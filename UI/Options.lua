-- Options in Blizzard's Settings panel (Esc > Options > AddOns > Your Legacy).
-- Signatures verified against Blizzard_Settings_Shared (Forever 1.60.1).
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local function proxy(category, key, varType, name, default)
	return Settings.RegisterProxySetting(category, "YourLegacy_" .. key, varType, name, default,
		function() return ns.Core:Setting(key) end,
		function(value) ns.Core:SetSetting(key, value) end)
end

function Options:Register()
	if self.category or type(Settings) ~= "table" or type(Settings.RegisterVerticalLayoutCategory) ~= "function" then return end
	local ok, err = pcall(function()
		local category = Settings.RegisterVerticalLayoutCategory("Your Legacy")
		local bool, number = Settings.VarType.Boolean, Settings.VarType.Number

		local scale = proxy(category, "scale", number, L["Window size"], 1)
		local sliderOptions = Settings.CreateSliderOptions(0.7, 1.3, 0.05)
		if MinimalSliderWithSteppersMixin and sliderOptions.SetLabelFormatter then
			sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return string.format("%d%%", v * 100 + 0.5) end)
		end
		Settings.CreateSlider(category, scale, sliderOptions, L["Scales the Your Legacy window. Your UI scale still applies on top."])

		Settings.CreateCheckbox(category, proxy(category, "minimap", bool, L["Minimap button"], true),
			L["Show the Your Legacy button on the minimap. The AddOns compartment button is always there."])
		Settings.CreateCheckbox(category, proxy(category, "locked", bool, L["Lock window position"], false),
			L["Stop the window from being dragged."])
		Settings.CreateCheckbox(category, proxy(category, "combatHide", bool, L["Close in combat"], true),
			L["Close the window when combat starts. It doesn't update during combat either way."])
		Settings.CreateCheckbox(category, proxy(category, "announce", bool, L["Announce earned challenges"], true),
			L["Print a chat line when you earn a Legacy challenge."])

		Settings.RegisterAddOnCategory(category)
		self.category = category
	end)
	if not ok then ns.Core:Print(L["couldn't add the options panel: "] .. tostring(err)) end
end

function Options:Open()
	if not self.category then self:Register() end
	if not self.category then return false end
	Settings.OpenToCategory(self.category:GetID())
	return true
end
