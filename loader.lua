--!strict
-- Public entry point. The fetched hub remains publicly readable.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local BASE_URL = "https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/"
local SCRIPTS_BY_GAME: {[number]: string} = {
	[5595353122] = "LukihoHub.client.lua",
}

local scriptName = SCRIPTS_BY_GAME[game.GameId]
if not scriptName then
	return
end

local hubUrl = BASE_URL .. scriptName

local fetched, source = pcall(function()
	return (game :: any):HttpGet(hubUrl)
end)
if not fetched then
	error("[Lukiho] Could not fetch hub. Check repository visibility, branch, and filename: " .. tostring(source))
end

local compile, syntaxError = loadstring(source)
if not compile then
	error("[Lukiho] Hub did not compile. Verify the raw URL: " .. tostring(syntaxError))
end

local started, failure = pcall(compile)
if not started then
	error("[Lukiho] Hub failed to start: " .. tostring(failure))
end
