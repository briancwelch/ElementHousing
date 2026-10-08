local _, EH = ...
local E = ElvUI[1]
local gap, padding = 12, 14

-- Use ElvUI's current font metrics for spacing without imposing another font configuration.
local function LineHeight()
    return math.max(14, E.db.general.fontSize or 13) + 6
end

-- Accept public finite chart data, preserving zero while rejecting restricted or invalid values.
local function Number(value)
    return EH:Readable(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- Apply only native value colors to dashboard accents.
local function Accent(label)
    label:SetTextColor(unpack(E.media.rgbvaluecolor))
end

-- Reanchor pooled controls so a different layout cannot retain old points.
local function Place(widget, parent, x, y, width, height)
    widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    widget:SetSize(width, height); widget:Show()
end

-- Show full values on demand for graph markers and compact directory rows.
local function Tooltip(widget)
    if not widget.tooltip then return end
    GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(widget.tooltip, 1, 1, 1, true)
    GameTooltip:Show()
end

-- Reuse labels and register each one with ElvUI only once.
local function Label(card, text, x, y, width, accent)
    card.labelIndex = card.labelIndex + 1
    local label = card.labels[card.labelIndex]
    if not label then label = EH:Label(card, ""); card.labels[card.labelIndex] = label end
    label:SetText(text or ""); label:SetWordWrap(true)
    label:ClearAllPoints(); label:SetPoint("TOPLEFT", x, -y); label:SetWidth(math.max(1, width))
    label:Show()
    if accent then Accent(label) else label:SetTextColor(1, 1, 1) end
    return math.max(LineHeight(), label:GetStringHeight())
end

-- Reuse native ElvUI status bars for XP, milestones, occupancy, and house budgets.
local function Meter(card, spec, y, width)
    card.barIndex = card.barIndex + 1
    local bar = card.bars[card.barIndex]
    if not bar then
        bar = CreateFrame("StatusBar", nil, card, "BackdropTemplate")
        EH:Skin(bar, true); E:RegisterStatusBar(bar)
        bar.text = EH:Label(bar, ""); bar.text:SetPoint("CENTER"); bar.text:SetJustifyH("CENTER")
        card.bars[card.barIndex] = bar
    end
    local height = LineHeight() + 8
    local known = Number(spec.current) and Number(spec.maximum) and spec.current >= 0 and spec.maximum >= 0
    local value = known and (spec.maximum > 0 and math.min(1, spec.current / spec.maximum) or (spec.current == 0 and 0 or 1)) or 0
    if spec.complete then value = 1 end
    bar.known, bar.fraction = known or spec.complete == true, value
    bar:SetMinMaxValues(0, 1); bar:SetValue(value)
    bar:SetStatusBarTexture(E.media.normTex); bar:SetStatusBarColor(unpack(E.media.rgbvaluecolor))
    Place(bar, card, padding, y, width, height)
    bar.text:SetWidth(math.max(1, width - 10))
    local percentage = known and spec.maximum > 0 and spec.current / spec.maximum * 100 or nil
    bar.text:SetText(spec.complete and (spec.completeText or "Complete") or ((Number(spec.current) and tostring(spec.current) or "Unknown")
        .. " / " .. (Number(spec.maximum) and tostring(spec.maximum) or "Unknown")
        .. (Number(percentage) and string.format("   (%.0f%%)", percentage) or "")))
    return y + height + gap
end

-- Allocate one dashboard card and keep its graph/table controls pooled between data updates.
local function Card(page, key)
    local card = page.cards[key]
    if not card then
        card = CreateFrame("Frame", nil, page.content, "BackdropTemplate")
        EH:Skin(card, true)
        card.labels, card.bars, card.rows, card.markers, card.grid = {}, {}, {}, {}, {}
        card.icon = card:CreateTexture(nil, "ARTWORK"); card.icon:SetSize(20, 20)
        card.icon:SetPoint("TOPLEFT", padding, -padding)
        page.cards[key] = card
    end
    for _, pool in ipairs({ card.labels, card.bars, card.rows, card.markers, card.grid }) do
        for _, widget in ipairs(pool) do widget:Hide() end
    end
    card.labelIndex, card.barIndex = 0, 0
    return card
end

-- Render wrapping label/value pairs, keeping long identifiers and localized names inside their card.
local function Fields(card, fields, y, width)
    for _, field in ipairs(fields or {}) do
        local labelWidth = math.floor(width * .43)
        local left = Label(card, field.label, padding, y, labelWidth - gap, true)
        local right = Label(card, field.value, padding + labelWidth, y, width - labelWidth)
        y = y + math.max(left, right) + 4
    end
    return y
end

-- Render full-width striped directories with native font sizing and per-row hover details.
local function Directory(card, section, y, width)
    local columns, rows = section.columns or {}, section.rows or {}
    local weights = #columns == 5 and { .09, .34, .18, .17, .22 } or { .43, .16, .22, .19 }
    local x, headerHeight = padding, LineHeight()
    for index, title in ipairs(columns) do
        local cellWidth = width * weights[index]
        headerHeight = math.max(headerHeight, Label(card, title, x, y, cellWidth - gap, true))
        x = x + cellWidth
    end
    y = y + headerHeight + 6
    for index, data in ipairs(rows) do
        local row = card.rows[index]
        if not row then
            row = CreateFrame("Button", nil, card)
            row.shade = row:CreateTexture(nil, "BACKGROUND"); row.shade:SetAllPoints()
            row.shade:SetTexture(E.media.blankTex)
            row.cells = {}
            row:SetScript("OnEnter", Tooltip)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            card.rows[index] = row
        end
        row.tooltip = data.tooltip or table.concat(data.cells, "  |  ")
        row.shade:SetVertexColor(unpack(E.media.bordercolor)); row.shade:SetAlpha(index % 2 == 0 and .15 or .04)
        local rowHeight, columnX = LineHeight() + 8, 6
        for column, text in ipairs(data.cells) do
            local label = row.cells[column]
            if not label then label = EH:Label(row, ""); row.cells[column] = label end
            label:SetText(text); label:SetWordWrap(true); label:SetJustifyH("LEFT")
            label:ClearAllPoints(); label:SetPoint("TOPLEFT", columnX, -4)
            label:SetWidth(math.max(1, width * weights[column] - gap))
            rowHeight = math.max(rowHeight, label:GetStringHeight() + 8)
            columnX = columnX + width * weights[column]
        end
        Place(row, card, padding, y, width, rowHeight)
        y = y + rowHeight + 2
    end
    if #rows == 0 and not section.message then y = y + Label(card, "No entries reported yet.", padding, y, width) end
    return y
end

-- Draw a coordinate chart from Blizzard's actual plot positions, with an honest occupancy meter.
local function PlotChart(card, section, y, width)
    local counts = section.counts
    y = y + Label(card, "Occupied / known plots", padding, y, width, true) + 4
    y = Meter(card, { current = counts.total > 0 and counts.occupied or nil, maximum = counts.total > 0 and counts.total or nil }, y, width)
    y = y + Label(card, counts.total > 0 and string.format("Occupied %d   |   Unowned %d   |   Unknown %d", counts.occupied, counts.vacant, counts.unknown)
        or "Occupancy details are not available yet.", padding, y, width) + 6
    local chartHeight = math.max(180, math.min(260, width * .6))
    for index = 1, 10 do
        local line = card.grid[index]
        if not line then line = card:CreateTexture(nil, "BACKGROUND"); line:SetTexture(E.media.blankTex); card.grid[index] = line end
        line:SetVertexColor(unpack(E.media.bordercolor)); line:SetAlpha(.35)
        local vertical = index <= 5
        local fraction = ((index - 1) % 5) / 4
        Place(line, card, padding + (vertical and width * fraction or 0), y + (vertical and 0 or chartHeight * fraction), vertical and 1 or width, vertical and chartHeight or 1)
    end
    local visible = 0
    for _, plot in ipairs(section.plots) do
        if Number(plot.x) and Number(plot.y) then
            visible = visible + 1
            local point = card.markers[visible]
            if not point then
                point = CreateFrame("Button", nil, card, "BackdropTemplate")
                EH:Skin(point)
                point.fill = point:CreateTexture(nil, "ARTWORK"); point.fill:SetAllPoints(); point.fill:SetTexture(E.media.blankTex)
                point:SetScript("OnEnter", Tooltip)
                point:SetScript("OnLeave", function() GameTooltip:Hide() end)
                card.markers[visible] = point
            end
            point.plotID, point.tooltip = plot.id, plot.tooltip
            local color = plot.status == "unknown" and E.media.bordercolor or E.media.rgbvaluecolor
            point.fill:SetVertexColor(unpack(color)); point.fill:SetAlpha(plot.status == "vacant" and .3 or 1)
            Place(point, card, padding + plot.x * (width - 12), y + plot.y * (chartHeight - 12), 12, 12)
        end
    end
    if visible == 0 then Label(card, "Plot coordinates are not available yet.", padding + 10, y + chartHeight / 2, width - 20) end
    y = y + chartHeight + 8
    y = y + Label(card, "Plot positions (0-100%). Hover a marker for its owner and price. Faded markers are unowned.", padding, y, width)
    return y
end

-- Render a reusable card according to its data: graphs, budget meters, field pairs, or a directory.
local function RenderCard(page, key, section, width, directory)
    local card = Card(page, key)
    card:SetWidth(width); card.icon:SetTexture(EH:Icon(section.icon or "general"))
    local titleHeight = Label(card, directory and "Plot directory" or section.title, padding + 28, padding, width - padding * 2 - 28, true)
    local y, inner = padding + math.max(20, titleHeight) + gap, width - padding * 2
    if section.message then y = y + Label(card, section.message, padding, y, inner) + gap end
    if directory or section.kind == "table" then
        y = Directory(card, section, y, inner)
    elseif section.kind == "plots" then
        y = PlotChart(card, section, y, inner)
    elseif section.kind == "budgets" then
        for _, meter in ipairs(section.meters) do
            y = y + Label(card, meter.label, padding, y, inner, true) + 4
            y = Meter(card, meter, y, inner)
        end
    else
        if section.progress then
            y = y + Label(card, section.progress.label, padding, y, inner, true) + 4
            y = Meter(card, section.progress, y, inner)
        end
        for _, milestone in ipairs(section.milestones or {}) do
            y = y + Label(card, milestone.label, padding, y, inner, true) + 4
            y = Meter(card, milestone, y, inner)
        end
        y = Fields(card, section.fields, y, inner)
    end
    card:SetHeight(y + padding)
    return card
end

-- Present the location identity and four summary tiles before the detailed graphs.
local function Overview(page, data, width)
    local card = Card(page, "overview")
    card.icon:SetTexture(EH:Icon(data.icon)); card.icon:SetSize(48, 48)
    local title = Label(card, data.title, padding + 64, padding, width - 104, true)
    local subtitle = Label(card, data.subtitle or "Housing overview", padding + 64, padding + title + 2, width - 104)
    local height = math.max(76, padding * 2 + title + subtitle)
    Place(card, page.content, 0, 0, width, height)
    local y, tileWidth = height + gap, (width - gap * 3) / 4
    for index, stat in ipairs(data.stats) do
        local tile = Card(page, "stat:" .. index)
        tile.icon:SetTexture(EH:Icon(stat.icon or "general")); tile.icon:SetSize(20, 20)
        local labelHeight = Label(tile, stat.label, padding + 28, padding, tileWidth - padding * 2 - 28, true)
        local valueHeight = Label(tile, stat.value, padding, padding + labelHeight + 6, tileWidth - padding * 2)
        tile:SetHeight(padding * 2 + labelHeight + valueHeight + 6)
        Place(tile, page.content, (index - 1) * (tileWidth + gap), y, tileWidth, tile:GetHeight())
        height = math.max(height, y + tile:GetHeight())
    end
    return height + gap
end

-- Arrange two cards together on wide windows and stack them on smaller windows.
local function Pair(page, left, right, y, width)
    if not left and not right then return y end
    local stacked = width < math.max(760, LineHeight() * 34)
    local cardWidth = (not right or stacked) and width or (width - gap) / 2
    local first = left and RenderCard(page, left.title, left, cardWidth)
    if first then Place(first, page.content, 0, y, cardWidth, first:GetHeight()) end
    if not right then return y + (first and first:GetHeight() or 0) + gap end
    local second = RenderCard(page, right.title, right, cardWidth)
    Place(second, page.content, stacked and 0 or cardWidth + gap, stacked and y + (first and first:GetHeight() or 0) + gap or y, cardWidth, second:GetHeight())
    return y + (stacked and (first and first:GetHeight() or 0) + gap + second:GetHeight()
        or math.max(first and first:GetHeight() or 0, second:GetHeight())) + gap
end

-- Rebuild page geometry from current native metrics, retaining the user's scroll position.
function EH:LayoutHousingDashboard(page, data)
    local width = math.max(240, page.scroll:GetWidth() - 10)
    page.content:SetWidth(width)
    for _, card in pairs(page.cards) do card:Hide() end
    local y, sections = Overview(page, data, width), {}
    for _, section in ipairs(data.sections) do sections[section.title] = section end
    if data.kind == "neighborhood" then
        y = Pair(page, sections["Neighborhood plots"], sections["Neighborhood endeavor"], y, width)
        y = Pair(page, sections["Current neighborhood"], sections["Milestone rewards"], y, width)
        for _, name in ipairs({ "Explore your neighborhood", "Endeavor tasks", "Residents" }) do
            if sections[name] then y = Pair(page, sections[name], nil, y, width) end
        end
        if sections["Neighborhood plots"] then
            local directory = RenderCard(page, "plot-directory", sections["Neighborhood plots"], width, true)
            Place(directory, page.content, 0, y, width, directory:GetHeight()); y = y + directory:GetHeight() + gap
        end
    else
        y = Pair(page, sections["House level and progress"], sections["Next level unlocks"], y, width)
        y = Pair(page, sections["Interior budgets"], sections["Exterior budgets"], y, width)
        y = Pair(page, sections["Your house"], sections["Live house details"], y, width)
        y = Pair(page, sections["Visitors and sharing"], sections["Room capacity"], y, width)
        if sections["Your home"] then y = Pair(page, sections["Your home"], nil, y, width) end
    end
    if data.identifiers then
        local card = RenderCard(page, "identifiers", { title = "Identifiers", icon = "help", fields = page.showIdentifiers and data.identifiers or {} }, width)
        if not card.toggle then
            -- Expand cached details locally; this control does not request additional housing data.
            card.toggle = self:Button(card, "Show", 80, function()
                page.showIdentifiers = not page.showIdentifiers
                self:LayoutHousingDashboard(page, page.data)
            end)
            card.toggle:SetPoint("TOPRIGHT", -padding, -padding)
        end
        card.toggle:SetHeight(LineHeight() + 8)
        card.toggle.text:SetText(page.showIdentifiers and "Hide" or "Show")
        Place(card, page.content, 0, y, width, card:GetHeight()); y = y + card:GetHeight() + gap
    end
    page.content:SetHeight(math.max(1, y))
    page.scroll:SetVerticalScroll(math.min(page.scroll:GetVerticalScroll(), math.max(0, y - page.scroll:GetHeight())))
end

-- Create native scrolling dashboards with a local owned-house selector.
function EH:CreateHousingPanels()
    self.infoPages = {}
    for _, key in ipairs({ "neighborhood", "house" }) do
        local panel = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        panel:Hide(); self:Skin(panel, true)
        panel:SetPoint("TOPLEFT", 12, -82); panel:SetPoint("BOTTOMRIGHT", -12, 38)
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, key == "house" and -50 or -12); scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        local content = CreateFrame("Frame", nil, scroll); content:SetSize(600, 1); scroll:SetScrollChild(content)
        self.infoPages[key] = { panel = panel, scroll = scroll, content = content, cards = {} }
        -- A width change reflows only cached data; it never requests another server reply.
        scroll:HookScript("OnSizeChanged", function() self:RenderHousingInfo() end)
    end
    self.houseSelector = self:Button(self.infoPages.house.panel, "Choose house", 320, function(button)
        self:ChoiceMenu(button, self:HouseChoices(), function() local info = self:SelectedHouse(); return info and info.houseGUID end,
            function(guid) self.selectedHouseGUID = guid; self.infoPages.house.scroll:SetVerticalScroll(0); self:RefreshHousingInfo() end)
    end, "housing")
    self.houseSelector:SetPoint("TOPLEFT", 12, -12)
end

-- Refresh the visible dashboard without requesting housing data or rebuilding its frames.
function EH:RenderHousingInfo()
    if not self.infoPages or self.renderingHousing then return end
    local page = self.infoPages[self.view]
    if not page then return end
    self.renderingHousing = true
    -- Clear the reflow guard even if a native control reports an error, allowing a later refresh to recover.
    local ok, reason = pcall(function()
        page.data = self.view == "house" and self:HouseData() or self:NeighborhoodData()
        self:LayoutHousingDashboard(page, page.data)
    end)
    self.renderingHousing = nil
    if not ok then error(reason) end
    if self.view == "house" then
        local info = self:SelectedHouse()
        self.houseSelector.text:SetText(info and self:Plain(info.houseName or info.neighborhoodName or "Your house") .. " - Plot "
            .. (self:Readable(info.plotID) and tostring(info.plotID) or "Unknown") or "Choose house")
    end
end
