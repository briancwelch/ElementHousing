local _, EH = ...
EH.professionNames = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting",
    [202] = "Engineering", [182] = "Herbalism", [773] = "Inscription", [755] = "Jewelcrafting",
    [165] = "Leatherworking", [186] = "Mining", [393] = "Skinning", [197] = "Tailoring",
    [185] = "Cooking", [356] = "Fishing", [794] = "Archaeology" }
EH.sourceNames = { all = "All sources", vendor = "Vendor", drop = "Drop / encounter",
    achievement = "Achievement", quest = "Quest", profession = "Profession", unknown = "Unknown / other" }
EH.sourceIcons = { all = "collection", vendor = "shop", drop = "dungeon", achievement = "achievement",
    quest = "quest", profession = "professions", unknown = "help" }

-- Use nMediaTag glyphs for acquisition choices without adding artwork markup to source searches.
function EH:SourceChoices()
    local choices = {}
    for kind, name in pairs(self.sourceNames) do choices[kind] = self:IconLabel(self.sourceIcons[kind], name) end
    return choices
end

-- Resolve character, recipe, and selector skill lines to the same base profession ID.
function EH:ProfessionID(id, info)
    if not self:Readable(id) or not self:Readable(info) then return nil end
    if type(info) == "table" and not id then id = info.professionID end
    local seen = {}
    for _ = 1, 8 do
        if not self:Readable(id) or type(id) ~= "number" or id <= 0 or id % 1 ~= 0 or seen[id] then return nil end
        seen[id] = true
        info = info or self:Call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
        local parent = type(info) == "table" and info.parentProfessionID or nil
        if not self:Readable(parent) then return nil end
        if parent == nil or parent == 0 or parent == id then return id end
        id, info = parent, nil
    end
end

-- Pack every profession slot so optional getter handling does not lose secondary skills.
local function CharacterProfessionIndexes()
    return { GetProfessions() }
end

-- Return only the public name and skill-line ID from the legacy profession tuple.
local function CharacterProfession(index)
    local name, _, _, _, _, _, id = GetProfessionInfo(index)
    return name, id
end

-- Rebuild this character's complete primary/secondary skill set after learning or unlearning skills.
function EH:UpdateProfessions()
    self.professions = {}
    for id, english in pairs(self.professionNames) do
        self.professionNames[id] = self:Call(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName, id) or english
    end
    self.professionsKnown = type(GetProfessions) == "function" and type(GetProfessionInfo) == "function"
    local indexes = self.professionsKnown and self:Call(CharacterProfessionIndexes)
    if type(indexes) == "table" then
        for _, index in pairs(indexes) do
            local name, id
            if self:Readable(index) then name, id = self:Call(CharacterProfession, index) end
            local info = self:Call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
            local rootID = self:ProfessionID(id, info)
            if rootID then
                self.professions[rootID] = true
                -- Keep generic names searchable when the character reports an expansion skill name.
                self.professionNames[rootID] = self:Call(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName, rootID)
                    or self.professionNames[rootID] or (info and info.parentProfessionName) or name
            else self.professionsKnown = false end
        end
    else self.professionsKnown = false end
    if self.db then self:ApplyFilters() end
end

-- Change one filter without disturbing the rest of a useful browse/search combination.
function EH:SetFilter(key, value)
    self.filters[key] = value
    if key == "category" then self.filters.subcategory = nil end
    self.notice = nil
    self.scrollOffset = 0
    self:ApplyFilters()
end

-- Restore default filters while retaining account favorites and saved presets.
function EH:ResetFilters()
    self.db.filters = self:Copy(self.defaults.filters)
    self.filters = self.db.filters
    self.scrollOffset = 0
    if self.searchBox then self.searchBox:SetText("") end
    self:ApplyFilters()
end

