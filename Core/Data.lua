-- Static data for Your Legacy: Blizzard IDs, class colours, perk presets.
-- Nothing here is about one particular player; challenges, points and perk ranks come from the game.
local _, ns = ...

local Data = {}
ns.Data = Data

-- From Blizzard_APIDocumentationGenerated/LegacyConstantsDocumentation.lua (Forever 1.60.1).
Data.REWARD_TRACK_FACTION_ID = 2802
Data.POINTS_CURRENCY_ID = 4225
Data.TREES = {
	-- icon = the atlas Blizzard's Legacy panel uses for the tree (Blizzard_LegacySystemConstants.lua)
	{ id = 1187, key = "professions", name = "Professions", icon = "UI-Legacy-Tree-Professions" },
	{ id = 1188, key = "adventure", name = "Adventure", icon = "UI-Legacy-Tree-Adventure" },
	{ id = 1189, key = "resourcefulness", name = "Resourcefulness", icon = "UI-Legacy-Tree-Progression" },
}
Data.SPEND_CAP = 16

-- Fills gaps when the renown API returns a level without a readable reward name.
-- Item IDs from /yl capture on the live client (2026-11-05).
Data.REWARDS = {
	[15] = { name = "Replica Ironforge Air Rifle", itemID = 276236, kind = "Toy", glyph = "Star" },
	[25] = { name = "Spectral Bear Cub", itemID = 277714, kind = "Pet", glyph = "Paw" },
	[40] = { name = "Spectral Bear Tabard", itemID = 277717, kind = "Tabard", glyph = "Shield" },
	[55] = { name = "Reins of the Spectral Bear", itemID = 277718, kind = "Mount", glyph = "Horseshoe" },
}

Data.CLASS_ORDER = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
Data.CLASS_COLORS = {
	DRUID = "FF7C0A", HUNTER = "AAD372", MAGE = "3FC7EB", PALADIN = "F48CBA", PRIEST = "FFFFFF",
	ROGUE = "FFF468", SHAMAN = "0070DD", WARLOCK = "8788EE", WARRIOR = "C69B6D",
}

-- Character level a profession rank needs in Forever (research/03-professions.md): skill target -> level.
Data.PROF_GATES = { [150] = 10, [225] = 20, [300] = 35 }

-- Crafting professions that award Legacy points, by skill line.
Data.CRAFTS = { [171] = true, [164] = true, [333] = true, [202] = true, [165] = true, [197] = true }

-- Trait node IDs of the Legacy perks (from /yl capture on the live client, 2026-11-05). The game supplies the
-- localized names, so presets match by ID and work on every client language. Names here are comments only.
local P = {
	WORKING_OVERTIME = 110290, BOUNTIFUL_HARVEST = 110291, BARTERING = 110286, DEDICATED_STUDY = 110284, PERFORMANCE_BONUS = 110292,
	WELL_RESTED = 110301, TALENTED = 110298, THRILL_OF_ADVENTURE = 110296, FIELD_MEDICINE = 110303,
	GOURMAND = 110313, PERMANENCE = 110316, QUICK_AND_THE_DEAD = 110315, REAGENT_ECONOMY = 110309, REINFORCE = 110318, DIPLOMAT = 110314,
}

-- Perk build presets: [node ID] = target rank. Purely a comparison aid.
Data.PRESETS = {
	{ key = "leveling", name = "Leveling", perks = { [P.WELL_RESTED] = 5, [P.TALENTED] = 5, [P.THRILL_OF_ADVENTURE] = 5, [P.QUICK_AND_THE_DEAD] = 1 } },
	{ key = "crafting", name = "Crafting", perks = { [P.WORKING_OVERTIME] = 5, [P.BOUNTIFUL_HARVEST] = 5, [P.BARTERING] = 2, [P.DEDICATED_STUDY] = 1, [P.PERFORMANCE_BONUS] = 3 } },
	{ key = "openworld", name = "Open world", perks = { [P.GOURMAND] = 3, [P.QUICK_AND_THE_DEAD] = 2, [P.DIPLOMAT] = 5, [P.REAGENT_ECONOMY] = 1, [P.PERMANENCE] = 2, [P.REINFORCE] = 3 } },
	{ key = "hardcore", name = "Hardcore", perks = { [P.THRILL_OF_ADVENTURE] = 5, [P.WELL_RESTED] = 5, [P.FIELD_MEDICINE] = 2, [P.TALENTED] = 4 } },
}

