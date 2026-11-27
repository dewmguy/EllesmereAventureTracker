-------------------------------------------------------------------------------
-- Adventure Tracker: EllesmereUI sidebar and settings pages.
-------------------------------------------------------------------------------
local _, ns = ...
local EUI = ns.EUI

local function Toggle(key, text, tooltip, refreshPage)
    return {
        type = "toggle",
        text = text,
        tooltip = tooltip,
        getValue = function() return ns.Get(key) == true end,
        setValue = function(value)
            ns.Set(key, value)
            if refreshPage and EUI.RefreshPage then EUI:RefreshPage() end
        end,
    }
end

local function Slider(key, text, minimum, maximum, step, tooltip, disabled)
    return {
        type = "slider",
        text = text,
        tooltip = tooltip,
        min = minimum,
        max = maximum,
        step = step,
        disabled = disabled,
        getValue = function() return ns.Get(key) end,
        setValue = function(value)
            ns.Set(key, value)
            if ns.ApplySettings then ns.ApplySettings() end
        end,
    }
end

local function Label(text, tooltip)
    return { type = "label", text = text, tooltip = tooltip }
end

local TRACKER_KEYS = { "enabled", "locked", "width", "scale", "opacity", "position", "hideInCombat", "hideInInstances", "hideWhenReady", "showContext" }
local READINESS_KEYS = { "showReadiness", "trackCamp", "trackSleepingBag", "trackFood", "trackClassBuffs", "trackWeaponEnhancements", "readinessWarnMinutes", "showCompletedReadiness", "roleByCharacter" }
local WORLD_BUFF_KEYS = { "showWorldBuffs", "showActiveWorldBuffs", "showMissingWorldBuffs", "worldBuffCurrentZoneOnly", "worldBuffWarnMinutes" }
local LEGACY_KEYS = { "showLegacy", "showUnspentLegacy" }
local PROFESSION_KEYS = { "showProfessions", "showProfessionProgress", "showProfessionCaps", "showCompletedProfessions", "showProfessionZoneHints" }

