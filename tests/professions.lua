-- Exercise eligibility through native source normalization and changing character skills.
local names = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting",
    [202] = "Engineering", [182] = "Herbalism", [773] = "Inscription", [755] = "Jewelcrafting",
    [165] = "Leatherworking", [186] = "Mining", [393] = "Skinning", [197] = "Tailoring",
    [185] = "Cooking", [356] = "Fishing", [794] = "Archaeology" }
local primary = { 171, 164, 333, 202, 182, 773, 755, 165, 186, 393, 197 }
local secondary = { 794, 356, 185 }
local learned, skillInfo, recipeInfo, displayNames = {}, {}, {}, {}
GetProfessions = function()
    return learned[1] and 1, learned[2] and 2, learned[3] and 3, learned[4] and 4, learned[5] and 5
end
GetProfessionInfo = function(index)
    local id = learned[index]
    return displayNames[id] or names[id], nil, 1, 100, nil, nil, id
end
C_TradeSkillUI.GetTradeSkillDisplayName = function(id) return names[id] end
C_TradeSkillUI.GetProfessionInfoBySkillLineID = function(id) return skillInfo[id] or { professionID = id } end
C_TradeSkillUI.GetProfessionInfoByRecipeID = function(id) return recipeInfo[id] end
EH:Initialize()
Check(EH:Show("catalog"), "Profession shortcut window constructs")
EH.db.settings.includeUnknownProfession = false
EH.filters.ownership, EH.filters.profession = "missing", "mine"

-- Give every profession a separate missing decor record using native source text.
local function Decor(id, source, stored, placed, redeemable)
    return EH:MakeEntry({ recordID = id, entryType = 1, name = "Decor " .. id,
        sourceText = source, totalNumStored = stored or 0, totalNumPlaced = placed or 0,
        remainingRedeemable = redeemable or 0 })
