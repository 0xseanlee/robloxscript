local environment, reports, notices, sequence = {}, {}, {}, 0
getgenv = function() return environment end
warn = function(message) table.insert(notices, message) end
task = { spawn = function(callback) callback() end }
local currentId = 12345
local http = {
    GenerateGUID = function() sequence = sequence + 1; return "event-" .. sequence end,
    JSONEncode = function(_, data) return data end,
}
game = { PlaceId = 1962086868, GetService = function(_, name)
    if name == "Players" then return { LocalPlayer = { UserId = currentId } } end
    return http
end }
request = function(data) table.insert(reports, data) end
dofile('analytics/prepend.lua'); dofile('analytics/prepend.lua')
assert(#reports == 2 and reports[1].Body.user_id == '12345' and reports[2].Body.user_id == '12345')
assert(reports[1].Body.event_id ~= reports[2].Body.event_id, 'separate executions must count separately')
assert(string.find(reports[1].Url, '/public/events', 1, true))
assert(#notices == 1, 'public notice appears once')
currentId = 98765; dofile('analytics/prepend.lua')
assert(reports[3].Body.user_id == '98765', 'accounts are not deduplicated by device')
environment.ROBLOX_ANALYTICS_DISABLED = true; dofile('analytics/prepend.lua')
assert(#reports == 3, 'opt-out prevents transmission')
environment.ROBLOX_ANALYTICS_DISABLED = false
request = function() error('offline') end
assert(pcall(dofile, 'analytics/prepend.lua'), 'network errors must not prevent main code')
request = nil
assert(pcall(dofile, 'analytics/prepend.lua'), 'missing HTTP implementation is harmless')
print('prepend repeats, account switching, notice, opt-out and failure isolation passed')
