table.clone = table.clone or function(src)
	local out = {}
	for key, val in pairs(src) do out[key] = val end
	return out
end
table.clear = table.clear or function(src)
	for key in pairs(src) do src[key] = nil end
end
table.find = table.find or function(src, wanted)
	for key, val in pairs(src) do if val == wanted then return key end end
end

task = task or {
	spawn = function(fn) return fn() end,
	wait = function() end
}

local function option(name, value)
	local opt = {Name = name, Value = value, Type = 'Slider'}
	function opt:Save(out)
		out[self.Name] = {Value = self.Value}
	end
	function opt:Load(data)
		self.Value = data.Value
	end
	function opt:SetValue(val)
		self.Value = val
	end
	return opt
end

local log = {history = {}}
function log:add(kind, path, message)
	self.history[#self.history + 1] = {kind = kind, path = path, message = tostring(message)}
end
function log:list(kind)
	local out = {}
	for _, item in ipairs(self.history) do
		if not kind or item.kind == kind then out[#out + 1] = table.clone(item) end
	end
	return out
end

local native = {
	Name = 'Fly',
	Enabled = false,
	Options = {},
	Tooltip = 'native',
	Function = function(value) return value + 1 end
}
local speed = option('Speed', 2)
native.Options.Speed = speed

local ctx = {
	cfg = {debounce = 0},
	log = log,
	state = 'starting',
	loading = {scope = 'universal', path = 'tests/smoke.lua'},
	mods = {},
	modorder = {},
	patchopts = {},
	target = {gameid = 10, placeid = 20, buildid = 30},
	profile = {name = 'default', dir = 'default'},
	store = {
		fs = {read = false, write = false, folders = false, delete = false},
		read = function() end,
		write = function() return false end,
		remove = function() return false end,
		encode = function() end,
		decode = function() end
	}
}

local registry = {Fly = native}
ctx.vapeapi = {
	find = function(_, name) return registry[name] end,
	getprop = function(_, obj, prop)
		if prop == '@value' then
			local out = {}
			obj:Save(out)
			return true, out[obj.Name]
		end
		return true, obj[prop]
	end,
	setprop = function(_, obj, prop, val)
		if prop == '@value' then obj:Load(val) else obj[prop] = val end
		return true
	end,
	snapshotoption = function(_, opt)
		local out = {}
		opt:Save(out)
		return out[opt.Name], true
	end,
	loadoption = function(_, opt, data)
		if type(data) ~= 'table' then return false end
		opt:Load(data)
		return true
	end,
	createoption = function(_, mod, _, def)
		local opt = option(def.name, def.default)
		mod.Options[def.name] = opt
		return opt
	end,
	removeoption = function(_, mod, name, opt)
		if mod.Options[name] == opt then mod.Options[name] = nil end
		return true
	end,
	optionkeys = function(_, _, def) return {def.name} end,
	savebind = function(_, mod) return table.clone(mod.Bind) end,
	setbind = function(_, mod, bind) mod.Bind = table.clone(bind) return true end
}

assert(loadfile('src/core/patch.lua'))()(ctx)
assert(loadfile('src/core/config.lua'))()(ctx)

local first = ctx:patch('Fly', 'chain-one')
assert(first:wrap('Function', function(old, value) return old(value) * 2 end))
local second = ctx:patch('Fly', 'chain-two')
assert(second:wrap('Function', function(old, value) return old(value) + 5 end))
assert(native.Function(3) == 13)
assert(first:disable() and native.Function(3) == 9)
assert(first:enable() and native.Function(3) == 13)
local rejected = ctx:patch('Fly', 'rejected-wrap')
assert(not rejected:wrap('Tooltip', function(old) return old end))
assert(ctx.patchsys.states[native].Tooltip == nil)
assert(ctx.patchsys:restore())
assert(native.Function(3) == 4 and native.Tooltip == 'native')

local seen
local owned = {Name = 'Owned', Enabled = false, Bind = {'Q'}, Options = {}}
owned.Options.Power = option('Power', 1)
function owned:Toggle()
	self.Enabled = not self.Enabled
	if self.Enabled then seen = self.Options.Power.Value end
end
function owned:SetBind(bind)
	self.Bind = table.clone(bind)
end
function owned:CreateToggle(def)
	local opt = option(def.Name, def.Default)
	self.Options[def.Name] = opt
	return opt
end
ctx.mods.Owned = {name = 'Owned', category = 'utility', obj = owned, scope = 'universal'}
ctx.modorder[1] = ctx.mods.Owned

local valuepatch = ctx:patch('Fly', 'managed-value')
assert(valuepatch:value(speed, {Value = 8}))
local shared = ctx:patch('Fly', 'shared-option')
assert(shared:manage(speed) == speed)
assert(#ctx.patchopts == 1 and speed.Value == 8)
assert(ctx.config:capture())
assert(ctx.config:nativesave(function()
	assert(speed.Value == 2)
	return 'saved'
end) == 'saved')
assert(speed.Value == 8)
ctx.config:nativeload(function()
	assert(speed.Value == 2)
	speed.Value = 5
end)
assert(speed.Value == 8)
assert(valuepatch:disable() and speed.Value == 5)
assert(valuepatch:enable() and speed.Value == 8)

ctx.config.memory.default = {
	universal = {
		version = 1,
		modules = {Owned = {enabled = false, bind = {'Q'}, options = {Power = {Value = 3}}}},
		patches = {['managed-value'] = {enabled = true, options = {Speed = {Value = 8}}}}
	},
	place = {version = 1, modules = {Owned = {enabled = true}}, patches = {}}
}
ctx.config:load()
assert(ctx.config:restore())
assert(owned.Enabled and owned.Options.Power.Value == 3 and seen == 3 and speed.Value == 8)

owned.Bind = {'R'}
owned.Options.Power.Value = 4
assert(ctx.config:save(false))
assert(ctx.config.layers.universal.modules.Owned.bind[1] == 'R')
assert(ctx.config.layers.universal.modules.Owned.options.Power.Value == 4)
assert(ctx.config.layers.place.modules.Owned.bind == nil)
assert(ctx.config.layers.place.modules.Owned.options == nil)

ctx.config.memory.default = {
	universal = {
		version = 1,
		modules = {Owned = {enabled = false, bind = {'Q'}, options = {Power = {Value = 3}}}},
		patches = {}
	},
	place = {version = 1, modules = {Owned = {enabled = true, options = {}}}, patches = {}}
}
ctx.config:load()
assert(ctx.config:restore())
assert(owned.Options.Power.Value == 3)
assert(ctx.config:save(false))
assert(next(ctx.config.layers.place.modules.Owned.options) == nil)
owned.Options.Power.Value = 7
assert(ctx.config:save(false))
assert(next(ctx.config.layers.place.modules.Owned.options) == nil)
assert(ctx.config.layers.universal.modules.Owned.options.Power.Value == 7)

ctx.config:watch()
local dynamic = owned:CreateToggle({Name = 'Dynamic', Default = false})
assert(ctx.config.watched[dynamic] and ctx.config.watched[dynamic].SetValue)

ctx.profile = {name = 'empty', dir = 'empty'}
ctx.config:setpaths()
ctx.config:load()
assert(ctx.config:restore())
assert(not owned.Enabled and owned.Options.Power.Value == 1 and speed.Value == 8)
assert(ctx.patchsys:restore())
ctx.config:unwatch()
assert(speed.Value == 5 and #ctx.patchopts == 0)

local cleanctx = {log = log}
assert(loadfile('src/core/clean.lua'))()(cleanctx)
local attempts = 0
cleanctx:clean(function()
	attempts = attempts + 1
	if attempts == 1 then error('retry') end
end)
assert(not cleanctx.bin:run() and attempts == 1)
assert(cleanctx.bin:run() and attempts == 2)
