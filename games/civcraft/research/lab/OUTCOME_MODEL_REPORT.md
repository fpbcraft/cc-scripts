# Supervised outcome-model study

## Scope and frozen design

This is a privileged diagnostic model trained from actual CivCraft games. It
is not a playing policy, does not receive model outputs during a match, and
does not establish causal effects of rules or mistakes. The runner, game
modules, and policy adapter were unchanged.

The pre-run manifest was written before launch in
[`outcome_model_manifest.json`](outcome_model_manifest.json). The driver is
[`outcome_model_study.py`](outcome_model_study.py), and the compact result is
[`results/outcome_model_study.json`](results/outcome_model_study.json).

Executed command:

```sh
/tmp/civcraft-lua-env/bin/python \
  games/civcraft/research/lab/outcome_model_study.py --run --workers 2
```

Configuration was fixed at Forge-versus-Forge, compact Pangaea, hostile mode
off, 180-round limit, with two policy matchups:

- selected expedition champion vs fixed industrial specialist;
- selected expedition champion vs adapted expedition specialist.

Each matchup was run in both seat rotations. The disjoint map-seed blocks were
12 train, 6 calibration, and 6 final test seeds: 24 blocks × 4 games = 96
actual games. Every game completed. The 96 games produced 288 snapshots at
rounds 31, 61 and 91.

The raw batches remain independently recoverable:

- `/tmp/civcraft-outcome-model/train.json` — 48 games, 27 MB;
- `/tmp/civcraft-outcome-model/calibration.json` — 24 games, 14 MB;
- `/tmp/civcraft-outcome-model/test.json` — 24 games, 14 MB.

The train split ended with 44 `END EXPEDITION` and 4 `INDUSTRIAL` victories;
calibration had 21 expedition, 2 industrial and 1 shared expedition tie; test
had 23 expedition and 1 industrial victories. These labels are actual final
winner records, not inferred from the snapshot.

## Model protocol

The critic uses signed `log1p(player-0) - log1p(player-1)` differences for
population, industry, science, technologies, combat power, unit count,
buildings, gold and score. It fits standard-library L2 logistic regression
with no intercept, fixed `L2=0.1`, 1,000 iterations and learning rate 0.1.
Rows are kept in map-block/matchup/seat/snapshot order; no row shuffle occurs.
Each row is weighted by the inverse number of rows from its map seed, so every
map block contributes equal total weight despite repeated snapshots.

The model is fit only on the 12 train blocks. A single temperature is selected
only on the six calibration blocks using the pre-registered fixed grid
`exp(-4 .. 4)` with 801 points. The final test set is untouched until scoring.
Uncertainty resamples exactly the six test map seeds as clusters, with 2,000
deterministic bootstrap replicates; snapshot rows are never treated as
independent clusters.

## Final six-block test results

| Predictor | Brier ↓ | Log loss ↓ | Accuracy |
|---|---:|---:|---:|
| Constant train prior (0.625) | 0.2969 | 0.7893 | 0.375 |
| Learned, uncalibrated | 0.1960 | 0.5724 | 0.750 |
| Learned, calibration-temperature adjusted | **0.1753** | **0.5167** | 0.750 |

The learned weights were fit on train only. The calibration temperature was
`0.3715766910`; the test result therefore measures a genuine blocked
calibration procedure rather than tuning on the final maps.

### Reliability counts on the six test blocks

| Predictor | 0–0.25 | 0.25–0.5 | 0.5–0.75 | 0.75–1.0 |
|---|---:|---:|---:|---:|
| Constant prior | 0 | 0 | 72 | 0 |
| Uncalibrated | 0 | 39 | 25 | 8 |
| Calibrated | 8 | 31 | 19 | 14 |

The bins are descriptive counts, not proof of calibration with only six map
clusters. Calibrated mean prediction/observed win credit per occupied bin was
`0.166/0.250`, `0.423/0.129`, `0.544/0.368`, and `0.951/1.000`.

### Map-cluster bootstrap intervals

The intervals below are 2.5th–97.5th percentiles over 2,000 resamples of the
six test seeds:

| Predictor | Brier 95% cluster CI | Log-loss 95% cluster CI |
|---|---|---|
| Constant prior | [0.2344, 0.3281] | [0.6616, 0.8531] |
| Uncalibrated | [0.1281, 0.2363] | [0.4118, 0.6659] |
| Calibrated | [0.1010, 0.2272] | [0.3077, 0.6588] |

The intervals are wide because the final test contains only six independent
map blocks. They support this as a useful diagnostic baseline, not a production
win-probability guarantee.

## Integrity and limits

All 96 games were run with two bounded spawned workers. The source manifest and
script SHA-256 were identical before and after the run (`sourceChangedDuringRun=false`).
The compact result records source manifests before/after, script hashes before/after,
policy input hashes, fixed model hyperparameters, split seeds and separate raw
batch paths.

The study is intentionally narrow: all factions are Forge, all maps are
compact Pangaea, hostile mode is off, and both opponents are fixed archived
controllers. Six test blocks are insufficient for broad balance claims.
Snapshots within a match are correlated, and the critic uses privileged totals
that a player policy must never see. The result measures association between
state summaries and eventual outcomes; it does not prove that changing a
feature or game rule would change the win probability.
