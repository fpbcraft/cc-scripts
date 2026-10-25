# CivCraft roadmap implementation

Source: [design draft v0.9.1](ROADMAP-v0.9.md). Open design choices remain open; proposed balancing values are not confirmed requirements. Work is on `codex/civcraft-roadmap`.

## 01: Shared gameplay rules

Implemented locally:

- `actions.lua` owns gameplay-order validation and execution. Local/remote human requests, AI research/production/staffing/trading/envoys, movement, founding, city strikes and engineer orders use it. Session startup, ready-state transitions and persistence remain in `game.lua`; wilderness monsters keep their separate local-sight rules.
- Settlers have three base movement points, pay one on ordinary land and require positive movement remaining to found. Founding checks ownership, terrain, landmarks, camps and city spacing before consuming the unit. Cavalry difficult-terrain cost is capped at two.
- Valid movement/attack/rail orders wake sleeping units. Invalid orders preserve sleep. The inspector allows orders without a manual Wake step.
- Passive healing requires owned territory; support healing still works outside it.
- `Combat.predict` is pure, includes HP, wall loss, retaliation, deaths and capture, and supplies the result applied by combat resolution. Unit attack previews show predicted remaining HP and walls in the status line.
- No Production preserves project progress and suppresses deliberate-idle reminders. Selecting production resumes saved work.
- The installer package includes the new action module.

Save compatibility: save schema remains version 6. The only new persisted gameplay field is optional `city.productionIdle`; absent means the existing idle/reminder behavior. Existing world terrain, resources, claims, seed and dimensions stay intact. Stored movement budgets are preserved when loading; the new settler allowance applies at the next normal reset and to newly produced units. No migration grants extra movement mid-round. Future world generation and diplomacy changes need explicit independent versions and migration tests before landing.

Validation: new command tests cover human/AI founding parity, failed orders, movement costs, support healing, paused progress and 180 pure combat forecasts. New text/graphics UI checks cover No Production confirmation, sleeping orders and forecast confirmation. Seeded progression scenarios separately exercise expedition-oriented and industry-oriented AI; the mixed-goal campaign now allows an earlier legal Industrial victory after faster expansion. Automated checks do not establish actual monitor performance, live rednet behavior or multiplayer privacy under races.

## 02: Biome world generation

New campaigns use generation version 2, with separate `biome`, `elevation` and `feature` records in `world.geography`. `world.tiles` remains a terrain projection for existing mechanics and save readers. A read-only adapter supplies layered information for old terrain strings. Loading an existing world does not regenerate or fill its deposits, terrain, wonders or starting locations.

The generator uses private seeded PRNG streams and smooth macro height, elevation, temperature, moisture and vegetation fields. It targets 17.5% deposits as an initial balance setting; habitat rules select each deposit, with rarer redstone and diamond. Every start has immediate grain and non-snowy hill iron, a passable first ring and at least 18 connected land tiles within three hexes. Repairs preserve surrounding climates where possible. At least 55% of traversable land is open; ordinary combined difficult terrain remains capped at two movement points.

Natural wonders choose shuffled eligible habitat candidates with geographic separation. Spawn buffers scale from five hexes on Compact to six on Standard and eight on larger maps; separation is three or four hexes. Habitat availability determines wonder variety rather than forcing every wonder into every world. Mushroom landmarks create rare mushroom-field patches before resource allocation. Constructed wonders retain their existing production and uniqueness rules.

Terrain rendering, minimaps and tile inspection use the new layers. Woodland can appear on a hill, snowy land and coasts have their own palette, and the terrain sprite cache is bounded. Observer snapshots filter geographic records by discovery just like terrain and resources. New deposit visibility is not gated by technology.

Added Huge (48×32) and Vast (64×40) to the lobby. Existing Compact (18×12), Standard (28×18) and Large (40×26) remain available. Cooperative checkpoints cover generation, snapshot rows and large territory loops.

Validation:

- 600 generated worlds spanning all five sizes, four map types and 2–4 civilizations passed density, habitat, traversability, climate coherence, fair-start, wonder-spacing and fog checks. Across that matrix, open traversable land was at least 55%, matching neighbouring biomes averaged 69%, and every map had at least one eligible wonder.
- Lua 5.2 and Lua 5.3 generated identical data for 40 additional seed/settings combinations.
- All 52 repository regression scripts passed with a Lua 5.3 runtime and the repository's existing `bit32` compatibility shim. A renderer preview was visually inspected. These are local automated/rendered checks, not live multiplayer or monitor validation.
- Run `lua5.3 tests/civcraft_world_benchmark.lua` for reproducible desktop timing output. See [WORLDGEN-BENCHMARK.md](WORLDGEN-BENCHMARK.md) for the measured scenarios and limitations.

## Lua style and upstream integration

The user's governing guide is the [Roblox Lua style guide](https://roblox.github.io/lua-style-guide/), replacing the earlier LuaRocks reference. Modified Lua files use tabs, a 100-column target, expanded blocks, double-quoted strings and camelCase local/function names where introduced; CraftOS and existing save/API names remain compatible. Formatting was applied and verified with StyLua 2.6.0. New code remains ordinary Lua, without Luau-only syntax.

The separately maintained [style-enforcement branch](https://github.com/fpbcraft/cc-scripts/compare/main...chore/enforce-lua-style) must merge before this implementation. Its configuration was inspected while still in progress and then specified two spaces/120 columns. Re-read its final configuration after merge, rebase this branch onto `main`, resolve formatting conflicts, and run its final StyLua/Selene checks before considering the implementation ready. Do not duplicate that branch's repository-wide tooling work here.

## Remaining workstreams

03. Sequenced events and event-time observer projections.
04. Smooth movement/combat animation, playback controls and bounded replay.
05. Stable strategic plans, fixed personalities and economic utilities.
06. Threat maps, tactical campaigns, retreat and coordinated support.
07. Hybrid peaceful/war-group turns and declaration transitions.
08. Relations, treaty offers, explicit defense calls and authored conversations.
09. Council elections, resolutions and diplomatic victory.
10. Duration/victory lobby settings, compact graphical research, HUD and factions.
11. AI difficulty variants after the Prince baseline.
12. Save/integration/fuzz/performance/network validation and release metadata.

Remaining foundation concerns: threat highlights and destination scores; exact city-defense forecasts when remote snapshots omit units that contribute to global city strength; event-backed per-segment movement/visibility; live CC:Tweaked verification. Keep hidden unit information out of forecasts instead of exposing authoritative records to clients. Resolve the remote defense rule in the event/snapshot workstream before calling all combat previews exact across clients.

The full roadmap is not complete. Live CC:Tweaked and rednet validation is still required for both implemented workstreams; do not treat these commits as a v0.9 release.
