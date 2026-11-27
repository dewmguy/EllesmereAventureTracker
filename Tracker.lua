-------------------------------------------------------------------------------
-- Adventure Tracker: floating window and rendering.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EUI = ns.EUI
local UNLOCK_KEY = "EAT_Tracker"
local DAMAGE_METER_MEDIA = "Interface\\AddOns\\EllesmereUIDamageMeters\\Media\\"

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
headerSeparator:SetPoint("BOTTOMLEFT")
headerSeparator:SetPoint("BOTTOMRIGHT")
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
local skin
local UpdateLockFade
local RegisterDragSurface
local HideSecureActionButtons
local QueueSecureActionSync
local HasUnlockAnchor

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

local function SetSurfaceBackground(surface, key)
    local r, g, b, a = ColorValue(key)
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
    if key then return ColorValue(key) end
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
    if not actionTooltip then GameTooltip:SetText(data.label or "Adventure Tracker") end
    local detail = data.tooltip or data.detail
    if detail and detail ~= "" then
        if actionTooltip then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine(detail, 1, 1, 1, true)
    end
    local clickHint = data.onClick and (data.clickHint or "Click to open.")
        or (owner._secureAction and data.secureClickHint)
    if clickHint then GameTooltip:AddLine(clickHint, 0.55, 0.82, 1) end
    GameTooltip:Show()
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
    button:SetScript("PostClick", function()
        if ns.RequestRefresh then C_Timer.After(0.1, ns.RequestRefresh) end
    end)
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
    for index = 1, #secureActionPool do DeactivateSecureActionButton(secureActionPool[index]) end
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
        end
    end
    SyncPool(iconPool)
    SyncPool(rowPool)
    for index = actionIndex + 1, #secureActionPool do
        DeactivateSecureActionButton(secureActionPool[index])
    end
end

