-- BananaLootExtra.lua
-- Minimap-Button, Optionsfenster (u.a. SR+ Bonus pro Stufe einstellbar)
-- sowie Export/Import-Popups, um die aktuelle SR-Liste an eine
-- Vertretung weiterzugeben.

-- ============================================================
-- 1) OPTIONSFENSTER
-- ============================================================
local optFrame = CreateFrame("Frame", "BananaLootOptionsFrame", UIParent)
optFrame:SetWidth(300)
optFrame:SetHeight(340)
optFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
optFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 11, top = 11, bottom = 11 },
})
optFrame:SetMovable(true)
optFrame:EnableMouse(true)
optFrame:RegisterForDrag("LeftButton")
optFrame:SetScript("OnDragStart", function() optFrame:StartMoving() end)
optFrame:SetScript("OnDragStop", function() optFrame:StopMovingOrSizing() end)
optFrame:SetFrameStrata("DIALOG")
optFrame:Hide()

local optLogo = optFrame:CreateTexture(nil, "ARTWORK")
optLogo:SetWidth(260)
optLogo:SetHeight(68)
optLogo:SetPoint("TOP", optFrame, "TOP", 0, -12)
optLogo:SetTexture("Interface\\AddOns\\BananaLoot\\Icons\\BananaLootBanner_460x120")

local optCloseBtn = CreateFrame("Button", "BananaLootOptionsCloseButton", optFrame, "UIPanelCloseButton")
optCloseBtn:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -4, -4)

local bonusLabel = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bonusLabel:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 20, -94)
bonusLabel:SetText("SR+ Bonus pro Stufe (Standard: 10):")

local bonusEditBox = CreateFrame("EditBox", "BananaLootBonusEditBox", optFrame, "InputBoxTemplate")
bonusEditBox:SetWidth(60)
bonusEditBox:SetHeight(20)
bonusEditBox:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 26, -120)
bonusEditBox:SetAutoFocus(false)
bonusEditBox:SetNumeric(true)

local bonusSaveBtn = CreateFrame("Button", "BananaLootBonusSaveBtn", optFrame, "UIPanelButtonTemplate")
bonusSaveBtn:SetWidth(80)
bonusSaveBtn:SetHeight(20)
bonusSaveBtn:SetPoint("LEFT", bonusEditBox, "RIGHT", 16, 0)
bonusSaveBtn:SetText("Speichern")
bonusSaveBtn:SetScript("OnClick", function()
    local value = tonumber(bonusEditBox:GetText())
    if value and value >= 0 then
        BananaLoot:SetBonusPerStack(value)
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: SR+ Bonus pro Stufe auf +" .. value .. " gesetzt.")
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BananaLoot|r: Bitte eine gültige Zahl eingeben.")
    end
end)

local optHint = optFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
optHint:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 20, -148)
optHint:SetWidth(260)
optHint:SetJustifyH("LEFT")
optHint:SetText("Beispiel: Wert 10 -> ein Spieler mit SR+2 bekommt +20 auf seinen Wurf.")

-- Roll-Timeout (Sekunden bis zur automatischen Auswertung)
local timeoutLabel = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timeoutLabel:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 20, -190)
timeoutLabel:SetText("Roll-Timeout in Sekunden (Standard: 60):")

local timeoutEditBox = CreateFrame("EditBox", "BananaLootTimeoutEditBox", optFrame, "InputBoxTemplate")
timeoutEditBox:SetWidth(60)
timeoutEditBox:SetHeight(20)
timeoutEditBox:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 26, -216)
timeoutEditBox:SetAutoFocus(false)
timeoutEditBox:SetNumeric(true)

