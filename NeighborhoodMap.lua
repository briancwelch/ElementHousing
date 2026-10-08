local _, EH = ...
local E = ElvUI[1]

-- Check public finite map data before doing geometry or replacing a waypoint.
local function Number(value)
    return EH:Readable(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- Reanchor pooled map widgets inside the clipped native scroll viewport.
local function Place(widget, parent, x, y, width, height)
    widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    widget:SetSize(width, height); widget:Show()
end

-- Display the full plot/vendor description without changing Blizzard's map or tracking state.
local function Tooltip(widget)
    GameTooltip:SetOwner(widget, "ANCHOR_RIGHT"); GameTooltip:ClearLines()
    GameTooltip:AddLine(widget.tooltip or "", 1, 1, 1, true); GameTooltip:Show()
end

-- Fetch the native base map layer; missing/restricted artwork keeps the coordinate grid available.
local function Artwork(mapID)
    if not Number(mapID) or mapID <= 0 or mapID % 1 ~= 0 then return end
    local layers = EH:Call(C_Map and C_Map.GetMapArtLayers, mapID)
    local layer = type(layers) == "table" and layers[1]
    if not EH:Readable(layer) or type(layer) ~= "table" then return end
    for _, key in ipairs({ "layerWidth", "layerHeight", "tileWidth", "tileHeight" }) do
        if not Number(layer[key]) or layer[key] <= 0 or layer[key] > 8192 then return end
    end
    local columns, rows = math.ceil(layer.layerWidth / layer.tileWidth), math.ceil(layer.layerHeight / layer.tileHeight)
    if columns * rows > 64 then return end
    local textures = EH:Call(C_Map.GetMapArtLayerTextures, mapID, 1)
    if type(textures) ~= "table" then return end
    for index = 1, columns * rows do
        if not Number(textures[index]) or textures[index] <= 0 or textures[index] % 1 ~= 0 then return end
    end
    return layer, textures, columns, rows
end

-- Keep pan offsets inside the current zoom range, including after a resize or map change.
local function Pan(view, x, y)
    view:SetHorizontalScroll(math.max(0, math.min(x, math.max(0, view.child:GetWidth() - view:GetWidth()))))
    view:SetVerticalScroll(math.max(0, math.min(y, math.max(0, view.child:GetHeight() - view:GetHeight()))))
end

-- Zoom around the current viewport center using only cached housing information.
local function Zoom(card, amount)
    local map = card.map
    local old, nextZoom = map.zoom, math.max(1, math.min(3, map.zoom + amount))
    if old == nextZoom then return end
    map.centerX = (map.view:GetHorizontalScroll() + map.view:GetWidth() / 2) / map.view.child:GetWidth()
    map.centerY = (map.view:GetVerticalScroll() + map.view:GetHeight() / 2) / map.view.child:GetHeight()
    map.zoom = nextZoom; EH:RenderHousingInfo()
end

-- Revalidate combat, neighborhood identity, map support, and coordinates at acceptance time.
function EH:PlaceNeighborhoodWaypoint(point)
    if InCombatLockdown() then self:Notify("Map waypoints are unavailable during combat."); return false end
    local guid = self:Call(C_Housing and C_Housing.GetCurrentNeighborhoodGUID)
    local mapID = guid and self:Call(C_Housing and C_Housing.GetUIMapIDForNeighborhood, guid)
    if not point or guid ~= point.neighborhoodGUID or mapID ~= point.mapID then
        self:Notify("The neighborhood changed. Choose a point on the current map."); return false
    end
    local location = self:VendorPoint(point.mapID, point.x, point.y)
    if not location or not C_Map.SetUserWaypoint or not UiMapPoint then self:Notify("This map location cannot accept a user waypoint."); return false end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(location.mapID, location.x, location.y))
    if self.db.settings.superTrack and C_SuperTrack then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    self:Notify("Map waypoint set: " .. point.label)
    return true
end