QueueSecureActionSync = function()
    if secureActionSyncQueued or (InCombatLockdown and InCombatLockdown()) then return end
    secureActionSyncQueued = true
    C_Timer.After(0, SyncSecureActionButtons)
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
    row:SetScript("OnClick", function(self)
        if self._trackerDragged then return end
        if self.data and self.data.onClick then self.data.onClick() end
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

local function HidePools()
    for i = 1, #iconPool do
        SetAttention(iconPool[i], nil)
        iconPool[i]:Hide()
    end
    for i = 1, #sectionPool do
        SetAttention(sectionPool[i], nil)
        sectionPool[i]:Hide()
    end
    for i = 1, #rowPool do
        SetAttention(rowPool[i], nil)
        rowPool[i]:Hide()
    end
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

local function ApplyTextAppearance()
    StyleFontString(title, "titleFontSize", 13)
    StyleFontString(collapseButton.text, "titleFontSize", 13)
    StyleFontString(contextText, "contextFontSize", 11, "contextTextColor", "contextTextColorMode")
    StyleFontString(playtimeText, "contextFontSize", 11, "contextTextColor", "contextTextColorMode")
    local statusAlignment = tostring(ns.Get("statusTextAlignment") or "LEFT"):upper()
    if statusAlignment ~= "CENTER" and statusAlignment ~= "RIGHT" then statusAlignment = "LEFT" end
    contextText:SetJustifyH(statusAlignment)
    playtimeText:SetJustifyH(statusAlignment)
    for i = 1, #iconPool do
        StyleFontString(iconPool[i].badge, "badgeFontSize", 10, "badgeTextColor", "badgeTextColorMode", 6, 32)
    end
    for i = 1, #sectionPool do
        local section = sectionPool[i]
        StyleFontString(section.text, "sectionFontSize", 11, "sectionTextColor", "sectionTextColorMode")
        SetSurfaceBackground(section, section:IsMouseOver() and "sectionHoverBackgroundColor" or "sectionBackgroundColor")
    end
    for i = 1, #rowPool do
        local row = rowPool[i]
        StyleFontString(row.label, "entryLabelFontSize", 12, "entryLabelTextColor", "entryLabelTextColorMode")
        StyleFontString(row.detail, "entryDetailFontSize", 10, "entryDetailTextColor", "entryDetailTextColorMode")
        SetSurfaceBackground(row, row:IsMouseOver() and "entryHoverBackgroundColor" or "entryBackgroundColor")
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
    return ThemeColor(TEXT_COLOR_MODES[fallbackKey], fallbackKey)
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
    if ns.RequestRefresh then ns.RequestRefresh() end
end

local function SectionAttention(rows)
    local attention
    for index = 1, #rows do
        if rows[index].attention == "critical" then return "critical" end
        if rows[index].attention == "warning" then attention = "warning" end
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
    end
    return attention
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

local function ChromeHeight()
    return TitleBarHeight() + PanePadding() * 2
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

    local growth = EffectiveGrowthDirection()
    local fixedEdge = growth == "UP" and frame:GetBottom() or frame:GetTop()
    if not fixedEdge then return math.max(48, math.floor(screenHeight / scaleRatio)) end
    fixedEdge = fixedEdge * scaleRatio

    local available
    if growth == "UP" then
        available = screenTop - fixedEdge
    else
        available = fixedEdge - screenBottom
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

local function ApplyWindowStyle()
    local r, g, b, a = ColorValue("backgroundColor")
    local backgroundOpacity = Clamp(ns.Get("opacity"), 0, 1, 0.96)
    frame:SetAlpha(1)
    frame:SetBackdropColor(r, g, b, a * backgroundOpacity)

    local borderR, borderG, borderB, borderA = ColorValue("borderColor")
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
        local hr, hg, hb, ha = ColorValue("titleBarColor")
        header:SetBackdropColor(hr, hg, hb, ha)
    else
        header:SetBackdropColor(0, 0, 0, 0)
    end

    local tr, tg, tb, ta = TitleControlColor()
    ApplyTextAppearance()
    title:SetTextColor(tr, tg, tb, ta)
    collapseButton.text:SetTextColor(tr, tg, tb, ta)
    title:SetShown(mode ~= "hidden" and ns.Get("showTitleText") == true)
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

    local separatorSize = Clamp(ns.Get("titleSeparatorSize"), 0, 4, 0)
    local sr, sg, sb, sa = ColorValue("titleSeparatorColor")
    headerSeparator:SetHeight(math.max(1, separatorSize))
    headerSeparator:SetColorTexture(sr, sg, sb, sa)
    headerSeparator:SetShown(mode ~= "hidden" and separatorSize > 0)

    local padding = PanePadding()
    local topInset = headerHeight + padding
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
    if ns.RequestRefresh then ns.RequestRefresh() end
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
    ns.Set("locked", not ns.Get("locked"))
    ns.ApplySettings()
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
            ns.RequestRefresh()
        end
    end
    if playtimeText:IsShown() and playtimeLine then playtimeText:SetText(playtimeLine) end
end

local function Render()
    if HideSecureActionButtons then HideSecureActionButtons() end
    HidePools()
    SetAttention(collapseButton, nil)
    if not BaseVisibilityAllows() then frame:Hide(); return end
    local snapshot = ns.BuildSnapshot()
    if ns.Get("hideWhenReady") and not snapshot.actionable and not snapshot.forceVisible then frame:Hide(); return end
    frame:Show()

    local width = math.max(280, math.min(480, tonumber(ns.Get("width")) or 340))
    local padding = PanePadding()
    local contentWidth = math.max(1, width - padding * 2)
    frame:SetWidth(width)
    content:SetWidth(contentWidth)
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
            SetAttention(button, data.attention, 2)
            button:Show()
        end
        fixedY = fixedY - rowCount * size - (rowCount - 1) * spacing - 9
    end

    local fixedHeight = math.max(1, math.abs(fixedY))
    fixedFrame:SetHeight(fixedHeight)
    if collapsed then
        ApplyTextAppearance()
        frame:SetHeight(ChromeHeight() + fixedHeight)
        if HasUnlockAnchor() and EUI.ReapplyOwnAnchor then
            EUI.ReapplyOwnAnchor(UNLOCK_KEY)
        end
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
            heading:ClearAllPoints()
            local sectionHeight = math.max(16, Clamp(ns.Get("sectionFontSize"), 8, 24, 11) + 5)
            heading:SetHeight(sectionHeight)
            heading:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
            heading:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, y)
            heading.text:SetText(string.format("%s %s", sectionCollapsed and "+" or "−", string.upper(sectionTitle)))
            SetAttention(heading, sectionCollapsed and SectionAttention(rows) or nil, 1)
            heading:Show()
            y = y - sectionHeight - 2
            if not sectionCollapsed then
                for j = 1, #rows do
                    rowIndex = rowIndex + 1
                    local data = rows[j]
                    local row = AcquireRow(rowIndex)
                    local labelSize = Clamp(data.labelFontSize, 8, 24, Clamp(ns.Get("entryLabelFontSize"), 8, 24, 12))
                    local detailSize = Clamp(data.detailFontSize, 8, 24, Clamp(ns.Get("entryDetailFontSize"), 8, 24, 10))
                    local progressHeight = type(data.progress) == "table" and Clamp(data.progress.height, 2, 24, 8) or 0
                    local rowHeight = math.max(37, labelSize + detailSize + 12 + (progressHeight > 0 and progressHeight + 6 or 0))
                    local rowIndent = Clamp(data.indentLevel, 0, 4, 0) * 18
                    local rowContentWidth = math.max(1, contentWidth - rowIndent)
                    row.data = data
                    row:ClearAllPoints()
                    row:SetHeight(rowHeight)
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", rowIndent, y)
                    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                    row.icon:SetTexture(data.icon or 134400)
                    row.icon:SetShown(not data.hideIcon)
                    local textLeft = data.hideIcon and 7 or 38
                    local textRight = data.onDismiss and 26 or 7
                    row.dismiss:SetShown(type(data.onDismiss) == "function")
                    row.label:ClearAllPoints()
                    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -4)
                    row.label:SetSize(math.max(1, rowContentWidth - textLeft - textRight), labelSize + 3)
                    row.detail:ClearAllPoints()
                    row.detail:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
                    row.detail:SetSize(math.max(1, rowContentWidth - textLeft - textRight), detailSize + 3)
                    row.label:SetText(data.label or "")
                    row.detail:SetText(data.detail or "")
                    row.stripe:SetColorTexture(StateColor(data.state))
                    ApplyProgress(row, data, rowContentWidth)
                    SetAttention(row, data.attention, 2)
                    row:EnableMouse(true)
                    row:Show()
                    y = y - rowHeight - 3
                end
            end
            y = y - 4
        end
    end

    local contentHeight = math.max(12, math.abs(y))
    content:SetHeight(contentHeight)
    ApplyTextAppearance()
    for index = 1, rowIndex do ApplyDataTypography(rowPool[index], rowPool[index].data) end
    local viewportHeight = math.min(contentHeight,
        math.max(12, MaximumPanelHeight() - ChromeHeight() - fixedHeight))
    scrollFrame:SetHeight(viewportHeight)
    frame:SetHeight(ChromeHeight() + fixedHeight + viewportHeight)
    -- Center-based legacy links need a fresh size-aware placement after the
    -- height changes; point links are idempotent and simply preserve their
    -- explicit source edge.
    if HasUnlockAnchor() and EUI.ReapplyOwnAnchor then
        EUI.ReapplyOwnAnchor(UNLOCK_KEY)
    end
    SetScroll(scrollFrame:GetVerticalScroll())
    if QueueSecureActionSync then QueueSecureActionSync() end
    UpdateLockFade()
