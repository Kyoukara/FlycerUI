local cloneref = cloneref or clonereference or function(instance)
	return instance
end

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))

local Flycer = {}

-- ============================================================
-- [FIX C3] Timeout wrapper untuk HTTP request.
-- Mencegah hang selamanya jika server tidak merespons.
-- Menggunakan task.spawn + polling agar kompatibel dengan
-- semua executor (termasuk yang tidak support task.cancel).
-- ============================================================
local DEFAULT_TIMEOUT = 15 -- detik

local function RequestWithTimeout(requestFn, timeout)
	timeout = timeout or DEFAULT_TIMEOUT

	local completed = false
	local resultOk, resultData = false, "Request timed out."

	task.spawn(function()
		local ok, response = pcall(requestFn)
		if not completed then
			completed = true
			resultOk = ok
			resultData = response
		end
	end)

	local elapsed = 0
	while not completed and elapsed < timeout do
		task.wait(0.25)
		elapsed = elapsed + 0.25
	end

	if not completed then
		-- [FIX C3] Request hang — return error alih-alih block selamanya.
		completed = true
		return false, "Flycer API request timed out after " .. tostring(timeout) .. "s."
	end

	return resultOk, resultData
end

local function NormalizeLockType(lockType)
	lockType = string.lower(tostring(lockType or "Device"))
	if lockType == "username" or lockType == "device" then
		return lockType
	end
	return nil
end

local function GetIdentifier(lockType)
	local LocalPlayer = Players.LocalPlayer
	lockType = NormalizeLockType(lockType)

	if lockType == "username" then
		return tostring(LocalPlayer.UserId), "Username"
	end

	if lockType ~= "device" then
		return nil, "Invalid", "LockType must be 'Device' or 'Username'."
	end

	-- Priority 1: gethwid (executor-specific, paling reliable)
	local gethwidFn = gethwid
	if type(gethwidFn) == "function" then
		local ok, hwid = pcall(gethwidFn)
		if ok and hwid ~= nil and tostring(hwid) ~= "" then
			return tostring(hwid), "Device"
		end
	end

	-- Priority 2: RbxAnalyticsService fallback
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
	productId = tostring(productId or "default"):gsub("^%s+", ""):gsub("%s+$", "")
	lockType = NormalizeLockType(lockType)
	clientName = tostring(clientName or "FlycerUI")
	clientVersion = tostring(clientVersion or "1.0.0")

	if not lockType then
		return {
			Type = "flycer",
			Verify = function()
				return false, "LockType must be 'Device' or 'Username'."
			end,
			Copy = function()
				return false, "LockType must be 'Device' or 'Username'."
			end,
			GetIdentifier = function()
				return nil, "Invalid", "LockType must be 'Device' or 'Username'."
			end,
		}
	end

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
			key = key,
			lock_type = string.lower(tostring(identifierType or lockType)),
			identifier = tostring(identifier),
			client = clientName,
			client_version = clientVersion,
		})

		local url = endpoint .. "/api/license/validate"

		-- ============================================================
		-- [FIX C3] Gunakan RequestWithTimeout alih-alih pcall langsung.
		-- Ini mencegah hang selamanya jika server tidak merespons.
		-- ============================================================
		local reqOk, response = RequestWithTimeout(function()
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

		if not reqOk then
			return false, tostring(response or "Unable to contact Flycer API.")
		end

		if not response then
			return false, "Flycer API returned no response."
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
