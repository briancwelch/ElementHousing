local _, EH = ...

-- Accept only public, finite numbers before inspecting native or saved acquisition data.
local function Number(value, minimum)
    return EH:Readable(value) and type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value >= minimum
end

-- Resolve real currency IDs and item-token hyperlinks into distinct purchase-cost keys.
local function CurrencyLink(link)
    if not EH:Readable(link) or type(link) ~= "string" then return nil end
    local id = link:match("|Hcurrency:(%d+)")
    if id and tonumber(id) > 0 then return "currency:" .. tonumber(id) end
    id = link:match("|Hitem:(%d+)")
    if id and tonumber(id) > 0 then return "item:" .. tonumber(id) end
end

-- Match explicit PvP source labels as whole words, including Blizzard's localized labels.
local function PvPSource(text)
    text = EH:Plain(text):lower()
    local names = { "PvP", "Player vs. Player", "Player versus Player", _G.PVP, _G.PLAYER_V_PLAYER }
    for _, name in pairs(names) do
        name = EH:Plain(name):lower()
        if name ~= "" then
            local first, last = text:find(name, 1, true)
            while first do
                local before, after = text:sub(first - 1, first - 1), text:sub(last + 1, last + 1)
                if not before:find("[%w_\128-\255]") and not after:find("[%w_\128-\255]") then return true end
                first, last = text:find(name, last + 1, true)
            end
        end
    end
    return false
end

-- Follow native achievement ancestry to PvP, including its legacy and feat-of-strength categories.
local function PvPAchievement(id)
    if not Number(id, 1) or id % 1 ~= 0 then return false end
    local category = EH:Call(GetAchievementCategory, id)
    local seen = {}
    for _ = 1, 16 do
        if not Number(category, 1) or category % 1 ~= 0 or seen[category] then return false end
        seen[category] = true
        local name, parent = EH:Call(GetCategoryInfo, category)
        if category == 95 or PvPSource(name) then return true end
        category = parent
    end
    return false
end

-- Classify only known PvP acquisition evidence; decor names and unknown sources cannot hide an item.
function EH:IsPvPDecor(entry)
    local text = self:Readable(entry.sourceText) and type(entry.sourceText) == "string" and entry.sourceText or ""
    if PvPSource(text) then return true end
    local tags = entry.info.dataTagsByID
    if self:Readable(tags) and type(tags) == "table" then
        for _, group in ipairs(self.tagGroups or {}) do
            for _, tag in ipairs(group.tags or {}) do
                if self:Readable(tags[tag.tagID]) and tags[tag.tagID] and PvPSource(tag.tagName) then return true end
            end
        end
    end
    local achievementType = Enum and Enum.ContentTrackingTargetType and Enum.ContentTrackingTargetType.Achievement or 2
    if entry.targetType == achievementType and PvPAchievement(entry.targetID) then return true end
    for id in text:gmatch("|Hachievement:(%d+)") do
        if PvPAchievement(tonumber(id)) then return true end
    end
    local constants = Constants and Constants.CurrencyConsts or {}
    local costs = {
        ["currency:" .. (constants.HONOR_CURRENCY_ID or 1792)] = true,
        ["currency:" .. (constants.CONQUEST_CURRENCY_ID or 1602)] = true,
        ["currency:2123"] = true, -- Bloody Tokens.
        ["item:137642"] = true, -- Mark of Honor.
    }
    for key in pairs(entry.currencyTypes or {}) do if costs[key] then return true end end
    for kind, id in text:gmatch("|H(%a+):(%d+)") do
        if costs[kind .. ":" .. tonumber(id)] then return true end
    end
    return false
end

-- Keep all verified currencies, including the association with their actual vendor.
function EH:AddCurrency(entry, key, vendorName)
    if type(key) ~= "string" or (key ~= "gold" and not key:match("^currency:%d+$")
        and not key:match("^item:%d+$")) then return end
    entry.currencyTypes[key] = true
    if type(vendorName) == "string" and vendorName ~= "" then
        entry.vendorCurrencies[vendorName] = entry.vendorCurrencies[vendorName] or {}
        entry.vendorCurrencies[vendorName][key] = true
    end
end

