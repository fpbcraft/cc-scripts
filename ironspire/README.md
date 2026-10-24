# IRONSPIRE — Clockwork Ascent v0.2.0

A single-player, Slay the Spire-inspired **deckbuilding roguelike** for CC:Tweaked, built around RAILBREAK's pixel-art renderer. The game uses a responsive advanced-monitor touchscreen; CC: Graphics mode 2 when available, otherwise colour-text drawing. No Create peripherals are controlled.

## Install

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-ironspire.lua
/ironspire/main.lua
```

The launcher selects the largest attached monitor automatically. To pick one, run `/ironspire/main.lua monitor_0`. The installer downloads into a staging area, checks Lua syntax, then replaces application files with rollback protection. Existing `/ironspire/data/save.lua` is never touched. To opt into autostart on a dedicated computer, add `--startup`; it never overwrites an existing startup file.

## Rules

- Begin with a 10-card deck and 72 HP. On each turn draw five cards, spend three energy, then press **END TURN** to resolve the visible enemy intent. Block absorbs damage for one turn; enemy armour absorbs your attacks; vulnerable enemies take 50% more damage.
- After fights, choose one of three new cards or skip. Your deck persists for the entire run. Draw/discard piles reshuffle as needed.
- Each expedition generates a **persistent, branching nine-floor route** with battle, elite, event, rest, shop and boss nodes. Only connected destinations on the next floor are selectable. Rest to heal 22 HP or train for +4 maximum HP; buy cards (50 gold), healing (30 gold), or remove the first card from your deck (40 gold).
- Some paths include encounters with optional tradeoffs; floor nine is the Gear Colossus boss. Tap the **?** button on a combat card to inspect its cost, full effect, damage, block, and draw before playing.
- Defeat ends your run; victory is earned by defeating the boss. There is no real-time timer or network requirement.

Saves are written after combat actions, enemy turns, and travel to `/ironspire/data/save.lua`. Press **Q** on a connected keyboard to exit. A built-in computer terminal can be used, but a sufficiently large advanced monitor (ideally 4×4 or 5×5) is recommended for the card interface.

## Maintainer verification

Launch `/ironspire/main.lua --test-api` in a Lua runtime that supports the installed game modules to verify imports without starting the event loop. The installer performs this boot check when available.

**Scope:** This is the first playable edition, not a full recreation of Slay the Spire: no relic system, ascension levels, or multiple characters yet.
