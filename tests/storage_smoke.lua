table.clone = table.clone or function(src)
	local out = {}
	for key, val in pairs(src) do out[key] = val end
	return out
end

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
function http:JSONEncode(value) return encode(value) end
function http:JSONDecode(value) return assert(load('return '..value, '@json'))() end

game = {}
function game:GetService(name)
	assert(name == 'HttpService')
	return http
end

local files = {}
local folders = {}
makefolder = function(path) folders[path] = true end
isfolder = function(path) return folders[path] == true end
isfile = function(path) return files[path] ~= nil end
readfile = function(path)
	if files[path] == nil then error('missing') end
	return files[path]
end
writefile = function(path, data)
	if path:match('%.tmp$') or path:match('%.bak$') then error('Illegal path') end
	files[path] = data
end
delfile = function(path) files[path] = nil end

local log = {history = {}}
function log:add(kind, path, message)
	self.history[#self.history + 1] = {kind = kind, path = path, message = tostring(message)}
end

local ctx = {
	loader = {root = 'VapeTweaker'},
	log = log,
	cfg = {debounce = 0},
	profile = {name = 'default', dir = 'default'},
	target = {gameid = 1, buildid = 2, placeid = 3},
	mods = {},
	modorder = {},
	patchopts = {},
	patchsys = {order = {}},
	vapeapi = {}
}

assert(loadfile('src/core/storage.lua'))()(ctx)
assert(ctx.store:temp('configs/index.json') == 'configs/index.tmp.json')
assert(ctx.store:backup('configs/index.json') == 'configs/index.bak.json')
assert(loadfile('src/core/config.lua'))()(ctx)

assert(ctx.config:atomic('configs/test.json', {version = 1, modules = {}, patches = {}}))
assert(ctx.config:atomic('configs/test.json', {
	version = 1,
	modules = {Example = {enabled = true}},
	patches = {}
}))
assert(files['VapeTweaker/configs/test.json'])
assert(files['VapeTweaker/configs/test.bak.json'])
assert(not files['VapeTweaker/configs/test.tmp.json'])
assert(#log.history == 0)
