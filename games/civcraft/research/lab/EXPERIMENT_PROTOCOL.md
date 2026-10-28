# CivCraft Balance Laboratory — Experiment Protocol

Status: design specification with bounded pilot addenda. The pilots listed
below are executed artifacts, not claims that the full protocol has been run.
Gameplay rules are out of scope; only behavior-preserving telemetry, replay,
and simulator work may be added until findings are reviewed.

This protocol is the companion to `GOAL_SPECIFICATION.md`,
`civ6-balance-2026-10-26/BALANCE-RESEARCH.md`, and [the executed baseline report](BASELINE_BALANCE_REPORT.md).
It is deliberately stricter than a tournament scoreboard: balance conclusions
must survive seed, seat, map, policy, and measurement controls.

## 1. Questions and estimands

Pre-register the question, configuration, primary endpoint, and contrast before
looking at the evaluation result. A run may answer a descriptive question
without answering a causal one.

### 1.1 Three quantities that must not be conflated

**Unconditional outcome share** is the chance that a player/civilization wins
among valid completed matches in the specified cell, without conditioning on
eventual route eligibility. Report attempted-match execution quality alongside it:

```text
P(win | cell) = wins / (wins + losses + ties/draws)
```

Report ties/draws separately and, when a product decision needs a single score,
also report a pre-declared tie convention (for example, half a win). Never put
errors, timeouts, invalid setup, or abandoned runs in the denominator. Report
those in a separate execution-quality table; never silently discard them.

**Conditional route fairness** is descriptive performance conditional on a
pre-specified route being available or actually pursued, for example:

```text
P(win | civ, route=industrial, route-eligible at checkpoint, cell)
```

`route-eligible` must be defined before the checkpoint (resources, geography,
technology, and enabled victory rules). If the condition uses a later action or
victory, label it post-treatment/descriptive; do not claim it is an unbiased
causal effect of the route. Always pair it with the unconditional outcome
share, because a route that wins often when attempted but is rarely reachable
is not globally fair.

**Intended strategy versus actual victory** is a confusion matrix. The intended
strategy is the policy's pre-match declaration or the first locked plan at a
specified checkpoint; it is not inferred from the eventual winner. Record:

```text
intended_strategy -> actual_victory_route
```

Use this to detect strategic flexibility, forced pivots, and policy failure.
Do not count an Industrial victory by a conquest-intent controller as a
successful Conquest-route finish. An adaptive agent must emit each plan
revision and its timestamp.

### 1.1a Normalize by pursuers, not victory labels

The user's objective is comparable **success per player pursuing a route**
across opponent compositions, not equal raw proportions of ending labels.
In a four-player match with three expedition pursuers and one industrial
pursuer, equal individual win chances of 25% imply an aggregate 75% expedition
and 25% industrial outcome share if players finish through their declared
routes. Forcing a 50/50 label split would favor the sole industrial pursuer.

For each declared route, report separately:

- Player win credit divided by completed pursuer appearances, including wins
  achieved by pivoting or incidentally qualifying through another route.
- Actual declared-route finish credit divided by those same appearances.
- Reachability, abandonment/switching, and time to a contestable finish.
- Each result conditional on faction, map family, seat, player count and
  opponent-route composition, alongside a predeclared weighted summary.

Use fractional credit for shared winners and keep ties explicit. A player
with a predeclared intent remains in that intention-to-pursue denominator
even when the route becomes unreachable; a separate reachability-conditioned
analysis must not hide that failure. Compare controllers only after their
route-specific competence gates pass. Counterplay and local advantages are
allowed; the target is to remove systematic route exclusion and large
unexplained disadvantages, with uncertainty, rather than promise identical
odds against every possible strategy and geography.

The executed cross-play demonstrates the distinction: diplomatic-intent
controllers won five player appearances but **zero Diplomatic victories**.
All five ended through Industrial. Counting only controller names would
incorrectly suggest Council victory was viable in that slice.

### 1.2 Primary pacing endpoints

For Standard (180-round) games, define distributions, not just averages:

- first expansion/founding round and number of cities at rounds 20, 40, 80,
  120, and 160;
- first useful technology, Age/technology milestones, and science per turn;
- first military contact, first hostile loss, first declaration/war, and war
  duration;
- first route-eligibility checkpoint and actual victory-contest round;
- decisive round (the earliest checkpoint at which the eventual winner's
  continuation win probability exceeds the pre-registered threshold);
- victory/end round, natural round-limit draw, elimination, and idle queue
  rounds;
