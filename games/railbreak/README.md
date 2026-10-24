# RAILBREAK: Kinetic Frontier — Train-first Edition v2

A **turn-based Create-inspired railway adventure** for **1–4 local players** on one ComputerCraft Advanced Monitor. Designed for 5×5, responsive down to **3×3**, with 4×3, 4×4, 4×5 and 5×4 sizes supported. Graphics mode provides pixel-art train, wagons, scenery, track map and machine icons; ordinary CC:Tweaked colour text is a fallback.

## Install / update

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/railbreak.lua
/games/railbreak/main.lua
```

For a specific attached screen: `/games/railbreak/main.lua monitor_0`. Without an argument, the game chooses the largest attached monitor. The installer stages downloads, validates Lua syntax, makes rollback backups, and never touches game saves. Use `--startup` only on a dedicated computer; existing startup programs are not overwritten.

The original **factory-first RAILBREAK v1** remains playable: `/games/railbreak/classic.lua`. Its existing save `/games/railbreak/data/save.lua` is preserved. **The new train-first game uses a separate save** at `/games/railbreak/data/train-save.lua`; v1 saves cannot be loaded into v2. On the title screen, CONTINUE loads the v2 save, including an unresolved travel event.

## How to play

1. Start an expedition, choose Explorer / Standard / Frontier, and optionally name 1–4 participants with the on-screen keyboard.
2. Your train is the main hub. Tap a wagon to select it and see its bonus directly on the train screen; use **?** for more detail or **LV UP** for the upgrade confirmation, or buy additional cargo/passenger/fuel/crane wagons. Upgrades are accessed through **TRAIN → TECH**.
3. Visit the station to buy/sell goods, repair/refuel, upgrade its simple Create-inspired production modules, or run **a production shift**. Modules are not freeform factory grids; each converts goods to other goods in one turn.
4. Pick a railway connection on the **MAP**. Building an untravelled connection requires parts; travel consumes fuel. The train advances **only when you tap Depart**.
5. Some departures trigger an event, e.g. rockslide or broken bridge. Read the consequences and choose an option. There are **no real-time countdowns**.
6. Accept jobs on the **JOBS** board while at their origin station, carry the requested goods to the specified destination, and tap DELIVER. Up to 3 simultaneous contracts can be active.
7. Complete **2 contracts** and earn **2 reputation**, then reach **EASTPORT** to win the expedition. A trip to Eastport before meeting these goals does not finish the run.

### Resources and progression

The train has coins, fuel, hull condition, reputation, and finite wagon cargo slots. Larger wagons add capacity. Upgrades change real rules: an efficient burner uses less fuel on long routes, an auto loader adds cargo space, a signal relay improves event outcomes, and armour raises hull capacity. Stations have 4 module slots, each supporting up to 3 levels. Production, travel, and recovery jobs consume turns rather than real time.

**Soft-lock prevention:** Every station sells refuelling, repairs, parts, and raw ingredients. A station's local repair job earns 12 coins per turn if you're short of money. Event choices always have a fallback that can be taken without scarce goods. The game is fully playable solo; the same rules apply with 2–4 players, who share the train, goals, inventory and actions. Tap the P1/P2 indicator on the title bar to switch credited crew member; this is a social feature, not touchscreen identity detection.

### Touchscreen / monitor behaviour

With CC: Graphics, `monitor_touch` events are **zero-based pixel coordinates**; without it, events use **one-based character cells**. The game sets the monitor text scale to **0.5** before initializing graphics. CC: Graphics uses a higher-density virtual canvas (3× text columns by 4× text rows), rendered at 2×2.25 real pixels per virtual pixel. This fits more readable text and content without shrinking the physical touchable area of the monitor. The native text fallback retains its previous 2×3 virtual canvas. Both use normalized touch coordinates. Controls are click targets in those same virtual coordinates. All six layouts and both modes are exercised in the offline test harness. Actual in-game performance has not yet been validated.

## Tests

Run from the repository root with Lua 5.3+:

```sh
lua games/railbreak/tests/scale.lua       # prove monitor scale 0.5 is applied and restored
lua games/railbreak/tests/boot.lua        # CraftOS-style boot/module lookup regression
lua games/railbreak/tests/train.lua       # train engine, campaign and responsive UI
lua games/railbreak/tests/run.lua         # preserved factory-first edition regressions
lua games/railbreak/tests/installer.lua   # rollback and non-destructive update behaviour
```

All artwork is procedural using CC: Graphics pixel primitives; no resource pack or extra peripherals are required. The game is a simulation *in* ComputerCraft and does not control your real Create infrastructure.

## Startup and screen reliability (v2.0.3)

The v2.0.3 railway map uses the rules engine for route fuel costs, and normal labels use a compact 3×5 pixel font in CC: Graphics mode (headings remain larger). The text-mode fallback uses the native character font.

The train edition imports modules relative to `/games/railbreak/` (`train.ui`, `train.rules`, `core.util`). The updater performs a CraftOS boot check **and renders key screens using a mock monitor** after installing; any failure triggers rollback to the prior files without modifying saved games. A stale cached installer can be bypassed by using the installation command with a pinned commit SHA for both installer and files.

## Display-density update v2.0.4

Advanced Monitors are explicitly set to **text scale 0.5**. In graphics mode, the
renderer uses more of the available CC: Graphics pixels instead of upscaling
text and controls by 3×. Layout mode is selected using monitor text-cell
dimensions, so 3×3 and 4×3 displays still receive the compact interface.
All six supported sizes are covered by graphics/text input and resize tests.

## Context help and confirmations (v2.0.5)

Tap **?** in the header of a screen for a short explanation of what to do. Tap the resource icons in the top strip to learn about coins, locomotive fuel, hull condition and reputation. Tapping a market item, station module, contract, route, wagon, or global upgrade opens its **details view**. This view describes the real gameplay effect, current inventory or level, exact costs, and any requirements. Use **BACK** to return without changes or the highlighted action button to confirm. Longer descriptions have **PREV / NEXT** pages even on 3×3 monitors. Travel event options also show their consequences before confirmation, without any time limit.

The Steam Whistle is correctly described as adding **2 shared cargo slots** (not a separate passenger-only capacity). Locomotive level upgrades now add **4 maximum fuel and 4 fuel**; crane level upgrades add **2 cargo slots**. Existing v2 saves are upgraded once for any previously purchased locomotive levels, without overwriting saves. No gameplay time passes while inspecting information.

## Inline gameplay summaries (v2.0.6)

Common information is now visible **without opening a separate help page**:
- **Tech cards:** specific upgrade effect, cost, and installed status.
- **Station modules:** input-to-output recipe, current level and next-level price.
- **Wagon list and train composition:** cargo, fuel, and special wagon benefits; touching a wagon selects it first.
- **Market:** current stock, buy/sell price and a short use description.
- **Contracts:** required cargo, current stock, reward, reputation and accepted/completed status.
- **Route map:** fuel and parts required compared with available supplies.
- **Travel events and station services:** costs and consequences shown beside choices.

Use a card or the **?** button to read the full explanation. Spending still requires a separate confirmation; displaying summaries never consumes turns or resources. Small monitors retain the same effects using compact layouts.
## Play without an external monitor

The game also runs on the computer's **built-in terminal**. Launch normally without connecting a monitor; the game automatically switches to its text-mode computer viewport. The built-in screen is smaller than the game canvas, so **arrow keys pan**, the **mouse wheel scrolls vertically**, and **left-click selects** controls or board cells. A footer shows the visible viewport position. Attaching an Advanced Monitor still uses the usual full-screen UI and touch controls.

## Emulator and unusual monitor aspect ratios

On iPad/CraftOS emulators and unusually wide or tall monitors, CC: Graphics now **preserves pixel aspect ratio** and centers the game in a dark letterboxed viewport instead of stretching its lettering. Touch coordinates account for the margins. On a small computer without an attached monitor, the virtual text-mode terminal fallback still applies.

## Native CraftOS-PC / iOS graphics

Without an attached monitor, the game now checks the **real computer terminal**
for CraftOS-PC mode-2 graphics (`setGraphicsMode`, `drawPixels`) before
creating any text-only virtual viewport. Native graphics use the emulator's
pixel dimensions and pixel-coordinate mouse events. Attached monitors retain
priority; ordinary CC:Tweaked computers without pixel graphics still use the
scrollable text fallback. The graphics renderer restores text mode on exit.

The game keeps its custom graphics. FPB Store uses a portable terminal launcher
and does not require Basalt.
