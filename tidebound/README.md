# TIDEBOUND: Stellar Frontier (v3.0)

A two-player, pass-and-play **space 4X tabletop game** for CC:Tweaked. Stellaris-inspired, but intentionally designed for **one shared 3×3, 4×4 or 5×5 Advanced Monitor**. Explore a 24-system connected galaxy, expand borders, build colonies, operate fleets, compete in research, negotiate trade, and win by empire score.

**Graphics:** The game *automatically uses [CC: Graphics](https://modrinth.com/mod/cc-graphics) mode 2* (256-colour pixel drawing) when the monitor supports it. This is a direct 2D pixel renderer, not Pine3D. All graphics (including **23 hand-coded icon sprites**, a custom font and the procedural space map) are embedded in the standalone Lua file; no image assets, libraries, or internet are required while playing. When graphics mode isn't present, it falls back to CC:Tweaked's native coloured terminal display. The pixel renderer uses batches and `setFrozen` to reduce flicker. The mod version with monitor support is 0.2.0 or later, and requires CC:Tweaked 1.117.0+ for Minecraft 1.21.1.

## Install or update in Minecraft

Connect an Advanced Monitor to a computer (wired modems work). At the computer terminal:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-tidebound.lua
```

Launch it:

```lua
/tidebound/tidebound.lua
```

To install from a different Git branch or tag:

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-tidebound.lua my-branch
```

Add `--startup` if this is a **dedicated game computer** that should open TIDEBOUND on reboot. By default the installer **does not alter `/startup.lua`**, so it won't interfere with your airship/factory computers. Pre-existing startup scripts are backed up if startup is explicitly enabled. Installing again updates all three editions while keeping the save file. Failed downloads do not replace existing scripts.

You can also upload the single `tidebound.lua` file manually. The file's filename does not affect play; launch using the uploaded filename. Pass a monitor peripheral name explicitly if several monitors are connected:

```lua
/tidebound/tidebound.lua monitor_0
```

## What is new in 3.0

- **Galaxy map fills the monitor**. Status, tooltips, context menus and action confirmations float over the starfield rather than reserving fixed map-free columns.
- **Responsive layout** across 3×3, 4×4 and 5×5 monitors, set to text scale 0.5. Game detects size changes at runtime.
- **Animated starfield, orbiting title, system selection pulse and fleet-travel streaks**, with pixel-art ship, planet, starbase, science, energy, alloys, influence and technology icons.
- **Proper setup screen**: enter both empire names with an on-monitor QWERTY keyboard, choose map topology (cluster or spiral) and match length (12/18/26 years). Physical keyboard input is optional.
- **4X gameplay**: SURVEY unknown star systems; ANNEX neutral sectors; COLONIZE systems; build EXTRACTORS, FOUNDRIES, LABORATORIES, SHIPYARDS and STARBASES; construct frigates; DISPATCH fleets; research 4 tech trees; use a diplomatic trade accord; capture rival systems.
- **Explain-first actions**: tap a contextual order to open a detailed briefing showing its purpose, cost in resources, action points, and any unmet requirement. Press CONFIRM to perform it. This specifically replaces opaque verbs like the previous version's FOUND.
- **Empire report**: tap the empire name at top left for the victory score, system count and per-year resource forecasts. Tap RESEARCH, DIPLOMACY, JOURNAL or GUIDE along the bottom as needed.
- **Persistence**: automatically saves to `/tidebound/save.dat` after every successful action and turn. Continue from the title. Old Kingdoms saves are not overwritten.

## Turn rules

The players alternate using the **same physical monitor**. Each receives **three command points per turn**. Most orders cost one command. After player two ends their turn, a year passes and both empires collect production income.

The top bar shows the active empire, year, remaining command points and four resources: **Energy** (upkeep and actions), **Alloy** (buildings and ships), **Science** (research) and **Influence** (new territory and diplomacy).

| Order | Cost | Effect |
|---|---|---|
| Survey | Energy 2 + 1 command | Reveals a system adjacent to your claimed territory; may recover free supplies |
| Annex | Influence 3 + 1 command | Adds a surveyed neutral system next to your territory or containing your fleet |
| Colonize | Alloy 5, Energy 2 + 1 command | Founds a settlement on your system, increasing score and enabling construction |
| Extractors | Alloy 4, Energy 1 + 1 command | Produces +2 alloy/year in Ore systems, otherwise +2 energy/year |
| Foundry | Alloy 5, Energy 1 + 1 command | Produces +2 alloy/year |
| Laboratory | Alloy 4, Energy 1 + 1 command | Produces +2 science/year |
| Shipyard | Alloy 6, Energy 2 + 1 command | Enables ship construction on colonized systems |
| Build Fleet | Alloy 4, Energy 1 + 1 command | Adds two frigates to a shipyard system (max eight per empire per system) |
| Starbase | Alloy 4, Energy 1 + 1 command | Adds three defensive combat strength to a colonized system |
| Dispatch | Energy 1 + 1 command | Choose ship count and tap a reachable destination; hostile destinations trigger battle |

Hyperdrives research allows ships to cross two starlanes via a friendly midpoint. Reactors increase each colony's energy output, Armaments increase combat power per ship, and Civic Unity increases influence production. Research costs science and one command; higher tiers cost progressively more.

An **active trade accord** grants both sides +2 energy and +1 science each year, but prevents either from attacking the other until somebody breaks it (which imposes an influence penalty).

Score: **one point per claimed system, two per colony, two per technology level, and two per conquered hostile system**. The first player to reach 40 points wins immediately. Otherwise, the highest score after the configured number of years wins. Eliminate your rival's last claimed system for an immediate victory. A tied result at the year limit is a draw.

### Controls

- Touch a system to select it and open its action panel.
- Touch an action to review its effects, costs and requirements. Tap Confirm or Cancel.
- For Dispatch, set the number of ships with the plus/minus buttons, then touch a highlighted destination.
- Touch the active empire name to see the empire report.
- On the shared monitor, no information is secret. Players may discuss diplomacy face to face.
- The setup screen supports both on-screen keyboard input and a computer keyboard, if available.
- For the optional graphics mode, **touch coordinates still use the CC:Tweaked monitor character grid**; the game converts those coordinates to pixel-rendered map locations.

## Editions

- `tidebound.lua` — **Stellar Frontier 3.0** (new game)
- `tidebound-kingdoms.lua` — Kingdoms 2.1 (original land-based game)
- `tidebound-classic.lua` — TIDEBOUND naval combat (original)

Each game has a separate save format; no automatic conversion is attempted. The new game explicitly uses `/tidebound/save.dat`, while the Kingdoms edition uses its own `tidebound-kingdoms.save` path.

## Testing & known limits

Offline checks can run with a Lua interpreter:

```bash
texlua tidebound.lua --self-test
```

These checks cover procedural connected map generation, movement/warfare, research, economy, diplomacy, and rendering/touch hitboxes on representative 3×3, 4×4 and 5×5-sized screens in pixel and native modes. The game has **not been exercised on your Minecraft CC: Graphics mod build**, so test the first install in-game and report any exceptions or touch-coordinate mismatch.

The CC: Graphics plugin must be installed on both the server and clients, with HTTP enabled only for the installer. Actual refresh rates depend on network/server performance, and the current game deliberately limits update frequency on large monitors. Native graphics mode can be disabled via your graphics mod's options, in which case the fallback should work.