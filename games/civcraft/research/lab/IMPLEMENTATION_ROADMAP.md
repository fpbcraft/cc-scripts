P1 implementation status: [approved prototype and validation](P1_IMPLEMENTATION.md).

# CivCraft balance redesign implementation roadmap

Latest review sequence: [FIRST_CHANGE_PACKAGE.md](FIRST_CHANGE_PACKAGE.md).
Its explicit prototype parameters refine earlier candidate ranges. H1 is the
user-requested implemented healing exception; P1 is now approved and implemented as a prototype; P2–P4 still require review. Research gaps do not require waiting for perfect AI before
prototyping a reviewed gameplay package.


Status: implementation plan only. No gameplay rebalance, new content, save
migration, live AI deployment, or trained model is authorized by this document.
The parent workstream is building behavior-preserving shared lifecycle seams,
a Lupa 5.3 simulation runner, policy/ES tests, and parity fixtures. This
roadmap consumes those artifacts and makes every gameplay candidate reviewable
and reversible.

## 1. Delivery rules

Work in this order:

```text
authoritative lifecycle/parity
  -> current-HEAD baseline and telemetry
  -> isolated opening/overflow candidates
  -> city focus and repeatable candidates
  -> army upgrades/combat/resource candidates
  -> faction/victory calibration
  -> AI adaptation and compact-policy evaluation
  -> human review, migration, release
```

The order is a dependency graph, not permission to change all systems in one
branch. Each phase produces a versioned config and can be evaluated against the
unchanged baseline. A candidate that fails its gate is archived with its replay
and does not become a hidden prerequisite for the next phase.

Non-negotiables:

- `Actions.apply()` and the observer projection remain authoritative for human,
  AI, native, and CraftOS play.
- The current `ruleset='create'`, six Ages, Minecraft/Create content, saves,
  multiplayer, fog, scheduler, and UI remain the compatibility baseline until
  an approved candidate replaces a specific behavior.
- Research/project progress retention remains unless a measured experiment
  proves it harmful. Do not describe it as free switching; the current stream
  still consumes that round's output.
- No city research tax, mandatory full Civ VI district layer, resource cheat,
  hidden catch-up bonus, or automatic gameplay tuning is introduced.
- Every result states whether it is a current fact, a design hypothesis, an
  executed pilot observation, or an unexecuted test requirement.

## 2. Baseline evidence to preserve

The current pilot artifact `/tmp/civcraft-lab-pilot-results.json` is copied or
referenced with its checksum in BASELINE_BALANCE_REPORT.md; it is not rewritten.
It contains seven configured matches: five finished and two errors. The
Compact/Pangaea Forge mirror reached the existing Industrial result at round
149. Two seed-95117 standard-hostile matches stopped around rounds 14 and 17
with `hostiles.lua:103: table index is nil` in the hostile spawner. The other
finished fixtures include Scholar/Iron seat swaps and a four-player compact
Continents case. This is enough to expose a runner and a reproducible hostile
bug, but not enough to claim civilization parity, route fairness, strong play,
or ML strength.

The archived Forge mirror and static inventories remain historical evidence
with their original source revisions. Before any balance comparison, regenerate
the same fixture at the current working-tree revision and add independent
seeds, seat rotations, policies, map families, and error accounting.

Additional executed pilots are now available but remain exploratory:

- `results/strategy_search_pilot.json`: one training seed, two evaluation
  seeds, population 3, two generations, two workers; selected expedition
  weights scored 0.75 on eight held-out Forge seat games versus 0.25 for the
  baseline's eight. This is a policy-search result, not route/faction balance.
- `results/recoverability_pilot.json`: four matched round-10 Forge/no-hostiles
  legal `Sailing` research-diversion cases on two seeds; two wins were delayed
  10/11 rounds,
  one baseline win became a diversion loss, and one pair retained winner and
  round. This is not a general mistake-tolerance estimate.
- `results/route_crossplay.json`: 24-game reported route-controller
  slice, selected expedition 12/12 credited wins and conquest 0/12. The goal
  controllers were not comparably strong and used one faction/two seeds, so
  this cannot establish intrinsic route balance.
