-------------------------------------------------------------------------------
-- Adventure Tracker: expandable quest progress for zones the player visited.
-------------------------------------------------------------------------------
local _, ns = ...

local QUEST_ICON = "Interface\\Icons\\INV_Misc_Note_01"
local candidateCache = {}
local candidateIndexOwner
local zoneResultCache = {}
local questStateRevision = 0
local reverseMap, reverseOverride, questXP
local lastRecordedAreaID
local merchantOpen, merchantInitialized = false, false
local buybackSnapshot = {}
local buybackScanQueued = false

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
    ns.Set("zoneQuestExpandedByCharacter", copy, true)
    if ns.RequestPresentationRefresh then
        ns.RequestPresentationRefresh("zone quest expansion")
    elseif ns.RequestRefresh then
        ns.RequestRefresh(false, "zone quest expansion")
    end
end

local function CharacterContinentKey(continentID)
    return tostring(ns.CharacterKey()) .. ":" .. tostring(continentID)
end

local function IsContinentExpanded(continentID)
    local source = ns.Get("zoneQuestContinentExpandedByCharacter")
    return type(source) == "table" and source[CharacterContinentKey(continentID)] == true
end

local function ToggleContinentExpanded(continentID)
    local source = ns.Get("zoneQuestContinentExpandedByCharacter")
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do copy[key] = value end
    end
    local key = CharacterContinentKey(continentID)
    copy[key] = not (copy[key] == true)
    ns.Set("zoneQuestContinentExpandedByCharacter", copy, true)
    if ns.RequestPresentationRefresh then
        ns.RequestPresentationRefresh("quest continent expansion")
    elseif ns.RequestRefresh then
        ns.RequestRefresh(false, "quest continent expansion")
    end
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
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return result
end

local function ContinentForMap(mapID)
    mapID = tonumber(mapID)
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    local visited = {}
    for _ = 1, 12 do
        if not mapID or mapID <= 0 or visited[mapID] then break end
        visited[mapID] = true
        local ok, info = C_Map and C_Map.GetMapInfo and pcall(C_Map.GetMapInfo, mapID)
        if not ok or type(info) ~= "table" then break end
        if tonumber(info.mapType) == tonumber(continentType) then
            return mapID, type(info.name) == "string" and info.name or ("Continent " .. mapID)
        end
        mapID = tonumber(info.parentMapID)
    end
    return "other", "Other Areas"
end

local function BitSet(mask, flag)
    mask, flag = tonumber(mask) or 0, tonumber(flag) or 0
    return flag > 0 and mask % (flag * 2) >= flag
end

