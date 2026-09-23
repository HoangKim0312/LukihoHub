--!strict
-- Public entry point. Add a new entry to SCRIPTS_BY_GAME for each experience.
-- Each game has its own script under games/<slug>/LukihoHub.client.lua.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local BASE_URL = "https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/"
local SCRIPTS_BY_GAME: { [number]: string } = {
	-- [GameId] = "path relative to repo root"
	[4584892739] = "games/aa/LukihoHub.client.lua",
}

local scriptPath = SCRIPTS_BY_GAME[game.GameId]
if not scriptPath then
	return
end

local hubUrl = BASE_URL .. scriptPath
local requestUrl = hubUrl .. "?cache=" .. tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 1000))

local fetched, source = pcall(function()
	return (game :: any):HttpGet(requestUrl)
end)
if not fetched then
	error("[Lukiho] Could not fetch script. Check repository visibility, branch, and filename: " .. tostring(source))
end

local compile, syntaxError = loadstring(source)
if not compile then
	error("[Lukiho] Script did not compile. Verify the raw URL: " .. tostring(syntaxError))
end

local started, failure = pcall(compile)
if not started then
	error("[Lukiho] Script failed to start: " .. tostring(failure))
end