- recoverability after a single moderate error and the time to regain the
  pre-error win-probability band.

The decisive-round threshold is an analysis parameter, not an observed fact.
Use a fixed value for a report (for example 0.80), and sensitivity-check it at
0.70 and 0.90.

## 2. Engine and replay preconditions

No balance conclusion is admissible until the same authoritative Lua rules are
used by CraftOS and the headless runner. The proposed boundary is:

```text
newGame(config) -> state
observe(state, playerId) -> fog-respecting view
legalActions(state, playerId) -> masked actions
applyAction(state, playerId, action) -> result/state transition
endTurn(state, playerId) -> state transition
isFinished(state) -> result
metrics(state) -> compact telemetry
```

The adapter now provides these functions. Its `legalActions` is explicitly a
partial observation-based proposal list, rather than an exhaustive legal mask;
authoritative validation can still reject a candidate. The broader conformance
requirements below remain distinct from API existence. Automated agents must call validated actions; they may
not mutate resources, teleport units, bypass fog, or receive extra turns.

Before the first tournament, run:

1. deterministic same-seed replays, including state hashes at every turn;
2. native-Lua versus CraftOS-compatible replay on identical initial state and
   actions;
3. legal-action and fog-of-war tests for every action family;
4. save/load and resume tests at early, mid, and late checkpoints;
5. victory, tie, elimination, timeout, and invalid-action fixtures;
6. a performance benchmark that reports wall time/game, CPU time/turn,
   games/hour, peak memory, and failure rate on the M3/36 GB machine.

State-hash differences are a parity failure until explained. A faster
surrogate or Python reimplementation may be used for exploration, but it is
not balance evidence until it passes replay equivalence against the true
engine.

## 3. Factorial design and matched controls

Every result row carries a complete immutable configuration. At minimum:

| Factor | Required levels/controls |
| --- | --- |
| Civilizations | every current civ, mirror matches, and pairwise/mixed compositions |
| Seats | every player seat/starting position; rotate civ and policy together and independently |
| Policies | current AI, fixed specialists, adaptive baseline, candidate/evolved policy, and archived versions |
| Intended strategy | expansion, science/expedition, industrial, conquest, diplomacy/score where enabled |
| Players | 2, 3, and 4 if supported by the current rules |
| Diplomacy topology | two-player structural-veto cell; 3–4-player support/counter-diplomacy cells |
| Map | generator version, map family/size, topology, hostile mode, and seed |
| Speed | Quick, Standard, Epic; record all speed-scaled and unscaled rules |
| Difficulty | fixed for a balance cell; difficulty comparisons are a separate experiment |
| Victory rules | enabled routes and round limit, versioned explicitly |
| Runtime | engine revision, content revision, AI revision, Lua/runtime version |

Use matched seed blocks. One block generates a world once and replays it under
the prescribed seat/civ/policy permutations. Do not treat permutations within
one block as independent observations. Randomize match order within a block to
reduce thermal, process-order, and cache effects.

The minimum balanced control suite is:

- same civilization and same policy on swapped seats;
- mirror civilization with swapped seats;
- same map/seed with each policy against the same opponent set;
- fixed-policy cross-play against archived policy versions;
- identical checkpoint continuation for recoverability tests.

When a factor cannot be fully crossed, record the sampling rule and analyse it
as a limitation rather than calling the result a full factorial experiment.

## 4. Sampling, holdouts, and stopping rules

Use separate world-seed pools by map-generator version:

```text
training/tuning: 60%   validation/model selection: 20%   final holdout: 20%
```

The holdout manifest is immutable and must not be used for policy tuning,
feature selection, threshold selection, or deciding which matches to replay.
If a bug is found from a holdout replay, freeze the affected result, fix the
engine, and create a new versioned holdout pool.

Recommended staged sample targets (not claims of completed runs):

- pilot: 20 independent seed blocks per headline cell, to find invalid maps,
  failures, and gross effects;
- main: at least 100 independent seed blocks per headline cell, with seat and
  composition rotations; expand sequentially until a 95% cluster interval for
  the headline contrast has half-width no greater than four percentage points,
  or stop at 400 blocks and report the remaining uncertainty;
- route-conditioned claims: at least 30 route-eligible games in a cell. Below
  that, report the estimate as exploratory and show the denominator;
- rare failures/exploits: continue until the failure taxonomy is stable or
  report zero observed events with an exact upper bound, not “none exist.”

These are precision and reliability targets, not a power calculation for every
possible interaction. A cell that cannot reach them is not merged into a
headline aggregate.

