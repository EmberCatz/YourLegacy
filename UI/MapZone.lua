-- 1.0 zone progress on the world map (research/19-feature-plan.md #8, the user's pick after map badges were
-- dropped). A small inset in the map's top-left corner, only on maps with Legacy work: how much of the map this
-- character has explored for the exploration challenge, which other character has it all, and the dungeons and raids
-- whose entrance is on the map, each with what's left or "done". The title counts the goals done.
-- No data provider, no pins, no hooks: EventRegistry's WorldMapOnShow / WorldMapOnHide (Blizzard_WorldMap.lua) start and
-- stop a light ticker that looks for another map while the map is open. In combat the box hides and nothing is built.
local _, ns = ...
local T, Live, L = ns.Theme, ns.Live, ns.L
local C = T.C

local Z = {}
ns.MapZone = Z
Z.TICK = 0.25                     -- seconds between checks while the map is open
Z.WIDTH, Z.ROW, Z.MAX_ROWS = 250, 16, 10
Z.ANCHOR, Z.X, Z.Y = "TOPLEFT", 8, -8 -- inside the map's scroll container (in-game check: clear of Blizzard's overlays)
Z.LEGACY_FOREVER = "LegacyForever" -- cjber's addon shows zone progress too; ours stays off beside it unless chosen

local box, ticker
local shown = {}                 -- what the box shows now: map, challenges (the Live.Challenges table it was built from)
local cache, cacheFor = {}, nil  -- entrance name → matches, for one Live.Challenges() reading

function Z.Enabled()
	local db = ns.Core.db
	if not db then return false end
	if Live.AddOnLoaded(Z.LEGACY_FOREVER) then return db.settings.mapZoneWithLegacyForever == true end
	return db.settings.mapZone == true
end

local function Matches(entrance)
	local challenges = Live.Challenges()
	if cacheFor ~= challenges then cache, cacheFor = {}, challenges end
	local key = entrance.kind .. ":" .. entrance.name
	if not cache[key] then cache[key] = Live.InstanceChallenges(entrance.name, entrance.kind) end
	return cache[key]
end

-- Another saved character that has explored all of this map (roster snapshots keep the zones each one finished).
local function ExploredBy(progress)
	local me = Live.CharacterKey()
	for key, ch in pairs(ns.Core.db.characters) do
		if key ~= me and ch.exploreID == progress.explorerID and type(ch.explore) == "table"
			and (ch.explore[progress.key] or ch.explore[tostring(progress.key)]) then
			return ch.name
		end
	end
end

