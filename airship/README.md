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
- **Fly to X/Z**: touchscreen coordinate editor (X, Z and optional name), with page-based numeric/name keyboard. **Physical keyboard typing and Ctrl+V paste also work**: on a connected monitor, enter or paste values into the computer's native Basalt input fields while the monitor continues showing the touch keypad. Pasting `120 -340` into X populates both X and Z. Direct X/Z destinations ignore Y; recorded route stops can store Y and lift signal strengths, described below.
- **Map target**: use the current Avionics Navigation Table marker (not Xaero integration).
- **Route**: select a waypoint, resume the last *next* stop, fly from the selected stop, reorder, add, edit or delete. **Loop Route** toggles a repeating circuit; after the last stop the ship automatically targets the first stop. The loop preference and next waypoint are saved. One-waypoint routes still finish normally.
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

## Route planner: recorded flights, stations, lift and waiting

Select **ROUTE → LIBRARY** to create, rename, duplicate, switch or delete
named routes (up to 32 routes, 100 stops per route). The previously saved
single route is **imported automatically** into an “Original route” on first
launch; the original `.airship_avionics_route` is retained as a fallback snapshot.
Each route remembers its next stop and its own Loop Route setting.

With the ship manually positioned and stable, open **ROUTE → RECORD**.
This captures the Navigation Table's **X/Y/Z**, the calibrated bow heading,
and the **current Redstone Link network levels** for the two lift channels.
The recorded waypoint is added at the end of the active route. Open its
**DETAIL** page to rename via Edit, toggle **STATION**, recapture its present
pose, or set its dwell time, normal/fine burner strengths, orientation, Y,
and docking tolerance. A waypoint's fields are:

| Field | Function |
|---|---|
| X / Z | Horizontal destination |
| Y | Recorded altitude; only enforced as a condition at station stops |
| Heading | Recorded desired bow heading; checked before timed stops and stations |
| Normal / Fine | Redstone Link strength 0–15, applied when *approaching* that waypoint |
| Wait | Seconds (0–86,400) held after confirmed arrival |
| Station | Use precise docking instead of the 20-block fly-through radius |
| Station radius | Configurable 0.5–10 blocks, default 1.5 |

**Altitude is NOT yet closed-loop controlled.** Normal and fine are direct
*output signal values*, not a commanded height in blocks; the controller
cannot guarantee that Y will be reached. If a station has recorded Y, the
ship must be within **1.5 blocks vertically** before its dwell timer begins.
It must also be within the chosen horizontal radius, slower than 0.3
blocks/s, and within 5 degrees of the recorded bow heading for a full
second. A normal unrecorded fly-through still uses the previous behavior.
When waiting, horizontal thrust and steering are zero; lift signals are
**retained** so the ship does not suddenly fall. If the ship drifts out of
tolerance, the timer restarts when stable again. Physical docking still needs
in-game tuning; this isn't a collision or obstruction sensor.

**Capturing lift signal levels:** the CCC Redstone Link Bridge API reports
*the overall network strength*. It cannot tell which manual transmitter
produced the signal. Record while flying manually and make sure no other
transmitter is overriding that frequency. Two default lift frequency pairs
are `minecraft:iron_ingot / aeronautics:white_envelope` (normal) and
`minecraft:oak_log / aeronautics:white_envelope` (fine).

## Configurable control channels

Use **SETUP → CONFIGURE CONTROL SIGNALS** to edit item-frequency pairs
for forward thrust, reverse thrust, left, right, normal lift, fine lift,
and the optional inverted-engine-request channel. Select a channel,
choose Edit, then enter two Minecraft item IDs separated by a space.
You can paste through the computer keyboard; a touchscreen keyboard is
also provided. Changes are saved in `.airship_avionics_burners_settings`
and restored at startup. Stop navigation before remapping active controls;
non-lift old outputs are deasserted during a remap. **Lift outputs are never
forced to zero by Stop**, and remapping a lift frequency does not release
the old one—check your wiring and manual cutoffs before moving it.

## Floppy disk route transfer

Attach a CC:Tweaked Disk Drive containing a **data floppy** to the computer
(or its wired peripheral network). In **ROUTE → LIBRARY → EXPORT / IMPORT**
select the mounted drive. Export writes one versioned `.route` file under
`disk/skyways-routes/`, preserving the waypoint metadata. Exports never
overwrite an existing file; rename the source route before exporting a new
version. Import reads valid `.route` files from that folder and adds them
as independent routes without replacing the active route. Inserted audio
records cannot be used. Data is validated before import, and duplicate
imported files result in separate saved routes.

The installer additionally preserves `.airship_route_library` and its
`.backup` recovery copy across upgrades. Always keep a backup of your
recorded station routes before changing hardware or world coordinates.

## Refined route and power interface

The route screen now shows rounded X/Z coordinates, saved Y targets, and wait durations for each stop. A dedicated **PWR** tab displays requested and observed normal/fine lift strengths and engine link levels, with manual step controls. Per-station Y tolerance and a confirmation-only, one-leg Y override prevent an impossible height match from silently advancing a route. Optional bounded altitude assist is **OFF by default** until you confirm lift polarity on the ship.

See [Power Controls and Docking Guide](POWER_GUIDE.md) for instructions, link semantics, safety restrictions, and the height-assist limitations.