-- Save bounded, plain preset names; store independent copies of the filter state.
function EH:SavePreset(name)
    name = self:Plain(name):gsub("|", ""):match("^%s*(.-)%s*$"):sub(1, 50)
    if name == "" then return false end
    local count = 0
    for _ in pairs(self.db.presets) do count = count + 1 end
    if count >= 30 and not self.db.presets[name] then self:Notify("Keep at most 30 filter presets."); return false end
    self.db.presets[name] = self:Copy(self.filters)
    self:Notify("Saved filter preset: " .. name)
    return true
end

-- Load a preset as a copy so further changes cannot alter the saved version.
function EH:LoadPreset(name)
    if not self.db.presets[name] then return end
    self.db.filters = self:Copy(self.db.presets[name])
    self:Defaults(self.db.filters, self.defaults.filters)
    self.filters, self.scrollOffset = self.db.filters, 0
    if self.searchBox then self.searchBox:SetText(self.filters.search) end
    self:ApplyFilters()
end

-- Normalize a map to its containing zone while preserving continents as distinct maps.
function EH:ZoneMap(mapID)
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    local seen = {}
    for _ = 1, 8 do
        if not mapID or seen[mapID] then break end
        seen[mapID] = true
        local info = self:Call(C_Map and C_Map.GetMapInfo, mapID)
        if not info or not info.parentMapID or info.parentMapID == 0 or info.mapType <= zoneType then break end
        mapID = info.parentMapID
    end
    return mapID
end

