--!strict
-- games/aa/LukihoHub.client.lua
-- Anime Adventures external hub. MacLib UI + 8 tabs:
--   Home, Lobby, Shop, In-Game, Event Card, Macro, Misc, Settings.

----------------------------------------------------------------
-- GAME GUARD
----------------------------------------------------------------
local TARGET_GAME_ID = 4584892739
if game.GameId ~= TARGET_GAME_ID then
	return
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local HttpService   = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local global = (_G :: any)
if type(global.LukihoHubUnload) == "function" then
	global.LukihoHubUnload()
end

----------------------------------------------------------------
-- MODULES
----------------------------------------------------------------
local init    = require(script.Parent:WaitForChild("init"))
local data    = require(script.Parent:WaitForChild("data"))
local lobby   = require(script.Parent:WaitForChild("lobby"))
local shop    = require(script.Parent:WaitForChild("shop"))
local misc    = require(script.Parent:WaitForChild("misc"))
local ingame  = require(script.Parent:WaitForChild("ingame"))
local eventcard = require(script.Parent:WaitForChild("eventcard"))
local macro   = require(script.Parent:WaitForChild("macro_storage"))

init.windowRef = nil -- will be set after MacLib loads

----------------------------------------------------------------
-- UI LIBRARY
----------------------------------------------------------------
local MacLib = loadstring(game:HttpGet(
	"https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"
))()

local Window = MacLib:Window({
	Title = "LukihoHub",
	Subtitle = "Anime Adventures | v1.0",
	Size = UDim2.fromOffset(820, 580),
	DragStyle = 1,
	DisabledWindowControls = {},
	ShowUserInfo = true,
	Keybind = Enum.KeyCode.RightControl,
	AcrylicBlur = false,
})

init.windowRef = Window

local TabGroup = Window:TabGroup()

