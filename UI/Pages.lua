-- What the four ledger pages share (0.9 split them into Overview.lua, Challenges.lua, Roster.lua, Tree.lua):
-- the challenge tooltip and click, the challenge row, class icons and the ruleset tag.
local _, ns = ...
local T, UI, Live, L = ns.Theme, ns.UI, ns.Live, ns.L
local C = T.C

local P = {}
ns.Pages = P

local function db() return ns.Core.db end
local Data = ns.Data

local function IsClassSub(sub)
	for _, token in ipairs(Data.CLASS_ORDER) do if Live.ClassName(token) == sub then return true end end
	return false
end

-- 1.0: how sure the ledger is of a rule (Data.RULES), as a muted suffix after the rule's line. Confirmed rules get none.
local STATUS_WORD = { reported = L["(reported)"], unchecked = L["(unchecked)"] }
function P.RuleTag(key)
	local rule = Data.RULE_BY_KEY[key]
	local word = rule and STATUS_WORD[rule.status]
	return word and (" " .. T.Hex(C.muted) .. word .. "|r") or ""
end

-- Feature 1: how a challenge counts, only where its data shows it (research/17-v09-feedback-features.md):
-- several parts → all of them; no parts and a number in the description → one character reaches it.
-- Anything else (PvP ranks, a single quest or week) gets no line. Returns the line and its rule (Data.RULES).
function P.CreditRule(item, criteria)
	criteria = criteria or Live.Criteria(item.id)
	if #criteria >= 2 then return string.format(L["Needs all %d listed."], #criteria), "allParts" end
	-- level and skill challenges have no criteria or a single one (the skill itself)
	local target = tonumber((item.description or ""):match("(%d+)"))
	if not target then return nil end
	if IsClassSub(item.sub) then return string.format(L["One character has to reach level %d."], target), "reach" end
	if target >= 75 then return string.format(L["One character has to reach %d skill."], target), "reach" end
	return nil
end

