table.clone = table.clone or function(src)
	local out = {}
	for key, val in pairs(src) do out[key] = val end
	return out
end
table.clear = table.clear or function(src)
	for key in pairs(src) do src[key] = nil end
end

local flags = {}
local old = {
	state = 'loaded',
	modorder = {{name = 'OldModule', obj = {}}},
	unload = function() return false end,
	vapeapi = {
		unhook = function() flags.unhook = true end,
		remove = function(_, name) flags.removed = name return true end
	},
	patchsys = {restore = function() flags.restore = true return true end},
	config = {unwatch = function() flags.unwatch = true end},
	bin = {run = function() flags.clean = true return true end}
}
local env = {VapeTweaker = old}
getgenv = function() return env end

local function noop() end
local function setup(path)
	if path == 'src/core/log.lua' then
		return function(ctx)
			ctx.log = {history = {}, add = function(self, kind, file, msg)
				self.history[#self.history + 1] = {kind = kind, path = file, message = tostring(msg)}
			end}
		end
	elseif path == 'src/core/clean.lua' then
		return function(ctx) ctx.bin = {run = function() return true end} end
	elseif path == 'src/core/storage.lua' then
		return function(ctx)
			ctx.store = {
				fs = {write = false},
				encode = function() return '{}' end,
				write = function() return true end
			}
		end
	elseif path == 'src/adapters/vape.lua' then
		return function(ctx)
			ctx.vapeapi = {
				attach = function() return {Loaded = true, Modules = {}, Categories = {}} end,
				reindex = noop,
				hook = noop,
				notify = noop,
				unhook = noop,
				remove = function() return true end
			}
		end
	elseif path == 'src/core/target.lua' then
		return function(ctx)
			function ctx:resolvetarget()
				self.target = {gameid = 1, buildid = 2, placeid = 3}
			end
		end
	elseif path == 'src/core/patch.lua' then
		return function(ctx) ctx.patchsys = {order = {}, restore = function() return true end} end
	elseif path == 'src/core/runtime.lua' then
		return function(ctx)
			function ctx:unload() self.state = 'unloaded' return true end
		end
	elseif path == 'src/core/profile.lua' then
		return function(ctx) ctx.profile = {name = 'default'} end
	elseif path == 'src/core/config.lua' then
		return function(ctx)
			ctx.config = {
				capture = function() return true end,
				load = noop,
				restore = function() return true end,
				watch = noop,
				index = noop
			}
		end
	elseif path == 'src/core/layers.lua' then
		return function(ctx) function ctx:loadlayers() end end
	elseif path == 'src/categories.lua' then
		return {order = {'render'}, names = {render = 'Render'}}
	end
	error('unexpected path '..path)
end

local ld = {
	version = '1.2.0',
	build = '1.2.0',
	cfg = {debug = false},
	run = function(_, path) return setup(path) end
}

local result = assert(loadfile('src/init.lua'))(ld)
assert(result and result.state == 'loaded')
assert(env.VapeTweaker == result)
assert(old.state == 'unloaded')
assert(flags.unhook and flags.restore and flags.unwatch and flags.clean)
assert(flags.removed == 'OldModule')
