-- 1.1 /yl probe: runs the in-game checks that don't need a person (archive/research/19 and archive/research/20 list them) and says
-- which ones still do. Three kinds of result:
--   pass / fail  checked now against the live client
--   wait         evidence the addon collects while you play (a boss kill, a reset, a new point), not seen yet
--   hand         needs your eyes; the line says what to look at
-- The run is printed as a summary, shown in full in the copy window, and saved to db.probe so it can be read from
-- SavedVariables after /reload (devenv/probe.py). Nothing here changes game state or settings.
local _, ns = ...
local Live, Data, L = ns.Live, ns.Data, ns.L

local Probe = {}
ns.Probe = Probe

-- APIs the addon leans on; a missing one means a feature quietly does nothing.
Probe.APIS = {
	"GetAchievementLink", "ChatFrameUtil.InsertLink", "C_ContentTracking.StartTracking", "C_ContentTracking.GetTrackedIDs",
	"C_Traits.GetConfigIDByTreeID", "C_Traits.GetTreeCurrencyInfo", "C_Traits.ResetTree", "C_Traits.GetNodeInfo",
	"C_MajorFactions.GetCurrentRenownLevel", "C_MajorFactions.GetRenownLevels",
	"C_EncounterJournal.GetDungeonEntrancesForMap", "C_Map.GetBestMapForUnit", "C_Map.GetMapChildrenInfo",
	"C_Texture.GetAtlasInfo", "ToggleLegacySystemUI", "ToggleLegacyChallenges", "ShowLegacyChallenge", "hooksecurefunc",
	"LegacyMicroButton.UpdateMicroButton", "C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "DressUpLink", "EventRegistry.RegisterCallback",
	"C_Sound.PlaySound", "C_ChatInfo.SendChatMessage",
}
-- Blizzard art the addon draws (each has a fallback, so a missing one only looks worse).
Probe.ATLASES = {
	"Legacy-Challenge-BG", "Legacy-Challenge-Cards", "Legacy-Challenge-Cards-selected", "Legacy-Progressbar-BG",
	"Legacy-Progressbar-Fill", "Legacy-Progressbar-Frame", "Legacy-Tree-Frame-icon-frame", "Legacy-Tree-Frame-level-circle",
	"Minimal_SliderBar_Button", "Minimal_SliderBar_Left", "Minimal_SliderBar_Right", "_Minimal_SliderBar_Middle",
	"Professions-skillbar-bg", "Professions-skillbar-frame", "Skillbar_Fill_Flipbook_DefaultBlue", "UI-Legacy-Points-icon-c60",
	"checkbox-minimal", "checkmark-minimal", "common-dropdown-a-button", "common-dropdown-a-button-hover", "common-dropdown-bg",
	"common-dropdown-icon-checkmark-yellow", "common-dropdown-textholder", "worldquest-tracker-checkmark",
	"UI-Legacy-Tree-Professions", "UI-Legacy-Tree-Adventure", "UI-Legacy-Tree-Progression", "Dungeon", "Raid",
}
-- Zone maps with dungeon entrances (Classic map IDs): The Barrens, Westfall, Tirisfal Glades, Dun Morogh, Ashenvale.
Probe.ENTRANCE_MAPS = { 1413, 1436, 1420, 1426, 1440 }
Probe.TIRISFAL_AREAS = 18 -- Undercity counts (Legacy Forever's issue 332, 2026-11-09)

-- 123456 copper → "12g 34s 56c"
function Probe.Coins(copper)
	copper = math.floor(tonumber(copper) or 0)
	return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function Join(list, max)
	max = max or 12
	local shown = {}
	for i = 1, math.min(#list, max) do shown[i] = tostring(list[i]) end
	local text = table.concat(shown, ", ")
	if #list > max then text = text .. string.format(", +%d", #list - max) end
	return text
end

-- Each check returns status, text. Order = the order of the report.
local CHECKS = {}
local function Check(id, title, fn) CHECKS[#CHECKS + 1] = { id = id, title = title, fn = fn } end

Check("client", "Client and addon", function()
	local i = Live.ClientInfo()
	return "info", string.format("Your Legacy %s, client %s (%s), %s, %s", i.addon, i.version, i.build, i.locale,
		Live.IsHardcore() and "Hardcore" or "Normal")
end)

Check("apis", "Game functions the addon uses", function()
	local missing = {}
	for _, name in ipairs(Probe.APIS) do if type(Live.Global(name)) ~= "function" then missing[#missing + 1] = name end end
	if #missing > 0 then return "fail", "Missing: " .. Join(missing) end
	return "pass", string.format("All %d are there.", #Probe.APIS)
end)

Check("atlases", "Blizzard art", function()
	local missing = {}
	for _, a in ipairs(Probe.ATLASES) do if not Live.AtlasExists(a) then missing[#missing + 1] = a end end
	if #missing > 0 then return "fail", "Not in this client (a fallback is drawn): " .. Join(missing) end
	return "pass", string.format("All %d atlases are there.", #Probe.ATLASES)
end)

Check("accountFlag", "Account flag on challenges", function()
	local g = Live.AccountFlag()
	if g == nil then return "info", string.format("The client has no ACHIEVEMENT_FLAGS_ACCOUNT; Your Legacy uses %d.", Data.ACHIEVEMENT_FLAG_ACCOUNT) end
	if g == Data.ACHIEVEMENT_FLAG_ACCOUNT then return "pass", "The client's value matches." end
	return "fail", string.format("The client says %s, Your Legacy assumes %d.", tostring(g), Data.ACHIEVEMENT_FLAG_ACCOUNT)
end)

Check("challenges", "Challenges found", function()
	local c = Live.Challenges()
	local n = 0
	for _, g in ipairs(c.groups) do n = n + #g.items end
	if n == 0 then return "fail", "No Legacy challenges found." end
	return c.total == 65 and "pass" or "info", string.format("%d challenges worth %d points (65 expected).", n, c.total)
end)

Check("unspent", "Points left to spend", function()
	if Live.Earned() <= 0 then return "info", "The account has no Legacy points yet." end
	local game, per = Live.UnspentFromGame()
	local ours = ns.Core:Unspent()
	if per then return "info", string.format("The trees report different counts (%s); Your Legacy says %d.", per, ours) end
	if game == nil then return "info", string.format("The game gives no count; Your Legacy says %d.", ours) end
	if game == ours then return "pass", string.format("Both say %d.", ours) end
	return "fail", string.format("The game says %d, Your Legacy says %d.", game, ours)
end)

Check("tracking", "Achievement tracking", function()
	if Live.TrackingDisabled() then return "info", "Tracking is turned off on this realm, so Shift-click only links." end
	return "pass", "Tracking is available."
end)

-- Explorer: every zone and continent the exploration challenge names should be a map, or the banner never shows it.
Check("exploreNames", "Exploration zones are maps", function()
	local maps = Live.AllMaps()
	if #maps == 0 then return "info", "No map list from the game." end
	local names = {}
	for _, m in ipairs(maps) do names[ns.Lower(m.name)] = true end
	local missing, total = {}, 0
	for name, node in pairs(Live.ExploreIndex()) do
		-- depth 1 is the whole world ("Explorer" = Explore Azeroth), which no map is named after (probe 2026-11-10)
		if node.depth >= 2 and node.depth <= 3 then
			total = total + 1
			if not names[name] then missing[#missing + 1] = name end
		end
	end
	table.sort(missing)
	if total == 0 then return "info", "No exploration challenge found." end
	-- achievement names ("explore ashenvale") are indexed too and never match a map, so report only criterion-like ones
	local real = {}
	for _, n in ipairs(missing) do if not n:find("^explore ") then real[#real + 1] = n end end
	if #real > 0 then return "fail", "No map named: " .. Join(real) end
	return "pass", "Every exploration zone has a map of the same name."
end)

-- The areas come from the game's own list, so the banner can't drift from it (Legacy Forever's 17-vs-18 bug came from
-- bundled data). This records the count, to compare with Blizzard's achievement panel when in doubt.
Check("tirisfal", "Tirisfal Glades areas", function()
	local p = Live.ExploreProgress(Live.MapName(1420) or "Tirisfal Glades") or Live.ExploreProgress("Tirisfal Glades")
	if not p then return "info", "Tirisfal Glades wasn't found (another language?)." end
	return "info", string.format("The game lists %d areas (players report %d with Undercity since 2026-11-09).", p.total, Probe.TIRISFAL_AREAS)
end)

-- Dungeons: every part of a dungeon or raid challenge should match an entrance on some map, or the banner and the
-- helper miss it. Also records each entrance's journalInstanceID (DUNGEON_LEVEL_IDS for every language).
Check("dungeons", "Dungeon and raid names", function(run)
	local entrances, journal = {}, {}
	for _, m in ipairs(Live.AllMaps()) do
		for _, e in ipairs(Live.DungeonEntrances(m.id)) do
			if not journal[e.name] then
				journal[e.name] = e.journalID or true -- (a Questie area ID is no journal ID: DUNGEON_LEVEL_IDS needs those)
				entrances[#entrances + 1] = e
			end
		end
	end
	run.journal = journal
	local source = entrances[1] and (entrances[1].source or "game") or nil
	if #entrances == 0 then
		-- 2026-11-10: none on any map in game. Say why, on maps that have entrances in every version of the game.
		local ids = { Live.PlayerMap() }
		for _, id in ipairs(Probe.ENTRANCE_MAPS) do ids[#ids + 1] = id end
		run.entranceDiagnostics = Live.EntranceDiagnostics(ids)
		local maps = #Live.AllMaps()
		return "fail", string.format("No entrances on any of %d maps, so the map banner shows no dungeons. Details: %s",
			maps, table.concat(run.entranceDiagnostics, " | "))
	end
	local matched, counts = {}, {}
	for _, e in ipairs(entrances) do
		for _, m in ipairs(Live.InstanceChallenges(e.name, e.kind)) do
			counts[e.name] = true
			for _, c in ipairs(m.parts) do matched[c.key] = true end
			if m.whole then matched["whole:" .. m.item.id] = true end
		end
	end
	local unmatched, noLevels = {}, {}
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			local criteria = Live.Criteria(item.id)
			if ns.Pages.BracketOf(criteria) then
				for _, c in ipairs(criteria) do
					if not matched[c.key] then unmatched[#unmatched + 1] = c.text end
					if not Data.LevelRange(c.text) then noLevels[#noLevels + 1] = c.text end
				end
			end
		end
	end
	-- only entrances that count for a challenge: Questie lists other expansions' places too (probe 2026-11-10)
	for _, e in ipairs(entrances) do
		if counts[e.name] and not Data.LevelRange(e.name, type(e.journalID) == "number" and e.journalID or nil, e.english) then noLevels[#noLevels + 1] = e.name end
	end
	run.noLevels = noLevels
	local text = string.format("%d entrances (from %s).", #entrances, source)
	if #noLevels > 0 then text = text .. " No level range: " .. Join(noLevels) .. "." end
	if #unmatched > 0 then return "fail", text .. " Dungeon parts with no entrance of that name: " .. Join(unmatched) end
	return "pass", text .. " Every dungeon part matches an entrance."
end)

-- 1.1: where the metal frame pieces really sit (the user: the side panel's left side looks too wide). For the main
-- window and, when open, the character panel: each nine-slice piece's atlas, width, and its left / right edge
-- against the frame's own rect (negative = outside on the left, positive = outside on the right).
local PIECES = { "TopLeftCorner", "LeftEdge", "BottomLeftCorner", "TopRightCorner", "RightEdge", "BottomRightCorner" }
local function Pieces(frame, border)
	local fl, fr = frame:GetLeft(), frame:GetRight()
	if not (fl and fr and border) then return "not laid out" end
	local bits = {}
	for _, key in ipairs(PIECES) do
		local p = border[key]
		if p and p.GetLeft and p:GetLeft() then
			bits[#bits + 1] = string.format("%s %s w%.0f L%+.0f R%+.0f", key, tostring(p.GetAtlas and p:GetAtlas() or "?"),
				p:GetWidth(), p:GetLeft() - fl, p:GetRight() - fr)
		end
	end
	return #bits > 0 and table.concat(bits, "; ") or "no pieces"
end
Check("frames", "Window and panel metal", function(run)
	local ui, ch = ns.UI and ns.UI.frame, ns.Character and ns.Character.frame
	local out = {}
	if ui and ui:IsShown() then
		out[#out + 1] = "Window: " .. Pieces(ui, ns.UI.border)
	end
	if ch and ch:IsShown() then
		out[#out + 1] = "Panel: " .. Pieces(ch, ch.border)
		local g = ch.ground
		if g and g:GetLeft() then out[#out + 1] = string.format("Panel ground L%+.0f", g:GetLeft() - ch:GetLeft()) end
	end
	run.frames = out
	if #out == 0 then return "hand", "Open a character's panel on the Roster, then run the probe again." end
	return "info", table.concat(out, " | ")
end)

Check("rewards", "Rewards collected", function()
	local bits = {}
	for _, r in ipairs(Live.Rewards()) do
		local state = r.owned == true and "owned" or r.owned == false and "not owned" or "unknown"
		bits[#bits + 1] = string.format("%d %s: %s", r.level, r.name or "?", state)
	end
	return "hand", table.concat(bits, "; ") .. ". Does this match your collections?"
end)

Check("level", "Legacy panel opens at level 25", function()
	if Live.Earned() > 0 and not Live.Global("LegacySystemFrame") and not Live.Global("ToggleLegacySystemUI") then
		return "fail", "The account has points but the client has no Legacy panel."
	end
	return "pass", "The Legacy panel is in the client."
end)

-- Evidence collected while playing (Core:Evidence). Each: what it means, what to do while it's missing.
local EVIDENCE = {
	{ key = "encounterUnits", title = "Boss kills carry creature IDs",
		ok = function(e) return true, string.format("Seen in %s.", e.place or "?") end,
		todo = "Kill any boss in a dungeon." },
	{ key = "wipe", title = "Trainer reset dialog (1.2)",
		ok = function(e) return true, string.format("Type %s, cost %s. The reset check below says which type is Legacy.", tostring(e.kind), Probe.Coins(e.cost or 0)) end,
		todo = "At your class trainer, pick the option to unlearn Legacy talents (you can cancel the dialog)." },
	{ key = "unlock", title = "Legacy window opens at 0 points (1.2)",
		ok = function(e) return e.shown, string.format("Opened by the %s; window shown: %s.", e.via or "?", tostring(e.shown)) end,
		todo = "On a ruleset with 0 Legacy points (a new Hardcore character), press the Legacy key or the menu button." },
	{ key = "encounterAsset", title = "Raid boss parts match the fight's ID",
		ok = function(e) return e.match, string.format("Part asset %s, fight %s.", tostring(e.asset), tostring(e.encounterID)) end,
		todo = "Kill a boss in Hyjal Summit (or another raid listed by fight)." },
	{ key = "instances", title = "Dungeon names find their challenge",
		ok = function(e)
			local bad, good = {}, {}
			for name, state in pairs(e.names or {}) do
				if state == "matched" then good[#good + 1] = name else bad[#bad + 1] = name end
			end
			if #bad > 0 then return false, "No challenge found for: " .. Join(bad) end
			return true, "Matched: " .. Join(good)
		end,
		todo = "Enter a dungeon that counts toward a Spelunker challenge." },
	{ key = "entrances", title = "Dungeon entrances on the open map",
		ok = function(e)
			local bits, any = {}, false
			for name, text in pairs(e.maps or {}) do
				bits[#bits + 1] = name .. ": " .. text
				if not text:find("api 0, pins 0, questie 0", 1, true) then any = true end
			end
			table.sort(bits)
			return any, Join(bits, 20)
		end,
		todo = "Open the world map on Westfall or The Barrens." },
	{ key = "challengeSet", title = "Challenge list compared at login (1.3)",
		ok = function(e)
			return (e.count or 0) > 0, string.format("%s: %s challenges on build %s (saved on %s); %s new, %s gone.",
				tostring(e.ruleset), tostring(e.count), tostring(e.build), tostring(e.from or "-"), tostring(e.added), tostring(e.removed))
		end,
		todo = "Log in twice (the first login only saves the list)." },
	{ key = "renown", title = "New point event",
		ok = function(e) return (e.new or 0) > (e.old or 0), string.format("Went from %s to %s.", tostring(e.old), tostring(e.new)) end,
		todo = "Earn a Legacy point." },
	{ key = "reset", title = "What a reset costs",
		ok = function(e)
			-- 1.2: a trainer reset should clear every tree (trees = all with ranks); kind = the dialog type learned
			return true, string.format("%s for %d ranks in %d tree(s), dialog type %s. Your Legacy says %d gold and every tree.",
				Probe.Coins(e.cost or 0), e.ranks or 0, e.trees or 0, tostring(e.kind), Data.RESET_COST_GOLD)
		end,
		todo = "Reset your Legacy perks at your class trainer (it costs gold)." },
}

local HAND = {
	"Open Tirisfal Glades' exploration in Blizzard's Legacy panel and count its areas: the probe's number above should match.",
	"Open the world map on The Barrens: does Blizzard draw the Wailing Caverns entrance icon? Does our banner list it?",
	"Legacy Tree: a plan that drops a learned rank shows the amber reset line; hover it for the list.",
	"World map: the banner and our button sit clear of Blizzard's map buttons, with and without Questie or OpenMap.",
	"World map: drag the banner, close the map, /reload: it stays where you put it.",
	"Open the world map in combat: no errors, the banner and button hide.",
	"Shift-click a challenge with the chat box open: the link works for others.",
	"/yl here in the open world names the areas you haven't found.",
	"Debug fill (Options > Data, Developer tools) at 50% and Mixed: every page; Off and /reload brings real numbers back.",
}

function Probe.Results()
	local run, results = {}, {}
	for _, c in ipairs(CHECKS) do
		local ok, status, text = pcall(c.fn, run)
		if not ok then
			-- report it in the run, and let the error surface too (CLAUDE.md: our own errors aren't pcall'd away)
			local err = status
			status, text = "fail", "The check itself broke: " .. tostring(err)
			if geterrorhandler then geterrorhandler()(err) end
		end
		results[#results + 1] = { id = c.id, title = c.title, status = status, text = text }
	end
	local evidence = ns.Core.db.evidence
	for _, e in ipairs(EVIDENCE) do
		local seen = evidence[e.key]
		if type(seen) == "table" then
			local good, text = e.ok(seen)
			results[#results + 1] = { id = e.key, title = e.title, status = good and "pass" or "fail", text = text .. " (" .. tostring(seen.date) .. ")" }
		else
			results[#results + 1] = { id = e.key, title = e.title, status = "wait", text = "Not seen yet. " .. e.todo }
		end
	end
	if evidence.encounterNoUnits and not evidence.encounterUnits then
		results[#results + 1] = { id = "encounterNoUnits", title = "Boss kills without creature IDs", status = "fail",
			text = "A boss fight ended without creature IDs, so the helper can't name the credit boss." }
	end
	for i, text in ipairs(HAND) do results[#results + 1] = { id = "hand" .. i, title = "By hand", status = "hand", text = text } end
	return results, run
end

local WORD = { pass = "PASS", fail = "FAIL", wait = "WAIT", hand = "HAND", info = "INFO" }

function Probe.Text(results)
	local out, count = {}, { pass = 0, fail = 0, wait = 0, hand = 0, info = 0 }
	for _, r in ipairs(results) do
		count[r.status] = (count[r.status] or 0) + 1
		out[#out + 1] = string.format("[%s] %s: %s", WORD[r.status] or r.status, r.title, r.text or "")
	end
	table.insert(out, 1, string.format("Your Legacy probe %s: %d passed, %d failed, %d waiting for play, %d by hand",
		date("%Y-%m-%d %H:%M"), count.pass, count.fail, count.wait, count.hand))
	return table.concat(out, "\n"), count
end

function Probe:Run()
	if Live.demo then
		ns.Core:Print(L["Turn the debug fill off first: the probe checks real progress."])
		return
	end
	local results, run = Probe.Results()
	local text, count = Probe.Text(results)
	ns.Core.db.probe = { date = date("%Y-%m-%d %H:%M"), results = results, journal = run.journal, noLevels = run.noLevels,
		entranceDiagnostics = run.entranceDiagnostics, frames = run.frames }
	ns.Core:Print(string.format(L["Probe: %d passed, %d failed, %d waiting for play, %d to check by hand. /reload saves it for a bug report."],
		count.pass, count.fail, count.wait, count.hand))
	if ns.Export then
		ns.Export:ShowText(L["Probe"], L["The text is selected. Press Ctrl+C to copy it. Type /reload to save the run with your other Your Legacy data."], text)
	end
	return results
end