-- Race and class combinations on Forever (0.6 class planner). Vanilla plus the six new ones from the 15 Oct 2026
-- patch (Gnome Priest, Human Hunter, Dwarf Shaman, Orc Mage, Troll Warlock, Undead Paladin) and the Skyborne:
-- High Order (Alliance) and Windshaper (Horde). Sources: wowhead.com/forever/guide/new-race-class-combinations,
-- mobalytics.gg/wow-forever/guides/wow-forever-race-class-combinations (both checked 2026-11-06).
-- The game has no in-world API for this (character creation data lives in the glue screens), so it's listed here.
Data.RACES = {
	Horde = { "Orc", "Undead", "Tauren", "Troll", "Skyborne" },
	Alliance = { "Human", "Dwarf", "Night Elf", "Gnome", "Skyborne" },
}
Data.RACE_CLASSES = {
	Horde = {
		Orc = { WARRIOR = true, HUNTER = true, MAGE = true, ROGUE = true, WARLOCK = true, SHAMAN = true },
		Undead = { WARRIOR = true, MAGE = true, ROGUE = true, PRIEST = true, WARLOCK = true, PALADIN = true },
		Tauren = { WARRIOR = true, HUNTER = true, DRUID = true, SHAMAN = true },
		Troll = { WARRIOR = true, HUNTER = true, MAGE = true, ROGUE = true, PRIEST = true, WARLOCK = true, SHAMAN = true },
		Skyborne = { WARRIOR = true, HUNTER = true, ROGUE = true, DRUID = true, SHAMAN = true },
	},
	Alliance = {
		Human = { WARRIOR = true, HUNTER = true, MAGE = true, ROGUE = true, PRIEST = true, WARLOCK = true, PALADIN = true },
		Dwarf = { WARRIOR = true, HUNTER = true, ROGUE = true, PRIEST = true, PALADIN = true, SHAMAN = true },
		["Night Elf"] = { WARRIOR = true, HUNTER = true, ROGUE = true, PRIEST = true, DRUID = true },
		Gnome = { WARRIOR = true, MAGE = true, ROGUE = true, PRIEST = true, WARLOCK = true },
		Skyborne = { WARRIOR = true, HUNTER = true, MAGE = true, ROGUE = true, DRUID = true },
	},
}

-- The six crafts that earn Legacy points, in the order the Tradeskills section lists them.
Data.CRAFT_ORDER = {
	{ id = 171, name = "Alchemy" }, { id = 164, name = "Blacksmithing" }, { id = 333, name = "Enchanting" },
	{ id = 202, name = "Engineering" }, { id = 165, name = "Leatherworking" }, { id = 197, name = "Tailoring" },
}
-- The crafts players pair with each class (research/03-professions.md section 5: the consensus of Wowhead, MMonster,
-- Gfinity and others, leveling and endgame pairs, crafts only). Shown as "suggested"; any pair counts for Legacy.
Data.SUGGESTED_CRAFTS = {
	WARRIOR = { [164] = true, [202] = true }, PALADIN = { [164] = true, [202] = true },
	HUNTER = { [165] = true, [202] = true }, ROGUE = { [165] = true, [202] = true },
	SHAMAN = { [165] = true, [171] = true }, DRUID = { [165] = true, [171] = true },
	MAGE = { [197] = true, [333] = true }, PRIEST = { [197] = true, [333] = true }, WARLOCK = { [197] = true, [333] = true },
}
-- Sounds for an earned challenge (Options > General), the game's own toasts (SoundKitConstants.lua, Forever 1.60.1).
Data.SOUNDS = {
	{ key = "quest", id = 73277, name = "Quest complete" },  -- UI_WORLDQUEST_COMPLETE
	{ key = "loot", id = 31578, name = "Epic loot" },        -- UI_EPICLOOT_TOAST
	{ key = "legendary", id = 63971, name = "Legendary" },   -- UI_LEGENDARY_LOOT_TOAST
	{ key = "recipe", id = 73919, name = "New recipe" },     -- UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST
	{ key = "dig", id = 38326, name = "Discovery" },         -- UI_DIG_SITE_COMPLETION_TOAST
}

