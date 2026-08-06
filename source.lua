--[[
    FlycerUI Library - Ultimate Patch
    Version: 2.0.0
    
    Features:
    - Multi-stage Loading Sequence (Rayfield Style)
    - Reveal Animation System (Smooth Fade-in)
    - Staggered UI Initial Sync
    - All Original Components (Toggle, Button, Label, Section)
    - Built-in Settings (Ping, FPS, UI Lock)
    - Discord & Resize Integration
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

-- ═══════════════════════════════════════════════════════════
-- TRANSPARENCY & EXCLUDED CLASSES DEFINITIONS
-- ═══════════════════════════════════════════════════════════

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

-- UTILITIES (Viewports, Centers, Names)

local Camera = workspace.CurrentCamera
local function getViewportSafe()
	if not Camera then
		Camera = workspace.CurrentCamera
	end
	local vp = Camera.ViewportSize
	return (vp.X < 10 or vp.Y < 10) and Vector2.new(1280, 720) or vp
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

local CHARSET = {}
for i = 33, 126 do
	CHARSET[#CHARSET + 1] = string.char(i)
end
local function randomName(len)
	len = len or math.random(15, 25)
	local buf = table.create(len)
	for i = 1, len do
		buf[i] = CHARSET[math.random(1, #CHARSET)]
	end
	return table.concat(buf)
end

-- SEALED PRIVATE
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
		if ok and r then
			table.insert(list, r)
		end
	end
	return list
end

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

-- STROKE ROTATION Pooling
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

-- CORE UTILS
local function makeSeparator(parentFrame, posY_offset, useScale, scaleY)
	local sep = Instance.new("Frame")
	sep.Name = "Separator"
	sep.Size = UDim2.new(1, -10, 0, 0)
	sep.Position = useScale and UDim2.new(0, 5, scaleY or 1, posY_offset or 0) or UDim2.new(0, 5, 0, posY_offset or 0)
	sep.BackgroundTransparency = 1
	sep.BorderSizePixel = 0
	sep.ZIndex = 10
	sep:SetAttribute("FlycerTag", true)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = sep
	local sg = Instance.new("UIGradient")
	sg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RX.Accent1),
		ColorSequenceKeypoint.new(0.45, RX.Accent2),
		ColorSequenceKeypoint.new(0.5, RX.Cyan),
		ColorSequenceKeypoint.new(0.55, RX.Accent2),
		ColorSequenceKeypoint.new(1, RX.Accent1),
	})
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(1, 0.55),
	})
	sg.Parent = stroke
	sep.Parent = parentFrame
	return sep
end

local function makeDraggable(dragHandle, dragTarget)
	dragTarget = dragTarget or dragHandle
	local dragging, dragStart, startPos = false
	dragHandle.InputBegan:Connect(function(input)
		if
			(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and not isUILocked
		then
			dragging = true
			dragStart = input.Position
			startPos = dragTarget.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local delta = input.Position - dragStart
			TweenService:Create(dragTarget, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				),
			}):Play()
		end
	end)
end

-- NOTIFICATION
local _notifScreen, _notifQueue, _notifRunning, _notifActive = nil, {}, false, false
local function getNotifScreenSafe()
	if _notifScreen and _notifScreen.Parent then
		return _notifScreen
	end
	local sg = Instance.new("ScreenGui")
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 9999999999
	sg.IgnoreGuiInset = true
	sg:SetAttribute(FLYCER_TAG_ATTR, true)
	SecureGui(sg)
	_notifScreen = sg
	return sg
end

