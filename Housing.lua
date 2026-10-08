local _, EH = ...
EH.housing = { houses = {}, favor = {}, neighborhoods = {}, rosters = {}, rewards = {}, requests = {} }
EH.housingEvents = {}
for _, event in ipairs({ "PLAYER_HOUSE_LIST_UPDATED", "CURRENT_HOUSE_INFO_RECIEVED", "CURRENT_HOUSE_INFO_UPDATED",
    "HOUSE_INFO_UPDATED", "HOUSE_LEVEL_FAVOR_UPDATED", "HOUSE_LEVEL_CHANGED", "RECEIVED_HOUSE_LEVEL_REWARDS",
    "HOUSE_PLOT_ENTERED", "HOUSE_PLOT_EXITED", "NEIGHBORHOOD_INFO_UPDATED", "NEIGHBORHOOD_MAP_DATA_UPDATED",
    "NEIGHBORHOOD_NAME_UPDATED", "UPDATE_BULLETIN_BOARD_ROSTER", "UPDATE_BULLETIN_BOARD_ROSTER_STATUSES",
    "NEIGHBORHOOD_INITIATIVE_UPDATED", "INITIATIVE_TASK_COMPLETED", "INITIATIVE_COMPLETED",
    "HOUSING_NUM_DECOR_PLACED_CHANGED", "HOUSING_LAYOUT_ROOM_RECEIVED", "HOUSING_LAYOUT_ROOM_REMOVED",
    "HOUSING_LAYOUT_ROOM_RETURNED", "HOUSING_LAYOUT_OCCUPIED_FLOOR_RANGE_CHANGED",
    "HOUSING_CORE_FIXTURE_CHANGED", "HOUSING_SET_EXTERIOR_HOUSE_SIZE_RESPONSE", "HOUSING_SET_EXTERIOR_HOUSE_TYPE_RESPONSE" }) do
    EH.housingEvents[event] = true
    -- Missing client events cannot prevent the other public housing notifications from loading.
    pcall(EH.events.RegisterEvent, EH.events, event)
end

