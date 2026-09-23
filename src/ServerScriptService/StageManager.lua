-- Server-side stage tracker. Polls your game's StageManager module if present,
-- otherwise watches a workspace attribute fallback.

local RunService = game:GetService("RunService")

local StageManager = {}
StageManager.State = "Idle"
StageManager.CurrentStage = nil

local function callModule(name)
	local ok, mod = pcall(function()
		return require(game:GetService("ServerScriptService"):FindFirstChild(name))
	end)
	if ok and type(mod) == "table" then
		return mod
	end
	return nil
end

local remoteModule = nil
local function getStageModule()
	if remoteModule then
		return remoteModule
	end
	for _, name in { "StageManager", "Stages", "WaveManager" } do
		local mod = callModule(name)
		if mod and (mod.GetCurrentStage or mod.GetState) then
			remoteModule = mod
			return mod
		end
	end
	return nil
end

local workspaceFolder = workspace:FindFirstChild("Stage")
if not workspaceFolder then
	workspaceFolder = Instance.new("Folder")
	workspaceFolder.Name = "Stage"
	workspaceFolder.Parent = workspace
	local stateValue = Instance.new("StringValue")
	stateValue.Name = "State"
	stateValue.Value = "Idle"
	stateValue.Parent = workspaceFolder
	local stageValue = Instance.new("IntValue")
	stageValue.Name = "CurrentStage"
	stageValue.Value = 0
	stageValue.Parent = workspaceFolder
end

local function getFallbackState()
	local stateVal = workspaceFolder:FindFirstChild("State")
	local stageVal = workspaceFolder:FindFirstChild("CurrentStage")
	return stateVal and stateVal.Value or "Idle", stageVal and stageVal.Value or 0
end

function StageManager.GetState()
	local mod = getStageModule()
	if mod and mod.GetState then
		local ok, state = pcall(mod.GetState)
		if ok then
			return state
		end
	end
	return getFallbackState()
end

function StageManager.GetCurrentStage()
	local mod = getStageModule()
	if mod and mod.GetCurrentStage then
		local ok, stage = pcall(mod.GetCurrentStage)
		if ok then
			return stage
		end
	end
	local _, current = getFallbackState()
	return current
end

function StageManager.IsStageActive()
	local state = StageManager.GetState()
	return state == "Playing" or state == "Active" or state == "InProgress"
end

function StageManager.IsStageCompleted()
	local state = StageManager.GetState()
	return state == "Completed" or state == "Victory" or state == "Failed"
end

function StageManager.subscribe(callback)
	local lastState = nil
	local lastStage = nil
	RunService.Heartbeat:Connect(function()
		local state = StageManager.GetState()
		local current = StageManager.GetCurrentStage()
		if state ~= lastState or current ~= lastStage then
			lastState = state
			lastStage = current
			callback(state, current)
		end
	end)
end

return StageManager
