-------------------------------------------------------------------------------
-- Adventure Tracker: profession planning and local-opportunity provider.
-------------------------------------------------------------------------------
local _, ns = ...

local CRAFTING_PROFESSIONS = {
    [164] = true, -- Blacksmithing
    [165] = true, -- Leatherworking
    [171] = true, -- Alchemy
    [197] = true, -- Tailoring
    [202] = true, -- Engineering
    [333] = true, -- Enchanting
    [185] = true, -- Cooking
    [129] = true, -- First Aid
}

local TRAINER_PROFESSIONS = {
    [164] = true, [165] = true, [171] = true, [197] = true,
    [202] = true, [333] = true, [185] = true, [129] = true,
    [182] = true, [186] = true, [393] = true, [356] = true,
    [794] = true,
}

local GATHERING_HINTS = {
    [182] = "Watch the minimap for herbs while you travel.",
    [186] = "Watch the minimap for ore veins while you travel.",
    [393] = "Local beasts may provide skinning opportunities.",
    [356] = "Local waters may advance Fishing or supply Cooking materials.",
}

local GATHERING_KINDS = {
    [182] = "herb", -- Herbalism
    [186] = "ore",  -- Mining
    [393] = "skin", -- Skinning
    [356] = "fish", -- Fishing
}

-- A profession rank becomes trainable before the previous rank is capped.
local RANK_GOALS = {
    [75] = { skill = 50, level = 10, name = "Journeyman", nextCap = 150 },
    [150] = { skill = 125, level = 20, name = "Expert", nextCap = 225 },
    [225] = { skill = 200, level = 35, name = "Artisan", nextCap = 300 },
}

local FISHING_RANK_GOALS = {
    [75] = RANK_GOALS[75],
    [150] = RANK_GOALS[150],
    [225] = { skill = 225, level = 35, name = "Artisan", nextCap = 300 },
}

local NODE_NAMES = {
    copper_vein = "Copper Veins", tin_vein = "Tin Veins",
    silver_vein = "Silver Veins", iron_deposit = "Iron Deposits",
    gold_vein = "Gold Veins", mithril_deposit = "Mithril Deposits",
    truesilver_deposit = "Truesilver Deposits",
    small_thorium_vein = "Small Thorium Veins",
    rich_thorium_vein = "Rich Thorium Veins",
}

local TRAINER_DESTINATIONS = {
    [164] = { Alliance = "a Blacksmithing trainer in Stormwind or Ironforge", Horde = "a Blacksmithing trainer in Orgrimmar" },
    [182] = { Alliance = "an Herbalism trainer in Stormwind or Ironforge", Horde = "an Herbalism trainer in Orgrimmar" },
    [186] = { Alliance = "a Mining trainer in Stormwind or Ironforge", Horde = "a Mining trainer in Orgrimmar" },
    [393] = { Alliance = "a Skinning trainer in Stormwind or Ironforge", Horde = "a Skinning trainer in Orgrimmar" },
}

local MINING_MATERIALS = {
    [2770] = { nodes = { "copper_vein" }, names = { "Copper Veins" }, action = "mine" },
    [2840] = { nodes = { "copper_vein" }, names = { "Copper Veins" }, action = "smelt" },
    [2771] = { nodes = { "tin_vein" }, names = { "Tin Veins" }, action = "mine" },
    [3576] = { nodes = { "tin_vein" }, names = { "Tin Veins" }, action = "smelt" },
    [2841] = { nodes = { "copper_vein", "tin_vein" }, names = { "Copper Veins", "Tin Veins" }, action = "smelt", requiresAll = true },
    [2775] = { nodes = { "silver_vein" }, names = { "Silver Veins" }, action = "mine" },
    [2842] = { nodes = { "silver_vein" }, names = { "Silver Veins" }, action = "smelt" },
    [2772] = { nodes = { "iron_deposit" }, names = { "Iron Deposits" }, action = "mine" },
    [3575] = { nodes = { "iron_deposit" }, names = { "Iron Deposits" }, action = "smelt" },
    [3859] = { nodes = { "iron_deposit" }, names = { "Iron Deposits" }, action = "smelt" },
    [2776] = { nodes = { "gold_vein" }, names = { "Gold Veins" }, action = "mine" },
    [3577] = { nodes = { "gold_vein" }, names = { "Gold Veins" }, action = "smelt" },
    [3858] = { nodes = { "mithril_deposit" }, names = { "Mithril Deposits" }, action = "mine" },
    [3860] = { nodes = { "mithril_deposit" }, names = { "Mithril Deposits" }, action = "smelt" },
    [7911] = { nodes = { "truesilver_deposit" }, names = { "Truesilver Deposits" }, action = "mine" },
    [6037] = { nodes = { "truesilver_deposit" }, names = { "Truesilver Deposits" }, action = "smelt" },
    [10620] = { nodes = { "small_thorium_vein", "rich_thorium_vein" }, names = { "Thorium Veins" }, action = "mine" },
    [12359] = { nodes = { "small_thorium_vein", "rich_thorium_vein" }, names = { "Thorium Veins" }, action = "smelt" },
    [2835] = { nodes = { "copper_vein" }, names = { "Copper Veins" }, action = "gather" },
    [2836] = { nodes = { "copper_vein", "tin_vein", "silver_vein" }, names = { "Copper, Tin or Silver Veins" }, action = "gather" },
    [2838] = { nodes = { "iron_deposit", "gold_vein" }, names = { "Iron Deposits or Gold Veins" }, action = "gather" },
    [7912] = { nodes = { "mithril_deposit", "truesilver_deposit" }, names = { "Mithril or Truesilver Deposits" }, action = "gather" },
    [12365] = { nodes = { "small_thorium_vein", "rich_thorium_vein" }, names = { "Thorium Veins" }, action = "gather" },
}

local EQUIPMENT_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}

local SLOT_LABELS = {
    INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulders",
    INVTYPE_BODY = "Shirt", INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest",
    INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet",
    INVTYPE_WRIST = "Wrists", INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Finger",
    INVTYPE_TRINKET = "Trinket", INVTYPE_CLOAK = "Back", INVTYPE_WEAPON = "Weapon",
    INVTYPE_2HWEAPON = "Two-Hand Weapon", INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_SHIELD = "Shield",
    INVTYPE_HOLDABLE = "Off Hand", INVTYPE_RANGED = "Ranged",
    INVTYPE_RANGEDRIGHT = "Ranged", INVTYPE_THROWN = "Ranged",
}

-- Versioned because early scans used GetBaseProfessionInfo().profession, which
-- is not the open profession's skill-line ID on Forever and could merge Cooking
-- recipes into Blacksmithing or First Aid caches.
local RECIPE_CACHE_VERSION = 3
local TRAINER_CACHE_VERSION = 1

