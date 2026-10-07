-- BananaLoot.lua
-- Kernlogik: SavedVariables (SR+ DB, Settings), Whisper-Parsing,
-- automatische Roll-Erfassung mit Hauptspec/Off-Spec/Transmog-Pools,
-- Gleichstand-Behandlung, Loot-Fenster-Erkennung, Vergabe, Export/Import.
-- Vanilla 1.12 kompatibel (Lua 5.0 -> KEIN "#" Operator, KEIN string.gmatch!)

BananaLoot = {}
BananaLoot.VERSION = "3.32"
BananaLoot.DB_VERSION = 1 -- bei künftigen Strukturänderungen an BananaLoot_DB erhöhen und Migration in MigrateDB() ergänzen

-- ============================================================
-- 1) DATENBANK / SAVEDVARIABLES
-- ============================================================
local function EnsureDB()
    if not BananaLoot_DB then BananaLoot_DB = {} end
    if not BananaLoot_DB.players then BananaLoot_DB.players = {} end
    if not BananaLoot_DB.settings then BananaLoot_DB.settings = {} end
    if not BananaLoot_DB.hardReserves then BananaLoot_DB.hardReserves = {} end
    if not BananaLoot_DB.bankReserves then BananaLoot_DB.bankReserves = {} end
    if not BananaLoot_DB.lastOverwritten then BananaLoot_DB.lastOverwritten = {} end
    if not BananaLoot_DB.savedRaids then BananaLoot_DB.savedRaids = {} end
    -- [itemID] = { winner = Spielername } -- wer hat aktuell ein über
    -- BananaLoot vergebenes Item (zuletzt bekannter Stand, wird bei jeder
    -- Vergabe sowie bei jeder erkannten Weitergabe per Handel aktualisiert,
    -- siehe Trade-Tracking, Abschnitt 4c).
    if not BananaLoot_DB.awardedItems then BananaLoot_DB.awardedItems = {} end
end
BananaLoot.EnsureDB = EnsureDB