local function BuildTracker(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    _, h = W:SectionHeader(parent, "WINDOW", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("enabled", "Enable Adventure Tracker", "Shows the floating Adventure Tracker window."),
        Toggle("locked", "Lock Window", "Prevents dragging the tracker by its title bar."))
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Reset Position", tooltip = "Returns the tracker to its default screen position, size, scale and opacity.",
          onClick = function() ns.ResetKeys({ "position", "width", "scale", "opacity" }) end },
        Label("Drag by the title bar while unlocked."))
    y = y - h

    _, h = W:SectionHeader(parent, "SIZE AND APPEARANCE", y); y = y - h
    _, h = W:DualRow(parent, y,
        Slider("width", "Window Width", 280, 480, 5, "Width of the Adventure Tracker window."),
        Slider("scale", "Window Scale", 0.65, 1.50, 0.05, "Overall scale of the Adventure Tracker window."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("opacity", "Window Opacity", 0.25, 1.00, 0.05, "Opacity of the whole tracker window."),
        Toggle("showContext", "Show Zone and Role", "Shows the current zone and selected activity role above the readiness icons."))
    y = y - h

    _, h = W:SectionHeader(parent, "VISIBILITY", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("hideInCombat", "Hide in Combat", "Hides the tracker while you are in combat."),
        Toggle("hideInInstances", "Hide in Instances", "Hides the tracker inside dungeons, raids and PvP instances."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("hideWhenReady", "Hide When Nothing Needs Attention", "Hides the entire window when no visible row is missing or nearing expiration."),
        nil)
    y = y - h
    return math.abs(y)
end

local function BuildReadiness(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    if pageName == "Essentials" then
        _, h = W:SectionHeader(parent, "READINESS STRIP", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showReadiness", "Enable Readiness", "Shows the readiness icon strip and its actionable rows.", true),
            Toggle("showCompletedReadiness", "Show Completed Rows", "Keeps satisfied readiness items in the expanded list as well as the icon strip."))
        y = y - h

        _, h = W:SectionHeader(parent, "ESSENTIALS", y); y = y - h
        local disabled = function() return not ns.Get("showReadiness") end
        local camp = Toggle("trackCamp", "Camp Benefits", "Tracks whether Camp Benefits is active and when a timed instance is nearing expiration.")
        camp.disabled = disabled
        local sleeping = Toggle("trackSleepingBag", "Cozy Sleeping Bag", "Tracks Well-Rested stacks below maximum level when the bag is available.")
        sleeping.disabled = disabled
        _, h = W:DualRow(parent, y, camp, sleeping); y = y - h
        local food = Toggle("trackFood", "Food Buff", "Tracks Well Fed and known Forever food buffs.")
        food.disabled = disabled
        _, h = W:DualRow(parent, y,
            food,
            Slider("readinessWarnMinutes", "Expiring Soon", 0, 60, 1, "A timed readiness item becomes amber this many minutes before it expires.", disabled))
        y = y - h

        _, h = W:SectionHeader(parent, "INTERPRETATION", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Green = ready; amber = partial or expiring; red = missing.", "Gray means unavailable, violet means unreadable, and blue is informational."),
            Label("Only actionable items expand into rows by default."))
        y = y - h
    else
        _, h = W:SectionHeader(parent, "ACTIVITY ROLE", y); y = y - h
        local roleValues = ns.ROLE_LABELS
        local roleOrder = { "SOLO", "TANK", "HEALER", "PHYSICAL", "CASTER" }
        _, h = W:DualRow(parent, y,
            { type = "dropdown", text = "Role for This Character",
              tooltip = "Forever does not expose a reliable solo specialization role, so Adventure Tracker keeps an explicit per-character activity role.",
              values = roleValues, order = roleOrder,
              getValue = ns.GetRole,
              setValue = ns.SetRole },
            Label("Used to decide which role-specific self buffs are important."))
        y = y - h

        _, h = W:SectionHeader(parent, "CLASS PREPARATION", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("trackClassBuffs", "Class and Personal Buffs", "Tracks known always-on class preparation such as blessings, auras, armor, shields and shouts."),
            Toggle("trackWeaponEnhancements", "Weapon Enhancements", "Tracks poisons and weapon imbues for classes that use them."))
        y = y - h

        _, h = W:SectionHeader(parent, "BUFF EQUIVALENCE", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Camp Benefits can satisfy matching buff families.", "The first preview recognizes Incense Candle as Intellect coverage and First Aid Kit as Fortitude coverage."),
            Label("More camp and world-buff families will be added from verified Forever data."))
        y = y - h
    end
    return math.abs(y)
end

local function BuildLegacy(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    _, h = W:SectionHeader(parent, "LEGACY TRACKING", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("showLegacy", "Enable Legacy Section", "Shows Legacy opportunities in the floating tracker.", true),
        Toggle("showUnspentLegacy", "Unspent Point Reminder", "Shows a row when the current character has Legacy points available to spend."))
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Open Legacy Window", onClick = function()
            if not InCombatLockdown() and ToggleLegacySystemUI then ToggleLegacySystemUI() end
          end },
        Label("Zone recommendations stay hidden until the addon has a verified action to show."))
    y = y - h

    _, h = W:SectionHeader(parent, "RECOMMENDATIONS", y); y = y - h
    _, h = W:DualRow(parent, y,
        Label("Unspent points are live now."),
        Label("Planned recommendations will use Blizzard's live Legacy Challenges and show only relevant, incomplete goals."))
    y = y - h
    return math.abs(y)
end

local function BuildWorldBuffs(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    if pageName == "Tracking" then
        _, h = W:SectionHeader(parent, "WORLD-BUFF STATUS", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showWorldBuffs", "Enable World Buffs", "Shows active and optionally missing world buffs in their own tracker section.", true),
            Toggle("showActiveWorldBuffs", "Show Active Buffs", "Shows known world buffs currently active on this character."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showMissingWorldBuffs", "Show Missing Buffs", "Shows selected known world buffs you do not have, including where to obtain them."),
            Slider("worldBuffWarnMinutes", "Expiring Soon", 0, 60, 1, "An active world buff becomes amber this many minutes before it expires."))
        y = y - h

        _, h = W:SectionHeader(parent, "DEFAULT BEHAVIOR", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Active buffs are shown by default; missing buffs are opt-in so the tracker does not treat every possible world buff as mandatory."),
            Label("World buffs are kept separate from the core readiness strip."))
        y = y - h
    else
        _, h = W:SectionHeader(parent, "ACQUISITION SOURCES", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("worldBuffCurrentZoneOnly", "Only Missing Buffs Available Here", "When missing-buff tracking is enabled, only shows buffs whose known acquisition zone matches your current zone."),
            nil)
        y = y - h
        _, h = W:SectionHeader(parent, "FIRST VERIFIED SET", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Faction Rend buff, Dragonslayer, Zandalar, Songflower and the three Dire Maul tribute buffs."),
            Label("Live drop schedules and waypoints will follow after their Forever signals and coordinates are verified."))
        y = y - h
    end
    return math.abs(y)
end

local function BuildProfessions(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    if pageName == "Progress" then
        _, h = W:SectionHeader(parent, "PROFESSION PROGRESS", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessions", "Enable Profession Sections", "Shows profession checkpoints and local opportunities.", true),
            Toggle("showProfessionProgress", "Legacy Skill Checkpoints", "Shows progress toward skill 150, 225 and 300 for crafting professions that award Legacy points."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionCaps", "Trainer Cap Reminders", "Shows when a profession has reached its current skill cap below 300."),
            Toggle("showCompletedProfessions", "Show Completed Professions", "Keeps professions at their final Legacy skill checkpoint visible."))
        y = y - h

        _, h = W:SectionHeader(parent, "CHECKPOINTS", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking and Tailoring are tracked at 150, 225 and 300."),
            Label("Gathering professions appear under Local Opportunities instead."))
        y = y - h
    else
        _, h = W:SectionHeader(parent, "CURRENT ZONE", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionZoneHints", "Local Gathering Hints", "Shows contextual reminders for Herbalism, Mining, Skinning and Fishing in the current zone."),
            nil)
        y = y - h

        _, h = W:SectionHeader(parent, "DATA ROADMAP", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("The first preview gives truthful contextual hints without inventing node or mob locations."),
            Label("Verified zone materials, mobs, trainers, quests and profession rewards will become richer local recommendations."))
        y = y - h
    end
    return math.abs(y)
end

local registered = false
local function Register()
    if registered then return true end
    if not EUI.RegisterPlugin then return false end
    registered = EUI.RegisterPlugin("EllesmereUIAdventureTracker", {
        label = "Adventure Tracker",
        position = "bottom",
        modules = {
            {
                key = "tracker", title = "Tracker",
                description = "Window layout, placement and visibility.",
                pages = { "Window" }, buildPage = BuildTracker,
                onReset = function() ns.ResetKeys(TRACKER_KEYS) end,
            },
            {
                key = "readiness", title = "Readiness",
                description = "Camp, rest, food and class preparation.",
                pages = { "Essentials", "Class & Role" }, buildPage = BuildReadiness,
                onReset = function() ns.ResetKeys(READINESS_KEYS) end,
            },
            {
                key = "world-buffs", title = "World Buffs",
                description = "Active world buffs and where missing ones come from.",
                pages = { "Tracking", "Sources" }, buildPage = BuildWorldBuffs,
                onReset = function() ns.ResetKeys(WORLD_BUFF_KEYS) end,
            },
            {
                key = "legacy", title = "Legacy",
                description = "Legacy points and current-zone opportunities.",
                pages = { "Overview" }, buildPage = BuildLegacy,
                onReset = function() ns.ResetKeys(LEGACY_KEYS) end,
            },
            {
                key = "professions", title = "Professions",
                description = "Skill checkpoints and local profession opportunities.",
                pages = { "Progress", "Local Opportunities" }, buildPage = BuildProfessions,
                onReset = function() ns.ResetKeys(PROFESSION_KEYS) end,
            },
        },
    }) == true
    return registered
end

if not Register() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, addonName)
        if addonName == "EllesmereUI" and Register() then self:UnregisterAllEvents() end
    end)
end