local function ProfessionList()
    if not GetProfessions or not GetProfessionInfo then return {} end
    local ok, primary1, primary2, archaeology, fishing, cooking, firstAid = pcall(GetProfessions)
    if not ok then return {} end
    local books = {
        [1] = primary1, [2] = primary2, [3] = archaeology,
        [4] = fishing, [5] = cooking, [6] = firstAid,
    }
    local result = {}
    for i = 1, 6 do
        local index = books[i]
        if index then
            local valid, name, icon, rank, maxRank, _, _, skillLineID, rankBonus = pcall(GetProfessionInfo, index)
            if valid and name then
                result[#result + 1] = {
                    name = name,
                    icon = icon,
                    rank = tonumber(rank) or 0,
                    rankBonus = math.max(0, tonumber(rankBonus) or 0),
                    maxRank = tonumber(maxRank) or 0,
                    skillLineID = skillLineID,
                }
            end
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end
ns.GetProfessionList = ProfessionList

local function PublicNumber(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return tonumber(value)
end

local function FindProfession(skillLineID, name)
    local professions = ProfessionList()
    if name then
        for i = 1, #professions do
            if professions[i].name == name then return professions[i] end
        end
    end
    skillLineID = PublicNumber(skillLineID)
    if skillLineID then
        for i = 1, #professions do
            if PublicNumber(professions[i].skillLineID) == skillLineID then return professions[i] end
        end
    end
end

local function ItemName(itemID)
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and name then return name end
    end
    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, itemID)
        if ok and name then return name end
    end
    return "Item " .. tostring(itemID)
end