- `results/adversarial_archive_adaptation_pilot.json`: archive adaptation using
  the existing runner/evolution helpers. Training selected an expedition
  mutant at 1.00 over four Forge/no-hostiles games against the archived
  expedition-plus-industrial mixture. Holdout previous-champion mirror was
  0.50/0.50, while previous-champion versus adapted counter was 0.25/0.75 over four
  finished games per cell on seeds `808381` and `919393`. This is a narrow
  policy smoke result; all valid candidates, source hashes, Lua archives, raw
  paths, and zero-error/censor status are recorded. Throughput is confounded.

The roadmap must preserve these artifacts and their limitations in the
eventual baseline report; it must not convert them into release thresholds.

## 3. Phase 0 — source freeze, branch contract, and artifact ledger

**Purpose:** make the experiment and implementation boundary explicit before
touching rules.

**Tasks**

1. Record the current commit, dirty working-tree files, Lua/runtime versions,
   content revision, campaign version, and pilot checksum.
2. Create a candidate configuration namespace separate from production
   `ruleset='create'`; candidate IDs must appear in state hashes and reports.
3. Link the current content inventory, Civ VI catalog, state audit, issue
   register, experiment protocol, and AI plan. Treat old numbers as historical
   when their revision differs from the current source.
4. Define the policy-config schema and baseline `baseline-current-v1` without
   changing current AI choices. Store policy checksum, seed pool, and action
   budget in every match manifest.

**Likely files/artifacts**

- `games/civcraft/research/lab/pilot_manifest.json`
- `games/civcraft/research/lab/EXPERIMENT_PROTOCOL.md`
- `games/civcraft/research/lab/AI_ML_RESEARCH_PLAN.md`
- `games/civcraft/ai_*.lua` policy adapter (behavior-preserving)
- future `research/lab/configs/*.json` and compact result manifests

**Dependencies:** none. **Gate:** a clean manifest can replay one baseline
match and identify every source/runtime revision; no balance conclusions are
made from the seven-match pilot alone.

## 4. Phase 1 — authoritative lifecycle and parity

**Purpose:** make real CivCraft the simulation instrument before changing
balance values.

**Tasks**

1. Complete the behavior-preserving seams in `match_lifecycle.lua` and
   `actor_lifecycle.lua`; keep `game.lua` as the CraftOS/UI/network adapter.
2. Provide the proposed contract: `newGame`, `observe`, `legalActions`,
   `applyAction`, `endTurn`, `isFinished`, and compact `metrics`.
3. Preserve observer/fog semantics from `world.lua`, `presentation.lua`, and
   snapshots. Add action masks without granting full-state access.
4. Define per-action, per-player, per-round budgets; invalid-action handling;
   timeout/abort statuses; eliminated/dead-seat behavior; and deterministic
   fallback. Record them separately from gameplay losses.
5. Extend native/CraftOS conformance beyond the existing peaceful 2/4-player
   three-round fixture: war scheduler/reactions, fog, save/reload, all victory
   routes, hostile/village turns, and network projection.
6. Preserve the reproduced hostile seed-95117 failure at `hostiles.lua:103`.
   Add a reviewed runtime-invariant repair and regression test before treating
   standard-hostile balance sweeps as clean; the behavior-preserving research
   extraction intentionally has not changed hostile gameplay. Do not quietly treat the error as a loss.

**Files**

`game.lua`, `match_lifecycle.lua`, `actor_lifecycle.lua`, `actions.lua`,
`turn_scheduler.lua`, `systems.lua`, `world.lua`, `presentation.lua`,
`snapshots.lua`, `saves.lua`, `victory.lua`, `hostiles.lua`, and parity tests.

**Acceptance gate**

- identical initial state/action replay has zero unexplained authoritative or
  observer divergence across 100 deterministic fixtures;
- every victory, draw, timeout, invalid-action, hostile failure, and save case
  has an explicit terminal status;
- fog and scheduler group semantics remain unchanged;
- the benchmark reports games/hour, CPU time/turn, memory, and error rate before
  any throughput target is claimed.

**Rollback:** retain the pre-extraction CraftOS entry path and disable the
headless adapter by feature flag. Do not migrate saves for a parity-only seam.

## 5. Phase 2 — current-HEAD baseline and opening clocks

