-------------------------------------------------------------------------------
-- Adventure Tracker: character reminders that replace hidden microbar alerts.
-------------------------------------------------------------------------------
local _, ns = ...

local function IsSecret(value)
    return _G.issecretvalue and _G.issecretvalue(value)
end

local function UnspentTalents()
    if not (C_SpecializationInfo and C_SpecializationInfo.CanPlayerUseTalentUI
        and C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints) then
        return false, 0
    end
    local ok, available = pcall(C_SpecializationInfo.CanPlayerUseTalentUI)
    if not ok or IsSecret(available) or not available then return false, 0 end
    local normalOK, normal, classPoints, specPoints = pcall(C_ClassTalents.HasUnspentTalentPoints)
    local heroOK, hero, heroPoints = true, false, 0
    if C_ClassTalents.HasUnspentHeroTalentPoints then
        heroOK, hero, heroPoints = pcall(C_ClassTalents.HasUnspentHeroTalentPoints)
    end
    if not normalOK or not heroOK or IsSecret(normal) or IsSecret(hero)
        or IsSecret(classPoints) or IsSecret(specPoints) or IsSecret(heroPoints) then
        return false, 0
    end
    classPoints = tonumber(classPoints) or 0
    specPoints = tonumber(specPoints) or 0
    heroPoints = tonumber(heroPoints) or 0
    return normal == true or hero == true, classPoints + specPoints + heroPoints
end

local function OpenTalents()
    if InCombatLockdown and InCombatLockdown() then return end
    if not PlayerSpellsUtil and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
    end
    if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then
        PlayerSpellsUtil.ToggleClassTalentFrame()
    elseif ToggleTalentFrame then
        ToggleTalentFrame()
    end
end

