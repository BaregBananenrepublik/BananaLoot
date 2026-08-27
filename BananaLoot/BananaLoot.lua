-- BananaLoot.lua
-- Kernlogik: SavedVariables (SR+ DB, Settings), Whisper-Parsing,
-- automatische Roll-Erfassung mit Hauptspec/Off-Spec/Transmog-Pools,
-- Gleichstand-Behandlung, Loot-Fenster-Erkennung, Vergabe, Export/Import.
-- Vanilla 1.12 kompatibel (Lua 5.0 -> KEIN "#" Operator, KEIN string.gmatch!)

BananaLoot = {}
BananaLoot.VERSION = "3.3.0"
BananaLoot.DB_VERSION = 1 -- bei künftigen Strukturänderungen an BananaLoot_DB erhöhen und Migration in MigrateDB() ergänzen

-- ============================================================
-- 1) DATENBANK / SAVEDVARIABLES
-- ============================================================
local function EnsureDB()
    if not BananaLoot_DB then BananaLoot_DB = {} end
    if not BananaLoot_DB.players then BananaLoot_DB.players = {} end
    if not BananaLoot_DB.settings then BananaLoot_DB.settings = {} end
    if not BananaLoot_DB.hardReserves then BananaLoot_DB.hardReserves = {} end
end
BananaLoot.EnsureDB = EnsureDB

-- Führt bei Bedarf Migrationsschritte für ältere SavedVariables-Strukturen aus.
-- Aktuell gibt es nur Version 1, das Grundgerüst steht aber für künftige
-- Strukturänderungen bereit (einfach if dbVersion < X then ... end ergänzen).
local function MigrateDB()
    EnsureDB()
    local v = BananaLoot_DB.dbVersion or 0
    if v < 1 then
        -- Version 1: erstmalige Einführung des Versionsfeldes, keine Datenänderung nötig.
        v = 1
    end
    BananaLoot_DB.dbVersion = v
end

function BananaLoot:GetStack(playerName, itemID)
    EnsureDB()
    local p = BananaLoot_DB.players[playerName]
    if not p then return 0 end
    return p[itemID] or 0
end

function BananaLoot:IncrementStack(playerName, itemID)
    EnsureDB()
    BananaLoot_DB.players[playerName] = BananaLoot_DB.players[playerName] or {}
    local cur = BananaLoot_DB.players[playerName][itemID] or 0
    BananaLoot_DB.players[playerName][itemID] = cur + 1
end

function BananaLoot:ResetStack(playerName, itemID)
    EnsureDB()
    if BananaLoot_DB.players[playerName] then
        BananaLoot_DB.players[playerName][itemID] = nil
    end
end

function BananaLoot:DecrementStack(playerName, itemID)
    EnsureDB()
    if BananaLoot_DB.players[playerName] then
        local cur = BananaLoot_DB.players[playerName][itemID] or 0
        if cur > 1 then
            BananaLoot_DB.players[playerName][itemID] = cur - 1
        elseif cur == 1 then
            BananaLoot_DB.players[playerName][itemID] = nil
        end
    end
end

-- Konfigurierbarer SR+ Bonus pro Stufe (Standard: 10)
function BananaLoot:GetBonusPerStack()
    EnsureDB()
    return BananaLoot_DB.settings.bonusPerStack or 10
end

function BananaLoot:SetBonusPerStack(value)
    EnsureDB()
    value = tonumber(value)
    if not value or value < 0 then return false end
    BananaLoot_DB.settings.bonusPerStack = value
    return true
end

-- Konfigurierbare Roll-Dauer in Sekunden (Standard: 60)
function BananaLoot:GetRollTimeout()
    EnsureDB()
    return BananaLoot_DB.settings.rollTimeout or 60
end

function BananaLoot:SetRollTimeout(value)
    EnsureDB()
    value = tonumber(value)
    if not value or value < 5 then return false end
    BananaLoot_DB.settings.rollTimeout = value
    return true
end

-- Chat-Countdown in den letzten Sekunden vor Rollende (Standard: an)
function BananaLoot:GetChatCountdownEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.chatCountdown == nil then return true end
    return BananaLoot_DB.settings.chatCountdown
end

function BananaLoot:SetChatCountdownEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.chatCountdown = value and true or false
end

-- ============================================================
-- 2) AKTUELLE SESSION (Reservierungen)
-- ============================================================
BananaLoot.reservations = {}       -- [itemID] = { link, name, players={}, order={} }
BananaLoot.playerCurrentItem = {}  -- [name] = itemID (Regel: 1 SR pro Raid)
BananaLoot.knownLootItems = {}     -- [itemID] = link (aktuell im Loot-Fenster sichtbar, auch ohne SR)
BananaLoot.lootCounts = {}         -- [itemID] = Anzahl noch offener Kopien im aktuellen Loot-Fenster (Mehrfachdrops)
BananaLoot.lastWhisperTime = {}    -- [name] = GetTime() der letzten verarbeiteten Whisper-Anfrage (Spam-Schutz)

-- Entfernt führende/nachfolgende Leerzeichen (kein string.gmatch in Lua 5.0)
local function Trim(str)
    if not str then return str end
    local _, _, captured = string.find(str, "^%s*(.-)%s*$")
    return captured or str
end

local function GetItemIDFromLink(link)
    if not link then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    if id then return tonumber(id) end
    return nil
end

local function GetItemNameFromLink(link)
    if not link then return nil end
    local _, _, name = string.find(link, "%[(.-)%]")
    return name or link
