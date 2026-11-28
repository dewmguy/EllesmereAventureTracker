-------------------------------------------------------------------------------
-- Adventure Tracker: instance timers, missing instance quests and upgrades.
-------------------------------------------------------------------------------
local _, ns = ...

local TIMER_ICON = 134376
local BOSS_ICON = 136116
local QUEST_ICON = 134400
local LOOT_ICON = 133784
-- QuestieDB's public quest schema cannot distinguish every client record from
-- content that can actually be offered on live Forever. Questie's non-SoD
-- blacklist supplies the Duskwood mission exclusions below. All The Things
-- independently records Of Mice and Milk as beta-only content removed before
-- launch (ATTWoWAddon/AllTheThings commit efb59f27785585017cd84d7ddf99dbe8a3aa3622).
local KNOWN_UNAVAILABLE_QUESTS = {
    [81730] = true, [81731] = true, [81732] = true, [81733] = true,
    [81734] = true, [81735] = true, [81736] = true, [81737] = true,
    [81738] = true, [81739] = true, [81740] = true, [81741] = true,
    [81742] = true, [81743] = true, [81744] = true, [81745] = true,
    [81746] = true, [81747] = true,
    [93928] = true, -- Of Mice and Milk
}

local state = {
    inInstance = false,
    completed = false,
    bossKills = 0,
}
local ticker
local questieChecked, questieReady
local questCandidates = {}
local questRowsCache
local lootRowsCache
local lootRevision = 0

local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_WEAPON = { 16 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 },
}

local function Now()
    return GetTime and GetTime() or 0
end

local function FormatClock(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, secs) end
    return string.format("%d:%02d", minutes, secs)
end

local function CharacterTable(key)
    local db = ns.DB()
    if type(db[key]) ~= "table" then db[key] = {} end
    local character = ns.CharacterKey()
    if type(db[key][character]) ~= "table" then db[key][character] = {} end
    return db[key][character]
end

local function PersonalBest(key, identity)
    local db = ns.DB()
    local root = type(db[key]) == "table" and db[key]
    local character = root and root[ns.CharacterKey()]
    return type(character) == "table" and tonumber(character[identity]) or nil
end

local function RecordBest(key, identity, duration)
    duration = tonumber(duration)
    if not duration or duration <= 0 or not identity then return false end
    local values = CharacterTable(key)
    local previous = tonumber(values[identity])
    if not previous or duration < previous then
        values[identity] = duration
        return true
    end
    return false
end

local function RunIdentity()
    if not state.instanceID then return nil end
    return string.format("%d:%d", state.instanceID, state.difficultyID or 0)
end

local function BossIdentity(encounterID)
    local run = RunIdentity()
    return run and encounterID and (run .. ":" .. tostring(encounterID)) or nil
end

local function RunTimerDetail()
    if not state.runStart then return nil end
    local elapsed = (state.runEnd or Now()) - state.runStart
    local best = PersonalBest("instanceRunBestsByCharacter", RunIdentity())
    return string.format("%s %s • Personal best %s", state.completed and "Finished in" or "Elapsed",
        FormatClock(elapsed), best and FormatClock(best) or "—")
end

local function BossTimerDetail()
    if not (state.bossStart and state.bossID) then return nil end
    local best = PersonalBest("instanceBossBestsByCharacter", BossIdentity(state.bossID))
    return string.format("Elapsed %s • Personal best %s", FormatClock(Now() - state.bossStart),
        best and FormatClock(best) or "—")
end

local function RefreshTimerRows()
    if not ns.UpdateVisibleRow then return end
    local runDetail = RunTimerDetail()
    if runDetail then ns.UpdateVisibleRow("instance-run-timer", { detail = runDetail }) end
    local bossDetail = BossTimerDetail()
    if bossDetail then ns.UpdateVisibleRow("instance-boss-timer", { detail = bossDetail }) end
end

local function StartTicker()
    if ticker or not C_Timer or not C_Timer.NewTicker then return end
    ticker = C_Timer.NewTicker(1, RefreshTimerRows)
