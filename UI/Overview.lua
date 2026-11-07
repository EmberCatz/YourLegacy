-- Overview (0.9): the points in Blizzard's Legacy shield, the reward track (click a reward to preview it), four
-- figures, then "Closest to done" and "Sections" (a click opens that section's tab in Challenges).
-- Goal / Maybe / Skip is gone (research/17-v09-brief.md #8).
local _, ns = ...
local T, UI, Live, Data, L, P = ns.Theme, ns.UI, ns.Live, ns.Data, ns.L, ns.Pages
local C = T.C

local function db() return ns.Core.db end

local overview = {}
local W = UI.CONTENT_W
local TOP_H, GAP = 250, 12
local LEAD_W = 236                 -- the shield's column
local TRACK_X = LEAD_W + 28
local TRACK_W = W - 32 - TRACK_X
local LOWER_H = UI.CONTENT_H - TOP_H - GAP
local LEFT_W = math.floor((W - GAP) / 2)
local RIGHT_W = W - GAP - LEFT_W
-- UI-Legacy-Points-icon-c60 is 50x73 in the client. 0.9.1: drawn at 1.2x its own size and proportions (it was
-- blown up to 92x134 and looked smeared), with the number where Blizzard puts it (LegacyPointShield: 59% down).
local SHIELD_W, SHIELD_H = 60, 88

-- A figure in the ruled row: a label, the number, and (Next reward only) a note. A 1px rule on its left.
local function Figure(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 64)
	f.sep = f:CreateTexture(nil, "ARTWORK")
	f.sep:SetColorTexture(T.unpack(C.rule))
	f.sep:SetWidth(1)
	f.sep:SetPoint("TOPLEFT", 0, 0)
	f.sep:SetPoint("BOTTOMLEFT", 0, 0)
	f.label = T.Text(f, T.F.small, C.head)
	f.label:SetPoint("TOPLEFT", 14, 0)
	f.value = T.Text(f, T.F.big, C.ink)
	f.value:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -4)
	f.unit = T.Text(f, T.F.num, C.muted)
	f.unit:SetPoint("BOTTOMLEFT", f.value, "BOTTOMRIGHT", 3, 3)
	f.note = T.Text(f, T.F.small, C.muted)
	f.note:SetPoint("TOPLEFT", f.value, "BOTTOMLEFT", 0, -3)
	f.note:SetPoint("RIGHT", -8, 0)
	f.note:SetWordWrap(false)
	return f
end

local function RewardTooltip(self)
	local r = self.reward
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:SetText(r.name or "", T.unpack(C.ink))
	if not self.unlocked then
		GameTooltip:AddLine(string.format(L["Unlocks at %d Legacy points"], r.level), T.unpack(C.ink2))
	elseif r.owned == false then
		GameTooltip:AddLine(L["Unlocked. Collect it from Innkeeper Wiley in Ratchet."], T.unpack(C.warn))
	else
		GameTooltip:AddLine(L["Collected"], T.unpack(C.heat5))
	end
	if r.itemID then GameTooltip:AddLine(L["Click to preview it."], T.unpack(C.muted)) end
	GameTooltip:Show()
end

local function BuildOverview(page)
	local top = T.Panel(page, false, W, TOP_H)
	top:SetPoint("TOPLEFT")
	overview.top = top
	local body = top.body

	-- the points in Blizzard's Legacy shield (UI-Legacy-Points-icon), as the Legacy panel's progress track shows them
	overview.number = CreateFrame("Frame", nil, body)
	overview.number:SetSize(SHIELD_W, SHIELD_H)
	overview.number:SetPoint("TOP", body, "TOPLEFT", LEAD_W / 2, -8)
	overview.shield = overview.number:CreateTexture(nil, "ARTWORK")
	overview.shield:SetAllPoints()
	if not T.Atlas(overview.shield, "UI-Legacy-Points-icon-c60") then overview.shield:SetTexture(T.MEDIA .. "Logo") end
	overview.points = T.Text(overview.number, T.F.shield, C.ink, "CENTER")
	overview.points:SetPoint("CENTER", 0, -8)
	overview.ringLabel = T.Text(body, T.F.large, C.head, "CENTER")
	overview.ringLabel:SetPoint("TOP", overview.number, "BOTTOM", 0, -8)
	overview.ringLabel:SetText(L["Legacy points"])

	-- the reward track: the Legacy points bar (Blizzard's profession bar, T.ProgressBar), the count on it, the
	-- rewards along it
	overview.track = T.ProgressBar(body, TRACK_W)
	overview.track:SetPoint("TOPLEFT", body, "TOPLEFT", TRACK_X, -68)
	overview.of = overview.track.Text
	overview.nodes = UI.Pool(body, function(parent)
		local n = CreateFrame("Button", nil, parent)
		n:SetSize(36, 36)
		n.tile = T.Tile(n, 34)
		n.tile:SetPoint("CENTER")
		n.hl = T.Hover(n.tile, 0.7)
		n.pts = T.Text(n, T.F.num, C.ink2, "CENTER")
		n.pts:SetPoint("BOTTOM", n.tile, "TOP", 0, 4)
		n.name = T.Text(n, T.F.small, C.ink, "CENTER")
		n.name:SetPoint("TOP", n.tile, "BOTTOM", 0, -42) -- clear of the bar frame (29px)
		n.name:SetMaxLines(2)
		n.kind = T.Text(n, T.F.small, C.muted, "CENTER")
		n.kind:SetPoint("TOP", n.name, "BOTTOM", 0, -1)
		n:SetScript("OnEnter", RewardTooltip)
		n:SetScript("OnLeave", function() GameTooltip:Hide() end)
		n:SetScript("OnClick", function(self) Live.PreviewReward(self.reward.itemID, self) end)
		return n
	end)

	-- four figures in a ruled row along the bottom
	local figW = math.floor((W - 32) / 4)
	overview.figures = {}
	for i = 1, 4 do
		local f = Figure(body, figW)
		f:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", (i - 1) * figW, 0)
		if i == 1 then f.sep:Hide() f.label:SetPoint("TOPLEFT", 0, 0) end
		overview.figures[i] = f
	end
	-- the next reward's name may take two lines, then it's cut
	local nextFig = overview.figures[4]
	nextFig.value:SetFontObject(T.F.name)
	nextFig.value:SetWidth(figW - 24)
	nextFig.value:SetWordWrap(true)
	nextFig.value:SetMaxLines(2)
	nextFig.value:SetJustifyV("TOP")
	overview.figureRule = T.Rule(body)
	overview.figureRule:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 72)
	overview.figureRule:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 72)

	-- Closest to done
	local close = T.Panel(page, L["Closest to done"], LEFT_W, LOWER_H)
	close:SetPoint("TOPLEFT", 0, -(TOP_H + GAP))
	overview.close = close
	overview.empty = T.Text(close.body, T.F.body, C.muted)
	overview.empty:SetPoint("TOPLEFT", 0, -4)
	overview.empty:SetWidth(LEFT_W - 32)
	overview.empty:SetText(L["Nothing under way yet. Your next level-up or profession skill point starts this list."])
	overview.rows = UI.Pool(close.body, function(parent) return P.CreateChallengeRow(parent, LEFT_W - 32, false) end)

	-- Sections: one row each; a click opens the section's tab in Challenges
	local sections = T.Panel(page, L["Sections"], RIGHT_W, LOWER_H)
	sections:SetPoint("TOPRIGHT", 0, -(TOP_H + GAP))
	overview.sections = sections
	overview.sectionRows = UI.Pool(sections.body, function(parent)
		local r = CreateFrame("Button", nil, parent)
		r:SetSize(RIGHT_W - 32, 36)
		T.RowBackground(r)
		r.tile = T.Tile(r, 24)
		r.tile:SetPoint("LEFT", 2, 0)
		r.title = T.Text(r, T.F.name, C.ink)
		r.title:SetPoint("TOPLEFT", r.tile, "TOPRIGHT", 10, 1)
		r.bar = T.Bar(r, RIGHT_W - 32 - 160, 3)
		r.bar:SetPoint("BOTTOMLEFT", r.tile, "BOTTOMRIGHT", 10, 2)
		r.value = T.Text(r, T.F.body, C.ink2, "RIGHT")
		r.value:SetPoint("RIGHT", -26, 0)
		r.chev = T.Tex(r, "Chevron", "ARTWORK", C.muted)
		r.chev:SetSize(12, 12)
		r.chev:SetPoint("RIGHT", -6, 0)
		r.chev:SetRotation(math.rad(90))
		r:SetScript("OnClick", function(self) UI:ShowSection(self.section) end)
		r:SetScript("OnEnter", function(self)
			self.chev:SetVertexColor(T.unpack(C.head))
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.section, T.unpack(C.ink))
			GameTooltip:AddLine(L["Click to open it in Challenges."], T.unpack(C.muted))
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function(self)
			self.chev:SetVertexColor(T.unpack(C.muted))
			GameTooltip:Hide()
		end)
		return r
	end)
