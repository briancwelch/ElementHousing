local _, EH = ...
local E = ElvUI[1]
local icons = {
    collection = true, book = true, shop = true, teleports = true, achievement = true,
    professions = true, dungeon = true, quest = true, general = true, colors = true,
    refresh = true, heart = true, menu = true, tags = true, browser = true, help = true,
}
EH.brandIcon = "Interface\\AddOns\\ElementHousing\\Media\\Icon.tga"

-- Prefer optional nMediaTag control glyphs; keep every fallback inside ElementHousing.
function EH:Icon(name)
    if name ~= "housing" and not icons[name] then return self.brandIcon end
    if C_AddOns.IsAddOnLoaded("ElvUI_mMediaTag") then
        return "Interface\\AddOns\\ElvUI_mMediaTag\\media\\options\\" .. name .. ".tga"
    end
    return name == "housing" and self.brandIcon or "Interface\\AddOns\\ElementHousing\\Media\\Icons\\" .. name .. ".tga"
end

-- Produce the Mage-blue to Warlock-purple label used by the launcher and ElvUI header.
function EH:Brand()
    local name, parts = "ElementHousing", {}
    for i = 1, #name do
        local t = (i - 1) / (#name - 1)
        parts[#parts + 1] = string.format("|cff%02x%02x%02x%s|r", math.floor(63 + 72 * t),
            math.floor(199 - 64 * t), math.floor(235 + 2 * t), name:sub(i, i))
    end
    return table.concat(parts)
end

-- Build a small texture tag for labels in ElvUI's options tree.
function EH:IconLabel(icon, label)
    return "|T" .. self:Icon(icon) .. ":14:14:0:0|t " .. label
end

-- Use native ElvUI templates and optional WindTools shadows on addon-owned windows.
function EH:Skin(frame, inset, shadow)
    frame:SetTemplate(inset and "Transparent" or "Default")
    if not shadow or not C_AddOns.IsAddOnLoaded("ElvUI_WindTools") then return end
    local wind = WindTools and WindTools[1]
    local skins = wind and wind.Modules and wind.Modules.Skins
    local settings = E.private.WT and E.private.WT.skins
    if skins and skins.CreateShadow and settings and settings.enable and settings.shadow then
        skins:CreateShadow(frame)
    end
end

-- Register labels with ElvUI so its font, size, and outline settings stay authoritative.
function EH:Label(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:FontTemplate()
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    return label
end

-- Create flat controls with native ElvUI hover styling and optional control artwork.
function EH:Button(parent, text, width, click, icon)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    self:Skin(button)
    button:SetSize(width or 100, 26)
    button.text = self:Label(button, text)
    button.text:SetPoint("CENTER", icon and 8 or 0, 0)
    if icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16); button.icon:SetPoint("LEFT", 6, 0)
        button.icon:SetTexture(self:Icon(icon))
    end
    button:StyleButton(nil, true, true)
    button:SetScript("OnClick", click)
    return button
end

-- Register input fonts with ElvUI while retaining native editing and focus behavior.
function EH:Edit(parent, width, changed)
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    self:Skin(edit, true)
    edit:FontTemplate()
    edit:SetSize(width, 26); edit:SetAutoFocus(false); edit:SetMaxLetters(1024)
    edit:SetTextInsets(7, 7, 0, 0)
    -- Escape releases input focus before the containing window is dismissed.
    edit:SetScript("OnEscapePressed", function(widget) widget:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(widget) widget:ClearFocus() end)
    if changed then edit:SetScript("OnTextChanged", changed) end
    return edit
end

-- Refresh only addon-owned media colors after ElvUI updates its configured palette.
function EH:UpdateMedia()
    local color = E.media.rgbvaluecolor
    if self.scrollbar then self.scrollbar:GetThumbTexture():SetVertexColor(color[1], color[2], color[3]) end
    if self.blueprintProgress then self.blueprintProgress:SetStatusBarColor(color[1], color[2], color[3]) end
    if self.listBody then self:RenderList() end
    if self.frame then self:RenderTabs(); self:RenderHousingInfo() end
end

-- Let ElvUI's native registries update fonts, templates, and status bars as settings change.
function EH:RegisterMedia()
    if self.mediaRegistered then return end
    self.mediaRegistered = true
    -- Apply palette changes to the two accent controls without changing ElvUI settings.
    hooksecurefunc(E, "UpdateMedia", function() self:UpdateMedia() end)
    -- Reflow rows when ElvUI changes font size, and geometry after its UI-scale adjustment.
    hooksecurefunc(E, "UpdateFontTemplates", function() self:LayoutWindow() end)
    hooksecurefunc(E, "UIScale", function() self:ApplyWindowSettings(); self:LayoutWindow() end)
end
