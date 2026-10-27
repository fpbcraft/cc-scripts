# CivCraft AI and ML Research Plan

Status: planning with bounded pilot evidence. A small source-frozen strategy
search has executed, but no deployable/learned policy is approved for live
gameplay and no broad training run has been completed. This plan uses the
current Lua decision system as the baseline and keeps the Minecraft/Create
rules authoritative.

The immediate objective is not “add neural AI.” It is to build a credible
measurement instrument, expose the existing policy's real knobs, improve those
knobs with CPU-friendly search, and only then decide whether a hierarchical
learned controller earns its complexity.

## 1. Current policy surface to make versioned

The current code already has useful, interpretable controls. A research adapter
should pass these as an immutable `policyConfig` rather than scattering new
constants through gameplay code. The adapter must preserve the current values
for the `baseline-current-v1` policy.

| Policy family | Existing control | Current source/role |
| --- | --- | --- |
| Economy | food, industry, science, and gold context weights; specialization multipliers | `ai_economy_values.lua` / city queue valuation |
| Dependency planning | prerequisite decay `0.78`; target/dependency weights | `Values.dependencies`, `ai_research.lua`, `ai_production.lua` |
| Research | terminal target weights 48 (general), 25 (tactics), 65 (engineering), 50 (sailing); building effect multiplier 1.2; owned-resource bonus 3 | `ai_research.lua` |
| Research horizon | score divisor `sqrt(turns)` (exponent 0.5); emergency unit-improvement multiplier | `ai_research.lua` |
| Production | building effect multiplier 12; project denominator `2 + turns`; wonder multiplier 8 | `ai_production.lua` |
| Production composition | city target 3, expansionist target 4; engineer/scout/naval/siege/healer targets; soldier caps 6/8 | `ai_production.lua` |
| Strategy | archetype goal preferences, goal-switch threshold `best > incumbent * 1.25 + 15`, review cadence | `ai_strategy.lua` |
| Difficulty | candidate count, review interval, route-cost horizon, alternatives, war cadence, risk | `ai_difficulty.lua` |

The first research interface should expose only semantically named fields with
units and bounds. Examples:

```lua
policyConfig = {
  version = "weights-v1",
  economy = { food = 3.5, industry = 2.4, science = 1.8, gold = 0.9 },
  planning = { dependencyDecay = 0.78, researchTurnsExponent = 0.50,
               researchBuilding = 1.20, researchResource = 3.0,
               productionBuilding = 12.0, projectTurnOffset = 2.0 },
  composition = { cityTarget = 3, expansionistCityTarget = 4,
                  engineerTarget = 1, scoutTarget = 1 },
  strategy = { reviewInterval = 10, switchMultiplier = 1.25,
               switchOffset = 15 },
  competence = { candidates = 24, alternatives = 1, planningHorizon = 16 },
  personality = "industrialist"
}
```

This is a schema illustration, not a gameplay patch. The adapter must reject
unknown versions, non-finite values, out-of-bound values, and incompatible
content revisions. Personality and competence are separate: changing
`personality` should alter priorities, not grant resources or hidden actions;
changing competence should alter search quality, not the game rules.

## 2. Policy contract and observation discipline

Every agent, including the current AI, implements the same contract:

```text
policy.init(match_config, player_id, seed, policy_config)
policy.observe(public_private_view, legal_action_mask, phase)
policy.propose(budget) -> ranked legal action proposals
policy.choose(...) -> one validated action or explicit pass
policy.end_turn()
```

The engine remains responsible for `legalActions`, validation, state mutation,
fog of war, resource accounting, movement, combat, victory, and deterministic
random streams. The policy receives an observer projection; a full-state/oracle
view is allowed only in diagnostic experiments and must be marked in results.
No policy may call internal systems to create units, reserve resources, reveal
tiles, or bypass an action cost.

The observation schema should separate:

- public visible state and the acting player's private state;
- stable entity IDs and sorted collections (no table iteration randomness);
- action masks and action failure reasons;
- current plan/intended strategy and every revision;
- bounded history features (recent losses, queue changes, rival threats);
- a schema version, content revision, and observation checksum.

