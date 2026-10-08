local _, EH = ...
local ownershipFields = { "totalNumStored", "totalNumPlaced", "remainingRedeemable" }
local refreshEvents = {
    MERCHANT_SHOW = true, MERCHANT_UPDATE = true, GET_ITEM_INFO_RECEIVED = true,
    BAG_UPDATE_DELAYED = true, HOUSING_STORAGE_UPDATED = true, HOUSING_STORAGE_ENTRY_UPDATED = true,
    HOUSING_NUM_DECOR_PLACED_CHANGED = true, HOUSING_CATALOG_CATEGORY_UPDATED = true,
    HOUSING_CATALOG_SUBCATEGORY_UPDATED = true,
}

-- Accept only public, finite, positive integers from item IDs, button IDs, and counts.
local function PositiveInteger(value)
    return EH:Readable(value) and type(value) == "number" and value > 0
        and value < math.huge and value % 1 == 0
end

-- Read current account ownership directly, including stored, placed, and unredeemed decor.
function EH:OwnsMerchantDecor(itemID)
    if not PositiveInteger(itemID) then return false end
    local info = self:Call(C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem, itemID)
    if type(info) ~= "table" or not self:Readable(info.entryType)
        or info.entryType ~= Enum.HousingCatalogEntryType.Decor then return false end
    for _, field in ipairs(ownershipFields) do
        if PositiveInteger(info[field]) then return true end
    end
    return false
end

-- Remove stale marks before native merchant buttons are reused, hidden, or disabled.
function EH:HideMerchantChecks()
    for _, check in pairs(self.merchantChecks or {}) do check:Hide() end
end

-- Overlay the icon without changing its tint, input handlers, or purchase behavior.
function EH:MerchantCheck(button)
    self.merchantChecks = self.merchantChecks or {}
    local check = self.merchantChecks[button]
    if not check then
        check = button:CreateTexture(nil, "OVERLAY", nil, 7)
        check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        check:SetSize(18, 18)
        check:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
        self.merchantChecks[button] = check
    end
    return check
end

-- Follow the native button's current item index, including WindTools' additional slots.
function EH:UpdateMerchantChecks()
    self:HideMerchantChecks()
    local frame, slots = _G.MerchantFrame, _G.MERCHANT_ITEMS_PER_PAGE
    if not self.db or not self.db.settings.merchantOwnedChecks or self.merchantOpen == false
        or not frame or not frame:IsVisible()
        or not self:Readable(frame.selectedTab) or frame.selectedTab ~= 1 or not PositiveInteger(slots) then return end
    local count = self:Call(GetMerchantNumItems)
    if not PositiveInteger(count) then return end
    for slot = 1, math.min(slots, 1000) do
        local button = _G["MerchantItem" .. slot .. "ItemButton"]
        if button and button:IsVisible() and self:Readable(button.hasItem) and button.hasItem then
            local index = self:Call(button.GetID, button)
            if PositiveInteger(index) and index <= count then
                local itemID = self:Call(GetMerchantItemID, index)
                if self:OwnsMerchantDecor(itemID) then self:MerchantCheck(button):Show() end
            end
        end
    end
end

-- Wait for Blizzard and optional skins to finish rebuilding the current merchant page.
function EH:ScheduleMerchantChecks()
    local frame = _G.MerchantFrame
    if self.merchantChecksPending or not self.db or not self.db.settings.merchantOwnedChecks
        or not frame or not frame:IsVisible() then return end
    self.merchantChecksPending = true
    -- Recheck visibility and preferences when deferred ownership data becomes available.
    C_Timer.After(0, function()
        self.merchantChecksPending = nil
        self:UpdateMerchantChecks()
    end)
end

-- Securely observe merchant rendering, including UI files loaded after login.
function EH:HookMerchantChecks()
    self.merchantCheckHooks = self.merchantCheckHooks or {}
    for _, name in ipairs({ "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" }) do
        if not self.merchantCheckHooks[name] and type(_G[name]) == "function" then
            self.merchantCheckHooks[name] = true
            if name == "MerchantFrame_UpdateBuybackInfo" then
                -- Buyback indices belong to a different inventory; never reuse vendor marks there.
                hooksecurefunc(name, function() self:HideMerchantChecks() end)
            else
                -- Pages and class filters update the button IDs before this post-hook runs.
                hooksecurefunc(name, function() self:UpdateMerchantChecks() end)
            end
        end
    end
    local frame = _G.MerchantFrame
    if frame and self.merchantCheckFrame ~= frame then
        self.merchantCheckFrame = frame
        -- Closing the merchant clears overlays even when no merchant event is dispatched.
        frame:HookScript("OnHide", function() self:HideMerchantChecks() end)
    end
end

-- Keep vendor marks fresh even while ElementHousing's own window has never been opened.
function EH:MerchantCheckEvent(event)
    if event == "ADDON_LOADED" or event == "MERCHANT_SHOW" then self:HookMerchantChecks() end
    if event == "MERCHANT_CLOSED" then self:HideMerchantChecks(); return end
    if refreshEvents[event] then self:ScheduleMerchantChecks() end
end
