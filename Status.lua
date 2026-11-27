-------------------------------------------------------------------------------
-- Adventure Tracker: compact activity statuses, playtime and character money.
-------------------------------------------------------------------------------
local _, ns = ...
local EUI = ns.EUI

local sessionStartedAt = GetTime and GetTime() or 0
local sessionMoneyReceived, sessionMoneySpent = 0, 0
local lastMoney

local COIN_MEDIA = "Interface\\AddOns\\EllesmereUIAdventureTracker\\Media\\Currency\\"
local GOLD_ICON = "|T" .. COIN_MEDIA .. "coin-gold.png:12:12:1:0|t"
local SILVER_ICON = "|T" .. COIN_MEDIA .. "coin-silver.png:12:12:1:0|t"
local COPPER_ICON = "|T" .. COIN_MEDIA .. "coin-copper.png:12:12:1:0|t"
local STATUS_LINK_PREFIX = "euiadventure:"

local function IsSecret(value)
    return _G.issecretvalue and _G.issecretvalue(value)
end

local function SafeBoolean(func, ...)
    if type(func) ~= "function" then return false end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then return false end
    return value == true
end

local function SafeNumber(value)
    if type(value) ~= "number" or IsSecret(value) then return nil end
    return value
end

local function FormatNumber(value)
    value = math.floor(tonumber(value) or 0)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, formatted = pcall(BreakUpLargeNumbers, value)
        if ok and type(formatted) == "string" and not IsSecret(formatted) then return formatted end
    end
    return tostring(value)
end

