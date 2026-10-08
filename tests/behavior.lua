-- Create realistic native catalog fixtures with separate acquisition routes and ownership.
local function Decor(id, name, source, stored, placed)
    return { recordID = id, entryType = 1, itemID = id + 1000, name = name, sourceText = source,
        totalNumStored = stored or 0, totalNumPlaced = placed or 0, remainingRedeemable = 0,
        categoryIDs = { 1 }, subcategoryIDs = { 2 }, dataTagsByID = { [7] = true }, quality = 3, size = 66,
        isAllowedIndoors = true, isAllowedOutdoors = false, placementCost = 2, asset = 1234 }
end
catalog = { Decor(1, "Leather Chair", "Profession: Leatherworking"),
    Decor(2, "Gem Lamp", "Profession: Jewelcrafting"),
    Decor(3, "Leather Rug", "Profession: Leatherworking\nVendor: Alice\nZone: Elwynn Forest"),
    Decor(4, "Mounted Chair", "Profession: Leatherworking", 0, 1),
    Decor(5, "Mystery Lamp", ""), Decor(6, "Westfall Table", "Vendor: Bob\nZone: Westfall") }
targets[1], targets[2], targets[6] = { 3, 900 }, { 3, 901 }, { 1, 10 }
vendors[3] = { creatureName = "Alice", zoneName = "Elwynn Forest", cost = 40, currencyType = 1 }
vendors[6] = { creatureName = "Bob", zoneName = "Westfall" }
locations[3] = { status = 0, mapID = 100, x = 0.4, y = 0.6, targetType = 1 }
locations[6] = { status = 0, mapID = 200, x = 0.4, y = 0.6, targetType = 1 }

