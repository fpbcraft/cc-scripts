# Research completion audit

**Historical audit snapshot.** Several measurements below have since been
extended, including the 152-game faction/map matrix, 28 multiplayer games,
96-game outcome-model study, expanded observer proposals, requested H1
healing change and coordinated siege follow-up. Use the
[current requirements matrix](REQUIREMENTS_MATRIX.md) for present evidence
and remaining scope. This audit neither proves completion nor adds an
approval requirement beyond the supplied goal specification.

Date: 27 October 2026
Scope: authoritative `GOAL_SPECIFICATION.md` A–J, current source tree, current lab artifacts, and the source-frozen research results available at this audit.
Status: **not complete**. This is an evidence audit, not approval to change live rules.

## Executive finding

The project now has a substantial, reusable research spine: a source-aware content/lifecycle inventory, a Civ VI reference catalog and comparison, a shared Lua-runtime lab adapter, bounded workers, observer projections, reproducibility manifests, several controlled pilots, an adversarial archive, and a corrected native compact-policy comparison. The documents and pilots are useful enough to guide implementation review.

The research goal is not yet satisfied as a credible current-head balance measurement system. The largest open evidence gaps are still actual-engine conformance coverage, a representative baseline with competent and route-comparable controllers, and conditional victory/fairness estimates. The hostile-processing error, incomplete legal-action enumeration, dead-seat/elimination semantics, and narrow/confounded policy samples prevent a clean claim about present balance. The goal must remain active.

This conclusion does **not** require implementing the proposed gameplay redesign first. The specification deliberately makes research/planning precede rebalancing. Specialized cities, repeatables, army refits, victory-route changes, and save migrations remain review-gated downstream work. Conversely, “the design is only a proposal” does not close the research gaps above.

## Evidence ledger

