
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

-- Anti-AFK
local environment = (getgenv and getgenv()) or _G

local function enableAntiAFK()
    local old = environment.SEAN_ANTI_AFK
    if old and old.Connected then
        return
    end

    local player = Players.LocalPlayer
    if not player then
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end

    environment.SEAN_ANTI_AFK =
        player.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)
end

task.spawn(enableAntiAFK)

local DiscordInvite = "https://discord.gg/mK9XWyV5Q2"

local function openDiscordInvite()
    local environment = (getgenv and getgenv()) or _G
    local openUrl = environment.openurl or environment.open_url
        or (syn and syn.open_url)
    if type(openUrl) == "function" then
        local opened, result = pcall(openUrl, DiscordInvite)
        if opened and result ~= false then return true end
    end
    local opened = pcall(function()
        game:GetService("BrowserService"):OpenBrowserWindow(DiscordInvite)
    end)
    if opened then return true end
    -- Discord desktop can open its invite window through the local RPC endpoint.
    local httpRequest = environment.request or environment.http_request
        or (syn and syn.request) or (http and http.request)
    if type(httpRequest) == "function" then
        for port = 6463, 6472 do
            local ok, response = pcall(httpRequest, {
                Url = "http://127.0.0.1:" .. port .. "/rpc?v=1",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Origin"] = "https://discord.com",
                },
                Body = HttpService:JSONEncode({
                    cmd = "INVITE_BROWSER",
                    args = { code = "mK9XWyV5Q2" },
                    nonce = HttpService:GenerateGUID(false),
                }),
            })
            if ok and type(response) == "table" then
                local status = tonumber(response.StatusCode or response.Status)
                if status and status >= 200 and status < 300 then return true end
            end
        end
    end
    return false
end

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
    card.Size = UDim2.new(0.9, 0, 0, 224)
    card.BackgroundColor3 = Color3.fromRGB(27, 29, 41)
    card.BorderSizePixel = 0
    card.Parent = overlay

    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MaxSize = Vector2.new(420, 224)
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
    label("Get updates, support, and new scripts.\nClick Join to open Discord and continue.",
        68, 52, Enum.Font.Gotham, 14, Color3.fromRGB(184, 188, 204))

    local button = Instance.new("TextButton")
    button.Position = UDim2.new(0, 24, 0, 144)
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
        task.spawn(function()
            local ok, opened = pcall(openDiscordInvite)
            if not ok or not opened then
                warn("Could not open Discord with this executor. Continuing...")
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
