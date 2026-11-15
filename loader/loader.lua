local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local DiscordInvite = "https://discord.gg/mK9XWyV5Q2"

local function showDiscordPrompt()
    local player = Players.LocalPlayer
    if not player then
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "DiscordJoinPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mounted = pcall(function()
        gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not mounted then
        gui.Parent = player:WaitForChild("PlayerGui")
    end

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    overlay.BackgroundTransparency = 0.2
    overlay.BorderSizePixel = 0
    overlay.Active = true
    overlay.Parent = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.new(0.9, 0, 0, 264)
    card.BackgroundColor3 = Color3.fromRGB(27, 29, 41)
    card.BorderSizePixel = 0
    card.Parent = overlay

    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MaxSize = Vector2.new(420, 264)
    sizeLimit.Parent = card

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = card

    local function label(text, y, height, font, textSize, color)
        local item = Instance.new("TextLabel")
        item.BackgroundTransparency = 1
        item.Position = UDim2.new(0, 24, 0, y)
        item.Size = UDim2.new(1, -48, 0, height)
        item.Font = font
        item.Text = text
        item.TextSize = textSize
        item.TextColor3 = color
        item.TextWrapped = true
        item.Parent = card
        return item
    end

    label("Join Our Discord", 24, 34, Enum.Font.GothamBold, 24,
        Color3.fromRGB(255, 255, 255))
    label("Get updates, support, and new scripts.\nClick below to copy the invite and continue.",
        68, 52, Enum.Font.Gotham, 14, Color3.fromRGB(184, 188, 204))

    local invite = Instance.new("TextBox")
    invite.Position = UDim2.new(0, 24, 0, 132)
    invite.Size = UDim2.new(1, -48, 0, 32)
    invite.BackgroundColor3 = Color3.fromRGB(36, 39, 54)
    invite.BorderSizePixel = 0
    invite.Font = Enum.Font.Gotham
    invite.Text = DiscordInvite
    invite.TextSize = 13
    invite.TextColor3 = Color3.fromRGB(207, 211, 255)
    invite.TextEditable = false
    invite.ClearTextOnFocus = false
    invite.Parent = card

    local button = Instance.new("TextButton")
    button.Position = UDim2.new(0, 24, 0, 184)
    button.Size = UDim2.new(1, -48, 0, 48)
    button.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = "Join to Continue"
    button.TextSize = 16
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Parent = card

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 10)
    buttonCorner.Parent = button

    local continued = false
    local connection = button.Activated:Connect(function()
        if continued then return end
        continued = true
        -- Copying is best-effort; clicking always unlocks the loader.
        pcall(function()
            if setclipboard then
                setclipboard(DiscordInvite)
            elseif toclipboard then
                toclipboard(DiscordInvite)
            end
        end)
    end)

    repeat task.wait() until continued
    connection:Disconnect()
    gui:Destroy()
end

showDiscordPrompt()

local PlaceId = tostring(game.PlaceId)
local GameId = tostring(game.GameId)

local BaseUrl = "https://raw.githubusercontent.com/0xseanlee/robloxscript/main"

local function report(eventName)
    task.spawn(function()
        pcall(function()
            local environment = (getgenv and getgenv()) or _G
            if environment.ROBLOX_ANALYTICS_DISABLED then return end
            local track = loadstring(game:HttpGet(BaseUrl .. "/analytics/client.lua"))()
            track("loader", eventName)
        end)
    end)
end

report("loader_started")

local function request(url)
    return game:HttpGet(url, true)
end

local success, response = pcall(function()
    return request(BaseUrl .. "/loader/game.json")
end)

if not success or not response then
    report("load_failed")
    return
end

local parsed, games = pcall(function()
    return HttpService:JSONDecode(response)
end)

if not parsed or type(games) ~= "table" then
    report("load_failed")
    return
end

local targetScript = games[PlaceId] or games[GameId]

if targetScript then
    local scriptUrl = BaseUrl .. "/games/" .. targetScript
    local scriptSuccess, scriptContent = pcall(function()
        return request(scriptUrl)
    end)

    if scriptSuccess and scriptContent then
        local exec, err = loadstring(scriptContent)
        if exec then
            task.spawn(function()
                local ran = pcall(exec)
                if not ran then report("load_failed") end
            end)
        else
            report("load_failed")
        end
    else
        report("load_failed")
    end
else
    report("unsupported_game")
end
