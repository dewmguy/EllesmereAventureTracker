-------------------------------------------------------------------------------
-- Adventure Tracker quest review tools
-- Persistent per-character hiding, categorized issue reports and copy exports.
-------------------------------------------------------------------------------
local _, ns = ...

local WOWHEAD_QUEST_URL = "https://www.wowhead.com/quest=%d"
local CONFIRM_DIALOG = "EUI_ADVENTURE_TRACKER_QUEST_CONFIRM"
local NOTE_DIALOG = "EUI_ADVENTURE_TRACKER_QUEST_NOTE"
local hiddenRevision = 0
local copyFrame

local REPORT_REASONS = {
    { key = "chain", label = "Has a prerequisite or is a later chain step" },
    { key = "level", label = "Minimum level or level eligibility is wrong" },
    { key = "unavailable", label = "Unavailable, removed, test or bugged quest" },
    { key = "restriction", label = "Wrong faction, class or profession restriction" },
    { key = "starter", label = "Quest giver, object or starting item is wrong" },
    { key = "duplicate_starter", label = "Duplicate quest giver" },
    { key = "zone", label = "Listed under the wrong zone" },
    { key = "status", label = "Repeatable, completed or already accepted" },
    { key = "reward", label = "XP or coin reward is wrong" },
    { key = "other", label = "Other quest-data problem" },
}

