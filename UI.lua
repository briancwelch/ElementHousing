local _, EH = ...
local ownership = { all = "All decor", missing = "Missing decor", owned = "Owned decor", stored = "In storage", favorites = "Favorites" }
local placement = { all = "Any placement", indoor = "Indoors", outdoor = "Outdoors" }
local sorts = { name = "Name", owned = "Most owned", missing = "Missing first", zone = "Zone", source = "Source" }
local sizes = { all = "Any size", [65] = "Tiny", [66] = "Small", [67] = "Medium", [68] = "Large", [69] = "Huge" }
local qualities = { all = "Any quality", [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary" }

-- Present predictable, alphabetized native menu choices with a separate all/current shortcut.
function EH:MenuChoices(choices)
    local result = {}
    for key, name in pairs(choices) do result[#result + 1] = { key = key, name = name } end
    -- Keep broad choices at the top, then sort labels rather than internal identifiers.
    table.sort(result, function(a, b)
        if a.key == "all" or b.key == "all" then return a.key == "all" end
        if a.key == "current" or b.key == "current" then return a.key == "current" end
        return self:Plain(a.name) < self:Plain(b.name)
    end)
    return result
end

-- Open Blizzard's modern context menu; never instantiate deprecated global dropdown frames.
function EH:ChoiceMenu(button, choices, selected, choose)
    if not MenuUtil or not MenuUtil.CreateContextMenu then self:Notify("Native menu support is unavailable."); return end
    MenuUtil.CreateContextMenu(button, function(_, root)
        for _, item in ipairs(self:MenuChoices(choices)) do
            local key = item.key
            -- Native radio callbacks capture a distinct key for every option.
            root:CreateRadio(item.name, function() return tostring(selected()) == tostring(key) end,
                function() choose(key) end)
        end
        if root.SetScrollMode then root:SetScrollMode(350) end
    end)
end

-- Create one labeled filter with dynamically refreshed native choices.
function EH:FilterControl(parent, key, label, choices)
    local title = self:Label(parent, label)
    local button = self:Button(parent, "", 176, function(widget)
        self:ChoiceMenu(widget, choices(), function() return self.filters[key] or "all" end,
            function(value) self:SetFilter(key, value) end)
    end)
    button.text:ClearAllPoints(); button.text:SetPoint("LEFT", 7, 0); button.text:SetWidth(158)
    button.text:SetWordWrap(false)
    self.filterControls[key] = { button = button, choices = choices, title = title }
    self.filterLayout[#self.filterLayout + 1] = { title = title, button = button }
end

-- Offer native tag groups as independent multi-select filters.
function EH:TagMenu(button)
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateButton("Clear tags", function() self.filters.tags = {}; self:ApplyFilters() end)
        for _, group in ipairs(self.tagGroups or {}) do
            local submenu = root:CreateButton(group.groupName)
            for _, tag in ipairs(group.tags or {}) do
                local id = tag.tagID
                -- Tag selections combine with source, profession, and zone filters.
                submenu:CreateCheckbox(tag.tagName, function() return self.filters.tags[id] == true end,
                    function() self.filters.tags[id] = not self.filters.tags[id] or nil; self:ApplyFilters() end)
            end
        end
    end)
end

-- Create a compact scrolling filter sidebar so all controls remain reachable after resizing.
function EH:CreateFilters(parent)
    self.filterControls, self.filterLayout = {}, {}
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -30); scroll:SetPoint("BOTTOMRIGHT", -24, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(196, 1); scroll:SetScrollChild(content)
    self.filterContent = content
    self:FilterControl(content, "ownership", "Collection", function() return ownership end)
    self:FilterControl(content, "source", "Acquisition source", function() return self:SourceChoices() end)
    self:FilterControl(content, "zone", "Zone", function()
        local values = { all = "All zones", current = "Current zone" }
        for key, name in pairs(self.zones or {}) do values[key] = name end
        return values
    end)
    self:FilterControl(content, "profession", "Profession eligibility", function()
        local values = { all = "Any profession", mine = "My professions", none = "No profession-only decor" }
        for id, name in pairs(self.professionNames) do values[tostring(id)] = name end
        return values
    end)
    self:FilterControl(content, "vendor", "Vendor", function()
        local values = { all = "All vendors" }
        for key, name in pairs(self.vendors or {}) do values[key] = name end
        return values
    end)
    self:FilterControl(content, "expansion", "Expansion", function()
        local values = { all = "All expansions", unknown = "Unknown expansion" }
        for key, name in pairs(self.expansions or {}) do values[key] = name end
        return values
    end)
    self:FilterControl(content, "currency", "Currency type", function()
        local values = { all = "All currencies", unknown = "Unknown / no vendor cost" }
        for key, name in pairs(self.currencies or {}) do values[key] = name end
        return values
    end)
    self:FilterControl(content, "category", "Category", function()
        local values = { all = "All categories" }
        for key, name in pairs(self.categories or {}) do values[key] = name end
        return values
    end)
    self:FilterControl(content, "subcategory", "Subcategory", function()
        local values = { all = "All subcategories" }
        for key, name in pairs(self.subcategories or {}) do
            local parent = self.subcategoryParents and self.subcategoryParents[key]
            local category = tonumber(self.filters.category)
            if not category or not parent or parent == category then values[key] = name end
        end
        return values
    end)
    self:FilterControl(content, "placement", "Placement", function() return placement end)
    self:FilterControl(content, "quality", "Quality", function() return qualities end)
    self:FilterControl(content, "size", "Size", function() return sizes end)
    for _, facet in ipairs(self.decorFacets) do
        local key = facet
        self:FilterControl(content, key, self.decorFacetLabels[key], function() return self:DecorTagChoices(key) end)
    end
    self:FilterControl(content, "sort", "Sort by", function() return sorts end)
    local tags = self:Button(content, "Tags / styles", 176, function(button) self:TagMenu(button) end, "tags")
    self.filterLayout[#self.filterLayout + 1] = { button = tags }
    local customize = self:Button(content, "Customizable: any", 176, function()
        self:SetFilter("customizable", not self.filters.customizable)
    end)
    self.customizableButton = customize
    self.filterLayout[#self.filterLayout + 1] = { button = customize }
    local pvpLabel = self:Label(content, "Hide PvP Decorations")
    local pvp = self:Button(content, "Disabled", 176, function()
        self:SetFilter("hidePvP", not self.filters.hidePvP)
    end)
    self.hidePvPButton = pvp
    self.filterLayout[#self.filterLayout + 1] = { title = pvpLabel, button = pvp }
    local reset = self:Button(content, "Reset filters", 176, function() self:ResetFilters() end, "refresh")
    self.filterLayout[#self.filterLayout + 1] = { button = reset }
    local presets = self:Button(content, "Filter presets", 176, function(button)
        MenuUtil.CreateContextMenu(button, function(_, root)
            root:CreateButton("Save current filters...", function() self:TextDialog("Save filter preset", "", function(name) self:SavePreset(name) end) end)
            local names = {}
            for name in pairs(self.db.presets) do names[name] = name end
            for _, item in ipairs(self:MenuChoices(names)) do
                local name = item.key
                local submenu = root:CreateButton(name)
                submenu:CreateButton("Load", function() self:LoadPreset(name) end)
                submenu:CreateButton("Remove", function() self.db.presets[name] = nil end)
            end
        end)
    end, "book")
    self.filterLayout[#self.filterLayout + 1] = { button = presets }
    local help = self:Label(content, 'Search: name:, source:, zone:, vendor:, profession:, id:, culture:, material:, color:, room:.\nUse "quoted phrases" or -exclude. Decor classifications are community tags.')
    help:SetWidth(175); help:SetWordWrap(true)
    self.filterHelp = help
    self:LayoutFilters()
end

-- Reflow the scrolling sidebar from ElvUI's font metrics so every selector remains reachable.
function EH:LayoutFilters()
    if not self.filterContent then return end
    local y, height = 0, math.max(24, (ElvUI[1].db.general.fontSize or 13) + 12)
    for _, control in ipairs(self.filterLayout) do
        if control.title then
            control.title:SetWidth(176); control.title:SetWordWrap(true)
            control.title:ClearAllPoints(); control.title:SetPoint("TOPLEFT", 10, -y)
            y = y + control.title:GetStringHeight() + 6
        end
        control.button:ClearAllPoints(); control.button:SetPoint("TOPLEFT", 10, -y)
        control.button:SetHeight(height); y = y + height + 12
    end
    self.filterHelp:ClearAllPoints(); self.filterHelp:SetPoint("TOPLEFT", 10, -y)
    self.filterContent:SetHeight(y + self.filterHelp:GetStringHeight() + 16)
end

-- Update selector captions without rebuilding menus or resetting scroll position.
function EH:RenderFilters()
    for key, control in pairs(self.filterControls or {}) do
        local value = self.filters[key] or "all"
        local choices = control.choices()
        control.button.text:SetText(choices[value] or choices[tonumber(value)] or tostring(value))
    end
    if self.customizableButton then self.customizableButton.text:SetText(self.filters.customizable and "Customizable: only" or "Customizable: any") end
    if self.hidePvPButton then
        self.hidePvPButton.text:SetText(self.filters.hidePvP and "Enabled" or "Disabled")
    end
    self:LayoutFilters()
end

-- Display a reusable text-entry dialog for names and copyable blueprint codes.
function EH:TextDialog(title, initial, accept, readOnly)
    if not self.textDialog then
        local dialog = CreateFrame("Frame", "ElementHousingTextDialog", UIParent, "BackdropTemplate")
        dialog:Hide(); dialog:SetSize(480, 132); dialog:SetPoint("CENTER"); dialog:SetFrameStrata("DIALOG")
        self:Skin(dialog, false, true)
        dialog.title = self:Label(dialog, ""); dialog.title:SetPoint("TOPLEFT", 14, -14)
        dialog.edit = self:Edit(dialog, 452); dialog.edit:SetMaxLetters(4096); dialog.edit:SetPoint("TOPLEFT", 14, -44)
        dialog.ok = self:Button(dialog, "Save", 90, function()
            if dialog.accept then dialog.accept(dialog.edit:GetText()) end
            dialog:Hide()
        end)
        dialog.ok:SetPoint("BOTTOMRIGHT", -112, 14)
        dialog.cancel = self:Button(dialog, "Close", 90, function() dialog:Hide() end)
        dialog.cancel:SetPoint("BOTTOMRIGHT", -14, 14)
        -- Hide dialogs with their originating addon window and release input focus.
        dialog:SetScript("OnHide", function() dialog.edit:ClearFocus(); dialog.accept = nil end)
        tinsert(UISpecialFrames, "ElementHousingTextDialog")
        self.textDialog = dialog
    end
    local dialog = self.textDialog
    dialog.title:SetText(title); dialog.edit:SetText(initial or ""); dialog.accept = accept
    dialog.ok:SetShown(not readOnly)
    dialog:Show(); dialog.edit:SetFocus(); dialog.edit:HighlightText()
end

-- Save an unclipped, center-relative position after user movement or resize.
function EH:SaveGeometry()
    local frame = self.frame
    self.db.settings.width, self.db.settings.height = frame:GetWidth(), frame:GetHeight()
    local x, y = frame:GetCenter()
    local px, py = UIParent:GetCenter()
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if x and y and px and py then self.db.position = { x = x * ratio - px, y = y * ratio - py } end
end

-- Inherit ElvUI's UI scale and clamp the saved dimensions to the current screen.
function EH:ApplyWindowSettings()
    if not self.frame then return end
    local frame, settings = self.frame, self.db.settings
    local maxWidth, maxHeight = math.max(760, UIParent:GetWidth() - 30), math.max(480, UIParent:GetHeight() - 30)
    frame:SetResizeBounds(760, 480, maxWidth, maxHeight)
    frame:SetSize(self:Clamp(settings.width, 760, maxWidth, 1140), self:Clamp(settings.height, 480, maxHeight, 720))
    frame:SetMovable(not settings.locked); frame:SetResizable(settings.resizable and not settings.locked)
    self.resizeGrip:SetShown(settings.resizable and not settings.locked)
end

-- Create all controls under an immediately hidden parent; failed construction cannot leave a stray frame.
function EH:CreateWindow()
    local frame = CreateFrame("Frame", "ElementHousingWindow", UIParent, "BackdropTemplate")
    frame:Hide(); self.frame = frame
    self:Skin(frame, false, true); frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
    frame:EnableMouse(true); frame:SetMovable(true); frame:SetResizable(true)
    local position = self.db.position
    frame:SetPoint("CENTER", UIParent, "CENTER", position and tonumber(position.x) or 0, position and tonumber(position.y) or 0)
    tinsert(UISpecialFrames, "ElementHousingWindow")
    local title = self:Label(frame, self:IconLabel("housing", self:Brand()) .. "  " .. self.version)
    title:SetPoint("TOPLEFT", 14, -12)
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", -270, 0); drag:SetHeight(38)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    -- Movement remains entirely on the addon-owned frame and respects the position lock.
    drag:SetScript("OnDragStart", function() if not self.db.settings.locked then frame:StartMoving() end end)
    drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); self:SaveGeometry() end)
    local close = self:Button(frame, "Close", 60, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -9)
    local config = self:Button(frame, "Settings", 92, function() self:OpenOptions() end, "general")
    config:SetPoint("RIGHT", close, "LEFT", -6, 0)
    local refresh = self:Button(frame, "Refresh", 92, function()
        if self.view == "neighborhood" or self.view == "house" then self:RefreshHousingInfo()
        elseif self.view == "blueprints" then self:RefreshBlueprints()
        else self:RefreshCatalog() end
    end, "refresh")
    refresh:SetPoint("RIGHT", config, "LEFT", -6, 0)
    self.catalogTab = self:Button(frame, "Catalog", 120, function() self:SetView("catalog") end, "collection")
    self.catalogTab:SetPoint("TOPLEFT", 12, -44)
    self.blueprintTab = self:Button(frame, "Blueprints", 130, function() self:SetView("blueprints") end, "book")
    self.blueprintTab:SetPoint("LEFT", self.catalogTab, "RIGHT", 6, 0)
    self.neighborhoodTab = self:Button(frame, "Neighborhood", 152, function() self:SetView("neighborhood") end, "general")
    self.neighborhoodTab:SetPoint("LEFT", self.blueprintTab, "RIGHT", 6, 0)
    self.houseTab = self:Button(frame, "House", 110, function() self:SetView("house") end, "housing")
    self.houseTab:SetPoint("LEFT", self.neighborhoodTab, "RIGHT", 6, 0)
    self.collectionsTab = self:Button(frame, "Collections", 140, function() self:SetView("collections") end, "collection")
    self.collectionsTab:SetPoint("LEFT", self.houseTab, "RIGHT", 6, 0)
    self.zoneShortcut = self:Button(frame, "Missing here", 140, function()
        self.filters.ownership, self.filters.zone = "missing", "current"
        self:SetView("catalog"); self.scrollOffset = 0; self:ApplyFilters()
    end, "teleports")
    self.zoneShortcut:SetPoint("TOPLEFT", 12, -78)
    self.professionShortcut = self:Button(frame, "My professions", 150, function() self:BrowseMyProfessions() end, "professions")
    self.professionShortcut:SetPoint("LEFT", self.zoneShortcut, "RIGHT", 6, 0)
    self.catalogPanel = CreateFrame("Frame", nil, frame)
    self.catalogPanel:SetPoint("TOPLEFT", 12, -118); self.catalogPanel:SetPoint("BOTTOMRIGHT", -12, 38)
    local sidebar = CreateFrame("Frame", nil, self.catalogPanel, "BackdropTemplate")
    self:Skin(sidebar, true); sidebar:SetPoint("TOPLEFT"); sidebar:SetPoint("BOTTOMLEFT"); sidebar:SetWidth(220)
    local filterTitle = self:Label(sidebar, self:IconLabel("tags", "Browse and filter"))
    filterTitle:SetPoint("TOPLEFT", 10, -8)
    self:CreateFilters(sidebar)
    self.details = CreateFrame("Frame", nil, self.catalogPanel, "BackdropTemplate")
    self:Skin(self.details, true); self.details:SetPoint("TOPRIGHT"); self.details:SetPoint("BOTTOMRIGHT")
    self.listPanel = CreateFrame("Frame", nil, self.catalogPanel, "BackdropTemplate")
    self:Skin(self.listPanel, true)
    self.listPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    self.listPanel:SetPoint("BOTTOMRIGHT", self.details, "BOTTOMLEFT", -8, 0)
    self.searchBox = self:Edit(self.listPanel, 180, function(edit, userInput)
        if userInput then
            self.searchGeneration = (self.searchGeneration or 0) + 1
            local generation = self.searchGeneration
            -- Debounce literal filtering without server requests while the user types.
            C_Timer.After(0.12, function()
                if generation == self.searchGeneration then self:SetFilter("search", edit:GetText()) end
            end)
        end
    end)
    self.searchBox:SetMaxLetters(256); self.searchBox:SetPoint("TOPLEFT", 8, -8); self.searchBox:SetPoint("TOPRIGHT", -44, -8)
    self.searchBox:SetText(self.filters.search or "")
    local clear = self:Button(self.listPanel, "X", 26, function() self.searchBox:SetText(""); self:SetFilter("search", "") end)
    clear:SetPoint("TOPRIGHT", -8, -8)
    self.listBody = CreateFrame("Frame", nil, self.listPanel)
    self.listBody:SetPoint("TOPLEFT", 5, -44); self.listBody:SetPoint("BOTTOMRIGHT", -22, 7)
    self.listBody:EnableMouseWheel(true)
    -- Wheel scrolling changes a row offset rather than allocating thousands of buttons.
    self.listBody:SetScript("OnMouseWheel", function(_, delta) self:SetScroll((self.scrollOffset or 0) - delta * 3) end)
    self.scrollbar = CreateFrame("Slider", nil, self.listPanel, "BackdropTemplate")
    self:Skin(self.scrollbar); self.scrollbar:SetWidth(12)
    self.scrollbar:SetPoint("TOPRIGHT", -5, -45); self.scrollbar:SetPoint("BOTTOMRIGHT", -5, 8)
    self.scrollbar:SetOrientation("VERTICAL"); self.scrollbar:SetValueStep(1); self.scrollbar:SetObeyStepOnDrag(true)
    self.scrollbar:SetThumbTexture(ElvUI[1].media.normTex)
    self.scrollbar:GetThumbTexture():SetSize(10, 32)
    ElvUI[1]:RegisterStatusBar(self.scrollbar:GetThumbTexture())
    self.scrollbar:SetMinMaxValues(0, 0)
    -- Avoid render recursion when updating the scrollbar from filtered data.
    self.scrollbar:SetScript("OnValueChanged", function(_, value) if not self.renderingList then self:SetScroll(value) end end)
    self.emptyLabel = self:Label(self.listBody, "Open the catalog to load decor.")
    self.emptyLabel:SetPoint("CENTER"); self.emptyLabel:SetWidth(230); self.emptyLabel:SetJustifyH("CENTER")
    self.rows = {}
    self:CreateDetails()
    self:CreateBlueprintPanel()
    self:CreateHousingPanels()
    self:CreateProjectsPanel()
    self.statusLabel = self:Label(frame, "")
    self.statusLabel:SetPoint("BOTTOMLEFT", 14, 13); self.statusLabel:SetPoint("BOTTOMRIGHT", -38, 13)
    self.resizeGrip = self:Button(frame, "/", 22, nil)
    self.resizeGrip:SetSize(22, 22); self.resizeGrip:SetPoint("BOTTOMRIGHT", -3, 3)
    -- Native resize dragging persists geometry on release and obeys the lock setting.
    self.resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and self.db.settings.resizable and not self.db.settings.locked then frame:StartSizing("BOTTOMRIGHT") end
    end)
    self.resizeGrip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); self:SaveGeometry() end)
    frame:HookScript("OnSizeChanged", function() if self.listBody then self:LayoutWindow() end end)
    -- Hide stops pending catalog batches and releases all transient input/model state.
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing(); self:SaveGeometry()
        self.generation = (self.generation or 0) + 1
        self.dirty, self.loading = true, false
        self.searchBox:ClearFocus()
        if self.projects then self.projects.search:ClearFocus() end
        if self.textDialog then self.textDialog:Hide() end
        self:ClearModel()
    end)
    self:ApplyWindowSettings(); self:LayoutWindow(); self:UpdateMedia(); self:SetView("catalog")
    self.windowReady = true
end

-- Reflow list/details widths and visible row count within the user's chosen dimensions.
function EH:LayoutWindow()
    if not self.details then return end
    self:LayoutNavigation()
    local width = self:Clamp(self.db.settings.detailsWidth, 240, 460, 330)
    width = math.min(width, math.max(240, self.frame:GetWidth() * 0.32))
    self.details:SetWidth(width)
    if self.favoriteButton then
        self.favoriteButton:SetWidth(math.floor((width - 30) / 2))
        self.modelReset:SetWidth(math.floor((width - 30) / 2))
    end
    local modelHeight = math.min(self:Clamp(self.db.settings.modelHeight, 120, 360, 210), math.max(120, self.details:GetHeight() * 0.42))
    if self.previewArea then self.previewArea:SetHeight(modelHeight) end
    if self.blueprintPanel then self:LayoutBlueprints() end
    if self.infoPages then self:RenderHousingInfo() end
    if self.projects then self:RenderProjects() end
    self:RenderList()
end

-- Wrap navigation when ElvUI's font grows, and move every workspace below the last tab row.
function EH:LayoutNavigation()
    local font = math.max(13, ElvUI[1].db.general.fontSize or 13)
    local height, available = font + 14, self.frame:GetWidth() - 24
    local x, y = 12, math.max(44, font + 30)
    for _, tab in ipairs({ self.catalogTab, self.blueprintTab, self.neighborhoodTab, self.houseTab, self.collectionsTab }) do
        local width = math.min(available, tab.text:GetStringWidth() + 46)
        if x > 12 and x + width > available + 12 then x, y = 12, y + height + 6 end
        tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", x, -y); tab:SetSize(width, height)
        x = x + width + 6
    end
    local top = y + height + 12
    self.zoneShortcut:ClearAllPoints(); self.zoneShortcut:SetPoint("TOPLEFT", 12, -top)
    self.zoneShortcut:SetHeight(height); self.professionShortcut:SetHeight(height)
    self.catalogPanel:ClearAllPoints(); self.catalogPanel:SetPoint("TOPLEFT", 12, -(top + height + 12)); self.catalogPanel:SetPoint("BOTTOMRIGHT", -12, 38)
    local panels = { self.blueprintPanel }
    if self.projects then panels[#panels + 1] = self.projects.root end
    for _, page in pairs(self.infoPages or {}) do panels[#panels + 1] = page.panel end
    for _, panel in ipairs(panels) do
        panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", 12, -top); panel:SetPoint("BOTTOMRIGHT", -12, 38)
    end
end

-- Create one reusable catalog row with source text, counts, and native item thumbnails.
function EH:CreateRow(index)
    local row = CreateFrame("Button", nil, self.listBody, "BackdropTemplate")
    self:Skin(row, true)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(32, 32); row.icon:SetPoint("LEFT", 6, 0)
    row.name = self:Label(row, ""); row.name:SetPoint("TOPLEFT", 46, -6); row.name:SetPoint("TOPRIGHT", -48, -6)
    row.name:SetWordWrap(false); row.name:SetHeight(18)
    row.meta = self:Label(row, ""); row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.meta:SetPoint("RIGHT", -7, 0)
    row.meta:SetWordWrap(false)
    row.count = self:Label(row, ""); row.count:SetPoint("TOPRIGHT", -7, -7)
    row:StyleButton(nil, true, true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:EnableMouseWheel(true); row:SetScript("OnMouseWheel", function(_, delta) self:SetScroll((self.scrollOffset or 0) - delta * 3) end)
    -- Selection previews decor; shortcuts act only on the explicitly clicked record.
    row:SetScript("OnClick", function(widget, button)
        if not widget.entry then return end
        if button == "RightButton" then self:VendorWaypoint(widget.entry)
        elseif IsShiftKeyDown() then self:Favorite(widget.entry)
        else self.selected = widget.entry; self:RenderDetails(); self:RenderList() end
    end)
    -- Native item tooltips are optional; source information remains available without an item ID.
    row:SetScript("OnEnter", function(widget)
        local entry = widget.entry
        if not entry or not self.db.settings.showTooltips then return end
        GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
        if entry.info.itemID then GameTooltip:SetItemByID(entry.info.itemID) else GameTooltip:AddLine(entry.name) end
        GameTooltip:AddLine(entry.sourceLabel, 0.3, 0.8, 1)
        if entry.zoneName then GameTooltip:AddLine(entry.zoneName, 1, 1, 1) end
        GameTooltip:AddLine("Shift-click: favorite. Right-click: vendor waypoint.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.rows[index] = row
    return row
end

-- Clamp scroll offset after filtering or a resize has changed the visible list length.
function EH:SetScroll(offset)
    self.scrollOffset = self:Clamp(math.floor(offset), 0, math.max(0, #self.results - (self.visibleRows or 1)), 0)
    self:RenderList()
end

-- Render a small visible row pool, retaining selection even when it is filtered out.
function EH:RenderList()
    if not self.listBody then return end
    self.renderingList = true
    local fontHeight = ElvUI[1].db.general.fontSize + 4
    local height = math.max(self:Clamp(self.db.settings.rowHeight, 38, 76, 48), fontHeight * 2 + 16)
    local count = math.max(1, math.floor(self.listBody:GetHeight() / height))
    count = math.min(count, 60)
    self.visibleRows = count
    self.scrollOffset = self:Clamp(self.scrollOffset or 0, 0, math.max(0, #self.results - count), 0)
    self.scrollbar:SetMinMaxValues(0, math.max(0, #self.results - count)); self.scrollbar:SetValue(self.scrollOffset)
    for i = 1, math.max(count, #self.rows) do
        local row = self.rows[i] or self:CreateRow(i)
        local entry = i <= count and self.results[i + self.scrollOffset]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(i - 1) * height)
            row:SetPoint("TOPRIGHT", 0, -(i - 1) * height); row:SetHeight(height - 2)
            row.name:SetHeight(fontHeight)
            local info = entry.info
            if info.iconTexture then row.icon:SetTexture(info.iconTexture)
            elseif info.iconAtlas then row.icon:SetAtlas(info.iconAtlas)
            else row.icon:SetTexture(self:Icon("housing")) end
            row.name:SetText((self.db.favorites[entry.key] and "|cff8787ed* |r" or "") .. entry.name)
            local color = info.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
            row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
            row.meta:SetText(self.db.settings.showSource and (entry.sourceLabel .. (entry.zoneName and " - " .. entry.zoneName or "")) or "")
            row.count:SetText(self.db.settings.showCounts and (entry.owned > 0 and tostring(entry.owned) or "Missing") or "")
            row.count:SetTextColor(entry.owned > 0 and 0.4 or 0.7, entry.owned > 0 and 0.85 or 0.7, entry.owned > 0 and 1 or 0.7)
            row.forcedBorderColors = self.selected == entry and ElvUI[1].media.rgbvaluecolor or nil
            local border = row.forcedBorderColors or ElvUI[1].media.bordercolor
            row:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
        end
    end
    self.emptyLabel:SetShown(#self.results == 0)
    self.emptyLabel:SetText(self.loading and "Loading decor..." or "No decor matches these filters.\nTry Reset filters.")
    self.renderingList = false
end

-- Construct a single interactive native scene and a scrollable information panel.
function EH:CreateDetails()
    local panel = self.details
    self.detailName = self:Label(panel, "Select decor")
    self.detailName:SetPoint("TOPLEFT", 12, -12); self.detailName:SetPoint("TOPRIGHT", -12, -12)
    self.detailName:SetHeight(40); self.detailName:SetWordWrap(true)
    self.previewArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    self:Skin(self.previewArea, true); self.previewArea:SetPoint("TOPLEFT", 10, -60)
    self.previewArea:SetPoint("TOPRIGHT", -10, -60); self.previewArea:SetHeight(210)
    self.modelFallback = self.previewArea:CreateTexture(nil, "ARTWORK")
    self.modelFallback:SetSize(64, 64); self.modelFallback:SetPoint("CENTER")
    self.modelHint = self:Label(self.previewArea, ""); self.modelHint:SetPoint("BOTTOM", 0, 8)
    local infoScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    infoScroll:SetPoint("TOPLEFT", self.previewArea, "BOTTOMLEFT", 2, -12)
    infoScroll:SetPoint("BOTTOMRIGHT", -30, 78)
    self.detailContent = CreateFrame("Frame", nil, infoScroll); self.detailContent:SetSize(280, 400)
    infoScroll:SetScrollChild(self.detailContent)
    self.detailText = self:Label(self.detailContent, ""); self.detailText:SetPoint("TOPLEFT")
    self.detailText:SetWordWrap(true)
    -- Reflow source descriptions instead of clipping them when the window becomes narrower.
    infoScroll:HookScript("OnSizeChanged", function(_, width)
        self.detailContent:SetWidth(math.max(180, width)); self.detailText:SetWidth(math.max(180, width))
        self.detailContent:SetHeight(math.max(1, self.detailText:GetStringHeight() + 10))
    end)
    self.favoriteButton = self:Button(panel, "Favorite", 125, function() self:Favorite(self.selected) end, "heart")
    self.favoriteButton:SetPoint("BOTTOMLEFT", 10, 43)
    self.waypointButton = self:Button(panel, "Vendor waypoint", 180, function()
        local entry = self.selected
        local recipeID = entry and self.recipesByItem and self.recipesByItem[entry.info.itemID]
        if entry and entry.sources.vendor then self:VendorWaypoint(entry)
        elseif recipeID then
            self:SetView("collections"); self:SetProjectMode("recipes")
            self.projects.profession, self.projects.missingOnly = "all", false
            self.projects.search:SetText(entry.name); self:RenderProjects()
        end
    end, "teleports")
    self.waypointButton:SetPoint("BOTTOMLEFT", 10, 10); self.waypointButton:SetPoint("BOTTOMRIGHT", -10, 10)
    self.modelReset = self:Button(panel, "Reset view", 110, function() self.modelKey = nil; self:RenderModel() end, "refresh")
    self.modelReset:SetPoint("BOTTOMRIGHT", -10, 43)
end

-- Release model resources on selection changes and when the window closes.
function EH:ClearModel()
    if self.modelScene then
        local actor = self.modelScene:GetActorByTag("decor")
        if actor then actor:ClearModel() end
        self.modelScene:Hide()
    end
    if self.modelControls then self.modelControls:Hide() end
    self.modelKey = nil
end

-- Preview the native catalog model using Blizzard's scene IDs, camera, and decor actor.
function EH:RenderModel()
    if self.view ~= "catalog" or not self.frame:IsShown() then self:ClearModel(); return end
    local entry = self.selected
    if not entry then self:ClearModel(); self.modelFallback:Hide(); self.modelHint:SetText("Select an item to preview"); return end
    local info = entry.info
    self.modelFallback:SetTexture(info.iconTexture or self:Icon("housing"))
    self.modelFallback:Show()
    if not self.db.settings.showModels or not info.asset then
        self:ClearModel()
        self.modelHint:SetText(self.db.settings.showModels and "3D model unavailable" or "3D preview disabled")
        return
    end
    if not self.modelScene then
        local ok, scene = pcall(CreateFrame, "ModelScene", nil, self.previewArea, "PanningModelSceneMixinTemplate")
        if not ok then self.modelHint:SetText("3D preview unavailable on this client"); return end
        self.modelScene = scene
        scene:SetAllPoints(self.previewArea)
        local controlsOK, controls = pcall(CreateFrame, "Frame", nil, self.previewArea, "ModelSceneControlFrameTemplate")
        if controlsOK then
            self.modelControls = controls; controls:SetPoint("BOTTOM", 0, 8); controls:SetModelScene(scene)
        end
    end
    local scene = self.modelScene
    if self.modelKey ~= entry.key then
        self:ClearModel()
        scene:TransitionToModelSceneID(info.uiModelSceneID or 1317, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
        local actor = scene:GetActorByTag("decor")
        if not actor then self.modelHint:SetText("3D model is loading"); return end
        actor:SetPreferModelCollisionBounds(true); actor:SetModelByFileID(info.asset)
        self.modelKey = entry.key
    end
    scene:EnableMouse(self.db.settings.modelRotation); scene:EnableMouseWheel(self.db.settings.modelRotation)
    scene:Show(); self.modelFallback:Hide(); self.modelHint:SetText("")
    if self.modelControls then self.modelControls:SetShown(self.db.settings.modelRotation) end
end

-- Format known native vendor costs without presenting absent cost data as free.
function EH:CostText(entry)
    if not self:Readable(entry.cost) or not self:Readable(entry.currencyType) then return "Unknown" end
    if entry.cost == nil then return "Unknown" end
    if type(entry.cost) == "number" and (entry.cost ~= entry.cost or entry.cost < 0 or entry.cost == math.huge) then return "Unknown" end
    if entry.currencyType ~= nil and (type(entry.currencyType) ~= "number" or entry.currencyType < 0
        or entry.currencyType == math.huge or entry.currencyType % 1 ~= 0) then return "Unknown" end
    if entry.currencyType and entry.currencyType > 0 then
        local currency = self:Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo, entry.currencyType)
        return tostring(entry.cost) .. " " .. (currency and currency.name or ("currency " .. entry.currencyType))
    end
    if type(entry.cost) == "number" and GetMoneyString then return GetMoneyString(entry.cost) end
    return tostring(entry.cost)
end

-- Present native ownership, placement, source, and acquisition metadata for the selected decor.
function EH:RenderDetails()
    if not self.detailName then return end
    local entry = self.selected
    self.detailName:SetText(entry and entry.name or "Select decor")
    local recipeID = entry and self.recipesByItem and self.recipesByItem[entry.info.itemID]
    self.favoriteButton:SetEnabled(entry ~= nil); self.waypointButton:SetEnabled(entry and entry.sources.vendor or recipeID ~= nil)
    self.waypointButton.text:SetText(entry and entry.sources.vendor and "Vendor waypoint" or recipeID and "Crafting recipe" or "Vendor waypoint")
    self.waypointButton.icon:SetTexture(self:Icon(entry and entry.sources.vendor and "teleports" or recipeID and "professions" or "teleports"))
    self.favoriteButton.text:SetText(entry and self.db.favorites[entry.key] and "Unfavorite" or "Favorite")
    local lines = {}
    if entry then
        local info = entry.info
        lines = { string.format("|cff3fc7ebOwned:|r %d   Storage: %d   Placed: %d", entry.owned, entry.stored, info.totalNumPlaced or 0),
            "Placement cost: " .. tostring(info.placementCost or 0),
            (info.isAllowedIndoors and "Indoors" or "") .. (info.isAllowedIndoors and info.isAllowedOutdoors and " / " or "") .. (info.isAllowedOutdoors and "Outdoors" or ""),
            info.canCustomize and "Customizable" or "", "", "|cff3fc7eb" .. entry.sourceLabel .. "|r",
            entry.sourceText ~= "" and entry.sourceText or "Source details are not supplied by Blizzard.",
        }
        if next(entry.vendorNames) then lines[#lines + 1] = "\nVendors: " .. self:SourceValues(entry.vendorNames) end
        if next(entry.zoneNames) then lines[#lines + 1] = "Zones: " .. self:SourceValues(entry.zoneNames) end
        if entry.waypointVendorName then lines[#lines + 1] = "Waypoint vendor: " .. entry.waypointVendorName end
        if entry.sources.vendor then
            local label = entry.waypointVendorName and "Cost at " .. entry.waypointVendorName or "Vendor cost"
            lines[#lines + 1] = label .. ": " .. self:CostText(entry)
        end
        if #(entry.libraryVendors or {}) > 0 then
            lines[#lines + 1] = "\nKnown vendor locations (bundled library):"
            for _, route in ipairs(entry.libraryVendors) do
                local map = self:Call(C_Map and C_Map.GetMapInfo, route.mapID)
                lines[#lines + 1] = string.format("%s - %s: %.1f, %.1f", route.vendorName, map and map.name or ("Map " .. route.mapID), route.x * 100, route.y * 100)
                if route.note then lines[#lines + 1] = route.note end
            end
        end
        local tags = {}
        for _, facet in ipairs(self.decorFacets) do
            local text = self:DecorTagText(entry, facet)
            if text ~= "" then tags[#tags + 1] = self.decorFacetLabels[facet] .. ": " .. text end
        end
        if #tags > 0 then lines[#lines + 1] = "\nCommunity decor tags:\n" .. table.concat(tags, "\n") end
        if entry.unknownLocation then lines[#lines + 1] = "Some location names need a native map ID to distinguish them." end
        if entry.instanceName then lines[#lines + 1] = "Instance: " .. entry.instanceName end
        if entry.encounterName then lines[#lines + 1] = "Encounter: " .. entry.encounterName end
        if entry.pendingSource then lines[#lines + 1] = "\nAdditional source data is loading." end
        lines[#lines + 1] = "\nDecor ID: " .. info.recordID .. (info.itemID and "   Item ID: " .. info.itemID or "")
    end
    self.detailText:SetText(table.concat(lines, "\n"))
    self.detailText:SetWidth(math.max(180, self.details:GetWidth() - 46))
    self.detailContent:SetHeight(math.max(1, self.detailText:GetStringHeight() + 10))
    self:RenderModel()
end

-- Refresh the active tab accent from ElvUI without requesting housing data.
function EH:RenderTabs()
    local color = ElvUI[1].media.rgbvaluecolor
    for key, tab in pairs({ catalog = self.catalogTab, blueprints = self.blueprintTab,
        neighborhood = self.neighborhoodTab, house = self.houseTab, collections = self.collectionsTab }) do
        if key == self.view then tab.text:SetTextColor(color[1], color[2], color[3]) else tab.text:SetTextColor(1, 1, 1) end
    end
end

-- Switch workspaces without rebuilding controls or carrying a model into information pages.
function EH:SetView(view)
    self.view = (view == "blueprints" or view == "neighborhood" or view == "house" or view == "collections") and view or "catalog"
    self.catalogPanel:SetShown(self.view == "catalog"); self.blueprintPanel:SetShown(self.view == "blueprints")
    self.projects.root:SetShown(self.view == "collections")
    self.zoneShortcut:SetShown(self.view == "catalog"); self.professionShortcut:SetShown(self.view == "catalog")
    self:RenderTabs()
    for key, page in pairs(self.infoPages or {}) do page.panel:SetShown(key == self.view) end
    if self.view == "catalog" then self:RenderDetails() else self:ClearModel() end
    if self.view == "collections" then self:RenderProjects() end
    if self.frame:IsShown() then
        if self.view == "blueprints" then self:RefreshBlueprints()
        elseif self.view == "neighborhood" or self.view == "house" then self:RefreshHousingInfo()
        elseif self.dirty or not self.searcher then self:RefreshCatalog() end
    end
    self:RenderStatus()
end

-- Lazily open a fully constructed window; report construction failure and keep the parent hidden.
function EH:Show(view)
    if not self.initialized then self:Initialize() end
    if not self.frame then
        local ok, reason = xpcall(function() self:CreateWindow() end, function(errorText)
            return tostring(errorText) .. (debugstack and "\n" .. debugstack(2, 8, 8) or "")
        end)
        if not ok then
            if self.frame then self.frame:Hide() end
            self:Notify("Window could not be built. " .. tostring(reason))
            return false
        end
    end
    if not self.windowReady then self:Notify("Window construction failed. Reload after reporting the error."); return false end
    self.frame:Show(); self:SetView(view or self.view or "catalog")
    return true
end

-- Keep every launcher action pointed at the same single native window.
function EH:Toggle()
    if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

-- Display collection progress and filter totals without fabricated achievement data.
function EH:RenderStatus()
    if not self.statusLabel then return end
    local infoView = self.view == "neighborhood" or self.view == "house"
    local message = self.notice or (infoView and "Housing information updates as you travel and receive new data.")
        or (self.view == "collections" and "Collections and crafting plans use Blizzard ownership and this character's inventory.")
        or (self.view == "blueprints" and self.blueprintStatus) or self.catalogStatus
    if not message then
        local total, owned = #self.entries, self.ownedCount or 0
        message = string.format("Collection %d / %d (%d%%)  |  Missing %d  |  Showing %d", owned, total,
            total > 0 and math.floor(owned / total * 100) or 0, total - owned, #self.results)
        if self.filters.zone == "current" then
            local mapID = self:Call(C_Map and C_Map.GetBestMapForUnit, "player")
            local map = mapID and self:Call(C_Map.GetMapInfo, self:ZoneMap(mapID))
            message = message .. "  |  " .. (map and map.name or "Current zone unknown")
        end
    end
    self.statusLabel:SetText(message)
end

-- Build the blueprint library, share-code input, and scrollable requirement inspector.
function EH:CreateBlueprintPanel()
    local panel = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    panel:Hide(); self:Skin(panel, true)
    panel:SetPoint("TOPLEFT", 12, -82); panel:SetPoint("BOTTOMRIGHT", -12, 38)
    self.blueprintPanel = panel
    local title = self:Label(panel, self:IconLabel("book", "Blueprint library"))
    title:SetPoint("TOPLEFT", 12, -12)
    self.blueprintInput = self:Edit(panel, 300); self.blueprintInput:SetMaxLetters(4096)
    self.blueprintInput:SetPoint("TOPLEFT", 12, -44)
    local inspect = self:Button(panel, "Inspect code", 126, function() self:InspectBlueprint(self.blueprintInput:GetText()) end, "browser")
    inspect:SetPoint("LEFT", self.blueprintInput, "RIGHT", 8, 0)
    local save = self:Button(panel, "Save code", 114, function()
        local code = self:BlueprintCode(self.blueprintInput:GetText()) or self.blueprintCode
        if not code then self:Notify("Paste or select a valid blueprint code first."); return end
        self:TextDialog("Name this saved blueprint", self.blueprintName or "", function(name) self:SaveBlueprint(code, name) end)
    end, "book")
    save:SetPoint("LEFT", inspect, "RIGHT", 6, 0)
    local export = self:Button(panel, "Export...", 108, function() self:ExportBlueprint() end)
    export:SetPoint("TOPRIGHT", -12, -12)
    local leftScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", 12, -86); leftScroll:SetPoint("BOTTOMLEFT", 12, 12); leftScroll:SetWidth(234)
    local library = CreateFrame("Frame", nil, leftScroll); library:SetSize(234, 1); leftScroll:SetScrollChild(library)
    self.blueprintLibrary, self.blueprintRows = library, {}
    self.blueprintDetail = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    self:Skin(self.blueprintDetail, true)
    self.blueprintDetail:SetPoint("TOPLEFT", 280, -86); self.blueprintDetail:SetPoint("BOTTOMRIGHT", -12, 12)
    self.blueprintTitle = self:Label(self.blueprintDetail, "Select a blueprint or paste a share code")
    self.blueprintTitle:SetPoint("TOPLEFT", 12, -12); self.blueprintTitle:SetPoint("TOPRIGHT", -12, -12)
    self.blueprintProgress = CreateFrame("StatusBar", nil, self.blueprintDetail)
    self.blueprintProgress:SetStatusBarTexture(ElvUI[1].media.normTex)
    ElvUI[1]:RegisterStatusBar(self.blueprintProgress)
    self:UpdateMedia()
    self.blueprintProgress:SetPoint("TOPLEFT", 12, -42); self.blueprintProgress:SetPoint("TOPRIGHT", -12, -42)
    self.blueprintProgress:SetHeight(8); self.blueprintProgress:SetMinMaxValues(0, 1); self.blueprintProgress:SetValue(0)
    self.blueprintSummaryLabel = self:Label(self.blueprintDetail, "")
    self.blueprintSummaryLabel:SetPoint("TOPLEFT", 12, -58); self.blueprintSummaryLabel:SetPoint("TOPRIGHT", -12, -58)
    local requirements = CreateFrame("ScrollFrame", nil, self.blueprintDetail, "UIPanelScrollFrameTemplate")
    requirements:SetPoint("TOPLEFT", 12, -94); requirements:SetPoint("BOTTOMRIGHT", -30, 80)
    local content = CreateFrame("Frame", nil, requirements); content:SetSize(350, 1); requirements:SetScrollChild(content)
    self.requirementContent, self.requirementRows = content, {}
    -- Keep blueprint requirements readable when the housing window is resized.
    requirements:HookScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(210, width)) end)
    self.importButton = self:Button(self.blueprintDetail, "Preview / import...", 190, function() self:ImportBlueprint(self.blueprintCode) end, "housing")
    self.importButton:SetPoint("BOTTOMLEFT", 12, 12)
    local copy = self:Button(self.blueprintDetail, "Copy code", 115, function()
        if self.blueprintCode then self:TextDialog("Blueprint share code - Ctrl+C to copy", self.blueprintCode, nil, true) end
    end)
    copy:SetPoint("BOTTOMRIGHT", -12, 12)
    local missing = self:Button(self.blueprintDetail, "Requirements: all", 180, function()
        self:SetSetting("blueprintMissingOnly", not self.db.settings.blueprintMissingOnly); self:RenderBlueprints()
    end)
    missing:SetPoint("BOTTOMLEFT", 12, 46); self.blueprintMissingButton = missing
    self.blueprintHelp = self:Label(panel, "Paste a Blizzard housing blueprint share code above.")
    self.blueprintHelp:SetPoint("TOPLEFT", 12, -74)
end

-- Fit blueprint code input to the window while retaining action buttons at minimum size.
function EH:LayoutBlueprints()
    if self.blueprintInput then self.blueprintInput:SetWidth(math.max(220, math.min(440, self.frame:GetWidth() - 390))) end
end

-- Show blueprint collection rows and native budget/requirement groups, with missing quantities.
function EH:RenderBlueprints()
    if not self.blueprintPanel then return end
    self:BuildBlueprintList()
    for i = 1, math.max(#self.blueprintList, #self.blueprintRows) do
        local row = self.blueprintRows[i]
        if not row then
            row = self:Button(self.blueprintLibrary, "", 232, function(widget)
                self.blueprintInput:SetText(widget.info.shareCode); self:InspectBlueprint(widget.info.shareCode, widget.info.name)
            end, "book")
            row:SetHeight(42); row.text:SetWidth(193); row.text:SetWordWrap(true)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            -- Right-click manages a local shared code without deleting a native blueprint.
            row:SetScript("OnClick", function(widget, button)
                local info = widget.info
                if not info then return end
                if button == "RightButton" then
                    MenuUtil.CreateContextMenu(widget, function(_, root)
                        root:CreateButton("Copy share code", function() self:TextDialog("Blueprint share code - Ctrl+C to copy", info.shareCode, nil, true) end)
                        if self.db.blueprints[info.shareCode] then
                            root:CreateButton("Rename local saved code", function()
                                self:TextDialog("Name this saved blueprint", self.db.blueprints[info.shareCode].name,
                                    function(name) self:SaveBlueprint(info.shareCode, name) end)
                            end)
                            root:CreateButton("Forget local saved code", function() self:ForgetBlueprint(info.shareCode) end)
                        end
                    end)
                else self.blueprintInput:SetText(info.shareCode); self:InspectBlueprint(info.shareCode, info.name) end
            end)
            self.blueprintRows[i] = row
        end
        row.info = self.blueprintList[i]; row:SetShown(row.info ~= nil)
        if row.info then row:SetPoint("TOPLEFT", 0, -(i - 1) * 46); row.text:SetText(row.info.name or "Shared blueprint") end
    end
    self.blueprintLibrary:SetHeight(math.max(1, #self.blueprintList * 46))
    self.blueprintHelp:SetText(self.blueprintStatus or (#self.blueprintList .. " blueprints. Select one or paste a share code."))
    self.blueprintTitle:SetText(self.blueprintName or "Select a blueprint or paste a share code")
    self.blueprintMissingButton.text:SetText(self.db.settings.blueprintMissingOnly and "Requirements: missing" or "Requirements: all")
    local contents = self.blueprintContents
    local total, missing, invalid = self:BlueprintSummary(contents)
    self.blueprintProgress:SetValue(total > 0 and math.max(0, total - missing) / total or 0)
    self.blueprintSummaryLabel:SetText(contents and string.format("%d / %d available  |  %d missing  |  %d invalid types", total - missing, total, missing, invalid) or "Inspect a code to load its requirements.")
    self.importButton:SetEnabled(self.blueprintCode ~= nil and contents ~= nil)
    local data = {}
    if contents then
        if contents.blockingRequirementFlags ~= 0 then data[#data + 1] = { title = "Blocking requirements - review Blizzard's import preview" } end
        for _, issue in ipairs(self:BlueprintIssues(contents)) do data[#data + 1] = { title = issue } end
        for _, location in ipairs({ "interiorBudgets", "exteriorBudgets" }) do
            local budgets = contents.budgetInfo and contents.budgetInfo[location] or {}
            local ordered = {}
            for _, budget in pairs(budgets) do if budget.cost > 0 then ordered[#ordered + 1] = budget end end
            table.sort(ordered, function(a, b) return a.budgetType < b.budgetType end)
            if #ordered > 0 then data[#data + 1] = { title = location == "interiorBudgets" and "Interior budgets" or "Exterior budgets" } end
            for _, budget in ipairs(ordered) do
                data[#data + 1] = { title = self:BlueprintBudgetText(budget, location == "interiorBudgets") }
            end
        end
        for _, group in ipairs(contents.contentGroups or {}) do
            local names = { [1] = "House", [2] = "Rooms", [3] = "Decor", [4] = "Dyes", [5] = "Fixtures", [6] = "Other" }
            local headerAdded = false
            for _, entry in ipairs(group.entries or {}) do
                if not self.db.settings.blueprintMissingOnly or entry.numMissing > 0 or entry.invalid then
                    if not headerAdded then data[#data + 1] = { title = names[group.contentType] or "Requirements" }; headerAdded = true end
                    data[#data + 1] = { entry = entry, title = string.format("%s  |  %d needed, %d missing%s", entry.name, entry.total, entry.numMissing, entry.invalid and " - unavailable" or "") }
                end
            end
        end
    end
    for i = 1, math.max(#data, #self.requirementRows) do
        local row = self.requirementRows[i]
        if not row then
            row = self:Button(self.requirementContent, "", 300, function(widget)
                local requirement = widget.data and widget.data.entry
                if requirement and requirement.contentType == Enum.HousingBlueprintContentType.Decor then
                    local entry = self.byID[requirement.recordID]
                    if entry then self.selected = entry; self:SetView("catalog"); self:RenderDetails()
                    else self:Notify("Load the catalog to inspect this decor requirement.") end
                end
            end)
            row:SetHeight(38); row.text:ClearAllPoints(); row.text:SetPoint("LEFT", 6, 0); row.text:SetPoint("RIGHT", -6, 0)
            row.text:SetWordWrap(true); self.requirementRows[i] = row
        end
        row.data = data[i]; row:SetShown(row.data ~= nil)
        if row.data then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(i - 1) * 42); row:SetPoint("TOPRIGHT", 0, -(i - 1) * 42)
            row.text:SetText(row.data.title)
            local isEntry = row.data.entry ~= nil
            row.text:SetTextColor(isEntry and 1 or 0.25, isEntry and 1 or 0.78, isEntry and 1 or 0.92)
        end
    end
    self.requirementContent:SetHeight(math.max(1, #data * 42))
    self:RenderStatus()
end
