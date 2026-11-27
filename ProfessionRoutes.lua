-------------------------------------------------------------------------------
-- Adventure Tracker: permanent, inventory-aware profession levelling routes.
-------------------------------------------------------------------------------
local _, ns = ...

local trainingCache = {}
local utilityCache
local LearnedMap

local EASY_SOURCES = {
    auto = true,
    trainer = true,
    ["quest+trainer"] = true,
}

local function ItemCount(itemID)
    local api = C_Item and C_Item.GetItemCount or _G.GetItemCount
    if type(api) ~= "function" then return 0 end
    local ok, count = pcall(api, itemID)
    return ok and math.max(0, tonumber(count) or 0) or 0
end

local function ItemName(itemID)
    local data = ns.RecipeCatalogData
    local name = data and data.names and data.names[itemID]
    if name then return name end
    local api = C_Item and C_Item.GetItemNameByID or GetItemInfo
    if type(api) == "function" then
        local ok, value = pcall(api, itemID)
        if ok and value then return value end
    end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return "Item " .. tostring(itemID)
end

local function ItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        local ok, value = pcall(C_Item.GetItemIconByID, itemID)
        if ok and value then return value end
    end
    return 134939
end

local function SpellName(spellID, productID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, value = pcall(C_Spell.GetSpellName, spellID)
        if ok and value then return value end
    end
    return ItemName(productID)
end

local function FormatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount == 0 then return "free" end
    if ns.FormatMarketPrice then return ns.FormatMarketPrice(amount) end
    return tostring(amount) .. " copper"
end

local function TrainingRows(skillLineID)
    skillLineID = tonumber(skillLineID)
    if trainingCache[skillLineID] then return trainingCache[skillLineID] end
    local rows = {}
    local source = ns.ProfessionTrainingData and ns.ProfessionTrainingData.recipes
    for _, raw in ipairs(source and source[skillLineID] or {}) do
        local flags = tostring(raw[8] or "")
        rows[#rows + 1] = {
            spellID = tonumber(raw[1]),
            learnAt = tonumber(raw[2]) or 0,
            productID = tonumber(raw[3]) or 0,
            source = tostring(raw[4] or ""),
            cost = tonumber(raw[5]) or 0,
            teachingItemID = tonumber(raw[6]) or 0,
            level = tonumber(raw[7]) or 0,
            auto = flags:find("auto", 1, true) ~= nil,
            rank = flags:find("rank", 1, true) ~= nil,
        }
    end
    trainingCache[skillLineID] = rows
    return rows
end

function ns.GetPermanentProfessionTraining(skillLineID)
    return TrainingRows(skillLineID)
end

local function TrainingBySpell(skillLineID)
    local result = {}
    for _, row in ipairs(TrainingRows(skillLineID)) do result[row.spellID] = row end
    return result
end

local function SpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
        if ok and known == true then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known == true then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known == true then return true end
    end
    return false
end


function ns.IsProfessionRecipeKnown(spellID, profession)
    if profession then
        local learned = LearnedMap and LearnedMap(profession)
        if learned and learned[tonumber(spellID)] then return true end
    end
    return SpellKnown(tonumber(spellID))
end

LearnedMap = function(profession)
    local learned = {}
    local cache = ns.GetProfessionRecipeCache
        and ns.GetProfessionRecipeCache(profession.skillLineID, profession.name)
    for _, recipe in pairs(cache and cache.recipes or {}) do
        if recipe.recipeID then learned[tonumber(recipe.recipeID)] = true end
    end
    return learned
end

local function ChanceAt(entry, skill)
    local yellow, grey = tonumber(entry.yellowAt) or 0, tonumber(entry.greyAt) or 0
    skill = tonumber(skill) or 0
    if yellow <= 0 or grey <= yellow or skill >= grey then return 0 end
    if skill < yellow then return 1 end
    return math.max(0, math.min(1, (grey - skill) / (grey - yellow)))
end

local function DifficultyAt(entry, skill)
    local chance = ChanceAt(entry, skill)
    if chance <= 0 then return "gray", chance end
    if skill < (tonumber(entry.yellowAt) or 0) then return "orange", chance end
    if chance > 0.5 then return "yellow", chance end
    return "green", chance
end

local function ExpectedCrafts(entry, fromSkill, toSkill)
    local expected = 0
    for skill = fromSkill, math.max(fromSkill, toSkill - 1) do
        local chance = ChanceAt(entry, skill)
        if chance <= 0 then return math.huge end
        expected = expected + (1 / chance)
    end
    return math.max(1, math.ceil(expected))
end

local function UtilityIndex()
    if utilityCache then return utilityCache end
    utilityCache = {}
    local skillLines = { 129, 164, 165, 171, 185, 197, 202, 333, 186 }
    for _, skillLineID in ipairs(skillLines) do
        for _, entry in ipairs(ns.GetRecipeCatalogForProfession(skillLineID) or {}) do
            for _, reagent in ipairs(entry.reagents or {}) do
                utilityCache[reagent.itemID] = (utilityCache[reagent.itemID] or 0) + 1
            end
        end
    end
    return utilityCache
end

local function UnitValue(itemID)
    local price, provider, basis
    if ns.GetMarketPrice then price, provider, basis = ns.GetMarketPrice(itemID) end
    if price then return price, provider, basis, true end
    local vendor = ns.RecipeCatalogData and ns.RecipeCatalogData.buy
    vendor = vendor and tonumber(vendor[itemID])
    if vendor and vendor > 0 then return vendor, "vendor", "price", true end
    return 100, nil, nil, false
end

local function CandidateMaterials(entry, crafts)
    local totalCost, totalUnits, haveCrafts = 0, 0, math.huge
    local priced, provider, basis = true
    for _, reagent in ipairs(entry.reagents or {}) do
        local quantity = math.max(1, tonumber(reagent.quantity) or 1)
        local value, source, valueBasis, known = UnitValue(reagent.itemID)
        totalCost = totalCost + value * quantity
        totalUnits = totalUnits + quantity
        haveCrafts = math.min(haveCrafts, math.floor(ItemCount(reagent.itemID) / quantity))
        priced = priced and known
        provider, basis = provider or source, basis or valueBasis
    end
    if haveCrafts == math.huge then haveCrafts = 0 end
    local outputValue, _, _, outputKnown = UnitValue(entry.productID)
    if priced and outputKnown and outputValue then
        totalCost = math.max(0, totalCost - outputValue * (tonumber(entry.minimum) or 1))
    end
    return {
        costPerCraft = totalCost,
        units = totalUnits,
        bagCrafts = haveCrafts,
        routeCrafts = crafts,
        provider = provider,
        basis = basis,
        priced = priced,
    }
end

local function SourceEasy(source)
    if EASY_SOURCES[source] then return true end
    return source and source:find("trainer", 1, true) ~= nil
end

local function CandidateList(profession, mapID)
    local rank = tonumber(profession.rank) or 0
    if rank >= (tonumber(profession.maxRank) or 0) then return {} end
    local training = TrainingBySpell(profession.skillLineID)
    local learned = LearnedMap(profession)
    local utility = UtilityIndex()
    local candidates = {}
    for _, entry in ipairs(ns.GetRecipeCatalogForProfession(profession.skillLineID) or {}) do
        local fact = training[entry.spellID]
        local learnAt = fact and fact.learnAt or math.max(1, (tonumber(entry.yellowAt) or 1) - 25)
        local known = learned[entry.spellID] == true or SpellKnown(entry.spellID)
        local easy = fact and SourceEasy(fact.source) or false
        local acquisition = not known and not easy and ns.GetRecipeAcquisitionFact
            and ns.GetRecipeAcquisitionFact(entry, mapID) or nil
        local chance = ChanceAt(entry, rank)
        if chance > 0 and learnAt <= rank and (known or easy or acquisition)
            and #(entry.reagents or {}) > 0 then
            local orange = rank < (tonumber(entry.yellowAt) or 0)
            local nextTarget = orange and tonumber(entry.yellowAt) or nil
            if not nextTarget or nextTarget <= rank then
                nextTarget = math.min(tonumber(entry.greyAt) or (rank + 10), rank + 10)
            end
            local crafts = ExpectedCrafts(entry, rank, nextTarget)
            local materials = CandidateMaterials(entry, crafts)
            local tier = orange and 5 or chance >= 0.75 and 4 or chance >= 0.5 and 3 or 2
            local score = tier * 100000000
                + (known and 2500000 or easy and 1500000
                    or acquisition.localSource and 1000000 or 400000)
                + math.min(25, materials.bagCrafts) * 30000
                + math.min(50, utility[entry.productID] or 0) * 10000
                - math.min(2000000, (materials.costPerCraft or 0) / math.max(chance, 0.1))
                - materials.units * 100
                - (fact and fact.cost or 0)
            candidates[#candidates + 1] = {
                entry = entry,
                training = fact,
                learnAt = learnAt,
                learned = known,
                easy = easy,
                acquisition = acquisition,
                chance = chance,
                orange = orange,
                utility = utility[entry.productID] or 0,
                materials = materials,
                score = score,
            }
        end
    end
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.entry.spellID < b.entry.spellID
    end)
    return candidates
