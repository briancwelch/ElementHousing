local _, EH = ...

-- Index sourced positions once without adding a dependency or copying them into saved variables.
local function Index()
    if EH.vendorLibraryIndex then return EH.vendorLibraryIndex end
    local index = {}
    for _, route in ipairs(EH.vendorLibrary or {}) do
        local name = route.name:lower()
        index[name] = index[name] or {}
        index[name][#index[name] + 1] = route
    end
    EH.vendorLibraryIndex = index
    return index
end

-- Resolve exact catalog vendor names; ambiguous identities require matching native map/zone evidence.
function EH:ReadLibrarySources(entry)
    entry.libraryVendors = {}
    if not entry.sources.vendor then return end
    local index, seen = Index(), {}
    for name in pairs(entry.vendorNames) do
        local routes = index[self:Plain(name):lower()] or {}
        local matching, distinct = {}, {}
        for _, route in ipairs(routes) do
            distinct[route.mapID] = true
            local map = self:Call(C_Map and C_Map.GetMapInfo, route.mapID)
            local zone = map and self:Plain(map.name) or route.zone
            local match = entry.maps[route.mapID] == true
            for id in pairs(entry.maps) do
                if self:ZoneMap(id) == self:ZoneMap(route.mapID) then match = true end
            end
            for label in pairs(entry.zoneNames) do
                if label:lower() == zone:lower() or label:lower() == route.zone:lower() then match = true end
            end
            matching[route] = match
        end
        local first = next(distinct)
        local unique = first and not next(distinct, first)
        for _, route in ipairs(routes) do
            if (unique or matching[route]) and not seen[route] then
                seen[route] = true
                entry.libraryVendors[#entry.libraryVendors + 1] = { vendorName = name, mapID = route.mapID,
                    x = route.x, y = route.y, faction = route.faction, note = route.note }
            end
        end
    end
    for _, route in ipairs(entry.libraryVendors) do
        entry.maps[route.mapID] = true
        local map = self:Call(C_Map and C_Map.GetMapInfo, route.mapID)
        if map and self:Plain(map.name) ~= "" then entry.zoneNames[self:Plain(map.name)] = true end
    end
end

-- Use supported, faction-appropriate library points only after native and observed routes fail.
function EH:LibraryVendorDestination(entry)
    local current = self:ZoneMap(self:Call(C_Map and C_Map.GetBestMapForUnit, "player"))
    local position = current and self:Call(C_Map.GetPlayerMapPosition, current, "player")
    local x, y
    if position and position.GetXY then x, y = self:Call(position.GetXY, position) end
    local faction = self:Call(UnitFactionGroup, "player")
    local selected, choices = self.filters and self.filters.vendor, {}
    for _, route in ipairs(entry.libraryVendors or {}) do
        local opposite = faction == "Alliance" and route.faction == "H" or faction == "Horde" and route.faction == "A"
        if not opposite and (not selected or selected == "all" or route.vendorName == selected) then
            local point = self:VendorPoint(route.mapID, route.x, route.y)
            if point then
                point.vendorName, point.source, point.note = route.vendorName, "library", route.note
                local nearby = self:ZoneMap(route.mapID) == current
                local located = route.mapID == current and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1
                choices[#choices + 1] = { point = point, current = nearby,
                    key = string.format("%010d:%s:%.6f:%.6f", route.mapID, route.vendorName, route.x, route.y),
                    distance = located and (point.x - x)^2 + (point.y - y)^2 or math.huge }
            end
        end
    end
    table.sort(choices, function(a, b)
        if a.current ~= b.current then return a.current end
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.key < b.key
    end)
    return choices[1] and choices[1].point
end
