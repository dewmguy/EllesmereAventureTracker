-------------------------------------------------------------------------------
-- EllesmereUI Adventure Tracker
-- A contextual readiness and opportunity tracker for WoW Forever.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EUI = _G.EllesmereUI
if not EUI or EUI.IS_FOREVER ~= true then return end

ns.ADDON_NAME = ADDON_NAME
ns.EUI = EUI

-- Item-data events are global and can be emitted by every addon. Track only
-- requests Adventure Tracker initiated so unrelated cache traffic cannot
-- repeatedly rebuild the tracker.
local pendingItemDataProviders = {}
local pendingSpellDataProviders = {}
local failedItemDataUntil = {}
local failedSpellDataUntil = {}
local DATA_FAILURE_RETRY_SECONDS = 300

local function DataNow()
    return GetTime and GetTime() or 0
end

local function FailureBackoffActive(failures, recordID)
    local retryAt = tonumber(failures[recordID])
    if not retryAt then return false end
    if DataNow() >= retryAt then
        failures[recordID] = nil
        return false
    end
    return true
end

function ns.RequestItemData(itemID, providers)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false end
    if FailureBackoffActive(failedItemDataUntil, itemID) then return false end
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if type(request) ~= "function" then return false end
    local pending = pendingItemDataProviders[itemID]
    local shouldRequest = pending == nil
    if not pending then
        pending = {}
        pendingItemDataProviders[itemID] = pending
    end
    if type(providers) == "string" then
        pending[providers] = true
    elseif type(providers) == "table" then
        for index = 1, #providers do pending[providers[index]] = true end
    end
    if shouldRequest then pcall(request, itemID) end
    return true
end

