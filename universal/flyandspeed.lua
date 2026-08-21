local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Features = {
    NoClip = true,
    Fly = false
}

local Connections = {
    NoClip = nil,
    FlyRender = nil,
    InputBegan = nil,
    InputEnded = nil
}

local defaultSpeed = 16
local flySpeedMultiplier = 1
local tpwalking = false
local flyingBodyGyro, flyingBodyVelocity
local flyingCtrl = {f = 0, b = 0, l = 0, r = 0}
local flyingLastCtrl = {f = 0, b = 0, l = 0, r = 0}
local flyingSpeed = 0
local flyingMaxSpeed = 50

-- Speed 控制
local function setSpeed(newSpeed)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = newSpeed
    end
end

-- NoClip 設定
local function setupNoClip()
    if Connections.NoClip then Connections.NoClip:Disconnect() end
    if not Features.NoClip then return end

    Connections.NoClip = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        if character and Features.NoClip then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

-- 停止飛行
local function stopFlying()
    tpwalking = false
    Features.Fly = false

    if Connections.FlyRender then Connections.FlyRender:Disconnect() Connections.FlyRender = nil end
    if Connections.InputBegan then Connections.InputBegan:Disconnect() Connections.InputBegan = nil end
    if Connections.InputEnded then Connections.InputEnded:Disconnect() Connections.InputEnded = nil end

    if flyingBodyGyro then flyingBodyGyro:Destroy() flyingBodyGyro = nil end
    if flyingBodyVelocity then flyingBodyVelocity:Destroy() flyingBodyVelocity = nil end

    flyingCtrl = {f = 0, b = 0, l = 0, r = 0}
    flyingLastCtrl = {f = 0, b = 0, l = 0, r = 0}
    flyingSpeed = 0

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        end
        local animate = char:FindFirstChild("Animate")
        if animate then
            animate.Disabled = false
        end
    end
end

