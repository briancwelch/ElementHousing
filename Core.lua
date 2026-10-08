local addonName, EH = ...
_G.ElementHousing = EH
EH.name, EH.version = addonName, "2.0.6"
EH.entries, EH.results, EH.byID = {}, {}, {}
EH.defaults = {
    schema = 2,
    settings = {
        width = 1140, height = 720, locked = false,
        resizable = true, rowHeight = 48, detailsWidth = 330,
        showModels = true, modelHeight = 210, modelRotation = true,
        showTooltips = true, showSource = true, showCounts = true,
        rememberFilters = true, professionMissingOnly = true, includeUnknownProfession = true,
        includeUnknownZone = false, includeSubzones = true, autoZone = true,
        superTrack = true, waypointConfirm = true, showAutosaves = false,
        blueprintMissingOnly = false, batchSize = 24, minimap = true,
    },
    filters = { ownership = "all", source = "all", zone = "all", profession = "all",
        search = "", sort = "name", placement = "all", quality = "all", size = "all", tags = {},
        expansion = "all", currency = "all", hidePvP = false },
    favorites = {}, blueprints = {}, presets = {}, vendorSources = {}, minimap = { minimapPos = 220 },
}

-- Reject restricted API values before inspecting or persisting them.
function EH:Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

-- Call an optional native getter without turning absent or pending data into an error.
function EH:Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok and self:Readable(a) and self:Readable(b) and self:Readable(c) then return a, b, c end
end

-- Copy plain saved settings without sharing nested default tables.
function EH:Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = self:Copy(child) end
    return result
end

-- Fill missing settings while preserving older account-wide favorites and preferences.
function EH:Defaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            self:Defaults(target[key], value)
        elseif type(target[key]) ~= type(value) then target[key] = value end
    end
end

-- Clamp saved numeric input to finite, practical values.
function EH:Clamp(value, low, high, fallback)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        value = fallback or low
    end
    return math.max(low, math.min(high, value))
end

-- Remove chat markup from metadata used for literal searches and editable labels.
function EH:Plain(value)
    if type(value) ~= "string" or not self:Readable(value) then return "" end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
end

-- Display short, useful status messages without creating another window.
function EH:Notify(message)
    self.notice = message
    if self.frame and self.frame:IsShown() then self:RenderStatus() end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff3fc7ebElementHousing:|r " .. message) end
end

-- Apply a setting immediately to addon-owned controls.
function EH:SetSetting(key, value)
    self.db.settings[key] = value
    if key == "minimap" and self.dbicon then
        self.db.minimap.hide = not value
        if value then self.dbicon:Show(self.name) else self.dbicon:Hide(self.name) end
    end
    if self.frame then self:ApplyWindowSettings(); self:LayoutWindow() end
    if key == "includeSubzones" and self.searcher then self:BuildFacets() end
    self:ApplyFilters()
    if self.frame then self:RenderDetails(); self:RenderBlueprints() end
end

-- Refresh only when an addon view is visible; coalesce native update events.
function EH:ScheduleRefresh()
    self.dirty = true
    if self.loading or self.refreshPending or not self.frame or not self.frame:IsShown() then return end
    self.refreshPending = true
    C_Timer.After(0.25, function()
        self.refreshPending = false
        if self.frame and self.frame:IsShown() then self:RefreshCatalog() end
    end)
end

-- Register a standard launcher so WindTools and other LibDBIcon collectors can find it.
function EH:RegisterLauncher()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not ldb or not icon then return end
    local object = ldb:NewDataObject(self.name, {
        type = "launcher", text = self.name, icon = self.brandIcon,
        -- Left click toggles the native window; right click opens configuration.
        OnClick = function(_, button)
            if button == "RightButton" then self:OpenOptions() else self:Toggle() end
        end,
        -- Explain both launcher actions using the collector's supplied tooltip.
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(self:Brand() .. " " .. self.version)
            tooltip:AddLine("Left click: catalog, blueprints, and housing information", 1, 1, 1)
            tooltip:AddLine("Right click: settings", 1, 1, 1)
        end,
    })
    self.dbicon, self.broker = icon, object
    self.db.minimap.hide = not self.db.settings.minimap
    if not icon:IsRegistered(self.name) then icon:Register(self.name, object, self.db.minimap) end
end

