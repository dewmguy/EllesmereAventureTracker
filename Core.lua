-------------------------------------------------------------------------------
-- EllesmereUI Adventure Tracker
-- A contextual readiness and opportunity tracker for WoW Forever.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EUI = _G.EllesmereUI
if not EUI or EUI.IS_FOREVER ~= true then return end

ns.ADDON_NAME = ADDON_NAME
ns.EUI = EUI

local DEFAULTS = {
    enabled = true,
    locked = false,
    collapsed = false,
    width = 340,
    scale = 1.0,
    maximizePaneHeight = false,
    paneGrowthDirection = "DOWN",
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

    showProfessions = true,
    showProfessionProgress = true,
    showProfessionSynergy = true,
    showProfessionGear = true,
    showProfessionCaps = true,
    showProfessionTrainerRecipes = true,
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
    providers[#providers + 1] = {
        id = id,
        order = order or 100,
        build = build,
        combatSafe = type(options) == "table" and options.combatSafe == true,
    }
    table.sort(providers, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)
    return true
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
    local combatRestricted = IsCombatRestricted()
    local snapshot = { sections = {}, statuses = {}, actionable = false, forceVisible = false }
    for i = 1, #providers do
        local provider = providers[i]
        local result = provider.lastResult
        if not combatRestricted or provider.combatSafe then
            local ok, built = xpcall(provider.build, geterrorhandler())
            if ok and type(built) == "table" then
                result = built
                provider.lastResult = built
            end
        end
        AppendProviderResult(snapshot, result)
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
        ns.Set("locked", true)
        if ns.ApplySettings then ns.ApplySettings() end
    elseif command == "unlock" then
        ns.Set("locked", false)
        if ns.ApplySettings then ns.ApplySettings() end
    elseif command == "reset" then
        ns.ResetKeys({ "position", "scale", "width" })
    elseif command == "show" then
        ns.Set("enabled", true)
    elseif command == "hide" then
        ns.Set("enabled", false)
    else
        ns.Set("enabled", not ns.Get("enabled"))
    end
end