local timeoutSaveBtn = CreateFrame("Button", "BananaLootTimeoutSaveBtn", optFrame, "UIPanelButtonTemplate")
timeoutSaveBtn:SetWidth(80)
timeoutSaveBtn:SetHeight(20)
timeoutSaveBtn:SetPoint("LEFT", timeoutEditBox, "RIGHT", 16, 0)
timeoutSaveBtn:SetText("Speichern")
timeoutSaveBtn:SetScript("OnClick", function()
    local value = tonumber(timeoutEditBox:GetText())
    if BananaLoot:SetRollTimeout(value) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Roll-Timeout auf " .. value .. " Sekunden gesetzt.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BananaLoot|r: Bitte eine gültige Zahl (mind. 5) eingeben.")
    end
end)

-- Chat-Countdown an/aus
local countdownCheck = CreateFrame("CheckButton", "BananaLootCountdownCheck", optFrame, "UICheckButtonTemplate")
countdownCheck:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 18, -248)
countdownCheck:SetScript("OnClick", function()
    local checked = countdownCheck:GetChecked()
    BananaLoot:SetChatCountdownEnabled(checked and true or false)
    if checked then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Chat-Countdown in den letzten Sekunden aktiviert.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Chat-Countdown deaktiviert.")
    end
end)

local countdownLabel = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
countdownLabel:SetPoint("LEFT", countdownCheck, "RIGHT", 2, 0)
countdownLabel:SetText("Chat-Countdown aktivieren")

local countdownHint = optFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
countdownHint:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 20, -272)
countdownHint:SetWidth(260)
countdownHint:SetJustifyH("LEFT")
countdownHint:SetText("Sagt bei 10, 5, 3, 2, 1 Sekunden im Raid-/Gruppenchat an, wie viel Zeit noch bleibt.")

function BananaLoot_UI:ToggleOptions()
    if optFrame:IsShown() then
        optFrame:Hide()
    else
        BananaLoot:EnsureDB()
        bonusEditBox:SetText(tostring(BananaLoot:GetBonusPerStack()))
        timeoutEditBox:SetText(tostring(BananaLoot:GetRollTimeout()))
        countdownCheck:SetChecked(BananaLoot:GetChatCountdownEnabled())
        optFrame:Show()
    end
end

