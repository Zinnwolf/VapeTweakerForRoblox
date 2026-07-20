local loader = ...
assert(type(loader) == 'table' and type(loader.Load) == 'function', '[VapeTweaker] invalid loader context')

local env = (getgenv and getgenv()) or _G
local previous = env.VapeTweaker
if type(previous) == 'table' and type(previous.Unload) == 'function' then
	pcall(function()
		previous:Unload('reload')
	end)
end

local context = {
	Name = 'VapeTweaker',
	Version = '0.1.0',
	Loader = loader,
	Config = loader.Config or {},
	State = 'starting',
	StartedAt = os.clock(),
	Adapters = {},
	Modules = {},
	ModuleOrder = {}
}

env.VapeTweaker = context

local manifest = loader:Load('src/manifest.lua')
assert(type(manifest) == 'table', '[VapeTweaker] manifest did not return a table')

local function initialize(path)
	local initializer = loader:Load(path)
	assert(type(initializer) == 'function', '[VapeTweaker] '..path..' must return an initializer function')
	initializer(context)
end

local ok, failure = xpcall(function()
	for _, path in ipairs(manifest.Core or {}) do
		initialize(path)
	end

	context.Vape = context.Adapters.Vape:Attach()

	for _, path in ipairs(manifest.Modules or {}) do
		initialize(path)
	end

	context.State = 'loaded'
	context.Logger:Info('attached to Vape; %d tweaker module(s) loaded', #context.ModuleOrder)
	context.Logger:Notify('VapeTweaker', 'Attached successfully', 4)
end, function(message)
	return debug and debug.traceback and debug.traceback(tostring(message), 2) or tostring(message)
end)

if not ok then
	context.State = 'failed'
	if context.Logger then
		context.Logger:Error('%s', failure)
	else
		warn('[VapeTweaker] '..tostring(failure))
	end
	pcall(function()
		context:Unload('startup failure')
	end)
	return nil
end

return context