Action budgets and timeouts are part of the result. An invalid action should be
rejected through the normal action path, not converted into a free legal move.
Use deterministic tie-breaking in all policies unless an experiment explicitly
registers a controlled RNG stream.

## 3. Baseline and specialist suite

Before optimization, archive reproducible policies:

1. `baseline-current-v1`: current strategy/research/production/tactics code,
   with its actual difficulty profile recorded;
2. `specialist-expansion-v1`: expansion priority with explicit defense and
   resource checks;
3. `specialist-science-v1`: expedition/science targets and safe development;
4. `specialist-industry-v1`: Create infrastructure and rail/industrial route;
5. `specialist-military-v1`: military readiness, defense, and conquest;
6. `specialist-diplomacy-v1`: villages/council where enabled;
7. `adaptive-heuristic-v1`: current planner with bounded plan revision;
8. `random-legal-negative-v1`: legal but intentionally weak control, never a
   balance reference;
9. `oracle-diagnostic-v1`: full-state or search aid for debugging only, never a
   fairness claim.

Each specialist declares its intended strategy before the match. A policy may
adapt later, but its initial intention and every revision are logged. This is
what allows an intended-strategy/actual-victory matrix instead of retrospective
storytelling.

Baseline evaluation is a fixed seed/seat/map suite from
`EXPERIMENT_PROTOCOL.md`. Use the current policy as a baseline, not an upper
bound: a civilization that appears weak only because the baseline cannot use
its mechanics is an AI failure until tested by a competent policy.

### 3.1 Executed pilot evidence (not deployment or proof of strength)

The following bounded pilots have now executed and should be treated as
exploratory evidence in later planning:

- `results/strategy_search_pilot.json` ran a source-frozen elitist bounded
  log-normal weight search with one training seed (`75123`), two holdout seeds
  (`95117`, `18731`), population 3, two generations, two workers, and 180
  rounds. The selected expedition policy
  (`food=1.277163`, `industry=1.235594`, `science=1.416576`, `gold=1.469771`)
  scored 0.75 over 8 held-out Forge seat games versus 0.25 for the baseline's
  8 games. This is a conditional policy-search improvement under two fixed
  opponent types and one faction; it is not a general strength estimate,
  route-equivalence result, confidence interval, or optimal-play claim.
- `results/recoverability_pilot.json` ran four matched round-10 checkpoint
  pairs on seeds `99119` and `61283`, Forge only, no hostiles, with a legal
  `Sailing` research diversion. The diversion retained the winner but delayed victory by
  10 and 11 rounds in two expedition-versus-industrial cases; in one
  expedition-versus-expedition case it changed a baseline win to a diversion
  loss; in the other, the same player won both at the same round. This is a
  legal counterfactual pilot, not a learned win-probability estimate.
- `results/route_crossplay.json` reports a bounded route-controller
  cross-play summary of 24 games: selected expedition was credited with 12/12
  reported wins and conquest with 0/12. These goal controllers were not
  comparably strong, used one faction and two seeds, and therefore demonstrate
  controller asymmetry rather than intrinsic route balance.

The pilots support more comparable policies, larger holdouts, and route-specific
competence tests. They do not authorize live AI deployment, gameplay changes,
or a claim that expedition is intrinsically stronger than conquest.

### 3.2 Executed adversarial archive-adaptation pilot

`results/adversarial_archive_adaptation_pilot.json` is the next bounded
archive-training step. It reused the existing `runner.write_run`,
`evolve.mutate`, and `evolve.export_lua` helpers through the research-only
driver `adversarial_archive_pilot.py`; no `tools/civcraft_lab` or gameplay file
was changed.

- Training used only seed `451139`, Forge versus Forge, hostiles off, 180
  rounds, population 3, two generations, and two workers. The initial
  candidates were the archived selected expedition policy, industrial, and
  conquest. Every training candidate faced the fixed mixture of archived
  selected expedition plus industrial, with candidate seats rotated.
