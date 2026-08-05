--[[
    FlycerUI Library
    Version: 1.0.0
    
    Usage:
        local Flycer = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL"))()
        local Window = Flycer:CreateWindow({ ... })
        local Tab = Window:CreateTab("TabName", layoutOrder)
        Tab:CreateToggle({ ... })
        Tab:CreateButton({ ... })
        Tab:CreateLabel("text")
        Tab:CreateSection("title")
]]

-- SERVICES

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

    if envHas("gethui") then
        EXECUTOR_APIS.gethui = true
    end
    if envHas("get_hidden_ui") then
        EXECUTOR_APIS.get_hidden_ui = true
    end

    pcall(function()
        if syn and type(syn.protect_gui) == "function" then
            EXECUTOR_APIS.syn_protect_gui = true
        end
    end)

    if envHas("protect_gui") then
        EXECUTOR_APIS.protect_gui = true
    end
    if envHas("protectgui") then
        EXECUTOR_APIS.protectgui = true
    end
    if envHas("setclipboard") then
        EXECUTOR_APIS.setclipboard = true
    end
    if envHas("toclipboard") then
        EXECUTOR_APIS.toclipboard = true
    end
end

-- PLATFORM DETECTION

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local isConsole = UserInputService.GamepadEnabled
    and not UserInputService.TouchEnabled
    and not UserInputService.MouseEnabled

if not isMobile and not isPC and not isConsole then
    isPC = true
end

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
local EXTRA_FRAME_GAP = 6
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

-- THEME & TWEEN

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
    F1 = Enum.Font.GothamBold,
    F2 = Enum.Font.GothamMedium,
    FM = Enum.Font.Code,
}

local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quint)
local TWEEN_NORMAL = TweenInfo.new(0.25, Enum.EasingStyle.Quint)

-- AUTO-CENTER & VIEWPORT HELPERS

local Camera = workspace.CurrentCamera

local function getViewportSafe()
    if not Camera then
        Camera = workspace.CurrentCamera
    end
    local vp = Camera.ViewportSize
    if vp.X < 10 or vp.Y < 10 then
        return Vector2.new(1280, 720)
    end
    return vp
end

local function getScreenCenter(w, h)
    local vp = getViewportSafe()
    return UDim2.new(0, math.round((vp.X - w) / 2), 0, math.round((vp.Y - h) / 2))
end

local function getCenteredTogglePos(guiHeight)
    local vp = getViewportSafe()
    local toggleHeight = 34
    local guiY = math.round((vp.Y - guiHeight) / 2)
    local y = guiY + math.round((guiHeight - toggleHeight) / 2)
    return UDim2.new(0, 18, 0, y)
end

-- LAYOUT CALCULATOR

local function calcLayout(w, h)
    local SHADOW_OFFSET_Y = -1
    local TAB_SHADOW_OFFSET_Y = 3

    local contentH = math.max(h - CONTENT_TOP - EXTRA_BAR_H - EXTRA_BAR_MARGIN - 14, MIN_CONTENT_H)

    return {
        mainSize = UDim2.new(0, w, 0, h),
        mainPos = getScreenCenter(w, h),
        contentSize = UDim2.new(1, 0, 0, contentH),
        shadowSize = UDim2.new(1, -10, 0, contentH),
        shadowPos = UDim2.new(0, 5, 0, CONTENT_TOP + SHADOW_OFFSET_Y),
        tabShadowSize = UDim2.new(1, -10, 0, TAB_HEIGHT),
        tabShadowPos = UDim2.new(0, 5, 0, TAB_RAIL_Y + TAB_SHADOW_OFFSET_Y),
        tabRailClipPos = UDim2.new(0, TAB_RAIL_MARGIN, 0, TAB_RAIL_Y + TAB_SHADOW_OFFSET_Y),
        togglePos = getCenteredTogglePos(h),
        extraFramePos = UDim2.new(0, 6, 0, h - EXTRA_BAR_H - 13),
        extraFrameSize = UDim2.new(1, -12, 0, 30),
    }
end

-- CHARSET & RANDOM NAME

local CHARSET = {}
for i = 33, 126 do
    CHARSET[#CHARSET + 1] = string.char(i)
end
local CHARSET_LEN = #CHARSET

do
    local seed = os.clock() * 1e9 + tick() * 1e6
    math.randomseed(seed)
    for _ = 1, 3 do
        math.random()
    end
end

local function randomName(len)
    len = len or math.random(15, 25)
    local buf = table.create(len)
    for i = 1, len do
        buf[i] = CHARSET[math.random(1, CHARSET_LEN)]
    end
    return table.concat(buf)
end

-- SEALED PRIVATE NAMESPACE

local _FLYCER_PRIVATE = {
    Refs = nil,
    MainFrame = nil,
    Session = nil,
    ShowNotif = nil,
    StartPing = nil,
    StopPing = nil,
    StartFPS = nil,
    StopFPS = nil,
}

local g = (getgenv and getgenv()) or _G
local _cachedParent = nil

-- GUI PARENT / SECURITY HELPERS

local function getParent()
    if _cachedParent and _cachedParent.Parent then
        return _cachedParent
    end
    if EXECUTOR_APIS.gethui then
        local ok, r = pcall(gethui)
        if ok and r then
            _cachedParent = r
            return r
        end
    end
    if EXECUTOR_APIS.get_hidden_ui then
        local ok, r = pcall(get_hidden_ui)
        if ok and r then
            _cachedParent = r
            return r
        end
    end
    _cachedParent = CoreGui
    return CoreGui
end

local function SecureGui(gui)
    gui.Name = "F4_" .. randomName(12)
    gui:SetAttribute(FLYCER_TAG_ATTR, true)
    if EXECUTOR_APIS.syn_protect_gui then
        pcall(function()
            syn.protect_gui(gui)
        end)
    end
    if EXECUTOR_APIS.protect_gui then
        pcall(function()
            protect_gui(gui)
        end)
    end
    if EXECUTOR_APIS.protectgui then
        pcall(function()
            protectgui(gui)
        end)
    end
    gui.Parent = getParent()
end

local function getAllContainers()
    local list = { CoreGui }
    if PlayerGui then
        table.insert(list, PlayerGui)
    end
    if EXECUTOR_APIS.gethui then
        local ok, r = pcall(gethui)
        if ok and r and not table.find(list, r) then
            table.insert(list, r)
        end
    end
    if EXECUTOR_APIS.get_hidden_ui then
        local ok, r = pcall(get_hidden_ui)
        if ok and r and not table.find(list, r) then
            table.insert(list, r)
        end
    end
    return list
end

-- CLEANUP OLD INSTANCES

local function cleanupOldInstances()
    if g[FLAG_NAME] then
        local old = g[GUI_REF_NAME]
        if old and typeof(old) == "Instance" and old.Parent then
            old:Destroy()
        end
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
    if not gradObj then
        return
    end
    _strokeTargets[gradObj] = true
    if _strokeLoopRunning then
        return
    end
    _strokeLoopRunning = true
    local rot = 0
    _strokeConnection = RunService.Heartbeat:Connect(function(dt)
        rot = (rot + dt * 40) % 180
        local any = false
        for grad in pairs(_strokeTargets) do
            if grad and grad.Parent then
                grad.Rotation = rot
                any = true
            else
                _strokeTargets[grad] = nil
            end
        end
        if not any then
            _strokeLoopRunning = false
            _strokeConnection:Disconnect()
            _strokeConnection = nil
        end
    end)
end

local function unregisterStrokeTarget(gradObj)
    if gradObj then
        _strokeTargets[gradObj] = nil
    end
end

-- SEPARATOR UTILITY

local function makeSeparator(parentFrame, posY_offset, useScale, scaleY)
    local sep = Instance.new("Frame")
    sep.Name = "Separator"
    sep.Size = UDim2.new(1, -10, 0, 0)

    if useScale then
        sep.Position = UDim2.new(0, 5, scaleY or 1, posY_offset or 0)
    else
        sep.Position = UDim2.new(0, 5, 0, posY_offset or 0)
    end

    sep.BackgroundTransparency = 1
    sep.BorderSizePixel = 0
    sep.ZIndex = 10
    sep.Active = false
    sep.Selectable = false
    sep:SetAttribute("FlycerTag", true)

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0
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

-- DRAGGABLE SYSTEM

local function getDragLerpAlpha(smoothValue)
    smoothValue = math.clamp(smoothValue or DRAG_SMOOTHNESS, 1, 20)
    return 1.0 - ((smoothValue - 1) / 19) * 0.9
end

local function makeDraggable(dragHandle, dragTarget, smoothness)
    dragTarget = dragTarget or dragHandle

    local dragging = false
    local dragStart = nil
    local startPos = nil
    local activeTouch = nil
    local targetPosition = nil
    local lerpConnection = nil

    local lerpAlpha = getDragLerpAlpha(smoothness)
    local smoothVal = math.clamp(smoothness or DRAG_SMOOTHNESS, 1, 20)
    local useLerp = smoothVal > 3

    local function startLerpLoop()
        if lerpConnection then
            return
        end
        lerpConnection = RunService.Heartbeat:Connect(function()
            if not (dragging and targetPosition) then
                return
            end
            local cp = dragTarget.Position
            local newX = math.round(cp.X.Offset + (targetPosition.X - cp.X.Offset) * lerpAlpha)
            local newY = math.round(cp.Y.Offset + (targetPosition.Y - cp.Y.Offset) * lerpAlpha)

            if math.abs(targetPosition.X - newX) < 0.5 and math.abs(targetPosition.Y - newY) < 0.5 then
                dragTarget.Position =
                    UDim2.new(cp.X.Scale, math.round(targetPosition.X), cp.Y.Scale, math.round(targetPosition.Y))
            else
                dragTarget.Position = UDim2.new(cp.X.Scale, newX, cp.Y.Scale, newY)
            end
        end)
    end

    local function stopLerpLoop()
        if lerpConnection then
            lerpConnection:Disconnect()
            lerpConnection = nil
        end
    end

    local function update(input)
        if not (dragging and dragStart and startPos) then
            return
        end
        local delta = input.Position - dragStart
        local rawX = startPos.X.Offset + delta.X
        local rawY = startPos.Y.Offset + delta.Y
        if useLerp then
            targetPosition = Vector2.new(rawX, rawY)
        else
            dragTarget.Position = UDim2.new(startPos.X.Scale, math.round(rawX), startPos.Y.Scale, math.round(rawY))
        end
    end

    local inputChangedConn = nil

    dragHandle.InputBegan:Connect(function(input)
        local it = input.UserInputType
        if it ~= Enum.UserInputType.MouseButton1 and it ~= Enum.UserInputType.Touch then
            return
        end
        if isUILocked then
            return
        end
        if dragging then
            return
        end

        if inputChangedConn then
            inputChangedConn:Disconnect()
            inputChangedConn = nil
        end

        dragging = true
        dragStart = input.Position
        startPos = dragTarget.Position
        targetPosition = Vector2.new(startPos.X.Offset, startPos.Y.Offset)
        if it == Enum.UserInputType.Touch then
            activeTouch = input
        end
        if useLerp then
            startLerpLoop()
        end

        input.Changed:Connect(function()
            if input.UserInputState ~= Enum.UserInputState.End then
                return
            end
            dragging = false
            dragStart = nil
            startPos = nil
            if input == activeTouch then
                activeTouch = nil
            end
            if useLerp then
                task.delay(0.15, function()
                    if not dragging then
                        stopLerpLoop()
                        targetPosition = nil
                    end
                end)
            end
            if inputChangedConn then
                inputChangedConn:Disconnect()
                inputChangedConn = nil
            end
        end)

        inputChangedConn = UserInputService.InputChanged:Connect(function(inp)
            if not dragging then
                return
            end
            local t = inp.UserInputType
            if t == Enum.UserInputType.MouseMovement then
                update(inp)
            elseif t == Enum.UserInputType.Touch and inp == activeTouch then
                update(inp)
            end
        end)
    end)

    dragHandle.Destroying:Connect(function()
        stopLerpLoop()
        if inputChangedConn then
            inputChangedConn:Disconnect()
            inputChangedConn = nil
        end
    end)
end

-- NOTIFICATION SYSTEM

local _notifScreen = nil
local _notifQueue = {}
local _notifRunning = false
local _notifActive = false

local function getNotifSafeParent()
    if PlayerGui and PlayerGui.Parent then
        return PlayerGui
    end
    return CoreGui
end

local function getNotifScreen()
    if _notifScreen and _notifScreen.Parent then
        return _notifScreen
    end
    local sg = Instance.new("ScreenGui")
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 9999999999
    sg.IgnoreGuiInset = true
    sg:SetAttribute(FLYCER_TAG_ATTR, true)
    if EXECUTOR_APIS.syn_protect_gui then
        pcall(function()
            syn.protect_gui(sg)
        end)
    end
    if EXECUTOR_APIS.protect_gui then
        pcall(function()
            protect_gui(sg)
        end)
    end
    sg.Parent = getNotifSafeParent()
    _notifScreen = sg
    return sg
end

local function buildNotifFrame(parent, cfg)
    local title = cfg.title or "Flycer"
    local body = cfg.body or ""

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "NotifFrame"
    mainFrame.Size = UDim2.new(0, NOTIF_WIDTH, 0, NOTIF_HEIGHT)
    mainFrame.Position = UDim2.new(1, NOTIF_WIDTH + 20, 1, -(NOTIF_HEIGHT + NOTIF_POS_Y))
    mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = false
    mainFrame.ZIndex = 2
    mainFrame.Parent = parent

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, NOTIF_CORNER_RADIUS)
    mainCorner.Parent = mainFrame

    local outerStroke = Instance.new("UIStroke")
    outerStroke.Color = Color3.fromRGB(38, 38, 50)
    outerStroke.Thickness = 1
    outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outerStroke.Parent = mainFrame

    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 16, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 14)),
    })
    bgGradient.Rotation = 130
    bgGradient.Parent = mainFrame

    local shimmerClip = Instance.new("Frame")
    shimmerClip.Size = UDim2.new(1, 0, 1, 0)
    shimmerClip.BackgroundTransparency = 1
    shimmerClip.BorderSizePixel = 0
    shimmerClip.ClipsDescendants = true
    shimmerClip.ZIndex = 3
    shimmerClip.Parent = mainFrame

    local shimmerClipCorner = Instance.new("UICorner")
    shimmerClipCorner.CornerRadius = UDim.new(0, NOTIF_CORNER_RADIUS)
    shimmerClipCorner.Parent = shimmerClip

    local shimmer = Instance.new("Frame")
    shimmer.Size = UDim2.new(0, NOTIF_WIDTH * 0.3, 1, 0)
    shimmer.Position = UDim2.new(-0.35, 0, 0, 0)
    shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shimmer.BackgroundTransparency = 0.97
    shimmer.BorderSizePixel = 0
    shimmer.ZIndex = 4
    shimmer.Rotation = 10
    shimmer.Parent = shimmerClip

    local shimmerGrad = Instance.new("UIGradient")
    shimmerGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.9),
        NumberSequenceKeypoint.new(1, 1),
    })
    shimmerGrad.Rotation = 90
    shimmerGrad.Parent = shimmer

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

    local iconFrameCorner = Instance.new("UICorner")
    iconFrameCorner.CornerRadius = UDim.new(0, 8)
    iconFrameCorner.Parent = iconFrame

    local iconFrameStroke = Instance.new("UIStroke")
    iconFrameStroke.Color = Color3.fromRGB(55, 45, 90)
    iconFrameStroke.Thickness = 1
    iconFrameStroke.Parent = iconFrame

    local iconAspect = Instance.new("UIAspectRatioConstraint")
    iconAspect.AspectRatio = 1
    iconAspect.AspectType = Enum.AspectType.ScaleWithParentSize
    iconAspect.DominantAxis = Enum.DominantAxis.Height
    iconAspect.Parent = iconFrame

    local iconImage = Instance.new("ImageLabel")
    iconImage.Size = UDim2.new(0.68, 0, 0.68, 0)
    iconImage.Position = UDim2.new(0.16, 0, 0.16, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.Image = "rbxassetid://89557898457977"
    iconImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
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

    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(0, textWidth, 1, -(NOTIF_PROGRESS_HEIGHT + 3))
    textContainer.Position = UDim2.new(0, textOffsetX, 0, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.ZIndex = 5
    textContainer.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 15)
    titleLabel.Position = UDim2.new(0, 0, 0, 13)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(225, 215, 255)
    titleLabel.TextSize = NOTIF_TITLE_SIZE
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.ZIndex = 6
    titleLabel.Parent = textContainer

    local bodyLabel = Instance.new("TextLabel")
    bodyLabel.Size = UDim2.new(1, 0, 0, 12)
    bodyLabel.Position = UDim2.new(0, 0, 0, 30)
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Text = body
    bodyLabel.TextColor3 = Color3.fromRGB(110, 105, 135)
    bodyLabel.TextSize = NOTIF_BODY_SIZE
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextTruncate = Enum.TextTruncate.AtEnd
    bodyLabel.ZIndex = 6
    bodyLabel.Parent = textContainer

    local progressContainer = Instance.new("Frame")
    progressContainer.Name = "ProgressContainer"
    progressContainer.Size = UDim2.new(1, -(NOTIF_CORNER_RADIUS * 2), 0, NOTIF_PROGRESS_HEIGHT)
    progressContainer.Position = UDim2.new(0, NOTIF_CORNER_RADIUS, 1, -(NOTIF_PROGRESS_HEIGHT + 3))
    progressContainer.BackgroundColor3 = Color3.fromRGB(30, 28, 42)
    progressContainer.BorderSizePixel = 0
    progressContainer.ZIndex = 9
    progressContainer.Parent = mainFrame

    local progressContainerCorner = Instance.new("UICorner")
    progressContainerCorner.CornerRadius = UDim.new(1, 0)
    progressContainerCorner.Parent = progressContainer

    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(1, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 10
    progressFill.Parent = progressContainer

    local progressFillCorner = Instance.new("UICorner")
    progressFillCorner.CornerRadius = UDim.new(1, 0)
    progressFillCorner.Parent = progressFill

    local progressGrad = Instance.new("UIGradient")
    progressGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 120, 255)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(180, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 160)),
    })
    progressGrad.Parent = progressFill

    return mainFrame, progressFill, shimmer
