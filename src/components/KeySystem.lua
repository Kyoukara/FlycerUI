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
	if not value or value == "" then
		return false
	end

	local copy = setclipboard or toclipboard

	if type(copy) ~= "function" then
		return false
	end

	local ok = pcall(function()
		copy(tostring(value))
	end)

	return ok
end

----------------------------------------------------------------
-- FLYCER SERVICE
----------------------------------------------------------------

-- Forward declaration.
-- GetFlycerIdentifier dan Submit menggunakan constructor yang sama.
local CreateFlycerService

----------------------------------------------------------------
-- FLYCER IDENTIFIER
----------------------------------------------------------------

-- Returns the identifier used by Flycer's selected lock mode.
-- Username -> Roblox UserId
-- Device   -> executor HWID, then Roblox Client ID
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

----------------------------------------------------------------
-- CREATE FLYCER SERVICE
----------------------------------------------------------------

-- Build the Flycer validator from the same configuration
-- used by Init.lua.
CreateFlycerService = function(Config)
	local flycerConfig = Config.KeySystem and Config.KeySystem.Flycer

	if type(flycerConfig) ~= "table" then
		return nil, "Flycer configuration is missing."
	end

	if not flycerConfig.Endpoint or tostring(flycerConfig.Endpoint) == "" then
		return nil, "Flycer API Endpoint is not configured."
	end

	local serviceData = Config.FlycerUI.Services.flycer

	if not serviceData or type(serviceData.New) ~= "function" then
		return nil, "Flycer service is not available in this FlycerUI build."
	end

	return serviceData.New(
		flycerConfig.Endpoint,
		flycerConfig.Product or Config.Title,
		flycerConfig.LockType or Config.KeySystem.LockType or "Device",
		flycerConfig.Client or "FlycerUI",
		flycerConfig.Version or "1.0.0"
	)
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

	-- Hide original KeySystem dialog.
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

		Dialog:Close()()

		task.delay(0.12, function()
			if KeyDialog and KeyDialog.UIElements.MainContainer then
				KeyDialog.UIElements.MainContainer.Visible = true
			end
		end)
	end

	Dialog.UIElements.Main.AutomaticSize = "Y"
	Dialog.UIElements.Main.Size = UDim2.new(0, 470, 0, 0)

	----------------------------------------------------------------
	-- TITLE
	----------------------------------------------------------------

	local TitleIcon = New("ImageLabel", {
		Image = "rbxassetid://89557898457977",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(22, 22),
		ScaleType = Enum.ScaleType.Fit,
	})

	local Title = New("TextLabel", {
		Text = "Flycer Hub",
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

	local Description = New("TextLabel", {
		Text = "Choose an action below.",
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
	-- BUTTONS
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
	-- CLOSE
	----------------------------------------------------------------

	local CloseButton = CreateButton("Close", "x", function()
		CloseFlycerDialog()
	end, "Tertiary", Buttons)

	----------------------------------------------------------------
	-- COPY HWID
	----------------------------------------------------------------

	local CopyButton = CreateButton("Copy HWID", "copy", function()
		if Identifier and CopyToClipboard(Identifier) then
			Config.FlycerUI:Notify({
				Title = "Flycer",
				Content = tostring(IdentifierType) .. " identifier copied to clipboard.",
				Image = "copy",
			})
		else
			Config.FlycerUI:Notify({
				Title = "Flycer",
				Content = IdentifierError or "Clipboard or identifier is not available in this executor.",
				Icon = "triangle-alert",
			})
		end
	end, "Primary", Buttons)

	----------------------------------------------------------------
	-- DISCORD
	----------------------------------------------------------------

	local Discord = Config.KeySystem.Discord or Config.KeySystem.DiscordURL

	local DiscordButton

	if Discord and Discord ~= "" then
		DiscordButton = CreateButton("Discord", "message-circle", function()
			if CopyToClipboard(Discord) then
				Config.FlycerUI:Notify({
					Title = "Flycer",
					Content = "Discord link copied to clipboard.",
					Image = "message-circle",
				})
			else
				Config.FlycerUI:Notify({
					Title = "Flycer",
					Content = "Clipboard is not available in this executor.",
					Icon = "triangle-alert",
				})
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
	-- MAIN DIALOG CONTENT
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

		TitleContainer,
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

----------------------------------------------------------------
-- KEY SYSTEM
----------------------------------------------------------------

function KeySystem.new(Config, Filename, func, keyValidator)
	local KeyDialogInit = require("./window/Dialog")

	local KeyDialog =
		KeyDialogInit.Create(true, "Popup", Config.Window, Config.FlycerUI, Config.FlycerUI.ScreenGui.KeySystem)

	local Services = {}

	local EnteredKey

	local ThumbnailSize = (Config.KeySystem.Thumbnail and Config.KeySystem.Thumbnail.Width) or 200

	----------------------------------------------------------------
	-- UI SIZE
	----------------------------------------------------------------

	local UISize = 430

	if Config.KeySystem.Thumbnail and Config.KeySystem.Thumbnail.Image then
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

	local InputFrame = CreateInput("Enter Key", "key", nil, "Input", function(k)
		EnteredKey = k
	end)

	----------------------------------------------------------------
	-- NOTE
	----------------------------------------------------------------

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
				Padding = UDim.new(0, 18 / 2),
				FillDirection = "Horizontal",
			}),
		}),
	})

	----------------------------------------------------------------
	-- THUMBNAIL
	----------------------------------------------------------------

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

	if Config.KeySystem.URL and not Config.KeySystem.KeyValidator then
		CreateButton("Get key", "key", function()
			CopyToClipboard(Config.KeySystem.URL)
		end, "Secondary", ButtonsContainer.Frame)
	end

	----------------------------------------------------------------
	-- SERVICE DROPDOWN
	----------------------------------------------------------------

	if Config.KeySystem.API or Config.KeySystem.KeyValidator or type(Config.KeySystem.Flycer) == "table" then
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
			Size = UDim2.new(0, 24 - 3, 0, 24 - 3),

			Parent = ButtonFrame.Frame,
			BackgroundTransparency = 1,
		}, {
			ChevronDown,
		})

		----------------------------------------------------------------
		-- DROPDOWN
		----------------------------------------------------------------

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
				PaddingTop = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
		})

		----------------------------------------------------------------
		-- FLYCER SERVICE
		----------------------------------------------------------------

		local function AddFlycerService()
			local IconFrame = Creator.Image("key", "key", 0, "Temp", "KeySystem", true)

			IconFrame.Size = UDim2.new(0, 24, 0, 24)

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

				IconFrame,

				New("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),

				New("TextLabel", {
					Text = "Flycer",
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

			Creator.AddSignal(APIFrame.MouseButton1Click, function()
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
		end

		if Config.KeySystem.KeyValidator or type(Config.KeySystem.Flycer) == "table" then
			AddFlycerService()
		end

		----------------------------------------------------------------
		-- OTHER API SERVICES
		----------------------------------------------------------------

		for _, i in next, (Config.KeySystem.API or {}) do
			if i.Type ~= "flycer" then
				local serviceDef = Config.FlycerUI.Services[i.Type]

				if serviceDef then
					local args = {}

					for _, argName in next, serviceDef.Args do
						table.insert(args, i[argName])
					end

					local serviceInstance = serviceDef.New(table.unpack(args))

					serviceInstance.Type = i.Type

					table.insert(Services, serviceInstance)

					local IconFrame =
						Creator.Image(i.Icon or serviceDef.Icon or "user", i.Icon or serviceDef.Icon or "user", 0, "Temp", "KeySystem", true)

					IconFrame.Size = UDim2.new(0, 24, 0, 24)

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

						IconFrame,

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
								Text = i.Desc or "",
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

								Visible = i.Desc and true or false,

								TextXAlignment = "Left",
							}),
						}),
					}, true)

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

					Creator.AddSignal(APIFrame.MouseButton1Click, function()
						serviceInstance.Copy()

						Config.FlycerUI:Notify({
							Title = "Key System",
							Content = "Key link copied to clipboard.",
							Image = "key",
						})
					end)
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
		KeyDialog:Close()()

		writefile((Config.Folder or "Temp") .. "/" .. Filename .. ".key", tostring(key))

		task.wait(0.4)

		func(true)
	end

	----------------------------------------------------------------
	-- SUBMIT BUTTON
	----------------------------------------------------------------

	local SubmitButton = CreateButton("Submit", "arrow-right", function()
		local key = tostring(EnteredKey or "empty")

		local folder = Config.Folder or Config.Title

		----------------------------------------------------------------
		-- FLYCER
		----------------------------------------------------------------

		if type(Config.KeySystem.Flycer) == "table" then
			----------------------------------------------------
			-- CREATE SERVICE
			----------------------------------------------------

			local createOk, serviceInstance, serviceError = pcall(function()
				return CreateFlycerService(Config)
			end)

			----------------------------------------------------
			-- CREATE SERVICE RUNTIME ERROR
			----------------------------------------------------

			if not createOk then
				Config.FlycerUI:Notify({
					Title = "Key System. Error",

					Content = "Flycer service error: " .. tostring(serviceInstance),

					Icon = "triangle-alert",
				})

				return
			end

			----------------------------------------------------
			-- INITIAL RESULT
			----------------------------------------------------

			local isValid = false
			local validationMessage = serviceError

			local validationData = nil

			----------------------------------------------------
			-- VERIFY
			----------------------------------------------------

			if serviceInstance then
				local verifyOk, verifyResult, verifyMessage, verifyResponse = pcall(function()
					return serviceInstance.Verify(key)
				end)

				------------------------------------------------
				-- VERIFY RUNTIME ERROR
				------------------------------------------------

				if not verifyOk then
					Config.FlycerUI:Notify({
						Title = "Key System. Error",

						Content = "Flycer Verify error: " .. tostring(verifyResult),

						Icon = "triangle-alert",
					})

					return
				end

				------------------------------------------------
				-- NORMAL VERIFY RESULT
				------------------------------------------------

				isValid = verifyResult
				validationMessage = verifyMessage

				validationData = verifyResponse
			end

			----------------------------------------------------
			-- VALID
			----------------------------------------------------

			if isValid then
				if Config.KeySystem.SaveKey then
					handleSuccess(key)
				else
					KeyDialog:Close()()

					task.wait(0.4)

					func(true)
				end

				----------------------------------------------------
				-- INVALID
				----------------------------------------------------
			else
				Config.FlycerUI:Notify({
					Title = "Key System. Error",

					Content = validationMessage or "Invalid key.",

					Icon = "triangle-alert",
				})
			end

			return
		end

		----------------------------------------------------------------
		-- KEY VALIDATOR
		----------------------------------------------------------------

		if Config.KeySystem.KeyValidator then
			local isValid, validationMessage = Config.KeySystem.KeyValidator(key)

			if isValid then
				if Config.KeySystem.SaveKey then
					handleSuccess(key)
				else
					KeyDialog:Close()()

					task.wait(0.4)

					func(true)
				end
			else
				Config.FlycerUI:Notify({
					Title = "Key System. Error",

					Content = validationMessage or "Invalid key.",

					Icon = "triangle-alert",
				})
			end

			----------------------------------------------------------------
			-- STATIC KEY
			----------------------------------------------------------------
		elseif not Config.KeySystem.API then
			local isKey = type(Config.KeySystem.Key) == "table"
					and table.find(Config.KeySystem.Key, key)
				or Config.KeySystem.Key == key

			if isKey then
				if Config.KeySystem.SaveKey then
					handleSuccess(key)
				else
					KeyDialog:Close()()

					task.wait(0.4)

					func(true)
				end
			end

			----------------------------------------------------------------
			-- OTHER API SERVICES
			----------------------------------------------------------------
		else
			local isSuccess
			local result

			for _, service in next, Services do
				local success, res = service.Verify(key)

				if success then
					isSuccess = true
					result = res

					break
				end

				result = res
			end

			if isSuccess then
				handleSuccess(key)
			else
				Config.FlycerUI:Notify({
					Title = "Key System. Error",
					Content = result,
					Icon = "triangle-alert",
				})
			end
		end
	end, "Primary", ButtonsContainer)

	SubmitButton.AnchorPoint = Vector2.new(1, 0.5)

	SubmitButton.Position = UDim2.new(1, 0, 0.5, 0)

	----------------------------------------------------------------
	-- OPEN
	----------------------------------------------------------------

	KeyDialog:Open()
end

return KeySystem
