-- 1.0 map badges (research/19-feature-plan.md #8, option B). Blizzard's world map already pins dungeon and raid
-- entrances (DungeonEntranceDataProvider). This adds a small Legacy mark beside the ones that still count toward
-- an open challenge, with what's left in its tooltip.
-- No data provider, no AcquirePin, no XML: AcquirePin needs an XML template and calls the protected
-- SetPassThroughButtons, and a provider would run our code inside the map's own refresh. Instead the badges are
-- our own pooled frames parented to the map canvas. EventRegistry's WorldMapOnShow / WorldMapOnHide (Blizzard_WorldMap.lua)
-- start and stop a light ticker that looks for a new map or zoom while the map is open. In combat the badges hide
-- and nothing is built.
local _, ns = ...
local T, Live, L = ns.Theme, ns.Live, ns.L
local C = T.C

local B = {}
ns.MapBadges = B
B.TICK = 0.25                     -- seconds between checks while the map is open
B.ICON_W, B.ICON_H = 12, 18       -- UI-Legacy-Points-icon-c60 is 50 × 73
B.OFFSET_X, B.OFFSET_Y = 13, 9    -- from the entrance to the badge's centre, beside Blizzard's pin
B.LEGACY_FOREVER = "LegacyForever" -- cjber's addon pins entrances too; ours stay off beside it unless chosen

local container, ticker
local pool, used = {}, 0
local shown = {}       -- what's laid out now: map, scale, challenges (the Live.Challenges table it was built from)
local cache, cacheFor = {}, nil -- entrance name → open matches, for one Live.Challenges() reading

function B.Enabled()
	local db = ns.Core.db
	if not db then return false end
	if Live.AddOnLoaded(B.LEGACY_FOREVER) then return db.settings.mapBadgesWithLegacyForever == true end
	return db.settings.mapBadges == true
end

-- The open challenges an entrance counts toward, with something still missing there.
local function OpenAt(entrance)
	local challenges = Live.Challenges()
	if cacheFor ~= challenges then cache, cacheFor = {}, challenges end
	local key = entrance.kind .. ":" .. entrance.name
	if cache[key] then return cache[key] end
	local out = {}
	for _, m in ipairs(Live.InstanceChallenges(entrance.name, entrance.kind)) do
		if not m.item.completed then
			local missing, left = ns.Instance.Missing(m)
			if #missing > 0 or (m.whole and left > 0) then out[#out + 1] = m end
		end
	end
	cache[key] = out
	return out
end

local function ShowTooltip(badge)
	local e = badge.entrance
	GameTooltip:SetOwner(badge, "ANCHOR_RIGHT")
	GameTooltip:SetText(e.name, T.unpack(C.head))
	for i, m in ipairs(badge.matches) do
		if i > 1 then GameTooltip:AddLine(" ") end
		local missing, left, total = ns.Instance.Missing(m)
		GameTooltip:AddLine(string.format(L["Counts toward %s."], m.item.name), T.unpack(C.white))
		if m.whole and #m.criteria > 0 then
			GameTooltip:AddLine(string.format(L["%d of %d bosses left."], left, total), T.unpack(C.ink2))
			local names = {}
			for _, c in ipairs(missing) do names[#names + 1] = c.text end
			for j, name in ipairs(names) do
				if j > 8 then GameTooltip:AddLine(string.format(L["and %d more"], #names - 8), T.unpack(C.muted)) break end
				GameTooltip:AddLine(name, T.unpack(C.muted))
			end
		elseif not m.whole then
			GameTooltip:AddLine(string.format(L["Still needs a clear. %d of %d dungeons left."], left, total), T.unpack(C.ink2))
			if #m.parts > 1 then
				for _, c in ipairs(missing) do GameTooltip:AddLine(c.text, T.unpack(C.muted)) end
			elseif missing[1] and ns.Instance.BossFor(missing[1]) then
				GameTooltip:AddLine(string.format(L["Killing %s gives the credit."], ns.Instance.BossFor(missing[1])), T.unpack(C.muted))
			end
		end
		local p = m.item.points
		GameTooltip:AddLine(p == 1 and L["1 Legacy point"] or string.format(L["%d Legacy points"], p), T.unpack(C.gold))
	end
	GameTooltip:Show()
end

local function Badge(i)
	if pool[i] then return pool[i] end
	local b = CreateFrame("Frame", nil, container)
	b:SetSize(B.ICON_W + 16, B.ICON_H)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(B.ICON_W, B.ICON_H)
	b.icon:SetPoint("LEFT")
	if not T.Atlas(b.icon, "UI-Legacy-Points-icon-c60") then b.icon:SetTexture(T.Path("LegacyPoints")) end
	b.count = T.Text(b, T.F.small, C.white)
	b.count:SetPoint("LEFT", b.icon, "RIGHT", 1, 0)
	b:EnableMouse(true)
	b:SetScript("OnEnter", ShowTooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	pool[i] = b
	return b
end

local function HideAll()
	for i = 1, used do pool[i]:Hide() end
	used = 0
	shown = {}
	if container then container:Hide() end
end

-- Build the badges for the map on screen. Never in combat (the map can open in combat; it stays bare then).
function B:Layout()
	local canvas, mapID, scale = Live.MapView()
	if not canvas or not mapID or InCombatLockdown() or not self.Enabled() then HideAll() return end
	if not container then
		container = CreateFrame("Frame", nil, canvas)
		container:SetAllPoints(canvas)
	end
	container:SetFrameLevel(canvas:GetFrameLevel() + 3000) -- above the map's pins (PIN_FRAME_LEVEL_*)
	container:Show()
	for i = 1, used do pool[i]:Hide() end
	used = 0
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	local s = 1 / math.max(scale or 1, 0.01) -- the canvas zooms by scaling; badges keep their size
	for _, e in ipairs(Live.DungeonEntrances(mapID)) do
		local matches = OpenAt(e)
		if #matches > 0 then
			used = used + 1
			local b = Badge(used)
			b.entrance, b.matches = e, matches
			local left = 0
			for _, m in ipairs(matches) do
				local missing, l = ns.Instance.Missing(m)
				left = left + (m.whole and l or #missing)
			end
			b.count:SetText(left)
			b:SetScale(s)
			b:ClearAllPoints()
			b:SetPoint("CENTER", canvas, "TOPLEFT", e.x * w / s + B.OFFSET_X, -e.y * h / s + B.OFFSET_Y)
			b:Show()
		end
	end
	shown = { map = mapID, scale = scale, challenges = Live.Challenges() }
end

-- While the map is open: rebuild when it shows another map, zooms, or the challenges changed (a refresh).
function B:Check()
	if InCombatLockdown() then HideAll() return end
	local _, mapID, scale = Live.MapView()
	if mapID ~= shown.map or scale ~= shown.scale or self.dirty then
		self.dirty = false
		self:Layout()
	end
end

-- Core:RequestRefresh and the settings call this: lay out again at the next check.
function B:Refresh()
	self.dirty = true
	if ticker then self:Check() elseif not self.Enabled() then HideAll() end
end

function B:OnMapShow()
	if ticker then ticker:Cancel() end
	self.dirty = true
	self:Check()
	ticker = C_Timer.NewTicker(B.TICK, function() B:Check() end)
end

function B:OnMapHide()
	if ticker then ticker:Cancel() ticker = nil end
	HideAll()
end

-- Called at PLAYER_LOGIN. EventRegistry callbacks run apart from Blizzard's own code (CallbackRegistryMixin).
function B:Register()
	if self.registered or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then return end
	self.registered = true
	EventRegistry:RegisterCallback("WorldMapOnShow", self.OnMapShow, self)
	EventRegistry:RegisterCallback("WorldMapOnHide", self.OnMapHide, self)
end

B.Badges = function() return pool, used end -- for tests
