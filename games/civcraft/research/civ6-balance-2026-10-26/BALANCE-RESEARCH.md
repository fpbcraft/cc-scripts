# CivCraft balance research and proposed pacing plan

Date: 26 October 2026. Baseline: `codex/civcraft-roadmap`, commit `c5d7e4dfb7538b1f164d36fcb08946f250179c6e`. This is research and a proposed design, with no gameplay changes. The user's priority is the satisfying opening of Civilization VI: actions matter, rewards arrive at the right time, and choices have consequences. Detailed Civ VI equivalents are used throughout.

**Follow-up scope and revised priority:** the user also requests endgame/victory and faction balance, fewer purposeless units, more meaningful production choices, and cities that feel specialized like Civ VI. See [the specialization, factions, armies, and victory study](SPECIALIZATION-FACTIONS-VICTORY.md). It advances real city specialization and repeatable productive work into the core design pass, and replaces the recommendation to keep three identical Industrial Complex cities as the industrial goal. The opening experiment below remains useful, but is no longer the complete first design milestone.

## Recommendation

Rebalance the first 30–40 rounds before expanding content or rewriting the entire economy. CivCraft's main opening problem is the relationship between its clocks: it can create units and new cities much faster than it unlocks its first economic choices. Later, empire-wide science can reverse that relationship and outrun individual cities' production. A global speed multiplier cannot fix both.

The first prototype should align scouting, production, growth, research, and expansion; reduce the extreme early Scholar advantage; preserve overflow; and create several viable opening sequences. Then tune military lifetimes, infrastructure roles, and victory timing using the same measures.

These are design hypotheses supported by current rules and small measurements, not a validated claim that the proposed numbers are balanced. Civ VI is a useful reference for this particular experience, not proof that every one of its systems is balanced or should be copied.

## Evidence and data coverage

- [Civ VI catalog](civ6_gathering_storm_catalog.json): all entries indexed in the public English Gathering Storm technology, civic, unit, building, district, and Wonders/project sections. Includes unique and optional-mode content; an indexed entry is not necessarily active in an ordinary game. Per-entry URLs identify the source. See [catalog methodology](README.md).
- [CivCraft runtime content](civcraft_content.json) and [readable inventory](CIVCRAFT-INVENTORY.md): 45 technologies, 25 recruitable units, five hostile unit types, 39 buildings, six world wonders. Runtime evaluation avoids undercounting multiline declarations.
- [Native measurements](civcraft_measurements.json), reproduced with [the measurement harness](measure_civcraft.lua): current functions in an isolated CraftOS-PC 2.8.3 profile. Seeded start samples and combat calculations, rather than an interactive human campaign.
- Existing [AI benchmark](../../AI-BENCHMARK.md) and its [CSV](../../AI-BENCHMARK.csv): useful historical evidence from this checkout, separately identified from fresh measurements. These are varied AI matchups, not a controlled test of civilization bonuses.
- Fresh [full-duration native fixture](civcraft_full180_prince.lua) and [raw results](civcraft_full180_prince.json): seed 75123, Compact/Pangaea, Forge versus Forge, Prince, hostiles off, 180-round limit. Industrial victory occurred on round **149**. One player reached Iron/Redstone/Rotation/Brass/Steam on rounds **24/58/78/97/121**; the other on **26/60/80/102/127**. Both seat reports describe the same deterministic mirror matchup, not two independent samples.

That fresh match is a useful restraint on the redesign: CivCraft can already deliver a functioning industrial arc within the existing deadline. Preserve that working outcome. The evidence supports fixing the opening and specific content lifetimes first; it does **not** support globally multiplying later research costs or asserting that every campaign runs out of time.

The Civ VI reference is a public Civilopedia snapshot, **not a verified final-patch merged Gameplay.sqlite database**. No installed Civ VI copy was found in the checked Steam common directory. The catalog cannot establish every hidden modifier, policy interaction, discount, cost escalation, or executable formula. Base costs are not necessarily actual in-game costs. Future-era randomization, unique replacements, optional modes, starting era, game speed, resource requirements, and difficulty all matter. Full parity work would require exporting the merged database from a licensed installation with an explicit DLC/ruleset manifest. This limitation does not prevent the opening comparison below.