end

local function normalizeNotifCfg(cfg)
    return {
        title = cfg.title or cfg.Title or "Flycer",
        body = cfg.body or cfg.Body or cfg.Description or cfg.Content or "",
        duration = cfg.duration or cfg.Duration or 5,
        onComplete = cfg.onComplete or cfg.OnComplete,
    }
end

local function processNotifQueue()
    if _notifRunning then
        return
    end
    _notifRunning = true

    task.spawn(function()
        while #_notifQueue > 0 do
            local cfg = table.remove(_notifQueue, 1)
            local duration = cfg.duration
            local onComplete = cfg.onComplete

            _notifActive = true

            local ok, err = pcall(function()
                local screen = getNotifScreen()
                local notifFrame, progressFill, shimmer = buildNotifFrame(screen, cfg)

                local targetPos = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_POS_X), 1, -(NOTIF_HEIGHT + NOTIF_POS_Y))
                local exitPos = UDim2.new(1, NOTIF_WIDTH + 20, 1, -(NOTIF_HEIGHT + NOTIF_POS_Y))

                local slideInInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                local slideOutInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

                TweenService:Create(notifFrame, slideInInfo, { Position = targetPos }):Play()

                local shimmerActive = true
                local shimmerThread = task.spawn(function()
                    while shimmerActive and notifFrame and notifFrame.Parent do
                        shimmer.Position = UDim2.new(-0.35, 0, 0, 0)
                        local tw = TweenService:Create(
                            shimmer,
                            TweenInfo.new(1.5, Enum.EasingStyle.Linear),
                            { Position = UDim2.new(1.2, 0, 0, 0) }
                        )
                        tw:Play()
                        tw.Completed:Wait()
                        if shimmerActive then
                            task.wait(1.7)
                        end
                    end
                end)

                TweenService:Create(
                    progressFill,
                    TweenInfo.new(duration, Enum.EasingStyle.Linear),
                    { Size = UDim2.new(0, 0, 1, 0) }
                ):Play()

                task.wait(duration)

                shimmerActive = false
                pcall(task.cancel, shimmerThread)

                local slideOut = TweenService:Create(notifFrame, slideOutInfo, { Position = exitPos })
                slideOut:Play()
                slideOut.Completed:Wait()

                if notifFrame and notifFrame.Parent then
                    notifFrame:Destroy()
                end

                if _notifScreen and _notifScreen.Parent then
                    if #_notifScreen:GetChildren() == 0 then
                        _notifScreen:Destroy()
                        _notifScreen = nil
                    end
                end
            end)

            _notifActive = false

            if not ok then
                warn("Flycer Notification error:", err)
            end

            if typeof(onComplete) == "function" then
                task.spawn(onComplete)
            end
            if #_notifQueue > 0 then
                task.wait(0.2)
            end
        end
        _notifRunning = false
    end)
end

local MAX_NOTIF_QUEUE = 3

local function ShowNotification(cfg)
    if _notifActive then
        return
    end
    if #_notifQueue >= MAX_NOTIF_QUEUE then
        return
    end

    cfg = normalizeNotifCfg(cfg or {})
    table.insert(_notifQueue, cfg)
    processNotifQueue()
end

_FLYCER_PRIVATE.ShowNotif = ShowNotification

-- RESIZE INPUT FIELD BUILDER

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
    lbl.TextTransparency = 0
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

    local inCorner = Instance.new("UICorner")
    inCorner.CornerRadius = UDim.new(0, 9)
    inCorner.Parent = inputBG

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
    textBox.TextTransparency = 0
    textBox.ClearTextOnFocus = false
    textBox.TextXAlignment = Enum.TextXAlignment.Center
    textBox.ZIndex = 15
    textBox.Parent = inputBG

    local filtering = false
    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        if filtering then
            return
        end
        filtering = true
        local filtered = textBox.Text:gsub("[^%d]", "")
        if filtered ~= textBox.Text then
            textBox.Text = filtered
        end
        filtering = false
    end)

    textBox.Focused:Connect(function()
        TweenService:Create(inStroke, TWEEN_FAST, { Color = RX.Accent1, Transparency = 0 }):Play()
        TweenService:Create(inputBG, TWEEN_FAST, { BackgroundTransparency = 0 }):Play()
        if isMobile and parentFrame and parentFrame.Parent then
            TweenService:Create(parentFrame, TWEEN_FAST, { Position = RESIZE_PANEL_UP_POS }):Play()
        end
    end)

    textBox.FocusLost:Connect(function()
        TweenService:Create(inStroke, TWEEN_FAST, {
            Color = Color3.fromRGB(55, 58, 85),
            Transparency = 0.3,
        }):Play()
        TweenService:Create(inputBG, TWEEN_FAST, { BackgroundTransparency = 0.08 }):Play()
        if isMobile and parentFrame and parentFrame.Parent then
            TweenService:Create(parentFrame, TWEEN_FAST, { Position = RESIZE_PANEL_CENTER_POS }):Play()
        end
    end)

    return container, textBox