-- The box's lines for a map: { { text, colour } }, goals done, goals in all. Nothing when the map has no Legacy work.
function Z.Lines(mapID)
	local lines, done, goals = {}, 0, 0
	local name = Live.MapName(mapID)
	local explore = Live.ExploreProgress(name)
	if explore then
		goals = goals + 1
		local complete = explore.done >= explore.total
		local other = not complete and ExploredBy(explore)
		if complete or other then done = done + 1 end
		local fmt = explore.nested and L["%s: %d of %d zones explored"] or L["%s: %d of %d areas explored"]
		lines[#lines + 1] = { string.format(fmt, Live.PlayerName(), explore.done, explore.total), complete and C.teal or C.white }
		if other then lines[#lines + 1] = { string.format(L["%s has explored all of it."], other), C.teal } end
	end
	local seen = {}
	for _, e in ipairs(Live.DungeonEntrances(mapID)) do
		for _, m in ipairs(Matches(e)) do
			if not seen[m.item.id .. ":" .. e.name] then
				seen[m.item.id .. ":" .. e.name] = true
				goals = goals + 1
				local missing, left, total = ns.Instance.Missing(m)
				local text, colour
				if m.item.completed or (not m.whole and #missing == 0) or (m.whole and left == 0) then
					text, colour, done = string.format(L["%s: done"], e.name), C.teal, done + 1
				elseif m.whole and total > 1 then
					text, colour = string.format(L["%s: %d of %d bosses left"], e.name, left, total), C.white
				elseif m.whole then
					text, colour = string.format(L["%s: not done yet"], e.name), C.white
				elseif #m.parts > 1 then
					text, colour = string.format(L["%s: %d wings left"], e.name, #missing), C.white
				else
					text, colour = string.format(L["%s: needs a clear"], e.name), C.white
				end
				lines[#lines + 1] = { text, colour }
			end
		end
	end
	return lines, done, goals, name
end

local function Create(parent)
	box = T.Panel(parent, "", Z.WIDTH, 60)
	box:SetPoint(Z.ANCHOR, parent, Z.ANCHOR, Z.X, Z.Y)
	box.band:SetHeight(24)
	box.title:SetFontObject(T.F.label)
	box.rule:SetPoint("TOPLEFT", box.band, "BOTTOMLEFT", 8, 0)
	box.rows = {}
	for i = 1, Z.MAX_ROWS do
		local fs = T.Text(box, T.F.small, C.white)
		fs:SetWidth(Z.WIDTH - 24)
		fs:SetWordWrap(false)
		fs:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -32 - (i - 1) * Z.ROW)
		box.rows[i] = fs
	end
end

local function Hide()
	shown = {}
	if box then box:Hide() end
end

-- Fill the box for the map on screen. Never in combat (the map can open in combat; the box stays away then).
function Z:Layout()
	local canvas, mapID = Live.MapView()
	if not canvas or not mapID or InCombatLockdown() or not self.Enabled() then Hide() return end
	local lines, done, goals, name = Z.Lines(mapID)
	shown = { map = mapID, challenges = Live.Challenges() }
	if #lines == 0 then if box then box:Hide() end return end
	-- on the scroll container that holds the canvas: stays put while the map zooms and pans
	if not box then Create(canvas:GetParent() or canvas) end
	box:SetFrameLevel(canvas:GetFrameLevel() + 3000) -- above the map's pins (PIN_FRAME_LEVEL_*)
	box.title:SetText(string.format(L["Legacy in %s"], name or ""))
	box.hint:SetText(string.format("%d / %d", done, goals))
	box.hint:SetTextColor(T.unpack(done >= goals and C.teal or C.ink2))
	for i, fs in ipairs(box.rows) do
		local line = lines[i]
		fs:SetShown(line ~= nil)
		if line then
			fs:SetText(line[1])
			fs:SetTextColor(T.unpack(line[2]))
		end
	end
	box:SetHeight(32 + math.min(#lines, Z.MAX_ROWS) * Z.ROW + 8)
	box:Show()
end

-- While the map is open: fill again when it shows another map or the challenges changed (a refresh).
function Z:Check()
	if InCombatLockdown() then Hide() return end
	local _, mapID = Live.MapView()
	if mapID ~= shown.map or self.dirty then
		self.dirty = false
		self:Layout()
	end
end

-- Core:RequestRefresh and the settings call this: fill again at the next check.
function Z:Refresh()
	self.dirty = true
	if ticker then self:Check() elseif not self.Enabled() then Hide() end
end

function Z:OnMapShow()
	if ticker then ticker:Cancel() end
	self.dirty = true
	self:Check()
	ticker = C_Timer.NewTicker(Z.TICK, function() Z:Check() end)
end

function Z:OnMapHide()
	if ticker then ticker:Cancel() ticker = nil end
	Hide()
end

-- Called at PLAYER_LOGIN. EventRegistry callbacks run apart from Blizzard's own code (CallbackRegistryMixin).
function Z:Register()
	if self.registered or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then return end
	self.registered = true
	EventRegistry:RegisterCallback("WorldMapOnShow", self.OnMapShow, self)
	EventRegistry:RegisterCallback("WorldMapOnHide", self.OnMapHide, self)
end

Z.Box = function() return box end -- for tests