-- ============================================================
-- 2) EXPORT / IMPORT POPUPS (für die Vertretung)
-- ============================================================
local function CreateCopyBoxFrame(name, titleText)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(420)
    f:SetHeight(180)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetText(titleText)

    local closeBtn = CreateFrame("Button", name .. "CloseButton", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local scrollFrame = CreateFrame("ScrollFrame", name .. "Scroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 46)

    local editBox = CreateFrame("EditBox", name .. "EditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(360)
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    f.editBox = editBox
    return f
end

local exportFrame = CreateCopyBoxFrame("BananaLootExportFrame", "SR-Liste exportieren")
local exportHint = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
exportHint:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 16)
exportHint:SetText("Strg+A, Strg+C zum Kopieren - dann deiner Vertretung schicken")

function BananaLoot_UI:ShowExport()
    local text = BananaLoot:ExportSRList()
    exportFrame.editBox:SetText(text)
    exportFrame.editBox:HighlightText()
    exportFrame:Show()
    exportFrame.editBox:SetFocus()
end

local importFrame = CreateCopyBoxFrame("BananaLootImportFrame", "SR-Liste importieren")
local importHint = importFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
importHint:SetPoint("BOTTOM", importFrame, "BOTTOM", 0, 40)
importHint:SetText("Text hier einfügen (Strg+V), dann Importieren klicken")

local importBtn = CreateFrame("Button", "BananaLootImportConfirmBtn", importFrame, "UIPanelButtonTemplate")
importBtn:SetWidth(100)
importBtn:SetHeight(20)
importBtn:SetPoint("BOTTOM", importFrame, "BOTTOM", 0, 12)
importBtn:SetText("Importieren")
importBtn:SetScript("OnClick", function()
    local text = importFrame.editBox:GetText()
    local ok, err, count, hrCount = BananaLoot:ImportSRList(text)
    if ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: " .. (count or 0) .. " Item-Reservierung(en) und " .. (hrCount or 0) .. " Hard-Reserve-Eintrag/Einträge importiert.")
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        importFrame:Hide()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BananaLoot|r: Import fehlgeschlagen - Text ungültig oder unvollständig kopiert.")
    end
end)

function BananaLoot_UI:ShowImport()
    importFrame.editBox:SetText("")
    importFrame:Show()
    importFrame.editBox:SetFocus()
end

-- ============================================================
-- 2b) CSV-EXPORT POPUPS (Tab-getrennt, für Google Sheets)
-- ============================================================
local csvResFrame = CreateCopyBoxFrame("BananaLootCsvResFrame", "SR-Liste als CSV (für Google Sheets)")
local csvResHint = csvResFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
csvResHint:SetPoint("BOTTOM", csvResFrame, "BOTTOM", 0, 16)
csvResHint:SetText("Strg+A, Strg+C - dann in eine leere Google-Sheets-Zelle einfügen (Strg+V)")

function BananaLoot_UI:ShowCSVReservations()
    local text = BananaLoot:ExportReservationsCSV()
    csvResFrame.editBox:SetText(text)
    csvResFrame.editBox:HighlightText()
    csvResFrame:Show()
    csvResFrame.editBox:SetFocus()
end

local csvLogFrame = CreateCopyBoxFrame("BananaLootCsvLogFrame", "Loot-Log als CSV (für Google Sheets)")
local csvLogHint = csvLogFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
csvLogHint:SetPoint("BOTTOM", csvLogFrame, "BOTTOM", 0, 16)
csvLogHint:SetText("Strg+A, Strg+C - dann in eine leere Google-Sheets-Zelle einfügen (Strg+V)")

function BananaLoot_UI:ShowCSVLog()
    local text = BananaLoot:ExportLogCSV()
    csvLogFrame.editBox:SetText(text)
    csvLogFrame.editBox:HighlightText()
    csvLogFrame:Show()
    csvLogFrame.editBox:SetFocus()
end

-- ============================================================
-- 2c) VERWALTEN: SR-Liste pro Item ansehen und bearbeiten
-- ============================================================
local manageFrame = CreateFrame("Frame", "BananaLootManageFrame", UIParent)
manageFrame:SetWidth(380)
manageFrame:SetHeight(420)
manageFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
manageFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 11, top = 11, bottom = 11 },
})
manageFrame:SetMovable(true)
manageFrame:EnableMouse(true)
manageFrame:RegisterForDrag("LeftButton")
manageFrame:SetScript("OnDragStart", function() manageFrame:StartMoving() end)
manageFrame:SetScript("OnDragStop", function() manageFrame:StopMovingOrSizing() end)
manageFrame:SetFrameStrata("DIALOG")
manageFrame:Hide()
manageFrame.itemID = nil

