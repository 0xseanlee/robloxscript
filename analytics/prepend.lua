-- 公開使用統計：貼在 Lua 最前面；腳本名稱需和統計後端的清單一致。
-- 公開 UserId、腳本名稱、啟動次數與收到回報的時間；不辨識裝置。
-- 執行前設定 getgenv().ROBLOX_ANALYTICS_DISABLED = true 可停用。
do
    local scriptName = "games/Demon Soul Simulator.lua"
    task.spawn(function()
        pcall(function()
            local env = (getgenv and getgenv()) or _G
            if env.ROBLOX_ANALYTICS_DISABLED then return end
            local send = request or http_request or (syn and syn.request)
            local player = game:GetService("Players").LocalPlayer
            if not player or type(send) ~= "function" then return end
            if not env.ROBLOX_PUBLIC_ANALYTICS_NOTICE_SHOWN then
                env.ROBLOX_PUBLIC_ANALYTICS_NOTICE_SHOWN = true
                warn("[0xseanlee 公開統計] Roblox UserId、腳本啟動次數與時間會公開。可在執行前設定 getgenv().ROBLOX_ANALYTICS_DISABLED = true 停用。")
            end
            local http = game:GetService("HttpService")
            send({
                Url = "https://roblox-analytics.sean0970802201.workers.dev/public/events",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = http:JSONEncode({
                    event_id = http:GenerateGUID(false),
                    user_id = tostring(player.UserId),
                    place_id = tostring(game.PlaceId),
                    script = scriptName,
                    event = "script_started",
                }),
            })
        end)
    end)
end
