# TIDEBOUND: The Shattered Expanse (v5.1)

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

1. Tap a **Scout icon directly on the galaxy map**, choose **Move Ship** from the compact context menu, then tap an adjacent linked star. Confirm the destination. Scouting reveals its contents.
2. Tap the **Colony Ark icon** beside its planet, choose **Move Ship**, and tap a discovered neutral system adjacent to your borders.
3. Tap the **Ark icon** on the new system and choose **Found Colony**, or tap the planet and select **Found Colony**. The Ark is consumed and establishment costs **8 Credits + 12 Alloy**.
4. Tap the colony planet and choose **Manage World** to specialize it. The planet's type affects specialty output.
5. Tap your owned planet to build ships using resources (Scouts C3/A7, Arks C5/A12, Fleets C5/A10). The **Ships** and **Worlds** tabs are optional empire overviews, not prerequisites for selecting units.

### Victory

| Route | Requirements |
|---|---|
| **Discovery** | Exploration III, 14 surveyed systems, 3 ancient clues from Rift/Relic exploration, 3 colonies, then fund and finish a 3-year Ancient Archive project |
| **Unity** | Prosperity II, 2 alliances, 4 colonies, then fund and finish a 3-year Galactic Accord project |
| **Dominion** | Control at least 15 of the 30 systems |
| **Legacy** | Highest empire score when the selected year limit expires |

The intended balance is that different routes remain viable; *AI campaign simulations currently favour Unity*, so tactical balance remains an active playtesting concern rather than a finished claim.

## UI: compact contextual actions

The galaxy fills the display between a narrow status bar and bottom navigation dock. Every star is a **directly selectable planet/system** and visible ships are drawn as **separate icons beside their system** (Scout, Colony Ark, Fleet). Each ship has its own non-overlapping touch target; even several ships orbiting the same planet can be selected individually. Tapping a star or a ship opens a **small, anchored Windows-style context menu**, with common actions on single tap. It does not push, pan or shrink the map.

- **Tap a planet:** inspect its owner and type, manage a colony, colonize or build a ship depending on context.
- **Tap a ship icon:** inspect orders and choose **Move / Attack**, **Found Colony** (Ark) or **View System**. You do **not** have to open Ships first.
- **Tap Move**, then tap a linked destination planet directly to see confirmation. Moving consumes one of the selected ship's own yearly orders.
- **Tap outside the context menu** to dismiss it, or tap a different visible marker to select that entity.
- **Ships** and **Worlds** remain available as optional strategic overviews, not mandatory entity pickers.

All interactions use the same normal right-click `monitor_touch`, including in Creative mode. **No left-click companion mod is required.** Graphics-mode input uses 0-based pixel coordinates and the fallback uses 1-based character coordinates; both are normalized before hit detection. Hitboxes are independently laid out so separate entity icons do not compete for the same touch area.

Research, diplomacy, council decisions, empire overview, handoff, and results have dedicated screens. Expensive orders still require an explicit confirmation.

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
  ui.lua                    title, setup, keyboard, galaxy, compact context menu,
                            ships, worlds, research, diplomacy, council,
                            victory, confirmation and touch mapping
/tidebound/tests/v5.lua    seeded simulation and fake-monitor tests
/tidebound/expanse/         previous v4 modules (unchanged)
```

Run offline tests from repository root with `texlua tidebound/tests/v5.lua ./tidebound/expanse-v5`. The simulator is independent of the display; tests cover seeded maps, resource invariants, AI progression, ship orders, narrative decisions, keyboard, direct ship and planet hit targets, contextual action geometry, and touch mapping at three monitor sizes.