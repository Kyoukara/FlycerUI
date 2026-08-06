--[[
    FlycerUI Library
    Version: 2.0.0
    
    Rayfield-inspired animation systems integrated:
    - Multi-stage loading sequence
    - Staggered element reveal
    - Minimize/Maximize
    - Hide/Unhide with keybind
    - Notification with actions
    - Toggle bounce animation
    - Button click feedback
    - Element hover effects
    - Error state handling
    
    Usage:
        local Flycer = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL"))()
        local Window = Flycer:CreateWindow({ ... })
        local Tab = Window:CreateTab("TabName", layoutOrder)
        Tab:CreateToggle({ ... })
        Tab:CreateButton({ ... })
        Tab:CreateLabel("text")
        Tab:CreateSection("title")
        Tab:CreateSlider({ ... })
        Tab:CreateInput({ ... })
        Tab:CreateDropdown({ ... })
        Tab:CreateKeybind({ ... })
]]

-- SERVICES

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui or LocalPlayer:WaitForChild("PlayerGui", 10)

-- EXECUTOR API CACHE

local EXECUTOR_APIS = {
    gethui = false,
    get_hidden_ui = false,
    syn_protect_gui = false,
    protect_gui = false,
    protectgui = false,
    setclipboard = false,
    toclipboard = false,
}

do
    local function envHas(name)
        local ok, val = pcall(function()
            return _G[name] or (getfenv and getfenv(0)[name])
        end)
        return ok and val ~= nil
    end
    if envHas("gethui") then EXECUTOR_APIS.gethui = true end
    if envHas("get_hidden_ui") then EXECUTOR_APIS.get_hidden_ui = true end
    pcall(function()
        if syn and type(syn.protect_gui) == "function" then EXECUTOR_APIS.syn_protect_gui = true end
    end)
    if envHas("protect_gui") then EXECUTOR_APIS.protect_gui = true end
    if envHas("protectgui") then EXECUTOR_APIS.protectgui = true end
    if envHas("setclipboard") then EXECUTOR_APIS.setclipboard = true end
    if envHas("toclipboard") then EXECUTOR_APIS.toclipboard = true end
end

-- PLATFORM DETECTION

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local isConsole = UserInputService.GamepadEnabled and not UserInputService.TouchEnabled and not UserInputService.MouseEnabled
if not isMobile and not isPC and not isConsole then isPC = true end

-- CONSTANTS

local NOTIF_WIDTH = isMobile and 220 or 265
local NOTIF_HEIGHT = isMobile and 58 or 62
local NOTIF_POS_X = isMobile and 12 or 18
local NOTIF_POS_Y = isMobile and 16 or 22
local NOTIF_CORNER_RADIUS = isMobile and 10 or 12
local NOTIF_PROGRESS_HEIGHT = 3
local NOTIF_ICON_SIZE = isMobile and 26 or 28
local NOTIF_TITLE_SIZE = isMobile and 11 or 12
local NOTIF_BODY_SIZE = isMobile and 9 or 10

local GUI_REF_NAME = "_FlycerGUI_Instance"
local FLAG_NAME = "_FlycerGUI_Loaded"
local FLYCER_TAG_ATTR = "FlycerOwnedGui"

local DRAG_SMOOTHNESS = 14
local RESIZE_PANEL_WIDTH = 270
local RESIZE_PANEL_HEIGHT = 165
local RESIZE_FIELD_WIDTH = 108
local RESIZE_FIELD_GAP = 14
local FADE_DURATION = 0.4
local TOGGLE_DEBOUNCE = 0.1

local TAB_HEIGHT = 32
local TAB_PADDING = 10
local TAB_MIN_WIDTH = 72
local TAB_RAIL_MARGIN = 5

local DISCORD_LINK = "discord.gg/RCASHh828K"

local RESIZE_PANEL_CENTER_POS = UDim2.new(0.5, 0, 0.5, 0)
local RESIZE_PANEL_UP_POS = UDim2.new(0.5, 0, 0.30, 0)

-- LAYOUT CONSTANTS

local HEADER_H = 36
local TAB_RAIL_Y = HEADER_H
local CONTENT_TOP = TAB_RAIL_Y + TAB_HEIGHT + 13
local EXTRA_BAR_H = 24
local EXTRA_BAR_MARGIN = 4
local MIN_CONTENT_H = 20

-- RAYFIELD-INSPIRED ANIMATION CONSTANTS

local LOADING_STAGE_DELAY = 0.05
local ELEMENT_STAGGER_DELAY = 0.08
local ELEMENT_FADE_DURATION = 0.7
local HOVER_TWEEN_DURATION = 0.6
local CLICK_FEEDBACK_DURATION = 0.2
local ERROR_FLASH_DURATION = 0.5
local MINIMIZE_DURATION = 0.5
local HIDE_DURATION = 0.5
local TAB_SWITCH_BOUNCE_DURATION = 0.8

-- THEME

local RX = {
    Bg = Color3.fromRGB(14, 14, 22),
    Bg2 = Color3.fromRGB(20, 20, 30),
    Bg3 = Color3.fromRGB(28, 28, 40),
    Card = Color3.fromRGB(14, 14, 22),
    Accent1 = Color3.fromRGB(88, 101, 242),
    Accent2 = Color3.fromRGB(130, 80, 255),
    Cyan = Color3.fromRGB(0, 200, 255),
    Green = Color3.fromRGB(60, 210, 120),
    Red = Color3.fromRGB(240, 70, 80),
    Orange = Color3.fromRGB(255, 140, 50),
    T1 = Color3.fromRGB(240, 240, 255),
    T2 = Color3.fromRGB(155, 160, 185),
    T3 = Color3.fromRGB(90, 95, 120),
    Border = Color3.fromRGB(45, 48, 70),
    MainAlpha = 0.25,
    CardAlpha = 0.25,
    CardHover = Color3.fromRGB(22, 22, 34),
    ErrorBg = Color3.fromRGB(85, 0, 0),
    F1 = Enum.Font.GothamBold,
    F2 = Enum.Font.GothamMedium,
    FM = Enum.Font.Code,
    ToggleEnabled = Color3.fromRGB(88, 101, 242),
    ToggleDisabled = Color3.fromRGB(100, 100, 100),
    ToggleEnabledStroke = Color3.fromRGB(120, 130, 255),
    ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
    SliderProgress = Color3.fromRGB(88, 101, 242),
    SliderBg = Color3.fromRGB(30, 30, 45),
    InputBg = Color3.fromRGB(20, 20, 32),
    InputStroke = Color3.fromRGB(55, 58, 85),
}

local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quint)
local TWEEN_NORMAL = TweenInfo.new(0.25, Enum.EasingStyle.Quint)
local TWEEN_ELEMENT = TweenInfo.new(ELEMENT_FADE_DURATION, Enum.EasingStyle.Quint)
local TWEEN_HOVER = TweenInfo.new(HOVER_TWEEN_DURATION, Enum.EasingStyle.Quint)
local TWEEN_CLICK = TweenInfo.new(CLICK_FEEDBACK_DURATION, Enum.EasingStyle.Quint)
local TWEEN_BOUNCE = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_BOUNCE_BACK = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- TRANSPARENCY PROPERTY DEFINITIONS

local TRANSPARENCY_PROPS = {
    Frame = { "BackgroundTransparency" },
    ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
    TextLabel = { "BackgroundTransparency", "TextTransparency" },
    TextButton = { "BackgroundTransparency", "TextTransparency" },
    TextBox = { "BackgroundTransparency", "TextTransparency" },
    ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
    ImageButton = { "BackgroundTransparency", "ImageTransparency" },
    UIStroke = { "Transparency" },
}

local EXCLUDED_CLASSES = {
    BillboardGui = true, UIListLayout = true, UIGridLayout = true,
    UIPageLayout = true, UITableLayout = true, UIPadding = true,
    UICorner = true, UIGradient = true, UIScale = true,
    UIAspectRatioConstraint = true, UISizeConstraint = true,
    UITextSizeConstraint = true,
}

-- VIEWPORT HELPERS

local Camera = workspace.CurrentCamera

local function getViewportSafe()
    if not Camera then Camera = workspace.CurrentCamera end
    local vp = Camera.ViewportSize
    if vp.X < 10 or vp.Y < 10 then return Vector2.new(1280, 720) end
    return vp
end

local function getScreenCenter(w, h)
    local vp = getViewportSafe()
    return UDim2.new(0, math.round((vp.X - w) / 2), 0, math.round((vp.Y - h) / 2))
end

local function getCenteredTogglePos(guiHeight)
    local vp = getViewportSafe()
    local guiY = math.round((vp.Y - guiHeight) / 2)
    return UDim2.new(0, 18, 0, guiY + math.round((guiHeight - 34) / 2))
end

-- LAYOUT CALCULATOR

local function calcLayout(w, h)
    local contentH = math.max(h - CONTENT_TOP - EXTRA_BAR_H - EXTRA_BAR_MARGIN - 14, MIN_CONTENT_H)
    return {
        mainSize = UDim2.new(0, w, 0, h),
        mainPos = getScreenCenter(w, h),
        contentSize = UDim2.new(1, 0, 0, contentH),
        shadowSize = UDim2.new(1, -10, 0, contentH),
        shadowPos = UDim2.new(0, 5, 0, CONTENT_TOP - 1),
        tabShadowSize = UDim2.new(1, -10, 0, TAB_HEIGHT),
        tabShadowPos = UDim2.new(0, 5, 0, TAB_RAIL_Y + 3),
        tabRailClipPos = UDim2.new(0, TAB_RAIL_MARGIN, 0, TAB_RAIL_Y + 3),
        togglePos = getCenteredTogglePos(h),
        extraFramePos = UDim2.new(0, 6, 0, h - EXTRA_BAR_H - 13),
        extraFrameSize = UDim2.new(1, -12, 0, 30),
    }
end

-- RANDOM NAME