end

-- RESIZE GUI

local function findExistingResizeGUI()
    for _, c in ipairs(getAllContainers()) do
        for _, child in ipairs(c:GetChildren()) do
            if child:IsA("ScreenGui") and child:GetAttribute("FlycerResizeTag") == true then
                return child
            end
        end
    end
    return nil
end

local function openResizeGUI(refs)
    local MF = refs.MainFrame
    local TF = refs.ToggleFrame
    local CW = refs.ContentWrapper
    local SF = refs.ShadowFrame
    local TabSF = refs.TabShadowFrame
    local TabRC = refs.TabRailClip
    local EF = refs.ExtraFrame
    local MainGuiRef = refs.MainGui

    local existing = findExistingResizeGUI()
    if existing then
        existing:Destroy()
    end

    local ResizeSG = Instance.new("ScreenGui")
    ResizeSG.ResetOnSpawn = false
    ResizeSG.IgnoreGuiInset = true
    ResizeSG.DisplayOrder = 999999999
    ResizeSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SecureGui(ResizeSG)
    ResizeSG:SetAttribute("FlycerResizeTag", true)

    -- Cleanup resize when main GUI is destroyed
    if MainGuiRef and MainGuiRef.Parent then
        MainGuiRef.Destroying:Connect(function()
            if ResizeSG and ResizeSG.Parent then
                ResizeSG:Destroy()
            end
        end)
    end

    local isClosing = false

    local function setMainUIVisible(visible)
        if MF and MF.Parent then
            MF.Visible = visible
        end
        if TF and TF.Parent then
            TF.Visible = visible
        end
    end

    local marginL = (RESIZE_PANEL_WIDTH - (RESIZE_FIELD_WIDTH * 2 + RESIZE_FIELD_GAP)) / 2

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.55
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 10
    overlay.Active = false
    overlay.Parent = ResizeSG

    local resizePanel = Instance.new("Frame")
    resizePanel.Size = UDim2.new(0, RESIZE_PANEL_WIDTH, 0, RESIZE_PANEL_HEIGHT)
    resizePanel.AnchorPoint = Vector2.new(0.5, 0.5)
    resizePanel.Position = RESIZE_PANEL_CENTER_POS
    resizePanel.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    resizePanel.BackgroundTransparency = 0.15
    resizePanel.BorderSizePixel = 0
    resizePanel.ZIndex = 11
    resizePanel.ClipsDescendants = false
    resizePanel.Active = true
    resizePanel.Parent = ResizeSG

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = resizePanel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Thickness = 1.2
    panelStroke.Color = RX.Accent1
    panelStroke.Transparency = 0.3
    panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    panelStroke.Parent = resizePanel

    local panelStrokeGrad = Instance.new("UIGradient")
    panelStrokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 60, 100)),
        ColorSequenceKeypoint.new(0.35, RX.Accent1),
        ColorSequenceKeypoint.new(0.65, RX.Accent2),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 60, 100)),
    })
    panelStrokeGrad.Rotation = 135
    panelStrokeGrad.Parent = panelStroke
    registerStrokeTarget(panelStrokeGrad)

    resizePanel.Destroying:Connect(function()
        unregisterStrokeTarget(panelStrokeGrad)
    end)

    local panelGrad = Instance.new("UIGradient")
    panelGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 28)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 14, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 18)),
    })
    panelGrad.Rotation = 180
    panelGrad.Parent = resizePanel

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundTransparency = 1
    titleBar.ZIndex = 13
    titleBar.Parent = resizePanel
    makeDraggable(titleBar, resizePanel)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -52, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Resize UI"
    titleLbl.TextColor3 = RX.T1
    titleLbl.TextTransparency = 0
    titleLbl.Font = RX.F1
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextYAlignment = Enum.TextYAlignment.Center
    titleLbl.ZIndex = 14
    titleLbl.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -38, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(0, 0.5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(240, 70, 80)
    closeBtn.BackgroundTransparency = 0.25
    closeBtn.Text = "X"
    closeBtn.Font = RX.F1
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextTransparency = 0
    closeBtn.AutoButtonColor = false
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 15
    closeBtn.Parent = titleBar

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn

    local closeBtnStroke = Instance.new("UIStroke")
    closeBtnStroke.Thickness = 1
    closeBtnStroke.Color = Color3.fromRGB(240, 70, 80)
    closeBtnStroke.Transparency = 0.5
    closeBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    closeBtnStroke.Parent = closeBtn

    makeSeparator(resizePanel, 40, false)

    if not isMobile then
        closeBtn.MouseEnter:Connect(function()
            TweenService:Create(closeBtn, TWEEN_FAST, { BackgroundTransparency = 0 }):Play()
        end)
        closeBtn.MouseLeave:Connect(function()
            TweenService:Create(closeBtn, TWEEN_FAST, { BackgroundTransparency = 0.25 }):Play()
        end)
    end

    local _, widthInput = makeInputField(resizePanel, marginL, "WIDTH", currentGUIWidth)
    local _, heightInput =
        makeInputField(resizePanel, marginL + RESIZE_FIELD_WIDTH + RESIZE_FIELD_GAP, "HEIGHT", currentGUIHeight)

    local changeBtn = Instance.new("TextButton")
    changeBtn.Size = UDim2.new(1, -28, 0, 34)
    changeBtn.Position = UDim2.new(0, 14, 0, RESIZE_PANEL_HEIGHT - 48)
    changeBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    changeBtn.BackgroundTransparency = 0.05
    changeBtn.Text = ""
    changeBtn.AutoButtonColor = false
    changeBtn.BorderSizePixel = 0
    changeBtn.ZIndex = 13
    changeBtn.Parent = resizePanel

    local changeBtnCorner = Instance.new("UICorner")
    changeBtnCorner.CornerRadius = UDim.new(0, 10)
    changeBtnCorner.Parent = changeBtn

    local changeBtnGrad = Instance.new("UIGradient")
    changeBtnGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(40, 180, 100)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(50, 200, 110)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(60, 210, 120)),
    })
    changeBtnGrad.Rotation = 90
    changeBtnGrad.Parent = changeBtn

    local changeBtnStroke = Instance.new("UIStroke")
    changeBtnStroke.Thickness = 1.2
    changeBtnStroke.Color = Color3.fromRGB(80, 220, 130)
    changeBtnStroke.Transparency = 0.3
    changeBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    changeBtnStroke.Parent = changeBtn

    local changeBtnLabel = Instance.new("TextLabel")
    changeBtnLabel.Size = UDim2.new(1, 0, 1, 0)
    changeBtnLabel.BackgroundTransparency = 1
    changeBtnLabel.Text = "APPLY"
    changeBtnLabel.Font = RX.F1
    changeBtnLabel.TextSize = 12
    changeBtnLabel.TextColor3 = Color3.fromRGB(220, 255, 235)
    changeBtnLabel.TextTransparency = 0
    changeBtnLabel.TextXAlignment = Enum.TextXAlignment.Center
    changeBtnLabel.TextYAlignment = Enum.TextYAlignment.Center
    changeBtnLabel.ZIndex = 15
    changeBtnLabel.Parent = changeBtn

    if not isMobile then
        changeBtn.MouseEnter:Connect(function()
            TweenService:Create(changeBtn, TWEEN_FAST, { BackgroundTransparency = 0 }):Play()
            TweenService:Create(changeBtnStroke, TWEEN_FAST, { Transparency = 0.1 }):Play()
        end)
        changeBtn.MouseLeave:Connect(function()
            TweenService:Create(changeBtn, TWEEN_FAST, { BackgroundTransparency = 0.05 }):Play()
            TweenService:Create(changeBtnStroke, TWEEN_FAST, { Transparency = 0.4 }):Play()
        end)
    end

    local originalTrans = {}

    local function cachePanelObj(obj)
        if not obj or not obj.Parent then
            return
        end
        local t = {}
        if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
            t.BackgroundTransparency = obj.BackgroundTransparency
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            t.BackgroundTransparency = obj.BackgroundTransparency
            t.TextTransparency = obj.TextTransparency
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            t.BackgroundTransparency = obj.BackgroundTransparency
            t.ImageTransparency = obj.ImageTransparency
        end
        if obj:IsA("UIStroke") then
            t.Transparency = obj.Transparency
        end
        if next(t) then
            originalTrans[obj] = t
        end
    end

    cachePanelObj(resizePanel)
    cachePanelObj(overlay)
    for _, d in ipairs(resizePanel:GetDescendants()) do
        cachePanelObj(d)
    end

    local function hideAllInstant()
        for obj, props in pairs(originalTrans) do
            if obj and obj.Parent then
                for propName in pairs(props) do
                    obj[propName] = 1
                end
            end
        end
    end

    local function fadePanelTo(targetAlpha, dur, callback)
        local tweenI = TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local activeTweens = 0
        local cbCalled = false

        local function fireCallback()
            if callback and not cbCalled and activeTweens <= 0 then
                cbCalled = true
                task.spawn(callback)
            end
        end

        for obj, props in pairs(originalTrans) do
            if obj and obj.Parent then
                local tp = {}
                for propName, origVal in pairs(props) do
                    tp[propName] = (targetAlpha == 0) and origVal or 1
                end
                if next(tp) then
                    local tw = TweenService:Create(obj, tweenI, tp)
                    activeTweens = activeTweens + 1
                    local conn
                    conn = tw.Completed:Connect(function()
                        if conn then
                            conn:Disconnect()
                            conn = nil
                        end
                        activeTweens = activeTweens - 1
                        fireCallback()
                    end)
                    tw:Play()
                end
            end
        end

        if activeTweens == 0 then
            fireCallback()
        end
    end

    local function closeResizeGui(callback)
        if isClosing then
            return
        end
        isClosing = true
        unregisterStrokeTarget(panelStrokeGrad)
        fadePanelTo(1, 0.30, function()
            setMainUIVisible(true)
            if ResizeSG and ResizeSG.Parent then
                ResizeSG:Destroy()
            end
            if callback then
                task.spawn(callback)
            end
        end)
    end

    local closeBtnDebounce = false
    local function onCloseBtn()
        if closeBtnDebounce or isClosing then
            return
        end
        closeBtnDebounce = true
        closeResizeGui()
        task.delay(1, function()
            closeBtnDebounce = false
        end)
    end

    closeBtn.Activated:Connect(onCloseBtn)

    local applyDebounce = false
    local function applyResize()
        if applyDebounce or isClosing then
            return
        end
        applyDebounce = true

        local wVal = math.clamp(tonumber(widthInput.Text) or currentGUIWidth, 150, 800)
        local hVal = math.clamp(tonumber(heightInput.Text) or currentGUIHeight, 100, 700)

        currentGUIWidth = wVal
        currentGUIHeight = hVal
        g.FlycerGUIWidth = wVal
        g.FlycerGUIHeight = hVal

        changeBtnLabel.Text = "CHANGED..."
        TweenService:Create(changeBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = RX.Green,
            BackgroundTransparency = 0,
        }):Play()

        task.delay(0.25, function()
            closeResizeGui(function()
                local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                local newLayout = calcLayout(wVal, hVal)

                if MF and MF.Parent then
                    TweenService:Create(MF, tweenInfo, {
                        Size = newLayout.mainSize,
                        Position = newLayout.mainPos,
                    }):Play()
                end
                if CW and CW.Parent then
                    TweenService:Create(CW, tweenInfo, { Size = newLayout.contentSize }):Play()
                end
                if SF and SF.Parent then
                    TweenService:Create(SF, tweenInfo, {
                        Size = newLayout.shadowSize,
                        Position = newLayout.shadowPos,
                    }):Play()
                end
                if TabSF and TabSF.Parent then
                    TweenService:Create(TabSF, tweenInfo, {
                        Size = newLayout.tabShadowSize,
                        Position = newLayout.tabShadowPos,
                    }):Play()
                end
                if TabRC and TabRC.Parent then
                    TweenService:Create(TabRC, tweenInfo, {
                        Position = newLayout.tabRailClipPos,
                    }):Play()
                end
                if TF and TF.Parent then
                    TweenService:Create(TF, tweenInfo, { Position = newLayout.togglePos }):Play()
                end
                if EF and EF.Parent then
                    TweenService:Create(EF, tweenInfo, {
                        Position = newLayout.extraFramePos,
                        Size = newLayout.extraFrameSize,
                    }):Play()
                end

                ShowNotification({
                    title = "Resize UI",
                    body = string.format("Size changed : %d x %d px", wVal, hVal),
                    duration = 3,
                })
            end)
        end)

        task.delay(2.5, function()
            applyDebounce = false
        end)
    end

    changeBtn.Activated:Connect(applyResize)

    setMainUIVisible(false)
    hideAllInstant()
    fadePanelTo(0, 0.30)