- All 8 training evaluations (4 games each) were valid: 4/4 finished, zero
  censored, zero errors, and the same source hash
  `9b12a1a22939d9e06834dff3743756f7b864eb3e12f40aaa109917ab1f0af38f`.
  The generation-1 `mutant-1` expedition candidate was selected on training
  fitness 1.00. Its policy is
  `{food=1.103751, industry=1.548743, science=1.645151, gold=0.692060}` with
  goal `expedition`.
- Only after selection and candidate archiving were holdout seeds `808381` and
  `919393` evaluated. The previous-champion mirror seat control scored 0.50 /
  0.50 (4/4 finished). Original expedition versus the selected counter scored
  0.25 / 0.75 (4/4 finished); all terminal reasons were End Expedition.
- Valid candidates were archived with policy IDs, Lua exports, training
  fitness, source hash, and raw artifact paths. Invalid/censored/error matches
  would have been ineligible; none occurred in this pilot. Elapsed time was
  about 227 seconds with two workers, but throughput is confounded by a
  concurrent three-worker run and is not a benchmark.

This is evidence that archive adaptation can improve a narrow Forge/seed/goal
cell. It is not a good-result claim, faction-generalization result, route
fairness result, or deployed-policy recommendation. The holdout was not used
for selection; larger cross-faction, cross-map, comparable-opponent and
independent-replication runs remain required.

## 4. CPU-first evolutionary search

The first ML-assisted implementation is black-box optimization of the bounded
`policyConfig` vector. It is interpretable, can export to Lua, and exposes
strategy dominance before investing in neural infrastructure.

### 4.1 Objective and evaluation

Use a multi-objective ledger rather than a single win-rate score. Candidate
objectives include:

- unconditional win share with ties reported separately;
- conditional route performance with route-eligibility denominators;
- actual-victory diversity and intended/actual strategy alignment;
- pacing milestones and victory-round distribution;
- skill ordering against weaker and stronger archived opponents;
- recoverability after a moderate error;
- exploit/error rate, illegal-action rate, and completion rate.

Use Pareto ranking or a pre-registered scalarization with hard constraints.
Never reward a policy for producing an unreachable route, exploiting hidden
state, shortening games through invalid actions, or defeating only its mirror.
Run common-random-number match blocks and evaluate against a mixture of
specialists, current baseline, archived champions, and adversarial opponents.

### 4.2 ES/genetic/CMA-ES stages

Start with a small pilot to measure games/second and objective noise. Candidate
methods, in order of increasing sophistication:

1. Latin-hypercube/random bounded sampling for sensitivity and interaction
   discovery;
2. rank-based evolution strategy or genetic population with elitism and
   mutation of a few interpretable weights at a time;
3. CMA-ES for continuous weights after the vector has stable scaling;
4. mixed-integer/conditional search for city targets, review cadence, and
   discrete route choices.

Population size, generations, and worker count are experiment parameters, not
performance claims. Record them exactly. A candidate is promoted only after
training-seed improvement, validation-seed confirmation, and final holdout
evaluation against policies not used for selection. Preserve each candidate's
config, seed manifest, objective vector, parent IDs, and replay of its best and
worst games.

The M3 MacBook Pro with 36 GB unified memory is the planning target. Prefer
native Lua workers, compact JSONL/CSV summaries, bounded worker processes, and
batch writes. Benchmark 1, 2, 4, 6, and 8 workers before choosing a default;
thermal throttling can make more workers slower. Report CPU time/turn,
complete games/hour, peak memory, and failure rate. Do not promise 10,000 games
or GPU acceleration until measured.

## 5. Archived adversarial league

Maintain an append-only league manifest. A policy snapshot includes:

```text
policy_id, parent_ids, config checksum, code revision,
engine/content revision, intended strategy set, training seed pool,
validation/holdout status, action-budget settings, creation date
```

League members should include current baseline, specialists, latest candidate,
previous champions, intentionally weak agents, exploit hunters, and counters
to known strategies. Match every new candidate against a fixed historical
subset and a rotating mixture so it cannot overfit the current champion or a
fixed seed pool. Store a civ/policy cross-play matrix; Elo/Glicko can summarize
opponent strength but must not replace raw matchup results and uncertainty.

