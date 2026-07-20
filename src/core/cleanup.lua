return function(context)
	local cleanup = {
		Items = {},
		Ran = false
	}

	function cleanup:Add(item)
		if item == nil then
			return item
		end
		table.insert(self.Items, item)
		return item
	end

	local function cleanOne(item)
		local kind = typeof(item)
		if kind == 'RBXScriptConnection' then
			item:Disconnect()
		elseif kind == 'Instance' then
			item:Destroy()
		elseif type(item) == 'function' then
			item()
		elseif type(item) == 'table' then
			if type(item.Disconnect) == 'function' then
				item:Disconnect()
			elseif type(item.Destroy) == 'function' then
				item:Destroy()
			elseif type(item.Clean) == 'function' then
				item:Clean()
			end
		end
	end

	function cleanup:Run()
		if self.Ran then
			return
		end
		self.Ran = true

		for index = #self.Items, 1, -1 do
			pcall(cleanOne, self.Items[index])
			self.Items[index] = nil
		end
	end

	context.Cleanup = cleanup
end
