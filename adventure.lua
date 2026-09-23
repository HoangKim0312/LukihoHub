--!strict
-- adventure.lua  (Anime Adventures, place id 4584892739)
-- Monolithic hub loaded by loader.lua via loadstring + HttpGet.
-- Public surface (only globals we set):
--   _AA_HUB_VERSION = "1.0"
--   _AA_UNLOAD (function set after load)
-- Everything else is local.

local _AA_SUPPORTED_IDS = {
	[4584892739]   = true,  -- legacy Anime Adventures
	[10715453071]  = true,  -- current Anime Adventures (post-update)
	[94823097601547] = true, -- Anime Adventures PlaceId variant
}
if not _AA_SUPPORTED_IDS[game.GameId] and not _AA_SUPPORTED_IDS[game.PlaceId] then return end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local HttpService   = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace     = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local _AA_HUB_VERSION = "1.0"

----------------------------------------------------------------
-- 0. UNLOAD GUARD
----------------------------------------------------------------
local _G = (_G :: any)
if type(_G.LukihoHubUnload) == "function" then
	pcall(_G.LukihoHubUnload)
end

local _AA_connections = {}

local function _AA_on(signal, fn)
	local c = signal:Connect(fn)
	table.insert(_AA_connections, c)
	return c
end

----------------------------------------------------------------
-- 1. REMOTE CATALOG
----------------------------------------------------------------
local _AA_REMOTE = {
	spawn_unit              = "spawn_unit",
	upgrade_unit_ingame     = "upgrade_unit_ingame",
	sell_unit_ingame        = "sell_unit_ingame",
	change_priority         = "change_priority",
	use_ingame_spell        = "use_ingame_spell",
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

	request_join_lobby      = "request_join_lobby",
	request_leave_lobby     = "request_leave_lobby",
	request_lock_level      = "request_lock_level",
	request_start_game      = "request_start_game",
	select_difficulty       = "select_difficulty",
	get_lobby_more_params   = "get_lobby_more_params",
	teleport_back_to_lobby  = "teleport_back_to_lobby",

	get_normal_challenge    = "get_normal_challenge",
	get_daily_challenge     = "get_daily_challenge",
	get_event_challenges    = "get_event_challenges",
	use_portal              = "use_portal",
	select_roguelike_option = "select_roguelike_option",
	lobby_world_skip        = "lobby_world_skip",

	request_matchmaking     = "request_matchmaking",
	leave_matchmaking       = "leave_matchmaking",
	claim_daily_reward      = "claim_daily_reward",
	claim_player_level_rewards = "claim_player_level_rewards",

	buy_travelling_merchant_item = "buy_travelling_merchant_item",
	buy_item_generic             = "buy_item_generic",
	buy_from_banner              = "buy_from_banner",
	try_purchase_skin_capacity   = "try_purchase_skin_capacity",
	try_purchase_unit_capacity   = "try_purchase_unit_capacity",

	accept_npc_quest        = "accept_npc_quest",
	try_complete_secret_quest = "try_complete_secret_quest",
	redeem_quest            = "redeem_quest",
	expire_quest            = "expire_quest",
	redeem_loot             = "redeem_loot",

	redeem_code             = "redeem_code",
	redeem_twitter          = "redeem_twitter",

	get_player_session      = "get_player_session",
	client_loaded_session   = "client_loaded_session",
	get_current_event       = "get_current_event",
	poll_active_items       = "poll_active_items",
	toggle_setting          = "toggle_setting",
	change_setting_slider   = "change_setting_slider",
	vote_start              = "vote_start",
	vote_wave_skip          = "vote_wave_skip",
	set_game_finished_vote  = "set_game_finished_vote",

	request_start_infinite_tower          = "request_start_infinite_tower",
	request_start_infinite_tower_from_game = "request_start_infinite_tower_from_game",
	request_get_bracket_information        = "request_get_bracket_information",
	request_claim_bracket_rewards          = "request_claim_bracket_rewards",

	dungeon_start        = "dungeon_start",
	dungeon_enter_room   = "dungeon_enter_room",
	dungeon_continue_shop = "dungeon_continue_shop",
	dungeon_buy_shop     = "dungeon_buy_shop",
	dungeon_open_chest   = "dungeon_open_chest",
	dungeon_quit         = "dungeon_quit",

	request_quests_data          = "request_quests_data",
	request_current_missions     = "request_current_missions",
	request_missions_data        = "request_missions_data",
	request_claim_mission        = "request_claim_mission",
	request_dailymissions_data   = "request_dailymissions_data",
	request_claim_dailymission   = "request_claim_dailymission",
}

----------------------------------------------------------------
-- 2. ENDPOINT LOOKUP (no WaitForChild: FindFirstChild + warn instead)
----------------------------------------------------------------
local _AA_endpoints_c2s = nil
local _AA_endpoints_s2c = nil
do
	local ok = pcall(function()
		local eps = ReplicatedStorage:FindFirstChild("endpoints")
		if not eps then return end
		_AA_endpoints_c2s = eps:FindFirstChild("client_to_server")
		_AA_endpoints_s2c = eps:FindFirstChild("server_to_client")
	end)
	if not ok or not _AA_endpoints_c2s then
		warn("[LukihoHub] endpoints not ready; remotes will be no-ops")
	end
end

local function _AA_get_remote(name)
	if not _AA_endpoints_c2s then return nil end
	return _AA_endpoints_c2s:FindFirstChild(name)
end

local function _AA_get_server_event(name)
	if not _AA_endpoints_s2c then return nil end
	return _AA_endpoints_s2c:FindFirstChild(name)
end

local function _AA_invoke(name, ...)
	local r = _AA_get_remote(name)
	if not r then
		warn("[LukihoHub] missing remote:", name)
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return (r :: any):InvokeServer(unpack(args))
	end)
	if not ok then
		warn(string.format("[LukihoHub] invoke(%s) failed: %s", name, tostring(result)))
	end
	return result
end

local function _AA_fire(name, ...)
	local r = _AA_get_remote(name)
	if not r then return end
	local args = { ... }
	pcall(function()
		(r :: any):FireServer(unpack(args))
	end)
end

----------------------------------------------------------------
-- 3. STAGE / LOBBY HELPERS
----------------------------------------------------------------
local function _AA_workspaceFind(path)
	local current = Workspace
	for _, seg in path do
		current = current:FindFirstChild(seg)
		if not current then return nil end
	end
	return current
end

local function _AA_inLobby()
	local state = _AA_workspaceFind({ "Stage", "State" })
	if state and state:IsA("StringValue") then
		return state.Value == "Lobby" or state.Value == "LobbyIdle"
	end
	local map = _AA_workspaceFind({ "Map" })
	if map then return false end
	local lobby = _AA_workspaceFind({ "Lobby" })
	return lobby ~= nil
end

local function _AA_getStageInfo()
	local info = { state = nil, currentWave = nil, totalWaves = nil, stage = nil }
	local state = _AA_workspaceFind({ "Stage", "State" })
	if state and state:IsA("StringValue") then info.state = state.Value end
	local wave = _AA_workspaceFind({ "Stage", "CurrentWave" })
	if wave and wave:IsA("IntValue") then info.currentWave = wave.Value end
	local total = _AA_workspaceFind({ "Stage", "TotalWaves" })
	if total and total:IsA("IntValue") then info.totalWaves = total.Value end
	local stage = _AA_workspaceFind({ "Stage", "StageName" })
	if stage and stage:IsA("StringValue") then info.stage = stage.Value end
	return info