if StaticPopupDialogs then
    StaticPopupDialogs["BANANALOOT_CONFIRM_MANUAL_AWARD"] = {
        text = "%s als Gewinner setzen und das Item sofort vergeben?",
        button1 = "Ja",
        button2 = "Abbrechen",
        OnAccept = function()
            if BananaLoot_ManualAwardPending then
                BananaLoot:AwardItem(BananaLoot_ManualAwardPending.itemID, BananaLoot_ManualAwardPending.name)
                manageFrame:Hide()
                if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
                BananaLoot_ManualAwardPending = nil
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

local mgClose = CreateFrame("Button", "BananaLootManageCloseButton", manageFrame, "UIPanelCloseButton")
mgClose:SetPoint("TOPRIGHT", manageFrame, "TOPRIGHT", -4, -4)

local mgTitle = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
mgTitle:SetPoint("TOP", manageFrame, "TOP", 0, -16)
mgTitle:SetText("SR-Liste verwalten")

local mgItemText = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mgItemText:SetPoint("TOP", manageFrame, "TOP", 0, -38)
mgItemText:SetWidth(300)

local mgScroll = CreateFrame("ScrollFrame", "BananaLootManageScroll", manageFrame, "UIPanelScrollFrameTemplate")
mgScroll:SetPoint("TOPLEFT", manageFrame, "TOPLEFT", 16, -60)
mgScroll:SetPoint("BOTTOMRIGHT", manageFrame, "BOTTOMRIGHT", -30, 96)

local mgChild = CreateFrame("Frame", "BananaLootManageScrollChild", mgScroll)
mgChild:SetWidth(320)
mgChild:SetHeight(1)
mgScroll:SetScrollChild(mgChild)

local MG_ROW_H = 24
local MG_MAX = 25
local mgRows = {}

local function CreateMgRow(i)
    local r = CreateFrame("Frame", "BananaLootManageRow" .. i, mgChild)
    r:SetWidth(320)
    r:SetHeight(MG_ROW_H)
    r:SetPoint("TOPLEFT", mgChild, "TOPLEFT", 0, -(i - 1) * MG_ROW_H)

    r.nameText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.nameText:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.nameText:SetWidth(110)
    r.nameText:SetJustifyH("LEFT")

    r.minusBtn = CreateFrame("Button", "BananaLootManageRow" .. i .. "MinusBtn", r, "UIPanelButtonTemplate")
    r.minusBtn:SetWidth(16)
    r.minusBtn:SetHeight(18)
    r.minusBtn:SetPoint("LEFT", r.nameText, "RIGHT", 1, 0)
    r.minusBtn:SetText("-")

    r.plusBtn = CreateFrame("Button", "BananaLootManageRow" .. i .. "PlusBtn", r, "UIPanelButtonTemplate")
    r.plusBtn:SetWidth(16)
    r.plusBtn:SetHeight(18)
    r.plusBtn:SetPoint("LEFT", r.minusBtn, "RIGHT", 1, 0)
    r.plusBtn:SetText("+")

    r.removeBtn = CreateFrame("Button", "BananaLootManageRow" .. i .. "RemoveBtn", r, "UIPanelButtonTemplate")
    r.removeBtn:SetWidth(70)
    r.removeBtn:SetHeight(18)
    r.removeBtn:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.removeBtn:SetText("Entfernen")

    r.winBtn = CreateFrame("Button", "BananaLootManageRow" .. i .. "WinBtn", r, "UIPanelButtonTemplate")
    r.winBtn:SetWidth(80)
    r.winBtn:SetHeight(18)
    r.winBtn:SetPoint("RIGHT", r.removeBtn, "LEFT", -4, 0)
    r.winBtn:SetText("Gewinner")

    return r
end

for i = 1, MG_MAX do
    mgRows[i] = CreateMgRow(i)
    mgRows[i]:Hide()
end

local mgOverflowText = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
mgOverflowText:SetPoint("BOTTOM", manageFrame, "BOTTOM", 0, 86)
mgOverflowText:SetText("")

local function RefreshManage()
    local id = manageFrame.itemID
    if not id then return end
    local res = BananaLoot.reservations[id]
    local hrTag = BananaLoot:IsHardReserve(id) and " |cffff5555(Hard Reserve)|r" or ""
    mgItemText:SetText(((res and res.link) or BananaLoot.knownLootItems[id] or ("Item " .. id)) .. hrTag)

    if res and table.getn(res.order) > MG_MAX then
        mgOverflowText:SetText("|cffff5555" .. (table.getn(res.order) - MG_MAX) .. " weitere Spieler werden nicht angezeigt (Limit " .. MG_MAX .. ")|r")
    else
        mgOverflowText:SetText("")
    end

    local shown = 0
    if res then
        for i = 1, table.getn(res.order) do
            shown = shown + 1
            if shown > MG_MAX then break end
            local name = res.order[i]
            local row = mgRows[shown]
            local stack = BananaLoot:GetStack(name, id)
            local bonusTxt = ""
            if stack > 0 then bonusTxt = " |cffffcc00(+" .. (stack * BananaLoot:GetBonusPerStack()) .. ")|r" end
            row.nameText:SetText(name .. bonusTxt)
            row.minusBtn:Show()
            row.plusBtn:Show()
            row.removeBtn:Show()
            row.winBtn:Show()
            row.minusBtn:SetScript("OnClick", function()
                BananaLoot:DecrementStack(name, id)
                RefreshManage()
                if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
            end)
            row.plusBtn:SetScript("OnClick", function()
                BananaLoot:IncrementStack(name, id)
                RefreshManage()
                if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
            end)
            row.removeBtn:SetScript("OnClick", function()
                BananaLoot:RemoveReservation(res.link, name)
                RefreshManage()
                if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
            end)
            row.winBtn:SetScript("OnClick", function()
                if StaticPopup_Show then
                    BananaLoot_ManualAwardPending = { itemID = id, name = name }
                    StaticPopup_Show("BANANALOOT_CONFIRM_MANUAL_AWARD", name)
                else
                    BananaLoot:AwardItem(id, name)
                    manageFrame:Hide()
                    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
                end
            end)
            row:Show()
        end
    end
    for i = shown + 1, MG_MAX do mgRows[i]:Hide() end
    mgChild:SetHeight(math.max(1, shown * MG_ROW_H))

    if shown == 0 then
        mgRows[1].nameText:SetText("|cff888888(keine Reservierungen)|r")
        mgRows[1].minusBtn:Hide()
        mgRows[1].plusBtn:Hide()
        mgRows[1].removeBtn:Hide()
        mgRows[1].winBtn:Hide()
        mgRows[1]:Show()
    end
end

local mgAddLabel = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mgAddLabel:SetPoint("BOTTOMLEFT", manageFrame, "BOTTOMLEFT", 16, 58)
mgAddLabel:SetText("Spieler manuell hinzufügen (genaue Schreibweise):")

local mgAddBox = CreateFrame("EditBox", "BananaLootManageAddBox", manageFrame, "InputBoxTemplate")
mgAddBox:SetWidth(140)
mgAddBox:SetHeight(20)
mgAddBox:SetPoint("TOPLEFT", mgAddLabel, "BOTTOMLEFT", 6, -8)
mgAddBox:SetAutoFocus(false)

local mgAddBtn = CreateFrame("Button", "BananaLootManageAddBtn", manageFrame, "UIPanelButtonTemplate")
mgAddBtn:SetWidth(80)
mgAddBtn:SetHeight(20)
mgAddBtn:SetPoint("LEFT", mgAddBox, "RIGHT", 10, 0)
mgAddBtn:SetText("Hinzufügen")
mgAddBtn:SetScript("OnClick", function()
    local name = mgAddBox:GetText()
    local id = manageFrame.itemID
    if name and name ~= "" and id then
        local res = BananaLoot.reservations[id]
        local link = (res and res.link) or BananaLoot.knownLootItems[id]
        if link then
            -- forceIgnoreHR = true: der Loot-Master darf im Verwalten-Fenster
            -- auch für Hard-Reserve-Items direkt einen Spieler hinterlegen
            -- (z.B. um danach über "Gewinner" manuell zu vergeben).
            BananaLoot:AddReservation(link, name, true)
            if not BananaLoot:IsPlayerInRoster(name) then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00BananaLoot|r: Hinweis - '" .. name .. "' wurde hinzugefügt, ist aber aktuell nicht im Raid/der Gruppe. Bitte Schreibweise prüfen.")
            end
            mgAddBox:SetText("")
            RefreshManage()
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        end
    end
end)

local mgRemoveItemBtn = CreateFrame("Button", "BananaLootManageRemoveItemBtn", manageFrame, "UIPanelButtonTemplate")
mgRemoveItemBtn:SetWidth(180)
mgRemoveItemBtn:SetHeight(20)
mgRemoveItemBtn:SetPoint("BOTTOMLEFT", manageFrame, "BOTTOMLEFT", 16, 20)
mgRemoveItemBtn:SetText("Item komplett entfernen")
mgRemoveItemBtn:SetScript("OnClick", function()
    local id = manageFrame.itemID
    if id then
        BananaLoot.reservations[id] = nil
        BananaLoot.knownLootItems[id] = nil
        manageFrame:Hide()
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
    end
end)

function BananaLoot_UI:ShowManage(itemID)
    manageFrame.itemID = itemID
    RefreshManage()
    manageFrame:Show()
end

-- ============================================================
-- 2d) HARD RESERVE VERWALTUNG (Liste + Entfernen-Button je Item)
-- ============================================================
local hrFrame = CreateFrame("Frame", "BananaLootHRFrame", UIParent)
hrFrame:SetWidth(340)
hrFrame:SetHeight(360)
hrFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
hrFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 11, top = 11, bottom = 11 },
})
hrFrame:SetMovable(true)
hrFrame:EnableMouse(true)
hrFrame:RegisterForDrag("LeftButton")
hrFrame:SetScript("OnDragStart", function() hrFrame:StartMoving() end)
hrFrame:SetScript("OnDragStop", function() hrFrame:StopMovingOrSizing() end)
hrFrame:SetFrameStrata("DIALOG")
hrFrame:Hide()