end

local function NextEasyUnlock(profession, rank)
    local training = TrainingBySpell(profession.skillLineID)
    local catalog = {}
    for _, entry in ipairs(ns.GetRecipeCatalogForProfession(profession.skillLineID) or {}) do
        catalog[entry.spellID] = entry
    end
    local best
    for spellID, fact in pairs(training) do
        local entry = catalog[spellID]
        if entry and not fact.rank and fact.productID > 0 and fact.learnAt > rank
            and fact.learnAt <= (tonumber(profession.maxRank) or 0)
            and SourceEasy(fact.source) and ChanceAt(entry, fact.learnAt) > 0 then
            best = not best and fact.learnAt or math.min(best, fact.learnAt)
        end
    end
    return best
end

local function PickCandidate(profession, mapID)
    local candidates = CandidateList(profession, mapID)
    local best = candidates[1]
    if not best then return nil end

    -- A useful bulk component is the one deliberate exception to the orange
    -- default: use it when bags support several crafts and the orange route
    -- cannot even be started from current materials.
    if best.orange and best.materials.bagCrafts == 0 then
        for _, candidate in ipairs(candidates) do
            if not candidate.orange and candidate.chance >= 0.35
                and candidate.utility >= 2 and candidate.materials.bagCrafts >= 5 then
                candidate.utilityException = true
                best = candidate
                break
            end
        end
    end

    local rank = tonumber(profession.rank) or 0
    local target = best.orange and tonumber(best.entry.yellowAt) or nil
    local unlock = NextEasyUnlock(profession, rank)
    if unlock and unlock > rank then target = target and math.min(target, unlock) or unlock end
    if not target or target <= rank then
        target = math.min(tonumber(best.entry.greyAt) or rank + 10, rank + 10)
    end
    target = math.max(rank + 1, math.min(target, tonumber(profession.maxRank) or target))
    best.target = target
    best.expectedCrafts = ExpectedCrafts(best.entry, rank, target)
    best.materials = CandidateMaterials(best.entry, best.expectedCrafts)
    return best
