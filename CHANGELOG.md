# Changelog

Alle nennenswerten Änderungen an BananaLoot. Neueste Version oben.

Die Einträge bis einschließlich 3.32 stammen aus der früheren `README.txt` im Addon-Ordner und sind unverändert übernommen.

## 3.32

 - New: LFM-Feature ("/bl lfm" bzw. Button im SR-Fenster) -- postet
   einen frei wählbaren, auf 255 Zeichen begrenzten Text in
   regelmäßigen, einstellbaren Abständen (mind. 1 Minute) automatisch
   im Weltkanal, mit einem einzelnen Start/Stop-Button (Beschriftung
   UND Funktion wechseln je nach Zustand). Text und Intervall werden
   lokal gespeichert und überleben Relog/Reload, das Posten selbst
   startet dabei aber NIE von selbst wieder -- ausschließlich über den
   Button. Der Weltkanal-Index wird bei jedem Post frisch anhand des
   Kanalnamens ermittelt statt fest auf 4 verdrahtet zu sein, da er
   sich durch Zonenwechsel/Relog verschieben kann. Siehe eigener
   Abschnitt LFM weiter oben.
 - New: das Optionsfenster ist jetzt in fünf statt drei Reiter
   unterteilt (Allgemein / Automatik / Netzwerk / Anzeige & Sound /
   Verwaltung), damit kein einzelner Reiter mehr überladen wirkt. Das
   Fenster passt seine Höhe automatisch an den jeweils angezeigten
   Reiter an.
 - Fix: die Meldung "Loot-Fenster geschlossen" konnte den Chat
   zuspammen, wenn das LOOT_CLOSED-Event mehrfach hintereinander
   feuerte, ohne dass zwischendurch neu geloottet wurde. Die Warnung
   erscheint jetzt nur noch einmal pro tatsächlichem Schließvorgang.

## 3.31

 - New: neues BananaLoot-Logo eingebaut. Das komplette Logo steht oben im
   Options-Fenster (138x138), der Kisten-Ausschnitt ohne Schriftzug dient
   als Minimap-Button-Icon (20x20) und als Titelicon im SR- (32x32) und
   Loot-Fenster (18x18). Alle vier Stellen sind quadratisch angelegt und
   verwenden kein SetTexCoord mehr -- das Seitenverhaeltnis der Quellgrafik
   (1:1) bleibt damit ueberall exakt erhalten, nichts wird gestaucht.
   Die alten Grafiken (BananaLootBanner_460x120.tga, _512x256.tga,
   BananaLoot_MinimapIcon_64.tga) sind entfallen; BananaLootBanner_460x120
   war ohnehin eine Leiche -- die Datei wurde von keiner Zeile Code
   referenziert und haette mangels Zweierpotenz-Dimensionen auch gar nicht
   geladen werden koennen.
 - Fix: Vergabe schlug still fehl, wenn das Loot-Fenster zwischenzeitlich
   zugegangen war (Bewegung, ESC, zu weit vom Kadaver weg). GetNumLootItems/
   GiveMasterLoot funktionieren in Vanilla nur bei offener Loot-Session --
   das wurde nirgends geprueft. Jetzt wird die Vergabe in dem Fall
   VORGEMERKT und beim erneuten Anklicken desselben Kadavers automatisch
   nachgeholt. Kein manueller Umweg ueber das Blizzard-Menue mehr noetig.
 - New: Fehlerursache bei fehlgeschlagener Vergabe wird unterschieden --
   "Loot-Fenster ist zu" (wird nachgeholt) vs. "Spieler steht nicht in der
   Vergabeliste" (zu weit weg, andere Zone, Geist am Friedhof, offline).
   Vorher kam in beiden Faellen dieselbe Sammelmeldung.
 - New: Warnung im Chat, sobald das Loot-Fenster waehrend eines laufenden
   Rolls geschlossen wird.
 - Fix: Namensvergleich bei der Masterloot-Kandidatensuche faellt jetzt
   zusaetzlich auf Gross-/Kleinschreibung-unabhaengig zurueck (relevant fuer
   manuell eingetippte Namen im "Verwalten"-Fenster). Die Reihenfolge der
   API-Signatur-Durchlaeufe wurde so sortiert, dass auf einem
   Ein-Argument-Server kein falscher Kandidatenindex entstehen kann.
 - Fix: Roll-Erkennung funktionierte nur auf enUS- und deDE-Clients. Auf
   allen anderen Client-Sprachen wurde kein einziger /roll erkannt (stumm,
   danach "Niemand hat gerollt"). Das Muster wird jetzt zusaetzlich aus der
   clientseitigen Variable RANDOM_ROLL_RESULT abgeleitet; die beiden festen
   Muster bleiben als Fallback.
 - Fix: Tie-Break auf einem SR-Item konnte haengenbleiben. Wuerfelten die
   Gleichstands-Teilnehmer (die selbst nicht auf der SR-Liste stehen) beim
   Nachrollen mit normalem /roll statt /roll 1 99, wurden ihre Wuerfe stumm
   verworfen -> Timeout -> "Niemand hat gerollt" -> im Auto-Modus wurde das
   Item uebersprungen. Waehrend eines laufenden Tie-Breaks greift die
   SR-Beschraenkung jetzt nicht mehr, die Teilnehmerliste ist ohnehin fix.
 - Fix ("Top N gewinnen"): wurde um den letzten Platz gleichgestanden und
   beim Nachrollen wuerfelte niemand, verwarf das Addon den kompletten Roll
   inkl. der bereits sicher bestimmten Gewinner ("Niemand hat gerollt").
   Diese bleiben jetzt bestehen und werden normal angekuendigt und vergeben.
 - Fix: Gewinner-Sammelansage bei sehr vielen Gewinnern wird auf das
   Chat-Zeilenlimit von 255 Zeichen gekuerzt statt vom Client abgeschnitten.
 - Cleanup: EnsureDB wird konsistent mit Punkt statt Doppelpunkt aufgerufen.

