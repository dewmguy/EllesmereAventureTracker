-------------------------------------------------------------------------------
-- Adventure Tracker: build-stamped recipe catalogue and acquisition overlay.
-------------------------------------------------------------------------------
local _, ns = ...

local PROFESSION_INDEX = {
    [171] = 1,  -- Alchemy
    [164] = 2,  -- Blacksmithing
    [185] = 3,  -- Cooking
    [333] = 4,  -- Enchanting
    [202] = 5,  -- Engineering
    [129] = 6,  -- First Aid
    [165] = 7,  -- Leatherworking
    [186] = 8,  -- Mining
    [197] = 9,  -- Tailoring
    [182] = 10, -- Herbalism
    [393] = 11, -- Skinning
    [356] = 12, -- Fishing
}
local MERCHANT_FAVOR_CURRENCY_ID = 3402
local RECIPE_ICON = 134939
local catalogByProfession
local recipeItemsBySpell
local sourceIndexState
local RecipeSource
local areaNameCache = {}

local function Materialize(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or type(loadstring) ~= "function" then return nil end
    local chunk = loadstring(value)
    if type(chunk) ~= "function" then return nil end
    local ok, result = pcall(chunk)
    return ok and type(result) == "table" and result or nil
end

local function ItemCount(itemID)
    local api = C_Item and C_Item.GetItemCount or _G.GetItemCount
    if type(api) ~= "function" then return 0 end
    local ok, count = pcall(api, itemID)
    return ok and tonumber(count) or 0
end

local function ItemName(itemID)
    local data = ns.RecipeCatalogData
    local name = data and data.names and data.names[itemID]
    if name then return name end
    local api = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(api) == "function" then
        local ok, value = pcall(api, itemID)
        if ok and value then return value end
    end
    return "Item " .. tostring(itemID)
end

local function ItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        local ok, value = pcall(C_Item.GetItemIconByID, itemID)
        if ok and value then return value end
    end
    if GetItemIcon then
        local ok, value = pcall(GetItemIcon, itemID)
        if ok and value then return value end
    end
    return RECIPE_ICON
end

local function MerchantFavorInfo()
    local api = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    if type(api) == "function" then
        local ok, info = pcall(api, MERCHANT_FAVOR_CURRENCY_ID)
        if ok and type(info) == "table" then
            return math.max(0, tonumber(info.quantity) or 0), info.iconFileID
        end
    end
    if type(GetCurrencyInfo) == "function" then
        local ok, _, quantity, icon = pcall(GetCurrencyInfo, MERCHANT_FAVOR_CURRENCY_ID)
        if ok then return math.max(0, tonumber(quantity) or 0), icon end
    end
    return 0, nil
end

local function ItemRequiredLevel(itemID)
    local generated = ns.RecipeSourceIndexData and ns.RecipeSourceIndexData.requiredLevels
    if generated and generated[itemID] then return tonumber(generated[itemID]) end
    local api = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(api) ~= "function" then return nil end
    local result = { pcall(api, itemID) }
    if not result[1] then return nil end
    return tonumber(result[6])
end

local function ParseCatalog()
    if catalogByProfession then return catalogByProfession end
    catalogByProfession = {}
    local data = ns.RecipeCatalogData
    for index = 1, #(data and data.recipes or {}) do
        local row = data.recipes[index]
        local product, minimum, maximum, professionIndex, yellowAt, greyAt, spellID, reagents =
            row:match("^(%d+);(%d+);(%d+);(%d+);(%d+);(%d+);(%d+);(.+)$")
        product, professionIndex, yellowAt, greyAt, spellID =
            tonumber(product), tonumber(professionIndex), tonumber(yellowAt), tonumber(greyAt), tonumber(spellID)
        if product and professionIndex and spellID then
            local entry = {
                productID = product,
                minimum = tonumber(minimum) or 1,
                maximum = tonumber(maximum) or tonumber(minimum) or 1,
                professionIndex = professionIndex,
                yellowAt = yellowAt or 0,
                greyAt = greyAt or 0,
                spellID = spellID,
                reagents = {},
            }
            for itemID, quantity in reagents:gmatch("(%d+):(%d+)") do
                entry.reagents[#entry.reagents + 1] = {
                    itemID = tonumber(itemID),
                    quantity = tonumber(quantity),
                }
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
            local list = catalogByProfession[professionIndex]
            if not list then list = {}; catalogByProfession[professionIndex] = list end
            list[#list + 1] = entry
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return catalogByProfession
end

function ns.GetRecipeCatalogForProfession(skillLineID)
    return ParseCatalog()[PROFESSION_INDEX[tonumber(skillLineID)]] or {}
end

local function StartSourceIndex()
    if sourceIndexState then return sourceIndexState end
    if ns.Get("showProfessionAttainableRecipes") ~= true then return "disabled" end
    local generated = ns.RecipeSourceIndexData and ns.RecipeSourceIndexData.recipeItems
    if type(generated) ~= "table" then
        sourceIndexState = "unavailable"
        return sourceIndexState
    end
    local data = ns.QuestData
    local itemDB
    if data and type(data.GetEntities) == "function" then
        local _, _, resolvedItemDB = data.GetEntities()
        itemDB = resolvedItemDB
    end
    if not (itemDB and type(itemDB.GetAllIds) == "function") then
        sourceIndexState = "unavailable"
        return sourceIndexState
    end
    recipeItemsBySpell = generated
    sourceIndexState = "ready"
    return sourceIndexState
end

local function Names(entity, ids, limit)
    local values, seen = {}, {}
    if type(ids) == "table" then
        for _, id in pairs(ids) do
            local name = ns.QuestData.Value(entity, "name", tonumber(id))
            if name and not seen[name] then
                seen[name] = true
                values[#values + 1] = name
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    ns.BudgetedSort(values, function(a, b) return a < b end)
    local total = #values
    while #values > (limit or 3) do
        values[#values] = nil
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local text = table.concat(values, ", ")
    if total > #values then text = text .. string.format(" +%d more", total - #values) end
    return text, total
end

local function FactionEligibleVendors(npcDB, ids)
    if type(ids) ~= "table" then return nil end
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local factionCode = playerFaction == "Alliance" and "A"
        or playerFaction == "Horde" and "H" or nil
    if not factionCode then return ids end

    local eligible = {}
    for _, id in pairs(ids) do
        id = tonumber(id)
        local friendlyTo = id and ns.QuestData.Value(npcDB, "friendlyToFaction", id) or nil
        if friendlyTo == factionCode or friendlyTo == "AH" then
            eligible[#eligible + 1] = id
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return #eligible > 0 and eligible or nil
end

local function SpawnsHere(entity, id, areaID)
    if not areaID then return false end
    local spawns = ns.QuestData.Value(entity, "spawns", tonumber(id))
    if type(spawns) ~= "table" then return false end
    for zoneID in pairs(spawns) do
        if tonumber(zoneID) == tonumber(areaID) then return true end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return false
end

local function AnySpawnHere(entity, ids, areaID)
    if type(ids) ~= "table" then return false end
    for _, id in pairs(ids) do
        if SpawnsHere(entity, id, areaID) then return true end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return false
end

local function LocalSpawnIDs(entity, ids, areaID)
    if type(ids) ~= "table" or not areaID then return ids end
    local localIDs = {}
    for _, id in pairs(ids) do
        if SpawnsHere(entity, id, areaID) then localIDs[#localIDs + 1] = id end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return #localIDs > 0 and localIDs or ids
end

local function AreaName(areaID)
    areaID = tonumber(areaID)
    if not areaID then return nil end
    local cached = areaNameCache[areaID]
    if cached ~= nil then return cached or nil end

    local library = _G.LibQuestieDB
    if not (library and library.Support and type(library.Support.Get) == "function") then
        areaNameCache[areaID] = false
        return nil
    end
    local ok, zones = pcall(library.Support.Get, "ZoneDB")
    if not ok or type(zones) ~= "table" then
        areaNameCache[areaID] = false
        return nil
    end
    local private = type(zones.private) == "table" and zones.private or {}

    local dungeons = Materialize(zones.dungeons or private.dungeons)
    local dungeon = dungeons and dungeons[areaID]
    if not dungeon and type(dungeons) == "table" then
        for _, entry in pairs(dungeons) do
            for _, alternativeID in ipairs(type(entry) == "table" and entry[2] or {}) do
                if tonumber(alternativeID) == areaID then dungeon = entry break end
            end
            if dungeon then break end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    if type(dungeon) == "table" and type(dungeon[1]) == "string" then
        areaNameCache[areaID] = dungeon[1]
        return dungeon[1]
    end

    local reverse = Materialize(zones.areaIdToUiMapId or private.areaIdToUiMapId)
    local mapID = reverse and tonumber(reverse[areaID])
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local name = info and info.name or nil
    areaNameCache[areaID] = name or false
    return name
end

local function SpawnZoneName(entity, ids, preferredAreaID)
    if AnySpawnHere(entity, ids, preferredAreaID) then return AreaName(preferredAreaID) end
    local names = {}
    for _, id in pairs(type(ids) == "table" and ids or {}) do
        local spawns = ns.QuestData.Value(entity, "spawns", tonumber(id))
        if type(spawns) == "table" then
            for areaID in pairs(spawns) do
                local name = AreaName(areaID)
                if name then names[name] = true end
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local ordered = {}
    for name in pairs(names) do
        ordered[#ordered + 1] = name
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    ns.BudgetedSort(ordered, function(a, b) return a < b end)
    return ordered[1]
end

local function ReasonableDrops(npcDB, ids)
    if type(ids) ~= "table" then return nil end
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local result = {}
    for _, id in pairs(ids) do
        id = tonumber(id)
        local minimum = id and tonumber(ns.QuestData.Value(npcDB, "minLevel", id)) or nil
        if id and (not minimum or minimum <= playerLevel + 7) then result[#result + 1] = id end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return #result > 0 and result or nil
end

local function BestSourceForItem(itemID, areaID, ignoreInventory)
    local questDB, npcDB, itemDB, objectDB = ns.QuestData.GetEntities()
    if not itemDB then return nil end
    local recipeName = ns.QuestData.Value(itemDB, "name", itemID) or ItemName(itemID)
    if not ignoreInventory and ItemCount(itemID) > 0 then
        return {
            score = 140, localSource = true, itemID = itemID,
            detail = recipeName .. " is already in your bags",
            tooltip = "You already have this recipe in your bags.",
        }
    end

    local best
    local function Consider(score, localSource, detail, kind, zoneName, names, note)
        score = score + (localSource and 30 or 0)
        if not best or score > best.score then
            if zoneName then detail = detail .. " in " .. zoneName end
            best = {
                score = score, localSource = localSource, itemID = itemID,
                detail = recipeName .. " • " .. detail,
                tooltip = detail .. "." .. (note and (" " .. note) or ""),
                kind = kind, zoneName = zoneName, names = names,
            }
        end
    end

    local vendors = FactionEligibleVendors(npcDB, ns.QuestData.Value(itemDB, "vendors", itemID))
    local vendorNames, vendorCount = Names(npcDB, vendors, 3)
    if vendorCount > 0 then
        local localSource = AnySpawnHere(npcDB, vendors, areaID)
        Consider(120, localSource, "Sold by " .. vendorNames,
            "vendor", SpawnZoneName(npcDB, vendors, areaID), vendorNames,
            "Stock and price may vary.")
    end

    local drops = ReasonableDrops(npcDB, ns.QuestData.Value(itemDB, "npcDrops", itemID))
    local namedDrops = LocalSpawnIDs(npcDB, drops, areaID)
    local dropNames, dropCount = Names(npcDB, namedDrops, 3)
    if dropCount > 0 then
        local localSource = AnySpawnHere(npcDB, drops, areaID)
        Consider(90, localSource, "Drops from " .. dropNames,
            "drop", SpawnZoneName(npcDB, namedDrops, areaID), dropNames)
    end

    local objects = ns.QuestData.Value(itemDB, "objectDrops", itemID)
    local objectNames, objectCount = Names(objectDB, objects, 3)
    if objectCount > 0 then
        local localSource = AnySpawnHere(objectDB, objects, areaID)
        Consider(75, localSource, "Looted from " .. objectNames,
            "object", SpawnZoneName(objectDB, objects, areaID), objectNames)
    end

    local questRewards = ns.QuestData.Value(itemDB, "questRewards", itemID)
    if type(questRewards) == "table" then
        local available = {}
        for _, questID in pairs(questRewards) do
            questID = tonumber(questID)
            if questID and not ns.QuestData.IsComplete(questID) and not ns.QuestData.IsInLog(questID)
                and ns.QuestData.RequirementsMet(questDB, questID) then
                available[#available + 1] = questID
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
        local questNames, questCount = Names(questDB, available, 2)
        if questCount > 0 then
            Consider(100, false, "Reward from " .. questNames,
                "quest", nil, questNames)
        end
    end
    return best
end

function ns.GetItemAcquisitionFact(itemID, mapID)
    if StartSourceIndex() ~= "ready" then return nil end
    local areaID = ns.ResolveQuestieAreaID and ns.ResolveQuestieAreaID(mapID)
    return BestSourceForItem(tonumber(itemID), areaID, true)
end

function ns.GetRecipeAcquisitionFact(entry, mapID)
    if StartSourceIndex() ~= "ready" then return nil end
    local areaID = ns.ResolveQuestieAreaID and ns.ResolveQuestieAreaID(mapID)
    return RecipeSource(entry, areaID)
end

RecipeSource = function(entry, areaID)
    if sourceIndexState ~= "ready" then return nil end
    local itemIDs = recipeItemsBySpell[entry.spellID]
    if type(itemIDs) == "number" then itemIDs = { itemIDs } end
    local best
    for index = 1, #(itemIDs or {}) do
        local source = BestSourceForItem(itemIDs[index], areaID)
        if source and (not best or source.score > best.score) then best = source end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return best
end

local function LearnedSpells(profession)
    local cache = ns.GetProfessionRecipeCache
        and ns.GetProfessionRecipeCache(profession.skillLineID, profession.name)
    if not cache or type(cache.recipes) ~= "table" then return nil, cache end
    local learned = {}
    for _, recipe in pairs(cache.recipes) do
        if recipe.recipeID then learned[tonumber(recipe.recipeID)] = true end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return learned, cache
end

local function ExpansionKey(profession, group)
    local key = tostring(ns.CharacterKey()) .. ":" .. tostring(profession.skillLineID)
    return group and (key .. ":" .. group) or key
end

local function Expanded(profession, group)
    local source = ns.Get("professionRecipeCatalogExpandedByCharacter")
    return type(source) == "table" and source[ExpansionKey(profession, group)] == true
end

local function ToggleExpanded(profession, group)
    local source = ns.Get("professionRecipeCatalogExpandedByCharacter")
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            copy[key] = value
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    local key = ExpansionKey(profession, group)
    copy[key] = not (copy[key] == true)
    ns.Set("professionRecipeCatalogExpandedByCharacter", copy, true)
    if ns.RequestPresentationRefresh then
        ns.RequestPresentationRefresh("profession recipe expansion")
    elseif ns.RequestRefresh then
        ns.RequestRefresh(false, "profession recipe expansion")
    end
end

local function CrossProfessionSynergy(profession, professions)
    if not ns.Get("showProfessionSynergy") then return nil end
    -- ProfessionRoutes handles permanent, inventory-aware material synergies.
    -- Keep this cache-based implementation only as a compatibility fallback.
    if ns.GetProfessionRouteCandidate then return nil end
    local consumer = ns.GetProfessionRecipeCache
        and ns.GetProfessionRecipeCache(profession.skillLineID, profession.name)
    if not consumer or type(consumer.recipes) ~= "table" then return nil end
    local products = {}
    for index = 1, #professions do
        local producerProfession = professions[index]
        if producerProfession.skillLineID ~= profession.skillLineID then
            local cache = ns.GetProfessionRecipeCache(producerProfession.skillLineID, producerProfession.name)
            for _, recipe in pairs(cache and cache.recipes or {}) do
                if recipe.resultItemID then
                    products[recipe.resultItemID] = {
                        profession = producerProfession,
                        recipe = recipe,
                    }
                end
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local best
    for _, recipe in pairs(consumer.recipes) do
        if (recipe.difficulty or 0) >= 2 then
            for _, reagent in ipairs(recipe.reagents or {}) do
                local producer = products[reagent.itemID]
                local missing = math.max(0, (reagent.quantity or 0) - ItemCount(reagent.itemID))
                if producer and missing > 0 then
                    local score = (recipe.difficulty or 0) * 100 + missing
                    if not best or score > best.score then
                        best = { score = score, consumer = recipe, producer = producer, reagent = reagent, missing = missing }
                    end
                end
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if not best then return nil end
    local reagentName = ItemName(best.reagent.itemID)
    return {
        key = "cross-profession-" .. tostring(profession.skillLineID),
        label = "Synergy: Craft " .. reagentName,
        detail = string.format("Make %dx with %s (%s), then use it for %s.",
            best.missing, best.producer.profession.name, best.producer.recipe.name, best.consumer.name),
        tooltip = string.format("%s produces a reagent needed by the current %s skill-up recipe.",
            best.producer.profession.name, profession.name),
        state = "info",
        icon = best.producer.recipe.icon or profession.icon,
    }
end

local function CandidateRow(candidate, indent)
    local entry, source = candidate.entry, candidate.source
    local productName = ItemName(entry.productID)
    local label = candidate.delta and candidate.delta > 0
        and ("Unlearned crafted upgrade: " .. productName)
        or ((candidate.merchantFavor and "Merchant's Favor recipe: " or "Recipe opportunity: ") .. productName)
    local skill = candidate.skill or math.max(1, (entry.yellowAt or 0) - 25)
    local favorDetail = candidate.merchantFavor and " • Merchant's Favor required." or ""
    local detail = source.detail .. favorDetail
        .. string.format(" • Around %d %s skill.", skill, candidate.profession.name)
    if candidate.delta and candidate.delta > 0 then
        detail = detail .. string.format(" +%d item levels for %s.", candidate.delta, candidate.slot or "gear")
    end
    return {
        key = string.format("catalog-recipe-%s-%d", tostring(candidate.profession.skillLineID), entry.spellID),
        label = label,
        detail = detail,
        tooltip = string.format("%s%s\n\nLearnable at around %d %s skill.%s",
            source.tooltip,
            candidate.merchantFavor and "\n\nThis recipe is purchased with Merchant's Favor rather than ordinary coin." or "",
            skill, candidate.profession.name,
            candidate.delta and candidate.delta > 0
                and string.format(" This would be a %d-item-level upgrade for %s.", candidate.delta, candidate.slot or "gear")
                or ""),
        state = candidate.delta and candidate.delta > 0 and "warning" or (source.localSource and "ready" or "info"),
        icon = ItemIcon(entry.productID),
        indentLevel = indent,
    }
end

local function CatalogCandidates(profession, mapID, learned)
    learned = learned or LearnedSpells(profession)
    if not learned then return nil end
    local areaID = ns.ResolveQuestieAreaID and ns.ResolveQuestieAreaID(mapID)
    local candidates = {}
    local rank = tonumber(profession.rank) or 0
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local hidden = ns.RecipeCatalogData.hidden or {}
    for _, entry in ipairs(ns.GetRecipeCatalogForProfession(profession.skillLineID)) do
        local approximateSkill = math.max(1, (entry.yellowAt or 0) - 25)
        local requiredLevel = ItemRequiredLevel(entry.productID)
        if not learned[entry.spellID] and not hidden[entry.productID]
            and approximateSkill <= rank + 15
            and (not requiredLevel or requiredLevel <= playerLevel + 5) then
            local source = RecipeSource(entry, areaID)
            if source then
                local item, delta, slot, _, alreadyEquipped
                local equippable = C_Item and C_Item.IsEquippableItem
                local evaluate = true
                if type(equippable) == "function" then
                    local ok, value = pcall(equippable, entry.productID)
                    evaluate = ok and value == true
                end
                if evaluate and ns.GetCraftedItemUpgrade then
                    item, delta, slot, _, alreadyEquipped = ns.GetCraftedItemUpgrade(entry.productID)
                end
                if not alreadyEquipped and (not item or (item.requiredLevel or 0) <= playerLevel) then
                    local score = source.score - math.max(0, approximateSkill - rank) * 2
                        + (delta and delta > 0 and (300 + delta * 10) or 0)
                    candidates[#candidates + 1] = {
                        entry = entry, source = source, profession = profession,
                        score = score, delta = delta, slot = slot,
                    }
                end
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    ns.BudgetedSort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return ItemName(a.entry.productID) < ItemName(b.entry.productID)
    end)
    return candidates
end

local function MerchantFavorCandidates(profession, mapID, learned)
    local areaID = ns.ResolveQuestieAreaID and ns.ResolveQuestieAreaID(mapID)
    local candidates = {}
    local rank = tonumber(profession.rank) or 0
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local training = ns.GetPermanentProfessionTraining
        and ns.GetPermanentProfessionTraining(profession.skillLineID) or {}
    for index = 1, #training do
        local fact = training[index]
        local skill = tonumber(fact.learnAt) or 0
        local requiredLevel = tonumber(fact.level) or 0
        local productID = tonumber(fact.productID) or 0
        local teachingItemID = tonumber(fact.teachingItemID) or 0
        local displayItemID = productID > 0 and productID or teachingItemID
        if fact.favor and fact.spellID and displayItemID > 0 and teachingItemID > 0
            and not learned[fact.spellID]
            and skill <= rank + 15
            and (requiredLevel <= 0 or requiredLevel <= playerLevel + 5) then
            local source = BestSourceForItem(teachingItemID, areaID, true)
            if not source or source.kind ~= "vendor" then
                source = {
                    score = 120,
                    kind = "vendor",
                    detail = "Purchased with Merchant's Favor",
                    tooltip = "Purchase this recipe from a Merchant's Favor vendor.",
                }
            end
            local item, delta, slot, _, alreadyEquipped
            local equippable = C_Item and C_Item.IsEquippableItem
            local evaluate = productID > 0
            if evaluate and type(equippable) == "function" then
                local ok, value = pcall(equippable, productID)
                evaluate = ok and value == true
            end
            if evaluate and ns.GetCraftedItemUpgrade then
                item, delta, slot, _, alreadyEquipped = ns.GetCraftedItemUpgrade(productID)
            end
            if not alreadyEquipped and (not item or (item.requiredLevel or 0) <= playerLevel) then
                candidates[#candidates + 1] = {
                    entry = { spellID = fact.spellID, productID = displayItemID },
                    source = source,
                    profession = profession,
                    skill = math.max(1, skill),
                    score = source.score - math.max(0, skill - rank) * 2
                        + (delta and delta > 0 and (300 + delta * 10) or 0),
                    delta = delta,
                    slot = slot,
                    merchantFavor = true,
                }
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    ns.BudgetedSort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return ItemName(a.entry.productID) < ItemName(b.entry.productID)
    end)
    return candidates
end

function ns.AddRecipeCatalogRows(rows, profession, professions, mapID)
    local synergy = CrossProfessionSynergy(profession, professions)
    if synergy then rows[#rows + 1] = synergy end
    if not ns.Get("showProfessionAttainableRecipes") or not PROFESSION_INDEX[profession.skillLineID] then return end
    local learned = LearnedSpells(profession)
    if not learned then return end
    local state = StartSourceIndex()
    if state ~= "ready" then return end

    local candidates = CatalogCandidates(profession, mapID, learned) or {}
    local merchantFavor = MerchantFavorCandidates(profession, mapID, learned)
    local favorQuantity, favorIcon = MerchantFavorInfo()
    if #candidates == 0 and #merchantFavor == 0 then return end

    local direct, mobDrops = {}, {}
    for index = 1, #candidates do
        local candidate = candidates[index]
        local target = candidate.source.kind == "drop" and mobDrops or direct
        target[#target + 1] = candidates[index]
        if ns.YieldForBudget then ns.YieldForBudget() end
    end

    if #direct > 0 then rows[#rows + 1] = CandidateRow(direct[1], 0) end
    if #direct > 1 then
        local function DirectExpanded() return Expanded(profession) end
        rows[#rows + 1] = {
            key = "catalog-expand-" .. tostring(profession.skillLineID),
            label = function()
                return string.format("%s %d additional attainable recipe%s",
                    DirectExpanded() and "− Hide" or "+ Show", #direct - 1, #direct == 2 and "" or "s")
            end,
            detail = function()
                return DirectExpanded()
                    and "Hide the additional vendor, quest and object-loot recipes."
                    or "Show additional recipes available from vendors, quests and objects."
            end,
            tooltip = "These recipes are appropriate to your current profession skill and character level.",
            state = "info",
            icon = profession.icon,
            onClick = function() ToggleExpanded(profession) end,
            disclosure = true,
            expanded = DirectExpanded,
        }
        for index = 2, #direct do
            local row = CandidateRow(direct[index], 1)
            row.visible = DirectExpanded
            rows[#rows + 1] = row
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end

    if #merchantFavor > 0 then
        local function FavorExpanded() return Expanded(profession, "merchant-favor") end
        local bestName = ItemName(merchantFavor[1].entry.productID)
        rows[#rows + 1] = {
            key = "catalog-merchant-favor-" .. tostring(profession.skillLineID),
            label = function()
                return string.format("%s %d Merchant's Favor recipe%s",
                    FavorExpanded() and "− Hide" or "+ Show", #merchantFavor, #merchantFavor == 1 and "" or "s")
            end,
            detail = function()
                if favorQuantity > 0 then
                    return string.format("You have %d Merchant's Favor • Best fit: %s.", favorQuantity, bestName)
                end
                return FavorExpanded() and "Hide recipes purchased with Merchant's Favor."
                    or "Show recipes purchased with Merchant's Favor instead of ordinary coin."
            end,
            tooltip = string.format("You currently have %d Merchant's Favor. Recipes are ordered by usefulness for your current character. Check the vendor for the exact Favor cost and reputation requirement.", favorQuantity),
            state = favorQuantity > 0 and "ready" or "info",
            icon = favorIcon or profession.icon,
            onClick = function() ToggleExpanded(profession, "merchant-favor") end,
            disclosure = true,
            expanded = FavorExpanded,
        }
        for index = 1, #merchantFavor do
            local row = CandidateRow(merchantFavor[index], 1)
            row.visible = FavorExpanded
            rows[#rows + 1] = row
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end

    if #mobDrops > 0 then
        local function MobDropsExpanded() return Expanded(profession, "mob-drops") end
        rows[#rows + 1] = {
            key = "catalog-mob-drops-" .. tostring(profession.skillLineID),
            label = function()
                return string.format("%s %d available mob-drop recipe%s",
                    MobDropsExpanded() and "− Hide" or "+ Show", #mobDrops, #mobDrops == 1 and "" or "s")
            end,
            detail = function()
                return MobDropsExpanded() and "Hide recipes obtained from enemies."
                    or "Show recipes obtained from enemies, including each mob and zone."
            end,
            tooltip = "Expand this list to see which enemies drop these recipes and where those enemies are found.",
            state = "info",
            icon = profession.icon,
            onClick = function() ToggleExpanded(profession, "mob-drops") end,
            disclosure = true,
            expanded = MobDropsExpanded,
        }
        for index = 1, #mobDrops do
            local row = CandidateRow(mobDrops[index], 1)
            row.visible = MobDropsExpanded
            rows[#rows + 1] = row
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "QuestieDB" then
        sourceIndexState, recipeItemsBySpell, areaNameCache = nil, nil, {}
        if ns.RequestRefresh then ns.RequestRefresh("professions", "QuestieDB loaded") end
    end
end)
