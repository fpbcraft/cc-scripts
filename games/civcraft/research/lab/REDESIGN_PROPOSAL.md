P1 implementation status: [approved prototype and validation](P1_IMPLEMENTATION.md).

# CivCraft redesign proposal: choices that compound, routes that remain contestable

Latest review sequence: [FIRST_CHANGE_PACKAGE.md](FIRST_CHANGE_PACKAGE.md).
Its explicit prototype parameters refine earlier candidate ranges. H1 is the
user-requested implemented healing exception; P1 is now approved and implemented as a prototype; P2–P4 still require review. Research gaps do not require waiting for perfect AI before
prototyping a reviewed gameplay package.


Status: design proposal for review. This document does not change gameplay,
content, saves, AI release behavior, or the current ruleset. Values described
as targets or candidate ranges are hypotheses for controlled experiments.

This proposal is grounded in `CURRENT_STATE_AUDIT.md`, `BALANCE_ISSUES.md`,
`CIV6_COMPARISON.md`, `EXPERIMENT_PROTOCOL.md`,
`AI_ML_RESEARCH_PLAN.md`, and the runtime inventory in
`../civ6-balance-2026-10-26/`. It deliberately preserves the Create/Minecraft
identity: cities are workshops and settlements, technology is a physical
production chain, rail is geography, villages are political actors, and armies
are equipment that can be maintained and rebuilt.

## 1. Evidence status and design boundary

### Current facts

- The live ruleset has six Ages, 45 technologies, 25 recruitable units, 39
  buildings/projects, six wonders, five victory routes, a 180-round Standard
  limit, and two-to-four players. Exact counts come from the runtime export;
  historical fixture hashes and current source revisions must remain attached
  to future reruns.
- Research and paused project progress are retained, but completion overflow is
  discarded. Retaining progress is forgiving but still has opportunity cost:
  the current round's output advances one selected stream.
- There is no general unit equipment-upgrade action. Early and late units are
  therefore separate purchases despite having experience levels.
- The combat curve is exponential and capped. The archived fixture measured a
  large early-tier breakpoint (Iron Swordsman effective power 45 versus Stone
  Guard 20, with the stronger attack reaching the damage cap). This is a
  static/fixture fact, not a claim about all battles at current HEAD.
- Engineer, Armored Engineer, and Railway Engineer all expose the engineer rail
  capability after Railways; Alchemist and Supply Crew both expose healing.
- Industrial victory requires a connected rail network and three qualifying
  cities for a hold period; End victory is an ordered project chain; Council
  victory depends on delegates and another civilization's support. These are
  distinct conditional routes, not proven balanced routes.
- `content.lua` contains horses and saltpeter metadata, but the live resource
  order/generation/unit gates are incomplete. This is a content mismatch, not
  yet a measured civilization advantage.
- The current working tree has behavior-preserving lifecycle extraction, but
  complete public headless API, wartime parity, save/replay parity, metrics,
  and action-budget contracts remain work in progress.

### Executed research pilots

The research platform now has bounded, source-frozen pilot results in addition
to the earlier seven-match runner pilot:

- `results/strategy_search_pilot.json` selected an expedition policy after one
  training seed and two evaluation seeds. On eight held-out Forge seat games it
  scored 0.75 versus 0.25 for the baseline's eight games. The run used a tiny
  population (3), two generations, and fixed opponent types. This demonstrates
  that goal commitment and economic weights together can change results; it does
  not establish intrinsic expedition strength, faction equivalence, or optimal
  play.
- `results/recoverability_pilot.json` tested a legal research diversion from
  round-10 checkpoints in four Forge/no-hostiles matched cases on two seeds,
  using a legal `Sailing` diversion. Two diversions retained the winner but
  delayed victory by 10 and 11 rounds;
  one changed a baseline expedition win into a diversion loss; one produced the
  same winner and round. This is a useful recoverability fixture, not a general
  mistake-tolerance estimate.
- `results/route_crossplay.json` reports a 24-game bounded route-controller
  slice in which the selected expedition controller was credited with 12/12
  reported wins and conquest 0/12. The controllers were not comparably strong,
  used one faction and two seeds, so the result is a policy-competence warning,
  not a route-balance finding.
