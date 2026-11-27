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

local function AppearanceSet(key, value, refreshPage)
    ns.Set(key, value, true)
    if ns.ApplySettings then ns.ApplySettings() end
    if refreshPage and EUI.RefreshPage then EUI:RefreshPage() end
end

local function StyleToggle(key, text, tooltip, disabled, refreshPage)
    return {
        type = "toggle", text = text, tooltip = tooltip, disabled = disabled,
        getValue = function() return ns.Get(key) == true end,
        setValue = function(value) AppearanceSet(key, value, refreshPage) end,
    }
end

local function Dropdown(key, text, values, order, tooltip, disabled, refreshPage)
    return {
        type = "dropdown", text = text, values = values, order = order,
        tooltip = tooltip, disabled = disabled,
        getValue = function() return ns.Get(key) end,
        setValue = function(value) AppearanceSet(key, value, refreshPage) end,
    }
end

local function ColorPicker(key, text, tooltip, hasAlpha, disabled)
    return {
        type = "colorpicker", text = text, tooltip = tooltip,
        hasAlpha = hasAlpha, disabled = disabled,
        getValue = function()
            local color = ns.Get(key)
            local fallback = ns.DEFAULTS[key] or {}
            if type(color) ~= "table" then color = fallback end
            return color.r or fallback.r or 1, color.g or fallback.g or 1,
                color.b or fallback.b or 1, color.a == nil and (fallback.a or 1) or color.a
        end,
        setValue = function(r, g, b, a)
            AppearanceSet(key, { r = r, g = g, b = b, a = a or 1 })
        end,
    }
end

local COLOR_MODE_VALUES = { custom = "Custom", class = "Class Color", accent = "Accent Color" }
local COLOR_MODE_ORDER = { "custom", "class", "accent" }

local function TextColorMode(key, text, tooltip, disabled)
    return Dropdown(key, text, COLOR_MODE_VALUES, COLOR_MODE_ORDER, tooltip, disabled, true)
end

local function CustomColorDisabled(modeKey, additionalDisabled)
    return function()
        return ns.Get(modeKey) ~= "custom" or (additionalDisabled and additionalDisabled())
    end
end

local TRACKER_KEYS = {
    "enabled", "locked", "width", "scale", "frameStrata", "maximizePaneHeight", "paneGrowthDirection", "opacity", "position", "hideInCombat", "hideInInstances", "hideWhenReady", "showContext", "collapsedSectionsByCharacter",
    "panePadding", "backgroundColor", "sectionBackgroundColor", "sectionHoverBackgroundColor", "entryBackgroundColor", "entryHoverBackgroundColor",
    "borderTexture", "borderSize", "borderColor", "titleBarMode", "titleBarHeight", "titleBarColor",
    "titleTextColorMode", "titleTextColor", "textFont", "textOutline", "titleFontSize", "contextFontSize", "contextTextColorMode", "contextTextColor",
    "sectionFontSize", "sectionTextColorMode", "sectionTextColor", "entryLabelFontSize", "entryLabelTextColorMode", "entryLabelTextColor",
    "entryDetailFontSize", "entryDetailTextColorMode", "entryDetailTextColor", "badgeFontSize", "badgeTextColorMode", "badgeTextColor",
    "titleAlignment", "showTitleText", "titleSeparatorSize", "titleSeparatorColor",
}
local READINESS_KEYS = { "showReadiness", "trackCamp", "trackSleepingBag", "trackFood", "trackClassBuffs", "trackWeaponEnhancements", "readinessWarnMinutes", "showCompletedReadiness", "roleByCharacter", "lastClassBuffSpellsByCharacter", "roleCriticalAlerts", "roleAlertMinDuration", "trackPartyClassBuffs" }
local REMINDER_KEYS = { "showTalentReminder", "showClassTrainerSkills", "hideBlizzardTalentReminder" }
local WORLD_BUFF_KEYS = { "showWorldBuffs", "showActiveWorldBuffs", "showMissingWorldBuffs", "worldBuffCurrentZoneOnly", "worldBuffWarnMinutes" }
local LEGACY_KEYS = { "showLegacy", "showUnspentLegacy", "showLegacyProfessionGoals" }
local PROFESSION_KEYS = { "showProfessions", "showProfessionProgress", "showProfessionSynergy", "showProfessionGear", "showProfessionCaps", "showProfessionTrainerRecipes", "showCompletedProfessions", "showProfessionZoneHints" }
local INSTANCE_KEYS = { "showInstances", "showInstanceRunTimer", "showInstanceBossTimer", "showInstanceQuests", "showInstanceLoot", "instanceQuestLimit", "instanceLootLimit" }
local FLIGHT_KEYS = {
    "showFlightTimer", "flightTimerShowDestination", "flightTimerShowElapsed", "flightTimerShowRemaining", "flightTimerShowTotal",
    "flightTimerLearnTimes", "flightTimerShowIcon", "flightTimerBarHeight", "flightTimerBarTexture", "flightTimerFillColorMode",
    "flightTimerFillColor", "flightTimerBackgroundColor", "flightTimerBorderTexture", "flightTimerBorderSize", "flightTimerBorderColor",
    "flightTimerFont", "flightTimerFontOutline", "flightTimerDestinationFontSize", "flightTimerTimeFontSize",
    "flightTimerDestinationColorMode", "flightTimerDestinationColor", "flightTimerTimeColorMode", "flightTimerTimeColor",
}
local STATUS_KEYS = {
    "showStatuses", "showFlightStatus", "showCombatStatus", "showRestingStatus", "showMountedStatus", "showInstanceStatus",
    "showPresenceStatus", "showLifeStatus", "showPlaytime", "showSessionPlaytime", "showTotalPlaytime", "showGoldStatus",
}

