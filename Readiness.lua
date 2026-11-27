-------------------------------------------------------------------------------
-- Adventure Tracker: readiness provider.
-------------------------------------------------------------------------------
local _, ns = ...

local CAMP_BENEFITS = 1229741
local SLEEPING_BAG_BUFF = 429959
local SLEEPING_BAG_ITEM = 211527
local WELL_FED = 19705
local FOOD_BUFFS = { 19705, 18192, 18194, 22730, 25661, 18125, 18141 }

local CLASS_REQUIREMENTS = {
    WARRIOR = {
        { key = "battle-shout", label = "Battle Shout", spells = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 } },
    },
    DRUID = {
        { key = "mark", label = "Mark of the Wild", spells = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 } },
        { key = "thorns", label = "Thorns", spells = { 467, 782, 1075, 8914, 9756, 9910 } },
    },
    HUNTER = {
        { key = "aspect", label = "Hunter Aspect", spells = { 13159, 5118, 13163, 13161, 1299445, 1299446, 1299447, 20043, 20190, 13165, 14318, 14319, 14320, 14321, 14322, 25296 } },
    },
    MAGE = {
        { key = "intellect", label = "Intellect", cover = "intellect", spells = { 1459, 1460, 1461, 10156, 10157 } },
        { key = "mage-armor", label = "Mage Armor", spells = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783 } },
    },
    PALADIN = {
        { key = "blessing", label = "Blessing", spells = { 19742, 19850, 19852, 19853, 19854, 25290, 20217, 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25894, 25918, 25898, 25782, 25916 } },
        { key = "aura", label = "Paladin Aura", spells = { 19891, 19899, 19900, 19888, 19897, 19898, 19876, 19895, 19896, 19746, 7294, 10298, 10299, 10300, 10301, 465, 10290, 643, 10291, 1032, 10292, 10293 } },
        { key = "righteous-fury", label = "Righteous Fury", roles = { TANK = true }, spells = { 25780 } },
    },
    PRIEST = {
        { key = "fortitude", label = "Fortitude", cover = "fortitude", spells = { 1243, 1244, 1245, 2791, 10937, 10938, 25389 } },
        { key = "inner-fire", label = "Inner Fire", spells = { 588, 7128, 602, 1006, 10951, 10952 } },
        { key = "shadowform", label = "Shadowform", roles = { CASTER = true }, spells = { 15473 } },
    },
    ROGUE = {
        { key = "weapon", label = "Weapon Poison", kind = "weapon" },
    },
    SHAMAN = {
        { key = "shield", label = "Lightning Shield", spells = { 324, 325, 905, 945, 8134, 10431, 10432, 408510 } },
        { key = "weapon", label = "Weapon Imbue", kind = "weapon" },
    },
    WARLOCK = {
        { key = "armor", label = "Demon Armor", spells = { 687, 696, 706, 1086, 11733, 11734, 11735 } },
    },
}

local function IsSecret(value)
    return _G.issecretvalue and _G.issecretvalue(value)
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and not IsSecret(name) then return name end
    end
    return GetSpellInfo and GetSpellInfo(id)
end

local function SpellTexture(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

local function GetAura(id)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil, false end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if not ok or IsSecret(aura) then return nil, false end
    return aura, true
end

local function AuraRemaining(aura)
    if not aura then return nil end
    local expiration = aura.expirationTime
    if IsSecret(expiration) or type(expiration) ~= "number" or expiration <= 0 then return nil end
    return math.max(0, expiration - GetTime())
end

local function IsKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and not IsSecret(known) and known then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and known then return true end
    end
    return false
end

local function FirstKnown(spells)
    for i = #spells, 1, -1 do
        if IsKnown(spells[i]) then return spells[i] end
    end
end

local function FindAura(spells)
    local readable = true
    for i = 1, #spells do
        local aura, ok = GetAura(spells[i])
        if not ok then readable = false end
        if aura then return aura, spells[i], readable end
    end
    return nil, nil, readable
end

local function GetItemCount(itemID)
    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, itemID)
        if ok and type(count) == "number" then return count end
    end
    if _G.GetItemCount then
        local ok, count = pcall(_G.GetItemCount, itemID)
        if ok and type(count) == "number" then return count end
    end
    return 0
end

local function ItemTexture(itemID)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID) end
    return GetItemIcon and GetItemIcon(itemID)
end

local function IsAtMaxLevel()
    local level = UnitLevel("player") or 0
    if IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel() then return true end
    local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    return level >= maxLevel
end

