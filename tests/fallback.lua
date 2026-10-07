-- Exercise the actual standalone initialization path in a second isolated client.
ElvUI = nil
C_AddOns.IsAddOnLoaded = function() return false end
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) settingsPanel = panel; return { name = name } end,
    RegisterAddOnCategory = function(category) settingsRegistered = category.name end,
}
EH:Initialize()
Check(EH.frame == nil and EH.configFrame == nil and not settingsPanel:IsShown(), "Standalone login creates no visible settings/catalog window")
Check(settingsRegistered == "ElementHousing", "Native settings category registers without ElvUI")
Check(EH:Icon("housing"):find("Interface\\Icons\\", 1, true), "Missing nMediaTag uses a native icon")
EH:OpenOptions()
Check(EH.configFrame:IsShown(), "Standalone settings open without a third-party engine")
Check(EH:Show() and EH.frame:IsShown(), "Standalone catalog opens")
EH:SetSetting("resizable", false)
Check(not EH.resizeGrip:IsShown(), "Standalone settings apply to native window")
EH.searcher, C_HousingCatalog = nil, nil
EH:RefreshCatalog()
Check(EH.catalogStatus:find("unavailable", 1, true), "Absent API reports availability without crashing")
C_HousingBlueprint = nil
EH:RefreshBlueprints()
Check(EH.blueprintStatus:find("unavailable", 1, true), "Absent blueprint API reports availability")
