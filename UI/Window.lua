-- Main window: Blizzard's portrait frame, side tabs, page switching, shared widgets (pools, scroll areas).
local _, ns = ...
local T = ns.Theme
local C = T.C

local UI = { pages = {}, order = {} }
ns.UI = UI

local WIDTH, HEIGHT = 980, 640
-- The Legacy panel's leather (Legacy-Challenge-BG) has a header band painted across its top, closed by a line.
-- Blizzard keeps its content under that line (Blizzard_LegacyChallenges.xml: the list starts at y -80 on a 575px
-- frame). On our 640px window the line lands 88 units down (measured on the user's screenshots: the groove at 85,
-- its highlight at 88). 0.9.1: the pages start under it and the page tabs sit in the band above it.
UI.HEADER_LINE = 88
UI.PAGE_TOP = UI.HEADER_LINE + 6
UI.CONTENT_W, UI.CONTENT_H = WIDTH - 28, HEIGHT - UI.PAGE_TOP - 12 -- inside Blizzard's frame edge, under the line
local TAB_H = 28

-- Reusable rows: frames can't be destroyed in WoW, so pages keep pools and hide what they don't use.
function UI.Pool(parent, create)
	local pool = { items = {}, used = 0 }
	function pool:Reset()
		for _, item in ipairs(self.items) do item:Hide() end
		self.used = 0
	end
	function pool:Acquire()
		self.used = self.used + 1
		local item = self.items[self.used]
		if not item then
			item = create(parent, self.used)
			self.items[self.used] = item
		end
		item:ClearAllPoints()
		item:Show()
		return item
	end
	return pool
end

-- A scrollable area with a slim thumb on the right; returns scrollFrame, child. The thumb is a handle (0.9): drag
-- it, or click the track above or below it to jump there. It draws 4px wide but takes the mouse over 12px.
function UI.Scroll(parent, width, height)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetSize(width, height)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(width - 12, height)
	scroll:SetScrollChild(child)
	local rail = CreateFrame("Button", nil, scroll)
	rail:SetPoint("TOPRIGHT", 0, 0)
	rail:SetPoint("BOTTOMRIGHT", 0, 0)
	rail:SetWidth(12)
	rail:SetFrameLevel(scroll:GetFrameLevel() + 10)
	rail.track = T.Tex(rail, "Thumb", "BACKGROUND", C.rule, 0.35)
	rail.track:SetWidth(2)
	rail.track:SetPoint("TOP", 1, 0)
	rail.track:SetPoint("BOTTOM", 1, 0)
	local handle = CreateFrame("Button", nil, rail)
	handle:SetWidth(12)
	handle:SetFrameLevel(rail:GetFrameLevel() + 1)
	local thumb = T.Tex(handle, "Thumb", "OVERLAY", C.muted, 0.6)
	thumb:SetWidth(4)
	thumb:SetPoint("TOP", 1, 0)
	thumb:SetPoint("BOTTOM", 1, 0)
	scroll.rail, scroll.handle, scroll.thumb = rail, handle, thumb
	local function Range() return math.max(0, child:GetHeight() - scroll:GetHeight()) end
	local function UpdateThumb()
		local range = Range()
		rail:SetShown(range > 0)
		if range > 0 then
			local h = math.max(24, scroll:GetHeight() * scroll:GetHeight() / child:GetHeight())
			handle:SetHeight(h)
			handle:ClearAllPoints()
			handle:SetPoint("TOPRIGHT", rail, "TOPRIGHT", 0, -(scroll:GetHeight() - h) * scroll:GetVerticalScroll() / range)
		end
	end
	local function Lit(on) thumb:SetVertexColor(T.unpack(on and C.head or C.muted, on and 0.9 or 0.6)) end
	handle:SetScript("OnEnter", function() Lit(true) end)
	handle:SetScript("OnLeave", function(self) if not self.dragging then Lit(false) end end)
	-- dragging: the scroll follows the cursor's travel since the press, scaled from track to content
	local function Follow(self)
		local _, y = GetCursorPosition()
		y = y / scroll:GetEffectiveScale()
		local travel = scroll:GetHeight() - self:GetHeight()
		if travel <= 0 then return end
		local pos = self.startScroll + (self.startY - y) * Range() / travel
		scroll:SetScript("OnUpdate", nil) -- a drag cancels a wheel glide
		scroll:SetVerticalScroll(math.max(0, math.min(Range(), pos)))
		UpdateThumb()
	end
	handle:SetScript("OnMouseDown", function(self)
		local _, y = GetCursorPosition()
		self.startY, self.startScroll, self.dragging = y / scroll:GetEffectiveScale(), scroll:GetVerticalScroll(), true
		Lit(true)
		self:SetScript("OnUpdate", Follow) -- only while the button is held
	end)
	handle:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
		self.dragging = false
		Lit(self:IsMouseOver())
	end)
	-- a click on the track pages toward the cursor
	rail:SetScript("OnClick", function(self)
		local _, y = GetCursorPosition()
		y = y / scroll:GetEffectiveScale()
		local up = y > (handle:GetTop() or y)
		local pos = scroll:GetVerticalScroll() + (up and -1 or 1) * scroll:GetHeight() * 0.9
		scroll:SetScript("OnUpdate", nil)
		scroll:SetVerticalScroll(math.max(0, math.min(Range(), pos)))
		UpdateThumb()
	end)
	function scroll:SetContentHeight(h)
		child:SetHeight(math.max(h, 1))
		self:SetVerticalScroll(math.min(self:GetVerticalScroll(), math.max(0, child:GetHeight() - self:GetHeight())))
		UpdateThumb()
	end
	-- Smooth wheel scrolling (as EllesmereUI does it): the wheel moves a target, an OnUpdate eases toward it and
	-- removes itself on arrival, so nothing runs while the list is still. Animations off: jump straight there.
	local target
	local function Glide(self, elapsed)
		local cur = self:GetVerticalScroll()
		local nextPos = cur + (target - cur) * math.min(1, 14 * elapsed)
		if math.abs(target - nextPos) < 0.5 then
			nextPos = target
			self:SetScript("OnUpdate", nil)
		end
		self:SetVerticalScroll(nextPos)
		UpdateThumb()
	end
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		-- 1.1 (the user's bug): a tooltip anchored to a card in here rode along with the scroll; close it, as
		-- Blizzard's scroll lists do
		local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
		while owner do
			if owner == self then GameTooltip:Hide() break end
			owner = owner.GetParent and owner:GetParent()
		end
		local max = math.max(0, child:GetHeight() - self:GetHeight())
		target = math.max(0, math.min(max, (self:GetScript("OnUpdate") and target or self:GetVerticalScroll()) - delta * 48))
		if T.Animated() then
			self:SetScript("OnUpdate", Glide)
		else
			self:SetVerticalScroll(target)
			UpdateThumb()
		end
	end)
	return scroll, child
