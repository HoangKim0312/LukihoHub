--!strict
-- Lukiho Automation Console. Run only in an experience you own and can test.
-- Game-specific module paths below are taken from the supplied reference script.

if game.GameId ~= 5595353122 then
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local global = _G :: any
if type(global.LukihoHubUnload) == "function" then
	global.LukihoHubUnload()
end

type Connection = RBXScriptConnection
type StateType = {
	running: boolean,
	autoFarm: boolean,
	autoBoss: boolean,
	autoChestFarm: boolean,
	autoChest: boolean,
	autoLoot: boolean,
	autoSkills: boolean,
	holdSkill: boolean,
	selectedSkill: string,
	selectedSkills: {[string]: boolean},
	selectedMob: string?,
	selectedBoss: string?,
	selectedTier: string,
	weaponSlot: number?,
	searchRadius: number,
	lootRadius: number,
	attackOffset: number,
	attackHeight: number,
	dodgeHeight: number,
	dodgeDuration: number,
	trackSpeed: number,
	comboDelay: number,
	patrolInterval: number,
	fly: boolean,
	flySpeed: number,
	noclip: boolean,
	speed: boolean,
	speedValue: number,
	cframeSpeed: boolean,
	cframeMultiplier: number,
	infiniteJump: boolean,
	jumpBoost: number,
	target: Model?,
	targetHumanoid: Humanoid?,
	targetRoot: BasePart?,
	dodgingUntil: number,
	lastSkill: number,
	lastPatrol: number,
	patrolIndex: number,
	chestTarget: Instance?,
	comboCount: number,
	postKillUntil: number,
	travelDestination: Vector3?,
	manualTravel: boolean,
}

local State: StateType = {
	running = true,
	autoFarm = false,
	autoBoss = false,
	autoChestFarm = false,
	autoChest = false,
	autoLoot = false,
	autoSkills = false,
	holdSkill = false,
	selectedSkill = "Z",
	selectedSkills = { Z = true, X = true, C = true, V = true, B = true },
	selectedMob = nil,
	selectedBoss = nil,
	selectedTier = "All",
	weaponSlot = nil,
	searchRadius = 1000,
	lootRadius = 40,
	attackOffset = 4.5,
	attackHeight = -6,
	dodgeHeight = 22,
	dodgeDuration = 0.7,
	trackSpeed = 180,
	comboDelay = 0.28,
	patrolInterval = 2,
	fly = false,
	flySpeed = 80,
	noclip = false,
	speed = false,
	speedValue = 32,
	cframeSpeed = false,
	cframeMultiplier = 1,
	infiniteJump = false,
	jumpBoost = 50,
	target = nil,
	targetHumanoid = nil,
	targetRoot = nil,
	dodgingUntil = 0,
	lastSkill = 0,
	lastPatrol = 0,
	patrolIndex = 0,
	chestTarget = nil,
	comboCount = 0,
	postKillUntil = 0,
	travelDestination = nil,
	manualTravel = false,
}

local connections: {Connection} = {}
local collisionStates: {[BasePart]: boolean} = {}
local targetAnimationConnection: Connection? = nil
local stoppedConnections: {Connection} = {}
local flyVelocity: BodyVelocity? = nil
local library: any = nil
local heldAction: string? = nil
local lastEquip = 0
local speedBaseline: {[Humanoid]: number} = {}
local mobDropdown: any = nil
local bossDropdown: any = nil
local weaponDropdown: any = nil
local mobNames = { "All" }
local bossNames = { "All" }
local weaponNames: {string} = {}
local weaponSlots: {[string]: number} = {}
local observedMobs: {[string]: boolean} = {}
local observedBosses: {[string]: boolean} = {}
local registeredBosses: {[string]: boolean} = {}
local bossSpawnPositions: {[string]: Vector3} = {}
local npcSpawnPositions: {[string]: Vector3} = {}

local function connect(signal: RBXScriptSignal, callback: (...any) -> ()): Connection
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then return nil, nil, nil end
	return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function live(): boolean
	local _, hum, root = getCharacter()
	return State.running and hum ~= nil and hum.Health > 0 and root ~= nil
end

local function requirePath(root: Instance, path: {string}): any
	local current = root
	for _, segment in path do
		local nextInstance = current:FindFirstChild(segment)
		if not nextInstance then return nil end
		current = nextInstance
	end
	if not current:IsA("ModuleScript") then return nil end
	local ok, result = pcall(require, current)
	return if ok then result else nil
end

local input: any = requirePath(ReplicatedStorage, { "CAM", "Client", "Components", "Client", "InputHandler" })
local skillsProvider: any = requirePath(ReplicatedStorage, { "CAM", "Client", "Controllers", "Skills_Provider" })
local worldBosses: any = requirePath(ReplicatedStorage, { "CAM", "Client", "Modules", "WorldBosses" })
local regions: any = requirePath(ReplicatedStorage, { "Regions" })
local items: any = requirePath(ReplicatedStorage, { "CAM", "Global", "Collectibles", "Items" })
local characterInfo: any = requirePath(ReplicatedStorage, { "CAM", "Global", "Character_info_provider" })
if not input or type(input.VirtualPress) ~= "function" or type(input.VirtualRelease) ~= "function" then
	warn("[Lukiho] InputHandler missing or incompatible; combat controls disabled.")
end

local function press(action: string, duration: number)
	if not input then return end
	local ok, err = pcall(function()
		input.VirtualPress(action)
		task.wait(duration)
		input.VirtualRelease(action)
	end)
	if not ok then warn("[Lukiho] Input action failed:", action, err) end
end

local function release(action: string)
	if input then pcall(function() input.VirtualRelease(action) end) end
end

