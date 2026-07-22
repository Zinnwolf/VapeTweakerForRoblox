return function(ctx)
	local vape = ctx.vape
	if type(vape) ~= 'table' or type(vape.CreateOverlay) ~= 'function' then
		error('Crosshair requires the new Vape GUI overlay API', 0)
	end

	local iconpath = ctx.store:path('assets/crosshair.png')
	local icon = 'rbxassetid://14368354234'
	local present = false
	if type(isfile) == 'function' and iconpath then
		local ok, val = pcall(isfile, iconpath)
		present = ok and val == true
	end
	if not present and iconpath and ctx.store.fs.write then
		local ok, body = pcall(game.HttpGet, game, ctx.loader.base..'/assets/crosshair.png', true)
		if ok and type(body) == 'string' and #body > 8 then
			present = ctx.store:write('assets/crosshair.png', body)
		end
	end
	local asset = vape.Libraries and vape.Libraries.getcustomasset
	if present and type(asset) == 'function' then
		local ok, val = pcall(asset, iconpath)
		if ok and type(val) == 'string' and val ~= '' then icon = val end
	end

	local overlay
	local holder
	local style
	local color
	local size
	local thickness
	local gap
	local outline
	local outlinewidth

	local function clear()
		if not holder then return end
		for _, obj in ipairs(holder:GetChildren()) do
			obj:Destroy()
		end
	end

	local function corner(obj)
		local ui = Instance.new('UICorner')
		ui.CornerRadius = UDim.new(1, 0)
		ui.Parent = obj
		return ui
	end

	local function box(name, parent, width, height, x, y, anchor, fill, transparency, round)
		local obj = Instance.new('Frame')
		obj.Name = name
		obj.Size = UDim2.fromOffset(math.max(1, width), math.max(1, height))
		obj.Position = UDim2.new(0.5, x, 0.5, y)
		obj.AnchorPoint = anchor
		obj.BackgroundColor3 = fill
		obj.BackgroundTransparency = transparency
		obj.BorderSizePixel = 0
		obj.ZIndex = 1000000
		obj.Parent = parent
		if round then corner(obj) end
		return obj
	end

	local function arm(name, width, height, x, y, anchor, fill, transparency, edge)
		if outline.Enabled then
			box(
				name..'Outline',
				holder,
				width + outlinewidth.Value * 2,
				height + outlinewidth.Value * 2,
				x,
				y,
				anchor,
				Color3.new(),
				transparency,
				edge
			)
		end
		box(name, holder, width, height, x, y, anchor, fill, transparency, edge)
	end

	local function dot(name, diameter, fill, transparency)
		if outline.Enabled then
			box(
				name..'Outline',
				holder,
				diameter + outlinewidth.Value * 2,
				diameter + outlinewidth.Value * 2,
				0,
				0,
				Vector2.new(0.5, 0.5),
				Color3.new(),
				transparency,
				true
			)
		end
		box(name, holder, diameter, diameter, 0, 0, Vector2.new(0.5, 0.5), fill, transparency, true)
	end

	local function circle(diameter, line, fill, transparency)
		if outline.Enabled then
			local outer = box(
				'CircleOutline',
				holder,
				diameter,
				diameter,
				0,
				0,
				Vector2.new(0.5, 0.5),
				Color3.new(),
				1,
				true
			)
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.new()
			stroke.Thickness = line + outlinewidth.Value * 2
			stroke.Transparency = transparency
			stroke.Parent = outer
		end

		local ring = box(
			'Circle',
			holder,
			diameter,
			diameter,
			0,
			0,
			Vector2.new(0.5, 0.5),
			fill,
			1,
			true
		)
		local stroke = Instance.new('UIStroke')
		stroke.Color = fill
		stroke.Thickness = line
		stroke.Transparency = transparency
		stroke.Parent = ring
		dot('CenterDot', math.max(2, line + 1), fill, transparency)
	end

	local function optionvisibility()
		if not style then return end
		local selected = style.Value
		if gap then gap.Object.Visible = selected == 'Classic' end
		if thickness then thickness.Object.Visible = selected ~= 'Dot' end
		if outlinewidth then outlinewidth.Object.Visible = outline.Enabled end
	end

	local function draw()
		if not holder or not style or not color or not size or not thickness or not gap or not outline or not outlinewidth then
			return
		end
		clear()
		optionvisibility()

		local fill = Color3.fromHSV(color.Hue, color.Sat, color.Value)
		local transparency = 1 - color.Opacity
		local length = size.Value
		local line = thickness.Value
		local space = gap.Value

		if style.Value == 'Dot' then
			dot('Dot', math.max(2, math.floor(length * 0.45 + 0.5)), fill, transparency)
		elseif style.Value == 'Circle' then
			circle(math.max(8, length * 2), line, fill, transparency)
		else
			arm('Left', length, line, -space, 0, Vector2.new(1, 0.5), fill, transparency, true)
			arm('Right', length, line, space, 0, Vector2.new(0, 0.5), fill, transparency, true)
			arm('Top', line, length, 0, -space, Vector2.new(0.5, 1), fill, transparency, true)
			arm('Bottom', line, length, 0, space, Vector2.new(0.5, 0), fill, transparency, true)
		end
	end

	local function center()
		if not overlay or not overlay.Object then return end
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local scale = vape.Scale and tonumber(vape.Scale.Value) or 1
		scale = math.max(scale or 1, 0.01)
		overlay.Object.Position = UDim2.fromOffset(
			math.floor(viewport.X / (2 * scale) - 110),
			math.floor(viewport.Y / (2 * scale))
		)
	end

	overlay = vape:CreateOverlay({
		Name = 'Crosshair',
		Icon = icon,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(11, 12),
		CategorySize = 220,
		Function = function(on)
			if holder then holder.Visible = on end
		end
	})

	ctx:clean(function()
		if type(vape.Overlays) == 'table' and type(vape.Overlays.Toggles) == 'table' then
			for i = #vape.Overlays.Toggles, 1, -1 do
				if vape.Overlays.Toggles[i] == overlay.Button then
					table.remove(vape.Overlays.Toggles, i)
				end
			end
		end
		if vape.Categories and vape.Categories.Crosshair == overlay then
			if overlay.Button and overlay.Button.Enabled then pcall(overlay.Button.Toggle, overlay.Button) end
			pcall(vape.Remove, vape, 'Crosshair')
		end
	end)

	holder = Instance.new('Frame')
	holder.Name = 'Crosshair'
	holder.Size = UDim2.fromOffset(160, 160)
	holder.Position = UDim2.fromOffset(110, 0)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.ZIndex = 1000000
	holder.Parent = overlay.Children

	style = overlay:CreateDropdown({
		Name = 'Style',
		List = {'Classic', 'Dot', 'Circle'},
		Function = draw
	})

	color = overlay:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		DefaultSat = 0,
		DefaultValue = 1,
		DefaultOpacity = 1,
		Function = draw
	})

	size = overlay:CreateSlider({
		Name = 'Size',
		Min = 2,
		Max = 40,
		Default = 12,
		Function = draw
	})

	thickness = overlay:CreateSlider({
		Name = 'Thickness',
		Min = 1,
		Max = 10,
		Default = 2,
		Function = draw
	})

	gap = overlay:CreateSlider({
		Name = 'Gap',
		Min = 0,
		Max = 30,
		Default = 6,
		Function = draw
	})

	outline = overlay:CreateToggle({
		Name = 'Outline',
		Default = true,
		Function = draw
	})

	outlinewidth = overlay:CreateSlider({
		Name = 'Outline Thickness',
		Min = 1,
		Max = 5,
		Default = 1,
		Function = draw
	})

	overlay:CreateButton({
		Name = 'Center Crosshair',
		Function = center
	})

	center()
	if not overlay.Pinned then overlay:Pin() end
	draw()

	pcall(function()
		vape:Load(true)
	end)

end