| Area | Current evidence | Status | What is actually proven |
|---|---|---|---|
| A — current source/content/lifecycle audit | [`CURRENT_STATE_AUDIT.md`](CURRENT_STATE_AUDIT.md), source manifests, runtime inventories, lifecycle extraction, content and victory audits | **Substantial / partial** | The current Create rules, six Ages, 180-round Standard frame, cities/units/buildings/technologies, five victory families, fog, diplomacy, hostiles, AI and lifecycle seams are documented. The audit also records retained research/project progress, discarded overflow, rail requirements, and the absence of a complete eliminated-player lifecycle. It is not proof that every late native/UI/rednet path is healthy. |
| B — Civ VI comparison | [`CIV6_COMPARISON.md`](CIV6_COMPARISON.md), [`civ6-balance-2026-10-26/`](../civ6-balance-2026-10-26/), CSV extracts and public-entry catalog | **Substantial / partial** | The comparison covers research pacing, boosts, districts/specialists, buildings, units/upgrades, projects, victories, policy opportunity cost and counterplay. The catalog parser issue that made every technology appear Ancient has been corrected. Current static QA reports 555 catalog entries, including 53 wonders and 83 projects; those are catalog/reference counts, not ordinary-game availability counts. |
| C — quantitative baseline | [`BASELINE_BALANCE_REPORT.md`](BASELINE_BALANCE_REPORT.md), route cross-play, faction/personality pilots, archive adaptation, recovery, outcome model, raw JSON results | **Partial** | There is real error-accounted evidence, including 24 route-crossplay games, 36 fixed-goal faction games plus 36 personality ablations, 32 archive-adaptation games, eight mistake continuations, and a separate hostile pilot with two engine errors. These are source-frozen pilots, not a balanced factorial tournament: controller competence, seats, geography, factions, hostile conditions and route intent remain confounded or underpowered. |
| D — one authoritative simulator | [`SIMULATION_ARCHITECTURE.md`](SIMULATION_ARCHITECTURE.md), `match_lifecycle.lua`, `actor_lifecycle.lua`, lab Runtime adapter, native/offline checks | **Implemented vertical slice / partial conformance** | The lab uses the authoritative Lua lifecycle and `Actions.apply`; it does not maintain an independent Python economy/combat model. `newGame`, observe/projection, legal-action proposal, apply, end-turn/advance, finish and metrics seams exist. Observer privacy, deterministic seed fixtures, a full selected-policy native match, 54 native parity checks, 21 narrow war/capture/save checks, and 75 observer/Surprise-War/trace checks provide meaningful evidence. Candidate enumeration is intentionally incomplete; full action/reaction replay, old saves, rednet, broader multiplayer and complete native runtime coverage are still open. |
| D — legality/privacy/determinism | `Presentation.capture`, privacy/rejection tests, parity fixtures, conformance reports | **Partial** | The projection boundary and illegal-proposal rejection are tested for covered fields. The evidence does not certify every action family or every event projection. A known `hostiles.lua:103` orphan-settler error is reproduced and symmetrically disabled in one continuation fixture; it remains an engine defect, not an accepted standard-hostile result. |
| D — bounded execution | worker watchdogs, Lua instruction/action budgets, host benchmark and CPU/RSS scaling results | **Initial implementation / partial** | Short 1/2/4-worker studies complete with identical outcomes and bounded processes. Sustained thermal behavior, broad workloads, resumability, and the complete conformance matrix are not established. |
| E1/E2 — policy API and evolution | [`AI_ML_RESEARCH_PLAN.md`](AI_ML_RESEARCH_PLAN.md), `evolve.py`, clean strategy search and economic-only pilot | **Partial** | The policy interfaces, specialist goals, noise/mistake controls and ES workflow are real. A clean strategy search reached 0.75 versus 0.25 held-out credit in its declared small evaluation; the economic-only pilot showed no gain. This does not establish comparable conquest, diplomacy, expansion or defense competence. |
| E3 — archived adversarial league | archive manifest, 24-game crossplay, 32-game archive adaptation | **Partial** | Archive provenance, seats, source hashes and holdouts are recorded. The selected Expedition controller won 12/12 against an unequal mixture; one adapted controller earned 3/4 held-out credit against its prior champion. This demonstrates a usable league mechanism, not route fairness or a strong universal teacher. Cycling, regression, more factions/maps and competent route controllers remain needed. |
| E4 — hierarchical/RL track | AI plan, throughput/parity gates, Gym design | **Planned / conditional** | The design is appropriately gated on parity, throughput and value. No neural-RL superiority, deployment, or claim of completed Gym parity is made. The goal does not require forcing an RL result where rule-based/ES baselines answer the research question. |
| E5 — compact native policy export | corrected [`POLICY_FORMAT_COMPARISON.md`](POLICY_FORMAT_COMPARISON.md), actual traces, oracle control, 24-match retention, native benchmark | **Partial; useful negative result** | Actual source-ranked recommendation traces contain 2,952 records from four complete games with game/seed holdout. The corrected adapter preserves `AI.choose`/`AI.research` and patches only ranker seams; the oracle matches all four baseline final hashes. Weights, tree and tiny MLP all run natively with Python/Lua prediction parity; current compact rankers fail the narrow full-game retention gate (weights target 1/4, tree 0/4, MLP 0/4). Tree’s 99.26% trace agreement is inflated by 85.28% source-ranked fallback. The existing 207-byte strategic policy is a separate already-validated task and must not be conflated with these rankers. |
| F — auxiliary ML/surrogates | outcome-model manifest/report and separate-map-block logistic critic | **Partial, correctly bounded** | The privileged critic beat a constant baseline on its declared split (Brier 0.1700 versus 0.2500), but has one map block per split and is not a calibrated recovery or rules surrogate. The true engine remains authoritative. |
| G — pacing/fairness/recoverability | [`EXPERIMENT_PROTOCOL.md`](EXPERIMENT_PROTOCOL.md), route/intention estimands, recoverability pilot, outcome reports | **Partial / major gap** | The protocol distinguishes unconditional outcome share from conditional route fairness and intended strategy versus actual victory, records censor/error denominators, and includes checkpoint branches. Four recovery cases show legal research diversion delaying two wins by 10/11 rounds and reversing one baseline win. There is no reliable broad conditional estimate yet because route controllers are not comparably strong and samples are small. |
| H — issue register/design/roadmap | [`BALANCE_ISSUES.md`](BALANCE_ISSUES.md), [`REDESIGN_PROPOSAL.md`](REDESIGN_PROPOSAL.md), [`IMPLEMENTATION_ROADMAP.md`](IMPLEMENTATION_ROADMAP.md) | **Draft complete / gameplay unimplemented** | The proposal preserves existing choices and Minecraft/Create identity, rejects blanket expansion research tax and mandatory Civ-style districts, and makes specialisation, repeatables, quality armies, route feasibility and faction identity explicit hypotheses with review gates. It is not evidence that any proposed value is balanced. |
| I — named documentation/artifacts | lab README/index, ten named docs, datasets, manifests, raw results and scripts | **Files present / evidence varies** | All ten named deliverables exist. A filename or plausible plan is not a passing experiment; the statuses above are the authoritative interpretation. |
| J — staged order/boundaries | `GOAL_SPECIFICATION.md`, requirements matrix, roadmap, source-freeze manifests | **Partially executed** | Research-only boundaries have been respected: no live gameplay rebalance, trained model deployment, or unreviewed save migration was applied. Later lifecycle, baseline, design and release gates remain open. |