local function skillAction(key: string): (string, string?)
	local fallback = { Z = "Skills_2nd", X = "Skills_3rd", C = "Skills_4th", V = "Skills_5th", B = "Skills_6th" }
	if skillsProvider and type(skillsProvider.get_current_keys) == "function" then
		local ok, entries = pcall(skillsProvider.get_current_keys)
		if ok and type(entries) == "table" then
			local ordinals = { "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th" }
			for index, entry in entries do
				if type(entry) == "table" and entry.Key == key then
					return "Skills_" .. (ordinals[index] or tostring(index)), entry.Name
				end
			end
		end
	end
	return fallback[key] or fallback.Z, nil
end

local function skillReady(skillName: string?): boolean
	local character = player.Character
	local status = character and character:FindFirstChild("SHC")
	return skillName == nil or status == nil or status:FindFirstChild(skillName) == nil
end

local function releaseHold()
	if heldAction then release(heldAction) end
	heldAction = nil
end

local attackIds: {[string]: boolean} = {}
local locomotionIds: {[string]: boolean} = {}
local function indexAnimations()
	table.clear(attackIds)
	table.clear(locomotionIds)
	local skills = ReplicatedStorage:FindFirstChild("Skills")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local function add(folder: Instance, bucket: {[string]: boolean})
		for _, item in folder:GetDescendants() do
			if item:IsA("Animation") and item.AnimationId ~= "" then
				bucket[item.AnimationId] = true
				local numeric = item.AnimationId:match("%d+")
				if numeric then bucket[numeric] = true end
			end
		end
	end
	if skills then add(skills, attackIds) end
	if animations then
		for _, category in animations:GetChildren() do
			local name = category.Name:lower()
			if name:find("_combat_anims", 1, true) then
				add(category, attackIds)
			elseif name:find("core", 1, true) or name:find("dash", 1, true) or name:find("defaultnpc", 1, true) then
				add(category, locomotionIds)
			end
		end
	end
end
indexAnimations()

local locomotionWords = { "idle", "walk", "run", "jump", "fall", "land", "swim", "block", "stun", "dash", "dodge", "react" }
local attackWords = { "swing", "slash", "attack", "strike", "punch", "kick", "smash", "thrust", "barrage", "skill", "charge", "grab" }
local function attackTrack(track: AnimationTrack): boolean
	local animation = track.Animation
	local id = if animation then animation.AnimationId else ""
	local numeric = id:match("%d+")
	if locomotionIds[id] or (numeric and locomotionIds[numeric]) then return false end
	if attackIds[id] or (numeric and attackIds[numeric]) then return true end
	local name = track.Name:lower()
	for _, word in locomotionWords do
		if name:find(word, 1, true) then return false end
	end
	for _, word in attackWords do
		if name:find(word, 1, true) then return true end
	end
	return false
end

local function clearTarget()
	if targetAnimationConnection then targetAnimationConnection:Disconnect() end
	targetAnimationConnection = nil
	for _, connection in stoppedConnections do connection:Disconnect() end
	table.clear(stoppedConnections)
	State.target = nil
	State.targetHumanoid = nil
	State.targetRoot = nil
	State.dodgingUntil = 0
end

local function setTarget(model: Model, humanoid: Humanoid, root: BasePart)
	if State.target == model then return end
	clearTarget()
	State.target = model
	State.targetHumanoid = humanoid
	State.targetRoot = root
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		targetAnimationConnection = animator.AnimationPlayed:Connect(function(track)
			if attackTrack(track) then
				State.dodgingUntil = os.clock() + State.dodgeDuration
				local stopped: Connection?
				stopped = track.Stopped:Connect(function()
					State.dodgingUntil = math.min(State.dodgingUntil, os.clock() + 0.15)
					if stopped then
						stopped:Disconnect()
						local index = table.find(stoppedConnections, stopped)
						if index then table.remove(stoppedConnections, index) end
					end
				end)
				if stopped then table.insert(stoppedConnections, stopped) end
			end
		end)
	end
end

local function candidate(model: Model): (Humanoid?, BasePart?)
	if Players:GetPlayerFromCharacter(model) then return nil, nil end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function isBossModel(model: Model): boolean
	if registeredBosses[model.Name] then return true end
	if CollectionService:HasTag(model, "Boss") or CollectionService:HasTag(model, "EventBoss") then
		return true
	end
	if model:GetAttribute("IsBoss") == true or model:GetAttribute("Boss") == true then
		return true
	end
	for _, attribute in { "NPCType", "EnemyType", "Type", "Rank" } do
		local value = model:GetAttribute(attribute)
		if type(value) == "string" and value:lower():find("boss", 1, true) then
			return true
		end
	end
	local bossValue = model:FindFirstChild("IsBoss") or model:FindFirstChild("Boss")
	if bossValue and bossValue:IsA("BoolValue") and bossValue.Value then
		return true
	end
	local bosses = Workspace:FindFirstChild("Bosses")
	if bosses and model:IsDescendantOf(bosses) then
		return true
	end
	local spawns = Workspace:FindFirstChild("BossSpawns")
	return spawns ~= nil and spawns:FindFirstChild(model.Name) ~= nil
end

local function readPosition(value: any): Vector3?
	if typeof(value) == "Vector3" then return value end
	if typeof(value) == "CFrame" then return value.Position end
	if type(value) ~= "string" then return nil end
	local x, y, z = value:match("([^,]+),%s*([^,]+),%s*([^,]+)")
	if not x or not y or not z then return nil end
	local px, py, pz = tonumber(x), tonumber(y), tonumber(z)
	return if px and py and pz then Vector3.new(px, py, pz) else nil
end