local function buildNotifFrame(parent, cfg)
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, NOTIF_WIDTH, 0, NOTIF_HEIGHT)
	mainFrame.Position = UDim2.new(1, NOTIF_WIDTH + 20, 1, -(NOTIF_HEIGHT + NOTIF_POS_Y))
	mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	mainFrame.BackgroundTransparency = 0.15
	mainFrame.ZIndex = 2
	mainFrame.Parent = parent
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, NOTIF_CORNER_RADIUS)
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = Color3.fromRGB(38, 38, 50)
	outerStroke.Thickness = 1
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = mainFrame

	local shimmerClip = Instance.new("Frame")
	shimmerClip.Size = UDim2.new(1, 0, 1, 0)
	shimmerClip.BackgroundTransparency = 1
	shimmerClip.ClipsDescendants = true
	shimmerClip.Parent = mainFrame
	Instance.new("UICorner", shimmerClip).CornerRadius = UDim.new(0, NOTIF_CORNER_RADIUS)
	local shimmer = Instance.new("Frame")
	shimmer.Size = UDim2.new(0, NOTIF_WIDTH * 0.3, 1, 0)
	shimmer.Position = UDim2.new(-0.35, 0, 0, 0)
	shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shimmer.BackgroundTransparency = 0.97
	shimmer.ZIndex = 4
	shimmer.Parent = shimmerClip
	Instance.new("UIGradient", shimmer).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})

	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(0, NOTIF_ICON_SIZE, 0, NOTIF_ICON_SIZE)
	iconFrame.Position = UDim2.new(0, NOTIF_POS_X, 0.5, 0)
	iconFrame.AnchorPoint = Vector2.new(0, 0.5)
	iconFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
	iconFrame.Parent = mainFrame
	Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 8)
	local iconImage = Instance.new("ImageLabel")
	iconImage.Size = UDim2.new(0.68, 0, 0.68, 0)
	iconImage.Position = UDim2.new(0.16, 0, 0.16, 0)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = "rbxassetid://89557898457977"
	iconImage.Parent = iconFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -70, 0, 15)
	titleLabel.Position = UDim2.new(0, 65, 0, 13)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = cfg.title
	titleLabel.TextColor3 = Color3.fromRGB(225, 215, 255)
	titleLabel.TextSize = NOTIF_TITLE_SIZE
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = mainFrame
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Size = UDim2.new(1, -70, 0, 12)
	bodyLabel.Position = UDim2.new(0, 65, 0, 30)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Text = cfg.body
	bodyLabel.TextColor3 = Color3.fromRGB(110, 105, 135)
	bodyLabel.TextSize = NOTIF_BODY_SIZE
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.Parent = mainFrame

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(1, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
	progressFill.ZIndex = 10
	local pBar = Instance.new("Frame")
	pBar.Size = UDim2.new(1, -(NOTIF_CORNER_RADIUS * 2), 0, NOTIF_PROGRESS_HEIGHT)
	pBar.Position = UDim2.new(0, NOTIF_CORNER_RADIUS, 1, -(NOTIF_PROGRESS_HEIGHT + 3))
	pBar.BackgroundColor3 = Color3.fromRGB(30, 28, 42)
	pBar.Parent = mainFrame
	progressFill.Parent = pBar
	Instance.new("UICorner", pBar).CornerRadius = UDim.new(1, 0)
	Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

	return mainFrame, progressFill, shimmer
end

local function ShowNotification(cfg)
	cfg = {
		title = cfg.title or cfg.Title or "Flycer",
		body = cfg.body or cfg.Body or cfg.Description or cfg.Content or "",
		duration = cfg.duration or cfg.Duration or 5,
		onComplete = cfg.onComplete or cfg.OnComplete,
	}
	table.insert(_notifQueue, cfg)
	if _notifRunning then
		return
	end
	_notifRunning = true
	task.spawn(function()
		while #_notifQueue > 0 do
			local c = table.remove(_notifQueue, 1)
			_notifActive = true
			local screen = getNotifScreenSafe()
			local frame, fill, shim = buildNotifFrame(screen, c)
			local targetPos = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_POS_X), 1, -(NOTIF_HEIGHT + NOTIF_POS_Y))
			TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Position = targetPos }):Play()
			task.spawn(function()
				while shim and shim.Parent do
					shim.Position = UDim2.new(-0.35, 0, 0, 0)
					TweenService
						:Create(
							shim,
							TweenInfo.new(1.5, Enum.EasingStyle.Linear),
							{ Position = UDim2.new(1.2, 0, 0, 0) }
						)
						:Play()
					task.wait(3.2)
				end
			end)
			TweenService
				:Create(fill, TweenInfo.new(c.duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })
				:Play()
			task.wait(c.duration)
			TweenService:Create(
				frame,
				TweenInfo.new(0.38, Enum.EasingStyle.Quint),
				{ Position = UDim2.new(1, NOTIF_WIDTH + 20, 1, -(NOTIF_HEIGHT + NOTIF_POS_Y)) }
			):Play()
			task.wait(0.4)
			frame:Destroy()
			_notifActive = false
			if typeof(c.onComplete) == "function" then
				task.spawn(c.onComplete)
			end
		end
		_notifRunning = false
	end)
