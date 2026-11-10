-- 1.1 /yl report [challenge]: a plain-text report to paste into a bug report (research/20-addon-research-nov10.md #5).
-- Versions, the ruleset, points, the settings, the unconfirmed rules as they're set, other Legacy and map addons
-- that change what players see, and, with a name, every part of that challenge as the game reports it. Rules and
-- criteria keep changing after launch (Tirisfal Glades gained Undercity), so this is what a report needs.
local _, ns = ...
local Live, Data, L = ns.Live, ns.Data, ns.L

local R = {}
ns.Report = R

-- Addons whose presence explains a report (they draw on the same map or replace Blizzard's Legacy window).
R.NEIGHBOURS = { "LegacyForever", "ClassicUIForever", "Questie", "OpenMap", "Krowi_WorldMapButtons" }

-- The challenge (or exploration achievement) whose name holds the text, case aside. Challenges first.
function R.Find(text)
	local needle = ns.Lower(text or "")
	if needle == "" then return nil end
	for _, g in ipairs(Live.Challenges().groups) do
		for _, item in ipairs(g.items) do
			if ns.Lower(item.name or ""):find(needle, 1, true) then return item.id, item.name end
		end
	end
	for name, node in pairs(Live.ExploreIndex()) do
		if name:find(needle, 1, true) then return node.id, name end
	end
end

local function Scalar(v) return type(v) ~= "table" and type(v) ~= "function" end

function R.Text(query)
	local db, out = ns.Core.db, {}
	local function add(line) out[#out + 1] = line end
	local info = Live.ClientInfo()
	add("Your Legacy " .. info.addon .. ", client " .. info.version .. " (" .. info.build .. "), " .. info.locale)
	add("Ruleset " .. (Live.IsHardcore() and "Hardcore" or "Normal") .. ", level " .. Live.Level()
		.. ", points " .. Live.Earned() .. " of " .. Live.MaxAvailable() .. ", unspent " .. ns.Core:Unspent())
	local c = Live.Challenges()
	local saved = 0
	for _ in pairs(db.characters) do saved = saved + 1 end
	add("Challenges " .. c.total .. ", characters saved " .. saved .. ", data version " .. tostring(db.version))
	local keys = {}
	for k, v in pairs(db.settings) do if Scalar(v) then keys[#keys + 1] = k end end
	table.sort(keys)
	local bits = {}
	for _, k in ipairs(keys) do bits[#bits + 1] = k .. "=" .. tostring(db.settings[k]) end
	add("Settings: " .. table.concat(bits, " "))
	add("Rules (" .. Data.RULES_DATE .. "): reset in panel " .. tostring(Data.PERK_RESET_IN_PANEL) .. ", reset cost "
		.. Data.RESET_COST_GOLD .. "g, outlevel warning " .. tostring(Data.OUTLEVEL_WARNING))
	local loaded = {}
	for _, name in ipairs(R.NEIGHBOURS) do if Live.AddOnLoaded(name) then loaded[#loaded + 1] = name end end
	add("Other addons: " .. (#loaded > 0 and table.concat(loaded, ", ") or "none of " .. table.concat(R.NEIGHBOURS, ", ")))
	local place = Live.Instance()
	local mapID = Live.PlayerMap()
	add("Where: " .. (place and (place.name .. " (" .. place.kind .. ")") or (Live.MapName(mapID) or "?") .. " (map " .. tostring(mapID) .. ")"))
	if query and query ~= "" then
		local id, name = R.Find(query)
		add("")
		if not id then
			add("No challenge or exploration matches \"" .. query .. "\".")
		else
			local criteria = Live.Criteria(id)
			add(name .. " (" .. id .. "), " .. #criteria .. " parts:")
			for _, cr in ipairs(criteria) do
				add((cr.done and "[x] " or "[ ] ") .. tostring(cr.text) .. "  type " .. tostring(cr.type) .. ", asset " .. tostring(cr.assetID))
			end
		end
	end
	return table.concat(out, "\n")
end

function R:Show(query)
	if not ns.Export then return end
	ns.Export:ShowText(L["Report a problem"],
		L["The text is selected. Press Ctrl+C to copy it into your bug report, with what you saw and what you expected."],
		R.Text(query))
end
