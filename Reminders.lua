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
        local cache = TrainerCache()
        if cache then
            cache.newServiceKeys = nil
            cache.newServiceCount = 0
        end
    end
    if ns.RequestRefresh then ns.RequestRefresh() end
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
        local cache = TrainerCache()
        if not cache then
            rows[#rows + 1] = {
                key = "class-training-scan",
                label = "Class training not scanned",
                detail = "Visit a class trainer once to load available skills and their total cost.",
                state = "info",
                icon = 136243,
            }
        else
            local services = type(cache.services) == "table" and cache.services or {}
            local total = tonumber(cache.total) or 0
            local currentLevel = tonumber(UnitLevel("player")) or 0
            local stale = currentLevel ~= (tonumber(cache.level) or 0)
            if #services == 0 then
                rows[#rows + 1] = {
                    key = "class-training-total",
                    label = "No class training available",
                    detail = stale and "Visit a class trainer to refresh after leveling."
                        or string.format("Checked with %s.", cache.trainerName or "your class trainer"),
                    state = stale and "info" or "ready",
                    icon = 136243,
                }
            else
                local expanded = TrainerSkillsExpanded()
                local newServiceCount = math.max(0, tonumber(cache.newServiceCount) or 0)
                rows[#rows + 1] = {
                    key = "class-training-total",
                    label = string.format("%s %d class-trainer skill%s available",
                        expanded and "−" or "+", #services, #services == 1 and "" or "s"),
                    detail = string.format("Total training cost: %s%s%s", FormatMoney(total),
                        newServiceCount > 0 and string.format(" • %d newly available", newServiceCount) or "",
                        stale and " • rescan after leveling" or ""),
                    tooltip = string.format("Last scanned from %s at level %d. Learn every listed skill for %s. %s%s",
                        cache.trainerName or "a class trainer", tonumber(cache.level) or 0, FormatMoney(total),
                        stale and "Visit a class trainer to include newly available skills. " or "",
                        expanded and "Collapse the individual skill list." or "Expand the individual skill list."),
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
                            key = "class-training-" .. index,
                            label = label,
                            detail = "Cost: " .. FormatMoney(service.cost),
                            tooltip = service.tooltipText or string.format("Untrained skill available from %s.",
                                cache.trainerName or "your class trainer"),
                            tooltipFunc = function(owner) return ShowLiveTrainerTooltip(owner, service) end,
                            state = "warning",
                            icon = service.icon or 136243,
                        }
                    end
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