local function CopyTable(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do copy[key] = value end
    end
    return copy
end

local function Chat(message)
    message = "|cff0cd29fAdventure Tracker:|r " .. tostring(message or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    else
        print(message)
    end
end

local function AddOnVersion(addonName)
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if type(getter) ~= "function" then return "unknown" end
    local ok, value = pcall(getter, addonName, "Version")
    return ok and value and tostring(value) or "unknown"
end

local function Confirm(message, accept)
    if type(StaticPopup_Show) ~= "function" or type(StaticPopupDialogs) ~= "table" then return false end
    if not StaticPopupDialogs[CONFIRM_DIALOG] then
        StaticPopupDialogs[CONFIRM_DIALOG] = {
            text = "%s",
            button1 = _G.YES or "Confirm",
            button2 = _G.CANCEL or "Cancel",
            OnAccept = function(self, data)
                data = data or self.data
                if type(data) == "table" and type(data.accept) == "function" then data.accept() end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    local popup = StaticPopup_Show(CONFIRM_DIALOG, message, nil, { accept = accept })
    return popup ~= nil
end

local function CharacterHiddenTable()
    local source = ns.Get("hiddenZoneQuestsByCharacter")
    local character = type(source) == "table" and source[ns.CharacterKey()]
    return type(character) == "table" and character or nil
end

function ns.IsQuestHidden(questID)
    local hidden = CharacterHiddenTable()
    return hidden and hidden[tostring(tonumber(questID) or questID)] ~= nil or false
end

function ns.GetHiddenQuestRevision()
    return hiddenRevision
end

function ns.GetHiddenQuestCount()
    local count, hidden = 0, CharacterHiddenTable()
    if type(hidden) == "table" then
        for _ in pairs(hidden) do count = count + 1 end
    end
    return count
end

local function RefreshHiddenQuests(reason)
    hiddenRevision = hiddenRevision + 1
    if ns.InvalidateInstanceQuestRows then ns.InvalidateInstanceQuestRows() end
    if ns.RequestRefresh then
        ns.RequestRefresh({ "zone-quests", "instances" }, reason or "hidden quests changed")
    end
end

local function HideQuest(context)
    local questID = tonumber(context and context.id)
    if not questID then return end
    local source = ns.Get("hiddenZoneQuestsByCharacter")
    local outer = CopyTable(source)
    local characterKey = ns.CharacterKey()
    local hidden = CopyTable(type(source) == "table" and source[characterKey])
    hidden[tostring(questID)] = {
        name = tostring(context.name or ("Quest " .. questID)),
        hiddenAt = type(time) == "function" and time() or 0,
    }
    outer[characterKey] = hidden
    ns.Set("hiddenZoneQuestsByCharacter", outer, true)
    RefreshHiddenQuests("quest hidden")
    Chat(string.format("hidden %s for this character. Restore hidden quests from the Quest Progress settings.",
        context.name or ("quest " .. questID)))
end

function ns.ConfirmHideQuest(context)
    if type(context) ~= "table" or not tonumber(context.id) then return end
    local name = tostring(context.name or ("Quest " .. tostring(context.id)))
    if not Confirm(string.format("Hide %s from Adventure Tracker for this character?", name), function()
        HideQuest(context)
    end) then
        Chat("could not open the confirmation dialog; the quest was not hidden.")
    end
end

function ns.ConfirmRestoreHiddenQuests()
    local count = ns.GetHiddenQuestCount()
    if count == 0 then
        Chat("this character has no hidden quests.")
        return
    end
    Confirm(string.format("Restore all %d hidden quest%s for this character?", count, count == 1 and "" or "s"), function()
        local source = ns.Get("hiddenZoneQuestsByCharacter")
        local outer = CopyTable(source)
        outer[ns.CharacterKey()] = nil
        ns.Set("hiddenZoneQuestsByCharacter", outer, true)
        RefreshHiddenQuests("hidden quests restored")
        Chat(string.format("restored %d hidden quest%s.", count, count == 1 and "" or "s"))
    end)
end

local function ReportTable()
    local reports = ns.Get("questIssueReports")
    return type(reports) == "table" and reports or {}
end

function ns.GetQuestReportCount()
    local count = 0
    for _ in pairs(ReportTable()) do count = count + 1 end
    return count
end

local function PlayerObservation(context)
    local className, classToken
    if UnitClass then className, classToken = UnitClass("player") end
    local characterName, realm
    if UnitFullName then characterName, realm = UnitFullName("player") end
    if not characterName and UnitName then characterName = UnitName("player") end
    realm = realm or (GetRealmName and GetRealmName())
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return {
        character = tostring(characterName or "Unknown") .. (realm and ("-" .. tostring(realm)) or ""),
        playerLevel = UnitLevel and UnitLevel("player") or 0,
        className = className,
        classToken = classToken,
        specialization = ns.GetCurrentSpecializationName and ns.GetCurrentSpecializationName() or nil,
        faction = faction,
        zoneName = context.zoneName,
        areaID = tonumber(context.areaID),
        questLevel = tonumber(context.questLevel),
        requiredLevel = tonumber(context.requiredLevel),
        source = context.source,
        observedAt = type(time) == "function" and time() or 0,
    }
end

local function QueueReport(context, reason, note)
    local questID = tonumber(context and context.id)
    if not questID or type(reason) ~= "table" then return end
    local source = ReportTable()
    local reports = CopyTable(source)
    local key = tostring(questID)
    local record = CopyTable(source[key])
    record.id = questID
    record.name = tostring(context.name or record.name or ("Quest " .. questID))
    record.reasons = CopyTable(record.reasons)
    record.reasons[reason.key] = true
    record.observations = CopyTable(record.observations)
    record.observations[ns.CharacterKey()] = PlayerObservation(context)
    local now = type(time) == "function" and time() or 0
    note = type(note) == "string" and note:match("^%s*(.-)%s*$") or nil
    if note and note ~= "" then
        record.notes = CopyTable(record.notes)
        record.notes[#record.notes + 1] = {
            text = note,
            character = ns.CharacterKey(),
            addedAt = now,
        }
    end
    record.firstReportedAt = tonumber(record.firstReportedAt) or now
    record.lastReportedAt = now
    reports[key] = record
    ns.Set("questIssueReports", reports, true)
    Chat(string.format("queued quest %d (%s): %s. Use /at questreports to copy the batch.",
        questID, record.name, reason.label))
end

local function PromptOtherReport(context, reason)
    if type(StaticPopup_Show) ~= "function" or type(StaticPopupDialogs) ~= "table" then
        QueueReport(context, reason)
        return
    end
    if not StaticPopupDialogs[NOTE_DIALOG] then
        StaticPopupDialogs[NOTE_DIALOG] = {
            text = "Add a short note for %s:",
            button1 = "Queue Report",
            button2 = _G.CANCEL or "Cancel",
            hasEditBox = true,
            wide = true,
            maxLetters = 300,
            OnShow = function(self)
                self.editBox:SetText("")
                self.editBox:SetFocus()
            end,
            OnAccept = function(self, data)
                data = data or self.data
                if type(data) == "table" then
                    QueueReport(data.context, data.reason, self.editBox:GetText())
                end
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                if parent and parent.button1 then parent.button1:Click() end
            end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show(NOTE_DIALOG, tostring(context.name or ("Quest " .. tostring(context.id))), nil,
        { context = context, reason = reason })
end

local function ClearQuestReport(questID, name)
    questID = tonumber(questID)
    if not questID then return end
    Confirm(string.format("Remove the queued report for %s?", tostring(name or ("quest " .. questID))), function()
        local source = ReportTable()
        local reports = CopyTable(source)
        reports[tostring(questID)] = nil
        ns.Set("questIssueReports", reports, true)
        Chat(string.format("removed the queued report for quest %d.", questID))
    end)
end

function ns.ConfirmClearQuestReports()
    local count = ns.GetQuestReportCount()
    if count == 0 then
        Chat("there are no queued quest reports.")
        return
    end
    Confirm(string.format("Permanently clear all %d queued quest report%s?", count, count == 1 and "" or "s"), function()
        ns.Set("questIssueReports", {}, true)
        if copyFrame then copyFrame:Hide() end
        Chat(string.format("cleared %d quest report%s.", count, count == 1 and "" or "s"))
    end)
end

local function Timestamp(value)
    value = tonumber(value)
    if not value or value <= 0 or type(date) ~= "function" then return "unknown" end
    return date("%Y-%m-%d %H:%M:%S", value)
end

local function ReasonLabels(record)
    local labels, known = {}, {}
    local reasons = type(record.reasons) == "table" and record.reasons or {}
    for index = 1, #REPORT_REASONS do
        local reason = REPORT_REASONS[index]
        known[reason.key] = true
        if reasons[reason.key] then labels[#labels + 1] = reason.label end
    end
    for key, enabled in pairs(reasons) do
        if enabled and not known[key] then labels[#labels + 1] = tostring(key) end
    end
    return #labels > 0 and table.concat(labels, "; ") or "Unspecified"
end

local function CharacterDescription(observation)
    local parts = {}
    if tonumber(observation.playerLevel) and tonumber(observation.playerLevel) > 0 then
        parts[#parts + 1] = "level " .. tostring(observation.playerLevel)
    end
    local class = observation.className or observation.classToken
    if observation.specialization and class then
        parts[#parts + 1] = tostring(observation.specialization) .. " " .. tostring(class)
    elseif class then
        parts[#parts + 1] = tostring(class)
    end
    if observation.faction then parts[#parts + 1] = tostring(observation.faction) end
    return #parts > 0 and table.concat(parts, " ") or "unknown character context"
end

local function BuildReportExport()
    local reports = ReportTable()
    local ids = {}
    for key, record in pairs(reports) do
        ids[#ids + 1] = type(record) == "table" and (tonumber(record.id) or tonumber(key) or key)
            or (tonumber(key) or key)
    end
    table.sort(ids, function(a, b)
        local numberA, numberB = tonumber(a), tonumber(b)
        if numberA and numberB then return numberA < numberB end
        return tostring(a) < tostring(b)
    end)
    local lines = {
        "Adventure Tracker quest issue batch",
        "Generated: " .. Timestamp(type(time) == "function" and time() or 0),
        "Adventure Tracker: " .. AddOnVersion(ns.ADDON_NAME),
        "QuestieDB: " .. AddOnVersion("QuestieDB"),
        "Reports: " .. tostring(#ids),
        "",
    }
    if #ids == 0 then
        lines[#lines + 1] = "No queued quest reports."
        return table.concat(lines, "\n")
    end
    for index = 1, #ids do
        local id = ids[index]
        local record = reports[tostring(id)] or reports[id]
        if type(record) ~= "table" then record = { id = id, name = "Unknown quest" } end
        lines[#lines + 1] = string.format("%d. Quest %s — %s", index, tostring(record.id or id),
            tostring(record.name or "Unknown quest"))
        lines[#lines + 1] = "   Wowhead: " .. string.format(WOWHEAD_QUEST_URL, tonumber(record.id or id) or 0)
        lines[#lines + 1] = "   Problem(s): " .. ReasonLabels(record)
        if type(record.notes) == "table" then
            for noteIndex = 1, #record.notes do
                local note = record.notes[noteIndex]
                if type(note) == "table" and note.text then
                    lines[#lines + 1] = string.format("   Note: %s (%s)", tostring(note.text), Timestamp(note.addedAt))
                end
            end
        end
        local observations = type(record.observations) == "table" and record.observations or {}
        local characterKeys = {}
        for key in pairs(observations) do characterKeys[#characterKeys + 1] = key end
        table.sort(characterKeys)
        for observationIndex = 1, #characterKeys do
            local observation = observations[characterKeys[observationIndex]]
            local zone = tostring(observation.zoneName or "unknown zone")
            if observation.areaID then zone = zone .. " (area " .. tostring(observation.areaID) .. ")" end
            lines[#lines + 1] = string.format("   Seen by %s: %s in %s", tostring(observation.character or characterKeys[observationIndex]),
                CharacterDescription(observation), zone)
            local metadata = {}
            if observation.requiredLevel then metadata[#metadata + 1] = "minimum level " .. tostring(observation.requiredLevel) end
            if observation.questLevel then metadata[#metadata + 1] = "displayed level " .. tostring(observation.questLevel) end
            if #metadata > 0 then lines[#lines + 1] = "   Recorded data: " .. table.concat(metadata, "; ") end
            if observation.source then lines[#lines + 1] = "   Recorded starter: " .. tostring(observation.source) end
            lines[#lines + 1] = "   Observed: " .. Timestamp(observation.observedAt)
        end
        lines[#lines + 1] = "   First reported: " .. Timestamp(record.firstReportedAt)
        lines[#lines + 1] = ""
    end
    return table.concat(lines, "\n")
end

local function CreateCopyFrame()
    if copyFrame then return copyFrame end
    local frame = CreateFrame("Frame", "EUIAdventureTrackerCopyFrame", UIParent, "BackdropTemplate")
    frame:SetSize(650, 430)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.025, 0.032, 0.04, 0.98)
    frame:SetBackdropBorderColor(0.12, 0.78, 0.62, 1)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 14, -13)
    frame.instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.instructions:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
    frame.instructions:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    frame.instructions:SetJustifyH("LEFT")

    frame.close = CreateFrame("Button", nil, frame)
    frame.close:SetSize(28, 28)
    frame.close:SetPoint("TOPRIGHT", -6, -6)
    frame.close.text = frame.close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.close.text:SetPoint("CENTER")
    frame.close.text:SetText("×")
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 14, -72)
    frame.scroll:SetPoint("BOTTOMRIGHT", -34, 48)
    frame.edit = CreateFrame("EditBox", nil, frame.scroll)
    frame.edit:SetMultiLine(true)
    frame.edit:SetAutoFocus(false)
    frame.edit:SetFontObject(ChatFontNormal)
    frame.edit:SetTextColor(0.92, 0.94, 0.96)
    frame.edit:SetWidth(590)
    frame.edit:SetPoint("TOPLEFT")
    frame.edit:SetTextInsets(5, 5, 5, 5)
    frame.edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    frame.scroll:SetScrollChild(frame.edit)

    frame.select = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.select:SetSize(110, 24)
    frame.select:SetPoint("BOTTOMLEFT", 14, 14)
    frame.select:SetText("Select All")
    frame.select:SetScript("OnClick", function()
        frame.edit:SetFocus()
        frame.edit:HighlightText()
    end)

    frame.clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clear:SetSize(130, 24)
    frame.clear:SetPoint("LEFT", frame.select, "RIGHT", 8, 0)
    frame.clear:SetText("Clear Reports")
    frame.clear:SetScript("OnClick", function()
        frame:Hide()
        ns.ConfirmClearQuestReports()
    end)

    frame.done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.done:SetSize(90, 24)
    frame.done:SetPoint("BOTTOMRIGHT", -14, 14)
    frame.done:SetText("Close")
    frame.done:SetScript("OnClick", function() frame:Hide() end)

    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = frame:GetName() end
    copyFrame = frame
    return frame
end

local function ShowCopyText(title, instructions, value, showClear, compact)
    local frame = CreateCopyFrame()
    frame.title:SetText(title)
    frame.instructions:SetText(instructions)
    frame.clear:SetShown(showClear == true)
    frame.scroll:ClearAllPoints()
    if compact then
        frame:SetSize(500, 148)
        frame.scroll:SetPoint("TOPLEFT", 14, -68)
        frame.scroll:SetPoint("BOTTOMRIGHT", -34, 48)
        frame.edit:SetMultiLine(false)
        frame.edit:SetWidth(430)
        frame.edit:SetHeight(28)
        frame.select:SetText("Select URL")
    else
        frame:SetSize(650, 430)
        frame.scroll:SetPoint("TOPLEFT", 14, -72)
        frame.scroll:SetPoint("BOTTOMRIGHT", -34, 48)
        frame.edit:SetMultiLine(true)
        frame.edit:SetWidth(590)
        frame.select:SetText("Select All")
    end
    value = tostring(value or "")
    local _, breaks = value:gsub("\n", "\n")
    if not compact then
        frame.edit:SetHeight(math.max(290, (breaks + 3) * 15))
    end
    frame.edit:SetText(value)
    frame:Show()
    frame:Raise()
    frame.edit:SetFocus()
    frame.edit:HighlightText()
end

function ns.ShowQuestReportExport()
    ShowCopyText("Quest Issue Reports",
        "The batch is selected. Press Ctrl+C, then paste it into a message when you want the reports investigated.",
        BuildReportExport(), true, false)
end

function ns.ShowQuestWowheadURL(questID)
    questID = tonumber(questID)
    if not questID then return end
    ShowCopyText("Wowhead Quest Link", "The URL is selected. Press Ctrl+C to copy it.",
        string.format(WOWHEAD_QUEST_URL, questID), false, true)
end

function ns.ShowQuestContextMenu(owner, context)
    if type(context) ~= "table" or not tonumber(context.id) then return end
    if type(ns.ShowContextMenu) ~= "function" then
        Chat("the quest menu is not available yet.")
        return
    end
    local reports = ReportTable()
    local record = reports[tostring(context.id)]
    local recordedReasons = type(record) == "table" and type(record.reasons) == "table" and record.reasons or {}
    local entries = {
        { text = "Copy Wowhead URL", action = function() ns.ShowQuestWowheadURL(context.id) end },
        { text = "Hide this quest…", action = function() ns.ConfirmHideQuest(context) end, color = { 1, 0.72, 0.30 } },
        { text = "Report a problem", heading = true },
    }
    for index = 1, #REPORT_REASONS do
        local reportReason = REPORT_REASONS[index]
        local queued = recordedReasons[reportReason.key] == true
        entries[#entries + 1] = {
            text = (queued and "[queued] " or "") .. reportReason.label,
            disabled = queued,
            action = queued and nil or function()
                if reportReason.key == "other" then
                    PromptOtherReport(context, reportReason)
                else
                    QueueReport(context, reportReason)
                end
            end,
        }
    end
    if record then
        entries[#entries + 1] = {
            text = "Remove this queued report…",
            action = function() ClearQuestReport(context.id, context.name) end,
            color = { 1, 0.45, 0.40 },
        }
    end
    local count = ns.GetQuestReportCount()
    if count > 0 then
        entries[#entries + 1] = {
            text = string.format("Copy all queued reports (%d)", count),
            action = ns.ShowQuestReportExport,
            color = { 0.30, 0.90, 0.72 },
        }
    end
    ns.ShowContextMenu(owner, string.format("Quest %d: %s", context.id,
        tostring(context.name or "Unknown")), entries)
end
