local KeySystem = {}

local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

local CreateButton = require("./ui/Button").New
local CreateInput = require("./ui/Input").New

-- ============================================================
-- HELPER: Format Countdown
-- ============================================================
local function FormatCountdown(expireTimestamp)
	expireTimestamp = tonumber(expireTimestamp)

	if not expireTimestamp or expireTimestamp <= 0 then
		return "Lifetime"
	end

	local remaining = math.max(0, expireTimestamp - os.time())
	local days = math.floor(remaining / 86400)
	local hours = math.floor((remaining % 86400) / 3600)
	local minutes = math.floor((remaining % 3600) / 60)

	return string.format("%03dD : %02dH : %02dM", days, hours, minutes)
end

-- ============================================================
-- HELPER: Start Countdown
-- ============================================================
local function StartCountdown(expireTimestamp, updateCallback)
	expireTimestamp = tonumber(expireTimestamp)

	if not expireTimestamp or expireTimestamp <= 0 then
		updateCallback("Lifetime")
		return function() end
	end

	local stopped = false

	task.spawn(function()
		local lastText

		while not stopped do
			local remaining = expireTimestamp - os.time()
			if remaining <= 0 then
				updateCallback("000D : 00H : 00M")
				break
			end

			local text = FormatCountdown(expireTimestamp)
			if text ~= lastText then
				lastText = text
				updateCallback(text)
			end

			local waitTime = 60 - (os.time() % 60)
			task.wait(math.max(1, waitTime))
		end
	end)

	return function()
		stopped = true
	end
end

-- ============================================================
-- HELPER: Copy to Clipboard
-- ============================================================
local function CopyToClipboard(value)
	if value == nil then
		return false, "Clipboard value is empty."
	end

	local text = tostring(value)
	if text == "" then
		return false, "Clipboard value is empty."
	end

	local copy = setclipboard or toclipboard
	if type(copy) ~= "function" then
		return false, "Clipboard is not available in this executor."
	end

	local ok, err = pcall(function()
		copy(text)
	end)

	if not ok then
		return false, tostring(err or "Unable to copy to clipboard.")
	end

	return true, text
end

-- ============================================================
-- HELPER: Notify
-- ============================================================
local function Notify(Config, title, content, icon)
	if not Config or not Config.FlycerUI or type(Config.FlycerUI.Notify) ~= "function" then
		warn("[FlycerUI KeySystem] " .. tostring(title) .. ": " .. tostring(content))
		return false
	end

	local ok = pcall(function()
		Config.FlycerUI:Notify({
			Title = tostring(title or "Key System"),
			Content = tostring(content or ""),
			Icon = icon or "triangle-alert",
		})
	end)

	if not ok then
		warn("[FlycerUI KeySystem] Notify failed: " .. tostring(title) .. " - " .. tostring(content))
	end

	return ok
end