-- Preserve the user's current pin when clicking a map marker, using the existing confirmation setting.
function EH:NeighborhoodWaypoint(point)
    if InCombatLockdown() then self:Notify("Map waypoints are unavailable during combat."); return end
    if not point or not self:VendorPoint(point.mapID, point.x, point.y) then self:Notify("This map location cannot accept a user waypoint."); return end
    if self.db.settings.waypointConfirm and self:Call(C_Map and C_Map.HasUserWaypoint) then
        StaticPopup_Show("ELEMENTHOUSING_MAP_WAYPOINT", nil, nil, point)
    else self:PlaceNeighborhoodWaypoint(point) end
end

StaticPopupDialogs.ELEMENTHOUSING_MAP_WAYPOINT = {
    text = "Replace your current map waypoint with this neighborhood location?", button1 = ACCEPT, button2 = CANCEL,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    -- Use the same validation for confirmed and unconfirmed map marker navigation.
    OnAccept = function(_, point) EH:PlaceNeighborhoodWaypoint(point) end,
}

-- Create one persistent map viewport and native ElvUI controls per neighborhood card.
local function CreateMap(card)
    local map = { zoom = 1, filter = "all", showVendors = false, tiles = {}, vendors = {} }
    local view = CreateFrame("ScrollFrame", nil, card, "BackdropTemplate")
    EH:Skin(view, true); view:EnableMouse(true); view:EnableMouseWheel(true); view:RegisterForDrag("LeftButton")
    local child = CreateFrame("Frame", nil, view); child:SetSize(1, 1); view:SetScrollChild(child)
    view.child, map.view = child, view
    view:SetScript("OnMouseWheel", function(_, delta) Zoom(card, delta > 0 and .5 or -.5) end)
    -- Drag in viewport pixels and release the update callback immediately when dragging ends.
    view:SetScript("OnDragStart", function(widget)
        local x, y = EH:Call(GetCursorPosition)
        if not Number(x) or not Number(y) then return end
        widget.drag = { x = x, y = y, horizontal = widget:GetHorizontalScroll(), vertical = widget:GetVerticalScroll() }
        widget:SetScript("OnUpdate", function(frame)
            local cursorX, cursorY = EH:Call(GetCursorPosition)
            local scale = frame:GetEffectiveScale()
            if frame.drag and Number(cursorX) and Number(cursorY) and Number(scale) and scale > 0 then
                Pan(frame, frame.drag.horizontal + (frame.drag.x - cursorX) / scale,
                    frame.drag.vertical + (cursorY - frame.drag.y) / scale)
            end
        end)
    end)
    view:SetScript("OnDragStop", function(widget) widget.drag = nil; widget:SetScript("OnUpdate", nil) end)
    view:SetScript("OnHide", function(widget) widget.drag = nil; widget:SetScript("OnUpdate", nil) end)
    map.minus = EH:Button(card, "-", 36, function() Zoom(card, -.5) end)
    map.plus = EH:Button(card, "+", 36, function() Zoom(card, .5) end)
    map.reset = EH:Button(card, "Reset", 90, function()
        map.zoom, map.centerX, map.centerY = 1, nil, nil; Pan(view, 0, 0); EH:RenderHousingInfo()
    end)
    map.plots = EH:Button(card, "All plots", 170, function(button)
        EH:ChoiceMenu(button, { all = "All plots", vacant = "Unowned plots", occupied = "Occupied plots", owned = "My plots", unknown = "Unknown ownership" },
            function() return map.filter end, function(value) map.filter = value; EH:RenderHousingInfo() end)
    end)
    map.vendorToggle = EH:Button(card, "Vendors", 146, function()
        map.showVendors = not map.showVendors; EH:RenderHousingInfo()
    end, "shop")
    map.player = child:CreateTexture(nil, "OVERLAY"); map.player:SetTexture("Interface\\Minimap\\MinimapArrow")
    card.map = map
    return map
end

