local HttpService = game:GetService("HttpService")
local PlaceId = tostring(game.PlaceId)
local GameId = tostring(game.GameId)

local BaseUrl = "https://raw.githubusercontent.com/0xseanlee/robloxscript/main"

local function report(eventName)
    task.spawn(function()
        pcall(function()
            local environment = (getgenv and getgenv()) or _G
            if environment.ROBLOX_ANALYTICS_DISABLED then return end
            local track = loadstring(game:HttpGet(BaseUrl .. "/analytics/client.lua"))()
            track("loader", eventName)
        end)
    end)
end

report("loader_started")

local function request(url)
    return game:HttpGet(url, true)
end

local success, response = pcall(function()
    return request(BaseUrl .. "/loader/game.json")
end)

if not success or not response then
    report("load_failed")
    return
end

local parsed, games = pcall(function()
    return HttpService:JSONDecode(response)
end)

if not parsed or type(games) ~= "table" then
    report("load_failed")
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
            task.spawn(function()
                local ran = pcall(exec)
                if not ran then report("load_failed") end
            end)
        else
            report("load_failed")
        end
    else
        report("load_failed")
    end
else
    report("unsupported_game")
end