end

local function RefreshOverview()
	local challenges = Live.Challenges()
	local earned, max = Live.Earned(), Live.MaxAvailable()
	local total = math.max(max, challenges.total)
	local hardcore = Live.IsHardcore()
	db().pools[hardcore and "hardcore" or "normal"] = earned

	overview.points:SetText(earned)
	overview.of:SetText(string.format("%d / %d", earned, total))

	-- track: filled to the points earned
	local scaleMax = math.max(60, total)
	overview.track:SetValue(earned / scaleMax)
	overview.nodes:Reset()
	local rewards = Live.Rewards()
	local nextReward, toCollect = nil, 0
	for i, r in ipairs(rewards) do
		local got = earned >= r.level
		if not got then nextReward = nextReward or r elseif r.owned == false then toCollect = toCollect + 1 end
		local n = overview.nodes:Acquire()
		n.reward, n.unlocked = r, got
		local x = overview.track:At(r.level / scaleMax)
		-- above the bar, so the count on it stays readable; the name goes under the bar
		n:SetPoint("BOTTOM", overview.track, "TOPLEFT", x, 6)
		local room = 120
		for _, j in ipairs({ i - 1, i + 1 }) do
			if rewards[j] then room = math.min(room, math.abs(overview.track:At(rewards[j].level / scaleMax) - x) - 8) end
		end
		n.name:SetWidth(math.max(60, room))
		local uncollected = got and r.owned == false
		n.tile:SetIcon(r.icon or ("glyph:" .. r.glyph))
		n.tile:SetState(uncollected and C.accent or (got and C.heat6 or C.rule), not got)
		n.pts:SetText(r.level)
		n.pts:SetTextColor(T.unpack(got and C.ink or C.muted))
		n.name:SetText(r.name)
		n.name:SetTextColor(T.unpack(got and C.ink or C.ink2))
		n.kind:SetText(r.kind and L[r.kind] or "")
	end

	-- figures: labels and numbers only
	local f1, f2, f3, f4 = unpack(overview.figures)
	f1.label:SetText(L["Normal pool"])
	f1.value:SetText(db().pools.normal or "–")
	f1.value:SetTextColor(T.unpack(db().pools.normal and C.ink or C.muted))
	f2.label:SetText(L["Hardcore pool"])
	f2.value:SetText(db().pools.hardcore or "–")
	f2.value:SetTextColor(T.unpack(db().pools.hardcore and C.hc or C.muted))
	f3.label:SetText(L["Usable per character"])
	f3.value:SetText(math.min(Data.SPEND_CAP, earned))
	f3.unit:SetText("/" .. Data.SPEND_CAP)
	f4.label:SetText(L["Next reward"])
	if nextReward then
		f4.value:SetText(nextReward.name)
		local togo = nextReward.level - earned
		f4.note:SetText(toCollect > 0 and string.format(L["%d waiting at Innkeeper Wiley"], toCollect)
			or (togo == 1 and L["1 point to go"] or string.format(L["%d points to go"], togo)))
	else
		f4.value:SetText(L["Every reward unlocked"])
		f4.note:SetText(toCollect > 0 and string.format(L["%d waiting at Innkeeper Wiley"], toCollect) or L["All collected."])
	end
	f4.note:SetTextColor(T.unpack(toCollect > 0 and C.warn or C.muted))

	-- Closest to done
	local open = {}
	for _, g in ipairs(challenges.groups) do
		for _, item in ipairs(g.items) do
			if not item.completed and item.ratio > 0 then open[#open + 1] = item end
		end
	end
	-- 0.9: brackets a character is about to outlevel go first, with that character named (Data.OUTLEVEL_WARNING)
	local warned = {}
	for _, ch in pairs(db().characters) do
		for _, w in ipairs(P.OutlevelWarnings(ch.level or 1)) do
			warned[w.item.id] = warned[w.item.id] or string.format(L["%s: %d left before level %d"], ch.name or "?", w.missing, w.max)
		end
	end
	for id in pairs(warned) do
		local listed = false
		for _, item in ipairs(open) do listed = listed or item.id == id end
		if not listed then
			for _, g in ipairs(challenges.groups) do
				for _, item in ipairs(g.items) do if item.id == id then open[#open + 1] = item end end
			end
		end
	end
	table.sort(open, function(a, b)
		if (warned[a.id] ~= nil) ~= (warned[b.id] ~= nil) then return warned[a.id] ~= nil end
		if a.ratio ~= b.ratio then return a.ratio > b.ratio end
		return a.id < b.id
	end)
	overview.rows:Reset()
	overview.empty:SetShown(#open == 0)
	overview.close.hint:SetText(#open > 0 and string.format(L["%d under way"], #open) or "")
	for i = 1, math.min(5, #open) do
		local r = overview.rows:Acquire()
		r:SetPoint("TOPLEFT", 0, -(i - 1) * 38)
		r:SetItem(open[i])
		if warned[open[i].id] then
			r.gate:SetText(warned[open[i].id])
			r.line:Hide()
		end
	end

	-- Sections
	overview.sectionRows:Reset()
	for i, g in ipairs(challenges.groups) do
		local r = overview.sectionRows:Acquire()
		r:SetPoint("TOPLEFT", 0, -(i - 1) * 36)
		r.section = g.title
		local ratio = g.total > 0 and g.done / g.total or 0
		r.tile:SetIcon(g.items[1] and g.items[1].icon or "glyph:Star")
		r.tile:SetState(ratio >= 1 and C.heat6 or C.rule, g.done == 0)
		r.title:SetText(g.title)
		r.value:SetText(string.format("%d / %d", g.done, g.total))
		r.bar:SetHeatValue(ratio)
	end
end

UI:RegisterPage("overview", L["Overview"], BuildOverview, RefreshOverview)