local function FoodAura()
    local aura = nil
    for i = 1, #FOOD_BUFFS do
        aura = GetAura(FOOD_BUFFS[i])
        if aura then return aura, FOOD_BUFFS[i], true end
    end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil, nil, false end
    local wellFedName = SpellName(WELL_FED)
    for index = 1, 255 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        if not ok or IsSecret(data) then return nil, nil, false end
        if not data then break end
        local name = data.name
        if not IsSecret(name) and wellFedName and name == wellFedName then
            return data, data.spellId or data.spellID, true
        end
    end
    return nil, nil, true
end

local function CampCoverage(campAura)
    local coverage = {}
    if not campAura or not C_TooltipInfo or not C_TooltipInfo.GetUnitAuraByAuraInstanceID then return coverage end
    local instanceID = campAura.auraInstanceID
    if IsSecret(instanceID) or not instanceID then return coverage end
    local ok, tooltip = pcall(C_TooltipInfo.GetUnitAuraByAuraInstanceID, "player", instanceID)
    if not ok or IsSecret(tooltip) or type(tooltip) ~= "table" then return coverage end
    local candleName = SpellName(1229705)
    local kitName = SpellName(1307244)
    for _, line in ipairs(tooltip.lines or {}) do
        local text = ""
        if type(line) == "table" then
            if type(line.leftText) == "string" then text = text .. line.leftText end
            if type(line.rightText) == "string" then text = text .. " " .. line.rightText end
        end
        if candleName and text:find(candleName, 1, true) then
            coverage.intellect = candleName
        end
        if kitName and text:find(kitName, 1, true) then
            coverage.fortitude = kitName
        end
    end
    return coverage
end

local function TimedState(aura, warnSeconds)
    local remaining = AuraRemaining(aura)
    if remaining and remaining <= warnSeconds then return "warning", remaining end
    return "ready", remaining
end

local function DurationDetail(prefix, remaining)
    local duration = ns.FormatDuration(remaining)
    return duration and (prefix .. " • " .. duration .. " remaining") or prefix
end

