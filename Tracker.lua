-------------------------------------------------------------------------------
-- Adventure Tracker: floating window and rendering.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EUI = ns.EUI

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
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
frame:SetBackdropColor(0.025, 0.032, 0.04, 0.94)
frame:SetBackdropBorderColor(0.20, 0.24, 0.27, 1)

local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(28)
header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
header:SetBackdropColor(0.04, 0.055, 0.065, 0.98)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", 9, 0)
title:SetText("Adventure Tracker")

local function SmallButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 24, 20)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button:SetBackdropColor(0.08, 0.10, 0.12, 1)
    button:SetBackdropBorderColor(0.25, 0.28, 0.31, 1)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("CENTER", 0, 0)
    button.text:SetText(text)
    return button
end

local collapseButton = SmallButton(header, "−", 22)
collapseButton:SetPoint("RIGHT", -4, 0)

local lockButton = SmallButton(header, "U", 22)
lockButton:SetPoint("RIGHT", collapseButton, "LEFT", -3, 0)

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

local function StateColor(state)
    local color = COLORS[state] or COLORS.info
    return color[1], color[2], color[3]
end

local function ShowTooltip(owner, data)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(data.label or "Adventure Tracker")
    if data.detail and data.detail ~= "" then GameTooltip:AddLine(data.detail, 1, 1, 1, true) end
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
    button:SetScript("OnEnter", function(self) if self.data then ShowTooltip(self, self.data) end end)
    button:SetScript("OnLeave", GameTooltip_Hide)
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
        self:SetBackdropColor(1, 1, 1, 0.07)
        if self.data then ShowTooltip(self, self.data) end
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(1, 1, 1, 0.025)
        GameTooltip_Hide()
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

local function SetPosition()
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
    if not ns.Get("locked") then frame:StartMoving() end
end)
header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition()
end)

collapseButton:SetScript("OnClick", function()
    ns.Set("collapsed", not ns.Get("collapsed"))
end)
collapseButton:SetScript("OnEnter", function(self)
    ShowTooltip(self, { label = ns.Get("collapsed") and "Expand" or "Collapse", detail = "Show or hide the tracker contents." })
end)
collapseButton:SetScript("OnLeave", GameTooltip_Hide)

lockButton:SetScript("OnClick", function()
    ns.Set("locked", not ns.Get("locked"))
    ns.ApplySettings()
end)
lockButton:SetScript("OnEnter", function(self)
    ShowTooltip(self, { label = ns.Get("locked") and "Unlock Window" or "Lock Window", detail = "Unlocked windows can be dragged by the title bar." })
end)
lockButton:SetScript("OnLeave", GameTooltip_Hide)

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
    local collapsed = ns.Get("collapsed") == true
    collapseButton.text:SetText(collapsed and "+" or "−")
    lockButton.text:SetText(ns.Get("locked") and "L" or "U")
    content:SetShown(not collapsed)
    if collapsed then frame:SetHeight(30); return end

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
    frame:SetHeight(38 + contentHeight)
end

function ns.ApplySettings()
    frame:SetScale(math.max(0.65, math.min(1.5, tonumber(ns.Get("scale")) or 1)))
    frame:SetAlpha(math.max(0.25, math.min(1, tonumber(ns.Get("opacity")) or 1)))
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

local events = CreateFrame("Frame")
local eventNames = {
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED",
    "CHAT_MSG_SKILL", "UNIT_INVENTORY_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "ITEM_DATA_LOAD_RESULT", "SPELL_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED",
    "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "ACHIEVEMENT_EARNED",
}
for i = 1, #eventNames do pcall(events.RegisterEvent, events, eventNames[i]) end
pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit and unit ~= "player" then return end
    end
    if event == "PLAYER_LOGIN" then
        ns.ApplySettings()
        C_Timer.NewTicker(10, ns.RequestRefresh)
    else
        ns.RequestRefresh()
    end
end)

if EUI.RegisterSkin then
    EUI.RegisterSkin(ADDON_NAME, function(S)
        skin = S
        S.Shell(frame)
        S.Panel(header, { noBorder = true })
        S.Button(lockButton)
        S.Button(collapseButton)
        S.Font(title)
        S.Font(contextText)
        for i = 1, #iconPool do S.SquareIcon(iconPool[i].icon) end
        for i = 1, #sectionPool do S.Font(sectionPool[i]) end
        for i = 1, #rowPool do
            S.Font(rowPool[i].label)
            S.Font(rowPool[i].detail)
            S.SquareIcon(rowPool[i].icon)
        end
    end)
end
