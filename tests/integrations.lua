-- Exercise all optional addon combinations while ElvUI remains the required engine.
local E = ElvUI[1]
catalog = { { recordID = 42, entryType = 1, itemID = 1042, name = "Housing sample", sourceText = "",
    totalNumStored = 1, totalNumPlaced = 0, remainingRedeemable = 0, quality = 3,
    categoryIDs = { 1 }, subcategoryIDs = { 2 }, dataTagsByID = { [7] = true }, asset = 1234 } }
C_AddOns.IsAddOnLoaded = function(name)
    return name == "ElvUI" or name == "ElvUI_mMediaTag" and nmediaLoaded or name == "ElvUI_WindTools" and windtoolsLoaded
end
ElementHousingDB = { settings = { scale = 1.4, opacity = 0.45, fontSize = 19 }, favorites = { ["decor:42"] = true } }
E.db.general.fontSize, E.db.general.fontStyle = 16, "NONE"
E.media.normFont, E.media.normTex = "Fonts\\UserFont.ttf", "Interface\\UserBar"
E.Options.args.general = { type = "group", order = 1, name = "General" }
E.Options.args.unitframe = { type = "group", order = 2, name = "UnitFrames" }
E.Options.args.tagGroup = { type = "group", order = 3, name = "Available Tags" }
E.Options.args.profiles = { type = "group", order = 4, name = "Profiles" }
E.Options.args.plugins = { type = "group", order = 5, name = "Plugins" }
shadowCalls = 0
if windtoolsLoaded then
    E.private.WT = { skins = { enable = true, shadow = true } }
    WindTools = { { Modules = { Skins = {
        -- Record only calls on ElementHousing-owned windows; no third-party frame is modified.
        CreateShadow = function(_, frame) shadowCalls = shadowCalls + 1; frame.windShadowApplied = true end,
    } } } }
end
local general = E.Options.args.general
EH:Initialize()
Check(E.Options.args.ElementHousing == nil, "Plugin options do not enter ElvUI's original core-page snapshot")
SnapshotNativeOptions()
if nmediaLoaded then E.Options.args.mMT = { type = "group", name = "mMediaTag & Tools" } end
if windtoolsLoaded then E.Options.args.WindTools = { type = "group", name = "WindTools" } end
local optional = E.Options.args.WindTools or E.Options.args.mMT
pluginCallback()
Check(EH.db.settings.scale == nil and EH.db.settings.opacity == nil and EH.db.settings.fontSize == nil, "Remove legacy appearance overrides")
Check(EH.db.favorites["decor:42"] and not EH.settingDefinitions.scale and not EH.settingDefinitions.opacity and not EH.settingDefinitions.fontSize, "Preserve user data while ElvUI owns appearance")
Check(EH.broker.icon == EH.brandIcon and EH.brandIcon:find("ElementHousing\\Media\\Icon.tga", 1, true), "All optional combinations use the original branded launcher")
for _, icon in ipairs({ "housing", "collection", "book", "shop", "teleports", "achievement", "professions", "dungeon", "quest", "general", "colors", "refresh", "heart", "menu", "tags", "browser", "help" }) do
    local resolved = EH:Icon(icon)
    Check(resolved:find(nmediaLoaded and "ElvUI_mMediaTag" or "ElementHousing\\Media\\", 1, true), "Resolve control artwork for " .. icon)
