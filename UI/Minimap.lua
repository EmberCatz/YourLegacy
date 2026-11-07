-- Minimap button. No embedded libraries:
-- * When another addon has loaded LibDataBroker + LibDBIcon (EnhanceQoL, Questie, GatherLite... do), the button is a
--   LibDBIcon button. Minimap button bins (EnhanceQoL's button sink, MinimapButtonButton, ...) know those and can
--   collect it; LibDBIcon keeps the position in settings.minimapIcon.
-- * Otherwise our own button, dragged around the rim. It's positioned only when created, dragged or reset, never on
--   a data refresh: an addon that moved it into its own frame keeps it there (0.5 re-anchored it on every refresh,
--   which pulled it back out of button bins).
local _, ns = ...
local T, Live = ns.Theme, ns.Live

local Minimap_ = {}
ns.Minimap = Minimap_

local function Tooltip(tooltip)
	tooltip:AddLine("Your Legacy", 1, 0.97, 0.92)
	local c = Live.Challenges()
	tooltip:AddLine(string.format(ns.L["%d of %d Legacy points"], Live.Earned(), math.max(Live.MaxAvailable(), c.total)), T.unpack(T.C.gold))
	tooltip:AddLine(ns.L["Left-click to open, right-click for options."], T.unpack(T.C.muted))
end

local function Click(_, button)
	if button == "RightButton" then ns.Core:OpenOptions() else ns.Core:Toggle() end
end

local function Library(name)
	local stub = _G.LibStub
	return type(stub) == "table" and stub.GetLibrary and stub:GetLibrary(name, true) or nil
end

local function Place(button)
	local angle = math.rad(tonumber(ns.Core:Setting("minimapAngle")) or 215)
	local radius = (Minimap:GetWidth() / 2) + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OwnButton()
	local b = CreateFrame("Button", "YourLegacyMinimapButton", Minimap)
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(T.MEDIA .. "Icon")
	icon:SetSize(22, 22)
	icon:SetPoint("CENTER")
	local ring = T.Tex(b, "MinimapRing", "BACKGROUND")
	ring:SetAllPoints()
	local hl = T.Tex(b, "MinimapRing", "HIGHLIGHT", T.C.ink, 0.35)
	hl:SetAllPoints()
	hl:SetBlendMode("ADD") -- brightens the gold band; the dark well adds nothing, so the icon isn't dimmed
	b:SetScript("OnClick", Click)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		Tooltip(GameTooltip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- Dragging: OnUpdate runs only while the mouse is down on the button, and only while it sits on the minimap.
	b:SetScript("OnDragStart", function(self)
		if self:GetParent() ~= Minimap then return end
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			local deg = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
			ns.Core.db.settings.minimapAngle = math.floor(deg + 0.5)
			Place(self)
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	Place(b)
	return b
end

function Minimap_:Create()
	if self.button or self.icon or not Minimap then return end
	local ldb = Library("LibDataBroker-1.1")
	if ldb and not self.broker then
		self.broker = ldb:NewDataObject("YourLegacy", {
			type = "launcher", label = "Your Legacy", icon = T.MEDIA .. "Icon",
			OnClick = Click, OnTooltipShow = Tooltip,
		})
	end
	local dbicon = Library("LibDBIcon-1.0")
	if dbicon and self.broker then
		self.icon = dbicon
		dbicon:Register("YourLegacy", self.broker, ns.Core.db.settings.minimapIcon)
	else
		self.button = OwnButton()
	end
	self:Update()
end

-- Shows or hides the button (Options > Minimap). Never moves it.
function Minimap_:Update()
	local show = ns.Core:Setting("minimap") and true or false
	if self.icon then
		ns.Core.db.settings.minimapIcon.hide = not show
		if show then self.icon:Show("YourLegacy") else self.icon:Hide("YourLegacy") end
	elseif self.button then
		self.button:SetShown(show)
	end
end

-- Options > Minimap > Reset position.
function Minimap_:ResetPosition()
	ns.Core.db.settings.minimapAngle = 215
	if self.icon then
		ns.Core.db.settings.minimapIcon.minimapPos = 215
		if self.icon.Refresh then self.icon:Refresh("YourLegacy", ns.Core.db.settings.minimapIcon) end
	elseif self.button and self.button:GetParent() == Minimap then
		Place(self.button)
	end
end

function Minimap_:UsesLibrary() return self.icon ~= nil end
