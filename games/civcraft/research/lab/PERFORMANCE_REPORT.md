# M3 simulation performance and optimization evidence

The permanent runner now has a measured short scaling baseline, rather than a
throughput estimate inferred from the earlier concurrent pilot. This report
does not promise sustained thermals or a 10,000-game completion time.

## Executed host scaling study

```sh
/tmp/civcraft-lua-env/bin/python \
  games/civcraft/research/lab/benchmark_host.py
```

[Compact result](results/host_benchmark.json), raw
`/tmp/civcraft-host-benchmark.raw.json`. The verified host is Apple M3 Pro,
36 GiB unified memory, twelve logical CPUs; Python 3.14.6 and Lupa 2.8/Lua 5.3.
The sandboxed benchmark's hardware query was unavailable, so a separate
read-only host query is recorded explicitly in the result. `pmset` could not
read thermal/performance warning status; absence of thermal data is not a
claim that no throttling occurred.

Every worker level runs the same four complete games: seeds 404977/616039,
two and four players, all Forge with the selected expedition policy, compact
Pangaea and hostiles off. Each game runs in a fresh spawned worker with the
existing wall/instruction/action safeguards. Initialization, actor phases,
round boundaries, metrics, canonical encoding, JSON encoding, process CPU and
RSS are separately recorded. No other full-game study ran concurrently;
brief conformance smoke checks overlapped the first single-worker level.
OS/user background activity was not controlled.

| Workers | Batch wall seconds | Completed games/minute | Speedup versus one worker | Largest single-worker RSS |
|---|---:|---:|---:|---:|
| 1 | 78.05 | 3.08 | 1.00× | 45.66 MiB |
| 2 | 41.10 | 5.84 | 1.90× | 46.69 MiB |
| 4 | 31.31 | 7.66 | 2.49× | 46.39 MiB |

All twelve executions completed, with no source changes and **identical final
hashes across worker levels**. Their ending rounds were 135/121 for two-player
games and 127/112 for four-player games, all End Expedition. Total worker CPU
was 77.47–78.97 seconds per four-game batch. Per-game CPU ranged from about
9.7 to 31.1 seconds, explaining the short batch's unequal worker utilization.
This suite is a scaling test, not twelve independent balance samples.

Actor pumps consumed approximately **85% of process CPU**. Round boundaries
consumed about 14%; metrics/conversion and canonical encoding together were
under 1%. The first batch's 491 actor phases used 66.13 CPU seconds and its
491 round boundaries 10.57 seconds. Initialization total was 0.054 seconds for
four games. JSON costs and output byte counts are retained per match in raw
profiles. Further compressing metrics cannot plausibly solve the main CPU
bottleneck in this workload.

Peak sampled Lua memory was about 11.4 MiB. Process RSS is a per-process
lifetime high-water mark; it is not simultaneous aggregate memory, and neither
it nor sampled Lua memory proves a CraftOS computer's memory requirements.
The earlier [native export match](results/full_policy_native_parity.json)
remains separate evidence for native execution.

Four workers are a reasonable next local default for these compact games,
with bounded processes and headroom for other work. Six workers and sustained
loads need their own measured study. Do not multiply this short mixed suite
into a guaranteed overnight schedule or assume larger maps share its rate.

## Inclusive Lua CPU profile

```sh
/tmp/civcraft-lua-env/bin/python \
  games/civcraft/research/lab/profile_ai.py
```

[Result](results/ai_cpu_profile.json). One four-player control from the host
study was instrumented by wrapping existing Lua functions, without changing
rules or decision scores. It completed with the exact unprofiled final state
hash. Process CPU was 31.81 seconds. These are **inclusive, overlapping** times;
do not add nested rows.

| Function | Calls | Inclusive CPU seconds |
|---|---:|---:|
| Presentation.capture | 9,597 | 15.62 |
| AI.knowledge | 9,381 | 15.27 |
| AI.choose | 1,436 | 6.96 |
| World.forPlayer | 9,597 | 6.52 |
| AI.military | 2,371 | 6.48 |
| AI.staff | 1,436 | 4.98 |
| Production.ranked | 1,436 | 3.07 |
| Tactics.ranked | 2,379 | 2.39 |
| Settlement.select | 1,488 | 1.60 |
| Routes.from | 1,502 | 0.95 |

Observer projection/detachment is the strongest optimization lead in this
fixture. The AI intentionally refreshes knowledge between actions, while
`Presentation.capture` deeply detaches the result of `World.forPlayer`,
including nested own-player memory. Removing fog checks or allowing mutable
host references would invalidate the research instrument.

Prefer a separately tested projection optimization: explicit read-only
boundaries, dependency-aware invalidation after accepted orders **and direct
AI-memory writes**, and no stale rival information. An AI-specific minimal
observation may be considered only with an explicit feature contract,
adversarial privacy tests and ordered-action/full-state differential tests.
A cache keyed only by round is unsafe because units move, reveal and attack
within a round. This report proposes that work; it does not silently replace
the current observation semantics to improve a benchmark.

## Consequence for ML experiments

The mixed suite's four-worker short rate is about 460 completed games/hour,
below the current research plan's proposed 1,000/hour full-game RL gate.
Neural training is therefore not presumed to be the next useful step.
Evolutionary tuning, compact distillation and short military curricula can
produce useful evidence while the authentic engine remains authoritative.
Any shortened-scenario gains still need complete held-out games.

Memory did not constrain this small workload; expensive strategic simulation
and repeated observation construction did. GPU/Metal acceleration would not
automatically accelerate the Lua game loop. No GPU speedup is claimed. The
next benchmark should include representative large maps, war-heavy games, varied player counts, longer load periods and adaptation/search overhead.