local function FormatMoney(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = value % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = FormatNumber(gold) .. GOLD_ICON end
    if silver > 0 then parts[#parts + 1] = silver .. SILVER_ICON end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = copper .. COPPER_ICON end
    return table.concat(parts, " ")
end

local function FormatSession(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if days > 0 then return string.format("%dd %dh %02dm", days, hours, minutes) end
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, secs) end
    return string.format("%d:%02d", minutes, secs)
end

local function FormatVerboseDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local values = {
        { math.floor(seconds / 86400), "day" },
        { math.floor((seconds % 86400) / 3600), "hour" },
        { math.floor((seconds % 3600) / 60), "minute" },
        { seconds % 60, "second" },
    }
    local parts = {}
    for i = 1, #values do
        local value, unit = values[i][1], values[i][2]
        if value > 0 or (i == #values and #parts == 0) then
            parts[#parts + 1] = string.format("%d %s%s", value, unit, value == 1 and "" or "s")
        end
    end
    return table.concat(parts, ", ")
end

local function TotalPlayed()
    if EUI.RequestTimePlayed then
        local ok, value = pcall(EUI.RequestTimePlayed)
        if ok and not IsSecret(value) then return tonumber(value) end
    elseif type(RequestTimePlayed) == "function" then
        pcall(RequestTimePlayed)
    end
end

local SHORT_SPEC_NAMES = {
    ["BEAST MASTERY"] = "BM",
    ["MARKSMANSHIP"] = "MM",
    ["FERAL COMBAT"] = "Feral",
    ["PROTECTION"] = "Prot",
    ["RETRIBUTION"] = "Ret",
    ["DISCIPLINE"] = "Disc",
    ["ASSASSINATION"] = "Assass",
    ["SUBTLETY"] = "Sub",
    ["ELEMENTAL"] = "Ele",
    ["ENHANCEMENT"] = "Enh",
    ["RESTORATION"] = "Resto",
    ["AFFLICTION"] = "Aff",
    ["DEMONOLOGY"] = "Demo",
    ["DESTRUCTION"] = "Destro",
}

local function ShortSpecName(name)
    return SHORT_SPEC_NAMES[tostring(name):upper()] or name
end

local function CharacterContext()
    if not ns.Get("showContext") then return nil end
    local zone = ns.GetZoneName()
    local role = ns.ROLE_LABELS[ns.GetRole()] or ns.GetRole()
    local className = UnitClass and UnitClass("player") or "Character"
    local specName = ns.GetCurrentSpecializationName and ns.GetCurrentSpecializationName()
    local buildName = specName and specName ~= className
        and (ShortSpecName(specName) .. " " .. className) or className
    return table.concat({ zone, buildName, role }, "  •  ")
end

local goldLedger
if type(EUI.GetGoldLedger) == "function" then
    local ok, value = pcall(EUI.GetGoldLedger)
    if ok and type(value) == "table" then goldLedger = value end
end

local function CurrentMoney()
    if goldLedger and type(goldLedger.Money) == "function" then
        local ok, value = pcall(goldLedger.Money)
        value = ok and SafeNumber(value) or nil
        if value then return value end
    end
    if type(GetMoney) == "function" then
        local ok, value = pcall(GetMoney)
        return ok and SafeNumber(value) or nil
    end
end

lastMoney = CurrentMoney()

local function LinkedStatus(kind, text)
    return string.format("|H%s%s|h%s|h", STATUS_LINK_PREFIX, kind, text)
end

local function StatusContext()
    local statuses = {}
    local showActivities = ns.Get("showStatuses")
    if showActivities and ns.Get("showLifeStatus") then
        if SafeBoolean(UnitIsGhost, "player") then
            statuses[#statuses + 1] = "Ghost"
        elseif SafeBoolean(UnitIsDead, "player") then
            statuses[#statuses + 1] = "Dead"
        end
    end
    if showActivities and ns.Get("showFlightStatus") and ((ns.IsAdventureTrackerInFlight and ns.IsAdventureTrackerInFlight())
        or SafeBoolean(UnitOnTaxi, "player")) then statuses[#statuses + 1] = "In Flight" end
    if showActivities and ns.Get("showCombatStatus") and ns.IsCombatRestricted and ns.IsCombatRestricted() then
        statuses[#statuses + 1] = "In Combat"
    end
    if showActivities and ns.Get("showInstanceStatus") and IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if not IsSecret(inInstance) and inInstance then
            local labels = { party = "Dungeon", raid = "Raid", pvp = "Battleground", arena = "Arena", scenario = "Scenario" }
            statuses[#statuses + 1] = labels[instanceType] or "Instance"
        end
    end
    if showActivities and ns.Get("showRestingStatus") and SafeBoolean(IsResting) then
        statuses[#statuses + 1] = "Resting"
    end

    -- The session clock deliberately sits immediately after Resting's slot so
    -- those two quiet, persistent context items read together when in a city.
    if ns.Get("showPlaytime") and ns.Get("showSessionPlaytime") then
        local now = GetTime and GetTime() or sessionStartedAt
        statuses[#statuses + 1] = LinkedStatus("session", FormatSession(now - sessionStartedAt))
    end
    if ns.Get("showGoldStatus") then
        local money = CurrentMoney()
        if money then statuses[#statuses + 1] = LinkedStatus("gold", FormatMoney(money)) end
    end

    if showActivities and ns.Get("showMountedStatus") and not SafeBoolean(UnitOnTaxi, "player") and SafeBoolean(IsMounted) then
        statuses[#statuses + 1] = "Mounted"
    end
    if showActivities and ns.Get("showPresenceStatus") then
        if SafeBoolean(UnitIsAFK, "player") then
            statuses[#statuses + 1] = "AFK"
        elseif SafeBoolean(UnitIsDND, "player") then
            statuses[#statuses + 1] = "DND"
        end
    end
    return #statuses > 0 and table.concat(statuses, "  •  ") or nil
end

local function AddTooltipMoneyLine(label, money, r, g, b)
    if type(money) ~= "number" then return end
    GameTooltip:AddDoubleLine(label, FormatMoney(money), 0.78, 0.82, 0.86, r or 1, g or 1, b or 1)
end

local function ShowPlaytimeTooltip(owner)
    local now = GetTime and GetTime() or sessionStartedAt
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 35)
    GameTooltip:SetText("Playtime", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Current UI session", FormatVerboseDuration(now - sessionStartedAt),
        0.78, 0.82, 0.86, 1, 1, 1)
    if ns.Get("showTotalPlaytime") then
        local total = TotalPlayed()
        GameTooltip:AddDoubleLine("Total /played on this character",
            total and FormatVerboseDuration(total) or "Loading from the server…",
            0.78, 0.82, 0.86, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("The session timer starts when this UI session loads or reloads. Total /played is the server's character-specific lifetime playtime and may take a moment to arrive.",
        0.65, 0.70, 0.74, true)
    GameTooltip:Show()
end

local goldStatisticCategory, goldStatisticIndex, goldStatisticID

local function FindGoldStatistic()
    if type(GetStatisticsCategoryList) ~= "function" or type(GetCategoryNumAchievements) ~= "function"
        or type(GetStatistic) ~= "function" or type(GetAchievementInfo) ~= "function" then return false end
    local ok, categories = pcall(GetStatisticsCategoryList)
    if not ok or IsSecret(categories) or type(categories) ~= "table" then return false end
    for _, categoryID in ipairs(categories) do
        local countOK, count = pcall(GetCategoryNumAchievements, categoryID)
        count = countOK and not IsSecret(count) and tonumber(count) or 0
        for index = 1, count do
            local statOK, _, skip, statisticID = pcall(GetStatistic, categoryID, index)
            if statOK and not IsSecret(skip) and not skip and not IsSecret(statisticID) and statisticID then
                local infoOK, _, name = pcall(GetAchievementInfo, statisticID)
                local normalized = infoOK and not IsSecret(name) and type(name) == "string" and name:lower() or nil
                if statisticID == 328 or normalized == "total gold acquired" then
                    goldStatisticCategory, goldStatisticIndex, goldStatisticID = categoryID, index, statisticID
                    return true
                end
            end
        end
    end
    return false
end

local function CharacterGoldStatistic()
    if type(GetStatistic) ~= "function" then return nil end
    if not goldStatisticCategory and not FindGoldStatistic() then
        -- Retail-compatible fallback; Forever normally uses the category/index form.
        local ok, value = pcall(GetStatistic, 328)
        if not ok or IsSecret(value) or (type(value) ~= "string" and type(value) ~= "number") then return nil end
        value = tostring(value)
        return value ~= "" and value ~= "--" and value ~= "0" and value or nil
    end
    local ok, value, _, statisticID = pcall(GetStatistic, goldStatisticCategory, goldStatisticIndex)
    if not ok or IsSecret(value) or IsSecret(statisticID) or statisticID ~= goldStatisticID then
        goldStatisticCategory, goldStatisticIndex, goldStatisticID = nil, nil, nil
        return nil
    end
    if type(value) ~= "string" and type(value) ~= "number" then return nil end
    value = tostring(value)
    return value ~= "" and value ~= "--" and value ~= "0" and value or nil
end

local function ShowGoldTooltip(owner)
    local current = CurrentMoney()
    local playerName = UnitName and UnitName("player") or "Current character"
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 35)
    GameTooltip:SetText("Character Gold", 1, 0.82, 0)
    AddTooltipMoneyLine(playerName, current)

    local lifetime = CharacterGoldStatistic()
    if lifetime then
        GameTooltip:AddDoubleLine("Lifetime gold acquired", lifetime, 0.78, 0.82, 0.86, 1, 1, 1)
    end
    if sessionMoneyReceived > 0 then AddTooltipMoneyLine("Money received this session", sessionMoneyReceived, 0.35, 1, 0.55) end
    if sessionMoneySpent > 0 then AddTooltipMoneyLine("Money spent or transferred this session", sessionMoneySpent, 1, 0.45, 0.35) end

    local entries, otherTotal = {}, 0
    local currentKey = goldLedger and type(goldLedger.CharKey) == "function" and goldLedger.CharKey() or nil
    local _, playerRealm = UnitFullName and UnitFullName("player")
    playerRealm = playerRealm or (GetRealmName and GetRealmName())
    if goldLedger and type(goldLedger.Chars) == "function" then
        local ok, characters = pcall(goldLedger.Chars)
        if ok and type(characters) == "table" then
            for key, data in pairs(characters) do
                local money = type(data) == "table" and SafeNumber(data.money) or nil
                local sameCharacter = key == currentKey or (not currentKey and type(data) == "table"
                    and data.name == playerName and (not data.realm or not playerRealm or data.realm == playerRealm))
                if not sameCharacter and money then
                    entries[#entries + 1] = { name = data.name or key, realm = data.realm, money = money }
                    otherTotal = otherTotal + money
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.money == b.money then return tostring(a.name) < tostring(b.name) end
        return a.money > b.money
    end)

    local warband
    if goldLedger and type(goldLedger.WarbandMoney) == "function" then
        local ok, value = pcall(goldLedger.WarbandMoney)
        warband = ok and SafeNumber(value) or nil
    end
    if #entries > 0 or warband then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Known account balances", 0.35, 0.82, 1)
        local shown = math.min(#entries, 10)
        for i = 1, shown do
            local entry = entries[i]
            local name = entry.name
            if entry.realm and entry.realm ~= "" then name = name .. " – " .. entry.realm end
            AddTooltipMoneyLine(name, entry.money)
        end
        if #entries > shown then
            GameTooltip:AddLine(string.format("…and %d more tracked character%s", #entries - shown,
                (#entries - shown) == 1 and "" or "s"), 0.65, 0.70, 0.74)
        end
        if #entries > 0 then AddTooltipMoneyLine("Other-character subtotal", otherTotal, 0.35, 0.82, 1) end
        if warband then AddTooltipMoneyLine("Warband bank", warband, 1, 0.80, 0.50) end
        AddTooltipMoneyLine("Known total", (current or 0) + otherTotal + (warband or 0), 1, 0.82, 0)
    end

    GameTooltip:AddLine(" ")
    if goldLedger and type(goldLedger.IsTracking) == "function" and goldLedger.IsTracking() == false then
        GameTooltip:AddLine("EllesmereUI gold tracking is disabled, so saved balances for other characters will not update.",
            1, 0.55, 0.35, true)
    else
        GameTooltip:AddLine("Other-character balances use EllesmereUI's shared gold ledger and update after those characters are played. They are balance snapshots, not lifetime earnings.",
            0.65, 0.70, 0.74, true)
    end
    GameTooltip:Show()
end

function ns.ShowStatusLinkTooltip(owner, link)
    if type(link) ~= "string" or link:sub(1, #STATUS_LINK_PREFIX) ~= STATUS_LINK_PREFIX then return false end
    local kind = link:sub(#STATUS_LINK_PREFIX + 1)
    if kind == "session" then
        ShowPlaytimeTooltip(owner)
        return true
    elseif kind == "gold" then
        ShowGoldTooltip(owner)
        return true
    end
    return false
end

function ns.GetTrackerContextLines()
    local base = CharacterContext()
    local statuses = StatusContext()
    local first
    if base and statuses then
        first = base .. "  •  " .. statuses
    else
        first = base or statuses
    end
    return first, nil
end

local function OnMoneyChanged(event, money)
    money = SafeNumber(money) or CurrentMoney()
    if money and lastMoney then
        local delta = money - lastMoney
        if delta > 0 then
            sessionMoneyReceived = sessionMoneyReceived + delta
        elseif delta < 0 then
            sessionMoneySpent = sessionMoneySpent - delta
        end
    end
    if money then lastMoney = money end
    if ns.RefreshTrackerContextText then ns.RefreshTrackerContextText() end
end

if goldLedger and type(goldLedger.Register) == "function" then
    goldLedger.Register("adventure-tracker-status", OnMoneyChanged)
elseif type(CreateFrame) == "function" then
    local moneyEvents = CreateFrame("Frame")
    moneyEvents:RegisterEvent("PLAYER_MONEY")
    moneyEvents:SetScript("OnEvent", function(_, event) OnMoneyChanged(event) end)
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1, function()
        if ns.RefreshTrackerContextText then ns.RefreshTrackerContextText() end
    end)
end