local function BuildCamp(statuses, rows, warnSeconds)
    if not ns.Get("trackCamp") then return nil end
    local aura, readable = GetAura(CAMP_BENEFITS)
    local status = { key = "camp", label = "Camp Benefits", icon = SpellTexture(CAMP_BENEFITS) }
    if not readable then
        status.state, status.detail = "unknown", "Camp Benefits cannot be read right now."
    elseif aura then
        local remaining
        status.state, remaining = TimedState(aura, warnSeconds)
        status.detail = DurationDetail("Camp Benefits active", remaining)
    else
        status.state = "missing"
        status.detail = "Rest beside a campfire for one minute."
    end
    statuses[#statuses + 1] = status
    if status.state ~= "ready" or ns.Get("showCompletedReadiness") then rows[#rows + 1] = status end
    return aura
end

local function BuildSleeping(statuses, rows, warnSeconds)
    if not ns.Get("trackSleepingBag") or IsAtMaxLevel() then return end
    local aura, readable = GetAura(SLEEPING_BAG_BUFF)
    local count = GetItemCount(SLEEPING_BAG_ITEM)
    local status = { key = "sleeping", label = "Well-Rested", icon = SpellTexture(SLEEPING_BAG_BUFF) or ItemTexture(SLEEPING_BAG_ITEM) }
    if not readable then
        status.state, status.detail = "unknown", "Well-Rested stacks cannot be read right now."
    elseif count <= 0 and not aura then
        status.state, status.detail = "unavailable", "Cozy Sleeping Bag not found in your bags."
    else
        local stacks = aura and aura.applications or 0
        if IsSecret(stacks) or type(stacks) ~= "number" then stacks = 0 end
        status.badge = string.format("%d/3", math.min(3, stacks))
        if stacks >= 3 then
            local remaining
            status.state, remaining = TimedState(aura, warnSeconds)
            status.detail = DurationDetail("Well-Rested 3/3", remaining)
        elseif stacks > 0 then
            status.state = "warning"
            status.detail = string.format("Well-Rested %d/3 • rest for %d more minute%s.", stacks, 3 - stacks, (3 - stacks) == 1 and "" or "s")
        else
            status.state = "missing"
            status.detail = "Use the Cozy Sleeping Bag and rest for three minutes."
        end
    end
    statuses[#statuses + 1] = status
    if status.state ~= "ready" or ns.Get("showCompletedReadiness") then rows[#rows + 1] = status end
end

local function BuildFood(statuses, rows, warnSeconds)
    if not ns.Get("trackFood") then return end
    local aura, _, readable = FoodAura()
    local status = { key = "food", label = "Well Fed", icon = SpellTexture(WELL_FED) }
    if not readable then
        status.state, status.detail = "unknown", "Food buffs cannot be read right now."
    elseif aura then
        local remaining
        status.state, remaining = TimedState(aura, warnSeconds)
        status.detail = DurationDetail("A food buff is active", remaining)
    else
        status.state, status.detail = "missing", "Eat suitable buff food before heading out."
    end
    statuses[#statuses + 1] = status
    if status.state ~= "ready" or ns.Get("showCompletedReadiness") then rows[#rows + 1] = status end
end

local function WeaponState()
    if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.WeaponSlot then
        local longest, readable = nil, true
        for _, slot in ipairs({ Enum.WeaponSlot.MainHand, Enum.WeaponSlot.OffHand }) do
            if slot then
                local ok, list = pcall(C_Item.GetWeaponEnchantInfo, slot)
                if not ok or IsSecret(list) then return nil, nil end
                for i = 1, type(list) == "table" and #list or 0 do
                    local enchant = list[i]
                    local active, left = enchant.hasEnchant, enchant.timeLeft
                    if IsSecret(active) or IsSecret(left) then readable = false
                    elseif active then
                        local seconds = type(left) == "number" and left / 1000 or nil
                        longest = math.max(longest or 0, seconds or 0)
                    end
                end
            end
        end
        if not readable then return nil, nil end
        return longest ~= nil, longest
    end
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
        local main = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)
        local off = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_OFFHAND)
        local enchant = main or off
        return enchant ~= nil, enchant and enchant.remainingTimeMs and enchant.remainingTimeMs / 1000 or nil
    end
    if GetWeaponEnchantInfo then
        local ok, main, mainMS, mainCharges, mainID, off, offMS = pcall(GetWeaponEnchantInfo)
        if not ok then return nil, nil end
        if main then return true, type(mainMS) == "number" and mainMS / 1000 or nil end
        if off then return true, type(offMS) == "number" and offMS / 1000 or nil end
        return false, nil
    end
    return nil, nil
end

local function BuildClass(statuses, rows, warnSeconds, coverage)
    if not ns.Get("trackClassBuffs") then return end
    local _, class = UnitClass("player")
    local requirements = class and CLASS_REQUIREMENTS[class]
    if not requirements then return end
    local role = ns.GetRole()
    for i = 1, #requirements do
        local req = requirements[i]
        local roleApplies = not req.roles or req.roles[role]
        local weaponApplies = req.kind ~= "weapon" or ns.Get("trackWeaponEnhancements")
        local knownSpell = req.spells and FirstKnown(req.spells)
        local known = req.kind == "weapon" or knownSpell ~= nil
        if roleApplies and weaponApplies and known then
            local status = {
                key = "class-" .. req.key,
                label = req.label,
                icon = req.kind == "weapon" and 134850 or SpellTexture(knownSpell or req.spells[1]),
            }
            if req.cover and coverage[req.cover] then
                status.state = "ready"
                status.detail = "Covered by Camp Benefits (" .. coverage[req.cover] .. ")."
            elseif req.kind == "weapon" then
                local active, remaining = WeaponState()
                if active == nil then
                    status.state, status.detail = "unknown", "Weapon enhancement state cannot be read."
                elseif active then
                    status.state = remaining and remaining <= warnSeconds and "warning" or "ready"
                    status.detail = DurationDetail(req.label .. " active", remaining)
                else
                    status.state, status.detail = "missing", "Apply a suitable " .. req.label:lower() .. "."
                end
            else
                local aura, _, readable = FindAura(req.spells)
                if not readable then
                    status.state, status.detail = "unknown", req.label .. " cannot be read right now."
                elseif aura then
                    local remaining
                    status.state, remaining = TimedState(aura, warnSeconds)
                    status.detail = DurationDetail(req.label .. " active", remaining)
                else
                    status.state, status.detail = "missing", "Apply " .. req.label .. " before leaving."
                end
            end
            statuses[#statuses + 1] = status
            if status.state ~= "ready" or ns.Get("showCompletedReadiness") then rows[#rows + 1] = status end
        end
    end
end

local function Build()
    if not ns.Get("showReadiness") then return {} end
    local statuses, rows = {}, {}
    local warnSeconds = math.max(0, tonumber(ns.Get("readinessWarnMinutes")) or 10) * 60
    local campAura = BuildCamp(statuses, rows, warnSeconds)
    local coverage = CampCoverage(campAura)
    BuildSleeping(statuses, rows, warnSeconds)
    BuildFood(statuses, rows, warnSeconds)
    BuildClass(statuses, rows, warnSeconds, coverage)
    return {
        id = "readiness",
        title = "Before You Leave",
        statuses = statuses,
        rows = rows,
    }
end

ns.RegisterProvider("readiness", 10, Build)