end

local function _AA_getWave()
	return _AA_getStageInfo().currentWave or 0
end

local function _AA_inGame()
	local info = _AA_getStageInfo()
	return info.state ~= nil and info.state ~= "Lobby" and info.state ~= "LobbyIdle"
end

----------------------------------------------------------------
-- 4. STATIC DATA
----------------------------------------------------------------
local _AA_DATA = {
	DIFFICULTIES = { "Easy", "Normal", "Hard", "Insane" },
	JOIN_MODES   = { "Story", "Infinite", "LegendStage", "Raid" },
	MAPS = {
		"Naruto", "Demon Slayer", "My Hero Academia",
		"Jujutsu Kaisen", "Bleach", "One Piece",
		"Dragon Ball", "Hunter x Hunter", "JoJo",
		"Fairy Tail", "Seven Deadly Sins", "Black Clover",
		"Halloween", "Christmas", "April", "Namek",
		"Dressrosa", "Marineford", "Sunraku",
	},
	ACTS  = { "Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6" },
	PORTALS = {
		"final_disc", "april_portal", "marineford_portal",
		"naruto_portal", "demonslayer_portal", "jjk_portal",
		"hxh_portal", "namek_portal", "dressrosa_portal",
		"halloween_portal", "christmas_portal", "bleach_portal",
		"clover_portal", "7ds_portal", "fairytail_portal",
		"aot_portal", "opm_portal", "mha_portal",
		"sunraku_portal", "csm_portal", "jojo_portal",
	},
	TIERS = { "T1", "T2", "T3", "T4", "T5" },
	BUFF_CARDS = {
		"Double Damage", "Gold Boost", "Range Boost",
		"Cooldown Reduction", "Extra Slot", "Speed Boost",
	},
	DEBUFF_CARDS = {
		"Half Damage", "Slow Enemies", "Reduce Range",
		"Increase Cooldowns", "Less Gold",
	},
	SKIN_RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	CAPSULE_TYPES = { "Standard", "Premium", "Event" },
	KNOWN_CODES = {
		"SORRYFORSHUTDOWN", "NEVERDIE", "RAIDNARUTO",
		"RAIDMARINEFORD", "HEROIC", "SUBTOSUBTOMETAVERSE",
	},
}

----------------------------------------------------------------
-- 5. LOBBY STATE
----------------------------------------------------------------
local _AA_LOBBY = {
	autoJoin = false,
	autoChallenge = false,
	autoPortal = false,
	autoJoinPlayer = false,
	joinMode = "Story",
	selectedMap = "Naruto",
	selectedAct = "Act 1",
	difficulty = "Normal",
	friendsOnly = false,
	autoStart = false,
	autoStartDelay = 5,
	ignoreWorlds = {},
	ignoreModifiers = {},
	selectedPortal = "final_disc",
	portalDifficulty = "Normal",
	portalTiers = {},
	ignoreDmgBonus = false,
	joinPlayerName = "",
}

local function _AA_joinStory()
	_AA_invoke(_AA_REMOTE.request_join_lobby, "Story", _AA_LOBBY.selectedMap, _AA_LOBBY.selectedAct, _AA_LOBBY.difficulty, _AA_LOBBY.friendsOnly)
end
local function _AA_joinInfinite()
	_AA_invoke(_AA_REMOTE.request_join_lobby, "Infinite", _AA_LOBBY.selectedMap, _AA_LOBBY.selectedAct, _AA_LOBBY.difficulty, _AA_LOBBY.friendsOnly)
end
local function _AA_joinLegend()
	_AA_invoke(_AA_REMOTE.request_join_lobby, "LegendStage", _AA_LOBBY.selectedMap, _AA_LOBBY.selectedAct, _AA_LOBBY.difficulty, _AA_LOBBY.friendsOnly)
end
local function _AA_joinRaid()
	_AA_invoke(_AA_REMOTE.request_join_lobby, "Raid", _AA_LOBBY.selectedMap, _AA_LOBBY.difficulty, _AA_LOBBY.friendsOnly)
end

local function _AA_joinPlayer(name)
	if name == nil or name == "" then return end
	_AA_invoke(_AA_REMOTE.request_matchmaking, _AA_LOBBY.selectedMap)
end

local function _AA_refreshFriends()
	local ok, pages = pcall(function() return Players:GetFriendsAsync(Players.LocalPlayer.UserId) end)
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

local function _AA_lobbyTick(dt)
	if _AA_LOBBY.autoJoin and _AA_inLobby() then
		if _AA_LOBBY.joinMode == "Story" then _AA_joinStory()
		elseif _AA_LOBBY.joinMode == "Infinite" then _AA_joinInfinite()
		elseif _AA_LOBBY.joinMode == "LegendStage" then _AA_joinLegend()
		elseif _AA_LOBBY.joinMode == "Raid" then _AA_joinRaid()
		end
		_AA_LOBBY.autoJoin = false
	end
	if _AA_LOBBY.autoChallenge and _AA_inLobby() then
		local challenges = _AA_invoke(_AA_REMOTE.get_daily_challenge) or {}
		for _, challenge in challenges do
			local name = challenge.Name or challenge.name or tostring(challenge)
			local ignored = false
			for _, ig in _AA_LOBBY.ignoreWorlds do if ig == name then ignored = true; break end end
			if not ignored then
				for _, ig in _AA_LOBBY.ignoreModifiers do if ig == name then ignored = true; break end end
			end
			if not ignored then
				_AA_invoke(_AA_REMOTE.request_join_lobby, "Challenge", challenge)
				break
			end
		end
		_AA_LOBBY.autoChallenge = false
	end
	if _AA_LOBBY.autoPortal and _AA_inLobby() then
		_AA_invoke(_AA_REMOTE.use_portal, _AA_LOBBY.selectedPortal, _AA_LOBBY.portalDifficulty, _AA_LOBBY.portalTiers, _AA_LOBBY.ignoreDmgBonus)
		_AA_LOBBY.autoPortal = false
	end
	if _AA_LOBBY.autoStart and _AA_inLobby() then
		task.delay(_AA_LOBBY.autoStartDelay, function()
			_AA_invoke(_AA_REMOTE.request_start_game)
		end)
		_AA_LOBBY.autoStart = false
	end
end

----------------------------------------------------------------
-- 6. SHOP STATE
----------------------------------------------------------------
local _AA_SHOP = {
	autoDeletePortal = false,
	autoOpenCapsules = false,
	autoSellSkins = false,
	capsuleType = "Standard",
	skinMinRarity = "Rare",
	deletePortalMinTier = "T3",
}

local function _AA_listPortals()
	local ok, list = pcall(function()
		local folder = ReplicatedStorage:FindFirstChild("player_portals")
		if not folder then return {} end
		local userFolder = folder:FindFirstChild(tostring(Players.LocalPlayer.UserId))
		if not userFolder then return {} end
		local out = {}
		for _, p in userFolder:GetChildren() do
			local tier = p:GetAttribute("tier") or p:GetAttribute("Tier") or "?"
			table.insert(out, { name = p.Name, tier = tostring(tier) })
		end
		return out
	end)
	return if ok then list else {}
end

