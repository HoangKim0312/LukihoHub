--!strict
-- Lukiho Automation Console. Run only in an experience you own and can test.
-- Game-specific module paths below are taken from the supplied reference script.

local HUB_VERSION = "1.6.0"

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
global.LukihoHubVersion = HUB_VERSION
print("[Lukiho] Hub version:", HUB_VERSION)

type Connection = RBXScriptConnection
type StateType = {
	running: boolean,
	autoFarm: boolean,
	autoBoss: boolean,
	autoChestFarm: boolean,
	autoChest: boolean,
	autoLoot: boolean,
	autoLevel: boolean,
	autoSkills: boolean,
	holdSkill: boolean,
	holdSkillKeys: {[string]: boolean},
	selectedSkills: {[string]: boolean},
	espEnabled: boolean,
	espRadius: number,
	espMobs: boolean,
	espBosses: boolean,
	espQuests: boolean,
	espInteractables: boolean,
	selectedMob: string?,
	selectedBoss: string?,
	selectedArea: string?,
	selectedTravelTarget: string?,
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
	levelTarget: string?,
	questGiver: Instance?,
	questStatus: string,
	lootPrompt: ProximityPrompt?,
}

local State: StateType = {
	running = true,
	autoFarm = false,
	autoBoss = false,
	autoChestFarm = false,
	autoChest = false,
	autoLoot = false,
	autoLevel = false,
	autoSkills = false,
	holdSkill = false,
	holdSkillKeys = {},
	selectedSkills = {},
	espEnabled = false,
	espRadius = 10000,
	espMobs = true,
	espBosses = true,
	espQuests = true,
	espInteractables = true,
	selectedMob = nil,
	selectedBoss = nil,
	selectedArea = nil,
	selectedTravelTarget = nil,
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
	levelTarget = nil,
	questGiver = nil,
	questStatus = "Idle",
	lootPrompt = nil,
}

local connections: {Connection} = {}
local collisionStates: {[BasePart]: boolean} = {}
local targetAnimationConnection: Connection? = nil
local stoppedConnections: {Connection} = {}
local flyVelocity: BodyVelocity? = nil
local library: any = nil
local heldActions: {[string]: string} = {}
local skillCursor = 0
local lastEquip = 0
local equipReadyAt = 0
local assumedWeaponSlot: number? = nil
local weaponAutomationActive = false
local updatingWeaponDropdown = false
local weaponNameCache: {[number]: string} = {}
local speedBaseline: {[Humanoid]: number} = {}
local mobDropdown: any = nil
local bossDropdown: any = nil
local weaponDropdown: any = nil
local areaDropdown: any = nil
local travelTargetDropdown: any = nil
local mobNames = { "All" }
local bossNames = { "All" }
local areaNames = { "No areas detected" }
local travelTargetNames = { "No NPCs or mobs detected" }
local weaponNames: {string} = {}
local weaponSlots: {[string]: number} = {}
local observedMobs: {[string]: boolean} = {}
local observedBosses: {[string]: boolean} = {}
local registeredBosses: {[string]: boolean} = {}
local bossSpawnPositions: {[string]: Vector3} = {}
local npcSpawnPositions: {[string]: Vector3} = {}
local areaPositions: {[string]: Vector3} = {}
type TravelEntry = {
	name: string,
	instance: Instance?,
	position: Vector3?,
	bossOnly: boolean?,
	enemy: boolean,
}
local travelTargets: {[string]: TravelEntry} = {}
local questStatusLabel: any = nil
local trackedPrompts: {[ProximityPrompt]: boolean} = {}

local function connect(signal: RBXScriptSignal, callback: (...any) -> ()): Connection
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

for _, instance in Workspace:GetDescendants() do
	if instance:IsA("ProximityPrompt") then trackedPrompts[instance] = true end
end
connect(Workspace.DescendantAdded, function(instance)
	if instance:IsA("ProximityPrompt") then trackedPrompts[instance] = true end
end)
connect(Workspace.DescendantRemoving, function(instance)
	if instance:IsA("ProximityPrompt") then trackedPrompts[instance] = nil end
end)

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

local function refreshInputHandler(): boolean
	if not input or type(input.VirtualPress) ~= "function" or type(input.VirtualRelease) ~= "function" then
		input = requirePath(ReplicatedStorage, { "CAM", "Client", "Components", "Client", "InputHandler" })
	end
	return input ~= nil and type(input.VirtualPress) == "function" and type(input.VirtualRelease) == "function"
end

local function press(action: string, duration: number): boolean
	if not refreshInputHandler() then return false end
	local ok, err = pcall(function()
		input.VirtualPress(action)
		task.wait(duration)
		input.VirtualRelease(action)
	end)
	if not ok then warn("[Lukiho] Input action failed:", action, err) end
	return ok
end

local function release(action: string)
	if refreshInputHandler() then pcall(function() input.VirtualRelease(action) end) end
end

local function skillAction(key: string): (string, string?)
	local fallback = { Z = "Skills_2nd", X = "Skills_3rd", C = "Skills_4th", V = "Skills_5th", B = "Skills_6th" }
	if not skillsProvider then
		skillsProvider = requirePath(ReplicatedStorage, { "CAM", "Client", "Controllers", "Skills_Provider" })
	end
	if skillsProvider and type(skillsProvider.get_current_keys) == "function" then
		local ok, entries = pcall(skillsProvider.get_current_keys)
		if not ok then ok, entries = pcall(skillsProvider.get_current_keys, skillsProvider) end
		if ok and type(entries) == "table" then
			local ordinals = { "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th" }
			for index, entry in entries do
				if type(entry) == "table" then
					local rawKey = tostring(entry.Key or entry.KeyCode or entry.Bind or entry.Hotkey or ""):upper()
					local entryKey = rawKey:match("([A-Z])$") or rawKey
					if entryKey == key then
						local name = entry.Name or entry.SkillName or entry.Skill
						local action = if type(index) == "number" then "Skills_" .. (ordinals[index] or tostring(index)) else fallback[key]
						return action or fallback.Z, if type(name) == "string" then name else nil
					end
				end
			end
		end
	end
	return fallback[key] or fallback.Z, nil
end

local function skillReady(skillName: string?): boolean
	local character = player.Character
	if not character then return false end
	local status = character and character:FindFirstChild("SHC")
	if not skillName or not status then return true end
	if status:FindFirstChild(skillName) then return false end
	local wanted = skillName:lower():gsub("[^%w]", "")
	for _, marker in status:GetChildren() do
		if marker.Name:lower():gsub("[^%w]", "") == wanted then return false end
	end
	return true
end

local function releaseHold()
	for key, action in heldActions do
		release(action)
		heldActions[key] = nil
	end
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
	if model.Name:lower():find("boss", 1, true) then return true end
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
	if typeof(value) == "Region3" then return value.CFrame.Position end
	if type(value) ~= "string" then return nil end
	local x, y, z = value:match("([^,]+),%s*([^,]+),%s*([^,]+)")
	if not x or not y or not z then return nil end
	local px, py, pz = tonumber(x), tonumber(y), tonumber(z)
	return if px and py and pz then Vector3.new(px, py, pz) else nil
end

local function instancePosition(instance: Instance?): Vector3?
	if not instance or not instance.Parent then return nil end
	if instance:IsA("BasePart") then return instance.Position end
	if instance:IsA("Attachment") then return instance.WorldPosition end
	if instance:IsA("Model") then return instance:GetPivot().Position end
	if instance:IsA("ProximityPrompt") then return instancePosition(instance.Parent) end
	local part = instance:FindFirstChildWhichIsA("BasePart", true)
	return if part then part.Position else nil
end

local function tablePosition(value: any): Vector3?
	local direct = readPosition(value)
	if direct then return direct end
	if type(value) ~= "table" then return nil end
	for _, key in { "Position", "CFrame", "Location", "Spawn", "Point", "Center", "Coordinates", "Coords" } do
		local position = readPosition(value[key])
		if position then return position end
	end
	local minimum = readPosition(value.Min or value.Minimum)
	local maximum = readPosition(value.Max or value.Maximum)
	if minimum and maximum then return minimum:Lerp(maximum, 0.5) end
	return nil
end

local AREA_CONTAINERS: {[string]: boolean} = {
	areas = true,
	fasttravel = true,
	locations = true,
	mapmarkers = true,
	regions = true,
	regionmarkers = true,
	spawnlocations = true,
	teleportlocations = true,
	waypoints = true,
}

local AREA_MODULE_KEYS = {
	"Areas", "AreaSpawns", "FastTravel", "Locations", "MapMarkers", "Regions",
	"RegionSpawns", "TeleportLocations", "Waypoints", "WorldLocations",
}

local AREA_DATA_BLOCK_WORDS = {
	"answer", "choice", "conversation", "dialog", "objective", "option",
	"prompt", "quest", "response", "task",
}

