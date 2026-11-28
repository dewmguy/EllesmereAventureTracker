-------------------------------------------------------------------------------
-- Adventure Tracker: floating window and rendering.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EUI = ns.EUI
local UNLOCK_KEY = "EAT_Tracker"
local DAMAGE_METER_MEDIA = "Interface\\AddOns\\EllesmereUIDamageMeters\\Media\\"
local foodInventorySignature
local professionInventorySignature
local CurrentBagRecommendationSignature

local COLORS = {
    ready = { 0.20, 0.82, 0.48 },
    warning = { 1.00, 0.68, 0.18 },
    missing = { 0.94, 0.28, 0.28 },
    unavailable = { 0.42, 0.45, 0.48 },
    unknown = { 0.58, 0.53, 0.78 },
    info = { 0.35, 0.67, 0.95 },
}

local frame = CreateFrame("Frame", "EllesmereUIAdventureTrackerFrame", UIParent, "BackdropTemplate")
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
})
frame:SetBackdropColor(0.025, 0.032, 0.04, 0.94)
frame:Hide()

local borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
borderFrame:SetAllPoints(frame)
borderFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
borderFrame:EnableMouse(false)

local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
header:SetPoint("TOPLEFT")
header:SetPoint("TOPRIGHT")
header:SetHeight(28)
header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
header:SetBackdropColor(0.04, 0.055, 0.065, 0.98)
header:EnableMouse(true)

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", 9, 0)
title:SetText("Adventure Tracker")

-- Quest Tracker style: an unboxed +/- glyph. It belongs to the window so it
-- remains available when the title bar itself is hidden.
local collapseButton = CreateFrame("Button", nil, frame)
collapseButton:SetSize(22, 20)
collapseButton:SetPoint("RIGHT", -7, 0)
collapseButton:SetFrameLevel(frame:GetFrameLevel() + 21)
collapseButton.text = collapseButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
collapseButton.text:SetPoint("CENTER")
collapseButton.text:SetText("−")
collapseButton:SetAlpha(0.85)

local headerSeparator = header:CreateTexture(nil, "OVERLAY")
headerSeparator:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
headerSeparator:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
headerSeparator:SetHeight(1)
headerSeparator:Hide()

-- Damage Meter style: a faint lock glyph in the lower-right corner that
-- brightens on hover and disappears when the window is not being inspected.
local lockButton = CreateFrame("Button", nil, frame)
lockButton:SetSize(13, 17)
lockButton:SetPoint("BOTTOMRIGHT", -4, 4)
lockButton:SetFrameLevel(frame:GetFrameLevel() + 21)
lockButton:SetAlpha(0)
local lockTexture = lockButton:CreateTexture(nil, "ARTWORK")
lockTexture:SetAllPoints()
lockTexture:SetDesaturated(true)
lockTexture:SetVertexColor(1, 1, 1)

-- Context, activity status and readiness icons stay fixed while recommendation
-- sections use the independent scroll frame below them.
local fixedFrame = CreateFrame("Frame", nil, frame)
fixedFrame:SetPoint("TOPLEFT", 8, -34)
fixedFrame:SetPoint("TOPRIGHT", -8, -34)
fixedFrame:SetHeight(1)
fixedFrame:EnableMouse(true)

local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
scrollFrame:SetPoint("TOPLEFT", fixedFrame, "BOTTOMLEFT")
scrollFrame:SetPoint("TOPRIGHT", fixedFrame, "BOTTOMRIGHT")
scrollFrame:EnableMouseWheel(true)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetPoint("TOPLEFT")
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

local contextButton = CreateFrame("Button", nil, fixedFrame)
contextButton:SetPoint("TOPLEFT", 2, 0)
contextButton:SetPoint("TOPRIGHT", -2, 0)
contextButton:SetHeight(1)
if contextButton.SetHyperlinksEnabled then contextButton:SetHyperlinksEnabled(true) end
if contextButton.SetPushedTextOffset then contextButton:SetPushedTextOffset(0, 0) end

local contextText = contextButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
contextText:SetPoint("TOPLEFT", 2, 0)
contextText:SetPoint("TOPRIGHT", -2, 0)
contextText:SetJustifyH("LEFT")
contextText:SetTextColor(0.67, 0.72, 0.75)
contextText:SetWordWrap(true)
if contextButton.SetFontString then contextButton:SetFontString(contextText) end
contextButton:SetScript("OnHyperlinkEnter", function(self, link)
    self._statusHoverLink = link
    if ns.ShowStatusLinkTooltip then ns.ShowStatusLinkTooltip(self, link) end
end)
contextButton:SetScript("OnHyperlinkLeave", function(self)
    self._statusHoverLink = nil
    GameTooltip_Hide()
    -- Let a neighboring hyperlink receive OnHyperlinkEnter before catching the
    -- row up; otherwise refreshing here can move that link out from under the
    -- cursor during the transition.
    C_Timer.After(0, function()
        if not self._statusHoverLink and ns.RefreshTrackerContextText then
            ns.RefreshTrackerContextText()
        end
    end)
end)
contextButton:SetScript("OnHide", function(self)
    self._statusHoverLink = nil
    if not GameTooltip.IsOwned or GameTooltip:IsOwned(self) then GameTooltip_Hide() end
end)

local playtimeText = fixedFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
playtimeText:SetJustifyH("LEFT")
playtimeText:SetTextColor(0.67, 0.72, 0.75)
playtimeText:SetWordWrap(true)

local iconPool, sectionPool, rowPool = {}, {}, {}
local visibleRowsByKey = {}
local visibleIconsByKey, visibleSectionsByID = {}, {}
local pendingDisclosuresByKey = {}
local renderInProgress = false
local skin
local UpdateLockFade
local RegisterDragSurface
local HideSecureActionButtons
local QueueSecureActionSync
local HasUnlockAnchor

-- Avoid turning an unchanged layout into another unlock-anchor resize cycle.
-- WoW can report subpixel differences after scale conversion, while Ellesmere's
-- resize observer intentionally treats changes above half a UI unit as real.
local function SetWidthIfChanged(region, width)
    local current = region and region:GetWidth()
    if not current or math.abs(current - width) > 0.5 then
        region:SetWidth(width)
        return true
    end
    return false
end

local function SetHeightIfChanged(region, height)
    local current = region and region:GetHeight()
    if not current or math.abs(current - height) > 0.5 then
        region:SetHeight(height)
        return true
    end
    return false
end

local function ColorValue(key)
    local value = ns.Get(key)
    local fallback = ns.DEFAULTS[key] or {}
    if type(value) ~= "table" then value = fallback end
    return value.r or fallback.r or 1, value.g or fallback.g or 1,
        value.b or fallback.b or 1, value.a == nil and (fallback.a or 1) or value.a
end

local TEXT_COLOR_MODES = {
    contextTextColor = "contextTextColorMode",
    sectionTextColor = "sectionTextColorMode",
    entryLabelTextColor = "entryLabelTextColorMode",
    entryDetailTextColor = "entryDetailTextColorMode",
    badgeTextColor = "badgeTextColorMode",
}

local function ThemeColor(modeKey, customKey)
    local mode = modeKey and ns.Get(modeKey) or "custom"
    if mode == "class" and EUI.GetPlayerClassColor then
        local ok, r, g, b = pcall(EUI.GetPlayerClassColor)
        if ok and r and g and b then return r, g, b, 1 end
    elseif mode == "accent" and EUI.GetAccentColor then
        local ok, r, g, b = pcall(EUI.GetAccentColor)
        if ok and r and g and b then return r, g, b, 1 end
    end
    return ColorValue(customKey)
end

local function ConfiguredColor(key)
    return ThemeColor(key .. "Mode", key)
end

local function SetSurfaceBackground(surface, key)
    local r, g, b, a = ConfiguredColor(key)
    surface:SetBackdropColor(r, g, b, a)
end

local function StateColor(state)
    local color = COLORS[state] or COLORS.info
    return color[1], color[2], color[3]
end

local READINESS_BORDER_COLOR_KEYS = {
    ready = "readinessIconReadyBorderColor",
    warning = "readinessIconWarningBorderColor",
    missing = "readinessIconMissingBorderColor",
    unavailable = "readinessIconUnavailableBorderColor",
    unknown = "readinessIconUnknownBorderColor",
    info = "readinessIconInfoBorderColor",
}

local function ReadinessBorderColor(state)
    local key = READINESS_BORDER_COLOR_KEYS[state]
    if key then return ConfiguredColor(key) end
    local r, g, b = StateColor(state)
    return r, g, b, 1
end

local ATTENTION_COLORS = {
    warning = { 1.00, 0.82, 0.12 },
    critical = { 1.00, 0.16, 0.12 },
}

local ATTENTION_FILL_ALPHA = {
    warning = 0.12,
    critical = 0.10,
}

local function CreateAttentionAnimation(region)
    local animation = region:CreateAnimationGroup()
    animation:SetLooping("BOUNCE")
    local fade = animation:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.25)
    fade:SetToAlpha(1)
    fade:SetDuration(0.9)
    fade:SetSmoothing("IN_OUT")
    return animation
end

local function SetAttention(widget, attention, edgeSize)
    local color = ATTENTION_COLORS[attention]
    local glow = widget._attentionBorder
    local fill = widget._attentionFill
    if not color then
        if glow then
            glow.animation:Stop()
            glow:Hide()
        end
        if fill then
            fill.animation:Stop()
            fill:Hide()
        end
        return
    end
    if not glow then
        glow = CreateFrame("Frame", nil, widget, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", 2, -2)
        glow:SetFrameLevel(widget:GetFrameLevel() + 10)
        glow:EnableMouse(false)
        glow.animation = CreateAttentionAnimation(glow)
        widget._attentionBorder = glow
    end
    edgeSize = edgeSize or 2
    if glow._edgeSize ~= edgeSize then
        glow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = edgeSize })
        glow._edgeSize = edgeSize
    end
    glow:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    if widget._attentionBackground then
        if not fill then
            fill = widget:CreateTexture(nil, "BACKGROUND", nil, 1)
            fill:SetAllPoints(widget)
            fill.animation = CreateAttentionAnimation(fill)
            widget._attentionFill = fill
        end
        fill:SetColorTexture(color[1], color[2], color[3], ATTENTION_FILL_ALPHA[attention] or 0.10)
        fill:SetAlpha(0.25)
        fill:Show()
        if not fill.animation:IsPlaying() then fill.animation:Play() end
    end
    glow:SetAlpha(0.25)
    glow:Show()
    if not glow.animation:IsPlaying() then glow.animation:Play() end
end

local function DataValue(data, key)
    if ns.ResolveTrackerDataValue then return ns.ResolveTrackerDataValue(data, key) end
    return type(data) == "table" and data[key] or nil
end

local function DataVisible(data)
    if ns.IsTrackerDataVisible then return ns.IsTrackerDataVisible(data) end
    return DataValue(data, "visible") ~= false
end

local function SetDisclosureActivity(row, active)
    if not (row and row.activity) then return end
    row.activity:SetShown(active == true)
    if not row.activity.animation then return end
    if active then
        if not row.activity.animation:IsPlaying() then row.activity.animation:Play() end
    else
        row.activity.animation:Stop()
        row.activity:SetAlpha(1)
    end
end

local function BeginDisclosureInteraction(row, data)
    if not (data and data.disclosure and data.key) then return end
    local currentlyExpanded = DataValue(data, "expanded") == true
    pendingDisclosuresByKey[data.key] = { expected = not currentlyExpanded }
    SetDisclosureActivity(row, true)
end

