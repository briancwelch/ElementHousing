-- Check native tile geometry, viewport interactions, visible player updates, and safe map navigation.
EH:Initialize(); SetupDashboardFixture(); EH:Show("neighborhood")
local page = EH.infoPages.neighborhood
page.scroll:SetSize(1240, 650); EH:RenderHousingInfo()
local card, originalGUID = page.cards["Neighborhood plots"], C_Housing.GetCurrentNeighborhoodGUID
local map = card.map
Check(not map.hasArtwork and #card.grid == 10, "Unavailable native artwork retains a usable coordinate grid")
Check(map.visiblePlots == 55 and map.player:IsShown(), "Current native plot and player positions are shown")
Check(card.markers[8].number:GetText() == "*7", "Owned house identity marks the correct plot")
C_Map.GetMapArtLayers = function() return { { layerWidth = 1000, layerHeight = 650, tileWidth = 256, tileHeight = 256 } } end
C_Map.GetMapArtLayerTextures = function() return { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 } end
EH:RenderHousingInfo()
Check(map.hasArtwork and #map.tiles == 12, "Documented native map layer produces the complete tiled artwork")
local edge = map.tiles[12]
Check(math.abs(edge.state_SetTexCoord[2] - 232 / 256) < .00001 and math.abs(edge.state_SetTexCoord[4] - 138 / 256) < .00001,
    "Partial native edge tiles crop the correct texture fractions")
Check(math.abs(map.view:GetHeight() / map.view:GetWidth() - .65) < .00001, "Map aspect ratio keeps plot coordinates aligned with artwork")
for _, grid in ipairs(card.grid) do Check(not grid:IsShown(), "Native artwork hides the fallback grid") end
local count = #frames
for _ = 1, 10 do EH:RenderHousingInfo() end
Check(#frames == count, "Native tile and marker controls are pooled across repeated replies")
map.view.scripts.OnMouseWheel(map.view, 1)
Check(map.zoom == 1.5 and map.view.child:GetWidth() == map.view:GetWidth() * 1.5, "Wheel zoom expands the child map within a clipped viewport")
Check(map.view:GetHorizontalScroll() > 0 and map.view:GetVerticalScroll() > 0, "Zoom preserves the visible map center")
for _ = 1, 10 do map.plus.scripts.OnClick(map.plus) end
Check(map.zoom == 3, "Zoom has a bounded maximum")
map.view.scripts.OnDragStart(map.view)
GetCursorPosition = function() return -50000, 50000 end
map.view.scripts.OnUpdate(map.view, .1)
Check(map.view:GetHorizontalScroll() <= map.view.child:GetWidth() - map.view:GetWidth(), "Drag pan cannot move beyond horizontal artwork bounds")
Check(map.view:GetVerticalScroll() <= map.view.child:GetHeight() - map.view:GetHeight(), "Drag pan cannot move beyond vertical artwork bounds")
map.view.scripts.OnDragStop(map.view)
Check(map.view.scripts.OnUpdate == nil and map.view.drag == nil, "Drag releases its update callback immediately")
map.reset.scripts.OnClick(map.reset)
Check(map.zoom == 1 and map.view:GetHorizontalScroll() == 0 and map.view:GetVerticalScroll() == 0, "Reset returns to the full neighborhood view")
map.plots.scripts.OnClick(map.plots)
-- The menu callback is exercised through the same public selection path as a native context menu.
map.filter = "vacant"; EH:RenderHousingInfo()
Check(map.visiblePlots == 11, "Unowned view shows actual available ownership states")
map.filter = "owned"; EH:RenderHousingInfo()
Check(map.visiblePlots == 1 and card.markers[1].plotID == 7, "My plots view uses the account's known house list")
map.filter = "all"; EH:RenderHousingInfo()
local old = { mapID = 200, x = .1, y = .1 }; waypoint = old
card.markers[1].scripts.OnClick(card.markers[1])
Check(waypoint == old and popup.which == "ELEMENTHOUSING_MAP_WAYPOINT", "Plot navigation preserves the current pin until confirmation")
combat = true; StaticPopupDialogs.ELEMENTHOUSING_MAP_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint == old, "Map navigation confirmation rechecks combat")
combat = false; C_Housing.GetCurrentNeighborhoodGUID = function() return "OTHER" end
StaticPopupDialogs.ELEMENTHOUSING_MAP_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint == old, "A delayed confirmation cannot navigate a stale neighborhood snapshot")
C_Housing.GetCurrentNeighborhoodGUID = originalGUID
StaticPopupDialogs.ELEMENTHOUSING_MAP_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint.mapID == 100 and waypoint.x == .12 and supertracked, "Confirmed plot navigation uses public map coordinates")
local originalMap = C_Housing.GetUIMapIDForNeighborhood
C_Housing.GetUIMapIDForNeighborhood = function() return 2352 end
waypoint = old; StaticPopupDialogs.ELEMENTHOUSING_MAP_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint == old, "A changed map layout cannot apply old neighborhood coordinates")
C_Housing.GetUIMapIDForNeighborhood = originalMap
local canSet = C_Map.CanSetUserWaypointOnMap
C_Map.CanSetUserWaypointOnMap = function() return false end
waypoint = old; card.markers[1].scripts.OnClick(card.markers[1])
Check(waypoint == old, "Unsupported plot map cannot replace a waypoint")
C_Map.CanSetUserWaypointOnMap = canSet
playerPositions[100] = { x = .8, y = .7 }
map.view.child.scripts.OnUpdate(map.view.child, .2)
local anchor = map.player.points[1]
Check(anchor[4] > map.view:GetWidth() * .7, "Player marker follows movement without a housing server refresh")
playerPositions[100] = { x = "SECRET", y = .7 }
map.view.child.scripts.OnUpdate(map.view.child, .2)
Check(not map.player:IsShown(), "Restricted player coordinates hide the marker")
playerPositions[100] = { x = .42, y = .62 }
C_Map.GetMapArtLayers = function() return { { layerWidth = "SECRET", layerHeight = 650, tileWidth = 256, tileHeight = 256 } } end
EH:RenderHousingInfo()
Check(not map.hasArtwork and card.grid[1]:IsShown() and not map.tiles[1]:IsShown(), "Restricted artwork data falls back without retaining stale tiles")
C_Housing.GetUIMapIDForNeighborhood = function() return 2352 end
maps[2352] = { mapID = 2352, name = "Founder's Point", mapType = 3, parentMapID = 1 }
map.vendorToggle.scripts.OnClick(map.vendorToggle)
Check(map.visibleVendors > 0, "Optional vendor layer uses bundled known neighborhood positions")
local grouped = false
for _, marker in ipairs(map.vendors) do
    if marker:IsShown() then
        Check(marker.tooltip:find("community data", 1, true), "Static vendor pins explain conditional availability")
        if marker.tooltip:find("Pascal-K1N6", 1, true) and marker.tooltip:find("Hordranin", 1, true) then grouped = true end
    end
end
Check(grouped, "Vendors sharing a location remain discoverable in one combined tooltip")
map.vendorToggle.scripts.OnClick(map.vendorToggle)
Check(map.visibleVendors == 0, "Vendor layer can be hidden independently of plots")
for _, marker in ipairs(map.vendors) do Check(not marker:IsShown(), "Disabling a layer hides its pooled pins") end
