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
    backgroundColor = { r = 0.025, g = 0.032, b = 0.04, a = 0.94 },
    sectionBackgroundColor = { r = 1, g = 1, b = 1, a = 0 },
    sectionHoverBackgroundColor = { r = 1, g = 1, b = 1, a = 0.05 },
    entryBackgroundColor = { r = 1, g = 1, b = 1, a = 0.025 },
    entryHoverBackgroundColor = { r = 1, g = 1, b = 1, a = 0.07 },
    borderTexture = "solid",
    borderSize = 1,
    borderColor = { r = 0.20, g = 0.24, b = 0.27, a = 1 },
    titleBarMode = "filled",
    titleBarHeight = 28,
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
    showTitleText = true,
    titleSeparatorSize = 0,
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
    readinessIconReadyBorderColor = { r = 0.20, g = 0.82, b = 0.48, a = 1 },
    readinessIconWarningBorderColor = { r = 1.00, g = 0.68, b = 0.18, a = 1 },
    readinessIconMissingBorderColor = { r = 0.94, g = 0.28, b = 0.28, a = 1 },
    readinessIconUnavailableBorderColor = { r = 0.42, g = 0.45, b = 0.48, a = 1 },
    readinessIconUnknownBorderColor = { r = 0.58, g = 0.53, b = 0.78, a = 1 },
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
    zoneQuestExpandedByCharacter = {},
    zoneQuestVisitedByCharacter = {},
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
    flightTimerBackgroundColor = { r = 0.10, g = 0.10, b = 0.10, a = 0.80 },
    flightTimerBorderTexture = "solid",
    flightTimerBorderSize = 1,
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

function ns.Set(key, value, quiet)
    DB()[key] = value
    if not quiet and ns.RequestRefresh then ns.RequestRefresh() end
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

local function ProfileNow()
    return debugprofilestop and debugprofilestop() or nil
end

function ns.RecordProfileMetric(id, startedAt, reason, examined)
    if ns.Get("debugProfiling") ~= true or not startedAt then return end
    local finishedAt = ProfileNow()
    if not finishedAt then return end
    local elapsed = math.max(0, finishedAt - startedAt)
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
    }
    providers[#providers + 1] = provider
    providersByID[id] = provider
    table.sort(providers, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)
    return true
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
        providers[index].dirty = true
        providers[index].invalidationReason = reason or "all"
    end
end

local function AppendProviderResult(snapshot, result)
    if type(result) ~= "table" then return end
    local sections = result.id and { result } or result
    for j = 1, #sections do
        local section = sections[j]
        if type(section) == "table" and section.id then
            snapshot.sections[#snapshot.sections + 1] = section
            if section.forceVisible then snapshot.forceVisible = true end
            if type(section.statuses) == "table" then
                for k = 1, #section.statuses do
                    snapshot.statuses[#snapshot.statuses + 1] = section.statuses[k]
                end
            end
            if type(section.rows) == "table" then
                for k = 1, #section.rows do
                    local state = section.rows[k].state
                    if state == "missing" or state == "warning" then snapshot.actionable = true end
                end
            end
        end
    end
end

function ns.BuildSnapshot()
    -- Forever uses Midnight's secret-value rules. Aura and equipment providers
    -- can receive nil or unreadable values in combat even when the state is
    -- still active. Keep each provider's last trustworthy out-of-combat result;
    -- only providers that explicitly opt in may rebuild while combat restricted.
    local profileStart = ProfileNow()
    local combatRestricted = IsCombatRestricted()
    local snapshot = { sections = {}, statuses = {}, actionable = false, forceVisible = false }
    for i = 1, #providers do
        local provider = providers[i]
        local result = provider.lastResult
        if provider.dirty and (not combatRestricted or provider.combatSafe) then
            local providerStart = ProfileNow()
            local invalidationReason = provider.invalidationReason
            local ok, built = xpcall(function()
                return provider.build(invalidationReason)
            end, geterrorhandler())
            if ok and type(built) == "table" then
                result = built
                provider.lastResult = built
                provider.dirty = false
            end
            ns.RecordProfileMetric("provider:" .. provider.id, providerStart,
                provider.invalidationReason)
        end
        AppendProviderResult(snapshot, result)
    end
    ns.RecordProfileMetric("BuildSnapshot", profileStart, "render")
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
        ns.Set("locked", true)
        if ns.ApplySettings then ns.ApplySettings() end
    elseif command == "unlock" then
        ns.Set("locked", false)
        if ns.ApplySettings then ns.ApplySettings() end
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
    elseif command == "show" then
        ns.Set("enabled", true)
    elseif command == "hide" then
        ns.Set("enabled", false)
    else
        ns.Set("enabled", not ns.Get("enabled"))
    end
end