local function ShowTooltip(owner, data)
    if type(data.tooltipFunc) == "function" then
        local ok, handled = pcall(data.tooltipFunc, owner)
        if ok and handled then return end
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local actionTooltip = false
    if data.spellID then
        if GameTooltip.SetSpellByID then
            actionTooltip = pcall(GameTooltip.SetSpellByID, GameTooltip, data.spellID)
        elseif GameTooltip.SetHyperlink then
            actionTooltip = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(data.spellID))
        end
    elseif data.secureItemID and GameTooltip.SetHyperlink then
        actionTooltip = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tostring(data.secureItemID))
    end
    if not actionTooltip then GameTooltip:SetText(DataValue(data, "label") or "Adventure Tracker") end
    local detail = DataValue(data, "tooltip") or DataValue(data, "detail")
    if detail and detail ~= "" then
        if actionTooltip then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine(detail, 1, 1, 1, true)
    end
    local clickHint = data.onClick and (DataValue(data, "clickHint") or "Click to open.")
        or (owner._secureAction and data.secureClickHint)
    if clickHint then GameTooltip:AddLine(clickHint, 0.55, 0.82, 1) end
    if type(data.onRightClick) == "function" then
        GameTooltip:AddLine(DataValue(data, "rightClickHint") or "Right-click for quest options.", 0.30, 0.90, 0.72)
    end
    if data.key and pendingDisclosuresByKey[data.key] then
        GameTooltip:AddLine("Updating this list...", 1, 0.82, 0.24)
    end
    GameTooltip:Show()
end

local contextMenuOverlay, contextMenu, contextMenuButtons

local function HideContextMenu()
    if contextMenuOverlay then contextMenuOverlay:Hide() end
end
ns.HideContextMenu = HideContextMenu

local function CreateContextMenu()
    if contextMenu then return end
    contextMenuButtons = {}
    contextMenuOverlay = CreateFrame("Button", "EUIAdventureTrackerContextMenuOverlay", UIParent)
    contextMenuOverlay:SetAllPoints(UIParent)
    contextMenuOverlay:SetFrameStrata("TOOLTIP")
    contextMenuOverlay:SetFrameLevel(200)
    contextMenuOverlay:EnableMouse(true)
    contextMenuOverlay:RegisterForClicks("AnyUp")
    contextMenuOverlay:SetScript("OnClick", HideContextMenu)
    contextMenuOverlay:Hide()

    contextMenu = CreateFrame("Frame", nil, contextMenuOverlay, "BackdropTemplate")
    contextMenu:SetWidth(330)
    contextMenu:SetFrameLevel(contextMenuOverlay:GetFrameLevel() + 10)
    contextMenu:SetClampedToScreen(true)
    contextMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    contextMenu:SetBackdropColor(0.025, 0.032, 0.04, 0.99)
    contextMenu:SetBackdropBorderColor(0.12, 0.78, 0.62, 1)
    contextMenu.title = contextMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    contextMenu.title:SetPoint("TOPLEFT", 10, -9)
    contextMenu.title:SetPoint("TOPRIGHT", -10, -9)
    contextMenu.title:SetJustifyH("LEFT")

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = contextMenuOverlay:GetName()
    end
end

local function ContextMenuButton(index)
    local button = contextMenuButtons[index]
    if button then return button end
    button = CreateFrame("Button", nil, contextMenu, "BackdropTemplate")
    button:SetHeight(22)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    button:SetBackdropColor(1, 1, 1, 0)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("LEFT", 8, 0)
    button.text:SetPoint("RIGHT", -8, 0)
    button.text:SetJustifyH("LEFT")
    button:SetScript("OnEnter", function(self)
        if self.action then self:SetBackdropColor(1, 1, 1, 0.08) end
    end)
    button:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0) end)
    button:SetScript("OnClick", function(self)
        local action = self.action
        if not action then return end
        HideContextMenu()
        local ok, message = pcall(action)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if type(handler) == "function" then handler(message) end
        end
    end)
    contextMenuButtons[index] = button
    return button
end

function ns.ShowContextMenu(owner, menuTitle, entries)
    if not owner or type(entries) ~= "table" then return false end
    CreateContextMenu()
    contextMenu.title:SetText(tostring(menuTitle or "Adventure Tracker"))
    local y = -32
    for index = 1, #entries do
        local entry = entries[index]
        local button = ContextMenuButton(index)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 6, y)
        button:SetPoint("TOPRIGHT", -6, y)
        button.action = not entry.disabled and not entry.heading and entry.action or nil
        button.text:SetText(tostring(entry.text or ""))
        if entry.heading then
            button.text:SetTextColor(0.30, 0.90, 0.72)
        elseif entry.disabled then
            button.text:SetTextColor(0.52, 0.55, 0.58)
        elseif type(entry.color) == "table" then
            button.text:SetTextColor(entry.color[1] or 1, entry.color[2] or 1, entry.color[3] or 1)
        else
            button.text:SetTextColor(0.94, 0.95, 0.96)
        end
        button:Show()
        y = y - 22
    end
    for index = #entries + 1, #contextMenuButtons do
        contextMenuButtons[index].action = nil
        contextMenuButtons[index]:Hide()
    end
    contextMenu:SetHeight(math.abs(y) + 7)
    contextMenu:ClearAllPoints()
    contextMenu:SetPoint("TOPLEFT", owner, "TOPRIGHT", 6, 0)
    contextMenuOverlay:Show()
    contextMenu:Show()
    return true
end

local secureActionPool = {}
local secureActionSyncQueued = false

local VALID_FRAME_STRATA = {
    BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
    FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true,
}

local function MainPaneStrata()
    local value = tostring(ns.Get("frameStrata") or "MEDIUM"):upper()
    return VALID_FRAME_STRATA[value] and value or "MEDIUM"
end

local function AcquireSecureActionButton(index)
    local button = secureActionPool[index]
    if button then
        if not (InCombatLockdown and InCombatLockdown()) then button:SetFrameStrata(MainPaneStrata()) end
        return button
    end
    button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    button:SetFrameStrata(MainPaneStrata())
    button:SetFrameLevel(frame:GetFrameLevel() + 40)
    button:RegisterForClicks("LeftButtonUp")
    button._secureAction = true
    button:SetScript("OnEnter", function(self)
        if UpdateLockFade then UpdateLockFade(true) end
        if self.data then ShowTooltip(self, self.data) end
    end)
    button:SetScript("OnLeave", function()
        GameTooltip_Hide()
        if UpdateLockFade then C_Timer.After(0, UpdateLockFade) end
    end)
    -- Successful item and spell actions already produce their authoritative
    -- bag or aura event. Do not add a speculative second readiness rebuild.
    button:SetScript("PostClick", nil)
    button:Hide()
    secureActionPool[index] = button
    return button
end

local function DeactivateSecureActionButton(button)
    if not button then return end
    if UnregisterStateDriver then pcall(UnregisterStateDriver, button, "visibility") end
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("unit", nil)
    button.data = nil
    button:Hide()
end

local function PositionSecureActionButton(button, owner)
    if HasUnlockAnchor and HasUnlockAnchor() then return false end
    if not (frame:IsShown() and owner and owner:IsShown()) then return false end
    local clipFrame = owner._trackerFixedAction and fixedFrame or scrollFrame
    if not clipFrame:IsShown() then return false end
    local left, right, top, bottom = owner:GetLeft(), owner:GetRight(), owner:GetTop(), owner:GetBottom()
    local scrollLeft, scrollRight = clipFrame:GetLeft(), clipFrame:GetRight()
    local scrollTop, scrollBottom = clipFrame:GetTop(), clipFrame:GetBottom()
    if not (left and right and top and bottom and scrollLeft and scrollRight and scrollTop and scrollBottom) then return false end
    if right <= scrollLeft or left >= scrollRight or bottom >= scrollTop or top <= scrollBottom then return false end
    local uiScale = math.max(0.01, UIParent:GetEffectiveScale() or 1)
    local ownerScale = math.max(0.01, owner:GetEffectiveScale() or 1)
    local ratio = ownerScale / uiScale
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
    button:SetSize((right - left) * ratio, (top - bottom) * ratio)
    return true
end

HideSecureActionButtons = function()
    if InCombatLockdown and InCombatLockdown() then return end
    for index = 1, #secureActionPool do
        DeactivateSecureActionButton(secureActionPool[index])
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

local function HasSecureAction(data)
    return data and ((data.castSpellID and data.castSpellName) or data.secureItemID)
end

local function ConfigureSecureAction(index, owner, data)
    local button = AcquireSecureActionButton(index)
    if not PositionSecureActionButton(button, owner) then
        DeactivateSecureActionButton(button)
        return
    end
    if UnregisterStateDriver then pcall(UnregisterStateDriver, button, "visibility") end
    button.data = data
    if data.secureItemID then
        button:SetAttribute("type", "item")
        button:SetAttribute("item", "item:" .. tostring(data.secureItemID))
        button:SetAttribute("spell", nil)
        button:SetAttribute("unit", nil)
    else
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", data.castSpellName)
        button:SetAttribute("item", nil)
        button:SetAttribute("unit", data.castUnit or "player")
    end
    local registered = RegisterStateDriver
        and pcall(RegisterStateDriver, button, "visibility", "[combat] hide; show")
    if not registered then button:Show() end
end

local function SyncSecureActionButtons()
    secureActionSyncQueued = false
    if InCombatLockdown and InCombatLockdown() then return end
    local actionIndex = 0
    local function SyncPool(pool)
        for ownerIndex = 1, #pool do
            local owner = pool[ownerIndex]
            local data = owner and owner.data
            if HasSecureAction(data) then
                actionIndex = actionIndex + 1
                ConfigureSecureAction(actionIndex, owner, data)
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    SyncPool(iconPool)
    SyncPool(rowPool)
    for index = actionIndex + 1, #secureActionPool do
        DeactivateSecureActionButton(secureActionPool[index])
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

QueueSecureActionSync = function()
    if secureActionSyncQueued or (InCombatLockdown and InCombatLockdown()) then return end
    secureActionSyncQueued = true
    if ns.QueueBudgetedWork then
        ns.QueueBudgetedWork("tracker-secure-actions", SyncSecureActionButtons, function()
            secureActionSyncQueued = false
        end, function()
            return not (InCombatLockdown and InCombatLockdown())
        end, function(message)
            secureActionSyncQueued = false
            local handler = geterrorhandler and geterrorhandler()
            if type(handler) == "function" then handler(message) end
        end)
    else
        C_Timer.After(0, SyncSecureActionButtons)
    end
end

local function AcquireIcon(index)
    local button = iconPool[index]
    if button then return button end
    button = CreateFrame("Button", nil, fixedFrame, "BackdropTemplate")
    button._trackerFixedAction = true
    button:SetSize(31, 31)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.border:SetAllPoints(button)
    button.border:SetFrameLevel(button:GetFrameLevel() + 2)
    button.border:EnableMouse(false)
    button.badge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.badge:SetPoint("BOTTOMRIGHT", 3, -2)
    button.badge:SetTextColor(1, 1, 1)
    button:SetScript("OnEnter", function(self)
        if UpdateLockFade then UpdateLockFade(true) end
        if self.data then ShowTooltip(self, self.data) end
    end)
    button:SetScript("OnLeave", function()
        GameTooltip_Hide()
        if UpdateLockFade then C_Timer.After(0, UpdateLockFade) end
    end)
    button:SetScript("OnClick", function(self)
        if self._trackerDragged then return end
        if self.data and self.data.onClick then self.data.onClick() end
    end)
    if RegisterDragSurface then RegisterDragSurface(button) end
    iconPool[index] = button
    if skin then skin.SquareIcon(button.icon) end
    return button
end