end

-- ============================================================
-- 1b) HARD RESERVE (HR) -- dauerhaft, bis manuell entfernt.
-- HR-Items werden NICHT über Whisper reservierbar, nicht in der
-- Auto-Roll-Schleife verrollt, sondern ausschließlich manuell
-- (im "Verwalten"-Fenster) an einen Spieler vergeben.
-- ============================================================
function BananaLoot:IsHardReserve(itemID)
    EnsureDB()
    return BananaLoot_DB.hardReserves[itemID] ~= nil
end

function BananaLoot:AddHardReserve(itemLink)
    local id = GetItemIDFromLink(itemLink)
    if not id then return false end
    EnsureDB()
    BananaLoot_DB.hardReserves[id] = { link = itemLink }
    return true, id
end

function BananaLoot:RemoveHardReserve(itemID)
    EnsureDB()
    if BananaLoot_DB.hardReserves[itemID] then
        BananaLoot_DB.hardReserves[itemID] = nil
        return true
    end
    return false
end

function BananaLoot:GetHardReserveList()
    EnsureDB()
    return BananaLoot_DB.hardReserves
end

function BananaLoot:AddReservation(itemLink, playerName, forceIgnoreHR)
    local id = GetItemIDFromLink(itemLink)
    if not id then return false, "invalid_link" end
    if not forceIgnoreHR and self:IsHardReserve(id) then return false, "hard_reserve" end

    local oldId = self.playerCurrentItem[playerName]
    if oldId and oldId ~= id then
        local oldRes = self.reservations[oldId]
        if oldRes and oldRes.players[playerName] then
            oldRes.players[playerName] = nil
            for i = 1, table.getn(oldRes.order) do
                if oldRes.order[i] == playerName then
                    table.remove(oldRes.order, i)
                    break
                end
            end
        end
        self:ResetStack(playerName, oldId)
    end

    if not self.reservations[id] then
        self.reservations[id] = { link = itemLink, name = GetItemNameFromLink(itemLink), players = {}, order = {} }
    end

    local res = self.reservations[id]
    if not res.players[playerName] then
        res.players[playerName] = true
        table.insert(res.order, playerName)
    end
    res.link = itemLink
    self.playerCurrentItem[playerName] = id

    self:SaveSession()
    return true, id, oldId
end

function BananaLoot:RemoveReservation(itemLink, playerName)
    local id = GetItemIDFromLink(itemLink)
    if not id then return false end
    local res = self.reservations[id]
    if not res or not res.players[playerName] then return false end

    res.players[playerName] = nil
    for i = 1, table.getn(res.order) do
        if res.order[i] == playerName then
            table.remove(res.order, i)
            break
        end
    end
    if self.playerCurrentItem[playerName] == id then
        self.playerCurrentItem[playerName] = nil
    end
    self:SaveSession()
    return true
end

function BananaLoot:ClearAllReservations()
    self.reservations = {}
    self.playerCurrentItem = {}
    self:SaveSession()
end

-- Sichert die aktuelle Session (Reservierungen) in den SavedVariables,
-- damit sie /reload und Disconnects überlebt.
function BananaLoot:SaveSession()
    EnsureDB()
    BananaLoot_DB.session = {
        reservations = self.reservations,
        playerCurrentItem = self.playerCurrentItem,
    }
end

function BananaLoot:RestoreSession()
    EnsureDB()
    if BananaLoot_DB.session then
        self.reservations = BananaLoot_DB.session.reservations or {}
        self.playerCurrentItem = BananaLoot_DB.session.playerCurrentItem or {}
    end
end

function BananaLoot:GetReservationForItem(itemID)
    return self.reservations[itemID]
end

-- ============================================================
-- 3) WHISPER-COMMANDS
-- ============================================================
local function SendWhisperReply(target, msg)
    SendChatMessage(msg, "WHISPER", nil, target)
end

local function ExtractLinkFromMessage(msg)
    local s, e = string.find(msg, "|c%x+|Hitem:.-|h%[.-%]|h|r")
    if s then return string.sub(msg, s, e) end
    return nil
end