----------------------------------------------------------------
-- TICK (single Heartbeat driving every module)
----------------------------------------------------------------
local connections: { RBXScriptConnection } = {}
local function on(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
end

on(RunService.Heartbeat, function(dt)
	lobby.tick(dt)
	shop.tick()
	misc.tick()
	ingame.tick()
	eventcard.tick()
end)

----------------------------------------------------------------
-- TAB: HOME
----------------------------------------------------------------
local home = TabGroup:Tab({ Name = "Home" })
local homeLeft = home:Section({ Side = "Left" })
homeLeft:Header({ Text = "Welcome" })
homeLeft:Paragraph({
	Title = "LukihoHub",
	Desc = "Anime Adventures automation console. Created by Lukiho.",
})
homeLeft:Paragraph({
	Title = "Keybind",
	Desc = "RightControl toggles the menu.",
})
homeLeft:Paragraph({
	Title = "Game Guard",
	Desc = "Anime Adventures (4584892739).",
})
homeLeft:Button({ Name = "Unload Hub", Callback = function() unload() end })
local homeRight = home:Section({ Side = "Right" })
homeRight:Header({ Text = "Live" })
local stateLabel = homeRight:Paragraph({ Title = "State", Desc = "Unknown" })
local waveLabel  = homeRight:Paragraph({ Title = "Wave",  Desc = "0" })
RunService.Heartbeat:Connect(function()
	local info = init.getStageInfo()
	stateLabel.Desc = tostring(info.state or "?")
	waveLabel.Desc  = tostring(info.currentWave or 0)
end)

----------------------------------------------------------------
-- TAB: LOBBY
----------------------------------------------------------------
local lobbyTab = TabGroup:Tab({ Name = "Lobby" })
local lobbyLeft = lobbyTab:Section({ Side = "Left" })
lobbyLeft:Header({ Text = "Auto Join Map" })
lobbyLeft:Dropdown({
	Name = "Join Mode",
	Search = false, Multi = false, Required = false,
	Options = data.JOIN_MODES,
	Default = 1,
	Callback = function(v) lobby.state.joinMode = v end,
}, "JoinMode")
lobbyLeft:Dropdown({
	Name = "Map",
	Search = true, Multi = false, Required = false,
	Options = data.MAPS,
	Default = 1,
	Callback = function(v) lobby.state.selectedMap = v end,
}, "Map")
lobbyLeft:Dropdown({
	Name = "Act",
	Search = false, Multi = false, Required = false,
	Options = data.ACTS,
	Default = 1,
	Callback = function(v) lobby.state.selectedAct = v end,
}, "Act")
lobbyLeft:Dropdown({
	Name = "Difficulty",
	Search = false, Multi = false, Required = false,
	Options = data.DIFFICULTIES,
	Default = 2,
	Callback = function(v) lobby.state.difficulty = v end,
}, "Difficulty")
lobbyLeft:Toggle({
	Name = "Friends Only",
	Default = false,
	Callback = function(v) lobby.state.friendsOnly = v end,
}, "FriendsOnly")
lobbyLeft:Toggle({
	Name = "Auto Join",
	Default = false,
	Callback = function(v) lobby.state.autoJoin = v end,
}, "AutoJoin")
lobbyLeft:Slider({
	Name = "Auto Start Delay (s)",
	Default = 5, Minimum = 0, Maximum = 30,
	DisplayMethod = "Value", Precision = 0,
	Callback = function(v) lobby.state.autoStartDelay = v end,
}, "AutoStartDelay")
lobbyLeft:Toggle({
	Name = "Auto Start",
	Default = false,
	Callback = function(v) lobby.state.autoStart = v end,
}, "AutoStart")

local lobbyRight = lobbyTab:Section({ Side = "Right" })
lobbyRight:Header({ Text = "Auto Challenge" })
lobbyRight:Dropdown({
	Name = "Ignore Worlds",
	Search = true, Multi = true, Required = false,
	Options = data.MAPS,
	Default = {},
	Callback = function(v) lobby.state.ignoreWorlds = v end,
}, "IgnoreWorlds")
lobbyRight:Dropdown({
	Name = "Ignore Modifiers",
	Search = true, Multi = true, Required = false,
	Options = { "Hard", "Insane", "Chilly", "Foggy", "Burning" },
	Default = {},
	Callback = function(v) lobby.state.ignoreModifiers = v end,
}, "IgnoreModifiers")
lobbyRight:Toggle({
	Name = "Auto Challenge",
	Default = false,
	Callback = function(v) lobby.state.autoChallenge = v end,
}, "AutoChallenge")

local portalSec = lobbyTab:Section({ Side = "Left" })
portalSec:Header({ Text = "Auto Portal" })
portalSec:Dropdown({
	Name = "Select Portal",
	Search = true, Multi = false, Required = false,
	Options = data.PORTALS,
	Default = 1,
	Callback = function(v) lobby.state.selectedPortal = v end,
}, "Portal")
portalSec:Dropdown({
	Name = "Difficulty",
	Search = false, Multi = false, Required = false,
	Options = data.DIFFICULTIES,
	Default = 2,
	Callback = function(v) lobby.state.portalDifficulty = v end,
}, "PortalDifficulty")
portalSec:Dropdown({
	Name = "Tiers",
	Search = false, Multi = true, Required = false,
	Options = data.TIERS,
	Default = { "T1", "T2" },
	Callback = function(v) lobby.state.portalTiers = v end,
}, "PortalTiers")
portalSec:Toggle({
	Name = "Ignore DMG Bonus",
	Default = false,
	Callback = function(v) lobby.state.ignoreDmgBonus = v end,
}, "IgnoreDmg")
portalSec:Dropdown({
	Name = "Ignore Worlds",
	Search = true, Multi = true, Required = false,
	Options = data.MAPS,
	Default = {},
	Callback = function(v) lobby.state.ignoreWorlds = v end,
}, "PortalIgnoreWorlds")
portalSec:Toggle({
	Name = "Auto Use Portal",
	Default = false,
	Callback = function(v) lobby.state.autoPortal = v end,
}, "AutoPortal")

local joinPlayerSec = lobbyTab:Section({ Side = "Right" })
joinPlayerSec:Header({ Text = "Auto Join Player" })
joinPlayerSec:Input({
	Name = "Join Selected Player",
	Placeholder = "Username",
	AcceptedCharacters = "All",
	Callback = function(v) lobby.state.joinPlayerName = v end,
}, "JoinPlayerInput")
joinPlayerSec:Toggle({
	Name = "Enable Auto Join Player",
	Default = false,
	Callback = function(v)
		lobby.state.autoJoinPlayer = v
		if v then lobby.joinPlayer(lobby.state.joinPlayerName) end
	end,
}, "AutoJoinPlayer")

----------------------------------------------------------------
-- TAB: SHOP
----------------------------------------------------------------
local shopTab = TabGroup:Tab({ Name = "Shop" })
local shopLeft = shopTab:Section({ Side = "Left" })
shopLeft:Header({ Text = "Portals" })
shopLeft:Dropdown({
	Name = "Delete Portal Min Tier",
	Search = false, Multi = false, Required = false,
	Options = data.TIERS,
	Default = 3,
	Callback = function(v) shop.state.deletePortalMinTier = v end,
}, "DeletePortalTier")
shopLeft:Toggle({
	Name = "Auto Delete Portal (below min)",
	Default = false,
	Callback = function(v) shop.state.autoDeletePortal = v end,
}, "AutoDeletePortal")
shopLeft:Button({
	Name = "Rescan Portals",
	Callback = function()
		local list = shop.listPortals()
		Window:Notify({
			Title = "LukihoHub",
			Description = string.format("%d portals in inventory", #list),
		})
	end,
})
local shopRight = shopTab:Section({ Side = "Right" })
shopRight:Header({ Text = "Capsules" })
shopRight:Dropdown({
	Name = "Capsule Type",
	Search = false, Multi = false, Required = false,
	Options = data.CAPSULE_TYPES,
	Default = 1,
	Callback = function(v) shop.state.capsuleType = v end,
}, "CapsuleType")
shopRight:Toggle({
	Name = "Auto Open Capsules",
	Default = false,
	Callback = function(v) shop.state.autoOpenCapsules = v end,
}, "AutoOpenCapsules")
shopRight:Button({
	Name = "Open 1 Capsule Now",
	Callback = function() shop.openCapsuleOnce() end,
})
shopRight:Header({ Text = "Skins" })
shopRight:Dropdown({
	Name = "Sell Skins Below",
	Search = false, Multi = false, Required = false,
	Options = data.SKIN_RARITIES,
	Default = 2,
	Callback = function(v) shop.state.skinMinRarity = v end,
}, "SkinMinRarity")
shopRight:Toggle({
	Name = "Auto Sell Skins",
	Default = false,
	Callback = function(v) shop.state.autoSellSkins = v end,
}, "AutoSellSkins")
shopRight:Button({
	Name = "Sell Now",
	Callback = function() shop.sellSkinBelowMin() end,
})

----------------------------------------------------------------
-- TAB: IN-GAME
----------------------------------------------------------------
local ingameTab = TabGroup:Tab({ Name = "In-Game" })
local igLeft = ingameTab:Section({ Side = "Left" })
igLeft:Header({ Text = "Wave Actions" })
igLeft:Toggle({
	Name = "Auto Sell Units on Wave",
	Default = false,
	Callback = function(v) ingame.state.autoSellOnWave = v end,
}, "AutoSell")
igLeft:Toggle({
	Name = "Auto Sell Farms on Wave",
	Default = false,
	Callback = function(v) ingame.state.autoSellFarmsOnWave = v end,
}, "AutoSellFarms")
igLeft:Toggle({
	Name = "Auto Leave on Wave",
	Default = false,
	Callback = function(v) ingame.state.autoLeaveOnWave = v end,
}, "AutoLeave")
igLeft:Toggle({
	Name = "Auto Upgrade on Wave",
	Default = false,
	Callback = function(v) ingame.state.autoUpgradeOnWave = v end,
}, "AutoUpgrade")
igLeft:Toggle({
	Name = "Focus Upgrade Farms",
	Default = false,
	Callback = function(v) ingame.state.autoUpgradeFarmsOnly = v end,
}, "FocusFarms")
igLeft:Slider({
	Name = "Auto Upgrade Cap",
	Default = 9, Minimum = 1, Maximum = 10,
	DisplayMethod = "Value", Precision = 0,
	Callback = function(v) ingame.state.autoUpgradeCap = v end,
}, "UpgradeCap")
igLeft:Toggle({
	Name = "Auto Place Position",
	Default = false,
	Callback = function(v) ingame.state.autoPlace = v end,
}, "AutoPlace")
igLeft:Input({
	Name = "Auto Place Unit Id",
	Placeholder = "unit_id",
	AcceptedCharacters = "All",
	Callback = function(v) ingame.state.autoPlaceUnitId = v end,
}, "PlaceUnitId")
igLeft:Slider({
	Name = "Auto Place Cap",
	Default = 6, Minimum = 1, Maximum = 20,
	DisplayMethod = "Value", Precision = 0,
	Callback = function(v) ingame.state.autoPlaceCap = v end,
}, "PlaceCap")

----------------------------------------------------------------
-- TAB: EVENT CARD
----------------------------------------------------------------
local ecTab = TabGroup:Tab({ Name = "Event Card" })
local ecLeft = ecTab:Section({ Side = "Left" })
ecLeft:Header({ Text = "Auto Pick" })
ecLeft:Toggle({
	Name = "Auto Pick Card",
	Default = false,
	Callback = function(v)
		eventcard.state.autoPick = v
		if v then eventcard.resetCounters() end
	end,
}, "AutoPickCard")
ecLeft:Slider({
	Name = "Pick Debuff Only Until Wave (0 = off)",
	Default = 0, Minimum = 0, Maximum = 99,
	DisplayMethod = "Value", Precision = 0,
	Callback = function(v) eventcard.state.untilWave = v end,
}, "DebuffUntilWave")
ecLeft:Toggle({
	Name = "Pick High Debuff Only",
	Default = false,
	Callback = function(v) eventcard.state.onlyHighDebuffs = v end,
}, "HighDebuff")
ecLeft:Toggle({
	Name = "Ignore Buffs",
	Default = false,
	Callback = function(v) eventcard.state.ignoreBuffs = v end,
}, "IgnoreBuffs")
ecLeft:Slider({
	Name = "Limit Modifiers",
	Default = 0, Minimum = 0, Maximum = 20,
	DisplayMethod = "Value", Precision = 0,
	Callback = function(v) eventcard.state.limit = v end,
}, "LimitModifiers")
local ecRight = ecTab:Section({ Side = "Right" })
ecRight:Header({ Text = "Card Priority" })
ecRight:Dropdown({
	Name = "Priority List",
	Search = true, Multi = true, Required = false,
	Options = data.BUFF_CARDS,
	Default = {},
	Callback = function(v) eventcard.state.priorityList = v end,
}, "PriorityBuffs")
ecRight:Dropdown({
	Name = "Debuff Priority",
	Search = true, Multi = true, Required = false,
	Options = data.DEBUFF_CARDS,
	Default = {},
	Callback = function(v) for _, x in v do table.insert(eventcard.state.priorityList, x) end end,
}, "PriorityDebuffs")

----------------------------------------------------------------
-- TAB: MACRO
----------------------------------------------------------------
local macroTab = TabGroup:Tab({ Name = "Macro" })
local mLeft = macroTab:Section({ Side = "Left" })
mLeft:Header({ Text = "Storage" })
local selectedMacro = ""
local macroDropdown = mLeft:Dropdown({
	Name = "Selected Macro",
	Search = true, Multi = false, Required = false,
	Options = macro.list(),
	Default = 1,
	Callback = function(v) selectedMacro = v end,
}, "SelectedMacro")
mLeft:Button({
	Name = "Refresh List",
	Callback = function()
		macroDropdown:UpdateSelection("")
		Window:Notify({ Title = "LukihoHub", Description = "Macros refreshed." })
	end,
})
mLeft:Input({
	Name = "Macro Name",
	Placeholder = "macro-name",
	AcceptedCharacters = function(input)
		return input:gsub("[^%w%-%_]", "")
	end,
	Callback = function(v) ingame.state.recordingName = v end,
}, "MacroName")
mLeft:Slider({
	Name = "Step Delay (s)",
	Default = 0.25, Minimum = 0.05, Maximum = 2,
	DisplayMethod = "Value", Precision = 2,
	Callback = function(v) ingame.state.recordStepDelay = v end,
}, "StepDelay")
mLeft:Toggle({
	Name = "Auto Equip Macro Units",
	Default = false,
	Callback = function(v)
		if v and selectedMacro ~= "" then
			local entry = macro.load(selectedMacro)
			if entry then
				for _, step in entry.steps do
					if step.unitId then
						init.invoke(init.REMOTE.equip_unit, step.unitId)
					end
				end
			end
		end
	end,
}, "AutoEquip")
local mRight = macroTab:Section({ Side = "Right" })
mRight:Header({ Text = "Record" })
mRight:Button({
	Name = "Start Record",
	Callback = function()
		if ingame.state.recordingName == "" then
			Window:Notify({ Title = "LukihoHub", Description = "Set a macro name first." })
			return
		end
		ingame.startRecording(ingame.state.recordingName)
	end,
})
mRight:Button({
	Name = "Stop Record",
	Callback = function()
		local result = ingame.stopRecording()
		Window:Notify({
			Title = "LukihoHub",
			Description = string.format("Saved %s (%d steps)", result.name, result.count),
		})
	end,
})
mRight:Button({
	Name = "Play Macro",
	Callback = function() ingame.playMacro(selectedMacro) end,
})

local importExport = macroTab:Section({ Side = "Left" })
importExport:Header({ Text = "Import / Export" })
importExport:Dropdown({
	Name = "Import Mode",
	Search = false, Multi = false, Required = false,
	Options = { "Link", "Text" },
	Default = 1,
	Callback = function(v) importExportMode = v end,
}, "ImportMode")
local importExportMode = "Link"
importExport:Input({
	Name = "Import File Name",
	Placeholder = "name",
	AcceptedCharacters = function(input) return input:gsub("[^%w%-%_]", "") end,
	Callback = function(v) importExportName = v end,
}, "ImportName")
local importExportName = ""
importExport:Input({
	Name = "Import URL / Text",
	Placeholder = "https:// ... or JSON",
	AcceptedCharacters = "All",
	Callback = function(v) importExportSource = v end,
}, "ImportSource")
local importExportSource = ""
importExport:Button({
	Name = "Import",
	Callback = function()
		if macro.import(importExportName, importExportSource, importExportMode) then
			Window:Notify({ Title = "LukihoHub", Description = "Macro imported." })
		else
			Window:Notify({ Title = "LukihoHub", Description = "Import failed." })
		end
	end,
})
importExport:Button({
	Name = "Export Selected",
	Callback = function()
		local out = macro.export(selectedMacro)
		if out then
			Window:Notify({ Title = "LukihoHub", Description = "Exported to F12 console." })
			print("[LukihoHub] macro export:", out)
		end
	end,
})

local macroMaps = macroTab:Section({ Side = "Right" })
macroMaps:Header({ Text = "Macro Maps" })
macroMaps:Dropdown({
	Name = "Macro Maps",
	Search = true, Multi = false, Required = false,
	Options = data.MAPS,
	Default = 1,
	Callback = function(v) macro.state.selectedMap = v end,
}, "MacroMaps")

----------------------------------------------------------------
-- TAB: MISC
----------------------------------------------------------------
local miscTab = TabGroup:Tab({ Name = "Misc" })
local miscLeft = miscTab:Section({ Side = "Left" })
miscLeft:Header({ Text = "Webhook" })
miscLeft:Input({
	Name = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
	AcceptedCharacters = "All",
	Callback = function(v) misc.state.webhookURL = v end,
}, "WebhookURL")
miscLeft:Input({
	Name = "Ping User ID",
	Placeholder = "000000000000",
	AcceptedCharacters = "Numeric",
	Callback = function(v) misc.state.pingUserID = v end,
}, "PingUser")
miscLeft:Dropdown({
	Name = "Ping on Selected Item",
	Search = true, Multi = true, Required = false,
	Options = { "Takedown", "Drop", "Match Found" },
	Default = {},
	Callback = function(v) misc.state.pingOnSelected = v end,
}, "PingOn")
miscLeft:Dropdown({
	Name = "Result Webhook Events",
	Search = true, Multi = true, Required = false,
	Options = { "Takedown", "Drop", "Secret Drop" },
	Default = { "Secret Drop" },
	Callback = function(v) misc.state.pingOnSelected = v end,
}, "WebhookEvents")
miscLeft:Toggle({
	Name = "Ping on Secret Drop",
	Default = false,
	Callback = function(v) misc.state.pingOnSecretDrop = v end,
}, "PingSecretDrop")

local miscMid = miscTab:Section({ Side = "Right" })
miscMid:Header({ Text = "Visibility" })
miscMid:Toggle({
	Name = "Auto Hide UI on Execute",
	Default = false,
	Callback = function(v) misc.setUIHidden(v) end,
}, "HideUI")
miscMid:Toggle({
	Name = "Hide Map",
	Default = false,
	Callback = function(v) misc.setMapHidden(v) end,
}, "HideMap")
miscMid:Toggle({
	Name = "Hide Name",
	Default = false,
	Callback = function(v) misc.setNamesHidden(v) end,
}, "HideName")
miscMid:Toggle({
	Name = "Fake Outfit",
	Default = false,
	Callback = function(v) misc.setFakeOutfit(v) end,
}, "FakeOutfit")
miscMid:Toggle({
	Name = "Auto Try Reconnect",
	Default = false,
	Callback = function(v) misc.state.autoReconnect = v end,
}, "AutoReconnect")
miscMid:Toggle({
	Name = "Auto Execute",
	Default = false,
	Callback = function(v)
		misc.state.autoReconnect = v
		misc.bindAutoExecute("https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/loader.lua")
	end,
}, "AutoExecute")
miscMid:Slider({
	Name = "Set FPS (0 = off)",
	Default = 0, Minimum = 0, Maximum = 240,
	DisplayMethod = "Value", Precision = 0,
	Callback = function(v) misc.setFps(v) end,
}, "SetFPS")
miscMid:Toggle({
	Name = "Colored Takedowns",
	Default = false,
	Callback = function(v) misc.state.coloredTakedowns = v end,
}, "ColoredTakedowns")
miscMid:Toggle({
	Name = "Show Takedowns",
	Default = true,
	Callback = function(v) misc.state.showTakedowns = v end,
}, "ShowTakedowns")
miscMid:Toggle({
	Name = "Auto Claim Quests",
	Default = false,
	Callback = function(v) misc.state.autoClaimQuests = v end,
}, "AutoClaimQuests")
miscMid:Toggle({
	Name = "Auto Take Daily Quests",
	Default = false,
	Callback = function(v) misc.state.autoTakeDailyQuests = v end,
}, "AutoTakeDailyQuests")
miscMid:Button({
	Name = "Redeem ALL Codes",
	Callback = function() misc.redeemAllCodes() end,
})

----------------------------------------------------------------
-- TAB: SETTINGS
----------------------------------------------------------------
local settingsTab = TabGroup:Tab({ Name = "Settings" })
local sLeft = settingsTab:Section({ Side = "Left" })
sLeft:Header({ Text = "Remote Status" })
sLeft:Paragraph({ Title = "spawn_unit",         Desc = tostring(init.getRemote("spawn_unit") ~= nil) })
sLeft:Paragraph({ Title = "upgrade_unit_ingame", Desc = tostring(init.getRemote("upgrade_unit_ingame") ~= nil) })
sLeft:Paragraph({ Title = "sell_unit_ingame",    Desc = tostring(init.getRemote("sell_unit_ingame") ~= nil) })
sLeft:Paragraph({ Title = "change_priority",     Desc = tostring(init.getRemote("change_priority") ~= nil) })
sLeft:Paragraph({ Title = "use_ingame_spell",    Desc = tostring(init.getRemote("use_ingame_spell") ~= nil) })
sLeft:Paragraph({ Title = "request_join_lobby",  Desc = tostring(init.getRemote("request_join_lobby") ~= nil) })
sLeft:Paragraph({ Title = "use_portal",          Desc = tostring(init.getRemote("use_portal") ~= nil) })
sLeft:Paragraph({ Title = "select_roguelike_option", Desc = tostring(init.getRemote("select_roguelike_option") ~= nil) })
sLeft:Paragraph({ Title = "redeem_code",         Desc = tostring(init.getRemote("redeem_code") ~= nil) })

local sRight = settingsTab:Section({ Side = "Right" })
sRight:Header({ Text = "Interface" })
sRight:Button({ Name = "Unload Hub", Callback = function() unload() end })
sRight:Paragraph({
	Title = "Created by Lukiho",
	Desc = "RightControl toggles.",
})

----------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------
function unload()
	for _, c in connections do c:Disconnect() end
	pcall(function() Window:Unload() end)
	if global.LukihoHubUnload == unload then global.LukihoHubUnload = nil end
end
global.LukihoHubUnload = unload

Window:Notify({
	Title = "LukihoHub",
	Description = "Loaded. RightControl to toggle.",
})