end

function UI:RegisterPage(key, label, builder, refresher)
	self.pages[key] = { label = label, build = builder, refresh = refresher }
	self.order[#self.order + 1] = key
end

-- A page without a tab (the options, opened by the gear button).
function UI:RegisterView(key, builder, refresher)
	self.pages[key] = { build = builder, refresh = refresher, untabbed = true }
end

-- The window is built the way Blizzard builds its Forever panels (PortraitFrameTemplate, Blizzard_LegacySystem):
-- the metal NineSlice frame, a round portrait, a gold title in the top strip and the red close button. Built from
-- the layout and atlases rather than by inheriting PortraitFrameTemplate, so the window keeps its own name, size and
-- drag handling. 0.9.1: the page tabs are text in the leather's header band, right of the portrait, resting on the
-- band's line (the icon tabs on the right edge are gone, the user's ask); Options sits at the band's right end.

local function Version()
	local v = C_AddOns and C_AddOns.GetAddOnMetadata and ns.Live.try(C_AddOns.GetAddOnMetadata, "YourLegacy", "Version")
	return v
end
UI.Version = Version

-- Window sounds, as Blizzard's own panels play them (SoundKitConstants: 839 open, 840 close, 841 tab). Silent while
-- the screenshot run flips through the pages.
function UI.Sound(kind)
	if ns.Shots and ns.Shots:Running() then return end
	local kit = SOUNDKIT or {}
	local ids = { open = kit.IG_CHARACTER_INFO_OPEN or 839, close = kit.IG_CHARACTER_INFO_CLOSE or 840, tab = kit.IG_CHARACTER_INFO_TAB or 841 }
	ns.Live.PlaySound(ids[kind])
end

