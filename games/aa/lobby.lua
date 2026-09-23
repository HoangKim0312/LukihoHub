--!strict
-- games/aa/lobby.lua
-- Lobby helpers: Auto Join Map / Challenge / Portal / Player.

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local M = {}

local init  = require(script.Parent:WaitForChild("init"))
local data  = require(script.Parent:WaitForChild("data"))

local player = Players.LocalPlayer

----------------------------------------------------------------
-- STATE (lobby-only)
----------------------------------------------------------------
M.state = {
	autoJoin          = false,
	autoChallenge     = false,
	autoPortal        = false,
	autoJoinPlayer    = false,
	joinMode          = "Story",
	selectedMap       = "Naruto",
	selectedAct       = "Act 1",
	difficulty        = "Normal",
	friendsOnly       = false,
	autoStart         = false,
	autoStartDelay    = 5,

	-- challenge
	ignoreWorlds      = {},
	ignoreModifiers   = {},

	-- portal
	selectedPortal    = "final_disc",
	portalDifficulty  = "Normal",
	portalTiers       = {},
	ignoreDmgBonus    = false,

	-- auto join player
	joinPlayerName    = "",
}

----------------------------------------------------------------
-- LOBBY GUARD
----------------------------------------------------------------
function M.inLobby(): boolean
	return init.isLobby()
end

----------------------------------------------------------------
-- STORY / INFINITE / LEGEND / RAID JOIN
-- request_join_lobby(mode, params...) shape varies per mode.
-- For story: request_join_lobby("Story", mapId, actId, difficulty, friendsOnly)
-- For infinite: request_join_lobby("Infinite", mapId, actId, difficulty, friendsOnly)
-- For raid:     request_join_lobby("Raid", raidId, difficulty, friendsOnly)
-- These are best-effort; AA's exact signature is internal.
----------------------------------------------------------------
function M.joinStory()
	init.invoke(init.REMOTE.request_join_lobby,
		"Story", M.state.selectedMap, M.state.selectedAct,
		M.state.difficulty, M.state.friendsOnly)
end

function M.joinInfinite()
	init.invoke(init.REMOTE.request_join_lobby,
		"Infinite", M.state.selectedMap, M.state.selectedAct,
		M.state.difficulty, M.state.friendsOnly)
end

function M.joinLegend()
	init.invoke(init.REMOTE.request_join_lobby,
		"LegendStage", M.state.selectedMap, M.state.selectedAct,
		M.state.difficulty, M.state.friendsOnly)
end

function M.joinRaid()
	init.invoke(init.REMOTE.request_join_lobby,
		"Raid", M.state.selectedMap, M.state.difficulty,
		M.state.friendsOnly)
end

----------------------------------------------------------------
-- DIFFICULTY
----------------------------------------------------------------
function M.setDifficulty(difficulty: string)
	M.state.difficulty = difficulty
	init.invoke(init.REMOTE.select_difficulty, difficulty)
end

----------------------------------------------------------------
-- CHALLENGE
----------------------------------------------------------------
function M.fetchChallenges(kind: string): any
	local remote = (kind == "Daily" and init.REMOTE.get_daily_challenge)
		or (kind == "Event" and init.REMOTE.get_event_challenges)
		or init.REMOTE.get_normal_challenge
	return init.invoke(remote) or {}
end

function M.isChallengeIgnored(name: string): boolean
	for _, ignore in M.state.ignoreWorlds do
		if ignore == name then return true end
	end
	for _, ignore in M.state.ignoreModifiers do
		if ignore == name then return true end
	end
	return false
end

----------------------------------------------------------------
-- PORTAL
----------------------------------------------------------------
function M.usePortal()
	init.invoke(init.REMOTE.use_portal,
		M.state.selectedPortal,
		M.state.portalDifficulty,
		M.state.portalTiers,
		M.state.ignoreDmgBonus)
end

----------------------------------------------------------------
-- AUTO JOIN PLAYER
-- Sends matchmaking request; the server returns a teleport ticket.
-- This is a thin wrapper; the actual teleport comes from
-- TeleportService:TeleportToPlaceInstance which AA itself does.
----------------------------------------------------------------
function M.joinPlayer(name: string)
	if name == "" or name == nil then return end
	-- AA has no direct "join this player's lobby" remote in the
	-- public dump; the supported route is matchmaking on the
	-- current map. Use it as a fallback.
	init.invoke(init.REMOTE.request_matchmaking, M.state.selectedMap)
end

function M.refreshFriends(): { string }
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then return {} end
	local list = {}
	while true do
		for _, friend in pages:GetCurrentPage() do
			table.insert(list, friend.Username)
		end
		if pages.IsFinished then break end
		pcall(function() pages:AdvanceToNextPageAsync() end)
	end
	return list
end

----------------------------------------------------------------
-- TICK
-- Drives the auto-* features from RunService.Heartbeat.
----------------------------------------------------------------
local hooks: { () -> () } = {}

function M.tick(dt: number)
	if M.state.autoJoin and M.inLobby() then
		if M.state.joinMode == "Story" then
			M.joinStory()
		elseif M.state.joinMode == "Infinite" then
			M.joinInfinite()
		elseif M.state.joinMode == "LegendStage" then
			M.joinLegend()
		elseif M.state.joinMode == "Raid" then
			M.joinRaid()
		end
		M.state.autoJoin = false
		init.notify("LukihoHub", "Auto join triggered: " .. M.state.joinMode)
	end

	if M.state.autoChallenge and M.inLobby() then
		local challenges = M.fetchChallenges("Daily")
		for _, challenge in challenges do
			local name = challenge.Name or challenge.name or tostring(challenge)
			if not M.isChallengeIgnored(name) then
				init.invoke(init.REMOTE.request_join_lobby, "Challenge", challenge)
				init.notify("LukihoHub", "Joined challenge: " .. tostring(name))
				break
			end
		end
		M.state.autoChallenge = false
	end

	if M.state.autoPortal and M.inLobby() then
		M.usePortal()
		init.notify("LukihoHub", "Portal used: " .. M.state.selectedPortal)
		M.state.autoPortal = false
	end

	if M.state.autoStart and M.inLobby() then
		task.delay(M.state.autoStartDelay, function()
			init.invoke(init.REMOTE.request_start_game)
		end)
		M.state.autoStart = false
	end

	for _, hook in hooks do
		pcall(hook, dt)
	end
end

function M.onTick(fn: () -> ())
	table.insert(hooks, fn)
end

return M
