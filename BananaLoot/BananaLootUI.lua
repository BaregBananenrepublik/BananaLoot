-- BananaLootUI.lua
-- Sichtbares Fenster für den Masterlooter. Baut das komplette UI in Lua auf
-- (kein XML nötig, dadurch unabhängig von FrameXML-Eigenheiten des Servers).

BananaLoot_UI = {}

local ROW_HEIGHT = 74
local MAX_ROWS = 20
local rows = {}

-- ------------------------------------------------------------
-- Hauptfenster
-- ------------------------------------------------------------
local frame = CreateFrame("Frame", "BananaLootFrame", UIParent)
frame:SetWidth(460)
frame:SetHeight(540)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 11, top = 11, bottom = 11 },
})
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() frame:StartMoving() end)
frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
frame:SetFrameStrata("HIGH")
frame:Hide()

local titleIcon = frame:CreateTexture(nil, "ARTWORK")
titleIcon:SetWidth(20)
titleIcon:SetHeight(20)
titleIcon:SetTexture("Interface\\AddOns\\BananaLoot\\Icons\\BananaLoot_MinimapIcon_64")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetText("BananaLoot - SoftReserve / SR+")
title:SetPoint("TOP", frame, "TOP", 0, -18)

titleIcon:SetPoint("RIGHT", title, "LEFT", -6, 0)

local closeBtn = CreateFrame("Button", "BananaLootFrameCloseButton", frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

-- ------------------------------------------------------------
-- Kopfzeile: manuelle Eingabe + Steuerbuttons
-- ------------------------------------------------------------
local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -42)
hint:SetText("Spieler reservieren per Whisper: |cffffff00sr [Item]|r  /  |cffffff00unsr [Item]|r")

local resetBtn = CreateFrame("Button", "BananaLootResetBtn", frame, "UIPanelButtonTemplate")
resetBtn:SetWidth(110)
resetBtn:SetHeight(20)
resetBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -62)
resetBtn:SetText("Neuer Raid")
resetBtn:SetScript("OnClick", function()
    if StaticPopup_Show then
        StaticPopup_Show("BANANALOOT_CONFIRM_RESET")
    else
        BananaLoot:ClearAllReservations()
        BananaLoot_UI:Refresh()
    end
end)

local wipeBtn = CreateFrame("Button", "BananaLootWipeBtn", frame, "UIPanelButtonTemplate")
wipeBtn:SetWidth(130)
wipeBtn:SetHeight(20)
wipeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)
wipeBtn:SetText("SR+ komplett leeren")
wipeBtn:SetScript("OnClick", function()
    if StaticPopup_Show then
        StaticPopup_Show("BANANALOOT_CONFIRM_WIPE")
    else
        BananaLoot:EnsureDB()
        BananaLoot_DB.players = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Alle SR+ Werte zurückgesetzt.")
        BananaLoot_UI:Refresh()
    end
end)

local exportBtn = CreateFrame("Button", "BananaLootExportBtn", frame, "UIPanelButtonTemplate")
exportBtn:SetWidth(90)
exportBtn:SetHeight(20)
exportBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -6)
exportBtn:SetText("Export")
exportBtn:SetScript("OnClick", function() BananaLoot_UI:ShowExport() end)

local importBtn = CreateFrame("Button", "BananaLootImportBtn", frame, "UIPanelButtonTemplate")
importBtn:SetWidth(90)
importBtn:SetHeight(20)
importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
importBtn:SetText("Import")
importBtn:SetScript("OnClick", function() BananaLoot_UI:ShowImport() end)

local optionsBtn = CreateFrame("Button", "BananaLootOptionsBtn", frame, "UIPanelButtonTemplate")
optionsBtn:SetWidth(90)
optionsBtn:SetHeight(20)
optionsBtn:SetPoint("LEFT", importBtn, "RIGHT", 6, 0)
optionsBtn:SetText("Optionen")
optionsBtn:SetScript("OnClick", function() BananaLoot_UI:ToggleOptions() end)

