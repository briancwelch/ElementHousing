-- Verify alternate native maps, observed merchant routes, and both acquisition filters in a fresh client.
local function Decor(id, itemID, source, owned)
    return { recordID = id, entryType = Enum.HousingCatalogEntryType.Decor, itemID = itemID,
        name = "Decor " .. id, sourceText = source or "Vendor: Dethelin", totalNumStored = owned or 0,
        totalNumPlaced = 0, remainingRedeemable = 0, categoryIDs = {}, subcategoryIDs = {},
        dataTagsByID = {}, quality = 1, size = 66, isAllowedIndoors = true, isAllowedOutdoors = true }
end

maps[100].name, maps[200].name = "Silvermoon City", "Twilight Highlands"
catalog = { Decor(30, 245284), Decor(31, 245285) }
catalog[1].name = "Silvermoon Wooden Chair"
currencyInfo[2815], currencyInfo[3319] = { name = "Resonance Crystals" }, { name = "Twilight's Blade Insignia" }
itemMetadata[245284], itemMetadata[245285] = { expansionID = 11 }, { expansionID = 0 }
vendors[30] = { creatureName = "Dethelin", zoneName = "Silvermoon City" }
EH:Initialize(); EH:Show(); Drain()
Check(EH.filterControls.expansion and EH.filterControls.currency, "Both acquisition selectors are present in the actual sidebar")
Check(EH.expansions["0"] == "Classic" and EH.expansions["11"] == "Midnight", "Classic ID zero and Midnight use native expansion names")
Check(not EH.byID[30].currencyTypes.gold, "Unknown vendor prices are not classified as gold")

