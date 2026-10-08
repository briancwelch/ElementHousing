-- Supply illustrative public data for layout/graph checks; these values are never used by the addon runtime.
function SetupDashboardFixture()
    local house = { houseGUID = "HOME", neighborhoodGUID = "NEIGHBORHOOD", houseName = "Willow Hearth",
        ownerName = "Homeowner", neighborhoodName = "Clear Sky Vineyard", plotID = 7, plotCost = 10000000, plotReserved = false }
    EH.housing.houses, EH.housing.housesLoaded = { house }, true
    EH.housing.favor.HOME = { houseGUID = "HOME", houseLevel = 5, houseFavor = 550 }
    EH.housing.rewards[6] = { { objectName = "Interior decor capacity", oldValue = 200, newValue = 250 },
        { objectName = "Room placement budget", oldValue = 12, newValue = 14 } }
    EH.housing.neighborhoods.NEIGHBORHOOD = { neighborhoodGUID = "NEIGHBORHOOD", neighborhoodName = "Clear Sky Vineyard",
        locationName = "Founder's Point", neighborhoodType = 1, neighborhoodOwnerType = 1, ownerName = "Community", ownerGUID = "OWNER" }
    EH.housing.rosters.NEIGHBORHOOD = { { residentName = "Homeowner", plotID = 7, residentType = 1, isOnline = true },
        { residentName = "Willowgardener", plotID = 15, residentType = 2, isOnline = false } }
    Enum.NeighborhoodType, Enum.NeighborhoodOwnerType = { Private = 1 }, { Player = 1 }
    Enum.HousingPlotOwnerType, Enum.ResidentType = { None = 0, Stranger = 1 }, { Owner = 1, Resident = 2 }
    Enum.NeighborhoodInitiativeTaskType = { Single = 0, RepeatableFinite = 1 }
    Enum.HousingFixtureSize = { Small = 1 }
    C_Housing = {
        GetCurrentHouseInfo = function() return house end, GetCurrentNeighborhoodGUID = function() return "NEIGHBORHOOD" end,
        GetUIMapIDForNeighborhood = function() return 100 end, DoesFactionMatchNeighborhood = function() return true end,
        IsInsideOwnedHouseOrPlot = function() return true end, IsInsideOwnedHouse = function() return true end,
        IsInsideOwnedPlot = function() return false end, GetMaxHouseLevel = function() return 10 end,
        GetHouseLevelFavorForLevel = function(level) return level * 100 end, GetCurrentHouseRefundAmount = function() return 5000000 end,
    }
    local plots = {}
    for i = 0, 54 do
        local x, y = .12 + (i % 9) * .092, .1 + math.floor(i / 9) * .12
        plots[#plots + 1] = { plotID = i, ownerType = i < 44 and 1 or 0,
            ownerName = i < 44 and "Neighbor " .. i or nil, plotCost = 10000000,
            mapPosition = { GetXY = function() return x, y end } }
    end
    C_HousingNeighborhood = {
        GetNeighborhoodMapData = function() return plots end, GetNeighborhoodName = function() return "Clear Sky Vineyard" end,
        IsNeighborhoodOwner = function() return false end, IsNeighborhoodManager = function() return true end,
    }
    C_HousingDecor = { GetNumDecorPlaced = function() return 75 end, GetDecorName = function() return "Vineyard bench" end,
        GetAllMaxPlacementBudgets = function() return { [1] = 200, [2] = 10 }, { [1] = 100 } end,
        GetAllSpentPlacementBudgets = function() return { [1] = 75, [2] = 2 }, { [1] = 37 } end }
    C_HousingLayout = { GetNumActiveRooms = function() return 6 end, GetSpentPlacementBudget = function() return 6 end,
        GetRoomPlacementBudget = function() return 12 end, GetLowestOccupiedFloorIndex = function() return -1 end,
        GetHighestOccupiedFloorIndex = function() return 1 end }
    C_HouseExterior = { GetCurrentHouseExteriorType = function() return 1, "Elven cottage" end,
        GetCurrentHouseExteriorSize = function() return 1 end }
    C_NeighborhoodInitiative = { GetNeighborhoodInitiativeInfo = function()
        return { isLoaded = true, neighborhoodGUID = "NEIGHBORHOOD", title = "A flourishing community", description = "Help your neighbors bring the vineyard to life.",
            currentProgress = 750, progressRequired = 1000, playerTotalContribution = 125, duration = 86400,
            milestones = { { milestoneOrderIndex = 1, requiredContributionAmount = 250, rewards = { { title = "Community reward", description = "A seat in the garden", decorID = 1, decorQuantity = 1 } } },
                { milestoneOrderIndex = 2, requiredContributionAmount = 1000, rewards = { { title = "House XP", favor = 100 } } } },
            tasks = { { taskName = "Gather supplies", description = "Collect supplies for the neighborhood", completed = true, inProgress = false, progressContributionAmount = 25, timesCompleted = 3, taskType = 1, tracked = false },
                { taskName = "Tend the vineyard", description = "Help a neighbor care for their garden", completed = false, inProgress = true, progressContributionAmount = 15, timesCompleted = 1, taskType = 0, tracked = true } } }
        end, GetAvailableHouseXP = function() return 250 end, GetRequiredLevel = function() return 20 end }
end

