return function(ctx)
	local seen = {}
	local excluded = {
		modules = {},
		patches = {}
	}
	local removals = {}
	local planned = {}

	local function join(a, b)
		if type(b) ~= 'string' or b == '' then return a end
		b = b:gsub('\\', '/'):gsub('^/+', ''):gsub('/+$', '')
		if b:sub(1, 4) == 'src/' then return b end
		return a..'/'..b
	end

	local function cleanpath(path)
		return tostring(path or '')
			:gsub('\\', '/')
			:gsub('/+', '/')
			:gsub('^/+', '')
			:gsub('/+$', '')
			:lower()
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

	local function addexclude(kind, value, prefix)
		if type(value) == 'string' then
			local path = cleanpath((prefix and prefix..'/' or '')..value)
			if path ~= '' then excluded[kind][path] = true end
			return
		end
		if type(value) ~= 'table' then return end
		for key, item in pairs(value) do
			if type(key) == 'number' then
				addexclude(kind, item, prefix)
			elseif item == true then
				addexclude(kind, key, prefix)
			elseif type(item) == 'table' then
				addexclude(kind, item, (prefix and prefix..'/' or '')..tostring(key))
			elseif type(item) == 'string' then
				addexclude(kind, item, (prefix and prefix..'/' or '')..tostring(key))
			end
		end
	end

	local function addremovals(value)
		if type(value) == 'string' then
			removals[value] = true
			return
		end
		if type(value) ~= 'table' then return end
		for key, item in pairs(value) do
			local name = type(key) == 'number' and item or item == true and key or nil
			if type(name) == 'string' and name ~= '' then removals[name] = true end
		end
	end

	local function collect(data)
		if type(data) ~= 'table' then return end
		local block = data.exclude or data.excludes
		if type(block) == 'table' then
			addexclude('modules', block.modules)
			addexclude('patches', block.patches)
		end
		addremovals(data.remove or data.removes)
	end

	local function isexcluded(path, kind, scope)
		if scope ~= 'universal' or not excluded[kind] then return false end
		local full = cleanpath(path)
		local root = kind == 'modules' and 'src/modules/' or 'src/patches/'
		local rel = full:sub(1, #root) == root and full:sub(#root + 1) or full
		if excluded[kind][full] or excluded[kind][rel] then return true end
		for pattern in pairs(excluded[kind]) do
			if pattern:sub(-2) == '/*' then
				local prefix = pattern:sub(1, -2)
				if rel == prefix or rel:sub(1, #prefix + 1) == prefix..'/' then
					return true
				end
			end
		end
		return false
	end

	local function run(path, meta)
		if seen[path] then return false end
		seen[path] = true
		if isexcluded(path, meta.kind, meta.scope) then return false end

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
		if isexcluded(path, meta.kind, meta.scope) then return 0 end
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
			}) then count += 1 end
		end

		for _, entry in ipairs(catfiles(man, meta.kind, path)) do
			local rel = type(entry) == 'string' and entry
				or type(entry) == 'table' and (entry.path or entry.file)
			local enabled = type(entry) ~= 'table' or entry.enabled ~= false
			if rel and enabled and run(join(root..'/'..cat, rel), {
				layer = meta.layer,
				scope = meta.scope,
				category = cat,
				kind = meta.kind,
				required = type(entry) == 'table' and entry.required == true
			}) then
				count += 1
			end
		end
		return count
	end

	function ctx:loadroot(root, kind, layer, scope, required, supplied)
		local path = root..'/manifest.lua'
		local man = supplied
		if man == nil then
			local ok, value, state = self.loader:try(path)
			if not ok then
				if required or state ~= 'missing' then
					fail('layer', path, value or 'missing manifest', required or self.cfg.strict)
				end
				return false
			end
			man = value
		end
		if type(man) ~= 'table' then
			fail('layer', path, path..' must return a table', required or self.cfg.strict)
			return false
		end
		if man.disabled == true or man.nativeonly == true and not self.target.native then return false end

		local count = 0
		if man.init then
			if run(join(root, man.init), {
				layer = layer,
				scope = scope,
				kind = kind,
				required = true
			}) then count += 1 end
		end
		for _, cat in ipairs(categories(man, path)) do
			count += loadcat(root, cat, {
				layer = layer,
				scope = scope,
				kind = kind
			})
		end
		self.layers[#self.layers + 1] = {
			name = layer,
			kind = kind,
			root = root,
			files = count
		}
		return true
	end

	local function section(base, data, kind, layer, scope)
		local val = data and data[kind]
		if not val then return end
		local root = type(val) == 'string' and join(base, val)
			or type(val) == 'table' and join(base, val.root or val.path or kind)
			or base..'/'..kind
		ctx:loadroot(
			root,
			kind,
			layer,
			scope,
			type(val) == 'table' and val.required == true,
			type(val) == 'table' and val.manifest
		)
	end

	local function targetpart(base, data, layer, scope)
		if data == true then data = {modules = true, patches = true} end
		if type(data) ~= 'table' then data = {} end
		if data.disabled == true then return end

		if data.init then
			local loaded = run(join(base, data.init), {
				layer = layer,
				scope = scope,
				kind = 'init',
				required = true
			})
			if loaded then
				ctx.layers[#ctx.layers + 1] = {
					name = layer,
					kind = 'init',
					root = base,
					files = 1
				}
			end
		end
		section(base, data, 'modules', layer, scope)
		section(base, data, 'patches', layer, scope)
	end

	local function readmanifest(root, quiet)
		local path = root..'/manifest.lua'
		local ok, man, state = ctx.loader:try(path)
		if not ok then
			if not quiet and state ~= 'missing' then fail('layer', path, man, ctx.cfg.strict) end
			return nil
		end
		if type(man) ~= 'table' then
			fail('layer', path, path..' must return a table', ctx.cfg.strict)
			return nil
		end
		return man
	end

	local function descriptor(root, data, layer, scope)
		if type(data) == 'string' then
			root = join('src/games', data)
			data = nil
		elseif type(data) == 'table' and (data.root or data.path) then
			root = join('src/games', data.root or data.path)
		end

		local inline = type(data) == 'table' and (
			data.modules ~= nil
			or data.patches ~= nil
			or data.init ~= nil
			or data.exclude ~= nil
			or data.excludes ~= nil
			or data.remove ~= nil
			or data.removes ~= nil
			or data.disabled ~= nil
		)
		local man = inline and data or readmanifest(root, true)
		if not man then return nil end
		return {
			root = root,
			data = man,
			layer = layer,
			scope = scope
		}
	end

	local function groupentry(base, group, id, layer, scope)
		if group == true then
			return descriptor(base..'/'..scope..'s/'..id, nil, layer, scope)
		end
		if type(group) ~= 'table' then return nil end
		local value = group[id] or group[tonumber(id)]
		if value == nil then return nil end
		return descriptor(base..'/'..scope..'s/'..id, value, layer, scope)
	end

	local function registryentry(registry, key, id, layer, scope)
		local group = type(registry) == 'table' and registry[key]
		if type(group) ~= 'table' then return nil end
		local value = group[id] or group[tonumber(id)]
		if value == nil then return nil end
		return descriptor('src/games/'..id, value, layer, scope)
	end

	local function addplan(item)
		if not item then return end
		for _, old in ipairs(planned) do
			if old.root == item.root and old.scope == item.scope then return end
		end
		planned[#planned + 1] = item
		collect(item.data)
	end

	local function applyremovals()
		for name in pairs(removals) do
			if ctx.mods[name] then
				local ok = ctx:drop(name)
				if not ok then fail('layer', name, 'failed to remove universal module '..name, ctx.cfg.strict) end
			end
		end
	end

	function ctx:loadlayers()
		local gameid = tostring(self.target.gameid)
		local buildid = tostring(self.target.buildid)
		local placeid = tostring(self.target.placeid)

		local registry = readmanifest('src/games', true)
		addplan(registryentry(registry, 'universes', gameid, 'game:'..gameid, 'game'))
		addplan(registryentry(registry, 'places', placeid, 'place:'..placeid, 'place'))

		local legacyroot = 'src/games/'..gameid
		local legacyman = readmanifest(legacyroot, true)
		if legacyman then
			addplan({
				root = legacyroot,
				data = legacyman,
				layer = 'game:'..gameid,
				scope = 'game'
			})
			addplan(groupentry(legacyroot, legacyman.builds, buildid, 'build:'..buildid, 'build'))
			addplan(groupentry(legacyroot, legacyman.places, placeid, 'place:'..placeid, 'place'))
		end

		if not registryentry(registry, 'places', placeid, 'place:'..placeid, 'place') then
			addplan(descriptor('src/games/'..placeid, nil, 'place:'..placeid, 'place'))
		end

		self.excluded = {
			modules = table.clone(excluded.modules),
			patches = table.clone(excluded.patches)
		}
		self.removals = table.clone(removals)

		self:loadroot('src/modules', 'modules', 'universal:modules', 'universal', true)
		self:loadroot('src/patches', 'patches', 'universal:patches', 'universal', true)
		applyremovals()

		for _, item in ipairs(planned) do
			targetpart(item.root, item.data, item.layer, item.scope)
		end
	end
end
