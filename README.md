<p align="center">
  <img src="BananaLoot.png" alt="BananaLoot" width="400">
</p>

# 🍌 BananaLoot **(Alpha)**

**Masterloot addon with chat-based soft-reserves and a local SR+ bonus system**
for World of Warcraft Classic 1.12 (OctoWoW, Turtle WoW, and similar Vanilla servers)

Behavior is inspired by the well-known RollFor workflow – the code itself is
fully original (no code copied from elsewhere).

1. Download [Latest Version](https://github.com/BaregBananenrepublik/BananaLoot/releases/latest)

---

## What is BananaLoot?

BananaLoot takes the paperwork off the master looter's plate: players reserve
items the normal way via whisper, the addon remembers everything locally,
evaluates rolls automatically, and suggests SR+ bonuses for players who have
soft-reserved an item multiple times without winning it.

No external service, no login, no dependency on working HTTP in the game
client – everything runs entirely locally via SavedVariables.

---

## Features

### Whisper-based soft reserve
- Players simply whisper `sr [Item]` or `unsr [Item]` to the master looter
- `srlist` shows a player's own reservations including bonus
- `hr` / `hrlist` lists all current Hard Reserve items
- Exactly 1 SR per raid is active – reserving a new item automatically drops
  the old reservation (with a heads-up sent via whisper)
- Spam protection (max. 1 command every 2 seconds per player)
- Unknown commands get a reply instead of being silently ignored

### SR+ bonus system
- Anyone who reserved an item but didn't win it automatically gets a stack
  bonus for the next roll on that same item
- Bonus per stack is freely configurable (default: +10)
- SR+ values persist across raids and relogs

### Hard Reserve (HR)
- Permanently reserve items for a specific player, independent of the
  whisper system
- Never rolled automatically – awarded exclusively by hand
- Dedicated management view with an overview and a remove button per item

### Automatic roll evaluation
- Detects Main Spec (`/roll`), Off-Spec (`/roll 1 99`), and Transmog
  (`/roll 1 98`) rolls automatically via system chat
- Priority: Main Spec > Off-Spec > Transmog
- If an item is soft-reserved, only the reservers may roll Main Spec –
  Off-Spec/Transmog stays open to everyone
- Resolves immediately once all eligible players have rolled (no need to
  wait for the timeout)
- On a tie, only the affected players are automatically asked to re-roll
- Configurable timeout as a fallback (default: 60 seconds)
- Optional chat countdown in the final seconds (10/5/3/2/1), can be toggled off

### Loot window automation
- Automatically detects when a loot window is opened as master looter
- `/bl auto` works through the entire chest one item at a time: non-SR items
  first (open to everyone), SR items afterward (reservers only)
- Multiple drops of the same item are counted correctly and handled one by one
- `/bl arf [Item]` suspends SR for a single roll (open to everyone)
- Attempts to award automatically via the master loot API – if that fails,
  the winner is displayed clearly so you can award manually instead

### Manage window
- For every item: view all reservers including their SR+ bonus
- Manually adjust SR+ stack (+/-)
- Manually add or remove players
- Directly set a winner and award instantly (with a confirmation prompt)
- Warns if a manually entered name isn't currently in the raid
  (typo protection)

### Export / import for a stand-in loot master
- Export the complete SR list (including SR+ values and Hard Reserves) as text
- The stand-in simply pastes the text into their own BananaLoot and is
  immediately up to date

### CSV export for Google Sheets
- Export the SR list and the full loot log as tab-separated text
- Just paste into an empty cell in Google Sheets – done

### Other
- Loot log records every award (date, item, player, category)
- Draggable minimap button with a custom icon
- Dedicated options window with banner

---

## Installation

1. Copy the `BananaLoot` folder into `World of Warcraft/Interface/AddOns/`
2. Restart the client or `/reload`
3. Keep it enabled under "AddOns" on the character selection screen

---

## Key commands

| Command | Effect |
|---|---|
| `/bl` | Open/close the window |
| `/bl auto` | Automatically work through the current loot chest |
| `/bl award` | Award the most recently evaluated item to the winner |
| `/bl arf [Item]` | Open roll for everyone, SR suspended for this roll |
| `/bl stop` | Cancel auto mode / the active roll |
| `/bl reset` | Clear all current reservations (SR+ values are kept) |
| `/bl wipeplus` | Completely reset all SR+ values |
| `/bl export` / `/bl import` | Share the SR list with a stand-in |
| `/bl csv` / `/bl csvlog` | Export the SR list / loot log as CSV for Google Sheets |
| `/bl hr [Item]` | Mark an item as Hard Reserve |
| `/bl hr` | Show the Hard Reserve list |
| `/bl options` | Open settings |

Full command overview is also available in-game via `/bl` with no arguments.

---

## Honestly: limitations of this addon

No loot tool is perfect – here are the deliberate trade-offs:

- **Automatic awarding is best-effort.** Assignment via the master loot API
  can fail depending on the server implementation. In that case the addon
  clearly displays the winner so the final award can be done manually in
  the Blizzard loot window.
- **No softres.it or raidres.io import.** The SR list comes exclusively from
  in-game whispers.
- **One SR per player per raid**, enforced as a fixed rule – there's no
  option to allow multiple simultaneous reservations.
- **No automatic class or spec prioritization.** Everything runs on rolls,
  not on a rules engine.
- Tested primarily on OctoWoW/Turtle WoW – other 1.12 servers may differ in
  details (e.g. master loot API behavior).

---

## Technical details

- Pure Lua, no XML – the entire UI is built at runtime
- Compatible with Lua 5.0 (no `#` operator, no `string.gmatch`)
- Data is stored locally in
  `World of Warcraft/WTF/Account/<ACCOUNT>/SavedVariables/BananaLoot.lua`
  and survives relogs and patches

---

## Author

**Bareg**

---

## License

Use at your own risk. Not a substitute for common sense while master looting. 🍌

<p align="center">
  <img src="BananaLootIcon.jpg" alt="BananaLoot" width="400">
</p>
