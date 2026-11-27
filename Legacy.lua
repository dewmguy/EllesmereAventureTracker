-------------------------------------------------------------------------------
-- Adventure Tracker: Legacy provider.
-------------------------------------------------------------------------------
local _, ns = ...

local LEGACY_PROFESSIONS = {
    [164] = true, -- Blacksmithing
    [165] = true, -- Leatherworking
    [171] = true, -- Alchemy
    [197] = true, -- Tailoring
    [202] = true, -- Engineering
    [333] = true, -- Enchanting
}
local CHECKPOINTS = { 150, 225, 300 }

local function NextCheckpoint(rank)
    for i = 1, #CHECKPOINTS do
        if rank < CHECKPOINTS[i] then return CHECKPOINTS[i] end
    end
end

local function AvailablePoints()
    local constants = _G.Constants and _G.Constants.LegacyConsts
    if not constants or not C_MajorFactions or not C_Traits then return nil end
    local factionID = constants.LEGACY_REWARD_TRACK_FACTION_ID
    local treeID = constants.LEGACY_TREE_PROFESSIONS_ID
    if not factionID or not treeID then return nil end
    local ok, renown = pcall(C_MajorFactions.GetCurrentRenownLevel, factionID)
    if not ok or type(renown) ~= "number" or renown <= 0 then return 0 end
    local configID = C_Traits.GetConfigIDByTreeID(treeID)
    if not configID then return 0 end
    local infos = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    local info = infos and infos[1]
    return info and info.quantity or 0
end

local function OpenLegacy()
    if InCombatLockdown and InCombatLockdown() then return end
    if ToggleLegacySystemUI then ToggleLegacySystemUI() end
end

local function Build()
    if not ns.Get("showLegacy") then return {} end
    local rows = {}
    if ns.Get("showUnspentLegacy") then
        local points = AvailablePoints()
        if points and points > 0 then
            rows[#rows + 1] = {
                key = "unspent-legacy",
                label = string.format("%d unspent Legacy point%s", points, points == 1 and "" or "s"),
                detail = "Open the Legacy tree to plan or spend them.",
                state = "warning",
                icon = 236544,
                onClick = OpenLegacy,
            }
        end
    end
    if ns.Get("showLegacyProfessionGoals") and ns.GetProfessionList then
        local professions = ns.GetProfessionList()
        for i = 1, #professions do
            local profession = professions[i]
            if LEGACY_PROFESSIONS[profession.skillLineID] then
                local checkpoint = NextCheckpoint(profession.rank)
                if checkpoint then
                    local remaining = checkpoint - profession.rank
                    rows[#rows + 1] = {
                        key = "legacy-profession-" .. tostring(profession.skillLineID),
                        label = string.format("Raise %s to %d", profession.name, checkpoint),
                        detail = string.format("Next profession Legacy checkpoint • %d skill-up%s remaining.", remaining, remaining == 1 and "" or "s"),
                        state = remaining <= 10 and "warning" or "info",
                        icon = profession.icon,
                    }
                end
            end
        end
    end
    return {
        id = "legacy",
        title = "Legacy",
        rows = rows,
    }
end

ns.RegisterProvider("legacy", 20, Build)
