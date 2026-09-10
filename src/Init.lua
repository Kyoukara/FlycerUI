local FlycerUI = {
	Window = nil,
	Theme = nil,
	Creator = require("./modules/Creator"),
	LocalizationModule = require("./modules/Localization"),
	NotificationModule = require("./components/Notification"),
	Themes = nil,
	Transparent = false,

	TransparencyValue = 0.15,

	UIScale = 1,

	ConfigManager = nil,
	Version = "0.0.0",

	Services = require("./utils/services/Init"),

	OnThemeChangeFunction = nil,

	cloneref = nil,
	UIScaleObj = nil,

	CreateWindow = nil,

	CurrentInput = nil,
}

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

FlycerUI.cloneref = cloneref

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

function FlycerUI.GenerateGUID()
	return HttpService:GenerateGUID(false)
end

local CurInput = FlycerUI.GenerateGUID()

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	--[[if GameProcessed then
		return
	end]]

	task.defer(function()
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			if FlycerUI.CurrentInput and FlycerUI.CurrentInput ~= CurInput then
				return
			end

			FlycerUI.CurrentInput = CurInput
			--print(CurInput)
			--FlycerUI.InputStartedOnUI = false
		end
	end)
end)
UserInputService.InputEnded:Connect(function(Input, GameProcessed)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		if FlycerUI.CurrentInput and FlycerUI.CurrentInput ~= CurInput then
			return
		end

		FlycerUI.CurrentInput = nil
	end
end)

local LocalPlayer = Players.LocalPlayer or nil

local Package = HttpService:JSONDecode(require("../build/package"))
if Package then
	FlycerUI.Version = Package.version
end

local KeySystem = require("./components/KeySystem")

local Creator = FlycerUI.Creator

local New = Creator.New

--local Tween = Creator.Tween
--local ServicesModule = FlycerUI.Services

local Acrylic = require("./utils/Acrylic/Init")

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local GUIParent = gethui and gethui() or (CoreGui or LocalPlayer:WaitForChild("PlayerGui"))

local UIScaleObj = New("UIScale", {
	Scale = FlycerUI.UIScale,
})

FlycerUI.UIScaleObj = UIScaleObj

FlycerUI.ScreenGui = New("ScreenGui", {
	Name = "FlycerUI",
	Parent = GUIParent,
	IgnoreGuiInset = true,
	ScreenInsets = "None",
	DisplayOrder = -99999,
}, {

	New("Folder", {
		Name = "Window",
	}),
	-- New("Folder", {
	--     Name = "Notifications"
	-- }),
	-- New("Folder", {
	--     Name = "Dropdowns"
	-- }),
	New("Folder", {
		Name = "KeySystem",
	}),
	New("Folder", {
		Name = "Popups",
	}),
	New("Folder", {
		Name = "ToolTips",
	}),
})

FlycerUI.NotificationGui = New("ScreenGui", {
	Name = "FlycerUI/Notifications",
	Parent = GUIParent,
	IgnoreGuiInset = true,
})
FlycerUI.DropdownGui = New("ScreenGui", {
	Name = "FlycerUI/Dropdowns",
	Parent = GUIParent,
	IgnoreGuiInset = true,
})
FlycerUI.TooltipGui = New("ScreenGui", {
	Name = "FlycerUI/Tooltips",
	Parent = GUIParent,
	IgnoreGuiInset = true,
})
ProtectGui(FlycerUI.ScreenGui)
ProtectGui(FlycerUI.NotificationGui)
ProtectGui(FlycerUI.DropdownGui)
ProtectGui(FlycerUI.TooltipGui)

Creator.Init(FlycerUI)

function FlycerUI:SetParent(parent)
	if FlycerUI.ScreenGui then
		FlycerUI.ScreenGui.Parent = parent
	end
	if FlycerUI.NotificationGui then
		FlycerUI.NotificationGui.Parent = parent
	end
	if FlycerUI.DropdownGui then
		FlycerUI.DropdownGui.Parent = parent
	end
	if FlycerUI.TooltipGui then
		FlycerUI.TooltipGui.Parent = parent
	end