### 4.1 Executed bounded pilots

These results are recorded here so later reports do not accidentally describe
them as merely planned. They remain exploratory and do not satisfy the main
sample-size or faction-equivalence gates.

- `results/strategy_search_pilot.json` is a source-frozen ES-style bounded
  strategy search: one training seed (`75123`), two evaluation seeds
  (`95117`, `18731`), population 3, two generations, two workers, and 180
  rounds. The selected expedition policy used weights
  `{food=1.277163, industry=1.235594, science=1.416576, gold=1.469771}`. Its
  held-out score was 0.75 over 8 Forge seat games versus 0.25 for the baseline
  over the same 8 games. This is a conditional policy-search gain, not a
  confidence interval, route-equivalence result, faction result, or optimal
  play claim.
- `results/recoverability_pilot.json` contains four matched round-10
  checkpoint pairs on two seeds, one Forge faction, no hostiles, and a legal
  `Sailing` research diversion. Diversion delayed the winning outcome by 10 and
  11 rounds in two expedition-versus-industrial cases while retaining the same
  winner; on seed 99119 in an expedition-versus-expedition case it changed a
  baseline win into a diversion loss; on seed 61283 in the other case the same
  player won both at the same round. This is not a learned win-probability or
  general mistake-tolerance estimate.
- `results/route_crossplay.json` records the bounded route-controller
  cross-play summary: 24 reported games, selected expedition credited with
  12/12 wins in its reported cells and conquest with 0/12. The controllers
  were goal-specialists rather than comparably strong policies, used one
  faction and two seeds, so this is evidence of policy/controller asymmetry,
  not intrinsic route fairness. Use the raw artifact's cell denominators when
  reproducing the summary.
- `results/adversarial_archive_adaptation_pilot.json` records an executed
  archive-adaptation pilot. Training used only seed `451139`, initial
  selected-expedition/industrial/conquest candidates, a fixed archived
  expedition-plus-industrial opponent mixture, rotated seats, population 3,
  two generations, and two workers. All 8 four-game evaluations were valid
  with zero errors/censoring and source hash
  `9b12a1a22939d9e06834dff3743756f7b864eb3e12f40aaa109917ab1f0af38f`.
  The selected generation-1 expedition mutant scored 1.00 on the training
  block. After selection only, holdout seeds `808381` and `919393` produced
  0.50/0.50 previous-champion mirror control and 0.25/0.75
  previous-champion versus adapted counter (all four matches finished in each cell).
  This is a narrow Forge/no-hostiles policy result, not route/faction balance;
  throughput is confounded by a concurrent three-worker run.

The executed results justify expanding the holdout suite and improving policy
comparability; they do not justify a gameplay rebalance by themselves.

## 5. Outcomes, missingness, and error taxonomy

Each match has exactly one terminal status:

```text
win(player), loss(player), tie/draw, round_limit_draw,
elimination, engine_error, timeout, invalid_setup, invalid_action_abort
```

`tie/draw` is a game outcome; `engine_error` is not. Record the first failing
turn, actor, action, state hash, stack/diagnostic, and replay path. Keep an
error ledger with these categories:

- setup/map infeasibility;
- authoritative rule defect or parity mismatch;
- policy illegal-action or action-budget defect;
- runtime/OS/resource failure;
- genuine game draw or round-limit outcome;
- intentional abort after a pre-registered safety limit.

Report completion rate and error rates by cell. If errors differ by policy or
civilization, that is itself a result and must not be repaired by deleting the
affected rows. Re-run only after the cause and replacement seed policy are
documented.

## 6. Statistical analysis

Primary comparisons use common random numbers: paired seat/map permutations
and a block-level difference in win indicator, victory round, or milestone
round. For win shares, report Wilson or Jeffreys intervals and paired cluster
bootstrap intervals. Use a mixed-effects logistic model only as a complementary
model, with civ, policy, seat, player count, map family, and speed as fixed
effects and seed block as a random effect. Avoid treating individual turns or
players in the same match as independent.

For victory timing, use Kaplan–Meier/competing-risk summaries when games can
end by different routes; a round-limit draw is right-censoring only when the
estimand is “time to this victory,” and is a valid outcome for unconditional
win share. Show median and quantiles, not only means.

For route proportions and intended/actual confusion matrices, show raw counts
and denominators. For recoverability, estimate paired delta in continuation win
probability and time-to-recovery; cluster by checkpoint seed. For skill
recoverability, do not condition away the fact that strong agents may choose
different states: label state-matched counterfactuals separately from natural
play.