- `results/adversarial_archive_adaptation_pilot.json` extends this with archive
  adaptation: training seed `451139`, initial selected-expedition/industrial/
  conquest candidates, fixed archived expedition-plus-industrial opponents,
  rotated seats, population 3, and two generations. The selected expedition
  mutant scored 1.00 on its four-game training block. On untouched seeds
  `808381` and `919393`, the previous-champion mirror control scored 0.50/0.50
  and previous-champion versus adapted counter scored 0.25/0.75; all four matches in
  each holdout cell finished without errors or censoring. This remains a narrow
  Forge/no-hostiles policy result; source hashes, candidate Lua archives, and
  raw match paths are recorded, and throughput is confounded by a concurrent
  three-worker run.

These pilots strengthen the case for policy adaptation and matched holdouts;
they do not justify changing victory costs or deploying the selected policy.

### Bounded pilot facts

The current `/tmp/civcraft-lab-pilot-results.json` pilot ran seven configured
matches: five finished and two errored. It included a Compact/Pangaea Forge
mirror that reached the Industrial arc's round-149 result, a Scholar/Iron
seat-swapped pair, and a four-player Compact/Continents match that ended at
round 106. The two seed-95117 failures stopped around rounds 14 and 17 with
`hostiles.lua:103: table index is nil`, identifying a hostile-spawner failure
(`nil` index) rather than a balance outcome. The pilot used a small, repeated
seed set and standard hostile mode; it proves runner usefulness and a bug
surface, not faction equivalence, route fairness, or ML strength.

### Design hypotheses to test

1. A single science clock plus a very strong early Scholar bonus can make the
   first technology choice too passive for ordinary factions.
2. Unlimited city building slots make many factory/science chains additive
   checklists rather than specialization choices.
3. Independent unit generations and the combat curve make upgrades feel like
   army replacement, reducing the value of early military investment.
4. Late content becomes pointless when it has no route, counter, or repeatable
   use before the 180-round end.
5. Victory routes may be viable only on certain maps or civs; raw aggregate
   win share alone would hide that conditional fairness.
6. Preserving progress and carrying bounded overflow can improve recoverability
   without removing the opportunity cost of changing a queue.

No hypothesis becomes a gameplay change until the controlled tests in
`EXPERIMENT_PROTOCOL.md` establish effect size and trade-offs.

## 2. North star and invariants

The intended Standard campaign has several understandable clocks. By roughly
round 8–12, a player should have a first meaningful research/development
decision; by 18–30, expansion should usually be a real investment rather than
an automatic spare-queue action; by 25–40, the empire should reveal a focus;
and late projects should still have time to matter. These are calibration
windows, not deadlines or a forced build order.

The redesign preserves these invariants:

- **One authoritative rules engine.** CraftOS, native Lua, replay, and any Gym
  adapter call the same validated actions and observer projections.
- **Choices remain reversible enough to be forgiving.** Retained research and
  project progress stay; a bounded overflow bank, if adopted, cannot become
  unlimited production storage or a modifier exploit.
- **No blanket expansion research tax.** Expansion must compete through
  production, food, focus capacity, defense, upkeep, and geography. It should
  not be punished by an arbitrary empire-wide science surcharge.
- **No mandatory Civ VI district clone.** Specialization is a lightweight
  Create-compatible capacity/focus layer, not a second map-placement UI.
- **No equal-share faction target.** A civilization may excel in a context; the
  target is conditional viability, counterplay, and uncertainty-aware matchup
  fairness.
- **No hidden AI cheats.** Difficulty changes decision quality, planning, and
  controlled noise; it does not grant sight, resources, extra turns, or illegal
  actions.
- **No auto-tuning in the live game.** Candidate rules are versioned, replayed,
  and reviewed before any release or save migration.

## 3. A coherent model: settlement, works, army, route

Each city has four interacting responsibilities:

1. **Settlement:** food, population, local terrain, and one or more universal
   basic buildings.
2. **Works:** Create machinery and repeatable output that converts local input
   into industry, materials, power, or logistics.
3. **Army:** equipment refits, defenses, supply, and recruitment.
4. **Route:** research, rail commerce, diplomacy, End preparation, or another
   victory-specific commitment.

These are not four queues. They are categories used to create opportunity cost
and readable city identity. A city may change focus, but changing it consumes a
turn/project opportunity, requires prerequisites, or temporarily loses a bonus.
The player can still build ordinary farms, walls, libraries, and essential
infrastructure wherever legal.

## 4. Specialized cities without mandatory districts

### 4.1 Focus capacity

