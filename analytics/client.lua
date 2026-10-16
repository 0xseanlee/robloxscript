-- Optional usage analytics. Set getgenv().ROBLOX_ANALYTICS_DISABLED = true
-- before running any script to opt out. No usernames or device IDs are sent.
return function(scriptName, eventName)
    task.spawn(function()
        pcall(function()
            local environment = (getgenv and getgenv()) or _G
            if environment.ROBLOX_ANALYTICS_DISABLED then return end
            local player = game:GetService("Players").LocalPlayer
            local send = request or http_request or (syn and syn.request)
            if not player or type(send) ~= "function" then return end
            local http = game:GetService("HttpService")
            send({
                Url = "https://roblox-analytics.sean0970802201.workers.dev/events",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = http:JSONEncode({
                    event_id = http:GenerateGUID(false),
                    user_id = tostring(player.UserId),
                    place_id = tostring(game.PlaceId),
                    script = scriptName,
                    event = eventName,
                }),
            })
        end)
    end)
end
