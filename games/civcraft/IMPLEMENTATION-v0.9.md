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

## 03: Action events and observer snapshots

Implemented locally:

- Version 1 observer journals retain up to 128 entries with an age limit of eight rounds. Movement, combat, capture/defeat, founding, disbanding, rail work, unit production, completed buildings/wonders, research and landmark discoveries emit action-time records. Research and administrative orders are private to their issuer.
- Each movement segment updates exploration and records who could actually see that position. Observer projections split paths at fog boundaries, omit hidden origins/endpoints and never reconstruct them from later exploration. Partially observed combat sends either an impact without its concealed attacker or visible actor activity without the concealed target. Only explicitly supported fields and event categories survive projection.
- The host assigns observer-local sequence numbers, so a recipient cannot infer the count of hidden actions from sequence gaps. The host retains no separate unrestricted raw-action history. Trusted host saves contain the observers' bounded journals; snapshots contain only the receiving observer's `eventStream`.
- Snapshots have per-observer transport serials and host-session identifiers. Receivers reject duplicates, stale snapshots, retired sessions, malformed streams and streams belonging to another observer. Campaign changes reset replay windows; received windows merge before acknowledgement so a fast empty snapshot cannot erase queued presentation data. Old protocol peers remain usable without the new replay guarantees.
- Host UI and network commands pass through one bounded cooperative queue, including snapshot construction. A yielded rule calculation or snapshot cannot interleave another mutation; overflow returns a retry result. Event acknowledgements cannot create a publication loop. New network orders include campaign/round context so stale commands cannot spend a new round's movement. Remote Save asks the host to persist its authoritative state.
- Visible rival cities/units use public-field snapshots instead of copying production, worker allocation or auto-exploration plans. Public combat ratings keep remote forecasts consistent without transmitting the hidden army that contributes to city strength. Melee attacks physically follow their approved approach, and ranged attacks cannot use an untraversed path to shoot outside their actual range.
- Version 1 map-memory records preserve last-observed rails, landmarks and camps while terrain is in explored fog. Rival construction and camp clearing stay private until re-scouted, in both network snapshots and local map/inspector rendering. Old saves preserve terrain/deposits; unknown dynamic infrastructure is not invented during migration. Immutable natural landmarks can restore previously explored knowledge.
- The package manifest installs all new runtime modules.

All 54 repository regression scripts passed. Automated evidence includes privacy and temporal-order assertions, interrupted command/snapshot coroutines, replay bounds/cursors, stale/malformed packets, hidden infrastructure and text/graphics inspector checks. Three checks passed together in a fresh native CraftOS-PC profile: the core event suite, actual renderer/button calls with filesystem serialization/reload, and a complete game session. That session uses real mouse events to traverse the paged lobby, initial reports, two human turns and private handoffs, round processing, pause, save and exit. See [NATIVE-TESTS.md](NATIVE-TESTS.md) for isolated reproduction and exact boundaries. These do not yet prove multi-client rednet behavior, physical monitor input or animation responsiveness. The visible replay/feed and interpolation controller belong to workstream 04.

## Lua style and upstream integration

The user's governing guide is the [Roblox Lua style guide](https://roblox.github.io/lua-style-guide/), replacing the earlier LuaRocks reference. After rebasing, the user authorized updating `.stylua.toml` to align with the Roblox guide: tabs displayed at four columns, a 100-column target, double-quoted strings and expanded blocks. `.editorconfig` and repository documentation match; the repository was reformatted with AST verification. Modified code follows the guide's readability, expanded blocks, double-quoted strings and camelCase naming where introduced; existing save/API names remain compatible. New code remains ordinary Lua, without Luau-only syntax.

Rebased onto `main` at `3a7518b` after PR #47 merged. Formatting conflicts were resolved through normalized three-way merges and checked against the pre-rebase implementation; upstream fixes and Selene annotations were retained. Use the repository's `.stylua.toml`, `selene.toml` and `cc-tweaked.yml` for all future work. StyLua 2.6.0 verifies formatting and Selene 0.32.0 checks the branch. The local Selene build enables `selene-lib/lua52` and `selene-lib/lua53` so the full CraftOS standard library loads without the prebuilt macOS binary's diagnostic. Refresh and rebase against `main` again before the final PR if it advances.

## Remaining workstreams

04. Smooth movement/combat animation, playback controls and bounded replay.
05. Stable strategic plans, fixed personalities and economic utilities.
06. Threat maps, tactical campaigns, retreat and coordinated support.
07. Hybrid peaceful/war-group turns and declaration transitions.
08. Relations, treaty offers, explicit defense calls and authored conversations.
09. Council elections, resolutions and diplomatic victory.
10. Duration/victory lobby settings, compact graphical research, HUD and factions.
11. AI difficulty variants after the Prince baseline.
12. Save/integration/fuzz/performance/network validation and release metadata.

Remaining foundation concerns: threat highlights and destination scores; complete simulation/presentation isolation during cooperative rendering; physical monitor and live rednet verification. Native CraftOS-PC event, rendering and save checks complement the automated suite. Public city/unit ratings now resolve the earlier hidden-army forecast mismatch; event-time path projection resolves the earlier replay-visibility gap.

The full roadmap is not complete. Target-server CC:Tweaked and live rednet validation is still required; do not treat these commits as a v0.9 release.
