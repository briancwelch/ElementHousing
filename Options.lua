local _, EH = ...

-- Define a setting once for ElvUI's tree and the standalone configuration fallback.
function EH:Setting(key, label, kind, order, description, min, max, step)
    local option = { type = kind, name = label, order = order, desc = description,
        -- Settings remain account-wide and independent of ElvUI profile switching.
        get = function() return self.db.settings[key] end,
        set = function(_, value) self:SetSetting(key, value) end }
    if kind == "range" then option.min, option.max, option.step = min, max, step end
    self.settingDefinitions[key] = option
    return option
end

-- Build the same left-hand feature tree used by WindTools, with focused pages within it.
function EH:BuildOptions()
    self.settingDefinitions = {}
    local options = { type = "group", childGroups = "tree", name = self:IconLabel("housing", self:Brand()), args = {} }
    options.args.intro = { type = "description", order = 1, fontSize = "medium",
        name = self:Brand() .. " " .. self.version .. "\nNative housing catalog and blueprint library. Account-wide settings. Style follows ElvUI; icons follow nMediaTag when installed." }
    options.args.open = { type = "execute", name = "Open catalog", order = 2, func = function() self:Show("catalog") end }
    options.args.appearance = { type = "group", name = self:IconLabel("colors", "Window"), order = 10,
        childGroups = "tab", args = {
            layout = { type = "group", name = "Layout", order = 1, args = {
                scale = self:Setting("scale", "Window scale", "range", 1, "Scale the entire housing window.", 0.65, 1.5, 0.05),
                opacity = self:Setting("opacity", "Window opacity", "range", 2, "Opacity of the housing window.", 0.4, 1, 0.05),
                width = self:Setting("width", "Window width", "range", 3, "The window also supports dragging its bottom-right corner.", 760, 2000, 10),
                height = self:Setting("height", "Window height", "range", 4, "Dimensions are clamped to the current screen.", 480, 1300, 10),
                detailsWidth = self:Setting("detailsWidth", "Details width", "range", 5, "Automatically narrows on smaller windows.", 240, 460, 10),
                locked = self:Setting("locked", "Lock movement and size", "toggle", 6, "Lock the current window position and dimensions."),
                resizable = self:Setting("resizable", "Enable resize grip", "toggle", 7, "Resize from the bottom-right corner."),
                reset = { type = "execute", name = "Reset window geometry", order = 8, func = function()
                    self.db.position = nil
                    for _, key in ipairs({ "width", "height", "scale" }) do self.db.settings[key] = self.defaults.settings[key] end
                    if self.frame then self.frame:ClearAllPoints(); self.frame:SetPoint("CENTER"); self:ApplyWindowSettings() end
                end },
            } },
            text = { type = "group", name = "Catalog rows", order = 2, args = {
                rowHeight = self:Setting("rowHeight", "Row height", "range", 1, "Space available to item names and source information.", 38, 76, 2),
                fontSize = self:Setting("fontSize", "Item name font size", "range", 2, "The font face follows ElvUI.", 10, 20, 1),
                showSource = self:Setting("showSource", "Show source and zone in rows", "toggle", 3),
                showCounts = self:Setting("showCounts", "Show owned / missing counts", "toggle", 4),
                showTooltips = self:Setting("showTooltips", "Show native item tooltips", "toggle", 5),
            } },
        } }
    options.args.catalog = { type = "group", name = self:IconLabel("collection", "Catalog"), order = 20,
        childGroups = "tab", args = {
            filters = { type = "group", name = "Filter behavior", order = 1, args = {
                help = { type = "description", order = 0, name = "Combine ownership, source, zone, vendor, profession, category, size, quality, placement, and tags. My professions checks all detected primary and secondary professions on the current character and updates when skills change. Search supports quoted phrases, -exclusions, name:, zone:, vendor:, source:, profession:, and id:." },
                rememberFilters = self:Setting("rememberFilters", "Remember filters between sessions", "toggle", 1),
                professionMissingOnly = self:Setting("professionMissingOnly", "Apply profession restrictions to missing decor only", "toggle", 2,
                    "Enable to keep owned decor visible under profession filtering. Disable to apply the selected profession filter to owned decor too. Known vendor, drop, quest, and achievement alternatives remain eligible."),
                includeUnknownProfession = self:Setting("includeUnknownProfession", "Include unknown profession eligibility", "toggle", 3,
                    "Keep decor visible when its profession or the character's skills cannot be determined. Known unrelated profession requirements remain excluded while waypoint data loads."),
                includeUnknownZone = self:Setting("includeUnknownZone", "Include unknown locations in zone filters", "toggle", 4),
                includeSubzones = self:Setting("includeSubzones", "Include subzones and building maps", "toggle", 5,
                    "Normalize native location maps to their containing zone."),
                autoZone = self:Setting("autoZone", "Update current-zone results when moving", "toggle", 6),
                reset = { type = "execute", name = "Reset active filters", order = 7, func = function() self:ResetFilters() end },
            } },
            models = { type = "group", name = "3D preview", order = 2, args = {
                showModels = self:Setting("showModels", "Show 3D decor previews", "toggle", 1,
                    "Uses the native housing model and camera presets. An item icon appears when no model is supplied."),
                modelHeight = self:Setting("modelHeight", "Preview height", "range", 2, "Automatically fits smaller windows.", 120, 360, 10),
                modelRotation = self:Setting("modelRotation", "Enable model camera controls", "toggle", 3, "Allow rotation, panning, and zoom using Blizzard's model scene controls."),
            } },
            performance = { type = "group", name = "Loading", order = 3, args = {
                batchSize = self:Setting("batchSize", "Records per loading batch", "range", 1,
                    "Smaller batches reduce frame-time spikes. Loading is deferred until the window opens.", 8, 64, 4),
                refresh = { type = "execute", name = "Refresh catalog data", order = 2, func = function() self:ScheduleRefresh() end },
            } },
        } }
    options.args.blueprints = { type = "group", name = self:IconLabel("book", "Blueprints"), order = 30, args = {
        help = { type = "description", order = 0, name = "Browse Blizzard's blueprint collection or save shared codes locally. Inspect decor, room, dye, and fixture requirements with availability progress and budgets. Preview / import opens Blizzard's own confirmation flow; export uses its native dialog." },
        showAutosaves = self:Setting("showAutosaves", "Include native automatic backups", "toggle", 1),
        blueprintMissingOnly = self:Setting("blueprintMissingOnly", "Show missing / invalid requirements only", "toggle", 2),
        open = { type = "execute", name = "Open blueprint library", order = 3, func = function() self:Show("blueprints") end },
    } }
    options.args.waypoints = { type = "group", name = self:IconLabel("teleports", "Vendor waypoints"), order = 40, args = {
        help = { type = "description", order = 0, name = "Select a vendor item and use Vendor waypoint, or right-click its catalog row. Coordinates come from Blizzard's acquisition tracking; unknown or loading locations never replace your existing pin." },
        superTrack = self:Setting("superTrack", "Super-track vendor waypoints", "toggle", 1),
        waypointConfirm = self:Setting("waypointConfirm", "Confirm replacing an existing map waypoint", "toggle", 2),
    } }
    options.args.launcher = { type = "group", name = self:IconLabel("menu", "Launcher and support"), order = 50, args = {
        minimap = self:Setting("minimap", "Show minimap icon", "toggle", 1,
            "Standard LibDBIcon launcher, compatible with WindTools minimap collectors. Left-click opens the window; right-click opens settings."),
        help = { type = "description", order = 2, name = "/eh - toggle\n/eh catalog - catalog\n/eh blueprints - blueprint library\n/eh missing - missing decor\n/eh zone - missing decor in this zone\n/eh config - settings\n\nElvUI styling and nMediaTag icons are detected automatically. No selectable themes. Blizzard's housing frames and the installed third-party addons are left untouched." },
    } }
    self.options = options
    return options
