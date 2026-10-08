local _, EH = ...

-- Accept ordinary finite nonnegative quantities before calculations or optional-addon calls.
local function Quantity(value)
    return EH:Readable(value) and type(value) == "number" and value >= 0 and value < 1000000000 and value % 1 == 0
end

-- Prefer localized cached item names; request missing metadata once per session.
function EH:ProjectItemName(id, fallback)
    local name = self:Call(C_Item and C_Item.GetItemNameByID, id)
    if type(name) == "string" and name ~= "" then return name end
    self.projectItems = self.projectItems or {}
    if not self.projectItems[id] and C_Item and C_Item.RequestLoadItemDataByID then
        self.projectItems[id] = true; self:Call(C_Item.RequestLoadItemDataByID, id)
    end
    return fallback or "Item " .. id
end

-- Normalize account-wide plans after loading saved variables, keeping quantities bounded.
function EH:NormalizeCraftPlan()
    for id, count in pairs(self.db.craftPlan) do
        if not self.housingRecipes[id] or not Quantity(count) or count < 1 then self.db.craftPlan[id] = nil
        else self.db.craftPlan[id] = math.min(999, count) end
    end
    for id, choices in pairs(self.db.reagentChoices) do
        if not self.housingRecipes[id] or type(choices) ~= "table" then self.db.reagentChoices[id] = nil end
    end
end

-- Set the number of crafts, with zero removing a recipe; never automate crafting.
function EH:SetCraftCount(id, count)
    if not self.housingRecipes[id] then return false end
    count = tonumber(count)
    if not Quantity(count) or count > 999 then self:Notify("Enter a whole number of crafts from 0 to 999."); return false end
    self.db.craftPlan[id] = count > 0 and count or nil
    self:RenderProjects(); return true
end

-- Resolve learned state only from current character recipe data, honoring known profession mismatches.
function EH:RecipeState(id)
    local recipe, api = self.housingRecipes[id], C_TradeSkillUI
    if not recipe then return "unknown" end
    if self.professionsKnown and not self.professions[recipe.professionID] then return "other" end
    for _, name in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
        if api and type(api[name]) == "function" and self:Call(api[name]) ~= false then return "unknown" end
    end
    local info = self:Call(api and api.GetRecipeInfo, id)
    if type(info) ~= "table" or not self:Readable(info.learned) then return "unknown" end
    if info.learned == true then return "learned" end
    return info.learned == false and "unlearned" or "unknown"
end

