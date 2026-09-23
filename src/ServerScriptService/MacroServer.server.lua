-- Macro server: validates actions, persists macros via DataStore, replays recorded actions.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Parent.ReplicatedStorage.Remotes)
local StageManager = require(script.Parent.StageManager)

local UNITS_FOLDER = ReplicatedStorage:WaitForChild("Units")
local DATASTORE_NAME = "Macros_v1"

local macrosStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local function unitExists(unitName)
	if not unitName then
		return false
	end
	local unit = UNITS_FOLDER:FindFirstChild(unitName)
	return unit ~= nil
end

local function clampNumber(value, minimum, maximum)
	if type(value) ~= "number" then
		return nil
	end
	if value < minimum or value > maximum then
		return nil
	end
	return value
end

local function sanitizeAction(raw, index)
	if type(raw) ~= "table" then
		return nil, "action[" .. index .. "] is not a table"
	end
	local actionType = raw.t or raw.type
	if actionType ~= "place" and actionType ~= "upgrade" and actionType ~= "sell"
		and actionType ~= "priority" and actionType ~= "ability" then
		return nil, "action[" .. index .. "] has unsupported type"
	end

	local sanitized = {
		t = actionType,
		n = raw.n or raw.unitName,
		x = clampNumber(raw.x or raw.px, -10000, 10000),
		y = clampNumber(raw.y or raw.py, -10000, 10000),
		z = clampNumber(raw.z or raw.pz, -10000, 10000),
		time = clampNumber(raw.time or raw.t or 0, 0, 60 * 60 * 12),
	}

	if actionType == "place" and not unitExists(sanitized.n) then
		return nil, "action[" .. index .. "] references unknown unit"
	end

	if actionType == "place" and (sanitized.x == nil or sanitized.y == nil or sanitized.z == nil) then
		return nil, "action[" .. index .. "] missing coordinates"
	end

	return sanitized
end

local function sanitizeMacro(raw)
	if type(raw) ~= "table" then
		return nil, "macro payload is not a table"
	end
	local actions = raw.actions
	if type(actions) ~= "table" then
		return nil, "actions must be a list"
	end
	local cleaned = {}
	for i, action in actions do
		local sanitized, err = sanitizeAction(action, i)
		if not sanitized then
			return nil, err
		end
		table.insert(cleaned, sanitized)
	end
	return {
		actions = cleaned,
		recordedAt = os.time(),
		stageName = raw.stageName or raw.stage or "Unknown",
	}
end

local function loadMacros(userId)
	local key = "macros_" .. tostring(userId)
	local ok, value = pcall(macrosStore.GetAsync, macrosStore, key)
	if ok and type(value) == "table" then
		return value
	end
	return {}
end

local function saveMacros(userId, macros)
	local key = "macros_" .. tostring(userId)
	local ok, err = pcall(macrosStore.SetAsync, macrosStore, key, macros)
	if not ok then
		warn("[MacroServer] Failed to save macros for", userId, err)
		return false
	end
	return true
end

local function actionCost(unitName)
	local unit = UNITS_FOLDER:FindFirstChild(unitName)
	if not unit then
		return math.huge
	end
	local config = unit:FindFirstChild("Config")
	if config then
		local price = config:FindFirstChild("Price") or config:FindFirstChild("Cost")
		if price and price:IsA("NumberValue") then
			return price.Value
		end
	end
	return 100
end

local function recordAction(player, actionType, payload)
	local macros = loadMacros(player.UserId)
	macros[#macros + 1] = {
		t = actionType,
		n = payload.unitName,
		x = payload.x,
		y = payload.y,
		z = payload.z,
		time = payload.time or 0,
	}
	return macros
end