**Purpose:** measure the opening before changing research, expansion, or
production values.

**Tasks**

1. Run matched 2/3/4-player blocks across all current civilizations, mirrors,
   seat rotations, map families, player counts, speed presets, hostile modes,
   and fixed specialist/adaptive policies.
2. Record first research completion, first growth, first scout/guard/settler,
   city founding, first village/camp interaction, first contact/war, science/
   industry/gold, idle queues, and checkpoint leads.
3. Re-run the pilot's Forge/Scholar/Iron compositions at current HEAD. Retain
   the round-149 industrial fixture as a regression reference, not a target
   claim.
4. Test opening candidate changes in isolated toggles: early proof/boost,
   science-floor calibration, settler population/opportunity cost, and bounded
   production/science overflow. Keep a no-change control for every seed block.
5. Evaluate whether early Scholar is a genuine faction advantage after seat,
   map, policy, and intended-route controls; do not nerf it based on one seed.

**Files**

`campaign_rules.lua`, `content.lua`, `systems.lua`, `economy.lua`, `worldgen.lua`,
`ai_research.lua`, `ai_production.lua`, telemetry harnesses under
`games/civcraft/research/`, and opening/pacing fixtures under `tests/`.

**Acceptance gate**

- baseline completion/error rate is reported separately from outcomes;
- Standard pacing distributions and cluster intervals exist before candidate
  values are selected;
- candidate opening changes produce at least three viable first-20-round
  patterns in controlled policies, or the failure is documented;
- overflow conserves only the declared bounded amount and cannot pre-complete
  arbitrary future projects or duplicate modifiers;
- no candidate is accepted because it merely makes the current AI look better.

**Rollback:** candidate flags default false; save schema remains unchanged.

## 6. Phase 3 — soft city specialization

**Purpose:** create meaningful city identity without mandatory districts or
removing existing choices.

**Tasks**

1. Add data-driven focus categories and capacity to city state, with a
   migration default that gives existing cities the current unrestricted
   behavior until a candidate campaign opts in.
2. Map current buildings/projects to core, research, works, logistics,
   military, maritime, diplomacy, or food categories. Identify buildings that
   are conditional enablers rather than pure yields; do not force Dock/Walls/
   Fortress/Council Hall into economic slots without evidence.
3. Implement focus selection as a validated action with preview, cost, and
   reversible/pivot semantics. Show displaced effects before confirmation.
4. Add specialized-city metrics: focus occupancy, building payback, queue idle,
   city role changes, repeated universal chains, and empire-wide output.
5. Test tall/compact, wide/expansionist, science, works, military, maritime,
   and diplomatic policies. Include map/geography controls.

**Files**

`content.lua`, `systems.lua`, `actions.lua`, `economy.lua`, `campaign_rules.lua`,
`ai_city_roles.lua`, `ai_production.lua`, `ai_strategy.lua`,
`empire_menu.lua`, `game_view.lua`, `research_details.lua`, `reports.lua`,
`encyclopedia.lua`, and city/focus tests.

**Acceptance gate**

- focus changes are legal, deterministic, visible, and save-safe;
- at least three distinct city-role profiles remain viable under competent
  policies on appropriate maps;
- no universal “build every focus everywhere” policy dominates in held-out
  games unless the focus is intentionally core;
- city specialization changes route eligibility and opportunity cost without
  making a route impossible before its checkpoint is knowable;
- UI and observer projections agree with authoritative focus state.

**Rollback:** campaign candidate flag turns focus data off and treats all
existing cities as legacy-unlimited; no old save is rewritten in place.

## 7. Phase 4 — repeatable productive work

**Purpose:** give mature specialized cities worthwhile choices after their
milestone chain, while preventing infinite science/industry snowballing.

**Tasks**

1. Add a small data-driven operation schema: input materials/power/gold,
   category, cost, output, cooldown/cap, route interaction, and counter.
2. Prototype Workshop Batch, Research Proof, Freight Run, Arsenal Refit,
   Village Initiative, and Expedition Preparation as separate candidates.
3. Make repeatables compete with ordinary projects, unit refits, route
   preparation, and rail maintenance. Do not grant a free global output.
