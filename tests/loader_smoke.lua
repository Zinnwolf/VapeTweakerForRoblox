table.clone = table.clone or function(src)
	local out = {}
	for key, val in pairs(src) do out[key] = val end
	return out
end
table.clear = table.clear or function(src)
	for key in pairs(src) do src[key] = nil end
end
math.clamp = math.clamp or function(value, low, high)
	return math.max(low, math.min(high, value))
end

local env = {}
local files = {}
local folders = {}
local requestmode = 'remote'
local guid = 0
local sha = string.rep('a', 40)
local source = "local ld = ... return {state = 'loaded', loader = ld}"
local manifest = "return {categories = {}}"
local apiurls = {}

local function encode(value)
	local kind = type(value)
	if kind == 'nil' then return 'nil' end
	if kind == 'boolean' or kind == 'number' then return tostring(value) end
	if kind == 'string' then return string.format('%q', value) end
	assert(kind == 'table')
	local out = {}
	for key, item in pairs(value) do out[#out + 1] = '['..encode(key)..']='..encode(item) end
	return '{'..table.concat(out, ',')..'}'
end

local http = {}
function http:JSONEncode(value)
	return encode(value)
end
function http:JSONDecode(value)
	local fn = assert(load('return '..value, '@json'))
	return fn()
end
function http:GenerateGUID()
	guid = guid + 1
	return string.format('00000000-0000-0000-0000-%012d', guid)
end

game = {}
function game:GetService(name)
	assert(name == 'HttpService')
	return http
end
function game:HttpGet(url)
	if url:find('api.github.com', 1, true) then
		apiurls[#apiurls + 1] = url
		assert(url:find('?vt=', 1, true))
		if requestmode == 'mutable' then error('offline') end
		if url:find('/git/ref/heads/', 1, true) then
			return http:JSONEncode({object = {sha = sha}})
		end
		return http:JSONEncode({sha = sha})
	end
	if url:find('src/modules/manifest.lua', 1, true) then
		if requestmode == 'stale' then
			return url:find('/main/', 1, true) and 'return {categories = {"render"}}' or manifest
		end
		return manifest
	end
	assert(url:find('src/init.lua', 1, true))
	if requestmode == 'missing' then return '404: Not Found' end
	return source
end

task = {
	wait = function() end
}
loadstring = load
getgenv = function() return env end
makefolder = function(path) folders[path] = true end
isfolder = function(path) return folders[path] == true end
writefile = function(path, data)
	if path:match('%.tmp$') or path:match('%.bak$') then error('Illegal path') end
	files[path] = data
end
readfile = function(path)
	if files[path] == nil then error('missing') end
	return files[path]
end
isfile = function(path) return files[path] ~= nil end
delfile = function(path) files[path] = nil end
delfolder = function(path)
	for file in pairs(files) do
		if file == path or file:sub(1, #path + 1) == path..'/' then files[file] = nil end
	end
end

local first = assert(loadfile('loader.lua'))()
assert(first and first.state == 'loaded' and first.loader.mode == 'remote')
local metapath = 'VapeTweaker/cache/meta.json'
local backpath = 'VapeTweaker/cache/meta.bak.json'
local meta = http:JSONDecode(files[metapath])
assert(meta.schema == 5 and meta.good and meta.files['src/init.lua'].size == #source)
assert(files[backpath] == files[metapath])

requestmode = 'missing'
local fallback = assert(loadfile('loader.lua'))()
assert(fallback and fallback.loader.mode == 'cache' and fallback.loader.recovered)

files[metapath] = '{}'
local backup = files[backpath]
local recovered = assert(loadfile('loader.lua'))()
assert(recovered and recovered.loader.mode == 'cache')
assert(files[backpath] == backup)

requestmode = 'mutable'
local before = files[backpath]
local mutable = assert(loadfile('loader.lua'))()
assert(mutable and mutable.loader.mode == 'remote')
assert(mutable.loader.moving and not mutable.loader.immutable)
assert(files[backpath] == before and files[metapath] == '{}')

requestmode = 'stale'
local stale = assert(loadfile('loader.lua'))()
assert(stale and stale.loader.mode == 'remote')
assert(stale.loader.moving and not stale.loader.immutable)
assert(#stale.loader.errors >= 1 and stale.loader.errors[1].kind == 'revision')

assert(#apiurls >= 5)
for path in pairs(files) do
	assert(not path:match('%.tmp$'))
	assert(not path:match('%.bak$'))
end