end

-- RESIZE INPUT (Reusable)
local function makeInputField(parentFrame, anchorX, labelTxt, defaultVal)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, RESIZE_FIELD_WIDTH, 0, 56)
	container.Position = UDim2.new(0, anchorX, 0, 48)
	container.BackgroundTransparency = 1
	container.Parent = parentFrame
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 16)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelTxt
	lbl.TextColor3 = RX.T2
	lbl.Font = RX.F2
	lbl.TextSize = 10
	lbl.Parent = container
	local inputBG = Instance.new("Frame")
	inputBG.Size = UDim2.new(1, 0, 0, 34)
	inputBG.Position = UDim2.new(0, 0, 0, 18)
	inputBG.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
	inputBG.Parent = container
	Instance.new("UICorner", inputBG).CornerRadius = UDim.new(0, 9)
	local inStroke = Instance.new("UIStroke")
	inStroke.Thickness = 1.2
	inStroke.Color = Color3.fromRGB(55, 58, 85)
	inStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inStroke.Parent = inputBG
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -10, 1, 0)
	textBox.Position = UDim2.new(0, 5, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = tostring(defaultVal)
	textBox.Font = RX.FM
	textBox.TextSize = 15
	textBox.TextColor3 = RX.Cyan
	textBox.ClearTextOnFocus = false
	textBox.Parent = inputBG
	textBox.Focused:Connect(function()
		TweenService:Create(inStroke, TWEEN_FAST, { Color = RX.Accent1 }):Play()
	end)
	textBox.FocusLost:Connect(function()
		TweenService:Create(inStroke, TWEEN_FAST, { Color = Color3.fromRGB(55, 58, 85) }):Play()
	end)
	return container, textBox
end

local function openResizeGUI(refs)
	local MF, MainGuiRef = refs.MainFrame, refs.MainGui
	local ResizeSG = Instance.new("ScreenGui")
	SecureGui(ResizeSG)
	ResizeSG:SetAttribute("FlycerResizeTag", true)
	if MainGuiRef then
		MainGuiRef.Destroying:Connect(function()
			if ResizeSG.Parent then
				ResizeSG:Destroy()
			end
		end)
	end
	local resizePanel = Instance.new("Frame")
	resizePanel.Size = UDim2.new(0, RESIZE_PANEL_WIDTH, 0, RESIZE_PANEL_HEIGHT)
	resizePanel.AnchorPoint = Vector2.new(0.5, 0.5)
	resizePanel.Position = RESIZE_PANEL_CENTER_POS
	resizePanel.BackgroundColor3 = RX.Bg
	resizePanel.Parent = ResizeSG
	Instance.new("UICorner", resizePanel).CornerRadius = UDim.new(0, 12)
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundTransparency = 1
	titleBar.Parent = resizePanel
	makeDraggable(titleBar, resizePanel)
	local _, widthInput = makeInputField(resizePanel, 20, "WIDTH", currentGUIWidth)
	local _, heightInput = makeInputField(resizePanel, 142, "HEIGHT", currentGUIHeight)
	local applyBtn = Instance.new("TextButton")
	applyBtn.Size = UDim2.new(1, -40, 0, 34)
	applyBtn.Position = UDim2.new(0, 20, 1, -48)
	applyBtn.BackgroundColor3 = RX.Accent1
	applyBtn.Text = "APPLY"
	applyBtn.Font = RX.F1
	applyBtn.TextColor3 = RX.T1
	applyBtn.Parent = resizePanel
	Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 10)
	applyBtn.Activated:Connect(function()
		local w = math.clamp(tonumber(widthInput.Text) or currentGUIWidth, 150, 800)
		local h = math.clamp(tonumber(heightInput.Text) or currentGUIHeight, 100, 700)
		currentGUIWidth, currentGUIHeight = w, h
		g.FlycerGUIWidth, g.FlycerGUIHeight = w, h
		local newLayout = calcLayout(w, h)
		MF.Size = newLayout.mainSize
		MF.Position = newLayout.mainPos
		refs.ContentWrapper.Size = newLayout.contentSize
		refs.ShadowFrame.Size = newLayout.shadowSize
		refs.ShadowFrame.Position = newLayout.shadowPos
		ResizeSG:Destroy()
		ShowNotification({ title = "Resize UI", body = "Applied: " .. w .. "x" .. h, duration = 2 })
	end)
