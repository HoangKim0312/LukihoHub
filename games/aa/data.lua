--!strict
-- games/aa/data.lua
-- Static catalogs extracted from the Anime Adventures .rbxlx dump.
-- These names are the canonical IDs the server expects in remote args.

return {
	----------------------------------------------------------------
	-- DIFFICULTIES
	-- select_difficulty accepts these strings (server side switch).
	----------------------------------------------------------------
	DIFFICULTIES = {
		"Easy", "Normal", "Hard", "Insane",
	},

	----------------------------------------------------------------
	-- MAP MODES
	-- Lobby join modes. Each mode is a string sent to
	-- request_join_lobby.
	----------------------------------------------------------------
	JOIN_MODES = {
		"Story", "Infinite", "LegendStage", "Raid",
	},

	----------------------------------------------------------------
	-- MAPS
	-- Subset of story-mode worlds. Full list is dynamic; the dropdown
	-- can populate from get_lobby_more_params at runtime.
	----------------------------------------------------------------
	MAPS = {
		"Naruto",     "Demon Slayer", "My Hero Academia",
		"Jujutsu Kaisen", "Bleach", "One Piece",
		"Dragon Ball", "Hunter x Hunter", "JoJo",
		"Fairy Tail", "Seven Deadly Sins", "Black Clover",
		"Halloween", "Christmas", "April", "Namek",
		"Dressrosa", "Marineford", "Sunraku",
	},

	----------------------------------------------------------------
	-- ACTS
	----------------------------------------------------------------
	ACTS = { "Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6" },

	----------------------------------------------------------------
	-- PORTALS
	-- use_portal() takes one of these IDs.
	----------------------------------------------------------------
	PORTALS = {
		"final_disc",  "april_portal", "marineford_portal",
		"naruto_portal", "demonslayer_portal", "jjk_portal",
		"hxh_portal", "namek_portal", "dressrosa_portal",
		"halloween_portal", "christmas_portal", "bleach_portal",
		"clover_portal", "7ds_portal", "fairytail_portal",
		"aot_portal", "opm_portal", "mha_portal",
		"sunraku_portal", "csm_portal", "jojo_portal",
	},

	----------------------------------------------------------------
	-- TIERS
	-- For portal tiers / chest filters.
	----------------------------------------------------------------
	TIERS = { "T1", "T2", "T3", "T4", "T5" },

	----------------------------------------------------------------
	-- DIFFICULTY -> GAME MODE tag (for get_normal_challenge)
	----------------------------------------------------------------
	CHALLENGE_TYPES = {
		"Normal", "Daily", "Event",
	},

	----------------------------------------------------------------
	-- UNIT ROLES (for sell-on-wave / upgrade-on-wave filters)
	-- These match the unit role strings in
	-- ReplicatedStorage/src/Data/Attacks/* (broad categories).
	----------------------------------------------------------------
	UNIT_ROLES = {
		"Ground", "Air", "Both",
	},

	----------------------------------------------------------------
	-- EVENT CARDS (roguelike modifiers)
	-- The "Event" challenge presents cards each wave. Some are buffs,
	-- some are debuffs. The picker filters by name.
	----------------------------------------------------------------
	BUFF_CARDS = {
		"Double Damage", "Gold Boost", "Range Boost",
		"Cooldown Reduction", "Extra Slot", "Speed Boost",
	},
	DEBUFF_CARDS = {
		"Half Damage", "Slow Enemies", "Reduce Range",
		"Increase Cooldowns", "Less Gold",
	},

	----------------------------------------------------------------
	-- SKIN TIERS
	-- For Auto Sell Skins. The skin rarity flag is set on the cosmetic
	-- object; AA reads it via `cosmetic.rarity`.
	----------------------------------------------------------------
	SKIN_RARITIES = {
		"Common", "Rare", "Epic", "Legendary", "Mythic",
	},

	----------------------------------------------------------------
	-- CAPSULE NAMES (auto-open target)
	----------------------------------------------------------------
	CAPSULE_TYPES = {
		"Standard", "Premium", "Event",
	},

	----------------------------------------------------------------
	-- FRIEND LIST CACHE
	-- Populated at runtime from Players:GetFriendsAsync.
	----------------------------------------------------------------
	FRIENDS_PLACEHOLDER = {
		"(press Refresh to load)",
	},

	----------------------------------------------------------------
	-- MACRO SLOT NAMES (UI placeholder)
	----------------------------------------------------------------
	MACRO_SLOTS = { "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5" },

	----------------------------------------------------------------
	-- CODES (Anime Adventures has known redeemable codes)
	-- Pulled from public lists; redacted/old ones removed.
	----------------------------------------------------------------
	KNOWN_CODES = {
		"SORRYFORSHUTDOWN",
		"NEVERDIE",
		"RAIDNARUTO",
		"RAIDMARINEFORD",
		"HEROIC",
		"SUBTOSUBTOMETAVERSE",
	},
}