-- Read current required slots, retaining explicit quality alternatives and currencies.
function EH:RecipeRequirements(id)
    local recipe = self.housingRecipes[id]
    if not recipe then return {}, "unavailable" end
    local schematic = self:Call(C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic, id, false)
    local result = {}
    if type(schematic) ~= "table" then
        for index, reagent in ipairs(recipe.reagents) do
            result[#result + 1] = { itemID = reagent.itemID, quantity = reagent.quantity, name = reagent.name, slot = index }
        end
        return result, "estimate"
    end
    local slots = schematic.reagentSlotSchematics
    if not self:Readable(schematic.recipeID) or schematic.recipeID ~= id then return {}, "incomplete" end
    if not self:Readable(slots) or type(slots) ~= "table" then return {}, "incomplete" end
    for index, slot in ipairs(slots) do
        if not self:Readable(slot) or type(slot) ~= "table" or not self:Readable(slot.required) then return {}, "incomplete" end
        if slot.required then
            if not Quantity(slot.quantityRequired) or not self:Readable(slot.reagents) or type(slot.reagents) ~= "table"
                or not self:Readable(slot.variableQuantities) or (slot.variableQuantities and #slot.variableQuantities > 0) then
                return {}, "incomplete"
            end
            local alternatives = {}
            for _, reagent in ipairs(slot.reagents) do
                if not self:Readable(reagent) or type(reagent) ~= "table" then return {}, "incomplete" end
                local iid, cid = reagent.itemID, reagent.currencyID
                if not self:Readable(iid) or not self:Readable(cid) then return {}, "incomplete" end
                if Quantity(iid) and iid > 0 then alternatives[#alternatives + 1] = iid
                elseif Quantity(cid) and cid > 0 and #slot.reagents == 1 then
                    result[#result + 1] = { currencyID = cid, quantity = slot.quantityRequired, slot = index }
                else return {}, "incomplete" end
            end
            if #alternatives > 0 then
                local saved = self.db.reagentChoices[id] and self.db.reagentChoices[id][index]
                local selected = alternatives[1]
                for _, iid in ipairs(alternatives) do if iid == saved then selected = iid end end
                result[#result + 1] = { itemID = selected, alternatives = alternatives, quantity = slot.quantityRequired, slot = index }
            elseif #slot.reagents == 0 then return {}, "incomplete" end
        end
    end
    return result, "native", schematic
end

-- Persist a selection only when the current native slot explicitly permits that item.
function EH:ChooseRecipeReagent(id, slot, itemID)
    local rows, source = self:RecipeRequirements(id)
    if source ~= "native" then return false end
    for _, row in ipairs(rows) do
        if row.slot == slot then
            for _, candidate in ipairs(row.alternatives or {}) do
                if candidate == itemID then
                    self.db.reagentChoices[id] = self.db.reagentChoices[id] or {}
                    self.db.reagentChoices[id][slot] = itemID; self:RenderProjects(); return true
                end
            end
        end
    end
    return false
end

-- Count only this character's publicly available bag contents unless bank inclusion is selected.
function EH:ReagentOwned(row)
    if row.currencyID then
        local info = self:Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo, row.currencyID)
        local count = type(info) == "table" and info.quantity
        return Quantity(count) and count or nil
    end
    local count = self:Call(C_Item and C_Item.GetItemCount, row.itemID, self.projectBanks == true, false,
        self.projectBanks == true, self.projectBanks == true)
    return Quantity(count) and count or nil
end

-- Read cached Auctionator unit prices through its stable public API, keeping unknown prices unknown.
function EH:ReagentPrice(id)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local price = id and self:Call(api and api.GetAuctionPriceByItemID, self.name, id)
    return Quantity(price) and price or nil
end

-- Aggregate selected crafts before subtracting inventory so shared materials are counted once.
function EH:CraftShoppingList()
    local grouped, rows, summary = {}, {}, { crafts = 0, recipes = 0, estimates = 0, incomplete = 0, cost = 0, unpriced = 0 }
    for id, count in pairs(self.db.craftPlan) do
        if self.housingRecipes[id] and Quantity(count) and count > 0 and count <= 999 then
            local requirements, source = self:RecipeRequirements(id)
            summary.crafts, summary.recipes = summary.crafts + count, summary.recipes + 1
            if source == "estimate" then summary.estimates = summary.estimates + 1 end
            if source == "incomplete" then summary.incomplete = summary.incomplete + 1 end
            for _, reagent in ipairs(requirements) do
                local key = (reagent.currencyID and "currency:" or "item:") .. (reagent.currencyID or reagent.itemID)
                local row = grouped[key]
                if not row then
                    row = { key = key, itemID = reagent.itemID, currencyID = reagent.currencyID, required = 0, fallbackName = reagent.name }
                    grouped[key] = row
                end
                row.required = row.required + reagent.quantity * count
                row.hasAlternatives = row.hasAlternatives or (reagent.alternatives and #reagent.alternatives > 1)
                if reagent.alternatives then
                    row.alternatives = row.alternatives or {}
                    for _, iid in ipairs(reagent.alternatives) do row.alternatives[iid] = true end
                end
            end
        end
    end
    for _, row in pairs(grouped) do
        local currency = row.currencyID and self:Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo, row.currencyID)
        row.name = row.itemID and self:ProjectItemName(row.itemID, row.fallbackName)
            or (type(currency) == "table" and self:Readable(currency.name) and type(currency.name) == "string" and currency.name) or "Currency " .. row.currencyID
        row.owned = self:ReagentOwned(row)
        row.missing = row.owned and math.max(0, row.required - row.owned) or nil
        row.price = self:ReagentPrice(row.itemID)
        if row.missing == nil or (row.missing > 0 and not row.price) then summary.unpriced = summary.unpriced + 1
        elseif row.missing > 0 then summary.cost = summary.cost + row.missing * row.price end
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b) return a.name == b.name and a.key < b.key or a.name < b.name end)
    return rows, summary
end

-- Export only known missing item quantities on an explicit click; leave currency and unknown counts visible.
function EH:ExportCraftShoppingList()
    if InCombatLockdown() then self:Notify("Export your shopping list after combat."); return false end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or type(api.CreateShoppingList) ~= "function" or type(api.ConvertToSearchString) ~= "function" then
        self:Notify("Install Auctionator to export a reagent shopping list."); return false
    end
    local rows, summary = self:CraftShoppingList()
    if summary.incomplete > 0 then self:Notify("Some native reagent data is incomplete. Open the relevant profession and refresh before exporting."); return false end
    local terms = {}
    for _, row in ipairs(rows) do
        if row.itemID and row.missing == nil then self:Notify("Inventory counts are unavailable. Refresh before exporting."); return false end
        if row.itemID and row.missing > 0 then
            local name = self:Call(C_Item and C_Item.GetItemNameByID, row.itemID)
            if type(name) ~= "string" or name == "" then self:Notify("Item names are still loading. Refresh before exporting."); return false end
            local quality = self:Call(C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo, row.itemID)
            if row.hasAlternatives and not Quantity(quality) then
                for iid in pairs(row.alternatives) do
                    if iid ~= row.itemID then
                        local alternativeName = self:Call(C_Item and C_Item.GetItemNameByID, iid)
                        if type(alternativeName) ~= "string" or alternativeName == "" then
                            self:ProjectItemName(iid); self:Notify("Alternative reagent names are still loading. Refresh before exporting."); return false
                        end
                        if alternativeName == name then
                            self:Notify("Reagent quality data is unavailable. Open the profession and refresh before exporting."); return false
                        end
                    end
                end
            end
            local term = self:Call(api.ConvertToSearchString, self.name, { searchString = name, isExact = true, quantity = row.missing,
                tier = Quantity(quality) and quality > 0 and quality or nil })
            if type(term) ~= "string" then self:Notify("Auctionator could not build this shopping list."); return false end
            terms[#terms + 1] = term
        end
    end
    if #terms == 0 then self:Notify("There are no missing item reagents to export."); return false end
    local ok = pcall(api.CreateShoppingList, self.name, "ElementHousing Reagents", terms)
    self:Notify(ok and "Updated Auctionator's ElementHousing Reagents list. Quantities are based on your selected inventory scope."
        or "Auctionator could not create the shopping list.")
    return ok
end

-- Toggle Blizzard's tracked recipe on a click; Kaliel's Tracker consumes the same native list.
function EH:TrackHousingRecipe(id)
    if InCombatLockdown() then self:Notify("Track recipes after combat."); return false end
    local api = C_TradeSkillUI
    if self:RecipeState(id) ~= "learned" or not api or type(api.SetRecipeTracked) ~= "function" then
        self:Notify("Open the recipe's profession to load a learned recipe before tracking it."); return false
    end
    local tracked = self:Call(api.IsRecipeTracked, id, false)
    if type(tracked) ~= "boolean" then self:Notify("Recipe tracking status is unavailable."); return false end
    local ok = pcall(api.SetRecipeTracked, id, not tracked, false)
    ok = ok and self:Call(api.IsRecipeTracked, id, false) == not tracked
    if ok then self:RenderProjects() else self:Notify("Blizzard could not update recipe tracking. Check your native tracked-recipe limit and loaded profession.") end
    return ok
end

-- Open the selected known profession recipe only from a direct user action.
function EH:OpenHousingRecipe(id)
    if InCombatLockdown() then self:Notify("Open recipes after combat."); return false end
    if self:RecipeState(id) == "other" then self:Notify("This character does not have that profession."); return false end
    self:Call(ProfessionsFrame_LoadUI)
    local fn = C_TradeSkillUI and C_TradeSkillUI.OpenRecipe
    local ok = type(fn) == "function" and pcall(fn, id)
    if not ok then self:Notify("Open the relevant profession to view this recipe.") end
    return ok
end

-- Coalesce inventory, profession, price, and item-data refreshes without querying the housing catalog.
function EH:ScheduleProjectRefresh()
    if self.projectRefreshPending or not self.frame or not self.frame:IsShown() or self.view ~= "collections" then return end
    self.projectRefreshPending = true
    C_Timer.After(.15, function()
        self.projectRefreshPending = nil
        if self.frame and self.frame:IsShown() and self.view == "collections" then self:RenderProjects() end
    end)
end
