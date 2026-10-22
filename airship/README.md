# FPBCRAFT Skyways — Airship Navigation

Touchscreen airship autopilot for CC:Tweaked, Create: Avionics and the CCC Redstone Link Bridge on Minecraft 1.21.1. **Basalt 2.5** replaces the old text-only cockpit UI. The 10 Hz flight controller, its independent timers, routes, calibration, braking, and separate Display Link output remain intact.

## One-command installation

On a **dedicated** Advanced Computer attached to the ship:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-airship.lua
```

The installer downloads `airship/autopilot.lua`, `airship/ui.lua`, and Basalt 2.5 (minified) to `/fpb-airship`. It stages the download, saves the old install to `/fpb-airship.backup`, and migrates waypoint/preset/calibration data from an older `/autopilot.lua` installation (or your existing `/fpb-airship` directory). It backs up an existing `/startup` or `/startup.lua` and configures `/startup.lua` to launch the new application automatically.

The computer is intended to run the **airship only**; don't install over an existing factory control computer's startup unintentionally. To keep your own startup program:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-airship.lua main --no-startup
```

Rerun either command to update. A development branch can be substituted for `main` **when it is publicly accessible**. Run immediately with:

```sh
/fpb-airship/autopilot.lua
```

The installer requires CC HTTP access (`http` enabled). Automatic startup requires `shell.allow_startup=true` and no boot disk overriding root startup.

## Hardware

- Advanced Computer and optional Advanced Monitor (largest connected monitor automatically selected).
- Monitor text scale `0.5`, at least **32×16** characters. A **3×2 or larger** monitor is recommended to show more controls and labels.
- Create: Avionics Navigation Table, CCC Redstone Link Bridge, and wired modem connections (or peripherals visible on the CC network).
- The same steering and throttle receiver frequencies as the existing autopilot.
- Optional Create Display Links refresh independently; their output does not require a second computer.
- Optional engine automation uses the `aeronautics:white_envelope` / `aeronautics:white_envelope` link and an **inverted LAC receiver**. Only turn on Engine Auto after testing the receiver's direction and manual override wiring.

Keep a **physical emergency propulsion cutoff**. Redstone Link commands are not safety interlocks.

## Cockpit controls

- **Flight**: current X/Z, destination, heading error, speed, forward/reverse/steering telemetry; **STOP NOW** is always prominent.
- **Fly to X/Z**: touchscreen coordinate editor (X, Z and optional name), with page-based numeric/name keyboard. Y is read-only and does not control altitude.
- **Map target**: use the current Avionics Navigation Table marker (not Xaero integration).
- **Route**: select a waypoint, resume the last *next* stop, fly from the selected stop, reorder, add, edit or delete.
- **Presets**: fly to a named preset, add it to a route, or **SAVE HERE** to capture the present ship X/Z as a named preset automatically.
- **Settings**: bow +90°, flip 180°, invert steering, auto-map, engine auto and bow calibration.
- **Diagnostics**: timer heartbeat, last stage, peripheral names, controller errors and Display Link status.

On startup the monitor shows an animated airship before opening the dashboard. Animation runs on Basalt's UI scheduler, **not** on the flight-control loop.

### Data and updates

The controller keeps using its original `.airship_avionics_route`, `.airship_avionics_presets`, and `.airship_avionics_burners_settings` files beside the application. Updates preserve these files. The installer deliberately doesn't overwrite a running factory installation in `/fpb-factory`.

## Testing

```sh
luac5.3 -p airship/autopilot.lua
luac5.3 -p airship/ui.lua
luac5.3 -p install-airship.lua
lua5.3 tests/airship_ui_test.lua
```

The UI test uses a mocked Basalt screen and peripheral-free navigation facade. Actual CC/Basalt, steering, and moving-ship control still require in-game validation before unattended navigation.