-- Reuse interactive marker buttons; plot numbers and vendor glyphs stay on native ElvUI fonts/templates.
local function Marker(pool, index, parent, vendor)
    local point = pool[index]
    if not point then
        point = CreateFrame("Button", nil, parent, "BackdropTemplate"); EH:Skin(point)
        point.fill = point:CreateTexture(nil, "ARTWORK"); point.fill:SetAllPoints()
        point.fill:SetTexture(vendor and EH:Icon("shop") or E.media.blankTex)
        if not vendor then point.number = EH:Label(point, ""); point.number:SetPoint("CENTER") end
        point:SetScript("OnEnter", Tooltip); point:SetScript("OnLeave", function() GameTooltip:Hide() end)
        point:SetScript("OnClick", function(widget) EH:NeighborhoodWaypoint(widget.destination) end)
        pool[index] = point
    end
    return point
end

-- Update the visible player marker from public native coordinates without refreshing server data.
local function PlayerPosition(map)
    map.player:Hide()
    if EH:Call(C_Housing and C_Housing.GetCurrentNeighborhoodGUID) ~= map.neighborhoodGUID then return end
    local position = map.mapID and EH:Call(C_Map and C_Map.GetPlayerMapPosition, map.mapID, "player")
    if not position or not position.GetXY then return end
    local px, py = EH:Call(position.GetXY, position)
    if not Number(px) or not Number(py) or px < 0 or px > 1 or py < 0 or py > 1 then return end
    local child = map.view.child
    Place(map.player, child, math.max(0, math.min(child:GetWidth() - 22, px * child:GetWidth() - 11)),
        math.max(0, math.min(child:GetHeight() - 22, py * child:GetHeight() - 11)), 22, 22)
end

