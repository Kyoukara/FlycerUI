
local Flycer = {}

local HttpService = game:GetService("HttpService")

-- ============================================================
-- HELPER: HTTP Request (multi-executor)
-- ============================================================
local function httpRequest(options)
	local req = (syn and syn.request)
		or (http and http.request)
		or (http_request)
		or (fluxus and fluxus.request)
		or request

	if type(req) ~= "function" then
		return nil, "HTTP request function is not available in this executor."
	end

	local ok, res = pcall(req, options)
	if not ok then
		return nil, tostring(res)
	end
	return res
end

-- ============================================================
-- HELPER: JSON encode/decode
-- ============================================================
local function jsonEncode(tbl)
	local ok, res = pcall(function()
		return HttpService:JSONEncode(tbl)
	end)
	if ok then return res end
	return nil
end

local function jsonDecode(str)
	if type(str) ~= "string" or str == "" then return nil end
	local ok, res = pcall(function()
		return HttpService:JSONDecode(str)
	end)
	if ok then return res end
	return nil
end

-- ============================================================
-- HELPER: Get HWID (sama seperti Luarmor/service umum)
-- ============================================================
local function getHWID()
	-- Prioritas 1: gethwid() dari executor
	if type(gethwid) == "function" then
		local ok, hwid = pcall(gethwid)
		if ok and hwid and tostring(hwid) ~= "" then
			return tostring(hwid)
		end
	end

	-- Prioritas 2: RbxAnalyticsService ClientId (fallback umum)
	local ok, hwid = pcall(function()
		return game:GetService("RbxAnalyticsService"):GetClientId()
	end)
	if ok and hwid and tostring(hwid) ~= "" then
		return tostring(hwid)
	end

	return nil
end

-- ============================================================
-- MAIN: Flycer.New
-- ============================================================
function Flycer.New(endpoint, product, client)
	endpoint = endpoint or "https://flycer.my.id"
	-- normalize trailing slash
	if endpoint:sub(-1) == "/" then
		endpoint = endpoint:sub(1, -2)
	end

	product = product or "FlycerUI"
	client  = client  or "FlycerUI"

	local fsetclipboard = setclipboard or toclipboard

	-- ========================================================
	-- Identifier Provider (dipakai oleh KeySystem UI)
	-- ========================================================
	local function GetIdentifier()
		local hwid = getHWID()
		if not hwid then
			return nil, "Invalid", "Unable to determine HWID."
		end
		return hwid, "HWID", nil
	end

	-- ========================================================
	-- Request challenge (optional, agar konsisten dengan
	-- rute /api/challenge di vercel.json)
	-- ========================================================
	local function RequestChallenge(hwid)
		local body = jsonEncode({
			hwid    = hwid,
			product = product,
			client  = client,
		})

		local res, err = httpRequest({
			Url     = endpoint .. "/api/challenge",
			Method  = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Accept"]       = "application/json",
				["X-Client"]     = client,
			},
			Body = body,
		})

		if not res then
			return nil, err or "No response from challenge endpoint."
		end

		local status = res.StatusCode or res.status_code or res.status or 0
		local data   = jsonDecode(res.Body or res.body or "")

		if status ~= 200 or type(data) ~= "table" then
			return nil, (data and data.message) or ("Challenge failed (HTTP " .. tostring(status) .. ").")
		end

		-- Server bisa mengembalikan { nonce = "...", token = "..." } dsb.
		return data
	end

	-- ========================================================
	-- Verify License Key
	-- ========================================================
	local function Verify(key)
		if type(key) ~= "string" or key == "" then
			return false, "Please enter a license key."
		end

		local hwid = getHWID()
		if not hwid then
			return false, "Unable to determine HWID."
		end

		-- Step 1: minta challenge (opsional; kalau gagal, tetap lanjut validate)
		local challenge = RequestChallenge(hwid)

		-- Step 2: validate
		local payload = {
			key     = key,
			hwid    = hwid,
			product = product,
			client  = client,
		}

		if type(challenge) == "table" then
			payload.nonce = challenge.nonce or challenge.challenge
			payload.token = challenge.token
		end

		local body = jsonEncode(payload)

		local res, err = httpRequest({
			Url     = endpoint .. "/api/license/validate",
			Method  = "POST",
			Headers = {
				["Content-Type"]  = "application/json",
				["Accept"]        = "application/json",
				["X-Client"]      = client,
				["X-Product"]     = product,
				["Authorization"] = "Bearer " .. key,
			},
			Body = body,
		})

		if not res then
			return false, err or "No response from validation endpoint."
		end

		local status = res.StatusCode or res.status_code or res.status or 0
		local data   = jsonDecode(res.Body or res.body or "") or {}

		if status == 200 and (data.valid == true or data.status == "ok" or data.code == "KEY_VALID") then
			return true, data.message or "Whitelisted!", data
		end

		local code = tostring(data.code or "")
		local msg  = data.message or data.error

		if code == "KEY_HWID_LOCKED" or code == "HWID_MISMATCH" then
			return false, msg or "Key is linked to a different HWID. Please contact the seller to reset it."
		elseif code == "KEY_NOT_FOUND" or code == "KEY_INVALID" or code == "KEY_INCORRECT" then
			return false, msg or "Key is wrong or has been deleted."
		elseif code == "KEY_EXPIRED" then
			return false, msg or "Your key has expired."
		elseif code == "HWID_NOT_WHITELISTED" then
			return false, msg or "Your HWID is not whitelisted. Please purchase a key first."
		elseif status == 429 then
			return false, msg or "Too many requests. Please try again in a moment."
		elseif status >= 500 then
			return false, msg or ("Server error (HTTP " .. tostring(status) .. "). Please try again later.")
		end

		return false, msg or ("Invalid key (HTTP " .. tostring(status) .. ").")
	end

	-- ========================================================
	-- Copy (dipakai jika seller memasang link Discord/Store)
	-- ========================================================
	local function Copy(link)
		if type(fsetclipboard) ~= "function" then
			return false, "Clipboard is not available in this executor."
		end
		local target = link or endpoint
		local ok, err = pcall(function()
			fsetclipboard(tostring(target))
		end)
		if not ok then
			return false, tostring(err)
		end
		return true, "Copied!"
	end

	-- ========================================================
	-- Return service instance
	-- ========================================================
	return {
		-- Metadata
		Endpoint = endpoint,
		Product  = product,
		Client   = client,

		-- Methods
		GetIdentifier    = GetIdentifier,
		RequestChallenge = RequestChallenge,
		Verify           = Verify,
		Copy             = Copy,
	}
end

return Flycer
