--!strict
-- games/aa/misc.lua
-- Misc features:
--   Discord webhook
--   Hide UI on execute
--   Redeem ALL codes
--   Set FPS cap
--   Hide map / Hide names
--   Fake outfit
--   Auto Execute
--   Auto Try Reconnect
--   Colored / show takedowns
--   Auto claim quests + auto take daily quests
--   Auto claim daily rewards

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")

local M = {}
local init = require(script.Parent:WaitForChild("init"))
local data = require(script.Parent:WaitForChild("data"))

local player = Players.LocalPlayer

M.state = {
	webhookURL       = "",
	pingUserID       = "",
	pingOnSelected   = {},
	pingOnSecretDrop = false,

	autoHideUI       = false,
	hideMap          = false,
	hideName         = false,
	fakeOutfit       = false,
	autoReconnect    = false,
	showTakedowns    = true,
	coloredTakedowns = false,
	setFps           = 0, -- 0 = unchanged

	autoClaimQuests      = false,
	autoTakeDailyQuests  = false,
	autoClaimDaily       = true,
	autoClaimPlayerLevel = true,
}

----------------------------------------------------------------
-- WEBHOOK
----------------------------------------------------------------
function M.postWebhook(url: string, payload: { [string]: any })
	if url == nil or url == "" then return end
	local body = HttpService:JSONEncode(payload)
	pcall(function()
		HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
	end)
end

function M.notifyWebhook(title: string, description: string, color: number?, ping: boolean?)
	if M.state.webhookURL == "" then return end
	local payload = {
		username = "LukihoHub",
		embeds = {
			{
				title = title,
				description = description,
				color = color or 0x00BFFF,
				footer = { text = "Anime Adventures" },
			},
		},
	}
	if ping and M.state.pingUserID ~= "" then
		payload.content = "<@" .. M.state.pingUserID .. ">"
	end
	M.postWebhook(M.state.webhookURL, payload)
end

----------------------------------------------------------------
-- HIDES
----------------------------------------------------------------
function M.setUIHidden(hidden: boolean)
	M.state.autoHideUI = hidden
	-- Hide UI injected by the game by walking PlayerGui descendants
	-- and toggling Enabled. (MacLib window is excluded by Name check.)
	pcall(function()
		local gui = player:WaitForChild("PlayerGui", 5)
		if not gui then return end
		for _, screen in gui:GetDescendants() do
			if screen:IsA("ScreenGui") and screen.Name ~= "LukihoHub" then
				screen.Enabled = not hidden
			end
		end
	end)
end

function M.setMapHidden(hidden: boolean)
	M.state.hideMap = hidden
	-- Walk workspace, hide Parts/MeshParts named or tagged like map tiles.
	-- AA doesn't have a single "map" folder, so we toggle Lighting
	-- ambient + clear the workspace tiles by tag if available.
	pcall(function()
		for _, d in Workspace:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("IsMapPiece") then
				d.Transparency = if hidden then 1 else d:GetAttribute("DefaultTransparency") or 0
			end
		end
	end)
end

function M.setNamesHidden(hidden: boolean)
	M.state.hideName = hidden
	pcall(function()
		for _, p in Workspace:GetDescendants() do
			if p:IsA("BillboardGui") and p.Name:lower():find("name", 1, true) then
				p.Enabled = not hidden
			end
		end
	end)
end

function M.setFakeOutfit(enabled: boolean)
	M.state.fakeOutfit = enabled
	-- Best-effort: AA hides player avatar via CharacterAppearanceLoaded;
	-- we set character parts transparent.
	pcall(function()
		local char = player.Character
		if not char then return end
		for _, part in char:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = if enabled then 1 else 0
			end
		end
	end)
end

----------------------------------------------------------------
-- FPS
----------------------------------------------------------------
function M.setFps(cap: number)
	M.state.setFps = cap
	if cap > 0 then
		pcall(function() setfpscap(cap) end)
	end
end

----------------------------------------------------------------
-- RECONNECT
----------------------------------------------------------------
local reconnecting = false
function M.tryReconnect()
	if reconnecting then return end
	reconnecting = true
	pcall(function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, player)
	end)
end

local function watchDisconnect()
	-- AA's own rejoin handler exists; we add a backup.
	player.PlayerRemoving:Connect(function()
		if M.state.autoReconnect then
			task.delay(2, function()
				pcall(function()
					game:GetService("TeleportService"):Teleport(game.PlaceId)
				end)
			end)
		end
	end)
end

watchDisconnect()

----------------------------------------------------------------
-- TAKEDOWNS
----------------------------------------------------------------
local takedownCount = 0
function M.bumpTakedowns(n: number)
	takedownCount = takedownCount + n
	local color = if M.state.coloredTakedowns
		then Color3.fromRGB(255, 60, 60)
		else Color3.fromRGB(255, 255, 255)
	M.notifyWebhook(
		"Takedown update",
		string.format("Takedowns: %d", takedownCount),
		0xFF3C3C
	)
end

function M.showTakedowns()
	if not M.state.showTakedowns then return end
	init.notify("LukihoHub", "Takedowns: " .. takedownCount)
end

----------------------------------------------------------------
-- CODES
----------------------------------------------------------------
function M.redeemAllCodes()
	for _, code in data.KNOWN_CODES do
		init.invoke(init.REMOTE.redeem_code, code)
	end
end

----------------------------------------------------------------
-- DAILY REWARDS / QUESTS
----------------------------------------------------------------
function M.claimDaily()
	if M.state.autoClaimDaily then
		init.invoke(init.REMOTE.claim_daily_reward)
	end
	if M.state.autoClaimPlayerLevel then
		init.invoke(init.REMOTE.claim_player_level_rewards)
	end
end

function M.takeDailyQuests()
	init.invoke(init.REMOTE.request_dailymissions_data)
end

function M.claimQuests()
	if not M.state.autoClaimQuests then return end
	-- AA exposes request_claim_mission / request_claim_dailymission
	-- for the active mission id. We poll quest data first.
	local daily = init.invoke(init.REMOTE.request_dailymissions_data) or {}
	for _, q in daily do
		if q.id then
			init.invoke(init.REMOTE.request_claim_dailymission, q.id)
		end
	end
	local main = init.invoke(init.REMOTE.request_missions_data) or {}
	for _, q in main do
		if q.id then
			init.invoke(init.REMOTE.request_claim_mission, q.id)
		end
	end
end

----------------------------------------------------------------
-- AUTO EXECUTE
-- Watch for game.JoinServer → re-load our own loader URL.
----------------------------------------------------------------
function M.bindAutoExecute(loaderUrl: string)
	if M.state.autoReconnect and loaderUrl ~= "" then
		game:GetService("GuiService").ErrorMessageChanged:Connect(function()
			pcall(function()
				loadstring(game:HttpGet(loaderUrl))()
			end)
		end)
	end
end

----------------------------------------------------------------
-- TICK
----------------------------------------------------------------
function M.tick()
	if M.state.autoTakeDailyQuests then
		M.takeDailyQuests()
		M.state.autoTakeDailyQuests = false
	end
	M.claimQuests()
	M.claimDaily()
end

return M
