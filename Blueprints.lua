local _, EH = ...
EH.blueprintList = {}

-- Normalize a share code using Blizzard's parser; validation does not imply server existence.
function EH:BlueprintCode(input)
    if type(input) ~= "string" or #input > 4096 or not C_HousingBlueprint then return nil end
    input = input:match("^%s*(.-)%s*$")
    local code = self:Call(C_HousingBlueprint.UpdateBlueprintStringFromInput, input) or input
    if self:Call(C_HousingBlueprint.IsShareCodeValid, code) then return code end
end

-- Merge Blizzard's collection with explicitly saved share codes without duplicating entries.
function EH:BuildBlueprintList()
    local result, seen = {}, {}
    for _, group in ipairs(self.blueprintCollection and self.blueprintCollection.groups or {}) do
        for _, info in ipairs(group.entries or {}) do
            if not info.isAutoSave or self.db.settings.showAutosaves then
                local entry = self:Copy(info)
                entry.group = group.name
                result[#result + 1], seen[entry.shareCode] = entry, true
            end
        end
    end
    for code, info in pairs(self.db.blueprints) do
        if not seen[code] then result[#result + 1] = { shareCode = code, name = info.name, group = "Saved codes" } end
    end
    -- Keep the collection ordered by readable names and stable share codes.
    table.sort(result, function(a, b)
        if (a.name or "") == (b.name or "") then return a.shareCode < b.shareCode end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    self.blueprintList = result
end

-- Request the native collection only while the user has opened the blueprint workspace.
function EH:RefreshBlueprints()
    if not C_HousingBlueprint then self.blueprintStatus = "Blueprint APIs unavailable on this client."
    elseif InCombatLockdown() then self.blueprintStatus = "Open blueprints again after combat."
    else
        local result = self:Call(C_HousingBlueprint.GetFeatureAvailability)
        if result ~= Enum.HousingResult.Success then self.blueprintStatus = self:BlueprintReason(result, "Blueprints are unavailable at this location.")
        else
            self.blueprintStatus = "Loading blueprint collection..."
            C_HousingBlueprint.RequestBlueprintCollection()
        end
    end
    self:BuildBlueprintList(); self:RenderBlueprints()
end

-- Inspect a code asynchronously; newer selections supersede previous server responses.
function EH:InspectBlueprint(input, name)
    local code = self:BlueprintCode(input)
    if not code then self:Notify("Enter a valid Blizzard housing blueprint share code."); return false end
    if InCombatLockdown() then self:Notify("Inspect blueprints after combat."); return false end
    self.blueprintCode, self.blueprintName = code, name or "Shared blueprint"
    self.notice = nil
    self.blueprintContents, self.blueprintStatus = nil, "Loading blueprint contents..."
    self.blueprintPending = true
    C_HousingBlueprint.RequestBlueprintContents(code)
    self:RenderBlueprints()
    return true
end

-- Save a valid code locally; never write arbitrary imported Lua or decode executable content.
function EH:SaveBlueprint(input, name)
    local code = self:BlueprintCode(input)
    name = self:Plain(name or ""):gsub("|", ""):match("^%s*(.-)%s*$"):sub(1, 80)
    if not code then self:Notify("Enter a valid Blizzard housing blueprint share code."); return false end
    if name == "" then name = "Shared blueprint" end
    local count = 0
    for _ in pairs(self.db.blueprints) do count = count + 1 end
    if count >= 200 and not self.db.blueprints[code] then self:Notify("Keep at most 200 saved blueprint codes."); return false end
    self.db.blueprints[code] = { name = name }
    self:BuildBlueprintList(); self:RenderBlueprints()
    return true
end

-- Remove only a local saved code; Blizzard's collection remains managed by Blizzard.
function EH:ForgetBlueprint(code)
    self.db.blueprints[code] = nil
    self:BuildBlueprintList(); self:RenderBlueprints()
end

-- Delegate blueprint import and its preview/confirmation to Blizzard's supported dialog.
function EH:ImportBlueprint(code)
    code = self:BlueprintCode(code)
    if not code then self:Notify("Select or inspect a valid blueprint first."); return false end
    if InCombatLockdown() then self:Notify("Blueprint import is unavailable during combat."); return false end
    local result = self:Call(C_HousingBlueprint.GetImportAvailability)
    if result ~= Enum.HousingResult.Success then self:Notify("Blueprint import is unavailable at this location."); return false end
    if HousingFramesUtil and HousingFramesUtil.ShowBlueprintImport then
        HousingFramesUtil.ShowBlueprintImport(code)
        return true
    end
    -- Load Blizzard's own UI only on an explicit import action, then use its guarded flow.
    self:Call(C_AddOns and C_AddOns.LoadAddOn, "Blizzard_HousingBlueprint")
    if HousingBlueprintImportFrame and HousingBlueprintImportFrame.StartImportFlow then
        return HousingBlueprintImportFrame:StartImportFlow(code) ~= false
    end
    self:Notify("Blizzard's blueprint import dialog is unavailable. Open the native housing dashboard first.")
    return false
end

-- Open the native export flow so Blizzard validates the house, layout, and export budget.
function EH:ExportBlueprint()
    if InCombatLockdown() then self:Notify("Blueprint export is unavailable during combat."); return end
    if not C_HousingBlueprint or self:Call(C_HousingBlueprint.GetExportAvailability) ~= Enum.HousingResult.Success then
        self:Notify("Blueprint export requires an available house editor context."); return
    end
    if HousingFramesUtil and HousingFramesUtil.ShowBlueprintExport then HousingFramesUtil.ShowBlueprintExport(); return end
    self:Call(C_AddOns and C_AddOns.LoadAddOn, "Blizzard_HousingBlueprint")
    if HousingBlueprintExportFrame and HousingBlueprintExportFrame.StartExportFlow then HousingBlueprintExportFrame:StartExportFlow()
    else self:Notify("Open Blizzard's housing dashboard to export a blueprint.") end
end

-- Keep requirement totals accurate for decor, rooms, dyes, fixtures, and other native groups.
function EH:BlueprintSummary(contents)
    local total, missing, invalid = 0, 0, 0
    for _, group in ipairs(contents and contents.contentGroups or {}) do
        for _, entry in ipairs(group.entries or {}) do
            total, missing = total + entry.total, missing + entry.numMissing
            if entry.invalid then invalid = invalid + 1 end
        end
    end
    return total, missing, invalid
end

-- Prefer Blizzard's localized availability message over exposing internal result numbers.
function EH:BlueprintReason(result, fallback)
    return HousingResultToErrorText and HousingResultToErrorText[result] or fallback
end

-- Label native budget types and distinguish a room addition from a whole-layout replacement.
function EH:BlueprintBudgetText(budget, interior)
    local names = { RoomPlacement = "Rooms", DecorPlacement = "Decor placement", PetDecor = "Pets" }
    local label = "Housing budget"
    for name, id in pairs(Enum.HousingBudgetType or {}) do if id == budget.budgetType then label = names[name] or name end end
    local text = label .. ": " .. budget.cost .. " required"
    if budget.max ~= nil then
        local blueprintType = self:Call(C_HousingBlueprint and C_HousingBlueprint.GetBlueprintTypeForCode, self.blueprintCode)
        if interior and Enum.HousingBlueprintType and blueprintType == Enum.HousingBlueprintType.Room and budget.current ~= nil then
            text = text .. " / " .. math.max(0, budget.max - budget.current) .. " available"
        else text = text .. " / " .. budget.max .. " maximum" end
    end
    if budget.current ~= nil then text = text .. " (currently " .. budget.current .. ")" end
    return text
end

-- Decode native requirement flags into actionable labels without inventing missing-data causes.
function EH:BlueprintIssues(contents)
    local issues = {}
    local names = { { "InsufficientBudget", "Insufficient housing budget" }, { "MissingRoom", "Missing room unlocks" },
        { "MissingFixture", "Missing fixtures" }, { "MissingDecor", "Missing decor copies" },
        { "MissingDye", "Missing dyes" }, { "MismatchedExteriorFaction", "Exterior belongs to another faction" },
        { "HouseTypeLocked", "House type is locked" }, { "HouseSizeLocked", "House size is locked" } }
    for _, pair in ipairs(names) do
        local flag = Enum.HousingBlueprintUnmetRequirementFlags and Enum.HousingBlueprintUnmetRequirementFlags[pair[1]]
        if flag and bit and bit.band(contents.unmetRequirementFlags or 0, flag) ~= 0 then
            local blocked = bit.band(contents.blockingRequirementFlags or 0, flag) ~= 0
            issues[#issues + 1] = pair[2] .. (blocked and " - blocks import" or "")
        end
    end
    return issues
end

-- Accept only responses belonging to the active blueprint request.
function EH:BlueprintEvent(event, ...)
    if event == "HOUSING_BLUEPRINT_COLLECTION_RECEIVED" then
        self.blueprintCollection = ...
        if not self.blueprintPending then self.blueprintStatus = nil end
        self:BuildBlueprintList()
    elseif event == "HOUSING_BLUEPRINT_COLLECTION_FAILURE" then self.blueprintStatus = "The blueprint collection could not be loaded."
    elseif event == "HOUSING_BLUEPRINT_CONTENTS_RECEIVED" then
        local contents = ...
        if not contents or contents.shareCode ~= self.blueprintCode then return end
        self.blueprintContents, self.blueprintStatus = contents, nil
        self.blueprintPending = false
    elseif event == "HOUSING_BLUEPRINT_CONTENTS_FAILURE" then
        local code, result = ...
        if code ~= self.blueprintCode then return end
        self.blueprintContents = nil
        self.blueprintPending = false
        self.blueprintStatus = self:BlueprintReason(result, "Blueprint contents are unavailable. Check the share code and try again.")
    elseif event == "HOUSING_BLUEPRINTS_AVAILABILITY_CHANGED" or event == "HOUSING_BLUEPRINT_EXPORT_SUCCESS"
        or event == "HOUSING_BLUEPRINT_RENAME_SUCCESS" or event == "HOUSING_BLUEPRINT_DELETE_SUCCESS" then
        if self.view == "blueprints" and self.frame and self.frame:IsShown() then self:RefreshBlueprints(); return end
    end
    if self.frame then self:RenderBlueprints() end
end
