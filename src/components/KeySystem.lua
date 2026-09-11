local KeySystem = {}

local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

local CreateButton = require("./ui/Button").New
local CreateInput = require("./ui/Input").New

----------------------------------------------------------------
-- CLIPBOARD
----------------------------------------------------------------

local function CopyToClipboard(value)
	if value == nil then
		return false
	end

	value = tostring(value)

	if value == "" then
		return false
	end

	local copy = setclipboard or toclipboard

	if type(copy) ~= "function" then
		return false
	end

	local ok = pcall(function()
		copy(value)
	end)

	return ok
end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------

local function Notify(Config, title, content, icon, image)
	if not Config or not Config.FlycerUI or type(Config.FlycerUI.Notify) ~= "function" then
		return
	end

	local data = {
		Title = title or "Key System",
		Content = tostring(content or ""),
	}

	if icon then
		data.Icon = icon
	end

	if image then
		data.Image = image
	end

	pcall(function()
		Config.FlycerUI:Notify(data)
	end)
end

local function Trim(value)
	value = tostring(value or "")

	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

----------------------------------------------------------------
-- FLYCER SERVICE
----------------------------------------------------------------

local CreateFlycerService

----------------------------------------------------------------
-- FLYCER IDENTIFIER
----------------------------------------------------------------

-- Username:
--     Roblox UserId
--
-- Device:
--     Executor HWID jika tersedia
--     lalu fallback ke Roblox ClientId
--
-- Returns:
--     identifier, identifierType, errorMessage
----------------------------------------------------------------

local function GetFlycerIdentifier(Config)
	if type(Config) ~= "table" then
		return nil, "Invalid", "Invalid Flycer configuration."
	end

	if type(Config.KeySystem) ~= "table" then
		return nil, "Invalid", "Flycer configuration is missing."
	end

	local serviceInstance, serviceError = CreateFlycerService(Config)

	if not serviceInstance then
		return nil, "Invalid", serviceError or "Flycer service is unavailable."
	end

	if type(serviceInstance.GetIdentifier) ~= "function" then
		return nil, "Invalid", "Flycer service does not support identifier detection."
	end

	local ok, identifier, identifierType, identifierError = pcall(function()
		return serviceInstance.GetIdentifier()
	end)

	if not ok then
		return nil, "Invalid", "Unable to determine Flycer identifier."
	end

	if identifier == nil or tostring(identifier) == "" then
		return nil, identifierType or "Invalid", identifierError or "Unable to determine Flycer identifier."
	end

	return tostring(identifier), identifierType, identifierError
end

KeySystem.GetFlycerIdentifier = GetFlycerIdentifier

----------------------------------------------------------------
-- CREATE FLYCER SERVICE
----------------------------------------------------------------

CreateFlycerService = function(Config)
	if type(Config) ~= "table" then
		return nil, "Invalid Flycer configuration."
	end

	if type(Config.KeySystem) ~= "table" then
		return nil, "KeySystem configuration is missing."
	end

	local flycerConfig = Config.KeySystem.Flycer

	if type(flycerConfig) ~= "table" then
		return nil, "Flycer configuration is missing."
	end

	local endpoint = Trim(flycerConfig.Endpoint)

	if endpoint == "" then
		return nil, "Flycer API Endpoint is not configured."
	end

	if not Config.FlycerUI then
		return nil, "FlycerUI instance is unavailable."
	end

	if not Config.FlycerUI.Services then
		return nil, "FlycerUI services are unavailable."
	end

	local serviceData = Config.FlycerUI.Services.flycer

	if type(serviceData) ~= "table" then
		return nil, "Flycer service definition is unavailable."
	end

	if type(serviceData.New) ~= "function" then
		return nil, "Flycer service constructor is unavailable."
	end

	local product = flycerConfig.Product or Config.Title or "default"

	local lockType = flycerConfig.LockType or Config.KeySystem.LockType or "Device"

	local client = flycerConfig.Client or "FlycerUI"

	local version = flycerConfig.Version or "1.0.0"

	local ok, serviceInstance, serviceError = pcall(function()
		return serviceData.New(endpoint, product, lockType, client, version)
	end)

	if not ok then
		return nil, "Failed to create Flycer service: " .. tostring(serviceInstance)
	end

	if not serviceInstance then
		return nil, serviceError or "Flycer service could not be created."
	end

	return serviceInstance