function BananaLoot:HandleWhisper(sender, msg)
    local now = GetTime()
    local last = self.lastWhisperTime[sender]
    if last and (now - last) < 2 then
        return -- Spam-Schutz: max. 1 Befehl alle 2 Sekunden pro Spieler
    end
    self.lastWhisperTime[sender] = now

    msg = Trim(msg)
    local lower = string.lower(msg)
    local isSR = (string.find(lower, "^sr ") or string.find(lower, "^!sr "))
    local isUnSR = (string.find(lower, "^unsr ") or string.find(lower, "^!unsr "))
    local isList = (lower == "srlist" or lower == "!srlist")
    local isHRQuery = (lower == "hr" or lower == "!hr" or lower == "hrlist" or lower == "!hrlist")

    if isList then
        self:ReplyWithPlayerList(sender)
        return
    end

    if isHRQuery then
        self:ReplyWithHRList(sender)
        return
    end

    if isSR then
        local link = ExtractLinkFromMessage(msg)
        if not link then
            SendWhisperReply(sender, "BananaLoot: Bitte das Item per Shift-Klick in den Whisper einfügen (z.B. \"sr [Item]\").")
            return
        end
        local ok, idOrErr, oldId = self:AddReservation(link, sender)
        if ok then
            local stack = self:GetStack(sender, idOrErr)
            local bonusTxt = ""
            if stack > 0 then bonusTxt = string.format(" (dein SR+ Bonus: +%d)", stack * self:GetBonusPerStack()) end
            local swapTxt = ""
            if oldId and oldId ~= idOrErr then
                swapTxt = " Achtung: deine vorherige Reservierung wurde ersetzt, der SR+ Bonus dafür ist verloren."
            end
            SendWhisperReply(sender, "BananaLoot: " .. link .. " wurde für dich reserviert." .. bonusTxt .. swapTxt)
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        elseif idOrErr == "hard_reserve" then
            SendWhisperReply(sender, "BananaLoot: " .. link .. " ist Hard Reserve und wird manuell vergeben. Bitte setze dein SR auf ein anderes Item.")
        else
            SendWhisperReply(sender, "BananaLoot: Konnte Item nicht erkennen, bitte erneut versuchen.")
        end
        return
    end

    if isUnSR then
        local link = ExtractLinkFromMessage(msg)
        if not link then
            SendWhisperReply(sender, "BananaLoot: Bitte das Item per Shift-Klick einfügen um es zu entfernen.")
            return
        end
        local ok = self:RemoveReservation(link, sender)
        if ok then
            SendWhisperReply(sender, "BananaLoot: Reservierung für " .. link .. " wurde entfernt.")
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        else
            SendWhisperReply(sender, "BananaLoot: Du hattest dieses Item nicht reserviert.")
        end
        return
    end

    -- Unbekannter Befehl: Rückmeldung statt stillem Ignorieren (hilft bei Tippfehlern).
    SendWhisperReply(sender, "BananaLoot: Befehl nicht erkannt. Nutze 'sr [Item]', 'unsr [Item]', 'srlist' oder 'hr'.")
end

function BananaLoot:ReplyWithPlayerList(sender)
    local found = false
    for id, res in pairs(self.reservations) do
        if res.players[sender] then
            found = true
            local stack = self:GetStack(sender, id)
            local bonusTxt = ""
            if stack > 0 then bonusTxt = string.format(" | SR+ Bonus: +%d", stack * self:GetBonusPerStack()) end
            SendWhisperReply(sender, "BananaLoot: " .. res.link .. bonusTxt)
        end
    end
    if not found then
        SendWhisperReply(sender, "BananaLoot: Du hast aktuell keine Reservierungen.")
    end
end

-- Listet alle aktuell auf Hard Reserve stehenden Items per Whisper auf.
function BananaLoot:ReplyWithHRList(sender)
    EnsureDB()
    local found = false
    for _, hr in pairs(BananaLoot_DB.hardReserves) do
        found = true
        SendWhisperReply(sender, "BananaLoot: " .. hr.link .. " ist Hard Reserve.")
    end
    if not found then
        SendWhisperReply(sender, "BananaLoot: Aktuell sind keine Items auf Hard Reserve.")
    end
end

-- ============================================================
-- 4) HILFSFUNKTIONEN: Chat-Kanal, Raid-Roster, berechtigte Roller
-- ============================================================
function BananaLoot:GetAnnounceChannel()
    if GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers() > 0 then return "PARTY" end
    return "SAY"
end

local function GetCurrentRosterSet()
    local set = {}
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            local name = UnitName("raid" .. i)
            if name then set[name] = true end
        end
    else
        set[UnitName("player")] = true
        local pn = GetNumPartyMembers()
        for i = 1, pn do
            local name = UnitName("party" .. i)
            if name then set[name] = true end
        end
    end
    return set
end

-- Prüft, ob ein Name aktuell im Raid/der Gruppe (bzw. der Spieler selbst) ist.
-- Nützlich als Tippfehler-Warnung beim manuellen Hinzufügen im Verwalten-Fenster.
function BananaLoot:IsPlayerInRoster(name)
    if not name then return false end
    local set = GetCurrentRosterSet()
    return set[name] == true
end

-- gibt es SR-Reservierungen -> nur diese Spieler sind für Hauptspec (MS) berechtigt.
-- gibt es keine -> die komplette anwesende Gruppe/Raid darf MS rollen.
local function GetEligiblePlayers(itemID)
    local res = BananaLoot.reservations[itemID]
    if res and table.getn(res.order) > 0 then
        local set = {}
        for i = 1, table.getn(res.order) do set[res.order[i]] = true end
        return set, true
    end
    return GetCurrentRosterSet(), false
end

-- ============================================================
-- 5) ROLL-ERFASSUNG (MS / Off-Spec / Transmog, automatische Auswertung)
-- ============================================================
-- activeRoll = {
--   itemID, link, rolls = { [name] = { value=, type="ms"/"os"/"tmog" } },
--   srEligible (Set oder nil), restricted (bool),
--   waitFor (Set oder nil, zum Auto-Abschluss), restrictTo (Set oder nil, Tie-Break),
--   running, startTime, maxDuration, winner, winnerScore, winnerRoll, winnerPool
-- }

BananaLoot.activeRoll = nil
BananaLoot.autoRunning = false
BananaLoot.lootQueue = {}