local function AcquireSection(index)
    local button = sectionPool[index]
    if button then return button end
    button = CreateFrame("Button", nil, content, "BackdropTemplate")
    button:SetHeight(16)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    button:SetBackdropColor(1, 1, 1, 0)
    button._attentionBackground = true
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", 2, 0)
    button.text:SetPoint("RIGHT", -2, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetTextColor(0.18, 0.82, 0.66)
    button:SetScript("OnEnter", function(self)
        SetSurfaceBackground(self, "sectionHoverBackgroundColor")
        if self.sectionID then
            ShowTooltip(self, {
                label = self.sectionCollapsed and "Expand " .. (self.sectionTitle or "section")
                    or "Collapse " .. (self.sectionTitle or "section"),
                detail = "Show or hide this section's entries.",
            })
        end
    end)
    button:SetScript("OnLeave", function(self)
        SetSurfaceBackground(self, "sectionBackgroundColor")
        GameTooltip_Hide()
    end)
    button:SetScript("OnClick", function(self)
        if self._trackerDragged then return end
        if self.sectionID and self.ToggleSection then self.ToggleSection(self.sectionID) end
    end)
    if RegisterDragSurface then RegisterDragSurface(button) end
    sectionPool[index] = button
    if skin then skin.Font(button.text) end
    return button
end

local function AcquireRow(index)
    local row = rowPool[index]
    if row then return row end
    row = CreateFrame("Button", nil, content, "BackdropTemplate")
    row:SetHeight(37)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(1, 1, 1, 0.025)
    row._attentionBackground = true
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetPoint("TOPLEFT")
    row.stripe:SetPoint("BOTTOMLEFT")
    row.stripe:SetWidth(2)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(23, 23)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 7, -2)
    row.label:SetPoint("TOPRIGHT", -7, -2)
    row.label:SetJustifyH("LEFT")
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.detail:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.detail:SetPoint("TOPRIGHT", -7, -18)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetTextColor(0.62, 0.66, 0.69)
    row.dismiss = CreateFrame("Button", nil, row)
    row.dismiss:SetSize(18, 18)
    row.dismiss:SetPoint("TOPRIGHT", -3, -3)
    row.dismiss.text = row.dismiss:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.dismiss.text:SetPoint("CENTER", 0, 0)
    row.dismiss.text:SetText("X")
    row.dismiss.text:SetTextColor(0.72, 0.75, 0.78)
    row.dismiss:SetScript("OnEnter", function(self)
        if UpdateLockFade then UpdateLockFade(true) end
        self.text:SetTextColor(1, 0.25, 0.20)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Dismiss warning")
        local data = self:GetParent().data
        if data and data.dismissHint then GameTooltip:AddLine(data.dismissHint, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    row.dismiss:SetScript("OnLeave", function(self)
        self.text:SetTextColor(0.72, 0.75, 0.78)
        GameTooltip_Hide()
        if UpdateLockFade then C_Timer.After(0, UpdateLockFade) end
    end)
    row.dismiss:SetScript("OnClick", function(self)
        local data = self:GetParent().data
        if data and data.onDismiss then data.onDismiss() end
    end)
    row.dismiss:Hide()
    row.activity = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.activity:SetPoint("RIGHT", row, "RIGHT", -7, 0)
    row.activity:SetText("...")
    row.activity:SetTextColor(1, 0.82, 0.24)
    row.activity.animation = row.activity:CreateAnimationGroup()
    row.activity.animation:SetLooping("BOUNCE")
    local activityFade = row.activity.animation:CreateAnimation("Alpha")
    activityFade:SetFromAlpha(0.25)
    activityFade:SetToAlpha(1)
    activityFade:SetDuration(0.45)
    row.activity:Hide()
    row.progress = CreateFrame("StatusBar", nil, row, "BackdropTemplate")
    row.progress:SetMinMaxValues(0, 1)
    row.progress:SetValue(0)
    row.progress:EnableMouse(false)
    row.progress.bg = row.progress:CreateTexture(nil, "BACKGROUND")
    row.progress.bg:SetAllPoints()
    row.progress.border = CreateFrame("Frame", nil, row.progress, "BackdropTemplate")
    row.progress.border:SetAllPoints(row.progress)
    row.progress.border:SetFrameLevel(row.progress:GetFrameLevel() + 5)
    row.progress.border:EnableMouse(false)
    row.progress:Hide()
    row:SetScript("OnEnter", function(self)
        if UpdateLockFade then UpdateLockFade(true) end
        SetSurfaceBackground(self, "entryHoverBackgroundColor")
        if self.data then ShowTooltip(self, self.data) end
    end)
    row:SetScript("OnLeave", function(self)
        SetSurfaceBackground(self, "entryBackgroundColor")
        GameTooltip_Hide()
        if UpdateLockFade then C_Timer.After(0, UpdateLockFade) end
    end)
    row:SetScript("OnClick", function(self, mouseButton)
        if self._trackerDragged then return end
        if mouseButton == "RightButton" then
            if self.data and type(self.data.onRightClick) == "function" then
                GameTooltip_Hide()
                local ok, message = pcall(self.data.onRightClick, self)
                if not ok then
                    local handler = geterrorhandler and geterrorhandler()
                    if type(handler) == "function" then handler(message) end
                end
            end
            return
        end
        if self.data and self.data.onClick then
            BeginDisclosureInteraction(self, self.data)
            local ok, message = pcall(self.data.onClick)
            if not ok then
                if self.data.key then pendingDisclosuresByKey[self.data.key] = nil end
                SetDisclosureActivity(self, false)
                local handler = geterrorhandler and geterrorhandler()
                if type(handler) == "function" then handler(message) end
            end
        end
    end)
    if RegisterDragSurface then RegisterDragSurface(row) end
    rowPool[index] = row
    if skin then
        skin.Font(row.label)
        skin.Font(row.detail)
        skin.Font(row.dismiss.text)
        skin.SquareIcon(row.icon)
    end
    return row
end

local function BeginPoolRender()
    wipe(visibleRowsByKey)
    wipe(visibleIconsByKey)
    wipe(visibleSectionsByID)
end

local function HideUnusedPools(iconCount, sectionCount, rowCount)
    for i = (iconCount or 0) + 1, #iconPool do
        SetAttention(iconPool[i], nil)
        iconPool[i]:Hide()
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    for i = (sectionCount or 0) + 1, #sectionPool do
        SetAttention(sectionPool[i], nil)
        sectionPool[i]:Hide()
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    for i = (rowCount or 0) + 1, #rowPool do
        SetAttention(rowPool[i], nil)
        SetDisclosureActivity(rowPool[i], false)
        rowPool[i]:Hide()
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

-- Timers update these already-laid-out widgets without rebuilding providers,
-- reconstructing sections, or touching QuestieDB. Only fields whose geometry
-- remains stable are supported here; structural changes still request a render.
function ns.UpdateVisibleRow(key, update)
    local row = visibleRowsByKey[key]
    if not (row and row:IsShown() and row.data and row.data.key == key) then return false end
    if type(update) ~= "table" then return false end
    if update.label ~= nil then
        row.data.label = update.label
        row.label:SetText(update.label)
    end
    if update.detail ~= nil then
        row.data.detail = update.detail
        row.detail:SetText(update.detail)
    end
    if update.tooltip ~= nil then row.data.tooltip = update.tooltip end
    if update.progressValue ~= nil and row.progress:IsShown() then
        local value = math.max(0, math.min(1, tonumber(update.progressValue) or 0))
        row.progress:SetValue(value)
        if type(row.data.progress) == "table" then row.data.progress.value = value end
    end
    return true
end

local function Clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback
    return math.max(minimum, math.min(maximum, value))
end

local function PanePadding()
    return Clamp(ns.Get("panePadding"), 0, 24, 8)
end

local function TextFontPath(choice)
    choice = choice or ns.Get("textFont")
    if choice == nil or choice == "" or choice == "__global" then
        return (EUI.GetFontPath and EUI.GetFontPath()) or STANDARD_TEXT_FONT
    end
    if EUI.ResolveFontName then
        local ok, path = pcall(EUI.ResolveFontName, choice)
        if ok and path then return path end
    end
    return (EUI.GetFontPath and EUI.GetFontPath()) or STANDARD_TEXT_FONT
end

local function TextFontFlags(outline)
    outline = outline or ns.Get("textOutline")
    if outline == "OUTLINE" or outline == "THICKOUTLINE" then return outline end
    return ""
end

local function StyleFontString(fontString, sizeKey, fallbackSize, colorKey, modeKey, minimum, maximum)
    if not fontString then return end
    local size = Clamp(ns.Get(sizeKey), minimum or 8, maximum or 24, fallbackSize)
    local path, flags = TextFontPath(), TextFontFlags()
    if EUI.SetFontFamily then
        pcall(EUI.SetFontFamily, fontString, path, size, flags, flags == "")
    else
        pcall(fontString.SetFont, fontString, path, size, flags)
    end
    if colorKey then fontString:SetTextColor(ThemeColor(modeKey or TEXT_COLOR_MODES[colorKey], colorKey)) end
end

local function StyleTitleFontString(fontString)
    if not fontString then return end
    local size = Clamp(ns.Get("titleFontSize"), 8, 24, 13)
    pcall(fontString.SetFont, fontString, TextFontPath(), size, TextFontFlags())
end

local function ApplyTextAppearance(iconCount, sectionCount, rowCount)
    StyleTitleFontString(title)
    StyleTitleFontString(collapseButton.text)
    StyleFontString(contextText, "contextFontSize", 11, "contextTextColor", "contextTextColorMode")
    StyleFontString(playtimeText, "contextFontSize", 11, "contextTextColor", "contextTextColorMode")
    local statusAlignment = tostring(ns.Get("statusTextAlignment") or "LEFT"):upper()
    if statusAlignment ~= "CENTER" and statusAlignment ~= "RIGHT" then statusAlignment = "LEFT" end
    contextText:SetJustifyH(statusAlignment)
    playtimeText:SetJustifyH(statusAlignment)
    for i = 1, iconCount or #iconPool do
        StyleFontString(iconPool[i].badge, "badgeFontSize", 10, "badgeTextColor", "badgeTextColorMode", 6, 32)
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    for i = 1, sectionCount or #sectionPool do
        local section = sectionPool[i]
        StyleFontString(section.text, "sectionFontSize", 11, "sectionTextColor", "sectionTextColorMode")
        SetSurfaceBackground(section, section:IsMouseOver() and "sectionHoverBackgroundColor" or "sectionBackgroundColor")
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    for i = 1, rowCount or #rowPool do
        local row = rowPool[i]
        StyleFontString(row.label, "entryLabelFontSize", 12, "entryLabelTextColor", "entryLabelTextColorMode")
        StyleFontString(row.detail, "entryDetailFontSize", 10, "entryDetailTextColor", "entryDetailTextColorMode")
        SetSurfaceBackground(row, row:IsMouseOver() and "entryHoverBackgroundColor" or "entryBackgroundColor")
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
end

local VALID_BADGE_ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function ApplyReadinessIconAppearance(button, state, size, borderSize)
    button:SetSize(size, size)
    local inset = borderSize > 0 and math.min(math.floor(size / 3), borderSize + 1) or 0
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)

    local anchor = tostring(ns.Get("badgeAnchor") or "BOTTOMRIGHT"):upper()
    if not VALID_BADGE_ANCHORS[anchor] then anchor = "BOTTOMRIGHT" end
    button.badge:ClearAllPoints()
    button.badge:SetPoint(anchor, button, anchor,
        Clamp(ns.Get("badgeOffsetX"), -24, 24, 3),
        Clamp(ns.Get("badgeOffsetY"), -24, 24, -2))

    local r, g, b, a = ReadinessBorderColor(state)
    local texture = ns.Get("readinessIconBorderTexture") or "solid"
    if EUI.ApplyBorderStyle then
        EUI.ApplyBorderStyle(button.border, borderSize, r, g, b, a, texture)
    elseif borderSize > 0 then
        button.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = borderSize })
        button.border:SetBackdropBorderColor(r, g, b, a)
        button.border:Show()
    else
        button.border:SetBackdrop(nil)
        button.border:Hide()
    end
end

