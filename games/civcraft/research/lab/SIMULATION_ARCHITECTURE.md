# CivCraft simulation architecture

**Status:** mixed implemented/planned inventory based on frozen HEAD `97944b8bc85e011d00abbdf45bf9aecdb82050ae` plus the current uncommitted lifecycle extraction. The lab shares authoritative gameplay rather than reimplementing it. The separately requested H1 healing rule is now implemented; historical experiments retain their original pre-H1 fingerprints.

**2026-10-27 amendment:** Observer proposals now cover city work, unit modes,
existing disband, escorts, rail, strikes, exchange/envoys and bounded
diplomacy/Council templates. `legalActionMetadata()` explicitly declares
`exhaustive=false`. Public scheduler eligibility filters ordinary orders while
preserving the dispatcher's reply/Council exceptions. See
[proposal validation](PROPOSAL_INTERFACE_REPORT.md) for 18 passing tests and
native initialization parity. Earlier line references and validation gaps
below describe the initial extraction; the [requirements matrix](REQUIREMENTS_MATRIX.md)
is the current evidence ledger.

## Architecture in one view

The lab now has a real shared transition path for short headless experiments:

```text
CraftOS game.lua ───────┐
                        ├─ games/civcraft/match_lifecycle.lua
                        ├─ games/civcraft/actor_lifecycle.lua
                        └─ games/civcraft/actions.lua / systems / victory
Lupa Runtime ───────────┘
        │
        ├─ engine.lua: newGame, observe, legalActions, applyAction,
        │              endTurn, advance, pump, isFinished, metrics
        ├─ runner.py: bounded whole-game worker + JSON result
        ├─ telemetry.lua: accepted/rejected action accounting
        └─ metrics.lua: privileged diagnostic snapshots
```

The boundary is behavior-preserving: `engine.lua` loads the installed game modules and calls `Actions.apply()` for orders. It does not duplicate the production, science, combat, visibility or victory formulas. The CraftOS adapter still owns UI, save I/O, rednet transport, presentation, tracing and victory/save side effects around the extracted lifecycle.

The current boundary has passed short native parity, one full selected-policy match and a narrow handcrafted save boundary, but it is not yet a complete replacement for the live game loop. In particular, there is no broad differential replay for registered-player war/Surprise War reactions, old-save migration, network snapshots, or a multi-seed/full-duration victory matrix.

## Implemented interfaces

### Shared lifecycle modules

`games/civcraft/match_lifecycle.lua` is the extracted authoritative setup/round boundary:

- `newLobby(campaignID)` creates the same schema-6 Create lobby defaults as the frozen `game.lua` (`match_lifecycle.lua:23-48`).
- `initialize(state)` generates the map, capitals, starting warriors/stores, hostiles, villages, migration, council, diplomacy and initial visibility (`match_lifecycle.lua:65-102`).
- `advance(state)` performs the round transition: readiness reset, council/diplomacy boundary, event pruning, combat/economy/village/hostile processing, movement reset, visibility, auto-explore, age/end-stage and reports (`match_lifecycle.lua:105-145`).
- `finish(state, id)` captures the report baseline, marks scheduler readiness and emits the end-order event (`match_lifecycle.lua:147-158`).

`games/civcraft/actor_lifecycle.lua` extracts the AI/queued-route/reaction pump (`actor_lifecycle.lua:13-71`). It retains the original order and calls `Systems.aiTurn()` through the existing shared `Actions.apply()` path. Callbacks are available for runtime progress/trace messages, but callbacks do not mutate authoritative state.

The live `game.lua` now delegates map setup, round advancement and actor pumping to these modules while retaining the UI, save, logging, victory and network orchestration. `lib/fpb/packages.lua:216-217` includes the new modules in the installed package manifest.

### Research engine

`tools/civcraft_lab/engine.lua` is an actual adapter, not an independent simulator:

