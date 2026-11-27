-------------------------------------------------------------------------------
-- Adventure Tracker: compact activity statuses and playtime context.
-------------------------------------------------------------------------------
local _, ns = ...
local EUI = ns.EUI

local sessionStartedAt = GetTime and GetTime() or 0

local function SafeBoolean(func, ...)
    if type(func) ~= "function" then return false end
    local ok, value = pcall(func, ...)
    if not ok or (_G.issecretvalue and _G.issecretvalue(value)) then return false end
    return value == true
end

local function FormatSession(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if days > 0 then return string.format("%dd %dh %02dm", days, hours, minutes) end
    return string.format("%d:%02d:%02d", hours, minutes, secs)
end

local function FormatPlayed(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then return string.format("%dd %dh %dm", days, hours, minutes) end
    if hours > 0 then return string.format("%dh %dm", hours, minutes) end
    return string.format("%dm", minutes)
end

local function CharacterContext()
    if not ns.Get("showContext") then return nil end
    local zone = ns.GetZoneName()
    local role = ns.ROLE_LABELS[ns.GetRole()] or ns.GetRole()
    local className = UnitClass and UnitClass("player") or "Character"
    local specName
    if GetSpecialization and GetSpecializationInfo then
        local specialization = GetSpecialization()
        if specialization then
            local ok, _, name = pcall(GetSpecializationInfo, specialization)
            local secret = ok and _G.issecretvalue and _G.issecretvalue(name)
            if ok and not secret and type(name) == "string" and name ~= "" then specName = name end
        end
    end
    local build = specName and (specName .. " " .. className) or className
    return table.concat({ zone, build, role }, "  •  ")
end

local function ActivityStatuses()
    if not ns.Get("showStatuses") then return nil end
    local statuses = {}
    if ns.Get("showLifeStatus") then
        if SafeBoolean(UnitIsGhost, "player") then
            statuses[#statuses + 1] = "Ghost"
        elseif SafeBoolean(UnitIsDead, "player") then
            statuses[#statuses + 1] = "Dead"
        end
    end
    if ns.Get("showFlightStatus") and ((ns.IsAdventureTrackerInFlight and ns.IsAdventureTrackerInFlight())
        or SafeBoolean(UnitOnTaxi, "player")) then statuses[#statuses + 1] = "In Flight" end
    if ns.Get("showCombatStatus") and ns.IsCombatRestricted and ns.IsCombatRestricted() then
        statuses[#statuses + 1] = "In Combat"
    end
    if ns.Get("showInstanceStatus") and IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance then
            local labels = { party = "Dungeon", raid = "Raid", pvp = "Battleground", arena = "Arena", scenario = "Scenario" }
            statuses[#statuses + 1] = labels[instanceType] or "Instance"
        end
    end
    if ns.Get("showRestingStatus") and SafeBoolean(IsResting) then statuses[#statuses + 1] = "Resting" end
    if ns.Get("showMountedStatus") and not SafeBoolean(UnitOnTaxi, "player") and SafeBoolean(IsMounted) then
        statuses[#statuses + 1] = "Mounted"
    end
    if ns.Get("showPresenceStatus") then
        if SafeBoolean(UnitIsAFK, "player") then
            statuses[#statuses + 1] = "AFK"
        elseif SafeBoolean(UnitIsDND, "player") then
            statuses[#statuses + 1] = "DND"
        end
    end
    return #statuses > 0 and table.concat(statuses, "  •  ") or nil
end

local function PlaytimeContext()
    if not ns.Get("showPlaytime") then return nil end
    local parts = {}
    local now = GetTime and GetTime() or sessionStartedAt
    if ns.Get("showSessionPlaytime") then
        parts[#parts + 1] = "Session " .. FormatSession(now - sessionStartedAt)
    end
    if ns.Get("showTotalPlaytime") then
        local total
        if EUI.RequestTimePlayed then
            local ok, value = pcall(EUI.RequestTimePlayed)
            if ok then total = tonumber(value) end
        elseif RequestTimePlayed then
            pcall(RequestTimePlayed)
        end
        parts[#parts + 1] = total and ("/played " .. FormatPlayed(total)) or "/played loading…"
    end
    return #parts > 0 and table.concat(parts, "  •  ") or nil
end

function ns.GetTrackerContextLines()
    local base = CharacterContext()
    local statuses = ActivityStatuses()
    local first
    if base and statuses then
        first = base .. "  •  " .. statuses
    else
        first = base or statuses
    end
    return first, PlaytimeContext()
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1, function()
        if ns.RefreshTrackerContextText then ns.RefreshTrackerContextText() end
    end)
end
