--!strict
-- Public entry. Maps game.PlaceId -> script file.
-- Loader handles:
--   1. Fetching the per-game hub script (adventure.lua, future bloxfruit.lua, etc.).
--   2. Loading the shared MacLib UI library ONCE and exposing it as _G._AA_MACLIB
--      so every hub can use the same library without each hub re-fetching it.
--   3. Compiling + running the hub. Hub receives _G._AA_MACLIB preloaded.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local BASE_URL = "https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/"
local CACHE_BUST = "?cache=" .. tostring(os.time())
	.. "-" .. tostring(math.floor(os.clock() * 1000))

-- place id -> script filename (each is a self-contained monolithic hub).
-- Add more entries here when you ship a hub for a new game; nothing else changes.
local SCRIPTS_BY_PLACE: { [number]: string } = {
	[4584892739] = "adventure.lua", -- Anime Adventures
	[5595353122] = "LukihoHub.client.lua", -- Legacy hub (Obsidian UI)
}

local function tryFetch(url: string): (string?, string?)
	local ok, body = pcall(function()
		return (game :: any):HttpGet(url)
	end)
	if not ok or type(body) ~= "string" or #body < 100 then
		return nil, type(body) == "string" and body or tostring(body)
	end
	return body
end

local scriptPath = SCRIPTS_BY_PLACE[game.PlaceId]
if not scriptPath then
	return
end

-- Loader-level MacLib URLs. Keep these local to the loader so hubs stay
-- UI-library-agnostic. The vendored copy in our own repo is the primary
-- source so we are not at the mercy of upstream GitHub releases.
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

local fetched, source = pcall(function()
	return (game :: any):HttpGet(hubUrl)
end)
if not fetched then
	error("[Lukiho] Could not fetch script. Check repo visibility / branch / filename: " .. tostring(source))
end

local compile, syntaxError = loadstring(source)
if not compile then
	error("[Lukiho] Script did not compile. Verify raw URL: " .. tostring(syntaxError))
end

local started, failure = pcall(compile)
if not started then
	error("[Lukiho] Script failed to start: " .. tostring(failure))
end