| Interface | Implementation | Status / limitation |
|---|---|---|
| `newGame(config)` | Validates 2–4 players/civs/hostile mode, configures speed/victories, calls `Lifecycle.initialize` (`engine.lua:14-35`) | Implemented; no arbitrary live lobby/network join sequence |
| `observe(state, playerId)` | `Presentation.capture` (`engine.lua:37-39`) | Implemented; observer-safe projection |
| `legalActions(state, playerId)` | `Proposals.list` from detached observation | Expanded observer candidate set; public eligibility filter; still not an exhaustive legal mask |
| `legalActionMetadata()` | `Proposals.coverageMetadata` | Declares covered families, bounded templates, hidden-state limitations and non-exhaustiveness |
| `applyAction(state, playerId, action)` | `Actions.apply` with live `Systems` (`engine.lua:46-48`) | Implemented; authoritative validation remains in game modules |
| `endTurn(state, playerId)` | `Lifecycle.finish` (`engine.lua:50-52`) | Implemented |
| `advance(state)` | Requires scheduler completion, advances lifecycle, checks victory (`engine.lua:54-59`) | Implemented; wartime/victory parity still needs broader tests |
| `pump(state)` | `Actors.pump` (`engine.lua:61-63`) | Implemented |
| `isFinished(state)` | `state.phase == "over"` (`engine.lua:65-67`) | Implemented; elimination semantics remain a gameplay gap |
| `metrics(state)` | privileged `Metrics.capture` (`engine.lua:69`) | Implemented diagnostic snapshot, not policy observation |

`legalActions` must not be treated as a complete action mask. Hidden obstacles, diplomacy, council, settlement constraints and some unit modes can still produce authoritative rejection. The intended safe policy contract is “propose from the player observation, then submit through `applyAction` and record acceptance/rejection.”

### Python/Lua runtime

`tools/civcraft_lab/runtime.py` creates one independent Lua 5.3 Lupa runtime and module cache per match (`runtime.py:40-62`). It maps `/games/civcraft/` to the repository and `/lab/` to `tools/civcraft_lab`, blocks uncontrolled `math.random`/`randomseed`, and invokes every engine call behind a Lua debug instruction hook (`runtime.py:14-28,50-65`). The default budget is 200,000,000 counted instructions per call; the hook raises `LAB_INSTRUCTION_BUDGET` on exhaustion.

The runtime exposes detached observations, action calls, actor pumping, round advancement, metrics, canonical state and SHA-256 state hashes (`runtime.py:67-90`). `tools/civcraft_lab/requirements.txt` pins `lupa==2.8`.

### Canonical state and telemetry

`canonical.lua` supplies a deterministic type-tagged, sorted-key encoding for differential hashes (`canonical.lua:1-31`). It is explicitly not the save format.

`telemetry.lua` wraps the existing `Actions.apply` only inside the lab module cache (`telemetry.lua:12-37`). It records attempted/accepted/rejected orders, rejection reasons, optional full request traces, and per-actor per-round action budgets. This is instrumentation, not a gameplay rule.

`metrics.lua` captures privileged per-player diagnostics: age, technology count, cities/population, yields, buildings, projects, units/combat power, resources, score, strategy and treasury (`metrics.lua:15-63`). The `noCityOrSettler` field is diagnostic only and does not invent an elimination rule (`metrics.lua:56-59`). Policies must receive `observe`, never this full record.

## Worker and output contract

`runner.py:23-53` runs a complete bounded match:

1. Construct `Runtime(config)`.
2. Install telemetry with an action budget.
3. Record an initial state hash.
4. Pump actors and append metrics each round.
5. Advance only after the current scheduler is complete.
6. Return `finished` with victory reason/IDs, or `censored` when `maxRounds` is reached.
7. Return `error` separately for runtime exceptions; errors are never converted into wins.

The worker records accepted/rejected dispatches and elapsed wall time for the match (`runner.py:31-53`). `write_run()` adds schema version, source manifest, host metadata, worker count and output JSON (`runner.py:56-74`). The source manifest hashes all top-level game Lua and lab Lua files and records `git rev-parse HEAD` (`runner.py:14-20`).

`run.py` is the actual CLI: it requires a JSON list of configs and an output path, permits 1–6 workers, and prints status counts (`run.py:10-26`). `ProcessPoolExecutor` is used when workers exceed one (`runner.py:62-66`).

