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

local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
scrollFrame:SetPoint("TOPLEFT", 8, -34)
scrollFrame:SetPoint("TOPRIGHT", -8, -34)
scrollFrame:EnableMouseWheel(true)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetPoint("TOPLEFT")
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

local contextText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
contextText:SetPoint("TOPLEFT", 2, 0)
contextText:SetPoint("TOPRIGHT", -2, 0)
contextText:SetJustifyH("LEFT")
contextText:SetTextColor(0.67, 0.72, 0.75)

local iconPool, sectionPool, rowPool = {}, {}, {}
local skin
local UpdateLockFade
local RegisterDragSurface
local HideSecureCastButtons
local QueueSecureCastSync
local HasUnlockAnchor

local function ColorValue(key)
    local value = ns.Get(key)
    local fallback = ns.DEFAULTS[key] or {}
    if type(value) ~= "table" then value = fallback end
    return value.r or fallback.r or 1, value.g or fallback.g or 1,
        value.b or fallback.b or 1, value.a == nil and (fallback.a or 1) or value.a
end

local function SetSurfaceBackground(surface, key)
    local r, g, b, a = ColorValue(key)
    surface:SetBackdropColor(r, g, b, a)
end

local function StateColor(state)
    local color = COLORS[state] or COLORS.info
    return color[1], color[2], color[3]
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
    local spellTooltip = false
    if data.spellID then
        if GameTooltip.SetSpellByID then
            spellTooltip = pcall(GameTooltip.SetSpellByID, GameTooltip, data.spellID)
        elseif GameTooltip.SetHyperlink then
            spellTooltip = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(data.spellID))
        end
    end
    if not spellTooltip then GameTooltip:SetText(data.label or "Adventure Tracker") end
    local detail = data.tooltip or data.detail
    if detail and detail ~= "" then
        if spellTooltip then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine(detail, 1, 1, 1, true)
    end
    local clickHint = data.onClick and (data.clickHint or "Click to open.")
        or (owner._secureSpellAction and data.secureClickHint)
    if clickHint then GameTooltip:AddLine(clickHint, 0.55, 0.82, 1) end
    GameTooltip:Show()
end

local secureCastPool = {}
local secureCastSyncQueued = false

local function AcquireSecureCastButton(index)
    local button = secureCastPool[index]
    if button then return button end
    button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(frame:GetFrameLevel() + 40)
    button:RegisterForClicks("LeftButtonUp")
    button._secureSpellAction = true
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
    secureCastPool[index] = button
    return button
end

local function DeactivateSecureCastButton(button)
    if not button then return end
    if UnregisterStateDriver then pcall(UnregisterStateDriver, button, "visibility") end
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("unit", nil)
    button.data = nil
    button:Hide()
end

local function PositionSecureCastButton(button, owner)
    if HasUnlockAnchor and HasUnlockAnchor() then return false end
    if not (frame:IsShown() and scrollFrame:IsShown() and owner and owner:IsShown()) then return false end
    local left, right, top, bottom = owner:GetLeft(), owner:GetRight(), owner:GetTop(), owner:GetBottom()
    local scrollLeft, scrollRight = scrollFrame:GetLeft(), scrollFrame:GetRight()
    local scrollTop, scrollBottom = scrollFrame:GetTop(), scrollFrame:GetBottom()
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

HideSecureCastButtons = function()
    if InCombatLockdown and InCombatLockdown() then return end
    for index = 1, #secureCastPool do DeactivateSecureCastButton(secureCastPool[index]) end
end