## Why the Civ VI opening feels satisfying

This section is design interpretation grounded in the cited mechanics, not a claim of access to Firaxis's internal balance targets.

### 1. A small menu contains competing investments

Civ VI's early units have distinct functions and substantial relative prices. A Scout costs 30 production, a Slinger 35, a Warrior 40, a Builder 50, and a Settler 80 before cost escalation or modifiers. The Scout moves three tiles, a Warrior two, and the Builder supplies three improvement charges. A Settler removes one population when completed. Thus information, safety, economic improvements, and another city compete for several rounds of the same city's production. Sources: [Scout](https://www.civilopedia.net/en-US/gathering-storm/units/unit_scout/), [Slinger](https://www.civilopedia.net/en-US/gathering-storm/units/unit_slinger/), [Warrior](https://www.civilopedia.net/en-US/gathering-storm/units/unit_warrior/), [Builder](https://www.civilopedia.net/en-US/gathering-storm/units/unit_builder/), [Settler](https://www.civilopedia.net/en-US/gathering-storm/units/unit_settler/).

Normalize against a Warrior rather than comparing raw production between games:

| Investment | Civ VI base production | Civ VI / Warrior | CivCraft base industry | CivCraft / Stone Guard | Implication |
|---|---:|---:|---:|---:|---|
| Scout | 30 | 0.75 | 5 | 0.38 | Information is unusually cheap in CivCraft. |
| Basic defender | 40 | 1.00 | 13 | 1.00 | Current reference point. |
| Initial ranged defender | Slinger 35 | 0.88 | Archer 25, requires Bow Crafting | 1.92 | CivCraft has no equivalent immediately available weak ranged unit. |
| First Settler | 80 | 2.00 | 12 | 0.92 | Another city costs less than a replacement guard. |
| Economic field work | Builder 50, three charges | 1.25 | No direct unit equivalent | — | Farm/Quarry are city buildings; compare total investment and yield, not names. |

CivCraft's Settler is also faster: three movement versus Civ VI's two. Its completed city starts with two population and its source city loses none. Its +5 cost step already exists and must not be described as absent. Together, cheap production, fast travel, no source-population loss, and two immediately available workers make the expansion package disproportionately generous.

### 2. Exploration changes the next choice

In Civ VI, meeting another civilization boosts Writing; a coastal settlement boosts Sailing. A Builder's limited charges turn the discovered resources into a decision about which tiles to improve first. This creates a sequence: discover something, change the plan, take an action, receive an earlier unlock. [Writing](https://www.civilopedia.net/en-US/gathering-storm/technologies/tech_writing/), [Eureka concepts](https://www.civilopedia.net/en-US/gathering-storm/concepts/science_3/), [Builder](https://www.civilopedia.net/en-US/gathering-storm/units/unit_builder/).

CivCraft already has useful ingredients: worked tiles, discoverable villages, hostile camps, strategic deposits, and city sites. However, research is almost entirely passive yield accumulation. Scouting can reveal an exciting opportunity without bringing the relevant economic technology closer. The problem is a missing action-to-progression link, not a lack of map features.

### 3. Growth, research, and production make each other useful

Civ VI's Library is not merely +2 science for 90 production. It requires Writing and a Campus, adds a scientist slot and a Great Scientist point, and shares production with defenders and expansion. The Campus has terrain-dependent adjacency and a base 54 production cost that can differ from its actual cost. Specialty district capacity increases at population 1/4/7, making growth relevant to specialization. [Library](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_library/), [Campus](https://www.civilopedia.net/en-US/gathering-storm/districts/district_campus/), [district capacity](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/).

CivCraft's Library costs 23 industry, grants the same flat +2 science, requires Books & Maps, and has no district, maintenance, specialist, or Great Person layer. It is much simpler, appropriately for the game, but triples a typical city's science from 1 to 3. Consequently, its unlock is a much larger relative breakpoint than its modest price suggests.

### 4. Unlocks retain value long enough to act on them

Civ VI explicitly has unit upgrade chains: Warrior → Swordsman → Man-at-Arms, for example. Its Warrior has strength 20; the Swordsman has strength 35, costs 90 production and 20 iron on Standard, and pays two gold maintenance. Existing military investment can remain useful through upgrades. [Warrior](https://www.civilopedia.net/en-US/gathering-storm/units/unit_warrior/), [Swordsman](https://www.civilopedia.net/en-US/gathering-storm/units/unit_swordsman/), [Man-at-Arms](https://www.civilopedia.net/en-US/gathering-storm/units/unit_man_at_arms/).

CivCraft has experience levels but no general equipment-upgrade action. A newly unlocked unit may take several rounds to build and travel, while empire science continues toward its replacement. Retaining useful military windows is as important as making research faster.

## What the current opening actually permits

On the measured Standard/Continents start at seed 12345, an ordinary one-city faction produces 7 food, 5 industry, and 1 science per round. Two population consume four food, leaving three surplus. A Scholar start has the same food and industry but three science. These are specific start samples, not universal map averages.

| Milestone or choice | Current ordinary faction | Current Scholar | What matters |
|---|---:|---:|---|
| Scout, if selected immediately | 1 production round | 1 | Cost 5; little competing investment. |
| Stone Guard | 3 production rounds | 3 | Cost 13; no carry of the final round's excess. |
| First Settler | 3 production rounds | 3 | Cost 12; no population lost. Travel and founding are additional. |
| First 24-science technology | 24 research rounds | 8 | Assumes unchanged science and no village/natural-wonder benefit. |
| First growth, unchanged workers | 12 rounds | 12 | Threshold 36 food, surplus three. |
| Wheat Farm, **after** Wheat Farming | 3 production rounds | 3 | Cost 15, +2 food. Its build time does not include the research gate. |

This is a strong diagnosis of the timing mismatch. Before an ordinary faction finishes its first technology, it can potentially produce multiple scouts, guards, or settlers. Those units may be useful, but city development offers few alternative choices. Scholar reaches the economic menu three times sooner. Increasing the overall game length leaves that opening relationship unchanged.

The generated start also repairs nearby terrain to provide grain and an iron hill. That guarantees useful tiles, but should be checked for a dominant worker assignment. The first meaningful choice should not require knowing an obscure worker optimization, nor should all seeds force an identical build order. [World generation](../../worldgen.lua), [worker and yield rules](../../systems.lua).

## Detailed equivalent-by-equivalent improvements

All proposed values below are **prototype inputs**, not demonstrated optima. Standard speed is the calibration baseline.

### A. Opening research: shorten the wait and narrow civilization extremes

**Civ VI equivalent:** opening technology costs and action boosts. Animal Husbandry costs 25 science; Writing costs 50 and is boosted by meeting another civilization. This already differentiates first-tier and follow-on research instead of pricing everything in one era identically. [Animal Husbandry](https://www.civilopedia.net/en-US/gathering-storm/technologies/tech_animal_husbandry/), [Writing](https://www.civilopedia.net/en-US/gathering-storm/technologies/tech_writing/).

**CivCraft diagnosis:** all six Survival technologies cost 24; ordinary center science is one, while Scholar adds two in **every** city. This is an opening-system advantage, not just a modest specialist bonus.

**First prototype:** raise ordinary city-center science to two. Keep initial core technologies around 20–24 science, with per-node prices. Change Scholar from +2 per city to +1 in the capital initially; evaluate a later conditional bonus from Libraries/Ponder infrastructure. At unchanged starting yields, a 24-cost technology becomes 12 rounds for ordinary factions and eight for Scholar, instead of 24 versus eight. Do not simultaneously add generous boosts and halve costs; measure this change first.

**Second prototype:** introduce one-time 25–30% boosts on selected nodes, visibly listed before the player selects research. Useful examples are discovering a village for Books & Maps; winning a battle for Bow Crafting; working a grain tile for several rounds for Wheat Farming; and establishing two complementary production buildings for a Create technology. These percentages are deliberately proposed CivCraft values, not an assertion about the exact Civ VI boost percentage. Avoid circular tasks requiring the building the technology itself unlocks, impossible resource requirements, repeatable exploits, or hidden retroactive eligibility.

**Success measure:** common first useful technology in 8–12 Standard rounds; Scholar retains a lead without turning the opening into a different game. Scouting should sometimes change the preferred research, not always trigger the same optimal quest route.

### B. Opening production: restore a real expansion decision

**Civ VI equivalent:** Scout 30 versus Warrior 40 versus Settler 80, with Settler population consumption. Those ratios make leaving a capital undefended or postponing infrastructure consequential. Civ VI's Builder 50 also makes economic improvement an investment before its benefits appear. [Opening unit sources](https://www.civilopedia.net/en-US/gathering-storm/units/unit_settler/).

**CivCraft prototype:** test Scout 15, Stone Guard 20, Settler 40 plus 12 per trained Settler. At five industry these take 3/4/8 production rounds, respectively. The new ratios are 0.75/1/2, matching the reference roles without importing Civ VI's absolute scale. Test a population gate separately: training a Settler requires three population and completion removes one; new settlements start at one population. Because CivCraft begins at population two, this is an adaptation of Civ VI's population tradeoff rather than an exact copy. AI, starvation, blocked completions, captured settlers, and legacy saves must be considered together.

Provide an immediate economic alternative. A no-tech Crafting Hall at approximately 20 industry and +1 industry gives a four-round local investment with a 20-round simple production payback. Rework the Crafting technology to unlock a distinct follow-on recipe or enhancement; do not leave an empty research node. Keep Wheat Farm/Quarry research gates initially so their first unlock has a visible payoff. A separate immediate Farm prototype can be tested later, but would require redesigning Wheat Farming's reward.

**Success measure:** an opening Scout-first sequence, defense-first sequence, and economic-first sequence each wins on an appropriate map/threat setting. A second city commonly arrives around rounds 18–30 after growth, training, and travel; an aggressive expansion opening may beat that at a meaningful cost. This is a target distribution, never a mandatory scripted turn.

### C. Growth and tile work: preserve what already synchronizes

**Civ VI equivalent:** population works tiles, Settlers sacrifice population, and housing constrains growth. A Granary gives food/housing rather than simply being another production multiplier. [Granary](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_granary/), [housing](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_14/).

**CivCraft diagnosis:** growth costs `20 + 8 × population`, consumes two food per citizen, and has a four-round minimum at Standard. The measured 12-round first growth is already close to a useful first research window. Do not slow it indiscriminately. The Farm's +2 food can change surplus three to five and is therefore strategically significant, even though food cannot be valued as industry at a 1:1 exchange rate.

**Proposal:** keep the initial growth formula in the first experiment. Show the next citizen's usable tile and the resulting yield change. Compare growth with defense/settlement timing; tune only after expansion changes. Audit whether newly grown citizens are assigned food-heavy tiles despite a player's production intention. Add housing or city capacity only if measured late-game growth demands it; importing a new constraint is not necessary to improve the opening.

### D. Scouting, villages, and hostile camps: connect information to action

**Civ VI equivalent:** discovery affects research boosts, city placement, and City-State relationships; a weak early ranged unit and upgrade path let military exploration develop into defense. [Eurekas](https://www.civilopedia.net/en-US/gathering-storm/concepts/science_3/), [Slinger](https://www.civilopedia.net/en-US/gathering-storm/units/unit_slinger/).

**CivCraft diagnosis:** Scouts cost five, move four, and see four; early exploration is cheap and fast relative to research. Clearing a camp awards 25 gold. A village envoy also costs 25 gold, provides ten influence, and has a five-round cooldown; an alliance requires 40 influence and gives +2 food/industry/science depending on village type. That is already a potentially good camp → diplomacy → economic payoff chain, but its travel, combat, cooldown, and contestability need measurement. A Librarian village's +2 science is especially large beside ordinary center science of one. [Hostiles](../../hostiles.lua), [villages](../../villages.lua).

**Proposal:** first test the higher Scout price, keeping movement unchanged. Measure rounds to first discovery, first promising city site, first camp engagement, and first village benefit. Add optional discovery/defense boosts and small village tasks that reward existing actions. Avoid guaranteeing a powerful free reward next to every start. Consider an early weak ranged role only if defense-first lacks a distinct choice; do not add a unit simply to complete a Civ VI checklist.

### E. Military progression: prevent equipment cliffs and premature obsolescence

**Civ VI equivalent:** Warrior strength 20, Swordsman strength 35; unit classes, upgrade paths, iron costs, and maintenance accompany the improved unit. CivCraft's similarly named unit should be compared by effective combat power and lifetime, not the small number printed in `strength`.

**CivCraft measurement:** base power is `10 + 5 × stat`, before levels, health, and terrain. Stone Guard attack/defense 2/2 becomes 20/20. Iron Swordsman 7/5 becomes 45/35. The exponential damage rule makes the Swordsman's initial open-field hit reach the 80-HP cap; an independent Stone Guard attack against a full-health Swordsman deals 16. These are separate full-health calculations; retaliation during an actual battle depends on which unit attacked and the combat resolver.

**Proposal:** use a narrower early power ladder, initially testing Iron Swordsman around effective attack 30–35 rather than 45, and audit Shield Guard/Horse Rider/city defense at the same time. Keep terrain, focus fire, and counters valuable. Add paid equipment upgrades in owned territory, preserving XP and costing gold plus the appropriate materials; spend the unit's activation. Publish explicit upgrade paths in content. Do not make all units obsolete automatically if an old cheap defender still has a valid role.

**Success measure:** a normal full-health early battle needs several activations, and the next equipment tier gives a decisive advantage without erasing all positioning. A newly unlocked core unit should normally allow training, travel, and several useful turns before its replacement becomes available. Target about 15–25 rounds of practical relevance initially; measure against map size rather than enforcing a global minimum-age timer.

### F. Research curve: preserve deployment time as empires grow

**Civ VI equivalent:** research costs rise substantially: Animal Husbandry 25, Writing 50, Education 390, Chemistry 1,370 science. Buildings also progress from Library +2 science to University +4, with prerequisites and wider system costs. These selected examples illustrate a curve; they are not an instruction to copy a 54.8× multiplier into CivCraft. [Education](https://www.civilopedia.net/en-US/gathering-storm/technologies/tech_education/), [Chemistry](https://www.civilopedia.net/en-US/gathering-storm/technologies/tech_chemistry/), [University](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_university/).

**CivCraft diagnosis:** costs rise only from 24 to 130, approximately 5.4×. All 45 technologies total 3,150 science. A three-city empire with Libraries alone contributes nine science before extra tiles, faction bonuses, or later buildings; three Scholar cities with Libraries contribute 15. Expansion accelerates every technology, while a unit still builds in only one city.

**Proposal:** per-node role-based costs, calibrated against expected empire science and the desired decision interval. Use `cost ≈ expected science per round × intended research rounds`, then include plausible boosts and integer rounding. Begin with Survival 20–24, retain later base costs for the first opening experiment, and measure how the new science floor affects downstream milestones. Only increase a particular later node or branch when its unlocks demonstrably outpace deployment or useful investment. The successful round-149 industrial baseline is a reason to reject an untested global steepening of the curve. Critical deployment nodes, optional tactical counters, and terminal victory research should not necessarily share one flat price. Keep branches; do not require every technology for every victory.

### G. Buildings: replace filler with decisions and visible payoffs

**Civ VI equivalents:** Library +2 science/90 production plus Campus; Workshop +3 production/195 plus Industrial Zone; University +4 science plus housing/specialist/Great Scientist functions. Not every building is a pure flat-yield purchase. [Workshop](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_workshop/), [Library](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_library/), [University](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_university/).

| CivCraft item | Current cost / benefit | Relevant comparison | Proposed direction |
|---|---|---|---|
| Wheat Farm / Animal Pens | 15/22, each +2 food | Builder farms and Granary solve distinct tile/growth constraints | Keep an accessible growth investment; give Pens a husbandry/resource or population role so it is more than the same purchase at a higher price. |
| Quarry / Furnace | 18/25, each +2 industry | Mines improve worked terrain; Workshop adds infrastructure | Differentiate extraction from processing, or acknowledge an intentional repeatable yield tier. Quarry is nine-round simple payback; Furnace 12.5. |
| Crafting Hall / Belt Workshop | 15/30, each +1 industry | Early development versus a later specialized production chain | Give Hall the immediate opening role; make Workshop change Create production, not merely add a slower +1. Forge's extra +2 must be included in testing. |
| Library | 23, +2 science | Civ VI Library needs the Campus and other investments | Keep readable and useful, but retune after the science floor change; do not triple every city's science at negligible local cost. |
| Smithy | 35, +1 industry; Furnace required | Military production/upgrade infrastructure | Make it an actual equipment upgrade or military production enabler. Its 35-round pure industry payback is weak without the late Netherite gate. |
| Water Wheel / Windmill | 35, +2 industry / 45, +2 food +2 industry | Terrain-specific infrastructure changes city plans | Use river/coastal/terrain suitability or distinct city roles. Avoid mandatory terrain hard locks without alternatives. |
| Press / Crusher / Belt Logistics | 45/55/50, +3/+3/+2 industry | Civ VI infrastructure has prerequisites and specialization | Assign pressing equipment, material processing, and logistics distinct benefits; optional leaves need contextual payoff, not universal mandatory construction. |
| Portal / Redstone Workshop / Enchanting Room | 45/40/38, +2/+2/+3 science | Science chains and active-research prerequisites | Preserve themed enablers, but avoid a long sequence of near-identical passive science purchases. |
| Mixer | 60, +2 industry; converts copper+zinc to brass after research | Gathering Storm strategic resource flows | Retain conversion identity; explain input deficits and whether production is actually needed. |
| Assembly / Crafter / Steam Plant | 80/90/100, +4 industry +2 science / +5 / +6 industry | Industrial infrastructure should change productive capability | Keep the payoff large enough to arrive before victory; differentiate equipment assembly, bulk crafting, and power. |
| Station / Freight Depot | 65, conditional network +2 industry/+2 gold / 80,+4 gold | Trade/logistics investments need functioning routes | Show reachable connection and total route cost before construction. Freight should contribute to throughput or a concrete goal. |
| End Archive | 90, +6 science at final End research | Civ VI Research Lab appears before later research goals | Move earlier or give research a repeatable victory contribution. It can help unfinished branches/Score today, but is poorly aligned with an expedition rush. |
| Dock / Walls / Fortress / Council Hall | Conditional unit, defense, or victory enablers | Civ VI military, naval, and diplomatic infrastructure is conditional too | Keep situational roles; zero economic yield alone is not evidence of uselessness. Display payoff and avoid irrelevant AI builds. |

For pure industry buildings, `production cost / extra industry` is a useful first payback screen, not a complete return calculation. Food and science cannot be converted to industry by the same formula. Use simulated extra citizens, earlier unlocks, avoided losses, and victory progress. Count prerequisites, travel, and the remaining game horizon. A good defensive building can repay immediately by preventing a capture even with zero yield.

### H. Gold, materials, and support units: make the alternatives matter

**Civ VI equivalent:** the Swordsman's production, gold maintenance, and iron requirement are separate fields; late resource maintenance is a different mechanic from upfront material cost. Gold can purchase production items, and upgrade paths preserve earlier units. [Swordsman](https://www.civilopedia.net/en-US/gathering-storm/units/unit_swordsman/), [spending gold](https://www.civilopedia.net/en-US/gathering-storm/concepts/gold_3/), [consumable resources](https://www.civilopedia.net/en-US/gathering-storm/concepts/consumeable_resources/).

**CivCraft diagnosis:** upkeep is derived from unit production with `ceil(cost/30)`; specialized recruits all cost two of their material. Controlled deposits generate one per round without requiring the corresponding tile to be worked or a local extraction building. A single deposit can therefore generate the material for a recruit every two rounds, often faster than production can consume it. Gold income starts at `2 + population` per city; there are no direct production purchases, though village envoys, diplomacy, material exchange, and upkeep already provide uses.

**Proposal:** make upkeep and material costs explicit balance fields independent of production. Give advanced equipment an appropriate upfront bill and some late machinery a modest ongoing supply need, with visible trade alternatives. Add equipment upgrades before universal gold-buying. Keep the opening simple: do not introduce maintenance pressure so severe that the first Scout causes disbanding. Engineer → Armored Engineer → Railway Engineer should be an upgrade lineage or genuinely distinct jobs; all currently build the same rails after Railways. Alchemist/Supply Crew both use the same +10 adjacent healing rule in friendly territory; either upgrade one into the other or give the later unit an expedition/supply role.

### I. Railways and victory: preserve a payoff for the economy

**Civ VI equivalent:** scientific victory connects research to production projects, and specialized infrastructure has to serve an actual end goal. The public concept mirror contains legacy text, so this report does not use it to assert exact final Gathering Storm project timings. The catalog's individual project entries are the better reference for displayed base costs.

**CivCraft diagnosis:** the End route ends with sequential 140/180/240-industry projects in one city. Industrial requires three connected cities with Industrial Complexes and ten qualifying Standard rounds. Rails cost two iron per segment, consume an engineer's movement, require owned territory, and must include each station's center tile. Border expansion is passive and unscaled by speed. Distant territories or islands can make a chosen industrial route unavailable, despite ample research and industry.

**Proposal:** show intermediate victory milestones and a route feasibility estimate early. Allow a deliberate way to claim/purchase a corridor or construct a negotiated neutral corridor; for archipelagos, design a costly freight alternative or clearly communicate map compatibility before the player commits. Avoid declaring every water-separated map a bug without checking alternate settle sites. Keep the industrial hold period as counterplay. For the End route, move prerequisite preparation into earlier Ages and expose a final, interruptible commitment; additional cities can contribute components without requiring every victory to use the same city count. Do not merely multiply the final project costs until the match lasts 180 rounds.

## A proposed opening rhythm

These are **overlapping outcome windows**, not an enforced build order. They assume a competent ordinary faction on a reasonably usable Standard start. Small maps, hostiles, civilization choices, and aggressive neighbors legitimately change the plan.

| Round window | Desired decisions and payoffs | Civ VI comparison |
|---|---|---|
| 1–4 | Scout, local development, or extra defense; worker choice changes a visible completion date | Scout/Slinger/Monument-style competition for the opening queue; functional analogy, not equal effects |
| 4–10 | Discovery reveals a city site, village, resource, or threat; player revises research/production | Scouting changes boosts, settlement priorities, and need for protection |
| 8–12 | First useful technology and/or population growth; affordable follow-on investment | Early research and growing population make improved tiles/new choices useful |
| 10–18 | First economic building affects a second decision; deliberate Settler preparation or military commitment | Builder/Granary versus Settler/defender timing |
| 18–30 | Second city usually founded, or a viable one-city military/economic alternative is visibly ahead elsewhere | Expansion consumes investment and defense attention rather than being nearly free |
| 25–40 | Opening identity emerges; first equipment improvement, sustained infrastructure plan, or contested village strategy | Classical transition changes available plans while early investments still matter |

Illustrative queue arithmetic at a fixed five industry, using candidate costs: Scout 3 rounds + Crafting Hall 4 rounds + Settler 8 rounds = 15 production rounds before travel. The Hall increases subsequent production, so the actual sequence may finish sooner; the population gate may make it later. Defense-first adds or substitutes a four-round guard. That is precisely why actual sequential simulations, not a sum of isolated tooltips, must validate the timing.

## Prioritized rollout

| Phase | Change | Deliverable / acceptance |
|---|---|---|
| 0. Record the baseline | Log openings, unlocks, yields, idle queues, and travel | Per-round traces and distributions; separate AI failures from weak game rules |
| 1. Opening candidate | Science floor/Scholar adjustment, Scout/Guard/Settler ratios, immediate Hall, retained overflow | Three viable opening styles; meaningful first research at 8–12; expansion commonly 18–30; no forced universal build order |
| 2. Action and military links | Selected boosts, equipment upgrades, narrower early strength gaps | Discovery changes choices; veteran units remain useful; prediction/resolution/UI agree |
| 3. Infrastructure and progression | Selective role-based tech prices after measured compression; differentiate weak building/unit roles | Newly unlocked content has time and a scenario to pay off; no empty tech nodes; preserve the successful current industrial arc |
| 4. Logistics and endings | Corridor feasibility, freight alternatives, visible End preparation, cost/flow consistency | Chosen victories remain feasible and contestable; full Standard games often finish in rounds 145–175, leaving 180 as the deadline |

Do not combine every candidate into one opaque rebalance. Establish Phase 1 first and review actual openings before accepting larger research costs or additional mechanics. Keep rules configurable so variants can be compared on identical seeds.

Provisional Age milestone windows for full-campaign calibration: Iron 20–35, Redstone 40–60, Rotation 65–85, Brass 90–115, Steam 120–145. These are ordinary balanced-development goals. A specialized rush can arrive sooner with a weaker economy or army; a hard world-era gate would erase that choice. Full-tree completion is not an acceptance requirement.

## How to establish that it works

1. Record the same opening traces for at least 30 seeds initially, then expand coverage for promising candidates. Use balanced city/terrain fixtures to isolate costs, plus generated maps to expose geography. Include all ten civilizations, hostile off/Standard/dangerous, and representative two-/four-player maps. Hold AI difficulty constant first and rotate starting seats. Full factorial coverage can be staged; do not mistake 30 maps for 30 independent samples of every configuration.
2. Compare exploration-first, defense-first, infrastructure-first, and expansion-first strategies. Track what each gives up, not just final score: first useful research, growth, second city, camp/village payoff, surviving military power, and industrial output at rounds 10/20/30/40.
3. Measure player relevance: rounds between material decisions, rewards that change the next action, unlocked projects never built, projects completed after their payoff horizon, and time spent repeatedly skipping. A clickable turn task is not automatically an interesting decision.
4. Check every relevant Civ VI counterpart alongside a CivCraft candidate: production normalized to a defender, research relative to science income, total prerequisite investment, population cost, actual first-benefit timing, and role after the next unlock. Use the same game-speed assumptions and distinguish base cost from realized cost.
5. Log discarded production/science today, then verify conservation after implementing overflow. Carry base progress without allowing production-modifier exploits, unbounded banking, hidden auto-selection, or multiple unintended military completions. Preserve progress when switching projects; delayed completion still has an opportunity cost.
6. Speed audit: Quick/Standard/Epic already scale core costs and deadlines to 120/180/270 rounds. Border expansion, envoy cooldowns, hostile spawn intervals, resource generation/bills, and rail segment work do not all scale together. Explicitly decide which represent economic time versus physical actions. Movement and combat staying unchanged is reasonable, but will alter the relationship to map size. Scaling every cooldown blindly is also wrong.
7. Run full games after opening checks. Report median and spread for Age/victory times, practical equipment lifetimes, losing-player ability to respond, route feasibility, and faction differences. The current AI's three-/four-city expansion targets, building heuristics, research dependencies, and missing boost/upgrade planning must be updated with the rules; otherwise an AI tournament could reject a good mechanic solely because the AI cannot use it.
8. Verify native CraftOS input, displayed forecasts, round transitions, multiplayer authoritative actions, and save/reload after implementation. Simulation validates balance hypotheses; it does not establish that the experience feels satisfying. Play at least several human openings on distinct maps and collect concrete moments of anticipation, regret, and payoff.

## Boundaries of this proposal

- Preserve Minecraft/Create progression and the existing six named Ages. Do not replace the theme with historical Civ content.
- Retain situational infrastructure and asymmetric civilizations when their conditions are clear and fair. Equal purchase rates or identical win times are not the objective.
- Do not add a blanket research tax per city, mandatory district placement, or escalating prices for every military unit without evidence. Expansion should earn advantages after a real investment.
- Do not solve boredom by adding content before making existing choices worthwhile.
- No gameplay, save migration, branch publication, or release was performed for this research. Proposed numbers require the experiments above.
