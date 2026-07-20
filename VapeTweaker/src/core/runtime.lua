return function(context)
	function context:RegisterModule(name, module, category)
		assert(type(name) == 'string' and name ~= '', '[VapeTweaker] module name is required')
		assert(type(module) == 'table', '[VapeTweaker] module object is required')

		self.Modules[name] = {
			Name = name,
			Category = category,
			Object = module
		}
		table.insert(self.ModuleOrder, name)
		return module
	end

	function context:Unload(reason)
		if self.State == 'unloading' or self.State == 'unloaded' then
			return
		end

		self.State = 'unloading'
		if self.Logger then
			self.Logger:Info('unloading%s', reason and (' ('..tostring(reason)..')') or '')
		end

		local adapter = self.Adapters and self.Adapters.Vape
		for index = #self.ModuleOrder, 1, -1 do
			local name = self.ModuleOrder[index]
			if adapter and type(adapter.RemoveModule) == 'function' then
				pcall(function()
					adapter:RemoveModule(name)
				end)
			end
			self.Modules[name] = nil
			self.ModuleOrder[index] = nil
		end

		if self.Cleanup then
			self.Cleanup:Run()
		end

		self.State = 'unloaded'
		local env = (getgenv and getgenv()) or _G
		if env.VapeTweaker == self then
			env.VapeTweaker = nil
		end
	end
end
