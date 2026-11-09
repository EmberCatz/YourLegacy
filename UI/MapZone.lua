-- 1.0 zone progress on the world map (research/19-feature-plan.md #8, the user's pick after map badges were
-- dropped). An inset box in a corner of the map (the user picks which, from the map button), only on maps with
-- Legacy work: the Legacy points icon, the map's name and how far along it is as a percentage over Blizzard's
-- profession bar; under it this character's exploration of the map, which other character has it all, and the
-- dungeons and raids whose entrance is on the map, each with what's left or a check when done.
-- No data provider, no pins, no hooks: EventRegistry's WorldMapOnShow / WorldMapOnHide (Blizzard_WorldMap.lua) start and
-- stop a light ticker that looks for another map while the map is open (it also shows the map button). In combat
-- the box and the button hide and nothing is built.
local _, ns = ...
local T, Live, L = ns.Theme, ns.Live, ns.L
local C = T.C

local Z = {}
ns.MapZone = Z
Z.TICK = 0.25                     -- seconds between checks while the map is open
Z.WIDTH, Z.ROW, Z.MAX_ROWS = 260, 16, 10
Z.MARGIN = 8                      -- from the map's edge
Z.TOP = 64                        -- header (30) + bar (24) + gap: where the first line starts
Z.CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
Z.LEGACY_FOREVER = "LegacyForever" -- cjber's addon shows zone progress too; ours stays off beside it unless chosen

local box, ticker
local shown = {}                 -- what the box shows now: map, challenges (the Live.Challenges table it was built from)
local cache, cacheFor = {}, nil  -- entrance name → matches, for one Live.Challenges() reading

local function S() return ns.Core.db.settings end

function Z.Enabled()
	local db = ns.Core.db
	if not db then return false end
	if Live.AddOnLoaded(Z.LEGACY_FOREVER) then return db.settings.mapZoneWithLegacyForever == true end
	return db.settings.mapZone == true
end

function Z.SetEnabled(on)
	ns.Core:SetSetting(Live.AddOnLoaded(Z.LEGACY_FOREVER) and "mapZoneWithLegacyForever" or "mapZone", on and true or false)
end

function Z.Corner()
	local corner = ns.Core.db and S().mapZoneCorner
	for _, c in ipairs(Z.CORNERS) do if c == corner then return c end end
	return "TOPLEFT"
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

