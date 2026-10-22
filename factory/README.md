# FPBCRAFT Factory Control (Basalt 2.5)

A modular touchscreen controller for CC:Tweaked + Create + Create: Power Grid on Minecraft 1.21.1.

## One-command installation / updates

**When this repository is publicly downloadable**, run on the CC:Tweaked computer:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install.lua
```

Repeat the same command to update. The installer:
1. Downloads the core, Basalt UI, and launcher into `/fpb-factory.next`.
2. Installs Basalt 2.5 (minified) alongside the application.
3. Preserves `/fpb-factory/data`, retaining configured machines, graphs, settings, and request history.
4. Backs up the previous installation to `/fpb-factory.backup` before swapping.
5. Creates `/startup.lua` only when that file does not already exist, without disturbing unrelated startup programs.

Then run `/fpb-factory/main.lua` or reboot if the installer created your startup file.

**Important:** The GitHub repository currently is **private**. Anonymous `wget` requests to `raw.githubusercontent.com` will return 404. You must either make the repository public, or publish a public, static distribution of these files and point the installer at that endpoint. The repo does *not* need to be public if you use a separate public distribution host. Don't put a GitHub personal access token in a ComputerCraft command or script.

For a feature branch preview, the installer accepts a Git ref as its first argument. Only use this with a trusted public download endpoint.

## Requirements

- CC:Tweaked + Create 6 (stock ticker, kinetic peripherals).
- Basalt 2.5, installed automatically.
- Advanced Monitor recommended: **3×2 blocks, text scale 0.5**. Minimum UI size: 32×16 characters.
- Wired Modems + Networking Cable to expose remote peripherals.
- Create: Power Grid for optional electrical gauges; the page is empty until gauges are actually attached.
- A configured Create logistics network with a valid receiving address **Hub** for package requests.
- At least one Advanced Computer.

The dashboard finds the first connected monitor by name (sorted alphabetically). Use only one dashboard monitor per computer for now.

## Pages

- **Home:** responsive 2–4 column grid of names.
- **Overview:** kinetic stress, shaft RPM, stock totals, machine count and observed output states.
- **Inventory:** detailed Stock Ticker entries, search, clear filter, sort, pagination, quantity selection, confirmation and request to Hub.
- **Switchboard:** all configured production units with observed redstone output state and direct manual ON/OFF buttons.
- **Machines:** register and edit machines, configure actuator sides and outputs.
- **Rules:** list automation policies and open machine configuration.
- **Graphs:** Basalt PixelGraph, real solid-colour plots of kinetic load, RPM, stock and Power Grid readings.
- **Power Grid:** native voltage, current, power, energy, battery and generator clutch peripheral readings.
- **Requests:** history of accepted Create package requests, NOT guaranteed deliveries.
- **Diagnostics:** attached peripherals and exposed methods.
- **Settings:** factory name, Hub address and sample frequency.

A touchscreen keyboard with CLEAR, BACKSPACE, and a separate Done action is included. Keyboard pages are available if the monitor is too small to display all characters simultaneously.

## Set up the andesite farm

The production unit must be controllable by redstone.

**Option A: adjacent to the computer:** attach a redstone signal on an unused side (e.g. `back`) and register the unit with `device = computer`, `side = back`.

**Option B: distant machine:** use a CC:Tweaked **Redstone Relay** against the control input, then attach a **Wired Modem** to the relay and connect it to the same wired modem cable network as the computer. From Diagnostics, find its name (e.g. `redstone_relay_0`). Register a machine using that exact name and the output side facing the machine's input.

If you currently use a lever, do **not** put an unmodified powered lever in parallel with the computer's output: the lever may override software OFF and the machine may keep running. Wire the lever as a *master enable* and the computer as a separate *permit* signal with an AND gate (or equivalent Create logic). Retain a **physical STOP override**. If the machine uses an inverted power-to-stop Clutch, configure `SIGNAL WHEN RUNNING` to false.

In **Machines → + Add**, enter:
- ID: `andesite`
- Name: `Andesite Farm`
- Device: `redstone_relay_0`
- Side: the relay output face (e.g. `front`)
- Output item: `minecraft:andesite`
- Rule stock item: `minecraft:andesite`
- Stop at: `12000`
- Resume below: `8000`

Initially use **Manual** mode and test the output. Change to **Auto** on the Machine page when ready. Automatic rules only act if the Stock Ticker inventory is available and fresh. Above the upper threshold, the output turns off; below the lower threshold, it turns on; between thresholds it retains the prior commanded state.

For an iron farm, repeat with `minecraft:iron_nugget` and your desired thresholds, e.g. stop at 32000 / resume below 24000.

**Production rate limitation:** v3 reports a **net stock-increase estimate** from successive Stock Ticker snapshots; it does not count items produced at the machine. If items are concurrently consumed or removed, the estimate will undercount. For accurate throughput, use a dedicated metered output buffer or an item-transfer counter and add its reading as a machine-specific adapter in a subsequent version.

## Power Grid

Connect relevant gauges to the wired peripheral network. The script uses these Power Grid peripheral types:
- `powergrid_voltage_gauge` / `voltage()`
- `powergrid_current_gauge` / `current()`
- `powergrid_power_gauge` / `power()`
- `powergrid_energy_meter` / `energy()`
- `powergrid_battery` / `capacity()`, `energy()`, `chargePercentage()`
- `powergrid_generator_clutch` / `load()`, `rpm()`

## Safety and compatibility

- Redstone outputs are **not** safety interlocks. A computer restart, unloaded chunk, network disconnection, or missing relay may cause unexpected actuator states. Use physical emergency stops and fail-safe wiring.
- This version is **single-computer**, not distributed Rednet; remote relays must be on the same wired modem network. Wireless buildings will need a separate controller node in a later release.
- Auto rules do not act on stale/unavailable Stock Ticker readings.
- Machine type and side are configurable; no Andesite Farm names or device IDs are hard-coded.
- The application does not manage chunkloading.
- No API can currently confirm package *delivery* from `requestFiltered()`. The logged status means only that the order was accepted.
- Stop existing `factory.lua` before starting the new controller. Do not run two controllers against the same relay.

## Development

```sh
luac5.3 -p factory/core.lua
luac5.3 -p factory/ui.lua
luac5.3 -p factory/main.lua
luac5.3 -p install.lua
lua5.3 tests/core_test.lua
```

The CI workflow runs syntax checks and mocked core rule tests. Real in-game Basalt and peripheral integration should be validated before using unattended machine control.
