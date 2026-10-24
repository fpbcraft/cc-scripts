# COGWORKS: Kinetic Lab

A **30-level**, touchscreen-first construction puzzle for **CC:Tweaked**, inspired by Create's mechanical engineering. Place shafts and machinery, join the ports, and meet each machine's required **clockwise/counterclockwise spin and RPM**. This is a standalone game: it does not control any real Create machinery.

## Install / update

Run on your Advanced Computer, with CC:Tweaked HTTP enabled:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-cogworks.lua
/cogworks/main.lua
```

The installer safely stages code updates and preserves game saves in `/cogworks/saves/`, `/cogworks/settings.dat`, and the legacy `/cogworks/save.dat`. Add `--startup` to the installer to create autostart *only when no unrelated startup script exists*. Test a branch by running its raw installer with its branch name as the final argument.

## Menu & save systems

The new **Title Menu** lets you Continue your last save, choose one of **three slots**, open Settings or Exit. Empty slots start a fresh campaign. Your previous pre-slot save automatically imports into slot 1 when selected, without deleting the original file.

The **Pause Menu** offers Resume, Save Game, Select Level (from your unlocked stages), Settings, Help, Restart Level, New Campaign and Title Menu. Restart and New Campaign require confirmation; New Campaign overwrites the current slot. Settings persist independently from save slots, currently controlling animation and open-port markers. Game boards and achievements autosave on every change; you can also save manually. Press `P` or Escape at the computer to pause and leave safely.

### Gameplay controls

- Tap a part in the compact two-column inventory, then tap an empty board cell to **place** it.
- Tap a placed part to **rotate** it clockwise 90 degrees. Tap a fixed machine to inspect its needed **CW / CCW** and the current spin. Tap **REMOVE** to reclaim parts.
- Select **SWITCH**, then tap a **clutch** to engage/disengage it. Switch mode is different from rotating a part.
- **Hint has been removed.** You can solve using as little or as much stock as necessary.
- Keyboard: `1`–`9`, `0` choose the 10 part types; `X` removes, `T` selects clutch switch, `S` saves, `P` or `Q` pauses, `N` next, `B` back. Ctrl+T exits safely and saves.

**Rotation clarity:** The green engine always generates **CW / 1×** power. Presses display **CW** or **CCW** on their face with their RPM underneath. Tapping a press displays what it **needs** and what it's **currently receiving**. A **gear** reverses CW ↔ CCW; a **large cog** reverses direction **and** doubles RPM. RPM and direction are independent of the physical orientation of the port.

### Ten available parts

| Icon | Part | Mechanical behavior |
|---|---|---|
| I | Shaft | Straight two-port transmission |
| L | Elbow | Turns a connection through 90° |
| T | Splitter | Three connected ports |
| G | Gear | Reverses spin (1:1 RPM) |
| B / 2 | Speed Drive | Doubles RPM from marked input to output; reverse flow halves |
| C | Clutch | Straight shaft you can engage or disengage using SWITCH |
| Q | Gearbox | Distributes power to four directions; unused outlets are capped |
| O | Large Cog | Reverses spin and doubles RPM across the input/output; reverse flow halves |
| V | Belt | Two aligned endpoints can transmit across **up to two** empty/stone cells |
| D | Chain Drive | Two aligned endpoints transmit across **up to three** empty/stone cells |

The game provides actual gap-spanning belt and chain puzzles in later levels (e.g. levels 6 and 23). The later stages also introduce the other parts, while the tutorials stay simple.

### Optional challenges are always visible

The primary win condition is **power every target with the required RPM and CW/CCW rotation without a jam**. It unlocks the next level immediately. Extra objectives appear on the gameplay sidebar, without any separate bonus menu:

- **Sealed Lines** (from level 2): no open ports or unpowered parts.
- **Full Factory** (from level 3): place/use all stock and power/fully connect every piece.
- **Precision** (from level 5): complete in the listed move budget.

Earned bonuses remain unlocked when you revisit a stage. They never block normal progression.

## Visual requirements and input options

- A color Advanced Computer and a color Advanced Monitor (a 3×3+ display recommended).
- **CC: Graphics** is recommended for animated pixel graphics, compact menus, and machine sprites; without it the game remains playable using a sufficiently large Advanced Monitor in text mode.
- The program explicitly sets the monitor text scale to `0.5` and restores the previous setting upon exit. The mode-2 renderer now uses a denser **200×120** virtual layout (rather than 128×88), and completely clears the framebuffer to avoid white margins.
- Standard CC:Tweaked monitor events support right-click only, without button information: right-click builds/rotates, and the REMOVE tool takes parts back.
- **Optional companion addon:** The experimental [FPB Monitor Input](../monitor-input-neoforge/README.md) NeoForge mod (tracked in PR #13) emits normalized `monitor_left_click` events. Once COGWORKS sees a left-click, it uses **left-click to place/rotate and right-click to remove directly**, while retaining the standard fallback. The addon must be installed on *client and server* and has not yet been validated for general deployment.

## Tests

```bash
lua5.3 tests/cogworks_test.lua
lua5.3 tests/cogworks_mechanics_test.lua
lua5.3 tests/cogworks_storage_test.lua
lua5.3 tests/cogworks_renderer_test.lua
lua5.3 tests/cogworks_main_test.lua
lua5.3 tests/cogworks_installer_test.lua
```

The automated suite validates all 30 reference solutions, bonus achievements, real mechanical interactions, saves and settings, menus and hitboxes, monitor scaling, and safe updates. These tests do not substitute for final in-world UI testing.

## Play without an external monitor

The game also runs on the computer's **built-in terminal**. Launch normally without connecting a monitor; the game automatically switches to its text-mode computer viewport. The built-in screen is smaller than the game canvas, so **arrow keys pan**, the **mouse wheel scrolls vertically**, and **left-click selects** controls or board cells. A footer shows the visible viewport position. Attaching an Advanced Monitor still uses the usual full-screen UI and touch controls.