## 3.29

 - New: player names throughout BananaLoot's own windows (SR/loot window
   reservation lists, "waiting for"/winner status, Manage window, SR+
   recovery, shared loot history, roll-sync popup, minimap tooltip) are
   now colored by class, using the standard Vanilla class colors and the
   raid/party roster (no extra API calls -- piggybacks on the roster scan
   that already runs regularly). Unknown class (player never seen in the
   roster) falls back to white, same as before. Deliberately NOT applied
   to raid/party chat announcements or whisper replies, and not to the
   Load Raid list (those names are saved raid names, not players).
   The multi-winner status line no longer hardcodes green for a pending
   winner -- it now shows the class color instead, while an already-
   awarded winner still shows grey to mark it as done.

## 3.28

 - New: automatic trade tracking (Options, General tab, default OFF).
   When enabled, detects when an item previously awarded via BananaLoot
   is traded onward to another player and adds the new owner to the
   corresponding loot log entry ("/bl csvlog", new "Traded to" column).
   Detection happens via the player's own trade window
   (TRADE_ACCEPT_UPDATE, once both sides have accepted) and is broadcast
   to other trade-tracking-enabled BananaLoot users in the raid/group via
   addon message (reuses the existing roll-sync message channel), so
   hand-offs stay traceable across multiple hops even when the loot
   master isn't a party to the trade themselves. Only items actually
   awarded via BananaLoot are tracked -- unrelated trades are ignored.
   Hard limitation of the WoW trade API: a trade between two players is
   only visible if at least one of them has this option enabled.
 - Note: award broadcasts (used for the shared loot history and now also
   for trade tracking) are now sent whenever EITHER roll-sync or trade
   tracking is enabled, instead of only roll-sync as before. No behavior
   change for players using only roll-sync.