end

ns.GetProfessionRouteCandidate = PickCandidate

local function MissingMaterials(candidate)
    local missing = {}
    for _, reagent in ipairs(candidate.entry.reagents or {}) do
        local required = (tonumber(reagent.quantity) or 0) * candidate.expectedCrafts
        local have = ItemCount(reagent.itemID)
        if required > have then
            missing[#missing + 1] = {
                itemID = reagent.itemID,
                name = ItemName(reagent.itemID),
                need = required - have,
                have = have,
                perCraft = tonumber(reagent.quantity) or 0,
            }
        end
    end
    table.sort(missing, function(a, b)
        if a.need ~= b.need then return a.need > b.need end
        return a.itemID < b.itemID
    end)
    return missing
end

local function SourceVerb(kind)
    if kind == "vendor" then return "Buy" end
    if kind == "drop" then return "Farm" end
    if kind == "object" then return "Gather" end
    if kind == "quest" then return "Earn" end
    return "Gather"
end

local function HasProfession(professions, skillLineID)
    for _, profession in ipairs(professions or {}) do
        if tonumber(profession.skillLineID) == tonumber(skillLineID) then return true end
    end
    return false
end

local function AcquisitionText(material, mapID, zoneName, professions)
    if HasProfession(professions, 186) and ns.GetMiningMaterialPlan then
        local plan = ns.GetMiningMaterialPlan(material.itemID, mapID, material.need)
        if plan then return plan.label, plan end
    end
    local fact = ns.GetItemAcquisitionFact and ns.GetItemAcquisitionFact(material.itemID, mapID)
    if not fact or fact.kind == "bag" then
        return "Gather " .. material.need .. "x " .. material.name, nil
    end
    local where
    if fact.localSource then
        where = " here"
    elseif fact.zoneName then
        where = " in " .. fact.zoneName
    else
        where = ""
    end
    local names = fact.names and fact.names ~= "" and (" from " .. fact.names) or ""
    return string.format("%s %dx %s%s%s", SourceVerb(fact.kind), material.need, material.name, names, where), fact