local function CopyTable(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do copy[key] = value end
    end
    return copy
end

local function CharacterItemKey(itemID)
    return tostring(ns.CharacterKey()) .. ":" .. tostring(itemID)
end

local function GetItemCount(itemID)
    local api = C_Item and C_Item.GetItemCount or _G.GetItemCount
    if type(api) ~= "function" then return 0 end
    local ok, count = pcall(api, itemID)
    if not ok or IsSecret(count) then return 0 end
    return math.max(0, tonumber(count) or 0)
end

local function ItemIdentity(itemDB, itemID)
    local name = ns.QuestData.Value(itemDB, "name", itemID)
    local icon
    if GetItemInfo then
        local ok, liveName, _, _, _, _, _, _, _, _, liveIcon = pcall(GetItemInfo, itemID)
        if ok then
            if not name and not IsSecret(liveName) then name = liveName end
            if not IsSecret(liveIcon) then icon = liveIcon end
        end
    end
    if not icon and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, instantIcon = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and not IsSecret(instantIcon) then icon = instantIcon end
    end
    return name or ("Item " .. tostring(itemID)), icon or QUEST_ICON
end

local function VisitedAreaSet()
    local result = {}
    local source = ns.Get("zoneQuestVisitedByCharacter")
    local prefix = tostring(ns.CharacterKey()) .. ":"
    if type(source) == "table" then
        for key, value in pairs(source) do
            if type(key) == "string" and key:sub(1, #prefix) == prefix then
                local areaID = type(value) == "table" and tonumber(value.areaID)
                    or tonumber(key:sub(#prefix + 1))
                if areaID then result[areaID] = true end
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    return result
end

local function MaskAllows(mask, flag)
    mask, flag = tonumber(mask) or 0, tonumber(flag)
    if mask == 0 then return true end
    return flag and flag > 0 and BitSet(mask, flag) or false
end

local function QuestIsNonTrivial(questDB, questID, playerLevel)
    local questLevel = tonumber(ns.QuestData.Value(questDB, "questLevel", questID)) or 0
    if questLevel <= 0 then return false end
    local trivialRange = 5
    if C_QuestLog and type(C_QuestLog.GetTrivialRange) == "function" then
        local ok, value = pcall(C_QuestLog.GetTrivialRange)
        if ok and not IsSecret(value) then trivialRange = tonumber(value) or trivialRange end
    end
    return questLevel - playerLevel >= -trivialRange
end

local function QuestMatchesCharacter(data, questDB, questID, visited, playerLevel)
    if data.IsComplete(questID) or data.IsInLog(questID) then return false end
    if data.IsKnownUnavailable and data.IsKnownUnavailable(questID) then return false end
    if data.HasChainPrerequisite and data.HasChainPrerequisite(questDB, questID) then return false end

    local requiredLevel = tonumber(data.Value(questDB, "requiredLevel", questID)) or 0
    local requiredMaxLevel = tonumber(data.Value(questDB, "requiredMaxLevel", questID)) or 0
    if requiredLevel > playerLevel + 5 then return false end
    if requiredMaxLevel > 0 and playerLevel > requiredMaxLevel then return false end
    if not QuestIsNonTrivial(questDB, questID, playerLevel) then return false end

    local areaID = tonumber(data.Value(questDB, "zoneOrSort", questID))
    if not areaID or not visited[areaID] then return false end

    local _, classToken
    if UnitClass then _, classToken = UnitClass("player") end
    local _, _, raceID
    if UnitRace then _, _, raceID = UnitRace("player") end
    local enums = _G.LibQuestieDB and _G.LibQuestieDB.Enum or {}
    local classMask = enums.classKeys and enums.classKeys[classToken]
    local raceMask = enums.raceMaskById and enums.raceMaskById[raceID]
    if not MaskAllows(data.Value(questDB, "requiredClasses", questID), classMask) then return false end
    if not MaskAllows(data.Value(questDB, "requiredRaces", questID), raceMask) then return false end

    local specialRequirement
    for _, field in ipairs({
        "requiredSkill", "requiredRanks", "requiredMinRep", "requiredMaxRep",
        "requiredSpell", "requiredSpecialization",
    }) do
        local value = data.Value(questDB, field, questID)
        if (type(value) == "table" and next(value) ~= nil)
            or (type(value) ~= "table" and value ~= nil and tonumber(value) ~= 0) then
            specialRequirement = true
            break
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if specialRequirement and not data.RequirementsMet(questDB, questID) then return false end

    local specialFlags = tonumber(data.Value(questDB, "specialFlags", questID)) or 0
    local questFlags = tonumber(data.Value(questDB, "questFlags", questID)) or 0
    if BitSet(specialFlags, 1) or BitSet(questFlags, 4096) or BitSet(questFlags, 32768) then return false end

    local untilCompleted = tonumber(data.Value(questDB, "availableUntilCompleted", questID)) or 0
    if untilCompleted > 0 and data.IsComplete(untilCompleted) then return false end
    local disabledBy = tonumber(data.Value(questDB, "disabledByQuest", questID)) or 0
    if disabledBy > 0 and (data.IsComplete(disabledBy) or data.IsInLog(disabledBy)) then return false end
    return true
end

local function ObjectiveItemCount(data, questDB, questID, itemID)
    local objectives = data.Value(questDB, "objectives", questID)
    local itemObjectives = type(objectives) == "table" and objectives[3]
    if type(itemObjectives) ~= "table" then return nil end
    local required
    for _, objective in pairs(itemObjectives) do
        if type(objective) == "table" and tonumber(objective[1]) == itemID then
            required = math.max(required or 0, tonumber(objective[3]) or 1)
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return required
end

local function FutureItemCandidate(itemID, questDB, itemDB)
    if not ns.Get("warnFutureQuestItems") then return nil end
    local data = ns.QuestData
    local related = data.Value(itemDB, "relatedQuests", itemID)
    if type(related) ~= "table" then return nil end
    local playerLevel = tonumber(UnitLevel and UnitLevel("player")) or 0
    local visited = VisitedAreaSet()
    local owned = GetItemCount(itemID)
    local quests, required = {}, 0
    for _, rawQuestID in pairs(related) do
        local questID = tonumber(rawQuestID)
        if questID and QuestMatchesCharacter(data, questDB, questID, visited, playerLevel) then
            local count = ObjectiveItemCount(data, questDB, questID, itemID)
            if count and owned < count then
                local name = data.Value(questDB, "name", questID) or ("Quest " .. tostring(questID))
                local questLevel = tonumber(data.Value(questDB, "questLevel", questID)) or 0
                quests[#quests + 1] = {
                    id = questID,
                    name = name,
                    level = questLevel,
                    required = count,
                }
                required = math.max(required, count)
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if #quests == 0 then return nil end
    ns.BudgetedSort(quests, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    local name, icon = ItemIdentity(itemDB, itemID)
    return {
        itemID = itemID,
        name = name,
        icon = icon,
        owned = owned,
        required = required,
        needed = math.max(1, required - owned),
        quests = quests,
    }
end

local function ItemIDFromLink(link)
    if type(link) ~= "string" or IsSecret(link) then return nil end
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, itemID = pcall(C_Item.GetItemInfoInstant, link)
        if ok and not IsSecret(itemID) and tonumber(itemID) then return tonumber(itemID) end
    end
    return tonumber(link:match("item:(%d+)"))
end

local function ReadBuybackSnapshot()
    local result = {}
    if not merchantOpen or type(GetNumBuybackItems) ~= "function"
        or type(GetBuybackItemLink) ~= "function" then return result end
    local ok, total = pcall(GetNumBuybackItems)
    total = ok and not IsSecret(total) and tonumber(total) or 0
    for index = 1, total do
        local linkOK, link = pcall(GetBuybackItemLink, index)
        local itemID = linkOK and ItemIDFromLink(link)
        if itemID then
            local price, quantity = 0, 1
            if type(GetBuybackItemInfo) == "function" then
                local infoOK, _, _, livePrice, liveQuantity = pcall(GetBuybackItemInfo, index)
                if infoOK then
                    if not IsSecret(livePrice) then price = tonumber(livePrice) or 0 end
                    if not IsSecret(liveQuantity) then quantity = tonumber(liveQuantity) or 1 end
                end
            end
            result[#result + 1] = {
                itemID = itemID,
                quantity = math.max(1, quantity),
                price = math.max(0, price),
                signature = string.format("%d:%d:%d", itemID, quantity, price),
            }
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return result
end

local function InsertedBuybackCount(previous, current)
    if #current == 0 then return 0 end
    if #previous == 0 then return #current end
    for shift = 1, #current do
        local overlap = math.min(#previous, #current - shift)
        if overlap > 0 then
            local matches = true
            for index = 1, overlap do
                if current[shift + index].signature ~= previous[index].signature then
                    matches = false
                    break
                end
            end
            if matches then return shift end
        end
    end
    return 0
end

local function SetFutureItemActive(itemID, quantity)
    local source = ns.Get("futureQuestItemsByCharacter")
    local copy = CopyTable(source)
    copy[CharacterItemKey(itemID)] = {
        itemID = itemID,
        soldQuantity = math.max(1, tonumber(quantity) or 1),
        soldAt = type(time) == "function" and time() or 0,
    }
    ns.Set("futureQuestItemsByCharacter", copy, true)
end

local function ProcessBuybackUpdate()
    buybackScanQueued = false
    if not merchantOpen then return end
    local current = ReadBuybackSnapshot()
    if not merchantInitialized then
        buybackSnapshot = current
        merchantInitialized = true
        return
    end
    local inserted = InsertedBuybackCount(buybackSnapshot, current)
    buybackSnapshot = current
    if inserted <= 0 or not ns.Get("warnFutureQuestItems") then
        if ns.RequestRefresh then ns.RequestRefresh("zone-quests", "merchant buyback update") end
        return
    end
    local questDB, _, itemDB = ns.QuestData.GetEntities()
    if questDB and itemDB then
        for index = 1, inserted do
            local sold = current[index]
            if sold and FutureItemCandidate(sold.itemID, questDB, itemDB) then
                SetFutureItemActive(sold.itemID, sold.quantity)
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    if ns.RequestRefresh then ns.RequestRefresh("zone-quests", "future quest item sold") end
end

local function QueueBuybackUpdate()
    if buybackScanQueued then return end
    buybackScanQueued = true
    C_Timer.After(0.05, function()
        if ns.QueueBudgetedWork then
            ns.QueueBudgetedWork("merchant-buyback-scan", ProcessBuybackUpdate)
        else
            ProcessBuybackUpdate()
        end
    end)
end

local function FindBuybackIndex(itemID)
    if not merchantOpen then return nil end
    local current = ReadBuybackSnapshot()
    for index = 1, #current do
        if current[index].itemID == itemID then return index end
    end
end

local function BuyBackFutureItem(itemID)
    local index = FindBuybackIndex(itemID)
    if not index or type(BuybackItem) ~= "function" then return end
    BuybackItem(index)
    C_Timer.After(0.15, function()
        QueueBuybackUpdate()
        if ns.RequestRefresh then ns.RequestRefresh("zone-quests", "future quest item bought back") end
    end)
end

local function DismissFutureItem(candidate)
    local active = CopyTable(ns.Get("futureQuestItemsByCharacter"))
    active[CharacterItemKey(candidate.itemID)] = nil
    ns.Set("futureQuestItemsByCharacter", active, true)
    if ns.RequestRefresh then ns.RequestRefresh("zone-quests", "future quest item dismissed") end
end

local function FutureItemTooltip(owner, candidate, buybackAvailable)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local handled = false
    if GameTooltip.SetItemByID then handled = pcall(GameTooltip.SetItemByID, GameTooltip, candidate.itemID) end
    if not handled and GameTooltip.SetHyperlink then
        handled = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tostring(candidate.itemID))
    end
    if not handled then GameTooltip:SetText(candidate.name) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Future quest material", 1, 0.30, 0.25)
    for index = 1, #candidate.quests do
        local quest = candidate.quests[index]
        GameTooltip:AddLine(string.format("%s (level %d): %d needed", quest.name, quest.level, quest.required),
            1, 1, 1, true)
    end
    GameTooltip:AddLine(string.format("In bags: %d • keep: %d", candidate.owned, candidate.required),
        0.72, 0.78, 0.82)
    if buybackAvailable then
        GameTooltip:AddLine("Click to buy this stack back before leaving the merchant.", 0.55, 0.82, 1, true)
    else
        GameTooltip:AddLine("Buyback is no longer available; keep the next stack you find.", 1, 0.72, 0.28, true)
    end
    GameTooltip:Show()
    return true
end

local function FutureItemRow(candidate, buybackAvailable)
    local quest = candidate.quests[1]
    local otherCount = #candidate.quests - 1
    local questText = quest.name .. (otherCount > 0 and string.format(" +%d more", otherCount) or "")
    return {
        key = "future-quest-item-" .. tostring(candidate.itemID),
        label = string.format("Keep %d %s for a future quest", candidate.needed, candidate.name),
        detail = buybackAvailable
            and string.format("Needed for %s • click to buy back", questText)
            or string.format("Needed for %s • buyback unavailable", questText),
        state = "missing",
        attention = "critical",
        icon = candidate.icon,
        tooltipFunc = function(owner) return FutureItemTooltip(owner, candidate, buybackAvailable) end,
        onClick = buybackAvailable and function() BuyBackFutureItem(candidate.itemID) end or nil,
        clickHint = buybackAvailable and "Click to buy this stack back." or nil,
        onDismiss = function() DismissFutureItem(candidate) end,
        dismissHint = "Dismiss this warning. Selling another stack can warn you again.",
    }
end

local function FutureItemRows(questDB, itemDB)
    if not ns.Get("warnFutureQuestItems") then return {} end
    local source = ns.Get("futureQuestItemsByCharacter")
    if type(source) ~= "table" then return {} end
    local prefix = tostring(ns.CharacterKey()) .. ":"
    local active = CopyTable(source)
    local changed, candidates = false, {}
    for key, record in pairs(source) do
        if type(key) == "string" and key:sub(1, #prefix) == prefix and type(record) == "table" then
            local itemID = tonumber(record.itemID) or tonumber(key:sub(#prefix + 1))
            local candidate = itemID and FutureItemCandidate(itemID, questDB, itemDB)
            if candidate then
                candidates[#candidates + 1] = candidate
            else
                active[key] = nil
                changed = true
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if changed then ns.Set("futureQuestItemsByCharacter", active, true) end
    ns.BudgetedSort(candidates, function(a, b) return a.name < b.name end)

    local rows = {}
    for index = 1, #candidates do
        local candidate = candidates[index]
        local buybackAvailable = FindBuybackIndex(candidate.itemID) ~= nil
        rows[#rows + 1] = FutureItemRow(candidate, buybackAvailable)
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return rows
end

local function CandidateIDs(questDB, areaID)
    local key = tostring(areaID)
    if candidateCache.__complete then return candidateCache[key] or {} end
    while candidateIndexOwner and not candidateCache.__complete do
        if coroutine.status(candidateIndexOwner) == "dead" then
            -- A provider error cannot strand every future caller behind a stale
            -- lock. The next live coroutine takes ownership and rebuilds.
            candidateIndexOwner = nil
            break
        end
        ns.YieldForBudget(true)
    end
    if candidateCache.__complete then return candidateCache[key] or {} end
    candidateIndexOwner = coroutine.running()
    -- Build into a private table and publish it atomically, so waiting providers
    -- never observe a partially populated area index.
    local buildingCache = {}
    local ids = type(questDB.GetAllIds) == "function" and questDB.GetAllIds() or {}
    for index = 1, #ids do
        local questID = ids[index]
        local questAreaID = tonumber(ns.QuestData.Value(questDB, "zoneOrSort", questID))
        if questAreaID then
            local areaKey = tostring(questAreaID)
            local bucket = buildingCache[areaKey]
            if not bucket then bucket = {}; buildingCache[areaKey] = bucket end
            bucket[#bucket + 1] = questID
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    buildingCache.__complete = true
    candidateCache = buildingCache
    candidateIndexOwner = nil
    return candidateCache[key] or {}
end
ns.GetQuestCandidateIDs = CandidateIDs

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

local function QuestRow(candidate, zone)
    local label = candidate.questLevel > 0
        and string.format("%s (Level %d)", candidate.name, candidate.questLevel)
        or candidate.name
    local rewards = {}
    if candidate.xp > 0 then rewards[#rewards + 1] = FormatNumber(candidate.xp) .. " XP" end
    if candidate.money and candidate.money > 0 then rewards[#rewards + 1] = FormatMoney(candidate.money) end
    local tooltip = candidate.source
    if #rewards > 0 then tooltip = tooltip .. "\nRewards: " .. table.concat(rewards, ", ") end
    local context = {
        id = candidate.id,
        name = candidate.name,
        source = candidate.source,
        questLevel = candidate.questLevel,
        requiredLevel = candidate.requiredLevel,
        zoneName = zone and zone.name,
        areaID = zone and zone.areaID,
    }
    return {
        key = "zone-quest-" .. tostring(candidate.id),
        label = label,
        detail = candidate.source,
        tooltip = tooltip,
        state = "info",
        icon = candidate.icon or QUEST_ICON,
        indentLevel = 1,
        onRightClick = function(owner)
            if ns.ShowQuestContextMenu then ns.ShowQuestContextMenu(owner, context) end
        end,
        rightClickHint = "Right-click to hide, report or copy the Wowhead link.",
    }
end

local function CandidatesForZone(data, questDB, npcDB, itemDB, objectDB, zone, xpMultiplier)
    local candidates, totalXP, totalMoney, moneyKnown = {}, 0, 0, false
    local ids = CandidateIDs(questDB, zone.areaID)
    for index = 1, #ids do
        local questID = ids[index]
        local specialFlags = tonumber(data.Value(questDB, "specialFlags", questID)) or 0
        local questFlags = tonumber(data.Value(questDB, "questFlags", questID)) or 0
        local recurring = BitSet(specialFlags, 1) or BitSet(questFlags, 4096) or BitSet(questFlags, 32768)
        if not recurring and not data.IsComplete(questID) and not data.IsInLog(questID)
            and not (ns.IsQuestHidden and ns.IsQuestHidden(questID))
            and data.RequirementsMet(questDB, questID) then
            local source, icon = data.Starter(questDB, npcDB, itemDB, questID, objectDB)
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
                    requiredLevel = tonumber(data.Value(questDB, "requiredLevel", questID)) or 0,
                    score = score,
                    xp = xp,
                    money = money,
                }
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    ns.BudgetedSort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.questLevel ~= b.questLevel then return a.questLevel < b.questLevel end
        return a.name < b.name
    end)
    return candidates, totalXP, totalMoney, moneyKnown
end

local function CachedCandidatesForZone(data, questDB, npcDB, itemDB, objectDB, zone, xpMultiplier)
    local level = UnitLevel and UnitLevel("player") or 0
    local cacheKey = table.concat({ ns.CharacterKey(), zone.areaID or 0, level,
        questStateRevision, ns.GetHiddenQuestRevision and ns.GetHiddenQuestRevision() or 0,
        tostring(xpMultiplier or 1) }, ":")
    local cached = zoneResultCache[cacheKey]
    if cached then
        return cached.candidates, cached.totalXP, cached.totalMoney, cached.moneyKnown
    end
    local candidates, totalXP, totalMoney, moneyKnown =
        CandidatesForZone(data, questDB, npcDB, itemDB, objectDB, zone, xpMultiplier)
    zoneResultCache[cacheKey] = {
        candidates = candidates,
        totalXP = totalXP,
        totalMoney = totalMoney,
        moneyKnown = moneyKnown,
    }
    return candidates, totalXP, totalMoney, moneyKnown
end

local function RewardSummary(totalXP, totalMoney, moneyKnown)
    local parts = {}
    if totalXP > 0 then parts[#parts + 1] = FormatNumber(totalXP) .. " XP" end
    if moneyKnown and totalMoney > 0 then parts[#parts + 1] = FormatMoney(totalMoney) end
    if #parts == 0 then return "Expand to review the available quests." end
    return "Total rewards: " .. table.concat(parts, ", ") .. "."
end

local function AppendZoneRows(rows, zone, options)
    options = options or {}
    local zoneAreaID = zone.areaID
    local alwaysExpanded = options.alwaysExpanded == true
    local parentVisible = options.parentVisible or function() return true end
    local indentLevel = tonumber(options.indentLevel) or 0
    local function ZoneExpanded()
        return alwaysExpanded or IsExpanded(zoneAreaID)
    end
    local summary = {
        key = "zone-quests-summary-" .. tostring(zoneAreaID),
        label = function()
            if alwaysExpanded then
                return string.format("%d current-zone quest%s available", #zone.candidates,
                    #zone.candidates == 1 and "" or "s")
            end
            return string.format("%s %d %s quest%s available", ZoneExpanded() and "−" or "+",
                #zone.candidates, zone.name, #zone.candidates == 1 and "" or "s")
        end,
        detail = RewardSummary(zone.totalXP, zone.totalMoney, zone.moneyKnown),
        tooltip = alwaysExpanded and "Current-zone quests stay visible at the top of Quest Progress."
            or function()
                return ZoneExpanded()
                    and string.format("Collapse the available quests in %s.", zone.name)
                    or string.format("Expand the available quests in %s.", zone.name)
            end,
        state = "info",
        icon = zone.candidates[1].icon or QUEST_ICON,
        indentLevel = indentLevel,
        visible = parentVisible,
    }
    if not alwaysExpanded then
        summary.clickHint = function()
            return ZoneExpanded() and "Click to collapse this zone." or "Click to expand this zone."
        end
        summary.onClick = function() ToggleExpanded(zoneAreaID) end
        summary.disclosure = true
        summary.expanded = ZoneExpanded
    end
    rows[#rows + 1] = summary
    for candidateIndex = 1, #zone.candidates do
        local row = QuestRow(zone.candidates[candidateIndex], zone)
        row.indentLevel = indentLevel + 1
        row.visible = function() return parentVisible() and ZoneExpanded() end
        rows[#rows + 1] = row
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

local function Build()
    if not ns.Get("showZoneQuests") then return {} end
    local data = ns.QuestData
    if type(data) ~= "table" then return {} end
    local questDB, npcDB, itemDB, objectDB = data.GetEntities()
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
    local rows = FutureItemRows(questDB, itemDB)
    local _, currentMapID = ns.GetZoneName()
    local currentAreaID = CurrentAreaID(currentMapID)
    local zones = VisitedZones()
    local xpMultiplier = QuestXPMultiplier()
    local populated = {}
    for index = 1, #zones do
        local zone = zones[index]
        local candidates, totalXP, totalMoney, moneyKnown =
            CachedCandidatesForZone(data, questDB, npcDB, itemDB, objectDB, zone, xpMultiplier)
        if #candidates > 0 then
            zone.candidates = candidates
            zone.totalXP = totalXP
            zone.totalMoney = totalMoney
            zone.moneyKnown = moneyKnown
            populated[#populated + 1] = zone
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if #populated == 0 and #rows == 0 then return {} end
    local currentZone, continentsByID, continents = nil, {}, {}
    local currentContinentID = select(1, ContinentForMap(currentMapID))
    for zoneIndex = 1, #populated do
        local zone = populated[zoneIndex]
        if zone.areaID == currentAreaID then
            currentZone = zone
        else
            local continentID, continentName = ContinentForMap(zone.mapID)
            local key = tostring(continentID)
            local continent = continentsByID[key]
            if not continent then
                continent = {
                    id = continentID,
                    name = continentName,
                    zones = {},
                    questCount = 0,
                }
                continentsByID[key] = continent
                continents[#continents + 1] = continent
            end
            continent.zones[#continent.zones + 1] = zone
            continent.questCount = continent.questCount + #zone.candidates
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end

    if currentZone then AppendZoneRows(rows, currentZone, { alwaysExpanded = true }) end

    ns.BudgetedSort(continents, function(a, b)
        local aCurrent = tostring(a.id) == tostring(currentContinentID)
        local bCurrent = tostring(b.id) == tostring(currentContinentID)
        if aCurrent ~= bCurrent then return aCurrent end
        return a.name < b.name
    end)
    for continentIndex = 1, #continents do
        local continent = continents[continentIndex]
        ns.BudgetedSort(continent.zones, function(a, b)
            if a.lastVisited ~= b.lastVisited then return a.lastVisited > b.lastVisited end
            return a.name < b.name
        end)
        local continentID = continent.id
        local continentName = continent.name
        local continentZones = continent.zones
        local continentQuestCount = continent.questCount
        local function ContinentExpanded() return IsContinentExpanded(continentID) end
        rows[#rows + 1] = {
            key = "zone-quests-continent-" .. tostring(continentID),
            label = function()
                return string.format("%s %s", ContinentExpanded() and "−" or "+", continentName)
            end,
            detail = string.format("%d visited zone%s • %d quest%s available.", #continentZones,
                #continentZones == 1 and "" or "s", continentQuestCount,
                continentQuestCount == 1 and "" or "s"),
            tooltip = function()
                return ContinentExpanded()
                    and string.format("Collapse visited zones in %s.", continentName)
                    or string.format("Expand visited zones in %s.", continentName)
            end,
            clickHint = function()
                return ContinentExpanded() and "Click to collapse this continent." or "Click to expand this continent."
            end,
            state = "info",
            icon = "Interface\\Icons\\INV_Misc_Map_01",
            onClick = function() ToggleContinentExpanded(continentID) end,
            disclosure = true,
            expanded = ContinentExpanded,
        }
        for zoneIndex = 1, #continentZones do
            AppendZoneRows(rows, continentZones[zoneIndex], {
                parentVisible = ContinentExpanded,
                indentLevel = 1,
            })
            if ns.YieldForBudget then ns.YieldForBudget() end
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
    "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_COMBAT_CONFIG_CHANGED", "SPELLS_CHANGED", "SKILL_LINES_CHANGED",
    "UPDATE_FACTION", "CHAT_MSG_COMBAT_FACTION_CHANGE", "ADDON_LOADED",
    "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED",
}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "MERCHANT_SHOW" then
        merchantOpen, merchantInitialized = true, false
        buybackSnapshot = {}
        C_Timer.After(0, function()
            if not merchantOpen then return end
            if ns.QueueBudgetedWork then
                ns.QueueBudgetedWork("merchant-initial-scan", function()
                    return ReadBuybackSnapshot()
                end, function(snapshot)
                    if not merchantOpen then return end
                    buybackSnapshot = snapshot
                    merchantInitialized = true
                    if ns.RequestRefresh then ns.RequestRefresh("zone-quests", "merchant opened") end
                end)
            end
        end)
    elseif event == "MERCHANT_UPDATE" then
        QueueBuybackUpdate()
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen, merchantInitialized = false, false
        buybackSnapshot = {}
    elseif event == "ADDON_LOADED" and (...) == "QuestieDB" then
        candidateCache, reverseMap, reverseOverride, questXP = {}, nil, nil, nil
        candidateIndexOwner = nil
        zoneResultCache = {}
        questStateRevision = questStateRevision + 1
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_LOGIN" then
        reverseMap, reverseOverride = nil, nil
        RecordCurrentZone()
    end
    if event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN"
        or event == "QUEST_LOG_UPDATE" or event == "PLAYER_LEVEL_UP"
        or event == "PLAYER_LEVEL_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "ACTIVE_COMBAT_CONFIG_CHANGED" or event == "SPELLS_CHANGED"
        or event == "SKILL_LINES_CHANGED"
        or event == "UPDATE_FACTION" or event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        questStateRevision = questStateRevision + 1
        zoneResultCache = {}
    end
    if ns.RequestRefresh then ns.RequestRefresh("zone-quests", event) end
end)
