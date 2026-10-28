# CivCraft versus Civ VI: player decision review

**Decision status:** All 38 initial questions and 16 follow-ups are answered.
See the [accepted ADRs](../../docs/adr/README.md) and
[implementation roadmap](../../docs/ROADMAP-balance.md) for the resulting design.
The alternatives, original recommendations and earlier approvals below are
historical questionnaire context; later answers can supersede them.

27 October 2026. Reference: Civilization VI with Gathering Storm, with optional
modules identified separately. CivCraft comparisons use the existing baseline
economy, including H1, and distinguish approved P1 changes. P1 implementation
is now underway in the shared workspace; it is not treated as fully validated
by this review. P2–P4 remain proposals. This review makes no gameplay edits.

This is a decision register, not approval to implement every recommendation.
Answers are recorded in `design_decision_answers.json`. IDs remain stable.
Each pending item has a question and three choices:

- **A — Keep:** retain CivCraft's current difference.
- **B — Align:** move substantially toward the corresponding Civ VI system,
  retaining Minecraft names and independently calibrated numbers.
- **C — Alternative:** use the specific smaller adaptation described below.

Recommendations are starting opinions, not assumed answers. Existing answers
are carried forward: P1 opening calibration (D07), P1 projects (D08), and the
requested healing split (D23). Other choices may require revisiting their details.

## Design reference and ComputerCraft constraints

In the [Ed Beach interview][interview], the stated goals include giving map
tiles consequential uses, making cities distinct, exposing valuable military
targets, encouraging different openings and keeping AI response time acceptable.
The interview is from 2016 before release; it explains intent, not final
Gathering Storm costs or proof that Civ VI has perfect balance.

For this review, the design test is: does a mechanic create useful choices
about investment, location, timing or counterplay? Simplicity is valuable when
it removes routine work; it is costly when it removes those choices.

Complexity notes are engineering estimates, not measured performance claims.
Static districts, integer bonuses and small policy tables are feasible in
ComputerCraft. Many independently moving units, large AI search spaces,
pathfinding, crowded screens and verbose network projections are bigger risks.
Fewer meaningful objects can be preferable to many shallow ones.

## Cities and economic development

### D01 — Where does a city's development exist?

**Current / Civ VI:** Most CivCraft buildings live inside the city record;
wonders already occupy map tiles. Civ VI places districts outside the center,
with buildings belonging to them. [District reference][districts]

**Question:** Should specialized infrastructure occupy map tiles?

- **A — Keep compact cities.** Plus: clear map and cheap management. Minus:
  less spatial commitment and fewer distinct targets outside city centers.
- **B — Civ VI-style districts.** Plus: placement, land use and raiding become
  major decisions. Minus: more UI, placement rules and AI work; crowded small maps.
- **C — A few visible special sites.** Place a limited Works, Knowledge or
  Freight site, while ordinary buildings stay inside cities. Plus: spatial
  identity with fewer objects. Minus: another boundary to explain and balance.

**Initial recommendation:** C, but B is feasible if spatial planning is central
to the intended game. **Interactions:** D02, D03, D04, D10, D22, D27.

### D02 — What prevents every city building everything?

**Current / Civ VI:** CivCraft has building prerequisites but no advanced-city
capacity limit. Civ VI gates specialty district capacity at population 1/4/7,
then every three additional population; some districts are exceptions. [Source][districts]

**Question:** What should force specialization rather than an identical checklist?

- **A — Keep unrestricted building access.** Plus: flexible recovery and easy
  rules. Minus: specialization must come entirely from incentives and geography.
- **B — Population-gated specialty districts.** Plus: growth buys strategic
  options. Minus: more planning commitments and potentially punitive small cities.
- **C — Limited city focus slots.** Plus: strong role choices with compact UI.
  Minus: abstract capacity and focus-switching rules can feel artificial.

**Initial recommendation:** C, with universal basics and defenses. Your existing
preference for specialized cities is retained; this question chooses the mechanism.
**Interactions:** D01, D05, D09, D27, D36.

### D03 — How much should geography determine a city's role?

**Current / Civ VI:** CivCraft terrain affects worked yields, movement, resources
and some prerequisites. Most buildings add flat yields. Civ VI district adjacency
adds location-specific returns, such as Campus terrain bonuses. [Source][districts]

**Question:** Which geographic specialization model do you want?

- **A — Keep mostly flat building effects.** Plus: predictable choices and fewer
  bad starts. Minus: cities can remain interchangeable.
- **B — Detailed district adjacency.** Plus: strong placement puzzles. Minus:
  more exceptions, map dependence and preview requirements.
- **C — A few local terrain/resource bonuses.** Plus: distinct cities with simple
  explanations. Minus: less precise placement play; needs caps to avoid jackpots.

**Initial recommendation:** C unless D01 chooses a full spatial game.
**Interactions:** D01, D02, D04, D15, D25.

### D04 — Builders and tile improvements

**Current / Civ VI:** CivCraft's Farm and Quarry are city buildings, not a general
Builder improvement system. Engineers lay rails. Civ VI Builders spend charges
on improvements and can harvest resources/remove features. [Builder][builder]

