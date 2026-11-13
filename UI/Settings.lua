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

-- 1.0 (the user's ask): grouped by what an option touches, not by when it was added. Window = the Your Legacy
-- window itself; Chat and sound = everything it says or plays; Maps = the world map and the minimap.
local SECTIONS = {
	{ key = "window", label = L["Window"], glyph = "Star" },
	{ key = "chat", label = L["Chat and sound"], glyph = "Crown" },
	{ key = "maps", label = L["Maps"], glyph = "Map" },
	{ key = "rules", label = L["How Legacy works"], glyph = "Shield" },
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
	r.desc:SetWordWrap(true)
	r.desc:SetText(desc or "")
	-- a description too long for one line (often a translation) wraps, and the row grows with it
	local descH = r.desc:GetStringHeight()
	r.desc:SetHeight(descH)
	r:SetHeight(math.max(height or 54, 10 + 14 + 4 + descH + 10))
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

-- A small gold heading over a group of rows inside a section (laid out like a row, without a background).
local function Heading(parent, text)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(ROW_W, 26)
	h.text = T.Text(h, T.F.label, C.head)
	h.text:SetPoint("BOTTOMLEFT", 4, 4)
	h.text:SetText(text)
	h.heading = true
	return h
end

local function SwitchRow(body, rows, label, desc, key)
	local r = Row(body, label, desc)
	r.switch = Switch(r, key)
	rows[#rows + 1] = r
	return r
end

-- The Your Legacy window itself.
function Builders.window(body)
	local rows = {}
	local size = Row(body, L["Window size"], L["From 80 to 150%, on top of your UI scale."])
	size.value = T.Text(size, T.F.name, C.ink, "RIGHT")
	size.slider = T.Slider(size, 200, SCALE_MIN, SCALE_MAX, SCALE_STEP,
		function(v) size.value:SetText(v .. "%") end,
		function(v) Set("scale", v / 100) end)
	size.slider:SetPoint("TOPRIGHT", size, "TOPRIGHT", -70, -18)
	size.value:SetPoint("LEFT", size.slider.forward, "RIGHT", 10, 0)
	rows[#rows + 1] = size
	-- 1.1: the fill of every progress bar, from the profession rank bars this client has (Theme.BAR_FILLS)
	local fill = Row(body, L["Bar fill"], L["The texture inside the progress bars: the points bar, the Challenges footer and the world map banner. Each one is a profession's rank bar from the game."])
	fill.fill = Control(fill, T.Dropdown(fill, 150, T.BarFillOptions, function(kit) Set("barFill", kit) end), -17)
	fill.barFill = true
	rows[#rows + 1] = fill
	SwitchRow(body, rows, L["Lock window position"], L["Stop the window from being dragged."], "locked")
	SwitchRow(body, rows, L["Close in combat"], L["Close the window when combat starts. It doesn't update during combat either way."], "combatHide")
	SwitchRow(body, rows, L["Animations"], L["Short fades when you open the window, switch tabs or pick an option. Turn it off for a still window."], "animations")
	SwitchRow(body, rows, L["Legacy window at 0 points"], L["Let the game's Legacy key and menu button open Blizzard's Legacy window before you have a point. The game keeps it locked until then."], "unlockLegacy")
	return rows
end

-- Everything Your Legacy says in chat or plays, grouped by when it happens.
function Builders.chat(body)
	local rows = {}
	rows[#rows + 1] = Heading(body, L["When you earn a challenge"])
	SwitchRow(body, rows, L["Announce earned challenges"], L["Print a chat line when you earn a Legacy challenge."], "announce")
	SwitchRow(body, rows, L["Announce in guild chat"], L["Also post earned challenges to your guild, as a link they can click."], "announceGuild")
	SwitchRow(body, rows, L["Say who can spend a new point"], L["When the account earns a Legacy point, list the characters that can still spend one."], "announceNewPoint")
	local r = Row(body, L["Sound for earned challenges"], L["Plays a sound from the game when you earn a Legacy challenge."], 54)
	r.switch = Switch(r, "sound")
	r.sound = T.Dropdown(r, 150, function()
		local out = {}
		for _, snd in ipairs(ns.Data.SOUNDS) do out[#out + 1] = { snd.key, L[snd.name] } end
		return out
	end, function(key)
		Set("soundKey", key)
		for _, snd in ipairs(ns.Data.SOUNDS) do if snd.key == key then ns.Live.PlaySound(snd.id) end end
	end)
	-- from the switch leftward, so a longer "Play" (German "Abspielen") pushes the dropdown, not into the switch
	r.play = T.TextButton(r, L["Play"])
	r.play:SetPoint("RIGHT", r.switch, "LEFT", -16, 0)
	r.sound:SetPoint("RIGHT", r.play, "LEFT", -16, 0)
	r.play:SetScript("OnClick", function()
		for _, snd in ipairs(ns.Data.SOUNDS) do if snd.key == S("soundKey") then ns.Live.PlaySound(snd.id) end end
	end)
	rows[#rows + 1] = r
	rows[#rows + 1] = Heading(body, L["At login"])
	SwitchRow(body, rows, L["Remind me of unspent points"], L["A chat line at login when you have Legacy points left to spend."], "remindUnspent")
	SwitchRow(body, rows, L["Remind me of rewards to collect"], L["A chat line at login when a reward waits for you at Innkeeper Wiley in Ratchet."], "remindRewards")
	rows[#rows + 1] = Heading(body, L["In dungeons and raids"])
	SwitchRow(body, rows, L["Dungeon and raid help"], L["In a dungeon or raid, say which challenge it counts for and what's left."], "instanceHelper")
	return rows
end

-- The world map (zone progress, its button) and the minimap button.
function Builders.maps(body)
	local rows = {}
	rows[#rows + 1] = Heading(body, L["World map"])
	-- next to Legacy Forever (which shows zone progress itself) the box is a separate choice, off by default
	if ns.Live.AddOnLoaded(ns.MapZone.LEGACY_FOREVER) then
		SwitchRow(body, rows, L["Zone progress on the world map"], L["Off by default while Legacy Forever is loaded, since it shows zone progress too."], "mapZoneWithLegacyForever")
	else
		SwitchRow(body, rows, L["Zone progress on the world map"], L["Shows the Legacy progress of the zone you open on the world map."], "mapZone")
	end
	SwitchRow(body, rows, L["World map button"], L["A button on the world map with Your Legacy's map options."], "mapButton")
	rows[#rows + 1] = Heading(body, L["Minimap"])
	SwitchRow(body, rows, L["Minimap button"], L["Show the Your Legacy button on the minimap. The AddOns compartment button is always there."], "minimap")
	local r = Row(body, L["Button position"], "", 54)
	r.reset = Control(r, T.ActionButton(r, L["Reset position"]))
	r.reset:SetScript("OnClick", function() if ns.Minimap then ns.Minimap:ResetPosition() end end)
	r.minimapInfo = true
	rows[#rows + 1] = r
	return rows
end

-- 1.0: the rules the ledger relies on (Data.RULES), each with how sure we are: a line per rule, its source under
-- it, the status on the right. Confirmed in the done colour, reported in gold, unchecked in amber.
local STATUS = {
	confirmed = { L["Confirmed"], C.teal }, reported = { L["Reported"], C.head }, unchecked = { L["Unchecked"], C.warn },
}
function Builders.rules(body)
	local rows = {}
	for _, rule in ipairs(ns.Data.RULES) do
		local r = Row(body, L[rule.text], L[rule.source])
		r.label:SetWidth(ROW_W - 150)
		r.label:SetWordWrap(true)
		r.label:SetJustifyV("TOP") -- a longer translation wraps downward, and the row grows with it
		r:SetHeight(math.max(54, 10 + r.label:GetStringHeight() + 4 + 14 + 10))
		local s = STATUS[rule.status] or STATUS.unchecked
		r.status = Control(r, T.Text(r, T.F.name, s[2], "RIGHT"), -12)
		r.status:SetText(s[1])
		r.rule = rule.key
		rows[#rows + 1] = r
	end
	local help = T.Text(body, T.F.small, C.muted)
	help:SetWidth(ROW_W)
	help:SetText(string.format(L["As of %s. Confirmed: the game or Blizzard shows it. Reported: guides and players say so, but nobody has proven it in game. Unchecked: nobody has tested it yet."], ns.Data.RULES_DATE))
	rows.footer = help
	return rows
end

-- A GitHub-style danger zone: a red heading, then the rows that delete or poke at things in a red-edged box.
-- Settings_:Refresh draws the box around the rows marked danger.
local function DangerHeading(parent)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(ROW_W, 34)
	h.text = T.Text(h, T.F.mid, C.bad)
	h.text:SetPoint("BOTTOMLEFT", 2, 8)
	h.text:SetText(L["Danger zone"])
	h.heading = true
	return h
end

-- Red button text. UIPanelButtonTemplate swaps font objects on hover and enable, which would undo a plain
-- SetTextColor, so the red is a font object of its own (Blizzard's button font, recoloured) for normal and hover.
local dangerFont
local function DangerButton(row, label)
	local b = Control(row, T.ActionButton(row, label, true))
	if not dangerFont then
		dangerFont = CreateFont("YourLegacyFontDanger")
		dangerFont:CopyFontObject(GameFontNormal or "GameFontNormal")
		dangerFont:SetTextColor(T.unpack(C.bad))
	end
	b:SetNormalFontObject(dangerFont)
	b:SetHighlightFontObject(dangerFont)
	return b
end

function Builders.data(body)
	local rows = {}
	local r = Row(body, L["Export"], L["Shows Your Legacy's data as text you can copy and keep as a backup."])
	r.button = Control(r, T.ActionButton(r, L["Export"]))
	r.button:SetScript("OnClick", function() if ns.Export then ns.Export:Show() end end)
	rows[#rows + 1] = r
	r = Row(body, L["Report a problem"], L["Shows a report to copy into a bug report: versions, settings and what the game says about your Legacy progress. Type /yl report and a challenge's name for its parts."])
	r.button = Control(r, T.ActionButton(r, L["Report"]))
	r.button:SetScript("OnClick", function() if ns.Report then ns.Report:Show("") end end)
	rows[#rows + 1] = r
	r = Row(body, L["Run the probe"], L["Checks what Your Legacy relies on in this client and lists what still needs a look in game. Type /reload afterwards to save the results."])
	r.button = Control(r, T.ActionButton(r, L["Probe"]))
	r.button:SetScript("OnClick", function() if ns.Probe then ns.Probe:Run() end end)
	rows[#rows + 1] = r
	r = Row(body, L["Capture game state"], L["Records what the game reports to Your Legacy, for bug reports. Type /reload afterwards to save it."])
	r.button = Control(r, T.ActionButton(r, L["Capture"]))
	r.button:SetScript("OnClick", function() ns.Core:Capture() end)
	rows[#rows + 1] = r
	rows[#rows + 1] = DangerHeading(body)
	r = Row(body, L["Delete saved data"], L["Starts Your Legacy over. Your Legacy progress in the game isn't touched."])
	r.button = DangerButton(r, L["Delete"])
	r.button:SetScript("OnClick", function() StaticPopup_Show("YOURLEGACY_RESET") end)
	r.danger = true
	rows[#rows + 1] = r
	-- 0.9.1: the developer row. Its tools stay greyed out until the switch unlocks them.
	r = Row(body, L["Developer tools"], L["Turns on the tools below, for tracking down layout bugs."])
	r.switch = Switch(r, "devTools")
	r.danger = true
	rows[#rows + 1] = r
	-- 1.1: fake progress for looking at bars and buttons part-way and full (Live.demo, never saved)
	r = Row(body, L["Debug fill"], L["Shows made-up progress everywhere so you can check how bars, checks and buttons look part-way and full. Your real data isn't changed, and it turns off on /reload."])
	r.fill = Control(r, T.Dropdown(r, 130, function()
		return {
			{ "off", L["Off"] }, { "0", "0%" }, { "25", "25%" }, { "50", "50%" }, { "75", "75%" }, { "100", "100%" },
			{ "mixed", L["Mixed"] },
		}
	end, function(key)
		if not S("devTools") then return end
		-- not "key == 'off' and nil or ...": nil is falsy, so that picked 0% for Off (the user's bug, 2026-11-10)
		local value
		if key == "mixed" then value = "mixed" elseif key ~= "off" then value = (tonumber(key) or 0) / 100 end
		ns.Live.SetDemo(value)
		ns.Core:Print(key == "off" and L["Debug fill is off. Real progress again."] or L["Debug fill is on. Nothing you see now is real progress."])
		ns.Core:RequestRefresh()
	end), -17)
	r.devFill = true
	r.danger = true
	rows[#rows + 1] = r
	r = Row(body, L["Screenshot every page"], L["Screenshots every page and tab, for bug reports. Type /reload afterwards to save the layout."])
	r.button = DangerButton(r, L["Take screenshots"])
	r.button:SetScript("OnClick", function() if S("devTools") then ns.Shots:Start() end end)
	r.shots = true
	r.danger = true
	rows[#rows + 1] = r
	-- the red edge around the danger rows, behind them
	rows.dangerBox = CreateFrame("Frame", nil, body)
	T.Border(rows.dangerBox, C.bad, 0.7)
	local help = T.Text(body, T.F.small, C.muted)
	help:SetWidth(ROW_W)
	help:SetText(L["Slash commands: /yl opens the window, /yl options this page, /yl status prints your points, /yl here says what the dungeon or zone you are in still holds, /yl report makes a bug report."])
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
	page.section = "window"
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
	if r.barFill then r.fill:SetValue(S("barFill")) end
	if r.devFill then
		local unlocked = S("devTools") and true or false
		local d = ns.Live.demo
		r.fill:SetValue(d == nil and "off" or d == "mixed" and "mixed" or tostring(math.floor(d * 100 + 0.5)))
		r.fill:SetEnabled(unlocked)
		r.label:SetAlpha(unlocked and 1 or 0.45)
		r.desc:SetAlpha(unlocked and 1 or 0.45)
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
	local dangerTop, dangerBottom
	for _, r in ipairs(holder.rows) do
		RefreshRow(r)
		-- rows inside the danger box sit 8px in from its edge
		local inset = r.danger and 8 or 0
		if r.danger and not dangerTop then dangerTop = y y = y + 8 end
		if not r.danger and dangerTop and not dangerBottom then dangerBottom = y y = y + 8 end
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -y)
		if r.danger then r:SetWidth(ROW_W - 2 * inset) end
		y = y + r:GetHeight() + 6
	end
	if dangerTop and not dangerBottom then dangerBottom = y + 2 y = y + 10 end
	local box = holder.rows.dangerBox
	if box then
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -dangerTop)
		box:SetPoint("TOPRIGHT", holder, "TOPLEFT", ROW_W, -dangerTop)
		box:SetHeight(dangerBottom - dangerTop)
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
