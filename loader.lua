-- VapeTweaker barebones loader.
-- Configure getgenv().VapeTweakerConfig before executing when using a remote repository.

local env = (getgenv and getgenv()) or _G
local config = env.VapeTweakerConfig or {}
local root = config.Root or 'VapeTweaker'
local baseUrl = config.BaseUrl
local cacheRoot = root..'/cache'

local nativeLoadstring = loadstring
assert(type(nativeLoadstring) == 'function', '[VapeTweaker] loadstring is unavailable')

local function fileExists(path)
	if type(isfile) == 'function' then
		local ok, result = pcall(isfile, path)
		return ok and result == true
	end

	if type(readfile) == 'function' then
		local ok, result = pcall(readfile, path)
		return ok and type(result) == 'string' and result ~= ''
	end

	return false
end

local function ensureFolder(path)
	if type(makefolder) ~= 'function' then
		return
	end

	local current = ''
	for part in path:gmatch('[^/\\]+') do
		current = current == '' and part or (current..'/'..part)
		if type(isfolder) ~= 'function' or not isfolder(current) then
			pcall(makefolder, current)
		end
	end
end

local function normalize(path)
	return tostring(path):gsub('\\', '/'):gsub('^/+', '')
end

local function readLocal(path)
	if type(readfile) ~= 'function' then
		return nil
	end

	local fullPath = root..'/'..normalize(path)
	if not fileExists(fullPath) then
		return nil
	end

	local ok, source = pcall(readfile, fullPath)
	return ok and source or nil
end

local function cachePath(path)
	return cacheRoot..'/'..normalize(path)
end

local function readCache(path)
	if config.DisableCache then
		return nil
	end

	local fullPath = cachePath(path)
	if not fileExists(fullPath) or type(readfile) ~= 'function' then
		return nil
	end

	local ok, source = pcall(readfile, fullPath)
	return ok and source or nil
end

local function writeCache(path, source)
	if config.DisableCache or type(writefile) ~= 'function' then
		return
	end

	local fullPath = cachePath(path)
	local folder = fullPath:match('^(.*)/[^/]+$')
	if folder then
		ensureFolder(folder)
	end
	pcall(writefile, fullPath, source)
end

local function fetchRemote(path)
	assert(type(baseUrl) == 'string' and baseUrl ~= '',
		'[VapeTweaker] file was not found locally and VapeTweakerConfig.BaseUrl is not configured')

	local url = baseUrl:gsub('/+$', '')..'/'..normalize(path)
	local ok, source = pcall(function()
		return game:HttpGet(url, true)
	end)

	if not ok or type(source) ~= 'string' or source == '' or source == '404: Not Found' then
		error('[VapeTweaker] failed to download '..path..': '..tostring(source), 0)
	end

	writeCache(path, source)
	return source
end

local function getSource(path)
	path = normalize(path)

	if config.PreferRemote ~= true then
		local localSource = readLocal(path)
		if localSource then
			return localSource, 'local'
		end
	end

	local ok, remoteSource = pcall(fetchRemote, path)
	if ok then
		return remoteSource, 'remote'
	end

	local cachedSource = readCache(path)
	if cachedSource then
		warn('[VapeTweaker] using cached '..path..' because remote loading failed')
		return cachedSource, 'cache'
	end

	if config.PreferRemote == true then
		local localSource = readLocal(path)
		if localSource then
			warn('[VapeTweaker] using local '..path..' because remote loading failed')
			return localSource, 'local'
		end
	end

	error(remoteSource, 0)
end

local loader = {
	Config = config,
	Root = root,
	BaseUrl = baseUrl,
	GetSource = getSource
}

function loader:Load(path, ...)
	local source, origin = getSource(path)
	local chunk, compileError = nativeLoadstring(source, '@VapeTweaker/'..normalize(path))
	if not chunk then
		error(('[VapeTweaker] failed to compile %s from %s:\n%s'):format(path, origin, tostring(compileError)), 0)
	end

	return chunk(...)
end

local ok, result = xpcall(function()
	return loader:Load('src/init.lua', loader)
end, function(message)
	return debug and debug.traceback and debug.traceback(tostring(message), 2) or tostring(message)
end)

if not ok then
	warn('[VapeTweaker] startup failed:\n'..tostring(result))
	return nil
end

return result
