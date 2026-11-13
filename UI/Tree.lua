-- Legacy Tree planner: a plan per character, edited on the game's real tree. Left-click adds a planned rank,
-- right-click removes one. The 16-point cap, each perk's max rank, the "points in this tree" gates and the arrows
-- (a perk needs the one pointing at it at max rank) all hold, read from C_Traits. Presets, saved builds and "Use
-- current ranks" replace the plan. Current ranks come live for the character you're playing, else from the logout
-- snapshot. Nodes snap to the game's own grid (900 units per step), as in Blizzard's panel; the "Unknown" nodes
-- are slots Blizzard reserved for future perks, drawn as empty sockets.
-- 0.9: what a perk still needs is drawn on the tree: a red badge with the points its tree still needs, red arrows
-- from perks that aren't at max rank yet (gold once they are). Builds can be saved under a name (db.builds).
local _, ns = ...
local T, UI, Live, Data, L, P = ns.Theme, ns.UI, ns.Live, ns.Data, ns.L, ns.Pages
local C = T.C

local function db() return ns.Core.db end

local tree = {}
local TREE_GAP = 12
local PLAN_H = 132
local TREE_W = math.floor((UI.CONTENT_W - 2 * TREE_GAP) / 3)
local TREE_H = UI.CONTENT_H - PLAN_H - TREE_GAP
local NODE_W, NODE_H, NODE_TILE = 68, 80, 36
local GRID_STEP = 900
local PRESET_W = 120

local function PresetByKey(key)
	for _, p in ipairs(Data.PRESETS) do if p.key == key then return p end end
end

-- The character whose tree is shown: the one picked in the plan bar, else the one you're playing.
local function TreeCharacter()
	local key = db().ui.treeChar
	if key and (key == Live.CharacterKey() or db().characters[key]) then return key end
	return Live.CharacterKey()
end

-- Current ranks by node ID for a character, or nil when the ledger hasn't seen them yet.
local function CurrentRanks(key, trees)
	if key == Live.CharacterKey() then
		local ranks = {}
		for _, t in ipairs(trees) do for _, n in ipairs(t.nodes) do ranks[n.id] = n.rank end end
		return ranks
	end
	local ch = db().characters[key]
	if not (ch and ch.perks) then return nil end
	local ranks = {}
	for id, r in pairs(ch.perks) do ranks[tonumber(id) or id] = r end
	return ranks
end

local function PlanTotal(plan)
	local n = 0
	for _, r in pairs(plan or {}) do n = n + r end
	return n
end

local function Copy(perks)
	local out = {}
	for id, r in pairs(perks or {}) do if r > 0 then out[tonumber(id) or id] = r end end
	return out
end

local function Same(a, b)
	if not (a and b) then return false end
	for id, r in pairs(a) do if (b[id] or 0) ~= r then return false end end
	for id, r in pairs(b) do if (a[id] or 0) ~= r then return false end end
	return true
end