end

--==================================================
-- FLYCER LIBRARY MODULE
--==================================================

local FlycerLib = {}

function FlycerLib:Notify(cfg)
    ShowNotification(cfg or {})
end

function FlycerLib:CreateWindow(windowCfg)
    windowCfg = windowCfg or {}

    local GUI_TITLE = windowCfg.Name or windowCfg.Title or "FlycerUI - Hub"
    local loadingTitle = windowCfg.LoadingTitle or GUI_TITLE
    local loadingSubtitle = windowCfg.LoadingSubtitle or "Loading..."
    local discordConfig = windowCfg.Discord or {}
    local discordEnabled = discordConfig.Enabled ~= false
    local discordLink = discordConfig.Link or DISCORD_LINK

    -- Show loading notification
    ShowNotification({
        title = loadingTitle,
        body = loadingSubtitle,
        duration = 1,
    })

    -- ScreenGui
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

    -- MainFrame
    local initLayout = calcLayout(currentGUIWidth, currentGUIHeight)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = randomName()
    MainFrame.Size = initLayout.mainSize
    MainFrame.AutomaticSize = Enum.AutomaticSize.None
    MainFrame.Position = initLayout.mainPos
    MainFrame.BackgroundColor3 = RX.Accent1
    MainFrame.BackgroundTransparency = RX.MainAlpha
    MainFrame.BorderSizePixel = 0
    MainFrame.ZIndex = 2
    MainFrame.Active = true
    MainFrame.ClipsDescendants = false
    MainFrame:SetAttribute("FlycerTag", true)
    MainFrame.Visible = true
    MainFrame.Parent = MainGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = MainFrame

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

    MainFrame.Destroying:Connect(function()
        unregisterStrokeTarget(mainStrokeGrad)
    end)

    local glassOverlay = Instance.new("Frame")
    glassOverlay.Name = "GlassOverlay"
    glassOverlay.Size = UDim2.new(1, 0, 0, 38)
    glassOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glassOverlay.BackgroundTransparency = 0.96
    glassOverlay.BorderSizePixel = 0
    glassOverlay.ZIndex = 1
    glassOverlay.Parent = MainFrame

    local glassCorner = Instance.new("UICorner")
    glassCorner.CornerRadius = UDim.new(0, 12)
    glassCorner.Parent = glassOverlay

    local glassGrad = Instance.new("UIGradient")
    glassGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.88),
        NumberSequenceKeypoint.new(0.4, 0.96),
        NumberSequenceKeypoint.new(1, 1),
    })
    glassGrad.Rotation = 90
    glassGrad.Parent = glassOverlay

    local innerGrad = Instance.new("UIGradient")
    innerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 28)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 14, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 18)),
    })
    innerGrad.Rotation = 180
    innerGrad.Parent = MainFrame

    -- Viewport resize handler
    local _lastVP = Vector2.new(0, 0)
    local _vpConnection = nil

    local ExtraFrame = nil
    local ToggleFrame = nil
    local DragBar = nil
    local DragBarHitbox = nil

    local function onViewportChanged()
        local vp = Camera.ViewportSize
        if math.abs(vp.X - _lastVP.X) < 2 and math.abs(vp.Y - _lastVP.Y) < 2 then
            return
        end
        _lastVP = vp
        if MainFrame and MainFrame.Parent then
            MainFrame.Position = getScreenCenter(MainFrame.AbsoluteSize.X, MainFrame.AbsoluteSize.Y)
        end
        if ToggleFrame and ToggleFrame.Parent then
            ToggleFrame.Position = getCenteredTogglePos(MainFrame.AbsoluteSize.Y)
        end
    end

    _vpConnection = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportChanged)
    MainGui.Destroying:Connect(function()
        if _vpConnection then
            _vpConnection:Disconnect()
            _vpConnection = nil
        end
    end)

    local _tabFadeExempt = {}
    local function markFadeExempt(instance)
        _tabFadeExempt[instance] = true
    end
    local function isFadeExempt(instance, forToggle)
        if forToggle then
            return false
        end
        return _tabFadeExempt[instance] == true
    end

    -- HEADER

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, HEADER_H)
    Header.BackgroundTransparency = 1
    Header.BorderSizePixel = 0
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

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, RX.T1),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 185, 255)),
        ColorSequenceKeypoint.new(1, RX.Accent2),
    })
    titleGrad.Parent = titleLabel

    makeSeparator(Header, 0, true, 1)

    -- PING COUNTER

    local PING_COLOR = Color3.fromRGB(60, 210, 120)
    local PING_UPDATE_INTERVAL = 0.25

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

    local pingContainerCorner = Instance.new("UICorner")
    pingContainerCorner.CornerRadius = UDim.new(0, 5)
    pingContainerCorner.Parent = pingContainer

    local pingStroke = Instance.new("UIStroke")
    pingStroke.Thickness = 1
    pingStroke.Color = Color3.fromRGB(60, 210, 120)
    pingStroke.Transparency = 0.4
    pingStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pingStroke.Parent = pingContainer

    local pingIcon = Instance.new("ImageLabel")
    pingIcon.Name = "PingIcon"
    pingIcon.Size = UDim2.new(0, 13, 0, 13)
    pingIcon.Position = UDim2.new(0, 5, 0.5, 0)
    pingIcon.AnchorPoint = Vector2.new(0, 0.5)
    pingIcon.BackgroundTransparency = 1
    pingIcon.Image = "rbxassetid://82891792883050"
    pingIcon.ImageColor3 = Color3.fromRGB(60, 210, 120)
    pingIcon.ScaleType = Enum.ScaleType.Fit
    pingIcon.ZIndex = 12
    pingIcon.Parent = pingContainer

    local pingLabel = Instance.new("TextLabel")
    pingLabel.Name = "PingLabel"
    pingLabel.Size = UDim2.new(1, -18, 1, 0)
    pingLabel.Position = UDim2.new(0, 20, 0, 0)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Text = "PING: 0ms"
    pingLabel.Font = RX.F1
    pingLabel.TextSize = 10
    pingLabel.TextColor3 = PING_COLOR
    pingLabel.TextXAlignment = Enum.TextXAlignment.Left
    pingLabel.BorderSizePixel = 0
    pingLabel.ZIndex = 12
    pingLabel.Parent = pingContainer

    local pingConnection = nil
    local lastPingUpdate = 0

    local function GetPing()
        local ok, result = pcall(function()
            return LocalPlayer:GetNetworkPing()
        end)
        if ok and result and result == result then
            return math.round(math.max(result * 1000, 0))
        end
        return 0
    end

    local function StartPingCounter()
        if pingConnection then
            return
        end
        lastPingUpdate = os.clock()
        pingConnection = RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if now - lastPingUpdate < PING_UPDATE_INTERVAL then
                return
            end
            lastPingUpdate = now
            if pingLabel and pingLabel.Parent then
                pingLabel.Text = "PING: " .. tostring(GetPing()) .. "ms"
                pingLabel.TextColor3 = PING_COLOR
            end
        end)
    end

    local function StopPingCounter()
        if pingConnection then
            pingConnection:Disconnect()
            pingConnection = nil
        end
        if pingLabel and pingLabel.Parent then
            pingLabel.Text = "PING: 0ms"
            pingLabel.TextColor3 = PING_COLOR
        end
    end

    _FLYCER_PRIVATE.StartPing = StartPingCounter
    _FLYCER_PRIVATE.StopPing = StopPingCounter
    MainGui.Destroying:Connect(StopPingCounter)

    -- FPS COUNTER

    local FPS_COLOR = Color3.fromRGB(240, 220, 50)
    local FPS_UPDATE_INTERVAL = 0.25

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

    local fpsContainerCorner = Instance.new("UICorner")
    fpsContainerCorner.CornerRadius = UDim.new(0, 5)
    fpsContainerCorner.Parent = fpsContainer

    local fpsStroke = Instance.new("UIStroke")
    fpsStroke.Thickness = 1
    fpsStroke.Color = Color3.fromRGB(240, 220, 50)
    fpsStroke.Transparency = 0.4
    fpsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fpsStroke.Parent = fpsContainer

    local fpsIcon = Instance.new("ImageLabel")
    fpsIcon.Name = "FPSIcon"
    fpsIcon.Size = UDim2.new(0, 18, 0, 18)
    fpsIcon.Position = UDim2.new(0, 5, 0.5, 0)
    fpsIcon.AnchorPoint = Vector2.new(0, 0.5)
    fpsIcon.BackgroundTransparency = 1
    fpsIcon.Image = "rbxassetid://123289872032874"
    fpsIcon.ImageColor3 = Color3.fromRGB(240, 220, 50)
    fpsIcon.ScaleType = Enum.ScaleType.Fit
    fpsIcon.ZIndex = 12
    fpsIcon.Parent = fpsContainer

    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "FPSLabel"
    fpsLabel.Size = UDim2.new(1, -18, 1, 0)
    fpsLabel.Position = UDim2.new(0, 25, 0, 0)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "FPS: 0"
    fpsLabel.Font = RX.F1
    fpsLabel.TextSize = 10
    fpsLabel.TextColor3 = FPS_COLOR
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    fpsLabel.BorderSizePixel = 0
    fpsLabel.ZIndex = 12
    fpsLabel.Parent = fpsContainer

    local fpsConnection = nil
    local frameCount = 0
    local lastUpdateTime = 0

    local function StartFPSCounter()
        if fpsConnection then
            return
        end
        frameCount = 0
        lastUpdateTime = os.clock()

        local function fpsCallback()
            frameCount = frameCount + 1
            local now = os.clock()
            local elapsed = now - lastUpdateTime
            if elapsed >= FPS_UPDATE_INTERVAL then
                if fpsLabel and fpsLabel.Parent then
                    fpsLabel.Text = "FPS: " .. tostring(math.round(frameCount / elapsed))
                    fpsLabel.TextColor3 = FPS_COLOR
                end
                frameCount = 0
                lastUpdateTime = now
            end
        end

        local ok = pcall(function()
            fpsConnection = RunService.RenderStepped:Connect(fpsCallback)
        end)
        if not ok then
            fpsConnection = RunService.Heartbeat:Connect(fpsCallback)
        end
    end

    local function StopFPSCounter()
        if fpsConnection then
            fpsConnection:Disconnect()
            fpsConnection = nil
        end
        if fpsLabel and fpsLabel.Parent then
            fpsLabel.Text = "FPS: 0"
            fpsLabel.TextColor3 = FPS_COLOR
        end
    end

    _FLYCER_PRIVATE.StartFPS = StartFPSCounter
    _FLYCER_PRIVATE.StopFPS = StopFPSCounter
    MainGui.Destroying:Connect(StopFPSCounter)

    -- TAB RAIL

    local TabShadowFrame = Instance.new("Frame")
    TabShadowFrame.Name = "TabShadowFrame"
    TabShadowFrame.Size = initLayout.tabShadowSize
    TabShadowFrame.Position = initLayout.tabShadowPos
    TabShadowFrame.BackgroundColor3 = RX.Accent1
    TabShadowFrame.BackgroundTransparency = 0.6
    TabShadowFrame.BorderSizePixel = 0
    TabShadowFrame.ZIndex = 1
    TabShadowFrame.Parent = MainFrame
    markFadeExempt(TabShadowFrame)

    local TabShadowCorner = Instance.new("UICorner")
    TabShadowCorner.CornerRadius = UDim.new(0, 3)
    TabShadowCorner.Parent = TabShadowFrame

    local TabRailClip = Instance.new("Frame")
    TabRailClip.Name = "TabRailClip"
    TabRailClip.Size = UDim2.new(1, -TAB_RAIL_MARGIN * 2, 0, TAB_HEIGHT)
    TabRailClip.Position = initLayout.tabRailClipPos
    TabRailClip.BackgroundTransparency = 1
    TabRailClip.BorderSizePixel = 0
    TabRailClip.ClipsDescendants = true
    TabRailClip.ZIndex = 8
    TabRailClip.Parent = MainFrame
    markFadeExempt(TabRailClip)

    local TabScroll = Instance.new("ScrollingFrame")
    TabScroll.Name = "TabScroll"
    TabScroll.Size = UDim2.new(1, 0, 1, 0)
    TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    TabScroll.ScrollingDirection = Enum.ScrollingDirection.X
    TabScroll.ScrollingEnabled = true
    TabScroll.BackgroundTransparency = 1
    TabScroll.BorderSizePixel = 0
    TabScroll.ZIndex = 8
    TabScroll.ElasticBehavior = Enum.ElasticBehavior.Never
    TabScroll.Parent = TabRailClip
    markFadeExempt(TabScroll)

    if isMobile then
        TabScroll.ScrollBarThickness = 1
        TabScroll.ScrollBarImageTransparency = 1
        TabScroll.ScrollBarImageColor3 = RX.Accent1
    else
        TabScroll.ScrollBarThickness = 0
    end

    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.FillDirection = Enum.FillDirection.Horizontal
    tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
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
    ShadowFrame.Name = "ShadowFrame"
    ShadowFrame.Size = initLayout.shadowSize
    ShadowFrame.Position = initLayout.shadowPos
    ShadowFrame.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
    ShadowFrame.BackgroundTransparency = 0.8
    ShadowFrame.BorderSizePixel = 0
    ShadowFrame.ZIndex = 1
    ShadowFrame.Parent = MainFrame

    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 8)
    ShadowCorner.Parent = ShadowFrame

    local ContentWrapper = Instance.new("Frame")
    ContentWrapper.Name = "ContentWrapper"
    ContentWrapper.Size = initLayout.contentSize
    ContentWrapper.AutomaticSize = Enum.AutomaticSize.None
    ContentWrapper.Position = UDim2.new(0, 0, 0, CONTENT_TOP)
    ContentWrapper.BackgroundTransparency = 1
    ContentWrapper.BorderSizePixel = 0
    ContentWrapper.ClipsDescendants = true
    ContentWrapper.ZIndex = 5
    ContentWrapper.Parent = MainFrame

    -- TAB SYSTEM CORE

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
        sf.ScrollingEnabled = true
        sf.ScrollBarThickness = 3
        sf.ScrollBarImageColor3 = RX.Accent1
        sf.ScrollBarImageTransparency = 1
        sf.BackgroundTransparency = 1
        sf.BorderSizePixel = 0
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
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.Padding = UDim.new(0, 5)
        layout.Parent = sf

        return sf, layout
    end

    local function activateTab(name)
        if tabSwitchDebounce then
            return
        end
        if activeTabName == name then
            return
        end
        tabSwitchDebounce = true

        local INACTIVE_BG = Color3.fromRGB(22, 22, 34)
        local ACTIVE_BG = Color3.fromRGB(32, 32, 52)

        for _, entry in ipairs(tabRegistry) do
            local active = (entry.name == name)
            entry.canvas.Visible = active
            TweenService:Create(entry.button, TWEEN_FAST, {
                BackgroundColor3 = active and ACTIVE_BG or INACTIVE_BG,
                BackgroundTransparency = active and 0 or 0.3,
            }):Play()
            TweenService:Create(entry.label, TWEEN_FAST, {
                TextColor3 = active and RX.T1 or RX.T3,
            }):Play()
            TweenService:Create(entry.stroke, TWEEN_FAST, {
                Transparency = active and 0.3 or 0.8,
                Color = active and RX.Accent1 or RX.Border,
            }):Play()
        end

        activeTabName = name
        task.delay(0.18, function()
            tabSwitchDebounce = false
        end)
    end

    local function addTab(name, layoutOrderHint)
        local canvas, layout = makeTabCanvas()
        local estimatedW = math.max(TAB_MIN_WIDTH, string.len(name) * 7 + TAB_PADDING * 2)

        local button = Instance.new("Frame")
        button.Name = "Tab_" .. name
        button.Size = UDim2.new(0, estimatedW, 0, TAB_HEIGHT - 7)
        button.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
        button.BackgroundTransparency = 0.3
        button.BorderSizePixel = 0
        button.LayoutOrder = layoutOrderHint or #tabRegistry + 1
        button.ZIndex = 9
        button.Parent = TabScroll

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = button

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Thickness = 1
        btnStroke.Color = RX.Border
        btnStroke.Transparency = 0.8
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
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextYAlignment = Enum.TextYAlignment.Center
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

        if not isMobile then
            hitbox.MouseEnter:Connect(function()
                if activeTabName ~= name then
                    TweenService:Create(button, TWEEN_FAST, { BackgroundTransparency = 0.1 }):Play()
                    TweenService:Create(lbl, TWEEN_FAST, { TextColor3 = RX.T2 }):Play()
                end
            end)
            hitbox.MouseLeave:Connect(function()
                if activeTabName ~= name then
                    TweenService:Create(button, TWEEN_FAST, { BackgroundTransparency = 0.3 }):Play()
                    TweenService:Create(lbl, TWEEN_FAST, { TextColor3 = RX.T3 }):Play()
                end
            end)
        end

        hitbox.Activated:Connect(function()
            activateTab(name)
        end)

        table.insert(tabRegistry, {
            name = name,
            button = button,
            label = lbl,
            stroke = btnStroke,
            canvas = canvas,
            layout = layout,
        })

        if not firstTabName then
            firstTabName = name
        end

        return canvas, layout
    end

    -- EXTRA FRAME

    ExtraFrame = Instance.new("Frame")
    ExtraFrame.Name = "ExtraFrame"
    ExtraFrame.Size = initLayout.extraFrameSize
    ExtraFrame.Position = initLayout.extraFramePos
    ExtraFrame.BackgroundColor3 = RX.Accent1
    ExtraFrame.BackgroundTransparency = RX.MainAlpha
    ExtraFrame.BorderSizePixel = 0
    ExtraFrame.ZIndex = 6
    ExtraFrame.ClipsDescendants = false
    ExtraFrame:SetAttribute("FlycerTag", true)
    ExtraFrame.Visible = true
    ExtraFrame.Parent = MainFrame

    local ec = Instance.new("UICorner")
    ec.CornerRadius = UDim.new(0, 6)
    ec.Parent = ExtraFrame

    local es = Instance.new("UIStroke")
    es.Thickness = 1
    es.Color = RX.Accent1
    es.Transparency = 0.4
    es.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    es.Parent = ExtraFrame

    -- DRAG BAR

    DragBarHitbox = Instance.new("Frame")
    DragBarHitbox.Name = "DragBarHitbox"
    DragBarHitbox.BackgroundTransparency = 1
    DragBarHitbox.BorderSizePixel = 0
    DragBarHitbox.ZIndex = 20
    DragBarHitbox.Active = true
    DragBarHitbox.AnchorPoint = Vector2.new(0.5, 0.5)
    DragBarHitbox.Size = UDim2.new(0, 80, 0, 20)
    DragBarHitbox.Position = UDim2.new(0.5, 0, 0.5, 35)
    DragBarHitbox.Parent = ExtraFrame

    DragBar = Instance.new("Frame")
    DragBar.Name = "DragBar"
    DragBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DragBar.BackgroundTransparency = 0.80
    DragBar.BorderSizePixel = 0
    DragBar.ZIndex = 21
    DragBar.AnchorPoint = Vector2.new(0.5, 0.5)
    DragBar.Size = UDim2.new(0, 50, 0, 3)
    DragBar.Position = UDim2.new(0.5, 0, 0.5, -5)
    DragBar.Parent = DragBarHitbox

    local dragBarCorner = Instance.new("UICorner")
    dragBarCorner.CornerRadius = UDim.new(1, 0)
    dragBarCorner.Parent = DragBar

    makeDraggable(DragBarHitbox, MainFrame)

    local isDragging = false
    local isHovered = false

    UserInputService.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            if isDragging then
                isDragging = false
                TweenService:Create(DragBar, TWEEN_FAST, {
                    BackgroundTransparency = isHovered and 0.50 or 0.80,
                }):Play()
            end
        end
    end)

    if not isMobile then
        DragBarHitbox.MouseEnter:Connect(function()
            isHovered = true
            if not isDragging then
                TweenService:Create(DragBar, TWEEN_FAST, { BackgroundTransparency = 0.60 }):Play()
            end
        end)
        DragBarHitbox.MouseLeave:Connect(function()
            isHovered = false
            if not isDragging then
                TweenService:Create(DragBar, TWEEN_FAST, { BackgroundTransparency = 0.80 }):Play()
            end
        end)
    end

    DragBarHitbox.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            isDragging = true
            TweenService:Create(DragBar, TWEEN_FAST, { BackgroundTransparency = 0.20 }):Play()
        end
    end)

    -- setUILock
    local function setUILock(locked)
        isUILocked = locked
        g.FlycerUILocked = locked

        if DragBar and DragBar.Parent and DragBarHitbox and DragBarHitbox.Parent then
            if locked then
                TweenService:Create(DragBar, TWEEN_NORMAL, { BackgroundTransparency = 1 }):Play()
                task.delay(0.3, function()
                    if DragBarHitbox and DragBarHitbox.Parent then
                        DragBarHitbox.Visible = false
                    end
                end)
            else
                if DragBarHitbox then
                    DragBarHitbox.Visible = true
                end
                TweenService:Create(DragBar, TWEEN_NORMAL, { BackgroundTransparency = 0.80 }):Play()
            end
        end

        local statusText = locked and "LOCKED" or "UNLOCKED"
        ShowNotification({
            title = "UI Position " .. statusText,
            body = locked and "Drag disabled - position locked" or "Drag enabled - position unlocked",
            duration = 2.1,
        })
    end

    -- TIMER WHITELIST

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Position = UDim2.new(0, 4, 0.5, 0)
    timerLabel.AnchorPoint = Vector2.new(0, 0.5)
    timerLabel.Size = UDim2.new(0, 100, 0, 20)
    timerLabel.BackgroundColor3 = RX.Accent1
    timerLabel.BackgroundTransparency = 0.8
    timerLabel.BorderSizePixel = 0
    timerLabel.Text = "0000D : 00H : 00M"
    timerLabel.Font = RX.FM
    timerLabel.TextSize = 9
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.ZIndex = 11
    timerLabel.Parent = ExtraFrame

    local timerCorner = Instance.new("UICorner")
    timerCorner.CornerRadius = UDim.new(0, 5)
    timerCorner.Parent = timerLabel

    local timerStroke = Instance.new("UIStroke")
    timerStroke.Thickness = 1
    timerStroke.Color = RX.Accent1
    timerStroke.Transparency = 0.4
    timerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    timerStroke.Parent = timerLabel

    local function formatTimer(totalSeconds)
        if totalSeconds <= 0 then
            return nil
        end
        return string.format(
            "%04dD : %02dH : %02dM",
            math.floor(totalSeconds / 86400),
            math.floor((totalSeconds % 86400) / 3600),
            math.floor((totalSeconds % 3600) / 60)
        )
    end

    local function startKeyTimer()
        local SessionManager = _FLYCER_PRIVATE.Session
        if not SessionManager then
            if timerLabel and timerLabel.Parent then
                timerLabel.Text = "NO SESSION"
            end
            return
        end
        task.spawn(function()
            local data = nil
            local elapsed = 0
            while not data and elapsed < 8 do
                local ok, result = pcall(function()
                    return SessionManager:getData()
                end)
                if ok and type(result) == "table" then
                    data = result
                    break
                end
                task.wait(0.5)
                elapsed = elapsed + 0.5
            end
            if not data then
                if timerLabel and timerLabel.Parent then
                    timerLabel.Text = "NO KEY DATA"
                end
                return
            end
            local keyType = data.keyType
            local expireTimestamp = data.expireTimestamp
            if not keyType then
                if timerLabel and timerLabel.Parent then
                    timerLabel.Text = "NO KEY DATA"
                end
                return
            end
            if keyType == "lifetime" then
                if timerLabel and timerLabel.Parent then
                    timerLabel.Text = "LIFETIME ACCESS"
                end
                return
            end
            if keyType == "free" and (not expireTimestamp or tonumber(expireTimestamp) == 0) then
                if timerLabel and timerLabel.Parent then
                    timerLabel.Text = "FREE UNLIMITED"
                end
                return
            end
            if expireTimestamp then
                local expireTime = tonumber(expireTimestamp)
                if not expireTime or expireTime - os.time() <= 0 then
                    if timerLabel and timerLabel.Parent then
                        timerLabel.Text = "EXPIRED"
                    end
                    return
                end
                task.spawn(function()
                    while timerLabel and timerLabel.Parent do
                        local remaining = expireTime - os.time()
                        if remaining <= 0 then
                            timerLabel.Text = "EXPIRED"
                            break
                        end
                        local fmt = formatTimer(remaining)
                        timerLabel.Text = fmt or "EXPIRED"
                        if not fmt then
                            break
                        end
                        task.wait(1)
                    end
                end)
            else
                if timerLabel and timerLabel.Parent then
                    timerLabel.Text = "NO EXPIRE"
                end
            end
        end)
    end

    task.defer(startKeyTimer)

    -- TOGGLE BUTTON SYSTEM

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
        BillboardGui = true,
        UIListLayout = true,
        UIGridLayout = true,
        UIPageLayout = true,
        UITableLayout = true,
        UIPadding = true,
        UICorner = true,
        UIGradient = true,
        UIScale = true,
        UIAspectRatioConstraint = true,
        UISizeConstraint = true,
        UITextSizeConstraint = true,
    }

    local mainVisible = true
    local isAnimating = false
    local lastToggleTime = 0
    local currentFadeTweens = {}
    local originalTransparencies = {}
    local eventConnections = {}

    local ToggleSG = Instance.new("ScreenGui")
    ToggleSG.ResetOnSpawn = false
    ToggleSG.IgnoreGuiInset = true
    ToggleSG.DisplayOrder = 9999999999
    ToggleSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SecureGui(ToggleSG)

    ToggleFrame = Instance.new("TextButton")
    ToggleFrame.Size = UDim2.new(0, 90, 0, 34)
    ToggleFrame.Position = initLayout.togglePos
    ToggleFrame.BackgroundColor3 = RX.Accent1
    ToggleFrame.BackgroundTransparency = RX.MainAlpha
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.Active = true
    ToggleFrame.Text = ""
    ToggleFrame.ZIndex = 10
    ToggleFrame.Parent = ToggleSG

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 16)
    tCorner.Parent = ToggleFrame

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

    table.insert(
        eventConnections,
        ToggleFrame.Destroying:Connect(function()
            unregisterStrokeTarget(tStrokeGrad)
        end)
    )

    local tInnerGrad = Instance.new("UIGradient")
    tInnerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 28)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 14, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 18)),
    })
    tInnerGrad.Rotation = 180
    tInnerGrad.Parent = ToggleFrame

    local tGlass = Instance.new("Frame")
    tGlass.Size = UDim2.new(1, 0, 0.5, 0)
    tGlass.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tGlass.BackgroundTransparency = 0.96
    tGlass.BorderSizePixel = 0
    tGlass.ZIndex = 11
    tGlass.Parent = ToggleFrame

    local tGlassCorner = Instance.new("UICorner")
    tGlassCorner.CornerRadius = UDim.new(0, 12)
    tGlassCorner.Parent = tGlass

    local tGlassGrad = Instance.new("UIGradient")
    tGlassGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.88),
        NumberSequenceKeypoint.new(0.5, 0.96),
        NumberSequenceKeypoint.new(1, 1),
    })
    tGlassGrad.Rotation = 90
    tGlassGrad.Parent = tGlass

    local tAccentBar = Instance.new("Frame")
    tAccentBar.Size = UDim2.new(0, 3, 0, 16)
    tAccentBar.Position = UDim2.new(0, 8, 0.5, 0)
    tAccentBar.AnchorPoint = Vector2.new(0, 0.5)
    tAccentBar.BackgroundColor3 = RX.Accent1
    tAccentBar.BorderSizePixel = 0
    tAccentBar.ZIndex = 13
    tAccentBar.Parent = ToggleFrame

    local tAccentCorner = Instance.new("UICorner")
    tAccentCorner.CornerRadius = UDim.new(1, 0)
    tAccentCorner.Parent = tAccentBar

    local ToggleIcon = Instance.new("ImageLabel")
    ToggleIcon.Size = UDim2.new(0, 24, 0, 24)
    ToggleIcon.Position = UDim2.new(0, 12, 0.5, 0)
    ToggleIcon.AnchorPoint = Vector2.new(0, 0.5)
    ToggleIcon.BackgroundTransparency = 1
    ToggleIcon.Image = "rbxassetid://89557898457977"
    ToggleIcon.ImageColor3 = RX.T1
    ToggleIcon.ZIndex = 13
    ToggleIcon.Parent = ToggleFrame

    local tDivider = Instance.new("Frame")
    tDivider.Size = UDim2.new(0, 1, 0, 20)
    tDivider.Position = UDim2.new(0, 38, 0.5, 0)
    tDivider.AnchorPoint = Vector2.new(0, 0.5)
    tDivider.BackgroundColor3 = RX.Accent1
    tDivider.BackgroundTransparency = 0.6
    tDivider.BorderSizePixel = 0
    tDivider.ZIndex = 13
    tDivider.Parent = ToggleFrame

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

    if not isMobile then
        table.insert(
            eventConnections,
            ToggleFrame.MouseEnter:Connect(function()
                TweenService:Create(ToggleFrame, TWEEN_FAST, {
                    BackgroundTransparency = math.max(RX.MainAlpha - 0.05, 0),
                }):Play()
                TweenService:Create(tStroke, TWEEN_FAST, { Transparency = 0.3 }):Play()
                TweenService:Create(ToggleIcon, TWEEN_FAST, { ImageColor3 = RX.Cyan }):Play()
            end)
        )
        table.insert(
            eventConnections,
            ToggleFrame.MouseLeave:Connect(function()
                TweenService:Create(ToggleFrame, TWEEN_FAST, { BackgroundTransparency = RX.MainAlpha }):Play()
                TweenService:Create(tStroke, TWEEN_FAST, { Transparency = 0.5 }):Play()
                TweenService:Create(ToggleIcon, TWEEN_FAST, { ImageColor3 = RX.T1 }):Play()
            end)
        )
    end

    makeDraggable(ToggleFrame)

    -- Accent bar tweens with cancel safety
    local currentAccentTween = nil

    local function playAccentTween(color)
        if currentAccentTween then
            currentAccentTween:Cancel()
        end
        currentAccentTween = TweenService:Create(tAccentBar, TWEEN_NORMAL, { BackgroundColor3 = color })
        currentAccentTween:Play()
    end

    -- Fade cache helpers

    local function cacheObj(obj, forToggle)
        if not obj or not obj.Parent then
            return
        end
        if isFadeExempt(obj, forToggle) then
            return
        end
        local className = obj.ClassName
        if not className or EXCLUDED_CLASSES[className] then
            return
        end
        local propList = TRANSPARENCY_PROPS[className]
        if not propList then
            return
        end
        local cached = {}
        for _, propName in ipairs(propList) do
            local val = obj[propName]
            if val ~= nil then
                if propName ~= "ScrollBarImageTransparency" then
                    if val < 1 then
                        cached[propName] = val
                    end
                else
                    cached[propName] = val
                end
            end
        end
        if next(cached) then
            originalTransparencies[obj] = cached
        end
    end

    local function cacheDescendants(root, forToggle)
        for _, child in ipairs(root:GetChildren()) do
            if not isFadeExempt(child, forToggle) and not EXCLUDED_CLASSES[child.ClassName] then
                cacheObj(child, forToggle)
                cacheDescendants(child, forToggle)
            end
        end
    end

    local function cacheOriginalValues()
        originalTransparencies = {}
        if MainFrame and MainFrame.Parent then
            cacheObj(MainFrame, true)
            cacheDescendants(MainFrame, true)
        end
    end

    local function cancelAllFadeTweens()
        for _, tw in ipairs(currentFadeTweens) do
            pcall(function()
                tw:Cancel()
            end)
        end
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
                if next(tp) then
                    table.insert(tweenList, TweenService:Create(obj, tweenI, tp))
                end
            end
        end

        currentFadeTweens = tweenList

        if #tweenList == 0 then
            setAllInstant(targetAlpha)
            if callback then
                task.spawn(callback)
            end
            return
        end

        local activeTweens = #tweenList
        local callbackCalled = false

        local function finishFade()
            if callbackCalled then
                return
            end
            callbackCalled = true
            setAllInstant(targetAlpha)
            if callback then
                task.spawn(callback)
            end
        end

        for _, tw in ipairs(tweenList) do
            local conn
            conn = tw.Completed:Connect(function()
                if conn then
                    conn:Disconnect()
                    conn = nil
                end
                activeTweens = activeTweens - 1
                if activeTweens <= 0 then
                    finishFade()
                end
            end)
            tw:Play()
        end
    end

    -- Toggle logic
    local function toggleGUI()
        local now = tick()
        if now - lastToggleTime < TOGGLE_DEBOUNCE then
            return
        end
        lastToggleTime = now
        if isAnimating then
            return
        end

        isAnimating = true
        mainVisible = not mainVisible

        if mainVisible then
            if MainFrame then
                MainFrame.Visible = true
            end
            ToggleText.Text = "HIDE"
            playAccentTween(RX.Accent1)
            StartPingCounter()
            StartFPSCounter()
            fadeAllTo(0, FADE_DURATION, function()
                isAnimating = false
            end)
        else
            cacheOriginalValues()
            ToggleText.Text = "OPEN"
            playAccentTween(RX.Red)
            StopPingCounter()
            StopFPSCounter()
            fadeAllTo(1, FADE_DURATION, function()
                if not mainVisible then
                    if MainFrame then
                        MainFrame.Visible = false
                    end
                end
                isAnimating = false
            end)
        end
    end

    table.insert(eventConnections, ToggleFrame.Activated:Connect(toggleGUI))

    local function cleanupAll()
        cancelAllFadeTweens()
        for _, conn in ipairs(eventConnections) do
            conn:Disconnect()
        end
        eventConnections = {}
        originalTransparencies = {}
    end

    table.insert(eventConnections, ToggleSG.Destroying:Connect(cleanupAll))

    -- RESIZE BUTTON

    local resizeButton = Instance.new("TextButton")
    resizeButton.Position = UDim2.new(1, -119, 0.5, 0)
    resizeButton.AnchorPoint = Vector2.new(0, 0.5)
    resizeButton.Size = UDim2.new(0, 55, 0, 20)
    resizeButton.BackgroundColor3 = RX.Accent1
    resizeButton.BackgroundTransparency = 0.8
    resizeButton.Text = "RESIZE UI"
    resizeButton.Font = RX.F1
    resizeButton.TextSize = 9
    resizeButton.TextColor3 = RX.T1
    resizeButton.AutoButtonColor = false
    resizeButton.BorderSizePixel = 0
    resizeButton.ZIndex = 11
    resizeButton.Parent = ExtraFrame

    local resizeCorner = Instance.new("UICorner")
    resizeCorner.CornerRadius = UDim.new(0, 5)
    resizeCorner.Parent = resizeButton

    local resizeStroke = Instance.new("UIStroke")
    resizeStroke.Thickness = 1
    resizeStroke.Color = RX.Accent1
    resizeStroke.Transparency = 0.4
    resizeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    resizeStroke.Parent = resizeButton

    if not isMobile then
        resizeButton.MouseEnter:Connect(function()
            TweenService:Create(resizeButton, TWEEN_FAST, { BackgroundTransparency = 0.35 }):Play()
        end)
        resizeButton.MouseLeave:Connect(function()
            TweenService:Create(resizeButton, TWEEN_FAST, { BackgroundTransparency = 0.6 }):Play()
        end)
    end

    local resizeDebounce = false
    local function resizeHandler()
        if resizeDebounce then
            return
        end
        resizeDebounce = true

        TweenService:Create(resizeButton, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            BackgroundColor3 = Color3.fromRGB(180, 130, 255),
            BackgroundTransparency = 0.1,
        }):Play()
        TweenService:Create(resizeStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Color = Color3.fromRGB(200, 160, 255),
            Transparency = 0,
        }):Play()

        task.delay(0.22, function()
            if not (resizeButton and resizeButton.Parent) then
                return
            end
            TweenService
                :Create(resizeButton, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    BackgroundColor3 = RX.Accent2,
                    BackgroundTransparency = 0.8,
                })
                :Play()
            TweenService
                :Create(resizeStroke, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Color = RX.Accent2,
                    Transparency = 0.3,
                })
                :Play()
            task.delay(0.20, function()
                openResizeGUI({
                    MainFrame = MainFrame,
                    ExtraFrame = ExtraFrame,
                    ToggleFrame = ToggleFrame,
                    ContentWrapper = ContentWrapper,
                    ShadowFrame = ShadowFrame,
                    TabShadowFrame = TabShadowFrame,
                    TabRailClip = TabRailClip,
                    MainGui = MainGui,
                })
            end)
        end)

        task.delay(1.2, function()
            resizeDebounce = false
        end)
    end

    resizeButton.Activated:Connect(resizeHandler)

    -- DISCORD BUTTON

    if discordEnabled then
        local discordButton = Instance.new("TextButton")
        discordButton.Position = UDim2.new(1, -59, 0.5, 0)
        discordButton.AnchorPoint = Vector2.new(0, 0.5)
        discordButton.Size = UDim2.new(0, 55, 0, 20)
        discordButton.BackgroundColor3 = RX.Accent1
        discordButton.BackgroundTransparency = 0.8
        discordButton.Text = "DISCORD"
        discordButton.Font = RX.F1
        discordButton.TextSize = 9
        discordButton.TextColor3 = RX.T1
        discordButton.AutoButtonColor = false
        discordButton.BorderSizePixel = 0
        discordButton.ZIndex = 11
        discordButton.Parent = ExtraFrame

        local discordCorner = Instance.new("UICorner")
        discordCorner.CornerRadius = UDim.new(0, 5)
        discordCorner.Parent = discordButton

        local discordStroke = Instance.new("UIStroke")
        discordStroke.Thickness = 1
        discordStroke.Color = RX.Accent1
        discordStroke.Transparency = 0.4
        discordStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        discordStroke.Parent = discordButton

        if not isMobile then
            discordButton.MouseEnter:Connect(function()
                TweenService:Create(discordButton, TWEEN_FAST, { BackgroundTransparency = 0.35 }):Play()
            end)
            discordButton.MouseLeave:Connect(function()
                TweenService:Create(discordButton, TWEEN_FAST, { BackgroundTransparency = 0.6 }):Play()
            end)
        end

        local discordClicking = false
        local function discordHandler()
            if discordClicking then
                return
            end
            discordClicking = true

            TweenService
                :Create(discordButton, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Color3.fromRGB(180, 130, 255),
                    BackgroundTransparency = 0.1,
                })
                :Play()
            TweenService
                :Create(discordStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Color = Color3.fromRGB(200, 160, 255),
                    Transparency = 0,
                })
                :Play()

            task.delay(0.22, function()
                if not (discordButton and discordButton.Parent) then
                    return
                end
                TweenService
                    :Create(discordButton, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = RX.Accent1,
                        BackgroundTransparency = 0.8,
                    })
                    :Play()
                TweenService
                    :Create(discordStroke, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Color = RX.Accent1,
                        Transparency = 0.3,
                    })
                    :Play()

                task.delay(0.20, function()
                    local copied = false
                    if EXECUTOR_APIS.setclipboard then
                        pcall(function()
                            setclipboard(discordLink)
                            copied = true
                        end)
                    end
                    if not copied and EXECUTOR_APIS.toclipboard then
                        pcall(function()
                            toclipboard(discordLink)
                            copied = true
                        end)
                    end

                    if discordButton and discordButton.Parent then
                        discordButton.Text = copied and "COPIED!" or "DISCORD"
                    end
                    if copied then
                        ShowNotification({ title = "Discord", body = "Invitation link copied!", duration = 3 })
                    end

                    task.delay(1.5, function()
                        if discordButton and discordButton.Parent then
                            discordButton.Text = "DISCORD"
                            TweenService:Create(discordButton, TweenInfo.new(0.25), {
                                BackgroundColor3 = RX.Accent1,
                                BackgroundTransparency = 0.8,
                            }):Play()
                        end
                    end)
                end)
            end)

            task.delay(2, function()
                discordClicking = false
            end)
        end

        discordButton.Activated:Connect(discordHandler)
    end

    -- PRIVATE REFS

    _FLYCER_PRIVATE.MainFrame = MainFrame
    _FLYCER_PRIVATE.Refs = {
        GUI = MainGui,
        MainFrame = MainFrame,
        ExtraFrame = ExtraFrame,
        ContentWrapper = ContentWrapper,
        ShadowFrame = ShadowFrame,
        TabShadowFrame = TabShadowFrame,
        Platform = { isMobile = isMobile, isPC = isPC },
        AddTab = addTab,
        ActivateTab = activateTab,
    }

    -- COMPONENT FACTORY

    local function makeComponents(canvas)
        local Components = {}

        local function makeBaseCard(layoutOrder, height)
            local f = Instance.new("Frame")
            f.Name = randomName()
            f.Size = UDim2.new(1, 0, 0, height or 34)
            f.BackgroundColor3 = RX.Card
            f.BackgroundTransparency = RX.CardAlpha
            f.BorderSizePixel = 0
            f.LayoutOrder = layoutOrder or 99
            f.Parent = canvas

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = f

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Thickness = 1
            cardStroke.Color = RX.Border
            cardStroke.Transparency = 0.6
            cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            cardStroke.Parent = f
            return f
        end

        function Components:CreateLabel(text, layoutOrder)
            local f = makeBaseCard(layoutOrder, 24)
            f.BackgroundColor3 = RX.Bg3

            local lb = Instance.new("Frame")
            lb.Size = UDim2.new(0, 3, 0.5, 0)
            lb.Position = UDim2.new(0, 6, 0.5, 0)
            lb.AnchorPoint = Vector2.new(0, 0.5)
            lb.BackgroundColor3 = RX.Accent1
            lb.BorderSizePixel = 0
            lb.Parent = f

            local lbc = Instance.new("UICorner")
            lbc.CornerRadius = UDim.new(1, 0)
            lbc.Parent = lb

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -22, 1, 0)
            lbl.Position = UDim2.new(0, 16, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = RX.T2
            lbl.Font = RX.F1
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = f

            return {
                Frame = f,
                SetText = function(newText)
                    lbl.Text = newText
                end,
                Destroy = function()
                    if f and f.Parent then
                        f:Destroy()
                    end
                end,
            }
        end

        function Components:CreateSection(cfg, layoutOrder)
            local title, order

            if type(cfg) == "table" then
                title = cfg.Title or cfg.title or "Section"
                order = cfg.LayoutOrder or cfg.layoutOrder or 50
            else
                title = tostring(cfg or "Section")
                order = layoutOrder or 50
            end

            local container = Instance.new("Frame")
            container.Name = randomName()
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

            local lg = Instance.new("UIGradient")
            lg.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.6, 0.4),
                NumberSequenceKeypoint.new(1, 1),
            })
            lg.Parent = accentLine

            return {
                Frame = container,
                SetTitle = function(newTitle)
                    label.Text = string.upper(newTitle)
                end,
                Destroy = function()
                    if container and container.Parent then
                        container:Destroy()
                    end
                end,
            }
        end

        function Components:CreateButton(cfg)
            cfg = cfg or {}

            local title = cfg.Name or cfg.Title or cfg.title or cfg.Label or cfg.label or "Button"
            local layoutOrder = cfg.LayoutOrder or cfg.layoutOrder or 99
            local lockedState = cfg.Locked == true or cfg.locked == true
            local debounceTime = tonumber(cfg.Debounce or cfg.debounce) or 0.3
            local callback = cfg.Callback or cfg.callback or cfg.onClick

            local frame = makeBaseCard(layoutOrder, 36)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(1, -80, 1, 0)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
            titleLbl.Parent = frame

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 60, 0, 24)
            btn.Position = UDim2.new(1, -70, 0.5, 0)
            btn.AnchorPoint = Vector2.new(0, 0.5)
            btn.BackgroundColor3 = RX.Accent1
            btn.BackgroundTransparency = 0.15
            btn.Text = "RUN"
            btn.Font = RX.F1
            btn.TextSize = 10
            btn.TextColor3 = RX.T1
            btn.AutoButtonColor = false
            btn.BorderSizePixel = 0
            btn.Parent = frame

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 7)
            btnCorner.Parent = btn

            local btnGrad = Instance.new("UIGradient")
            btnGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, RX.Accent1),
                ColorSequenceKeypoint.new(1, RX.Accent2),
            })
            btnGrad.Rotation = 90
            btnGrad.Parent = btn

            local btnStroke = Instance.new("UIStroke")
            btnStroke.Thickness = 1
            btnStroke.Color = RX.Accent1
            btnStroke.Transparency = 0.5
            btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            btnStroke.Parent = btn

            local locked = lockedState
            local isDebounced = false

            local function updateLockedVisuals(instant)
                local ti = instant and TweenInfo.new(0) or TWEEN_FAST
                TweenService:Create(titleLbl, ti, { TextTransparency = locked and 0.35 or 0 }):Play()
                TweenService:Create(btn, ti, {
                    BackgroundTransparency = locked and 0.5 or 0.15,
                    TextTransparency = locked and 0.35 or 0,
                }):Play()
            end

            updateLockedVisuals(true)

            btn.Activated:Connect(function()
                if locked or isDebounced then
                    return
                end
                isDebounced = true
                TweenService:Create(btn, TWEEN_FAST, { BackgroundTransparency = 0 }):Play()
                task.delay(0.15, function()
                    if btn and btn.Parent then
                        TweenService:Create(btn, TWEEN_FAST, { BackgroundTransparency = 0.15 }):Play()
                    end
                end)
                if typeof(callback) == "function" then
                    task.spawn(callback)
                end
                task.delay(debounceTime, function()
                    isDebounced = false
                end)
            end)

            if not isMobile then
                btn.MouseEnter:Connect(function()
                    if not locked then
                        TweenService:Create(btn, TWEEN_FAST, { BackgroundTransparency = 0 }):Play()
                        TweenService:Create(btnStroke, TWEEN_FAST, { Transparency = 0.2 }):Play()
                    end
                end)
                btn.MouseLeave:Connect(function()
                    if not locked then
                        TweenService:Create(btn, TWEEN_FAST, { BackgroundTransparency = 0.15 }):Play()
                        TweenService:Create(btnStroke, TWEEN_FAST, { Transparency = 0.5 }):Play()
                    end
                end)
            end

            return {
                Frame = frame,
                Button = btn,
                SetCallback = function(fn)
                    callback = fn
                end,
                SetLocked = function(v)
                    locked = v == true
                    updateLockedVisuals(false)
                end,
                GetLocked = function()
                    return locked
                end,
                SetTitle = function(newTitle)
                    titleLbl.Text = newTitle
                end,
                Destroy = function()
                    if frame and frame.Parent then
                        frame:Destroy()
                    end
                end,
            }
        end

        function Components:CreateToggle(cfg)
            cfg = cfg or {}

            local title = cfg.Name or cfg.Title or cfg.title or cfg.Label or cfg.label or "Toggle"
            local layoutOrder = cfg.LayoutOrder or cfg.layoutOrder or 99
            local defaultState = cfg.CurrentValue == true or cfg.Default == true or cfg.default == true
            local lockedState = cfg.Locked == true or cfg.locked == true
            local debounceTime = tonumber(cfg.Debounce or cfg.debounce) or 0.3
            local flag = cfg.Flag or cfg.flag
            local callback = cfg.Callback or cfg.callback or cfg.onToggle

            local frame = makeBaseCard(layoutOrder, 34)

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(1, -74, 1, 0)
            titleLbl.Position = UDim2.new(0, 10, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.Font = RX.F1
            titleLbl.TextSize = 10
            titleLbl.TextColor3 = RX.T1
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
            titleLbl.Parent = frame

            local track = Instance.new("Frame")
            track.Size = UDim2.new(0, 44, 0, 22)
            track.Position = UDim2.new(1, -53, 0.5, 0)
            track.AnchorPoint = Vector2.new(0, 0.5)
            track.BackgroundColor3 = Color3.fromRGB(38, 38, 55)
            track.BorderSizePixel = 0
            track.Parent = frame

            local trackCorner = Instance.new("UICorner")
            trackCorner.CornerRadius = UDim.new(1, 0)
            trackCorner.Parent = track

            local trackStroke = Instance.new("UIStroke")
            trackStroke.Thickness = 1
            trackStroke.Color = RX.Border
            trackStroke.Transparency = 1
            trackStroke.Parent = track

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 18, 0, 18)
            knob.Position = UDim2.new(0, 2, 0.5, 0)
            knob.AnchorPoint = Vector2.new(0, 0.5)
            knob.BackgroundColor3 = Color3.fromRGB(150, 150, 170)
            knob.Parent = track

            local knobCorner = Instance.new("UICorner")
            knobCorner.CornerRadius = UDim.new(1, 0)
            knobCorner.Parent = knob

            local knobGlow = Instance.new("Frame")
            knobGlow.Size = UDim2.new(0.5, 0, 0.5, 0)
            knobGlow.Position = UDim2.new(0.25, 0, 0.25, 0)
            knobGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knobGlow.BackgroundTransparency = 1
            knobGlow.BorderSizePixel = 0
            knobGlow.ZIndex = knob.ZIndex + 1
            knobGlow.Parent = knob

            local knobGlowCorner = Instance.new("UICorner")
            knobGlowCorner.CornerRadius = UDim.new(1, 0)
            knobGlowCorner.Parent = knobGlow

            local toggleBtn = Instance.new("TextButton")
            toggleBtn.Size = UDim2.new(1, 0, 1, 0)
            toggleBtn.BackgroundTransparency = 1
            toggleBtn.Text = ""
            toggleBtn.AutoButtonColor = false
            toggleBtn.ZIndex = track.ZIndex + 2
            toggleBtn.Parent = track

            local state = defaultState
            local locked = lockedState
            local isDebounced = false

            local knobOff = UDim2.new(0, 2, 0.5, 0)
            local knobOn = UDim2.new(0, 24, 0.5, 0)

            local function updateToggle(enabled, instant)
                local ti = instant and TweenInfo.new(0)
                    or TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

                TweenService:Create(knob, ti, {
                    Position = enabled and knobOn or knobOff,
                    BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255)
                        or Color3.fromRGB(150, 150, 170),
                }):Play()
                TweenService:Create(knobGlow, TWEEN_FAST, {
                    BackgroundTransparency = enabled and 0.4 or 1,
                }):Play()
                TweenService:Create(track, TWEEN_NORMAL, {
                    BackgroundColor3 = enabled and RX.Accent1 or Color3.fromRGB(38, 38, 55),
                }):Play()
                TweenService:Create(trackStroke, TWEEN_NORMAL, {
                    Color = enabled and RX.Accent1 or RX.Border,
                }):Play()
            end

            local function updateLockedVisuals(instant)
                local ti = instant and TweenInfo.new(0) or TWEEN_FAST
                TweenService:Create(titleLbl, ti, { TextTransparency = locked and 0.35 or 0 }):Play()
                TweenService:Create(track, ti, { BackgroundTransparency = locked and 0.35 or 0 }):Play()
                TweenService:Create(knob, ti, { BackgroundTransparency = locked and 0.2 or 0 }):Play()
            end

            local function fireCallback()
                if typeof(callback) == "function" then
                    task.spawn(function()
                        callback(state)
                    end)
                end
            end

            updateToggle(state, true)
            updateLockedVisuals(true)

            toggleBtn.Activated:Connect(function()
                if locked or isDebounced then
                    return
                end
                isDebounced = true
                state = not state
                updateToggle(state, false)
                fireCallback()
                task.delay(debounceTime, function()
                    isDebounced = false
                end)
            end)

            return {
                Frame = frame,
                Button = toggleBtn,
                SetState = function(v, shouldCallback)
                    state = v == true
                    updateToggle(state, false)
                    if shouldCallback == true then
                        fireCallback()
                    end
                end,
                GetState = function()
                    return state
                end,
                SetLocked = function(v)
                    locked = v == true
                    updateLockedVisuals(false)
                end,
                GetLocked = function()
                    return locked
                end,
                SetCallback = function(fn)
                    callback = fn
                end,
                Destroy = function()
                    if frame and frame.Parent then
                        frame:Destroy()
                    end
                end,
            }
        end

        return Components
    end

    -- INITIAL SYNC

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
        _lastVP = Camera.ViewportSize
        task.wait(0.1)
        cacheOriginalValues()
    end)

    -- Start counters
    StartPingCounter()
    StartFPSCounter()

    -- SETTINGS TAB (built-in)

    local settingsCanvas, _settingsL = addTab("Settings", 999)
    local SettingsC = makeComponents(settingsCanvas)

    -- Ping/FPS positioning
    local PING_POS_BOTH_ON = UDim2.new(1, -156, 0.5, 0)
    local FPS_POS_BOTH_ON = UDim2.new(1, -71, 0.5, 0)
    local PING_POS_SOLO = UDim2.new(1, -86, 0.5, 0)
    local FPS_POS_SOLO = UDim2.new(1, -71, 0.5, 0)

    local pingEnabled = true
    local fpsEnabled = true

    local function updateCounterPositions()
        if pingEnabled and fpsEnabled then
            TweenService:Create(pingContainer, TWEEN_FAST, { Position = PING_POS_BOTH_ON }):Play()
            TweenService:Create(fpsContainer, TWEEN_FAST, { Position = FPS_POS_BOTH_ON }):Play()
        elseif pingEnabled and not fpsEnabled then
            TweenService:Create(pingContainer, TWEEN_FAST, { Position = PING_POS_SOLO }):Play()
        elseif not pingEnabled and fpsEnabled then
            TweenService:Create(fpsContainer, TWEEN_FAST, { Position = FPS_POS_SOLO }):Play()
        end
    end

    local function setPingEnabled(enabled)
        pingEnabled = enabled
        if enabled then
            pingContainer.Visible = true
            StartPingCounter()
        else
            StopPingCounter()
            pingContainer.Visible = false
        end
        updateCounterPositions()
    end

    local function setFPSEnabled(enabled)
        fpsEnabled = enabled
        if enabled then
            fpsContainer.Visible = true
            StartFPSCounter()
        else
            StopFPSCounter()
            fpsContainer.Visible = false
        end
        updateCounterPositions()
    end

    SettingsC:CreateLabel("Show PING & FPS", 1)

    SettingsC:CreateToggle({
        Name = "Show Ping Counter",
        LayoutOrder = 2,
        CurrentValue = true,
        Callback = setPingEnabled,
    })

    SettingsC:CreateToggle({
        Name = "Show FPS Counter",
        LayoutOrder = 3,
        CurrentValue = true,
        Callback = setFPSEnabled,
    })

    SettingsC:CreateSection("UI Position Control", 4)

    SettingsC:CreateToggle({
        Name = "Lock UI Position",
        LayoutOrder = 5,
        CurrentValue = false,
        Debounce = 2.5,
        Callback = setUILock,
    })

    -- WINDOW OBJECT (returned to user)

    local Window = {}

    function Window:CreateTab(name, layoutOrder)
        local tabCanvas, tabLayout = addTab(name, layoutOrder)
        local TabObj = makeComponents(tabCanvas)

        -- Auto-activate first user tab
        if not activeTabName then
            activateTab(name)
        end

        return TabObj
    end

    function Window:Notify(cfg)
        ShowNotification(cfg or {})
    end

    function Window:Destroy()
        cleanupAll()
        if MainGui and MainGui.Parent then
            MainGui:Destroy()
        end
        if ToggleSG and ToggleSG.Parent then
            ToggleSG:Destroy()
        end
    end

    -- Auto-activate first tab if none active
    task.defer(function()
        if not activeTabName and firstTabName then
            activateTab(firstTabName)
        end
    end)

    return Window
end

-- GLOBAL API

if getgenv then
    getgenv()._FlycerUI = {
        GetRefs = function()
            return _FLYCER_PRIVATE.Refs
        end,
        GetFrame = function()
            return _FLYCER_PRIVATE.MainFrame
        end,
        Notify = function(c)
            ShowNotification(c)
        end,
    }
end

return FlycerLib
