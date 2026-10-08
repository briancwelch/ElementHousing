-- Exercise native merchant button reuse, account ownership, and expanded optional layouts.
EH:Initialize()
Check(EH.db.settings.merchantOwnedChecks == true and EH.frame == nil, "Vendor checks default on without opening the addon")
local saved = { settings = { merchantOwnedChecks = false } }
EH:Defaults(saved, EH.defaults)
Check(saved.settings.merchantOwnedChecks == false, "An existing disabled preference survives default migration")
Check(EH.events.events.ADDON_LOADED, "Late merchant UI loads can install their secure hooks")

local itemQueries, ownershipQueries, updates, purchases, buybacks = 0, 0, 0, 0, 0
local byItem, merchandise = {}, {}
local nativeItemID = GetMerchantItemID
-- Count vendor lookups separately to verify disabled and closed views do no ownership work.
GetMerchantItemID = function(index) itemQueries = itemQueries + 1; return nativeItemID(index) end
-- Model pending, unavailable, and restricted catalog replies without depending on our own catalog.
C_HousingCatalog.GetCatalogEntryInfoByItem = function(id)
    ownershipQueries = ownershipQueries + 1
    if byItem[id] == "ERROR" then error("Pending catalog data") end
    return byItem[id]
end
-- Send the actual registered addon event handler a documented notification.
local function Event(event) EH.events.scripts.OnEvent(EH.events, event) end
-- Build a public catalog entry independently of the housing window's cached entries.
local function Decor(stored, placed, redeemable, kind)
    return { entryType = kind or Enum.HousingCatalogEntryType.Decor,
        totalNumStored = stored, totalNumPlaced = placed, remainingRedeemable = redeemable }
end
-- Use Blizzard's actual slot naming and merchant-index contract for every visible button.
local function Expand(slots)
    MERCHANT_ITEMS_PER_PAGE = slots
    for slot = 1, slots do
        local name = "MerchantItem" .. slot .. "ItemButton"
        if not _G[name] then
            local button = CreateFrame("Button", name, MerchantFrame)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetTexture(123); button.icon:SetVertexColor(.4, .7, .9, 1)
            -- A retained native purchase handler proves the overlay never replaces input.
            button:SetScript("OnClick", function() purchases = purchases + 1 end)
        end
    end
end
-- Render the current page exactly as Blizzard assigns hasItem, visibility, and absolute IDs.
local function Render()
    updates = updates + 1
    for slot = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. slot .. "ItemButton"]
        local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + slot
        button.hasItem = merchantItems[index] ~= nil
        if button.hasItem then button:SetID(index) end
        button:SetShown(button.hasItem)
    end
    return "native merchant result"
end
-- Report the marker on a reused slot; absent textures count as unmarked.
local function Marked(slot)
    local check = EH.merchantChecks and EH.merchantChecks[_G["MerchantItem" .. slot .. "ItemButton"]]
    return check and check:IsVisible() or false
end
-- Populate enough distinct owned/unowned items for multiple standard and extended pages.
for index = 1, 137 do
    local id = 900000 + index
    merchandise[index] = { itemID = id, price = 10000, stackCount = 1 }
    byItem[id] = index % 2 == 1 and Decor(1, 0, 0) or Decor(0, 0, 0)
