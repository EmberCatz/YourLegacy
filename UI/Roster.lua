-- Roster (0.9): a card per character on the Legacy panel's own card art (Legacy-Challenge-Cards). Each card shows
-- the class portrait, the name in its class colour, level and the next class challenge, both crafts with their bars
-- and the next Legacy point, suggested crafts for the class, and perks spent. Click opens the character panel,
-- which docks on the right; the cards reflow into the space left instead of sitting under it. Right-click removes.
-- Below, the classes not started yet as compact cards; a click opens the class planner.
local _, ns = ...
local T, UI, Live, Data, L, P = ns.Theme, ns.UI, ns.Live, ns.Data, ns.L, ns.Pages
local C = T.C

local function db() return ns.Core.db end

local roster = {}
local FULL_W = UI.CONTENT_W - 14 -- inside the scroll
local GAP, CARD_MIN_W, CARD_H, PLAN_H = 12, 250, 228, 66
local BANNER_H = PLAN_H -- a character card's banner: the card art at the height it's drawn for
local DOCK_W = 404 + 12          -- the docked panel and its gap (UI/Character.lua)

-- Add a field to Blizzard's table; never reassign the global itself (that would taint it).
StaticPopupDialogs.YOURLEGACY_FORGET = {
	text = L["Remove %s from Your Legacy? It comes back the next time you log in with that character."],
	button1 = YES, button2 = NO,
	OnAccept = function(_, key) ns.Core:ForgetCharacter(key) end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

-- The milestone's word as the game names it ("Novice" from "Novice Warlock"), so every client language matches.
local function MilestoneWords(token)
	local words, name = {}, Live.ClassName(token)
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			if item.sub == name then words[#words + 1] = (item.name or ""):match("^(%S+)%s") end
		end
	end
	return words
end

-- The next class challenge for a character level: "Next: Novice at 25, 18 levels to go".
local function NextLevelGoal(level, token)
	for i, target in ipairs(Data.LEVEL_MILESTONES) do
		if level < target then
			local game = MilestoneWords(token)
			local names = { game[1] or L["Novice"], game[2] or L["Experienced"], game[3] or L["Master"] }
			local togo = target - level
			return togo == 1 and string.format(L["Next: %s at %d, 1 level to go"], names[i], target)
				or string.format(L["Next: %s at %d, %d levels to go"], names[i], target, togo)
		end
	end
	return L["All three class challenges reached"]
end

-- The next Legacy point a craft gives (150, 225, 300) and whether the character's level blocks it.
local function NextSkillGoal(p, level)
	if not p.craft then return nil end
	for _, target in ipairs({ 150, 225, 300 }) do
		if (p.skill or 0) < target then
			local need = Data.PROF_GATES[target]
			if need and level < need then
				return string.format(L["%d for the next point, needs level %d"], target, need), true
			end
			return string.format(L["%d for the next point"], target), false
		end
	end
	return L["Every point from this craft earned"], false
end

-- One profession on a card: "Tailoring, Apprentice (suggested)" left, "1 / 75" right, a bar with rank ticks and
-- what the next Legacy point needs.
local function ProfLine(parent)
	local p = CreateFrame("Frame", nil, parent)
	p:SetHeight(34)
	p.name = T.Text(p, T.F.body, C.ink)
	p.name:SetPoint("TOPLEFT")
	p.name:SetPoint("RIGHT", -64, 0)
	p.name:SetWordWrap(false)
	p.value = T.Text(p, T.F.body, C.ink2, "RIGHT")
	p.value:SetPoint("TOPRIGHT")
	p.bar = T.Bar(p, 100, 3)
	p.bar:SetPoint("TOPLEFT", 0, -17)
	p.bar:SetTicks({ 75 / 300, 150 / 300, 225 / 300 })
	p.next = T.Text(p, T.F.small, C.muted)
	p.next:SetPoint("TOPLEFT", p.bar, "BOTTOMLEFT", 0, -3)
	p.next:SetPoint("RIGHT")
	p.next:SetWordWrap(false)
	function p:Layout(width)
		self:SetWidth(width)
		self.bar.width = width
		self.bar:SetWidth(width)
		self.bar:SetTicks({ 75 / 300, 150 / 300, 225 / 300 })
	end
	return p
end

local function Suggested(token, skillLine)
	return Data.SUGGESTED_CRAFTS[token] and Data.SUGGESTED_CRAFTS[token][skillLine] or false
end

-- ", Bank" after race and class for any role but Alt (the default says nothing).
local function RoleTag(key)
	local role = P.Role(key)
	if role == "alt" then return "" end
	for _, r in ipairs(Data.ROLES) do
		if r.key == role then return ", " .. T.Hex(role == "main" and C.head or C.muted) .. L[r.name] .. "|r" end
	end
	return ""
end

local function CreateCharacterCard(parent)
	-- 0.9.1: the Legacy card art as a banner across the top, at the height the unstarted-class cards use (it looked
	-- smeared stretched over the whole card), a Blizzard inset for the rest. Text sits on card.content.
	local card = T.Card(parent, 300, CARD_H, BANNER_H)
	local box = card.content
	card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- the class colour, faint, across the banner (fades down)
	card.wash = card.art:CreateTexture(nil, "BACKGROUND", nil, 1)
	card.wash:SetPoint("TOPLEFT", 4, -4)
	card.wash:SetPoint("TOPRIGHT", -4, -4)
	card.wash:SetHeight(BANNER_H - 10)
	card.wash:SetColorTexture(1, 1, 1, 1)
	-- the banner: the class icon in Blizzard's Legacy icon frame, name and race/class/ruleset, the level on the right
	card.portrait = T.IconFrame(box, 36)
	card.portrait:SetPoint("LEFT", box, "TOPLEFT", 16, -BANNER_H / 2)
	card.icon = card.portrait.icon
	card.mono = T.Text(card.portrait, T.F.mid, C.ink, "CENTER")
	card.mono:SetPoint("CENTER", 0, 1)
	card.name = T.Text(box, T.F.mid, C.ink)
	card.name:SetPoint("BOTTOMLEFT", card.portrait, "RIGHT", 14, 1)
	card.name:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -60, -BANNER_H / 2 + 1)
	card.name:SetWordWrap(false)
	card.sub = T.Text(box, T.F.small, C.ink2)
	card.sub:SetPoint("TOPLEFT", card.portrait, "RIGHT", 14, -3)
	card.sub:SetPoint("TOPRIGHT", box, "TOPRIGHT", -60, -BANNER_H / 2 - 3)
	card.sub:SetWordWrap(false)
	card.level = T.Text(box, T.F.big, C.ink, "RIGHT")
	card.level:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -16, -BANNER_H / 2 - 1)
	card.levelLabel = T.Text(box, T.F.small, C.head, "RIGHT")
	card.levelLabel:SetPoint("TOPRIGHT", card.level, "BOTTOMRIGHT", 0, -2)
	card.levelLabel:SetText(L["Level"])
	-- the body, in the inset
	local top = -(BANNER_H + 8)
	card.levelBar = T.Bar(box, 100, 3)
	card.levelBar:SetPoint("TOPLEFT", 14, top - 4)
	card.levelNext = T.Text(box, T.F.small, C.muted)
	card.levelNext:SetPoint("TOPLEFT", card.levelBar, "BOTTOMLEFT", 0, -4)
	card.levelNext:SetPoint("RIGHT", -14, 0)
	card.levelNext:SetWordWrap(false)
	card.profs = { ProfLine(box), ProfLine(box) }
	card.profs[1]:SetPoint("TOPLEFT", 14, top - 30)
	card.profs[2]:SetPoint("TOPLEFT", card.profs[1], "BOTTOMLEFT", 0, -4)
	card.noProf = T.Text(box, T.F.small, C.muted)
	card.noProf:SetPoint("TOPLEFT", 14, top - 32)
	card.noProf:SetPoint("RIGHT", -14, 0)
	card.noProf:SetJustifyV("TOP")
	card.footRule = T.Rule(box)
	card.footRule:SetPoint("BOTTOMLEFT", 10, 28)
	card.footRule:SetPoint("BOTTOMRIGHT", -10, 28)
	card.perks = T.Text(box, T.F.small, C.ink2)
	card.perks:SetPoint("BOTTOMLEFT", 14, 10)
	card.seen = T.Text(box, T.F.small, C.muted, "RIGHT")
	card.seen:SetPoint("BOTTOMRIGHT", -14, 10)
	-- 0.9: a dungeon bracket about to be outleveled (only while Data.OUTLEVEL_WARNING is on)
	card.warn = T.Text(box, T.F.small, C.warn)
	card.warn:SetPoint("BOTTOMLEFT", 14, 34)
	card.warn:SetPoint("RIGHT", -14, 0)
	card.warn:SetWordWrap(false)
	function card:Layout(width)
		self:SetWidth(width)
		self.levelBar.width = width - 28
		self.levelBar:SetWidth(width - 28)
		self.levelBar:SetTicks({ 25 / 60, 45 / 60 })
		for _, p in ipairs(self.profs) do p:Layout(width - 28) end
	end
	card:SetScript("OnClick", function(self, button)
		if not self.charKey then return end
		if button == "RightButton" then
			if self.charKey == Live.CharacterKey() then
				ns.Core:Print(L["you can't remove the character you're playing."])
			else
				StaticPopup_Show("YOURLEGACY_FORGET", self.charName, nil, self.charKey)
			end
		elseif ns.Character then
			ns.Character:Toggle(self.charKey)
		end
	end)
	card.onEnter = function(self)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 16, 4) -- 1.1: at the mouse (the user)
		GameTooltip:SetText(self.charName or "", T.unpack(C.ink))
		-- perks that no longer help at this level, and what they'd free
		for _, d in ipairs(self.dead or {}) do
			GameTooltip:AddLine(string.format(L["%s %d: %s"], P.PerkName(d.id), d.rank, L[d.why]), T.unpack(C.warn))
		end
		if self.deadTotal and self.deadTotal > 0 then
			GameTooltip:AddLine(string.format(L["Reset at your class trainer to spend them elsewhere (%d gold)."], Data.RESET_COST_GOLD)
				.. P.RuleTag("reset"), T.unpack(C.muted), true)
		end
		for _, w in ipairs(self.warnings or {}) do GameTooltip:AddLine(P.OutlevelText(w), T.unpack(C.warn)) end
		GameTooltip:AddLine(L["Click for gear and professions. Right-click to remove."], T.unpack(C.muted))
		GameTooltip:Show()
	end
	card.onLeave = function() GameTooltip:Hide() end
	return card
