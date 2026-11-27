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
header:RegisterForDrag("LeftButton")

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", 9, 0)
title:SetText("Adventure Tracker")

-- Quest Tracker style: an unboxed +/- glyph in the title bar.
local collapseButton = CreateFrame("Button", nil, header)
collapseButton:SetSize(22, 20)
collapseButton:SetPoint("RIGHT", -7, 0)
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

local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", 8, -34)
content:SetPoint("TOPRIGHT", -8, -34)

local contextText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
contextText:SetPoint("TOPLEFT", 2, 0)
contextText:SetPoint("TOPRIGHT", -2, 0)
contextText:SetJustifyH("LEFT")
contextText:SetTextColor(0.67, 0.72, 0.75)

local iconPool, sectionPool, rowPool = {}, {}, {}
local skin
local UpdateLockFade

local function StateColor(state)
    local color = COLORS[state] or COLORS.info
    return color[1], color[2], color[3]
end

local function ShowTooltip(owner, data)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(data.label or "Adventure Tracker")
    local detail = data.tooltip or data.detail
    if detail and detail ~= "" then GameTooltip:AddLine(detail, 1, 1, 1, true) end
    if data.onClick then GameTooltip:AddLine("Click to open.", 0.55, 0.82, 1) end
    GameTooltip:Show()
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
    button:SetScript("OnClick", function(self) if self.data and self.data.onClick then self.data.onClick() end end)
    iconPool[index] = button
    if skin then skin.SquareIcon(button.icon) end
    return button
end

local function AcquireSection(index)
    local fs = sectionPool[index]
    if fs then return fs end
    fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.18, 0.82, 0.66)
    sectionPool[index] = fs
    if skin then skin.Font(fs) end
    return fs
end

local function AcquireRow(index)
    local row = rowPool[index]
    if row then return row end
    row = CreateFrame("Button", nil, content, "BackdropTemplate")
    row:SetHeight(37)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(1, 1, 1, 0.025)
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
        self:SetBackdropColor(1, 1, 1, 0.07)
        if self.data then ShowTooltip(self, self.data) end
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(1, 1, 1, 0.025)
        GameTooltip_Hide()
        if UpdateLockFade then C_Timer.After(0, UpdateLockFade) end
    end)
    row:SetScript("OnClick", function(self) if self.data and self.data.onClick then self.data.onClick() end end)
    rowPool[index] = row
    if skin then
        skin.Font(row.label)
        skin.Font(row.detail)
        skin.SquareIcon(row.icon)
    end
    return row
end

local function HidePools()
    for i = 1, #iconPool do iconPool[i]:Hide() end
    for i = 1, #sectionPool do sectionPool[i]:Hide() end
    for i = 1, #rowPool do rowPool[i]:Hide() end
end

local function Clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback
    return math.max(minimum, math.min(maximum, value))
end

local function ColorValue(key)
    local value = ns.Get(key)
    local fallback = ns.DEFAULTS[key] or {}
    if type(value) ~= "table" then value = fallback end
    return value.r or fallback.r or 1, value.g or fallback.g or 1,
        value.b or fallback.b or 1, value.a == nil and (fallback.a or 1) or value.a
end

local function TitleBarMode()
    local mode = ns.Get("titleBarMode")
    if mode ~= "filled" and mode ~= "transparent" and mode ~= "hidden" then return "filled" end
    return mode
end

local function TitleBarHeight()
    if TitleBarMode() == "hidden" then return 0 end
    return Clamp(ns.Get("titleBarHeight"), 20, 40, 28)
end

local function ChromeHeight()
    local height = TitleBarHeight()
    return height > 0 and height + 10 or 12
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
    frame:SetBackdropColor(r, g, b, a)

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

    local tr, tg, tb, ta = ColorValue("titleTextColor")
    local titleSize = Clamp(ns.Get("titleFontSize"), 9, 20, 13)
    local titleFont, _, titleFlags = title:GetFont()
    local collapseFont, _, collapseFlags = collapseButton.text:GetFont()
    if titleFont then pcall(title.SetFont, title, titleFont, titleSize, titleFlags) end
    if collapseFont then pcall(collapseButton.text.SetFont, collapseButton.text, collapseFont, titleSize, collapseFlags) end
    title:SetTextColor(tr, tg, tb, ta)
    collapseButton.text:SetTextColor(tr, tg, tb, ta)
    title:SetShown(mode ~= "hidden" and ns.Get("showTitleText") == true)
    collapseButton:SetShown(mode ~= "hidden")

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

    content:ClearAllPoints()
    local topInset = headerHeight > 0 and headerHeight + 6 or 8
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -topInset)
    content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -topInset)
    UpdateLockIcon()
    UpdateLockFade()