-- ============================================================
-- 1a) SPRACHE / ÜBERSETZUNGEN
-- ============================================================
local LOCALE = {
    de = {
        -- Whisper / Chat
        MSG_ADDON_LOADED = "|cff33ff99BananaLoot|r geladen. /bl öffnet das Fenster, /bl auto startet den automatischen Loot-Durchlauf.",
        WHISPER_SR_NEED_LINK = "BananaLoot: Bitte das Item per Shift-Klick in den Whisper einfügen (z.B. \"sr [Item]\").",
        WHISPER_SR_RESERVED = "BananaLoot: %s wurde für dich reserviert.",
        WHISPER_SR_BONUS_SUFFIX = " (dein SR+ Bonus: +%d)",
        WHISPER_SR_SWAP_SUFFIX = " Achtung: deine vorherige Reservierung wurde ersetzt, der SR+ Bonus dafür ist verloren.",
        WHISPER_SR_HARD_RESERVE = "BananaLoot: %s ist Hard Reserve und wird manuell vergeben. Bitte setze dein SR auf ein anderes Item.",
        WHISPER_SR_LIMIT_REACHED = "BananaLoot: Du hast bereits die maximale Anzahl an Reservierungen (%d) erreicht. Bitte entferne zuerst eine mit 'unsr [Item]'.",
        WHISPER_SR_UNKNOWN_ITEM = "BananaLoot: Konnte Item nicht erkennen, bitte erneut versuchen.",
        WHISPER_UNSR_NEED_LINK = "BananaLoot: Bitte das Item per Shift-Klick einfügen um es zu entfernen.",
        WHISPER_UNSR_REMOVED = "BananaLoot: Reservierung für %s wurde entfernt.",
        WHISPER_UNSR_NOT_RESERVED = "BananaLoot: Du hattest dieses Item nicht reserviert.",
        WHISPER_UNKNOWN_COMMAND = "BananaLoot: Befehl nicht erkannt. Nutze 'sr [Item]', 'unsr [Item]', 'srlist' oder 'hr'.",
        WHISPER_LIST_ENTRY = "BananaLoot: %s",
        WHISPER_LIST_BONUS_SUFFIX = " -- SR+ Bonus: +%d",
        WHISPER_LIST_EMPTY = "BananaLoot: Du hast aktuell keine Reservierungen.",
        WHISPER_LIST_OTHERS_PREFIX = "BananaLoot: Ebenfalls auf SR: %s",
        WHISPER_HR_ENTRY = "BananaLoot: %s ist Hard Reserve.",
        WHISPER_HR_EMPTY = "BananaLoot: Aktuell sind keine Items auf Hard Reserve.",
        WHISPER_SR_LOCKED = "BananaLoot: Die SR-Liste ist für diesen Raid gesperrt. Bitte wende dich direkt an den Loot-Master.",
        SR_LOCK_ON = "|cff33ff99BananaLoot|r: SR-Liste gesperrt -- Whisper-Reservierungen (sr/unsr) sind deaktiviert.",
        SR_LOCK_OFF = "|cff33ff99BananaLoot|r: SR-Liste entsperrt -- Whisper-Reservierungen (sr/unsr) sind wieder möglich.",
        UI_BTN_LOCK_TOOLTIP_LOCKED = "SR-Liste ist gesperrt (Whisper-Reservierungen deaktiviert). Klicken zum Entsperren.",
        UI_BTN_LOCK_TOOLTIP_UNLOCKED = "SR-Liste ist offen (Whisper-Reservierungen aktiv). Klicken zum Sperren.",
        UI_BTN_LOCK_LOCKED = "Gesperrt",
        UI_BTN_LOCK_UNLOCKED = "Offen",
        UI_BTN_LOOTMETHOD_TOOLTIP = "Wechselt zwischen Gruppenloot (GL) und Masterloot (ML, du selbst). Funktioniert nur, wenn du Gruppen-/Raidleiter bist.",
        UI_BTN_AUTO_ON = "Auto: An",
        UI_BTN_AUTO_OFF = "Auto: Aus",
        UI_BTN_AUTO_TOOLTIP = "Startet/pausiert den automatischen Loot-Durchlauf (wie /bl auto). Ein bereits laufender Roll wird beim Ausschalten NICHT abgebrochen -- dafür weiterhin /bl stop nutzen.",
        UI_BTN_STOP = "Stopp",
        UI_BTN_STOP_TOOLTIP = "Bricht den Auto-Modus UND einen gerade laufenden Roll sofort ab (wie /bl stop).",
        WHISPER_SR_BANK_RESERVE = "BananaLoot: %s ist Bankreserve und wird automatisch vergeben. Bitte setze dein SR auf ein anderes Item.",

        -- Roll-Ansagen
        ROLL_HOWTO = "/roll = Hauptspec, /roll 1 99 = Off-Spec, /roll 1 98 = Transmog",
        ROLL_ANNOUNCE_SR = "[BananaLoot] SR-Roll für %s -- %s-- %s",
        ROLL_ANNOUNCE_ARF = "[BananaLoot] ARF: Roll für %s -- SR ausgesetzt, offen für alle -- %s",
        ROLL_ANNOUNCE_OPEN = "[BananaLoot] Roll für %s -- offen für alle -- %s",
        ROLL_HARD_RESERVE_BLOCKED = "|cffff5555[BananaLoot]|r Dieses Item ist Hard Reserve und wird nicht verrollt -- bitte manuell im \"Verwalten\"-Fenster vergeben.",
        ROLL_BANK_RESERVE_BLOCKED = "|cffff5555[BananaLoot]|r Dieses Item ist Bankreserve und wird nicht verrollt -- es wird automatisch vergeben.",
        ROLL_NOBODY_ROLLED = "|cffff5555[BananaLoot]|r Niemand hat für %s gerollt.",
        ROLL_NOBODY_ROLLED_REST = "|cffffcc00[BananaLoot]|r Für den/die verbleibenden Platz/Plätze bei %s hat niemand gerollt -- bereits ermittelte Gewinner bleiben bestehen.",
        ROLL_TIE = "[BananaLoot] Gleichstand (%s) bei %d! %s-- bitte erneut rollen (gleiche Kategorie)!",
        ROLL_WINNER_CHAT = "|cff33ff99[BananaLoot]|r Gewinner (%s) für %s: %s (Wurf %d, Wertung %d)",
        ROLL_WINNER_ANNOUNCE = "[BananaLoot] %s gewinnt %s (%s)!",
        ROLL_WINNERS_ANNOUNCE = "[BananaLoot] %s -- %s: %s teilen sich den Sieg!",
        ROLL_SLOTS_SUFFIX = " |cff88ccff(%d Kopien -- Top-Rolls gewinnen)|r",
        POOL_MS = "Hauptspec",
        POOL_OS = "Off-Spec",
        POOL_TMOG = "Transmog",
        POOL_MANUAL = "Manuell",
        POOL_BANK = "Bankreserve",
        POOL_RAIDROLL = "Raid Roll",
        RAID_ROLL_ANNOUNCE = "[BananaLoot] %s -- Vergabe per random raid Roll an: %s",
        MG_RAIDROLL_BTN = "Raid Roll",
        MG_RAIDROLL_POPUP_TEXT = "%s per Zufalls-Roll unter dem kompletten Raid vergeben (kein SR nötig, Spieler müssen nicht selbst würfeln)?",
        UI_BTN_HELP_TOOLTIP = "Befehlsübersicht anzeigen",
        WIN_HELP_TITLE = "Befehlsübersicht",
        WIN_HELP_HINT = "Strg+A, Strg+C zum Kopieren",

        -- Vergabe
        AWARD_ASSIGNED = "|cff33ff99[BananaLoot]|r %s -> %s (automatisch zugewiesen)",
        AWARD_NOT_ASSIGNED = "|cff33ff99[BananaLoot]|r %s -> %s |cffff5555(bitte manuell im Loot-Fenster zuweisen!)|r",
        AWARD_FAIL_NOLOOT = "|cffff5555[BananaLoot]|r %s -> %s: Loot-Fenster ist zu. Kadaver nochmal anklicken, die Vergabe wird dann automatisch nachgeholt.",
        AWARD_FAIL_NOCAND = "|cffff5555[BananaLoot]|r %s -> %s: Spieler steht nicht in der Vergabeliste (zu weit weg, andere Zone, als Geist am Friedhof oder offline). Bitte manuell vergeben.",
        AWARD_PENDING_DONE = "|cff33ff99[BananaLoot]|r %s -> %s nachtraeglich zugewiesen.",
        AWARD_PENDING_DROPPED = "|cffff5555[BananaLoot]|r %s -> %s: Vormerkung verworfen, Item liegt nicht mehr in diesem Loot-Fenster. Bitte manuell vergeben.",
        LOOT_CLOSED_WARN = "|cffffcc00[BananaLoot]|r Loot-Fenster geschlossen. Solange es zu ist, kann nichts vergeben werden.",
        AWARD_NO_WINNER = "|cffff5555[BananaLoot]|r Kein abgeschlossener Roll vorhanden.",
        AWARD_BANK_AUTO = "|cff33ff99[BananaLoot]|r %s automatisch an dich vergeben (Bankreserve).",
        AWARD_BANK_AUTO_FAILED = "|cffff5555[BananaLoot]|r %s ist Bankreserve, konnte aber nicht automatisch zugewiesen werden -- bitte manuell looten.",
        PRUNE_REMOVED = "|cffffcc00[BananaLoot]|r Reservierung(en) entfernt (nicht mehr im Raid): %s",

        -- Loot-Fenster
        LOOT_DETECTED_PREFIX = "|cff33ff99[BananaLoot]|r Loot erkannt: ",
        LOOT_SR_TAG = " |cffffcc00(SR: %d)|r",
        LOOT_HINT = "|cff33ff99[BananaLoot]|r Tippe |cffffff00/bl auto|r für automatischen Durchlauf, oder |cffffff00/bl loot|r für die Loot-Fensteransicht.",
        AUTO_SKIPPED_HR = "|cffffcc00[BananaLoot]|r Hard-Reserve-Items übersprungen (bitte manuell vergeben): %s",
        AUTO_ALL_DONE = "|cff33ff99[BananaLoot]|r Alle Items abgearbeitet.",
        AUTO_PAUSED = "|cffff5555[BananaLoot]|r Auto-Modus pausiert: bitte manuell im Loot-Fenster vergeben, dann /bl auto erneut tippen um fortzufahren.",

        -- Countdown
        COUNTDOWN_10 = "[BananaLoot] Roll endet in 10 Sekunden -- bitte bald abschließen!",
        COUNTDOWN_N = "[BananaLoot] Noch %d %s!",
        SECOND_SINGULAR = "Sekunde",
        SECOND_PLURAL = "Sekunden",

        -- Slash Commands
        CMD_RESET_DONE = "|cff33ff99BananaLoot|r: Alle aktuellen Reservierungen gelöscht (SR+ Werte bleiben erhalten).",
        CMD_WIPE_DONE = "|cff33ff99BananaLoot|r: Alle SR+ Werte komplett zurückgesetzt.",
        CMD_ARF_NEED_LINK = "|cffff5555BananaLoot|r: Bitte Item per Shift-Klick anhängen, z.B. /bl arf [Item].",
        CMD_SR_NEED_LINK = "|cffff5555BananaLoot|r: Bitte Item per Shift-Klick anhängen, z.B. /bl sr [Item].",
        CMD_SR_ADDED = "|cff33ff99BananaLoot|r: %s für dich selbst reserviert.",
        CMD_SR_ADD_FAIL = "|cffff5555BananaLoot|r: Reservierung fehlgeschlagen.",
        CMD_UNSR_REMOVED = "|cff33ff99BananaLoot|r: Deine Reservierung für %s wurde entfernt.",
        CMD_UNSR_NOT_RESERVED = "|cffff5555BananaLoot|r: Du hattest dieses Item nicht reserviert.",
        CMD_HR_REMOVED = "|cff33ff99BananaLoot|r: Hard Reserve entfernt.",
        CMD_HR_REMOVE_FAIL = "|cffff5555BananaLoot|r: Item nicht gefunden oder nicht auf Hard Reserve.",
        CMD_HR_ADDED = "|cff33ff99BananaLoot|r: %s als Hard Reserve hinterlegt.",
        CMD_HR_NEED_LINK = "|cffff5555BananaLoot|r: Bitte Item per Shift-Klick anhängen, z.B. /bl hr [Item].",
        CMD_BR_ADDED = "|cff33ff99BananaLoot|r: %s als Bankreserve hinterlegt.",
        CMD_BR_REMOVED = "|cff33ff99BananaLoot|r: Bankreserve entfernt.",
        CMD_BR_REMOVE_FAIL = "|cffff5555BananaLoot|r: Item nicht gefunden oder nicht auf Bankreserve.",
        CMD_BR_NEED_LINK = "|cffff5555BananaLoot|r: Bitte Item per Shift-Klick anhängen, z.B. /bl br [Item].",
        CMD_STOPPED = "|cff33ff99BananaLoot|r: Auto-Modus / aktiver Roll gestoppt.",
        CMD_LOG_CLEARED = "|cff33ff99BananaLoot|r: Loot-Log geleert.",
        CMD_LEGEND_TEXT = "=== SLASH-BEFEHLE (Loot-Master) ===\n" ..
            "/bl                    Fenster öffnen/schließen\n" ..
            "/bl loot               Loot-Fenster öffnen/schließen\n" ..
            "/bl auto               Automatischen Loot-Durchlauf starten\n" ..
            "/bl award              Letzten Roll-Gewinner vergeben\n" ..
            "/bl arf [Item]         Offener Roll für alle (SR ausgesetzt)\n" ..
            "/bl sr [Item]          Item für dich selbst reservieren (als Loot-Master)\n" ..
            "/bl unsr [Item]        Eigene Reservierung entfernen\n" ..
            "/bl stop               Auto-Modus / laufenden Roll abbrechen\n" ..
            "/bl reset              Alle aktuellen Reservierungen löschen\n" ..
            "/bl wipeplus           Alle SR+ Werte zurücksetzen\n" ..
            "/bl export             SR-Liste exportieren\n" ..
            "/bl import             SR-Liste importieren\n" ..
            "/bl csv                SR-Liste als CSV\n" ..
            "/bl csvlog             Loot-Log als CSV\n" ..
            "/bl clearlog           Loot-Log leeren\n" ..
            "/bl options            Einstellungen öffnen\n" ..
            "/bl hr [Item]          Item als Hard Reserve markieren\n" ..
            "/bl hr remove [Item]   Hard Reserve entfernen\n" ..
            "/bl hr                 Hard-Reserve-Liste anzeigen\n" ..
            "/bl br [Item]          Item als Bankreserve markieren (auto-vergeben)\n" ..
            "/bl br remove [Item]   Bankreserve entfernen\n" ..
            "/bl br                 Bankreserve-Liste anzeigen\n" ..
            "/bl recover            SR+-Wiederherstellungsliste anzeigen\n" ..
            "/bl history            Geteilte Loot-Historie anzeigen (nur Session)\n" ..
            "/bl lfm                LFM-Fenster öffnen (Text im Weltkanal posten)\n" ..
            "\n" ..
            "=== WHISPER-BEFEHLE (Spieler) ===\n" ..
            "sr [Item]              Item reservieren\n" ..
            "unsr [Item]            Reservierung entfernen\n" ..
            "srlist                 Eigene Reservierungen anzeigen\n" ..
            "hr / hrlist            Aktuelle Hard-Reserve-Items anzeigen\n" ..
            "\n" ..
            "=== ROLL-KATEGORIEN ===\n" ..
            "/roll                  Hauptspec (1-100)\n" ..
            "/roll 1 99             Off-Spec\n" ..
            "/roll 1 98             Transmog",

        CMD_HELP = "|cff33ff99BananaLoot|r Befehle: /bl, /bl loot, /bl auto, /bl award, /bl arf [Item], /bl sr [Item], /bl unsr [Item], /bl stop, /bl reset, /bl wipeplus, /bl export, /bl import, /bl csv, /bl csvlog, /bl clearlog, /bl options, /bl hr [Item], /bl hr remove [Item], /bl br [Item], /bl br remove [Item], /bl lfm",

        -- Optionen (Chat-Feedback)
        OPT_BONUS_SET = "|cff33ff99BananaLoot|r: SR+ Bonus pro Stufe auf +%d gesetzt.",
        OPT_BONUS_INVALID = "|cffff5555BananaLoot|r: Bitte eine gültige Zahl eingeben.",
        OPT_TIMEOUT_SET = "|cff33ff99BananaLoot|r: Roll-Timeout auf %d Sekunden gesetzt.",
        OPT_TIMEOUT_INVALID = "|cffff5555BananaLoot|r: Bitte eine gültige Zahl (mind. 5) eingeben.",
        OPT_COUNTDOWN_ON = "|cff33ff99BananaLoot|r: Chat-Countdown in den letzten Sekunden aktiviert.",
        OPT_COUNTDOWN_OFF = "|cff33ff99BananaLoot|r: Chat-Countdown deaktiviert.",
        OPT_LOOTPREVIEW_ON = "|cff33ff99BananaLoot|r: Loot-Vorschau im Raid-/Gruppenchat aktiviert.",
        OPT_LOOTPREVIEW_OFF = "|cff33ff99BananaLoot|r: Loot-Vorschau im Raid-/Gruppenchat deaktiviert.",
        OPT_LANGUAGE_SET = "|cff33ff99BananaLoot|r: Sprache umgestellt.",
        IMPORT_SUCCESS = "|cff33ff99BananaLoot|r: %d Item-Reservierung(en) und %d Hard-Reserve-Eintrag/Einträge importiert.",
        IMPORT_DROPPED_WARNING = "|cffffcc00BananaLoot|r: %d Reservierung(en) wegen des aktuellen SR-Limits (max. %d pro Spieler) beim Import verworfen.",
        WIN_IMPORT_RAIDRES_BTN = "raidres.top",
        IMPORT_RAIDRES_EMPTY = "|cffff5555BananaLoot|r: Bitte zuerst den Export-Text von raidres.top einfügen.",
        IMPORT_RAIDRES_BASE64_FAILED = "|cffff5555BananaLoot|r: Konnte den Text nicht als Base64 dekodieren. Bitte den kompletten Export-Text unverändert einfügen.",
        IMPORT_RAIDRES_JSON_FAILED = "|cffff5555BananaLoot|r: Konnte die dekodierten Daten nicht als JSON lesen. Bitte prüfen, ob der Export-Text vollständig kopiert wurde.",
        IMPORT_RAIDRES_NO_ENTRIES = "|cffff5555BananaLoot|r: Im Export wurden keine bekannten Felder gefunden. Das raidres.top-Format wird evtl. noch nicht korrekt erkannt -- bitte Rückmeldung geben, damit das angepasst werden kann.",
        IMPORT_RAIDRES_SUCCESS = "|cff33ff99BananaLoot|r: raidres.top-Import: %d Item-Reservierung(en) und %d Hard-Reserve-Eintrag/Einträge übernommen.",
        IMPORT_RAIDRES_UNMATCHED_WARNING = "|cffffcc00BananaLoot|r: Folgende importierte Namen wurden nicht im aktuellen Raid/der Gruppe gefunden (evtl. Tippfehler): %s",
        IMPORT_RAIDRES_HR_SKIPPED_WARNING = "|cffffcc00BananaLoot|r: %d Reservierung(en) wegen Hard Reserve übersprungen: %s",
        IMPORT_RAIDRES_SHOW_RAW = "Rohdaten anzeigen",
        IMPORT_FAIL = "|cffff5555BananaLoot|r: Import fehlgeschlagen - Text ungültig oder unvollständig kopiert.",
        IMPORT_OLD_WARNING = "|cffffcc00BananaLoot|r: Achtung - diese SR-Liste ist bereits %d Minute(n) alt. Möglicherweise wurden seitdem Items vergeben.",
        MANAGE_ADD_WARNING = "|cffffcc00BananaLoot|r: Hinweis - '%s' wurde hinzugefügt, ist aber aktuell nicht im Raid/der Gruppe. Bitte Schreibweise prüfen.",
        HR_REMOVED_LIST = "|cff33ff99BananaLoot|r: %s von Hard Reserve entfernt.",

        -- Hauptfenster (UI)
        UI_TITLE = "BananaLoot - SoftReserve / SR+",
        UI_TITLE_LOOT = "BananaLoot - Loot",
        UI_HINT = "Spieler reservieren per Whisper: |cffffff00sr [Item]|r  /  |cffffff00unsr [Item]|r",
        UI_BTN_OPEN_LOOT = "Loot-Fenster",
        UI_BTN_OPEN_LOOT_TOOLTIP = "Öffnet das separate Loot-Fenster (öffnet sich auch automatisch, sobald Loot verfügbar ist).",
        UI_BTN_NEW_RAID = "Neuer Raid",
        UI_BTN_WIPE = "SR+ komplett leeren",
        UI_BTN_EXPORT = "Export",
        UI_BTN_IMPORT = "Import",
        UI_BTN_SAVE_RAID = "Raid speichern",
        UI_BTN_LOAD_RAID = "Raid laden",
        UI_BTN_OPTIONS = "Optionen",
        UI_BTN_CSV_SR = "CSV: SR-Liste",
        UI_BTN_CSV_LOG = "CSV: Loot-Log",
        UI_BTN_CLEAR_LOG = "Log leeren",
        UI_POPUP_RESET_TEXT = "Alle aktuellen SR-Reservierungen löschen? (SR+ Werte bleiben erhalten)",
        UI_POPUP_YES = "Ja",
        UI_POPUP_CANCEL = "Abbrechen",
        UI_POPUP_WIPE_TEXT = "ALLE SR+ Werte ALLER Spieler unwiderruflich löschen? Das kann nicht rückgängig gemacht werden!",
        UI_POPUP_WIPE_YES = "Ja, komplett leeren",
        UI_OVERFLOW = "|cffff5555%d weitere Item(s) werden nicht angezeigt (Limit %d)|r",
        UI_BTN_MANAGE = "Verwalten",
        UI_BTN_ROLL = "Roll starten",
        UI_BTN_ARF = "ARF",
        UI_BTN_AWARD = "Vergeben",
        UI_TAG_HR = " |cffff5555[HR]|r",
        UI_TAG_SR = " |cffffcc00[SR]|r",
        UI_TAG_OPEN = " |cff88ff88[Offen]|r",
        UI_QTY = " |cff88ccff(x%d)|r",
        UI_NO_RESERVATIONS = "|cff888888(offen für alle -- noch keine Reservierungen)|r",
        UI_PLAYERS_MORE = " |cff888888(+%d weitere)|r",
        UI_STATUS_HR = "|cffff5555Hard Reserve -- nur manuelle Vergabe über \"Verwalten\"|r",
        UI_STATUS_WAITING = "Warte auf: %s",
        UI_STATUS_EVALUATING = "Werte aus...",
        UI_STATUS_OPEN_TIMEOUT = "Roll offen (kein festes Ende, siehe Timeout)",
        UI_STATUS_WINNER = "Gewinner (%s): %s (Wurf %d, Wertung %d)",
        UI_STATUS_NOBODY_ROLLED = "|cffff5555Niemand hat gerollt.|r",

        -- Optionsfenster
        OPT_BONUS_LABEL = "SR+ Bonus pro Stufe (Standard: 10):",
        OPT_SAVE_BTN = "Speichern",
        OPT_BONUS_HINT = "Beispiel: Wert 10 -> ein Spieler mit SR+2 bekommt +20 auf seinen Wurf.",
        OPT_TIMEOUT_LABEL = "Roll-Timeout in Sekunden (Standard: 60):",
        OPT_COUNTDOWN_LABEL = "Chat-Countdown aktivieren",
        OPT_COUNTDOWN_HINT = "Sagt bei 10, 5, 3, 2, 1 Sekunden im Raid-/Gruppenchat an, wie viel Zeit noch bleibt.",
        OPT_LOOTPREVIEW_LABEL = "Loot-Vorschau im Raid-/Gruppenchat",
        OPT_LOOTPREVIEW_HINT = "Postet beim Öffnen eines neuen Loot-Fensters einmalig eine Übersicht aller Items im Raid-/Gruppenchat, BEVOR gerollt wird (mit SR-Reservierern, Hard Reserve oder \"frei für alle\"). Bankreserve-Items werden dabei nie angezeigt.",
        OPT_LANGUAGE_LABEL = "Sprache der Chat- und UI-Ausgaben:",
        OPT_UNKNOWN_REPLY_LABEL = "Rückantwort bei unbekanntem Whisper-Befehl",
        OPT_UNKNOWN_REPLY_HINT = "Betrifft nur die Standardmeldung bei nicht erkannten Whispers (z.B. außerhalb des Raids). SR/unSR/srlist/hr-Antworten bleiben davon unberührt.",
        OPT_UNKNOWN_REPLY_ON = "|cff33ff99BananaLoot|r: Rückantwort bei unbekanntem Befehl aktiviert.",
        OPT_UNKNOWN_REPLY_OFF = "|cff33ff99BananaLoot|r: Rückantwort bei unbekanntem Befehl deaktiviert.",
        OPT_MANAGE_LABEL = "Verwaltung (selten benötigt)",
        OPT_TAB_GENERAL = "Allgemein",
        OPT_TAB_AUTOMATION = "Automatik",
        OPT_TAB_NETWORK = "Netzwerk",
        OPT_TAB_DISPLAY = "Anzeige & Sound",
        OPT_TAB_MANAGE = "Verwaltung",
        OPT_SCALE_LABEL = "SR-Fenster-Skalierung in % (Standard: 100):",
        OPT_SCALE_HINT = "Verkleinert oder vergrößert das SR-Fenster, z.B. 70-90 auf kleinen Bildschirmen (z.B. 14 Zoll). Bereich: 50-150.",
        OPT_SCALE_SET = "|cff33ff99BananaLoot|r: SR-Fenster-Skalierung auf %d%% gesetzt.",
        OPT_SCALE_INVALID = "|cffff5555BananaLoot|r: Bitte einen Wert zwischen 50 und 150 eingeben.",
        OPT_LOOT_SCALE_LABEL = "Loot-Fenster-Skalierung in % (Standard: 100):",
        OPT_LOOT_SCALE_HINT = "Verkleinert oder vergrößert das separate Loot-Fenster, unabhängig von der SR-Fenster-Skalierung oben. Bereich: 50-150.",
        OPT_LOOT_SCALE_SET = "|cff33ff99BananaLoot|r: Loot-Fenster-Skalierung auf %d%% gesetzt.",
        OPT_LOOT_SCALE_INVALID = "|cffff5555BananaLoot|r: Bitte einen Wert zwischen 50 und 150 eingeben.",
        OPT_MAXSR_LABEL = "Maximale Anzahl SR pro Spieler (Standard: 1, Bereich 1-4):",
        OPT_MAXSR_SET = "|cff33ff99BananaLoot|r: Maximale Anzahl SR pro Spieler auf %d gesetzt.",
        OPT_MAXSR_INVALID = "|cffff5555BananaLoot|r: Bitte einen Wert zwischen 1 und 4 eingeben.",
        OPT_MAXSR_HINT = "Bei 1 verhält sich BananaLoot wie gewohnt (neues SR ersetzt automatisch das alte). Bei 2-4 können Spieler mehrere Items gleichzeitig reservieren; ist das Limit erreicht, muss zuerst 'unsr [Item]' geschickt werden.",
        OPT_AUTOML_LABEL = "Automatisches Masterloot beim Anvisieren eines Bosses",
        OPT_AUTOML_HINT = "Wechselt automatisch auf Masterloot, sobald du einen bekannten Raid-Boss anvisierst (nur als Gruppen-/Raidleiter wirksam). Schaltet NIE automatisch zurück auf Gruppenloot -- das bleibt manuell über den ML/GL-Button.",
        OPT_ROLLSYNC_LABEL = "Roll-Sync mit anderen BananaLoot-Nutzern",
        OPT_ROLLSYNC_HINT = "Sendet den Roll-Fortschritt (Start, eingehende Würfe, Gewinner) per Addon-Nachricht an Raid-/Gruppenmitglieder, die ebenfalls BananaLoot nutzen. Empfänger sehen ein kleines Popup-Fenster mit Stand/Countdown und können direkt darin würfeln; im Chat erscheint zusätzlich eine Debug-Zeile (|cff33ccff[BL-Sync]|r).",
        OPT_ROLLSYNC_SENDER_LABEL = "Popup auch beim Senden (als Loot-Master) anzeigen",
        OPT_MULTIWINNER_LABEL = "Mehrfachdrops: Top N gewinnen",
        OPT_MULTIWINNER_HINT = "Liegen mehrere Kopien desselben Items im Loot-Fenster (N Stück), gewinnen die besten N Werfer je eine Kopie in einem gemeinsamen Roll, statt jede Kopie einzeln nacheinander zu verrollen.",
        OPT_TRADETRACKING_LABEL = "Trade-Tracking (automatisch)",
        OPT_TRADETRACKING_HINT = "Erkennt automatisch, wenn ein über BananaLoot vergebenes Item per Handel weitergegeben wird, und ergänzt den Loot-Log-Eintrag um den neuen Besitzer (siehe /bl csvlog, Spalte \"Weitergegeben an\"). Erkennung erfolgt im eigenen Handelsfenster; ein Trade zwischen zwei anderen Spielern ist nur sichtbar, wenn einer von beiden diese Option ebenfalls aktiviert hat.",
        TRADE_DETECTED = "|cff33ccff[BananaLoot]|r Weitergabe erkannt: %s -- %s an %s.",

        -- Roll-Sync-Popup (Client-Fenster für eingehende Rolls)
        RSWIN_TITLE = "BananaLoot - Roll",
        RSWIN_MODE_SR = "SR",
        RSWIN_MODE_OPEN = "Offen",
        RSWIN_MODE_ARF = "ARF",
        RSWIN_TIME_LEFT = "Noch %d Sekunden",
        RSWIN_TIE = "|cffffcc00Gleichstand -- bitte erneut rollen!|r",
        RSWIN_WINNER = "Gewinner: %s (Wurf %d, Wertung %d)",
        RSWIN_NO_ROLLS = "|cff888888(noch keine Würfe)|r",
        RSWIN_MS_BTN = "MS",
        RSWIN_OS_BTN = "OS",
        RSWIN_TM_BTN = "TM",
        RSWIN_OVERFLOW = "|cffff5555%d weitere|r",

        -- Geteilte Loot-Historie (/bl history) -- nur für die aktuelle
        -- Session, wird nicht gespeichert.
        WIN_HISTORY_TITLE = "Loot-Historie",
        WIN_HISTORY_HINT = "Nur für diese Session -- wird nicht gespeichert. Bankreserve-Vergaben erscheinen hier bewusst nicht (bleiben lautlos, siehe Bankreserve).",
        HISTORY_EMPTY = "|cff888888(noch keine Vergaben in dieser Session)|r",
        HISTORY_OVERFLOW = "|cffff5555%d ältere Einträge werden nicht angezeigt|r",
        UI_BTN_RECOVERY = "SR+ Wiederherstellung",
        UI_BTN_RECOVERY_TOOLTIP = "Zuletzt durch eine neue Reservierung verdrängte SR+ Werte einsehen und wiederherstellen.",
        WIN_RECOVERY_TITLE = "SR+ Wiederherstellung",
        WIN_RECOVERY_HINT = "Zeigt je Spieler die zuletzt verdrängte Reservierung (durch neues SR oder Import überschrieben).",
        RECOVERY_EMPTY = "|cff888888(keine überschriebenen Reservierungen vorhanden)|r",
        RECOVERY_RESTORE_BTN = "Wiederherstellen",
        RECOVERY_RESTORED_MSG = "|cff33ff99BananaLoot|r: Reservierung für %s wiederhergestellt (%s, SR+ %d).",
        RECOVERY_RESTORE_FAILED = "|cffff5555BananaLoot|r: Wiederherstellung fehlgeschlagen (Spieler hat evtl. bereits das SR-Limit erreicht).",

        -- Sound-Feedback (optional, standardmäßig an)
        OPT_SOUND_LABEL = "Sound",
        OPT_SOUND_MASTER_LABEL = "Sounds aktivieren (Hauptschalter)",
        OPT_SOUND_LOOT_LABEL = "Loot erkannt",
        OPT_SOUND_ROLL_LABEL = "Roll gestartet",
        OPT_SOUND_WINNER_LABEL = "Gewinner ermittelt",
        OPT_SOUND_AWARD_LABEL = "Item vergeben",
        OPT_SOUND_CLICK_LABEL = "Klick-Sound auf allen Buttons",

        -- Export/Import/CSV-Fenster
        WIN_EXPORT_TITLE = "SR-Liste exportieren",
        WIN_EXPORT_HINT = "Strg+A, Strg+C zum Kopieren - dann deiner Vertretung schicken",
        WIN_IMPORT_TITLE = "SR-Liste importieren",
        WIN_IMPORT_HINT = "Text hier einfügen (Strg+V), dann Importieren klicken",
        WIN_IMPORT_BTN = "Importieren",
        WIN_CSV_SR_TITLE = "SR-Liste als CSV (für Google Sheets)",
        WIN_CSV_HINT = "Strg+A, Strg+C - dann in eine leere Google-Sheets-Zelle einfügen (Strg+V)",
        WIN_CSV_LOG_TITLE = "Loot-Log als CSV (für Google Sheets)",

        -- Verwalten-Fenster
        WIN_MANAGE_TITLE = "SR-Liste verwalten",
        MG_POPUP_TEXT = "%s als Gewinner setzen und das Item sofort vergeben?",
        MG_NONE = "|cff888888(keine Reservierungen)|r",
        MG_REMOVE_BTN = "Entfernen",
        MG_WIN_BTN = "Gewinner",
        MG_OVERFLOW = "|cffff5555%d weitere Spieler werden nicht angezeigt (Limit %d)|r",
        MG_ADD_LABEL = "Spieler manuell hinzufügen (genaue Schreibweise):",
        MG_ADD_BTN = "Hinzufügen",
        MG_REMOVE_ITEM_BTN = "Item komplett entfernen",
        MG_REMOVE_RESERVATION_BTN = "Reservierung löschen",
        MG_SKIP_DROP_BTN = "Drop überspringen",
        MG_HR_TAG = " |cffff5555(Hard Reserve)|r",

        -- Hard-Reserve-Fenster
        WIN_HR_TITLE = "Hard Reserve Items",
        WIN_HR_HINT = "Hinzufügen per /bl hr [Item] (Shift-Klick anhängen)",
        HR_REMOVE_BTN = "Entfernen",
        HR_EMPTY = "|cff888888(keine Hard-Reserve-Items)|r",
        HR_OVERFLOW = "|cffff5555%d weitere Item(s) werden nicht angezeigt|r",

        -- Bankreserve-Fenster
        WIN_BR_TITLE = "Bankreserve-Items",
        WIN_BR_HINT = "Hinzufügen per /bl br [Item] (Shift-Klick anhängen). Diese Items werden beim Looten automatisch und lautlos an dich vergeben -- kein Roll, keine Ankündigung.",
        BR_REMOVE_BTN = "Entfernen",
        BR_EMPTY = "|cff888888(keine Bankreserve-Items)|r",
        BR_OVERFLOW = "|cffff5555%d weitere Item(s) werden nicht angezeigt|r",
        UI_BTN_HR_TOOLTIP = "Hard-Reserve-Liste anzeigen",
        UI_BTN_BR_TOOLTIP = "Bankreserve-Liste anzeigen",

        -- LFM-Fenster
        WIN_LFM_TITLE = "LFM - Suche Mitspieler",
        LFM_TEXT_LABEL = "Text (wird im Weltkanal gepostet):",
        LFM_INTERVAL_LABEL = "Abstand in Minuten (min. 1):",
        LFM_BTN_START = "Starten",
        LFM_BTN_STOP = "Stoppen",
        LFM_STARTED = "|cff33ff99BananaLoot|r: LFM gestartet -- postet alle %d Minute(n) im Weltkanal.",
        LFM_STOPPED = "|cff33ff99BananaLoot|r: LFM gestoppt.",
        LFM_NEED_TEXT = "|cffff5555BananaLoot|r: Bitte zuerst einen Text eingeben.",
        LFM_INTERVAL_INVALID = "|cffff5555BananaLoot|r: Bitte einen Wert von mindestens %d Minute(n) eingeben.",
        LFM_CHANNEL_NOT_FOUND = "|cffff5555[BananaLoot]|r LFM: Kein Weltkanal (z.B. /4) gefunden/gejoint -- Post übersprungen.",
        LFM_STATUS_RUNNING = "Aktiv -- nächster Post in %d Sekunden",
        LFM_STATUS_STOPPED = "Gestoppt",
        UI_BTN_LFM_TOOLTIP = "LFM-Fenster öffnen (postet einen Text in regelmäßigen Abständen im Weltkanal)",

        -- Raid speichern/laden
        WIN_SAVE_RAID_TITLE = "Raid speichern",
        WIN_SAVE_RAID_HINT = "Speichert die aktuellen Reservierungen, SR+ Werte und die SR+-Wiederherstellungsliste unter diesem Namen (Hard Reserve/Bankreserve bleiben unabhängig davon bestehen). Ein bereits vorhandener Name wird nach Rückfrage überschrieben.",
        SAVE_RAID_NAME_LABEL = "Name:",
        SAVE_RAID_BTN = "Speichern",
        SAVE_RAID_NEED_NAME = "|cffff5555BananaLoot|r: Bitte einen Namen eingeben.",
        SAVE_RAID_DONE = "|cff33ff99BananaLoot|r: Raid '%s' gespeichert.",
        WIN_LOAD_RAID_TITLE = "Raid laden",
        WIN_LOAD_RAID_HINT = "Achtung: Lädt die gespeicherten Reservierungen und SR+ Werte und ersetzt damit den aktuellen Stand.",
        LOAD_RAID_BTN = "Laden",
        LOAD_RAID_DELETE_BTN = "Löschen",
        LOAD_RAID_EMPTY = "|cff888888(keine gespeicherten Raids vorhanden)|r",
        LOAD_RAID_OVERFLOW = "|cffff5555%d weitere Eintrag/Einträge werden nicht angezeigt|r",
        LOAD_RAID_DONE = "|cff33ff99BananaLoot|r: Raid '%s' geladen.",
        DELETE_RAID_DONE = "|cff33ff99BananaLoot|r: Gespeicherter Raid '%s' gelöscht.",
        UI_POPUP_OVERWRITE_RAID_TEXT = "Ein gespeicherter Raid namens '%s' existiert bereits. Überschreiben?",
        UI_POPUP_LOAD_RAID_TEXT = "Raid '%s' laden? Die aktuellen Reservierungen und SR+ Werte werden dabei ersetzt.",
        UI_POPUP_DELETE_RAID_TEXT = "Gespeicherten Raid '%s' endgültig löschen?",

        -- Minimap
        MM_TOOLTIP_LEFT = "Linksklick: Fenster öffnen",
        MM_TOOLTIP_RIGHT = "Rechtsklick: Einstellungen",
        MM_TOOLTIP_DRAG = "Ziehen: Position am Minimap-Rand ändern",
        MM_TOOLTIP_SR_HEADER = "Aktuelle SR-Reservierungen:",
        MM_TOOLTIP_SR_MORE = "... und %d weitere",
    },

    en = {
        MSG_ADDON_LOADED = "|cff33ff99BananaLoot|r loaded. /bl opens the window, /bl auto starts the automatic loot run.",
        WHISPER_SR_NEED_LINK = "BananaLoot: Please shift-click the item into the whisper (e.g. \"sr [Item]\").",
        WHISPER_SR_RESERVED = "BananaLoot: %s has been reserved for you.",
        WHISPER_SR_BONUS_SUFFIX = " (your SR+ bonus: +%d)",
        WHISPER_SR_SWAP_SUFFIX = " Note: your previous reservation was replaced, its SR+ bonus is lost.",
        WHISPER_SR_HARD_RESERVE = "BananaLoot: %s is Hard Reserve and will be awarded manually. Please SR a different item.",
        WHISPER_SR_LIMIT_REACHED = "BananaLoot: You have already reached the maximum number of reservations (%d). Please remove one first with 'unsr [Item]'.",
        WHISPER_SR_UNKNOWN_ITEM = "BananaLoot: Could not recognize the item, please try again.",
        WHISPER_UNSR_NEED_LINK = "BananaLoot: Please shift-click the item to remove it.",
        WHISPER_UNSR_REMOVED = "BananaLoot: Your reservation for %s has been removed.",
        WHISPER_UNSR_NOT_RESERVED = "BananaLoot: You hadn't reserved this item.",
        WHISPER_UNKNOWN_COMMAND = "BananaLoot: Command not recognized. Use 'sr [Item]', 'unsr [Item]', 'srlist', or 'hr'.",
        WHISPER_LIST_ENTRY = "BananaLoot: %s",
        WHISPER_LIST_BONUS_SUFFIX = " -- SR+ bonus: +%d",
        WHISPER_LIST_EMPTY = "BananaLoot: You currently have no reservations.",
        WHISPER_LIST_OTHERS_PREFIX = "BananaLoot: Also SR'd: %s",
        WHISPER_HR_ENTRY = "BananaLoot: %s is Hard Reserve.",
        WHISPER_HR_EMPTY = "BananaLoot: There are currently no items on Hard Reserve.",
        WHISPER_SR_LOCKED = "BananaLoot: The SR list is locked for this raid. Please contact the loot master directly.",
        SR_LOCK_ON = "|cff33ff99BananaLoot|r: SR list locked -- whisper reservations (sr/unsr) are disabled.",
        SR_LOCK_OFF = "|cff33ff99BananaLoot|r: SR list unlocked -- whisper reservations (sr/unsr) are possible again.",
        UI_BTN_LOCK_TOOLTIP_LOCKED = "SR list is locked (whisper reservations disabled). Click to unlock.",
        UI_BTN_LOCK_TOOLTIP_UNLOCKED = "SR list is open (whisper reservations active). Click to lock.",
        UI_BTN_LOCK_LOCKED = "Locked",
        UI_BTN_LOCK_UNLOCKED = "Open",
        UI_BTN_LOOTMETHOD_TOOLTIP = "Switches between Group Loot (GL) and Master Loot (ML, you). Only works if you're the party/raid leader.",
        UI_BTN_AUTO_ON = "Auto: On",
        UI_BTN_AUTO_OFF = "Auto: Off",
        UI_BTN_AUTO_TOOLTIP = "Starts/pauses the automatic loot run (same as /bl auto). Turning it off does NOT cancel an already active roll -- use /bl stop for that.",
        UI_BTN_STOP = "Stop",
        UI_BTN_STOP_TOOLTIP = "Immediately cancels auto mode AND an active roll (same as /bl stop).",
        WHISPER_SR_BANK_RESERVE = "BananaLoot: %s is Bank Reserve and will be awarded automatically. Please SR a different item.",

        ROLL_HOWTO = "/roll = Main Spec, /roll 1 99 = Off-Spec, /roll 1 98 = Transmog",
        ROLL_ANNOUNCE_SR = "[BananaLoot] SR roll for %s -- %s-- %s",
        ROLL_ANNOUNCE_ARF = "[BananaLoot] ARF: Roll for %s -- SR suspended, open to everyone -- %s",
        ROLL_ANNOUNCE_OPEN = "[BananaLoot] Roll for %s -- open to everyone -- %s",
        ROLL_HARD_RESERVE_BLOCKED = "|cffff5555[BananaLoot]|r This item is Hard Reserve and will not be rolled -- please award it manually in the \"Manage\" window.",
        ROLL_BANK_RESERVE_BLOCKED = "|cffff5555[BananaLoot]|r This item is Bank Reserve and will not be rolled -- it will be awarded automatically.",
        ROLL_NOBODY_ROLLED = "|cffff5555[BananaLoot]|r Nobody rolled for %s.",
        ROLL_NOBODY_ROLLED_REST = "|cffffcc00[BananaLoot]|r Nobody rolled for the remaining slot(s) of %s -- winners already determined stay valid.",
        ROLL_TIE = "[BananaLoot] Tie (%s) at %d! %s-- please roll again (same category)!",
        ROLL_WINNER_CHAT = "|cff33ff99[BananaLoot]|r Winner (%s) for %s: %s (roll %d, score %d)",
        ROLL_WINNER_ANNOUNCE = "[BananaLoot] %s wins %s (%s)!",
        ROLL_WINNERS_ANNOUNCE = "[BananaLoot] %s -- %s: %s share the win!",
        ROLL_SLOTS_SUFFIX = " |cff88ccff(%d copies -- top rolls win)|r",
        POOL_MS = "Main Spec",
        POOL_OS = "Off-Spec",
        POOL_TMOG = "Transmog",
        POOL_MANUAL = "Manual",
        POOL_BANK = "Bank Reserve",
        POOL_RAIDROLL = "Raid Roll",
        RAID_ROLL_ANNOUNCE = "[BananaLoot] %s -- Awarded via random raid roll to: %s",
        MG_RAIDROLL_BTN = "Raid Roll",
        MG_RAIDROLL_POPUP_TEXT = "Award %s via random roll among the entire raid (no SR needed, players don't have to roll themselves)?",
        UI_BTN_HELP_TOOLTIP = "Show command legend",
        WIN_HELP_TITLE = "Command Legend",
        WIN_HELP_HINT = "Ctrl+A, Ctrl+C to copy",

        AWARD_ASSIGNED = "|cff33ff99[BananaLoot]|r %s -> %s (auto-assigned)",
        AWARD_NOT_ASSIGNED = "|cff33ff99[BananaLoot]|r %s -> %s |cffff5555(please assign manually in the loot window!)|r",
        AWARD_FAIL_NOLOOT = "|cffff5555[BananaLoot]|r %s -> %s: loot window is closed. Re-open the corpse, the award will be retried automatically.",
        AWARD_FAIL_NOCAND = "|cffff5555[BananaLoot]|r %s -> %s: player is not in the master loot candidate list (out of range, different zone, released spirit or offline). Please assign manually.",
        AWARD_PENDING_DONE = "|cff33ff99[BananaLoot]|r %s -> %s assigned (retry).",
        AWARD_PENDING_DROPPED = "|cffff5555[BananaLoot]|r %s -> %s: pending award dropped, item is no longer in this loot window. Please assign manually.",
        LOOT_CLOSED_WARN = "|cffffcc00[BananaLoot]|r Loot window closed. Nothing can be awarded while it is closed.",
        AWARD_NO_WINNER = "|cffff5555[BananaLoot]|r No completed roll available.",
        AWARD_BANK_AUTO = "|cff33ff99[BananaLoot]|r %s automatically awarded to you (Bank Reserve).",
        AWARD_BANK_AUTO_FAILED = "|cffff5555[BananaLoot]|r %s is Bank Reserve, but could not be auto-assigned -- please loot it manually.",
        PRUNE_REMOVED = "|cffffcc00[BananaLoot]|r Reservation(s) removed (no longer in raid): %s",

        LOOT_DETECTED_PREFIX = "|cff33ff99[BananaLoot]|r Loot detected: ",
        LOOT_SR_TAG = " |cffffcc00(SR: %d)|r",
        LOOT_HINT = "|cff33ff99[BananaLoot]|r Type |cffffff00/bl auto|r for an automatic run, or |cffffff00/bl loot|r for the loot window view.",
        AUTO_SKIPPED_HR = "|cffffcc00[BananaLoot]|r Hard Reserve items skipped (please award manually): %s",
        AUTO_ALL_DONE = "|cff33ff99[BananaLoot]|r All items processed.",
        AUTO_PAUSED = "|cffff5555[BananaLoot]|r Auto mode paused: please award manually in the loot window, then type /bl auto again to continue.",

        COUNTDOWN_10 = "[BananaLoot] Roll ends in 10 seconds -- please wrap it up!",
        COUNTDOWN_N = "[BananaLoot] %d %s left!",
        SECOND_SINGULAR = "second",
        SECOND_PLURAL = "seconds",

        CMD_RESET_DONE = "|cff33ff99BananaLoot|r: All current reservations cleared (SR+ values are kept).",
        CMD_WIPE_DONE = "|cff33ff99BananaLoot|r: All SR+ values have been completely reset.",
        CMD_ARF_NEED_LINK = "|cffff5555BananaLoot|r: Please shift-click an item, e.g. /bl arf [Item].",
        CMD_SR_NEED_LINK = "|cffff5555BananaLoot|r: Please shift-click an item, e.g. /bl sr [Item].",
        CMD_SR_ADDED = "|cff33ff99BananaLoot|r: %s reserved for yourself.",
        CMD_SR_ADD_FAIL = "|cffff5555BananaLoot|r: Reservation failed.",
        CMD_UNSR_REMOVED = "|cff33ff99BananaLoot|r: Your reservation for %s has been removed.",
        CMD_UNSR_NOT_RESERVED = "|cffff5555BananaLoot|r: You hadn't reserved this item.",
        CMD_HR_REMOVED = "|cff33ff99BananaLoot|r: Hard Reserve removed.",
        CMD_HR_REMOVE_FAIL = "|cffff5555BananaLoot|r: Item not found or not on Hard Reserve.",
        CMD_HR_ADDED = "|cff33ff99BananaLoot|r: %s marked as Hard Reserve.",
        CMD_HR_NEED_LINK = "|cffff5555BananaLoot|r: Please shift-click an item, e.g. /bl hr [Item].",
        CMD_BR_ADDED = "|cff33ff99BananaLoot|r: %s marked as Bank Reserve.",
        CMD_BR_REMOVED = "|cff33ff99BananaLoot|r: Bank Reserve removed.",
        CMD_BR_REMOVE_FAIL = "|cffff5555BananaLoot|r: Item not found or not on Bank Reserve.",
        CMD_BR_NEED_LINK = "|cffff5555BananaLoot|r: Please shift-click an item, e.g. /bl br [Item].",
        CMD_STOPPED = "|cff33ff99BananaLoot|r: Auto mode / active roll stopped.",
        CMD_LOG_CLEARED = "|cff33ff99BananaLoot|r: Loot log cleared.",
        CMD_LEGEND_TEXT = "=== SLASH COMMANDS (Loot Master) ===\n" ..
            "/bl                    Open/close the window\n" ..
            "/bl loot               Open/close the loot window\n" ..
            "/bl auto               Start the automatic loot run\n" ..
            "/bl award              Award the last roll winner\n" ..
            "/bl arf [Item]         Open roll for everyone (SR suspended)\n" ..
            "/bl sr [Item]          Reserve item for yourself (as loot master)\n" ..
            "/bl unsr [Item]        Remove your own reservation\n" ..
            "/bl stop               Stop auto mode / active roll\n" ..
            "/bl reset              Clear all current reservations\n" ..
            "/bl wipeplus           Reset all SR+ values\n" ..
            "/bl export             Export SR list\n" ..
            "/bl import             Import SR list\n" ..
            "/bl csv                SR list as CSV\n" ..
            "/bl csvlog             Loot log as CSV\n" ..
            "/bl clearlog           Clear loot log\n" ..
            "/bl options            Open settings\n" ..
            "/bl hr [Item]          Mark item as Hard Reserve\n" ..
            "/bl hr remove [Item]   Remove Hard Reserve\n" ..
            "/bl hr                 Show Hard Reserve list\n" ..
            "/bl br [Item]          Mark item as Bank Reserve (auto-awarded)\n" ..
            "/bl br remove [Item]   Remove Bank Reserve\n" ..
            "/bl br                 Show Bank Reserve list\n" ..
            "/bl recover            Show SR+ recovery list\n" ..
            "/bl history            Show shared loot history (session only)\n" ..
            "/bl lfm                Open the LFM window (post a text in the World channel)\n" ..
            "\n" ..
            "=== WHISPER COMMANDS (Players) ===\n" ..
            "sr [Item]              Reserve item\n" ..
            "unsr [Item]            Remove reservation\n" ..
            "srlist                 Show your own reservations\n" ..
            "hr / hrlist            Show current Hard Reserve items\n" ..
            "\n" ..
            "=== ROLL CATEGORIES ===\n" ..
            "/roll                  Main Spec (1-100)\n" ..
            "/roll 1 99             Off-Spec\n" ..
            "/roll 1 98             Transmog",

        CMD_HELP = "|cff33ff99BananaLoot|r Commands: /bl, /bl loot, /bl auto, /bl award, /bl arf [Item], /bl sr [Item], /bl unsr [Item], /bl stop, /bl reset, /bl wipeplus, /bl export, /bl import, /bl csv, /bl csvlog, /bl clearlog, /bl options, /bl hr [Item], /bl hr remove [Item], /bl br [Item], /bl br remove [Item], /bl lfm",

        OPT_BONUS_SET = "|cff33ff99BananaLoot|r: SR+ bonus per stack set to +%d.",
        OPT_BONUS_INVALID = "|cffff5555BananaLoot|r: Please enter a valid number.",
        OPT_TIMEOUT_SET = "|cff33ff99BananaLoot|r: Roll timeout set to %d seconds.",
        OPT_TIMEOUT_INVALID = "|cffff5555BananaLoot|r: Please enter a valid number (min. 5).",
        OPT_COUNTDOWN_ON = "|cff33ff99BananaLoot|r: Chat countdown in the final seconds enabled.",
        OPT_COUNTDOWN_OFF = "|cff33ff99BananaLoot|r: Chat countdown disabled.",
        OPT_LOOTPREVIEW_ON = "|cff33ff99BananaLoot|r: Loot preview in raid/party chat enabled.",
        OPT_LOOTPREVIEW_OFF = "|cff33ff99BananaLoot|r: Loot preview in raid/party chat disabled.",
        OPT_LANGUAGE_SET = "|cff33ff99BananaLoot|r: Language switched.",
        IMPORT_SUCCESS = "|cff33ff99BananaLoot|r: Imported %d item reservation(s) and %d Hard Reserve entr(y/ies).",
        IMPORT_DROPPED_WARNING = "|cffffcc00BananaLoot|r: %d reservation(s) were dropped during import due to the current SR limit (max. %d per player).",
        WIN_IMPORT_RAIDRES_BTN = "raidres.top",
        IMPORT_RAIDRES_EMPTY = "|cffff5555BananaLoot|r: Please paste the raidres.top export text first.",
        IMPORT_RAIDRES_BASE64_FAILED = "|cffff5555BananaLoot|r: Could not decode the text as Base64. Please paste the full export text unmodified.",
        IMPORT_RAIDRES_JSON_FAILED = "|cffff5555BananaLoot|r: Could not read the decoded data as JSON. Please check that the export text was copied in full.",
        IMPORT_RAIDRES_NO_ENTRIES = "|cffff5555BananaLoot|r: No known fields were found in the export. The raidres.top format may not be fully recognized yet -- please report this so it can be adjusted.",
        IMPORT_RAIDRES_SUCCESS = "|cff33ff99BananaLoot|r: raidres.top import: %d item reservation(s) and %d Hard Reserve entr(y/ies) applied.",
        IMPORT_RAIDRES_UNMATCHED_WARNING = "|cffffcc00BananaLoot|r: The following imported names were not found in the current raid/group (possible typos): %s",
        IMPORT_RAIDRES_HR_SKIPPED_WARNING = "|cffffcc00BananaLoot|r: %d reservation(s) skipped due to Hard Reserve: %s",
        IMPORT_RAIDRES_SHOW_RAW = "Show raw data",
        IMPORT_FAIL = "|cffff5555BananaLoot|r: Import failed - text invalid or copied incompletely.",
        IMPORT_OLD_WARNING = "|cffffcc00BananaLoot|r: Note - this SR list is already %d minute(s) old. Items may have been awarded since then.",
        MANAGE_ADD_WARNING = "|cffffcc00BananaLoot|r: Note - '%s' was added but is not currently in the raid/group. Please check the spelling.",
        HR_REMOVED_LIST = "|cff33ff99BananaLoot|r: %s removed from Hard Reserve.",

        UI_TITLE = "BananaLoot - SoftReserve / SR+",
        UI_TITLE_LOOT = "BananaLoot - Loot",
        UI_HINT = "Players reserve via whisper: |cffffff00sr [Item]|r  /  |cffffff00unsr [Item]|r",
        UI_BTN_OPEN_LOOT = "Loot Window",
        UI_BTN_OPEN_LOOT_TOOLTIP = "Opens the separate loot window (also opens automatically once loot is available).",
        UI_BTN_NEW_RAID = "New Raid",
        UI_BTN_WIPE = "Clear all SR+",
        UI_BTN_EXPORT = "Export",
        UI_BTN_IMPORT = "Import",
        UI_BTN_SAVE_RAID = "Save Raid",
        UI_BTN_LOAD_RAID = "Load Raid",
        UI_BTN_OPTIONS = "Options",
        UI_BTN_CSV_SR = "CSV: SR List",
        UI_BTN_CSV_LOG = "CSV: Loot Log",
        UI_BTN_CLEAR_LOG = "Clear Log",
        UI_POPUP_RESET_TEXT = "Clear all current SR reservations? (SR+ values are kept)",
        UI_POPUP_YES = "Yes",
        UI_POPUP_CANCEL = "Cancel",
        UI_POPUP_WIPE_TEXT = "Permanently delete ALL SR+ values of ALL players? This cannot be undone!",
        UI_POPUP_WIPE_YES = "Yes, clear everything",
        UI_OVERFLOW = "|cffff5555%d more item(s) not shown (limit %d)|r",
        UI_BTN_MANAGE = "Manage",
        UI_BTN_ROLL = "Start Roll",
        UI_BTN_ARF = "ARF",
        UI_BTN_AWARD = "Award",
        UI_TAG_HR = " |cffff5555[HR]|r",
        UI_TAG_SR = " |cffffcc00[SR]|r",
        UI_TAG_OPEN = " |cff88ff88[Open]|r",
        UI_QTY = " |cff88ccff(x%d)|r",
        UI_NO_RESERVATIONS = "|cff888888(open to everyone -- no reservations yet)|r",
        UI_PLAYERS_MORE = " |cff888888(+%d more)|r",
        UI_STATUS_HR = "|cffff5555Hard Reserve -- manual award only via \"Manage\"|r",
        UI_STATUS_WAITING = "Waiting for: %s",
        UI_STATUS_EVALUATING = "Evaluating...",
        UI_STATUS_OPEN_TIMEOUT = "Roll open (no fixed end, see timeout)",
        UI_STATUS_WINNER = "Winner (%s): %s (roll %d, score %d)",
        UI_STATUS_NOBODY_ROLLED = "|cffff5555Nobody rolled.|r",

        OPT_BONUS_LABEL = "SR+ bonus per stack (default: 10):",
        OPT_SAVE_BTN = "Save",
        OPT_BONUS_HINT = "Example: value 10 -> a player with SR+2 gets +20 on their roll.",
        OPT_TIMEOUT_LABEL = "Roll timeout in seconds (default: 60):",
        OPT_COUNTDOWN_LABEL = "Enable chat countdown",
        OPT_COUNTDOWN_HINT = "Announces remaining time at 10, 5, 3, 2, 1 seconds in raid/party chat.",
        OPT_LOOTPREVIEW_LABEL = "Loot preview in raid/party chat",
        OPT_LOOTPREVIEW_HINT = "Posts an overview of all items in raid/party chat once, right when a new loot window is opened, BEFORE any rolling starts (with SR reservers, Hard Reserve, or \"open to everyone\"). Bank Reserve items are never shown here.",
        OPT_LANGUAGE_LABEL = "Chat and UI language:",
        OPT_UNKNOWN_REPLY_LABEL = "Reply on unrecognized whisper command",
        OPT_UNKNOWN_REPLY_HINT = "Only affects the default reply for unrecognized whispers (e.g. outside of a raid). SR/unSR/srlist/hr replies are unaffected.",
        OPT_UNKNOWN_REPLY_ON = "|cff33ff99BananaLoot|r: Reply on unrecognized command enabled.",
        OPT_UNKNOWN_REPLY_OFF = "|cff33ff99BananaLoot|r: Reply on unrecognized command disabled.",
        OPT_MANAGE_LABEL = "Management (rarely needed)",
        OPT_TAB_GENERAL = "General",
        OPT_TAB_AUTOMATION = "Automation",
        OPT_TAB_NETWORK = "Network",
        OPT_TAB_DISPLAY = "Display & Sound",
        OPT_TAB_MANAGE = "Management",
        OPT_SCALE_LABEL = "SR window scale in % (default: 100):",
        OPT_SCALE_HINT = "Shrinks or enlarges the SR window, e.g. 70-90 on small screens (e.g. 14 inch). Range: 50-150.",
        OPT_SCALE_SET = "|cff33ff99BananaLoot|r: SR window scale set to %d%%.",
        OPT_SCALE_INVALID = "|cffff5555BananaLoot|r: Please enter a value between 50 and 150.",
        OPT_LOOT_SCALE_LABEL = "Loot window scale in % (default: 100):",
        OPT_LOOT_SCALE_HINT = "Shrinks or enlarges the separate loot window, independent of the SR window scale above. Range: 50-150.",
        OPT_LOOT_SCALE_SET = "|cff33ff99BananaLoot|r: Loot window scale set to %d%%.",
        OPT_LOOT_SCALE_INVALID = "|cffff5555BananaLoot|r: Please enter a value between 50 and 150.",
        OPT_MAXSR_LABEL = "Max. number of SR per player (default: 1, range 1-4):",
        OPT_MAXSR_SET = "|cff33ff99BananaLoot|r: Max. number of SR per player set to %d.",
        OPT_MAXSR_INVALID = "|cffff5555BananaLoot|r: Please enter a value between 1 and 4.",
        OPT_MAXSR_HINT = "At 1, BananaLoot behaves as usual (a new SR automatically replaces the old one). At 2-4, players can reserve multiple items at once; once the limit is reached, 'unsr [Item]' must be sent first.",
        OPT_AUTOML_LABEL = "Auto Master Loot on boss target",
        OPT_AUTOML_HINT = "Automatically switches to Master Loot when you target a known raid boss (only has an effect while you're the party/raid leader). Never automatically switches back to Group Loot -- that remains manual via the ML/GL button.",
        OPT_ROLLSYNC_LABEL = "Roll sync with other BananaLoot users",
        OPT_ROLLSYNC_HINT = "Broadcasts roll progress (start, incoming rolls, winner) via addon message to raid/party members who also use BananaLoot. Recipients see a small popup window with the current standings/countdown and can roll directly from it; the chat also shows a debug line (|cff33ccff[BL-Sync]|r).",
        OPT_ROLLSYNC_SENDER_LABEL = "Also show popup when sending (as loot master)",
        OPT_MULTIWINNER_LABEL = "Multiple drops: top rolls win",
        OPT_MULTIWINNER_HINT = "When multiple copies of the same item are in the loot window (N copies), the top N rollers each win one copy in a single shared roll, instead of rolling each copy one after another.",
        OPT_TRADETRACKING_LABEL = "Trade tracking (automatic)",
        OPT_TRADETRACKING_HINT = "Automatically detects when an item awarded via BananaLoot is traded onward, and adds the new owner to the loot log entry (see /bl csvlog, \"Traded to\" column). Detection happens in your own trade window; a trade between two other players is only visible if one of them also has this option enabled.",
        TRADE_DETECTED = "|cff33ccff[BananaLoot]|r Handoff detected: %s -- %s to %s.",

        -- Roll sync popup (client window for incoming rolls)
        RSWIN_TITLE = "BananaLoot - Roll",
        RSWIN_MODE_SR = "SR",
        RSWIN_MODE_OPEN = "Open",
        RSWIN_MODE_ARF = "ARF",
        RSWIN_TIME_LEFT = "%d seconds left",
        RSWIN_TIE = "|cffffcc00Tie -- please roll again!|r",
        RSWIN_WINNER = "Winner: %s (roll %d, score %d)",
        RSWIN_NO_ROLLS = "|cff888888(no rolls yet)|r",
        RSWIN_MS_BTN = "MS",
        RSWIN_OS_BTN = "OS",
        RSWIN_TM_BTN = "TM",
        RSWIN_OVERFLOW = "|cffff5555%d more|r",

        -- Shared loot history (/bl history) -- current session only,
        -- not saved.
        WIN_HISTORY_TITLE = "Loot History",
        WIN_HISTORY_HINT = "Current session only -- not saved. Bank reserve awards deliberately don't appear here (they stay silent, see Bank Reserve).",
        HISTORY_EMPTY = "|cff888888(no awards in this session yet)|r",
        HISTORY_OVERFLOW = "|cffff5555%d older entries not shown|r",
        UI_BTN_RECOVERY = "SR+ Recovery",
        UI_BTN_RECOVERY_TOOLTIP = "View and restore SR+ values that were most recently displaced by a new reservation.",
        WIN_RECOVERY_TITLE = "SR+ Recovery",
        WIN_RECOVERY_HINT = "Shows, per player, the most recently displaced reservation (overwritten by a new SR or an import).",
        RECOVERY_EMPTY = "|cff888888(no overwritten reservations)|r",
        RECOVERY_RESTORE_BTN = "Restore",
        RECOVERY_RESTORED_MSG = "|cff33ff99BananaLoot|r: Reservation for %s restored (%s, SR+ %d).",
        RECOVERY_RESTORE_FAILED = "|cffff5555BananaLoot|r: Restore failed (player may have already reached the SR limit).",

        -- Sound feedback (optional, on by default)
        OPT_SOUND_LABEL = "Sound",
        OPT_SOUND_MASTER_LABEL = "Enable sounds (master switch)",
        OPT_SOUND_LOOT_LABEL = "Loot detected",
        OPT_SOUND_ROLL_LABEL = "Roll started",
        OPT_SOUND_WINNER_LABEL = "Winner determined",
        OPT_SOUND_AWARD_LABEL = "Item awarded",
        OPT_SOUND_CLICK_LABEL = "Click sound on all buttons",

        WIN_EXPORT_TITLE = "Export SR List",
        WIN_EXPORT_HINT = "Ctrl+A, Ctrl+C to copy - then send to your stand-in",
        WIN_IMPORT_TITLE = "Import SR List",
        WIN_IMPORT_HINT = "Paste text here (Ctrl+V), then click Import",
        WIN_IMPORT_BTN = "Import",
        WIN_CSV_SR_TITLE = "SR List as CSV (for Google Sheets)",
        WIN_CSV_HINT = "Ctrl+A, Ctrl+C - then paste into an empty Google Sheets cell (Ctrl+V)",
        WIN_CSV_LOG_TITLE = "Loot Log as CSV (for Google Sheets)",

        WIN_MANAGE_TITLE = "Manage SR List",
        MG_POPUP_TEXT = "Set %s as winner and award the item immediately?",
        MG_NONE = "|cff888888(no reservations)|r",
        MG_REMOVE_BTN = "Remove",
        MG_WIN_BTN = "Winner",
        MG_OVERFLOW = "|cffff5555%d more player(s) not shown (limit %d)|r",
        MG_ADD_LABEL = "Manually add a player (exact spelling):",
        MG_ADD_BTN = "Add",
        MG_REMOVE_ITEM_BTN = "Remove item completely",
        MG_REMOVE_RESERVATION_BTN = "Delete reservation",
        MG_SKIP_DROP_BTN = "Skip drop",
        MG_HR_TAG = " |cffff5555(Hard Reserve)|r",

        WIN_HR_TITLE = "Hard Reserve Items",
        WIN_HR_HINT = "Add via /bl hr [Item] (shift-click to attach)",
        HR_REMOVE_BTN = "Remove",
        HR_EMPTY = "|cff888888(no Hard Reserve items)|r",
        HR_OVERFLOW = "|cffff5555%d more item(s) not shown|r",

        WIN_BR_TITLE = "Bank Reserve Items",
        WIN_BR_HINT = "Add via /bl br [Item] (shift-click to attach). These items are automatically and silently awarded to you on loot -- no roll, no announcement.",
        BR_REMOVE_BTN = "Remove",
        BR_EMPTY = "|cff888888(no Bank Reserve items)|r",
        BR_OVERFLOW = "|cffff5555%d more item(s) not shown|r",
        UI_BTN_HR_TOOLTIP = "Show Hard Reserve list",
        UI_BTN_BR_TOOLTIP = "Show Bank Reserve list",

        -- LFM window
        WIN_LFM_TITLE = "LFM - Looking For More",
        LFM_TEXT_LABEL = "Text (posted to the World channel):",
        LFM_INTERVAL_LABEL = "Interval in minutes (min. 1):",
        LFM_BTN_START = "Start",
        LFM_BTN_STOP = "Stop",
        LFM_STARTED = "|cff33ff99BananaLoot|r: LFM started -- posting every %d minute(s) in the World channel.",
        LFM_STOPPED = "|cff33ff99BananaLoot|r: LFM stopped.",
        LFM_NEED_TEXT = "|cffff5555BananaLoot|r: Please enter a text first.",
        LFM_INTERVAL_INVALID = "|cffff5555BananaLoot|r: Please enter a value of at least %d minute(s).",
        LFM_CHANNEL_NOT_FOUND = "|cffff5555[BananaLoot]|r LFM: No World channel (e.g. /4) found/joined -- post skipped.",
        LFM_STATUS_RUNNING = "Active -- next post in %d seconds",
        LFM_STATUS_STOPPED = "Stopped",
        UI_BTN_LFM_TOOLTIP = "Open the LFM window (posts a text at regular intervals in the World channel)",

        -- Save/Load Raid
        WIN_SAVE_RAID_TITLE = "Save Raid",
        WIN_SAVE_RAID_HINT = "Saves the current reservations, SR+ values, and the SR+ recovery list under this name (Hard Reserve/Bank Reserve are unaffected). An existing name will be overwritten after confirmation.",
        SAVE_RAID_NAME_LABEL = "Name:",
        SAVE_RAID_BTN = "Save",
        SAVE_RAID_NEED_NAME = "|cffff5555BananaLoot|r: Please enter a name.",
        SAVE_RAID_DONE = "|cff33ff99BananaLoot|r: Raid '%s' saved.",
        WIN_LOAD_RAID_TITLE = "Load Raid",
        WIN_LOAD_RAID_HINT = "Note: loads the saved reservations and SR+ values, replacing the current state.",
        LOAD_RAID_BTN = "Load",
        LOAD_RAID_DELETE_BTN = "Delete",
        LOAD_RAID_EMPTY = "|cff888888(no saved raids available)|r",
        LOAD_RAID_OVERFLOW = "|cffff5555%d more entr(y/ies) not shown|r",
        LOAD_RAID_DONE = "|cff33ff99BananaLoot|r: Raid '%s' loaded.",
        DELETE_RAID_DONE = "|cff33ff99BananaLoot|r: Saved raid '%s' deleted.",
        UI_POPUP_OVERWRITE_RAID_TEXT = "A saved raid named '%s' already exists. Overwrite it?",
        UI_POPUP_LOAD_RAID_TEXT = "Load raid '%s'? This will replace the current reservations and SR+ values.",
        UI_POPUP_DELETE_RAID_TEXT = "Permanently delete the saved raid '%s'?",

        MM_TOOLTIP_LEFT = "Left-click: open window",
        MM_TOOLTIP_RIGHT = "Right-click: settings",
        MM_TOOLTIP_DRAG = "Drag: change position along minimap edge",
        MM_TOOLTIP_SR_HEADER = "Current SR reservations:",
        MM_TOOLTIP_SR_MORE = "... and %d more",
    },
}

