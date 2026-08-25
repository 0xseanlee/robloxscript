local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer

local autoEEnabled = true
local autoInteractDistance = 20

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2.5
        })
    end)
end

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

local function handleCommand(msg)
    local cleaned = string.lower(msg)
    if cleaned == "!e" or cleaned == "!e true" or cleaned == "!e on" then
        autoEEnabled = true
        notify("Auto [E] Loop", "Status: ENABLED")
    elseif cleaned == "!e false" or cleaned == "!e off" then
        autoEEnabled = false
        notify("Auto [E] Loop", "Status: DISABLED")
    end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        if textChatMessage.TextSource and textChatMessage.TextSource.UserId == LocalPlayer.UserId then
            handleCommand(textChatMessage.Text)
        end
    end)
else
    LocalPlayer.Chatted:Connect(function(msg)
        handleCommand(msg)
    end)
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if autoEEnabled then
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local rootPos = character.HumanoidRootPart.Position
                for _, prompt in ipairs(workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        local parent = prompt.Parent
                        if parent and parent:IsA("BasePart") then
                            local dist = (parent.Position - rootPos).Magnitude
                            if dist <= (prompt.MaxActivationDistance or autoInteractDistance) then
                                fireproximityprompt(prompt)
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(setupInstantCook)
task.spawn(setupInstantInteract)
notify("Auto E & Instant Cook", "Ready. Type '!e' or '!e false' in chat.")