-- Accept only public finite numbers, preserving meaningful zero values.
local function Number(value)
    return EH:Readable(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- Accept only public records before reading fields from native API or event payloads.
local function Record(value)
    return EH:Readable(value) and type(value) == "table" and value or {}
end

-- Format public scalar values without retaining markup or displaying restricted data.
local function Text(value)
    if not EH:Readable(value) then return "Unknown" end
    if type(value) == "boolean" then return value and "Yes" or "No" end
    if Number(value) then return tostring(value) end
    if type(value) == "string" then
        local text = EH:Plain(value):gsub("|", "")
        if text ~= "" then return text end
    end
    return "Unknown"
end

-- Copy bounded public event data into session memory; housing information is never saved to disk.
local function Snapshot(value, depth)
    depth = depth or 0
    if not EH:Readable(value) then return nil end
    if type(value) ~= "table" then
        if Number(value) or type(value) == "boolean" or type(value) == "string" then return value end
        return nil
    end
    if depth >= 5 then return nil end
    local result, count = {}, 0
    for key, child in pairs(value) do
        if EH:Readable(key) and (type(key) == "string" or Number(key)) then
            result[key] = Snapshot(child, depth + 1)
            count = count + 1
            if count >= 1024 then break end
        end
    end
    return result
end

-- Resolve native enum values to readable names while preserving an unknown value honestly.
local function EnumName(kind, value)
    if not Number(value) then return "Unknown" end
    for name, id in pairs(Enum and Enum[kind] or {}) do
        if id == value then return name:gsub("(%l)(%u)", "%1 %2") end
    end
    return tostring(value)
end

-- Keep public values structured so cards, tables, and charts share the same native data.
local function Field(sections, label, value)
    local section = sections[#sections]
    section.fields[#section.fields + 1] = { label = label, value = Text(value) }
end

-- Describe one dashboard card without choosing fonts, colors, or screen geometry in the data layer.
local function Section(sections, title, kind, icon)
    local section = { title = title, kind = kind or "fields", icon = icon or "general", fields = {} }
    sections[#sections + 1] = section
    return section
end

-- Explain unavailable information in its own card rather than substituting fabricated values.
local function Message(sections, message)
    sections[#sections].message = message
end

-- Define an honest summary tile; unknown values stay distinct from numeric zero.
local function Stat(data, label, value, icon)
    data.stats[#data.stats + 1] = { label = label, value = Text(value), icon = icon }
end

-- Retain technical identifiers for an optional detail card instead of crowding the main overview.
local function Identifier(data, label, value)
    data.identifiers = data.identifiers or {}
    data.identifiers[#data.identifiers + 1] = { label = label, value = Text(value) }
end

-- Show native monetary values only when supplied; a missing price is not a free purchase.
local function Money(value)
    return Number(value) and EH:Call(GetMoneyString, value) or nil
end

-- Choose an owned house, preferring the player's current home without confusing a visited house with it.
function EH:SelectedHouse()
    local current = Record(self:Call(C_Housing and C_Housing.GetCurrentHouseInfo))
    for _, info in ipairs(self.housing.houses) do
        if info.houseGUID == self.selectedHouseGUID then return info end
    end
    if self:Call(C_Housing and C_Housing.IsInsideOwnedHouseOrPlot) then
        for _, info in ipairs(self.housing.houses) do
            if self:Readable(current.houseGUID) and info.houseGUID == current.houseGUID then return info end
        end
        if self:Readable(current.houseGUID) and type(current.houseGUID) == "string" then return current end
    end
    return self.housing.houses[1]
end

-- Offer each owned house through the standard native menu without changing Blizzard's tracked house.
function EH:HouseChoices()
    local choices = {}
    for _, info in ipairs(self.housing.houses) do
        if type(info.houseGUID) == "string" then
            choices[info.houseGUID] = Text(info.houseName or info.neighborhoodName) .. " - Plot " .. Text(info.plotID)
        end
    end
    return choices
end

-- Rate-limit documented data requests, and defer them during combat until the visible page can refresh.
function EH:RequestHousingData(key, fn, ...)
    if type(fn) ~= "function" then return end
    if InCombatLockdown() then self.housingDeferred = true; return end
    local now = GetTime()
    if self.housing.requests[key] and now - self.housing.requests[key] < 2 then return end
    self.housing.requests[key] = now
    self:Call(fn, ...)
end

-- Request selected-house progress and unlocks without repeating the owned-list request on its reply.
function EH:RequestHouseProgress(info, includeFavor)
    if not info or not self:Readable(info.houseGUID) or type(info.houseGUID) ~= "string" then return end
    if includeFavor then
        self:RequestHousingData("favor:" .. info.houseGUID, C_Housing and C_Housing.GetCurrentHouseLevelFavor, info.houseGUID)
    end
    local favor = Record(self.housing.favor[info.houseGUID])
    local maximum = self:Call(C_Housing and C_Housing.GetMaxHouseLevel)
    if Number(favor.houseLevel) and (not Number(maximum) or favor.houseLevel < maximum) then
        self:RequestHousingData("rewards:" .. favor.houseLevel, C_Housing and C_Housing.GetHouseLevelRewardsForLevel, favor.houseLevel + 1)
    end
end

-- Refresh only the visible housing page through public requests; no editor or ownership operation is performed.
function EH:RefreshHousingInfo()
    if not self.frame or not self.frame:IsShown() then return end
    if self.view == "house" then
        self:RequestHousingData("houses", C_Housing and C_Housing.GetPlayerOwnedHouses)
        self:RequestHouseProgress(self:SelectedHouse(), true)
    elseif self.view == "neighborhood" then
        local guid = self:Call(C_Housing and C_Housing.GetCurrentNeighborhoodGUID)
        if type(guid) == "string" and guid ~= "" then
            self:RequestHousingData("neighborhood:" .. guid, C_HousingNeighborhood and C_HousingNeighborhood.RequestNeighborhoodInfo)
            local active = self:Call(C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetActiveNeighborhood)
            if active == guid then
                self:RequestHousingData("endeavor:" .. guid, C_NeighborhoodInitiative and C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo)
            end
        end
    else return end
    self:RenderHousingInfo()
end

-- Keep asynchronous replies keyed by their actual house or neighborhood, then update existing controls.
function EH:HousingEvent(event, ...)
    local first, second = ...
    if event == "PLAYER_HOUSE_LIST_UPDATED" then
        local houses = {}
        for _, info in ipairs(Record(first)) do
            info = Record(Snapshot(info))
            if type(info.houseGUID) == "string" and info.houseGUID ~= "" then houses[#houses + 1] = info end
        end
        self.housing.houses, self.housing.housesLoaded = houses, true
    elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" then
        local info = Record(Snapshot(first))
        if type(info.houseGUID) == "string" then self.housing.favor[info.houseGUID] = info end
    elseif event == "CURRENT_HOUSE_INFO_UPDATED" or event == "CURRENT_HOUSE_INFO_RECIEVED" then
        local info = Record(Snapshot(first))
        for index, house in ipairs(self.housing.houses) do
            if house.houseGUID == info.houseGUID then self.housing.houses[index] = info; break end
        end
    elseif event == "NEIGHBORHOOD_INFO_UPDATED" or event == "UPDATE_BULLETIN_BOARD_ROSTER" then
        local info = Record(Snapshot(first))
        if type(info.neighborhoodGUID) == "string" then
            self.housing.neighborhoods[info.neighborhoodGUID] = info
            if event == "UPDATE_BULLETIN_BOARD_ROSTER" then self.housing.rosters[info.neighborhoodGUID] = Snapshot(second) end
        end
    elseif event == "UPDATE_BULLETIN_BOARD_ROSTER_STATUSES" then
        local guid = self:Call(C_Housing and C_Housing.GetCurrentNeighborhoodGUID)
        local roster = guid and self.housing.rosters[guid]
        for _, update in ipairs(Record(Snapshot(first))) do
            for _, resident in ipairs(Record(roster)) do
                if resident.playerGUID == update.playerGUID then
                    resident.isOnline, resident.residentType = update.isOnline, update.residentType
                end
            end
        end
    elseif event == "RECEIVED_HOUSE_LEVEL_REWARDS" and Number(first) then
        self.housing.rewards[first] = Snapshot(second)
    elseif event == "NEIGHBORHOOD_NAME_UPDATED" and self:Readable(first) and self:Readable(second)
        and type(first) == "string" and type(second) == "string" then
        local info = self.housing.neighborhoods[first]
        if info then info.neighborhoodName = second end
    end
    if self.frame and self.frame:IsShown() and (self.view == "house" or self.view == "neighborhood") then
        if self.view == "house" and (event == "PLAYER_HOUSE_LIST_UPDATED" or event == "HOUSE_LEVEL_FAVOR_UPDATED") then
            self:RequestHouseProgress(self:SelectedHouse(), event == "PLAYER_HOUSE_LIST_UPDATED")
        elseif event == "HOUSE_LEVEL_CHANGED" or event == "HOUSE_PLOT_ENTERED" or event == "HOUSE_PLOT_EXITED"
            or event == "HOUSE_INFO_UPDATED" or event == "CURRENT_HOUSE_INFO_RECIEVED" or event == "CURRENT_HOUSE_INFO_UPDATED" then
            self:RefreshHousingInfo(); return
        end
        self:RenderHousingInfo()
    end
end

-- Present identity, available plot ownership, and the currently received resident roster.
function EH:NeighborhoodData()
    local sections, api = {}, C_HousingNeighborhood or {}
    local data = { kind = "neighborhood", title = "Neighborhood", icon = "housing", sections = sections, stats = {} }
    local guid = self:Call(C_Housing and C_Housing.GetCurrentNeighborhoodGUID)
    if type(guid) ~= "string" or guid == "" then
        Section(sections, "Explore your neighborhood", nil, "housing")
        Message(sections, "Enter a neighborhood to see its information.")
        return data
    end
    local info = Record(self.housing.neighborhoods[guid])
    local mapID = self:Call(C_Housing and C_Housing.GetUIMapIDForNeighborhood, guid)
    local map = Record(self:Call(C_Map and C_Map.GetMapInfo, mapID))
    data.title = Text(info.neighborhoodName or self:Call(api.GetNeighborhoodName))
    data.subtitle = Text(info.locationName or map.name)
    Section(sections, "Current neighborhood")
    Field(sections, "Name", info.neighborhoodName or self:Call(api.GetNeighborhoodName))
    Field(sections, "Location", info.locationName or map.name)
    Field(sections, "Type", EnumName("NeighborhoodType", info.neighborhoodType))
    Field(sections, "Owner type", EnumName("NeighborhoodOwnerType", info.neighborhoodOwnerType))
    Field(sections, "Owner", info.ownerName)
    Identifier(data, "Owner ID", info.ownerGUID)
    Field(sections, "You are the owner", self:Call(api.IsNeighborhoodOwner))
    Field(sections, "You are a manager", self:Call(api.IsNeighborhoodManager))
    Field(sections, "Faction matches", self:Call(C_Housing and C_Housing.DoesFactionMatchNeighborhood, guid))
    Identifier(data, "Neighborhood ID", guid)
    Identifier(data, "Map ID", mapID)
    local plots, seen, occupied, vacant, unknown = {}, {}, 0, 0, 0
    local vacantType = Enum.HousingPlotOwnerType and Enum.HousingPlotOwnerType.None or 0
    for _, plot in pairs(Record(self:Call(api.GetNeighborhoodMapData))) do
        plot = Record(plot)
        if Number(plot.plotID) and not seen[plot.plotID] then
            seen[plot.plotID], plots[#plots + 1] = true, plot
            if not Number(plot.ownerType) then unknown = unknown + 1
            elseif plot.ownerType == vacantType then vacant = vacant + 1
            else occupied = occupied + 1 end
        end
    end
    table.sort(plots, function(a, b) return a.plotID < b.plotID end)
    local plotCard = Section(sections, "Neighborhood plots", "plots", "housing")
    plotCard.plots, plotCard.rows = {}, {}
    plotCard.columns = { "Plot", "Owner", "Status", "Price", "Coordinates" }
    plotCard.counts = { occupied = occupied, vacant = vacant, unknown = unknown, total = #plots }
    Stat(data, "Known plots", #plots > 0 and #plots or nil, "housing")
    Stat(data, "Occupied", #plots > 0 and occupied or nil, "collection")
    Stat(data, "Unowned", #plots > 0 and vacant or nil, "shop")
    if #plots == 0 then Message(sections, "Plot details are not available yet.")
    else
        Field(sections, "Known plots", #plots); Field(sections, "Occupied", occupied); Field(sections, "Unowned", vacant)
        if unknown > 0 then Field(sections, "Ownership unknown", unknown) end
        for _, plot in ipairs(plots) do
            local point = { id = plot.plotID, owner = Text(plot.ownerName),
                status = not Number(plot.ownerType) and "unknown" or (plot.ownerType == vacantType and "vacant" or "occupied") }
            local detail = Text(plot.ownerName) .. " (" .. EnumName("HousingPlotOwnerType", plot.ownerType) .. ")"
            if Number(plot.plotCost) then detail = detail .. " - " .. Text(Money(plot.plotCost)) end
            local position = plot.mapPosition
            if self:Readable(position) and (type(position) == "table" or type(position) == "userdata") and type(position.GetXY) == "function" then
                local x, y = self:Call(position.GetXY, position)
                if Number(x) and Number(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    point.x, point.y = x, y
                    detail = detail .. string.format(" - %.1f, %.1f", x * 100, y * 100)
                end
            end
            point.tooltip = "Plot " .. plot.plotID .. ": " .. detail
            plotCard.plots[#plotCard.plots + 1] = point
            plotCard.rows[#plotCard.rows + 1] = { cells = { Text(plot.plotID), Text(plot.ownerName),
                point.status == "vacant" and "Unowned" or EnumName("HousingPlotOwnerType", plot.ownerType), Text(Money(plot.plotCost)),
                point.x and string.format("%.1f, %.1f", point.x * 100, point.y * 100) or "Unknown" }, tooltip = point.tooltip }
            Field(sections, "Plot " .. plot.plotID, detail)
        end
    end
    local residentCard = Section(sections, "Residents", "table", "heart")
    residentCard.columns, residentCard.rows = { "Resident", "Plot", "Role", "Online" }, {}
    local roster = self.housing.rosters[guid]
    if type(roster) ~= "table" then Message(sections, "Visit the neighborhood bulletin board to load resident details.")
    else
        Field(sections, "Residents in the last received roster", #roster)
        for _, resident in ipairs(roster) do
            residentCard.rows[#residentCard.rows + 1] = { cells = { Text(resident.residentName), Text(resident.plotID),
                EnumName("ResidentType", resident.residentType), Text(resident.isOnline) }, tooltip = Text(resident.residentName)
                .. "\nPlot: " .. Text(resident.plotID) .. "\nRole: " .. EnumName("ResidentType", resident.residentType)
                .. "\nOnline: " .. Text(resident.isOnline) .. (Number(resident.subdivision) and "\nSubdivision: " .. Text(resident.subdivision) or "") }
            Field(sections, Text(resident.residentName), "Plot " .. Text(resident.plotID) .. " - "
                .. EnumName("ResidentType", resident.residentType) .. " - Online: " .. Text(resident.isOnline))
            if Number(resident.subdivision) then Field(sections, "Subdivision", resident.subdivision) end
        end
    end
    Stat(data, "Residents", type(roster) == "table" and #roster or nil, "heart")
    self:AddEndeavorData(sections, guid)
    return data
end

-- Render only the endeavor associated with the current neighborhood, without changing native selection.
function EH:AddEndeavorData(sections, guid)
    local card = Section(sections, "Neighborhood endeavor", "progress", "achievement")
    local api = C_NeighborhoodInitiative or {}
    local info = Record(self:Call(api.GetNeighborhoodInitiativeInfo))
    if not self:Readable(info.neighborhoodGUID) or info.neighborhoodGUID ~= guid
        or not self:Readable(info.isLoaded) or info.isLoaded ~= true then
        Message(sections, "Endeavor details are not available for this neighborhood yet.")
        return
    end
    card.progress = { label = "Community progress", current = info.currentProgress, maximum = info.progressRequired }
    Field(sections, "Title", info.title); Field(sections, "Description", info.description)
    Field(sections, "Progress", Text(info.currentProgress) .. " / " .. Text(info.progressRequired))
    Field(sections, "Your contribution", info.playerTotalContribution)
    Field(sections, "Duration (seconds)", info.duration)
    Field(sections, "House XP available", self:Call(api.GetAvailableHouseXP))
    Field(sections, "Required player level", self:Call(api.GetRequiredLevel))
    local milestones = Section(sections, "Milestone rewards", "milestones", "achievement")
    milestones.milestones = {}
    for _, milestone in ipairs(Record(info.milestones)) do
        milestone = Record(milestone)
        milestones.milestones[#milestones.milestones + 1] = { label = "Milestone " .. Text(milestone.milestoneOrderIndex),
            current = info.currentProgress, maximum = milestone.requiredContributionAmount,
            complete = Number(info.currentProgress) and Number(milestone.requiredContributionAmount) and info.currentProgress >= milestone.requiredContributionAmount,
            completeText = "Goal reached" }
        Field(sections, "Milestone " .. Text(milestone.milestoneOrderIndex), milestone.requiredContributionAmount)
        for _, reward in ipairs(Record(milestone.rewards)) do
            reward = Record(reward)
            Field(sections, "Reward", reward.title); Field(sections, "Reward description", reward.description)
            if Number(reward.decorID) and reward.decorID > 0 then
                Field(sections, "Decor reward", Text(self:Call(C_HousingDecor and C_HousingDecor.GetDecorName, reward.decorID)) .. " x " .. Text(reward.decorQuantity))
            end
            if Number(reward.favor) and reward.favor > 0 then Field(sections, "House XP reward", reward.favor) end
            if Number(reward.money) and reward.money > 0 then Field(sections, "Money reward", Money(reward.money)) end
        end
    end
    local tasks = Section(sections, "Endeavor tasks", "table", "quest")
    tasks.columns, tasks.rows = { "Task", "Status", "Contribution", "Times completed" }, {}
    for _, task in ipairs(Record(info.tasks)) do
        task = Record(task)
        local details = #tasks.fields + 1
        Field(sections, "Task", task.taskName); Field(sections, "Description", task.description)
        Field(sections, "Contribution", task.progressContributionAmount); Field(sections, "Times completed", task.timesCompleted)
        Field(sections, "Completed", task.completed); Field(sections, "In progress", task.inProgress)
        Field(sections, "Task type", EnumName("NeighborhoodInitiativeTaskType", task.taskType))
        Field(sections, "Tracked", task.tracked)
        for _, requirement in ipairs(Record(task.requirementsList)) do Field(sections, "Requirement", EnumName("CriteriaRequirement", requirement)) end
        local tooltip = {}
        for i = details, #tasks.fields do tooltip[#tooltip + 1] = tasks.fields[i].label .. ": " .. tasks.fields[i].value end
        local status = "Unknown"
        if self:Readable(task.completed) and self:Readable(task.inProgress)
            and type(task.completed) == "boolean" and type(task.inProgress) == "boolean" then
            status = task.completed and "Complete" or (task.inProgress and "In progress" or "Available")
        end
        tasks.rows[#tasks.rows + 1] = { cells = { Text(task.taskName), status,
            Text(task.progressContributionAmount), Text(task.timesCompleted) }, tooltip = table.concat(tooltip, "\n") }
    end
end

-- Display all native budget types as spent/max pairs, without assuming missing data means zero.
local function Budgets(sections, title, spent, maximum)
    local card = Section(sections, title, "budgets", "collection")
    card.meters = {}
    local keys = {}
    for kind in pairs(Record(maximum)) do if Number(kind) then keys[#keys + 1] = kind end end
    table.sort(keys)
    if #keys == 0 then Message(sections, "Budget information is not available yet.") end
    for _, kind in ipairs(keys) do
        card.meters[#card.meters + 1] = { label = EnumName("HousingBudgetType", kind), current = Record(spent)[kind], maximum = maximum[kind] }
        Field(sections, EnumName("HousingBudgetType", kind), Text(Record(spent)[kind]) .. " / " .. Text(maximum[kind]))
    end
end

-- Describe Blizzard's visitor and blueprint permissions using its own enum and flag helper.
local function Access(flags, prefix)
    if not Number(flags) or not FlagsUtil or type(FlagsUtil.IsSet) ~= "function" then return nil end
    local masks = Enum.HouseSettingFlags or {}
    local anyone = masks[prefix .. "Anyone"]
    if not Number(anyone) then return nil end
    if EH:Call(FlagsUtil.IsSet, flags, anyone) == true then return HOUSING_HOUSE_SETTINGS_ANYONE or "Anyone" end
    local groups = {}
    for _, name in ipairs({ "Neighbors", "Guild", "Friends", "Party" }) do
        local mask = masks[prefix .. name]
        if not Number(mask) then return nil end
        local allowed = EH:Call(FlagsUtil.IsSet, flags, mask)
        if allowed == nil then return nil end
        if allowed then groups[#groups + 1] = HousingAccessTypeStrings and HousingAccessTypeStrings[mask] or name end
    end
    return #groups > 0 and table.concat(groups, ", ") or (HOUSING_HOUSE_SETTINGS_NOONE or "No one")
end

-- Show the selected owned house, and scope live layout/decor data to that exact home.
function EH:HouseData()
    local sections, api = {}, C_Housing or {}
    local data = { kind = "house", title = "Your house", icon = "housing", sections = sections, stats = {} }
    local info = self:SelectedHouse()
    if not info then
        Section(sections, "Your home", nil, "housing")
        Message(sections, self.housing.housesLoaded and "No owned houses were reported for your account." or "Loading your owned houses...")
        return data
    end
    data.title = Text(info.houseName)
    data.subtitle = Text(info.neighborhoodName) .. "  /  Plot " .. Text(info.plotID)
    Section(sections, "Your house")
    Field(sections, "Name", info.houseName); Field(sections, "Owner", info.ownerName)
    Field(sections, "Neighborhood", info.neighborhoodName); Field(sections, "Plot", info.plotID)
    Field(sections, "Plot cost", Money(info.plotCost)); Field(sections, "Plot reserved", info.plotReserved)
    if Number(info.moveOutTime) and info.moveOutTime > 0 then Field(sections, "Move-out time", self:Call(date, "%Y-%m-%d %H:%M", info.moveOutTime)) end
    Identifier(data, "House ID", info.houseGUID); Identifier(data, "Neighborhood ID", info.neighborhoodGUID)
    if type(info.neighborhoodGUID) == "string" then Identifier(data, "Map ID", self:Call(api.GetUIMapIDForNeighborhood, info.neighborhoodGUID)) end
    local progress = Section(sections, "House level and progress", "progress", "achievement")
    local favor = Record(self.housing.favor[info.houseGUID])
    Field(sections, "House level", favor.houseLevel)
    Field(sections, "House XP", favor.houseFavor)
    local maximum = self:Call(api.GetMaxHouseLevel)
    local atMaximum = Number(maximum) and Number(favor.houseLevel) and favor.houseLevel >= maximum
    local required = not atMaximum and Number(favor.houseLevel) and self:Call(api.GetHouseLevelFavorForLevel, favor.houseLevel + 1) or nil
    Field(sections, "Maximum house level", maximum)
    local baseline = Number(favor.houseLevel) and self:Call(api.GetHouseLevelFavorForLevel, favor.houseLevel) or nil
    if Number(favor.houseLevel) and favor.houseLevel == 0 then baseline = 0 end
    progress.progress = { label = "Progress to next level", current = Number(baseline) and Number(favor.houseFavor) and favor.houseFavor - baseline or nil,
        maximum = Number(baseline) and Number(required) and required - baseline or nil, complete = atMaximum, completeText = "Maximum level" }
    Stat(data, "House level", favor.houseLevel, "achievement")
    Stat(data, "XP still needed", Number(required) and Number(favor.houseFavor) and math.max(0, required - favor.houseFavor) or (atMaximum and 0 or nil), "quest")
    if atMaximum then Message(sections, "Maximum house level reached.")
    else Field(sections, "XP required for the next level", required) end
    if Number(required) and Number(favor.houseFavor) then Field(sections, "XP still needed", math.max(0, required - favor.houseFavor)) end
    if not atMaximum and Number(favor.houseLevel) then
        Section(sections, "Next level unlocks", nil, "book")
        for _, reward in ipairs(Record(self.housing.rewards[favor.houseLevel + 1])) do
            reward = Record(reward)
            local name = reward.objectName or reward.tooltipText or EnumName("HouseLevelRewardValueType", reward.valueType)
            if Number(reward.newValue) then name = Text(name) .. " - " .. Text(reward.oldValue) .. " -> " .. Text(reward.newValue) end
            Field(sections, "Next level reward", name)
        end
        if #sections[#sections].fields == 0 then Message(sections, "Unlock details are not available yet.") end
    end
    local current = Record(self:Call(api.GetCurrentHouseInfo))
    if not self:Readable(current.houseGUID) or current.houseGUID ~= info.houseGUID or self:Call(api.IsInsideOwnedHouseOrPlot) ~= true then
        Section(sections, "Live house details")
        Message(sections, "Enter this house or its plot to see current decor, room, exterior, and budget details.")
        Stat(data, "Placed decor", nil, "collection"); Stat(data, "Rooms", nil, "housing")
        return data
    end
    Section(sections, "Live house details")
    Field(sections, "Inside your house", self:Call(api.IsInsideOwnedHouse))
    Field(sections, "On your plot", self:Call(api.IsInsideOwnedPlot))
    local decor = self:Call(C_HousingDecor and C_HousingDecor.GetNumDecorPlaced)
    local rooms = self:Call(C_HousingLayout and C_HousingLayout.GetNumActiveRooms)
    Field(sections, "Placed decor in the current area", decor); Field(sections, "Active rooms", rooms)
    Stat(data, "Placed decor", decor, "collection"); Stat(data, "Rooms", rooms, "housing")
    Field(sections, "Lowest occupied floor", self:Call(C_HousingLayout and C_HousingLayout.GetLowestOccupiedFloorIndex))
    Field(sections, "Highest occupied floor", self:Call(C_HousingLayout and C_HousingLayout.GetHighestOccupiedFloorIndex))
    local _, exteriorName = self:Call(C_HouseExterior and C_HouseExterior.GetCurrentHouseExteriorType)
    Field(sections, "Exterior style", exteriorName)
    Field(sections, "Exterior size", EnumName("HousingFixtureSize", self:Call(C_HouseExterior and C_HouseExterior.GetCurrentHouseExteriorSize)))
    Field(sections, "Refund amount", Money(self:Call(api.GetCurrentHouseRefundAmount)))
    Section(sections, "Visitors and sharing", nil, "heart")
    local access = self:Call(api.GetHousingAccessFlags)
    Field(sections, "House visitors", Access(access, "HouseAccess"))
    Field(sections, "Plot visitors", Access(access, "PlotAccess"))
    Field(sections, "Blueprint export permission", Access(access, "BlueprintExport"))
    local interiorMax, exteriorMax = self:Call(C_HousingDecor and C_HousingDecor.GetAllMaxPlacementBudgets)
    local interiorSpent, exteriorSpent = self:Call(C_HousingDecor and C_HousingDecor.GetAllSpentPlacementBudgets)
    Budgets(sections, "Interior budgets", interiorSpent, interiorMax); Budgets(sections, "Exterior budgets", exteriorSpent, exteriorMax)
    local spent = self:Call(C_HousingLayout and C_HousingLayout.GetSpentPlacementBudget)
    local limit = self:Call(C_HousingLayout and C_HousingLayout.GetRoomPlacementBudget)
    local roomCard = Section(sections, "Room capacity", "budgets", "housing")
    roomCard.meters = { { label = "Room placement budget", current = spent, maximum = limit } }
    Field(sections, "Room placement budget", Text(spent) .. " / " .. Text(limit))
    return data
end
