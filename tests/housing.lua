-- Exercise documented read-only getters, asynchronous replies, and actual information page controls.
local requests, liveReads, forbidden, now = {}, 0, 0, 10
local current, neighborhood, owned, initiative, plots = nil, nil, false, nil, {}
GetTime = function() return now end
-- Record void native requests; only corresponding events may supply their results.
local function Request(key, guid)
    requests[key] = (requests[key] or 0) + 1
    if guid then requests.lastGUID = guid end
end
-- Detect any accidental editor or bulletin-board operation outside its supported context.
local function Forbidden()
    forbidden = forbidden + 1
    error("Restricted operation")
end
C_Housing = {
    GetCurrentHouseInfo = function() return current end,
    GetPlayerOwnedHouses = function() Request("houses") end,
    GetCurrentHouseLevelFavor = function(guid) Request("favor", guid) end,
    GetHouseLevelRewardsForLevel = function(level) Request("rewards", level) end,
    GetCurrentNeighborhoodGUID = function() return neighborhood end,
    GetUIMapIDForNeighborhood = function(guid) return guid == "N1" and 100 or 200 end,
    GetHouseLevelFavorForLevel = function(level) return level * 100 end,
    GetMaxHouseLevel = function() return 10 end,
    IsInsideOwnedHouseOrPlot = function() return owned end,
    IsInsideOwnedHouse = function() return owned end,
    IsInsideOwnedPlot = function() return false end,
    DoesFactionMatchNeighborhood = function() return true end,
    GetCurrentHouseRefundAmount = function() return 50 end,
    GetHousingAccessFlags = function() return 17 end,
}
C_HousingNeighborhood = {
    RequestNeighborhoodInfo = function() Request("neighborhood") end,
    GetNeighborhoodName = function() return neighborhood == "N1" and "First neighborhood" or "Second neighborhood" end,
    GetNeighborhoodMapData = function() return plots end,
    IsNeighborhoodOwner = function() return false end,
    IsNeighborhoodManager = function() return true end,
    RequestNeighborhoodRoster = Forbidden,
}
C_NeighborhoodInitiative = {
    GetActiveNeighborhood = function() return initiative and initiative.neighborhoodGUID end,
    GetNeighborhoodInitiativeInfo = function() return initiative end,
    RequestNeighborhoodInitiativeInfo = function() Request("endeavor") end,
    GetAvailableHouseXP = function() return 25 end,
    GetRequiredLevel = function() return 20 end,
    SetActiveNeighborhood = Forbidden,
}
C_HousingDecor = {
    GetNumDecorPlaced = function() liveReads = liveReads + 1; return 12 end,
    GetAllMaxPlacementBudgets = function() return { [1] = 100, [2] = 10 }, { [1] = 40 } end,
    GetAllSpentPlacementBudgets = function() return { [1] = 12 }, { [1] = 0 } end,
    GetDecorName = function() return "Garden chair" end,
    GetAllPlacedDecor = Forbidden,
}
C_HousingLayout = {
    GetNumActiveRooms = function() return 3 end, GetLowestOccupiedFloorIndex = function() return -1 end,
    GetHighestOccupiedFloorIndex = function() return 1 end, GetSpentPlacementBudget = function() return 3 end,
    GetRoomPlacementBudget = function() return 8 end,
}
C_HouseExterior = { GetCurrentHouseExteriorType = function() return 1, "Elven cottage" end,
    GetCurrentHouseExteriorSize = function() return 1 end }
Enum.NeighborhoodType = { Private = 1 }
Enum.NeighborhoodOwnerType = { Player = 1 }
Enum.HousingPlotOwnerType = { None = 0, Player = 1 }
Enum.ResidentType = { Owner = 1, Resident = 2 }
Enum.HousingFixtureSize = { Small = 1 }
Enum.HouseLevelRewardValueType = { Rooms = 2 }
Enum.HouseSettingFlags = {}
for i, prefix in ipairs({ "HouseAccess", "PlotAccess", "BlueprintExport" }) do
    for j, group in ipairs({ "Anyone", "Neighbors", "Guild", "Friends", "Party" }) do
        Enum.HouseSettingFlags[prefix .. group] = 2 ^ ((i - 1) * 5 + j - 1)
    end