end

--==================================================
-- FLYCER LIBRARY MODULE
--==================================================

local FlycerLib = {}

function FlycerLib:CreateWindow(windowCfg)
	windowCfg = windowCfg or {}
	local GUI_TITLE = windowCfg.Name or "FlycerUI"
	local loadingTitle = windowCfg.LoadingTitle or GUI_TITLE
	local loadingSubtitle = windowCfg.LoadingSubtitle or "Loading Interface..."
	local loadingDuration = windowCfg.LoadingDuration or windowCfg.Duration or 3
	local discordLink = windowCfg.Discord and windowCfg.Discord.Link or DISCORD_LINK

	-- ═══════════════════════════════════════════════
	-- REVEAL ANIMATION SYSTEM
	-- ═══════════════════════════════════════════════
	local uiRevealed = false
	local REVEAL_DURATION = 0.5
	local REVEAL_TWEEN_INFO = TweenInfo.new(REVEAL_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local revealTargets = {}

	local function cacheRevealTarget(obj)
		if not obj or not obj.Parent or EXCLUDED_CLASSES[obj.ClassName] then
			return
		end
		local propList = TRANSPARENCY_PROPS[obj.ClassName]
		if not propList then
			return
		end
		local cached = {}
		for _, propName in ipairs(propList) do
			local val = obj[propName]
			if val ~= nil and val < 1 then
				cached[propName] = val
				obj[propName] = 1
			end
		end
		if next(cached) then
			revealTargets[obj] = cached
		end
	end

	local function cacheAllRevealTargets(root)
		cacheRevealTarget(root)
		for _, child in ipairs(root:GetDescendants()) do
			cacheRevealTarget(child)
		end
	end

	local function revealUI(callback)
		if uiRevealed then
			return
		end
		uiRevealed = true
		local activeTweens = 0
		for obj, props in pairs(revealTargets) do
			if obj and obj.Parent then
				activeTweens = activeTweens + 1
				local tw = TweenService:Create(obj, REVEAL_TWEEN_INFO, props)
				tw.Completed:Connect(function()
					activeTweens = activeTweens - 1
					if activeTweens <= 0 and callback then
						task.spawn(callback)
					end
				end)
				tw:Play()
			end
		end
	end

	-- ═══════════════════════════════════════════════
	-- BUILD MAIN UI
	-- ═══════════════════════════════════════════════
	local MainGui = Instance.new("ScreenGui")
	SecureGui(MainGui)
	g._FlycerGUI, g[GUI_REF_NAME], g[FLAG_NAME] = MainGui, MainGui, true
	local initLayout = calcLayout(currentGUIWidth, currentGUIHeight)
	local MainFrame = Instance.new("Frame")
	MainFrame.Size = initLayout.mainSize
	MainFrame.Position = initLayout.mainPos
	MainFrame.BackgroundColor3 = RX.Accent1
	MainFrame.BackgroundTransparency = 1
	MainFrame.Parent = MainGui
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
	local innerGrad = Instance.new("UIGradient", MainFrame)
	innerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 18)),
	})
	innerGrad.Rotation = 180

	local Header = Instance.new("Frame")
	Header.Size = UDim2.new(1, 0, 0, HEADER_H)
	Header.BackgroundTransparency = 1
	Header.Parent = MainFrame
	makeDraggable(Header, MainFrame)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -160, 1, 0)
	titleLabel.Position = UDim2.new(0, 26, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = GUI_TITLE
	titleLabel.TextColor3 = RX.T1
	titleLabel.Font = RX.F1
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = Header
	makeSeparator(Header, 0, true, 1)

	-- PING/FPS Containers
	local pingContainer = Instance.new("Frame")
	pingContainer.Size = UDim2.new(0, 80, 0, 18)
	pingContainer.Position = UDim2.new(1, -156, 0.5, 0)
	pingContainer.AnchorPoint = Vector2.new(0, 0.5)
	pingContainer.BackgroundColor3 = Color3.fromRGB(60, 210, 120)
	pingContainer.BackgroundTransparency = 0.85
	pingContainer.Parent = Header
	Instance.new("UICorner", pingContainer).CornerRadius = UDim.new(0, 5)
	local pingLabel = Instance.new("TextLabel")
	pingLabel.Size = UDim2.new(1, 0, 1, 0)
	pingLabel.BackgroundTransparency = 1
	pingLabel.Text = "PING: 0ms"
	pingLabel.Font = RX.F1
	pingLabel.TextSize = 10
	pingLabel.TextColor3 = Color3.fromRGB(60, 210, 120)
	pingLabel.Parent = pingContainer

	local fpsContainer = Instance.new("Frame")
	fpsContainer.Size = UDim2.new(0, 65, 0, 18)
	fpsContainer.Position = UDim2.new(1, -71, 0.5, 0)
	fpsContainer.AnchorPoint = Vector2.new(0, 0.5)
	fpsContainer.BackgroundColor3 = Color3.fromRGB(240, 220, 50)
	fpsContainer.BackgroundTransparency = 0.85
	fpsContainer.Parent = Header
	Instance.new("UICorner", fpsContainer).CornerRadius = UDim.new(0, 5)
	local fpsLabel = Instance.new("TextLabel")
	fpsLabel.Size = UDim2.new(1, 0, 1, 0)
	fpsLabel.BackgroundTransparency = 1
	fpsLabel.Text = "FPS: 0"
	fpsLabel.Font = RX.F1
	fpsLabel.TextSize = 10
	fpsLabel.TextColor3 = Color3.fromRGB(240, 220, 50)
	fpsLabel.Parent = fpsContainer

	-- TAB RAIL
	local TabRailClip = Instance.new("Frame")
	TabRailClip.Size = UDim2.new(1, -TAB_RAIL_MARGIN * 2, 0, TAB_HEIGHT)
	TabRailClip.Position = initLayout.tabRailClipPos
	TabRailClip.BackgroundTransparency = 1
	TabRailClip.ClipsDescendants = true
	TabRailClip.Parent = MainFrame
	local TabScroll = Instance.new("ScrollingFrame")
	TabScroll.Size = UDim2.new(1, 0, 1, 0)
	TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	TabScroll.ScrollingDirection = Enum.ScrollingDirection.X
	TabScroll.BackgroundTransparency = 1
	TabScroll.ScrollBarThickness = 0
	TabScroll.Parent = TabRailClip
	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.FillDirection = Enum.FillDirection.Horizontal
	tabListLayout.Padding = UDim.new(0, 4)
	tabListLayout.Parent = TabScroll

	-- CONTENT
	local ShadowFrame = Instance.new("Frame")
	ShadowFrame.Size = initLayout.shadowSize
	ShadowFrame.Position = initLayout.shadowPos
	ShadowFrame.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	ShadowFrame.BackgroundTransparency = 0.8
	ShadowFrame.Parent = MainFrame
	Instance.new("UICorner", ShadowFrame).CornerRadius = UDim.new(0, 8)
	local ContentWrapper = Instance.new("Frame")
	ContentWrapper.Size = initLayout.contentSize
	ContentWrapper.Position = UDim2.new(0, 0, 0, CONTENT_TOP)
	ContentWrapper.BackgroundTransparency = 1
	ContentWrapper.Parent = MainFrame

	local ExtraFrame = Instance.new("Frame")
	ExtraFrame.Size = initLayout.extraFrameSize
	ExtraFrame.Position = initLayout.extraFramePos
	ExtraFrame.BackgroundColor3 = RX.Accent1
	ExtraFrame.BackgroundTransparency = RX.MainAlpha
	ExtraFrame.Parent = MainFrame
	Instance.new("UICorner", ExtraFrame).CornerRadius = UDim.new(0, 6)

	-- TOGGLE BUTTON
	local ToggleSG = Instance.new("ScreenGui")
	SecureGui(ToggleSG)
	local ToggleFrame = Instance.new("TextButton")
	ToggleFrame.Size = UDim2.new(0, 90, 0, 34)
	ToggleFrame.Position = initLayout.togglePos
	ToggleFrame.BackgroundColor3 = RX.Accent1
	ToggleFrame.BackgroundTransparency = 1
	ToggleFrame.Text = ""
	ToggleFrame.Parent = ToggleSG
	Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 16)
	local ToggleText = Instance.new("TextLabel")
	ToggleText.Size = UDim2.new(1, 0, 1, 0)
	ToggleText.BackgroundTransparency = 1
	ToggleText.Text = "HIDE"
	ToggleText.TextColor3 = RX.T1
	ToggleText.Font = RX.F1
	ToggleText.TextSize = 12
	ToggleText.Parent = ToggleFrame
	makeDraggable(ToggleFrame)

	-- TAB CORE
	local tabRegistry, activeTabName = {}, nil
	local function activateTab(name)
		if activeTabName == name then
			return
		end
		activeTabName = name
		for _, entry in ipairs(tabRegistry) do
			local active = (entry.name == name)
			entry.canvas.Visible = active
			TweenService:Create(entry.button, TWEEN_FAST, { BackgroundTransparency = active and 0 or 0.3 }):Play()
		end
	end

	local function addTab(name)
		local sf = Instance.new("ScrollingFrame")
		sf.Size = UDim2.new(1, 0, 1, 0)
		sf.BackgroundTransparency = 1
		sf.ScrollBarThickness = 2
		sf.Visible = false
		sf.Parent = ContentWrapper
		Instance.new("UIListLayout", sf).Padding = UDim.new(0, 5)
		local button = Instance.new("Frame")
		button.Size = UDim2.new(0, 80, 0, TAB_HEIGHT - 7)
		button.BackgroundColor3 = Color3.fromRGB(32, 32, 52)
		button.Parent = TabScroll
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = name
		lbl.TextColor3 = RX.T1
		lbl.Font = RX.F1
		lbl.TextSize = 11
		lbl.Parent = button
		local hit = Instance.new("TextButton")
		hit.Size = UDim2.new(1, 0, 1, 0)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Parent = button
		hit.Activated:Connect(function()
			activateTab(name)
		end)
		table.insert(tabRegistry, { name = name, button = button, canvas = sf })
		if not activeTabName then
			activateTab(name)
		end
		return sf
	end

	-- COMPONENT FACTORY
	local function makeComponents(canvas)
		local C = {}
		function C:CreateToggle(cfg)
			local f = Instance.new("Frame")
			f.Size = UDim2.new(1, 0, 0, 34)
			f.BackgroundColor3 = RX.Card
			f.BackgroundTransparency = RX.CardAlpha
			f.Parent = canvas
			Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -50, 1, 0)
			lbl.Position = UDim2.new(0, 10, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = cfg.Name
			lbl.TextColor3 = RX.T1
			lbl.Font = RX.F1
			lbl.TextSize = 10
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = f
			local track = Instance.new("Frame")
			track.Size = UDim2.new(0, 40, 0, 20)
			track.Position = UDim2.new(1, -50, 0.5, 0)
			track.AnchorPoint = Vector2.new(0, 0.5)
			track.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			track.Parent = f
			Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
			local knob = Instance.new("Frame")
			knob.Size = UDim2.new(0, 16, 0, 16)
			knob.Position = UDim2.new(0, 2, 0.5, 0)
			knob.AnchorPoint = Vector2.new(0, 0.5)
			knob.BackgroundColor3 = RX.T1
			knob.Parent = track
			Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
			local state = cfg.CurrentValue or false
			local function update()
				TweenService
					:Create(
						knob,
						TWEEN_FAST,
						{ Position = state and UDim2.new(0, 22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }
					)
					:Play()
				TweenService
					:Create(
						track,
						TWEEN_FAST,
						{ BackgroundColor3 = state and RX.Accent1 or Color3.fromRGB(40, 40, 50) }
					)
					:Play()
			end
			update()
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.Parent = track
			btn.Activated:Connect(function()
				state = not state
				update()
				if cfg.Callback then
					task.spawn(cfg.Callback, state)
				end
			end)
			return {
				Set = function(_, v)
					state = v
					update()
				end,
			}
		end
		function C:CreateButton(cfg)
			local f = Instance.new("Frame")
			f.Size = UDim2.new(1, 0, 0, 36)
			f.BackgroundColor3 = RX.Card
			f.BackgroundTransparency = RX.CardAlpha
			f.Parent = canvas
			Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text = cfg.Name
			btn.TextColor3 = RX.T1
			btn.Font = RX.F1
			btn.TextSize = 10
			btn.Parent = f
			btn.Activated:Connect(function()
				if cfg.Callback then
					task.spawn(cfg.Callback)
				end
			end)
		end
		function C:CreateLabel(txt)
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 20)
			lbl.BackgroundTransparency = 1
			lbl.Text = txt
			lbl.TextColor3 = RX.T2
			lbl.Font = RX.F2
			lbl.TextSize = 10
			lbl.Parent = canvas
		end
		function C:CreateSection(txt)
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 26)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.upper(txt)
			lbl.TextColor3 = RX.Accent1
			lbl.Font = RX.F1
			lbl.TextSize = 10
			lbl.Parent = canvas
		end
		return C
	end

	-- COUNTERS
	local function StartPingCounter()
		if _FLYCER_PRIVATE.pingConn then
			return
		end
		_FLYCER_PRIVATE.pingConn = RunService.Heartbeat:Connect(function()
			local ok, r = pcall(function()
				return LocalPlayer:GetNetworkPing()
			end)
			if ok then
				pingLabel.Text = "PING: " .. math.round(r * 1000) .. "ms"
			end
		end)
	end
	local function StartFPSCounter()
		if _FLYCER_PRIVATE.fpsConn then
			return
		end
		local f, last = 0, os.clock()
		_FLYCER_PRIVATE.fpsConn = RunService.RenderStepped:Connect(function()
			f = f + 1
			local now = os.clock()
			if now - last >= 0.5 then
				fpsLabel.Text = "FPS: " .. math.round(f / (now - last))
				f = 0
				last = now
			end
		end)
	end

	-- INITIAL SYNC & LOADING
	task.spawn(function()
		local waited = 0
		while Camera.ViewportSize.X == 0 and waited < 3 do
			RunService.RenderStepped:Wait()
			waited = waited + 1 / 60
		end
		local sync = calcLayout(currentGUIWidth, currentGUIHeight)
		MainFrame.Position, ToggleFrame.Position = sync.mainPos, sync.togglePos
		task.wait(0.1)
		cacheAllRevealTargets(MainFrame)
		cacheAllRevealTargets(ToggleFrame)
	end)

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

	-- SETTINGS TAB
	local setCanvas = addTab("Settings")
	local SC = makeComponents(setCanvas)
	SC:CreateToggle({
		Name = "Lock UI Position",
		Callback = function(v)
			isUILocked = v
		end,
	})
	SC:CreateButton({
		Name = "Resize UI",
		Callback = function()
			openResizeGUI({
				MainFrame = MainFrame,
				ContentWrapper = ContentWrapper,
				ShadowFrame = ShadowFrame,
				MainGui = MainGui,
			})
		end,
	})
	SC:CreateButton({
		Name = "Copy Discord",
		Callback = function()
			if EXECUTOR_APIS.setclipboard then
				setclipboard(discordLink)
			end
		end,
	})

	local Window = {}
	function Window:CreateTab(n)
		return makeComponents(addTab(n))
	end
	function Window:Notify(c)
		ShowNotification(c)
	end
	return Window
end

return FlycerLib
