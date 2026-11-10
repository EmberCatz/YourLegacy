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

-- 1.0: what a character is for (db.roles; nil = alt), shown on its roster card. Ignore also hides the card behind
-- "Show ignored". (Play next, which the other roles fed, was removed on the user's call, 2026-11-09.)
Data.ROLES = {
	{ key = "main", name = "Main", desc = "Your main character." },
	{ key = "alt", name = "Alt", desc = "Another character you play." },
	{ key = "crafter", name = "Crafter", desc = "Kept for its professions." },
	{ key = "bank", name = "Bank", desc = "Holds your things." },
	{ key = "ignore", name = "Ignore", desc = "Hidden on the Roster." },
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
Data.RULES_DATE = "2026-11-10"
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
	{ key = "reset", status = "reported", text = "Taking ranks back means resetting the tree in the Legacy panel, which costs 10 gold.",
		source = "Players on Blizzard's forums, 2026-11-10. The panel's reset button asks for no confirmation." },
	{ key = "gathering", status = "confirmed", text = "Gathering professions, fishing, cooking and first aid earn no Legacy points.",
		source = "Only the six crafts have Legacy challenges." },
	{ key = "hardcore", status = "reported", text = "Hardcore challenges count everywhere; Normal ones don't count on Hardcore.",
		source = "Guides. Hardcore isn't out yet." },
	{ key = "outlevel", status = "unchecked", text = "A dungeon cleared above its bracket's top level may not count.",
		source = "Nobody has tested it, so Your Legacy doesn't warn about it yet." },
}
Data.RULE_BY_KEY = {}
for _, r in ipairs(Data.RULES) do Data.RULE_BY_KEY[r.key] = r end

-- Ranks are reset in the Legacy panel. Blizzard_LegacyTree.lua has a reset button (C_Traits.ResetTree, a whole tree,
-- staged until Apply). Players on Blizzard's forums (2026-11-10, "I paid my 10g fine") report it costs 10 gold and
-- asks for no confirmation. UNVERIFIED in our own game: the cost (RESET_COST_GOLD) and whether it's per tree.
Data.PERK_RESET_IN_PANEL = true
Data.RESET_COST_GOLD = 10

-- 1.1: notes for perks players misread (forum, 2026-11-10: "Bountiful Harvest, zero increase"). Most profession
-- perks raise a chance, so a short session can show nothing. Node IDs from the 2026-11-06 capture; effects from
-- research/01-legacy-system-reference.md (perk trees table).
Data.PERK_NOTES = {
	[110291] = "Only scarce materials (gems, rare drops) increase, not ore, herbs or leather. It raises a chance, so it shows over many nodes.", -- Bountiful Harvest
	[110290] = "Raises the chance of a skill-up. It shows over many crafts, not a few.", -- Working Overtime
	[110292] = "A chance on each crate turn-in, not every time.", -- Performance Bonus
	[110289] = "A chance of an extra result on each cook, not every time.", -- Master Chef
	[110293] = "A chance of an extra fish while a lure is on, not every catch.", -- Luremaster
}

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

-- 1.1: level range of every dungeon and raid, from guide sites (the game has no lookup by name: C_LFGInfo needs LFG
-- dungeon IDs). Sources, checked 2026-11-10: mobalytics.gg/wow-forever/guides/dungeon-raid-map and
-- mmonster.co/wow-forever/guides/legacy-challenges/dungeons (updated 2026-11-07); they agree on every dungeon. The 9
-- new Forever dungeons also match Wowhead's overview; for some Classic ones Wowhead differs (Wailing Caverns 15-25).
-- Keys are English names, normalized by Data.LevelKey, so only English clients match by name for now. The probe
-- (/yl probe) records each entrance's journalInstanceID; once captured, DUNGEON_LEVEL_IDS makes it work in every
-- language.
Data.DUNGEON_LEVELS = {
	["ragefire chasm"] = { 13, 18 }, ["hall of thanes"] = { 13, 18 }, ["ruins of lordaeron"] = { 15, 20 },
	["wailing caverns"] = { 17, 24 }, ["deadmines"] = { 17, 26 }, ["shadowfang keep"] = { 22, 30 },
	["excavation site wetlands"] = { 24, 29 }, ["excavation site"] = { 24, 29 },
	["stockade"] = { 24, 32 }, ["stormwind stockade"] = { 24, 32 }, ["blackfathom deeps"] = { 24, 32 },
	["city of dalaran"] = { 28, 33 }, ["gnomeregan"] = { 29, 38 }, ["razorfen kraul"] = { 29, 38 },
	["scarlet monastery graveyard"] = { 30, 38 }, ["scarlet monastery library"] = { 33, 41 },
	["scarlet monastery armory"] = { 36, 44 }, ["scarlet monastery cathedral"] = { 38, 46 }, ["scarlet monastery"] = { 30, 46 },
	["drowned city"] = { 35, 40 }, ["razorfen downs"] = { 37, 46 }, ["kroldok stronghold"] = { 40, 45 }, ["kroldok"] = { 40, 45 },
	["uldaman"] = { 41, 51 }, ["zulfarrak"] = { 44, 54 }, ["maraudon"] = { 46, 55 }, ["alcaz prison"] = { 48, 53 },
	["temple of atalhakkar"] = { 50, 60 }, ["sunken temple"] = { 50, 60 }, ["blackrock depths"] = { 52, 60 },
	["dire maul east"] = { 54, 60 }, ["dire maul north"] = { 56, 60 }, ["dire maul west"] = { 56, 60 }, ["dire maul"] = { 54, 60 },
	["lower blackrock spire"] = { 55, 60 }, ["upper blackrock spire"] = { 59, 60 }, ["blackrock spire"] = { 55, 60 },
	["blackmaw hold"] = { 55, 60 }, ["scholomance"] = { 58, 60 }, ["shapers terrace"] = { 58, 60 },
	["stratholme"] = { 58, 60 }, ["stratholme live"] = { 58, 60 }, ["stratholme dead"] = { 58, 60 },
	["stratholme main gate"] = { 58, 60 }, ["stratholme service gate"] = { 58, 60 },
	-- raids
	["molten core"] = { 60, 60 }, ["onyxias lair"] = { 60, 60 }, ["blackwing lair"] = { 60, 60 }, ["zulgurub"] = { 60, 60 },
	["ruins of ahnqiraj"] = { 60, 60 }, ["temple of ahnqiraj"] = { 60, 60 }, ["naxxramas"] = { 60, 60 },
	["hyjal summit"] = { 60, 60 }, ["barrow deeps"] = { 60, 60 },
}
-- Raids by the same keys (an entrance from Questie carries no raid flag).
Data.RAID_KEYS = {
	["molten core"] = true, ["onyxias lair"] = true, ["blackwing lair"] = true, ["zulgurub"] = true, ["ruins of ahnqiraj"] = true,
	["temple of ahnqiraj"] = true, ["naxxramas"] = true, ["hyjal summit"] = true, ["barrow deeps"] = true,
}
-- Zones of the new Forever dungeons that neither the game's call (empty, probe 2026-11-10) nor Questie's table
-- (QuestieDB/support/Forever, checked 2026-11-10) has. Zone only: the banner lists a zone's dungeons, it draws no
-- pins. Zones from mobalytics.gg's dungeon map and zockify.com's dungeon list; uiMap IDs are the Classic ones,
-- Riverglades (new in Forever) by name. Names are English: other languages match once a probe has their IDs.
Data.EXTRA_ENTRANCES = {
	{ name = "The Drowned City", map = 1434 },            -- Stranglethorn Vale
	{ name = "Krol'dok Stronghold", mapName = "Riverglades" },
	{ name = "Alcaz Prison", map = 1445 },                -- Dustwallow Marsh
	{ name = "Blackmaw Hold", map = 1447 },               -- Azshara
	{ name = "The Shaper's Terrace", map = 1449 },        -- Un'Goro Crater
}
-- [journalInstanceID] = { min, max }, from probe captures (empty until one is in).
Data.DUNGEON_LEVEL_IDS = {}

-- "The Shaper's Terrace" → "shapers terrace", "Stratholme: Live" → "stratholme live".
function Data.LevelKey(name)
	local s = ns.Lower(tostring(name or ""))
	s = s:gsub("\226\128\153", ""):gsub("'", ""):gsub("[:%-,]", " "):gsub("%s+", " ")
	s = strtrim and strtrim(s) or s:match("^%s*(.-)%s*$")
	return (s:gsub("^the ", ""))
end

-- { min, max } for a dungeon or raid, by journal ID when known, else by name ("A or B": the first that's known).
function Data.LevelRange(name, journalID, english)
	if journalID and Data.DUNGEON_LEVEL_IDS[journalID] then return Data.DUNGEON_LEVEL_IDS[journalID] end
	if english and Data.DUNGEON_LEVELS[Data.LevelKey(english)] then return Data.DUNGEON_LEVELS[Data.LevelKey(english)] end
	local r = Data.DUNGEON_LEVELS[Data.LevelKey(name)]
	if r then return r end
	for part in (tostring(name or "") .. " or "):gmatch("(.-) or ") do
		r = Data.DUNGEON_LEVELS[Data.LevelKey(part)]
		if r then return r end
	end
end

-- "Wailing Caverns (17-24)", "Onyxia's Lair (60)", or the name unchanged when its range isn't known.
function Data.WithLevels(name, journalID, english)
	local r = Data.LevelRange(name, journalID, english)
	if not r then return name end
	return r[1] == r[2] and string.format("%s (%d)", name, r[1]) or string.format("%s (%d-%d)", name, r[1], r[2])
end