local function BuildTracker(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    local borderValues, borderOrder = { solid = "Solid" }, { "solid" }
    if EUI.GetBorderTextureDropdown then borderValues, borderOrder = EUI.GetBorderTextureDropdown() end
    local fontValues, fontOrder = { __global = "EUI Global Font" }, { "__global" }
    if EUI.BuildFontDropdownData then fontValues, fontOrder = EUI.BuildFontDropdownData() end

    _, h = W:SectionHeader(parent, "WINDOW", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("enabled", "Enable Adventure Tracker", "Shows the floating Adventure Tracker window."),
        Toggle("locked", "Lock Window", "Prevents dragging the tracker from its pane surfaces."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("frameStrata", "Main Pane Strata", {
            BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High",
            DIALOG = "Dialog", FULLSCREEN = "Fullscreen", FULLSCREEN_DIALOG = "Fullscreen Dialog", TOOLTIP = "Tooltip",
        }, { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" },
            "Controls whether the entire tracker appears behind or above other UI windows. Medium matches the original behavior."),
        Label("Secure click surfaces for food and class buffs follow the selected pane strata when out of combat."))
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Reset Position", tooltip = "Returns the tracker to its default screen position, width, scale and growth behavior.",
          onClick = function() ns.ResetKeys({ "position", "width", "scale", "maximizePaneHeight", "paneGrowthDirection" }) end },
        { type = "button", text = "Reset Appearance", tooltip = "Restores spacing, backgrounds, border, title bar and text defaults.",
          onClick = function()
              ns.ResetKeys({ "frameStrata", "opacity", "panePadding", "backgroundColor", "sectionBackgroundColor", "sectionHoverBackgroundColor",
                  "entryBackgroundColor", "entryHoverBackgroundColor", "borderTexture", "borderSize", "borderColor", "titleBarMode",
                  "titleBarHeight", "titleBarColor", "titleTextColorMode", "titleTextColor", "textFont", "textOutline", "titleFontSize",
                  "contextFontSize", "contextTextColorMode", "contextTextColor", "sectionFontSize", "sectionTextColorMode", "sectionTextColor",
                  "entryLabelFontSize", "entryLabelTextColorMode", "entryLabelTextColor", "entryDetailFontSize", "entryDetailTextColorMode",
                  "entryDetailTextColor", "badgeFontSize", "badgeTextColorMode", "badgeTextColor", "titleAlignment", "showTitleText",
                  "titleSeparatorSize", "titleSeparatorColor" })
          end })
    y = y - h

    _, h = W:SectionHeader(parent, "SIZE AND SPACING", y); y = y - h
    _, h = W:DualRow(parent, y,
        Slider("width", "Window Width", 280, 480, 5, "Width of the Adventure Tracker window."),
        Slider("scale", "Window Scale", 0.65, 1.50, 0.05, "Overall scale of the Adventure Tracker window."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("panePadding", "Pane Padding", 0, 24, 1, "Space between the pane edges and tracker contents on all sides."),
        Toggle("showContext", "Show Zone, Class, Spec and Role", "Shows the current zone, class, specialization and selected activity role above the readiness icons."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("maximizePaneHeight", "Allow Full Viewport Height", "Allows an unanchored pane to use all safe screen space in the selected growth direction instead of the normal 75% screen-height limit. A dynamic EllesmereUI anchor always uses the safe space between its fixed edge and the viewport."),
        Dropdown("paneGrowthDirection", "Pane Growth Direction", { DOWN = "Down", UP = "Up" }, { "DOWN", "UP" }, "Keeps an unanchored pane's top edge fixed when growing down, or its bottom edge fixed when growing up. A vertical EllesmereUI anchor determines the anchored pane's growth edge."))
    y = y - h

    _, h = W:SectionHeader(parent, "VISIBILITY", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("hideInCombat", "Hide in Combat", "Hides the tracker while you are in combat. An enabled boss timer temporarily overrides this so the encounter clock remains visible."),
        Toggle("hideInInstances", "Hide in Instances", "Hides the tracker inside dungeons, raids and PvP instances."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("hideWhenReady", "Hide When Nothing Needs Attention", "Hides the entire window when no visible row is missing or nearing expiration."),
        Label("While unlocked, drag almost any pane surface or use Unlock Mode for exact anchoring."))
    y = y - h

    _, h = W:SectionHeader(parent, "BACKGROUNDS", y); y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("backgroundColor", "Main Pane Background", "Color and alpha behind the tracker contents.", true),
        Slider("opacity", "Main Pane Opacity", 0.00, 1.00, 0.05, "Additional opacity for only the main pane background; text, title and entry backgrounds are unaffected."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("sectionBackgroundColor", "Section Background", "Normal color and alpha behind section titles.", true),
        ColorPicker("sectionHoverBackgroundColor", "Section Hover Background", "Color and alpha behind a section title while hovered.", true))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("entryBackgroundColor", "Entry Background", "Normal color and alpha behind recommendation entries.", true),
        ColorPicker("entryHoverBackgroundColor", "Entry Hover Background", "Color and alpha behind a recommendation while hovered.", true))
    y = y - h

    _, h = W:SectionHeader(parent, "BORDER", y); y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("borderTexture", "Border Style", borderValues, borderOrder, "Solid and installed EllesmereUI or SharedMedia border styles."),
        Slider("borderSize", "Border Size", 0, 4, 1, "Set to zero to hide the window border."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("borderColor", "Border Color", "Border color and opacity.", true, function() return (tonumber(ns.Get("borderSize")) or 0) <= 0 end),
        nil)
    y = y - h

    local titleHidden = function() return ns.Get("titleBarMode") == "hidden" end
    local titleNotFilled = function() return ns.Get("titleBarMode") ~= "filled" end
    local titleTextHidden = function() return titleHidden() or not ns.Get("showTitleText") end
    local customTitleColorDisabled = function() return ns.Get("titleTextColorMode") ~= "custom" end
    _, h = W:SectionHeader(parent, "TITLE BAR", y); y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("titleBarMode", "Title Bar", { filled = "Filled", transparent = "Transparent", hidden = "Hidden" },
            { "filled", "transparent", "hidden" }, "Hidden removes the title bar; the collapse control remains in the tracker pane.", nil, true),
        Slider("titleBarHeight", "Title Bar Height", 20, 40, 1, "Height of the title bar.", titleHidden))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("titleBarColor", "Title Bar Color", "Filled title bar color and opacity.", true, titleNotFilled),
        StyleToggle("showTitleText", "Show Title Text", "Shows Adventure Tracker in the title bar.", titleHidden, true))
    y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("titleTextColorMode", "Title and Minimize Color",
            { custom = "Custom", class = "Class Color", accent = "Accent Color" },
            { "custom", "class", "accent" }, "Colors the title and Quest Tracker-style collapse glyph.", nil, true),
        ColorPicker("titleTextColor", "Custom Title Color", "Custom color shared by the title and collapse glyph.", true,
            customTitleColorDisabled))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("titleFontSize", "Title Font Size", 8, 24, 1, "Font size shared by the title and collapse glyph."),
        Dropdown("titleAlignment", "Title Alignment", { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
            { "LEFT", "CENTER", "RIGHT" }, "Horizontal title alignment.", titleTextHidden))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("titleSeparatorSize", "Bottom Separator", 0, 4, 1, "Optional divider beneath the title bar.", titleHidden),
        ColorPicker("titleSeparatorColor", "Separator Color", "Title-bar divider color and opacity.", true,
            function() return titleHidden() or (tonumber(ns.Get("titleSeparatorSize")) or 0) <= 0 end))
    y = y - h

    _, h = W:SectionHeader(parent, "TEXT", y); y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("textFont", "Tracker Font", fontValues, fontOrder, "Font face shared by every text element in the tracker."),
        Dropdown("textOutline", "Font Outline", { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
            { "NONE", "OUTLINE", "THICKOUTLINE" }, "Outline shared by every tracker font."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("contextFontSize", "Context Font Size", 8, 24, 1, "Size of the zone, class, specialization and role line."),
        TextColorMode("contextTextColorMode", "Context Text Color", "Use the player class, EllesmereUI accent, or a custom context/status color."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("contextTextColor", "Custom Context Color", "Custom color and alpha of the context and status line.", true,
            CustomColorDisabled("contextTextColorMode")),
        nil)
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("sectionFontSize", "Section Font Size", 8, 24, 1, "Size of collapsible section titles."),
        TextColorMode("sectionTextColorMode", "Section Text Color", "Use the player class, EllesmereUI accent, or a custom section-title color."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("sectionTextColor", "Custom Section Color", "Custom color and alpha of section titles.", true,
            CustomColorDisabled("sectionTextColorMode")),
        nil)
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("entryLabelFontSize", "Entry Label Font Size", 8, 24, 1, "Size of recommendation entry labels."),
        TextColorMode("entryLabelTextColorMode", "Entry Label Color", "Use the player class, EllesmereUI accent, or a custom recommendation-label color."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("entryLabelTextColor", "Custom Entry Label Color", "Custom color and alpha of recommendation labels.", true,
            CustomColorDisabled("entryLabelTextColorMode")),
        nil)
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("entryDetailFontSize", "Entry Detail Font Size", 8, 24, 1, "Size of recommendation detail text."),
        TextColorMode("entryDetailTextColorMode", "Entry Detail Color", "Use the player class, EllesmereUI accent, or a custom recommendation-detail color."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("entryDetailTextColor", "Custom Entry Detail Color", "Custom color and alpha of recommendation details.", true,
            CustomColorDisabled("entryDetailTextColorMode")),
        nil)
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("badgeFontSize", "Icon Badge Font Size", 8, 24, 1, "Size of small text badges on readiness icons."),
        TextColorMode("badgeTextColorMode", "Icon Badge Text Color", "Use the player class, EllesmereUI accent, or a custom readiness-badge color."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorPicker("badgeTextColor", "Custom Icon Badge Color", "Custom color and alpha of readiness icon badge text.", true,
            CustomColorDisabled("badgeTextColorMode")),
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
        local food = Toggle("trackFood", "Food Buff", "Tracks Well Fed and known Forever food buffs. An owned-food recommendation can be eaten through WoW's secure hardware-click action while out of combat.")
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
    elseif pageName == "Class & Role" then
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

        _, h = W:SectionHeader(parent, "ROLE-CRITICAL ALERTS", y); y = y - h
        local roleAlertsDisabled = function() return not ns.Get("roleCriticalAlerts") end
        _, h = W:DualRow(parent, y,
            Toggle("roleCriticalAlerts", "Missing Role Buff Glow",
                "Adds a breathing red border when a tracked long-lived class ability is missing while this character has a group role selected."),
            Slider("roleAlertMinDuration", "Minimum Expected Duration", 0, 60, 1,
                "Only abilities normally lasting at least this many minutes receive the red breathing alert. Set zero to include short-duration abilities.",
                roleAlertsDisabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("trackPartyClassBuffs", "Check Party Members",
                "When a non-Solo role is selected, checks living connected party members for party-wide class buffs and summarizes who is missing them."),
            Label("The five-minute default excludes short-cycle effects such as seals while retaining preparation buffs such as Righteous Fury."))
        y = y - h

        _, h = W:SectionHeader(parent, "BUFF EQUIVALENCE", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Camp Benefits can satisfy matching buff families.", "The first preview recognizes Incense Candle as Intellect coverage and First Aid Kit as Fortitude coverage."),
            Label("More camp and world-buff families will be added from verified Forever data."))
        y = y - h
    else
        _, h = W:SectionHeader(parent, "TALENT POINTS", y); y = y - h
        local suppressBlizzard = Toggle("hideBlizzardTalentReminder", "Hide Blizzard Talent Callout",
            "Suppresses only Blizzard's unspent-talent callout that points at the microbar. Other microbutton alerts are unchanged.")
        suppressBlizzard.setValue = function(value)
            ns.Set("hideBlizzardTalentReminder", value)
            if value and ns.ApplyTalentAlertSuppression then ns.ApplyTalentAlertSuppression() end
        end
        _, h = W:DualRow(parent, y,
            Toggle("showTalentReminder", "Adventure Tracker Reminder", "Shows an actionable row while class or hero talent points are unspent."),
            suppressBlizzard)
        y = y - h
        _, h = W:DualRow(parent, y,
            Label("The reminder opens the Talents window when clicked."),
            Label("Blizzard's reminder is hidden because the EllesmereUI microbar may not be visible."))
        y = y - h

        _, h = W:SectionHeader(parent, "CLASS TRAINING", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showClassTrainerSkills", "Available Class-Trainer Skills",
                "Lists every skill currently available at the last class trainer visited and totals their training cost."),
            Label("Visit a class trainer once to scan. Click the summary row to expand the individual skills."))
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
        Toggle("showLegacyProfessionGoals", "Profession Checkpoint Goals", "Shows the next 150, 225 or 300 crafting-skill goal in the Legacy section."),
        { type = "button", text = "Open Legacy Window", onClick = function()
            if not InCombatLockdown() and ToggleLegacySystemUI then ToggleLegacySystemUI() end
          end })
    y = y - h

    _, h = W:SectionHeader(parent, "RECOMMENDATIONS", y); y = y - h
    _, h = W:DualRow(parent, y,
        Label("Profession goals state the target skill itself instead of showing an unexplained point count."),
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
            Toggle("showMissingWorldBuffs", "Show Additional Missing Buffs", "Shows other known world buffs you do not have, including where to obtain them. Your faction's Rend buff is always tracked."),
            Slider("worldBuffWarnMinutes", "Expiring Soon", 0, 60, 1, "An active world buff becomes amber this many minutes before it expires."))
        y = y - h

        _, h = W:SectionHeader(parent, "DEFAULT BEHAVIOR", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Might of Stormwind or Warchief's Blessing stays visible with an acquisition hint when missing."),
            Label("Other missing buffs are opt-in so the tracker does not treat every possible world buff as mandatory."))
        y = y - h
    else
        _, h = W:SectionHeader(parent, "ACQUISITION SOURCES", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("worldBuffCurrentZoneOnly", "Only Additional Buffs Available Here", "Limits optional missing buffs to those obtainable in the current zone. Your faction's Rend buff stays visible everywhere."),
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
            Toggle("showProfessions", "Enable Profession Sections", "Shows profession plans and local opportunities.", true),
            Toggle("showProfessionProgress", "Rank Guidance", "Shows when the next profession rank becomes trainable and how many skill-ups remain."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionSynergy", "Skill-up and Gathering Plan", "Recommends a learned skill-up recipe and uses a paired gathering profession when its materials can be gathered."),
            Toggle("showProfessionGear", "Useful Crafted Gear", "Recommends a usable learned craft, preferring an upgrade over currently equipped gear."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionCaps", "Trainer Rank Reminders", "Shows as soon as the next profession rank is trainable, not only after reaching the current cap."),
            Toggle("showCompletedProfessions", "Show Completed Professions", "Keeps professions visible after their final rank is complete."))
        y = y - h

        _, h = W:SectionHeader(parent, "TRAINER RECIPES", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionTrainerRecipes", "Available Unlearned Recipes",
                "Shows a collapsible list and total cost for recipes currently learnable from the last trainer visited for each profession."),
            Label("Visit each profession trainer once to scan its current offerings and prices."))
        y = y - h

        _, h = W:SectionHeader(parent, "LIVE RECIPE DATA", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Open a profession once to let Adventure Tracker evaluate its learned recipes, reagents and outputs."),
            Label("Legacy skill checkpoints now appear in the Legacy section; gathering skills remain visible here."))
        y = y - h
    else
        _, h = W:SectionHeader(parent, "CURRENT ZONE", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionZoneHints", "Local Gathering Hints", "Shows contextual reminders for Herbalism, Mining, Skinning and Fishing in the current zone."),
            nil)
        y = y - h

        _, h = W:SectionHeader(parent, "DATA SOURCES", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Herb, ore and fishing summaries use the attributed, coordinate-free Forever Nodes catalogue."),
            Label("Skill-up and crafted-gear plans use the character's learned recipes, bags and equipped items."))
        y = y - h
    end
    return math.abs(y)
end

local function BuildInstances(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    _, h = W:SectionHeader(parent, "INSTANCE TRACKING", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("showInstances", "Enable Instance Sections", "Shows timers, known missing quests and spec-filtered upgrades while inside a dungeon or raid.", true),
        Toggle("showInstanceRunTimer", "Instance Run Timer", "Starts on entry and records a per-character personal best when the final boss or dungeon-completion event is detected."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("showInstanceBossTimer", "Boss Encounter Timer", "Shows the current boss duration and the per-character personal best for this difficulty. It remains visible during the encounter even when Hide in Combat is enabled."),
        Label("Personal bests are separated by character, instance and difficulty."))
    y = y - h

    _, h = W:SectionHeader(parent, "INSTANCE QUESTS", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("showInstanceQuests", "Known Missing Quests", "Lists eligible, incomplete instance quests that are not already in the quest log. No coordinates, routes or objectives are shown."),
        Slider("instanceQuestLimit", "Maximum Quest Suggestions", 1, 20, 1, "Limits visible quest suggestions so a large dungeon quest set does not overwhelm the tracker."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Label("NPC-started quests show the giver. Item-started quests show the item and the mobs that drop it."),
        Label((_G.LibQuestieDB and "QuestieDB detected." or "QuestieDB is not installed or enabled."), "QuestieDB is an optional runtime provider; Adventure Tracker does not copy its database or expose its map data."))
    y = y - h

    _, h = W:SectionHeader(parent, "DUNGEON UPGRADES", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("showInstanceLoot", "Spec-Filtered Upgrade Drops", "Uses the Encounter Journal's current class and specialization filter, then keeps only equippable item-level upgrades."),
        Slider("instanceLootLimit", "Maximum Upgrade Suggestions", 1, 20, 1, "Limits visible dungeon upgrade suggestions."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Label("Each suggestion names the dropping encounter and compares its item level with the relevant equipped slot."),
        Label((type(EJ_GetNumLoot) == "function" and type(EJ_SetLootFilter) == "function")
            and "Encounter Journal loot data detected." or "Encounter Journal loot data is unavailable on this client."))
    y = y - h
    return math.abs(y)
end

local function BuildTravelStatus(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    if pageName == "Flight Timer" then
        local textureValues, textureOrder = { none = "Solid" }, { "none" }
        if EUI.BuildBarTextureTables then
            local _, names, order = EUI.BuildBarTextureTables()
            if type(names) == "table" and type(order) == "table" then textureValues, textureOrder = names, order end
        end
        local borderValues, borderOrder = { solid = "Solid" }, { "solid" }
        if EUI.GetBorderTextureDropdown then borderValues, borderOrder = EUI.GetBorderTextureDropdown() end
        local fontValues, fontOrder = { __global = "EUI Global Font" }, { "__global" }
        if EUI.BuildFontDropdownData then fontValues, fontOrder = EUI.BuildFontDropdownData() end
        local disabled = function() return not ns.Get("showFlightTimer") end
        local customFillDisabled = function()
            return not ns.Get("showFlightTimer") or ns.Get("flightTimerFillColorMode") ~= "custom"
        end

        _, h = W:SectionHeader(parent, "TRACKER FLIGHT TIMER", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showFlightTimer", "Show While In Flight", "Shows a compact destination, clock and progress bar inside Adventure Tracker during flight-master travel.", true),
            Toggle("flightTimerLearnTimes", "Learn Actual Route Times", "Records clean completed flights by their complete route and uses their rolling median for future estimates."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("flightTimerShowIcon", "Show Flight Icon", "Shows the flight-master icon beside the timer."),
            { type = "button", text = "Clear Learned Route Times", tooltip = "Forgets only Adventure Tracker's flight history. Native and Custom Tweaks flight data are unchanged.",
              onClick = function()
                  if ns.ResetFlightTimerRoutes then ns.ResetFlightTimerRoutes() end
                  if EUI.RefreshPage then EUI:RefreshPage() end
              end })
        y = y - h
        _, h = W:DualRow(parent, y,
            Label("This timer has its own route history and appearance settings."),
            Label("It does not read or overwrite the native flight timer or Custom Tweaks settings."))
        y = y - h

        _, h = W:SectionHeader(parent, "TEXT CONTENT", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("flightTimerShowDestination", "Show Destination", "Shows the final or early-landing destination in the timer label."),
            Toggle("flightTimerShowElapsed", "Show Elapsed Time", "Adds elapsed flight time to the detail line."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("flightTimerShowRemaining", "Show Remaining Time", "Shows the estimated time until landing."),
            Toggle("flightTimerShowTotal", "Show Total Time", "Shows the full estimated route duration."))
        y = y - h

        _, h = W:SectionHeader(parent, "PROGRESS BAR", y); y = y - h
        _, h = W:DualRow(parent, y,
            Slider("flightTimerBarHeight", "Bar Height", 2, 24, 1, "Height of the tracker flight progress bar.", disabled),
            Dropdown("flightTimerBarTexture", "Bar Texture", textureValues, textureOrder, "Texture used by both the fill and its independent background.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Dropdown("flightTimerFillColorMode", "Fill Color", { custom = "Custom", class = "Class Color", accent = "Accent Color" },
                { "custom", "class", "accent" }, "Color source for the progress fill.", disabled, true),
            ColorPicker("flightTimerFillColor", "Custom Fill Color", "Custom progress-fill color and opacity.", true, customFillDisabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            ColorPicker("flightTimerBackgroundColor", "Bar Background", "Background color and opacity behind the flight progress.", true, disabled),
            Dropdown("flightTimerBorderTexture", "Border Style", borderValues, borderOrder, "Independent border style for the flight progress bar.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Slider("flightTimerBorderSize", "Border Size", 0, 4, 1, "Set to zero to hide the flight progress border.", disabled),
            ColorPicker("flightTimerBorderColor", "Border Color", "Flight progress border color and opacity.", true,
                function() return disabled() or (tonumber(ns.Get("flightTimerBorderSize")) or 0) <= 0 end))
        y = y - h

        _, h = W:SectionHeader(parent, "FLIGHT TYPOGRAPHY", y); y = y - h
        _, h = W:DualRow(parent, y,
            Dropdown("flightTimerFont", "Flight Font", fontValues, fontOrder, "Font used only by the tracker flight timer.", disabled),
            Dropdown("flightTimerFontOutline", "Flight Font Outline", { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
                { "NONE", "OUTLINE", "THICKOUTLINE" }, "Outline used only by the tracker flight timer.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Slider("flightTimerDestinationFontSize", "Destination Font Size", 8, 24, 1, "Size of the flight destination label.", disabled),
            TextColorMode("flightTimerDestinationColorMode", "Destination Color", "Use the player class, EllesmereUI accent, or a custom flight-destination color.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            ColorPicker("flightTimerDestinationColor", "Custom Destination Color", "Custom color and alpha of the flight destination label.", true,
                CustomColorDisabled("flightTimerDestinationColorMode", disabled)),
            nil)
        y = y - h
        _, h = W:DualRow(parent, y,
            Slider("flightTimerTimeFontSize", "Time Font Size", 8, 24, 1, "Size of elapsed, remaining and total time.", disabled),
            TextColorMode("flightTimerTimeColorMode", "Time Detail Color", "Use the player class, EllesmereUI accent, or a custom flight-time detail color.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            ColorPicker("flightTimerTimeColor", "Custom Time Detail Color", "Custom color and alpha of the flight time detail.", true,
                CustomColorDisabled("flightTimerTimeColorMode", disabled)),
            nil)
        y = y - h
    else
        _, h = W:SectionHeader(parent, "ACTIVITY STATUSES", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showStatuses", "Show Activity Statuses", "Adds compact live status labels beside the zone, class, specialization and role context."),
            Label("Statuses appear only while applicable so the context line stays compact."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showFlightStatus", "In Flight", "Shows In Flight during flight-master travel."),
            Toggle("showCombatStatus", "In Combat", "Shows In Combat while the character is fighting."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showRestingStatus", "Resting", "Shows Resting in inns, cities and other rested areas."),
            Toggle("showMountedStatus", "Mounted", "Shows Mounted outside flight-master travel."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showInstanceStatus", "Instance Type", "Shows Dungeon, Raid, Battleground, Arena or Scenario while inside one."),
            Toggle("showLifeStatus", "Dead or Ghost", "Shows Dead or Ghost when applicable."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showPresenceStatus", "AFK or DND", "Shows the character's AFK or Do Not Disturb state."),
            nil)
        y = y - h

        _, h = W:SectionHeader(parent, "PLAYTIME", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showPlaytime", "Enable Playtime Status", "Enables the session clock in the main status row and its hover details."),
            Label("The session clock appears immediately after Resting when that status is active."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showSessionPlaytime", "Show Session Timer", "Shows a live minutes:seconds clock, adding hours only after the first hour."),
            Toggle("showTotalPlaytime", "Include Total /played", "Adds the character's server-reported total played time to the session timer tooltip."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Label("Hover the session timer for a verbose current-session and total-played explanation."),
            nil)
        y = y - h

        _, h = W:SectionHeader(parent, "CURRENCY", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showGoldStatus", "Show Character Gold", "Shows carried money in the status row with gold, silver and copper icons."),
            Label("Hover it for session changes, the character's lifetime statistic when available, and balances recorded for other characters."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Label("Other-character balances come from EllesmereUI's shared ledger and refresh after those characters are played."),
            Label("Status, playtime and currency text use the Tracker Context font size and color mode."))
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
                description = "Window layout, visibility and appearance.",
                pages = { "Settings" }, buildPage = BuildTracker,
                onReset = function() ns.ResetKeys(TRACKER_KEYS) end,
            },
            {
                key = "readiness", title = "Readiness",
                description = "Camp, rest, food and class preparation.",
                pages = { "Essentials", "Class & Role", "Reminders" }, buildPage = BuildReadiness,
                onReset = function()
                    ns.ResetKeys(READINESS_KEYS)
                    ns.ResetKeys(REMINDER_KEYS)
                end,
            },
            {
                key = "world-buffs", title = "World Buffs",
                description = "Active world buffs and where missing ones come from.",
                pages = { "Tracking", "Sources" }, buildPage = BuildWorldBuffs,
                onReset = function() ns.ResetKeys(WORLD_BUFF_KEYS) end,
            },
            {
                key = "travel-status", title = "Travel & Status",
                description = "Tracker flight timer, activity statuses, playtime and character gold.",
                pages = { "Flight Timer", "Statuses & Playtime" }, buildPage = BuildTravelStatus,
                onReset = function()
                    ns.ResetKeys(FLIGHT_KEYS)
                    ns.ResetKeys(STATUS_KEYS)
                end,
            },
            {
                key = "instances", title = "Instances",
                description = "Dungeon timers, missing quests and spec-filtered upgrades.",
                pages = { "Tracking" }, buildPage = BuildInstances,
                onReset = function() ns.ResetKeys(INSTANCE_KEYS) end,
            },
            {
                key = "legacy", title = "Legacy",
                description = "Legacy points and current-zone opportunities.",
                pages = { "Overview" }, buildPage = BuildLegacy,
                onReset = function() ns.ResetKeys(LEGACY_KEYS) end,
            },
            {
                key = "professions", title = "Professions",
                description = "Rank goals, skill-up plans, crafted gear and local resources.",
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