end

local function StopTicker()
    if ticker and ticker.Cancel then ticker:Cancel() end
    ticker = nil
end

local function CurrentMapID()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
end

local function ResolveJournalInstance()
    if state.journalInstanceID then return state.journalInstanceID end
    if type(EJ_GetInstanceForMap) ~= "function" then return nil end
    local candidates = { CurrentMapID(), state.instanceID }
    for index = 1, #candidates do
        local mapID = candidates[index]
        if mapID then
            local ok, journalID = pcall(EJ_GetInstanceForMap, mapID)
            if ok and tonumber(journalID) and tonumber(journalID) > 0 then
                state.journalInstanceID = tonumber(journalID)
                return state.journalInstanceID
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return nil
end

local function ResolveFinalEncounters()
    if state.finalEncounterIDs ~= nil then return state.finalEncounterIDs end
    local result = {}
    local journalID = ResolveJournalInstance()
    if journalID and type(EJ_GetEncounterInfoByIndex) == "function" then
        local index = 1
        while index <= 100 do
            local ok, name, _, journalEncounterID, _, _, _, dungeonEncounterID =
                pcall(EJ_GetEncounterInfoByIndex, index, journalID)
            if not ok or not name then break end
            result = {}
            if tonumber(journalEncounterID) and tonumber(journalEncounterID) > 0 then
                result[tonumber(journalEncounterID)] = true
            end
            if tonumber(dungeonEncounterID) and tonumber(dungeonEncounterID) > 0 then
                result[tonumber(dungeonEncounterID)] = true
            end
            index = index + 1
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    if next(result) then state.finalEncounterIDs = result end
    return result
end

local function CompleteRun()
    if not state.inInstance or state.completed or not state.runStart then return end
    state.completed = true
    state.runEnd = Now()
    local duration = state.runEnd - state.runStart
    RecordBest("instanceRunBestsByCharacter", RunIdentity(), duration)
    if ns.RequestRefresh then ns.RequestRefresh("instances", "instance completed") end
end

local function ResetInstanceState()
    state.inInstance = false
    state.instanceName = nil
    state.instanceType = nil
    state.instanceID = nil
    state.difficultyID = nil
    state.sessionIdentity = nil
    state.runStart = nil
    state.runEnd = nil
    state.completed = false
    state.bossStart = nil
    state.bossID = nil
    state.bossName = nil
    state.bossKills = 0
    state.journalInstanceID = nil
    state.finalEncounterIDs = nil
    questRowsCache = nil
    lootRowsCache = nil
    StopTicker()
end

local function UpdateInstance()
    local inInstance, instanceType = false, nil
    if IsInInstance then inInstance, instanceType = IsInInstance() end
    local supported = inInstance and (instanceType == "party" or instanceType == "raid")
    if not supported then
        if state.inInstance then ResetInstanceState() end
        return
    end

    local name, detectedType, difficultyID, _, _, _, _, instanceID
    if GetInstanceInfo then
        name, detectedType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    end
    instanceType = detectedType or instanceType
    instanceID = tonumber(instanceID) or 0
    local identity = string.format("%d:%d", instanceID, tonumber(difficultyID) or 0)
    if state.inInstance and state.sessionIdentity == identity then return end

    ResetInstanceState()
    state.inInstance = true
    state.instanceName = name or "Instance"
    state.instanceType = instanceType
    state.instanceID = instanceID
    state.difficultyID = tonumber(difficultyID) or 0
    state.sessionIdentity = identity
    state.runStart = Now()
    state.bossKills = 0
    StartTicker()
    ResolveFinalEncounters()
end