**Question:** How should players develop the land around their cities?

- **A — Keep city-level development.** Plus: few civilian pieces and clicks.
  Minus: less control over individual tiles and development timing.
- **B — Builders with improvement charges.** Plus: meaningful labor investment
  and tile choices. Minus: more units, routing and repeated orders.
- **C — City-funded tile works without Builder units.** Plus: land-use choices
  with fewer pieces. Minus: loses escort/logistics play; still needs tile UI.

**Initial recommendation:** C. Harvesting/chopping would need a separate follow-up
about one-time production bursts. **Interactions:** D01, D03, D06, D12, D22.

### D05 — Growth constraints: food, housing and amenities

**Current / Civ VI:** CivCraft uses food storage, food consumption, growth
thresholds and minimum growth time. It has no separate housing/amenity economy.
Civ VI uses both as additional growth/development constraints. [Housing][housing],
[happiness][happiness]

**Question:** How much city-growth management should exist?

- **A — Keep food plus the existing growth rules.** Plus: easy to understand.
  Minus: fewer reasons to balance a large city against several smaller ones.
- **B — Separate housing and amenities.** Plus: distinct expansion and growth
  pressures. Minus: several new meters and supporting content.
- **C — One simple development capacity.** Plus: growth has an infrastructure
  cost with one meter. Minus: combines two different economic functions.

**Initial recommendation:** C or A; choose housing and amenities separately in
follow-up if B is preferred. **Interactions:** D02, D06, D25, D32.

### D06 — Does a Settler consume population?

**Current / Civ VI:** CivCraft Settlers cost production and become more expensive
as more are trained, but do not consume population. A Civ VI Settler normally
removes one population on completion. [Settler][settler]

**Question:** Should founding another city also reduce the source city's population?

- **A — Keep no population cost.** Plus: simpler expansion and recovery. Minus:
  expansion needs sufficient competing production/protection costs.
- **B — Consume one population.** Plus: directly trades present growth for
  expansion. Minus: food and growth tuning become more sensitive.
- **C — Temporary growth/labor commitment.** Plus: meaningful cost without losing
  a citizen. Minus: another temporary state and a less familiar rule.

**Initial recommendation:** A for the approved P1 baseline, then compare B if
expansion still dominates. **Interactions:** D04, D05, D07, D25.

### D07 — Opening investment ratios

**Current / Civ VI:** Current CivCraft Scout/Guard/first Settler cost 5/13/12
industry against one ordinary center science. Civ VI's early investments create
competing build commitments; its raw prices are not suitable targets for CivCraft.

**Question:** Which opening calibration should guide the prototype?

- **A — Keep current ratios.** Plus: quick expansion. Minus: production can
  exhaust choices before useful research arrives.
- **B — Closely reproduce Civ VI relative timings.** Plus: a recognizable
  reference. Minus: different maps, growth rules and campaign length undermine copying.
- **C — The approved P1 calibration.** Plus: coordinated production/science
  changes with fewer new mechanics. Minus: its numerical balance remains unproven.

**Existing answer:** C, approved P1; not asked again unless D05/D06/D11/D13 changes
its assumptions. **Interactions:** D05, D06, D08, D11, D13, D33.

### D08 — What does a developed city produce indefinitely?

**Baseline / Civ VI:** The baseline economy offers construction, recruitment, wonders
or explicit idling; P1 adds three recurring projects. Civ VI district projects provide continuing economic activity
and often Great Person progress. [Example][commercial-project]

**Question:** How should recurring civilian production work?

- **A — Keep the existing finite menu.** Plus: least complexity. Minus: idle
  cities and unnecessary recruitment remain likely outlets.
- **B — District projects plus Great People.** Plus: mature cities contribute to
  economic and recruitment races. Minus: adds another progression system.
- **C — P1's three simple ongoing conversions.** Plus: useful work with small
  integer rules. Minus: needs calibration so operating does not beat all construction.

**Existing answer:** C, approved P1. Great People remain a separate D35 choice.
**Interactions:** D02, D09, D14, D24, D27, D35.

### D09 — Building families and operating costs

**Current / Civ VI:** CivCraft has thematic prerequisite chains and many additive
yield buildings, including Create processing. Civ VI groups buildings into
district families and uses maintenance and, in Gathering Storm, power for some
advanced effects. [Buildings][buildings], [power][power]

**Question:** What should distinguish higher-tier buildings from another yield increase?

- **A — Keep the current additive chains.** Plus: transparent progression. Minus:
  can remain a compulsory shopping list.
- **B — Closely align district tiers, maintenance and power.** Plus: richer
  trade-offs. Minus: several operating budgets and prerequisites.
- **C — Short role-based chains with selected operating requirements.** Plus:
  each machine has a job. Minus: content must be audited to avoid filler links.

**Initial recommendation:** C. This does not imply copying every Civ VI building.
**Interactions:** D02, D08, D15, D16, D24, D27.

### D10 — Wonders: general bonuses or strategic commitments?

**Current / Civ VI:** CivCraft already places world-unique wonders on tiles; this
is a similarity. Its six wonders have a smaller, mostly yield-oriented role set.
Civ VI has a much wider set of specialized, placement-constrained wonders.
[Wonder reference][wonders]

