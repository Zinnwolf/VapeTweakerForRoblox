return function(ctx)
	local vape = ctx.vape
	if ctx.target.gui ~= 'new' or type(vape) ~= 'table' or type(vape.CreateCategory) ~= 'function'
		or type(vape.Categories) ~= 'table' or type(vape.Modules) ~= 'table' then return end
	if vape.Categories.Favorites then return end

	local run = game:GetService('RunService')
	local alive = true
	local seq = 0
	local profile
	local state = {favorites = {}, hidden = {}, editing = false}
	local mods = {}
	local rows = {}
	local heads = {}
	local wraps = {}
	local fav
	local favchildren
	local apiold = {}
	local assets = {}

	local function inst(obj)
		return typeof(obj) == 'Instance'
	end

	local function copy(tab)
		local out = {}
		for key, val in pairs(tab or {}) do out[key] = val end
		return out
	end

	local function tomap(tab)
		local out = {}
		if type(tab) ~= 'table' then return out end
		for key, val in pairs(tab) do
			local name = type(key) == 'number' and val or val and key
			if type(name) == 'string' and name ~= '' then out[name] = true end
		end
		return out
	end

	local function tolist(tab)
		local out = {}
		for name, enabled in pairs(tab) do
			if enabled then out[#out + 1] = name end
		end
		table.sort(out)
		return out
	end

	local function asset(name)
		if assets[name] then return assets[name] end
		local rel = 'assets/gui/'..name
		local path = ctx.store:path(rel)
		local present = false
		if path and type(isfile) == 'function' then
			local ok, val = pcall(isfile, path)
			present = ok and val == true
		end
		if not present and path and ctx.store.fs.write then
			local ok, body = pcall(game.HttpGet, game, ctx.loader.base..'/'..rel, true)
			if ok and type(body) == 'string' and #body > 8 then
				present = ctx.store:write(rel, body)
			end
		end
		local get = vape.Libraries and vape.Libraries.getcustomasset or getcustomasset
		if present and type(get) == 'function' then
			local ok, val = pcall(get, path)
			if ok and type(val) == 'string' then
				assets[name] = val
				return val
			end
		end
		assets[name] = ''
		return ''
	end

	local favoriteoff = asset('favoriteoff.png')
	local favoriteon = asset('favoriteon.png')
	local favoritetab = asset('favoriteofftab.png')
	local hiddeneye = asset('hiddeneyeoff.png')
	local editicon = asset('edit.png')

	local function path(dir)
		dir = dir or ctx.profile and ctx.profile.dir or 'default'
		return 'configs/profiles/'..dir..'/gui.json'
	end

	local function syncapi()
		if type(vape.Favorites) == 'table' then
			vape.Favorites.List = tolist(state.favorites)
			vape.Favorites.Rows = rows
		end
		if type(vape.Hidden) == 'table' then
			vape.Hidden.List = tolist(state.hidden)
			vape.Hidden.Editing = state.editing
		end
	end

	local function save(dir)
		if not alive then return false end
		local file = path(dir)
		local raw = ctx.store:encode({
			version = 1,
			favorites = tolist(state.favorites),
			hidden = tolist(state.hidden)
		}, file)
		return raw and ctx.store:write(file, raw) or false
	end

	local function queue()
		seq += 1
		local id = seq
		task.delay(0.35, function()
			if alive and id == seq then save() end
		end)
	end

	local function load()
		local data = ctx.store:json(path())
		state.favorites = tomap(data and data.favorites)
		state.hidden = tomap(data and data.hidden)
		state.editing = false
		profile = ctx.profile and ctx.profile.dir or 'default'
		syncapi()
	end

	local function accent(mod)
		local gui = vape.GUIColor
		if type(gui) == 'table' then
			local h = tonumber(gui.Hue) or 0.45
			local s = tonumber(gui.Sat) or 0.8
			local v = tonumber(gui.Value) or 0.8
			if gui.Rainbow and type(vape.Color) == 'function' then
				local ok, col = pcall(vape.Color, vape, (h - (((mod and mod.Index) or 1) * 0.025)) % 1)
				if ok and typeof(col) == 'Color3' then return col end
			end
			return Color3.fromHSV(h, s, v)
		end
		return Color3.fromRGB(5, 134, 105)
	end

	local function fallbackstar(button)
		local text = Instance.new('TextLabel')
		text.Name = 'Fallback'
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = '★'
		text.TextSize = 20
		text.TextColor3 = Color3.fromRGB(150, 150, 158)
		text.Font = Enum.Font.GothamBold
		text.Visible = button.Image == ''
		text.Parent = button
		return text
	end

	local function setstar(button, on, hover)
		if not inst(button) then return end
		button.Image = on and favoriteon or favoriteoff
		button.ImageColor3 = on and Color3.new(1, 1, 1)
			or hover and Color3.fromRGB(225, 225, 230) or Color3.fromRGB(120, 120, 128)
		local text = button:FindFirstChild('Fallback')
		if text then
			text.Visible = button.Image == ''
			text.TextColor3 = on and Color3.fromRGB(255, 170, 42) or button.ImageColor3
		end
	end

	local function checkbox(parent)
		local shield = Instance.new('TextButton')
		shield.Name = 'VTHideShield'
		shield.Size = UDim2.fromScale(1, 1)
		shield.BackgroundTransparency = 1
		shield.BorderSizePixel = 0
		shield.AutoButtonColor = false
		shield.Text = ''
		shield.Visible = false
		shield.ZIndex = 50
		shield.Parent = parent

		local box = Instance.new('Frame')
		box.Name = 'Box'
		box.Size = UDim2.fromOffset(14, 14)
		box.Position = UDim2.fromOffset(21, 13)
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 1
		box.BorderColor3 = Color3.fromRGB(62, 62, 70)
		box.ZIndex = 51
		box.Parent = shield

		local fill = Instance.new('Frame')
		fill.Name = 'Fill'
		fill.Size = UDim2.new(1, -2, 1, -2)
		fill.Position = UDim2.fromOffset(1, 1)
		fill.BackgroundTransparency = 1
		fill.BorderSizePixel = 0
		fill.ZIndex = 52
		fill.Parent = box
		return shield, box, fill
	end

	local applymod
	local refreshfav
	local updateheads

	local function hiddencount(cat)
		local count = 0
		if cat == 'Favorites' then
			for name in pairs(state.favorites) do
				if state.hidden[name] and vape.Modules[name] then count += 1 end
			end
			return count
		end
		for name, mod in pairs(vape.Modules) do
			if type(mod) == 'table' and mod.Category == cat and state.hidden[name] then count += 1 end
		end
		return count
	end

	local function sethidden(name, on, skip)
		if not vape.Modules[name] then return end
		state.hidden[name] = on and true or nil
		syncapi()
		if applymod then applymod(vape.Modules[name]) end
		if refreshfav then refreshfav() end
		if updateheads then updateheads() end
		if not skip then queue() end
	end

	local function setfavorite(name, on, skip)
		if not vape.Modules[name] then return end
		state.favorites[name] = on and true or nil
		syncapi()
		if applymod then applymod(vape.Modules[name]) end
		if refreshfav then refreshfav() end
		if not skip then queue() end
	end

	local function setediting(on)
		state.editing = on and true or false
		syncapi()
		for _, mod in pairs(vape.Modules) do
			if type(mod) == 'table' and mod.Children then mod.Children.Visible = false end
		end
		for _, data in pairs(mods) do applymod(data.mod) end
		refreshfav()
		updateheads()
	end

	local function addheader(name, cat)
		if heads[name] or name == 'Main' or type(cat) ~= 'table' or cat.Type ~= 'Category'
			or not inst(cat.Object) then return end
		local window = cat.Object
		local edit = Instance.new('ImageButton')
		edit.Name = 'VTEditHidden'
		edit.Size = UDim2.fromOffset(30, 40)
		edit.Position = UDim2.new(1, -68, 0, 0)
		edit.BackgroundTransparency = 1
		edit.AutoButtonColor = false
		edit.Image = editicon
		edit.ImageColor3 = Color3.fromRGB(120, 120, 128)
		edit.ImageRectSize = Vector2.zero
		edit.ScaleType = Enum.ScaleType.Fit
		edit.Visible = false
		edit.ZIndex = 5
		edit.Parent = window
		if editicon == '' then
			local txt = Instance.new('TextLabel')
			txt.Size = UDim2.fromScale(1, 1)
			txt.BackgroundTransparency = 1
			txt.Text = '✎'
			txt.TextColor3 = Color3.fromRGB(150, 150, 158)
			txt.TextSize = 16
			txt.Parent = edit
		end

		local done = Instance.new('TextButton')
		done.Name = 'VTDoneHidden'
		done.Size = UDim2.fromOffset(58, 40)
		done.Position = UDim2.new(1, -82, 0, 0)
		done.BackgroundTransparency = 1
		done.AutoButtonColor = false
		done.Text = 'DONE'
		done.TextColor3 = Color3.fromRGB(150, 150, 158)
		done.TextSize = 12
		done.Font = Enum.Font.Gotham
		done.Visible = false
		done.ZIndex = 5
		done.Parent = window

		local count = Instance.new('TextButton')
		count.Name = 'VTHiddenCount'
		count.Size = UDim2.fromOffset(48, 40)
		count.Position = UDim2.new(1, -76, 0, 0)
		count.BackgroundTransparency = 1
		count.AutoButtonColor = false
		count.Text = ''
		count.Visible = false
		count.ZIndex = 5
		count.Parent = window

		local num = Instance.new('TextLabel')
		num.Name = 'Count'
		num.Size = UDim2.fromOffset(14, 40)
		num.Position = UDim2.fromOffset(2, 0)
		num.BackgroundTransparency = 1
		num.Text = '0'
		num.TextColor3 = Color3.fromRGB(145, 145, 153)
		num.TextSize = 13
		num.Font = Enum.Font.Gotham
		num.ZIndex = 6
		num.Parent = count

		local eye = Instance.new('ImageLabel')
		eye.Name = 'Eye'
		eye.Size = UDim2.fromOffset(22, 22)
		eye.Position = UDim2.fromOffset(16, 9)
		eye.BackgroundTransparency = 1
		eye.Image = hiddeneye
		eye.ImageColor3 = Color3.fromRGB(118, 118, 126)
		eye.ScaleType = Enum.ScaleType.Fit
		eye.ZIndex = 6
		eye.Parent = count
		if hiddeneye == '' then
			local txt = Instance.new('TextLabel')
			txt.Size = UDim2.fromScale(1, 1)
			txt.BackgroundTransparency = 1
			txt.Text = '◉'
			txt.TextColor3 = eye.ImageColor3
			txt.TextSize = 15
			txt.ZIndex = 7
			txt.Parent = eye
		end

		local data = {cat = cat, window = window, edit = edit, done = done, count = count, num = num, hover = false}
		heads[name] = data
		ctx:clean(edit.MouseButton1Click:Connect(function() setediting(true) end))
		ctx:clean(count.MouseButton1Click:Connect(function() setediting(true) end))
		ctx:clean(done.MouseButton1Click:Connect(function() setediting(false) end))
		ctx:clean(edit.MouseEnter:Connect(function() edit.ImageColor3 = Color3.fromRGB(225, 225, 230) end))
		ctx:clean(edit.MouseLeave:Connect(function() edit.ImageColor3 = Color3.fromRGB(120, 120, 128) end))
		ctx:clean(window.MouseEnter:Connect(function()
			data.hover = true
			updateheads()
		end))
		ctx:clean(window.MouseLeave:Connect(function()
			data.hover = false
			updateheads()
		end))
	end

	updateheads = function()
		for name, data in pairs(heads) do
			local count = hiddencount(name)
			data.num.Text = tostring(count)
			data.done.Visible = state.editing
			data.edit.Visible = not state.editing and data.hover
			data.count.Visible = not state.editing and not data.hover and count > 0
		end
	end

	local function boxstate(data, hidden, mod)
		data.box.BorderColor3 = hidden and Color3.fromRGB(62, 62, 70) or Color3.fromRGB(235, 235, 240)
		data.fill.BackgroundColor3 = accent(mod)
		data.fill.BackgroundTransparency = hidden and 1 or 0
	end

	local function addmod(mod)
		if type(mod) ~= 'table' or mods[mod] or not inst(mod.Object) or type(mod.Name) ~= 'string' then return end
		local row = mod.Object
		local star = Instance.new('ImageButton')
		star.Name = 'VTFavorite'
		star.Size = UDim2.fromOffset(22, 22)
		star.Position = UDim2.new(1, -61, 0, 8)
		star.AnchorPoint = Vector2.new(1, 0)
		star.BackgroundTransparency = 1
		star.AutoButtonColor = false
		star.Visible = false
		star.ZIndex = 20
		star.Parent = row
		fallbackstar(star)

		local shield, box, fill = checkbox(row)
		local data = {
			mod = mod,
			row = row,
			star = star,
			shield = shield,
			box = box,
			fill = fill,
			dots = row:FindFirstChild('Dots'),
			bind = row:FindFirstChild('Bind'),
			text = row.Text,
			hover = false
		}
		mods[mod] = data

		ctx:clean(star.MouseButton1Click:Connect(function()
			setfavorite(mod.Name, not state.favorites[mod.Name])
		end))
		ctx:clean(star.MouseEnter:Connect(function()
			data.starhover = true
			setstar(star, state.favorites[mod.Name], true)
		end))
		ctx:clean(star.MouseLeave:Connect(function()
			data.starhover = false
			setstar(star, state.favorites[mod.Name], false)
		end))
		ctx:clean(shield.MouseButton1Click:Connect(function()
			sethidden(mod.Name, not state.hidden[mod.Name])
		end))
		ctx:clean(row.MouseEnter:Connect(function()
			data.hover = true
			applymod(mod)
		end))
		ctx:clean(row.MouseLeave:Connect(function()
			data.hover = false
			applymod(mod)
		end))
		if inst(mod.Children) then
			ctx:clean(mod.Children:GetPropertyChangedSignal('Visible'):Connect(function() applymod(mod) end))
		end
		applymod(mod)
	end

	applymod = function(mod)
		local data = mods[mod]
		if not data or not inst(data.row) then return end
		local hidden = state.hidden[mod.Name] == true
		local edit = state.editing
		if hidden and not edit and inst(mod.Children) then mod.Children.Visible = false end
		data.row.Visible = edit or not hidden
		data.shield.Visible = edit
		data.row.Text = edit and ('    '..mod.Name:gsub(' ', '')) or data.text
		if inst(data.dots) then data.dots.Visible = not edit end
		if inst(data.bind) then
			local bound = type(mod.Bind) == 'table' and (#mod.Bind > 0 or mod.Bind.Mobile == true)
			data.bind.Visible = not edit and (bound or data.hover or inst(mod.Children) and mod.Children.Visible)
		end
		data.star.Visible = not edit and (data.hover or inst(mod.Children) and mod.Children.Visible)
		boxstate(data, hidden, mod)
		setstar(data.star, state.favorites[mod.Name] == true, data.starhover)
	end

	local function openmod(mod)
		local cat = vape.Categories[mod.Category]
		if type(cat) ~= 'table' then return end
		if cat.Button and not cat.Button.Enabled and type(cat.Button.Toggle) == 'function' then
			pcall(cat.Button.Toggle, cat.Button)
		end
		if cat.Expanded == false and type(cat.Expand) == 'function' then pcall(cat.Expand, cat) end
		if inst(mod.Children) then mod.Children.Visible = true end
	end

	local function syncrow(data)
		local mod = data.mod
		local src = mod.Object
		local row = data.row
		if not inst(src) or not inst(row) then return end
		row.BackgroundColor3 = src.BackgroundColor3
		row.TextColor3 = src.TextColor3
		row.TextSize = src.TextSize
		row.FontFace = src.FontFace
		local sg = src:FindFirstChildWhichIsA('UIGradient')
		local dg = row:FindFirstChildWhichIsA('UIGradient')
		if sg and dg then
			dg.Enabled = sg.Enabled
			dg.Color = sg.Color
		end
		local sd = src:FindFirstChild('Dots')
		local dd = row:FindFirstChild('Dots')
		local si = sd and sd:FindFirstChild('Dots')
		local di = dd and dd:FindFirstChild('Dots')
		if si and di then di.ImageColor3 = si.ImageColor3 end
		local sb = src:FindFirstChild('Bind')
		local db = row:FindFirstChild('Bind')
		if sb and db then
			db.Visible = not state.editing and sb.Visible
			db.Size = sb.Size
			local sit = sb:FindFirstChild('Text')
			local dit = db:FindFirstChild('Text')
			if sit and dit then
				dit.Text = sit.Text
				dit.Visible = sit.Visible
			end
			local sii = sb:FindFirstChild('Icon')
			local dii = db:FindFirstChild('Icon')
			if sii and dii then
				dii.Image = sii.Image
				dii.ImageColor3 = sii.ImageColor3
				dii.Visible = sii.Visible
			end
		end
	end

	local function makerow(mod)
		if rows[mod.Name] or not inst(mod.Object) or not inst(favchildren) then return end
		local row = mod.Object:Clone()
		row.Name = 'VT_'..mod.Name
		row.Parent = favchildren
		local oldstar = row:FindFirstChild('VTFavorite')
		if oldstar then oldstar:Destroy() end
		local oldshield = row:FindFirstChild('VTHideShield')
		if oldshield then oldshield:Destroy() end

		local star = Instance.new('ImageButton')
		star.Name = 'VTFavorite'
		star.Size = UDim2.fromOffset(22, 22)
		star.Position = UDim2.new(1, -61, 0, 8)
		star.AnchorPoint = Vector2.new(1, 0)
		star.BackgroundTransparency = 1
		star.AutoButtonColor = false
		star.Visible = false
		star.ZIndex = 20
		star.Parent = row
		fallbackstar(star)
		local shield, box, fill = checkbox(row)
		local data = {
			mod = mod,
			row = row,
			star = star,
			shield = shield,
			box = box,
			fill = fill,
			hover = false
		}
		rows[mod.Name] = data
		ctx:clean(row.MouseEnter:Connect(function() data.hover = true end))
		ctx:clean(row.MouseLeave:Connect(function() data.hover = false end))
		ctx:clean(row.MouseButton1Click:Connect(function()
			if not state.editing then
				pcall(mod.Toggle, mod)
				syncrow(data)
			end
		end))
		ctx:clean(row.MouseButton2Click:Connect(function()
			if not state.editing then openmod(mod) end
		end))
		local dots = row:FindFirstChild('Dots')
		if dots and dots:IsA('GuiButton') then
			ctx:clean(dots.MouseButton1Click:Connect(function()
				if not state.editing then openmod(mod) end
			end))
		end
		ctx:clean(star.MouseButton1Click:Connect(function() setfavorite(mod.Name, false) end))
		ctx:clean(star.MouseEnter:Connect(function() data.starhover = true end))
		ctx:clean(star.MouseLeave:Connect(function() data.starhover = false end))
		ctx:clean(shield.MouseButton1Click:Connect(function()
			sethidden(mod.Name, not state.hidden[mod.Name])
		end))
		syncrow(data)
	end

	refreshfav = function()
		for name, data in pairs(copy(rows)) do
			if not state.favorites[name] or not vape.Modules[name] then
				if inst(data.row) then data.row:Destroy() end
				rows[name] = nil
			end
		end
		local list = tolist(state.favorites)
		for order, name in ipairs(list) do
			local mod = vape.Modules[name]
			if mod then
				makerow(mod)
				local data = rows[name]
				if data and inst(data.row) then
					data.row.LayoutOrder = order
					local hidden = state.hidden[name] == true
					data.row.Visible = state.editing or not hidden
					data.shield.Visible = state.editing
					data.row.Text = state.editing and ('    '..mod.Name:gsub(' ', '')) or mods[mod] and mods[mod].text or data.row.Text
					local dots = data.row:FindFirstChild('Dots')
					if dots then dots.Visible = not state.editing end
					local bind = data.row:FindFirstChild('Bind')
					if bind then bind.Visible = not state.editing and bind.Visible end
					data.star.Visible = not state.editing and data.hover
					boxstate(data, hidden, mod)
					setstar(data.star, true, data.starhover)
					syncrow(data)
				end
			end
		end
		syncapi()
	end

	local function wrapcat(cat)
		if wraps[cat] or cat == fav or type(cat) ~= 'table' or type(cat.CreateModule) ~= 'function' then return end
		local old = cat.CreateModule
		local wrap
		wrap = function(self, ...)
			local mod = old(self, ...)
			task.defer(function()
				if alive then
					addmod(mod)
					refreshfav()
					updateheads()
				end
			end)
			return mod
		end
		cat.CreateModule = wrap
		wraps[cat] = {old = old, wrap = wrap}
	end

	local function applysearch()
		local root = vape.gui
		if not inst(root) then return end
		local search = root:FindFirstChild('Search', true)
		local holder = search and search:FindFirstChild('Children')
		if not inst(holder) then return end
		for _, row in ipairs(holder:GetChildren()) do
			if row:IsA('TextButton') then
				row.Visible = not state.hidden[row.Name]
				local star = row:FindFirstChild('VTFavorite')
				if star then star:Destroy() end
				local shield = row:FindFirstChild('VTHideShield')
				if shield then shield:Destroy() end
			end
		end
	end

	local function reorder()
		local main = vape.Categories.Main
		local holder = main and main.Object and main.Object:FindFirstChild('Children')
		local button = fav and fav.Button and fav.Button.Object
		if not inst(holder) or not inst(button) then return end
		local list = {}
		for _, obj in ipairs(holder:GetChildren()) do
			if obj:IsA('GuiObject') and obj ~= button then list[#list + 1] = obj end
		end
		local out = {}
		local added = false
		for _, obj in ipairs(list) do
			out[#out + 1] = obj
			if obj.Name == 'Minigames' then
				out[#out + 1] = button
				added = true
			end
		end
		if not added then out[#out + 1] = button end
		for order, obj in ipairs(out) do obj.LayoutOrder = order end
	end

	load()
	fav = vape:CreateCategory({
		Name = 'Favorites',
		Icon = favoritetab,
		Size = UDim2.fromOffset(25, 25)
	})
	favchildren = fav.Object and fav.Object:FindFirstChild('Children')
	reorder()

	apiold.Favorites = vape.Favorites
	apiold.Hidden = vape.Hidden
	for _, name in ipairs({'IsFavorite', 'SetFavorite', 'RefreshFavorites', 'IsHidden', 'SetHidden', 'SetHiddenEditing', 'RefreshHiddenModules'}) do
		apiold[name] = vape[name]
	end
	vape.Favorites = {List = {}, Rows = rows}
	vape.Hidden = {List = {}, Editing = false}
	vape.IsFavorite = function(_, name) return state.favorites[name] == true end
	vape.SetFavorite = function(_, name, on, skip) setfavorite(name, on, skip) end
	vape.RefreshFavorites = function() refreshfav() end
	vape.IsHidden = function(_, name) return state.hidden[name] == true end
	vape.SetHidden = function(_, name, on, skip) sethidden(name, on, skip) end
	vape.SetHiddenEditing = function(_, on) setediting(on) end
	vape.RefreshHiddenModules = function()
		for _, data in pairs(mods) do applymod(data.mod) end
		refreshfav()
		updateheads()
	end
	syncapi()

	local function scan()
		for name, cat in pairs(vape.Categories) do
			if name ~= 'Main' then
				addheader(name, cat)
				wrapcat(cat)
			end
		end
		for _, mod in pairs(vape.Modules) do addmod(mod) end
		for mod, data in pairs(copy(mods)) do
			if vape.Modules[mod.Name] ~= mod or not inst(data.row) then
				mods[mod] = nil
			end
		end
		refreshfav()
		updateheads()
		applysearch()
	end

	scan()
	local elapsed = 0
	ctx:clean(run.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then return end
		elapsed = 0
		local current = ctx.profile and ctx.profile.dir or 'default'
		if current ~= profile then
			save(profile)
			load()
		end
		scan()
		for _, data in pairs(mods) do applymod(data.mod) end
		for _, data in pairs(rows) do
			syncrow(data)
			data.star.Visible = not state.editing and data.hover
			setstar(data.star, true, data.starhover)
		end
	end))

	ctx:clean(function()
		if not alive then return end
		save(profile)
		alive = false
		for cat, data in pairs(wraps) do
			if cat.CreateModule == data.wrap then cat.CreateModule = data.old end
		end
		for mod, data in pairs(mods) do
			if inst(data.row) then
				data.row.Visible = true
				data.row.Text = data.text
			end
			if inst(data.star) then data.star:Destroy() end
			if inst(data.shield) then data.shield:Destroy() end
			if inst(data.dots) then data.dots.Visible = true end
		end
		for _, data in pairs(rows) do if inst(data.row) then data.row:Destroy() end end
		for _, data in pairs(heads) do
			if inst(data.edit) then data.edit:Destroy() end
			if inst(data.done) then data.done:Destroy() end
			if inst(data.count) then data.count:Destroy() end
		end
		if fav then
			if fav.Button and fav.Button.Enabled and type(fav.Button.Toggle) == 'function' then pcall(fav.Button.Toggle, fav.Button) end
			if fav.Button and inst(fav.Button.Object) then fav.Button.Object:Destroy() end
			if inst(fav.Object) then fav.Object:Destroy() end
			if vape.Categories.Favorites == fav then vape.Categories.Favorites = nil end
			local main = vape.Categories.Main
			if main and type(main.Buttons) == 'table' and main.Buttons.Favorites == fav.Button then
				main.Buttons.Favorites = nil
			end
		end
		vape.Favorites = apiold.Favorites
		vape.Hidden = apiold.Hidden
		for _, name in ipairs({'IsFavorite', 'SetFavorite', 'RefreshFavorites', 'IsHidden', 'SetHidden', 'SetHiddenEditing', 'RefreshHiddenModules'}) do
			vape[name] = apiold[name]
		end
	end)
end
