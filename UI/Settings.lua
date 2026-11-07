-- In-addon options (0.6), opened by the gear button, /yl options, the minimap button's right-click or the
-- AddOns compartment. A section list on the left, rows on the right: a label, one line saying what it does, and the
-- control. Blizzard's Settings panel keeps the basic switches (UI/Options.lua) and a pointer here.
local _, ns = ...
local T, UI, L = ns.Theme, ns.UI, ns.L
local C = T.C

local Settings_ = {}
ns.Settings = Settings_

local function db() return ns.Core.db end
local function S(key) return ns.Core:Setting(key) end
local function Set(key, value)
	ns.Core:SetSetting(key, value)
	UI:Refresh()
end

local W, H = UI.CONTENT_W, UI.CONTENT_H
local NAV_W, GAP = 200, 12
local BODY_W = W - NAV_W - GAP
local ROW_W = BODY_W - 28 - 14

local SECTIONS = {
	{ key = "general", label = L["General"], glyph = "Star" },
	{ key = "minimap", label = L["Minimap"], glyph = "Map" },
	{ key = "data", label = L["Data"], glyph = "Lock" },
}
Settings_.SECTIONS = SECTIONS -- UI/Shots.lua walks them

StaticPopupDialogs.YOURLEGACY_RESET = {
	text = L["Delete everything Your Legacy has saved? Plans, notes, snapshots of your other characters and these options are gone afterwards."],
	button1 = YES, button2 = NO,
	OnAccept = function() ns.Core:ResetAll() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}
-- One option: label + description on the left, control on the right. height grows for tall controls.
local function Row(parent, label, desc, height)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(ROW_W, height or 54)
	T.RowBackground(r)
	r.label = T.Text(r, T.F.name, C.ink)
	r.label:SetPoint("TOPLEFT", 12, -10)
	r.label:SetText(label)
	r.desc = T.Text(r, T.F.small, C.muted)
	r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -4)
	r.desc:SetWidth(ROW_W - 300)
	r.desc:SetJustifyV("TOP")
	r.desc:SetText(desc or "")
	return r
end

local function Control(row, control, y)
	control:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, y or -14)
	row.control = control
	return control
end

-- The scale as a percentage, 80 to 150 in steps of 5.
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 80, 150, 5

local function Switch(row, key)
	local sw = Control(row, T.Switch(row, function(v) Set(key, v) end), -17)
	sw.key = key
	return sw
end

---------------------------------------------------------------- sections
local Builders = {}