local function DataColor(color, fallbackKey)
    if type(color) == "table" then
        return color.r or color[1] or 1, color.g or color[2] or 1,
            color.b or color[3] or 1, color.a == nil and (color[4] or 1) or color.a
    end
    return ThemeColor(TEXT_COLOR_MODES[fallbackKey] or (fallbackKey .. "Mode"), fallbackKey)
end

local function ApplyDataTypography(row, data)
    if not (row and data) then return end
    local path = TextFontPath(data.font)
    local flags = TextFontFlags(data.fontOutline)
    local labelSize = Clamp(data.labelFontSize, 8, 24, Clamp(ns.Get("entryLabelFontSize"), 8, 24, 12))
    local detailSize = Clamp(data.detailFontSize, 8, 24, Clamp(ns.Get("entryDetailFontSize"), 8, 24, 10))
    if EUI.SetFontFamily then
        pcall(EUI.SetFontFamily, row.label, path, labelSize, flags, flags == "")
        pcall(EUI.SetFontFamily, row.detail, path, detailSize, flags, flags == "")
    else
        pcall(row.label.SetFont, row.label, path, labelSize, flags)
        pcall(row.detail.SetFont, row.detail, path, detailSize, flags)
    end
    if data.labelColor then row.label:SetTextColor(DataColor(data.labelColor, "entryLabelTextColor")) end
    if data.detailColor then row.detail:SetTextColor(DataColor(data.detailColor, "entryDetailTextColor")) end
end

local barTextureLookup
local function ProgressTexture(choice)
    if not barTextureLookup and EUI.BuildBarTextureTables then
        local ok, lookup = pcall(EUI.BuildBarTextureTables)
        if ok then barTextureLookup = lookup end
    end
    if EUI.ResolveTexturePath and barTextureLookup then
        local ok, path = pcall(EUI.ResolveTexturePath, barTextureLookup, choice, "Interface\\Buttons\\WHITE8x8")
        if ok and path then return path end
    end
    return "Interface\\Buttons\\WHITE8x8"
end

local function ApplyProgress(row, data, contentWidth)
    local progressData = data and data.progress
    local progress = row.progress
    if type(progressData) ~= "table" then progress:Hide(); return end
    local height = Clamp(progressData.height, 2, 24, 8)
    local left = data.hideIcon and 7 or 38
    progress:ClearAllPoints()
    progress:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", left, 5)
    progress:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -7, 5)
    progress:SetHeight(height)
    progress:SetStatusBarTexture(ProgressTexture(progressData.texture))
    progress:SetMinMaxValues(0, 1)
    progress:SetValue(Clamp(progressData.value, 0, 1, 0))
    progress:SetStatusBarColor(DataColor(progressData.fillColor, "entryLabelTextColor"))
    progress.bg:SetTexture(ProgressTexture(progressData.texture))
    progress.bg:SetVertexColor(DataColor(progressData.backgroundColor, "entryBackgroundColor"))
    local borderSize = Clamp(progressData.borderSize, 0, 4, 0)
    local borderStyleKey = table.concat({ tostring(progressData.borderTexture), tostring(borderSize),
        tostring(progressData.borderColor and (progressData.borderColor.r or progressData.borderColor[1])),
        tostring(progressData.borderColor and (progressData.borderColor.g or progressData.borderColor[2])),
        tostring(progressData.borderColor and (progressData.borderColor.b or progressData.borderColor[3])),
        tostring(progressData.borderColor and (progressData.borderColor.a or progressData.borderColor[4])) }, ":")
    if progress._adventureBorderStyleKey ~= borderStyleKey then
        progress._adventureBorderStyleKey = borderStyleKey
        local border = progress.border
        if borderSize > 0 then
            local r, g, b, a = DataColor(progressData.borderColor, "borderColor")
            if EUI.ApplyBorderStyle then
                EUI.ApplyBorderStyle(border, borderSize, r, g, b, a, progressData.borderTexture or "solid")
            else
                border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = borderSize })
                border:SetBackdropBorderColor(r, g, b, a)
                border:Show()
            end
        else
            if EUI.ApplyBorderStyle then
                EUI.ApplyBorderStyle(border, 0, 0, 0, 0, 0, progressData.borderTexture or "solid")
            else
                border:SetBackdrop(nil)
                border:Hide()
            end
        end
    end
    progress:Show()
end

local function SectionCollapsed(sectionID)
    local root = ns.DB().collapsedSectionsByCharacter
    local character = type(root) == "table" and root[ns.CharacterKey()]
    return type(character) == "table" and character[sectionID] == true
end

local function ToggleSection(sectionID)
    local db = ns.DB()
    if type(db.collapsedSectionsByCharacter) ~= "table" then db.collapsedSectionsByCharacter = {} end
    local characterKey = ns.CharacterKey()
    if type(db.collapsedSectionsByCharacter[characterKey]) ~= "table" then
        db.collapsedSectionsByCharacter[characterKey] = {}
    end
    local character = db.collapsedSectionsByCharacter[characterKey]
    character[sectionID] = not SectionCollapsed(sectionID)
    if ns.RequestPresentationRefresh then
        ns.RequestPresentationRefresh("section collapse")
    elseif ns.RequestRefresh then
        ns.RequestRefresh(false, "section collapse")
    end
end

local function SectionAttention(rows)
    local attention
    for index = 1, #rows do
        local rowAttention = DataVisible(rows[index]) and DataValue(rows[index], "attention") or nil
        if rowAttention == "critical" then return "critical" end
        if rowAttention == "warning" then attention = "warning" end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return attention
end

local function SnapshotAttention(snapshot)
    local attention = SectionAttention(snapshot.statuses or {})
    if attention == "critical" then return attention end
    for index = 1, #(snapshot.sections or {}) do
        local sectionAttention = SectionAttention(snapshot.sections[index].rows or {})
        if sectionAttention == "critical" then return sectionAttention end
        if sectionAttention == "warning" then attention = "warning" end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    return attention
end

local function ResultSections(result)
    if type(result) ~= "table" then return {} end
    return result.id and { result } or result
end