local function _AA_deletePortal(name)
	_AA_invoke(_AA_REMOTE.delete_unique_item, name)
	_AA_invoke(_AA_REMOTE.delete_unique_items, { name })
end

local _AA_TIER_ORDER = { T1 = 1, T2 = 2, T3 = 3, T4 = 4, T5 = 5 }

local function _AA_deletePortalsBelowTier(tier)
	local cutoff = _AA_TIER_ORDER[tier] or 3
	for _, portal in _AA_listPortals() do
		local rank = _AA_TIER_ORDER[portal.tier] or 0
		if rank > 0 and rank < cutoff then _AA_deletePortal(portal.name) end
	end
end

local function _AA_openCapsuleOnce()
	_AA_invoke(_AA_REMOTE.buy_from_banner, _AA_SHOP.capsuleType, 1)
end

local function _AA_listSkins()
	local ok, list = pcall(function()
		local folder = ReplicatedStorage:FindFirstChild("player_skins")
		if not folder then return {} end
		local userFolder = folder:FindFirstChild(tostring(Players.LocalPlayer.UserId))
		if not userFolder then return {} end
		local out = {}
		for _, s in userFolder:GetChildren() do
			local rarity = s:GetAttribute("rarity") or s:GetAttribute("Rarity") or "Common"
			local equipped = s:GetAttribute("equipped") or false
			table.insert(out, { name = s.Name, rarity = tostring(rarity), equipped = equipped })
		end
		return out
	end)
	return if ok then list else {}
end

local _AA_RARITY_RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

local function _AA_sellSkinBelowMin()
	local cutoff = _AA_RARITY_RANK[_AA_SHOP.skinMinRarity] or 2
	for _, skin in _AA_listSkins() do
		if not skin.equipped and (_AA_RARITY_RANK[skin.rarity] or 0) < cutoff then
			_AA_invoke(_AA_REMOTE.delete_unique_item, skin.name)
		end
	end
end

local function _AA_shopTick()
	if _AA_SHOP.autoDeletePortal then _AA_deletePortalsBelowTier(_AA_SHOP.deletePortalMinTier); _AA_SHOP.autoDeletePortal = false end
	if _AA_SHOP.autoOpenCapsules then _AA_openCapsuleOnce() end
	if _AA_SHOP.autoSellSkins then _AA_sellSkinBelowMin(); _AA_SHOP.autoSellSkins = false end
end

----------------------------------------------------------------
-- 7. IN-GAME STATE
----------------------------------------------------------------
local _AA_INGAME = {
	autoSellOnWave = false,
	autoSellFarmsOnWave = false,
	autoLeaveOnWave = false,
	autoUpgradeOnWave = false,
	autoUpgradeFarmsOnly = false,
	autoUpgradeCap = 9,
	autoPlace = false,
	autoPlacePos = nil,
	autoPlaceUnitId = nil,
	autoPlaceCap = 6,
	recording = false,
	recordingName = "",
	lastWave = 0,
	lastRecordStep = 0,
	recordStepDelay = 0.25,
}

local _AA_steps = {}

local function _AA_listFieldUnits()
	local out = {}
	local folder = Workspace:FindFirstChild("placed_units")
	if not folder then return out end
	local userFolder = folder:FindFirstChild(tostring(Players.LocalPlayer.UserId))
	if not userFolder then return out end
	for _, unit in userFolder:GetChildren() do
		if unit:IsA("Model") then table.insert(out, unit) end
	end
	return out
end

local function _AA_isFarm(unit)
	local id = unit:GetAttribute("unit_id") or unit.Name or ""
	return string.find(string.lower(id), "farm", 1, true) ~= nil
end

local function _AA_unitName(unit)
	return unit:GetAttribute("unit_id") or unit.Name
end

local function _AA_sellUnit(unit) _AA_invoke(_AA_REMOTE.sell_unit_ingame, _AA_unitName(unit)) end
local function _AA_upgradeUnit(unit) _AA_invoke(_AA_REMOTE.upgrade_unit_ingame, _AA_unitName(unit)) end

local function _AA_ingameTickWaveActions()
	if not _AA_inGame() then return end
	local wave = _AA_getWave()
	if wave == _AA_INGAME.lastWave then return end
	_AA_INGAME.lastWave = wave

	if _AA_INGAME.autoSellOnWave then
		for _, unit in _AA_listFieldUnits() do
			if _AA_INGAME.autoSellFarmsOnWave or not _AA_isFarm(unit) then _AA_sellUnit(unit) end
		end
	end
	if _AA_INGAME.autoLeaveOnWave then _AA_invoke(_AA_REMOTE.teleport_back_to_lobby) end
	if _AA_INGAME.autoUpgradeOnWave then
		for _, unit in _AA_listFieldUnits() do
			if _AA_INGAME.autoUpgradeFarmsOnly and not _AA_isFarm(unit) then continue end
			local lvl = unit:GetAttribute("level") or 0
			if lvl < _AA_INGAME.autoUpgradeCap then _AA_upgradeUnit(unit) end
		end
	end
end

local function _AA_ingameTickPlace()
	if not _AA_INGAME.autoPlace or not _AA_inGame() then return end
	if not _AA_INGAME.autoPlaceUnitId or not _AA_INGAME.autoPlacePos then return end
	if #_AA_listFieldUnits() >= _AA_INGAME.autoPlaceCap then return end
	_AA_invoke(_AA_REMOTE.spawn_unit, _AA_INGAME.autoPlaceUnitId, _AA_INGAME.autoPlacePos)
end

local function _AA_ingameTick() _AA_ingameTickWaveActions(); _AA_ingameTickPlace() end

----------------------------------------------------------------
-- 8. MACRO STORAGE
----------------------------------------------------------------
local _AA_macroStore = {}
local _AA_macroFolder = "LukihoHub/macros"

local function _AA_ensureFolder()
	if type(makefolder) == "function" then
		pcall(makefolder, "LukihoHub")
		pcall(makefolder, _AA_macroFolder)
	end
end

local function _AA_writeFile(path, content)
	if type(writefile) ~= "function" then return false end
	local ok = pcall(writefile, path, content)
	return ok
end

local function _AA_readFile(path)
	if type(readfile) ~= "function" then return nil end
	local ok, content = pcall(readfile, path)
	if ok then return content end
	return nil
end

local function _AA_listFiles(path)
	if type(listfiles) ~= "function" then return {} end
	local ok, list = pcall(listfiles, path)
	if ok and type(list) == "table" then return list end
	return {}
end

local function _AA_macroSave(name, steps)
	_AA_ensureFolder()
	_AA_macroStore[name] = { steps = steps, created = os.time() }
	_AA_writeFile(_AA_macroFolder .. "/" .. name .. ".json", HttpService:JSONEncode(_AA_macroStore[name]))
end

local function _AA_macroLoad(name)
	if _AA_macroStore[name] then return _AA_macroStore[name] end
	local raw = _AA_readFile(_AA_macroFolder .. "/" .. name .. ".json")
	if not raw then return nil end
	local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and parsed then _AA_macroStore[name] = parsed; return parsed end
	return nil
end

local function _AA_macroList()
	local set = {}
	for n in _AA_macroStore do set[n] = true end
	for _, path in _AA_listFiles(_AA_macroFolder) do
		local base = path:match("([^/\\]+)%.json$")
		if base then set[base] = true end
	end
	local out = {}
	for n in set do table.insert(out, n) end
	table.sort(out)
	return out
