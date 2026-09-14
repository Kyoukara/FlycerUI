local cloneref = cloneref or clonereference or function(instance)
	return instance
end

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))

local Flycer = {}

-- ============================================================
-- [ADVANCED] Timeout wrapper dengan support kompatibilitas
-- semua executor (task.spawn + polling).
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
		completed = true
		return false, "Flycer API request timed out after " .. tostring(timeout) .. "s."
	end

	return resultOk, resultData
end

-- ============================================================
-- [NEW] Universal HTTP Request Handler Detection
-- Support: Synapse X, Fluxus, KRNL, Delta, Wave, Solara,
-- Codex, Hydrogen, Xeno, PC/Mobile executors.
-- ============================================================
local function GetHttpRequestHandler()
	local handlers = {
		function() return syn and syn.request end,
		function() return http and http.request end,
		function() return http_request end,
		function() return fluxus and fluxus.request end,
		function() return request end,
		function() return httprequest end,
		function() return krnl_request end,
	}

	for _, getHandler in ipairs(handlers) do
		local ok, handler = pcall(getHandler)
		if ok and type(handler) == "function" then
			return handler
		end
	end
	return nil
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

	-- ============================================================
	-- [NEW] Attempt Single HTTP Request (helper)
	-- ============================================================
	local function AttemptSingleRequest(Request, url, body, userAgent)
		local reqOk, response = RequestWithTimeout(function()
			return Request({
				Url = url,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					["Accept"] = "application/json",
					["User-Agent"] = userAgent or ("FlycerUI/" .. clientVersion),
				},
				Body = body,
			})
		end, DEFAULT_TIMEOUT)

		if not reqOk or not response then
			return nil, tostring(response or "No response from server.")
		end

		if not response.Success then
			local status = tonumber(response.StatusCode)
			local responseBody = tostring(response.Body or "")
			if status and status == 200 then
				-- Beberapa executor tidak set Success=true untuk 200 OK
				response.Success = true
			else
				local message = "Server returned HTTP " .. tostring(status or "?")
				if responseBody ~= "" then
					local decodeOk, errorData = pcall(function()
						return HttpService:JSONDecode(responseBody)
					end)
					if decodeOk and type(errorData) == "table" and errorData.message then
						message = tostring(errorData.message)
					end
				end
				return nil, message
			end
		end

		local decodeOk, data = pcall(function()
			return HttpService:JSONDecode(response.Body or "")
		end)

		if not decodeOk or type(data) ~= "table" then
			return nil, "Server returned invalid JSON response."
		end

		return data, nil
	end

	-- ============================================================
	-- [NEW] Multi-Retry Validate dengan Adaptive Backoff
	-- Strategi: 3x retry dengan delay 0s → 0.5s → 1.5s
	-- 2 endpoint variant × 3 UserAgent
	-- ============================================================
	local function ValidateKey(key)
		if endpoint == "" then
			return false, "Flycer API endpoint is not configured."
		end

		local identifier, identifierType, identifierError = GetIdentifier(lockType)
		if not identifier then
			return false, identifierError or "Unable to determine identifier."
		end

		local Request = GetHttpRequestHandler()
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

		local endpoints = {
			endpoint .. "/api/license/validate",
			endpoint .. "/api/license/validate/",
		}

		local userAgents = {
			"FlycerUI/" .. clientVersion,
			"Roblox/Linux",
			"Roblox/WinInet",
		}

		-- Adaptive Backoff: retry ke-1 langsung, retry ke-2 delay 500ms, retry ke-3 delay 1500ms
		local backoffDelays = { 0, 0.5, 1.5 }

		local lastError = "Unable to reach Flycer API after multiple retries."
		local businessLogicError = nil -- Untuk error non-network (key invalid, expired, dll)

		for attempt = 1, #backoffDelays do
			if attempt > 1 then
				task.wait(backoffDelays[attempt])
			end

			for _, url in ipairs(endpoints) do
				for _, ua in ipairs(userAgents) do
					local data, err = AttemptSingleRequest(Request, url, body, ua)

					if data then
						-- Cek business logic response
						if data.success == true then
							return true, data.message or data.code or "Authenticated", data
						else
							-- Response valid tapi key ditolak (INVALID/EXPIRED/BANNED)
							-- Ini bukan network error, langsung return
							businessLogicError = data.message or data.code or "License validation failed."
							return false, businessLogicError, data
						end
					else
						lastError = err or lastError
					end
				end
			end
		end

		return false, lastError
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
