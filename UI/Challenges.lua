-- Challenges (0.9): a tab per section instead of one long scroll, so a new section from Blizzard is a new tab,
-- not more scrolling. The first tab is an overview: every section as a card in its basic form. Grid-shaped sections
-- (Classes, Tradeskills) show as a grid; the rest as rows. 0.9.1: the search is gone (the user's ask); a footer
-- along the bottom holds the filters and the Legacy points on Blizzard's profession bar.
local _, ns = ...
local T, UI, Live, Data, L, P = ns.Theme, ns.UI, ns.Live, ns.Data, ns.L, ns.Pages
local C = T.C

local function db() return ns.Core.db end

local chal = {}
local FILTERS = { { "open", L["Open"] }, { "progress", L["In progress"] }, { "done", L["Done"] }, { "all", L["All"] } }
local W = UI.CONTENT_W
local TABS_Y, TAB_H = 0, 30
local LIST_Y = TABS_Y - TAB_H - 8
local FOOT_H = 38 -- the footer: filters left, the points bar right
local POINTS_W = 280

-- 1.0: how rows sort inside a section. Rows keep their subgroup (the headers stay put); grids keep their shape.
local SORTS = { { "game", L["Game order"] }, { "closest", L["Closest to done"] }, { "points", L["Most points"] }, { "name", L["Name"] } }
local function SortRows(list, mode)
	if not mode or mode == "game" then return end
	local subRank, pos = {}, {}
	for i, item in ipairs(list) do
		pos[item] = i
		subRank[item.sub or ""] = subRank[item.sub or ""] or i
	end
	local function closeness(item) return item.completed and -1 or (item.ratio or 0) end
	table.sort(list, function(a, b)
		local sa, sb = subRank[a.sub or ""], subRank[b.sub or ""]
		if sa ~= sb then return sa < sb end
		if mode == "closest" and closeness(a) ~= closeness(b) then return closeness(a) > closeness(b) end
		if mode == "points" and (a.points or 0) ~= (b.points or 0) then return (a.points or 0) > (b.points or 0) end
		if mode == "name" and a.name ~= b.name then return ns.Lower(a.name or "") < ns.Lower(b.name or "") end
		return pos[a] < pos[b]
	end)
end

local function Matches(item, status)
	if status == "open" and item.completed then return false end
	if status == "progress" and (item.completed or item.ratio == 0) then return false end
	if status == "done" and not item.completed then return false end
	return true
end

---------------------------------------------------------------- grid shape
-- A section is grid-shaped when it has 3+ subgroups that each hold the same number (2+) of challenges:
-- Classes (class × 25/45/60) and Tradeskills (craft × 150/225/300) on the live client. Decided by shape,
-- never by name, so it holds on every client language and when Blizzard adds rows.
local GRID_LABEL_W, GRID_GAP, GRID_MAX_COLS = 220, 0, 4
local PANEL_PAD, BAND_H = 16, 50 -- content inset inside a section panel, title head height incl. gap

local function GridShape(g)
	local subs, bySub = {}, {}
	for _, item in ipairs(g.items) do
		if not item.sub or item.sub == g.title then return nil end
		if not bySub[item.sub] then
			bySub[item.sub] = {}
			subs[#subs + 1] = item.sub
		end
		local list = bySub[item.sub]
		list[#list + 1] = item
	end
	if #subs < 3 then return nil end
	local cols = #bySub[subs[1]]
	if cols < 2 or cols > GRID_MAX_COLS then return nil end
	for _, sub in ipairs(subs) do
		if #bySub[sub] ~= cols then return nil end
	end
	return { subs = subs, bySub = bySub, cols = cols }
end

-- Column labels from what the rows share: the first word of the name ("Novice", "Journeyman") when every row
-- agrees on it, plus the first number of the description (25, 150) when every row agrees on that.
local function GridColumnLabels(shape)
	local labels = {}
	for c = 1, shape.cols do
		local word, num
		for i, sub in ipairs(shape.subs) do
			local item = shape.bySub[sub][c]
			local w = (item.name or ""):match("^(%S+)%s")
			local n = (item.description or ""):match("%d+")
			if i == 1 then word, num = w, n else
				if w ~= word then word = nil end
				if n ~= num then num = nil end
			end
		end
		labels[c] = word or (num and ("" .. num)) or ""
	end
	return labels
end

local function SubColor(sub)
	for _, token in ipairs(Data.CLASS_ORDER) do
		if Live.ClassName(token) == sub then return { T.ClassColor(token) } end
	end
	return C.text
end

local function GridCellWidth(innerW, cols) return (innerW - GRID_LABEL_W - (cols - 1) * GRID_GAP) / cols end

-- One flash when a challenge turns done while the ledger is open: the cell's fill warms and fades.
local function Flash(parent)
	local fill = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
	fill:SetColorTexture(T.unpack(C.heat5))
	fill:SetAllPoints()
	fill:SetAlpha(0)
	local group = fill:CreateAnimationGroup()
	local up = group:CreateAnimation("Alpha")
	up:SetFromAlpha(0)
	up:SetToAlpha(0.35)
	up:SetDuration(T.DUR_SHORT)
	local down = group:CreateAnimation("Alpha")
	down:SetFromAlpha(0.35)
	down:SetToAlpha(0)
	down:SetDuration(0.9)
	down:SetStartDelay(T.DUR_SHORT)
	return group
end

-- A grid cell as a table cell: the milestone's target figure, its state beside it, and a 3px heat bar along the
-- bottom while it's under way. Done: the checkmark, figure in ink, the date. Not started: the figure muted.
local CELL_H = 44
local function CreateGridCell(parent)
	local cell = CreateFrame("Button", nil, parent)
	cell.hover = T.Hover(cell, 0.5)
	cell.num = T.Text(cell, T.F.mid, C.muted, "LEFT")
	cell.num:SetPoint("LEFT", 10, 2)
	cell.check = cell:CreateTexture(nil, "OVERLAY")
	if not T.Atlas(cell.check, "worldquest-tracker-checkmark") then cell.check:SetTexture(T.Path("Check")) end
	cell.check:SetSize(16, 14)
	cell.check:SetPoint("LEFT", cell.num, "RIGHT", 6, 0)
	cell.sub = T.Text(cell, T.F.small, C.ink2, "RIGHT")
	cell.sub:SetPoint("RIGHT", -10, 2)
	cell.gate = T.Text(cell, T.F.small, C.warn, "RIGHT")
	cell.gate:SetPoint("RIGHT", -10, 2)
	cell.bar = T.Bar(cell, 10, 3)
	cell.bar:SetPoint("BOTTOMLEFT", 10, 6)
	cell.flash = Flash(cell)
	cell:SetScript("OnEnter", function(self) if self.item then P.ShowChallengeTooltip(self, self.item) end end)
	cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
	cell:SetScript("OnClick", P.ClickChallenge)
	cell.tracked = P.TrackedMark(cell)
	function cell:Layout(width)
		self:SetSize(width, CELL_H)
		self.width = width
		self.bar.width = width - 20
		self.bar:SetWidth(width - 20)
	end
	function cell:SetItem(item, matches)
		self.item = item
		self.tracked:SetShown(Live.Tracked()[item.id] or false)
		self:SetAlpha(matches and 1 or 0.35)
		local entry = db().earnedLog[item.id]
		self.num:SetText((item.description or ""):match("%d+") or "")
		local gate = not item.completed and item.gate and string.format(L["needs level %d"], item.gate) or ""
		self.gate:SetText(gate)
		if item.completed then
			local hc = entry and entry.ruleset == "hardcore"
			self.num:SetTextColor(T.unpack(C.ink))
			self.check:Show()
			self.check:SetVertexColor(T.unpack(hc and C.hc or C.ink))
			self.sub:SetText((hc and L["Hardcore"] .. "  " or "") .. (item.date or (entry and entry.date) or L["Done"]))
			self.sub:SetTextColor(T.unpack(hc and C.hc or C.muted))
			self.bar:Hide()
		else
			local started = (item.ratio or 0) > 0
			self.check:Hide()
			self.num:SetTextColor(T.unpack(started and C.ink or C.muted, started and 1 or 0.6))
			self.sub:SetText(gate == "" and started and (item.detail or "") or "")
			self.sub:SetTextColor(T.unpack(C.ink2))
			self.bar:SetShown(started)
			if started then self.bar:SetHeatValue(item.ratio) end
		end
	end
	return cell
end

local function CreateGridRow(parent, innerW)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(innerW, CELL_H)
	r.rule = T.Rule(r, "BORDER")
	r.rule:SetPoint("BOTTOMLEFT", 0, 0)
	r.rule:SetPoint("BOTTOMRIGHT", 0, 0)
	r.tile = T.Tile(r, 28)
	r.tile:SetPoint("LEFT", 0, 0)
	r.label = T.Text(r, T.F.name, C.ink)
	r.label:SetPoint("TOPLEFT", r.tile, "TOPRIGHT", 10, 0)
	r.label:SetWidth(GRID_LABEL_W - 50)
	r.label:SetWordWrap(false)
	r.sub = T.Text(r, T.F.small, C.muted)
	r.sub:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -2)
	r.sub:SetWidth(GRID_LABEL_W - 50)
	r.sub:SetWordWrap(false)
	r.cells = {}
	function r:SetRow(sub, items, matched, cols, flashes)
		self.label:SetText(sub)
		self.label:SetTextColor(T.unpack(SubColor(sub)))
		self.tile:SetIcon(items[1].icon or "glyph:Shield")
		local allDone, who, started = true, nil, false
		for _, item in ipairs(items) do
			allDone = allDone and item.completed
			who = who or (not item.completed and item.who)
			started = started or item.completed or (item.ratio or 0) > 0
		end
		self.tile:SetState(allDone and C.heat6 or C.rule, not started)
		local done = 0
		for _, item in ipairs(items) do if item.completed then done = done + 1 end end
		self.sub:SetText(allDone and L["All done"] or (who and string.format(L["Best: %s"], who))
			or (done > 0 and string.format(L["%d of %d done"], done, #items)) or (started and L["In progress"] or ""))
		local w = GridCellWidth(innerW, cols)
		for c = 1, GRID_MAX_COLS do
			local cell = self.cells[c]
			if c <= cols then
				if not cell then -- grows once per pooled row, never per refresh
					cell = CreateGridCell(self)
					self.cells[c] = cell
				end
				cell:Layout(w)
				cell:ClearAllPoints()
				cell:SetPoint("LEFT", self, "LEFT", GRID_LABEL_W + (c - 1) * (w + GRID_GAP), 0)
				cell:SetItem(items[c], matched[items[c]])
				cell:Show()
				if flashes[items[c].id] then cell.flash:Play() end
			elseif cell then
				cell:Hide()
			end
		end
	end
	return r
end

---------------------------------------------------------------- overview tab: the front page
-- Every section as a card in its basic form, in three columns (each card goes to the shortest column, in order).
-- Grid sections: one line per class or craft with a small cell per milestone. Others: the challenges' icons.
-- A card's title opens its tab; a cell or icon behaves as everywhere else (tooltip, click, Shift-click).
local BOARD_COLS, BOARD_GAP = 3, 12
local BOARD_W = W - 14
local CARD_W = math.floor((BOARD_W - (BOARD_COLS - 1) * BOARD_GAP) / BOARD_COLS)
local CARD_INNER = CARD_W - 28
local PIP_H, PIP_GAP, MINI_LABEL_W = 20, 4, 128 -- room for "Leatherworking"
local ICON, ICON_GAP = 32, 6

local function CreatePip(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(PIP_H)
	b.fill = T.Fill(b, "BACKGROUND", C.paper)
	T.Border(b, C.rule)
	b.hl = T.Hover(b, 0.7)
	b.num = T.Text(b, T.F.small, C.muted, "CENTER")
	b.num:SetPoint("CENTER", 0, 1)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetPoint("BOTTOMLEFT", 1, 1)
	b.bar:SetHeight(2)
	-- 1.1: done = the dark cell, a gold number, Blizzard's checkmark and a full gold line (was a solid yellow block
	-- with black text, which the user called amateurish)
	b.check = b:CreateTexture(nil, "OVERLAY")
	b.check:SetSize(11, 10)
	b.check:SetPoint("RIGHT", -3, 1)
	if not T.Atlas(b.check, "worldquest-tracker-checkmark") then b.check:SetTexture(T.Path("Check")) end
	b.check:Hide()
	b:SetScript("OnEnter", function(self) P.ShowChallengeTooltip(self, self.item) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", P.ClickChallenge)
	function b:SetItem(item)
		self.item = item
		local ratio = item.completed and 1 or (item.ratio or 0)
		self.num:SetText((item.description or ""):match("%d+") or "")
		self.check:SetShown(item.completed and true or false)
		if item.completed then
			self.fill:SetColorTexture(T.unpack(C.paper))
			self.num:SetTextColor(T.unpack(C.goldHi))
			self.bar:Show()
			self.bar:SetColorTexture(T.unpack(C.heat6))
			self.bar:SetWidth(math.max(2, self:GetWidth() - 2))
		else
			self.fill:SetColorTexture(T.unpack(C.paper))
			self.num:SetTextColor(T.unpack(ratio > 0 and C.ink or C.muted))
			self.bar:SetShown(ratio > 0)
			self.bar:SetColorTexture(T.unpack(T.Heat(ratio)))
			self.bar:SetWidth(math.max(2, (self:GetWidth() - 2) * ratio))
		end
	end
	return b
end

local function CreateIcon(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(ICON, ICON + 5)
	b.tile = T.Tile(b, ICON)
	b.tile:SetPoint("TOP")
	b.hl = T.Hover(b.tile, 0.7)
	b.check = b:CreateTexture(nil, "OVERLAY")
	b.check:SetSize(16, 14)
	b.check:SetPoint("BOTTOMRIGHT", b.tile, "BOTTOMRIGHT", 3, -3)
	if not T.Atlas(b.check, "worldquest-tracker-checkmark") then b.check:SetTexture(T.Path("Check")) end
	b.bar = T.Bar(b, ICON, 3)
	b.bar:SetPoint("BOTTOMLEFT")
	b:SetScript("OnEnter", function(self) P.ShowChallengeTooltip(self, self.item) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", P.ClickChallenge)
	function b:SetItem(item)
		self.item = item
		local started = item.completed or (item.ratio or 0) > 0
		self.tile:SetIcon(item.icon or "glyph:Star")
		self.tile:SetState(item.completed and C.heat6 or C.rule, not started)
		self.check:SetShown(item.completed and true or false)
		self.bar:SetShown(not item.completed and (item.ratio or 0) > 0)
		if not item.completed then self.bar:SetHeatValue(item.ratio or 0) end
	end
	return b
end

local function BuildBoard(parent)
	local scroll, child = UI.Scroll(parent, W, UI.CONTENT_H + LIST_Y - FOOT_H)
	scroll:SetPoint("TOPLEFT", 0, LIST_Y)
	chal.board = { scroll = scroll, child = child }
	local base = child:GetFrameLevel()
	chal.board.cards = UI.Pool(child, function(p)
		local card = T.Panel(p, "", CARD_W, 100)
		card:SetFrameLevel(base + 1)
		card.open = CreateFrame("Button", nil, card)
		card.open:SetAllPoints(card.band)
		card.open.hl = T.Hover(card.open, 0.4)
		card.chev = T.Tex(card.open, "Chevron", "ARTWORK", C.muted)
		card.chev:SetSize(12, 12)
		card.chev:SetRotation(math.rad(90))
		card.chev:SetPoint("RIGHT", -10, 0)
		card.hint:ClearAllPoints()
		card.hint:SetPoint("RIGHT", card.chev, "LEFT", -8, 0)
		card.bar = T.Bar(card, CARD_INNER, 2)
		card.bar:SetPoint("TOPLEFT", card.band, "BOTTOMLEFT", 14, -1)
		card.open:SetScript("OnClick", function() UI:ShowSection(card.section) end)
		card.open:SetScript("OnEnter", function(self)
			card.chev:SetVertexColor(T.unpack(C.head))
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(card.section, T.unpack(C.ink))
			GameTooltip:AddLine(L["Click to open this section."], T.unpack(C.muted))
			GameTooltip:Show()
		end)
		card.open:SetScript("OnLeave", function()
			card.chev:SetVertexColor(T.unpack(C.muted))
			GameTooltip:Hide()
		end)
		return card
	end)
	local function Above(f) f:SetFrameLevel(base + 4) return f end
	chal.board.lines = UI.Pool(child, function(p)
		local r = Above(CreateFrame("Frame", nil, p))
		r:SetSize(CARD_INNER, PIP_H)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(16, 16)
		r.icon:SetPoint("LEFT", 0, 0)
		r.label = T.Text(r, T.F.body, C.ink)
		r.label:SetPoint("LEFT", 22, 0)
		r.label:SetWidth(MINI_LABEL_W - 26)
		r.label:SetWordWrap(false)
		r.pips = {}
		return r
	end)
	chal.board.icons = UI.Pool(child, function(p) return Above(CreateIcon(p)) end)
end

local function RefreshBoard(data)
	local b = chal.board
	b.cards:Reset()
	b.lines:Reset()
	b.icons:Reset()
	local heights = {}
	for c = 1, BOARD_COLS do heights[c] = 0 end
	for _, g in ipairs(data.groups) do
		local shape = GridShape(g)
		-- the card's height from its content
		local bodyH
		if shape then
			bodyH = #shape.subs * (PIP_H + PIP_GAP)
		else
			local perRow = math.max(1, math.floor((CARD_INNER + ICON_GAP) / (ICON + ICON_GAP)))
			bodyH = math.ceil(#g.items / perRow) * (ICON + 5 + ICON_GAP)
		end
		local h = 44 + 10 + bodyH + 8
		local col = 1
		for c = 2, BOARD_COLS do if heights[c] < heights[col] then col = c end end
		local x, y = (col - 1) * (CARD_W + BOARD_GAP), heights[col]
		heights[col] = y + h + BOARD_GAP
		local card = b.cards:Acquire()
		card:SetPoint("TOPLEFT", b.child, "TOPLEFT", x, -y)
		card:SetHeight(h)
		card.section = g.title
		card.title:SetText(g.title)
		card.hint:SetText(string.format("%d / %d", g.done, g.total))
		-- 1.1 (the user: the blue line under the titles): the section's share in gold, softer while under way
		local share = g.total > 0 and g.done / g.total or 0
		card.bar:SetValue(share)
		card.bar:SetColor(share >= 1 and C.heat6 or { C.heat6[1], C.heat6[2], C.heat6[3], 0.55 })
		local cx, cy = x + 14, y + 44 + 10
		if shape then
			local pipW = math.floor((CARD_INNER - MINI_LABEL_W - (shape.cols - 1) * PIP_GAP) / shape.cols)
			for i, sub in ipairs(shape.subs) do
				local line = b.lines:Acquire()
				line:SetPoint("TOPLEFT", b.child, "TOPLEFT", cx, -(cy + (i - 1) * (PIP_H + PIP_GAP)))
				local items = shape.bySub[sub]
				line.label:SetText(sub)
				line.label:SetTextColor(T.unpack(SubColor(sub)))
				line.icon:SetTexture(items[1].icon)
				for c = 1, GRID_MAX_COLS do
					local pip = line.pips[c]
					if c <= shape.cols then
						if not pip then
							pip = CreatePip(line)
							line.pips[c] = pip
						end
						pip:SetWidth(pipW)
						pip:ClearAllPoints()
						pip:SetPoint("LEFT", line, "LEFT", MINI_LABEL_W + (c - 1) * (pipW + PIP_GAP), 0)
						pip:SetItem(items[c])
						pip:Show()
					elseif pip then
						pip:Hide()
					end
				end
			end
		else
			local perRow = math.max(1, math.floor((CARD_INNER + ICON_GAP) / (ICON + ICON_GAP)))
			for i, item in ipairs(g.items) do
				local ic = b.icons:Acquire()
				local col2, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
				ic:SetPoint("TOPLEFT", b.child, "TOPLEFT", cx + col2 * (ICON + ICON_GAP), -(cy + row * (ICON + 5 + ICON_GAP)))
				ic:SetItem(item)
			end
		end
	end
	local tallest = 0
	for c = 1, BOARD_COLS do tallest = math.max(tallest, heights[c]) end
	b.scroll:SetContentHeight(tallest)
end

---------------------------------------------------------------- tabs
-- Text tabs in a strip along the top: the selected one gold with the accent marker under it. A tab carries its
-- section's count. When the tabs outgrow one line they wrap onto a second.
local function BuildTabs(page)
	chal.tabs = UI.Pool(page, function(parent)
		local b = T.BoxTab(parent, "")
		b:SetHeight(TAB_H)
		b.count = T.Text(b, T.F.small, C.muted, "LEFT")
		b.Label:ClearAllPoints()
		b.Label:SetPoint("LEFT", 12, 0)
		b.count:SetPoint("LEFT", b.Label, "RIGHT", 6, 0)
		b:SetScript("OnClick", function(self) UI:ShowSection(self.section) end)
		return b
	end)
	chal.tabRule = T.Rule(page)
end

local function RefreshTabs(data)
	chal.tabs:Reset()
	local list = { { section = "", label = L["Overview"] } }
	for _, g in ipairs(data.groups) do list[#list + 1] = { section = g.title, label = g.title, count = string.format("%d/%d", g.done, g.total) } end
	local x, y = 0, TABS_Y
	local current = db().ui.section or ""
	for _, def in ipairs(list) do
		local b = chal.tabs:Acquire()
		b.section = def.section
		b.Label:SetText(def.label)
		b.count:SetText(def.count or "")
		local w = b.Label:GetStringWidth() + (def.count and (b.count:GetStringWidth() + 6) or 0) + 24
		b:SetWidth(w)
		if x + w > W and x > 0 then x, y = 0, y - TAB_H end
		b:SetPoint("TOPLEFT", chal.page, "TOPLEFT", x, y)
		b:SetActive(def.section == current)
		x = x + w + 2
	end
	chal.tabRule:ClearAllPoints()
	chal.tabRule:SetPoint("TOPLEFT", chal.page, "TOPLEFT", 0, y - TAB_H)
	chal.tabRule:SetPoint("TOPRIGHT", chal.page, "TOPRIGHT", 0, y - TAB_H)
	return y - TAB_H - 8 -- where the content starts
end

---------------------------------------------------------------- page
local function BuildChallenges(page)
	chal.page = page
	-- the footer: a rule, the filters on the left (section tabs only) with how many show, and the account's Legacy
	-- points on the right on the profession bar, the gold label first
	local foot = CreateFrame("Frame", nil, page)
	foot:SetPoint("BOTTOMLEFT", 0, 0)
	foot:SetPoint("BOTTOMRIGHT", 0, 0)
	foot:SetHeight(FOOT_H)
	foot.rule = T.Rule(foot)
	foot.rule:SetPoint("TOPLEFT", 0, 0)
	foot.rule:SetPoint("TOPRIGHT", 0, 0)
	chal.foot = foot
	chal.chips = {}
	local prev
	for _, f in ipairs(FILTERS) do
		local chip = T.TextButton(foot, f[2], T.F.bodyL)
		if prev then chip:SetPoint("LEFT", prev, "RIGHT", 2, 0) else chip:SetPoint("LEFT", foot, "LEFT", 0, -2) end
		chip:SetScript("OnClick", function()
			db().ui.status = f[1]
			UI:Refresh()
		end)
		chal.chips[f[1]] = chip
		prev = chip
	end
	chal.count = T.Text(foot, T.F.body, C.muted, "LEFT")
	chal.count:SetPoint("LEFT", prev, "RIGHT", 16, 0)
	chal.points = T.ProgressBar(foot, POINTS_W)
	chal.points:SetPoint("RIGHT", foot, "RIGHT", -4, -2)
	chal.pointsLabel = T.Text(foot, T.F.name, C.head, "RIGHT")
	chal.pointsLabel:SetPoint("RIGHT", chal.points, "LEFT", -12, 0)
	chal.pointsLabel:SetText(L["Legacy points"])
	chal.sort = T.Dropdown(foot, 130, function()
		local out = {}
		for _, s in ipairs(SORTS) do out[#out + 1] = { s[1], s[2] } end
		return out
	end, function(key)
		db().ui.sort = key
		UI:Refresh()
	end)
	chal.sort:SetPoint("RIGHT", chal.pointsLabel, "LEFT", -28, 0)
	chal.sortLabel = T.Text(foot, T.F.body, C.muted, "RIGHT")
	chal.sortLabel:SetPoint("RIGHT", chal.sort, "LEFT", -14, 0)
	chal.sortLabel:SetText(L["Sort"])
	BuildTabs(page)

	local scroll, child = UI.Scroll(page, W, UI.CONTENT_H + LIST_Y - FOOT_H)
	scroll:SetPoint("TOPLEFT", 0, LIST_Y)
	chal.scroll, chal.child = scroll, child
	local rowW = W - 14
	local innerW = rowW - 2 * PANEL_PAD
	chal.rowW, chal.innerW = rowW, innerW
	local base = child:GetFrameLevel()

	-- the section's panel
	chal.panels = UI.Pool(child, function(parent)
		local p = T.Panel(parent, "", rowW, 100)
		p:SetFrameLevel(base + 1)
		return p
	end)
	local function Above(f) f:SetFrameLevel(base + 4) return f end
	chal.subs = UI.Pool(child, function(parent)
		local s = Above(CreateFrame("Frame", nil, parent))
		s:SetSize(innerW, 20)
		s.text = T.Text(s, T.F.body, C.head)
		s.text:SetPoint("BOTTOMLEFT", 2, 2)
		return s
	end)
	chal.rows = UI.Pool(child, function(parent)
		local r = Above(P.CreateChallengeRow(parent, innerW, true))
		-- multi-step challenges (dungeon tiers, raids, Explorer) unfold into their checklist on click
		r.onExpand = function(item)
			chal.expanded[item.id] = not chal.expanded[item.id] or nil
			UI:Refresh()
		end
		return r
	end)
	chal.checks = UI.Pool(child, function(parent)
		local c = Above(CreateFrame("Frame", nil, parent))
		c:SetSize(math.floor(innerW / 3) - 8, 18)
		c.mark = T.Tex(c, "Check", "ARTWORK", C.heat6)
		c.mark:SetSize(12, 12)
		c.mark:SetPoint("LEFT", 2, 0)
		c.text = T.Text(c, T.F.small, C.parch)
		c.text:SetPoint("LEFT", 18, 0)
		c.text:SetPoint("RIGHT", -2, 0)
		c.text:SetWordWrap(false)
		return c
	end)
	chal.gridHeads = UI.Pool(child, function(parent)
		local f = Above(CreateFrame("Frame", nil, parent))
		f:SetSize(innerW, 24)
		f.labels = {}
		f.rule = T.Rule(f)
		f.rule:SetPoint("BOTTOMLEFT")
		f.rule:SetPoint("BOTTOMRIGHT")
		return f
	end)
	chal.gridRows = UI.Pool(child, function(parent) return Above(CreateGridRow(parent, innerW)) end)
	chal.empty = T.Text(child, T.F.body, C.muted)
	chal.empty:SetPoint("TOPLEFT", 4, -8)
	chal.empty:SetWidth(rowW - 8)
	chal.expanded = {}
	BuildBoard(page)
end

-- Checklist under an expanded row: the challenge's own criteria from the game, three columns.
local function LayCriteria(item, x, y)
	local list = Live.Criteria(item.id)
	local colW = math.floor(chal.innerW / 3)
	for i, crit in ipairs(list) do
		local c = chal.checks:Acquire()
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		c:SetPoint("TOPLEFT", chal.child, "TOPLEFT", x + 38 + col * colW, -(y + row * 19))
		c.mark:SetTexture(T.Path(crit.done and "Check" or "Box"))
		c.mark:SetVertexColor(T.unpack(crit.done and C.heat6 or C.muted))
		c.text:SetText(crit.text)
		c.text:SetTextColor(T.unpack(crit.done and C.text or C.muted))
	end
	return math.ceil(#list / 3) * 19 + 6
end

-- One section's challenges inside its panel, from y; returns the new y.
local function LaySection(g, list, matched, flashes, y)
	local x = PANEL_PAD
	local shape = GridShape(g) -- table-shaped sections (Classes, Tradeskills) always show as a grid
	local p = chal.panels:Acquire()
	p:SetPoint("TOPLEFT", chal.child, "TOPLEFT", 0, -y)
	p.title:SetText(g.title)
	p.hint:SetText(string.format(L["%d of %d points"], g.done, g.total))
	local top = y
	y = y + BAND_H
	if shape then
		-- Grid: one row per subgroup that has a match; cells that don't match the filter are dimmed.
		local labels = GridColumnLabels(shape)
		local head = chal.gridHeads:Acquire()
		head:SetPoint("TOPLEFT", chal.child, "TOPLEFT", x, -y)
		local w = GridCellWidth(chal.innerW, shape.cols)
		for c = 1, GRID_MAX_COLS do
			local fs = head.labels[c]
			if c <= shape.cols then
				if not fs then
					fs = T.Text(head, T.F.label, C.head, "LEFT")
					head.labels[c] = fs
				end
				fs:ClearAllPoints()
				fs:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", GRID_LABEL_W + (c - 1) * (w + GRID_GAP) + 10, 4)
				fs:SetText(labels[c])
				fs:Show()
			elseif fs then
				fs:Hide()
			end
		end
		y = y + 24
		for _, sub in ipairs(shape.subs) do
			local items, any = shape.bySub[sub], false
			for _, item in ipairs(items) do any = any or matched[item] or false end
			if any then
				local r = chal.gridRows:Acquire()
				r:SetPoint("TOPLEFT", chal.child, "TOPLEFT", x, -y)
				r:SetRow(sub, items, matched, shape.cols, flashes)
				y = y + CELL_H
			end
		end
	else
		local lastSub
		for _, item in ipairs(list) do
			if item.sub ~= lastSub and item.sub ~= g.title then
				local s = chal.subs:Acquire()
				s:SetPoint("TOPLEFT", chal.child, "TOPLEFT", x, -y)
				s.text:SetText(item.sub)
				y = y + 22
			end
			lastSub = item.sub
			local r = chal.rows:Acquire()
			r:SetPoint("TOPLEFT", chal.child, "TOPLEFT", x, -y)
			r:SetItem(item)
			y = y + 38
			if chal.expanded[item.id] then y = y + LayCriteria(item, x, y) end
		end
	end
	y = y + 8
	p:SetHeight(y - top)
	return y + 12
end

local function RefreshChallenges()
	local data = Live.Challenges()
	local status = db().ui.status or "open"
	for key, chip in pairs(chal.chips) do chip:SetActive(key == status) end
	-- a section that's gone (another client language, a renamed section) falls back to the overview tab
	local section = db().ui.section or ""
	local found = section == ""
	for _, g in ipairs(data.groups) do found = found or g.title == section end
	if not found then section, db().ui.section = "", "" end
	local contentY = RefreshTabs(data)
	local listH = UI.CONTENT_H + contentY - FOOT_H - 4
	chal.scroll:ClearAllPoints()
	chal.scroll:SetPoint("TOPLEFT", chal.page, "TOPLEFT", 0, contentY)
	chal.scroll:SetHeight(listH)
	chal.board.scroll:ClearAllPoints()
	chal.board.scroll:SetPoint("TOPLEFT", chal.page, "TOPLEFT", 0, contentY)
	chal.board.scroll:SetHeight(listH)
	-- the account's points, on every tab
	local earned, total = Live.Earned(), math.max(Live.MaxAvailable(), data.total)
	chal.points.Text:SetText(string.format("%d / %d", earned, total))
	chal.points:SetValue(total > 0 and earned / total or 0)

	chal.panels:Reset()
	chal.subs:Reset()
	chal.rows:Reset()
	chal.checks:Reset()
	chal.gridHeads:Reset()
	chal.gridRows:Reset()

	-- challenges that turned done since the last refresh flash once (none on the first refresh)
	local flashes, firstRun = {}, chal.seenDone == nil
	chal.seenDone = chal.seenDone or {}
	for _, g in ipairs(data.groups) do
		for _, item in ipairs(g.items) do
			if item.completed and not chal.seenDone[item.id] then
				if not firstRun then flashes[item.id] = true end
				chal.seenDone[item.id] = true
			end
		end
	end

	local board = section == ""
	chal.board.scroll:SetShown(board)
	chal.scroll:SetShown(not board)
	for _, chip in pairs(chal.chips) do chip:SetShown(not board) end
	chal.count:SetShown(not board)
	-- the sort only applies to row sections; a grid keeps its class × milestone shape
	local rows = false
	for _, g in ipairs(data.groups) do if g.title == section then rows = not GridShape(g) end end
	chal.sort:SetShown(rows)
	chal.sortLabel:SetShown(rows)
	local sort = db().ui.sort or "game"
	chal.sort:SetValue(sort)
	if board then
		RefreshBoard(data)
		return
	end

	local y, shown, total = 0, 0, 0
	for _, g in ipairs(data.groups) do
		if g.title == section then
			local list, matched = {}, {}
			for _, item in ipairs(g.items) do
				total = total + 1
				if Matches(item, status) then
					list[#list + 1] = item
					matched[item] = true
				end
			end
			SortRows(list, sort)
			if #list > 0 then
				y = LaySection(g, list, matched, flashes, y)
				shown = shown + #list
			end
		end
	end
	chal.empty:SetShown(shown == 0)
	chal.empty:SetText(status == "open" and L["Every challenge in this section is done."] or L["Nothing here yet."])
	chal.count:SetText(string.format(L["%d of %d shown"], shown, total))
	chal.scroll:SetContentHeight(y)
end

UI:RegisterPage("challenges", L["Challenges"], BuildChallenges, RefreshChallenges)

-- Opens Challenges on a section's tab ("" = the overview tab). Used by the Overview's section rows and the cards.
function UI:ShowSection(section)
	ns.Core.db.ui.section = section or ""
	if chal.scroll then chal.scroll:SetVerticalScroll(0) end
	self:Show("challenges")
	if chal.scroll then T.Reveal(chal.board.scroll:IsShown() and chal.board.scroll or chal.scroll, T.DUR_MICRO) end
end
