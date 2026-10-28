# City specialization, production choices, armies, factions, and victories

Follow-up research, 26 October 2026. Current checkout: `codex/civcraft-roadmap`, HEAD `97944b8bc85e011d00abbdf45bf9aecdb82050ae`. The referenced content, economy, production, and victory files are unchanged from the earlier research baseline. This extends [the original balance investigation](BALANCE-RESEARCH.md). No gameplay changes are proposed as already implemented.

The user adds three priorities: investigate endgame/victory conditions and faction balance; explain the feeling of having too many units and no worthwhile buildings; and make cities feel specialized like Civ VI. These concerns change the recommendation: opening costs alone will not solve the missing choices. Specialization and repeatable productive work now belong in the first major design pass.

## The central finding

CivCraft has a finite building checklist but lacks productive activities that remain useful after the checklist is complete. Most cities can eventually accumulate the same additive bonuses, while some victory requirements actively demand identical development. Producing an army becomes an available outlet for spare industry even when the player does not need another unit.

Civ VI handles this through a combination of specialization, ongoing projects, competing victory investments, and ways to improve an army without increasing its number of pieces. It can still suffer from large armies and late-game repetitive turns. The lesson is not that its endgame is universally perfect; it is that it has more mechanisms to preserve a purpose for each city's production.

## What Civ VI does differently, with concrete equivalents

| Mechanism | Verified Civ VI example | Current CivCraft | Design consequence |
|---|---|---|---|
| Limited specialized development | Specialty districts become available at population 1/4/7, then every three additional population | No corresponding city-development capacity; buildings mostly stack | Growth can open a new strategic branch instead of merely adding another worker. |
| Geographic returns | Campus gains science from suitable adjacent terrain; Hansa rewards planned industrial/trade adjacency | Terrain changes worked yields, but most building effects are unconditional city-wide additions | City location should make one line of investment better than another. |
| Ongoing scholarly work | Campus Research Grants produces science during the project and Great Scientist points on completion | Once Libraries and later science buildings are built, there is no comparable ongoing production activity | A developed science city can keep being useful without training soldiers. |
| Ongoing commercial work | Commercial Hub Investment produces gold during the project and Great Merchant points on completion | Trading Hall/Stock Exchange give passive yields; no recurring trade project | Commerce can be an active use of production as well as a passive income total. |
| Ongoing industrial work | Gathering Storm Industrial Zone Logistics supplies the city with power while active and awards Great Engineer points on completion | Create factories mostly add flat industry | A factory can provide an operating service, not merely finish its construction list. |
| Quality instead of unit count | Unit upgrades, plus later Corps/Armies formed by merging units | XP exists, but no general equipment upgrade or merge action | More military investment need not mean more separate map pieces. |
| Staged scientific ending | Satellite → Moon Landing → Mars Colony → Exoplanet Expedition; later laser projects accelerate travel | The three final End projects all unlock at End Expedition research | Spread preparation and choices across the progression rather than unlocking the entire final queue together. |

