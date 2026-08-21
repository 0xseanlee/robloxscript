local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local targetX, targetY, targetZ = 0, 0, 0
local heightOffset = 5
local touchDisabled = false
local touchSteppedConnection = nil

local function getGuiParent()
    local success, parent = pcall(function() return CoreGui end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local floatGui = Instance.new("ScreenGui")
floatGui.Name = "TouchControlFloatingUI"
floatGui.ResetOnSpawn = false
floatGui.Parent = getGuiParent()

local floatFrame = Instance.new("Frame")
floatFrame.Name = "TouchFrame"
floatFrame.Size = UDim2.new(0, 160, 0, 45)
floatFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
floatFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
floatFrame.BorderSizePixel = 0
floatFrame.Active = true
floatFrame.Draggable = true
floatFrame.Parent = floatGui

local floatCorner = Instance.new("UICorner")
floatCorner.CornerRadius = UDim.new(0, 8)
floatCorner.Parent = floatFrame

local floatStroke = Instance.new("UIStroke")
floatStroke.Color = Color3.fromRGB(70, 70, 90)
floatStroke.Thickness = 1.5
floatStroke.Parent = floatFrame

local touchToggleBtn = Instance.new("TextButton")
touchToggleBtn.Name = "TouchToggleButton"
touchToggleBtn.Size = UDim2.new(1, -10, 1, -10)
touchToggleBtn.Position = UDim2.new(0, 5, 0, 5)
touchToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
touchToggleBtn.Text = "Touch: ENABLED"
touchToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
touchToggleBtn.Font = Enum.Font.GothamBold
touchToggleBtn.TextSize = 13
touchToggleBtn.AutoButtonColor = false
touchToggleBtn.Parent = floatFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = touchToggleBtn

local function updateTouchState(disabled)
    touchDisabled = disabled
    
    if touchDisabled then
        touchToggleBtn.Text = "Touch: DISABLED"
        touchToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        
        if not touchSteppedConnection then
            touchSteppedConnection = RunService.Stepped:Connect(function()
                local character = LocalPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanTouch then
                            part.CanTouch = false
                        end
                    end
                end
            end)
        end
    else
        touchToggleBtn.Text = "Touch: ENABLED"
        touchToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
        
        if touchSteppedConnection then
            touchSteppedConnection:Disconnect()
            touchSteppedConnection = nil
        end
        
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanTouch = true
                end
            end
        end
    end
end

touchToggleBtn.MouseButton1Click:Connect(function()
    updateTouchState(not touchDisabled)
end)

local Window = Rayfield:CreateWindow({
    Name = "Dev Tool - Position & Touch",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by 0xseanlee",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Developer", 4483362458)

Tab:CreateSection("Touch Control Floating UI")

Tab:CreateToggle({
    Name = "Show / Hide Touch UI",
    CurrentValue = true,
    Flag = "ShowTouchUI",
    Callback = function(Value)
        floatFrame.Visible = Value
    end
})

Tab:CreateSection("Coordinate Tracker")

Tab:CreateButton({
    Name = "Copy Current Position (XYZ)",
    Callback = function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local pos = character.HumanoidRootPart.Position
            local formatted = string.format("Vector3.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
            if setclipboard then
                setclipboard(formatted)
                Rayfield:Notify({
                    Title = "Copied to Clipboard",
                    Content = formatted,
                    Duration = 3,
                    Image = 4483362458
                })
            else
                Rayfield:Notify({
                    Title = "Position Found",
                    Content = formatted,
                    Duration = 3,
                    Image = 4483362458
                })
            end
        end
    end
})

Tab:CreateSection("Coordinate Inputs")

Tab:CreateInput({
    Name = "Target X",
    PlaceholderText = "0",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) targetX = tonumber(Text) or targetX end
})

Tab:CreateInput({
    Name = "Target Y",
    PlaceholderText = "0",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) targetY = tonumber(Text) or targetY end
})

Tab:CreateInput({
    Name = "Target Z",
    PlaceholderText = "0",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) targetZ = tonumber(Text) or targetZ end
})

Tab:CreateSlider({
    Name = "Height Offset",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "HeightSlider",
    Callback = function(Value) heightOffset = Value end
})

Tab:CreateButton({
    Name = "Teleport to Position",
    Callback = function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local root = character.HumanoidRootPart
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = CFrame.new(Vector3.new(targetX, targetY + heightOffset, targetZ))
        end
    end
})
