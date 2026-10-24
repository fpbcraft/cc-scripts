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

## Map-screen layout and touch controls (required)

The map must remain the dominant **central view**; fixed control **bars on both sides of the map** should replace the large bottom action grid:

- **Left bar — navigation and world views:** map-mode controls (Terrain, Territory, Resources), zoom where practical, camera pan arrows (up/down/left/right) for simple monitor touch, and a recenter control. Each control uses a distinct icon **and** a short text label or tooltip. Map navigation must never move the fixed sidebars.
- **Center — interactive hex map:** large scrollable viewport, visible owner-colored city territory outlines, fog/discovery shading, deposits, recognizable city/unit icons, highlighted reachable movement and attack cells. Finger/mouse dragging pans the map when supported; tapping a cell selects it, not a neighboring hex. Camera offset is clamped, retained between frames, and reset sensibly when a new campaign/world is loaded.
- **Right bar — selection inspector and actions:** selecting a unit shows its icon, attack/defense/movement/range/vision, unique ability, movement remaining and available actions. Selecting a city shows population, current yields, project/progress and production options. Selecting a resource hex shows its deposit and tile yield. A persistent **production list** appears when a city is selected, with unit/building icons, locked state, turns-to-complete and requirements, like the provided Civilization screenshot.
- **City staffing interaction:** three prominent Food/Industry/Science allocation rows with direct large +/- touch targets, citizen counts and per-turn yield previews. This should not require repeatedly opening small text menus. Workers cannot become negative or exceed population.
- **Tech tree layout:** use pixel/canvas primitives for icon + name graph nodes, visible prerequisites/branch connectors, drag or directional pan, and a dedicated details side panel. Do not crowd every node with lengthy descriptions; put unlocks, effects, time estimate and Start Research in the side panel.
- **Actions:** use consistent custom pixel-art icons on **most** buttons: move, attack, found city, units, buildings, production, workers, research, map modes, zoom/pan, pause, resume, save, next turn, back, confirm. Preserve text labels and adequate target sizes, particularly on CraftOS iOS.
- **Responsive behavior:** large monitors and iPad use both bars alongside the map. On narrower computers, bars become compact or switchable while retaining map visibility and working keyboard controls. Never assume a fixed pixel resolution, and never let canvas art or buttons overlap the hot-seat privacy handoff.

## Delivery tracker

Check boxes indicate **verified end-to-end behavior**, not just files or partial rules existing on a development branch.

- [x] Define gameplay/UX scope and map/sidebar interaction contract in repository documentation.
- [ ] Save compatibility regression test for existing 3 slots and legacy worlds.
- [ ] Larger seeded generation with map-size and map-type selection and stable starting positions.
- [ ] Pannable centered map, touch drag and accessible arrow controls in the left fixed bar.
- [ ] Three fog-safe map view modes, visible resources and owner-colored territory edges.
- [ ] Unit movement range previews, terrain-dependent cost, full stats and civilization abilities.
- [ ] City's per-turn food/industry/science yields, growth, direct worker allocation controls.
- [ ] City production list in the right fixed bar; per-turn unit/building progress, not instant purchases.
- [ ] Strategic deposit prerequisites and distinctive units/civilization bonuses.
- [ ] True turn-based technology research, persisted progress and unlock effects.
- [ ] Graphical, pannable technology DAG with compact nodes and side detail panel.
- [ ] Icons + readable text on most actions, including pause/save and next-turn.
- [ ] AI participation under the same economics, production and research rules.
- [ ] Regression coverage for touch coordinates, fog privacy, maps, economy, AI, saves and installer.
- [ ] Passing CI, merged PR and iPad runtime verification (hardware testing remains separate).

### Project phases
1. **World model:** deterministic terrain/resource presets, territory, saves and exploration.
2. **Turn economy:** jobs/yields/growth, queue projects, research progress, abilities and AI.
3. **Map and city UI:** central pannable map, fixed sidebars, production inspector and action icons.
4. **Tech canvas, integration and QA:** connected technology graph, responsive fallback, regression tests, release manifest and version bump.

**Implementation note:** Code on `feat/civcraft-strategy-depth-tech-canvas` is in progress and is not yet a released version. Existing v0.5 functionality must remain usable throughout migration.

## UX, persistence and testing
- Title screen -> save slot -> lobby (map size, map type, seed, civilization/AI assignments) -> world. Pause menu allows SAVE, RESUME, MAIN MENU, EXIT.
- City inspector contains population worker controls and build queue; tech graph has compact nodes + right-hand details. World has a persistent turn summary and distinct map views.
- Save migration: old numeric science/wood/food remain safely readable but use the new turn-progress economy; don't lose game state or delete saves.
- Tests: seeded determinism + different map styles, territory edges and fog, pan clamping & tap transforms, population conservation, project completion timing, research completion timing & prerequisites, unique civ effects, save migration, and Store installer manifest.
