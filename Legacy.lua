-------------------------------------------------------------------------------
-- Adventure Tracker: Legacy provider.
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
local CHECKPOINTS = { 150, 225, 300 }
local CHALLENGE_ICON = 236544
local challengeCatalog

local function PublicNumber(value)
    if type(value) ~= "number" then return nil end
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local function Readable(value)
    if type(value) ~= "string" or value == "" then return nil end
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local function NextCheckpoint(rank)
    for index = 1, #CHECKPOINTS do
        if rank < CHECKPOINTS[index] then return CHECKPOINTS[index] end
    end
end

local function AvailablePoints()
    local constants = _G.Constants and _G.Constants.LegacyConsts
    if not constants or not C_MajorFactions or not C_Traits then return nil end
    local factionID = constants.LEGACY_REWARD_TRACK_FACTION_ID
    local treeID = constants.LEGACY_TREE_PROFESSIONS_ID
    if not factionID or not treeID then return nil end
    local ok, renown = pcall(C_MajorFactions.GetCurrentRenownLevel, factionID)
    if not ok or type(renown) ~= "number" or renown <= 0 then return 0 end
    local configID = C_Traits.GetConfigIDByTreeID(treeID)
    if not configID then return 0 end
    local infos = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    local info = infos and infos[1]
    return info and info.quantity or 0
end

local function OpenLegacy()
    if InCombatLockdown and InCombatLockdown() then return end
    if ToggleLegacySystemUI then ToggleLegacySystemUI() end
end

