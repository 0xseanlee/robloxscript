
local WIN_POSITION = Vector3.new(75.15, 361.89, 77.54)
local HEIGHT_OFFSET = 5

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Tower of hell script",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by 0xseanlee",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateSection("Action")

Tab:CreateButton({
    Name = "TP to WIN",
    Callback = function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local rootPart = character.HumanoidRootPart
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.CFrame = CFrame.new(WIN_POSITION + Vector3.new(0, HEIGHT_OFFSET, 0))
            Rayfield:Notify({
                Title = "Success",
                Content = "Teleported to WIN.",
                Duration = 2,
                Image = 4483362458
            })
        end
    end
})