function BananaLoot:StartRoll(itemID, maxDuration, forceOpen)
    if self:IsHardReserve(itemID) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[BananaLoot]|r Dieses Item ist Hard Reserve und wird nicht verrollt -- bitte manuell im \"Verwalten\"-Fenster vergeben.")
        return false
    end
    local res = self.reservations[itemID]
    local link = (res and res.link) or ("item:" .. itemID .. ":0:0:0:0:0:0:0")
    local eligible, restricted = GetEligiblePlayers(itemID)
    if forceOpen then
        eligible, restricted = GetCurrentRosterSet(), false
    end

    self.activeRoll = {
        itemID = itemID,
        link = link,
        rolls = {},
        srEligible = restricted and eligible or nil,
        waitFor = restricted and eligible or nil,
        restrictTo = nil,
        restricted = restricted,
        running = true,
        startTime = GetTime(),
        maxDuration = maxDuration or self:GetRollTimeout(),
        lastCountdownSecond = nil,
    }

    local channel = self:GetAnnounceChannel()
    local howTo = "/roll = Hauptspec, /roll 1 99 = Off-Spec, /roll 1 98 = Transmog"

    if restricted then
        local names = ""
        for i = 1, table.getn(res.order) do
            local n = res.order[i]
            local stack = self:GetStack(n, itemID)
            names = names .. n .. (stack > 0 and ("(+" .. (stack * self:GetBonusPerStack()) .. ")") or "") .. " "
        end
        SendChatMessage("[BananaLoot] SR-Roll für " .. link .. " -- " .. names .. "-- " .. howTo, channel)
    elseif forceOpen then
        SendChatMessage("[BananaLoot] ARF: Roll für " .. link .. " -- SR ausgesetzt, offen für alle -- " .. howTo, channel)
    else
        SendChatMessage("[BananaLoot] Roll für " .. link .. " -- offen für alle -- " .. howTo, channel)
    end

    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
    return true
end

function BananaLoot:StopRoll()
    self.activeRoll = nil
end

-- Wird bei jedem erkannten "X rolls Y (1-100/99/98)" System-Chat aufgerufen.
function BananaLoot:OnRoll(name, value, rollType)
    local ar = self.activeRoll
    if not ar or not ar.running then return end
    if ar.rolls[name] then return end -- Mehrfachroll ignorieren

    if ar.restrictTo and not ar.restrictTo[name] then return end -- Tie-Break: nur betroffene Spieler
    if rollType == "ms" and ar.srEligible and not ar.srEligible[name] then return end -- Item SR't -> MS nur für Reservierer

    ar.rolls[name] = { value = value, type = rollType }

    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    local waitSet = ar.restrictTo or ar.waitFor
    if waitSet then
        local allRolled = true
        for n, _ in pairs(waitSet) do
            if not ar.rolls[n] then allRolled = false break end
        end
        if allRolled then self:ResolveActiveRoll() end
    end
end

local function EvaluatePool(pool, useBonus, itemID)
    local bestScore, bestRoll, winners = -1, nil, {}
    for i = 1, table.getn(pool) do
        local entry = pool[i]
        local bonus = 0
        if useBonus then bonus = BananaLoot:GetStack(entry.name, itemID) * BananaLoot:GetBonusPerStack() end
        local score = entry.value + bonus
        if score > bestScore then
            bestScore, winners, bestRoll = score, { entry.name }, entry.value
        elseif score == bestScore then
            table.insert(winners, entry.name)
        end
    end
    return winners, bestScore, bestRoll
end

-- Wertet den aktuellen Roll aus. Priorität: Hauptspec > Off-Spec > Transmog.
-- Bei Gleichstand: nur die betroffenen Spieler müssen erneut rollen.
function BananaLoot:ResolveActiveRoll()
    local ar = self.activeRoll
    if not ar then return end

    local pools = { ms = {}, os = {}, tmog = {} }
    for name, data in pairs(ar.rolls) do
        table.insert(pools[data.type], { name = name, value = data.value })
    end

    local winners, bestScore, bestRoll, poolLabel

    if table.getn(pools.ms) > 0 then
        winners, bestScore, bestRoll = EvaluatePool(pools.ms, true, ar.itemID)
        poolLabel = "Hauptspec"
    elseif table.getn(pools.os) > 0 then
        winners, bestScore, bestRoll = EvaluatePool(pools.os, false, ar.itemID)
        poolLabel = "Off-Spec"
    elseif table.getn(pools.tmog) > 0 then
        winners, bestScore, bestRoll = EvaluatePool(pools.tmog, false, ar.itemID)
        poolLabel = "Transmog"
    else
        ar.running = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[BananaLoot]|r Niemand hat für " .. ar.link .. " gerollt.")
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        if self.autoRunning then
            self.activeRoll = nil
            self:AutoAdvance()
        end
        return
    end

    if table.getn(winners) > 1 then
        local names = ""
        local newEligible = {}
        for i = 1, table.getn(winners) do
            names = names .. winners[i] .. " "
            newEligible[winners[i]] = true
            ar.rolls[winners[i]] = nil
        end
        ar.restrictTo = newEligible
        ar.startTime = GetTime()
        SendChatMessage("[BananaLoot] Gleichstand (" .. poolLabel .. ") bei " .. bestScore .. "! " .. names .. "-- bitte erneut rollen (gleiche Kategorie)!", self:GetAnnounceChannel())
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        return
    end

    ar.running = false
    ar.winner = winners[1]
    ar.winnerScore = bestScore
    ar.winnerRoll = bestRoll
    ar.winnerPool = poolLabel

    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[BananaLoot]|r Gewinner (" .. poolLabel .. ") für " .. ar.link .. ": " .. ar.winner .. " (Wurf " .. bestRoll .. ", Wertung " .. bestScore .. ")")
    SendChatMessage("[BananaLoot] " .. ar.winner .. " gewinnt " .. ar.link .. " (" .. poolLabel .. ")!", self:GetAnnounceChannel())

    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
end

