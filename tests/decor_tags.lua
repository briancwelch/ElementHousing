-- Validate every imported classification and its native catalog linkage without creating fake acquisition data.
local function Decor(itemID)
    return { recordID = itemID + 500000, entryType = 1, itemID = itemID, name = "Tagged decor", sourceText = "",
        totalNumStored = 0, totalNumPlaced = 0, remainingRedeemable = 0, categoryIDs = {}, subcategoryIDs = {}, dataTagsByID = {} }
end

EH:Initialize()
local count = 0
for itemID, tags in pairs(EH.decorTags) do
    count = count + 1
    local entry = EH:MakeEntry(Decor(itemID))
    Check(entry.info.itemID == itemID and entry.decorTags == tags, "Classifications attach by stable item ID")
    Check(entry.sources.unknown and not entry.sources.vendor, "Community appearance tags do not invent acquisition requirements")
    for _, facet in ipairs(EH.decorFacets) do
        for _, id in ipairs(tags[facet] or {}) do
            Check(type(EH.decorTagNames[facet][id]) == "string", "Every classification has a vocabulary label")
            EH.filters[facet] = tostring(id)
            Check(EH:MatchesDecorTags(entry), "Every known classification can be selected")
            EH.filters[facet] = "all"
        end
        EH.filters[facet] = "unknown"
        Check(EH:MatchesDecorTags(entry) == (#(tags[facet] or {}) == 0), "Unclassified selectors keep partial metadata honest")
        EH.filters[facet] = "all"
    end
end
Check(count == 1657, "The imported dataset includes every classified item from the reviewed revision")
local chair = EH:MakeEntry(Decor(235523))
EH.entries, EH.byID = { chair, EH:MakeEntry(Decor(999999)) }, {}
EH:Show(); Drain()
EH.entries = { chair, EH:MakeEntry(Decor(999999)) }; EH:ApplyFilters()
for _, facet in ipairs(EH.decorFacets) do
    Check(EH.filterControls[facet] ~= nil, "Each requested browsing facet has a native selector")
    local choices = EH:DecorTagChoices(facet)
    Check(choices.all and choices.unknown and choices[tostring(chair.decorTags[facet][1])], "Menus include available labels and unclassified records")
end
EH.filters.culture, EH.filters.material, EH.filters.color, EH.filters.room = "1", "1", "16", "10"
EH:ApplyFilters()
Check(#EH.results == 1 and EH.results[1] == chair, "Culture, material, color, and room selectors combine with AND logic")
EH.filters.material = "23"; EH:ApplyFilters()
Check(#EH.results == 0, "A known mismatching material is excluded")
EH:ResetFilters(); EH:SetFilter("color", "unknown")
Check(#EH.results == 1 and EH.results[1].info.itemID == 999999, "Unclassified item browsing is explicit and supported")
EH:ResetFilters(); EH.filters.search = 'culture:human material:"rough wood" color:brown room:tavern'; EH:ApplyFilters()
Check(#EH.results == 1 and EH.results[1] == chair, "All four facet names support field-specific text searches")
EH:ResetFilters(); EH:SetFilter("room", "10"); EH:SavePreset("Tavern")
EH:SetFilter("room", "3"); EH:LoadPreset("Tavern")
Check(EH.filters.room == "10", "Classification filters persist in independent saved presets")
EH:ResetFilters()
Check(EH.filters.culture == "all" and EH.filters.material == "all" and EH.filters.color == "all" and EH.filters.room == "all",
    "Reset restores all four selectors without removing favorites or presets")
for _, font in ipairs({ 13, 20, 28 }) do
    ElvUI[1].db.general.fontSize = font
    ElvUI[1]:UpdateFontTemplates(); EH:RenderFilters()
    local lastEnd = 0
    for _, control in ipairs(EH.filterLayout) do
        if control.title then
            local y = -control.title.points[1][3]
            Check(y >= lastEnd, "Native-font sidebar labels do not overlap preceding buttons")
            lastEnd = y + control.title:GetStringHeight()
        end
        local y = -control.button.points[1][3]
        Check(y >= lastEnd and control.button:GetHeight() >= font, "Sidebar controls remain legible after native font changes")
        lastEnd = y + control.button:GetHeight()
    end
    local bottom = -EH.filterHelp.points[1][3] + EH.filterHelp:GetStringHeight()
    Check(bottom <= EH.filterContent:GetHeight(), "Scrolling sidebar keeps every filter and help line reachable")
end
