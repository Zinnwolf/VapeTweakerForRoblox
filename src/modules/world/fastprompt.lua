return function(ctx)
	local prompts = game:GetService('ProximityPromptService')
	local players = game:GetService('Players')
	local lp = players.LocalPlayer
	local jobs = {}
	local mod
	local reduction

	local function cancel(prompt)
		local job = jobs[prompt]
		if not job then return end
		jobs[prompt] = nil
		pcall(task.cancel, job)
	end

	local function clear()
		for prompt in pairs(jobs) do
			cancel(prompt)
		end
	end

	mod = ctx:module('world', {
		name = 'FastPrompt',
		tooltip = 'Modify ProximityPrompt timer',
		func = function(on)
			if on then
				mod:Clean(prompts.PromptButtonHoldBegan:Connect(function(prompt, player)
					if player ~= lp or prompt.HoldDuration <= 0 then return end

					cancel(prompt)

					local delay = prompt.HoldDuration
						* (1 - math.clamp(reduction.Value, 0, 100) / 100)

					jobs[prompt] = task.delay(delay, function()
						jobs[prompt] = nil

						if mod.Enabled
							and prompt.Parent
							and prompt.Enabled
							and type(fireproximityprompt) == 'function' then
							pcall(fireproximityprompt, prompt)
						end
					end)
				end))

				mod:Clean(prompts.PromptButtonHoldEnded:Connect(function(prompt, player)
					if player == lp then
						cancel(prompt)
					end
				end))

				mod:Clean(clear)
			else
				clear()
			end
		end
	})

	reduction = mod:CreateSlider({
		Name = 'Reduction',
		Min = 1,
		Max = 100,
		Default = 20,
		Suffix = '%'
	})
end
