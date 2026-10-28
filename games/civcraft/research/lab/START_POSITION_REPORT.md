# Start-position permutation report

## Purpose and method

This is a research-only geography-versus-seat/order probe. It ran eight bounded
games: the four requested seeds (`203807`, `708091`, `807121`, `509443`) in a
baseline arm and a reverse arm. Both seats used the same Forge expedition
champion policy from `results/strategy_search_pilot.json`; map size was compact
Pangaea, hostile mode was off, the round budget was 180, and the worker pool was
three spawned processes through `tools/civcraft_lab/workers.py`.

The reverse arm is implemented only by a `Runtime` subclass in
[`start_position_permutation.py`](start_position_permutation.py). Before the
first `Engine.newGame` call it wraps the cached `World.generate`, swaps
`world.starts[1]` and `world.starts[2]`, and returns the generated world. Normal
initialization, village generation, vision, AI, production, diplomacy and
victory code then run unchanged. No core or tool module was edited.

Command:

```sh
/tmp/civcraft-lua-env/bin/python \
  games/civcraft/research/lab/start_position_permutation.py --workers 3
```

The compact result is
[`results/start_position_permutation.json`](results/start_position_permutation.json).
The raw full trajectories and canonical final states are in
`/tmp/civcraft-start-position-permutation.raw.json` and are intentionally not
duplicated in the repository.

## Setup guards

All eight games finished; the run took 52.51 seconds, used three workers, and
reported `sourceChangedDuringRun=false`. Every seed passed all setup guards:

| Guard | Result |
|---|---:|
| Reverse starts equal baseline starts in opposite order | 4/4 |
| Terrain/geography/resources/landmarks/rails hashes unchanged | 4/4 |
| Neutral-village records unchanged | 4/4 |
| Hostile spawner records unchanged | 4/4 |
| Player assets unchanged after excluding spawn-derived visibility/map memory | 4/4 |

The last guard intentionally excludes `explored`, `visible`, `mapMemory` and
`knownLandmarks`: those are expected to differ because the player owns a
different starting coordinate. It still compares the initialized player
identity, civilization, AI difficulty, starting resources, stockpiles,
research state and readiness fields.

## Outcomes

All eight games ended with `END EXPEDITION` at the same round within each pair:

| Seed | Baseline starts (P0, P1) | Baseline winner | Reverse winner | Round | Geographic winner preserved? |
|---:|---|---:|---:|---:|---|
| 203807 | (5,5), (20,13) | P0 | P1 | 122 | Yes |
| 708091 | (5,3), (20,12) | P0 | P1 | 128 | Yes |
| 807121 | (5,5), (20,13) | P1 | P0 | 121 | Yes |
| 509443 | (4,3), (22,14) | P0 | P0 | 132 | No; the winning ID stayed P0 |

In three of four pairs, the winning player ID flipped exactly when the winning
geographic start moved to the other seat. In the fourth pair, player ID 0 won
both arms even though the winning geographic coordinate changed. This is useful
evidence that start geography explains a strong majority of these matched
outcomes, but it is not universal under this controller and sample.

The reverse arm deliberately leaves player IDs, names, entity IDs and actor
order unchanged. Therefore the fourth pair cannot separate geographic advantage
from identity/turn-order association or deterministic policy tie-breaking. It
must not be described as a causal geography result. The experiment also does
not establish a win probability or a general seat-bias estimate from four
paired seeds.

## Early trajectory and milestones

Each raw match records every round's state hash and compact per-player metrics;
the repository result retains the first 20 rows plus milestone transitions.
The first-round industry values demonstrate that the swapped start can change
the immediate economy while all players retain the same policy and starting
assets. For example, seed `203807` begins with P0/P1 industry `(6,5)` in the
baseline and `(5,6)` in the reverse arm. Later trajectories diverge even when
the final victory round remains paired-identical.

The compact result includes milestone transitions for age, technologies, city
count, settler presence and strategy. Full canonical final states remain only
in the raw artifact; no large canonical strings are embedded in the repository
result.

## Interpretation and next experiment

The safe conclusion is conditional: under the same Forge expedition champion,
compact Pangaea, hostile-off rules and these four seeds, geography tracked the
winner in 3/4 start swaps, while one pair remained attached to player ID 0.
That residual is exactly why future balance studies must independently rotate
policy, civilization, seat, names/entity IDs and actor order, and use more map
families and seeds. A two-seat start swap is a diagnostic probe, not proof that
the game has a geography-only or seat-only bias.

The raw artifact and source metadata record the run's exact script hash and
source manifest. The study is complete as a descriptive eight-game result; no
additional games are required to support the findings above.
