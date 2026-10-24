# COGWORKS: Kinetic Lab

A compact **construction puzzle** for CC:Tweaked, inspired by Create's rotational power transmission. Build mechanical networks with a limited inventory rather than rotating a prebuilt solution.

There are **30 curated construction puzzles** in a 7 x 6 workshop. The first three levels introduce the mechanics; levels 4–30 require you to create **fully connected** working machines, with increasingly restrictive stock, rock walls, branching transmission lines, reversing gears and 2x speed drives. Late stages have up to **five** press targets and over twenty machine parts.

### Campaign difficulty

- **1–3 — Fundamentals:** Build, turn and route a single shaft line.
- **4–10 — Routing contracts:** Two press targets, obstacle detours, exact inventory, and the first reversing/speed stages.
- **11–15 — Distribution:** Three targets connected to one source; multi-way splitters and mixed output requirements.
- **16–20 — Kinetic networks:** Long branches, combined gear/drive requirements and up to four presses.
- **21–25 — Industrial puzzles:** Four output targets, crowded boards, precise placement of specialized equipment.
- **26–30 — Master challenges:** Four or five presses, multi-stage transformations, tight stock, and dense obstacles.

**Advanced contract (level 4 onward):** To complete the workshop, *every available part must be placed and powered*, **every port must connect** to a matching adjacent port, and **every target must have the correct speed/direction**. A glowing press does not mean the puzzle is finished if a shaft is dangling or stock is unused.

## One-command install / update

On an Advanced Computer with HTTP enabled:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-cogworks.lua
```

Run with:

```lua
/cogworks/main.lua
```

You can add `--startup` to the installer on a dedicated computer (existing unrelated startup scripts are never overwritten). The updater downloads and syntax-validates everything before activating, rolls back on failures, and preserves `/cogworks/save.dat`.

To test a development branch, install directly from its raw URL and pass the branch name as an argument:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/cogworks-30-level-campaign/install-cogworks.lua feat/cogworks-construction-v2
```

## How to play

1. Identify the **green engine (S)** and **blue press targets (M)**. Each target displays a required sign and RPM, such as `+1`, `-1`, `+2` or `-2`.
2. Select a component from the right-hand **PARTS** inventory. Its stock count is shown next to its name.
3. Tap an empty workshop cell to **place** that part. Tap a part already placed to **rotate** it by 90 degrees.
4. Select **REMOVE** to salvage a misplaced part (stock is refunded). You cannot change the source, goal presses, or stone walls.
5. Connect ports so power flows from the source to **every target** at the correct RPM and direction. Starting at level 4, you must also use the whole inventory, close all ports and ensure every part is powered.
6. Use **HINT** to fix one misplaced, missing, or misrotated piece at a time. **RESET** empties the board and restores your stock. Next levels unlock upon completion.

Every puzzle starts empty, except for its fixed terminals and obstacles. Some levels reward thoughtful use of tees/splitters, others force you to reverse spin or double shaft speed using specialized parts.

### Machinery legend

| Part | Display | Function |
|---|---|---|
| **Generator** | Green S, fixed | Outputs clockwise `+1` power |
| **Press** | Blue M with a numeric target, fixed | Must receive exactly the displayed power |
| **Shaft** | Straight connector | Carries power through two opposite sides |
| **Elbow** | Right-angle connector | Turns power through 90 degrees |
| **Splitter** | Three-way connector | Carries power to multiple machines |
| **Gear** | Purple toothed ring | Reverses rotation direction |
| **2x Drive** | Amber `2` with a green input marker | Doubles RPM from input to output; reverse flow halves it |
| **Stone** | Dark blocked square | Cannot hold machinery |

The ports are always visibly marked on the corresponding edges. Connected, powered machinery animates with amber motion markers. A target turns green when its speed and rotation are correct. Inconsistent closed loops can cause a red **JAM** warning.

### Other controls

- Top bar: **PREV**, **NEXT**, **RESET**. NEXT unlocks as you complete levels.
- Sidebar: **HINT** and **HELP** (illustrated legend).
- Keyboard: `1`–`5` select parts; `6` remove; `H` hint; `R` reset; `P` previous; `N` next; `?` help; `Q` quit. Ctrl+T exits.
- The game saves each board layout, current level, unlocked levels, and best hint-free move counts. Quitting/reinstalling does not wipe progress.

## Displays and dependencies

- CC:Tweaked Advanced Computer and a color Advanced Monitor. A **3×3 or larger** monitor is recommended.
- [CC: Graphics](https://modrinth.com/mod/cc-graphics) enables the higher-resolution, animated pixel display.
- Without CC: Graphics, the game automatically switches to a **fully playable text UI**, on a sufficiently large Advanced Monitor.
- The game chooses the largest color monitor; optionally provide a monitor peripheral name, e.g. `/cogworks/main.lua monitor_1`.
- No actual Create machinery is controlled. This is a standalone game inspired by Create's engineering.

## Testing

```bash
lua5.3 tests/cogworks_test.lua
lua5.3 tests/cogworks_renderer_test.lua
lua5.3 tests/cogworks_installer_test.lua
```

The pure Lua engine includes validated reference network solutions for all 30 levels. Regression tests verify inventory depletion/refunds, building, rotation, hint recovery, save serialization, target RPM and direction, pixel and text input, and installer rollback.
