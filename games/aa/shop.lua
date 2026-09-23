--!strict
-- games/aa/shop.lua
-- Shop / inventory helpers: Delete Portal, Auto Open Capsules, Auto Sell Skins.

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = {}

local init = require(script.Parent:WaitForChild("init"))
local data = require(script.Parent:WaitForChild("data"))

local player = Players.LocalPlayer

M.state = {
	autoDeletePortal       = false,
	autoOpenCapsules       = false,
	autoSellSkins          = false,
	capsuleType            = "Standard",
	skinMinRarity          = "Rare",
	deletePortalMinTier    = "T3",
}

----------------------------------------------------------------
-- PORTAL INVENTORY READ
-- Anime Adventures stores portals in
-- ReplicatedStorage.player_portals.<userId>.*
-- We read the player's portal folder and surface names/tiers.
----------------------------------------------------------------
function M.listPortals(): { { name: string, tier: string } }
	local ok, portals = pcall(function()
		local folder = ReplicatedStorage:FindFirstChild("player_portals")
		if not folder then return {} end
		local userFolder = folder:FindFirstChild(tostring(player.UserId))
		if not userFolder then return {} end
		local list = {}
		for _, p in userFolder:GetChildren() do
			local tier = (p:GetAttribute("tier") or p:GetAttribute("Tier") or "?") :: string
			table.insert(list, { name = p.Name, tier = tier })
		end
		return list
	end)
	return if ok then portals else {}
end

function M.deletePortal(name: string)
	-- delete_unique_items takes a list; AA accepts either a single id
	-- or a table. Best-effort: send both shapes.
	init.invoke(init.REMOTE.delete_unique_item, name)
	init.invoke(init.REMOTE.delete_unique_items, { name })
end

function M.deletePortalsBelowTier(tier: string)
	local order = { T1 = 1, T2 = 2, T3 = 3, T4 = 4, T5 = 5 }
	local cutoff = order[tier] or 3
	for _, portal in M.listPortals() do
		local tierRank = order[portal.tier] or 0
		if tierRank > 0 and tierRank < cutoff then
			M.deletePortal(portal.name)
		end
	end
end

----------------------------------------------------------------
-- CAPSULES
----------------------------------------------------------------
function M.openCapsuleOnce()
	-- buy_from_banner is the canonical remote; AA exposes capsule
	-- banners via the same channel.
	init.invoke(init.REMOTE.buy_from_banner, M.state.capsuleType, 1)
end

----------------------------------------------------------------
-- SKIN INVENTORY READ
-- Skins live under ReplicatedStorage.player_skins.<userId>.* with
-- attributes .rarity and .cosmetic_type.
----------------------------------------------------------------
function M.listSkins(): { { name: string, rarity: string, equipped: boolean } }
	local ok, list = pcall(function()
		local folder = ReplicatedStorage:FindFirstChild("player_skins")
		if not folder then return {} end
		local userFolder = folder:FindFirstChild(tostring(player.UserId))
		if not userFolder then return {} end
		local out = {}
		for _, s in userFolder:GetChildren() do
			local rarity = (s:GetAttribute("rarity") or s:GetAttribute("Rarity") or "Common") :: string
			local equipped = (s:GetAttribute("equipped") or false) :: boolean
			table.insert(out, { name = s.Name, rarity = rarity, equipped = equipped })
		end
		return out
	end)
	return if ok then list else {}
end

local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

function M.sellSkinBelowMin()
	local cutoff = RANK[M.state.skinMinRarity] or 2
	for _, skin in M.listSkins() do
		if not skin.equipped and (RANK[skin.rarity] or 0) < cutoff then
			-- AA uses delete_unique_item for cosmetic disposal.
			init.invoke(init.REMOTE.delete_unique_item, skin.name)
		end
	end
end

----------------------------------------------------------------
-- TICK
----------------------------------------------------------------
function M.tick()
	if M.state.autoDeletePortal then
		M.deletePortalsBelowTier(M.state.deletePortalMinTier)
		M.state.autoDeletePortal = false
	end
	if M.state.autoOpenCapsules then
		M.openCapsuleOnce()
	end
	if M.state.autoSellSkins then
		M.sellSkinBelowMin()
		M.state.autoSellSkins = false
	end
end

return M