-- ============================================================
-- 6) VERGABE (Award) -> löst SR+ Buchung aus, versucht automatisch zuzuweisen
-- ============================================================
function BananaLoot:AwardItem(itemID, winnerName)
    local res = self.reservations[itemID]
    local link = (res and res.link) or self.knownLootItems[itemID] or ("Item " .. itemID)

    local assigned = false
    pcall(function()
        local n = GetNumLootItems()
        for slot = 1, n do
            if assigned then break end
            local slotLink = GetLootSlotLink(slot)
            if slotLink then
                local _, _, slotItemID = string.find(slotLink, "item:(%d+)")
                if slotItemID and tonumber(slotItemID) == itemID then
                    if self:TryGiveMasterLoot(slot, winnerName) then assigned = true end
                end
            end
        end
    end)

    -- Kategorie für das Log ermitteln (Hauptspec/Off-Spec/Transmog/Manuell)
    local poolLabel = "Manuell"
    if self.activeRoll and self.activeRoll.itemID == itemID and self.activeRoll.winnerPool then
        poolLabel = self.activeRoll.winnerPool
    end
    self:LogAward(link, winnerName, poolLabel)

    self:ResetStack(winnerName, itemID)
    if res then
        for i = 1, table.getn(res.order) do
            local n = res.order[i]
            if n ~= winnerName then self:IncrementStack(n, itemID) end
        end
        -- Gewinner aus der Reservierung entfernen (nicht die ganze Reservierung
        -- löschen!): fällt dasselbe Item ein zweites Mal, darf derselbe Spieler
        -- nicht nochmal gewinnen, aber übrige Reservierer bleiben für den
        -- nächsten Roll dieses Items berechtigt.
        if res.players[winnerName] then
            res.players[winnerName] = nil
            for i = 1, table.getn(res.order) do
                if res.order[i] == winnerName then
                    table.remove(res.order, i)
                    break
                end
            end
        end
        if self.playerCurrentItem[winnerName] == itemID then
            self.playerCurrentItem[winnerName] = nil
        end
    end

    if assigned then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[BananaLoot]|r " .. link .. " -> " .. winnerName .. " (automatisch zugewiesen)")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[BananaLoot]|r " .. link .. " -> " .. winnerName .. " |cffff5555(bitte manuell im Loot-Fenster zuweisen!)|r")
    end

    -- Mehrfachdrops: nur wenn keine weitere bekannte Kopie dieses Items mehr
    -- offen ist, Reservierung/Sichtbarkeit im Loot-Fenster komplett entfernen.
    -- Ist die Anzahl unbekannt (z.B. rein manuelle Vergabe ohne Scan), wird
    -- wie bisher sofort vollständig entfernt.
    local remaining = self.lootCounts[itemID]
    if remaining then
        remaining = remaining - 1
        self.lootCounts[itemID] = remaining
    end
    if not remaining or remaining <= 0 then
        if res then self.reservations[itemID] = nil end
        self.knownLootItems[itemID] = nil
        self.lootCounts[itemID] = nil
    end

    self:SaveSession()
    if self.activeRoll and self.activeRoll.itemID == itemID then self.activeRoll = nil end

    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    if self.autoRunning then
        if assigned then
            self:AutoAdvance()
        else
            self.autoRunning = false
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[BananaLoot]|r Auto-Modus pausiert: bitte manuell im Loot-Fenster vergeben, dann /bl auto erneut tippen um fortzufahren.")
            pcall(function() PlaySound("RaidWarning") end)
        end
    end
end

function BananaLoot:AwardActiveWinner()
    local ar = self.activeRoll
    if not ar or ar.running or not ar.winner then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[BananaLoot]|r Kein abgeschlossener Roll vorhanden.")
        return
    end
    self:AwardItem(ar.itemID, ar.winner)
end

-- ============================================================
-- 7) LOOT-FENSTER: Erkennung + automatische Reihenfolge
-- ============================================================
function BananaLoot:ScanLootWindow()
    local items = {}
    local n = GetNumLootItems()
    for slot = 1, n do
        local link = GetLootSlotLink(slot)
        if link then
            local id = GetItemIDFromLink(link)
            if id then table.insert(items, { itemID = id, link = link }) end
        end
    end
    return items
end

local function IsPlayerMasterLooter()
    local ok, method, mlPartyID, mlRaidID = pcall(GetLootMethod)
    if not ok or method ~= "master" then return false end
    if GetNumRaidMembers() > 0 then
        if mlRaidID and UnitName("raid" .. mlRaidID) == UnitName("player") then return true end
        return false
    else
        if mlPartyID == 0 then return true end
        if mlPartyID and UnitName("party" .. mlPartyID) == UnitName("player") then return true end
        return false
    end
end

-- Zählt, wie oft jede itemID im aktuellen Loot-Fenster vorkommt
-- (Mehrfachdrops desselben Items in unterschiedlichen Slots).
local function BuildLootCounts(items)
    local counts = {}
    for i = 1, table.getn(items) do
        local id = items[i].itemID
        counts[id] = (counts[id] or 0) + 1
    end
    return counts
end

-- Aktualisiert BananaLoot.knownLootItems mit den aktuell im Loot-Fenster
-- sichtbaren Items (auch ohne SR), rein zur Anzeige im UI, unabhängig
-- von der Auto-Modus-Queue.
function BananaLoot:RefreshKnownLootItems()
    local items = self:ScanLootWindow()
    local map = {}
    for i = 1, table.getn(items) do
        local it = items[i]
        map[it.itemID] = it.link
    end
    self.knownLootItems = map