-- 開始飛行
local function startFlying(customMultiplier)
    stopFlying()

    flySpeedMultiplier = math.max(1, tonumber(customMultiplier) or 1)
    Features.Fly = true

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local targetPart = (hum.RigType == Enum.HumanoidRigType.R6) and char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not targetPart then return end

    tpwalking = true
    for i = 1, flySpeedMultiplier do
        task.spawn(function()
            local hb = RunService.Heartbeat
            while tpwalking and hb:Wait() do
                local curChar = LocalPlayer.Character
                local curHum = curChar and curChar:FindFirstChildWhichIsA("Humanoid")
                if curChar and curHum and curHum.Parent and curHum.MoveDirection.Magnitude > 0 then
                    curChar:TranslateBy(curHum.MoveDirection)
                end
            end
        end)
    end

    local animate = char:FindFirstChild("Animate")
    if animate then animate.Disabled = true end

    local animController = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("AnimationController")
    if animController then
        for _, track in pairs(animController:GetPlayingAnimationTracks()) do
            track:AdjustSpeed(0)
        end
    end

    hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Running, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    hum:ChangeState(Enum.HumanoidStateType.Swimming)
    hum.PlatformStand = true

    flyingBodyGyro = Instance.new("BodyGyro")
    flyingBodyGyro.P = 9e4
    flyingBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyingBodyGyro.CFrame = targetPart.CFrame
    flyingBodyGyro.Parent = targetPart

    flyingBodyVelocity = Instance.new("BodyVelocity")
    flyingBodyVelocity.Velocity = Vector3.new(0, 0.1, 0)
    flyingBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyingBodyVelocity.Parent = targetPart

    flyingCtrl = {f = 0, b = 0, l = 0, r = 0}
    flyingLastCtrl = {f = 0, b = 0, l = 0, r = 0}
    flyingSpeed = 0

    Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.W then
            flyingCtrl.f = 1
        elseif input.KeyCode == Enum.KeyCode.S then
            flyingCtrl.b = -1
        elseif input.KeyCode == Enum.KeyCode.A then
            flyingCtrl.l = -1
        elseif input.KeyCode == Enum.KeyCode.D then
            flyingCtrl.r = 1
        end
    end)

    Connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.W then
            flyingCtrl.f = 0
        elseif input.KeyCode == Enum.KeyCode.S then
            flyingCtrl.b = 0
        elseif input.KeyCode == Enum.KeyCode.A then
            flyingCtrl.l = 0
        elseif input.KeyCode == Enum.KeyCode.D then
            flyingCtrl.r = 0
        end
    end)

    Connections.FlyRender = RunService.RenderStepped:Connect(function()
        if not Features.Fly or not targetPart or not targetPart.Parent then return end
        local camera = workspace.CurrentCamera
        if not camera then return end

        if (flyingCtrl.l + flyingCtrl.r ~= 0) or (flyingCtrl.f + flyingCtrl.b ~= 0) then
            flyingSpeed = flyingSpeed + 0.5 + (flyingSpeed / flyingMaxSpeed)
            if flyingSpeed > flyingMaxSpeed then
                flyingSpeed = flyingMaxSpeed
            end
        elseif (flyingCtrl.l + flyingCtrl.r == 0) and (flyingCtrl.f + flyingCtrl.b == 0) and flyingSpeed ~= 0 then
            flyingSpeed = flyingSpeed - 1
            if flyingSpeed < 0 then
                flyingSpeed = 0
            end
        end

        if (flyingCtrl.l + flyingCtrl.r ~= 0) or (flyingCtrl.f + flyingCtrl.b ~= 0) then
            flyingBodyVelocity.Velocity = ((camera.CFrame.LookVector * (flyingCtrl.f + flyingCtrl.b)) + ((camera.CFrame * CFrame.new(flyingCtrl.l + flyingCtrl.r, (flyingCtrl.f + flyingCtrl.b) * 0.2, 0).Position) - camera.CFrame.Position)) * flyingSpeed
            flyingLastCtrl = {f = flyingCtrl.f, b = flyingCtrl.b, l = flyingCtrl.l, r = flyingCtrl.r}
        elseif (flyingCtrl.l + flyingCtrl.r == 0) and (flyingCtrl.f + flyingCtrl.b == 0) and flyingSpeed ~= 0 then
            flyingBodyVelocity.Velocity = ((camera.CFrame.LookVector * (flyingLastCtrl.f + flyingLastCtrl.b)) + ((camera.CFrame * CFrame.new(flyingLastCtrl.l + flyingLastCtrl.r, (flyingLastCtrl.f + flyingLastCtrl.b) * 0.2, 0).Position) - camera.CFrame.Position)) * flyingSpeed
        else
            flyingBodyVelocity.Velocity = Vector3.zero
        end

        flyingBodyGyro.CFrame = camera.CFrame * CFrame.Angles(-math.rad((flyingCtrl.f + flyingCtrl.b) * 50 * flyingSpeed / flyingMaxSpeed), 0, 0)
    end)
end

-- 指令監聽
local function handleCommand(msg)
    local lowerMsg = string.lower(msg)
    
    if string.sub(lowerMsg, 1, 4) == "!fly" then
        local param = string.match(lowerMsg, "^!fly%s*(.*)$")
        if param == "false" then
            stopFlying()
        else
            local inputSpeed = tonumber(param) or 1
            startFlying(inputSpeed)
        end
    elseif string.sub(lowerMsg, 1, 6) == "!speed" then
        local param = string.match(lowerMsg, "^!speed%s*(.*)$")
        if param == "false" then
            setSpeed(defaultSpeed)
        else
            local num = tonumber(param)
            if num then
                setSpeed(num)
            end
        end
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

-- 角色生成與死亡監聽
local function onCharacterAdded(char)
    local hum = char:WaitForChild("Humanoid")
    char:WaitForChild("HumanoidRootPart")

    defaultSpeed = hum.WalkSpeed

    if Features.NoClip then setupNoClip() end
    if Features.Fly then startFlying(flySpeedMultiplier) end

    hum.Died:Connect(function()
        stopFlying()
        for _, conn in pairs(Connections) do
            if conn then conn:Disconnect() end
        end
    end)
end

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- 外部控制函式
function toggleNoClip(state)
    Features.NoClip = (state ~= nil) and state or not Features.NoClip
    setupNoClip()
end

function toggleFly(state, customSpeed)
    if state == false then
        stopFlying()
    else
        startFlying(customSpeed or 1)
    end
end

-- 預設開啟 NoClip
toggleNoClip(true)