local bestMap = C_ContentTracking.GetBestMapForTrackable
C_ContentTracking.GetBestMapForTrackable = function() return Enum.ContentTrackingResult.Failure end
locations[30] = { status = 0, mapID = 100, x = 0.4, y = 0.6, targetType = 1 }
local point = EH:VendorDestination(EH.byID[30])
Check(point and point.mapID == 100 and point.x == 0.4, "Current zone can resolve native coordinates when the preferred map lookup fails")
locations[30].targetType = Enum.ContentTrackingTargetType.Quest
Check(EH:VendorDestination(EH.byID[30]) == nil, "Alternate-map queries still reject non-vendor targets")
locations[30] = nil
local previous = { mapID = 200, x = 0.2, y = 0.3 }
waypoint = previous
EH:VendorWaypoint(EH.byID[30])
Check(waypoint == previous and messages[#messages]:find("shop once", 1, true), "Missing vendor data preserves the pin and explains how to learn the route")

merchantName, merchantGUID = "Dethelin", "Creature-0-1-2-3-250982-000001"
merchantItems = {
    { itemID = 245284, price = 0, hasExtendedCost = true,
        costs = { { amount = 3000, link = "|Hcurrency:2815:3000|h[Resonance Crystals]|h" } } },
    { itemID = 245285, price = 10000, hasExtendedCost = true,
        costs = { { amount = 50, link = "|Hcurrency:3319:50|h[Insignia]|h" },
            { amount = 2, link = "|Hitem:777|h[Trade token]|h" } } },
    { itemID = 999999, price = 0, hasExtendedCost = false },
}
EH.events.scripts.OnEvent(EH.events, "MERCHANT_SHOW"); Drain()
local routes = EH.db.vendorSources[30]
local observed = routes and routes["250982:100"]
Check(observed and observed.vendorName == "Dethelin" and observed.x == 0.42,
    "Opening the actual selling merchant records its nearby location on the containing zone")
Check(observed.costs["currency:2815"] == 3000 and observed.costs.gold == nil,
    "Currency-only purchases do not acquire a spurious gold price")
Check(EH.db.vendorSources[31]["250982:100"].costs.gold == 10000,
    "Mixed purchases retain their gold component")
Check(EH.byID[31].currencyTypes["currency:3319"] and EH.byID[31].currencyTypes["item:777"],
    "Mixed purchases retain every currency and item-token component")
Check(EH.db.vendorSources[999999] == nil, "Merchant items outside the housing catalog are ignored")
Check(waypoint == previous, "Learning a merchant does not replace a waypoint")
Check(EH.currencies["currency:2815"] == "Resonance Crystals", "Currency selector uses localized native currency names")
point = EH:VendorDestination(EH.byID[30])
Check(point and point.mapID == 100 and point.x == 0.42 and point.vendorName == "Dethelin",
    "Dethelin chair resolves from its observed selling route when native tracking has no map")
EH:VendorWaypoint(EH.byID[30])
Check(waypoint == previous and popup.which == "ELEMENTHOUSING_WAYPOINT", "Observed vendor routes retain replacement confirmation")
combat = true; StaticPopupDialogs.ELEMENTHOUSING_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint == previous, "Confirmation rechecks combat for observed routes")
combat = false; StaticPopupDialogs.ELEMENTHOUSING_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint.x == 0.42 and supertracked, "Confirmed observed route creates the vendor waypoint and supertracking")
Check(messages[#messages]:find("Dethelin", 1, true), "Waypoint confirmation identifies the resolved vendor")
playerPositions[100], merchantItems[1].costs = nil, {}
EH.events.scripts.OnEvent(EH.events, "MERCHANT_UPDATE"); Drain()
Check(EH.db.vendorSources[30]["250982:100"].x == 0.42, "Pending player position preserves the verified merchant location")
Check(EH.db.vendorSources[30]["250982:100"].costs["currency:2815"] == 3000,
    "Pending extended costs preserve the verified purchase currency")
playerPositions[100] = { x = 0.42, y = 0.62 }

EH:SetFilter("currency", "currency:2815")
Check(#EH.results == 1 and EH.results[1].info.recordID == 30, "Currency selector filters the actual catalog")
EH:SetFilter("expansion", "0")
Check(#EH.results == 0, "Expansion and currency filters combine")
EH:SetFilter("currency", "gold")
Check(#EH.results == 1 and EH.results[1].info.recordID == 31, "Classic and mixed gold cost combine correctly")
EH:SavePreset("Acquisition")
EH:ResetFilters()
Check(EH.filters.expansion == "all" and EH.filters.currency == "all", "Reset clears both new filters")
EH:LoadPreset("Acquisition")
Check(EH.filters.expansion == "0" and EH.filters.currency == "gold", "Presets preserve both new filters")
EH:ResetFilters()

-- A new vendor changes only its own recorded route and does not borrow another vendor's currency.
merchantName, merchantGUID = "Other vendor", "Creature-0-1-2-3-500000-000001"
merchantItems = { { itemID = 245284, price = 20000, hasExtendedCost = false } }
playerPositions[100] = { x = 0.8, y = 0.8 }
EH.events.scripts.OnEvent(EH.events, "MERCHANT_UPDATE"); Drain()
playerPositions[100] = { x = 0.42, y = 0.62 }
EH:SetFilter("vendor", "Other vendor"); EH:SetFilter("currency", "currency:2815")
Check(#EH.results == 0, "Selecting a vendor cannot match currency sold only by a different vendor")
EH:SetFilter("currency", "gold")
Check(#EH.results == 1, "Selected vendor matches its own gold purchase route")
point = EH:VendorDestination(EH.byID[30])
Check(point and point.vendorName == "Other vendor", "Waypoint selection respects the selected observed vendor")
EH:ResetFilters()
point = EH:VendorDestination(EH.byID[30])
Check(point and point.vendorName == "Dethelin", "Unfiltered waypoints prefer the nearby observed vendor")
playerPositions[100] = { x = 0.79, y = 0.79 }
point = EH:VendorDestination(EH.byID[30])
Check(point and point.vendorName == "Other vendor", "Nearest observed vendor follows the player's position")
playerPositions[100] = { x = 0.42, y = 0.62 }
EH.events.scripts.OnEvent(EH.events, "MERCHANT_CLOSED")
merchantItems[1].price = 999
EH.events.scripts.OnEvent(EH.events, "MERCHANT_UPDATE"); Drain()
Check(EH.db.vendorSources[30]["500000:100"].costs.gold == 20000, "Closed merchant updates cannot overwrite observed costs")
combat = true; EH.events.scripts.OnEvent(EH.events, "MERCHANT_SHOW")
Check(EH.db.vendorSources[30]["500000:100"].costs.gold == 20000, "Combat does not record new merchant data")
combat = false; EH.events.scripts.OnEvent(EH.events, "MERCHANT_CLOSED")
Check(EH.db.vendorSources[30]["250982:100"].costs["currency:2815"] == 3000, "Other merchants preserve Dethelin's route")

-- Prefer catalog expansion classifications over the item's introduction expansion.
EH.tagGroups = { { groupID = 9, tags = { { tagID = 71, tagName = "The Burning Crusade" } } } }
local tagged = Decor(50, 245284)
tagged.dataTagsByID[71] = true
local entry = EH:MakeEntry(tagged)
Check(entry.expansionIDs[1] and not entry.expansionIDs[11], "Native expansion tags take priority over item metadata")
EXPANSION_NAME1 = "L'extension"
EH.tagGroups[1].tags[1].tagName = "L'extension"
Check(EH:MakeEntry(tagged).expansionIDs[1], "Expansion tag matching respects native localization")
EXPANSION_NAME1, EH.tagGroups = "The Burning Crusade", {}
local pending = Decor(51, 500051)
local requests = #itemRequests
entry = EH:MakeEntry(pending); EH:MakeEntry(pending)
Check(not next(entry.expansionIDs) and #itemRequests == requests + 1, "Uncached expansion stays unknown and requests item data once")
catalog[#catalog + 1] = pending
itemMetadata[500051] = { expansionID = 10 }
EH.events.scripts.OnEvent(EH.events, "GET_ITEM_INFO_RECEIVED", 500051, true); Drain()
Check(EH.byID[51].expansionIDs[10] and EH.expansions["10"] == "The War Within", "Item data notification refreshes expansion choices")

-- Invalid coordinates, unavailable maps, and restricted acquisition values never become user pins.
for _, coordinates in ipairs({ { 0, 0 }, { -0.1, 0.5 }, { 0.5, 1.1 }, { 0 / 0, 0.5 }, { math.huge, 0.5 }, { "SECRET", 0.5 } }) do
    Check(EH:VendorPoint(100, coordinates[1], coordinates[2]) == nil, "Unsafe vendor coordinate rejected")
end
Check(EH:VendorPoint(99999, 0.5, 0.5) == nil, "Map without waypoint support rejected")
Check(EH:VendorPoint("SECRET", 0.5, 0.5) == nil, "Restricted map ID rejected")
Check(EH:CostText({ cost = "SECRET", currencyType = 2815 }) == "Unknown", "Restricted costs are not formatted")
Check(EH:CostText({ cost = 10000, currencyType = "SECRET" }) == "Unknown", "Restricted currency IDs are not inspected")
Check(EH:CostText({ cost = 0 / 0, currencyType = 0 }) == "Unknown", "Invalid costs are not presented as prices")
EH.db.vendorSources[9000] = false
Check(not EH:ObservedVendorDestination({ info = { recordID = 9000 } }), "Malformed saved vendor routes are ignored")
merchantName, merchantGUID = "Dethelin", "Player-0-1-2-3-250982-000001"
EH.events.scripts.OnEvent(EH.events, "MERCHANT_SHOW"); Drain()
Check(EH.db.vendorSources[30]["250982:100"].costs["currency:2815"] == 3000, "Non-creature units cannot create vendor observations")
EH.events.scripts.OnEvent(EH.events, "MERCHANT_CLOSED")

-- Cover every expansion ID against gold, real currencies, tokens, unknown costs, and ownership.
local currencies = { "gold", "currency:2815", "currency:3319", "item:777", "unknown" }
for expansion = 0, 11 do
    for _, currency in ipairs(currencies) do
        for owned = 0, 1 do
            local id = 1000 + expansion * 10 + owned
            local info = Decor(id, id + 100000, "Vendor: Matrix vendor", owned)
            itemMetadata[info.itemID] = { expansionID = expansion }
            EH.db.vendorSources[id] = { matrix = { vendorName = "Matrix vendor", costs = currency == "unknown" and {} or { [currency] = 1 } } }
            entry = EH:MakeEntry(info)
            EH.filters.expansion, EH.filters.currency = tostring(expansion), currency
            Check(EH:Matches(entry, {}), "Matching expansion/currency pair includes either ownership state")
            EH.filters.expansion = tostring((expansion + 1) % 12)
            Check(not EH:Matches(entry, {}), "Different expansion is excluded for every currency")
            EH.filters.expansion, EH.filters.currency = tostring(expansion), currency == "gold" and "currency:2815" or "gold"
            Check(not EH:Matches(entry, {}), "Different currency is excluded for every expansion")
        end
    end
end
EH:ResetFilters()
C_ContentTracking.GetBestMapForTrackable = bestMap