end

-- Entfernt Reservierungen von Spielern, die aktuell nicht mehr im
-- Raid/der Gruppe sind (z.B. Disconnect/Verlassen). SR+ Werte bleiben
-- unangetastet, nur die aktive Reservierung fällt weg.
function BananaLoot:PruneAbsentReservations()
    local roster = GetCurrentRosterSet()
    local removedNames = {}
    for id, res in pairs(self.reservations) do
        local i = 1
        while i <= table.getn(res.order) do
            local name = res.order[i]
            if not roster[name] then
                self:RemoveReservation(res.link, name)
                table.insert(removedNames, name .. " (" .. (GetItemNameFromLink(res.link) or res.link) .. ")")
            else
                i = i + 1
            end
        end
    end
    if table.getn(removedNames) > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[BananaLoot]|r Reservierung(en) entfernt (nicht mehr im Raid): " .. table.concat(removedNames, ", "))
    end
end

function BananaLoot:OnLootOpened()
    if not IsPlayerMasterLooter() then return end

    self:PruneAbsentReservations()

    local items = self:ScanLootWindow()
    if table.getn(items) == 0 then return end

    self.lootQueue = items
    self.lootCounts = BuildLootCounts(items)
    self:RefreshKnownLootItems()

    local summary = "|cff33ff99[BananaLoot]|r Loot erkannt: "
    for i = 1, table.getn(items) do
        local it = items[i]
        local res = self.reservations[it.itemID]
        local tag = ""
        if res and table.getn(res.order) > 0 then
            tag = " |cffffcc00(SR: " .. table.getn(res.order) .. ")|r"
        end
        summary = summary .. it.link .. tag .. "  "
    end
    DEFAULT_CHAT_FRAME:AddMessage(summary)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[BananaLoot]|r Tippe |cffffff00/bl auto|r für automatischen Durchlauf, oder |cffffff00/bl|r für die Fensteransicht.")
end

local function SortQueueNonSRFirst(queue)
    local nonSR, withSR = {}, {}
    for i = 1, table.getn(queue) do
        local it = queue[i]
        local res = BananaLoot.reservations[it.itemID]
        if res and table.getn(res.order) > 0 then
            table.insert(withSR, it)
        else
            table.insert(nonSR, it)
        end
    end
    local out = {}
    for i = 1, table.getn(nonSR) do table.insert(out, nonSR[i]) end
    for i = 1, table.getn(withSR) do table.insert(out, withSR[i]) end
    return out
end

function BananaLoot:AutoAdvance()
    self.lootQueue = SortQueueNonSRFirst(self.lootQueue)

    -- Hard-Reserve-Items werden nie automatisch verrollt, nur manuell vergeben.
    local filtered = {}
    local skippedHR = {}
    for i = 1, table.getn(self.lootQueue) do
        local it = self.lootQueue[i]
        if self:IsHardReserve(it.itemID) then
            table.insert(skippedHR, it.link)
        else
            table.insert(filtered, it)
        end
    end
    self.lootQueue = filtered
    if table.getn(skippedHR) > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[BananaLoot]|r Hard-Reserve-Items übersprungen (bitte manuell vergeben): " .. table.concat(skippedHR, ", "))
    end

    if table.getn(self.lootQueue) == 0 then
        self.autoRunning = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[BananaLoot]|r Alle Items abgearbeitet.")
        return
    end

    self.autoRunning = true
    local nextItem = table.remove(self.lootQueue, 1)

    -- lootCounts wird bei vollständiger Vergabe (auch manuell über "Verwalten")
    -- auf nil gesetzt. Ist das hier schon der Fall, wurde das Item bereits
    -- fertig bearbeitet -> überspringen statt erneut zu verrollen.
    if self.lootCounts[nextItem.itemID] == nil then
        self:AutoAdvance()
        return
    end

    self:StartRoll(nextItem.itemID)
end

-- ============================================================
-- 8) LOOT-VERGABE-API (best effort, Server-API kann leicht abweichen!)
-- ============================================================
function BananaLoot:TryGiveMasterLoot(lootSlot, winnerName)
    local didAssign = false
    local ok = pcall(function()
        local numCandidates = 40
        for i = 1, numCandidates do
            local candidateName = GetMasterLootCandidate(lootSlot, i)
            if candidateName and candidateName == winnerName then
                GiveMasterLoot(lootSlot, i)
                didAssign = true
                return
            end
        end
    end)
    return ok and didAssign
end

-- ============================================================
-- 9) EXPORT / IMPORT DER SR-LISTE (für deine Vertretung)
-- ============================================================
-- Format: "MSRv2~itemID^itemLink^Spieler1:Stack1`Spieler2:Stack2~itemID2^...~H^hrItemID^hrItemLink~..."
-- (Datensätze mit "H" als erstem Feld sind Hard-Reserve-Einträge)

local function Split(str, sep)
    local result = {}
    local start = 1
    while true do
        local s, e = string.find(str, sep, start, true)
        if not s then
            table.insert(result, string.sub(str, start))
            break
        end
        table.insert(result, string.sub(str, start, s - 1))
        start = e + 1
    end
    return result
end

function BananaLoot:ExportSRList()
    local records = {}
    for id, res in pairs(self.reservations) do
        if table.getn(res.order) > 0 then
            local playerParts = {}
            for i = 1, table.getn(res.order) do
                local name = res.order[i]
                local stack = self:GetStack(name, id)
                table.insert(playerParts, name .. ":" .. stack)
            end
            table.insert(records, id .. "^" .. res.link .. "^" .. table.concat(playerParts, "`"))
        end
    end
    EnsureDB()
    for id, hr in pairs(BananaLoot_DB.hardReserves) do
        table.insert(records, "H^" .. id .. "^" .. hr.link)
    end

    return "MSRv2~" .. table.concat(records, "~")
