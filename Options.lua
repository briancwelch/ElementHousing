local _, EH = ...

-- Define an account-wide behavior or layout setting in the native ElvUI options tree.
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
    -- ElvUI reserves sidebar orders 1-5 for core pages and 6 for plugin pages.
    local options = { type = "group", order = 6, childGroups = "tree", name = self:IconLabel("housing", self:Brand()), args = {} }
    options.args.intro = { type = "description", order = 1, fontSize = "medium",
        name = self:Brand() .. " " .. self.version .. "\nNative housing catalog, blueprints, and neighborhood/house information. Account-wide settings. Appearance follows ElvUI settings. nMediaTag icons and WindTools integration are optional." }
    options.args.open = { type = "execute", name = "Open catalog", order = 2, func = function() self:Show("catalog") end }
    options.args.appearance = { type = "group", name = self:IconLabel("colors", "Window"), order = 10,
        childGroups = "tab", args = {
            layout = { type = "group", name = "Layout", order = 1, args = {
                elvui = { type = "description", order = 0, name = "Font, font size, outline, UI scale, colors, borders, and status-bar textures follow your ElvUI settings." },
                width = self:Setting("width", "Window width", "range", 3, "The window also supports dragging its bottom-right corner.", 760, 2000, 10),
                height = self:Setting("height", "Window height", "range", 4, "Dimensions are clamped to the current screen.", 480, 1300, 10),
                detailsWidth = self:Setting("detailsWidth", "Details width", "range", 5, "Automatically narrows on smaller windows.", 240, 460, 10),
                locked = self:Setting("locked", "Lock movement and size", "toggle", 6, "Lock the current window position and dimensions."),
                resizable = self:Setting("resizable", "Enable resize grip", "toggle", 7, "Resize from the bottom-right corner."),
                reset = { type = "execute", name = "Reset window geometry", order = 8, func = function()
                    self.db.position = nil
                    for _, key in ipairs({ "width", "height" }) do self.db.settings[key] = self.defaults.settings[key] end
                    if self.frame then self.frame:ClearAllPoints(); self.frame:SetPoint("CENTER"); self:ApplyWindowSettings() end
                end },
            } },
            text = { type = "group", name = "Catalog rows", order = 2, args = {
                rowHeight = self:Setting("rowHeight", "Row height", "range", 1, "Space available to item names and source information.", 38, 76, 2),
                showSource = self:Setting("showSource", "Show source and zone in rows", "toggle", 3),
                showCounts = self:Setting("showCounts", "Show owned / missing counts", "toggle", 4),
                showTooltips = self:Setting("showTooltips", "Show native item tooltips", "toggle", 5),
            } },
        } }
    options.args.catalog = { type = "group", name = self:IconLabel("collection", "Catalog"), order = 20,
        childGroups = "tab", args = {
            filters = { type = "group", name = "Filter behavior", order = 1, args = {
                help = { type = "description", order = 0, name = "Combine ownership, source, zone, vendor, expansion, purchase currency, profession, category, size, quality, placement, and tags. Expansion uses native catalog tags or item metadata. Currency choices include verified native costs and vendors you have visited; unknown costs remain selectable. My professions checks all detected primary and secondary professions on the current character and updates when skills change. Search supports quoted phrases, -exclusions, name:, zone:, vendor:, source:, profession:, and id:." },
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
    options.args.waypoints = { type = "group", name = self:IconLabel("teleports", "Vendors"), order = 40, args = {
        help = { type = "description", order = 0, name = "Select a vendor item and use Vendor waypoint, or right-click its catalog row. Destinations use Blizzard's tracking, recorded merchant visits, then the bundled known-vendor library. Known library vendors work without visiting first. Unlisted vendors can still be learned by opening their shop. Unknown locations preserve your existing pin." },
        superTrack = self:Setting("superTrack", "Super-track vendor waypoints", "toggle", 1),
        waypointConfirm = self:Setting("waypointConfirm", "Confirm replacing an existing map waypoint", "toggle", 2),
        merchantOwnedChecks = self:Setting("merchantOwnedChecks", "Show owned decor checkmarks", "toggle", 3,
            "Show a green check on vendor decor icons when your account owns a copy in storage, placed in a house, or awaiting redemption. Enabled by default. Supports WindTools' expanded merchant pages."),
    } }
    options.args.launcher = { type = "group", name = self:IconLabel("menu", "Launcher and support"), order = 50, args = {
        minimap = self:Setting("minimap", "Show minimap icon", "toggle", 1,
            "Standard LibDBIcon launcher, compatible with WindTools minimap collectors. Left-click opens the window; right-click opens settings."),
        help = { type = "description", order = 2, name = "/eh - toggle\n/eh catalog - catalog\n/eh blueprints - blueprint library\n/eh neighborhood - current neighborhood\n/eh house - owned houses\n/eh missing - missing decor\n/eh zone - missing decor in this zone\n/eh config - settings\n\nElvUI is required and controls appearance. Bundled control icons are used unless nMediaTag is loaded. WindTools can collect the branded minimap launcher and add its configured window shadows." },
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

-- Register the configuration only through ElvUI's native plugin library.
function EH:RegisterOptions()
    self:BuildOptions()
    local engine = ElvUI[1]
    engine.Libs.EP:RegisterPlugin(self.name, function() self:InsertOptions() end)
end

-- Open the native ElementHousing page in ElvUI's settings tree.
function EH:OpenOptions()
    ElvUI[1]:ToggleOptions("ElementHousing")
end