4. Add progress/capacity previews and interruption events. Log actual input,
   output, opportunity cost, route progress, and counter actions.
5. Test diminishing returns and remaining-horizon value. A late repeatable that
   cannot pay back before round 180 should be a conscious choice, not a hidden
   trap.

**Files**

`content.lua`, `systems.lua`, `economy.lua`, `victory.lua`, `railways.lua`,
`actions.lua`, `ai_infrastructure.lua`, `ai_materials.lua`, `ai_routes.lua`,
`ai_production.lua`, `reports.lua`, `event_feed.lua`, and operation tests.

**Acceptance gate**

- every repeatable has an input, a competing use, and a visible counter;
- no single repeatable supplies an unconditional dominant route across held-out
  maps/policies;
- input accounting is conserved through save/replay and speed presets;
- repeatables improve late-city decision density without shortening every route
  below its contest window;
- current Industrial and End fixtures remain mechanically reachable under the
  unchanged baseline candidate, or a difference is explicitly reviewed.

**Rollback:** remove operation availability from candidate content while
retaining harmless telemetry fields; do not delete saved operation history.

## 8. Phase 5 — quality armies, refits, and resource integrity

**Purpose:** make early military investment durable and reduce abrupt equipment
replacement while preserving strong Create-themed units.

**Tasks**

1. Add upgrade metadata and a validated refit action. Preserve experience,
   consume activation, and charge industry/material/gold in owned supply sites.
2. Build combat breakpoint matrices for same-tier, one-tier, terrain, wall,
   ranged, siege, support, and city cases. Calibrate stat spacing/damage curve
   only after the matrix exists.
3. Differentiate Engineer/Armored/Railway Engineer capabilities; differentiate
   Alchemist and Supply Crew. Preserve a recruitment choice where it is useful.
4. Separate strategic resource access, per-unit build cost, upkeep, exchange,
   and grace behavior. Decide explicitly whether horses/saltpeter are live or
   retired from the player-facing rules.
5. Add army supply/repair/refit telemetry and route disruption metrics. Verify
   that walls, escorts, terrain, villages, and diplomacy remain counters.

**Files**

`content.lua`, `combat.lua`, `combat_strength.lua`, `actions.lua`, `systems.lua`,
`economy.lua`, `railways.lua`, `unit_movement.lua`, `zone_control.lua`,
`ai_tactics.lua`, `ai_production.lua`, `ai_materials.lua`, `ai_routes.lua`,
`map_view.lua`, `inspector.lua`, `encyclopedia.lua`, and military/resource
tests.

**Acceptance gate**

- upgrade/recruit/refit actions obey normal ownership, cost, movement, fog, and
  scheduler rules;
- veteran experience survives the intended refits and save/replay;
- same-tier combats do not routinely collapse to one capped hit under ordinary
  conditions, while a prepared newer tier remains meaningfully better;
- every live strategic resource is generated, surfaced, consumed/used, and
  counterable, or is explicitly retired from claims;
- old army strategies have a legal, understandable migration path.

**Rollback:** candidate refits remain disabled; old unit IDs and combat formulas
remain selectable for old saves. Never silently reinterpret an old unit as a
new tier without a versioned migration.

## 9. Phase 6 — victory-route feasibility and interaction

**Purpose:** make victories conditional, visible, interruptible, and recoverable
without forcing equal raw shares.

**Tasks**

1. Add route feasibility diagnostics at checkpoints: resources, geography,
   stations, focus capacity, diplomacy, prerequisite technologies, and
   remaining horizon.
2. Industrial: preview corridor feasibility, station graph, material cost,
   hold timer, and disruption options. Test owned-territory gaps, neutral/open
   borders, islands, and freight alternatives before choosing a rule.
3. End: make knowledge/End Archive useful before the final projects; expose
   staging, preparation, supply, and an interruptible final window.
4. Council: display delegates, support requirements, relationship state, and
   counter-diplomacy. Do not turn the election into an unannounced timer.
5. Conquest: finish elimination lifecycle and dead-seat handling; expose
   defense/surrender/recovery states without granting free comeback power.
6. Route progress/events must respect fog and diplomacy. A public or scout-
   discoverable threat is required for a meaningful contest.
