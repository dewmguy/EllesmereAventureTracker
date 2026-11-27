-------------------------------------------------------------------------------
-- Adventure Tracker: Legacy provider.
-------------------------------------------------------------------------------
local _, ns = ...

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
    if ns.Get("showLegacyZoneNote") then
        local zone = ns.GetZoneName()
        rows[#rows + 1] = {
            key = "legacy-zone-preview",
            label = zone,
            detail = "Verified current-zone Legacy recommendations are the next provider milestone.",
            state = "info",
            icon = 236544,
            onClick = OpenLegacy,
        }
    end
    return {
        id = "legacy",
        title = "Legacy in This Zone",
        rows = rows,
    }
end

ns.RegisterProvider("legacy", 20, Build)
