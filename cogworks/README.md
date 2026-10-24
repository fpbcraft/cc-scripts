# COGWORKS: Kinetic Lab

A compact **construction puzzle** for CC:Tweaked, inspired by Create's rotational power transmission. Build mechanical networks with a limited inventory rather than rotating a prebuilt solution.

There are **12 handmade stages** on a 6 x 5 workshop grid, with obstacles, branching circuits, clockwise/counterclockwise requirements, and RPM multipliers. The later stages require powering as many as three machines at different speeds and/or directions.

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
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/cogworks-construction-v2/install-cogworks.lua feat/cogworks-construction-v2
```

## How to play

1. Identify the **green engine (S)** and **blue press targets (M)**. Each target displays a required sign and RPM, such as `+1`, `-1`, `+2` or `-2`.
2. Select a component from the right-hand **PARTS** inventory. Its stock count is shown next to its name.
3. Tap an empty workshop cell to **place** that part. Tap a part already placed to **rotate** it by 90 degrees.
4. Select **REMOVE** to salvage a misplaced part (stock is refunded). You cannot change the source, goal presses, or stone walls.
5. Connect ports so power flows from the source to **every target** at the correct RPM and direction. All goals must be satisfied simultaneously.
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

The pure Lua engine includes canonical network solutions for all 12 levels. Regression tests verify inventory depletion/refunds, building, rotation, hint recovery, save serialization, target RPM and direction, pixel and text input, and installer rollback.