## 3.27

 - New: optional "top rolls win" mode for multi-copy drops (Options,
   General tab, default OFF). When multiple copies of the same item are
   sitting in the loot window, BananaLoot starts a single shared roll
   instead of one roll per copy, and the top N rollers (N = number of
   copies) each win one copy. A tie right at the cutoff only makes the
   tied players re-roll for the remaining copies; players already above
   the cutoff are locked in. The SR+ loss bonus for non-winning
   reservers is applied once per roll, not once per awarded copy. The
   loot window lists every winner with their roll/score (greyed out once
   awarded), with one "Award" click needed per copy. With the option off
   (default) or only a single copy dropping, behavior is unchanged from
   previous versions.

## 3.26

 - New: shared loot history ("/bl history"), part of the roll-sync
   feature family. Broadcasts every award (roll winner, manual award
   from the Manage window, raid roll -- deliberately excluding bank
   reserve, which stays silent by design) to raid/party members who
   also use BananaLoot with roll-sync enabled. Shows a simple list
   (time, item, winner, category) for the current session; the loot
   master sees their own awards immediately without a network round
   trip, everyone else via the new AW broadcast message. Not saved to
   disk -- the loot master already has their own permanent log via
   "/bl csvlog". Documented in a new dedicated README section
   ("ROLL-SYNC") covering both the popup window (v3.24) and this
   history window together.

## 3.25

 - New: "/bl sr [Item]" and "/bl unsr [Item]" let the loot master
   reserve an item for themselves (or remove that reservation) directly
   from a slash command, exactly like the whisper-based "sr [Item]" /
   "unsr [Item]" players use -- since you cannot whisper yourself in
   WoW, this was previously only possible via the "Manage" window's
   manual add. Item link via shift-click, same as /bl hr and /bl br.

## 3.24

 - New: the roll-sync feature (v3.23) now shows a real popup window
   instead of only a chat debug line. Recipients see the item icon/
   name, mode (SR/Open/ARF), a live countdown, and a standings list of
   incoming rolls (sorted by pool priority first -- Main Spec beats
   Off-Spec beats Transmog, exactly like the master's own evaluation --
   then by roll value within the same pool). Three buttons (MS/OS/TM)
   let the viewer roll directly from the window via RandomRoll, the
   same effect as typing /roll, /roll 1 99, or /roll 1 98 by hand. On
   a tie, the standings reset and the countdown restarts; on a winner,
   the result is highlighted and the window auto-closes after a few
   seconds; on cancellation, it closes immediately. New sub-option
   "Also show popup when sending (as loot master)", default OFF, since
   the master already has the same information in their loot window.
 - Fix: the Options window banner (introduced in v3.22) never actually
   displayed in-game. Custom TGA textures in this client require
   power-of-two dimensions (16/32/64/128/.../512/...); the banner was
   400x138, neither of which qualifies, so the texture silently failed
   to load. Replaced with a 512x256 power-of-two canvas (artwork in
   the top-left, transparent padding elsewhere) cropped down to the
   intended display size via SetTexCoord, the same technique already
   used for the minimap/title icon elsewhere in the addon.

## 3.23

 - New (experimental, Phase 1): optional roll-sync between BananaLoot
   users in the raid/group (Options, General tab, default OFF). When
   enabled, the loot master broadcasts roll progress (roll started, each
   counted roll, ties, winner, cancellation) via addon message to
   everyone else running BananaLoot with the option enabled. This first
   phase only implements the send/receive protocol itself -- incoming
   updates are currently shown as a colored debug line in the chat
   frame ("[BL-Sync] ..."), not yet a dedicated popup window; that is
   planned as a follow-up. Deliberately NOT synced: the list of
   SR-eligible players (the master already filters this server-side
   before a roll is even counted) and item name/icon (resolved locally
   by each client from the item ID, the same way the master already
   does). No effect on players without BananaLoot or with the option
   disabled -- normal /roll-based play is completely unaffected.