Correct families of exploratory civ, route, and policy contrasts with a
pre-declared method (Benjamini–Hochberg FDR for broad screening, or a
Holm-adjusted confirmatory family). Do not report the smallest unadjusted
p-value as the result. Prefer effect sizes and intervals; p-values cannot
demonstrate practical balance.

## 7. Recoverability and mistake tolerance

At checkpoints 20, 40, 60, 80, 120, and 150 (or the closest legal state),
archive the complete authoritative state and the public observation for each
player. Generate counterfactual continuations from the same checkpoint:

- source continuation under the original policy;
- one moderate, pre-defined error (delayed settler, plausible lower-ranked
  building/research choice, or one poor defensive move);
- a strong deterministic continuation or search policy;
- sustained low-quality play as a separate negative control.

Use the same future random streams when the engine permits it. Measure win
probability, milestone displacement, unit/city losses, and rounds to return to
the source continuation's confidence band. Never infer “one mistake is
forgiving” from a single hand-picked replay. Report route and civ strata.

## 8. Pacing and balance dashboards

The compact per-turn schema should include:

```text
match_id, block_id, seed, engine/content/AI revisions,
round, player, civ, seat, policy, intended_strategy, current_plan,
cities, population, food/industry/science/gold, treasury,
techs, age, units/combat_power, buildings, resources,
legal_action_count, chosen_action, queue_idle, visibility_summary,
route_eligible, route_progress, lead_snapshot, terminal_status
```

Retain full action traces and state snapshots only for the pilot, every error,
ties/draws, outliers, exploit candidates, and a reproducible sample of normal
games. Keep compact aggregates and manifests in the repository; store large
traces externally with checksums and a documented retrieval path.

Headline dashboards must show:

- unconditional outcome share with tie/draw and completion denominators;
- conditional route performance with eligibility/attempt denominators;
- intended-strategy/actual-victory confusion matrix;
- milestone and victory-round distributions;
- lead-to-win and reversal curves at fixed checkpoints;
- route diversity, building/unit utilization, idle rounds, and unreachable
  victory-route frequency;
- completion/error rates and throughput.

## 9. Candidate balance experiments

Changes are evaluated as versioned candidates, never silently applied to the
baseline. Early candidates should isolate one mechanism at a time: overflow
conservation, settler/population opportunity cost, research boosts, combat
breakpoint changes, unit upgrade paths, rail feasibility, and dead-end content.
Do not add a blanket expansion research tax or wholesale Civ VI district model
without a separate hypothesis and control. A candidate must specify which
policy versions are fixed, adapted, or re-optimized; otherwise an AI blind spot
can masquerade as game balance.

For each candidate, run:

1. fixed current-policy evaluation;
2. adapted strong-policy evaluation on training/validation seeds;
3. independent policy/league holdout evaluation;
4. regression checks for pacing, route diversity, civ fairness, skill ordering,
   recoverability, and execution/parity.

No candidate is recommended for gameplay review if it improves one score by
causing a route to become unreachable, homogenizing strategies, invalidating
the map, or reducing the skill gap.

### 9.1 Two-player diplomatic structural veto

The current Council resolution requires a two-thirds threshold and a supporting
member. In a two-player game, the candidate's rival is therefore structurally
able to veto a diplomatic victory; there is no unilateral two-player path.
Treat this as a rules/topology issue, not as a diplomatic policy failure or a
poor win-rate observation. Do not implement a fix in this research phase.

The experiment must report diplomacy separately for two players and for 3–4
players, including eligibility, support/pledge availability, veto events,
route attempts, and actual victory. A future design candidate may add a
two-player unilateral threshold, neutral Council support, or a different
two-player victory contract, but each is a separate pre-registered candidate
with counter-diplomacy tests. Do not pool two-player diplomatic cells into the
general route-fairness denominator while the structural veto remains.

## 10. Reproducibility and reporting checklist

Every report records:

- exact git commit, content/engine/AI policy versions, Lua/runtime version;
- machine and worker count, benchmark command, and wall/CPU time;
- complete config, seed-block manifest, holdout status, and exclusions;
- all denominators, tie convention, error ledger, and missingness rule;
- estimator, interval/cluster method, multiplicity family, and effect-size
  interpretation;
- commands to replay one ordinary match, one holdout match, and every failure;
- whether the result is confirmed, exploratory, a hypothesis, or blocked by
  insufficient parity/throughput.

Until those fields are present, label the artifact a plan or raw diagnostic,
not a balance result.