local function refreshGameCatalog()
	if not worldBosses then worldBosses = requirePath(ReplicatedStorage, { "CAM", "Client", "Modules", "WorldBosses" }) end
	if not regions then regions = requirePath(ReplicatedStorage, { "Regions" }) end
	local spawns = if regions and type(regions.NpcSpawns) == "table" then regions.NpcSpawns else nil
	if worldBosses and type(worldBosses.Get) == "function" then
		local ok, entries = pcall(worldBosses.Get)
		if ok and type(entries) == "table" then
			for _, entry in entries do
				if type(entry) == "table" and type(entry.Name) == "string" and entry.Name ~= "" then
					registeredBosses[entry.Name] = true
					local position = readPosition(entry.Position or (spawns and spawns[entry.Name]))
					if position then bossSpawnPositions[entry.Name] = position end
				end
			end
		end
	end
	local hunts = ReplicatedStorage:FindFirstChild("BossHunts")
	if hunts then
		for _, hunt in hunts:GetChildren() do
			local name = hunt:GetAttribute("Boss")
			if type(name) == "string" and name ~= "" then registeredBosses[name] = true end
		end
	end
	if spawns then
		for name, rawPosition in spawns do
			if type(name) == "string" and name ~= "" and not registeredBosses[name] then
				observedMobs[name] = true
				local position = readPosition(rawPosition)
				if position then npcSpawnPositions[name] = position end
			end
		end
	end
end

local function scanNpcCatalog(): ({string}, {string})
	refreshGameCatalog()
	local seen: {[Model]: boolean} = {}
	local function register(model: Model)
		if seen[model] then return end
		seen[model] = true
		if Players:GetPlayerFromCharacter(model) then return end
		if not model:FindFirstChildOfClass("Humanoid") or not model:FindFirstChild("HumanoidRootPart") then return end
		if isBossModel(model) then
			observedBosses[model.Name] = true
			observedMobs[model.Name] = nil
		else
			observedMobs[model.Name] = true
		end
	end
	local humanoids = Workspace:FindFirstChild("Humanoids")
	if humanoids then
		for _, item in humanoids:GetDescendants() do
			if item:IsA("Model") then register(item) end
		end
	else
		for _, item in Workspace:GetDescendants() do
			if item:IsA("Model") then register(item) end
		end
	end
	local bossFolder = Workspace:FindFirstChild("Bosses")
	if bossFolder then
		for _, item in bossFolder:GetDescendants() do
			if item:IsA("Model") then register(item) end
		end
	end
	for _, tag in { "Enemy", "Boss", "EventBoss" } do
		for _, item in CollectionService:GetTagged(tag) do
			if item:IsA("Model") then register(item) end
		end
	end
	local spawns = Workspace:FindFirstChild("BossSpawns")
	if spawns then
		for _, marker in spawns:GetChildren() do
			registeredBosses[marker.Name] = true
			observedBosses[marker.Name] = true
			observedMobs[marker.Name] = nil
		end
	end
	for name in registeredBosses do
		observedBosses[name] = true
		observedMobs[name] = nil
	end
	local nextMobs: {string} = {}
	local nextBosses: {string} = {}
	for name in observedMobs do table.insert(nextMobs, name) end
	for name in observedBosses do table.insert(nextBosses, name) end
	table.sort(nextMobs)
	table.sort(nextBosses)
	table.insert(nextMobs, 1, "All")
	table.insert(nextBosses, 1, "All")
	return nextMobs, nextBosses
end

local function nearestNpc(bossOnly: boolean): (Model?, Humanoid?, BasePart?)
	local selected = if bossOnly then State.selectedBoss else State.selectedMob
	if not selected then return nil, nil, nil end
	local _, _, playerRoot = getCharacter()
	if not playerRoot then return nil, nil, nil end
	local best: Model? = nil
	local bestHum: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local distance = State.searchRadius
	local seen: {[Model]: boolean} = {}
	local function consider(model: Model)
		if seen[model] then return end
		seen[model] = true
		local boss = isBossModel(model)
		if bossOnly ~= boss then return end
		if selected ~= "All" and model.Name ~= selected then return end
		local hum, root = candidate(model)
		if hum and root then
			local current = (root.Position - playerRoot.Position).Magnitude
			if current <= distance then
				distance, best, bestHum, bestRoot = current, model, hum, root
			end
		end
	end
	local folder = Workspace:FindFirstChild("Humanoids")
	if folder then
		for _, child in folder:GetDescendants() do
			if child:IsA("Model") then consider(child) end
		end
	end
	local bossFolder = Workspace:FindFirstChild("Bosses")
	if bossFolder then
		for _, child in bossFolder:GetDescendants() do
			if child:IsA("Model") then consider(child) end
		end
	end
	for _, tagged in CollectionService:GetTagged(if bossOnly then "Boss" else "Enemy") do
		if tagged:IsA("Model") then consider(tagged) end
	end
	if bossOnly then
		for _, tagged in CollectionService:GetTagged("EventBoss") do
			if tagged:IsA("Model") then consider(tagged) end
		end
	end
	return best, bestHum, bestRoot
end

local function travelToSelected(bossOnly: boolean)
	local model, humanoid, root = nearestNpc(bossOnly)
	if not model or not humanoid or not root then
		local selectedName = if bossOnly then State.selectedBoss else State.selectedMob
		local position: Vector3? = nil
		if selectedName then
			position = if bossOnly then bossSpawnPositions[selectedName] else npcSpawnPositions[selectedName]
		end
		if position then
			clearTarget()
			State.travelDestination = position + Vector3.new(0, 5, 0)
			State.manualTravel = true
			return
		end
		warn("[Lukiho] Select an active " .. (if bossOnly then "boss" else "mob") .. " or one with a known spawn position.")
		return
	end
	State.travelDestination = nil
	State.manualTravel = true
	setTarget(model, humanoid, root)
end