`workers.py:1-47` now supplies per-match process isolation and wall-clock enforcement. `run_bounded()` starts bounded child workers, terminates a worker after `config.wallSeconds` (default 180), records `status="timeout"` with elapsed time, and preserves ordering/config metadata. Lua instruction budgets still bound individual calls. The remaining limitation is validation coverage: timeout/kill behavior and partial diagnostics need dedicated tests, and `elapsedSeconds` in ordinary finished results remains measurement rather than a timeout boundary.

## Policies: actual versus planned

`policies.lua` is an implemented policy-injection experiment, not an evolutionary learner. It validates bounded nonnegative weights for food/industry/science/gold and four goals (conquest, industrial, expedition, diplomatic), then wraps the existing economy context and strategy review (`policies.lua:5-40`). A policy changes priorities/planning memory; it does not grant resources, alter costs, bypass action validation or change initial assets.

The following are **planned, not implemented** in the current lab:

- rule-based specialist policies beyond the existing live AI and bounded goal/weight injection;
- evolutionary/black-box search over policy weights;
- league/self-play, adversarial policy archives and holdout evaluation;
- learned win-probability/remaining-length models;
- Gymnasium/RL bindings or exported CC:Tweaked policies;
- automatic parameter optimization or gameplay changes.

`proposals.lua` is not a learned policy and not exhaustive legal-action enumeration. It generates observation-only candidates for research, basic buildings/units, and reachable movement (`proposals.lua:6-50`).

### Policy information boundary

The intended policy input is `Engine.observe(state, playerId)`, which delegates to `Presentation.capture` and `World.forPlayer`: the acting player receives a detached copy of its own private state, while rival players/cities/units are reduced to public or currently visible fields. The Python `Runtime.observe()` conversion is detached again on the Python side. `Engine.metrics()` is a privileged evaluator diagnostic and is not passed to policies. The policy adapter only wraps economy weights and strategy review; it does not receive `state`, `metrics`, raw rival stockpiles or the canonical encoder. The 12 lab tests cover rival-treasury redaction, detached observations and policy asset invariance, and the three-fixture parity run covers observer hashes.

This is an architectural boundary with partial test coverage, not a formal information-flow proof. The candidate generator is explicitly incomplete, and wartime, diplomacy, council, settlement and all unit modes still rely on authoritative rejection after proposal. Before policy search, add adversarial observer checks for rival plans/stockpiles, unseen city/unit details, event streams and every newly exposed field; report candidate coverage and rejection rates separately.

### Checkpoints versus live saves

`Runtime.restore()` decodes the lab's deterministic `canonical.lua` checkpoint and validates only the schema/ruleset. It is useful for matched continuation branches, but it is not `games/civcraft/saves.lua` compatibility. The research-only [`check_wartime_save_parity.py`](check_wartime_save_parity.py) now exercises the actual native `Saves.save()`/`Saves.load()` path plus the same `World.migrate`/`Systems.migrate`/`Diplomacy.migrate` pipeline used by `game.lua` on a handcrafted hostile-spawn settler capture. Its compact [`result`](results/wartime_save_parity.json) passes 21 hash/error checks: offline/native before and after hostile capture, native save/reload, a controlled post-load continuation, explicit matching diagnostics for the known active-hostile error, and a separate registered-player `declareWar` followed by next-round legal settler capture through `Actions.apply`. Surprise War remains untested. The active-hostile continuation is intentionally recorded as a matching known `hostiles.lua:103` orphan-settler error on both runtimes; the fixture disables hostile processing symmetrically only for the continuation equality check. This proves a narrow save boundary, not migration across old versions, rednet snapshots or a repaired hostile invariant.

## Differential parity status

`check_native_parity.py` runs the same scripted checkpoints in Lupa and native CraftOS-PC. It copies the repository game and lab into an isolated profile, runs `parity_fixture.lua`, canonicalizes state and observation strings, compares hashes, and writes JSON (`check_native_parity.py:27-43,45-95`).

The current checked-in result [`results/native_parity.json`](results/native_parity.json) covers three fixtures: 2 players, 4 players, and 2 players with a policy adapter; all use compact Continents, standard hostiles, and the Forge/Scholar/Iron/Merchant seat ordering. Each fixture has 18 checks (nine authoritative-state and nine observation checkpoints) across initial state, research, a rejected research order, three actor pumps and three round boundaries. All 54 state/observation checks pass. The aggregate validation record is [`results/validation_summary.json`](results/validation_summary.json): 12 Python lab tests and six frozen lifecycle fixtures also pass.