end
for id, name in pairs(names) do
    EH.entries[#EH.entries + 1] = Decor(id, "Profession: " .. name)
    EH.entries[#EH.entries + 1] = Decor(id + 1000, "Profession: " .. name .. "\nVendor: Merchant")
end
EH.entries[#EH.entries + 1] = Decor(999, "Vendor: Merchant")
for _, entry in ipairs(EH.entries) do catalog[#catalog + 1] = entry.info end

-- Refresh the detected character and assert every profession's visibility in the catalog.
local function Character(slots, label)
    learned = slots
    EH.events.scripts.OnEvent(EH.events, "SKILL_LINES_CHANGED")
    Drain()
    local expected, visible = {}, {}
    for _, id in pairs(slots) do expected[id] = true end
    for _, entry in ipairs(EH.results) do visible[entry.info.recordID] = true end
    for id, name in pairs(names) do
        Check((visible[id] == true) == (expected[id] == true), label .. ": " .. name)
    end
    EH.professionShortcut.scripts.OnClick(EH.professionShortcut)
    Drain()
    Check(EH.filters.source == "profession" and EH.filters.profession == "mine" and EH.filters.ownership == "missing",
        label .. ": header shortcut selects missing profession decor")
    visible = {}
    for _, entry in ipairs(EH.results) do visible[entry.info.recordID] = true end
    Check(not visible[999], label .. ": ordinary vendor decor is excluded by the shortcut")
    for id, name in pairs(names) do
        Check((visible[id] == true) == (expected[id] == true), label .. ": shortcut profession " .. name)
        Check((visible[id + 1000] == true) == (expected[id] == true), label .. ": shortcut alternate vendor " .. name)
    end
    EH.filters.source = "all"
end
Character({}, "No professions")
for _, id in ipairs(primary) do
    Character({ id }, "One primary profession")
    Character({ [2] = id }, "One primary profession in the second slot")
end
for i, first in ipairs(primary) do
    for j = i + 1, #primary do Character({ first, primary[j] }, "Each primary profession pair") end
end
-- Cover every secondary subset, including holes before Fishing and Cooking.
for mask = 0, 7 do
    local slots = { 171, 197 }
    for i, id in ipairs(secondary) do if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then slots[i + 2] = id end end
    Character(slots, "Each secondary profession combination")
end
Character({ [4] = 356, [5] = 185 }, "Secondary professions without primary professions")
Character({ 333, 202 }, "Changing to enchanting and engineering")
Character({ 393, 165 }, "Changing to skinning and leatherworking")
Character({}, "Unlearning all professions removes the previous character's skills")

learned = { 171 }; EH:UpdateProfessions()
for id, name in pairs(names) do
    local entry = Decor(10000 + id, "Profession: " .. name)
    Check(EH:MatchesProfession(entry, tostring(id)), "Specific profession string selector: " .. name)
    Check(EH:MatchesProfession(entry, id), "Specific profession numeric selector: " .. name)
    Check(not EH:MatchesProfession(entry, "none"), "No profession-only decor: " .. name)
    Check(EH:MatchesProfession(entry, "all"), "Unrestricted browsing: " .. name)
    for _, owned in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }) do
        entry = Decor(20000 + id, "Profession: " .. name, unpack(owned))
        Check(EH:MatchesProfession(entry, "mine"), "Configured owned exemption: " .. name)
        EH.db.settings.professionMissingOnly = false
        Check(EH:MatchesProfession(entry, "mine") == (id == 171), "Restrictions on all owned states: " .. name)
        EH.db.settings.professionMissingOnly = true
    end
end
local entry = Decor(30000, "Profession: Alchemy\nProfession: Tailoring")
Check(EH:MatchesProfession(entry, "mine"), "Any matching known profession route is sufficient")
learned = { 333 }; EH:UpdateProfessions()
Check(not EH:MatchesProfession(entry, "mine"), "Multiple unrelated professions remain excluded")
for _, source in ipairs({ "Vendor: Merchant", "Drop: Encounter", "Achievement: Collector", "Quest: Reward" }) do
    entry = Decor(30001, "Profession: Alchemy\n" .. source)
    Check(EH:MatchesProfession(entry, "mine"), "Known alternative acquisition route: " .. source)
end
-- Location loading must never override a known profession mismatch.
locations[30002] = { status = Enum.ContentTrackingResult.DataPending }
EH.db.settings.includeUnknownProfession = true
entry = Decor(30002, "Profession: Tailoring")
Check(entry.pendingSource and not EH:MatchesProfession(entry, "mine"), "A pending waypoint does not make known eligibility unknown")

-- Use expansion skill lines on both the character and recipe, with canonical root names.
skillInfo[40001] = { professionID = 40001, parentProfessionID = 40002 }
skillInfo[40002] = { professionID = 40002, parentProfessionID = 202 }
displayNames[40001] = "Midnight Engineering"
learned = { 40001 }; EH:UpdateProfessions()
Check(EH.professions[202] and not EH.professions[40001] and not EH.professions[40002], "Expansion skills normalize to a base profession")
Check(EH.professionNames[202] == "Engineering", "Expansion skill names never replace canonical profession names")
entry = Decor(30003, "Profession: Engineering")
Check(EH:MatchesProfession(entry, "mine"), "Base profession text matches an expansion-skilled character")
recipeInfo[40003] = { professionID = 40001, parentProfessionID = 40002 }
targets[30004] = { Enum.ContentTrackingTargetType.Profession, 40003 }
entry = Decor(30004, "Profession: Unknown recipe")
Check(entry.professionIDs[202] and EH:MatchesProfession(entry, "mine"), "Native recipe targets use the same normalized profession")
Check(EH:MatchesProfession(entry, "40001"), "An expansion-specific selector resolves to its base profession")
-- Source recipe links must work even when their display text omits the profession name.
entry = Decor(30005, "Profession: |Hspell:40003|h[Clockwork Display]|h")
Check(entry.professionIDs[202] and EH:MatchesProfession(entry, "mine"), "Recipe hyperlinks resolve profession metadata")
recipeInfo[40004] = { professionID = 164 }
entry = Decor(30006, "Profession: |Hspell:40004|h[Iron Display]|h")
Check(entry.professionIDs[164] and not EH:MatchesProfession(entry, "mine"), "Unrelated recipe links are excluded even when unknowns are enabled")

entry = Decor(30007, "Profession: Unknown recipe")
Check(EH:MatchesProfession(entry, "mine"), "Unknown profession metadata follows the include policy")
Check(not EH:MatchesProfession(entry, "none"), "A known profession route is excluded by no-profession browsing even if its profession is unknown")
EH.db.settings.includeUnknownProfession = false
Check(not EH:MatchesProfession(entry, "mine"), "Unknown profession metadata can be excluded")
entry = Decor(30008, "Unclassified source")
Check(not EH:MatchesProfession(entry, "mine"), "Unclassified metadata follows the same exclude policy")
EH.db.settings.includeUnknownProfession = true
Check(EH:MatchesProfession(entry, "mine"), "Unclassified metadata can remain visible")
-- Do not mistake words containing a profession name for a profession requirement.
entry = Decor(30009, "Source: Undermining challenge")
Check(not next(entry.professionIDs), "Mining is not inferred from the unrelated word Undermining")

-- Every profession must normalize correctly through native expansion and recipe metadata.
for id, name in pairs(names) do
    local child, parent, recipe = id + 50000, id + 60000, id + 70000
    skillInfo[child] = { professionID = child, parentProfessionID = parent }
    skillInfo[parent] = { professionID = parent, parentProfessionID = id }
    displayNames[child] = "Midnight " .. name
    recipeInfo[recipe] = { professionID = child, parentProfessionID = parent }
    learned = { child }; EH.events.scripts.OnEvent(EH.events, "TRADE_SKILL_LIST_UPDATE")
    Check(EH.professions[id] and EH.professionNames[id] == name, "Canonical expansion profession: " .. name)
    local record = 80000 + id * 10
    entry = Decor(record, "Profession: " .. name)
    Check(EH:MatchesProfession(entry, "mine"), "Expansion character with base source text: " .. name)
    targets[record + 1] = { Enum.ContentTrackingTargetType.Profession, recipe }
    entry = Decor(record + 1, "Profession: Recipe")
    Check(entry.professionIDs[id] and EH:MatchesProfession(entry, "mine"), "Normalized native recipe target: " .. name)
    entry = Decor(record + 2, "Profession: |Hspell:" .. recipe .. "|h[Display]|h")
    Check(entry.professionIDs[id] and EH:MatchesProfession(entry, "mine"), "Normalized linked recipe: " .. name)
end
-- Future professions exposed by native IDs do not need a new hardcoded exclusion rule.
displayNames[90000], names[90000] = "New profession", "New profession"
learned = { 90000 }; EH:UpdateProfessions()
recipeInfo[90001] = { professionID = 90000 }
entry = Decor(90002, "Profession: |Hspell:90001|h[Display]|h")
Check(EH:MatchesProfession(entry, "mine"), "Previously unlisted native profession is supported")
learned = {}; EH:UpdateProfessions()
Check(not EH:MatchesProfession(entry, "mine"), "Unlearning a newly exposed profession changes eligibility")

-- Distinguish genuinely absent professions from a temporarily unreadable character skill set.
entry = Decor(90003, "Profession: Engineering")
local getter = GetProfessions
GetProfessions = nil; EH:UpdateProfessions()
Check(not EH.professionsKnown and EH:MatchesProfession(entry, "mine"), "Unavailable character metadata follows the include policy")
EH.db.settings.includeUnknownProfession = false
Check(not EH:MatchesProfession(entry, "mine"), "Unavailable character metadata follows the exclude policy")
GetProfessions = function() error("Pending character professions") end
EH.db.settings.includeUnknownProfession = true; EH:UpdateProfessions()
Check(not EH.professionsKnown and EH:MatchesProfession(entry, "mine"), "An optional getter failure cannot break the catalog")
GetProfessions = getter; EH:UpdateProfessions()
Check(EH.professionsKnown and not EH:MatchesProfession(entry, "mine"), "An empty readable skill set excludes known profession-only decor")
-- Invalid native recipe metadata remains unknown rather than introducing an invalid table key.
recipeInfo[90004] = { professionID = 0 }
entry = Decor(90005, "Profession: |Hspell:90004|h[Display]|h")
Check(not next(entry.professionIDs) and EH:MatchesProfession(entry, "mine"), "Invalid native profession IDs follow the unknown policy")

-- Localized names must identify every profession without relying on English special cases.
local localized = { [171] = "Alchemie", [164] = "Schmiedekunst", [333] = "Verzauberkunst",
    [202] = "Ingenieurskunst", [182] = "Kräuterkunde", [773] = "Inschriftenkunde", [755] = "Juwelierskunst",
    [165] = "Lederverarbeitung", [186] = "Bergbau", [393] = "Kürschnerei", [197] = "Schneiderei",
    [185] = "Kochen", [356] = "Angeln", [794] = "Archäologie" }
PROFESSIONS = "Berufe"
C_TradeSkillUI.GetTradeSkillDisplayName = function(id) return localized[id] or names[id] end
for id, name in pairs(localized) do
    learned = { id }; EH:UpdateProfessions()
    entry = Decor(100000 + id, "Berufe: " .. name)
    Check(entry.professionIDs[id] and EH:MatchesProfession(entry, "mine"), "Localized matching profession: " .. name)
    learned = { id == 171 and 333 or 171 }; EH:UpdateProfessions()
    Check(not EH:MatchesProfession(entry, "mine"), "Localized unrelated profession: " .. name)
end
