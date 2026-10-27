# Continuous balance testing plan

**Status:** this began as the 2026-10-26 testing plan. The harness, bounded
evolution/archive studies, several baseline matrices and auxiliary-model
experiments have since run; use the [current requirements matrix](REQUIREMENTS_MATRIX.md)
for their actual scope and limits. The CI lab suite now discovers 34 tests,
including observer proposals, siege composition, P1 and runtime adapters;
six optional LuaJIT cases skip when that extension is absent. Historical counts and
remaining tasks below describe the initial extraction unless updated by a
linked report. This document does not authorize gameplay changes.

## What is already a regression gate

The lab currently has five useful layers:

1. **Frozen-HEAD lifecycle reference:** `tests/civcraft_lifecycle_test.lua` compares `match_lifecycle.lua` and `actor_lifecycle.lua` against readable transcriptions of the original `game.lua` lifecycle over six seeded 2–4-player fixtures. It checks lobby, initialization, one round boundary, actor state and callback order (`civcraft_lifecycle_test.lua:273-315`).
2. **Python lab contract tests:** `tests/test_civcraft_lab.py` checks real initialization/villages, 2/3/4-player advancement, detached fog-safe observation, rejected research immutability, partial legal-action proposals, deterministic repeated matches, disabled-victory policy behavior, policy asset invariance and instruction-budget errors (`test_civcraft_lab.py:17-87`).
3. **Native parity:** `tools/civcraft_lab/check_native_parity.py` compares Lupa and CraftOS-PC canonical full state plus observer output for three compact Continents, standard-hostile fixtures: 2 players, 4 players and a 2-player policy adapter. The checked-in [`results/native_parity.json`](results/native_parity.json) has 54/54 equal state/observation checks (18 per fixture).
5. **Long-match pilot:** `/tmp/civcraft-lab-pilot-results.json` exercised seven configurations through the runner. It finished five and exposed two standard-hostiles engine errors at `hostiles.lua:103`; it is a smoke diagnostic, not a pass gate for balance.

These gates test different failure classes. A passing lifecycle/parity check means state transitions and projections agree for the covered trace. It does not establish civilization win-rate balance, strategic diversity, comeback potential or fun.

4. **Full selected-policy native match:** [`results/full_policy_native_parity.json`](results/full_policy_native_parity.json) compares an exported champion policy against its offline run from initial state through `END EXPEDITION` at round 125. Both canonical full-state hashes equal `33758cc931da1153cd959a45eadce92db5546943dbb5e190fe53b864703981ab`; native measurement was 12,823 ms wall time, 69 ms worst actor, 22,083.315 sampled Lua KB peak, and 413 GC/yield cycles. This establishes one end-to-end adapter match, not general balance or a performance SLA. Inference/Monte Carlo memory isolation was not measured, and sampled Lua KB is not process-wide memory.

The aggregate validation record [`results/validation_summary.json`](results/validation_summary.json) reports 12 Python tests, six frozen lifecycle fixtures, and all 54 native state/observation checks passing. The full-policy result is a single Forge mirror on seed 75123 with hostile mode off; it must not be generalized to route, faction, map or hostile balance.

## Required result taxonomy

Every run must distinguish:

| Status | Meaning | Balance interpretation |
|---|---|---|
| `finished` | Authoritative game reached `phase == "over"` | Eligible for victory/timing analysis |
| `censored` | Research round budget ended before victory (`runner.py:45-47`) | Eligible for survival/trajectory analysis, not a loss or score win |
| `error` | Engine, policy, serialization or infrastructure exception | Exclude from win rate; fix or report as a reproducibility blocker |
| `timeout` | Worker wall-clock limit exceeded by `workers.py:run_bounded()` | Infrastructure failure; retain config, source manifest and partial diagnostics |
| `budget_error` | Instruction/action budget rejected work | Report separately from gameplay outcomes; inspect policy/engine behavior |

The current runner enforces Lua instruction budgets, per-actor-per-round action budgets and a worker wall-clock/process boundary (`runtime.py:50-60`; `telemetry.lua:16-20`; `workers.py:1-47`). `elapsedSeconds` remains measurement for ordinary results; a timeout is explicit only when `run_bounded()` records `status="timeout"`.

## Provenance required for every matrix