7. Record the current two-player Council structural veto separately: the
   two-thirds/supporting-member rule gives the rival a veto and leaves no
   unilateral diplomatic path. Do not implement a fix here; specify and test
   any future two-player contract as a separate candidate.

**Files**

`victory.lua`, `railways.lua`, `council.lua`, `council_rules.lua`,
`diplomacy.lua`, `hostility.lua`, `systems.lua`, `actions.lua`, `events.lua`,
`event_feed.lua`, `reports.lua`, `map_view.lua`, `council_view.lua`,
`diplomatic_perception.lua`, and victory/elimination tests.

**Acceptance gate**

- route feasibility is deterministic and does not reveal hidden map state;
- each final route step has a visible response window and at least one
  competent counter;
- route-conditional success and unconditional outcome share are reported
  separately with proper denominators;
- two-player diplomacy is not pooled with 3–4-player diplomacy while the
  structural veto remains; veto availability and route eligibility are logged;
- a blocked route can pivot in matched checkpoints without free resources;
- industrial, End, Council, conquest, and score/draw states have explicit
  terminal reasons and save/replay parity.

**Rollback:** route diagnostics/events can be hidden while authoritative route
rules remain baseline. Candidate corridor/final-step changes are config-gated;
old saves keep their original victory-rules version.

## 10. Phase 7 — faction identity and fair calibration

**Purpose:** tune asymmetric civilizations after the systemic opportunity-cost,
army, and route models exist.

**Tasks**

1. Export actual civilization fields from `content.lua` and classify each
   primary context, fallback route, counter, and map dependency.
2. Define a bounded identity budget: opening effects, specialist effects,
   conditional resource/terrain effects, and route effects are separately
   measured. Do not compare only aggregate 10% shares.
3. Run mirror/seat/matchup matrices with all current civilizations, specialist
   policies, adaptive policies, map families, player counts, and speed presets.
4. Tune Scholar's early science discontinuity, Forge/industrial compounding,
   Merchant/village effects, and any other outliers only after conditional
   route and unconditional results agree.
5. Check intended strategy versus actual victory and policy competence. A weak
   civ policy is not evidence of a weak civ.

**Files**

`content.lua`, `civilization_picker.lua`, `faction_view.lua`,
`faction_colors.lua`, `ai_personalities.lua`, `ai_strategy.lua`,
`ai_economy_values.lua`, `ai_research.lua`, `ai_production.lua`,
`ai_routes.lua`, and civilization/route fixtures.

**Acceptance gate**

- all civs have at least one viable primary context and a credible fallback
  under appropriate conditions;
- no civ dominates across the pre-registered broad matchup/map/policy suite
  after multiplicity control, while context advantages remain visible;
- seat and starting-position effects are separated from faction effects;
- moderate errors reduce expected outcome without routinely making recovery
  impossible;
- changes do not collapse strategic diversity into one universal opening.

**Rollback:** retain identity version in campaign config. Old saves use the
old identity table; new candidates are not silently applied to existing games.

## 11. Phase 8 — AI adaptation and ML evaluation

**Purpose:** ensure the redesign is not accepted or rejected solely through a
weak policy, and produce no unreviewed live AI.

**Tasks**

1. Add focus, repeatable, refit, route-feasibility, and counterplay features to
   the versioned policy adapter while retaining current-policy behavior as the
   baseline.
2. Preserve the executed bounded strategy-search pilot as a smoke artifact;
   its 0.75 versus 0.25 Forge holdout result is not a deployment threshold.
   Preserve the separate archive-adaptation result as a second smoke artifact:
   0.25 baseline versus 0.75 selected counter on its four-game-per-cell
   holdout. Run specialist/adaptive policies before expanding evolutionary
   search. Keep the policy's intended route and plan revisions in telemetry.
3. Run ES/genetic/CMA-ES on bounded weights using training seeds only; evaluate
   validation, archived league, and untouched holdout policies/maps with
   comparably strong opponents and multiple factions.
4. Classify wins as gameplay dominance, policy blind spot, rule violation,
   simulator divergence, objective degeneracy, or measurement artifact.
5. Do not begin Gym/RL until parity and throughput gates pass. Do not export a
   Lua policy until full-game strength retention and CraftOS latency/memory
   tests pass.