end

local function RecipeLearnText(candidate, mapID)
    local fact = candidate.training
    local source = fact and fact.source or ""
    if source:find("trainer", 1, true) then
        local price = fact.cost > 0 and (" for " .. FormatMoney(fact.cost)) or ""
        return "Learn it from a profession trainer" .. price
    end
    local acquisition = ns.GetRecipeAcquisitionFact and ns.GetRecipeAcquisitionFact(candidate.entry, mapID)
    if acquisition then return acquisition.detail end
    if source == "vendor" then return "Buy its recipe from a vendor" end
    if source == "drop" then return "Find its recipe as a creature drop" end
    if source == "quest" then return "Earn its recipe from a quest" end
    return "Learn the recipe before continuing"
end

local function OpenProfession(profession)
    if InCombatLockdown and InCombatLockdown() then return end
    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        pcall(C_TradeSkillUI.OpenTradeSkill, profession.skillLineID)
    end
    if CastSpellByName then pcall(CastSpellByName, profession.name) end
end

function ns.AddProfessionRouteRow(rows, profession, professions, mapID, zoneName)
    local candidate = PickCandidate(profession, mapID)
    if not candidate then return false end

    local recipeName = SpellName(candidate.entry.spellID, candidate.entry.productID)
    local difficulty, chance = DifficultyAt(candidate.entry, profession.rank)
    local chanceText = string.format("%d%% estimated skill-up chance", math.floor(chance * 100 + 0.5))
    local route = string.format("%s to %d", recipeName, candidate.target)
    local tooltip = string.format(
        "Permanent profession route: %s. %s (%s) at %d %s. Expected crafts to %d: about %d.",
        route, chanceText, difficulty, profession.rank, profession.name,
        candidate.target, candidate.expectedCrafts)
    if candidate.utilityException then
        tooltip = tooltip .. " This is a utility exception: its output is reused by multiple later recipes and your bags support a useful batch."
    elseif candidate.orange then
        tooltip = tooltip .. " Orange/guaranteed crafts are preferred before probabilistic alternatives."
    end
    if candidate.materials.provider then
        tooltip = tooltip .. " Cost comparison used " .. candidate.materials.provider
            .. (candidate.materials.basis and (" " .. candidate.materials.basis) or "") .. "."
    end

    local label, detail, icon = "Craft " .. route, nil, ItemIcon(candidate.entry.productID)
    local state = "ready"
    if not candidate.learned then
        label = "Learn " .. recipeName
        detail = RecipeLearnText(candidate, mapID) .. string.format("; then craft to %d.", candidate.target)
        state = "warning"
    else
        local missing = MissingMaterials(candidate)
        if #missing > 0 then
            local action, source = AcquisitionText(missing[1], mapID, zoneName, professions)
            label = action
            detail = string.format("Then craft about %d %s to reach %d • %s.",
                candidate.expectedCrafts, recipeName, candidate.target, chanceText)
            icon = ItemIcon(missing[1].itemID)
            state = source and source.localSource and "ready" or "info"
            if #missing > 1 then
                detail = detail .. string.format(" %d other material%s also missing.",
                    #missing - 1, #missing == 2 and " is" or "s are")
            end
        else
            detail = string.format("About %d craft%s • %s • materials are in your bags.",
                candidate.expectedCrafts, candidate.expectedCrafts == 1 and "" or "s", chanceText)
        end
    end

    rows[#rows + 1] = {
        key = "profession-route-" .. tostring(profession.skillLineID),
        label = label,
        detail = detail,
        tooltip = tooltip,
        spellID = candidate.entry.spellID,
        state = state,
        icon = icon or profession.icon,
        onClick = function() OpenProfession(profession) end,
    }
    return true
end