end

local function _AA_macroDelete(name)
	_AA_macroStore[name] = nil
	if type(delfile) == "function" then pcall(delfile, _AA_macroFolder .. "/" .. name .. ".json") end
end

local function _AA_macroImport(name, source, mode)
	if name == nil or name == "" then return false end
	mode = mode or "Link"
	local content = nil
	if mode == "Link" then
		if typeof((HttpService :: any).GetAsync) == "function" then
			local ok, r = pcall(function() return (HttpService :: any):GetAsync(source) end)
			if ok then content = r end
		elseif type(game.HttpGet) == "function" then
			local ok, r = pcall(function() return (game :: any):HttpGet(source) end)
			if ok then content = r end
		end
	else
		content = source
	end
	if not content then return false end
	local ok, parsed = pcall(function() return HttpService:JSONDecode(content) end)
	if not ok or not parsed or not parsed.steps then return false end
	_AA_macroSave(name, parsed.steps)
	return true
end

local function _AA_macroExport(name)
	local entry = _AA_macroLoad(name)
	if not entry then return nil end
	return HttpService:JSONEncode(entry)
end

local function _AA_appendStep(step) table.insert(_AA_steps, step) end
local function _AA_clearSteps() table.clear(_AA_steps) end
local function _AA_getSteps() return _AA_steps end

local function _AA_macroStartRecord(name)
	if _AA_INGAME.recording then return false end
	_AA_INGAME.recording = true
	_AA_INGAME.recordingName = name
	_AA_INGAME.lastRecordStep = os.clock()
	_AA_clearSteps()
	return true
end

