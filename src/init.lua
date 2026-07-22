local ld = ...
if type(ld) ~= 'table' or type(ld.run) ~= 'function' then error('invalid VapeTweaker loader', 0) end

local env = (getgenv and getgenv()) or _G
local paths = {
	log = 'src/core/log.lua',
	clean = 'src/core/clean.lua',
	storage = 'src/core/storage.lua',
	adapter = 'src/adapters/vape.lua',
	target = 'src/core/target.lua',
	patch = 'src/core/patch.lua',
	runtime = 'src/core/runtime.lua',
	profile = 'src/core/profile.lua',
	config = 'src/core/config.lua',
	layers = 'src/core/layers.lua'
}
local init = {}

for name, path in pairs(paths) do
	local fn = ld:run(path)
	if type(fn) ~= 'function' then error(path..' must return a function', 0) end
	init[name] = fn
end
local cats = ld:run('src/categories.lua')
if type(cats) ~= 'table' or type(cats.order) ~= 'table' or type(cats.names) ~= 'table' then
	error('invalid category map', 0)
end

local old = env.VapeTweaker
if type(old) == 'table' then
	local unload = type(old.unload) == 'function' and old.unload or old.Unload
	if type(unload) == 'function' then
		local ok, done = pcall(unload, old, 'reload')
		if not ok or done == false then error('previous runtime unload failed: '..tostring(done), 0) end
	end
end

local ctx = {
	name = 'VapeTweaker',
	version = ld.version,
	loader = ld,
	cfg = ld.cfg,
	state = 'starting',
	started = os.clock(),
	cats = cats,
	mods = {},
	modorder = {},
	patchopts = {},
	layers = {},
	events = {}
}

init.log(ctx)
init.clean(ctx)
init.storage(ctx)
init.adapter(ctx)
init.target(ctx)
init.patch(ctx)
init.runtime(ctx)
init.layers(ctx)

local function trace(msg)
	if ctx.cfg.debug and debug and type(debug.traceback) == 'function' then
		return debug.traceback(tostring(msg), 2)
	end
	return tostring(msg)
end

local ok, msg = xpcall(function()
	ctx.vape = ctx.vapeapi:attach()
	ctx.vapeapi:reindex()
	ctx:resolvetarget()
	init.profile(ctx)
	init.config(ctx)
	ctx.vapeapi:hook()
	ctx:loadlayers()
	if not ctx.config:capture() then error('configuration baseline could not be captured', 0) end
	ctx.config:load()
	if not ctx.config:restore() then error('configuration could not be restored', 0) end
	ctx.config:watch()
	ctx.state = 'loaded'
	ctx.config:index()

	local session = {
		version = ctx.version,
		build = ld.build,
		started = ctx.started,
		profile = ctx.profile.name,
		target = ctx.target,
		layers = ctx.layers
	}
	local raw = ctx.store:encode(session, 'state/session.json')
	if raw then ctx.store:write('state/session.json', raw) end
end, trace)

if not ok then
	ctx.log:add('startup', nil, msg, true)
	ctx:unload('startup failure')
	error(msg, 0)
end

env.VapeTweaker = ctx
ctx.vapeapi:notify('VapeTweaker', 'Loaded', 4, 'info')
return ctx
