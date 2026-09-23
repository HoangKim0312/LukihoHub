--!strict
-- games/aa/ingame.lua
-- In-game automation:
--   Auto Sell Units on Wave
--   Auto Sell Farms on Wave
--   Auto Leave on Wave
--   Auto Upgrade on Wave
--   Focus Upgrade Farms
--   Auto Place Position
--   Auto Upgrade Cap
--   Auto Place Cap
--   Macro system (record/play, equip macro units, step delay, time/wave options)

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace      = game:GetService("Workspace")

local M = {}
local init  = require(script.Parent:WaitForChild("init"))
local macro = require(script.Parent:WaitForChild("macro_storage"))
local data  = require(script.Parent:WaitForChild("data"))

local player = Players.LocalPlayer

M.state = {
	autoSellOnWave    = false,
	autoSellFarmsOnWave = false,
	autoLeaveOnWave   = false,
	autoUpgradeOnWave = false,
	autoUpgradeFarmsOnly = false,
	autoUpgradeCap    = 9,

	autoPlace         = false,
	autoPlacePos      = nil, -- CFrame
	autoPlaceUnitId   = nil,
	autoPlaceCap      = 6,

	macro             = macro,
	recording         = false,
	recordingName     = "",
	lastWave          = 0,
	lastRecordStep    = 0,
	recordStepDelay   = 0.25,
}

----------------------------------------------------------------
-- WAVE DETECTION
-- The Stage StringValue/IntValue inside workspace.Stage carries the
-- wave number; this function reads it safely.
----------------------------------------------------------------
function M.getWave(): number
	local info = init.getStageInfo()
	return info.currentWave or 0
end

function M.inGame(): boolean
	local info = init.getStageInfo()
	return info.state ~= nil and info.state ~= "Lobby" and info.state ~= "LobbyIdle"
end

----------------------------------------------------------------
-- UNITS ON FIELD
-- AA spawns a `Unit` model under `workspace.placed_units.<userId>.*`
-- with attributes `unit_id`, `owner`, `current_health`, `position`.
----------------------------------------------------------------
function M.listFieldUnits(): { Model }
	local out = {}
	local folder = Workspace:FindFirstChild("placed_units")
	if not folder then return out end
	local userFolder = folder:FindFirstChild(tostring(player.UserId))
	if not userFolder then return out end
	for _, unit in userFolder:GetChildren() do
		if unit:IsA("Model") then table.insert(out, unit) end
	end
	return out
end

function M.isFarm(unit: Model): boolean
	local id = unit:GetAttribute("unit_id") or unit.Name
	return string.find(string.lower(id or ""), "farm", 1, true) ~= nil
end

function M.unitName(unit: Model): string
	return unit:GetAttribute("unit_id") or unit.Name
end

----------------------------------------------------------------
-- SELL / UPGRADE
----------------------------------------------------------------
function M.sellUnit(unit: Model)
	init.invoke(init.REMOTE.sell_unit_ingame, M.unitName(unit))
end

function M.upgradeUnit(unit: Model)
	init.invoke(init.REMOTE.upgrade_unit_ingame, M.unitName(unit))
end

function M.upgradeLevel(unit: Model): number
	return (unit:GetAttribute("level") or 0) :: number
end

----------------------------------------------------------------
-- PLACE
----------------------------------------------------------------
function M.placeUnit(unitId: string, cframe: CFrame)
	if not unitId or not cframe then return end
	init.invoke(init.REMOTE.spawn_unit, unitId, cframe)
end

----------------------------------------------------------------
-- AUTO BEHAVIOURS
----------------------------------------------------------------
local function countPlaced(): number
	return #M.listFieldUnits()
end

function M.tickWaveActions()
	if not M.inGame() then return end
	local wave = M.getWave()
	if wave == M.state.lastWave then return end
	M.state.lastWave = wave

	if M.state.autoSellOnWave then
		for _, unit in M.listFieldUnits() do
			if M.state.autoSellFarmsOnWave or not M.isFarm(unit) then
				M.sellUnit(unit)
			end
		end
	end

	if M.state.autoLeaveOnWave then
		init.invoke(init.REMOTE.teleport_back_to_lobby)
	end

	if M.state.autoUpgradeOnWave then
		for _, unit in M.listFieldUnits() do
			if M.state.autoUpgradeFarmsOnly and not M.isFarm(unit) then continue end
			local lvl = M.upgradeLevel(unit)
			if lvl < M.state.autoUpgradeCap then
				M.upgradeUnit(unit)
			end
		end
	end
end

function M.tickPlace()
	if not M.state.autoPlace or not M.inGame() then return end
	if not M.state.autoPlaceUnitId or not M.state.autoPlacePos then return end
	if countPlaced() >= M.state.autoPlaceCap then return end
	M.placeUnit(M.state.autoPlaceUnitId, M.state.autoPlacePos)
end

----------------------------------------------------------------
-- MACRO (record / play)
----------------------------------------------------------------
-- Recorded step types:
--   { t = "place",  unitId, cframe }
--   { t = "upgrade", unitId }
--   { t = "sell",    unitId }
--   { t = "priority", unitId, priority }
--   { t = "spell",   unitId }
----------------------------------------------------------------
function M.startRecording(name: string)
	if M.state.recording then return false, "already recording" end
	M.state.recording = true
	M.state.recordingName = name
	M.state.lastRecordStep = os.clock()
	macro.clearSteps()
	return true
end

function M.stopRecording(): { [string]: any }
	M.state.recording = false
	local steps = macro.getSteps()
	macro.save(M.state.recordingName, steps)
	return { name = M.state.recordingName, count = #steps }
end

function M.recordStep(step: { [string]: any })
	if not M.state.recording then return end
	if os.clock() - M.state.lastRecordStep < M.state.recordStepDelay then return end
	M.state.lastRecordStep = os.clock()
	step.t = step.t or "place"
	step.time = os.clock()
	macro.appendStep(step)
end

function M.playMacro(name: string)
	local entry = macro.load(name)
	if not entry then return false, "macro not found" end
	task.spawn(function()
		for _, step in entry.steps do
			if step.t == "place" then
				init.invoke(init.REMOTE.spawn_unit, step.unitId, step.cframe)
			elseif step.t == "upgrade" then
				init.invoke(init.REMOTE.upgrade_unit_ingame, step.unitId)
			elseif step.t == "sell" then
				init.invoke(init.REMOTE.sell_unit_ingame, step.unitId)
			elseif step.t == "priority" then
				init.invoke(init.REMOTE.change_priority, step.unitId, step.priority)
			elseif step.t == "spell" then
				init.invoke(init.REMOTE.use_ingame_spell, step.unitId)
			end
			if step.time then task.wait(step.time) end
		end
	end)
	return true
end

----------------------------------------------------------------
-- TICK
----------------------------------------------------------------
function M.tick()
	M.tickWaveActions()
	M.tickPlace()
end

return M