local function ensureWeapon()
	local selectedSlot = State.weaponSlot
	if not selectedSlot or os.clock() - lastEquip < 0.6 then return end
	local index = tostring(selectedSlot)
	local toolbar = player:FindFirstChild("PlayerGui")
	local holder = toolbar and toolbar:FindFirstChild("ComponentsHolder")
	local bottom = holder and holder:FindFirstChild("BottomHolder")
	local bar = bottom and bottom:FindFirstChild("Toolbar")
	local skills = bar and bar:FindFirstChild("SkillHolder")
	local slot = skills and skills:FindFirstChild(index .. "_ToolPosition")
	local selection = slot and slot:FindFirstChild("CircleSelect")
	if selection and selection:IsA("ImageLabel") and selection.ImageTransparency < 0.72 then return end
	local action = ({ ["1"] = "Toolbar_1st", ["2"] = "Toolbar_2nd", ["3"] = "Toolbar_3rd", ["4"] = "Toolbar_4th", ["5"] = "Toolbar_5th" })[index]
	if action then lastEquip = os.clock(); press(action, 0.04) end
end

local function activeTarget(): boolean
	return State.target ~= nil and State.target.Parent ~= nil and State.targetHumanoid ~= nil
		and State.targetHumanoid.Health > 0 and State.targetRoot ~= nil and State.targetRoot.Parent ~= nil
end

local function readCombo(): number
	local character = player.Character
	local counter = character and character:FindFirstChild("ComboCounter")
	return if counter and counter:IsA("IntValue") then counter.Value else 0
end

local function supervise(name: string, interval: number, callback: () -> ())
	task.spawn(function()
		while State.running do
			local ok, err = xpcall(callback, function(message) return tostring(message) end)
			if not ok then warn("[Lukiho] " .. name .. ":", err) end
			task.wait(if ok then interval else math.max(interval, 1))
		end
	end)
end

local function sameValues(left: {string}, right: {string}): boolean
	if #left ~= #right then return false end
	for index, value in left do
		if right[index] ~= value then return false end
	end
	return true
end

local function hotbarHolder(): Instance?
	local playerGui = player:FindFirstChild("PlayerGui")
	local components = playerGui and playerGui:FindFirstChild("ComponentsHolder")
	local bottom = components and components:FindFirstChild("BottomHolder")
	local toolbar = bottom and bottom:FindFirstChild("Toolbar")
	return toolbar and toolbar:FindFirstChild("SkillHolder")
end

local iconNames: {[string]: string} = {}
local indexedItems = false
local function refreshItemCatalog()
	if indexedItems then return end
	if not items then items = requirePath(ReplicatedStorage, { "CAM", "Global", "Collectibles", "Items" }) end
	if type(items) ~= "table" then return end
	indexedItems = true
	for itemName, data in items do
		if type(itemName) == "string" and type(data) == "table" then
			for _, key in { "Icon", "Image", "ItemIcon", "IconId", "ImageId", "Thumbnail" } do
				local image = data[key]
				if type(image) == "string" or type(image) == "number" then
					local id = tostring(image):match("%d+")
					if id then iconNames[id] = itemName end
				end
			end
		end
	end
end

local function toolInSlot(index: number): string?
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local containers: {Instance} = {}
	if character then table.insert(containers, character) end
	if backpack then table.insert(containers, backpack) end
	for _, container in containers do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") then
					for _, key in { "HotbarSlot", "ToolbarSlot", "SlotIndex", "Slot" } do
						local number = tostring(tool:GetAttribute(key)):match("%d+")
						if tonumber(number) == index then return tool.Name end
					end
				end
			end
		end
	end
	return nil
end

local function itemNameAttribute(instance: Instance): string?
	for _, key in { "ItemName", "ToolName", "DisplayName", "ItemId" } do
		local value = instance:GetAttribute(key)
		if (type(value) == "string" and value ~= "") or type(value) == "number" then
			local item = if type(items) == "table" then items[value] else nil
			return if type(item) == "table" and type(item.Name) == "string" then item.Name else tostring(value)
		end
	end
	return nil
end

local function slotItemName(slot: Instance, index: number): (string?, boolean)
	local attributed = itemNameAttribute(slot)
	if attributed then return attributed, true end
	local tool = toolInSlot(index)
	if tool then return tool, true end
	local hasIcon = false
	for _, child in slot:GetDescendants() do
		attributed = itemNameAttribute(child)
		if attributed then return attributed, true end
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			local value = child.Text:match("^%s*(.-)%s*$")
			if value and value ~= "" and not value:match("^%d+$") and not value:match("^[xX]%d+$")
				and not value:match("^Lv%s*%d+") and value ~= "Equip" and value ~= "Unequip"
				and not table.find({ "Key", "Keybind", "Hotkey", "Stack", "Count" }, child.Name) then
				return value, true
			end
		elseif (child:IsA("ImageLabel") or child:IsA("ImageButton")) and child.Visible and child.Name ~= "CircleSelect" and child.Image ~= "" then
			hasIcon = true
			local id = child.Image:match("%d+")
			if id and iconNames[id] then return iconNames[id], true end
		end
	end
	if hasIcon and characterInfo and type(characterInfo.Get_equipped_tool) == "function" then
		local selected = slot:FindFirstChild("CircleSelect")
		if selected and selected:IsA("ImageLabel") and selected.ImageTransparency < 0.72 then
			local ok, equipped = pcall(characterInfo.Get_equipped_tool, player)
			if ok and typeof(equipped) == "Instance" then return equipped.Name, true end
		end
	end
	return nil, hasIcon
end

local function scanHotbar(): ({string}, {[string]: number})
	refreshItemCatalog()
	if not characterInfo then characterInfo = requirePath(ReplicatedStorage, { "CAM", "Global", "Character_info_provider" }) end
	local holder = hotbarHolder()
	local names: {string} = {}
	local slots: {[string]: number} = {}
	if holder then
		for index = 1, 5 do
			local slot = holder:FindFirstChild(index .. "_ToolPosition")
			if slot then
				local name, occupied = slotItemName(slot, index)
				if occupied then
					local label = string.format("%d - %s", index, name or "Name unavailable")
					table.insert(names, label)
					slots[label] = index
				end
			end
		end
	end
	if #names == 0 then table.insert(names, "Hotbar not detected") end
	return names, slots