-- Forever exposes the achievement-to-Legacy-currency relationship live. The
-- return shape changed during beta builds, so accept table-like and scalar
-- forms while requiring a non-empty positive result.
local function TraitAward(achievementID)
    local api = C_Traits and C_Traits.GetTraitCurrencyForAchievement
    if type(api) ~= "function" then return nil end
    local results = { pcall(api, achievementID) }
    if not results[1] then return nil end
    local found, numbers = false, {}
    for index = 2, 8 do
        local value = results[index]
        if type(value) == "table" then
            found = true
            local amount = PublicNumber(value.quantity or value.amount or value.value or value.numPoints)
            if amount and amount > 0 and amount <= 10 then return amount end
        elseif type(value) == "number" and value > 0 then
            found = true
            numbers[#numbers + 1] = value
        elseif value == true then
            found = true
        end
    end
    if not found then return nil end
    for index = #numbers, 1, -1 do
        if numbers[index] <= 10 then return numbers[index] end
    end
    return 1
end

local function Criteria(achievementID)
    local rows, complete, quantity, required = {}, 0, 0, 0
    local count = 0
    if type(GetAchievementNumCriteria) == "function" then
        local ok, value = pcall(GetAchievementNumCriteria, achievementID)
        if ok then count = math.min(64, math.max(0, tonumber(value) or 0)) end
    end
    for index = 1, count do
        local result = { pcall(GetAchievementCriteriaInfo, achievementID, index, true) }
        if result[1] then
            local name = Readable(result[2])
            local done = result[4] == true
            local current = PublicNumber(result[5]) or 0
            local goal = PublicNumber(result[6]) or 0
            if name then
                rows[#rows + 1] = { name = name, complete = done, quantity = current, required = goal }
            end
            if done then complete = complete + 1 end
            if goal > 0 then
                quantity = quantity + math.min(current, goal)
                required = required + goal
            end
        end
    end
    local progress
    if required > 0 then
        progress = math.max(0, math.min(1, quantity / required))
    elseif count > 0 then
        progress = complete / count
    end
    return rows, complete, count, progress
end

local function ScanChallenges()
    if challengeCatalog then return challengeCatalog end
    challengeCatalog = {}
    if type(GetCategoryList) ~= "function" or type(GetCategoryNumAchievements) ~= "function"
        or type(GetAchievementInfo) ~= "function" then return challengeCatalog end
    local ok, categories = pcall(GetCategoryList)
    if not ok or type(categories) ~= "table" then return challengeCatalog end
    local seen = {}
    for categoryIndex = 1, #categories do
        local categoryID = categories[categoryIndex]
        local categoryName
        if type(GetCategoryInfo) == "function" then
            local categoryOK, title = pcall(GetCategoryInfo, categoryID)
            if categoryOK then categoryName = Readable(title) end
        end
        local countOK, count = pcall(GetCategoryNumAchievements, categoryID, false)
        count = countOK and math.max(0, tonumber(count) or 0) or 0
        for achievementIndex = 1, count do
            local info = { pcall(GetAchievementInfo, categoryID, achievementIndex) }
            local achievementID = info[1] and PublicNumber(info[2]) or nil
            local completed = info[5] == true
            if achievementID and not completed and not seen[achievementID] then
                seen[achievementID] = true
                local points = TraitAward(achievementID)
                if points then
                    local eligible = true
                    if type(IsAchievementEligible) == "function" then
                        local eligibleOK, value = pcall(IsAchievementEligible, achievementID)
                        if eligibleOK and value == false then eligible = false end
                    end
                    if eligible then
                        local criteria, criteriaDone, criteriaCount, progress = Criteria(achievementID)
                        local name = Readable(info[3]) or ("Legacy Challenge " .. tostring(achievementID))
                        local description = Readable(info[9])
                        local textParts = { name }
                        if description then textParts[#textParts + 1] = description end
                        if categoryName then textParts[#textParts + 1] = categoryName end
                        for criteriaIndex = 1, #criteria do
                            textParts[#textParts + 1] = criteria[criteriaIndex].name
                        end
                        challengeCatalog[#challengeCatalog + 1] = {
                            id = achievementID,
                            name = name,
                            description = description,
                            category = categoryName,
                            icon = info[11] or CHALLENGE_ICON,
                            points = points,
                            criteria = criteria,
                            criteriaDone = criteriaDone,
                            criteriaCount = criteriaCount,
                            progress = progress,
                            searchText = string.lower(table.concat(textParts, " ")),
                        }
                    end
                end
            end
        end
    end
    return challengeCatalog
end

local function Contains(text, value)
    value = Readable(value)
    return value and text:find(string.lower(value), 1, true) ~= nil
end

local function ChallengeScore(entry, professions)
    local score, reasons = 0, {}
    local zoneName = ns.GetZoneName()
    if Contains(entry.searchText, zoneName) then
        score = score + 100
        reasons[#reasons + 1] = "current zone"
    end

    local instanceName = GetInstanceInfo and GetInstanceInfo()
    if IsInInstance and select(1, IsInInstance()) and Contains(entry.searchText, instanceName) then
        score = score + 100
        reasons[#reasons + 1] = "current instance"
    end

    local className = UnitClass and UnitClass("player")
    if Contains(entry.searchText, className) then
        score = score + 70
        reasons[#reasons + 1] = "your class"
    end

    for index = 1, #professions do
        if LEGACY_PROFESSIONS[professions[index].skillLineID]
            and Contains(entry.searchText, professions[index].name) then
            score = score + 80
            reasons[#reasons + 1] = professions[index].name
            break
        end
    end

    local playerLevel = UnitLevel and UnitLevel("player") or 0
    for number in entry.searchText:gmatch("%f[%d](%d+)%f[%D]") do
        local target = tonumber(number)
        if target and target >= playerLevel and target <= playerLevel + 10 then
            score = score + math.max(5, 30 - (target - playerLevel) * 2)
            reasons[#reasons + 1] = "near your level"
            break
        end
    end

    if entry.progress and entry.progress > 0 then
        score = score + 20 + entry.progress * 30
        reasons[#reasons + 1] = "already in progress"
    end
    return score, reasons
end

local function CheckpointDuplicate(entry, professions)
    for index = 1, #professions do
        local profession = professions[index]
        local checkpoint = LEGACY_PROFESSIONS[profession.skillLineID] and NextCheckpoint(profession.rank)
        if checkpoint and Contains(entry.searchText, profession.name)
            and entry.searchText:find(tostring(checkpoint), 1, true) then return true end
    end
    return false
end

local function ChallengeDetail(entry, reasons)
    local award = string.format("Awards %d Legacy point%s", entry.points, entry.points == 1 and "" or "s")
    local progress
    if entry.criteriaCount > 0 then
        progress = string.format("%d/%d criteria", entry.criteriaDone, entry.criteriaCount)
    elseif entry.progress then
        progress = string.format("%d%% complete", math.floor(entry.progress * 100 + 0.5))
    end
    local nextCriterion
    for index = 1, #entry.criteria do
        if not entry.criteria[index].complete then
            nextCriterion = entry.criteria[index].name
            break
        end
    end
    local parts = { award }
    if progress then parts[#parts + 1] = progress end
    if nextCriterion then parts[#parts + 1] = "Next: " .. nextCriterion end
    if #reasons > 0 then parts[#parts + 1] = "Relevant: " .. table.concat(reasons, ", ") end
    return table.concat(parts, " • ") .. "."
end

local function BuildChallengeRows(professions)
    if not ns.Get("showLegacyChallenges") then return {} end
    local catalog = ScanChallenges()
    local candidates = {}
    for index = 1, #catalog do
        local entry = catalog[index]
        local score, reasons = ChallengeScore(entry, professions)
        if score > 0 and not CheckpointDuplicate(entry, professions) then
            candidates[#candidates + 1] = { entry = entry, score = score, reasons = reasons }
        end
    end
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local progressA, progressB = a.entry.progress or 0, b.entry.progress or 0
        if progressA ~= progressB then return progressA > progressB end
        return a.entry.name < b.entry.name
    end)

    local rows = {}
    local limit = math.max(1, math.min(10, tonumber(ns.Get("legacyChallengeLimit")) or 4))
    for index = 1, math.min(limit, #candidates) do
        local candidate = candidates[index]
        local entry = candidate.entry
        local tooltip = entry.description or entry.name
        if entry.category then tooltip = tooltip .. "\n\nCategory: " .. entry.category end
        rows[#rows + 1] = {
            key = "legacy-challenge-" .. tostring(entry.id),
            label = entry.name,
            detail = ChallengeDetail(entry, candidate.reasons),
            tooltip = tooltip .. "\n\nAdventure Tracker found this through the live achievement-to-Legacy-currency relationship.",
            state = (entry.progress or 0) >= 0.75 and "warning" or "info",
            icon = entry.icon,
            onClick = OpenLegacy,
        }
    end
    return rows
end

local function Build()
    if not ns.Get("showLegacy") then return {} end
    local rows = {}
    if ns.Get("showUnspentLegacy") then
        local points = AvailablePoints()
        if points and points > 0 then
            rows[#rows + 1] = {
                key = "unspent-legacy",
                label = string.format("%d unspent Legacy point%s", points, points == 1 and "" or "s"),
                detail = "Open the Legacy tree to plan or spend them.",
                state = "warning",
                icon = CHALLENGE_ICON,
                onClick = OpenLegacy,
            }
        end
    end

    local professions = ns.GetProfessionList and ns.GetProfessionList() or {}
    if ns.Get("showLegacyProfessionGoals") then
        for index = 1, #professions do
            local profession = professions[index]
            if LEGACY_PROFESSIONS[profession.skillLineID] then
                local checkpoint = NextCheckpoint(profession.rank)
                if checkpoint then
                    local remaining = checkpoint - profession.rank
                    rows[#rows + 1] = {
                        key = "legacy-profession-" .. tostring(profession.skillLineID),
                        label = string.format("Raise %s to %d", profession.name, checkpoint),
                        detail = string.format("Next profession Legacy checkpoint • %d skill-up%s remaining.", remaining, remaining == 1 and "" or "s"),
                        state = remaining <= 10 and "warning" or "info",
                        icon = profession.icon,
                    }
                end
            end
        end
    end

    local challengeRows = BuildChallengeRows(professions)
    for index = 1, #challengeRows do rows[#rows + 1] = challengeRows[index] end
    return { id = "legacy", title = "Legacy Progress", rows = rows }
end

function ns.InvalidateLegacyChallenges()
    challengeCatalog = nil
end

ns.RegisterProvider("legacy", 20, Build)

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "RECEIVED_ACHIEVEMENT_LIST" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    challengeCatalog = nil
    if ns.RequestRefresh then ns.RequestRefresh("legacy", event) end
end)