**Question:** How much should wonders change an empire's plan?

- **A — Keep six broadly useful bonuses.** Plus: easy to learn. Minus: limited
  identity and weaker build-versus-develop dilemmas.
- **B — A broad Civ VI-like wonder ecosystem.** Plus: many distinct strategies.
  Minus: content, AI valuation and balance workload grow substantially.
- **C — A few sharply differentiated Minecraft wonders.** Plus: memorable
  commitments with a small roster. Minus: missing a contested wonder may sting.

**Initial recommendation:** C; ensure viable alternatives to each wonder.
**Interactions:** D01, D02, D25–D29, D35.

## Research and infrastructure

### D11 — One research stream or science plus civics?

**Current / Civ VI:** CivCraft has one global science tree. Civ VI has separate
technology and culture-driven civic trees, including governments and policies.
[Civics][civics], [governments][governments]

**Question:** Should political/economic organization progress separately from technology?

- **A — Keep one research tree.** Plus: least UI and bookkeeping. Minus: science
  tends to unlock many kinds of advantage together.
- **B — Separate science and culture/civic trees.** Plus: independent strategic
  clocks. Minus: another yield, tree and balancing problem.
- **C — A small milestone-based doctrine track.** Plus: organization choices
  without a second full tree. Minus: requires clear milestone and respec rules.

**Initial recommendation:** C. The theme can be guild doctrines or settlement
charters rather than real-world governments. **Interactions:** D07, D12, D13, D26, D36.

### D12 — Research boosts earned through actions

**Current / Civ VI:** CivCraft lacks an Eureka/Inspiration-equivalent layer.
Civ VI boosts connect actions to research, such as coastal settlement helping
Sailing or a Pasture helping Horseback Riding. [Eurekas][boosts]

**Question:** Should activities accelerate related research?

- **A — Keep science-only progress.** Plus: predictable and simple. Minus:
  exploration and production have fewer direct research payoffs.
- **B — Boost objectives across most technologies/civics.** Plus: varied plans.
  Minus: checklist optimization and much more content/AI logic.
- **C — A few pivotal Minecraft experiments.** Plus: meaningful links without
  dozens of chores. Minus: unmatched branches could become less attractive.

**Initial recommendation:** C; boosts should offer another route, not mandatory
tasks. **Interactions:** D04, D11, D13, D25.

### D13 — Research-tree breadth and unlock spacing

**Current / Civ VI:** CivCraft has 45 technologies across six Ages. Gathering
Storm's reference tree is larger and spans nine eras. More entries alone do
not guarantee useful decisions. [Reference catalog](../civ6-balance-2026-10-26/README.md)

**Question:** How closely should the progression structure resemble Civ VI?

- **A — Keep six Ages and the current tree.** Plus: recognizable, compact theme.
  Minus: existing unlock gaps and bottlenecks need other remedies.
- **B — A similarly broad era-by-era tree.** Plus: more intermediate choices.
  Minus: longer campaigns and potential filler technologies.
- **C — Keep six Ages, reshape branches and unlock spacing.** Plus: focused
  decisions at manageable size. Minus: prerequisites and saves need careful versioning.

**Initial recommendation:** C. **Interactions:** D07, D09, D11, D12, D28, D33.

### D14 — Switching investments and completion overflow

**Current / Civ VI:** CivCraft retains research/paused production progress but
discards excess output at completion. Civ VI has overflow rules and switching
details that vary by yield and modifier; exact replication needs a separate audit.

**Question:** How forgiving should changing plans and finishing investments be?

- **A — Keep retention with discarded overflow.** Plus: easy rules. Minus:
  threshold waste and output timing can feel arbitrary.
- **B — Closely reproduce Civ VI's detailed rules.** Plus: familiar optimizations.
  Minus: modifier interactions and less transparent edge cases.
- **C — Retain progress and bounded, explicit overflow.** Plus: reduces waste
  and supports pivots. Minus: needs anti-duplication and cross-category rules.

**Initial recommendation:** C; retained progress still has a timing cost.
**Interactions:** D08, D12, D13, D19, D28.

### D15 — Strategic resources and manufacturing

**Current / Civ VI:** CivCraft has resource stocks and brass processing, but
horses/saltpeter have incomplete generation/use links. Gathering Storm uses
strategic-resource accumulation, unit requirements and ongoing consumption for
some advanced units. [Consumable resources][resources]

**Question:** How much resource logistics should military and industry require?

- **A — Keep the small current resource model, repair inconsistencies.** Plus:
  little new complexity. Minus: several resources may remain shallow gates.
- **B — Closely match resource stockpile/cap/consumption systems.** Plus: access
  and trade matter. Minus: more shortage states and map-dependent exclusion.
- **C — A few meaningful Minecraft inputs and outputs.** Plus: distinctive Create
  economy. Minus: recipes can become compulsory chores without alternative access.

**Initial recommendation:** C, with clear exchange/fallback options.
**Interactions:** D03, D09, D16, D17, D19, D25.

### D16 — Trade, roads and rail logistics