local function ResultStatuses(sections)
    local statuses = {}
    for sectionIndex = 1, #sections do
        for statusIndex = 1, #(sections[sectionIndex].statuses or {}) do
            statuses[#statuses + 1] = sections[sectionIndex].statuses[statusIndex]
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    return statuses
end

local function SameRowGeometry(before, after)
    local beforeProgress = type(before.progress) == "table" and before.progress or nil
    local afterProgress = type(after.progress) == "table" and after.progress or nil
    return (before.hideIcon == true) == (after.hideIcon == true)
        and (type(before.onDismiss) == "function") == (type(after.onDismiss) == "function")
        and (beforeProgress ~= nil) == (afterProgress ~= nil)
        and (not beforeProgress or tonumber(beforeProgress.height) == tonumber(afterProgress.height))
        and tonumber(before.indentLevel or 0) == tonumber(after.indentLevel or 0)
        and tonumber(before.labelFontSize or 0) == tonumber(after.labelFontSize or 0)
        and tonumber(before.detailFontSize or 0) == tonumber(after.detailFontSize or 0)
end

local function TryPatchProviderResult(previous, current)
    if renderInProgress or not frame:IsShown() or ns.Get("collapsed") or ns.Get("hideWhenReady") then return false end
    local beforeSections, afterSections = ResultSections(previous), ResultSections(current)
    if #beforeSections ~= #afterSections then return false end

    for sectionIndex = 1, #afterSections do
        local before, after = beforeSections[sectionIndex], afterSections[sectionIndex]
        if before.id ~= after.id or before.title ~= after.title
            or #(before.rows or {}) ~= #(after.rows or {}) then return false end
        for rowIndex = 1, #(after.rows or {}) do
            local oldRow, newRow = before.rows[rowIndex], after.rows[rowIndex]
            if oldRow.key ~= newRow.key or not SameRowGeometry(oldRow, newRow) then return false end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end

    local beforeStatuses, afterStatuses = ResultStatuses(beforeSections), ResultStatuses(afterSections)
    if #beforeStatuses ~= #afterStatuses then return false end
    for index = 1, #afterStatuses do
        if beforeStatuses[index].key ~= afterStatuses[index].key then return false end
        local button = visibleIconsByKey[afterStatuses[index].key]
        if not button then return false end
        if ns.YieldForBudget then ns.YieldForBudget() end
    end

    local size = Clamp(ns.Get("readinessIconSize"), 20, 64, 31)
    local borderSize = Clamp(ns.Get("readinessIconBorderSize"), 0, 4, 2)
    for index = 1, #afterStatuses do
        local data = afterStatuses[index]
        local button = visibleIconsByKey[data.key]
        button.data = data
        button.icon:SetTexture(data.icon or 134400)
        button.badge:SetText(data.badge or "")
        ApplyReadinessIconAppearance(button, data.state, size, borderSize)
        SetAttention(button, DataValue(data, "attention"), 2)
        if ns.YieldForBudget then ns.YieldForBudget() end
    end

    for sectionIndex = 1, #afterSections do
        local section = afterSections[sectionIndex]
        local sectionID = tostring(section.id)
        local collapsed = SectionCollapsed(sectionID)
        local heading = visibleSectionsByID[sectionID]
        if not heading then return false end
        heading.sectionTitle = section.title or sectionID
        heading.text:SetText(string.format("%s %s", collapsed and "+" or "−", string.upper(heading.sectionTitle)))
        SetAttention(heading, collapsed and SectionAttention(section.rows or {}) or nil, 1)
        for rowIndex = 1, #(section.rows or {}) do
            local data = section.rows[rowIndex]
            local row = visibleRowsByKey[data.key]
            if not collapsed then
                local visible = DataVisible(data)
                if visible ~= (row ~= nil) then return false end
                if visible then
                    row.data = data
                    row.icon:SetTexture(data.icon or 134400)
                    row.label:SetText(DataValue(data, "label") or "")
                    row.detail:SetText(DataValue(data, "detail") or "")
                    row.stripe:SetColorTexture(StateColor(data.state))
                    ApplyProgress(row, data, row:GetWidth() or content:GetWidth() or 1)
                    ApplyDataTypography(row, data)
                    SetAttention(row, DataValue(data, "attention"), 2)
                end
            end
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
    end
    if QueueSecureActionSync then QueueSecureActionSync() end
    return true
end

function ns.QueueProviderPresentation(providerID, previous, current)
    if not ns.QueueBudgetedWork then
        ns.RequestRender("provider committed: " .. tostring(providerID))
        return
    end
    ns.QueueBudgetedWork("provider-presentation:" .. tostring(providerID), function()
        return TryPatchProviderResult(previous, current)
    end, function(patched)
        if not patched then ns.RequestRender("provider structure changed: " .. tostring(providerID)) end
    end)
end

local function MaximumScroll()
    return math.max(0, (content:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
end

local function SetScroll(value)
    scrollFrame:SetVerticalScroll(Clamp(value, 0, MaximumScroll(), 0))
    if QueueSecureActionSync then QueueSecureActionSync() end
end

local function ScrollRecommendations(_, delta)
    SetScroll(scrollFrame:GetVerticalScroll() - delta * 40)
end

scrollFrame:SetScript("OnMouseWheel", ScrollRecommendations)
fixedFrame:EnableMouseWheel(true)
fixedFrame:SetScript("OnMouseWheel", ScrollRecommendations)

local function TitleBarMode()
    local mode = ns.Get("titleBarMode")
    if mode ~= "filled" and mode ~= "transparent" and mode ~= "hidden" then return "filled" end
    return mode
end

local function TitleBarHeight()
    if TitleBarMode() == "hidden" then return 0 end
    return math.max(Clamp(ns.Get("titleBarHeight"), 20, 40, 28),
        Clamp(ns.Get("titleFontSize"), 8, 24, 13) + 8)
end

local function TitleSeparatorSize()
    if TitleBarMode() == "hidden" then return 0 end
    return Clamp(ns.Get("titleSeparatorSize"), 0, 4, 0)
end

local function ChromeHeight()
    return TitleBarHeight() + TitleSeparatorSize() + PanePadding() * 2
end

local function GrowthDirection()
    return ns.Get("paneGrowthDirection") == "UP" and "UP" or "DOWN"
end

local function AnchorVertical(point)
    point = tostring(point or "CENTER"):upper()
    if point:find("TOP", 1, true) then return "TOP" end
    if point:find("BOTTOM", 1, true) then return "BOTTOM" end
    return "CENTER"
end

local function UnlockAnchorInfo()
    local db = _G.EllesmereUIDB
    local info = db and db.unlockAnchors and db.unlockAnchors[UNLOCK_KEY]
    return info and info.target and info or nil
end

-- A vertical EllesmereUI link owns the edge from which the tracker grows.  In
-- particular, TOP -> BOTTOM must keep the tracker's top below its target even
-- when the user selected upward growth for an otherwise free-floating pane.
local function EffectiveGrowthDirection()
    local info = UnlockAnchorInfo()
    if info then
        if info.mode == "POINT" then
            local sourceEdge = AnchorVertical(info.sourcePoint)
            if sourceEdge == "TOP" then return "DOWN" end
            if sourceEdge == "BOTTOM" then return "UP" end
        else
            local targetEdge = AnchorVertical(info.side)
            if targetEdge == "BOTTOM" then return "DOWN" end
            if targetEdge == "TOP" then return "UP" end
        end
    end
    return GrowthDirection()
end

local function AvailablePanelHeight()
    local frameScale = math.max(0.01, frame:GetEffectiveScale() or frame:GetScale() or 1)
    local parentScale = math.max(0.01, UIParent and UIParent:GetEffectiveScale() or 1)
    local scaleRatio = frameScale / parentScale
    local screenHeight = UIParent and UIParent:GetHeight() or 768
    local screenTop = UIParent and UIParent:GetTop()
    local screenBottom = UIParent and UIParent:GetBottom()
    screenTop = screenTop or screenHeight
    screenBottom = screenBottom or 0

    -- Measure from the point that actually owns the frame, not from the edge
    -- implied by a setting. A CENTER-anchored frame changes both GetTop() and
    -- GetBottom() when its height changes; measuring one of those moving edges
    -- creates a geometric feedback loop (100% -> 75% -> 62.5% -> ...). Dynamic
    -- side links likewise have an implicit source edge that is not stored.
    local info = UnlockAnchorInfo()
    local sourceEdge
    if info then
        if info.mode == "POINT" then
            sourceEdge = AnchorVertical(info.sourcePoint)
        else
            local targetEdge = AnchorVertical(info.side)
            if targetEdge == "BOTTOM" then sourceEdge = "TOP"
            elseif targetEdge == "TOP" then sourceEdge = "BOTTOM"
            else sourceEdge = "CENTER" end
        end
    else
        local point = frame:GetPoint(1)
        sourceEdge = AnchorVertical(point)
    end

    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not top or not bottom then return math.max(48, math.floor(screenHeight / scaleRatio)) end
    top, bottom = top * scaleRatio, bottom * scaleRatio

    local available
    if sourceEdge == "TOP" then
        available = top - screenBottom
    elseif sourceEdge == "BOTTOM" then
        available = screenTop - bottom
    else
        -- A center point grows symmetrically regardless of the requested visual
        -- direction. Use the largest stable height that fits on both sides.
        local center = (top + bottom) * 0.5
        available = math.max(0, math.min(screenTop - center, center - screenBottom) * 2)
    end
    -- Leave a small viewport gutter so borders and shadows are never clipped.
    return math.max(48, math.floor((available - 4) / scaleRatio))
end

local function MaximumPanelHeight()
    local available = AvailablePanelHeight()
    local frameScale = math.max(0.01, frame:GetEffectiveScale() or frame:GetScale() or 1)
    local parentScale = math.max(0.01, UIParent and UIParent:GetEffectiveScale() or 1)
    local scaleRatio = frameScale / parentScale
    local screenHeight = UIParent and UIParent:GetHeight() or 768
    local limitMode = tostring(ns.Get("paneHeightLimitMode") or "AUTO"):upper()
    if limitMode == "PERCENT" then
        local percent = Clamp(ns.Get("paneHeightLimitPercent"), 10, 100, 75)
        local limit = math.floor((screenHeight * percent / 100) / scaleRatio)
        return math.max(48, math.min(limit, available))
    elseif limitMode == "PIXELS" then
        local pixels = Clamp(ns.Get("paneHeightLimitPixels"), 120, 1600, 600)
        local limit = math.floor(pixels / scaleRatio)
        return math.max(48, math.min(limit, available))
    end

    -- A live unlock-mode anchor already imposes the meaningful height limit:
    -- the space between its fixed edge and the viewport.  Applying the normal
    -- 75% cap on top of that leaves an arbitrary gap at the far screen edge.
    if UnlockAnchorInfo() or ns.Get("maximizePaneHeight") == true then
        return available
    end

    local normalLimit = math.floor((screenHeight * 0.75) / scaleRatio)
    return math.max(48, math.min(normalLimit, available))
end

local function TitleControlColor()
    return ThemeColor("titleTextColorMode", "titleTextColor")
end

local function DamageMeterModule()
    return EUI._ModuleNS and EUI._ModuleNS.EllesmereUIDamageMeters
end

local function UpdateLockIcon()
    local key = ns.Get("locked") and "locked" or "unlocked"
    local dm = DamageMeterModule()
    local art = dm and dm.DMHdrArt and dm.DMHdrArt(key)
    lockButton:SetSize(art and 18 or 13, art and 18 or 17)
    lockTexture:ClearAllPoints()
    lockTexture:SetAllPoints(lockButton)
    if dm and dm.DMPaintHdrArt and dm.DMPaintHdrArt(lockTexture, key) then return end

    lockTexture._hdrArt = nil
    if lockTexture._fvPlate then lockTexture._fvPlate:Hide() end
    lockTexture:SetDesaturated(true)
    lockTexture:SetVertexColor(1, 1, 1, 1)
    if dm then
        lockTexture:SetTexture(DAMAGE_METER_MEDIA .. (key == "locked" and "dm_locked.png" or "dm_unlocked.png"))
        lockTexture:SetTexCoord(0, 1, 0, 1)
    else
        lockButton:SetSize(18, 18)
        lockTexture:SetTexture(key == "locked"
            and "Interface\\Buttons\\LockButton-Locked-Up"
            or "Interface\\Buttons\\LockButton-Unlocked-Up")
        lockTexture:SetTexCoord(0.1875, 0.78125, 0.21875, 0.78125)
    end
end

UpdateLockFade = function()
    if lockButton:IsMouseOver() then
        lockButton:SetAlpha(0.7)
    elseif frame:IsMouseOver() then
        lockButton:SetAlpha(0.3)
    else
        lockButton:SetAlpha(0)
    end
end

function ns.ApplyLockState()
    UpdateLockIcon()
    UpdateLockFade()
end

local function ApplyWindowStyle()
    local r, g, b, a = ConfiguredColor("backgroundColor")
    local backgroundOpacity = Clamp(ns.Get("opacity"), 0, 1, 0.96)
    frame:SetAlpha(1)
    frame:SetBackdropColor(r, g, b, a * backgroundOpacity)

    local borderR, borderG, borderB, borderA = ConfiguredColor("borderColor")
    local borderSize = Clamp(ns.Get("borderSize"), 0, 4, 1)
    local borderTexture = ns.Get("borderTexture") or "solid"
    if EUI.ApplyBorderStyle then
        EUI.ApplyBorderStyle(borderFrame, borderSize, borderR, borderG, borderB, borderA, borderTexture)
    else
        borderFrame:SetBackdrop(borderSize > 0 and {
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = borderSize,
        } or nil)
        if borderSize > 0 then
            borderFrame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
            borderFrame:Show()
        else
            borderFrame:Hide()
        end
    end

    local mode = TitleBarMode()
    local headerHeight = TitleBarHeight()
    header:SetHeight(math.max(1, headerHeight))
    header:SetShown(mode ~= "hidden")
    if mode == "filled" then
        local hr, hg, hb, ha = ConfiguredColor("titleBarColor")
        header:SetBackdropColor(hr, hg, hb, ha)
    else
        header:SetBackdropColor(0, 0, 0, 0)
    end

    local tr, tg, tb, ta = TitleControlColor()
    ApplyTextAppearance()
    title:SetTextColor(tr, tg, tb, ta)
    collapseButton.text:SetTextColor(tr, tg, tb, ta)
    title:SetShown(mode ~= "hidden")
    collapseButton:ClearAllPoints()
    if mode ~= "hidden" then
        collapseButton:SetPoint("RIGHT", header, "RIGHT", -7, 0)
    end
    collapseButton:Show()

    title:ClearAllPoints()
    local alignment = ns.Get("titleAlignment")
    if alignment == "CENTER" then
        title:SetPoint("CENTER", header, "CENTER", 0, 0)
        title:SetJustifyH("CENTER")
    elseif alignment == "RIGHT" then
        title:SetPoint("RIGHT", collapseButton, "LEFT", -8, 0)
        title:SetJustifyH("RIGHT")
    else
        title:SetPoint("LEFT", header, "LEFT", 9, 0)
        title:SetPoint("RIGHT", collapseButton, "LEFT", -8, 0)
        title:SetJustifyH("LEFT")
    end

    local separatorSize = TitleSeparatorSize()
    local sr, sg, sb, sa = ConfiguredColor("titleSeparatorColor")
    headerSeparator:SetHeight(math.max(1, separatorSize))
    headerSeparator:SetColorTexture(sr, sg, sb, sa)
    headerSeparator:SetShown(mode ~= "hidden" and separatorSize > 0)

    local padding = PanePadding()
    local topInset = headerHeight + separatorSize + padding
    fixedFrame:ClearAllPoints()
    fixedFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -topInset)
    fixedFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padding, -topInset)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", fixedFrame, "BOTTOMLEFT")
    scrollFrame:SetPoint("TOPRIGHT", fixedFrame, "BOTTOMRIGHT")
    if mode == "hidden" then
        collapseButton:SetPoint("TOPRIGHT", fixedFrame, "TOPRIGHT", 0, math.min(4, padding))
    end
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT")
    contextButton:ClearAllPoints()
    contextButton:SetPoint("TOPLEFT", fixedFrame, "TOPLEFT", 2, 0)
    contextButton:SetPoint("TOPRIGHT", fixedFrame, "TOPRIGHT", mode == "hidden" and -28 or -2, 0)
    contextText:ClearAllPoints()
    contextText:SetPoint("TOPLEFT", contextButton, "TOPLEFT", 0, 0)
    contextText:SetPoint("TOPRIGHT", contextButton, "TOPRIGHT", 0, 0)
    playtimeText:ClearAllPoints()
    playtimeText:SetPoint("TOPLEFT", fixedFrame, "TOPLEFT", 2, 0)
    playtimeText:SetPoint("TOPRIGHT", fixedFrame, "TOPRIGHT", mode == "hidden" and -28 or -2, 0)
    UpdateLockIcon()
    UpdateLockFade()
end

HasUnlockAnchor = function()
    return UnlockAnchorInfo() and true or false
end

local function GrowthAnchorPoint(point)
    point = tostring(point or "CENTER"):upper()
    local horizontal = point:find("LEFT", 1, true) and "LEFT"
        or (point:find("RIGHT", 1, true) and "RIGHT" or "")
    return (GrowthDirection() == "UP" and "BOTTOM" or "TOP") .. horizontal
end

local function ApplyGrowthAnchor()
    -- EllesmereUI's dynamic link is the position authority.  Rewriting its
    -- source point here can invert a TOP -> BOTTOM link and grow through the
    -- element the tracker was deliberately placed beneath.
    if HasUnlockAnchor() then return false end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return false end
    local desiredPoint = GrowthAnchorPoint(point)
    if point == desiredPoint then return false end

    local height = frame:GetHeight() or 0
    local oldVertical = AnchorVertical(point)
    local delta = 0
    if GrowthDirection() == "UP" then
        if oldVertical == "TOP" then delta = -height
        elseif oldVertical == "CENTER" then delta = -height * 0.5 end
    else
        if oldVertical == "BOTTOM" then delta = height
        elseif oldVertical == "CENTER" then delta = height * 0.5 end
    end

    frame:ClearAllPoints()
    frame:SetPoint(desiredPoint, relativeTo or UIParent, relativePoint or desiredPoint, x or 0, (y or 0) + delta)
    return true
end

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.Set("position", { point = point, relativePoint = relativePoint, x = x, y = y }, true)
end

local function SetPosition()
    if HasUnlockAnchor() and EUI.ReapplyOwnAnchor then
        EUI.ReapplyOwnAnchor(UNLOCK_KEY)
        return
    end
    local position = ns.Get("position")
    if type(position) ~= "table" then position = ns.DEFAULTS.position end
    frame:ClearAllPoints()
    frame:SetPoint(position.point or "TOPRIGHT", UIParent, position.relativePoint or position.point or "TOPRIGHT", position.x or -330, position.y or -220)
    if ApplyGrowthAnchor() then SavePosition() end
end

local function BeginTrackerDrag(surface)
    if ns.Get("locked") or HasUnlockAnchor() then return end
    if HideSecureActionButtons then HideSecureActionButtons() end
    surface._trackerDragged = true
    GameTooltip_Hide()
    frame:StartMoving()
end

local function EndTrackerDrag(surface)
    if not surface._trackerDragged then return end
    frame:StopMovingOrSizing()
    ApplyGrowthAnchor()
    SavePosition()
    if ns.RequestRefresh then ns.RequestRefresh(false, "pane moved") end
    if QueueSecureActionSync then QueueSecureActionSync() end
    C_Timer.After(0, function() surface._trackerDragged = nil end)
end

RegisterDragSurface = function(surface)
    surface:EnableMouse(true)
    surface:RegisterForDrag("LeftButton")
    surface:SetScript("OnDragStart", BeginTrackerDrag)
    surface:SetScript("OnDragStop", EndTrackerDrag)
end

RegisterDragSurface(frame)
RegisterDragSurface(header)
RegisterDragSurface(fixedFrame)
RegisterDragSurface(contextButton)
RegisterDragSurface(scrollFrame)
RegisterDragSurface(content)

collapseButton:SetScript("OnClick", function()
    ns.Set("collapsed", not ns.Get("collapsed"))
end)
collapseButton:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    UpdateLockFade()
    ShowTooltip(self, { label = ns.Get("collapsed") and "Expand" or "Collapse", detail = "Show or hide the recommendation sections." })
end)
collapseButton:SetScript("OnLeave", function(self)
    self:SetAlpha(0.85)
    GameTooltip_Hide()
    C_Timer.After(0, UpdateLockFade)
end)

