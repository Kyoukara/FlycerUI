local KeySystem = {}

local Creator = require("../modules/Creator")
local New = Creator.New
local Tween = Creator.Tween

local CreateButton = require("./ui/Button").New
local CreateInput = require("./ui/Input").New

local function CopyToClipboard(value)
	if not value or value == "" then
		return false
	end

	local ok = pcall(function()
		setclipboard(tostring(value))
	end)

	return ok
end

-- Returns the identifier used by Flycer's selected lock mode.
-- Username -> Roblox UserId (account-bound).
-- Device -> executor HWID, then Roblox client ID.
local CreateFlycerService

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

-- Build the Flycer validator from the same configuration used by Init.lua.
-- Flycer is intentionally authoritative when Config.KeySystem.Flycer exists.
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

	-- Hide the original KeyValidator dialog while the Flycer service dialog is open.
	-- This prevents both dialogs from occupying the same space.
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
		if Identifier and CopyToClipboard(Identifier) then
			Config.FlycerUI:Notify({
				Title = "Flycer",
				Content = IdentifierType .. " identifier copied to clipboard.",
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
			end
		end, "Secondary", Buttons)
	end

	-- Keep every action button inside the dialog bounds on small/mobile screens.
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

function KeySystem.new(Config, Filename, func, keyValidator)
	local KeyDialogInit = require("./window/Dialog")
	local KeyDialog =
		KeyDialogInit.Create(true, "Popup", Config.Window, Config.FlycerUI, Config.FlycerUI.ScreenGui.KeySystem)

	local Services = {}

	local EnteredKey

	local ThumbnailSize = (Config.KeySystem.Thumbnail and Config.KeySystem.Thumbnail.Width) or 200

	local UISize = 430
	if Config.KeySystem.Thumbnail and Config.KeySystem.Thumbnail.Image then
		UISize = 430 + (ThumbnailSize / 2)
	end

	KeyDialog.UIElements.Main.AutomaticSize = "Y"
	KeyDialog.UIElements.Main.Size = UDim2.new(0, UISize, 0, 0)

	local IconFrame

	if Config.Icon then
		IconFrame =
			Creator.Image(Config.Icon, Config.Title .. ":" .. Config.Icon, 0, "Temp", "KeySystem", Config.IconThemed)
		IconFrame.Size = UDim2.new(0, 24, 0, 24)
		IconFrame.LayoutOrder = -1
	end

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
		TextTransparency = 1, -- .4 -- hidden
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
		-- New("UIListLayout", {
		--     Padding = UDim.new(0,9),
		--     FillDirection = "Horizontal",
		--     VerticalAlignment = "Bottom"
		-- }),
		IconAndTitleContainer,
		KeySystemTitle,
	})

	local InputFrame = CreateInput("Enter Key", "key", nil, "Input", function(k)
		EnteredKey = k
	end)

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

	local MainFrame = New("Frame", {
		--AutomaticSize = "XY",
		Size = UDim2.new(1, ThumbnailFrame and -ThumbnailSize or 0, 1, 0),
		Position = UDim2.new(0, ThumbnailFrame and ThumbnailSize or 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = KeyDialog.UIElements.Main,
	}, {
		New("Frame", {
			--AutomaticSize = "XY",
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

	-- for _, values in next, KeySystemButtons do
	--     CreateButton(values.Title, values.Icon, values.Callback, values.Variant)
	-- end

	local ExitButton = CreateButton("Exit", "log-out", function()
		KeyDialog:Close()()
	end, "Tertiary", ButtonsContainer.Frame)

	if ThumbnailFrame then
		ExitButton.Parent = ThumbnailFrame
		ExitButton.Size = UDim2.new(0, 0, 0, 42)
		ExitButton.Position = UDim2.new(0, 10, 1, -10)
		ExitButton.AnchorPoint = Vector2.new(0, 1)
	end

	if Config.KeySystem.URL and not Config.KeySystem.KeyValidator then
		CreateButton("Get key", "key", function()
			setclipboard(Config.KeySystem.URL)
		end, "Secondary", ButtonsContainer.Frame)
	end

	if Config.KeySystem.API or Config.KeySystem.KeyValidator or type(Config.KeySystem.Flycer) == "table" then
		-- local Icons = {
		--     platoboost = "rbxassetid://75920162824531",
		--     pandadevelopment = "panda",
		-- }
		-- local Names = {
		--     platoboost = "Platoboost",
		--     pandadevelopment = "Panda Development",
		-- }
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

		local function AddFlycerService()
			local IconFrame = Creator.Image("key", "key", 0, "Temp", "KeySystem", true)
			IconFrame.Size = UDim2.new(0, 24, 0, 24)

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

					local IconFrame = Creator.Image(
						i.Icon or serviceDef.Icon or "user",
						i.Icon or serviceDef.Icon or "user",
						0,
						"Temp",
						"KeySystem",
						true
					)
					IconFrame.Size = UDim2.new(0, 24, 0, 24)

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

	local function handleSuccess(key)
		KeyDialog:Close()()
		writefile((Config.Folder or "Temp") .. "/" .. Filename .. ".key", tostring(key))
		task.wait(0.4)
		func(true)
	end

	local SubmitButton = CreateButton("Submit", "arrow-right", function()
		local key = tostring(EnteredKey or "empty")
		local folder = Config.Folder or Config.Title

		if type(Config.KeySystem.Flycer) == "table" then
			local serviceInstance, serviceError = CreateFlycerService(Config)
			local isValid, validationMessage = false, serviceError

			if serviceInstance then
				-- Every submit goes to the remote API. The server decides whether
				-- the key is active, expired, free, bound or mismatched.
				isValid, validationMessage = serviceInstance.Verify(key)
			end

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
			return
		end

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
		elseif not Config.KeySystem.API then
			local isKey = type(Config.KeySystem.Key) == "table" and table.find(Config.KeySystem.Key, key)
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
		else
			local isSuccess, result
			for _, service in next, Services do
				local success, res = service.Verify(key)
				if success then
					isSuccess, result = true, res
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

	-- TitleContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	--     KeyDialog.UIElements.Main.Size = UDim2.new(
	--         0,
	--         TitleContainer.AbsoluteSize.X +24+24+24+24+9,
	--         0,
	--         0
	--     )
	-- end)

	KeyDialog:Open()
end

return KeySystem
