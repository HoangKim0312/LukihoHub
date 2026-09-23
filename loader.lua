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

local compile, syntaxError = loadstring(source)
if not compile then
	error("[Lukiho] Script did not compile. Verify raw URL: " .. tostring(syntaxError))
end

local started, failure = pcall(compile)
if not started then
	error("[Lukiho] Script failed to start: " .. tostring(failure))
end