end

-- Importiert eine Export-Zeichenkette. Bestehende Reservierungen für die
-- enthaltenen Items werden ersetzt, alles andere bleibt unangetastet.
-- Die SR+ Werte der gelisteten Spieler/Items werden mit übernommen,
-- damit die Vertretung sofort korrekt rechnet.
function BananaLoot:ImportSRList(str)
    if not str or string.sub(str, 1, 6) ~= "MSRv2~" then
        return false, "invalid_format", 0
    end

    local body = string.sub(str, 7)
    if body == "" then return true, nil, 0 end

    local records = Split(body, "~")
    local itemCount = 0
    local hrCount = 0

    for i = 1, table.getn(records) do
        local rec = records[i]
        if rec ~= "" then
            local fields = Split(rec, "^")
            if fields[1] == "H" then
                if table.getn(fields) >= 3 then
                    local hrId = tonumber(fields[2])
                    local hrLink = fields[3]
                    if hrId then
                        EnsureDB()
                        BananaLoot_DB.hardReserves[hrId] = { link = hrLink }
                        hrCount = hrCount + 1
                    end
                end
            elseif table.getn(fields) >= 3 then
                local id = tonumber(fields[1])
                local link = fields[2]
                local playersStr = fields[3]
                if id then
                    self.reservations[id] = { link = link, name = GetItemNameFromLink(link), players = {}, order = {} }
                    local res = self.reservations[id]
                    itemCount = itemCount + 1

                    local playerParts = Split(playersStr, "`")
                    for p = 1, table.getn(playerParts) do
                        local pf = Split(playerParts[p], ":")
                        local pname = pf[1]
                        local pstack = tonumber(pf[2]) or 0
                        if pname and pname ~= "" then
                            local oldId = self.playerCurrentItem[pname]
                            if oldId and oldId ~= id then
                                local oldRes = self.reservations[oldId]
                                if oldRes and oldRes.players[pname] then
                                    oldRes.players[pname] = nil
                                    for oi = 1, table.getn(oldRes.order) do
                                        if oldRes.order[oi] == pname then
                                            table.remove(oldRes.order, oi)
                                            break
                                        end
                                    end
                                end
                            end
                            res.players[pname] = true
                            table.insert(res.order, pname)
                            self.playerCurrentItem[pname] = id
                            EnsureDB()
                            BananaLoot_DB.players[pname] = BananaLoot_DB.players[pname] or {}
                            BananaLoot_DB.players[pname][id] = pstack
                        end
                    end
                end
            end
        end
    end

    self:SaveSession()
    return true, nil, itemCount, hrCount
end

-- ============================================================
-- 9b) LOOT-LOG + CSV-EXPORT (Google Sheets: Tab-getrennter Text,
--     einfach mit Strg+V in eine leere Zelle einfügen)
-- ============================================================
function BananaLoot:LogAward(link, winnerName, poolLabel)
    EnsureDB()
    if not BananaLoot_DB.log then BananaLoot_DB.log = {} end
    table.insert(BananaLoot_DB.log, {
        time = date("%d.%m.%Y %H:%M"),
        item = GetItemNameFromLink(link) or link,
        winner = winnerName,
        pool = poolLabel or "SR",
    })
end

function BananaLoot:ClearLog()
    EnsureDB()
    BananaLoot_DB.log = {}
end

-- Tab-getrennte Tabelle: Datum | Item | Spieler | Kategorie
function BananaLoot:ExportLogCSV()
    EnsureDB()
    local lines = { "Datum\tItem\tSpieler\tKategorie" }
    local log = BananaLoot_DB.log or {}
    for i = 1, table.getn(log) do
        local e = log[i]
        table.insert(lines, e.time .. "\t" .. e.item .. "\t" .. e.winner .. "\t" .. e.pool)
    end
    return table.concat(lines, "\n")
end

-- Tab-getrennte Tabelle der AKTUELL offenen Reservierungen: Item | Spieler | SR+ Bonus
function BananaLoot:ExportReservationsCSV()
    local lines = { "Item\tSpieler\tSR+ Bonus" }
    local ids = {}
    for id, _ in pairs(self.reservations) do table.insert(ids, id) end
    table.sort(ids)
    for i = 1, table.getn(ids) do
        local id = ids[i]
        local res = self.reservations[id]
        local itemName = GetItemNameFromLink(res.link) or res.link
        for p = 1, table.getn(res.order) do
            local name = res.order[p]
            local stack = self:GetStack(name, id)
            table.insert(lines, itemName .. "\t" .. name .. "\t" .. (stack * self:GetBonusPerStack()))
        end
    end
    return table.concat(lines, "\n")
end