EH.events.scripts.OnEvent(EH.events, "PLAYER_LOGIN")
Check(EH.frame == nil, "Login must not create a visible housing window")
Check(EH.db.schema == 2 and EH.version == "2.0.9", "Fresh native schema and release")
Check(EH.professions[755] and EH.professions[186] and not EH.professions[165], "Character is a jewelcrafter/miner")
Check(pluginName == "ElementHousing" and EH.options.childGroups == "tree", "ElvUI plugin tree registration")
Check(ElvUI[1].Options.args.ElementHousing == nil, "Wait for ElvUI's plugin callback before inserting options")
pluginCallback()
local header = ElvUI[1].Options.name
pluginCallback(); pluginCallback()
Check(ElvUI[1].Options.name == header, "Header callback must be idempotent")
Check(EH:Brand():find("|cff3fc7eb", 1, true) and EH:Brand():find("|cff8787ed", 1, true), "Brand gradient endpoints")
Check(EH:Icon("housing"):find("ElvUI_mMediaTag", 1, true), "Use installed nMediaTag glyphs")
Check(LibStub("LibDBIcon-1.0"):IsRegistered("ElementHousing"), "Real LibDBIcon launcher registered")
local launcher = LibStub("LibDBIcon-1.0"):GetMinimapButton("ElementHousing")
Check(launcher.icon.texture == EH.brandIcon, "Launcher always displays the original housing artwork")
launcher.scripts.OnClick(launcher, "LeftButton"); Drain()
Check(EH.windowReady and EH.frame:IsShown(), "Minimap launcher constructs and opens catalog")
Check(#EH.entries == 6 and #EH.results == 6, "Independent native results load all base decor")
Check(EH.byID[4].owned == 1 and EH.byID[4].stored == 0, "Placed decor is owned")
Check(EH.zones["100"] == "Elwynn Forest" and EH.vendors.Alice, "Native zone/vendor browse choices")
Check(EH.searcher.SetCollectedState and EH.searcher.SetUncollectedState, "Native ownership filters must include both")
EH:SetFilter("profession", "mine")
Check(#EH.results == 5, "Hide LW-only missing decor; preserve mine, owned, unknown, alternate routes")
EH:SetFilter("ownership", "missing")
Check(#EH.results == 4, "Missing plus profession filter excludes placed-only decor")
EH:SetSetting("includeUnknownProfession", false)
Check(#EH.results == 3, "Explicit unknown exclusion")
EH:SetSetting("includeUnknownProfession", true)
EH:SetFilter("zone", "current")
Check(#EH.results == 1 and EH.results[1].info.recordID == 3, "Missing decor in the current zone, including subzones")
currentMap = 200; EH.events.scripts.OnEvent(EH.events, "ZONE_CHANGED_NEW_AREA")
Check(#EH.results == 1 and EH.results[1].info.recordID == 6, "Current-zone filter follows travel")
EH:ResetFilters(); EH:SetFilter("source", "vendor")
Check(#EH.results == 2, "Browse vendor decor with native/source-text routes")
EH:SetFilter("vendor", "Alice")
Check(#EH.results == 1 and EH.results[1].info.recordID == 3, "Specific vendor filter")
EH:ResetFilters(); EH:SetFilter("search", 'name:"gem lamp" -leather')
Check(#EH.results == 1 and EH.results[1].info.recordID == 2, "Field phrases and exclusions")
EH:SetFilter("search", 'ZONE:"elwynn forest" source:vendor')
Check(#EH.results == 1 and EH.results[1].info.recordID == 3, "Case-insensitive field names")
EH:SetFilter("search", "%.*[]")
Check(#EH.results == 0, "Search strings are literal, never Lua patterns")
EH:ResetFilters(); EH:SetFilter("quality", "4")
Check(#EH.results == 0, "Quality filter")
EH:SetFilter("quality", "all"); EH:SetFilter("placement", "outdoor")
Check(#EH.results == 0, "Placement filter")
EH:ResetFilters(); EH.filters.tags[99] = true; EH:ApplyFilters()
Check(#EH.results == 0, "Tag filter combines with catalog constraints")
EH:ResetFilters(); EH:Favorite(EH.byID[2]); EH:SetFilter("ownership", "favorites")
Check(#EH.results == 1 and EH.results[1].info.recordID == 2, "Favorites are account-wide base record keys")
Check(EH:SavePreset("Favorites"), "Save independent filter preset")
EH:SetFilter("source", "vendor"); EH:LoadPreset("Favorites")
Check(EH.filters.source == "all" and EH.filters.ownership == "favorites", "Preset is not mutated by later changes")
EH:ChoiceMenu(EH.catalogTab, { all = "All", a = "A", b = "B" }, function() return "all" end, function(key) chosen = key end)
lastMenu.items[2].action(); Check(chosen == "a", "Menu closures bind individual choices")
EH:ResetFilters(); EH.selected = EH.byID[2]; EH:RenderDetails()
Check(EH.modelScene:IsShown() and EH.modelScene.sceneID == 1317, "Native decor scene loads in details")
Check(EH.modelScene.actor.state_SetModelByFileID[1] == 1234, "Correct model asset and decor actor")
EH:SetSetting("showModels", false)
Check(not EH.modelScene:IsShown() and EH.modelFallback:IsShown(), "Model off uses item fallback")
EH:SetSetting("showModels", true); EH:SetSetting("locked", true)
Check(not EH.resizeGrip:IsShown(), "Position lock hides resize grip")
EH:SetSetting("locked", false); EH.resizeGrip.scripts.OnMouseDown(nil, "LeftButton")
Check(EH.frame.sizing, "Native window starts bottom-right resizing")
EH.frame:SetSize(980, 610); EH.resizeGrip.scripts.OnMouseUp()
Check(EH.db.settings.width == 980 and EH.db.settings.height == 610 and not EH.frame.sizing, "Resize persists geometry")
Check(EH.visibleRows > 0 and #EH.rows <= 60, "Virtual list pool stays bounded")
EH.db.settings.width = math.huge; EH:ApplyWindowSettings()
Check(EH.frame:GetWidth() <= 1890, "Invalid geometry is clamped to screen")
waypoint = { mapID = 200, x = 0.1, y = 0.1 }
local previous = waypoint
locations[3].status = 1; EH:VendorWaypoint(EH.byID[3])
Check(waypoint == previous, "Pending location must preserve existing waypoint")
locations[3].status = 0; locations[3].x = 0 / 0; EH:VendorWaypoint(EH.byID[3])
Check(waypoint == previous, "Non-finite coordinates rejected")
locations[3].x = 0.4; locations[3].targetType = 2; EH:VendorWaypoint(EH.byID[3])
Check(waypoint == previous, "Only verified vendor targets create waypoints")
locations[3].targetType = 1; combat = true; EH:VendorWaypoint(EH.byID[3])
Check(waypoint == previous, "Combat guard preserves map pin")
combat = false; EH:VendorWaypoint(EH.byID[3])
Check(popup.which == "ELEMENTHOUSING_WAYPOINT" and waypoint == previous, "Existing pin requires configured confirmation")
StaticPopupDialogs.ELEMENTHOUSING_WAYPOINT.OnAccept(nil, popup.data)
Check(waypoint.mapID == 100 and waypoint.x == 0.4 and supertracked, "Accepted vendor pin and supertracking")
Check(EH:CostText(EH.byID[6]) == "Unknown", "Missing cost must never mean free")
EH:Show("blueprints")
Check(collectionRequested and EH.blueprintPanel:IsShown() and not EH.catalogPanel:IsShown(), "Blueprint workspace routing")
Check(not EH:InspectBlueprint("garbage"), "Invalid code is rejected before request")
Check(not EH:InspectBlueprint(string.rep("a", 4097)), "Oversized code is bounded")
EH:InspectBlueprint("BP-aaa", "First"); EH:InspectBlueprint("BP-bbb", "Second")
EH:BlueprintEvent("HOUSING_BLUEPRINT_CONTENTS_RECEIVED", { shareCode = "BP-aaa" })
Check(EH.blueprintContents == nil, "Ignore stale blueprint replies")
local contents = { shareCode = "BP-bbb", blockingRequirementFlags = 0, unmetRequirementFlags = 8,
    budgetInfo = { interiorBudgets = { [1] = { budgetType = 1, cost = 10, max = 100, current = 20 } }, exteriorBudgets = {} },
    contentGroups = { { contentType = 3, entries = { { contentType = 3, recordID = 2, name = "Gem Lamp", total = 5, numMissing = 3, invalid = false } } },
        { contentType = 2, entries = { { contentType = 2, recordID = 100, name = "Room", total = 1, numMissing = 0, invalid = false } } } } }
EH:BlueprintEvent("HOUSING_BLUEPRINT_CONTENTS_RECEIVED", contents)
local total, missing, invalid = EH:BlueprintSummary(contents)
Check(total == 6 and missing == 3 and invalid == 0, "Requirements use native total/numMissing quantities")
Check(EH:BlueprintIssues(contents)[1] == "Missing decor copies", "Native flags have meaningful requirement labels")
Check(EH:BlueprintBudgetText({ budgetType = 1, cost = 10, max = 100, current = 20 }, true):find("Decor placement", 1, true), "Budgets use native housing types")
C_HousingBlueprint.GetBlueprintTypeForCode = function() return Enum.HousingBlueprintType.Room end
Check(EH:BlueprintBudgetText({ budgetType = 1, cost = 10, max = 100, current = 20 }, true):find("80 available", 1, true), "Room additions account for the existing interior budget")
Check(EH.blueprintProgress.value == 0.5, "Blueprint availability progress bar")
EH:ImportBlueprint("BP-bbb")
Check(importedCode == "BP-bbb", "Import delegates to Blizzard's preview/confirmation")
combat = true; importedCode = nil; EH:ImportBlueprint("BP-bbb")
Check(importedCode == nil, "Blueprint imports blocked during combat")
combat = false; EH:ExportBlueprint()
Check(exportOpened, "Export opens native blueprint workflow")
Check(EH:SaveBlueprint("BP-bbb", " My layout "), "Save blueprint code with name")
Check(EH.db.blueprints["BP-bbb"].name == "My layout", "Local names are normalized")
EH:BlueprintEvent("HOUSING_BLUEPRINT_COLLECTION_RECEIVED", { groups = { { name = "Interior", entries = {
    { shareCode = "BP-bbb", name = "Native blueprint", isAutoSave = false },
    { shareCode = "BP-auto", name = "Backup", isAutoSave = true } } } } })
Check(#EH.blueprintList == 1, "Merge collection and saved codes without duplicates; hide autosaves")
EH:SetSetting("showAutosaves", true)
Check(#EH.blueprintList == 2, "Autosave setting refreshes library immediately")
EH:ForgetBlueprint("BP-bbb")
Check(EH.db.blueprints["BP-bbb"] == nil and #EH.blueprintList == 2, "Forgetting local code preserves Blizzard collection")
EH.broker.OnClick(nil, "RightButton")
Check(optionsPath == "ElementHousing", "Launcher opens correct ElvUI settings page")
EH.broker.OnClick(nil, "LeftButton")
Check(not EH.frame:IsShown() and not EH.modelScene:IsShown(), "Launcher closes window and releases model")
local count = #EH.entries; EH:ScheduleRefresh(); Drain()
Check(#EH.entries == count and EH.dirty, "Hidden window defers catalog work")
SlashCmdList.ELEMENTHOUSING("zone"); Drain()
Check(EH.frame:IsShown() and EH.view == "catalog" and EH.filters.zone == "current" and EH.filters.ownership == "missing", "Slash current-zone route works after reopen")
EH:OpenOptions()
Check(optionsPath == "ElementHousing" and EH.configFrame == nil, "All settings use the native ElvUI options page")
EH:SetSetting("minimap", false)
Check(not launcher:IsShown(), "Minimap preference updates actual LibDBIcon button")
EH:SetSetting("minimap", true)
Check(launcher:IsShown(), "Minimap button can be restored")
Check(not EH:Readable("SECRET") and EH:Call(function() return "SECRET" end) == nil, "Secret API data is not inspected")
EH:ResetFilters(); EH.tagGroups = { { tags = { { tagID = 7 }, { tagID = 8 } } }, { tags = { { tagID = 9 } } } }
EH.filters.tags = { [7] = true, [8] = true }; EH:ApplyFilters()
Check(#EH.results == 6, "OR semantics within a native tag group")
EH.filters.tags[9] = true; EH:ApplyFilters()
Check(#EH.results == 0, "AND semantics between native tag groups")
EH:ResetFilters()
local extra = EH:MakeEntry(Decor(80, "Other source", "Unlabelled source"))
Check(extra.sources.unknown and EH:MatchesProfession(extra, "mine"), "Unknown untracked sources fail open")
locations[81] = { status = 0, mapID = 100, x = 0.4, y = 0.6, targetType = 1, targetID = 50 }
vendors[81] = { creatureName = "Carol", zoneName = "Elwynn Forest" }
extra = EH:MakeEntry(Decor(81, "Native target", "Unlabelled source"))
Check(extra.sources.vendor and extra.vendorName == "Carol", "Untracked source can be resolved through the native waypoint target")
PROFESSIONS, VENDOR = "Berufe", "Händler"
EH.professionNames[165] = "Lederverarbeitung"
extra = EH:MakeEntry(Decor(82, "Stuhl", "Berufe: Lederverarbeitung"))
Check(not EH:MatchesProfession(extra, "mine"), "Localized profession metadata excludes unrelated missing decor")
extra = EH:MakeEntry(Decor(83, "Stuhl", "Berufe: Lederverarbeitung\nHändler: Anna"))
Check(EH:MatchesProfession(extra, "mine") and extra.vendorName == "Anna", "Localized alternate vendor route remains visible")
EH.professionNames[165], PROFESSIONS, VENDOR = "Leatherworking", nil, nil
EH:SetView("blueprints"); EH:SetSetting("showModels", true)
Check(not EH.modelScene:IsShown(), "Hidden catalog model stays released while changing blueprint settings")
EH:InspectBlueprint("BP-refresh")
EH:BlueprintEvent("HOUSING_BLUEPRINT_COLLECTION_RECEIVED", { groups = {} })
Check(EH.blueprintPending and EH.blueprintStatus == "Loading blueprint contents...", "Collection reply cannot clear active content loading")
EH:BlueprintEvent("HOUSING_BLUEPRINT_CONTENTS_RECEIVED", { shareCode = "BP-refresh", contentGroups = {}, budgetInfo = {}, blockingRequirementFlags = 0 })
local requests = #blueprintRequests
EH.events.scripts.OnEvent(EH.events, "HOUSING_STORAGE_UPDATED")
EH.events.scripts.OnEvent(EH.events, "HOUSING_STORAGE_ENTRY_UPDATED")
Check(#blueprintRequests == requests + 1, "Ownership updates recheck blueprint requirements without duplicate pending requests")
Drain()
EH.loading = true; local pendingTimers = #timers; EH:ScheduleRefresh()
Check(EH.dirty and #timers == pendingTimers, "Metadata notifications cannot starve an in-progress loading batch")
EH.loading = false
local oldContents = EH.blueprintContents
EH:BlueprintEvent("HOUSING_BLUEPRINT_CONTENTS_FAILURE", "BP-stale", 7)
Check(EH.blueprintContents == oldContents, "Stale blueprint failures cannot clear active data")
EH:Show("catalog"); Drain()
local originalCatalog, oldCount = catalog, #EH.entries
catalog = {}
for id = 100, 179 do catalog[#catalog + 1] = Decor(id, "Batched " .. id, "Vendor: Batch vendor") end
local getter, reads = C_HousingCatalog.GetCatalogEntryInfo, 0
C_HousingCatalog.GetCatalogEntryInfo = function(id) reads = reads + 1; return getter(id) end
EH:RefreshCatalog()
Check(EH.loading and reads == EH.db.settings.batchSize, "Synchronous search callback starts exactly one bounded batch")
local queued = #timers
EH:ScheduleRefresh()
Check(#timers == queued and EH.dirty, "Source notification waits for the active result read")
EH.frame:Hide(); Drain()
Check(not EH.loading and #EH.entries == oldCount, "Closing midway cancels all unpublished catalog batches")
catalog, C_HousingCatalog.GetCatalogEntryInfo = originalCatalog, getter
EH:Show("catalog"); Drain()
Check(#EH.entries == 6 and not EH.loading, "Reopening resumes a fresh complete catalog load")
local importedFrame = false
for _, frame in ipairs(frames) do if frame.nameID and frame.nameID:find("EHX", 1, true) then importedFrame = true end end
Check(not importedFrame, "No imported suite frames")
-- Exercise alternative sources through the actual native entry normalizer and filter engine.
EH:ResetFilters()
extra = EH:MakeEntry(Decor(90, "Two vendors", "Vendor: Alice\nZone: Elwynn Forest\nVendor: Bob\nZone: Westfall"))
Check(extra.vendorNames.Alice and extra.vendorNames.Bob and extra.maps[100] and extra.maps[200], "Retain both vendors and both source maps")
Check(EH:MatchesZone(extra, "100") and EH:MatchesZone(extra, "200"), "Zone filtering matches every known source location")
EH.filters.vendor = "Alice"
Check(EH:Matches(extra, {}), "First alternative vendor remains selectable")
EH.filters.vendor = "Bob"
Check(EH:Matches(extra, {}), "Second alternative vendor remains selectable")
EH.filters.vendor = nil
Check(EH:MatchesSearch(extra, EH:SearchTokens('vendor:alice zone:westfall')), "Field searches retain all known vendor/zone metadata")
local oldEntries = EH.entries
EH.entries = { extra }; EH:BuildFacets()
Check(EH.vendors.Alice and EH.vendors.Bob and EH.zones["100"] and EH.zones["200"], "Browse selectors include all alternatives")
EH.entries = oldEntries; EH:BuildFacets()
locations[91] = { status = 1 }
extra = EH:MakeEntry(Decor(91, "Loading route", "Profession: Leatherworking"))
Check(extra.pendingSource and not EH:MatchesProfession(extra, "mine"), "Pending waypoint metadata cannot override a known unrelated profession")
locations[91].status = 2
extra = EH:MakeEntry(Decor(91, "Known route", "Profession: Leatherworking"))
Check(not EH:MatchesProfession(extra, "mine"), "Resolved unrelated profession-only decor is excluded")
maps[300], maps[400] = { mapID = 300, name = "Shadowmoon Valley", mapType = 3 }, { mapID = 400, name = "Shadowmoon Valley", mapType = 3 }
EH.mapNames["shadowmoon valley"] = { [300] = true, [400] = true }
locations[92] = { status = 0, mapID = 300, x = 0.3, y = 0.5, targetType = 1 }
extra = EH:MakeEntry(Decor(92, "Outland source", "Vendor: Trader\nZone: Shadowmoon Valley"))
Check(EH:MatchesZone(extra, "300") and not EH:MatchesZone(extra, "400"), "Native map IDs distinguish shared zone names")
extra = EH:MakeEntry(Decor(93, "Unresolved shared zone", "Vendor: Trader\nZone: Shadowmoon Valley"))
Check(not EH:MatchesZone(extra, "300") and not EH:MatchesZone(extra, "400"), "Ambiguous locations respect default unknown exclusion")
EH.db.settings.includeUnknownZone = true
Check(EH:MatchesZone(extra, "300"), "Unknown location policy is configurable")
EH.db.settings.includeUnknownZone = false
Check(EH:SourceChoices().achievement:find("ElvUI_mMediaTag", 1, true) and EH:SourceChoices().vendor:find("shop.tga", 1, true), "Acquisition selectors use appropriate nMediaTag icons")
EH:ResetFilters()
EH.filters.subcategory = 2; EH:SetFilter("category", 1)
Check(EH.filters.subcategory == nil, "Changing category clears an incompatible old subcategory")
EH:ResetFilters()
extra = EH:MakeEntry(Decor(94, "Unmapped route", "Vendor: Trader\nZone: Unmapped Grove"))
EH.entries = { extra }; EH:BuildFacets()
Check(EH.zones["name:Unmapped Grove"] == "Unmapped Grove (location name)", "Known location names remain browseable without a native map ID")
Check(EH:MatchesZone(extra, "name:Unmapped Grove") and not EH:MatchesZone(extra, "100"), "Explicit named-zone browsing does not invent a current-zone location")
EH.entries = oldEntries; EH:BuildFacets()
EH:ChoiceMenu(EH.catalogTab, EH:SourceChoices(), function() return "all" end, function() end)
Check(EH:Plain(lastMenu.items[2].label) == " Achievement", "Source menus sort by readable labels rather than icon filenames")
local oldMapLookup = EH.mapNames
EH.mapNames = nil
extra = EH:MakeEntry(Decor(92, "Identified route", "Vendor: Trader\nZone: Shadowmoon Valley"))
Check(EH:MatchesZone(extra, "300") and not EH:MatchesZone(extra, "400"), "Exact native map identity wins even when the public zone index is missing")
maps[947], maps[946] = { parentMapID = 946 }, { parentMapID = 0 }
local children = C_Map.GetMapChildrenInfo
C_Map.GetMapChildrenInfo = function(root, ...) mapRootRequested = root; return children(root, ...) end
EH:RefreshCatalog(); Drain()
Check(mapRootRequested == 946, "Index zones from the public root including off-world regions")
C_Map.GetMapChildrenInfo, EH.mapNames = children, oldMapLookup
