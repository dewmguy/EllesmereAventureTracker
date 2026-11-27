-------------------------------------------------------------------------------
-- Adventure Tracker: profession progress and local-opportunity provider.
-------------------------------------------------------------------------------
local _, ns = ...

local LEGACY_PROFESSIONS = {
    [164] = true, -- Blacksmithing
    [165] = true, -- Leatherworking
    [171] = true, -- Alchemy
    [197] = true, -- Tailoring
    [202] = true, -- Engineering
    [333] = true, -- Enchanting
}

local GATHERING_HINTS = {
    [182] = "Watch the minimap for herbs while you travel through %s.",
    [186] = "Watch the minimap for ore veins while you travel through %s.",
    [393] = "Beasts in %s may provide skinning opportunities.",
    [356] = "Local waters in %s may advance Fishing or supply Cooking materials.",
}

local GATHERING_KINDS = {
    [182] = "herb", -- Herbalism
    [186] = "ore",  -- Mining
    [393] = "skin", -- Skinning
    [356] = "fish", -- Fishing
}

local CHECKPOINTS = { 150, 225, 300 }

local function ProfessionList()
    if not GetProfessions or not GetProfessionInfo then return {} end
    local ok, primary1, primary2, archaeology, fishing, cooking, firstAid = pcall(GetProfessions)
    if not ok then return {} end
    -- GetProfessions has nil slots (normally Archaeology on Forever). Iterating
    -- to #books can stop at that hole and omit Fishing, Cooking or First Aid.
    local books = {
        [1] = primary1,
        [2] = primary2,
        [3] = archaeology,
        [4] = fishing,
        [5] = cooking,
        [6] = firstAid,
    }
    local result = {}
    for i = 1, 6 do
        local index = books[i]
        if index then
            local ok, name, icon, rank, maxRank, numSpells, spellOffset, skillLineID = pcall(GetProfessionInfo, index)
            if ok and name then
                result[#result + 1] = {
                    name = name,
                    icon = icon,
                    rank = tonumber(rank) or 0,
                    maxRank = tonumber(maxRank) or 0,
                    skillLineID = skillLineID,
                }
            end
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

local function GatheringSummary(mapID, kind)
    if kind ~= "herb" and kind ~= "ore" and kind ~= "fish" then return nil end
    local catalog = ns.GatheringCatalog
    local zoneData = catalog and catalog.zones and mapID and catalog.zones[mapID]
    local entries = zoneData and zoneData[kind]
    if type(entries) ~= "table" or #entries == 0 then return nil end
    local parts = {}
    local shown = math.min(3, #entries)
    for i = 1, shown do
        local node = entries[i]
        parts[#parts + 1] = string.format("%s (%d)", node.name, node.count)
    end
    local more = #entries - shown
    local suffix = more > 0 and string.format(" +%d more", more) or ""
    return table.concat(parts, ", ") .. suffix .. " • known locations, most to least."
end

local function AddGatheringProgress(rows, profession)
    local cap = profession.maxRank > 0 and profession.maxRank or 300
    local remaining = math.max(0, cap - profession.rank)
    rows[#rows + 1] = {
        key = "skill-" .. tostring(profession.skillLineID),
        label = string.format("%s %d/%d", profession.name, profession.rank, cap),
        detail = remaining > 0
            and string.format("%d skill point%s to the current rank cap.", remaining, remaining == 1 and "" or "s")
            or "Current profession rank complete.",
        state = remaining == 0 and "ready" or (remaining <= 10 and "warning" or "info"),
        icon = profession.icon,
    }
end

local function NextCheckpoint(rank)
    for i = 1, #CHECKPOINTS do
        if rank < CHECKPOINTS[i] then return CHECKPOINTS[i] end
    end
end

local function Build()
    if not ns.Get("showProfessions") then return {} end
    local professions = ProfessionList()
    local progressRows, localRows = {}, {}
    local zone, mapID = ns.GetZoneName()

    for i = 1, #professions do
        local profession = professions[i]
        if ns.Get("showProfessionCaps") and profession.maxRank > 0
            and profession.rank >= profession.maxRank and profession.maxRank < 300 then
            progressRows[#progressRows + 1] = {
                key = "cap-" .. tostring(profession.skillLineID),
                label = string.format("%s %d/%d is capped", profession.name, profession.rank, profession.maxRank),
                detail = "Visit a trainer for the next profession rank.",
                state = "missing",
                icon = profession.icon,
            }
        elseif ns.Get("showProfessionProgress") and LEGACY_PROFESSIONS[profession.skillLineID] then
            local checkpoint = NextCheckpoint(profession.rank)
            if checkpoint then
                local remaining = checkpoint - profession.rank
                progressRows[#progressRows + 1] = {
                    key = "checkpoint-" .. tostring(profession.skillLineID),
                    label = string.format("%s %d/%d", profession.name, profession.rank, checkpoint),
                    detail = string.format("%d skill point%s to the next Legacy checkpoint.", remaining, remaining == 1 and "" or "s"),
                    state = remaining <= 10 and "warning" or "info",
                    icon = profession.icon,
                }
            elseif ns.Get("showCompletedProfessions") then
                progressRows[#progressRows + 1] = {
                    key = "complete-" .. tostring(profession.skillLineID),
                    label = profession.name .. " 300/300",
                    detail = "All profession Legacy skill checkpoints reached.",
                    state = "ready",
                    icon = profession.icon,
                }
            end
        elseif ns.Get("showProfessionProgress") and GATHERING_KINDS[profession.skillLineID] then
            AddGatheringProgress(progressRows, profession)
        end

        if ns.Get("showProfessionZoneHints") and GATHERING_HINTS[profession.skillLineID] then
            local kind = GATHERING_KINDS[profession.skillLineID]
            local summary = GatheringSummary(mapID, kind)
            localRows[#localRows + 1] = {
                key = "local-" .. tostring(profession.skillLineID),
                label = (summary and (profession.name .. " nodes in ") or (profession.name .. " in ")) .. zone,
                detail = summary or string.format(GATHERING_HINTS[profession.skillLineID], zone),
                state = "info",
                icon = profession.icon,
            }
        end
    end

    local sections = {}
    if #progressRows > 0 then
        sections[#sections + 1] = { id = "profession-progress", title = "Profession Checkpoints", rows = progressRows }
    end
    if #localRows > 0 then
        sections[#sections + 1] = { id = "profession-local", title = "Profession Opportunities", rows = localRows }
    end
    return sections
end

ns.RegisterProvider("professions", 30, Build)