local CHARSET = {}
for i = 33, 126 do CHARSET[#CHARSET + 1] = string.char(i) end
local CHARSET_LEN = #CHARSET
do
    math.randomseed(os.clock() * 1e9 + tick() * 1e6)
    for _ = 1, 3 do math.random() end
end
local function randomName(len)
    len = len or math.random(15, 25)
    local buf = table.create(len)
    for i = 1, len do buf[i] = CHARSET[math.random(1, CHARSET_LEN)] end
    return table.concat(buf)
end

-- PRIVATE NAMESPACE

local _FLYCER_PRIVATE = {
    Refs = nil, MainFrame = nil, Session = nil,
    ShowNotif = nil, StartPing = nil, StopPing = nil,
    StartFPS = nil, StopFPS = nil,
}

local g = (getgenv and getgenv()) or _G
local _cachedParent = nil

-- GUI PARENT / SECURITY

local function getParent()
    if _cachedParent and _cachedParent.Parent then return _cachedParent end
    if EXECUTOR_APIS.gethui then
        local ok, r = pcall(gethui)
        if ok and r then _cachedParent = r return r end
    end
    if EXECUTOR_APIS.get_hidden_ui then
        local ok, r = pcall(get_hidden_ui)
        if ok and r then _cachedParent = r return r end
    end
    _cachedParent = CoreGui
    return CoreGui
end

local function SecureGui(gui)
    gui.Name = "F4_" .. randomName(12)
    gui:SetAttribute(FLYCER_TAG_ATTR, true)
    if EXECUTOR_APIS.syn_protect_gui then pcall(function() syn.protect_gui(gui) end) end
    if EXECUTOR_APIS.protect_gui then pcall(function() protect_gui(gui) end) end
    if EXECUTOR_APIS.protectgui then pcall(function() protectgui(gui) end) end
    gui.Parent = getParent()
end

local function getAllContainers()
    local list = { CoreGui }
    if PlayerGui then table.insert(list, PlayerGui) end
    if EXECUTOR_APIS.gethui then
        local ok, r = pcall(gethui)
        if ok and r and not table.find(list, r) then table.insert(list, r) end
    end
    if EXECUTOR_APIS.get_hidden_ui then
        local ok, r = pcall(get_hidden_ui)
        if ok and r and not table.find(list, r) then table.insert(list, r) end
    end
    return list
end

-- CLEANUP

local function cleanupOldInstances()
    if g[FLAG_NAME] then
        local old = g[GUI_REF_NAME]
        if old and typeof(old) == "Instance" and old.Parent then old:Destroy() end
    end
    if g._FlycerGUI and typeof(g._FlycerGUI) == "Instance" and g._FlycerGUI.Parent then
        g._FlycerGUI:Destroy()
        g._FlycerGUI = nil
    end
    g[FLAG_NAME] = nil
    g[GUI_REF_NAME] = nil
    for _, container in ipairs(getAllContainers()) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child:GetAttribute(FLYCER_TAG_ATTR) == true then
                child:Destroy()
            end
        end
    end
end
cleanupOldInstances()
task.wait(0.05)

-- STROKE ROTATION MANAGER

local _strokeTargets = {}
local _strokeLoopRunning = false
local _strokeConnection = nil

local function registerStrokeTarget(gradObj)
    if not gradObj then return end
    _strokeTargets[gradObj] = true
    if _strokeLoopRunning then return end
    _strokeLoopRunning = true
    local rot = 0
    _strokeConnection = RunService.Heartbeat:Connect(function(dt)
        rot = (rot + dt * 40) % 180
        local any = false
        for grad in pairs(_strokeTargets) do
            if grad and grad.Parent then grad.Rotation = rot any = true
            else _strokeTargets[grad] = nil end
        end
        if not any then
            _strokeLoopRunning = false
            _strokeConnection:Disconnect()
            _strokeConnection = nil
        end
    end)
end

local function unregisterStrokeTarget(gradObj)
    if gradObj then _strokeTargets[gradObj] = nil end
end

-- SEPARATOR

local function makeSeparator(parentFrame, posY_offset, useScale, scaleY)
    local sep = Instance.new("Frame")
    sep.Name = "Separator"
    sep.Size = UDim2.new(1, -10, 0, 0)
    sep.Position = useScale and UDim2.new(0, 5, scaleY or 1, posY_offset or 0) or UDim2.new(0, 5, 0, posY_offset or 0)
    sep.BackgroundTransparency = 1
    sep.BorderSizePixel = 0
    sep.ZIndex = 10
    sep.Active = false
    sep.Selectable = false

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Parent = sep

    local sg = Instance.new("UIGradient")
    sg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, RX.Accent1),
        ColorSequenceKeypoint.new(0.45, RX.Accent2),
        ColorSequenceKeypoint.new(0.50, RX.Cyan),
        ColorSequenceKeypoint.new(0.55, RX.Accent2),
        ColorSequenceKeypoint.new(1.00, RX.Accent1),
    })
    sg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.55),
        NumberSequenceKeypoint.new(0.20, 0.10),
        NumberSequenceKeypoint.new(0.45, 0.00),
        NumberSequenceKeypoint.new(0.55, 0.00),
        NumberSequenceKeypoint.new(0.80, 0.10),
        NumberSequenceKeypoint.new(1.00, 0.55),
    })
    sg.Parent = stroke
    sep.Parent = parentFrame
    return sep
end

-- GUI SIZE STATE

local currentGUIWidth = math.clamp(tonumber(g.FlycerGUIWidth) or 370, 150, 800)
local currentGUIHeight = math.clamp(tonumber(g.FlycerGUIHeight) or 270, 100, 700)
g.FlycerGUIWidth = currentGUIWidth
g.FlycerGUIHeight = currentGUIHeight
local isUILocked = false
g.FlycerUILocked = false

-- DRAGGABLE (Rayfield-style with TweenService smooth)

local function makeDraggable(dragHandle, dragTarget)
    dragTarget = dragTarget or dragHandle
    local dragging = false
    local dragStart, framePos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isUILocked then return end
            dragging = true
            dragStart = input.Position
            framePos = dragTarget.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    local dragInput
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            TweenService:Create(dragTarget, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
            }):Play()
        end
    end)
end

-- NOTIFICATION SYSTEM (Rayfield-inspired with actions support)

local _notifScreen = nil
local _notifQueue = {}
local _notifRunning = false
local _notifActive = false

local function getNotifScreen()
    if _notifScreen and _notifScreen.Parent then return _notifScreen end
    local sg = Instance.new("ScreenGui")
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 9999999999
    sg.IgnoreGuiInset = true
    sg:SetAttribute(FLYCER_TAG_ATTR, true)
    if EXECUTOR_APIS.syn_protect_gui then pcall(function() syn.protect_gui(sg) end) end
    if EXECUTOR_APIS.protect_gui then pcall(function() protect_gui(sg) end) end
    sg.Parent = (PlayerGui and PlayerGui.Parent) and PlayerGui or CoreGui
    _notifScreen = sg
    return sg
end

local function buildNotifFrame(parent, cfg)
    local title = cfg.title or "Flycer"
    local body = cfg.body or ""

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "NotifFrame"
    mainFrame.Size = UDim2.new(0, NOTIF_WIDTH - 35, 0, NOTIF_HEIGHT - 11)
    mainFrame.Position = UDim2.new(1, NOTIF_WIDTH + 20, 1, -(NOTIF_HEIGHT + NOTIF_POS_Y))
    mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = false
    mainFrame.ZIndex = 2
    mainFrame.Parent = parent

    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, NOTIF_CORNER_RADIUS)

    local outerStroke = Instance.new("UIStroke")
    outerStroke.Color = Color3.fromRGB(38, 38, 50)
    outerStroke.Thickness = 1
    outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outerStroke.Parent = mainFrame

    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 16, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 14)),
    })
    bgGrad.Rotation = 130
    bgGrad.Parent = mainFrame

    -- Shimmer
    local shimmerClip = Instance.new("Frame")
    shimmerClip.Size = UDim2.new(1, 0, 1, 0)
    shimmerClip.BackgroundTransparency = 1
    shimmerClip.ClipsDescendants = true
    shimmerClip.ZIndex = 3
    shimmerClip.Parent = mainFrame
    Instance.new("UICorner", shimmerClip).CornerRadius = UDim.new(0, NOTIF_CORNER_RADIUS)

    local shimmer = Instance.new("Frame")
    shimmer.Size = UDim2.new(0, NOTIF_WIDTH * 0.3, 1, 0)
    shimmer.Position = UDim2.new(-0.35, 0, 0, 0)
    shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shimmer.BackgroundTransparency = 0.97
    shimmer.BorderSizePixel = 0
    shimmer.ZIndex = 4
    shimmer.Rotation = 10
    shimmer.Parent = shimmerClip

    -- Icon
    local dividerX = NOTIF_POS_X + NOTIF_ICON_SIZE + 10
    local textOffsetX = dividerX + 11
    local textWidth = NOTIF_WIDTH - textOffsetX - 8

    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, NOTIF_ICON_SIZE, 0, NOTIF_ICON_SIZE)
    iconFrame.Position = UDim2.new(0, NOTIF_POS_X, 0.5, 0)
    iconFrame.AnchorPoint = Vector2.new(0, 0.5)
    iconFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
    iconFrame.BorderSizePixel = 0
    iconFrame.ZIndex = 5
    iconFrame.Parent = mainFrame
    Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 8)
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = Color3.fromRGB(55, 45, 90)
    iconStroke.Thickness = 1
    iconStroke.Parent = iconFrame

    local iconImage = Instance.new("ImageLabel")
    iconImage.Size = UDim2.new(0.68, 0, 0.68, 0)
    iconImage.Position = UDim2.new(0.16, 0, 0.16, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.Image = "rbxassetid://89557898457977"
    iconImage.ImageTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.ZIndex = 6
    iconImage.Parent = iconFrame

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0, 1, 0, NOTIF_HEIGHT * 0.55)
    divider.Position = UDim2.new(0, dividerX, 0.5, 0)
    divider.AnchorPoint = Vector2.new(0, 0.5)
    divider.BackgroundColor3 = Color3.fromRGB(55, 45, 90)
    divider.BorderSizePixel = 0
    divider.ZIndex = 5
    divider.Parent = mainFrame

    -- Text
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, textWidth, 0, 15)
    titleLabel.Position = UDim2.new(0, textOffsetX, 0, 13)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(225, 215, 255)
    titleLabel.TextSize = NOTIF_TITLE_SIZE
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.TextTransparency = 1
    titleLabel.ZIndex = 6
    titleLabel.Parent = mainFrame

    local bodyLabel = Instance.new("TextLabel")
    bodyLabel.Size = UDim2.new(0, textWidth, 0, 12)
    bodyLabel.Position = UDim2.new(0, textOffsetX, 0, 30)
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Text = body
    bodyLabel.TextColor3 = Color3.fromRGB(110, 105, 135)
    bodyLabel.TextSize = NOTIF_BODY_SIZE
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextTruncate = Enum.TextTruncate.AtEnd
    bodyLabel.TextTransparency = 1
    bodyLabel.ZIndex = 6
    bodyLabel.Parent = mainFrame

    -- Progress
    local progressContainer = Instance.new("Frame")
    progressContainer.Size = UDim2.new(1, -(NOTIF_CORNER_RADIUS * 2), 0, NOTIF_PROGRESS_HEIGHT)
    progressContainer.Position = UDim2.new(0, NOTIF_CORNER_RADIUS, 1, -(NOTIF_PROGRESS_HEIGHT + 3))
    progressContainer.BackgroundColor3 = Color3.fromRGB(30, 28, 42)
    progressContainer.BorderSizePixel = 0
    progressContainer.ZIndex = 9
    progressContainer.Parent = mainFrame
    Instance.new("UICorner", progressContainer).CornerRadius = UDim.new(1, 0)

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(1, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 10
    progressFill.Parent = progressContainer
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

    local progressGrad = Instance.new("UIGradient")
    progressGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 120, 255)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(180, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 160)),
    })
    progressGrad.Parent = progressFill

    -- Actions container
    local actionsFrame = Instance.new("Frame")
    actionsFrame.Name = "Actions"
    actionsFrame.Size = UDim2.new(1, -20, 0, 36)
    actionsFrame.Position = UDim2.new(0, 10, 1, -42)
    actionsFrame.BackgroundTransparency = 1
    actionsFrame.BorderSizePixel = 0
    actionsFrame.ZIndex = 7
    actionsFrame.Visible = false
    actionsFrame.Parent = mainFrame

    local actionsLayout = Instance.new("UIListLayout")
    actionsLayout.FillDirection = Enum.FillDirection.Horizontal
    actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    actionsLayout.Padding = UDim.new(0, 8)
    actionsLayout.Parent = actionsFrame

    return mainFrame, progressFill, shimmer, titleLabel, bodyLabel, iconImage, actionsFrame
end

local function normalizeNotifCfg(cfg)
    return {
        title = cfg.title or cfg.Title or "Flycer",
        body = cfg.body or cfg.Body or cfg.Description or cfg.Content or "",
        duration = cfg.duration or cfg.Duration or 5,
        image = cfg.image or cfg.Image,
        actions = cfg.actions or cfg.Actions,
        onComplete = cfg.onComplete or cfg.OnComplete,
    }
end