-- Aktuelle Sprache (Standard: Deutsch)
function BananaLoot:GetLanguage()
    EnsureDB()
    return BananaLoot_DB.settings.language or "de"
end

function BananaLoot:SetLanguage(lang)
    EnsureDB()
    if lang ~= "de" and lang ~= "en" then return false end
    BananaLoot_DB.settings.language = lang
    return true
end

-- Übersetzten String zum Schlüssel liefern (Fallback: Deutsch, dann der Schlüssel selbst)
function BananaLoot:L(key)
    local lang = self:GetLanguage()
    local tbl = LOCALE[lang] or LOCALE.de
    return tbl[key] or LOCALE.de[key] or key
end

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

-- Loot-Vorschau im Raid-/Gruppenchat: postet beim Öffnen eines NEUEN
-- Loot-Fensters einmalig eine Item-für-Item-Übersicht (SR-Reservierer/
-- Hard Reserve/frei für alle), noch bevor irgendein Roll gestartet
-- wurde -- damit Spieler vorab wissen, wie jedes Item vergeben wird.
-- Bankreserve-Items tauchen hier bewusst NIE auf (siehe AnnounceLoot-
-- Preview), da sie per Definition lautlos/ohne Ankündigung vergeben
-- werden sollen. Standard: an.
function BananaLoot:GetLootPreviewEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.lootPreviewEnabled == nil then return true end
    return BananaLoot_DB.settings.lootPreviewEnabled
end

function BananaLoot:SetLootPreviewEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.lootPreviewEnabled = value and true or false
end

-- SR-Liste sperren/entsperren: bei aktiver Sperre lehnt HandleWhisper neue
-- sr/unsr-Befehle ab (Standard: entsperrt). Reine Abfragen (srlist/hr/hrlist)
-- bleiben davon unberührt. Der Loot-Master selbst kann über das "Verwalten"-
-- Fenster trotz Sperre jederzeit manuell Änderungen vornehmen.
function BananaLoot:GetSRLocked()
    EnsureDB()
    if BananaLoot_DB.settings.srLocked == nil then return false end
    return BananaLoot_DB.settings.srLocked
end

function BananaLoot:SetSRLocked(value)
    EnsureDB()
    BananaLoot_DB.settings.srLocked = value and true or false
end

-- Maximale Anzahl gleichzeitiger SR-Reservierungen pro Spieler (Standard: 1).
-- Bei 1 verhält sich das Addon exakt wie bisher (neue Reservierung ersetzt
-- automatisch die alte, SR+ verfällt). Bei 2-4 kann ein Spieler mehrere
-- Items parallel reservieren; ist das Limit erreicht, wird ein weiteres
-- "sr [Item]" abgelehnt -- der Spieler muss zuerst "unsr [Item]" schicken.
function BananaLoot:GetMaxSRCount()
    EnsureDB()
    return BananaLoot_DB.settings.maxSRCount or 1
end

function BananaLoot:SetMaxSRCount(value)
    EnsureDB()
    value = tonumber(value)
    if not value or value < 1 or value > 4 then return false end
    BananaLoot_DB.settings.maxSRCount = value
    return true
end

-- Automatisches Master Loot beim Anvisieren eines bekannten Raid-Bosses
-- (Standard: an). Greift nur, wenn aktuell NICHT bereits Masterloot aktiv
-- ist -- ist ML schon gesetzt, passiert nichts. Schaltet NIE automatisch
-- zurück auf Gruppenloot, das bleibt bewusst manuell (ML/GL-Button in der
-- UI, siehe BananaLootUI.lua).
function BananaLoot:GetAutoMasterLootEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.autoMasterLoot == nil then return true end
    return BananaLoot_DB.settings.autoMasterLoot
end

function BananaLoot:SetAutoMasterLootEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.autoMasterLoot = value and true or false
end

-- Roll-Sync (AddonMessage-Broadcast des Roll-Fortschritts an alle
-- BananaLoot-Clients im Raid/der Gruppe). Standard: AUS -- neue
-- Netzwerkfunktionalität, bewusst nicht standardmäßig aktiv. Eine
-- gemeinsame Option für Senden (als Loot-Master) UND Empfangen (als
-- normaler Raider) -- je nach aktueller Rolle greift automatisch das
-- Richtige, kein separates Senden/Empfangen-Umschalten nötig.
function BananaLoot:GetRollSyncEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.rollSyncEnabled == nil then return false end
    return BananaLoot_DB.settings.rollSyncEnabled
end

function BananaLoot:SetRollSyncEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.rollSyncEnabled = value and true or false
end

-- Zeigt das Roll-Sync-Popup auch beim Absender (Loot-Master) selbst an.
-- Standard: AUS -- der Master hat sein Loot-Fenster ja schon mit
-- denselben Infos, das Popup wäre für ihn redundant, außer er möchte
-- es trotzdem (z.B. zum Testen).
function BananaLoot:GetRollSyncShowForSender()
    EnsureDB()
    if BananaLoot_DB.settings.rollSyncShowForSender == nil then return false end
    return BananaLoot_DB.settings.rollSyncShowForSender
end

function BananaLoot:SetRollSyncShowForSender(value)
    EnsureDB()
    BananaLoot_DB.settings.rollSyncShowForSender = value and true or false
end

-- "Top N gewinnen" bei Mehrfachdrops: liegen mehrere Kopien desselben Items
-- im Loot-Fenster, gewinnen die besten N Werfer je eine Kopie in EINEM
-- gemeinsamen Roll, statt wie bisher jede Kopie einzeln nacheinander zu
-- verrollen (N = Anzahl der Kopien). Standard: AUS -- ohne aktivierte
-- Option verhält sich jede Auswertung exakt wie zuvor (siehe StartRoll/
-- ResolveActiveRoll).
function BananaLoot:GetMultiWinnerEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.multiWinnerEnabled == nil then return false end
    return BananaLoot_DB.settings.multiWinnerEnabled
end

function BananaLoot:SetMultiWinnerEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.multiWinnerEnabled = value and true or false
end