end

----------------------------------------------------------------
-- FLYCER SERVICE DIALOG
----------------------------------------------------------------

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

	----------------------------------------------------------------
	-- HIDE ORIGINAL KEY DIALOG
	----------------------------------------------------------------

	if DropdownContainer then
		DropdownContainer.Size = UDim2.new(0, 0, 0, 0)
	end

	if ChevronDown then
		ChevronDown.Rotation = 0
	end

	if KeyDialog and KeyDialog.UIElements and KeyDialog.UIElements.MainContainer then
		KeyDialog.UIElements.MainContainer.Visible = false
	end

	local Closed = false

	----------------------------------------------------------------
	-- CLOSE
	----------------------------------------------------------------

	local function CloseFlycerDialog()
		if Closed then
			return
		end

		Closed = true

		pcall(function()
			Dialog:Close()()
		end)

		task.delay(0.12, function()
			if KeyDialog and KeyDialog.UIElements and KeyDialog.UIElements.MainContainer then
				KeyDialog.UIElements.MainContainer.Visible = true
			end
		end)
	end

	----------------------------------------------------------------
	-- DIALOG SIZE
	----------------------------------------------------------------

	Dialog.UIElements.Main.AutomaticSize = "Y"
	Dialog.UIElements.Main.Size = UDim2.new(0, 470, 0, 0)

	----------------------------------------------------------------
	-- FLYCER SERVICE CONFIG
	----------------------------------------------------------------

	local serviceDef

	if Config.FlycerUI and Config.FlycerUI.Services then
		serviceDef = Config.FlycerUI.Services.flycer
	end

	local serviceName = (serviceDef and serviceDef.Name) or "Flycer"

	local serviceIcon = (serviceDef and serviceDef.Icon) or "key"

	----------------------------------------------------------------
	-- TITLE ICON
	----------------------------------------------------------------

	local TitleIcon = New("ImageLabel", {
		Image = serviceIcon,

		BackgroundTransparency = 1,

		Size = UDim2.fromOffset(24, 24),

		ScaleType = Enum.ScaleType.Fit,
	})

	----------------------------------------------------------------
	-- TITLE
	----------------------------------------------------------------

	local Title = New("TextLabel", {
		Text = serviceName,

		BackgroundTransparency = 1,

		AutomaticSize = "XY",

		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),

		ThemeTag = {
			TextColor3 = "Text",
		},

		TextSize = 20,
	})

	----------------------------------------------------------------
	-- DESCRIPTION
	----------------------------------------------------------------

	local DescriptionText = "Choose an action below."

	if IdentifierType and Identifier then
		DescriptionText = "Current " .. tostring(IdentifierType) .. " identifier is ready to use."
	end

	if IdentifierError then
		DescriptionText = tostring(IdentifierError)
	end

	local Description = New("TextLabel", {
		Text = DescriptionText,

		BackgroundTransparency = 1,

		Size = UDim2.new(1, 0, 0, 0),

		AutomaticSize = "Y",

		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),

		ThemeTag = {
			TextColor3 = "Text",
		},

		TextTransparency = 0.35,

		TextSize = 16,

		TextWrapped = true,

		TextXAlignment = "Left",
	})

	----------------------------------------------------------------
	-- IDENTIFIER LABEL
	----------------------------------------------------------------

	local IdentifierLabel = New("TextLabel", {
		Text = Identifier
				and (tostring(IdentifierType or "Identifier") .. ": " .. tostring(Identifier))
			or "Identifier unavailable.",

		BackgroundTransparency = 1,

		Size = UDim2.new(1, 0, 0, 0),

		AutomaticSize = "Y",

		FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),

		ThemeTag = {
			TextColor3 = "Text",
		},

		TextTransparency = 0.2,

		TextSize = 14,

		TextWrapped = true,

		TextXAlignment = "Left",
	})

	----------------------------------------------------------------
	-- BUTTON CONTAINER
	----------------------------------------------------------------

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

	----------------------------------------------------------------
	-- CLOSE BUTTON
	----------------------------------------------------------------

	local CloseButton = CreateButton("Close", "x", function()
		CloseFlycerDialog()
	end, "Tertiary", Buttons)

	----------------------------------------------------------------
	-- COPY HWID
	----------------------------------------------------------------

	local CopyButton = CreateButton("Copy HWID", "copy", function()
		if not Identifier then
			Notify(Config, "Flycer", IdentifierError or "Identifier is not available.", "triangle-alert")

			return
		end

		if CopyToClipboard(Identifier) then
			Notify(Config, "Flycer", tostring(IdentifierType or "Identifier") .. " copied to clipboard.", nil, "copy")
		else
			Notify(Config, "Flycer", "Clipboard is not available in this executor.", "triangle-alert")
		end
	end, "Primary", Buttons)

	----------------------------------------------------------------
	-- DISCORD
	----------------------------------------------------------------

	local Discord = Config.KeySystem.Discord or Config.KeySystem.DiscordURL

	local DiscordButton

	if Discord and Trim(Discord) ~= "" then
		DiscordButton = CreateButton("Discord", "message-circle", function()
			if CopyToClipboard(Discord) then
				Notify(Config, "Flycer", "Discord link copied to clipboard.", nil, "message-circle")
			else
				Notify(Config, "Flycer", "Clipboard is not available in this executor.", "triangle-alert")
			end
		end, "Secondary", Buttons)
	end

	----------------------------------------------------------------
	-- BUTTON SIZES
	----------------------------------------------------------------

	CloseButton.Size = UDim2.new(0, 105, 0, 42)

	CopyButton.Size = UDim2.new(0, 145, 0, 42)

	if DiscordButton then
		DiscordButton.Size = UDim2.new(0, 125, 0, 42)
	end

	----------------------------------------------------------------
	-- TITLE CONTAINER
	----------------------------------------------------------------

	local TitleContainer = New("Frame", {
		BackgroundTransparency = 1,

		Size = UDim2.new(1, 0, 0, 35),
	}, {
		New("UIListLayout", {
			FillDirection = "Horizontal",

			VerticalAlignment = "Center",

			Padding = UDim.new(0, 10),
		}),

		TitleIcon,
		Title,
	})

	----------------------------------------------------------------
	-- MAIN CONTENT
	----------------------------------------------------------------

	New("Frame", {
		BackgroundTransparency = 1,

		Size = UDim2.new(1, 0, 0, 0),

		AutomaticSize = "Y",

		Parent = Dialog.UIElements.Main,
	}, {
		New("UIListLayout", {
			FillDirection = "Vertical",

			Padding = UDim.new(0, 12),
		}),

		TitleContainer,

		Description,

		IdentifierLabel,

		Buttons,

		New("UIPadding", {
			PaddingTop = UDim.new(0, 16),

			PaddingLeft = UDim.new(0, 16),

			PaddingRight = UDim.new(0, 16),

			PaddingBottom = UDim.new(0, 16),
		}),
	})

	----------------------------------------------------------------
	-- OPEN
	----------------------------------------------------------------

	Dialog:Open()
