-------------------------------------------------------------------------------
-- Adventure Tracker: world-buff status and acquisition-source provider.
-------------------------------------------------------------------------------
local _, ns = ...

local WORLD_BUFFS = {
    {
        key = "faction-rend",
        alliance = true,
        alwaysShowMissing = true,
        label = "Might of Stormwind",
        spells = { 1304678, 460940, 460939 },
        source = "Wait in Stormwind City, Goldshire, Lakeshire or Sentinel Hill when an Alliance player turns in Rend Blackhand's head to Mathias Shaw.",
        zones = { ["Stormwind City"] = true, ["Elwynn Forest"] = true, ["Redridge Mountains"] = true, ["Westfall"] = true },
    },
    {
        key = "faction-rend",
        horde = true,
        alwaysShowMissing = true,
        label = "Warchief's Blessing",
        spells = { 16609 },
        source = "Wait in Orgrimmar, Razor Hill or the Crossroads when a Horde player turns in Rend Blackhand's head to Thrall.",
        zones = { ["Orgrimmar"] = true, ["Durotar"] = true, ["Northern Barrens"] = true, ["The Barrens"] = true },
    },
    {
        key = "dragonslayer",
        label = "Rallying Cry of the Dragonslayer",
        spells = { 22888 },
        source = "Your faction capital after an eligible dragon-head turn-in.",
        zones = { ["Stormwind City"] = true, ["Orgrimmar"] = true },
    },
    {
        key = "zandalar",
        label = "Spirit of Zandalar",
        spells = { 24425 },
        source = "Booty Bay or Yojamba Isle after a Heart of Hakkar turn-in.",
        zones = { ["The Cape of Stranglethorn"] = true, ["Stranglethorn Vale"] = true },
    },
    {
        key = "songflower",
        label = "Songflower Serenade",
        spells = { 15366 },
        source = "A cleansed songflower in Felwood.",
        zones = { ["Felwood"] = true },
    },
    {
        key = "moldar",
        label = "Mol'dar's Moxie",
        spells = { 22818 },
        source = "Guard Mol'dar after completing a Dire Maul North tribute run.",
        zones = { ["Dire Maul"] = true, ["Feralas"] = true },
    },
    {
        key = "fengus",
        label = "Fengus' Ferocity",
        spells = { 22817 },
        source = "Guard Fengus after completing a Dire Maul North tribute run.",
        zones = { ["Dire Maul"] = true, ["Feralas"] = true },
    },
    {
        key = "slipkik",
        label = "Slip'kik's Savvy",
        spells = { 22820 },
        source = "Guard Slip'kik after completing a Dire Maul North tribute run.",
        zones = { ["Dire Maul"] = true, ["Feralas"] = true },
    },
}

local function IsSecret(value)
    return _G.issecretvalue and _G.issecretvalue(value)
end

local function Texture(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

local function FindAura(spells)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil, false end
    for i = 1, #spells do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spells[i])
        if not ok or IsSecret(aura) then return nil, false end
        if aura then return aura, true end
    end
    return nil, true
end

local function AppliesToFaction(buff)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if buff.alliance then return faction == "Alliance" end
    if buff.horde then return faction == "Horde" end
    return true
end

local function Remaining(aura)
    local expiration = aura and aura.expirationTime
    if IsSecret(expiration) or type(expiration) ~= "number" or expiration <= 0 then return nil end
    return math.max(0, expiration - GetTime())
end

local function Build()
    if not ns.Get("showWorldBuffs") then return {} end
    local rows = {}
    local zone = ns.GetZoneName()
    local warnSeconds = math.max(0, tonumber(ns.Get("worldBuffWarnMinutes")) or 10) * 60
    for i = 1, #WORLD_BUFFS do
        local buff = WORLD_BUFFS[i]
        if AppliesToFaction(buff) then
            local aura, readable = FindAura(buff.spells)
            if aura and ns.Get("showActiveWorldBuffs") then
                local left = Remaining(aura)
                rows[#rows + 1] = {
                    key = "world-active-" .. buff.key,
                    label = buff.label,
                    detail = left and (ns.FormatDuration(left) .. " remaining") or "Active",
                    state = left and left <= warnSeconds and "warning" or "ready",
                    icon = Texture(buff.spells[1]),
                }
            elseif not readable then
                rows[#rows + 1] = {
                    key = "world-unknown-" .. buff.key,
                    label = buff.label,
                    detail = "World-buff state cannot be read right now.",
                    state = "unknown",
                    icon = Texture(buff.spells[1]),
                }
            elseif not aura and (buff.alwaysShowMissing or ns.Get("showMissingWorldBuffs"))
                and (buff.alwaysShowMissing or not ns.Get("worldBuffCurrentZoneOnly") or (buff.zones and buff.zones[zone])) then
                rows[#rows + 1] = {
                    key = "world-missing-" .. buff.key,
                    label = buff.label,
                    detail = buff.source,
                    state = "missing",
                    icon = Texture(buff.spells[1]),
                }
            end
        end
    end
    return { id = "world-buffs", title = "World Buffs", rows = rows }
end

ns.RegisterProvider("world-buffs", 15, Build)