Do not call a goal-specialist cross-play matrix a route-balance matrix. A
conquest controller that never performs military preparation can lose every
match while the conquest route remains healthy. Diplomacy also needs a topology
stratum: under the current Council rule, a two-player rival can structurally
veto the diplomatic win because the resolution requires a supporting member.
Record that as a rules/topology constraint, not as an AI failure. Keep any
future two-player diplomatic contract as a separate candidate experiment.

### 5.1 Exploit taxonomy

Every suspicious win gets a replay and one of these labels:

- **rule violation:** illegal action, hidden state, extra resource/move, or
  bypassed validation;
- **simulator divergence:** native/CraftOS or save/replay mismatch;
- **information leak:** policy observes fogged or future state;
- **policy blind spot:** legal counterplay exists but a baseline misses it;
- **gameplay dominance:** strong diverse policies win under matched controls;
- **degenerate objective:** candidate optimizes a proxy while losing actual
  games/variety/pacing;
- **measurement artifact:** denominator, seed, or route conditioning error.

An exploit is not a balance finding until the replay is classified, the
authoritative engine is verified, and the behavior reproduces across held-out
maps/policies. Keep action traces for all exploit candidates.

## 6. Hierarchical Gymnasium prototype (gated)

Gymnasium integration begins only after true-engine parity and throughput gates
are met. The first environment should be a strategic controller, not a
full-game mouse-action replacement:

```text
reset(seed, match_config) -> observation, info
step(high_level_goal/action) -> observation, reward, terminated, truncated, info
action_mask -> legal strategic choices
```

The learned layer chooses a bounded goal such as expand, develop industry,
research, defend, attack, connect rail, pursue expedition, or contest a rival.
Deterministic Lua planners continue to choose legal tile placement, pathfinding,
combat, queue actions, and tactical details. Goal duration and re-planning
cadence are explicit and logged.

### 6.1 Required gates

**Parity gate:** the environment must replay identical actions through the real
engine and produce equivalent authoritative state hashes, metrics, and victory
results. Start with 100 deterministic fixtures across early/mid/late turns and
zero unexplained mismatches; expand the fixture set after every divergence.

**Throughput gate:** first benchmark the native authoritative runner. Set a
documented production threshold after measurement; a provisional gate is at
least 5× the CraftOS-compatible runner and at least 1,000 complete games/hour
on the target M3 configuration, with memory and error limits recorded. If the
true engine cannot meet this, shorten scenarios or use larger batch intervals,
not an unvalidated surrogate for balance claims.

**Learning gate:** masked actions, reward accounting, truncation, and seeded
resets pass unit tests; a learned controller must beat or match the strongest
heuristic/evolutionary baseline on held-out games, not merely reproduce a
training reward.

Only after these gates should masked PPO or another method be benchmarked.
Use curriculum scenarios first, then complete games, with actual victory as the
primary outcome and carefully bounded shaping for legal progress. Test reward
hacking, route collapse, mirror overfitting, and unstable multi-agent play.

## 7. Compact Lua policy export

The deployment target is CC:Tweaked, so inference must be deterministic under
an explicit RNG policy, small, bounded, and independent of Python/ML packages.
Compare three export forms:

1. **weights/thresholds:** the preferred first path; directly maps the tuned
   policy vector to existing `ranked` functions;
2. **decision tree/rule list:** a bounded-depth, deterministic policy for
   strategic choices;
3. **tiny MLP:** only if it materially improves held-out play; keep the model
   compact and use arithmetic available in the target Lua runtime.

Every export contains:

```text
format_version, engine/content revision, observation schema,
feature order/checksum, finite parameters, action priorities,
legal-action fallback, RNG policy, model checksum
```

The offline exporter must reject missing features, NaN/inf, unknown content,
oversized models, and incompatible policy versions. It emits a Lua fixture and
an independent reference output for the same observations.

### 7.1 Export validation

For each candidate, test:

- feature ordering and checksum;
- legal action masking and deterministic tie-breaking;
- output equivalence between reference and Lua fixtures;
- memory, p95 inference latency, watchdog/cooperative-yield behavior, and
  worst-case action count on target CraftOS;