local function SyncSecureCastButtons()
    secureCastSyncQueued = false
    if InCombatLockdown and InCombatLockdown() then return end
    for index = 1, math.max(#iconPool, #secureCastPool) do
        local owner = iconPool[index]
        local data = owner and owner.data
        if data and data.castSpellID and data.castSpellName and PositionSecureCastButton(AcquireSecureCastButton(index), owner) then
            local button = secureCastPool[index]
            if UnregisterStateDriver then pcall(UnregisterStateDriver, button, "visibility") end
            button.data = data
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", data.castSpellName)
            button:SetAttribute("unit", data.castUnit or "player")
            local registered = RegisterStateDriver
                and pcall(RegisterStateDriver, button, "visibility", "[combat] hide; show")
            if not registered then button:Show() end
        elseif secureCastPool[index] then
            DeactivateSecureCastButton(secureCastPool[index])
        end
    end
end

QueueSecureCastSync = function()
    if secureCastSyncQueued or (InCombatLockdown and InCombatLockdown()) then return end
    secureCastSyncQueued = true
    C_Timer.After(0, SyncSecureCastButtons)
end

local function AcquireIcon(index)
    local button = iconPool[index]
    if button then return button end
    button = CreateFrame("Button", nil, content, "BackdropTemplate")
    button:SetSize(31, 31)
    button:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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

local function TextFontPath()
    local choice = ns.Get("textFont")
    if choice == nil or choice == "" or choice == "__global" then
        return (EUI.GetFontPath and EUI.GetFontPath()) or STANDARD_TEXT_FONT
    end
    if EUI.ResolveFontName then
        local ok, path = pcall(EUI.ResolveFontName, choice)
        if ok and path then return path end
    end
    return (EUI.GetFontPath and EUI.GetFontPath()) or STANDARD_TEXT_FONT
end

local function TextFontFlags()
    local outline = ns.Get("textOutline")
    if outline == "OUTLINE" or outline == "THICKOUTLINE" then return outline end
    return ""
end

local function StyleFontString(fontString, sizeKey, fallbackSize, colorKey)
    if not fontString then return end
    local size = Clamp(ns.Get(sizeKey), 8, 24, fallbackSize)
    local path, flags = TextFontPath(), TextFontFlags()
    if EUI.SetFontFamily then
        pcall(EUI.SetFontFamily, fontString, path, size, flags, flags == "")
    else
        pcall(fontString.SetFont, fontString, path, size, flags)
    end
    if colorKey then fontString:SetTextColor(ColorValue(colorKey)) end
end

local function ApplyTextAppearance()
    StyleFontString(title, "titleFontSize", 13)
    StyleFontString(collapseButton.text, "titleFontSize", 13)
    StyleFontString(contextText, "contextFontSize", 11, "contextTextColor")
    for i = 1, #iconPool do
        StyleFontString(iconPool[i].badge, "badgeFontSize", 10, "badgeTextColor")
    end
    for i = 1, #sectionPool do
        local section = sectionPool[i]
        StyleFontString(section.text, "sectionFontSize", 11, "sectionTextColor")
        SetSurfaceBackground(section, section:IsMouseOver() and "sectionHoverBackgroundColor" or "sectionBackgroundColor")
    end
    for i = 1, #rowPool do
        local row = rowPool[i]
        StyleFontString(row.label, "entryLabelFontSize", 12, "entryLabelTextColor")
        StyleFontString(row.detail, "entryDetailFontSize", 10, "entryDetailTextColor")
        SetSurfaceBackground(row, row:IsMouseOver() and "entryHoverBackgroundColor" or "entryBackgroundColor")
    end
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
    if QueueSecureCastSync then QueueSecureCastSync() end
end

scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    SetScroll(self:GetVerticalScroll() - delta * 40)
end)

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

local function MaximumPanelHeight()
    local scale = math.max(0.01, frame:GetScale() or 1)
    local screenHeight = UIParent and UIParent:GetHeight() or 768
    return math.max(180, math.floor((screenHeight * 0.75) / scale))
end

local function CollapsedHeight()
    local height = TitleBarHeight()
    return height > 0 and height + 2 or math.max(28, PanePadding() * 2 + 12)
end

local function TitleControlColor()
    local mode = ns.Get("titleTextColorMode")
    if mode == "class" and EUI.GetPlayerClassColor then
        local ok, r, g, b = pcall(EUI.GetPlayerClassColor)
        if ok and r and g and b then return r, g, b, 1 end
    elseif mode == "accent" and EUI.GetAccentColor then
        local ok, r, g, b = pcall(EUI.GetAccentColor)
        if ok and r and g and b then return r, g, b, 1 end
    end
    return ColorValue("titleTextColor")
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

    scrollFrame:ClearAllPoints()
    local padding = PanePadding()
    local topInset = headerHeight + padding
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -topInset)
    scrollFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padding, -topInset)
    if mode == "hidden" then
        collapseButton:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, math.min(4, padding))
    end
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT")
    contextText:ClearAllPoints()
    contextText:SetPoint("TOPLEFT", content, "TOPLEFT", 2, 0)
    contextText:SetPoint("TOPRIGHT", content, "TOPRIGHT", mode == "hidden" and -28 or -2, 0)
    UpdateLockIcon()
    UpdateLockFade()
end

HasUnlockAnchor = function()
    local db = _G.EllesmereUIDB
    local info = db and db.unlockAnchors and db.unlockAnchors[UNLOCK_KEY]
    return info and info.target and true or false
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
end

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.Set("position", { point = point, relativePoint = relativePoint, x = x, y = y }, true)
end

local function BeginTrackerDrag(surface)
    if ns.Get("locked") or HasUnlockAnchor() then return end
    if HideSecureCastButtons then HideSecureCastButtons() end
    surface._trackerDragged = true
    GameTooltip_Hide()
    frame:StartMoving()
end

local function EndTrackerDrag(surface)
    if not surface._trackerDragged then return end
    frame:StopMovingOrSizing()
    SavePosition()
    if QueueSecureCastSync then QueueSecureCastSync() end
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
RegisterDragSurface(scrollFrame)
RegisterDragSurface(content)

collapseButton:SetScript("OnClick", function()
    ns.Set("collapsed", not ns.Get("collapsed"))
end)
collapseButton:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    UpdateLockFade()
    ShowTooltip(self, { label = ns.Get("collapsed") and "Expand" or "Collapse", detail = "Show or hide the tracker contents." })
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

