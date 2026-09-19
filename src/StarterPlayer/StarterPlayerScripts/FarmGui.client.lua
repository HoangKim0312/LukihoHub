local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ENEMY_TAG = "Enemy"
local GUI_NAME = "FarmControlGui"

local COLORS = {
	background = Color3.fromRGB(13, 13, 15),
	sidebar = Color3.fromRGB(16, 16, 18),
	panel = Color3.fromRGB(19, 19, 22),
	field = Color3.fromRGB(28, 28, 32),
	fieldHover = Color3.fromRGB(35, 35, 40),
	border = Color3.fromRGB(48, 48, 55),
	text = Color3.fromRGB(238, 238, 242),
	muted = Color3.fromRGB(148, 148, 158),
	accent = Color3.fromRGB(132, 77, 255),
	accentDark = Color3.fromRGB(80, 45, 160),
	success = Color3.fromRGB(74, 201, 126),
	danger = Color3.fromRGB(230, 91, 91),
}

local settings = {
	autoFarm = false,
	searchRadius = 1000,
	selectedMob = nil,
	weaponSlot = "Slot 1",
	undergroundRange = -6,
	positionType = "Above",
	offsetDistance = 4.5,
	heightOffset = 0,
	trackSpeed = 400,
	semiKillAura = false,
	semiKillAuraSkill = "Z",
	autoUseSkills = false,
	autoSkills = "Z,X,C,V,B",
	autoLootTravel = false,
	lootTravelRadius = 150,
	autoFarmBoss = false,
	selectedBoss = "All Registered Bosses",
	bossPatrolWait = 1,
	developerFly = false,
	flySpeed = 200,
	flyVerticalSpeed = 150,
	developerNoClip = false,
	developerSpeed = false,
	walkSpeed = 32,
	infiniteJump = false,
	jumpBoost = 50,
	autoOpenChest = false,
	autoCollectLoot = false,
	selectedChestTier = "All",
	autoFarmChest = false,
	lootRadius = 40,
}

local preferredScale = 1
local updateResponsiveSize

local previousGui = playerGui:FindFirstChild(GUI_NAME)
if previousGui then
	previousGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local function create(className, properties)
	local instance = Instance.new(className)
	for property, value in properties do
		instance[property] = value
	end
	return instance
end

local function corner(parent, radius)
	create("UICorner", {
		CornerRadius = UDim.new(0, radius or 5),
		Parent = parent,
	})
end

local function stroke(parent, color, thickness)
	create("UIStroke", {
		Color = color or COLORS.border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function label(parent, text, size, color, font)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size + 8),
		Font = font or Enum.Font.Code,
		Text = text,
		TextColor3 = color or COLORS.text,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	})
end

local root = create("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 500),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = screenGui,
})
corner(root, 6)
stroke(root)

local uiScale = create("UIScale", {
	Scale = 1,
	Parent = root,
})

local sidebar = create("Frame", {
	Name = "Sidebar",
	Size = UDim2.new(0, 220, 1, 0),
	BackgroundColor3 = COLORS.sidebar,
	BorderSizePixel = 0,
	Parent = root,
})

create("Frame", {
	Position = UDim2.new(1, -1, 0, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = COLORS.border,
	BorderSizePixel = 0,
	Parent = sidebar,
})

local titleBar = create("Frame", {
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
	Parent = sidebar,
})

local brandMark = create("Frame", {
	Position = UDim2.fromOffset(18, 17),
	Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = COLORS.accent,
	BorderSizePixel = 0,
	Parent = titleBar,
})
corner(brandMark, 5)

local brandLetter = label(brandMark, "L", 16, COLORS.text, Enum.Font.GothamBold)
brandLetter.Size = UDim2.fromScale(1, 1)
brandLetter.TextXAlignment = Enum.TextXAlignment.Center
brandLetter.TextYAlignment = Enum.TextYAlignment.Center

local title = label(titleBar, "LUKIHO", 17, COLORS.text, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(54, 10)
title.Size = UDim2.new(1, -70, 0, 25)

local subtitle = label(titleBar, "AUTOMATION CONSOLE", 10, COLORS.muted, Enum.Font.GothamMedium)
subtitle.Position = UDim2.fromOffset(54, 32)
subtitle.Size = UDim2.new(1, -70, 0, 16)

create("Frame", {
	Position = UDim2.new(0, 0, 0, 59),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = COLORS.border,
	BorderSizePixel = 0,
	Parent = sidebar,
})

local navigation = create("Frame", {
	Position = UDim2.fromOffset(0, 68),
	Size = UDim2.new(1, 0, 1, -126),
	BackgroundTransparency = 1,
	Parent = sidebar,
})

local footer = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundTransparency = 1,
	Parent = sidebar,
})

