-- Drawers over the right side of the ledger window (inside it, so they never run off a small screen):
-- * the character panel: one character's gear, gold, professions and general info and, on Hardcore, alive /
--   fallen. The character you're playing is read live; others show their last logout (Live.Snapshot).
--   0.9.1: no bags any more (the user: overkill for the addon).
-- * the class planner (0.6): for a class you haven't started, the ruleset, race and crafts you mean to play it
--   with, and what that's worth in Legacy points.
-- Both close when the window switches to another page.
local _, ns = ...
local T, UI, Live, Data, L = ns.Theme, ns.UI, ns.Live, ns.Data, ns.L
local C = T.C

local Character = {}
ns.Character = Character

local function db() return ns.Core.db end

local W = 404
local TILE, GAP = 32, 3
-- Paper-doll order, the way the game's character frame lays it out.
local SLOTS_LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }   -- head, neck, shoulder, back, chest, shirt, tabard, wrist
local SLOTS_RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 } -- hands, waist, legs, feet, two rings, two trinkets
local SLOTS_WEAPONS = { 16, 17, 18 }                -- main hand, off hand, ranged
local QUALITY = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000", [6] = "e6cc80", [7] = "00ccff" }
-- The drawer's ground is the Legacy leather at its own proportions (cropped at the sides, not stretched), so the
-- line painted under its header band lands where the art puts it: 56 of its 510px, under the 21px title strip.
-- The banner between strip and line holds the icon, the name and the level; the body starts under the line.
local GROUND_TOP, LINE_AT = 21, 56
local BANNER_MID = GROUND_TOP + LINE_AT / 2 + 1

local function QualityColour(q)
	local hex = QUALITY[q or 1] or "ffffff"
	return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1 }
end

local function Coins(copper)
	copper = math.floor(copper or 0)
	return string.format("%d%sg|r %d%ss|r %d%sc|r", math.floor(copper / 10000), T.Hex(C.heat5), math.floor(copper / 100) % 100, T.Hex(C.muted),
		copper % 100, T.Hex(C.heat3))
end

-- "Journeyman" for a skill cap of 150, and the next rank's cap.
local function ProfRank(max)
	local name, nextCap
	for _, r in ipairs(Data.PROF_RANKS) do
		if (max or 0) >= r[1] then name = r[2] elseif not nextCap then nextCap = r[1] end
	end
	return name, nextCap
end
ns.ProfRank = ProfRank