-- ============================================================
-- HELPER: Normalize Asset ID
-- ============================================================
local function NormalizeAssetId(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. tostring(math.floor(icon))
	end

	if type(icon) ~= "string" then
		return nil
	end

	if icon:match("^rbxassetid://%d+$") then
		return icon
	end

	if icon:match("^%d+$") then
		return "rbxassetid://" .. icon
	end

	return nil
end

-- ============================================================
-- HELPER: Create Service Icon
-- ============================================================
local function CreateServiceIcon(icon, size, themed)
	icon = icon or "user"
	size = size or UDim2.fromOffset(24, 24)

	local assetId = NormalizeAssetId(icon)
	if assetId then
		return New("ImageLabel", {
			Image = assetId,
			BackgroundTransparency = 1,
			Size = size,
			ScaleType = Enum.ScaleType.Fit,
		})
	end

	local ok, frame = pcall(function()
		return Creator.Image(
			tostring(icon),
			tostring(icon),
			0,
			"Temp",
			"KeySystem",
			themed == true
		)
	end)

	if ok and frame then
		frame.Size = size
		return frame
	end

	local fallbackOk, fallback = pcall(function()
		return Creator.Image("key", "key", 0, "Temp", "KeySystem", true)
	end)

	if fallbackOk and fallback then
		fallback.Size = size
		return fallback
	end

	return New("Frame", {
		BackgroundTransparency = 1,
		Size = size,
	})
end

-- ============================================================
-- HELPER: Safe Close Dialog
-- ============================================================
local function SafeCloseDialog(dialog)
	if dialog then
		pcall(function()
			dialog:Close()()
		end)
	end
end

-- ============================================================
-- Forward declaration
-- ============================================================
local CreateFlycerService

-- ============================================================
-- HELPER: Get Flycer Identifier
-- ============================================================
local function GetFlycerIdentifier(Config)
	if type(Config) ~= "table" or type(Config.KeySystem) ~= "table" then
		return nil, "Invalid", "Flycer configuration is missing."
	end

	local serviceInstance, serviceError = CreateFlycerService(Config)
	if not serviceInstance then
		return nil, "Invalid", serviceError or "Flycer service is not available."
	end

	if type(serviceInstance.GetIdentifier) ~= "function" then
		return nil, "Invalid", "Flycer service does not expose an identifier provider."
	end

	local ok, identifier, identifierType, identifierError = pcall(function()
		return serviceInstance.GetIdentifier()
	end)

	if not ok then
		return nil, "Invalid", "Unable to determine Flycer identifier."
	end

	if not identifier or tostring(identifier) == "" then
		return nil, identifierType or "Invalid", identifierError or "Unable to determine Flycer identifier."
	end

	return tostring(identifier), identifierType, identifierError
end

KeySystem.GetFlycerIdentifier = GetFlycerIdentifier

-- ============================================================
-- HELPER: Create Flycer Service
-- ============================================================
CreateFlycerService = function(Config)
	local flycerConfig = Config.KeySystem and Config.KeySystem.Flycer
	if type(flycerConfig) ~= "table" then
		return nil, "Flycer configuration is missing."
	end

	if not flycerConfig.Endpoint or tostring(flycerConfig.Endpoint) == "" then
		return nil, "Flycer API Endpoint is not configured."
	end

	local services = Config.FlycerUI and Config.FlycerUI.Services
	local serviceData = services and services.flycer
	if not serviceData or type(serviceData.New) ~= "function" then
		return nil, "Flycer service is not available in this FlycerUI build."
	end

	local ok, serviceOrError = pcall(function()
		return serviceData.New(
			flycerConfig.Endpoint,
			flycerConfig.Product or Config.Title,
			flycerConfig.LockType or "Device",
			flycerConfig.Client or "FlycerUI",
			flycerConfig.Version or "1.0.0"
		)
	end)

	if not ok or type(serviceOrError) ~= "table" then
		return nil, "Unable to initialize Flycer service."
	end

	return serviceOrError
end

-- ============================================================
-- HELPER: Open Flycer Service Dialog
-- ============================================================
local function OpenFlycerServiceDialog(
	Config,
	Identifier,
	IdentifierType,
	KeyDialog,
	DropdownContainer,
	ChevronDown,
	IdentifierError
)
	local DialogModule = require("./window/Dialog")
	local Dialog =
		DialogModule.Create(true, "Popup", Config.Window, Config.FlycerUI, Config.FlycerUI.ScreenGui.KeySystem)

	if DropdownContainer then
		DropdownContainer.Size = UDim2.new(0, 0, 0, 0)
	end
	if ChevronDown then
		ChevronDown.Rotation = 0
	end
	if KeyDialog and KeyDialog.UIElements.MainContainer then
		KeyDialog.UIElements.MainContainer.Visible = false
	end

	local Closed = false
	local function CloseFlycerDialog()
		if Closed then
			return
		end
		Closed = true
		SafeCloseDialog(Dialog)
		task.delay(0.12, function()
			if KeyDialog and KeyDialog.UIElements.MainContainer then
				KeyDialog.UIElements.MainContainer.Visible = true
			end
		end)
	end

	Dialog.UIElements.Main.AutomaticSize = "Y"
	Dialog.UIElements.Main.Size = UDim2.new(0, 470, 0, 0)

	local Title = New("TextLabel", {
		Text = "Flycer",
		BackgroundTransparency = 1,
		AutomaticSize = "XY",
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ThemeTag = { TextColor3 = "Text" },
		TextSize = 20,
	})

	local Description = New("TextLabel", {
		Text = "Choose an action below.",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ThemeTag = { TextColor3 = "Text" },
		TextTransparency = 0.35,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = "Left",
	})

	local Buttons = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 42),
	}, {
		New("UIListLayout", {
			FillDirection = "Horizontal",
			HorizontalAlignment = "Center",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 8),
		}),
	})

	local CloseButton = CreateButton("Close", "x", function()
		CloseFlycerDialog()
	end, "Tertiary", Buttons)

	local CopyButton = CreateButton("Copy HWID", "copy", function()
		local copied, copyError = CopyToClipboard(Identifier)
		if copied then
			Notify(Config, "Flycer", tostring(IdentifierType or "Device") .. " identifier copied to clipboard.", "copy")
		else
			Notify(Config, "Flycer", IdentifierError or copyError or "Clipboard or identifier is not available in this executor.", "triangle-alert")
		end
	end, "Primary", Buttons)

	local Discord = Config.KeySystem.Discord or Config.KeySystem.DiscordURL
	local DiscordButton
	if Discord and Discord ~= "" then
		DiscordButton = CreateButton("Discord", "message-circle", function()
			local copied, copyError = CopyToClipboard(Discord)
			if copied then
				Notify(Config, "Flycer", "Discord link copied to clipboard.", "message-circle")
			else
				Notify(Config, "Flycer", copyError or "Unable to copy Discord link.", "triangle-alert")
			end
		end, "Secondary", Buttons)
	end

	CloseButton.Size = UDim2.new(0, 105, 0, 42)
	CopyButton.Size = UDim2.new(0, 145, 0, 42)
	if DiscordButton then
		DiscordButton.Size = UDim2.new(0, 125, 0, 42)
	end

	New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		Parent = Dialog.UIElements.Main,
	}, {
		New("UIListLayout", {
			FillDirection = "Vertical",
			Padding = UDim.new(0, 14),
		}),
		Title,
		Description,
		Buttons,
		New("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
		}),
	})

	Dialog:Open()
