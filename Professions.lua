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
local RECIPE_CACHE_VERSION = 2

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
            local valid, name, icon, rank, maxRank, _, _, skillLineID = pcall(GetProfessionInfo, index)
            if valid and name then
                result[#result + 1] = {
                    name = name,
                    icon = icon,
                    rank = tonumber(rank) or 0,
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
    if ns.RequestRefresh then ns.RequestRefresh() end
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

local function TrainerService(index)
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
    return {
        name = name,
        subText = subText,
        serviceType = serviceType,
        icon = icon,
        cost = cost,
        isProfession = isProfession,
        trainerIndex = index,
    }
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
        local service = TrainerService(index)
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
                    service.tooltipText = TrainerTooltipText(index, service.name)
                    bucket.services[#bucket.services + 1] = service
                    bucket.total = bucket.total + service.cost
                end
            end
        end
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
    for cacheKey, bucket in pairs(buckets) do
        character[cacheKey] = {
            professionName = bucket.profession.name,
            rank = bucket.profession.rank,
            trainerName = trainerName,
            services = bucket.services,
            total = bucket.total,
        }
    end
    return true
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
        and C_TradeSkillUI.GetFilteredRecipeIDs and C_TradeSkillUI.GetRecipeInfo
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

    local recipeIDs = {}
    local gotIDs, returned = pcall(C_TradeSkillUI.GetFilteredRecipeIDs, recipeIDs)
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
    end

    cache.professionName = profession.name
    cache.skillLineID = skillLineID
    cache.cacheVersion = RECIPE_CACHE_VERSION
    cache.rank = profession.rank
    cache.scannedAt = time and time() or 0
    cache.learnedCount = learnedCount
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
    end
    local more = #entries - shown
    local suffix = more > 0 and string.format(" +%d more", more) or ""
    return table.concat(parts, ", ") .. suffix .. " • known locations, most to least."
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
        for i = 1, #entries do keys[entries[i].key] = true end
    end
    return keys
end

local function MaterialFacts(recipe, hasMining, mapID)
    local total, missing = 0, 0
    local materialLines, missingNames, otherNeeds = {}, {}, {}
    local nodeNames, nodeSeen, preparation = {}, {}, {}
    local localNodes, miningNodes = 0, 0
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
        if need > 0 then missingNames[#missingNames + 1] = string.format("%dx %s", need, reagentName) end

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
    local localScore = miningNodes > 0 and (localNodes / miningNodes) or 0
    return {
        craftable = craftable,
        missing = missing,
        total = total,
        detail = detail,
        tooltip = tooltip,
        localScore = localScore,
    }
end

local function HasProfession(professions, skillLineID)
    for i = 1, #professions do
        if professions[i].skillLineID == skillLineID then return true end
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
            local score = (facts.craftable and 100000 or 0)
                + (recipe.difficulty or 0) * 10000 + facts.localScore * 1000
                - facts.missing * 10 - facts.total
            if not bestScore or score > bestScore then
                best, bestFacts, bestScore = recipe, facts, score
            end
        end
    end
    return best, bestFacts
end

local function ItemInfo(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return nil end
    local ok, name, link, _, itemLevel, requiredLevel, _, _, _, equipLoc, icon, _, classID, subClassID = pcall(getInfo, itemID)
    if not ok or not name then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
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
                    local score = (delta > 0 and 100000 or 0) + delta * 1000 + item.itemLevel * 10
                        + (facts.craftable and 500 or 0) + SpecPreference(item.equipLoc)
                    if not bestScore or score > bestScore then
                        best, bestItem, bestFacts, bestDelta, bestScore = recipe, item, facts, delta, score
                    end
                end
            end
        end
    end
    return best, bestItem, bestFacts, bestDelta
end

local function AddRecipePlan(rows, profession, professions, mapID)
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

local function AddScanPrompt(rows, profession, stale)
    rows[#rows + 1] = {
        key = "scan-profession-" .. tostring(profession.skillLineID),
        label = (stale and "Refresh " or "Open ") .. profession.name .. " recipes",
        detail = stale
            and "Open the profession once to update skill-up difficulty and material advice."
            or "Open the profession once so Adventure Tracker can evaluate learned recipes.",
        state = "info",
        icon = profession.icon,
        onClick = function() OpenProfession(profession.name) end,
    }
end

local function AddTrainerRecipeRows(rows, profession)
    if not ns.Get("showProfessionTrainerRecipes") then return end
    local cache = ProfessionTrainerCache(profession.skillLineID)
    if not cache then
        rows[#rows + 1] = {
            key = "trainer-recipes-scan-" .. tostring(profession.skillLineID),
            label = "Trainer recipes not scanned",
            detail = string.format("Visit a %s trainer once to load available recipes and prices.", profession.name),
            state = "info",
            icon = profession.icon,
        }
        return
    end

    local services = type(cache.services) == "table" and cache.services or {}
    local stale = (tonumber(cache.rank) or 0) ~= profession.rank
    if #services == 0 then return end

    local expanded = ProfessionTrainerExpanded(profession.skillLineID)
    rows[#rows + 1] = {
        key = "trainer-recipes-total-" .. tostring(profession.skillLineID),
        label = string.format("%s %d trainer recipe%s available",
            expanded and "−" or "+", #services, #services == 1 and "" or "s"),
        detail = string.format("Total training cost: %s%s", FormatMoney(cache.total),
            stale and " • rescan after gaining skill" or ""),
        tooltip = string.format("Last scanned from %s at %d %s. Learn every listed recipe for %s. %s%s",
            cache.trainerName or "a profession trainer", tonumber(cache.rank) or 0, profession.name,
            FormatMoney(cache.total), stale and "Visit a trainer to include newly available recipes. " or "",
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
            tooltip = service.tooltipText or string.format("Unlearned recipe available from %s.",
                cache.trainerName or "your profession trainer"),
            tooltipFunc = function(owner) return ShowLiveTrainerTooltip(owner, service) end,
            state = "warning",
            icon = service.icon or profession.icon,
            indentLevel = 1,
        }
    end
end

local function BuildProfessionRows(profession, professions, mapID)
    local rows = {}
    if CRAFTING_PROFESSIONS[profession.skillLineID] then
        AddRankPlan(rows, profession, mapID)
        local cache = RecipeCache(profession.skillLineID, profession.name)
        local addedRecipe = false
        if ns.Get("showProfessionSynergy") then
            addedRecipe = AddRecipePlan(rows, profession, professions, mapID)
        end
        if ns.Get("showProfessionGear") then AddGearPlan(rows, profession, professions, mapID) end
        if (ns.Get("showProfessionSynergy") or ns.Get("showProfessionGear")) and not cache then
            AddScanPrompt(rows, profession, false)
        elseif ns.Get("showProfessionSynergy") and cache and cache.rank ~= profession.rank and not addedRecipe then
            AddScanPrompt(rows, profession, true)
        end
    elseif GATHERING_KINDS[profession.skillLineID] then
        AddRankPlan(rows, profession, mapID)
    end

    if TRAINER_PROFESSIONS[profession.skillLineID] then AddTrainerRecipeRows(rows, profession) end

    if ns.Get("showProfessionZoneHints") and GATHERING_HINTS[profession.skillLineID] then
        local kind = GATHERING_KINDS[profession.skillLineID]
        local summary = GatheringSummary(mapID, kind)
        rows[#rows + 1] = {
            key = "local-" .. tostring(profession.skillLineID),
            label = summary and "Available here" or "Local opportunities",
            detail = summary or GATHERING_HINTS[profession.skillLineID],
            state = "info",
            icon = profession.icon,
        }
    end
    return rows
end

local function Build()
    if not ns.Get("showProfessions") then return {} end
    local professions = ProfessionList()
    local _, mapID = ns.GetZoneName()
    local sections = {}
    for i = 1, #professions do
        local profession = professions[i]
        if CRAFTING_PROFESSIONS[profession.skillLineID] or GATHERING_KINDS[profession.skillLineID]
            or TRAINER_PROFESSIONS[profession.skillLineID] then
            local rows = BuildProfessionRows(profession, professions, mapID)
            if #rows > 0 then
                sections[#sections + 1] = {
                    id = "profession-" .. tostring(profession.skillLineID),
                    title = string.format("%s %d/%d", profession.name, profession.rank, profession.maxRank),
                    rows = rows,
                }
            end
        end
    end
    return sections
end

ns.RegisterProvider("professions", 30, Build)
