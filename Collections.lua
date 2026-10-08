local _, EH = ...

-- Index native catalog entries and bundled recipes by output item ID without applying browse filters.
function EH:IndexCollections()
    self.collectionEntries, self.recipesByItem = {}, {}
    for _, entry in ipairs(self.entries) do
        local id = entry.info.itemID
        if self:Readable(id) and type(id) == "number" then self.collectionEntries[id] = entry end
    end
    for id, recipe in pairs(self.housingRecipes) do self.recipesByItem[recipe.itemID] = id end
end

-- Find a suggested set by its stable key; names and ownership can change independently.
function EH:CollectionSet(key)
    for _, set in ipairs(self.collectionSets) do if set.key == key then return set end end
    return self.collectionSets[1]
end

-- Keep unavailable entries distinct from known missing decor and count each item type only once.
function EH:CollectionChecklist(key)
    if not self.collectionEntries then self:IndexCollections() end
    local set, rows = self:CollectionSet(key), {}
    local counts = { owned = 0, missing = 0, unavailable = 0, total = 0 }
    for _, id in ipairs(set.items) do
        local entry = self.collectionEntries[id]
        local status = not entry and "unavailable" or (entry.owned > 0 and "owned" or "missing")
        counts[status], counts.total = counts[status] + 1, counts.total + 1
        rows[#rows + 1] = { itemID = id, entry = entry, status = status, recipeID = self.recipesByItem[id],
            name = entry and entry.name or self:ProjectItemName(id, self.collectionItemNames[id]) }
    end
    table.sort(rows, function(a, b) return a.name == b.name and a.itemID < b.itemID or a.name < b.name end)
    return set, rows, counts
end

-- Add one craft per known missing craftable decor type, preserving existing larger quantities.
function EH:PlanCollection(key)
    local _, rows = self:CollectionChecklist(key)
    local count = 0
    for _, row in ipairs(rows) do
        if row.status == "missing" and row.recipeID then
            self.db.craftPlan[row.recipeID] = math.max(1, self.db.craftPlan[row.recipeID] or 0)
            count = count + 1
        end
    end
    self:Notify(count .. " missing craftable decor types added to your plan (one craft each).")
    self:RenderProjects()
end

-- Open the native catalog detail for a checklist item without changing existing browse filters.
function EH:InspectCollectionItem(row)
    if not row.entry then self:Notify("This item is not in the current Blizzard catalog."); return end
    self.selected = row.entry; self:SetView("catalog"); self:RenderDetails()
end