lockButton:SetScript("OnClick", function()
    ns.Set("locked", not ns.Get("locked"), true)
    ns.ApplyLockState()
    if EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() end
    if EUI.ShowWidgetTooltip then EUI.ShowWidgetTooltip(lockButton, ns.Get("locked") and "Locked" or "Unlocked") end
end)
lockButton:SetScript("OnEnter", function(self)
    self:SetAlpha(0.7)
    if EUI.ShowWidgetTooltip then
        EUI.ShowWidgetTooltip(self, ns.Get("locked") and "Locked" or "Unlocked")
    else
        ShowTooltip(self, { label = ns.Get("locked") and "Locked" or "Unlocked", detail = "Click to toggle the window lock." })
    end
end)
lockButton:SetScript("OnLeave", function()
    if EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() else GameTooltip_Hide() end
    C_Timer.After(0, UpdateLockFade)
end)

frame:SetScript("OnEnter", UpdateLockFade)
frame:SetScript("OnLeave", function() C_Timer.After(0, UpdateLockFade) end)
header:SetScript("OnEnter", UpdateLockFade)
header:SetScript("OnLeave", function() C_Timer.After(0, UpdateLockFade) end)

local function BaseVisibilityAllows()
    if not ns.Get("enabled") then return false end
    if ns.Get("hideInCombat") and InCombatLockdown and InCombatLockdown()
        and not (ns.IsInstanceBossTimerActive and ns.IsInstanceBossTimerActive()) then return false end
    if ns.Get("hideInInstances") then
        local inInstance = IsInInstance and IsInInstance()
        if inInstance then return false end
    end
    return true
end

local function CurrentContextLines()
    if ns.GetTrackerContextLines then return ns.GetTrackerContextLines() end
    if ns.Get("showContext") then return ns.GetZoneName(), nil end
    return nil, nil
end

local function UpdateContextButtonText(contextLine)
    -- Replacing hyperlinked text invalidates WoW's current hyperlink hover,
    -- even when only a timer digit changed. Keep its geometry stable until the
    -- real mouse-leave event, while still refreshing the tooltip data.
    if contextButton._statusHoverLink then
        local ownsTooltip = not GameTooltip.IsOwned or GameTooltip:IsOwned(contextButton)
        if ownsTooltip and ns.ShowStatusLinkTooltip then
            ns.ShowStatusLinkTooltip(contextButton, contextButton._statusHoverLink)
        end
    else
        contextButton:SetText(contextLine)
    end
end

function ns.RefreshTrackerContextText()
    if not (frame:IsShown() and fixedFrame:IsShown()) then return end
    local contextLine, playtimeLine = CurrentContextLines()
    if contextButton:IsShown() and contextLine then
        UpdateContextButtonText(contextLine)
        local minimum = math.max(19, Clamp(ns.Get("contextFontSize"), 8, 24, 11) + 8)
        local expected = math.max(minimum, math.ceil(contextText:GetStringHeight() or 0) + 5)
        if math.abs((contextButton:GetHeight() or 0) - expected) > 0.5 and ns.RequestRefresh then
            ns.RequestRefresh(false, "context height")
        end
    end
    if playtimeText:IsShown() and playtimeLine then playtimeText:SetText(playtimeLine) end
end

local function RenderBody(snapshot)
    if HideSecureActionButtons then HideSecureActionButtons() end
    BeginPoolRender()
    local renderedDisclosures = {}
    SetAttention(collapseButton, nil)
    if not BaseVisibilityAllows() then frame:Hide(); return end
    if ns.Get("hideWhenReady") and not snapshot.actionable and not snapshot.forceVisible then frame:Hide(); return end
    frame:Show()
    if ns.YieldForBudget then ns.YieldForBudget() end

    local width = math.max(280, math.min(480, tonumber(ns.Get("width")) or 340))
    local padding = PanePadding()
    local contentWidth = math.max(1, width - padding * 2)
    SetWidthIfChanged(frame, width)
    SetWidthIfChanged(content, contentWidth)
    if ApplyGrowthAnchor() and not HasUnlockAnchor() then SavePosition() end
    local collapsed = ns.Get("collapsed") == true
    collapseButton.text:SetText(collapsed and "+" or "−")
    SetAttention(collapseButton, collapsed and SnapshotAttention(snapshot) or nil, 1)
    fixedFrame:Show()
    scrollFrame:SetShown(not collapsed)

    local fixedY = 0
    local contextLine, playtimeLine
    contextLine, playtimeLine = CurrentContextLines()
    local contextLineHeight = math.max(19, Clamp(ns.Get("contextFontSize"), 8, 24, 11) + 8)
    local contextRight = TitleBarMode() == "hidden" and -28 or -2
    if contextLine then
        contextButton:ClearAllPoints()
        contextButton:SetPoint("TOPLEFT", fixedFrame, "TOPLEFT", 2, fixedY)
        contextButton:SetPoint("TOPRIGHT", fixedFrame, "TOPRIGHT", contextRight, fixedY)
        UpdateContextButtonText(contextLine)
        contextText:Show()
        local height = math.max(contextLineHeight, math.ceil(contextText:GetStringHeight() or 0) + 5)
        contextButton:SetHeight(height)
        contextButton:Show()
        fixedY = fixedY - height
    else
        contextButton:Hide()
        contextText:Hide()
    end
    if playtimeLine then
        playtimeText:ClearAllPoints()
        playtimeText:SetPoint("TOPLEFT", fixedFrame, "TOPLEFT", 2, fixedY)
        playtimeText:SetPoint("TOPRIGHT", fixedFrame, "TOPRIGHT", contextRight, fixedY)
        playtimeText:SetText(playtimeLine)
        playtimeText:Show()
        fixedY = fixedY - math.max(contextLineHeight, math.ceil(playtimeText:GetStringHeight() or 0) + 5)
    else
        playtimeText:Hide()
    end

    local iconCount = #snapshot.statuses
    if iconCount > 0 then
        local size = Clamp(ns.Get("readinessIconSize"), 20, 64, 31)
        local spacing = Clamp(ns.Get("readinessIconSpacing"), 0, 24, 6)
        local borderSize = Clamp(ns.Get("readinessIconBorderSize"), 0, 4, 2)
        local columns = math.max(1, math.min(iconCount, math.floor((contentWidth + spacing) / (size + spacing))))
        local rowCount = math.ceil(iconCount / columns)
        for i = 1, iconCount do
            local data = snapshot.statuses[i]
            local button = AcquireIcon(i)
            if data.key then visibleIconsByKey[data.key] = button end
            local row = math.floor((i - 1) / columns)
            local column = (i - 1) % columns
            local countInRow = math.min(columns, iconCount - row * columns)
            local rowWidth = countInRow * size + (countInRow - 1) * spacing
            local startX = math.max(0, (contentWidth - rowWidth) / 2)
            button.data = data
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", fixedFrame, "TOPLEFT", startX + column * (size + spacing), fixedY - row * (size + spacing))
            button.icon:SetTexture(data.icon or 134400)
            button.badge:SetText(data.badge or "")
            ApplyReadinessIconAppearance(button, data.state, size, borderSize)
            SetAttention(button, DataValue(data, "attention"), 2)
            button:Show()
            if ns.YieldForBudget then ns.YieldForBudget() end
        end
        fixedY = fixedY - rowCount * size - (rowCount - 1) * spacing - 9
    end

    local fixedHeight = math.max(1, math.abs(fixedY))
    SetHeightIfChanged(fixedFrame, fixedHeight)
    if collapsed then
        HideUnusedPools(iconCount, 0, 0)
        ApplyTextAppearance(iconCount, 0, 0)
        -- The registered Ellesmere resize observer re-applies a dynamic anchor
        -- exactly once when this height really changes. Calling it again here
        -- used to duplicate the cascade and its settle pass on every render.
        SetHeightIfChanged(frame, ChromeHeight() + fixedHeight)
        if QueueSecureActionSync then QueueSecureActionSync() end
        UpdateLockFade()
        return
    end
    local y = 0
    local sectionIndex, rowIndex = 0, 0
    for i = 1, #snapshot.sections do
        local section = snapshot.sections[i]
        local rows = section.rows or {}
        if #rows > 0 then
            sectionIndex = sectionIndex + 1
            local heading = AcquireSection(sectionIndex)
            local sectionID = tostring(section.id)
            local sectionTitle = section.title or sectionID
            local sectionCollapsed = SectionCollapsed(sectionID)
            heading.sectionID = sectionID
            heading.sectionTitle = sectionTitle
            heading.sectionCollapsed = sectionCollapsed
            heading.ToggleSection = ToggleSection
            visibleSectionsByID[sectionID] = heading
            heading:ClearAllPoints()
            local sectionHeight = math.max(16, Clamp(ns.Get("sectionFontSize"), 8, 24, 11) + 5)
            heading:SetHeight(sectionHeight)
            heading:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
            heading:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, y)
            heading.text:SetText(string.format("%s %s", sectionCollapsed and "+" or "−", string.upper(sectionTitle)))
            SetAttention(heading, sectionCollapsed and SectionAttention(rows) or nil, 1)
            heading:Show()
            if ns.YieldForBudget then ns.YieldForBudget() end
            y = y - sectionHeight - 2
            if not sectionCollapsed then
                for j = 1, #rows do
                    local data = rows[j]
                    if DataVisible(data) then
                        rowIndex = rowIndex + 1
                        local row = AcquireRow(rowIndex)
                        local labelSize = Clamp(data.labelFontSize, 8, 24, Clamp(ns.Get("entryLabelFontSize"), 8, 24, 12))
                        local detailSize = Clamp(data.detailFontSize, 8, 24, Clamp(ns.Get("entryDetailFontSize"), 8, 24, 10))
                        local progressHeight = type(data.progress) == "table" and Clamp(data.progress.height, 2, 24, 8) or 0
                        local rowHeight = math.max(37, labelSize + detailSize + 12 + (progressHeight > 0 and progressHeight + 6 or 0))
                        local rowIndent = Clamp(data.indentLevel, 0, 4, 0) * 18
                        local rowContentWidth = math.max(1, contentWidth - rowIndent)
                        row.data = data
                        if data.key then visibleRowsByKey[data.key] = row end
                        row:ClearAllPoints()
                        row:SetHeight(rowHeight)
                        row:SetPoint("TOPLEFT", content, "TOPLEFT", rowIndent, y)
                        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                        row.icon:SetTexture(data.icon or 134400)
                        row.icon:SetShown(not data.hideIcon)
                        local textLeft = data.hideIcon and 7 or 38
                        local textRight = (data.onDismiss or data.disclosure) and 26 or 7
                        row.dismiss:SetShown(type(data.onDismiss) == "function")
                        if data.disclosure and data.key then
                            renderedDisclosures[data.key] = DataValue(data, "expanded") == true
                        end
                        SetDisclosureActivity(row, data.key and pendingDisclosuresByKey[data.key] ~= nil)
                        row.label:ClearAllPoints()
                        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -4)
                        row.label:SetSize(math.max(1, rowContentWidth - textLeft - textRight), labelSize + 3)
                        row.detail:ClearAllPoints()
                        row.detail:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
                        row.detail:SetSize(math.max(1, rowContentWidth - textLeft - textRight), detailSize + 3)
                        row.label:SetText(DataValue(data, "label") or "")
                        row.detail:SetText(DataValue(data, "detail") or "")
                        row.stripe:SetColorTexture(StateColor(data.state))
                        ApplyProgress(row, data, rowContentWidth)
                        SetAttention(row, DataValue(data, "attention"), 2)
                        row:EnableMouse(true)
                        row:Show()
                        y = y - rowHeight - 3
                    end
                    if ns.YieldForBudget then ns.YieldForBudget() end
                end
            end
            y = y - 4
        end
    end

    local contentHeight = math.max(12, math.abs(y))
    SetHeightIfChanged(content, contentHeight)
    HideUnusedPools(iconCount, sectionIndex, rowIndex)
    ApplyTextAppearance(iconCount, sectionIndex, rowIndex)
    for index = 1, rowIndex do
        ApplyDataTypography(rowPool[index], rowPool[index].data)
        if ns.YieldForBudget then ns.YieldForBudget() end
    end
    local viewportHeight = math.min(contentHeight,
        math.max(12, MaximumPanelHeight() - ChromeHeight() - fixedHeight))
    SetHeightIfChanged(scrollFrame, viewportHeight)
    -- EllesmereUI hooks this registered outer frame's OnSizeChanged event. It
    -- owns the single size-aware anchor reapply and downstream propagation.
    SetHeightIfChanged(frame, ChromeHeight() + fixedHeight + viewportHeight)
    SetScroll(scrollFrame:GetVerticalScroll())
    if QueueSecureActionSync then QueueSecureActionSync() end
    UpdateLockFade()
    for key, pending in pairs(pendingDisclosuresByKey) do
        local renderedState = renderedDisclosures[key]
        if renderedState == nil or renderedState == pending.expected then
            pendingDisclosuresByKey[key] = nil
            SetDisclosureActivity(visibleRowsByKey[key], false)
        end
    end
