--!strict
-- games/aa/eventcard.lua
-- Event card (roguelike modifier) picker.
-- Listens to the server's card-presentation event and auto-selects
-- based on user priority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = {}
local init = require(script.Parent:WaitForChild("init"))
local data = require(script.Parent:WaitForChild("data"))

M.state = {
	autoPick        = false,
	untilWave       = 0,
	onlyDebuffs     = false,
	onlyHighDebuffs = false,
	ignoreBuffs     = false,
	limit           = 0,
	priorityList    = {}, -- ordered list of card names to pick first
}

local pickedSoFar = 0
local lastWaveSeen = 0

----------------------------------------------------------------
-- WAVE / CARD SIGNAL
-- AA broadcasts `event_card_offered` from server_to_client with a
-- payload { wave, cards: {...} }. We listen via the dedicated event.
----------------------------------------------------------------
local offered = init.getServerEvent("event_card_offered")
local picked  = init.getServerEvent("event_card_picked")

local function onOffer(payload)
	if not M.state.autoPick then return end
	local wave = payload and payload.wave or 0
	if M.state.untilWave > 0 and wave > M.state.untilWave then return end

	local cards = (payload and payload.cards) or {}
	local best = nil
	local bestScore = -math.huge
	for _, card in cards do
		local name = card.name or card.Name or ""
		local tier = card.tier or card.Tier or "Common"
		local isDebuff = card.is_debuff or card.isDebuff or false
		local highDebuff = card.high_debuff or card.highDebuff or false

		-- filter buffs when onlyDebuffs / ignoreBuffs is set
		if not isDebuff and (M.state.onlyDebuffs or M.state.ignoreBuffs) then continue end
		if M.state.onlyHighDebuffs and not highDebuff then continue end

		-- priority: explicit list > high-debuff > debuff > buff
		local score = 0
		for i, p in M.state.priorityList do
			if p == name then score = score + (#M.state.priorityList - i + 1) * 10 end
		end
		if isDebuff then score = score + 5 end
		if highDebuff then score = score + 10 end
		if tier == "Mythic" then score = score + 3 end

		if score > bestScore then
			bestScore = score
			best = card
		end
	end

	if best and (M.state.limit == 0 or pickedSoFar < M.state.limit) then
		init.invoke(init.REMOTE.select_roguelike_option, best.id or best.Id)
		pickedSoFar = pickedSoFar + 1
		lastWaveSeen = wave
	end
end

if offered and typeof(offered) == "Instance" then
	-- For Real-time events; AA's offerings are server_to_client events.
	pcall(function()
		(offered :: any).OnClientEvent:Connect(onOffer)
	end)
end

----------------------------------------------------------------
-- TICK (only used to reset counters on wave change)
----------------------------------------------------------------
function M.tick()
	if M.state.untilWave > 0 and lastWaveSeen > M.state.untilWave then
		M.state.autoPick = false
	end
end

function M.resetCounters()
	pickedSoFar = 0
	lastWaveSeen = 0
end

return M
