# CivCraft compact policy-format comparison

Status: actual comparison complete; source/runtime rules remained frozen. The initial 64-row fixture is retained as a contract test, while actual teacher traces, bounded full-game retention, and fresh-process native inference are reported below.

Update: the approved actual-trace/native/retention run is now complete. The original fixture result remains below as a contract test; it is superseded for strength claims by the actual results in this section.

## Actual source-ranked comparison

The collector called the installed `Production.ranked(view, player, city, systems)` and `Research.ranked(view, player, systems)` through the existing Lupa Runtime, after taking `Presentation.capture` observer views. Systems-derived own-city yields and treasury were used for the feature vector. No `metrics.lua` or authoritative rival state entered the labels.

Teacher-label definition: these are source-ranked recommendations (`ranked[1]`) with the complete candidate list and scores, not claims about the final action actually selected by `AI.choose`/`AI.research`. A current project, emergency branch, `Difficulty.choices`, or authoritative rejection can change the eventual action. The corrected adapter preserves those branches and uses the ranker only as a reorder seam. Python and Lua now both aggregate all own-city `Systems.yields` before constructing the vector.

The dataset contains 2,952 records from four complete Forge-v-Forge, hostile-off, compact Pangaea games: train seeds 75123 and 18731 (1,464 records), holdout seeds 95117 and 808381 (1,488 records). There are 68 actual action labels. The game/seed split is held out as a block; no adjacent rows from one game were split across train and holdout. All four source games finished, with Industrial victory; that is collection provenance, not a balance claim. After correcting the all-own-city yield aggregation, the dataset hash is `0ef6cc9c71f12677c7a2eb222292253ae614e55cef7efb7972f5511258f71e0e`.

| Format | Export bytes | Holdout teacher agreement | Raw unsupported-leaf/prediction fallback | Interpretation |
|---|---:|---:|---:|---|
| weights | 25,052 | 93.75% | 0.00% | Linear ranker; lower trace agreement than the MLP, but the best of these three on the narrow retention arm |
| rule tree | 4,467 | 99.26% | 85.28% | Agreement is inflated: most leaves predict an action absent from the local candidate set and are rescued by the source-ranked candidate fallback |
| tiny quantized MLP | 6,187 | 94.83% | 0.00% | Best held-out trace agreement of the three; full-game retention still fails |

The rule tree's 99.26% must not be read as learned strength. Its 85.28% raw fallback rate means the high agreement mostly inherits the source candidate ordering. On trace agreement, MLP (94.83%) is ahead of weights (93.75%); on the narrow full-game arm, weights are less poor (1/4 target wins versus 0/4 for MLP and tree). None is releasable, and the current tree is rejected despite its small export.

## Adapter-control correction and actual full-game retention

The first 20-match artifact is preserved as `results/actual_full_game_retention_adapter_confounded.json` and is **adapter-confounded**: the old adapter replaced `AI.choose` and `AI.research`, bypassing current-project preservation, emergency/surplus handling, `Difficulty.choices`, four-candidate validation, and retry semantics. Do not use that run to blame the compact learners.

The corrected adapter patches only `Production.ranked` and `Research.ranked`; installed `AI.choose`/`AI.research` remain authoritative. Its `oracle_rank_hook` returns the untouched source order. In four matched seed/seat controls, oracle final hashes equaled the original controller hashes exactly (`oracle_control.all_equal=true`). This isolates later model outcomes from adapter engineering.

The authoritative corrected rerun used 24 bounded matches across four worker processes: original teacher, oracle rank hook, archived champion reference, and each compact format; two holdout seeds; both target seats. Source, extractor, adapter, and model hashes were captured before the first worker and after the last worker and remained unchanged. All 24 matches finished; no timeout/error/censor was converted into a loss.

- Original teacher versus original teacher: 4/4 Industrial, with the nominated target seat winning 2/4 (seat 1 on both seeds). The raw 4/4 winner-seat result is not a strength proof.
- Oracle rank hook: 4/4 exact final-state hashes versus original teacher, proving the corrected adapter preserves the source AI semantics when it makes no ranking change.
- Archived selected expedition champion reference: target seat won 4/4, all `END EXPEDITION` (a stronger archived controller reference, not a universal optimum).
- Weights: target seat won 1/4; the original opponent won the other three through Industrial victory.
- Rule tree and tiny MLP: target seat won 0/4 each; the original opponent won all four through Industrial victory.

This remains a retention failure for the current compact rankers, though weights achieved one target-seat win after the control correction. It demonstrates why the full-game gate is mandatory: a candidate can select locally legal ranked actions and still lose the retained multi-turn economy/route race. The result is only a narrow Forge/hostile-off holdout, not faction or route balance evidence.

The archived 207-byte evolved goal/economic-weight policy is a separate strategic-policy task with existing native full-hash evidence. The 25 KB multiclass linear `weights` export and the tree/MLP exports are distilled production/research rankers; their trace agreement and retention must not be presented as a replacement comparison against that strategic policy.

## Native inference cost and parity