## Current static and opening facts

These facts should remain separate from match timing claims:

- The current opening audit records roughly 24 science with 1 base frozen income and an AI reaching two cities at round 3. This is an opening-clock observation to validate across seeds, not a universal opening balance claim.
- The current victory dependency audit finds 18 shared technologies between the Industrial and Expedition closures. Each static route closure is 24 technologies: Industrial/Bank has base global science 1,776 and 2,670 industry across three required copies (890 local); Expedition/Dragon has base global science 1,744 and 728 local industry.
- The 2,670/728 values are dependency-cost arithmetic. Industrial local production can run in parallel and also requires network/hold conditions; they must not be converted into a “turn ratio”. The audit explicitly excludes staffing, city founding, travel, rail construction and changing yields.
- The current static counts support the design hypothesis that Industrial can feel like a repeated local-closure burden while Expedition reaches a terminal chain with less local production, but they do not identify the causal match pacing without controlled runs.

## Coherence review of the central proposal

`REDESIGN_PROPOSAL.md` and `IMPLEMENTATION_ROADMAP.md` are coherent with the specification when read as review material rather than approved changes:

- They preserve the existing Create/Minecraft theme, factions, victories and player choices while proposing specialised city roles, repeatables, quality army upgrades and visible victory-route feasibility.
- They correctly avoid a blanket research tax on expansion. Expansion’s opportunity cost should be measured through production, maintenance, settlers, protection, city focus and route commitment rather than by making every technology more expensive after each city.
- They correctly avoid mandatory Civ VI-style districts. Civ VI’s district opportunity cost is a useful comparison, not a reason to add a second mandatory placement system to CivCraft.
- They retain progress deliberately, so the claim that progress retention “removes all opportunity cost” is false: switching still delays completion, consumes a city/slot/turn window and can miss a route or contest. The real question is whether current retained progress is too forgiving or too opaque; that needs telemetry and matched switching experiments.
- They identify the End/Archive terminal-content risk, duplicate engineer/healer roles, filler factory-chain risk, rail geography requirements and game-speed inconsistencies as hypotheses to test. They do not silently turn these into approved nerfs.
- The two-player diplomatic route still has a structural veto because a win requires the rival vote. The proposal records this as a design issue; no unilateral diplomatic path should be implemented as part of this research audit.

## Highest remaining gaps requiring actual work

These are ordered by how much they threaten the validity of every later balance conclusion.

### 1. Finish authoritative lifecycle and conformance coverage

