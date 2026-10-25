# COGWORKS: Kinetic Lab

> **Campaign redesign (proposal):** [Discovery-Driven 64-Level Campaign Design](CAMPAIGN_DESIGN.md)
> specifies all 64 hand-authored puzzle concepts, branching chapters, remixes,
> varied bonuses, fixed machinery and the editor/pack acceptance criteria.
> The currently generated 64-level layouts are **implementation placeholders**;
> this document does not describe already playable replacement levels.

A touchscreen-first construction puzzle for CC:Tweaked, based on the rotational
transmission mechanics in the Minecraft [Create mod](https://github.com/Creators-of-Create/Create/wiki).

The previous 30-stage campaign and its fictitious elbow, splitter, inline-speed
drive and inline-reversing gear have been **removed entirely**. The new
**16-stage campaign** introduces the actual principles of shaft axes, side-meshing
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
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/cogworks-v03-craftos/installers/cogworks.lua feat/cogworks-create-kinetics-sandbox
/games/cogworks/main.lua --dev
```

The installer preserves saves and settings. The new campaign uses version-4
save data and resets old puzzle sessions/unlocks, because the old solutions are
mechanically incompatible. Previous save files remain on disk; they are not
deleted. Display options are preserved.

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

Sixteen new levels, from 5×5 to 10×10, progress from straight powerlines and gearbox reversals
through perpendicular cog teeth, chain drives, clutches/gearshifts, 2:1 gearing,
belts and branching networks. Each level starts with a mission briefing;
a one-time Ponder explains newly introduced parts. Complete all required
presses at their requested relative speed and rotation without jamming
the mechanism. Optional bonus challenges do not block advancement.

Progress and awards are stored in three independent save slots. Each stage
retains its own construction snapshot, including placed and removed redstone parts. Existing campaign unlocks are
retained; incompatible old board arrangements reset when the level is opened.

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