-- Trade-Tracking: erkennt automatisch, wenn ein über BananaLoot vergebenes
-- Item per Handel an einen anderen Spieler weitergegeben wird (siehe
-- Abschnitt 4c). Standard: AUS -- wie Roll-Sync neue Netzwerkfunktionalität,
-- bewusst nicht standardmäßig aktiv.
function BananaLoot:GetTradeTrackingEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.tradeTrackingEnabled == nil then return false end
    return BananaLoot_DB.settings.tradeTrackingEnabled
end

function BananaLoot:SetTradeTrackingEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.tradeTrackingEnabled = value and true or false
end

-- Setzt den SR+ Stack direkt auf einen bestimmten Wert (statt schrittweise
-- über IncrementStack/DecrementStack). Wird für die Wiederherstellung einer
-- versehentlich überschriebenen Reservierung gebraucht.
function BananaLoot:SetStack(playerName, itemID, value)
    EnsureDB()
    BananaLoot_DB.players[playerName] = BananaLoot_DB.players[playerName] or {}
    if value and value > 0 then
        BananaLoot_DB.players[playerName][itemID] = value
    else
        BananaLoot_DB.players[playerName][itemID] = nil
    end
end

-- Merkt sich die zuletzt durch eine neue Reservierung verdrängte
-- Reservierung eines Spielers (inkl. seines SR+ Stacks), damit der
-- Loot-Master sie im Fehlerfall ("Spieler hat sich vertan") manuell über
-- das SR+-Wiederherstellungsfenster zurückholen kann. Es wird je Spieler
-- immer nur der letzte Verdrängungsvorgang gespeichert.
function BananaLoot:RecordOverwrittenReservation(playerName, itemID)
    EnsureDB()
    local oldRes = self.reservations[itemID]
    local link = (oldRes and oldRes.link) or self.knownLootItems[itemID] or ("item:" .. itemID .. ":0:0:0:0:0:0:0")
    BananaLoot_DB.lastOverwritten[playerName] = {
        itemID = itemID,
        link = link,
        stack = self:GetStack(playerName, itemID),
    }
end

function BananaLoot:GetOverwrittenList()
    EnsureDB()
    return BananaLoot_DB.lastOverwritten
end

-- Stellt die zuletzt verdrängte Reservierung eines Spielers wieder her:
-- setzt die Reservierung erneut (respektiert dabei weiterhin das aktuelle
-- SR-Limit) und schreibt den gemerkten SR+ Stack zurück.
function BananaLoot:RestoreOverwrittenReservation(playerName)
    local entry = self:GetOverwrittenList()[playerName]
    if not entry then return false end

    local ok = self:AddReservation(entry.link, playerName, true)
    if ok then
        self:SetStack(playerName, entry.itemID, entry.stack)
        self:GetOverwrittenList()[playerName] = nil
        return true
    end
    return false
end

-- Ersetzt einen "rohen" Platzhalter-Link (z.B. "item:61260:0:0:0:0:0:0:0"
-- aus dem raidres.top-Import, der keinen echten Namen enthält) durch den
-- echten, farbcodierten Item-Link, SOBALD der Client die Item-Daten kennt
-- (GetItemInfo liefert die Namen/Farbe erst nach einer kurzen, asynchronen
-- Serverabfrage, siehe bereits vorhandene Icon-Retry-Logik in der UI).
-- Gibt true zurück, wenn tatsächlich etwas aktualisiert wurde (für die UI,
-- um zu wissen, ob ein Refresh nötig ist).
function BananaLoot:TryUpgradeSyntheticLink(itemID)
    local res = self.reservations[itemID]
    local needsUpgrade = (res and res.link and not string.find(res.link, "|Hitem:")) and true or false
    if not needsUpgrade and self.knownLootItems[itemID] and not string.find(self.knownLootItems[itemID], "|Hitem:") then
        needsUpgrade = true
    end
    if not needsUpgrade then return false end

    local _, properLink = GetItemInfo("item:" .. itemID .. ":0:0:0:0:0:0:0")
    if not properLink then
        -- GetItemInfo liefert auf diesem Server fuer unbekannte Items nie
        -- etwas -- als Fallback die statische Item-DB probieren, bevor wir
        -- endgueltig aufgeben (siehe BananaLootItemDB.lua).
        local staticInfo = self:GetStaticItemInfo(itemID)
        if staticInfo and staticInfo.name then
            if staticInfo.quality and not self.itemQualityHints[itemID] then
                self.itemQualityHints[itemID] = staticInfo.quality
            end
            properLink = self:BuildItemLink(itemID, staticInfo.name)
        end
    end
    if not properLink then return false end

    if res then res.link = properLink end
    if self.knownLootItems[itemID] then self.knownLootItems[itemID] = properLink end
    self:SaveSession()
    return true
end

-- Automatische Rückantwort bei unbekanntem Whisper-Befehl (Standard: an)
function BananaLoot:GetUnknownCommandReplyEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.unknownCommandReplyEnabled == nil then return true end
    return BananaLoot_DB.settings.unknownCommandReplyEnabled
end

function BananaLoot:SetUnknownCommandReplyEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.unknownCommandReplyEnabled = value and true or false
end

-- Skalierung des Hauptfensters in Prozent (Standard: 100, Bereich 50-150).
-- Als Ganzzahl-Prozent statt Dezimalfaktor gespeichert, damit sich die
-- Eingabe an die bestehenden numerischen EditBoxen (SetNumeric) anpasst.
function BananaLoot:GetUIScalePercent()
    EnsureDB()
    return BananaLoot_DB.settings.uiScalePercent or 100
end

function BananaLoot:SetUIScalePercent(value)
    EnsureDB()
    value = tonumber(value)
    if not value or value < 50 or value > 150 then return false end
    BananaLoot_DB.settings.uiScalePercent = value
    return true
end

function BananaLoot:GetUIScale()
    return self:GetUIScalePercent() / 100
end

-- Separate Skalierung nur für das Loot-Fenster (Standard: 100, Bereich
-- 50-150), unabhängig von der SR-Fenster-Skalierung oben -- beide
-- Fenster werden unterschiedlich oft/groß genutzt, daher ein eigener
-- Wert statt eines gemeinsamen "UI-Skalierung"-Reglers für beide.
function BananaLoot:GetLootUIScalePercent()
    EnsureDB()
    return BananaLoot_DB.settings.lootUiScalePercent or 100
end

function BananaLoot:SetLootUIScalePercent(value)
    EnsureDB()
    value = tonumber(value)
    if not value or value < 50 or value > 150 then return false end
    BananaLoot_DB.settings.lootUiScalePercent = value
    return true
end

function BananaLoot:GetLootUIScale()
    return self:GetLootUIScalePercent() / 100
end

-- ============================================================
-- 1c) SOUND-FEEDBACK (optional, standardmäßig an)
-- Ein übergreifender Hauptschalter (GetSoundEnabled) sowie vier einzelne
-- Schalter für die Event-Sounds (Loot/Roll/Gewinner/Award), damit jedes
-- Event für sich abschaltbar ist, ohne alle Sounds komplett auszuschalten.
-- Der Klick-Sound auf UI-Buttons wird bewusst über EINEN eigenen globalen
-- Schalter gesteuert statt über 25+ Einzelschalter je Button.
-- ============================================================
function BananaLoot:GetSoundEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.soundEnabled == nil then return true end
    return BananaLoot_DB.settings.soundEnabled
end

function BananaLoot:SetSoundEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.soundEnabled = value and true or false
end

function BananaLoot:GetSoundLootDetectedEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.soundLootDetected == nil then return true end
    return BananaLoot_DB.settings.soundLootDetected
end

function BananaLoot:SetSoundLootDetectedEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.soundLootDetected = value and true or false
end

function BananaLoot:GetSoundRollStartedEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.soundRollStarted == nil then return true end
    return BananaLoot_DB.settings.soundRollStarted
end

function BananaLoot:SetSoundRollStartedEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.soundRollStarted = value and true or false
end

function BananaLoot:GetSoundWinnerEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.soundWinner == nil then return true end
    return BananaLoot_DB.settings.soundWinner
end

function BananaLoot:SetSoundWinnerEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.soundWinner = value and true or false
end

function BananaLoot:GetSoundAwardEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.soundAward == nil then return true end
    return BananaLoot_DB.settings.soundAward
end

function BananaLoot:SetSoundAwardEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.soundAward = value and true or false
end

function BananaLoot:GetSoundButtonClicksEnabled()
    EnsureDB()
    if BananaLoot_DB.settings.soundButtonClicks == nil then return true end
    return BananaLoot_DB.settings.soundButtonClicks
end

function BananaLoot:SetSoundButtonClicksEnabled(value)
    EnsureDB()
    BananaLoot_DB.settings.soundButtonClicks = value and true or false
end

-- Zentrale, pcall-abgesicherte Wiedergabe für Event-Sounds. specificEnabled
-- wird vom Aufrufer übergeben (z.B. self:GetSoundWinnerEnabled()), damit
-- diese Funktion nicht wissen muss, um welches Event es sich handelt.
function BananaLoot:PlayEventSound(soundName, specificEnabled)
    if not self:GetSoundEnabled() then return end
    if not specificEnabled then return end
    pcall(function() PlaySound(soundName) end)
end

-- Einheitlicher Klick-Sound für UI-Buttons (eigener globaler Schalter,
-- respektiert zusätzlich den übergeordneten Master-Schalter -- "Sounds
-- aktivieren" soll wirklich ALLE Addon-Sounds stummschalten können).
function BananaLoot:PlayClickSound()
    if not self:GetSoundEnabled() then return end
    if not self:GetSoundButtonClicksEnabled() then return end
    pcall(function() PlaySound("igMainMenuOptionCheckBoxOn") end)
end

-- ============================================================
-- 2) AKTUELLE SESSION (Reservierungen)
-- ============================================================
BananaLoot.reservations = {}       -- [itemID] = { link, name, players={}, order={} }
BananaLoot.playerReservedItems = {} -- [name] = { itemID1, itemID2, ... } (chronologisch, älteste zuerst; Anzahl begrenzt durch GetMaxSRCount)
BananaLoot.knownLootItems = {}     -- [itemID] = link (aktuell im Loot-Fenster sichtbar, auch ohne SR)
BananaLoot.knownLootIcons = {}     -- [itemID] = Icon-Pfad aus GetLootSlotInfo (bleibt auch nach Schließen des Loot-Fensters erhalten, im Gegensatz zu knownLootItems wird hier nichts überschrieben)
BananaLoot.lootCounts = {}         -- [itemID] = Anzahl noch offener Kopien im aktuellen Loot-Fenster (Mehrfachdrops)
BananaLoot.lastWhisperTime = {}    -- [name] = GetTime() der letzten verarbeiteten Whisper-Anfrage (Spam-Schutz)
BananaLoot.itemQualityHints = {}   -- [itemID] = Qualitätsstufe (0-6), z.B. aus raidres.top-Import (liefert nie einen Namen, aber die Qualität) -- für Rarity-Farbe der "Item #ID"-Platzhalteranzeige, solange der echte Name noch nicht bekannt ist
BananaLoot.playerClasses = {}      -- [name] = Klassen-Token (z.B. "WARRIOR"), aus dem Raid-/Gruppen-Roster (siehe GetCurrentRosterSet) -- rein session-lokaler Anzeige-Cache, nicht gespeichert, bleibt aber auch nach Verlassen/Disconnect eines Spielers erhalten (wird nur überschrieben, nie gelöscht)

-- Standard-WoW-Qualitätsfarben (wie ITEM_QUALITY_COLORS), als Hex ohne "|c"-Präfix.
local QUALITY_COLOR_HEX = {
    [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd",
    [4] = "a335ee", [5] = "ff8000", [6] = "e6cc80",
}

-- Liefert den Farbcode (ohne "|c"-Präfix) für eine bekannte Qualitätsstufe,
-- oder weiß als Fallback, falls keine Qualität hinterlegt ist.
function BananaLoot:GetQualityColorHex(itemID)
    local quality = self.itemQualityHints[itemID]
    return (quality and QUALITY_COLOR_HEX[quality]) or "ffffff"
end

-- Standard-WoW-Klassenfarben (wie RAID_CLASS_COLORS), als Hex ohne
-- "|c"-Präfix. Nur die neun Vanilla-Klassen.
local CLASS_COLOR_HEX = {
    WARRIOR = "c79c6e", PALADIN = "f58cba", HUNTER = "abd473",
    ROGUE = "fff569", PRIEST = "ffffff", SHAMAN = "0070de",
    MAGE = "69ccf0", WARLOCK = "9482c9", DRUID = "ff7d0a",
}

-- Liefert den Farbcode (ohne "|c"-Präfix) für einen Spielernamen anhand
-- der zuletzt bekannten Klasse (playerClasses-Cache, siehe
-- GetCurrentRosterSet), oder weiß als Fallback, falls die Klasse (noch)
-- unbekannt ist (z.B. Spieler noch nie im Roster gesehen).
function BananaLoot:GetClassColorHex(name)
    local class = self.playerClasses[name]
    return (class and CLASS_COLOR_HEX[class]) or "ffffff"
end

-- Baut den farbcodierten Anzeigenamen eines Spielers (Klassenfarbe, siehe
-- GetClassColorHex) -- zentrale Hilfsfunktion für die Addon-Fenster
-- (SR-/Loot-Fenster, Verwalten, Historie, Roll-Sync-Popup). Bewusst NICHT
-- für Chat-/Whisper-Ausgaben verwendet (Raid-/Gruppenchat-Ankündigungen,
-- Whisper-Antworten, lokale Chat-Log-Zeilen bleiben unverändert).
function BananaLoot:ColoredName(name)
    if not name then return name end
    return "|cff" .. self:GetClassColorHex(name) .. name .. "|r"
end

-- Liefert Name (+ ggf. Qualitaet) aus der mitgelieferten statischen Item-
-- Datenbank (BananaLootItemDB.lua), falls dort vorhanden, sonst nil.
-- Diese DB dient als VORGELAGERTER Fallback zu GetItemInfo(): auf diesem
-- Server liefert GetItemInfo() fuer dem Client unbekannte Items nie Daten,
-- die statische DB kennt viele Items trotzdem schon vor dem ersten Loot.
function BananaLoot:GetStaticItemInfo(itemID)
    if not BananaLoot_ItemDB then return nil end
    return BananaLoot_ItemDB[itemID]
end

-- Baut aus einer Item-ID und einem bekannten Namen einen vollstaendigen,
-- farbcodierten Chat-Link (ohne GetItemInfo/Server-Query). Nutzt die
-- aktuell hinterlegte Qualitaetsvermutung (itemQualityHints, meist von
-- raidres.top) fuer die Farbe, Standard weiss falls nichts bekannt ist.
function BananaLoot:BuildItemLink(itemID, name)
    return "|cff" .. self:GetQualityColorHex(itemID) .. "|Hitem:" .. itemID .. ":0:0:0:0:0:0:0|h[" .. name .. "]|h|r"
end

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

-- Entfernt playerName aus dem order-Array einer Reservierung (falls vorhanden).
-- Zentrale Hilfsfunktion, da diese Schleife an mehreren Stellen benötigt wird.
local function RemovePlayerFromOrder(order, playerName)
    for i = 1, table.getn(order) do
        if order[i] == playerName then
            table.remove(order, i)
            return true
        end
    end
    return false
end

-- Entfernt einen Wert (z.B. eine Item-ID) aus einem einfachen Array.
-- Gleiches Prinzip wie RemovePlayerFromOrder, nur generisch für IDs statt
-- Spielernamen -- wird für playerReservedItems gebraucht (Mehrfach-SR).
local function RemoveIDFromArray(array, id)
    for i = 1, table.getn(array) do
        if array[i] == id then
            table.remove(array, i)
            return true
        end
    end
    return false
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

-- ============================================================
-- 1b-2) BANK RESERVE (BR) -- Items, die nie verrollt und nicht im Chat
-- angekündigt werden, sondern beim Looten automatisch und lautlos an
-- den Lootmaster selbst gehen (z.B. Tradeskill-Mats für die Gildenbank,
-- BoE-Items zum Verkauf/Craften).
-- ============================================================
function BananaLoot:IsBankReserve(itemID)
    EnsureDB()
    return BananaLoot_DB.bankReserves[itemID] ~= nil
end

function BananaLoot:AddBankReserve(itemLink)
    local id = GetItemIDFromLink(itemLink)
    if not id then return false end
    EnsureDB()
    BananaLoot_DB.bankReserves[id] = { link = itemLink }
    return true, id
end

function BananaLoot:RemoveBankReserve(itemID)
    EnsureDB()
    if BananaLoot_DB.bankReserves[itemID] then
        BananaLoot_DB.bankReserves[itemID] = nil
        return true
    end
    return false
end

function BananaLoot:GetBankReserveList()
    EnsureDB()
    return BananaLoot_DB.bankReserves
end

-- ============================================================
-- 1b-3) RAID SPEICHERN/LADEN -- benannte lokale Snapshots des
-- aktuellen SR-Stands (Reservierungen, SR+ Werte, SR+-Wiederher-
-- stellungsliste), z.B. um mehrere Raidabende sauber getrennt zu
-- sichern und bei Bedarf wieder herzustellen. Hard-Reserve- und
-- Bankreserve-Listen sind bewusst NICHT Teil eines Snapshots, da sie
-- eher dauerhafte, raid-übergreifende Einstellungen sind.
-- ============================================================

-- Rekursive Tief-Kopie beliebig verschachtelter Tabellen. Wird sowohl
-- beim Speichern als auch beim Laden gebraucht: ohne echte Kopie würde
-- ein gespeicherter Snapshot weiterhin auf dieselben Tabellen wie die
-- aktuelle Session zeigen, sodass spätere Änderungen (neue SR, Award
-- etc.) den bereits gespeicherten Stand nachträglich verfälschen würden.
local function DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[DeepCopy(k)] = DeepCopy(v)
    end
    return copy
end

-- Name des aktuell aktiven (zuletzt gespeicherten oder geladenen)
-- Raids, rein zur Anzeige als Überschrift im SR-Fenster. Rein
-- informativ -- hat keinen Einfluss auf Spielmechanik/Vergabe.
function BananaLoot:GetCurrentRaidName()
    EnsureDB()
    return BananaLoot_DB.currentRaidName
end

function BananaLoot:SetCurrentRaidName(name)
    EnsureDB()
    BananaLoot_DB.currentRaidName = name
end

function BananaLoot:GetSavedRaidList()
    EnsureDB()
    return BananaLoot_DB.savedRaids
end

-- Speichert den aktuellen SR-Stand unter dem angegebenen Namen (Tief-
-- Kopie, siehe DeepCopy). Ein bereits vorhandener Eintrag mit gleichem
-- Namen wird überschrieben -- die Rückfrage dazu erfolgt im UI, nicht
-- hier. Setzt den Namen zusätzlich als aktuellen Raid-Namen (Anzeige
-- im SR-Fenster).
function BananaLoot:SaveRaid(name)
    if not name or Trim(name) == "" then return false end
    name = Trim(name)
    EnsureDB()
    BananaLoot_DB.savedRaids[name] = {
        timestamp = time(),
        reservations = DeepCopy(self.reservations),
        playerReservedItems = DeepCopy(self.playerReservedItems),
        players = DeepCopy(BananaLoot_DB.players),
        lastOverwritten = DeepCopy(BananaLoot_DB.lastOverwritten),
    }
    self:SetCurrentRaidName(name)
    return true
end

-- Lädt einen zuvor gespeicherten Raid-Snapshot: ersetzt die aktuellen
-- Reservierungen, SR+ Werte und die SR+-Wiederherstellungsliste
-- vollständig durch den gespeicherten Stand (wieder als Tief-Kopie,
-- damit spätere Änderungen den gespeicherten Snapshot nicht erneut
-- verfälschen). Hard-Reserve/Bankreserve bleiben unangetastet.
function BananaLoot:LoadRaid(name)
    EnsureDB()
    local entry = BananaLoot_DB.savedRaids[name]
    if not entry then return false end

    self.reservations = DeepCopy(entry.reservations or {})
    self.playerReservedItems = DeepCopy(entry.playerReservedItems or {})
    BananaLoot_DB.players = DeepCopy(entry.players or {})
    BananaLoot_DB.lastOverwritten = DeepCopy(entry.lastOverwritten or {})

    self:SetCurrentRaidName(name)
    self:SaveSession()
    return true
end

function BananaLoot:DeleteSavedRaid(name)
    EnsureDB()
    if BananaLoot_DB.savedRaids[name] then
        BananaLoot_DB.savedRaids[name] = nil
        return true
    end
    return false
end

-- Entfernt eine Item-ID aus der Mehrfach-SR-Liste eines Spielers (falls
-- vorhanden). Zentrale Hilfsfunktion für RemoveReservation und AwardItem.
function BananaLoot:RemoveItemFromPlayerList(playerName, itemID)
    local items = self.playerReservedItems[playerName]
    if items then RemoveIDFromArray(items, itemID) end
end

-- Entfernt ALLE aktuellen Reservierungen eines Spielers auf einmal (z.B.
-- wenn ein SR-Import für diesen Spieler eine komplett neue, autoritative
-- Liste mitbringt). Jede verdrängte Reservierung wird vorher per
-- RecordOverwrittenReservation gesichert, damit sie sich bei Bedarf manuell
-- wiederherstellen lässt.
function BananaLoot:EvictAllPlayerReservations(playerName)
    local items = self.playerReservedItems[playerName]
    if not items then return end
    for i = 1, table.getn(items) do
        local oldId = items[i]
        local oldRes = self.reservations[oldId]
        if oldRes and oldRes.players[playerName] then
            oldRes.players[playerName] = nil
            RemovePlayerFromOrder(oldRes.order, playerName)
        end
        self:RecordOverwrittenReservation(playerName, oldId)
        self:ResetStack(playerName, oldId)
    end
    self.playerReservedItems[playerName] = {}
end

function BananaLoot:AddReservation(itemLink, playerName, forceIgnoreHR)
    local id = GetItemIDFromLink(itemLink)
    if not id then return false, "invalid_link" end
    if not forceIgnoreHR and self:IsHardReserve(id) then return false, "hard_reserve" end
    if not forceIgnoreHR and self:IsBankReserve(id) then return false, "bank_reserve" end

    local items = self.playerReservedItems[playerName] or {}
    local alreadyHasThis = false
    for i = 1, table.getn(items) do
        if items[i] == id then alreadyHasThis = true end
    end

    local oldId = nil

    if not alreadyHasThis then
        local maxCount = self:GetMaxSRCount()
        if table.getn(items) >= maxCount then
            if maxCount <= 1 then
                -- Standardverhalten (Limit 1, wie seit v3.6.0): automatisch
                -- ersetzen, der SR+ Bonus für das alte Item verfällt.
                oldId = items[1]
                local oldRes = self.reservations[oldId]
                if oldRes and oldRes.players[playerName] then
                    oldRes.players[playerName] = nil
                    RemovePlayerFromOrder(oldRes.order, playerName)
                end
                self:RecordOverwrittenReservation(playerName, oldId)
                self:ResetStack(playerName, oldId)
                items = {}
            else
                -- Limit > 1 erreicht: Whisper wird abgelehnt, Spieler muss
                -- zuerst "unsr [Item]" für eines seiner Items schicken.
                return false, "limit_reached"
            end
        end
        table.insert(items, id)
        self.playerReservedItems[playerName] = items
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

    self:SaveSession()
    return true, id, oldId
end

function BananaLoot:RemoveReservation(itemLink, playerName)
    local id = GetItemIDFromLink(itemLink)
    if not id then return false end
    local res = self.reservations[id]
    if not res or not res.players[playerName] then return false end

    res.players[playerName] = nil
    RemovePlayerFromOrder(res.order, playerName)
    self:RemoveItemFromPlayerList(playerName, id)

    -- War das der letzte Reservierer, bleibt sonst ein leerer Eintrag
    -- stehen, der in der UI dauerhaft als "[Offen]" auftaucht. Nur
    -- entfernen, wenn das Item nicht noch aktiv im Loot-Fenster relevant
    -- ist (sonst würde es kurz aus der Liste verschwinden und beim
    -- nächsten Scan wieder auftauchen).
    if table.getn(res.order) == 0 and not self.knownLootItems[id] then
        self.reservations[id] = nil
    end

    self:SaveSession()
    return true
end

function BananaLoot:ClearAllReservations()
    self.reservations = {}
    self.playerReservedItems = {}
    self:SaveSession()
end

-- Sichert die aktuelle Session (Reservierungen) in den SavedVariables,
-- damit sie /reload und Disconnects überlebt.
function BananaLoot:SaveSession()
    EnsureDB()
    BananaLoot_DB.session = {
        reservations = self.reservations,
        playerReservedItems = self.playerReservedItems,
    }
end