-- The box's content for a map: lines { text, done, sub } (sub = a note under the goal above it), the share of the
-- map's Legacy work done (0-1, each goal counts the same: explored share, bosses or wings done, 0 or 1 for a
-- clear), goals done, goals in all, the map's name. No lines when the map has no Legacy work.
function Z.Lines(mapID)
	local lines, done, goals, sum = {}, 0, 0, 0
	local name = Live.MapName(mapID)
	local explore = Live.ExploreProgress(name)
	if explore then
		goals = goals + 1
		local complete = explore.done >= explore.total
		local other = not complete and ExploredBy(explore)
		local share = (complete or other) and 1 or explore.done / explore.total
		sum = sum + share
		if share >= 1 then done = done + 1 end
		local fmt = explore.nested and L["%s: %d of %d zones explored"] or L["%s: %d of %d areas explored"]
		lines[#lines + 1] = { text = string.format(fmt, Live.PlayerName(), explore.done, explore.total), done = complete }
		if other then lines[#lines + 1] = { text = string.format(L["%s has explored all of it."], other), done = true, sub = true } end
	end
	local seen = {}
	for _, e in ipairs(Live.DungeonEntrances(mapID)) do
		for _, m in ipairs(Matches(e)) do
			if not seen[m.item.id .. ":" .. e.name] then
				seen[m.item.id .. ":" .. e.name] = true
				goals = goals + 1
				local missing, left, total = ns.Instance.Missing(m)
				local text, share
				if m.item.completed or (not m.whole and #missing == 0) or (m.whole and left == 0) then
					text, share = string.format(L["%s: done"], e.name), 1
				elseif m.whole and total > 1 then
					text, share = string.format(L["%s: %d of %d bosses left"], e.name, left, total), (total - left) / total
				elseif m.whole then
					text, share = string.format(L["%s: not done yet"], e.name), 0
				elseif #m.parts > 1 then
					text, share = string.format(L["%s: %d wings left"], e.name, #missing), (#m.parts - #missing) / #m.parts
				else
					text, share = string.format(L["%s: needs a clear"], e.name), 0
				end
				sum = sum + share
				if share >= 1 then done = done + 1 end
				lines[#lines + 1] = { text = text, done = share >= 1 }
			end
		end
	end
	return lines, goals > 0 and sum / goals or 0, done, goals, name
end

-- "48%": rounded down, so 100% means every goal here is done.
function Z.Percent(ratio) return string.format("%d%%", math.floor(math.max(0, math.min(1, ratio)) * 100 + 1e-6)) end

local function Create(parent)
	box = T.Panel(parent, "", Z.WIDTH, 100)
	box.icon = box:CreateTexture(nil, "ARTWORK")
	box.icon:SetSize(14, 20) -- UI-Legacy-Points-icon-c60 is 50 × 73
	box.icon:SetPoint("LEFT", box.band, "LEFT", 10, 0)
	if not T.Atlas(box.icon, "UI-Legacy-Points-icon-c60") then box.icon:SetTexture(T.Path("LegacyPoints")) end
	box.title:ClearAllPoints()
	box.title:SetPoint("LEFT", box.icon, "RIGHT", 6, 0)
	box.title:SetPoint("RIGHT", box.band, "RIGHT", -64, 0)
	box.title:SetFontObject(T.F.label)
	box.title:SetWordWrap(false)
	box.hint:SetFontObject(T.F.mid)
	box.bar = T.ProgressBar(box, Z.WIDTH - 24)
	box.bar:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -36)
	box.rows = {}
	for i = 1, Z.MAX_ROWS do
		local r = CreateFrame("Frame", nil, box)
		r:SetSize(Z.WIDTH - 24, Z.ROW)
		r:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -Z.TOP - (i - 1) * Z.ROW)
		r.check = r:CreateTexture(nil, "ARTWORK")
		r.check:SetSize(12, 12)
		r.check:SetPoint("LEFT")
		if not T.Atlas(r.check, "worldquest-tracker-checkmark") then r.check:SetTexture(T.Path("Check")) end
		r.text = T.Text(r, T.F.small, C.white)
		r.text:SetPoint("LEFT", 16, 0)
		r.text:SetPoint("RIGHT")
		r.text:SetWordWrap(false)
		box.rows[i] = r
	end
end

-- In the chosen corner, beside whatever already sits there: the map pin and tracking buttons, the stack of addon
-- buttons (ours included), the floor dropdown, Blizzard's panels at the bottom (Live.MapCornerClear). Placed again
-- on every check, so the box steps aside when a button appears later; SetPoint only when the spot changes.
local function Place(parent)
	local corner = Z.Corner()
	local own = ns.MapButton.Button()
	local dx, dy = Live.MapCornerClear(parent, corner, { own }, box)
	local x = (corner:find("LEFT") and 1 or -1) * (Z.MARGIN + dx)
	local y = (corner:find("TOP") and -1 or 1) * (Z.MARGIN + dy)
	local spot = corner .. x .. ":" .. y
	if box.spot == spot then return end
	box.spot = spot
	box:ClearAllPoints()
	box:SetPoint(corner, parent, corner, x, y)
end
Z.Place = function() if box and box:IsShown() then Place(box:GetParent()) end end

local function Hide()
	shown = {}
	if box then box:Hide() end
end

-- Fill the box for the map on screen. Never in combat (the map can open in combat; the box stays away then).
function Z:Layout()
	local canvas, mapID = Live.MapView()
	if not canvas or not mapID or InCombatLockdown() or not self.Enabled() then Hide() return end
	local lines, ratio, done, goals, name = Z.Lines(mapID)
	local newMap = shown.map ~= mapID
	shown = { map = mapID, challenges = Live.Challenges() }
	if #lines == 0 then if box then box:Hide() end return end
	-- on the scroll container that holds the canvas: stays put while the map zooms and pans
	local parent = canvas:GetParent() or canvas
	if not box then Create(parent) end
	box:SetFrameLevel(canvas:GetFrameLevel() + 3000) -- above the map's pins (PIN_FRAME_LEVEL_*)
	Place(parent)
	box.title:SetText(name or "")
	box.hint:SetText(Z.Percent(ratio))
	box.hint:SetTextColor(T.unpack(ratio >= 1 and C.goldHi or C.white))
	box.bar:SetValue(ratio)
	box.goals = { done = done, total = goals }
	for i, r in ipairs(box.rows) do
		local line = lines[i]
		r:SetShown(line ~= nil)
		if line then
			r.text:SetText(line.text)
			r.text:SetTextColor(T.unpack(line.done and C.teal or (line.sub and C.ink2 or C.white)))
			r.check:SetShown(line.done and not line.sub)
		end
	end
	box:SetHeight(Z.TOP + math.min(#lines, Z.MAX_ROWS) * Z.ROW + 10)
	local wasShown = box:IsShown()
	box:Show()
	if newMap or not wasShown then T.Reveal(box, T.DUR_SHORT, 0.97) end
end

-- While the map is open: fill again when it shows another map or the challenges changed (a refresh).
function Z:Check()
	local combat = InCombatLockdown()
	ns.MapButton:Update(not combat)
	if combat then Hide() return end
	local _, mapID = Live.MapView()
	if mapID ~= shown.map or self.dirty then
		self.dirty = false
		self:Layout()
	else
		Z.Place() -- a button appeared or left in the box's corner
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
	ns.MapButton:Update(false)
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

-- The map button's menu: the switch and the corner.
local MB = ns.MapButton
MB:Add({ kind = "toggle", order = 10, text = L["Zone progress"], get = Z.Enabled, set = Z.SetEnabled })
MB:Add({ kind = "title", order = 20, text = L["Corner"] })
local CORNER_NAMES = { TOPLEFT = L["Top left"], TOPRIGHT = L["Top right"], BOTTOMLEFT = L["Bottom left"], BOTTOMRIGHT = L["Bottom right"] }
for i, corner in ipairs(Z.CORNERS) do
	MB:Add({ kind = "radio", order = 20 + i, text = CORNER_NAMES[corner], value = corner, get = Z.Corner,
		set = function(v) ns.Core:SetSetting("mapZoneCorner", v) end })
end
