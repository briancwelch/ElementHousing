-- A missing required engine must not initialize saved data, launchers, or configuration.
ElvUI = nil
C_AddOns.IsAddOnLoaded = function() return false end
ElementHousingDB = { favorites = { ["decor:42"] = true } }
Check(EH:Initialize() == false and not EH.initialized, "Missing ElvUI cannot initialize ElementHousing")
Check(EH.db == nil and EH.broker == nil and EH.options == nil, "Required-engine failure creates no integrations")
Check(EH.frame == nil and EH.configFrame == nil and SlashCmdList.ELEMENTHOUSING == nil, "Missing ElvUI opens no window or slash route")
Check(ElementHousingDB.favorites["decor:42"] and messages[1]:find("ElvUI is required", 1, true), "Missing dependency preserves saved data and explains the requirement")