local hrClose = CreateFrame("Button", "BananaLootHRCloseButton", hrFrame, "UIPanelCloseButton")
hrClose:SetPoint("TOPRIGHT", hrFrame, "TOPRIGHT", -4, -4)

local hrTitle = hrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hrTitle:SetPoint("TOP", hrFrame, "TOP", 0, -16)
hrTitle:SetText("Hard Reserve Items")

local hrHint = hrFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hrHint:SetPoint("TOP", hrFrame, "TOP", 0, -36)
hrHint:SetWidth(300)
hrHint:SetJustifyH("CENTER")
hrHint:SetText("Hinzufügen per /bl hr [Item] (Shift-Klick anhängen)")

local hrScroll = CreateFrame("ScrollFrame", "BananaLootHRScroll", hrFrame, "UIPanelScrollFrameTemplate")
hrScroll:SetPoint("TOPLEFT", hrFrame, "TOPLEFT", 16, -60)
hrScroll:SetPoint("BOTTOMRIGHT", hrFrame, "BOTTOMRIGHT", -30, 20)

local hrChild = CreateFrame("Frame", "BananaLootHRScrollChild", hrScroll)
hrChild:SetWidth(280)
hrChild:SetHeight(1)
hrScroll:SetScrollChild(hrChild)

local HR_ROW_H = 22
local HR_MAX = 30
local hrRows = {}

