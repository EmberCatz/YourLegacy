-- Your Legacy's design system (0.8): native to Forever's own UI (research/15-v08-native-audit.md).
-- The window is Blizzard's PortraitFrameTemplate frame with side tabs; regions are Blizzard insets on the Legacy
-- panel's leather ground; text is the client's Friz Quadrata, gold for headings and labels, white for values.
-- The 0.7 rules stay (research/14-v07-hallmark.md): every colour from T.C, every face from T.F, tables before cards,
-- no glows, motion only as state.
local _, ns = ...

local T = {}
ns.Theme = T

T.C = {}
local C = T.C

local function unpackC(c, a) return c[1], c[2], c[3], a or c[4] or 1 end
T.unpack = unpackC

-- "|cffrrggbb" for inline colour codes in strings, from a token.
function T.Hex(c)
	return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

T.MEDIA = "Interface\\AddOns\\YourLegacy\\media\\"
function T.Path(name) return T.MEDIA .. "ui\\" .. name end

---------------------------------------------------------------- palette
-- Roles: paper (behind the ground art), paper2 (inset fill), paper3 (hover, selection), ink / ink2 / muted (text),
-- head (headings and labels, Blizzard gold), rule (1px lines), accent + accentInk (the current selection),
-- heat1..heat6 (progress: Blizzard's blue while under way, gold when done), hc (Hardcore), warn (a level gate),
-- hover (the mouseover band), bad (an unmet requirement).
-- Colours from Blizzard's font colour constants (NORMAL_FONT_COLOR 1/0.82/0, HIGHLIGHT 1/1/1, GRAY 0.5).
-- 0.9.1: one look, the 0.8 one ("Classic"). The Forever glow theme and the theme choice are gone (the user's ask).
local PALETTE = {
	paper = { 0.070, 0.050, 0.035, 1 }, paper2 = { 0.030, 0.024, 0.018, 0.72 }, paper3 = { 0.300, 0.230, 0.130, 0.45 },
	ink = { 1, 1, 1, 1 }, ink2 = { 0.860, 0.840, 0.800, 1 }, muted = { 0.640, 0.610, 0.560, 1 }, head = { 1, 0.820, 0, 1 },
	rule = { 0.330, 0.270, 0.190, 1 }, accent = { 1, 0.820, 0, 1 }, accentInk = { 0, 0, 0, 1 },
	heat1 = { 0.100, 0.160, 0.300, 1 }, heat2 = { 0.120, 0.330, 0.720, 1 }, heat3 = { 0.160, 0.440, 0.880, 1 },
	heat4 = { 0.250, 0.550, 1, 1 }, heat5 = { 0.450, 0.700, 1, 1 }, heat6 = { 1, 0.820, 0, 1 },
	hc = { 1, 0.300, 0.250, 1 }, warn = { 1, 0.450, 0.300, 1 }, bad = { 1, 0.250, 0.200, 1 },
	hover = { 1, 0.780, 0.300, 1 },
}
for k, v in pairs(PALETTE) do C[k] = v end
-- names the code used before 0.7, mapped onto the roles
C.night, C.panel, C.panelFill, C.panelTop, C.well = C.paper, C.paper2, C.paper2, C.paper3, C.paper
C.row, C.field, C.rowHover, C.header, C.bronze = C.paper2, C.paper3, C.paper3, C.paper3, C.paper3
C.text, C.white, C.parch = C.ink, C.ink, C.ink2
C.gold, C.goldHi, C.goldLo = C.heat6, C.ink, C.rule
C.teal, C.tealLo, C.fire, C.green = C.accent, C.heat2, C.warn, C.heat6

-- Progress as heat: the ramp step a ratio has reached. Done is white heat.
function T.Heat(ratio)
	ratio = ratio or 0
	if ratio >= 1 then return C.heat6 end
	if ratio <= 0 then return C.rule end
	if ratio < 0.25 then return C.heat2 end
	if ratio < 0.5 then return C.heat3 end
	if ratio < 0.75 then return C.heat4 end
	return C.heat5
end

---------------------------------------------------------------- fonts
-- The client's own face (Friz Quadrata on Latin clients) at Blizzard's sizes (GameFontNormal 12, Med3 14, Large 16).
-- 0.9.1: the font choices went with the themes. Still our own font objects, so the type scale lives in one place.
local CLIENT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_OBJECTS = { -- name -> size
	YourLegacyFontBrand = 12, YourLegacyFontTitle = 14, YourLegacyFontHuge = 32, YourLegacyFontBig = 20,
	YourLegacyFontMid = 16, YourLegacyFontNumber = 12, YourLegacyFontName = 13, YourLegacyFontTab = 12,
	YourLegacyFontLabel = 11, YourLegacyFontBody = 12, YourLegacyFontBodyLarge = 13, YourLegacyFontSmall = 11,
	YourLegacyFontLarge = 14, YourLegacyFontShield = 32, YourLegacyFontTiny = 10,
}
for name, size in pairs(FONT_OBJECTS) do
	local f = CreateFont(name)
	f:SetFont(CLIENT_FONT, size, "")
	f:SetShadowOffset(1, -1)
	f:SetShadowColor(0, 0, 0, 1) -- Blizzard's fonts carry a full black 1px shadow
end
_G.YourLegacyFontShield:SetShadowOffset(2, -2) -- the points in the shield sit a little off the art
_G.YourLegacyFontShield:SetShadowColor(0, 0, 0, 0.85)

T.F = {
	brand = "YourLegacyFontBrand", title = "YourLegacyFontTitle", huge = "YourLegacyFontHuge",
	big = "YourLegacyFontBig", mid = "YourLegacyFontMid", num = "YourLegacyFontNumber",
	name = "YourLegacyFontName", tab = "YourLegacyFontTab", label = "YourLegacyFontLabel",
	body = "YourLegacyFontBody", bodyL = "YourLegacyFontBodyLarge", small = "YourLegacyFontSmall",
	large = "YourLegacyFontLarge", shield = "YourLegacyFontShield", tiny = "YourLegacyFontTiny",
}

---------------------------------------------------------------- motion
-- Motion is state (Hallmark): short fades in answer to the player (switch, open, select) or the game (an earn).
-- Nothing loops, glows or plays on load. The "animations" option turns all of it off.
function T.Animated() return not (ns.Core and ns.Core.db and ns.Core.db.settings.animations == false) end
T.DUR_MICRO, T.DUR_SHORT = 0.12, 0.22

-- Fade a frame in; grow (optional, e.g. 0.97) scales it up to full size from its origin point at the same time.
function T.Reveal(frame, duration, grow, delay, origin)
	if not T.Animated() then return end
	local g = frame.__reveal
	if not g then
		g = frame:CreateAnimationGroup()
		g.alpha = g:CreateAnimation("Alpha")
		g.alpha:SetFromAlpha(0)
		g.alpha:SetToAlpha(1)
		g.alpha:SetSmoothing("OUT")
		g.scale = g:CreateAnimation("Scale")
		g.scale:SetSmoothing("OUT")
		frame.__reveal = g
	end
	g:Stop()
	duration = duration or T.DUR_SHORT
	g.alpha:SetDuration(duration)
	g.alpha:SetStartDelay(delay or 0)
	g.scale:SetScaleFrom(grow or 1, grow or 1)
	g.scale:SetScaleTo(1, 1)
	g.scale:SetOrigin(origin or "CENTER", 0, 0)
	g.scale:SetDuration(duration)
	g.scale:SetStartDelay(delay or 0)
	g:Play()
end

function T.ClassColor(token)
	local hex = ns.Data.CLASS_COLORS[token] or "FFFFFF"
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

---------------------------------------------------------------- primitives
function T.Tex(parent, name, layer, c, a)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(T.Path(name))
	if c then t:SetVertexColor(unpackC(c, a)) end
	return t
end

function T.Fill(parent, layer, c, a, sub)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	tex:SetColorTexture(unpackC(c, a))
	tex:SetAllPoints() -- covers the parent unless the caller anchors it otherwise
	return tex
end

-- A rounded nine-slice texture (Well, WellEdge, Chip, ChipEdge) covering the parent.
local SLICE = { Well = 12, WellEdge = 12, Chip = 4, ChipEdge = 4 }
function T.Rounded(parent, name, layer, c, a, sub)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	t:SetTexture(T.Path(name))
	local m = SLICE[name]
	t:SetTextureSliceMargins(m, m, m, m)
	t:SetTextureSliceMode(0)
	t:SetAllPoints()
	if c then t:SetVertexColor(unpackC(c, a)) end
	return t
end

-- A smoked well: a rounded fill with a 1px rule edge (Kiln). One level only: never put a well in a well.
function T.Well(frame, c)
	frame.wellFill = T.Rounded(frame, "Well", "BACKGROUND", c or C.paper2)
	frame.wellEdge = T.Rounded(frame, "WellEdge", "BORDER", C.rule)
	return frame
end

-- A Blizzard atlas when the client has it, else the addon's own texture (an atlas missing on Forever draws nothing).
function T.Atlas(tex, atlas, fallback, useAtlasSize)
	if C_Texture and ns.Live.try(C_Texture.GetAtlasInfo, atlas) then
		tex:SetAtlas(atlas, useAtlasSize)
		return true
	end
	if fallback then tex:SetTexture(T.Path(fallback)) end
	return false
end

-- The atlas's own size and texture coordinates in its file (C_Texture.GetAtlasInfo), or nil when the client
-- lacks the atlas. A texture that SetAtlas drew takes SetTexCoord in its file's coordinates, so a caller can draw
-- part of an atlas: SetAtlas, then SetTexCoord inside this rect.
local function AtlasRect(atlas)
	local info = C_Texture and ns.Live.try(C_Texture.GetAtlasInfo, atlas)
	if not (info and info.leftTexCoord and info.rightTexCoord and info.topTexCoord and info.bottomTexCoord
		and (info.width or 0) > 0 and (info.height or 0) > 0) then return nil end
	return info
end
T.AtlasRect = AtlasRect

-- 0.9.1: a background atlas drawn at its own proportions, cropped to the region instead of stretched across it
-- (the docked panels are tall, the Legacy ground is wide). align: "TOP" keeps the art's top edge, so a header band
-- painted into it stays at the top; the sides are cropped evenly. w, h: the region's size.
function T.AtlasCrop(tex, atlas, w, h, align)
	if not T.Atlas(tex, atlas) then return false end
	local info = AtlasRect(atlas)
	if not info or w <= 0 or h <= 0 then return true end
	local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local want, have = w / h, info.width / info.height
	if want < have then -- region narrower than the art: crop the sides
		local keep = (r - l) * want / have
		l = l + ((r - l) - keep) / 2
		r = l + keep
	elseif want > have then -- wider: crop the bottom (or both ends when centred)
		local keep = (b - t) * have / want
		if align ~= "TOP" then t = t + ((b - t) - keep) / 2 end
		b = t + keep
	end
	tex:SetTexCoord(l, r, t, b)
	return true
end

-- A Blizzard NineSlice border (PortraitFrameTemplate, InsetFrameTemplate...), drawn on its own child frame so it
-- can sit above or below the content. Returns the frame.
-- edits (1.1): changes to some pieces of Blizzard's layout, e.g. { TopLeftCorner = { x = -2 } }. The layout is copied
-- (NineSliceUtil.GetLayout), never changed in place.
function T.NineSlice(parent, layout, levelOffset, edits)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()
	f:SetFrameLevel(parent:GetFrameLevel() + (levelOffset or 0))
	return T.ApplyNineSlice(f, layout, edits)
end

-- Lays Blizzard's layout (with edits, if any) onto a frame; again on the same frame to change it.
function T.ApplyNineSlice(f, layout, edits)
	if not NineSliceUtil then return f end
	local base = edits and NineSliceUtil.GetLayout and NineSliceUtil.GetLayout(layout)
	if base and NineSliceUtil.ApplyLayout then
		local copy = {}
		for key, piece in pairs(base) do
			if type(piece) == "table" then
				local p = {}
				for k, v in pairs(piece) do p[k] = v end
				for k, v in pairs(edits[key] or {}) do p[k] = v end
				copy[key] = p
			else
				copy[key] = piece
			end
		end
		NineSliceUtil.ApplyLayout(f, copy)
	elseif NineSliceUtil.ApplyLayoutByName then
		NineSliceUtil.ApplyLayoutByName(f, layout)
	end
	return f
end

-- 1px square border of four textures (tiles, item slots).
function T.Border(frame, c, a)
	local function edge(p1, p2, horizontal)
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetColorTexture(unpackC(c, a))
		t:SetPoint(p1, frame, p1, 0, 0)
		t:SetPoint(p2, frame, p2, 0, 0)
		if horizontal then t:SetHeight(1) else t:SetWidth(1) end
	end
	edge("TOPLEFT", "TOPRIGHT", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	edge("TOPLEFT", "BOTTOMLEFT", false)
	edge("TOPRIGHT", "BOTTOMRIGHT", false)
end

-- A horizontal 1px rule.
function T.Rule(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetColorTexture(unpackC(C.rule))
	t:SetHeight(1)
	return t
end

function T.Divider(parent, width)
	local d = T.Rule(parent)
	d:SetWidth(width)
	return d
end

function T.Text(parent, font, c, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFontObject(font or T.F.body)
	fs:SetTextColor(unpackC(c or C.ink))
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- Section head inside a page or a drawer: a display title in ink over a 1px rule; .hint sits right, muted.
function T.Heading(parent, text, width)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(width, 26)
	h.text = T.Text(h, T.F.title, C.head)
	h.text:SetPoint("TOPLEFT", 0, -2)
	h.text:SetText(text)
	h.line = T.Rule(h)
	h.line:SetPoint("BOTTOMLEFT", 0, 0)
	h.line:SetPoint("BOTTOMRIGHT", 0, 0)
	h.hint = T.Text(h, T.F.small, C.muted, "RIGHT")
	h.hint:SetPoint("TOPRIGHT", 0, -4)
	return h
end

-- The mouseover (0.9): a soft band in the theme's hover colour that fades out at both ends, with a hairline along
-- its top and bottom (media/ui/Hover), as Blizzard's list highlights do. HIGHLIGHT layer, so the game shows it on
-- hover by itself. alpha scales it for small targets.
function T.Hover(frame, alpha, inset)
	local t = frame:CreateTexture(nil, "HIGHLIGHT")
	t:SetTexture(T.Path("Hover"))
	t:SetVertexColor(unpackC(C.hover, alpha or 0.55))
	t:SetBlendMode("ADD")
	t:SetPoint("TOPLEFT", inset or 0, -(inset or 0))
	t:SetPoint("BOTTOMRIGHT", -(inset or 0), inset or 0)
	return t
end

-- A table row: a 1px rule along the bottom and the hover band. With c (an input), a rounded well.
function T.RowBackground(row, c)
	if c then
		row.band = T.Rounded(row, "Chip", "BACKGROUND", C.paper)
		row.edge = T.Rounded(row, "ChipEdge", "BORDER", C.rule)
		return
	end
	row.hover = T.Hover(row)
	row.rule = T.Rule(row, "BORDER")
	row.rule:SetPoint("BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", 0, 0)
end

-- A text button (filters, character chips, sort). At rest ink2, hover ink, active ink with a 2px ember indicator.
function T.TextButton(parent, label, font)
	local b = CreateFrame("Button", nil, parent)
	b.Label = T.Text(b, font or T.F.tab, C.ink2, "CENTER")
	b.Label:SetPoint("CENTER")
	b.Label:SetText(label)
	b:SetSize(math.max(36, b.Label:GetStringWidth() + 20), 26)
	b.glow = b:CreateTexture(nil, "ARTWORK")
	b.glow:SetColorTexture(unpackC(C.accent))
	b.glow:SetHeight(2)
	b.glow:SetPoint("BOTTOMLEFT", 8, 0)
	b.glow:SetPoint("BOTTOMRIGHT", -8, 0)
	b.glow:Hide()
	b:SetScript("OnEnter", function(self) if not self.active then self.Label:SetTextColor(unpackC(C.ink)) end end)
	b:SetScript("OnLeave", function(self) if not self.active then self.Label:SetTextColor(unpackC(C.ink2)) end end)
	function b:SetActive(active)
		local was = self.active
		self.active = active
		self.Label:SetTextColor(unpackC(active and C.head or C.ink2))
		self.glow:SetShown(active and not self.noGlow)
		if active and not was and not self.noGlow then T.Reveal(self.glow, T.DUR_MICRO) end
	end
	return b
end

-- Small icon button (close, options).
function T.IconButton(parent, icon, size, tooltip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.icon = T.Tex(b, icon, "ARTWORK", C.muted)
	b.icon:SetAllPoints()
	b:SetScript("OnEnter", function(self)
		self.icon:SetVertexColor(unpackC(C.ink))
		if tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText(tooltip)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(unpackC(self.on and C.ink or C.muted))
		GameTooltip:Hide()
	end)
	return b
end

-- A region of a page: Blizzard's InsetFrameTemplate border over a darkened fill, a gold title in a 32px head and a
-- 1px rule under it. p.band is the head (for anchoring), p.title, p.hint (right, muted), p.body the content area.
-- title == false: no head at all, the body fills the inset (0.9 Overview).
function T.Panel(parent, title, width, height)
	local p = CreateFrame("Frame", nil, parent)
	p:SetSize(width, height)
	p.fill = T.Fill(p, "BACKGROUND", C.paper2)
	p.fill:SetPoint("TOPLEFT", 3, -3)
	p.fill:SetPoint("BOTTOMRIGHT", -3, 3)
	p.border = T.NineSlice(p, "InsetFrameTemplate", 0)
	p.band = CreateFrame("Frame", nil, p)
	p.band:SetPoint("TOPLEFT", 3, -3)
	p.band:SetPoint("TOPRIGHT", -3, -3)
	p.band:SetHeight(30)
	p.title = T.Text(p, T.F.title, C.head)
	p.title:SetPoint("LEFT", p.band, "LEFT", 12, 0)
	p.title:SetText(title or "")
	p.hint = T.Text(p, T.F.small, C.muted, "RIGHT")
	p.hint:SetPoint("RIGHT", p.band, "RIGHT", -12, 0)
	p.body = CreateFrame("Frame", nil, p)
	p.body:SetPoint("BOTTOMRIGHT", -14, 12)
	if title == false then
		p.band:Hide()
		p.body:SetPoint("TOPLEFT", 14, -12)
		return p
	end
	p.rule = T.Rule(p)
	p.rule:SetPoint("TOPLEFT", p.band, "BOTTOMLEFT", 8, 0)
	p.rule:SetPoint("TOPRIGHT", p.band, "BOTTOMRIGHT", -8, 0)
	p.body:SetPoint("TOPLEFT", 14, -44)
	return p
end

-- A card on the Legacy panel's own card art (Legacy-Challenge-Cards; -selected is the yellow outline Blizzard puts
-- on the chosen challenge), with a hover band. Falls back to an inset.
-- bannerH (0.9.1): a tall card. The card art is drawn only across the top, at the height it's made for (it
-- stretched badly over a whole 218px card), and the rest is a Blizzard inset under it. Then c.content is the frame
-- to put text on (above both), and c.onEnter / c.onLeave take the place of the OnEnter / OnLeave scripts.
-- Without a banner c.content is the card itself.
function T.Card(parent, width, height, bannerH)
	local c = CreateFrame("Button", nil, parent)
	c:SetSize(width, height)
	local art = c
	if bannerH then
		c.inset = CreateFrame("Frame", nil, c)
		c.inset:SetPoint("TOPLEFT", 2, -(bannerH - 6))
		c.inset:SetPoint("BOTTOMRIGHT", -2, 0)
		c.inset.fill = T.Fill(c.inset, "BACKGROUND", C.paper2)
		c.inset.fill:SetPoint("TOPLEFT", 3, -3)
		c.inset.fill:SetPoint("BOTTOMRIGHT", -3, 3)
		c.inset.border = T.NineSlice(c.inset, "InsetFrameTemplate", 0)
		art = CreateFrame("Frame", nil, c)
		art:SetAllPoints()
		art:SetFrameLevel(c:GetFrameLevel() + 3) -- the banner overlaps the inset's top edge
		c.art = art
		c.content = CreateFrame("Frame", nil, c)
		c.content:SetAllPoints()
		c.content:SetFrameLevel(c:GetFrameLevel() + 5)
		c.hover = c.content:CreateTexture(nil, "BACKGROUND")
		c.hover:SetTexture(T.Path("Hover"))
		c.hover:SetVertexColor(unpackC(C.hover, 0.3))
		c.hover:SetBlendMode("ADD")
		c.hover:SetPoint("TOPLEFT", 3, -3)
		c.hover:SetPoint("BOTTOMRIGHT", -3, 3)
		c.hover:Hide()
		c:SetScript("OnEnter", function(self)
			self.hover:Show()
			if self.onEnter then self:onEnter() end
		end)
		c:SetScript("OnLeave", function(self)
			self.hover:Hide()
			if self.onLeave then self:onLeave() end
		end)
	else
		c.content = c
		c.hover = T.Hover(c, 0.35, 3)
	end
	c.bg = art:CreateTexture(nil, "BACKGROUND")
	c.bg:SetPoint("TOPLEFT")
	c.bg:SetPoint("TOPRIGHT")
	if bannerH then c.bg:SetHeight(bannerH) else c.bg:SetPoint("BOTTOM") end
	if not T.Atlas(c.bg, "Legacy-Challenge-Cards") then
		c.bg:SetColorTexture(unpackC(C.paper2))
		if not bannerH then c.border = T.NineSlice(c, "InsetFrameTemplate", 0) end
	end
	c.sel = art:CreateTexture(nil, "BORDER", nil, 2)
	c.sel:SetAllPoints(c.bg)
	if not T.Atlas(c.sel, "Legacy-Challenge-Cards-selected") then
		c.sel:SetTexture(T.Path("TileFrame"))
		c.sel:SetVertexColor(unpackC(C.accent))
	end
	c.sel:Hide()
	function c:SetSelected(on)
		local was = self.sel:IsShown()
		self.sel:SetShown(on and true or false)
		if on and not was then T.Reveal(self.sel, T.DUR_MICRO) end
	end
	return c
end

-- Dropdown on Blizzard's WowStyle1Dropdown art (common-dropdown-textholder, common-dropdown-a-button) with the list
-- the way Blizzard's MenuStyle1 draws it (Blizzard_Menu/Mainline/MenuTemplates.lua): common-dropdown-bg reaching
-- 10px past the sides and 3px past the top and bottom, at 92.5% alpha, the entries inset 8px. Built here rather
-- than on the Menu system so the mock can drive it. options() returns { { value, label, desc?, deletable? } };
-- onSelect(value). Entries can carry a delete action (onDelete(value)) for saved lists.
-- 0.9.1: the list is as wide as its longest entry (no more "Quest comple..."), shows at most LIST_ROWS entries and
-- scrolls with the wheel past that, and closes whenever its button goes out of sight (another options section,
-- another tab), so it never comes back open.
local openDropdown
local LIST_ROWS = 10
local LIST_INSET = { left = 8, right = 8, top = 8, bottom = 10 }
T.LIST_ROWS = LIST_ROWS
function T.Dropdown(parent, width, options, onSelect, rowH)
	rowH = rowH or 20
	local d = CreateFrame("Button", nil, parent)
	d:SetSize(width, 25)
	d.bg = d:CreateTexture(nil, "BACKGROUND")
	d.bg:SetPoint("TOPLEFT", -8, 7)
	d.bg:SetPoint("BOTTOMRIGHT", 8, -9)
	if not T.Atlas(d.bg, "common-dropdown-textholder") then
		d.bg:ClearAllPoints()
		d.bg:SetAllPoints()
		d.bg:SetColorTexture(unpackC(C.paper))
		T.Border(d, C.rule)
	end
	d.arrow = d:CreateTexture(nil, "OVERLAY")
	d.arrow:SetPoint("RIGHT", 1, -3)
	if not T.Atlas(d.arrow, "common-dropdown-a-button", "Chevron", true) then
		d.arrow:SetSize(12, 12)
		d.arrow:SetPoint("RIGHT", -6, 0)
		d.arrow:SetVertexColor(unpackC(C.ink2))
	end
	d.Text = T.Text(d, T.F.body, C.ink, "LEFT")
	d.Text:SetPoint("LEFT", 8, 0)
	d.Text:SetPoint("RIGHT", d.arrow, "LEFT", -4, 0)
	d.Text:SetWordWrap(false)
	d.options, d.onSelect = options, onSelect

	-- the list: on the dialog strata so it sits over the window
	local list = CreateFrame("Frame", nil, d)
	list:SetFrameStrata("DIALOG")
	list:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -4)
	list:EnableMouse(true)
	list:EnableMouseWheel(true)
	list:Hide()
	list.bg = list:CreateTexture(nil, "BACKGROUND")
	if T.Atlas(list.bg, "common-dropdown-bg") then
		list.bg:SetPoint("TOPLEFT", -10, 3)
		list.bg:SetPoint("BOTTOMRIGHT", 10, -3)
		list.bg:SetAlpha(0.925)
	else
		list.bg:SetAllPoints()
		list.bg:SetColorTexture(unpackC(C.paper))
		T.Border(list, C.rule)
	end
	-- a slim thumb on the right while the list scrolls
	list.thumb = T.Tex(list, "Thumb", "OVERLAY", C.muted, 0.7)
	list.thumb:SetWidth(3)
	list.thumb:Hide()
	d.list = list
	list.rows, list.offset = {}, 0
	local function Row(i)
		local r = list.rows[i]
		if r then return r end
		r = CreateFrame("Button", nil, list)
		r:SetHeight(rowH)
		r.hover = T.Hover(r, 0.5)
		r.check = r:CreateTexture(nil, "OVERLAY")
		r.check:SetSize(14, 14)
		r.check:SetPoint("LEFT", 0, 0)
		if not T.Atlas(r.check, "common-dropdown-icon-checkmark-yellow") then
			r.check:SetTexture(T.Path("Check"))
			r.check:SetVertexColor(unpackC(C.head))
		end
		r.Label = T.Text(r, T.F.body, C.ink, "LEFT")
		r.Label:SetPoint("LEFT", 20, 0)
		r.Label:SetPoint("RIGHT", -4, 0)
		r.Label:SetWordWrap(false)
		r.del = T.IconButton(r, "Close", 12)
		r.del:SetPoint("RIGHT", -2, 0)
		r.del:SetScript("OnClick", function(self)
			list:Hide()
			if d.onDelete then d.onDelete(self:GetParent().value) end
		end)
		r:SetScript("OnClick", function(self)
			list:Hide()
			d:SetValue(self.value)
			if d.onSelect then d.onSelect(self.value) end
		end)
		r:SetScript("OnEnter", function(self)
			if self.desc then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(self.Label:GetText() or "", unpackC(C.ink))
				GameTooltip:AddLine(self.desc, unpackC(C.ink2))
				GameTooltip:Show()
			end
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		list.rows[i] = r
		return r
	end
	-- the entries from list.offset on, as many as fit
	local function Lay()
		local opts = list.opts or {}
		local shown = math.min(#opts, LIST_ROWS)
		for i = 1, shown do
			local o = opts[list.offset + i]
			local r = Row(i)
			r.value, r.desc = o[1], o.desc
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_INSET.left, -LIST_INSET.top - (i - 1) * rowH)
			r:SetPoint("RIGHT", list, "RIGHT", -LIST_INSET.right - (#opts > LIST_ROWS and 6 or 0), 0)
			r.Label:SetFontObject(o.font or T.F.body)
			r.Label:SetText(o[2])
			r.Label:SetPoint("RIGHT", o.deletable and -18 or -4, 0)
			r.Label:SetTextColor(unpackC(o[1] == d.value and C.head or C.ink))
			r.check:SetShown(o[1] == d.value)
			r.del:SetShown(o.deletable and true or false)
			r:Show()
		end
		for i = shown + 1, #list.rows do list.rows[i]:Hide() end
		local scrolls = #opts > LIST_ROWS
		list.thumb:SetShown(scrolls)
		if scrolls then
			local track = shown * rowH
			local h = math.max(16, track * shown / #opts)
			list.thumb:SetHeight(h)
			list.thumb:ClearAllPoints()
			list.thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, -LIST_INSET.top - (track - h) * list.offset / (#opts - shown))
		end
	end
	list:SetScript("OnMouseWheel", function(_, delta)
		local opts = list.opts or {}
		local maxOffset = math.max(0, #opts - LIST_ROWS)
		list.offset = math.max(0, math.min(maxOffset, list.offset - delta))
		Lay()
	end)
	function d:Open()
		if openDropdown and openDropdown ~= self then openDropdown.list:Hide() end
		local opts = type(self.options) == "function" and self.options() or self.options
		list.opts = opts
		-- as wide as the widest entry: the check, the text, the delete button, the insets
		local measure = Row(1).Label
		local widest, deletable = 0, false
		for _, o in ipairs(opts) do
			measure:SetFontObject(o.font or T.F.body)
			measure:SetText(o[2])
			widest = math.max(widest, measure:GetStringWidth())
			deletable = deletable or o.deletable or false
		end
		local w = math.max(self:GetWidth(), math.ceil(widest) + 20 + (deletable and 18 or 4) + LIST_INSET.left + LIST_INSET.right
			+ (#opts > LIST_ROWS and 6 or 0) + 4)
		-- open on the chosen entry when the list scrolls
		list.offset = 0
		for i, o in ipairs(opts) do
			if o[1] == self.value then list.offset = math.max(0, math.min(#opts - LIST_ROWS, i - math.ceil(LIST_ROWS / 2))) end
		end
		list.offset = math.max(0, list.offset)
		list:SetSize(w, math.min(#opts, LIST_ROWS) * rowH + LIST_INSET.top + LIST_INSET.bottom)
		-- 1.1: a scroll area clips its children, so a list near the bottom of the Options page was cut off. Lift it to
		-- the top-level frame the dropdown sits in (same scale, no clipping), and open it upward when it wouldn't fit
		-- below that frame.
		local top, p = self, self:GetParent()
		while p and p ~= UIParent do top, p = p, p:GetParent() end
		if list:GetParent() ~= top then
			list:SetParent(top)
			list:SetFrameStrata("DIALOG")
		end
		list:SetFrameLevel(top:GetFrameLevel() + 50)
		list:ClearAllPoints()
		local below = (self:GetBottom() or 0) - (top:GetBottom() or 0)
		if below < list:GetHeight() + 8 and (top:GetTop() or 0) - (self:GetTop() or 0) > list:GetHeight() + 8 then
			list:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4)
		else
			list:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
		end
		Lay()
		list:Show()
		openDropdown = self
		T.Reveal(list, T.DUR_MICRO)
	end
	d:SetScript("OnClick", function(self)
		if list:IsShown() then list:Hide() else self:Open() end
	end)
	-- out of sight (its section or page hidden): the list goes too, so it never reappears open
	d:SetScript("OnHide", function() list:Hide() end)
	d.hover = d:CreateTexture(nil, "HIGHLIGHT")
	d.hover:SetAllPoints(d.arrow)
	if not T.Atlas(d.hover, "common-dropdown-a-button-hover") then d.hover:Hide() end
	-- a click anywhere else closes it, as Blizzard's menus do; it listens only while it's open
	list:SetScript("OnEvent", function(self)
		if not (self:IsMouseOver() or d:IsMouseOver()) then self:Hide() end
	end)
	list:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
	list:SetScript("OnHide", function(self)
		self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		if openDropdown == d then openDropdown = nil end
	end)
	-- value shown on the button; label looked up in the options
	function d:SetValue(value)
		self.value = value
		local opts = type(self.options) == "function" and self.options() or self.options
		for _, o in ipairs(opts) do
			if o[1] == value then
				self.Text:SetFontObject(o.buttonFont or T.F.body)
				self.Text:SetText(o[2])
				return
			end
		end
		self.Text:SetText(self.placeholder or "")
	end
	return d
end
function T.CloseDropdowns() if openDropdown then openDropdown.list:Hide() end end

-- Slider on Blizzard's minimal slider (Blizzard_SharedXML/Shared/Slider/MinimalSlider.xml), as the game's Settings
-- panel draws it: Left and Right caps and the Middle between them, all three at their own atlas size (0.9.1: the
-- middle was squeezed to 8px under 17px caps), the round Minimal_SliderBar_Button thumb, and the stepper arrows
-- either side (MinimalSliderWithSteppersTemplate). A fill in the Legacy bar's blue runs from the left to the thumb,
-- with a light top edge. min..max in steps; onChange(value) while dragging, onCommit(value) on release.
function T.Slider(parent, width, min, max, step, onChange, onCommit)
	local s = CreateFrame("Frame", nil, parent)
	s:SetSize(width, 19)
	s:EnableMouse(true)
	local l = s:CreateTexture(nil, "BACKGROUND")
	l:SetPoint("LEFT", 0, 0)
	local r = s:CreateTexture(nil, "BACKGROUND")
	r:SetPoint("RIGHT", 0, 0)
	local mid = s:CreateTexture(nil, "BACKGROUND")
	local hasMid = T.Atlas(mid, "_Minimal_SliderBar_Middle", nil, true)
	local caps = T.Atlas(l, "Minimal_SliderBar_Left", nil, true) and T.Atlas(r, "Minimal_SliderBar_Right", nil, true)
	if hasMid and caps then
		mid:SetPoint("TOPLEFT", l, "TOPRIGHT")
		mid:SetPoint("TOPRIGHT", r, "TOPLEFT")
	else
		l:Hide()
		r:Hide()
		mid:SetPoint("LEFT", 0, 0)
		mid:SetPoint("RIGHT", 0, 0)
		if not hasMid then
			mid:SetHeight(6)
			mid:SetColorTexture(unpackC(C.paper))
		end
	end
	-- the fill, inside the track's groove
	s.fill = s:CreateTexture(nil, "ARTWORK")
	s.fill:SetPoint("LEFT", s, "LEFT", 4, 0)
	s.fill:SetHeight(5)
	if not T.Atlas(s.fill, "Legacy-Progressbar-Fill") then s.fill:SetColorTexture(unpackC(C.heat4)) end
	s.fillEdge = s:CreateTexture(nil, "ARTWORK", nil, 1)
	s.fillEdge:SetColorTexture(1, 1, 1, 0.28)
	s.fillEdge:SetHeight(1)
	s.fillEdge:SetPoint("TOPLEFT", s.fill, "TOPLEFT")
	s.fillEdge:SetPoint("TOPRIGHT", s.fill, "TOPRIGHT")
	s.thumb = CreateFrame("Frame", nil, s)
	s.thumb:SetSize(20, 19)
	s.thumb.tex = s.thumb:CreateTexture(nil, "ARTWORK")
	s.thumb.tex:SetAllPoints()
	if not T.Atlas(s.thumb.tex, "Minimal_SliderBar_Button") then
		s.thumb.tex:SetTexture(T.Path("Glow"))
		s.thumb.tex:SetVertexColor(unpackC(C.head))
	end
	s.thumb.hl = T.Hover(s.thumb, 0.6)
	s.min, s.max, s.step = min, max, step
	local function Place()
		local ratio = (s.value - min) / (max - min)
		local x = 8 + ratio * (width - 16) -- the thumb's centre stays over the track
		s.thumb:ClearAllPoints()
		s.thumb:SetPoint("CENTER", s, "LEFT", x, 0)
		s.fill:SetWidth(math.max(1, x - 4))
	end
	function s:SetValue(v)
		v = math.max(min, math.min(max, math.floor((v - min) / step + 0.5) * step + min))
		self.value = v
		Place()
	end
	local function Nudge(delta)
		s:SetValue(s.value + delta * step)
		if onChange then onChange(s.value) end
		if onCommit then onCommit(s.value) end
	end
	-- the stepper arrows, as the Settings panel puts them beside its sliders
	local function Stepper(atlas, delta, w, h)
		local b = CreateFrame("Button", nil, s)
		b:SetSize(w, h)
		b.tex = b:CreateTexture(nil, "BACKGROUND")
		b.tex:SetAllPoints()
		if not T.Atlas(b.tex, atlas) then
			b.tex:SetTexture(T.Path("Chevron"))
			b.tex:SetRotation(math.rad(delta < 0 and 90 or -90))
			b.tex:SetVertexColor(unpackC(C.ink2))
		end
		b.hl = b:CreateTexture(nil, "HIGHLIGHT")
		b.hl:SetAllPoints()
		if T.Atlas(b.hl, atlas) then b.hl:SetBlendMode("ADD") b.hl:SetAlpha(0.4) else b.hl:Hide() end
		b:SetScript("OnClick", function() Nudge(delta) end)
		return b
	end
	s.back = Stepper("Minimal_SliderBar_Button_Left", -1, 11, 19)
	s.back:SetPoint("RIGHT", s, "LEFT", -4, 0)
	s.forward = Stepper("Minimal_SliderBar_Button_Right", 1, 9, 18)
	s.forward:SetPoint("LEFT", s, "RIGHT", 4, 0)
	local function FromCursor()
		local x = GetCursorPosition() / s:GetEffectiveScale()
		local left = s:GetLeft() or 0
		return min + (max - min) * math.max(0, math.min(1, (x - left - 8) / (width - 16)))
	end
	local function Drag()
		local old = s.value
		s:SetValue(FromCursor())
		if s.value ~= old and onChange then onChange(s.value) end
	end
	s:SetScript("OnMouseDown", function(self)
		Drag()
		self:SetScript("OnUpdate", Drag) -- only while the button is held
	end)
	s:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
		Drag()
		if onCommit then onCommit(self.value) end
	end)
	s:SetScript("OnMouseWheel", function(_, delta) Nudge(delta) end)
	s:EnableMouseWheel(true)
	s:SetValue(min)
	return s
end

-- A class or reward icon in Blizzard's Legacy icon frame (Legacy-Tree-Frame-icon-frame, 60px around a 50px icon in
-- LegacyChallengeIconFrameTemplate), so it reads as a framed portrait rather than a loose square. f.icon, f.ring.
function T.IconFrame(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("CENTER")
	f.icon:SetSize(size, size)
	f.ring = f:CreateTexture(nil, "OVERLAY")
	f.ring:SetPoint("CENTER")
	if T.Atlas(f.ring, "Legacy-Tree-Frame-icon-frame") then
		f.ring:SetSize(size * 1.2, size * 1.2)
	else
		f.ring:SetTexture(T.Path("TileFrame"))
		f.ring:SetVertexColor(unpackC(C.rule))
		f.ring:SetSize(size + 2, size + 2)
	end
	return f
end

-- A monochrome glyph from media/ui (Glyph<Name>), tinted.
function T.Glyph(parent, name, size, c, layer)
	local g = T.Tex(parent, "Glyph" .. name, layer or "ARTWORK", c or C.muted)
	g:SetSize(size, size)
	return g
end

-- Icon tile: a game icon (or a glyph) on the ground, a 1px edge whose colour carries the state.
function T.Tile(parent, size)
	local t = CreateFrame("Frame", nil, parent)
	t:SetSize(size, size)
	t.fill = T.Rounded(t, "Chip", "BACKGROUND", C.paper)
	t.icon = t:CreateTexture(nil, "ARTWORK")
	t.icon:SetPoint("TOPLEFT", 2, -2)
	t.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	t.frame = T.Tex(t, "TileFrame", "OVERLAY", C.rule)
	t.frame:SetAllPoints()
	-- texture: a file ID / path from the game, or "glyph:Name" for our own art
	function t:SetIcon(texture, tint)
		if type(texture) == "string" and texture:sub(1, 6) == "glyph:" then
			self.icon:SetTexture(T.Path("Glyph" .. texture:sub(7)))
			self.icon:SetTexCoord(0, 1, 0, 1)
			self.icon:SetVertexColor(unpackC(tint or C.muted))
		else
			self.icon:SetTexture(texture)
			self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the game icons' baked border
			self.icon:SetVertexColor(1, 1, 1, 1)
		end
	end
	function t:SetState(c, dim)
		self.frame:SetVertexColor(unpackC(c))
		self.icon:SetDesaturated(dim and true or false)
		self.icon:SetAlpha(dim and 0.5 or 1)
	end
	return t
end

-- A text tab (the window's page tabs, the Challenges sections): ink2 at rest, gold when active, with a 2px gold
-- marker along its foot and the hover band.
function T.BoxTab(parent, label, font)
	local b = T.TextButton(parent, label, font or T.F.tab)
	b:SetSize(math.max(64, b.Label:GetStringWidth() + 28), 34)
	b.glow:ClearAllPoints()
	b.glow:SetPoint("BOTTOMLEFT", 12, 0)
	b.glow:SetPoint("BOTTOMRIGHT", -12, 0)
	b.hl = T.Hover(b, 0.35)
	return b
end

-- Progress bar: a paper track and a solid fill; colour by state (T.Heat for progress). Ticks mark milestones and
-- turn ink2 once passed. Never thinner than 2px once started, so 1/300 still reads as begun.
function T.Bar(parent, width, height, c)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize(width, height)
	bar.width = width
	bar.track = T.Fill(bar, "BACKGROUND", C.paper3, 1)
	bar.fill = bar:CreateTexture(nil, "ARTWORK")
	bar.fill:SetPoint("TOPLEFT")
	bar.fill:SetPoint("BOTTOMLEFT")
	bar.ticks = {}
	function bar:SetColor(col)
		self.colour = col
		self.fill:SetColorTexture(unpackC(col))
	end
	function bar:SetTicks(ratios)
		self.tickRatios = ratios or {}
		for i, ratio in ipairs(self.tickRatios) do
			local t = self.ticks[i]
			if not t then
				t = self:CreateTexture(nil, "OVERLAY")
				t:SetWidth(1)
				self.ticks[i] = t
			end
			t:ClearAllPoints()
			t:SetPoint("TOP", self, "TOPLEFT", self.width * ratio, 2)
			t:SetPoint("BOTTOM", self, "BOTTOMLEFT", self.width * ratio, -2)
			t:Show()
		end
		for i = #self.tickRatios + 1, #self.ticks do self.ticks[i]:Hide() end
		self:Paint()
	end
	function bar:Paint()
		local ratio = self.ratio or 0
		for i, t in ipairs(self.ticks) do
			local at = self.tickRatios and self.tickRatios[i]
			if at then t:SetColorTexture(unpackC(ratio >= at and C.ink2 or C.muted, ratio >= at and 0.9 or 0.45)) end
		end
	end
	function bar:SetValue(ratio)
		ratio = math.max(0, math.min(1, ratio or 0))
		self.ratio = ratio
		local w = ratio > 0 and math.max(2, self.width * ratio) or 0
		self.fill:SetWidth(math.max(w, 1))
		self.fill:SetShown(ratio > 0)
		self:Paint()
	end
	-- the ramp step for its own ratio, unless the caller set a colour
	function bar:SetHeatValue(ratio)
		self:SetValue(ratio)
		self:SetColor(T.Heat(ratio))
	end
	bar:SetColor(c or C.heat4)
	bar:SetValue(0)
	return bar
end

-- The Legacy points bar (0.9.1) on Blizzard's profession rank bar (Blizzard_ProfessionsTemplates,
-- ProfessionsRankBarTemplate, 453 wide): Professions-skillbar-bg behind, Professions-skillbar-frame over it, the fill
-- 5px in and 3px down, 18px tall, 12px narrower than the bar, and the count centred on the fill. The fill is the first
-- frame of Blizzard's animated one (Skillbar_Fill_Flipbook_DefaultBlue: 2 columns, rows = height / 34 as Blizzard
-- counts them; on Forever 880x33, so one row of two 440px frames), cut at the ratio so
-- it never stretches. The art keeps its own height; only the width follows the bar. Without the profession art it
-- falls back to the Legacy panel's own bar (Legacy-Progressbar-*). bar.Text holds the count. SetValue(ratio).
local FLIPBOOK_COLS, FLIPBOOK_FRAME_H = 2, 34 -- ProfessionsRankBarMixin:Update
-- 1.1: the fills a bar can wear, the game's profession rank-bar art ("Skillbar_Fill_Flipbook_" .. the Enum.Profession
-- key, Blizzard_ProfessionsRankBar.lua). Options lists the ones this client has (Options > Window > Bar fill).
T.BAR_FILLS = {
	{ "DefaultBlue", "Default blue" }, { "Alchemy", "Alchemy" }, { "Blacksmithing", "Blacksmithing" },
	{ "Enchanting", "Enchanting" }, { "Engineering", "Engineering" }, { "Leatherworking", "Leatherworking" },
	{ "Tailoring", "Tailoring" }, { "Herbalism", "Herbalism" }, { "Mining", "Mining" }, { "Skinning", "Skinning" },
	{ "Cooking", "Cooking" }, { "Fishing", "Fishing" }, { "FirstAid", "First Aid" }, { "Inscription", "Inscription" },
	{ "Jewelcrafting", "Jewelcrafting" }, { "Archaeology", "Archaeology" },
}
function T.FillAtlas(kit) return "Skillbar_Fill_Flipbook_" .. tostring(kit or "DefaultBlue") end
function T.BarFillOptions()
	local out = {}
	for _, f in ipairs(T.BAR_FILLS) do
		if AtlasRect(T.FillAtlas(f[1])) then out[#out + 1] = { f[1], ns.L[f[2]] } end
	end
	return out
end
local function CurrentFill()
	local kit = ns.Core and ns.Core.db and ns.Core.db.settings.barFill
	return (kit and AtlasRect(T.FillAtlas(kit))) and kit or "DefaultBlue"
end
-- The outline's and background's ends keep their own pixels however wide the bar is (SetTextureSliceMargins,
-- SimpleTextureBaseAPI): stretching the 451px art to 950px doubled its caps, looked blocky and let a full fill poke
-- past them (the user's 1.1 feedback).
local BAR_SLICE = { 14, 6, 14, 6 }
local function Slice(tex)
	if tex.SetTextureSliceMargins then tex:SetTextureSliceMargins(BAR_SLICE[1], BAR_SLICE[2], BAR_SLICE[3], BAR_SLICE[4]) end
end
local bars = setmetatable({}, { __mode = "k" }) -- every profession-style bar, to repaint when the fill setting changes
function T.SetBarFill()
	for bar in pairs(bars) do bar:SetFill(CurrentFill()) end
end
local GROW_TIME = 0.6

function T.ProgressBar(parent, width)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize(width, 24)
	bar.width = width
	bar.bg = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	bar.fill = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	bar.frame = bar:CreateTexture(nil, "ARTWORK", nil, 3)
	local bgInfo = C_Texture and ns.Live.try(C_Texture.GetAtlasInfo, "Professions-skillbar-bg")
	local frameInfo = C_Texture and ns.Live.try(C_Texture.GetAtlasInfo, "Professions-skillbar-frame")
	if bgInfo and frameInfo then
		bar.kind = "profession"
		T.Atlas(bar.bg, "Professions-skillbar-bg")
		bar.bg:SetPoint("TOPLEFT")
		bar.bg:SetSize(width, bgInfo.height or 26)
		Slice(bar.bg)
		T.Atlas(bar.frame, "Professions-skillbar-frame")
		bar.frame:SetPoint("TOPLEFT")
		bar.frame:SetSize(width - 2, frameInfo.height or 29)
		Slice(bar.frame)
		bar.fill:SetPoint("TOPLEFT", 5, -3)
		bar.fill:SetHeight(18)
		bar.fullW = width - 12
		bars[bar] = true
		bar.textY = -12
	else
		-- LegacyChallengePointSummaryTemplate: a 16px Legacy-Progressbar-BG, the fill over its top 13px, the frame
		-- 8px past the sides, 7px above and 10px below
		bar.kind = "legacy"
		bar.bg:SetPoint("TOPLEFT", 0, -4)
		bar.bg:SetPoint("TOPRIGHT", 0, -4)
		bar.bg:SetHeight(16)
		if not T.Atlas(bar.bg, "Legacy-Progressbar-BG") then bar.bg:SetColorTexture(unpackC(C.paper)) end
		bar.fill:SetPoint("TOPLEFT", bar.bg, "TOPLEFT", 0, 0)
		bar.fill:SetHeight(13)
		bar.fullW = width
		if not T.Atlas(bar.fill, "Legacy-Progressbar-Fill") then bar.fill:SetColorTexture(unpackC(C.heat4)) end
		bar.frame:SetPoint("TOPLEFT", bar.bg, "TOPLEFT", -8, 7)
		bar.frame:SetPoint("BOTTOMRIGHT", bar.bg, "BOTTOMRIGHT", 8, -7)
		if not T.Atlas(bar.frame, "Legacy-Progressbar-Frame") then bar.frame:Hide() end
		bar.textY = -10
	end
	bar.Text = T.Text(bar, T.F.num, C.ink, "CENTER")
	bar.Text:SetPoint("CENTER", bar, "TOP", 0, bar.textY)

	-- one frame of the fill's flipbook (2 columns, 34px rows); row picks the frame, for the shimmer while it grows
	function bar:SetFill(kit)
		if self.kind ~= "profession" then return end
		local atlas = T.FillAtlas(kit)
		local info = AtlasRect(atlas)
		if info and T.Atlas(self.fill, atlas) then
			self.fillKit = kit
			local w = (info.rightTexCoord - info.leftTexCoord) / FLIPBOOK_COLS
			local rows = math.max(1, math.floor(info.height / FLIPBOOK_FRAME_H + 0.5))
			local h = (info.bottomTexCoord - info.topTexCoord) / rows
			self.tc = { info.leftTexCoord, w, info.topTexCoord, h, rows }
		elseif not T.Atlas(self.fill, "Legacy-Progressbar-Fill") then
			self.tc = nil
			self.fill:SetColorTexture(unpackC(C.heat4))
		end
		self:Paint(self.shownRatio or self.ratio or 0, 0)
	end
	-- draw a ratio, on flipbook frame `frame` (0-based, both columns count)
	function bar:Paint(ratio, frame)
		self.shownRatio = ratio
		self.fill:SetWidth(math.max(1, self.fullW * ratio))
		if self.tc then
			local l, w, t, h, rows = unpack(self.tc)
			frame = (frame or 0) % (rows * FLIPBOOK_COLS)
			local col, row = frame % FLIPBOOK_COLS, math.floor(frame / FLIPBOOK_COLS)
			local left = l + col * w
			self.fill:SetTexCoord(left, left + w * math.max(0.001, ratio), t + row * h, t + (row + 1) * h)
		end
		self.fill:SetShown(ratio > 0)
		if self.onPaint then self.onPaint(ratio) end
	end
	-- animate (1.1, the map banner): grow from what's shown to the new ratio, the flipbook playing once on the way
	function bar:SetValue(ratio, animate)
		ratio = math.max(0, math.min(1, ratio or 0))
		self.ratio = ratio
		local from = self.shownRatio or 0
		if not (animate and T.Animated()) or math.abs(from - ratio) < 0.001 then
			self:SetScript("OnUpdate", nil)
			self:Paint(ratio, 0)
			return
		end
		local t0, frames = GetTime(), self.tc and self.tc[5] * FLIPBOOK_COLS or 1
		self:SetScript("OnUpdate", function(f)
			local p = math.min(1, (GetTime() - t0) / GROW_TIME)
			local eased = 1 - (1 - p) * (1 - p) * (1 - p)
			if p >= 1 then
				f:SetScript("OnUpdate", nil)
				f:Paint(ratio, 0) -- exactly the value (from + (ratio - from) can round below it)
			else
				f:Paint(from + (ratio - from) * eased, math.floor(p * frames))
			end
		end)
	end
	-- the x of a ratio along the fill, for marks placed on the bar (the reward track)
	function bar:At(ratio) return (self.kind == "profession" and 5 or 0) + self.fullW * ratio end
	if bar.kind == "profession" then bar:SetFill(CurrentFill()) end
	bar:SetValue(0)
	return bar
end

-- Segmented control: options in one rounded track; the selected one is a quiet paper3 pill in ink (Hallmark: a
-- selection is a colour or a soft background; ember stays for the primary action and the tab marker).
-- options = { {value, label} }; onSelect(value) on click.
function T.Segmented(parent, options, onSelect, height, font)
	local s = CreateFrame("Frame", nil, parent)
	height = height or 26
	T.Rounded(s, "Chip", "BACKGROUND", C.paper)
	T.Rounded(s, "ChipEdge", "BORDER", C.rule)
	s.buttons = {}
	local x = 2
	for i, opt in ipairs(options) do
		local b = CreateFrame("Button", nil, s)
		b.value = opt[1]
		b.fill = T.Rounded(b, "Chip", "ARTWORK", C.paper3)
		b.fillEdge = T.Rounded(b, "ChipEdge", "OVERLAY", C.muted, 0.6)
		b.fillEdge:Hide()
		b.fill:Hide()
		b.hover = T.Rounded(b, "Chip", "HIGHLIGHT", C.paper3, 0.6)
		b.Label = T.Text(b, font or T.F.label, C.ink2, "CENTER")
		b.Label:SetPoint("CENTER", 0, 0)
		b.Label:SetText(opt[2])
		local w = math.max(36, b.Label:GetStringWidth() + 20)
		b:SetSize(w, height - 4)
		b:SetPoint("TOPLEFT", s, "TOPLEFT", x, -2)
		b:SetScript("OnClick", function(self)
			s:SetValue(self.value)
			if onSelect then onSelect(self.value) end
		end)
		s.buttons[i] = b
		x = x + w
		if i == 1 then b.first = true end
	end
	s:SetSize(x + 2, height)
	function s:SetValue(value)
		for _, b in ipairs(self.buttons) do
			local on = b.value == value
			local was = b.on
			b.on = on
			b.fill:SetShown(on)
			b.fillEdge:SetShown(on)
			b.Label:SetTextColor(unpackC(on and C.head or C.ink2))
			if on and not was and self.value ~= nil then T.Reveal(b.fill, T.DUR_MICRO) end
		end
		self.value = value
	end
	function s:SetLabel(value, text)
		for _, b in ipairs(self.buttons) do if b.value == value then b.Label:SetText(text) end end
	end
	return s
end

-- On/off as a WoW checkbox (the settings panel's checkbox-minimal), same API as before: SetChecked, onChange.
function T.Switch(parent, onChange)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(24, 24)
	b.box = b:CreateTexture(nil, "ARTWORK")
	b.box:SetAllPoints()
	if not T.Atlas(b.box, "checkbox-minimal", "Box") then b.box:SetVertexColor(unpackC(C.muted)) end
	b.tick = b:CreateTexture(nil, "OVERLAY")
	b.tick:SetAllPoints()
	if not T.Atlas(b.tick, "checkmark-minimal", "Check") then b.tick:SetVertexColor(unpackC(C.head)) end
	b.hover = T.Fill(b, "HIGHLIGHT", C.ink, 0.1)
	function b:SetChecked(v)
		self.checked = v and true or false
		self.tick:SetShown(self.checked)
	end
	b:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
		if onChange then onChange(self.checked) end
	end)
	b:SetChecked(false)
	return b
end

-- Button: Blizzard's red UIPanelButtonTemplate, the one every Forever window uses. style is kept for callers
-- ("primary", "danger") but Blizzard draws every action button the same way.
function T.ActionButton(parent, label, style)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetText(label)
	b.Label = b:GetFontString()
	b:SetSize(math.max(96, b.Label:GetStringWidth() + 36), 22)
	b.style = style
	return b
end

-- Checkbox with a label; onChange(checked) fires on click.
function T.Checkbox(parent, label, onChange)
	local b = CreateFrame("Button", nil, parent)
	b.boxFrame = CreateFrame("Frame", nil, b)
	b.boxFrame:SetSize(16, 16)
	b.boxFrame:SetPoint("LEFT")
	b.boxFill = T.Rounded(b.boxFrame, "Chip", "BACKGROUND", C.paper)
	b.box = T.Tex(b.boxFrame, "Box", "ARTWORK", C.muted)
	b.box:SetAllPoints()
	b.tick = T.Tex(b.boxFrame, "Check", "OVERLAY", C.head)
	b.tick:SetSize(14, 14)
	b.tick:SetPoint("CENTER", 1, 1)
	b.Label = T.Text(b, T.F.body, C.ink2)
	b.Label:SetPoint("LEFT", b.boxFrame, "RIGHT", 8, 0)
	b.Label:SetText(label)
	b:SetSize(b.Label:GetStringWidth() + 28, 22)
	function b:SetChecked(v)
		self.checked = v and true or false
		self.tick:SetShown(self.checked)
	end
	function b:SetLabel(text)
		self.Label:SetText(text)
		self:SetWidth(self.Label:GetStringWidth() + 28)
	end
	b:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
		if onChange then onChange(self.checked) end
	end)
	b:SetChecked(false)
	return b
end
