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
            if key == "locked" then
                ns.Set(key, value, true)
                if ns.ApplyLockState then ns.ApplyLockState() end
            else
                ns.Set(key, value)
            end
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
            ns.Set(key, value, true)
            if ns.InvalidateForSetting then ns.InvalidateForSetting(key) end
            if ns.ApplySettings then ns.ApplySettings() end
        end,
    }
end

local function Label(text, tooltip)
    return { type = "label", text = text, tooltip = tooltip }
end

local function AppearanceSet(key, value, refreshPage)
    ns.Set(key, value, true)
    if ns.InvalidateForSetting then ns.InvalidateForSetting(key, "appearance setting") end
    if ns.ApplySettings then ns.ApplySettings() end
    if refreshPage and EUI.RefreshPage then EUI:RefreshPage() end
end

local function Dropdown(key, text, values, order, tooltip, disabled, refreshPage)
    return {
        type = "dropdown", text = text, values = values, order = order,
        tooltip = tooltip, disabled = disabled,
        getValue = function() return ns.Get(key) end,
        setValue = function(value) AppearanceSet(key, value, refreshPage) end,
    }
end

local function ColorSwatches(modeKey, colorKey, text, disabled)
    local function SetMode(mode)
        AppearanceSet(modeKey, mode, true)
    end
    local function ClassColor()
        if EUI.GetPlayerClassColor then
            local ok, r, g, b = pcall(EUI.GetPlayerClassColor)
            if ok and r and g and b then return r, g, b, 1 end
        end
        return 1, 1, 1, 1
    end
    local function AccentColor()
        if EUI.GetAccentColor then
            local ok, r, g, b = pcall(EUI.GetAccentColor)
            if ok and r and g and b then return r, g, b, 1 end
        end
        return 1, 1, 1, 1
    end
    local function CustomColor()
        local color = ns.Get(colorKey)
        local fallback = ns.DEFAULTS[colorKey] or {}
        if type(color) ~= "table" then color = fallback end
        return color.r or fallback.r or 1, color.g or fallback.g or 1,
            color.b or fallback.b or 1, color.a == nil and (fallback.a or 1) or color.a
    end

    return {
        type = "multiSwatch", text = text, disabled = disabled,
        swatches = {
            {
                tooltip = "Class Color", hasAlpha = false,
                getValue = ClassColor, setValue = function() end,
                onClick = function() SetMode("class") end,
                refreshAlpha = function() return ns.Get(modeKey) == "class" and 1 or 0.3 end,
            },
            {
                tooltip = "Accent Color", hasAlpha = false,
                getValue = AccentColor, setValue = function() end,
                onClick = function() SetMode("accent") end,
                refreshAlpha = function() return ns.Get(modeKey) == "accent" and 1 or 0.3 end,
            },
            {
                tooltip = "Custom Color", hasAlpha = true,
                getValue = CustomColor,
                setValue = function(r, g, b, a)
                    ns.Set(modeKey, "custom", true)
                    AppearanceSet(colorKey, { r = r, g = g, b = b, a = a or 1 })
                end,
                onClick = function(self)
                    if ns.Get(modeKey) ~= "custom" then
                        SetMode("custom")
                        return
                    end
                    if self._eabOrigClick then self._eabOrigClick(self) end
                end,
                refreshAlpha = function() return ns.Get(modeKey) == "custom" and 1 or 0.3 end,
            },
        },
    }
end