Each actual export ran in a fresh CraftOS-PC headless process for five cooperative four-second batches (20 seconds), with frequent instruction-watchdog yields and garbage collection outside the timed call. The first 120-second attempt exceeded the process bound before producing a valid measurement; it is recorded as an operational timeout, not a performance result. The final bounded run wrote file-backed JSON to avoid terminal redraw corruption.

| Format | Bytes | Calls/s | Max single call | Heap delta | Native replay agreement | Fallback |
|---|---:|---:|---:|---:|---:|---:|
| weights | 25,052 | 7,931 | 108 ms | 0.41 KiB | 100% | 0% |
| rule tree | 4,467 | 613,989 | 2 ms | 0.38 KiB | 100% | 85.28% |
| tiny quantized MLP | 6,187 | 8,671 | 3 ms | 0.41 KiB | 100% | 0% |

Native replay agreement is Python-vs-Lua prediction parity over the 1,488 actual held-out vectors, not gameplay strength. The native comparison used 20-second bounded batches because a single long busy process triggered the CraftOS watchdog; the harness now yields every 32 calls and records timeout/error status explicitly.

## Decision in one page

The comparison now has three actual, exportable formats:

| Format | Representation | Strength | Main risk |
|---|---|---|---|
| `weights` | multiclass linear scores over 15 normalized features | Easiest to inspect, stable, compact enough for Lua | Can miss phase interactions and needs legal-action masking |
| `rule_tree` | bounded depth-2 feature thresholds and leaves | Fastest and highly inspectable | Brittle near thresholds; current fixture tree underfits |
| `tiny_quantized_mlp` | 15 → 8 ReLU → 10 int8 action scores | Captures interactions while remaining self-contained | Harder to audit; quantization and fallback behavior need native testing |

The prepared artifact is not a recommendation to ship one format. The fixture is deliberately a contract test. Selection must wait for teacher decision traces, matched full games, and the isolated native benchmark.

## Source and teacher boundary

Teacher candidates are recorded in `datasets/teacher_archive_manifest.json`:

- `selected-archived-expedition` from `selected_policy.lua` / `results/strategy_search_pilot.json`;
- `adapted-expedition-b4f3d28b1297` from `results/adversarial_archive_adaptation_pilot.json`;
- archived industrial and conquest candidates from the same source-frozen search artifacts.

The archived policies are strong *candidate controller sources*, not proven universal teachers: the earlier pilots were Forge-only, hostile-off, and limited in seed/faction coverage. They contain a goal/weight configuration, not a per-turn decision trace. Therefore this increment does **not** claim that the archived expedition champion is a meaningful goal classifier or that it supplies action labels. The manifest preserves source hashes and the label-ingestion contract. A real teacher record must contain an observer projection, legal action list, chosen action, ranked candidate actions/scores, and teacher ID. It must not contain `metrics.lua`, authoritative state, rival totals, hidden map state, or debug envelopes.

The fixture labels are marked `ranked-research-label-fixture`, not archived game traces. They vary by intended route and game phase; they are present to test format plumbing, action coverage, and non-constant behavior. They must not be counted as a strength result, and they must not be used as evidence that a distilled controller learned `Production.ranked` or `Research.ranked`.

The next data-preparation step is to capture the actual ranked choice from the source AI at decision points: `Production.ranked(view, player, city, systems)` for per-city production and `Research.ranked(view, player, systems)` for research. The capture must retain the observer projection, legal candidate requests, candidate scores/ranks, selected request, route/goal context, seat/faction/map controls, and source hash. This makes the teacher label a changing marginal production/research choice rather than a constant `goal = expedition` label. Train/holdout splits must be by complete game/seed, not by adjacent rows from one trajectory.

## Observer-safe strategic feature contract

`policy_format_comparison.py` implements `extract_observer_features` for the exact shape produced by `Presentation.capture` / `World.forPlayer`. The fixed schema is `observer-strategic-v1`:

`round_fraction`, `age_fraction`, `cities`, `population`, `industry`, `science`, `gold`, `treasury_net`, `technologies`, `buildings`, `unit_count`, `combat_power`, `idle_cities`, `research_progress`, and `legal_action_count`.

Counts and rates are normalized and bounded. Optional fields absent from older presentations become explicit zero/default values and are listed in `missing_optional_fields`. Rival rows can remain visible for public identity/age information, but no rival aggregate is read. The policy receives only the active player's projection and the already computed legal-action list.

## Legal-action safety

All formats call the same deterministic `legal_fallback` rule: if the predicted label is legal, use it; otherwise choose the lexicographically first legal candidate; if the list is empty, return `noop`. The fallback is observable in every score and native benchmark. This is a safety layer, not a way to claim the model made a legal strategic decision. A candidate with an elevated fallback rate fails the acceptance gate even if its teacher agreement is high.

The generated Lua files under `formats/` are self-contained and expose `predict(features, legalActions, candidates)`. They do not mutate game state or call action APIs. The bounded native harness was executed in fresh processes; its attempted 120-second configuration timed out under the watchdog and is not used for the reported cost table.

