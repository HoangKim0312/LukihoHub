-- Client-side recorder and playback controller. Talks to MacroServer via the
-- Remotes module and notifies the host GUI through callbacks.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local MacroRecorder = {}
MacroRecorder.Recording = false
MacroRecorder.Playing = false
MacroRecorder.CurrentName = nil
MacroRecorder.StartTime = nil
MacroRecorder.Actions = {}
MacroRecorder.OnStateChanged = nil

local remotes = nil

local function getRemotes()
	if not remotes then
		local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
		if folder then
			remotes = folder
		end
	end
	return remotes
end

local function emit(state, payload)
	if MacroRecorder.OnStateChanged then
		MacroRecorder.OnStateChanged(state, payload)
	end
end

local function recordAction(actionType, payload)
	if not MacroRecorder.Recording then
		return
	end
	local now = os.clock() - (MacroRecorder.StartTime or 0)
	table.insert(MacroRecorder.Actions, {
		t = actionType,
		n = payload.unitName,
		x = payload.x,
		y = payload.y,
		z = payload.z,
		time = now,
	})
end

local function hookRemotes()
	local r = getRemotes()
	if not r then
		return false
	end
	r.PlaceUnit.OnClientEvent = nil
	r.UpgradeUnit.OnClientEvent = nil
	r.SellUnit.OnClientEvent = nil
	r.SetTargetPriority.OnClientEvent = nil
	r.UseAbility.OnClientEvent = nil

	local function place(unitName, x, y, z)
		recordAction("place", { unitName = unitName, x = x, y = y, z = z })
		r.PlaceUnit:FireServer(unitName, x, y, z)
	end

	local function upgrade(unitName)
		recordAction("upgrade", { unitName = unitName })
		r.UpgradeUnit:FireServer(unitName)
	end

	local function sell(unitName)
		recordAction("sell", { unitName = unitName })
		r.SellUnit:FireServer(unitName)
	end

	local function setPriority(unitName, priority)
		recordAction("priority", { unitName = unitName })
		r.SetTargetPriority:FireServer(unitName, priority)
	end

	local function useAbility(unitName)
		recordAction("ability", { unitName = unitName })
		r.UseAbility:FireServer(unitName)
	end

	MacroRecorder.Place = place
	MacroRecorder.Upgrade = upgrade
	MacroRecorder.Sell = sell
	MacroRecorder.SetPriority = setPriority
	MacroRecorder.UseAbility = useAbility

	r.MacroRecordEvent.OnClientEvent:Connect(function(kind, name, count)
		if kind == "saved" then
			MacroRecorder.Recording = false
			emit("saved", { name = name, count = count })
		elseif kind == "error" then
			MacroRecorder.Recording = false
			emit("error", { name = name })
		end
	end)

	return true
end

function MacroRecorder.StartRecording(name)
	if MacroRecorder.Recording then
		return false, "already recording"
	end
	if type(name) ~= "string" or name == "" then
		return false, "name is required"
	end
	if not getRemotes() then
		return false, "remotes not ready"
	end
	MacroRecorder.Recording = true
	MacroRecorder.CurrentName = name
	MacroRecorder.StartTime = os.clock()
	MacroRecorder.Actions = {}
	emit("recording", { name = name })
	return true
end

function MacroRecorder.StopRecording()
	if not MacroRecorder.Recording then
		return false, "not recording"
	end
	local snapshot = MacroRecorder.Actions
	local name = MacroRecorder.CurrentName
	MacroRecorder.Recording = false
	MacroRecorder.Actions = {}
	MacroRecorder.CurrentName = nil
	emit("stopped", { name = name, count = #snapshot })
	return true, { name = name, actions = snapshot }
end

function MacroRecorder.ListMacros()
	local r = getRemotes()
	if not r then
		return {}
	end
	local ok, payload = pcall(r.MacroLoadRequest.InvokeServer, r.MacroLoadRequest)
	if ok and type(payload) == "table" then
		return payload
	end
	return { names = {}, macros = {} }
end

function MacroRecorder.PlayMacro(name)
	if MacroRecorder.Playing then
		return false, "already playing"
	end
	local r = getRemotes()
	if not r then
		return false, "remotes not ready"
	end
	local list = MacroRecorder.ListMacros()
	local macro = list.macros and list.macros[name]
	if not macro then
		return false, "macro not found"
	end
	MacroRecorder.Playing = true
	emit("playing", { name = name, count = #(macro.actions or {}) })

	task.spawn(function()
		local start = os.clock()
		for i, action in macro.actions do
			local waitTime = (action.time or 0) - (os.clock() - start)
			if waitTime > 0 then
				task.wait(waitTime)
			end
			local ok, result = pcall(r.MacroPlay.InvokeServer, r.MacroPlay, name, i)
			if not ok then
				warn("[MacroRecorder] Playback step failed:", result)
			end
		end
		MacroRecorder.Playing = false
		emit("finished", { name = name })
	end)
	return true
end

local function bindPlayerPositionHook()
	RunService.Heartbeat:Connect(function()
		-- Placeholder for additional hooks (e.g., camera). Reserved for future use.
	end)
end

function MacroRecorder.Init(onStateChanged)
	MacroRecorder.OnStateChanged = onStateChanged
	if not hookRemotes() then
		task.defer(function()
			hookRemotes()
		end)
	end
	bindPlayerPositionHook()
end

return MacroRecorder