-- ============================================================
-- 10) EVENT HANDLING (klassischer Vanilla-Stil: globale arg1..argN)
-- ============================================================
local eventFrame = CreateFrame("Frame", "BananaLootEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("LOOT_OPENED")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "BananaLoot" then
        EnsureDB()
        MigrateDB()
        BananaLoot:RestoreSession()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r geladen. /bl öffnet das Fenster, /bl auto startet den automatischen Loot-Durchlauf.")

    elseif event == "CHAT_MSG_WHISPER" then
        BananaLoot:HandleWhisper(arg2, arg1)

    elseif event == "CHAT_MSG_SYSTEM" then
        if BananaLoot.activeRoll and BananaLoot.activeRoll.running then
            local _, _, roller, value, maxRange = string.find(arg1, "^(.+) rolls (%d+) %(1%-(%d+)%)$")
            if roller and value and maxRange then
                local rollType = nil
                if maxRange == "100" then rollType = "ms"
                elseif maxRange == "99" then rollType = "os"
                elseif maxRange == "98" then rollType = "tmog" end
                if rollType then
                    BananaLoot:OnRoll(roller, tonumber(value), rollType)
                end
            end
        end

    elseif event == "LOOT_OPENED" then
        BananaLoot:OnLootOpened()
    end
end)

local COUNTDOWN_SECONDS = { [10] = true, [5] = true, [3] = true, [2] = true, [1] = true }

eventFrame:SetScript("OnUpdate", function()
    local ar = BananaLoot.activeRoll
    if ar and ar.running then
        local elapsed = GetTime() - ar.startTime
        if elapsed > ar.maxDuration then
            BananaLoot:ResolveActiveRoll()
        elseif BananaLoot:GetChatCountdownEnabled() then
            local remaining = math.ceil(ar.maxDuration - elapsed)
            if remaining >= 1 and remaining <= 10 and COUNTDOWN_SECONDS[remaining] and ar.lastCountdownSecond ~= remaining then
                ar.lastCountdownSecond = remaining
                local msg
                if remaining == 10 then
                    msg = "[BananaLoot] Roll endet in 10 Sekunden -- bitte bald abschließen!"
                else
                    local unit = (remaining == 1) and "Sekunde" or "Sekunden"
                    msg = "[BananaLoot] Noch " .. remaining .. " " .. unit .. "!"
                end
                SendChatMessage(msg, BananaLoot:GetAnnounceChannel())
            end
        end
    end
end)

-- ============================================================
-- 11) SLASH COMMANDS
-- ============================================================
SLASH_BANANALOOT1 = "/bl"
SLASH_BANANALOOT2 = "/bananaloot"
SlashCmdList["BANANALOOT"] = function(msg)
    msg = Trim(msg or "")
    local cmd = string.lower(msg)

    if cmd == "reset" then
        BananaLoot:ClearAllReservations()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Alle aktuellen Reservierungen gelöscht (SR+ Werte bleiben erhalten).")
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    elseif cmd == "wipeplus" then
        if StaticPopup_Show then
            StaticPopup_Show("BANANALOOT_CONFIRM_WIPE")
        else
            EnsureDB()
            BananaLoot_DB.players = {}
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Alle SR+ Werte komplett zurückgesetzt.")
        end

    elseif cmd == "auto" then
        BananaLoot.lootQueue = BananaLoot:ScanLootWindow()
        BananaLoot.lootCounts = BuildLootCounts(BananaLoot.lootQueue)
        BananaLoot:AutoAdvance()

    elseif cmd == "award" then
        BananaLoot:AwardActiveWinner()

    elseif string.find(cmd, "^arf") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id then
            BananaLoot:StartRoll(id, nil, true)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BananaLoot|r: Bitte Item per Shift-Klick anhängen, z.B. /bl arf [Item].")
        end

    elseif string.find(cmd, "^hr remove") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id and BananaLoot:RemoveHardReserve(id) then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Hard Reserve entfernt.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BananaLoot|r: Item nicht gefunden oder nicht auf Hard Reserve.")
        end
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    elseif cmd == "hr" then
        if BananaLoot_UI and BananaLoot_UI.ShowHRList then BananaLoot_UI:ShowHRList() end

    elseif string.find(cmd, "^hr") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id then
            BananaLoot:AddHardReserve(link)
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: " .. link .. " als Hard Reserve hinterlegt.")
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BananaLoot|r: Bitte Item per Shift-Klick anhängen, z.B. /bl hr [Item].")
        end

    elseif cmd == "stop" then
        BananaLoot.autoRunning = false
        BananaLoot:StopRoll()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Auto-Modus / aktiver Roll gestoppt.")

    elseif cmd == "export" then
        if BananaLoot_UI and BananaLoot_UI.ShowExport then BananaLoot_UI:ShowExport() end

    elseif cmd == "import" then
        if BananaLoot_UI and BananaLoot_UI.ShowImport then BananaLoot_UI:ShowImport() end

    elseif cmd == "csv" then
        if BananaLoot_UI and BananaLoot_UI.ShowCSVReservations then BananaLoot_UI:ShowCSVReservations() end

    elseif cmd == "csvlog" then
        if BananaLoot_UI and BananaLoot_UI.ShowCSVLog then BananaLoot_UI:ShowCSVLog() end

    elseif cmd == "clearlog" then
        BananaLoot:ClearLog()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r: Loot-Log geleert.")

    elseif cmd == "options" or cmd == "config" then
        if BananaLoot_UI and BananaLoot_UI.ToggleOptions then BananaLoot_UI:ToggleOptions() end

    elseif cmd == "open" or cmd == "" then
        if BananaLoot_UI and BananaLoot_UI.Toggle then BananaLoot_UI:Toggle() end

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BananaLoot|r Befehle: /bl, /bl auto, /bl award, /bl arf [Item], /bl stop, /bl reset, /bl wipeplus, /bl export, /bl import, /bl csv, /bl csvlog, /bl clearlog, /bl options, /bl hr [Item], /bl hr remove [Item]")
    end
end
