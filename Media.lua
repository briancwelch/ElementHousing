local _, EH = ...
local fallback = {
    housing = "INV_Misc_EngGizmos_31", collection = "INV_Misc_Book_09", book = "INV_Misc_Book_11",
    shop = "INV_Misc_Coin_01", teleports = "INV_Misc_Map_01", achievement = "Achievement_General",
    professions = "Trade_Engineering", dungeon = "INV_Misc_MonsterClaw_04", quest = "INV_Misc_Note_01",
    general = "INV_Gizmo_02", colors = "INV_Misc_Gem_Sapphire_02", refresh = "Spell_Nature_Rejuvenation",
    heart = "Spell_Holy_BlessingOfProtection", menu = "INV_Misc_QuestionMark", tags = "INV_Misc_Note_02",
    browser = "INV_Misc_Spyglass_03", help = "INV_Misc_QuestionMark",
}

-- Resolve the installed nMediaTag glyphs without copying its artwork or requiring its engine.
function EH:Icon(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded("ElvUI_mMediaTag") then
        return "Interface\\AddOns\\ElvUI_mMediaTag\\media\\options\\" .. name .. ".tga"
    end
    return "Interface\\Icons\\" .. (fallback[name] or fallback.housing)
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

-- Use the current ElvUI palette and font, with a single fixed native fallback.
function EH:Palette()
    local engine = ElvUI and ElvUI[1]
    local media = engine and engine.media
    return media and media.backdropcolor or { 0.08, 0.08, 0.10, 1 },
        media and media.bordercolor or { 0.22, 0.24, 0.28, 1 },
        media and media.normFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- Skin only ElementHousing frames using ElvUI templates where available.
function EH:Skin(frame, inset)
    local background, border = self:Palette()
    if frame.SetTemplate then frame:SetTemplate(inset and "Transparent" or "Default")
    else frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }) end
    frame:SetBackdropColor(background[1], background[2], background[3], inset and 0.55 or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end

-- Create a consistently sized label; preserve native item colors when supplying text.
function EH:Label(parent, text, size)
    local _, _, font = self:Palette()
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(font, size or self.db.settings.fontSize, "OUTLINE")
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    return label
end

-- Create flat text controls without invalid nil button-state texture setters.
function EH:Button(parent, text, width, click, icon)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    self:Skin(button)
    button:SetSize(width or 100, 26)
    button.text = self:Label(button, text, 12)
    button.text:SetPoint("CENTER", icon and 8 or 0, 0)
    if icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16); button.icon:SetPoint("LEFT", 6, 0)
        button.icon:SetTexture(self:Icon(icon))
    end
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(0.25, 0.65, 0.85, 0.16)
    button:SetScript("OnClick", click)
    return button
end

-- Create an editable field with native text input and no auto-focus on window opening.
function EH:Edit(parent, width, changed)
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    self:Skin(edit, true)
    local _, _, font = self:Palette()
    edit:SetFont(font, 13, "")
    edit:SetSize(width, 26); edit:SetAutoFocus(false); edit:SetMaxLetters(1024)
    edit:SetTextInsets(7, 7, 0, 0)
    -- Escape releases input focus before the containing window is dismissed.
    edit:SetScript("OnEscapePressed", function(widget) widget:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(widget) widget:ClearFocus() end)
    if changed then edit:SetScript("OnTextChanged", changed) end
    return edit
end