**Current / Civ VI:** CivCraft has commerce treaties, material exchange and
engineer-built rails with network benefits. It lacks Civ VI's general Trader-unit
route economy and automatic road creation through trading. [Trade][trade], [roads][roads]

**Question:** How should cities support and connect to one another?

- **A — Keep treaties/exchange/rails.** Plus: simple and strongly themed. Minus:
  early connections and economic interdependence are limited.
- **B — Trader units and route capacities.** Plus: active connections, roads and
  vulnerable commerce. Minus: more moving pieces and path management.
- **C — Abstract trade routes with visible links.** Plus: network choices without
  extra units. Minus: raiding and route visibility must be explicitly designed.

**Initial recommendation:** C, retaining Create railways for advanced logistics.
**Interactions:** D01, D09, D15, D22, D24, D27, D30.

## Armies and combat

### D17 — Unit roster and distinct roles

**Current / Civ VI:** CivCraft has 25 recruitable unit definitions, including
overlapping engineer/healer generations, and no air-combat layer. Civ VI has a
larger roster, upgrade families and more late-game domains. [Unit catalog][units]

**Question:** Should military breadth grow toward Civ VI's roster?

- **A — Keep the current roster.** Plus: low learning/content cost. Minus:
  duplicated support jobs and some role gaps remain.
- **B — Broad class and domain coverage.** Plus: more counters and era variety.
  Minus: more pieces, UI, AI and balance work, especially aircraft.
- **C — Fewer clear families with equipment variants.** Plus: more useful choices
  per unit type. Minus: requires migration and explicit role/counter design.

**Initial recommendation:** C; air warfare would be a separate optional decision.
**Interactions:** D15, D18, D19, D20, D21, D23.

### D18 — Upgrading an existing unit

**Current / Civ VI:** CivCraft has XP/levels but no general equipment-refit action.
Civ VI has research/resource/gold-gated upgrade paths. [Example][swordsman]

**Question:** Should an early unit become its later counterpart?

- **A — Keep separate recruitment and disbanding.** Plus: simple rules. Minus:
  obsolete bodies accumulate and prior investment is lost.
- **B — Civ VI-like upgrade chains.** Plus: veterans stay useful. Minus: upgrade
  financing can create large sudden military swings.
- **C — Minecraft equipment refits.** Plus: role continuity with selected material
  costs. Minus: prices, territory and turn consumption still need balancing.

**Initial recommendation:** B or C; choose whether the distinction should be
mostly thematic or mechanically different. **Interactions:** D14, D15, D17, D24.

### D19 — Combining units into formations

**Current / Civ VI:** CivCraft has settler escorts but no Corps/Army merge.
Civ VI combines same-type military units into stronger formations after civic
unlocks, reducing the number of pieces. [Formations][formations]

**Question:** Should several units eventually become one stronger piece?

- **A — Keep independent units.** Plus: transparent and reversible positioning.
  Minus: late armies keep demanding many orders.
- **B — Corps/Armies and naval equivalents.** Plus: investment with fewer pieces.
  Minus: strength breakpoints, unlocks and irreversible merges add rules.
- **C — One simple late-game formation tier.** Plus: declutters armies. Minus:
  less gradual development; must avoid an automatic always-merge choice.

**Initial recommendation:** C after upgrades. **Interactions:** D17, D18, D20, D21, D24.

### D20 — Stacking and support-unit handling

**Current / Civ VI:** CivCraft supports a linked settler/guard pair but not the
full military/civilian/support grouping model of Civ VI. [Formations][formations]

**Question:** How should support units share space and orders with an army?

- **A — Keep current escort rules and separate support pieces.** Plus: clear
  occupancy. Minus: congestion and more healer/engineer movement orders.
- **B — Civ VI-like support/civilian formations.** Plus: escorts and support move
  together. Minus: selecting, targeting and displaying a tile becomes harder.
- **C — Attach support as a visible army component.** Plus: fewer separate pieces.
  Minus: new damage, detachment and equipment rules must be explicit.

**Initial recommendation:** C or a limited B. **Interactions:** D17, D19, D21, D23.

### D21 — Combat, walls and siege

**Current / Civ VI:** Both games have tactical hex combat, ranged attacks and
walls, but their damage rules and siege options differ. CivCraft has deterministic
forecasts and no general ram-like early wall-support role. [Catapult][catapult], [ram][ram]

**Question:** How much of Civ VI's combat ecosystem should be reproduced?

- **A — Keep current combat and improve AI/clarity.** Plus: preserves a working
  core. Minus: large equipment breakpoints and siege friction may remain.
- **B — Closely align combat classes, counters and siege progression.** Plus:
  a richer reference model. Minus: much wider rebalancing and tactical complexity.
- **C — Retain deterministic combat, fix selected role/counter gaps.** Plus:
  targeted changes. Minus: bespoke systems need equally good explanations.

**Initial recommendation:** C, informed by equal-budget scenarios; existing weak
conquest AI is not proof walls must be nerfed. **Interactions:** D17–D20, D22, D24, D32.

### D22 — Raiding an economy without capturing its city

