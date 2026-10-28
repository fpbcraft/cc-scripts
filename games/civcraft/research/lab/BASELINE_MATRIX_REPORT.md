# CivCraft fixed-strategy baseline matrix

## Purpose and scope

This is a research-only baseline for the current ruleset. It is a fixed
strategy slice, not an all-route fairness study and not a claim about the
balance of every faction, policy, map, or victory route. Every target game
uses the selected expedition policy from
`results/strategy_search_pilot.json`; Forge uses the existing fixed-personality
ablation hook. Hostiles are disabled so the first pass isolates faction,
geography, seat rotation, and this policy's outcome behavior.

The matrix has 152 games:

* Four map families (`continents`, `archipelago`, `pangaea`, `highlands`),
  two fixed seeds per family, giving eight independent map-family/seed blocks.
* Nine non-Forge civilizations, each tested in both seats against Forge:
  `verdant`, `iron`, `scholar`, `nomad`, `wild`, `mariner`, `highland`,
  `merchant`, and `sentinel` (9 x 2 x 8 = 144 target games).
* One Forge-versus-Forge mirror per map block (8 games), used as a control.

The seeds are new to this matrix and were not reused from the 96-game outcome
model split. The same seed is reused across the 19 configurations in its
block, which makes matched geography explicit; it does not turn the rows into
independent random maps.

Configuration: compact map, hostile mode off, 180-round deadline, metrics every
10 rounds, instruction budget 200,000,000, action budget 4,096, and four
bounded workers. Player IDs and actor order are the normal runner defaults, so
the result is not a causal claim about seat identity.

## Results

The run completed all 152 games in 499.861 seconds (about 8.33 minutes):

* status counts: 152 `finished`, zero errors, timeouts, censored, or invalid
  setups;
* all 152 ended with `END EXPEDITION`;
* among the 144 target games, all 144 had the intended expedition route and
  all 144 finished on `END EXPEDITION`;
* target win credit (a shared-winner credit would be divided among winners):

| Target civilization | Games | Target win credit | Route |
| --- | ---: | ---: | --- |
| highland | 16 | 0.5000 | expedition |
| iron | 16 | 0.5625 | expedition |
| mariner | 16 | 0.4375 | expedition |
| merchant | 16 | 0.5000 | expedition |
| nomad | 16 | 0.5000 | expedition |
| scholar | 16 | 1.0000 | expedition |
| sentinel | 16 | 0.5000 | expedition |
| verdant | 16 | 0.5625 | expedition |
| wild | 16 | 0.5000 | expedition |

Across the eight map-family/seed blocks, the target credits were:

| Map family | Seed | Target games | Target win credit |
| --- | ---: | ---: | ---: |
| archipelago | 620117 | 18 | 0.6111 |
| archipelago | 620119 | 18 | 0.5556 |
| continents | 610111 | 18 | 0.5556 |
| continents | 610113 | 18 | 0.5556 |
| highlands | 640137 | 18 | 0.5556 |
| highlands | 640139 | 18 | 0.5556 |
| pangaea | 630127 | 18 | 0.5556 |
| pangaea | 630131 | 18 | 0.5556 |

The eight-block mean target credit is 0.5625. A 95% Hoeffding descriptive
bound over those eight block means is `[0.0823, 1.0000]`. This wide interval is
the honest small-cluster uncertainty; it is not a population estimate over all
possible maps and should not be read as a faction balance confidence interval.

The scholar result is a strong signal for a follow-up, but this study cannot
separate faction strength from the selected expedition policy, the fixed
personality opponent, the compact map, no-hostile setting, or the expedition
route's terminal behavior. The mariner result is likewise only a diagnostic
within this slice.

## Checkpointing and provenance

`checkpointed_baseline_batch.py` writes one atomic JSON record per game under
`runs/baseline-matrix-v1/`; that directory is intentionally ignored because
the raw records are large. A record is reusable only when its terminal status,
job ID, exact config, source fingerprint, and runtime-adapter fingerprints all
match, including the frozen driver hash on resume. Non-terminal or malformed records are rerun; a worker result with no
payload is recorded as an error rather than silently dropped. The manifest is
written before the run and contains the complete job list, policy, seeds,
limits, source manifest, script hash, and adapter fingerprints.

The resumability smoke used two max-rounds-two jobs and three passes: first one
job, then the remaining job, then a cached-only pass. It passed with
`sameHashesAfterResume=true`, `cachedOnlyThird=true`, and zero launches on the
third pass. The compact result was subsequently recomputed from the 152 durable
records only; no game was rerun for the eight-block correction. The result
therefore preserves the original run script hash
`27de64ce6533a7e1b5af01438a1735e7e84c336a8a1699921a01cbc433d3f083` and source
hash before/after
`9b12a1a22939d9e06834dff3743756f7b864eb3e12f40aaa109917ab1f0af38f`, with
`sourceChangedDuringRun=false`. The post-run analysis script hash is recorded
separately in `results/baseline_matrix.json`.

## Reproduction

From the repository root:

```text
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/checkpointed_baseline_batch.py --prepare-manifest
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/checkpointed_baseline_batch.py --run --workers 4
```

To rebuild only the compact summary from already completed atomic records:

```text
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/checkpointed_baseline_batch.py --analyze-existing
```

The machine-readable summary is
`results/baseline_matrix.json`; the frozen job/source manifest is
`baseline_matrix_manifest.json`. This report deliberately does not claim
all-map population fairness, all-victory-route viability, or a causal seat
advantage.