-- Display Blizzard's localized expansion names without deriving an expansion from a vendor's zone.
function EH:ExpansionName(id)
    return _G["EXPANSION_NAME" .. id] or (id == 0 and "Classic" or ("Expansion " .. id))
end

-- Return only the documented expansion field from the cached item-information tuple.
local function ItemExpansion(itemID)
    return (select(15, C_Item.GetItemInfo(itemID)))
end

-- Prefer native catalog expansion tags, then request uncached item metadata once per session.
function EH:ReadExpansion(entry)
    entry.expansionIDs = {}
    local tags = entry.info.dataTagsByID
    if self:Readable(tags) and type(tags) == "table" then
        for _, group in ipairs(self.tagGroups or {}) do
            for _, tag in ipairs(group.tags or {}) do
                if self:Readable(tags[tag.tagID]) and tags[tag.tagID] then
                    local tagName = self:Plain(tag.tagName):lower()
                    for id = 0, 20 do
                        local name = _G["EXPANSION_NAME" .. id]
                        if (name and tagName == self:Plain(name):lower())
                            or (id == 0 and tagName == "classic") then entry.expansionIDs[id] = true end
                    end
                end
            end
        end
    end
    if next(entry.expansionIDs) then return end
    local itemID = entry.info.itemID
    if not Number(itemID, 1) or itemID % 1 ~= 0 or not C_Item or not C_Item.GetItemInfo then return end
    local id = self:Call(ItemExpansion, itemID)
    if Number(id, 0) and id % 1 == 0 then entry.expansionIDs[id] = true; return end
    self.requestedItems = self.requestedItems or {}
    if not self.requestedItems[itemID] and C_Item.RequestLoadItemDataByID then
        self.requestedItems[itemID] = true
        self:Call(C_Item.RequestLoadItemDataByID, itemID)
    end
end

-- Read every purchase component without treating an unavailable extended cost as free or gold-only.
function EH:MerchantCosts(index, info)
    local costs = {}
    if Number(info.price, 0) and (info.price > 0 or info.hasExtendedCost == false) then costs.gold = info.price end
    if info.hasExtendedCost == true then
        local count = self:Call(GetMerchantItemCostInfo, index)
        if Number(count, 0) and count % 1 == 0 then
            for i = 1, math.min(count, MAX_ITEM_COST or 10) do
                local _, amount, link = self:Call(GetMerchantItemCostItem, index, i)
                local key = CurrencyLink(link)
                if key and Number(amount, 0) then costs[key] = amount end
            end
        end
    end
    return costs
end

