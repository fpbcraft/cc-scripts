# TIDEBOUND: KINGDOMS (v2.1)

A local, **two-player strategy board game** built for [CC:Tweaked](https://tweaked.cc/) Advanced Monitors. Inspired by the territorial expansion of **Risk**, resource production and settlements in **Catan**, the map-first interaction of **Carcassonne**, and the long-term development of **Civilization**.

This is a **new game mode**, not the previous naval-combat game. The original is included as `tidebound-classic.lua` if you want to keep playing it.

## Supported monitor sizes

| Advanced Monitor | Support | Notes |
| --- | --- | --- |
| 3×3 | Yes | Compact on-screen keyboard and command panel |
| **4×4** | **Yes** | More map provinces and generous touch targets |
| **5×5** | **Yes** | Larger map, full-screen board, centered dialogs |
| Other shapes/sizes | Adaptive | At 0.5 text scale, requires **at least 45 columns × 34 rows** |

The Lua game **measures the connected monitor's character resolution**. There is **no hardcoded 3×3 grid**. World dimensions, tile hitboxes, effects, dialogs, and on-screen keyboard are calculated from that resolution. Every area of the monitor is rendered as map terrain; only the small top HUD and the contextual order panels are overlaid. You can resize the physical monitor during a match without changing the saved world's grid.

## Requirements

- CC:Tweaked on your computer (including NeoForge 1.21.1 distributions).
- One **Advanced Monitor** (colour, right-click/touch-capable), connected to a ComputerCraft computer or Advanced Computer (directly or over wired modems).
- Optional speaker for touch-feedback notes.
- No HTTP access, external APIs, libraries, or redstone signals needed.

## Installation

1. Upload **`tidebound.lua`** to your CC:Tweaked computer. You can drag the `.lua` file from your desktop onto its in-game computer terminal, or place it under your world's `computercraft/computer/<id>/` folder.
2. Attach the Advanced Monitor. Construct a **3×3, 4×4, or 5×5** monitor by placing the blocks side by side on the same plane.
3. On the computer terminal, run:

    ```sh
    tidebound
    ```

   If multiple monitors are connected, select one using its peripheral name:

    ```sh
    tidebound right
    tidebound monitor_0
    ```

4. On the title screen, tap **NEW KINGDOMS** (or **CONTINUE** to resume an existing match).
5. Enter player names with the **on-monitor touch keyboard**: tap a name field, tap letters, use **SPACE**, **CLEAR**, **<** (backspace), and **NEXT** to switch players. Physical typing into the computer terminal is also supported in setup.
6. Choose **CONTINENT** or **ISLANDS**, plus **SWIFT / 20** or **EPIC / 40** point targets. Tap **START GAME**.

The game sets text scale to **0.5** automatically for maximum space and restores the original scale and palette on normal exit. Stop it with **Ctrl+T** on the connected computer terminal.

## How to play

Each player controls a kingdom on a fully visible procedural map. The map is symmetric so starting terrain and production are balanced.

- **3 action points per turn.** Tap any province to open its available orders. A player may finish early with **END TURN**.
- **CLAIM** a neutral land province adjacent to your borders (cost: 1 food + 1 wood).
- **FOUND** a village on your territory (4 wood + 2 stone) and **UPGRADE** it twice into a more productive town/city (4 wood + 4 stone per level).
- **RECRUIT** two armies at a settlement (3 food + 1 stone; up to nine armies per province).
- **FORT** an owned province (+1 defense level; costs 2 wood + 2 stone).
- **MARCH** up to half your province's army into an adjacent friendly province; tap a highlighted province to select the destination.
- **ATTACK** an adjacent enemy from an army; tap the attacking province, then **ATTACK**, then a highlighted defender. Combat compares committed armies + a D3 roll versus defense (armies + fort, settlement, terrain) + a D3 roll. An unsuccessful attack loses attackers; the outcome is shown in the HUD. Capturing the enemy capital wins immediately.

### Resources and prestige

After **both players finish their turns**, all controlled terrain produces resources:

| Tile | Production each round |
| --- | --- |
| Meadow (`.`) | 2 food |
| Forest (`*`) | 2 wood |
| Hill (`^`) | 2 stone |
| Mountain (`M`) | 1 stone |
| Sea (`~`) | Cannot be claimed |

The game starts with 6 food, 6 wood and 4 stone per player, and resources are capped at 50 each.

**Prestige** is also awarded at round end: capital = 2, other settlements = their level, ancient sites (`#`) = 1. The first player to reach the configured target (20 or 40) wins. If neither reaches the target, the game ends after 26 rounds, with score then territory as tiebreakers.

Both players share one physical tabletop screen, and both can see each other's actions. An optional speaker makes a short note on button presses.

## Controls and interface

- **Map** uses the entire monitor; province borders, ownership stripes, settlement icons, troop counts, and ancient site markers are all drawn directly on the terrain.
- **Small top HUD** shows player names, prestige, resources, current turn, **MENU** and **END TURN**.
- **Contextual order overlay** appears after selecting a province. Tap **CLOSE** to return to the map.
- **Target mode** switches to a small prompt at the *top of the screen* so that the bottom rows of the map remain accessible for moving and attacking. Highlighted neighbouring provinces are valid destinations.
- **MENU** returns to the animated title screen without discarding your current match; tap **CONTINUE** later.
- A new match prompts for confirmation before replacing an unfinished saved campaign.
- Movement and combat use sub-second easing, flashes and ripples. The terrain water texture and title-screen embellishments animate. Dirty-row buffering reduces writes to the monitor.

## Saving

The game automatically saves state-changing actions and turn endings to **`tidebound-kingdoms.save`**, alongside the Lua script. A temporary `.tmp` and rollback `.bak` file protect against interrupted replacement of a save. **Version 2 saves are compatible with this 2.1 update.**

The old naval game used **`tidebound.save`**, so its save is not overwritten or migrated by Kingdoms.

## Tests

This package has two independent ways to test without a Minecraft installation:

```sh
texlua tidebound.lua --self-test
texlua tests.lua
```

The test suite covers randomized world symmetry, economy, legal and illegal actions, combat, and full touch-controlled gameplay on representative **3×3, 4×4 and 5×5** monitor resolutions, including resize support and save-replacement prompts.

**Status:** Verified with offline Lua tests and a mocked monitor implementing `getSize`, `setCursorPos` and `blit`. Actual in-game monitor latency, rendering, sound effects and multiplayer interaction have **not yet been verified in Minecraft**.