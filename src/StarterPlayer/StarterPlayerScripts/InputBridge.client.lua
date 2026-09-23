-- Client-side input bridge for the macro recorder.
-- Intercepts hotbar selection, map placement, and unit-context actions
-- (upgrade, sell, change priority, ability) so the recorder sees the same
-- actions the player performs. No edits to existing game scripts required.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MacroRecorder = require(script.Parent:WaitForChild("MacroRecorder"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local HOTBAR_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
}

local HOTBAR_SLOTS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

local function getUnitNameAtSlot(slot)
	-- Replace this with your hotbar source. Common shapes:
	--   playerGui.Hotbar.Slots[slot].Unit.Value
	--   player.PlayerScripts.Hotbar:GetSelectedUnit(slot)
	--   workspace.Hotbar[slot].UnitName.Value
	local candidate = {
		playerGui:FindFirstChild("Hotbar"),
		player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Hotbar"),
		workspace:FindFirstChild("Hotbar"),
	}
	for _, folder in candidate do
		if folder then
			local child = folder:FindFirstChild(tostring(slot))
			if child then
				local nameValue = child:FindFirstChild("UnitName") or child:FindFirstChild("Unit")
				if nameValue and (nameValue:IsA("StringValue") or nameValue:IsA("ObjectValue")) then
					return nameValue.Value
				end
				return child.Name
			end
		end
	end
	return nil
end

local function selectedUnitFromHotbar()
	local hotbar = playerGui:FindFirstChild("Hotbar")
	if not hotbar then
		return nil
	end
	local selected = hotbar:FindFirstChild("Selected") or hotbar:GetAttribute("SelectedSlot")
	if typeof(selected) == "number" then
		return getUnitNameAtSlot(selected), selected
	end
	if selected and selected:IsA("NumberValue") then
		return getUnitNameAtSlot(selected.Value), selected.Value
	end
	return nil, nil
end

local function getCamera()
	return workspace.CurrentCamera
end

local function mouseToWorld(mouseLocation)
	local camera = getCamera()
	if not camera then
		return nil
	end
	local unitRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
	if result then
		return result.Position
	end
	return unitRay.Origin + unitRay.Direction * 50
end

local function pickPlacedUnitAt(mouseLocation)
	local camera = getCamera()
	if not camera then
		return nil
	end
	local unitRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
	if not result then
		return nil
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local unitAttr = model:GetAttribute("UnitName") or model:GetAttribute("UnitId")
	if unitAttr then
		return model, tostring(unitAttr)
	end
	return model, model.Name
end

local function firePlace(unitName, position)
	if not unitName or not position then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder then
		local remote = folder:FindFirstChild("PlaceUnit")
		if remote then
			remote:FireServer(unitName, position.X, position.Y, position.Z)
		end
	end
	MacroRecorder.Place(unitName, position.X, position.Y, position.Z)
end

local function fireUpgrade(unitName)
	if not unitName then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder then
		local remote = folder:FindFirstChild("UpgradeUnit")
		if remote then
			remote:FireServer(unitName)
		end
	end
	MacroRecorder.Upgrade(unitName)
end

local function fireSell(unitName)
	if not unitName then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder then
		local remote = folder:FindFirstChild("SellUnit")
		if remote then
			remote:FireServer(unitName)
		end
	end
	MacroRecorder.Sell(unitName)
end

local function firePriority(unitName, priority)
	if not unitName then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder then
		local remote = folder:FindFirstChild("SetTargetPriority")
		if remote then
			remote:FireServer(unitName, priority or "First")
		end
	end
	MacroRecorder.SetPriority(unitName, priority or "First")
end

local function fireAbility(unitName)
	if not unitName then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder then
		local remote = folder:FindFirstChild("UseAbility")
		if remote then
			remote:FireServer(unitName)
		end
	end
	MacroRecorder.UseAbility(unitName)
end

local pendingHotbarSlot = nil

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if table.find(HOTBAR_KEYS, input.KeyCode) then
		pendingHotbarSlot = HOTBAR_SLOTS[input.KeyCode]
		return
	end

	if input.KeyCode == Enum.KeyCode.U then
		local _, unitName = pickPlacedUnitAt(UserInputService:GetMouseLocation())
		fireUpgrade(unitName)
		return
	end

	if input.KeyCode == Enum.KeyCode.X then
		local _, unitName = pickPlacedUnitAt(UserInputService:GetMouseLocation())
		fireSell(unitName)
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		local _, unitName = pickPlacedUnitAt(UserInputService:GetMouseLocation())
		fireAbility(unitName)
		return
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	if pendingHotbarSlot then
		local unitName = getUnitNameAtSlot(pendingHotbarSlot)
		if unitName then
			local position = mouseToWorld(UserInputService:GetMouseLocation())
			firePlace(unitName, position)
		end
		pendingHotbarSlot = nil
		return
	end

	local _, unitName = pickPlacedUnitAt(UserInputService:GetMouseLocation())
	if unitName then
		firePriority(unitName, "First")
	end
end)

RunService.RenderStepped:Connect(function()
	-- Clear stale slot selection if the player moves on without placing.
	if pendingHotbarSlot and os.clock() - (pendingHotbarSlot._pickedAt or 0) > 5 then
		pendingHotbarSlot = nil
	end
	if pendingHotbarSlot then
		pendingHotbarSlot._pickedAt = pendingHotbarSlot._pickedAt or os.clock()
	end
end)

MacroRecorder.Init(function() end)