local function Render()
    if HideSecureCastButtons then HideSecureCastButtons() end
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
    local collapsed = ns.Get("collapsed") == true
    collapseButton.text:SetText(collapsed and "+" or "−")
    SetAttention(collapseButton, collapsed and SnapshotAttention(snapshot) or nil, 1)
    scrollFrame:SetShown(not collapsed)
    if collapsed then
        frame:SetHeight(CollapsedHeight())
        UpdateLockFade()
        return
    end

    local y = 0
    if ns.Get("showContext") then
        local zone = ns.GetZoneName()
        local role = ns.ROLE_LABELS[ns.GetRole()] or ns.GetRole()
        local className = UnitClass and UnitClass("player") or "Character"
        local specName
        if GetSpecialization and GetSpecializationInfo then
            local specialization = GetSpecialization()
            if specialization then
                local ok, _, name = pcall(GetSpecializationInfo, specialization)
                if ok and type(name) == "string" and name ~= "" then specName = name end
            end
        end
        local build = specName and (specName .. " " .. className) or className
        contextText:SetText(zone .. "  •  " .. build .. "  •  " .. role)
        contextText:Show()
        y = y - math.max(19, Clamp(ns.Get("contextFontSize"), 8, 24, 11) + 8)
    else
        contextText:Hide()
    end

    local iconCount = #snapshot.statuses
    if iconCount > 0 then
        local size, spacing = 31, 6
        local total = iconCount * size + (iconCount - 1) * spacing
        local startX = math.max(0, (contentWidth - total) / 2)
        for i = 1, iconCount do
            local data = snapshot.statuses[i]
            local button = AcquireIcon(i)
            button.data = data
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", content, "TOPLEFT", startX + (i - 1) * (size + spacing), y)
            button.icon:SetTexture(data.icon or 134400)
            button.badge:SetText(data.badge or "")
            button:SetBackdropBorderColor(StateColor(data.state))
            SetAttention(button, data.attention, 2)
            button:Show()
        end
        y = y - 40
    end

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
                    local labelSize = Clamp(ns.Get("entryLabelFontSize"), 8, 24, 12)
                    local detailSize = Clamp(ns.Get("entryDetailFontSize"), 8, 24, 10)
                    local rowHeight = math.max(37, labelSize + detailSize + 12)
                    row.data = data
                    row:ClearAllPoints()
                    row:SetHeight(rowHeight)
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                    row.icon:SetTexture(data.icon or 134400)
                    row.label:ClearAllPoints()
                    row.label:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 7, -2)
                    row.label:SetSize(math.max(1, contentWidth - 45), labelSize + 3)
                    row.detail:ClearAllPoints()
                    row.detail:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
                    row.detail:SetSize(math.max(1, contentWidth - 45), detailSize + 3)
                    row.label:SetText(data.label or "")
                    row.detail:SetText(data.detail or "")
                    row.stripe:SetColorTexture(StateColor(data.state))
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
    local viewportHeight = math.min(contentHeight, math.max(12, MaximumPanelHeight() - ChromeHeight()))
    scrollFrame:SetHeight(viewportHeight)
    frame:SetHeight(ChromeHeight() + viewportHeight)
    SetScroll(scrollFrame:GetVerticalScroll())
    if QueueSecureCastSync then QueueSecureCastSync() end
    UpdateLockFade()
end

function ns.ApplySettings()
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
            if ns.Get("titleTextColorMode") == "accent" then ApplyWindowStyle() end
        end,
    })
end
if hooksecurefunc and type(EUI.ApplyColorsToOUF) == "function" then
    pcall(hooksecurefunc, EUI, "ApplyColorsToOUF", function()
        if ns.Get("titleTextColorMode") == "class" then ApplyWindowStyle() end
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
            if QueueSecureCastSync then QueueSecureCastSync() end
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
            if QueueSecureCastSync then QueueSecureCastSync() end
        end,
        applyPos = function()
            SetPosition()
            if QueueSecureCastSync then QueueSecureCastSync() end
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
    "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED",
    "CHAT_MSG_SKILL", "UNIT_INVENTORY_CHANGED", "UNIT_CONNECTION", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "ITEM_DATA_LOAD_RESULT", "SPELL_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED",
    "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED",
    "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "ACHIEVEMENT_EARNED",
}
for i = 1, #eventNames do pcall(events.RegisterEvent, events, eventNames[i]) end
pcall(events.RegisterEvent, events, "UNIT_AURA")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit and unit ~= "player" and not tostring(unit):match("^party%d+$") then return end
    end
    if (event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE") and ns.ScanProfessionRecipes then
        ns.ScanProfessionRecipes()
    end
    if event == "PLAYER_REGEN_ENABLED" and HideSecureCastButtons then HideSecureCastButtons() end
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