-- Learn decor routes only from an open merchant that actually offers the corresponding catalog item.
function EH:ObserveMerchant()
    if not self.merchantOpen or InCombatLockdown() or not C_MerchantFrame then return end
    local name, guid = self:Call(UnitName, "npc"), self:Call(UnitGUID, "npc")
    local npcID = type(guid) == "string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$"))
    if type(name) ~= "string" or name == "" or not npcID then return end
    local mapID = self:ZoneMap(self:Call(C_Map and C_Map.GetBestMapForUnit, "player"))
    local position = mapID and self:Call(C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y
    if position and position.GetXY then x, y = self:Call(position.GetXY, position) end
    local mapInfo = mapID and self:Call(C_Map.GetMapInfo, self:ZoneMap(mapID))
    local count = self:Call(GetMerchantNumItems)
    if not Number(count, 0) or count % 1 ~= 0 then return end
    for index = 1, math.min(count, 1000) do
        local itemID = self:Call(GetMerchantItemID, index)
        local catalog = itemID and self:Call(C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem, itemID)
        local info = catalog and self:Call(C_MerchantFrame.GetItemInfo, index)
        if catalog and catalog.entryType == Enum.HousingCatalogEntryType.Decor and Number(catalog.recordID, 1)
            and info and self:Readable(info.price) and self:Readable(info.hasExtendedCost) then
            local saved = self.db.vendorSources[catalog.recordID]
            local routes = type(saved) == "table" and saved or {}
            self.db.vendorSources[catalog.recordID] = routes
            local key = npcID .. ":" .. (mapID or 0)
            local previous = type(routes[key]) == "table" and routes[key] or {}
            local point = self:VendorPoint(mapID, x, y) or self:VendorPoint(mapID, previous.x, previous.y)
            local costs = self:MerchantCosts(index, info)
            -- A transient empty reply must not erase a verified location or purchase currency.
            if not next(costs) and type(previous.costs) == "table" then costs = previous.costs end
            routes[key] = { vendorName = self:Plain(name), mapID = mapID,
                x = point and point.x, y = point and point.y, zoneName = mapInfo and self:Plain(mapInfo.name), costs = costs }
        end
    end
    self:ScheduleRefresh()
end

-- Merge observed alternatives into source, location, and currency filters without replacing native metadata.
function EH:ReadObservedSources(entry)
    local routes = self.db.vendorSources[entry.info.recordID]
    for _, route in pairs(type(routes) == "table" and routes or {}) do
        if type(route) == "table" and type(route.vendorName) == "string" then
            entry.sources.vendor, entry.vendorNames[route.vendorName] = true, true
            if type(route.zoneName) == "string" then entry.zoneNames[route.zoneName] = true end
            if Number(route.mapID, 1) and route.mapID % 1 == 0 then entry.maps[route.mapID] = true end
            for key, cost in pairs(type(route.costs) == "table" and route.costs or {}) do
                if Number(cost, 0) then self:AddCurrency(entry, key, route.vendorName) end
            end
        end
    end
end

-- Validate a public map coordinate and map support before any user waypoint can be replaced.
function EH:VendorPoint(mapID, x, y)
    if not Number(mapID, 1) or mapID % 1 ~= 0 or not Number(x, 0) or not Number(y, 0)
        or x > 1 or y > 1 or x == 0 and y == 0
        or self:Call(C_Map and C_Map.CanSetUserWaypointOnMap, mapID) ~= true then return nil end
    return { mapID = mapID, x = x, y = y }
end

-- Respect the vendor selection and prefer the nearest verified merchant on the current map.
function EH:ObservedVendorDestination(entry, currentOnly)
    local current = self:Call(C_Map and C_Map.GetBestMapForUnit, "player")
    current = self:ZoneMap(current)
    local vendor = self.filters and self.filters.vendor
    local position = current and self:Call(C_Map.GetPlayerMapPosition, current, "player")
    local x, y
    if position and position.GetXY then x, y = self:Call(position.GetXY, position) end
    local hasPosition = Number(x, 0) and Number(y, 0) and x <= 1 and y <= 1
    local choices = {}
    local routes = self.db.vendorSources[entry.info.recordID]
    for key, route in pairs(type(routes) == "table" and routes or {}) do
        if type(route) == "table" and type(route.vendorName) == "string"
            and (not vendor or vendor == "all" or route.vendorName == vendor)
            and (not currentOnly or current and route.mapID == current) then
            local point = self:VendorPoint(route.mapID, route.x, route.y)
            if point then
                point.vendorName = route.vendorName
                local distance = hasPosition and point.mapID == current and ((point.x - x)^2 + (point.y - y)^2) or math.huge
                choices[#choices + 1] = { key = tostring(key), point = point, distance = distance }
            end
        end
    end
    -- Keep selection stable when player position is unavailable or two observations share a location.
    table.sort(choices, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.key < b.key
    end)
    return choices[1] and choices[1].point
end

-- Describe known currency IDs and item tokens using native metadata instead of guessed labels.
function EH:CurrencyName(key)
    if key == "gold" then return GOLD or "Gold" end
    local id = key:match("^currency:(%d+)$")
    if id then
        local info = self:Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo, tonumber(id))
        return info and info.name or ("Currency " .. id)
    end
    id = key:match("^item:(%d+)$")
    return id and (self:Call(C_Item and C_Item.GetItemInfo, tonumber(id)) or ("Item token " .. id)) or key
end

-- Match a known purchase currency for the selected vendor, keeping unknown costs explicitly selectable.
function EH:MatchesCurrency(entry, selected)
    if not selected or selected == "all" then return true end
    local vendor = self.filters and self.filters.vendor
    local currencies = vendor and vendor ~= "all" and entry.vendorCurrencies[vendor] or entry.currencyTypes
    if vendor and vendor ~= "all" and not entry.vendorCurrencies[vendor] then currencies = {} end
    return selected == "unknown" and not next(currencies) or currencies[selected] == true
end