local function CreateHRRow(i)
    local r = CreateFrame("Frame", "BananaLootHRRow" .. i, hrChild)
    r:SetWidth(280)
    r:SetHeight(HR_ROW_H)
    r:SetPoint("TOPLEFT", hrChild, "TOPLEFT", 0, -(i - 1) * HR_ROW_H)

    r.linkText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.linkText:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.linkText:SetWidth(190)
    r.linkText:SetJustifyH("LEFT")

    r.removeBtn = CreateFrame("Button", "BananaLootHRRow" .. i .. "RemoveBtn", r, "UIPanelButtonTemplate")
    r.removeBtn:SetWidth(80)
    r.removeBtn:SetHeight(18)
    r.removeBtn:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.removeBtn:SetText("Entfernen")

    return r
end

for i = 1, HR_MAX do
    hrRows[i] = CreateHRRow(i)
    hrRows[i]:Hide()
end

local hrOverflowText = hrFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hrOverflowText:SetPoint("BOTTOM", hrFrame, "BOTTOM", 0, 4)
hrOverflowText:SetText("")

local function RefreshHRList()
    local list = BananaLoot:GetHardReserveList()
    local ids = {}
    for id, _ in pairs(list) do table.insert(ids, id) end
    table.sort(ids)

    if table.getn(ids) > HR_MAX then
        hrOverflowText:SetText("|cffff5555" .. (table.getn(ids) - HR_MAX) .. " weitere Item(s) werden nicht angezeigt|r")
    else
        hrOverflowText:SetText("")
    end

    local shown = 0
    for i = 1, table.getn(ids) do
        local id = ids[i]
        shown = shown + 1
        if shown > HR_MAX then break end
        local row = hrRows[shown]
        row.linkText:SetText(list[id].link)
        row.removeBtn:Show()
        row.removeBtn:SetScript("OnClick", function()
            BananaLoot:RemoveHardReserve(id)
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: " .. list[id].link .. " von Hard Reserve entfernt.")
            RefreshHRList()
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        end)
        row:Show()
    end
    for i = shown + 1, HR_MAX do hrRows[i]:Hide() end
    hrChild:SetHeight(math.max(1, shown * HR_ROW_H))

    if shown == 0 then
        hrRows[1].linkText:SetText("|cff888888(keine Hard-Reserve-Items)|r")
        hrRows[1].removeBtn:Hide()
        hrRows[1]:Show()
    end