create("Frame", {
	Position = UDim2.fromOffset(18, 0),
	Size = UDim2.new(1, -36, 0, 1),
	BackgroundColor3 = COLORS.border,
	BorderSizePixel = 0,
	Parent = footer,
})

local creator = label(footer, "Created by Lukiho", 11, COLORS.muted, Enum.Font.GothamMedium)
creator.Position = UDim2.fromOffset(18, 9)
creator.Size = UDim2.new(1, -36, 0, 18)

local version = label(footer, "v1.0  /  OWNED EXPERIENCE", 9, COLORS.muted, Enum.Font.Gotham)
version.Position = UDim2.fromOffset(18, 27)
version.Size = UDim2.new(1, -36, 0, 16)
create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = navigation,
})

local content = create("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(220, 0),
	Size = UDim2.new(1, -220, 1, 0),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
	Parent = root,
})

local topBar = create("Frame", {
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
	Parent = content,
})

local searchBox = create("TextBox", {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -132, 0, 40),
	BackgroundColor3 = COLORS.field,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Code,
	PlaceholderText = "Search settings or detected mobs...",
	PlaceholderColor3 = COLORS.muted,
	Text = "",
	TextColor3 = COLORS.text,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = topBar,
})
corner(searchBox, 5)
stroke(searchBox)
create("UIPadding", {
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 14),
	Parent = searchBox,
})

local status = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 10),
	Size = UDim2.fromOffset(90, 40),
	BackgroundColor3 = COLORS.field,
	BorderSizePixel = 0,
	Parent = topBar,
})
corner(status, 5)
stroke(status)

local statusDot = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(7, 7),
	BackgroundColor3 = COLORS.success,
	BorderSizePixel = 0,
	Parent = status,
})
corner(statusDot, 4)

local statusText = label(status, "UI ONLY", 10, COLORS.text, Enum.Font.GothamBold)
statusText.Position = UDim2.fromOffset(27, 0)
statusText.Size = UDim2.new(1, -32, 1, 0)
statusText.TextYAlignment = Enum.TextYAlignment.Center

local pagesHost = create("Frame", {
	Position = UDim2.fromOffset(0, 60),
	Size = UDim2.new(1, 0, 1, -60),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = content,
})

local pages = {}
local navButtons = {}
local activePageName = "Farm"

local function newPage(name)
	local page = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.accent,
		Visible = name == activePageName,
		Parent = pagesHost,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 16),
		Parent = page,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	pages[name] = page
	return page
end

local function selectPage(name)
	activePageName = name
	for pageName, page in pages do
		page.Visible = pageName == name
	end
	for buttonName, button in navButtons do
		local active = buttonName == name
		button.BackgroundColor3 = active and COLORS.panel or COLORS.sidebar
		button.TextColor3 = active and COLORS.text or COLORS.muted
	end
	searchBox.Text = ""
end

local function navButton(name, order)
	local button = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = name == activePageName and COLORS.panel or COLORS.sidebar,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.Code,
		Text = "   " .. name,
		TextColor3 = name == activePageName and COLORS.text or COLORS.muted,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = navigation,
	})
	button.MouseButton1Click:Connect(function()
		selectPage(name)
	end)
	navButtons[name] = button
	return button
end