function UI:Create()
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "YourLegacyFrame", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if ns.Core:Setting("locked") then return end
		self:StartMoving()
		if ns.Character then ns.Character:DragStart() end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if ns.Character then ns.Character:DragStop() end
	end)
	tinsert(UISpecialFrames, "YourLegacyFrame") -- Escape closes it
	-- the sounds Blizzard's Legacy panel makes (Blizzard_LegacySystem.lua: IG_CHARACTER_INFO_OPEN / _CLOSE)
	f:SetScript("OnShow", function() UI.Sound("open") end)
	f:SetScript("OnHide", function()
		T.CloseDropdowns()
		UI.Sound("close")
	end)

	-- the ground: the Legacy panel's leather under the content, a dark fill behind it in case the atlas is missing
	T.Fill(f, "BACKGROUND", C.paper, nil, -8)
	local ground = f:CreateTexture(nil, "BACKGROUND", nil, -6)
	ground:SetPoint("TOPLEFT", 2, -21)
	ground:SetPoint("BOTTOMRIGHT", -2, 2)
	if not T.Atlas(ground, "Legacy-Challenge-BG") then ground:Hide() end
	-- the frame itself, above the pages so its edge overlaps them as Blizzard's does
	self.border = T.NineSlice(f, "PortraitFrameTemplate", 40)
	local portrait = self.border:CreateTexture(nil, "OVERLAY", nil, 7) -- above the nine-slice's portrait ring
	portrait:SetSize(75, 75)
	portrait:SetPoint("CENTER", self.border, "TOPLEFT", 25, -23) -- the portrait ring's centre
	portrait:SetTexture(T.MEDIA .. "Logo")
	local title = T.Text(self.border, T.F.brand, C.head, "CENTER")
	title:SetPoint("TOP", 0, -5)
	title:SetPoint("LEFT", 60, 0)
	title:SetPoint("RIGHT", -60, 0)
	title:SetText("Your Legacy")
	self.title = title
	local close = CreateFrame("Button", nil, self.border, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, 1)
	close:SetScript("OnClick", function() f:Hide() end)
	-- the version on every page, quiet, in the top strip left of the close button. It shares the title's line box
	-- (same top and bottom, centred in it), so the two read on one line whatever their sizes.
	self.version = T.Text(self.border, T.F.tiny, C.muted, "RIGHT")
	self.version:SetPoint("TOPRIGHT", title, "TOPRIGHT", 28, 0)
	self.version:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 28, 0)
	self.version:SetJustifyV("MIDDLE")
	local v = Version()
	self.version:SetText(v and ("v" .. v) or "")

	-- the page tabs: text in the header band, resting on its line; the selected one gold with the marker under it
	self.tabs = {}
	local x = 72 -- clear of the portrait ring
	for _, key in ipairs(self.order) do
		local tab = T.BoxTab(f, self.pages[key].label, T.F.large)
		tab:SetHeight(TAB_H)
		tab:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(self.HEADER_LINE - 2 - TAB_H))
		x = x + tab:GetWidth() + 4
		tab:SetScript("OnClick", function() UI:Show(key) end)
		tab.key = key
		tab.baseW = tab:GetWidth()
		-- 1.0: a count beside the label (UI:SetTabBadge), e.g. the Tree's unspent points
		tab.badge = T.Text(tab, T.F.name, C.warn, "LEFT")
		tab.badge:SetPoint("LEFT", tab.Label, "RIGHT", 6, 0)
		self.tabs[key] = tab
	end
	local opts = T.BoxTab(f, ns.L["Options"], T.F.large)
	opts:SetHeight(TAB_H)
	opts:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -(self.HEADER_LINE - 2 - TAB_H))
	opts:SetScript("OnClick", function() UI:Show("options") end)
	opts.key = "options"
	self.tabs.options = opts
	-- 1.1 (the user: juice, in WoW's look): one gold marker glides from tab to tab; hovering a tab shows a faint
	-- line under it; a pressed label dips a pixel, as Blizzard's buttons do
	self.marker = f:CreateTexture(nil, "OVERLAY")
	self.marker:SetColorTexture(T.unpack(C.accent))
	self.marker:SetHeight(2)
	self.marker:Hide()
	self.markerDriver = CreateFrame("Frame", nil, f)
	for _, tab in pairs(self.tabs) do
		tab.glow:SetAlpha(0) -- the shared marker shows the active tab
		tab.peek = tab:CreateTexture(nil, "ARTWORK")
		tab.peek:SetColorTexture(T.unpack(C.accent, 0.35))
		tab.peek:SetHeight(1)
		tab.peek:SetPoint("BOTTOMLEFT", 12, 0)
		tab.peek:SetPoint("BOTTOMRIGHT", -12, 0)
		tab.peek:Hide()
		tab:HookScript("OnEnter", function(self) self.peek:SetShown(not self.active) end)
		tab:HookScript("OnLeave", function(self) self.peek:Hide() end)
		tab:HookScript("OnMouseDown", function(self) self.Label:SetPoint("CENTER", 0, -1) end)
		tab:HookScript("OnMouseUp", function(self) self.Label:SetPoint("CENTER", 0, 0) end)
	end

	for key in pairs(self.pages) do
		local page = CreateFrame("Frame", nil, f)
		page:SetPoint("TOPLEFT", 14, -self.PAGE_TOP)
		page:SetSize(self.CONTENT_W, self.CONTENT_H)
		page:Hide()
		self.pages[key].frame = page
		self.pages[key].build(page)
	end

	self.frame = f
	f:Hide()
	self:ApplySettings()
	return f
end

function UI:ApplySettings()
	if not self.frame then return end
	local scale = tonumber(ns.Core:Setting("scale")) or 1
	self.frame:SetScale(math.max(0.5, math.min(1.5, scale)))
	T.SetBarFill() -- 1.1: the bars repaint when the fill setting changes
	self:Refresh()
end

function UI:Show(key)
	self:Create()
	local db = ns.Core.db
	key = self.pages[key] and key or (db and db.ui.tab) or "overview"
	if not self.pages[key] then key = self.order[1] end
	local changed = self.current ~= key or not self.frame:IsShown()
	if self.frame:IsShown() and self.current and self.current ~= key then UI.Sound("tab") end
	if self.current and self.current ~= key and not self.pages[self.current].untabbed then self.previous = self.current end
	self.current = key
	if db and not self.pages[key].untabbed then db.ui.tab = key end
	-- drawers and open lists belong to the page that opened them
	if ns.Character and self.current ~= "roster" then ns.Character:Close() end
	T.CloseDropdowns()
	for k, p in pairs(self.pages) do
		p.frame:SetShown(k == key)
		if self.tabs[k] then
			self.tabs[k]:SetActive(k == key)
			self.tabs[k].peek:Hide()
		end
	end
	self:PlaceMarker(key, changed and self.frame:IsShown())
	self.title:SetText(string.format(ns.L["Your Legacy: %s"], key == "options" and ns.L["Options"] or self.pages[key].label))
	self.frame:Show()
	self:Refresh()
	if changed then T.Reveal(self.pages[key].frame, T.DUR_MICRO) end -- a tab change crossfades, nothing moves
end

-- The gold marker under the active tab. animate: glide there from where it is (0.2s, easing out), else jump.
local MARKER_TIME = 0.2
function UI:PlaceMarker(key, animate)
	local tab, f, m = self.tabs[key], self.frame, self.marker
	if not (tab and m) then return end
	local function Snap()
		self.markerDriver:SetScript("OnUpdate", nil)
		m:ClearAllPoints()
		m:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 12, 0)
		m:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -12, 0)
		m:Show()
	end
	local fl, tl, tr, mb = f:GetLeft(), tab:GetLeft(), tab:GetRight(), tab:GetBottom()
	local ml, mr = m:IsShown() and m:GetLeft(), m:IsShown() and m:GetRight()
	if not (animate and T.Animated() and fl and tl and tr and mb and ml and mr) then return Snap() end
	local fromL, fromR = ml - fl, mr - fl
	local toL, toR = tl - fl + 12, tr - fl - 12
	local bottom = mb - f:GetBottom()
	local t0 = GetTime()
	self.markerDriver:SetScript("OnUpdate", function()
		local p = math.min(1, (GetTime() - t0) / MARKER_TIME)
		local e = 1 - (1 - p) * (1 - p) * (1 - p)
		if p >= 1 then return Snap() end
		m:ClearAllPoints()
		m:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", fromL + (toL - fromL) * e, bottom)
		m:SetWidth(math.max(1, (fromR - fromL) + ((toR - toL) - (fromR - fromL)) * e))
	end)