local function _AA_macroStopRecord()
	_AA_INGAME.recording = false
	local steps = _AA_getSteps()
	_AA_macroSave(_AA_INGAME.recordingName, steps)
	return { name = _AA_INGAME.recordingName, count = #steps }
end

local function _AA_macroRecordStep(step)
	if not _AA_INGAME.recording then return end
	if os.clock() - _AA_INGAME.lastRecordStep < _AA_INGAME.recordStepDelay then return end
	_AA_INGAME.lastRecordStep = os.clock()
	step.t = step.t or "place"
	step.time = os.clock()
	_AA_appendStep(step)
end

local function _AA_macroPlay(name)
	local entry = _AA_macroLoad(name)
	if not entry then return false, "not found" end
	task.spawn(function()
		for _, step in entry.steps do
			if step.t == "place" then _AA_invoke(_AA_REMOTE.spawn_unit, step.unitId, step.cframe)
			elseif step.t == "upgrade" then _AA_invoke(_AA_REMOTE.upgrade_unit_ingame, step.unitId)
			elseif step.t == "sell" then _AA_invoke(_AA_REMOTE.sell_unit_ingame, step.unitId)
			elseif step.t == "priority" then _AA_invoke(_AA_REMOTE.change_priority, step.unitId, step.priority)
			elseif step.t == "spell" then _AA_invoke(_AA_REMOTE.use_ingame_spell, step.unitId)
			end
			if step.time then task.wait(step.time) end
		end
	end)
	return true
end

----------------------------------------------------------------
-- 9. EVENT CARD
----------------------------------------------------------------
local _AA_EC = {
	autoPick = false,
	untilWave = 0,
	onlyDebuffs = false,
	onlyHighDebuffs = false,
	ignoreBuffs = false,
	limit = 0,
	priorityList = {},
}
local _AA_pickedSoFar = 0
local _AA_lastWaveSeen = 0

do
	local offered = _AA_get_server_event("event_card_offered")
	if offered then
		pcall(function()
			(offered :: any).OnClientEvent:Connect(function(payload)
				if not _AA_EC.autoPick then return end
				local wave = (payload and payload.wave) or 0
				if _AA_EC.untilWave > 0 and wave > _AA_EC.untilWave then return end
				local cards = (payload and payload.cards) or {}
				local best, bestScore = nil, -math.huge
				for _, card in cards do
					local name = card.name or card.Name or ""
					local isDebuff = card.is_debuff or card.isDebuff or false
					local highDebuff = card.high_debuff or card.highDebuff or false
					if not isDebuff and (_AA_EC.onlyDebuffs or _AA_EC.ignoreBuffs) then continue end
					if _AA_EC.onlyHighDebuffs and not highDebuff then continue end
					local score = 0
					for i, p in _AA_EC.priorityList do
						if p == name then score = score + (#_AA_EC.priorityList - i + 1) * 10 end
					end
					if isDebuff then score = score + 5 end
					if highDebuff then score = score + 10 end
					if score > bestScore then bestScore = score; best = card end
				end
				if best and (_AA_EC.limit == 0 or _AA_pickedSoFar < _AA_EC.limit) then
					_AA_invoke(_AA_REMOTE.select_roguelike_option, best.id or best.Id)
					_AA_pickedSoFar = _AA_pickedSoFar + 1
					_AA_lastWaveSeen = wave
				end
			end)
		end)
	end
end

local function _AA_ecTick()
	if _AA_EC.untilWave > 0 and _AA_lastWaveSeen > _AA_EC.untilWave then _AA_EC.autoPick = false end
end

----------------------------------------------------------------
-- 10. MISC / WEBHOOK / HIDE / FPS / RECONNECT
----------------------------------------------------------------
local _AA_MISC = {
	webhookURL = "",
	pingUserID = "",
	pingOnSelected = {},
	pingOnSecretDrop = false,
	autoHideUI = false,
	hideMap = false,
	hideName = false,
	fakeOutfit = false,
	autoReconnect = false,
	showTakedowns = true,
	coloredTakedowns = false,
	setFps = 0,
	autoClaimQuests = false,
	autoTakeDailyQuests = false,
	autoClaimDaily = true,
	autoClaimPlayerLevel = true,
}

local function _AA_postWebhook(url, payload)
	if url == nil or url == "" then return end
	local ok, body = pcall(function() return HttpService:JSONEncode(payload) end)
	if not ok then return end
	pcall(function()
		(HttpService :: any):PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
	end)
end

local function _AA_notifyWebhook(title, description, color, ping)
	if _AA_MISC.webhookURL == "" then return end
	local payload = {
		username = "LukihoHub",
		embeds = { { title = title, description = description, color = color or 0x00BFFF, footer = { text = "Anime Adventures" } } },
	}
	if ping and _AA_MISC.pingUserID ~= "" then payload.content = "<@" .. _AA_MISC.pingUserID .. ">" end
	_AA_postWebhook(_AA_MISC.webhookURL, payload)
end

local function _AA_setUIHidden(hidden)
	_AA_MISC.autoHideUI = hidden
	pcall(function()
		local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if not gui then return end
		for _, screen in gui:GetDescendants() do
			if screen:IsA("ScreenGui") and screen.Name ~= "LukihoHub" then screen.Enabled = not hidden end
		end
	end)
end

local function _AA_setMapHidden(hidden)
	_AA_MISC.hideMap = hidden
	pcall(function()
		for _, d in Workspace:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("IsMapPiece") then
				d.Transparency = if hidden then 1 else (d:GetAttribute("DefaultTransparency") or 0)
			end
		end
	end)
end

local function _AA_setNamesHidden(hidden)
	_AA_MISC.hideName = hidden
	pcall(function()
		for _, p in Workspace:GetDescendants() do
			if p:IsA("BillboardGui") and string.find(p.Name:lower(), "name", 1, true) then p.Enabled = not hidden end
		end
	end)
end

local function _AA_setFakeOutfit(enabled)
	_AA_MISC.fakeOutfit = enabled
	pcall(function()
		local char = Players.LocalPlayer.Character
		if not char then return end
		for _, part in char:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.Transparency = if enabled then 1 else 0 end
		end
	end)
end

local function _AA_setFps(cap)
	_AA_MISC.setFps = cap
	if cap > 0 and type(setfpscap) == "function" then pcall(setfpscap, cap) end
end

local function _AA_tryReconnect()
	pcall(function() TeleportService:Teleport(game.PlaceId, Players.LocalPlayer) end)
end

_AA_on(Players.PlayerRemoving, function(player)
	if player == Players.LocalPlayer and _AA_MISC.autoReconnect then
		task.delay(2, function() pcall(function() TeleportService:Teleport(game.PlaceId) end) end)
	end
end)

local _AA_takedownCount = 0
local function _AA_bumpTakedowns(n) _AA_takedownCount = _AA_takedownCount + n end
local function _AA_showTakedowns() return _AA_takedownCount end

local function _AA_redeemAllCodes()
	for _, code in _AA_DATA.KNOWN_CODES do _AA_invoke(_AA_REMOTE.redeem_code, code) end
end

local function _AA_claimDaily()
	if _AA_MISC.autoClaimDaily then _AA_invoke(_AA_REMOTE.claim_daily_reward) end
	if _AA_MISC.autoClaimPlayerLevel then _AA_invoke(_AA_REMOTE.claim_player_level_rewards) end
end

local function _AA_takeDailyQuests()
	_AA_invoke(_AA_REMOTE.request_dailymissions_data)
end

local function _AA_claimQuests()
	if not _AA_MISC.autoClaimQuests then return end
	local daily = _AA_invoke(_AA_REMOTE.request_dailymissions_data) or {}
	for _, q in daily do if q.id then _AA_invoke(_AA_REMOTE.request_claim_dailymission, q.id) end end
	local main = _AA_invoke(_AA_REMOTE.request_missions_data) or {}
	for _, q in main do if q.id then _AA_invoke(_AA_REMOTE.request_claim_mission, q.id) end end
end

local function _AA_miscTick()
	if _AA_MISC.autoTakeDailyQuests then _AA_takeDailyQuests(); _AA_MISC.autoTakeDailyQuests = false end
	_AA_claimQuests()
	_AA_claimDaily()
end

----------------------------------------------------------------
-- 11. MASTER TICK
----------------------------------------------------------------
local function _AA_tick(dt)
	_AA_lobbyTick(dt)
	_AA_shopTick()
	_AA_miscTick()
	_AA_ingameTick()
	_AA_ecTick()
end

_AA_on(RunService.Heartbeat, _AA_tick)

----------------------------------------------------------------
-- 12. UI
----------------------------------------------------------------
local _AA_Window = nil

----------------------------------------------------------------
-- In-game debug overlay (visible in Potassium without F9).
-- Always-on ScreenGui pinned top-left, scrollable list of recent
-- log lines + color-coded by level. Independent from MacLib —
-- works even if the UI library fails to load.
----------------------------------------------------------------
local _AA_LOG_BUFFER = {}
local _AA_LOG_MAX = 200
local _AA_debugGui

local function _AA_log(level, msg)
	local line = string.format("[%s] %s", level, tostring(msg))
	table.insert(_AA_LOG_BUFFER, 1, { line = line, level = level, t = os.clock() })
	if #_AA_LOG_BUFFER > _AA_LOG_MAX then
		table.remove(_AA_LOG_BUFFER)
	end

	-- Write to executor console too, in case F9 *does* exist.
	pcall(function() warn(line) end)

	-- Mirror to in-game overlay if it's already built.
	if _AA_debugGui and _AA_debugGui.list then
		pcall(function()
			local entry = Instance.new("TextLabel")
			entry.BackgroundTransparency = 1
			entry.Size = UDim2.new(1, 0, 0, 16)
			entry.Font = Enum.Font.Code
			entry.TextSize = 12
			entry.TextXAlignment = Enum.TextXAlignment.Left
			entry.Text = line
			entry.TextColor3 = (level == "ERROR" and Color3.fromRGB(255, 90, 90))
				or (level == "WARN" and Color3.fromRGB(255, 200, 80))
				or (level == "OK" and Color3.fromRGB(80, 255, 120))
				or Color3.fromRGB(220, 220, 220)
			entry.Parent = _AA_debugGui.list
			if #_AA_debugGui.list:GetChildren() > _AA_LOG_MAX then
				local first = _AA_debugGui.list:GetChildren()[1]
				if first then first:Destroy() end
			end
		end)
	end
end

local function _AA_fetchRaw(url)
	local ok, body = pcall(function() return (game :: any):HttpGet(url) end)
	if not ok or type(body) ~= "string" or #body < 100 then
		_AA_log("WARN", "fetch failed: " .. url)
		return nil
	end
	return body
end

local function _AA_buildDebugGui()
	if _AA_debugGui then return end
	pcall(function()
		local Players = game:GetService("Players")
		local LocalPlayer = Players.LocalPlayer
		if not LocalPlayer then return end
		local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not PlayerGui then return end

		local gui = Instance.new("ScreenGui")
		gui.Name = "LukihoDebug"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 999
		gui.Parent = PlayerGui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(440, 320)
		frame.Position = UDim2.fromOffset(16, 16)
		frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		frame.Parent = gui
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 24)
		title.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
		title.BorderSizePixel = 0
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.Text = "LukihoHub · Debug Log (Potassium)"
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.PaddingLeft = UDim.new(0, 8)
		title.Parent = frame
		Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

		local close = Instance.new("TextButton")
		close.Size = UDim2.fromOffset(24, 24)
		close.Position = UDim2.new(1, -28, 0, 0)
		close.BackgroundTransparency = 1
		close.Font = Enum.Font.GothamBold
		close.TextSize = 16
		close.Text = "X"
		close.TextColor3 = Color3.fromRGB(255, 100, 100)
		close.Parent = frame
		close.MouseButton1Click = function() gui:Destroy() end

		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, -8, 1, -32)
		scroll.Position = UDim2.fromOffset(4, 28)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = frame

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scroll

		_AA_debugGui = { gui = gui, list = scroll }
	end)
end

local function _AA_loadMacLib()
	-- MacLib is injected by loader.lua as _G._AA_MACLIB (already compiled).
	-- The hub never fetches UI libraries on its own.
	if type(_G._AA_MACLIB) == "table" then
		return _G._AA_MACLIB, "injected"
	end
	return nil, "not-injected-by-loader"
end

-- Build the debug overlay before anything else so even early errors show.
_AA_buildDebugGui()
_AA_log("INFO", string.format("LukihoHub v%s starting (place=%d)", _AA_HUB_VERSION, game.PlaceId))