local function ItemID(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, id = pcall(C_Item.GetItemInfoInstant, value)
        if ok and id then return id end
    end
    return tonumber(value:match("item:(%d+)"))
end

local function DifficultyRank(value)
    local difficulty = Enum and Enum.TradeskillRelativeDifficulty
    if difficulty then
        if value == difficulty.Optimal then return 4 end
        if value == difficulty.Medium then return 3 end
        if value == difficulty.Easy then return 2 end
        if value == difficulty.Trivial then return 1 end
    end
    if type(value) == "number" and value >= 0 and value <= 3 then return 4 - value end
    return 0
end

local function RecipeCache(skillLineID, professionName)
    local root = ns.DB().professionRecipeCache
    local character = type(root) == "table" and root[ns.CharacterKey()]
    if type(character) ~= "table" then return nil end
    local cacheKey = tostring(skillLineID)
    local cache = character[cacheKey]
    if type(cache) ~= "table" then return nil end
    if cache.cacheVersion ~= RECIPE_CACHE_VERSION
        or tonumber(cache.skillLineID) ~= tonumber(skillLineID)
        or (professionName and cache.professionName ~= professionName) then
        character[cacheKey] = nil
        return nil
    end
    return cache
end

function ns.GetProfessionRecipeCache(skillLineID, professionName)
    return RecipeCache(skillLineID, professionName)
end

function ns.MarkProfessionRecipeCachesDirty(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local root = ns.DB().professionRecipeCache
    local character = type(root) == "table" and root[ns.CharacterKey()]
    if type(character) ~= "table" then return false end
    local reportedSkillLine, reportedRoot
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineForRecipe then
        local ok, skillLine, _, rootSkillLine = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, spellID)
        if ok then
            reportedSkillLine = PublicNumber(skillLine)
            reportedRoot = PublicNumber(rootSkillLine)
        end
    end
    local changed = false
    for cacheKey, cache in pairs(character) do
        local skillLineID = tonumber(cacheKey)
        local matches = skillLineID and (skillLineID == reportedSkillLine or skillLineID == reportedRoot)
        if not matches and skillLineID and ns.GetRecipeCatalogForProfession then
            for _, entry in ipairs(ns.GetRecipeCatalogForProfession(skillLineID) or {}) do
                if tonumber(entry.spellID) == spellID then matches = true break end
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
        end
        if matches and type(cache) == "table" and cache.cacheVersion == RECIPE_CACHE_VERSION then
            cache.dirty = true
            changed = true
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return changed
end

local function FormatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount == 0 then return "Free" end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = string.format("%dg", gold) end
    if silver > 0 or gold > 0 then parts[#parts + 1] = string.format("%ds", silver) end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = string.format("%dc", copper) end
    return table.concat(parts, " ")
end

local function ProfessionTrainerCache(skillLineID)
    local root = ns.DB().professionTrainerCache
    local character = type(root) == "table" and root[ns.CharacterKey()]
    return type(character) == "table" and character[tostring(skillLineID)] or nil
end

local function ProfessionTrainerExpanded(skillLineID)
    local root = ns.DB().professionTrainerExpandedByCharacter
    local character = type(root) == "table" and root[ns.CharacterKey()]
    return type(character) == "table" and character[tostring(skillLineID)] == true
end

local function ToggleProfessionTrainer(skillLineID)
    local db = ns.DB()
    if type(db.professionTrainerExpandedByCharacter) ~= "table" then
        db.professionTrainerExpandedByCharacter = {}
    end
    local characterKey = ns.CharacterKey()
    if type(db.professionTrainerExpandedByCharacter[characterKey]) ~= "table" then
        db.professionTrainerExpandedByCharacter[characterKey] = {}
    end
    local character = db.professionTrainerExpandedByCharacter[characterKey]
    local cacheKey = tostring(skillLineID)
    character[cacheKey] = not ProfessionTrainerExpanded(skillLineID)
    if ns.RequestRefresh then ns.RequestRefresh("professions", "profession trainer expansion") end
end

local function CleanTrainerTooltipText(value)
    if type(value) ~= "string" or (_G.issecretvalue and _G.issecretvalue(value)) then return "" end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
end

local function TrainerTooltipText(index, serviceName)
    local parts, seen = {}, {}
    local function Add(value)
        local text = CleanTrainerTooltipText(value)
        if text ~= "" and text ~= serviceName and not seen[text] then
            parts[#parts + 1] = text
            seen[text] = true
        end
    end
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
        local ok, tooltip = pcall(C_TooltipInfo.GetTrainerService, index)
        if ok and type(tooltip) == "table" and not (_G.issecretvalue and _G.issecretvalue(tooltip)) then
            for _, line in ipairs(tooltip.lines or {}) do
                if type(line) == "table" and not (_G.issecretvalue and _G.issecretvalue(line)) then
                    Add(line.leftText)
                    Add(line.rightText)
                end
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
        end
    end
    if #parts == 0 and type(GetTrainerServiceDescription) == "function" then
        local ok, description = pcall(GetTrainerServiceDescription, index)
        description = ok and CleanTrainerTooltipText(description) or ""
        if description ~= "" then parts[1] = description end
    end
    return #parts > 0 and table.concat(parts, "\n") or nil
end

local function NormalizeProfessionName(value)
    if type(value) ~= "string" or (_G.issecretvalue and _G.issecretvalue(value)) then return nil end
    return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function MatchProfession(professions, value)
    local wanted = NormalizeProfessionName(value)
    if not wanted then return nil end
    for i = 1, #professions do
        local profession = professions[i]
        local name = NormalizeProfessionName(profession.name)
        if name and (wanted == name or wanted:find(name, 1, true)) then return profession end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

local function TrainerServiceProfession(index, serviceName, professions)
    if type(GetTrainerServiceSkillReq) == "function" then
        local ok, skillName, rank = pcall(GetTrainerServiceSkillReq, index)
        if ok then
            local profession = MatchProfession(professions, skillName)
            if profession then return profession, tonumber(rank) or 0 end
        end
    end
    if type(GetTrainerServiceSkillLine) == "function" then
        local ok, skillName = pcall(GetTrainerServiceSkillLine, index)
        if ok then
            local profession = MatchProfession(professions, skillName)
            if profession then return profession, 0 end
        end
    end
    return MatchProfession(professions, serviceName), 0
end

local function TrainerService(index, includeTooltip)
    if type(GetTrainerServiceInfo) ~= "function" then return nil end
    local ok, name, second, third = pcall(GetTrainerServiceInfo, index)
    if not ok or type(name) ~= "string" or (_G.issecretvalue and _G.issecretvalue(name)) then return nil end

    local serviceType, subText, icon
    if second == "available" or second == "unavailable" or second == "used" or second == "header" then
        serviceType, icon = second, third
    else
        subText, serviceType = second, third
        if type(GetTrainerServiceIcon) == "function" then
            local iconOK, value = pcall(GetTrainerServiceIcon, index)
            if iconOK and not (_G.issecretvalue and _G.issecretvalue(value)) then icon = value end
        end
    end
    if type(subText) ~= "string" or (_G.issecretvalue and _G.issecretvalue(subText)) then subText = nil end
    if type(icon) ~= "number" and type(icon) ~= "string" then icon = nil end

    local cost, isProfession = 0, false
    if type(GetTrainerServiceCost) == "function" then
        local costOK, value, professionService = pcall(GetTrainerServiceCost, index)
        if costOK then
            if not (_G.issecretvalue and _G.issecretvalue(value)) then cost = math.max(0, tonumber(value) or 0) end
            isProfession = professionService == true
        end
    end
    local service = {
        name = name,
        subText = subText,
        serviceType = serviceType,
        icon = icon,
        cost = cost,
        isProfession = isProfession,
        trainerIndex = index,
    }
    if includeTooltip then service.tooltipText = TrainerTooltipText(index, service.name) end
    return service
end

local PROFESSION_RANK_NAMES = { "apprentice", "journeyman", "expert", "artisan", "master" }
local function IsProfessionRankService(service, profession, stepIndex)
    if service.isProfession or service.trainerIndex == stepIndex then return true end
    local serviceName = NormalizeProfessionName(service.name) or ""
    local professionName = NormalizeProfessionName(profession.name) or ""
    if professionName == "" or not serviceName:find(professionName, 1, true) then return false end
    for i = 1, #PROFESSION_RANK_NAMES do
        if serviceName:find(PROFESSION_RANK_NAMES[i], 1, true) then return true end
    end
    return false
end

function ns.ScanProfessionTrainer()
    if not ns.Get("showProfessionTrainerRecipes") or ns.IsCombatRestricted() then return false end
    if type(IsTradeskillTrainer) ~= "function" or type(GetNumTrainerServices) ~= "function" then return false end
    local tradeOK, isTrade = pcall(IsTradeskillTrainer)
    if not tradeOK or not isTrade then return false end
    if type(GetTrainerServiceTypeFilter) == "function" then
        local filterOK, showingAvailable = pcall(GetTrainerServiceTypeFilter, "available")
        if filterOK and showingAvailable == false then return false end
    end

    local countOK, count = pcall(GetNumTrainerServices)
    if not countOK then return false end
    count = math.max(0, math.floor(tonumber(count) or 0))
    local stepIndex
    if type(GetTrainerServiceStepIndex) == "function" then
        local stepOK, value = pcall(GetTrainerServiceStepIndex)
        if stepOK then stepIndex = tonumber(value) end
    end

    local professions = ProfessionList()
    local buckets = {}
    for index = 1, count do
        local service = TrainerService(index, false)
        if service then
            local profession, requiredSkill = TrainerServiceProfession(index, service.name, professions)
            if profession and TRAINER_PROFESSIONS[profession.skillLineID] then
                local cacheKey = tostring(profession.skillLineID)
                local bucket = buckets[cacheKey]
                if not bucket then
                    bucket = { profession = profession, services = {}, total = 0 }
                    buckets[cacheKey] = bucket
                end
                if service.serviceType == "available" and not IsProfessionRankService(service, profession, stepIndex) then
                    service.requiredSkill = requiredSkill
                    service.icon = service.icon or profession.icon
                    bucket.services[#bucket.services + 1] = service
                    bucket.total = bucket.total + service.cost
                end
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if not next(buckets) then return false end

    local trainerName = UnitName and UnitName("npc")
    if type(trainerName) ~= "string" or (_G.issecretvalue and _G.issecretvalue(trainerName)) then
        trainerName = "Profession trainer"
    end
    local db = ns.DB()
    if type(db.professionTrainerCache) ~= "table" then db.professionTrainerCache = {} end
    local characterKey = ns.CharacterKey()
    if type(db.professionTrainerCache[characterKey]) ~= "table" then db.professionTrainerCache[characterKey] = {} end
    local character = db.professionTrainerCache[characterKey]
    local changed = false
    for cacheKey, bucket in pairs(buckets) do
        ns.BudgetedSort(bucket.services, function(a, b)
            if a.requiredSkill ~= b.requiredSkill then return a.requiredSkill < b.requiredSkill end
            if a.name ~= b.name then return a.name < b.name end
            return (a.cost or 0) < (b.cost or 0)
        end)
        local signatureParts = {}
        for _, service in ipairs(bucket.services) do
            signatureParts[#signatureParts + 1] = table.concat({
                service.name or "", service.subText or "", service.requiredSkill or 0,
                service.cost or 0, service.serviceType or "",
            }, "\031")
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
        local signature = table.concat(signatureParts, "\030")
        local previous = character[cacheKey]
        if not (type(previous) == "table" and previous.cacheVersion == TRAINER_CACHE_VERSION
            and previous.signature == signature and previous.rank == bucket.profession.rank) then
            for _, service in ipairs(bucket.services) do
                service.tooltipText = TrainerTooltipText(service.trainerIndex, service.name)
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
            character[cacheKey] = {
                cacheVersion = TRAINER_CACHE_VERSION,
                signature = signature,
                professionName = bucket.profession.name,
                rank = bucket.profession.rank,
                trainerName = trainerName,
                services = bucket.services,
                total = bucket.total,
                scannedAt = time and time() or 0,
            }
            changed = true
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return changed
end

local function ShowLiveTrainerTooltip(owner, service)
    if not (owner and service and service.trainerIndex and GameTooltip and GameTooltip.SetTrainerService) then return false end
    if type(IsTradeskillTrainer) ~= "function" or type(GetNumTrainerServices) ~= "function"
        or type(GetTrainerServiceInfo) ~= "function" then return false end
    local tradeOK, isTrade = pcall(IsTradeskillTrainer)
    if not tradeOK or not isTrade then return false end
    local countOK, count = pcall(GetNumTrainerServices)
    if not countOK or service.trainerIndex > (tonumber(count) or 0) then return false end
    local infoOK, currentName = pcall(GetTrainerServiceInfo, service.trainerIndex)
    if not infoOK or currentName ~= service.name then return false end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 35)
    local tooltipOK = pcall(GameTooltip.SetTrainerService, GameTooltip, service.trainerIndex)
    if not tooltipOK then return false end
    GameTooltip:Show()
    return true
end

local function RecipeBelongsToProfession(recipeID, skillLineID)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineForRecipe) then return true end
    local ok, recipeSkillLine, _, rootSkillLine = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
    if not ok then return true end
    recipeSkillLine = PublicNumber(recipeSkillLine)
    rootSkillLine = PublicNumber(rootSkillLine)
    if not recipeSkillLine and not rootSkillLine then return true end
    skillLineID = PublicNumber(skillLineID)
    return recipeSkillLine == skillLineID or rootSkillLine == skillLineID
end

function ns.ScanProfessionRecipes()
    if ns.IsCombatRestricted() or not (C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo
        and (C_TradeSkillUI.GetAllRecipeIDs or C_TradeSkillUI.GetFilteredRecipeIDs) and C_TradeSkillUI.GetRecipeInfo
        and C_TradeSkillUI.GetRecipeSchematic) then return false end
    if C_TradeSkillUI.IsTradeSkillReady then
        local ok, ready = pcall(C_TradeSkillUI.IsTradeSkillReady)
        if not ok or not ready then return false end
    end
    if C_TradeSkillUI.IsNPCCrafting then
        local ok, value = pcall(C_TradeSkillUI.IsNPCCrafting)
        if ok and value then return false end
    end

    local ok, base = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not ok or type(base) ~= "table" then return false end
    local professionName = base.parentProfessionName or base.professionName
    local reportedProfessionID = PublicNumber(base.professionID)
    local skillLineID = reportedProfessionID or PublicNumber(base.parentProfessionID or base.profession)
    local profession = FindProfession(nil, professionName) or FindProfession(skillLineID, nil)
    if not profession then return false end
    if reportedProfessionID and PublicNumber(profession.skillLineID) ~= reportedProfessionID then return false end
    skillLineID = profession.skillLineID

    local existing = RecipeCache(skillLineID, profession.name)
    if existing and existing.dirty ~= true then
        -- The recipe snapshot is already durable SavedVariables data. Opening
        -- the same profession is not evidence that its learned recipes changed.
        existing.rank = profession.rank
        return false
    end

    local recipeIDs = {}
    local gotIDs, returned
    if C_TradeSkillUI.GetAllRecipeIDs then
        gotIDs, returned = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    else
        gotIDs, returned = pcall(C_TradeSkillUI.GetFilteredRecipeIDs, recipeIDs)
    end
    if not gotIDs then return false end
    if type(returned) == "table" then recipeIDs = returned end
    if #recipeIDs == 0 then return false end

    local db = ns.DB()
    if type(db.professionRecipeCache) ~= "table" then db.professionRecipeCache = {} end
    local characterKey = ns.CharacterKey()
    if type(db.professionRecipeCache[characterKey]) ~= "table" then db.professionRecipeCache[characterKey] = {} end
    local character = db.professionRecipeCache[characterKey]
    local cacheKey = tostring(skillLineID)
    -- Every scan is a full snapshot of the open profession. Never merge it with
    -- an older cache, since stale recipes may belong to a different profession.
    local cache = { recipes = {} }

    local learnedCount = 0
    for i = 1, #recipeIDs do
        local recipeID = recipeIDs[i]
        local infoOK, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if infoOK and type(info) == "table" and info.learned
            and RecipeBelongsToProfession(recipeID, skillLineID) then
            local schematicOK, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
            if schematicOK and type(schematic) == "table" then
                local reagents = {}
                local slots = schematic.reagentSlotSchematics or {}
                for j = 1, #slots do
                    local slot = slots[j]
                    local first = slot.reagents and slot.reagents[1]
                    local basicType = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
                    local modifyingType = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Modifying
                    local regular = (not basicType) or slot.reagentType == basicType
                        or (slot.reagentType == modifyingType and slot.required)
                    local reagentID = regular and first and tonumber(first.itemID)
                    local quantity = tonumber(slot.quantityRequired) or 0
                    if reagentID and quantity > 0 then
                        reagents[#reagents + 1] = {
                            itemID = reagentID,
                            name = ItemName(reagentID),
                            quantity = quantity,
                        }
                    end
                    if ns.YieldForBudget then ns.YieldForBudget() end
                end

                local resultLink
                if C_TradeSkillUI.GetRecipeItemLink then
                    local resultOK, value = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
                    if resultOK then resultLink = value end
                end
                local resultItemID = ItemID(resultLink)
                local resultIcon
                if resultItemID and C_Item and C_Item.GetItemInfoInstant then
                    local instantOK, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, resultItemID)
                    if instantOK then resultIcon = icon end
                end
                cache.recipes[tostring(recipeID)] = {
                    recipeID = recipeID,
                    name = info.name or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(recipeID)) or ("Recipe " .. tostring(recipeID)),
                    icon = info.icon or info.iconID or resultIcon or profession.icon,
                    difficulty = DifficultyRank(info.relativeDifficulty),
                    numSkillUps = tonumber(info.numSkillUps) or 1,
                    reagents = reagents,
                    resultItemID = resultItemID,
                }
                learnedCount = learnedCount + 1
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end

    cache.professionName = profession.name
    cache.skillLineID = skillLineID
    cache.cacheVersion = RECIPE_CACHE_VERSION
    cache.rank = profession.rank
    cache.scannedAt = time and time() or 0
    cache.learnedCount = learnedCount
    cache.dirty = nil
    character[cacheKey] = cache
    return learnedCount > 0