end

function UI:ShowOptions() self:Show("options") end

function UI:Toggle(key)
	self:Create()
	if self.frame:IsShown() and (not key or key == self.current) then
		self.frame:Hide()
	else
		self:Show(key)
	end
end

-- A count beside a page tab's label ("" or nil clears it); the tabs after it move along.
function UI:SetTabBadge(key, text)
	local tab = self.tabs and self.tabs[key]
	if not (tab and tab.badge) or (tab.badge:GetText() or "") == (text or "") then return end
	tab.badge:SetText(text or "")
	local x = 72
	for _, k in ipairs(self.order) do
		local t = self.tabs[k]
		local extra = (t.badge:GetText() or "") ~= "" and (t.badge:GetStringWidth() + 6) or 0
		t:SetWidth(t.baseW + extra)
		t:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -(self.HEADER_LINE - 2 - TAB_H))
		x = x + t:GetWidth() + 4
	end
end

function UI:Refresh()
	if not (self.frame and self.frame:IsShown() and self.current) then return end
	local page = self.pages[self.current]
	if page.refresh then page.refresh(page.frame) end
	if ns.Character then ns.Character:Refresh() end
	-- 1.0: unspent Legacy points on the Tree tab (the reminder setting turns it off with the chat line)
	local unspent = ns.Core:Setting("remindUnspent") and ns.Core:Unspent() or 0
	self:SetTabBadge("tree", unspent > 0 and tostring(unspent) or "")
end