local function IsQuestComplete(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, complete = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok then return complete == true end
    end
    if IsQuestFlaggedCompleted then
        local ok, complete = pcall(IsQuestFlaggedCompleted, questID)
        if ok then return complete == true end
    end
    return false
end

local function IsKnownUnavailableQuest(questID)
    return KNOWN_UNAVAILABLE_QUESTS[tonumber(questID)] == true
end

local function IsQuestInLog(questID)
    if C_QuestLog and C_QuestLog.IsOnQuest then
        local ok, onQuest = pcall(C_QuestLog.IsOnQuest, questID)
        if ok then return onQuest == true end
    end
    local entries = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries()
        or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
    for index = 1, entries do
        if C_QuestLog and C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(index)
            if info and info.questID == questID then return true end
        elseif GetQuestLogTitle then
            local _, _, _, _, _, _, _, id = GetQuestLogTitle(index)
            if id == questID then return true end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return false
end

local function QuestieEntities()
    if questieChecked then
        return questieReady and _G.QuestDB, _G.NpcDB, _G.ItemDB, _G.ObjectDB
    end
    questieChecked = true
    local library = _G.LibQuestieDB
    if type(library) ~= "table" or type(library.RequireContract) ~= "function" then return nil end
    local ok, supported = pcall(library.RequireContract, 4)
    questieReady = ok and supported == true and type(_G.QuestDB) == "table"
        and type(_G.NpcDB) == "table" and type(_G.ItemDB) == "table"
    if questieReady then return _G.QuestDB, _G.NpcDB, _G.ItemDB, _G.ObjectDB end
    return nil
end

local function EntityValue(entity, field, id)
    local getter = entity and entity[field]
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, id)
    if ok then return value end
    return nil
end

local function InstanceAreaID()
    local library = _G.LibQuestieDB
    if not (library and library.Support and type(library.Support.Get) == "function") then return nil end
    local ok, zones = pcall(library.Support.Get, "ZoneDB")
    if not ok or type(zones) ~= "table" then return nil end
    local map = zones.instanceIdToAreaId
    return type(map) == "table" and map[state.instanceID] or nil
end

local function MaskIncludes(mask, flag)
    mask, flag = tonumber(mask), tonumber(flag)
    if not mask or mask == 0 then return true end
    if not flag or flag <= 0 then return false end
    return mask % (flag * 2) >= flag
end

local function HasPositiveQuestID(list)
    if type(list) ~= "table" then return false end
    for _, id in pairs(list) do
        id = tonumber(id)
        if id and id > 0 then return true end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return false
end

local function QuestHasChainPrerequisite(questDB, questID)
    if (tonumber(EntityValue(questDB, "parentQuest", questID)) or 0) > 0 then return true end
    if (tonumber(EntityValue(questDB, "availableStartingWith", questID)) or 0) > 0 then return true end
    if HasPositiveQuestID(EntityValue(questDB, "preQuestGroup", questID)) then return true end
    if HasPositiveQuestID(EntityValue(questDB, "preQuestSingle", questID)) then return true end
    return false
end

local function NoneComplete(list)
    if type(list) ~= "table" then return true end
    for _, id in pairs(list) do
        id = tonumber(id)
        if id and id > 0 and IsQuestComplete(id) then return false end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return true
end

local function ProfessionRequirementMet(required)
    if required == nil or required == 0 then return true end
    local skillLineID, rank
    if type(required) == "table" then
        skillLineID, rank = tonumber(required[1]), tonumber(required[2]) or 1
    else
        skillLineID, rank = tonumber(required), 1
    end
    if not skillLineID or skillLineID <= 0 then return true end
    if not ns.GetProfessionList then return false end
    local professions = ns.GetProfessionList()
    for index = 1, #professions do
        if professions[index].skillLineID == skillLineID then
            return (tonumber(professions[index].rank) or 0) >= rank
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return false
end

local function ProfessionRankRequirementsMet(required)
    if type(required) ~= "table" then return true end
    if not ns.GetProfessionList then return false end
    local professions = ns.GetProfessionList()
    local bySkill = {}
    for index = 1, #professions do
        bySkill[professions[index].skillLineID] = professions[index]
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local found = false
    local rankCaps = { [1] = 75, [2] = 150, [3] = 225, [4] = 300 }
    for _, pair in pairs(required) do
        if type(pair) == "table" then
            local skillLineID, rank = tonumber(pair[1]), tonumber(pair[2])
            if skillLineID and rank then
                found = true
                local profession = bySkill[skillLineID]
                if profession then
                    if rank < 0 then
                        local cap = rankCaps[-rank]
                        if cap and (tonumber(profession.maxRank) or 0) >= cap then return true end
                    elseif (tonumber(profession.rank) or 0) >= rank then
                        return true
                    end
                end
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return not found
end