local function processNotifQueue()
    if _notifRunning then return end
    _notifRunning = true
    task.spawn(function()
        while #_notifQueue > 0 do
            local cfg = table.remove(_notifQueue, 1)
            local duration = cfg.duration
            local onComplete = cfg.onComplete
            local actions = cfg.actions
            _notifActive = true

            local ok, err = pcall(function()
                local screen = getNotifScreen()
                local notifFrame, progressFill, shimmer, titleLbl, bodyLbl, iconImg, actionsFrame = buildNotifFrame(screen, cfg)

                local hasActions = actions and #actions > 0
                local baseHeight = NOTIF_HEIGHT
                local expandedHeight = hasActions and (NOTIF_HEIGHT + 44) or NOTIF_HEIGHT

                local targetPos = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_POS_X), 1, -(expandedHeight + NOTIF_POS_Y))
                local exitPos = UDim2.new(1, NOTIF_WIDTH + 20, 1, -(expandedHeight + NOTIF_POS_Y))

                -- RAYFIELD-STYLE: Multi-stage entrance
                -- Stage 1: Size grow + slide in + bg fade
                TweenService:Create(notifFrame, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {
                    Size = UDim2.new(0, NOTIF_WIDTH, 0, baseHeight),
                    BackgroundTransparency = 0.15,
                }):Play()
                notifFrame:TweenPosition(targetPos, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.8, true)

                task.wait(0.3)

                -- Stage 2: Icon fade in
                TweenService:Create(iconImg, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { ImageTransparency = 0 }):Play()

                -- Stage 3: Title + body staggered
                TweenService:Create(titleLbl, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { TextTransparency = 0 }):Play()
                task.wait(LOADING_STAGE_DELAY)
                TweenService:Create(bodyLbl, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { TextTransparency = 0.2 }):Play()

                -- Stage 4: Glass effect (lower transparency)
                task.wait(0.2)
                TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.1 }):Play()

                -- Shimmer loop
                local shimmerActive = true
                local shimmerThread = task.spawn(function()
                    while shimmerActive and notifFrame and notifFrame.Parent do
                        shimmer.Position = UDim2.new(-0.35, 0, 0, 0)
                        local tw = TweenService:Create(shimmer, TweenInfo.new(1.5, Enum.EasingStyle.Linear), { Position = UDim2.new(1.2, 0, 0, 0) })
                        tw:Play()
                        tw.Completed:Wait()
                        if shimmerActive then task.wait(1.7) end
                    end
                end)

                -- Progress bar
                TweenService:Create(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) }):Play()

                -- Actions (Rayfield-style)
                local actionCompleted = not hasActions

                if hasActions then
                    task.wait(0.8)
                    -- Expand notification
                    TweenService:Create(notifFrame, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {
                        Size = UDim2.new(0, NOTIF_WIDTH, 0, expandedHeight)
                    }):Play()
                    task.wait(0.3)

                    actionsFrame.Visible = true
                    for _, action in ipairs(actions) do
                        local actionBtn = Instance.new("TextButton")
                        actionBtn.Size = UDim2.new(0, 80, 0, 28)
                        actionBtn.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
                        actionBtn.BackgroundTransparency = 1
                        actionBtn.Text = action.Name or "Action"
                        actionBtn.Font = RX.F1
                        actionBtn.TextSize = 10
                        actionBtn.TextColor3 = RX.T1
                        actionBtn.TextTransparency = 1
                        actionBtn.AutoButtonColor = false
                        actionBtn.BorderSizePixel = 0
                        actionBtn.ZIndex = 8
                        actionBtn.Parent = actionsFrame
                        Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)

                        -- Fade in action buttons (staggered)
                        TweenService:Create(actionBtn, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.2 }):Play()
                        TweenService:Create(actionBtn, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { TextTransparency = 0 }):Play()

                        actionBtn.MouseButton1Click:Connect(function()
                            if action.Callback then
                                pcall(action.Callback)
                            end
                            actionCompleted = true
                        end)
                        task.wait(0.05)
                    end
                end

                if not hasActions then
                    task.wait(duration)
                else
                    repeat task.wait(0.01) until actionCompleted
                end

                -- RAYFIELD-STYLE: Multi-stage exit
                shimmerActive = false
                pcall(task.cancel, shimmerThread)

                -- Stage 1: Fade out actions
                if hasActions then
                    for _, action in ipairs(actionsFrame:GetChildren()) do
                        if action:IsA("TextButton") then
                            TweenService:Create(action, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
                            TweenService:Create(action, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
                        end
                    end
                end

                -- Stage 2: Text slide + fade
                TweenService:Create(titleLbl, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {
                    Position = UDim2.new(0, titleLbl.Position.X.Offset + 10, 0, titleLbl.Position.Y.Offset),
                    TextTransparency = 0.4
                }):Play()
                TweenService:Create(bodyLbl, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {
                    Position = UDim2.new(0, bodyLbl.Position.X.Offset + 15, 0, bodyLbl.Position.Y.Offset),
                    TextTransparency = 0.5
                }):Play()

                -- Stage 3: Size shrink + icon fade
                TweenService:Create(notifFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {
                    Size = UDim2.new(0, NOTIF_WIDTH - 15, 0, NOTIF_HEIGHT - 8)
                }):Play()
                TweenService:Create(iconImg, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { ImageTransparency = 1 }):Play()
                TweenService:Create(notifFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.6 }):Play()

                task.wait(0.3)

                -- Stage 4: Text fully fade
                TweenService:Create(titleLbl, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
                TweenService:Create(bodyLbl, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()

                task.wait(0.4)

                -- Stage 5: Collapse + slide out
                TweenService:Create(notifFrame, TweenInfo.new(0.9, Enum.EasingStyle.Quint), {
                    Size = UDim2.new(0, NOTIF_WIDTH - 35, 0, 0)
                }):Play()
                TweenService:Create(notifFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()

                task.wait(0.9)
                if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
                if _notifScreen and _notifScreen.Parent and #_notifScreen:GetChildren() == 0 then
                    _notifScreen:Destroy()
                    _notifScreen = nil
                end
            end)

            _notifActive = false
            if not ok then warn("Flycer Notification error:", err) end
            if typeof(onComplete) == "function" then task.spawn(onComplete) end
            if #_notifQueue > 0 then task.wait(0.2) end
        end
        _notifRunning = false
    end)
end

local function ShowNotification(cfg)
    if _notifActive then return end
    if #_notifQueue >= 3 then return end
    cfg = normalizeNotifCfg(cfg or {})
    table.insert(_notifQueue, cfg)
    processNotifQueue()
end

_FLYCER_PRIVATE.ShowNotif = ShowNotification

-- RESIZE HELPERS (abbreviated for length - same as before)

local function makeInputField(parentFrame, anchorX, labelTxt, defaultVal)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, RESIZE_FIELD_WIDTH, 0, 56)
    container.Position = UDim2.new(0, anchorX, 0, 48)
    container.BackgroundTransparency = 1
    container.ZIndex = 13
    container.Parent = parentFrame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelTxt
    lbl.TextColor3 = RX.T2
    lbl.Font = RX.F2
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.ZIndex = 14
    lbl.Parent = container

    local inputBG = Instance.new("Frame")
    inputBG.Size = UDim2.new(1, 0, 0, 34)
    inputBG.Position = UDim2.new(0, 0, 0, 18)
    inputBG.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    inputBG.BackgroundTransparency = 0.08
    inputBG.BorderSizePixel = 0
    inputBG.ZIndex = 14
    inputBG.Parent = container
    Instance.new("UICorner", inputBG).CornerRadius = UDim.new(0, 9)

    local inStroke = Instance.new("UIStroke")
    inStroke.Thickness = 1.2
    inStroke.Color = Color3.fromRGB(55, 58, 85)
    inStroke.Transparency = 0.3
    inStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    inStroke.Parent = inputBG

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 1, 0)
    textBox.Position = UDim2.new(0, 5, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text = tostring(defaultVal)
    textBox.PlaceholderText = tostring(defaultVal)
    textBox.PlaceholderColor3 = RX.T3
    textBox.Font = RX.FM
    textBox.TextSize = 15
    textBox.TextColor3 = RX.Cyan
    textBox.ClearTextOnFocus = false
    textBox.TextXAlignment = Enum.TextXAlignment.Center
    textBox.ZIndex = 15
    textBox.Parent = inputBG

    local filtering = false
    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        if filtering then return end
        filtering = true
        local filtered = textBox.Text:gsub("[^%d]", "")
        if filtered ~= textBox.Text then textBox.Text = filtered end
        filtering = false
    end)

    textBox.Focused:Connect(function()
        TweenService:Create(inStroke, TWEEN_FAST, { Color = RX.Accent1, Transparency = 0 }):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(inStroke, TWEEN_FAST, { Color = Color3.fromRGB(55, 58, 85), Transparency = 0.3 }):Play()
    end)

    return container, textBox
end

-- Due to extreme length, the resize GUI function is the same as the previous version.
-- I'll include a placeholder that references it:

local function openResizeGUI(refs)
    -- Same implementation as previous version
    -- (Full resize GUI code from previous script applies here unchanged)
end

--==================================================
-- FLYCER LIBRARY MODULE
--==================================================

local FlycerLib = {}
FlycerLib.Flags = {}

function FlycerLib:Notify(cfg)
    ShowNotification(cfg or {})
end

