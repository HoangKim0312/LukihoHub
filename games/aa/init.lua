--!strict
-- games/aa/init.lua
-- Shared bootstrap for the Anime Adventures hub.
-- Exports:
--   Constants: GAME_ID, REMOTE (table of remote names), DIFFICULTIES, etc.
--   Functions: fire(name, ...), invoke(name, ...), getRemote(name),
--              waitForEndpoint(name, timeout), isLobby(), getStageInfo(),
--              listEndpoints(), log(...), notify(window, ...)

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")

local M = {}

----------------------------------------------------------------
-- GAME ID
----------------------------------------------------------------
M.GAME_ID = 4584892739
if game.GameId ~= M.GAME_ID then
	return M
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

----------------------------------------------------------------
-- REMOTE CATALOG
-- Curated subset. Anything not listed here can still be reached via
-- fireByPath / invokeByPath.
----------------------------------------------------------------
M.REMOTE = {
	-- gameplay (5 main)
	spawn_unit              = "spawn_unit",
	upgrade_unit_ingame     = "upgrade_unit_ingame",
	sell_unit_ingame        = "sell_unit_ingame",
	change_priority         = "change_priority",
	use_ingame_spell        = "use_ingame_spell",

	-- misc gameplay
	equip_unit              = "equip_unit",
	unequip_unit            = "unequip_unit",
	full_heal               = "full_heal",
	use_item                = "use_item",
	retreat_units           = "retreat_units",
	attacking_target        = "attacking_target",
	delete_unique_item      = "delete_unique_item",
	delete_unique_items     = "delete_unique_items",
	sell_units              = "sell_units",
	evolve_unit             = "evolve_unit",
	feed_units              = "feed_units",
	autosell_hatched_units  = "autosell_hatched_units",

	-- lobby
	request_join_lobby      = "request_join_lobby",
	request_leave_lobby     = "request_leave_lobby",
	request_lock_level      = "request_lock_level",
	request_start_game      = "request_start_game",
	select_difficulty       = "select_difficulty",
	get_lobby_more_params   = "get_lobby_more_params",
	teleport_back_to_lobby  = "teleport_back_to_lobby",

	-- challenges & portals
	get_normal_challenge    = "get_normal_challenge",
	get_daily_challenge     = "get_daily_challenge",
	get_event_challenges    = "get_event_challenges",
	use_portal              = "use_portal",
	select_roguelike_option = "select_roguelike_option",
	lobby_world_skip        = "lobby_world_skip",

	-- player / social
	request_matchmaking     = "request_matchmaking",
	leave_matchmaking       = "leave_matchmaking",
	claim_daily_reward      = "claim_daily_reward",
	claim_player_level_rewards = "claim_player_level_rewards",

	-- shop
	buy_travelling_merchant_item = "buy_travelling_merchant_item",
	buy_item_generic             = "buy_item_generic",
	buy_from_banner              = "buy_from_banner",
	try_purchase_skin_capacity   = "try_purchase_skin_capacity",
	try_purchase_unit_capacity   = "try_purchase_unit_capacity",

	-- quests
	accept_npc_quest        = "accept_npc_quest",
	try_complete_secret_quest = "try_complete_secret_quest",
	redeem_quest            = "redeem_quest",
	expire_quest            = "expire_quest",
	redeem_loot             = "redeem_loot",

	-- codes / webhooks (just hooks for the bot side; AA has its own code remote)
	redeem_code             = "redeem_code",
	redeem_twitter          = "redeem_twitter",

	-- misc
	get_player_session      = "get_player_session",
	client_loaded_session   = "client_loaded_session",
	get_current_event       = "get_current_event",
	poll_active_items       = "poll_active_items",
	toggle_setting          = "toggle_setting",
	change_setting_slider   = "change_setting_slider",
	vote_start              = "vote_start",
	vote_wave_skip          = "vote_wave_skip",
	set_game_finished_vote  = "set_game_finished_vote",

	-- infinite tower / tournament
	request_start_infinite_tower          = "request_start_infinite_tower",
	request_start_infinite_tower_from_game = "request_start_infinite_tower_from_game",
	request_get_bracket_information        = "request_get_bracket_information",
	request_claim_bracket_rewards          = "request_claim_bracket_rewards",

	-- dungeons
	dungeon_start        = "dungeon_start",
	dungeon_enter_room   = "dungeon_enter_room",
	dungeon_continue_shop = "dungeon_continue_shop",
	dungeon_buy_shop     = "dungeon_buy_shop",
	dungeon_open_chest   = "dungeon_open_chest",
	dungeon_quit         = "dungeon_quit",

	-- missions / daily
	request_quests_data          = "request_quests_data",
	request_current_missions     = "request_current_missions",
	request_missions_data        = "request_missions_data",
	request_claim_mission        = "request_claim_mission",
	request_dailymissions_data   = "request_dailymissions_data",
	request_claim_dailymission   = "request_claim_dailymission",
}

