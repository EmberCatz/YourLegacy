-- 1.0 world map button: our icon in the stack of map buttons down the map's top-left corner (where Forever puts
-- Blizzard's map pin button), with a menu of map options. Features add entries with MapButton:Add (the zone
-- progress box adds its switch and corner).
-- When another addon loaded Krowi_WorldMapButtons (Questie, AllTheThings, GatherLite embed it), the button joins
-- that shared stack and the library keeps it in line. Otherwise it's our own frame on the map's scroll container in
-- the next free slot of the stack. MapZone's ticker drives it while the map is open. No hooks of our own, no
-- AddOverlayFrame (that needs an XML template).
-- Entries: { kind = "title", text }, { kind = "toggle", text, get(), set(on) },
--          { kind = "radio", text, value, get(), set(value) }, { kind = "action", text, run() }.
local _, ns = ...
local T, Live, L = ns.Theme, ns.Live, ns.L
local C = T.C

local MB = {}
ns.MapButton = MB
MB.SIZE = 32
MB.ROW = 20
MB.entries = {}

local button, menu

-- entry.order sorts the menu (features load in any order); equal orders keep the order they were added in.
function MB:Add(entry)
	entry.order = entry.order or 50
	local at = #self.entries + 1
	for i, e in ipairs(self.entries) do
		if e.order > entry.order then at = i break end
	end
	table.insert(self.entries, at, entry)
end

-- Over the map's icons: OpenMap's stitched map and its icons reach 9000 above the map's scroll container (it lifts
-- Blizzard's map buttons over that; GatherLite's button goes there too). A frame level can't pass 10000.
function MB.Level(container)
	return math.min(container:GetFrameLevel() + 9010, 9900)
end

function MB.Enabled()
	local db = ns.Core.db
	return db and db.settings.mapButton == true or false
end

local function Checked(e)
	if e.kind == "toggle" then return e.get() and true or false end
	if e.kind == "radio" then return e.get() == e.value end
	return false
end