**Files**

`ai.lua`, `ai_strategy.lua`, `ai_research.lua`, `ai_production.lua`,
`ai_economy_values.lua`, `ai_workers.lua`, `ai_tactics.lua`, `ai_materials.lua`,
`ai_routes.lua`, `ai_difficulty.lua`, and `research/lab` orchestration/artifact
manifests.

**Acceptance gate**

- candidate policies use only legal observer actions;
- fixed and adapted policies are both evaluated after each candidate rule;
- improvements generalize to held-out seeds/opponents and do not rely on mirror
  play or a proxy score;
- league regressions and exploits have replayable traces;
- no training-executed or deployed-AI claim is made without stored run output.

**Rollback:** live AI remains `baseline-current-v1`; candidate weights/models
are offline artifacts only.

## 12. Phase 9 — UX, saves, and player-visible review

**Purpose:** ensure a mechanically sound candidate is understandable and safe
before a gameplay release.

**Tasks**

1. Add queue previews for focus displacement, repeatable inputs/outputs,
   upgrade costs, route feasibility, and victory contest windows.
2. Add report/event fields for current plan, route progress, counters, resource
   shortages, hostile failure diagnostics, and recoverability-relevant state.
3. Add encyclopedia entries for all live unit upgrade paths, specializations,
   operations, resource uses, and faction fallback identities.
4. Design a versioned save migration only after candidate rules are approved.
   Preserve map, territory, progress, XP, diplomacy, and route state; do not
   invent missing focus/operation state without an explicit default.
5. Test CraftOS monitor, hotseat handoff, rednet projection, save/reload, and
   low-resource/late-game rendering with candidate state.

**Files**

`ui.lua`, `game_view.lua`, `map_view.lua`, `empire_menu.lua`,
`research_details.lua`, `reports.lua`, `event_feed.lua`, `event_summary.lua`,
`encyclopedia.lua`, `inspector.lua`, `faction_view.lua`, `saves.lua`,
`systems.lua`, and UI/network/save tests.

**Acceptance gate**

- a player can see why a focus, repeatable, refit, or route is available and
  what it displaces;
- fog/privacy is preserved in all previews and reports;
- old saves load without losing cities, units, diplomacy, research, or route
  progress, or are rejected with a recoverable version message;
- interactive CraftOS/rednet behavior is tested separately from headless
  simulation claims.

## 13. Phase 10 — release review and rollback plan

Gameplay rebalance is eligible for review only when it has:

1. authoritative parity and current-HEAD baseline evidence;
2. pilot/main/holdout reports with cluster intervals and an error ledger;
3. route-conditional/unconditional fairness and intended/actual matrices;
4. specialized-city, repeatable, army, faction, victory, and recoverability
   acceptance results;
5. fixed and adapted AI/league results with no hidden policy cheat;
6. UI, save, multiplayer, rednet, and native CraftOS validation;
7. a migration version, feature flag, replay compatibility decision, and
   documented rollback owner.

Release strategy:

- keep the old ruleset selectable for one review cycle;
- ship candidate content/config and telemetry behind a versioned campaign flag;
- preserve old save behavior through the old rules version;
- archive candidate replays and hashes;
- if a regression appears, disable the candidate flag and retain diagnostics;
- only remove old paths after a separate migration/cleanup review.

## 14. Final acceptance philosophy

The redesign succeeds when the game produces more meaningful decisions, not
when every item is used equally or every civilization wins the same percentage.
The strongest evidence will show that:

- cities specialize because their focus choices change the next best action;
- repeatables keep mature cities relevant without an infinite dominant faucet;
- armies improve through quality/refit and retain veteran value;
- factions have recognizable contexts and fair fallbacks;
- victories remain conditional, visible, interruptible, and geographically
  feasible;
- a moderate mistake delays a plan rather than ending the campaign;
- stronger policies improve results without invalid actions or hidden state;
- current successful arcs, including the round-149 Industrial fixture, are not
  accidentally destroyed by an untested global tax or content rewrite.

Until those claims are demonstrated on the protocol's holdouts, this roadmap is
an implementation sequence and review contract, not a declaration that the
proposed mechanics are balanced.
