-------------------------------------------------------------------------------
-- Adventure Tracker: expandable quest progress for zones the player visited.
-------------------------------------------------------------------------------
local _, ns = ...

local QUEST_ICON = 134400
local candidateCache = {}
local reverseMap, reverseOverride, questXP
local lastRecordedAreaID

local function IsSecret(value)
    return _G.issecretvalue and _G.issecretvalue(value)
end

local function Materialize(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or type(loadstring) ~= "function" then return nil end
    local chunk = loadstring(value)
    if type(chunk) ~= "function" then return nil end
    local ok, result = pcall(chunk)
    if ok and type(result) == "table" then return result end
    return nil
end

local function QuestieSupport(name)
    local library = _G.LibQuestieDB
    if not (library and library.Support and type(library.Support.Get) == "function") then return nil end
    local ok, support = pcall(library.Support.Get, name)
    return ok and type(support) == "table" and support or nil
end

local function ResolveZoneTables()
    if reverseMap or reverseOverride then return reverseMap, reverseOverride end
    local zones = QuestieSupport("ZoneDB")
    if not zones then return nil end
    local private = type(zones.private) == "table" and zones.private or {}
    reverseMap = Materialize(zones.uiMapIdToAreaId or private.uiMapIdToAreaId) or {}
    reverseOverride = Materialize(zones.uiMapIdToAreaIdOverride or private.uiMapIdToAreaIdOverride) or {}
    return reverseMap, reverseOverride
end

local function ResolveQuestXP()
    if questXP ~= nil then return questXP or nil end
    local support = QuestieSupport("QuestXP")
    questXP = support and type(support.db) == "table" and support.db or false
    return questXP or nil
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
ns.ResolveQuestieAreaID = CurrentAreaID

local function CharacterZoneKey(areaID)
    return tostring(ns.CharacterKey()) .. ":" .. tostring(areaID)
end

local function IsExpanded(areaID)
    local source = ns.Get("zoneQuestExpandedByCharacter")
    return type(source) == "table" and source[CharacterZoneKey(areaID)] == true
end

local function ToggleExpanded(areaID)
    local source = ns.Get("zoneQuestExpandedByCharacter")
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do copy[key] = value end
    end
    local key = CharacterZoneKey(areaID)
    copy[key] = not (copy[key] == true)
    ns.Set("zoneQuestExpandedByCharacter", copy)
end

local function PlayerIsOnTaxi()
    if type(UnitOnTaxi) ~= "function" then return false end
    local ok, value = pcall(UnitOnTaxi, "player")
    return ok and not IsSecret(value) and value == true
end

local function RecordCurrentZone()
    if PlayerIsOnTaxi() then return false end
    if type(IsInInstance) == "function" then
        local ok, inside = pcall(IsInInstance)
        if ok and not IsSecret(inside) and inside then return false end
    end

    local zoneName, mapID = ns.GetZoneName()
    local areaID = CurrentAreaID(mapID)
    if not areaID then return false end
    local key = CharacterZoneKey(areaID)
    local source = ns.Get("zoneQuestVisitedByCharacter")
    if lastRecordedAreaID == areaID and type(source) == "table" and source[key] then return false end

    local copy = {}
    if type(source) == "table" then
        for savedKey, value in pairs(source) do copy[savedKey] = value end
    end
    copy[key] = {
        areaID = areaID,
        mapID = mapID,
        name = type(zoneName) == "string" and zoneName ~= "" and zoneName or ("Zone " .. areaID),
        lastVisited = type(time) == "function" and time() or 0,
    }
    lastRecordedAreaID = areaID
    ns.Set("zoneQuestVisitedByCharacter", copy, true)
    return true
end

local function VisitedZones()
    local result = {}
    local source = ns.Get("zoneQuestVisitedByCharacter")
    if type(source) ~= "table" then return result end
    local prefix = tostring(ns.CharacterKey()) .. ":"
    for key, value in pairs(source) do
        if type(key) == "string" and key:sub(1, #prefix) == prefix and type(value) == "table" then
            local areaID = tonumber(value.areaID) or tonumber(key:sub(#prefix + 1))
            if areaID then
                result[#result + 1] = {
                    areaID = areaID,
                    mapID = tonumber(value.mapID),
                    name = type(value.name) == "string" and value.name or ("Zone " .. areaID),
                    lastVisited = tonumber(value.lastVisited) or 0,
                }
            end
        end
    end
    return result
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

local function AuraApplications(spellID)
    if ns.IsCombatRestricted and ns.IsCombatRestricted() then return nil end
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or IsSecret(aura) or type(aura) ~= "table" then return nil end
    local applications = aura.applications
    if IsSecret(applications) then return 0 end
    return math.max(0, tonumber(applications) or 0)
end

local function QuestXPMultiplier()
    local multiplier = 1
    if AuraApplications(377749) ~= nil then multiplier = multiplier + 0.5 end -- Joyous Journeys
    if AuraApplications(46668) ~= nil then multiplier = multiplier + 0.1 end -- Darkmoon Faire
    if AuraApplications(95987) ~= nil or AuraApplications(24705) ~= nil then
        multiplier = multiplier + 0.1 -- Hallow's End faction buffs
    end
    local wellRested = AuraApplications(429959)
    if wellRested then multiplier = multiplier + wellRested * 0.01 end
    return multiplier
end

local function AdjustedQuestXP(questID, xpMultiplier)
    local database = ResolveQuestXP()
    local row = database and database[questID]
    local questLevel = row and tonumber(row[1])
    local amount = row and tonumber(row[2])
    if not questLevel or questLevel <= 0 or not amount or amount <= 0 then return 0 end

    local playerLevel = tonumber(UnitLevel and UnitLevel("player")) or 0
    if type(GetMaxPlayerLevel) == "function" then
        local ok, maximum = pcall(GetMaxPlayerLevel)
        if ok and not IsSecret(maximum) and playerLevel >= (tonumber(maximum) or math.huge) then return 0 end
    end
    local multiplier = 2 * (questLevel - playerLevel) + 20
    multiplier = math.max(5, math.min(10, multiplier))
    amount = amount * multiplier / 10
    if amount <= 100 then
        amount = 5 * math.floor((amount + 2) / 5)
    elseif amount <= 500 then
        amount = 10 * math.floor((amount + 5) / 10)
    elseif amount <= 1000 then
        amount = 25 * math.floor((amount + 12) / 25)
    else
        amount = 50 * math.floor((amount + 25) / 50)
    end
    return math.floor(amount * (tonumber(xpMultiplier) or 1))
end

local function QuestMoney(questID)
    if type(GetQuestLogRewardMoney) ~= "function" then return nil end
    local ok, value = pcall(GetQuestLogRewardMoney, questID)
    if not ok or IsSecret(value) then return nil end
    value = tonumber(value)
    return value and math.max(0, math.floor(value)) or nil
end

local function FormatNumber(value)
    local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
    while true do
        local updated, count = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
        text = updated
        if count == 0 then return text end
    end
end

local function FormatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = string.format("%dg", gold) end
    if silver > 0 or gold > 0 then parts[#parts + 1] = string.format("%ds", silver) end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = string.format("%dc", copper) end
    return table.concat(parts, " ")
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

local function QuestRow(candidate)
    local label = candidate.questLevel > 0
        and string.format("%s (Level %d)", candidate.name, candidate.questLevel)
        or candidate.name
    local rewards = {}
    if candidate.xp > 0 then rewards[#rewards + 1] = FormatNumber(candidate.xp) .. " XP" end
    if candidate.money and candidate.money > 0 then rewards[#rewards + 1] = FormatMoney(candidate.money) end
    local tooltip = candidate.source
    if #rewards > 0 then tooltip = tooltip .. "\nRewards: " .. table.concat(rewards, ", ") end
    return {
        key = "zone-quest-" .. tostring(candidate.id),
        label = label,
        detail = candidate.source,
        tooltip = tooltip,
        state = "info",
        icon = candidate.icon or QUEST_ICON,
        indentLevel = 1,
    }
end

local function CandidatesForZone(data, questDB, npcDB, itemDB, zone, xpMultiplier)
    local candidates, totalXP, totalMoney, moneyKnown = {}, 0, 0, false
    local ids = CandidateIDs(questDB, zone.areaID)
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
                local xp, money = AdjustedQuestXP(questID, xpMultiplier), QuestMoney(questID)
                totalXP = totalXP + xp
                if money ~= nil then
                    moneyKnown = true
                    totalMoney = totalMoney + money
                end
                candidates[#candidates + 1] = {
                    id = questID,
                    name = data.Value(questDB, "name", questID) or ("Quest " .. tostring(questID)),
                    source = source,
                    icon = icon,
                    questLevel = questLevel,
                    score = score,
                    xp = xp,
                    money = money,
                }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.questLevel ~= b.questLevel then return a.questLevel < b.questLevel end
        return a.name < b.name
    end)
    return candidates, totalXP, totalMoney, moneyKnown
end

local function RewardSummary(totalXP, totalMoney, moneyKnown)
    local parts = {}
    if totalXP > 0 then parts[#parts + 1] = FormatNumber(totalXP) .. " XP" end
    if moneyKnown and totalMoney > 0 then parts[#parts + 1] = FormatMoney(totalMoney) end
    if #parts == 0 then return "Expand to review the available quests." end
    return "Total rewards: " .. table.concat(parts, ", ") .. "."
end

local function Build()
    if not ns.Get("showZoneQuests") then return {} end
    local data = ns.QuestData
    if type(data) ~= "table" then return {} end
    local questDB, npcDB, itemDB = data.GetEntities()
    if not questDB then
        return {
            id = "zone-quests-provider",
            title = "Quest Progress",
            rows = {{
                key = "zone-quests-provider",
                label = "Quest records unavailable",
                detail = "Enable QuestieDB and restart WoW to restore quest progress.",
                state = "unavailable",
                icon = QUEST_ICON,
            }},
        }
    end

    RecordCurrentZone()
    local _, currentMapID = ns.GetZoneName()
    local currentAreaID = CurrentAreaID(currentMapID)
    local zones = VisitedZones()
    local xpMultiplier = QuestXPMultiplier()
    local populated = {}
    for index = 1, #zones do
        local zone = zones[index]
        local candidates, totalXP, totalMoney, moneyKnown =
            CandidatesForZone(data, questDB, npcDB, itemDB, zone, xpMultiplier)
        if #candidates > 0 then
            zone.candidates = candidates
            zone.totalXP = totalXP
            zone.totalMoney = totalMoney
            zone.moneyKnown = moneyKnown
            populated[#populated + 1] = zone
        end
    end
    if #populated == 0 then return {} end
    table.sort(populated, function(a, b)
        local aCurrent, bCurrent = a.areaID == currentAreaID, b.areaID == currentAreaID
        if aCurrent ~= bCurrent then return aCurrent end
        if a.lastVisited ~= b.lastVisited then return a.lastVisited > b.lastVisited end
        return a.name < b.name
    end)

    local rows = {}
    for zoneIndex = 1, #populated do
        local zone = populated[zoneIndex]
        local zoneAreaID = zone.areaID
        local expanded = IsExpanded(zoneAreaID)
        rows[#rows + 1] = {
            key = "zone-quests-summary-" .. tostring(zoneAreaID),
            label = string.format("%s %d %s quest%s available", expanded and "−" or "+",
                #zone.candidates, zone.name, #zone.candidates == 1 and "" or "s"),
            detail = RewardSummary(zone.totalXP, zone.totalMoney, zone.moneyKnown),
            tooltip = expanded
                and string.format("Collapse the available quests in %s.", zone.name)
                or string.format("Expand the available quests in %s.", zone.name),
            clickHint = expanded and "Click to collapse this zone." or "Click to expand this zone.",
            state = "info",
            icon = zone.candidates[1].icon or QUEST_ICON,
            onClick = function() ToggleExpanded(zoneAreaID) end,
        }
        if expanded then
            for candidateIndex = 1, #zone.candidates do
                rows[#rows + 1] = QuestRow(zone.candidates[candidateIndex])
            end
        end
    end
    return {
        id = "zone-quests",
        title = "Quest Progress",
        rows = rows,
    }
end

ns.RegisterProvider("zone-quests", 22, Build)

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_CONTROL_GAINED",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
    "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "SKILL_LINES_CHANGED", "ADDON_LOADED",
}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and (...) == "QuestieDB" then
        candidateCache, reverseMap, reverseOverride, questXP = {}, nil, nil, nil
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_LOGIN" then
        reverseMap, reverseOverride = nil, nil
        RecordCurrentZone()
    end
    if ns.RequestRefresh then ns.RequestRefresh() end
end)
