# Baseline measurements and evidence boundaries

26 October 2026. This is a living research report, not a completed claim of faction or victory-route fairness. Source HEAD is `97944b8bc85e011d00abbdf45bf9aecdb82050ae` plus the explicitly recorded uncommitted shared-lifecycle extraction and laboratory sources. Exact Lua hashes are included in each result manifest. The studies below preserve their original source manifests. A later user-requested change H1 allows healer support outside territory while retaining owned-territory passive healing; see HEALING_CHANGE_VALIDATION.md. The broader costs, focus, content and victory proposals are still unimplemented.

## Hardware and runtime

The execution host was verified using `sysctl -n machdep.cpu.brand_string hw.memsize hw.logicalcpu`: **Apple M3 Pro, 38,654,705,664 bytes (36 GiB) unified memory, 12 logical CPUs**. Offline execution uses Python 3.14.6, Lupa 2.8, and its Lua 5.3 extension. Native checks use **CraftOS-PC 2.8.3 / ComputerCraft 1.112.0**. The dependency is pinned in [requirements.txt](../../../../tools/civcraft_lab/requirements.txt).

No GPU training or MPS speed claim has been measured. CPU simulation and small interpretable policies are the current prototype. The larger experiment protocol and training plan remain [separate requirements](AI_ML_RESEARCH_PLAN.md).

## Correctness gates actually executed

| Check | Executed scope | Result | Important limit |
|---|---|---|---|
| Original lifecycle reference | Six seeded fixtures, 2/3/4 players, lobby/setup/boundary/actor ordering | Passed | Frozen HEAD reference; does not prove every UI/network/victory flow |
| Native vs offline differential | Three fixtures, 2/4 players, accepted/rejected research, 3 actor/boundary cycles, full states and detached observations; includes an explicit exported-policy-format controller | 54/54 equal | Short early fixtures; complete-game check separately below |
| Complete native exported-policy game | Actual selected Lua policy export, Forge mirror seed 75123, no hostiles, full state compared at expedition victory | Exact state equality, round 125 | One full game; no proof across all factions, maps, wars or live Minecraft |
| Narrow registered war/capture and save/reload | Legal registered war and capture; native production Saves.save/load plus migration; full states/observer hashes | 21 checks passed | Includes two expected hostile-crash diagnostics; no Surprise War, old-save migration matrix or rednet |
| Python laboratory tests | Initialization with villages, 2–4 players, observation isolation/privacy, rejection immutability, proposal purity, deterministic replay, censoring, policy asset neutrality, instruction cutoff | 12 passed | Includes exact checkpoint continuation, invalid configuration, and enforced process timeout checks; league tests remain |
| Existing CivCraft Lua regressions | 54 scripts run independently with native Lua 5.3 | No failures; 837.23 seconds | Ran during extraction; later end-helper change additionally exercised by current native UI sessions |
| Real native UI sessions | Installed-loader environment; hotseat/AI/Surprise War and host/AI, settings/research/campaign/conversation/routes/history/Council/map tools/difficulty/civilization/save flows | Both PASS | Headless text backend; not physical Minecraft monitor/modem validation |

[Compact validation record](results/validation_summary.json), [native parity hashes](results/native_parity.json), [war/capture/save checks](results/wartime_save_parity.json). Native profile locations and the original regression log location are preserved in that record. They are disposable local artifacts, not durable release assets.

## Fresh authentic-game pilot

The first permanent-runner pilot used **real shared initialization**, including independent villages and Standard hostiles. This improves on the earlier research-only mirror fixture that had not initialized villages and disabled mobs. Six two-player cases and one four-player case ran with the current original AI at Prince, normal faction bonuses, no rule overrides, and the actual Standard deadline. [Manifest](pilot_manifest.json), [compact results and provenance](results/pilot_summary.json).