end

-- A class not started yet: icon, name, the plan so far, suggested crafts. Opens the class planner.
-- 0.9.1: the icon sits in Blizzard's Legacy icon frame, centred on the card's height.
local function CreatePlanCard(parent)
	local card = T.Card(parent, 300, PLAN_H)
	card.frame = T.IconFrame(card, 34)
	card.frame:SetPoint("LEFT", 16, 0)
	card.icon = card.frame.icon
	card.name = T.Text(card, T.F.name, C.ink)
	card.name:SetPoint("TOPLEFT", card.frame, "TOPRIGHT", 14, 6)
	card.star = T.Text(card, T.F.label, C.accent)
	card.star:SetPoint("LEFT", card.name, "RIGHT", 8, 0)
	card.star:SetText(L["next"])
	card.tag = T.Text(card, T.F.small, C.muted, "RIGHT")
	card.tag:SetPoint("TOPRIGHT", -12, -12)
	card.detail = T.Text(card, T.F.small, C.ink2)
	card.detail:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
	card.detail:SetPoint("RIGHT", -12, 0)
	card.detail:SetWordWrap(false)
	card.suggest = T.Text(card, T.F.small, C.muted)
	card.suggest:SetPoint("TOPLEFT", card.detail, "BOTTOMLEFT", 0, -3)
	card.suggest:SetPoint("RIGHT", -12, 0)
	card.suggest:SetWordWrap(false)
	card:SetScript("OnClick", function(self) ns.Character:TogglePlan(self.intentClass) end)
	card:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 16, 4) -- 1.1: at the mouse (the user)
		GameTooltip:SetText(Live.ClassName(self.intentClass), T.unpack(C.ink))
		GameTooltip:AddLine(L["Click to plan it: ruleset, race and crafts."], T.unpack(C.ink2))
		GameTooltip:Show()
	end)
	card:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return card