`runner.source_manifest()` records the git HEAD, a combined Lua source hash and all hashed top-level game/lab Lua files (`runner.py:14-20`). Each output should additionally preserve:

- config JSON: seed, map size/type, hostile mode, speed, enabled victories, civilization/seat order, policy and difficulty;
- runtime: Lupa version, CraftOS-PC version for native checks, Python version, machine/worker count;
- status, victory reason/IDs, round/censor/error reason;
- initial/final canonical state hashes;
- accepted/attempted/rejected orders and rejection reasons;
- per-round metrics: cities, population, food/industry/science, gold/treasury, technologies/age, buildings, units/combat power, stockpiles, score, project and strategy fields;
- full action traces only for selected anomalous matches, because unbounded traces are expensive;
- the exact source manifest and raw JSON, never only a summary table.

The current pilot has configs, metrics, dispatch counts and hashes, but no action trace. Its two hostiles errors are therefore reproducible by config/seed and stack location, but not yet fully diagnosed by a captured action sequence.

## Small deterministic suite

Run these on every lifecycle/harness change:

```sh
python3 -m unittest tests/test_civcraft_lab.py \
  games/civcraft/research/lab/test_proposal_interface.py \
  games/civcraft/research/lab/test_coordinated_siege_policy.py
python3 tools/civcraft_lab/check_native_parity.py \
  --output /tmp/civcraft-lab-native-parity.json
```

Run the CraftOS lifecycle comparison inside an isolated CraftOS-PC profile using `tests/civcraft_lifecycle_test.lua`. The expected output states that six seeded 2–4-player fixtures match the frozen lifecycle reference and that UI/save/trace/victory side effects are intentionally excluded.

The small suite should fail if:

- a rejected action mutates authoritative state;
- observation leaks rival private treasury/plans or aliases live state;
- a policy changes initial assets;
- deterministic repeated matches diverge;
- instruction/action budgets are silently converted to victories;
- native and Lupa canonical state/observation hashes diverge;
- lifecycle extraction changes actor callback order or round state.

The observation boundary currently has direct coverage for detached views and rival-treasury redaction, plus observer hashes in the native parity fixture. It does not yet prove non-leakage for every rival plan/stockpile, unseen city/unit field, event-stream detail, diplomacy/council field or future proposal. `metrics()` remains evaluator-only and must never be supplied to a policy. `legalActions()` is a partial candidate list, so authoritative rejection is expected and must be measured rather than silently treated as policy failure.

The checkpoint test proves that a canonical lab string can restore an identical continuation in Lupa. It does not replace compatibility evidence for the production `games/civcraft/saves.lua` format or native save/reload behavior; keep those as a separate gate before using checkpoint branches as replay or balance evidence.

The research-only [`results/wartime_save_parity.json`](results/wartime_save_parity.json) now supplies that narrow gate: 21 compact hash/error checks pass for offline/native handcrafted hostile-spawn capture, native `Saves.save`/`Saves.load` plus migration, observer projections, a controlled post-load continuation, explicit error diagnostics, and a separate registered-player `declareWar` followed by next-round legal settler capture. Both runtimes also reproduce the known active-hostile `hostiles.lua:103` orphan-settler error; the fixture records it and disables hostile processing symmetrically for the continuation comparison. Surprise War remains untested, and this is not evidence that the hostile bug is acceptable or that old-save migration/rednet replay is complete.

## Pilot and nightly matrix

After the hostile error is fixed, run a versioned pilot through `tools/civcraft_lab/run.py` with a JSON config list and separate output file. Start with one worker to establish correctness, then measure 2–6 workers for throughput/thermal behavior. Do not claim throughput from the current seven-game run alone.

The first real matrix should include:

- all ten civilizations in mirror and rotated-seat matchups;
- 2, 3 and 4 players;
- continents, pangaea, archipelago and highlands;
- multiple holdout seeds, with a fixed seed set kept out of policy search;
- standard, quick and epic speed;
- hostile off/standard/dangerous after hostile conformance passes;
- each victory enabled alone and all-victory default;
- baseline Prince/current AI, specialist heuristics, and adaptive policies;
- both player orderings for every two-player matchup.

The current `legalActions` proposal generator is explicitly partial (`proposals.lua:1-4`). Until diplomacy, council, settlement and all unit modes are covered or policies are restricted to declared action families, report proposal coverage and authoritative rejection rates separately.

