-- 1.0 instance helper (research/19-feature-plan.md #7). Inside a dungeon or raid that counts toward a Legacy challenge,
-- say which challenge and what's still missing there; after a boss dies, say whether the kill counted. Answers the
-- "killed every boss, no credit" reports (Drowned City, research/18-competitive-research.md).
-- A dungeon's part is one creature kill (the criterion's assetID). ENCOUNTER_END lists the bosses of the fight with
-- creatureID and creatureName (EncounterInfoDocumentation, Forever), so the helper learns which boss gives the credit
-- (db.bossNames) and notices a kill of that boss that didn't count.
local _, ns = ...
local Live, Data, L = ns.Live, ns.Data, ns.L
local Core = ns.Core

local I = CreateFrame("Frame")
ns.Instance = I
I.ENTER_DELAY = 2 -- after the loading screen, so the instance info and criteria are in
I.KILL_DELAY = 5  -- after ENCOUNTER_END, so the criteria have updated
I.MAX_NAMES = 6   -- names in one "still to kill" line

local told = {}   -- instance name → true once the helper spoke there this session
local here        -- { place = Live.Instance(), matches = Live.InstanceChallenges(), done = { [achievementID] = { [key] = true } } }

local function db() return Core.db end

local function Snapshot(matches)
	local done = {}
	for _, m in ipairs(matches) do
		done[m.item.id] = {}
		for _, c in ipairs(Live.Criteria(m.item.id)) do if c.done then done[m.item.id][c.key] = true end end
	end
	return done
end

local function Left(criteria)
	local left = 0
	for _, c in ipairs(criteria) do if not c.done then left = left + 1 end end
	return left
end