end

local function GatheringSummary(mapID, kind)
    if kind ~= "herb" and kind ~= "ore" and kind ~= "fish" then return nil end
    local catalog = ns.GatheringCatalog
    local zoneData = catalog and catalog.zones and mapID and catalog.zones[mapID]
    local entries = zoneData and zoneData[kind]
    if type(entries) ~= "table" or #entries == 0 then return nil end
    local parts = {}
    local shown = math.min(3, #entries)
    for i = 1, shown do
        local node = entries[i]
        parts[#parts + 1] = string.format("%s (%d)", node.name, node.count)
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local more = #entries - shown
    local suffix = more > 0 and string.format(" +%d more", more) or ""
    return table.concat(parts, ", ") .. suffix .. " • known locations, most to least."
end

local function ObservedGatheringSummary(mapID, kind)
    if not ns.Get("showObservedGathering") or not ns.GetObservedGathering then return nil end
    local bucketKind = kind == "fish" and "fishing" or kind == "skin" and "skinning" or nil
    if not bucketKind then return nil end
    local bucket = ns.GetObservedGathering(mapID, bucketKind)
    if not bucket or type(bucket.items) ~= "table" or (tonumber(bucket.windows) or 0) <= 0 then return nil end
    local items = {}
    for _, item in pairs(bucket.items) do
        if type(item) == "table" and tonumber(item.itemID) then items[#items + 1] = item end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    ns.BudgetedSort(items, function(a, b)
        local aCount, bCount = tonumber(a.count) or 0, tonumber(b.count) or 0
        if aCount ~= bCount then return aCount > bCount end
        return tostring(a.name or a.itemID) < tostring(b.name or b.itemID)
    end)
    if #items == 0 then return nil end
    local parts = {}
    for index = 1, math.min(3, #items) do
        local item = items[index]
        local name = ItemName(item.itemID)
        if name:match("^Item %d+$") and item.name then name = item.name end
        parts[#parts + 1] = string.format("%s ×%d", name, tonumber(item.count) or 0)
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if #items > 3 then parts[#parts + 1] = string.format("+%d more", #items - 3) end
    local windows = tonumber(bucket.windows) or 0
    local sampleLabel = bucketKind == "fishing"
        and (windows == 1 and "catch" or "catches")
        or (windows == 1 and "skinning window" or "skinning windows")
    return {
        label = bucketKind == "fishing" and "Observed catches" or "Observed skinning materials",
        detail = string.format("%s • %d local %s recorded.", table.concat(parts, ", "), windows, sampleLabel),
        tooltip = string.format("Account-wide observations recorded by Adventure Tracker in this zone. Sample: %d %s. This history stays local and is never uploaded.",
            windows, sampleLabel),
    }
end

local function AddFishingSkillRow(rows, profession, zoneName)
    if not ns.Get("showProfessionZoneHints") or not ns.GetFishingSkillRecommendation then return end
    local target, source = ns.GetFishingSkillRecommendation(zoneName)
    if not target then
        rows[#rows + 1] = {
            key = "fishing-threshold-unknown",
            label = "Recommended Fishing skill unknown",
            detail = "No reliable no-getaway threshold has been measured for these waters yet.",
            tooltip = "Adventure Tracker leaves an unmeasured Forever fishing threshold unknown instead of borrowing a guess from an unrelated zone.",
            state = "unknown",
            icon = profession.icon,
        }
        return
    end
    local effective = (tonumber(profession.rank) or 0) + (tonumber(profession.rankBonus) or 0)
    local gap = math.max(0, target - effective)
    local sourceLabel = source == "forever" and "Forever player measurements"
        or source == "spot" and "this sub-zone's Classic baseline"
        or "Classic baseline; Forever may differ"
    rows[#rows + 1] = {
        key = "fishing-threshold",
        label = string.format("Recommended effective Fishing: %d", target),
        detail = gap > 0
            and string.format("Current effective skill %d • %d short of the no-getaway threshold.", effective, gap)
            or string.format("Current effective skill %d • meets the no-getaway threshold.", effective),
        tooltip = string.format("OneCast source: %s. Effective skill includes the profession bonus reported by the client, so pole, lure, racial and equipment bonuses can count. A future observed getaway at or above this value should overrule the estimate.", sourceLabel),
        state = gap > 0 and "warning" or "ready",
        icon = profession.icon,
    }
end

local function OpenProfession(name)
    if InCombatLockdown and InCombatLockdown() then return end
    local profession = FindProfession(nil, name)
    if profession and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        pcall(C_TradeSkillUI.OpenTradeSkill, profession.skillLineID)
    end
    if CastSpellByName then pcall(CastSpellByName, name) end
end

local function RankSource(profession, goal, mapID)
    if profession.skillLineID == 356 and profession.maxRank == 150 then
        return "Old Man Heming in Booty Bay (Expert Fishing - The Bass and You)"
    elseif profession.skillLineID == 356 and profession.maxRank == 225 then
        return "Nat Pagle in Dustwallow Marsh (Nat Pagle, Angler Extreme)"
    elseif profession.skillLineID == 164 and profession.maxRank == 225 then
        return "Brikk Keencraft in Booty Bay"
    elseif profession.skillLineID == 164 and profession.maxRank == 150
        and UnitFactionGroup and UnitFactionGroup("player") == "Alliance" and mapID == 1431 then
        return "Clarise Gnarltree in Darkshire"
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Alliance"
    local destinations = TRAINER_DESTINATIONS[profession.skillLineID]
    return destinations and destinations[faction]
        or ("a " .. profession.name .. " trainer in a capital city")
end

local function AddRankPlan(rows, profession, mapID)
    local goals = profession.skillLineID == 356 and FISHING_RANK_GOALS or RANK_GOALS
    local goal = goals[profession.maxRank]
    local source = goal and RankSource(profession, goal, mapID)
    local playerLevel = UnitLevel("player") or 0
    if goal and profession.rank >= goal.skill and playerLevel >= goal.level then
        if ns.Get("showProfessionCaps") then
            rows[#rows + 1] = {
                key = "rank-ready-" .. tostring(profession.skillLineID),
                label = string.format("Train %s %s", goal.name, profession.name),
                detail = string.format("Available now from %s • raises the cap to %d.", source, goal.nextCap),
                state = "missing",
                icon = profession.icon,
                onClick = function() OpenProfession(profession.name) end,
            }
        end
    elseif goal and ns.Get("showProfessionProgress") then
        local remaining = math.max(0, goal.skill - profession.rank)
        local levelNeeded = math.max(0, goal.level - playerLevel)
        local label
        if remaining > 0 then
            label = string.format("Learn %s %s in %d point%s", goal.name, profession.name, remaining, remaining == 1 and "" or "s")
        else
            label = string.format("Reach level %d for %s %s", goal.level, goal.name, profession.name)
        end
        rows[#rows + 1] = {
            key = "rank-goal-" .. tostring(profession.skillLineID),
            label = label,
            detail = levelNeeded > 0
                and string.format("Requires level %d and %d skill; learn it from %s.", goal.level, goal.skill, source)
                or string.format("At %d skill, learn it from %s.", goal.skill, source),
            state = (remaining <= 10 or remaining == 0) and "warning" or "info",
            icon = profession.icon,
            onClick = function() OpenProfession(profession.name) end,
        }
    elseif not goal and ns.Get("showCompletedProfessions") then
        rows[#rows + 1] = {
            key = "rank-complete-" .. tostring(profession.skillLineID),
            label = string.format("%s %d/%d", profession.name, profession.rank, profession.maxRank),
            detail = "Final profession rank reached.",
            state = "ready",
            icon = profession.icon,
        }
    end
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

local function HumanList(values)
    if #values == 0 then return "" end
    if #values == 1 then return values[1] end
    if #values == 2 then return values[1] .. " and " .. values[2] end
    return table.concat(values, ", ", 1, #values - 1) .. ", and " .. values[#values]
end

local function ZoneOreKeys(mapID)
    local keys = {}
    local catalog = ns.GatheringCatalog
    local entries = catalog and catalog.zones and mapID and catalog.zones[mapID]
    entries = entries and entries.ore
    if type(entries) == "table" then
        for i = 1, #entries do
            keys[entries[i].key] = true
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    return keys
end

function ns.GetMiningMaterialPlan(itemID, mapID, need)
    local source = MINING_MATERIALS[tonumber(itemID)]
    if not source then return nil end
    local zoneKeys = ZoneOreKeys(mapID)
    local available, names = 0, {}
    for index = 1, #source.nodes do
        local key = source.nodes[index]
        if zoneKeys[key] then
            available = available + 1
            names[#names + 1] = NODE_NAMES[key] or source.names[index]
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local localSource = source.requiresAll and available == #source.nodes or not source.requiresAll and available > 0
    if not localSource then names = source.names end
    local material = ItemName(itemID)
    local nodes = HumanList(names)
    local label
    if source.action == "mine" then
        label = string.format("Mine %dx %s from %s", need, material, nodes)
    elseif source.action == "smelt" then
        label = string.format("Farm %s for %dx %s", nodes, need, material)
    else
        label = string.format("Farm %s for %dx %s", nodes, need, material)
    end
    return {
        label = label,
        detail = source.action == "smelt" and (label .. ", then smelt it.") or label,
        kind = "profession",
        localSource = localSource,
        names = nodes,
    }
end

local function MaterialFacts(recipe, hasMining, mapID)
    local total, missing = 0, 0
    local materialLines, missingNames, otherNeeds = {}, {}, {}
    local nodeNames, nodeSeen, preparation = {}, {}, {}
    local localNodes, miningNodes = 0, 0
    local marketCost, pricedMissing, unpricedMissing = 0, 0, 0
    local priceProvider, priceBasis
    local zoneKeys = ZoneOreKeys(mapID)

    for i = 1, #(recipe.reagents or {}) do
        local reagent = recipe.reagents[i]
        local reagentName = ItemName(reagent.itemID)
        if reagentName:match("^Item %d+$") then reagentName = reagent.name end
        local owned = GetItemCount(reagent.itemID)
        local need = math.max(0, reagent.quantity - owned)
        total = total + reagent.quantity
        missing = missing + need
        materialLines[#materialLines + 1] = string.format("%dx %s (have %d)", reagent.quantity, reagentName, owned)
        if need > 0 then
            missingNames[#missingNames + 1] = string.format("%dx %s", need, reagentName)
            if ns.GetMarketPrice then
                local unitPrice, provider, basis = ns.GetMarketPrice(reagent.itemID)
                if unitPrice then
                    marketCost = marketCost + unitPrice * need
                    pricedMissing = pricedMissing + 1
                    priceProvider = priceProvider or provider
                    priceBasis = priceBasis or basis
                else
                    unpricedMissing = unpricedMissing + 1
                end
            end
        end

        local source = hasMining and MINING_MATERIALS[reagent.itemID]
        if source then
            local sourceLocal = false
            local availableNodes = 0
            local sourceNodeNames = {}
            for j = 1, #source.nodes do
                if zoneKeys[source.nodes[j]] then
                    availableNodes = availableNodes + 1
                    local name = NODE_NAMES[source.nodes[j]] or source.names[1]
                    if name then sourceNodeNames[#sourceNodeNames + 1] = name end
                end
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
            sourceLocal = (source.requiresAll and availableNodes == #source.nodes)
                or (not source.requiresAll and availableNodes > 0)
            if source.requiresAll then
                miningNodes = miningNodes + 1
                if sourceLocal then localNodes = localNodes + 1 end
            else
                miningNodes = miningNodes + #source.nodes
                localNodes = localNodes + availableNodes
            end
            if sourceLocal then
                for j = 1, #sourceNodeNames do
                    local name = sourceNodeNames[j]
                    if not nodeSeen[name] then
                        nodeSeen[name] = true
                        nodeNames[#nodeNames + 1] = name
                    end
                    if ns.YieldForBudget then ns.YieldForBudget() end
                end
            end
            if need > 0 and sourceLocal then
                local verb = source.action == "smelt" and "smelt" or "gather"
                preparation[#preparation + 1] = string.format("%s %dx %s", verb, need, reagentName)
            elseif sourceLocal and #preparation == 0 then
                preparation[#preparation + 1] = "stock up on " .. reagentName
            end
            if need > 0 and not sourceLocal then otherNeeds[#otherNeeds + 1] = string.format("%dx %s", need, reagentName) end
        elseif need > 0 then
            otherNeeds[#otherNeeds + 1] = string.format("%dx %s", need, reagentName)
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end

    local craftable = missing == 0
    local difficultyNames = { [4] = "orange", [3] = "yellow", [2] = "green", [1] = "gray" }
    local difficulty = difficultyNames[recipe.difficulty] or "eligible"
    local detail
    if craftable then
        detail = string.format("Craft now for a %s skill-up", difficulty)
        if #nodeNames > 0 then detail = detail .. "; farm " .. HumanList(nodeNames) .. " for the next one" end
        detail = detail .. "."
    elseif #nodeNames > 0 then
        detail = "Farm " .. HumanList(nodeNames)
        if #preparation > 0 then detail = detail .. "; " .. HumanList(preparation) end
        if #otherNeeds > 0 then detail = detail .. "; also get " .. HumanList(otherNeeds) end
        detail = detail .. "; then craft " .. recipe.name .. "."
    else
        detail = "Gather " .. HumanList(missingNames) .. "; then craft " .. recipe.name .. "."
    end

    local difficultyTitle = difficulty:sub(1, 1):upper() .. difficulty:sub(2)
    local tooltip = string.format("%s skill-up recipe. Materials: %s.", difficultyTitle, table.concat(materialLines, "; "))
    if #nodeNames > 0 then tooltip = tooltip .. " Mining synergy: farm " .. HumanList(nodeNames) .. "." end
    if pricedMissing > 0 and ns.FormatMarketPrice then
        tooltip = tooltip .. string.format(" Estimated missing-material cost: %s via %s%s.",
            ns.FormatMarketPrice(marketCost), priceProvider or "installed price addon",
            priceBasis and (" " .. priceBasis) or "")
        if unpricedMissing > 0 then
            tooltip = tooltip .. string.format(" %d missing reagent%s had no price.",
                unpricedMissing, unpricedMissing == 1 and "" or "s")
        end
    end
    local localScore = miningNodes > 0 and (localNodes / miningNodes) or 0
    return {
        craftable = craftable,
        missing = missing,
        total = total,
        detail = detail,
        tooltip = tooltip,
        localScore = localScore,
        marketCost = pricedMissing > 0 and marketCost or nil,
        marketCoverage = pricedMissing,
        marketProvider = priceProvider,
    }
end

local function HasProfession(professions, skillLineID)
    for i = 1, #professions do
        if professions[i].skillLineID == skillLineID then return true end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return false
end

local function BestSkillUpRecipe(profession, professions, mapID)
    local cache = RecipeCache(profession.skillLineID, profession.name)
    if not cache or type(cache.recipes) ~= "table" then return nil end
    if cache.rank ~= profession.rank then return nil end
    local hasMining = HasProfession(professions, 186)
    local best, bestFacts, bestScore
    for _, recipe in pairs(cache.recipes) do
        if type(recipe) == "table" and (recipe.difficulty or 0) >= 2 and type(recipe.reagents) == "table" and #recipe.reagents > 0 then
            local facts = MaterialFacts(recipe, hasMining, mapID)
            local costPenalty = facts.marketCost and math.min(2500, facts.marketCost / 1000) or 0
            local score = (facts.craftable and 100000 or 0)
                + (recipe.difficulty or 0) * 10000 + facts.localScore * 1000
                - facts.missing * 10 - facts.total - costPenalty
            if not bestScore or score > bestScore then
                best, bestFacts, bestScore = recipe, facts, score
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return best, bestFacts
end

local function ItemInfo(itemID, requestMissing)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return nil end
    local ok, name, link, _, itemLevel, requiredLevel, _, _, _, equipLoc, icon, _, classID, subClassID = pcall(getInfo, itemID)
    if not ok or not name then
        if requestMissing ~= false and ns.RequestItemData then ns.RequestItemData(itemID, "professions") end
        return nil
    end
    return {
        name = name, link = link, itemLevel = tonumber(itemLevel) or 0,
        requiredLevel = tonumber(requiredLevel) or 0, equipLoc = equipLoc,
        icon = icon, classID = classID, subClassID = subClassID,
    }
end

local function EquippedItemLevel(equipLoc)
    local slots = EQUIPMENT_SLOTS[equipLoc]
    if not slots then return nil end
    local lowest
    for i = 1, #slots do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slots[i])
        local level = 0
        if link then
            if C_Item and C_Item.GetDetailedItemLevelInfo then
                local ok, value = pcall(C_Item.GetDetailedItemLevelInfo, link)
                if ok and type(value) == "number" then level = value end
            end
            if level == 0 and GetDetailedItemLevelInfo then
                local ok, value = pcall(GetDetailedItemLevelInfo, link)
                if ok and type(value) == "number" then level = value end
            end
        end
        if lowest == nil or level < lowest then lowest = level end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return lowest
end

local function CharacterBuildName()
    local _, className = UnitClass("player")
    local specialization = GetSpecialization and GetSpecialization()
    if specialization and GetSpecializationInfo then
        local ok, _, specName = pcall(GetSpecializationInfo, specialization)
        if ok and specName then return specName .. " " .. (className or "") end
    end
    return className or "your class"
end

local function SpecPreference(equipLoc)
    if not (GetSpecialization and GetSpecializationInfo) then return 0 end
    local specialization = GetSpecialization()
    if not specialization then return 0 end
    local ok, specID = pcall(GetSpecializationInfo, specialization)
    if not ok then return 0 end
    if (specID == 66 or specID == 65 or specID == 73) and equipLoc == "INVTYPE_SHIELD" then return 400 end
    if (specID == 66 or specID == 73) and (equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND") then return 250 end
    if (specID == 70 or specID == 71) and equipLoc == "INVTYPE_2HWEAPON" then return 400 end
    return 0
end

local function SpecAllows(equipLoc)
    if not (GetSpecialization and GetSpecializationInfo) then return true end
    local specialization = GetSpecialization()
    if not specialization then return true end
    local ok, specID = pcall(GetSpecializationInfo, specialization)
    if not ok then return true end
    if specID == 70 or specID == 71 then
        return equipLoc ~= "INVTYPE_SHIELD" and equipLoc ~= "INVTYPE_WEAPONOFFHAND"
            and equipLoc ~= "INVTYPE_WEAPON" and equipLoc ~= "INVTYPE_WEAPONMAINHAND"
    elseif specID == 65 or specID == 66 or specID == 73 then
        return equipLoc ~= "INVTYPE_2HWEAPON"
    end
    return true
end

local function IsUsableEquippable(itemID, item)
    if not item.equipLoc or item.equipLoc == "" or not EQUIPMENT_SLOTS[item.equipLoc] then return false end
    if not SpecAllows(item.equipLoc) then return false end
    if item.requiredLevel > (UnitLevel("player") or 0) then return false end
    if IsUsableItem then
        local ok, usable = pcall(IsUsableItem, itemID)
        if ok and not usable then return false end
    end
    return true
end

function ns.GetCraftedItemUpgrade(itemID)
    -- The worldwide catalogue can contain hundreds of plausible products. It
    -- must not turn a cold item cache into a bulk asynchronous load. Cached
    -- products are still scored; ordinary client use will populate more.
    local item = ItemInfo(itemID, false)
    if not item or not IsUsableEquippable(itemID, item) then return nil end
    local equippedLevel = EquippedItemLevel(item.equipLoc)
    if equippedLevel == nil then return nil end
    return item, item.itemLevel - equippedLevel, SLOT_LABELS[item.equipLoc] or "gear", equippedLevel
end

local function BestGearRecipe(profession, professions, mapID)
    local cache = RecipeCache(profession.skillLineID, profession.name)
    if not cache or type(cache.recipes) ~= "table" then return nil end
    local hasMining = HasProfession(professions, 186)
    local best, bestItem, bestFacts, bestDelta, bestScore
    for _, recipe in pairs(cache.recipes) do
        if recipe.resultItemID then
            local item = ItemInfo(recipe.resultItemID)
            if item and IsUsableEquippable(recipe.resultItemID, item) then
                local equippedLevel = EquippedItemLevel(item.equipLoc)
                if equippedLevel ~= nil then
                    local delta = item.itemLevel - equippedLevel
                    local facts = MaterialFacts(recipe, hasMining, mapID)
                    local costPenalty = facts.marketCost and math.min(1000, facts.marketCost / 1000) or 0
                    local score = (delta > 0 and 100000 or 0) + delta * 1000 + item.itemLevel * 10
                        + (facts.craftable and 500 or 0) + SpecPreference(item.equipLoc) - costPenalty
                    if not bestScore or score > bestScore then
                        best, bestItem, bestFacts, bestDelta, bestScore = recipe, item, facts, delta, score
                    end
                end
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return best, bestItem, bestFacts, bestDelta
end

local function AddRecipePlan(rows, profession, professions, mapID, reuseSelected)
    if ns.AddProfessionRouteRow then
        return ns.AddProfessionRouteRow(rows, profession, professions, mapID,
            ns.GetZoneName and ns.GetZoneName(), reuseSelected)
    end
    local recipe, facts = BestSkillUpRecipe(profession, professions, mapID)
    if recipe then
        rows[#rows + 1] = {
            key = "skillup-recipe-" .. tostring(profession.skillLineID),
            label = "Next skill-up: " .. recipe.name,
            detail = facts.detail,
            tooltip = facts.tooltip,
            state = facts.craftable and "ready" or "info",
            icon = recipe.icon or profession.icon,
            onClick = function() OpenProfession(profession.name) end,
        }
        return true
    end
    return false
end

local function AddGearPlan(rows, profession, professions, mapID)
    local recipe, item, facts, delta = BestGearRecipe(profession, professions, mapID)
    if not recipe then return false end
    local buildName = CharacterBuildName()
    local slotName = SLOT_LABELS[item.equipLoc] or "gear"
    local label, detail
    if delta > 0 then
        label = "Crafted upgrade: " .. item.name
        detail = string.format("+%d item level%s for %s • %s.", delta, delta == 1 and "" or "s", slotName, facts.craftable and "craftable now" or "materials needed")
    else
        label = "Useful craft: " .. item.name
        detail = string.format("Best learned %s craft for %s • item level %d.", slotName, buildName, item.itemLevel)
    end
    rows[#rows + 1] = {
        key = "gear-recipe-" .. tostring(profession.skillLineID),
        label = label,
        detail = detail,
        tooltip = string.format("%s recipe for %s. %s", profession.name, buildName, facts.tooltip),
        state = delta > 0 and (facts.craftable and "ready" or "warning") or "info",
        icon = item.icon or recipe.icon or profession.icon,
        onClick = function() OpenProfession(profession.name) end,
    }
    return true
end

local function PermanentTrainerServices(profession)
    local services = {}
    local liveByName = {}
    local liveCache = ProfessionTrainerCache(profession.skillLineID)
    for _, live in ipairs(type(liveCache) == "table" and liveCache.services or {}) do
        local key = NormalizeProfessionName(live.name)
        if key then liveByName[key] = live end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    for _, fact in ipairs(ns.GetPermanentProfessionTraining
        and ns.GetPermanentProfessionTraining(profession.skillLineID) or {}) do
        local trainer = fact.source and fact.source:find("trainer", 1, true)
        local known = ns.IsProfessionRecipeKnown and ns.IsProfessionRecipeKnown(fact.spellID, profession)
        if trainer and not fact.rank and fact.productID > 0 and fact.learnAt <= profession.rank
            and (fact.level <= 0 or fact.level <= playerLevel) and not known then
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(fact.spellID)
                or ItemName(fact.productID)
            local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(fact.productID)
            local liveKey = NormalizeProfessionName(name)
            local live = liveKey and liveByName[liveKey]
            services[#services + 1] = {
                spellID = fact.spellID,
                name = name,
                icon = live and live.icon or icon or profession.icon,
                cost = live and live.cost or fact.cost,
                requiredSkill = fact.learnAt,
                tooltipText = live and live.tooltipText or string.format(
                    "Available from a %s trainer at %d skill. Permanent catalog cost: %s.",
                    profession.name, fact.learnAt, FormatMoney(fact.cost)),
            }
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    ns.BudgetedSort(services, function(a, b)
        if a.requiredSkill ~= b.requiredSkill then return a.requiredSkill < b.requiredSkill end
        return a.name < b.name
    end)
    return services
end

local function AddTrainerRecipeRows(rows, profession)
    if not ns.Get("showProfessionTrainerRecipes") then return end
    local services = PermanentTrainerServices(profession)
    if #services == 0 then return end

    local total = 0
    for index = 1, #services do
        total = total + (tonumber(services[index].cost) or 0)
        if ns.YieldForBudget then ns.YieldForBudget() end
    end

    local expanded = ProfessionTrainerExpanded(profession.skillLineID)
    rows[#rows + 1] = {
        key = "trainer-recipes-total-" .. tostring(profession.skillLineID),
        label = string.format("%s %d trainer recipe%s available",
            expanded and "−" or "+", #services, #services == 1 and "" or "s"),
        detail = string.format("Total training cost: %s", FormatMoney(total)),
        tooltip = string.format("Permanent WoW Forever trainer catalog at %d %s skill. Learn every listed recipe for %s. %s",
            profession.rank, profession.name, FormatMoney(total),
            expanded and "Collapse the individual recipe list." or "Expand the individual recipe list."),
        clickHint = expanded and "Click to collapse trainer recipes." or "Click to expand trainer recipes.",
        onClick = function() ToggleProfessionTrainer(profession.skillLineID) end,
        state = "warning",
        icon = profession.icon,
    }
    if not expanded then return end

    for index = 1, #services do
        local service = services[index]
        local label = service.name or "Unknown recipe"
        if service.subText and service.subText ~= "" then label = string.format("%s (%s)", label, service.subText) end
        rows[#rows + 1] = {
            key = string.format("trainer-recipe-%s-%d", tostring(profession.skillLineID), index),
            label = label,
            detail = "Cost: " .. FormatMoney(service.cost),
            tooltip = service.tooltipText,
            spellID = service.spellID,
            state = "warning",
            icon = service.icon or profession.icon,
            indentLevel = 1,
        }
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

local stableProfessionRows = {}

local function AppendRows(target, source)
    for index = 1, #(source or {}) do
        target[#target + 1] = source[index]
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

local function BuildStableProfessionRows(profession, professions, mapID, zoneName)
    local beforeRoute, afterRoute = {}, {}
    if CRAFTING_PROFESSIONS[profession.skillLineID] then
        AddRankPlan(beforeRoute, profession, mapID)
        if ns.Get("showProfessionGear") then AddGearPlan(afterRoute, profession, professions, mapID) end
    elseif GATHERING_KINDS[profession.skillLineID] then
        AddRankPlan(beforeRoute, profession, mapID)
    end

    if TRAINER_PROFESSIONS[profession.skillLineID] then AddTrainerRecipeRows(afterRoute, profession) end
    if ns.AddRecipeCatalogRows then ns.AddRecipeCatalogRows(afterRoute, profession, professions, mapID) end
    if profession.skillLineID == 356 then AddFishingSkillRow(afterRoute, profession, zoneName) end

    if ns.Get("showProfessionZoneHints") and GATHERING_HINTS[profession.skillLineID] then
        local kind = GATHERING_KINDS[profession.skillLineID]
        local summary = GatheringSummary(mapID, kind)
        afterRoute[#afterRoute + 1] = {
            key = "local-" .. tostring(profession.skillLineID),
            label = summary and "Available here" or "Local opportunities",
            detail = summary or GATHERING_HINTS[profession.skillLineID],
            state = "info",
            icon = profession.icon,
        }
        local observed = ObservedGatheringSummary(mapID, kind)
        if observed then
            observed.key = "observed-" .. tostring(profession.skillLineID)
            observed.state = "info"
            observed.icon = profession.icon
            afterRoute[#afterRoute + 1] = observed
        end
    end
    return { beforeRoute = beforeRoute, afterRoute = afterRoute }
end

local function BuildProfessionRows(profession, professions, mapID, zoneName, inventoryOnly)
    local cacheKey = tostring(profession.skillLineID)
    local stable = stableProfessionRows[cacheKey]
    if not stable then
        stable = BuildStableProfessionRows(profession, professions, mapID, zoneName)
        stableProfessionRows[cacheKey] = stable
    end
    local rows = {}
    AppendRows(rows, stable.beforeRoute)
    if CRAFTING_PROFESSIONS[profession.skillLineID] and ns.Get("showProfessionSynergy") then
        AddRecipePlan(rows, profession, professions, mapID, inventoryOnly)
    end
    AppendRows(rows, stable.afterRoute)
    return rows
end

local function Build(invalidationReason)
    local inventoryOnly = invalidationReason == "BAG_UPDATE_DELAYED"
    if ns.BeginProfessionRouteBuild then ns.BeginProfessionRouteBuild(inventoryOnly) end
    if not inventoryOnly then
        stableProfessionRows = {}
        if ns.ResetProfessionRouteSelections then ns.ResetProfessionRouteSelections() end
    end
    if not ns.Get("showProfessions") then
        if ns.FinalizeProfessionRouteBuild then ns.FinalizeProfessionRouteBuild() end
        return {}
    end
    local professions = ProfessionList()
    local zoneName, mapID = ns.GetZoneName()
    local sections = {}
    for i = 1, #professions do
        local profession = professions[i]
        if CRAFTING_PROFESSIONS[profession.skillLineID] or GATHERING_KINDS[profession.skillLineID]
            or TRAINER_PROFESSIONS[profession.skillLineID] then
            local rows = BuildProfessionRows(profession, professions, mapID, zoneName, inventoryOnly)
            if #rows > 0 then
                sections[#sections + 1] = {
                    id = "profession-" .. tostring(profession.skillLineID),
                    title = string.format("%s %d/%d", profession.name, profession.rank, profession.maxRank),
                    rows = rows,
                }
            end
        end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    if ns.FinalizeProfessionRouteBuild then ns.FinalizeProfessionRouteBuild() end
    return sections
end

ns.RegisterProvider("professions", 30, Build)

function ns.OnProfessionProviderCommitted()
    if ns.CommitProfessionRouteBuild then ns.CommitProfessionRouteBuild() end
end

function ns.OnProfessionProviderDiscarded()
    if ns.DiscardProfessionRouteBuild then ns.DiscardProfessionRouteBuild() end
end