end
Check(EH:Icon("../not-an-icon") == EH.brandIcon, "Unknown glyph names use the owned housing icon")
local legacy = RenderNativeSidebar({ general = general, ElementHousing = { order = -1, name = EH:Brand() } }, { "general", "ElementHousing" })
Check(legacy[1] == "ElementHousing", "Reproduce the released negative-order bug in ElvUI's actual sidebar")
local sorted, separators = RenderNativeSidebar(E.Options.args)
Check(sorted[1] == "general" and sorted[5] == "plugins" and sorted[6] == "ElementHousing", "Native ElvUI places ElementHousing first in the bottom plugin group")
Check(separators[#separators] == "plugins", "ElementHousing appears below ElvUI's plugin separator")
Check(not windtoolsLoaded or sorted[7] == "WindTools", "WindTools follows ElementHousing in the plugin group")
Check(not nmediaLoaded or sorted[#sorted] == "mMT", "nMediaTag remains with the other plugin pages")
local aceSorted = SortNativeOptions(E.Options.args)
Check(aceSorted[1] == "general" and aceSorted[5] == "plugins", "Native AceConfig also keeps the plugin group after core pages")
pluginCallback(); pluginCallback()
Check(E.Options.args.general == general and (not optional or E.Options.args.WindTools == optional or E.Options.args.mMT == optional), "Plugin registration preserves existing options")
Check(EH:Show() and EH.windowReady, "ElvUI-only and optional-addon clients open the catalog")
Drain()
local launcher = LibStub("LibDBIcon-1.0"):GetMinimapButton("ElementHousing")
Check(launcher:GetName() == "LibDBIcon10_ElementHousing" and launcher.icon.texture == EH.brandIcon, "Use the standard collector-compatible LibDBIcon button")
Check(not windtoolsLoaded or EH.frame.windShadowApplied, "Optional WindTools applies configured window shadows")
Check(windtoolsLoaded or shadowCalls == 0, "ElvUI-only clients never need WindTools skin APIs")
for widget, info in pairs(E.texts) do
    Check(info.fontName == nil and info.fontSize == nil and info.fontStyle == nil, "No registered label or input overrides native font settings")
    Check(widget.state_SetFont[1] == E.media.normFont and widget.state_SetFont[2] == 16 and widget.state_SetFont[3] == "", "New controls inherit the actual ElvUI font defaults")
end
Check(E.frames[EH.frame] and E.frames[EH.details] and EH.details.template == "Transparent", "Native frame registry controls panel templates")
Check(EH.details.state_SetBackdropColor[4] == E.media.backdropfadecolor[4], "Use native transparent backdrop opacity")
Check(E.statusBars[EH.blueprintProgress] and E.statusBars[EH.scrollbar:GetThumbTexture()], "Register status bar and thumb in ElvUI's media registry")
Check(EH.blueprintProgress.state_SetStatusBarTexture[1] == E.media.normTex and EH.scrollbar:GetThumbTexture().texture == E.media.normTex, "Use the user's status-bar texture immediately")
E.media.normFont, E.media.normTex = "Fonts\\ChangedFont.ttf", "Interface\\ChangedBar"
E.db.general.fontSize, E.db.general.fontStyle = 20, "OUTLINE"
E.media.rgbvaluecolor[1], E.media.rgbvaluecolor[2], E.media.rgbvaluecolor[3] = 0.9, 0.2, 0.4
E.media.backdropfadecolor[4], E.media.bordercolor[1] = 0.7, 0.8
E:UpdateMedia(); E:UpdateFontTemplates(); E:UpdateStatusBars(); E:UpdateFrames()
for widget in pairs(E.texts) do
    Check(widget.state_SetFont[1] == E.media.normFont and widget.state_SetFont[2] == 20 and widget.state_SetFont[3] == "OUTLINE", "Existing controls follow actual native font refresh")
end
Check(EH.rows[1].name:GetHeight() == 24 and EH.rows[1]:GetHeight() >= 56, "Row layout accommodates ElvUI font-size changes without clipping")
Check(EH.blueprintProgress.state_SetStatusBarTexture[1] == E.media.normTex and EH.scrollbar:GetThumbTexture().texture == E.media.normTex, "Existing status media follows native texture refresh")
Check(EH.blueprintProgress.state_SetStatusBarColor[1] == 0.9 and EH.scrollbar:GetThumbTexture().color[2] == 0.2, "Accent controls follow native value colors")
Check(EH.details.state_SetBackdropColor[4] == 0.7 and EH.details.state_SetBackdropBorderColor[1] == 0.8, "Native template refresh retains configured backdrop and borders")
E.global.general.UIScale = 0.75
E:UIScale()
Check(EH.frame.scale == 1 and EH.frame:GetEffectiveScale() == 0.75 and EH.searchBox:GetEffectiveScale() == 0.75, "Windows and child controls inherit ElvUI UI scale once")
EH:SetSetting("width", 1200)
Check(E.db.general.fontSize == 20 and E.global.general.UIScale == 0.75 and E.media.normTex == "Interface\\ChangedBar", "Addon geometry never changes ElvUI appearance settings")
UIParent:SetSize(900, 650)
EH.events.scripts.OnEvent(EH.events, "UI_SCALE_CHANGED")
Check(EH.frame:GetWidth() <= 870 and EH.frame:GetHeight() <= 620, "Scale and display changes recompute usable bounds")
if windtoolsLoaded then E.private.WT.skins.enable = false end
EH:TextDialog("Name", "", function() end)
Check(not windtoolsLoaded or not EH.textDialog.windShadowApplied, "Disabled WindTools skins do not add window shadows")
E:UpdateFontTemplates()
Check(EH.textDialog.edit.state_SetFont[1] == E.media.normFont and EH.textDialog.edit.state_SetFont[2] == 20, "Later-created dialogs join the same native font registry")
EH:OpenOptions()
Check(optionsPath == "ElementHousing" and EH.configFrame == nil, "Every supported client uses ElvUI configuration natively")