local function applyActionToGame(player, action)
	-- This is the bridge to your game's place/upgrade/sell systems. Replace the
	-- bodies below with calls to your actual server handlers if they exist.
	local success, err = pcall(function()
		if action.t == "place" then
			local cost = actionCost(action.n)
			print(("[MacroServer] %s placed %s at (%.1f, %.1f, %.1f) for %d"):format(
				player.Name, action.n, action.x, action.y, action.z, cost))
		elseif action.t == "upgrade" then
			print(("[MacroServer] %s upgraded %s"):format(player.Name, action.n))
		elseif action.t == "sell" then
			print(("[MacroServer] %s sold %s"):format(player.Name, action.n))
		elseif action.t == "priority" then
			print(("[MacroServer] %s set priority on %s"):format(player.Name, action.n))
		elseif action.t == "ability" then
			print(("[MacroServer] %s used ability on %s"):format(player.Name, action.n))
		end
	end)
	if not success then
		warn("[MacroServer] Action failed:", err)
	end
	return success
end

local function setupRemotes(remotes)
	local placeConn = remotes.PlaceUnit.OnServerEvent:Connect(function(player, unitName, x, y, z)
		if not unitExists(unitName) then
			return
		end
		applyActionToGame(player, { t = "place", n = unitName, x = x, y = y, z = z })
		recordAction(player, "place", { unitName = unitName, x = x, y = y, z = z })
	end)

	local upgradeConn = remotes.UpgradeUnit.OnServerEvent:Connect(function(player, unitName)
		if not unitExists(unitName) then
			return
		end
		applyActionToGame(player, { t = "upgrade", n = unitName })
		recordAction(player, "upgrade", { unitName = unitName })
	end)

	local sellConn = remotes.SellUnit.OnServerEvent:Connect(function(player, unitName)
		if not unitExists(unitName) then
			return
		end
		applyActionToGame(player, { t = "sell", n = unitName })
		recordAction(player, "sell", { unitName = unitName })
	end)

	local priorityConn = remotes.SetTargetPriority.OnServerEvent:Connect(function(player, unitName, priority)
		applyActionToGame(player, { t = "priority", n = unitName })
		recordAction(player, "priority", { unitName = unitName })
	end)

	local abilityConn = remotes.UseAbility.OnServerEvent:Connect(function(player, unitName)
		applyActionToGame(player, { t = "ability", n = unitName })
		recordAction(player, "ability", { unitName = unitName })
	end)

	remotes.MacroPlay.OnServerInvoke = function(player, macroName, actionIndex)
		local macros = loadMacros(player.UserId)
		local macro = macros[macroName]
		if not macro or not macro.actions then
			return false
		end
		local action = macro.actions[actionIndex]
		if not action then
			return false
		end
		return applyActionToGame(player, action)
	end

	remotes.MacroLoadRequest.OnServerInvoke = function(player)
		local macros = loadMacros(player.UserId)
		local names = {}
		for name in macros do
			table.insert(names, name)
		end
		table.sort(names)
		return {
			names = names,
			macros = macros,
		}
	end

	return { placeConn, upgradeConn, sellConn, priorityConn, abilityConn }
end

local function setupStageWatcher(remotes)
	local recordingPlayers = {}

	StageManager.subscribe(function(state, current)
		if state == "Playing" or state == "Active" or state == "InProgress" then
			return
		end
		if state ~= "Completed" and state ~= "Victory" and state ~= "Failed" then
			return
		end

		for _, player in Players:GetPlayers() do
			local pending = recordingPlayers[player.UserId]
			if pending then
				local macros = loadMacros(player.UserId)
				macros[pending.name] = sanitizeMacro({
					actions = pending.actions,
					stageName = tostring(current or "Unknown"),
				}) or macros[pending.name]
				if saveMacros(player.UserId, macros) then
					remotes.MacroRecordEvent:FireClient(player, "saved", pending.name, #pending.actions)
				else
					remotes.MacroRecordEvent:FireClient(player, "error", pending.name, 0)
				end
				recordingPlayers[player.UserId] = nil
			end
		end
	end)

	return recordingPlayers
end

local function start()
	local remotes = Remotes.bootstrap()
	local recordingPlayers = setupStageWatcher(remotes)
	setupRemotes(remotes)

	Players.PlayerAdded:Connect(function(player)
		recordingPlayers[player.UserId] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		recordingPlayers[player.UserId] = nil
	end)
end

start()