navButton("Farm", 1)
navButton("Movement", 2)
navButton("Chests & Loot", 3)
navButton("UI Settings", 4)

local farmPage = newPage("Farm")
local movementPage = newPage("Movement")
local lootPage = newPage("Chests & Loot")
local uiPage = newPage("UI Settings")

local function section(parent, heading, description)
	local frame = create("Frame", {
		Name = heading,
		Size = UDim2.new(1, 0, 0, 80),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	corner(frame, 5)
	stroke(frame)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		Parent = frame,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	label(frame, heading, 15, COLORS.text, Enum.Font.Code)
	if description then
		label(frame, description, 12, COLORS.muted, Enum.Font.Code)
	end
	return frame
end

local function button(parent, text, callback)
	local control = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = COLORS.field,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.Code,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 13,
		Parent = parent,
	})
	corner(control, 4)
	stroke(control)
	control.MouseEnter:Connect(function()
		control.BackgroundColor3 = control:GetAttribute("Selected") and COLORS.accentDark or COLORS.fieldHover
	end)
	control.MouseLeave:Connect(function()
		control.BackgroundColor3 = control:GetAttribute("Selected") and COLORS.accentDark or COLORS.field
	end)
	if callback then
		control.MouseButton1Click:Connect(callback)
	end
	return control
end

local function toggle(parent, text, initialValue, callback)
	local value = initialValue
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local textLabel = label(row, text, 13, COLORS.text)
	textLabel.Size = UDim2.new(1, -56, 1, 0)

	local track = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 22),
		BackgroundColor3 = value and COLORS.accent or COLORS.field,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})
	corner(track, 11)
	stroke(track)

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = value and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = COLORS.text,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(knob, 8)

	track.MouseButton1Click:Connect(function()
		value = not value
		track.BackgroundColor3 = value and COLORS.accent or COLORS.field
		knob.Position = value and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0)
		callback(value)
	end)
	return row
end

