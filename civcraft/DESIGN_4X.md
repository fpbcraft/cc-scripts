# CIVCRAFT: Territorial 4X design (v0.6)

Status: **implementation specification**. This document is the behavioral contract for the game's next iteration. All systems must run in CC:Tweaked on advanced monitors or ordinary computer terminals, including CraftOS iOS without `package` or `shell`.

## Design pillars

- **Decisions over clicks.** Workable tiles, city output, production queues, research choices and positional tactics should matter more than accumulated currency.
- **One consistent model.** All clients and AI use the same host-authoritative rules for visibility, territory, research, and production.
- **Readable touch interaction.** The hex world is primary; details live in an inspectable right sidebar on large displays, with compact fallbacks for small screens.
- **Reliable campaigns.** Three independent named save slots, deterministic generated world seeds, per-civ fog of war, and forward-only save migrations.

## World, territory and discovery

- Generated maps have seeded terrain and **seeded resource deposits** independent of global RNG. Strategic deposits include **iron**, **horses**, **saltpeter**; bonus deposits include **grain**, **timber**, **stone**, and **fish**.
- Cities claim a hex area (initial radius 2; growth increases radius when population warrants it). Conflicting claims use **nearest city**, then stable city ID as a tie-breaker. Cities never switch to enemy ownership merely because another culture border grows; ownership only changes through city capture.
- Hex borders visually separate different city/civilization territories; owned tiles gain owner tint in political mode. Borders follow the six hex edges, not rectangular outlines.
- Fog of war is civilization-private: unseen tiles dark, explored-but-not-visible terrain dim, enemy armies visible only inside current sight. Deposits are only shown on discovered tiles. Hot-seat handoff clears previous map state and private selections.
- Map modes switch **Terrain / Political / Resources / Yields**, with one obvious button and a legend appropriate to the active mode. View mode persists in the UI only, not as a gameplay modifier.

## City screen and workforce

- Selecting a friendly city reveals its **population, growth, yields, worked tiles, current production, and available production choices** in the sidebar.
- The city center is worked automatically. Residents work owned, discovered, passable hexes in a radius of two; each assignment is **one citizen to one hex**. Workable hexes highlight when the **WORK TILES** control is active. Tap a hex to work or unwork it; occupied slots are indicated on the map. Workers cannot exceed population (center consumes no worker). No cycling through opaque F/W/S job menus.
- Terrain and bonus deposits provide yield vectors `food / production / science`. Building modifiers and civilization abilities further modify those yields. Food surplus drives population growth; production accumulates toward the city's selected project; science accumulates toward a civilization-wide selected technology.
- City capture retains its buildings but stops the losing player from controlling the population or queue.

## Production (turns, not stockpiled resource purchases)

- Every city has **one production project**: `{kind = "unit"|"building", id, progress}`. The sidebar lists all units/buildings, their icon, unlock state, effective per-turn production, total production cost, and **estimated turns**. Selecting an item assigns it to the queue without immediately creating it.
- End-of-round applies production points. Completed buildings take effect on the next yield evaluation. Completed units spawn at the city if available, or a passable nearby free hex (naval units require a coastal water hex). Blocked completions stay queued at 100% until space opens.
- Standard production uses **turns and output**, not food/wood/science stockpiles. **Special units** additionally require control of a strategic resource deposit within a player's territory (for example iron for swordsmen, horses for horsemen, saltpeter for late gunpowder units). Strategic deposits are eligibility gates, not consumable inventory.
- Switching projects resets partially completed progress initially (explicit in UI). Finishing a turn updates all players exactly once.

## Research (turns, not science expenditures)

- Each civilization has a **single active research project** with `{id, progress}`. Science is a per-turn rate from cities and improvements, not a currency spent on selection. Existing `techs` unlock flags are retained.
- The research graph has prerequisite links. Nodes show **only a technology name + icon + compact state**. Selecting a node updates a **right-side detail pane** with description, prerequisites, unlocks, progress and estimated turns. The research action selects a technology rather than completing it instantly.
- The canvas supports pan/zoom in graphics mode with on-screen touch targets. A narrow/text terminal gets an era list and details screen.
- Tech progress applies once at end-of-round; completion unlocks production choices. Re-selecting the same active technology preserves progress.

## Civs, AI and UI

- Civilizations retain distinct modifiers. AI chooses legal research and production queues, reassigns citizens when growth changes, explores and uses the same movement/visibility rules. No AI teleportation or instant construction.
- Title screen: **Continue / New / Save slots / Settings / Exit**. In game: **Pause / Save / Main menu / Resume**. Settings include map view defaults where practical.
- The gameplay board shows city territories and map yields/deposits. Selecting a city opens the side production catalog with category tabs **Units / Buildings**, paging for the long lists, and a **WORK TILES** mode. Selecting an enemy/neutral tile does not expose private city options.
- Icon art must distinguish cities, unit classes, deposits, and building categories. Labels remain readable on CC:Tweaked's small monitors and CraftOS iOS with responsive scaling.

## Save data and migration

- Keep existing `/civcraft/data/slot-{1,2,3}.dat` and backups; never overwrite a save on selection alone. New schema uses version 4 while recognizing v1-v3 saves. Legacy `jobs`, `wood`, and `science` are kept for backward compatibility but no longer pay for production/research.
- Legacy city workforce is mapped deterministically to owned tiles, not guessed from unexplored positions. New worlds persist resource deposits and world seed; legacy worlds generate resources from their persisted tiles and stable migration seed.
- Save `city.worked`, `city.production`, `player.research`, discovered tiles, and city IDs. Repeated migrations must be idempotent.

## Acceptance tests

1. Deterministic resource generation, fair starting deposits, territory tie-breaking and six-edge border geometry.
2. Work assignment never exceeds population, respects city ownership, and yields match selected worked tiles.
3. Buildings/units do not appear until enough turn-based production has accrued; blocked spawn never deletes a queued unit.
4. Strategic-resource units require the appropriate controlled deposit; basic units do not consume stored food/wood.
5. Research cannot bypass prerequisites or finish immediately, and active progress survives saving/reloading.
6. UI tests: toggled map modes, political borders, resource visibility, city production sidebar, work-tile interaction, and selection/details/pan controls in the technology graph.
7. Regression tests: 3 save slots, generated-map determinism, private fog, hot-seat handoffs, network-host action validation, and CraftOS package-free rendering.