end

supervise("npc catalog", 2, function()
	local nextMobs, nextBosses = scanNpcCatalog()
	if not sameValues(mobNames, nextMobs) then
		mobNames = nextMobs
		if State.selectedMob and not table.find(mobNames, State.selectedMob) then State.selectedMob = nil end
		if mobDropdown then
			mobDropdown:SetValues(mobNames)
		end
	end
	if not sameValues(bossNames, nextBosses) then
		bossNames = nextBosses
		if State.selectedBoss and not table.find(bossNames, State.selectedBoss) then State.selectedBoss = nil end
		if bossDropdown then
			bossDropdown:SetValues(bossNames)
		end
	end
end)

supervise("hotbar catalog", 2, function()
	local nextNames, nextSlots = scanHotbar()
	if sameValues(weaponNames, nextNames) then return end
	local selectedIndex = State.weaponSlot
	weaponNames, weaponSlots = nextNames, nextSlots
	local selectedLabel: string? = nil
	if selectedIndex then
		for label, index in weaponSlots do
			if index == selectedIndex then selectedLabel = label; break end
		end
	end
	State.weaponSlot = if selectedLabel then selectedIndex else nil
	if weaponDropdown then
		weaponDropdown:SetValues(weaponNames)
		weaponDropdown:SetValue(selectedLabel)
	end
end)

local function selectedChest(): Instance?
	local folder = Workspace:FindFirstChild("Chests")
	local _, _, root = getCharacter()
	if not folder or not root then return nil end
	local closest: Instance? = nil
	local distance = math.huge
	for _, chest in folder:GetChildren() do
		if chest:GetAttribute("IsOpen") ~= true and
			(State.selectedTier == "All" or tostring(chest:GetAttribute("Tier") or chest.Name):lower():find(State.selectedTier:lower(), 1, true)) then
			local position = if chest:IsA("Model") then chest:GetPivot().Position elseif chest:IsA("BasePart") then chest.Position else nil
			if position then
				local current = (position - root.Position).Magnitude
				if current < distance then closest, distance = chest, current end
			end
		end
	end
	return closest
end

local function chestGuard(chest: Instance): (Model?, Humanoid?, BasePart?)
	local folder = Workspace:FindFirstChild("Humanoids")
	local position = if chest:IsA("Model") then chest:GetPivot().Position elseif chest:IsA("BasePart") then chest.Position else nil
	if not folder or not position then return nil, nil, nil end
	local best: Model? = nil
	local bestHum: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local distance = 55
	for _, item in folder:GetDescendants() do
		if item:IsA("Model") then
			local hum, root = candidate(item)
			if hum and root then
				local linked = item:GetAttribute("GuardChest") == chest.Name
				local current = (root.Position - position).Magnitude
				if (linked or current <= distance) and current < distance then
					best, bestHum, bestRoot, distance = item, hum, root, current
				end
			end
		end
	end
	return best, bestHum, bestRoot
end

local function patrolBoss()
	if not State.selectedBoss then return end
	if State.travelDestination then return end
	if os.clock() - State.lastPatrol < State.patrolInterval then return end
	local folder = Workspace:FindFirstChild("BossSpawns")
	local choices: {Vector3} = {}
	local mapped: {[string]: boolean} = {}
	if folder then
		for _, marker in folder:GetChildren() do
			if State.selectedBoss == "All" or marker.Name == State.selectedBoss then
				mapped[marker.Name] = true
				if marker:IsA("BasePart") then
					table.insert(choices, marker.Position)
				elseif marker:IsA("Attachment") then
					table.insert(choices, marker.WorldPosition)
				elseif marker:IsA("Model") then
					table.insert(choices, marker:GetPivot().Position)
				end
			end
		end
	end
	for name, position in bossSpawnPositions do
		if not mapped[name] and (State.selectedBoss == "All" or name == State.selectedBoss) then
			table.insert(choices, position)
		end
	end
	if #choices == 0 then return end
	State.patrolIndex = (State.patrolIndex % #choices) + 1
	State.travelDestination = choices[State.patrolIndex] + Vector3.new(0, 5, 0)
end

local function attackCombo()
	if State.manualTravel or not input or not live() or not activeTarget() or os.clock() < State.dodgingUntil then return end
	local _, _, playerRoot = getCharacter()
	local targetRoot = State.targetRoot
	if not playerRoot or not targetRoot or (playerRoot.Position - targetRoot.Position).Magnitude > math.max(14, State.attackOffset + 9) then
		return
	end
	ensureWeapon()
	for hit = 1, 5 do
		if State.manualTravel or not State.running or not activeTarget() or not (State.autoFarm or State.autoBoss or State.autoChestFarm) then break end
		if os.clock() < State.dodgingUntil then break end
		press("Combat", 0.05)
		State.comboCount = readCombo()
		if hit < 5 then task.wait(State.comboDelay) end
	end
	task.wait(0.45)
end

supervise("target", 0.35, function()
	if not live() or not (State.autoFarm or State.autoBoss or State.autoChestFarm or State.manualTravel) then
		clearTarget()
		State.chestTarget = nil
		State.travelDestination = nil
		State.manualTravel = false
		return
	end
	if activeTarget() then return end
	if State.manualTravel then
		if State.travelDestination then return end
		State.manualTravel = false
		clearTarget()
		return
	end
	if State.targetHumanoid and State.targetHumanoid.Health <= 0 then
		State.postKillUntil = os.clock() + 3
	end
	clearTarget()
	if not State.autoChestFarm and os.clock() < State.postKillUntil then return end
	if State.autoChestFarm then
		local chest = selectedChest()
		State.chestTarget = chest
		if chest and chest:GetAttribute("Locked") == true then
			local guard, guardHum, guardRoot = chestGuard(chest)
			if guard and guardHum and guardRoot then
				setTarget(guard, guardHum, guardRoot)
			end
		end
		return
	end
	local model, humanoid, root = nearestNpc(State.autoBoss)
	if model and humanoid and root then
		State.travelDestination = nil
		setTarget(model, humanoid, root)
	elseif State.autoBoss then
		patrolBoss()
	end
end)

supervise("combat", 0.12, function()
	if not State.manualTravel and not State.holdSkill and (State.autoFarm or State.autoBoss or State.autoChestFarm) then
		attackCombo()
	end
end)

supervise("skills", 0.15, function()
	if State.manualTravel then releaseHold(); return end
	if not input or not live() then releaseHold(); return end
	if not activeTarget() or not (State.autoFarm or State.autoBoss or State.autoChestFarm) then releaseHold(); return end
	if State.holdSkill then
		local action, name = skillAction(State.selectedSkill)
		if heldAction ~= action then releaseHold() end
		if heldAction and type(input.IsDown) == "function" then
			local ok, down = pcall(input.IsDown, action)
			if ok and not down then heldAction = nil end
		end
		if not heldAction and skillReady(name) then
			local ok = pcall(function() input.VirtualPress(action) end)
			if ok then heldAction = action end
		end
		return
	end
	releaseHold()
	if State.autoSkills and os.clock() - State.lastSkill > 1 then
		for _, key in { "Z", "X", "C", "V", "B" } do
			if State.selectedSkills[key] then
				local action, name = skillAction(key)
				if skillReady(name) then
					State.lastSkill = os.clock()
					press(action, 0.05)
					break
				end
			end
		end
	end
end)

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then return parent.Position end
	if parent and parent:IsA("Attachment") then return parent.WorldPosition end
	if parent and parent:IsA("Model") then return parent:GetPivot().Position end
	return nil
end

local function usePrompt(prompt: ProximityPrompt, maxDistance: number)
	local _, _, root = getCharacter()
	local position = promptPosition(prompt)
	if not root or not position or not prompt.Enabled or (position - root.Position).Magnitude > maxDistance then return end
	local trigger = (global :: any).fireproximityprompt
	if type(trigger) == "function" then
		pcall(trigger, prompt)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.05)
			prompt:InputHoldEnd()
		end)
	end