end

----------------------------------------------------------------
-- KEY SYSTEM
----------------------------------------------------------------

function KeySystem.new(Config, Filename, func, keyValidator)
	local KeyDialogInit = require("./window/Dialog")

	local KeyDialog =
		KeyDialogInit.Create(true, "Popup", Config.Window, Config.FlycerUI, Config.FlycerUI.ScreenGui.KeySystem)

	local Services = {}

	local EnteredKey = ""

	----------------------------------------------------------------
	-- KEY SYSTEM CONFIG
	----------------------------------------------------------------

	local KeyConfig = Config.KeySystem

	if type(KeyConfig) ~= "table" then
		KeyConfig = {}
	end

	----------------------------------------------------------------
	-- UI SIZE
	----------------------------------------------------------------

	local ThumbnailSize = (KeyConfig.Thumbnail and KeyConfig.Thumbnail.Width) or 200

	local UISize = 430

	if KeyConfig.Thumbnail and KeyConfig.Thumbnail.Image then
		UISize = 430 + (ThumbnailSize / 2)
	end

	KeyDialog.UIElements.Main.AutomaticSize = "Y"

	KeyDialog.UIElements.Main.Size = UDim2.new(0, UISize, 0, 0)

	----------------------------------------------------------------
	-- ICON
	----------------------------------------------------------------

	local IconFrame

	if Config.Icon then
		IconFrame =
			Creator.Image(Config.Icon, Config.Title .. ":" .. Config.Icon, 0, "Temp", "KeySystem", Config.IconThemed)

		IconFrame.Size = UDim2.new(0, 24, 0, 24)

		IconFrame.LayoutOrder = -1
	end

	----------------------------------------------------------------
	-- TITLE
	----------------------------------------------------------------

	local Title = New("TextLabel", {
		AutomaticSize = "XY",

		BackgroundTransparency = 1,

		Text = KeyConfig.Title or Config.Title,

		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),

		ThemeTag = {
			TextColor3 = "Text",
		},

		TextSize = 20,
	})

	----------------------------------------------------------------
	-- KEY SYSTEM TITLE
	----------------------------------------------------------------

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

	----------------------------------------------------------------
	-- ICON + TITLE
	----------------------------------------------------------------

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

	----------------------------------------------------------------
	-- INPUT
	----------------------------------------------------------------

	local InputFrame = CreateInput("Enter Key", "key", nil, "Input", function(key)
		EnteredKey = Trim(key)
	end)

	----------------------------------------------------------------
	-- NOTE
	----------------------------------------------------------------

	local NoteText

	if KeyConfig.Note and KeyConfig.Note ~= "" then
		NoteText = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),

			AutomaticSize = "Y",

			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),

			TextXAlignment = "Left",

			Text = KeyConfig.Note,

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

	----------------------------------------------------------------
	-- BUTTON CONTAINER
	----------------------------------------------------------------

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
				Padding = UDim.new(0, 9),

				FillDirection = "Horizontal",
			}),
		}),
	})

	----------------------------------------------------------------
	-- THUMBNAIL
	----------------------------------------------------------------

	local ThumbnailFrame

	if KeyConfig.Thumbnail and KeyConfig.Thumbnail.Image then
		local ThumbnailTitle

		if KeyConfig.Thumbnail.Title then
			ThumbnailTitle = New("TextLabel", {
				Text = KeyConfig.Thumbnail.Title,

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
			Image = KeyConfig.Thumbnail.Image,

			BackgroundTransparency = 1,

			Size = UDim2.new(0, ThumbnailSize, 1, -12),

			Position = UDim2.new(0, 6, 0, 6),

			Parent = KeyDialog.UIElements.Main,

			ScaleType = "Crop",
		}, {
			ThumbnailTitle,

			New("UICorner", {
				CornerRadius = UDim.new(0, 20),
			}),
		})
	end

	----------------------------------------------------------------
	-- MAIN FRAME
	----------------------------------------------------------------

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

	----------------------------------------------------------------
	-- EXIT BUTTON
	----------------------------------------------------------------

	local ExitButton = CreateButton("Exit", "log-out", function()
		KeyDialog:Close()()
	end, "Tertiary", ButtonsContainer.Frame)

	if ThumbnailFrame then
		ExitButton.Parent = ThumbnailFrame

		ExitButton.Size = UDim2.new(0, 0, 0, 42)

		ExitButton.Position = UDim2.new(0, 10, 1, -10)

		ExitButton.AnchorPoint = Vector2.new(0, 1)
	end

	----------------------------------------------------------------
	-- SIMPLE GET KEY
	----------------------------------------------------------------

	if KeyConfig.URL and not KeyConfig.KeyValidator and not KeyConfig.Flycer then
		CreateButton("Get key", "key", function()
			if CopyToClipboard(KeyConfig.URL) then
				Notify(Config, "Key System", "Key link copied to clipboard.", nil, "key")
			else
				Notify(Config, "Key System", "Clipboard is not available.", "triangle-alert")
			end
		end, "Secondary", ButtonsContainer.Frame)
	end

	----------------------------------------------------------------
	-- SERVICE DROPDOWN
	----------------------------------------------------------------

	if KeyConfig.API or KeyConfig.KeyValidator or type(KeyConfig.Flycer) == "table" then
		local Width = 240
		local Opened = false

		local ButtonFrame = CreateButton("Get key", "key", nil, "Secondary", ButtonsContainer.Frame)

		----------------------------------------------------------------
		-- DIVIDER
		----------------------------------------------------------------

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

		----------------------------------------------------------------
		-- CHEVRON
		----------------------------------------------------------------

		local ChevronDown = Creator.Image("chevron-down", "chevron-down", 0, "Temp", "KeySystem", true)

		ChevronDown.Size = UDim2.new(1, 0, 1, 0)

		local IconContainer = New("Frame", {
			Size = UDim2.new(0, 21, 0, 21),

			Parent = ButtonFrame.Frame,

			BackgroundTransparency = 1,
		}, {
			ChevronDown,
		})

		----------------------------------------------------------------
		-- DROPDOWN FRAME
		----------------------------------------------------------------

		local DropdownFrame = Creator.NewRoundFrame(15, "Squircle", {
			Size = UDim2.new(1, 0, 0, 0),

			AutomaticSize = "Y",

			ThemeTag = {
				ImageColor3 = "Background",
			},
		}, {
			New("UIPadding", {
				PaddingTop = UDim.new(0, 5),

				PaddingLeft = UDim.new(0, 5),

				PaddingRight = UDim.new(0, 5),

				PaddingBottom = UDim.new(0, 5),
			}),

			New("UIListLayout", {
				FillDirection = "Vertical",

				Padding = UDim.new(0, 5),
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

		----------------------------------------------------------------
		-- SELECT SERVICE LABEL
		----------------------------------------------------------------

		New("TextLabel", {
			Text = "Select Service",

			BackgroundTransparency = 1,

			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),

			ThemeTag = {
				TextColor3 = "Text",
			},

			TextTransparency = 0.2,

			TextSize = 16,

			Size = UDim2.new(1, 0, 0, 0),

			AutomaticSize = "Y",

			TextWrapped = true,

			TextXAlignment = "Left",

			Parent = DropdownFrame,
		}, {
			New("UIPadding", {
				PaddingTop = UDim.new(0, 8),

				PaddingLeft = UDim.new(0, 10),

				PaddingRight = UDim.new(0, 10),

				PaddingBottom = UDim.new(0, 8),
			}),
		})

		----------------------------------------------------------------
		-- ADD FLYCER SERVICE
		----------------------------------------------------------------

		local function AddFlycerService()
			local serviceDef

			if Config.FlycerUI and Config.FlycerUI.Services then
				serviceDef = Config.FlycerUI.Services.flycer
			end

			if not serviceDef then
				return
			end

			local serviceIcon = serviceDef.Icon or "key"

			local serviceName = serviceDef.Name or "Flycer"

			--------------------------------------------------------
			-- ICON
			--------------------------------------------------------

			local IconFrame = Creator.Image(serviceIcon, serviceIcon, 0, "Temp", "KeySystem", true)

			IconFrame.Size = UDim2.new(0, 24, 0, 24)

			--------------------------------------------------------
			-- SERVICE BUTTON
			--------------------------------------------------------

			local APIFrame = Creator.NewRoundFrame(10, "Squircle", {
				Size = UDim2.new(1, 0, 0, 0),

				ThemeTag = {
					ImageColor3 = "Text",
				},

				ImageTransparency = 1,

				Parent = DropdownFrame,

				AutomaticSize = "Y",
			}, {
				New("UIListLayout", {
					FillDirection = "Horizontal",

					Padding = UDim.new(0, 10),

					VerticalAlignment = "Center",
				}),

				New("UIPadding", {
					PaddingTop = UDim.new(0, 10),

					PaddingLeft = UDim.new(0, 10),

					PaddingRight = UDim.new(0, 10),

					PaddingBottom = UDim.new(0, 10),
				}),

				IconFrame,

				New("TextLabel", {
					Text = serviceName,

					BackgroundTransparency = 1,

					FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),

					ThemeTag = {
						TextColor3 = "Text",
					},

					TextSize = 18,

					Size = UDim2.new(1, -34, 0, 0),

					AutomaticSize = "Y",

					TextWrapped = true,

					TextXAlignment = "Left",
				}),
			}, true)

			--------------------------------------------------------
			-- HOVER
			--------------------------------------------------------

			Creator.AddSignal(APIFrame.MouseEnter, function()
				Tween(APIFrame, 0.08, {
					ImageTransparency = 0.95,
				}):Play()
			end)

			Creator.AddSignal(APIFrame.InputEnded, function()
				Tween(APIFrame, 0.08, {
					ImageTransparency = 1,
				}):Play()
			end)

			--------------------------------------------------------
			-- CLICK
			--------------------------------------------------------

			Creator.AddSignal(APIFrame.MouseButton1Click, function()
				local Identifier
				local IdentifierType
				local IdentifierError

				local ok, err = pcall(function()
					Identifier, IdentifierType, IdentifierError = GetFlycerIdentifier(Config)
				end)

				if not ok then
					Identifier = nil
					IdentifierType = "Invalid"
					IdentifierError = "Unable to determine Flycer identifier."
				end

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
		end

		----------------------------------------------------------------
		-- FLYCER
		----------------------------------------------------------------

		if KeyConfig.KeyValidator or type(KeyConfig.Flycer) == "table" then
			AddFlycerService()
		end

		----------------------------------------------------------------
		-- OTHER API SERVICES
		----------------------------------------------------------------

		for _, serviceConfig in next, (KeyConfig.API or {}) do
			if serviceConfig.Type ~= "flycer" then
				local serviceDef = Config.FlycerUI.Services and Config.FlycerUI.Services[serviceConfig.Type]

				if serviceDef then
					local args = {}

					for _, argName in next, serviceDef.Args do
						table.insert(args, serviceConfig[argName])
					end

					local serviceOk, serviceInstance = pcall(function()
						return serviceDef.New(table.unpack(args))
					end)

					if serviceOk and serviceInstance then
						serviceInstance.Type = serviceConfig.Type

						table.insert(Services, serviceInstance)

						------------------------------------------------
						-- SERVICE ICON
						------------------------------------------------

						local serviceIcon = serviceConfig.Icon or serviceDef.Icon or "user"

						local IconFrame = Creator.Image(serviceIcon, serviceIcon, 0, "Temp", "KeySystem", true)

						IconFrame.Size = UDim2.new(0, 24, 0, 24)

						------------------------------------------------
						-- SERVICE FRAME
						------------------------------------------------

						local APIFrame = Creator.NewRoundFrame(10, "Squircle", {
							Size = UDim2.new(1, 0, 0, 0),

							ThemeTag = {
								ImageColor3 = "Text",
							},

							ImageTransparency = 1,

							Parent = DropdownFrame,

							AutomaticSize = "Y",
						}, {
							New("UIListLayout", {
								FillDirection = "Horizontal",

								Padding = UDim.new(0, 10),

								VerticalAlignment = "Center",
							}),

							New("UIPadding", {
								PaddingTop = UDim.new(0, 10),

								PaddingLeft = UDim.new(0, 10),

								PaddingRight = UDim.new(0, 10),

								PaddingBottom = UDim.new(0, 10),
							}),

							IconFrame,

							New("Frame", {
								BackgroundTransparency = 1,

								Size = UDim2.new(1, -34, 0, 0),

								AutomaticSize = "Y",
							}, {
								New("UIListLayout", {
									FillDirection = "Vertical",

									Padding = UDim.new(0, 5),

									HorizontalAlignment = "Center",
								}),

								New("TextLabel", {
									Text = serviceConfig.Title or serviceDef.Name,

									BackgroundTransparency = 1,

									FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),

									ThemeTag = {
										TextColor3 = "Text",
									},

									TextTransparency = 0.05,

									TextSize = 18,

									Size = UDim2.new(1, 0, 0, 0),

									AutomaticSize = "Y",

									TextWrapped = true,

									TextXAlignment = "Left",
								}),

								New("TextLabel", {
									Text = serviceConfig.Desc or "",

									BackgroundTransparency = 1,

									FontFace = Font.new(Creator.Font, Enum.FontWeight.Regular),

									ThemeTag = {
										TextColor3 = "Text",
									},

									TextTransparency = 0.2,

									TextSize = 16,

									Size = UDim2.new(1, 0, 0, 0),

									AutomaticSize = "Y",

									TextWrapped = true,

									Visible = serviceConfig.Desc and true or false,

									TextXAlignment = "Left",
								}),
							}),
						}, true)

						------------------------------------------------
						-- HOVER
						------------------------------------------------

						Creator.AddSignal(APIFrame.MouseEnter, function()
							Tween(APIFrame, 0.08, {
								ImageTransparency = 0.95,
							}):Play()
						end)

						Creator.AddSignal(APIFrame.InputEnded, function()
							Tween(APIFrame, 0.08, {
								ImageTransparency = 1,
							}):Play()
						end)

						------------------------------------------------
						-- COPY
						------------------------------------------------

						Creator.AddSignal(APIFrame.MouseButton1Click, function()
							local copyOk = pcall(function()
								serviceInstance.Copy()
							end)

							if copyOk then
								Notify(Config, "Key System", "Key link copied to clipboard.", nil, "key")
							else
								Notify(Config, "Key System", "Unable to copy key link.", "triangle-alert")
							end
						end)
					end
				end
			end
		end

		----------------------------------------------------------------
		-- DROPDOWN TOGGLE
		----------------------------------------------------------------

		Creator.AddSignal(ButtonFrame.MouseButton1Click, function()
			if not Opened then
				Tween(DropdownContainer, 0.3, {
					Size = UDim2.new(0, Width, 0, DropdownFrame.AbsoluteSize.Y + 1),
				}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

				Tween(ChevronDown, 0.3, {
					Rotation = 180,
				}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
			else
				Tween(DropdownContainer, 0.25, {
					Size = UDim2.new(0, Width, 0, 0),
				}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()

				Tween(ChevronDown, 0.25, {
					Rotation = 0,
				}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out):Play()
			end

			Opened = not Opened
		end)
	end

	----------------------------------------------------------------
	-- SUCCESS HANDLER
	----------------------------------------------------------------

	local function handleSuccess(key)
		key = Trim(key)

		if key == "" then
			Notify(Config, "Key System. Error", "Key is empty.", "triangle-alert")

			return false
		end

		----------------------------------------------------------------
		-- SAVE KEY
		----------------------------------------------------------------

		if KeyConfig.SaveKey then
			local folder = Config.Folder or Config.Title or "Temp"

			local path = tostring(folder) .. "/" .. tostring(Filename) .. ".key"

			local writeOk, writeError = pcall(function()
				writefile(path, tostring(key))
			end)

			if not writeOk then
				Notify(Config, "Key System. Error", "Failed to save key: " .. tostring(writeError), "triangle-alert")

				return false
			end
		end

		----------------------------------------------------------------
		-- CLOSE
		----------------------------------------------------------------

		pcall(function()
			KeyDialog:Close()()
		end)

		task.wait(0.4)

		if type(func) == "function" then
			pcall(function()
				func(true)
			end)
		end

		return true
	end

	----------------------------------------------------------------
	-- SUBMIT BUTTON
	----------------------------------------------------------------

	local SubmitButton = CreateButton("Submit", "arrow-right", function()
		local key = Trim(EnteredKey)

		----------------------------------------------------------------
		-- EMPTY KEY
		----------------------------------------------------------------

		if key == "" then
			Notify(Config, "Key System. Error", "Please enter a license key.", "triangle-alert")

			return
		end

		----------------------------------------------------------------
		-- FLYCER
		----------------------------------------------------------------

		if type(KeyConfig.Flycer) == "table" then
			--------------------------------------------------------
			-- CREATE SERVICE
			--------------------------------------------------------

			local createOk, serviceInstance, serviceError = pcall(function()
				return CreateFlycerService(Config)
			end)

			if not createOk then
				Notify(
					Config,
					"Key System. Error",
					"Flycer service error: " .. tostring(serviceInstance),
					"triangle-alert"
				)

				return
			end

			if not serviceInstance then
				Notify(
					Config,
					"Key System. Error",
					tostring(serviceError or "Unable to create Flycer service."),
					"triangle-alert"
				)

				return
			end

			--------------------------------------------------------
			-- VERIFY
			--------------------------------------------------------

			if type(serviceInstance.Verify) ~= "function" then
				Notify(
					Config,
					"Key System. Error",
					"Flycer service does not support key verification.",
					"triangle-alert"
				)

				return
			end

			local verifyOk, verifyResult, verifyMessage, verifyResponse = pcall(function()
				return serviceInstance.Verify(key)
			end)

			if not verifyOk then
				Notify(Config, "Key System. Error", "Flycer Verify error: " .. tostring(verifyResult), "triangle-alert")

				return
			end

			--------------------------------------------------------
			-- VALID
			--------------------------------------------------------

			if verifyResult == true then
				local success = handleSuccess(key)

				if not success then
					return
				end
			else
				Notify(
					Config,
					"Key System. Error",
					tostring(verifyMessage or "License validation failed."),
					"triangle-alert"
				)
			end

			return
		end

		----------------------------------------------------------------
		-- KEY VALIDATOR
		----------------------------------------------------------------

		if KeyConfig.KeyValidator then
			local validatorOk, isValid, validationMessage = pcall(function()
				return KeyConfig.KeyValidator(key)
			end)

			if not validatorOk then
				Notify(Config, "Key System. Error", "KeyValidator error: " .. tostring(isValid), "triangle-alert")

				return
			end

			if isValid then
				handleSuccess(key)
			else
				Notify(Config, "Key System. Error", validationMessage or "Invalid key.", "triangle-alert")
			end

			return
		end

		----------------------------------------------------------------
		-- STATIC KEY
		----------------------------------------------------------------

		if not KeyConfig.API then
			local isKey = false

			if type(KeyConfig.Key) == "table" then
				isKey = table.find(KeyConfig.Key, key) ~= nil
			else
				isKey = KeyConfig.Key == key
			end

			if isKey then
				handleSuccess(key)
			else
				Notify(Config, "Key System. Error", "Invalid key.", "triangle-alert")
			end

			return
		end

		----------------------------------------------------------------
		-- OTHER API SERVICES
		----------------------------------------------------------------

		local isSuccess = false
		local result = "Invalid key."

		for _, service in next, Services do
			if type(service.Verify) == "function" then
				local verifyOk, success, message = pcall(function()
					return service.Verify(key)
				end)

				if not verifyOk then
					result = "Service verification error: " .. tostring(success)
				elseif success then
					isSuccess = true
					result = message or "Authenticated."

					break
				else
					result = message or "Invalid key."
				end
			end
		end

		if isSuccess then
			handleSuccess(key)
		else
			Notify(Config, "Key System. Error", result, "triangle-alert")
		end
	end, "Primary", ButtonsContainer.Frame)

	SubmitButton.AnchorPoint = Vector2.new(1, 0.5)

	SubmitButton.Position = UDim2.new(1, 0, 0.5, 0)

	----------------------------------------------------------------
	-- OPEN
	----------------------------------------------------------------

	KeyDialog:Open()
end

return KeySystem
