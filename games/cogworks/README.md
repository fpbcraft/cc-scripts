# COGWORKS: Kinetic Lab

> **Campaign redesign:** [Discovery-Driven 64-Level Campaign Design](CAMPAIGN_DESIGN.md)
> specifies the intended puzzle insights and variations. This branch now contains
> a **playable first implementation**: 64 distinct solver-verified layouts,
> including 34 bespoke circuits and 30 authored variations of proven kinetic
> constructions. Further manual playtesting and refining the remixes against
> their design briefs remains necessary.

A touchscreen-first construction puzzle for CC:Tweaked, based on the rotational
transmission mechanics in the Minecraft [Create mod](https://github.com/Creators-of-Create/Create/wiki).

The previous 30-stage campaign and its fictitious elbow, splitter, inline-speed
drive and inline-reversing gear have been **removed entirely**. The **64-stage, eight-chapter campaign** introduces the actual principles of shaft axes, side-meshing
cogs, bevel gearboxes, encased chain drives, mechanical belts and redstone
devices. COGWORKS is a standalone game; it does **not** control Minecraft machines.

## Install or update

On a computer with HTTP access enabled:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/cogworks.lua
/games/cogworks/main.lua
```

To try this branch before merging, run the branch's installer and pass the branch
name as the positional ref:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/cogworks-64-campaign-editor/installers/cogworks.lua feat/cogworks-64-campaign-editor
/games/cogworks/main.lua --dev
```

The installer preserves saves and settings. The handcrafted campaign uses **version-6** save data and starts a new
campaign when loading incompatible generated-layout saves. A permanent
`slot-N.dat.campaign-v5` backup is retained before an older slot is
overwritten. Display settings are preserved.

## High-resolution CraftOS and iPad interface

Cogworks uses CivCraft's graphics density of **three logical pixels wide
by four high per terminal character** when CC:Graphics is available.
On larger screens it now renders an actual full-resolution interface,
rather than magnifying a fixed 200×120 screen or showing that design in
a small central window. This includes a broad mission briefing, dedicated
mechanical board, two-column component palette, clear optional goals,
larger controls, branching maps, save slots, menus, tutorial overlays,
and custom pack browsers. Visual hit targets and input coordinates use
the same graphics transform, including after a resize.

A compact 200×120 design is retained for smaller graphics monitors and
the existing text-mode fallback remains supported. On attached monitors,
Cogworks requests text scale 0.5 before initializing its graphics renderer
and restores the original scale on exit; an emulator's built-in terminal
may not offer the monitor text-scale API.

For CraftOS-PC on iPad, the mouse input handler also accepts click-only
taps when `mouse_up` is absent, while retaining drag movement when the
appropriate events are available. Use `--input-debug` to capture the raw
pointer events and resolved board actions if touch input remains unusual.

## Mechanical components

COGWORKS uses an intentionally **two-dimensional abstraction** of Create:
rotation is described in a consistent top-down board view, with CW/CCW and
relative RPM. Three-dimensional axis alignment and Create's stress/overstress
budget are not simulated. The connection rules below replace the older
generic-port mechanics.

| Key | Part | Create-inspired interaction |
| --- | --- | --- |
| I | Shaft | Two opposing shaft ends, same speed and spin |
| G | Small cogwheel | Axial shaft ends; toothed rims on perpendicular neighboring cells mesh and reverse spin, at 1:1 for small/small or 2:1 for small/large |
| O | Large cogwheel | Axial shaft ends; toothed-rim neighbors mesh at 1:1 for matching sizes or 2:1 with small cogs, either side-adjacent or diagonally |
| Q | Gearbox | Accepts power from any of four sides; outputs on the other sides reverse spin (1:1 speed) |
| D | Encased chain drive | Axial shaft ends, plus same-axis chain links to neighboring chain drives **perpendicular** to their shafts; no speed/sign change |
| V | Belt pulley | Axial shaft ends; parallel pulleys connect even when adjacent; shafts can pass through intervening belts, preserving speed and spin |
| Z | Gearshift | Acts as a straight shaft; when redstone-powered, reverses the output's spin |
| C | Clutch | Acts as a straight shaft; when redstone-powered, disconnects the output |
| R | Dust | Connects orthogonally to redstone blocks, other dust and devices |
| B | Redstone block | Supplies power to adjacent dust and switches |

**Redstone dust and blocks now replace the switch tool.** A block powers
adjacent dust or clutches/gearshifts; dust transmits power through orthogonal
connections, corners, T-junctions and crosses. Redstone must be placed in an
empty cell and may not overlap machinery.

Power conflicts (incompatible speed/direction reaching the same shaft)
are jams. Green/coral machine faces indicate whether a press receives the
requested spin and speed.

## Modes

### Campaign

Sixty-four levels occupy **eight interconnected factory districts**. Touch a
district on the overworld, then follow dotted tracks between puzzle nodes.
Completing a puzzle reveals adjacent nodes; different routes let players
skip a troublesome puzzle and return to it later. **Any three distinct
clears within a district unlock the next district**. Bonus objectives
never gate access to required campaign content.

Each district contains a network of six ordinary puzzles, an optional
expert side path (#7), and an optional finale (#8). The finale can be
reached via either the main route or the expert detour, and neither extra
stage is required to leave a district. Clear status and optional rewards
appear on each map node. Puzzles have **zero, one or two optional bonuses**
depending on the design; bonuses are awarded independently on separate
replays if desired, and can require different constructions.

Each level starts with a mission briefing and may introduce mechanics
through a one-time Ponder tutorial. Main objectives are always to power
the required presses at their target spin and relative speed without a jam.
Some pilot puzzles intentionally offer more than the exact parts in the
author's reference solution, encouraging alternate engineering approaches.

Progress and awards are stored in three independent save slots. Each stage
retains its own construction snapshot, including placed and removed redstone parts. Existing campaign unlocks are
retained; incompatible old board arrangements reset when the level is opened.

### Campaign reference and validation

Each authored stage has a playable starting state, a separate reference
construction, an explicit stock inventory, optional immovable fixtures,
and zero to two typed optional bonuses. `tests/cogworks_campaign_design_test.lua`
verifies all 64 main reference solutions with the actual kinetic simulator,
variable bonus counts, immovable fixtures, board diversity, and alternate
map routes that bypass optional levels. Main references are **not** expected
to automatically earn bonuses.

The 30 levels derived from earlier proven kinetic layouts are **intentional
first-pass variations, not yet final playtested puzzles**. Their discovery
quality and authored twists should be checked during in-game playtesting
and revised where a familiar solution still works trivially.

### Development mode

Launch with:

```lua
/games/cogworks/main.lua --dev
```

A **DEV: ALL LEVELS** item appears on the title screen. It lets you enter or
jump to **any level**, even if no campaign stages are unlocked. Developer
sessions are temporary and do not write to campaign save slots. Ordinary
saved-game progression retains its normal unlocking rules even when launched
with `--dev`.

To select a particular monitor as well, pass its peripheral name as a second
argument: `/games/cogworks/main.lua --dev monitor_0`.

### Sandbox

Choose **FREE SANDBOX** on the title screen. All ten parts are available in
unlimited quantities, with a selectable 5×5–10×10 board. A generator is pre-installed.
There are no targets, victory conditions, part limits or campaign unlocks.
Build, rotate, switch or remove components freely, and clear the board from
the pause menu. Sandbox sessions do not overwrite campaign saves.

## Blueprint graphics

The CC:Graphics 2 renderer now uses a custom sixteen-color blueprint palette:
navy grid panels, cyan blueprint lines, restrained brass machinery, steel
shafts, and orange redstone/reverse-spin accents. Cogs use small 13-pixel-cell
sprites with **different small/large tooth silhouettes**, clearly marked
meshing contacts and speed-sensitive rotating spokes. Shafts animate their
rotation rather than scrolling dots along the power path.

Each powered tile uses an unobtrusive direction marker. The footer shows
CW/CCW and speed multipliers without obscuring the gear artwork:

- **Cyan CW (>)** indicates clockwise motion.
- **Orange CCW (<)** indicates counter-clockwise motion.
- **1X**, **2X**, and **0.5** indicate speed relative to the source.

The persistent two-color legend and the numeric multiplier remain visible
even if animations are disabled. Cog rim meshing works for perpendicular
adjacent equal-size **and mixed-size** pairs, at the applicable 1:1 or 2:1
speed ratio. Existing diagonal large/small gearing remains supported.

Animation frames are buffered and sent to CC:Graphics as a **single bitmap
upload of the changed region** instead of thousands of peripheral calls.
Cogwheels now display rotating contrasting spokes, an asymmetric rim marker,
stepping teeth and a recessed center; shafts animate their rolling faces
rather than scrolling dots along the shaft. The workshop's **RUN/OFF** header
button toggles animation without navigating to Settings. Attached-monitor
animations target five updates per second.
This aims to resolve attached-monitor stalls, but physical testing is still
required.

The game automatically prefers an attached monitor, including an ordinary
monitor when no color display is connected. It applies **text scale 0.5**
when supported and restores the previous scale when it exits. With no
monitor connected, it falls back to the computer or a scrollable text view.
Graphics pixel scaling is separately fitted to the available pixel dimensions.

## Controls

**Computer / CraftOS-PC mouse:** right-click to place or rotate; left-click
to delete; drag a movable machine or redstone piece to an empty cell.
Dragging does not consume stock or reset orientation.

**Advanced Monitor (tap-only):** tap an empty square to place the selected
part. Tap an existing part to select it; the small top-left arrow rotates,
and the top-right X deletes. A separate REMOVE palette tool remains
available for small screens. Selecting a redstone tool places dust or a
power block in the center of an empty cell.

The sandbox SIZE button cycles from 5×5 through 10×10, resetting the
sandbox layout. Campaign puzzles use their own fixed grid dimensions.

Keyboard: `1`–`9` choose parts, `0` selects redstone block,
`X` selects REMOVE, `S` saves, `P`/`Q` pauses and
`N`/`B` navigates; Escape opens/closes Pause.

### Attached-monitor input diagnostics

If a monitor displays the game but taps do not activate controls, launch with
`--input-debug` (and optionally the monitor side):

```lua
/games/cogworks/main.lua --input-debug top
```

Try a couple of buttons, then quit with `Q`. Inspect
`/games/cogworks/input-debug.log` on the computer. The file records raw
touch/mouse events and their resolved button/cell targets, distinguishing
missing input events from incorrect coordinate mapping.

A monitor resize triggers an entire-surface background clear before the next
batched redraw. This removes stale title text and light strips caused by the
old graphics viewport moving or changing size.

## Regression tests

```sh
lua5.3 tests/cogworks_campaign_design_test.lua
lua5.3 tests/cogworks_test.lua
lua5.3 tests/cogworks_mechanics_test.lua
lua5.3 tests/cogworks_briefing_test.lua
lua5.3 tests/cogworks_tutorials_test.lua
lua5.3 tests/cogworks_storage_test.lua
lua5.3 tests/cogworks_renderer_test.lua
lua5.3 tests/cogworks_main_test.lua
lua5.3 tests/cogworks_installer_test.lua
```

StyLua formatting and Selene linting are enforced alongside the Lua test
suite in the repository's CI workflows. Final monitor layout and touch input
should also be checked in CC:Tweaked.

## Create reference

[Create Cogwheels](https://github.com/Creators-of-Create/Create/wiki/Cogwheel)
and [Generate and Convey](https://github.com/Creators-of-Create/Create/wiki/Generate-and-Convey)
document the shaft, gearbox, chain, belt and redstone interaction rules on
which this compact game is based.
