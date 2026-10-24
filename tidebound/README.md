# TIDEBOUND: The Shattered Expanse (v5.0)

A four-civilization, hot-seat space 4X game with **1–4 human commanders and AI filling the remaining seats**, designed for a **5×5 CC:Tweaked Advanced Monitor**. The new edition implements the approved v5 simplification and UI mockups: no overlapping menu stacks, three resources, three ship roles, three research paths, and persistent roleplaying decisions.

## Install or update

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-tidebound.lua
/tidebound/tidebound.lua
```

Requires an Advanced Computer and a connected colour Advanced Monitor. The game autodetects a monitor; specify its peripheral name as a CLI argument to override it. **CC: Graphics** mode 2 is used automatically when available, with a text-mode fallback. This version was tested offline against simulated **3×3, 4×4 and 5×5** monitor sizes; 5×5 is the target. Actual modded Minecraft performance and interaction have not yet been verified.

`--startup` on the installer is optional. It is intended only for a dedicated game computer and preserves a previously installed startup script when possible.

## The v5 rules

- **30 connected star systems** with fog of war and strategic chokepoints.
- **Four empires**, with individual names and archetypes. One to four humans; the rest AI.
- **Three resources:** Credits (diplomacy and administration), Alloy (colonies and fleets), Knowledge (research).
- **Three ships:** Scout (reveals systems), Colony Ark (founds a colony), Fleet (fights other empires). Each ship receives **two orders per year**; empire decisions have no global action cap.
- **Colonies:** One specialization per colony: Industry, Science or Commerce. Each can be upgraded twice. You can change specialization or upgrade once per colony per year.
- **Research:** Three 3-level paths — Exploration, Prosperity, Warfare. Research consumes Knowledge; it does not consume ship orders.
- **Diplomacy:** Trade, non-aggression, alliance, war and peace. Human offers queue until the recipient accepts or declines. AI acceptances respond to relationship and personality.
- **Narrative:** Branching council events with immediate resource/trust effects, remembered ideological choices and time-delayed follow-up chapters.
- **Income and orders:** When all four players finish a year, production is added, ship orders reset and multi-year projects progress. Turn order rotates annually.

### Expanding the galaxy

1. Select **Ships** and tap **ORDER** on a Scout. Tap an adjacent linked system, then confirm the move. Scouting reveals its contents.
2. Move a **Colony Ark** to a discovered neutral system adjacent to your borders.
3. Tap **FOUND** on the Ark in Ships, or select the system and choose **FOUND COLONY**. The Ark is consumed and establishment costs **8 Credits + 12 Alloy**.
4. Open **Worlds** to specialize the new colony. The planet's type affects specialty output.
5. Select your own colony in Galaxy to launch new ships using resources (Scouts C3/A7, Arks C5/A12, Fleets C5/A10).

### Victory

| Route | Requirements |
|---|---|
| **Discovery** | Exploration III, 14 surveyed systems, 3 ancient clues from Rift/Relic exploration, 3 colonies, then fund and finish a 3-year Ancient Archive project |
| **Unity** | Prosperity II, 2 alliances, 4 colonies, then fund and finish a 3-year Galactic Accord project |
| **Dominion** | Control at least 15 of the 30 systems |
| **Legacy** | Highest empire score when the selected year limit expires |

The intended balance is that different routes remain viable; *AI campaign simulations currently favour Unity*, so tactical balance remains an active playtesting concern rather than a finished claim.

## UI

The galaxy uses the full available play area between a narrow top status bar and bottom navigation dock. Selecting a star opens **only one inspector**, with the galaxy narrowing to leave it space. Scouts, orders, research, colony specialization, diplomacy, empire overview, events, handoff and results have dedicated screens. Every order is prevalidated with requirements and has an explicit confirmation view.

Graphics-mode `monitor_touch` uses 0-based pixel coordinates and the fallback uses 1-based character coordinates. This game converts input to one coordinate system before hit detection.

## Saves, legacy editions and rollback

- v5: `/tidebound/v5-save.dat`, with `.bak` fallback.
- v4: `/tidebound/expanse-save.dat`, **not migrated or overwritten by v5**.
- v3: `/tidebound/save.dat`, kept unchanged.

Previous games are launchable independently:

```sh
/tidebound/tidebound-shattered-v4.lua   # The Shattered Expanse v4
/tidebound/tidebound-stellar-frontier.lua # Stellar Frontier v3
/tidebound/tidebound-kingdoms.lua        # Kingdoms v2
/tidebound/tidebound-classic.lua         # Original naval edition
```

The installer downloads and syntax-checks every Lua module before activation; it rolls back file replacements after a failed activation and leaves all save files outside its code replacement list.

## Architecture

```text
install-tidebound.lua       validated installer with code rollback, preserves saves
/tidebound/tidebound.lua    v5 launcher + monitor discovery
/tidebound/expanse-v5/
  content.lua               faction, tech, ship and economy data
  events.lua                branching, delayed narrative events
  sim.lua                   deterministic rules, resources, AI and victory
  render.lua                256-colour pixel rendering and text fallback
  ui.lua                    title, setup, keyboard, galaxy, inspector,
                            ships, worlds, research, diplomacy, council,
                            victory, confirmation and touch mapping
/tidebound/tests/v5.lua    seeded simulation and fake-monitor tests
/tidebound/expanse/         previous v4 modules (unchanged)
```

Run offline tests from repository root with `texlua tidebound/tests/v5.lua ./tidebound/expanse-v5`. The simulator is independent of the display; tests cover seeded maps, resource invariants, AI progression, ship orders, narrative decisions, keyboard and touch hitboxes at three monitor sizes.