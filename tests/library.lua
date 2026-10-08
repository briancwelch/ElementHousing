-- Exercise sourced coordinates on a fresh account, including ambiguous names and safe fallback priority.
local function Decor(id, source)
    return { recordID = id, entryType = 1, itemID = 900000 + id, name = "Library decor", sourceText = source,
        totalNumStored = 0, totalNumPlaced = 0, remainingRedeemable = 0, categoryIDs = {}, subcategoryIDs = {}, dataTagsByID = {} }
end

EH:Initialize()
Check(#EH.vendorLibrary == 243 and next(EH.db.vendorSources) == nil, "Fresh install loads sourced vendor data without merchant visits")
for _, route in ipairs(EH.vendorLibrary) do
    maps[route.mapID] = { mapID = route.mapID, name = route.zone, mapType = 3, parentMapID = 1 }
    Check(EH:VendorPoint(route.mapID, route.x, route.y) ~= nil, "Every bundled position is a valid native coordinate")
    Check(route.npcID == nil or route.npcID > 0, "Synthetic upstream IDs are never exposed as NPC IDs")
    Check(route.cost == nil and route.currencyType == nil, "Coordinate data never guesses an inventory or price")
end
currentMap, playerPositions[2393] = 2393, { x = .5, y = .5 }
local entry = EH:MakeEntry(Decor(66000, "Vendor: Dethelin"))
local point = EH:VendorDestination(entry)
Check(point and point.source == "library" and point.mapID == 2393 and point.x == .524 and point.y == .474,
    "Dethelin resolves before any shop visit when native tracking has no destination")
Check(entry.maps[2393] and entry.zoneNames["Silvermoon City"], "Known vendor maps enrich source zone browsing")
Check(not next(entry.currencyTypes) and EH:CostText(entry) == "Unknown", "Unseen merchant prices remain unknown")
Check(next(EH.db.vendorSources) == nil, "Bundled routes are not copied into account observations")
EH:SetFilter("vendor", "Someone else")
Check(EH:VendorDestination(entry) == nil, "Library waypoints honor the selected vendor")
EH:ResetFilters()
locations[66000] = { status = 0, mapID = 2393, x = .6, y = .7, targetType = 1 }
vendors[66000] = { creatureName = "Dethelin" }
point = EH:VendorDestination(entry)
Check(point.x == .6 and point.source == nil, "Current native tracking takes priority over the bundled position")
locations[66000] = { status = 1, mapID = 2393 }
Check(EH:VendorDestination(entry).source == "library", "Pending tracking can use an already known library destination")
locations[66000] = nil
EH.db.vendorSources[66000] = { visit = { vendorName = "Dethelin", mapID = 2393, x = .51, y = .49, costs = {} } }
Check(EH:VendorDestination(entry).x == .51, "An observed merchant route remains preferred to static coordinates")
EH.db.vendorSources[66000] = nil
local previous = { mapID = 100, x = .2, y = .3 }; waypoint = previous
EH:VendorWaypoint(entry)
Check(waypoint == previous and popup.which == "ELEMENTHOUSING_WAYPOINT", "Library navigation retains current-pin confirmation")
combat = true; StaticPopupDialogs.ELEMENTHOUSING_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint == previous, "Library confirmation rechecks combat")
combat = false; StaticPopupDialogs.ELEMENTHOUSING_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint.mapID == 2393 and waypoint.x == .524 and supertracked, "Confirmed library route uses native waypoint and supertracking APIs")
local canSet = C_Map.CanSetUserWaypointOnMap
C_Map.CanSetUserWaypointOnMap = function() return false end
waypoint = previous; EH:VendorWaypoint(entry)
Check(waypoint == previous, "Unsupported library maps leave an existing waypoint intact")
C_Map.CanSetUserWaypointOnMap = canSet
local tracking = C_ContentTracking; C_ContentTracking = nil
Check(EH:VendorDestination(entry).source == "library", "Bundled waypoints work when optional tracking getters are unavailable")
C_ContentTracking = tracking
local ambiguous = EH:MakeEntry(Decor(66001, "Vendor: Pascal-K1N6"))
Check(#ambiguous.libraryVendors == 0, "A vendor name shared by different zones cannot guess the seller")
ambiguous = EH:MakeEntry(Decor(66002, "Vendor: Pascal-K1N6\nZone: Founder's Point"))
Check(#ambiguous.libraryVendors == 1 and ambiguous.libraryVendors[1].mapID == 2352,
    "An explicit zone distinguishes the endeavor vendor from the Mechagon NPC")
ambiguous = EH:MakeEntry(Decor(66003, "Vendor: Pascal-K1N6\nZone: Razorwind Shores"))
Check(#ambiguous.libraryVendors == 1 and ambiguous.libraryVendors[1].mapID == 2351,
    "Sourced alternate neighborhood coordinates resolve without a synthetic NPC ID")
Check(#EH:MakeEntry(Decor(66004, "Vendor: Dethelin's assistant")).libraryVendors == 0, "Name substrings cannot infer selling routes")
Check(#EH:MakeEntry(Decor(66005, "Profession: Dethelin")).libraryVendors == 0, "A vendor name cannot reclassify a profession source")
UnitFactionGroup = function() return "Horde" end
local alliance = EH:MakeEntry(Decor(66006, "Vendor: Innkeeper Belm"))
Check(EH:VendorDestination(alliance) == nil, "Opposite-faction library destinations are not chosen automatically")
UnitFactionGroup = function() return "Alliance" end
Check(EH:VendorDestination(alliance).mapID == 27, "Eligible faction can use its sourced destination")