end
FlagsUtil = { IsSet = function(value, mask) return bit.band(value, mask) ~= 0 end }
-- Emit the real addon dispatcher so registration and routing participate in the assertions.
local function Event(name, ...)
    Check(EH.events.events[name], "Documented event registered: " .. name)
    EH.events.scripts.OnEvent(EH.events, name, ...)
end
-- Read the structured facts supplied to dashboard cards, independent of their visual arrangement.
local function Page(key)
    local lines = {}
    for _, section in ipairs(EH.infoPages[key].data.sections) do
        if section.message then lines[#lines + 1] = section.message end
        for _, field in ipairs(section.fields) do lines[#lines + 1] = field.label .. ": " .. field.value end
    end
    return table.concat(lines, "\n")
end
-- Match a complete user-facing fact in the rendered page.
local function Contains(text, expected, message)
    Check(text:find(expected, 1, true), message .. ": " .. expected)
end
EH:Initialize()
Check(not next(requests), "Login does not query housing")
Check(EH:Show("catalog"), "Window constructs all four tabs")
Check(not next(requests), "Catalog does not query housing")
EH.houseTab.scripts.OnClick(EH.houseTab)
Check(EH.view == "house" and EH.infoPages.house.panel:IsShown() and not EH.catalogPanel:IsShown(), "House tab switches panels")
Check(not EH.professionShortcut:IsShown() and not EH.infoPages.neighborhood.panel:IsShown(), "Catalog shortcuts hide on House")
Check(requests.houses == 1 and not requests.favor, "Owned houses load asynchronously before favor requests")
Contains(Page("house"), "Loading your owned houses...", "Void request does not invent an empty list")
local first = { houseGUID = "H1", houseName = "First home", ownerName = "Owner", plotID = 0,
    neighborhoodGUID = "N1", neighborhoodName = "First neighborhood", plotCost = 0, plotReserved = false }
local second = { houseGUID = "H2", houseName = "Second home", plotID = 7, neighborhoodGUID = "N2" }
now = now + 5
Event("PLAYER_HOUSE_LIST_UPDATED", { first, second })
Check(requests.houses == 1, "A delayed owned-list reply cannot create a request loop")
Check(requests.favor == 1 and requests.lastGUID == "H1", "Owned-list event requests the selected home's favor")
Contains(Page("house"), "Name: First home", "First owned home renders")
Contains(Page("house"), "Plot: 0", "Native plot index is not changed")
Contains(Page("house"), "Plot cost: 0 copper", "Known zero prices remain zero")
Contains(Page("house"), "House level: Unknown", "Unavailable house level is not zero")
Check(liveReads == 0, "Away from the house no live budgets are read")
now = now + 5
Event("HOUSE_LEVEL_FAVOR_UPDATED", { houseGUID = "H1", houseLevel = 0, houseFavor = 20 })
Check(requests.favor == 1, "A delayed favor reply cannot create a request loop")
Contains(Page("house"), "House level: 0", "Current level uses Blizzard's actual level rather than the next reward level")
Contains(Page("house"), "XP still needed: 80", "House progress uses the next threshold")
Contains(Page("house"), "Maximum house level: 10", "Native maximum level stays correct")
Check(requests.rewards == 1 and requests.lastGUID == 1, "Next-level rewards use the documented request")
Event("RECEIVED_HOUSE_LEVEL_REWARDS", 1, { { valueType = 2, oldValue = 3, newValue = 4 } })
Contains(Page("house"), "Next level reward: Rooms - 3 -> 4", "Asynchronous reward renders")
Event("HOUSE_LEVEL_FAVOR_UPDATED", { houseGUID = "H2", houseLevel = 5, houseFavor = 500 })
Contains(Page("house"), "House level: 0", "Another home's reply cannot change current progress")
EH.houseSelector.scripts.OnClick(EH.houseSelector)
Check(lastMenu.items and #lastMenu.items == 2, "Selector includes both owned homes")
for _, radio in ipairs(lastMenu.items) do if radio.label:find("Second home", 1, true) then radio.action() end end
Contains(Page("house"), "Name: Second home", "House selector changes only the addon selection")
Contains(Page("house"), "House level: 5", "Selected second home uses its own cached level")
EH.selectedHouseGUID = nil; current, owned = second, true
now = now + 3
Event("HOUSE_PLOT_ENTERED", second)
Contains(Page("house"), "Name: Second home", "Current owned house is preferred by default")
Contains(Page("house"), "Placed decor in the current area: 12", "Live decor count renders at home")
Contains(Page("house"), "Active rooms: 3", "Room information renders")
Contains(Page("house"), "Exterior style: Elven cottage", "Exterior style renders")
Contains(Page("house"), "Decor Placement: 12 / 100", "Interior placement budget renders")
Contains(Page("house"), "Pet Decor: Unknown / 10", "Missing spent data remains unknown")
Contains(Page("house"), "Decor Placement: 0 / 40", "Exterior known-zero budget renders")
Contains(Page("house"), "Room placement budget: 3 / 8", "Room budget renders")
Contains(Page("house"), "House visitors: Anyone", "Anyone access takes precedence over individual groups")
Contains(Page("house"), "Plot visitors: No one", "Empty native access flags show no visitors")
Contains(Page("house"), "Blueprint export permission: No one", "Blueprint permissions render without changing them")
local rewardRequests = requests.rewards
Event("HOUSE_LEVEL_FAVOR_UPDATED", { houseGUID = "H2", houseLevel = 10, houseFavor = 1000 })
Contains(Page("house"), "Maximum house level reached.", "Maximum level has no fabricated future threshold")
Check(requests.rewards == rewardRequests, "Maximum level does not request unavailable future unlocks")
EH.selectedHouseGUID = "H1"; EH:RenderHousingInfo()
Contains(Page("house"), "Enter this house or its plot", "Second home's budgets do not leak into selected first home")
local reads = liveReads
current, owned = { houseGUID = "VISITOR", houseName = "Visitor's home" }, false
Event("HOUSE_PLOT_EXITED")
Check(liveReads == reads and EH:SelectedHouse().houseGUID == "H1", "Visiting someone else never becomes an owned home")
EH.selectedHouseGUID = nil; current, owned = { houseGUID = "SECRET" }, true
EH:RenderHousingInfo()
Contains(Page("house"), "Name: First home", "Secret current house identity cannot be compared or displayed")
neighborhood = "N1"
initiative = { neighborhoodGUID = "N1", isLoaded = true, title = "Community garden", description = "Build together",
    currentProgress = 25, progressRequired = 100, playerTotalContribution = 4, duration = 3600,
    tasks = { { taskName = "Plant seeds", description = "Plant five", progressContributionAmount = 5,
        timesCompleted = 0, completed = false, inProgress = true, requirementsList = {} } },
    milestones = { { milestoneOrderIndex = 1, requiredContributionAmount = 50,
        rewards = { { title = "Garden chair", description = "A chair", decorID = 1, decorQuantity = 2, favor = 10 } } } } }
plots = { { plotID = 2, ownerType = 1, ownerName = "Neighbor", plotCost = nil },
    { plotID = 1, ownerType = 0, plotCost = 100, mapPosition = { GetXY = function() return .2, .3 end } } }
EH.neighborhoodTab.scripts.OnClick(EH.neighborhoodTab)
Check(requests.neighborhood == 1 and requests.endeavor == 1, "Neighborhood tab requests only the current active neighborhood")
Contains(Page("neighborhood"), "Known plots: 2", "Known plots render")
Contains(Page("neighborhood"), "Occupied: 1", "Plot ownership counts render")
Contains(Page("neighborhood"), "100 copper - 20.0, 30.0", "Known plot cost and coordinates render")
Contains(Page("neighborhood"), "Visit the neighborhood bulletin board", "Resident availability is explained")
Contains(Page("neighborhood"), "Title: Community garden", "Current endeavor renders")
Contains(Page("neighborhood"), "Progress: 25 / 100", "Endeavor progress renders")
Contains(Page("neighborhood"), "Task: Plant seeds", "Endeavor tasks render")
Contains(Page("neighborhood"), "Decor reward: Garden chair x 2", "Milestone rewards render")
Event("UPDATE_BULLETIN_BOARD_ROSTER", { neighborhoodGUID = "N1", neighborhoodName = "First neighborhood",
    neighborhoodType = 1, neighborhoodOwnerType = 1, ownerName = "Owner" },
    { { playerGUID = "P1", residentName = "Neighbor", plotID = 2, residentType = 1, isOnline = false } })
Contains(Page("neighborhood"), "Neighbor: Plot 2 - Owner - Online: No", "Public bulletin roster renders")
Event("UPDATE_BULLETIN_BOARD_ROSTER_STATUSES", { { playerGUID = "P1", residentType = 2, isOnline = true } })
Contains(Page("neighborhood"), "Resident - Online: Yes", "Roster status event updates existing residents")
Event("NEIGHBORHOOD_NAME_UPDATED", "N1", "Renamed neighborhood")
Contains(Page("neighborhood"), "Name: Renamed neighborhood", "Neighborhood rename is immediate")
neighborhood, plots = "N2", {}
now = now + 3
Event("ZONE_CHANGED_NEW_AREA")
Contains(Page("neighborhood"), "Name: Second neighborhood", "Travel shows the current neighborhood")
Check(not Page("neighborhood"):find("Community garden", 1, true), "Prior neighborhood endeavor is not shown after travel")
Check(not Page("neighborhood"):find("Neighbor: Plot", 1, true), "Prior neighborhood roster is not shown after travel")
Check(requests.endeavor == 1, "Addon does not switch Blizzard's active endeavor neighborhood")
neighborhood = nil; Event("ZONE_CHANGED")
Contains(Page("neighborhood"), "Enter a neighborhood", "Outside-neighborhood state is clear")
combat, now, neighborhood = true, now + 3, "N1"
local before = requests.neighborhood
EH:RefreshHousingInfo()
Check(EH.housingDeferred and requests.neighborhood == before, "Housing requests defer in combat")
combat = false; Event("PLAYER_REGEN_ENABLED")
Check(not EH.housingDeferred and requests.neighborhood == before + 1, "Visible housing requests resume after combat")
local total = requests.neighborhood
EH.frame:Hide(); now = now + 3
Event("NEIGHBORHOOD_MAP_DATA_UPDATED")
EH:RefreshHousingInfo()
Check(requests.neighborhood == total, "Hidden pages make no housing requests")
EH:Show("house"); now = now + 3
local houseRequests = requests.houses
ElvUI[1].media.rgbvaluecolor = { .2, .4, .6 }; ElvUI[1]:UpdateMedia()
Check(requests.houses == houseRequests, "Native palette updates never request house data")
Check(EH.houseTab.text.state_SetTextColor[1] == .2, "Active tab follows native ElvUI colors")
Check(EH.infoPages.house.cards["overview"].labels[1].state_SetTextColor[1] == .2, "Dashboard heading follows native ElvUI colors")
EH.housing.houses = {}; current, owned = nil, false
EH:RenderHousingInfo()
Contains(Page("house"), "No owned houses were reported", "Empty owned-house replies have a clear state")
Check(forbidden == 0, "No restricted decor enumeration, roster request, or endeavor selection runs")
Check(not EH.db.housing and not EH.db.rosters, "Neighborhood and house snapshots remain session-only")
