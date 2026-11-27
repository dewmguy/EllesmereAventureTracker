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
    opacity = 0.96,
    position = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -330, y = -220 },
    hideInCombat = true,
    hideInInstances = false,
    hideWhenReady = false,
    showContext = true,

    showReadiness = true,
    trackCamp = true,
    trackSleepingBag = true,
    trackFood = true,
    trackClassBuffs = true,
    trackWeaponEnhancements = true,
    readinessWarnMinutes = 10,
    showCompletedReadiness = false,
    roleByCharacter = {},

    showWorldBuffs = true,
    showActiveWorldBuffs = true,
    showMissingWorldBuffs = false,
    worldBuffCurrentZoneOnly = false,
    worldBuffWarnMinutes = 10,

    showLegacy = true,
    showUnspentLegacy = true,

    showProfessions = true,
    showProfessionProgress = true,
    showProfessionCaps = true,
    showCompletedProfessions = false,
    showProfessionZoneHints = true,
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

function ns.RegisterProvider(id, order, build)
    if type(id) ~= "string" or type(build) ~= "function" then return false end
    providers[#providers + 1] = { id = id, order = order or 100, build = build }
    table.sort(providers, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)
    return true
end

function ns.BuildSnapshot()
    local snapshot = { sections = {}, statuses = {}, actionable = false }
    for i = 1, #providers do
        local provider = providers[i]
        local ok, result = xpcall(provider.build, geterrorhandler())
        if ok and type(result) == "table" then
            local sections = result.id and { result } or result
            for j = 1, #sections do
                local section = sections[j]
                if type(section) == "table" and section.id then
                    snapshot.sections[#snapshot.sections + 1] = section
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
        ns.ResetKeys({ "position", "scale", "width", "opacity" })
    elseif command == "show" then
        ns.Set("enabled", true)
    elseif command == "hide" then
        ns.Set("enabled", false)
    else
        ns.Set("enabled", not ns.Get("enabled"))
    end
end
