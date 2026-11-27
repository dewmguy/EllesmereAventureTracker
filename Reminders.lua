-------------------------------------------------------------------------------
-- Adventure Tracker: character reminders that replace hidden microbar alerts.
-------------------------------------------------------------------------------
local _, ns = ...

local function IsSecret(value)
    return _G.issecretvalue and _G.issecretvalue(value)
end

local function HasUnspentTalents()
    if not (C_SpecializationInfo and C_SpecializationInfo.CanPlayerUseTalentUI
        and C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints) then
        return false
    end
    local ok, available = pcall(C_SpecializationInfo.CanPlayerUseTalentUI)
    if not ok or IsSecret(available) or not available then return false end
    local normalOK, normal = pcall(C_ClassTalents.HasUnspentTalentPoints)
    local heroOK, hero = true, false
    if C_ClassTalents.HasUnspentHeroTalentPoints then
        heroOK, hero = pcall(C_ClassTalents.HasUnspentHeroTalentPoints)
    end
    if not normalOK or not heroOK or IsSecret(normal) or IsSecret(hero) then return false end
    return normal == true or hero == true
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

local function Build()
    if not ns.Get("showTalentReminder") or not HasUnspentTalents() then return {} end
    return {
        id = "character-reminders",
        title = "Character",
        rows = {
            {
                key = "unspent-talents",
                label = "Unspent talent points",
                detail = "Open Talents to spend your available points.",
                state = "warning",
                icon = TalentIcon(),
                onClick = OpenTalents,
            },
        },
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

local function HideTalentAlert(button)
    if not ns.Get("hideBlizzardTalentReminder") or not IsTalentButton(button) then return end
    local alert = _G.MainMenuMicroButtonAlert
    if alert then alert:Hide() end
    if button.alert then button.alert:Hide() end
end

function ns.ApplyTalentAlertSuppression()
    if not ns.Get("hideBlizzardTalentReminder") then return end
    local alert = _G.MainMenuMicroButtonAlert
    if not (alert and alert:IsShown()) then return end
    local _, relativeTo = alert:GetPoint(1)
    HideTalentAlert(relativeTo)
end

local alertHooked = false
local function InstallAlertHook()
    if alertHooked or type(_G.MainMenuMicroButton_ShowAlert) ~= "function" or not hooksecurefunc then return end
    hooksecurefunc("MainMenuMicroButton_ShowAlert", function(button) HideTalentAlert(button) end)
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