local function validAreaName(value: any): string?
	if type(value) ~= "string" then return nil end
	local name = value:gsub("<[^>]->", ""):match("^%s*(.-)%s*$")
	if name == "" or #name > 72 or name:match("^%d+$") then return nil end
	local lower = name:lower()
	if table.find({ "misc", "other", "dialogue", "conversation", "choices", "options", "quests" }, lower) then
		return nil
	end
	if lower:find("(lv", 1, true) or lower:match("%f[%a]lvl?%.?%s*:?%s*%d")
		or lower:match("%f[%a]level%s*:?%s*%d") then return nil end
	if lower:match("^i'll%s") or lower:match("^ill%s") or lower:match("^i%s+will%s") then return nil end
	for _, prefix in { "accept ", "clear out ", "deal with ", "defeat ", "drive ", "fell ", "hunt ", "kill ", "slay ", "take " } do
		if lower:sub(1, #prefix) == prefix then return nil end
	end
	return name
end

local function areaDataBranchAllowed(key: any): boolean
	if type(key) ~= "string" then return true end
	local lower = key:lower()
	for _, word in AREA_DATA_BLOCK_WORDS do
		if lower:find(word, 1, true) then return false end
	end
	return true
end

local function scanTravelCatalog(): ({string}, {[string]: Vector3}, {string}, {[string]: TravelEntry})
	local nextAreas: {[string]: Vector3} = {}
	local nextTargets: {[string]: TravelEntry} = {}
	local function addArea(name: any, position: Vector3?)
		local validName = validAreaName(name)
		if not validName or not position then return end
		nextAreas[validName] = position
	end
	local function addTarget(label: string, entry: TravelEntry)
		if label == "" then return end
		nextTargets[label] = entry
	end

	if not regions then regions = requirePath(ReplicatedStorage, { "Regions" }) end
	if type(regions) == "table" then
		local visited: {[any]: boolean} = {}
		local function readAreaTable(node: any, depth: number)
			if type(node) ~= "table" or visited[node] or depth > 3 then return end
			visited[node] = true
			for key, value in node do
				local explicitName = if type(value) == "table" then value.AreaName or value.RegionName
					or value.LocationName or value.DisplayName or value.Name else nil
				local entryName = explicitName or (if type(key) == "string" then key else nil)
				local position = tablePosition(value)
				if position and entryName then addArea(entryName, position) end
				if type(value) == "table" and not position and areaDataBranchAllowed(key) then
					readAreaTable(value, depth + 1)
				end
			end
		end
		for _, key in AREA_MODULE_KEYS do readAreaTable(regions[key], 1) end
	end

	for _, item in Workspace:GetDescendants() do
		local parent = item.Parent
		if parent and AREA_CONTAINERS[parent.Name:lower()] then
			local displayName = item:GetAttribute("DisplayName") or item:GetAttribute("AreaName")
				or item:GetAttribute("RegionName") or item:GetAttribute("LocationName") or item.Name
			addArea(displayName, instancePosition(item))
		end
		for _, key in { "AreaName", "RegionName", "LocationName" } do
			local name = item:GetAttribute(key)
			if type(name) == "string" and name ~= "" then
				addArea(name, instancePosition(item))
				break
			end
		end
		if item:IsA("SpawnLocation") then addArea(item.Name, item.Position) end
	end
	for _, tag in { "Area", "FastTravel", "Location", "Region", "Teleport", "Waypoint" } do
		for _, item in CollectionService:GetTagged(tag) do
			local displayName = item:GetAttribute("DisplayName") or item:GetAttribute("AreaName")
				or item:GetAttribute("RegionName") or item.Name
			addArea(displayName, instancePosition(item))
		end
	end

	for _, name in mobNames do
		if name ~= "All" then
			addTarget("Mob - " .. name, {
				name = name,
				position = npcSpawnPositions[name],
				instance = nil,
				bossOnly = false,
				enemy = true,
			})
		end
	end
	for _, name in bossNames do
		if name ~= "All" then
			addTarget("Boss - " .. name, {
				name = name,
				position = bossSpawnPositions[name],
				instance = nil,
				bossOnly = true,
				enemy = true,
			})
		end
	end
	local function addFixedNpc(instance: Instance)
		local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
		local target = model or instance
		local position = instancePosition(target)
		if not position then return end
		local displayName = target:GetAttribute("DisplayName") or target:GetAttribute("NPCName") or target.Name
		if type(displayName) == "string" and displayName ~= "" then
			addTarget("NPC - " .. displayName, {
				name = displayName,
				instance = target,
				position = position,
				bossOnly = nil,
				enemy = false,
			})
		end
	end
	for prompt in trackedPrompts do
		if prompt.Parent then
			local text = (prompt.ActionText .. " " .. prompt.ObjectText):lower()
			if text:find("talk", 1, true) or text:find("chat", 1, true) or text:find("quest", 1, true)
				or text:find("shop", 1, true) or text:find("train", 1, true) then
				addFixedNpc(prompt)
			end
		end
	end
	for _, tag in { "NPC", "QuestGiver", "QuestNPC", "Merchant", "Trainer" } do
		for _, item in CollectionService:GetTagged(tag) do addFixedNpc(item) end
	end

	local nextAreaNames: {string} = {}
	for name in nextAreas do table.insert(nextAreaNames, name) end
	table.sort(nextAreaNames)
	if #nextAreaNames == 0 then table.insert(nextAreaNames, "No areas detected") end
	local nextTargetNames: {string} = {}
	for name in nextTargets do table.insert(nextTargetNames, name) end
	table.sort(nextTargetNames)
	if #nextTargetNames == 0 then table.insert(nextTargetNames, "No NPCs or mobs detected") end
	return nextAreaNames, nextAreas, nextTargetNames, nextTargets
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

local function canonicalName(value: string): string
	local result = value:lower():gsub("[^%w]", "")
	if result:sub(-1) == "s" then result = result:sub(1, -2) end
	return result
end

local function nameMatches(modelName: string, selected: string): boolean
	local modelKey = canonicalName(modelName)
	local selectedKey = canonicalName(selected)
	return modelKey == selectedKey or modelKey:find(selectedKey, 1, true) ~= nil or selectedKey:find(modelKey, 1, true) ~= nil
end

local function nearestNpc(bossOnly: boolean, targetName: string?, maxDistance: number?): (Model?, Humanoid?, BasePart?)
	local selected = targetName or (if bossOnly then State.selectedBoss else State.selectedMob)
	if not selected then return nil, nil, nil end
	local _, _, playerRoot = getCharacter()
	if not playerRoot then return nil, nil, nil end
	local best: Model? = nil
	local bestHum: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local distance = maxDistance or State.searchRadius
	local seen: {[Model]: boolean} = {}
	local function consider(model: Model)
		if seen[model] then return end
		seen[model] = true
		local boss = isBossModel(model)
		if bossOnly ~= boss then return end
		if selected ~= "All" and not nameMatches(model.Name, selected) then return end
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

local function beginManualTravel()
	State.lootPrompt = nil
	State.chestTarget = nil
	State.travelDestination = nil
	State.manualTravel = true
	clearTarget()
end

local function travelToSelected(bossOnly: boolean)
	local model, humanoid, root = nearestNpc(bossOnly, nil, math.huge)
	if not model or not humanoid or not root then
		local selectedName = if bossOnly then State.selectedBoss else State.selectedMob
		local position: Vector3? = nil
		if selectedName then
			position = if bossOnly then bossSpawnPositions[selectedName] else npcSpawnPositions[selectedName]
		end
		if position then
			beginManualTravel()
			State.travelDestination = position + Vector3.new(0, 5, 0)
			return
		end
		warn("[Lukiho] Select an active " .. (if bossOnly then "boss" else "mob") .. " or one with a known spawn position.")
		return
	end
	beginManualTravel()
	setTarget(model, humanoid, root)
end

local function travelToPosition(position: Vector3)
	beginManualTravel()
	State.travelDestination = position + Vector3.new(0, 5, 0)
end

local function travelToArea()
	local selected = State.selectedArea
	local position = selected and areaPositions[selected]
	if not position then
		warn("[Lukiho] Select a detected area before travelling.")
		return
	end
	travelToPosition(position)
end

local function travelToCatalogTarget()
	local selected = State.selectedTravelTarget
	local entry = selected and travelTargets[selected]
	if not entry then
		warn("[Lukiho] Select a detected NPC or mob before travelling.")
		return
	end
	if entry.enemy and entry.bossOnly ~= nil then
		local model, humanoid, root = nearestNpc(entry.bossOnly == true, entry.name, math.huge)
		if model and humanoid and root then
			beginManualTravel()
			setTarget(model, humanoid, root)
			return
		end
	end
	local position = instancePosition(entry.instance) or entry.position
	if position then
		travelToPosition(position)
	else
		warn("[Lukiho] The selected destination is not currently available.")
	end
end

local function cancelManualTravel()
	State.manualTravel = false
	State.travelDestination = nil
	clearTarget()
end

local TOOLBAR_ACTIONS = {
	[1] = "Toolbar_1st",
	[2] = "Toolbar_2nd",
	[3] = "Toolbar_3rd",
	[4] = "Toolbar_4th",
	[5] = "Toolbar_5th",
}

local function instanceSlot(instance: Instance?): number?
	if not instance then return nil end
	for _, key in { "HotbarSlot", "ToolbarSlot", "SlotIndex", "Slot" } do
		local number = tonumber(tostring(instance:GetAttribute(key)):match("%d+"))
		if number then return number end
	end
	return nil
end

local function characterEquippedSlot(): number?
	local character = player.Character
	if not character then return nil end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local slot = instanceSlot(child)
			if slot then return slot end
		end
	end
	return nil
end

local function providerEquippedSlot(): number?
	if not characterInfo or type(characterInfo.Get_equipped_tool) ~= "function" then return nil end
	local ok, equipped = pcall(characterInfo.Get_equipped_tool, player)
	if not ok then ok, equipped = pcall(characterInfo.Get_equipped_tool, characterInfo, player) end
	if not ok then return nil end
	if typeof(equipped) == "Instance" then
		local slot = instanceSlot(equipped)
		if slot then return slot end
		for index, name in weaponNameCache do
			if name:lower():gsub("[^%w]", "") == equipped.Name:lower():gsub("[^%w]", "") then return index end
		end
	elseif type(equipped) == "string" then
		for index, name in weaponNameCache do
			if name:lower():gsub("[^%w]", "") == equipped:lower():gsub("[^%w]", "") then return index end
		end
	end
	return nil
end

local function uiSelectedHotbarSlot(): number?
	local toolbar = player:FindFirstChild("PlayerGui")
	local holder = toolbar and toolbar:FindFirstChild("ComponentsHolder")
	local bottom = holder and holder:FindFirstChild("BottomHolder")
	local bar = bottom and bottom:FindFirstChild("Toolbar")
	local skills = bar and bar:FindFirstChild("SkillHolder")
	if not skills then return nil end
	for index = 1, 5 do
		local slot = skills:FindFirstChild(tostring(index) .. "_ToolPosition")
		local selection = slot and slot:FindFirstChild("CircleSelect")
		if selection and (selection:IsA("ImageLabel") or selection:IsA("ImageButton"))
			and selection.Visible and selection.ImageTransparency < 0.72 then
			return index
		end
	end
	return nil
end

local function hotbarSlotSelected(index: number): boolean?
	if assumedWeaponSlot == index and os.clock() - lastEquip < 4 then return true end
	local equipped = characterEquippedSlot() or providerEquippedSlot()
	if equipped then
		if equipped == index then assumedWeaponSlot = index end
		return equipped == index
	end
	if assumedWeaponSlot == index then return true end
	local selected = uiSelectedHotbarSlot()
	return if selected then selected == index else nil
end

local function equipWeaponSlot(index: number, force: boolean?): boolean
	local action = TOOLBAR_ACTIONS[index]
	if not action or not refreshInputHandler() then return false end
	local selected = hotbarSlotSelected(index)
	if selected == true then return true end
	if selected == nil and not force then return false end
	if os.clock() - lastEquip < 0.8 then return false end
	lastEquip = os.clock()
	assumedWeaponSlot = index
	press(action, 0.06)
	return true
end

local function ensureWeapon()
	local selectedSlot = State.weaponSlot
	if selectedSlot then equipWeaponSlot(selectedSlot, false) end
end

local function weaponReadyForCombat(): boolean
	local selectedSlot = State.weaponSlot
	if not selectedSlot then return true end
	if os.clock() < equipReadyAt then return false end
	ensureWeapon()
	return hotbarSlotSelected(selectedSlot) == true
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
			if not ok then ok, equipped = pcall(characterInfo.Get_equipped_tool, characterInfo, player) end
			if ok and typeof(equipped) == "Instance" then return equipped.Name, true end
			if ok and type(equipped) == "string" and equipped ~= "" then return equipped, true end
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
	for index = 1, 5 do
		local slot = holder and holder:FindFirstChild(index .. "_ToolPosition")
		local name = if slot then select(1, slotItemName(slot, index)) else nil
		if name then weaponNameCache[index] = name end
		local stableName = name or weaponNameCache[index]
		local label = if stableName then string.format("%d - %s", index, stableName) else tostring(index)
		table.insert(names, label)
		slots[label] = index
	end
	return names, slots
end

local function refreshHotbarCatalog()
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
	if weaponDropdown then
		updatingWeaponDropdown = true
		local ok, err = pcall(function()
			weaponDropdown:SetValues(weaponNames)
			weaponDropdown:SetValue(selectedLabel)
		end)
		updatingWeaponDropdown = false
		if not ok then error(err) end
	end
end

connect(player.CharacterRemoving, function()
	releaseHold()
	clearTarget()
	assumedWeaponSlot = nil
	weaponAutomationActive = false
end)

connect(player.CharacterAdded, function()
	releaseHold()
	clearTarget()
	for part, canCollide in collisionStates do
		if part.Parent then part.CanCollide = canCollide end
	end
	table.clear(collisionStates)
	table.clear(speedBaseline)
	assumedWeaponSlot = nil
	weaponAutomationActive = false
	lastEquip = 0
	State.lastSkill = 0
	skillCursor = 0
	equipReadyAt = os.clock() + 1.5
	task.spawn(function()
		for _ = 1, 40 do
			if not State.running then return end
			if hotbarHolder() then
				refreshHotbarCatalog()
				return
			end
			task.wait(0.25)
		end
	end)
end)

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

supervise("travel catalog", 5, function()
	local nextAreaNames, nextAreaPositions, nextTargetNames, nextTargets = scanTravelCatalog()
	areaPositions = nextAreaPositions
	travelTargets = nextTargets
	if not sameValues(areaNames, nextAreaNames) then
		areaNames = nextAreaNames
		if State.selectedArea and not areaPositions[State.selectedArea] then State.selectedArea = nil end
		if areaDropdown then
			areaDropdown:SetValues(areaNames)
			if not State.selectedArea then areaDropdown:SetValue(nil) end
		end
	end
	if not sameValues(travelTargetNames, nextTargetNames) then
		travelTargetNames = nextTargetNames
		if State.selectedTravelTarget and not travelTargets[State.selectedTravelTarget] then State.selectedTravelTarget = nil end
		if travelTargetDropdown then
			travelTargetDropdown:SetValues(travelTargetNames)
			if not State.selectedTravelTarget then travelTargetDropdown:SetValue(nil) end
		end
	end
end)

supervise("hotbar catalog", 2, refreshHotbarCatalog)

supervise("weapon equip", 0.75, function()
	local active = live() and os.clock() >= equipReadyAt and hotbarHolder() ~= nil and State.weaponSlot ~= nil
		and (State.autoFarm or State.autoBoss or State.autoChestFarm or State.autoLevel)
	if active and State.weaponSlot then
		if not weaponAutomationActive then
			assumedWeaponSlot = nil
			equipWeaponSlot(State.weaponSlot, true)
		else
			ensureWeapon()
		end
	elseif weaponAutomationActive then
		assumedWeaponSlot = nil
	end
	weaponAutomationActive = active
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
	if State.manualTravel or not refreshInputHandler() or not live() or not activeTarget()
		or os.clock() < State.dodgingUntil then return end
	local _, _, playerRoot = getCharacter()
	local targetRoot = State.targetRoot
	if not playerRoot or not targetRoot or (playerRoot.Position - targetRoot.Position).Magnitude > math.max(14, State.attackOffset + 9) then
		return
	end
	if not weaponReadyForCombat() then return end
	for hit = 1, 5 do
		if State.manualTravel or not State.running or not activeTarget() or not (State.autoFarm or State.autoBoss or State.autoChestFarm or State.autoLevel) then break end
		if os.clock() < State.dodgingUntil then break end
		press("Combat", 0.05)
		State.comboCount = readCombo()
		if hit < 5 then task.wait(State.comboDelay) end
	end
	task.wait(0.45)
end

supervise("target", 0.35, function()
	if not live() or not (State.autoFarm or State.autoBoss or State.autoChestFarm or State.autoLevel or State.manualTravel) then
		clearTarget()
		State.chestTarget = nil
		if not State.lootPrompt then State.travelDestination = nil end
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
	if State.autoLevel then
		local targetName = State.levelTarget
		if targetName then
			local isBossTarget = registeredBosses[targetName] == true or targetName:lower():find("boss", 1, true) ~= nil
			local model, humanoid, root = nearestNpc(isBossTarget, targetName, math.huge)
			if model and humanoid and root then
				State.travelDestination = nil
				setTarget(model, humanoid, root)
			else
				local position = if isBossTarget then bossSpawnPositions[targetName] else npcSpawnPositions[targetName]
				if position and not State.travelDestination then
					State.travelDestination = position + Vector3.new(0, 5, 0)
				end
			end
		end
		return
	end
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
	if not State.manualTravel and not State.holdSkill and (State.autoFarm or State.autoBoss or State.autoChestFarm or State.autoLevel) then
		attackCombo()
	end
end)

supervise("skills", 0.15, function()
	if State.manualTravel then releaseHold(); return end
	if not refreshInputHandler() or not live() then releaseHold(); return end
	if not activeTarget() or not (State.autoFarm or State.autoBoss or State.autoChestFarm or State.autoLevel) then releaseHold(); return end
	if not weaponReadyForCombat() then releaseHold(); return end
	if State.holdSkill then
		for key, action in heldActions do
			if not State.holdSkillKeys[key] then
				release(action)
				heldActions[key] = nil
			end
		end
		for _, key in { "Z", "X", "C", "V", "B" } do
			if State.holdSkillKeys[key] then
				local action, name = skillAction(key)
				local held = heldActions[key]
				if held and held ~= action then
					release(held)
					heldActions[key] = nil
				elseif held and type(input.IsDown) == "function" then
					local ok, down = pcall(input.IsDown, action)
					if ok and not down then heldActions[key] = nil end
				end
				if not heldActions[key] and skillReady(name) then
					local ok = pcall(function() input.VirtualPress(action) end)
					if ok then heldActions[key] = action end
				end
			end
		end
		return
	end
	releaseHold()
	if State.autoSkills and os.clock() - State.lastSkill > 1 then
		local keys = { "Z", "X", "C", "V", "B" }
		for offset = 1, #keys do
			local index = (skillCursor + offset - 1) % #keys + 1
			local key = keys[index]
			if State.selectedSkills[key] then
				local action, name = skillAction(key)
				if skillReady(name) then
					State.lastSkill = os.clock()
					skillCursor = index
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

local function questPromptGiver(prompt: ProximityPrompt): Instance
	local current = prompt.Parent
	local fallback: Model? = nil
	while current and current ~= Workspace do
		if current:IsA("Model") then
			if not fallback then fallback = current end
			local questTagged = CollectionService:HasTag(current, "QuestNPC") or CollectionService:HasTag(current, "QuestGiver")
			if current:FindFirstChildOfClass("Humanoid") or questTagged
				or current:GetAttribute("QuestGiver") == true or current:GetAttribute("NPCName") ~= nil then
				return current
			end
		end
		current = current.Parent
	end

	local position = promptPosition(prompt)
	local humanoids = Workspace:FindFirstChild("Humanoids")
	if position and humanoids then
		local nearest: Model? = nil
		local nearestDistance = 18
		for _, item in humanoids:GetDescendants() do
			if item:IsA("Model") and not Players:GetPlayerFromCharacter(item) then
				local humanoid = item:FindFirstChildOfClass("Humanoid")
				local root = item:FindFirstChild("HumanoidRootPart")
				if humanoid and root and root:IsA("BasePart") then
					local distance = (root.Position - position).Magnitude
					if distance < nearestDistance then nearest, nearestDistance = item, distance end
				end
			end
		end
		if nearest then return nearest end
	end
	return fallback or (prompt.Parent :: Instance)
end

local function usePrompt(prompt: ProximityPrompt, maxDistance: number): boolean
	local _, _, root = getCharacter()
	local position = promptPosition(prompt)
	local activation = math.max(1, prompt.MaxActivationDistance - 1)
	if not root or not position or not prompt.Enabled or (position - root.Position).Magnitude > math.min(maxDistance, activation) then return false end
	local trigger = (global :: any).fireproximityprompt
	if type(trigger) == "function" then
		return pcall(trigger, prompt)
	else
		return pcall(function()
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.05)
			prompt:InputHoldEnd()
		end)
	end
end

local function field(instance: Instance?, keys: {string}): any
	if not instance then return nil end
	for _, key in keys do
		local value = instance:GetAttribute(key)
		if value ~= nil then return value end
		local child = instance:FindFirstChild(key)
		if child and child:IsA("ValueBase") then return (child :: any).Value end
	end
	return nil
end

local lastKnownPlayerLevel: number? = nil

local function parseLevelValue(raw: any): number?
	if type(raw) == "number" then
		return if raw >= 1 then math.floor(raw) else nil
	end
	if type(raw) ~= "string" then return nil end
	local text = raw:gsub("<[^>]->", ""):gsub(",", ""):match("^%s*(.-)%s*$")
	local number = tonumber(text)
		or tonumber(text:match("^[Ll][Vv][Ll]?%.?%s*:?%s*(%d+)"))
		or tonumber(text:match("^[Ll][Ee][Vv][Ee][Ll]%s*:?%s*(%d+)"))
		or tonumber(text:match("^(%d+)%s*[Ll][Vv][Ll]?%.?$"))
		or tonumber(text:match("^(%d+)%s*[Ll][Ee][Vv][Ee][Ll]$"))
	return if number and number >= 1 then math.floor(number) else nil
end

local function rememberPlayerLevel(level: number?): number?
	if level then lastKnownPlayerLevel = level end
	return level
end

local function currentLevel(): number?
	local keys = { "Level", "Lvl", "PlayerLevel" }
	if not characterInfo then
		characterInfo = requirePath(ReplicatedStorage, { "CAM", "Global", "Character_info_provider" })
	end
	if characterInfo then
		for _, name in { "Get_level", "get_level", "GetLevel", "getLevel", "Get_player_level", "get_player_level" } do
			local getter = characterInfo[name]
			if type(getter) == "function" then
				local ok, raw = pcall(getter, player)
				if not ok then ok, raw = pcall(getter, characterInfo, player) end
				local provided = if ok then parseLevelValue(raw) else nil
				if ok and not provided and type(raw) == "table" then
					provided = parseLevelValue(raw.Level or raw.Lvl or raw.PlayerLevel or raw.CombatLevel)
				end
				if provided then return rememberPlayerLevel(provided) end
			end
		end
	end
	local direct = field(player, keys)
	local level = parseLevelValue(direct)
	if level then return rememberPlayerLevel(level) end

	local containers: {Instance} = {}
	local stats = player:FindFirstChild("leaderstats")
	local data = player:FindFirstChild("Data") or player:FindFirstChild("PlayerData")
	if stats then table.insert(containers, stats) end
	if data then table.insert(containers, data) end
	if player.Character then table.insert(containers, player.Character) end
	for _, container in containers do
		local raw = field(container, keys)
		level = parseLevelValue(raw)
		if not level then level = parseLevelValue(field(container, { "CombatLevel" })) end
		if level then return rememberPlayerLevel(level) end
		for _, descendant in container:GetDescendants() do
			local name = descendant.Name:lower()
			if name == "level" or name == "lvl" or name == "playerlevel" or name == "combatlevel" then
				if descendant:IsA("ValueBase") then level = parseLevelValue((descendant :: any).Value) end
				if not level then level = parseLevelValue(field(descendant, keys)) end
				if level then return rememberPlayerLevel(level) end
			end
		end
	end

	local gui = player:FindFirstChild("PlayerGui")
	if gui then
		local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
		local bestLevel: number? = nil
		local bestScore = -1
		for _, child in gui:GetDescendants() do
			if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Visible then
				local path = child:GetFullName():lower()
				local text = child.Text:gsub("<[^>]->", "")
				local excluded = path:find("mastery", 1, true) or path:find("combat", 1, true)
					or path:find("dialog", 1, true) or path:find("conversation", 1, true)
					or path:find("quest", 1, true) or path:find("lukiho", 1, true)
				if not excluded and not text:lower():find("mastery", 1, true) then
					level = parseLevelValue(text)
					if not level and (child.Name:lower():find("level", 1, true) or path:find(".level", 1, true)) then
						level = tonumber(text:match("%d+"))
					end
					if level then
						local score = 0
						local name = child.Name:lower()
						if name:find("level", 1, true) or name == "lvl" then score += 5 end
						if text:match("^%s*[Ll][Vv][Ll]?") or text:match("^%s*[Ll][Ee][Vv][Ee][Ll]") then score += 4 end
						if path:find("hud", 1, true) or path:find("stat", 1, true) or path:find("profile", 1, true) then score += 3 end
						if viewport and child.AbsolutePosition.X < viewport.X * 0.5 then score += 1 end
						if score > bestScore or (score == bestScore and (not bestLevel or level > bestLevel)) then
							bestLevel, bestScore = level, score
						end
					end
				end
			end
		end
		if bestLevel and bestScore >= 4 then return rememberPlayerLevel(bestLevel) end
	end
	return lastKnownPlayerLevel
end

local QUEST_TARGET_KEYS = { "QuestTarget", "TargetMob", "RequiredMob", "EnemyName", "MobName" }
local QUEST_LEVEL_KEYS = { "RequiredLevel", "MinLevel", "LevelRequirement", "CombatLevel", "RequiredCombatLevel", "MinCombatLevel", "CombatRequiredLevel" }

local function hudQuestProgress(): (string?, boolean?)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return nil, nil end
	for _, child in gui:GetDescendants() do
		if child:IsA("TextLabel") and child.Visible then
			local text = child.Text:gsub("<[^>]->", ""):match("^%s*(.-)%s*$")
			local target, current, required = text:match("^(.-)%s+[Dd]efeated%s+(%d+)%s*/%s*(%d+)")
			if not target then target, current, required = text:match("^[Dd]efeat%s+(.-)%s+(%d+)%s*/%s*(%d+)") end
			if not target then target, current, required = text:match("^[Kk]ill%s+(.-)%s+(%d+)%s*/%s*(%d+)") end
			if not target then current, required, target = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)%s+[Dd]efeated") end
			if not target then target, current, required = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)") end
			if target and current and required then
				return target:match("^%s*(.-)%s*$"), tonumber(current) >= tonumber(required)
			end
			local path = child:GetFullName():lower()
			local lower = text:lower()
			if (path:find("quest", 1, true) or path:find("objective", 1, true))
				and (lower:find("quest complete", 1, true) or lower:find("quest completed", 1, true)) then
				return nil, true
			end
		end
	end
	return nil, nil
