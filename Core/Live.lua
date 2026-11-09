-- Reads Legacy state from the game. Every call is guarded: if Blizzard renames an API the ledger shows
-- less instead of throwing errors. APIs mirror Blizzard_LegacySystem (Forever 1.60.1).
local _, ns = ...
local Data = ns.Data

local Live = {}
ns.Live = Live

local function pass(ok, ...)
	if ok then return ... end -- every return value (GetMountInfoByID's isCollected is the 11th)
	return nil
end
local function try(fn, ...)
	if type(fn) ~= "function" then return nil end
	return pass(pcall(fn, ...))
end
Live.try = try

function Live.IsHardcore()
	return C_GameRules and try(C_GameRules.IsHardcoreActive) and true or false
end

-- Total Legacy points the account has earned (= the reward track's renown level).
function Live.Earned()
	return C_MajorFactions and try(C_MajorFactions.GetCurrentRenownLevel, Data.REWARD_TRACK_FACTION_ID) or 0
end

-- Points obtainable right now (Blizzard's panel shows "earned / this").
function Live.MaxAvailable()
	return C_Traits and try(C_Traits.GetMaxAvailableTraitCurrency, Data.POINTS_CURRENCY_ID, false) or 0
end

function Live.ClassName(token)
	local names = LOCALIZED_CLASS_NAMES_MALE
	if type(names) == "table" and names[token] then return names[token] end
	return token and (token:sub(1, 1) .. token:sub(2):lower()) or "?"
end

-- Whether the account already has a reward item. Unlocked Legacy rewards must still be collected from an NPC,
-- so this tells "unlocked" from "claimed". true / false when a collection API knows the item, nil when none does.
-- Order: mount, pet, toy, appearance (tabard), then bags and bank of this character.
local requested = {}
function Live.RewardOwned(itemID)
	if not itemID then return nil end
	-- An uncached item makes the pet and toy lookups come back empty, which would read as "not owned".
	-- Ask the client to load it and say "unknown" until ITEM_DATA_LOAD_RESULT refreshes the ledger. Once per item a
	-- session: an item that never loads would otherwise ask again on every refresh, and each answer refreshes.
	if C_Item and C_Item.IsItemDataCachedByID and not try(C_Item.IsItemDataCachedByID, itemID) then
		if not requested[itemID] then
			requested[itemID] = true
			try(C_Item.RequestLoadItemDataByID, itemID)
		end
		return nil
	end
	if C_MountJournal then
		local mountID = try(C_MountJournal.GetMountFromItem, itemID)
		if mountID then return select(11, try(C_MountJournal.GetMountInfoByID, mountID)) and true or false end
	end
	if C_PetJournal then
		local speciesID = select(13, try(C_PetJournal.GetPetInfoByItemID, itemID))
		if speciesID then return (try(C_PetJournal.GetNumCollectedInfo, speciesID) or 0) > 0 end
	end
	if PlayerHasToy and try(PlayerHasToy, itemID) then return true end
	if C_TransmogCollection and try(C_TransmogCollection.PlayerHasTransmog, itemID) then return true end
	if C_Item and (try(C_Item.GetItemCount, itemID, true) or 0) > 0 then return true end
	return false -- no collection, toy box, wardrobe or bag has it
end

-- Reward track { level, name, itemID, owned }: the game's renown levels, with names and item IDs filled from
-- Data.REWARDS when the API gives a level but no readable name (toys and mounts often only carry an item ID).
function Live.Rewards()
	local byLevel = {}
	local levels = C_MajorFactions and try(C_MajorFactions.GetRenownLevels, Data.REWARD_TRACK_FACTION_ID)
	if type(levels) == "table" then
		for _, info in ipairs(levels) do
			local name, itemID
			local rewards = try(C_MajorFactions.GetRenownRewardsForLevel, Data.REWARD_TRACK_FACTION_ID, info.level)
			for _, r in ipairs(type(rewards) == "table" and rewards or {}) do
				itemID = itemID or r.itemID
				name = name or (r.name ~= "" and r.name) or (r.itemID and C_Item and try(C_Item.GetItemNameByID, r.itemID))
			end
			local known = Data.REWARDS[info.level]
			if name or known then
				byLevel[info.level] = { level = info.level, name = name or ns.L[known.name], itemID = itemID or (known and known.itemID) }
			end
		end
	end
	for level, known in pairs(Data.REWARDS) do
		byLevel[level] = byLevel[level] or { level = level, name = ns.L[known.name], itemID = known.itemID }
	end
	local out = {}
	for _, r in pairs(byLevel) do
		local known = Data.REWARDS[r.level]
		r.kind, r.glyph = known and known.kind, known and known.glyph or "Star"
		r.icon = r.itemID and C_Item and try(C_Item.GetItemIconByID, r.itemID) or nil
		r.owned = Live.RewardOwned(r.itemID)
		out[#out + 1] = r
	end
	table.sort(out, function(a, b) return a.level < b.level end)
	return out
end

local function CriteriaProgress(achievementID)
	local num = try(GetAchievementNumCriteria, achievementID) or 0
	if num == 0 then return 0, nil end
	if num == 1 then
		local text, _, done, qty, req = try(GetAchievementCriteriaInfo, achievementID, 1)
		if done then return 1, text end
		if req and req > 1 and qty and qty > 0 then return math.min(qty / req, 1), string.format("%d / %d", qty, req) end
		return 0, nil
	end
	local doneCount = 0
	for i = 1, num do
		local _, _, done = try(GetAchievementCriteriaInfo, achievementID, i)
		if done then doneCount = doneCount + 1 end
	end
	return doneCount / num, string.format("%d / %d", doneCount, num)
end

-- Level and skill challenges carry no criteria while they're far away, so derive their progress from the
-- best character on the account: the subcategory is named after the class or profession, the description
-- holds the target number ("Reach level 25 ...", "Reach 150 skill ..."). `chars` are roster snapshots.
local function LocalProgress(sub, description, chars)
	local target = tonumber((description or ""):match("(%d+)"))
	if not target or target < 2 then return nil end
	local best, who = 1, nil -- level 1 / skill 1 is where everyone starts, not progress
	for _, ch in ipairs(chars) do
		if Live.ClassName(ch.class) == sub and (ch.level or 0) > best then best, who = ch.level, ch.name end
		for _, p in ipairs(ch.professions or {}) do
			if p.name == sub and (p.skill or 0) > best then best, who = p.skill, ch.name end
		end
	end
	if who then return math.min(best / target, 1), string.format("%d / %d", best, target), who end
end

-- Profession ranks are gated by character level in Forever (research/03-professions.md): a skill target can't be
-- reached until the character who holds the profession is old enough. Returns that level when it's still ahead.
local function ProfessionGate(sub, description, chars)
	local gate = Data.PROF_GATES[tonumber((description or ""):match("(%d+)")) or 0]
	if not gate then return nil end
	local holderLevel, holderSkill
	for _, ch in ipairs(chars) do
		for _, p in ipairs(ch.professions or {}) do
			if p.name == sub and (p.skill or 0) > (holderSkill or -1) then holderLevel, holderSkill = ch.level or 1, p.skill or 0 end
		end
	end
	if holderLevel and holderLevel < gate then return gate end
end

-- Roster snapshots plus the live character (the roster can be a login behind).
local function AccountCharacters()
	local list, me = {}, Live.CharacterKey()
	local db = ns.Core and ns.Core.db
	for key, ch in pairs(db and db.characters or {}) do
		if key ~= me then list[#list + 1] = ch end
	end
	local _, token = try(UnitClass, "player")
	list[#list + 1] = { name = try(UnitName, "player"), class = token, level = try(UnitLevel, "player") or 1, professions = Live.Professions() }
	return list
end

-- Criteria lines for tooltips, read on demand (cheap enough per hover, too costly for every refresh).
-- Return order as Forever's Blizzard_AchievementUI reads it: string, type, completed, quantity, reqQuantity,
-- charName, flags, assetID, quantityString, and (retail order) criteriaID 10th. key: the criteria ID, or the
-- asset ID when the client gives none, so saved progress can be matched to the live list.
function Live.Criteria(achievementID)
	local out = {}
	for i = 1, try(GetAchievementNumCriteria, achievementID) or 0 do
		local text, ctype, done, qty, req, charName, flags, assetID, _, criteriaID = try(GetAchievementCriteriaInfo, achievementID, i)
		if text and text ~= "" then
			out[#out + 1] = { text = text, done = done and true or false, qty = qty, req = req, type = ctype, assetID = assetID,
				charName = charName ~= "" and charName or nil, flags = flags, key = criteriaID or assetID or i }
		end
	end
	return out
end

-- Account-wide or per character, from the achievement's flags (9th return), the way Blizzard_AchievementUI tests
-- ACHIEVEMENT_FLAGS_ACCOUNT. Returns "account", "character", or nil when the client gives no flags; plus earnedBy.
function Live.Scope(achievementID)
	local flags = select(9, try(GetAchievementInfo, achievementID))
	local earnedBy = select(14, try(GetAchievementInfo, achievementID))
	if type(flags) ~= "number" then return nil, earnedBy end
	local bit = ACHIEVEMENT_FLAGS_ACCOUNT or Data.ACHIEVEMENT_FLAG_ACCOUNT
	return (math.floor(flags / bit) % 2 == 1) and "account" or "character", earnedBy
end

-- The deepest list under an achievement whose criteria are achievements themselves: for Explorer that's
-- Explorer → Explore Azeroth → Explore Kalimdor / Eastern Kingdoms → one criterion per zone (the zones' own
-- criteria are subzones, not achievements). Returns { key, text, done } per zone, or nil when it isn't nested.
local ACH_TYPE = CRITERIA_TYPE_ACHIEVEMENT or 8
local function IsNested(achievementID)
	for _, c in ipairs(Live.Criteria(achievementID)) do
		if c.type == ACH_TYPE and (c.assetID or 0) > 0 then return true end
	end
	return false
end
function Live.NestedParts(achievementID, depth, seen)
	depth, seen = depth or 1, seen or {}
	if depth > 4 or seen[achievementID] then return nil end
	seen[achievementID] = true
	local criteria = Live.Criteria(achievementID)
	local out, deeper = {}, false
	for _, c in ipairs(criteria) do
		if c.type == ACH_TYPE and (c.assetID or 0) > 0 and IsNested(c.assetID) then
			deeper = true
			for _, part in ipairs(Live.NestedParts(c.assetID, depth + 1, seen) or {}) do out[#out + 1] = part end
		end
	end
	if deeper then return out end
	if depth == 1 then return nil end -- a flat list is the challenge's own parts, not a nested one
	for _, c in ipairs(criteria) do out[#out + 1] = { key = c.key, text = c.text, done = c.done } end
	return out
end

-- 1.0 instance helper. The dungeon or raid the character is in, or nil outside one (battlegrounds and the open
-- world don't count). GetInstanceInfo: name 1st, instanceType 2nd, instanceID 8th (Blizzard_FrameXML/InstanceDifficulty.lua).
function Live.Instance()
	local inside, kind = try(IsInInstance)
	if not inside or (kind ~= "party" and kind ~= "raid") then return nil end
	local name, _, _, _, _, _, _, instanceID = try(GetInstanceInfo)
	if type(name) ~= "string" or name == "" then return nil end
	return { name = name, kind = kind, id = instanceID }
end

function Live.Level() return try(UnitLevel, "player") or 1 end

-- `needle` sits in `hay` as whole words ("ragefire chasm" in "ragefire chasm or hall of thanes", not "lair" in
-- "lairs"). Bytes above 127 count as letters, so accented names stay whole in every language.
local function IsWordByte(b) return b and (b >= 128 or (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)) end
local function HasPhrase(hay, needle)
	if needle == "" then return false end
	local from = 1
	while true do
		local s, e = hay:find(needle, from, true)
		if not s then return false end
		if not IsWordByte(hay:byte(s - 1)) and not IsWordByte(hay:byte(e + 1)) then return true end
		from = s + 1
	end
end
Live.HasPhrase = HasPhrase -- for tests

-- A challenge with no parts whose description names the raid's boss ("Defeat Onyxia." in Onyxia's Lair): a word
-- of five letters or more that starts a word of the instance's name. Only tried in raids, only without parts.
local function NamesPlace(description, place)
	for word in ns.Lower(description or ""):gmatch("[%a\128-\255]+") do
		if #word >= 5 then
			for pw in place:gmatch("[%a\128-\255]+") do
				if pw:sub(1, #word) == word then return true end
			end
		end
	end
	return false
end

-- The challenges an instance counts toward, read from the challenges' own text, so no instance or achievement IDs
-- are needed and every client language works (capture 2026-11-06):
--   raids: "Defeat the following encounters in Hyjal Summit." and one part per boss → whole = true, every part;
--   dungeons: one part per dungeon, named after it ("Wailing Caverns", "Ragefire Chasm or Hall of Thanes",
--   "Scarlet Monastery: Library") → the parts that name this instance or that it names.
-- Criteria are read here, on demand: once per loading screen into an instance, never per refresh.
-- Returns { { item, parts, criteria, whole } }.
function Live.InstanceChallenges(name, kind)
	local place, out = ns.Lower(name or ""), {}
	if place == "" then return out end
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			local criteria = Live.Criteria(item.id)
			local whole = HasPhrase(ns.Lower(item.description or ""), place)
			local parts = {}
			if whole then
				for _, c in ipairs(criteria) do parts[#parts + 1] = c end
			else
				for _, c in ipairs(criteria) do
					local text = ns.Lower(c.text)
					if c.type ~= ACH_TYPE and (HasPhrase(text, place) or (#text >= 4 and HasPhrase(place, text))) then
						parts[#parts + 1] = c
					end
				end
				if #criteria == 0 and kind == "raid" and NamesPlace(item.description, place) then whole = true end
			end
			if whole or #parts > 0 then out[#out + 1] = { item = item, parts = parts, criteria = criteria, whole = whole } end
		end
	end
	return out
end

-- 1.0 map badges. The world map's canvas, the map it shows and its zoom, or nil while there's no world map.
-- MapCanvasMixin:GetCanvas / GetMapID / GetCanvasScale (Blizzard_MapCanvas/Blizzard_MapCanvas.lua, Forever). Reads
-- only: the badges never go through the map's data providers or pin pools (research/19-feature-plan.md #8).
function Live.MapView()
	local map = WorldMapFrame
	if type(map) ~= "table" or type(map.GetCanvas) ~= "function" then return nil end
	local canvas = try(map.GetCanvas, map)
	if not canvas then return nil end
	return canvas, try(map.GetMapID, map), try(map.GetCanvasScale, map) or 1
end

-- Dungeon and raid entrances on a map (the data Blizzard's own entrance pins use): name, normalized x / y,
-- kind from the pin's atlas ("Raid" in it = raid).
function Live.DungeonEntrances(mapID)
	local out = {}
	if not (mapID and C_EncounterJournal) then return out end
	for _, e in ipairs(try(C_EncounterJournal.GetDungeonEntrancesForMap, mapID) or {}) do
		local pos = e.position
		if type(e.name) == "string" and e.name ~= "" and pos and pos.x and pos.y then
			out[#out + 1] = { name = e.name, x = pos.x, y = pos.y,
				kind = tostring(e.atlasName or ""):find("Raid") and "raid" or "party" }
		end
	end
	return out
end

function Live.AddOnLoaded(name)
	return C_AddOns and try(C_AddOns.IsAddOnLoaded, name) and true or false
end

-- What this character has done on multi-part challenges, read when the snapshot is taken (login, logout, an
-- earned criterion), never on a refresh: explore = { [zone key] = true } for the nested challenge (Explorer),
-- parts = { [achievementID] = { [criteria key] = true } } for every challenge with several parts.
function Live.ProgressSnapshot()
	local parts, explore, exploreTotal, exploreID = {}, {}, 0, nil
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			local nested = Live.NestedParts(item.id)
			if nested and #nested > 0 and not exploreID then
				exploreID, exploreTotal = item.id, #nested
				for _, z in ipairs(nested) do if z.done then explore[z.key] = true end end
			else
				local list = Live.Criteria(item.id)
				if #list > 1 then
					local done
					for _, c in ipairs(list) do
						if c.done then done = done or {} done[c.key] = true end
					end
					parts[item.id] = done
				end
			end
		end
	end
	return { explore = explore, exploreTotal = exploreTotal, exploreID = exploreID, parts = parts }
end

local cache, trackedCache
function Live.Invalidate() cache, trackedCache = nil, nil end

-- Everything the ledger knows, as plain data for /yl export (format documented in dashboard/README.md).
-- earnedLog and characters come from SavedVariables; the rest is read live.
function Live.Export(db)
	local _, build = try(GetBuildInfo)
	local out = {
		format = "your-legacy-export", version = 1,
		exported = date("%Y-%m-%d"), build = build, locale = GetLocale and try(GetLocale) or "enUS",
		account = { earned = Live.Earned(), available = Live.MaxAvailable() },
		challenges = {}, characters = {}, rewards = {},
	}
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			local entry = db.earnedLog[item.id]
			out.challenges[#out.challenges + 1] = {
				id = item.id, name = item.name, section = g.title, group = item.sub, points = item.points,
				completed = item.completed, date = item.date or (entry and entry.date),
				ruleset = entry and entry.ruleset or nil, progress = item.completed and 1 or item.ratio,
			}
		end
	end
	for key, ch in pairs(db.characters) do
		local profs = {}
		for _, p in ipairs(ch.professions or {}) do
			profs[#profs + 1] = { name = p.name, skill = p.skill, max = p.max, skillLine = p.skillLine }
		end
		out.characters[#out.characters + 1] = {
			key = key, name = ch.name, realm = ch.realm, class = ch.class, race = ch.race, level = ch.level,
			ruleset = ch.ruleset or "normal", professions = profs, spent = ch.spent,
			seen = ch.seen and ch.seen > 0 and date("%Y-%m-%d", ch.seen) or nil,
		}
	end
	table.sort(out.characters, function(a, b) return a.key < b.key end)
	for _, r in ipairs(Live.Rewards()) do
		out.rewards[#out.rewards + 1] = { level = r.level, name = r.name, itemID = r.itemID, collected = r.owned }
	end
	return out
end

-- A perk's description for its tooltip (read on hover, not per refresh).
function Live.SpellDescription(spellID)
	return C_Spell and try(C_Spell.GetSpellDescription, spellID) or nil
end

-- Objective-tracker pins, the way Blizzard_AchievementUI does it (AchievementTemplateMixin:ToggleTracking).
local function AchievementTrackingType()
	return C_ContentTracking and Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
end

function Live.TrackingDisabled()
	local rule = Enum and Enum.GameRule and Enum.GameRule.TrackAchievementsDisabled
	return not AchievementTrackingType() or (rule and C_GameRules and try(C_GameRules.IsGameRuleActive, rule)) and true or false
end

-- Set of tracked achievement IDs, read once per refresh.
function Live.Tracked()
	if not trackedCache then
		trackedCache = {}
		local kind = AchievementTrackingType()
		for _, id in ipairs(kind and try(C_ContentTracking.GetTrackedIDs, kind) or {}) do trackedCache[id] = true end
	end
	return trackedCache
end

-- Returns "tracked", "untracked", "disabled", "done", "failed", or "full" plus the limit.
function Live.ToggleTracking(achievementID)
	local kind = AchievementTrackingType()
	if Live.TrackingDisabled() then return "disabled" end
	trackedCache = nil
	if try(C_ContentTracking.IsTracking, kind, achievementID) then
		try(C_ContentTracking.StopTracking, kind, achievementID, Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual)
		return "untracked"
	end
	local limit = Constants and Constants.ContentTrackingConsts and Constants.ContentTrackingConsts.MaxTrackedAchievements or 10
	if #(try(C_ContentTracking.GetTrackedIDs, kind) or {}) >= limit then return "full", limit end
	if select(4, try(GetAchievementInfo, achievementID)) then return "done" end
	try(C_ContentTracking.StartTracking, kind, achievementID)
	return try(C_ContentTracking.IsTracking, kind, achievementID) and "tracked" or "failed"
end

-- 1.0: chat links, the way Blizzard_AchievementUI/Mainline does it (AchievementTemplateMixin:LinkInChat):
-- GetAchievementLink, then ChatFrameUtil.InsertLink, which is true only when a chat edit box took the link.
function Live.AchievementLink(achievementID)
	return try(GetAchievementLink, achievementID)
end

function Live.InsertChatLink(link)
	local util = ChatFrameUtil
	if not (link and util and util.InsertLink) then return false end
	return try(util.InsertLink, link) and true or false
end

-- One line to guild chat. False when the character has no guild (nothing is sent then).
function Live.SendGuild(msg)
	if not (try(IsInGuild) and C_ChatInfo and C_ChatInfo.SendChatMessage) then return false end
	try(C_ChatInfo.SendChatMessage, msg, "GUILD")
	return true
end

-- Every Legacy challenge the client lists for this character. A challenge is any achievement that awards
-- Legacy points, so no ID list is needed. Achievements sit in subcategories (Druid, Alchemy, Ranks...)
-- below sections (Classes, Tradeskills...); items are grouped by section.
function Live.Challenges()
	if cache then return cache end
	local chars = AccountCharacters()
	local info = {}
	local function catInfo(id)
		if not info[id] then
			local title, parent = try(GetCategoryInfo, id)
			info[id] = { title = title or "Legacy", parent = (parent and parent > 0) and parent or nil }
		end
		return info[id]
	end
	local function chain(id) -- { root, ..., id }
		local list, guard = {}, 0
		while id and guard < 10 do
			table.insert(list, 1, id)
			id = catInfo(id).parent
			guard = guard + 1
		end
		return list
	end

	local items, seen, roots = {}, {}, {}
	for _, categoryID in ipairs(try(GetCategoryList) or {}) do
		local count = try(GetCategoryNumAchievements, categoryID) or 0
		for index = 1, count do
			local id, name, _, completed, month, day, year, description, _, icon = try(GetAchievementInfo, categoryID, index)
			if id and not seen[id] then
				local points = C_Traits and try(C_Traits.GetTraitCurrencyForAchievement, Data.POINTS_CURRENCY_ID, id) or 0
				if points and points > 0 then
					seen[id] = true
					local path = chain(categoryID)
					roots[path[1]] = true
					local sub = catInfo(categoryID).title
					local ratio, detail, who, gate = 1, nil, nil, nil
					if not completed then
						ratio, detail = CriteriaProgress(id)
						if ratio == 0 then
							local r, d, w = LocalProgress(sub, description, chars)
							if r then ratio, detail, who = r, d, w end
						end
						gate = ProfessionGate(sub, description, chars)
					end
					items[#items + 1] = {
						id = id, name = name, description = description, completed = completed and true or false, icon = icon,
						points = points, ratio = ratio, detail = detail, who = who, gate = gate, sub = sub, path = path,
						date = completed and month and string.format("20%02d-%02d-%02d", year or 0, month, day or 0) or nil,
					}
				end
			end
		end
	end

	-- Section = top-level category, unless every challenge shares one root (a "Legacy" umbrella):
	-- then the level below it.
	local rootCount = 0
	for _ in pairs(roots) do rootCount = rootCount + 1 end
	local groups, order = {}, {}
	local total, done = 0, 0
	for _, item in ipairs(items) do
		local depth = (rootCount == 1 and #item.path > 1) and 2 or 1
		local sectionID = item.path[math.min(depth, #item.path)]
		local title = catInfo(sectionID).title
		local g = groups[title]
		if not g then
			g = { title = title, id = sectionID, items = {}, done = 0, total = 0 }
			groups[title] = g
			order[#order + 1] = g
		end
		g.items[#g.items + 1] = item
		g.total = g.total + item.points
		total = total + item.points
		if item.completed then
			g.done = g.done + item.points
			done = done + item.points
		end
	end
	cache = { groups = order, total = total, done = done }
	return cache
end

-- The current character's Legacy trees: every visible node with its purchased rank.
-- Visible means what Blizzard's Legacy panel draws: TalentFrameBaseMixin:InstantiateTalentButton skips a node
-- unless nodeInfo.isVisible is truthy (Blizzard_SharedTalentFrame.lua). includeHidden is for /yl capture only.
function Live.Trees(includeHidden)
	local trees, spentTotal = {}, 0
	if not C_Traits then return trees, 0 end
	for _, tree in ipairs(Data.TREES) do
		local configID = try(C_Traits.GetConfigIDByTreeID, tree.id)
		local entry = { key = tree.key, name = tree.name, id = tree.id, nodes = {}, spent = 0 }
		-- Tree gates ("spend 5 points in this tree"): each applies from its top-left node's row down
		-- (TraitTreeInfo.gates, as Blizzard_SharedTalentFrame draws them).
		local gates = {}
		local treeInfo = configID and try(C_Traits.GetTreeInfo, configID, tree.id)
		for _, gate in ipairs(treeInfo and treeInfo.gates or {}) do
			local cond = gate.conditionID and try(C_Traits.GetConditionInfo, configID, gate.conditionID)
			local top = gate.topLeftNodeID and try(C_Traits.GetNodeInfo, configID, gate.topLeftNodeID)
			if cond and (cond.spentAmountRequired or 0) > 0 and top then
				gates[#gates + 1] = { y = top.posY or 0, amount = cond.spentAmountRequired }
			end
		end
		if configID then
			for _, nodeID in ipairs(try(C_Traits.GetTreeNodes, tree.id) or {}) do
				local node = try(C_Traits.GetNodeInfo, configID, nodeID)
				if node and node.ID and node.ID ~= 0 and (node.isVisible or includeHidden) then
					local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
					local name, icon
					local entryInfo = entryID and try(C_Traits.GetEntryInfo, configID, entryID)
					local def = entryInfo and entryInfo.definitionID and try(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
					if def then
						name, icon = def.overrideName, def.overrideIcon
						if (not name or name == "") and def.spellID and C_Spell then name = try(C_Spell.GetSpellName, def.spellID) end
						if not icon and def.spellID and C_Spell then icon = try(C_Spell.GetSpellTexture, def.spellID) end
					end
					local rank = node.ranksPurchased or node.currentRank or 0
					-- Forever build 70790 has two visible 1-rank nodes per tree that all use placeholder spell 1317256,
					-- which the client names UNKNOWN (unreleased perks?). Label them instead of printing "Unknown".
					local unnamed = not name or name == "" or name == (UNKNOWN or "Unknown")
					-- What unlocks it: points spent in this tree (node conditions and tree gates), and the perks
					-- whose arrows point at it (their visibleEdges), which must be at max rank.
					local gate = 0
					for _, condID in ipairs(node.conditionIDs or {}) do
						local cond = try(C_Traits.GetConditionInfo, configID, condID)
						if cond and (cond.spentAmountRequired or 0) > gate then gate = cond.spentAmountRequired end
					end
					for _, g in ipairs(gates) do
						if (node.posY or 0) >= g.y and g.amount > gate then gate = g.amount end
					end
					local edges = {}
					for _, e in ipairs(node.visibleEdges or {}) do
						if e.targetNode then edges[#edges + 1] = e.targetNode end
					end
					entry.nodes[#entry.nodes + 1] = {
						id = nodeID, name = name or "", unnamed = unnamed, icon = icon, rank = rank,
						maxRanks = node.maxRanks or 1, x = node.posX or 0, y = node.posY or 0,
						-- evidence for captures
						visible = node.isVisible and true or false, nodeType = node.type, hasActiveEntry = node.activeEntry ~= nil,
						spellID = def and def.spellID, gate = gate, edges = edges,
					}
					if node.isVisible then entry.spent = entry.spent + rank end
				end
			end
		end
		table.sort(entry.nodes, function(a, b)
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		-- prerequisites: the reverse of the edges (a node lists the perks pointing at it)
		local byID = {}
		for _, n in ipairs(entry.nodes) do byID[n.id] = n n.requires = {} end
		for _, n in ipairs(entry.nodes) do
			for _, target in ipairs(n.edges) do
				if byID[target] then table.insert(byID[target].requires, n.id) end
			end
		end
		spentTotal = spentTotal + entry.spent
		trees[#trees + 1] = entry
	end
	return trees, spentTotal
end

-- Professions of the current character.
function Live.Professions()
	local out = {}
	if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return out end
	-- Forever (Camelot) returns First Aid in the third slot where retail has Archaeology.
	local p1, p2, firstAid, fishing, cooking = try(GetProfessions)
	for slot, index in pairs({ p1, p2, firstAid, fishing, cooking }) do
		if index then
			local name, icon, skill, maxSkill, _, _, skillLine = try(GetProfessionInfo, index)
			if name then
				out[#out + 1] = {
					name = name, icon = icon, skill = skill or 0, max = maxSkill or 0, skillLine = skillLine, slot = slot,
					primary = slot <= 2, craft = skillLine and Data.CRAFTS[skillLine] or false,
				}
			end
		end
	end
	table.sort(out, function(a, b)
		if a.primary ~= b.primary then return a.primary end
		return a.skill > b.skill
	end)
	return out
end

function Live.PlayerName() return try(UnitName, "player") or "?" end

function Live.CharacterKey()
	return (try(UnitName, "player") or "?") .. "-" .. (try(GetRealmName) or "?")
end

-- A snapshot of the logged-in character for the roster.
-- Equipped items by inventory slot (1 head ... 19 tabard): { link, icon, quality }. Blizzard's PaperDollFrame
-- (Mainline) reads GetInventoryItemLink; icon and quality come from the documented C_Item calls.
Live.GEAR_SLOTS = { 1, 2, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local function ItemInfo(link)
	local itemID = link and tonumber(link:match("item:(%d+)"))
	if not itemID then return nil end
	return {
		link = link, itemID = itemID,
		icon = C_Item and try(C_Item.GetItemIconByID, itemID) or nil,
		quality = C_Item and try(C_Item.GetItemQualityByID, link) or nil,
	}
end

function Live.Gear()
	local gear = {}
	for _, slot in ipairs(Live.GEAR_SLOTS) do
		gear[slot] = ItemInfo(try(GetInventoryItemLink, "player", slot))
	end
	return gear
end

-- Legacy perk ranks by node ID, for planning on characters you aren't logged in with.
local function PerkRanks(trees)
	local ranks = {}
	for _, t in ipairs(trees) do
		for _, n in ipairs(t.nodes) do if n.rank > 0 then ranks[n.id] = n.rank end end
	end
	return ranks
end

function Live.Snapshot()
	local _, classToken = try(UnitClass, "player")
	local trees, spent = Live.Trees() -- one walk of the trees for the spent count and the ranks
	return {
		name = try(UnitName, "player") or "Unknown", realm = try(GetRealmName) or "",
		class = classToken or "WARRIOR", race = try(UnitRace, "player") or "?",
		level = try(UnitLevel, "player") or 1, ruleset = Live.IsHardcore() and "hardcore" or "normal",
		professions = Live.Professions(), spent = spent, seen = time and time() or 0,
		-- 0.5: the character panel (0.9.1: without bags)
		gear = Live.Gear(), perks = PerkRanks(trees),
		money = try(GetMoney) or 0, zone = try(GetRealZoneText) or "", guild = try(GetGuildInfo, "player"),
		itemLevel = select(2, try(GetAverageItemLevel)) or try(GetAverageItemLevel),
		xp = try(UnitXP, "player"), xpMax = try(UnitXPMax, "player"), rested = try(GetXPExhaustion),
	}
end

-- Opens Blizzard's Legacy panel (Y), on the challenge page when an ID is given. Not in combat:
-- opening Blizzard panels from addon code mid-fight risks spreading taint.
function Live.OpenLegacyPanel(achievementID)
	if InCombatLockdown and InCombatLockdown() then return false end
	if type(ToggleLegacySystemUI) ~= "function" then return false end
	if not (LegacySystemFrame and LegacySystemFrame:IsShown()) then try(ToggleLegacySystemUI) end
	if achievementID and EventRegistry then
		try(EventRegistry.TriggerEvent, EventRegistry, "Legacy.SelectPage", 2)
		if AchievementFrame_SelectAchievement then try(AchievementFrame_SelectAchievement, achievementID, true) end
	end
	return true
end

-- Previews a reward (0.9): Blizzard's DressUpLink shows the tabard on the character, the pet and the mount in the
-- dressing room (Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua). A toy has no model: the item tooltip instead.
-- Not in combat, like every Blizzard panel the ledger opens. Returns true when the dressing room took it.
function Live.PreviewReward(itemID, owner)
	if not itemID or (InCombatLockdown and InCombatLockdown()) then return false end
	local link = C_Item and select(2, try(C_Item.GetItemInfo, itemID))
	if not link then
		try(C_Item and C_Item.RequestLoadItemDataByID, itemID)
		link = "item:" .. itemID
	end
	if type(DressUpLink) == "function" and try(DressUpLink, link) then return true end
	if owner then
		GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
		GameTooltip:SetHyperlink("item:" .. itemID)
		GameTooltip:Show()
	end
	return false
end

-- A game sound by sound kit ID (C_Sound.PlaySound, documented in Forever 1.60.1), on the SFX channel.
function Live.PlaySound(id)
	if not id then return end
	if C_Sound and C_Sound.PlaySound then try(C_Sound.PlaySound, id, "SFX") end
end

-- A game screenshot (global Screenshot(), not protected in Forever's docs). The client writes it to its Screenshots
-- folder and fires SCREENSHOT_SUCCEEDED or SCREENSHOT_FAILED (UI/Shots.lua waits for those).
function Live.Screenshot()
	if Screenshot then try(Screenshot) end
end

-- Records exactly what the ledger reads, in the shape devenv scenarios use, so the offline simulator
-- can replay the real client. Saved under YourLegacyDB.capture (written on /reload or logout).
function Live.Capture()
	local cats = {}
	for _, categoryID in ipairs(try(GetCategoryList) or {}) do
		local title, parent = try(GetCategoryInfo, categoryID)
		local cat = { id = categoryID, title = title, parent = parent, achievements = {} }
		for index = 1, try(GetCategoryNumAchievements, categoryID) or 0 do
			local id, name, _, completed, month, day, year, description = try(GetAchievementInfo, categoryID, index)
			if id then
				-- 0.9: flags, wasEarnedByMe and earnedBy too, to settle per character vs account-wide (capture on two
				-- characters and compare)
				local flags = select(9, try(GetAchievementInfo, categoryID, index))
				local wasEarnedByMe, earnedBy = select(13, try(GetAchievementInfo, categoryID, index))
				local a = {
					id = id, name = name, description = description, completed = completed and true or false,
					points = C_Traits and try(C_Traits.GetTraitCurrencyForAchievement, Data.POINTS_CURRENCY_ID, id) or 0,
					date = completed and month and string.format("20%02d-%02d-%02d", year or 0, month, day or 0) or nil,
					flags = flags, wasEarnedByMe = wasEarnedByMe, earnedBy = earnedBy,
					criteria = {},
				}
				for i = 1, try(GetAchievementNumCriteria, id) or 0 do
					local text, criteriaType, done, qty, req, charName, cflags, assetID, _, criteriaID = try(GetAchievementCriteriaInfo, id, i)
					a.criteria[#a.criteria + 1] = { text = text, done = done and true or false, qty = qty, req = req, type = criteriaType, assetID = assetID,
						charName = charName, flags = cflags, criteriaID = criteriaID }
				end
				cat.achievements[#cat.achievements + 1] = a
			end
		end
		cats[#cats + 1] = cat
	end
	local rewards = {}
	for _, info in ipairs((C_MajorFactions and try(C_MajorFactions.GetRenownLevels, Data.REWARD_TRACK_FACTION_ID)) or {}) do
		local raw = try(C_MajorFactions.GetRenownRewardsForLevel, Data.REWARD_TRACK_FACTION_ID, info.level) or {}
		local first = raw[1] or {}
		rewards[#rewards + 1] = { level = info.level, name = first.name, itemID = first.itemID, count = #raw }
	end
	local trees = {}
	for _, t in ipairs(Live.Trees(true)) do
		local nodes = {}
		for _, n in ipairs(t.nodes) do
			nodes[#nodes + 1] = { id = n.id, name = n.name, rank = n.rank, max = n.maxRanks, x = n.x, y = n.y,
				visible = n.visible, type = n.nodeType, activeEntry = n.hasActiveEntry, spellID = n.spellID,
				gate = n.gate, edges = n.edges }
		end
		trees[tostring(t.id)] = { nodes = nodes }
	end
	local profs = {}
	for _, p in ipairs(Live.Professions()) do profs[#profs + 1] = { slot = p.slot, name = p.name, skill = p.skill, max = p.max, skillLine = p.skillLine } end
	-- Font object names the client defines (devenv/wowsim/fonts.txt is generated from this).
	local fonts = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "table" then
			local ok, kind = pcall(function() return v:GetObjectType() end)
			if ok and kind == "Font" then fonts[#fonts + 1] = k end
		end
	end
	table.sort(fonts)
	local _, classToken = try(UnitClass, "player")
	-- the Blizzard atlases the UI draws, with their real sizes (devenv's renderer uses stand-ins for them)
	local atlases = {}
	for _, name in ipairs({ "common-sidetab", "common-sidetab-selected", "RedButton-Exit", "128-RedButton-UP",
		"UI-Legacy-Points-icon-c60", "Legacy-Challenge-BG", "Legacy-Progressbar-BG", "Legacy-Progressbar-Fill",
		"Legacy-Progressbar-Frame", "worldquest-tracker-checkmark", "checkbox-minimal", "checkmark-minimal",
		"UI-Frame-PortraitMetal-CornerTopLeft", "UI-Frame-InnerTopLeft",
		-- 0.9
		"Legacy-Challenge-Cards", "Legacy-Challenge-Cards-selected", "Legacy-Tree-Frame-Card", "Legacy-Tree-Frame-Card-Glow",
		"Legacy-Tree-Frame-icon-frame", "UI-Legacy-Tree-Professions", "UI-Legacy-Tree-Adventure", "UI-Legacy-Tree-Progression",
		"common-dropdown-textholder", "common-dropdown-a-button", "common-dropdown-bg", "common-dropdown-icon-checkmark-yellow",
		"Minimal_SliderBar_Button", "_Minimal_SliderBar_Middle", "common-sidetab-hover", "UI-Frame-Metal-CornerTopLeft",
		-- 0.9.1
		"Minimal_SliderBar_Left", "Minimal_SliderBar_Right", "Minimal_SliderBar_Button_Left", "Minimal_SliderBar_Button_Right",
		"Professions-skillbar-bg", "Professions-skillbar-frame", "Skillbar_Fill_Flipbook_DefaultBlue",
		"common-dropdown-a-button-hover" }) do
		local info = C_Texture and try(C_Texture.GetAtlasInfo, name)
		atlases[name] = info and { width = info.width, height = info.height, file = info.file } or false
	end
	return {
		atlases = atlases,
		time = time and time() or 0, build = select(2, try(GetBuildInfo)), hardcore = Live.IsHardcore(),
		player = { name = try(UnitName, "player"), realm = try(GetRealmName), class = classToken, race = try(UnitRace, "player"), level = try(UnitLevel, "player"),
			gear = Live.Gear(), money = try(GetMoney), zone = try(GetRealZoneText), guild = try(GetGuildInfo, "player"),
			itemLevel = try(GetAverageItemLevel), xp = try(UnitXP, "player"), xpMax = try(UnitXPMax, "player"), rested = try(GetXPExhaustion),
			instance = Live.Instance() }, -- 1.0: to check the instance helper's name match in game
		legacy = { earned = Live.Earned(), max = Live.MaxAvailable(), rewards = rewards },
		categories = cats, trees = trees, professions = profs, fonts = fonts,
	}
end
