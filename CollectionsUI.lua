local _, EH = ...
local E = ElvUI[1]
local states = { learned = "Learned", unlearned = "Not learned", other = "Other profession", unknown = "Recipe data pending" }

-- Place reusable controls without retaining points from an earlier font or window layout.
local function Place(widget, parent, x, y, width, height)
    widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    widget:SetSize(math.max(1, width), math.max(1, height)); widget:Show()
end

-- Keep compact control captions bounded while exposing full text in their native tooltips.
local function Caption(button, text)
    button.text:SetText(text); button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", button.icon and 28 or 7, 0); button.text:SetPoint("RIGHT", -7, 0)
    button.text:SetWordWrap(false)
    button.tooltip = text
end

-- Show complete row and control information when native font sizes truncate compact captions.
local function Tooltip(widget)
    if not widget.tooltip then return end
    local text = widget.data and widget.data.recipeID and EH.projects.mode == "recipes"
        and EH:HousingRecipeTooltip(widget.data) or widget.tooltip
    GameTooltip:SetOwner(widget, "ANCHOR_RIGHT"); GameTooltip:ClearLines()
    GameTooltip:AddLine(text, 1, 1, 1, true); GameTooltip:Show()
end

-- Read detailed schematics only for a hovered recipe, avoiding metadata requests for the entire library.
function EH:HousingRecipeTooltip(row)
    local id, recipe = row.recipeID, self.housingRecipes[row.recipeID]
    local requirements, source, schematic = self:RecipeRequirements(id)
    local tooltip = { row.name, self.professionNames[recipe.professionID] .. " / " .. recipe.expansion,
        states[self:RecipeState(id)], "Recipe ID: " .. id,
        source == "native" and "Current Blizzard requirements per craft:" or source == "estimate" and "Bundled estimates per craft:"
            or "Native requirements incomplete; open the profession and refresh." }
    if schematic and self:Readable(schematic.quantityMin) and self:Readable(schematic.quantityMax)
        and type(schematic.quantityMin) == "number" and type(schematic.quantityMax) == "number"
        and schematic.quantityMin >= 0 and schematic.quantityMax >= schematic.quantityMin and schematic.quantityMax < 1000000000 then
        tooltip[#tooltip + 1] = "Output per craft: " .. schematic.quantityMin .. "-" .. schematic.quantityMax
    end
    for _, reagent in ipairs(requirements) do
        tooltip[#tooltip + 1] = reagent.quantity .. " x " .. (reagent.itemID and self:ProjectItemName(reagent.itemID, reagent.name)
            or "Currency " .. reagent.currencyID) .. (reagent.alternatives and #reagent.alternatives > 1 and " (choose reagent in menu)" or "")
    end
    return table.concat(tooltip, "\n")
end

-- Build one reusable collection/crafting workspace using ElvUI fonts, skins, and status bars.
function EH:CreateProjectsPanel()
    local panel = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    panel:Hide(); self:Skin(panel, true)
    panel:SetPoint("TOPLEFT", 12, -82); panel:SetPoint("BOTTOMRIGHT", -12, 38)
    local root = panel
    local scroll = CreateFrame("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4); scroll:SetPoint("BOTTOMRIGHT", -24, 4)
    panel = CreateFrame("Frame", nil, scroll); panel:SetSize(700, 1); scroll:SetScrollChild(panel)
    local page = { root = root, scroll = scroll, panel = panel, mode = "sets", setKey = "cozy-cottage", profession = "all", offset = 0, rows = {}, tabs = {} }
    self.projects = page
    for _, mode in ipairs({ "sets", "recipes", "reagents" }) do
        local key = mode
        page.tabs[key] = self:Button(panel, ({ sets = "Sets", recipes = "Recipes", reagents = "Reagents" })[key], 120,
            function() self:SetProjectMode(key) end,
            ({ sets = "collection", recipes = "professions", reagents = "shop" })[key])
    end
    page.select = self:Button(panel, "", 240, function(button)
        if page.mode == "sets" then
            local choices = {}
            for _, set in ipairs(self.collectionSets) do
                local owned, known = 0, 0
                for _, id in ipairs(set.items) do
                    local entry = self.collectionEntries[id]
                    if entry then known = known + 1; if entry.owned > 0 then owned = owned + 1 end end
                end
                choices[set.key] = (set.kind == "theme" and "Theme: " or "Collection: ") .. set.name .. " (" .. owned .. "/" .. known .. ")"
            end
            self:ChoiceMenu(button, choices, function() return page.setKey end,
                function(key) page.setKey, page.offset = key, 0; self:RenderProjects() end)
        elseif page.mode == "recipes" then
            local choices = { all = "All professions", mine = "My professions" }
            for _, recipe in pairs(self.housingRecipes) do choices[tostring(recipe.professionID)] = self.professionNames[recipe.professionID] end
            self:ChoiceMenu(button, choices, function() return page.profession end,
                function(key) page.profession, page.offset = key, 0; self:RenderProjects() end)
        else self.projectBanks = not self.projectBanks; self:RenderProjects() end
    end, "menu")
    page.search = self:Edit(panel, 220, function(_, userInput)
        if userInput then page.offset = 0; self:ScheduleProjectRefresh() end
    end)
    page.search:SetMaxLetters(128)
    page.searchLabel = self:Label(panel, "Search this view")
    page.toggle = self:Button(panel, "", 190, function()
        page.missingOnly, page.offset = not page.missingOnly, 0; self:RenderProjects()
    end)
    page.action = self:Button(panel, "", 190, function(button) self:ProjectActions(button) end, "menu")
    for _, button in ipairs({ page.select, page.toggle, page.action }) do
        button:SetScript("OnEnter", Tooltip); button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    page.title, page.description, page.summary = self:Label(panel, ""), self:Label(panel, ""), self:Label(panel, "")
    page.description:SetWordWrap(true); page.summary:SetWordWrap(true)
    page.progress = CreateFrame("StatusBar", nil, panel, "BackdropTemplate")
    self:Skin(page.progress, true); E:RegisterStatusBar(page.progress)
    page.progress:SetMinMaxValues(0, 1)
    page.progress.text = self:Label(page.progress, ""); page.progress.text:SetPoint("CENTER")
    page.body = CreateFrame("Frame", nil, panel)
    page.body:EnableMouseWheel(true)
    page.body:SetScript("OnMouseWheel", function(_, delta) self:ScrollProjects((page.offset or 0) - delta * 3) end)
    page.scrollbar = CreateFrame("Slider", nil, panel, "BackdropTemplate")
    self:Skin(page.scrollbar); page.scrollbar:SetOrientation("VERTICAL")
    page.scrollbar:SetValueStep(1); page.scrollbar:SetObeyStepOnDrag(true)
    page.scrollbar:SetThumbTexture(E.media.normTex); page.scrollbar:GetThumbTexture():SetSize(10, 32)
    E:RegisterStatusBar(page.scrollbar:GetThumbTexture())
    page.scrollbar:SetScript("OnValueChanged", function(_, value) if not page.rendering then self:ScrollProjects(value) end end)
    page.empty = self:Label(page.body, ""); page.empty:SetPoint("CENTER"); page.empty:SetJustifyH("CENTER")
    page.hint = self:Label(panel, ""); page.hint:SetWordWrap(true)
    page.hint:SetPoint("BOTTOMLEFT", 12, 9); page.hint:SetPoint("BOTTOMRIGHT", -12, 9)
end

-- Start a newly selected workspace with its own broad view rather than carrying another mode's filter.
function EH:SetProjectMode(mode)
    local page = self.projects
    if not page then return end
    if page.mode ~= mode then
        page.mode, page.offset, page.missingOnly = mode, 0, false
        page.search:SetText(""); page.search:ClearFocus()
    end
    self.notice = nil; self:RenderProjects()
end

-- Offer mode-specific explicit actions; exporting and tracking never run while rendering.
function EH:ProjectActions(button)
    local page = self.projects
    MenuUtil.CreateContextMenu(button, function(_, root)
        if page.mode == "sets" then
            root:CreateButton("Plan missing craftable decor (one craft each)", function() self:PlanCollection(page.setKey) end)
            root:CreateButton("Show recipe library", function() self:SetProjectMode("recipes") end)
        else
            root:CreateButton("Export missing reagents to Auctionator", function() self:ExportCraftShoppingList() end)
            root:CreateButton("Show reagent totals", function() self:SetProjectMode("reagents") end)
            root:CreateButton("Clear crafting plan...", function()
                self:TextDialog("Type CLEAR to empty the crafting plan", "", function(text)
                    if text == "CLEAR" then wipe(self.db.craftPlan); self:RenderProjects() end
                end)
            end)
        end
    end)
end

-- Open native item details or recipe planning controls for the explicitly clicked row.
function EH:ProjectRowMenu(row)
    if row.recipeID and self.projects.mode == "recipes" then
        local id = row.recipeID
        MenuUtil.CreateContextMenu(self.projects.panel, function(_, root)
            root:CreateButton("Set crafts (0 removes)...", function()
                self:TextDialog("Number of crafts (0-999)", tostring(self.db.craftPlan[id] or 1),
                    function(value) self:SetCraftCount(id, value) end)
            end)
            root:CreateButton("Add one craft", function() self:SetCraftCount(id, math.min(999, (self.db.craftPlan[id] or 0) + 1)) end)
            root:CreateButton("Remove from plan", function() self:SetCraftCount(id, 0) end)
            root:CreateButton("Open profession recipe", function() self:OpenHousingRecipe(id) end)
            root:CreateButton("Track / untrack recipe", function() self:TrackHousingRecipe(id) end)
            local requirements, source = self:RecipeRequirements(id)
            for _, reagent in ipairs(requirements) do
                if source == "native" and reagent.alternatives and #reagent.alternatives > 1 then
                    local slot = reagent.slot
                    local submenu = root:CreateButton("Reagent choice: " .. self:ProjectItemName(reagent.itemID))
                    for _, iid in ipairs(reagent.alternatives) do
                        local itemID = iid
                        submenu:CreateRadio(self:ProjectItemName(itemID) .. " (" .. itemID .. ")",
                            function() return (self.db.reagentChoices[id] and self.db.reagentChoices[id][slot] or reagent.alternatives[1]) == itemID end,
                            function() self:ChooseRecipeReagent(id, slot, itemID) end)
                    end
                end
            end
            local entry = self.collectionEntries and self.collectionEntries[row.itemID]
            if entry then root:CreateButton("View decor in catalog", function() self:InspectCollectionItem({ entry = entry }) end) end
        end)
    elseif self.projects.mode == "sets" then self:InspectCollectionItem(row)
    elseif row.itemID then
        GameTooltip:SetOwner(self.projects.panel, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(row.itemID); GameTooltip:Show()
    end
end

-- Build searchable row data independently of rendering and the catalog's current filters.
function EH:ProjectRows()
    local page, rows = self.projects, {}
    local search = self:Plain(page.search:GetText()):lower()
    if page.mode == "sets" then
        local set, checklist, counts = self:CollectionChecklist(page.setKey)
        page.title:SetText(set.name); page.description:SetText(set.description)
        page.summary:SetText(string.format("Owned %d  |  Missing %d  |  Unavailable %d  |  Set size %d", counts.owned, counts.missing, counts.unavailable, counts.total))
        local known = counts.owned + counts.missing
        page.progress:SetValue(known > 0 and counts.owned / known or 0)
        page.progress.text:SetText(string.format("Collected %d / %d known items", counts.owned, known))
        for _, row in ipairs(checklist) do
            if (not page.missingOnly or row.status == "missing") and row.name:lower():find(search, 1, true) then
                row.meta = row.entry and row.entry.sourceLabel or "Not in the current catalog"
                row.value = ({ owned = "Owned", missing = "Missing", unavailable = "Unavailable" })[row.status]
                row.tooltip = row.name .. "\n" .. row.value .. "\n" .. row.meta
                    .. (row.recipeID and "\nCrafting recipe available in Recipes." or "")
                rows[#rows + 1] = row
            end
        end
        page.hint:SetText("Checkmarks follow Blizzard ownership. Click an item for catalog details. Themes are community suggestions; unavailable entries do not count as missing.")
        Caption(page.select, set.name); Caption(page.toggle, page.missingOnly and "Missing only" or "All set items")
    elseif page.mode == "recipes" then
        page.title:SetText("Housing recipe library")
        page.description:SetText("Choose a recipe to set crafts, view reagents, open its profession, or track it.")
        local _, plan = self:CraftShoppingList()
        page.summary:SetText(string.format("Crafting plan: %d recipes  |  %d crafts  |  %d bundled estimates", plan.recipes, plan.crafts, plan.estimates))
        for id, recipe in pairs(self.housingRecipes) do
            local profession = self.professionNames[recipe.professionID]
            local entry = self.collectionEntries[recipe.itemID]
            local name = entry and entry.name or self:ProjectItemName(recipe.itemID, recipe.name)
            local state = self:RecipeState(id)
            local eligible = page.profession == "all" or (page.profession == "mine" and self.professions[recipe.professionID])
                or tonumber(page.profession) == recipe.professionID
            if eligible and (not page.missingOnly or self.db.craftPlan[id]) and (name .. " " .. profession .. " " .. recipe.expansion):lower():find(search, 1, true) then
                local tracked = self:Call(C_TradeSkillUI and C_TradeSkillUI.IsRecipeTracked, id, false) == true
                rows[#rows + 1] = { recipeID = id, itemID = recipe.itemID, name = name,
                    meta = profession .. "  |  " .. states[state] .. (tracked and "  |  Tracked" or ""),
                    value = self.db.craftPlan[id] and (self.db.craftPlan[id] .. " crafts") or "Add to plan", tooltip = name }
            end
        end
        page.hint:SetText("Plan quantities count crafts, not output items. Native tracking appears in Kaliel's Tracker when installed and its profession module is enabled, or Blizzard's tracker. Learned status is for this character.")
        Caption(page.select, page.profession == "all" and "All professions" or page.profession == "mine" and "My professions" or self.professionNames[tonumber(page.profession)] or "All professions")
        Caption(page.toggle, page.missingOnly and "Planned only" or "All recipes")
    else
        local shopping, plan = self:CraftShoppingList()
        page.title:SetText("Reagents for your crafting plan")
        page.description:SetText("Required totals combine every planned recipe before subtracting inventory. Reagent choices are set from each recipe's menu.")
        page.summary:SetText(string.format("%d recipes / %d crafts  |  %d estimates / %d incomplete  |  Cached price %s%s", plan.recipes, plan.crafts,
            plan.estimates, plan.incomplete, GetMoneyString(plan.cost), plan.unpriced > 0 and (" + " .. plan.unpriced .. " unpriced") or ""))
        for _, row in ipairs(shopping) do
            if (not page.missingOnly or row.missing == nil or row.missing > 0) and row.name:lower():find(search, 1, true) then
                row.meta = "Required " .. row.required .. "  |  Have " .. (row.owned or "Unknown")
                row.value = "Need " .. (row.missing or "Unknown")
                row.tooltip = row.name .. "\n" .. row.meta .. "\n" .. row.value .. "\nCached unit price: "
                    .. (row.price and GetMoneyString(row.price) or "Unknown / not auctionable")
                rows[#rows + 1] = row
            end
        end
        page.hint:SetText("Bank totals reflect data available to Blizzard. Auctionator prices are cached estimates. Actions exports/replaces only the ElementHousing Reagents list; currency requirements stay here.")
        Caption(page.select, self.projectBanks and "Bags + banks + warband" or "Inventory: bags only")
        Caption(page.toggle, page.missingOnly and "Missing only" or "All reagents")
    end
    table.sort(rows, function(a, b) return a.name == b.name and (a.itemID or a.currencyID) < (b.itemID or b.currencyID) or a.name < b.name end)
    return rows
end

-- Allocate only enough pooled rows for the current viewport, retaining native tooltip and click behavior.
function EH:ProjectRow(index)
    local page = self.projects
    if page.rows[index] then return page.rows[index] end
    local row = CreateFrame("Button", nil, page.body, "BackdropTemplate")
    self:Skin(row, true); row:StyleButton(nil, true, true)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(28, 28); row.icon:SetPoint("LEFT", 8, 0)
    row.check = row:CreateTexture(nil, "OVERLAY"); row.check:SetSize(22, 22); row.check:SetPoint("LEFT", 30, 0)
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.name, row.meta, row.value = self:Label(row, ""), self:Label(row, ""), self:Label(row, "")
    row.name:SetWordWrap(false); row.meta:SetWordWrap(false); row.value:SetWordWrap(false); row.value:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", Tooltip); row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(widget) if widget.data then self:ProjectRowMenu(widget.data) end end)
    row:EnableMouseWheel(true); row:SetScript("OnMouseWheel", function(_, delta) self:ScrollProjects(page.offset - delta * 3) end)
    page.rows[index] = row
    return row
end

-- Clamp a row offset independently of the catalog and redraw only the visible checklist rows.
function EH:ScrollProjects(offset)
    local page = self.projects
    page.offset = math.floor(self:Clamp(offset, 0, math.max(0, #(page.data or {}) - (page.visible or 1)), 0))
    self:RenderProjectList()
end

-- Render the bounded row pool, keeping empty and partial-data states explicit.
function EH:RenderProjectList()
    local page = self.projects
    local font = math.max(13, E.db.general.fontSize or 13)
    local height, width = font * 2 + 26, page.body:GetWidth()
    page.visible = math.max(1, math.floor(page.body:GetHeight() / height))
    local maximum = math.max(0, #page.data - page.visible)
    page.offset = math.min(page.offset, maximum)
    page.rendering = true; page.scrollbar:SetMinMaxValues(0, maximum); page.scrollbar:SetValue(page.offset); page.rendering = nil
    for index = 1, page.visible do
        local data = page.data[index + page.offset]
        local row = self:ProjectRow(index)
        row:SetShown(data ~= nil)
        if data then
            Place(row, page.body, 0, (index - 1) * height, width, height - 4)
            row.data, row.tooltip = data, data.tooltip
            row.icon:SetTexture(data.itemID and self:Call(C_Item and C_Item.GetItemIconByID, data.itemID) or self:Icon(page.mode == "reagents" and "shop" or "collection"))
            row.check:SetShown(data.status == "owned")
            row.name:SetText(data.name); row.meta:SetText(data.meta); row.value:SetText(data.value)
            row.name:ClearAllPoints(); row.name:SetPoint("TOPLEFT", 58, -6); row.name:SetWidth(math.max(1, width - 80))
            row.meta:ClearAllPoints(); row.meta:SetPoint("BOTTOMLEFT", 58, 7); row.meta:SetWidth(math.max(1, width * .7 - 64))
            row.value:ClearAllPoints(); row.value:SetPoint("BOTTOMRIGHT", -8, 7); row.value:SetWidth(math.max(1, width * .3 - 12))
            row.value:SetTextColor(unpack(E.media.rgbvaluecolor))
        end
    end
    for index = page.visible + 1, #page.rows do page.rows[index]:Hide() end
    page.empty:SetWidth(math.max(1, width - 24)); page.empty:SetText(#page.data == 0 and "No entries match this view. Add recipes to your crafting plan to see reagent totals." or "")
    page.empty:SetShown(#page.data == 0)
end

-- Reflow the workspace from native font metrics, and refresh data only while its tab is active.
function EH:RenderProjects()
    local page = self.projects
    if not page or self.view ~= "collections" or not self.frame:IsShown() then return end
    if not self.collectionEntries then self:IndexCollections() end
    page.data = self:ProjectRows()
    page.panel:SetWidth(math.max(1, self.frame:GetWidth() - 48))
    local width, font = page.panel:GetWidth() - 24, math.max(13, E.db.general.fontSize or 13)
    local control, y = font + 16, 12
    for index, mode in ipairs({ "sets", "recipes", "reagents" }) do
        local tab = page.tabs[mode]
        Place(tab, page.panel, 12 + (index - 1) * (width / 3 + 2), y, width / 3 - 4, control)
        tab.text:SetTextColor(unpack(mode == page.mode and E.media.rgbvaluecolor or { 1, 1, 1 }))
    end
    y = y + control + 12
    Place(page.select, page.panel, 12, y, width * .55 - 6, control)
    Place(page.action, page.panel, 12 + width * .55, y, width * .45, control); Caption(page.action, "Actions")
    y = y + control + 10
    Place(page.searchLabel, page.panel, 12, y, width, font + 6); y = y + font + 8
    Place(page.search, page.panel, 12, y, width * .55 - 6, control)
    Place(page.toggle, page.panel, 12 + width * .55, y, width * .45, control)
    y = y + control + 14
    Place(page.title, page.panel, 12, y, width, font + 8); page.title:SetTextColor(unpack(E.media.rgbvaluecolor)); y = y + font + 12
    page.description:SetWidth(width)
    Place(page.description, page.panel, 12, y, width, page.description:GetStringHeight())
    y = y + page.description:GetStringHeight() + 8
    page.summary:SetWidth(width)
    Place(page.summary, page.panel, 12, y, width, page.summary:GetStringHeight()); y = y + page.summary:GetStringHeight() + 10
    page.progress:SetShown(page.mode == "sets")
    if page.mode == "sets" then
        page.progress.text:SetWidth(width - 10)
        local barHeight = math.max(control, page.progress.text:GetStringHeight() + 10)
        Place(page.progress, page.panel, 12, y, width, barHeight)
        page.progress:SetStatusBarTexture(E.media.normTex); page.progress:SetStatusBarColor(unpack(E.media.rgbvaluecolor))
        y = y + barHeight + 10
    end
    page.hint:SetWidth(width)
    local bodyHeight = math.max((font * 2 + 26) * 3, page.root:GetHeight() - y - page.hint:GetStringHeight() - 22)
    page.panel:SetHeight(y + bodyHeight + page.hint:GetStringHeight() + 22)
    Place(page.body, page.panel, 12, y, width - 22, bodyHeight)
    Place(page.scrollbar, page.panel, 12 + width - 12, y, 12, bodyHeight)
    self:RenderProjectList()
    self:RenderStatus()
end
