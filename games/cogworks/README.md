# COGWORKS: Kinetic Lab

The **version-7 campaign** contains 64 authored starting boards across eight
branching factory districts. Puzzles offer credible inventory choices, 62
certified alternative clears and 66 independent optional redesign challenges.
See the [designer guide](CAMPAIGN_DESIGN.md) for the level insights, reproducible
solutions and human-playtesting boundaries (contains spoilers).

A touchscreen-first construction puzzle for CC:Tweaked, based on the rotational
transmission mechanics in the Minecraft [Create mod](https://github.com/Creators-of-Create/Create/wiki).

The **64-stage, eight-chapter campaign** explores shaft axes, side-meshing
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
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/codex/cogworks-puzzle-redesign/installers/cogworks.lua codex/cogworks-puzzle-redesign
/games/cogworks/main.lua --dev
```

The installer preserves saves and settings. Campaign version **7** starts older
campaigns fresh, permanently archiving each old slot before replacement. For
example, version-6 data is retained as `slot-N.dat.campaign-v6`. A failed archive
prevents overwriting the slot. Display settings and user-authored packs remain
unchanged.

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

The gameplay layout now sizes the board as a **square, height-constrained
workspace** instead of a fixed percentage of window width. It removes
the redundant board heading, oversized margins and persistent rotation
legend, giving the board nearly all available vertical space. Any
remaining horizontal room goes to the component sidebar; the only footer
is a compact contextual message.

High-resolution parts are redrawn as Create-inspired mechanical sprites:
wood-and-brass small and large cogwheels with distinct teeth and spokes,
andesite shafts and gearboxes, pulley wheels and traveling belt/chain
links, enclosed clutch and gearshift controls, metal-framed motors and
presses, and redstone signal paths. Clock-based animation phases make
rotation direction and speed visible independently of frame rate.
Native CraftOS graphics refresh at approximately 12 frames per second,
while attached monitors run at a lower rate to reduce peripheral traffic.
On smaller displays the existing simplified glyphs remain supported.

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
Every puzzle has explicit stock with alternatives beyond the normal reference
construction. Extra parts are available for different engineering approaches.

Progress and awards are stored in three independent save slots. Each stage
retains its own construction snapshot, including placed and removed redstone parts. Incompatible campaigns restart from the first district after their previous
slot bytes are archived.

### Optional objectives and validation

Bonuses require different constructions: tighter part-family budgets, an
alternative route around a marked cell, useful installed mounts, or a belt,
chain or diagonal transmission that a press actually depends on. Decorative
powered branches do not count. Move budgets and full-stock requirements are
not part of this campaign. Bonuses can be earned independently across replays.

Graphics outlines and text-mode A/B marks identify objective cells. The sidebar
shows live counters; tap an objective to read its full rule in the status line.
The larger graphics layout also displays rules below their labels.

Each level has a normal reference, an independent alternate (after the two
opening lessons), and a legal failed-approach example. Every bonus has its own
winning witness. Tests verify that normal reference builds do not automatically
earn bonuses, including while they are being constructed. The campaign ships
135 winning witness builds and 64 failed attempts checked by the simulator.
Human discovery quality, blind-playtest difficulty and real Minecraft monitor
behavior require separate validation.

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
