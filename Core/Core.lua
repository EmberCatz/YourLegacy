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
	settings = {
		scale = 1,           -- window scale
		minimap = true,      -- show the minimap button
		minimapAngle = 215,  -- degrees around the minimap
		locked = false,      -- window can't be dragged
		combatHide = true,   -- close the window when combat starts
		announce = true,     -- chat line when a challenge is earned
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
		self:Evidence("reset", { cost = old.money - snap.money, ranks = old.spent - snap.spent, trees = trees })
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

-- Once a session, a few seconds after the first login (the trees and collections have loaded by then).
local reminded = false
function Core:Remind()
	if reminded or not self.db then return end
	reminded = true
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
		self:RecordCharacter(true)
		if ns.Options then ns.Options:Register() end
		if ns.Minimap then ns.Minimap:Create() end
		if ns.MapZone then ns.MapZone:Register() end
	elseif event == "PLAYER_LOGOUT" then
		self:RecordCharacter(true)
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- arg1 = isInitialLogin: remind once after logging in, not after every loading screen
		if arg1 then C_Timer.After(Core.REMIND_DELAY, function() Core:Remind() end) end
		self:RequestRefresh()
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
