-- /yl export: the ledger as JSON in a copyable box, for the web dashboard's Import button.
local _, ns = ...
local T, Live, L = ns.Theme, ns.Live, ns.L
local C = T.C

local Export = {}
ns.Export = Export

---------------------------------------------------------------- JSON
local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function encodeString(s)
	return '"' .. s:gsub('[%c"\\]', function(c) return ESCAPES[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function isArray(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n == #t
end

-- Deterministic output: object keys sorted, arrays in order, one key per line for readable diffs.
local function encode(v, indent)
	local kind = type(v)
	if kind == "string" then return encodeString(v) end
	if kind == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return v == math.floor(v) and string.format("%d", v) or string.format("%.4g", v)
	end
	if kind == "boolean" then return tostring(v) end
	if kind ~= "table" then return "null" end
	local pad, inner = indent, indent .. "  "
	local parts = {}
	if isArray(v) then
		if #v == 0 then return "[]" end
		for i = 1, #v do parts[i] = inner .. encode(v[i], inner) end
		return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
	end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	for i, k in ipairs(keys) do parts[i] = inner .. encodeString(k) .. ": " .. encode(v[k], inner) end
	return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end
Export.Encode = function(v) return encode(v, "") end

---------------------------------------------------------------- window
local W, H = 560, 400

local function Build()
	local f = CreateFrame("Frame", "YourLegacyExportFrame", UIParent)
	f:SetSize(W, H)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "YourLegacyExportFrame") -- Escape closes it
	T.Rounded(f, "Well", "BACKGROUND", C.paper)
	T.Rounded(f, "WellEdge", "BORDER", C.rule)


	local heading = T.Heading(f, L["Export"], W - 48)
	heading:SetPoint("TOPLEFT", 24, -20)
	local close = T.IconButton(f, "Close", 16, L["Close"])
	close:SetPoint("TOPRIGHT", -18, -20)
	close:SetScript("OnClick", function() f:Hide() end)
	local help = T.Text(f, T.F.body, C.parch)
	help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 4, -10)
	help:SetWidth(W - 56)
	help:SetText(L["The text is selected. Press Ctrl+C to copy it, then press Ctrl+V on the Your Legacy dashboard page."])

	local well = CreateFrame("Frame", nil, f)
	well:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -4, -12)
	well:SetPoint("BOTTOMRIGHT", -24, 24)
	T.RowBackground(well)
	local scroll = CreateFrame("ScrollFrame", nil, well)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(T.F.small)
	box:SetTextColor(T.unpack(C.text))
	box:SetWidth(W - 48 - 20)
	scroll:SetScrollChild(box)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, box:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
	end)
	-- Read-only: typing restores the export and selects it again.
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(f.json or "")
			self:HighlightText()
		end
	end)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	f.box = box
	f:Hide()
	return f
end

function Export:Show()
	self.frame = self.frame or Build()
	local f = self.frame
	f.json = Export.Encode(Live.Export(ns.Core.db))
	f.box:SetText(f.json)
	f:Show()
	f.box:SetFocus()
	f.box:HighlightText()
end
