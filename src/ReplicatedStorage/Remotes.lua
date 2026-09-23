-- Centralized remote event/function registry for the macro system.
-- Bootstraps itself on the server and exposes a shared reference on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}
Remotes.FolderName = "MacroRemotes"

local function createRemote(className, name)
	local instance = Instance.new(className)
	instance.Name = name
	return instance
end

function Remotes.bootstrap()
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Remotes.FolderName
		folder.Parent = ReplicatedStorage
	end

	local function ensure(className, name)
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local instance = createRemote(className, name)
		instance.Parent = folder
		return instance
	end

	return {
		Folder = folder,
		PlaceUnit = ensure("RemoteEvent", "PlaceUnit"),
		UpgradeUnit = ensure("RemoteEvent", "UpgradeUnit"),
		SellUnit = ensure("RemoteEvent", "SellUnit"),
		SetTargetPriority = ensure("RemoteEvent", "SetTargetPriority"),
		UseAbility = ensure("RemoteEvent", "UseAbility"),
		MacroPlay = ensure("RemoteFunction", "MacroPlay"),
		MacroRecordEvent = ensure("RemoteEvent", "MacroRecordEvent"),
		MacroLoadRequest = ensure("RemoteFunction", "MacroLoadRequest"),
	}
end

return Remotes
