-------------------------------------------------------------------------------
-- Adventure Tracker: readiness provider.
-------------------------------------------------------------------------------
local _, ns = ...

local CAMP_BENEFITS = 1229741
local SLEEPING_BAG_BUFF = 429959
local SLEEPING_BAG_ITEM = 211527
local WELL_FED = 19705
local NUTRITIOUS_FOOD = 1248377
local FOOD_BUFFS = { 19705, 18192, 18194, 22730, 25661, 18125, 18141 }

local PALADIN_WISDOM = { 19742, 19850, 19852, 19853, 19854, 25290 }
local PALADIN_KINGS = { 20217 }
local PALADIN_MIGHT = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }
local PALADIN_SANCTUARY = { 20911, 20912, 20913, 20914 }
local PALADIN_CONCENTRATION = { 19746 }
local PALADIN_RETRIBUTION = { 7294, 10298, 10299, 10300, 10301 }
local PALADIN_DEVOTION = { 465, 10290, 643, 10291, 1032, 10292, 10293 }

local CLASS_REQUIREMENTS = {
    WARRIOR = {
        { key = "battle-shout", label = "Battle Shout", scope = "party", expectedMinutes = 2, spells = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 } },
    },
    DRUID = {
        { key = "mark", label = "Mark of the Wild", scope = "party", expectedMinutes = 30, spells = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 } },
        { key = "thorns", label = "Thorns", expectedMinutes = 10, spells = { 467, 782, 1075, 8914, 9756, 9910 } },
    },
    HUNTER = {
        { key = "aspect", label = "Hunter Aspect", expectedMinutes = 1440, spells = { 13159, 5118, 13163, 13161, 1299445, 1299446, 1299447, 20043, 20190, 13165, 14318, 14319, 14320, 14321, 14322, 25296 } },
    },
    MAGE = {
        { key = "intellect", label = "Intellect", scope = "party", expectedMinutes = 30, cover = "intellect", spells = { 1459, 1460, 1461, 10156, 10157 } },
        { key = "mage-armor", label = "Mage Armor", expectedMinutes = 30, spells = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783 } },
    },
    PALADIN = {
        { key = "blessing", label = "Blessing", scope = "party", expectedMinutes = 5,
            spells = { 19742, 19850, 19852, 19853, 19854, 25290, 20217, 19740, 19834, 19835, 19836, 19837, 19838, 25291, 20911, 20912, 20913, 20914, 25894, 25918, 25898, 25782, 25916, 25899 },
            preferredByRole = {
                TANK = { PALADIN_SANCTUARY, PALADIN_KINGS, PALADIN_MIGHT },
                HEALER = { PALADIN_WISDOM, PALADIN_KINGS },
                CASTER = { PALADIN_WISDOM, PALADIN_KINGS },
                PHYSICAL = { PALADIN_MIGHT, PALADIN_KINGS },
                SOLO = { PALADIN_MIGHT, PALADIN_KINGS, PALADIN_WISDOM },
            },
            preferredBySpec = {
                HOLY = { PALADIN_WISDOM, PALADIN_KINGS },
                PROTECTION = { PALADIN_SANCTUARY, PALADIN_KINGS, PALADIN_MIGHT },
                RETRIBUTION = { PALADIN_MIGHT, PALADIN_KINGS },
            },
        },
        { key = "aura", label = "Paladin Aura", scope = "party", expectedMinutes = 1440,
            spells = { 19891, 19899, 19900, 19888, 19897, 19898, 19876, 19895, 19896, 19746, 7294, 10298, 10299, 10300, 10301, 465, 10290, 643, 10291, 1032, 10292, 10293 },
            preferredByRole = {
                TANK = { PALADIN_DEVOTION },
                HEALER = { PALADIN_CONCENTRATION, PALADIN_DEVOTION },
                CASTER = { PALADIN_CONCENTRATION, PALADIN_DEVOTION },
                PHYSICAL = { PALADIN_RETRIBUTION, PALADIN_DEVOTION },
                SOLO = { PALADIN_DEVOTION, PALADIN_RETRIBUTION },
            },
            preferredBySpec = {
                HOLY = { PALADIN_CONCENTRATION, PALADIN_DEVOTION },
                PROTECTION = { PALADIN_DEVOTION },
                RETRIBUTION = { PALADIN_RETRIBUTION, PALADIN_DEVOTION },
            },
        },
        { key = "righteous-fury", label = "Righteous Fury", roles = { TANK = true }, expectedMinutes = 30, spells = { 25780 } },
    },
    PRIEST = {
        { key = "fortitude", label = "Fortitude", scope = "party", expectedMinutes = 30, cover = "fortitude", spells = { 1243, 1244, 1245, 2791, 10937, 10938, 25389 } },
        { key = "inner-fire", label = "Inner Fire", expectedMinutes = 10, spells = { 588, 7128, 602, 1006, 10951, 10952 } },
        { key = "shadowform", label = "Shadowform", roles = { CASTER = true }, expectedMinutes = 1440, spells = { 15473 } },
    },
    ROGUE = {
        { key = "weapon", label = "Weapon Poison", kind = "weapon", expectedMinutes = 30 },
    },
    SHAMAN = {
        { key = "shield", label = "Lightning Shield", expectedMinutes = 10, spells = { 324, 325, 905, 945, 8134, 10431, 10432, 408510 } },
        { key = "weapon", label = "Weapon Imbue", kind = "weapon", expectedMinutes = 30 },
    },
    WARLOCK = {
        { key = "armor", label = "Demon Armor", expectedMinutes = 30, spells = { 687, 696, 706, 1086, 11733, 11734, 11735 } },
    },
}