function BananaLoot:RestoreSession()
    EnsureDB()
    if BananaLoot_DB.session then
        self.reservations = BananaLoot_DB.session.reservations or {}
        if BananaLoot_DB.session.playerReservedItems then
            self.playerReservedItems = BananaLoot_DB.session.playerReservedItems
        elseif BananaLoot_DB.session.playerCurrentItem then
            -- Migration von einer älteren BananaLoot-Version (vor v3.9,
            -- Einzel-SR pro Spieler): altes Einzel-Item-Feld in ein Array
            -- umwandeln, damit bestehende Reservierungen erhalten bleiben.
            local migrated = {}
            for name, id in pairs(BananaLoot_DB.session.playerCurrentItem) do
                migrated[name] = { id }
            end
            self.playerReservedItems = migrated
        else
            self.playerReservedItems = {}
        end
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
    msg = Trim(msg)
    -- Mehrfache Leerzeichen auf eines reduzieren (z.B. bei "sr   [Item]").
    -- Ungefährlich für Itemnamen, die enthalten normalerweise keine
    -- doppelten Leerzeichen.
    msg = string.gsub(msg, "%s+", " ")
    local lower = string.lower(msg)
    -- "sr " deckt den Normalfall ab (Leerzeichen vor dem Item-Link).
    -- "sr|c" deckt den Fall ab, dass der Spieler den Item-Link direkt ohne
    -- Leerzeichen hinter "sr" shift-klickt (Item-Links beginnen mit "|c").
    -- Nacktes "sr"/"!sr" (ohne alles danach) zählt ebenfalls als Versuch,
    -- damit dafür die passende "bitte Item anhängen"-Antwort kommt statt
    -- der allgemeinen "Befehl nicht erkannt"-Meldung.
    local isSR = (string.find(lower, "^sr ") or string.find(lower, "^!sr ")
        or string.find(lower, "^sr|c") or string.find(lower, "^!sr|c")
        or lower == "sr" or lower == "!sr")
    local isUnSR = (string.find(lower, "^unsr ") or string.find(lower, "^!unsr ")
        or string.find(lower, "^unsr|c") or string.find(lower, "^!unsr|c")
        or lower == "unsr" or lower == "!unsr")
    local isList = (lower == "srlist" or lower == "!srlist")
    local isHRQuery = (lower == "hr" or lower == "!hr" or lower == "hrlist" or lower == "!hrlist")

    -- Nur bei einem tatsächlich erkannten Befehlsversuch überhaupt reagieren:
    -- weder der Spam-Schutz-Timer noch eine automatische Antwort sollen bei
    -- ganz normalem Chat ("hi", "thx" etc.) an den Loot-Master greifen.
    local isCommandAttempt = isSR or isUnSR or isList or isHRQuery
    if not isCommandAttempt then
        return
    end

    local now = GetTime()
    local last = self.lastWhisperTime[sender]
    if last and (now - last) < 2 then
        return -- Spam-Schutz: max. 1 Befehl alle 2 Sekunden pro Spieler
    end
    self.lastWhisperTime[sender] = now

    if isList then
        self:ReplyWithPlayerList(sender)
        return
    end

    if isHRQuery then
        self:ReplyWithHRList(sender)
        return
    end

    if isSR then
        if self:GetSRLocked() then
            SendWhisperReply(sender, self:L("WHISPER_SR_LOCKED"))
            return
        end
        local link = ExtractLinkFromMessage(msg)
        if not link then
            SendWhisperReply(sender, self:L("WHISPER_SR_NEED_LINK"))
            return
        end
        local ok, idOrErr, oldId = self:AddReservation(link, sender)
        if ok then
            local stack = self:GetStack(sender, idOrErr)
            local bonusTxt = ""
            if stack > 0 then bonusTxt = string.format(self:L("WHISPER_SR_BONUS_SUFFIX"), stack * self:GetBonusPerStack()) end
            local swapTxt = ""
            if oldId and oldId ~= idOrErr then
                swapTxt = self:L("WHISPER_SR_SWAP_SUFFIX")
            end
            SendWhisperReply(sender, string.format(self:L("WHISPER_SR_RESERVED"), link) .. bonusTxt .. swapTxt)
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        elseif idOrErr == "hard_reserve" then
            SendWhisperReply(sender, string.format(self:L("WHISPER_SR_HARD_RESERVE"), link))
        elseif idOrErr == "bank_reserve" then
            SendWhisperReply(sender, string.format(self:L("WHISPER_SR_BANK_RESERVE"), link))
        elseif idOrErr == "limit_reached" then
            SendWhisperReply(sender, string.format(self:L("WHISPER_SR_LIMIT_REACHED"), self:GetMaxSRCount()))
        else
            SendWhisperReply(sender, self:L("WHISPER_SR_UNKNOWN_ITEM"))
        end
        return
    end

    if isUnSR then
        if self:GetSRLocked() then
            SendWhisperReply(sender, self:L("WHISPER_SR_LOCKED"))
            return
        end
        local link = ExtractLinkFromMessage(msg)
        if not link then
            SendWhisperReply(sender, self:L("WHISPER_UNSR_NEED_LINK"))
            return
        end
        local ok = self:RemoveReservation(link, sender)
        if ok then
            SendWhisperReply(sender, string.format(self:L("WHISPER_UNSR_REMOVED"), link))
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        else
            SendWhisperReply(sender, self:L("WHISPER_UNSR_NOT_RESERVED"))
        end
        return
    end

    -- Unbekannter Befehl: Rückmeldung statt stillem Ignorieren (hilft bei Tippfehlern),
    -- aber optional abschaltbar (z.B. gegen Spam außerhalb des Raids).
    if self:GetUnknownCommandReplyEnabled() then
        SendWhisperReply(sender, self:L("WHISPER_UNKNOWN_COMMAND"))
    end
end

-- Maximale Anzahl namentlich genannter Mit-Reservierer je Item in der
-- srlist-Antwort (siehe ReplyWithPlayerList), danach "+N weitere" --
-- Whisper-Nachrichten haben wie jede Chatzeile ein Zeichenlimit.
local WHISPER_LIST_MAX_OTHERS = 8

function BananaLoot:ReplyWithPlayerList(sender)
    local found = false
    for id, res in pairs(self.reservations) do
        if res.players[sender] then
            found = true
            local stack = self:GetStack(sender, id)
            local bonusTxt = ""
            if stack > 0 then bonusTxt = string.format(self:L("WHISPER_LIST_BONUS_SUFFIX"), stack * self:GetBonusPerStack()) end
            SendWhisperReply(sender, string.format(self:L("WHISPER_LIST_ENTRY"), res.link) .. bonusTxt)

            -- Zusätzlich: welche anderen Spieler ebenfalls auf dieses
            -- Item SR't haben, inkl. deren SR+ Bonus. Keine neue
            -- Information gegenüber dem, was ohnehin beim Rollstart im
            -- Raid-/Gruppenchat bzw. in der Loot-Vorschau sichtbar wird
            -- (siehe AnnounceLootPreview/StartRoll) -- hier nur bereits
            -- vorab auf Nachfrage per Whisper.
            local others = ""
            local othersCount = 0
            local shownCount = 0
            for i = 1, table.getn(res.order) do
                local name = res.order[i]
                if name ~= sender then
                    othersCount = othersCount + 1
                    if shownCount < WHISPER_LIST_MAX_OTHERS then
                        if shownCount > 0 then others = others .. ", " end
                        local otherStack = self:GetStack(name, id)
                        others = others .. name
                        if otherStack > 0 then others = others .. "(+" .. (otherStack * self:GetBonusPerStack()) .. ")" end
                        shownCount = shownCount + 1
                    end
                end
            end
            if othersCount > WHISPER_LIST_MAX_OTHERS then
                others = others .. string.format(self:L("UI_PLAYERS_MORE"), othersCount - WHISPER_LIST_MAX_OTHERS)
            end
            if othersCount > 0 then
                SendWhisperReply(sender, string.format(self:L("WHISPER_LIST_OTHERS_PREFIX"), others))
            end
        end
    end
    if not found then
        SendWhisperReply(sender, self:L("WHISPER_LIST_EMPTY"))
    end
end

-- Listet alle aktuell auf Hard Reserve stehenden Items per Whisper auf.
function BananaLoot:ReplyWithHRList(sender)
    EnsureDB()
    local found = false
    for _, hr in pairs(BananaLoot_DB.hardReserves) do
        found = true
        SendWhisperReply(sender, string.format(self:L("WHISPER_HR_ENTRY"), hr.link))
    end
    if not found then
        SendWhisperReply(sender, self:L("WHISPER_HR_EMPTY"))
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

-- Baut nebenbei den Klassen-Farb-Cache (BananaLoot.playerClasses) mit auf
-- -- kein zusätzlicher Event-Hook nötig, da diese Funktion ohnehin an
-- vielen Stellen (Loot-Fenster öffnen, jeder Roll-Start, /bl-Befehle...)
-- regelmäßig aufgerufen wird.
local function GetCurrentRosterSet()
    local set = {}
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            local name = UnitName("raid" .. i)
            if name then
                set[name] = true
                local _, class = UnitClass("raid" .. i)
                if class then BananaLoot.playerClasses[name] = class end
            end
        end
    else
        local myName = UnitName("player")
        set[myName] = true
        local _, myClass = UnitClass("player")
        if myClass then BananaLoot.playerClasses[myName] = myClass end
        local pn = GetNumPartyMembers()
        for i = 1, pn do
            local name = UnitName("party" .. i)
            if name then
                set[name] = true
                local _, class = UnitClass("party" .. i)
                if class then BananaLoot.playerClasses[name] = class end
            end
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

-- Liefert alle aktuell im Raid/der Gruppe anwesenden Spielernamen als Array
-- (statt als Set) -- z.B. für den Raid-Roll im Verwalten-Fenster, wo ein
-- zufälliger Index gezogen werden muss.
function BananaLoot:GetRosterNames()
    local set = GetCurrentRosterSet()
    local names = {}
    for name, _ in pairs(set) do
        table.insert(names, name)
    end
    return names
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
-- 4b) ROLL-SYNC (AddonMessage-Broadcast an alle BananaLoot-Clients)
-- Sendet den Roll-Fortschritt (Start/Update/Gleichstand/Gewinner/
-- Abbruch) als kompakte AddonMessage an RAID/PARTY, damit andere
-- Spieler mit BananaLoot den Stand mitverfolgen können. Phase 1: nur
-- das reine Sende-/Empfangsprotokoll, zur Kontrolle vorerst als
-- Chat-Debug-Ausgabe sichtbar (siehe HandleRollSyncMessage weiter
-- unten) -- ein eigenes Anzeigefenster ist ein späterer Schritt.
--
-- WICHTIG: Vanilla 1.12 kennt kein RegisterAddonMessagePrefix (das kam
-- erst in späteren Client-Versionen) -- SendAddonMessage/CHAT_MSG_ADDON
-- funktionieren hier ohne Registrierung, der Prefix wird beim Empfang
-- manuell verglichen.
--
-- Format (kompakt, "~"-getrennt, wie beim bestehenden MSRv2-Export):
--   RS~itemID~dauerSek~modus            Roll gestartet (modus: 0 offen, 1 SR, 2 ARF)
--   RU~itemID~Spieler~Wert~Typ          Einzelner gezählter Wurf (Typ: ms/os/tmog)
--   RT~itemID~Namen(Komma-getrennt)     Gleichstand, nur diese Spieler rollen erneut
--   RW~itemID~Gewinner~Score~Wurf~Pool  Roll abgeschlossen (Pool: ms/os/tmog)
--   RC~itemID~Grund                     Abgebrochen (Grund: 0 manuell, 1 niemand gerollt)
--
-- Absichtlich NICHT mitgesendet: die Liste der SR-berechtigten
-- Spieler (potenziell lang, unnötig -- der Master filtert bereits
-- serverseitig, welche Rolls überhaupt als RU rausgehen) sowie Item-
-- Name/Icon (wird beim Empfänger lokal aus der itemID aufgelöst,
-- genau wie beim Master selbst -- siehe GetStaticItemInfo/GetItemInfo).
-- ============================================================
local ROLL_SYNC_PREFIX = "BananaLoot"

local function SendRollSyncMessage(text)
    if not BananaLoot:GetRollSyncEnabled() then return end
    -- Nur sinnvoll in Gruppe/Raid -- SendAddonMessage kennt "SAY" nicht
    -- als gültigen Kanal, und alleine gibt es ohnehin niemanden, der
    -- mitliest.
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then return end
    local channel = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    pcall(function() SendAddonMessage(ROLL_SYNC_PREFIX, text, channel) end)
end

local function BroadcastRollStart(itemID, duration, mode)
    SendRollSyncMessage("RS~" .. itemID .. "~" .. duration .. "~" .. mode)
end

local function BroadcastRollUpdate(itemID, playerName, value, rollType)
    SendRollSyncMessage("RU~" .. itemID .. "~" .. playerName .. "~" .. value .. "~" .. rollType)
end

local function BroadcastRollTie(itemID, namesCommaSeparated)
    SendRollSyncMessage("RT~" .. itemID .. "~" .. namesCommaSeparated)
end

local function BroadcastRollWinner(itemID, winner, score, roll, poolCode)
    SendRollSyncMessage("RW~" .. itemID .. "~" .. winner .. "~" .. score .. "~" .. roll .. "~" .. poolCode)
end

local function BroadcastRollCancel(itemID, reason)
    SendRollSyncMessage("RC~" .. itemID .. "~" .. reason)
end

-- AW~itemID~Gewinner~PoolCode -- unabhängig vom eigentlichen Roll-
-- Fortschritt (RS/RU/RT/RW), da eine Vergabe auch ganz ohne Roll
-- zustande kommen kann (manuell im Verwalten-Fenster, Bankreserve-
-- Auto-Vergabe, Raid Roll). Wird an genau der Stelle ausgelöst, an der
-- auch das lokale Loot-Log geschrieben wird (siehe LogAward-Aufrufer),
-- deckt also automatisch JEDEN Vergabeweg ab.
--
-- Eigener Sende-Gate (nicht SendRollSyncMessage): AW-Nachrichten werden
-- auch fürs Trade-Tracking gebraucht (siehe Abschnitt 4c) -- Roll-Sync und
-- Trade-Tracking sind zwei unabhängig aktivierbare Optionen, die sich nur
-- denselben Addon-Message-Kanal teilen. Gesendet wird daher, sobald EINE
-- der beiden Optionen aktiv ist.
local function SendAwardOrTradeMessage(text)
    if not (BananaLoot:GetRollSyncEnabled() or BananaLoot:GetTradeTrackingEnabled()) then return end
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then return end
    local channel = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    pcall(function() SendAddonMessage(ROLL_SYNC_PREFIX, text, channel) end)
end

local function BroadcastAward(itemID, winnerName, poolCode)
    SendAwardOrTradeMessage("AW~" .. itemID .. "~" .. winnerName .. "~" .. poolCode)
end

-- ============================================================
-- 4c) TRADE-TRACKING: erkennt automatisch, wenn ein über BananaLoot
-- vergebenes Item per Handel an einen anderen Spieler weitergegeben wird.
-- Nur für Items, die BananaLoot selbst vergeben hat (BananaLoot_DB.
-- awardedItems, siehe AwardItem/AwardBankReserveItem) -- beliebige andere
-- Trades im Raid werden bewusst ignoriert.
--
-- WICHTIG: Die WoW-Trade-API zeigt IMMER nur die eigene Handelsseite. Ein
-- Trade zwischen zwei anderen Spielern ist nur erkennbar, wenn EINER der
-- beiden BananaLoot mit aktiviertem Trade-Tracking ausführt -- dessen
-- Client erkennt den Trade lokal und meldet ihn per Addon-Nachricht (TT)
-- an alle anderen Trade-Tracking-Clients im Raid/der Gruppe weiter,
-- analog zum bestehenden Roll-Sync-Mechanismus. Ohne mindestens einen
-- Trade-Tracking-Teilnehmer im Trade bleibt die Weitergabe unsichtbar --
-- eine harte Grenze der Addon-API, keine Lücke in der Umsetzung.
-- ============================================================
local function BroadcastTrade(itemID, fromName, toName)
    SendAwardOrTradeMessage("TT~" .. itemID .. "~" .. fromName .. "~" .. toName)
end

-- Liefert best-effort einen reinen Item-Namen (ohne Farbe/Link) zu einer
-- Item-ID, fuer den Log-Abgleich in RecordTradeHandoff -- dieselbe
-- Fallback-Kette (statische DB zuerst, dann GetItemInfo) wie an anderen
-- Stellen im Addon (siehe z.B. ResolveHistoryItemDisplay in
-- BananaLootExtra.lua), hier aber ohne Farbcodierung/Link, da nur der
-- reine Name mit dem im Loot-Log gespeicherten Namen verglichen wird.
local function ResolveItemNameForItemID(itemID)
    local staticInfo = BananaLoot:GetStaticItemInfo(itemID)
    if staticInfo and staticInfo.name then return staticInfo.name end
    return GetItemInfo("item:" .. itemID .. ":0:0:0:0:0:0:0")
end

-- Zentrale Stelle für einen erkannten Besitzerwechsel eines über
-- BananaLoot vergebenen Items -- egal ob lokal im eigenen Handelsfenster
-- erkannt (broadcast=true, siehe HandleTradeMatch weiter unten) oder per
-- TT-Netzwerknachricht von einem anderen Trade-Tracking-Client empfangen
-- (broadcast=false, siehe HandleRollSyncMessage). Aktualisiert den
-- lokalen "wer hat's gerade"-Stand (awardedItems, damit auch mehrfach
-- weitergereichte Items über mehrere Hops verfolgbar bleiben) sowie --
-- falls vorhanden -- den eigenen Loot-Log-Eintrag um "Weitergegeben an"
-- (siehe ExportLogCSV).
function BananaLoot:RecordTradeHandoff(itemID, fromName, toName, broadcast)
    EnsureDB()
    BananaLoot_DB.awardedItems[itemID] = { winner = toName }

    local itemName = ResolveItemNameForItemID(itemID)
    if BananaLoot_DB.log and itemName then
        for i = table.getn(BananaLoot_DB.log), 1, -1 do
            local e = BananaLoot_DB.log[i]
            if e.winner == fromName and e.item == itemName and not e.tradedTo then
                e.tradedTo = toName
                break
            end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("TRADE_DETECTED"), itemName or ("Item " .. itemID), fromName, toName))

    if broadcast then
        BroadcastTrade(itemID, fromName, toName)
    end
end

-- Prüft ein per Handelsfenster beobachtetes Item (siehe SnapshotTradeItems
-- unten): nur wenn "fromName" laut awardedItems der zuletzt bekannte
-- Besitzer dieses über BananaLoot vergebenen Items ist, wird es als
-- Weitergabe gewertet.
function BananaLoot:HandleTradeMatch(itemID, fromName, toName)
    if not self:GetTradeTrackingEnabled() then return end
    EnsureDB()
    local entry = BananaLoot_DB.awardedItems[itemID]
    if not entry or entry.winner ~= fromName then return end
    self:RecordTradeHandoff(itemID, fromName, toName, true)
end

-- Liest die eigene, gerade beidseitig akzeptierte Handelssitzung aus
-- (GetTradePlayerItemLink/GetTradeTargetItemLink liefern nur in diesem
-- kurzen Zeitfenster gültige Daten, siehe TRADE_ACCEPT_UPDATE-Handler in
-- Abschnitt 10) und prüft jeden der bis zu 6 Item-Slots je Seite.
-- UnitName("NPC") ist trotz des irreführenden Namens der korrekte
-- Unit-Token für den Handelspartner (Blizzard-FrameXML-Konvention).
local function SnapshotTradeItems()
    if not BananaLoot:GetTradeTrackingEnabled() then return end
    local partnerName = UnitName("NPC")
    if not partnerName then return end
    local myName = UnitName("player")

    for i = 1, 6 do
        local givenLink = GetTradePlayerItemLink(i)
        if givenLink then
            local id = GetItemIDFromLink(givenLink)
            if id then BananaLoot:HandleTradeMatch(id, myName, partnerName) end
        end
        local receivedLink = GetTradeTargetItemLink(i)
        if receivedLink then
            local id = GetItemIDFromLink(receivedLink)
            if id then BananaLoot:HandleTradeMatch(id, partnerName, myName) end
        end
    end
end

-- ============================================================
-- 5) ROLL-ERFASSUNG (MS / Off-Spec / Transmog, automatische Auswertung)
-- ============================================================
-- activeRoll = {
--   itemID, link, rolls = { [name] = { value=, type="ms"/"os"/"tmog" } },
--   srEligible (Set oder nil), restricted (bool),
--   waitFor (Set oder nil, zum Auto-Abschluss), restrictTo (Set oder nil, Tie-Break),
--   running, startTime, maxDuration, winner, winnerScore, winnerRoll, winnerPool
--   (winner/winnerScore/winnerRoll/winnerPool/winnerPoolCode sind immer nur
--   ein Spiegel des ERSTEN Eintrags von confirmedWinners, siehe unten --
--   fuer Alt-Code/Sync, der weiterhin nur EINEN Gewinner kennt),
--   slots (Anzahl gleichzeitig zu vergebender Kopien, Standard 1),
--   confirmedWinners (Array { name, score, roll, pool, poolCode, awarded },
--   fuer "Top N gewinnen" bei Mehrfachdrops, siehe GetMultiWinnerEnabled),
--   awardedCount (wie viele confirmedWinners bereits per AwardItem
--   vergeben wurden -- steuert, wann /bl auto zum naechsten Item weiterzieht),
--   lossBonusApplied (Merker, damit der SR+-Verlustbonus bei mehreren
--   Gewinnern nur EINMAL fuer den ganzen Roll vergeben wird)
-- }

BananaLoot.activeRoll = nil
BananaLoot.autoRunning = false
BananaLoot.lootQueue = {}
BananaLoot.lastLootSignature = nil -- Signatur (sortierte Item-IDs) des zuletzt angekündigten Loot-Fensters, siehe OnLootOpened
-- Ist gerade eine Loot-Session offen? GetNumLootItems/GetLootSlotLink/
-- GiveMasterLoot funktionieren in Vanilla NUR, solange das Kadaver-Fenster
-- wirklich offen ist -- siehe AssignLoot/FlushPendingAwards (Abschnitt 8).
BananaLoot.lootWindowOpen = false
-- Verhindert, dass LOOT_CLOSED_WARN mehrfach hintereinander im Chat
-- ausgegeben wird -- das LOOT_CLOSED-Event kann pro tatsächlichem
-- Schließvorgang mehrfach feuern. Wird bei LOOT_OPENED wieder freigegeben,
-- siehe Abschnitt 10 (Event Handling).
BananaLoot.lootClosedWarned = false
-- Vergaben, die mangels offenem Loot-Fenster nicht zugewiesen werden konnten
-- und beim nächsten Öffnen desselben Kadavers automatisch nachgeholt werden.
BananaLoot.pendingAwards = {}

function BananaLoot:StartRoll(itemID, maxDuration, forceOpen, providedLink)
    if self:IsHardReserve(itemID) then
        DEFAULT_CHAT_FRAME:AddMessage(self:L("ROLL_HARD_RESERVE_BLOCKED"))
        return false
    end
    if self:IsBankReserve(itemID) then
        DEFAULT_CHAT_FRAME:AddMessage(self:L("ROLL_BANK_RESERVE_BLOCKED"))
        return false
    end
    local res = self.reservations[itemID]
    -- providedLink: expliziter Item-Link, z.B. von /bl arf mit einem Item,
    -- das nicht aus dem aktuell offenen Loot-Fenster stammt (z.B. Test aus
    -- dem eigenen Inventar). Wird zusätzlich in knownLootItems hinterlegt,
    -- damit das Item im Hauptfenster sichtbar bleibt und z.B. nach
    -- "Niemand hat gerollt" ganz normal per Klick erneut verrollt oder
    -- manuell vergeben werden kann.
    if providedLink and not self.knownLootItems[itemID] and not (res and res.link) then
        self.knownLootItems[itemID] = providedLink
    end
    -- Fallback-Reihenfolge: reservierter Link -> zuletzt im Loot-Fenster
    -- gescannter Link -> übergebener Link -> erst zuletzt der reine
    -- "item:ID..."-String ohne Namen (nur falls wirklich keine der drei
    -- anderen Quellen etwas liefert). Vorher wurde dieser rohe String zu
    -- früh verwendet, wodurch im Chat nur die Item-ID statt "[Itemname]"
    -- zu sehen war.
    local link = (res and res.link) or self.knownLootItems[itemID] or providedLink or ("item:" .. itemID .. ":0:0:0:0:0:0:0")
    local eligible, restricted = GetEligiblePlayers(itemID)
    if forceOpen then
        eligible, restricted = GetCurrentRosterSet(), false
    end

    -- "Top N gewinnen" (siehe GetMultiWinnerEnabled): liegen mehrere
    -- Kopien desselben Items im Loot-Fenster, wird EIN gemeinsamer Roll
    -- gestartet, bei dem die besten N Werfer je eine Kopie gewinnen,
    -- statt wie bisher jede Kopie einzeln nacheinander zu verrollen.
    -- Ohne aktivierte Option (Standard) bleibt slots immer 1 -- dann
    -- verhaelt sich die komplette Auswertung weiter exakt wie zuvor.
    local slots = 1
    if self:GetMultiWinnerEnabled() and self.lootCounts[itemID] and self.lootCounts[itemID] > 1 then
        slots = self.lootCounts[itemID]
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
        slots = slots,
        confirmedWinners = {},
        awardedCount = 0,
        lossBonusApplied = false,
    }

    local syncMode = 0
    if restricted then syncMode = 1 elseif forceOpen then syncMode = 2 end
    BroadcastRollStart(itemID, self.activeRoll.maxDuration, syncMode)

    local channel = self:GetAnnounceChannel()
    local howTo = self:L("ROLL_HOWTO")
    -- Zusaetzlicher Hinweis im Ankuendigungstext, wenn mehrere Kopien in
    -- diesem einen Roll vergeben werden -- der reine Item-Link (ar.link)
    -- bleibt dabei unveraendert, damit Tooltip/Sync/spaetere Vergabe
    -- weiterhin den echten Item-Link nutzen.
    local announceLink = link
    if slots > 1 then
        announceLink = link .. string.format(self:L("ROLL_SLOTS_SUFFIX"), slots)
    end

    if restricted then
        local names = ""
        for i = 1, table.getn(res.order) do
            local n = res.order[i]
            local stack = self:GetStack(n, itemID)
            names = names .. n .. (stack > 0 and ("(+" .. (stack * self:GetBonusPerStack()) .. ")") or "") .. " "
        end
        SendChatMessage(string.format(self:L("ROLL_ANNOUNCE_SR"), announceLink, names, howTo), channel)
    elseif forceOpen then
        SendChatMessage(string.format(self:L("ROLL_ANNOUNCE_ARF"), announceLink, howTo), channel)
    else
        SendChatMessage(string.format(self:L("ROLL_ANNOUNCE_OPEN"), announceLink, howTo), channel)
    end

    self:PlayEventSound("RaidWarning", self:GetSoundRollStartedEnabled())

    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
    return true
end

function BananaLoot:StopRoll()
    if self.activeRoll then
        BroadcastRollCancel(self.activeRoll.itemID, 0)
    end
    self.activeRoll = nil
end

-- Wird bei jedem erkannten "X rolls Y (1-100/99/98)" System-Chat aufgerufen.
function BananaLoot:OnRoll(name, value, rollType)
    local ar = self.activeRoll
    if not ar or not ar.running then return end
    if ar.rolls[name] then return end -- Mehrfachroll ignorieren

    if ar.restrictTo and not ar.restrictTo[name] then return end -- Tie-Break: nur betroffene Spieler
    -- Item SR't -> Hauptspec-Rolls nur für Reservierer. Ausnahme: läuft
    -- bereits ein Tie-Break (ar.restrictTo gesetzt), ist die Teilnehmerliste
    -- ohnehin fixiert -- dann darf ein Gleichstands-Teilnehmer auch mit einem
    -- normalen /roll erneut würfeln, statt dass sein Wurf stumm verworfen
    -- wird und der Tie-Break in den Timeout und "Niemand hat gerollt" läuft.
    if rollType == "ms" and ar.srEligible and not ar.restrictTo and not ar.srEligible[name] then return end

    ar.rolls[name] = { value = value, type = rollType }
    BroadcastRollUpdate(ar.itemID, name, value, rollType)

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

