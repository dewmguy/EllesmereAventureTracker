-------------------------------------------------------------------------------
-- Adventure Tracker fishing thresholds.
-- Adapted from OneCast ZoneLevels.lua and ZoneNames.lua at revision
-- 2f4a6b02e25ef5f4ab025a14b09f48c352948c3a (MIT; see THIRD_PARTY_NOTICES.md).
-- Values are the effective Fishing skill at which OneCast reports that fish
-- stop getting away. Pole, lure, racial and equipment bonuses all count. The
-- accompanying catch floors use the same Classic base-level relationship as
-- EllesmereUI Forever Essentials' world-map Fishing display: no-getaway skill
-- is normally the server's base fishing level plus 95.
-------------------------------------------------------------------------------
local _, ns = ...

local GROUPS = {
    { skill = 25, zones = {
        { "Dun Morogh", 1 }, { "Durotar", 14 }, { "Elwynn Forest", 12 },
        { "Mulgore", 215 }, { "Teldrassil", 141 }, { "Tirisfal Glades", 85 },
        { "Zephras Isle", 16593 },
    } },
    { skill = 75, zones = {
        { "Darkshore", 148 }, { "Loch Modan", 38 }, { "Silverpine Forest", 130 },
        { "Westfall", 40 }, { "Stormwind City", 1519 }, { "Orgrimmar", 1637 },
        { "Ironforge", 1537 }, { "Thunder Bluff", 1638 }, { "Undercity", 1497 },
        { "Darnassus", 1657 }, { "The Deadmines", 1581 },
        { "Wailing Caverns", 718 }, { "Blackfathom Deeps", 719 },
    } },
    { skill = 100, zones = { { "The Barrens", 17 } } },
    { skill = 150, zones = {
        { "Ashenvale", 331 }, { "Duskwood", 10 }, { "Hillsbrad Foothills", 267 },
        { "Redridge Mountains", 44 }, { "Stonetalon Mountains", 406 },
        { "Wetlands", 11 },
    } },
    { skill = 225, zones = {
        { "Alterac Mountains", 36 }, { "Arathi Highlands", 45 },
        { "Desolace", 405 }, { "Dustwallow Marsh", 15 },
        { "Stranglethorn Vale", 33 }, { "Swamp of Sorrows", 8 },
        { "Thousand Needles", 400 }, { "Scarlet Monastery", 796 },
        { "Riverglades", 16591 }, { "City of Dalaran", 16544 },
    } },
    { skill = 300, zones = {
        { "Azshara", 16 }, { "Felwood", 361 }, { "Feralas", 357 },
        { "Moonglade", 493 }, { "Tanaris", 440 }, { "The Hinterlands", 47 },
        { "Un'Goro Crater", 490 }, { "Western Plaguelands", 28 },
        { "Sunken Temple", 1417 }, { "Maraudon", 2100 },
    } },
    { skill = 425, zones = {
        { "Burning Steppes", 46 }, { "Deadwind Pass", 41 },
        { "Eastern Plaguelands", 139 }, { "Silithus", 1377 },
        { "Winterspring", 618 }, { "Zul'Gurub", 1977 },
        { "Stratholme", 2017 }, { "Scholomance", 2057 },
    } },
}

local FOREVER_MEASURED = {
    ["Zephras Isle"] = true, ["Mulgore"] = true, ["Dun Morogh"] = true,
    ["Elwynn Forest"] = true, ["Stormwind City"] = true,
    ["Orgrimmar"] = true, ["Darkshore"] = true, ["The Barrens"] = true,
    ["Stonetalon Mountains"] = true, ["Redridge Mountains"] = true,
    ["Desolace"] = true, ["Dustwallow Marsh"] = true,
    ["Riverglades"] = true, ["City of Dalaran"] = true,
    ["Feralas"] = true, ["Tanaris"] = true,
}

local INSTANCE_SKILL = {
    [36] = 75, [43] = 75, [48] = 75, [189] = 225,
    [109] = 300, [349] = 300, [309] = 425, [329] = 425, [289] = 425,
}

local SPOTS = {
    { "Jaguero Isle", 297, 300 }, { "Jademir Lake", 1112, 425 },
    { "Bay of Storms", 1227, 425 }, { "Hetaera's Clutch", 1222, 425 },
    { "Scalebeard's Cave", 3140, 425 },
}

local byName, measuredByName, minimumByName, minimumSourceByName, spotByName = {}, {}, {}, {}, {}
local MINIMUM_UNKNOWN = {
    ["Riverglades"] = true,
    ["City of Dalaran"] = true,
}
local MINIMUM_OVERRIDES = {
    ["The Barrens"] = 1, -- Ellesmere's Classic world-map baseline; Forever's no-getaway target is 100.
    ["Zephras Isle"] = 1, -- Forever observations include catches below skill 25.
}

local function LocalName(english, areaID)
    if C_Map and C_Map.GetAreaInfo and areaID then
        local ok, value = pcall(C_Map.GetAreaInfo, areaID)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return english
end

local DALARAN_ALIAS = LocalName("Dalaran", 16558)
local DALARAN_ZONE = LocalName("City of Dalaran", 16544)

for _, group in ipairs(GROUPS) do
    for _, zone in ipairs(group.zones) do
        local english, areaID = zone[1], zone[2]
        local localized = LocalName(english, areaID)
        byName[english] = group.skill
        byName[localized] = group.skill
        if FOREVER_MEASURED[english] then
            measuredByName[english] = true
            measuredByName[localized] = true
        end
        if not MINIMUM_UNKNOWN[english] then
            local minimum = MINIMUM_OVERRIDES[english] or math.max(1, group.skill - 95)
            local minimumSource = english == "Zephras Isle" and "forever" or "classic"
            minimumByName[english], minimumByName[localized] = minimum, minimum
            minimumSourceByName[english], minimumSourceByName[localized] = minimumSource, minimumSource
        end
    end
end
for _, spot in ipairs(SPOTS) do
    spotByName[spot[1]] = spot[3]
    spotByName[LocalName(spot[1], spot[2])] = spot[3]
end

function ns.GetFishingSkillRecommendation(zoneName)
    local subZone = GetSubZoneText and GetSubZoneText()
    local spotSkill = subZone and spotByName[subZone]
    if spotSkill then return spotSkill, "spot", math.max(1, spotSkill - 95), "classic" end

    if IsInInstance and IsInInstance() and GetInstanceInfo then
        local ok, _, _, _, _, _, _, _, instanceMapID = pcall(GetInstanceInfo)
        local instanceSkill = ok and INSTANCE_SKILL[tonumber(instanceMapID)]
        if instanceSkill then return instanceSkill, "classic", math.max(1, instanceSkill - 95), "classic" end
    end

    if zoneName == "Dalaran" or zoneName == DALARAN_ALIAS then zoneName = DALARAN_ZONE end
    local skill = zoneName and byName[zoneName]
    if not skill then return nil end
    return skill, measuredByName[zoneName] and "forever" or "classic",
        minimumByName[zoneName], minimumSourceByName[zoneName]
end

ns.FishingLevelSource = {
    name = "OneCast",
    revision = "2f4a6b02e25ef5f4ab025a14b09f48c352948c3a",
    url = "https://github.com/rynmon/OneCast",
}