end

local function activeQuestTarget(): string?
	local containers: {Instance} = { player }
	local current = player:FindFirstChild("CurrentQuest")
	local quest = player:FindFirstChild("Quest")
	local data = player:FindFirstChild("Data")
	if current then table.insert(containers, current) end
	if quest then table.insert(containers, quest) end
	if data then table.insert(containers, data) end
	for _, container in containers do
		local target = field(container, QUEST_TARGET_KEYS)
		if type(target) == "string" and target ~= "" then return target end
	end
	local hudTarget = hudQuestProgress()
	return hudTarget
end

local function questComplete(): boolean
	local containers: {Instance} = { player }
	local current = player:FindFirstChild("CurrentQuest")
	local quest = player:FindFirstChild("Quest")
	if current then table.insert(containers, current) end
	if quest then table.insert(containers, quest) end
	for _, container in containers do
		if field(container, { "QuestCompleted", "IsComplete", "Completed" }) == true then return true end
	end
	local _, completed = hudQuestProgress()
	return completed == true
end

type QuestOption = { Text: string, Target: string, Level: number }
type QuestChoiceHint = { Key: string, Position: Vector3, Option: QuestOption, Owner: string? }
type QuestEntry = { Prompt: ProximityPrompt, Giver: Instance, Position: Vector3, Level: number,
	Target: string?, Dialogue: boolean, Confidence: number, Hints: {QuestOption} }
