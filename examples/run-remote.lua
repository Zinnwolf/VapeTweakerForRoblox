local BASE_URL = 'https://raw.githubusercontent.com/OWNER/REPOSITORY/main/'

getgenv().VapeTweakerConfig = {
	BaseUrl = BASE_URL,
	AutoLoadVape = true
}

return loadstring(game:HttpGet(BASE_URL..'loader.lua', true), '@VapeTweakerLoader')()
