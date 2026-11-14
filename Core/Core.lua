-- Your Legacy core: SavedVariables, event wiring, slash commands.
local addonName, ns = ...
local Live, Data, L = ns.Live, ns.Data, ns.L

local Core = CreateFrame("Frame")
ns.Core = Core
YourLegacy = ns -- one global for /dump and other addons; everything else stays local

local DB_VERSION = 14
Core.DB_VERSION = DB_VERSION -- read by tests
local DEFAULTS = {
	characters = {}, -- [Name-Realm] = Live.Snapshot()
	plans = {},      -- [Name-Realm] = { [nodeID] = planned rank } (Legacy tree planner)
	intent = {},     -- [CLASS] = "normal" | "hardcore": classes the player means to level but hasn't started
	earnedLog = {},  -- [achievementID] = { date, char, ruleset } recorded when a challenge pops
	pools = {},      -- normal / hardcore = Legacy points the game reported on a character of that ruleset
	notes = {},      -- [Name-Realm] = the player's note about that character
	status = {},     -- [Name-Realm] = "fallen" for a Hardcore character that died (set on death, editable)
	classPlans = {}, -- [CLASS] = { race = "Troll", profs = { [skillLine] = true }, next = true } for classes not started yet
	builds = {},     -- 0.9: saved Legacy tree builds, account-wide: { { name = "...", perks = { [nodeID] = rank } } }
	roles = {},      -- 1.0: [Name-Realm] = "main" | "crafter" | "bank" | "ignore" (nil = alt; Data.ROLES)
	bossNames = {},  -- 1.0: [creatureID] = name, learned from ENCOUNTER_END for creatures a dungeon's credit needs
	evidence = {},   -- 1.1: what the probe (/yl probe) learned while you played: [key] = { date, ... } (UI/Probe.lua)
	probe = {},      -- 1.1: the last probe run, for reading from SavedVariables after /reload (devenv/probe.py)
	almost = { said = {}, seeded = {} }, -- 1.3: said = { [achievementID] = true } got the almost-done line; seeded[ruleset] = first check done
	rested = { inn = 1, outside = 1 }, -- 1.3: learned correction of the offline rested rate, per where the character logged out
	knownChallenges = {}, -- 1.3: [normal | hardcore] = { build, ids = { [achievementID] = name } }, the list at the last login
	settings = {
		scale = 1,           -- window scale
		minimap = true,      -- show the minimap button
		minimapAngle = 215,  -- degrees around the minimap
		locked = false,      -- window can't be dragged
		combatHide = true,   -- close the window when combat starts
		announce = true,     -- chat line when a challenge is earned
		unlockLegacy = true, -- 1.2: Blizzard's Legacy key binding and micro button work at 0 points (post-hooks)
		-- 0.6
		animations = true,   -- short fades on open, tab switch and selection
		minimapIcon = {},    -- LibDBIcon's own table (hide, minimapPos) when that library is present
		-- 0.9
		sound = false,       -- play a sound when a Legacy challenge is earned
		soundKey = "quest",  -- Data.SOUNDS key
		-- 0.9.1
		devTools = false,    -- Options > Data: unlocks the developer row (the screenshot run)
		-- 1.0
		announceGuild = false, -- also post earned challenges to guild chat
		remindUnspent = true,  -- chat line at login when Legacy points are unspent
		remindRewards = true,  -- chat line at login when an unlocked reward waits at Innkeeper Wiley
		announceAlmost = true,  -- 1.3: chat line once when a challenge is nearly finished
		raidBuildWarning = true, -- 1.3: chat line on joining a raid when the perks aren't the build marked for raids
		announceChanges = true, -- 1.3: chat line at login when the game lists new Legacy challenges or drops some
		instanceHelper = true, -- chat lines inside a dungeon or raid that counts toward a challenge (Core/Instance.lua)
		mapZone = true,        -- Legacy progress of the zone open on the world map (UI/MapZone.lua)
		mapZoneWithLegacyForever = false, -- the same while Legacy Forever is loaded (it shows zone progress too)
		mapZonePos = {},       -- { x, y } where the player dragged the zone box, from the map's top-left (empty = beside the map buttons)
		mapButton = true,      -- our button on the world map with the map options (UI/MapButton.lua)
		-- 1.1
		announceNewPoint = true, -- on a new Legacy point, say which characters can spend it
		barFill = "DefaultBlue", -- the fill of the progress bars: a profession rank-bar art (Theme.BAR_FILLS)
	},
	-- status: open | progress | done | all; section: the Challenges tab ("" = its overview);
	-- sort (1.0): game | closest | points | name, for the rows inside a section
	ui = { tab = "overview", status = "open", section = "", sort = "game", showIgnored = false },
}

local function ApplyDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			db[k] = type(v) == "table" and ApplyDefaults({}, v) or v
		elseif type(v) == "table" and type(db[k]) == "table" then
			ApplyDefaults(db[k], v)
		elseif type(v) ~= type(db[k]) then
			db[k] = type(v) == "table" and ApplyDefaults({}, v) or v -- wrong type in saved data: reset that key
		end
	end
	return db