**Current / Civ VI:** CivCraft supports city capture but no general player
pillage action for its economy/rails. Civ VI lets attackers pillage improvements
and districts, making external infrastructure a military target. [Pillaging][pillage]

**Question:** How much non-conquest economic warfare should exist?

- **A — Keep capture as the main disruption.** Plus: low UI/rules cost. Minus:
  fewer limited wars or ways to delay a leading rival.
- **B — Broad pillage/repair rules.** Plus: many targets and tactical choices.
  Minus: repetitive damage/repair management and snowball risks.
- **C — Raid only key sites and transport links.** Plus: clear counterplay with
  bounded repair work. Minus: fewer options; those few targets must not be brittle.

**Initial recommendation:** C. **Interactions:** D01, D04, D16, D21, D27, D28, D30.

### D23 — Healing away from home

**Current / Civ VI:** Your requested H1 is implemented: normal rest/fortify heals
only in owned territory, while healer support works abroad. Civ VI permits
ordinary healing abroad at territory-dependent rates. [Territory][territory]

**Question:** Keep the explicitly requested support-dependent expedition healing?

- **A — Keep H1.** Plus: healers and retreat routes matter. Minus: an unsupported
  expedition has limited recovery.
- **B — Civ VI-like ordinary healing abroad.** Plus: less punishing distance.
  Minus: reduces support/logistics dependence.
- **C — A limited supply/camp alternative.** Plus: an additional recovery choice.
  Minus: introduces another support rule.

**Existing answer:** A, from your direct request. No reconfirmation needed unless
your support/formation choices create a conflict. **Interactions:** D16, D20, D21.

### D24 — Unit upkeep and insolvency

**Current / Civ VI:** CivCraft charges upkeep and can automatically disband
recent recruits when gold becomes negative. A matched replay lost two healthy
catapults this way. Civ VI also treats military maintenance as a budget and
provides policy choices affecting it. [Local evidence](OPERATIONAL_SIEGE_REPORT.md)

**Question:** How should the game constrain armies and handle an unpaid bill?

- **A — Keep upkeep and current automatic removal.** Plus: a hard budget limit.
  Minus: valuable recent investment can disappear unexpectedly.
- **B — Closely reproduce Civ VI maintenance/shortage/policy rules.** Plus: a
  fuller reference. Minus: depends on several other adopted systems.
- **C — Keep upkeep, show forecasts and offer bounded retirement choices.** Plus:
  preserves agency. Minus: needs a deadline and anti-free-credit rules.

**Initial recommendation:** C; affordability alone will not fix poor recruitment
or movement AI. **Interactions:** D08, D11, D16, D18, D19, D21.

## Factions, victories and other players

### D25 — Faction identity and balance

**Current / Civ VI:** CivCraft factions mainly have compact yield/movement/defense
bonuses. Civ VI combines civilization/leader abilities and unique content with
strong geography and infrastructure interactions. [Faction comparison](../civ6-balance-2026-10-26/SPECIALIZATION-FACTIONS-VICTORY.md)

**Question:** How asymmetric should factions become?

- **A — Keep small simple bonuses.** Plus: easy to learn and compare. Minus:
  a flat early yield can dominate without changing decisions.
- **B — Multiple abilities and unique content per faction.** Plus: strong identity.
  Minus: much more content and matchup complexity.
- **C — One signature mechanic plus a modest fallback.** Plus: meaningful identity
  at limited scope. Minus: still needs conditional map/opponent testing.

**Initial recommendation:** C. Close competitiveness should not require identical
strength on every map. **Interactions:** D03, D05, D11, D15, D17, D26–D30.

### D26 — Which kinds of victory belong in CivCraft?

**Current / Civ VI:** CivCraft has Conquest, Industrial, End Expedition, Diplomatic
and Score. It has no full culture/tourism or religious spread systems. Civ VI
has cultural and religious victory alongside its other routes. [Victory concepts][victories]

**Question:** Keep the current themed victory set or add missing Civ VI domains?

- **A — Keep the existing five categories.** Plus: compact and Minecraft-themed.
  Minus: fewer nonmilitary ways to interact with rivals.
- **B — Add full culture/tourism and religion.** Plus: wider strategic domains.
  Minus: major new economies, units, defenses and AI systems.
- **C — Add at most one themed influence/culture route later.** Plus: selected
  strategic breadth. Minus: a partial system can feel shallow or overlap diplomacy.

**Initial recommendation:** A initially; if B/C is chosen, split culture and
religion into separate follow-up decisions. **Interactions:** D11, D25, D29, D30, D35.

### D27 — Industrial victory and city specialization

**Current / Civ VI:** CivCraft requires three connected cities with the same
Industrial Complex flag. Civ VI has no directly equivalent industrial victory;
its productive cities support multiple routes.

**Question:** What should CivCraft's distinct industrial win reward?

- **A — Keep three matching developed factory cities.** Plus: clear objective.
  Minus: rewards identical building chains.
- **B — Remove the separate industrial win and align to Civ VI's route set.**
  Plus: fewer overlapping races. Minus: loses a strong Create identity.
- **C — A complementary manufacturing/knowledge/freight network.** Plus: specialized
  cities cooperate. Minus: can become another prescribed three-city checklist.