-- Initialize saved data and integrations after all optional dependencies have loaded.
function EH:Initialize()
    if self.initialized then return end
    if not ElvUI or not ElvUI[1] then self:Notify("ElvUI is required to use ElementHousing."); return false end
    self.initialized = true
    ElementHousingDB = type(ElementHousingDB) == "table" and ElementHousingDB or {}
    self.db = ElementHousingDB
    self:Defaults(self.db, self.defaults)
    self.db.settings.scale, self.db.settings.opacity, self.db.settings.fontSize = nil, nil, nil
    self.db.schema = 2
    if not self.db.settings.rememberFilters then self.db.filters = self:Copy(self.defaults.filters) end
    self.filters = self.db.filters
    self:UpdateProfessions()
    self:RegisterMedia()
    self:RegisterOptions()
    self:RegisterLauncher()
    SLASH_ELEMENTHOUSING1, SLASH_ELEMENTHOUSING2 = "/eh", "/elementhousing"
    -- Keep slash navigation available even when the minimap collector hides an icon.
    SlashCmdList.ELEMENTHOUSING = function(text)
        text = (text or ""):lower():match("^%s*(.-)%s*$")
        if text == "config" or text == "settings" then self:OpenOptions()
        elseif text == "blueprints" then self:Show("blueprints")
        elseif text == "neighborhood" or text == "house" then self:Show(text)
        elseif text == "missing" then self:SetFilter("ownership", "missing"); self:Show("catalog")
        elseif text == "zone" then
            self:SetFilter("ownership", "missing"); self:SetFilter("zone", "current"); self:Show("catalog")
        elseif text == "catalog" then self:Show("catalog")
        else self:Toggle() end
    end
end

EH.events = CreateFrame("Frame")
-- Dispatch documented data notifications without touching Blizzard housing frames.
EH.events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then EH:Initialize(); return end
    if not EH.initialized then return end
    if EH.housingEvents and EH.housingEvents[event] then EH:HousingEvent(event, ...); return end
    if event == "PLAYER_REGEN_ENABLED" and EH.housingDeferred then
        EH.housingDeferred = nil; EH:RefreshHousingInfo()
    end
    if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        EH:ApplyWindowSettings(); EH:LayoutWindow(); return
    end
    if event == "MERCHANT_SHOW" then EH.merchantOpen = true; EH:ObserveMerchant(); return end
    if event == "MERCHANT_UPDATE" then EH:ObserveMerchant(); return end
    if event == "MERCHANT_CLOSED" then EH.merchantOpen = false; return end
    if event == "GET_ITEM_INFO_RECEIVED" then
        local itemID, success = ...
        if EH:Readable(itemID) and EH:Readable(success) and EH.requestedItems
            and EH.requestedItems[itemID] and success then EH:ScheduleRefresh() end
        return
    end
    if event:find("HOUSING_BLUEPRINT", 1, true) then EH:BlueprintEvent(event, ...); return end
    if event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE" then EH:UpdateProfessions() end
    if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        EH:RefreshHousingInfo()
        if EH.db.settings.autoZone and EH.filters.zone == "current" then EH:ApplyFilters(); EH:ScheduleRefresh() end
        return
    end
    if (event == "HOUSING_STORAGE_UPDATED" or event == "HOUSING_STORAGE_ENTRY_UPDATED")
        and EH.view == "blueprints" and EH.frame and EH.frame:IsShown()
        and EH.blueprintCode and not EH.blueprintPending and not InCombatLockdown() then
        EH:InspectBlueprint(EH.blueprintCode, EH.blueprintName)
    end
    EH:ScheduleRefresh()
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "SKILL_LINES_CHANGED",
    "TRADE_SKILL_LIST_UPDATE", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
    "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "GET_ITEM_INFO_RECEIVED",
    "RECEIVED_ACHIEVEMENT_LIST", "ACHIEVEMENT_EARNED",
    "HOUSING_STORAGE_UPDATED", "HOUSING_STORAGE_ENTRY_UPDATED", "TRACKABLE_INFO_UPDATE",
    "TRACKING_TARGET_INFO_UPDATE", "CONTENT_TRACKING_UPDATE",
    "HOUSING_CATALOG_CATEGORY_UPDATED", "HOUSING_CATALOG_SUBCATEGORY_UPDATED",
    "HOUSING_BLUEPRINT_COLLECTION_RECEIVED", "HOUSING_BLUEPRINT_COLLECTION_FAILURE",
    "HOUSING_BLUEPRINT_CONTENTS_RECEIVED", "HOUSING_BLUEPRINT_CONTENTS_FAILURE",
    "HOUSING_BLUEPRINTS_AVAILABILITY_CHANGED", "HOUSING_BLUEPRINT_EXPORT_SUCCESS",
    "HOUSING_BLUEPRINT_RENAME_SUCCESS", "HOUSING_BLUEPRINT_DELETE_SUCCESS" }) do
    -- Older clients may lack an event; the catalog reports API availability explicitly.
    pcall(EH.events.RegisterEvent, EH.events, event)
end