-- The shared drawer shell (0.9): docked on the right of the page in the window's own metal frame
-- (ButtonFrameTemplateNoPortrait, the bronze Forever draws for its windows), the title in the class colour in the
-- frame's top strip, Blizzard's close button. The Roster reflows its cards into the space beside it.
-- 0.9.1: it starts under the window's header line, like the pages, and is as tall as they are.
local function Drawer()
	local main = UI.frame
	local f = CreateFrame("Frame", nil, main)
	f:SetSize(W, UI.CONTENT_H)
	f:SetPoint("TOPRIGHT", main, "TOPRIGHT", -14, -UI.PAGE_TOP)
	f:SetFrameLevel(main:GetFrameLevel() + 30) -- before its children: a child's level is fixed when it's made
	T.Fill(f, "BACKGROUND", C.paper, nil, -8) -- opaque
	local ground = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	ground:SetPoint("TOPLEFT", 2, -GROUND_TOP)
	ground:SetPoint("BOTTOMRIGHT", -2, 2)
	if not T.AtlasCrop(ground, "Legacy-Challenge-BG", W - 4, UI.CONTENT_H - GROUND_TOP - 2, "TOP") then ground:Hide() end
	f.border = T.NineSlice(f, "ButtonFrameTemplateNoPortrait", 20)
	f:EnableMouse(true)
	f:Hide()
	-- the title strip of the metal frame, as the main window's
	f.band = CreateFrame("Frame", nil, f.border)
	f.band:SetPoint("TOPLEFT", 0, 0)
	f.band:SetPoint("TOPRIGHT", 0, 0)
	f.band:SetHeight(22)
	f.title = T.Text(f.band, T.F.brand, C.head, "CENTER")
	f.title:SetPoint("TOP", 0, -4)
	f.title:SetPoint("LEFT", 40, 0)
	f.title:SetPoint("RIGHT", -40, 0)
	local close = CreateFrame("Button", nil, f.border, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function()
		f:Hide()
		UI:Refresh()
	end)
	-- the banner: the class icon in the Legacy icon frame, who, and the level, between the strip and the line
	f.banner = CreateFrame("Frame", nil, f)
	f.banner:SetPoint("TOPLEFT", 14, -(GROUND_TOP + 2))
	f.banner:SetPoint("TOPRIGHT", -14, -(GROUND_TOP + 2))
	f.banner:SetHeight(LINE_AT - 6)
	f.tile = T.IconFrame(f.banner, 34)
	f.tile:SetPoint("LEFT", f, "TOPLEFT", 18, -BANNER_MID)
	f.who = T.Text(f.banner, T.F.name, C.text)
	f.who:SetPoint("BOTTOMLEFT", f.tile, "RIGHT", 14, 1)
	f.who:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -64, -BANNER_MID + 1)
	f.who:SetWordWrap(false)
	f.level = T.Text(f.banner, T.F.big, C.ink, "RIGHT")
	f.level:SetPoint("RIGHT", f, "TOPRIGHT", -18, -BANNER_MID)
	f.body = CreateFrame("Frame", nil, f)
	f.body:SetPoint("TOPLEFT", 14, -(GROUND_TOP + LINE_AT + 10))
	f.body:SetPoint("BOTTOMRIGHT", -14, 12)
	-- quiet, right on the body's first line: how old a snapshot is (nothing for the character you're playing)
	f.hint = T.Text(f.body, T.F.small, C.muted, "RIGHT")
	f.hint:SetPoint("TOPRIGHT", 0, 0)
	function f:SetClassColour(r, g, b)
		self.title:SetTextColor(r, g, b)
	end
	return f
end

local function Open(f)
	local wasShown = f:IsShown()
	f:Show()
	if not wasShown then T.Reveal(f, 0.2, 0.97, 0, "RIGHT") end
end

---------------------------------------------------------------- character panel
-- An item slot: tile with the item's icon, quality border, stack count, and the game's item tooltip on hover.
local function ItemTile(parent)
	local t = T.Tile(parent, TILE)
	t:EnableMouse(true)
	t.count = T.Text(t, T.F.small, C.white, "RIGHT")
	t.count:SetPoint("BOTTOMRIGHT", -3, 3)
	t.hl = T.Fill(t, "HIGHLIGHT", C.ink, 0.12)
	t:SetScript("OnEnter", function(self)
		if not self.link then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function() GameTooltip:Hide() end)
	function t:SetItem(it)
		self.link = it and it.link
		if it then
			self:SetIcon(it.icon or "glyph:Star", C.parch)
			local q = QualityColour(it.quality)
			self:SetState(q)
			self.icon:Show()
		else
			self.icon:Hide()
			self:SetState(C.rule, true)
		end
		self.count:SetText(it and (it.count or 1) > 1 and it.count or "")
	end
	return t
end

local function InfoRow(parent, width)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(width, 18)
	r.label = T.Text(r, T.F.small, C.muted)
	r.label:SetPoint("LEFT")
	r.value = T.Text(r, T.F.body, C.text, "RIGHT")
	r.value:SetPoint("RIGHT")
	r.value:SetPoint("LEFT", r.label, "RIGHT", 8, 0)
	r.value:SetWordWrap(false)
	return r
end