-- Profession ranks, for bar ticks and labels: skill cap -> rank name.
Data.PROF_RANKS = { { 75, "Apprentice" }, { 150, "Journeyman" }, { 225, "Expert" }, { 300, "Artisan" } }
-- Class challenge milestones (levels).
Data.LEVEL_MILESTONES = { 25, 45, 60 }
Data.SKILL_MILESTONES = { 150, 225, 300 } -- the crafting challenges' targets (Novice/Journeyman ranks earn none)

-- 1.0: what a character is for (db.roles; nil = alt). Bank and Ignore leave Play next; Ignore also hides the
-- roster card behind "Show ignored"; a Crafter only counts for its crafts.
Data.ROLES = {
	{ key = "main", name = "Main", desc = "Your main. Goes first when two characters are equally close." },
	{ key = "alt", name = "Alt", desc = "Counts everywhere." },
	{ key = "crafter", name = "Crafter", desc = "Only its crafts count in Play next." },
	{ key = "bank", name = "Bank", desc = "Left out of Play next." },
	{ key = "ignore", name = "Ignore", desc = "Left out of Play next and hidden on the Roster." },
}

-- One-line descriptions of the perk presets (Legacy Tree).
Data.PRESET_NOTES = {
	leveling = "Faster levels: more rested XP, earlier talents, health back on kills.",
	crafting = "Skill-ups, gathering and vendor prices for a crafter or bank character.",
	openworld = "Food, reputation, buffs and no reagents for questing at any level.",
	hardcore = "Survival: health on kills, shorter bandage lockout and early talents.",
}