## 3.22

 - New: optional automatic Master Loot switch when targeting a known
   raid boss (Options, General tab, default ON). Only has an effect
   while you're the party/raid leader (native SetLootMethod
   restriction) and only switches TO Master Loot -- it never switches
   back to Group Loot automatically, that remains a manual action via
   the existing ML/GL button. Covers all classic Vanilla raid bosses
   plus the known OctoWoW/Turtle custom raid bosses (Molten Core's
   Incindis/Basalthar/Smoldaris/Sorcerer-Thane Thaurissan, Blackwing
   Lair's Ezzel Darkbrewer, Timbermaw Hold, and Lower/Upper Karazhan
   Halls). Note: the custom-raid boss names were sourced from internal
   AtlasLoot identifiers and are not yet individually verified in-game
   -- corrections/additions welcome.
 - New: the Options window banner was replaced with new artwork,
   spanning the exact window width (400px) instead of leaving a small
   margin on each side. The window was made 44px taller to keep every
   section below it at its previous relative spacing.

## 3.21

 - Fix: the icon shown in the SR window, the loot window, and the
   minimap button all use the same source image, which turns out to
   have the "BananaLoot" wordmark baked into its bottom ~25% (it's a
   crop of the wider banner graphic). At the small original 20px size
   this sliver of text was barely noticeable, but after the SR
   window's icon was enlarged in v3.18 it became a visibly clipped,
   half-legible "ananaLo" underneath the chest artwork. All three
   icons now crop that image via SetTexCoord to show only the clean
   chest-and-bananas portion, with their height adjusted to match the
   new (no longer square) aspect ratio so nothing looks stretched.

## 3.20

 - New: "Stop" button in the loot window, right next to "Auto: On/
   Off", immediately canceling auto mode AND an active roll (same as
   /bl stop). Unlike the Auto toggle -- which deliberately leaves an
   active roll running when switched off -- this is the equivalent of
   the panic button. /bl stop and this button now share the exact
   same code path (BananaLoot:StopAutoMode()).
 - New: the options window's banner image now spans the full window
   width at the very top (was a small, narrower logo before).
 - New: the loot window has its own, independent UI scale setting
   (Options), separate from the SR window's scale -- handy for
   shrinking just the more compact loot window on small screens
   without affecting the SR window.
 - Fix: several option labels/hints in the Options window could still
   overlap with the section below them, and some hint text could
   extend past the bottom edge of the window, depending on how many
   lines it wrapped to. Recalculated the entire layout with
   substantially more generous, individually verified spacing (rather
   than another incremental nudge), widened the hint text boxes so
   long hints wrap to fewer lines, and widened/heightened the window
   itself to fit comfortably.
 - Fix: the SR window's logo icon (enlarged in v3.18) could appear
   visually clipped by the frame's ornate corner border decoration.
   Given more margin from the corner.