`tests/civcraft_lifecycle_test.lua` independently compares extracted lifecycle functions against readable frozen-HEAD reference transcriptions over six fixtures: 2/3/4 players × seeds 12345/24680 (`civcraft_lifecycle_test.lua:273-315`). It compares lobby, initialization, one round boundary, actor pump state and callbacks. The test explicitly excludes UI, save/trace I/O and victory side effects.

This is strong short-horizon evidence of behavior preservation, not proof of a complete simulator. Wartime scheduler reactions, hostile edge cases, save migration, network packet flow, victory outcomes and late-game/full-duration parity remain separate tests.

The selected exported policy has an additional full-duration native comparison. [`results/full_policy_native_parity.json`](results/full_policy_native_parity.json) matches the offline and CraftOS canonical full state exactly for seed 75123, compact Pangaea, hostile mode off, Forge mirror, through round 125 and `END EXPEDITION`: SHA-256 `33758cc931da1153cd959a45eadce92db5546943dbb5e190fe53b864703981ab` on both sides. The native run measured 12,823 ms wall time, 69 ms worst actor callback, 22,083.315 sampled Lua KB peak, and 413 cooperative GC/yield cycles. These are one-machine, one-seed measurements, not performance or balance guarantees; inference/Monte Carlo memory isolation was not measured, and the sampled Lua figure is not a process-wide memory bound.

## Pilot run status

`/tmp/civcraft-lab-pilot-results.json` is a seven-match pilot, not a balance benchmark. It ran 57.86 seconds on arm64 Python 3.14.6. The runner itself records hardware model as unverified; a separate host query confirmed Apple M3 Pro/36 GiB, documented in BASELINE_BALANCE_REPORT.md:

- 5 matches finished; 2 errored in the standard-hostiles path at `games/civcraft/hostiles.lua:103` with `table index is nil`. A fresh native fixture now reproduces the Forge-v-Forge case at round 15 after 14 completed rounds and captures the orphan hostile-owned settler; see `games/civcraft/research/lab/hostile_capture_reproduction.json` (raw copy at `tools/civcraft_lab/results/hostile_capture_reproduction.json`).
- The two errors were seed 95117 Forge-v-Forge and Scholar-v-Iron. The native fixture now confirms the captured-settler/nil-spawner root cause for Forge-v-Forge; fresh Lupa reproduction remains unavailable because Lupa is not installed in this environment.
- Finished fixtures included Forge-v-Forge seed 75123 Industrial round 149; Scholar-v-Iron seed 75123 End Expedition round 93; Iron-v-Scholar seed 75123 End Expedition round 96; Iron-v-Scholar seed 95117 End Expedition round 100; and a four-player Forge/Scholar/Iron/Merchant seed 18731 End Expedition round 106.
- Results include dispatch counts and per-round metrics, but no full action trace (`trace` is empty). The two errors are infrastructure/engine failures and must not be counted as losses or wins.

The pilot demonstrates that the runner can complete long matches and expose metrics, while simultaneously demonstrating why hostile-mode error handling is a release gate before large balance sweeps.

## Next implementation boundary

The highest-value next steps are behavior-preserving:

1. Design-review and then fix the standard-hostiles `hostiles.lua:103` nil-spawner failure; the deterministic regression fixture now exists.
2. Add tests for the implemented per-worker wall-clock timeout and explicit infrastructure-error schema.
3. Expand `legalActions` coverage or expose its coverage mask to every policy.
4. Extend the native wartime/save fixture to Surprise War, scheduler reactions, old-save migration and a non-error active-hostile continuation after the nil-spawner invariant is fixed; keep canonical checkpoint tests as a separate research-only gate.
5. Add victory-route completion and elimination checks before policy search.
6. Add adversarial observer/information-flow checks and broader legal-action coverage before interpreting policy results.
7. Only then implement specialist policies, evolution, league evaluation and balance proposals.
