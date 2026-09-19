-- Put NPC models under workspace.Enemies. This script gives them a stable tag
-- that client UI and gameplay systems can query without repeatedly scanning Workspace.

local CollectionService = game:GetService("CollectionService")

local function registerModel(instance, tags)
	if not instance:IsA("Model") then
		return
	end

	local humanoid = instance:FindFirstChildOfClass("Humanoid")
	local rootPart = instance:FindFirstChild("HumanoidRootPart")
	if humanoid and rootPart then
		for _, tag in tags do
			CollectionService:AddTag(instance, tag)
		end
	end
end

local function unregisterModel(instance, tags)
	for _, tag in tags do
		if CollectionService:HasTag(instance, tag) then
			CollectionService:RemoveTag(instance, tag)
		end
	end
end

local function observeFolder(folderName, tags)
	local folder = workspace:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = workspace
	end

	for _, child in folder:GetChildren() do
		registerModel(child, tags)
	end

	folder.ChildAdded:Connect(function(child)
		-- Some spawners parent the model before inserting all of its parts.
		task.defer(registerModel, child, tags)
	end)

	folder.ChildRemoved:Connect(function(child)
		unregisterModel(child, tags)
	end)
end

observeFolder("Enemies", { "Enemy" })
observeFolder("Bosses", { "Enemy", "Boss" })