end

-- Attach the addon to ElvUI's plugin header and left-hand options tree, like WindTools.
function EH:InsertOptions()
    local engine = ElvUI and ElvUI[1]
    if not engine or not engine.Options then return end
    local label = self:IconLabel("housing", self:Brand())
    engine.Options.args.ElementHousing = self.options
    if self.headerOptions ~= engine.Options then
        engine.Options.name = (engine.Options.name or "ElvUI") .. " + " .. label .. " " .. self.version
        self.headerOptions = engine.Options
    end
end

-- Register through ElvUI's public plugin library, or provide native settings when ElvUI is absent.
function EH:RegisterOptions()
    self:BuildOptions()
    local engine = ElvUI and ElvUI[1]
    local plugin = engine and engine.Libs and engine.Libs.EP
    if not plugin and LibStub then plugin = LibStub("LibElvUIPlugin-1.0", true) end
    if engine and plugin then
        plugin:RegisterPlugin(self.name, function() self:InsertOptions() end)
        if engine.Options then self:InsertOptions() end
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = CreateFrame("Frame")
        panel:Hide()
        panel.name = self.name
        local title = self:Label(panel, "ElementHousing " .. self.version, 18); title:SetPoint("TOPLEFT", 16, -16)
        local help = self:Label(panel, "Use the configuration window to adjust all settings.\nElvUI adds these pages to its own settings tree when installed.", 13)
        help:SetPoint("TOPLEFT", 16, -50)
        local open = self:Button(panel, "Open configuration", 200, function() self:StandaloneOptions() end, "general")
        open:SetPoint("TOPLEFT", 16, -100)
        self.nativeCategory = Settings.RegisterCanvasLayoutCategory(panel, self.name)
        Settings.RegisterAddOnCategory(self.nativeCategory)
    end