Introduce a data-driven city focus capacity rather than a full Civ VI district
system. A city receives a small number of focus slots from population and/or a
one-time civic/infrastructure decision. Candidate calibration levels are two
early slots, three at a mid-population threshold, and one additional late slot;
the exact thresholds must be measured against current city counts and queue
idle time.

Buildings/projects declare one of:

```text
core       food, housing, basic storage, local defense
research   library/academy/ponder/end knowledge
works      Create machinery, power, processing, assembly
logistics  rail, freight, movement, materials, trade
military   refit, ranged/siege, walls, garrison, supply
maritime   dock, shipyard, naval route
diplomatic village/council influence and delegates
```

One city can host a limited number of non-core focuses. A focus grants an
identity bonus or unlocks a repeatable; it does not simply block every other
building. Existing prerequisites remain meaningful, and universal basics are
not made illegal merely because a city has chosen a research focus.

### 4.2 Specialization examples

- **Research Bench:** science buildings and research proofs; trades some works
  capacity for science and late research projects.
- **Create Works:** press, mixer, brass, assembly, steam; converts copper/zinc,
  power, or fuel into industry and advanced materials.
- **Rail Foundry:** station, freight, route maintenance, engineer refits; makes
  network construction and logistics cheaper or safer rather than giving free
  global production.
- **Garrison/Arsenal:** walls, military refits, ranged/siege support, supply;
  protects a corridor and turns industry into quality units.
- **Market/Embassy:** village influence, council, trade and diplomatic projects;
  depends on relationships and does not guarantee a Council victory.
- **Harbor/Expedition:** coastal and End preparation, naval logistics, or
  long-range exploration; map-dependent but with an inland fallback.

The player should be able to build a mixed city when the map demands it. The
trade-off is lost focus efficiency, not an opaque prohibition. The UI must show
which bonus will be displaced before the player confirms a specialization.

### 4.3 Repeated work

Replace filler chains with a small library of repeatable operations. Each has a
cost, input, output, focus requirement, and a visible counter/opportunity cost:

| Operation | Input | Output | Counter/trade-off |
| --- | --- | --- | --- |
| Workshop Batch | power or basic materials | short industry/material burst | competes with unit/refit queue |
| Research Proof | books, power, or a discovered proof | bounded science progress | cannot be banked indefinitely; consumes research focus |
| Freight Run | iron/rails/gold | route progress, trade, or movement supply | exposed to rail disruption and needs a route |
| Arsenal Refit | iron/diamond/brass + gold | unit upgrade/repair/equipment | uses city works and consumes stock |
| Village Initiative | gold/materials + influence | influence/delegates/relationship | cooldown and diplomatic retaliation |
| Expedition Preparation | End materials/power | bounded End progress | visible staging and vulnerable commitment |

Operations should have diminishing returns or a capacity limit per city/round.
They are a use for an idle late city, not an infinite science faucet. A
repeatable is successful only if it changes which next action is best and has a
credible rival investment.

## 5. Quality armies and recoverable military investment

### 5.1 Upgrade families

Add explicit data fields for `upgradeFrom`, `upgradeCost`, `upgradeMaterials`,
`upgradeTurns`, and `preserveExperience`. Start with three families:

- Guard: Stone Guard → Shield Guard → Iron/Diamond/Netherite Guard;
- Ranged/Siege: Bow Archer → Crossbow Guard → Create siege line;
- Mounted/Naval/Support: Horse/boat/engineer branches where the map and
  technology make the role meaningful.

An upgrade is a validated action in a supplied/owned city or depot, consumes
industry/material/gold, uses the unit activation, and preserves veteran XP.
Recruiting a new unit remains useful when the player has capacity or needs a
second front. Existing stand-alone units are not removed until upgrade paths
and migration tests prove equivalent legal choices.

### 5.2 Combat breakpoint calibration

Do not tune printed strength in isolation. For each tier, measure full-health
attacker/defender damage across terrain, walls, support, level, ranged and city
combat. Candidate target is a readable advantage: a new tier should normally
win a prepared one-on-one fight in several activations, not erase the older
unit in one capped hit. The exact curve, including whether to narrow the
exponent or stat spacing, awaits the combat matrix.

Keep roles distinct:

- melee holds/captures;
- ranged supports without retaliation but needs protection;
- siege attacks walls/cities and is vulnerable in the field;
- mounted exploits movement and flanks;
- engineers/logistics alter geography and supply;
- healers/support extend an army but do not duplicate each other.

