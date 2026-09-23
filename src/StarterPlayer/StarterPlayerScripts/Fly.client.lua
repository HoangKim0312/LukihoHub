-- Client-side fly toggle for the developer's owned experience.
-- Press F to toggle. Hold Space/Shift for vertical. WASD to strafe.
-- Mouse moves the camera while flying.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FLY_SPEED = 70
local VERTICAL_SPEED = 50
local TOGGLE_KEY = Enum.KeyCode.F

local flying = false
local bodyVelocity
local bodyGyro
local connection

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function attachFly(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent = root

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = 9e4
	bodyGyro.D = 500
	bodyGyro.Parent = root

	humanoid.PlatformStand = true

	connection = RunService.RenderStepped:Connect(function()
		if not flying then
			return
		end
		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move = move + camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move = move - camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move = move - camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move = move + camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move = move + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			move = move - Vector3.new(0, 1, 0)
		end

		if move.Magnitude > 0 then
			move = move.Unit * FLY_SPEED
		end

		bodyVelocity.Velocity = move
		bodyGyro.CFrame = camera.CFrame
	end)
end

local function detachFly(character)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function toggleFly()
	local character = getCharacter()
	if flying then
		flying = false
		detachFly(character)
	else
		flying = true
		attachFly(character)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == TOGGLE_KEY then
		toggleFly()
	end
end)

player.CharacterAdded:Connect(function(character)
	if flying then
		task.wait()
		flying = false
		detachFly(character)
	end
end)