end

local function tierMatches(chest: Instance): boolean
	if State.selectedTier == "All" then return true end
	local tier = tostring(chest:GetAttribute("Tier") or chest:GetAttribute("ChestId") or chest.Name)
	return tier:lower():find(State.selectedTier:lower(), 1, true) ~= nil
end

supervise("loot", 0.6, function()
	if not live() or not (State.autoLoot or State.autoChest or State.autoChestFarm or os.clock() < State.postKillUntil) then return end
	local drops = Workspace:FindFirstChild("LootDrops")
	if drops and (State.autoLoot or os.clock() < State.postKillUntil) then
		for _, item in drops:GetDescendants() do
			if item:IsA("ProximityPrompt") then usePrompt(item, State.lootRadius) end
		end
	end
	local chests = Workspace:FindFirstChild("Chests")
	if chests and (State.autoChest or State.autoChestFarm) then
		for _, chest in chests:GetChildren() do
			if tierMatches(chest) and chest:GetAttribute("IsOpen") ~= true then
				local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
				if State.autoChestFarm and chest == State.chestTarget and chest:GetAttribute("Locked") ~= true then
					if prompt then
						local position = promptPosition(prompt)
						if position then State.travelDestination = position + Vector3.new(0, 3, 0) end
					end
				end
				if prompt and chest:GetAttribute("Locked") ~= true then
					usePrompt(prompt, if State.autoChestFarm then 8 else State.lootRadius)
				end
			end
		end
	end
end)

connect(RunService.Heartbeat, function(dt: number)
	if not live() then return end
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then return end
	local automationMoving = activeTarget() and (State.autoFarm or State.autoBoss or State.autoChestFarm or State.manualTravel)
	local destination: CFrame? = nil
	if automationMoving then
		local targetRoot = State.targetRoot :: BasePart
		local targetFrame = targetRoot.CFrame
		local height = if os.clock() < State.dodgingUntil then State.dodgeHeight else State.attackHeight
		local position = (targetFrame * CFrame.new(0, height, State.attackOffset)).Position
		destination = CFrame.lookAt(position, targetFrame.Position)
	elseif State.travelDestination and (State.autoBoss or State.autoChestFarm or State.manualTravel) then
		local travel = State.travelDestination :: Vector3
		destination = CFrame.lookAt(travel, travel + root.CFrame.LookVector)
	end
	if destination then
		local delta = destination.Position - root.Position
		local distance = delta.Magnitude
		local step = math.min(distance, State.trackSpeed * dt)
		local nextPosition = if distance > 0.01 then root.Position + delta.Unit * step else destination.Position
		local rotation = destination.Rotation
		root.CFrame = CFrame.new(nextPosition) * rotation
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if State.manualTravel and distance <= 2 then
			State.manualTravel = false
			clearTarget()
		end
		if State.travelDestination and not automationMoving and distance <= 2 then
			State.travelDestination = nil
			State.manualTravel = false
			State.lastPatrol = os.clock()
		end
	end
	local autoNoClip = destination ~= nil
	if State.noclip or autoNoClip then
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				if collisionStates[part] == nil then collisionStates[part] = part.CanCollide end
				part.CanCollide = false
			end
		end
	elseif next(collisionStates) then
		for part, canCollide in collisionStates do
			if part.Parent then part.CanCollide = canCollide end
		end
		table.clear(collisionStates)
	end
	if State.fly then
		if not flyVelocity or flyVelocity.Parent ~= root then
			if flyVelocity then flyVelocity:Destroy() end
			flyVelocity = Instance.new("BodyVelocity")
			flyVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
			flyVelocity.Parent = root
		end
		local camera = Workspace.CurrentCamera
		local vertical = (if UserInputService:IsKeyDown(Enum.KeyCode.Space) then 1 else 0)
			- (if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then 1 else 0)
		flyVelocity.Velocity = humanoid.MoveDirection * State.flySpeed + Vector3.new(0, vertical * State.flySpeed, 0)
		if camera then root.CFrame = CFrame.lookAt(root.Position, root.Position + camera.CFrame.LookVector) end
	elseif flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end
	if State.speed and not State.fly then
		if speedBaseline[humanoid] == nil then speedBaseline[humanoid] = humanoid.WalkSpeed end
		humanoid.WalkSpeed = State.speedValue
	elseif speedBaseline[humanoid] ~= nil then
		humanoid.WalkSpeed = speedBaseline[humanoid]
		speedBaseline[humanoid] = nil
	end
	if State.cframeSpeed and not State.fly then
		root.CFrame += humanoid.MoveDirection * State.cframeMultiplier * dt * 16
	end
end)