Make Engineer, Armored Engineer, and Railway Engineer a meaningful lineage or
distinct jobs (construction, armored escort, freight/repair). Make Alchemist a
combat healer/potion role and Supply Crew a logistics/supply-radius role. Do
not add units simply to match Civ VI's catalogue.

### 5.3 Resources and grace

Separate resource access from per-unit cost and upkeep. A missing deposit should
create a strategic problem, not silently delete an entire counter branch. A
candidate model is a small stock reserve, visible exchange/settlement options,
and a graceful advanced-unit slowdown or surcharge before recruitment becomes
impossible. Wire or explicitly retire horses/saltpeter; never leave them as
implied strategic choices.

## 6. Faction identity under conditional fairness

Keep the ten Minecraft/Create-flavoured identities and give each a primary
context plus a credible fallback. Identity budgets should be expressed as
conditional effects, not unconditional opening multipliers whenever possible:

| Current civilization | Current advertised bonus | Proposed primary context | Proposed fallback/counterplay |
| --- | --- | --- | --- |
| Enchanters Guild (`scholar`) | Cities +2 science | conditional research proofs and Knowledge focus | defensive knowledge and diplomacy |
| Andesite Engineers (`forge`) | Belt Workshops +2 industry | Create Works, power, refits, rail | quality army or freight |
| Deepslate Miners (`iron`) | Quarries +1 industry | extraction and material supply | industrial or military production |
| Mountain Builders (`highland`) | Hill defenders +3 power | defended passes and hillside works | durable industrial network |
| Emerald Traders (`merchant`) | Trading Halls +2 food | settlement trade and village relationships | freight and economic recovery |
| Ocean Explorers (`mariner`) | Ships +1 movement | coast, ships and sea logistics | inland engineering/trade fallback |
| Desert Wanderers (`nomad`) | Scouts +1 movement | scouting and distant opportunities | mobile defense and village trade |
| Golem Keepers (`sentinel`) | City defense +3 power | walls, supply and protected production | diplomatic or industrial safety |
| Taiga Rangers (`wild`) | Forest movement costs one | forest scouting and terrain control | village and exploration economy |
| Oak Villagers (`verdant`) | Wheat farms +1 food | food, growth and staffing | population-supported research or trade |

Current bonuses above come from the runtime inventory; the final two columns
are proposed identity contracts, not implemented effects. Unique units and
other existing effects remain part of each faction's full audit. Do not infer
pure bonus strength from the same goal wrapper: current civilization-specific
AI personalities still change expansion and other decisions. Balance evidence must include
mirror matches, seat rotations, map families, and intended routes. A faction is
healthy when it has a strong context, a legible counter, and a fallback that
does not require a perfect start—not when every aggregate share equals 10%.

The Scholar opening bonus is a priority test because the existing measurement
shows 1 versus 3 science in one fixture. Test whether reducing its opening
discontinuity while adding conditional research proofs preserves identity and
improves strategic choice; do not pre-commit to a numeric nerf.

## 7. Conditional, visible victory routes

Keep the route concepts and make each route pass four tests:

1. **Eligibility:** a competent player can determine by a checkpoint whether
   the geography/resources/diplomacy make the route viable.
2. **Preparation:** the route requires several meaningful investments, not a
   hidden final queue.
3. **Contest:** opponents receive a visible, actionable response window.
4. **Recovery:** a blocked route can pivot to a credible alternative without
   discarding the whole empire.

Suggested route contract:

| Route | Preserve | Add/verify |
| --- | --- | --- |
| Industrial | rail geography, stations, network, hold timer | complementary city contributions instead of three identical factory checklists; feasibility preview, freight fallback, disruption and visible timer |
| End/expedition | staged Create/Minecraft project chain | make End Archive/knowledge contribute before the final race; expose staging, supply, and interruption |
| Diplomatic | Council, delegates, village relationships, support requirement | route progress and counter-diplomacy; no silent election surprise; measure two-player structural veto separately |
| Conquest | capitals, movement, terrain, walls, support | upgrades, supply, elimination lifecycle, and non-conquest defensive recovery |
| Score/round limit | fallback for unfinished games | report as a genuine draw/score result, not a hidden victory substitute |

Conditional fairness is measured as both unconditional outcome share and route-
conditional success. A route that wins 60% of attempts but is reachable in only
10% of maps is not equivalent to a route with 40% success and 80% reachability.
Use the estimands and denominators in `EXPERIMENT_PROTOCOL.md`.