do
	local MacLib, via = _AA_loadMacLib()
	if not MacLib then
		_AA_log("ERROR", "MacLib unavailable (" .. tostring(via) .. ") — running headless; debug overlay still active.")
	else
		_AA_log("OK", "MacLib loaded via " .. tostring(via))
		local ok, win = pcall(function()
			return MacLib:Window({
				Title = "LukihoHub",
				Subtitle = "Anime Adventures | v" .. _AA_HUB_VERSION,
				Size = UDim2.fromOffset(820, 580),
				DragStyle = 1,
				ShowUserInfo = false,
				Keybind = Enum.KeyCode.RightControl,
				AcrylicBlur = false,
			})
		end)
		if not ok then
			_AA_log("ERROR", "MacLib:Window threw: " .. tostring(win))
		elseif not win then
			_AA_log("ERROR", "MacLib returned no window.")
		else
			_AA_Window = win
			_AA_log("OK", "UI Window created — press RightControl to toggle.")
		end
	end
end

-- Auto-open UI immediately when window is created (most executors
-- steal RightControl; K is a safer default keybind).
_AA_on(UserInputService.InputBegan, function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.K then
		if _AA_Window and type((_AA_Window :: any).Toggle) == "function" then
			pcall(function() (_AA_Window :: any):Toggle() end)
		end
	end
end)

