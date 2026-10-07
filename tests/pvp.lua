-- Validate acquisition-based PvP classification and actual combined filter controls.
EH:Initialize()
Check(EH:Show("catalog"), "PvP controls construct")
local categories = { [500] = { "Arena", 95 }, [95] = { "Player vs. Player", -1 },
    [600] = { "Legacy", 601 }, [601] = { "PvP", 81 }, [700] = { "Quests", -1 }, [800] = { "Cycle", 800 } }
local achievements = { [10] = 500, [11] = 600, [12] = 700, [13] = 800 }
GetAchievementCategory = function(id) return achievements[id] end
GetCategoryInfo = function(id) local row = categories[id]; if row then return unpack(row) end end
EH.tagGroups = { { tags = { { tagID = 20, tagName = "PvP" }, { tagID = 21, tagName = "PvE" } } } }
-- Build real catalog entries so observed currencies and target metadata are included.
local function Decor(id, source, tags, owned, name)
    return EH:MakeEntry({ recordID = id, entryType = 1, name = name or "Decor " .. id,
        sourceText = source, dataTagsByID = tags, totalNumStored = owned or 0 })
end
local cases = {
    { "PvP: Arena", true }, { "Player vs. Player reward", true }, { "Player versus Player reward", true },
    { "Achievement: |Hachievement:10|h[Arena champion]|h", true },
    { "Achievement: |Hachievement:11|h[Legacy champion]|h", true },
    { "Achievement: |Hachievement:12|h[Quest champion]|h", false },
    { "Achievement: |Hachievement:13|h[Broken category]|h", false },
    { "Vendor: |Hcurrency:1792|h[Honor]|h", true }, { "Vendor: |Hcurrency:1602|h[Conquest]|h", true },
    { "Vendor: |Hcurrency:2123|h[Bloody Tokens]|h", true }, { "Vendor: |Hitem:137642|h[Mark of Honor]|h", true },
    { "Vendor: |Hcurrency:2815|h[Resonance]|h", false }, { "Vendor: Honor Supplies", false },
    { "Quest: PvPish story", false }, { "Vendor: prepvp shop", false }, { "Unknown source", false },
    { "SECRET", false }, { "Vendor: Trader", true, { [20] = true } },
    { "Vendor: Trader", false, { [21] = true } }, { "Vendor: Trader", false, { [20] = false } },
    { "Vendor: Trader", false, { [20] = "SECRET" } }, { "Vendor: Trader", false, nil, "PvP Trophy" },
}
for i, case in ipairs(cases) do
    local entry = Decor(1000 + i, case[1], case[3], 0, case[4])
    Check(entry.isPvP == case[2], "Known PvP evidence classification " .. i)
    EH.filters.hidePvP = false
    Check(EH:Matches(entry, {}) == true, "Disabled PvP filter retains decor " .. i)
    EH.filters.hidePvP = true
    Check(EH:Matches(entry, {}) == not case[2], "Enabled PvP filter hides only known sources " .. i)
end
targets[2001] = { Enum.ContentTrackingTargetType.Achievement, 10 }
Check(Decor(2001, "Achievement: Arena champion").isPvP, "Native achievement targets classify without a link")
PVP = "Joueur contre joueur"
Check(Decor(2002, "Joueur contre joueur: Arène").isPvP, "Localized PvP source labels classify")
-- Use the exact persisted merchant shape consumed by ReadObservedSources.
EH.db.vendorSources[2003] = { Seller = { vendorName = "Seller", costs = { ["item:137642"] = 5 } } }
Check(Decor(2003, "Vendor: Seller").isPvP, "Visited merchant token costs classify PvP decor")
EH:ResetFilters()
EH.entries = { Decor(3001, "PvP: Arena", nil, 0), Decor(3002, "Vendor: Seller", nil, 0),
    Decor(3003, "Unknown source", nil, 0), Decor(3004, "PvP: Arena", nil, 1) }
EH.hidePvPButton.scripts.OnClick(EH.hidePvPButton)
Check(EH.filters.hidePvP and #EH.results == 2, "Actual toggle hides missing and owned PvP decor")
Check(EH.hidePvPButton.text:GetText() == "Enabled", "Toggle displays its current state")
EH:SetFilter("source", "vendor")
Check(#EH.results == 1 and EH.results[1].info.recordID == 3002, "PvP filtering combines with other selectors")
Check(EH:SavePreset("No PvP"), "PvP filter preset saves")
EH:ResetFilters()
Check(not EH.filters.hidePvP and #EH.results == 4, "Reset restores all decor")
EH:LoadPreset("No PvP")
Check(EH.filters.hidePvP and #EH.results == 1, "Saved preset restores the combined PvP filter")
EH:SetFilter("hidePvP", false)
Check(EH.db.presets["No PvP"].hidePvP, "Changing current filters preserves the saved preset")
EH.db.presets.Legacy = { source = "all" }
EH:LoadPreset("Legacy")
Check(EH.filters.hidePvP == false, "Older presets gain the disabled default")
GetAchievementCategory = nil; GetCategoryInfo = nil
Check(not Decor(3005, "Achievement: |Hachievement:10|h[Unknown]|h").isPvP, "Unavailable achievement data leaves decor visible")