type SelectedQuest = { Entry: QuestEntry, Option: QuestOption }
local rejectedQuestGivers: {[Instance]: number} = {}
local questDialogueCatalog: {[Instance]: {QuestOption}} = {}
local scannedQuestGivers: {[Instance]: boolean} = {}
local questChoiceHints: {QuestChoiceHint} = {}
local questHintsRefreshedAt = 0

local function parseQuestOptionText(rawText: string): QuestOption?
	local text = rawText:gsub("<[^>]->", ""):match("^%s*(.-)%s*$")
	if text == "" then return nil end
	local lower = text:lower()
	local required = tonumber(lower:match("lvl?%s*%.?%s*:?%s*(%d+)") or lower:match("level%s*:?%s*(%d+)"))
	if not required or required <= 0 then return nil end
	local target = lower:gsub("%b()", ""):gsub("%b[]", ""):match("^%s*(.-)%s*$")
	for _, prefix in { "i'll ", "ill ", "i will " } do
		if target:sub(1, #prefix) == prefix then target = target:sub(#prefix + 1); break end
	end
	local combat = false
	for _, prefix in { "accept ", "clear out ", "deal with ", "defeat ", "destroy ", "drive back ", "drive ",
		"eliminate ", "exterminate ", "fell ", "hunt ", "kill ", "put out ", "slay ", "take ", "wipe out " } do
		if target:sub(1, #prefix) == prefix then
			target = target:sub(#prefix + 1)
			combat = true
			break
		end
	end
	if not combat then return nil end
	target = target:gsub("lvl?%s*%.?%s*:?%s*%d+", ""):gsub("level%s*:?%s*%d+", "")
		:gsub("^%d+%s+", ""):gsub("^the%s+", ""):gsub("%s+back$", "")
		:gsub("[%.!]+$", ""):match("^%s*(.-)%s*$")
	if target == "" then return nil end
	return { Text = text, Target = target, Level = required }
end

local function refreshQuestChoiceHints(): {QuestChoiceHint}
	if questHintsRefreshedAt > 0 and os.clock() - questHintsRefreshedAt < 10 then return questChoiceHints end
	questHintsRefreshedAt = os.clock()
	if not regions then regions = requirePath(ReplicatedStorage, { "Regions" }) end
	if type(regions) ~= "table" then return questChoiceHints end
	local nextHints: {QuestChoiceHint} = {}
	local seen: {[string]: boolean} = {}
	local visited: {[any]: boolean} = {}
	local function add(rawText: any, position: Vector3?, owner: string?)
		if type(rawText) ~= "string" or not position then return end
		local option = parseQuestOptionText(rawText)
		if not option then return end
		local key = string.format("%s@%s@%d,%d,%d", option.Text:lower(), (owner or ""):lower(),
			math.round(position.X), math.round(position.Y), math.round(position.Z))
		if seen[key] then return end
		seen[key] = true
		table.insert(nextHints, { Key = key, Position = position, Option = option, Owner = owner })
	end
	local function childOwner(key: any, current: string?): string?
		if type(key) ~= "string" or parseQuestOptionText(key) then return current end
		local lower = key:lower()
		if table.find({ "text", "name", "title", "label", "choice", "response", "position", "cframe",
			"location", "spawn", "point", "center", "coordinates", "coords" }, lower) then return current end
		for _, word in AREA_DATA_BLOCK_WORDS do
			if lower:find(word, 1, true) then return current end
		end
		for _, name in AREA_MODULE_KEYS do
			if lower == name:lower() then return current end
		end
		if lower == "npcspawns" or lower == "spawns" then return current end
		return if #key <= 60 then key else current
	end
	local function walk(node: any, depth: number, inheritedPosition: Vector3?, inheritedOwner: string?)
		if type(node) ~= "table" or visited[node] or depth > 7 then return end
		visited[node] = true
		local nodePosition = tablePosition(node) or inheritedPosition
		local explicitOwner = node.GiverName or node.NPCName or node.NpcName or node.Npc
		local nodeName = node.Name
		if not explicitOwner and type(nodeName) == "string" and not parseQuestOptionText(nodeName) then explicitOwner = nodeName end
		local nodeOwner = if type(explicitOwner) == "string" and explicitOwner ~= "" then explicitOwner else inheritedOwner
		for key, value in node do
			local position = tablePosition(value) or nodePosition
			add(key, position, nodeOwner)
			if type(value) == "table" then
				for _, textKey in { "Text", "Name", "Title", "Label", "Choice", "Response" } do
					add(value[textKey], position, nodeOwner)
				end
				walk(value, depth + 1, position, childOwner(key, nodeOwner))
			end
		end
	end
	walk(regions, 0, nil, nil)
	questChoiceHints = nextHints
	return questChoiceHints
end

local function questGiverDisplayName(giver: Instance): string
	local attributedName = giver:GetAttribute("DisplayName") or giver:GetAttribute("NPCName")
	return if type(attributedName) == "string" and attributedName ~= "" then attributedName else giver.Name
end

local function questHintsForGiver(giver: Instance): {QuestOption}
	local options: {QuestOption} = {}
	local giverName = questGiverDisplayName(giver)
	local giverKey = canonicalName(giverName)
	for _, hint in refreshQuestChoiceHints() do
		local ownerMatch = hint.Owner ~= nil and nameMatches(giverName, hint.Owner)
		local targetKey = canonicalName(hint.Option.Target)
		local mitsuFallback = giverKey == "demonslayermitsu" and hint.Option.Level >= 105 and hint.Option.Level <= 145
			and (targetKey:find("frost", 1, true) ~= nil or targetKey:find("blaze", 1, true) ~= nil)
		if ownerMatch or mitsuFallback then table.insert(options, hint.Option) end
	end
	return options
end

local function questGivers(): {QuestEntry}
	local _, _, root = getCharacter()
	if not root then return {} end
	local byGiver: {[Instance]: QuestEntry} = {}
	for prompt in trackedPrompts do
		if prompt.Parent then
			local giver = questPromptGiver(prompt)
			local giverName = questGiverDisplayName(giver)
			local position = promptPosition(prompt)
			if not position then continue end
			local hints = questHintsForGiver(giver)
			local text = (prompt.ActionText .. " " .. prompt.ObjectText .. " " .. giverName):lower()
			local combatRoleGiver = giverName:lower():find("demon slayer", 1, true) ~= nil
			local tagged = CollectionService:HasTag(giver, "QuestNPC") or CollectionService:HasTag(giver, "QuestGiver")
			local questFolder = giver:FindFirstAncestor("QuestNPCs") or giver:FindFirstAncestor("QuestGivers")
			local rawLevel = field(prompt, QUEST_LEVEL_KEYS) or field(giver, QUEST_LEVEL_KEYS)
			local required = parseLevelValue(rawLevel) or tonumber(tostring(rawLevel):match("%d+")) or 0
			local target = field(prompt, QUEST_TARGET_KEYS) or field(giver, QUEST_TARGET_KEYS)
			local rawKind = field(prompt, { "QuestType", "QuestCategory", "ObjectiveType", "TaskType" })
				or field(giver, { "QuestType", "QuestCategory", "ObjectiveType", "TaskType" })
			local kind = if rawKind ~= nil then tostring(rawKind):lower() else ""
			local explicitlyNonCombat = kind:find("delivery", 1, true) ~= nil or kind:find("letter", 1, true) ~= nil
				or kind:find("gather", 1, true) ~= nil or kind:find("collect", 1, true) ~= nil
				or kind:find("talk", 1, true) ~= nil or kind:find("escort", 1, true) ~= nil
			local dialogue = text:find("chat", 1, true) ~= nil or text:find("talk", 1, true) ~= nil
				or combatRoleGiver or #hints > 0 or ((tagged or questFolder ~= nil) and target == nil)
			local structured = tagged or questFolder ~= nil or field(giver, { "QuestGiver" }) == true
				or combatRoleGiver or text:find("quest", 1, true) ~= nil or target ~= nil or rawLevel ~= nil or #hints > 0
			local questLike = structured and (not explicitlyNonCombat or target ~= nil or #hints > 0)
			if questLike then
				local hintLevel = 0
				for _, hint in hints do hintLevel = math.max(hintLevel, hint.Level) end
				local effectiveLevel = math.max(required, hintLevel)
				local confidence = if #hints > 0 then 3 elseif structured then 2 else 1
				local current = byGiver[giver]
				if not current or confidence > current.Confidence or (confidence == current.Confidence and effectiveLevel > current.Level) then
					byGiver[giver] = { Prompt = prompt, Giver = giver, Position = position, Level = effectiveLevel,
						Target = if type(target) == "string" and target ~= "" then target else nil,
						Dialogue = dialogue, Confidence = confidence, Hints = hints }
				end
			end
		end
	end
	local entries: {QuestEntry} = {}
	for _, entry in byGiver do table.insert(entries, entry) end
	table.sort(entries, function(left, right)
		return (left.Position - root.Position).Magnitude < (right.Position - root.Position).Magnitude
	end)
	return entries
end

local function mergeQuestOption(giver: Instance, option: QuestOption)
	local options = questDialogueCatalog[giver]
	if not options then
		options = {}
		questDialogueCatalog[giver] = options
	end
	for index, existing in options do
		if existing.Level == option.Level and canonicalName(existing.Target) == canonicalName(option.Target) then
			options[index] = option
			return
		end
	end
	table.insert(options, option)
end

local function refreshStructuredQuests(entries: {QuestEntry})
	for _, entry in entries do
		if entry.Level > 0 and entry.Target then
			mergeQuestOption(entry.Giver, { Text = entry.Target, Target = entry.Target, Level = entry.Level })
		end
		for _, hint in entry.Hints do mergeQuestOption(entry.Giver, hint) end
		if not entry.Dialogue or #entry.Hints > 0 then scannedQuestGivers[entry.Giver] = true end
	end
end

local function nextQuestGiverToScan(entries: {QuestEntry}): QuestEntry?
	for _, entry in entries do
		if entry.Dialogue and not scannedQuestGivers[entry.Giver]
			and (rejectedQuestGivers[entry.Giver] or 0) <= os.clock() then
			return entry
		end
	end
	return nil
end

local function bestCatalogQuest(entries: {QuestEntry}, level: number): SelectedQuest?
	local _, _, root = getCharacter()
	if not root then return nil end
	local best: SelectedQuest? = nil
	local bestDistance = math.huge
	for _, entry in entries do
		if (rejectedQuestGivers[entry.Giver] or 0) <= os.clock() then
			for _, option in questDialogueCatalog[entry.Giver] or {} do
				if option.Level > 0 and option.Level <= level then
					local distance = (entry.Position - root.Position).Magnitude
					if not best or option.Level > best.Option.Level
						or (option.Level == best.Option.Level and distance < bestDistance) then
						best = { Entry = entry, Option = option }
						bestDistance = distance
					end
				end
			end
		end
	end
	return best
end

type DialogueChoice = { Button: GuiButton, Text: string, Target: string, Level: number }
local function guiVisible(instance: GuiObject): boolean
	if instance.AbsoluteSize.X <= 1 or instance.AbsoluteSize.Y <= 1 then return false end
	local current: Instance? = instance
	while current and current:IsA("GuiObject") do
		if not current.Visible then return false end
		current = current.Parent
	end
	return true
end

local function buttonText(button: GuiButton): string
	if button:IsA("TextButton") and button.Text ~= "" then return button.Text end
	local longest = ""
	for _, child in button:GetDescendants() do
		if child:IsA("TextLabel") and child.Visible and #child.Text > #longest then longest = child.Text end
	end
	return longest
end

local function parseDialogueChoice(button: GuiButton): DialogueChoice?
	local text = buttonText(button):gsub("<[^>]->", ""):match("^%s*(.-)%s*$")
	local option = parseQuestOptionText(text)
	if not option then return nil end
	return { Button = button, Text = option.Text, Target = option.Target, Level = option.Level }
end

local function activateGuiObject(object: GuiObject): boolean
	local fireSignal = (global :: any).firesignal
	if object:IsA("GuiButton") and type(fireSignal) == "function" then
		if object:IsA("TextButton") then return pcall(fireSignal, object.MouseButton1Click) end
		return pcall(fireSignal, object.Activated)
	end
	local ok, virtualInput = pcall(function() return game:GetService("VirtualInputManager") end)
	if not ok or not virtualInput then return false end
	local center = object.AbsolutePosition + object.AbsoluteSize / 2
	local inputManager: any = virtualInput
	return pcall(function()
		inputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
		task.wait(0.04)
		inputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
	end)
end

local function activateGuiButton(button: GuiButton): boolean
	return activateGuiObject(button)
end

local function dialogueChoices(): ({DialogueChoice}, GuiButton?, GuiObject?, boolean)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return {}, nil, nil, false end
	local choices: {DialogueChoice} = {}
	local closeButton: GuiButton? = nil
	local advanceControl: GuiObject? = nil
	local advanceScore = 0
	local advanceY = -math.huge
	local dialogueVisible = false
	for _, child in gui:GetDescendants() do
		if child:IsA("GuiButton") and guiVisible(child) then
			local text = buttonText(child):gsub("<[^>]->", ""):match("^%s*(.-)%s*$")
			local lower = text:lower()
			local name = child.Name:lower()
			local path = child:GetFullName():lower()
			local inDialogue = path:find("dialog", 1, true) ~= nil or path:find("conversation", 1, true) ~= nil
				or path:find("npcchat", 1, true) ~= nil or path:find("speech", 1, true) ~= nil
				or path:find("story", 1, true) ~= nil
			if lower == "close" or lower == "cancel" or lower == "leave" then
				closeButton = child
				dialogueVisible = true
			end
			local choice = parseDialogueChoice(child)
			if choice then
				dialogueVisible = true
				table.insert(choices, choice)
			elseif child ~= closeButton then
				local namedAdvance = name:find("next", 1, true) ~= nil or name:find("continue", 1, true) ~= nil
					or name:find("advance", 1, true) ~= nil or name:find("proceed", 1, true) ~= nil
					or path:find("next", 1, true) ~= nil or path:find("continue", 1, true) ~= nil
					or path:find("advance", 1, true) ~= nil or path:find("proceed", 1, true) ~= nil
				local textAdvance = lower == "next" or lower == "continue" or lower == "advance"
					or lower == "proceed" or lower == ">" or lower == ">>" or lower == "..."
				local icon = child:FindFirstChildWhichIsA("ImageLabel", true)
				local iconName = if icon then icon.Name:lower() else ""
				local iconAdvance = inDialogue
					and (child:IsA("ImageButton") or icon ~= nil)
					and (name:find("arrow", 1, true) ~= nil or name:find("caret", 1, true) ~= nil
						or path:find("arrow", 1, true) ~= nil or path:find("caret", 1, true) ~= nil
						or iconName:find("arrow", 1, true) ~= nil or iconName:find("caret", 1, true) ~= nil)
				local genericIcon = text == "" and inDialogue and (child:IsA("ImageButton") or icon ~= nil)
					and not name:find("close", 1, true) and not name:find("cancel", 1, true)
					and not name:find("back", 1, true) and not name:find("exit", 1, true)
					and child.AbsoluteSize.X <= 160 and child.AbsoluteSize.Y <= 160
				local narrativeSurface = inDialogue and #text >= 15
					and child.AbsoluteSize.X >= 180 and child.AbsoluteSize.Y >= 60
				local score = if namedAdvance or textAdvance then 4 elseif iconAdvance then 3
					elseif narrativeSurface then 2 elseif genericIcon then 1 else 0
				if score > advanceScore or (score > 0 and score == advanceScore and child.AbsolutePosition.Y > advanceY) then
					advanceControl = child
					advanceScore = score
					advanceY = child.AbsolutePosition.Y
					dialogueVisible = true
				end
			end
		end
	end
	for _, child in gui:GetDescendants() do
		if child:IsA("TextLabel") and guiVisible(child) then
			local path = child:GetFullName():lower()
			local inDialogue = path:find("dialog", 1, true) or path:find("conversation", 1, true)
				or path:find("npcchat", 1, true) or path:find("speech", 1, true)
				or path:find("story", 1, true)
			if inDialogue then
				dialogueVisible = true
				local text = child.Text:gsub("<[^>]->", ""):match("^%s*(.-)%s*$")
				local buttonOwner = child:FindFirstAncestorWhichIsA("GuiButton")
				local narrative = #text >= 15 and child.AbsoluteSize.X >= 180 and child.AbsoluteSize.Y >= 35
				if narrative and not buttonOwner and advanceScore < 2 then
					advanceControl = child
					advanceScore = 2
					advanceY = child.AbsolutePosition.Y
				end
			end
		end
	end
	return choices, closeButton, advanceControl, dialogueVisible
end

local pendingQuest: QuestEntry? = nil
local pendingDialogueMode = ""
local pendingQuestOption: QuestOption? = nil
local dialogueDeadline = 0
local dialogueAdvanceAt = 0
local dialogueStepCount = 0

local function inspectQuestData()
	print("[Lukiho] Level:", currentLevel(), "Active target:", activeQuestTarget(), "Complete:", questComplete())
	local hints = refreshQuestChoiceHints()
	print("[Lukiho] Replicated combat quest hints:", #hints)
	for index = 1, math.min(#hints, 30) do
		local hint = hints[index]
		print("[Lukiho]   Hint owner:", hint.Owner, "Choice:", hint.Option.Text,
			"Level:", hint.Option.Level, "Target:", hint.Option.Target)
	end
	local count = 0
	local entries = questGivers()
	refreshStructuredQuests(entries)
	for _, entry in entries do
		count += 1
		local options = questDialogueCatalog[entry.Giver] or {}
		print("[Lukiho] Quest NPC:", entry.Giver:GetFullName(), "Action:", entry.Prompt.ActionText,
			"Scanned:", scannedQuestGivers[entry.Giver] == true, "Cached choices:", #options,
			"Structured level:", entry.Level, "Structured target:", entry.Target)
		for _, option in options do
			print("[Lukiho]   Choice:", option.Text, "Required level:", option.Level, "Target:", option.Target)
		end
		if count >= 30 then break end
	end
	local choices, _, advance, visible = dialogueChoices()
	print("[Lukiho] Dialogue visible:", visible, "Visible choices:", #choices)
	print("[Lukiho] Dialogue advance available:", advance ~= nil, "Current step:", dialogueStepCount)
	for _, choice in choices do
		print("[Lukiho]   Visible choice:", choice.Text, "Required level:", choice.Level, "Target:", choice.Target)
	end
	print("[Lukiho] Quest NPC entries shown:", count)
end

local questRetryAt = 0
local wasQuestComplete = false
local activeQuestSeen = false
local function questStatus(message: string)
	if State.questStatus == message then return end
	State.questStatus = message
	if questStatusLabel then questStatusLabel:SetText(message) end
end

local function clearPendingDialogue()
	pendingQuest = nil
	pendingDialogueMode = ""
	pendingQuestOption = nil
	dialogueDeadline = 0
	dialogueAdvanceAt = 0
	dialogueStepCount = 0
end

local function sameQuestOption(choice: DialogueChoice, option: QuestOption): boolean
	return choice.Level == option.Level and canonicalName(choice.Target) == canonicalName(option.Target)
end

local function catalogCounts(entries: {QuestEntry}): (number, number)
	local scanned = 0
	local quests = 0
	for _, entry in entries do
		if scannedQuestGivers[entry.Giver] then scanned += 1 end
		quests += #(questDialogueCatalog[entry.Giver] or {})
	end
	return scanned, quests
end

local function resetQuestCatalog()
	table.clear(questDialogueCatalog)
	table.clear(scannedQuestGivers)
	table.clear(rejectedQuestGivers)
	table.clear(questChoiceHints)
	questHintsRefreshedAt = 0
	clearPendingDialogue()
	State.questGiver = nil
	State.levelTarget = nil
	State.travelDestination = nil
	questRetryAt = 0
	wasQuestComplete = false
	activeQuestSeen = false
	clearTarget()
	questStatus("Quest catalog cleared; scan will restart")
end

supervise("auto level", 1, function()
	if not State.autoLevel then
		State.levelTarget = nil
		State.questGiver = nil
		clearPendingDialogue()
		questStatus("Idle")
		return
	end
	if State.manualTravel or not live() then return end
	local level = currentLevel()
	if not level then
		State.levelTarget = nil
		State.travelDestination = nil
		clearTarget()
		questStatus("Level data unavailable")
		return
	end
	if pendingQuest then
		local choices, closeButton, advanceControl, dialogueVisible = dialogueChoices()
		if pendingDialogueMode == "Scan" and #choices > 0 then
			local found = 0
			for _, choice in choices do
				if choice.Level > 0 then
					mergeQuestOption(pendingQuest.Giver, {
						Text = choice.Text,
						Target = choice.Target,
						Level = choice.Level,
					})
					found += 1
				end
			end
			scannedQuestGivers[pendingQuest.Giver] = true
			local giverName = pendingQuest.Giver.Name
			if closeButton then activateGuiButton(closeButton) end
			clearPendingDialogue()
			questRetryAt = os.clock() + 0.5
			questStatus(string.format("Lv %d | Scanned %s: %d leveled quest(s)", level, giverName, found))
			return
		elseif pendingDialogueMode == "Accept" and pendingQuestOption then
			for _, choice in choices do
				if sameQuestOption(choice, pendingQuestOption) and activateGuiButton(choice.Button) then
					local accepted = pendingQuestOption
					State.levelTarget = accepted.Target
					State.questGiver = pendingQuest.Giver
					questRetryAt = os.clock() + 45
					wasQuestComplete = false
					activeQuestSeen = false
					State.travelDestination = nil
					clearPendingDialogue()
					questStatus(string.format("Lv %d | Accepted quest Lv %d: %s", level, accepted.Level, accepted.Target))
					return
				end
			end
		end
		if dialogueVisible and advanceControl and dialogueStepCount < 20 and os.clock() >= dialogueAdvanceAt then
			if activateGuiObject(advanceControl) then
				dialogueStepCount += 1
				dialogueAdvanceAt = os.clock() + 0.3
				dialogueDeadline = math.max(dialogueDeadline, os.clock() + 5)
				questStatus(string.format("Lv %d | %s %s dialogue (%d/20)", level,
					pendingDialogueMode, pendingQuest.Giver.Name, dialogueStepCount))
				return
			end
		end
		if os.clock() >= dialogueDeadline then
			if dialogueVisible and closeButton then activateGuiButton(closeButton) end
			local giver = pendingQuest.Giver
			local mode = pendingDialogueMode
			if mode == "Scan" then
				scannedQuestGivers[giver] = true
			else
				rejectedQuestGivers[giver] = os.clock() + 30
			end
			clearPendingDialogue()
			questRetryAt = 0
			questStatus(string.format("Lv %d | %s failed for %s", level, mode, giver.Name))
			return
		end
		questStatus(string.format("Lv %d | %s %s's dialogue", level, pendingDialogueMode, pendingQuest.Giver.Name))
		return
	end
	local active = activeQuestTarget()
	local completed = questComplete()
	local justCompleted = completed and not wasQuestComplete
	wasQuestComplete = completed
	if completed then
		State.levelTarget = nil
		activeQuestSeen = false
		if justCompleted then questRetryAt = 0 end
		clearTarget()
	elseif active then
		if State.levelTarget ~= active then
			clearTarget()
			State.travelDestination = nil
		end
		State.levelTarget = active
		activeQuestSeen = true
		questStatus(string.format("Lv %d | Target: %s", level, active))
		return
	elseif State.levelTarget and activeQuestSeen then
		State.levelTarget = nil
		activeQuestSeen = false
		questRetryAt = 0
		clearTarget()
	elseif State.levelTarget and os.clock() < questRetryAt then
		questStatus(string.format("Lv %d | Quest requested: %s", level, State.levelTarget))
		return
	else
		if State.levelTarget then clearTarget() end
		State.levelTarget = nil
		activeQuestSeen = false
	end

	local entries = questGivers()
	refreshStructuredQuests(entries)
	local toScan = nextQuestGiverToScan(entries)
	if toScan then
		State.questGiver = toScan.Giver
		local _, _, root = getCharacter()
		if not root then return end
		local distance = (root.Position - toScan.Position).Magnitude
		if distance > math.min(8, math.max(1, toScan.Prompt.MaxActivationDistance - 1)) then
			State.travelDestination = toScan.Position + Vector3.new(0, 2, 0)
			questStatus(string.format("Lv %d | Scanning quest NPC: %s", level, toScan.Giver.Name))
		elseif os.clock() >= questRetryAt and usePrompt(toScan.Prompt, 8) then
			State.travelDestination = nil
			pendingQuest = toScan
			pendingDialogueMode = "Scan"
			pendingQuestOption = nil
			dialogueDeadline = os.clock() + 12
			dialogueAdvanceAt = os.clock() + 0.3
			dialogueStepCount = 0
			questRetryAt = os.clock() + 1
			questStatus(string.format("Lv %d | Opening %s for scan", level, toScan.Giver.Name))
		end
		return
	end

	local selected = bestCatalogQuest(entries, level)
	if not selected then
		State.travelDestination = nil
		local scanned, quests = catalogCounts(entries)
		questStatus(string.format("Lv %d | Scanned %d NPC(s), no eligible leveled kill quest (%d found)", level, scanned, quests))
		return
	end
	local quest = selected.Entry
	local option = selected.Option
	State.questGiver = quest.Giver
	local _, _, root = getCharacter()
	if not root then return end
	local distance = (root.Position - quest.Position).Magnitude
	if distance > math.min(8, math.max(1, quest.Prompt.MaxActivationDistance - 1)) then
		State.travelDestination = quest.Position + Vector3.new(0, 2, 0)
		questStatus(string.format("Lv %d | Quest Lv %d: traveling to %s", level, option.Level, quest.Giver.Name))
	elseif os.clock() >= questRetryAt then
		if usePrompt(quest.Prompt, 8) then
			State.travelDestination = nil
			if quest.Dialogue then
				pendingQuest = quest
				pendingDialogueMode = "Accept"
				pendingQuestOption = option
				dialogueDeadline = os.clock() + 12
				dialogueAdvanceAt = os.clock() + 0.3
				dialogueStepCount = 0
				questRetryAt = os.clock() + 1
				questStatus(string.format("Lv %d | Selecting quest Lv %d from %s", level, option.Level, quest.Giver.Name))
			else
				questRetryAt = os.clock() + 20
				State.levelTarget = option.Target
				activeQuestSeen = false
				questStatus(string.format("Lv %d | Requested quest Lv %d: %s", level, option.Level, option.Target))
			end
		end
	end
end)

local function tierMatches(chest: Instance): boolean
	if State.selectedTier == "All" then return true end
	local tier = tostring(chest:GetAttribute("Tier") or chest:GetAttribute("ChestId") or chest.Name)
	return tier:lower():find(State.selectedTier:lower(), 1, true) ~= nil
end

local function isLootPrompt(prompt: ProximityPrompt): boolean
	local drops = Workspace:FindFirstChild("LootDrops")
	if drops and prompt:IsDescendantOf(drops) then return true end
	for _, tag in { "LootDrop", "Loot", "Drop", "Collectible" } do
		if CollectionService:HasTag(prompt, tag) then return true end
		if prompt.Parent and CollectionService:HasTag(prompt.Parent, tag) then return true end
	end
	local owner = prompt:FindFirstAncestorOfClass("Model") or prompt.Parent
	if owner and (owner:GetAttribute("IsLoot") == true or owner:GetAttribute("DroppedItem") == true
		or owner:GetAttribute("IsDrop") == true or owner:GetAttribute("Loot") == true) then return true end
	local path = prompt:GetFullName():lower()
	if path:find("lootdrop", 1, true) or path:find("drops", 1, true) or path:find("reward", 1, true) then return true end
	local text = (prompt.Name .. " " .. prompt.ActionText .. " " .. prompt.ObjectText):lower()
	return text:find("loot", 1, true) ~= nil or text:find("pick up", 1, true) ~= nil
		or text:find("pickup", 1, true) ~= nil or text:find("collect", 1, true) ~= nil
		or text:find("claim", 1, true) ~= nil or text:find("take", 1, true) ~= nil
		or text:find("grab", 1, true) ~= nil
end

local lastLootAttempt: {[ProximityPrompt]: number} = {}
local function nearestLootPrompt(): (ProximityPrompt?, number)
	local _, _, root = getCharacter()
	if not root then return nil, math.huge end
	local nearest: ProximityPrompt? = nil
	local distance = State.lootRadius
	for prompt in trackedPrompts do
		local attempted = lastLootAttempt[prompt] or 0
		if prompt.Parent and prompt.Enabled and os.clock() - attempted >= 0.45 and isLootPrompt(prompt) then
			local position = promptPosition(prompt)
			if position then
				local current = (position - root.Position).Magnitude
				if current <= distance then nearest, distance = prompt, current end
			end
		end
	end
	return nearest, distance
end

supervise("loot", 0.2, function()
	local collecting = State.autoLoot or State.autoChestFarm or os.clock() < State.postKillUntil
	if (not collecting or State.autoLevel) and State.lootPrompt then
		State.lootPrompt = nil
		State.travelDestination = nil
	end
	if not live() or not (collecting or State.autoChest or State.autoChestFarm) then
		if State.lootPrompt then State.travelDestination = nil end
		State.lootPrompt = nil
		return
	end
	for prompt in lastLootAttempt do
		if not prompt.Parent then lastLootAttempt[prompt] = nil end
	end
	local handledLoot = false
	if collecting then
		local prompt, distance = nearestLootPrompt()
		if prompt then
			handledLoot = true
			local activation = math.max(1, prompt.MaxActivationDistance - 1)
			if distance <= activation then
				if State.lootPrompt == prompt then State.travelDestination = nil end
				State.lootPrompt = nil
				lastLootAttempt[prompt] = os.clock()
				usePrompt(prompt, activation)
			elseif not activeTarget() and not State.autoLevel and not State.manualTravel then
				local position = promptPosition(prompt)
				if position then
					State.lootPrompt = prompt
					State.travelDestination = position + Vector3.new(0, 2, 0)
				end
			end
		elseif State.lootPrompt then
			State.lootPrompt = nil
			State.travelDestination = nil
		end
	end
	if handledLoot or State.lootPrompt then return end
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
					if usePrompt(prompt, if State.autoChestFarm then 8 else State.lootRadius) then
						State.postKillUntil = math.max(State.postKillUntil, os.clock() + 8)
					end
				end
			end
		end
	end
end)

type EspMarker = { Gui: BillboardGui, Label: TextLabel }
local espMarkers: {[Instance]: EspMarker} = {}
local function clearEsp()
	for instance, marker in espMarkers do
		marker.Gui:Destroy()
		espMarkers[instance] = nil
	end
end

local function markerPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then return instance end
	if instance:IsA("Attachment") and instance.Parent and instance.Parent:IsA("BasePart") then return instance.Parent end
	if instance:IsA("Model") then
		return instance:FindFirstChild("HumanoidRootPart") :: BasePart? or instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function newEspMarker(part: BasePart): EspMarker
	local gui = Instance.new("BillboardGui")
	gui.Name = "LukihoESP"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(170, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.MaxDistance = State.espRadius
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(19, 20, 23)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = label
	return { Gui = gui, Label = label }
end

supervise("esp", 1, function()
	if not State.espEnabled then clearEsp(); return end
	local _, _, root = getCharacter()
	if not root then clearEsp(); return end
	type Candidate = { Instance: Instance, Part: BasePart, Name: string, Color: Color3, Distance: number }
	local candidates: {Candidate} = {}
	local seen: {[Instance]: boolean} = {}
	local function add(instance: Instance, part: BasePart?, name: string, color: Color3)
		if not part or seen[instance] then return end
		seen[instance] = true
		local distance = (part.Position - root.Position).Magnitude
		if distance <= State.espRadius then
			table.insert(candidates, { Instance = instance, Part = part, Name = name, Color = color, Distance = distance })
		end
	end
	local function addNpc(model: Model)
		local humanoid, part = candidate(model)
		if not humanoid or not part then return end
		if isBossModel(model) and State.espBosses then
			add(model, part, "BOSS  " .. model.Name, Color3.fromRGB(255, 126, 170))
		elseif not isBossModel(model) and State.espMobs then
			add(model, part, "MOB  " .. model.Name, Color3.fromRGB(234, 235, 239))
		end
	end
	local humanoids = Workspace:FindFirstChild("Humanoids")
	if humanoids then
		for _, instance in humanoids:GetDescendants() do
			if instance:IsA("Model") then addNpc(instance) end
		end
	end
	local bossFolder = Workspace:FindFirstChild("Bosses")
	if bossFolder then
		for _, instance in bossFolder:GetDescendants() do
			if instance:IsA("Model") then addNpc(instance) end
		end
	end
	for _, tag in { "Enemy", "Boss", "EventBoss" } do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("Model") then addNpc(instance) end
		end
	end
	for prompt in trackedPrompts do
		if prompt.Parent and prompt.Enabled then
			local text = (prompt.ActionText .. " " .. prompt.ObjectText):lower()
			local giver = prompt:FindFirstAncestorOfClass("Model")
			local quest = (giver and (CollectionService:HasTag(giver, "QuestNPC") or CollectionService:HasTag(giver, "QuestGiver")))
				or text:find("quest", 1, true) ~= nil
			if quest and State.espQuests then
				add(prompt, markerPart(prompt.Parent), "QUEST  " .. (prompt.ObjectText ~= "" and prompt.ObjectText or (giver and giver.Name or "NPC")), Color3.fromRGB(255, 205, 105))
			elseif State.espInteractables then
				add(prompt, markerPart(prompt.Parent), "ITEM  " .. (prompt.ObjectText ~= "" and prompt.ObjectText or prompt.Parent.Name), Color3.fromRGB(99, 215, 183))
			end
		end
	end
	table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
	local active: {[Instance]: boolean} = {}
	for index = 1, math.min(#candidates, 250) do
		local entry = candidates[index]
		active[entry.Instance] = true
		local marker = espMarkers[entry.Instance]
		if not marker then
			marker = newEspMarker(entry.Part)
			espMarkers[entry.Instance] = marker
		end
		marker.Gui.Adornee = entry.Part
		marker.Gui.MaxDistance = State.espRadius
		marker.Label.TextColor3 = entry.Color
		marker.Label.Text = string.format("%s  [%d studs]", entry.Name, math.round(entry.Distance))
	end
	for instance, marker in espMarkers do
		if not active[instance] then marker.Gui:Destroy(); espMarkers[instance] = nil end
	end
end)

connect(RunService.Heartbeat, function(dt: number)
	if not live() then return end
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then return end
	local automationMoving = activeTarget() and (State.autoFarm or State.autoBoss or State.autoChestFarm or State.autoLevel or State.manualTravel)
	local destination: CFrame? = nil
	if automationMoving then
		local targetRoot = State.targetRoot :: BasePart
		local targetFrame = targetRoot.CFrame
		local height = if os.clock() < State.dodgingUntil then State.dodgeHeight else State.attackHeight
		local position = (targetFrame * CFrame.new(0, height, State.attackOffset)).Position
		destination = CFrame.lookAt(position, targetFrame.Position)
	elseif State.travelDestination and (State.autoBoss or State.autoChestFarm or State.autoLevel or State.manualTravel or State.lootPrompt) then
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
	clearEsp()
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
	if global.LukihoHubVersion == HUB_VERSION then global.LukihoHubVersion = nil end
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

local function polishSliderTypography(screenGui: ScreenGui)
	for _, descendant in screenGui:GetDescendants() do
		if descendant:IsA("UIStroke") and descendant.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			local textObject = descendant.Parent
			local bar = textObject and textObject.Parent
			if textObject and (textObject:IsA("TextLabel") or textObject:IsA("TextBox"))
				and bar and bar:IsA("TextButton") then
				descendant.Enabled = false
				textObject.Font = Enum.Font.Gotham
				textObject.TextSize = 12
			end
		end
	end
end

mobNames, bossNames = scanNpcCatalog()
areaNames, areaPositions, travelTargetNames, travelTargets = scanTravelCatalog()
weaponNames, weaponSlots = scanHotbar()

local loaded, failure = xpcall(function()
	library = loadRemote("Library.lua")
	local theme: any = loadRemote("addons/ThemeManager.lua")
	local saves: any = loadRemote("addons/SaveManager.lua")
	library.ForceCheckbox = false
	library.IsLightTheme = false
	theme:SetLibrary(library)
	theme:SetDefaultTheme({
		FontColor = "eef1f5",
		MainColor = "24272d",
		AccentColor = "5598d6",
		BackgroundColor = "181a1e",
		OutlineColor = "41464f",
		FontFace = "Gotham",
	})
	local compactLayout = Workspace.CurrentCamera ~= nil and Workspace.CurrentCamera.ViewportSize.X < 760
	local window = library:CreateWindow({
		Title = "LUKIHO",
		Footer = "Created by Lukiho | v" .. HUB_VERSION,
		Size = UDim2.fromOffset(920, 620),
		CornerRadius = 6,
		Font = Enum.Font.Gotham,
		NotifySide = "Right",
		ShowCustomCursor = false,
		GlobalSearch = true,
		SidebarCompacted = compactLayout,
		MinSidebarWidth = 166,
		MinContainerWidth = 280,
		TabButtonsStyle = { Gap = 6, Padding = 10, CornerRadius = 6, Indicator = true, IndicatorWidth = 3, IndicatorHeight = 18 },
		Animations = { ToggleWindow = true, TabSwitch = true, Groupbox = false, Dropdown = true, KeyPicker = true },
	})
	local tabs = {
		Farm = window:AddTab("Farm", "swords"),
		Combat = window:AddTab("Combat", "zap"),
		Movement = window:AddTab("Movement", "navigation"),
		Loot = window:AddTab("Loot", "package"),
		ESP = window:AddTab("ESP", "eye"),
		Settings = window:AddTab("Settings", "settings"),
	}
	local farm = tabs.Farm:AddGroupbox({ Side = "Left", Name = "Mob Targets", IconName = "swords" })
	farm:AddToggle("LukihoAutoFarm", { Text = "Auto Farm Mobs", Default = false, Callback = function(value: boolean)
		State.autoFarm = value
		if value then
			State.autoBoss = false
			State.autoLevel = false
			local other = library.Toggles.LukihoBoss
			if other and other.Value then other:SetValue(false) end
			local level = library.Toggles.LukihoAutoLevel
			if level and level.Value then level:SetValue(false) end
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
	farm:AddButton({ Text = "Go to Mob", Tooltip = "Move to the selected mob or its registered spawn.", Func = function() travelToSelected(false) end })
	farm:AddSlider("LukihoRadius", { Text = "Search Radius", Min = 50, Max = 5000, Default = 1000, Rounding = 0, Callback = function(value: number) State.searchRadius = value end })
	farm:AddSlider("LukihoOffset", { Text = "Behind Target", Min = 0, Max = 20, Default = 4.5, Rounding = 1, Callback = function(value: number) State.attackOffset = value end })
	farm:AddSlider("LukihoHeight", { Text = "Attack Height", Min = -20, Max = 20, Default = -6, Rounding = 1, Callback = function(value: number) State.attackHeight = value end })
	farm:AddSlider("LukihoDodge", { Text = "Dodge Height", Min = 0, Max = 50, Default = 22, Rounding = 0, Callback = function(value: number) State.dodgeHeight = value end })
	farm:AddSlider("LukihoTrack", { Text = "Travel Speed", Min = 20, Max = 1000, Default = 180, Rounding = 0, Suffix = " studs/s", Callback = function(value: number) State.trackSpeed = value end })
	local leveling = tabs.Farm:AddGroupbox({ Side = compactLayout and "Left" or "Right", Name = "Quest Route", IconName = "map-pin" })
	leveling:AddToggle("LukihoAutoLevel", { Text = "Auto Level", Default = false, Callback = function(value: boolean)
		State.autoLevel = value
		if value then
			for _, key in { "LukihoAutoFarm", "LukihoBoss" } do
				local other = library.Toggles[key]
				if other and other.Value then other:SetValue(false) end
			end
		else
			State.levelTarget = nil
			State.questGiver = nil
			State.travelDestination = nil
			clearTarget()
			questStatus("Idle")
		end
	end })
	questStatusLabel = leveling:AddLabel("Idle")
	leveling:AddButton({ Text = "Rescan Quest NPCs", Tooltip = "Clear learned conversations and scan every detected quest NPC again.", Func = resetQuestCatalog })
	leveling:AddButton({ Text = "Inspect Quest", Tooltip = "Print quest NPC metadata to the developer console.", Func = inspectQuestData })
	local combat = tabs.Combat:AddGroupbox({ Side = "Left", Name = "Loadout", IconName = "swords" })
	weaponDropdown = combat:AddDropdown("LukihoWeapon", {
		Text = "Hotbar Slot",
		Values = weaponNames,
		AllowNull = true,
		Searchable = true,
		Callback = function(value: string?)
			if updatingWeaponDropdown then return end
			local nextSlot = if value then weaponSlots[value] or tonumber(value:match("^%s*(%d+)")) else nil
			if State.weaponSlot == nextSlot then return end
			State.weaponSlot = nextSlot
			assumedWeaponSlot = nil
			if State.weaponSlot then
				task.spawn(equipWeaponSlot, State.weaponSlot, true)
			end
		end,
	})
	combat:AddSlider("LukihoCombo", { Text = "Combo Interval", Min = 0.2, Max = 0.5, Default = 0.28, Rounding = 2, Callback = function(value: number) State.comboDelay = value end })
	local skills = tabs.Combat:AddGroupbox({ Side = compactLayout and "Left" or "Right", Name = "Skills", IconName = "zap" })
	skills:AddToggle("LukihoSkills", { Text = "Auto Cast", Default = false, Callback = function(value: boolean) State.autoSkills = value end })
	skills:AddDropdown("LukihoSkillKeys", { Text = "Auto Skill Keys", Values = { "Z", "X", "C", "V", "B" }, Multi = true, AllowNull = true, Default = {}, Callback = function(value: {[string]: boolean}) State.selectedSkills = value end })
	skills:AddToggle("LukihoHold", { Text = "Hold Skills", Default = false, Callback = function(value: boolean) State.holdSkill = value; if not value then releaseHold() end end })
	skills:AddDropdown("LukihoHoldKeys", { Text = "Hold Skill Keys", Values = { "Z", "X", "C", "V", "B" }, Multi = true, AllowNull = true, Default = {}, Callback = function(value: {[string]: boolean}) State.holdSkillKeys = value end })
	local bosses = tabs.Farm:AddGroupbox({ Side = compactLayout and "Left" or "Right", Name = "World Bosses", IconName = "skull" })
	bosses:AddToggle("LukihoBoss", { Text = "Farm Registered Bosses", Default = false, Callback = function(value: boolean)
		State.autoBoss = value
		if value then
			State.autoFarm = false
			State.autoLevel = false
			local other = library.Toggles.LukihoAutoFarm
			if other and other.Value then other:SetValue(false) end
			local level = library.Toggles.LukihoAutoLevel
			if level and level.Value then level:SetValue(false) end
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
	bosses:AddButton({ Text = "Go to Boss", Tooltip = "Move to the selected boss or its registered spawn.", Func = function() travelToSelected(true) end })
	bosses:AddSlider("LukihoPatrol", { Text = "Patrol Interval", Min = 0.5, Max = 5, Default = 2, Rounding = 1, Callback = function(value: number) State.patrolInterval = value end })
	local movement = tabs.Movement:AddGroupbox({ Side = "Left", Name = "Traversal", IconName = "navigation" })
	local fly = movement:AddToggle("LukihoFly", { Text = "Fly", Default = false, Callback = function(value: boolean) State.fly = value end })
	fly:AddKeyPicker("LukihoFlyKey", { Text = "Fly", Default = "F", SyncToggleState = true })
	movement:AddSlider("LukihoFlySpeed", { Text = "Fly Speed", Min = 10, Max = 450, Default = 80, Rounding = 0, Callback = function(value: number) State.flySpeed = value end })
	local clip = movement:AddToggle("LukihoClip", { Text = "NoClip", Default = false, Callback = function(value: boolean) State.noclip = value end })
	clip:AddKeyPicker("LukihoClipKey", { Text = "NoClip", Default = "N", SyncToggleState = true })
	local travel = tabs.Movement:AddGroupbox({ Side = compactLayout and "Left" or "Right", Name = "Map Travel", IconName = "map-pin" })
	areaDropdown = travel:AddDropdown("LukihoAreaTravel", {
		Text = "Select Area",
		Values = areaNames,
		AllowNull = true,
		Searchable = true,
		Callback = function(value: string?) State.selectedArea = if value and areaPositions[value] then value else nil end,
	})
	travel:AddButton({ Text = "Go to Area", Tooltip = "Travel to the selected area with temporary noclip.", Func = travelToArea })
	travelTargetDropdown = travel:AddDropdown("LukihoTargetTravel", {
		Text = "Select NPC / Mob",
		Values = travelTargetNames,
		AllowNull = true,
		Searchable = true,
		Callback = function(value: string?) State.selectedTravelTarget = if value and travelTargets[value] then value else nil end,
	})
	travel:AddButton({ Text = "Go to NPC / Mob", Tooltip = "Travel across the full map to the selected NPC, mob, or boss.", Func = travelToCatalogTarget })
	travel:AddButton({ Text = "Stop Travel", Func = cancelManualTravel })
	local speed = tabs.Movement:AddGroupbox({ Side = compactLayout and "Left" or "Right", Name = "Speed & Jump", IconName = "zap" })
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
	local esp = tabs.ESP:AddGroupbox({ Side = "Left", Name = "Map ESP", IconName = "eye" })
	esp:AddToggle("LukihoESP", { Text = "ESP", Default = false, Callback = function(value: boolean) State.espEnabled = value; if not value then clearEsp() end end })
	esp:AddSlider("LukihoESPRadius", { Text = "Display Radius", Min = 100, Max = 10000, Default = 10000, Rounding = 0, Suffix = " studs", Callback = function(value: number) State.espRadius = value end })
	esp:AddToggle("LukihoESPMobs", { Text = "Mobs", Default = true, Callback = function(value: boolean) State.espMobs = value end })
	esp:AddToggle("LukihoESPBosses", { Text = "Bosses", Default = true, Callback = function(value: boolean) State.espBosses = value end })
	esp:AddToggle("LukihoESPQuests", { Text = "Quest NPCs", Default = true, Callback = function(value: boolean) State.espQuests = value end })
	esp:AddToggle("LukihoESPItems", { Text = "Interactables", Default = true, Callback = function(value: boolean) State.espInteractables = value end })
	local settings = tabs.Settings:AddGroupbox({ Side = "Left", Name = "Interface", IconName = "settings" })
	settings:AddLabel("Hub Version: v" .. HUB_VERSION)
	settings:AddLabel("Menu Keybind"):AddKeyPicker("LukihoMenuKey", { Default = "RightControl", NoUI = true, Text = "Menu", Mode = "Toggle" })
	library.ToggleKeybind = library.Options.LukihoMenuKey
	settings:AddButton({ Text = "Unload Hub", Func = unload })
	saves:SetLibrary(library)
	saves:IgnoreThemeSettings()
	saves:SetIgnoreIndexes({ "LukihoMenuKey" })
	theme:SetFolder("LukihoHub/Graphite")
	saves:SetFolder("LukihoHub/configs")
	saves:BuildConfigSection(tabs.Settings)
	theme:ApplyToTab(tabs.Settings)
	saves:LoadAutoloadConfig()
	polishSliderTypography(library.ScreenGui)
end, function(message) return tostring(message) end)

if not loaded then
	warn("[Lukiho] UI failed:", failure)
	unload()
end