function ns.ConsumeItemDataProviders(itemID, succeeded)
    itemID = tonumber(itemID)
    local pending = itemID and pendingItemDataProviders[itemID]
    if not pending then return nil end
    pendingItemDataProviders[itemID] = nil
    if succeeded == false then
        failedItemDataUntil[itemID] = DataNow() + DATA_FAILURE_RETRY_SECONDS
        return nil
    end
    failedItemDataUntil[itemID] = nil
    local providers = {}
    for providerID in pairs(pending) do providers[#providers + 1] = providerID end
    table.sort(providers)
    return #providers > 0 and providers or nil
end

function ns.RequestSpellData(spellID, providers)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return false end
    if FailureBackoffActive(failedSpellDataUntil, spellID) then return false end
    local request = C_Spell and C_Spell.RequestLoadSpellData
    if type(request) ~= "function" then return false end
    local pending = pendingSpellDataProviders[spellID]
    local shouldRequest = pending == nil
    if not pending then
        pending = {}
        pendingSpellDataProviders[spellID] = pending
    end
    if type(providers) == "string" then
        pending[providers] = true
    elseif type(providers) == "table" then
        for index = 1, #providers do pending[providers[index]] = true end
    end
    if shouldRequest then pcall(request, spellID) end
    return true
end

function ns.ConsumeSpellDataProviders(spellID, succeeded)
    spellID = tonumber(spellID)
    local pending = spellID and pendingSpellDataProviders[spellID]
    if not pending then return nil end
    pendingSpellDataProviders[spellID] = nil
    if succeeded == false then
        failedSpellDataUntil[spellID] = DataNow() + DATA_FAILURE_RETRY_SECONDS
        return nil
    end
    failedSpellDataUntil[spellID] = nil
    local providers = {}
    for providerID in pairs(pending) do providers[#providers + 1] = providerID end
    table.sort(providers)
    return #providers > 0 and providers or nil
end

local DEFAULTS = {
    enabled = true,
    locked = false,
    collapsed = false,
    width = 340,
    scale = 1.0,
    frameStrata = "MEDIUM",
    maximizePaneHeight = false,
    paneGrowthDirection = "DOWN",
    paneHeightLimitMode = "AUTO",
    paneHeightLimitPercent = 75,
    paneHeightLimitPixels = 600,
    opacity = 0.96,
    panePadding = 8,
    backgroundColorMode = "custom",
    backgroundColor = { r = 0.025, g = 0.032, b = 0.04, a = 0.94 },
    sectionBackgroundColorMode = "custom",
    sectionBackgroundColor = { r = 1, g = 1, b = 1, a = 0 },
    sectionHoverBackgroundColorMode = "custom",
    sectionHoverBackgroundColor = { r = 1, g = 1, b = 1, a = 0.05 },
    entryBackgroundColorMode = "custom",
    entryBackgroundColor = { r = 1, g = 1, b = 1, a = 0.025 },
    entryHoverBackgroundColorMode = "custom",
    entryHoverBackgroundColor = { r = 1, g = 1, b = 1, a = 0.07 },
    borderTexture = "solid",
    borderSize = 1,
    borderColorMode = "custom",
    borderColor = { r = 0.20, g = 0.24, b = 0.27, a = 1 },
    titleBarMode = "filled",
    titleBarHeight = 28,
    titleBarColorMode = "custom",
    titleBarColor = { r = 0.04, g = 0.055, b = 0.065, a = 0.98 },
    titleTextColorMode = "custom",
    titleTextColor = { r = 1, g = 0.82, b = 0, a = 1 },
    textFont = "__global",
    textOutline = "NONE",
    titleFontSize = 13,
    contextFontSize = 11,
    statusTextAlignment = "LEFT",
    contextTextColorMode = "custom",
    contextTextColor = { r = 0.67, g = 0.72, b = 0.75, a = 1 },
    sectionFontSize = 11,
    sectionTextColorMode = "custom",
    sectionTextColor = { r = 0.18, g = 0.82, b = 0.66, a = 1 },
    entryLabelFontSize = 12,
    entryLabelTextColorMode = "custom",
    entryLabelTextColor = { r = 1, g = 1, b = 1, a = 1 },
    entryDetailFontSize = 10,
    entryDetailTextColorMode = "custom",
    entryDetailTextColor = { r = 0.62, g = 0.66, b = 0.69, a = 1 },
    badgeFontSize = 10,
    badgeTextColorMode = "custom",
    badgeTextColor = { r = 1, g = 1, b = 1, a = 1 },
    badgeAnchor = "BOTTOMRIGHT",
    badgeOffsetX = 3,
    badgeOffsetY = -2,
    titleAlignment = "LEFT",
    titleSeparatorSize = 0,
    titleSeparatorColorMode = "custom",
    titleSeparatorColor = { r = 0.20, g = 0.24, b = 0.27, a = 1 },
    position = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -330, y = -220 },
    hideInCombat = true,
    hideInInstances = false,
    hideWhenReady = false,
    showContext = true,
    collapsedSectionsByCharacter = {},
    showTalentReminder = true,
    showClassTrainerSkills = true,
    hideBlizzardTalentReminder = true,

    showReadiness = true,
    readinessIconSize = 31,
    readinessIconSpacing = 6,
    readinessIconBorderTexture = "solid",
    readinessIconBorderSize = 2,
    readinessIconReadyBorderColorMode = "custom",
    readinessIconReadyBorderColor = { r = 0.20, g = 0.82, b = 0.48, a = 1 },
    readinessIconWarningBorderColorMode = "custom",
    readinessIconWarningBorderColor = { r = 1.00, g = 0.68, b = 0.18, a = 1 },
    readinessIconMissingBorderColorMode = "custom",
    readinessIconMissingBorderColor = { r = 0.94, g = 0.28, b = 0.28, a = 1 },
    readinessIconUnavailableBorderColorMode = "custom",
    readinessIconUnavailableBorderColor = { r = 0.42, g = 0.45, b = 0.48, a = 1 },
    readinessIconUnknownBorderColorMode = "custom",
    readinessIconUnknownBorderColor = { r = 0.58, g = 0.53, b = 0.78, a = 1 },
    readinessIconInfoBorderColorMode = "custom",
    readinessIconInfoBorderColor = { r = 0.35, g = 0.67, b = 0.95, a = 1 },
    trackCamp = true,
    trackSleepingBag = true,
    trackFood = true,
    trackClassBuffs = true,
    trackWeaponEnhancements = true,
    readinessWarnMinutes = 10,
    showCompletedReadiness = false,
    roleByCharacter = {},
    lastClassBuffSpellsByCharacter = {},
    roleCriticalAlerts = true,
    roleAlertMinDuration = 5,
    trackPartyClassBuffs = true,

    showWorldBuffs = true,
    showActiveWorldBuffs = true,
    showMissingWorldBuffs = false,
    worldBuffCurrentZoneOnly = false,
    worldBuffWarnMinutes = 10,

    showLegacy = true,
    showUnspentLegacy = true,
    showLegacyProfessionGoals = true,
    showLegacyChallenges = true,
    legacyChallengeLimit = 4,

    showZoneQuests = true,
    questSortMode = "recommended",
    questZoneSortMode = "recent",
    questContinentSortMode = "current",
    questDifficultyFilter = "all",
    questHistoryScope = "all",
    questShowNPCStarters = true,
    questShowObjectStarters = true,
    questShowItemStarters = true,
    questMaxPerZone = 0,
    zoneQuestExpandedByCharacter = {},
    zoneQuestContinentExpandedByCharacter = {},
    zoneQuestVisitedByCharacter = {},
    hiddenZoneQuestsByCharacter = {},
    questIssueReports = {},
    warnFutureQuestItems = true,
    futureQuestItemsByCharacter = {},

    showProfessions = true,
    showProfessionProgress = true,
    showProfessionSynergy = true,
    showProfessionGear = true,
    showProfessionCaps = true,
    showProfessionTrainerRecipes = true,
    showProfessionMarketCosts = true,
    showProfessionAttainableRecipes = true,
    showObservedGathering = true,
    professionRecipeCatalogExpandedByCharacter = {},
    showCompletedProfessions = false,
    showProfessionZoneHints = true,
    showProviderDiagnostics = false,
    runtimeFrameBudgetPercent = 10,

    showInstances = true,
    showInstanceRunTimer = true,
    showInstanceBossTimer = true,
    showInstanceQuests = true,
    showInstanceLoot = true,
    instanceQuestLimit = 8,
    instanceLootLimit = 8,
    instanceRunBestsByCharacter = {},
    instanceBossBestsByCharacter = {},

    showFlightTimer = true,
    flightTimerShowDestination = true,
    flightTimerShowElapsed = false,
    flightTimerShowRemaining = true,
    flightTimerShowTotal = true,
    flightTimerLearnTimes = true,
    flightTimerShowIcon = true,
    flightTimerBarHeight = 8,
    flightTimerBarTexture = "none",
    flightTimerFillColorMode = "accent",
    flightTimerFillColor = { r = 0.05, g = 0.75, b = 0.58, a = 1 },
    flightTimerBackgroundColorMode = "custom",
    flightTimerBackgroundColor = { r = 0.10, g = 0.10, b = 0.10, a = 0.80 },
    flightTimerBorderTexture = "solid",
    flightTimerBorderSize = 1,
    flightTimerBorderColorMode = "custom",
    flightTimerBorderColor = { r = 0, g = 0, b = 0, a = 1 },
    flightTimerFont = "__global",
    flightTimerFontOutline = "NONE",
    flightTimerDestinationFontSize = 12,
    flightTimerTimeFontSize = 10,
    flightTimerDestinationColorMode = "custom",
    flightTimerDestinationColor = { r = 1, g = 1, b = 1, a = 1 },
    flightTimerTimeColorMode = "custom",
    flightTimerTimeColor = { r = 0.75, g = 0.82, b = 0.86, a = 1 },
    flightTimerRoutes = {},

    showStatuses = true,
    showFlightStatus = true,
    showCombatStatus = true,
    showRestingStatus = true,
    showMountedStatus = true,
    showInstanceStatus = true,
    showPresenceStatus = true,
    showLifeStatus = true,
    showPlaytime = true,
    showSessionPlaytime = true,
    showTotalPlaytime = true,
    showGoldStatus = true,
}
ns.DEFAULTS = DEFAULTS

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

local function DB()
    local db = _G.EllesmereUIAdventureTrackerDB
    if type(db) ~= "table" then
        db = {}
        _G.EllesmereUIAdventureTrackerDB = db
    end
    return db
end
ns.DB = DB

function ns.Get(key)
    local value = DB()[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

local NO_RENDER_SETTINGS = {
    locked = true,
    position = true,
    runtimeFrameBudgetPercent = true,
    questIssueReports = true,
}
local RENDER_ONLY_SETTINGS = {}
for _, key in ipairs({
    "enabled", "collapsed", "width", "scale", "frameStrata", "maximizePaneHeight",
    "paneGrowthDirection", "paneHeightLimitMode", "paneHeightLimitPercent", "paneHeightLimitPixels",
    "opacity", "panePadding", "backgroundColorMode", "backgroundColor", "sectionBackgroundColorMode", "sectionBackgroundColor",
    "sectionHoverBackgroundColorMode", "sectionHoverBackgroundColor", "entryBackgroundColorMode", "entryBackgroundColor",
    "entryHoverBackgroundColorMode", "entryHoverBackgroundColor", "borderTexture", "borderSize", "borderColorMode", "borderColor",
    "titleBarMode", "titleBarHeight", "titleBarColorMode", "titleBarColor", "titleTextColorMode", "titleTextColor",
    "textFont", "textOutline", "titleFontSize", "contextFontSize", "statusTextAlignment",
    "contextTextColorMode", "contextTextColor", "sectionFontSize", "sectionTextColorMode",
    "sectionTextColor", "entryLabelFontSize", "entryLabelTextColorMode", "entryLabelTextColor",
    "entryDetailFontSize", "entryDetailTextColorMode", "entryDetailTextColor", "badgeFontSize",
    "badgeTextColorMode", "badgeTextColor", "badgeAnchor", "badgeOffsetX", "badgeOffsetY",
    "titleAlignment", "titleSeparatorSize", "titleSeparatorColorMode", "titleSeparatorColor",
    "hideInCombat", "hideInInstances", "hideWhenReady", "showContext", "collapsedSectionsByCharacter",
    "zoneQuestExpandedByCharacter", "zoneQuestContinentExpandedByCharacter", "professionRecipeCatalogExpandedByCharacter",
    "readinessIconSize", "readinessIconSpacing", "readinessIconBorderTexture", "readinessIconBorderSize",
    "readinessIconReadyBorderColorMode", "readinessIconReadyBorderColor", "readinessIconWarningBorderColorMode", "readinessIconWarningBorderColor",
    "readinessIconMissingBorderColorMode", "readinessIconMissingBorderColor", "readinessIconUnavailableBorderColorMode", "readinessIconUnavailableBorderColor",
    "readinessIconUnknownBorderColorMode", "readinessIconUnknownBorderColor", "readinessIconInfoBorderColorMode", "readinessIconInfoBorderColor",
    "showStatuses", "showFlightStatus", "showCombatStatus", "showRestingStatus", "showMountedStatus",
    "showInstanceStatus", "showPresenceStatus", "showLifeStatus", "showPlaytime", "showSessionPlaytime",
    "showTotalPlaytime", "showGoldStatus",
    "showProviderDiagnostics",
}) do RENDER_ONLY_SETTINGS[key] = true end

local SETTING_PROVIDERS = {}
local function RegisterSettingProviders(providers, keys)
    for _, key in ipairs(keys) do SETTING_PROVIDERS[key] = providers end
end
RegisterSettingProviders({ "character-reminders" }, {
    "showTalentReminder", "showClassTrainerSkills", "hideBlizzardTalentReminder",
})
RegisterSettingProviders({ "readiness" }, {
    "showReadiness", "trackCamp", "trackSleepingBag", "trackFood", "trackClassBuffs",
    "trackWeaponEnhancements", "readinessWarnMinutes", "showCompletedReadiness",
    "lastClassBuffSpellsByCharacter", "roleCriticalAlerts", "roleAlertMinDuration", "trackPartyClassBuffs",
})
SETTING_PROVIDERS.roleByCharacter = { "readiness", "professions", "instances" }
RegisterSettingProviders({ "world-buffs" }, {
    "showWorldBuffs", "showActiveWorldBuffs", "showMissingWorldBuffs",
    "worldBuffCurrentZoneOnly", "worldBuffWarnMinutes",
})
RegisterSettingProviders({ "legacy" }, {
    "showLegacy", "showUnspentLegacy", "showLegacyProfessionGoals", "showLegacyChallenges", "legacyChallengeLimit",
})
RegisterSettingProviders({ "zone-quests" }, {
    "showZoneQuests", "questSortMode", "questZoneSortMode", "questContinentSortMode",
    "questDifficultyFilter", "questHistoryScope", "questShowNPCStarters",
    "questShowObjectStarters", "questShowItemStarters", "questMaxPerZone",
    "zoneQuestVisitedByCharacter", "zoneQuestContinentExpandedByCharacter",
    "hiddenZoneQuestsByCharacter",
    "warnFutureQuestItems", "futureQuestItemsByCharacter",
})
RegisterSettingProviders({ "professions" }, {
    "showProfessions", "showProfessionProgress", "showProfessionSynergy", "showProfessionGear",
    "showProfessionCaps", "showProfessionTrainerRecipes", "showProfessionMarketCosts",
    "showProfessionAttainableRecipes", "showObservedGathering",
    "showCompletedProfessions", "showProfessionZoneHints",
})
RegisterSettingProviders({ "instances" }, {
    "showInstances", "showInstanceRunTimer", "showInstanceBossTimer", "showInstanceQuests",
    "showInstanceLoot", "instanceQuestLimit", "instanceLootLimit",
})
RegisterSettingProviders({ "flight-timer" }, {
    "showFlightTimer", "flightTimerShowDestination", "flightTimerShowElapsed", "flightTimerShowRemaining",
    "flightTimerShowTotal", "flightTimerLearnTimes", "flightTimerShowIcon", "flightTimerBarHeight",
    "flightTimerBarTexture", "flightTimerFillColorMode", "flightTimerFillColor", "flightTimerBackgroundColorMode", "flightTimerBackgroundColor",
    "flightTimerBorderTexture", "flightTimerBorderSize", "flightTimerBorderColorMode", "flightTimerBorderColor", "flightTimerFont",
    "flightTimerFontOutline", "flightTimerDestinationFontSize", "flightTimerTimeFontSize",
    "flightTimerDestinationColorMode", "flightTimerDestinationColor", "flightTimerTimeColorMode",
    "flightTimerTimeColor",
})

local function SettingScope(key)
    if NO_RENDER_SETTINGS[key] then return "none" end
    if RENDER_ONLY_SETTINGS[key] then return "render" end
    return SETTING_PROVIDERS[key]
end

function ns.InvalidateForSetting(key, reason)
    local scope = SettingScope(key)
    if scope == "none" or scope == "render" then return scope end
    if type(scope) == "table" and ns.InvalidateProviders then
        ns.InvalidateProviders(scope, reason or ("setting: " .. tostring(key)))
    elseif ns.InvalidateAllProviders then
        ns.InvalidateAllProviders(reason or ("setting: " .. tostring(key)))
    end
    return scope
end

function ns.RefreshForSetting(key)
    local scope = SettingScope(key)
    if scope == "none" then return end
    if ns.RequestRefresh then
        if scope == "render" then
            ns.RequestRefresh(false, "setting: " .. tostring(key))
        else
            ns.RequestRefresh(scope, "setting: " .. tostring(key))
        end
    end
end

function ns.Set(key, value, quiet)
    DB()[key] = value
    if not quiet then ns.RefreshForSetting(key) end
end

function ns.ResetKeys(keys)
    local db = DB()
    for i = 1, #keys do
        local key = keys[i]
        db[key] = Copy(DEFAULTS[key])
    end
    if ns.ApplySettings then ns.ApplySettings() end
    if ns.RequestRefresh then ns.RequestRefresh() end
end

function ns.ResetAll()
    local db = DB()
    for key in pairs(db) do db[key] = nil end
    for key, value in pairs(DEFAULTS) do db[key] = Copy(value) end
    if ns.ApplySettings then ns.ApplySettings() end
    if ns.RequestRefresh then ns.RequestRefresh() end
end

local function CharacterKey()
    local guid = UnitGUID and UnitGUID("player")
    if guid then return guid end
    local name, realm = UnitFullName and UnitFullName("player")
    return (name or "Player") .. "-" .. (realm or GetRealmName() or "Realm")
end
ns.CharacterKey = CharacterKey

function ns.GetRole()
    local roles = ns.Get("roleByCharacter")
    local value = type(roles) == "table" and roles[CharacterKey()]
    return value or "SOLO"
end

function ns.SetRole(value)
    local source = ns.Get("roleByCharacter")
    local roles = {}
    if type(source) == "table" then
        for key, role in pairs(source) do roles[key] = role end
    end
    roles[CharacterKey()] = value
    ns.Set("roleByCharacter", roles)
end

local function ReadableSpecName(value)
    if type(value) ~= "string" or value == "" then return nil end
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local cachedSpecName, specNameResolved

function ns.InvalidateCurrentSpecializationName()
    cachedSpecName, specNameResolved = nil, false
end

-- Forever exposes one starter specialization per class, so that identifier is
-- not a useful character build. EllesmereUI already resolves the active dual-
-- spec build's dominant vanilla talent group; use its localized group name as
-- the player's practical specialization (Protection, Holy, Arms, etc.).
function ns.GetCurrentSpecializationName()
    if specNameResolved then return cachedSpecName end
    specNameResolved = true
    if EUI.IS_FOREVER == true then
        if type(EUI.ForeverSpecGroupTalents) ~= "function" then return nil end
        local group = 1
        local getActiveGroup = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
        if type(getActiveGroup) == "function" then
            local ok, value = pcall(getActiveGroup)
            if ok and type(value) == "number" and value > 0 then group = value end
        end
        local ok, build = pcall(EUI.ForeverSpecGroupTalents, group)
        if not ok or type(build) ~= "table" or type(build.trees) ~= "table" then return nil end
        local lead = tonumber(build.lead)
        local tree = lead and build.trees[lead]
        cachedSpecName = ReadableSpecName(type(tree) == "table" and tree.name or nil)
        return cachedSpecName
    end

    local api = C_SpecializationInfo
    if api and type(api.GetSpecialization) == "function" and type(api.GetSpecializationInfo) == "function" then
        local ok, specialization = pcall(api.GetSpecialization)
        if ok and type(specialization) == "number" and specialization > 0 then
            local infoOK, _, name = pcall(api.GetSpecializationInfo, specialization)
            if infoOK then
                cachedSpecName = ReadableSpecName(name)
                return cachedSpecName
            end
        end
    end
    if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
        local ok, specialization = pcall(GetSpecialization)
        if ok and type(specialization) == "number" and specialization > 0 then
            local infoOK, _, name = pcall(GetSpecializationInfo, specialization)
            if infoOK then
                cachedSpecName = ReadableSpecName(name)
                return cachedSpecName
            end
        end
    end
end

ns.ROLE_LABELS = {
    SOLO = "Solo",
    TANK = "Tank",
    HEALER = "Healer",
    PHYSICAL = "Physical DPS",
    CASTER = "Caster DPS",
}

function ns.FormatDuration(seconds)
    if type(seconds) ~= "number" or seconds <= 0 then return nil end
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return minutes > 0 and string.format("%dh %dm", hours, minutes) or string.format("%dh", hours)
    end
    if seconds >= 60 then return string.format("%dm", math.floor(seconds / 60)) end
    return string.format("%ds", math.max(1, math.floor(seconds)))
end

function ns.GetZoneName()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local mapID = C_Map.GetBestMapForUnit("player")
        local info = mapID and C_Map.GetMapInfo(mapID)
        if info and info.name then return info.name, mapID end
    end
    return GetRealZoneText and GetRealZoneText() or "Unknown zone", nil
end

local providers = {}
local providersByID = {}
local profileMetrics = {}
local timedProviderTimer
local timedProviderDeadline
local providerRuntimeActive = false

local function ProfileNow()
    return debugprofilestop and debugprofilestop() or nil
end

function ns.RecordProfileMetric(id, startedAt, reason, examined)
    if ns.Get("debugProfiling") ~= true or not startedAt then return end
    local finishedAt = ProfileNow()
    if not finishedAt then return end
    ns.RecordProfileDuration(id, math.max(0, finishedAt - startedAt), reason, examined)
end

function ns.RecordProfileDuration(id, elapsed, reason, examined)
    if ns.Get("debugProfiling") ~= true or type(elapsed) ~= "number" then return end
    local metric = profileMetrics[id]
    if not metric then
        metric = { count = 0, total = 0, maximum = 0 }
        profileMetrics[id] = metric
    end
    metric.count = metric.count + 1
    metric.total = metric.total + elapsed
    metric.last = elapsed
    metric.maximum = math.max(metric.maximum, elapsed)
    metric.average = metric.total / metric.count
    metric.reason = reason
    metric.examined = examined
end

function ns.GetProfileMetrics()
    return profileMetrics
end

function ns.ResetProfileMetrics()
    wipe(profileMetrics)
end

-- WoW executes addon Lua on the render thread. All potentially repeated work
-- therefore shares one deliberately small frame budget. Work functions may
-- call ns.YieldForBudget() at safe boundaries; the scheduler resumes them on a
-- later frame instead of allowing an event burst to monopolize a frame.
local RUNTIME_FRAME_BUDGET_DEFAULT_PERCENT = 10
local RUNTIME_FRAME_BUDGET_MIN_MS = 0.35
local workQueue, workByKey = {}, {}
local activeWork, activeSliceStartedAt, activeFrameBudgetMS = RUNTIME_FRAME_BUDGET_MIN_MS
local worker = CreateFrame("Frame")
worker:Hide()

local function RuntimeNow()
    return debugprofilestop and debugprofilestop() or 0
end

local function RuntimeFrameBudget()
    local fps = GetFramerate and tonumber(GetFramerate()) or 60
    if not fps or fps <= 0 then fps = 60 end
    local percent = tonumber(ns.Get("runtimeFrameBudgetPercent")) or RUNTIME_FRAME_BUDGET_DEFAULT_PERCENT
    percent = math.max(5, math.min(100, percent))
    local budget = (1000 / fps) * (percent / 100)
    return math.max(RUNTIME_FRAME_BUDGET_MIN_MS, budget)
end

function ns.YieldForBudget(force)
    if not activeWork or not activeSliceStartedAt then return false end
    if not force and RuntimeNow() - activeSliceStartedAt < activeFrameBudgetMS then return false end
    coroutine.yield("frame-budget")
    return true
end

local function ReportWorkError(entry, message)
    if entry and type(entry.onError) == "function" then
        entry.onError(message)
        return
    end
    local handler = geterrorhandler and geterrorhandler()
    if type(handler) == "function" then handler(message) end
end

local function RemoveQueuedEntry(entry)
    for index = 1, #workQueue do
        if workQueue[index] == entry then
            table.remove(workQueue, index)
            return true
        end
    end
    return false
end

local function EnqueueWorkEntry(entry)
    workByKey[entry.key] = entry
    if entry.priority then
        table.insert(workQueue, 1, entry)
    else
        workQueue[#workQueue + 1] = entry
    end
    worker:Show()
end

function ns.QueueBudgetedWork(key, work, onComplete, canRun, onError, priority)
    if type(key) ~= "string" or type(work) ~= "function" then return false end
    local existing = workByKey[key]
    if existing then
        if not existing.thread then
            existing.work = work
            existing.onComplete = onComplete
            existing.canRun = canRun
            existing.onError = onError
            if priority then
                existing.priority = true
                if RemoveQueuedEntry(existing) then table.insert(workQueue, 1, existing) end
                worker:Show()
            end
            return true
        end
        -- Coalesce arbitrarily many requests into one latest rerun. The active
        -- coroutine is allowed to finish so it cannot leave a half-applied UI.
        local rerunPriority = priority == true or (existing.rerun and existing.rerun.priority == true)
        existing.rerun = {
            key = key, work = work, onComplete = onComplete,
            canRun = canRun, onError = onError, priority = rerunPriority,
        }
        if priority then
            existing.priority = true
            if RemoveQueuedEntry(existing) then table.insert(workQueue, 1, existing) end
            worker:Show()
        end
        return true
    end
    EnqueueWorkEntry({
        key = key, work = work, onComplete = onComplete,
        canRun = canRun, onError = onError, priority = priority == true,
    })
    return true
end

function ns.WakeBudgetedWork()
    if #workQueue > 0 then worker:Show() end
end

worker:SetScript("OnUpdate", function(self)
    if #workQueue == 0 then self:Hide(); return end
    activeFrameBudgetMS = RuntimeFrameBudget()
    activeSliceStartedAt = RuntimeNow()
    local deferred = 0
    while #workQueue > 0 and RuntimeNow() - activeSliceStartedAt < activeFrameBudgetMS do
        local entry = table.remove(workQueue, 1)
        local runnable = type(entry.canRun) ~= "function" or entry.canRun() ~= false
        if not runnable then
            workQueue[#workQueue + 1] = entry
            deferred = deferred + 1
            if deferred >= #workQueue then
                -- Every queued task is currently gated (normally by combat).
                -- Stop polling every frame; the matching state event wakes us.
                self:Hide()
                break
            end
        else
            deferred = 0
            if not entry.thread then entry.thread = coroutine.create(entry.work) end
            activeWork = entry
            local callStartedAt = RuntimeNow()
            local resumed = { coroutine.resume(entry.thread) }
            local callElapsed = RuntimeNow() - callStartedAt
            entry.activeElapsed = (entry.activeElapsed or 0) + callElapsed
            activeWork = nil
            if callElapsed > activeFrameBudgetMS and ns.RecordProfileDuration then
                ns.RecordProfileDuration("runtime-overrun:" .. entry.key,
                    callElapsed, "single resume exceeded frame budget")
            end
            local ok = table.remove(resumed, 1)
            if not ok then
                workByKey[entry.key] = nil
                if entry.rerun then EnqueueWorkEntry(entry.rerun) end
                ReportWorkError(entry, resumed[1])
            elseif coroutine.status(entry.thread) == "dead" then
                workByKey[entry.key] = nil
                -- Publish a coalesced rerun before invoking completion code. If
                -- that callback requests the same key, it updates this pending
                -- rerun instead of creating an orphaned duplicate queue entry.
                if entry.rerun then EnqueueWorkEntry(entry.rerun) end
                ns.RecordProfileDuration(entry.key, entry.activeElapsed or 0, "budgeted work")
                if type(entry.onComplete) == "function" then
                    entry.onComplete(unpack(resumed))
                end
            else
                if entry.priority then
                    table.insert(workQueue, 1, entry)
                else
                    workQueue[#workQueue + 1] = entry
                end
                -- Yielding means this work consumed its slice. Never resume it
                -- twice in the same frame even if the timer granularity rounds
                -- the measured duration down.
                break
            end
        end
    end
    activeWork = nil
    activeSliceStartedAt = nil
    if #workQueue == 0 then self:Hide() end
end)

function ns.GetRuntimeFrameBudget()
    return RuntimeFrameBudget()
end

function ns.GetRuntimeFrameBudgetFraction()
    local percent = tonumber(ns.Get("runtimeFrameBudgetPercent")) or RUNTIME_FRAME_BUDGET_DEFAULT_PERCENT
    return math.max(5, math.min(100, percent)) / 100
end

-- Lua's table.sort is a single C call and cannot yield. Providers use this
-- bottom-up merge sort for potentially variable result sets so comparison and
-- allocation work remains inside the shared frame budget.
function ns.BudgetedSort(values, less)
    if type(values) ~= "table" or #values < 2 or type(less) ~= "function" then return values end
    local count, width = #values, 1
    local source, target = values, {}
    while width < count do
        local left = 1
        while left <= count do
            local middle = math.min(left + width, count + 1)
            local right = math.min(left + width * 2, count + 1)
            local a, b = left, middle
            for index = left, right - 1 do
                if a < middle and (b >= right or not less(source[b], source[a])) then
                    target[index] = source[a]
                    a = a + 1
                else
                    target[index] = source[b]
                    b = b + 1
                end
                ns.YieldForBudget()
            end
            left = right
        end
        source, target = target, source
        width = width * 2
        ns.YieldForBudget()
    end
    if source ~= values then
        for index = 1, count do
            values[index] = source[index]
            ns.YieldForBudget()
        end
    end
    return values
end

-- Aura events cover applications, removals and stack changes. The only timed
-- transition they do not report is crossing a user-configured "expiring soon"
-- threshold, so schedule that exact transition instead of rebuilding the whole
-- tracker on a permanent polling interval.
function ns.ScheduleTimedProviderRefresh(delay)
    delay = tonumber(delay)
    if not delay or delay <= 0 or not (C_Timer and C_Timer.NewTimer) then return end
    local now = GetTime and GetTime() or 0
    local deadline = now + math.max(0.1, delay + 0.05)
    if timedProviderTimer and timedProviderDeadline and timedProviderDeadline <= deadline + 0.05 then
        return
    end
    if timedProviderTimer then timedProviderTimer:Cancel() end
    timedProviderDeadline = deadline
    timedProviderTimer = C_Timer.NewTimer(math.max(0.1, deadline - now), function()
        timedProviderTimer = nil
        timedProviderDeadline = nil
        if ns.RequestRefresh then
            ns.RequestRefresh({ "readiness", "world-buffs" }, "timed aura threshold")
        end
    end)
end

local function IsCombatRestricted()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat then
        local ok, fighting = pcall(UnitAffectingCombat, "player")
        local secret = ok and _G.issecretvalue and _G.issecretvalue(fighting)
        if ok and not secret and fighting then return true end
    end
    return false
end
ns.IsCombatRestricted = IsCombatRestricted

function ns.RegisterProvider(id, order, build, options)
    if type(id) ~= "string" or type(build) ~= "function" then return false end
    local provider = {
        id = id,
        order = order or 100,
        build = build,
        combatSafe = type(options) == "table" and options.combatSafe == true,
        dirty = true,
        invalidationReason = "registration",
        generation = 1,
        queued = false,
    }
    providers[#providers + 1] = provider
    providersByID[id] = provider
    table.sort(providers, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)
    return true
end

local QueueProvider

local function ProviderResultSectionCount(result)
    if type(result) ~= "table" then return 0 end
    if result.id then return 1 end
    local count = 0
    for index = 1, #result do
        if type(result[index]) == "table" and result[index].id then count = count + 1 end
    end
    return count
end

local function HasProviderSections(result)
    return ProviderResultSectionCount(result) > 0
end

QueueProvider = function(provider)
    if not providerRuntimeActive or not provider or not provider.dirty or provider.queued then return end
    provider.queued = true
    local executionGeneration
    ns.QueueBudgetedWork("provider:" .. provider.id, function()
        -- Capture at execution time so login/zone event bursts coalesce before
        -- a cold provider starts instead of forcing a guaranteed stale pass.
        local generation = provider.generation
        executionGeneration = generation
        local reason = provider.invalidationReason
        provider.buildingReason = reason
        provider.progressPublished = false
        local function PublishProgress(result)
            if provider.generation ~= generation or type(result) ~= "table" then return false end
            local previous = provider.lastResult
            provider.lastResult = result
            provider.lastError = nil
            provider.progressPublished = true
            if provider.id == "professions" and ns.RequestRender then
                -- The progress row is synthetic snapshot state, so a keyed
                -- provider patch cannot add or update it safely.
                ns.RequestRender("profession provider progress")
            elseif ns.QueueProviderPresentation then
                ns.QueueProviderPresentation(provider.id, previous, result)
            elseif ns.RequestRender then
                ns.RequestRender("provider progress: " .. provider.id)
            end
            return true
        end
        local result = provider.build(reason, PublishProgress, HasProviderSections(provider.lastResult))
        return result, generation
    end, function(result, builtGeneration)
        provider.queued = false
        local publishedProgress = provider.progressPublished == true
        provider.progressPublished = false
        provider.buildingReason = nil
        if provider.generation == builtGeneration and type(result) == "table" then
            if provider.id == "professions" and ns.OnProfessionProviderCommitted then
                ns.OnProfessionProviderCommitted()
            end
            local previous = provider.lastResult
            provider.lastResult = result
            provider.dirty = false
            provider.lastError = nil
            if ns.OnProviderCommitted then ns.OnProviderCommitted(provider.id) end
            if provider.id == "professions" and publishedProgress and ns.RequestRender then
                ns.RequestRender("profession provider completed")
            elseif ns.QueueProviderPresentation then
                ns.QueueProviderPresentation(provider.id, previous, result)
            elseif ns.RequestRender then
                ns.RequestRender("provider committed: " .. provider.id)
            end
        else
            if provider.id == "professions" and ns.OnProfessionProviderDiscarded then
                ns.OnProfessionProviderDiscarded()
            end
            if provider.dirty then QueueProvider(provider) end
        end
    end, function()
        return provider.combatSafe or not IsCombatRestricted()
    end, function(message)
        provider.queued = false
        provider.progressPublished = false
        provider.buildingReason = nil
        provider.lastError = tostring(message or "unknown provider error")
        if provider.id == "professions" and ns.OnProfessionProviderDiscarded then
            ns.OnProfessionProviderDiscarded()
        end
        if provider.generation == executionGeneration then
            provider.dirty = false
        else
            QueueProvider(provider)
        end
        if provider.id == "professions" and ns.RequestRender then
            ns.RequestRender("profession provider failed")
        end
        ReportWorkError(nil, message)
    end)
end

function ns.GetProviderRuntimeState(id)
    local provider = providersByID[id]
    if not provider then return nil end
    return provider.lastResult, provider.dirty == true, provider.queued == true, provider.lastError
end

local function ProviderStateName(provider)
    if provider.lastError then return "error" end
    if provider.queued then return provider.progressPublished and "enriching" or "building" end
    if provider.dirty then return "waiting" end
    return "ready"
end

function ns.PrintProviderDiagnostics()
    print("Adventure Tracker provider diagnostics:")
    for index = 1, #providers do
        local provider = providers[index]
        local reason = provider.buildingReason or provider.invalidationReason or "none"
        print(string.format("%s: %s, %d sections, generation %d, reason %s",
            provider.id, ProviderStateName(provider), ProviderResultSectionCount(provider.lastResult),
            provider.generation or 0, tostring(reason)))
        if provider.lastError then print("  error: " .. tostring(provider.lastError)) end
    end
end

function ns.ActivateProviderRuntime()
    if providerRuntimeActive then return end
    providerRuntimeActive = true
    for index = 1, #providers do QueueProvider(providers[index]) end
end

function ns.InvalidateProvider(id, reason)
    local provider = providersByID[id]
    if not provider then return false end
    reason = reason or "unspecified"
    -- A bag event can arrive in the same short coalescing window as a skill,
    -- level, zone or settings change. Never let the lightweight inventory
    -- reason replace a pending full rebuild.
    if provider.dirty and reason == "BAG_UPDATE_DELAYED"
        and provider.invalidationReason ~= "BAG_UPDATE_DELAYED" then
        return true
    end
    provider.dirty = true
    provider.invalidationReason = reason
    provider.generation = (provider.generation or 0) + 1
    QueueProvider(provider)
    if id == "professions" and ns.Get("showProviderDiagnostics") and ns.RequestRender then
        ns.RequestRender("profession provider queued")
    end
    return true
end

function ns.InvalidateProviders(ids, reason)
    if type(ids) == "string" then return ns.InvalidateProvider(ids, reason) end
    if type(ids) ~= "table" then return false end
    local changed = false
    for index = 1, #ids do
        changed = ns.InvalidateProvider(ids[index], reason) or changed
    end
    return changed
end

function ns.InvalidateAllProviders(reason)
    for index = 1, #providers do
        ns.InvalidateProvider(providers[index].id, reason or "all")
    end
end

function ns.ResolveTrackerDataValue(data, key)
    if type(data) ~= "table" then return nil end
    local value = data[key]
    if type(value) ~= "function" then return value end
    local ok, resolved = pcall(value, data)
    if not ok then return nil end
    return resolved
end

function ns.IsTrackerDataVisible(data)
    local visible = ns.ResolveTrackerDataValue(data, "visible")
    return visible ~= false
end

local function AppendProviderResult(snapshot, result)
    if type(result) ~= "table" then return end
    local sections = result.id and { result } or result
    for j = 1, #sections do
        if ns.YieldForBudget then ns.YieldForBudget() end
        local section = sections[j]
        if type(section) == "table" and section.id then
            snapshot.sections[#snapshot.sections + 1] = section
            if section.forceVisible then snapshot.forceVisible = true end
            if type(section.statuses) == "table" then
                for k = 1, #section.statuses do
                    if ns.YieldForBudget then ns.YieldForBudget() end
                    snapshot.statuses[#snapshot.statuses + 1] = section.statuses[k]
                end
            end
            if type(section.rows) == "table" then
                for k = 1, #section.rows do
                    if ns.YieldForBudget then ns.YieldForBudget() end
                    local row = section.rows[k]
                    local state = row.state
                    if ns.IsTrackerDataVisible(row) and (state == "missing" or state == "warning") then
                        snapshot.actionable = true
                    end
                end
            end
        end
    end
end

local function ProfessionProviderStatusSection(provider)
    if not provider or not ns.Get("showProfessions") then return nil end
    local sectionCount = ProviderResultSectionCount(provider.lastResult)
    local busy = provider.dirty or provider.queued
    local errorMessage = provider.lastError
    local diagnostic = ns.Get("showProviderDiagnostics") == true
    local label, detail, state, attention

    if errorMessage then
        label = "Profession analysis failed"
        detail = sectionCount > 0 and "Basic guidance remains available. Click for technical details."
            or "No profession recommendations could be built. Click for technical details."
        state, attention = "missing", "critical"
    elseif provider.progressPublished and provider.queued then
        label = "Expanding profession recommendations…"
        detail = string.format("%d %s available; recipe, source and upgrade analysis is continuing.",
            sectionCount, sectionCount == 1 and "section is" or "sections are")
        state = "info"
    elseif sectionCount == 0 and busy then
        label = "Loading profession recommendations…"
        detail = "Building rank and trainer guidance first; detailed recipes follow."
        state = "info"
    elseif diagnostic then
        label = busy and "Refreshing profession recommendations…" or "Profession recommendations ready"
        detail = string.format("%d %s loaded • provider %s.", sectionCount,
            sectionCount == 1 and "section" or "sections", ProviderStateName(provider))
        state = "info"
    else
        return nil
    end

    local reason = provider.buildingReason or provider.invalidationReason or "none"
    local tooltip = string.format("State: %s\nSections: %d\nGeneration: %d\nReason: %s",
        ProviderStateName(provider), sectionCount, provider.generation or 0, tostring(reason))
    if errorMessage then tooltip = tooltip .. "\nError: " .. tostring(errorMessage) end
    return {
        id = "profession-provider-status",
        title = "Profession status",
        forceVisible = errorMessage ~= nil or sectionCount == 0,
        rows = {{
            key = "profession-provider-status",
            label = label,
            detail = detail,
            tooltip = tooltip,
            state = state,
            attention = attention,
            icon = errorMessage and 135813 or 136243,
            onClick = ns.PrintProviderDiagnostics,
            clickHint = "Click to print provider diagnostics in chat.",
        }},
    }
end

function ns.BuildSnapshot()
    -- Forever uses Midnight's secret-value rules. Aura and equipment providers
    -- can receive nil or unreadable values in combat even when the state is
    -- still active. Keep each provider's last trustworthy out-of-combat result;
    -- only providers that explicitly opt in may rebuild while combat restricted.
    local snapshot = { sections = {}, statuses = {}, actionable = false, forceVisible = false }
    for i = 1, #providers do
        if ns.YieldForBudget then ns.YieldForBudget() end
        local provider = providers[i]
        if provider.id == "professions" then
            AppendProviderResult(snapshot, ProfessionProviderStatusSection(provider))
        end
        AppendProviderResult(snapshot, provider.lastResult)
    end
    return snapshot
end

function ns.OpenOptions(moduleKey, pageName)
    if EUI.OpenPlugin then
        EUI.OpenPlugin("EllesmereUIAdventureTracker", moduleKey, pageName)
    end
end

SLASH_EUIADVENTURETRACKER1 = "/adventuretracker"
SLASH_EUIADVENTURETRACKER2 = "/advtracker"
SLASH_EUIADVENTURETRACKER3 = "/at"
SlashCmdList.EUIADVENTURETRACKER = function(message)
    local command = tostring(message or ""):lower():match("^%s*(.-)%s*$")
    if command == "options" or command == "config" then
        ns.OpenOptions("tracker", "Window")
    elseif command == "lock" then
        ns.Set("locked", true, true)
        if ns.ApplyLockState then ns.ApplyLockState() end
    elseif command == "unlock" then
        ns.Set("locked", false, true)
        if ns.ApplyLockState then ns.ApplyLockState() end
    elseif command == "reset" then
        ns.ResetKeys({ "position", "scale", "width" })
    elseif command == "profile" then
        local enabled = ns.Get("debugProfiling") == true
        DB().debugProfiling = not enabled
        if not enabled then ns.ResetProfileMetrics() end
        print("Adventure Tracker profiling " .. (enabled and "disabled." or "enabled; use /at profile report to inspect metrics."))
    elseif command == "profile report" then
        local keys = {}
        for key in pairs(profileMetrics) do keys[#keys + 1] = key end
        table.sort(keys)
        print("Adventure Tracker profiling metrics:")
        for index = 1, #keys do
            local key, metric = keys[index], profileMetrics[keys[index]]
            print(string.format("%s: last %.3f ms, avg %.3f ms, max %.3f ms, %d calls%s",
                key, metric.last or 0, metric.average or 0, metric.maximum or 0, metric.count or 0,
                metric.examined and (", examined " .. tostring(metric.examined)) or ""))
        end
        for index = 1, #providers do
            local provider = providers[index]
            if provider.lastError then
                print(string.format("provider:%s error: %s", provider.id, provider.lastError))
            end
        end
    elseif command == "providers" or command == "diagnostics" then
        ns.PrintProviderDiagnostics()
    elseif command == "questreports" or command == "reports" then
        if ns.ShowQuestReportExport then
            ns.ShowQuestReportExport()
        else
            print("Adventure Tracker quest reports are not available yet.")
        end
    elseif command == "show" then
        ns.Set("enabled", true)
    elseif command == "hide" then
        ns.Set("enabled", false)
    else
        ns.Set("enabled", not ns.Get("enabled"))
    end
end