Actual work is required to classify or fix the active-hostile orphan-settler error, define eliminated/dead-seat behavior, and complete legal-action enumeration across production, research, movement, settlement, war, diplomacy, projects, rail and victory proposals. Add full native/offline hash fixtures for Surprise War, old saves/migration, rednet/multiplayer projection, hostile processing and victory resolution. Do not hide the known error by counting it as a loss or silently dropping the game.

### 2. Run a current-head factorial baseline with competent controls

Build a representative, source-frozen matrix over map/start position, player count, seat, faction, speed, hostile setting and policy family. Include original, specialist, adapted and route-capable controllers with explicit competence gates. Pre-register timeout/error/censor handling, cluster intervals by map seed, holdout seeds, multiple-comparison handling and the minimum cell size. The existing 24/36/32-game pilots are inputs to this matrix, not substitutes for it.

### 3. Measure conditional victory fairness and intended-versus-actual routes

For each route, report both unconditional winner share and the conditional estimand among games where the route was intended and feasible. Record route eligibility, route commitment, actual victory, failure reason, round and map geography. A weak Expedition-versus-Industrial crossplay cannot answer whether Industrial is overpowered; it only shows the controllers were not comparably strong. Keep the diplomatic structural-veto issue separate from controller strength.

### 4. Validate pacing and recoverability at decision boundaries

Measure opening milestones, first expansion, first specialist/specialised city, first meaningful military contact, research completion, route eligibility, terminal project start and victory by seed/speed. Expand recovery branches beyond research diversion to expansion, military, diplomatic and project-switch mistakes. Report paired deltas and cluster intervals, not anecdotes or aggregate win counts.

### 5. Consolidate the AI evidence before any deployment decision

Keep the native-validated 207-byte strategic policy as its own task. Keep the actual 15-feature ranker experiment as a negative/diagnostic result until a candidate clears full-game retention on held-out games and route/faction cells. Improve the ranker only if the measurement question needs it; do not start hierarchical RL or ship a model to compensate for incomplete game semantics.

### 6. Only then prototype and review gameplay candidates

After the baseline, implement versioned, opt-in research branches for city focus/specialisation, repeatable overflow sinks, army refit/quality, and route-feasibility/rail alternatives. Evaluate one causal change at a time with migration and rollback plans. These are real future implementation tasks, but they are not a prerequisite for declaring the documentation/prototype stage complete; neither should their approval be implied by this audit.

## Research-phase exit gate

The research phase can be reconsidered when all of the following are true:

1. A current source hash and artifact ledger cover the rules, runner, policy and feature extractor used in every reported baseline.
2. The hostile error is fixed or explicitly excluded by a documented, user-visible scope decision; elimination/dead-seat semantics and the legal-action contract are tested.
3. The authoritative simulator passes the expanded native/offline conformance suite, including save/load and observer privacy, with no independent Python rules model.
4. A representative baseline has finished-game/error/censor accounting, clustered uncertainty, holdout seeds and comparably capable route controls.
5. Victory reporting includes conditional route fairness, intended strategy versus actual victory, faction/seat/map controls and recoverability—not only unconditional winner shares.
6. The ten documents and result indexes agree on current numbers, historical invalid artifacts and known limitations. In particular, the corrected compact-policy values are 4,467 bytes/85.28% fallback for the tree and 94.83% MLP versus 93.75% weights on held-out recommendations; none is described as a strong deployed controller.

Passing this gate would complete the measurement/research objective while still leaving gameplay candidate review, implementation, migration, UI and release validation as separate decisions. It would be incorrect to mark the overall CivCraft balance goal complete before this gate.

## Audit conclusion

**Proven:** a meaningful source-aware research platform, catalog, documentation set, controlled pilot history, corrected policy-format controls, and several useful negative results.
**Partial:** baseline pacing, policy competence, simulator conformance, recovery, compact-model retention and static route diagnosis.
**Missing:** representative current-head causal balance evidence, conditional route fairness with comparable controllers, complete lifecycle/action coverage and native multiplayer/hostile/save conformance.
**Deferred by design:** gameplay rebalance, new city/victory mechanics, model deployment, save migration and release approval.

No gameplay files were changed by this audit.