end

function ns.ApplySettings()
    local strata = MainPaneStrata()
    frame:SetFrameStrata(strata)
    if not (InCombatLockdown and InCombatLockdown()) then
        for index = 1, #secureActionPool do secureActionPool[index]:SetFrameStrata(strata) end
    end
    frame:SetScale(math.max(0.65, math.min(1.5, tonumber(ns.Get("scale")) or 1)))
    frame:SetAlpha(1)
    ApplyWindowStyle()
    SetPosition()
    Render()
end

local refreshQueued = false
function ns.RequestRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.05, function()
        refreshQueued = false
        Render()
    end)
end

ns.RefreshTracker = Render
ns.TrackerFrame = frame

if EUI.RegAccent then
    EUI.RegAccent({
        type = "callback",
        obj = frame,
        fn = function()
            ApplyWindowStyle()
            if ns.RequestRefresh then ns.RequestRefresh() end
        end,
    })
end
if hooksecurefunc and type(EUI.ApplyColorsToOUF) == "function" then
    pcall(hooksecurefunc, EUI, "ApplyColorsToOUF", function()
        ApplyWindowStyle()
        if ns.RequestRefresh then ns.RequestRefresh() end
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
            if ns.RequestRefresh then ns.RequestRefresh() end
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
            if ns.RequestRefresh then ns.RequestRefresh() end
            if QueueSecureActionSync then QueueSecureActionSync() end
        end,
        applyPos = function()
            SetPosition()
            if ns.RequestRefresh then ns.RequestRefresh() end
            if QueueSecureActionSync then QueueSecureActionSync() end
        end,
    }) }, ADDON_NAME)
    unlockRegistered = true
    return true
end
RegisterUnlockElement()

local events = CreateFrame("Frame")
local eventNames = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
    "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED",
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED",
    "CHAT_MSG_SKILL", "UNIT_INVENTORY_CHANGED", "UNIT_CONNECTION", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_UPDATE_RESTING", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_FLAGS_CHANGED", "UNIT_FLAGS", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "ITEM_DATA_LOAD_RESULT", "SPELL_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED",
    "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED",
    "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "ACHIEVEMENT_EARNED",
}
for i = 1, #eventNames do pcall(events.RegisterEvent, events, eventNames[i]) end
pcall(events.RegisterEvent, events, "UNIT_AURA")
events:SetScript("OnEvent", function(_, event, ...)
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
    if (event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE") and ns.ScanProfessionRecipes then
        ns.ScanProfessionRecipes()
    end
    if event == "PLAYER_REGEN_ENABLED" and HideSecureActionButtons then HideSecureActionButtons() end
    if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        if ns.ScanClassTrainer then ns.ScanClassTrainer() end
        if ns.ScanProfessionTrainer then ns.ScanProfessionTrainer() end
        if event == "TRAINER_SHOW" then
            C_Timer.After(0, function()
                if ns.ScanClassTrainer and ns.ScanClassTrainer() then ns.RequestRefresh() end
                if ns.ScanProfessionTrainer and ns.ScanProfessionTrainer() then ns.RequestRefresh() end
            end)
        end
    end
    if event == "PLAYER_LOGIN" then
        RegisterUnlockElement()
        ns.ApplySettings()
        C_Timer.NewTicker(10, ns.RequestRefresh)
    elseif event == "ADDON_LOADED" and (...) == "EllesmereUIDamageMeters" then
        UpdateLockIcon()
    else
        ns.RequestRefresh()
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