-- Liefert ALLE Wuerfe eines Pools absteigend nach Wertung (Wurf + ggf. SR+
-- Bonus) sortiert zurueck -- statt wie bisher nur den/die Bestplatzierten.
-- Wird fuer "Top N gewinnen" gebraucht: ResolveActiveRoll liest sich davon
-- gruppenweise (je Wertung) so viele Plaetze, wie noch frei sind.
local function EvaluatePool(pool, useBonus, itemID)
    local scored = {}
    for i = 1, table.getn(pool) do
        local entry = pool[i]
        local bonus = 0
        if useBonus then bonus = BananaLoot:GetStack(entry.name, itemID) * BananaLoot:GetBonusPerStack() end
        table.insert(scored, { name = entry.name, roll = entry.value, score = entry.value + bonus })
    end
    table.sort(scored, function(a, b) return a.score > b.score end)
    return scored
end

-- Wertet den aktuellen Roll aus. Priorität: Hauptspec > Off-Spec > Transmog.
-- Bei Gleichstand: nur die betroffenen Spieler müssen erneut rollen.
--
-- "Top N gewinnen" (ar.slots > 1, siehe GetMultiWinnerEnabled/StartRoll):
-- statt nur des Bestplatzierten werden die besten ar.slots Werfer als
-- Gewinner uebernommen (ar.confirmedWinners). Liegt die Wertungsgrenze
-- mitten in einer Gleichstand-Gruppe (mehr Gleichstaendige als noch freie
-- Plaetze), muessen nur diese betroffenen Spieler um die restlichen
-- Plaetze erneut wuerfeln -- bereits sicher platzierte Gewinner aus
-- frueheren Runden bleiben dabei unangetastet. Bei ar.slots == 1 (Standard,
-- Option aus) reduziert sich das exakt auf die bisherige Einzel-Gewinner-
-- Logik inkl. identischer Chat-/Sync-Nachrichten.
function BananaLoot:ResolveActiveRoll()
    local ar = self.activeRoll
    if not ar then return end

    local pools = { ms = {}, os = {}, tmog = {} }
    for name, data in pairs(ar.rolls) do
        -- Bei einem laufenden Tie-Break (restrictTo gesetzt) dürfen NUR die
        -- Rolls der aktuell betroffenen Spieler zählen. Alte Rolls von
        -- Spielern, die bereits vor dem Gleichstand ausgeschieden sind,
        -- bleiben zwar in ar.rolls stehen (für die Anzeige), dürfen aber
        -- nicht erneut in die Auswertung einfließen.
        if not ar.restrictTo or ar.restrictTo[name] then
            table.insert(pools[data.type], { name = name, value = data.value })
        end
    end

    local scored, poolLabel, poolCode

    if table.getn(pools.ms) > 0 then
        scored = EvaluatePool(pools.ms, true, ar.itemID)
        poolLabel = self:L("POOL_MS")
        poolCode = "ms"
    elseif table.getn(pools.os) > 0 then
        scored = EvaluatePool(pools.os, false, ar.itemID)
        poolLabel = self:L("POOL_OS")
        poolCode = "os"
    elseif table.getn(pools.tmog) > 0 then
        scored = EvaluatePool(pools.tmog, false, ar.itemID)
        poolLabel = self:L("POOL_TMOG")
        poolCode = "tmog"
    elseif table.getn(ar.confirmedWinners) == 0 then
        ar.running = false
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("ROLL_NOBODY_ROLLED"), ar.link))
        BroadcastRollCancel(ar.itemID, 1)
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        if self.autoRunning then
            self.activeRoll = nil
            self:AutoAdvance()
        end
        return
    else
        -- Mehrfachdrop ("Top N gewinnen"): für den/die verbleibenden Platz/
        -- Plätze hat niemand (erneut) gerollt. Bereits in früheren Runden
        -- bestätigte Gewinner bleiben gültig und werden ganz normal
        -- angekündigt und vergeben, statt den kompletten Roll zu verwerfen.
        -- Leeres "scored" -> die Platzvergabe-Schleife unten läuft nullmal,
        -- es entsteht kein neuer Gleichstand, der Roll wird abgeschlossen.
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("ROLL_NOBODY_ROLLED_REST"), ar.link))
        scored = {}
        poolLabel = ar.confirmedWinners[1].pool
        poolCode = ar.confirmedWinners[1].poolCode
        ar.restrictTo = nil
    end

    local remainingSlots = (ar.slots or 1) - table.getn(ar.confirmedWinners)
    if remainingSlots < 1 then remainingSlots = 1 end

    -- Wertungs-Gruppen (gleicher Score) nacheinander uebernehmen, solange
    -- die komplette Gruppe noch in die verbleibenden Plaetze passt. Passt
    -- eine Gruppe nicht mehr komplett hinein, ist das der Gleichstand, der
    -- erneut verwuerfelt werden muss (bei ar.slots == 1 identisch zur
    -- bisherigen "table.getn(winners) > 1"-Pruefung).
    local idx, total = 1, table.getn(scored)
    local tieGroup, tieScore = nil, nil
    while idx <= total and remainingSlots > 0 do
        local currentScore = scored[idx].score
        local group = {}
        local j = idx
        while j <= total and scored[j].score == currentScore do
            table.insert(group, scored[j])
            j = j + 1
        end
        if table.getn(group) <= remainingSlots then
            for g = 1, table.getn(group) do
                table.insert(ar.confirmedWinners, {
                    name = group[g].name, score = group[g].score, roll = group[g].roll,
                    pool = poolLabel, poolCode = poolCode, awarded = false,
                })
            end
            remainingSlots = remainingSlots - table.getn(group)
            idx = j
        else
            tieGroup, tieScore = group, currentScore
            break
        end
    end

    if tieGroup then
        local names = ""
        local namesSync = ""
        local newEligible = {}
        for i = 1, table.getn(tieGroup) do
            names = names .. tieGroup[i].name .. " "
            if i > 1 then namesSync = namesSync .. "," end
            namesSync = namesSync .. tieGroup[i].name
            newEligible[tieGroup[i].name] = true
            ar.rolls[tieGroup[i].name] = nil
        end
        ar.restrictTo = newEligible
        ar.startTime = GetTime()
        SendChatMessage(string.format(self:L("ROLL_TIE"), poolLabel, tieScore, names), self:GetAnnounceChannel())
        BroadcastRollTie(ar.itemID, namesSync)
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        return
    end

    ar.running = false

    -- winner/winnerScore/.../winnerPoolCode bleiben als Spiegel des ERSTEN
    -- Gewinners erhalten -- fuer Alt-Code (z.B. AwardItem's Pool-Fallback,
    -- /bl award bei genau einem Gewinner), der weiterhin nur ein einzelnes
    -- Gewinner-Feld kennt. Bei ar.slots == 1 ist das ohnehin der einzige
    -- Gewinner.
    if table.getn(ar.confirmedWinners) > 0 then
        local first = ar.confirmedWinners[1]
        ar.winner = first.name
        ar.winnerScore = first.score
        ar.winnerRoll = first.roll
        ar.winnerPool = first.pool
        ar.winnerPoolCode = first.poolCode
    end

    self:PlayEventSound("LEVELUP", self:GetSoundWinnerEnabled())

    if table.getn(ar.confirmedWinners) <= 1 then
        -- Einzelgewinner: unveraendert identisch zur bisherigen Logik/Texten.
        local w = ar.confirmedWinners[1]
        if w then
            DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("ROLL_WINNER_CHAT"), poolLabel, ar.link, w.name, w.roll, w.score))
            SendChatMessage(string.format(self:L("ROLL_WINNER_ANNOUNCE"), w.name, ar.link, poolLabel), self:GetAnnounceChannel())
            BroadcastRollWinner(ar.itemID, w.name, w.score, w.roll, poolCode)
        end
    else
        -- Mehrere Gewinner ("Top N gewinnen"): jeder bekommt seine eigene
        -- Chat-Zeile wie gewohnt, zusaetzlich eine gemeinsame Sammel-
        -- Ankuendigung im Raid-/Gruppenchat. Der Roll-Sync-Broadcast (RW)
        -- kennt weiterhin nur EIN Score/Wurf-Feldpaar (Wire-Format bleibt
        -- kompatibel) -- hier bewusst die Werte des Bestplatzierten, die
        -- Namen aller Gewinner werden komma-getrennt mitgesendet.
        local namesList = ""
        local namesSync = ""
        for i = 1, table.getn(ar.confirmedWinners) do
            local w = ar.confirmedWinners[i]
            if i > 1 then namesList = namesList .. ", "; namesSync = namesSync .. "," end
            namesList = namesList .. w.name .. " (" .. w.roll .. "/" .. w.score .. ")"
            namesSync = namesSync .. w.name
            DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("ROLL_WINNER_CHAT"), w.pool, ar.link, w.name, w.roll, w.score))
        end
        -- Chat-Zeilen sind auf 255 Zeichen begrenzt; der Client schneidet
        -- längere Nachrichten kommentarlos ab. Bei sehr vielen Gewinnern
        -- deshalb kürzen statt die Zeile verstümmeln zu lassen.
        local winnersMsg = string.format(self:L("ROLL_WINNERS_ANNOUNCE"), ar.link, poolLabel, namesList)
        if string.len(winnersMsg) > 255 then
            winnersMsg = string.sub(winnersMsg, 1, 252) .. "..."
        end
        SendChatMessage(winnersMsg, self:GetAnnounceChannel())
        local top = ar.confirmedWinners[1]
        BroadcastRollWinner(ar.itemID, namesSync, top.score, top.roll, poolCode)
    end

    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
end

-- ============================================================
-- 6) VERGABE (Award) -> löst SR+ Buchung aus, versucht automatisch zuzuweisen
-- ============================================================
-- skipLossBonus: wird NUR von AwardMultiRollWinner (Mehrfachdrop, "Top N
-- gewinnen") mit true übergeben, da dort der SR+-Verlustbonus für die
-- NICHT gewinnenden Reservierer bereits zentral EINMAL für den ganzen Roll
-- vergeben wurde (siehe ApplyLossBonus) -- der Standard-Aufruf (manuelle
-- Vergabe, Raid Roll, normaler Einzelroll) lässt diesen Parameter weg und
-- verhält sich exakt wie bisher.
function BananaLoot:AwardItem(itemID, winnerName, poolOverride, poolCodeOverride, skipLossBonus)
    local res = self.reservations[itemID]
    local link = (res and res.link) or self.knownLootItems[itemID] or ("Item " .. itemID)

    local assigned, failReason = self:AssignLoot(itemID, winnerName)

    -- Kategorie für das Log ermitteln (Hauptspec/Off-Spec/Transmog/Manuell/
    -- Raid Roll). poolOverride hat Vorrang (z.B. explizit "Raid Roll"),
    -- sonst wird wie bisher versucht, sie vom letzten aktiven Roll zu
    -- übernehmen. poolCode ist das sprachunabhängige Pendant dazu, nur
    -- für den Roll-Sync-Broadcast/die geteilte Historie gebraucht (siehe
    -- BroadcastAward) -- die lokale Anzeige/CSV nutzt weiterhin poolLabel.
    local poolLabel = poolOverride or self:L("POOL_MANUAL")
    local poolCode = poolCodeOverride or "manual"
    if not poolOverride and self.activeRoll and self.activeRoll.itemID == itemID and self.activeRoll.winnerPool then
        poolLabel = self.activeRoll.winnerPool
        poolCode = self.activeRoll.winnerPoolCode or poolCode
    end
    self:LogAward(link, winnerName, poolLabel)
    EnsureDB()
    BananaLoot_DB.awardedItems[itemID] = { winner = winnerName }
    BroadcastAward(itemID, winnerName, poolCode)
    if BananaLoot_UI and BananaLoot_UI.AddHistoryEntry then
        BananaLoot_UI:AddHistoryEntry(itemID, winnerName, poolCode)
    end

    self:ResetStack(winnerName, itemID)
    if res then
        if not skipLossBonus then
            for i = 1, table.getn(res.order) do
                local n = res.order[i]
                if n ~= winnerName then self:IncrementStack(n, itemID) end
            end
        end
        -- Gewinner aus der Reservierung entfernen (nicht die ganze Reservierung
        -- löschen!): fällt dasselbe Item ein zweites Mal, darf derselbe Spieler
        -- nicht nochmal gewinnen, aber übrige Reservierer bleiben für den
        -- nächsten Roll dieses Items berechtigt.
        if res.players[winnerName] then
            res.players[winnerName] = nil
            RemovePlayerFromOrder(res.order, winnerName)
        end
        self:RemoveItemFromPlayerList(winnerName, itemID)
    end

    self:PlayEventSound("igMainMenuOptionCheckBoxOn", self:GetSoundAwardEnabled())

    if assigned then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_ASSIGNED"), link, winnerName))
    elseif failReason == "noloot" then
        -- Häufigster Fall: das Kadaver-Fenster ist zwischenzeitlich zugegangen
        -- (Bewegung, ESC, zu weit weg). Vergabe vormerken -- sie wird beim
        -- erneuten Anklicken des Kadavers automatisch nachgeholt.
        self:QueuePendingAward(itemID, winnerName, link)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_FAIL_NOLOOT"), link, winnerName))
    elseif failReason == "nocand" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_FAIL_NOCAND"), link, winnerName))
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_NOT_ASSIGNED"), link, winnerName))
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

    -- rollDone: bei "Top N gewinnen" (ar.slots > 1) läuft AwardItem einmal
    -- PRO Gewinner -- der Roll selbst ist aber erst fertig, wenn ALLE
    -- Plätze vergeben sind (ar.awardedCount erreicht ar.slots). Erst dann
    -- wird der Roll geschlossen und /bl auto darf zum nächsten Item in der
    -- Warteschlange weiterziehen. Bei ar.slots == 1 (Standard) ist das nach
    -- diesem einen Aufruf sofort der Fall -- unverändert zum bisherigen
    -- Verhalten.
    local rollDone = true
    if self.activeRoll and self.activeRoll.itemID == itemID then
        self.activeRoll.awardedCount = (self.activeRoll.awardedCount or 0) + 1
        rollDone = self.activeRoll.awardedCount >= (self.activeRoll.slots or 1)
        if rollDone then self.activeRoll = nil end
    end

    if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    if self.autoRunning then
        if assigned then
            if rollDone then self:AutoAdvance() end
        else
            self.autoRunning = false
            DEFAULT_CHAT_FRAME:AddMessage(self:L("AUTO_PAUSED"))
            pcall(function() PlaySound("RaidWarning") end)
        end
    end
end

-- Vergibt SR+-Verlustbonus fuer alle Reservierer eines Items, die NICHT in
-- winnerNames stehen -- zentral EINMAL pro Roll aufgerufen (siehe
-- AwardMultiRollWinner), damit bei mehreren Gewinnern ("Top N gewinnen")
-- niemand mehrfach SR+ fuer denselben verlorenen Roll bekommt.
function BananaLoot:ApplyLossBonus(itemID, winnerNames)
    local res = self.reservations[itemID]
    if not res then return end
    local winnerSet = {}
    for i = 1, table.getn(winnerNames) do winnerSet[winnerNames[i]] = true end
    for i = 1, table.getn(res.order) do
        local n = res.order[i]
        if not winnerSet[n] then self:IncrementStack(n, itemID) end
    end
end

-- Vergibt EINEN Gewinner eines Mehrfachdrop-Rolls ("Top N gewinnen",
-- ar.confirmedWinners mit mehr als einem Eintrag). Der SR+-Verlustbonus
-- für alle NICHT gewinnenden Reservierer wird beim allerersten Aufruf für
-- diesen Roll zentral einmal vergeben (ar.lossBonusApplied), AwardItem
-- selbst bekommt skipLossBonus=true, damit sein eigener (für Einzelrolls
-- gedachter) Verlust-Bonus-Loop nicht zusätzlich greift.
function BananaLoot:AwardMultiRollWinner(itemID, winnerName)
    local ar = self.activeRoll
    if ar and ar.itemID == itemID and ar.confirmedWinners and not ar.lossBonusApplied then
        local names = {}
        for i = 1, table.getn(ar.confirmedWinners) do
            table.insert(names, ar.confirmedWinners[i].name)
        end
        self:ApplyLossBonus(itemID, names)
        ar.lossBonusApplied = true
    end

    local poolOverride, poolCodeOverride = nil, nil
    if ar and ar.confirmedWinners then
        for i = 1, table.getn(ar.confirmedWinners) do
            local w = ar.confirmedWinners[i]
            if w.name == winnerName and not w.awarded then
                poolOverride, poolCodeOverride = w.pool, w.poolCode
                w.awarded = true
            end
        end
    end

    self:AwardItem(itemID, winnerName, poolOverride, poolCodeOverride, true)
end

-- Vergibt ein Bank-Reserve-Item automatisch und lautlos an den Lootmaster
-- selbst: kein Roll, keine Ankündigung im Raid-/Gruppenchat. Die einzige
-- Rückmeldung ist eine lokale Chatzeile (nur für dich sichtbar), damit du
-- nachvollziehen kannst, was automatisch vergeben wurde.
function BananaLoot:AwardBankReserveItem(itemID, link)
    local myName = UnitName("player")
    local assigned = self:AssignLoot(itemID, myName)

    self:LogAward(link, myName, self:L("POOL_BANK"))
    EnsureDB()
    BananaLoot_DB.awardedItems[itemID] = { winner = myName }

    if assigned then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_BANK_AUTO"), link))
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_BANK_AUTO_FAILED"), link))
    end

    self.knownLootItems[itemID] = nil
    self.lootCounts[itemID] = nil
end

-- Filtert Bank-Reserve-Items aus einer Item-Liste heraus und vergibt sie
-- dabei sofort automatisch. Gibt die verbleibende Liste (ohne BR-Items)
-- zurück -- gemeinsame Hilfsfunktion für OnLootOpened und /bl auto, damit
-- BR-Items in beiden Fällen konsistent behandelt werden.
function BananaLoot:ProcessBankReserveItems(items)
    local remaining = {}
    for i = 1, table.getn(items) do
        local it = items[i]
        if self:IsBankReserve(it.itemID) then
            self:AwardBankReserveItem(it.itemID, it.link)
        else
            table.insert(remaining, it)
        end
    end
    return remaining
end

function BananaLoot:AwardActiveWinner()
    local ar = self.activeRoll
    if not ar or ar.running or not ar.confirmedWinners or table.getn(ar.confirmedWinners) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(self:L("AWARD_NO_WINNER"))
        return
    end
    if table.getn(ar.confirmedWinners) == 1 then
        self:AwardItem(ar.itemID, ar.winner)
    else
        -- Mehrfachdrop ("Top N gewinnen"): /bl award vergibt alle noch
        -- offenen Gewinner dieses Rolls nacheinander in einem Rutsch.
        local itemID = ar.itemID
        local winners = ar.confirmedWinners
        for i = 1, table.getn(winners) do
            if not winners[i].awarded then
                self:AwardMultiRollWinner(itemID, winners[i].name)
            end
        end
    end
end

-- Vergibt ein Item per Zufallsauswahl unter ALLEN aktuell im Raid/der Gruppe
-- anwesenden Spielern (unabhängig von SR-Reservierungen). Es findet kein
-- echter /roll der Spieler statt -- die Auswahl passiert vollständig lokal,
-- nur das Ergebnis wird im Raid-/Gruppenchat angesagt.
function BananaLoot:DoRaidRoll(itemID)
    local names = self:GetRosterNames()
    if table.getn(names) == 0 then return false end

    local res = self.reservations[itemID]
    local link = (res and res.link) or self.knownLootItems[itemID] or ("Item " .. itemID)

    local winner = names[math.random(1, table.getn(names))]

    SendChatMessage(string.format(self:L("RAID_ROLL_ANNOUNCE"), link, winner), self:GetAnnounceChannel())

    self:AwardItem(itemID, winner, self:L("POOL_RAIDROLL"), "raidroll")
    return true, winner
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
            if id then
                -- GetLootSlotInfo liefert den Icon-Pfad direkt aus dem
                -- Loot-Fenster-Datenpaket -- eine andere Quelle als
                -- GetItemInfo/GetItemIcon, die auf manchen Servern nur
                -- eine für den Client nutzlose numerische ID liefern.
                local lootIcon = GetLootSlotInfo(slot)
                table.insert(items, { itemID = id, link = link, icon = lootIcon })
            end
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

-- Baut eine einfache Signatur (sortierte, kommagetrennte Item-IDs) aus
-- der aktuell im Loot-Fenster sichtbaren Item-Menge. Dient in
-- OnLootOpened als Erkennung, ob dasselbe Loot-Fenster (z.B. derselbe
-- Boss-Kadaver) lediglich erneut geöffnet wurde, ohne dass sich der
-- Inhalt seit der letzten Ankündigung geändert hat -- Vanilla liefert
-- keine eindeutige Loot-Quelle-ID, daher dieser Kompromiss über den
-- reinen Item-Inhalt. Einschränkung: zwei verschiedene Kadaver mit
-- zufällig identischer Item-Menge würden fälschlich als "gleich"
-- erkannt; in der Praxis (unterschiedliche Bosse/Trash) sehr selten.
local function BuildLootSignature(items)
    local ids = {}
    for i = 1, table.getn(items) do
        table.insert(ids, items[i].itemID)
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

-- Aktualisiert BananaLoot.knownLootItems mit den aktuell im Loot-Fenster
-- sichtbaren Items (auch ohne SR), rein zur Anzeige im UI, unabhängig
-- von der Auto-Modus-Queue.
function BananaLoot:RefreshKnownLootItems()
    local items = self:ScanLootWindow()
    local map = {}
    for i = 1, table.getn(items) do
        local it = items[i]
        if not self:IsBankReserve(it.itemID) then
            map[it.itemID] = it.link
            -- Additiv befüllen (nicht überschreiben mit nil): einmal gelernte
            -- Icons bleiben auch nach Schließen des Loot-Fensters erhalten,
            -- damit die Zeile im Hauptfenster weiterhin ein Icon zeigen kann.
            if it.icon and it.icon ~= "" then
                self.knownLootIcons[it.itemID] = it.icon
            end
            -- Hat dieses Item aktuell nur einen rohen Platzhalter-Link (z.B.
            -- aus einem raidres.top-Import, ohne echten Namen), aber wird jetzt
            -- TATSÄCHLICH gelootet, liefert GetLootSlotLink hier einen echten,
            -- vollständigen Link -- den nutzen wir, um die Reservierung sofort
            -- auf den echten Namen/Icon aufzuwerten.
            local res = self.reservations[it.itemID]
            if res and res.link and not string.find(res.link, "|Hitem:") then
                res.link = it.link
            end
        end
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
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("PRUNE_REMOVED"), table.concat(removedNames, ", ")))
    end
end

-- Maximale Anzahl namentlich genannter Reservierer je Item in der
-- Loot-Vorschau (siehe AnnounceLootPreview), danach "+N weitere" -- der
-- Raid-/Gruppenchat hat wie jede Chatzeile ein Zeichenlimit, bei sehr
-- vielen Reservierern auf ein Item soll die Zeile nicht abgeschnitten
-- werden.
local LOOT_PREVIEW_MAX_PLAYERS = 8

-- Postet einmalig (siehe Aufrufer OnLootOpened) eine Item-für-Item-
-- Übersicht im Raid-/Gruppenchat, BEVOR irgendein Roll gestartet wurde,
-- damit alle Spieler vorab sehen, wie jedes Item vergeben wird:
--   [Item] [SR]: Name(+Bonus), Name2, ... -- SR-reserviert
--   [Item] [HR]                            -- Hard Reserve, manuell
--   [Item] [Offen]/[Open]                  -- frei für alle, jeder darf rollen
-- Bankreserve-Items sind hier bewusst NIE dabei (per Definition lautlos,
-- siehe ProcessBankReserveItems -- die werden schon vor dem Aufruf
-- dieser Funktion aus der Item-Liste entfernt und vergeben).
function BananaLoot:AnnounceLootPreview(items)
    if not self:GetLootPreviewEnabled() then return end
    local channel = self:GetAnnounceChannel()

    for i = 1, table.getn(items) do
        local it = items[i]
        local res = self.reservations[it.itemID]
        local qty = self.lootCounts[it.itemID]
        local qtyTxt = (qty and qty > 1) and string.format(self:L("UI_QTY"), qty) or ""
        local line

        if self:IsHardReserve(it.itemID) then
            line = it.link .. qtyTxt .. self:L("UI_TAG_HR")
        elseif res and table.getn(res.order) > 0 then
            local names = ""
            local total = table.getn(res.order)
            local shownCount = total
            if shownCount > LOOT_PREVIEW_MAX_PLAYERS then shownCount = LOOT_PREVIEW_MAX_PLAYERS end
            for p = 1, shownCount do
                local n = res.order[p]
                local stack = self:GetStack(n, it.itemID)
                names = names .. n
                if stack > 0 then names = names .. "(+" .. (stack * self:GetBonusPerStack()) .. ")" end
                if p < shownCount then names = names .. ", " end
            end
            if total > LOOT_PREVIEW_MAX_PLAYERS then
                names = names .. string.format(self:L("UI_PLAYERS_MORE"), total - LOOT_PREVIEW_MAX_PLAYERS)
            end
            line = it.link .. qtyTxt .. self:L("UI_TAG_SR") .. ": " .. names
        else
            line = it.link .. qtyTxt .. self:L("UI_TAG_OPEN")
        end

        SendChatMessage(line, channel)
    end
end

