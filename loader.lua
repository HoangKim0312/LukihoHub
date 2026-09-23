--!strict
-- Public entry. Maps game.PlaceId (Anime Adventures) -> script file.
-- Fetch via HttpGet, then loadstring. No script.Parent dependency.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local BASE_URL = "https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/"

-- place id -> script filename (each is a self-contained monolithic hub)
local SCRIPTS_BY_PLACE: { [number]: string } = {
	[4584892739] = "adventure.lua", -- Anime Adventures
}

-- UI library sources. The hub uses these only as a best-effort; if every
-- mirror fails, the script still runs (automation features are headless).
local MACLIB_URLS = {
	"https://raw.githubusercontent.com/biggaboy212/Maclib/main/maclib.txt",
	"https://raw.githubusercontent.com/biggaboy212/Maclib/master/maclib.txt",
}

local function tryFetch(url)
	local ok, body = pcall(function()
		return (game :: any):HttpGet(url)
	end)
	if not ok or type(body) ~= "string" or #body < 100 then
		return nil
	end
	return body
end

local scriptPath = SCRIPTS_BY_PLACE[game.PlaceId]
if not scriptPath then
	return
end

local hubUrl = BASE_URL .. scriptPath
	.. "?cache=" .. tostring(os.time())
	.. "-" .. tostring(math.floor(os.clock() * 1000))

local fetched, source = pcall(function()
	return (game :: any):HttpGet(hubUrl)
end)
if not fetched then
	error("[Lukiho] Could not fetch script. Check repo visibility / branch / filename: " .. tostring(source))
end

-- Pre-fetch the UI library on this level (top-level loadstring has the
-- most reliable HttpGet permissions across executors). If any mirror works,
-- hand the source to the hub so it doesn't have to refetch.
local macLibSource = nil
for _, url in MACLIB_URLS do
	macLibSource = tryFetch(url)
	if macLibSource then break end
end
if macLibSource then
	_G._AA_MACLIB_SOURCE = macLibSource
else
	_G._AA_MACLIB_SOURCE = nil
end

local compile, syntaxError = loadstring(source)
if not compile then
	error("[Lukiho] Script did not compile. Verify raw URL: " .. tostring(syntaxError))
end

local started, failure = pcall(compile)
if not started then
	error("[Lukiho] Script failed to start: " .. tostring(failure))
end