end

local function HasUnlockAnchor()
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

header:SetScript("OnDragStart", function()
    if not ns.Get("locked") and not HasUnlockAnchor() then frame:StartMoving() end
end)
header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition()
end)

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
    if ns.Get("hideInCombat") and InCombatLockdown and InCombatLockdown() then return false end
    if ns.Get("hideInInstances") then
        local inInstance = IsInInstance and IsInInstance()
        if inInstance then return false end
    end
    return true
end

local function Render()
    HidePools()
    if not BaseVisibilityAllows() then frame:Hide(); return end
    local snapshot = ns.BuildSnapshot()
    if ns.Get("hideWhenReady") and not snapshot.actionable then frame:Hide(); return end
    frame:Show()

    local width = math.max(280, math.min(480, tonumber(ns.Get("width")) or 340))
    frame:SetWidth(width)
    local collapsed = ns.Get("collapsed") == true and TitleBarMode() ~= "hidden"
    collapseButton.text:SetText(collapsed and "+" or "−")
    content:SetShown(not collapsed)
    if collapsed then
        frame:SetHeight(TitleBarHeight() + 2)
        UpdateLockFade()
        return
    end

    local y = 0
    if ns.Get("showContext") then
        local zone = ns.GetZoneName()
        local role = ns.ROLE_LABELS[ns.GetRole()] or ns.GetRole()
        contextText:SetText(zone .. "  •  " .. role)
        contextText:Show()
        y = y - 19
    else
        contextText:Hide()
    end

    local iconCount = #snapshot.statuses
    if iconCount > 0 then
        local size, spacing = 31, 6
        local total = iconCount * size + (iconCount - 1) * spacing
        local startX = math.max(0, (width - 16 - total) / 2)
        for i = 1, iconCount do
            local data = snapshot.statuses[i]
            local button = AcquireIcon(i)
            button.data = data
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", content, "TOPLEFT", startX + (i - 1) * (size + spacing), y)
            button.icon:SetTexture(data.icon or 134400)
            button.badge:SetText(data.badge or "")
            button:SetBackdropBorderColor(StateColor(data.state))
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
            heading:ClearAllPoints()
            heading:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
            heading:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, y)
            heading:SetText(string.upper(section.title or section.id))
            heading:Show()
            y = y - 18
            for j = 1, #rows do
                rowIndex = rowIndex + 1
                local data = rows[j]
                local row = AcquireRow(rowIndex)
                row.data = data
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                row.icon:SetTexture(data.icon or 134400)
                row.label:SetText(data.label or "")
                row.detail:SetText(data.detail or "")
                row.stripe:SetColorTexture(StateColor(data.state))
                row:EnableMouse(true)
                row:Show()
                y = y - 40
            end
            y = y - 4
        end
    end

    local contentHeight = math.max(12, math.abs(y))
    content:SetHeight(contentHeight)
    frame:SetHeight(ChromeHeight() + contentHeight)
    UpdateLockFade()
end

function ns.ApplySettings()
    frame:SetScale(math.max(0.65, math.min(1.5, tonumber(ns.Get("scale")) or 1)))
    frame:SetAlpha(math.max(0.25, math.min(1, tonumber(ns.Get("opacity")) or 1)))
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
        end,
        applyPos = SetPosition,
    }) }, ADDON_NAME)
    unlockRegistered = true
    return true
end
RegisterUnlockElement()

local events = CreateFrame("Frame")
local eventNames = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED",
    "CHAT_MSG_SKILL", "UNIT_INVENTORY_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "ITEM_DATA_LOAD_RESULT", "SPELL_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED",
    "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED",
    "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "ACHIEVEMENT_EARNED",
}
for i = 1, #eventNames do pcall(events.RegisterEvent, events, eventNames[i]) end
pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit and unit ~= "player" then return end
    end
    if (event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE") and ns.ScanProfessionRecipes then
        ns.ScanProfessionRecipes()
    end
    if (event == "TRAINER_SHOW" or event == "TRAINER_UPDATE") and ns.ScanClassTrainer then
        ns.ScanClassTrainer()
        if event == "TRAINER_SHOW" then
            C_Timer.After(0, function()
                if ns.ScanClassTrainer and ns.ScanClassTrainer() then ns.RequestRefresh() end
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
        for i = 1, #sectionPool do S.Font(sectionPool[i]) end
        for i = 1, #rowPool do
            S.Font(rowPool[i].label)
            S.Font(rowPool[i].detail)
            S.SquareIcon(rowPool[i].icon)
        end
        ApplyWindowStyle()
    end)
end