function BananaLoot:OnLootOpened()
    if not IsPlayerMasterLooter() then return end

    self:PruneAbsentReservations()

    local items = self:ScanLootWindow()
    if table.getn(items) == 0 then return end

    items = self:ProcessBankReserveItems(items)
    if table.getn(items) == 0 then return end

    -- Signatur-Abgleich: wurde exakt dasselbe Loot-Fenster (gleicher
    -- Item-Inhalt) bereits angekündigt, z.B. weil derselbe Boss-Kadaver
    -- ein zweites Mal geöffnet wurde, ohne dass sich der Inhalt seither
    -- geändert hat? Dann Sound/Chat-Zusammenfassung/Loot-Vorschau NICHT
    -- erneut auslösen (Spam-Schutz) -- die Item-Daten (Queue, Icons,
    -- Reservierungs-Sichtbarkeit) werden aber trotzdem ganz normal
    -- aktualisiert, damit Roll/Vergabe im Loot-Fenster weiter funktioniert.
    local signature = BuildLootSignature(items)
    local isRepeatOpen = (signature == self.lastLootSignature)

    self.lootQueue = items
    self.lootCounts = BuildLootCounts(items)
    self:RefreshKnownLootItems()

    if not isRepeatOpen then
        self.lastLootSignature = signature

        self:PlayEventSound("AuctionWindowOpen", self:GetSoundLootDetectedEnabled())

        local summary = self:L("LOOT_DETECTED_PREFIX")
        for i = 1, table.getn(items) do
            local it = items[i]
            local res = self.reservations[it.itemID]
            local tag = ""
            if res and table.getn(res.order) > 0 then
                tag = string.format(self:L("LOOT_SR_TAG"), table.getn(res.order))
            end
            summary = summary .. it.link .. tag .. "  "
        end
        DEFAULT_CHAT_FRAME:AddMessage(summary)
        DEFAULT_CHAT_FRAME:AddMessage(self:L("LOOT_HINT"))

        self:AnnounceLootPreview(items)
    end

    -- Separates Loot-Fenster automatisch anzeigen (nicht nur toggeln, damit
    -- ein bereits geöffnetes SR-Fenster davon unberührt bleibt und das
    -- Loot-Fenster nicht versehentlich geschlossen wird, falls es aus
    -- irgendeinem Grund schon offen war).
    if BananaLoot_UI and BananaLoot_UI.ShowLoot then BananaLoot_UI:ShowLoot() end
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

-- Startet den automatischen Loot-Durchlauf: scannt das aktuell offene
-- Loot-Fenster neu, entfernt/vergibt Bankreserve-Items sofort (siehe
-- ProcessBankReserveItems) und arbeitet den Rest der Warteschlange ab.
-- Zentrale Funktion für sowohl /bl auto als auch den Auto-Toggle-Button
-- im Loot-Fenster (BananaLootUI.lua), damit beide exakt dasselbe
-- Verhalten haben und nicht getrennt gepflegt werden müssen.
function BananaLoot:StartAutoMode()
    local items = self:ScanLootWindow()
    items = self:ProcessBankReserveItems(items)
    self.lootQueue = items
    self.lootCounts = BuildLootCounts(items)
    self:AutoAdvance()
end

-- Bricht den Auto-Modus UND einen gerade laufenden Roll sofort ab
-- (im Gegensatz zum Auto-Toggle-Button im Loot-Fenster, der beim
-- Ausschalten einen laufenden Roll bewusst NICHT abbricht -- siehe
-- dort). Zentrale Funktion für sowohl /bl stop als auch den neuen
-- Stop-Button im Loot-Fenster.
function BananaLoot:StopAutoMode()
    self.autoRunning = false
    self:StopRoll()
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
        DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AUTO_SKIPPED_HR"), table.concat(skippedHR, ", ")))
    end

    if table.getn(self.lootQueue) == 0 then
        self.autoRunning = false
        DEFAULT_CHAT_FRAME:AddMessage(self:L("AUTO_ALL_DONE"))
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
-- Das echte Vanilla-1.12-API dokumentiert GetMasterLootCandidate(index)
-- mit nur EINEM Argument (der Slot spielt dabei serverseitig keine Rolle,
-- die Kandidatenliste gilt für die gesamte Lootrunde). Manche private
-- Server implementieren stattdessen die spätere GetMasterLootCandidate(slot,
-- index)-Variante mit zwei Argumenten. Eine "falsche" Signatur liefert nicht
-- zwangsläufig nil zurück -- überzählige Argumente werden von Lua an native
-- Funktionen einfach ignoriert, wodurch z.B. bei der Ein-Argument-Form
-- versehentlich immer derselbe (falsche) Name zurückkommen kann. Deshalb
-- hier ein kompletter Suchdurchlauf je Signatur-Variante statt gemischter
-- Versuche pro Index -- erst wenn die erste Variante gar keinen Treffer
-- liefert, wird die zweite komplett durchprobiert.
-- ignoreCase: Fallback für manuell eingetippte Namen (z.B. über "Gewinner"
-- im Verwalten-Fenster). Rolls aus dem System-Chat liefern die Schreibweise
-- immer exakt, manuelle Eingaben nicht zwangsläufig.
local function FindMasterLootCandidateIndex(lootSlot, winnerName, useSlotArg, ignoreCase)
    local target = winnerName
    if ignoreCase then target = string.lower(winnerName) end
    for i = 1, 40 do
        local ok, name
        if useSlotArg then
            ok, name = pcall(GetMasterLootCandidate, lootSlot, i)
        else
            ok, name = pcall(GetMasterLootCandidate, i)
        end
        if ok and name then
            local cmp = name
            if ignoreCase then cmp = string.lower(name) end
            if cmp == target then return i, name end
        end
    end
    return nil
end

-- Reihenfolge wichtig: BEIDE Ein-Argument-Durchläufe zuerst, erst danach die
-- Zwei-Argument-Variante. Auf einem Ein-Argument-Server (echtes Vanilla-API)
-- liefert der Aufruf mit zwei Argumenten sonst für jeden Index denselben
-- Kandidaten zurück -- und damit potenziell einen falschen Index.
function BananaLoot:TryGiveMasterLoot(lootSlot, winnerName)
    local didAssign = false
    local ok = pcall(function()
        local index = FindMasterLootCandidateIndex(lootSlot, winnerName, false, false)
        if not index then index = FindMasterLootCandidateIndex(lootSlot, winnerName, false, true) end
        if not index then index = FindMasterLootCandidateIndex(lootSlot, winnerName, true, false) end
        if not index then index = FindMasterLootCandidateIndex(lootSlot, winnerName, true, true) end
        if index then
            GiveMasterLoot(lootSlot, index)
            didAssign = true
        end
    end)
    return ok and didAssign
end

-- Sucht das Item im aktuell offenen Loot-Fenster und weist es zu.
-- Rückgabe: true  -> zugewiesen
--           false, "noloot" -> Loot-Fenster ist zu (GetNumLootItems liefert 0)
--           false, "noslot" -> Item liegt nicht (mehr) in diesem Fenster
--           false, "nocand" -> Spieler steht nicht in der Kandidatenliste
--                              (ausser Reichweite, andere Zone, Geist, offline)
-- Zentrale Stelle für ALLE Vergabewege (Roll, /bl award, Verwalten-Fenster,
-- Raid Roll, Bankreserve, Mehrfachgewinner).
function BananaLoot:AssignLoot(itemID, winnerName)
    local n = 0
    local okCount = pcall(function() n = GetNumLootItems() or 0 end)
    if not okCount or n == 0 then return false, "noloot" end

    local foundSlot = nil
    for slot = 1, n do
        local slotLink = GetLootSlotLink(slot)
        if slotLink then
            local _, _, slotItemID = string.find(slotLink, "item:(%d+)")
            if slotItemID and tonumber(slotItemID) == itemID then
                foundSlot = slot
                break
            end
        end
    end
    if not foundSlot then return false, "noslot" end

    if self:TryGiveMasterLoot(foundSlot, winnerName) then return true end
    return false, "nocand"
end

-- Merkt eine Vergabe vor, die nur am geschlossenen Loot-Fenster gescheitert
-- ist. Die Signatur des Kadavers wird mitgespeichert, damit beim Öffnen eines
-- ANDEREN Kadavers nicht versehentlich eine gleichnamige zweite Kopie
-- vergeben wird.
function BananaLoot:QueuePendingAward(itemID, winnerName, link)
    table.insert(self.pendingAwards, {
        itemID = itemID,
        winner = winnerName,
        link = link,
        sig = self.lastLootSignature,
    })
end

-- Wird nach jedem LOOT_OPENED aufgerufen: holt vorgemerkte Vergaben nach.
function BananaLoot:FlushPendingAwards()
    if table.getn(self.pendingAwards) == 0 then return end
    local rest = {}
    for i = 1, table.getn(self.pendingAwards) do
        local p = self.pendingAwards[i]
        if p.sig ~= self.lastLootSignature then
            DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_PENDING_DROPPED"), p.link, p.winner))
        else
            local ok, reason = self:AssignLoot(p.itemID, p.winner)
            if ok then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_PENDING_DONE"), p.link, p.winner))
            elseif reason == "noslot" then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(self:L("AWARD_PENDING_DROPPED"), p.link, p.winner))
            else
                -- "nocand": Spieler gerade nicht erreichbar -> vorgemerkt lassen,
                -- beim nächsten Öffnen wird es erneut versucht.
                table.insert(rest, p)
            end
        end
    end
    self.pendingAwards = rest
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

-- ============================================================
-- 9a) RAIDRES.TOP IMPORT (externe SR-Website, Base64-kodiertes JSON)
-- raidres.top liefert seine Exportdaten als reines Base64(JSON) OHNE
-- zusätzliche Kompression (anders als z.B. softres.it/Gargul, die
-- zusätzlich zlib nutzen -- eine reine Lua-5.0-Implementierung eines
-- Zlib-Inflate wäre praktisch nicht sinnvoll umsetzbar). Base64-Decoder
-- und JSON-Parser sind daher als reine Lua-5.0-Funktionen selbst
-- geschrieben (kein string.gmatch, siehe Datei-Kopfkommentar).
-- ============================================================
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LOOKUP = {}
for i = 1, string.len(B64_CHARS) do
    B64_LOOKUP[string.sub(B64_CHARS, i, i)] = i - 1
end

local function Base64Decode(data)
    if not data then return nil end
    data = string.gsub(data, "[^A-Za-z0-9%+/=]", "")
    local resultParts = {}
    local buffer = 0
    local bits = 0
    for i = 1, string.len(data) do
        local c = string.sub(data, i, i)
        if c == "=" then break end
        local val = B64_LOOKUP[c]
        if val then
            buffer = buffer * 64 + val
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local divisor = math.pow(2, bits)
                local byte = math.floor(buffer / divisor)
                buffer = math.mod(buffer, divisor)
                table.insert(resultParts, string.char(byte))
            end
        end
    end
    return table.concat(resultParts)
end

-- Minimaler, nachsichtiger JSON-Parser (nur für unsere Zwecke: flache bis
-- mäßig verschachtelte Objekte/Arrays mit Strings, Zahlen, Bools, Arrays).
-- Läuft komplett per pcall abgesichert (siehe Aufrufer) -- bei unerwarteten
-- Eingaben lieber sauber abbrechen als eine Endlosschleife riskieren.
local function JSONDecode(str)
    local pos = 1
    local len = string.len(str)
    local parseValue

    local function skipWhitespace()
        while pos <= len do
            local c = string.sub(str, pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end

    local function parseString()
        pos = pos + 1 -- öffnendes "
        local startPos = pos
        local parts = {}
        while pos <= len do
            local c = string.sub(str, pos, pos)
            if c == "\"" then
                table.insert(parts, string.sub(str, startPos, pos - 1))
                pos = pos + 1
                return table.concat(parts)
            elseif c == "\\" then
                table.insert(parts, string.sub(str, startPos, pos - 1))
                local nextC = string.sub(str, pos + 1, pos + 1)
                if nextC == "n" then table.insert(parts, "\n")
                elseif nextC == "t" then table.insert(parts, "\t")
                elseif nextC == "r" then table.insert(parts, "\r")
                elseif nextC == "u" then
                    -- Für Spielernamen/Item-IDs reicht Standard-ASCII;
                    -- alles darüber hinaus wird als "?" übernommen.
                    local hex = string.sub(str, pos + 2, pos + 5)
                    local code = tonumber(hex, 16) or 63
                    table.insert(parts, code < 128 and string.char(code) or "?")
                    pos = pos + 4
                else
                    table.insert(parts, nextC)
                end
                pos = pos + 2
                startPos = pos
            else
                pos = pos + 1
            end
        end
        return table.concat(parts)
    end

    local function parseNumber()
        local startPos = pos
        while pos <= len do
            local c = string.sub(str, pos, pos)
            if string.find(c, "[%d%.%-%+eE]") then
                pos = pos + 1
            else
                break
            end
        end
        return tonumber(string.sub(str, startPos, pos - 1))
    end

    local function parseArray()
        pos = pos + 1
        local arr = {}
        skipWhitespace()
        if string.sub(str, pos, pos) == "]" then
            pos = pos + 1
            return arr
        end
        while true do
            skipWhitespace()
            table.insert(arr, parseValue())
            skipWhitespace()
            local c = string.sub(str, pos, pos)
            if c == "," then
                pos = pos + 1
            else
                if c == "]" then pos = pos + 1 end
                break
            end
        end
        return arr
    end

    local function parseObject()
        pos = pos + 1
        local obj = {}
        skipWhitespace()
        if string.sub(str, pos, pos) == "}" then
            pos = pos + 1
            return obj
        end
        while true do
            skipWhitespace()
            if string.sub(str, pos, pos) ~= "\"" then break end
            local key = parseString()
            skipWhitespace()
            if string.sub(str, pos, pos) == ":" then pos = pos + 1 end
            skipWhitespace()
            obj[key] = parseValue()
            skipWhitespace()
            local c = string.sub(str, pos, pos)
            if c == "," then
                pos = pos + 1
            else
                if c == "}" then pos = pos + 1 end
                break
            end
        end
        return obj
    end

    parseValue = function()
        skipWhitespace()
        local c = string.sub(str, pos, pos)
        if c == "\"" then return parseString()
        elseif c == "{" then return parseObject()
        elseif c == "[" then return parseArray()
        elseif c == "t" then pos = pos + 4 return true
        elseif c == "f" then pos = pos + 5 return false
        elseif c == "n" then pos = pos + 4 return nil
        else return parseNumber()
        end
    end

    local ok, result = pcall(parseValue)
    if ok then return result end
    return nil
end

-- Sucht in einer Tabelle die erste vorhandene Tabelle unter mehreren
-- möglichen Feldnamen -- da das genaue raidres.top-JSON-Schema nicht
-- öffentlich dokumentiert ist, deckt das mehrere plausible Varianten ab.
local function FindFirstTable(obj, keys)
    for i = 1, table.getn(keys) do
        local v = obj[keys[i]]
        if type(v) == "table" then return v end
    end
    return nil
end

local function FindFirstValue(obj, keys)
    for i = 1, table.getn(keys) do
        local v = obj[keys[i]]
        if v ~= nil then return v end
    end
    return nil
end

-- Importiert eine raidres.top-Exportzeichenkette (Base64-kodiertes JSON).
-- Rückgabe: ok, err, resultTable
-- resultTable = { itemCount, hrCount, droppedCount, unmatchedNames={}, hrSkipped={} }
-- Bei ok=false, err="no_entries_found" wird zusätzlich rawJson mitgeliefert,
-- damit die Rohdaten im Zweifel zur Fehlersuche angezeigt werden können.
-- Reine Debug-Hilfsfunktion: dekodiert einen raidres.top-Export bis zum
-- rohen JSON-Text, unabhängig davon, ob der Import selbst erfolgreich wäre.
-- Damit lässt sich das tatsächliche Datenformat einsehen, um die
-- Feldnamen-Zuordnung in ImportRaidResData bei Bedarf zu verfeinern.
function BananaLoot:DecodeRaidResRaw(rawText)
    if not rawText or Trim(rawText) == "" then
        return nil, "empty"
    end
    local cleaned = string.gsub(rawText, "%s+", "")
    local decoded = Base64Decode(cleaned)
    if not decoded or decoded == "" then
        return nil, "base64_failed"
    end
    return decoded
end

function BananaLoot:ImportRaidResData(rawText)
    if not rawText or Trim(rawText) == "" then
        return false, "empty"
    end

    -- Zeilenumbrüche/Leerzeichen entfernen, die beim Copy&Paste aus dem
    -- Browser leicht mit reinrutschen und die Base64-Dekodierung stören.
    local cleaned = string.gsub(rawText, "%s+", "")

    local decoded = Base64Decode(cleaned)
    if not decoded or decoded == "" then
        return false, "base64_failed"
    end

    local data = JSONDecode(decoded)
    if type(data) ~= "table" then
        return false, "json_failed"
    end

    local softList = FindFirstTable(data, { "softReserves", "softreserves", "softRes", "reserves", "items", "SoftReserves" })
    if not softList and data[1] ~= nil then
        -- Kein Wrapper-Feld gefunden, aber die Wurzel selbst sieht wie ein Array aus.
        softList = data
    end
    local hardList = FindFirstTable(data, { "hardReserves", "hardreserves", "hardRes", "HardReserves" })

    if not softList and not hardList then
        return false, "no_entries_found", { rawJson = decoded }
    end

    local maxCount = self:GetMaxSRCount()
    local importCountPerPlayer = {}
    local itemCount = 0
    local hrCount = 0
    local droppedCount = 0
    local unmatchedNames = {}
    local unmatchedSeen = {}
    local hrSkipped = {}

    -- Hard Reserves zuerst verarbeiten, damit die nachfolgende Soft-Reserve-
    -- Zuordnung bereits weiß, welche Items lokal (oder aus diesem Import)
    -- als Hard Reserve gelten.
    if hardList then
        for i = 1, table.getn(hardList) do
            local entry = hardList[i]
            if type(entry) == "table" then
                local id = tonumber(FindFirstValue(entry, { "itemId", "itemID", "id" }))
                if id then
                    -- Qualität ZUERST auswerten (wird für BuildItemLink als
                    -- Farbe gebraucht, falls wir gleich einen Namen finden).
                    -- raidres.top liefert (Stand aktueller Beobachtung) keinen
                    -- Namen, aber die Qualitätsstufe.
                    local quality = tonumber(FindFirstValue(entry, { "quality" }))
                    if quality then self.itemQualityHints[id] = quality end

                    local hrItemName = FindFirstValue(entry, { "itemName", "name", "item_name" })
                    if not (type(hrItemName) == "string" and hrItemName ~= "") then
                        -- Kein Name von raidres.top -- statische Item-DB als
                        -- Fallback probieren (siehe BananaLootItemDB.lua),
                        -- damit der echte Name sofort angezeigt wird statt
                        -- erst beim tatsächlichen Loot.
                        local staticInfo = self:GetStaticItemInfo(id)
                        if staticInfo and staticInfo.name then
                            hrItemName = staticInfo.name
                            if staticInfo.quality and not quality then
                                self.itemQualityHints[id] = staticInfo.quality
                            end
                        end
                    end

                    local link
                    if type(hrItemName) == "string" and hrItemName ~= "" then
                        link = self:BuildItemLink(id, hrItemName)
                    else
                        link = "item:" .. id .. ":0:0:0:0:0:0:0"
                    end
                    self:AddHardReserve(link)
                    hrCount = hrCount + 1
                end
            end
        end
    end

    if softList then
        for i = 1, table.getn(softList) do
            local entry = softList[i]
            if type(entry) == "table" then
                local pname = FindFirstValue(entry, { "name", "player", "playerName", "character" })
                local plusOnes = tonumber(FindFirstValue(entry, { "plusOnes", "plusOne", "srPlus", "sr_plus" })) or 0

                -- Ein Eintrag kann entweder ein Array von Item-IDs mitbringen
                -- (mehrere SR desselben Spielers in einem Datensatz) oder
                -- selbst genau ein Item repräsentieren. Falls raidres.top
                -- direkt einen Namen mitliefert (itemName/name je Item),
                -- wird der übernommen -- das umgeht GetItemInfo komplett,
                -- welches sich für dem Client völlig unbekannte Items auf
                -- diesem Server als generell nicht funktionsfähig erwiesen
                -- hat (auch mit korrekt formatiertem String-Argument).
                local itemIds = {}
                local itemNames = {} -- [itemID] = Name (falls von raidres.top mitgeliefert -- bisher nicht beobachtet)
                local itemsField = FindFirstValue(entry, { "Items", "items" })
                if type(itemsField) == "table" then
                    for k = 1, table.getn(itemsField) do
                        local v = itemsField[k]
                        local id = tonumber(type(v) == "table" and FindFirstValue(v, { "itemId", "itemID", "id" }) or v)
                        if id then
                            table.insert(itemIds, id)
                            if type(v) == "table" then
                                local itemName = FindFirstValue(v, { "itemName", "name", "item_name" })
                                if type(itemName) == "string" and itemName ~= "" then
                                    itemNames[id] = itemName
                                end
                                -- Qualitätsstufe für die Rarity-Farbe der
                                -- "Item #ID"-Anzeige, solange der echte Name
                                -- (z.B. erst beim tatsächlichen Loot) fehlt.
                                local quality = tonumber(FindFirstValue(v, { "quality" }))
                                if quality then self.itemQualityHints[id] = quality end
                            end
                        end
                    end
                else
                    local singleId = tonumber(FindFirstValue(entry, { "itemId", "itemID", "id" }))
                    if singleId then table.insert(itemIds, singleId) end
                end

                if pname and pname ~= "" and table.getn(itemIds) > 0 then
                    if not importCountPerPlayer[pname] then
                        importCountPerPlayer[pname] = 0
                        self:EvictAllPlayerReservations(pname)
                    end
                    if not unmatchedSeen[pname] and not self:IsPlayerInRoster(pname) then
                        unmatchedSeen[pname] = true
                        table.insert(unmatchedNames, pname)
                    end

                    for k = 1, table.getn(itemIds) do
                        local id = itemIds[k]
                        if self:IsHardReserve(id) then
                            table.insert(hrSkipped, pname .. " (Item " .. id .. ")")
                        elseif importCountPerPlayer[pname] >= maxCount then
                            droppedCount = droppedCount + 1
                        else
                            importCountPerPlayer[pname] = importCountPerPlayer[pname] + 1
                            local link = "item:" .. id .. ":0:0:0:0:0:0:0"
                            if itemNames[id] then
                                -- raidres.top liefert den Namen direkt mit -- daraus
                                -- einen echten, klickbaren Link bauen (Farbe aus
                                -- itemQualityHints, falls vorhanden, sonst weiß).
                                link = self:BuildItemLink(id, itemNames[id])
                            else
                                -- Kein Name von raidres.top mitgeliefert: zuerst die
                                -- statische Item-DB probieren (BananaLootItemDB.lua) --
                                -- deutlich zuverlässiger als GetItemInfo auf diesem
                                -- Server, das für unbekannte Items nie etwas liefert.
                                local staticInfo = self:GetStaticItemInfo(id)
                                if staticInfo and staticInfo.name then
                                    if staticInfo.quality and not self.itemQualityHints[id] then
                                        self.itemQualityHints[id] = staticInfo.quality
                                    end
                                    link = self:BuildItemLink(id, staticInfo.name)
                                else
                                    -- Letzter Fallback: falls der Client die Item-Daten
                                    -- ausnahmsweise schon kennt (z.B. AH-Suche), den
                                    -- echten Link stattdessen verwenden.
                                    local _, cachedLink = GetItemInfo("item:" .. id .. ":0:0:0:0:0:0:0")
                                    if cachedLink then link = cachedLink end
                                end
                            end
                            if not self.reservations[id] then
                                self.reservations[id] = { link = link, name = GetItemNameFromLink(link), players = {}, order = {} }
                            end
                            local res = self.reservations[id]
                            if not res.players[pname] then
                                res.players[pname] = true
                                table.insert(res.order, pname)
                            end
                            self.playerReservedItems[pname] = self.playerReservedItems[pname] or {}
                            table.insert(self.playerReservedItems[pname], id)
                            if plusOnes > 0 then
                                self:SetStack(pname, id, plusOnes)
                            end
                            itemCount = itemCount + 1
                        end
                    end
                end
            end
        end
    end

    self:SaveSession()

    return true, nil, {
        itemCount = itemCount,
        hrCount = hrCount,
        droppedCount = droppedCount,
        unmatchedNames = unmatchedNames,
        hrSkipped = hrSkipped,
    }
end

function BananaLoot:ExportSRList()
    local records = {}
    -- Zeitstempel als erster Datensatz, damit die Vertretung beim Import
    -- erkennen kann, wie alt die exportierte Liste ist.
    table.insert(records, "T^" .. tostring(time()))
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
-- Rückgabe: ok, err, itemCount, hrCount, ageMinutes
-- ageMinutes ist nil, wenn der Export keinen Zeitstempel enthält (z.B.
-- sehr alter Export), sonst die Anzahl Minuten seit dem Export.
function BananaLoot:ImportSRList(str)
    if not str or string.sub(str, 1, 6) ~= "MSRv2~" then
        return false, "invalid_format", 0
    end

    local body = string.sub(str, 7)
    if body == "" then return true, nil, 0 end

    local records = Split(body, "~")
    local itemCount = 0
    local hrCount = 0
    local droppedCount = 0
    local exportTime = nil
    -- Zählt pro Spieler, wie viele Items in DIESEM Import bereits vergeben
    -- wurden, um das aktuelle SR-Limit durchzusetzen. Beim ersten Auftreten
    -- eines Spielers werden zudem alle seine bisherigen lokalen
    -- Reservierungen verdrängt (siehe EvictAllPlayerReservations) -- der
    -- Import gilt als autoritativ für jeden darin genannten Spieler.
    local importCountPerPlayer = {}
    local maxCount = self:GetMaxSRCount()

    for i = 1, table.getn(records) do
        local rec = records[i]
        if rec ~= "" then
            local fields = Split(rec, "^")
            if fields[1] == "T" then
                exportTime = tonumber(fields[2])
            elseif fields[1] == "H" then
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
                            if not importCountPerPlayer[pname] then
                                importCountPerPlayer[pname] = 0
                                self:EvictAllPlayerReservations(pname)
                            end

                            if importCountPerPlayer[pname] >= maxCount then
                                droppedCount = droppedCount + 1
                            else
                                importCountPerPlayer[pname] = importCountPerPlayer[pname] + 1
                                res.players[pname] = true
                                table.insert(res.order, pname)
                                self.playerReservedItems[pname] = self.playerReservedItems[pname] or {}
                                table.insert(self.playerReservedItems[pname], id)
                                EnsureDB()
                                BananaLoot_DB.players[pname] = BananaLoot_DB.players[pname] or {}
                                BananaLoot_DB.players[pname][id] = pstack
                            end
                        end
                    end
                end
            end
        end
    end

    self:SaveSession()

    local ageMinutes = nil
    if exportTime then
        local ageSeconds = time() - exportTime
        if ageSeconds > 0 then
            ageMinutes = math.floor(ageSeconds / 60)
        end
    end

    return true, nil, itemCount, hrCount, ageMinutes, droppedCount
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
    local lines = { "Datum\tItem\tSpieler\tKategorie\tWeitergegeben an" }
    local log = BananaLoot_DB.log or {}
    for i = 1, table.getn(log) do
        local e = log[i]
        table.insert(lines, e.time .. "\t" .. e.item .. "\t" .. e.winner .. "\t" .. e.pool .. "\t" .. (e.tradedTo or ""))
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
-- 9c) AUTOMATISCHES MASTER LOOT BEIM BOSS-ANVISIEREN
-- Liste bekannter Raid-Boss-Namen (Vanilla-Raids + bekannte OctoWoW/
-- Turtle-Custom-Raid-Bosse). Beim Anvisieren eines dieser Namen wird
-- automatisch auf Masterloot gewechselt (Option, Standard: an), sofern
-- aktuell NICHT schon Masterloot aktiv ist. Kein automatisches
-- Zurückschalten -- das bleibt manuell.
--
-- Quelle: OctoWoW-AtlasLoot-Fork (dieselbe Quelle wie
-- BananaLootItemDB.lua), Stand September 2026. Die Custom-Raid-Namen
-- (Timbermaw Hold, Karazhan 10/40) stammen aus internen AtlasLoot-
-- Kürzeln und sind NICHT 1:1 im Spiel gegengeprüft -- bei Abweichungen
-- hier korrigieren/ergänzen.
-- ============================================================
local AUTO_ML_BOSS_NAMES = {
    -- Molten Core
    ["Lucifron"] = true, ["Magmadar"] = true, ["Garr"] = true,
    ["Baron Geddon"] = true, ["Shazzrah"] = true, ["Sulfuron Harbinger"] = true,
    ["Golemagg the Incinerator"] = true, ["Majordomo Executus"] = true,
    ["Ragnaros"] = true,
    ["Incindis"] = true, ["Basalthar"] = true, ["Smoldaris"] = true,
    ["Sorcerer-Thane Thaurissan"] = true,
    -- Onyxia's Lair
    ["Onyxia"] = true,
    -- Blackwing Lair
    ["Razorgore the Untamed"] = true, ["Vaelastrasz the Corrupt"] = true,
    ["Broodlord Lashlayer"] = true, ["Firemaw"] = true,
    ["Ezzel Darkbrewer"] = true, ["Ebonroc"] = true, ["Flamegor"] = true,
    ["Chromaggus"] = true, ["Nefarian"] = true,
    -- Zul'Gurub
    ["Bloodlord Mandokir"] = true, ["High Priest Venoxis"] = true,
    ["High Priestess Jeklik"] = true, ["High Priestess Mar'li"] = true,
    ["High Priest Thekal"] = true, ["High Priestess Arlokk"] = true,
    ["Hakkar the Soulflayer"] = true, ["Jin'do the Hexxer"] = true,
    ["Gahz'ranka"] = true,
    -- Ahn'Qiraj (20)
    ["Kurinnaxx"] = true, ["General Rajaxx"] = true, ["Moam"] = true,
    ["Buru the Gorger"] = true, ["Ayamiss the Hunter"] = true,
    ["Ossirian the Unscarred"] = true,
    -- Ahn'Qiraj (40)
    ["The Prophet Skeram"] = true, ["Lord Kri"] = true, ["Princess Yauj"] = true,
    ["Vem"] = true, ["Battleguard Sartura"] = true,
    ["Fankriss the Unyielding"] = true, ["Viscidus"] = true,
    ["Princess Huhuran"] = true, ["Vek'lor"] = true, ["Vek'nilash"] = true,
    ["Ouro"] = true, ["C'Thun"] = true,
    -- Naxxramas
    ["Anub'Rekhan"] = true, ["Grand Widow Faerlina"] = true, ["Maexxna"] = true,
    ["Noth the Plaguebringer"] = true, ["Heigan the Unclean"] = true,
    ["Loatheb"] = true, ["Instructor Razuvious"] = true,
    ["Gothik the Harvester"] = true, ["Thane Korth'azz"] = true,
    ["Lady Blaumeux"] = true, ["Sir Zeliek"] = true, ["Baron Rivendare"] = true,
    ["Patchwerk"] = true, ["Grobbulus"] = true, ["Gluth"] = true,
    ["Thaddius"] = true, ["Sapphiron"] = true, ["Kel'Thuzad"] = true,
    -- Timbermaw Hold (20, Custom-Raid -- unsichere Schreibweisen)
    ["Karrsh the Sentinel"] = true, ["Rotgrowl"] = true, ["Kodiak"] = true,
    ["Chieftain Partath"] = true, ["Archdruid Kronn"] = true,
    ["Trioch the Devourer"] = true,
    -- Lower Karazhan Halls (10, interne Kürzel -- unsichere Schreibweisen)
    ["Rolfen"] = true, ["Brood Queen Araxxna"] = true, ["Grizikil"] = true,
    ["Clawlord Howlfang"] = true, ["Lord Blackwald II"] = true, ["Moroes"] = true,
    -- Upper Karazhan Halls (40, interne Kürzel -- unsichere Schreibweisen)
    ["Gnarlmoon"] = true, ["Incantagos"] = true, ["Anomalus"] = true,
    ["Echo"] = true, ["Sanv Tasdal"] = true, ["Rupturan"] = true,
    ["Kruul"] = true, ["Mephistroth"] = true,
}