-- Tokenize literal searches with quoted phrases, exclusions, and optional field prefixes.
function EH:SearchTokens(query)
    local tokens, index = {}, 1
    query = query:sub(1, 256)
    while index <= #query do
        local first, last = query:find("%S", index)
        if not first then break end
        index = last
        local negative = query:sub(index, index) == "-"
        if negative then index = index + 1 end
        local field, stop = query:sub(index):match("^(%a+):()")
        if stop then index = index + stop - 1 end
        local word
        if query:sub(index, index) == '"' then
            local finish = query:find('"', index + 1, true) or (#query + 1)
            word, index = query:sub(index + 1, finish - 1), finish + 1
        else
            local finish = query:find("%s", index) or (#query + 1)
            word, index = query:sub(index, finish - 1), finish + 1
        end
        if word ~= "" then tokens[#tokens + 1] = { word = word:lower(), field = field and field:lower(), negative = negative } end
    end
    return tokens
end

-- Match all literal tokens; use plain substring matching rather than user-supplied patterns.
function EH:MatchesSearch(entry, tokens)
    for _, token in ipairs(tokens) do
        local haystack = token.field and entry.searchFields[token.field] or entry.searchText
        if not haystack then haystack = entry.searchText end
        local found = haystack:find(token.word, 1, true) ~= nil
        if found == token.negative then return false end
    end
    return true
end

-- Apply the same eligibility rules to every profession, with configurable ownership and unknown policies.
function EH:MatchesProfession(entry, mode)
    if mode == "all" then return true end
    if self.db.settings.professionMissingOnly and entry.owned > 0 then return true end
    if entry.nonProfessionRoute then return true end
    if mode == "none" and entry.sources.profession then return false end
    -- Loading map/waypoint data does not invalidate an already known profession requirement.
    if not next(entry.professionIDs) then return self.db.settings.includeUnknownProfession end
    if mode == "none" then return false end
    if mode == "mine" then
        for id in pairs(entry.professionIDs) do if self.professions[id] then return true end end
        if not self.professionsKnown then return self.db.settings.includeUnknownProfession end
        return false
    end
    local id = self:ProfessionID(tonumber(mode))
    return id ~= nil and entry.professionIDs[id] == true
end

-- Match native zone IDs and localized zone names, optionally including child maps.
function EH:MatchesZone(entry, mode)
    if mode == "all" then return true end
    if type(mode) == "string" and mode:sub(1, 5) == "name:" then
        local selected = mode:sub(6):lower()
        for name in pairs(entry.zoneNames or {}) do if name:lower() == selected then return true end end
        return entry.zoneName and entry.zoneName:lower() == selected or false
    end
    local mapID = mode == "current" and self:Call(C_Map and C_Map.GetBestMapForUnit, "player") or tonumber(mode)
    if not mapID then return self.db.settings.includeUnknownZone end
    if self.db.settings.includeSubzones then mapID = self:ZoneMap(mapID) end
    if not next(entry.maps) and not next(entry.zoneNames or {}) and not entry.zoneName then return self.db.settings.includeUnknownZone end
    for candidate in pairs(entry.maps) do
        if (self.db.settings.includeSubzones and self:ZoneMap(candidate) or candidate) == mapID then return true end
    end
    if entry.unknownLocation then return self.db.settings.includeUnknownZone end
    return false
end

-- Native tag choices use OR within a group and AND between different groups.
function EH:MatchesTags(info)
    local selected, tags, grouped = self.filters.tags, info.dataTagsByID or {}, {}
    for _, group in ipairs(self.tagGroups or {}) do
        local active, matched = false, false
        for _, tag in ipairs(group.tags or {}) do
            local id = tag.tagID
            if selected[id] or selected[tostring(id)] then
                active, grouped[id] = true, true
                if tags[id] then matched = true end
            end
        end
        if active and not matched then return false end
    end
    for id, active in pairs(selected) do
        if active and not grouped[tonumber(id)] and not tags[tonumber(id)] then return false end
    end
    return true
end

-- Combine filters without mistaking unverified ownership or sources for an acquisition route.
function EH:Matches(entry, tokens)
    local f = self.filters
    if f.ownership == "missing" and entry.owned > 0 then return false end
    if f.ownership == "owned" and entry.owned == 0 then return false end
    if f.ownership == "stored" and entry.stored == 0 then return false end
    if f.ownership == "favorites" and not self.db.favorites[entry.key] then return false end
    if f.source ~= "all" and not entry.sources[f.source] then return false end
    if f.vendor and f.vendor ~= "all" and not (entry.vendorNames or {})[f.vendor] and entry.vendorName ~= f.vendor then return false end
    if f.category and f.category ~= "all" and not entry.categories[tonumber(f.category)] then return false end
    if f.subcategory and f.subcategory ~= "all" and not entry.subcategories[tonumber(f.subcategory)] then return false end
    if f.quality ~= "all" and entry.info.quality ~= tonumber(f.quality) then return false end
    if f.size ~= "all" and entry.info.size ~= tonumber(f.size) then return false end
    if f.placement == "indoor" and not entry.info.isAllowedIndoors then return false end
    if f.placement == "outdoor" and not entry.info.isAllowedOutdoors then return false end
    if f.customizable and not entry.info.canCustomize then return false end
    if not self:MatchesTags(entry.info) then return false end
    return self:MatchesProfession(entry, f.profession) and self:MatchesZone(entry, f.zone)
        and self:MatchesSearch(entry, tokens)
end

-- Filter and stably sort the cached catalog without rerunning a server search per keystroke.
function EH:ApplyFilters()
    if not self.db then return end
    local tokens, results, owned = self:SearchTokens(self.filters.search or ""), {}, 0
    for _, entry in ipairs(self.entries) do
        if entry.owned > 0 then owned = owned + 1 end
        if self:Matches(entry, tokens) then results[#results + 1] = entry end
    end
    local sort = self.filters.sort
    -- Resolve ties by name and ID so scroll order remains predictable after data updates.
    table.sort(results, function(a, b)
        if sort == "owned" and a.owned ~= b.owned then return a.owned > b.owned end
        if sort == "missing" and (a.owned == 0) ~= (b.owned == 0) then return a.owned == 0 end
        if sort == "zone" and (a.zoneName or "") ~= (b.zoneName or "") then return (a.zoneName or "") < (b.zoneName or "") end
        if sort == "source" and a.sourceLabel ~= b.sourceLabel then return a.sourceLabel < b.sourceLabel end
        if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
        return a.key < b.key
    end)
    self.results, self.ownedCount = results, owned
    if self.frame then self:RenderList(); self:RenderFilters(); self:RenderStatus() end
end
