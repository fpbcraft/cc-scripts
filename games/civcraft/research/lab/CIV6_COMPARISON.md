# Civ VI and CivCraft: pacing and balance comparison

Date: 2026-10-26
Scope: Gathering Storm reference data compared with the CivCraft implementation at `c5d7e4dfb7538b1f164d36fcb08946f250179c6e`.

This is a design comparison, not a claim that Civilization VI is perfectly balanced. Civ VI is useful as a reference because its systems create several interacting clocks: population, production, science, culture, gold, strategic resources, movement, diplomacy and victory progress. The recommendation is to borrow those relationships in a Minecraft/Create form, not to copy its numbers.

## Evidence boundary

The Civ VI catalog is a public Gathering Storm Civilopedia snapshot: 77 technologies, 61 civics, 161 units, 85 buildings, 35 districts and 136 entries from the Wonders index. It includes unique and optional-mode entries and late-game projects exposed by that index. It records article facts such as costs, yields, maintenance, resource quantities, requirements, boosts and upgrade links. It does not merge the installed `Gameplay.sqlite`, modifier tables, map scripts or every DLC-specific rule. Missing values are `null`, not zero. See [the catalog README](../civ6-balance-2026-10-26/README.md), [the JSON catalog](../civ6-balance-2026-10-26/civ6_gathering_storm_catalog.json), and [the verification script](../civ6-balance-2026-10-26/verify_catalog.py).

