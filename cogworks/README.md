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
- **Hint has been removed.** You can solve using as little or as much stock as necessary.
- Keyboard: `1`–`9`, `0` choose the 10 part types; `X` removes, `S` saves, `P` or `Q` pauses, `N` next, `B` back. Ctrl+T exits safely and saves.

**Rotation clarity:** The green engine always generates **CW / 1×** power. Presses display **CW** or **CCW** on their face with their RPM underneath. Tapping a press displays what it **needs** and what it's **currently receiving**. A **gear** reverses CW ↔ CCW; a **large cog** reverses direction **and** doubles RPM. RPM and direction are independent of the physical orientation of the port.

### Nine available parts

| Icon | Part | Mechanical behavior |
|---|---|---|
| I | Shaft | Straight two-port transmission |
| L | Elbow | Turns a connection through 90° |
| T | Splitter | Three connected ports |
| G | Gear | Reverses spin (1:1 RPM) |
| B / 2 | Speed Drive | Doubles RPM from marked input to output; reverse flow halves |
| Q | Gearbox | Distributes power to four directions; unused outlets are capped |
| O | Large Cog | Reverses spin and doubles RPM across the input/output; reverse flow halves |
| V | Belt | Two aligned endpoints can transmit across **up to two** empty/stone cells |
| D | Chain Drive | Two aligned endpoints transmit across **up to three** empty/stone cells |

Belt and chain endpoints visibly connect across empty or stone cells, including the gap on level 6 and the longer span on level 23. A moving highlight indicates live power flow. Open ports can be highlighted separately in Settings.

Clutches have been removed because the authored puzzles only used them as ordinary shafts. **Existing saved clutch placements automatically migrate to shafts** when loading, preserving saved level progress.

### Mechanic lessons (Ponder)

When a level first introduces a mechanic, a **Ponder** overlay appears with a short explanation and animated mechanism diagram. Use **NEXT / GOT IT** to read the slides or **SKIP** to dismiss. Lessons are saved per campaign slot, so returning to an already-introduced level does not repeat them, even after restarting the computer. Use the **?** help screen and **REPLAY PONDER** to view the current level's lesson again.

Introductions include shafts (1), elbows (2), splitters (4), belts (6), gears (8), speed drives and gearboxes (9), large cogs (16), and chains (23). Ponder is available in both pixel graphics mode and the text fallback.

A persistent strip below the board explains the selected construction part, including speed/spin and transmission range. A separate status line reports jams, current press requirements and level progress. Bonus goal spacing has been adjusted to avoid text collisions.

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
lua5.3 tests/cogworks_tutorials_test.lua
lua5.3 tests/cogworks_storage_test.lua
lua5.3 tests/cogworks_renderer_test.lua
lua5.3 tests/cogworks_main_test.lua
lua5.3 tests/cogworks_installer_test.lua
```

The automated suite validates all 30 reference solutions, bonus achievements, real mechanical interactions, saves and settings, menus and hitboxes, monitor scaling, and safe updates. These tests do not substitute for final in-world UI testing.

## Play without an external monitor

The game also runs on the computer's **built-in terminal**. Launch normally without connecting a monitor; the game automatically switches to its text-mode computer viewport. The built-in screen is smaller than the game canvas, so **arrow keys pan**, the **mouse wheel scrolls vertically**, and **left-click selects** controls or board cells. A footer shows the visible viewport position. Attaching an Advanced Monitor still uses the usual full-screen UI and touch controls.

## Native CraftOS-PC / iOS graphics

Without an attached monitor, the game now checks the **real computer terminal**
for CraftOS-PC mode-2 graphics (`setGraphicsMode`, `drawPixels`) before
creating any text-only virtual viewport. Native graphics use the emulator's
pixel dimensions and pixel-coordinate mouse events. Attached monitors retain
priority; ordinary CC:Tweaked computers without pixel graphics still use the
scrollable text fallback. The graphics renderer restores text mode on exit.

The existing custom game graphics remain independent of Basalt. Basalt is
currently optional for FPB Store's terminal UI; a full game-screen migration is
a separate follow-up rather than a dependency of this native-graphics update.
