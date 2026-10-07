local _, EH = ...
local labels = {
    vendor = { "Vendor", "Vendors", "VENDOR", "HOUSING_DECOR_SOURCE_VENDOR" },
    drop = { "Drop", "Drops", "Loot", "LOOT", "HOUSING_DECOR_SOURCE_DROP" },
    achievement = { "Achievement", "Achievements", "ACHIEVEMENTS", "HOUSING_DECOR_SOURCE_ACHIEVEMENT" },
    quest = { "Quest", "Quests", "QUESTS_LABEL", "HOUSING_DECOR_SOURCE_QUEST" },
    profession = { "Profession", "Professions", "Crafted", "PROFESSIONS", "HOUSING_DECOR_SOURCE_PROFESSION" },
}

-- Build a deterministic display/search label while keeping every distinct acquisition value.
function EH:SourceValues(values)
    local names = {}
    for name in pairs(values or {}) do names[#names + 1] = name end
    table.sort(names)
    return table.concat(names, ", ")
end

-- Match literal profession names as complete words, avoiding matches such as Mining in Undermining.
local function HasProfessionName(text, name)
    name = name:lower()
    if name == "" then return false end
    local first, last = text:find(name, 1, true)
    while first do
        local before, after = text:sub(first - 1, first - 1), text:sub(last + 1, last + 1)
        if not before:find("[%w_\128-\255]") and not after:find("[%w_\128-\255]") then return true end
        first, last = text:find(name, last + 1, true)
    end
    return false
end

-- Identify all known source professions and native recipe links, preserving alternate routes.
function EH:ParseSources(text)
    local sources, professions = {}, {}
    local plain = self:Plain(text):lower()
    for kind, words in pairs(labels) do
        for _, word in ipairs(words) do
            local localized = _G[word] or word
            localized = self:Plain(localized):gsub("%%s", ""):gsub(":", ""):lower()
            if localized ~= "" and plain:find(localized .. ":", 1, true) then sources[kind] = true end
        end
    end
    if text:find("|Hachievement:", 1, true) then sources.achievement = true end
    if text:find("|Hquest:", 1, true) then sources.quest = true end
    if text:find("|Htrade:", 1, true) then sources.profession = true end
    for id, name in pairs(self.professionNames) do
        if HasProfessionName(plain, name) then professions[id] = true; sources.profession = true end
    end
    for recipeID in text:gmatch("|Hspell:(%d+)") do
        local info = self:Call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID, tonumber(recipeID))
        local id = self:ProfessionID(nil, info)
        if id then professions[id] = true; sources.profession = true end
    end
    return sources, professions
end