Civ VI facts below are linked to the public [Gathering Storm Civilopedia](https://www.civilopedia.net/en-US/gathering-storm/). CivCraft facts come from [the current content inventory](../civ6-balance-2026-10-26/CIVCRAFT-INVENTORY.md), [the measured JSON baseline](../civ6-balance-2026-10-26/civcraft_measurements.json), and the current Lua sources. A measurement from one seed or one match is evidence about that fixture, not a population estimate. The full-duration native fixture was one Forge mirror match on Compact/Pangaea at Prince; it reached Industrial victory on round 149 and recorded three cities each, with ages at rounds 1, 24/26, 58/60, 78/80, 97/102 and 121/127. It is a pacing probe, not a balance result.

## What makes Civ VI feel paced

### 1. The game has multiple clocks, so one decision changes several future options

Civ VI's Standard speed is 500 turns; Quick, Epic and Marathon use 330, 750 and 1,500 turns, while Online uses 250. Speed scales research, culture, production, gold, faith and Great Person costs, while unit movement remains unchanged. That distinction keeps the map and tactical geography legible when the strategic game is shortened or lengthened. [Speed reference](https://civilization.fandom.com/wiki/Speed_%28Civ6%29).

The technology tree has nine eras in the Gathering Storm catalog, and the civic tree is a separate progression. A tech or civic can unlock a unit, building, district prerequisite, resource or strategic capability. A player therefore spends a finite early production budget between expansion, infrastructure and defense while also deciding which future branch becomes available. The split science/culture clocks prevent a pure science economy from automatically receiving every government and policy benefit.

CivCraft has six ages and 45 technologies, but one global science track and no separate civic/policy clock. Its tech costs total 3,150 base science, grouped as 144/256/350/560/800/1,040 by age. This is a clear backbone, but each age is a fairly wide bundle and several branches have little pressure on the player to choose between competing economic identities. The missing second clock is a major reason research can feel either too fast or like a queue of prerequisites rather than a strategic commitment.

### 2. Unlocks are active objectives rather than only waiting

Civ VI attaches Eureka and Inspiration tasks to many technologies and civics. The Civilopedia describes these as immediate, significant research boosts earned by actions such as settling on the coast, building an improvement or meeting another civilization. The tasks make exploration, warfare, terrain and development contribute to research instead of making science an isolated slider. [Eureka reference](https://www.civilopedia.net/en-US/gathering-storm/concepts/science_3/).

CivCraft has good thematic prerequisites—Create machinery, brass, railways, Nether and End projects—but does not yet have an equivalent boost layer. The recommended adaptation is a small number of Minecraft-native “proofs” attached to expensive or pivotal techs: run a belt line, power a mixer, connect two stations, clear a hostile camp, discover a village, or protect a convoy. A proof should reduce the remaining cost or grant a one-time resource, while never being mandatory for a route. This makes the world participate in progression without adding a second full tree.

### 3. Buildings are constrained specializations, not a flat list of yield buttons

In Civ VI, districts occupy map tiles and create population gates: specialty districts are available at population 1, 4, 7, then every three additional population. Buildings sit inside the district and arrive in tiers. A Campus can lead from Library to University to Research Lab; an Encampment has military buildings; a Harbor has naval buildings. Placement adjacency and limited district slots create opportunity cost. [District rules](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/) and [building rules](https://www.civilopedia.net/en-US/gathering-storm/buildings/).

District costs also scale with progress. The commonly documented formula is `base cost × (1 + 9 × max(technology-tree proportion, civic-tree proportion))`; the standard base for most districts is 54 production. A district is often placed before it is finished, locking an earlier cost and making timing matter. [District cost reference](https://civilization.fandom.com/wiki/District_%28Civ6%29).

CivCraft currently has 39 buildings/projects with local prerequisites, but all city slots are effectively unlimited and every city can pursue the same flat sequence. The effects are often understandable—Library +2 science, Furnace +2 industry, University +4 science, Steam Plant +6 industry—but a player rarely gives up one specialization to obtain another. This makes late buildings feel like an accelerating checklist. The first structural fix should be soft specialization: each city gets a limited number of “focus slots” or districts, while a small set of universal maintenance buildings remains available everywhere. A Campus-equivalent “research bench,” Create-equivalent “works,” rail/logistics and defense focus should compete for the same slots. This is enough to create choices without reproducing Civ VI's full placement UI.

### 4. Units have roles, upgrade continuity and congestion

The Civ VI catalog exposes explicit upgrade paths, production costs, strategic-resource costs and maintenance. For example, a Swordsman costs 90 production, 20 Iron on Standard speed and 2 Gold maintenance, and upgrades to Man-at-Arms and several unique equivalents; it upgrades from Warrior and unique predecessors. A Library costs 90 production, yields +2 Science, provides a citizen slot and a Great Scientist point, and requires a Campus and Writing. [Swordsman](https://www.civilopedia.net/en-US/gathering-storm/units/unit_swordsman/) and [Library](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_library/).

That continuity gives a player a reason to build an early army: it can be upgraded rather than discarded. Unit roles also remain distinct—melee holds ground, ranged supports, siege attacks defenses, mounted units exploit movement, and support units alter the odds. City and unit congestion further constrain armies: at most one combat, one support and one non-combat unit can occupy a city tile at the end of a turn. [Official manual](https://cdn.steamstatic.com/steam/apps/289070/manuals/CIV_VI_25TH_ONLINE_MANUAL_ENG.pdf?t=1636653176).

CivCraft has 25 recruitable units, but they are mostly independent technology unlocks. It has no general upgrade/equipment ladder, so a Stone Guard can become obsolete when Iron Swordsman or Diamond Swordsman arrives. The baseline combat fixture makes the gap visible: an Iron Swordsman deals 80 damage to a Stone Guard while the Stone Guard deals 16 back under the current formula. That is a useful technology payoff but an abrupt replacement pressure. The recommended adaptation is two or three upgrade families—Guard, Ranged, Mounted/Naval—with an upgrade cost in industry plus material, preserving veteran experience and giving early production a longer horizon. Keep Minecraft identity by making the upgrade an equipment refit: iron-to-diamond, Create mechanisms, brass armor, rail logistics and Netherite.

The current CivCraft resource rule is also more brittle than Civ VI's: every resource-gated recruit consumes two material on completion, while gold upkeep is a per-round rate. This makes a rare deposit or one exchange purchase decide whether a unit is available at all. Split “access,” “per-unit build cost” and “per-turn consumption”; let a modest stock shortage increase cost or disable advanced production after a grace period rather than deleting the whole branch.

### 5. Counterplay is built into the content graph

Civ VI does not balance a unit only against its direct predecessor. Terrain, districts, city defenses, strategic resources, roads, trade routes, governments, policy cards, diplomacy and victory pressure all create counters. A player who loses an early fight can still defend behind a city, change production, trade for a resource, pursue another victory, or use a different terrain and diplomacy plan. This is why the game can tolerate large local advantages without every lead becoming an immediate game over.

CivCraft already has useful counterplay primitives: walls, ranged fire, zone of control, escorts, villages, rails, hostile mobs and a Council. The main weakness is that several are late or route-specific. A city can be safe from mobs because mobs cannot capture it, but an enemy army can still convert a large technology lead into a decisive combat gap. Bring one defensive response into each age: early walls/terrain defense, mid-game ranged and supply, Create-era siege/rail logistics, late-game airship or long-range counterplay. Every expensive victory project should expose at least one visible counter window (raid its supply, interrupt its network, attack its staging city, or force a diplomatic response).

## Direct comparison by phase

| Phase | Civ VI pacing mechanism | CivCraft evidence | Diagnosis | Direction |
|---|---|---|---|---|
| Opening | Separate science/culture choices, boosts, population gates, settlers and terrain-dependent placement | Standard start is science 1 for most civs and 3 for Scholar; Agriculture takes 24 turns for most and 8 for Scholar in the measured seed; growth is 12 turns; Farm is unavailable until Agriculture; a Settler costs 12 industry and takes 3 turns at 5 industry | Scholar's +2 city science is an enormous early clock change; non-Scholar opening has a long research wait before its first food infrastructure | Normalize the first research horizon, then differentiate civs through conditional yield or boost quality; make one early food/industry choice available before a long research lock |
| Expansion | Settler cost and city/district limits create a build-versus-grow trade-off; new cities add both yield and management burden | Settler base cost starts at 12 and gains +5 per completed settler; no district/population slot pressure | Expansion can be the obvious answer whenever a city has spare industry; tall development lacks a comparable opportunity cost | Add soft city focus slots and a founding-cost curve tied to empire size, while preserving a viable two-to-four-city tall line |
| Midgame | District adjacency, building tiers, civic policies, upgrades and strategic resources force specialization | Six-age tech graph branches into Create, trade, military and End, but buildings are flat city lists and unit generations do not upgrade | Many choices are “unlock everything eventually”; midgame can become a prerequisite queue | Introduce branch proofs, specialization slots and upgrade families; give each branch one counter and one cross-branch benefit |
| Endgame | Future technologies, projects, victory races and late resource/power systems provide competing clocks | Steam, rail, Industrial, End and Naval branches are present; one native Forge mirror reached Industrial victory at round 149 of 180 | Endgame is reachable and measurable, but an Industrial route may terminate before the End branch becomes strategically relevant; this is one fixture, not a general claim | Gate victory readiness behind a visible contest window; preserve conditional route viability rather than forcing equal win shares |

## Specialization, repeatables and “pointless” content

Civ VI's late game is not balanced by making every building equally efficient. It uses a mix of differentiated buildings, limited slots, adjacency, power, projects and victory-specific investments. Some items are intentionally situational; their value depends on map, leader, resource access and opponent pressure. The useful design test is therefore not “does every item get built?” but “does the item create a credible response or opportunity in at least one common state?”

CivCraft should use three content classes:

1. **Milestone unlocks**: units, buildings and technologies that change what actions are legal.
2. **Specialists**: mutually competing city focuses with strong, legible payoffs (research, Create industry, rail commerce, defense, food, naval or diplomacy).
3. **Repeatables**: late projects that convert excess industry into science, materials, defense, influence or victory progress with diminishing returns.

Repeatables must have an opportunity cost and a counter. A “Ponder” project that simply gives unlimited science will recreate the same runaway as an oversized Library chain. A better repeatable might consume power or materials, add a small amount of progress, and compete with rail maintenance, unit refits and victory projects. Keep the number of repeatables small enough that the player can understand why one is chosen.

## Opening, midgame and endgame recommendations

### Opening: make the first 20 turns legible

The measured non-Scholar start produces 1 science and needs 24 science for Agriculture, while Scholar produces 3 science and reaches it in 8 turns. That is a large faction identity before map, scouting or player skill has had time to matter. Reduce the discontinuity by giving every civilization a comparable first research horizon—roughly one short early technology—then move the asymmetry into what the boost does, what terrain it prefers, and how the second and third technologies compound.

Expose a meaningful early fork: food improvement, scouting/naval access, or defense/industry. Do not make a Farm invisible until Agriculture if the opening is expected to contain a food decision. Keep the current 12-cost Settler as a tested baseline, but make the second city compete with the first city's focus slot and with an early defensive unit.

### Midgame: make branches interact

The Create content is strongest when a chain is physical and intelligible: press, mixer, brass, assembly, steam, rail. Preserve that identity, but connect each chain to at least one non-industrial pressure. Rail should improve movement and trade while also requiring protection. Research buildings should improve science while consuming a focus slot or power. Military buildings should improve unit refits and defense, while delaying a civilian project. A player should be able to pivot, but the pivot should have a visible cost.

Research switching currently retains progress, which is forgiving, while research and production overflow are discarded on completion. Retained progress is a good mistake-tolerance rule; discarded overflow makes high-yield turns feel wasted and creates awkward queue timing. Preserve progress and add a bounded overflow bank—perhaps 25–50% of the completed cost—that can apply only to the next item in the same category. Validate that it helps recovery without enabling one-turn chains.

### Endgame: create a race before the finish line

CivCraft's Industrial victory requires three Industrial Complexes on one connected station network for ten consecutive Standard rounds, speed-scaled by `Rules.cost`. The End victory requires the ordered Staging Ground, Eyes, Equipment and Dragon projects in one city. The Council route requires a Stock Logistics technology, Council Hall, delegate threshold and another civilization's support. Conquest requires every original rival capital. These are meaningfully different, and the implementation should keep them conditional: each route should be viable when its map, civ and diplomatic context support it, but no route should be guaranteed or required to win every match.

The key missing piece is a visible contest period. When a player begins the final Industrial, End or Council step, opponents need enough information and time to respond. Use progress notifications, espionage-like visibility from scouts/villages/Council, and route-specific disruption. A route that can be countered should still be able to finish if the leader planned protection; a route that cannot be seen or interrupted is a private timer, not a strategic victory.

## Faction asymmetry and fairness

Civ VI uses unique units, buildings, abilities and leader agendas to change preferred decisions while retaining shared fundamentals. A faction can be best on a coast, near a resource, in a particular diplomatic situation or on a certain victory route; it does not need equal performance in every condition. This is a better target for CivCraft than equal aggregate win shares.

CivCraft's ten identities are strong and thematic—villagers, miners, scholars, nomads, mariners, engineers, highlanders, merchants, sentinels and rangers—but some bonuses affect the opening economy directly. Scholar's city science bonus is the clearest measured example. Test each identity with mirror matches, seat rotations, map families and matched opponent policies. Report conditional viability: “this civ has a credible science route on research-rich maps and a credible defensive route elsewhere,” rather than “each civ must win 10% of all games.”

The acceptance target should be a matchup matrix with uncertainty intervals, not a forced share. A route or civ is healthy when competent play can reach it in an appropriate context, opponents can identify and counter it, and a moderate mistake lowers the chance without making recovery impossible. A route is unhealthy when it dominates across map families, requires a single irreplaceable deposit, or becomes impossible before the player can know the route was lost.

## Prioritized plan

1. **Instrument the baseline before changing values.** Run seeded 2–4 player matches on all map presets with mirrors, rotated seats and at least expansion, science, Create-industry, military and diplomacy policies. Record turn of Agriculture, first city, first contact, first war, each age, first advanced unit, final-project start, route interruption and victory. Preserve replay seeds and separate native CraftOS results from historical Lupa snapshots.
2. **Fix the first-clock discontinuity.** Calibrate opening science, food access and Scholar's bonus against a target first expansion/research window. Add an early optional boost proof and verify that the first 20 turns still contain scouting, city staffing, production and defense decisions.
3. **Add soft city specialization.** Implement focus slots or equivalent categories in the authoritative engine. Reprice buildings only after the slot model is measured; otherwise a cost change may hide the real lack of opportunity cost.
4. **Add upgrade families and resource grace periods.** Preserve veterans, charge a refit cost, distinguish stock access from per-unit cost and prevent one missing deposit from deleting a whole strategic branch.
5. **Add a small repeatable-project layer.** Each repeatable must consume an input, compete with another project and expose a counter. Add production/science overflow banking with a bounded cap and measure whether it reduces feel-bad turns.
6. **Make victories observable and interruptible.** Keep conquest, Industry, End and Council as conditional routes. Add route progress to the ledger and event feed, and define at least one credible disruption for every final step. Do not force equal raw win shares.
7. **Re-evaluate AI after mechanics.** Difficulty should improve planning and counterplay under the same rules. Run fixed and adapted policies after each systemic change; otherwise an unchanged AI can make a good redesign look weak or a bad redesign look balanced.

## What to adopt, adapt and reject

Adopt Civ VI's multiple clocks, active research proofs, upgrade continuity, role-based units, constrained specialization, visible victory races and route counterplay. Adapt them to Minecraft resources, Create production chains, villages, rails and small-screen UI. Reject direct cost copying, a full civic/policy clone, a large district-placement interface, unbounded late-game modifiers and any automatic balance decision based on one AI or one map. CivCraft's success criterion is a readable, replayable Minecraft 4X whose routes remain conditional, interactive and recoverable under strong play.

## Sources and limits

- [Civ VI Gathering Storm Civilopedia index](https://www.civilopedia.net/en-US/gathering-storm/)
- [Civ VI technologies](https://www.civilopedia.net/en-US/gathering-storm/technologies/), [civics](https://www.civilopedia.net/en-US/gathering-storm/civics/), [units](https://www.civilopedia.net/en-US/gathering-storm/units/), [buildings](https://www.civilopedia.net/en-US/gathering-storm/buildings/), [districts](https://www.civilopedia.net/en-US/gathering-storm/districts/), [wonders/projects](https://www.civilopedia.net/en-US/gathering-storm/wonders/)
- [Civ VI Civilopedia: districts](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/), [Eureka moments](https://www.civilopedia.net/en-US/gathering-storm/concepts/science_3/), [science victory](https://www.civilopedia.net/en-US/gathering-storm/concepts/victory_3/), [official online manual](https://cdn.steamstatic.com/steam/apps/289070/manuals/CIV_VI_25TH_ONLINE_MANUAL_ENG.pdf?t=1636653176)
- [CivCraft current inventory](../civ6-balance-2026-10-26/CIVCRAFT-INVENTORY.md)
- [CivCraft measured baseline](../civ6-balance-2026-10-26/civcraft_measurements.json)
- [CivCraft content export](../civ6-balance-2026-10-26/civcraft_content.json)

The Civilopedia is a player-facing reference and can contain legacy or mode-specific descriptions. The current CivCraft native fixture is too small to establish civilization win rates, comeback probabilities, route viability or a universal ideal victory round. Those claims require the simulation laboratory and matched policy evaluations described above.

Opening-clock evidence note: 24 science / one starting science is a frozen-income
anchor, not the actual technology completion time of a growing empire. The
[paired opening study](RECOVERY_OPENING_REPORT.md) records two cities and two
science by round three in one ordinary AI continuation. Cheap expansion and
research pace must be considered together.