| Seed | Players in starting order | Status | Ending |
|---|---|---|---|
| 75123 | Forge / Forge | Finished | Industrial, round 149, player 0 |
| 75123 | Scholar / Iron | Finished | End Expedition, round 93, player 0 |
| 75123 | Iron / Scholar | Finished | End Expedition, round 96, player 1 |
| 95117 | Forge / Forge | Error | Hostile update failed after round 14 snapshot |
| 95117 | Scholar / Iron | Error | Hostile update failed after round 17 snapshot |
| 95117 | Iron / Scholar | Finished | End Expedition, round 100, player 1 |
| 18731 | Forge / Scholar / Iron / Merchant | Finished | End Expedition, round 106, player 1 |

All five completed games ended through a gameplay victory, not the research cutoff. Four ended through End Expedition. This is **not** an estimate that expedition should win 80% of games: the pilot deliberately includes several Scholar/Iron cases, fixed personalities/goals, reused seeds, unmatched opponent mixtures, and one four-player case. It is a diagnosis and harness exercise, not a balanced tournament design.

Errors remain visible: **5 completed / 7 attempted, 2 errors / 7 attempted**. Do not silently discard the two errors, score them as losses, or claim a clean seven-game benchmark. There are too few independent map blocks for a useful faction-fairness confidence interval; see [the preregistered protocol](EXPERIMENT_PROTOCOL.md) before a decisive study.

The batch took 57.86 wall seconds with two workers while other Lua validation work was active. This is a measured **pilot completion rate of about 5.2 completed games/minute**, including failed jobs, setup, and recording overhead. It is not an isolated throughput benchmark and must not be extrapolated into a guarantee for 10,000 games, large maps, four players, deep search, or thermally sustained runs. The individual four-player case took 38.95 worker wall seconds under that concurrent load. Later performance runs must isolate workload and report initialization, simulation, metrics, serialization, and memory separately.

Raw per-turn results are stored at `/tmp/civcraft-lab-pilot-results.json`; the compact repository record retains all configurations, final hashes, outcomes, errors, dispatch counts, and source hashes. Reproduce using:

```sh
python3 -m venv /tmp/civcraft-lab-env
/tmp/civcraft-lab-env/bin/pip install -r tools/civcraft_lab/requirements.txt
/tmp/civcraft-lab-env/bin/python tools/civcraft_lab/run.py \
  --config games/civcraft/research/lab/pilot_manifest.json \
  --output /tmp/civcraft-lab-pilot-results.json --workers 2
```

Install only into a disposable or dedicated environment. The runner source subsequently gained stronger per-worker wall-clock enforcement and error-state diagnostics; the original pilot manifest records the exact earlier implementation rather than pretending the rerun is byte-for-byte identical.

## Confirmed captured-settler runtime failure

Seed 95117 Forge/Forge was independently reproduced in real CraftOS-PC. A hostile captures Settler `id=22`, which becomes owned by the hostile faction without spawner metadata. On round 15, `hostiles.lua:103` indexes the per-spawner count with `nil`. The completed rounds before the failure are 14. This is a **runtime integrity defect**, not a simulation timeout or evidence that a strategy lost. [Issue BAL-00](BALANCE_ISSUES.md), [reproduction program](reproduce_hostile_capture.py), [native result](../../../../tools/civcraft_lab/results/hostile_capture_reproduction.json).

The gameplay implementation was left intact in this planning phase. Standard-hostiles sweeps must retain the error outcome, and cleaner controlled tests can disable hostiles explicitly while this defect awaits review. Such no-mob results must not be generalized to normal wilderness gameplay.

## Earlier pacing evidence retained with its provenance

The earlier [runtime content inventory](../civ6-balance-2026-10-26/CIVCRAFT-INVENTORY.md), [native start measurements](../civ6-balance-2026-10-26/civcraft_measurements.json), and [production-choice trace](../civ6-balance-2026-10-26/PRODUCTION-CHOICE-MEASUREMENTS.json) support narrower conclusions:

- A sampled opening with five industry and one science permits a one-round Scout and three-round Settler while a 24-science technology takes 24 rounds at constant income; Scholar has three science in that same setup.
- In one peaceful Forge mirror trace, every city-round snapshot through round 100 had zero or one legal building. That does not count military/wonder alternatives or alternate research paths and is not a universal distribution.
- Current Industrial victory repeats a 13-building, 890-industry local dependency closure in three connected cities. This explains the tension with specialization but is not an actual time-to-victory prediction.
- Existing faction matchup tables confound bonuses, policies, geography, and opponent composition. They cannot rank civilizations under comparably strong play.

The referenced content/economy/victory definitions are unchanged at the current HEAD. Earlier fixture hashes and setup limitations remain explicit; a successful older fixture is not mislabeled as the new authentic-game pilot.

## What has not been established

- Equal overall faction strength or comparable conditional victory-route success.
- A strategic optimum, robust exploit resistance, or an AI competence ceiling.
- A causal estimate of the Scholar bonus independent of policy and geography.
- The effect of proposed opening, specialization, army, or victory changes: none is implemented.
- Reliable win-probability prediction, mistake recovery probabilities, or a measured benefit from neural RL/distillation.
- Full wartime/save/reload/multiplayer/native-late-game differential equivalence.

## Executed policy optimization

The [economic-weight-only pilot](results/economic_weight_search_pilot.json) found **no held-out gain**: both original and selected controller earned 0.25 win credit over eight games each. Two initial training evaluations were invalidated by a source-manifest change; the guard worked, and this training run must not be described as a clean comparison.

The subsequent [source-frozen strategy-search pilot](results/strategy_search_pilot.json) used population three, two generations, one training map seed (75123), and two untouched evaluation seeds (95117, 18731). Both evaluation controllers faced the same original/adaptive and expedition-committed opponent mixture with swapped seats. All civilizations were Forge, all maps compact Pangaea, hostiles explicitly off, with unchanged game rules. The selected controller committed to expedition with food/industry/science/gold weights 1.277163/1.235594/1.416576/1.469771. It earned **6/8 held-out win credit (0.75), versus 2/8 (0.25)** for the original controller.

This is a real bounded black-box policy optimization result. It is primarily evidence for strategic commitment, not an isolated causal benefit of the four weight changes. It is not neural reinforcement learning, an intrinsic route-strength estimate, or a precise generalization estimate: the eight games have only two independent map blocks, reused opponents and seat rotations. No holdout tuning was performed, and no source changes occurred during the clean study.

## Archived route-controller cross-play

[Manifest](archived_route_league.json), [compact result](results/route_crossplay.json), raw `/tmp/civcraft-route-crossplay.raw.json`. Four archived controllers played each pair on seeds 99119 and 61283 with swapped seats: **24/24 completed, no source-integrity failure**. All were Forge, no hostiles, compact Pangaea. Each table cell is win credit in four matches, **not four independent map blocks**.

| Row controller versus column | Industrial | Selected expedition | Conquest | Diplomatic |
|---|---:|---:|---:|---:|
| Industrial | — | 0/4 | 4/4 | 3/4 |
| Selected expedition | 4/4 | — | 4/4 | 4/4 |
| Conquest | 0/4 | 0/4 | — | 0/4 |
| Diplomatic | 1/4 | 0/4 | 4/4 | — |

The selected expedition controller won all 12 appearances. The conquest controller won none. **Actual endings were 12 End Expedition and 12 Industrial, zero Diplomatic or Conquest.** All five diplomatic-controller wins qualified through Industrial despite the final policy goal still being diplomatic. Goal commitment is not an exclusive constraint on victory eligibility; this is expected under shared actual game rules. Reporting those five as diplomatic wins would produce a false balance conclusion.