end
math.clamp(FlycerUI.TransparencyValue, 0, 1)

local Holder = FlycerUI.NotificationModule.Init(FlycerUI.NotificationGui)

function FlycerUI:Notify(Config)
	Config.Holder = Holder.Frame
	Config.Window = FlycerUI.Window
	--Config.FlycerUI = FlycerUI
	return FlycerUI.NotificationModule.New(Config)
end

function FlycerUI:SetNotificationLower(Val)
	Holder.SetLower(Val)
end

function FlycerUI:SetFont(FontId)
	Creator.UpdateFont(FontId)
end

function FlycerUI:OnThemeChange(func)
	FlycerUI.OnThemeChangeFunction = func
end

function FlycerUI:AddTheme(LTheme)
	FlycerUI.Themes[LTheme.Name] = LTheme
	return LTheme
end

function FlycerUI:SetTheme(Value)
	if FlycerUI.Themes[Value] then
		FlycerUI.Theme = FlycerUI.Themes[Value]
		Creator.SetTheme(FlycerUI.Themes[Value])

		if FlycerUI.OnThemeChangeFunction then
			FlycerUI.OnThemeChangeFunction(Value)
		end

		return FlycerUI.Themes[Value]
	end
	return nil
end

function FlycerUI:GetThemes()
	return FlycerUI.Themes
end
function FlycerUI:GetCurrentTheme()
	return FlycerUI.Theme.Name
end
function FlycerUI:GetTransparency()
	return FlycerUI.Transparent or false
end
function FlycerUI:GetWindowSize()
	return FlycerUI.Window.UIElements.Main.Size
end
function FlycerUI:Localization(LocalizationConfig)
	return FlycerUI.LocalizationModule:New(LocalizationConfig, Creator)
end

function FlycerUI:SetLanguage(Value)
	if Creator.Localization then
		return Creator.SetLanguage(Value)
	end
	return false
end

function FlycerUI:ToggleAcrylic(Value)
	if FlycerUI.Window and FlycerUI.Window.AcrylicPaint and FlycerUI.Window.AcrylicPaint.Model then
		FlycerUI.Window.Acrylic = Value
		FlycerUI.Window.AcrylicPaint.Model.Transparency = Value and 0.98 or 1
		if Value then
			Acrylic.Enable()
		else
			Acrylic.Disable()
		end
	end
end

function FlycerUI:Gradient(stops, props)
	local colorSequence = {}
	local transparencySequence = {}

	for posStr, stop in next, stops do
		local position = tonumber(posStr)
		if position then
			position = math.clamp(position / 100, 0, 1)

			local color = stop.Color
			if typeof(color) == "string" and string.sub(color, 1, 1) == "#" then
				color = Color3.fromHex(color)
			end

			local transparency = stop.Transparency or 0

			table.insert(colorSequence, ColorSequenceKeypoint.new(position, color))
			table.insert(transparencySequence, NumberSequenceKeypoint.new(position, transparency))
		end
	end

	table.sort(colorSequence, function(a, b)
		return a.Time < b.Time
	end)
	table.sort(transparencySequence, function(a, b)
		return a.Time < b.Time
	end)

	if #colorSequence < 2 then
		table.insert(colorSequence, ColorSequenceKeypoint.new(1, colorSequence[1].Value))
		table.insert(transparencySequence, NumberSequenceKeypoint.new(1, transparencySequence[1].Value))
	end

	local gradientData = {
		Color = ColorSequence.new(colorSequence),
		Transparency = NumberSequence.new(transparencySequence),
	}

	if props then
		for k, v in pairs(props) do
			gradientData[k] = v
		end
	end

	return gradientData
end

function FlycerUI:Popup(PopupConfig)
	PopupConfig.FlycerUI = FlycerUI
	return require("./components/popup/Init").new(PopupConfig, FlycerUI.ScreenGui.Popups)