local function NameList(list)
	local shown = {}
	for i = 1, math.min(#list, I.MAX_NAMES) do shown[i] = list[i] end
	local text = table.concat(shown, ", ")
	if #list > I.MAX_NAMES then text = text .. ", " .. string.format(L["and %d more"], #list - I.MAX_NAMES) end
	return text
end

local function Title(item) return Live.AchievementLink(item.id) or item.name end

-- What's still open in one match of Live.InstanceChallenges: the missing parts at this place, the challenge's
-- parts left and total. A raid challenge without parts (Onyxia's) counts as one thing left. Used by the map badges.
function I.Missing(m)
	local missing = {}
	for _, c in ipairs(m.parts) do if not c.done then missing[#missing + 1] = c end end
	local total, left = #m.criteria, Left(m.criteria)
	if m.whole and total == 0 then return {}, 1, 1 end
	return missing, left, total
end

-- The boss whose kill gives a part, once a fight here has shown it.
function I.BossFor(c)
	if c.type ~= Data.CRITERIA_KILL or not c.assetID or c.assetID == 0 then return nil end
	local name = db() and db().bossNames[c.assetID]
	if name and ns.Lower(name) ~= ns.Lower(c.text) then return name end
end

-- The bracket a dungeon challenge belongs to (Data.DUNGEON_BRACKETS), for the outlevel line.
local function Bracket(m) return ns.Pages.BracketOf(m.criteria) end

-- Chat lines for one challenge this instance counts toward. Nothing for a finished one unless asked (/yl here).
local function Lines(place, m, forced)
	local out, item = {}, m.item
	local where = Data.WithLevels(place.name) -- 1.1: "Wailing Caverns (17-24)"
	if item.completed then
		if forced then out[1] = string.format(L["%s counts toward %s, which you've already earned."], where, Title(item)) end
		return out
	end
	local total, left = #m.criteria, Left(m.criteria)
	if m.whole and total == 0 then
		out[1] = string.format(L["%s counts toward %s."], where, Title(item))
	elseif m.whole then
		out[1] = string.format(L["%s counts toward %s: %d of %d bosses left."], where, Title(item), left, total)
		local missing = {}
		for _, c in ipairs(m.parts) do if not c.done then missing[#missing + 1] = c.text end end
		if #missing > 0 then out[2] = string.format(L["Bosses still to kill: %s"], NameList(missing)) end
	else
		local missing = {}
		for _, c in ipairs(m.parts) do if not c.done then missing[#missing + 1] = c end end
		if #missing == 0 then
			out[1] = string.format(L["%s already counts toward %s. %d of %d dungeons left elsewhere."], where, Title(item), left, total)
		else
			out[1] = string.format(L["%s counts toward %s and still needs a clear. %d of %d dungeons left."], where, Title(item), left, total)
			if #m.parts > 1 then
				local names = {}
				for i, c in ipairs(missing) do names[i] = c.text end
				out[#out + 1] = string.format(L["Still needed here: %s"], NameList(names))
			elseif I.BossFor(missing[1]) then
				out[#out + 1] = string.format(L["Killing %s gives the credit."], I.BossFor(missing[1]))
			end
			-- off until in-game check 4 shows an outleveled clear doesn't count (Data.OUTLEVEL_WARNING)
			local bracket = Bracket(m)
			if bracket and Data.OUTLEVEL_WARNING and Live.Level() > bracket.max then
				out[#out + 1] = string.format(L["You're above level %d, so clears here may not count."], bracket.max) .. ns.Pages.RuleTag("outlevel")
			elseif bracket and Live.Level() >= bracket.max - Data.OUTLEVEL_MARGIN then
				-- 1.1: near or past the list's top level, say the range; no claim about whether it still counts
				out[#out + 1] = string.format(L["These dungeons are for levels %d to %d. You're level %d."], bracket.min, bracket.max, Live.Level())
			end
		end
	end
	return out
end

-- Reads where the character is and what counts there. Called after every loading screen.
function I:Update()
	local place = Live.Instance()
	if not place then here = nil return end
	if here and here.place.name == place.name then return end -- a /reload or a ghost run back in: keep the reading
	local matches = Live.InstanceChallenges(place.name, place.kind)
	here = { place = place, matches = matches, done = Snapshot(matches) }
	-- 1.1 probe evidence: did the game's instance name find its challenge? (a known dungeon that matched nothing is a
	-- name mismatch, like a wing named differently in GetInstanceInfo than in the challenge's parts)
	if Data.LevelRange(place.name) or #matches > 0 then
		local old = Core.db.evidence.instances
		local names = {}
		if type(old) == "table" and type(old.names) == "table" then
			for k, v in pairs(old.names) do names[k] = v end
		end
		names[place.name] = #matches > 0 and "matched" or "no challenge"
		Core:Evidence("instances", { names = names })
	end
end

-- The instance lines. forced (/yl here) also speaks outside instances, in ones that don't count, and again.
function I:Report(forced)
	if forced then self:Update() end
	if not here then
		-- 1.1: in the open world, /yl here speaks for the zone instead
		if forced and not (ns.MapZone and ns.MapZone.Here()) then Core:Print(L["You're not in a dungeon or raid."]) end
		return
	end
	if not forced and (told[here.place.name] or not Core:Setting("instanceHelper")) then return end
	told[here.place.name] = true
	local any = false
	for _, m in ipairs(here.matches) do
		for _, line in ipairs(Lines(here.place, m, forced)) do Core:Print(line) any = true end
	end
	if forced and not any then Core:Print(string.format(L["%s doesn't count toward any Legacy challenge."], here.place.name)) end
end

-- Where the character is and which parts of a challenge it can do there, for the tooltip. nil outside.
function I.Here(achievementID)
	if not here then return nil end
	for _, m in ipairs(here.matches) do
		if m.item.id == achievementID then
			local keys = {}
			for _, c in ipairs(m.parts) do keys[c.key] = true end
			return here.place.name, keys, m.whole
		end
	end
	return nil
end

-- A boss fight ended. Learn the names of creatures a part needs; after a kill, say what it did for the challenges.
function I:EncounterEnd(encounterID, success, units)
	if not here then return end
	local killed = {}
	for _, u in ipairs(type(units) == "table" and units or {}) do
		if type(u) == "table" and u.creatureID then
			killed[u.creatureID] = u.creatureName
			for _, m in ipairs(here.matches) do
				for _, c in ipairs(m.criteria) do
					if c.type == Data.CRITERIA_KILL and c.assetID == u.creatureID and type(u.creatureName) == "string" and u.creatureName ~= "" then
						db().bossNames[u.creatureID] = u.creatureName
					end
				end
			end
		end
	end
	-- 1.1 probe evidence: ENCOUNTER_END carries the bosses' creature IDs (or not)
	local withIDs = next(killed) ~= nil
	Core:Evidence(withIDs and "encounterUnits" or "encounterNoUnits", { encounterID = encounterID, place = here.place.name })
	if success ~= 1 then return end
	local at = here
	C_Timer.After(I.KILL_DELAY, function() if here == at then I:AfterKill(encounterID, killed) end end)
end

function I:AfterKill(encounterID, killed)
	local speak = Core:Setting("instanceHelper")
	for _, m in ipairs(here.matches) do
		local before, now = here.done[m.item.id] or {}, Live.Criteria(m.item.id)
		local stillOpen = false
		for _, g in ipairs(Live.Challenges().groups) do
			for _, item in ipairs(g.items) do if item.id == m.item.id then stillOpen = not item.completed end end
		end
		-- a finished challenge has its own "earned" line (Core, ACHIEVEMENT_EARNED)
		if speak and stillOpen then
			local inHere = {}
			for _, c in ipairs(m.parts) do inHere[c.key] = true end
			local total, left = #now, Left(now)
			for _, c in ipairs(now) do
				if inHere[c.key] and not before[c.key] then
					local byThisFight = (c.type == Data.CRITERIA_KILL and killed[c.assetID])
						or (c.type == Data.CRITERIA_ENCOUNTER and c.assetID == encounterID)
					if c.done and c.type == Data.CRITERIA_ENCOUNTER then
						-- 1.1 probe evidence: does a boss-fight part's asset equal ENCOUNTER_END's encounterID?
						Core:Evidence("encounterAsset", { match = c.assetID == encounterID, asset = c.assetID, encounterID = encounterID })
					end
					if c.done then
						if m.whole then
							Core:Print(string.format(L["%s is done for %s: %d of %d bosses left."], c.text, Title(m.item), left, total))
						else
							Core:Print(string.format(L["%s now counts toward %s. %d of %d dungeons left."], c.text, Title(m.item), left, total))
						end
					elseif byThisFight and not m.whole then
						Core:Print(string.format(L["%s died, but the clear of %s didn't count toward %s."], killed[c.assetID] or c.text, c.text, Title(m.item)))
					end
				end
			end
		end
		here.done[m.item.id] = {}
		for _, c in ipairs(now) do if c.done then here.done[m.item.id][c.key] = true end end
	end
end

I:RegisterEvent("PLAYER_ENTERING_WORLD")
I:RegisterEvent("ENCOUNTER_END")
I:SetScript("OnEvent", function(self, event, ...)
	if not db() then return end
	if event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(I.ENTER_DELAY, function()
			I:Update()
			I:Report(false)
		end)
	elseif event == "ENCOUNTER_END" then
		local encounterID, _, _, _, success, units = ...
		self:EncounterEnd(encounterID, success, units)
	end
end)