local function slider(parent, text, minimum, maximum, initialValue, step, callback, formatter)
	local value = initialValue
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local nameLabel = label(row, text, 13, COLORS.text)
	nameLabel.Size = UDim2.new(0.65, 0, 0, 24)

	local valueLabel = label(row, "", 12, COLORS.muted)
	valueLabel.Position = UDim2.new(0.65, 0, 0, 0)
	valueLabel.Size = UDim2.new(0.35, 0, 0, 24)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local track = create("TextButton", {
		Position = UDim2.fromOffset(0, 31),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = COLORS.field,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})
	corner(track, 3)
	stroke(track)

	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(fill, 3)

	local dragging = false
	local function setValue(newValue)
		newValue = math.clamp(newValue, minimum, maximum)
		newValue = math.round(newValue / step) * step
		value = newValue
		fill.Size = UDim2.fromScale((value - minimum) / (maximum - minimum), 1)
		valueLabel.Text = formatter and formatter(value) or tostring(value)
		callback(value)
	end

	local function setFromInput(input)
		local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(minimum + ((maximum - minimum) * ratio))
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromInput(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromInput(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	setValue(initialValue)
	return row
end

local function cycle(parent, text, values, initialIndex, callback)
	local index = initialIndex
	local control = button(parent, text .. ": " .. tostring(values[index]))
	control.MouseButton1Click:Connect(function()
		index = (index % #values) + 1
		control.Text = text .. ": " .. tostring(values[index])
		callback(values[index])
	end)
	return control
end

local autoFarmSection = section(farmPage, "Auto Farm Mobs", "Select a detected NPC type before enabling.")
toggle(autoFarmSection, "Auto Farm Mobs", settings.autoFarm, function(value)
	settings.autoFarm = value
	screenGui:SetAttribute("AutoFarm", value)
	screenGui:SetAttribute("AutoFarmMobs", value)
end)
slider(autoFarmSection, "Mob Search Radius", 100, 5000, settings.searchRadius, 50, function(value)
	settings.searchRadius = value
	screenGui:SetAttribute("SearchRadius", value)
end, function(value)
	return string.format("%d / 5000", value)
end)

local detectedSection = section(farmPage, "Detected Mobs", "Tagged NPCs are preferred; valid Humanoid models are the fallback.")
local detectedSummary = label(detectedSection, "Scanning...", 12, COLORS.muted)
local mobList = create("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = detectedSection,
})
create("UIListLayout", {
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = mobList,
})

local farmSettingsSection = section(farmPage, "Farm Settings")
cycle(farmSettingsSection, "Weapon Slot", { "None", "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5" }, 2, function(value)
	settings.weaponSlot = value
	screenGui:SetAttribute("WeaponSlot", value)
end)
slider(farmSettingsSection, "Underground Attack Range", -20, 0, settings.undergroundRange, 1, function(value)
	settings.undergroundRange = value
	screenGui:SetAttribute("UndergroundRange", value)
end, function(value)
	return string.format("%d / 0", value)
end)

toggle(farmSettingsSection, "Hold Skill Mode", settings.semiKillAura, function(value)
	settings.semiKillAura = value
	screenGui:SetAttribute("HoldSkillMode", value)
end)
cycle(farmSettingsSection, "Held Skill", { "Z", "X", "C", "V", "B" }, 1, function(value)
	settings.semiKillAuraSkill = value
	screenGui:SetAttribute("HeldSkill", value)
end)
toggle(farmSettingsSection, "Auto Use Skills", settings.autoUseSkills, function(value)
	settings.autoUseSkills = value
	screenGui:SetAttribute("AutoUseSkills", value)
end)
cycle(farmSettingsSection, "Skill Loadout", { "Z,X,C,V,B", "Z,X,C", "V,B", "Z" }, 1, function(value)
	settings.autoSkills = value
	screenGui:SetAttribute("AutoSkills", value)
end)
toggle(farmSettingsSection, "Travel to Nearby Loot", settings.autoLootTravel, function(value)
	settings.autoLootTravel = value
	screenGui:SetAttribute("AutoLootTravel", value)
end)
slider(farmSettingsSection, "Loot Travel Radius", 20, 500, settings.lootTravelRadius, 10, function(value)
	settings.lootTravelRadius = value
	screenGui:SetAttribute("LootTravelRadius", value)
end, function(value)
	return string.format("%d studs", value)
end)

local bossSection = section(farmPage, "World Boss", "Use the Boss tag or place boss models under workspace.Bosses.")
toggle(bossSection, "Auto Farm Registered Bosses", settings.autoFarmBoss, function(value)
	settings.autoFarmBoss = value
	screenGui:SetAttribute("AutoFarmBoss", value)
end)
cycle(bossSection, "Boss Filter", { "All Registered Bosses", "Event Bosses", "Nearest Boss" }, 1, function(value)
	settings.selectedBoss = value
	screenGui:SetAttribute("SelectedBoss", value)
end)
slider(bossSection, "Patrol Stream Wait", 0.5, 3, settings.bossPatrolWait, 0.1, function(value)
	settings.bossPatrolWait = value
	screenGui:SetAttribute("BossPatrolWait", value)
end, function(value)
	return string.format("%.1f s", value)
end)

local movementSection = section(movementPage, "Target Tracking", "Movement values are exposed as GUI attributes for your controller.")
cycle(movementSection, "Position Type", { "Above", "Behind", "Below", "Front" }, 1, function(value)
	settings.positionType = value
	screenGui:SetAttribute("PositionType", value)
end)
slider(movementSection, "Offset Distance", 0, 100, settings.offsetDistance, 0.5, function(value)
	settings.offsetDistance = value
	screenGui:SetAttribute("OffsetDistance", value)
end, function(value)
	return string.format("%.1f / 100 studs", value)
end)
slider(movementSection, "Height Offset", -50, 50, settings.heightOffset, 1, function(value)
	settings.heightOffset = value
	screenGui:SetAttribute("HeightOffset", value)
end, function(value)
	return string.format("%d / 50 studs", value)
end)
slider(movementSection, "Track Speed", 50, 1000, settings.trackSpeed, 25, function(value)
	settings.trackSpeed = value
	screenGui:SetAttribute("TrackSpeed", value)
end, function(value)
	return string.format("%d / 1000 studs/s", value)
end)

local developerMovementSection = section(movementPage, "Developer Movement", "Only connect these controls to permission-checked server tools.")
toggle(developerMovementSection, "Developer Flight", settings.developerFly, function(value)
	settings.developerFly = value
	screenGui:SetAttribute("DeveloperFly", value)
end)
slider(developerMovementSection, "Flight Speed", 0, 450, settings.flySpeed, 10, function(value)
	settings.flySpeed = value
	screenGui:SetAttribute("FlySpeed", value)
end, function(value)
	return string.format("%d studs/s", value)
end)
slider(developerMovementSection, "Vertical Flight Speed", 0, 450, settings.flyVerticalSpeed, 10, function(value)
	settings.flyVerticalSpeed = value
	screenGui:SetAttribute("FlyVerticalSpeed", value)
end, function(value)
	return string.format("%d studs/s", value)
end)
toggle(developerMovementSection, "Developer NoClip", settings.developerNoClip, function(value)
	settings.developerNoClip = value
	screenGui:SetAttribute("DeveloperNoClip", value)
end)

local movementOverrideSection = section(movementPage, "Movement Override")
toggle(movementOverrideSection, "Custom Walk Speed", settings.developerSpeed, function(value)
	settings.developerSpeed = value
	screenGui:SetAttribute("CustomWalkSpeedEnabled", value)
end)
slider(movementOverrideSection, "Walk Speed", 16, 100, settings.walkSpeed, 1, function(value)
	settings.walkSpeed = value
	screenGui:SetAttribute("WalkSpeed", value)
end, function(value)
	return string.format("%d studs/s", value)
end)
toggle(movementOverrideSection, "Extended Jump", settings.infiniteJump, function(value)
	settings.infiniteJump = value
	screenGui:SetAttribute("ExtendedJump", value)
end)
slider(movementOverrideSection, "Jump Boost", 0, 200, settings.jumpBoost, 5, function(value)
	settings.jumpBoost = value
	screenGui:SetAttribute("JumpBoost", value)
end, function(value)
	return string.format("%d studs/s", value)
end)

local lootSection = section(lootPage, "Chests & Drops", "Connect prompt requests to a server-side distance and ownership check.")
toggle(lootSection, "Auto Open Nearby Chests", settings.autoOpenChest, function(value)
	settings.autoOpenChest = value
	screenGui:SetAttribute("AutoOpenChest", value)
end)
toggle(lootSection, "Auto Collect Loot", settings.autoCollectLoot, function(value)
	settings.autoCollectLoot = value
	screenGui:SetAttribute("AutoCollectLoot", value)
end)
cycle(lootSection, "Chest Tier", { "All", "Common", "Rare", "T1", "T2", "T3", "T4", "T5" }, 1, function(value)
	settings.selectedChestTier = value
	screenGui:SetAttribute("SelectedChestTier", value)
end)
toggle(lootSection, "Auto Farm Sealed Chests", settings.autoFarmChest, function(value)
	settings.autoFarmChest = value
	screenGui:SetAttribute("AutoFarmChest", value)
end)
slider(lootSection, "Loot Detection Radius", 10, 100, settings.lootRadius, 5, function(value)
	settings.lootRadius = value
	screenGui:SetAttribute("LootRadius", value)
end, function(value)
	return string.format("%d studs", value)
end)

local uiSettingsSection = section(uiPage, "Interface", "Clean local UI with no remotely loaded library.")
cycle(uiSettingsSection, "Notification Side", { "Right", "Left" }, 1, function(value)
	screenGui:SetAttribute("NotificationSide", value)
end)
slider(uiSettingsSection, "Interface Scale", 0.75, 1.25, preferredScale, 0.05, function(value)
	preferredScale = value
	screenGui:SetAttribute("InterfaceScale", value)
	if updateResponsiveSize then
		updateResponsiveSize()
	end
end, function(value)
	return string.format("%d%%", math.round(value * 100))
end)
toggle(uiSettingsSection, "Show Runtime Stats", false, function(value)
	screenGui:SetAttribute("ShowRuntimeStats", value)
end)
button(uiSettingsSection, "Hide Interface", function()
	root.Visible = false
end)
label(uiSettingsSection, "RightShift toggles the interface.", 12, COLORS.muted)

local aboutSection = section(uiPage, "About")
label(aboutSection, "Lukiho Automation Console", 14, COLORS.text, Enum.Font.GothamBold)
label(aboutSection, "Created by Lukiho", 12, COLORS.muted, Enum.Font.Gotham)
label(aboutSection, "Built for a server-authoritative Roblox experience.", 11, COLORS.muted, Enum.Font.Gotham)

local function getCharacterRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isPlayerCharacter(model)
	return Players:GetPlayerFromCharacter(model) ~= nil
end

local function isValidEnemy(model)
	if not model:IsA("Model") or isPlayerCharacter(model) then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and rootPart ~= nil
end

local function collectEnemies()
	local unique = {}
	local enemies = {}

	local function add(model)
		if unique[model] or not isValidEnemy(model) then
			return
		end
		unique[model] = true
		table.insert(enemies, model)
	end

	for _, tagged in CollectionService:GetTagged(ENEMY_TAG) do
		add(tagged)
	end

	-- Compatibility fallback for an existing game that has not added tags yet.
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, child in enemiesFolder:GetChildren() do
			add(child)
		end
	end

	-- Spatial discovery is intentionally a last resort. On large maps it is more
	-- expensive than querying a tag or a dedicated NPC folder.
	local characterRoot = getCharacterRoot()
	if #enemies == 0 and characterRoot then
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = player.Character and { player.Character } or {}
		for _, part in workspace:GetPartBoundsInRadius(characterRoot.Position, settings.searchRadius, overlap) do
			local model = part:FindFirstAncestorOfClass("Model")
			if model then
				add(model)
			end
		end
	end

	return enemies
end

local function refreshMobList()
	for _, child in mobList:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local counts = {}
	local total = 0
	for _, enemy in collectEnemies() do
		counts[enemy.Name] = (counts[enemy.Name] or 0) + 1
		total += 1
	end

	local names = {}
	for name in counts do
		table.insert(names, name)
	end
	table.sort(names)
	detectedSummary.Text = string.format("%d active NPC(s), %d type(s)", total, #names)
	if settings.selectedMob and not counts[settings.selectedMob] then
		settings.selectedMob = nil
		screenGui:SetAttribute("SelectedMob", nil)
	end

	if #names == 0 then
		local empty = label(mobList, "No NPC found in the current radius.", 12, COLORS.muted)
		empty.Name = "EmptyState"
		return
	end

	for _, name in names do
		local mobName = name
		local entry = button(mobList, string.format("%s  (%d)", mobName, counts[mobName]), function()
			settings.selectedMob = mobName
			screenGui:SetAttribute("SelectedMob", mobName)
			for _, item in mobList:GetChildren() do
				if item:IsA("TextButton") then
					local selected = item.Name == mobName
					item:SetAttribute("Selected", selected)
					item.BackgroundColor3 = selected and COLORS.accentDark or COLORS.field
				end
			end
		end)
		entry.Name = mobName
		local query = string.lower(searchBox.Text)
		entry.Visible = query == "" or string.find(string.lower(mobName), query, 1, true) ~= nil
		if settings.selectedMob == mobName then
			entry:SetAttribute("Selected", true)
			entry.BackgroundColor3 = COLORS.accentDark
		end
	end
end

button(detectedSection, "Refresh NPC list", refreshMobList)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local query = string.lower(searchBox.Text)
	local function containsQuery(instance)
		if query == "" then
			return true
		end
		if string.find(string.lower(instance.Name), query, 1, true) then
			return true
		end
		for _, descendant in instance:GetDescendants() do
			if (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
				and string.find(string.lower(descendant.Text), query, 1, true) then
				return true
			end
		end
		return false
	end

	for _, page in pages do
		for _, child in page:GetChildren() do
			if child:IsA("Frame") then
				child.Visible = containsQuery(child)
			end
		end
	end
	for _, item in mobList:GetChildren() do
		if item:IsA("TextButton") then
			item.Visible = query == "" or string.find(string.lower(item.Name), query, 1, true) ~= nil
		end
	end
end)

local draggingWindow = false
local dragStart
local startPosition

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingWindow = true
		dragStart = input.Position
		startPosition = root.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingWindow and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingWindow = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.RightShift then
		root.Visible = not root.Visible
	end
end)

local camera = workspace.CurrentCamera
updateResponsiveSize = function()
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local fitScale = math.min((viewport.X - 24) / 760, (viewport.Y - 24) / 500)
	uiScale.Scale = math.min(preferredScale, fitScale)
	root.Size = UDim2.fromOffset(760, 500)
end

if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveSize)
end
updateResponsiveSize()

screenGui:SetAttribute("AutoFarm", settings.autoFarm)
screenGui:SetAttribute("AutoFarmMobs", settings.autoFarm)
screenGui:SetAttribute("SearchRadius", settings.searchRadius)
screenGui:SetAttribute("WeaponSlot", settings.weaponSlot)
screenGui:SetAttribute("UndergroundRange", settings.undergroundRange)
screenGui:SetAttribute("PositionType", settings.positionType)
screenGui:SetAttribute("OffsetDistance", settings.offsetDistance)
screenGui:SetAttribute("HeightOffset", settings.heightOffset)
screenGui:SetAttribute("TrackSpeed", settings.trackSpeed)
screenGui:SetAttribute("HoldSkillMode", settings.semiKillAura)
screenGui:SetAttribute("HeldSkill", settings.semiKillAuraSkill)
screenGui:SetAttribute("AutoUseSkills", settings.autoUseSkills)
screenGui:SetAttribute("AutoSkills", settings.autoSkills)
screenGui:SetAttribute("AutoLootTravel", settings.autoLootTravel)
screenGui:SetAttribute("LootTravelRadius", settings.lootTravelRadius)
screenGui:SetAttribute("AutoFarmBoss", settings.autoFarmBoss)
screenGui:SetAttribute("SelectedBoss", settings.selectedBoss)
screenGui:SetAttribute("BossPatrolWait", settings.bossPatrolWait)
screenGui:SetAttribute("DeveloperFly", settings.developerFly)
screenGui:SetAttribute("FlySpeed", settings.flySpeed)
screenGui:SetAttribute("FlyVerticalSpeed", settings.flyVerticalSpeed)
screenGui:SetAttribute("DeveloperNoClip", settings.developerNoClip)
screenGui:SetAttribute("CustomWalkSpeedEnabled", settings.developerSpeed)
screenGui:SetAttribute("WalkSpeed", settings.walkSpeed)
screenGui:SetAttribute("ExtendedJump", settings.infiniteJump)
screenGui:SetAttribute("JumpBoost", settings.jumpBoost)
screenGui:SetAttribute("AutoOpenChest", settings.autoOpenChest)
screenGui:SetAttribute("AutoCollectLoot", settings.autoCollectLoot)
screenGui:SetAttribute("SelectedChestTier", settings.selectedChestTier)
screenGui:SetAttribute("AutoFarmChest", settings.autoFarmChest)
screenGui:SetAttribute("LootRadius", settings.lootRadius)
screenGui:SetAttribute("NotificationSide", "Right")
screenGui:SetAttribute("InterfaceScale", preferredScale)
screenGui:SetAttribute("ShowRuntimeStats", false)

refreshMobList()

CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(refreshMobList)
CollectionService:GetInstanceRemovedSignal(ENEMY_TAG):Connect(refreshMobList)

task.spawn(function()
	while screenGui.Parent do
		task.wait(5)
		if activePageName == "Farm" and root.Visible then
			refreshMobList()
		end
	end
end)
