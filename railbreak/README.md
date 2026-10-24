# RAILBREAK: Kinetic Frontier — Train-first Edition v2

A **turn-based Create-inspired railway adventure** for **1–4 local players** on one ComputerCraft Advanced Monitor. Designed for 5×5, responsive down to **3×3**, with 4×3, 4×4, 4×5 and 5×4 sizes supported. Graphics mode provides pixel-art train, wagons, scenery, track map and machine icons; ordinary CC:Tweaked colour text is a fallback.

## Install / update

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-railbreak.lua
/railbreak/main.lua
```

For a specific attached screen: `/railbreak/main.lua monitor_0`. Without an argument, the game chooses the largest attached monitor. The installer stages downloads, validates Lua syntax, makes rollback backups, and never touches game saves. Use `--startup` only on a dedicated computer; existing startup programs are not overwritten.

The original **factory-first RAILBREAK v1** remains playable: `/railbreak/classic.lua`. Its existing save `/railbreak/data/save.lua` is preserved. **The new train-first game uses a separate save** at `/railbreak/data/train-save.lua`; v1 saves cannot be loaded into v2. On the title screen, CONTINUE loads the v2 save, including an unresolved travel event.

## How to play

1. Start an expedition, choose Explorer / Standard / Frontier, and optionally name 1–4 participants with the on-screen keyboard.
2. Your train is the main hub. Tap a wagon to inspect and level it up, or buy additional cargo/passenger/fuel/crane wagons. Upgrades are accessed through **TRAIN → TECH**.
3. Visit the station to buy/sell goods, repair/refuel, upgrade its simple Create-inspired production modules, or run **a production shift**. Modules are not freeform factory grids; each converts goods to other goods in one turn.
4. Pick a railway connection on the **MAP**. Building an untravelled connection requires parts; travel consumes fuel. The train advances **only when you tap Depart**.
5. Some departures trigger an event, e.g. rockslide or broken bridge. Read the consequences and choose an option. There are **no real-time countdowns**.
6. Accept jobs on the **JOBS** board while at their origin station, carry the requested goods to the specified destination, and tap DELIVER. Up to 3 simultaneous contracts can be active.
7. Complete **2 contracts** and earn **2 reputation**, then reach **EASTPORT** to win the expedition. A trip to Eastport before meeting these goals does not finish the run.

### Resources and progression

The train has coins, fuel, hull condition, reputation, and finite wagon cargo slots. Larger wagons add capacity. Upgrades change real rules: an efficient burner uses less fuel on long routes, an auto loader adds cargo space, a signal relay improves event outcomes, and armour raises hull capacity. Stations have 4 module slots, each supporting up to 3 levels. Production, travel, and recovery jobs consume turns rather than real time.

**Soft-lock prevention:** Every station sells refuelling, repairs, parts, and raw ingredients. A station's local repair job earns 12 coins per turn if you're short of money. Event choices always have a fallback that can be taken without scarce goods. The game is fully playable solo; the same rules apply with 2–4 players, who share the train, goals, inventory and actions. Tap the P1/P2 indicator on the title bar to switch credited crew member; this is a social feature, not touchscreen identity detection.

### Touchscreen / monitor behaviour

With CC: Graphics, `monitor_touch` events are **zero-based pixel coordinates**; without it, events use **one-based character cells**. The renderer normalizes both into a virtual pixel canvas sized at twice the terminal text width and three times its text height. Controls are click targets in those same virtual coordinates. All six layouts and both modes are exercised in the offline test harness. Actual in-game performance has not yet been validated.

## Tests

Run from the repository root with Lua 5.3+:

```sh
lua railbreak/tests/boot.lua        # CraftOS-style boot/module lookup regression
lua railbreak/tests/train.lua       # train engine, campaign and responsive UI
lua railbreak/tests/run.lua         # preserved factory-first edition regressions
lua railbreak/tests/installer.lua   # rollback and non-destructive update behaviour
```

All artwork is procedural using CC: Graphics pixel primitives; no resource pack or extra peripherals are required. The game is a simulation *in* ComputerCraft and does not control your real Create infrastructure.
