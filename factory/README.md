# FPBCRAFT Factory Control (Basalt 2.5)

A modular touchscreen controller for CC:Tweaked + Create + Create: Power Grid on Minecraft 1.21.1.

## One-command installation / updates

Run this command on the CC:Tweaked computer:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install.lua
```

Repeat the same command to update. The current installer downloads the modules, updates code **in place without creating backups**, preserves `/fpb-factory/data`, installs Basalt only when needed, and configures automatic startup. It refuses to overwrite unrelated startup scripts.

**Reboot to launch the manager automatically.** You can also run `/fpb-factory/main.lua` immediately. CraftOS must have `shell.allow_startup` enabled; bootable programs on attached disks may take precedence over root startup scripts. Disconnect boot disks when using this dedicated controller.

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
- **Graphs:** responsive paginated multi-graph dashboard, solid-colour PixelGraph plots with labeled axes/ticks and values; tap **Expand** on a tile for a detailed full-screen view.
- **Overview:** small live telemetry graphs next to operational status when the monitor has enough space.
- **Machine details:** production-rate mini graph (using net Stock Ticker changes); select it to open the detailed view.
- **Devices:** automatically discover wired and adjacent peripherals, rename each device, list supported read-only methods, register a sensor or set up a Redstone Relay as a controllable machine.
- **Readings:** browse configured scalar telemetry, set labels/units, enable graphs, set upper/lower warning thresholds, suspend polling, and relink after a device is replaced.
- **Power Grid:** native voltage, current, power, energy, battery and generator clutch peripheral readings.
- **Requests:** history of accepted Create package requests, NOT guaranteed deliveries.
- **Diagnostics:** attached peripherals and exposed methods.
- **Settings:** factory name, Hub address and sample frequency.

A touchscreen keyboard with CLEAR, BACKSPACE, and a separate Done action is included. Keyboard pages are available if the monitor is too small to display all characters simultaneously.

## Add a new sensor without editing Lua

1. Attach the new sensor/entity to the computer using **Wired Modems and Networking Cable**. Right-click its modem so CC:Tweaked attaches the peripheral.
2. Open **Devices** in Factory Manager. The new peripheral appears on the next refresh (or tap **Rescan**), with its CC:Tweaked network name and type.
3. Tap the device and **Rename** it to a friendly name, e.g. `Boiler Room / Battery A`.
4. Tap **Add Reading**. The manager lists recognized, zero-argument read methods from `peripheral.getMethods()`. Select a trustworthy method, for example `getStress`, `voltage`, `getSpeed`, or `getValue`.
5. In **Readings**, choose the new reading and optionally give it a meaningful label, set units, toggle graphing, or add upper/lower warning limits.
6. Go to **Graphs → Change Graph** and select the newly added reading.

No source edits, mod-specific Lua module or reboot is needed for such scalar sensors. The device inventory and configured readings are persisted in `/fpb-factory/data/devices.db` and survive automatic updates. A disconnected sensor stays listed as **offline** instead of disappearing and losing its configuration. If you replace it, open its Reading page and choose **Relink**, which only offers online peripherals of the same declared type exposing the same method.

**Important limitations:**
- This version polls explicitly selected, no-argument getters returning a **number, string or boolean**. Some getters may require an argument or return a table; those show as unavailable and require a dedicated adapter in a future release.
- Read method names starting with `get`, `is`, or `has` are candidates, but the name itself does not guarantee they are side-effect free; choose methods belonging to trustworthy mods. No arbitrary setters or mutating methods run automatically.
- Graphs can use numeric readings only; textual and boolean readings remain visible on their details screen.
- If wired names are reassigned after rebuilding a cable network, use **Relink**. The manager does not silently reassociate peripherals merely because they share a type.
- Up to **48** custom readings are supported, with polling at the configured refresh interval. Very large inventories/expensive getters should use purpose-built adapters, not generic method polling.
- **Alerts** display warning states only; they do **not** issue commands or stop machines. Stock rules remain managed through **Machines** and **Rules**, and machine controls must be explicitly configured.

### Adding a remote Redstone Relay as a machine

The **Devices** page identifies attached `redstone_relay` peripherals. Select one and tap **Register as Machine**. The machine editor starts with the correct relay name. Configure the redstone face, signal polarity, and optionally the Create stock item/stop-resume thresholds. Then use the **Switchboard** to test manual control before enabling Auto. This requires the physical override and safe wiring described below.

## Remote factories / wireless nodes

You can install a small **FPBCRAFT Remote Node** on any distant CC:Tweaked computer. It attaches to local wired peripherals, automatically broadcasts their scalar telemetry over Wireless or Ender Modems, and reconnects after restart.

The Factory Manager requires its own Wireless/Ender Modem. It discovers the broadcasts automatically and lists sensors under **Devices** alongside locally wired peripherals, with persistent friendly names, graph options and warning thresholds. Nodes expire from the live online list after about 22 seconds without an update.

**Remote control is not enabled:** nodes publish read-only telemetry; network commands cannot turn machinery on/off. Rednet messages are not authenticated, so writing to machinery over that channel will need a separate pairing/security mechanism.

[Complete setup and installation instructions](../node/README.md), including the one-command installer for each node.

## Keyboard, autocomplete and clipboard

Every text/numeric field now supports **both** modes without changing the factory application:

- **Touchscreen:** tap the original field to open a keypad. The editor shows tappable matching suggestions; select one to fill the field. Use BACKSPACE, CLEAR, COPY, PASTE, DONE or CANCEL.
- **Physical keyboard:** open the computer's GUI while the keypad is shown on the Advanced Monitor. The computer displays a synchronized Basalt text input. Type as normal, press **Enter** to apply, or paste text using **Ctrl+V** (**⌘V** on macOS when the Minecraft client maps that shortcut). Monitor taps and computer edits share the current field value.
- **Copy/Paste:** COPY and PASTE buttons on both displays operate on an **in-application clipboard**, retained while the Factory Manager runs, across different fields. **This does not read or write the operating system clipboard** from a touch event: CC:Tweaked exposes incoming paste events, not native clipboard contents on monitors. For external clipboard text, focus the computer input and use native paste.

Valid-value suggestions (when the game exposes the necessary data):
- **Relay / computer:** `computer` or online wired Redstone Relay names (excluding unrelated gauges).
- **Side:** `top`, `bottom`, `left`, `right`, `front`, `back`.
- **Output item / rule stock item:** actual item IDs and display names in the connected Stock Ticker; this is not a full registry of every modded item.
- **Inventory search:** current stock display names.
- **Order quantity / rule stock thresholds:** common numeric presets. Resume thresholds are filtered below the configured stop threshold.
- **Hub address:** current setting and previously used destinations; Create does not expose an authoritative list of every valid package destination.

Suggestions never automatically change the saved value: choosing one fills the editor, and **DONE/Enter** commits it. You can always type a custom value.

## Graph axes and readouts

PixelGraph displays each numerical series in a **solid colour**. Graphs now show:
- Labeled **Y-axis** with the actual unit, numeric ticks and scale that includes negative data when necessary
- **X-axis** showing the elapsed time window with start, midpoint and **NOW** tick labels
- **Latest** measured value, plus minimum, average, and maximum values for the visible sample window
- An explicit **NO NUMERIC DATA** message when the selected sensor has not returned measurements

Values are rounded and compacted for readability on Advanced Monitors; the persisted telemetry remains numerical.

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

## Overview charts and production-rate averaging

The Overview now displays compact charts below the status summary on monitors at least 32 characters wide and 27 rows tall. On wider or taller monitors it automatically shows more charts; tap a chart to expand it.

The estimated production rate is now smoothed using an exponential time-weighted average. Its default period is 120 seconds. Adjust per machine under Machines > Edit > Rate Avg Seconds (15 to 900 seconds), or change the default for newly registered machines in Settings > Rate Average. Shorter periods react more quickly, while longer periods reduce batch-delivery spikes. Historical spike-based rate values are excluded from the new chart history.

Rates remain based on net Stock Ticker changes, not exact per-machine production. Consumers and other producers sharing the same item can affect the estimate.

**Wireless-node controls:** Remote nodes are read-only and are therefore not suggested as machine actuators. Machine control currently requires the local computer's redstone outputs or a wired Redstone Relay. Remote nodes may still supply sensor readings and graphs; adding wireless actuation will require a separate trusted control mechanism.

## Graph visibility and quick averaging-range controls

- **Power Grid graphs appear only when an attached Power Grid peripheral returns a finite numeric value.** Gauges without data no longer occupy tiles in the graph dashboard or picker. A valid zero is still displayed as data.
- **Rate averaging can be adjusted directly on each Machine screen or its expanded rate graph.** Presets: **30 seconds, 1 minute, 2 minutes, 5 minutes, 10 minutes**. The selected preset is highlighted and saved to the individual machine. Custom values from 15 to 900 seconds remain configurable via **Machines > Edit > Rate Avg Seconds**.
- This controls the time constant for the existing exponentially smoothed net-stock-gain rate, not the graph's X-axis history range. Changing the rate time constant clears that machine's previous rate graph samples to avoid showing mixed averaging periods; other saved telemetry stays intact.
- The default rate averaging period under **Settings > Rate Average** applies to newly created machines. Existing machines keep their chosen values.


## Optional CC: Graphics and Unicode enhancements

Both mods are optional for this Lua application. **The default Basalt interface remains a normal 16-color text terminal.**

- **CC: Tweaked Unicode Support (NeoForge 1.21.1):** improves client/server handling of UTF-8 input, paste, and rendering. Factory Manager and Remote Node now clip text by Unicode display columns and limit field input without splitting multibyte characters. For names such as `Électricité`, `Chaudière`, or `Andrésite`, this avoids malformed text from byte-based truncation. Some Basalt-internal operations may still need compatibility testing with the mod.
- **CC: Graphics:** exposes `getGraphicsMode`, `setGraphicsMode`, `drawPixels`, and higher-resolution 16-/256-color pixel modes. In **Settings**, the Factory Manager now reports whether the active display exposes this API and its pixel resolution, **without enabling graphics mode**. Graphics mode replaces the visible text terminal rather than overlaying on top of Basalt, so the existing touch UI intentionally stays in text mode.
- **Future graphics-viewer design:** a dedicated full-screen graph view or a second Advanced Monitor driven by a separate graphics renderer. Keep normal buttons, machine controls, and navigation in Basalt; never switch its monitor out of text mode from a background polling callback. Pixel drawing should batch updates and use the supported `drawPixels` API, with a classic graph fallback.
- **Compatibility:** CC: Tweaked Unicode Support requires CC:Tweaked 1.120.2+ and installation on **both client and server**. CC: Graphics supports NeoForge 1.21.1 and requires CC:Tweaked 1.117.0+. Test the combination with the actual modpack versions: its compatibility with every other UI/peripheral mod is not established by these checks.

The glyph-width calculations assume conventional Unicode column widths. Font/rendering differences still require visual verification in game.