- full-game strength retention against the source policy on held-out maps;
- actual victories, pacing, strategy diversity, and recoverability after
  distillation;
- safe fallback when a feature/action is unavailable after save migration.

One-step imitation accuracy is insufficient. A compact model can choose a
locally similar action and still lose because of long-horizon consequences.
Promote an export only after complete-game tests and a replay audit.

## 8. ML-assisted diagnostics, not replacement simulation

After baseline traces exist, optional supervised models may predict win
probability, remaining duration, milestone risk, or exploit likelihood. These
models are triage/surrogate tools only. Any proposed balance change or policy
conclusion must be re-evaluated by the authoritative engine with nested policy
adaptation:

```text
candidate rules -> fixed baseline evaluation
                 -> adapted strong-policy evaluation
                 -> independent policy/league holdout
                 -> final holdout and replay audit
```

Do not optimize a game parameter against a surrogate and report the surrogate's
prediction as a win-rate result. Include model uncertainty and out-of-domain
checks; reject a surrogate when it selects a seed/map family not represented in
its training data.

## 9. Validation stages and exit criteria

| Stage | Work | Exit evidence |
| --- | --- | --- |
| G0 | versioned policy schema and baseline adapters | current policy reproduces existing choices on fixtures |
| G1 | authoritative headless API and parity/replay tests | no unexplained deterministic divergence |
| G2 | baseline/specialist benchmark | complete metrics, denominators, errors, holdouts |
| G3 | ES/genetic/CMA-ES plus archive-adaptation pilot | reproducible improvement on validation/league and stable objective ledger; current bounded Forge result is smoke evidence only |
| G4 | archived league and exploit replays | cross-play matrix, taxonomy, regression checks |
| G5 | Gym strategic prototype | parity + measured throughput + masked-action tests |
| G6 | compact Lua exports | full-game retention and CraftOS resource/latency evidence |
| G7 | gameplay review | only then consider a reviewed policy/rule change |

Failure at a gate pauses the downstream track. In particular, a policy that
looks strong on a non-authoritative simulator cannot advance to balance or
deployment evidence. Keep the last passing artifact and the failing replay.

## 10. Risks and deliberate non-goals

- A stronger policy can expose a genuine balance flaw or merely a current AI
  blind spot; cross-play and competent specialists are required to distinguish
  them.
- Evolution can overfit fixed maps, mirrors, or route-conditioned scores;
  holdouts, seed blocks, and a league are mandatory.
- RL can reward proxy progress, invalid action retries, or early termination;
  actual engine outcomes and completion/error metrics remain authoritative.
- A compact export can preserve one-step behavior while losing strategically;
  full-game retention is the acceptance test.
- Difficulty must not silently add resources, sight, or actions. Decision search,
  planning depth, controlled noise, and policy quality are acceptable levers;
  hidden cheats are not.
- Perfect play is not a deliverable. Report the strength of the league and
  search estimate, its uncertainty, and the strategies it has not tested.

No live-game AI rewrite, gameplay rebalance, large content addition, or claim
of completed training belongs in this phase. The first concrete deliverables
are a reproducible baseline suite, a policy-config adapter preserving current
behavior, and measured evidence that each later research stage is worth its
cost.

### Auxiliary outcome-model pilot now executed

`fit_outcome_pilot.py` trains an L2 logistic critic on route-crossplay seed 99119
and evaluates on seed 61283, using three pre-outcome snapshots per match.
`results/outcome_model_pilot.json` retains inputs, coefficients and provenance.
Held-out Brier loss is 0.1700 versus a 0.2500 constant prior, log loss 0.5143
versus 0.6931. Each split has only one independent map block; snapshots and
seat rotations are correlated. These are descriptive probabilistic scores,
not validated calibration or recovery probabilities. The model uses privileged
opponent totals and is kept entirely out of playing agents. It is a first
auxiliary ML experiment, not an approximate replacement for the Lua simulator.
See the [calibration reference](https://scikit-learn.org/stable/modules/calibration.html).
