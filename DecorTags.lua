local _, EH = ...
EH.decorFacets = { "culture", "material", "color", "room" }
EH.decorFacetLabels = { culture = "Culture", material = "Material", color = "Color", room = "Room type" }

-- Attach community classifications by stable item ID, keeping absent classifications unknown.
function EH:ReadDecorTags(entry)
    local id = entry.info.itemID
    entry.decorTags = self:Readable(id) and type(id) == "number" and self.decorTags[id] or {}
    entry.decorTags = entry.decorTags or {}
end

-- Combine one choice per facet with existing collection, acquisition, and search filters.
function EH:MatchesDecorTags(entry)
    for _, facet in ipairs(self.decorFacets) do
        local selected = self.filters[facet]
        if selected and selected ~= "all" then
            local values, matched = (entry.decorTags or {})[facet] or {}, false
            if selected == "unknown" then matched = #values == 0
            else
                for _, id in ipairs(values) do if tostring(id) == tostring(selected) then matched = true; break end end
            end
            if not matched then return false end
        end
    end
    return true
end

-- Offer only classifications present in the loaded catalog, plus all and unclassified choices.
function EH:DecorTagChoices(facet)
    local choices = { all = "Any " .. self.decorFacetLabels[facet]:lower(), unknown = "Unclassified" }
    for _, entry in ipairs(self.entries) do
        for _, id in ipairs((entry.decorTags or {})[facet] or {}) do choices[tostring(id)] = self.decorTagNames[facet][id] end
    end
    return choices
end

-- Format attributed classifications for catalog details and field-specific searches.
function EH:DecorTagText(entry, facet)
    local names = {}
    for _, id in ipairs((entry.decorTags or {})[facet] or {}) do names[#names + 1] = self.decorTagNames[facet][id] end
    table.sort(names)
    return table.concat(names, ", ")
end
