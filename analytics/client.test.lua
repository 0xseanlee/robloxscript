local environment, reports = {}, {}
getgenv = function() return environment end
task = { spawn = function(callback) callback() end }
local http = {
    GenerateGUID = function() return "00000000-0000-4000-8000-000000000001" end,
    JSONEncode = function(_, data) return data end,
}
game = {
    PlaceId = 1962086868,
    GetService = function(_, name)
        if name == "Players" then return { LocalPlayer = { UserId = 12345 } } end
        return http
    end,
}
request = function(data) table.insert(reports, data) end
local track = dofile("analytics/client.lua")
track("games/towerofhell.lua", "script_started")
assert(#reports == 1 and reports[1].Body.user_id == "12345")
assert(reports[1].Body.script == "games/towerofhell.lua")
environment.ROBLOX_ANALYTICS_DISABLED = true
track("games/towerofhell.lua", "script_started")
assert(#reports == 1, "opt-out must prevent transmission")
environment.ROBLOX_ANALYTICS_DISABLED = false
request = function() error("network unavailable") end
assert(pcall(track, "loader", "loader_started"), "network errors must not escape")
request = nil
assert(pcall(track, "loader", "loader_started"), "missing HTTP API must be harmless")
print("client telemetry, opt-out, and failure isolation passed")
