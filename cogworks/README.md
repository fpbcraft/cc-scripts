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

**Main objective (all 30 levels):** Supply every fixed press with its required rotation direction and RPM. You unlock the next level as soon as all press targets are satisfied and the machinery is not jammed. **You do not need to consume all stock or seal every open port to progress.**

### Optional bonus contracts

Most levels also provide up to three harder, independently earnable bonuses. Tap **BNS** in the graphics sidebar (or press `C` at the computer) to open the challenge list and see saved completions.

| Bonus | Availability | Requirement |
|---|---|---|
| **Sealed Lines** | Levels 2–30 | Every placed part powered, with no unconnected ports |
| **Full Factory** | Levels 3–30 | Every allocated part placed, powered and fully connected |
| **Precision** | Levels 5–30 | No hints and at most the displayed move budget |

Bonuses do not block the next level. They are awarded only on a successful main-objective completion, persist in `/cogworks/save.dat`, and can be earned in later replays. A level's authored solution satisfies all of its applicable bonuses; the bonus requirements are deliberately more restrictive than the main objective.

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
5. Connect ports so power flows from the source to **every target** at the correct RPM and direction. No full-inventory or sealed-circuit requirement applies to normal completion. Optional bonuses reward those advanced restrictions.
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

The ports are always visibly marked on the corresponding edges. Connected, powered machinery animates with amber motion markers. A target turns green when its speed and rotation are correct. **Red end caps** identify open/unconnected ports (important for the optional bonuses). Inconsistent closed loops can cause a red **JAM** warning.

### Other controls

- Top bar: **PREV**, **NEXT**, **RESET**. NEXT unlocks as you complete levels.
- Sidebar: **HNT** (hint), **?** (illustrated rules), and **BNS** (optional bonus contracts).
- Keyboard: `1`–`5` select parts; `6` remove; `H` hint; `R` reset; `P` previous; `N` next; `C` bonus contracts; `?` help; `Q` quit. Ctrl+T exits.
- The game saves each board layout, current level, unlocked levels, best hint-free move counts, and permanent bonus awards. Quitting/reinstalling does not wipe progress.

## Displays and dependencies

- CC:Tweaked Advanced Computer and a color Advanced Monitor. A **3×3 or larger** monitor is recommended. The program explicitly sets the monitor text scale to **0.5**, and the Graphics renderer clears the entire framebuffer, including letterbox margins, with a dark background.
- [CC: Graphics](https://modrinth.com/mod/cc-graphics) enables the higher-resolution, animated pixel display.
- Without CC: Graphics, the game automatically switches to a **fully playable text UI**, on a sufficiently large Advanced Monitor.
- The game chooses the largest color monitor; optionally provide a monitor peripheral name, e.g. `/cogworks/main.lua monitor_1`.
- Minecraft's standard `monitor_touch` event is **right-click only** and does not report mouse button. Left-click/right-click separation on the physical monitor requires a separate input-capable mod. The regular right-click tap builds/rotates, while the **REMOVE** tool salvages any removable part. For compatible addons that append an explicit mouse-button field to `monitor_touch`, right-button taps remove directly.
- No actual Create machinery is controlled. This is a standalone game inspired by Create's engineering.

## Testing

```bash
lua5.3 tests/cogworks_test.lua
lua5.3 tests/cogworks_renderer_test.lua
lua5.3 tests/cogworks_installer_test.lua
```

The pure Lua engine includes validated reference network solutions for all 30 levels. Regression tests verify inventory depletion/refunds, building, rotation, hint recovery, standard versus bonus completion, target RPM and direction, full framebuffer clearing, pixel and text input, and installer rollback.