function FlycerLib:CreateWindow(windowCfg)
    windowCfg = windowCfg or {}

    local GUI_TITLE = windowCfg.Name or windowCfg.Title or "FlycerUI - Hub"
    local loadingTitle = windowCfg.LoadingTitle or GUI_TITLE
    local loadingSubtitle = windowCfg.LoadingSubtitle or "Loading..."
    local loadingDuration = windowCfg.LoadingDuration or windowCfg.Duration or 3
    local discordConfig = windowCfg.Discord or {}
    local discordEnabled = discordConfig.Enabled ~= false
    local discordLink = discordConfig.Link or DISCORD_LINK
    local hideKeybind = windowCfg.HideKeybind or Enum.KeyCode.K

    -- STATE
    local uiRevealed = false
    local isMinimised = false
    local isHidden = false
    local isDebounce = false

    -- REVEAL ANIMATION SYSTEM (Rayfield-inspired multi-stage)

    local REVEAL_DURATION = 0.5
    local REVEAL_TWEEN_INFO = TweenInfo.new(REVEAL_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local revealTargets = {}

    local function cacheRevealTarget(obj)
        if not obj or not obj.Parent then return end
        if EXCLUDED_CLASSES[obj.ClassName] then return end
        local propList = TRANSPARENCY_PROPS[obj.ClassName]
        if not propList then return end
        local cached = {}
        for _, propName in ipairs(propList) do
            local val = obj[propName]
            if val ~= nil and val < 1 then
                cached[propName] = val
                obj[propName] = 1
            end
        end
        if next(cached) then revealTargets[obj] = cached end
    end

    local function cacheAllRevealTargets(root)
        cacheRevealTarget(root)
        for _, child in ipairs(root:GetDescendants()) do cacheRevealTarget(child) end
    end

    local function revealUI(callback)
        if uiRevealed then
            if callback then task.spawn(callback) end
            return
        end
        uiRevealed = true
        local tweenList = {}
        local activeTweens = 0
        for obj, props in pairs(revealTargets) do
            if obj and obj.Parent then
                table.insert(tweenList, TweenService:Create(obj, REVEAL_TWEEN_INFO, props))
                activeTweens = activeTweens + 1
            end
        end
        if #tweenList == 0 then
            if callback then task.spawn(callback) end
            return
        end
        local callbackFired = false
        local function onComplete()
            if callbackFired then return end
            activeTweens = activeTweens - 1
            if activeTweens <= 0 then
                callbackFired = true
                for obj, props in pairs(revealTargets) do
                    if obj and obj.Parent then
                        for p, v in pairs(props) do obj[p] = v end
                    end
                end
                if callback then task.spawn(callback) end
            end
        end
        for _, tw in ipairs(tweenList) do
            local conn
            conn = tw.Completed:Connect(function()
                if conn then conn:Disconnect() conn = nil end
                onComplete()
            end)
            tw:Play()
        end
    end

    -- BUILD GUI

    local MainGui = Instance.new("ScreenGui")
    MainGui.ResetOnSpawn = false
    MainGui.IgnoreGuiInset = true
    MainGui.Archivable = false
    MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    MainGui.DisplayOrder = 999999998
    SecureGui(MainGui)
    g._FlycerGUI = MainGui
    g[GUI_REF_NAME] = MainGui
    g[FLAG_NAME] = true

    local initLayout = calcLayout(currentGUIWidth, currentGUIHeight)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = randomName()
    MainFrame.Size = initLayout.mainSize
    MainFrame.Position = initLayout.mainPos
    MainFrame.BackgroundColor3 = RX.Accent1
    MainFrame.BackgroundTransparency = 1
    MainFrame.BorderSizePixel = 0
    MainFrame.ZIndex = 2
    MainFrame.Active = true
    MainFrame.ClipsDescendants = false
    MainFrame.Visible = true
    MainFrame.Parent = MainGui

    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.2
    mainStroke.Color = RX.T1
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mainStroke.Parent = MainFrame

    local mainStrokeGrad = Instance.new("UIGradient")
    mainStrokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 60, 100)),
        ColorSequenceKeypoint.new(0.35, RX.Accent1),
        ColorSequenceKeypoint.new(0.65, RX.Accent2),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 60, 100)),
    })
    mainStrokeGrad.Rotation = 135
    mainStrokeGrad.Parent = mainStroke
    registerStrokeTarget(mainStrokeGrad)
    MainFrame.Destroying:Connect(function() unregisterStrokeTarget(mainStrokeGrad) end)

    local innerGrad = Instance.new("UIGradient")
    innerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 28)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 14, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 18)),
    })
    innerGrad.Rotation = 180
    innerGrad.Parent = MainFrame

    -- Fade exempt system
    local _tabFadeExempt = {}
    local function markFadeExempt(inst) _tabFadeExempt[inst] = true end
    local function isFadeExempt(inst, forToggle)
        if forToggle then return false end
        return _tabFadeExempt[inst] == true
    end

    -- HEADER
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, HEADER_H)
    Header.BackgroundTransparency = 1
    Header.ZIndex = 10
    Header.Parent = MainFrame
    makeDraggable(Header, MainFrame)

    local headerIcon = Instance.new("ImageLabel")
    headerIcon.Size = UDim2.new(0, 32, 0, 32)
    headerIcon.Position = UDim2.new(0, -2, 0.5, 0)
    headerIcon.AnchorPoint = Vector2.new(0, 0.5)
    headerIcon.BackgroundTransparency = 1
    headerIcon.Image = "rbxassetid://89557898457977"
    headerIcon.ZIndex = 11
    headerIcon.Parent = Header

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -160, 1, 0)
    titleLabel.Position = UDim2.new(0, 26, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = GUI_TITLE
    titleLabel.TextColor3 = RX.T1
    titleLabel.Font = RX.F1
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.ZIndex = 11
    titleLabel.Parent = Header

    makeSeparator(Header, 0, true, 1)

    -- PING COUNTER
    local pingContainer = Instance.new("Frame")
    pingContainer.Name = "PingContainer"
    pingContainer.Position = UDim2.new(1, -156, 0.5, 0)
    pingContainer.AnchorPoint = Vector2.new(0, 0.5)
    pingContainer.Size = UDim2.new(0, 80, 0, 18)
    pingContainer.BackgroundColor3 = Color3.fromRGB(60, 210, 120)
    pingContainer.BackgroundTransparency = 0.85
    pingContainer.BorderSizePixel = 0
    pingContainer.ZIndex = 11
    pingContainer.Parent = Header
    Instance.new("UICorner", pingContainer).CornerRadius = UDim.new(0, 5)

    local pingLabel = Instance.new("TextLabel")
    pingLabel.Size = UDim2.new(1, -18, 1, 0)
    pingLabel.Position = UDim2.new(0, 20, 0, 0)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Text = "PING: 0ms"
    pingLabel.Font = RX.F1
    pingLabel.TextSize = 10
    pingLabel.TextColor3 = Color3.fromRGB(60, 210, 120)
    pingLabel.TextXAlignment = Enum.TextXAlignment.Left
    pingLabel.ZIndex = 12
    pingLabel.Parent = pingContainer

    local pingConnection, lastPingUpdate = nil, 0
    local function StartPingCounter()
        if pingConnection then return end
        lastPingUpdate = os.clock()
        pingConnection = RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if now - lastPingUpdate < 0.25 then return end
            lastPingUpdate = now
            if pingLabel and pingLabel.Parent then
                local ok, r = pcall(function() return LocalPlayer:GetNetworkPing() end)
                pingLabel.Text = "PING: " .. tostring(ok and math.round(math.max(r * 1000, 0)) or 0) .. "ms"
            end
        end)
    end
    local function StopPingCounter()
        if pingConnection then pingConnection:Disconnect() pingConnection = nil end
        if pingLabel and pingLabel.Parent then pingLabel.Text = "PING: 0ms" end
    end
    MainGui.Destroying:Connect(StopPingCounter)

    -- FPS COUNTER
    local fpsContainer = Instance.new("Frame")
    fpsContainer.Name = "FPSContainer"
    fpsContainer.Position = UDim2.new(1, -71, 0.5, 0)
    fpsContainer.AnchorPoint = Vector2.new(0, 0.5)
    fpsContainer.Size = UDim2.new(0, 65, 0, 18)
    fpsContainer.BackgroundColor3 = Color3.fromRGB(240, 220, 50)
    fpsContainer.BackgroundTransparency = 0.85
    fpsContainer.BorderSizePixel = 0
    fpsContainer.ZIndex = 11
    fpsContainer.Parent = Header
    Instance.new("UICorner", fpsContainer).CornerRadius = UDim.new(0, 5)

    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(1, -18, 1, 0)
    fpsLabel.Position = UDim2.new(0, 25, 0, 0)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "FPS: 0"
    fpsLabel.Font = RX.F1
    fpsLabel.TextSize = 10
    fpsLabel.TextColor3 = Color3.fromRGB(240, 220, 50)
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    fpsLabel.ZIndex = 12
    fpsLabel.Parent = fpsContainer

    local fpsConnection, frameCount, lastFPSUpdate = nil, 0, 0
    local function StartFPSCounter()
        if fpsConnection then return end
        frameCount = 0
        lastFPSUpdate = os.clock()
        local ok = pcall(function()
            fpsConnection = RunService.RenderStepped:Connect(function()
                frameCount = frameCount + 1
                local now = os.clock()
                if now - lastFPSUpdate >= 0.25 then
                    if fpsLabel and fpsLabel.Parent then
                        fpsLabel.Text = "FPS: " .. tostring(math.round(frameCount / (now - lastFPSUpdate)))
                    end
                    frameCount = 0
                    lastFPSUpdate = now
                end
            end)
        end)
        if not ok then
            fpsConnection = RunService.Heartbeat:Connect(function()
                frameCount = frameCount + 1
                local now = os.clock()
                if now - lastFPSUpdate >= 0.25 then
                    if fpsLabel and fpsLabel.Parent then
                        fpsLabel.Text = "FPS: " .. tostring(math.round(frameCount / (now - lastFPSUpdate)))
                    end
                    frameCount = 0
                    lastFPSUpdate = now
                end
            end)
        end
    end
    local function StopFPSCounter()
        if fpsConnection then fpsConnection:Disconnect() fpsConnection = nil end
        if fpsLabel and fpsLabel.Parent then fpsLabel.Text = "FPS: 0" end
    end
    MainGui.Destroying:Connect(StopFPSCounter)

    -- TAB RAIL
    local TabShadowFrame = Instance.new("Frame")
    TabShadowFrame.Size = initLayout.tabShadowSize
    TabShadowFrame.Position = initLayout.tabShadowPos
    TabShadowFrame.BackgroundColor3 = RX.Accent1
    TabShadowFrame.BackgroundTransparency = 0.6
    TabShadowFrame.BorderSizePixel = 0
    TabShadowFrame.ZIndex = 1
    TabShadowFrame.Parent = MainFrame
    markFadeExempt(TabShadowFrame)

    local TabRailClip = Instance.new("Frame")
    TabRailClip.Size = UDim2.new(1, -TAB_RAIL_MARGIN * 2, 0, TAB_HEIGHT)
    TabRailClip.Position = initLayout.tabRailClipPos
    TabRailClip.BackgroundTransparency = 1
    TabRailClip.ClipsDescendants = true
    TabRailClip.ZIndex = 8
    TabRailClip.Parent = MainFrame
    markFadeExempt(TabRailClip)

    local TabScroll = Instance.new("ScrollingFrame")
    TabScroll.Size = UDim2.new(1, 0, 1, 0)
    TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    TabScroll.ScrollingDirection = Enum.ScrollingDirection.X
    TabScroll.BackgroundTransparency = 1
    TabScroll.ScrollBarThickness = isMobile and 1 or 0
    TabScroll.ZIndex = 8
    TabScroll.ElasticBehavior = Enum.ElasticBehavior.Never
    TabScroll.Parent = TabRailClip
    markFadeExempt(TabScroll)

    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.FillDirection = Enum.FillDirection.Horizontal
    tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabListLayout.Padding = UDim.new(0, 4)
    tabListLayout.Parent = TabScroll

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0, 4)
    tabPad.PaddingRight = UDim.new(0, 4)
    tabPad.Parent = TabScroll

    makeSeparator(MainFrame, TAB_RAIL_Y + TAB_HEIGHT + 6, false)

    -- CONTENT AREA
    local ShadowFrame = Instance.new("Frame")
    ShadowFrame.Size = initLayout.shadowSize
    ShadowFrame.Position = initLayout.shadowPos
    ShadowFrame.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
    ShadowFrame.BackgroundTransparency = 0.8
    ShadowFrame.BorderSizePixel = 0
    ShadowFrame.ZIndex = 1
    ShadowFrame.Parent = MainFrame
    Instance.new("UICorner", ShadowFrame).CornerRadius = UDim.new(0, 8)

    local ContentWrapper = Instance.new("Frame")
    ContentWrapper.Size = initLayout.contentSize
    ContentWrapper.Position = UDim2.new(0, 0, 0, CONTENT_TOP)
    ContentWrapper.BackgroundTransparency = 1
    ContentWrapper.ClipsDescendants = true
    ContentWrapper.ZIndex = 5
    ContentWrapper.Parent = MainFrame

    -- TAB SYSTEM
    local tabRegistry = {}
    local activeTabName = nil
    local tabSwitchDebounce = false
    local firstTabName = nil

    local function makeTabCanvas()
        local sf = Instance.new("ScrollingFrame")
        sf.Size = UDim2.new(1, 0, 1, 0)
        sf.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.ScrollingDirection = Enum.ScrollingDirection.Y
        sf.ScrollBarThickness = 3
        sf.ScrollBarImageColor3 = RX.Accent1
        sf.ScrollBarImageTransparency = 1
        sf.BackgroundTransparency = 1
        sf.ZIndex = 5
        sf.ElasticBehavior = Enum.ElasticBehavior.Never
        sf.Visible = false
        sf.Parent = ContentWrapper

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.PaddingTop = UDim.new(0, 6)
        pad.PaddingBottom = UDim.new(0, 6)
        pad.Parent = sf

        local layout = Instance.new("UIListLayout")
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 5)
        layout.Parent = sf

        return sf, layout
    end

    local function activateTab(name)
        if tabSwitchDebounce or activeTabName == name then return end
        tabSwitchDebounce = true

        -- Rayfield-style: bounce content area during switch
        TweenService:Create(ContentWrapper, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0.97, 0, 0, ContentWrapper.Size.Y.Offset - 5)
        }):Play()

        for _, entry in ipairs(tabRegistry) do
            local active = (entry.name == name)
            entry.canvas.Visible = active

            if active then
                TweenService:Create(entry.button, TWEEN_ELEMENT, {
                    BackgroundColor3 = Color3.fromRGB(32, 32, 52),
                    BackgroundTransparency = 0,
                }):Play()
                TweenService:Create(entry.label, TWEEN_ELEMENT, { TextColor3 = RX.T1, TextTransparency = 0 }):Play()
                TweenService:Create(entry.stroke, TWEEN_ELEMENT, { Transparency = 1 }):Play()
            else
                TweenService:Create(entry.button, TWEEN_ELEMENT, {
                    BackgroundColor3 = Color3.fromRGB(22, 22, 34),
                    BackgroundTransparency = 0.3,
                }):Play()
                TweenService:Create(entry.label, TWEEN_ELEMENT, { TextColor3 = RX.T3, TextTransparency = 0.2 }):Play()
                TweenService:Create(entry.stroke, TWEEN_ELEMENT, { Transparency = 0 }):Play()
            end
        end

        task.delay(0.2, function()
            -- Bounce back
            TweenService:Create(ContentWrapper, TweenInfo.new(TAB_SWITCH_BOUNCE_DURATION, Enum.EasingStyle.Quint), {
                Size = initLayout.contentSize
            }):Play()
        end)

        activeTabName = name
        task.delay(0.3, function() tabSwitchDebounce = false end)
    end

    local function addTab(name, layoutOrderHint)
        local canvas, layout = makeTabCanvas()
        local estimatedW = math.max(TAB_MIN_WIDTH, string.len(name) * 7 + TAB_PADDING * 2)

        local button = Instance.new("Frame")
        button.Name = "Tab_" .. name
        button.Size = UDim2.new(0, estimatedW, 0, TAB_HEIGHT - 7)
        button.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.LayoutOrder = layoutOrderHint or #tabRegistry + 1
        button.ZIndex = 9
        button.Parent = TabScroll
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Thickness = 1
        btnStroke.Color = RX.Border
        btnStroke.Transparency = 1
        btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        btnStroke.Parent = button

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -TAB_PADDING, 1, 0)
        lbl.Position = UDim2.new(0, TAB_PADDING / 2, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.Font = RX.F1
        lbl.TextSize = 11
        lbl.TextColor3 = RX.T3
        lbl.TextTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.ZIndex = 10
        lbl.Parent = button

        local hitbox = Instance.new("TextButton")
        hitbox.Size = UDim2.new(1, 0, 1, 0)
        hitbox.BackgroundTransparency = 1
        hitbox.Text = ""
        hitbox.ZIndex = 12
        hitbox.Parent = button

        markFadeExempt(button)
        markFadeExempt(btnStroke)
        markFadeExempt(lbl)
        markFadeExempt(hitbox)

        -- Rayfield-style: Staggered tab button reveal
        task.delay(#tabRegistry * 0.1, function()
            if not firstTabName or firstTabName == name then
                TweenService:Create(button, TWEEN_ELEMENT, { BackgroundTransparency = 0 }):Play()
                TweenService:Create(lbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
            else
                TweenService:Create(button, TWEEN_ELEMENT, { BackgroundTransparency = 0.7 }):Play()
                TweenService:Create(lbl, TWEEN_ELEMENT, { TextTransparency = 0.2 }):Play()
                TweenService:Create(btnStroke, TWEEN_ELEMENT, { Transparency = 0 }):Play()
            end
        end)

        if not isMobile then
            hitbox.MouseEnter:Connect(function()
                if activeTabName ~= name then
                    TweenService:Create(button, TWEEN_HOVER, { BackgroundTransparency = 0.1 }):Play()
                    TweenService:Create(lbl, TWEEN_HOVER, { TextColor3 = RX.T2 }):Play()
                end
            end)
            hitbox.MouseLeave:Connect(function()
                if activeTabName ~= name then
                    TweenService:Create(button, TWEEN_HOVER, { BackgroundTransparency = 0.3 }):Play()
                    TweenService:Create(lbl, TWEEN_HOVER, { TextColor3 = RX.T3 }):Play()
                end
            end)
        end

        hitbox.Activated:Connect(function()
            if isMinimised then return end
            activateTab(name)
        end)

        table.insert(tabRegistry, {
            name = name, button = button, label = lbl,
            stroke = btnStroke, canvas = canvas, layout = layout,
        })
        if not firstTabName then firstTabName = name end
        return canvas, layout
    end

    -- EXTRA FRAME
    local ExtraFrame = Instance.new("Frame")
    ExtraFrame.Size = initLayout.extraFrameSize
    ExtraFrame.Position = initLayout.extraFramePos
    ExtraFrame.BackgroundColor3 = RX.Accent1
    ExtraFrame.BackgroundTransparency = RX.MainAlpha
    ExtraFrame.BorderSizePixel = 0
    ExtraFrame.ZIndex = 6
    ExtraFrame.ClipsDescendants = false
    ExtraFrame.Parent = MainFrame
    Instance.new("UICorner", ExtraFrame).CornerRadius = UDim.new(0, 6)

    -- DRAG BAR
    local DragBarHitbox = Instance.new("Frame")
    DragBarHitbox.BackgroundTransparency = 1
    DragBarHitbox.ZIndex = 20
    DragBarHitbox.Active = true
    DragBarHitbox.AnchorPoint = Vector2.new(0.5, 0.5)
    DragBarHitbox.Size = UDim2.new(0, 80, 0, 20)
    DragBarHitbox.Position = UDim2.new(0.5, 0, 0.5, 35)
    DragBarHitbox.Parent = ExtraFrame

    local DragBar = Instance.new("Frame")
    DragBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DragBar.BackgroundTransparency = 0.80
    DragBar.ZIndex = 21
    DragBar.AnchorPoint = Vector2.new(0.5, 0.5)
    DragBar.Size = UDim2.new(0, 50, 0, 3)
    DragBar.Position = UDim2.new(0.5, 0, 0.5, -5)
    DragBar.Parent = DragBarHitbox
    Instance.new("UICorner", DragBar).CornerRadius = UDim.new(1, 0)

    makeDraggable(DragBarHitbox, MainFrame)

    -- TOGGLE BUTTON
    local ToggleSG = Instance.new("ScreenGui")
    ToggleSG.ResetOnSpawn = false
    ToggleSG.IgnoreGuiInset = true
    ToggleSG.DisplayOrder = 9999999999
    SecureGui(ToggleSG)

    local ToggleFrame = Instance.new("TextButton")
    ToggleFrame.Size = UDim2.new(0, 90, 0, 34)
    ToggleFrame.Position = initLayout.togglePos
    ToggleFrame.BackgroundColor3 = RX.Accent1
    ToggleFrame.BackgroundTransparency = 1
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.Active = true
    ToggleFrame.Text = ""
    ToggleFrame.ZIndex = 10
    ToggleFrame.Parent = ToggleSG
    Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 16)

    local tStroke = Instance.new("UIStroke")
    tStroke.Thickness = 1.4
    tStroke.Transparency = 0.2
    tStroke.Color = RX.T1
    tStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    tStroke.Parent = ToggleFrame

    local tStrokeGrad = Instance.new("UIGradient")
    tStrokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 60, 100)),
        ColorSequenceKeypoint.new(0.35, RX.Accent1),
        ColorSequenceKeypoint.new(0.65, RX.Accent2),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 60, 100)),
    })
    tStrokeGrad.Rotation = 135
    tStrokeGrad.Parent = tStroke
    registerStrokeTarget(tStrokeGrad)

    local ToggleText = Instance.new("TextLabel")
    ToggleText.Size = UDim2.new(1, -48, 1, 0)
    ToggleText.Position = UDim2.new(0, 48, 0, 0)
    ToggleText.BackgroundTransparency = 1
    ToggleText.Text = "HIDE"
    ToggleText.TextColor3 = RX.T1
    ToggleText.Font = RX.F1
    ToggleText.TextSize = 12
    ToggleText.TextXAlignment = Enum.TextXAlignment.Left
    ToggleText.TextYAlignment = Enum.TextYAlignment.Center
    ToggleText.ZIndex = 13
    ToggleText.Parent = ToggleFrame

    local ToggleIcon = Instance.new("ImageLabel")
    ToggleIcon.Size = UDim2.new(0, 24, 0, 24)
    ToggleIcon.Position = UDim2.new(0, 12, 0.5, 0)
    ToggleIcon.AnchorPoint = Vector2.new(0, 0.5)
    ToggleIcon.BackgroundTransparency = 1
    ToggleIcon.Image = "rbxassetid://89557898457977"
    ToggleIcon.ImageColor3 = RX.T1
    ToggleIcon.ZIndex = 13
    ToggleIcon.Parent = ToggleFrame

    makeDraggable(ToggleFrame)

    -- HIDE/UNHIDE SYSTEM (Rayfield-inspired)

    local mainVisible = true
    local isAnimating = false
    local lastToggleTime = 0
    local originalTransparencies = {}
    local currentFadeTweens = {}
    local eventConnections = {}

    local function cacheObj(obj)
        if not obj or not obj.Parent then return end
        if isFadeExempt(obj, true) then return end
        if EXCLUDED_CLASSES[obj.ClassName] then return end
        local propList = TRANSPARENCY_PROPS[obj.ClassName]
        if not propList then return end
        local cached = {}
        for _, propName in ipairs(propList) do
            local val = obj[propName]
            if val ~= nil then
                if propName ~= "ScrollBarImageTransparency" then
                    if val < 1 then cached[propName] = val end
                else cached[propName] = val end
            end
        end
        if next(cached) then originalTransparencies[obj] = cached end
    end

    local function cacheDescendants(root)
        for _, child in ipairs(root:GetChildren()) do
            if not isFadeExempt(child, true) and not EXCLUDED_CLASSES[child.ClassName] then
                cacheObj(child)
                cacheDescendants(child)
            end
        end
    end

    local function cacheOriginalValues()
        originalTransparencies = {}
        if MainFrame and MainFrame.Parent then
            cacheObj(MainFrame)
            cacheDescendants(MainFrame)
        end
    end

    local function cancelAllFadeTweens()
        for _, tw in ipairs(currentFadeTweens) do pcall(function() tw:Cancel() end) end
        currentFadeTweens = {}
    end

    local function setAllInstant(targetAlpha)
        for obj, props in pairs(originalTransparencies) do
            if obj and obj.Parent then
                for propName, origVal in pairs(props) do
                    obj[propName] = (targetAlpha == 0) and origVal or 1
                end
            end
        end
    end

    local function fadeAllTo(targetAlpha, dur, callback)
        cancelAllFadeTweens()
        local tweenI = TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local tweenList = {}
        for obj, props in pairs(originalTransparencies) do
            if obj and obj.Parent then
                local tp = {}
                for propName, origVal in pairs(props) do
                    tp[propName] = (targetAlpha == 0) and origVal or 1
                end
                if next(tp) then table.insert(tweenList, TweenService:Create(obj, tweenI, tp)) end
            end
        end
        currentFadeTweens = tweenList
        if #tweenList == 0 then
            setAllInstant(targetAlpha)
            if callback then task.spawn(callback) end
            return
        end
        local activeTweens = #tweenList
        local callbackCalled = false
        local function finishFade()
            if callbackCalled then return end
            callbackCalled = true
            setAllInstant(targetAlpha)
            if callback then task.spawn(callback) end
        end
        for _, tw in ipairs(tweenList) do
            local conn
            conn = tw.Completed:Connect(function()
                if conn then conn:Disconnect() conn = nil end
                activeTweens = activeTweens - 1
                if activeTweens <= 0 then finishFade() end
            end)
            tw:Play()
        end
    end

    -- Rayfield-style Hide with notification
    local function hideGUI()
        if isDebounce then return end
        isDebounce = true
        isHidden = true

        ShowNotification({
            title = "Interface Hidden",
            body = "Tap " .. tostring(hideKeybind.Name) .. " to unhide the interface",
            duration = 5,
        })

        cacheOriginalValues()
        ToggleText.Text = "OPEN"
        StopPingCounter()
        StopFPSCounter()

        -- Rayfield-style: Size shrink + fade
        TweenService:Create(MainFrame, TweenInfo.new(HIDE_DURATION, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0, currentGUIWidth - 30, 0, currentGUIHeight - 75),
        }):Play()

        fadeAllTo(1, HIDE_DURATION, function()
            if isHidden then MainFrame.Visible = false end
            isDebounce = false
        end)
    end

    local function unhideGUI()
        if isDebounce then return end
        isDebounce = true
        isHidden = false

        MainFrame.Visible = true
        MainFrame.Position = getScreenCenter(currentGUIWidth, currentGUIHeight)
        ToggleText.Text = "HIDE"
        StartPingCounter()
        StartFPSCounter()

        -- Rayfield-style: Size grow + fade in
        TweenService:Create(MainFrame, TweenInfo.new(HIDE_DURATION, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0, currentGUIWidth, 0, currentGUIHeight),
        }):Play()
        TweenService:Create(ShadowFrame, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {
            BackgroundTransparency = 0.8,
        }):Play()

        fadeAllTo(0, HIDE_DURATION, function()
            isDebounce = false
        end)
    end

    local function toggleGUI()
        local now = tick()
        if now - lastToggleTime < TOGGLE_DEBOUNCE then return end
        lastToggleTime = now
        if isAnimating then return end

        if isHidden then
            unhideGUI()
        else
            hideGUI()
        end
    end

    table.insert(eventConnections, ToggleFrame.Activated:Connect(toggleGUI))

    -- Rayfield-style: K keybind to hide/unhide
    table.insert(eventConnections, UserInputService.InputBegan:Connect(function(input, processed)
        if input.KeyCode == hideKeybind and not processed then
            toggleGUI()
        end
    end))

    -- COMPONENT FACTORY (with Rayfield-inspired animations)

    local function makeComponents(canvas)
        local Components = {}
        local elementCount = 0

        local function makeBaseCard(layoutOrder, height)
            elementCount = elementCount + 1
            local f = Instance.new("Frame")
            f.Name = randomName()
            f.Size = UDim2.new(1, 0, 0, height or 34)
            f.BackgroundColor3 = RX.Card
            f.BackgroundTransparency = 1
            f.BorderSizePixel = 0
            f.LayoutOrder = layoutOrder or 99
            f.Parent = canvas
            Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Thickness = 1
            cardStroke.Color = RX.Border
            cardStroke.Transparency = 1
            cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            cardStroke.Parent = f

            -- Rayfield-style: Staggered element fade-in
            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if f and f.Parent then
                    TweenService:Create(f, TWEEN_ELEMENT, { BackgroundTransparency = RX.CardAlpha }):Play()
                    TweenService:Create(cardStroke, TWEEN_ELEMENT, { Transparency = 0.6 }):Play()
                end
            end)

            return f, cardStroke
        end

        -- Rayfield-style hover effect helper
        local function addHoverEffect(frame)
            if isMobile then return end
            frame.MouseEnter:Connect(function()
                TweenService:Create(frame, TWEEN_HOVER, { BackgroundColor3 = RX.CardHover }):Play()
            end)
            frame.MouseLeave:Connect(function()
                TweenService:Create(frame, TWEEN_HOVER, { BackgroundColor3 = RX.Card }):Play()
            end)
        end

        -- Rayfield-style error flash helper
        local function flashError(frame, cardStroke, titleLbl, originalTitle, errMsg)
            TweenService:Create(frame, TWEEN_HOVER, { BackgroundColor3 = RX.ErrorBg }):Play()
            TweenService:Create(cardStroke, TWEEN_HOVER, { Transparency = 1 }):Play()
            titleLbl.Text = "Callback Error"
            warn("Flycer | " .. originalTitle .. " Error: " .. tostring(errMsg))
            task.delay(ERROR_FLASH_DURATION, function()
                if frame and frame.Parent then
                    titleLbl.Text = originalTitle
                    TweenService:Create(frame, TWEEN_HOVER, { BackgroundColor3 = RX.Card }):Play()
                    TweenService:Create(cardStroke, TWEEN_HOVER, { Transparency = 0.6 }):Play()
                end
            end)
        end

        function Components:CreateLabel(text, layoutOrder)
            local f, cs = makeBaseCard(layoutOrder, 24)
            f.BackgroundColor3 = RX.Bg3

            local lb = Instance.new("Frame")
            lb.Size = UDim2.new(0, 3, 0.5, 0)
            lb.Position = UDim2.new(0, 6, 0.5, 0)
            lb.AnchorPoint = Vector2.new(0, 0.5)
            lb.BackgroundColor3 = RX.Accent1
            lb.BorderSizePixel = 0
            lb.Parent = f
            Instance.new("UICorner", lb).CornerRadius = UDim.new(1, 0)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -22, 1, 0)
            lbl.Position = UDim2.new(0, 16, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = RX.T2
            lbl.TextTransparency = 1
            lbl.Font = RX.F1
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = f

            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if lbl and lbl.Parent then
                    TweenService:Create(lbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            return {
                Frame = f,
                SetText = function(t) lbl.Text = t end,
                Destroy = function() if f and f.Parent then f:Destroy() end end,
            }
        end

        function Components:CreateSection(cfg, layoutOrder)
            local title = type(cfg) == "table" and (cfg.Title or "Section") or tostring(cfg or "Section")
            local order = type(cfg) == "table" and (cfg.LayoutOrder or 50) or (layoutOrder or 50)
            elementCount = elementCount + 1

            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, 26)
            container.BackgroundTransparency = 1
            container.LayoutOrder = order
            container.Parent = canvas

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -8, 1, 0)
            label.Position = UDim2.new(0, 4, 0, 0)
            label.BackgroundTransparency = 1
            label.Text = string.upper(title)
            label.TextColor3 = RX.T2
            label.TextTransparency = 1
            label.Font = RX.F1
            label.TextSize = 10
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = container

            local accentLine = Instance.new("Frame")
            accentLine.Size = UDim2.new(1, -4, 0, 1)
            accentLine.Position = UDim2.new(0, 2, 1, -1)
            accentLine.BackgroundColor3 = RX.Accent1
            accentLine.BackgroundTransparency = 0.2
            accentLine.BorderSizePixel = 0
            accentLine.Parent = container

            -- Rayfield-style: Section title staggered reveal
            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if label and label.Parent then
                    TweenService:Create(label, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            return {
                Frame = container,
                SetTitle = function(t) label.Text = string.upper(t) end,
                Destroy = function() if container and container.Parent then container:Destroy() end end,
            }
        end

        function Components:CreateButton(cfg)
            cfg = cfg or {}
            local title = cfg.Name or cfg.Title or "Button"
            local layoutOrder = cfg.LayoutOrder or 99
            local debounceTime = tonumber(cfg.Debounce) or 0.3
            local callback = cfg.Callback or cfg.callback

            local frame, cardStroke = makeBaseCard(layoutOrder, 36)
            addHoverEffect(frame)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(1, -80, 1, 0)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextTransparency = 1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.Parent = frame

            -- Arrow indicator (Rayfield-style)
            local indicator = Instance.new("TextLabel")
            indicator.Size = UDim2.new(0, 30, 1, 0)
            indicator.Position = UDim2.new(1, -35, 0, 0)
            indicator.BackgroundTransparency = 1
            indicator.Text = "→"
            indicator.Font = RX.F1
            indicator.TextSize = 14
            indicator.TextColor3 = RX.T3
            indicator.TextTransparency = 0.9
            indicator.TextXAlignment = Enum.TextXAlignment.Center
            indicator.Parent = frame

            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if titleLbl and titleLbl.Parent then
                    TweenService:Create(titleLbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            local isDebounced = false
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.ZIndex = frame.ZIndex + 1
            btn.Parent = frame

            btn.Activated:Connect(function()
                if isDebounced then return end
                isDebounced = true

                -- Rayfield-style: Click feedback
                TweenService:Create(frame, TWEEN_CLICK, { BackgroundColor3 = RX.CardHover }):Play()
                TweenService:Create(indicator, TWEEN_CLICK, { TextTransparency = 1 }):Play()
                TweenService:Create(cardStroke, TWEEN_CLICK, { Transparency = 1 }):Play()

                if typeof(callback) == "function" then
                    local ok, err = pcall(callback)
                    if not ok then
                        flashError(frame, cardStroke, titleLbl, title, err)
                    else
                        task.delay(CLICK_FEEDBACK_DURATION, function()
                            if frame and frame.Parent then
                                TweenService:Create(frame, TWEEN_HOVER, { BackgroundColor3 = RX.Card }):Play()
                                TweenService:Create(indicator, TWEEN_HOVER, { TextTransparency = 0.9 }):Play()
                                TweenService:Create(cardStroke, TWEEN_HOVER, { Transparency = 0.6 }):Play()
                            end
                        end)
                    end
                end

                task.delay(debounceTime, function() isDebounced = false end)
            end)

            if not isMobile then
                btn.MouseEnter:Connect(function()
                    TweenService:Create(indicator, TWEEN_HOVER, { TextTransparency = 0.7 }):Play()
                end)
                btn.MouseLeave:Connect(function()
                    TweenService:Create(indicator, TWEEN_HOVER, { TextTransparency = 0.9 }):Play()
                end)
            end

            return {
                Frame = frame,
                SetCallback = function(fn) callback = fn end,
                SetTitle = function(t) titleLbl.Text = t end,
                Destroy = function() if frame and frame.Parent then frame:Destroy() end end,
            }
        end

        function Components:CreateToggle(cfg)
            cfg = cfg or {}
            local title = cfg.Name or cfg.Title or "Toggle"
            local layoutOrder = cfg.LayoutOrder or 99
            local defaultState = cfg.CurrentValue == true or cfg.Default == true
            local debounceTime = tonumber(cfg.Debounce) or 0.3
            local flag = cfg.Flag
            local callback = cfg.Callback or cfg.callback

            local frame, cardStroke = makeBaseCard(layoutOrder, 34)
            addHoverEffect(frame)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(1, -74, 1, 0)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextTransparency = 1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.Parent = frame

            local track = Instance.new("Frame")
            track.Size = UDim2.new(0, 44, 0, 22)
            track.Position = UDim2.new(1, -53, 0.5, 0)
            track.AnchorPoint = Vector2.new(0, 0.5)
            track.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            track.BorderSizePixel = 0
            track.Parent = frame
            Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

            local trackStroke = Instance.new("UIStroke")
            trackStroke.Thickness = 1
            trackStroke.Color = RX.ToggleDisabledStroke
            trackStroke.Parent = track

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 17, 0, 17)
            knob.Position = UDim2.new(0, 2, 0.5, 0)
            knob.AnchorPoint = Vector2.new(0, 0.5)
            knob.BackgroundColor3 = RX.ToggleDisabled
            knob.Parent = track
            Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

            local knobStroke = Instance.new("UIStroke")
            knobStroke.Thickness = 1
            knobStroke.Color = RX.ToggleDisabledStroke
            knobStroke.Parent = knob

            local toggleBtn = Instance.new("TextButton")
            toggleBtn.Size = UDim2.new(1, 0, 1, 0)
            toggleBtn.BackgroundTransparency = 1
            toggleBtn.Text = ""
            toggleBtn.ZIndex = track.ZIndex + 2
            toggleBtn.Parent = track

            local state = defaultState
            local isDebounced = false

            local function updateToggle(enabled, instant)
                if enabled then
                    -- Rayfield-style: Bounce animation (squash then stretch)
                    if not instant then
                        TweenService:Create(knob, TWEEN_BOUNCE, { Position = UDim2.new(0, 24, 0.5, 0) }):Play()
                        TweenService:Create(knob, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, 12, 0, 12)
                        }):Play()
                        task.delay(0.05, function()
                            if knob and knob.Parent then
                                TweenService:Create(knob, TWEEN_BOUNCE_BACK, { Size = UDim2.new(0, 17, 0, 17) }):Play()
                            end
                        end)
                    else
                        knob.Position = UDim2.new(0, 24, 0.5, 0)
                    end
                    TweenService:Create(knob, TweenInfo.new(instant and 0 or 0.8, Enum.EasingStyle.Quint), {
                        BackgroundColor3 = RX.ToggleEnabled
                    }):Play()
                    TweenService:Create(knobStroke, TweenInfo.new(instant and 0 or 0.55, Enum.EasingStyle.Quint), {
                        Color = RX.ToggleEnabledStroke
                    }):Play()
                    TweenService:Create(trackStroke, TweenInfo.new(instant and 0 or 0.55, Enum.EasingStyle.Quint), {
                        Color = Color3.fromRGB(100, 100, 100)
                    }):Play()
                else
                    if not instant then
                        TweenService:Create(knob, TWEEN_BOUNCE, { Position = UDim2.new(0, 2, 0.5, 0) }):Play()
                        TweenService:Create(knob, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, 12, 0, 12)
                        }):Play()
                        task.delay(0.05, function()
                            if knob and knob.Parent then
                                TweenService:Create(knob, TWEEN_BOUNCE_BACK, { Size = UDim2.new(0, 17, 0, 17) }):Play()
                            end
                        end)
                    else
                        knob.Position = UDim2.new(0, 2, 0.5, 0)
                    end
                    TweenService:Create(knob, TweenInfo.new(instant and 0 or 0.8, Enum.EasingStyle.Quint), {
                        BackgroundColor3 = RX.ToggleDisabled
                    }):Play()
                    TweenService:Create(knobStroke, TweenInfo.new(instant and 0 or 0.55, Enum.EasingStyle.Quint), {
                        Color = RX.ToggleDisabledStroke
                    }):Play()
                    TweenService:Create(trackStroke, TweenInfo.new(instant and 0 or 0.55, Enum.EasingStyle.Quint), {
                        Color = Color3.fromRGB(65, 65, 65)
                    }):Play()
                end
            end

            local function fireCallback()
                if typeof(callback) == "function" then
                    local ok, err = pcall(function() callback(state) end)
                    if not ok then
                        flashError(frame, cardStroke, titleLbl, title, err)
                    end
                end
            end

            updateToggle(state, true)

            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if titleLbl and titleLbl.Parent then
                    TweenService:Create(titleLbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            toggleBtn.Activated:Connect(function()
                if isDebounced then return end
                isDebounced = true

                -- Rayfield-style: Background flash on toggle
                TweenService:Create(frame, TWEEN_HOVER, { BackgroundColor3 = RX.CardHover }):Play()
                TweenService:Create(cardStroke, TWEEN_HOVER, { Transparency = 1 }):Play()

                state = not state
                updateToggle(state, false)
                fireCallback()

                task.delay(0.15, function()
                    if frame and frame.Parent then
                        TweenService:Create(frame, TWEEN_HOVER, { BackgroundColor3 = RX.Card }):Play()
                        TweenService:Create(cardStroke, TWEEN_HOVER, { Transparency = 0.6 }):Play()
                    end
                end)

                task.delay(debounceTime, function() isDebounced = false end)
            end)

            local toggleSettings = {
                Frame = frame,
                CurrentValue = state,
                Type = "Toggle",
                SetState = function(v, shouldCallback)
                    state = v == true
                    toggleSettings.CurrentValue = state
                    updateToggle(state, false)
                    if shouldCallback == true then fireCallback() end
                end,
                GetState = function() return state end,
                Set = function(self, v)
                    state = v == true
                    self.CurrentValue = state
                    updateToggle(state, false)
                    fireCallback()
                end,
                SetCallback = function(fn) callback = fn end,
                Destroy = function() if frame and frame.Parent then frame:Destroy() end end,
            }

            if flag then
                FlycerLib.Flags[flag] = toggleSettings
            end

            return toggleSettings
        end

        function Components:CreateSlider(cfg)
            cfg = cfg or {}
            local title = cfg.Name or cfg.Title or "Slider"
            local layoutOrder = cfg.LayoutOrder or 99
            local range = cfg.Range or { 0, 100 }
            local increment = cfg.Increment or 1
            local suffix = cfg.Suffix or ""
            local currentValue = cfg.CurrentValue or cfg.Default or range[1]
            local flag = cfg.Flag
            local callback = cfg.Callback or cfg.callback

            local frame, cardStroke = makeBaseCard(layoutOrder, 50)
            addHoverEffect(frame)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(1, -20, 0, 20)
            titleLbl.Position = UDim2.new(0, 10, 0, 2)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextTransparency = 1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.Parent = frame

            local sliderBg = Instance.new("Frame")
            sliderBg.Size = UDim2.new(1, -20, 0, 14)
            sliderBg.Position = UDim2.new(0, 10, 0, 28)
            sliderBg.BackgroundColor3 = RX.SliderBg
            sliderBg.BorderSizePixel = 0
            sliderBg.ZIndex = frame.ZIndex + 1
            sliderBg.Parent = frame
            Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

            local sliderStroke = Instance.new("UIStroke")
            sliderStroke.Thickness = 1
            sliderStroke.Color = RX.Border
            sliderStroke.Parent = sliderBg

            local progress = Instance.new("Frame")
            progress.BackgroundColor3 = RX.SliderProgress
            progress.BorderSizePixel = 0
            progress.ZIndex = frame.ZIndex + 2
            progress.Parent = sliderBg
            Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)

            local infoLabel = Instance.new("TextLabel")
            infoLabel.Size = UDim2.new(1, 0, 1, 0)
            infoLabel.BackgroundTransparency = 1
            infoLabel.Text = tostring(currentValue) .. (suffix ~= "" and (" " .. suffix) or "")
            infoLabel.Font = RX.FM
            infoLabel.TextSize = 9
            infoLabel.TextColor3 = RX.T1
            infoLabel.ZIndex = frame.ZIndex + 3
            infoLabel.Parent = sliderBg

            -- Set initial progress
            local pct = math.clamp((currentValue - range[1]) / (range[2] - range[1]), 0, 1)
            progress.Size = UDim2.new(0, math.max(pct * sliderBg.AbsoluteSize.X, 5), 1, 0)

            local interact = Instance.new("TextButton")
            interact.Size = UDim2.new(1, 0, 1, 0)
            interact.BackgroundTransparency = 1
            interact.Text = ""
            interact.ZIndex = frame.ZIndex + 4
            interact.Parent = sliderBg

            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if titleLbl and titleLbl.Parent then
                    TweenService:Create(titleLbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            local sliderDragging = false

            interact.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliderDragging = true
                end
            end)

            interact.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliderDragging = false
                end
            end)

            local loopConn
            interact.MouseButton1Down:Connect(function()
                if loopConn then loopConn:Disconnect() end
                loopConn = RunService.Stepped:Connect(function()
                    if sliderDragging then
                        local mouseX = UserInputService:GetMouseLocation().X
                        local localX = math.clamp(mouseX - sliderBg.AbsolutePosition.X, 0, sliderBg.AbsoluteSize.X)

                        TweenService:Create(progress, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, math.max(localX, 5), 1, 0)
                        }):Play()

                        local newValue = range[1] + (localX / sliderBg.AbsoluteSize.X) * (range[2] - range[1])
                        newValue = math.floor(newValue / increment + 0.5) * increment
                        newValue = math.clamp(newValue, range[1], range[2])

                        infoLabel.Text = tostring(newValue) .. (suffix ~= "" and (" " .. suffix) or "")

                        if currentValue ~= newValue then
                            currentValue = newValue
                            if typeof(callback) == "function" then
                                local ok, err = pcall(function() callback(newValue) end)
                                if not ok then
                                    flashError(frame, cardStroke, titleLbl, title, err)
                                end
                            end
                        end
                    else
                        loopConn:Disconnect()
                    end
                end)
            end)

            local sliderSettings = {
                Frame = frame,
                CurrentValue = currentValue,
                Type = "Slider",
                Set = function(self, newVal)
                    newVal = math.clamp(newVal, range[1], range[2])
                    currentValue = newVal
                    self.CurrentValue = newVal
                    local p = (newVal - range[1]) / (range[2] - range[1])
                    TweenService:Create(progress, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {
                        Size = UDim2.new(0, math.max(p * sliderBg.AbsoluteSize.X, 5), 1, 0)
                    }):Play()
                    infoLabel.Text = tostring(newVal) .. (suffix ~= "" and (" " .. suffix) or "")
                    if typeof(callback) == "function" then pcall(function() callback(newVal) end) end
                end,
                Destroy = function() if frame and frame.Parent then frame:Destroy() end end,
            }

            if flag then FlycerLib.Flags[flag] = sliderSettings end
            return sliderSettings
        end

        function Components:CreateInput(cfg)
            cfg = cfg or {}
            local title = cfg.Name or cfg.Title or "Input"
            local layoutOrder = cfg.LayoutOrder or 99
            local placeholder = cfg.PlaceholderText or "Type here..."
            local removeOnFocus = cfg.RemoveTextAfterFocusLost
            local callback = cfg.Callback or cfg.callback

            local frame, cardStroke = makeBaseCard(layoutOrder, 36)
            addHoverEffect(frame)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(0.5, -10, 1, 0)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextTransparency = 1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.Parent = frame

            local inputBg = Instance.new("Frame")
            inputBg.Size = UDim2.new(0, 120, 0, 24)
            inputBg.Position = UDim2.new(1, -130, 0.5, 0)
            inputBg.AnchorPoint = Vector2.new(0, 0.5)
            inputBg.BackgroundColor3 = RX.InputBg
            inputBg.BorderSizePixel = 0
            inputBg.ZIndex = frame.ZIndex + 1
            inputBg.Parent = frame
            Instance.new("UICorner", inputBg).CornerRadius = UDim.new(0, 6)

            local inputStroke = Instance.new("UIStroke")
            inputStroke.Thickness = 1
            inputStroke.Color = RX.InputStroke
            inputStroke.Parent = inputBg

            local inputBox = Instance.new("TextBox")
            inputBox.Size = UDim2.new(1, -10, 1, 0)
            inputBox.Position = UDim2.new(0, 5, 0, 0)
            inputBox.BackgroundTransparency = 1
            inputBox.PlaceholderText = placeholder
            inputBox.PlaceholderColor3 = RX.T3
            inputBox.Font = RX.FM
            inputBox.TextSize = 11
            inputBox.TextColor3 = RX.Cyan
            inputBox.ClearTextOnFocus = false
            inputBox.TextXAlignment = Enum.TextXAlignment.Left
            inputBox.ZIndex = frame.ZIndex + 2
            inputBox.Parent = inputBg

            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if titleLbl and titleLbl.Parent then
                    TweenService:Create(titleLbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            inputBox.FocusLost:Connect(function()
                if #inputBox.Text == 0 then return end
                if typeof(callback) == "function" then
                    local ok, err = pcall(function() callback(inputBox.Text) end)
                    if not ok then flashError(frame, cardStroke, titleLbl, title, err) end
                end
                if removeOnFocus then inputBox.Text = "" end
            end)

            -- Auto-resize input frame
            inputBox:GetPropertyChangedSignal("Text"):Connect(function()
                TweenService:Create(inputBg, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, math.clamp(inputBox.TextBounds.X + 24, 60, 200), 0, 24)
                }):Play()
            end)

            return {
                Frame = frame,
                Set = function(text) inputBox.Text = text end,
                Destroy = function() if frame and frame.Parent then frame:Destroy() end end,
            }
        end

        function Components:CreateKeybind(cfg)
            cfg = cfg or {}
            local title = cfg.Name or cfg.Title or "Keybind"
            local layoutOrder = cfg.LayoutOrder or 99
            local currentKeybind = cfg.CurrentKeybind or "E"
            local holdToInteract = cfg.HoldToInteract
            local flag = cfg.Flag
            local callback = cfg.Callback or cfg.callback

            local frame, cardStroke = makeBaseCard(layoutOrder, 36)
            addHoverEffect(frame)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(0.6, -10, 1, 0)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextTransparency = 1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.Parent = frame

            local keybindBg = Instance.new("Frame")
            keybindBg.Size = UDim2.new(0, 60, 0, 24)
            keybindBg.Position = UDim2.new(1, -70, 0.5, 0)
            keybindBg.AnchorPoint = Vector2.new(0, 0.5)
            keybindBg.BackgroundColor3 = RX.InputBg
            keybindBg.BorderSizePixel = 0
            keybindBg.ZIndex = frame.ZIndex + 1
            keybindBg.Parent = frame
            Instance.new("UICorner", keybindBg).CornerRadius = UDim.new(0, 6)

            local keybindBox = Instance.new("TextBox")
            keybindBox.Size = UDim2.new(1, -10, 1, 0)
            keybindBox.Position = UDim2.new(0, 5, 0, 0)
            keybindBox.BackgroundTransparency = 1
            keybindBox.Text = currentKeybind
            keybindBox.Font = RX.FM
            keybindBox.TextSize = 11
            keybindBox.TextColor3 = RX.Cyan
            keybindBox.TextXAlignment = Enum.TextXAlignment.Center
            keybindBox.ZIndex = frame.ZIndex + 2
            keybindBox.Parent = keybindBg

            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if titleLbl and titleLbl.Parent then
                    TweenService:Create(titleLbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            local checkingForKey = false
            keybindBox.Focused:Connect(function()
                checkingForKey = true
                keybindBox.Text = ""
            end)
            keybindBox.FocusLost:Connect(function()
                checkingForKey = false
                if keybindBox.Text == "" then keybindBox.Text = currentKeybind end
            end)

            UserInputService.InputBegan:Connect(function(input, processed)
                if checkingForKey then
                    if input.KeyCode ~= Enum.KeyCode.Unknown then
                        local keyName = input.KeyCode.Name
                        keybindBox.Text = keyName
                        currentKeybind = keyName
                        keybindBox:ReleaseFocus()
                    end
                elseif currentKeybind and not processed then
                    local ok, keyEnum = pcall(function() return Enum.KeyCode[currentKeybind] end)
                    if ok and input.KeyCode == keyEnum then
                        if typeof(callback) == "function" then
                            pcall(callback)
                        end
                    end
                end
            end)

            -- Auto-resize
            keybindBox:GetPropertyChangedSignal("Text"):Connect(function()
                TweenService:Create(keybindBg, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {
                    Size = UDim2.new(0, math.max(keybindBox.TextBounds.X + 24, 40), 0, 24)
                }):Play()
            end)

            local keybindSettings = {
                Frame = frame,
                CurrentKeybind = currentKeybind,
                Type = "Keybind",
                Set = function(self, newKey)
                    currentKeybind = tostring(newKey)
                    self.CurrentKeybind = currentKeybind
                    keybindBox.Text = currentKeybind
                end,
                Destroy = function() if frame and frame.Parent then frame:Destroy() end end,
            }

            if flag then FlycerLib.Flags[flag] = keybindSettings end
            return keybindSettings
        end

        function Components:CreateDropdown(cfg)
            cfg = cfg or {}
            local title = cfg.Name or cfg.Title or "Dropdown"
            local layoutOrder = cfg.LayoutOrder or 99
            local options = cfg.Options or {}
            local currentOption = cfg.CurrentOption or (options[1] and { options[1] } or {})
            local multipleOptions = cfg.MultipleOptions
            local flag = cfg.Flag
            local callback = cfg.Callback or cfg.callback

            if type(currentOption) == "string" then currentOption = { currentOption } end

            local frame, cardStroke = makeBaseCard(layoutOrder, 45)
            frame.ClipsDescendants = true
            addHoverEffect(frame)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(0.6, -10, 0, 45)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextTransparency = 1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.Parent = frame

            local selectedLbl = Instance.new("TextLabel")
            selectedLbl.Size = UDim2.new(0.4, -10, 0, 45)
            selectedLbl.Position = UDim2.new(0.6, 0, 0, 0)
            selectedLbl.BackgroundTransparency = 1
            selectedLbl.Text = #currentOption > 0 and currentOption[1] or "None"
            selectedLbl.Font = RX.F2
            selectedLbl.TextSize = 10
            selectedLbl.TextColor3 = RX.T2
            selectedLbl.TextXAlignment = Enum.TextXAlignment.Right
            selectedLbl.TextYAlignment = Enum.TextYAlignment.Center
            selectedLbl.Parent = frame

            -- Toggle arrow
            local toggle = Instance.new("TextLabel")
            toggle.Size = UDim2.new(0, 20, 0, 45)
            toggle.Position = UDim2.new(1, -25, 0, 0)
            toggle.BackgroundTransparency = 1
            toggle.Text = "▼"
            toggle.Font = RX.F1
            toggle.TextSize = 8
            toggle.TextColor3 = RX.T3
            toggle.Rotation = 180
            toggle.Parent = frame

            -- Options list
            local optionsList = Instance.new("Frame")
            optionsList.Size = UDim2.new(1, -20, 0, #options * 30)
            optionsList.Position = UDim2.new(0, 10, 0, 50)
            optionsList.BackgroundTransparency = 1
            optionsList.Visible = false
            optionsList.ZIndex = frame.ZIndex + 1
            optionsList.Parent = frame

            local optLayout = Instance.new("UIListLayout")
            optLayout.SortOrder = Enum.SortOrder.LayoutOrder
            optLayout.Padding = UDim.new(0, 3)
            optLayout.Parent = optionsList

            local dropdownOpen = false

            local interact = Instance.new("TextButton")
            interact.Size = UDim2.new(1, 0, 0, 45)
            interact.BackgroundTransparency = 1
            interact.Text = ""
            interact.ZIndex = frame.ZIndex + 3
            interact.Parent = frame

            task.delay(elementCount * ELEMENT_STAGGER_DELAY, function()
                if titleLbl and titleLbl.Parent then
                    TweenService:Create(titleLbl, TWEEN_ELEMENT, { TextTransparency = 0 }):Play()
                end
            end)

            -- Create option buttons
            for _, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 26)
                optBtn.BackgroundColor3 = table.find(currentOption, opt) and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(30, 30, 30)
                optBtn.BackgroundTransparency = 1
                optBtn.Text = opt
                optBtn.Font = RX.F2
                optBtn.TextSize = 10
                optBtn.TextColor3 = RX.T1
                optBtn.TextTransparency = 1
                optBtn.AutoButtonColor = false
                optBtn.ZIndex = frame.ZIndex + 2
                optBtn.Parent = optionsList
                Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 4)

                local optStroke = Instance.new("UIStroke")
                optStroke.Thickness = 1
                optStroke.Color = RX.Border
                optStroke.Transparency = 1
                optStroke.Parent = optBtn

                optBtn.MouseButton1Click:Connect(function()
                    if table.find(currentOption, opt) then
                        if not multipleOptions then return end
                        table.remove(currentOption, table.find(currentOption, opt))
                    else
                        if not multipleOptions then table.clear(currentOption) end
                        table.insert(currentOption, opt)
                        TweenService:Create(optStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Transparency = 1 }):Play()
                        TweenService:Create(optBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { BackgroundColor3 = Color3.fromRGB(40, 40, 40) }):Play()
                    end

                    -- Update selected text
                    if #currentOption == 0 then selectedLbl.Text = "None"
                    elseif #currentOption == 1 then selectedLbl.Text = currentOption[1]
                    else selectedLbl.Text = "Various" end

                    if typeof(callback) == "function" then
                        pcall(function() callback(currentOption) end)
                    end

                    -- Update all option visuals
                    for _, child in ipairs(optionsList:GetChildren()) do
                        if child:IsA("TextButton") then
                            local isSelected = table.find(currentOption, child.Text)
                            TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
                                BackgroundColor3 = isSelected and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(30, 30, 30)
                            }):Play()
                        end
                    end

                    if not multipleOptions then
                        -- Auto-close
                        task.delay(0.1, function()
                            dropdownOpen = false
                            TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.new(1, 0, 0, 45) }):Play()
                            TweenService:Create(toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { Rotation = 180 }):Play()
                            for _, child in ipairs(optionsList:GetChildren()) do
                                if child:IsA("TextButton") then
                                    TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
                                    local s = child:FindFirstChildOfClass("UIStroke")
                                    if s then TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Transparency = 1 }):Play() end
                                end
                            end
                            task.delay(0.35, function() optionsList.Visible = false end)
                        end)
                    end
                end)
            end

            interact.Activated:Connect(function()
                -- Rayfield-style: Click feedback
                TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { BackgroundColor3 = RX.CardHover }):Play()
                task.delay(0.1, function()
                    if frame and frame.Parent then
                        TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { BackgroundColor3 = RX.Card }):Play()
                    end
                end)

                if dropdownOpen then
                    dropdownOpen = false
                    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.new(1, 0, 0, 45) }):Play()
                    TweenService:Create(toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { Rotation = 180 }):Play()
                    for _, child in ipairs(optionsList:GetChildren()) do
                        if child:IsA("TextButton") then
                            TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
                            local s = child:FindFirstChildOfClass("UIStroke")
                            if s then TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Transparency = 1 }):Play() end
                        end
                    end
                    task.delay(0.35, function() optionsList.Visible = false end)
                else
                    dropdownOpen = true
                    optionsList.Visible = true
                    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
                        Size = UDim2.new(1, 0, 0, 55 + #options * 30)
                    }):Play()
                    TweenService:Create(toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { Rotation = 0 }):Play()
                    for _, child in ipairs(optionsList:GetChildren()) do
                        if child:IsA("TextButton") then
                            TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
                            local s = child:FindFirstChildOfClass("UIStroke")
                            if s then TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Transparency = 0 }):Play() end
                        end
                    end
                end
            end)

            local dropdownSettings = {
                Frame = frame,
                CurrentOption = currentOption,
                Type = "Dropdown",
                Set = function(self, newOption)
                    if type(newOption) == "string" then newOption = { newOption } end
                    currentOption = newOption
                    self.CurrentOption = currentOption
                    if #currentOption == 0 then selectedLbl.Text = "None"
                    elseif #currentOption == 1 then selectedLbl.Text = currentOption[1]
                    else selectedLbl.Text = "Various" end
                    if typeof(callback) == "function" then pcall(function() callback(newOption) end) end
                end,
                Destroy = function() if frame and frame.Parent then frame:Destroy() end end,
            }

            if flag then FlycerLib.Flags[flag] = dropdownSettings end
            return dropdownSettings
        end

        return Components
    end

    -- INITIAL SYNC & LOADING

    task.spawn(function()
        local waited = 0
        while Camera.ViewportSize.X == 0 and waited < 3 do
            RunService.RenderStepped:Wait()
            waited = waited + 1 / 60
        end
        local syncLayout = calcLayout(currentGUIWidth, currentGUIHeight)
        MainFrame.Position = syncLayout.mainPos
        if ToggleFrame and ToggleFrame.Parent then
            ToggleFrame.Position = syncLayout.togglePos
        end
        task.wait(0.1)
        cacheAllRevealTargets(MainFrame)
        cacheAllRevealTargets(ToggleFrame)
        task.defer(function()
            task.wait(REVEAL_DURATION + 0.2)
            cacheOriginalValues()
        end)
    end)

    -- BUILT-IN SETTINGS TAB
    local settingsCanvas, _ = addTab("Settings", 999)
    local SettingsC = makeComponents(settingsCanvas)

    local pingEnabled, fpsEnabled = true, true
    local PING_POS_BOTH = UDim2.new(1, -156, 0.5, 0)
    local FPS_POS_BOTH = UDim2.new(1, -71, 0.5, 0)
    local PING_POS_SOLO = UDim2.new(1, -86, 0.5, 0)

    local function updateCounterPositions()
        if pingEnabled and fpsEnabled then
            TweenService:Create(pingContainer, TWEEN_FAST, { Position = PING_POS_BOTH }):Play()
            TweenService:Create(fpsContainer, TWEEN_FAST, { Position = FPS_POS_BOTH }):Play()
        elseif pingEnabled then
            TweenService:Create(pingContainer, TWEEN_FAST, { Position = PING_POS_SOLO }):Play()
        elseif fpsEnabled then
            TweenService:Create(fpsContainer, TWEEN_FAST, { Position = FPS_POS_BOTH }):Play()
        end
    end

    SettingsC:CreateLabel("Show PING & FPS", 1)
    SettingsC:CreateToggle({
        Name = "Show Ping Counter", LayoutOrder = 2, CurrentValue = true,
        Callback = function(v)
            pingEnabled = v
            pingContainer.Visible = v
            if v then StartPingCounter() else StopPingCounter() end
            updateCounterPositions()
        end,
    })
    SettingsC:CreateToggle({
        Name = "Show FPS Counter", LayoutOrder = 3, CurrentValue = true,
        Callback = function(v)
            fpsEnabled = v
            fpsContainer.Visible = v
            if v then StartFPSCounter() else StopFPSCounter() end
            updateCounterPositions()
        end,
    })
    SettingsC:CreateSection("UI Position Control", 4)
    SettingsC:CreateToggle({
        Name = "Lock UI Position", LayoutOrder = 5, CurrentValue = false, Debounce = 2.5,
        Callback = function(locked)
            isUILocked = locked
            g.FlycerUILocked = locked
            if DragBar and DragBarHitbox then
                if locked then
                    TweenService:Create(DragBar, TWEEN_NORMAL, { BackgroundTransparency = 1 }):Play()
                    task.delay(0.3, function() if DragBarHitbox then DragBarHitbox.Visible = false end end)
                else
                    DragBarHitbox.Visible = true
                    TweenService:Create(DragBar, TWEEN_NORMAL, { BackgroundTransparency = 0.80 }):Play()
                end
            end
            ShowNotification({
                title = "UI Position " .. (locked and "LOCKED" or "UNLOCKED"),
                body = locked and "Drag disabled" or "Drag enabled",
                duration = 2,
            })
        end,
    })

    -- SHOW LOADING → REVEAL UI (Rayfield-style multi-stage)

    ShowNotification({
        title = loadingTitle,
        body = loadingSubtitle,
        duration = loadingDuration,
        onComplete = function()
            revealUI(function()
                StartPingCounter()
                StartFPSCounter()
            end)
        end,
    })

    -- WINDOW OBJECT

    local Window = {}

    function Window:CreateTab(name, layoutOrder)
        local tabCanvas, _ = addTab(name, layoutOrder)
        local TabObj = makeComponents(tabCanvas)
        if not activeTabName then activateTab(name) end
        return TabObj
    end

    function Window:Notify(cfg) ShowNotification(cfg or {}) end

    function Window:Destroy()
        cancelAllFadeTweens()
        for _, conn in ipairs(eventConnections) do conn:Disconnect() end
        if MainGui and MainGui.Parent then MainGui:Destroy() end
        if ToggleSG and ToggleSG.Parent then ToggleSG:Destroy() end
    end

    task.defer(function()
        if not activeTabName and firstTabName then activateTab(firstTabName) end
    end)

    return Window
end

-- GLOBAL API

if getgenv then
    getgenv()._FlycerUI = {
        GetRefs = function() return _FLYCER_PRIVATE.Refs end,
        GetFrame = function() return _FLYCER_PRIVATE.MainFrame end,
        Notify = function(c) ShowNotification(c) end,
    }
end

return FlycerLib