-- 1.1 reset warning: what a plan changes against the current ranks. Returns { learn = { {node, from, to} },
-- takeBack = { ... }, trees = { tree name with ranks taken back } }. Taking a rank back needs a paid reset at the class
-- trainer (Data.RESET_COST_GOLD, forum reports 2026-11-10/12).
function ns.TreeDiff(plan, current, trees)
	local out = { learn = {}, takeBack = {}, trees = {} }
	if not (plan and current) then return out end
	for _, t in ipairs(trees) do
		local hit = false
		for _, n in ipairs(t.nodes) do
			local cur, want = current[n.id] or 0, plan[n.id] or 0
			if want > cur then out.learn[#out.learn + 1] = { node = n, from = cur, to = want }
			elseif want < cur then
				out.takeBack[#out.takeBack + 1] = { node = n, from = cur, to = want }
				hit = true
			end
		end
		if hit then out.trees[#out.trees + 1] = L[t.name] end
	end
	return out
end

-- What still blocks a node in a set of ranks: points missing in its tree, and prerequisite perks not at max rank.
local function Blockers(n, t, ranks)
	local inTree, byID = 0, {}
	for _, other in ipairs(t.nodes) do
		byID[other.id] = other
		if other.id ~= n.id then inTree = inTree + (ranks[other.id] or 0) end
	end
	local out = {}
	if (n.gate or 0) > inTree then out[#out + 1] = { kind = "gate", amount = n.gate, have = inTree, missing = n.gate - inTree } end
	for _, reqID in ipairs(n.requires or {}) do
		local req = byID[reqID]
		if req and (ranks[reqID] or 0) < req.maxRanks then out[#out + 1] = { kind = "perk", node = req } end
	end
	return out, inTree
end

local function NodeTooltip(self)
	local n = self.node
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if n.unnamed then
		GameTooltip:SetText(L["Reserved slot"], T.unpack(C.white))
		GameTooltip:AddLine(L["Blizzard keeps this slot for a perk coming in a later update. It can't be learned yet."], 0.78, 0.73, 0.65, true)
		GameTooltip:Show()
		return
	end
	GameTooltip:SetText(n.name, T.unpack(C.white))
	local desc = n.spellID and Live.SpellDescription(n.spellID)
	if desc and desc ~= "" then GameTooltip:AddLine(desc, 0.78, 0.73, 0.65, true) end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(string.format(L["Current rank %d of %d"], self.current or 0, n.maxRanks), T.unpack(C.parch))
	if self.planned then GameTooltip:AddLine(string.format(L["Planned rank %d"], self.planned), T.unpack(C.teal)) end
	-- requirements, red while unmet and gold once met
	local _, inTree = Blockers(n, self.tree, self.ranks or {})
	if (n.gate or 0) > 0 then
		local met = inTree >= n.gate
		GameTooltip:AddLine(string.format(L["Needs %d points in this tree first (%d so far)."], n.gate, inTree), T.unpack(met and C.head or C.bad))
	end
	for _, reqID in ipairs(n.requires or {}) do
		local req = self.byID and self.byID[reqID]
		if req then
			local met = ((self.ranks or {})[reqID] or 0) >= req.maxRanks
			GameTooltip:AddLine(string.format(L["Needs %s at rank %d first."], req.name, req.maxRanks), T.unpack(met and C.head or C.bad))
		end
	end
	if self.dead then GameTooltip:AddLine(L[self.dead.why], T.unpack(C.warn), true) end
	local note = Data.PERK_NOTES[n.id]
	if note then GameTooltip:AddLine(L[note], T.unpack(C.muted), true) end
	if self.planned and self.planned < (self.current or 0) then
		GameTooltip:AddLine(L["The plan takes ranks back here, which needs a reset at your class trainer."] .. P.RuleTag("reset"), T.unpack(C.warn), true)
	end
	GameTooltip:AddLine(L["Left-click adds a rank to the plan, right-click removes one."], T.unpack(C.muted))
	GameTooltip:Show()
end

local function StartPlan(key, current)
	local plan = db().plans[key]
	if type(plan) ~= "table" then -- the first click starts a plan from the current ranks
		plan = Copy(current)
		db().plans[key] = plan
	end
	return plan
end

local function CreateNode(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(NODE_W, NODE_H)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.tile = T.Tile(b, NODE_TILE)
	b.tile:SetPoint("TOP", 0, 0)
	b.hl = T.Hover(b.tile, 0.7)
	-- a red badge on the tile's corner: the points its tree still needs (a lock when only a perk blocks it)
	b.gate = CreateFrame("Frame", nil, b.tile)
	b.gate:SetSize(20, 20)
	b.gate:SetPoint("CENTER", b.tile, "TOPLEFT", 1, -1)
	b.gate:SetFrameLevel(b.tile:GetFrameLevel() + 3)
	b.gate.bg = b.gate:CreateTexture(nil, "ARTWORK")
	b.gate.bg:SetAllPoints()
	if not T.Atlas(b.gate.bg, "Legacy-Tree-Frame-level-circle") then
		b.gate.bg:SetTexture(T.Path("Glow"))
		b.gate.bg:SetVertexColor(0, 0, 0, 1)
	end
	b.gate.num = T.Text(b.gate, T.F.tiny, C.bad, "CENTER")
	b.gate.num:SetPoint("CENTER", 0, 0)
	b.gate.lock = T.Tex(b.gate, "GlyphLock", "OVERLAY", C.bad)
	b.gate.lock:SetSize(11, 11)
	b.gate.lock:SetPoint("CENTER")
	-- the rank as a plain figure under the icon (no badge box)
	b.badge = CreateFrame("Frame", nil, b)
	b.badge:SetSize(NODE_W, 14)
	b.badge:SetPoint("TOP", b.tile, "BOTTOM", 0, -3)
	b.rank = T.Text(b.badge, T.F.num, C.ink, "CENTER")
	b.rank:SetPoint("CENTER", 0, 0)
	b.name = T.Text(b, T.F.small, C.ink2, "CENTER")
	b.name:SetPoint("TOP", b.badge, "BOTTOM", 0, -2)
	b.name:SetWidth(NODE_W)
	b.name:SetMaxLines(2)
	b:SetScript("OnEnter", NodeTooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self, button)
		local n = self.node
		if n.unnamed then return end
		local plan = StartPlan(TreeCharacter(), self.currentRanks)
		local r = plan[n.id] or 0
		if button == "RightButton" then
			plan[n.id] = r > 1 and r - 1 or nil
		elseif r < n.maxRanks and PlanTotal(plan) < Data.SPEND_CAP and #Blockers(n, self.tree, plan) == 0 then
			plan[n.id] = r + 1
		end
		UI:Refresh()
		if self:IsMouseOver() then NodeTooltip(self) end
	end)
	return b
end

-- A prerequisite arrow between two node tiles: a rotated 2px line and a chevron head at the target.
local function CreateLink(parent)
	local l = { line = parent:CreateTexture(nil, "BORDER"), head = parent:CreateTexture(nil, "BORDER", nil, 1) }
	l.line:SetColorTexture(1, 1, 1, 1)
	l.line:SetHeight(2)
	l.head:SetTexture(T.Path("Chevron"))
	l.head:SetSize(12, 12)
	function l:Hide() self.line:Hide() self.head:Hide() end
	function l:Show() self.line:Show() self.head:Show() end
	function l:ClearAllPoints() self.line:ClearAllPoints() self.head:ClearAllPoints() end
	return l
end

local function PresetCard(parent, def)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(PRESET_W, 30)
	T.Rounded(b, "Chip", "BACKGROUND", C.paper)
	b.edge = T.Rounded(b, "ChipEdge", "BORDER", C.rule)
	b.hover = T.Hover(b, 0.5)
	b.sel = CreateFrame("Frame", nil, b)
	b.sel:SetAllPoints()
	T.Rounded(b.sel, "ChipEdge", "OVERLAY", C.accent)
	b.sel:Hide()
	b.Label = T.Text(b, T.F.tab, C.ink)
	b.Label:SetPoint("LEFT", 10, 0)
	b.Label:SetText(def.label)
	b.sub = T.Text(b, T.F.small, C.muted, "RIGHT")
	b.sub:SetPoint("RIGHT", -10, 0)
	b.sub:SetText(def.sub or "")
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(def.label, T.unpack(C.ink))
		if def.note then GameTooltip:AddLine(def.note, 0.78, 0.73, 0.65, true) end
		if def.perks then
			GameTooltip:AddLine(" ")
			for _, t in ipairs(Live.Trees()) do
				for _, n in ipairs(t.nodes) do
					if def.perks[n.id] then
						local r, g, bl = T.unpack(C.ink2)
						GameTooltip:AddDoubleLine(n.name, def.perks[n.id], r, g, bl, T.unpack(C.ink))
					end
				end
			end
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Click to load it. It replaces this character's plan."], T.unpack(C.muted))
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

---------------------------------------------------------------- builds (0.9)
-- Saved builds live in db.builds, account-wide: { name, perks = { [nodeID] = rank } }.
StaticPopupDialogs.YOURLEGACY_SAVE_BUILD = {
	text = L["Name this build. Every character on the account can load it."],
	button1 = SAVE or "Save", button2 = CANCEL or "Cancel",
	hasEditBox = true, maxLetters = 32,
	OnShow = function(self)
		local box = self and (self.editBox or (self.GetEditBox and self:GetEditBox()))
		if box then box:SetText(tree.suggestedName or "") box:HighlightText() end
	end,
	OnAccept = function(self)
		local box = self and (self.editBox or (self.GetEditBox and self:GetEditBox()))
		ns.Tree.SaveBuild(box and box:GetText() or "")
	end,
	EditBoxOnEnterPressed = function(self)
		ns.Tree.SaveBuild(self:GetText() or "")
		StaticPopup_Hide("YOURLEGACY_SAVE_BUILD")
	end,
	EditBoxOnEscapePressed = function() StaticPopup_Hide("YOURLEGACY_SAVE_BUILD") end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs.YOURLEGACY_DELETE_BUILD = {
	text = L["Delete the build \"%s\"? Plans that use it keep their ranks."],
	button1 = YES, button2 = NO,
	OnAccept = function(_, index) ns.Tree.DeleteBuild(index) end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

ns.Tree = { ui = tree } -- ui: the page's widgets, for tests
function ns.Tree.SaveBuild(name)
	name = strtrim(name or "")
	if name == "" then return false end
	local plan = db().plans[TreeCharacter()]
	if type(plan) ~= "table" or PlanTotal(plan) == 0 then return false end
	-- same name: overwrite that build
	for _, b in ipairs(db().builds) do
		if b.name == name then
			b.perks = Copy(plan)
			UI:Refresh()
			return true
		end
	end
	table.insert(db().builds, { name = name, perks = Copy(plan) })
	UI:Refresh()
	return true
end
function ns.Tree.DeleteBuild(index)
	if db().builds[index] then table.remove(db().builds, index) end
	UI:Refresh()
end

---------------------------------------------------------------- sharing (1.0)
-- A build as text: "!YL1!" + "nodeID.rank" pairs joined by commas + "!" + the name. Our own format; node IDs are
-- the game's, so a string works on every client language. Imported text is untrusted: a length cap, pattern
-- parsing only, and every node checked against the live trees (exists, visible, rank within its max, total
-- within the cap) before anything is saved.
local SHARE_PREFIX, SHARE_MAX_LEN, NAME_MAX = "!YL1!", 600, 32

local function CleanName(name)
	name = tostring(name or ""):gsub("|", ""):gsub("%c", "")
	return strtrim(name):sub(1, NAME_MAX)
end

function ns.Tree.Encode(perks, name)
	local ids = {}
	for id, r in pairs(perks or {}) do
		id, r = tonumber(id), tonumber(r)
		if id and r and r > 0 then ids[#ids + 1] = id end
	end
	if #ids == 0 then return nil end
	table.sort(ids)
	local pairs_ = {}
	for i, id in ipairs(ids) do pairs_[i] = id .. "." .. (tonumber(perks[id]) or tonumber(perks[tostring(id)])) end
	return SHARE_PREFIX .. table.concat(pairs_, ",") .. "!" .. CleanName(name)
end

-- Returns perks, name on success; nil, a message for the player otherwise.
function ns.Tree.Decode(text)
	text = strtrim(tostring(text or ""))
	if #text > SHARE_MAX_LEN then return nil, L["That text is too long to be a build."] end
	local body, name = text:match("^!YL1!([%d.,]+)!(.*)$")
	if not body then return nil, L["That isn't a Your Legacy build. Builds start with !YL1!"] end
	local known = {}
	for _, t in ipairs(Live.Trees()) do
		for _, n in ipairs(t.nodes) do if not n.unnamed then known[n.id] = n.maxRanks or 1 end end
	end
	if not next(known) then return nil, L["The Legacy trees haven't loaded yet. Try again in a moment."] end
	local perks, total = {}, 0
	for entry in body:gmatch("[^,]+") do
		local id, rank = entry:match("^(%d+)%.(%d+)$")
		id, rank = tonumber(id), tonumber(rank)
		if not (id and rank) then return nil, L["That build is damaged. Copy it again."] end
		if not known[id] then return nil, L["That build has a perk this game doesn't have."] end
		if rank < 1 or rank > known[id] or perks[id] then return nil, L["That build has a rank above what its perk allows."] end
		perks[id], total = rank, total + rank
	end
	if total == 0 then return nil, L["That build is empty."] end
	if total > Data.SPEND_CAP then return nil, string.format(L["That build needs %d points; a character can spend %d."], total, Data.SPEND_CAP) end
	return perks, CleanName(name)
end

-- Saves an imported build (a free name: "Name (2)" when taken) and loads it into the shown character's plan.
function ns.Tree.Import(text)
	local perks, nameOrError = ns.Tree.Decode(text)
	if not perks then
		ns.Core:Print(nameOrError)
		return false
	end
	local base = nameOrError ~= "" and nameOrError or L["Imported build"]
	local name, n = base, 1
	local function taken(s) for _, b in ipairs(db().builds) do if b.name == s then return true end end end
	while taken(name) do
		n = n + 1
		name = string.format("%s (%d)", base:sub(1, NAME_MAX - 5), n)
	end
	table.insert(db().builds, { name = name, perks = Copy(perks) })
	db().plans[TreeCharacter()] = Copy(perks)
	ns.Core:Print(string.format(L["Imported \"%s\" and loaded it into the plan."], name))
	UI:Refresh()
	return true
end

StaticPopupDialogs.YOURLEGACY_IMPORT_BUILD = {
	text = L["Paste a build someone shared with you. It's saved under My builds and loaded into this plan."],
	button1 = L["Import"], button2 = CANCEL or "Cancel",
	hasEditBox = true, maxLetters = SHARE_MAX_LEN, editBoxWidth = 360,
	OnAccept = function(self)
		local box = self and (self.editBox or (self.GetEditBox and self:GetEditBox()))
		ns.Tree.Import(box and box:GetText() or "")
	end,
	EditBoxOnEnterPressed = function(self)
		ns.Tree.Import(self:GetText() or "")
		StaticPopup_Hide("YOURLEGACY_IMPORT_BUILD")
	end,
	EditBoxOnEscapePressed = function() StaticPopup_Hide("YOURLEGACY_IMPORT_BUILD") end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

-- The plan as a share string, named after the build it matches, else the character.
function ns.Tree.ShareText()
	local key = TreeCharacter()
	local plan = db().plans[key]
	if type(plan) ~= "table" or PlanTotal(plan) == 0 then return nil end
	local name
	for _, b in ipairs(db().builds) do if not name and Same(plan, Copy(b.perks)) then name = b.name end end
	local who = db().characters[key]
	name = name or (who and who.name and string.format(L["%s's build"], who.name)) or ""
	return ns.Tree.Encode(plan, name)
end

local function BuildOptions()
	local out = {}
	for i, b in ipairs(db().builds) do
		out[#out + 1] = { i, string.format("%s  %s", b.name, T.Hex(C.muted) .. string.format(L["%d points"], PlanTotal(b.perks)) .. "|r"), deletable = true }
	end
	if #out == 0 then out[1] = { 0, T.Hex(C.muted) .. L["Save a plan to keep it here."] .. "|r" } end
	-- 1.0: sharing, at the end of the list as Blizzard's loadout menu has Import
	if ns.Tree.ShareText() then out[#out + 1] = { "share", T.Hex(C.head) .. L["Share this plan..."] .. "|r" } end
	out[#out + 1] = { "import", T.Hex(C.head) .. L["Import a build..."] .. "|r" }
	return out
end

-- "(Warlock, Tailoring)" for the plan bar: the class and the character's two primary professions.
local function WhoLine(ch)
	if not ch then return "" end
	local bits = { Live.ClassName(ch.class) }
	for _, p in ipairs(ch.professions or {}) do
		if (p.slot or 9) <= 2 then bits[#bits + 1] = p.name end
	end
	return "(" .. table.concat(bits, ", ") .. ")"
end

local function CharacterOptions()
	local list = {}
	for k, ch in pairs(db().characters) do list[#list + 1] = { key = k, ch = ch } end
	table.sort(list, function(a, b)
		if (a.ch.level or 0) ~= (b.ch.level or 0) then return (a.ch.level or 0) > (b.ch.level or 0) end
		return (a.ch.name or "") < (b.ch.name or "")
	end)
	local out = {}
	for _, e in ipairs(list) do
		local r, g, b = T.ClassColor(e.ch.class)
		local colour = T.Hex({ r, g, b })
		out[#out + 1] = { e.key, colour .. (e.ch.name or e.key) .. "|r  " .. T.Hex(C.muted) .. string.format(L["level %d"], e.ch.level or 1) .. "|r",
			buttonFont = T.F.name }
	end
	return out
end

local function BuildTree(page)
	local plan = T.Panel(page, L["Plan for"], UI.CONTENT_W, PLAN_H)
	plan:SetPoint("TOPLEFT")
	tree.plan = plan
	plan.title:SetText(L["Plan for"])
	tree.who = T.Dropdown(plan, 170, CharacterOptions, function(key)
		db().ui.treeChar = key
		UI:Refresh()
	end)
	tree.who:SetPoint("LEFT", plan.title, "RIGHT", 12, -1)
	tree.whoLine = T.Text(plan, T.F.body, C.ink2)
	tree.whoLine:SetPoint("LEFT", tree.who, "RIGHT", 12, 1)
	tree.open = T.ActionButton(plan, L["Open Legacy panel"])
	tree.open:SetPoint("RIGHT", plan.band, "RIGHT", -10, 0)
	tree.open:SetScript("OnClick", function() Live.OpenLegacyPanel() end)
	tree.open:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Blizzard's Legacy panel"], T.unpack(C.ink))
		GameTooltip:AddLine(L["The plan here is a guide. You learn perks and spend your points in Blizzard's Legacy panel."], 0.78, 0.73, 0.65, true)
		GameTooltip:AddLine(L["The panel opens once the account has its first Legacy point."], T.unpack(C.muted))
		GameTooltip:Show()
	end)
	tree.open:SetScript("OnLeave", function() GameTooltip:Hide() end)
	tree.clear = T.TextButton(plan, L["Clear plan"])
	tree.clear:SetPoint("RIGHT", tree.open, "LEFT", -8, 0)
	tree.current = T.TextButton(plan, L["Use current ranks"])
	tree.current:SetPoint("RIGHT", tree.clear, "LEFT", -4, 0)
	tree.current:SetScript("OnClick", function()
		local key = TreeCharacter()
		db().plans[key] = Copy(CurrentRanks(key, Live.Trees()))
		UI:Refresh()
	end)
	tree.clear:SetScript("OnClick", function()
		db().plans[TreeCharacter()] = nil
		UI:Refresh()
	end)
	plan.hint:Hide()
	local body = plan.body

	-- line 1: the presets, then saved builds and "Save as build"
	tree.buttons = {}
	for i, p in ipairs(Data.PRESETS) do
		local total = 0
		for _, r in pairs(p.perks) do total = total + r end
		local b = PresetCard(body, { label = L[p.name], note = L[Data.PRESET_NOTES[p.key] or ""], perks = p.perks, sub = total })
		b:SetPoint("TOPLEFT", (i - 1) * (PRESET_W + 6), 0)
		b:SetScript("OnClick", function()
			db().plans[TreeCharacter()] = Copy(PresetByKey(p.key).perks)
			UI:Refresh()
		end)
		b.perks = p.perks
		tree.buttons[p.key] = b
	end
	local x = #Data.PRESETS * (PRESET_W + 6) + 10
	tree.builds = T.Dropdown(body, 190, BuildOptions, function(index)
		if index == "share" then
			local text = ns.Tree.ShareText()
			if text and ns.Export then
				ns.Export:ShowText(L["Share this plan"], L["The text is selected. Press Ctrl+C to copy it. Anyone with Your Legacy can paste it with Import a build on the Legacy Tree page."], text)
			end
			UI:Refresh() -- the list goes back to showing the build the plan matches
			return
		elseif index == "import" then
			StaticPopup_Show("YOURLEGACY_IMPORT_BUILD")
			UI:Refresh()
			return
		end
		local b = db().builds[index]
		if not b then return end
		db().plans[TreeCharacter()] = Copy(b.perks)
		UI:Refresh()
	end)
	tree.builds.placeholder = L["My builds"]
	tree.builds.onDelete = function(index)
		local b = db().builds[index]
		if b then StaticPopup_Show("YOURLEGACY_DELETE_BUILD", b.name, nil, index) end
	end
	tree.builds:SetPoint("TOPLEFT", x, -3)
	tree.save = T.ActionButton(body, L["Save as build"])
	tree.save:SetPoint("LEFT", tree.builds, "RIGHT", 10, 0)
	tree.save:SetScript("OnClick", function()
		local who = db().characters[TreeCharacter()]
		tree.suggestedName = who and who.name and string.format(L["%s's build"], who.name) or ""
		StaticPopup_Show("YOURLEGACY_SAVE_BUILD")
	end)
	tree.save:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Save as build"], T.unpack(C.ink))
		GameTooltip:AddLine(L["Saves this plan under a name for every character on the account. Saving under an existing name replaces that build."], 0.78, 0.73, 0.65, true)
		GameTooltip:Show()
	end)
	tree.save:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- line 2: the plan's total against the cap, what it means, and the key to the tree's marks
	tree.total = T.Text(body, T.F.mid, C.ink)
	tree.total:SetPoint("TOPLEFT", 0, -46)
	tree.cap = T.Text(body, T.F.num, C.muted)
	tree.cap:SetPoint("BOTTOMLEFT", tree.total, "BOTTOMRIGHT", 2, 1)
	tree.summary = T.Text(body, T.F.body, C.muted)
	tree.summary:SetPoint("LEFT", tree.cap, "RIGHT", 12, 0)
	tree.summary:SetWordWrap(false)
	-- 1.1: hover the summary for what the plan changes, perk by perk
	tree.diffHit = CreateFrame("Frame", nil, body)
	tree.diffHit:SetPoint("TOPLEFT", tree.summary, "TOPLEFT", -2, 2)
	tree.diffHit:SetPoint("BOTTOMRIGHT", tree.summary, "BOTTOMRIGHT", 2, -2)
	tree.diffHit:EnableMouse(true)
	tree.diffHit:SetScript("OnEnter", function(self)
		local diff = tree.diff
		if not diff or (#diff.learn == 0 and #diff.takeBack == 0) then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["What this plan changes"], T.unpack(C.ink))
		local function lines(list, color)
			for _, d in ipairs(list) do
				local r, g, b = T.unpack(C.ink2)
				local r2, g2, b2 = T.unpack(color)
				GameTooltip:AddDoubleLine(d.node.name, string.format("%d > %d", d.from, d.to), r, g, b, r2, g2, b2)
			end
		end
		if #diff.learn > 0 then
			GameTooltip:AddLine(L["Learn"], T.unpack(C.head))
			lines(diff.learn, C.teal)
		end
		if #diff.takeBack > 0 then
			GameTooltip:AddLine(L["Take back"], T.unpack(C.head))
			lines(diff.takeBack, C.warn)
			GameTooltip:AddLine(string.format(L["Taking ranks back needs a reset at your class trainer. It clears every rank in all three trees, Talented too, and players report it costs %d gold. Then learn the plan again in the Legacy panel."], Data.RESET_COST_GOLD), T.unpack(C.muted), true)
			if (tree.deficit or 0) > 0 then
				GameTooltip:AddLine(string.format(L["Below level 60 the trainer won't reset while Talented pays for spent class talents: unlearn %d class talent points there first."], tree.deficit), T.unpack(C.warn), true)
			end
		end
		GameTooltip:Show()
	end)
	tree.diffHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	tree.legend = T.Text(body, T.F.small, C.muted, "RIGHT")
	tree.legend:SetPoint("TOPRIGHT", 0, -48)
	tree.legend:SetText(T.Hex(C.bad) .. "5|r " .. L["points this tree still needs"] .. "     "
		.. T.Hex(C.bad) .. "—>|r " .. L["needs that perk at max rank"] .. "     "
		.. T.Hex(C.head) .. "—>|r " .. L["met"])

	tree.cols = {}
	for i, def in ipairs(Data.TREES) do
		local p = T.Panel(page, L[def.name], TREE_W, TREE_H)
		p:SetPoint("TOPLEFT", (i - 1) * (TREE_W + TREE_GAP), -(PLAN_H + TREE_GAP))
		-- the tree's own icon from Blizzard's Legacy panel (UI-Legacy-Tree-*); none if the client lacks it
		p.icon = p:CreateTexture(nil, "ARTWORK")
		p.icon:SetSize(22, 22)
		p.icon:SetPoint("LEFT", p.band, "LEFT", 10, 0)
		if T.Atlas(p.icon, def.icon) then
			p.title:ClearAllPoints()
			p.title:SetPoint("LEFT", p.icon, "RIGHT", 8, 0)
		else
			p.icon:Hide()
		end
		p.links = UI.Pool(p.body, CreateLink)
		p.nodes = UI.Pool(p.body, CreateNode)
		p.empty = T.Text(p.body, T.F.body, C.muted)
		p.empty:SetPoint("TOPLEFT", 2, -4)
		p.empty:SetWidth(TREE_W - 32)
		tree.cols[def.key] = p
	end
end

local function RefreshTree()
	local trees, spentLive = Live.Trees()
	local key = TreeCharacter()
	local current = CurrentRanks(key, trees)
	local plan = type(db().plans[key]) == "table" and db().plans[key] or nil
	local earned = math.min(Data.SPEND_CAP, Live.Earned())
	local ch = db().characters[key]
	local level = ch and ch.level or 1

	-- "Plan for [Name v] (Class, crafts)"
	tree.who:SetValue(key)
	if ch then
		tree.who.Text:SetText(ch.name or key)
		tree.who.Text:SetTextColor(T.ClassColor(ch.class))
	end
	tree.whoLine:SetText(WhoLine(ch))

	-- which preset or saved build the plan matches exactly, if any
	for _, b in pairs(tree.buttons) do b.sel:SetShown(Same(plan, b.perks)) end
	local match
	for i, b in ipairs(db().builds) do if not match and Same(plan, Copy(b.perks)) then match = i end end
	tree.builds:SetValue(match)
	if not match then
		tree.builds.Text:SetText(L["My builds"])
		tree.builds.Text:SetTextColor(T.unpack(C.ink2))
	else
		tree.builds.Text:SetText(db().builds[match].name)
		tree.builds.Text:SetTextColor(T.unpack(C.ink))
	end
	local canSave = plan and PlanTotal(plan) > 0
	if canSave then tree.save:Enable() else tree.save:Disable() end

	-- the plan's total against the cap
	local total = plan and PlanTotal(plan) or 0
	tree.total:SetText(plan and total or "–")
	tree.total:SetTextColor(T.unpack(plan and C.goldHi or C.muted))
	tree.cap:SetText("/" .. Data.SPEND_CAP)
	local spent = key == Live.CharacterKey() and spentLive or (ch and ch.spent) or 0
	local who = ch and ch.name or key
	local _, wasted = P.DeadPerks(plan or current, level)
	local diff = ns.TreeDiff(plan, current, trees)
	tree.diff = diff
	if wasted > 0 then
		-- ranks (planned, else learned) in perks that no longer help at this character's level
		tree.summary:SetText(string.format(L["%d points sit in perks that no longer help at level %d."], wasted, level) .. P.RuleTag("deadPerks"))
		tree.summary:SetTextColor(T.unpack(C.warn))
	elseif #diff.takeBack > 0 then
		-- 1.1: the loudest complaint after launch is the 10g reset with no confirmation; say so before it happens
		local back = 0
		for _, d in ipairs(diff.takeBack) do back = back + d.from - d.to end
		-- 1.2: a trainer reset clears every rank, not just the ones the plan drops; below 60 Talented can block it
		tree.deficit = key == Live.CharacterKey() and P.TalentedDeficit(level, current[Data.TALENTED_NODE], Live.ClassTalentUnspent()) or 0
		if tree.deficit > 0 then
			tree.summary:SetText(string.format(L["Takes back %d ranks. Unlearn %d class talent points first."], back, tree.deficit) .. P.RuleTag("talentedReset"))
		else
			tree.summary:SetText(string.format(L["Takes back %d ranks: a trainer reset clears all %d (%d gold)."], back,
				spent, Data.RESET_COST_GOLD) .. P.RuleTag("reset"))
		end
		tree.summary:SetTextColor(T.unpack(C.warn))
	elseif not plan then
		tree.summary:SetText(string.format(L["No plan for %s yet. Load a build or click perks."], who))
		tree.summary:SetTextColor(T.unpack(C.muted))
	elseif total > earned then
		tree.summary:SetText(string.format(L["Needs %d points; the account has %d to spend."], total, earned))
		tree.summary:SetTextColor(T.unpack(C.fire))
	else
		tree.summary:SetText(string.format(L["%d spent now, %d still to place."], spent, math.max(0, total - spent)))
		tree.summary:SetTextColor(T.unpack(C.parch))
	end
	-- 1.2: a warning (dead perks, ranks taken back, Talented) takes the legend's room: in German it's too long to
	-- sit beside it, and the legend only explains the arrow colours
	tree.legend:SetShown(not (wasted > 0 or #diff.takeBack > 0))

	-- the grid every tree shares, in the game's units
	local minX, maxX, minY = math.huge, -math.huge, math.huge
	for _, t in ipairs(trees) do
		for _, n in ipairs(t.nodes) do
			minX, maxX = math.min(minX, n.x), math.max(maxX, n.x)
			minY = math.min(minY, n.y)
		end
	end
	local cols = maxX > minX and math.floor((maxX - minX) / GRID_STEP + 0.5) + 1 or 1
	local innerW = TREE_W - 28
	local colW = innerW / math.max(cols, 1)
	local rows = 1
	for _, t in ipairs(trees) do for _, n in ipairs(t.nodes) do rows = math.max(rows, math.floor((n.y - minY) / GRID_STEP + 0.5) + 1) end end
	local rowH = math.min(NODE_H + 18, (TREE_H - 58 - NODE_H) / math.max(1, rows - 1))
	-- requirements are judged against the plan, or the current ranks without one
	local ranks = plan or current or {}
	for _, t in ipairs(trees) do
		local col = tree.cols[t.key]
		col.nodes:Reset()
		col.links:Reset()
		local planned = 0
		for _, n in ipairs(t.nodes) do planned = planned + (plan and plan[n.id] or 0) end
		col.hint:SetText(plan and string.format(L["%d planned"], planned) or string.format(L["%d spent"], t.spent))
		col.empty:SetShown(#t.nodes == 0)
		col.empty:SetText(L["Not unlocked yet"])
		local byID, pos = {}, {}
		for _, n in ipairs(t.nodes) do
			byID[n.id] = n
			local cx = math.floor((n.x - minX) / GRID_STEP + 0.5)
			local cy = math.floor((n.y - minY) / GRID_STEP + 0.5)
			pos[n.id] = { x = cx * colW + colW / 2, y = cy * rowH }
		end
		for _, n in ipairs(t.nodes) do
			local b = col.nodes:Acquire()
			b.node, b.currentRanks, b.tree, b.byID, b.ranks = n, current, t, byID, ranks
			local p = pos[n.id]
			b:SetPoint("TOP", col.body, "TOPLEFT", p.x, -p.y)
			local cur = current and current[n.id] or 0
			local want = plan and (plan[n.id] or 0) or nil
			b.current, b.planned = cur, want
			local blockers = n.unnamed and {} or Blockers(n, t, ranks)
			local gateMissing, perkMissing = nil, false
			for _, bl in ipairs(blockers) do
				if bl.kind == "gate" then gateMissing = bl.missing else perkMissing = true end
			end
			local locked = #blockers > 0 and (ranks[n.id] or 0) == 0
			local blockedPlan = plan and want and want > 0 and #blockers > 0
			-- ranks (planned or learned) in a perk that no longer helps at this character's level
			local deadDef = Data.DEAD_PERKS[n.id]
			local dead = deadDef and level >= deadDef.level and ((want or cur) > 0) and deadDef or nil
			b.dead = dead
			-- the badge: the points still missing in the tree, else a lock when only a perk blocks it
			b.gate:SetShown((gateMissing or perkMissing) and ((ranks[n.id] or 0) == 0 or blockedPlan) and true or false)
			b.gate.num:SetShown(gateMissing ~= nil)
			b.gate.num:SetText(gateMissing or "")
			b.gate.lock:SetShown(gateMissing == nil)
			if n.unnamed then
				-- a reserved socket: no icon, no rank, no name
				b.tile:SetIcon("glyph:Lock", C.muted)
				b.tile:SetState(C.goldLo, true)
				b.tile:SetAlpha(0.45)
				b.badge:Hide()
				b.gate:Hide()
				b.name:SetText(L["Reserved"])
				b.name:SetTextColor(T.unpack(C.muted, 0.7))
			else
				b.tile:SetAlpha(locked and 0.55 or 1)
				b.badge:Show()
				if n.icon then b.tile:SetIcon(n.icon) else b.tile:SetIcon("glyph:Lock", C.muted) end
				-- the edge says it all: accent = planned higher than now, gold = learned, red = blocked,
				-- amber = planned lower, rule = nothing yet
				local state = C.rule
				if blockedPlan then state = C.bad elseif dead then state = C.warn elseif want and want > cur then state = C.accent elseif want and want < cur then state = C.warn elseif cur > 0 then state = C.heat6 end
				b.tile:SetState(state, cur == 0 and not (want and want > 0))
				local shown = want or cur
				b.rank:SetText(string.format("%d/%d", shown, n.maxRanks))
				b.rank:SetTextColor(T.unpack((want or cur) > 0 and C.ink or C.muted))
				b.name:SetText(n.name)
				b.name:SetTextColor(T.unpack((cur > 0 or (want or 0) > 0) and C.ink or C.muted))
			end
		end
		-- arrows: from each perk to the ones it unlocks, drawn under the tiles; red until the source is at max rank
		for _, n in ipairs(t.nodes) do
			for _, target in ipairs(n.edges or {}) do
				local a, z = pos[n.id], pos[target]
				if a and z then
					local x1, y1 = a.x, -(a.y + NODE_TILE / 2)
					local x2, y2 = z.x, -(z.y + NODE_TILE / 2)
					local dx, dy = x2 - x1, y2 - y1
					local len = math.sqrt(dx * dx + dy * dy)
					local link = col.links:Acquire()
					link:Show()
					link.line:SetWidth(len)
					link.line:SetPoint("CENTER", col.body, "TOPLEFT", (x1 + x2) / 2, (y1 + y2) / 2)
					local angle = math.atan2(dy, dx)
					link.line:SetRotation(angle)
					-- the head sits just outside the target tile, pointing at it (the chevron art points down)
					local back = NODE_TILE / 2 + 7
					link.head:SetPoint("CENTER", col.body, "TOPLEFT", x2 - dx / len * back, y2 - dy / len * back)
					link.head:SetRotation(angle + math.pi / 2)
					local met = (ranks[n.id] or 0) >= n.maxRanks
					local c = met and C.head or C.bad
					link.line:SetColorTexture(T.unpack(c, met and 0.9 or 0.6))
					link.head:SetVertexColor(T.unpack(c, met and 0.9 or 0.7))
				end
			end
		end
	end
end

UI:RegisterPage("tree", L["Legacy Tree"], BuildTree, RefreshTree)