## Prepared fixture result (not gameplay evidence)

Dataset: 64 records, SHA-256 `c895530da38953fae21b6f4a39f16aaaae4fc6c5d0499f8b7d47dde8eeebcb41`, ten action labels, all labels legal. Python-only results are in `results/policy_format_offline_comparison.json`.

| Format | Lua bytes | Fixture agreement | Distinct predictions | Fallback rate | Python p50 / p95 | Traced peak |
|---|---:|---:|---:|---:|---:|---:|
| weights | 5,099 | 32.8% | 9 | 3.1% | 17.3 / 20.3 µs | 101,056 B |
| rule tree | 2,045 | 29.7% | 3 | 0.0% | 2.2 / 2.7 µs | 97,824 B |
| tiny quantized MLP | 2,464 | 12.5% | 5 | 20.3% | 30.6 / 36.1 µs | 98,656 B |

These numbers only test a synthetic fixture and the Python implementation. In particular, the low MLP agreement is an implementation/fixture warning, not evidence that an MLP is unsuitable; it must be retrained from actual ranked teacher traces and evaluated on held-out trajectories. The Python timings and traced allocations are not native CraftOS measurements.

## Required full-game retention experiment

After parent approval and teacher-trace import:

1. Freeze the source revision, feature schema, label split, and teacher policy IDs.
2. Train each representation on the same training traces. Do not tune format-specific hyperparameters on holdout games.
3. Run matched full games against the original controller and archived teachers with seats rotated, fixed map/faction/hostile controls, and the existing error/censor ledger.
4. Compare conditional route fairness and intended-strategy-versus-actual-victory, not only unconditional win share. Record victory route, round, fallback action, illegal proposal, timeout, and recoverability metrics.
5. Require the compact controller to meet a pre-registered retention gate: no material increase in invalid/censored games; median route-conditioned outcome within the declared equivalence margin of the teacher; no route/faction cell below the minimum sample gate; and no action-family collapse (for example, a tree that emits only one production class).
6. Hold out seeds and at least one faction/hostile condition. The teacher itself must be evaluated on the same blocks. Any format selected by holdout performance is an experiment result, not a shipping default.

There is no valid claim of “full-game retention” until this protocol produces matched, finished game artifacts. One-step teacher agreement is insufficient because CivCraft retains state, research progress, cities, units, and route commitments across many turns.

## Native benchmark to run later

Parent should mount `games/civcraft/research/lab` into the same native CraftOS/Lua environment used by the controller, then run `native_inference_benchmark.lua` for 120 seconds per format. Capture:

- calls/second and maximum single-call latency;
- `collectgarbage("count")` heap delta after a collection;
- generated export bytes (`fs.getSize`);
- legal fallback rate and action histogram over varied feature/legal rows;
- watchdog behavior under the same turn budget as the real AI.

The benchmark must be isolated from full game state and run with each format loaded in a fresh process or reset. It should not be used to infer game strength. The parent-supplied `/tmp/civcraft-lua-env/bin/python` remains the intended offline Lupa environment for later integration checks; this preparation did not start it for a game.

## Files prepared

- `policy_format_comparison.py`: extractor, label fixture, three fitters, legal fallback, Lua exporters, and fixture-only benchmark.
- `datasets/teacher_archive_manifest.json`: archived teacher provenance and ingestion rules.
- `datasets/teacher_decision_labels.schema.json`: machine-readable decision-record schema.
- `datasets/teacher_trace_contract.json`: exact `Production.ranked` / `Research.ranked` capture contract for real labels.
- `datasets/policy_format_fixture.jsonl`: deterministic observer-safe non-constant fixture.
- `formats/weights.lua`, `formats/rule_tree.lua`, `formats/tiny_quantized_mlp.lua`: generated self-contained Lua artifacts.
- `native_inference_benchmark.lua`: bounded native harness (five 4-second batches; the attempted 120-second variant timed out under the watchdog).
- `retention_comparison.py`: offline reducer for completed teacher/candidate full-game artifacts; it never starts a match.
- `collect_teacher_traces.py`, `datasets/teacher_traces_actual.jsonl`, and `results/teacher_trace_collection.json`: actual source-ranked observer labels.
- `train_actual_formats.py`, `formats/actual_*.lua`, and `results/actual_policy_format_comparison.json`: actual train/holdout fits.
- `run_actual_retention.py` and `results/actual_full_game_retention.json`: corrected 24-match bounded seat-rotated retention suite with oracle hash control and before/after provenance hashes.
- `results/actual_full_game_retention_adapter_confounded.json`: preserved invalid pre-correction diagnostic.
- `run_native_format_benchmark.py` and `results/native_actual_format_benchmark.json`: fresh-process CraftOS cost/parity measurements.
- `results/policy_format_offline_comparison.json`: preparation result with explicit claim limits.

No live-game source files, tools, action rules, or existing research reports were modified for this increment; the games were executed only through the existing research Runtime and native harness.