end

-- Open the requested ElvUI page or the same editable settings in the fixed native fallback.
function EH:OpenOptions()
    local engine = ElvUI and ElvUI[1]
    if engine and engine.ToggleOptions then
        engine:ToggleOptions("ElementHousing")
    else self:StandaloneOptions() end
end

-- Traverse the existing schema to provide every setting without an extra configuration library.
function EH:StandaloneOptions()
    if not self.configFrame then
        local frame = CreateFrame("Frame", "ElementHousingConfig", UIParent, "BackdropTemplate")
        frame:Hide(); self:Skin(frame); frame:SetSize(670, 620); frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
        local title = self:Label(frame, self:Brand() .. " settings", 17); title:SetPoint("TOPLEFT", 14, -14)
        local close = self:Button(frame, "Close", 80, function() frame:Hide() end); close:SetPoint("TOPRIGHT", -12, -10)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -48); scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        local content = CreateFrame("Frame", nil, scroll); content:SetSize(620, 1); scroll:SetScrollChild(content)
        local y = 0
        -- Render ordered sections from the shared ElvUI options schema.
        local function section(group)
            local children = {}
            for _, option in pairs(group.args or {}) do children[#children + 1] = option end
            table.sort(children, function(a, b) return a.order < b.order end)
            if group ~= self.options then
                local heading = self:Label(content, group.name, 14); heading:SetPoint("TOPLEFT", 0, -y); y = y + 28
            end
            for _, option in ipairs(children) do
                if option.type == "group" then section(option)
                elseif option.type == "description" then
                    local text = self:Label(content, option.name, 12); text:SetPoint("TOPLEFT", 0, -y)
                    text:SetWidth(590); text:SetWordWrap(true); y = y + text:GetStringHeight() + 14
                elseif option.type == "execute" then
                    local button = self:Button(content, option.name, 280, option.func); button:SetPoint("TOPLEFT", 0, -y); y = y + 36
                elseif option.type == "toggle" then
                    local button = self:Button(content, "", 590, function(widget)
                        option.set(nil, not option.get()); widget.text:SetText(option.name .. ": " .. (option.get() and "On" or "Off"))
                    end)
                    button.text:SetText(option.name .. ": " .. (option.get() and "On" or "Off"))
                    button:SetPoint("TOPLEFT", 0, -y); y = y + 36
                    -- Refresh stale values when settings changed through another control.
                    button:SetScript("OnShow", function(widget) widget.text:SetText(option.name .. ": " .. (option.get() and "On" or "Off")) end)
                elseif option.type == "range" then
                    local text = self:Label(content, option.name, 12); text:SetPoint("TOPLEFT", 0, -y)
                    local edit = self:Edit(content, 95); edit:SetPoint("TOPLEFT", 480, -y + 5); edit:SetText(tostring(option.get()))
                    -- Validate numeric text before changing geometry or rendering settings.
                    edit:SetScript("OnEnterPressed", function(widget)
                        local value = self:Clamp(tonumber(widget:GetText()), option.min, option.max, option.get())
                        value = math.floor(value / option.step + 0.5) * option.step
                        option.set(nil, value); widget:SetText(tostring(value)); widget:ClearFocus()
                    end)
                    edit:SetScript("OnShow", function(widget) widget:SetText(tostring(option.get())) end)
                    y = y + 36
                end
            end
        end
        section(self.options); content:SetHeight(y)
        tinsert(UISpecialFrames, "ElementHousingConfig"); self.configFrame = frame
    end
    self.configFrame:Show()
end