local csvBtn = CreateFrame("Button", "BananaLootCsvBtn", frame, "UIPanelButtonTemplate")
csvBtn:SetWidth(120)
csvBtn:SetHeight(20)
csvBtn:SetPoint("TOPLEFT", exportBtn, "BOTTOMLEFT", 0, -6)
csvBtn:SetText("CSV: SR-Liste")
csvBtn:SetScript("OnClick", function() BananaLoot_UI:ShowCSVReservations() end)

local csvLogBtn = CreateFrame("Button", "BananaLootCsvLogBtn", frame, "UIPanelButtonTemplate")
csvLogBtn:SetWidth(120)
csvLogBtn:SetHeight(20)
csvLogBtn:SetPoint("LEFT", csvBtn, "RIGHT", 6, 0)
csvLogBtn:SetText("CSV: Loot-Log")
csvLogBtn:SetScript("OnClick", function() BananaLoot_UI:ShowCSVLog() end)

local clearLogBtn = CreateFrame("Button", "BananaLootClearLogBtn", frame, "UIPanelButtonTemplate")
clearLogBtn:SetWidth(100)
clearLogBtn:SetHeight(20)
clearLogBtn:SetPoint("LEFT", csvLogBtn, "RIGHT", 6, 0)
clearLogBtn:SetText("Log leeren")
clearLogBtn:SetScript("OnClick", function()
    BananaLoot:ClearLog()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Loot-Log geleert.")
end)

-- Bestätigungsdialog für "Neuer Raid" (nur falls StaticPopup verfügbar)
if StaticPopupDialogs then
    StaticPopupDialogs["BANANALOOT_CONFIRM_RESET"] = {
        text = "Alle aktuellen SR-Reservierungen löschen? (SR+ Werte bleiben erhalten)",
        button1 = "Ja",
        button2 = "Abbrechen",
        OnAccept = function()
            BananaLoot:ClearAllReservations()
            BananaLoot_UI:Refresh()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["BANANALOOT_CONFIRM_WIPE"] = {
        text = "ALLE SR+ Werte ALLER Spieler unwiderruflich löschen? Das kann nicht rückgängig gemacht werden!",
        button1 = "Ja, komplett leeren",
        button2 = "Abbrechen",
        OnAccept = function()
            BananaLoot:EnsureDB()
            BananaLoot_DB.players = {}
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Alle SR+ Werte zurückgesetzt.")
            BananaLoot_UI:Refresh()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

-- ------------------------------------------------------------
-- Scroll-Bereich mit den Item-Zeilen
-- ------------------------------------------------------------
local overflowText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
overflowText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 4)
overflowText:SetText("")

local scrollFrame = CreateFrame("ScrollFrame", "BananaLootScrollFrame", frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -142)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 20)

local scrollChild = CreateFrame("Frame", "BananaLootScrollChild", scrollFrame)
scrollChild:SetWidth(400)
scrollChild:SetHeight(1) -- wird dynamisch angepasst
scrollFrame:SetScrollChild(scrollChild)