end

FlycerUI.Themes = require("./themes/Init")(FlycerUI, Creator)

Creator.Themes = FlycerUI.Themes

FlycerUI:SetTheme("Dark")
FlycerUI:SetLanguage(Creator.Language)

function FlycerUI:CreateWindow(Config)
	local CreateWindow = require("./components/window/Init")

	if not RunService:IsStudio() and writefile then
		if not isfolder("FlycerUI") then
			makefolder("FlycerUI")
		end
		if Config.Folder then
			makefolder(Config.Folder)
		else
			makefolder(Config.Title)
		end
	end

	Config.FlycerUI = FlycerUI
	Config.Window = FlycerUI.Window
	Config.Parent = FlycerUI.ScreenGui.Window

	if FlycerUI.Window then
		warn("You cannot create more than one window")
		return
	end

	local CanLoadWindow = true

	local Theme = FlycerUI.Themes[Config.Theme or "Dark"]

	--FlycerUI.Theme = Theme
	Creator.SetTheme(Theme)

	local hwid = gethwid or function()
		return Players.LocalPlayer.UserId
	end

	local Filename = hwid()

	if Config.KeySystem then
		CanLoadWindow = false

		local function loadKeysystem()
			KeySystem.new(Config, Filename, function(c)
				CanLoadWindow = c
			end)
		end

		local keyPath = (Config.Folder or "Temp") .. "/" .. Filename .. ".key"

		if Config.KeySystem.KeyValidator then
			if Config.KeySystem.SaveKey and isfile(keyPath) then
				local savedKey = readfile(keyPath)
				local isValid = Config.KeySystem.KeyValidator(savedKey)

				if isValid then
					CanLoadWindow = true
				else
					loadKeysystem()
				end
			else
				loadKeysystem()
			end
		elseif not Config.KeySystem.API then
			if Config.KeySystem.SaveKey and isfile(keyPath) then
				local savedKey = readfile(keyPath)
				local isKey = (type(Config.KeySystem.Key) == "table") and table.find(Config.KeySystem.Key, savedKey)
					or tostring(Config.KeySystem.Key) == tostring(savedKey)

				if isKey then
					CanLoadWindow = true
				else
					loadKeysystem()
				end
			else
				loadKeysystem()
			end
		else
			if isfile(keyPath) then
				local fileKey = readfile(keyPath)
				local isSuccess = false

				for _, i in next, Config.KeySystem.API do
					local serviceData = FlycerUI.Services[i.Type]
					if serviceData then
						local args = {}
						for _, argName in next, serviceData.Args do
							table.insert(args, i[argName])
						end

						local service = serviceData.New(table.unpack(args))
						local success = service.Verify(fileKey)
						if success then
							isSuccess = true
							break
						end
					end
				end

				CanLoadWindow = isSuccess
				if not isSuccess then
					loadKeysystem()
				end
			else
				loadKeysystem()
			end
		end

		repeat
			task.wait()
		until CanLoadWindow
	end

	local Window = CreateWindow(Config)

	FlycerUI.Transparent = Config.Transparent
	FlycerUI.Window = Window

	if Config.Acrylic then
		Acrylic.init()
	end

	-- function Window:ToggleTransparency(Value)
	--     FlycerUI.Transparent = Value
	--     FlycerUI.Window.Transparent = Value

	--     Window.UIElements.Main.Background.BackgroundTransparency = Value and FlycerUI.TransparencyValue or 0
	--     Window.UIElements.Main.Background.ImageLabel.ImageTransparency = Value and FlycerUI.TransparencyValue or 0
	--     Window.UIElements.Main.Gradient.UIGradient.Transparency = NumberSequence.new{
	--         NumberSequenceKeypoint.new(0, 1),
	--         NumberSequenceKeypoint.new(1, Value and 0.85 or 0.7),
	--     }
	-- end

	return Window
end

return FlycerUI