end

-- One-way upgrades of older SavedVariables. Never assume a field exists in old data.
local function Migrate(db)
	if (db.version or 1) < 2 then
		db.capture = nil -- capture format changed
	end
	-- v6: a plan was a preset key; now it's the ranks themselves, so the planner can edit it.
	if (db.version or 1) < 6 and type(db.plans) == "table" then
		for key, plan in pairs(db.plans) do
			if type(plan) == "string" then
				local preset
				for _, p in ipairs(Data.PRESETS) do if p.key == plan then preset = p end end
				local copy = {}
				for id, r in pairs(preset and preset.perks or {}) do copy[id] = r end
				db.plans[key] = preset and copy or nil
			end
		end
	end
	-- v5: goal values gained "maybe" (nil = Goal, "maybe", false = Skip); old nil/false keep their meaning. pools is new.
	if (db.version or 1) < 4 and type(db.ui) == "table" then
		db.ui.view = nil -- 0.4 dev builds had a list/grid toggle; grid is now the only view
		-- Grid sections replaced long lists; open them once so the new view is visible.
		if type(db.ui.collapsed) == "table" then db.ui.collapsed = {} end
	end
	-- v7: the in-addon options page. Notes moved out of the character panel; the data stays.
	if (db.version or 1) < 7 and type(db.settings) == "table" and type(db.settings.minimapAngle) == "number" then
		db.settings.minimapIcon = type(db.settings.minimapIcon) == "table" and db.settings.minimapIcon or {}
		db.settings.minimapIcon.minimapPos = db.settings.minimapAngle
	end
	-- v8 (0.7, the Hallmark redesign): Ember becomes the default theme; fonts are two roles, display and body.
	if (db.version or 1) < 8 and type(db.settings) == "table" then
		if db.settings.theme == "gilded" then db.settings.theme = "ember" end
		local heading = db.settings.fontHeading
		if type(heading) == "string" and heading ~= "marcellus" then db.settings.fontDisplay = heading end
		db.settings.fontHeading, db.settings.fontNumber = nil, nil
	end
	-- v9 (0.8, native to Forever): the retired themes (ember, gilded) move to forever.
	if (db.version or 1) < 9 and type(db.settings) == "table" and db.settings.theme ~= "forever" then
		db.settings.theme = "forever"
	end
	-- v10 (0.9): Goal / Maybe / Skip is gone; the 0.8 theme is "classic" now and "forever" is the new glow theme;
	-- the roster lost its sort; folded sections gave way to section tabs.
	if (db.version or 1) < 10 then
		db.goal = nil
		if type(db.settings) == "table" and db.settings.theme ~= "classic" then db.settings.theme = "classic" end
		if type(db.ui) == "table" then db.ui.rosterSort, db.ui.collapsed = nil, nil end
	end
	-- v11 (0.9 feedback features): characters keep their progress on multi-part challenges (explore, parts).
	if (db.version or 1) < 11 and type(db.characters) == "table" then
		for _, ch in pairs(db.characters) do
			if type(ch) == "table" then
				ch.explore = type(ch.explore) == "table" and ch.explore or {}
				ch.parts = type(ch.parts) == "table" and ch.parts or {}
			end
		end
	end
	-- v12 (0.9.1): one look and the client font (no themes, no font choices), no first-run note, no bags.
	if (db.version or 1) < 12 then
		if type(db.settings) == "table" then db.settings.theme, db.settings.fontDisplay, db.settings.fontBody = nil, nil, nil end
		if type(db.ui) == "table" then db.ui.introSeen = nil end
		if type(db.characters) == "table" then
			for _, ch in pairs(db.characters) do
				if type(ch) == "table" then ch.bags, ch.bagSlots = nil, nil end
			end
		end
	end
	-- v13 (1.1): evidence and probe are new tables (ApplyDefaults adds them). Settings of removed 1.0 dev features
	-- (the map badges, the zone box corners) were still in saved data (seen in a /yl report, 2026-11-10).
	if (db.version or 1) < 13 and type(db.settings) == "table" then
		db.settings.mapBadges, db.settings.mapBadgesWithLegacyForever, db.settings.mapZoneCorner = nil, nil, nil
	end
	-- v14 (1.1): the frame sliders were a tuning tool; their values are built in now (UI/Window.lua, UI/Character.lua)
	if (db.version or 1) < 14 and type(db.settings) == "table" then
		for _, k in ipairs({ "panelMetalLeft", "panelMetalRight", "panelGround", "windowMetalLeft", "windowMetalRight",
			"windowGround", "windowLogoDisc" }) do db.settings[k] = nil end
	end
	db.version = DB_VERSION
	return db
end

function Core:Print(msg)
	print(ns.Theme.Hex(ns.Theme.C.heat5) .. "Your Legacy:|r " .. tostring(msg))
end

function Core:Setting(key) return self.db and self.db.settings[key] end

-- 1.1: a piece of evidence for the probe, with the day it was seen. Never while the debug fill fakes progress.
function Core:Evidence(key, fields)
	if not self.db or Live.demo then return end
	fields = fields or {}
	fields.date = date("%Y-%m-%d %H:%M")
	self.db.evidence[key] = fields