local TRACKER_KEYS = {
    "enabled", "locked", "width", "scale", "frameStrata", "maximizePaneHeight", "paneGrowthDirection", "paneHeightLimitMode", "paneHeightLimitPercent", "paneHeightLimitPixels", "opacity", "position", "hideInCombat", "hideInInstances", "hideWhenReady", "showContext", "collapsedSectionsByCharacter",
    "panePadding", "backgroundColorMode", "backgroundColor", "sectionBackgroundColorMode", "sectionBackgroundColor",
    "sectionHoverBackgroundColorMode", "sectionHoverBackgroundColor", "entryBackgroundColorMode", "entryBackgroundColor",
    "entryHoverBackgroundColorMode", "entryHoverBackgroundColor", "borderTexture", "borderSize", "borderColorMode", "borderColor",
    "titleBarMode", "titleBarHeight", "titleBarColorMode", "titleBarColor",
    "titleTextColorMode", "titleTextColor", "textFont", "textOutline", "titleFontSize", "contextFontSize", "statusTextAlignment", "contextTextColorMode", "contextTextColor",
    "sectionFontSize", "sectionTextColorMode", "sectionTextColor", "entryLabelFontSize", "entryLabelTextColorMode", "entryLabelTextColor",
    "entryDetailFontSize", "entryDetailTextColorMode", "entryDetailTextColor",
    "titleAlignment", "titleSeparatorSize", "titleSeparatorColorMode", "titleSeparatorColor", "runtimeFrameBudgetPercent",
}
local READINESS_KEYS = {
    "showReadiness", "readinessIconSize", "readinessIconSpacing", "readinessIconBorderTexture", "readinessIconBorderSize",
    "readinessIconReadyBorderColorMode", "readinessIconReadyBorderColor", "readinessIconWarningBorderColorMode", "readinessIconWarningBorderColor",
    "readinessIconMissingBorderColorMode", "readinessIconMissingBorderColor", "readinessIconUnavailableBorderColorMode", "readinessIconUnavailableBorderColor",
    "readinessIconUnknownBorderColorMode", "readinessIconUnknownBorderColor", "readinessIconInfoBorderColorMode", "readinessIconInfoBorderColor",
    "badgeFontSize", "badgeTextColorMode", "badgeTextColor", "badgeAnchor", "badgeOffsetX", "badgeOffsetY",
    "trackCamp", "trackSleepingBag", "trackFood", "trackClassBuffs", "trackWeaponEnhancements", "readinessWarnMinutes",
    "showCompletedReadiness", "roleByCharacter", "lastClassBuffSpellsByCharacter", "roleCriticalAlerts", "roleAlertMinDuration", "trackPartyClassBuffs",
}
local REMINDER_KEYS = { "showTalentReminder", "showClassTrainerSkills", "hideBlizzardTalentReminder" }
local WORLD_BUFF_KEYS = { "showWorldBuffs", "showActiveWorldBuffs", "showMissingWorldBuffs", "worldBuffCurrentZoneOnly", "worldBuffWarnMinutes" }
local LEGACY_KEYS = { "showLegacy", "showUnspentLegacy", "showLegacyProfessionGoals", "showLegacyChallenges", "legacyChallengeLimit" }
local QUEST_KEYS = {
    "showZoneQuests", "zoneQuestExpandedByCharacter", "zoneQuestVisitedByCharacter",
    "warnFutureQuestItems", "futureQuestItemsByCharacter",
}
local PROFESSION_KEYS = { "showProfessions", "showProfessionProgress", "showProfessionSynergy", "showProfessionGear", "showProfessionCaps", "showProfessionTrainerRecipes", "showProfessionMarketCosts", "showProfessionAttainableRecipes", "showObservedGathering", "professionRecipeCatalogExpandedByCharacter", "showCompletedProfessions", "showProfessionZoneHints", "showProviderDiagnostics" }
local INSTANCE_KEYS = { "showInstances", "showInstanceRunTimer", "showInstanceBossTimer", "showInstanceQuests", "showInstanceLoot", "instanceQuestLimit", "instanceLootLimit" }
local FLIGHT_KEYS = {
    "showFlightTimer", "flightTimerShowDestination", "flightTimerShowElapsed", "flightTimerShowRemaining", "flightTimerShowTotal",
    "flightTimerLearnTimes", "flightTimerShowIcon", "flightTimerBarHeight", "flightTimerBarTexture", "flightTimerFillColorMode",
    "flightTimerFillColor", "flightTimerBackgroundColorMode", "flightTimerBackgroundColor", "flightTimerBorderTexture", "flightTimerBorderSize",
    "flightTimerBorderColorMode", "flightTimerBorderColor",
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
        { type = "button", text = "Reset Position", tooltip = "Returns the tracker to its default screen position, width, scale, growth behavior and height limit.",
          onClick = function() ns.ResetKeys({ "position", "width", "scale", "maximizePaneHeight", "paneGrowthDirection", "paneHeightLimitMode", "paneHeightLimitPercent", "paneHeightLimitPixels" }) end },
        { type = "button", text = "Reset Appearance", tooltip = "Restores spacing, backgrounds, border, title bar and text defaults.",
          onClick = function()
              ns.ResetKeys({ "frameStrata", "opacity", "panePadding", "backgroundColorMode", "backgroundColor",
                  "sectionBackgroundColorMode", "sectionBackgroundColor", "sectionHoverBackgroundColorMode", "sectionHoverBackgroundColor",
                  "entryBackgroundColorMode", "entryBackgroundColor", "entryHoverBackgroundColorMode", "entryHoverBackgroundColor",
                  "borderTexture", "borderSize", "borderColorMode", "borderColor", "titleBarMode",
                  "titleBarHeight", "titleBarColorMode", "titleBarColor", "titleTextColorMode", "titleTextColor", "textFont", "textOutline", "titleFontSize",
                  "contextFontSize", "statusTextAlignment", "contextTextColorMode", "contextTextColor", "sectionFontSize", "sectionTextColorMode", "sectionTextColor",
                  "entryLabelFontSize", "entryLabelTextColorMode", "entryLabelTextColor", "entryDetailFontSize", "entryDetailTextColorMode",
                  "entryDetailTextColor", "titleAlignment", "titleSeparatorSize", "titleSeparatorColorMode", "titleSeparatorColor" })
          end })
    y = y - h

    _, h = W:SectionHeader(parent, "SIZE AND SPACING", y); y = y - h
    _, h = W:DualRow(parent, y,
        Slider("width", "Window Width", 280, 480, 5, "Width of the Adventure Tracker window."),
        Slider("scale", "Window Scale", 0.65, 1.50, 0.05, "Overall scale of the Adventure Tracker window."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("panePadding", "Pane Padding", 0, 24, 1, "Space between the pane edges and tracker contents on all sides."),
        Toggle("showContext", "Show Zone, Level, Class, Spec, Group and Role", "Shows the current zone, character level, class, dominant Forever talent tree, live Solo, Party or Raid context, and any specifically selected activity role above the readiness icons."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("maximizePaneHeight", "Allow Full Viewport Height", "Allows an unanchored pane to use all safe screen space in the selected growth direction instead of the normal 75% screen-height limit. A dynamic EllesmereUI anchor always uses the safe space between its fixed edge and the viewport."),
        Dropdown("paneGrowthDirection", "Pane Growth Direction", { DOWN = "Down", UP = "Up" }, { "DOWN", "UP" }, "Keeps an unanchored pane's top edge fixed when growing down, or its bottom edge fixed when growing up. A vertical EllesmereUI anchor determines the anchored pane's growth edge."))
    y = y - h
    local percentLimitDisabled = function() return ns.Get("paneHeightLimitMode") ~= "PERCENT" end
    local pixelLimitDisabled = function() return ns.Get("paneHeightLimitMode") ~= "PIXELS" end
    _, h = W:DualRow(parent, y,
        Dropdown("paneHeightLimitMode", "Pane Height Limit", {
            AUTO = "Automatic", PERCENT = "Viewport Percent", PIXELS = "UI Pixels",
        }, { "AUTO", "PERCENT", "PIXELS" },
            "Optionally caps the total pane height to a percentage of the viewport or an absolute number of UI pixels. The pane never exceeds the safe space available from its fixed edge.", nil, true),
        Label("A custom limit overrides the normal or full-viewport cap, but never overrides a dynamic anchor or the screen edge."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("paneHeightLimitPercent", "Height Limit (%)", 10, 100, 1, "Maximum total pane height as a percentage of the full viewport height.", percentLimitDisabled),
        Slider("paneHeightLimitPixels", "Height Limit (UI px)", 120, 1600, 10, "Maximum total pane height in UI pixels before the tracker reaches its anchored or selected viewport edge.", pixelLimitDisabled))
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
        ColorSwatches("backgroundColorMode", "backgroundColor", "Main Pane Background"),
        Slider("opacity", "Main Pane Opacity", 0.00, 1.00, 0.05, "Additional opacity for only the main pane background; text, title and entry backgrounds are unaffected."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorSwatches("sectionBackgroundColorMode", "sectionBackgroundColor", "Section Background"),
        ColorSwatches("sectionHoverBackgroundColorMode", "sectionHoverBackgroundColor", "Section Hover Background"))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorSwatches("entryBackgroundColorMode", "entryBackgroundColor", "Entry Background"),
        ColorSwatches("entryHoverBackgroundColorMode", "entryHoverBackgroundColor", "Entry Hover Background"))
    y = y - h

    _, h = W:SectionHeader(parent, "BORDER", y); y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("borderTexture", "Border Style", borderValues, borderOrder, "Solid and installed EllesmereUI or SharedMedia border styles."),
        Slider("borderSize", "Border Size", 0, 4, 1, "Set to zero to hide the window border."))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorSwatches("borderColorMode", "borderColor", "Border Color", function() return (tonumber(ns.Get("borderSize")) or 0) <= 0 end),
        nil)
    y = y - h

    local titleHidden = function() return ns.Get("titleBarMode") == "hidden" end
    local titleNotFilled = function() return ns.Get("titleBarMode") ~= "filled" end
    _, h = W:SectionHeader(parent, "TITLE BAR", y); y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("titleBarMode", "Title Bar", { filled = "Filled", transparent = "Transparent", hidden = "Hidden" },
            { "filled", "transparent", "hidden" }, "Hidden removes the title bar; the collapse control remains in the tracker pane.", nil, true),
        Slider("titleBarHeight", "Title Bar Height", 20, 40, 1, "Height of the title bar.", titleHidden))
    y = y - h
    _, h = W:DualRow(parent, y,
        ColorSwatches("titleBarColorMode", "titleBarColor", "Title Bar Color", titleNotFilled),
        ColorSwatches("titleTextColorMode", "titleTextColor", "Title and Minimize Color"))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("titleFontSize", "Title Font Size", 8, 24, 1, "Font size shared by the title and collapse glyph."),
        Dropdown("titleAlignment", "Title Alignment", { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
            { "LEFT", "CENTER", "RIGHT" }, "Horizontal title alignment.", titleHidden))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("titleSeparatorSize", "Bottom Separator Padding", 0, 4, 1, "Colored spacing beneath the title bar that increases the pane height by the selected number of pixels.", titleHidden),
        ColorSwatches("titleSeparatorColorMode", "titleSeparatorColor", "Separator Color",
            function() return titleHidden() or (tonumber(ns.Get("titleSeparatorSize")) or 0) <= 0 end))
    y = y - h

    _, h = W:SectionHeader(parent, "TEXT", y); y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("textFont", "Tracker Font", fontValues, fontOrder, "Font face shared by every text element in the tracker."),
        Dropdown("textOutline", "Font Outline", { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
            { "NONE", "OUTLINE", "THICKOUTLINE" }, "Outline shared by every tracker font."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("contextFontSize", "Context Font Size", 8, 24, 1, "Size of the zone, class, specialization, group-context and selected-role line."),
        ColorSwatches("contextTextColorMode", "contextTextColor", "Context Text Color"))
    y = y - h
    _, h = W:DualRow(parent, y,
        Dropdown("statusTextAlignment", "Status Row Alignment", { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
            { "LEFT", "CENTER", "RIGHT" }, "Horizontal alignment of the complete zone, class, group context, role, activity, session and currency status line."),
        Label("The readiness icon row remains independently centered."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("sectionFontSize", "Section Font Size", 8, 24, 1, "Size of collapsible section titles."),
        ColorSwatches("sectionTextColorMode", "sectionTextColor", "Section Text Color"))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("entryLabelFontSize", "Entry Label Font Size", 8, 24, 1, "Size of recommendation entry labels."),
        ColorSwatches("entryLabelTextColorMode", "entryLabelTextColor", "Entry Label Color"))
    y = y - h
    _, h = W:DualRow(parent, y,
        Slider("entryDetailFontSize", "Entry Detail Font Size", 8, 24, 1, "Size of recommendation detail text."),
        ColorSwatches("entryDetailTextColorMode", "entryDetailTextColor", "Entry Detail Color"))
    y = y - h

    _, h = W:SectionHeader(parent, "PERFORMANCE", y); y = y - h
    _, h = W:DualRow(parent, y,
        Slider("runtimeFrameBudgetPercent", "Background Work per Frame (%)", 5, 100, 1,
            "Percentage of each frame Adventure Tracker may use for queued analysis and layout work. Higher values finish loading sooner. At 100%, queued work may consume an entire frame and cause visible hitching."),
        Label("10% is the balanced default. Values above 25% are intended for performance testing on faster systems."))
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

        local disabled = function() return not ns.Get("showReadiness") end
        local borderDisabled = function()
            return disabled() or (tonumber(ns.Get("readinessIconBorderSize")) or 0) <= 0
        end
        local borderValues, borderOrder = { solid = "Solid" }, { "solid" }
        if EUI.GetBorderTextureDropdown then borderValues, borderOrder = EUI.GetBorderTextureDropdown() end

        _, h = W:SectionHeader(parent, "ICON LAYOUT", y); y = y - h
        _, h = W:DualRow(parent, y,
            Slider("readinessIconSize", "Icon Size", 20, 64, 1, "Size of each readiness icon. Icons wrap into centered additional rows when needed.", disabled),
            Slider("readinessIconSpacing", "Icon Spacing", 0, 24, 1, "Horizontal and vertical space between readiness icons.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Dropdown("readinessIconBorderTexture", "Border Style", borderValues, borderOrder, "Solid and installed EllesmereUI or SharedMedia border styles.", borderDisabled),
            Slider("readinessIconBorderSize", "Border Size", 0, 4, 1, "Thickness of the readiness icon border. Set zero to hide it.", disabled))
        y = y - h

        _, h = W:SectionHeader(parent, "BORDER STATE COLORS", y); y = y - h
        _, h = W:DualRow(parent, y,
            ColorSwatches("readinessIconReadyBorderColorMode", "readinessIconReadyBorderColor", "Ready", borderDisabled),
            ColorSwatches("readinessIconWarningBorderColorMode", "readinessIconWarningBorderColor", "Warning", borderDisabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            ColorSwatches("readinessIconMissingBorderColorMode", "readinessIconMissingBorderColor", "Missing", borderDisabled),
            ColorSwatches("readinessIconUnavailableBorderColorMode", "readinessIconUnavailableBorderColor", "Unavailable", borderDisabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            ColorSwatches("readinessIconUnknownBorderColorMode", "readinessIconUnknownBorderColor", "Unknown", borderDisabled),
            ColorSwatches("readinessIconInfoBorderColorMode", "readinessIconInfoBorderColor", "Information", borderDisabled))
        y = y - h

        _, h = W:SectionHeader(parent, "STACK TEXT", y); y = y - h
        _, h = W:DualRow(parent, y,
            Slider("badgeFontSize", "Stack Font Size", 6, 32, 1, "Font size of stack and count text drawn over readiness icons.", disabled),
            ColorSwatches("badgeTextColorMode", "badgeTextColor", "Stack Text Color", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Dropdown("badgeAnchor", "Stack Position", {
                TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
                LEFT = "Left", CENTER = "Center", RIGHT = "Right",
                BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right",
            }, { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
                "Anchor point used to position stack and count text on each readiness icon.", disabled, true),
            Label("Offsets fine-tune the selected anchor."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Slider("badgeOffsetX", "Stack Horizontal Offset", -24, 24, 1, "Moves stack text left or right from its selected anchor.", disabled),
            Slider("badgeOffsetY", "Stack Vertical Offset", -24, 24, 1, "Moves stack text down or up from its selected anchor.", disabled))
        y = y - h

        _, h = W:SectionHeader(parent, "ESSENTIALS", y); y = y - h
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
            Label("Default borders: green = ready, amber = warning and red = missing.", "Gray means unavailable, violet means unreadable, and blue is informational. Every state color is customizable above."),
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
            Label("This manual activity role controls role-specific recommendations and appears after the live Solo, Party or Raid context when it is more specific than Solo."))
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
                "Lists every skill currently available from the bundled Forever class-training catalog and totals their training cost."),
            Label("Click the summary row to expand the individual skills. Trainer visits quietly refine live prices and descriptions."))
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
    _, h = W:DualRow(parent, y,
        Toggle("showLegacyChallenges", "Contextual Legacy Challenges",
            "Uses the live achievement-to-Legacy-currency relationship and shows incomplete goals relevant to your zone, level, class, professions or current progress."),
        Slider("legacyChallengeLimit", "Maximum Challenge Suggestions", 1, 10, 1,
            "Limits contextual challenge rows after relevance and progress ranking."))
    y = y - h

    _, h = W:SectionHeader(parent, "RECOMMENDATIONS", y); y = y - h
    _, h = W:DualRow(parent, y,
        Label("Profession goals state the target skill itself instead of showing an unexplained point count."),
        Label("Recommendations come from live point-bearing achievements; unmatched or unverifiable goals remain hidden."))
    y = y - h
    return math.abs(y)
end

local function BuildQuests(pageName, parent, yOffset)
    local W, y, h = EUI.Widgets, yOffset
    if EUI.ClearContentHeader then EUI:ClearContentHeader() end
    parent._showRowDivider = true

    _, h = W:SectionHeader(parent, "QUEST PROGRESS", y); y = y - h
    _, h = W:DualRow(parent, y,
        Toggle("showZoneQuests", "Visited-Zone Quest Progress",
            "Lists eligible, incomplete quests in zones this character has entered on foot and that are not already in the quest log.", true),
        Label((_G.LibQuestieDB and "QuestieDB detected." or "QuestieDB is not installed or enabled."),
            "QuestieDB is an optional runtime provider; Adventure Tracker does not copy its database or expose map data."))
    y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("warnFutureQuestItems", "Future Quest-Material Vendor Warnings",
            "Warns when you sell an item still needed by a non-trivial, unaccepted quest in a zone this character has visited. Click the warning to buy it back while possible, or use its X to dismiss the current warning."),
        Label("Warnings cover actual item objectives up to five levels ahead.",
            "Later chain steps are intentionally considered so useful materials are not discarded before the quest itself becomes available."))
    y = y - h

    _, h = W:SectionHeader(parent, "PRESENTATION RULES", y); y = y - h
    _, h = W:DualRow(parent, y,
        Label("Each visited zone has one summary row with its quest count and combined rewards; click it to expand every available quest."),
        Label("NPC-started quests show only the giver. Item-started quests show only the item and mobs that drop it."))
    y = y - h
    _, h = W:DualRow(parent, y,
        Label("Flight-path pass-throughs, repeatable quests, unavailable chain steps, unknown starters and object-only starts are excluded."),
        Label("No coordinates, routes, objectives, pins, arrows or waypoint guidance are shown."))
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
            Toggle("showProfessionSynergy", "Skill-up and Gathering Plan", "Builds a permanent skill route from profession level, learned recipes, bags, prices and local material sources."),
            Toggle("showProfessionGear", "Useful Crafted Gear", "Recommends a usable learned craft, preferring an upgrade over currently equipped gear."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionCaps", "Trainer Rank Reminders", "Shows as soon as the next profession rank is trainable, not only after reaching the current cap."),
            Toggle("showCompletedProfessions", "Show Completed Professions", "Keeps professions visible after their final rank is complete."))
        y = y - h

        _, h = W:SectionHeader(parent, "TRAINER RECIPES", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionTrainerRecipes", "Available Unlearned Recipes",
                "Shows a collapsible permanent list and total cost for recipes currently learnable from each profession trainer."),
            Label("Trainer visits are player objectives only; Adventure Tracker already carries the recipe requirements and base prices."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionAttainableRecipes", "Looted and Purchased Recipes",
                "Shows unlearned recipes you can obtain from vendors, quests, objects and enemies."),
            Label("Merchant's Favor and mob-drop recipes have separate collapsed summaries; ordinary vendor, quest and object sources stay concise."))
        y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showObservedGathering", "Show Local Catch and Skinning History",
                "Shows locally recorded fishing and skinning loot by zone, ranked by item count with sample sizes."),
            { type = "button", text = "Clear Local Gathering History",
              tooltip = "Forgets only Adventure Tracker's locally recorded fishing and skinning observations.",
              onClick = function()
                  if ns.ResetObservedGathering then ns.ResetObservedGathering() end
                  if EUI.RefreshPage then EUI:RefreshPage() end
              end })
        y = y - h

        _, h = W:SectionHeader(parent, "ROUTE DATA", y); y = y - h
        _, h = W:DualRow(parent, y,
            Label("Permanent Forever recipe facts drive skill targets, expected crafts, trainer steps and material requirements."),
            Label("Legacy skill checkpoints now appear in the Legacy section; gathering skills remain visible here."))
        y = y - h
        local priceProvider = ns.GetPriceProviderName and ns.GetPriceProviderName()
        _, h = W:DualRow(parent, y,
            Toggle("showProfessionMarketCosts", "Use Installed Market Prices",
                "Scores otherwise comparable profession plans by estimated missing-material cost. TradeSkillMaster is preferred, then Auctionator."),
            Label(priceProvider and (priceProvider .. " price data detected.")
                or "No supported price API is currently available; recommendations continue without a price score."))
        y = y - h

        _, h = W:SectionHeader(parent, "DIAGNOSTICS", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showProviderDiagnostics", "Show Recommendation Status",
                "Keeps a profession provider status row visible after loading. Hover it for state details or click it to print all provider diagnostics."),
            Label("Loading and failure states appear automatically even when this setting is disabled."))
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
            Label("Skill-up plans use permanent trainer and recipe data plus live learned state, bags, prices and equipped items."))
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
            ColorSwatches("flightTimerFillColorMode", "flightTimerFillColor", "Fill Color", disabled),
            ColorSwatches("flightTimerBackgroundColorMode", "flightTimerBackgroundColor", "Bar Background", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Dropdown("flightTimerBorderTexture", "Border Style", borderValues, borderOrder, "Independent border style for the flight progress bar.", disabled),
            Slider("flightTimerBorderSize", "Border Size", 0, 4, 1, "Set to zero to hide the flight progress border.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            ColorSwatches("flightTimerBorderColorMode", "flightTimerBorderColor", "Border Color",
                function() return disabled() or (tonumber(ns.Get("flightTimerBorderSize")) or 0) <= 0 end),
            nil)
        y = y - h

        _, h = W:SectionHeader(parent, "FLIGHT TYPOGRAPHY", y); y = y - h
        _, h = W:DualRow(parent, y,
            Dropdown("flightTimerFont", "Flight Font", fontValues, fontOrder, "Font used only by the tracker flight timer.", disabled),
            Dropdown("flightTimerFontOutline", "Flight Font Outline", { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
                { "NONE", "OUTLINE", "THICKOUTLINE" }, "Outline used only by the tracker flight timer.", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Slider("flightTimerDestinationFontSize", "Destination Font Size", 8, 24, 1, "Size of the flight destination label.", disabled),
            ColorSwatches("flightTimerDestinationColorMode", "flightTimerDestinationColor", "Destination Color", disabled))
        y = y - h
        _, h = W:DualRow(parent, y,
            Slider("flightTimerTimeFontSize", "Time Font Size", 8, 24, 1, "Size of elapsed, remaining and total time.", disabled),
            ColorSwatches("flightTimerTimeColorMode", "flightTimerTimeColor", "Time Detail Color", disabled))
        y = y - h
    else
        _, h = W:SectionHeader(parent, "ACTIVITY STATUSES", y); y = y - h
        _, h = W:DualRow(parent, y,
            Toggle("showStatuses", "Show Activity Statuses", "Adds compact live status labels beside the zone, class, specialization and group context."),
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
                key = "quests", title = "Quests",
                description = "Expandable quest progress for zones this character has actually visited.",
                pages = { "Progress" }, buildPage = BuildQuests,
                onReset = function() ns.ResetKeys(QUEST_KEYS) end,
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
