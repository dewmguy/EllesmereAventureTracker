-------------------------------------------------------------------------------
-- Adventure Tracker: local fishing and skinning observations.
-------------------------------------------------------------------------------
local _, ns = ...

local FISHING_SPELLS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }
local SKINNING_SPELLS = { [8613] = true, [8617] = true, [8618] = true, [10768] = true }
local pendingCast

local function Now()
    return GetTime and GetTime() or 0
end

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, value = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(value) == "string" then return value end
    end
    if GetSpellInfo then
        local ok, value = pcall(GetSpellInfo, spellID)
        if ok and type(value) == "table" then value = value.name end
        if ok and type(value) == "string" then return value end
    end
end

local function CastSent(unit, arg2, arg3, arg4)
    if unit ~= "player" then return end
    local spellID = type(arg4) == "number" and arg4 or nil
    local spell = spellID and SpellName(spellID) or (type(arg2) == "string" and arg2 or nil)
    local kind
    if (spellID and FISHING_SPELLS[spellID]) or spell == "Fishing" then kind = "fishing"
    elseif (spellID and SKINNING_SPELLS[spellID]) or spell == "Skinning" then kind = "skinning" end
    if kind then
        pendingCast = {
            kind = kind,
            at = Now(),
            castGUID = spellID and type(arg3) == "string" and arg3 or nil,
        }
    end
end

local function PendingMatches(castGUID)
    if not pendingCast then return false end
    if pendingCast.castGUID and type(castGUID) == "string" and castGUID:find("^Cast%-") then
        return pendingCast.castGUID == castGUID
    end
    return true
end

local function FishingWindow()
    if type(IsFishingLoot) ~= "function" then return false end
    local ok, value = pcall(IsFishingLoot)
    return ok and value == true
end

local function LootItems()
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then return nil end
    local result = {}
    local count = GetNumLootItems() or 0
    for index = 1, math.min(50, count) do
        local okLink, link = pcall(GetLootSlotLink, index)
        local itemID = okLink and type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if itemID then
            local quantity, name = 1, nil
            if GetLootSlotInfo then
                local okInfo, _, itemName, itemCount = pcall(GetLootSlotInfo, index)
                if okInfo then
                    name = type(itemName) == "string" and itemName or nil
                    quantity = math.max(1, tonumber(itemCount) or 1)
                end
            end
            result[#result + 1] = { itemID = itemID, name = name, count = quantity }
        end
    end
    return #result > 0 and result or nil
end

local function Record(kind, items)
    local zoneName, mapID = ns.GetZoneName()
    if not mapID or type(items) ~= "table" then return end
    local db = ns.DB()
    if type(db.observedGatheringByZone) ~= "table" then db.observedGatheringByZone = {} end
    local zoneKey = tostring(mapID)
    local zone = db.observedGatheringByZone[zoneKey]
    if type(zone) ~= "table" then
        zone = { name = zoneName, fishing = { windows = 0, items = {} }, skinning = { windows = 0, items = {} } }
        db.observedGatheringByZone[zoneKey] = zone
    end
    local bucket = zone[kind]
    if type(bucket) ~= "table" then bucket = { windows = 0, items = {} }; zone[kind] = bucket end
    if type(bucket.items) ~= "table" then bucket.items = {} end
    bucket.windows = (tonumber(bucket.windows) or 0) + 1
    bucket.lastSeen = time and time() or 0
    zone.name = zoneName
    local seen = {}
    for _, item in ipairs(items) do
        local key = tostring(item.itemID)
        local row = bucket.items[key]
        if type(row) ~= "table" then
            row = { itemID = item.itemID, name = item.name, count = 0, windows = 0 }
            bucket.items[key] = row
        end
        row.name = item.name or row.name
        row.count = (tonumber(row.count) or 0) + (tonumber(item.count) or 1)
        if not seen[key] then row.windows = (tonumber(row.windows) or 0) + 1; seen[key] = true end
    end
    if ns.RequestRefresh then ns.RequestRefresh("professions", "gathering observation") end
end

local function LootOpened()
    local kind
    if FishingWindow() then
        kind = "fishing"
    elseif pendingCast and pendingCast.kind == "skinning" and pendingCast.succeeded
        and Now() - pendingCast.at <= 8 then
        kind = "skinning"
    elseif pendingCast and pendingCast.kind == "fishing" and Now() - pendingCast.at <= 30 then
        kind = "fishing"
    end
    if not kind then return end
    local items = LootItems()
    if items then Record(kind, items) end
    pendingCast = nil
end

function ns.GetObservedGathering(mapID, kind)
    local root = ns.DB().observedGatheringByZone
    local zone = type(root) == "table" and root[tostring(mapID or "")]
    local bucket = type(zone) == "table" and zone[kind]
    return type(bucket) == "table" and bucket or nil
end

function ns.ResetObservedGathering()
    ns.DB().observedGatheringByZone = nil
    if ns.RequestRefresh then ns.RequestRefresh("professions", "gathering observations reset") end
end

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_CLOSED")
events:SetScript("OnEvent", function(_, event)
    if event == "LOOT_OPENED" then LootOpened()
    elseif event == "LOOT_CLOSED" then pendingCast = nil end
end)

local spells = CreateFrame("Frame")
for _, event in ipairs({
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED",
}) do
    if spells.RegisterUnitEvent then pcall(spells.RegisterUnitEvent, spells, event, "player")
    else pcall(spells.RegisterEvent, spells, event) end
end
spells:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "UNIT_SPELLCAST_SENT" then
        CastSent(arg1, arg2, arg3, arg4)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        if PendingMatches(arg2) then pendingCast.succeeded = true end
    elseif arg1 == "player" and PendingMatches(arg2) then
        pendingCast = nil
    end
end)