local function TalentIcon()
    local button = _G.PlayerSpellsMicroButton or _G.TalentMicroButton
    local texture = button and button.GetNormalTexture and button:GetNormalTexture()
    local file = texture and texture.GetTexture and texture:GetTexture()
    return file or 136243
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
    if copper > 0 or (#parts == 0) then parts[#parts + 1] = string.format("%dc", copper) end
    return table.concat(parts, " ")
end

local function TrainerCache()
    local all = ns.DB().classTrainerByCharacter
    if type(all) ~= "table" then return nil end
    return all[ns.CharacterKey()]
end

local StaticTrainerServices, MarkCatalogSeen
local staticServiceCache

local function TrainerSkillsExpanded()
    local all = ns.DB().classTrainerExpandedByCharacter
    return type(all) == "table" and all[ns.CharacterKey()] == true
end

local function ToggleTrainerSkills()
    local db = ns.DB()
    if type(db.classTrainerExpandedByCharacter) ~= "table" then
        db.classTrainerExpandedByCharacter = {}
    end
    local key = ns.CharacterKey()
    local expanding = not TrainerSkillsExpanded()
    db.classTrainerExpandedByCharacter[key] = expanding
    if expanding then
        if MarkCatalogSeen then MarkCatalogSeen() end
        local cache = TrainerCache()
        if cache then
            cache.newServiceKeys = nil
            cache.newServiceCount = 0
        end
        staticServiceCache = nil
    end
    if ns.RequestRefresh then ns.RequestRefresh("character-reminders", "class trainer expansion") end
end

local function CleanTrainerTooltipText(value)
    if type(value) ~= "string" or IsSecret(value) then return "" end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
end

local function TrainerTooltipText(index, serviceName, serviceCost)
    local parts, seen = {}, {}
    local costTexts = {}
    local function RememberCostText(value)
        local text = CleanTrainerTooltipText(value)
        if text ~= "" then costTexts[text] = true end
    end
    if (tonumber(serviceCost) or 0) > 0 then
        if type(GetCoinTextureString) == "function" then
            local ok, value = pcall(GetCoinTextureString, serviceCost)
            if ok then RememberCostText(value) end
        end
        if type(GetMoneyString) == "function" then
            local ok, value = pcall(GetMoneyString, serviceCost)
            if ok then RememberCostText(value) end
            ok, value = pcall(GetMoneyString, serviceCost, true)
            if ok then RememberCostText(value) end
        end
    end
    local function Add(value)
        local text = CleanTrainerTooltipText(value)
        if text ~= "" and text ~= serviceName and not costTexts[text] and not seen[text] then
            parts[#parts + 1] = text
            seen[text] = true
        end
    end

    -- This is the actual trainer-provided ability description. Cache it first
    -- so leaving the trainer does not reduce the hover to the price line.
    if type(GetTrainerServiceDescription) == "function" then
        local ok, description = pcall(GetTrainerServiceDescription, index)
        if ok then Add(description) end
    end
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
        local ok, tooltip = pcall(C_TooltipInfo.GetTrainerService, index)
        if ok and type(tooltip) == "table" and not IsSecret(tooltip) then
            for _, line in ipairs(tooltip.lines or {}) do
                if type(line) == "table" and not IsSecret(line) then
                    Add(line.leftText)
                    Add(line.rightText)
                end
            end
        end
    end
    return #parts > 0 and table.concat(parts, "\n") or nil
end

local function AvailableTrainerService(index)
    if type(GetTrainerServiceInfo) ~= "function" then return nil end
    local ok, name, second, third = pcall(GetTrainerServiceInfo, index)
    if not ok or IsSecret(name) or type(name) ~= "string" or name == "" then return nil end

    -- Mainline returns name, serviceType, texture; Classic returns
    -- name, subText, serviceType and exposes the texture separately.
    local serviceType, subText, icon
    if second == "available" or second == "unavailable" or second == "used" or second == "header" then
        serviceType, icon = second, third
    else
        subText, serviceType = second, third
        if type(GetTrainerServiceIcon) == "function" then
            local iconOK, value = pcall(GetTrainerServiceIcon, index)
            if iconOK and not IsSecret(value) then icon = value end
        end
    end
    if serviceType ~= "available" then return nil end

    local cost = 0
    if type(GetTrainerServiceCost) == "function" then
        local costOK, value = pcall(GetTrainerServiceCost, index)
        if costOK and not IsSecret(value) then cost = math.max(0, tonumber(value) or 0) end
    end
    if IsSecret(subText) or type(subText) ~= "string" then subText = nil end
    if IsSecret(icon) or (type(icon) ~= "number" and type(icon) ~= "string") then icon = nil end
    return {
        name = name,
        subText = subText,
        icon = icon or 136243,
        cost = cost,
        trainerIndex = index,
        tooltipText = TrainerTooltipText(index, name, cost),
    }
end

local function ShowLiveTrainerTooltip(owner, service)
    if not (owner and service and service.trainerIndex and GameTooltip and GameTooltip.SetTrainerService) then return false end
    if type(GetNumTrainerServices) ~= "function" or type(GetTrainerServiceInfo) ~= "function" then return false end
    if type(IsTradeskillTrainer) == "function" then
        local tradeOK, isTrade = pcall(IsTradeskillTrainer)
        if not tradeOK or IsSecret(isTrade) or isTrade then return false end
    end
    local countOK, count = pcall(GetNumTrainerServices)
    if not countOK or IsSecret(count) or service.trainerIndex > (tonumber(count) or 0) then return false end
    local infoOK, currentName = pcall(GetTrainerServiceInfo, service.trainerIndex)
    if not infoOK or IsSecret(currentName) or currentName ~= service.name then return false end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 35)
    local tooltipOK = pcall(GameTooltip.SetTrainerService, GameTooltip, service.trainerIndex)
    if not tooltipOK then return false end
    GameTooltip:Show()
    return true
end

local function TrainerServiceKey(service)
    return (service.name or "") .. "\031" .. (service.subText or "")
end

local function AbilityKnownRaw(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook and Enum and Enum.SpellBookSpellBank then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID, Enum.SpellBookSpellBank.Player, false)
        if ok and not IsSecret(known) and known then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown and Enum and Enum.SpellBookSpellBank then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, Enum.SpellBookSpellBank.Player)
        if ok and not IsSecret(known) and known then return true end
    end
    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and not IsSecret(known) and known then return true end
    end
    if type(IsSpellKnown) == "function" then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and not IsSecret(known) and known then return true end
    end
    return false
