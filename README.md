# FPBCRAFT CC:Tweaked scripts

ComputerCraft/CC:Tweaked programs for the FPBCRAFT Minecraft server.

## Games

- [COGWORKS](games/cogworks/README.md) — machinery construction puzzles.
- [RAILBREAK](games/railbreak/README.md) — railway adventure, cargo and train upgrades.
- [SHATTERED](games/shattered/README.md) — space 4X with human and AI empires.
- [IRONSPIRE](games/ironspire/README.md) — touchscreen deckbuilding roguelike.
- [CIVCRAFT](games/civcraft/README.md) — local hotseat and networked civilization building.

## Apps

- [FPB Store](apps/fpbstore/README.md) — search, install, update and launch games.
- [Airship navigation](apps/airship/README.md) — Basalt touchscreen autopilot and routes.
- [Factory controller](apps/factory/README.md) — machine controls and telemetry.
- [Remote node](apps/node/README.md) — paired factory telemetry and remote control.

## Installation

Installers live in `installers/<id>.lua`. For example:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/fpbstore.lua
/apps/fpbstore/main.lua
```

Use `cogworks`, `railbreak`, `shattered`, `ironspire`, `civcraft`, `airship`,
`factory` or `node` instead of `fpbstore` for a direct install. An optional first
argument selects a Git ref; `--startup` and `--no-startup` control autostart.
Airship, factory and node enable autostart by default; games and Store do not.

**Layout v2 is a clean path change.** Programs now install under `/games/<id>`
or `/apps/<id>`. Reinstall the Store with the command above; old Store versions
cannot self-update across the installer URL change. Old installer URLs and
`/store.lua` are no longer provided. Update any custom launch commands yourself.

Reinstall each program to copy its known saves/configuration from the old root.
Originals remain intact. Conflicting destination data stops installation; resolve
the reported files and retry. Migration runs once, so later updates preserve your
new progress. Remove old installations manually only after checking the new one.
See [installation and library details](lib/fpb/README.md).

All factory controls must retain a physical manual override. Do not rely on
software alone for machinery safety.
