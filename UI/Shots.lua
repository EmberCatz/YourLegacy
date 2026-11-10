-- Troubleshooting (0.9.1): Options > Data > "Screenshot every page", or /yl shots. Walks every page, Challenges
-- tab, Roster panel and options section, takes a game screenshot of each (the client's Screenshots folder) and
-- records the window's layout as the client measured it: every visible text with its real width and whether it was
-- cut off, every texture and atlas. Saved under YourLegacyDB.shots on /reload; ../devenv/shots.py pairs the files
-- with the pages and crops them to the window. Everything the run changes (tab, section, filter, animations, docked
-- panel) is put back afterwards.
local _, ns = ...
local UI, L, Live, Data = ns.UI, ns.L, ns.Live, ns.Data

local Shots = {}
ns.Shots = Shots

local SETTLE = 0.5     -- seconds after a page change before the shot (animations are off during the run)
local GAP = 1.1        -- between shots: the client names screenshot files by the second
local TIMEOUT = 4      -- give up waiting for SCREENSHOT_SUCCEEDED / _FAILED
local MAX_ITEMS = 3000 -- layout entries per page
local MAX_SCROLLS = 4  -- extra shots further down a long page
local TEXT_MAX = 80    -- characters of text kept per entry

local function db() return ns.Core.db end
local function round(v) return v and math.floor(v * 10 + 0.5) / 10 or 0 end

---------------------------------------------------------------- the steps
-- Each step opens one view. Built when the run starts, so the Challenges tabs and the Roster match the account.
local function Steps()
	local steps = {}
	local function add(key, label, enter) steps[#steps + 1] = { key = key, label = label, enter = enter } end
	local function page(key) return function() ns.Character:Close() UI:Show(key) end end

	add("overview", L["Overview"], page("overview"))
	add("challenges", L["Challenges"], function() ns.Character:Close() UI:ShowSection("") end)
	for i, g in ipairs(Live.Challenges().groups) do
		add("challenges-" .. i, L["Challenges"] .. ": " .. g.title, function() UI:ShowSection(g.title) end)
	end
	add("roster", L["Roster"], page("roster"))
	local me = Live.CharacterKey()
	if db().characters[me] then
		add("roster-character", L["Roster"] .. ": " .. me, function()
			UI:Show("roster")
			ns.Character:Close()
			ns.Character:Toggle(me)
		end)
	end
	local started = {}
	for _, ch in pairs(db().characters) do if ch.class then started[ch.class] = true end end
	for _, token in ipairs(Data.CLASS_ORDER) do
		if not started[token] then
			add("roster-plan", L["Roster"] .. ": " .. (Live.ClassName(token) or token), function()
				UI:Show("roster")
				ns.Character:Close()
				ns.Character:TogglePlan(token)
			end)
			break
		end
	end
	add("tree", L["Legacy Tree"], page("tree"))
	for _, sec in ipairs(ns.Settings.SECTIONS) do
		add("options-" .. sec.key, L["Options"] .. ": " .. sec.label, function()
			ns.Character:Close()
			UI:Show("options")
			ns.Settings:ShowSection(sec.key)
		end)
	end
	return steps
end

---------------------------------------------------------------- layout
-- Positions are in the window's own units from its top-left corner, whatever scale a region has.
local function Walk(frame, origin, items)
	local ox, oy, os = origin.left, origin.top, origin.scale
	local function rect(r)
		local left, top = r:GetLeft(), r:GetTop()
		if not (left and top) then return nil end
		local s = r:GetEffectiveScale()
		return round((left * s - ox * os) / os), round((oy * os - top * s) / os), round(r:GetWidth() * s / os), round(r:GetHeight() * s / os)
	end
	for _, r in ipairs({ frame:GetRegions() }) do
		if #items >= MAX_ITEMS then return end
		if r:IsVisible() and (r:GetAlpha() or 1) > 0 then
			local x, y, w, h = rect(r)
			local kind = r:GetObjectType()
			if x and kind == "FontString" then
				local text = r:GetText()
				if text and text ~= "" then
					text = text:gsub("|", "/"):gsub("\n", " ")
					items[#items + 1] = table.concat({ "T", x, y, w, h, round(r:GetUnboundedStringWidth()),
						r:IsTruncated() and 1 or 0, text:sub(1, TEXT_MAX) }, "|")
				end
			elseif x and kind == "Texture" then
				local art = r:GetAtlas() or r:GetTexture()
				if art then items[#items + 1] = table.concat({ "X", x, y, w, h, tostring(art) }, "|") end
			end
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if #items >= MAX_ITEMS then return end
		if child:IsVisible() then Walk(child, origin, items) end
	end
end

local function Layout()
	local f = UI.frame
	local origin = { left = f:GetLeft() or 0, top = f:GetTop() or 0, scale = f:GetEffectiveScale() }
	local items = {}
	Walk(f, origin, items)
	return items
end

-- The page's main scroll area: the biggest visible ScrollFrame that has something below the fold.
local function MainScroll()
	local best, bestArea
	local function find(frame)
		for _, child in ipairs({ frame:GetChildren() }) do
			if child:IsVisible() then
				if child:GetObjectType() == "ScrollFrame" and child:GetVerticalScrollRange() > 1 then
					local area = child:GetWidth() * child:GetHeight()
					if not best or area > bestArea then best, bestArea = child, area end
				end
				find(child)
			end
		end
	end
	find(UI.frame)
	return best
end

-- Scrolls the way the mouse wheel does (UI.Scroll), so the thumb moves too. Animations are off: it jumps.
local function ScrollBy(scroll, pixels)
	local wheel = scroll:GetScript("OnMouseWheel")
	if wheel then wheel(scroll, -pixels / 48) else scroll:SetVerticalScroll(scroll:GetVerticalScroll() + pixels) end
end

---------------------------------------------------------------- the run
local events = CreateFrame("Frame")
local run

local function Finish(reason)
	if not run then return end
	local r = run
	run = nil
	events:UnregisterAllEvents()
	local settings, ui = db().settings, db().ui
	settings.animations = r.saved.animations
	ui.status, ui.section, ui.tab = r.saved.status, r.saved.section, r.saved.tab
	if UI.frame and UI.frame:IsShown() then
		ns.Character:Close()
		UI:Show(r.saved.view)
		if r.saved.view == "options" then ns.Settings:ShowSection(r.saved.optionsSection) end
		if r.saved.character then ns.Character:Toggle(r.saved.character) end
		if r.saved.plan then ns.Character:TogglePlan(r.saved.plan) end
	end
	local taken = 0
	for _, s in ipairs(r.out.shots) do if s.ok then taken = taken + 1 end end
	r.out.finished = date("%Y-%m-%d %H:%M:%S")
	r.out.stopped = reason
	if reason == "combat" then
		ns.Core:Print(string.format(L["screenshots stopped when combat started. %d taken."], taken))
	elseif reason == "closed" then
		ns.Core:Print(string.format(L["screenshots stopped because the window closed. %d taken."], taken))
	elseif reason then
		ns.Core:Print(string.format(L["screenshots stopped. %d taken."], taken))
	else
		ns.Core:Print(string.format(L["%d screenshots taken. Type /reload to save the layout that goes with them."], taken))
	end
	if ns.Settings and ns.Settings.Refresh then ns.Settings:Refresh() end
end

-- Takes one screenshot, waits for the client to confirm it, then calls done(ok).
local function Shoot(entry, done)
	entry.time, entry.stamp = time(), date("%m%d%y_%H%M%S")
	local token = {}
	run.waiting = token
	events:RegisterEvent("SCREENSHOT_SUCCEEDED")
	events:RegisterEvent("SCREENSHOT_FAILED")
	events.done = function(ok)
		if run and run.waiting == token then
			run.waiting = nil
			events:UnregisterEvent("SCREENSHOT_SUCCEEDED")
			events:UnregisterEvent("SCREENSHOT_FAILED")
			entry.ok = ok
			C_Timer.After(GAP, function() if run then done(ok) end end)
		end
	end
	Live.Screenshot()
	-- only this shot's own wait: a stale timeout used to fail whichever later shot was waiting (found in 1.1, once
	-- the simulator ran time frame by frame)
	C_Timer.After(TIMEOUT, function() if run and run.waiting == token and events.done then events.done(false) end end)
end

events:SetScript("OnEvent", function(self, event)
	if self.done then self.done(event == "SCREENSHOT_SUCCEEDED") end
end)

local function Interrupted()
	if InCombatLockdown() then return "combat" end
	if not (UI.frame and UI.frame:IsShown()) then return "closed" end
end

-- Shoots step i, then the same view further down while there's more to see.
local function Next(i)
	if not run then return end
	local why = Interrupted()
	if why then return Finish(why) end
	local step = run.steps[i]
	if not step then return Finish() end
	step.enter()
	C_Timer.After(SETTLE, function()
		if not run then return end
		why = Interrupted()
		if why then return Finish(why) end
		local scroll = MainScroll()
		if scroll and scroll:GetVerticalScroll() > 0 then ScrollBy(scroll, -scroll:GetVerticalScroll()) end
		local entry = { n = #run.out.shots + 1, key = step.key, label = step.label, items = Layout() }
		run.out.shots[#run.out.shots + 1] = entry
		local extra = 0
		local function More()
			if not run then return end
			why = Interrupted()
			if why then return Finish(why) end
			if scroll and extra < MAX_SCROLLS and scroll:GetVerticalScroll() < scroll:GetVerticalScrollRange() - 1 then
				extra = extra + 1
				ScrollBy(scroll, scroll:GetHeight() * 0.85)
				C_Timer.After(SETTLE, function()
					if not run then return end
					local more = { n = #run.out.shots + 1, key = step.key, label = step.label, scrolled = round(scroll:GetVerticalScroll()) }
					run.out.shots[#run.out.shots + 1] = more
					Shoot(more, More)
				end)
			else
				Next(i + 1)
			end
		end
		Shoot(entry, More)
	end)
end

function Shots:Running() return run ~= nil end

function Shots:Start()
	if run then return Finish("stopped") end
	if InCombatLockdown() then
		ns.Core:Print(L["can't take screenshots in combat."])
		return
	end
	local settings, ui = db().settings, db().ui
	UI:Show(UI.current or "overview")
	local saved = {
		animations = settings.animations, status = ui.status, section = ui.section, tab = ui.tab,
		view = UI.current, optionsSection = ns.Settings:Section(),
		character = ns.Character:Shown(), plan = ns.Character:PlanShown(),
	}
	settings.animations = false -- no fades caught half-way
	ui.status = "all"          -- every challenge in the section tabs, done or not
	local f = UI.frame
	local physW, physH = GetPhysicalScreenSize()
	run = {
		saved = saved,
		steps = Steps(),
		out = {
			started = date("%Y-%m-%d %H:%M:%S"), version = UI.Version(), locale = GetLocale(),
			theme = settings.theme, character = Live.CharacterKey(),
			screen = { w = round(GetScreenWidth()), h = round(GetScreenHeight()), physW = physW, physH = physH,
				uiScale = UIParent:GetEffectiveScale() },
			frame = { left = round(f:GetLeft()), top = round(f:GetTop()), w = round(f:GetWidth()), h = round(f:GetHeight()),
				scale = f:GetEffectiveScale() },
			shots = {},
		},
	}
	db().shots = run.out
	ns.Core:Print(string.format(L["taking screenshots of %d pages. Leave the window open; Escape stops it."], #run.steps))
	Next(1)
end