connect(UserInputService.JumpRequest, function()
	if not State.infiniteJump or not live() then return end
	local _, humanoid, root = getCharacter()
	if humanoid and root then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, State.jumpBoost, root.AssemblyLinearVelocity.Z)
	end
end)

local function unload()
	if not State.running then return end
	State.running = false
	releaseHold()
	release("Combat")
	clearTarget()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for part, value in collisionStates do
		if part.Parent then part.CanCollide = value end
	end
	table.clear(collisionStates)
	for humanoid, value in speedBaseline do
		if humanoid.Parent then humanoid.WalkSpeed = value end
	end
	table.clear(speedBaseline)
	if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
	if library then pcall(function() library:Unload() end) end
	if global.LukihoHubUnload == unload then global.LukihoHubUnload = nil end
end
global.LukihoHubUnload = unload

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local function loadRemote(path: string): any
	local source = (game :: any):HttpGet(repo .. path)
	local compiler = (global :: any).loadstring or loadstring
	local chunk = compiler(source)
	if not chunk then error("Unable to compile Obsidian " .. path) end
	return chunk()
end

mobNames, bossNames = scanNpcCatalog()
weaponNames, weaponSlots = scanHotbar()

local loaded, failure = xpcall(function()
	library = loadRemote("Library.lua")
	local theme: any = loadRemote("addons/ThemeManager.lua")
	local saves: any = loadRemote("addons/SaveManager.lua")
	library.ForceCheckbox = false
	local window = library:CreateWindow({ Title = "Lukiho", Footer = "Created by Lukiho", NotifySide = "Right" })
	local tabs = {
		Farm = window:AddTab("Farm", "swords"),
		Movement = window:AddTab("Movement", "navigation"),
		Loot = window:AddTab("Chests & Loot", "package"),
		Settings = window:AddTab("UI Settings", "settings"),
	}
	local farm = tabs.Farm:AddGroupbox({ Side = "Left", Name = "Mob Farming", IconName = "swords" })
	farm:AddToggle("LukihoAutoFarm", { Text = "Auto Farm Mobs", Default = false, Callback = function(value: boolean)
		State.autoFarm = value
		if value then
			State.autoBoss = false
			local other = library.Toggles.LukihoBoss
			if other and other.Value then other:SetValue(false) end
		end
	end })
	mobDropdown = farm:AddDropdown("LukihoMobFilter", {
		Text = "Select Mob",
		Values = mobNames,
		AllowNull = true,
		Searchable = true,
		Callback = function(value: string?)
			State.selectedMob = value
			State.manualTravel = false
			State.travelDestination = nil
			clearTarget()
		end,
	})
	farm:AddButton({ Text = "Travel to Selected Mob", Func = function() travelToSelected(false) end })
	farm:AddSlider("LukihoRadius", { Text = "Search Radius", Min = 50, Max = 5000, Default = 1000, Rounding = 0, Callback = function(value: number) State.searchRadius = value end })
	farm:AddSlider("LukihoOffset", { Text = "Behind Target", Min = 0, Max = 20, Default = 4.5, Rounding = 1, Callback = function(value: number) State.attackOffset = value end })
	farm:AddSlider("LukihoHeight", { Text = "Attack Height", Min = -20, Max = 20, Default = -6, Rounding = 1, Callback = function(value: number) State.attackHeight = value end })
	farm:AddSlider("LukihoDodge", { Text = "Dodge Height", Min = 0, Max = 50, Default = 22, Rounding = 0, Callback = function(value: number) State.dodgeHeight = value end })
	farm:AddSlider("LukihoTrack", { Text = "NoClip Travel Speed", Min = 20, Max = 1000, Default = 180, Rounding = 0, Suffix = " studs/s", Callback = function(value: number) State.trackSpeed = value end })
	local combat = tabs.Farm:AddGroupbox({ Side = "Right", Name = "Combat & Skills", IconName = "zap" })
	weaponDropdown = combat:AddDropdown("LukihoWeapon", {
		Text = "Hotbar Item",
		Values = weaponNames,
		AllowNull = true,
		Searchable = true,
		Callback = function(value: string?)
			State.weaponSlot = if value then weaponSlots[value] else nil
		end,
	})
	combat:AddSlider("LukihoCombo", { Text = "Combo Interval", Min = 0.2, Max = 0.5, Default = 0.28, Rounding = 2, Callback = function(value: number) State.comboDelay = value end })
	combat:AddToggle("LukihoSkills", { Text = "Auto Cast Ready Skills", Default = false, Callback = function(value: boolean) State.autoSkills = value end })
	combat:AddDropdown("LukihoSkillKeys", { Text = "Auto Skill Keys", Values = { "Z", "X", "C", "V", "B" }, Multi = true, Default = { "Z", "X", "C", "V", "B" }, Callback = function(value: {[string]: boolean}) State.selectedSkills = value end })
	combat:AddToggle("LukihoHold", { Text = "Hold Skill", Default = false, Callback = function(value: boolean) State.holdSkill = value; if not value then releaseHold() end end })
	combat:AddDropdown("LukihoHeldKey", { Text = "Held Skill", Values = { "Z", "X", "C", "V", "B" }, Default = 1, Callback = function(value: string) releaseHold(); State.selectedSkill = value end })
	local bosses = tabs.Farm:AddGroupbox({ Side = "Right", Name = "Bosses", IconName = "skull" })
	bosses:AddToggle("LukihoBoss", { Text = "Farm Registered Bosses", Default = false, Callback = function(value: boolean)
		State.autoBoss = value
		if value then
			State.autoFarm = false
			local other = library.Toggles.LukihoAutoFarm
			if other and other.Value then other:SetValue(false) end
		end
	end })
	bossDropdown = bosses:AddDropdown("LukihoBossFilter", {
		Text = "Select Boss",
		Values = bossNames,
		AllowNull = true,
		Searchable = true,
		Callback = function(value: string?)
			State.selectedBoss = value
			State.manualTravel = false
			clearTarget()
			State.travelDestination = nil
		end,
	})
	bosses:AddButton({ Text = "Travel to Selected Boss", Func = function() travelToSelected(true) end })
	bosses:AddSlider("LukihoPatrol", { Text = "Patrol Interval", Min = 0.5, Max = 5, Default = 2, Rounding = 1, Callback = function(value: number) State.patrolInterval = value end })
	local movement = tabs.Movement:AddGroupbox({ Side = "Left", Name = "Movement", IconName = "navigation" })
	local fly = movement:AddToggle("LukihoFly", { Text = "Fly", Default = false, Callback = function(value: boolean) State.fly = value end })
	fly:AddKeyPicker("LukihoFlyKey", { Text = "Fly", Default = "F", SyncToggleState = true })
	movement:AddSlider("LukihoFlySpeed", { Text = "Fly Speed", Min = 10, Max = 450, Default = 80, Rounding = 0, Callback = function(value: number) State.flySpeed = value end })
	local clip = movement:AddToggle("LukihoClip", { Text = "NoClip", Default = false, Callback = function(value: boolean) State.noclip = value end })
	clip:AddKeyPicker("LukihoClipKey", { Text = "NoClip", Default = "N", SyncToggleState = true })
	local speed = tabs.Movement:AddGroupbox({ Side = "Right", Name = "Speed & Jump", IconName = "zap" })
	speed:AddToggle("LukihoSpeed", { Text = "Custom Walk Speed", Default = false, Callback = function(value: boolean) State.speed = value end })
	speed:AddSlider("LukihoSpeedValue", { Text = "Walk Speed", Min = 16, Max = 200, Default = 32, Rounding = 0, Callback = function(value: number) State.speedValue = value end })
	speed:AddToggle("LukihoCFrame", { Text = "CFrame Speed", Default = false, Callback = function(value: boolean) State.cframeSpeed = value end })
	speed:AddSlider("LukihoCFrameValue", { Text = "CFrame Multiplier", Min = 1, Max = 20, Default = 1, Rounding = 1, Callback = function(value: number) State.cframeMultiplier = value end })
	speed:AddToggle("LukihoJump", { Text = "Infinite Jump", Default = false, Callback = function(value: boolean) State.infiniteJump = value end })
	speed:AddSlider("LukihoJumpValue", { Text = "Jump Boost", Min = 25, Max = 200, Default = 50, Rounding = 0, Callback = function(value: number) State.jumpBoost = value end })
	local loot = tabs.Loot:AddGroupbox({ Side = "Left", Name = "Chests & Drops", IconName = "package" })
	loot:AddToggle("LukihoOpenChest", { Text = "Open Nearby Chests", Default = false, Callback = function(value: boolean) State.autoChest = value end })
	loot:AddToggle("LukihoCollect", { Text = "Collect Nearby Drops", Default = false, Callback = function(value: boolean) State.autoLoot = value end })
	loot:AddToggle("LukihoFarmChest", { Text = "Farm Chest Guards", Default = false, Callback = function(value: boolean) State.autoChestFarm = value end })
	loot:AddDropdown("LukihoTier", { Text = "Chest Tier", Values = { "All", "Common", "Rare", "T1", "T2", "T3", "T4", "T5" }, Default = 1, Callback = function(value: string) State.selectedTier = value end })
	loot:AddSlider("LukihoLootRadius", { Text = "Loot Radius", Min = 10, Max = 100, Default = 40, Rounding = 0, Callback = function(value: number) State.lootRadius = value end })
	local settings = tabs.Settings:AddGroupbox({ Side = "Left", Name = "Interface", IconName = "settings" })
	settings:AddLabel("Created by Lukiho")
	settings:AddLabel("RightControl toggles this menu")
	settings:AddLabel("Cooldowns remain server-authoritative")
	settings:AddLabel("Menu Keybind"):AddKeyPicker("LukihoMenuKey", { Default = "RightControl", NoUI = true, Text = "Menu", Mode = "Toggle" })
	library.ToggleKeybind = library.Options.LukihoMenuKey
	settings:AddButton({ Text = "Unload Hub", Func = unload })
	theme:SetLibrary(library)
	saves:SetLibrary(library)
	saves:IgnoreThemeSettings()
	saves:SetIgnoreIndexes({ "LukihoMenuKey" })
	theme:SetFolder("LukihoHub")
	saves:SetFolder("LukihoHub/configs")
	saves:BuildConfigSection(tabs.Settings)
	theme:ApplyToTab(tabs.Settings)
	saves:LoadAutoloadConfig()
end, function(message) return tostring(message) end)

if not loaded then
	warn("[Lukiho] UI failed:", failure)
	unload()
end