### Industrial victory should reward complementary cities

The current local Industrial Complex dependency closure is 13 buildings and
890 industry, repeated in three cities before network/hold requirements.
Simply adding focus slots while retaining that qualification would conflict
with specialization: the victory would still demand three copies of the same
city. The preferred first prototype replaces qualification with three linked
contributions: an Assembly Works producing machinery, a Knowledge Works
producing control/research proofs, and a Freight Hub delivering network
throughput. Preserve a visible hold period and make supply interruption a
counter. Calibrate the aggregate investment against the current route; this
proposal does not assert that three cheap role markers equal its cost.

Civ VI's Campus/Industrial Zone/Commercial Hub distinction is the detailed
reference: a Library in a Campus produces science and scientist points, while
a Commercial Hub project produces gold and merchant points, and Industrial
Zone Logistics supplies power and engineer points. Different cities support
the same empire through different outputs. CivCraft can express that through
Create machinery, knowledge and rail freight without requiring district tiles.
The prototype must measure whether three settlements remain an appropriate
minimum; population/focus thresholds must not make every victory demand the
same expansion count. See [the sourced Civ VI comparison](CIV6_COMPARISON.md)
and [the earlier detailed project references](../civ6-balance-2026-10-26/SPECIALIZATION-FACTIONS-VICTORY.md).

### Two-player diplomatic veto (structural issue)

The current Council resolution requires a two-thirds threshold and a supporting
member. With two players, the rival is therefore able to veto the diplomatic
victory; there is no unilateral two-player path under the current rule. This is
not evidence that the diplomatic AI is weak, and it must not be “fixed” by
quietly granting a bonus or treating two-player diplomacy as a failed policy.
Keep it as a documented topology issue. A future candidate may define a
two-player unilateral threshold, neutral Council support, or a separate
two-player contract, but each option needs its own counter-diplomacy and route-
fairness experiment. Until then, report two-player diplomacy separately from
3–4-player diplomatic fairness.

## 8. Recoverability without rubber-banding

Use systems that preserve player agency and the value of earlier decisions:

- keep retained research/project progress;
- test bounded research/production overflow after completion;
- preserve XP and equipment through upgrades;
- let damaged cities/armies rebuild through supply and refit investments;
- make route pivoting possible through shared infrastructure and repeatables;
- reveal route threats and hostile bugs rather than secretly compensating;
- allow diplomacy, villages, trade, and defensive terrain to buy time.

Avoid hidden catch-up yields, free units, or research bonuses granted solely to
the loser. Measure a single moderate mistake from identical checkpoints and
separate it from sustained poor play. Acceptance is a lower win probability and
delayed milestone—not automatic elimination—after one plausible error.

## 9. Content triage and compatibility choices

Classify existing content before adding more:

- **Keep as milestone:** content that changes legal actions or opens a branch
  (Create machinery, rail, End preparation, walls, naval access).
- **Specialize:** flat yield buildings that can define Research, Works,
  Logistics, Military, Harbor, Food, or Diplomacy focuses.
- **Convert to repeatable:** late industry/science/rail/village projects whose
  one-time effect expires before the route can use it.
- **Differentiate/upgrade:** duplicate engineers, healers, and near-identical
  factory steps.
- **Repair or retire:** inert horses/saltpeter, End Archive if it remains
  disconnected from any route, and leaves that neither unlock, counter, nor
  repay within the remaining horizon.

Keep the current buildings in the baseline while instrumenting payback
horizon, focus competition, route use and actual completion. The proposed
Industrial qualification changes which complementary contributions are
required; it does not automatically delete the existing building content.
Reorganize prerequisites only in a reviewed candidate. A content item may
remain situational; “not built in every game” is not by itself a defect.

## 10. Review gates

No design candidate advances to gameplay review until it has:

- authoritative engine parity, deterministic replay, and migration coverage;
- a current-HEAD baseline with completion/error accounting;
- matched seed/seat/civ/policy results with cluster intervals;
- route-conditional and unconditional reports;
- AI fixed-policy and adapted-policy evaluation;
- pacing, route diversity, combat breakpoint, and recoverability deltas;
- UI/report previews and a rollback/config flag;
- explicit confirmation that the candidate did not create a mandatory build
  order, map-infeasible victory, or hidden AI advantage.

The intended outcome is a more legible game with specialized settlements,
durable armies, meaningful repeatable work, distinct factions, and contestable
victory races—not numerical imitation of Civ VI.