-- Prüft beim Anvisieren, ob das Ziel ein bekannter Raid-Boss ist, und
-- wechselt ggf. automatisch auf Masterloot.
local function TryAutoMasterLoot()
    if not BananaLoot:GetAutoMasterLootEnabled() then return end
    local name = UnitName("target")
    if not name or not AUTO_ML_BOSS_NAMES[name] then return end

    local ok, method = pcall(GetLootMethod)
    if ok and method == "master" then return end -- schon ML, nichts zu tun

    pcall(function() SetLootMethod("master", UnitName("player")) end)
end

-- ============================================================
-- 9d) ROLL-SYNC EMPFANG: verarbeitet eingehende AddonMessages von
-- anderen BananaLoot-Clients. Roll-Fortschritt (RS/RU/RT/RW/RC) geht
-- ans Popup-Fenster (BananaLoot_UI:HandleRollSync), Vergaben (AW) an
-- die geteilte Loot-Historie (BananaLoot_UI:AddHistoryEntry) -- beide
-- in BananaLootUI.lua bzw. BananaLootExtra.lua definiert. Split() ist
-- an dieser Stelle im Chunk bereits als lokale Funktion definiert
-- (siehe Abschnitt 9, Export/Import) und kann hier mitgenutzt werden.
-- ============================================================
function BananaLoot:HandleRollSyncMessage(text, sender)
    local isSelf = (sender == UnitName("player"))

    local fields = Split(text, "~")
    local msgType = fields[1]

    -- AW (Vergabe) und TT (Handels-Weitergabe, siehe Abschnitt 4c) werden
    -- UNABHÄNGIG vom Roll-Sync-Popup-Schalter verarbeitet -- Roll-Sync und
    -- Trade-Tracking sind zwei getrennt aktivierbare Optionen, die sich
    -- nur denselben Addon-Message-Kanal teilen (siehe SendAwardOrTradeMessage).
    --
    -- AW wird zusätzlich unabhängig von "Popup auch beim Senden" behandelt:
    -- die eigene Vergabe landet bereits direkt am Auslösepunkt (siehe
    -- AwardItem) in der geteilten Historie, ganz ohne Netzwerk-Umweg --
    -- der eigene Broadcast wird beim Empfang daher einfach ignoriert,
    -- sonst gäbe es den Eintrag doppelt.
    if msgType == "AW" then
        if not isSelf and BananaLoot_UI and BananaLoot_UI.AddHistoryEntry then
            BananaLoot_UI:AddHistoryEntry(tonumber(fields[2]), fields[3], fields[4])
        end
        -- Für Trade-Tracking: merkt sich auf JEDEM Client mit aktivierter
        -- Option (nicht nur beim Loot-Master) den aktuellen Besitzer eines
        -- über BananaLoot vergebenen Items, damit ein späterer Trade
        -- dieses Items -- auf welchem Client auch immer er stattfindet --
        -- erkannt werden kann (siehe HandleTradeMatch).
        if self:GetTradeTrackingEnabled() then
            local itemID = tonumber(fields[2])
            if itemID and fields[3] then
                EnsureDB()
                BananaLoot_DB.awardedItems[itemID] = { winner = fields[3] }
            end
        end
        return
    end

    if msgType == "TT" then
        if self:GetTradeTrackingEnabled() and not isSelf then
            local itemID = tonumber(fields[2])
            if itemID and fields[3] and fields[4] then
                self:RecordTradeHandoff(itemID, fields[3], fields[4], false)
            end
        end
        return
    end

    if not self:GetRollSyncEnabled() then return end

    -- Eigene Broadcasts nur verarbeiten, wenn explizit gewünscht (Option
    -- "Popup auch beim Senden anzeigen") -- sonst wäre das Popup für den
    -- Loot-Master redundant zu seinem ohnehin vorhandenen Loot-Fenster.
    if isSelf and not self:GetRollSyncShowForSender() then return end

    -- Chat-Debug-Ausgabe bewusst nur für Nachrichten von ANDEREN --
    -- die eigenen kennt man ja schon aus dem normalen Loot-Fenster/
    -- Chat, das würde nur zusätzlich Chat-Spam beim Master erzeugen.
    if not isSelf then
        if msgType == "RS" then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ccff[BL-Sync]|r RS von %s: Item %s, %ss, Modus %s", sender, fields[2], fields[3], fields[4]))
        elseif msgType == "RU" then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ccff[BL-Sync]|r RU von %s: %s hat %s (%s) auf Item %s gewuerfelt", sender, fields[3], fields[4], fields[5], fields[2]))
        elseif msgType == "RT" then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ccff[BL-Sync]|r RT von %s: Gleichstand auf Item %s -- %s", sender, fields[2], fields[3] or ""))
        elseif msgType == "RW" then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ccff[BL-Sync]|r RW von %s: %s gewinnt Item %s (%s, Wurf %s, Wertung %s)", sender, fields[3], fields[2], fields[6], fields[5], fields[4]))
        elseif msgType == "RC" then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ccff[BL-Sync]|r RC von %s: Roll auf Item %s abgebrochen (Grund %s)", sender, fields[2], fields[3]))
        end
    end

    if BananaLoot_UI and BananaLoot_UI.HandleRollSync then
        BananaLoot_UI:HandleRollSync(msgType, fields, sender)
    end
end

-- ============================================================
-- 9e) LFM ("Looking For More") -- postet einen frei waehlbaren Text in
-- regelmaessigen Abstaenden im Weltkanal (ueblicherweise /4, siehe
-- FindWorldChannelIndex weiter unten fuer den Grund, warum der Index
-- nicht fest verdrahtet wird). Gedacht z.B. fuer PUG-Raids oder um
-- Nachschub fuer einen abgesprungenen Spieler zu finden.
--
-- Text UND Intervall werden in den SavedVariables gespeichert und
-- bleiben bis zur naechsten manuellen Aenderung bestehen (ueberleben
-- also Relog/Reload) -- das eigentliche Posten startet dabei aber NIE
-- von selbst wieder, auch nicht nach einem Reload: lfmRunning ist
-- bewusst rein session-lokal und wird nur ueber den Start/Stop-Button
-- bzw. BananaLoot:StartLFM()/StopLFM() gesteuert (siehe BananaLootUI/
-- BananaLootExtra.lua fuer das Fenster).
-- ============================================================
BananaLoot.lfmRunning = false      -- rein session-lokal, nie gespeichert
BananaLoot.lfmLastPostTime = nil   -- GetTime() des letzten tatsaechlichen Posts

-- Mindestabstand in Minuten: ein zu kurzes Intervall riskiert eine
-- serverseitige Chat-Sperre wegen Spam. Wird in SetLFMIntervalMinutes()
-- hart erzwungen.
local LFM_MIN_INTERVAL_MINUTES = 1

function BananaLoot:GetLFMText()
    EnsureDB()
    return BananaLoot_DB.settings.lfmText or ""
end

function BananaLoot:SetLFMText(text)
    EnsureDB()
    text = text or ""
    -- Die Eingabebox ist mehrzeilig dargestellt (automatischer Zeilen-
    -- umbruch fuer die Lesbarkeit, siehe BananaLootExtra.lua), aber der
    -- eigentliche Text muss fuer SendChatMessage eine einzelne Zeile
    -- bleiben -- ein versehentlich per Enter eingefuegter Zeilenumbruch
    -- wird daher zu einem Leerzeichen geglaettet.
    text = string.gsub(text, "[\n\r]+", " ")
    BananaLoot_DB.settings.lfmText = text
end

function BananaLoot:GetLFMIntervalMinutes()
    EnsureDB()
    return BananaLoot_DB.settings.lfmIntervalMinutes or 5
end

function BananaLoot:SetLFMIntervalMinutes(value)
    EnsureDB()
    value = tonumber(value)
    if not value or value < LFM_MIN_INTERVAL_MINUTES then return false end
    BananaLoot_DB.settings.lfmIntervalMinutes = value
    return true
end

-- Sucht den aktuell gejointen Chat-Kanal, dessen Name "world" enthaelt
-- (Gross-/Kleinschreibung egal), und liefert dessen AKTUELLEN Kanal-
-- Index. Bewusst NICHT fest auf 4 verdrahtet: welchen Index "World" hat,
-- haengt davon ab, welche Kanaele der Charakter gerade gejoint hat und
-- in welcher Reihenfolge (kann sich durch Zonenwechsel oder Relog
-- verschieben) -- der Index wird daher bei JEDEM Post frisch ermittelt.
local function FindWorldChannelIndex()
    for i = 1, 20 do
        local ok, id, name = pcall(GetChannelName, i)
        if ok and id and id > 0 and name and string.find(string.lower(name), "world") then
            return id
        end
    end
    return nil
end

-- Postet den aktuellen LFM-Text einmalig in den Weltkanal. Zentrale
-- Stelle fuer sowohl den Sofort-Post bei StartLFM() als auch die
-- wiederkehrenden Posts aus TickLFM().
local function PostLFMMessage()
    local text = BananaLoot:GetLFMText()
    if not text or Trim(text) == "" then
        -- Text wurde zwischenzeitlich geleert -- sauber abbrechen statt
        -- eine leere Nachricht zu senden oder endlos weiterzulaufen.
        BananaLoot.lfmRunning = false
        if BananaLoot_UI and BananaLoot_UI.RefreshLFM then BananaLoot_UI:RefreshLFM() end
        return
    end

    local channelIndex = FindWorldChannelIndex()
    if not channelIndex then
        DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("LFM_CHANNEL_NOT_FOUND"))
        -- Naechster Versuch erst nach einem vollen Intervall (kein
        -- Dauerspam im eigenen Chat, falls der Kanal laengere Zeit nicht
        -- verfuegbar ist, z.B. in einer Instanz).
        BananaLoot.lfmLastPostTime = GetTime()
        return
    end

    SendChatMessage(text, "CHANNEL", nil, channelIndex)
    BananaLoot.lfmLastPostTime = GetTime()
end

-- Startet den LFM-Lauf: postet sofort einmal und danach im eingestellten
-- Intervall (siehe TickLFM, aufgerufen aus dem bestehenden OnUpdate-
-- Ticker in Abschnitt 10). Rueckgabe false, "no_text" wenn kein Text
-- hinterlegt ist.
function BananaLoot:StartLFM()
    local text = self:GetLFMText()
    if not text or Trim(text) == "" then return false, "no_text" end
    self.lfmRunning = true
    PostLFMMessage()
    return true
end

function BananaLoot:StopLFM()
    self.lfmRunning = false
end

-- Wird aus dem bestehenden OnUpdate-Ticker (Abschnitt 10) einmal pro
-- Frame aufgerufen; macht selbst nichts, solange lfmRunning falsch ist.
function BananaLoot:TickLFM()
    if not self.lfmRunning then return end
    local intervalSeconds = self:GetLFMIntervalMinutes() * 60
    if not self.lfmLastPostTime then self.lfmLastPostTime = GetTime() end
    if GetTime() - self.lfmLastPostTime >= intervalSeconds then
        PostLFMMessage()
    end
end

-- ============================================================
-- 10) EVENT HANDLING (klassischer Vanilla-Stil: globale arg1..argN)
-- ============================================================
-- Die Systemmeldung für /roll kommt in der Sprache des CLIENTS. Fest
-- verdrahtete Muster decken nur enUS/deDE ab -- auf einem frFR/ruRU/esES-
-- Client würde kein einziger Roll erkannt, ohne sichtbaren Fehler. Deshalb
-- wird das Muster zusätzlich aus der globalen Variable RANDOM_ROLL_RESULT
-- ("%s rolls %d (%d-%d)") abgeleitet, die der Client selbst lokalisiert
-- mitliefert. Die beiden festen Muster bleiben als Fallback bestehen, falls
-- ein Server-Client die Variable nicht setzt.
local ROLL_PATTERN = nil
local function BuildRollPattern()
    local src = RANDOM_ROLL_RESULT
    if not src or src == "" then return nil end
    -- 1) alle Lua-Pattern-Magic-Chars escapen (inkl. "%" selbst)
    local p = string.gsub(src, "([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    -- 2) aus den escapeten Platzhaltern "%%s"/"%%d" wieder Captures machen
    p = string.gsub(p, "%%%%s", "(.+)")
    p = string.gsub(p, "%%%%d", "(%%d+)")
    return "^" .. p .. "$"
end

local eventFrame = CreateFrame("Frame", "BananaLootEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "BananaLoot" then
        EnsureDB()
        MigrateDB()
        BananaLoot:RestoreSession()
        DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("MSG_ADDON_LOADED"))
        if BananaLoot_UI and BananaLoot_UI.ApplyLocaleAll then BananaLoot_UI:ApplyLocaleAll() end

    elseif event == "CHAT_MSG_WHISPER" then
        BananaLoot:HandleWhisper(arg2, arg1)

    elseif event == "CHAT_MSG_SYSTEM" then
        if BananaLoot.activeRoll and BananaLoot.activeRoll.running then
            -- Die Systemnachricht für /roll wird vom WoW-Client lokalisiert
            -- ausgegeben (abhängig von der Client-Sprache des Loot-Masters,
            -- NICHT von der BananaLoot-Sprachoption!). Auf einem deutschen
            -- Client lautet die Meldung "X würfelt Y (1-Z)" statt "X rolls
            -- Y (1-Z)" -- deshalb hier beide Varianten prüfen.
            local _, _, roller, value, maxRange = string.find(arg1, "^(.+) rolls (%d+) %(1%-(%d+)%)$")
            if not roller then
                _, _, roller, value, maxRange = string.find(arg1, "^(.+) würfelt (%d+) %(1%-(%d+)%)$")
            end
            if not roller then
                -- Client-lokalisiertes Muster (siehe BuildRollPattern oben):
                -- liefert vier Captures -- Name, Wurf, Minimum, Maximum.
                if ROLL_PATTERN == nil then ROLL_PATTERN = BuildRollPattern() or false end
                if ROLL_PATTERN then
                    local r, v, minRange, maxR = nil, nil, nil, nil
                    _, _, r, v, minRange, maxR = string.find(arg1, ROLL_PATTERN)
                    if r and minRange == "1" then
                        roller, value, maxRange = r, v, maxR
                    end
                end
            end
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

    elseif event == "PLAYER_TARGET_CHANGED" then
        TryAutoMasterLoot()

    elseif event == "TRADE_ACCEPT_UPDATE" then
        -- arg1/arg2 = playerAccepted/targetAccepted (0 oder 1). Erst wenn
        -- BEIDE Seiten akzeptiert haben, liefern GetTradePlayerItemLink/
        -- GetTradeTargetItemLink noch kurz vor dem eigentlichen Abschluss
        -- gültige Daten -- siehe SnapshotTradeItems (Abschnitt 4c).
        if arg1 == 1 and arg2 == 1 then
            SnapshotTradeItems()
        end

    elseif event == "CHAT_MSG_ADDON" then
        if arg1 == ROLL_SYNC_PREFIX then
            BananaLoot:HandleRollSyncMessage(arg2, arg4)
        end

    elseif event == "LOOT_OPENED" then
        BananaLoot.lootWindowOpen = true
        BananaLoot.lootClosedWarned = false
        BananaLoot:OnLootOpened()
        -- Nach OnLootOpened, damit lastLootSignature für den Signatur-Abgleich
        -- in FlushPendingAwards bereits aktuell ist.
        BananaLoot:FlushPendingAwards()

    elseif event == "LOOT_CLOSED" then
        BananaLoot.lootWindowOpen = false
        -- Früh warnen statt erst bei der Vergabe: läuft gerade ein Roll oder
        -- wartet ein Gewinner auf die Vergabe, würde GiveMasterLoot bei
        -- geschlossenem Fenster stillschweigend nichts tun. Nur EINMAL pro
        -- tatsächlichem Schließvorgang warnen -- LOOT_CLOSED kann auf manchen
        -- Servern mehrfach hintereinander feuern, ohne dass zwischendurch
        -- neu geloottet wurde, was sonst den Chat zuspammt.
        if BananaLoot.activeRoll and not BananaLoot.lootClosedWarned then
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("LOOT_CLOSED_WARN"))
            BananaLoot.lootClosedWarned = true
        end

        -- Signatur-Sperre nur zurücksetzen, wenn wirklich ALLE Items aus
        -- diesem Loot-Fenster bereits vergeben wurden (lootCounts leer).
        -- Wurde das Fenster nur zwischenzeitlich geschlossen, ohne dass
        -- alles vergeben ist (z.B. wartet noch auf eine Vergabe), bleibt
        -- die Sperre bestehen, damit ein erneutes Öffnen desselben
        -- Kadavers weiterhin nicht nochmal Sound/Chat/Vorschau auslöst.
        if not next(BananaLoot.lootCounts) then
            BananaLoot.lastLootSignature = nil
        end
    end
end)

local COUNTDOWN_SECONDS = { [10] = true, [5] = true, [3] = true, [2] = true, [1] = true }

eventFrame:SetScript("OnUpdate", function()
    BananaLoot:TickLFM()

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
                    msg = BananaLoot:L("COUNTDOWN_10")
                else
                    local unit = (remaining == 1) and BananaLoot:L("SECOND_SINGULAR") or BananaLoot:L("SECOND_PLURAL")
                    msg = string.format(BananaLoot:L("COUNTDOWN_N"), remaining, unit)
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
        DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_RESET_DONE"))
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    elseif cmd == "wipeplus" then
        if StaticPopup_Show then
            StaticPopup_Show("BANANALOOT_CONFIRM_WIPE")
        else
            EnsureDB()
            BananaLoot_DB.players = {}
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_WIPE_DONE"))
        end

    elseif cmd == "auto" then
        BananaLoot:StartAutoMode()

    elseif cmd == "award" then
        BananaLoot:AwardActiveWinner()

    elseif string.find(cmd, "^arf") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id then
            BananaLoot:StartRoll(id, nil, true, link)
        else
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_ARF_NEED_LINK"))
        end

    elseif string.find(cmd, "^unsr") then
        local link = ExtractLinkFromMessage(msg)
        if link then
            local ok = BananaLoot:RemoveReservation(link, UnitName("player"))
            if ok then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(BananaLoot:L("CMD_UNSR_REMOVED"), link))
            else
                DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_UNSR_NOT_RESERVED"))
            end
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        else
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_SR_NEED_LINK"))
        end

    elseif string.find(cmd, "^sr") then
        local link = ExtractLinkFromMessage(msg)
        if link then
            -- forceIgnoreHR = true: der Loot-Master darf sich damit auch
            -- selbst auf ein Hard-Reserve-Item setzen (z.B. um es danach
            -- über "Gewinner" manuell an sich zu vergeben) -- exakt
            -- dieselbe Ausnahme wie beim manuellen Hinzufügen im
            -- "Verwalten"-Fenster.
            local ok, idOrErr = BananaLoot:AddReservation(link, UnitName("player"), true)
            if ok then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(BananaLoot:L("CMD_SR_ADDED"), link))
            elseif idOrErr == "limit_reached" then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(BananaLoot:L("WHISPER_SR_LIMIT_REACHED"), BananaLoot:GetMaxSRCount()))
            else
                DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_SR_ADD_FAIL"))
            end
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        else
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_SR_NEED_LINK"))
        end

    elseif string.find(cmd, "^hr remove") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id and BananaLoot:RemoveHardReserve(id) then
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_HR_REMOVED"))
        else
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_HR_REMOVE_FAIL"))
        end
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    elseif cmd == "hr" then
        if BananaLoot_UI and BananaLoot_UI.ShowHRList then BananaLoot_UI:ShowHRList() end

    elseif string.find(cmd, "^hr") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id then
            BananaLoot:AddHardReserve(link)
            DEFAULT_CHAT_FRAME:AddMessage(string.format(BananaLoot:L("CMD_HR_ADDED"), link))
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        else
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_HR_NEED_LINK"))
        end

    elseif string.find(cmd, "^br remove") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id and BananaLoot:RemoveBankReserve(id) then
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_BR_REMOVED"))
        else
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_BR_REMOVE_FAIL"))
        end
        if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end

    elseif cmd == "br" then
        if BananaLoot_UI and BananaLoot_UI.ShowBRList then BananaLoot_UI:ShowBRList() end

    elseif string.find(cmd, "^br") then
        local link = ExtractLinkFromMessage(msg)
        local id = link and GetItemIDFromLink(link)
        if id then
            BananaLoot:AddBankReserve(link)
            DEFAULT_CHAT_FRAME:AddMessage(string.format(BananaLoot:L("CMD_BR_ADDED"), link))
            if BananaLoot_UI and BananaLoot_UI.Refresh then BananaLoot_UI:Refresh() end
        else
            DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_BR_NEED_LINK"))
        end

    elseif cmd == "stop" then
        BananaLoot:StopAutoMode()
        DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_STOPPED"))

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
        DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_LOG_CLEARED"))

    elseif cmd == "recover" then
        if BananaLoot_UI and BananaLoot_UI.ShowRecoveryList then BananaLoot_UI:ShowRecoveryList() end

    elseif cmd == "history" then
        if BananaLoot_UI and BananaLoot_UI.ShowHistory then BananaLoot_UI:ShowHistory() end

    elseif cmd == "lfm" then
        if BananaLoot_UI and BananaLoot_UI.ShowLFM then BananaLoot_UI:ShowLFM() end

    elseif cmd == "options" or cmd == "config" then
        if BananaLoot_UI and BananaLoot_UI.ToggleOptions then BananaLoot_UI:ToggleOptions() end

    elseif cmd == "loot" then
        if BananaLoot_UI and BananaLoot_UI.ToggleLoot then BananaLoot_UI:ToggleLoot() end

    elseif cmd == "open" or cmd == "" then
        if BananaLoot_UI and BananaLoot_UI.Toggle then BananaLoot_UI:Toggle() end

    else
        DEFAULT_CHAT_FRAME:AddMessage(BananaLoot:L("CMD_HELP"))
    end
end