end

local function CatalogAbilityKnown(classData, spellID)
    if AbilityKnownRaw(spellID) then return true end
    for _, group in ipairs(classData.overriddenGroups or {}) do
        local spellIndex, highestKnown = nil, 0
        for index, groupedID in ipairs(group) do
            if groupedID == spellID then spellIndex = index end
            if AbilityKnownRaw(groupedID) then highestKnown = math.max(highestKnown, index) end
        end
        if spellIndex and spellIndex <= highestKnown then return true end
    end
    return false
end

local function SkillRank(skillLineID)
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then return nil end
    local ok, count = pcall(GetNumSkillLines)
    if not ok or IsSecret(count) then return nil end
    for index = 1, math.max(0, tonumber(count) or 0) do
        local info = { pcall(GetSkillLineInfo, index) }
        if info[1] then
            local isHeader, rank = info[3], info[5]
            local reportedID = tonumber(info[14]) or tonumber(info[15])
            if not isHeader and reportedID == tonumber(skillLineID) then return tonumber(rank) or 0 end
        end
    end
end

local function CatalogEntryMatchesCharacter(entry)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if entry.faction and entry.faction ~= faction then return false end
    local _, _, raceID = UnitRace and UnitRace("player")
    if entry.race and tonumber(entry.race) ~= tonumber(raceID) then return false end
    if type(entry.races) == "table" then
        local matched = false
        for _, allowedRace in ipairs(entry.races) do
            if tonumber(allowedRace) == tonumber(raceID) then matched = true break end
        end
        if not matched then return false end
    end
    for _, requirement in ipairs(entry.skills or {}) do
        local rank = SkillRank(requirement.skill)
        if not rank or rank < (tonumber(requirement.level) or 1) then return false end
    end
    return true
end

local function CatalogPrerequisitesMet(classData, entry)
    if entry.requiredTalentId and not CatalogAbilityKnown(classData, entry.requiredTalentId) then return false end
    for _, spellID in ipairs(entry.requiredIds or {}) do
        if not CatalogAbilityKnown(classData, spellID) then return false end
    end
    return true
end

local function SpellDetails(spellID)
    local name, subText, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and not IsSecret(info) then
            name, icon = info.name, info.iconID or info.originalIconID
        end
    end
    if (not name or name == "") and type(GetSpellInfo) == "function" then
        local ok, legacyName, legacySubText, legacyIcon = pcall(GetSpellInfo, spellID)
        if ok and not IsSecret(legacyName) then
            name, subText, icon = legacyName, legacySubText, legacyIcon
        end
    end
    if (not subText or subText == "") and C_Spell and C_Spell.GetSpellSubtext then
        local ok, value = pcall(C_Spell.GetSpellSubtext, spellID)
        if ok and not IsSecret(value) then subText = value end
    end
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        local ok, value = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and not IsSecret(value) then icon = value end
    end
    if (not name or name == "") and ns.RequestSpellData then
        ns.RequestSpellData(spellID, "character-reminders")
    end
    return name or ("Spell " .. tostring(spellID)), subText, icon or 136243
end