## Metrics and acceptance questions

For each matrix cell, calculate (with sample size and uncertainty intervals):

- win/tie rate by civilization, seat and route;
- victory/decisive turn and censored-game proportion;
- first growth, first settler/founding, first contact, age milestones and military contact;
- city/population/industry/science/gold trajectories;
- technology/building/unit utilization and never-selected content;
- accepted/rejected action rate and reason distribution;
- military strength, losses, capture timing and elimination/recoverability once elimination exists;
- leader margin at fixed checkpoints, probability of reversal and remaining-game length;
- runner instruction time, wall time, checkpoint/GC data where available, and errors/timeouts.

Use fixed policies to diagnose rules, then adapted/strong policies to avoid tuning around a weak AI. Never infer balance from the current pilot’s five wins: it contains repeated matchups, deterministic seed choices, two engine errors, no confidence intervals, no independent strong-policy control, and no complete trace.

## Counterfactual and robustness tests

Once the baseline matrix is stable, freeze checkpoints and compare continuations:

- normal continuation versus one delayed settler;
- one delayed building/research choice;
- one moderate defensive mistake;
- a plausible military retreat or lost unit;
- a route switch with retained project progress;
- a conquered city and, after implementation, an eliminated seat.

Measure win-probability delta, time to recover, city/population/science gap and whether a single moderate error becomes irreversible. Keep the same initial state, action budget and policy version. This is the empirical route to the spec’s forgiving-but-skillful objective.

## Policy search and evolution: planned gates

The current `policies.lua` only injects bounded goal/food/industry/science/gold weights into existing strategy/economy planning (`policies.lua:8-40`). Evolutionary optimization is **not implemented**. When added, require:

1. a versioned parameter vector and mutation/selection configuration;
2. training seeds/opponents separated from holdout seeds/opponents;
3. baseline, specialist, generalist and adversarial league members;
4. cross-play and mirror controls to detect seat/seed overfitting;
5. nested evaluation after rules/config changes, with policy adaptation before conclusions;
6. no direct resource/state mutation outside validated actions;
7. retained champion/rejected-candidate manifests and raw match outputs;
8. regression checks for pacing, diversity, comeback rate and civ identity, not only wins.

The first useful optimizer should target interpretable Lua weights/thresholds. Neural RL, Gymnasium bindings and CC:Tweaked export remain later research tracks and should not block rules diagnosis.

## Error and repair gates before large runs

The current pilot found two reproducible standard-hostiles errors:

```text
games/civcraft/hostiles.lua:103: table index is nil
```

They occurred for seed 95117 Forge-v-Forge and Scholar-v-Iron. The likely hostile captured-settler/spawner path was a hypothesis in the pilot; the native reproduction [`reproduce_hostile_capture.py`](reproduce_hostile_capture.py) now identifies the exact nil object: a hostile-owned captured settler with no `spawner`, at round 15 after 14 completed rounds. The raw record is [`hostile_capture_reproduction.json`](../../../../tools/civcraft_lab/results/hostile_capture_reproduction.json). Add the gameplay design decision and then rerun both failing configs plus a hostile-mode holdout set. No large balance matrix should treat these errors as match losses or proceed until the runner returns explicit `error` records without truncating provenance.

Other pre-matrix gates are:

- add tests for the implemented worker wall-clock timeout and partial-output handling;
- preserve action traces for errors and anomalous late games;
- extend the narrow native wartime/save parity to Surprise War/war groups, old-save migration and each victory route;
- define elimination/timeout semantics before scoring no-city players;
- verify installer/package coverage for the extracted lifecycle modules;
- keep all gameplay costs, yields, combat formulas and victory rules unchanged while validating the lab.

## Reporting template

Every published balance result should include:

```text
Question / hypothesis:
Rules and source manifest:
Policies and versions:
Seeds/maps/seats/player count:
Sample size and exclusions:
Finished / censored / error / timeout counts:
Victory and milestone metrics:
Effect size and uncertainty:
Confounders and limitations:
Raw JSON / trace paths:
Decision: adopt, adapt, reject, or investigate
```

This keeps the lab useful as a long-lived regression instrument rather than turning a handful of generated matches into unsupported balance claims.