local TRACKED_AURA_SPELLS = {
    [CAMP_BENEFITS] = true,
    [SLEEPING_BAG_BUFF] = true,
}
for i = 1, #FOOD_BUFFS do TRACKED_AURA_SPELLS[FOOD_BUFFS[i]] = true end
for _, requirements in pairs(CLASS_REQUIREMENTS) do
    for i = 1, #requirements do
        for j = 1, #(requirements[i].spells or {}) do
            TRACKED_AURA_SPELLS[requirements[i].spells[j]] = true
        end
    end
end

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

function ns.IsReadinessAuraSpell(spellID, spellName)
    if type(spellID) == "number" and TRACKED_AURA_SPELLS[spellID] == true then return true end
    local wellFedName = SpellName(WELL_FED)
    return type(spellName) == "string" and not IsSecret(spellName)
        and type(wellFedName) == "string" and spellName == wellFedName
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

local function CurrentSpecKey()
    local name = ns.GetCurrentSpecializationName and ns.GetCurrentSpecializationName()
    if IsSecret(name) or type(name) ~= "string" then return nil end
    return name:upper()
end

local function FirstPreferred(groups)
    if type(groups) ~= "table" then return nil end
    for index = 1, #groups do
        local known = FirstKnown(groups[index])
        if known then return known end
    end
end

local function RecentSpell(requirement, role)
    local root = ns.DB().lastClassBuffSpellsByCharacter
    local character = type(root) == "table" and root[ns.CharacterKey()]
    local recentByRole = type(character) == "table" and character[requirement.key]
    local spellID = type(recentByRole) == "table" and recentByRole[role]
    return type(spellID) == "number" and IsKnown(spellID) and spellID or nil
end

local function RememberSpell(requirement, role, spellID)
    if type(spellID) ~= "number" or not IsKnown(spellID) then return end
    local db = ns.DB()
    if type(db.lastClassBuffSpellsByCharacter) ~= "table" then db.lastClassBuffSpellsByCharacter = {} end
    local characterKey = ns.CharacterKey()
    if type(db.lastClassBuffSpellsByCharacter[characterKey]) ~= "table" then
        db.lastClassBuffSpellsByCharacter[characterKey] = {}
    end
    local character = db.lastClassBuffSpellsByCharacter[characterKey]
    if type(character[requirement.key]) ~= "table" then character[requirement.key] = {} end
    character[requirement.key][role] = spellID
end