## 3.19

 - New: "Auto: On/Off" toggle button in the loot window, right below
   the title, so the automatic loot run (same as `/bl auto`) can be
   started or paused with a click instead of typing the command. Its
   label always reflects the current state (analogous to the SR
   window's lock button). Note: turning it off deliberately does NOT
   cancel an already active roll -- `/bl stop` remains the command for
   that. Internally, `/bl auto` and the button now share the exact
   same code path (`BananaLoot:StartAutoMode()`), so behavior is
   guaranteed to stay identical between the two.

## 3.18

 - New: small "ML/GL" button in the SR window, right next to the SR
   lock button, toggling WoW's actual loot method between Master Loot
   (yourself) and Group Loot with one click via SetLootMethod, instead
   of going through Blizzard's raid options menu. Only has an effect
   while you're the party/raid leader (native engine restriction), and
   stays in sync with PARTY_LOOT_METHOD_CHANGED so it reflects the
   true state even if changed elsewhere.
 - New: the SR window's logo icon is noticeably larger (20px -> 44px)
   and the title is now anchored to its right instead of being frame-
   centered, so the header reads left-to-right like a normal window
   title/logo instead of fighting for horizontal space with the close/
   help/HR/BR buttons in the top-right corner.
 - New: the "Save Raid" and "Load Raid" buttons were moved into the
   same row as "Loot Window" instead of occupying a dedicated third
   row, shortening the header and giving the reservation list a bit
   more room.
 - Fix: the SR window's title ("BananaLoot - SoftReserve / SR+") could
   have its trailing "+" partially covered by the HR/BR/help/close
   button row in the top-right corner, introduced when the HR/BR
   quick-access buttons were added in v3.14. Resolved together with
   the icon/title repositioning above.
 - Fix: in the Options window (General tab), the "Max. number of SR
   per player" section could still visually run into the "Reply on
   unrecognized whisper command" hint text above it on some font/
   client configurations, even after the v3.14 spacing fix. The gap
   between the two sections was increased substantially (not just
   incrementally) and the window made taller again to match.

## 3.17

 - New: the "srlist" whisper reply now also shows, for each reserved
   item, which OTHER players are also SR'd on it and their current
   SR+ bonus -- e.g. "Also SR'd: Nareg(+30), Toreg" as a follow-up
   whisper line after the item itself. This isn't new information as
   such (the same names/bonuses already become visible to everyone
   once a roll starts or via the loot preview), it's just available
   proactively on request now. Lists longer than 8 co-reservers are
   shortened with "+N more" to stay within the whisper's character
   limit. A player who is the only one reserved on an item sees no
   extra line, as before.

## 3.16

 - New: local Save Raid / Load Raid feature, independent of the
   existing Export/Import (which remains fully intact for sharing
   with a stand-in via timestamped text/Google Sheets). Two new
   buttons in the SR window ("Save Raid" / "Load Raid"):
    - Save Raid: enter a name and save; an existing name prompts for
      confirmation before overwriting.
    - Load Raid: opens a list of all locally saved raids (with last-
      saved timestamp), each with "Load" and "Delete" actions;
      loading prompts for confirmation since it replaces the current
      state.
   A saved/loaded raid's name is shown as a subtitle under the SR
   window's title, so it's always clear which raid is currently
   active. Snapshots include current reservations, all players' SR+
   values, and the SR+ recovery list; Hard Reserve and Bank Reserve
   remain global/independent of any snapshot, since they're meant to
   persist across raids rather than being tied to one.

## 3.15

 - New: optional loot preview in raid/party chat (Options, default ON).
   When a NEW loot window is opened, BananaLoot posts a one-line-per-
   item overview BEFORE any roll is started, so players know in
   advance how each item will be handled: "[Item] [SR]: Name(+Bonus),
   ..." for SR-reserved items, "[Item] [Offen]/[Open]" for items open
   to everyone, "[Item] [HR]" for Hard Reserve items. Bank Reserve
   items are deliberately never included, since they are meant to be
   awarded completely silently.
 - Fix: reopening the loot window for the same corpse (e.g. clicking
   the same boss/chest again without looting anything new) no longer
   re-triggers the "Loot detected" sound, the chat summary, or the new
   loot preview a second time. Detection is based on the exact set of
   items still present; the guard resets once every item from that
   loot window has actually been awarded, so a genuinely new kill with
   a coincidentally identical item set (e.g. two trash mobs both only
   dropping Linen Cloth) is still announced normally.

## 3.14.1

 - Fix: replying to "srlist" for a player with an active SR+ bonus
   could throw a client-side "SendChatMessage(): Invalid escape code
   in chat message" error (visible in chat via addons that hook
   SendChatMessage, e.g. pfUI's macrotweak module, though the root
   cause was on our end). The SR+ bonus suffix appended after the item
   link started with a bare "|" character, which WoW's chat protocol
   interprets as the start of a formatting code -- invalid without a
   matching code letter. The separator was changed from " | " to
   " -- " to avoid the raw pipe character entirely. Only affected the
   "srlist" whisper reply when the player had a stack (SR+) greater
   than 0; unaffected reservations (SR+ 0) never appended the suffix
   and were never affected.

