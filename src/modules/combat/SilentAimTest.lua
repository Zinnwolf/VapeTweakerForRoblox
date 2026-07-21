-- Biblioteca / SilentAim.lua
-- Owner gate removed – usable anywhere

return function(context)
	local Players = game:GetService('Players')
	local ReplicatedStorage = game:GetService('ReplicatedStorage')
	local RunService = game:GetService('RunService')

	local player = Players.LocalPlayer
	local random = Random.new()
	local unpackArgs = table.unpack or unpack

	local SilentAim
	local FOV
	local MaxDistance
	local HitChance
	local AimPoint
	local WallCheck
	local RedirectVFX
	local ShowFOV

	local enabled = false
	local oldNamecall
	local internalCall = false
	local pendingDecision
	local pendingUntil = 0
	local lastRedirectedStroke = 0
	local circle
	local circleConnection

	local paintRemotes = ReplicatedStorage:FindFirstChild('PaintRemotes')
	local seekerData = ReplicatedStorage:FindFirstChild('SeekerData')
	local strokeEvent = paintRemotes and paintRemotes:FindFirstChild('StrokeEvent')
	local shootVFXEvent = seekerData and seekerData:FindFirstChild('ShootVFXEvent')

	if not strokeEvent or not strokeEvent:IsA('RemoteEvent')
		or not shootVFXEvent or not shootVFXEvent:IsA('RemoteEvent') then
		context.Logger:Warn('SilentAim skipped: required game remotes are unavailable')
		return
	end

	local function findPlayerFromInstance(instance)
		if not instance then
			return nil
		end

		for _, candidate in ipairs(Players:GetPlayers()) do
			local character = candidate.Character
			if character and instance:IsDescendantOf(character) then
				return candidate
			end
		end
	end

	local function getTargetMesh(candidate)
		local character = candidate and candidate.Character
		local mesh = character and character:FindFirstChild('paintman.001')
		return mesh and mesh:IsA('BasePart') and mesh or nil
	end

	local function findNamedBone(mesh, names)
		for _, descendant in ipairs(mesh:GetDescendants()) do
			if descendant:IsA('Bone') and names[string.lower(descendant.Name)] then
				return descendant
			end
		end
	end

	local function getBones(mesh)
		local bones = {}
		for _, descendant in ipairs(mesh:GetDescendants()) do
			if descendant:IsA('Bone') then
				table.insert(bones, descendant)
			end
		end
		return bones
	end

	local function getCamera()
		return workspace.CurrentCamera
	end

	local function getScreenCenter(camera)
		local viewport = camera.ViewportSize
		return Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	end

	local function project(camera, worldPosition)
		local point, visibleOnScreen = camera:WorldToViewportPoint(worldPosition)
		if not visibleOnScreen or point.Z <= 0 then
			return nil
		end
		return Vector2.new(point.X, point.Y)
	end

	local function raycastSkippingDecorations(origin, direction, targetCharacter)
		local camera = getCamera()
		local excluded = {player.Character, camera}

		for _ = 1, 16 do
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = excluded
			params.IgnoreWater = true

			local result = workspace:Raycast(origin, direction, params)
			if not result then
				return nil
			end

			local instance = result.Instance
			if targetCharacter and instance:IsDescendantOf(targetCharacter) then
				return result
			end

			if instance.CanCollide ~= false or findPlayerFromInstance(instance) then
				return result
			end

			table.insert(excluded, instance)
		end
	end

	local function isVisible(origin, position, character)
		if not WallCheck.Enabled then
			return true
		end

		local result = raycastSkippingDecorations(origin, position - origin, character)
		return result == nil or result.Instance:IsDescendantOf(character)
	end

	local function chooseAimPosition(mesh, camera, center)
		local selectedMode = AimPoint.Value
		local selectedBone

		if selectedMode == 'Head' then
			selectedBone = findNamedBone(mesh, {head = true, neck = true})
		elseif selectedMode == 'Torso' then
			selectedBone = findNamedBone(mesh, {
				spine1 = true,
				spine = true,
				chest = true,
				neck = true,
				hips = true
			})
		elseif selectedMode == 'Random Bone' then
			local bones = getBones(mesh)
			if #bones > 0 then
				selectedBone = bones[random:NextInteger(1, #bones)]
			end
		end

		if selectedBone then
			local position = selectedBone.WorldCFrame.Position
			local screen = project(camera, position)
			if screen then
				return position, (screen - center).Magnitude
			end
		end

		local bestPosition
		local bestScreenDistance = math.huge
		for _, bone in ipairs(getBones(mesh)) do
			local position = bone.WorldCFrame.Position
			local screen = project(camera, position)
			if screen then
				local screenDistance = (screen - center).Magnitude
				if screenDistance < bestScreenDistance then
					bestScreenDistance = screenDistance
					bestPosition = position
				end
			end
		end

		if bestPosition then
			return bestPosition, bestScreenDistance
		end

		local screen = project(camera, mesh.Position)
		return screen and mesh.Position or nil, screen and (screen - center).Magnitude or nil
	end

	local function acquireTarget()
		if player:GetAttribute('Role') ~= 'Seeker' then
			return nil
		end

		if random:NextNumber(0, 100) > HitChance.Value then
			return nil
		end

		local camera = getCamera()
		if not camera then
			return nil
		end

		local origin = camera.CFrame.Position
		local center = getScreenCenter(camera)
		local best
		local bestScreenDistance = FOV.Value

		for _, candidate in ipairs(Players:GetPlayers()) do
			if candidate ~= player and candidate:GetAttribute('Role') == 'Hider' then
				local character = candidate.Character
				local mesh = getTargetMesh(candidate)
				if character and mesh then
					local position, screenDistance = chooseAimPosition(mesh, camera, center)
					if position
						and screenDistance
						and screenDistance <= bestScreenDistance
						and (position - origin).Magnitude <= MaxDistance.Value
						and isVisible(origin, position, character) then
						bestScreenDistance = screenDistance
						best = {
							Player = candidate,
							Character = character,
							Mesh = mesh,
							Position = position,
							ScreenDistance = screenDistance,
							Origin = origin
						}
					end
				end
			end
		end

		if best then
			local ray = raycastSkippingDecorations(
				best.Origin,
				best.Position - best.Origin,
				best.Character
			)
			best.Normal = ray and ray.Instance:IsDescendantOf(best.Character)
				and ray.Normal
				or Vector3.new(0, 1, 0)
		end

		return best
	end

	local function getDecision()
		local now = os.clock()
		if pendingDecision ~= nil and now <= pendingUntil then
			return pendingDecision ~= false and pendingDecision or nil
		end

		pendingDecision = acquireTarget() or false
		pendingUntil = now + 0.15
		return pendingDecision ~= false and pendingDecision or nil
	end

	local function clearDecision()
		pendingDecision = nil
		pendingUntil = 0
	end

	local function clonePayload(payload)
		local cloned = {}
		if type(payload) == 'table' then
			for key, value in pairs(payload) do
				cloned[key] = value
			end
		end
		return cloned
	end

	local function buildStrokePayload(decision, color)
		return {
			partLocal = decision.Mesh.CFrame:PointToObjectSpace(decision.Position),
			color = color or Color3.fromHSV(random:NextNumber(), random:NextNumber(0.75, 1), 1),
			target = decision.Player
		}
	end

	local function fireInjectedStroke(decision, color)
		internalCall = true
		local ok, err = pcall(function()
			strokeEvent:FireServer(buildStrokePayload(decision, color))
		end)
		internalCall = false

		if not ok then
			context.Logger:Warn('SilentAim injected StrokeEvent failed: %s', tostring(err))
		end
	end

	local function installHook()
		if oldNamecall then
			return true
		end

		if type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then
			return false, 'executor does not expose hookmetamethod/getnamecallmethod'
		end

		local callback = function(self, ...)
			local method = getnamecallmethod()
			local callerIsExecutor = type(checkcaller) == 'function' and checkcaller()

			if not enabled
				or internalCall
				or callerIsExecutor
				or method ~= 'FireServer'
				or (self ~= strokeEvent and self ~= shootVFXEvent) then
				return oldNamecall(self, ...)
			end

			local args = {...}
			local payload = args[1]

			if self == strokeEvent then
				local decision = getDecision()
				if decision then
					local redirected = buildStrokePayload(
						decision,
						type(payload) == 'table' and payload.color or nil
					)
					args[1] = redirected
					lastRedirectedStroke = os.clock()
				end
				return oldNamecall(self, unpackArgs(args))
			end

			local decision = getDecision()
			if decision then
				if os.clock() - lastRedirectedStroke > 0.15 then
					fireInjectedStroke(
						decision,
						type(payload) == 'table' and payload.color or nil
					)
				end

				if RedirectVFX.Enabled then
					local redirectedVFX = clonePayload(payload)
					redirectedVFX.hit = decision.Position
					redirectedVFX.normal = decision.Normal
					redirectedVFX.onPlayer = true
					args[1] = redirectedVFX
				end
			end

			clearDecision()
			lastRedirectedStroke = 0
			return oldNamecall(self, unpackArgs(args))
		end

		if type(newcclosure) == 'function' then
			callback = newcclosure(callback)
		end

		oldNamecall = hookmetamethod(game, '__namecall', callback)
		return type(oldNamecall) == 'function'
	end

	local function removeHook()
		if oldNamecall and type(hookmetamethod) == 'function' then
			pcall(function()
				hookmetamethod(game, '__namecall', oldNamecall)
			end)
		end
		oldNamecall = nil
		internalCall = false
		clearDecision()
		lastRedirectedStroke = 0
	end

	local function removeCircle()
		if circleConnection then
			circleConnection:Disconnect()
			circleConnection = nil
		end
		if circle then
			pcall(function()
				circle.Visible = false
				circle:Remove()
			end)
			circle = nil
		end
	end

	local function refreshCircle()
		if not enabled or not ShowFOV.Enabled or type(Drawing) ~= 'table' then
			if circle then
				circle.Visible = false
			end
			return
		end

		if not circle then
			circle = Drawing.new('Circle')
			circle.NumSides = 80
			circle.Thickness = 1
			circle.Filled = false
			circle.Transparency = 0.75
			circle.Color = Color3.new(1, 1, 1)
		end

		circle.Visible = true
		circle.Radius = FOV.Value
		local camera = getCamera()
		if camera then
			circle.Position = getScreenCenter(camera)
		end
	end

	SilentAim = context:CreateModule({
		Name = 'SilentAim',
		Category = 'Combat',
		Source = 'place:84307090458624',
		Function = function(callback)
			enabled = callback

			if callback then
				local ok, reason = installHook()
				if not ok then
					context.Logger:Notify('SilentAim', tostring(reason), 6, 'warning')
					task.defer(function()
						if SilentAim and SilentAim.Enabled then
							SilentAim:Toggle()
						end
					end)
					return
				end

				if not circleConnection then
					circleConnection = RunService.RenderStepped:Connect(refreshCircle)
				end
				refreshCircle()
				context.Logger:Notify('SilentAim', 'Remote redirection enabled', 4)
			else
				removeHook()
				removeCircle()
			end
		end,
		ExtraText = function()
			return AimPoint and AimPoint.Value or 'Game'
		end,
		Tooltip = 'Silent targeting for chameleon game thung'
	})

	AimPoint = SilentAim:CreateDropdown({
		Name = 'Aim Point',
		List = {'Closest Bone', 'Head', 'Torso', 'Random Bone'},
		Default = 'Closest Bone'
	})

	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 10,
		Max = 800,
		Default = 180,
		Function = refreshCircle,
		Suffix = function(value)
			return tostring(value)..' px'
		end
	})

	MaxDistance = SilentAim:CreateSlider({
		Name = 'Max Distance',
		Min = 25,
		Max = 500,
		Default = 500,
		Suffix = function(value)
			return tostring(value)..' studs'
		end
	})

	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})

	WallCheck = SilentAim:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})

	RedirectVFX = SilentAim:CreateToggle({
		Name = 'Redirect Shot VFX',
		Default = false,
		Tooltip = 'When disabled, the visible shot remains where you aimed while the server target is redirected.'
	})

	ShowFOV = SilentAim:CreateToggle({
		Name = 'Show FOV',
		Default = true,
		Function = refreshCircle
	})

	context.Cleanup:Add(function()
		enabled = false
		removeHook()
		removeCircle()
	end)
end
