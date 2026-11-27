-------------------------------------------------------------------------------
-- Adventure Tracker: eligible missing quests in the current zone.
-------------------------------------------------------------------------------
local _, ns = ...

local QUEST_ICON = 134400
local candidateCache = {}
local reverseMap, reverseOverride

local function Materialize(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or type(loadstring) ~= "function" then return nil end
    local chunk = loadstring(value)
    if type(chunk) ~= "function" then return nil end
    local ok, result = pcall(chunk)
    if ok and type(result) == "table" then return result end
    return nil
end

local function ResolveZoneTables()
    if reverseMap or reverseOverride then return reverseMap, reverseOverride end
    local library = _G.LibQuestieDB
    if not (library and library.Support and type(library.Support.Get) == "function") then return nil end
    local ok, zones = pcall(library.Support.Get, "ZoneDB")
    if not ok or type(zones) ~= "table" then return nil end
    local private = type(zones.private) == "table" and zones.private or {}
    reverseMap = Materialize(zones.uiMapIdToAreaId or private.uiMapIdToAreaId) or {}
    reverseOverride = Materialize(zones.uiMapIdToAreaIdOverride or private.uiMapIdToAreaIdOverride) or {}
    return reverseMap, reverseOverride
end

local function CurrentAreaID(mapID)
    mapID = tonumber(mapID)
    if not mapID then return nil end
    local regular, override = ResolveZoneTables()
    if not regular then return nil end
    local visited = {}
    for _ = 1, 8 do
        if visited[mapID] then return nil end
        visited[mapID] = true
        local areaID = tonumber(override[mapID]) or tonumber(regular[mapID])
        if areaID then return areaID end
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local parent = info and tonumber(info.parentMapID)
        if not parent or parent <= 0 then return nil end
        mapID = parent
    end
end

local function CharacterExpansionKey(areaID)
    return tostring(ns.CharacterKey()) .. ":" .. tostring(areaID)
end

local function IsExpanded(areaID)
    local source = ns.Get("zoneQuestExpandedByCharacter")
    return type(source) == "table" and source[CharacterExpansionKey(areaID)] == true
end

local function ToggleExpanded(areaID)
    local source = ns.Get("zoneQuestExpandedByCharacter")
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do copy[key] = value end
    end
    local key = CharacterExpansionKey(areaID)
    copy[key] = not (copy[key] == true)
    ns.Set("zoneQuestExpandedByCharacter", copy)
end

local function BitSet(mask, flag)
    mask, flag = tonumber(mask) or 0, tonumber(flag) or 0
    return flag > 0 and mask % (flag * 2) >= flag
end

local function CandidateIDs(questDB, areaID)
    local key = tostring(areaID)
    if candidateCache[key] then return candidateCache[key] end
    local ids = type(questDB.GetAllIds) == "function" and questDB.GetAllIds() or {}
    local candidates = {}
    for index = 1, #ids do
        local questID = ids[index]
        if tonumber(ns.QuestData.Value(questDB, "zoneOrSort", questID)) == areaID then
            candidates[#candidates + 1] = questID
        end
    end
    candidateCache[key] = candidates
    return candidates
end

local function QuestScore(questDB, questID, source)
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local questLevel = tonumber(ns.QuestData.Value(questDB, "questLevel", questID)) or playerLevel
    local requiredLevel = tonumber(ns.QuestData.Value(questDB, "requiredLevel", questID)) or 0
    local score = 1000 - math.abs(questLevel - playerLevel) * 20
    if questLevel >= playerLevel - 3 and questLevel <= playerLevel + 3 then score = score + 120 end
    if requiredLevel > 0 and requiredLevel >= playerLevel - 2 then score = score + 40 end
    if (tonumber(ns.QuestData.Value(questDB, "requiredClasses", questID)) or 0) > 0 then score = score + 80 end
    if ns.QuestData.Value(questDB, "requiredSkill", questID) then score = score + 70 end
    if source and source:find("^Quest giver:", 1, false) then score = score + 35 end
    return score, questLevel
end

local function QuestRow(candidate, indent)
    local label = candidate.questLevel > 0
        and string.format("%s (Level %d)", candidate.name, candidate.questLevel)
        or candidate.name
    return {
        key = "zone-quest-" .. tostring(candidate.id),
        label = label,
        detail = candidate.source,
        tooltip = candidate.source
            .. "\n\nKnown available quest. Adventure Tracker intentionally does not show coordinates, routing, objectives or waypoint guidance.",
        state = "info",
        icon = candidate.icon or QUEST_ICON,
        indentLevel = indent,
    }
end

local function Build()
    if not ns.Get("showZoneQuests") then return {} end
    local data = ns.QuestData
    if type(data) ~= "table" then return {} end
    local questDB, npcDB, itemDB = data.GetEntities()
    if not questDB then
        return {
            id = "zone-quests-provider",
            title = "Missing Quests",
            rows = {{
                key = "zone-quests-provider",
                label = "Zone quest data unavailable",
                detail = "Install, enable or update QuestieDB to list known missing quests.",
                tooltip = "QuestieDB is used only as a data provider. Adventure Tracker does not copy its database, show coordinates or invoke Questie's routing.",
                state = "unavailable",
                icon = QUEST_ICON,
            }},
        }
    end

    local _, mapID = ns.GetZoneName()
    local areaID = CurrentAreaID(mapID)
    if not areaID then
        return {
            id = "zone-quests-map",
            title = "Missing Quests",
            rows = {{
                key = "zone-quests-map",
                label = "This zone is not mapped by QuestieDB",
                detail = "Update QuestieDB or continue playing so its Forever data can mature.",
                state = "unavailable",
                icon = QUEST_ICON,
            }},
        }
    end

    local candidates = {}
    local ids = CandidateIDs(questDB, areaID)
    for index = 1, #ids do
        local questID = ids[index]
        local specialFlags = tonumber(data.Value(questDB, "specialFlags", questID)) or 0
        local questFlags = tonumber(data.Value(questDB, "questFlags", questID)) or 0
        local recurring = BitSet(specialFlags, 1) or BitSet(questFlags, 4096) or BitSet(questFlags, 32768)
        if not recurring and not data.IsComplete(questID) and not data.IsInLog(questID)
            and data.RequirementsMet(questDB, questID) then
            local source, icon = data.Starter(questDB, npcDB, itemDB, questID)
            if source then
                local score, questLevel = QuestScore(questDB, questID, source)
                candidates[#candidates + 1] = {
                    id = questID,
                    name = data.Value(questDB, "name", questID) or ("Quest " .. tostring(questID)),
                    source = source,
                    icon = icon,
                    questLevel = questLevel,
                    score = score,
                }
            end
        end
    end
    if #candidates == 0 then return {} end
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.questLevel ~= b.questLevel then return a.questLevel < b.questLevel end
        return a.name < b.name
    end)

    local expanded = IsExpanded(areaID)
    local rows = { QuestRow(candidates[1], 0) }
    if #candidates > 1 then
        rows[#rows + 1] = {
            key = "zone-quests-expand-" .. tostring(areaID),
            label = string.format("%s %d additional missing quest%s",
                expanded and "− Hide" or "+ Show", #candidates - 1, #candidates == 2 and "" or "s"),
            detail = expanded
                and "Collapse the complete eligible quest list."
                or "Expand the complete eligible quest list; no locations or objectives are shown.",
            tooltip = "The recommended quest remains visible. Click to show or hide every other eligible quest known to QuestieDB for this zone.",
            state = "info",
            icon = QUEST_ICON,
            onClick = function() ToggleExpanded(areaID) end,
        }
        if expanded then
            for index = 2, #candidates do rows[#rows + 1] = QuestRow(candidates[index], 1) end
        end
    end
    return {
        id = "zone-quests",
        title = string.format("Missing Quests (%d)", #candidates),
        rows = rows,
    }
end

ns.RegisterProvider("zone-quests", 22, Build)

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
    "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "SKILL_LINES_CHANGED", "ADDON_LOADED",
}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and (...) == "QuestieDB" then
        candidateCache, reverseMap, reverseOverride = {}, nil, nil
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        reverseMap, reverseOverride = nil, nil
    end
    if ns.RequestRefresh then ns.RequestRefresh() end
end)