local function ReputationValue(factionID)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and type(data) == "table" then
            return tonumber(data.currentStanding or data.barValue)
        end
    end
    if GetFactionInfoByID then
        local ok, _, _, _, _, _, value = pcall(GetFactionInfoByID, factionID)
        if ok then return tonumber(value) end
    end
    return nil
end

local function ReputationRequirementMet(required, maximum)
    if type(required) ~= "table" then return true end
    local factionID, threshold = tonumber(required[1]), tonumber(required[2])
    if not factionID or not threshold then return true end
    local current = ReputationValue(factionID)
    if current == nil then return false end
    return maximum and current <= threshold or current >= threshold
end

local function QuestRequirementsMet(questDB, questID)
    if IsKnownUnavailableQuest(questID) then return false end
    local level = UnitLevel and UnitLevel("player") or 0
    local requiredLevel = tonumber(EntityValue(questDB, "requiredLevel", questID)) or 0
    local requiredMaxLevel = tonumber(EntityValue(questDB, "requiredMaxLevel", questID)) or 0
    if requiredLevel > level or (requiredMaxLevel > 0 and level > requiredMaxLevel) then return false end

    local _, classToken
    if UnitClass then _, classToken = UnitClass("player") end
    local _, _, raceID
    if UnitRace then _, _, raceID = UnitRace("player") end
    local enums = _G.LibQuestieDB and _G.LibQuestieDB.Enum or {}
    local classMask = enums.classKeys and enums.classKeys[classToken]
    local raceMask = enums.raceMaskById and enums.raceMaskById[raceID]
    if not MaskIncludes(EntityValue(questDB, "requiredClasses", questID), classMask) then return false end
    if not MaskIncludes(EntityValue(questDB, "requiredRaces", questID), raceMask) then return false end
    if ns.YieldForBudget then ns.YieldForBudget() end

    -- Adventure Tracker deliberately recommends direct, ungated quest starts only.
    -- Even when Blizzard reports the prior step complete, a recorded chain gate
    -- remains outside this addon's conservative definition of "available."
    if QuestHasChainPrerequisite(questDB, questID) then return false end
    if not NoneComplete(EntityValue(questDB, "exclusiveTo", questID)) then return false end
    local nextQuest = tonumber(EntityValue(questDB, "nextQuestInChain", questID)) or 0
    if nextQuest > 0 and (IsQuestComplete(nextQuest) or IsQuestInLog(nextQuest)) then return false end
    local untilCompleted = tonumber(EntityValue(questDB, "availableUntilCompleted", questID)) or 0
    if untilCompleted > 0 and IsQuestComplete(untilCompleted) then return false end
    local breadcrumbFor = tonumber(EntityValue(questDB, "breadcrumbForQuestId", questID)) or 0
    if breadcrumbFor > 0 and (IsQuestComplete(breadcrumbFor) or IsQuestInLog(breadcrumbFor)) then return false end
    local disabledBy = tonumber(EntityValue(questDB, "disabledByQuest", questID)) or 0
    if disabledBy > 0 and IsQuestInLog(disabledBy) then return false end
    if ns.YieldForBudget then ns.YieldForBudget() end

    local requiredSpell = tonumber(EntityValue(questDB, "requiredSpell", questID)) or 0
    if requiredSpell > 0 then
        local known = (IsPlayerSpell and IsPlayerSpell(requiredSpell)) or (IsSpellKnown and IsSpellKnown(requiredSpell))
        if not known then return false end
    end
    local requiredSpec = tonumber(EntityValue(questDB, "requiredSpecialization", questID)) or 0
    if requiredSpec > 0 and GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        local specID = specIndex and select(1, GetSpecializationInfo(specIndex))
        if specID ~= requiredSpec then return false end
    end
    if not ProfessionRequirementMet(EntityValue(questDB, "requiredSkill", questID)) then return false end
    if not ProfessionRankRequirementsMet(EntityValue(questDB, "requiredRanks", questID)) then return false end
    if not ReputationRequirementMet(EntityValue(questDB, "requiredMinRep", questID), false) then return false end
    if not ReputationRequirementMet(EntityValue(questDB, "requiredMaxRep", questID), true) then return false end
    return true