end

-- 1.2: Blizzard's reset dialog at the trainer (CONFIRM_TALENT_WIPE cost, type; Blizzard_Game EventImplementation.lua
-- shows ConfirmTalentWipeDialog). Class talents and Legacy perks share it; which type is Legacy isn't documented,
-- so the type that came before a measured Legacy reset is learned (evidence "reset".kind). Says once what a Legacy
-- reset clears and, below 60, whether Talented blocks it. Until the type is known the line starts with "If".
function Core:OnTalentWipe(cost, kind)
	if not self.db then return end
	self.pendingWipe = { kind = kind, at = time() }
	self:Evidence("wipe", { cost = cost, kind = kind })
	local learned = self.db.evidence.reset and self.db.evidence.reset.kind
	if learned ~= nil and learned ~= kind then return end
	local trees, spent = Live.Trees()
	if (spent or 0) == 0 then return end
	local ranks = {}
	for _, t in ipairs(trees) do for _, n in ipairs(t.nodes) do if n.rank > 0 then ranks[n.id] = n.rank end end end
	local text = string.format(L["A Legacy reset clears all %d ranks, Talented too. Learn your plan again in the Legacy panel afterwards."], spent)
	if learned == nil then text = string.format(L["If this is the Legacy reset: %s"], text) end
	self:Print(text)
	local deficit = ns.Pages.TalentedDeficit(UnitLevel("player"), ranks[Data.TALENTED_NODE], Live.ClassTalentUnspent())
	if deficit > 0 then
		self:Print(string.format(L["Below level 60 the trainer won't reset while Talented pays for spent class talents: unlearn %d class talent points there first."], deficit))
	end
end

function Core:SetSetting(key, value)
	if not self.db then return end
	self.db.settings[key] = value
	-- the debug fill lives behind Developer tools; switching them off must not leave fake progress on
	if key == "devTools" and not value and Live.demo then Live.SetDemo(nil) end
	if ns.UI and ns.UI.ApplySettings then ns.UI:ApplySettings() end
	if key == "minimap" and ns.Minimap and ns.Minimap.Update then ns.Minimap:Update() end
	if ns.MapZone then ns.MapZone:Refresh() end
end

-- withProgress reads the character's progress on multi-part challenges (Live.ProgressSnapshot); that walk is
-- costly, so it runs at login, logout and when a criterion is earned. Every other snapshot keeps the last reading.
function Core:RecordCharacter(withProgress)
	if not self.db or Live.demo then return end -- the debug fill's fake progress never reaches the saved data
	local key = Live.CharacterKey()
	local snap, old = Live.Snapshot(), self.db.characters[key]
	if withProgress or not (old and old.explore) then
		local progress = Live.ProgressSnapshot()
		snap.explore, snap.exploreTotal, snap.exploreID, snap.parts = progress.explore, progress.exploreTotal, progress.exploreID, progress.parts
	else
		snap.explore, snap.exploreTotal, snap.exploreID, snap.parts = old.explore, old.exploreTotal, old.exploreID, old.parts or {}
	end
	-- On logout and /reload (and early at login) the client has no inventory links any more: a read with no item
	-- at all keeps the last real one, or it would save empty gear over it (found in game, 0.9.1).
	if not next(snap.gear or {}) and old and type(old.gear) == "table" and next(old.gear) then snap.gear = old.gear end
	-- 1.1 probe evidence: ranks went down and gold with them since the last snapshot a few minutes ago = a reset
	-- in the Legacy panel. Records what it cost and how many trees lost ranks (the 10g rule: per tree or per reset?).
	if old and (tonumber(old.spent) or 0) > (snap.spent or 0) and (tonumber(old.money) or 0) > (snap.money or 0)
		and (snap.seen or 0) - (tonumber(old.seen) or 0) < 600 then
		local treeOf, lost = {}, {}
		for _, t in ipairs(Live.Trees()) do for _, n in ipairs(t.nodes) do treeOf[n.id] = t.key end end
		for id, r in pairs(old.perks or {}) do
			id = tonumber(id) or id
			if (snap.perks[id] or 0) < r and treeOf[id] then lost[treeOf[id]] = true end
		end
		local trees = 0
		for _ in pairs(lost) do trees = trees + 1 end
		-- 1.2: the trainer's dialog type just before it is the Legacy reset's (Core:OnTalentWipe learns it from this)
		local wipe = self.pendingWipe
		local kind = wipe and time() - wipe.at < 300 and wipe.kind or nil
		self:Evidence("reset", { cost = old.money - snap.money, ranks = old.spent - snap.spent, trees = trees, kind = kind })
	end
	self.db.characters[key] = snap
	-- the points of this ruleset, for characters of it the roster shows while you play the other one
	local earned = Live.Earned()
	if earned > 0 then self.db.pools[snap.ruleset] = earned end
end