local function BuildCharacter()
	local f = Drawer()
	local body = f.body

	-- who (in the banner): race and class, ruleset and status, the level; then the XP bar
	f.tag = T.Text(f.banner, T.F.small, C.ink2)
	f.tag:SetPoint("TOPLEFT", f.tile, "RIGHT", 14, -3)
	f.status = T.TextButton(f.banner, "", T.F.small)
	f.status:SetHeight(18)
	f.status:SetPoint("LEFT", f.tag, "RIGHT", 4, 0)
	f.status:SetScript("OnClick", function()
		local key = f.key
		db().status[key] = db().status[key] ~= "fallen" and "fallen" or nil
		UI:Refresh()
		Character:Refresh()
	end)
	local innerW = W - 28
	f.xpLabel = T.Text(body, T.F.small, C.muted)
	f.xpLabel:SetPoint("TOPLEFT", 0, 0)
	f.xp = T.Bar(body, innerW, 4, C.heat4)
	f.xp:SetPoint("TOPLEFT", 0, -16)
	f.rested = f.xp:CreateTexture(nil, "ARTWORK", nil, 1)
	f.rested:SetColorTexture(T.unpack(C.heat2, 0.9))
	f.rested:SetPoint("TOPLEFT", f.xp, "TOPLEFT")
	f.rested:SetPoint("BOTTOMLEFT", f.xp, "BOTTOMLEFT")

	-- paper doll: gear down both sides, info and professions in the middle, weapons below
	local top = -32
	f.slots = {}
	for i, slot in ipairs(SLOTS_LEFT) do
		local t = ItemTile(body)
		t:SetPoint("TOPLEFT", 0, top - (i - 1) * (TILE + GAP))
		f.slots[slot] = t
	end
	for i, slot in ipairs(SLOTS_RIGHT) do
		local t = ItemTile(body)
		t:SetPoint("TOPRIGHT", 0, top - (i - 1) * (TILE + GAP))
		f.slots[slot] = t
	end
	local dollH = #SLOTS_LEFT * (TILE + GAP)
	for i, slot in ipairs(SLOTS_WEAPONS) do
		local t = ItemTile(body)
		t:SetPoint("TOP", body, "TOPLEFT", innerW / 2 + (i - 2) * (TILE + GAP * 2), top - dollH - 2)
		f.slots[slot] = t
	end
	local midX, midW = TILE + 14, innerW - 2 * (TILE + 14)
	f.info = {}
	local keys = { "gold", "zone", "guild", "itemLevel", "spent" }
	for i, k in ipairs(keys) do
		local r = InfoRow(body, midW)
		r:SetPoint("TOPLEFT", midX, top - 2 - (i - 1) * 18)
		f.info[k] = r
	end
	f.info.gold.label:SetText(L["Gold"])
	f.info.zone.label:SetText(L["Zone"])
	f.info.guild.label:SetText(L["Guild"])
	f.info.itemLevel.label:SetText(L["Item level"])
	f.info.spent.label:SetText(L["Legacy points spent"])
	-- 1.0: what the character is for (Data.ROLES), shown on its card; Ignore hides the card on the Roster
	f.role = InfoRow(body, midW)
	f.role:SetHeight(26)
	f.role:SetPoint("TOPLEFT", midX, top - 2 - #keys * 18 - 6)
	f.role.label:SetText(L["Role"])
	f.role.value:Hide()
	f.roleDrop = T.Dropdown(f.role, 112, function()
		local out = {}
		for _, r in ipairs(Data.ROLES) do out[#out + 1] = { r.key, L[r.name], desc = L[r.desc] } end
		return out
	end, function(key)
		db().roles[f.key] = key ~= "alt" and key or nil
		UI:Refresh()
		Character:Refresh()
	end)
	f.roleDrop:SetPoint("RIGHT", f.role, "RIGHT", -8, 0)

	-- professions: name, rank, a bar with the 75/150/225 rank ticks
	local profTop = top - 2 - #keys * 18 - 12 - 32
	f.profHead = T.Text(body, T.F.label, C.muted)
	f.profHead:SetPoint("TOPLEFT", midX, profTop)
	f.profHead:SetText(L["Professions"])
	f.profs = {}
	for i = 1, 5 do
		local p = CreateFrame("Frame", nil, body)
		p:SetSize(midW, 26)
		p:SetPoint("TOPLEFT", midX, profTop - 16 - (i - 1) * 25)
		p.name = T.Text(p, T.F.small, C.text)
		p.name:SetPoint("TOPLEFT")
		p.value = T.Text(p, T.F.small, C.ink2, "RIGHT")
		p.value:SetPoint("TOPRIGHT", 0, 1)
		p.bar = T.Bar(p, midW, 3)
		p.bar:SetPoint("TOPLEFT", 0, -16)
		p.bar:SetTicks({ 0.25, 0.5, 0.75 })
		f.profs[i] = p
	end
	f.profEmpty = T.Text(body, T.F.small, C.muted)
	f.profEmpty:SetPoint("TOPLEFT", f.profHead, "BOTTOMLEFT", 0, -6)
	f.profEmpty:SetWidth(midW)
	f.profEmpty:SetText(L["No professions yet. Trainers in every capital teach them."])

	return f
end

-- The class icon on a framed portrait, or the shield glyph in the class colour where the client has none.
local function SetClassIcon(frame, token)
	local r, g, b = T.ClassColor(token)
	if ns.ClassIcon(frame.icon, token) then
		frame.icon:SetTexCoord(0, 1, 0, 1)
		frame.icon:SetVertexColor(1, 1, 1, 1)
	else
		frame.icon:SetTexture(T.Path("GlyphShield"))
		frame.icon:SetVertexColor(r, g, b, 1)
	end
end

-- The character's data: live for the one you're playing, the stored snapshot for the rest.
local function DataFor(key)
	if key == Live.CharacterKey() then return Live.DemoCharacter(Live.Snapshot()), true end
	return ns.Core:Characters()[key], false
end

local function RefreshCharacter(f)
	local ch, live = DataFor(f.key)
	if not ch then f:Hide() return end
	local r, g, b = T.ClassColor(ch.class)
	f.title:SetText(ch.name or "")
	f:SetClassColour(r, g, b)
	f.hint:SetText(live and "" or (ch.seen and ch.seen > 0 and string.format(L["As of %s"], date("%Y-%m-%d", ch.seen)) or L["As of last logout"]))
	SetClassIcon(f.tile, ch.class)
	f.who:SetText(string.format(L["%s %s"], ch.race or "", Live.ClassName(ch.class)))
	f.level:SetText(ch.level or 1)
	f.tag:SetText(ns.RulesetTag(ch.ruleset))
	local hardcore = ch.ruleset == "hardcore"
	local fallen = hardcore and db().status[f.key] == "fallen"
	f.status:SetShown(hardcore)
	f.status.Label:SetText(fallen and L["Fallen"] or L["Alive"])
	f.status:SetWidth(f.status.Label:GetStringWidth() + 20)
	f.status.Label:SetTextColor(T.unpack(fallen and C.hc or C.ink))

	local xp, xpMax = ch.xp or 0, ch.xpMax or 0
	local maxLevel = (ch.level or 1) >= 60
	f.xpLabel:SetText(maxLevel and L["Maximum level"] or (xpMax > 0 and string.format(L["Level %d: %d / %d XP, %d rested"], ch.level or 1, xp, xpMax, ch.rested or 0) or L["Experience unknown"]))
	f.xp:SetValue(maxLevel and 1 or (xpMax > 0 and xp / xpMax or 0))
	local restRatio = (not maxLevel and xpMax > 0) and math.min(1, (xp + (ch.rested or 0)) / xpMax) or 0
	f.rested:SetWidth(math.max(0.01, f.xp.width * restRatio))
	f.rested:SetShown(restRatio > 0)

	for slot, tile in pairs(f.slots) do
		local gear = ch.gear or {}
		tile:SetItem(gear[slot] or gear[tostring(slot)])
	end
	f.info.gold.value:SetText(Coins(ch.money))
	f.info.zone.value:SetText(ch.zone ~= "" and ch.zone or "–")
	f.info.guild.value:SetText(ch.guild or "–")
	f.info.itemLevel.value:SetText(ch.itemLevel and string.format("%.1f", ch.itemLevel) or "–")
	f.info.spent.value:SetText(string.format("%d / %d", ch.spent or 0, Data.SPEND_CAP))
	f.roleDrop:SetValue(ns.Pages.Role(f.key))

	local profs = ch.professions or {}
	for i, row in ipairs(f.profs) do
		local p = profs[i]
		row:SetShown(p ~= nil)
		if p then
			local rank = ProfRank(p.max)
			row.name:SetText(rank and string.format(L["%s, %s"], p.name, L[rank]) or p.name)
			row.name:SetTextColor(T.unpack(p.craft and C.ink or C.ink2))
			row.value:SetText(string.format("%d / %d", p.skill or 0, p.max or 300))
			row.bar:SetHeatValue((p.skill or 0) / 300)
		end
	end
	f.profEmpty:SetShown(#profs == 0)

end

---------------------------------------------------------------- class planner
-- What the Legacy grid shows for a class: its three challenges, and who on the account holds each craft.
local function ClassChallenges(token)
	local name, out = Live.ClassName(token), {}
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			if item.sub == name then out[#out + 1] = item end
		end
	end
	return out
end

local function CraftHolders()
	local holders = {}
	for _, ch in pairs(ns.Core:Characters()) do
		for _, p in ipairs(ch.professions or {}) do
			if p.skillLine and Data.CRAFTS[p.skillLine] then
				local list = holders[p.skillLine] or {}
				list[#list + 1] = { name = ch.name, skill = p.skill or 0, class = ch.class }
				holders[p.skillLine] = list
			end
		end
	end
	return holders
end

local function ClassPlan(token)
	local plan = db().classPlans[token]
	if type(plan) ~= "table" then plan = {} db().classPlans[token] = plan end
	plan.profs = type(plan.profs) == "table" and plan.profs or {}
	return plan
end
ns.ClassPlan = function(token) return type(db().classPlans[token]) == "table" and db().classPlans[token] or nil end

local function PlayerFaction()
	local f = Live.try(UnitFactionGroup, "player")
	return (f == "Alliance" or f == "Horde") and f or "Horde"
end
ns.PlayerFaction = PlayerFaction

local function BuildPlanner()
	local f = Drawer()
	local body = f.body
	local innerW = W - 28
	f.level:Hide() -- a class not started has no level
	f.who:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -18, -BANNER_MID + 1)
	f.worth = T.Text(f.banner, T.F.small, C.muted)
	f.worth:SetPoint("TOPLEFT", f.tile, "RIGHT", 14, -3)
	f.worth:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -BANNER_MID - 3)
	f.worth:SetWordWrap(false)

	-- the class's three challenges, as the grid shows them
	f.milestones = {}
	for i = 1, 3 do
		local m = CreateFrame("Frame", nil, body)
		m:SetSize((innerW - 16) / 3, 44)
		m:SetPoint("TOPLEFT", (i - 1) * ((innerW - 16) / 3 + 8), -14)
		-- the class's three milestones as figures in a ruled row, no boxes
		if i > 1 then
			local sep = m:CreateTexture(nil, "ARTWORK")
			sep:SetColorTexture(T.unpack(C.rule))
			sep:SetWidth(1)
			sep:SetPoint("TOPLEFT", -4, 0)
			sep:SetPoint("BOTTOMLEFT", -4, 0)
		end
		m.num = T.Text(m, T.F.big, C.muted, "CENTER")
		m.num:SetPoint("CENTER", 0, 4)
		m.label = T.Text(m, T.F.small, C.muted, "CENTER")
		m.label:SetPoint("BOTTOM", 0, 4)
		f.milestones[i] = m
	end

	local y = -72
	local function Label(text, yy)
		local h = T.Heading(body, text, innerW)
		h:SetPoint("TOPLEFT", 0, yy)
		return h
	end
	f.rulesetH = Label(L["Ruleset"], y)
	f.ruleset = T.Segmented(body, { { "", L["Not planned"] }, { "normal", L["Normal"] }, { "hardcore", L["Hardcore"] } }, function(v)
		db().intent[f.token] = v ~= "" and v or nil
		UI:Refresh()
	end, 24)
	f.ruleset:SetPoint("TOPLEFT", 0, y - 32)
	f.next = T.Checkbox(body, L["Play it next"], function(v)
		ClassPlan(f.token).next = v or nil
		UI:Refresh()
	end)
	f.next:SetPoint("LEFT", f.ruleset, "RIGHT", 16, 0)

	y = y - 70
	f.raceH = Label(L["Race"], y)
	f.races = UI.Pool(body, function(parent)
		local b = T.TextButton(parent, "", T.F.body)
		b:SetScript("OnClick", function(self)
			local plan = ClassPlan(f.token)
			plan.race = plan.race ~= self.race and self.race or nil
			UI:Refresh()
		end)
		b:SetScript("OnEnter", function(self)
			if not self.active then self.Label:SetTextColor(T.unpack(C.ink)) end
		end)
		return b
	end)
	f.raceY = y - 32

	y = y - 70
	f.craftH = Label(L["Crafts"], y)
	f.craftH.hint:SetText(L["Pick up to two"])
	f.crafts = {}
	for i, craft in ipairs(Data.CRAFT_ORDER) do
		local row = CreateFrame("Button", nil, body)
		row:SetSize(innerW, 26)
		row:SetPoint("TOPLEFT", 0, y - 30 - (i - 1) * 28)
		T.RowBackground(row)
		row.box = T.Tex(row, "Box", "ARTWORK", C.muted)
		row.box:SetSize(14, 14)
		row.box:SetPoint("LEFT", 8, 0)
		row.tick = T.Tex(row, "Check", "OVERLAY", C.accent)
		row.tick:SetSize(14, 14)
		row.tick:SetPoint("CENTER", row.box, "CENTER", 1, 1)
		row.name = T.Text(row, T.F.body, C.text)
		row.name:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
		row.name:SetText(L[craft.name])
		row.who = T.Text(row, T.F.small, C.muted, "RIGHT")
		row.who:SetPoint("RIGHT", -8, 0)
		row.id, row.craft = craft.id, craft.name
		row:SetScript("OnClick", function(self)
			local plan = ClassPlan(f.token)
			if plan.profs[self.id] then
				plan.profs[self.id] = nil
			else
				local n = 0
				for _ in pairs(plan.profs) do n = n + 1 end
				if n >= 2 then return end -- two primary professions per character
				plan.profs[self.id] = true
			end
			UI:Refresh()
		end)
		f.crafts[i] = row
	end
	f.summary = T.Text(body, T.F.body, C.ink)
	f.summary:SetPoint("BOTTOMLEFT", 0, 4)
	f.summary:SetWidth(innerW)
	return f
end

local function RefreshPlanner(f)
	local token = f.token
	local r, g, b = T.ClassColor(token)
	local name = Live.ClassName(token)
	f.title:SetText(name)
	f:SetClassColour(r, g, b)
	f.hint:SetText(L["Not started yet"])
	SetClassIcon(f.tile, token)
	local plan = ns.ClassPlan(token) or { profs = {} }
	local intent = db().intent[token]
	f.who:SetText(plan.race and string.format(L["%s %s"], L[plan.race], name) or name)

	-- milestones
	local items, open = ClassChallenges(token), 0
	for i, m in ipairs(f.milestones) do
		local item = items[i]
		m:SetShown(item ~= nil)
		if item then
			local target = (item.description or ""):match("%d+") or Data.LEVEL_MILESTONES[i]
			m.num:SetText(target)
			m.num:SetTextColor(T.unpack(item.completed and C.heat6 or C.ink))
			m.label:SetText(item.completed and L["Done"] or ((item.name or ""):match("^(%S+)") or ""))
			if not item.completed then open = open + 1 end
		end
	end
	f.worth:SetText(open == 1 and L["1 class challenge still open on the account."]
		or string.format(L["%d class challenges still open on the account."], open))

	f.ruleset:SetValue(intent or "")
	f.next:SetChecked(plan.next and true or false)

	-- races of the player's faction that can be this class
	f.races:Reset()
	local faction = PlayerFaction()
	local prev
	for _, race in ipairs(Data.RACES[faction]) do
		if Data.RACE_CLASSES[faction][race][token] then
			local btn = f.races:Acquire()
			btn.race = race
			btn.Label:SetText(L[race])
			btn:SetWidth(btn.Label:GetStringWidth() + 20)
			if prev then btn:SetPoint("LEFT", prev, "RIGHT", 2, 0) else btn:SetPoint("TOPLEFT", f.body, "TOPLEFT", 0, f.raceY) end
			btn:SetActive(plan.race == race)
			prev = btn
		end
	end
	f.raceH.hint:SetText(faction == "Alliance" and L["Alliance"] or L["Horde"])

	-- crafts: who already has each one; an uncovered craft is worth three more points
	local holders, newPoints = CraftHolders(), 0
	for _, row in ipairs(f.crafts) do
		local on = plan.profs[row.id] and true or false
		row.tick:SetShown(on)
		local list = holders[row.id]
		if list then
			table.sort(list, function(a, b2) return a.skill > b2.skill end)
			row.who:SetText(string.format(L["%s has it (%d)"], list[1].name, list[1].skill))
			row.who:SetTextColor(T.unpack(C.muted))
		else
			row.who:SetText(L["Nobody has it yet: 3 points"])
			row.who:SetTextColor(T.unpack(C.warn))
			if on then newPoints = newPoints + 3 end
		end
		row.name:SetTextColor(T.unpack(on and C.ink or C.ink2))
		local suggested = Data.SUGGESTED_CRAFTS[token] and Data.SUGGESTED_CRAFTS[token][row.id]
		row.name:SetText(L[row.craft] .. (suggested and (" " .. T.Hex(C.head) .. L["(suggested)"] .. "|r") or ""))
	end
	local total = open + newPoints
	f.summary:SetText(intent and string.format(L["Playing it this way is worth up to %d Legacy points."], total)
		or L["Pick a ruleset to put this class on your plan."])
	f.summary:SetTextColor(T.unpack(intent and C.ink or C.muted))
end

---------------------------------------------------------------- public
function Character:Refresh()
	if self.frame and self.frame:IsShown() and self.frame.key then RefreshCharacter(self.frame) end
	if self.planner and self.planner:IsShown() and self.planner.token then RefreshPlanner(self.planner) end
end

-- Clicking the same character again closes the panel; another character switches it.
-- Opening, switching or closing a panel refreshes the page too: the Roster reflows its cards around it.
function Character:Toggle(key)
	self.frame = self.frame or BuildCharacter()
	local f = self.frame
	if self.planner then self.planner:Hide() end
	if f:IsShown() and f.key == key then
		f:Hide()
	else
		f.key = key
		Open(f)
	end
	UI:Refresh()
end

function Character:TogglePlan(token)
	self.planner = self.planner or BuildPlanner()
	local f = self.planner
	if self.frame then self.frame:Hide() end
	if f:IsShown() and f.token == token then
		f:Hide()
	else
		f.token = token
		Open(f)
	end
	UI:Refresh()
end

function Character:Close()
	if self.frame then self.frame:Hide() end
	if self.planner then self.planner:Hide() end
end

function Character:Shown() return self.frame and self.frame:IsShown() and self.frame.key end
function Character:PlanShown() return self.planner and self.planner:IsShown() and self.planner.token end
function Character:Docked() return (self:Shown() or self:PlanShown()) and true or false end