-- Feature 2: ranks in perks that no longer help at a level (Data.DEAD_PERKS). ranks = { [nodeID] = rank }.
-- Returns { { id, rank, why } }, total points.
function P.DeadPerks(ranks, level)
	local out, total = {}, 0
	for id, r in pairs(ranks or {}) do
		local dead = Data.DEAD_PERKS[tonumber(id) or id]
		if dead and (r or 0) > 0 and (level or 1) >= dead.level then
			out[#out + 1] = { id = tonumber(id) or id, rank = r, why = dead.why, level = dead.level }
			total = total + r
		end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out, total
end

-- Perk names by node ID (the game's localized names), for dead-perk lists.
function P.PerkName(id)
	for _, t in ipairs(Live.Trees()) do
		for _, n in ipairs(t.nodes) do if n.id == id then return n.name end end
	end
	return tostring(id)
end

-- Feature 6: dungeon brackets a character is about to outlevel with clears still missing. Off unless
-- Data.OUTLEVEL_WARNING (unverified rule). Returns { { item, missing, max } }.
-- The open bracket challenges, worked out once per challenge list (a refresh), not per card.
local bracketCache, bracketFor
local function OpenBrackets()
	local challenges = Live.Challenges()
	if bracketFor == challenges then return bracketCache end
	bracketCache, bracketFor = {}, challenges
	for _, g in ipairs(challenges.groups) do
		for _, item in ipairs(g.items) do
			if not item.completed then
				local criteria, marker, missing = Live.Criteria(item.id), nil, 0
				for _, c in ipairs(criteria) do
					for i, bracket in ipairs(Data.DUNGEON_BRACKETS) do if c.assetID == bracket.marker then marker = i end end
					if not c.done then missing = missing + 1 end
				end
				if marker and missing > 0 then bracketCache[marker] = { item = item, missing = missing } end
			end
		end
	end
	return bracketCache
end
-- 1.1: the bracket a dungeon list belongs to, found by one of its dungeons' criteria asset IDs.
function P.BracketOf(criteria)
	for _, c in ipairs(criteria or {}) do
		for _, b in ipairs(Data.DUNGEON_BRACKETS) do if c.assetID == b.marker then return b end end
	end
end

function P.OutlevelWarnings(level)
	local out = {}
	if not Data.OUTLEVEL_WARNING then return out end
	local open = OpenBrackets()
	for i, bracket in ipairs(Data.DUNGEON_BRACKETS) do
		local b = open[i]
		if b and level >= bracket.max - Data.OUTLEVEL_MARGIN and level <= bracket.max then
			out[#out + 1] = { item = b.item, missing = b.missing, max = bracket.max }
		end
	end
	return out
end
function P.OutlevelText(w)
	return w.missing == 1 and string.format(L["%s: 1 clear left before level %d."], w.item.name, w.max)
		or string.format(L["%s: %d clears left before level %d."], w.item.name, w.missing, w.max)
end

-- Feature 5: which saved characters have done each part. Live character from the live criteria, the others from
-- their snapshots (ch.parts / ch.explore). Returns names by criteria key, and whether any other character has data.
local function PartsByCharacter(item)
	local me = Live.CharacterKey()
	local byKey, others = {}, false
	for key, ch in pairs(db().characters) do
		if key ~= me then
			local parts = ch.parts and ch.parts[item.id]
			if parts then
				others = true
				for k in pairs(parts) do
					local list = byKey[tonumber(k) or k] or {}
					list[#list + 1] = ch.name
					byKey[tonumber(k) or k] = list
				end
			elseif ch.parts then
				others = true
			end
		end
	end
	return byKey, others
end

-- Feature 4: the character closest to finishing the nested challenge (Explorer) and the zones it still needs.
local function ExplorationLines(item)
	local zones = Live.NestedParts(item.id)
	if not zones or #zones == 0 then return end
	local me = Live.CharacterKey()
	local best, bestCount, bestDone = nil, -1, nil
	local function consider(name, done)
		local n = 0
		for _, z in ipairs(zones) do if done[z.key] then n = n + 1 end end
		if n > bestCount then best, bestCount, bestDone = name, n, done end
	end
	local live = {}
	for _, z in ipairs(zones) do if z.done then live[z.key] = true end end
	consider(Live.PlayerName(), live)
	for key, ch in pairs(db().characters) do
		if key ~= me and ch.exploreID == item.id and type(ch.explore) == "table" then
			local done = {}
			for k in pairs(ch.explore) do done[tonumber(k) or k] = true end
			consider(ch.name, done)
		end
	end
	GameTooltip:AddLine(L["Each character explores on its own."] .. P.RuleTag("explore"), T.unpack(C.ink2))
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(string.format(L["Closest: %s, %d of %d zones"], best, bestCount, #zones), T.unpack(C.head))
	local missing = {}
	for _, z in ipairs(zones) do if not bestDone[z.key] then missing[#missing + 1] = z.text end end
	for i, text in ipairs(missing) do
		if i > 12 then GameTooltip:AddLine(string.format(L["and %d more"], #missing - 12), T.unpack(C.muted)) break end
		GameTooltip:AddLine(text, T.unpack(C.muted))
	end
	return true
end

-- Shared challenge tooltip: scope, description, how it counts, criteria (with who did each part), points,
-- where and when it was earned.
function P.ShowChallengeTooltip(owner, item)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(item.name, T.unpack(item.completed and C.goldHi or C.white))
	local scope = Live.Scope(item.id)
	if scope then
		-- the account flag means the challenge is earned once for the account; its progress can still be per
		-- character (exploration is, 2026-11-07 capture), so the label no longer says "account-wide progress"
		GameTooltip:AddLine(scope == "account" and (L["Earned once for the account"] .. P.RuleTag("once")) or L["Progress per character"], T.unpack(C.ink2))
	end
	if item.description and item.description ~= "" then GameTooltip:AddLine(item.description, 0.78, 0.73, 0.65, true) end
	local criteria = Live.Criteria(item.id)
	local rule, ruleKey = P.CreditRule(item, criteria)
	if rule then GameTooltip:AddLine(rule .. P.RuleTag(ruleKey), T.unpack(C.head)) end
	-- 1.1: a dungeon list's level range (Data.DUNGEON_BRACKETS), with this character's level
	local bracket = P.BracketOf(criteria)
	if bracket and not item.completed then
		GameTooltip:AddLine(string.format(L["These dungeons are for levels %d to %d. You're level %d."], bracket.min, bracket.max, Live.Level()), T.unpack(C.ink2))
	end
	local explored = ExplorationLines(item)
	-- 1.0 instance helper: inside a dungeon or raid this challenge counts for, its parts there are gold
	local placeName, hereKeys
	if ns.Instance then placeName, hereKeys = ns.Instance.Here(item.id) end
	if placeName and not item.completed then
		GameTooltip:AddLine(string.format(L["You're in %s."], placeName), T.unpack(C.head))
	end
	if #criteria > 1 and not explored then
		GameTooltip:AddLine(" ")
		local byKey, others = PartsByCharacter(item)
		local myName = Live.PlayerName()
		for i, c in ipairs(criteria) do
			if i > 12 then GameTooltip:AddLine(string.format(L["and %d more"], #criteria - 12), 0.56, 0.6, 0.72) break end
			-- the boss that gives a dungeon's credit, once a fight showed it (Core/Instance.lua)
			local boss = ns.Instance and ns.Instance.BossFor(c)
			local text = boss and string.format("%s (%s)", c.text, boss) or c.text
			-- 1.1: a dungeon or raid part gets its level range (guide data, Data.DUNGEON_LEVELS)
			-- (not only kill parts: "Ragefire Chasm or Hall of Thanes" is type 78 with no asset, report 2026-11-10)
			if bracket then text = Data.WithLevels(text) end
			local hereColor = hereKeys and hereKeys[c.key] and not c.done and C.head
			if others then
				-- who has done this part: the live character first, then the saved ones
				local names = {}
				if c.done and myName then names[1] = myName end
				for _, n in ipairs(byKey[c.key] or {}) do names[#names + 1] = n end
				local r, g, b = T.unpack(hereColor or (#names > 0 and C.teal) or C.muted)
				GameTooltip:AddLine(#names > 0 and string.format(L["%s: %s"], text, table.concat(names, ", ")) or text, r, g, b)
			else
				local r, g, b = T.unpack(hereColor or (c.done and C.teal) or C.muted)
				GameTooltip:AddLine((c.done and L["Done: "] or "") .. text, r, g, b)
			end
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(item.points == 1 and L["1 Legacy point"] or string.format(L["%d Legacy points"], item.points), T.unpack(C.gold))
	local entry = db().earnedLog[item.id]
	if item.completed then
		local ruleset = entry and (entry.ruleset == "hardcore" and L[" on Hardcore"] or L[" on Normal"]) or ""
		GameTooltip:AddLine(string.format(L["Earned %s"], item.date or (entry and entry.date) or "") .. ruleset, T.unpack(C.teal))
		-- The game doesn't say where a challenge was earned; only earns this addon saw carry a ruleset.
		if not entry then GameTooltip:AddLine(L["Ruleset unknown: earned before Your Legacy was running."], T.unpack(C.muted)) end
	elseif item.detail then
		GameTooltip:AddLine(item.who and string.format(L["%s, best: %s"], item.detail, item.who) or item.detail, T.unpack(C.parch))
	end
	if item.gate then
		GameTooltip:AddLine(string.format(L["The character with this profession needs level %d first."], item.gate), T.unpack(C.fire))
	end
	local expandable = owner.onExpand and #criteria > 1
	local canTrack = not item.completed and not Live.TrackingDisabled()
	if canTrack and Live.Tracked()[item.id] then
		GameTooltip:AddLine(L["Tracked. Shift-click to stop tracking it."], T.unpack(C.teal))
	end
	if expandable then
		GameTooltip:AddLine(canTrack and not Live.Tracked()[item.id] and L["Click to show or hide its checklist, Shift-click to track it."]
			or L["Click to show or hide its checklist."], T.unpack(C.muted))
	elseif canTrack and not Live.Tracked()[item.id] then
		GameTooltip:AddLine(L["Click to open it in the Legacy panel, Shift-click to track it."], T.unpack(C.muted))
	elseif not canTrack then
		GameTooltip:AddLine(L["Click to open it in the Legacy panel."], T.unpack(C.muted))
	end
	GameTooltip:Show()
end

-- Click opens Blizzard's Legacy panel; the quest-watch modifier (Shift unless rebound) pins it to the tracker.
local TRACK_MESSAGES = {
	disabled = L["Achievement tracking is turned off on this realm."],
	done = L["That challenge is already done."],
	failed = L["The game didn't accept the tracking request."],
	full = L["You're already tracking %d achievements. Untrack one first."],
}
function P.ClickChallenge(owner)
	local item = owner.item
	if not item then return end
	-- 1.0: with a chat box open, the chat-link modifier (Shift) links the challenge, as Blizzard's achievement
	-- window does; with none open the same click falls through to tracking.
	if IsModifiedClick and IsModifiedClick("CHATLINK") and Live.InsertChatLink(Live.AchievementLink(item.id)) then return end
	if not (IsModifiedClick and IsModifiedClick("QUESTWATCHTOGGLE")) and owner.onExpand and #Live.Criteria(item.id) > 1 then
		owner.onExpand(item)
		return
	end
	if IsModifiedClick and IsModifiedClick("QUESTWATCHTOGGLE") then
		local result, limit = Live.ToggleTracking(item.id)
		if TRACK_MESSAGES[result] then ns.Core:Print(string.format(TRACK_MESSAGES[result], limit or 0)) end
		UI:Refresh()
		if owner:IsMouseOver() then P.ShowChallengeTooltip(owner, item) end
	else
		Live.OpenLegacyPanel(item.id)
	end
end

-- Thin mark on the left edge of a tracked row or cell.
function P.TrackedMark(parent)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetColorTexture(T.unpack(C.teal))
	t:SetWidth(3)
	t:SetPoint("TOPLEFT", 0, -3)
	t:SetPoint("BOTTOMLEFT", 0, 3)
	t:Hide()
	return t
end

-- A challenge as a table row: icon, name (and description), the state on the right, a 3px heat bar under the
-- state while it's under way. Rows are separated by 1px rules, never boxed. Used by Overview and Challenges.
function P.CreateChallengeRow(parent, width, withDescription)
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(width, 38)
	T.RowBackground(r)
	r.tile = T.Tile(r, 24)
	r.tile:SetPoint("LEFT", 4, 0)
	r.name = T.Text(r, T.F.bodyL, C.ink)
	r.name:SetPoint("LEFT", 38, 0)
	r.name:SetWidth(withDescription and 240 or width - 190)
	r.name:SetWordWrap(false)
	if withDescription then
		r.desc = T.Text(r, T.F.small, C.muted)
		r.desc:SetPoint("LEFT", 290, 0)
		r.desc:SetWidth(width - 290 - 170)
		r.desc:SetWordWrap(false)
	end
	r.state = T.Text(r, T.F.body, C.ink2, "RIGHT")
	r.state:SetPoint("RIGHT", -8, 4)
	r.gate = T.Text(r, T.F.small, C.warn, "RIGHT")
	r.gate:SetPoint("RIGHT", -8, -8)
	r.line = T.Bar(r, 140, 3)
	r.line:SetPoint("TOPRIGHT", r, "RIGHT", -8, -8)
	r:SetScript("OnEnter", function(self) if self.item then P.ShowChallengeTooltip(self, self.item) end end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r:SetScript("OnClick", P.ClickChallenge)
	r.tracked = P.TrackedMark(r)
	function r:SetItem(item)
		self.item = item
		self.tracked:SetShown(Live.Tracked()[item.id] or false)
		self.tile:SetIcon(item.icon or "glyph:Star")
		local started = item.completed or (item.ratio or 0) > 0
		self.tile:SetState(item.completed and C.heat6 or C.rule, not started)
		self.name:SetText(item.name)
		if self.desc then self.desc:SetText(item.description or "") end
		local entry = db().earnedLog[item.id]
		self.gate:SetText(not item.completed and item.gate and string.format(L["needs level %d"], item.gate) or "")
		if item.completed then
			local hc = entry and entry.ruleset == "hardcore"
			self.name:SetTextColor(T.unpack(C.ink))
			self.state:SetText((hc and (T.Hex(C.hc) .. L["Hardcore"] .. "|r  ") or "") .. (item.date or (entry and entry.date) or L["Done"]))
			self.line:Hide()
		else
			self.name:SetTextColor(T.unpack(started and C.ink or C.ink2))
			self.state:SetText(item.detail or "")
			-- the bar moves down when there's no gate line under the state
			self.line:SetShown(item.ratio > 0 and not item.gate)
			self.line:SetHeatValue(item.ratio)
		end
	end
	return r
end

-- 1.0: what a character is for (Data.ROLES; nil = alt). Ignore hides its roster card behind "Show ignored".
function P.Role(key) return db().roles[key] or "alt" end

-- The game's class icon atlas (classicon-warlock) when the client has it.
function P.ClassIcon(texture, token)
	local atlas = "classicon-" .. token:lower()
	if C_Texture and Live.try(C_Texture.GetAtlasInfo, atlas) then
		texture:SetAtlas(atlas)
		return true
	end
	return false
end
ns.ClassIcon = P.ClassIcon

function P.RulesetTag(ruleset)
	return ruleset == "hardcore" and (T.Hex(C.hc) .. L["Hardcore"] .. "|r") or (T.Hex(C.ink2) .. L["Normal"] .. "|r")
end
ns.RulesetTag = P.RulesetTag

-- The crafts suggested for a class, as localized names in the order the Tradeskills section lists them.
function P.SuggestedCrafts(token)
	local out, want = {}, ns.Data.SUGGESTED_CRAFTS[token] or {}
	for _, craft in ipairs(ns.Data.CRAFT_ORDER) do
		if want[craft.id] then out[#out + 1] = L[craft.name] end
	end
	return out
end