-- Enrich a decor record from documented native tracking metadata without starting tracking.
function EH:ReadSources(entry)
    local info, tracking = entry.info, C_ContentTracking
    entry.sourceText = type(info.sourceText) == "string" and info.sourceText or ""
    entry.sources, entry.professionIDs = self:ParseSources(entry.sourceText)
    entry.maps, entry.vendorNames, entry.zoneNames, entry.ambiguousZones = {}, {}, {}, {}
    entry.currencyTypes, entry.vendorCurrencies = {}, {}
    -- Localized source label lines supplement tracking when its structured target is unavailable.
    for line in self:Plain(entry.sourceText):gmatch("[^\r\n]+") do
        local label, value = line:match("^%s*([^:]+):%s*(.-)%s*$")
        if label and value ~= "" then
            for _, word in ipairs(labels.vendor) do
                local name = self:Plain(_G[word] or word):gsub("%%s", ""):gsub(":", "")
                if label:lower() == name:lower() then
                    entry.vendorName, entry.vendorNames[value] = entry.vendorName or value, true
                end
            end
            for _, word in ipairs({ "Zone", "Location", ZONE or "Zone", LOCATION_COLON or "Location" }) do
                if label:lower() == word:gsub(":", ""):lower() then
                    entry.zoneName, entry.zoneNames[value] = entry.zoneName or value, true
                end
            end
        end
    end
    local typeID = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Decor or 3
    local targets = Enum and Enum.ContentTrackingTargetType or {}
    if tracking then
        local target, targetID = self:Call(tracking.GetCurrentTrackingTarget, typeID, info.recordID)
        local result, mapID = self:Call(tracking.GetBestMapForTrackable, typeID, info.recordID, true)
        if result == (Enum and Enum.ContentTrackingResult and Enum.ContentTrackingResult.Success or 0) and mapID then
            entry.maps[mapID] = true
            local map = self:Call(C_Map and C_Map.GetMapInfo, self:ZoneMap(mapID))
            entry.zoneName = entry.zoneName or (map and map.name)
            if map then entry.zoneNames[map.name] = true end
            entry.mapID = mapID
            -- Untracked decor can still expose its acquisition target through a native waypoint.
            if target == nil then
                local status, location = self:Call(tracking.GetNextWaypointForTrackable, typeID, info.recordID, mapID)
                if status == Enum.ContentTrackingResult.Success and location then target, targetID = location.targetType, location.targetID end
            end
        elseif result == (Enum and Enum.ContentTrackingResult and Enum.ContentTrackingResult.DataPending or 1) then
            entry.pendingSource = true
        end
        entry.targetType, entry.targetID = target, targetID
        local kind = ({ [targets.Vendor or 1] = "vendor", [targets.JournalEncounter or 0] = "drop",
            [targets.Achievement or 2] = "achievement", [targets.Profession or 3] = "profession",
            [targets.Quest or 4] = "quest" })[target]
        if kind then entry.sources[kind] = true end
        if kind == "profession" and targetID then
            local profession = self:Call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID, targetID)
            local id = self:ProfessionID(nil, profession)
            if id then entry.professionIDs[id] = true end
        end
        if entry.sources.vendor then
            local vendor = self:Call(tracking.GetVendorTrackingInfo, info.recordID)
            if vendor then
                entry.vendorName, entry.zoneName = vendor.creatureName or entry.vendorName, vendor.zoneName or entry.zoneName
                entry.waypointVendorName = vendor.creatureName
                entry.currencyType, entry.cost = vendor.currencyType, vendor.cost
                local currency = vendor.currencyType
                if self:Readable(currency) and type(currency) == "number" and currency >= 0
                    and currency < math.huge and currency % 1 == 0 then
                    self:AddCurrency(entry, currency == 0 and "gold" or ("currency:" .. currency), vendor.creatureName)
                elseif self:Readable(currency) and currency == nil and self:Readable(vendor.cost) and type(vendor.cost) == "number"
                    and vendor.cost >= 0 and vendor.cost < math.huge then
                    self:AddCurrency(entry, "gold", vendor.creatureName)
                end
            end
        end
        if kind == "drop" and targetID then
            local encounter = self:Call(tracking.GetEncounterTrackingInfo, targetID)
            if encounter then entry.encounterName, entry.instanceName = encounter.encounterName, encounter.instanceName end
        end
    end
    self:ReadObservedSources(entry)
    entry.isPvP = self:IsPvPDecor(entry)
    if entry.vendorName then entry.vendorNames[entry.vendorName] = true end
    if entry.zoneName then entry.zoneNames[entry.zoneName] = true end
    for name in pairs(entry.zoneNames) do
        local zoneIDs = self.mapNames and self.mapNames[name:lower()]
        local identified = false
        for mapID in pairs(entry.maps) do
            local map = self:Call(C_Map and C_Map.GetMapInfo, self:ZoneMap(mapID))
            if map and map.name:lower() == name:lower() then identified = true end
        end
        if type(zoneIDs) == "table" then
            local first = next(zoneIDs)
            if first and not next(zoneIDs, first) then entry.maps[first] = true
            else
                -- Shared names, such as Shadowmoon Valley, cannot establish an exact source map.
                entry.ambiguousZones[name:lower()] = true
                if not identified then entry.unknownLocation = true end
            end
        elseif not identified then entry.unknownLocation = true end
    end
    local kinds, names = {}, {}
    for _, kind in ipairs({ "vendor", "drop", "achievement", "quest", "profession" }) do
        if entry.sources[kind] then
            kinds[#kinds + 1] = self.sourceNames[kind]
            if kind ~= "profession" then entry.nonProfessionRoute = true end
        end
    end
    if #kinds == 0 then entry.sources.unknown = true end
    entry.sourceLabel = #kinds > 0 and table.concat(kinds, " / ") or "Unknown / other"
    for id in pairs(entry.professionIDs) do names[#names + 1] = self.professionNames[id] or tostring(id) end
    entry.searchFields = {
        name = self:Plain(entry.name):lower(), source = self:Plain(entry.sourceText .. " " .. entry.sourceLabel):lower(),
        zone = self:Plain(self:SourceValues(entry.zoneNames)):lower(), vendor = self:Plain(self:SourceValues(entry.vendorNames)):lower(),
        profession = table.concat(names, " "):lower(),
        id = tostring(info.recordID) .. " " .. tostring(info.itemID or ""),
    }
    entry.searchText = table.concat({ entry.searchFields.name, entry.searchFields.source, entry.searchFields.zone,
        entry.searchFields.vendor, entry.searchFields.profession, entry.searchFields.id,
        self:Plain(entry.instanceName or ""):lower() }, " ")
end

-- Convert a native record into the small, normalized representation used by every view.
function EH:MakeEntry(info)
    local entry = { info = info, name = info.name or "Unknown decor",
        key = tostring(info.entryType) .. ":" .. tostring(info.recordID), categories = {}, subcategories = {} }
    entry.stored = (info.totalNumStored or 0) + (info.remainingRedeemable or 0)
    entry.owned = entry.stored + (info.totalNumPlaced or 0)
    for _, id in ipairs(info.categoryIDs or {}) do entry.categories[id] = true end
    for _, id in ipairs(info.subcategoryIDs or {}) do entry.subcategories[id] = true end
    self:ReadSources(entry)
    self:ReadExpansion(entry)
    return entry
end

-- Create one independent searcher, with all base decor enabled and no Blizzard UI dependency.
function EH:EnsureSearcher()
    if self.searcher then return true end
    if not C_HousingCatalog or not C_HousingCatalog.CreateCatalogSearcher then
        self.catalogStatus = "Housing APIs unavailable. ElementHousing requires Midnight 12.1.0+."
        return false
    end
    self.searcher = C_HousingCatalog.CreateCatalogSearcher()
    self.searcher:SetAutoUpdateOnParamChanges(false)
    -- Deliver result updates only into this addon's cache.
    self.searcher:SetResultsUpdatedCallback(function() self:ReadResults() end)
    return true
end

-- Read result records in bounded batches; discard stale or hidden-window work.
function EH:ReadResults()
    if not self.frame or not self.frame:IsShown() then self.dirty = true; return end
    self.generation = (self.generation or 0) + 1
    local generation = self.generation
    local ids = self.searcher:GetCatalogSearchResults() or {}
    local entries, byID, seen, index = {}, {}, {}, 1
    self.loading = true
    -- Each scheduled batch checks its identity before publishing data or scheduling more work.
    local function readBatch()
        if self.generation ~= generation or not self.frame:IsShown() then return end
        local last = math.min(#ids, index + self:Clamp(self.db.settings.batchSize, 8, 64, 24) - 1)
        for i = index, last do
            local id = ids[i]
            if type(id) == "table" and id.entryType == (Enum.HousingCatalogEntryType.Decor or 1)
                and not seen[id.recordID] then
                seen[id.recordID] = true
                local info = self:Call(C_HousingCatalog.GetCatalogEntryInfo, id)
                if info then
                    local entry = self:MakeEntry(info)
                    entries[#entries + 1], byID[info.recordID] = entry, entry
                end
            end
        end
        index = last + 1
        self.catalogStatus = string.format("Reading decor: %d / %d", math.min(last, #ids), #ids)
        self:RenderStatus()
        if index <= #ids then C_Timer.After(0, readBatch)
        else
            self.entries, self.byID, self.loading, self.catalogStatus = entries, byID, false, nil
            if self.selected then self.selected = byID[self.selected.info.recordID] end
            self:BuildFacets(); self:ApplyFilters(); self:RenderDetails()
            if self.dirty then self:ScheduleRefresh() end
        end
    end
    readBatch()
end

-- Refresh native ownership and source metadata; defer work during combat and while hidden.
function EH:RefreshCatalog()
    if not self.frame or not self.frame:IsShown() then self.dirty = true; return end
    if InCombatLockdown() then
        self.dirty, self.catalogStatus = true, "Catalog refresh will resume after combat."
        self:RenderStatus(); return
    end
    if not self:EnsureSearcher() then self:RenderStatus(); return end
    if not self.mapNames then
        self.mapNames = {}
        -- Traverse the public world-map hierarchy so off-world zones are indexed as well.
        local rootMap, seen = 947, {}
        for _ = 1, 8 do
            seen[rootMap] = true
            local info = self:Call(C_Map and C_Map.GetMapInfo, rootMap)
            if not info or not info.parentMapID or info.parentMapID == 0 or seen[info.parentMapID] then break end
            rootMap = info.parentMapID
        end
        local maps = self:Call(C_Map and C_Map.GetMapChildrenInfo, rootMap, Enum.UIMapType.Zone, true) or {}
        for _, map in ipairs(maps) do
            local name = map.name:lower()
            self.mapNames[name] = self.mapNames[name] or {}
            self.mapNames[name][map.mapID] = true
        end
    end
    self.dirty, self.loading, self.catalogStatus, self.notice = false, true, "Loading catalog...", nil
    local searcher = self.searcher
    searcher:SetCollected(true); searcher:SetUncollected(true); searcher:SetStoredOnly(false)
    searcher:SetAllowedIndoors(true); searcher:SetAllowedOutdoors(true); searcher:SetBaseVariantOnly(true)
    searcher:SetCustomizableOnly(false); searcher:SetFirstAcquisitionBonusOnly(false)
    searcher:SetEditorModeContext(nil); searcher:SetSearchText(nil)
    searcher:SetFilteredCategoryID(nil); searcher:SetFilteredSubcategoryID(nil)
    self.tagGroups = C_HousingCatalog.GetAllFilterTagGroups() or {}
    for _, group in ipairs(self.tagGroups) do searcher:SetAllInFilterTagGroup(group.groupID, true) end
    self:RenderStatus()
    local generation = self.generation
    searcher:RunSearch()
    if not searcher:IsSearchInProgress() and self.generation == generation then self:ReadResults() end
end

-- Build source-aware vendor/zone choices and native category/subcategory labels.
function EH:BuildFacets()
    self.zones, self.vendors, self.categories, self.subcategories, self.subcategoryParents = {}, {}, {}, {}, {}
    self.expansions, self.currencies = {}, {}
    for _, entry in ipairs(self.entries) do
        for id in pairs(entry.expansionIDs) do self.expansions[tostring(id)] = self:ExpansionName(id) end
        for key in pairs(entry.currencyTypes) do self.currencies[key] = self:CurrencyName(key) end
        for name in pairs(entry.vendorNames) do self.vendors[name] = name end
        for name in pairs(entry.zoneNames) do
            local matched = false
            for mapID in pairs(entry.maps) do
                local map = self:Call(C_Map.GetMapInfo, self:ZoneMap(mapID))
                if map and map.name:lower() == name:lower() then matched = true end
            end
            if not matched then self.zones["name:" .. name] = name .. " (location name)" end
        end
        for mapID in pairs(entry.maps) do
            local zoneID = self.db.settings.includeSubzones and self:ZoneMap(mapID) or mapID
            local map = self:Call(C_Map.GetMapInfo, zoneID)
            if map then self.zones[tostring(zoneID)] = map.name end
        end
        for id in pairs(entry.categories) do
            if not self.categories[id] then
                local category = self:Call(C_HousingCatalog.GetCatalogCategoryInfo, id)
                self.categories[id] = category and category.name or tostring(id)
            end
        end
        for id in pairs(entry.subcategories) do
            if not self.subcategories[id] then
                local category = self:Call(C_HousingCatalog.GetCatalogSubcategoryInfo, id)
                self.subcategories[id] = category and category.name or tostring(id)
                self.subcategoryParents[id] = category and category.parentCategoryID
            end
        end
    end
end

-- Toggle account-wide favorites using stable base-decor keys.
function EH:Favorite(entry)
    if not entry then return end
    self.db.favorites[entry.key] = not self.db.favorites[entry.key] or nil
    self:ApplyFilters(); self:RenderDetails()
end

-- Validate a vendor destination before replacing any existing user waypoint.
function EH:VendorDestination(entry)
    if not entry or not entry.sources.vendor then return nil, "This decor has no known vendor route." end
    if InCombatLockdown() then return nil, "Vendor waypoints are unavailable during combat." end
    local tracking, map = C_ContentTracking, C_Map
    if not map or not map.SetUserWaypoint or not UiMapPoint then
        return nil, "Native vendor waypoints are unavailable on this client."
    end
    local observed = self:ObservedVendorDestination(entry, true)
    if observed then return observed end
    if not tracking or not tracking.GetNextWaypointForTrackable then
        return self:ObservedVendorDestination(entry), "Native vendor waypoints are unavailable on this client."
    end
    local typeID = Enum.ContentTrackingType.Decor
    local result, mapID = self:Call(tracking.GetBestMapForTrackable, typeID, entry.info.recordID, true)
    local candidates, seen, pending, invalid = {}, {}, result == Enum.ContentTrackingResult.DataPending, false
    -- Map IDs are query candidates; only native vendor coordinates can become a destination.
    local function addMap(id)
        if self:Readable(id) and type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0 and not seen[id] then
            candidates[#candidates + 1], seen[id] = id, true
        end
    end
    if result == Enum.ContentTrackingResult.Success then addMap(mapID) end
    local current = self:Call(map.GetBestMapForUnit, "player")
    addMap(current); addMap(self:ZoneMap(current))
    local known = {}
    for id in pairs(entry.maps or {}) do known[#known + 1] = id end
    table.sort(known)
    for _, id in ipairs(known) do addMap(id) end
    local vendor = self.filters and self.filters.vendor
    for _, id in ipairs(candidates) do
        local status, location = self:Call(tracking.GetNextWaypointForTrackable, typeID, entry.info.recordID, id)
        pending = pending or status == Enum.ContentTrackingResult.DataPending
        if status == Enum.ContentTrackingResult.Success and type(location) == "table"
            and self:Readable(location.targetType) and location.targetType == Enum.ContentTrackingTargetType.Vendor then
            local point = self:VendorPoint(id, location.x, location.y)
            if point then
                local info = self:Call(tracking.GetVendorTrackingInfo, entry.info.recordID)
                point.vendorName = info and info.creatureName
                if not vendor or vendor == "all" or point.vendorName == vendor then return point end
            else invalid = true end
        end
    end
    observed = self:ObservedVendorDestination(entry)
    if observed then return observed end
    if pending then return nil, "Vendor location is loading. Try again shortly." end
    if invalid then return nil, "This vendor location cannot accept a user waypoint." end
    return nil, "No vendor destination is available. Open the vendor's shop once to learn its location."
end

-- Place a user waypoint only after rechecking the destination and combat state.
function EH:PlaceVendorWaypoint(entry)
    local location, reason = self:VendorDestination(entry)
    if not location then self:Notify(reason); return false end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(location.mapID, location.x, location.y))
    if self.db.settings.superTrack and C_SuperTrack then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    self:Notify("Vendor waypoint set: " .. (location.vendorName or entry.waypointVendorName or entry.name))
    return true
end

-- Respect the user's existing map pin, with an optional native confirmation dialog.
function EH:VendorWaypoint(entry)
    local location, reason = self:VendorDestination(entry)
    if not location then self:Notify(reason); return end
    if self.db.settings.waypointConfirm and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
        StaticPopup_Show("ELEMENTHOUSING_WAYPOINT", nil, nil, entry)
    else self:PlaceVendorWaypoint(entry) end
end

StaticPopupDialogs.ELEMENTHOUSING_WAYPOINT = {
    text = "Replace your current map waypoint with this decor vendor?", button1 = ACCEPT, button2 = CANCEL,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    -- Revalidate instead of applying coordinates captured before a map or combat change.
    OnAccept = function(_, entry) EH:PlaceVendorWaypoint(entry) end,
}