end

function ns.RequestRender(reason, priority)
    reason = reason or "tracker render"
    if not ns.QueueBudgetedWork then return end
    ns.QueueBudgetedWork("Render", function()
        renderInProgress = true
        local snapshot = ns.BuildSnapshot()
        RenderBody(snapshot)
    end, function()
        renderInProgress = false
    end, nil, function(message)
        renderInProgress = false
        local handler = geterrorhandler and geterrorhandler()
        if type(handler) == "function" then handler(message) end
    end, priority == true)
end

function ns.RequestPresentationRefresh(reason)
    ns.RequestRender(reason or "interactive presentation refresh", true)
end

function ns.ApplySettings()
    if not ns.QueueBudgetedWork then return end
    ns.QueueBudgetedWork("tracker-settings", function()
        local strata = MainPaneStrata()
        frame:SetFrameStrata(strata)
        if not (InCombatLockdown and InCombatLockdown()) then
            for index = 1, #secureActionPool do
                secureActionPool[index]:SetFrameStrata(strata)
                if ns.YieldForBudget then ns.YieldForBudget() end
            end
        end
        frame:SetScale(math.max(0.65, math.min(1.5, tonumber(ns.Get("scale")) or 1)))
        frame:SetAlpha(1)
        ApplyWindowStyle()
        SetPosition()
    end, function()
        ns.RequestRender("settings applied")
    end)
end

function ns.RequestRefresh(providers, reason)
    if providers == nil then
        if ns.InvalidateAllProviders then ns.InvalidateAllProviders(reason or "unspecified refresh") end
    elseif providers ~= false and ns.InvalidateProviders then
        ns.InvalidateProviders(providers, reason or "targeted refresh")
    else
        ns.RequestRender(reason or "presentation refresh")
    end
end

ns.RefreshTracker = ns.RequestRender
ns.TrackerFrame = frame

if EUI.RegAccent then
    EUI.RegAccent({
        type = "callback",
        obj = frame,
        fn = function()
            ns.ApplySettings()
        end,
    })
end
if hooksecurefunc and type(EUI.ApplyColorsToOUF) == "function" then
    pcall(hooksecurefunc, EUI, "ApplyColorsToOUF", function()
        ns.ApplySettings()
    end)
end

local unlockRegistered = false
local function RegisterUnlockElement()
    if unlockRegistered or not (EUI.RegisterUnlockElements and EUI.MakeUnlockElement) then return unlockRegistered end
    EUI:RegisterUnlockElements({ EUI.MakeUnlockElement({
        key = UNLOCK_KEY,
        label = "Adventure Tracker",
        group = "Adventure Tracker",
        order = 565,
        getFrame = function() return frame end,
        isHidden = function() return not ns.Get("enabled") end,
        noSpecLayout = true,
        getSize = function()
            return tonumber(ns.Get("width")) or frame:GetWidth(), frame:GetHeight()
        end,
        setWidth = function(_, width)
            if width then ns.Set("width", math.floor(Clamp(width, 280, 480, 340) + 0.5), true) end
            frame:SetWidth(Clamp(ns.Get("width"), 280, 480, 340))
            Render()
        end,
        savePos = function(_, point, relativePoint, x, y)
            if not point then return end
            ns.Set("position", {
                point = point, relativePoint = relativePoint or point,
                x = x or 0, y = y or 0,
            }, true)
            if QueueSecureActionSync then QueueSecureActionSync() end
        end,
        loadPos = function()
            local position = ns.Get("position")
            if type(position) ~= "table" then position = ns.DEFAULTS.position end
            return {
                point = position.point or "TOPRIGHT",
                relPoint = position.relativePoint or position.point or "TOPRIGHT",
                x = position.x or -330, y = position.y or -220,
            }
        end,
        clearPos = function()
            local position = ns.DEFAULTS.position
            ns.Set("position", {
                point = position.point, relativePoint = position.relativePoint,
                x = position.x, y = position.y,
            }, true)
            SetPosition()
            if QueueSecureActionSync then QueueSecureActionSync() end
        end,
        applyPos = function()
            SetPosition()
            if QueueSecureActionSync then QueueSecureActionSync() end
        end,
    }) }, ADDON_NAME)
    unlockRegistered = true
    return true
end
RegisterUnlockElement()

-- A dynamic target can rebuild through several sizes after login. Follow every
-- movement immediately through EllesmereUI, but perform our viewport-height
-- calculation only once the target has been quiet for a short window.
local anchorGeometryTimer
if hooksecurefunc then
    hooksecurefunc(frame, "SetPoint", function()
        if not HasUnlockAnchor() or not (C_Timer and C_Timer.NewTimer) then return end
        if anchorGeometryTimer then anchorGeometryTimer:Cancel() end
        anchorGeometryTimer = C_Timer.NewTimer(0.35, function()
            anchorGeometryTimer = nil
            if HasUnlockAnchor() and ns.RequestRefresh then
                ns.RequestRefresh(false, "dynamic anchor settled")
            end
        end)
    end)
end

local events = CreateFrame("Frame")
local eventNames = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
    "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED",
    "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED",
    "CHAT_MSG_SKILL", "UNIT_INVENTORY_CHANGED", "UNIT_CONNECTION", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_UPDATE_RESTING", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_FLAGS_CHANGED", "UNIT_FLAGS", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE", "ITEM_DATA_LOAD_RESULT", "SPELL_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED",
    "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED",
    "CURRENCY_DISPLAY_UPDATE",
    "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "ACHIEVEMENT_EARNED",
}
for i = 1, #eventNames do pcall(events.RegisterEvent, events, eventNames[i]) end
pcall(events.RegisterEvent, events, "UNIT_AURA")

CurrentBagRecommendationSignature = function()
    local food = ns.GetReadinessInventorySignature and ns.GetReadinessInventorySignature() or ""
    local profession = ns.GetProfessionRouteInventorySignature and ns.GetProfessionRouteInventorySignature() or ""
    return food, profession
end