Sources: [district capacity](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/), [Campus](https://www.civilopedia.net/en-US/gathering-storm/districts/district_campus/), [Hansa](https://www.civilopedia.net/en-US/gathering-storm/districts/district_hansa/), [Research Grants](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_enhance_district_campus/), [Commercial Investment](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_enhance_district_commercial_hub/), [Industrial Logistics](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_enhance_district_industrial_zone/), [formations](https://www.civilopedia.net/en-US/gathering-storm/concepts/combat_12/).

Important distinction: repeatable projects are a fallback that preserves productive agency. They do not automatically create a difficult decision every turn. The important choice is whether to keep operating the city, develop another specialty, prepare for victory, or divert resources into a military response. Automation should handle the routine continuation.

## Why the current building menu can feel empty despite 39 buildings

The total content count is the wrong measure. The useful measure is how many **relevant, materially different choices** exist when a city finishes its current job.

1. Research gates arrive in small batches, and buildings are one-time purchases. When a city finishes the latest batch, it must wait for another technology to open new local work.
2. A prerequisite chain often supplies exactly one next step. If the goal is an Industrial Complex, a large fraction of choices are already decided by its dependency graph.
3. Many buildings simply add another increment of food, industry, or science. A larger menu of similar increments still produces an obvious best purchase.
4. The game has no repeatable economic project category. The queue supports buildings, units, and wonders; the player can also explicitly select No Production. A human is not forced by the rules to train units, but idling feels wasteful and units are an obvious remaining productive option.
5. AI city roles already exist in `ai_city_roles.lua`, but they are planning weights, not player-facing economic specialization. They do not prevent a research city and factory city from eventually building the same infrastructure.

Static calculation from current runtime content: one Industrial Complex has **13 local buildings including itself**, totaling **890 base industry** before yields from those buildings, research, rails, units, or speed rounding. Industrial victory requires three such complexes in one network: **2,670 base industry across three repeated local chains**, plus rail preparation and the ten-round hold. The End route's local building closure is six buildings totaling 728 industry, of which 560 is the three final projects. These are dependency totals, not predicted completion times. [Arithmetic audit](specialization_static_audit.json), [current content](civcraft_content.json).

### Fresh production-choice trace

A new native CraftOS run of the same peaceful Forge mirror fixture reproduced Industrial victory on round 149 and recorded each city's legal buildings after the AI had acted. [Summarized measurements](PRODUCTION-CHOICE-MEASUREMENTS.json), [raw trace](civcraft_production_trace.json), [native harness](measure_production_choices.lua), [summarizer](summarize_production_choices.py).

| Round interval | City-round snapshots, both players | Snapshots with zero or one legal building | No active production |
|---|---:|---:|---:|
| 1–30 | 152 | 100% | 55.3% |
| 31–60 | 180 | 100% | 66.7% |
| 61–100 | 240 | 100% | 39.6% |
| 101–149 | 294 | 64.6% | 39.8% |

Player zero had three cities by round 10. At round 100 all three had 15 completed buildings, zero legal new buildings, no active production, and industry outputs of 31/45/36. The army consisted of four Stone Guards and a Scout; gold was 2,078 and net income +41. By the round-149 victory there were still only six units, including one Armored Engineer; treasury was 3,839 with +97 net income. This fixture shows considerable unused productive capacity, not an AI that endlessly spams soldiers.

Interpretation limits: this is one correlated deterministic match with one research/AI policy, Compact/Pangaea, hostiles off, and no independent villages initialized by the fixture. A legal active building is counted until completion; these are all-round snapshots, not only moments when the player chooses a new project. Wonders, military needs, and possible alternative research plans are not included in the legal-building count. The trace does not prove that every faction or human game has the same shortage, but it gives direct evidence of the narrow menu and idle production under an ordinary peaceful progression. The inherited action-count wrapper does not reliably count dispatches, so its zero order count is not interpreted.

To reproduce, copy the game to an isolated CraftOS profile, copy `measure_production_choices.lua` to `/choices.lua`, run `shell.run("/choices.lua", "180", "75123", "forge", "none", "forge")`, and extract `/civcraft-production-trace.json`. The fourth argument occupies the existing optional-GC slot; the fifth selects the opponent civilization. Then run `python3 summarize_production_choices.py /path/to/extracted-trace.json` in the host environment.

This updates the prior recommendation to avoid new capacity rules without evidence: the user's explicit desire for specialization, together with these repeated dependency chains, now provides a concrete reason to prototype a restrained capacity system.

## Recommended city specialization model

Use recognizable Minecraft/Create **specialized quarters or worksites**, with a few development slots, distinct local infrastructure, and recurring operations. This is a proposed CivCraft adaptation; it is not an existing system or an exact copy of Civ VI.

Basic food storage, simple defenses, and the opening Crafting Hall remain broadly available. A city then invests in one or more advanced specialties. Prototype capacity at population **2/5/8** for one/two/three specialties, adapting Civ VI's 1/4/7 thresholds to CivCraft's current population-two capital. These numbers require growth testing. A future population-one founded settlement would grow once before establishing a specialty; it must still have useful basic production beforehand.

Prefer one visible worksite on an owned hex per specialty, because placement makes the decision legible and connects it to the map. Evaluate its displacement of worked tile yields, suitable terrain, and network access. If that makes the first prototype too large, implement the same capacity and economic rules in the city screen first, then add map placement. The economic distinction must exist in either version; a label or colored icon alone is insufficient.

| City role | Local advantage and investment | Useful continuing work | Civ VI equivalent / limit |
|---|---|---|---|
| Farming settlement | Good food terrain; farms, pens, storage | Local growth or supplies exported through a route to a selected city/project | Farms/Granary and domestic trade support development; Civ VI does not have this exact farming specialty district. |
| Extraction/foundry town | Ore access, Quarry/Deep Mine/Furnace | Refining inputs and manufacturing equipment/components | Worked improvements plus Industrial Zone infrastructure; do not make every ore tile require a new district. |
| Enchanting/Ponder city | Science terrain; Library, Enchanting Room, Ponder Hall | Research experiments; expedition surveying/preparation | Campus, its buildings, and Research Grants. |
| Trading village | Accessible partners, market infrastructure | Trade contracts, relief shipments, diplomacy funding | Commercial Hub Investment and trade routes. |
| Manufacturing city | Create chain, productive terrain | Mechanisms, railway equipment, victory components | Industrial Zone investment; final component production has a Spaceport analogy. |
| Freight hub/port | Central network position or useful coast | Move goods, fulfill delivery commitments, support expedition logistics | Harbor/trade network role; no claim that Civ VI's railways work like CivCraft's. |
| Frontier arsenal | Threatened position and military facilities | Train or refit a needed army; bounded repairs and mobilization work | Encampment and upgrades; a frontier city need not train troops forever in peace. |

A city can combine two roles as it grows. Specialization should be an investment with foregone alternatives, not a permanent class chosen in a menu. A compact city can excel at one role; a large city gains versatility. Research cities must need food, defense, and equipment from somewhere, but avoid adding transport micromanagement to every yield. Start with a small number of automatic routes and clearly defined transferable outputs.

Do not gate all ordinary buildings behind specialties, require every city to develop every branch, or leave a small city with one legal job. At a typical completion point, aim for two or three plausible categories: continue operating a specialty, build/develop something new, or respond to a military/diplomatic situation. Many irrelevant menu entries are not a substitute.

## Repeatable projects: how completed cities keep contributing

Civ VI's Research Grants and Commercial Investment demonstrate the key property: the project converts current city effort into an ongoing strategic contribution rather than another permanent building or military piece. Great People make the race more competitive in Civ VI; CivCraft does not need an entire Great Person system to capture the core benefit.

Candidate operations, with rates deliberately left for simulation rather than falsely presented as balanced:

- **Ponder Experiments:** requires scholarly infrastructure; converts some active industry to science. Experiments can also provide a capped contribution to an identified expedition preparation objective. They must not grant an infinitely stacking permanent science modifier.
- **Trade Contracts:** requires market access; converts current effort into gold or fulfills a specific external contract. Gold can fund refits, village relationships, and imported materials. Contract rewards must have real sinks, not just inflate an already idle treasury.
- **Mechanism Assembly:** requires the relevant Create machinery and material inputs; produces equipment/components for rail, army refits, and victory objectives. It should not conjure strategic resources from nothing or duplicate the Mixer conversion without a purpose.
- **Supply Shipments:** routes a declared food/supply contribution to another settlement or an expedition. Route capacity and transport cost bound how much can be exported. This makes a farming town useful even when another city performs the final project.
- **Reconstruction/Refit:** repairs actual damage or upgrades existing equipment. Stop or notify when the task is complete; a full-health city should not misleadingly claim productive repair work.

Allow operations to repeat automatically until interrupted, with forecast outcomes and an unobtrusive indicator. Offer a persistent low-return fallback when a city's best project is unavailable. Do not require another confirmation every four rounds just because a project cycle completed.

Before adopting production-to-science conversion, test it against the new science floor and civilization bonuses. If running experiments is always better than building a Library or if every factory becomes the best research city, the conversion rate or eligibility is wrong. Units should remain worthwhile when there is a military purpose; projects should remove the incentive to create purposeless troops.

## Too many units: count, usefulness, and attention are different problems

Current gold can support a relatively large cheap army. Three population-two cities generate 12 gold per round before economic buildings or treaties. A Stone Guard costs one gold upkeep, so that income can cover twelve guards at zero net income if there are no other units. Three population-five cities generate 21 before those bonuses. These are arithmetic examples, not observed player armies. Buildings have no ordinary gold maintenance in the current treasury calculation.

The AI is not an unlimited-spam model: its normal land soldier targets are bounded at six, or eight for conquest, with separate categories for some scouts, engineers, naval units, and support needs. Its target count does not establish an appropriate human army size. Measure player armies and idle-unit prompts directly before claiming a universal ideal count. [Production AI](../../ai_production.lua), [treasury](../../systems.lua), [turn tasks](../../turn_tasks.lua).

Recommended order of fixes:

1. Add worthwhile civilian operations so extra troops cease to be the default outlet.
2. Add paid equipment upgrades that retain XP. Obsolete guards should become the new front line rather than remain beside an entirely new army.
3. Ensure each role has a need: frontline defense, ranged support, siege, reconnaissance, logistics. Consolidate duplicate engineers and healers, and stop suggesting units without a role.
4. Give standby/garrison orders a clear persistent behavior so inactive defenders do not generate repetitive movement decisions. Standby already exists; inspect discoverability and actual prompt behavior before adding another order.
5. Consider late **companies/battalions**, inspired by Corps/Armies, if map congestion remains. Merging should reduce pieces and upkeep pressure while preserving the best veteran. Test strength in effective combat power, not raw CivCraft stats. Do not import Civ VI's +10 Corps strength as +10 CivCraft attack: CivCraft multiplies its base stat by five.
6. Tune explicit upkeep and, if needed, a modest supply/logistics budget after the productive alternatives exist. Avoid an arbitrary hard unit cap or an immediate global upkeep increase that makes basic defense unaffordable.

Civ VI's Corps/Army model is a particularly relevant congestion tool: multiple same-type units merge into one stronger piece without gaining more HP, while preserving the strongest veteran's experience. The source mirror's Army wording is ambiguous about the incremental bonus, so this proposal deliberately does not use it to prescribe exact Army strength. [Formations](https://www.civilopedia.net/en-US/gathering-storm/concepts/combat_12/).

## Victory conditions should sustain different city roles

### End Expedition versus Civ VI scientific victory

In Gathering Storm, different technologies unlock successive stages: Rocketry for the Satellite, Satellites for the Moon Landing, Nanotechnology for the Mars Colony, and Smart Materials for the Exoplanet Expedition. The launched expedition continues traveling; laser projects speed it up, and terrestrial lasers add a power requirement. A finished research tree is therefore not the sole purpose of scientific development, and a launched expedition is not an instant win. Sources: [Satellite](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_launch_earth_satellite/), [Moon](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_launch_moon_landing/), [Mars](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_launch_mars_base/), [Exoplanet](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_launch_exoplanet_expedition/), [laser](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_terrestrial_laser/).

CivCraft currently unlocks Eyes of Ender, Expedition Equipment, and Dragon Expedition together at its terminal research, with sequential local building prerequisites and costs 140/180/240. Propose earlier milestones: surveying and knowledge in a scholarly city; gear/components in a manufacturing city; supplies and transport from farms/hubs; a final staging commitment. A compact empire could perform several contributions sequentially in a versatile capital, while a specialized network performs them in parallel after paying transport/setup costs. Do not turn three cities into a universal requirement for every victory.

Keep a visible late commitment with a bounded response window. Rival counterplay should include interrupting production or access to supplies, trading embargoes where relevant, and racing a different victory. Do not merely add an uninteractive fixed wait to the existing Dragon project. The precise contribution totals and delay must be calibrated against the existing round-149 industrial baseline.

### Industrial victory must reward complementary cities

There is no direct Civ VI industrial victory; its industrial capacity supports other goals. CivCraft can keep its distinctive logistics victory, but three copies of the same Industrial Complex chain conflict with the user's specialization objective.

Recommended prototype: a connected network with a manufacturing center, a freight hub, and a qualifying extraction/supply/trade partner; sustain a visible target of **delivered useful output** for a limited period. Roles must contribute different things. Factory output without transport, or transport without supplied goods, should not qualify. This replaces the three-identical-complex condition rather than adding even more mandatory buildings to it.

Require a credible alternative for island geography or clearly state compatibility. Report progress as actual deliveries/required flow and the threatened links. Prevent alliance trades from counting the same goods repeatedly, newly generated shipments from being duplicated by save/reload, or idle production farming victory credit.

### Diplomatic victory needs sustained agency and counterplay

Civ VI accumulates diplomatic victory points from several systems, including Congress outcomes, competitions, and certain development achievements. Opponents can use Congress to remove points. It is broader than one successful leadership ballot. [Diplomatic Victory](https://www.civilopedia.net/en-US/gathering-storm/concepts/diplomatic_victory/).

CivCraft already has a substantial Council system: leadership elections, policy resolutions, pledges, and village-linked delegates. It requires Commerce and a Council Hall, at least two-thirds of allocated delegates, and support from another civilization to win. That means a real external-support safeguard exists; this must not be described as a simple gold-purchase win. However, one qualifying election ends the game. The two-player case is especially sensitive to why the opponent supports a rival.

Prototype a short, public mandate track across multiple sessions, with sources such as fulfilled aid contracts, defended partners, and maintained relationships. Elections advance or confer the final mandate; opponents can contest it. Give trade and aid projects useful but bounded contributions. No infinite influence-per-industry loop, no requirement that a rational human willingly votes for an immediate rival victory, and no diplomacy route that silently becomes impossible after another player is eliminated. Test the two-player case explicitly.

### Conquest, Score, and missing cultural/religious routes

Civ VI Domination is ownership of original capitals, broadly matching CivCraft's capital goal. Keep that understandable target, but make wars involve useful army composition and logistics instead of count inflation. Do not add a long holding requirement without evidence that last-capital finishes lack counterplay. [Domination](https://www.civilopedia.net/en-US/gathering-storm/concepts/victory_2/).

Civ VI's Culture victory is a competition against rivals' domestic tourism, and Religious victory requires a majority of cities in each civilization to follow the religion. They give other economies and units a different end goal. CivCraft does not need a direct tourism/religion transplant now. Its existing End, industrial, diplomatic, and conquest identities can already offer distinct plans if the cities and production systems support them. [Culture](https://www.civilopedia.net/en-US/gathering-storm/concepts/victory_4/), [Religion](https://www.civilopedia.net/en-US/gathering-storm/concepts/victory_5/).

Current Score awards city/population/building/technology quantity, without directly crediting wonders, village relationships, or logistics. Review it after defining the role-based goals so the deadline does not unfairly erase non-science progress. Do **not** add raw unit count or unlimited project completions to score: that would reward precisely the spam and routine production the user dislikes. Cap or value durable achievements; clearly show the scoring breakdown. Keep Score a fallback rather than the usual planned finish.

## Faction balance: identity must change decisions without replacing the economy

Civ VI is not evidence of equal strength between all civilizations. Its useful design pattern is that many advantages operate through infrastructure, geography, resources, or a distinct economic exchange. Korea's Seowon provides +4 science but requires Writing, construction, hills, and loses science near adjacent districts. Germany's Hansa rewards industrial/trade placement. Mali trades production strength for a gold-oriented economy. These bonuses affect what the player builds and where, rather than only changing a starting yield. [Seowon](https://www.civilopedia.net/en-US/gathering-storm/districts/district_seowon/), [Hansa](https://www.civilopedia.net/en-US/gathering-storm/districts/district_hansa/), [Mali](https://www.civilopedia.net/en-US/gathering-storm/civilizations/civilization_mali/).

| CivCraft faction | Current rule | Balance concern | Proposed identity to test |
|---|---|---|---|
| Oak Villagers | Wheat Farm +1 food | Requires research/building; food is valuable only through growth/useful workers | Strong farming and supply settlements; food should help a partner, not force every city to grow endlessly. |
| Deepslate Miners | Quarry +1 industry | Early useful advantage but narrow expression; can conflict with conqueror AI personality | Extraction efficiency, terrain-aware foundries, equipment export. Choose its economic identity independently of AI aggression. |
| Enchanters Guild | Every city +2 science immediately | +200% center science over the ordinary one-science floor; scales with every cheap new city | A modest opening benefit, with most additional science earned by scholarly investment and experiments. Closest design reference: Seowon, not free empire-wide Campuses. |
| Desert Wanderers | Basic Scout +1 movement | Strong early information, then little progression; currently excludes the later Expedition Scout | Sustained exploration and route establishment, with upgrades retaining appropriate faction traits. No infinite reward for revealing the same tile. |
| Ocean Explorers | Naval units +1 movement | Highly map dependent; ship count alone is not an economy | Productive ports/freight links and maritime exploration, with a modest inland fallback. Sea advantages can remain genuinely conditional. |
| Andesite Engineers | Belt Workshop +2 industry | Later activation than Scholar; potential compounding once industry operations exist | Efficient manufacturing combinations and component assembly; require real machinery investment. Closest reference: Hansa's planned infrastructure. |
| Mountain Builders | Hill defenders +3 effective power | Tactical and terrain-conditional rather than permanent economic compounding | Hill settlement/worksite value plus a defensive identity; retain counterplay off hills. |
| Emerald Traders | Trading Hall +2 food | Name implies trade, but the bonus mainly duplicates growth advantages | Active contracts, exchange efficiency, and diplomatic funding, with profitable partners rather than a second Scholar-style global yield. Mali demonstrates an economic exchange identity, not a template to copy its penalties. |
| Golem Keepers | City defense +3 effective power | Helps only when attacked; peaceful games can make the identity nearly invisible | Cheaper or more efficient defensive preparation, golem refits, and bounded protection/aid contributions. Georgia's +50% defensive-building production illustrates a development benefit alongside a defensive theme. |
| Taiga Rangers | Cheaper movement through applicable wooded tiles | Some scouts/rangers already cross forest cheaply; overlap can reduce its distinct benefit | Woodland city/worksite benefits plus relevant troop mobility. Vietnam illustrates geography shaping development as well as movement. |

Additional source examples: [Georgia](https://www.civilopedia.net/en-US/gathering-storm/civilizations/civilization_georgia/), [Vietnam](https://www.civilopedia.net/en-US/gathering-storm/civilizations/civilization_vietnam/). These are design analogies; proposed CivCraft effects are not yet priced or implemented.

For scale, +3 effective defense power corresponds to about 11% less incoming damage before integer rounding and caps under CivCraft's exponential formula. That is not comparable to +200% starting center science by simply reading the printed numbers. Likewise, a later +2 industry can compound strongly if projects convert industry to science or contracts. Changes to specialization and operations must be included before declaring faction balance solved.

The previous 60-match benchmark is not a valid faction ranking: civilizations are paired with fixed personalities, different opponents, and different seeds. Distinguish the civilization bonus, player/AI policy, geography, and victory route. A weak AI using Miners does not establish that the mining bonus itself is weak.

## Revised implementation and validation order

1. **Opening and productive alternatives:** prototype cost/science changes together with a small set of ongoing jobs. Measure a city finishing its buildings before merely increasing army upkeep.
2. **Real city specialization:** limited advanced development, geographic payoff, local prerequisites, and visible role forecasts. Provide two or three credible alternatives at meaningful investment points; support deliberate hybrid cities.
3. **Quality-based armies:** upgrades first, persistent orders and duplicate-role cleanup next, optional later formation merging. Tune maintenance/supply only after the alternatives exist.
4. **Victory-role alignment:** replace identical-complex industrial qualification; distribute End preparation across research stages and complementary contributions; test diplomatic mandate progression and two-player incentives.
5. **Faction pass using the new economy:** modest starting parity, conditional advantages that alter decisions, and scenarios where each faction's strength matters. Keep AI difficulty separate from faction identity and economic bonuses.

Measurements should include city-rounds with zero/one/two-plus legal buildings, but also review strategic relevance: three bad buildings do not make three choices. Record recurring-project time, unit production with no assigned need, obsolete-unit count, standby prompts, spending on refits versus new pieces, specialist/route tradeoffs, and contribution by city role to each victory.

For faction testing, use matched seeds and seats, several opponents, all map families, and each enabled victory configuration. First use scripted equal-policy fixtures to isolate bonuses; then use policy-aware AI and human openings. Report uncertainty and matchup differences, not only pooled win rate. Do not demand exact 50% everywhere or erase a naval faction's advantage on water maps.

For victory balance, measure when a route becomes realistically available, how much additional commitment it needs, the response window after public warning, how competitors can interfere, and what useful decisions losing players still have. A final round number alone cannot establish a satisfying ending.

No gameplay changes, release, or publication were performed. The recommendations supersede the earlier assumption that cost tuning alone could address the lack of choices.
