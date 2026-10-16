local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LocalPlayer = Players.LocalPlayer

local function setupInstantCook()
    local playerScripts = LocalPlayer:WaitForChild("PlayerScripts")
    local cooking = playerScripts:WaitForChild("CookingNew", 10)
    if not cooking then return end

    local cookProgress = require(cooking:WaitForChild("CookProgress"))
    local multiClick = require(cooking:WaitForChild("InputDetectors"):WaitForChild("MultiClick"))
    local mouseMovement = require(cooking:WaitForChild("InputDetectors"):WaitForChild("MouseMovement"))
    local mouseSpin = require(cooking:WaitForChild("InputDetectors"):WaitForChild("MouseSpin"))

    local oldRun = cookProgress.run
    cookProgress.run = function(...)
        local args = {...}
        args[3] = 0
        return oldRun(unpack(args))
    end

    multiClick.start = function(...)
        local args = {...}
        if typeof(args[3]) == "function" then
            args[3]()
        end
    end

    mouseMovement.start = function(...)
        local args = {...}
        if typeof(args[3]) == "function" then
            args[3]()
        end
    end

    mouseSpin.start = function(...)
        local args = {...}
        if typeof(args[3]) == "function" then
            args[3]()
        end
    end
end

local function setupInstantInteract()
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            prompt.HoldDuration = 0
        end
    end

    workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("ProximityPrompt") then
            descendant.HoldDuration = 0
        end
    end)

    ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
        fireproximityprompt(prompt)
    end)
end

task.spawn(setupInstantCook)
task.spawn(setupInstantInteract)

-- Usage analytics: see README for data collected and opt-out.
task.spawn(function()
    pcall(function()
        local environment = (getgenv and getgenv()) or _G
        if environment.ROBLOX_ANALYTICS_DISABLED then return end
        local track = loadstring(game:HttpGet("https://raw.githubusercontent.com/0xseanlee/robloxscript/main/analytics/client.lua"))()
        track("games/rt2.lua", "script_started")
    end)
end)
