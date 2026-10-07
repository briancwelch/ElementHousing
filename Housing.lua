local _, EH = ...
local E = ElvUI and ElvUI[1]
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

-- Add one readable field to the current information section.
local function Field(lines, label, value)
    lines[#lines + 1] = label .. ": " .. Text(value)
end

-- Use the user's native ElvUI value color for section headings.
local function Section(lines, title)
    local color = E.media.rgbvaluecolor
    local hex = string.format("%02x%02x%02x", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
    lines[#lines + 1] = (#lines > 0 and "\n" or "") .. "|cff" .. hex .. title .. "|r"
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
function EH:NeighborhoodLines()
    local lines, api = {}, C_HousingNeighborhood or {}
    local guid = self:Call(C_Housing and C_Housing.GetCurrentNeighborhoodGUID)
    if type(guid) ~= "string" or guid == "" then return { "Enter a neighborhood to see its information." } end
    local info = Record(self.housing.neighborhoods[guid])
    local mapID = self:Call(C_Housing and C_Housing.GetUIMapIDForNeighborhood, guid)
    local map = Record(self:Call(C_Map and C_Map.GetMapInfo, mapID))
    Section(lines, "Current neighborhood")
    Field(lines, "Name", info.neighborhoodName or self:Call(api.GetNeighborhoodName))
    Field(lines, "Location", info.locationName or map.name)
    Field(lines, "Type", EnumName("NeighborhoodType", info.neighborhoodType))
    Field(lines, "Owner type", EnumName("NeighborhoodOwnerType", info.neighborhoodOwnerType))
    Field(lines, "Owner", info.ownerName)
    Field(lines, "Owner ID", info.ownerGUID)
    Field(lines, "You are the owner", self:Call(api.IsNeighborhoodOwner))
    Field(lines, "You are a manager", self:Call(api.IsNeighborhoodManager))
    Field(lines, "Faction matches", self:Call(C_Housing and C_Housing.DoesFactionMatchNeighborhood, guid))
    Field(lines, "Neighborhood ID", guid)
    Field(lines, "Map ID", mapID)
    local plots, seen, occupied, vacant, unknown = {}, {}, 0, 0, 0
    for _, plot in pairs(Record(self:Call(api.GetNeighborhoodMapData))) do
        plot = Record(plot)
        if Number(plot.plotID) and not seen[plot.plotID] then
            seen[plot.plotID], plots[#plots + 1] = true, plot
            if not Number(plot.ownerType) then unknown = unknown + 1
            elseif plot.ownerType == (Enum.HousingPlotOwnerType and Enum.HousingPlotOwnerType.None or 0) then vacant = vacant + 1
            else occupied = occupied + 1 end
        end
    end
    table.sort(plots, function(a, b) return a.plotID < b.plotID end)
    Section(lines, "Plots")
    if #plots == 0 then lines[#lines + 1] = "Plot details are not available yet."
    else
        Field(lines, "Known plots", #plots); Field(lines, "Occupied", occupied); Field(lines, "Unowned", vacant)
        if unknown > 0 then Field(lines, "Ownership unknown", unknown) end
        for _, plot in ipairs(plots) do
            local detail = Text(plot.ownerName) .. " (" .. EnumName("HousingPlotOwnerType", plot.ownerType) .. ")"
            if Number(plot.plotCost) then detail = detail .. " - " .. Text(Money(plot.plotCost)) end
            local position = plot.mapPosition
            if self:Readable(position) and (type(position) == "table" or type(position) == "userdata") and type(position.GetXY) == "function" then
                local x, y = self:Call(position.GetXY, position)
                if Number(x) and Number(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    detail = detail .. string.format(" - %.1f, %.1f", x * 100, y * 100)
                end
            end
            Field(lines, "Plot " .. plot.plotID, detail)
        end
    end
    Section(lines, "Residents")
    local roster = self.housing.rosters[guid]
    if type(roster) ~= "table" then lines[#lines + 1] = "Visit the neighborhood bulletin board to load resident details."
    else
        Field(lines, "Residents in the last received roster", #roster)
        for _, resident in ipairs(roster) do
            Field(lines, Text(resident.residentName), "Plot " .. Text(resident.plotID) .. " - "
                .. EnumName("ResidentType", resident.residentType) .. " - Online: " .. Text(resident.isOnline))
            if Number(resident.subdivision) then Field(lines, "Subdivision", resident.subdivision) end
        end
    end
    self:EndeavorLines(lines, guid)
    return lines
end

-- Render only the endeavor associated with the current neighborhood, without changing native selection.
function EH:EndeavorLines(lines, guid)
    Section(lines, "Neighborhood endeavor")
    local api = C_NeighborhoodInitiative or {}
    local info = Record(self:Call(api.GetNeighborhoodInitiativeInfo))
    if not self:Readable(info.neighborhoodGUID) or info.neighborhoodGUID ~= guid
        or not self:Readable(info.isLoaded) or info.isLoaded ~= true then
        lines[#lines + 1] = "Endeavor details are not available for this neighborhood yet."
        return
    end
    Field(lines, "Title", info.title); Field(lines, "Description", info.description)
    Field(lines, "Progress", Text(info.currentProgress) .. " / " .. Text(info.progressRequired))
    Field(lines, "Your contribution", info.playerTotalContribution)
    Field(lines, "Duration (seconds)", info.duration)
    Field(lines, "House XP available", self:Call(api.GetAvailableHouseXP))
    Field(lines, "Required player level", self:Call(api.GetRequiredLevel))
    for _, milestone in ipairs(Record(info.milestones)) do
        milestone = Record(milestone)
        Field(lines, "Milestone " .. Text(milestone.milestoneOrderIndex), milestone.requiredContributionAmount)
        for _, reward in ipairs(Record(milestone.rewards)) do
            reward = Record(reward)
            Field(lines, "Reward", reward.title); Field(lines, "Reward description", reward.description)
            if Number(reward.decorID) and reward.decorID > 0 then
                Field(lines, "Decor reward", Text(self:Call(C_HousingDecor and C_HousingDecor.GetDecorName, reward.decorID)) .. " x " .. Text(reward.decorQuantity))
            end
            if Number(reward.favor) and reward.favor > 0 then Field(lines, "House XP reward", reward.favor) end
            if Number(reward.money) and reward.money > 0 then Field(lines, "Money reward", Money(reward.money)) end
        end
    end
    Section(lines, "Endeavor tasks")
    for _, task in ipairs(Record(info.tasks)) do
        task = Record(task)
        Field(lines, "Task", task.taskName); Field(lines, "Description", task.description)
        Field(lines, "Contribution", task.progressContributionAmount); Field(lines, "Times completed", task.timesCompleted)
        Field(lines, "Completed", task.completed); Field(lines, "In progress", task.inProgress)
        Field(lines, "Task type", EnumName("NeighborhoodInitiativeTaskType", task.taskType))
        Field(lines, "Tracked", task.tracked)
        for _, requirement in ipairs(Record(task.requirementsList)) do Field(lines, "Requirement", EnumName("CriteriaRequirement", requirement)) end
    end
end

-- Display all native budget types as spent/max pairs, without assuming missing data means zero.
local function Budgets(lines, title, spent, maximum)
    Section(lines, title)
    local keys = {}
    for kind in pairs(Record(maximum)) do if Number(kind) then keys[#keys + 1] = kind end end
    table.sort(keys)
    if #keys == 0 then lines[#lines + 1] = "Budget information is not available yet." end
    for _, kind in ipairs(keys) do
        Field(lines, EnumName("HousingBudgetType", kind), Text(Record(spent)[kind]) .. " / " .. Text(maximum[kind]))
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
function EH:HouseLines()
    local lines, api = {}, C_Housing or {}
    local info = self:SelectedHouse()
    if not info then return { self.housing.housesLoaded and "No owned houses were reported for your account." or "Loading your owned houses..." } end
    Section(lines, "Your house")
    Field(lines, "Name", info.houseName); Field(lines, "Owner", info.ownerName)
    Field(lines, "Neighborhood", info.neighborhoodName); Field(lines, "Plot", info.plotID)
    Field(lines, "Plot cost", Money(info.plotCost)); Field(lines, "Plot reserved", info.plotReserved)
    if Number(info.moveOutTime) and info.moveOutTime > 0 then Field(lines, "Move-out time", self:Call(date, "%Y-%m-%d %H:%M", info.moveOutTime)) end
    Field(lines, "House ID", info.houseGUID); Field(lines, "Neighborhood ID", info.neighborhoodGUID)
    if type(info.neighborhoodGUID) == "string" then Field(lines, "Map ID", self:Call(api.GetUIMapIDForNeighborhood, info.neighborhoodGUID)) end
    Section(lines, "House level and progress")
    local favor = Record(self.housing.favor[info.houseGUID])
    Field(lines, "House level", favor.houseLevel)
    Field(lines, "House XP", favor.houseFavor)
    local maximum = self:Call(api.GetMaxHouseLevel)
    local atMaximum = Number(maximum) and Number(favor.houseLevel) and favor.houseLevel >= maximum
    local required = not atMaximum and Number(favor.houseLevel) and self:Call(api.GetHouseLevelFavorForLevel, favor.houseLevel + 1) or nil
    Field(lines, "Maximum house level", maximum)
    if atMaximum then lines[#lines + 1] = "Maximum house level reached."
    else Field(lines, "XP required for the next level", required) end
    if Number(required) and Number(favor.houseFavor) then Field(lines, "XP still needed", math.max(0, required - favor.houseFavor)) end
    if not atMaximum and Number(favor.houseLevel) then
        for _, reward in ipairs(Record(self.housing.rewards[favor.houseLevel + 1])) do
            reward = Record(reward)
            local name = reward.objectName or reward.tooltipText or EnumName("HouseLevelRewardValueType", reward.valueType)
            if Number(reward.newValue) then name = Text(name) .. " - " .. Text(reward.oldValue) .. " -> " .. Text(reward.newValue) end
            Field(lines, "Next level reward", name)
        end
    end
    local current = Record(self:Call(api.GetCurrentHouseInfo))
    if not self:Readable(current.houseGUID) or current.houseGUID ~= info.houseGUID or self:Call(api.IsInsideOwnedHouseOrPlot) ~= true then
        Section(lines, "Live house details")
        lines[#lines + 1] = "Enter this house or its plot to see current decor, room, exterior, and budget details."
        return lines
    end
    Section(lines, "Live house details")
    Field(lines, "Inside your house", self:Call(api.IsInsideOwnedHouse))
    Field(lines, "On your plot", self:Call(api.IsInsideOwnedPlot))
    Field(lines, "Placed decor in the current area", self:Call(C_HousingDecor and C_HousingDecor.GetNumDecorPlaced))
    Field(lines, "Active rooms", self:Call(C_HousingLayout and C_HousingLayout.GetNumActiveRooms))
    Field(lines, "Lowest occupied floor", self:Call(C_HousingLayout and C_HousingLayout.GetLowestOccupiedFloorIndex))
    Field(lines, "Highest occupied floor", self:Call(C_HousingLayout and C_HousingLayout.GetHighestOccupiedFloorIndex))
    local _, exteriorName = self:Call(C_HouseExterior and C_HouseExterior.GetCurrentHouseExteriorType)
    Field(lines, "Exterior style", exteriorName)
    Field(lines, "Exterior size", EnumName("HousingFixtureSize", self:Call(C_HouseExterior and C_HouseExterior.GetCurrentHouseExteriorSize)))
    Field(lines, "Refund amount", Money(self:Call(api.GetCurrentHouseRefundAmount)))
    local access = self:Call(api.GetHousingAccessFlags)
    Field(lines, "House visitors", Access(access, "HouseAccess"))
    Field(lines, "Plot visitors", Access(access, "PlotAccess"))
    Field(lines, "Blueprint export permission", Access(access, "BlueprintExport"))
    local interiorMax, exteriorMax = self:Call(C_HousingDecor and C_HousingDecor.GetAllMaxPlacementBudgets)
    local interiorSpent, exteriorSpent = self:Call(C_HousingDecor and C_HousingDecor.GetAllSpentPlacementBudgets)
    Budgets(lines, "Interior budgets", interiorSpent, interiorMax); Budgets(lines, "Exterior budgets", exteriorSpent, exteriorMax)
    Field(lines, "Room placement budget", Text(self:Call(C_HousingLayout and C_HousingLayout.GetSpentPlacementBudget)) .. " / "
        .. Text(self:Call(C_HousingLayout and C_HousingLayout.GetRoomPlacementBudget)))
    return lines
end

-- Create two native ElvUI-styled scrolling pages with a local owned-house selector.
function EH:CreateHousingPanels()
    self.infoPages = {}
    for _, key in ipairs({ "neighborhood", "house" }) do
        local panel = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        panel:Hide(); self:Skin(panel, true)
        panel:SetPoint("TOPLEFT", 12, -82); panel:SetPoint("BOTTOMRIGHT", -12, 38)
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, key == "house" and -50 or -12); scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        local content = CreateFrame("Frame", nil, scroll); content:SetSize(600, 1); scroll:SetScrollChild(content)
        local text = self:Label(content, ""); text:SetPoint("TOPLEFT"); text:SetJustifyH("LEFT"); text:SetWordWrap(true)
        self.infoPages[key] = { panel = panel, scroll = scroll, content = content, text = text }
        -- Scroll width and text height follow native font and window geometry changes.
        scroll:HookScript("OnSizeChanged", function() self:RenderHousingInfo() end)
    end
    self.houseSelector = self:Button(self.infoPages.house.panel, "Choose house", 320, function(button)
        self:ChoiceMenu(button, self:HouseChoices(), function() local info = self:SelectedHouse(); return info and info.houseGUID end,
            function(guid) self.selectedHouseGUID = guid; self:RefreshHousingInfo() end)
    end, "housing")
    self.houseSelector:SetPoint("TOPLEFT", 12, -12)
end

-- Reuse the existing page controls and reflow their text without any server request during rendering.
function EH:RenderHousingInfo()
    if not self.infoPages then return end
    for key, page in pairs(self.infoPages) do
        if self.view == key then
            local lines = key == "house" and self:HouseLines() or self:NeighborhoodLines()
            local width = math.max(1, page.scroll:GetWidth() - 10)
            page.content:SetWidth(width); page.text:SetWidth(width)
            page.text:SetText(table.concat(lines, "\n"))
            page.content:SetHeight(math.max(1, page.text:GetStringHeight() + 12))
        end
    end
    if self.houseSelector then
        local info = self:SelectedHouse()
        self.houseSelector.text:SetText(info and (Text(info.houseName or info.neighborhoodName) .. " - Plot " .. Text(info.plotID)) or "Choose house")
    end
end
