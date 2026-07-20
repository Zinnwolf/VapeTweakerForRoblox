getgenv().VapeTweakerConfig = {
	Root = 'VapeTweaker',
	AutoLoadVape = true
}

return loadstring(readfile('VapeTweaker/loader.lua'), '@VapeTweakerLoader')()