if _AA_Window then
	-- MacLib on certain executor forks throws "Unable to assign property
	-- Text. string expected, got nil" inside its internal layout pass.
	-- Build each tab inside its own pcall so a single bad tab doesn't
	-- wipe out every other tab. The Window stays open either way.
	local function _AA_build(name, fn)
		local ok, err = pcall(fn)
		if not ok then _AA_log("ERROR", name .. " tab failed: " .. tostring(err)) end
	end
	local TabGroup = _AA_Window:TabGroup()

	-- HOME
	_AA_build("Home", function()
		local tab = TabGroup:Tab({ Name = "Home" })
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Welcome" })
		left:Paragraph({ Header = "LukihoHub", Body = "Anime Adventures automation. RightControl to toggle." })
		left:Paragraph({ Header = "Version", Body = _AA_HUB_VERSION })
		left:Button({ Name = "Unload Hub", Callback = function() _AA_unload() end })
		local right = tab:Section({ Side = "Right" })
		right:Header({ Text = "Live" })
		local stateLabel = right:Paragraph({ Header = "State", Body = "?" })
		local waveLabel  = right:Paragraph({ Header = "Wave",  Body = "0" })
		_AA_on(RunService.Heartbeat, function()
			local info = _AA_getStageInfo()
			if stateLabel and stateLabel.UpdateBody then stateLabel:UpdateBody(tostring(info.state or "?")) end
			if waveLabel  and waveLabel.UpdateBody  then waveLabel:UpdateBody(tostring(info.currentWave or 0)) end
		end)
	end)

	-- LOBBY
	_AA_build("Lobby", function()
		local tab = TabGroup:Tab({ Name = "Lobby" })
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Auto Join Map" })
		left:Dropdown({ Name = "Join Mode", Search = false, Multi = false, Required = false, Options = _AA_DATA.JOIN_MODES, Default = 1, Callback = function(v) _AA_LOBBY.joinMode = v end }, "JoinMode")
		left:Dropdown({ Name = "Map", Search = true, Multi = false, Required = false, Options = _AA_DATA.MAPS, Default = 1, Callback = function(v) _AA_LOBBY.selectedMap = v end }, "Map")
		left:Dropdown({ Name = "Act", Search = false, Multi = false, Required = false, Options = _AA_DATA.ACTS, Default = 1, Callback = function(v) _AA_LOBBY.selectedAct = v end }, "Act")
		left:Dropdown({ Name = "Difficulty", Search = false, Multi = false, Required = false, Options = _AA_DATA.DIFFICULTIES, Default = 2, Callback = function(v) _AA_LOBBY.difficulty = v end }, "Difficulty")
		left:Toggle({ Name = "Friends Only", Default = false, Callback = function(v) _AA_LOBBY.friendsOnly = v end }, "FriendsOnly")
		left:Toggle({ Name = "Auto Join", Default = false, Callback = function(v) _AA_LOBBY.autoJoin = v end }, "AutoJoin")
		left:Slider({ Name = "Auto Start Delay (s)", Default = 5, Minimum = 0, Maximum = 30, DisplayMethod = "Value", Precision = 0, Callback = function(v) _AA_LOBBY.autoStartDelay = v end }, "AutoStartDelay")
		left:Toggle({ Name = "Auto Start", Default = false, Callback = function(v) _AA_LOBBY.autoStart = v end }, "AutoStart")
		local right = tab:Section({ Side = "Right" })
		right:Header({ Text = "Auto Challenge" })
		right:Dropdown({ Name = "Ignore Worlds", Search = true, Multi = true, Required = false, Options = _AA_DATA.MAPS, Default = {}, Callback = function(v) _AA_LOBBY.ignoreWorlds = v end }, "IgnoreWorlds")
		right:Dropdown({ Name = "Ignore Modifiers", Search = true, Multi = true, Required = false, Options = { "Hard", "Insane", "Chilly", "Foggy", "Burning" }, Default = {}, Callback = function(v) _AA_LOBBY.ignoreModifiers = v end }, "IgnoreModifiers")
		right:Toggle({ Name = "Auto Challenge", Default = false, Callback = function(v) _AA_LOBBY.autoChallenge = v end }, "AutoChallenge")

		local portal = tab:Section({ Side = "Left" })
		portal:Header({ Text = "Auto Portal" })
		portal:Dropdown({ Name = "Select Portal", Search = true, Multi = false, Required = false, Options = _AA_DATA.PORTALS, Default = 1, Callback = function(v) _AA_LOBBY.selectedPortal = v end }, "Portal")
		portal:Dropdown({ Name = "Difficulty", Search = false, Multi = false, Required = false, Options = _AA_DATA.DIFFICULTIES, Default = 2, Callback = function(v) _AA_LOBBY.portalDifficulty = v end }, "PortalDifficulty")
		portal:Dropdown({ Name = "Tiers", Search = false, Multi = true, Required = false, Options = _AA_DATA.TIERS, Default = { "T1", "T2" }, Callback = function(v) _AA_LOBBY.portalTiers = v end }, "PortalTiers")
		portal:Toggle({ Name = "Ignore DMG Bonus", Default = false, Callback = function(v) _AA_LOBBY.ignoreDmgBonus = v end }, "IgnoreDmg")
		portal:Toggle({ Name = "Auto Use Portal", Default = false, Callback = function(v) _AA_LOBBY.autoPortal = v end }, "AutoPortal")

		local playerSec = tab:Section({ Side = "Right" })
		playerSec:Header({ Text = "Auto Join Player" })
		playerSec:Input({ Name = "Join Selected Player", Placeholder = "Username", AcceptedCharacters = "All", Callback = function(v) _AA_LOBBY.joinPlayerName = v end }, "JoinPlayerInput")
		playerSec:Toggle({ Name = "Enable Auto Join Player", Default = false, Callback = function(v) if v then _AA_joinPlayer(_AA_LOBBY.joinPlayerName) end end }, "AutoJoinPlayer")
	end)

	-- SHOP
	_AA_build("Shop", function()
		local tab = TabGroup:Tab({ Name = "Shop" })
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Portals" })
		left:Dropdown({ Name = "Delete Portal Min Tier", Search = false, Multi = false, Required = false, Options = _AA_DATA.TIERS, Default = 3, Callback = function(v) _AA_SHOP.deletePortalMinTier = v end }, "DeletePortalTier")
		left:Toggle({ Name = "Auto Delete Portal (below min)", Default = false, Callback = function(v) _AA_SHOP.autoDeletePortal = v end }, "AutoDeletePortal")
		left:Button({ Name = "Rescan Portals", Callback = function() _AA_Window:Notify({ Title = "LukihoHub", Description = #_AA_listPortals() .. " portals in inventory" }) end })
		local right = tab:Section({ Side = "Right" })
		right:Header({ Text = "Capsules" })
		right:Dropdown({ Name = "Capsule Type", Search = false, Multi = false, Required = false, Options = _AA_DATA.CAPSULE_TYPES, Default = 1, Callback = function(v) _AA_SHOP.capsuleType = v end }, "CapsuleType")
		right:Toggle({ Name = "Auto Open Capsules", Default = false, Callback = function(v) _AA_SHOP.autoOpenCapsules = v end }, "AutoOpenCapsules")
		right:Button({ Name = "Open 1 Capsule Now", Callback = function() _AA_openCapsuleOnce() end })
		right:Header({ Text = "Skins" })
		right:Dropdown({ Name = "Sell Skins Below", Search = false, Multi = false, Required = false, Options = _AA_DATA.SKIN_RARITIES, Default = 2, Callback = function(v) _AA_SHOP.skinMinRarity = v end }, "SkinMinRarity")
		right:Toggle({ Name = "Auto Sell Skins", Default = false, Callback = function(v) _AA_SHOP.autoSellSkins = v end }, "AutoSellSkins")
		right:Button({ Name = "Sell Now", Callback = function() _AA_sellSkinBelowMin() end })
	end)

	-- IN-GAME
	_AA_build("In-Game", function()
		local tab = TabGroup:Tab({ Name = "In-Game" })
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Wave Actions" })
		left:Toggle({ Name = "Auto Sell Units on Wave", Default = false, Callback = function(v) _AA_INGAME.autoSellOnWave = v; _AA_log("OK", "AutoSell=" .. tostring(v)) end }, "AutoSell")
		left:Toggle({ Name = "Auto Sell Farms on Wave", Default = false, Callback = function(v) _AA_INGAME.autoSellFarmsOnWave = v end }, "AutoSellFarms")
		left:Toggle({ Name = "Auto Leave on Wave", Default = false, Callback = function(v) _AA_INGAME.autoLeaveOnWave = v end }, "AutoLeave")
		left:Toggle({ Name = "Auto Upgrade on Wave", Default = false, Callback = function(v) _AA_INGAME.autoUpgradeOnWave = v end }, "AutoUpgrade")
		left:Toggle({ Name = "Focus Upgrade Farms", Default = false, Callback = function(v) _AA_INGAME.autoUpgradeFarmsOnly = v end }, "FocusFarms")
		left:Slider({ Name = "Auto Upgrade Cap", Default = 9, Minimum = 1, Maximum = 10, DisplayMethod = "Value", Precision = 0, Callback = function(v) _AA_INGAME.autoUpgradeCap = v end }, "UpgradeCap")
		left:Header({ Text = "Auto Place" })
		left:Toggle({ Name = "Auto Place Position", Default = false, Callback = function(v) _AA_INGAME.autoPlace = v end }, "AutoPlace")
		left:Input({ Name = "Auto Place Unit Id", Placeholder = "unit_id", AcceptedCharacters = "All", Callback = function(v) _AA_INGAME.autoPlaceUnitId = v end }, "PlaceUnitId")
		left:Slider({ Name = "Auto Place Cap", Default = 6, Minimum = 1, Maximum = 20, DisplayMethod = "Value", Precision = 0, Callback = function(v) _AA_INGAME.autoPlaceCap = v end }, "PlaceCap")
	end)

	-- EVENT CARD
	_AA_build("Event Card", function()
		local tab = TabGroup:Tab({ Name = "Event Card" })
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Auto Pick" })
		left:Toggle({ Name = "Auto Pick Card", Default = false, Callback = function(v) _AA_EC.autoPick = v; if v then _AA_pickedSoFar = 0; _AA_lastWaveSeen = 0 end end }, "AutoPickCard")
		left:Slider({ Name = "Pick Debuff Only Until Wave (0=off)", Default = 0, Minimum = 0, Maximum = 99, DisplayMethod = "Value", Precision = 0, Callback = function(v) _AA_EC.untilWave = v end }, "DebuffUntilWave")
		left:Toggle({ Name = "Pick High Debuff Only", Default = false, Callback = function(v) _AA_EC.onlyHighDebuffs = v end }, "HighDebuff")
		left:Toggle({ Name = "Ignore Buffs", Default = false, Callback = function(v) _AA_EC.ignoreBuffs = v end }, "IgnoreBuffs")
		left:Slider({ Name = "Limit Modifiers", Default = 0, Minimum = 0, Maximum = 20, DisplayMethod = "Value", Precision = 0, Callback = function(v) _AA_EC.limit = v end }, "LimitModifiers")
		local right = tab:Section({ Side = "Right" })
		right:Header({ Text = "Card Priority" })
		right:Dropdown({ Name = "Buff Priority", Search = true, Multi = true, Required = false, Options = _AA_DATA.BUFF_CARDS, Default = {}, Callback = function(v) for _, x in v do table.insert(_AA_EC.priorityList, x) end end }, "PriorityBuffs")
		right:Dropdown({ Name = "Debuff Priority", Search = true, Multi = true, Required = false, Options = _AA_DATA.DEBUFF_CARDS, Default = {}, Callback = function(v) for _, x in v do table.insert(_AA_EC.priorityList, x) end end }, "PriorityDebuffs")
	end)

	-- MACRO
	_AA_build("Macro", function()
		local tab = TabGroup:Tab({ Name = "Macro" })
		local selectedMacro = ""
		local macroDropdown = nil
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Storage" })
		macroDropdown = left:Dropdown({ Name = "Selected Macro", Search = true, Multi = false, Required = false, Options = _AA_macroList(), Default = 1, Callback = function(v) selectedMacro = v end }, "SelectedMacro")
		left:Input({ Name = "Macro Name", Placeholder = "macro-name", AcceptedCharacters = function(input) return input:gsub("[^%w%-%_]", "") end, Callback = function(v) _AA_INGAME.recordingName = v end }, "MacroName")
		left:Slider({ Name = "Step Delay (s)", Default = 0.25, Minimum = 0.05, Maximum = 2, DisplayMethod = "Value", Precision = 2, Callback = function(v) _AA_INGAME.recordStepDelay = v end }, "StepDelay")
		left:Toggle({ Name = "Auto Equip Macro Units", Default = false, Callback = function(v)
			if v and selectedMacro ~= "" then
				local entry = _AA_macroLoad(selectedMacro)
				if entry then
					for _, step in entry.steps do
						if step.unitId then _AA_invoke(_AA_REMOTE.equip_unit, step.unitId) end
					end
				end
			end
		end }, "AutoEquip")
		local right = tab:Section({ Side = "Right" })
		right:Header({ Text = "Record / Play" })
		right:Button({ Name = "Start Record", Callback = function()
			if _AA_INGAME.recordingName == "" then _AA_Window:Notify({ Title = "LukihoHub", Description = "Set a macro name first." }); return end
			_AA_macroStartRecord(_AA_INGAME.recordingName)
		end })
		right:Button({ Name = "Stop Record", Callback = function()
			local r = _AA_macroStopRecord()
			_AA_Window:Notify({ Title = "LukihoHub", Description = string.format("Saved %s (%d steps)", r.name, r.count) })
		end })
		right:Button({ Name = "Play Macro", Callback = function() _AA_macroPlay(selectedMacro) end })
		right:Button({ Name = "Refresh List", Callback = function() _AA_Window:Notify({ Title = "LukihoHub", Description = "Macros: " .. #_AA_macroList() }) end })

		local ie = tab:Section({ Side = "Left" })
		ie:Header({ Text = "Import / Export" })
		local importMode = "Link"
		ie:Dropdown({ Name = "Import Mode", Search = false, Multi = false, Required = false, Options = { "Link", "Text" }, Default = 1, Callback = function(v) importMode = v end }, "ImportMode")
		local importName = ""
		ie:Input({ Name = "Import File Name", Placeholder = "name", AcceptedCharacters = function(input) return input:gsub("[^%w%-%_]", "") end, Callback = function(v) importName = v end }, "ImportName")
		local importSource = ""
		ie:Input({ Name = "Import URL / Text", Placeholder = "https:// ... or JSON", AcceptedCharacters = "All", Callback = function(v) importSource = v end }, "ImportSource")
		ie:Button({ Name = "Import", Callback = function()
			if _AA_macroImport(importName, importSource, importMode) then
				_AA_Window:Notify({ Title = "LukihoHub", Description = "Macro imported." })
			else
				_AA_Window:Notify({ Title = "LukihoHub", Description = "Import failed." })
			end
		end })
		ie:Button({ Name = "Export Selected", Callback = function()
			local out = _AA_macroExport(selectedMacro)
			if out then
				_AA_Window:Notify({ Title = "LukihoHub", Description = "Exported (see F9 console)" })
				print("[LukihoHub] macro export:", out)
			end
		end })
	end)

	-- MISC
	_AA_build("Misc", function()
		local tab = TabGroup:Tab({ Name = "Misc" })
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Webhook" })
		left:Input({ Name = "Webhook URL", Placeholder = "https://discord.com/api/webhooks/...", AcceptedCharacters = "All", Callback = function(v) _AA_MISC.webhookURL = v end }, "WebhookURL")
		left:Input({ Name = "Ping User ID", Placeholder = "000000000000", AcceptedCharacters = "Numeric", Callback = function(v) _AA_MISC.pingUserID = v end }, "PingUser")
		left:Dropdown({ Name = "Ping on Selected", Search = true, Multi = true, Required = false, Options = { "Takedown", "Drop", "Match Found" }, Default = {}, Callback = function(v) _AA_MISC.pingOnSelected = v end }, "PingOn")
		left:Toggle({ Name = "Ping on Secret Drop", Default = false, Callback = function(v) _AA_MISC.pingOnSecretDrop = v end }, "PingSecretDrop")
		left:Button({ Name = "Send Test Webhook", Callback = function() _AA_notifyWebhook("Test", "LukihoHub is online", 0x00BFFF, true) end })

		local right = tab:Section({ Side = "Right" })
		right:Header({ Text = "Visibility / Misc" })
		right:Toggle({ Name = "Auto Hide UI on Execute", Default = false, Callback = function(v) _AA_setUIHidden(v) end }, "HideUI")
		right:Toggle({ Name = "Hide Map", Default = false, Callback = function(v) _AA_setMapHidden(v) end }, "HideMap")
		right:Toggle({ Name = "Hide Name", Default = false, Callback = function(v) _AA_setNamesHidden(v) end }, "HideName")
		right:Toggle({ Name = "Fake Outfit", Default = false, Callback = function(v) _AA_setFakeOutfit(v) end }, "FakeOutfit")
		right:Toggle({ Name = "Auto Try Reconnect", Default = false, Callback = function(v) _AA_MISC.autoReconnect = v end }, "AutoReconnect")
		right:Slider({ Name = "Set FPS (0=off)", Default = 0, Minimum = 0, Maximum = 240, DisplayMethod = "Value", Precision = 0, Callback = function(v) _AA_setFps(v) end }, "SetFPS")
		right:Toggle({ Name = "Colored Takedowns", Default = false, Callback = function(v) _AA_MISC.coloredTakedowns = v end }, "ColoredTakedowns")
		right:Toggle({ Name = "Show Takedowns", Default = true, Callback = function(v) _AA_MISC.showTakedowns = v end }, "ShowTakedowns")
		right:Toggle({ Name = "Auto Claim Quests", Default = false, Callback = function(v) _AA_MISC.autoClaimQuests = v end }, "AutoClaimQuests")
		right:Toggle({ Name = "Auto Take Daily Quests", Default = false, Callback = function(v) _AA_MISC.autoTakeDailyQuests = v end }, "AutoTakeDailyQuests")
		right:Button({ Name = "Redeem ALL Codes", Callback = function() _AA_redeemAllCodes() end })
	end)

	-- SETTINGS
	_AA_build("Settings", function()
		local tab = TabGroup:Tab({ Name = "Settings" })
		local left = tab:Section({ Side = "Left" })
		left:Header({ Text = "Remote Status" })
		left:Paragraph({ Header = "spawn_unit",         Body = tostring(_AA_get_remote("spawn_unit") ~= nil) })
		left:Paragraph({ Header = "upgrade_unit_ingame", Body = tostring(_AA_get_remote("upgrade_unit_ingame") ~= nil) })
		left:Paragraph({ Header = "sell_unit_ingame",    Body = tostring(_AA_get_remote("sell_unit_ingame") ~= nil) })
		left:Paragraph({ Header = "change_priority",     Body = tostring(_AA_get_remote("change_priority") ~= nil) })
		left:Paragraph({ Header = "use_ingame_spell",    Body = tostring(_AA_get_remote("use_ingame_spell") ~= nil) })
		left:Paragraph({ Header = "request_join_lobby",  Body = tostring(_AA_get_remote("request_join_lobby") ~= nil) })
		left:Paragraph({ Header = "use_portal",          Body = tostring(_AA_get_remote("use_portal") ~= nil) })
		left:Paragraph({ Header = "select_roguelike_option", Body = tostring(_AA_get_remote("select_roguelike_option") ~= nil) })
		left:Paragraph({ Header = "redeem_code",         Body = tostring(_AA_get_remote("redeem_code") ~= nil) })
		local right = tab:Section({ Side = "Right" })
		right:Header({ Text = "Interface" })
		right:Button({ Name = "Unload Hub", Callback = function() _AA_unload() end })
		right:Paragraph({ Header = "Lukiho", Body = "RightControl toggles" })
	end)

	pcall(function() _AA_Window:Notify({ Title = "LukihoHub", Description = "Loaded. RightControl to toggle." }) end)
end

----------------------------------------------------------------
-- 13. UNLOAD
----------------------------------------------------------------
function _AA_unload()
	for _, c in _AA_connections do pcall(function() c:Disconnect() end) end
	if _AA_Window then pcall(function() _AA_Window:Unload() end) end
	if _AA_debugGui and _AA_debugGui.gui then pcall(function() _AA_debugGui.gui:Destroy() end) end
	_G.LukihoHubUnload = nil
end
_G.LukihoHubUnload = _AA_unload
_G._AA_HUB_VERSION = _AA_HUB_VERSION

_AA_log("OK", string.format("hub ready (place=%d, ui=%s)", game.PlaceId, _AA_Window and "loaded" or "missing"))