## 3.14

 - New: Bank Reserve (BR) list -- a second reserve list alongside Hard
   Reserve, for items that should never be rolled or announced in raid/
   party chat at all (tradeskill mats for the guild bank, BoE items to
   sell/craft, etc.). BR items are detected silently on loot and
   automatically awarded to the loot master (you) via GiveMasterLoot,
   with only a local chat confirmation visible to you -- no roll, no
   raid/party announcement, no entry in the loot window. Managed via
   /bl br [Item], /bl br remove [Item], /bl br (list), or the new "BR"
   quick-access button in the SR window's title bar.
 - New: matching "HR" quick-access button next to the existing "?"
   help button in the SR window's title bar, opening the Hard Reserve
   list directly without going through /bl hr.
 - Fix: clicking "Remove" in the Hard Reserve list could throw a Lua
   error ("attempt to index field '?' (a nil value)") because the
   confirmation chat message read the item's link from the list AFTER
   already removing the entry from it. The link is now captured before
   removal.
 - Fix: in the Options window (Display & Sound tab), the "Reply on
   unrecognized whisper command" hint text and the "Max. number of SR
   per player" section below it could visually overlap on longer
   translations. The lower section was moved down and the window made
   slightly taller to give both enough room.

## 3.13

 - New: the single main window is now split into two separate windows:
   - SR window (/bl, minimap left-click): persistent overview of all
     current reservations (whisper sr/unsr, raidres.top/MSRv2 import).
     Holds Export/Import/Options/Lock and a button to open the loot
     window.
   - Loot window (/bl loot): only the items currently visible in the
     real loot window, with Roll/ARF/Award. Opens automatically when
     loot is detected (LOOT_OPENED), independent of the SR window.
 - New: the "Manage" popup is now context-aware. Opened from the SR
   window it only offers list editing (view/±/remove/add player) and
   "Delete reservation". Opened from the loot window it additionally
   offers "Winner" and "Raid Roll", and its removal button is "Skip
   drop" (removes only the loot entry, keeps the SR reservation intact
   for a possible re-drop).
 - New: the Options window is now split into three tabs (General /
   Display & Sound / Management) instead of one long scrolling list,
   noticeably shorter and easier to navigate.
 - New: the command legend ("?") moved from Options into the SR window,
   reachable without opening Options, including mid-loot.
 - Fix: a scope bug where opening "Manage" from the loot window threw
   a Lua error ("attempt to index global 'mgRemoveItemBtn'") due to a
   forward-reference; fixed with a proper local forward declaration.
 - Fix: the loot window button in the SR window's header overflowed
   past the window's right edge; moved to its own row.
 - Fix: replaced an untested Lua vararg pattern (the only place in the
   whole addon that would have relied on it) with the same
   table.getn()-based approach already used everywhere else, removing
   an unnecessary compatibility risk.
 - /bl now opens the SR window specifically (previously the single
   combined window); use /bl loot for the loot window.

## 3.12

 - New: static item database (BananaLootItemDB.lua, ~3600 entries)
   shipped with the addon, sourced from OctoWoW's own AtlasLoot fork
   plus a generic Vanilla item list as a name-only fallback. Works
   around this server's GetItemInfo() limitation, which never returns
   data for items the client hasn't independently seen before.
 - New: raidres.top imports now resolve item names (and correct
   rarity color) immediately from the static database when raidres.top
   itself doesn't supply a name, instead of only showing "Item #ID"
   until the item actually drops.
 - New: the same static database is now also used as a fallback in
   TryUpgradeSyntheticLink, so any other placeholder link (MSRv2
   import, ARF on an unknown item, etc.) can upgrade to a real,
   colored item link without needing GetItemInfo() to succeed.
 - No behavior change for items already resolvable via GetItemInfo()
   or via an actual loot window scan; the existing placeholder-then-
   upgrade-on-loot fallback is fully preserved for anything not (yet)
   covered by the static database.
