-------------------------------------------------------------------------------
-- Adventure Tracker: compact, independently styled flight timer.
-------------------------------------------------------------------------------
local _, ns = ...
local EUI = ns.EUI

local DEFAULT_SPEED = 30.4
local ROUTE_HISTORY = 5
local FLIGHT_ICON = "Interface\\Minimap\\Tracking\\FlightMaster"

local pending
local active
local ticker
local taxiHooked
local landingHooked

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

local function SpeedMultiplier()
    if not (C_Traits and C_Traits.GetConfigIDByTreeID and C_Traits.GetNodeInfo) then return 1 end
    local okConfig, configID = pcall(C_Traits.GetConfigIDByTreeID, 1188)
    local okNode, node = false, nil
    if configID then okNode, node = pcall(C_Traits.GetNodeInfo, configID, 110300) end
    return okConfig and okNode and node and (tonumber(node.activeRank) or 0) > 0 and 1.2 or 1
end

local function RouteDB(create)
    local db = ns.DB()
    if type(db.flightTimerRoutes) ~= "table" and create then db.flightTimerRoutes = {} end
    return db.flightTimerRoutes
end

local function Median(values)
    if type(values) ~= "table" then return nil end
    local sorted = {}
    for index = 1, #values do
        local value = tonumber(values[index])
        if value and value > 0 then sorted[#sorted + 1] = value end
    end
    if #sorted == 0 then return nil end
    table.sort(sorted)
    local middle = math.floor(#sorted / 2) + 1
    if #sorted % 2 == 1 then return sorted[middle] end
    return (sorted[middle - 1] + sorted[middle]) / 2
end

local function LearnedBase(routeKey)
    local routes = RouteDB(false)
    local route = routes and routeKey and routes[routeKey]
    return type(route) == "table" and Median(route.times) or nil
end

local function RouteInfo(slot)
    if type(slot) ~= "number" or type(GetNumRoutes) ~= "function" then return nil end
    local hops = GetNumRoutes(slot)
    if type(hops) ~= "number" or hops < 1 then return nil end

    local mapID = GetTaxiMapID and GetTaxiMapID()
    local nodes = mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_TaxiMap.GetAllTaxiNodes(mapID)
    local idBySlot = {}
    for _, node in ipairs(nodes or idBySlot) do idBySlot[node.slotIndex] = node.nodeID end

    local ids, points = {}, {}
    local startSlot = TaxiGetNodeSlot(slot, 1, true)
    ids[1] = idBySlot[startSlot]
    points[1] = { name = TaxiNodeName(startSlot), yards = 0 }
    local routeData = EUI._FlightTimerRoutes
    local yards = 0
    for hop = 1, hops do
        local fromSlot = TaxiGetNodeSlot(slot, hop, true)
        local toSlot = TaxiGetNodeSlot(slot, hop, false)
        local fromID, toID = idBySlot[fromSlot], idBySlot[toSlot]
        ids[hop + 1] = toID
        local hopYards = routeData and fromID and toID and routeData[fromID * 10000 + toID]
        yards = yards and hopYards and yards + hopYards
        points[#points + 1] = { name = TaxiNodeName(toSlot), yards = yards }
    end

    local validIDs = true
    for index = 1, #points do
        if type(ids[index]) ~= "number" then validIDs = false break end
    end
    local totalYards = yards and yards > 0 and yards or nil
    return {
        key = validIDs and table.concat(ids, ">") or nil,
        points = points,
        yards = totalYards,
        staticBase = totalYards and totalYards / DEFAULT_SPEED or nil,
        from = points[1] and points[1].name or nil,
        destination = points[#points] and points[#points].name or nil,
    }
end

local function RecordFlight(flight, elapsed)
    if not (ns.Get("flightTimerLearnTimes") and flight and flight.sawTaxi and not flight.early) then return end
    if not (flight.info and flight.info.key and elapsed >= 5 and elapsed <= 7200) then return end
    local normalized = elapsed * (flight.mult or 1)
    local learned = LearnedBase(flight.info.key)
    local reference = learned or flight.info.staticBase
    if reference and (normalized < reference * (learned and 0.5 or 0.35)
        or normalized > reference * (learned and 2 or 3)) then return end

    local routes = RouteDB(true)
    local route = routes[flight.info.key]
    if type(route) ~= "table" then
        route = { times = {}, samples = 0 }
        routes[flight.info.key] = route
    elseif type(route.times) ~= "table" then
        route.times = {}
    end
    route.times[#route.times + 1] = normalized
    while #route.times > ROUTE_HISTORY do table.remove(route.times, 1) end
    route.samples = (tonumber(route.samples) or 0) + 1
    route.lastSeen = time and time() or nil
    route.from = flight.info.from
    route.destination = flight.info.destination
end

local function StartTicker()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    ticker = C_Timer.NewTicker(0.5, function()
        if active and UnitOnTaxi and UnitOnTaxi("player") then active.sawTaxi = true end
        if active and active.start and Now() - active.start > 2
            and not (UnitOnTaxi and UnitOnTaxi("player")) then
            local flight = active
            active = nil
            RecordFlight(flight, Now() - flight.start)
            if ticker and ticker.Cancel then ticker:Cancel() end
            ticker = nil
        end
        if ns.RequestRefresh then ns.RequestRefresh() end
    end)
end

local function StopTicker()
    if ticker and ticker.Cancel then ticker:Cancel() end
    ticker = nil
end

local function BeginFlight()
    if not (pending and Now() - pending.clicked < 5) then pending = nil return end
    local info = pending.info
    pending = nil
    local mult = SpeedMultiplier()
    local learned = ns.Get("flightTimerLearnTimes") and info.key and LearnedBase(info.key)
    local base = learned or info.staticBase
    active = {
        info = info,
        start = Now(),
        mult = mult,
        eta = base and base / mult or nil,
        learned = learned ~= nil,
    }
    StartTicker()
    if ns.RequestRefresh then ns.RequestRefresh() end
end

local function FinishFlight(learn)
    local flight = active
    if not flight then return end
    active = nil
    if learn then RecordFlight(flight, Now() - flight.start) end
    StopTicker()
    if ns.RequestRefresh then ns.RequestRefresh() end
end

local function RetargetEarlyLanding()
    local flight = active
    if not flight then return end
    flight.early = true
    local info = flight.info
    if not (flight.eta and info and info.yards and info.points) then return end
    local elapsed = Now() - flight.start
    local flown = math.max(0, math.min(1, elapsed / flight.eta)) * info.yards
    for index = 2, #info.points do
        local point = info.points[index]
        if point.yards and point.yards > flown then
            flight.eta = flight.eta * point.yards / info.yards
            info.yards = point.yards
            info.destination = point.name
            for remove = #info.points, index + 1, -1 do info.points[remove] = nil end
            break
        end
    end
end

local function HookFlightAPI()
    if not taxiHooked and type(TakeTaxiNode) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc("TakeTaxiNode", function(slot)
            if not ns.Get("showFlightTimer") then pending = nil return end
            local info = RouteInfo(slot)
            pending = info and { info = info, clicked = Now() } or nil
        end)
        taxiHooked = true
    end
    if not landingHooked and type(TaxiRequestEarlyLanding) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc("TaxiRequestEarlyLanding", RetargetEarlyLanding)
        landingHooked = true
    end
end

local function ColorValue(key)
    local color = ns.Get(key)
    local fallback = ns.DEFAULTS[key] or {}
    if type(color) ~= "table" then color = fallback end
    return color.r or fallback.r or 1, color.g or fallback.g or 1,
        color.b or fallback.b or 1, color.a == nil and (fallback.a or 1) or color.a
end

local function ThemeColor(modeKey, customKey)
    local mode = ns.Get(modeKey)
    if mode == "class" and EUI.GetPlayerClassColor then
        local ok, r, g, b = pcall(EUI.GetPlayerClassColor)
        if ok and r and g and b then return r, g, b, 1 end
    elseif mode == "accent" and EUI.GetAccentColor then
        local ok, r, g, b = pcall(EUI.GetAccentColor)
        if ok and r and g and b then return r, g, b, 1 end
    end
    return ColorValue(customKey)
end

local function FillColor()
    local mode = ns.Get("flightTimerFillColorMode")
    if mode == "class" then
        if EUI.GetPlayerClassColor then
            local ok, r, g, b = pcall(EUI.GetPlayerClassColor)
            if ok and r and g and b then return r, g, b, 1 end
        end
        local _, classFile = UnitClass("player")
        local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if color then return color.r, color.g, color.b, 1 end
    elseif mode == "accent" and EUI.GetAccentColor then
        local ok, r, g, b = pcall(EUI.GetAccentColor)
        if ok and r and g and b then return r, g, b, 1 end
    end
    return ColorValue("flightTimerFillColor")
end

local function DetailText(elapsed, eta)
    local parts = {}
    if ns.Get("flightTimerShowElapsed") then parts[#parts + 1] = FormatClock(elapsed) .. " elapsed" end
    if eta and ns.Get("flightTimerShowRemaining") then
        parts[#parts + 1] = FormatClock(math.max(0, eta - elapsed)) .. " remaining"
    end
    if eta and ns.Get("flightTimerShowTotal") then parts[#parts + 1] = FormatClock(eta) .. " total" end
    if #parts == 0 then parts[1] = eta and FormatClock(math.max(0, eta - elapsed)) .. " remaining"
        or FormatClock(elapsed) .. " elapsed" end
    return table.concat(parts, "  •  ")
end

local function Build()
    if not ns.Get("showFlightTimer") or not active then return {} end
    local elapsed = math.max(0, Now() - active.start)
    local eta = active.eta
    local progress = eta and math.max(0, math.min(1, elapsed / eta)) or 0
    local fr, fg, fb, fa = FillColor()
    local br, bg, bb, ba = ColorValue("flightTimerBackgroundColor")
    local rr, rg, rb, ra = ColorValue("flightTimerBorderColor")
    local lr, lg, lb, la = ThemeColor("flightTimerDestinationColorMode", "flightTimerDestinationColor")
    local dr, dg, db, da = ThemeColor("flightTimerTimeColorMode", "flightTimerTimeColor")
    local destination = active.info and active.info.destination
    local label = ns.Get("flightTimerShowDestination") and destination or nil
    label = label and ("Flying to " .. label) or "Flight in progress"
    return {
        id = "flight-timer",
        title = "Flight",
        forceVisible = true,
        rows = {{
            key = "active-flight",
            label = label,
            detail = DetailText(elapsed, eta),
            tooltip = string.format("%s%s\nAdventure Tracker keeps its estimate and learned route history separate from the native EllesmereUI flight timer.",
                destination and ("Destination: " .. destination .. "\n") or "",
                active.learned and "Estimate: learned route median" or (eta and "Estimate: route distance" or "Estimate unavailable")),
            state = "info",
            icon = FLIGHT_ICON,
            hideIcon = not ns.Get("flightTimerShowIcon"),
            font = ns.Get("flightTimerFont"),
            fontOutline = ns.Get("flightTimerFontOutline"),
            labelFontSize = ns.Get("flightTimerDestinationFontSize"),
            detailFontSize = ns.Get("flightTimerTimeFontSize"),
            labelColor = { lr, lg, lb, la },
            detailColor = { dr, dg, db, da },
            progress = {
                value = progress,
                height = ns.Get("flightTimerBarHeight"),
                texture = ns.Get("flightTimerBarTexture"),
                fillColor = { fr, fg, fb, fa },
                backgroundColor = { br, bg, bb, ba },
                borderTexture = ns.Get("flightTimerBorderTexture"),
                borderSize = ns.Get("flightTimerBorderSize"),
                borderColor = { rr, rg, rb, ra },
            },
        }},
    }
end

function ns.ResetFlightTimerRoutes()
    ns.DB().flightTimerRoutes = {}
    if active and active.info then
        local base = active.info.staticBase
        active.eta = base and base / (active.mult or 1) or nil
        active.learned = false
    end
    if ns.RequestRefresh then ns.RequestRefresh() end
end

function ns.IsAdventureTrackerInFlight()
    return active ~= nil or (UnitOnTaxi and UnitOnTaxi("player")) == true
end

ns.RegisterProvider("flight-timer", 1, Build, { combatSafe = true })

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_OPENED", "ADDON_LOADED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "TAXIMAP_OPENED" then
        HookFlightAPI()
    elseif event == "ADDON_LOADED" and (...) == "Blizzard_FlightMap" then
        HookFlightAPI()
    elseif event == "PLAYER_CONTROL_LOST" then
        BeginFlight()
    elseif event == "PLAYER_CONTROL_GAINED" and active and not UnitOnTaxi("player") then
        FinishFlight(active.sawTaxi and not active.early)
    end
end)

HookFlightAPI()