**Initial recommendation:** C. **Interactions:** D01, D02, D08, D09, D16, D22, D26.

### D28 — End Expedition: preparation versus final checklist

**Current / Civ VI:** CivCraft's three terminal End projects unlock together.
Gathering Storm's space race has staged project/research milestones and an
expedition that travels after launch; later projects accelerate it. [Exoplanet][exoplanet]

**Question:** How should the End victory build toward a finish?

- **A — Keep the existing final queue.** Plus: simple endpoint. Minus: compressed
  preparation and limited late counterplay.
- **B — Closely mirror the staged science-race structure.** Plus: visible milestones
  and several investment windows. Minus: risks a long compulsory sequence.
- **C — A few Minecraft preparation stages and an explicit contest window.** Plus:
  thematic and readable. Minus: interruption/recovery must be precisely defined.

**Initial recommendation:** C. A countdown alone is not meaningful counterplay.
**Interactions:** D10, D13, D14, D16, D22, D26, D33.

### D29 — Does diplomatic victory require a rival's consent?

**Current / Civ VI:** CivCraft needs two-thirds of allocated delegates plus a
different member's vote. Civ VI accumulates diplomatic victory points through
several systems, rather than one final election. [Diplomatic victory][diplomatic]

**Question:** What kind of diplomatic win should be supported?

- **A — Keep a negotiated coalition victory.** Plus: real negotiation. Minus:
  noncooperating rivals can prevent it indefinitely.
- **B — Closely align to Civ VI's point-based ecosystem.** Plus: multiple progress
  sources. Minus: more rules, timing manipulation and possible point farming.
- **C — A compact public-objective/mandate route.** Plus: independent progress with
  costly counterplay. Minus: risks becoming another economic construction race.

**Initial recommendation:** C if equal competitive viability is the priority.
A is a deliberate exception to that goal, not a balance tweak.
**Interactions:** D11, D16, D22, D25, D26, D30.

### D30 — Villages, trade diplomacy and global institutions

**Current / Civ VI:** CivCraft has influence-based village alliances, envoys,
treaties, pledges and Council resolutions. Civ VI adds city-state quests,
suzerainty, diplomatic favor and a broader Congress. [World Congress][congress]

**Question:** How much political play should exist outside the victory condition?

- **A — Keep the current diplomacy and village rules.** Plus: existing readable
  foundation. Minus: less active neutral-world interaction.
- **B — Closely reproduce city-states/favor/Congress.** Plus: a deep political
  economy. Minus: more currencies, exceptions and AI negotiation.
- **C — A few village contracts and consequential treaties.** Plus: active diplomacy
  with fewer meters. Minus: repeat contracts need farming/collusion protections.

**Initial recommendation:** C, retaining working current features.
**Interactions:** D15, D16, D22, D25, D29, D37.

### D31 — Wilderness threats and warning windows

**Current / Civ VI:** CivCraft uses Minecraft spawners/outposts and deterministic
hostile behavior. Civ VI's barbarian scout/report/raid loop can reveal an
approaching threat before the attack. This intent is discussed in the [interview][interview].

**Question:** How should wilderness pressure create early decisions?

- **A — Keep current spawner pressure.** Plus: themed and compact. Minus:
  pressure can be harder to anticipate or influence.
- **B — Scout discovery followed by organized raids.** Plus: information and
  interception matter. Minus: more hostile state and pathfinding.
- **C — Simple visible spawner alert levels and raid warnings.** Plus: readable
  preparation choices. Minus: fewer emergent scout interactions.

**Initial recommendation:** C, possibly adding a small scout loop later. The
known captured-settler runtime bug remains a separate correctness issue.
**Interactions:** D06, D07, D17, D21, D23.

### D32 — Capture, occupation and defeat

**Current / Civ VI:** CivCraft transfers cities and lacks a genuine player
elimination transition. Civ VI has explicit defeat handling and, with its
expansions, loyalty/occupation pressures on conquest. [Loyalty][loyalty]

**Question:** What should stop conquest from being either trivial snowballing or tedious cleanup?

- **A — Keep immediate transfer with minimal friction.** Plus: quick resolution.
  Minus: weak recovery/occupation choices; missing defeat handling still needs repair.
- **B — Fuller loyalty/occupation systems.** Plus: conquest has lasting costs.
  Minus: more city meters, unrest and potentially repetitive reconquest.
- **C — Simple occupation/recovery plus explicit defeat rules.** Plus: counterplay
  without a loyalty simulation. Minus: needs carefully limited penalties.

**Initial recommendation:** C. Correct turn termination and honest defeat
reporting are required under any option. **Interactions:** D05, D21, D22, D25–D29.

## Campaign structure and optional layers

### D33 — Campaign length and game-speed scaling

**Current / Civ VI:** CivCraft's Standard deadline is 180 rounds, with Quick/Epic
variants. Civ VI normally runs a much longer strategic arc. Movement does not
simply accelerate with economic costs in either comparison.

**Question:** Should we target Civ VI-like campaign duration or preserve a shorter game?

