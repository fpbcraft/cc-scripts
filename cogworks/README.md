# COGWORKS: Kinetic Lab

A small, touchscreen-first kinetic routing puzzle inspired by **Create**. No Create blocks, peripherals, wireless networking, or external scripts are needed to play.

**The objective:** rotate the preplaced shaft, elbow and gearbox tiles until all machines are supplied with the RPM and direction shown on them. Solved shafts glow amber and show animated moving power. The complete game includes ten hand-authored puzzles, progressively introducing branch lines, rotation reversal, and speed doubling.

## Install and update

On a CC:Tweaked Advanced Computer with HTTP enabled:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-cogworks.lua
```

Then run:

```lua
/cogworks/main.lua
```

Pass `--startup` to the installer to automatically start on a **dedicated** computer if no other startup program exists. To test a branch before merging, pass a branch name to the installer: `wget run <installer-url> feat/cogworks-kinetic-puzzles` (after the installer exists on `main`; until then, use the branch URL itself). Updates preserve `/cogworks/save.dat`, validate every Lua download before activation, and roll back if installation fails.

## Requirements

- Minecraft 1.21.1 CC:Tweaked, a color Advanced Computer, and a color Advanced Monitor (3x3 blocks or larger recommended).
- **Recommended:** [CC: Graphics](https://modrinth.com/mod/cc-graphics) for pixel-mode animation and a nicer full-color UI. It must be installed for the game to switch to graphics mode (CC:Tweaked 1.117.0+).
- Without CC: Graphics, the game stays **fully playable** using a character-grid view on a suitably large Advanced Monitor.
- Automatically picks the largest color monitor. Optionally specify its network/peripheral name: `/cogworks/main.lua monitor_1`.

## Controls

Tap a movable tile to rotate it clockwise 90 degrees. Blue machines and the green input source cannot rotate. The four sidebar buttons are **HINT** (fixes one tile's rotation), **RESET**, **PREV** and **NEXT**. Next is available after the current level has been solved. Progress and best move counts persist.

Keyboard (at the computer): `H` hint, `R` reset, `P` previous level, `N` next level, `Q` quit. Ctrl+T also exits safely.

## Kinetic rules

- Shafts (I), elbows (L) and tees (T) transmit their incoming RPM and rotation direction through every connected side.
- A **gear reverser (G)** changes clockwise to counterclockwise (and vice versa).
- A **2x speed controller (2/B)** doubles RPM from its arrow-marked input port to output; going backward halves RPM.
- Parts only connect where the ports of **both** neighboring tiles touch.
- Each machine displays its required speed and direction, e.g. `+2` means clockwise at 2x RPM, `-1` means counterclockwise at 1x.
- Inconsistent rotation or speed constraints in a connected loop cause a **jam**. You must satisfy **every** machine without a jam to complete a puzzle.

## Developer test

```sh
lua5.3 tests/cogworks_test.lua
```

The simulation is standalone Lua; graphics and CraftOS peripherals are only used by the UI. No game progress can alter physical Create machinery.