---------------------------------------------------------------- 0.9: from player feedback (research/17-v09-feedback-features.md)
-- Character level cap on Forever (the class challenges' last milestone).
Data.MAX_LEVEL = 60

-- Perks whose ranks stop helping at a character level, keyed by node ID. Sources: the perk texts in
-- research/01-legacy-system-reference.md (perk trees table). Nothing else in the three trees is level-bound by its text.
Data.DEAD_PERKS = {
	[110301] = { level = 60, why = "No experience to rest for at level 60." },           -- Well Rested: rested XP accrues faster, cap higher
	[110298] = { level = 60, why = "Talent points reach the same 51 at level 60." },     -- Talented: talents from level 5 instead of 10, max 51 still
}
-- 1.0: the Legacy rules the ledger relies on, each with how sure we are, shown to players (tooltips and
-- Options > How Legacy works). confirmed = the game or Blizzard shows it; reported = guides and players say so,
-- not yet proven in game; unchecked = nobody has tested it. Update a status (and RULES_DATE) when an in-game
-- check settles it (research/17-v09-feedback-features.md has the checklist).
Data.RULES_DATE = "2026-11-09"
Data.RULES = {
	{ key = "once", status = "confirmed", text = "A challenge is earned once for the whole account.",
		source = "Every challenge carries the game's account flag." },
	{ key = "reach", status = "confirmed", text = "A level or skill challenge needs one character to reach the number.",
		source = "The challenge's own description." },
	{ key = "explore", status = "confirmed", text = "Exploring counts per character: one character has to find every area.",
		source = "Compared on two characters in game." },
	{ key = "cap", status = "confirmed", text = "A character can spend up to 16 Legacy points.",
		source = "Blizzard's Legacy System announcement." },
	{ key = "allParts", status = "reported", text = "A challenge with a list needs every part on it.",
		source = "Guides and players. Not tested in game yet." },
	{ key = "deadPerks", status = "reported", text = "Well Rested and Talented stop helping at level 60.",
		source = "How the perks are described. Not tested in game yet." },
	{ key = "reset", status = "reported", text = "Unlearning perks happens at a class trainer and costs gold.",
		source = "Guides and beta players. Not tested in game yet." },
	{ key = "hardcore", status = "reported", text = "Hardcore challenges count everywhere; Normal ones don't count on Hardcore.",
		source = "Guides. Hardcore isn't out yet." },
	{ key = "outlevel", status = "unchecked", text = "A dungeon cleared above its bracket's top level may not count.",
		source = "Nobody has tested it, so Your Legacy doesn't warn about it yet." },
}
Data.RULE_BY_KEY = {}
for _, r in ipairs(Data.RULES) do Data.RULE_BY_KEY[r.key] = r end

-- UNVERIFIED: whether ranks can be reset in the Legacy panel without a trainer or a cost. Blizzard_LegacyTree.lua has
-- a reset button (C_Traits.ResetTree, a whole tree, staged until Apply); guides say a respec happens at a class
-- trainer for a cost that climbs. Off: the copy says the ranks no longer help and promises no reset. In-game check 2.
Data.PERK_RESET_IN_PANEL = false

-- The achievement flag for account-wide progress. Blizzard_AchievementUI (Forever) tests the client's global
-- ACHIEVEMENT_FLAGS_ACCOUNT; the value below is retail's, used only when the global is missing. UNVERIFIED on Forever.
Data.ACHIEVEMENT_FLAG_ACCOUNT = 0x20000

-- Dungeon brackets: the lowest and highest dungeon level in each Spelunker list, from mmonster.co's per-dungeon
-- ranges (wow-forever/guides/legacy-challenges/dungeons, checked 2026-11-06): Novice 13-31 (Ragefire Chasm 13 to
-- Excavation Site 31), Experienced 24-46 (Blackfathom Deeps 24 to SM Cathedral 46), Master 37-60. research/01's
-- "15-25 / 26-45 / 46-60" was wrong: Shadowfang Keep (22-30) and Excavation Site (26-31) are Novice dungeons.
-- A bracket's challenge is found by one of its dungeons' criteria asset IDs (capture 2026-11-06), so no achievement
-- IDs are hardcoded and every client language works. UNVERIFIED: that Hardcore uses the same asset IDs (check 5).
Data.DUNGEON_BRACKETS = {
	{ min = 13, max = 31, marker = 3654 }, -- Wailing Caverns
	{ min = 24, max = 46, marker = 7800 }, -- Gnomeregan
	{ min = 37, max = 60, marker = 9019 }, -- Blackrock Depths
}
-- UNVERIFIED: whether a clear by a character above a bracket's top level still counts. Off until the in-game test
-- (check 4) shows it doesn't; then the warning goes live. Margin: levels before the top where it starts.
Data.OUTLEVEL_WARNING = false
Data.OUTLEVEL_MARGIN = 3

-- 1.0 instance helper: criteria types in the dungeon and raid challenges (capture 2026-11-06). Kill = a creature
-- (assetID = its creature ID: Wailing Caverns is 3654, Mutanus). Encounter = a boss fight (Hyjal's Time-Lost
-- Battalion, type 165, asset 3339). UNVERIFIED: that 165's asset is the encounterID ENCOUNTER_END reports.
Data.CRITERIA_KILL = 0
Data.CRITERIA_ENCOUNTER = 165