-- ------------------------------------------------------------
-- Zeilen-Erzeugung (Pool, wiederverwendet)
-- ------------------------------------------------------------
local function CreateRow(index)
    local row = CreateFrame("Frame", "BananaLootRow" .. index, scrollChild)
    row:SetWidth(400)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture(0, 0, 0, 0.15)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(32)
    row.icon:SetHeight(32)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)

    row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.itemText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    row.itemText:SetJustifyH("LEFT")
    row.itemText:SetWidth(200)

    row.manageBtn = CreateFrame("Button", "BananaLootRow" .. index .. "ManageBtn", row, "UIPanelButtonTemplate")
    row.manageBtn:SetWidth(76)
    row.manageBtn:SetHeight(18)
    row.manageBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -4)
    row.manageBtn:SetText("Verwalten")

    row.playersText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.playersText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -18)
    row.playersText:SetJustifyH("LEFT")
    row.playersText:SetWidth(260)
    row.playersText:SetHeight(30)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -52)
    row.statusText:SetJustifyH("LEFT")
    row.statusText:SetWidth(220)

    row.rollBtn = CreateFrame("Button", "BananaLootRow" .. index .. "RollBtn", row, "UIPanelButtonTemplate")
    row.rollBtn:SetWidth(85)
    row.rollBtn:SetHeight(20)
    row.rollBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 2)
    row.rollBtn:SetText("Roll starten")

    row.arfBtn = CreateFrame("Button", "BananaLootRow" .. index .. "ArfBtn", row, "UIPanelButtonTemplate")
    row.arfBtn:SetWidth(50)
    row.arfBtn:SetHeight(20)
    row.arfBtn:SetPoint("RIGHT", row.rollBtn, "LEFT", -4, 0)
    row.arfBtn:SetText("ARF")

    row.awardBtn = CreateFrame("Button", "BananaLootRow" .. index .. "AwardBtn", row, "UIPanelButtonTemplate")
    row.awardBtn:SetWidth(90)
    row.awardBtn:SetHeight(20)
    row.awardBtn:SetPoint("RIGHT", row.arfBtn, "LEFT", -4, 0)
    row.awardBtn:SetText("Vergeben")
    row.awardBtn:Hide()

    return row
end

for i = 1, MAX_ROWS do
    rows[i] = CreateRow(i)
    rows[i]:Hide()
end

