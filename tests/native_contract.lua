-- This harness implements explicit public frame contracts; unknown methods fail immediately.
frames, timers, checks, messages = {}, {}, 0, {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
ACCEPT, CANCEL = "Accept", "Cancel"
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD = 0, 0
StaticPopupDialogs, UISpecialFrames, SlashCmdList = {}, {}, {}
Enum = { UIMapType = { Zone = 3 }, HousingCatalogEntryType = { Decor = 1 },
    ContentTrackingType = { Decor = 3 }, ContentTrackingTargetType = { Vendor = 1, JournalEncounter = 0, Achievement = 2, Profession = 3, Quest = 4 },
    ContentTrackingResult = { Success = 0, DataPending = 1, Failure = 2 },
    HousingBlueprintContentType = { Decor = 3 }, HousingResult = { Success = 0 }, HousingBudgetType = { DecorPlacement = 1, RoomPlacement = 0, PetDecor = 2 },
    HousingBlueprintType = { Room = 2 }, HousingBlueprintUnmetRequirementFlags = { InsufficientBudget = 1, MissingDecor = 8 } }
-- Requirement masks are individual powers of two; expose the native bit contract for those masks.
bit = { band = function(value, mask) return value % (mask * 2) >= mask and mask or 0 end }
tinsert, wipe = table.insert, function(t) for k in pairs(t) do t[k] = nil end return t end
strmatch, strfind, strsub, format, strlower = string.match, string.find, string.sub, string.format, string.lower
securecallfunction = function(fn, ...) return fn(...) end
issecretvalue = function(value) return value == "SECRET" end
combat, waypoint, shifted = false, nil, false
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return shifted end
debugstack = function() return "offline stack" end
GetLocale = function() return "enUS" end
GetMoneyString = function(value) return value .. " copper" end
GetTime = function() return 1 end
GetCursorPosition = function() return 1, 1 end
GetMinimapShape = function() return "ROUND" end
GetCVar = function() return "1" end
GetCVarBool = function() return false end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
-- Drain scheduled work with a limit that exposes accidental refresh loops.
function Drain()
    local count = 0
    while #timers > 0 do
        count = count + 1; assert(count < 1000, "Unbounded timer scheduling")
        table.remove(timers, 1)()
    end
end
-- Assert behavior, counting only explicit outcome checks.
function Check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local methods = {}
-- Allocate a native-like widget that reports unsupported methods instead of accepting everything.
local function Widget(kind, name, parent)
    local frame = setmetatable({ kind = kind, nameID = name, parent = parent, shown = true,
        scripts = {}, points = {}, alpha = 1, scale = 1 }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
-- Store simple rendering state without simulating the Blizzard renderer.
for _, method in ipairs({ "SetFrameStrata", "SetFrameLevel", "SetFixedFrameStrata", "SetFixedFrameLevel",
    "SetClampedToScreen", "SetMovable", "SetResizable", "EnableMouse", "EnableMouseWheel",
    "RegisterForClicks", "RegisterForDrag", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetTextInsets", "SetAutoFocus", "SetMaxLetters", "SetFont", "SetJustifyH", "SetWordWrap",
    "SetOrientation", "SetValueStep", "SetObeyStepOnDrag", "SetPreferModelCollisionBounds", "SetModelByFileID",
    "SetOrder", "SetDuration", "SetFromAlpha", "SetToAlpha", "SetStartDelay", "SetToFinalAlpha", "Play", "Stop",
    "SetTextColor", "SetTexCoord", "SetDesaturated", "SetStatusBarColor", "SetStatusBarTexture" }) do
    methods[method] = function(self, ...) self["state_" .. method] = { ... } end
end
-- Verify native button texture setters require an asset, while Texture:SetTexture can clear it.
for _, method in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture", "SetHighlightTexture", "SetThumbTexture" }) do
    methods[method] = function(self, asset)
        assert(type(asset) == "string" or type(asset) == "number", method .. " requires an asset")
        self[method .. "Value"] = Widget("Texture", nil, self); self[method .. "Value"]:SetTexture(asset)
    end
end
-- Create child objects with explicit contracts.
methods.CreateTexture = function(self) return Widget("Texture", nil, self) end
methods.CreateFontString = function(self) return Widget("FontString", nil, self) end
methods.CreateAnimationGroup = function(self) return Widget("AnimationGroup", nil, self) end
methods.CreateAnimation = function(self) return Widget("Animation", nil, self) end
methods.GetHighlightTexture = function(self) return self.SetHighlightTextureValue end
methods.GetThumbTexture = function(self) return self.SetThumbTextureValue end
-- Register native ElvUI template and font state, including its shared refresh registries.
methods.SetTemplate = function(self, template)
    self.template = template
    local engine = ElvUI[1]
    engine.frames[self] = true
    self:SetBackdropColor(unpack(template == "Transparent" and engine.media.backdropfadecolor or engine.media.backdropcolor))
    self:SetBackdropBorderColor(unpack(self.forcedBorderColors or engine.media.bordercolor))
end
methods.FontTemplate = function(self, fontName, fontSize, fontStyle, skip)
    if NativeFontTemplate then return NativeFontTemplate(self, fontName, fontSize, fontStyle, skip) end
    local engine = ElvUI[1]
    if not skip then engine.texts[self] = { fontName = fontName, fontSize = fontSize, fontStyle = fontStyle } end
    self:SetFont(fontName or engine.media.normFont, fontSize or engine.db.general.fontSize, fontStyle or engine.db.general.fontStyle)
end
methods.StyleButton = function(self)
    self:SetHighlightTexture(ElvUI[1].media.blankTex)
    self:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.3)
end
-- Preserve native call ordering when installing a secure post-hook on an addon method.
hooksecurefunc = function(object, name, callback)
    local original = object[name]
    object[name] = function(...) original(...); callback(...) end
end
methods.SetTexture = function(self, value) assert(value == nil or type(value) == "string" or type(value) == "number"); self.texture = value end
methods.SetAtlas = function(self, value) assert(type(value) == "string"); self.atlas = value end
methods.GetVertexColor = function() return 1, 1, 1, 1 end
methods.SetVertexColor = function(self, ...) self.color = { ... } end
methods.SetText = function(self, value) self.textValue = value; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end end
methods.GetText = function(self) return self.textValue or "" end
methods.SetSize = function(self, width, height)
    self.width, self.height = width, height
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, width, height) end
end
methods.SetWidth = function(self, width) self.width = width end
methods.SetHeight = function(self, height) self.height = height end
methods.GetWidth = function(self) return self.width or (self.parent and self.parent:GetWidth()) or 800 end
methods.GetHeight = function(self) return self.height or (self.parent and math.max(1, self.parent:GetHeight() - 110)) or 600 end
methods.GetCenter = function() return 500, 350 end
methods.GetEffectiveScale = function(self) return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
methods.SetScale = function(self, value) self.scale = value end
methods.SetAlpha = function(self, value) self.alpha = value end
methods.SetResizeBounds = function(self, ...) self.bounds = { ... } end
methods.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end
methods.SetAllPoints = function(self, parent) self.allPoints = parent end
methods.ClearAllPoints = function(self) self.points = {} end
methods.IsObjectType = function(self, kind) return self.kind == kind end
methods.GetParent = function(self) return self.parent end
methods.GetName = function(self) return self.nameID end
methods.Show = function(self) local changed = not self.shown; self.shown = true; if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
methods.Hide = function(self) local changed = self.shown; self.shown = false; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
methods.IsShown = function(self) return self.shown end
methods.IsVisible = function(self) return self.shown and (not self.parent or self.parent:IsVisible()) end
methods.SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end
methods.SetEnabled = function(self, enabled) self.enabled = enabled end
methods.Enable = function(self) self.enabled = true end
methods.Disable = function(self) self.enabled = false end
methods.SetScript = function(self, event, callback) self.scripts[event] = callback end
methods.GetScript = function(self, event) return self.scripts[event] end
methods.HookScript = function(self, event, callback)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; callback(...) end
end
methods.RegisterEvent = function(self, event) self.events = self.events or {}; self.events[event] = true end
methods.UnregisterEvent = function(self, event) self.events[event] = nil end
methods.SetScrollChild = function(self, child) self.scrollChild = child end
methods.SetFocus = function(self) self.focus = true end
methods.ClearFocus = function(self) self.focus = false end
methods.HighlightText = function(self) self.highlighted = true end
methods.GetStringHeight = function(self)
    local size = self.state_SetFont and self.state_SetFont[2] or 13
    local width = self.width or 800
    local height = 0
    for line in ((self.textValue or "") .. "\n"):gmatch("(.-)\n") do
        height = height + math.max(1, math.ceil(#line * size * .58 / math.max(1, width))) * (size + 2)
    end
    return height
end
methods.GetVerticalScroll = function(self) return self.verticalScroll or 0 end
methods.SetVerticalScroll = function(self, value) self.verticalScroll = value end
-- Keep the native map viewport's horizontal pan separate from the dashboard's vertical scroll.
methods.GetHorizontalScroll = function(self) return self.horizontalScroll or 0 end
methods.SetHorizontalScroll = function(self, value) self.horizontalScroll = value end
methods.ClearLines = function(self) self.tooltipLines = {} end
methods.SetMinMaxValues = function(self, min, max) self.min, self.max = min, max end
methods.SetValue = function(self, value) self.value = value; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end end
methods.StartMoving = function(self) self.moving = true end
methods.StartSizing = function(self) self.sizing = true end
methods.StopMovingOrSizing = function(self) self.moving, self.sizing = false, false end
methods.ClearModel = function(self) self.modelCleared = true end
methods.TransitionToModelSceneID = function(self, id, transition, modification, force)
    assert(id and transition ~= nil and modification ~= nil and force ~= nil)
    self.sceneID, self.actor = id, Widget("Actor", nil, self)
end
methods.GetActorByTag = function(self, tag) assert(tag == "decor", "Wrong native actor tag"); return self.actor end
methods.SetModelScene = function(self, scene) assert(scene.kind == "ModelScene"); self.scene = scene end
methods.SetOwner = function() end
methods.AddLine = function(self, value) self.tooltipLines = self.tooltipLines or {}; self.tooltipLines[#self.tooltipLines + 1] = value end
methods.SetItemByID = function(_, id) assert(type(id) == "number") end
-- Enforce the model template names used by the current native housing preview.
CreateFrame = function(kind, name, parent, template)
    if kind == "ModelScene" then assert(template == "PanningModelSceneMixinTemplate") end
    return Widget(kind, name, parent)
end
UIParent = Widget("Frame", "UIParent"); UIParent:SetSize(1920, 1080)
Minimap = Widget("Frame", "Minimap", UIParent)
GameTooltip = Widget("GameTooltip", "GameTooltip", UIParent)
StaticPopup_Show = function(which, _, _, data) popup = { which = which, data = data } end
C_AddOns = { IsAddOnLoaded = function(name) return name == "ElvUI_mMediaTag" end, LoadAddOn = function() return true end }
GetProfessions = function() return 1, 2 end
GetProfessionInfo = function(index) return index == 1 and "Jewelcrafting" or "Mining", nil, 100, 100, nil, nil, index == 1 and 755 or 186 end
C_TradeSkillUI = { GetTradeSkillDisplayName = function() return nil end,
    GetProfessionInfoBySkillLineID = function(id) return { professionID = id } end,
    GetProfessionInfoByRecipeID = function(id) return id == 900 and { professionID = 2905, parentProfessionID = 165 } or nil end }
maps = { [100] = { mapID = 100, name = "Elwynn Forest", mapType = 3, parentMapID = 1 },
    [101] = { mapID = 101, name = "Goldshire Inn", mapType = 5, parentMapID = 100 },
    [200] = { mapID = 200, name = "Westfall", mapType = 3, parentMapID = 1 } }
currentMap = 101
playerPositions = { [100] = { x = 0.42, y = 0.62 }, [101] = { x = 0.2, y = 0.3 } }
C_Map = { GetMapInfo = function(id) return maps[id] end,
    GetMapChildrenInfo = function() return { maps[100], maps[200] } end,
    GetBestMapForUnit = function() return currentMap end,
    -- Return independent native map vectors so merchant observations snapshot the location.
    GetPlayerMapPosition = function(id)
        local point = playerPositions[id]
        if point then return { x = point.x, y = point.y, GetXY = function(self) return self.x, self.y end } end
    end,
    CanSetUserWaypointOnMap = function(id) return maps[id] ~= nil end,
    HasUserWaypoint = function() return waypoint ~= nil end,
    SetUserWaypoint = function(point) waypoint = point end }
UiMapPoint = { CreateFromCoordinates = function(mapID, x, y) return { mapID = mapID, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(value) supertracked = value end }
targets, locations, vendors = {}, {}, {}
C_ContentTracking = { GetCurrentTrackingTarget = function(_, id) local t = targets[id]; if t then return t[1], t[2] end end,
    GetVendorTrackingInfo = function(id) return vendors[id] end,
    GetEncounterTrackingInfo = function() return nil end,
    GetBestMapForTrackable = function(_, id, ignore) assert(ignore == true); local point = locations[id]; return point and point.status or 2, point and point.mapID end,
    -- Waypoint coordinates belong to the requested map, not whichever map the test last used.
    GetNextWaypointForTrackable = function(_, id, mapID)
        local point = locations[id]
        if point and point.mapID == mapID then return point.status, point end
        return Enum.ContentTrackingResult.Failure
    end }
itemMetadata, itemRequests, currencyInfo, merchantItems = {}, {}, {}, {}
EXPANSION_NAME0, EXPANSION_NAME1, EXPANSION_NAME10, EXPANSION_NAME11 = "Classic", "The Burning Crusade", "The War Within", "Midnight"
C_Item = {
    -- Expose the documented fifteen-field item tuple, including expansion ID zero.
    GetItemInfo = function(id)
        local info = itemMetadata[id]
        if info then return info.name or "Item", nil, 1, 1, 1, nil, nil, 1, nil, 1, 0, 1, 1, 1, info.expansionID end
    end,
    RequestLoadItemDataByID = function(id) itemRequests[#itemRequests + 1] = id end,
}
C_CurrencyInfo = { GetCurrencyInfo = function(id) return currencyInfo[id] end }
UnitName = function() return merchantName end
UnitGUID = function() return merchantGUID end
GetMerchantNumItems = function() return #merchantItems end
GetMerchantItemID = function(index) return merchantItems[index] and merchantItems[index].itemID end
C_MerchantFrame = { GetItemInfo = function(index) return merchantItems[index] end }
GetMerchantItemCostInfo = function(index) return #(merchantItems[index].costs or {}) end
GetMerchantItemCostItem = function(index, costIndex)
    local cost = merchantItems[index].costs[costIndex]
    if cost then return 1, cost.amount, cost.link end
end
catalog = {}
-- Supply a complete independent searcher contract and deterministic result callback.
C_HousingCatalog = { CreateCatalogSearcher = function()
    local searcher = {}
    for _, method in ipairs({ "SetAutoUpdateOnParamChanges", "SetCollected", "SetUncollected", "SetStoredOnly",
        "SetAllowedIndoors", "SetAllowedOutdoors", "SetBaseVariantOnly", "SetCustomizableOnly", "SetFirstAcquisitionBonusOnly",
        "SetEditorModeContext", "SetSearchText", "SetFilteredCategoryID", "SetFilteredSubcategoryID", "SetAllInFilterTagGroup" }) do
        searcher[method] = function(self, value) self[method .. "State"] = value end
    end
    searcher.SetResultsUpdatedCallback = function(self, fn) self.callback = fn end
    searcher.RunSearch = function(self) self.callback() end
    searcher.IsSearchInProgress = function() return false end
    searcher.GetCatalogSearchResults = function()
        local ids = {}
        for _, info in ipairs(catalog) do ids[#ids + 1] = { recordID = info.recordID, entryType = info.entryType, variantIdentifier = 0 } end
        return ids
    end
    return searcher
end,
    GetCatalogEntryInfo = function(id) for _, info in ipairs(catalog) do if info.recordID == id.recordID then return info end end end,
    -- Merchant item IDs resolve through the real catalog identifier contract.
    GetCatalogEntryInfoByItem = function(itemID) for _, info in ipairs(catalog) do if info.itemID == itemID then return info end end end,
    GetAllFilterTagGroups = function() return { { groupID = 1, groupName = "Style", tags = { { tagID = 7, tagName = "Alliance" } } } } end,
    GetCatalogCategoryInfo = function(id) return { name = "Category " .. id } end,
    GetCatalogSubcategoryInfo = function(id) return { name = "Subcategory " .. id } end }
blueprintRequests = {}
C_HousingBlueprint = { GetFeatureAvailability = function() return 0 end,
    GetImportAvailability = function() return 0 end, GetExportAvailability = function() return 0 end,
    IsShareCodeValid = function(code) return code:match("^BP%-%w+$") ~= nil end,
    UpdateBlueprintStringFromInput = function(code) return code end,
    RequestBlueprintCollection = function() collectionRequested = true end,
    RequestBlueprintContents = function(code) blueprintRequests[#blueprintRequests + 1] = code end }
HousingFramesUtil = { ShowBlueprintImport = function(code) importedCode = code end, ShowBlueprintExport = function() exportOpened = true end }
-- Capture modern menu descriptions and the closures attached to each user choice.
local menuMethods = {}
menuMethods.CreateButton = function(self, label, action) local item = setmetatable({ label = label, action = action, items = {} }, { __index = menuMethods }); self.items[#self.items + 1] = item; return item end
menuMethods.CreateRadio = function(self, label, selected, action) local item = self:CreateButton(label, action); item.selected = selected; return item end
menuMethods.CreateCheckbox = menuMethods.CreateRadio
menuMethods.SetScrollMode = function() end
MenuUtil = { CreateContextMenu = function(owner, build) lastMenu = setmetatable({ items = {} }, { __index = menuMethods }); build(owner, lastMenu) end }
-- Track ElvUI's public registries without depending on its complete engine or renderer.
ElvUI = { { Options = { name = "ElvUI", args = {} }, db = { general = { fontSize = 13, fontStyle = "OUTLINE" } },
    private = {}, texts = {}, frames = {}, statusBars = {},
    media = { normFont = STANDARD_TEXT_FONT, normTex = "Interface\\AddOns\\ElvUI\\Media\\Textures\\NormTex",
        blankTex = "Interface\\Buttons\\WHITE8X8", rgbvaluecolor = { 0.3, 0.8, 0.9 },
        backdropcolor = { 0.08, 0.08, 0.08, 1 }, backdropfadecolor = { 0.08, 0.08, 0.08, 0.4 }, bordercolor = { 0.2, 0.2, 0.2, 1 } },
    Libs = { EP = { RegisterPlugin = function(_, name, fn) pluginCallback = fn; pluginName = name end } },
    ToggleOptions = function(_, path) optionsPath = path end,
    UpdateMedia = function() end,
    UIScale = function(self) UIParent:SetScale(self.global.general.UIScale) end,
    global = { general = { UIScale = 1 } },
    CanFlagSlug = function() return false end,
    SetFontShadow = function(_, widget, _, shadow) widget.fontShadow = shadow end,
    CoroutineUpdate = function(_, callback, registry) for widget, info in pairs(registry) do callback(widget, info) end end,
    -- Native registries apply the current media without storing addon-specific appearance settings.
    RegisterStatusBar = function(self, bar) self.statusBars[bar] = true end,
    UpdateFontTemplates = function(self) for widget, info in pairs(self.texts) do widget:FontTemplate(info.fontName, info.fontSize, info.fontStyle, true) end end,
    UpdateStatusBars = function(self) for bar in pairs(self.statusBars) do
        if bar.kind == "StatusBar" then bar:SetStatusBarTexture(self.media.normTex) else bar:SetTexture(self.media.normTex) end
    end end,
    UpdateFrames = function(self) for frame in pairs(self.frames) do frame:SetTemplate(frame.template) end end,
} }