EH:Initialize(); SetupDashboardFixture(); EH:Show("neighborhood")
local neighborhood = EH.infoPages.neighborhood
neighborhood.scroll:SetSize(1240, 600); EH:RenderHousingInfo()
local plots = neighborhood.cards["Neighborhood plots"]
Check(#plots.markers == 55, "Every plot with native coordinates has a hover marker")
Check(math.abs(plots.bars[1].fraction - 44 / 55) < .0001, "Occupancy chart shows actual occupied/total ratio")
Check(neighborhood.cards["plot-directory"].rows[55]:IsShown(), "Complete plot directory remains available below the chart")
plots.markers[1].scripts.OnEnter(plots.markers[1])
Check(GameTooltip.tooltipLines[1]:find("Neighbor 0", 1, true), "Marker tooltip identifies its actual plot owner")
local count = #frames
for _ = 1, 10 do EH:RenderHousingInfo() end
Check(#frames == count, "Repeated housing notifications reuse the existing controls")
EH:Show("house")
local house = EH.infoPages.house
house.scroll:SetSize(1240, 600); EH:RenderHousingInfo()
Check(house.cards["House level and progress"].bars[1].fraction == .5, "House XP graph uses progress within the current level")
Check(house.cards["Interior budgets"].bars[1].fraction == .375, "Interior budget graph uses actual spent/max")
Check(house.cards["Exterior budgets"].bars[1].fraction == .37, "Exterior budget graph uses actual spent/max")
Check(house.cards["Room capacity"].bars[1].fraction == .5, "Room placement graph uses the native room budget")
local identifiers = house.cards.identifiers
Check(not house.showIdentifiers and identifiers.labelIndex == 1, "Identifiers start collapsed")
identifiers.toggle.scripts.OnClick(identifiers.toggle)
Check(house.showIdentifiers and identifiers.labelIndex == 7, "Identifiers expand without losing any ID fields")
identifiers.toggle.scripts.OnClick(identifiers.toggle)
Check(not house.showIdentifiers and identifiers.labelIndex == 1, "Identifiers collapse back to the compact card")
for _, font in ipairs({ 13, 20, 28 }) do
    ElvUI[1].db.general.fontSize = font; ElvUI[1]:UpdateFontTemplates()
    for _, width in ipairs({ 640, 820, 1240 }) do
        for _, view in ipairs({ "house", "neighborhood" }) do
            EH:SetView(view)
            local page = EH.infoPages[view]
            page.scroll:SetSize(width, 500); EH:RenderHousingInfo()
            local ordered = {}
            for _, card in pairs(page.cards) do
                if card:IsShown() then
                    local point = card.points[1]
                    local x, y = point[4], -point[5]
                    Check(x >= 0 and x + card:GetWidth() <= page.content:GetWidth() + .01, "Dashboard cards remain within the scroll width")
                    Check(y + card:GetHeight() <= page.content:GetHeight() + .01, "Every dashboard card is reachable by scrolling")
                    ordered[#ordered + 1] = { x = x, y = y, width = card:GetWidth(), height = card:GetHeight() }
                    for _, bar in ipairs(card.bars) do
                        if bar:IsShown() then
                            Check(ElvUI[1].statusBars[bar] and bar.state_SetStatusBarTexture[1] == ElvUI[1].media.normTex,
                                "Every dashboard graph uses native ElvUI texture registration")
                        end
                    end
                end
            end
            for i, a in ipairs(ordered) do
                for j = i + 1, #ordered do
                    local b = ordered[j]
                    Check(a.x + a.width <= b.x + .01 or b.x + b.width <= a.x + .01 or a.y + a.height <= b.y + .01
                        or b.y + b.height <= a.y + .01, "Summary tiles and cards do not overlap at this font/width")
                end
            end
        end
    end
end
EH:SetView("house")
local nativeSpent = C_HousingDecor.GetAllSpentPlacementBudgets
C_HousingDecor.GetAllSpentPlacementBudgets = function() return { [1] = 300 }, { [1] = 0 } end
EH:RenderHousingInfo()
local budget = house.cards["Interior budgets"].bars[1]
Check(budget.fraction == 1 and budget.text:GetText():find("150%%"), "Over-budget values clamp the fill while keeping the actual usage percentage")
Check(not house.cards["Interior budgets"].bars[2].known and house.cards["Interior budgets"].bars[2].text:GetText():find("Unknown", 1, true),
    "Unreported budget usage is not mistaken for empty capacity")
C_HousingDecor.GetAllSpentPlacementBudgets = nativeSpent
local bar = house.cards["House level and progress"].bars[1]
C_Housing.GetHouseLevelFavorForLevel = function() return nil end
EH:RenderHousingInfo()
Check(not bar.known and bar.fraction == 0 and bar.text:GetText():find("Unknown", 1, true), "Unknown XP has no fabricated progress percentage")
C_Housing.GetCurrentHouseInfo = function() return { houseGUID = "OTHER" } end
C_Housing.IsInsideOwnedHouseOrPlot = function() return false end
EH:RenderHousingInfo()
Check(not house.cards["Interior budgets"]:IsShown(), "Leaving the selected home hides its stale live budget charts")
EH:SetView("neighborhood")
C_Housing.GetCurrentNeighborhoodGUID = function() return nil end
EH:RenderHousingInfo()
Check(not neighborhood.cards["Neighborhood plots"]:IsShown() and not neighborhood.cards["plot-directory"]:IsShown(),
    "Leaving the neighborhood hides its stale plot chart and directory")
SetupDashboardFixture()
