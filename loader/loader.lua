local HttpService = game:GetService("HttpService")
local PlaceId = tostring(game.PlaceId)
local GameId = tostring(game.GameId)

local BaseUrl = "https://raw.githubusercontent.com/0xseanlee/robloxscript/main"

local function request(url)
    return game:HttpGet(url, true)
end

local success, response = pcall(function()
    return request(BaseUrl .. "/loader/game.json")
end)

if not success or not response then
    return
end

local parsed, games = pcall(function()
    return HttpService:JSONDecode(response)
end)

if not parsed or type(games) ~= "table" then
    return
end

local targetScript = games[PlaceId] or games[GameId]

if targetScript then
    local scriptUrl = BaseUrl .. "/games/" .. targetScript
    local scriptSuccess, scriptContent = pcall(function()
        return request(scriptUrl)
    end)

    if scriptSuccess and scriptContent then
        local exec, err = loadstring(scriptContent)
        if exec then
            task.spawn(exec)
        end
    end
end
