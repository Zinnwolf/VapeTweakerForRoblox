return function(context)
	local adapter = {
		Vape = nil
	}

	local function waitFor(callback, timeout)
		local started = os.clock()
		repeat
			local ok, value = pcall(callback)
			if ok and value then
				return value
			end
			task.wait()
		until os.clock() - started >= timeout
		return nil
	end

	local function loadVape()
		local config = context.Config
		if config.AutoLoadVape == false then
			return
		end

		context.Logger:Info('Vape is not loaded; starting the configured Vape loader')

		if type(config.VapeLoaderPath) == 'string'
			and type(isfile) == 'function'
			and type(readfile) == 'function'
			and isfile(config.VapeLoaderPath) then
			local source = readfile(config.VapeLoaderPath)
			local chunk, compileError = loadstring(source, '@VapeTweaker/VapeLoader')
			assert(chunk, compileError)
			chunk()
			return
		end

		local url = config.VapeLoaderUrl
			or 'https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua'
		local source = game:HttpGet(url, true)
		local chunk, compileError = loadstring(source, '@VapeTweaker/VapeBootstrap')
		assert(chunk, compileError)
		chunk()
	end

	function adapter:Attach()
		local sharedTable = shared
		if type(sharedTable) ~= 'table' then
			error('[VapeTweaker] shared is unavailable', 0)
		end

		if type(sharedTable.vape) ~= 'table' then
			loadVape()
		end

		local vape = waitFor(function()
			local candidate = sharedTable.vape
			if type(candidate) ~= 'table' then
				return nil
			end
			if type(candidate.Categories) ~= 'table' then
				return nil
			end
			if type(candidate.Categories.Combat) ~= 'table' then
				return nil
			end
			if type(candidate.Categories.Combat.CreateModule) ~= 'function' then
				return nil
			end
			if context.Config.RequireLoaded == true and candidate.Loaded ~= true then
				return nil
			end
			return candidate
		end, tonumber(context.Config.AttachTimeout) or 45)

		assert(vape, '[VapeTweaker] timed out waiting for Vape and its Combat UI category')
		self.Vape = vape
		context.Logger:Info('found Vape UI and Combat category')
		return vape
	end

	local function disconnectItems(object)
		if type(object) ~= 'table' or type(object.Connections) ~= 'table' then
			return
		end

		for _, connection in pairs(object.Connections) do
			pcall(function()
				if type(connection) == 'function' then
					connection()
				elseif type(connection) == 'table' and type(connection.Disconnect) == 'function' then
					connection:Disconnect()
				elseif typeof(connection) == 'RBXScriptConnection' then
					connection:Disconnect()
				end
			end)
		end
		table.clear(object.Connections)
	end

	local function destroyObject(object)
		if typeof(object) == 'Instance' then
			pcall(function()
				object:Destroy()
			end)
		elseif type(object) == 'table' and typeof(object.Object) == 'Instance' then
			pcall(function()
				object.Object:Destroy()
			end)
		end
	end

	function adapter:FindModule(name)
		local vape = self.Vape or context.Vape
		if type(vape) ~= 'table' then
			return nil
		end

		if type(vape.Modules) == 'table' and type(vape.Modules[name]) == 'table' then
			return vape.Modules[name]
		end

		if type(vape.Categories) == 'table' then
			for _, category in pairs(vape.Categories) do
				if type(category) == 'table' and type(category.Modules) == 'table' and type(category.Modules[name]) == 'table' then
					return category.Modules[name]
				end
			end
		end

		return nil
	end

	function adapter:RemoveModule(name)
		local vape = self.Vape or context.Vape
		if type(vape) ~= 'table' then
			return false
		end

		local module = self:FindModule(name)
		if module and module.Enabled and type(module.Toggle) == 'function' then
			pcall(function()
				module:Toggle(true)
			end)
			task.wait()
		end

		if type(vape.Remove) == 'function' then
			local ok = pcall(function()
				vape:Remove(name)
			end)
			if ok and self:FindModule(name) == nil then
				return true
			end
		end

		-- Compatibility path for minimal GUI implementations that do not expose Remove.
		if module then
			disconnectItems(module)
			destroyObject(module.Object)
			destroyObject(module.Children)
		end

		if type(vape.Modules) == 'table' then
			vape.Modules[name] = nil
		end
		if type(vape.Categories) == 'table' then
			for _, category in pairs(vape.Categories) do
				if type(category) == 'table' and type(category.Modules) == 'table' then
					category.Modules[name] = nil
				end
			end
		end

		return module ~= nil
	end

	context.Adapters.Vape = adapter
end
