-- Exercise data identities, native ownership, crafting totals, and both optional integrations.
EH:Initialize()
Check(#EH.collectionSets == 42, "Bundle 42 suggested collection and theme sets")
local recipes, items = 0, {}
for id, recipe in pairs(EH.housingRecipes) do
    recipes = recipes + 1
    Check(id > 1000000 and not items[recipe.itemID], "Recipe spell IDs and unique outputs come from source fields")
    items[recipe.itemID] = true
    Check(EH.professionNames[recipe.professionID] and #recipe.reagents > 0, "Every bundled recipe has a known profession and requirements")
    for _, reagent in ipairs(recipe.reagents) do
        Check(reagent.itemID > 0 and reagent.quantity > 0 and reagent.quantity % 1 == 0, "Bundled reagents are explicit positive per-craft quantities")
    end
end
Check(recipes == 325 and EH.housingRecipes[1262829].itemID == 257100 and not EH.housingRecipes[56269], "Import actual recipe spell ID, never upstream table key")
for _, set in ipairs(EH.collectionSets) do
    local seen = {}
    for _, id in ipairs(set.items) do Check(id > 0 and not seen[id], "Suggested set membership uses unique item IDs"); seen[id] = true end
end

-- Supply current localized item metadata and exact public inventory/recipe signatures.
local names = { [262599] = "Silvermoon Curtains", [262352] = "Lush Telogrus Carpet", [262591] = "Lounge Cushion",
    [7001] = "Shared Lumber", [7002] = "Cloth", [7003] = "Cloth", [7004] = "Unknown component" }
local inventory, prices, nativeRecipes, schematics, tracked = {}, {}, {}, {}, {}
local exported, exportCalls, trackCalls, opened = nil, 0, 0, nil
C_Item.GetItemNameByID = function(id) return names[id] end
C_Item.GetItemIconByID = function() return 123 end
C_Item.GetItemCount = function(id, bank, uses, reagentBank, accountBank)
    Check(uses == false and bank == reagentBank and bank == accountBank, "Native item count flags use the selected complete bank scope")
    return inventory[id]
end
C_TradeSkillUI.GetRecipeInfo = function(id) return nativeRecipes[id] end
C_TradeSkillUI.GetRecipeSchematic = function(id, recraft)
    Check(recraft == false, "Housing crafting uses regular recipe schematics")
    return schematics[id]
end
C_TradeSkillUI.IsRecipeTracked = function(id, recraft) Check(recraft == false, "Tracking queries regular recipes"); return tracked[id] or false end
C_TradeSkillUI.SetRecipeTracked = function(id, enabled, recraft)
    Check(recraft == false and type(enabled) == "boolean", "Use documented SetRecipeTracked(recipeID, tracked, isRecraft)")
    trackCalls, tracked[id] = trackCalls + 1, enabled
end
C_TradeSkillUI.OpenRecipe = function(id) opened = id end
C_TradeSkillUI.GetItemReagentQualityByItemInfo = function(id) return id == 7003 and 2 or 0 end
local first, second = 1229000, 1229001
nativeRecipes[first], nativeRecipes[second] = { learned = true }, { learned = false }
EH.professions, EH.professionsKnown = { [197] = true }, true
Check(EH:RecipeState(first) == "learned" and EH:RecipeState(second) == "unlearned", "Learned state is current character data")
nativeRecipes[first].learned = "SECRET"
Check(EH:RecipeState(first) == "unknown", "Restricted learned state stays unknown")
nativeRecipes[first].learned = true
for _, name in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
    C_TradeSkillUI[name] = function() return true end
    Check(EH:RecipeState(first) == "unknown", "Linked, guild, and NPC recipe data never imply player ownership")
    C_TradeSkillUI[name] = function() return false end
end
-- Cover every supported profession independently, including gathering and secondary professions.
for root in pairs(EH.professionNames) do
    EH.professions = { [root] = true }
    for id, recipe in pairs(EH.housingRecipes) do
        nativeRecipes[id] = { learned = true }
        Check(EH:RecipeState(id) == (root == recipe.professionID and "learned" or "other"), "Known profession mismatches cannot become learned craft eligibility")
    end
end
EH.professions = { [197] = true }
nativeRecipes[second].learned = false
EH.db.craftPlan = { [first] = 10000, [second] = "2", [5] = 1, [1233132] = -1 }
EH:NormalizeCraftPlan()
Check(EH.db.craftPlan[first] == 999 and EH.db.craftPlan[second] == nil and EH.db.craftPlan[5] == nil, "Normalize saved quantities and discard unknown recipe identities")
EH.db.craftPlan = {}
Check(not EH:SetCraftCount(first, .5) and not EH:SetCraftCount(first, math.huge) and not EH:SetCraftCount(first, -1), "Reject fractional and invalid craft input")
Check(EH:SetCraftCount(first, 2) and EH:SetCraftCount(second, 3), "Plan exact numbers of crafts")
local fallback, source = EH:RecipeRequirements(first)
Check(source == "estimate" and fallback[1].itemID == 239702, "Keep bundled requirements explicitly estimated when native data is absent")

-- Current schematics supersede outdated bundles; alternative qualities require an explicit valid choice.
schematics[first] = { recipeID = first, quantityMin = 2, quantityMax = 2, reagentSlotSchematics = {
    { required = true, quantityRequired = 4, reagents = { { itemID = 7001 } }, variableQuantities = {} },
    { required = true, quantityRequired = 5, reagents = { { itemID = 7002 }, { itemID = 7003 } }, variableQuantities = {} },
    { required = false, quantityRequired = 20, reagents = { { itemID = 7004 } }, variableQuantities = {} },
} }
schematics[second] = { recipeID = second, quantityMin = 1, quantityMax = 1, reagentSlotSchematics = {
    { required = true, quantityRequired = 2, reagents = { { itemID = 7001 } }, variableQuantities = {} },
} }
local current, currentSource = EH:RecipeRequirements(first)
Check(currentSource == "native" and #current == 2 and current[1].itemID == 7001, "Native required slots replace bundled ingredients and omit optional materials")
Check(not EH:ChooseRecipeReagent(first, 2, 9999), "Reject a reagent outside the native permitted alternatives")
Check(EH:ChooseRecipeReagent(first, 2, 7003), "Persist an explicit permitted reagent quality")
inventory[7001], inventory[7003] = 9, 4
local shopping, summary = EH:CraftShoppingList()
local byID = {}; for _, row in ipairs(shopping) do byID[row.itemID] = row end
Check(#shopping == 2 and summary.crafts == 5 and summary.recipes == 2 and summary.estimates == 0, "Combine the entire plan using current native data")
Check(byID[7001].required == 14 and byID[7001].missing == 5, "Subtract shared lumber inventory once after aggregating both recipes")
Check(byID[7003].required == 10 and byID[7003].missing == 6 and not byID[7002], "Reagent totals honor selected quality and crafts rather than output yield")
Check(summary.unpriced == 2 and summary.cost == 0, "Absent Auctionator prices are unknown rather than free")

-- Replacing only this addon's named shopping list is the documented Auctionator v1 operation.
local function AuctionAPI()
    return { API = { v1 = {
        GetAuctionPriceByItemID = function(caller, id) Check(caller == "ElementHousing", "Auctionator API receives stable caller identity"); return prices[id] end,
        ConvertToSearchString = function(caller, term)
            Check(caller == "ElementHousing" and term.isExact == true, "Export exact localized item names through the public converter")
            return term.searchString .. ":" .. term.quantity .. ":" .. (term.tier or 0)
        end,
        CreateShoppingList = function(caller, name, terms)
            Check(caller == "ElementHousing" and name == "ElementHousing Reagents", "Export touches only the dedicated reagent list")
            exportCalls, exported = exportCalls + 1, terms
        end,
    } } }
end
for _, auction in ipairs({ false, true }) do
    for _, kaliel in ipairs({ false, true }) do
        Auctionator = auction and AuctionAPI() or nil
        KalielsTracker = kaliel and { Toggle = function() error("Private/custom tracker manipulation is not needed") end } or nil
        prices[7001], prices[7003] = 100, 200
        local _, totals = EH:CraftShoppingList()
        Check(totals.cost == (auction and 1700 or 0), "Cached missing-material estimates work with every optional integration combination")
        local before = trackCalls
        Check(EH:TrackHousingRecipe(first) and trackCalls == before + 1, "Blizzard recipe tracking works with and without Kaliel")
        Check(EH:TrackHousingRecipe(first) and not tracked[first], "Untracking affects only the clicked native recipe")
        before = exportCalls
        Check(EH:ExportCraftShoppingList() == auction and exportCalls == before + (auction and 1 or 0), "Export requires optional Auctionator and occurs only on explicit action")
        if auction then
            Check(exported[1] == "Cloth:6:2" and exported[2] == "Shared Lumber:5:0", "Export exact missing quantities and chosen reagent quality")
        end
    end
end
Auctionator = AuctionAPI()
local qualityGetter = C_TradeSkillUI.GetItemReagentQualityByItemInfo
C_TradeSkillUI.GetItemReagentQualityByItemInfo = function() return nil end
Check(not EH:ExportCraftShoppingList(), "Identically named alternatives require native quality data")
names[7002] = "Different unranked cloth"
Check(EH:ExportCraftShoppingList(), "Distinct unranked reagent alternatives export exact item names without inventing quality")
names[7002] = "Cloth"; C_TradeSkillUI.GetItemReagentQualityByItemInfo = qualityGetter
local before = exportCalls
inventory[7001] = "SECRET"
Check(not EH:ExportCraftShoppingList() and exportCalls == before, "Unknown/restricted inventory cannot export an inflated quantity")
inventory[7001] = 9; names[7003] = nil
Check(not EH:ExportCraftShoppingList() and exportCalls == before, "Wait for localized names instead of exporting English guesses")
names[7003] = "Cloth"
local normal = schematics[first].reagentSlotSchematics[1].quantityRequired
schematics[first].reagentSlotSchematics[1].quantityRequired = "SECRET"
local rows, blocked = EH:RecipeRequirements(first)
Check(blocked == "incomplete" and #rows == 0, "Restricted native requirements cannot fall back to stale estimates")
Check(not EH:ExportCraftShoppingList() and exportCalls == before, "Incomplete native requirements block incomplete shopping exports")
schematics[first].reagentSlotSchematics[1].quantityRequired = normal
combat = true
local trackedBefore = trackCalls
Check(not EH:TrackHousingRecipe(first) and trackCalls == trackedBefore, "No native recipe mutation during combat")
Check(not EH:ExportCraftShoppingList() and exportCalls == before, "No Auctionator list mutation during combat")
combat = false
Check(not EH:TrackHousingRecipe(second) and trackCalls == trackedBefore, "Unlearned recipes cannot be tracked as learned")
Check(EH:OpenHousingRecipe(first) and opened == first, "Open a recipe through the native profession API")
-- Currency requirements stay visible; native variable quantities block misleading exports.
schematics[second].reagentSlotSchematics[2] = { required = true, quantityRequired = 7,
    reagents = { { currencyID = 88 } }, variableQuantities = {} }
currencyInfo[88] = { name = "Sample Currency", quantity = 5 }
local withCurrency = EH:CraftShoppingList()
local currencyRow
for _, row in ipairs(withCurrency) do if row.currencyID == 88 then currencyRow = row end end
Check(currencyRow and currencyRow.required == 21 and currencyRow.missing == 16 and currencyRow.price == nil,
    "Currency reagents aggregate current requirements and remain unpriced")
Check(EH:ExportCraftShoppingList(), "Currency requirements remain visible without becoming auction shopping terms")
schematics[second].reagentSlotSchematics[2] = nil
schematics[first].reagentSlotSchematics[1].variableQuantities = { { quantity = 9 } }
Check(select(2, EH:RecipeRequirements(first)) == "incomplete", "Native variable quantity slots cannot become fabricated fixed totals")
schematics[first].reagentSlotSchematics[1].variableQuantities = {}

-- Collection progress includes placed and redeemable ownership, and distinguishes unavailable items.
EH.collectionSets[#EH.collectionSets + 1] = { key = "test-set", name = "Test Theme", description = "Native test membership", kind = "theme", items = { 262599, 262352, 262591 } }
catalog = {
    { recordID = 1, entryType = 1, itemID = 262599, name = names[262599], sourceText = "", totalNumStored = 0, totalNumPlaced = 1, remainingRedeemable = 0 },
    { recordID = 2, entryType = 1, itemID = 262352, name = names[262352], sourceText = "", totalNumStored = 0, totalNumPlaced = 0, remainingRedeemable = 0 },
}
Check(EH:Show("collections"), "Open the native collection workspace")
Drain()
local set, checklist, counts = EH:CollectionChecklist("test-set")
Check(counts.owned == 1 and counts.missing == 1 and counts.unavailable == 1, "Known ownership and absent catalog records remain separate")
EH:SetFilter("search", "nothing matches"); EH:IndexCollections()
Check(#EH.results == 0 and select(3, EH:CollectionChecklist("test-set")).owned == 1, "Catalog browse filters never alter a themed checklist's ownership")
EH.db.craftPlan = { [second] = 4 }
EH:PlanCollection("test-set")
Check(EH.db.craftPlan[second] == 4 and not EH.db.craftPlan[first] and not EH.db.craftPlan[1229002], "Planning missing decorations preserves existing crafts and excludes owned or unavailable items")
EH.projects.setKey, EH.projects.mode, EH.projects.missingOnly = "test-set", "sets", false
EH:RenderProjects()
Check(#EH.projects.data == 3 and EH.projects.progress.value == .5, "Set progress measures known native catalog item types")
EH.projects.missingOnly = true; EH:RenderProjects()
Check(#EH.projects.data == 1 and EH.projects.data[1].status == "missing", "Missing-only view excludes unavailable catalog items")
EH.projects.mode, EH.projects.missingOnly, EH.projects.profession = "recipes", true, "all"; EH:RenderProjects()
Check(#EH.projects.data == 1 and EH.projects.data[1].recipeID == second, "Planned recipe filter remains independent of collection filters")
EH:SetProjectMode("reagents")
Check(#EH.projects.data == 1 and EH.projects.data[1].required == 8, "Reagent workspace renders current plan totals")
local frameCount = #frames
EH:RenderProjects(); EH:RenderProjects()
Check(#frames == frameCount, "Repeat project renders reuse their visible row pool")
for _, font in ipairs({ 13, 20, 28 }) do
    ElvUI[1].db.general.fontSize = font; ElvUI[1]:UpdateFontTemplates()
    EH.frame:SetSize(760, 480); EH:LayoutWindow()
    Check(EH.projects.panel:GetHeight() >= EH.projects.body:GetHeight() + EH.projects.body.points[1][5] * -1,
        "Small windows and large native fonts retain full scrolling content")
    Check(EH.projects.body:GetHeight() >= (font * 2 + 26) * 3, "At least three readable native-font rows remain accessible")
    local last = EH.collectionsTab.points[1]
    Check(last[2] + EH.collectionsTab:GetWidth() <= EH.frame:GetWidth() - 12, "Wrapped navigation remains within the window")
end
EH.projects.mode = "recipes"; EH.projects.profession = "mine"; EH.projects.missingOnly = false
EH.projects.search:SetText("Silvermoon Curtains"); EH:RenderProjects()
Check(#EH.projects.data == 1 and EH.projects.data[1].recipeID == first, "Native recipe names and current profession selections combine")
for _, row in ipairs(checklist) do if row.itemID == 262599 then EH:InspectCollectionItem(row) end end
Check(EH.view == "catalog" and EH.selected ~= nil, "Checklist clicks open native catalog details")
EH.projects.profession, EH.projects.missingOnly = "mine", true
EH.waypointButton.scripts.OnClick()
Check(EH.view == "collections" and EH.projects.profession == "all" and not EH.projects.missingOnly and #EH.projects.data == 1,
    "Catalog recipe action exposes its clicked recipe despite earlier profession/plan filters")
SlashCmdList.ELEMENTHOUSING("reagents")
Check(EH.view == "collections" and EH.projects.mode == "reagents", "Slash navigation opens the reagent view")
EH.events.scripts.OnEvent(EH.events, "BAG_UPDATE_DELAYED"); Drain()
Check(not EH.projectRefreshPending, "Inventory notifications coalesce and finish without catalog refresh loops")
