local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))

local Flycer = {}

local function GetIdentifier(lockType)
	local LocalPlayer = Players.LocalPlayer
	lockType = string.lower(tostring(lockType or "Device"))

	if lockType == "username" then
		return tostring(LocalPlayer.UserId), "Username"
	end

	if lockType ~= "device" then
		return nil, "Invalid", "LockType must be 'Device' or 'Username'."
	end

	local gethwidFn = gethwid
	if type(gethwidFn) == "function" then
		local ok, hwid = pcall(gethwidFn)
		if ok and hwid ~= nil and tostring(hwid) ~= "" then
			return tostring(hwid), "Device"
		end
	end

	local ok, clientId = pcall(function()
		return cloneref(game:GetService("RbxAnalyticsService")):GetClientId()
	end)
	if ok and clientId ~= nil and tostring(clientId) ~= "" then
		return tostring(clientId), "Device"
	end

	return nil, "Device", "No device identifier is available in this executor."
end

function Flycer.New(endpoint, productId, lockType, clientName, clientVersion)
	endpoint = tostring(endpoint or ""):gsub("/$", "")
	productId = tostring(productId or "default")
	lockType = tostring(lockType or "Device")
	clientName = tostring(clientName or "FlycerUI")
	clientVersion = tostring(clientVersion or "1.0.0")

	local function ValidateKey(key)
		if endpoint == "" then
			return false, "Flycer API endpoint is not configured."
		end

		local identifier, identifierType, identifierError = GetIdentifier(lockType)
		if not identifier then
			return false, identifierError or "Unable to determine identifier."
		end

		local Request = request or http_request or (syn and syn.request)
		if type(Request) ~= "function" then
			return false, "HTTP request is not available in this executor."
		end

		key = tostring(key or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if key == "" then
			return false, "Please enter a license key."
		end

		local body = HttpService:JSONEncode({
			product = productId,
			key = tostring(key),
			lock_type = string.lower(identifierType),
			identifier = identifier,
			client = clientName,
			client_version = clientVersion,
		})

		local url = endpoint .. "/api/license/validate"

		local ok, response = pcall(function()
			return Request({
				Url = url,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					["User-Agent"] = "FlycerUI/" .. clientVersion,
				},
				Body = body,
			})
		end)

		if not ok or not response then
			return false, "Unable to contact Flycer API."
		end

		if not response.Success then
			local status = tonumber(response.StatusCode)
			local responseBody = tostring(response.Body or "")
			local message = "Flycer API request failed"
			if status then
				message = message .. " (" .. tostring(status) .. ")"
			end
			if responseBody ~= "" then
				local decodeOk, errorData = pcall(function()
					return HttpService:JSONDecode(responseBody)
				end)
				if decodeOk and type(errorData) == "table" and errorData.message then
					message = tostring(errorData.message)
				end
			end
			return false, message
		end

		local decodeOk, data = pcall(function()
			return HttpService:JSONDecode(response.Body or "")
		end)

		if not decodeOk or type(data) ~= "table" then
			return false, "Flycer API returned an invalid response."
		end

		if data.success == true then
			return true, data.message or data.code or "Authenticated", data
		end

		return false, data.message or data.code or "License validation failed.", data
	end

	local function Copy()
		local identifier, _, err = GetIdentifier(lockType)
		if not identifier then
			return false, err or "Identifier unavailable."
		end

		local copy = setclipboard or toclipboard
		if type(copy) ~= "function" then
			return false, "Clipboard is not available in this executor."
		end

		local ok = pcall(function()
			copy(identifier)
		end)
		return ok, ok and identifier or "Unable to copy identifier."
	end

	return {
		Type = "flycer",
		Verify = ValidateKey,
		Copy = Copy,
		GetIdentifier = function()
			return GetIdentifier(lockType)
		end,
	}
end

return Flycer
