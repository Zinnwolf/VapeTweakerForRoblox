return function(context)
	local logger = {
		History = {}
	}

	local function format(message, ...)
		if select('#', ...) == 0 then
			return tostring(message)
		end

		local ok, result = pcall(string.format, tostring(message), ...)
		return ok and result or tostring(message)
	end

	function logger:Write(level, message, ...)
		local text = format(message, ...)
		table.insert(self.History, {
			Level = level,
			Message = text,
			Time = os.clock()
		})

		local output = ('[VapeTweaker/%s] %s'):format(level, text)
		if level == 'WARN' or level == 'ERROR' then
			warn(output)
		else
			print(output)
		end
	end

	function logger:Info(message, ...)
		self:Write('INFO', message, ...)
	end

	function logger:Warn(message, ...)
		self:Write('WARN', message, ...)
	end

	function logger:Error(message, ...)
		self:Write('ERROR', message, ...)
	end

	local function getGuiName()
		if type(isfile) == 'function' and type(readfile) == 'function' then
			local path = 'newvape/profiles/gui.txt'
			local ok, exists = pcall(isfile, path)
			if ok and exists then
				local readOk, value = pcall(readfile, path)
				if readOk then
					return tostring(value):lower():gsub('%s+', '')
				end
			end
		end
		return nil
	end

	function logger:Notify(title, text, duration, notificationType)
		local vape = context.Vape
		local shown = false
		local guiName = getGuiName()
		local nativeNotificationMissing = guiName == 'wurst' or guiName == 'liquidbounce'

		if not nativeNotificationMissing and type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			shown = pcall(function()
				vape:CreateNotification(title, text, duration or 5, notificationType)
			end)
		end

		if not shown then
			local ok = pcall(function()
				game:GetService('StarterGui'):SetCore('SendNotification', {
					Title = tostring(title),
					Text = tostring(text),
					Duration = duration or 5
				})
			end)
			shown = ok
		end

		self:Info('notification: %s - %s', title, text)
		return shown
	end

	context.Logger = logger
end