- **A — Keep the current duration/speed framework.** Plus: manageable sessions.
  Minus: current unlock and travel clocks may not fit it.
- **B — A substantially longer Civ VI-like arc.** Plus: more time for each era.
  Minus: late-turn workload and multiplayer commitment increase.
- **C — Keep shorter campaigns but retime unlocks, travel and contest windows together.**
  Plus: preserves format. Minus: compressing meaningful eras needs careful pruning.

**Initial recommendation:** C. **Interactions:** D06, D07, D13, D19, D28, D31.

### D34 — Simultaneous peaceful turns and wartime ordering

**Current / Civ VI:** CivCraft lets peaceful players act independently and
sequences active war groups. Civ VI offers turn modes including sequential,
simultaneous and dynamic multiplayer; there is not one universal Civ VI mode.

**Question:** Which turn structure should the balance target assume?

- **A — Keep CivCraft's war-component model.** Plus: little peaceful waiting.
  Minus: reaction/order rules need clear presentation.
- **B — Align to a selected Civ VI multiplayer mode.** Plus: familiar behavior.
  Minus: sequential waiting or simultaneous click races depend on the mode chosen.
- **C — Keep the hybrid but expose a simpler explicit combat phase/order.** Plus:
  readable fairness. Minus: adds a transition and may increase waiting.

**Initial recommendation:** A with clearer UI; choose the exact mode in follow-up
if B is preferred. **Interactions:** D20, D21, D22, D32, D33.

### D35 — Great People and secondary project rewards

**Current / Civ VI:** CivCraft has no Great Person recruitment race. Civ VI
specialized development produces points toward individual powerful figures.
[Great People][greatpeople]

**Question:** Should specialized cities compete for limited exceptional rewards?

- **A — Keep this layer absent.** Plus: no additional race/currency. Minus:
  projects and specialization have fewer long-term secondary payoffs.
- **B — Full category-based Great People.** Plus: strong timing and competition.
  Minus: many unique effects, points and AI valuations.
- **C — A small shared set of Inventors/Master Craftspeople.** Plus: notable
  rewards at smaller scope. Minus: still risks snowballing and must have fallbacks.

**Initial recommendation:** A initially or C after the core economy works.
**Interactions:** D02, D08, D10, D11, D25.

### D36 — Governors and persistent city administrators

**Current / Civ VI:** CivCraft has no governor progression. Civ VI governors
provide assignable city specialization with promotion choices. [Governors][governors]

**Question:** Should city identity also depend on an assignable administrator?

- **A — Keep governors absent.** Plus: fewer overlapping specialization systems.
  Minus: less ability to move a development advantage between cities.
- **B — Governor trees and establishment delays.** Plus: distinctive city plans.
  Minus: another promotion/assignment system.
- **C — One simple specialist appointment per empire.** Plus: a movable emphasis.
  Minus: can still duplicate focus-slot decisions rather than add value.

**Initial recommendation:** A unless it fills a gap left by D02/D11.
**Interactions:** D02, D05, D11, D25, D32.

### D37 — Espionage

**Current / Civ VI:** CivCraft has no spy mission system. Civ VI spies can
perform offensive missions and counterspy. [Espionage][espionage]

**Question:** Should rivals have a nonmilitary sabotage/information tool?

- **A — Keep spies absent.** Plus: simple, visible causes. Minus: fewer ways to
  challenge a distant peaceful leader.
- **B — Full spy units, missions and counterspies.** Plus: a separate interaction
  layer. Minus: more units, probabilistic events and difficult-to-explain losses.
- **C — A small, costly abstract mission system.** Plus: counterplay without
  additional map pieces. Minus: needs warnings, defense and anti-spam limits.

**Initial recommendation:** A or C later, depending on D22/D28 counterplay.
**Interactions:** D22, D26–D30, D34.

### D38 — Power, fuel and environmental consequences

**Current / Civ VI:** CivCraft has themed machinery and processing but no
Gathering Storm-style power/fuel/climate system. [Power][power], [environment][environment]

**Question:** Should advanced production require an operating energy economy?

- **A — Keep current passive machines/limited recipes.** Plus: minimal overhead.
  Minus: little operating trade-off after construction.
- **B — Power, fuel and climate/disaster consequences.** Plus: a substantial
  late economic layer. Minus: several new simulations and balance dependencies.
- **C — Simple Create power capacity, without global climate.** Plus: thematic
  machine operation choices. Minus: another capacity meter; avoid compulsory wiring chores.

**Initial recommendation:** C only if D09/D15 need it; decide climate separately
if B is preferred. **Interactions:** D09, D15, D16, D25, D27, D33.

## How answers will be reconciled

First collect D01–D03, then ask the remaining unanswered items in small batches.
Every later question retains A/B/C, but its concrete alternative can be refined
to fit your earlier answers. A choice is not discarded merely because it differs
from the recommendation.

After each batch, record answers and classify interactions:

- **Compatible:** the choices reinforce one another.
- **Parameter dependency:** both work, but need joint cost/capacity calibration.
- **Design tension:** both can work with an explicit trade-off.
- **Direct conflict:** the same object cannot obey both rules as stated; ask a
  focused follow-up before implementation.

