return function(ctx)
	local seen = {}

	local function join(a, b)
		if type(b) ~= 'string' or b == '' then return a end
		b = b:gsub('\\', '/'):gsub('^/+', '')
		if b:sub(1, 4) == 'src/' then return b end
		return a..'/'..b
	end

	local function fail(kind, path, msg, fatal)
		ctx.log:add(kind, path, msg, fatal)
		if fatal then error(msg, 0) end
	end

	local function traceback(msg)
		if ctx.cfg.debug and debug and type(debug.traceback) == 'function' then
			return debug.traceback(tostring(msg), 2)
		end
		return tostring(msg)
	end

	local function run(path, meta)
		if seen[path] then return false end
		seen[path] = true
		local mark = ctx:_mark()
		local previous = ctx.loading
		ctx.loading = {
			layer = meta.layer,
			scope = meta.scope,
			category = meta.category,
			kind = meta.kind,
			path = path,
			required = meta.required == true
		}
		local ok, msg = xpcall(function()
			local init = ctx.loader:run(path)
			if type(init) ~= 'function' then error(path..' must return a function', 0) end
			init(ctx)
		end, traceback)
		ctx.loading = previous
		if ok then return true end
		if not ctx:_rollback(mark) then error('incomplete rollback for '..path, 0) end
		fail(meta.kind, path, msg, ctx.cfg.strict or meta.required == true)
		return false
	end

	local function categories(man, path)
		if man.categories == nil then return table.clone(ctx.cats.order) end
		if type(man.categories) ~= 'table' then error(path..' categories must be a table', 0) end
		local out = {}
		local added = {}
		for key, val in pairs(man.categories) do
			local cat = type(key) == 'number' and val or val and key or nil
			if cat then
				cat = tostring(cat):lower()
				if not ctx.cats.names[cat] then error(path..' has unsupported category '..cat, 0) end
				if not added[cat] then
					added[cat] = true
					out[#out + 1] = cat
				end
			end
		end
		table.sort(out, function(a, b)
			return table.find(ctx.cats.order, a) < table.find(ctx.cats.order, b)
		end)
		return out
	end

	local function catfiles(man, kind, path)
		local files = man.files or man[kind] or man
		if type(files) ~= 'table' then error(path..' must return a file list', 0) end
		return files
	end

	local function loadcat(root, cat, meta)
		local path = root..'/'..cat..'/manifest.lua'
		local ok, man, state = ctx.loader:try(path)
		if not ok then
			if state ~= 'missing' then fail(meta.kind, path, man, ctx.cfg.strict) end
			return 0
		end
		if type(man) ~= 'table' then
			fail(meta.kind, path, path..' must return a table', ctx.cfg.strict)
			return 0
		end
		if man.disabled == true or man.nativeonly == true and not ctx.target.native then return 0 end
		local count = 0
		if man.init then
			if run(join(root..'/'..cat, man.init), {
				layer = meta.layer,
				scope = meta.scope,
				category = cat,
				kind = meta.kind,
				required = true
			}) then count = count + 1 end
		end
		for _, entry in ipairs(catfiles(man, meta.kind, path)) do
			local rel = type(entry) == 'string' and entry or type(entry) == 'table' and (entry.path or entry.file)
			local enabled = type(entry) ~= 'table' or entry.enabled ~= false
			if rel and enabled and run(join(root..'/'..cat, rel), {
				layer = meta.layer,
				scope = meta.scope,
				category = cat,
				kind = meta.kind,
				required = type(entry) == 'table' and entry.required == true
			}) then
				count = count + 1
			end
		end
		return count
	end

	function ctx:loadroot(root, kind, layer, scope, required)
		local path = root..'/manifest.lua'
		local ok, man, state = self.loader:try(path)
		if not ok then
			if required or state ~= 'missing' then fail('layer', path, man or 'missing manifest', required or self.cfg.strict) end
			return false
		end
		if type(man) ~= 'table' then
			fail('layer', path, path..' must return a table', required or self.cfg.strict)
			return false
		end
		if man.disabled == true or man.nativeonly == true and not self.target.native then return false end
		local count = 0
		if man.init then
			if run(join(root, man.init), {layer = layer, scope = scope, kind = kind, required = true}) then
				count = count + 1
			end
		end
		for _, cat in ipairs(categories(man, path)) do
			count = count + loadcat(root, cat, {layer = layer, scope = scope, kind = kind})
		end
		self.layers[#self.layers + 1] = {name = layer, kind = kind, root = root, files = count}
		return true
	end

	local function section(base, data, kind, layer, scope)
		local val = data and data[kind]
		if not val then return end
		local root = type(val) == 'string' and join(base, val)
			or type(val) == 'table' and join(base, val.root or val.path or kind)
			or base..'/'..kind
		ctx:loadroot(root, kind, layer, scope, type(val) == 'table' and val.required == true)
	end

	local function targetpart(base, data, layer, scope)
		if data == true then data = {modules = true, patches = true} end
		if type(data) ~= 'table' then data = {} end
		if data.init then
			local loaded = run(join(base, data.init), {
				layer = layer,
				scope = scope,
				kind = 'init',
				required = true
			})
			if loaded then
				ctx.layers[#ctx.layers + 1] = {name = layer, kind = 'init', root = base, files = 1}
			end
		end
		section(base, data, 'modules', layer, scope)
		section(base, data, 'patches', layer, scope)
	end

	local function targetentry(base, group, id, layer, scope)
		if type(group) == 'table' then
			local data = group[id] or group[tonumber(id)]
			if data then targetpart(base..'/'..scope..'s/'..id, data, layer, scope) end
			return
		end
		if group ~= true then return end
		local root = base..'/'..scope..'s/'..id
		local ok, data, state = ctx.loader:try(root..'/manifest.lua')
		if not ok then
			if state ~= 'missing' then fail('layer', root..'/manifest.lua', data, ctx.cfg.strict) end
			return
		end
		if type(data) ~= 'table' then
			fail('layer', root..'/manifest.lua', 'target manifest must return a table', ctx.cfg.strict)
			return
		end
		targetpart(root, data, layer, scope)
	end

	function ctx:loadlayers()
		self:loadroot('src/modules', 'modules', 'universal:modules', 'universal', true)
		self:loadroot('src/patches', 'patches', 'universal:patches', 'universal', true)

		local gameid = tostring(self.target.gameid)
		local base = 'src/games/'..gameid
		local ok, man, state = self.loader:try(base..'/manifest.lua')
		if not ok then
			if state ~= 'missing' then fail('layer', base..'/manifest.lua', man, self.cfg.strict) end
			return
		end
		if type(man) ~= 'table' then
			fail('layer', base..'/manifest.lua', 'game manifest must return a table', self.cfg.strict)
			return
		end
		targetpart(base, man, 'game:'..gameid, 'game')

		local buildid = tostring(self.target.buildid)
		targetentry(base, man.builds, buildid, 'build:'..buildid, 'build')

		local placeid = tostring(self.target.placeid)
		targetentry(base, man.places, placeid, 'place:'..placeid, 'place')
	end
end
