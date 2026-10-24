# CIVCRAFT v0.6 — 4X systems and interaction specification

This is the implementation contract for the next release. Existing v0.5 generated worlds, three save slots, discovery, and network/hot-seat modes must migrate without destruction.

## Main world
- Hex world is 2–4 times the original playable area depending on the **map size** selected in the lobby; seed gives deterministic terrain, resources, starts and coastlines.
- **Map type** is selectable independently: CONTINENTS (landmasses separated by seas), ARCHIPELAGO (small islands), PANGAEA (large central landmass), and HIGHLANDS (elevated inland regions). No regenerating a saved world on load.
- Scrollable camera viewport: touch drag/pan when drag events exist, pan buttons for monitor-only touch, mouse-scroll optional, clamp to map boundaries. Selection/hit testing uses the same camera transform as drawing.
- Three map views: TERRAIN, TERRITORY, RESOURCES. FOG OF WAR is always enforced; explored but not currently visible areas are dimmed. Other civilizations' information is private during hot-seat handoffs.

## Hex territory and resources
- Generated tile deposits include farms/grain (food), timber and stone (industry), horses and iron (strategic).
- Each city claims nearby tiles (initial radius 1, expands with population), with consistent resolution if two borders contest the same hex. Render only exposed polygon edges in the owning civilization's color; visible in territory view and as subtle outlines in normal view.
- Tile yields and strategic deposits are assigned by the territory owner; strategic prerequisites (horses/iron) enable special units rather than charging wood/food.
- Never expose another civilization's hidden map, resources, cities, or units outside visibility.

## Economy and production
- Cities have separate **Food**, **Industry**, **Science** worker allocations. Every citizen works exactly one sector; direct +/- controls adjust counts and give immediate projected per-turn yields.
- Cities produce yields at the **global turn boundary**. Food surplus grows population, industry advances the city's active production, science advances the civilization's selected research.
- Only one active city project at once: unit or building. A production sidebar lists locked, available, selected and completed options, production cost in **turns**, expected completion, unique-unit icons and prerequisite details. Switching projects retains progress only for a specific project to discourage queue exploits.
- Normal units/buildings do **not** spend abstract resources on order. Special units can require a connected strategic deposit, checked when queued and completed.

## Research
- Technology tree uses a canvas-style **directed graph**: compact clickable name-and-icon nodes connected by prerequisite edges. Selection shows a persistent right detail panel with research time, prerequisites, abilities, unlocked items and a START RESEARCH control.
- Research accumulates science **per full turn** and completes at threshold; science is no longer a wallet for instant tech purchase. Switching technology retains progress for that technology. The research target and completion progress persist in saves.
- Research UI must work in both graphics and text fallback; panels don't overlap graph hit targets.

## Civilizations and units
- Each civilization has a mechanically distinct passive bonus or **unique unit**. Examples: Verdant (farm yields), Iron Dominion (industrial bonuses), Nomads (scout move), Mariner (ships), Highland (hill combat), Stone Wardens (city defenses), Wildborn (forest mobility), etc. Display these in the setup lobby.
- Units retain attack, defense, movement points, range, vision and role. Pathfinding respects terrain cost and ability. Show reachable hexes, projected movement cost and attack targets.

## UX, persistence and testing
- Title screen -> save slot -> lobby (map size, map type, seed, civilization/AI assignments) -> world. Pause menu allows SAVE, RESUME, MAIN MENU, EXIT.
- City inspector contains population worker controls and build queue; tech graph has compact nodes + right-hand details. World has a persistent turn summary and distinct map views.
- Save migration: old numeric science/wood/food remain safely readable but use the new turn-progress economy; don't lose game state or delete saves.
- Tests: seeded determinism + different map styles, territory edges and fog, pan clamping & tap transforms, population conservation, project completion timing, research completion timing & prerequisites, unique civ effects, save migration, and Store installer manifest.