local function SelectRequirementSpell(requirement, role, activeSpellID)
    if activeSpellID and IsKnown(activeSpellID) then
        RememberSpell(requirement, role, activeSpellID)
        return activeSpellID
    end
    local recent = RecentSpell(requirement, role)
    if recent then return recent end
    local groups
    if role == "SOLO" and requirement.preferredBySpec then
        groups = requirement.preferredBySpec[CurrentSpecKey()]
    end
    groups = groups or (requirement.preferredByRole and requirement.preferredByRole[role])
    return FirstPreferred(groups) or FirstKnown(requirement.spells or {})
end

local function FindAura(spells, unit)
    unit = unit or "player"
    if unit == "player" then
        local readable = true
        for i = 1, #spells do
            local aura, ok = GetAura(spells[i])
            if not ok then readable = false end
            if aura then return aura, spells[i], readable end
        end
        return nil, nil, readable
    end

    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil, nil, false end
    local spellIDs, spellNames = {}, {}
    for i = 1, #spells do
        spellIDs[spells[i]] = true
        local name = SpellName(spells[i])
        if type(name) == "string" and not IsSecret(name) then spellNames[name] = true end
    end
    for index = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok or IsSecret(aura) then return nil, nil, false end
        if not aura then break end
        local spellID = aura.spellId or aura.spellID
        local name = aura.name
        if IsSecret(spellID) or IsSecret(name) then return nil, nil, false end
        if spellIDs[spellID] or spellNames[name] then
            return aura, spellID, true
        end
    end
    return nil, nil, true
end

local function UnitLabel(unit)
    if unit == "player" or (UnitIsUnit and UnitIsUnit(unit, "player")) then return "you" end
    local name = UnitName and UnitName(unit)
    if IsSecret(name) or type(name) ~= "string" or name == "" then return unit end
    return name
end

