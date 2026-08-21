local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local heightOffset = 5

local Window = Rayfield:CreateWindow({
    Name = "Tower Teleport Hub",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by 0xseanlee",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateSection("Settings")

Tab:CreateSlider({
    Name = "Height Offset Above Finish",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "HeightSlider",
    Callback = function(Value)
        heightOffset = Value
    end
})

Tab:CreateSection("Action")

local function getFinishPart()
    local tower = workspace:FindFirstChild("tower")
    if tower then
        local finishes = tower:FindFirstChild("finishes")
        if finishes then
            local finish = finishes:FindFirstChild("Finish")
            if finish and finish:IsA("BasePart") then
                return finish
            end
            for _, child in ipairs(finishes:GetChildren()) do
                if child:IsA("BasePart") then
                    return child
                end
            end
        end
    end
    
    return workspace:FindFirstChild("Finish", true)
end

Tab:CreateButton({
    Name = "TP to WIN (Dynamic Finish Door)",
    Callback = function()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            Rayfield:Notify({
                Title = "Error",
                Content = "Character or HumanoidRootPart not found!",
                Duration = 2.5,
                Image = 4483362458
            })
            return
        end

        local finishPart = getFinishPart()

        if finishPart then
            local rootPart = character.HumanoidRootPart
            rootPart.AssemblyLinearVelocity = Vector3.zero
            
            local targetCFrame = finishPart.CFrame + Vector3.new(0, (finishPart.Size.Y / 2) + heightOffset, 0)
            rootPart.CFrame = targetCFrame

            Rayfield:Notify({
                Title = "Success",
                Content = string.format("Teleported to Finish: (%.1f, %.1f, %.1f)", targetCFrame.Position.X, targetCFrame.Position.Y, targetCFrame.Position.Z),
                Duration = 3,
                Image = 4483362458
            })
        else
            Rayfield:Notify({
                Title = "Failed",
                Content = "Finish door not found in current map!",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})