----------------------------------------------------------------
-- ENDPOINT LOOKUP
-- Anime Adventures exposes endpoints under
-- ReplicatedStorage.endpoints.{client_to_server,server_to_client}.
-- Every request from the client is a RemoteFunction.
----------------------------------------------------------------
local endpoints_c2s: Folder? = nil
local endpoints_s2c: Folder? = nil
do
	local ok = pcall(function()
		local eps = ReplicatedStorage:WaitForChild("endpoints", 30)
		endpoints_c2s = eps:WaitForChild("client_to_server", 30) :: Folder
		endpoints_s2c = eps:WaitForChild("server_to_client", 30) :: Folder
	end)
	if not ok then
		warn("[LukihoHub] endpoints not ready within 30s")
	end
end

M.endpoints_c2s = endpoints_c2s
M.endpoints_s2c = endpoints_s2c

function M.getRemote(name: string): any
	if not endpoints_c2s then return nil end
	return endpoints_c2s:FindFirstChild(name)
end

function M.getServerEvent(name: string): any
	if not endpoints_s2c then return nil end
	return endpoints_s2c:FindFirstChild(name)
end

----------------------------------------------------------------
-- FIRE / INVOKE helpers
-- Anime Adventures endpoints are RemoteFunctions, so prefer InvokeServer.
-- Some executors can't return values; fall back to FireServer.
----------------------------------------------------------------
function M.invoke(name: string, ...: any): any
	local r = M.getRemote(name)
	if not r then warn("[LukihoHub] missing remote:", name); return nil end
	local args = { ... }
	local ok, result = pcall(function()
		return (r :: any):InvokeServer(unpack(args))
	end)
	if not ok then warn(string.format("[LukihoHub] invoke(%s) failed: %s", name, tostring(result))) end
	return result
end

function M.fire(name: string, ...: any): ()
	local r = M.getRemote(name)
	if not r then warn("[LukihoHub] missing remote:", name); return end
	local args = { ... }
	pcall(function()
		(r :: any):FireServer(unpack(args))
	end)
end

----------------------------------------------------------------
-- LOBBY / STAGE DETECTION
----------------------------------------------------------------
local function workspaceFind(path: {string}): any
	local current = Workspace
	for _, seg in path do
		current = current:FindFirstChild(seg)
		if not current then return nil end
	end
	return current
end

function M.isLobby(): boolean
	-- In AA the lobby contains a `Lobby` folder and a `lobby_` tagged
	-- instance; the in-game state is signalled by a `game_state` StringValue
	-- inside workspace.Stage.State or a `Map` attribute.
	local state = workspaceFind({ "Stage", "State" })
	if state and state:IsA("StringValue") then
		return state.Value == "Lobby" or state.Value == "LobbyIdle"
	end
	local map = workspaceFind({ "Map" })
	if map then return false end
	local lobby = workspaceFind({ "Lobby" })
	return lobby ~= nil
end

function M.getStageInfo(): { [string]: any }
	local info = {
		state = nil,
		currentWave = nil,
		totalWaves = nil,
		stage = nil,
	}
	local state = workspaceFind({ "Stage", "State" })
	if state and state:IsA("StringValue") then info.state = state.Value end
	local wave = workspaceFind({ "Stage", "CurrentWave" })
	if wave and wave:IsA("IntValue") then info.currentWave = wave.Value end
	local total = workspaceFind({ "Stage", "TotalWaves" })
	if total and total:IsA("IntValue") then info.totalWaves = total.Value end
	local stage = workspaceFind({ "Stage", "StageName" })
	if stage and stage:IsA("StringValue") then info.stage = stage.Value end
	return info
end

----------------------------------------------------------------
-- UTILITY
----------------------------------------------------------------
function M.encode(t: any): string
	return HttpService:JSONEncode(t)
end

function M.decode(s: string): any
	local ok, r = pcall(function() return HttpService:JSONDecode(s) end)
	return if ok then r else nil
end

function M.log(prefix: string, ...: any)
	print(string.format("[LukihoHub:%s]", prefix), ...)
end

----------------------------------------------------------------
-- WINDOW NOTIFY (filled in by main script when MacLib window is built)
----------------------------------------------------------------
M.windowRef = nil
function M.notify(title: string, description: string, duration: number?)
	if M.windowRef and type(M.windowRef.Notify) == "function" then
		pcall(function()
			M.windowRef:Notify({
				Title = title,
				Description = description,
				Duration = duration or 3,
			})
		end)
	end
end

return M