function Builders.general(body)
	local rows = {}
	local size = Row(body, L["Window size"], L["From 80 to 150%, on top of your UI scale."])
	size.value = T.Text(size, T.F.name, C.ink, "RIGHT")
	size.slider = T.Slider(size, 200, SCALE_MIN, SCALE_MAX, SCALE_STEP,
		function(v) size.value:SetText(v .. "%") end,
		function(v) Set("scale", v / 100) end)
	size.slider:SetPoint("TOPRIGHT", size, "TOPRIGHT", -70, -18)
	size.value:SetPoint("LEFT", size.slider.forward, "RIGHT", 10, 0)
	rows[#rows + 1] = size
	local r
	r = Row(body, L["Lock window position"], L["Stop the window from being dragged."])
	r.switch = Switch(r, "locked")
	rows[#rows + 1] = r
	r = Row(body, L["Close in combat"], L["Close the window when combat starts. It doesn't update during combat either way."])
	r.switch = Switch(r, "combatHide")
	rows[#rows + 1] = r
	r = Row(body, L["Announce earned challenges"], L["Print a chat line when you earn a Legacy challenge."])
	r.switch = Switch(r, "announce")
	rows[#rows + 1] = r
	r = Row(body, L["Sound for earned challenges"], L["Plays a sound from the game when you earn a Legacy challenge."], 54)
	r.switch = Switch(r, "sound")
	r.sound = T.Dropdown(r, 150, function()
		local out = {}
		for _, snd in ipairs(ns.Data.SOUNDS) do out[#out + 1] = { snd.key, L[snd.name] } end
		return out
	end, function(key)
		Set("soundKey", key)
		for _, snd in ipairs(ns.Data.SOUNDS) do if snd.key == key then ns.Live.PlaySound(snd.id) end end
	end)
	r.sound:SetPoint("RIGHT", r.switch, "LEFT", -54, 0)
	r.play = T.TextButton(r, L["Play"])
	r.play:SetPoint("LEFT", r.sound, "RIGHT", 8, 0)
	r.play:SetScript("OnClick", function()
		for _, snd in ipairs(ns.Data.SOUNDS) do if snd.key == S("soundKey") then ns.Live.PlaySound(snd.id) end end
	end)
	rows[#rows + 1] = r
	r = Row(body, L["Animations"], L["Short fades when you open the window, switch tabs or pick an option. Turn it off for a still window."])
	r.switch = Switch(r, "animations")
	rows[#rows + 1] = r
	return rows
end

function Builders.minimap(body)
	local rows = {}
	local r = Row(body, L["Minimap button"], L["Show the Your Legacy button on the minimap. The AddOns compartment button is always there."])
	r.switch = Switch(r, "minimap")
	rows[#rows + 1] = r
	r = Row(body, L["Button position"], "", 54)
	r.reset = Control(r, T.ActionButton(r, L["Reset position"]))
	r.reset:SetScript("OnClick", function() if ns.Minimap then ns.Minimap:ResetPosition() end end)
	r.minimapInfo = true
	rows[#rows + 1] = r
	return rows
end

function Builders.data(body)
	local rows = {}
	local r = Row(body, L["Export"], L["Shows Your Legacy's data as text you can copy and keep as a backup."])
	r.button = Control(r, T.ActionButton(r, L["Export"]))
	r.button:SetScript("OnClick", function() if ns.Export then ns.Export:Show() end end)
	rows[#rows + 1] = r
	r = Row(body, L["Capture game state"], L["Records what the game reports to Your Legacy, for bug reports. Type /reload afterwards to save it."])
	r.button = Control(r, T.ActionButton(r, L["Capture"]))
	r.button:SetScript("OnClick", function() ns.Core:Capture() end)
	rows[#rows + 1] = r
	r = Row(body, L["Delete saved data"], L["Starts Your Legacy over. Your Legacy progress in the game isn't touched."])
	r.button = Control(r, T.ActionButton(r, L["Delete"], true))
	r.button:SetScript("OnClick", function() StaticPopup_Show("YOURLEGACY_RESET") end)
	rows[#rows + 1] = r
	-- 0.9.1: the developer row. Its tools stay greyed out until the switch unlocks them.
	r = Row(body, L["Developer tools"], L["Turns on the screenshot tool below, for tracking down layout bugs."])
	r.switch = Switch(r, "devTools")
	rows[#rows + 1] = r
	r = Row(body, L["Screenshot every page"], L["Screenshots every page and tab, for bug reports. Type /reload afterwards to save the layout."])
	r.button = Control(r, T.ActionButton(r, L["Take screenshots"]))
	r.button:SetScript("OnClick", function() if S("devTools") then ns.Shots:Start() end end)
	r.shots = true
	rows[#rows + 1] = r
	local help = T.Text(body, T.F.small, C.muted)
	help:SetWidth(ROW_W)
	help:SetText(L["Slash commands: /yl opens the window, /yl options this page, /yl status prints your points."])
	rows.footer = help
	return rows
end

---------------------------------------------------------------- page
local page = {}

local function Build(frame)
	local nav = T.Panel(frame, L["Options"], NAV_W, H)
	nav:SetPoint("TOPLEFT")
	page.nav = {}
	for i, sec in ipairs(SECTIONS) do
		local b = CreateFrame("Button", nil, nav.body)
		b:SetSize(NAV_W - 28, 34)
		b:SetPoint("TOPLEFT", 0, -(i - 1) * 38)
		T.RowBackground(b)
		-- the current section: a quiet paper3 fill and ink (Hallmark: state is a colour or a soft background)
		b.sel = T.Rounded(b, "Chip", "BORDER", C.paper3)
		b.sel:Hide()
		b.glyph = T.Glyph(b, sec.glyph, 14, C.muted)
		b.glyph:SetPoint("LEFT", 12, 0)
		b.Label = T.Text(b, T.F.name, C.ink2)
		b.Label:SetPoint("LEFT", b.glyph, "RIGHT", 10, 0)
		b.Label:SetText(sec.label)
		b:SetScript("OnClick", function()
			T.CloseDropdowns()
			page.section = sec.key
			Settings_:Refresh()
			T.Reveal(page.body, 0.15)
		end)
		page.nav[sec.key] = b
	end
	-- the version is in the window's title strip on every page (0.9)

	local panel = T.Panel(frame, "", BODY_W, H)
	panel:SetPoint("TOPLEFT", NAV_W + GAP, 0)
	page.panel = panel
	local scroll, child = UI.Scroll(panel.body, BODY_W - 28, H - 58)
	scroll:SetPoint("TOPLEFT")
	page.scroll, page.body = scroll, child
	page.sections = {}
	for _, sec in ipairs(SECTIONS) do
		local holder = CreateFrame("Frame", nil, child)
		holder:SetPoint("TOPLEFT")
		holder:SetSize(ROW_W, 10)
		holder.rows = Builders[sec.key](holder)
		holder:Hide()
		page.sections[sec.key] = holder
	end
	page.section = "general"
end

local function RefreshRow(r)
	if r.switch then r.switch:SetChecked(S(r.switch.key) and true or false) end
	if r.slider then
		local pct = math.floor((tonumber(S("scale")) or 1) * 100 + 0.5)
		r.slider:SetValue(pct)
		r.value:SetText(r.slider.value .. "%")
	end
	if r.sound then r.sound:SetValue(S("soundKey")) end
	if r.minimapInfo then
		r.desc:SetText(ns.Minimap and ns.Minimap:UsesLibrary()
			and L["Uses LibDBIcon from another addon, so minimap button collectors can gather it. Drag it to move it."]
			or L["Drag the button around the minimap to move it."])
	end
	if r.shots then
		local unlocked = S("devTools") and true or false
		r.button:SetText(ns.Shots and ns.Shots:Running() and L["Stop"] or L["Take screenshots"])
		r.button:SetEnabled(unlocked)
		r.label:SetAlpha(unlocked and 1 or 0.45)
		r.desc:SetAlpha(unlocked and 1 or 0.45)
	end
end

function Settings_:Refresh()
	if not page.sections then return end
	for key, b in pairs(page.nav) do
		local on = key == page.section
		b.sel:SetShown(on)
		b.Label:SetTextColor(T.unpack(on and C.ink or C.ink2))
		b.glyph:SetVertexColor(T.unpack(on and C.ink or C.muted))
	end
	local y = 0
	for key, holder in pairs(page.sections) do holder:SetShown(key == page.section) end
	local holder = page.sections[page.section]
	for _, sec in ipairs(SECTIONS) do
		if sec.key == page.section then page.panel.title:SetText(sec.label) end
	end
	for _, r in ipairs(holder.rows) do
		RefreshRow(r)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
		y = y + r:GetHeight() + 6
	end
	if holder.rows.footer then
		holder.rows.footer:ClearAllPoints()
		holder.rows.footer:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -(y + 6))
		y = y + 30
	end
	holder:SetHeight(math.max(10, y))
	page.scroll:SetContentHeight(y)
end

function Settings_:Section() return page.section end

function Settings_:ShowSection(key)
	if not (page.sections and page.sections[key]) then return end
	T.CloseDropdowns()
	page.section = key
	page.scroll:SetVerticalScroll(0)
	self:Refresh()
end

UI:RegisterView("options", Build, function() Settings_:Refresh() end)
