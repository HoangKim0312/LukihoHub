-- Public entry. Maps game.PlaceId -> script file.
-- Loader is responsible for:
--   1. Loading the shared MacLib UI library ONCE and exposing it as
--      _G._AA_MACLIB so every hub can use the same library without each
--      hub re-fetching it.
--   2. Fetching the per-game hub script (adventure.lua, future bloxfruit.lua).
--   3. Compiling + running the hub. Hub receives _G._AA_MACLIB preloaded.
--
-- Every step prints a short status line so the user can see progress even
-- without an F9 console (some executors swallow stderr but keep stdout).

local function _boot()
	print("[Lukiho] loader starting (gameId=" .. tostring(game.GameId) .. " placeId=" .. tostring(game.PlaceId) .. ")")

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local BASE_URL = "https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/"
	local CACHE_BUST = "?cache=" .. tostring(os.time())
		.. "-" .. tostring(math.floor(os.clock() * 1000))

	-- place id -> script filename (each is a self-contained monolithic hub).
	-- Add more entries here when you ship a hub for a new game; nothing else changes.
	local SCRIPTS_BY_PLACE = {
		-- Anime Adventures
		[4584892739]  = "adventure.lua",        -- legacy place id (pre-2025)
		[10715453071] = "adventure.lua",        -- current game id (post-update)
		-- Legacy hub
		[5595353122]  = "LukihoHub.client.lua", -- Legacy hub (Obsidian UI)
		-- Anime Adventures PlaceId variants
		[94823097601547] = "adventure.lua",
	}

	local scriptPath = SCRIPTS_BY_PLACE[game.PlaceId]
	if not scriptPath then
		warn("[Lukiho] no hub registered for placeId " .. tostring(game.PlaceId) .. " — exiting")
		return
	end

	local HttpGet = game and game.HttpGet
	if type(HttpGet) ~= "function" then
		error("[Lukiho] executor does not expose game:HttpGet — cannot continue")
	end

	local function tryFetch(url)
		local ok, body = pcall(HttpGet, game, url)
		if not ok or type(body) ~= "string" or #body < 100 then
			return nil, type(body) == "string" and body or tostring(body)
		end
		return body
	end

	-- Loader-level MacLib URLs. The vendored copy in our own repo is primary
	-- so we are not at the mercy of upstream GitHub releases.
	local MACLIB_URLS = {
		BASE_URL .. "libs/maclib.lua",
		"https://github.com/biggaboy212/Maclib/releases/download/9.Maclib/maclib.txt",
		"https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt",
	}

	local macLib, macLibErr
	for _, url in MACLIB_URLS do
		local body, fetchErr = tryFetch(url .. CACHE_BUST)
		if body then
			local chunk, compileErr = loadstring(body)
			if chunk then
				local ok, libOrErr = pcall(chunk)
				if ok and type(libOrErr) == "table" then
					macLib = libOrErr
					print("[Lukiho] MacLib loaded from " .. url)
					break
				else
					macLibErr = "runtime: " .. tostring(libOrErr)
				end
			else
				macLibErr = "compile: " .. tostring(compileErr)
			end
		else
			macLibErr = "fetch(" .. url .. "): " .. tostring(fetchErr)
		end
	end

	if macLib then
		_G._AA_MACLIB = macLib
	else
		_G._AA_MACLIB = nil
		warn("[Lukiho] MacLib unavailable: " .. tostring(macLibErr) .. " — hub will run headless")
	end

	local hubUrl = BASE_URL .. scriptPath .. CACHE_BUST

	local fetched, source = pcall(HttpGet, game, hubUrl)
	if not fetched then
		error("[Lukiho] Could not fetch script. Check repo visibility / branch / filename: " .. tostring(source))
	end
	print("[Lukiho] hub source fetched (" .. tostring(#source) .. " bytes)")

	local compile, syntaxError = loadstring(source)
	if not compile then
		error("[Lukiho] Script did not compile. Verify raw URL: " .. tostring(syntaxError))
	end

	local started, failure = pcall(compile)
	if not started then
		error("[Lukiho] Script failed to start: " .. tostring(failure))
	end

	print("[Lukiho] hub started")
end

local ok, err = pcall(_boot)
if not ok then
	-- Print to every channel so even minimal executors show something.
	print("[Lukiho] FATAL: " .. tostring(err))
	warn("[Lukiho] FATAL: " .. tostring(err))
	if type(_G.error) == "function" then
		pcall(_G.error, "[Lukiho] FATAL: " .. tostring(err), 0)
	end
end