end

function BananaLoot_UI:ShowHRList()
    RefreshHRList()
    hrFrame:Show()
end

-- ============================================================
-- 3) MINIMAP-BUTTON
-- ============================================================
local mmButton = CreateFrame("Button", "BananaLootMinimapButton", Minimap)
mmButton:SetWidth(31)
mmButton:SetHeight(31)
mmButton:SetFrameStrata("MEDIUM")
mmButton:SetFrameLevel(8)
mmButton:SetToplevel(true)
mmButton:SetMovable(true)
mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mmButton:RegisterForDrag("LeftButton")

local mmIcon = mmButton:CreateTexture(nil, "BACKGROUND")
mmIcon:SetWidth(20)
mmIcon:SetHeight(20)
mmIcon:SetPoint("CENTER", mmButton, "CENTER", 0, 0)
mmIcon:SetTexture("Interface\\AddOns\\BananaLoot\\Icons\\BananaLoot_MinimapIcon_64")

local mmBorder = mmButton:CreateTexture(nil, "OVERLAY")
mmBorder:SetWidth(54)
mmBorder:SetHeight(54)
mmBorder:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 0, 0)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Position entlang des Minimap-Randes speichern/laden (Winkel in Grad)
local function GetSavedAngle()
    BananaLoot:EnsureDB()
    return BananaLoot_DB.settings.minimapAngle or 200
end

local function SetSavedAngle(angle)
    BananaLoot:EnsureDB()
    BananaLoot_DB.settings.minimapAngle = angle
end

local function UpdateMinimapButtonPosition(angle)
    local radius = 80
    local rad = angle * (math.pi / 180)
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

mmButton:SetScript("OnDragStart", function()
    this.dragging = true
end)

mmButton:SetScript("OnDragStop", function()
    this.dragging = false
end)

mmButton:SetScript("OnUpdate", function()
    if this.dragging then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        UpdateMinimapButtonPosition(angle)
        SetSavedAngle(angle)
    end
end)

mmButton:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        BananaLoot_UI:ToggleOptions()
    else
        if BananaLoot_UI and BananaLoot_UI.Toggle then BananaLoot_UI:Toggle() end
    end
end)

mmButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("BananaLoot")
    GameTooltip:AddLine("Linksklick: Fenster öffnen", 1, 1, 1)
    GameTooltip:AddLine("Rechtsklick: Einstellungen", 1, 1, 1)
    GameTooltip:AddLine("Ziehen: Position am Minimap-Rand ändern", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Initiale Position setzen, sobald die Datenbank geladen ist
local mmInitFrame = CreateFrame("Frame")
mmInitFrame:RegisterEvent("PLAYER_LOGIN")
mmInitFrame:SetScript("OnEvent", function()
    UpdateMinimapButtonPosition(GetSavedAngle())
end)
