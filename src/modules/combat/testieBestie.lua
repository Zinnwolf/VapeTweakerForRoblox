return function(context)
	local vape = assert(context.Vape, '[VapeTweaker] Vape adapter was not attached')
	local combat = vape.Categories and vape.Categories.Combat
	assert(type(combat) == 'table' and type(combat.CreateModule) == 'function',
		'[VapeTweaker] Vape Combat category is unavailable')

	context.Adapters.Vape:RemoveModule('testieBestie')

	local testieBestie
	testieBestie = combat:CreateModule({
		Name = 'testieBestie',
		Function = function(enabled)
			if not enabled then
				return
			end

			context.Logger:Notify('testieBestie', 'Yuh everything works', 5)

			-- Treat it like a test button so every click can run the check again.
			task.defer(function()
				if testieBestie and testieBestie.Enabled then
					testieBestie:Toggle()
				end
			end)
		end,
		Tooltip = 'Confirms that VapeTweaker attached to the active Vape UI.'
	})

	context:RegisterModule('testieBestie', testieBestie, 'Combat')
end