-- 1.0 reminders. Points this character could still spend: the account's points up to the per-character cap,
-- minus the ranks it has learned. 0 before the account's first point (the panel isn't open yet).
function Core:Unspent()
	local earned = Live.Earned()
	if earned <= 0 then return 0 end
	local _, spent = Live.Trees()
	return math.max(0, math.min(Data.SPEND_CAP, earned) - (spent or 0))
end

-- 1.1: the account's points on a ruleset (Normal and Hardcore earn apart): live for the one you play, else the
-- last reading taken on a character of it.
function Core:EarnedFor(ruleset)
	if ruleset == (Live.IsHardcore() and "hardcore" or "normal") then return Live.Earned() end
	return tonumber(self.db and self.db.pools[ruleset]) or 0
end

-- Points a saved character could still spend: its ruleset's points up to the cap, minus its ranks.
function Core:UnspentFor(key)
	if key == Live.CharacterKey() then return self:Unspent() end
	local ch = self.db and self.db.characters[key]
	if type(ch) ~= "table" then return 0 end
	local earned = self:EarnedFor(ch.ruleset or "normal")
	if earned <= 0 then return 0 end
	return math.max(0, math.min(Data.SPEND_CAP, earned) - (tonumber(ch.spent) or 0))
end

-- 1.1: a new Legacy point. Which characters of this ruleset can spend it (not fallen, not set to Ignore), the one
-- you're playing first. Nothing when all of them sit at the cap.
function Core:CanSpend()
	local me, ruleset, out = Live.CharacterKey(), Live.IsHardcore() and "hardcore" or "normal", {}
	for key, ch in pairs(self.db.characters) do
		if type(ch) == "table" and (ch.ruleset or "normal") == ruleset and self.db.status[key] ~= "fallen"
			and self.db.roles[key] ~= "ignore" and self:UnspentFor(key) > 0 then
			out[#out + 1] = { key = key, name = ch.name or key, live = key == me }
		end
	end
	table.sort(out, function(a, b)
		if a.live ~= b.live then return a.live end
		return a.name < b.name
	end)
	return out
end

function Core:NewPoint(level)
	if not self:Setting("announceNewPoint") or Live.demo then return end
	local list = self:CanSpend()
	if #list == 0 then return end
	local names = {}
	for i, c in ipairs(list) do names[i] = c.name end
	if #list == 1 then
		self:Print(string.format(L["New Legacy point (%d in all). %s can spend it."], level, names[1]))
	else
		self:Print(string.format(L["New Legacy point (%d in all). %d characters can spend it: %s."], level, #list, table.concat(names, ", ")))
	end
end

-- The saved characters as the pages show them. 1.1 debug fill: every snapshot at the fill's share, plus a made-up
-- character for each class the account hasn't played (two crafts, both rulesets), so every card can be looked at.
-- Nothing here is saved.
function Core:Characters()
	if not Live.demo then return self.db.characters end
	local out, have = {}, {}
	for key, ch in pairs(self.db.characters) do
		out[key] = Live.DemoCharacter(ch)
		have[ch.class] = true
	end
	for i, token in ipairs(Data.CLASS_ORDER) do
		if not have[token] then
			local profs, slot = {}, 0
			for _, craft in ipairs(Data.CRAFT_ORDER) do
				if Data.SUGGESTED_CRAFTS[token] and Data.SUGGESTED_CRAFTS[token][craft.id] then
					slot = slot + 1
					profs[#profs + 1] = { name = L[craft.name], skillLine = craft.id, skill = 1, max = 300, slot = slot, primary = true, craft = true }
				end
			end
			local name = "Demo" .. Live.ClassName(token):gsub("[^%a]", "")
			local race = "Orc"
			for _, r in ipairs(Data.RACES.Horde) do
				if Data.RACE_CLASSES.Horde[r][token] then race = r break end
			end
			out[name .. "-Demo"] = Live.DemoCharacter({
				name = name, realm = "Demo", class = token, race = L[race], ruleset = i % 3 == 0 and "hardcore" or "normal",
				level = 1, professions = profs, perks = {}, gear = {}, money = 123456, seen = 0, spent = 0, demo = true,
			})
		end
	end
	return out
end

-- Rewards the account has unlocked but not collected from Innkeeper Wiley yet.
function Core:RewardsToCollect()
	local out, earned = {}, Live.Earned()
	for _, r in ipairs(Live.Rewards()) do
		if earned >= r.level and r.owned == false then out[#out + 1] = r end
	end
	return out
end

-- 1.3: compares the challenges the game lists now with the list saved at the last login (per ruleset: Normal and
-- Hardcore have their own IDs) and says which are new and which are gone. The first login only saves the list.
-- A read with nothing, or under half of last time, is the client not having loaded its achievements yet: the old
-- list stays and nothing is said, so a slow load never reads as challenges being removed.
Core.CHANGES_SHOWN = 5 -- names per line, then "and N more"
local function NameList(ids, nameOf)
	local shown = {}
	for i = 1, math.min(#ids, Core.CHANGES_SHOWN) do shown[i] = nameOf(ids[i]) end
	local text = table.concat(shown, ", ")
	if #ids > Core.CHANGES_SHOWN then text = text .. " " .. string.format(L["and %d more"], #ids - Core.CHANGES_SHOWN) end
	return text
end

function Core:ChallengeChanges()
	if not self.db or Live.demo then return end
	local now, count = {}, 0
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			if not now[item.id] then count = count + 1 end
			now[item.id] = item.name or tostring(item.id)
		end
	end
	local ruleset = Live.IsHardcore() and "hardcore" or "normal"
	local known = self.db.knownChallenges[ruleset]
	local old, before = type(known) == "table" and type(known.ids) == "table" and known.ids or nil, 0
	for _ in pairs(old or {}) do before = before + 1 end
	if count == 0 or count * 2 < before then return end
	local build = Live.ClientInfo().build
	self.db.knownChallenges[ruleset] = { build = build, ids = now }
	local added, removed = {}, {}
	if before > 0 then
		for id in pairs(now) do if old[id] == nil then added[#added + 1] = id end end
		for id in pairs(old) do if now[id] == nil then removed[#removed + 1] = id end end
	end
	table.sort(added)
	table.sort(removed)
	self:Evidence("challengeSet", { build = build, from = type(known) == "table" and known.build or nil, ruleset = ruleset,
		count = count, compared = before > 0, added = #added, removed = #removed })
	if not self:Setting("announceChanges") then return end
	if #added > 0 then
		local text = NameList(added, function(id) return Live.AchievementLink(id) or now[id] end)
		self:Print(#added == 1 and string.format(L["New Legacy challenge since your last login: %s"], text)
			or string.format(L["%d new Legacy challenges since your last login: %s"], #added, text))
	end
	if #removed > 0 then
		local text = NameList(removed, function(id) return tostring(old[id]) end)
		self:Print(#removed == 1 and string.format(L["The game no longer lists this Legacy challenge: %s"], text)
			or string.format(L["The game no longer lists %d Legacy challenges: %s"], #removed, text))
	end
end

-- 1.3: one chat line when a challenge is nearly finished: 90% there, or one part left of three or more. Once per
-- challenge, ever. The first check on a ruleset only notes what is already that close (installing or updating the
-- addon shouldn't fill the chat); Closest to done on the Overview lists those.
Core.ALMOST_RATIO = 0.9
function Core.IsAlmostDone(item)
	if item.completed or (item.ratio or 0) <= 0 then return false end
	if item.ratio >= Core.ALMOST_RATIO then return true end
	local have, need = (item.detail or ""):match("^(%d+) / (%d+)$")
	have, need = tonumber(have), tonumber(need)
	return need ~= nil and need >= 3 and have == need - 1 and item.who == nil -- parts, not levels or skill
end

function Core:AlmostDone()
	if not self.db or Live.demo then return end
	local almost = self.db.almost
	local ruleset = Live.IsHardcore() and "hardcore" or "normal"
	local seeding = not almost.seeded[ruleset]
	local fresh = {}
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			if not almost.said[item.id] and Core.IsAlmostDone(item) then
				almost.said[item.id] = true
				fresh[#fresh + 1] = item
			end
		end
	end
	almost.seeded[ruleset] = true
	if seeding or #fresh == 0 then return end
	table.sort(fresh, function(a, b) return a.id < b.id end)
	self:Evidence("almostDone", { id = fresh[1].id, detail = fresh[1].detail, ratio = fresh[1].ratio, count = #fresh })
	if not self:Setting("announceAlmost") then return end
	local byID = {}
	for _, item in ipairs(fresh) do byID[item.id] = item end
	local ids = {}
	for i, item in ipairs(fresh) do ids[i] = item.id end
	self:Print(string.format(L["Almost done: %s"], NameList(ids, function(id)
		local item = byID[id]
		local name = Live.AchievementLink(id) or item.name or tostring(id)
		return item.detail and string.format("%s (%s)", name, item.detail) or name
	end)))
end

-- 1.3: a character's rested XP. With `now`, the pool grown since the snapshot (`seen`, the logout) at the offline
-- rate for where it logged out; without, the snapshot as it is (the character being played). `scale` is the learned
-- correction (db.rested). nil at level 60, without XP data, or for snapshots older than 1.3 (no `resting`).
-- Returns value, pct (of a level), cap, full, estimated, hours (offline), perHour, toFull (hours), rank (Well Rested).
function Core.RestedNow(ch, now, scale)
	if type(ch) ~= "table" then return nil end
	local xpMax = tonumber(ch.xpMax) or 0
	if (ch.level or 1) >= Data.MAX_LEVEL or xpMax <= 0 then return nil end
	local rank = 0
	for id, r in pairs(ch.perks or {}) do if tonumber(id) == Data.WELL_RESTED_NODE then rank = tonumber(r) or 0 end end
	local mult = 1 + Data.WELL_RESTED_PER_RANK * rank
	local cap = math.floor(xpMax * Data.RESTED_CAP * mult)
	local out = { rank = rank, cap = cap, value = math.min(tonumber(ch.rested) or 0, cap), hours = 0 }
	if ch.resting ~= nil then
		out.perHour = xpMax * Data.RESTED_PER_8H / 8 * mult * (ch.resting and 1 or Data.RESTED_OUTSIDE) * (scale or 1)
		if now and (ch.seen or 0) > 0 and now > ch.seen then
			out.hours = (now - ch.seen) / 3600
			out.value = math.min(cap, out.value + out.perHour * out.hours)
			out.estimated = true
		end
	end
	out.pct = math.floor(out.value / xpMax * 100 + 0.5)
	out.full = out.value >= cap
	if out.perHour and not out.full then out.toFull = (cap - out.value) / out.perHour end
	return out
end

-- The rested XP to show for a roster entry: the live pool for the character being played, else the estimate.
function Core:Rested(key, ch)
	local live = key == Live.CharacterKey()
	local scale = self.db and self.db.rested[ch and ch.resting and "inn" or "outside"]
	return Core.RestedNow(ch, not live and time() or nil, scale)
end

-- At login, before the snapshot is replaced: the estimate from the last logout against the game's real pool. Kept as
-- evidence; logins that didn't reach the cap (it hides the rate) move the learned correction halfway to what was seen.
function Core:MeasureRested()
	if not self.db or Live.demo then return end
	local old = self.db.characters[Live.CharacterKey()]
	local actual = Live.RestedXP()
	if type(old) ~= "table" or old.resting == nil or actual == nil or (old.level or 0) ~= Live.Level() then return end
	local state = old.resting and "inn" or "outside"
	local scale = self.db.rested[state]
	local est = Core.RestedNow(old, time(), scale)
	if not est or not est.estimated or est.hours < 1 then return end
	local before = math.min(tonumber(old.rested) or 0, est.cap)
	self:Evidence("rested", { estimate = math.floor(est.value), actual = actual, before = before, resting = old.resting,
		hours = math.floor(est.hours * 10 + 0.5) / 10, rank = est.rank, scale = scale })
	local predicted, gained = est.value - before, actual - before
	if est.full or actual >= est.cap or predicted <= 0 or gained < 0 then return end
	local seen = scale * gained / predicted
	self.db.rested[state] = math.max(0.25, math.min(4, (scale + seen) / 2))
end

-- 1.3: the saved build marked for raids (My builds on the Legacy Tree page), at most one.
function Core:RaidBuild()
	for i, b in ipairs(self.db and self.db.builds or {}) do
		if type(b) == "table" and b.raid and type(b.perks) == "table" then return b, i end
	end
end

function Core:SetRaidBuild(index)
	for i, b in ipairs(self.db.builds) do b.raid = (i == index) or nil end
end

-- Ranks between the character's perks and a build: every rank one of them has and the other doesn't.
function Core.RankDistance(ranks, perks)
	local n = 0
	for id, r in pairs(perks) do n = n + math.abs((ranks[tonumber(id) or id] or 0) - r) end
	for id, r in pairs(ranks) do if perks[id] == nil and perks[tostring(id)] == nil then n = n + r end end
	return n
end

-- On joining a raid (or logging in inside one): one chat line when the perks differ from the raid build.
local inRaid = false
function Core:CheckRaidBuild()
	local now = Live.InRaid()
	local joined = now and not inRaid
	inRaid = now
	if not joined or not self.db or Live.demo or not self:Setting("raidBuildWarning") then return end
	local build = self:RaidBuild()
	if not build then return end
	local trees = Live.Trees()
	if #trees == 0 then return end -- no Legacy trees yet (0 points): nothing to compare
	local ranks = {}
	for _, t in ipairs(trees) do for _, n in ipairs(t.nodes) do ranks[n.id] = n.rank end end
	local diff = Core.RankDistance(ranks, build.perks)
	self:Evidence("raidBuild", { name = build.name, diff = diff })
	if diff == 0 then return end
	self:Print(diff == 1 and string.format(L["In a raid: your Legacy perks differ from your raid build \"%s\" by 1 rank."], build.name or "?")
		or string.format(L["In a raid: your Legacy perks differ from your raid build \"%s\" by %d ranks."], build.name or "?", diff))
end

-- Once a session, a few seconds after the first login (the trees and collections have loaded by then).
local reminded = false
function Core:Remind()
	if reminded or not self.db then return end
	reminded = true
	self:ChallengeChanges()
	if self:Setting("remindUnspent") then
		local n = self:Unspent()
		if n == 1 then self:Print(L["You have 1 Legacy point to spend in the Legacy panel."])
		elseif n > 1 then self:Print(string.format(L["You have %d Legacy points to spend in the Legacy panel."], n)) end
	end
	if self:Setting("remindRewards") then
		for _, r in ipairs(self:RewardsToCollect()) do
			self:Print(string.format(L["%s is waiting for you at Innkeeper Wiley in Ratchet."], r.name or "?"))
		end
	end
end
Core.REMIND_DELAY = 8

function Core:ForgetCharacter(key)
	if self.db and self.db.characters[key] and key ~= Live.CharacterKey() then
		self.db.characters[key] = nil
		self.db.roles[key] = nil
		Live.Invalidate()
		if ns.UI then ns.UI:Refresh() end
		return true
	end
	return false
end

-- Refreshes are coalesced (CRITERIA_UPDATE fires on every kill) and never run in combat:
-- the window waits for PLAYER_REGEN_ENABLED instead of costing frame time mid-fight.
-- The snapshot of the character (trees, gear, professions) is the costly part. With the window closed nobody
-- looks at it, so kill progress records it at most every RECORD_EVERY seconds; the events that change what it
-- holds (RECORD_NOW: gear, level, skills, perks, the world loaded, an earn) record at once, and logout always does.
local pending, deferred, progressDue, recordDue = false, false, false, false
local lastRecord = -math.huge
local RECORD_EVERY = 30
local RECORD_NOW = {
	PLAYER_EQUIPMENT_CHANGED = true, PLAYER_LEVEL_UP = true, SKILL_LINES_CHANGED = true, TRAIT_CONFIG_UPDATED = true,
	PLAYER_ENTERING_WORLD = true, ACHIEVEMENT_EARNED = true, CRITERIA_EARNED = true, PLAYER_DEAD = true,
}
function Core:RequestRefresh()
	Live.Invalidate()
	if InCombatLockdown() then
		deferred = true
		return
	end
	if pending then return end
	pending = true
	C_Timer.After(0.5, function()
		pending = false
		if InCombatLockdown() then deferred = true return end
		local open = ns.UI and ns.UI.frame and ns.UI.frame:IsShown()
		local now = GetTime()
		if open or recordDue or progressDue or now - lastRecord >= RECORD_EVERY then
			Core:RecordCharacter(progressDue)
			lastRecord = now
			progressDue, recordDue = false, false
		end
		Core:AlmostDone()
		if ns.UI then ns.UI:Refresh() end
		if ns.Minimap and ns.Minimap.UpdateText then ns.Minimap:UpdateText() end
		if ns.MapZone then ns.MapZone:Refresh() end
	end)
end

local EVENTS = {
	"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
	"ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "TRAIT_CONFIG_UPDATED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"CONTENT_TRACKING_LIST_UPDATE", "TRACKED_ACHIEVEMENT_LIST_CHANGED", "ITEM_DATA_LOAD_RESULT", "PLAYER_DEAD",
	"CONFIRM_TALENT_WIPE", -- 1.2: the trainer's reset dialog
	"GROUP_ROSTER_UPDATE", -- 1.3: joining a raid (raid build warning)
	"CRITERIA_EARNED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD", -- 0.9.1: gear changes and the gear once it has loaded reach the snapshot
}
for _, e in ipairs(EVENTS) do Core:RegisterEvent(e) end

Core:SetScript("OnEvent", function(self, event, arg1, ...)
	if RECORD_NOW[event] then recordDue = true end
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			local db = type(YourLegacyDB) == "table" and YourLegacyDB or {}
			YourLegacyDB = Migrate(ApplyDefaults(db, DEFAULTS))
			self.db = YourLegacyDB
		end
	elseif event == "PLAYER_LOGIN" then
		self:MeasureRested() -- reads the last logout's snapshot, so before it's replaced
		self:RecordCharacter(true)
		if ns.Options then ns.Options:Register() end
		if ns.Minimap then ns.Minimap:Create() end
		if ns.MapZone then ns.MapZone:Register() end
		Live.HookLegacyUnlock(function() return Core.db.settings.unlockLegacy end, function(f) Core:Evidence("unlock", f) end)
	elseif event == "PLAYER_LOGOUT" then
		self:RecordCharacter(true)
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- arg1 = isInitialLogin: remind once after logging in, not after every loading screen
		if arg1 then C_Timer.After(Core.REMIND_DELAY, function() Core:Remind() end) end
		C_Timer.After(2, function() Core:CheckRaidBuild() end) -- logged in (or loaded) inside a raid
		self:RequestRefresh()
	elseif event == "GROUP_ROSTER_UPDATE" then
		-- fires on every roster change in a raid: only the step into one matters, and nothing on the page changes
		C_Timer.After(1, function() Core:CheckRaidBuild() end)
	elseif event == "CONFIRM_TALENT_WIPE" then
		self:OnTalentWipe(arg1, ...)
	elseif event == "CRITERIA_EARNED" then
		-- a part of a challenge got done: read the progress again once the refresh settles
		progressDue = true
		self:RequestRefresh()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if self:Setting("combatHide") and ns.UI and ns.UI.frame and ns.UI.frame:IsShown() then ns.UI.frame:Hide() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if deferred then deferred = false self:RequestRefresh() end
	elseif event == "ACHIEVEMENT_EARNED" then
		progressDue = true
		local points = Live.try(C_Traits and C_Traits.GetTraitCurrencyForAchievement, Data.POINTS_CURRENCY_ID, arg1) or 0
		if points > 0 and self.db then
			self.db.earnedLog[arg1] = { date = date("%Y-%m-%d"), char = Live.CharacterKey(), ruleset = Live.IsHardcore() and "hardcore" or "normal" }
			if self:Setting("sound") then
				for _, snd in ipairs(Data.SOUNDS) do if snd.key == self:Setting("soundKey") then Live.PlaySound(snd.id) end end
			end
			local _, name = Live.try(GetAchievementInfo, arg1)
			if self:Setting("announce") then
				self:Print(string.format(L["Legacy challenge earned: |cfff5dc9e%s|r (+%d)"], name or arg1, points))
			end
			-- 1.0: guild chat, with the challenge as a link the guild can click (off by default)
			if self:Setting("announceGuild") then
				local link = Live.AchievementLink(arg1) or name
				if link then Live.SendGuild(string.format(L["Legacy challenge earned: %s (+%d Legacy points)"], link, points)) end
			end
		end
		self:RequestRefresh()
	elseif event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
		-- 1.1: majorFactionID, newRenownLevel, oldRenownLevel. Wait for the refresh so the trees and pools are current.
		local newLevel, oldLevel = ...
		if arg1 == Data.REWARD_TRACK_FACTION_ID then self:Evidence("renown", { new = tonumber(newLevel), old = tonumber(oldLevel) }) end
		if arg1 == Data.REWARD_TRACK_FACTION_ID and self.db and tonumber(newLevel) and tonumber(newLevel) > (tonumber(oldLevel) or 0) then
			C_Timer.After(1, function() Core:NewPoint(tonumber(newLevel)) end)
		end
		self:RequestRefresh()
	elseif event == "PLAYER_DEAD" then
		-- A Hardcore death is final; mark the character (the player can undo it in the character panel).
		if Live.IsHardcore() and self.db then self.db.status[Live.CharacterKey()] = "fallen" end
		self:RequestRefresh()
	elseif event == "ITEM_DATA_LOAD_RESULT" then
		-- Fires for every item the client loads; only reward items change what the ledger shows.
		for _, reward in pairs(Data.REWARDS) do
			if reward.itemID == arg1 then self:RequestRefresh() break end
		end
	else
		self:RequestRefresh()
	end
end)

function Core:Toggle(tab)
	if not ns.UI then return end
	if InCombatLockdown() and self:Setting("combatHide") then
		self:Print(L["opens after combat."])
		return
	end
	ns.UI:Toggle(tab)
end

function Core:OpenOptions()
	if InCombatLockdown() then
		self:Print(L["options open after combat."])
		return
	end
	if ns.UI then ns.UI:ShowOptions() end
end

-- Wipes every saved setting, plan and snapshot (slash /yl reset, Options > Data).
function Core:ResetAll()
	YourLegacyDB = Migrate(ApplyDefaults({}, DEFAULTS))
	self.db = YourLegacyDB
	Live.Invalidate()
	self:RecordCharacter()
	if ns.UI then ns.UI:ApplySettings() end
	if ns.Minimap then ns.Minimap:Update() end
	self:Print(L["saved data cleared."])
end

function Core:Capture()
	self.db.capture = Live.Capture()
	self:Print(L["game state captured. Type /reload to write it to SavedVariables."])
end

local HELP = L["Commands:"] .. " /yl, /yl overview|challenges|roster|tree, /yl options, /yl status, /yl here, /yl report [challenge], /yl probe, /yl export, /yl capture, /yl shots, /yl reset"

SLASH_YOURLEGACY1 = "/yourlegacy"
SLASH_YOURLEGACY2 = "/yl"
SlashCmdList.YOURLEGACY = function(msg)
	local raw = strtrim(msg or "")
	msg = raw:lower()
	if msg == "" then
		Core:Toggle()
	elseif msg == "overview" or msg == "challenges" or msg == "roster" or msg == "tree" then
		Core:Toggle(msg)
	elseif msg == "options" or msg == "config" then
		Core:OpenOptions()
	elseif msg == "status" then
		local c = Live.Challenges()
		Core:Print(string.format(L["%d of %d Legacy points earned, %d challenges listed."], Live.Earned(), math.max(Live.MaxAvailable(), c.total), c.total))
	elseif msg == "export" then
		if ns.Export then ns.Export:Show() end
	elseif msg == "capture" then
		Core:Capture()
	elseif msg == "here" then
		if ns.Instance then ns.Instance:Report(true) end
	elseif msg == "probe" then
		if ns.Probe then ns.Probe:Run() end
	elseif msg == "report" or msg:match("^report ") then
		if ns.Report then ns.Report:Show(strtrim(raw:sub(7))) end
	elseif msg == "shots" then
		if ns.Shots then ns.Shots:Start() end
	elseif msg == "reset" then
		Core:ResetAll()
	else
		Core:Print(HELP)
	end
end

function YourLegacy_OnAddonCompartmentClick(_, button)
	if button == "RightButton" then Core:OpenOptions() else Core:Toggle() end
end

-- Key Bindings > AddOns > Your Legacy (Bindings.xml).
BINDING_HEADER_YOURLEGACY = "Your Legacy"
BINDING_NAME_YOURLEGACY_TOGGLE = L["Open or close Your Legacy"]
function YourLegacy_Toggle() Core:Toggle() end