These are wrappers around existing tactics, not equally capable route specialists. Conquest's stale-unit caps, campaign behavior and economic priorities require competence testing before weakening expedition or strengthening conquest on this evidence. Council additionally has a source-proven two-player veto: maximum unilateral delegates are 3/(3+2)=60%, below two-thirds, and victory explicitly requires another member's support. A rational rival can decline to elect the candidate. See [BAL-09](BALANCE_ISSUES.md). Costs alone cannot repair that structural route-agency problem.

## Matched early-mistake continuations

[Reproduction](measure_recoverability.py), [results](results/recoverability_pilot.json), raw `/tmp/civcraft-recoverability-pilot.json`. At the start of round 10, an exact canonical checkpoint was forked into an unchanged continuation and a continuation using one legal action to divert research from Mining to Sailing. Prior Mining progress was preserved by the existing rules. Each pair began with the same full-state hash; no resources, map or opponents were edited. The target was the selected expedition controller in seat zero, with Forge on both sides and hostiles off.

| Map seed | Opponent goal | Baseline | Sailing diversion | Interpretation |
|---|---|---|---|---|
| 99119 | Industrial | Win, expedition 127 | Win, expedition 137 | Win retained; 10-round delay |
| 61283 | Industrial | Win, expedition 127 | Win, expedition 138 | Win retained; 11-round delay |
| 99119 | Expedition | Win, expedition 130 | Loss, rival expedition 134 | Competitive outcome changed |
| 61283 | Expedition | Loss, rival expedition 126 | Loss, rival expedition 126 | Winner unchanged |

Eight continuations completed with a stable source manifest. This establishes reproducible local opportunity costs and an opponent-dependent outcome change. It does **not** estimate universal forgiveness, optimal recovery, or a calibrated recovery probability. There are two independent maps and one intervention type; the continuation policy was fixed rather than retrained or searched for the best response to the mistake.

## Small auxiliary ML diagnostic

A [reproducible logistic-regression pilot](fit_outcome_pilot.py) fitted final seat-zero win credit from signed log differences in nine economy/army totals at rounds 31, 61 and 91. Training used only seed 99119; holdout used only seed 61283. Each split contains 12 matches and 36 correlated snapshots from **one independent map block**. Hyperparameters were fixed before evaluation. [Dataset, coefficients, scores and limitations](results/outcome_model_pilot.json).