end

-- Profession coverage: per craft, who has it (best first), and which planned classes mean to take it.
local CRAFT_H, CRAFT_MIN_W = 74, 140
function roster.Coverage()
	local out = {}
	for _, craft in ipairs(Data.CRAFT_ORDER) do
		local holders, planned = {}, {}
		for _, ch in pairs(ns.Core:Characters()) do
			for _, p in ipairs(ch.professions or {}) do
				if p.skillLine == craft.id then holders[#holders + 1] = { name = ch.name, skill = p.skill or 0 } end
			end
		end
		table.sort(holders, function(a, b)
			if a.skill ~= b.skill then return a.skill > b.skill end
			return (a.name or "") < (b.name or "")
		end)
		for _, token in ipairs(Data.CLASS_ORDER) do
			local plan = db().classPlans[token]
			if type(plan) == "table" and type(plan.profs) == "table" and plan.profs[craft.id] then planned[#planned + 1] = token end
		end
		out[#out + 1] = { id = craft.id, name = L[craft.name], holders = holders, planned = planned }
	end
	return out
end

local function CraftCoverage(y, width)
	roster.crafts:Reset()
	roster.cropsH:SetWidth(width)
	roster.cropsH:ClearAllPoints()
	roster.cropsH:SetPoint("TOPLEFT", roster.child, "TOPLEFT", 0, -(y + 6))
	local list = roster.Coverage()
	local open = 0
	for _, c in ipairs(list) do if #c.holders == 0 then open = open + 1 end end
	roster.cropsH.hint:SetText(open == 0 and L["Every craft is covered"] or (open == 1 and L["1 craft nobody has"] or string.format(L["%d crafts nobody has"], open)))
	y = y + 42
	-- even rows: the most columns that divide the crafts and still fit (6 across, 3 beside the docked panel)
	local cols = 1
	for c = #list, 1, -1 do
		if #list % c == 0 and c * CRAFT_MIN_W + (c - 1) * GAP <= width then cols = c break end
	end
	local w = math.floor((width - (cols - 1) * GAP) / cols)
	for i, craft in ipairs(list) do
		local c = roster.crafts:Acquire()
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		c:SetWidth(w)
		c.bar.width = w - 4
		c.bar:SetWidth(w - 4)
		c.bar:SetTicks({ 0.5, 0.75 })
		c:SetPoint("TOPLEFT", roster.child, "TOPLEFT", col * (w + GAP), -(y + row * (CRAFT_H + 4)))
		c.craftName, c.holders, c.planned = craft.name, craft.holders, craft.planned
		c.name:SetText(craft.name)
		local best = craft.holders[1]
		local plannedNames = {}
		for _, token in ipairs(craft.planned) do plannedNames[#plannedNames + 1] = Live.ClassName(token) end
		if best then
			c.who:SetText(best.name)
			c.who:SetTextColor(T.unpack(C.ink))
			c.value:SetText(string.format("%d / 300", best.skill))
			c.bar:Show()
			c.bar:SetHeatValue(best.skill / 300)
			local more = #craft.holders > 1 and string.format(L["and %d more"], #craft.holders - 1) or ""
			if #plannedNames > 0 then more = (more ~= "" and (more .. ", ") or "") .. string.format(L["Planned for %s"], table.concat(plannedNames, ", ")) end
			c.more:SetText(more)
		else
			c.who:SetText(L["Nobody yet"])
			c.who:SetTextColor(T.unpack(C.warn))
			c.value:SetText("")
			c.bar:Hide()
			c.more:SetText(#plannedNames > 0 and string.format(L["Planned for %s"], table.concat(plannedNames, ", ")) or "")
		end
	end
	return y + math.ceil(#list / cols) * (CRAFT_H + 4) + 6
end

local function BuildRoster(page)
	roster.page = page
	local scroll, child = UI.Scroll(page, UI.CONTENT_W, UI.CONTENT_H)
	scroll:SetPoint("TOPLEFT", 0, 0)
	roster.scroll, roster.child = scroll, child
	roster.cards = UI.Pool(child, CreateCharacterCard)
	roster.groupHeads = UI.Pool(child, function(parent) return T.Heading(parent, "", FULL_W) end)
	roster.unstartedH = T.Heading(child, L["Classes you haven't started"], FULL_W)
	roster.plans = UI.Pool(child, CreatePlanCard)
	-- 1.0: characters with the Ignore role stay hidden until this is clicked
	roster.ignored = T.TextButton(child, "", T.F.body)
	roster.ignored:SetScript("OnClick", function()
		db().ui.showIgnored = not db().ui.showIgnored
		UI:Refresh()
	end)
	-- 0.9: who covers which craft (crafting professions only: gathering earns no Legacy points)
	roster.cropsH = T.Heading(child, L["Crafts on the account"], FULL_W)
	roster.crafts = UI.Pool(child, function(parent)
		local c = CreateFrame("Frame", nil, parent)
		c:SetSize(150, CRAFT_H)
		c:EnableMouse(true)
		c.hover = T.Hover(c, 0.4)
		c.rule = T.Rule(c, "BORDER")
		c.rule:SetPoint("BOTTOMLEFT")
		c.rule:SetPoint("BOTTOMRIGHT")
		c.name = T.Text(c, T.F.name, C.head)
		c.name:SetPoint("TOPLEFT", 2, -4)
		c.name:SetPoint("RIGHT", -2, 0)
		c.name:SetWordWrap(false)
		c.who = T.Text(c, T.F.body, C.ink)
		c.who:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
		c.who:SetPoint("RIGHT", -56, 0)
		c.value = T.Text(c, T.F.body, C.ink2, "RIGHT")
		c.value:SetPoint("TOP", c.who, "TOP")
		c.value:SetPoint("RIGHT", -2, 0)
		c.who:SetWordWrap(false)
		c.bar = T.Bar(c, 100, 3)
		c.bar:SetPoint("TOPLEFT", c.who, "BOTTOMLEFT", 0, -4)
		c.bar:SetTicks({ 0.5, 0.75 })
		c.more = T.Text(c, T.F.small, C.muted)
		c.more:SetPoint("TOPLEFT", c.bar, "BOTTOMLEFT", 0, -4)
		c.more:SetPoint("RIGHT", -2, 0)
		c.more:SetWordWrap(false)
		c:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 16, 4) -- 1.1: at the mouse (the user)
			GameTooltip:SetText(self.craftName or "", T.unpack(C.ink))
			for _, h in ipairs(self.holders or {}) do GameTooltip:AddDoubleLine(h.name, h.skill, T.unpack(C.ink2)) end
			for _, token in ipairs(self.planned or {}) do
				GameTooltip:AddLine(string.format(L["Planned for %s"], Live.ClassName(token)), T.unpack(C.accent))
			end
			if #(self.holders or {}) == 0 then GameTooltip:AddLine(L["Nobody has it yet, so its challenges are still open."], T.unpack(C.warn), true) end
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return c
	end)
end

local function FillCard(card, entry)
	local ch, token = entry.real, entry.real.class
	local r, g, b = T.ClassColor(token)
	card.charKey, card.charName = entry.key, ch.name
	card:SetSelected(ns.Character and ns.Character:Shown() == entry.key or false)
	card.wash:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.22))
	local hasIcon = P.ClassIcon(card.icon, token)
	if hasIcon then card.icon:SetTexCoord(0, 1, 0, 1) else card.icon:SetTexture(nil) end
	card.mono:SetShown(not hasIcon)
	card.mono:SetText(Live.ClassName(token):sub(1, 1))
	card.mono:SetTextColor(r, g, b)
	card.name:SetText(ch.name)
	card.name:SetTextColor(r, g, b)
	local fallen = ch.ruleset == "hardcore" and db().status[entry.key] == "fallen"
	-- Normal is the default, so only Hardcore is named (0.9.1: "Undead Warlock, Nor..." didn't fit beside the level)
	card.sub:SetText(string.format(L["%s %s"], ch.race or "", Live.ClassName(token))
		.. (ch.ruleset == "hardcore" and (", " .. P.RulesetTag(ch.ruleset)) or "")
		.. (fallen and ("  " .. T.Hex(C.hc) .. L["Fallen"] .. "|r") or "")
		.. RoleTag(entry.key))
	local level = ch.level or 1
	card.level:SetText(level)
	card.levelBar:SetHeatValue(level / 60)
	card.levelNext:SetText(NextLevelGoal(level, token))
	local primary = {}
	for _, p in ipairs(ch.professions or {}) do
		if (p.slot or 9) <= 2 then primary[#primary + 1] = p end
	end
	for k, line in ipairs(card.profs) do
		local p = primary[k]
		line:SetShown(p ~= nil)
		if p then
			-- the rank is in "300 / 300" already (and in the character panel); the card keeps room for the tag
			local label = p.name
			if p.skillLine and Suggested(token, p.skillLine) then label = label .. " " .. T.Hex(C.muted) .. L["(suggested)"] .. "|r" end
			line.name:SetText(label)
			line.name:SetTextColor(T.unpack(p.craft and C.ink or C.ink2))
			line.value:SetText(string.format("%d / %d", p.skill or 0, p.max or 300))
			line.bar:SetHeatValue((p.skill or 0) / 300)
			local text, blocked = NextSkillGoal(p, level)
			line.next:SetText(text or L["Gathering: no Legacy points of its own"])
			line.next:SetTextColor(T.unpack(blocked and C.warn or C.muted))
		end
	end
	-- with one craft or none, say which crafts suit the class (leaving out the one it has)
	local suggested, have = {}, {}
	for _, p in ipairs(primary) do have[p.name] = true end
	for _, name in ipairs(P.SuggestedCrafts(token)) do if not have[name] then suggested[#suggested + 1] = name end end
	card.noProf:SetShown(#primary < 2 and #suggested > 0)
	card.noProf:ClearAllPoints()
	if #primary == 0 then card.noProf:SetPoint("TOPLEFT", 14, -(BANNER_H + 38)) else card.noProf:SetPoint("TOPLEFT", card.profs[1], "BOTTOMLEFT", 0, -6) end
	card.noProf:SetPoint("RIGHT", -14, 0)
	card.noProf:SetText((#primary == 0 and (L["No professions yet."] .. " ") or "")
		.. string.format(L["Suggested: %s"], table.concat(suggested, ", ")))
	local ranks = {}
	for id, r in pairs(ch.perks or {}) do ranks[tonumber(id) or id] = r end
	card.dead, card.deadTotal = P.DeadPerks(ranks, level)
	-- 1.1: points this character could still spend (same ruleset only: Hardcore and Normal earn apart)
	card.unspent = ns.Core:UnspentFor(entry.key)
	local perksText = card.deadTotal > 0
		and string.format(L["%d / %d perks spent, %d no longer help"], ch.spent or 0, Data.SPEND_CAP, card.deadTotal)
		or string.format(L["%d / %d perks spent"], ch.spent or 0, Data.SPEND_CAP)
	if card.unspent > 0 then perksText = perksText .. ", " .. T.Hex(C.goldHi) .. string.format(L["%d to spend"], card.unspent) .. "|r" end
	card.perks:SetText(perksText)
	card.perks:SetTextColor(T.unpack(card.deadTotal > 0 and C.warn or C.ink2))
	card.warnings = P.OutlevelWarnings(level)
	card.warn:SetText(card.warnings[1] and P.OutlevelText(card.warnings[1]) or "")
	local live = entry.key == Live.CharacterKey()
	card.seen:SetText(live and L["Playing now"] or (ch.seen and ch.seen > 0 and date("%Y-%m-%d", ch.seen) or ""))
end

local function FillPlan(card, token)
	local r, g, b = T.ClassColor(token)
	local intent = db().intent[token]
	local plan = ns.ClassPlan(token)
	card.intentClass = token
	card:SetSelected(ns.Character and ns.Character:PlanShown() == token or false)
	local hasIcon = P.ClassIcon(card.icon, token)
	card.icon:SetShown(hasIcon)
	card.icon:SetDesaturated(not intent)
	card.icon:SetAlpha(intent and 1 or 0.6)
	card.name:SetText(Live.ClassName(token))
	card.name:SetTextColor(r, g, b, intent and 1 or 0.8)
	card.tag:SetText(intent and P.RulesetTag(intent) or L["Not planned"])
	card.star:SetShown(plan and plan.next and true or false)
	-- what the plan says so far: race and crafts, else how many races can play it
	local bits = {}
	if plan and plan.race then bits[#bits + 1] = L[plan.race] end
	for _, craft in ipairs(Data.CRAFT_ORDER) do
		if plan and plan.profs and plan.profs[craft.id] then bits[#bits + 1] = L[craft.name] end
	end
	if #bits == 0 then
		local faction, n = ns.PlayerFaction(), 0
		for _, race in ipairs(Data.RACES[faction]) do if Data.RACE_CLASSES[faction][race][token] then n = n + 1 end end
		card.detail:SetText(n == 1 and L["1 race can play it"] or string.format(L["%d races can play it"], n))
	else
		card.detail:SetText(table.concat(bits, ", "))
	end
	card.suggest:SetText(string.format(L["Suggested: %s"], table.concat(P.SuggestedCrafts(token), ", ")))
end

-- How many cards fit across, and how wide each is, for the width left beside a docked panel.
local function Columns(width)
	local cols = math.max(1, math.floor((width + GAP) / (CARD_MIN_W + GAP)))
	return cols, math.floor((width - (cols - 1) * GAP) / cols)
end

local function RefreshRoster()
	roster.cards:Reset()
	roster.groupHeads:Reset()
	roster.plans:Reset()
	-- the docked panel takes the right side; the cards reflow into what's left
	local docked = ns.Character and ns.Character:Docked()
	local width = docked and (UI.CONTENT_W - DOCK_W - 14) or FULL_W
	roster.scroll:SetWidth(docked and (UI.CONTENT_W - DOCK_W) or UI.CONTENT_W)
	local cols, cardW = Columns(width)

	local groups, started, ignored = { normal = {}, hardcore = {} }, {}, 0
	for key, ch in pairs(ns.Core:Characters()) do
		started[ch.class] = true
		if P.Role(key) == "ignore" then ignored = ignored + 1 end
		if P.Role(key) ~= "ignore" or db().ui.showIgnored then
			local group = groups[ch.ruleset == "hardcore" and "hardcore" or "normal"]
			group[#group + 1] = { key = key, real = ch }
		end
	end
	local function compare(a, b)
		if (a.real.level or 0) ~= (b.real.level or 0) then return (a.real.level or 0) > (b.real.level or 0) end
		return (a.real.name or "") < (b.real.name or "")
	end
	local y = 0
	-- headings only when both rulesets are on the account; one kind needs no label
	local split = #groups.normal > 0 and #groups.hardcore > 0
	for _, ruleset in ipairs({ "normal", "hardcore" }) do
		local list = groups[ruleset]
		table.sort(list, compare)
		if split and #list > 0 then
			local h = roster.groupHeads:Acquire()
			h:SetWidth(width)
			h:SetPoint("TOPLEFT", roster.child, "TOPLEFT", 0, -y)
			h.text:SetText(ruleset == "hardcore" and L["Hardcore"] or L["Normal"])
			h.text:SetTextColor(T.unpack(ruleset == "hardcore" and C.hc or C.head))
			h.hint:SetText(#list == 1 and L["1 character"] or string.format(L["%d characters"], #list))
			y = y + 34
		end
		for i, entry in ipairs(list) do
			local card = roster.cards:Acquire()
			card:Layout(cardW)
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
			card:SetPoint("TOPLEFT", roster.child, "TOPLEFT", col * (cardW + GAP), -(y + row * (CARD_H + GAP)))
			FillCard(card, entry)
		end
		if #list > 0 then y = y + math.ceil(#list / cols) * (CARD_H + GAP) + 6 end
	end

	roster.ignored:SetShown(ignored > 0)
	if ignored > 0 then
		roster.ignored.Label:SetText(db().ui.showIgnored and L["Hide ignored characters"]
			or (ignored == 1 and L["Show 1 ignored character"] or string.format(L["Show %d ignored characters"], ignored)))
		roster.ignored:SetWidth(roster.ignored.Label:GetStringWidth() + 20)
		roster.ignored:ClearAllPoints()
		roster.ignored:SetPoint("TOPLEFT", roster.child, "TOPLEFT", -8, -y)
		y = y + 32
	end

	y = CraftCoverage(y, width)

	-- classes not started: "play it next" first, then the planned ones, then the rest, in the game's class order
	local unstarted = {}
	for _, token in ipairs(Data.CLASS_ORDER) do
		if not started[token] then unstarted[#unstarted + 1] = token end
	end
	local rank = {}
	for i, token in ipairs(unstarted) do
		local plan = ns.ClassPlan(token)
		rank[token] = ((plan and plan.next) and 0 or (db().intent[token] and 1 or 2)) * 100 + i
	end
	table.sort(unstarted, function(a, b) return rank[a] < rank[b] end)
	roster.unstartedH:SetShown(#unstarted > 0)
	roster.unstartedH:SetWidth(width)
	roster.unstartedH:ClearAllPoints()
	roster.unstartedH:SetPoint("TOPLEFT", roster.child, "TOPLEFT", 0, -(y + 6))
	roster.unstartedH.hint:SetText(L["Click one to plan it"])
	y = y + 42
	for i, token in ipairs(unstarted) do
		local card = roster.plans:Acquire()
		card:SetWidth(cardW)
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		card:SetPoint("TOPLEFT", roster.child, "TOPLEFT", col * (cardW + GAP), -(y + row * (PLAN_H + GAP)))
		FillPlan(card, token)
	end
	y = y + math.ceil(#unstarted / cols) * (PLAN_H + GAP)
	roster.scroll:SetContentHeight(y)
end

UI:RegisterPage("roster", L["Roster"], BuildRoster, RefreshRoster)