end

-- ============================================================
-- MAIN: KeySystem.new
-- ============================================================
function KeySystem.new(Config, Filename, func, keyValidator)
	local KeyDialogInit = require("./window/Dialog")
	local KeyDialog =
		KeyDialogInit.Create(true, "Popup", Config.Window, Config.FlycerUI, Config.FlycerUI.ScreenGui.KeySystem)

	local Services = {}

	local EnteredKey
	local ExpiryTag
	local StopCountdown

	local ThumbnailSize = (Config.KeySystem.Thumbnail and Config.KeySystem.Thumbnail.Width) or 200

	local UISize = 430
	if Config.KeySystem.Thumbnail and Config.KeySystem.Thumbnail.Image then
		UISize = 430 + (ThumbnailSize / 2)
	end

	KeyDialog.UIElements.Main.AutomaticSize = "Y"
	KeyDialog.UIElements.Main.Size = UDim2.new(0, UISize, 0, 0)

	-- ========================================================
	-- UI: Icon
	-- ========================================================
	local IconFrame

	if Config.Icon then
		IconFrame = CreateServiceIcon(Config.Icon, UDim2.fromOffset(24, 24), Config.IconThemed)
		IconFrame.LayoutOrder = -1
	end

	-- ========================================================
	-- UI: Title
	-- ========================================================
	local Title = New("TextLabel", {
		AutomaticSize = "XY",
		BackgroundTransparency = 1,
		Text = Config.KeySystem.Title or Config.Title,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ThemeTag = {
			TextColor3 = "Text",
		},
		TextSize = 20,
	})

	local KeySystemTitle = New("TextLabel", {
		AutomaticSize = "XY",
		BackgroundTransparency = 1,
		Text = "Key System",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		TextTransparency = 1,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ThemeTag = {
			TextColor3 = "Text",
		},
		TextSize = 16,
	})

	local IconAndTitleContainer = New("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = "XY",
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 14),
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
		}),
		IconFrame,
		Title,
	})

	local TitleContainer = New("Frame", {
		AutomaticSize = "Y",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
	}, {
		IconAndTitleContainer,
		KeySystemTitle,
	})

	-- ========================================================
	-- UI: Input
	-- ========================================================
	local InputFrame = CreateInput("Enter Key", "key", nil, "Input", function(k)
		EnteredKey = k
	end)

	-- ========================================================
	-- UI: Note
	-- ========================================================
	local NoteText
	if Config.KeySystem.Note and Config.KeySystem.Note ~= "" then
		NoteText = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			TextXAlignment = "Left",
			Text = Config.KeySystem.Note,
			TextSize = 18,
			TextTransparency = 0.4,
			ThemeTag = {
				TextColor3 = "Text",
			},
			BackgroundTransparency = 1,
			RichText = true,
			TextWrapped = true,
		})
	end

	-- ========================================================
	-- UI: Buttons Container
	-- ========================================================
	local ButtonsContainer = New("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
	}, {
		New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = "X",
			Size = UDim2.new(0, 0, 1, 0),
		}, {
			New("UIListLayout", {
				Padding = UDim.new(0, 18 / 2),
				FillDirection = "Horizontal",
			}),
		}),
	})

	-- ========================================================
	-- UI: Thumbnail
	-- ========================================================
	local ThumbnailFrame
	if Config.KeySystem.Thumbnail and Config.KeySystem.Thumbnail.Image then
		local ThumbnailTitle
		if Config.KeySystem.Thumbnail.Title then
			ThumbnailTitle = New("TextLabel", {
				Text = Config.KeySystem.Thumbnail.Title,
				ThemeTag = {
					TextColor3 = "Text",
				},
				TextSize = 18,
				FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
				BackgroundTransparency = 1,
				AutomaticSize = "XY",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
			})
		end
		ThumbnailFrame = New("ImageLabel", {
			Image = Config.KeySystem.Thumbnail.Image,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, ThumbnailSize, 1, -12),
			Position = UDim2.new(0, 6, 0, 6),
			Parent = KeyDialog.UIElements.Main,
			ScaleType = "Crop",
		}, {
			ThumbnailTitle,
			New("UICorner", {
				CornerRadius = UDim.new(0, 26 - 6),
			}),
		})
	end

	-- ========================================================
	-- UI: Main Frame
	-- ========================================================
	local MainFrame = New("Frame", {
		Size = UDim2.new(1, ThumbnailFrame and -ThumbnailSize or 0, 1, 0),
		Position = UDim2.new(0, ThumbnailFrame and ThumbnailSize or 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = KeyDialog.UIElements.Main,
	}, {
		New("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			New("UIListLayout", {
				Padding = UDim.new(0, 18),
				FillDirection = "Vertical",
			}),
			TitleContainer,
			NoteText,
			InputFrame,
			ButtonsContainer,
			New("UIPadding", {
				PaddingTop = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
			}),
		}),
	})

	-- ========================================================
	-- UI: Exit Button
	-- ========================================================
	local ExitButton = CreateButton("Exit", "log-out", function()
		SafeCloseDialog(KeyDialog)
	end, "Tertiary", ButtonsContainer.Frame)

	if ThumbnailFrame then
		ExitButton.Parent = ThumbnailFrame
		ExitButton.Size = UDim2.new(0, 0, 0, 42)
		ExitButton.Position = UDim2.new(0, 10, 1, -10)
		ExitButton.AnchorPoint = Vector2.new(0, 1)
	end

	-- ========================================================
	-- UI: Get Key Button (URL only, no validator)
	-- ========================================================
	if Config.KeySystem.URL and not Config.KeySystem.KeyValidator then
		CreateButton("Get key", "key", function()
			local copied, copyError = CopyToClipboard(Config.KeySystem.URL)
			if copied then
				Notify(Config, "Key System", "Key link copied to clipboard.", "key")
			else
				Notify(Config, "Key System", copyError or "Unable to copy key link.", "triangle-alert")
			end
		end, "Secondary", ButtonsContainer.Frame)
	end

	-- ========================================================
	-- UI: Get Key Dropdown (API / KeyValidator / Flycer)
	-- ========================================================
	if Config.KeySystem.API or Config.KeySystem.KeyValidator or type(Config.KeySystem.Flycer) == "table" then
		local Width = 240
		local Opened = false
		local ButtonFrame = CreateButton("Get key", "key", nil, "Secondary", ButtonsContainer.Frame)

		local Divider = Creator.NewRoundFrame(99, "Squircle", {
			Size = UDim2.new(0, 1, 1, 0),
			ThemeTag = {
				ImageColor3 = "Text",
			},
			ImageTransparency = 0.9,
		})

		local DividerContainer = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = "X",
			Parent = ButtonFrame.Frame,
		}, {
			Divider,
			New("UIPadding", {
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
			}),
		})

		local ChevronDown = Creator.Image("chevron-down", "chevron-down", 0, "Temp", "KeySystem", true)
		ChevronDown.Size = UDim2.new(1, 0, 1, 0)

		local IconContainer = New("Frame", {
			Size = UDim2.new(0, 24 - 3, 0, 24 - 3),
			Parent = ButtonFrame.Frame,
			BackgroundTransparency = 1,
		}, {
			ChevronDown,
		})

		local DropdownFrame = Creator.NewRoundFrame(15, "Squircle", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			ThemeTag = {
				ImageColor3 = "Background",
			},
		}, {
			New("UIPadding", {
				PaddingTop = UDim.new(0, 10 / 2),
				PaddingLeft = UDim.new(0, 10 / 2),
				PaddingRight = UDim.new(0, 10 / 2),
				PaddingBottom = UDim.new(0, 10 / 2),
			}),
			New("UIListLayout", {
				FillDirection = "Vertical",
				Padding = UDim.new(0, 10 / 2),
			}),
		})

		local DropdownContainer = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, Width, 0, 0),
			ClipsDescendants = true,
			AnchorPoint = Vector2.new(1, 0),
			Parent = ButtonFrame,
			Position = UDim2.new(1, 0, 1, 15),
		}, {
			DropdownFrame,
		})

		New("TextLabel", {
			Text = "Select Service",
			BackgroundTransparency = 1,
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			ThemeTag = { TextColor3 = "Text" },
			TextTransparency = 0.2,
			TextSize = 16,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			TextWrapped = true,
			TextXAlignment = "Left",
			Parent = DropdownFrame,
		}, {
			New("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
		})

		-- ====================================================
		-- Dropdown: Add Flycer Service
		-- ====================================================
		local function AddFlycerService()
			local services = Config.FlycerUI and Config.FlycerUI.Services
			local serviceDef = services and services.flycer
			local serviceIcon = serviceDef and serviceDef.Icon or "key"
			local serviceName = serviceDef and serviceDef.Name or "Flycer"

			local FlycerIconFrame = CreateServiceIcon(serviceIcon, UDim2.fromOffset(24, 24), true)

			local APIFrame = Creator.NewRoundFrame(10, "Squircle", {
				Size = UDim2.new(1, 0, 0, 0),
				ThemeTag = { ImageColor3 = "Text" },
				ImageTransparency = 1,
				Parent = DropdownFrame,
				AutomaticSize = "Y",
			}, {
				New("UIListLayout", {
					FillDirection = "Horizontal",
					Padding = UDim.new(0, 10),
					VerticalAlignment = "Center",
				}),
				FlycerIconFrame,
				New("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
				New("TextLabel", {
					Text = serviceName,
					BackgroundTransparency = 1,
					FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
					ThemeTag = { TextColor3 = "Text" },
					TextSize = 18,
					Size = UDim2.new(1, -34, 0, 0),
					AutomaticSize = "Y",
					TextWrapped = true,
					TextXAlignment = "Left",
				}),
			}, true)

			Creator.AddSignal(APIFrame.MouseEnter, function()
				Tween(APIFrame, 0.08, { ImageTransparency = 0.95 }):Play()
			end)
			Creator.AddSignal(APIFrame.InputEnded, function()
				Tween(APIFrame, 0.08, { ImageTransparency = 1 }):Play()
			end)
			Creator.AddSignal(APIFrame.MouseButton1Click, function()
				local ok, err = pcall(function()
					local Identifier, IdentifierType, IdentifierError = GetFlycerIdentifier(Config)
					OpenFlycerServiceDialog(
						Config,
						Identifier,
						IdentifierType,
						KeyDialog,
						DropdownContainer,
						ChevronDown,
						IdentifierError
					)
				end)

				if not ok then
					Notify(Config, "Flycer", "Unable to open Flycer dialog: " .. tostring(err), "triangle-alert")
				end
			end)
		end

		if Config.KeySystem.KeyValidator or type(Config.KeySystem.Flycer) == "table" then
			AddFlycerService()
		end

		-- ====================================================
		-- Dropdown: Add External API Services
		-- ====================================================
		for _, i in next, (Config.KeySystem.API or {}) do
			if i.Type ~= "flycer" then
				local serviceDef = Config.FlycerUI.Services[i.Type]
				if serviceDef then
					local args = {}
					for _, argName in next, serviceDef.Args do
						table.insert(args, i[argName])
					end

					local serviceOk, serviceInstance = pcall(function()
						return serviceDef.New(table.unpack(args))
					end)

					if not serviceOk or type(serviceInstance) ~= "table" then
						Notify(Config, "Key System", "Unable to initialize service: " .. tostring(i.Type), "triangle-alert")
						continue
					end

					serviceInstance.Type = i.Type
					table.insert(Services, serviceInstance)

					local serviceIcon = i.Icon or serviceDef.Icon or "user"
					local ServiceIconFrame = CreateServiceIcon(serviceIcon, UDim2.fromOffset(24, 24), true)

					local APIFrame = Creator.NewRoundFrame(10, "Squircle", {
						Size = UDim2.new(1, 0, 0, 0),
						ThemeTag = { ImageColor3 = "Text" },
						ImageTransparency = 1,
						Parent = DropdownFrame,
						AutomaticSize = "Y",
					}, {
						New("UIListLayout", {
							FillDirection = "Horizontal",
							Padding = UDim.new(0, 10),
							VerticalAlignment = "Center",
						}),
						ServiceIconFrame,
						New("UIPadding", {
							PaddingTop = UDim.new(0, 10),
							PaddingLeft = UDim.new(0, 10),
							PaddingRight = UDim.new(0, 10),
							PaddingBottom = UDim.new(0, 10),
						}),
						New("Frame", {
							BackgroundTransparency = 1,
							Size = UDim2.new(1, -24 - 10, 0, 0),
							AutomaticSize = "Y",
						}, {
							New("UIListLayout", {
								FillDirection = "Vertical",
								Padding = UDim.new(0, 5),
								HorizontalAlignment = "Center",
							}),
							New("TextLabel", {
								Text = i.Title or serviceDef.Name,
								BackgroundTransparency = 1,
								FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
								ThemeTag = { TextColor3 = "Text" },
								TextTransparency = 0.05,
								TextSize = 18,
								Size = UDim2.new(1, 0, 0, 0),
								AutomaticSize = "Y",
								TextWrapped = true,
								TextXAlignment = "Left",
							}),
							New("TextLabel", {
								Text = i.Desc or "",
								BackgroundTransparency = 1,
								FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),
								ThemeTag = { TextColor3 = "Text" },
								TextTransparency = 0.2,
								TextSize = 16,
								Size = UDim2.new(1, 0, 0, 0),
								AutomaticSize = "Y",
								TextWrapped = true,
								Visible = i.Desc and true or false,
								TextXAlignment = "Left",
							}),
						}),
					}, true)

					Creator.AddSignal(APIFrame.MouseEnter, function()
						Tween(APIFrame, 0.08, { ImageTransparency = 0.95 }):Play()
					end)
					Creator.AddSignal(APIFrame.InputEnded, function()
						Tween(APIFrame, 0.08, { ImageTransparency = 1 }):Play()
					end)
					Creator.AddSignal(APIFrame.MouseButton1Click, function()
						local ok, copied, message = pcall(function()
							if type(serviceInstance.Copy) ~= "function" then
								return false, "Copy is not supported by this service."
							end
							return serviceInstance.Copy()
						end)

						if ok and copied then
							Notify(Config, "Key System", "Key link copied to clipboard.", "key")
						else
							Notify(Config, "Key System", message or "Unable to copy key link.", "triangle-alert")
						end
					end)
				end
			end
		end

		-- ====================================================
		-- Dropdown: Toggle Animation
		-- ====================================================
		Creator.AddSignal(ButtonFrame.MouseButton1Click, function()
			if not Opened then
				Tween(
					DropdownContainer,
					0.3,
					{ Size = UDim2.new(0, Width, 0, DropdownFrame.AbsoluteSize.Y + 1) },
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.Out
				):Play()
				Tween(ChevronDown, 0.3, { Rotation = 180 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
			else
				Tween(
					DropdownContainer,
					0.25,
					{ Size = UDim2.new(0, Width, 0, 0) },
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.Out
				):Play()
				Tween(ChevronDown, 0.25, { Rotation = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
			end
			Opened = not Opened
		end)
	end

	-- ========================================================
	-- HELPER: Handle Success
	-- ========================================================
	local function handleSuccess(key)
		SafeCloseDialog(KeyDialog)

		if Config.KeySystem.SaveKey then
			local folder = Config.Folder or "Temp"
			local path = folder .. "/" .. tostring(Filename) .. ".key"

			local writeOk, writeErr = pcall(function()
				if type(writefile) ~= "function" then
					error("writefile is not available in this executor.")
				end

				-- [FIX] Pastikan folder ada sebelum writefile
				if type(makefolder) == "function" and type(isfolder) == "function" then
					if not isfolder(folder) then
						makefolder(folder)
					end
				end

				writefile(path, tostring(key))
			end)

			if not writeOk then
				Notify(Config, "Key System", "Key verified but unable to save: " .. tostring(writeErr), "triangle-alert")
			end
		end

		task.delay(0.4, function()
			if type(func) == "function" then
				func(true)
			end
		end)

		return true
	end

	-- ========================================================
	-- SUBMIT BUTTON
	-- ========================================================
	local SubmitButton = CreateButton("Submit", "arrow-right", function()
		task.spawn(function()
			local key = EnteredKey
			if not key or tostring(key):gsub("%s+", "") == "" then
				Notify(Config, "Key System", "Please enter a license key.", "triangle-alert")
				return
			end
			key = tostring(key):gsub("^%s+", ""):gsub("%s+$", "")

			-- ====================================================
			-- PATH 1: FLYCER SERVICE
			-- ====================================================
						-- ====================================================
			-- PATH 1: FLYCER SERVICE
			-- ====================================================
			if type(Config.KeySystem.Flycer) == "table" then
				local serviceInstance, serviceError = CreateFlycerService(Config)

				if not serviceInstance then
					Notify(Config, "Key System", serviceError or "Flycer service unavailable.", "triangle-alert")
					return
				end

				if type(serviceInstance.Verify) ~= "function" then
					Notify(Config, "Key System", "Flycer service does not provide Verify().", "triangle-alert")
					return
				end

				-- Validasi key langsung (aman di dalam task.spawn)
				local verifyValid, verifyMessage, verifyData = serviceInstance.Verify(key)

				if verifyValid then
					-- Ambil informasi license dari response API
					local licenseInfo
					if type(verifyData) == "table" then
						licenseInfo = verifyData.license
					end

					local expireTimestamp
					local keyType

					if type(licenseInfo) == "table" then
						expireTimestamp = tonumber(licenseInfo.expires_at)
						keyType = tostring(licenseInfo.key_type or ""):lower()
					end

					-- Hentikan countdown sebelumnya
					if StopCountdown then
						StopCountdown()
						StopCountdown = nil
					end

					-- Hapus Tag expiry sebelumnya
					if ExpiryTag then
						pcall(function() ExpiryTag:Destroy() end)
						ExpiryTag = nil
					end

					-- ====================================================
					-- [FIX RACE CONDITION] Smart Deferred Tag Creation
					-- Menunggu Config.Window terinisialisasi secara asinkronus
					-- ====================================================
					task.spawn(function()
						local timeout = 5 -- Maksimal menunggu 5 detik
						local elapsed = 0

						-- Lakukan polling non-blocking setiap 0.1 detik
						while not (Config.Window and type(Config.Window.Tag) == "function") and elapsed < timeout do
							task.wait(0.1)
							elapsed = elapsed + 0.1
						end

						local windowExists = Config.Window and type(Config.Window.Tag) == "function"

						if windowExists then
							-- DURATION KEY
							if expireTimestamp and expireTimestamp > 0 then
								local tagOk, tagResult = pcall(function()
									return Config.Window:Tag({
										Title = FormatCountdown(expireTimestamp),
										Icon = "clock-3",
										Color = Color3.fromHex("#315dff"),
									})
								end)

								if tagOk then
									ExpiryTag = tagResult
									StopCountdown = StartCountdown(expireTimestamp, function(text)
										if ExpiryTag and type(ExpiryTag.SetTitle) == "function" then
											pcall(function()
												ExpiryTag:SetTitle(text)
											end)
										end
									end)
								end

							-- LIFETIME KEY
							elseif keyType == "lifetime" then
								pcall(function()
									ExpiryTag = Config.Window:Tag({
										Title = "Lifetime",
										Icon = "infinity",
										Color = Color3.fromHex("#315dff"),
									})
								end)
							end
						else
							-- Muncul hanya jika inisialisasi Window gagal total melewati batas 5 detik
							warn("[FlycerUI KeySystem] Timeout reached. Config.Window was not initialized within " .. tostring(timeout) .. "s.")
						end
					end)

					-- Alur penutupan dialog & pemuatan script cheat berjalan seketika (Instant UX)
					handleSuccess(key)
				else
					Notify(Config, "Key System", verifyMessage or "Invalid key.", "triangle-alert")
				end

				return
			end

					-- ====================================================
					-- [FIX RUNTIME ERROR] Safe Check untuk Config.Window
					-- ====================================================
					local windowExists = Config.Window and type(Config.Window.Tag) == "function"

					-- DURATION KEY
					if expireTimestamp and expireTimestamp > 0 then
						if windowExists then
							local tagOk, tagResult = pcall(function()
								return Config.Window:Tag({
									Title = FormatCountdown(expireTimestamp),
									Icon = "clock-3",
									Color = Color3.fromHex("#315dff"),
								})
							end)

							if tagOk then
								ExpiryTag = tagResult
								StopCountdown = StartCountdown(expireTimestamp, function(text)
									if ExpiryTag and type(ExpiryTag.SetTitle) == "function" then
										pcall(function()
											ExpiryTag:SetTitle(text)
										end)
									end
								end)
							end
						else
							warn("[FlycerUI KeySystem] Config.Window is not initialized yet. Skipping Expiry Tag creation.")
						end

					-- LIFETIME KEY
					elseif keyType == "lifetime" then
						if windowExists then
							pcall(function()
								ExpiryTag = Config.Window:Tag({
									Title = "Lifetime",
									Icon = "infinity",
									Color = Color3.fromHex("#315dff"),
								})
							end)
						else
							warn("[FlycerUI KeySystem] Config.Window is not initialized yet. Skipping Lifetime Tag creation.")
						end
					end

					handleSuccess(key)
				else
					Notify(Config, "Key System", verifyMessage or "Invalid key.", "triangle-alert")
				end

				return
			end

			-- ====================================================
			-- PATH 2: CUSTOM KEY VALIDATOR
			-- ====================================================
			if Config.KeySystem.KeyValidator then
				local validatorOk, isValid, validationMessage = pcall(function()
					return Config.KeySystem.KeyValidator(key)
				end)

				if not validatorOk then
					Notify(Config, "Key System", "Key validator error: " .. tostring(isValid), "triangle-alert")
					return
				end

				if isValid then
					handleSuccess(key)
				else
					Notify(Config, "Key System", validationMessage or "Invalid key.", "triangle-alert")
				end
				return
			end

			-- ====================================================
			-- PATH 3: STATIC KEY
			-- ====================================================
			if not Config.KeySystem.API then
				local isKey = false
				if type(Config.KeySystem.Key) == "table" then
					isKey = table.find(Config.KeySystem.Key, key) ~= nil
				else
					isKey = Config.KeySystem.Key == key
				end

				if isKey then
					handleSuccess(key)
				else
					Notify(Config, "Key System", "Invalid key.", "triangle-alert")
				end
				return
			end

			-- ====================================================
			-- PATH 4: API SERVICES
			-- ====================================================
			if #Services == 0 then
				Notify(Config, "Key System", "No key validation service is configured.", "triangle-alert")
				return
			end

			local isSuccess, result = false, nil
			for _, service in next, Services do
				if type(service.Verify) == "function" then
					local success, res = service.Verify(key)
					if success then
						isSuccess = true
						result = res
						break
					end
					result = res or "Verification failed."
				end
			end

			if isSuccess then
				handleSuccess(key)
			else
				Notify(Config, "Key System", result or "Invalid key.", "triangle-alert")
			end
		end)
	end, "Primary", ButtonsContainer)

	SubmitButton.AnchorPoint = Vector2.new(1, 0.5)
	SubmitButton.Position = UDim2.new(1, 0, 0.5, 0)

	KeyDialog:Open()
end

return KeySystem