-- Draw native map tiles and public plot positions, with zoom, pan, ownership filters, and optional vendor pins.
function EH:RenderNeighborhoodMap(card, section, y, width)
    local map = card.map or CreateMap(card)
    local layer, textures, columns, rows = Artwork(section.mapID)
    local ratio = layer and layer.layerHeight / layer.layerWidth or .65
    local height = math.max(200, math.min(620, width * ratio))
    local nativeRatioWidth = math.min(width, height / ratio)
    local left = 14 + (width - nativeRatioWidth) / 2
    local line = math.max(14, E.db.general.fontSize or 13) + 14
    local x = 14
    for _, button in ipairs({ map.minus, map.plus, map.reset, map.plots, map.vendorToggle }) do
        Place(button, card, x, y, button:GetWidth(), line); x = x + button:GetWidth() + 6
    end
    map.plots.text:SetText(({ all = "All plots", vacant = "Unowned", occupied = "Occupied", owned = "My plots", unknown = "Unknown" })[map.filter])
    map.vendorToggle:SetAlpha(map.showVendors and 1 or .55)
    y = y + line + 8
    Place(map.view, card, left, y, nativeRatioWidth, height)
    local view, child = map.view, map.view.child
    local childWidth, childHeight = nativeRatioWidth * map.zoom, height * map.zoom
    child:SetSize(childWidth, childHeight)
    for _, tile in ipairs(map.tiles) do tile:Hide() end
    for _, lineTexture in ipairs(card.grid) do lineTexture:Hide() end
    if layer then
        for index = 1, columns * rows do
            local tile = map.tiles[index]
            if not tile then tile = child:CreateTexture(nil, "BACKGROUND"); map.tiles[index] = tile end
            local col, row = (index - 1) % columns, math.floor((index - 1) / columns)
            local tileWidth = math.min(layer.tileWidth, layer.layerWidth - col * layer.tileWidth)
            local tileHeight = math.min(layer.tileHeight, layer.layerHeight - row * layer.tileHeight)
            tile:SetTexture(textures[index]); tile:SetTexCoord(0, tileWidth / layer.tileWidth, 0, tileHeight / layer.tileHeight)
            Place(tile, child, col * layer.tileWidth / layer.layerWidth * childWidth, row * layer.tileHeight / layer.layerHeight * childHeight,
                tileWidth / layer.layerWidth * childWidth, tileHeight / layer.layerHeight * childHeight)
        end
    else
        for index = 1, 10 do
            local grid = card.grid[index]
            if not grid then grid = child:CreateTexture(nil, "BACKGROUND"); grid:SetTexture(E.media.blankTex); card.grid[index] = grid end
            grid:SetVertexColor(unpack(E.media.bordercolor)); grid:SetAlpha(.35)
            local vertical, fraction = index <= 5, ((index - 1) % 5) / 4
            Place(grid, child, vertical and childWidth * fraction or 0, vertical and 0 or childHeight * fraction,
                vertical and 1 or childWidth, vertical and childHeight or 1)
        end
    end
    local visible, size = 0, math.max(22, line - 2)
    for _, marker in ipairs(card.markers) do marker:Hide() end
    for _, plot in ipairs(section.plots or {}) do
        local show = map.filter == "all" or map.filter == plot.status or map.filter == "owned" and plot.owned
        if show and Number(plot.x) and Number(plot.y) then
            visible = visible + 1
            local point = Marker(card.markers, visible, child)
            point.plotID, point.tooltip = plot.id, plot.tooltip .. "\nClick to set a waypoint."
            point.destination = { mapID = section.mapID, x = plot.x, y = plot.y, label = "Plot " .. plot.id, neighborhoodGUID = section.neighborhoodGUID }
            point.number:SetText((plot.owned and "*" or "") .. plot.id)
            point.fill:SetVertexColor(unpack(plot.status == "unknown" and E.media.bordercolor or E.media.rgbvaluecolor))
            point.fill:SetAlpha(plot.owned and .85 or plot.status == "vacant" and .15 or .45)
            Place(point, child, math.max(0, math.min(childWidth - size, plot.x * childWidth - size / 2)),
                math.max(0, math.min(childHeight - size, plot.y * childHeight - size / 2)), size, size)
        end
    end
    for _, marker in ipairs(map.vendors) do marker:Hide() end
    local vendorCount = 0
    if map.showVendors then
        local groups, order = {}, {}
        for _, route in ipairs(self.vendorLibrary or {}) do
            if route.mapID == section.mapID then
                local key = route.x .. ":" .. route.y
                if not groups[key] then groups[key] = { x = route.x, y = route.y, names = {} }; order[#order + 1] = key end
                groups[key].names[#groups[key].names + 1] = route.name .. (route.note and " - " .. route.note or "")
            end
        end
        for _, key in ipairs(order) do
            local group = groups[key]
            vendorCount = vendorCount + 1
            local point = Marker(map.vendors, vendorCount, child, true)
            point.fill:SetTexture(self:Icon("shop"))
            point.tooltip = table.concat(group.names, "\n") .. string.format("\nKnown vendor location: %.1f, %.1f", group.x * 100, group.y * 100)
                .. "\nBundled community data; availability may depend on an endeavor or event.\nClick to set a waypoint."
            point.destination = { mapID = section.mapID, x = group.x, y = group.y, label = #group.names > 1 and "Vendor location" or group.names[1], neighborhoodGUID = section.neighborhoodGUID }
            Place(point, child, math.max(0, math.min(childWidth - size, group.x * childWidth - size / 2)),
                math.max(0, math.min(childHeight - size, group.y * childHeight - size / 2)), size, size)
        end
    end
    if map.neighborhoodGUID ~= section.neighborhoodGUID then
        map.neighborhoodGUID, map.centerX, map.centerY = section.neighborhoodGUID, nil, nil; Pan(view, 0, 0)
    elseif map.centerX then
        Pan(view, map.centerX * childWidth - nativeRatioWidth / 2, map.centerY * childHeight - height / 2)
        map.centerX, map.centerY = nil, nil
    else Pan(view, view:GetHorizontalScroll(), view:GetVerticalScroll()) end
    map.mapID = section.mapID
    PlayerPosition(map)
    if not map.trackingPlayer then
        map.trackingPlayer = true
        -- Native OnUpdate runs only while the map and its parent frames are visible.
        child:SetScript("OnUpdate", function(_, elapsed)
            map.elapsed = (map.elapsed or 0) + elapsed
            if map.elapsed >= .2 then map.elapsed = 0; PlayerPosition(map) end
        end)
    end
    map.hasArtwork, map.visiblePlots, map.visibleVendors = layer ~= nil, visible, vendorCount
    return y + height + 8
end
