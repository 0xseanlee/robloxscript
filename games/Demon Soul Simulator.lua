local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local fastAttack = false
local spamSkills = false
local selectedSkillMode = "All Skills"
local autoSouls = false
local autoBurstDraw = false
local burstDrawCount = 5
local attackInterval = 0
local customWalkSpeed = 16
local speedHackEnabled = false

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local generalAttack = remoteEvents and remoteEvents:FindFirstChild("GeneralAttack")
local skillAttack = remoteEvents and remoteEvents:FindFirstChild("SkillAttack")
local drawRole = remoteEvents and remoteEvents:FindFirstChild("DrawRole")
local addSoul = ReplicatedStorage:FindFirstChild("AddSoul")
local soulsFolder = Workspace:FindFirstChild("Souls")

RunService.Stepped:Connect(function()
    local character = LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if speedHackEnabled then
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        if humanoid and humanoid.WalkSpeed ~= customWalkSpeed then
            humanoid.WalkSpeed = customWalkSpeed
        end
    end
end)

local Window = Rayfield:CreateWindow({
    Name = "Demon Soul Master Hub",
    LoadingTitle = "Initializing...",
    LoadingSubtitle = "by 0xseanlee",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local CombatTab = Window:CreateTab("Combat & Movement", 4483362458)
local FarmTab = Window:CreateTab("Farming", 4483362458)
local GachaTab = Window:CreateTab("Gacha", 4483362458)

CombatTab:CreateSection("Movement")

CombatTab:CreateToggle({
    Name = "Enable Custom WalkSpeed",
    CurrentValue = false,
    Flag = "WalkSpeedToggle",
    Callback = function(Value)
        speedHackEnabled = Value
        if not Value then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
            end
        end
    end
})

CombatTab:CreateSlider({
    Name = "WalkSpeed Value",
    Range = {16, 300},
    Increment = 1,
    Suffix = " spd",
    CurrentValue = 16,
    Flag = "WalkSpeedSlider",
    Callback = function(Value)
        customWalkSpeed = Value
    end
})

CombatTab:CreateSection("Attack Controls")

CombatTab:CreateToggle({
    Name = "Fast Combo Attack (1-4)",
    CurrentValue = false,
    Flag = "FastAttackToggle",
    Callback = function(Value)
        fastAttack = Value
    end
})

CombatTab:CreateDropdown({
    Name = "Select Skill to Cast",
    Options = {"Skill 1", "Skill 2", "Skill 3", "Skill 4", "All Skills"},
    CurrentOption = {"All Skills"},
    MultipleOptions = false,
    Flag = "SkillSelectDropdown",
    Callback = function(Option)
        selectedSkillMode = type(Option) == "table" and Option[1] or Option
    end
})

CombatTab:CreateToggle({
    Name = "Spam Selected Skill",
    CurrentValue = false,
    Flag = "SpamSkillsToggle",
    Callback = function(Value)
        spamSkills = Value
    end
})

CombatTab:CreateSlider({
    Name = "Attack Delay (0s = Max Rate)",
    Range = {0, 0.3},
    Increment = 0.005,
    Suffix = "s",
    CurrentValue = 0,
    Flag = "AttackDelaySlider",
    Callback = function(Value)
        attackInterval = Value
    end
})

FarmTab:CreateSection("Souls")

FarmTab:CreateToggle({
    Name = "Auto Collect Souls",
    CurrentValue = false,
    Flag = "AutoSoulsToggle",
    Callback = function(Value)
        autoSouls = Value
    end
})

GachaTab:CreateSection("Burst Draw")

GachaTab:CreateSlider({
    Name = "Burst Multiplier (x)",
    Range = {1, 25},
    Increment = 1,
    Suffix = " rolls",
    CurrentValue = 5,
    Flag = "BurstSlider",
    Callback = function(Value)
        burstDrawCount = Value
    end
})

GachaTab:CreateToggle({
    Name = "Auto Multi-Draw Burst",
    CurrentValue = false,
    Flag = "AutoBurstToggle",
    Callback = function(Value)
        autoBurstDraw = Value
    end
})

task.spawn(function()
    while true do
        if attackInterval > 0 then
            task.wait(attackInterval)
        else
            task.wait()
        end


        if fastAttack and generalAttack then
            pcall(function()
                generalAttack:FireServer(4)
            end)
        end


        if spamSkills and skillAttack then
            if selectedSkillMode == "All Skills" then
                for skillNum = 1, 4 do
                    pcall(function()
                        skillAttack:FireServer(skillNum)
                    end)
                end
            else
                local targetSkill = tonumber(string.match(selectedSkillMode, "%d+")) or 1
                pcall(function()
                    skillAttack:FireServer(targetSkill)
                end)
            end
        end
    end
end)


task.spawn(function()
    while true do
        task.wait(0.15)
        if autoSouls then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and soulsFolder then
                for _, soul in ipairs(soulsFolder:GetChildren()) do
                    local part = soul:IsA("BasePart") and soul or soul:FindFirstChildWhichIsA("BasePart")
                    if part then
                        if firetouchinterest then
                            firetouchinterest(root, part, 0)
                            task.wait()
                            firetouchinterest(root, part, 1)
                        else
                            part.CFrame = root.CFrame
                        end
                    end
                end
            end
            if addSoul then
                pcall(function()
                    addSoul:FireServer()
                end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if autoBurstDraw and drawRole then
            for _ = 1, burstDrawCount do
                pcall(function()
                    drawRole:FireServer(1)
                end)
            end
        end
    end
end)