-- ------------------------------------------------------------
-- Refresh: baut die Liste aus BananaLoot.reservations neu auf
-- ------------------------------------------------------------
function BananaLoot_UI:Refresh()
    -- Falls gerade ein Loot-Fenster offen ist, Ansicht auf aktuellsten Stand bringen
    if LootFrame and LootFrame:IsShown() then
        BananaLoot:RefreshKnownLootItems()
    end

    -- Sortierte Liste: reservierte Items + aktuell im Loot-Fenster sichtbare Items
    -- (auch ohne SR), damit man immer den vollen Überblick hat.
    local idSet = {}
    for id, _ in pairs(BananaLoot.reservations) do idSet[id] = true end
    for id, _ in pairs(BananaLoot.knownLootItems) do idSet[id] = true end

    local ids = {}
    for id, _ in pairs(idSet) do
        table.insert(ids, id)
    end
    table.sort(ids)

    if table.getn(ids) > MAX_ROWS then
        overflowText:SetText("|cffff5555" .. (table.getn(ids) - MAX_ROWS) .. " weitere Item(s) werden nicht angezeigt (Limit " .. MAX_ROWS .. ")|r")
    else
        overflowText:SetText("")
    end

    local shown = 0
    for i = 1, table.getn(ids) do
        local id = ids[i]
        local res = BananaLoot.reservations[id]
        shown = shown + 1
        if shown > MAX_ROWS then break end

        local row = rows[shown]
        row.itemID = id
        row:Show()

        -- Icon laden (best effort, funktioniert wenn Item im Cache ist)
        local _, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(id)
        if itemTexture then
            row.icon:SetTexture(itemTexture)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local displayLink = (res and res.link) or BananaLoot.knownLootItems[id] or ("Item " .. id)
        local isHR = BananaLoot:IsHardReserve(id)
        local tag
        if isHR then
            tag = " |cffff5555[HR]|r"
        elseif res and table.getn(res.order) > 0 then
            tag = " |cffffcc00[SR]|r"
        else
            tag = " |cff88ff88[Offen]|r"
        end
        local qty = BananaLoot.lootCounts[id]
        local qtyTxt = (qty and qty > 1) and (" |cff88ccff(x" .. qty .. ")|r") or ""
        row.itemText:SetText(displayLink .. tag .. qtyTxt)

        row.manageBtn:SetScript("OnClick", function()
            BananaLoot_UI:ShowManage(id)
        end)

        local list = ""
        if res then
            for p = 1, table.getn(res.order) do
                local name = res.order[p]
                local stack = BananaLoot:GetStack(name, id)
                if stack > 0 then
                    list = list .. name .. "|cffffcc00(+" .. (stack * BananaLoot:GetBonusPerStack()) .. ")|r"
                else
                    list = list .. name
                end
                if p < table.getn(res.order) then list = list .. ", " end
            end
        end
        if list == "" then list = "|cff888888(offen für alle -- noch keine Reservierungen)|r" end
        row.playersText:SetText(list)

        -- Status / Roll-Auswertung
        row.statusText:SetText("")
        row.awardBtn:Hide()

        if isHR then
            row.statusText:SetText("|cffff5555Hard Reserve -- nur manuelle Vergabe über \"Verwalten\"|r")
            row.rollBtn:Disable()
            row.arfBtn:Disable()
        elseif BananaLoot.activeRoll and BananaLoot.activeRoll.itemID == id then
            if BananaLoot.activeRoll.running then
                local waitSet = BananaLoot.activeRoll.restrictTo or BananaLoot.activeRoll.waitFor
                if waitSet then
                    local pending = ""
                    local pendingCount = 0
                    for n, _ in pairs(waitSet) do
                        if not BananaLoot.activeRoll.rolls[n] then
                            pending = pending .. n .. " "
                            pendingCount = pendingCount + 1
                        end
                    end
                    if pendingCount > 0 then
                        row.statusText:SetText("Warte auf: " .. pending)
                    else
                        row.statusText:SetText("Werte aus...")
                    end
                else
                    row.statusText:SetText("Roll offen (kein festes Ende, siehe Timeout)")
                end
                row.rollBtn:Disable()
                row.arfBtn:Disable()
            else
                local winner, score, roll, pool = BananaLoot.activeRoll.winner, BananaLoot.activeRoll.winnerScore, BananaLoot.activeRoll.winnerRoll, BananaLoot.activeRoll.winnerPool
                if winner then
                    row.statusText:SetText("Gewinner (" .. (pool or "?") .. "): |cff33ff99" .. winner .. "|r (Wurf " .. roll .. ", Wertung " .. score .. ")")
                    row.awardBtn:Show()
                    row.awardBtn:SetScript("OnClick", function()
                        BananaLoot:AwardItem(id, winner)
                    end)
                else
                    row.statusText:SetText("|cffff5555Niemand hat gerollt.|r")
                end
                row.rollBtn:Enable()
                row.rollBtn:SetText("Roll starten")
                row.arfBtn:Enable()
            end
        else
            row.rollBtn:Enable()
            row.rollBtn:SetText("Roll starten")
            row.arfBtn:Enable()
        end

        row.arfBtn:SetScript("OnClick", function()
            BananaLoot:StartRoll(id, nil, true)
            BananaLoot_UI:Refresh()
        end)

        row.rollBtn:SetScript("OnClick", function()
            BananaLoot:StartRoll(id)
            BananaLoot_UI:Refresh()
        end)
    end

    for i = shown + 1, MAX_ROWS do
        rows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, shown * ROW_HEIGHT))
end

-- ------------------------------------------------------------
-- Live-Update während ein Roll-Timer läuft
-- ------------------------------------------------------------
local ticker = CreateFrame("Frame")
local lastUpdate = 0
ticker:SetScript("OnUpdate", function()
    if not frame:IsShown() then return end
    lastUpdate = lastUpdate + arg1
    if lastUpdate > 1 then
        lastUpdate = 0
        if BananaLoot.activeRoll and BananaLoot.activeRoll.running then
            BananaLoot_UI:Refresh()
        end
    end
end)

-- ------------------------------------------------------------
-- Öffnen / Schließen
-- ------------------------------------------------------------
function BananaLoot_UI:Toggle()
    if frame:IsShown() then
        frame:Hide()
    else
        BananaLoot_UI:Refresh()
        frame:Show()
    end
end