StaticTrainerServices = function()
    if staticServiceCache then return staticServiceCache end
    local _, classToken = UnitClass("player")
    local classData = ns.ClassTrainingData and ns.ClassTrainingData[classToken]
    if type(classData) ~= "table" or type(classData.spellsByLevel) ~= "table" then return nil end
    local level = tonumber(UnitLevel("player")) or 0
    local services = {}
    for requiredLevel, entries in pairs(classData.spellsByLevel) do
        requiredLevel = tonumber(requiredLevel) or math.huge
        if requiredLevel <= level then
            for _, entry in ipairs(entries) do
                if CatalogEntryMatchesCharacter(entry)
                    and not CatalogAbilityKnown(classData, entry.id)
                    and CatalogPrerequisitesMet(classData, entry) then
                    local name, subText, icon = SpellDetails(entry.id)
                    services[#services + 1] = {
                        name = name,
                        subText = subText,
                        icon = icon,
                        cost = math.max(0, tonumber(entry.cost) or 0),
                        spellID = tonumber(entry.id),
                        requiredLevel = requiredLevel,
                        catalog = true,
                    }
                end
            end
        end
    end

    local cache = TrainerCache()
    local liveByKey = {}
    if type(cache) == "table" and tonumber(cache.level) == level then
        for _, service in ipairs(cache.services or {}) do liveByKey[TrainerServiceKey(service)] = service end
    end
    local catalogKeys = {}
    for _, service in ipairs(services) do
        local key = TrainerServiceKey(service)
        catalogKeys[key] = true
        local live = liveByKey[key]
        if live then
            service.cost = math.max(0, tonumber(live.cost) or service.cost)
            service.icon = live.icon or service.icon
            service.tooltipText = live.tooltipText
        end
    end
    if type(cache) == "table" and tonumber(cache.level) == level then
        for _, live in ipairs(cache.services or {}) do
            local key = TrainerServiceKey(live)
            if not catalogKeys[key] then
                services[#services + 1] = {
                    name = live.name,
                    subText = live.subText,
                    icon = live.icon,
                    cost = math.max(0, tonumber(live.cost) or 0),
                    trainerIndex = live.trainerIndex,
                    tooltipText = live.tooltipText,
                    requiredLevel = level,
                    liveNew = type(cache.newServiceKeys) == "table" and cache.newServiceKeys[key] == true,
                }
            end
        end
    end
    table.sort(services, function(a, b)
        if a.requiredLevel ~= b.requiredLevel then return a.requiredLevel < b.requiredLevel end
        if a.name ~= b.name then return a.name < b.name end
        return (a.spellID or 0) < (b.spellID or 0)
    end)
    staticServiceCache = services
    return services
end

local function CatalogSeenTable(create)
    local db = ns.DB()
    if create and type(db.classTrainerSeenByCharacter) ~= "table" then db.classTrainerSeenByCharacter = {} end
    local all = db.classTrainerSeenByCharacter
    if type(all) ~= "table" then return nil end
    local key = ns.CharacterKey()
    if create and type(all[key]) ~= "table" then all[key] = {} end
    return all[key]
end

MarkCatalogSeen = function()
    local services = StaticTrainerServices and StaticTrainerServices()
    if type(services) ~= "table" then return end
    local seen = CatalogSeenTable(true)
    for _, service in ipairs(services) do
        if service.spellID then seen[tostring(service.spellID)] = true end
    end
end

local function NewCatalogServiceCount(services)
    local seen, count = CatalogSeenTable(false), 0
    for _, service in ipairs(services or {}) do
        if service.spellID and not (seen and seen[tostring(service.spellID)]) then
            count = count + 1
        elseif service.liveNew then
            count = count + 1
        end
    end
    return count
end