local function Lay()
	local widest = 0
	for i, e in ipairs(MB.entries) do
		local r = menu.rows[i]
		if not r then
			r = CreateFrame("Button", nil, menu)
			r:SetHeight(MB.ROW)
			r.hover = T.Hover(r, 0.5)
			r.check = r:CreateTexture(nil, "OVERLAY")
			r.check:SetSize(14, 14)
			r.check:SetPoint("LEFT", 0, 0)
			if not T.Atlas(r.check, "common-dropdown-icon-checkmark-yellow") then
				r.check:SetTexture(T.Path("Check"))
				r.check:SetVertexColor(T.unpack(C.head))
			end
			r.Label = T.Text(r, T.F.body, C.ink)
			r.Label:SetPoint("LEFT", 20, 0)
			r.Label:SetWordWrap(false)
			r:SetScript("OnClick", function(self)
				local entry = self.entry
				if entry.kind == "toggle" then entry.set(not entry.get())
				elseif entry.kind == "radio" then entry.set(entry.value)
				elseif entry.kind == "action" then menu:Hide() entry.run() return end
				Lay()
			end)
			menu.rows[i] = r
		end
		r.entry = e
		local title = e.kind == "title"
		r.Label:SetFontObject(title and T.F.small or T.F.body)
		r.Label:SetText(e.text)
		r.Label:ClearAllPoints()
		r.Label:SetPoint("LEFT", title and 0 or 20, 0)
		r.Label:SetTextColor(T.unpack(title and C.head or (Checked(e) and C.head or C.ink)))
		r.check:SetShown(Checked(e))
		r.hover:SetShown(not title)
		r:EnableMouse(not title)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -10 - (i - 1) * MB.ROW)
		r:SetPoint("RIGHT", menu, "RIGHT", -12, 0)
		r:Show()
		widest = math.max(widest, r.Label:GetStringWidth() + (title and 0 or 20))
	end
	for i = #MB.entries + 1, #menu.rows do menu.rows[i]:Hide() end
	menu:SetSize(math.max(150, math.ceil(widest) + 28), #MB.entries * MB.ROW + 20)
end

local function CreateMenu()
	menu = CreateFrame("Frame", nil, button)
	menu:SetFrameStrata("DIALOG")
	menu:SetPoint("TOPLEFT", button, "TOPRIGHT", 4, 0) -- beside the stack, not over the buttons under ours
	menu:EnableMouse(true)
	menu:Hide()
	menu.bg = menu:CreateTexture(nil, "BACKGROUND")
	if T.Atlas(menu.bg, "common-dropdown-bg") then
		menu.bg:SetPoint("TOPLEFT", -10, 3)
		menu.bg:SetPoint("BOTTOMRIGHT", 10, -3)
		menu.bg:SetAlpha(0.925)
	else
		menu.bg:SetAllPoints()
		menu.bg:SetColorTexture(T.unpack(C.paper))
		T.Border(menu, C.rule)
	end
	menu.rows = {}
	-- a click anywhere else closes it, as Blizzard's menus do; it listens only while it's open
	menu:SetScript("OnEvent", function(self)
		if not (self:IsMouseOver() or button:IsMouseOver()) then self:Hide() end
	end)
	menu:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
	menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
end

local function Create(container)
	-- In the shared stack when another addon loaded Krowi_WorldMapButtons: the library makes the button (no template
	-- needed), places it with the others and calls button:Refresh() when the map changes.
	local lib = Live.MapButtonLibrary()
	if lib and type(lib.Add) == "function" then
		button = lib:Add(nil, "Button")
		button.Refresh = function() end
		MB.stack = lib
	else
		button = CreateFrame("Button", nil, container)
	end
	button:SetSize(MB.SIZE, MB.SIZE)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(T.MEDIA .. "Icon")
	button.icon:SetSize(22, 22)
	button.icon:SetPoint("CENTER")
	button.ring = T.Tex(button, "MinimapRing", "BACKGROUND")
	button.ring:SetAllPoints()
	local hl = T.Tex(button, "MinimapRing", "HIGHLIGHT", C.ink, 0.35)
	hl:SetAllPoints()
	hl:SetBlendMode("ADD")
	button:SetScript("OnClick", function()
		if menu:IsShown() then menu:Hide() else Lay() menu:Show() T.Reveal(menu, T.DUR_MICRO) end
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Your Legacy", 1, 0.97, 0.92)
		GameTooltip:AddLine(L["Click for map options."], T.unpack(C.muted))
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	CreateMenu()
end

-- Show or hide the button for the open map (called by MapZone's checks; shown = map open and out of combat).
function MB:Update(shown)
	-- In the shared stack the library places every button, Blizzard's map pin button among them: only change
	-- ours out of combat, then let it stack again (its buttons skip hidden ones).
	if self.stack then
		if InCombatLockdown() then return end
		-- over the map's icons (OpenMap's stitched map draws up to 9000 above the scroll container)
		local canvas = Live.MapView()
		local container = canvas and (canvas:GetParent() or canvas)
		if container then button:SetFrameLevel(MB.Level(container)) end
		local want = self.Enabled() and true or false
		if button:IsShown() ~= want then
			button:SetShown(want)
			if not want then menu:Hide() end
			if type(self.stack.SetPoints) == "function" then self.stack.SetPoints() end
		end
		if menu:IsShown() then Lay() end
		return
	end
	local canvas = shown and Live.MapView()
	local container = canvas and (canvas:GetParent() or canvas)
	if not (container and self.Enabled()) then
		if button then button:Hide() menu:Hide() end
		return
	end
	if not button then
		Create(container)
		if self.stack then return self:Update(shown) end
	end
	-- our own: the next slot of the top-left stack, under Blizzard's and other addons' buttons
	button:SetFrameLevel(MB.Level(container))
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", container, "TOPLEFT", 3, Live.MapButtonSlot(container))
	button:Show()
	if menu:IsShown() then Lay() end
end

MB.Button = function() return button, menu end -- for tests

MB:Add({ kind = "action", order = 100, text = L["Open Your Legacy"], run = function() ns.Core:Toggle() end })