local function QueueBagSignatureUpdate(initializeOnly)
    if not ns.QueueBudgetedWork then return end
    ns.QueueBudgetedWork("inventory-signatures", function()
        return CurrentBagRecommendationSignature()
    end, function(food, profession)
        if initializeOnly and foodInventorySignature == nil and professionInventorySignature == nil then
            foodInventorySignature, professionInventorySignature = food, profession
            return
        end
        local providers = {}
        if foodInventorySignature ~= food then providers[#providers + 1] = "readiness" end
        if professionInventorySignature ~= profession then providers[#providers + 1] = "professions" end
        foodInventorySignature, professionInventorySignature = food, profession
        if #providers > 0 then ns.RequestRefresh(providers, "BAG_UPDATE_DELAYED") end
    end)
end

function ns.OnProviderCommitted(providerID)
    if providerID == "professions" and ns.GetCommittedProfessionRouteInventorySignature then
        professionInventorySignature = ns.GetCommittedProfessionRouteInventorySignature()
    end
end

local function QueueProfessionLoginRecovery()
    if not (C_Timer and C_Timer.After and ns.QueueBudgetedWork) then return end
    C_Timer.After(2, function()
        ns.QueueBudgetedWork("profession-login-readiness", function()
            if not ns.Get("showProfessions") or not ns.GetProfessionList
                or not ns.GetProviderRuntimeState then return false end
            local professions = ns.GetProfessionList()
            local result, dirty, queued, lastError = ns.GetProviderRuntimeState("professions")
            local hasSections = type(result) == "table" and (result.id ~= nil or #result > 0)
            return (lastError ~= nil or (#professions > 0 and not hasSections))
                and not dirty and not queued, lastError
        end, function(shouldRetry, lastError)
            if shouldRetry then
                ns.RequestRefresh("professions", lastError and "profession provider recovery"
                    or "profession API became ready")
            end
        end)
    end)
end

local professionScanTimer
local function EnqueueProfessionCacheScan()
    if not ns.QueueBudgetedWork then return end
    ns.QueueBudgetedWork("profession-recipe-scan", function()
        return ns.ScanProfessionRecipes and ns.ScanProfessionRecipes() or false
    end, function(changed)
        if changed then ns.RequestRefresh("professions", "profession recipe cache changed") end
    end, function()
        return not (ns.IsCombatRestricted and ns.IsCombatRestricted())
    end)
end

local function QueueProfessionCacheScan()
    if professionScanTimer and professionScanTimer.Cancel then professionScanTimer:Cancel() end
    if not (C_Timer and C_Timer.NewTimer) then
        EnqueueProfessionCacheScan()
        return
    end
    professionScanTimer = C_Timer.NewTimer(0.1, function()
        professionScanTimer = nil
        EnqueueProfessionCacheScan()
    end)
end

-- UNIT_AURA fires for every temporary effect, including the generic eating and
-- drinking auras. Track the provider relevance of aura instances so unrelated
-- consumable effects never rebuild readiness or world-buff rows. Unknown/full
-- updates remain conservative for API compatibility.
local auraInstanceScopes = {}

local function AddAuraProvider(providers, seen, provider)
    if not seen[provider] then
        seen[provider] = true
        providers[#providers + 1] = provider
    end
end

local function AuraScope(unit, spellID, spellName)
    if type(spellID) ~= "number" or (issecretvalue and issecretvalue(spellID)) then
        return { readiness = true, world = unit == "player" }
    end
    return {
        readiness = ns.IsReadinessAuraSpell and ns.IsReadinessAuraSpell(spellID, spellName) or false,
        world = unit == "player" and ns.IsWorldBuffAuraSpell and ns.IsWorldBuffAuraSpell(spellID) or false,
    }
end

local function ProvidersForAuraEvent(unit, updateInfo)
    local providers, seen = {}, {}
    local function addScope(scope)
        if not scope then
            AddAuraProvider(providers, seen, "readiness")
            if unit == "player" then AddAuraProvider(providers, seen, "world-buffs") end
            return
        end
        if scope.readiness then AddAuraProvider(providers, seen, "readiness") end
        if scope.world then AddAuraProvider(providers, seen, "world-buffs") end
    end

    if type(updateInfo) ~= "table" or (issecretvalue and issecretvalue(updateInfo)) then
        addScope(nil)
        return providers
    end
    local fullUpdate = updateInfo.isFullUpdate
    if (issecretvalue and issecretvalue(fullUpdate)) or fullUpdate then
        addScope(nil)
        return providers
    end

    local cache = auraInstanceScopes[unit]
    if not cache then
        cache = {}
        auraInstanceScopes[unit] = cache
    end
    local sawDelta = false

    for _, aura in ipairs(type(updateInfo.addedAuras) == "table" and updateInfo.addedAuras or {}) do
        sawDelta = true
        if type(aura) ~= "table" or (issecretvalue and issecretvalue(aura)) then
            addScope(nil)
        else
            local instanceID = aura.auraInstanceID
            local scope = AuraScope(unit, aura.spellId or aura.spellID, aura.name)
            if type(instanceID) == "number" and not (issecretvalue and issecretvalue(instanceID)) then
                cache[instanceID] = scope
            end
            addScope(scope)
        end
    end

    for _, instanceID in ipairs(type(updateInfo.updatedAuraInstanceIDs) == "table" and updateInfo.updatedAuraInstanceIDs or {}) do
        sawDelta = true
        if (issecretvalue and issecretvalue(instanceID)) or type(instanceID) ~= "number" then
            addScope(nil)
        else
            local scope = cache[instanceID]
            if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, instanceID)
                if ok and type(aura) == "table" and not (issecretvalue and issecretvalue(aura)) then
                    scope = AuraScope(unit, aura.spellId or aura.spellID, aura.name)
                    cache[instanceID] = scope
                end
            end
            addScope(scope)
        end
    end

    for _, instanceID in ipairs(type(updateInfo.removedAuraInstanceIDs) == "table" and updateInfo.removedAuraInstanceIDs or {}) do
        sawDelta = true
        if (issecretvalue and issecretvalue(instanceID)) or type(instanceID) ~= "number" then
            addScope(nil)
        else
            local scope = cache[instanceID]
            cache[instanceID] = nil
            addScope(scope)
        end
    end

    if not sawDelta then addScope(nil) end
    return providers
end

local trainerScanTimer
local function EnqueueTrainerCacheScan()
    if not ns.QueueBudgetedWork then return end
    ns.QueueBudgetedWork("trainer-cache-scan", function()
        local classChanged = ns.ScanClassTrainer and ns.ScanClassTrainer() or false
        local professionChanged = ns.ScanProfessionTrainer and ns.ScanProfessionTrainer() or false
        return classChanged, professionChanged
    end, function(classChanged, professionChanged)
        if classChanged then ns.RequestRefresh("character-reminders", "class trainer cache changed") end
        if professionChanged then ns.RequestRefresh("professions", "profession trainer cache changed") end
    end, function()
        return not (ns.IsCombatRestricted and ns.IsCombatRestricted())
    end)
end

local function QueueTrainerCacheScan()
    if trainerScanTimer and trainerScanTimer.Cancel then trainerScanTimer:Cancel() end
    if not (C_Timer and C_Timer.NewTimer) then
        EnqueueTrainerCacheScan()
        return
    end
    trainerScanTimer = C_Timer.NewTimer(0.1, function()
        trainerScanTimer = nil
        EnqueueTrainerCacheScan()
    end)
end

local function ProvidersForTrackerEvent(event, ...)
    if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" or event == "ADDON_LOADED" then
        return false
    elseif event == "UNIT_AURA" then
        return ProvidersForAuraEvent(...)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_CONNECTION" then
        return { "readiness" }
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        return { "readiness", "world-buffs" }
    elseif event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" or event == "PLAYER_DEAD"
        or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        -- These events change the directly rendered status row. Relevant buff
        -- changes arrive separately through UNIT_AURA, so cached provider rows
        -- can be reused.
        return false
    elseif event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then
        local itemID, succeeded = ...
        return ns.ConsumeItemDataProviders and ns.ConsumeItemDataProviders(itemID, succeeded) or nil
    elseif event == "SPELL_DATA_LOAD_RESULT" then
        local spellID, succeeded = ...
        return ns.ConsumeSpellDataProviders and ns.ConsumeSpellDataProviders(spellID, succeeded) or nil
    elseif event == "UNIT_INVENTORY_CHANGED" then
        return { "readiness", "professions", "instances" }
    elseif event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
        return { "legacy", "zone-quests", "professions", "character-reminders" }
    elseif event == "LEARNED_SPELL_IN_TAB" then
        return { "professions", "character-reminders" }
    elseif event == "ACHIEVEMENT_EARNED" or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
        return { "legacy" }
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        local currencyID = ...
        if currencyID and tonumber(currencyID) ~= 3402 then return {} end
        return { "professions" }
    elseif event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" or event == "TRAIT_CONFIG_UPDATED" then
        return { "legacy", "readiness", "character-reminders", "professions" }
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        return { "readiness", "world-buffs", "legacy", "zone-quests", "professions", "instances" }
    elseif event == "PLAYER_LEVEL_UP" or event == "PLAYER_LEVEL_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
        or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        return { "character-reminders", "readiness", "world-buffs", "legacy",
            "zone-quests", "professions", "instances" }
    end
    return nil
end

local function IsContextOnlyEvent(event)
    return event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" or event == "PLAYER_DEAD"
        or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST"
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "BAG_UPDATE" then
        if ns.MarkReadinessInventoryBagDirty then ns.MarkReadinessInventoryBagDirty((...)) end
        return
    elseif event == "BAG_UPDATE_DELAYED" then
        QueueBagSignatureUpdate(false)
        return
    end
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        QueueProfessionCacheScan()
        return
    elseif event == "TRADE_SKILL_CLOSE" then
        if professionScanTimer and professionScanTimer.Cancel then professionScanTimer:Cancel() end
        professionScanTimer = nil
        return
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        QueueTrainerCacheScan()
        return
    elseif event == "TRAINER_CLOSED" then
        if trainerScanTimer and trainerScanTimer.Cancel then trainerScanTimer:Cancel() end
        trainerScanTimer = nil
        return
    elseif event == "LEARNED_SPELL_IN_TAB" and ns.MarkProfessionRecipeCachesDirty then
        local spellID = (...)
        ns.QueueBudgetedWork("profession-cache-dirty", function()
            return ns.MarkProfessionRecipeCachesDirty(spellID)
        end, function()
            ns.RequestRefresh({ "professions", "character-reminders" }, event)
        end)
        return
    end
    if (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "ACTIVE_COMBAT_CONFIG_CHANGED" or event == "PLAYER_TALENT_UPDATE"
        or event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" or event == "TRAIT_CONFIG_UPDATED")
        and ns.InvalidateCurrentSpecializationName then
        ns.InvalidateCurrentSpecializationName()
    end
    if event == "UNIT_AURA" then
        local unit = ...
        if unit and unit ~= "player" and not tostring(unit):match("^party%d+$") then return end
    end
    if event == "UNIT_FLAGS" then
        local unit = ...
        if unit and unit ~= "player" then return end
    end
    if event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit and unit ~= "player" then return end
    end
    if IsContextOnlyEvent(event) then
        if ns.RefreshTrackerContextText then ns.RefreshTrackerContextText() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if ns.RefreshTrackerContextText then ns.RefreshTrackerContextText() end
        if event == "PLAYER_REGEN_ENABLED" and ns.WakeBudgetedWork then ns.WakeBudgetedWork() end
    end
    if event == "PLAYER_REGEN_ENABLED" and QueueSecureActionSync then QueueSecureActionSync() end
    if event == "PLAYER_LOGIN" then
        RegisterUnlockElement()
        if ns.ActivateProviderRuntime then ns.ActivateProviderRuntime() end
        ns.ApplySettings()
        QueueBagSignatureUpdate(true)
        QueueProfessionLoginRecovery()
        -- Re-measure once WoW has resolved the saved point. Ongoing aura state is
        -- event-driven; exact warning-threshold transitions use one-shot timers.
        C_Timer.After(0, function()
            if ns.RequestRefresh then ns.RequestRefresh(false, "initial geometry settled") end
        end)
    elseif event == "ADDON_LOADED" then
        if (...) == "EllesmereUIDamageMeters" then
            UpdateLockIcon()
            ns.RequestRefresh(false, "damage meter loaded")
        end
    else
        local providers = ProvidersForTrackerEvent(event, ...)
        if (event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED"
            or event == "SPELL_DATA_LOAD_RESULT") and not providers then return end
        if type(providers) == "table" and #providers == 0 then return end
        ns.RequestRefresh(providers, event)
    end
end)

if EUI.RegisterSkin then
    EUI.RegisterSkin(ADDON_NAME, function(S)
        skin = S
        S.Font(title)
        S.Font(collapseButton.text)
        S.Font(contextText)
        S.Font(playtimeText)
        for i = 1, #iconPool do S.SquareIcon(iconPool[i].icon) end
        for i = 1, #sectionPool do S.Font(sectionPool[i].text) end
        for i = 1, #rowPool do
            S.Font(rowPool[i].label)
            S.Font(rowPool[i].detail)
            S.SquareIcon(rowPool[i].icon)
        end
        ApplyWindowStyle()
    end)
end