end

local function JoinNames(entity, ids, limit)
    local names, seen = {}, {}
    if type(ids) == "table" then
        for _, id in pairs(ids) do
            local name = EntityValue(entity, "name", tonumber(id))
            if name and name ~= "" and not seen[name] then
                names[#names + 1] = name
                seen[name] = true
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    ns.BudgetedSort(names, function(a, b) return a < b end)
    local total = #names
    while #names > (limit or 3) do
        names[#names] = nil
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local text = table.concat(names, ", ")
    if total > #names then text = text .. string.format(" +%d more", total - #names) end
    return text, total
end

local function QuestStarter(questDB, npcDB, itemDB, questID, objectDB)
    local startedBy = EntityValue(questDB, "startedBy", questID)
    if type(startedBy) ~= "table" then return nil end
    local npcText, npcCount = JoinNames(npcDB, startedBy[1], 3)
    if npcCount > 0 then return "Quest giver: " .. npcText, QUEST_ICON end

    local objectText, objectCount = JoinNames(objectDB, startedBy[2], 3)
    if objectCount > 0 then return "Quest object: " .. objectText, QUEST_ICON end

    if type(startedBy[3]) == "table" then
        for _, itemID in pairs(startedBy[3]) do
            itemID = tonumber(itemID)
            local drops = itemID and EntityValue(itemDB, "npcDrops", itemID)
            local mobText, mobCount = JoinNames(npcDB, drops, 3)
            if itemID and mobCount > 0 then
                local itemName = EntityValue(itemDB, "name", itemID) or (GetItemInfo and GetItemInfo(itemID))
                    or ("Item " .. tostring(itemID))
                local icon = GetItemIcon and GetItemIcon(itemID) or QUEST_ICON
                return string.format("%s • Drops from: %s", itemName, mobText), icon
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    return nil
end

-- Shared, coordinate-free QuestieDB adapter used by both the instance and
-- current-zone quest providers. Keep the filtering policy in one place so a
-- quest cannot appear in one section while failing prerequisites in another.
ns.QuestData = {
    GetEntities = QuestieEntities,
    Value = EntityValue,
    IsComplete = IsQuestComplete,
    IsInLog = IsQuestInLog,
    IsKnownUnavailable = IsKnownUnavailableQuest,
    HasChainPrerequisite = QuestHasChainPrerequisite,
    RequirementsMet = QuestRequirementsMet,
    Starter = QuestStarter,
}

local function BuildQuestRows()
    if not state.inInstance or not ns.Get("showInstanceQuests") then return {} end
    if ns.IsCombatRestricted and ns.IsCombatRestricted() then
        return questRowsCache or {}
    end
    local questDB, npcDB, itemDB, objectDB = QuestieEntities()
    if not questDB then
        return {{
            key = "instance-quests-provider",
            label = "Instance quest data unavailable",
            detail = "Install, enable or update QuestieDB to list known missing quests.",
            state = "unavailable",
            icon = QUEST_ICON,
        }}
    end

    local areaID = InstanceAreaID()
    if not areaID then return {} end
    local cacheKey = tostring(state.instanceID) .. ":" .. tostring(areaID)
    local candidates = questCandidates[cacheKey]
    if not candidates then
        candidates = {}
        local ids = ns.GetQuestCandidateIDs and ns.GetQuestCandidateIDs(questDB, areaID)
            or (type(questDB.GetAllIds) == "function" and questDB.GetAllIds() or {})
        for index = 1, #ids do
            local questID = ids[index]
            if ns.GetQuestCandidateIDs
                or tonumber(EntityValue(questDB, "zoneOrSort", questID)) == tonumber(areaID) then
                candidates[#candidates + 1] = questID
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
        ns.BudgetedSort(candidates, function(a, b)
            local levelA = tonumber(EntityValue(questDB, "questLevel", a)) or 0
            local levelB = tonumber(EntityValue(questDB, "questLevel", b)) or 0
            if levelA == levelB then
                return tostring(EntityValue(questDB, "name", a) or a) < tostring(EntityValue(questDB, "name", b) or b)
            end
            return levelA < levelB
        end)
        questCandidates[cacheKey] = candidates
    end

    local rows = {}
    for index = 1, #candidates do
        local questID = candidates[index]
        if not IsQuestComplete(questID) and not IsQuestInLog(questID)
            and QuestRequirementsMet(questDB, questID) then
            local source, icon = QuestStarter(questDB, npcDB, itemDB, questID, objectDB)
            if source then
                local name = EntityValue(questDB, "name", questID) or ("Quest " .. tostring(questID))
                local questLevel = tonumber(EntityValue(questDB, "questLevel", questID)) or 0
                rows[#rows + 1] = {
                    key = "instance-quest-" .. tostring(questID),
                    label = questLevel > 0 and string.format("%s (Level %d)", name, questLevel) or name,
                    detail = source,
                    tooltip = source,
                    state = "info",
                    icon = icon or QUEST_ICON,
                }
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local limit = math.max(1, math.min(20, tonumber(ns.Get("instanceQuestLimit")) or 8))
    local total = #rows
    while #rows > limit do table.remove(rows) end
    if total > #rows then
        rows[#rows + 1] = {
            key = "instance-quests-more",
            label = string.format("%d more known quest%s hidden", total - #rows, total - #rows == 1 and "" or "s"),
            detail = "Increase the instance quest limit in Adventure Tracker settings.",
            state = "info",
            icon = QUEST_ICON,
        }
    end
    return rows
end

local function ItemLevel(item)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, item)
        if ok and tonumber(level) then return tonumber(level) end
    end
    if GetItemInfo then
        local ok, _, _, _, level = pcall(GetItemInfo, item)
        if ok and tonumber(level) then return tonumber(level) end
    end
    return nil
end

local function EquippedLevel(equipLoc)
    local slots = EQUIP_SLOTS[equipLoc]
    if equipLoc == "INVTYPE_WEAPON" then
        local canDualWield = (IsPlayerSpell and IsPlayerSpell(674)) or (IsSpellKnown and IsSpellKnown(674))
        if canDualWield then slots = { 16, 17 } end
    end
    if not slots then return nil end
    local lowest
    for index = 1, #slots do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slots[index])
        local level = link and ItemLevel(link) or 0
        if lowest == nil or level < lowest then lowest = level end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return lowest or 0
end

local function ItemTooltip(link, itemID)
    return function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        if link and GameTooltip.SetHyperlink then
            GameTooltip:SetHyperlink(link)
        elseif GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(itemID)
        else
            return false
        end
        GameTooltip:Show()
        return true
    end
end

local function IsEquippable(itemID)
    if C_Item and C_Item.IsEquippableItem then
        local ok, value = pcall(C_Item.IsEquippableItem, itemID)
        if ok then return value == true end
    end
    if IsEquippableItem then
        local ok, value = pcall(IsEquippableItem, itemID)
        if ok then return value == true end
    end
    return false
end

local function BuildLootRows()
    if not state.inInstance or not ns.Get("showInstanceLoot") then return {} end
    if ns.IsCombatRestricted and ns.IsCombatRestricted() then
        return lootRowsCache and lootRowsCache.rows or {}
    end
    local journalID = ResolveJournalInstance()
    if not journalID or type(EJ_GetNumLoot) ~= "function" or type(EJ_GetLootInfoByIndex) ~= "function"
        or type(EJ_SetLootFilter) ~= "function" then return {} end

    local _, _, classID
    if UnitClass then _, _, classID = UnitClass("player") end
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and select(1, GetSpecializationInfo(specIndex)) or 0
    local cacheKey = table.concat({ state.sessionIdentity or "", classID or 0, specID or 0, lootRevision }, ":")
    if lootRowsCache and lootRowsCache.key == cacheKey then return lootRowsCache.rows end

    if EJ_SelectInstance then pcall(EJ_SelectInstance, journalID) end
    if EJ_SetDifficulty and state.difficultyID and state.difficultyID > 0 then
        pcall(EJ_SetDifficulty, state.difficultyID)
    end
    local oldClass, oldSpec
    if EJ_GetLootFilter then
        local ok
        ok, oldClass, oldSpec = pcall(EJ_GetLootFilter)
        if not ok then oldClass, oldSpec = nil, nil end
    end
    pcall(EJ_SetLootFilter, classID or 0, specID or 0)

    local rows = {}
    local okCount, count = pcall(EJ_GetNumLoot)
    count = okCount and tonumber(count) or 0
    for index = 1, count do
        local ok, itemID, encounterID, itemName, icon, _, _, itemLink, encounterName =
            pcall(EJ_GetLootInfoByIndex, index)
        itemID = ok and tonumber(itemID) or nil
        if itemID and IsEquippable(itemID) then
            local _, _, _, equipLoc, instantIcon
            if GetItemInfoInstant then _, _, _, equipLoc, instantIcon = GetItemInfoInstant(itemID) end
            local candidateLevel = ItemLevel(itemLink or itemID)
            local equippedLevel = equipLoc and EquippedLevel(equipLoc)
            local requiredLevel = GetItemInfo and select(5, GetItemInfo(itemID)) or 0
            if candidateLevel and equippedLevel and candidateLevel > equippedLevel
                and (not requiredLevel or requiredLevel == 0 or requiredLevel <= (UnitLevel("player") or 0)) then
                rows[#rows + 1] = {
                    key = "instance-loot-" .. tostring(itemID),
                    label = itemName or (GetItemInfo and GetItemInfo(itemID)) or ("Item " .. tostring(itemID)),
                    detail = string.format("%s • item level %d vs %d equipped (+%d)",
                        encounterName or "Instance drop", candidateLevel, equippedLevel, candidateLevel - equippedLevel),
                    state = "ready",
                    icon = icon or instantIcon or LOOT_ICON,
                    tooltipFunc = ItemTooltip(itemLink, itemID),
                    encounterID = encounterID,
                    improvement = candidateLevel - equippedLevel,
                }
            elseif ns.RequestItemData then
                ns.RequestItemData(itemID, "instances")
            end
        elseif itemID and ns.RequestItemData then
            ns.RequestItemData(itemID, "instances")
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    pcall(EJ_SetLootFilter, oldClass or 0, oldSpec or 0)

    ns.BudgetedSort(rows, function(a, b)
        if a.improvement == b.improvement then return tostring(a.label) < tostring(b.label) end
        return a.improvement > b.improvement
    end)
    local limit = math.max(1, math.min(20, tonumber(ns.Get("instanceLootLimit")) or 8))
    local total = #rows
    while #rows > limit do table.remove(rows) end
    if total > #rows then
        rows[#rows + 1] = {
            key = "instance-loot-more",
            label = string.format("%d more upgrade%s hidden", total - #rows, total - #rows == 1 and "" or "s"),
            detail = "Increase the dungeon upgrade limit in Adventure Tracker settings.",
            state = "info",
            icon = LOOT_ICON,
        }
    end
    lootRowsCache = { key = cacheKey, rows = rows }
    return rows
end

local function Build()
    if not ns.Get("showInstances") or not state.inInstance then return {} end
    local sections = {}
    local timerRows = {}
    if ns.Get("showInstanceRunTimer") and state.runStart then
        timerRows[#timerRows + 1] = {
            key = "instance-run-timer",
            label = state.completed and (state.instanceName .. " complete") or state.instanceName,
            detail = RunTimerDetail(),
            tooltip = "The personal best is recorded per character and difficulty when the final boss or dungeon-completion event is detected.",
            state = state.completed and "ready" or "info",
            icon = TIMER_ICON,
        }
    end
    if ns.Get("showInstanceBossTimer") and state.bossStart and state.bossID then
        timerRows[#timerRows + 1] = {
            key = "instance-boss-timer",
            label = state.bossName or "Boss encounter",
            detail = BossTimerDetail(),
            tooltip = "Successful boss kills record a per-character personal best for this difficulty.",
            state = "warning",
            icon = BOSS_ICON,
        }
    end
    if #timerRows > 0 then
        sections[#sections + 1] = {
            id = "instance-timers",
            title = "Instance Timers",
            rows = timerRows,
            forceVisible = true,
        }
    end

    if ns.Get("showInstanceQuests") then
        if not questRowsCache then questRowsCache = BuildQuestRows() end
        if #questRowsCache > 0 then
            sections[#sections + 1] = { id = "instance-quests", title = "Instance Quests", rows = questRowsCache }
        end
    end
    if ns.Get("showInstanceLoot") then
        local rows = BuildLootRows()
        if #rows > 0 then
            sections[#sections + 1] = { id = "instance-upgrades", title = "Dungeon Upgrades", rows = rows }
        end
    end
    return sections
end

function ns.IsInstanceBossTimerActive()
    return state.inInstance and state.bossStart ~= nil and ns.Get("showInstanceBossTimer") == true
end

function ns.GetInstanceDataStatus()
    local questStatus = _G.LibQuestieDB and "QuestieDB detected" or "QuestieDB not detected"
    local lootStatus = type(EJ_GetNumLoot) == "function" and type(EJ_SetLootFilter) == "function"
        and "Encounter Journal detected" or "Encounter Journal unavailable"
    return questStatus, lootStatus
end

ns.RegisterProvider("instances", 2, Build, { combatSafe = true })

local events = CreateFrame("Frame")
local eventNames = {
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "ENCOUNTER_START", "ENCOUNTER_END", "LFG_COMPLETION_REWARD",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED",
    "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "UPDATE_FACTION",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
    "ADDON_LOADED",
}
for index = 1, #eventNames do pcall(events.RegisterEvent, events, eventNames[index]) end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        UpdateInstance()
        local encounterID, encounterName = ...
        state.bossID = tonumber(encounterID)
        state.bossName = encounterName
        state.bossStart = Now()
        StartTicker()
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        if state.bossStart and tonumber(encounterID) == state.bossID then
            if tonumber(success) == 1 then
                local duration = Now() - state.bossStart
                RecordBest("instanceBossBestsByCharacter", BossIdentity(state.bossID), duration)
                state.bossKills = (state.bossKills or 0) + 1
                local finals = ResolveFinalEncounters()
                if finals[tonumber(encounterID)] then CompleteRun() end
            end
            state.bossStart = nil
            state.bossID = nil
            state.bossName = encounterName or state.bossName
        end
    elseif event == "LFG_COMPLETION_REWARD" then
        CompleteRun()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_LOGIN" then
        UpdateInstance()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        questRowsCache = nil
        lootRevision = lootRevision + 1
        lootRowsCache = nil
    elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN"
        or event == "QUEST_LOG_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_LEVEL_CHANGED" then
        questRowsCache = nil
    elseif event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" or event == "UPDATE_FACTION" then
        questRowsCache = nil
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        lootRevision = lootRevision + 1
        lootRowsCache = nil
    elseif event == "ADDON_LOADED" then
        if (...) ~= "QuestieDB" then return end
        questieChecked, questieReady = nil, nil
        questCandidates = {}
        questRowsCache = nil
    end
    if ns.RequestRefresh then ns.RequestRefresh("instances", event) end
end)