local function AddBuffUnit(units, unit)
    if UnitExists and not UnitExists(unit) then return end
    if UnitIsConnected and UnitIsConnected(unit) == false then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return end
    units[#units + 1] = { unit = unit, label = UnitLabel(unit) }
end

local function BuffUnits(requirement, role)
    local units = { { unit = "player", label = "you" } }
    if requirement.scope ~= "party" or role == "SOLO" or not ns.Get("trackPartyClassBuffs") then return units end
    if IsInRaid and IsInRaid() then return units end
    local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    for index = 1, count do AddBuffUnit(units, "party" .. index) end
    return units
end

local function UnitList(labels)
    if #labels <= 3 then return table.concat(labels, ", ") end
    return string.format("%s, %s, %s and %d more", labels[1], labels[2], labels[3], #labels - 3)
end

local function RoleAlertApplies(requirement, role)
    if role == "SOLO" or not ns.Get("roleCriticalAlerts") then return false end
    local minimum = math.max(0, tonumber(ns.Get("roleAlertMinDuration")) or 5)
    return (tonumber(requirement.expectedMinutes) or -1) >= minimum
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

local FOOD_WEIGHTS = {
    SOLO = { strength = 4, agility = 4, intellect = 4, stamina = 2, spirit = 1, attackPower = 3, spellPower = 3, healing = 2, crit = 2, mana5 = 1 },
    TANK = { strength = 2, agility = 2, intellect = 1, stamina = 6, spirit = 1, attackPower = 1, spellPower = 1, healing = 1, crit = 1, mana5 = 1 },
    HEALER = { strength = 0, agility = 0, intellect = 6, stamina = 1, spirit = 4, attackPower = 0, spellPower = 5, healing = 6, crit = 2, mana5 = 4 },
    PHYSICAL = { strength = 6, agility = 6, intellect = 0, stamina = 1, spirit = 0, attackPower = 4, spellPower = 0, healing = 0, crit = 3, mana5 = 0 },
    CASTER = { strength = 0, agility = 0, intellect = 6, stamina = 1, spirit = 2, attackPower = 0, spellPower = 5, healing = 2, crit = 3, mana5 = 2 },
}

local FOOD_STAT_DEFS = {
    { key = "strength", label = "Strength", phrases = { "strength" } },
    { key = "agility", label = "Agility", phrases = { "agility" } },
    { key = "intellect", label = "Intellect", phrases = { "intellect" } },
    { key = "stamina", label = "Stamina", phrases = { "stamina" } },
    { key = "spirit", label = "Spirit", phrases = { "spirit" } },
    { key = "attackPower", label = "Attack Power", phrases = { "attack power" } },
    { key = "spellPower", label = "Spell Power", phrases = { "spell power", "spell damage" } },
    { key = "healing", label = "Healing", phrases = { "healing" } },
    { key = "crit", label = "Critical Strike", phrases = { "critical strike", "critical hit" } },
    { key = "mana5", label = "Mana/5", phrases = { "mana every 5", "mana per 5" } },
}

local function CleanTooltipText(value)
    if type(value) ~= "string" or IsSecret(value) then return "" end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
end

local function TooltipText(tooltip)
    if IsSecret(tooltip) or type(tooltip) ~= "table" then return nil end
    local parts = {}
    for _, line in ipairs(tooltip.lines or {}) do
        if type(line) == "table" and not IsSecret(line) then
            local left = CleanTooltipText(line.leftText)
            local right = CleanTooltipText(line.rightText)
            if left ~= "" then parts[#parts + 1] = left end
            if right ~= "" then parts[#parts + 1] = right end
        end
    end
    return table.concat(parts, "\n")
end

local function ItemTooltipText(itemID)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local ok, tooltip = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok then return nil end
    return TooltipText(tooltip)
end

local function MaxStatValue(text, phrases)
    local best = 0
    for i = 1, #phrases do
        local phrase = phrases[i]
        local before = text:match("(%d+)%s+" .. phrase)
        local after = text:match(phrase .. "%s+by%s+(%d+)")
        best = math.max(best, tonumber(before) or 0, tonumber(after) or 0)
    end
    return best
end

local foodCache = {}
local foodCacheRevision = {}
local foodBagCounts = {}
local foodBagDirty = {}
local foodBagsInitialized = false
local foodInventoryRevision = 0
local foodSignatureCache = {}

local function StoreFoodEvaluation(role, itemID, value)
    if foodCache[role][itemID] ~= value then
        foodCache[role][itemID] = value
        foodCacheRevision[role] = (foodCacheRevision[role] or 0) + 1
    end
    return value or nil
end

local function IsFoodCandidate(itemID)
    if not GetItemInfoInstant then return true end
    local ok, _, _, _, _, _, classID, subClassID = pcall(GetItemInfoInstant, itemID)
    if not ok or classID == nil then return true end
    local consumable = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or 0
    local foodAndDrink = Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Fooddrink or 5
    return tonumber(classID) == tonumber(consumable) and tonumber(subClassID) == tonumber(foodAndDrink)
end

local function ScanFoodBag(bag)
    local counts = {}
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
        local itemID = C_Container.GetContainerItemID(bag, slot)
        if itemID and IsFoodCandidate(itemID) then
            local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
            counts[itemID] = (counts[itemID] or 0) + (info and info.stackCount or 1)
        end
    end
    foodBagCounts[bag] = counts
    foodBagDirty[bag] = nil
    foodInventoryRevision = foodInventoryRevision + 1
end

function ns.MarkReadinessInventoryBagDirty(bag)
    bag = tonumber(bag)
    if bag and bag >= 0 and bag <= (NUM_BAG_SLOTS or 4) then foodBagDirty[bag] = true end
end

function ns.GetReadinessInventorySignature()
    if not ns.Get("showReadiness") or not ns.Get("trackFood") then return "" end
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return "" end
    if not foodBagsInitialized then
        for bag = 0, NUM_BAG_SLOTS or 4 do ScanFoodBag(bag) end
        foodBagsInitialized = true
    else
        for bag in pairs(foodBagDirty) do ScanFoodBag(bag) end
    end

    local role = ns.GetRole()
    local classificationRevision = foodCacheRevision[role] or 0
    local cachedSignature = foodSignatureCache[role]
    if cachedSignature and cachedSignature.inventoryRevision == foodInventoryRevision
        and cachedSignature.classificationRevision == classificationRevision then
        return cachedSignature.value
    end

    local counts = {}
    local roleCache = foodCache[role] or {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for itemID, count in pairs(foodBagCounts[bag] or {}) do
            -- Food and drink share one Blizzard subclass. Once tooltip
            -- evaluation establishes that an item has no combat-food benefit,
            -- exclude it from the signature so drinking it cannot dirty the
            -- readiness provider on every sip.
            if roleCache[itemID] ~= false then counts[itemID] = (counts[itemID] or 0) + count end
        end
    end
    local values = {}
    for itemID, count in pairs(counts) do values[#values + 1] = string.format("%d:%d", itemID, count) end
    table.sort(values)
    local signature = table.concat(values, ";")
    foodSignatureCache[role] = {
        inventoryRevision = foodInventoryRevision,
        classificationRevision = classificationRevision,
        value = signature,
    }
    return signature
end

local function EvaluateCombatFood(itemID)
    local role = ns.GetRole()
    foodCache[role] = foodCache[role] or {}
    local cached = foodCache[role][itemID]
    if cached ~= nil then return cached or nil end

    local ok, name, _, _, itemLevel, requiredLevel, _, _, _, _, icon = pcall(C_Item.GetItemInfo, itemID)
    if not ok or not name or IsSecret(name) then
        if ns.RequestItemData then ns.RequestItemData(itemID, "readiness") end
        return nil
    end
    if C_Item and C_Item.IsItemDataCachedByID then
        local cacheOK, ready = pcall(C_Item.IsItemDataCachedByID, itemID)
        if cacheOK and ready ~= true then
            if ns.RequestItemData then ns.RequestItemData(itemID, "readiness") end
            return nil
        end
    end
    requiredLevel = tonumber(requiredLevel) or 0
    if requiredLevel > (UnitLevel("player") or 0) then return nil end

    local text = ItemTooltipText(itemID)
    if not text then return nil end
    local familyName = SpellName(NUTRITIOUS_FOOD)
    if not familyName and ns.RequestSpellData then
        ns.RequestSpellData(NUTRITIOUS_FOOD, "readiness")
    end
    local foodSpell
    if C_Item and C_Item.GetItemSpell then
        local spellOK, spellName = pcall(C_Item.GetItemSpell, itemID)
        if spellOK and not IsSecret(spellName) then foodSpell = spellName end
    end
    local lower = text:lower()
    if not ((familyName and foodSpell == familyName) or lower:find("well fed", 1, true)) then
        return StoreFoodEvaluation(role, itemID, false)
    end

    local weights = FOOD_WEIGHTS[role] or FOOD_WEIGHTS.SOLO
    local stats, score, effect = {}, 0, {}
    for i = 1, #FOOD_STAT_DEFS do
        local def = FOOD_STAT_DEFS[i]
        local value = MaxStatValue(lower, def.phrases)
        if value > 0 then
            stats[def.key] = value
            score = score + value * (weights[def.key] or 0)
            effect[#effect + 1] = string.format("+%d %s", value, def.label)
        end
    end
    local sharedStamina = tonumber(lower:match("(%d+)%s+stamina%s+and%s+spirit"))
    if sharedStamina and sharedStamina > 0 and not stats.spirit then
        stats.spirit = sharedStamina
        score = score + sharedStamina * (weights.spirit or 0)
        effect[#effect + 1] = string.format("+%d Spirit", sharedStamina)
    end
    if score <= 0 then
        return StoreFoodEvaluation(role, itemID, false)
    end
    local result = {
        itemID = itemID,
        name = name,
        icon = icon or ItemTexture(itemID),
        itemLevel = tonumber(itemLevel) or 0,
        requiredLevel = requiredLevel,
        score = score,
        effect = #effect > 0 and table.concat(effect, ", ") or "combat benefit",
    }
    return StoreFoodEvaluation(role, itemID, result)
end

local function BetterFood(candidate, best)
    if not candidate then return best end
    if not best or candidate.score > best.score
        or (candidate.score == best.score and candidate.requiredLevel > best.requiredLevel)
        or (candidate.score == best.score and candidate.requiredLevel == best.requiredLevel and candidate.itemLevel > best.itemLevel) then
        return candidate
    end
    return best
end

local function BestBagCombatFood()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return nil end
    local counts = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                counts[itemID] = (counts[itemID] or 0) + (info and info.stackCount or 1)
            end
        end
    end
    local best
    for itemID, count in pairs(counts) do
        local food = IsFoodCandidate(itemID) and EvaluateCombatFood(itemID) or nil
        if food then
            food.count = count
            best = BetterFood(food, best)
        end
    end
    return best
end

local function RecipeKnown(recipeID, info)
    if info then
        local learned = info.learned
        if not IsSecret(learned) and learned ~= nil then return learned == true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, recipeID)
        if ok and not IsSecret(known) and known then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, recipeID)
        if ok and not IsSecret(known) and known then return true end
    end
    return false
end

local function RecipeOutput(recipeID)
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeItemLink then
        local ok, link = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
        if ok and link and not IsSecret(link) and C_Item and C_Item.GetItemInfoInstant then
            local itemID = C_Item.GetItemInfoInstant(link)
            if itemID then return itemID end
        end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
        if ok and type(schematic) == "table" and not IsSecret(schematic.outputItemID) then
            return schematic.outputItemID
        end
    end
end

local function BestCraftedCombatFood()
    local recipes = {}
    for recipeID, itemID in pairs(ns.CookingFoodRecipes or {}) do recipes[recipeID] = itemID end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if ok and not IsSecret(ids) and type(ids) == "table" then
            for i = 1, #ids do
                local recipeID = ids[i]
                if not IsSecret(recipeID) then recipes[recipeID] = recipes[recipeID] or RecipeOutput(recipeID) end
            end
        end
    end

    local best
    for recipeID, itemID in pairs(recipes) do
        local info
        if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
            local ok, value = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if ok and type(value) == "table" then info = value end
        end
        if itemID and RecipeKnown(recipeID, info) then
            local food = EvaluateCombatFood(itemID)
            if food then
                food.recipeID = recipeID
                food.recipeName = (info and info.name) or SpellName(recipeID) or food.name
                best = BetterFood(food, best)
            end
        end
    end
    return best
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
    if remaining and remaining > warnSeconds and ns.ScheduleTimedProviderRefresh then
        ns.ScheduleTimedProviderRefresh(remaining - warnSeconds)
    end
    if remaining and remaining <= warnSeconds then return "warning", remaining end
    return "ready", remaining
end

local function DurationDetail(prefix, remaining)
    local duration = ns.FormatDuration(remaining)
    return duration and (prefix .. " • " .. duration .. " remaining") or prefix
end

local function AddReadinessRow(rows, status)
    if status.expiringSoon then return end
    if status.state ~= "ready" or ns.Get("showCompletedReadiness") then rows[#rows + 1] = status end
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
        status.expiringSoon = status.state == "warning"
        status.detail = DurationDetail("Camp Benefits active", remaining)
    else
        status.state = "missing"
        status.detail = "Rest beside a campfire for one minute."
    end
    statuses[#statuses + 1] = status
    AddReadinessRow(rows, status)
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
        status.badge = tostring(math.min(3, stacks))
        if stacks >= 3 then
            local remaining
            status.state, remaining = TimedState(aura, warnSeconds)
            status.expiringSoon = status.state == "warning"
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
    AddReadinessRow(rows, status)
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
        status.expiringSoon = status.state == "warning"
        status.detail = DurationDetail("A food buff is active", remaining)
    else
        status.state = "missing"
        local bagFood = BestBagCombatFood()
        if bagFood then
            status.icon = bagFood.icon or status.icon
            status.detail = string.format("Eat %s (%d in bags) • %s.", bagFood.name, bagFood.count or 1, bagFood.effect)
            status.secureItemID = bagFood.itemID
            status.secureClickHint = "Click to eat " .. bagFood.name .. " while out of combat."
        else
            local crafted = BestCraftedCombatFood()
            if crafted then
                status.icon = crafted.icon or status.icon
                status.detail = string.format("Cook %s • %s.", crafted.name, crafted.effect)
            else
                status.detail = "No suitable combat food found in bags or learned Cooking recipes."
            end
        end
    end
    statuses[#statuses + 1] = status
    AddReadinessRow(rows, status)
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
            local activeSpellID
            if req.kind == "weapon" then
                local active, remaining = WeaponState()
                if active == nil then
                    status.state, status.detail = "unknown", "Weapon enhancement state cannot be read."
                elseif active then
                    if remaining and remaining > warnSeconds and ns.ScheduleTimedProviderRefresh then
                        ns.ScheduleTimedProviderRefresh(remaining - warnSeconds)
                    end
                    status.state = remaining and remaining <= warnSeconds and "warning" or "ready"
                    status.expiringSoon = status.state == "warning"
                    status.detail = DurationDetail(req.label .. " active", remaining)
                else
                    status.state, status.detail = "missing", "Apply a suitable " .. req.label:lower() .. "."
                end
            else
                local units = BuffUnits(req, role)
                local missing, expiring = {}, {}
                local shortest, readable, campCovered = nil, true, false
                for unitIndex = 1, #units do
                    local target = units[unitIndex]
                    local covered = target.unit == "player" and req.cover and coverage[req.cover]
                    if covered then
                        campCovered = true
                    else
                        local aura, auraSpellID, auraReadable = FindAura(req.spells, target.unit)
                        if not auraReadable then
                            readable = false
                        elseif not aura then
                            missing[#missing + 1] = target.label
                        else
                            if target.unit == "player" and auraSpellID then activeSpellID = auraSpellID end
                            local remaining = AuraRemaining(aura)
                            if remaining then shortest = math.min(shortest or remaining, remaining) end
                            if remaining and remaining <= warnSeconds then expiring[#expiring + 1] = target.label end
                        end
                    end
                end

                if shortest and shortest > warnSeconds and ns.ScheduleTimedProviderRefresh then
                    ns.ScheduleTimedProviderRefresh(shortest - warnSeconds)
                end

                if not readable then
                    status.state, status.detail = "unknown", req.label .. " cannot be read right now."
                elseif #missing > 0 then
                    status.state = "missing"
                    status.detail = #units > 1
                        and string.format("Apply %s to %s.", req.label, UnitList(missing))
                        or "Apply " .. req.label .. "."
                elseif #expiring > 0 then
                    status.state = "warning"
                    status.expiringSoon = true
                    status.detail = DurationDetail(req.label .. " expiring on " .. UnitList(expiring), shortest)
                elseif #units > 1 then
                    status.state = "ready"
                    status.detail = string.format("%s active on all %d group members.", req.label, #units)
                elseif campCovered then
                    status.state = "ready"
                    status.detail = "Covered by Camp Benefits (" .. coverage[req.cover] .. ")."
                else
                    status.state = "ready"
                    status.detail = DurationDetail(req.label .. " active", shortest)
                end
            end
            if req.kind ~= "weapon" then
                local selectedSpellID = SelectRequirementSpell(req, role, activeSpellID)
                if selectedSpellID then
                    local selectedName = SpellName(selectedSpellID) or req.label
                    status.icon = SpellTexture(selectedSpellID) or status.icon
                    status.spellID = selectedSpellID
                    status.castSpellID = selectedSpellID
                    status.castSpellName = selectedName
                    status.castUnit = "player"
                    status.secureClickHint = "Click to cast " .. selectedName .. " on yourself while out of combat."
                end
            end
            if status.state == "missing" and RoleAlertApplies(req, role) then
                status.attention = "critical"
            end
            statuses[#statuses + 1] = status
            AddReadinessRow(rows, status)
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
        title = "Missing Buffs",
        statuses = statuses,
        rows = rows,
    }
end

ns.RegisterProvider("readiness", 10, Build)