Held-out Brier loss was **0.1700**, compared with **0.2500** for the training-prior constant; log loss was 0.5143 versus 0.6931. Snapshot classification accuracy was 72.2%. This is a working offline diagnostic experiment, not evidence of calibrated probabilities: Brier/log loss combine discrimination and calibration, the reliability bins are tiny, and there is no separate calibration set. See the [primary calibration documentation](https://scikit-learn.org/stable/modules/calibration.html).

The critic uses privileged opponent totals. It is **never passed to a playing policy** and cannot be deployed as an observed-information agent. It neither replaces the true Lua engine nor proves causal effects of mistakes. Generalization across factions, unseen controllers and independent map populations remains untested.

## Actual native export execution

The [selected 207-byte policy data export](selected_policy.lua) was loaded from disk in real CraftOS-PC by the offline research adapter and ran to End Expedition victory at round 125. The native and Lupa complete final states had identical SHA-256 `33758cc931da1153cd959a45eadce92db5546943dbb5e190fe53b864703981ab`. [Reproduction driver](check_full_policy_parity.py), [native fixture](native_policy_match.lua), [result](results/full_policy_native_parity.json).

The measured native match took 12,823 ms, with a worst sampled actor callback of 69 ms, 413 cooperative yield/collection checkpoints, and peak **sampled** Lua memory 22,083 KiB. These include game execution and adapter work; they do not isolate policy inference cost or prove a Minecraft computer's memory requirements. The first adapter attempt lacked native cooperative hooks and hit the watchdog; the successful adapter installs the game's existing cooperative checkpoints and yields/collects between rounds. No gameplay rule changed to obtain the match.

This proves one full-game retention case for exported weights/goal data. It does not compare distilled trees against tiny networks or authorize live AI deployment.

## First adversarial archive-adaptation round

The [archive-adaptation driver](adversarial_archive_pilot.py) trained against a
fixed mixture of the previous selected expedition champion and Industrial
controller. Population three, two generations and rotated seats produced 24
training matches on seed 451139. Selection used training only. Eight further
matches on untouched seeds 808381/919393 evaluated a previous-champion mirror
and previous champion versus adapted policy. **All 32 completed with unchanged
engine/policy source.** [Compact result and candidate archive](results/adversarial_archive_adaptation_pilot.json).

The selected expedition mutant had food/industry/science/gold weights
1.103751/1.548743/1.645151/0.692060. Training fitness was 4/4. On the four
held-out direct matches it earned **3/4 credit versus the previous champion's
1/4**. The previous champion's mirrored control was 0.50/0.50 by subject
identity. Here “previous champion” is the earlier evolved expedition policy,
not the shipping original AI; the raw artifact's `baselineOriginal` field
name refers to that archived source policy.

This is one real adaptation step against archived opponents, beyond merely
cross-playing fixed policies. It does not establish an equilibrium, demonstrate
strategy cycling, prove exploit resistance, or validate a large league. Each
holdout has only two map blocks, one faction, fixed opponent types and hostiles
off. Later archive regression/cycling/counter tests remain required. Runtime
throughput was confounded by the concurrent faction sweep and is not a hardware
benchmark.

## Same-goal faction sweep and remaining personality confound

The [36-match manifest](faction_policy_manifest.json) used the same selected
expedition goal/weights in every seat, comparing each of the nine non-Forge
factions to Forge on new seeds 203807/708091, with starting positions swapped.
All 36 completed through End Expedition with a stable source manifest.
[Compact results](results/faction_policy_pilot.json), raw
`/tmp/civcraft-faction-policy-pilot.json`.

Scholar, Nomad and Wild each won 4/4 appearances; Mariner won 3/4; Verdant,
Iron, Highland, Merchant and Sentinel each won 2/4. Seat zero won 29/36 overall
and every non-Forge faction won both of its seat-zero cases. These are **not
pure faction-bonus effects**: `ai_personalities.lua` still changes behavior by
civilization, and only two geographic starts were sampled. A shared strategic
wrapper does not hold the full policy constant. The observed seat association
does not by itself identify a scheduler or victory-tally bug; source inspection
shows that `Victory.check` collects all same-check qualifiers. Separate geography,
personality and actor-order experiments are needed before making a tier list.

## Fixed-personality faction ablation

The [research-only driver](run_fixed_personality_ablation.py) repeats the same
36 configurations while pinning the personality lookup to a copy of Forge's
profile for both seats, before the first actor pump. It changes policy
preferences only: actual civilization bonuses, starting assets, action budgets,
vision and authoritative rules remain unchanged. **36/36 completed**, all End
Expedition, with an unchanged source manifest. The driver hash and explicit
hook are recorded in [the compact result](results/faction_policy_ablation.json);
raw records are `/tmp/civcraft-faction-policy-ablation.raw.json`.

| Non-Forge faction versus Forge | Own personality | Fixed Forge personality |
|---|---:|---:|
| Scholar | 4/4 | 4/4 |
| Nomad | 4/4 | 2/4 |
| Wild | 4/4 | 2/4 |
| Mariner | 3/4 | 1/4 |
| Verdant, Iron, Highland, Merchant, Sentinel (each) | 2/4 | 2/4 |

The expansionist personality materially explains the Nomad/Wild advantage in
this paired slice; Mariner also loses its earlier advantage when it is pinned.
Scholar remains ahead in both seats on both maps, supporting further tests of
its research bonus without proving its all-map/all-route strength. Under the
fixed personality, seat zero won 33/36. The remaining seat association is still
not separated into geography, policy tie-breaking and actor scheduling. Two
map blocks cannot establish a population seat bias or a faction tier list.

## M3 scaling and native conformance follow-up

[The measured host study](PERFORMANCE_REPORT.md) ran twelve executions of four
fixed two-/four-player worlds at one, two and four workers. All final hashes
matched across worker counts. Batch times were 78.05, 41.10 and 31.31 seconds;
maximum per-worker RSS was about 47 MiB. Actor pumps consumed about 85% of CPU.
An inclusive Lua profile identifies repeated observer capture/detachment as
the largest optimization lead; removing privacy safeguards is not an accepted
optimization. No sustained thermal result is available.

[Expanded native conformance](CONFORMANCE_EXTENSION_REPORT.md) adds 75
cross-runtime comparisons for observer privacy, Surprise War attacker finish,
defender reaction, both observer views, proposals and trace replay. Defender
waiting before attacker completion is correct scheduler behavior, not a bug.
The earlier 21 save/capture checks and expected hostile-crash diagnostics
remain separate.

## Interrupted compact-policy study: evidence under review

Real teacher traces and eight complete format-comparison games were recovered
after the usage interruption. These do not yet establish retained strength:
the original controller and every candidate lost both fixed-seat cases. The
retention driver's source guard captured both manifests after the study,
so its source-clean field does not verify source stability during execution.
A corrected guarded, bounded, seat-rotated evaluation is required.

The tree's reported 99.26% teacher agreement additionally has an 85.4% fallback
rate. Agreement that depends on falling back to the original ordered candidate
list cannot be credited to the distilled tree. Native export timing and real
Python/Lua prediction parity are still pending. Preserve the completed raw
records, report their limitations, and do not label prepared/synthetic formats
as trained gameplay strength.

## Recovered follow-up results and adapter control requirement

The corrected compact-policy run completed twenty bounded, seat-rotated games
with before/after engine and model hashes unchanged. The original controller
earned 2/4 target-seat win credit against itself, the archived expedition
champion 4/4, and each compact format 0/4. Native inference was also measured
in fresh CraftOS-PC processes over actual held-out vectors: linear classifier
24,836 bytes/8,522 calls per second, tree 4,469 bytes/666,992 calls per second,
and int8 MLP 6,201 bytes/9,086 calls per second. All 1,488 held-out vectors
matched Python predictions exactly. See POLICY_FORMAT_COMPARISON.md and its
machine-readable results.

**Interpretation correction:** the current adapter replaces AI.choose and
queues predictions directly, bypassing the original incumbent-project
completion, difficulty choice and retry semantics. Therefore the observed
0/4 results are a failure of these complete adapter/model combinations, not
an isolated causal estimate that any model format is inferior. A teacher-oracle
arm and a ranking-only adapter are required before attributing the drop to
distillation. Training also targets top-ranked recommendations rather than
actual selected orders, and Python/Lua feature aggregation requires alignment.
The already validated 207-byte strategic goal/weight export is a different
task from these larger multiclass research/production approximators.

The starting-location study completed eight games with all map, neutral-village
and initial-asset guards passing. The winning geographic start persisted in
three of four swapped pairs; the remaining case retained player ID instead.
See START_POSITION_REPORT.md. This narrows the earlier seat association without
proving a universal actor-order or geography effect.

The military diagnostic identifies a specific first bottleneck: in seed 95117
the scout stopped exploring from round 14 despite four movement points, and
the conquest controller never discovered another player. A research-only
observed-frontier routing hook produced contact and a legal declaration at
round 25 in the paired retest. Four of six hook cases declared war; none
captured a city or won Conquest. Thus exploration competence matters, but
declaration-to-capture execution still needs diagnosis before combat or route
costs are calibrated. See MILITARY_COMPETENCE_REPORT.md.