function ns.ScanClassTrainer()
    if not ns.Get("showClassTrainerSkills") or ns.IsCombatRestricted() then return false end
    if type(IsTradeskillTrainer) ~= "function" or type(GetNumTrainerServices) ~= "function" then return false end

    local tradeOK, isTrade = pcall(IsTradeskillTrainer)
    if not tradeOK or IsSecret(isTrade) or isTrade then return false end
    if type(GetTrainerServiceTypeFilter) == "function" then
        local filterOK, showingAvailable = pcall(GetTrainerServiceTypeFilter, "available")
        if filterOK and not IsSecret(showingAvailable) and showingAvailable == false then return false end
    end

    local countOK, count = pcall(GetNumTrainerServices)
    if not countOK or IsSecret(count) then return false end
    count = math.max(0, math.floor(tonumber(count) or 0))

    local services, total = {}, 0
    for index = 1, count do
        local service = AvailableTrainerService(index)
        if service then
            services[#services + 1] = service
            total = total + service.cost
        end
    end

    local currentLevel = tonumber(UnitLevel("player")) or 0
    local previous = TrainerCache()
    -- TRAINER_SHOW can fire before its service list is populated. Preserve the
    -- prior-level comparison until the deferred scan or TRAINER_UPDATE has data.
    if count == 0 and previous then return false end
    local previousServices, previousKeys = previous and previous.services, {}
    if type(previousServices) == "table" then
        for index = 1, #previousServices do previousKeys[TrainerServiceKey(previousServices[index])] = true end
    end
    local retainedNew = type(previous) == "table" and type(previous.newServiceKeys) == "table"
        and previous.newServiceKeys or {}
    local newServiceKeys = {}
    if not TrainerSkillsExpanded() then
        for index = 1, #services do
            local key = TrainerServiceKey(services[index])
            if retainedNew[key]
                or (previous and currentLevel > (tonumber(previous.level) or currentLevel) and not previousKeys[key]) then
                newServiceKeys[key] = true
            end
        end
    end
    local newServiceCount = 0
    for _ in pairs(newServiceKeys) do newServiceCount = newServiceCount + 1 end

    local trainerName = UnitName and UnitName("npc")
    if IsSecret(trainerName) or type(trainerName) ~= "string" or trainerName == "" then trainerName = "Class trainer" end
    local className, classToken = UnitClass("player")
    local db = ns.DB()
    if type(db.classTrainerByCharacter) ~= "table" then db.classTrainerByCharacter = {} end
    db.classTrainerByCharacter[ns.CharacterKey()] = {
        className = className,
        classToken = classToken,
        level = currentLevel,
        trainerName = trainerName,
        services = services,
        total = total,
        newServiceKeys = newServiceKeys,
        newServiceCount = newServiceCount,
    }
    staticServiceCache = nil
    return true
end

local function Build()
    local rows = {}
    if ns.Get("showTalentReminder") then
        local hasPoints, count = UnspentTalents()
        if hasPoints then
            rows[#rows + 1] = {
                key = "unspent-talents",
                label = string.format("%d unspent talent point%s", count, count == 1 and "" or "s"),
                detail = "Open Talents to spend them.",
                state = "warning",
                attention = "warning",
                icon = TalentIcon(),
                onClick = OpenTalents,
            }
        end
    end

    if ns.Get("showClassTrainerSkills") then
        local services = StaticTrainerServices and StaticTrainerServices()
        if type(services) ~= "table" then
            local cache = TrainerCache()
            services = type(cache) == "table" and type(cache.services) == "table" and cache.services or {}
        end
        if #services > 0 then
            local total = 0
            for _, service in ipairs(services) do total = total + math.max(0, tonumber(service.cost) or 0) end
            local expanded = TrainerSkillsExpanded()
            if expanded and MarkCatalogSeen then MarkCatalogSeen() end
            local newServiceCount = NewCatalogServiceCount(services)
            rows[#rows + 1] = {
                key = "class-training-total",
                label = string.format("%s %d class-trainer skill%s available",
                    expanded and "−" or "+", #services, #services == 1 and "" or "s"),
                detail = string.format("Total training cost: %s%s", FormatMoney(total),
                    newServiceCount > 0 and string.format(" • %d newly available", newServiceCount) or ""),
                tooltip = string.format("Learn every listed skill for %s. %s",
                    FormatMoney(total), expanded and "Collapse the individual skill list."
                        or "Expand the individual skill list."),
                clickHint = expanded and "Click to collapse class-trainer skills."
                    or "Click to expand class-trainer skills.",
                onClick = ToggleTrainerSkills,
                state = "warning",
                attention = not expanded and newServiceCount > 0 and "warning" or nil,
                icon = 136243,
            }
            if expanded then
                for index = 1, #services do
                    local service = services[index]
                    local label = service.name or "Unknown skill"
                    if service.subText and service.subText ~= "" then
                        label = string.format("%s (%s)", label, service.subText)
                    end
                    rows[#rows + 1] = {
                        key = "class-training-" .. tostring(service.spellID or index),
                        label = label,
                        detail = "Cost: " .. FormatMoney(service.cost),
                        tooltip = service.spellID and "" or service.tooltipText,
                        tooltipFunc = not service.spellID and function(owner)
                            return ShowLiveTrainerTooltip(owner, service)
                        end or nil,
                        spellID = service.spellID,
                        state = "warning",
                        icon = service.icon or 136243,
                        indentLevel = 1,
                    }
                end
            end
        end
    end

    if #rows == 0 then return {} end
    return {
        id = "character-reminders",
        title = "Character",
        rows = rows,
    }
end

ns.RegisterProvider("character-reminders", 5, Build)

local catalogEvents = CreateFrame("Frame")
for _, event in ipairs({
    "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED",
    "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED",
}) do
    pcall(catalogEvents.RegisterEvent, catalogEvents, event)
end
catalogEvents:SetScript("OnEvent", function(_, event)
    staticServiceCache = nil
    if ns.RequestRefresh then ns.RequestRefresh("character-reminders", event) end
end)

-------------------------------------------------------------------------------
-- Blizzard points its talent alert at PlayerSpellsMicroButton. EllesmereUI can
-- hide that microbar, so suppress only this one alert when our replacement is
-- enabled. Other microbutton alerts continue through Blizzard unchanged.
-------------------------------------------------------------------------------
local function IsTalentButton(button)
    return button and (button == _G.PlayerSpellsMicroButton or button == _G.TalentMicroButton)
end

local function IsUnspentTalentAlert(text)
    if type(text) ~= "string" then return false end
    local localized = _G.TALENT_MICRO_BUTTON_UNSPENT_TALENTS
    return (type(localized) == "string" and text == localized)
        or text == "You have unspent Talent points."
end

local function StopTalentPulse(button)
    if not button then return end
    C_Timer.After(0, function()
        if MicroButtonPulseStop then pcall(MicroButtonPulseStop, button) end
    end)
end

local function HideTalentAlert(button, text, force)
    if not ns.Get("hideBlizzardTalentReminder") or not IsTalentButton(button) then return end
    if not force and not IsUnspentTalentAlert(text) then return end

    -- Current Forever/Mainline alerts are HelpTips tracked by the microbutton
    -- manager. Older clients used named alert frames, so retain those fallbacks.
    if type(_G.MainMenuMicroButton_HideAlert) == "function" then
        pcall(_G.MainMenuMicroButton_HideAlert, button)
    elseif HelpTip and HelpTip.HideAllSystem then
        pcall(HelpTip.HideAllSystem, HelpTip, "MicroButtons")
    end
    local legacyAlerts = { _G.MainMenuMicroButtonAlert, _G.TalentMicroButtonAlert, button.alert }
    for index = 1, 3 do
        local alert = legacyAlerts[index]
        if alert and alert.Hide then alert:Hide() end
    end
    StopTalentPulse(button)
end

function ns.ApplyTalentAlertSuppression()
    if not ns.Get("hideBlizzardTalentReminder") then return end
    local button = _G.PlayerSpellsMicroButton or _G.TalentMicroButton
    if not button then return end

    -- Re-evaluating lets Blizzard identify the highest-priority Player Spells
    -- alert. Our ShowAlert hook removes only the unspent-talent message.
    if type(button.EvaluateAlertVisibility) == "function" then
        pcall(button.EvaluateAlertVisibility, button)
        return
    end
    local hasPoints = UnspentTalents()
    if hasPoints then HideTalentAlert(button, nil, true) end
end

local alertHooked = false
local function InstallAlertHook()
    if alertHooked or type(_G.MainMenuMicroButton_ShowAlert) ~= "function" or not hooksecurefunc then return end
    hooksecurefunc("MainMenuMicroButton_ShowAlert", function(button, text) HideTalentAlert(button, text, false) end)
    alertHooked = true
end
InstallAlertHook()

local suppressor = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_CHANGED" }) do
    pcall(suppressor.RegisterEvent, suppressor, event)
end
suppressor:SetScript("OnEvent", function()
    InstallAlertHook()
    C_Timer.After(0, function()
        if not ns.Get("hideBlizzardTalentReminder") then return end
        ns.ApplyTalentAlertSuppression()
    end)
end)