end
merchantItems = merchandise
MerchantFrame = CreateFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame.selectedTab, MerchantFrame.page = 1, 1
MerchantFrame_UpdateMerchantInfo = Render
-- Native buyback uses a separate inventory and must never inherit vendor checks.
MerchantFrame_UpdateBuybackInfo = function() buybacks = buybacks + 1; return "native buyback result" end
Expand(10)
Event("ADDON_LOADED")
local hook, hideHook = MerchantFrame_UpdateMerchantInfo, MerchantFrame.scripts.OnHide
Event("ADDON_LOADED"); EH:HookMerchantChecks()
Check(MerchantFrame_UpdateMerchantInfo == hook and MerchantFrame.scripts.OnHide == hideHook, "Repeated load notifications do not duplicate hooks")
Check(MerchantFrame_UpdateMerchantInfo() == "native merchant result" and updates == 1, "Post-hook preserves native execution and return value")
for slot = 1, 10 do Check(Marked(slot) == (slot % 2 == 1), "Standard vendor slots reflect native ownership") end
Check(EH.frame == nil and #EH.entries == 0, "Vendor ownership does not require our catalog to be loaded")
local first = MerchantItem1ItemButton
local check = EH.merchantChecks[first]
Check(check.parent == first and check.texture == "Interface\\RaidFrame\\ReadyCheck-Ready", "A native green ready-check texture belongs to the item button")
Check(check.width == 18 and check.points[1][1] == "TOPRIGHT", "Corner overlay leaves price and stack count visible")
local click = first.scripts.OnClick
first.scripts.OnClick(first)
Check(purchases == 1 and click == first.scripts.OnClick and first.icon.color[1] == .4 and first.icon.texture == 123,
    "Checkmarks preserve purchase handlers and optional icon tints")

-- Check every slot across standard, screenshot-sized, and larger WindTools pages.
for _, slots in ipairs({ 10, 30, 60 }) do
    Expand(slots)
    for page = 1, math.ceil(#merchandise / slots) do
        MerchantFrame.page = page
        MerchantFrame_UpdateMerchantInfo()
        for slot = 1, slots do
            local index = (page - 1) * slots + slot
            Check(Marked(slot) == (index <= #merchandise and index % 2 == 1), "Recycled vendor buttons use current absolute IDs on every page")
        end
    end
end
Expand(10); MerchantFrame.page = 1; MerchantFrame_UpdateMerchantInfo()
for slot = 11, 60 do Check(not Marked(slot), "Shrinking optional pages clears marks on extra pooled slots") end

-- Current native ownership includes every supported positive count, not only storage.
for _, owned in ipairs({ Decor(1, 0, 0), Decor(0, 1, 0), Decor(0, 0, 1), Decor(2, 3, 4), Decor("SECRET", 1, nil) }) do
    byItem[900001] = owned; MerchantFrame_UpdateMerchantInfo()
    Check(Marked(1), "Stored, placed, and unredeemed copies each count as account ownership")
end
for _, unavailable in ipairs({ Decor(0, 0, 0), Decor(nil, nil, nil), Decor(-1, 0, 0), Decor(.5, 0, 0),
    Decor(math.huge, 0, 0), Decor(0 / 0, 0, 0), Decor("SECRET", "SECRET", "SECRET"),
    Decor(1, 0, 0, 99), Decor(1, 0, 0, "SECRET"), "SECRET", "ERROR", false }) do
    byItem[900001] = unavailable; MerchantFrame_UpdateMerchantInfo()
    Check(not Marked(1), "Unowned, non-decor, invalid, restricted, and pending items cannot receive stale marks")
end
byItem[900001] = nil; MerchantFrame_UpdateMerchantInfo()
Check(not Marked(1), "Ordinary merchant items outside the housing catalog remain unmarked")
for _, id in ipairs({ 0, -1, .5, math.huge, "SECRET", 10000 }) do
    MerchantItem3ItemButton.id = id; EH:UpdateMerchantChecks()
    Check(not Marked(3), "Invalid, restricted, and out-of-inventory button indices clear stale marks")
end
MerchantFrame_UpdateMerchantInfo()
local catalogAPI = C_HousingCatalog.GetCatalogEntryInfoByItem
C_HousingCatalog.GetCatalogEntryInfoByItem = nil; MerchantFrame_UpdateMerchantInfo()
Check(not Marked(3), "An unavailable native catalog getter fails open")
C_HousingCatalog.GetCatalogEntryInfoByItem = catalogAPI
for _, id in ipairs({ 0, -1, .5, math.huge, "SECRET", false, "900001" }) do
    local before = ownershipQueries
    Check(not EH:OwnsMerchantDecor(id) and before == ownershipQueries, "Invalid or restricted item IDs never reach housing getters")
end

-- Purchases and storage/placement updates work with the ElementHousing window closed.
MerchantFrame.page = 1; byItem[900001] = Decor(0, 0, 0); MerchantFrame_UpdateMerchantInfo()
local timersBefore = #timers
byItem[900001] = Decor(1, 0, 0)
Event("HOUSING_STORAGE_ENTRY_UPDATED"); Event("HOUSING_STORAGE_UPDATED"); Event("BAG_UPDATE_DELAYED")
Check(#timers == timersBefore + 1 and not Marked(1), "A purchase burst coalesces while waiting for ownership replies")
Drain()
Check(Marked(1) and EH.frame == nil, "Purchased decor receives its check without opening the addon")
for _, event in ipairs({ "HOUSING_NUM_DECOR_PLACED_CHANGED", "GET_ITEM_INFO_RECEIVED", "HOUSING_CATALOG_CATEGORY_UPDATED",
    "HOUSING_CATALOG_SUBCATEGORY_UPDATED", "MERCHANT_UPDATE" }) do
    byItem[900001] = Decor(0, 0, 0); Event(event); Drain()
    Check(not Marked(1), "Ownership notifications clear stale marks")
    byItem[900001] = Decor(0, 2, 0); Event(event); Drain()
    Check(Marked(1), "Ownership notifications restore known placed-only decor marks")
end

-- Class filters replace the native inventory; old slot contents must not survive.
merchantItems = { merchandise[2], merchandise[1], merchandise[4] }
MerchantFrame_UpdateMerchantInfo()
Check(not Marked(1) and Marked(2) and not Marked(3) and not Marked(5), "Changing vendor filters updates reordered and empty buttons")
first.hasItem = false; EH:UpdateMerchantChecks()
Check(not Marked(1), "Empty recycled buttons ignore stale native IDs")
merchantItems = merchandise; MerchantFrame_UpdateMerchantInfo()
local option = EH.options.args.waypoints.args.merchantOwnedChecks
Check(option.get() == true, "Native ElvUI Vendors option exposes the enabled preference")
option.set(nil, false)
Check(not Marked(1) and not Marked(3) and option.get() == false, "Disabling the native option removes checks immediately")
local before = itemQueries
MerchantFrame_UpdateMerchantInfo(); Event("HOUSING_STORAGE_UPDATED"); Drain()
Check(itemQueries == before, "Disabled vendor checks do not query item or housing ownership")
option.set(nil, true)
Check(Marked(1) and Marked(3), "Enabling the native option immediately restores visible ownership marks")
local allocated = #frames
for pass = 1, 20 do MerchantFrame_UpdateMerchantInfo() end
Check(#frames == allocated and EH.merchantChecks[first] == check, "Repeated page rendering reuses overlay textures")

MerchantFrame.selectedTab = 2
Check(MerchantFrame_UpdateBuybackInfo() == "native buyback result" and buybacks == 1, "Buyback retains native execution and return value")
for slot = 1, 60 do Check(not Marked(slot), "Buyback cannot display a check from vendor inventory") end
Event("HOUSING_STORAGE_UPDATED"); Drain()
Check(not Marked(1), "Deferred ownership refreshes cannot restore vendor marks on buyback")
MerchantFrame.selectedTab = 1; MerchantFrame_UpdateMerchantInfo()
Check(Marked(1), "Returning from buyback restores vendor marks")
combat = true; MerchantFrame_UpdateMerchantInfo()
Check(Marked(1) and first.scripts.OnClick == click, "Cosmetic ownership refreshes do not replace protected purchase controls")
combat = false
Event("HOUSING_STORAGE_UPDATED"); Event("MERCHANT_CLOSED"); Drain()
Check(not check:IsShown(), "A queued update cannot restore marks after close before the native frame hides")
MerchantFrame:Hide()
before = ownershipQueries
Event("HOUSING_STORAGE_UPDATED"); Event("GET_ITEM_INFO_RECEIVED"); Drain()
Check(not check:IsShown() and ownershipQueries == before, "Closed vendors clear overlays and perform no ownership work")
MerchantFrame:Show(); MerchantFrame_UpdateMerchantInfo(); Event("MERCHANT_SHOW"); Drain()
Check(Marked(1), "Opening another vendor refreshes current ownership")
MerchantFrame:Hide()
Check(not check:IsShown(), "Native merchant hiding clears checks without relying on close events")
