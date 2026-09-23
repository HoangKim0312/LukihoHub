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

	-- Match by game.UniverseId instead of PlaceId so the same hub runs on
	-- every Anime Adventures place (lobby + every story/infinite/raid
	-- game instance). Universes are stable across place versions.
	local SCRIPTS_BY_UNIVERSE = {
		-- Anime Adventures
		[4646479491]  = "adventure.lua", -- AA legacy + current universe
		-- Legacy hub (different universe entirely)
		[--[[ legacy universe id will go here ]] 0] = "LukihoHub.client.lua",
	}

	-- Universe-id-prefix table for AA so new place versions stay covered.
	local AA_UNIVERSE_IDS = {
		[4646479491] = true,
	}

	-- Find the script to run for the current place. We try:
	--   1. Direct PlaceId match (so legacy/different hubs still dispatch).
	--   2. UniverseId match (same game, any place inside).
	--   3. AA universe fallback (adventure.lua).
	local PLACE_TO_SCRIPT = {
		[4584892739]    = "adventure.lua",
		[10715453071]   = "adventure.lua",
		[94823097601547] = "adventure.lua",
		[5595353122]    = "LukihoHub.client.lua",
	}

	local scriptPath = PLACE_TO_SCRIPT[game.PlaceId]
	if not scriptPath then
		if AA_UNIVERSE_IDS[game.GameId] then
			scriptPath = "adventure.lua"
			print(string.format("[Lukiho] AA universe matched (gameId=%d), using adventure.lua", game.GameId))
		elseif SCRIPTS_BY_UNIVERSE[game.GameId] then
			scriptPath = SCRIPTS_BY_UNIVERSE[game.GameId]
		end
	end
	if not scriptPath then
		warn("[Lukiho] no hub registered for placeId=" .. tostring(game.PlaceId)
			.. " gameId=" .. tostring(game.GameId) .. " — exiting")
		return
	end

	-- Build a self-restart command that re-executes this loader after the
	-- server teleports us (e.g. play a story map -> new place instance).
	-- queue_on_teleport is supported by Synapse X, Fluxus, Wave, etc.
	-- If the executor doesn't expose it we silently fall back; the hub will
	-- still work for non-teleport flows.
	local RESTART_CMD
	if type(queue_on_teleport) == "function" or type(fluxus) == "table"
		or type(syn) == "table" then
		-- Re-fetch + execute the hub source directly to avoid a second HTTP
		-- round-trip for the loader in the destination place.
		RESTART_CMD = string.format([[
local ok, body = pcall(function()
	if syn and syn.request then return syn.request({ Url = %q, Method = "GET" }).Body end
	if request then return request({ Url = %q, Method = "GET" }).Body end
	if game and game.HttpGet then return game:HttpGet(%q) end
end)
if ok and type(body) == "string" and #body > 100 then
	local fn, err = loadstring(body)
	if fn then pcall(fn) end
end]], BASE_URL .. scriptPath, BASE_URL .. scriptPath, BASE_URL .. scriptPath)
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

	-- Ask the executor to re-run the hub after any teleport triggered by
	-- the game (joining a story match, raid, etc.). queue_on_teleport is
	-- exposed by Synapse X / Fluxus / Wave. Some executors use a global
	-- `fluxus` object instead — handle those.
	if RESTART_CMD then
		pcall(function()
			if type(queue_on_teleport) == "function" then
				queue_on_teleport(RESTART_CMD)
				print("[Lukiho] queue_on_teleport registered (story/raid auto-rerun)")
			elseif type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then
				fluxus.queue_on_teleport(RESTART_CMD)
				print("[Lukiho] fluxus.queue_on_teleport registered")
			end
		end)
	end
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