Examples requiring attention:

| Choices | Follow-up needed |
|---|---|
| Full placed districts + focus slots | Do slots count districts, functions, or both? Avoid double-gating every city. |
| No civics track + Civ VI corps/policies | Which Minecraft milestone unlocks these instead? |
| Settler population loss + slower growth + pricier settlers | Is the combined expansion penalty too large? |
| Very short campaigns + many eras/tiers | Which content gets meaningful time to operate? |
| No pillaging/spies + a long public victory countdown | What costly action can actually interrupt the leader? |
| Limited city roles + three identical Industrial cities | Change the victory condition or accept that it overrides specialization. |
| Independent victory chances + compulsory diplomatic consent | Choose independent progress, or explicitly exempt coalition victory from that fairness goal. |
| Upgrades + upkeep + few civilian outlets | Forecast whether modernized armies can be sustained instead of replaced and involuntarily lost. |
| Automatic tile development + detailed geographic bonuses | How does the player direct and understand the spatial choice? |
| No Builders/Traders + full Civ VI infrastructure | Which city actions replace their labor and transport functions? |
| Great People + governors + focus slots + doctrines | Which layers create different decisions, and which duplicate one another? |

Only after reconciliation should we rewrite the implementation package. Then
test mechanics and numerical pacing separately, adapt agents to the changed
rules, and check early/mid/late human play. Exact victory-rate equality across
all maps and opponent strategies is not a realistic guarantee; competitive
agency and conditional success per pursuer remain the evaluation targets.

## Sources and current-code anchors

CivCraft source: `content.lua`, `systems.lua`, `economy.lua`, `actions.lua`,
`unit_stacks.lua`, `combat.lua`, `hostiles.lua`, `world.lua`, `landmarks.lua`,
`railways.lua`, `council.lua`, `victory.lua`, `turn_scheduler.lua`, and
`match_lifecycle.lua`. Existing research results are linked above where used.

Public Civilopedia concept pages can retain outdated explanations even under
the Gathering Storm selector. The science comparison uses the actual Exoplanet
project entry rather than a legacy Mars-only concept description. This review
does not copy district-cost exploits or exact overflow modifiers as settled facts.

[interview]: https://gamesbeat.com/why-firaxis-decided-to-make-drastic-changes-to-cities-in-civilization-vi/
[districts]: https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/
[builder]: https://www.civilopedia.net/en-US/gathering-storm/units/unit_builder/
[settler]: https://www.civilopedia.net/en-US/gathering-storm/units/unit_settler/
[housing]: https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_14/
[happiness]: https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_16/
[commercial-project]: https://www.civilopedia.net/en-US/gathering-storm/wonders/project_enhance_district_commercial_hub/
[buildings]: https://www.civilopedia.net/en-US/gathering-storm/buildings/
[wonders]: https://www.civilopedia.net/en-US/gathering-storm/wonders/
[civics]: https://www.civilopedia.net/en-US/gathering-storm/concepts/culture_4/
[governments]: https://www.civilopedia.net/en-US/gathering-storm/concepts/govt_1/
[boosts]: https://www.civilopedia.net/en-US/gathering-storm/concepts/science_3/
[resources]: https://www.civilopedia.net/en-US/gathering-storm/concepts/consumeable_resources/
[trade]: https://www.civilopedia.net/en-US/gathering-storm/concepts/trade_5/
[roads]: https://www.civilopedia.net/en-US/gathering-storm/concepts/movement_2/
[units]: https://www.civilopedia.net/en-US/gathering-storm/units/
[swordsman]: https://www.civilopedia.net/en-US/gathering-storm/units/unit_swordsman/
[formations]: https://www.civilopedia.net/en-US/gathering-storm/concepts/combat_12/
[catapult]: https://www.civilopedia.net/en-US/gathering-storm/units/unit_catapult/
[ram]: https://www.civilopedia.net/en-US/gathering-storm/units/unit_battering_ram/
[pillage]: https://www.civilopedia.net/en-US/gathering-storm/concepts/combat_13/
[territory]: https://www.civilopedia.net/en-US/gathering-storm/concepts/diplo_15/
[victories]: https://www.civilopedia.net/en-US/gathering-storm/concepts/victory_1/
[exoplanet]: https://www.civilopedia.net/en-US/gathering-storm/wonders/project_launch_exoplanet_expedition/
[diplomatic]: https://www.civilopedia.net/en-US/gathering-storm/concepts/diplomatic_victory/
[congress]: https://www.civilopedia.net/en-US/gathering-storm/concepts/world_congress/
[loyalty]: https://www.civilopedia.net/en-US/gathering-storm/concepts/loyalty/
[greatpeople]: https://www.civilopedia.net/en-US/gathering-storm/concepts/greatpeople_2/
[governors]: https://www.civilopedia.net/en-US/gathering-storm/concepts/governors_1/
[espionage]: https://www.civilopedia.net/en-US/gathering-storm/concepts/diplo_5/
[power]: https://www.civilopedia.net/en-US/gathering-storm/concepts/power/
[environment]: https://www.civilopedia.net/en-US/gathering-storm/concepts/environmental_effects/
