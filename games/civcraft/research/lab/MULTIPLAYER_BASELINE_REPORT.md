# Multiplayer baseline report

Date: 27 October 2026
Status: **completed research-only slice; not a balance or faction-equivalence claim**
Driver: [`multiplayer_baseline_batch.py`](multiplayer_baseline_batch.py)
Manifest: [`multiplayer_baseline_manifest.json`](multiplayer_baseline_manifest.json)
Result: [`results/multiplayer_baseline.json`](results/multiplayer_baseline.json)

## Question and design

This is the requested current-rules 3/4-player context slice:

| Factor | Levels |
|---|---|
| Map family | Pangaea seed `730127`; Archipelago seed `740131` |
| Roster | all Forge; mixed roster |
| Mixed 3-player pairs | Forge/selected Expedition, Mariner/adapted Expedition, Scholar/Industrial |
| Mixed 4-player pairs | Forge/selected Expedition, Mariner/adapted Expedition, Scholar/Industrial, Merchant/original adaptive |
| All-Forge roles | selected Expedition, adapted Expedition, Industrial, plus original adaptive in 4-player games |
| Seat control | every role/civilisation pair occupies every seat once within each 3- or 4-player map/roster block |
| Rules | current source, compact map, Standard 180 rounds, hostiles off |

The design is `2 map families × 2 rosters × (3 seat rotations + 4 seat rotations) = 28 games`. Seat rotation moves the role and civilisation together. The same seed is reused within a map-family block so the contrast is roster/seat/policy assignment, not a claim that the two map families are independent replications.

The role policies are existing research artifacts: selected Expedition is the clean strategy-search champion; adapted Expedition is the selected archive-adaptation policy; Industrial is the pre-registered literal Industrial goal; original adaptive uses an empty policy and therefore preserves the native personality-driven planner. No live AI, game rule, `tools/civcraft_lab` source, or gameplay content was modified.

## Execution integrity

- 28/28 games finished; no timeout, error, censor or invalid setup was scored.
- Each game was written as an atomic record under `runs/multiplayer-baseline-v1/` before the next bounded batch.
- The driver used two bounded workers and the authoritative Lua Runtime/runner. The completed records retain initial/final hashes, all round telemetry, per-player policy/civilisation identity, and read-only victory eligibility status.
- A post-run reducer bug treated `(turn, player)` tuples as turns. All 28 records had already been persisted; [`summarize_multiplayer_baseline.py`](summarize_multiplayer_baseline.py) reduced those records without launching games. The result explicitly records `gamesLaunched: 0` for post-processing and retains the original run provenance.
- Source was unchanged before/after the games. The driver and runtime/workers fingerprints are in the manifest and each durable record.

## Observed outcomes

| Finished route | Games |
|---|---:|
| `END EXPEDITION` | 17 |
| `INDUSTRIAL` | 10 |
| `END EXPEDITION / END EXPEDITION` | 1 |

The shared Expedition result is fractional-credit eligible: each qualifying winner receives `1/2` winner credit. No game ended by Conquest, Diplomatic, Score, draw, error or censor.

### Winner credit by map and roster

Winner credit is the per-role share of finished-game winner credit, not a population win rate. The nominal reference is `1/3` in a three-player game and `1/4` in a four-player game.

| Map | Roster | Selected Exp. | Adapted Exp. | Industrial | Original adaptive |
|---|---|---:|---:|---:|---:|
| Pangaea | all Forge | 0.643 | 0.357 | 0.000 | 0.000 |
| Pangaea | mixed | 0.000 | 0.000 | 1.000 | 0.000 |
| Archipelago | all Forge | 0.571 | 0.429 | 0.000 | 0.000 |
| Archipelago | mixed | 0.143 | 0.429 | 0.429 | 0.000 |

The mixed Pangaea block is a single map seed with three- and four-player seat rotations; its Industrial result is a context observation, not evidence that Scholar or Industrial is universally advantaged. The all-Forge rows show that selected/adapted Expedition and Industrial do not have exchangeable competence in this controller set. Original adaptive wins zero winner credit in this slice and must not be used as a neutral baseline without a competence diagnosis.

Across all role-seat rows, winner credit was selected Expedition `0.339` (10 winning rows, 9.5 fractional credit), adapted Expedition `0.304` (9 winning rows, 8.5 fractional credit), Industrial `0.357` (10), and original adaptive `0.000` (0). These totals mix 3- and 4-player nominal denominators and are descriptive only.

## Opening and progression observations

The result retains `gameProgress` for every finished game and every player. It records first positive science, first completed technology, first second city, first route-eligibility signal, route intent at finish, final technology/city totals, and final eligibility status.

Across the 28 games:

| Role | First science | First technology | Second city | First victory-eligibility signal |
|---|---:|---:|---:|---:|
| Selected Expedition | round 1 in all 28 | median 14.5 (11–19) | median 5 (4–13) | 10/28; median 126.5 (114–133) |
| Adapted Expedition | round 1 in all 28 | median 14.5 (11–19) | median 5 (4–13) | 9/28; median 121 (104–138) |
| Industrial | round 1 in all 28 | median 10.5 (7–19) | median 5 (4–13) | 10/28; median 109.5 (107–116) |
| Original adaptive | round 1 in all 16 | median 14.5 (12–19) | median 5 (4–13) | 0/16 under the exposed route-status signals |

“First victory eligibility” is the first observed positive status among conquest, Expedition, Industrial or diplomatic checks. It is not a victory and does not imply route feasibility: for example, the Industrial status requires the sustained-turn target, while Expedition status records the Dragon prerequisite. The raw rows retain `connected`, `industryTurns`, and `industryTarget` for interpretation.

Route intent at finish was stable for the explicit policies: selected and adapted Expedition reported Expedition in all 28 role rows; Industrial reported Industrial in all 28. Native original adaptive reported Industrial in eight rows and Diplomatic in eight rows, demonstrating why intended strategy and actual victory must be reported separately.

## Map-cluster uncertainty

There are only two map clusters. For each roster/role cell, the result reports the mean of the two map-level winner-credit means and a deliberately wide descriptive Hoeffding bound. These bounds mostly span `[0, 1]`; they are not population confidence intervals and should not be used to declare faction or route balance. The nominal per-pursuer references remain `1/3` and `1/4`, shown in the JSON beside each role summary.

The appropriate interpretation is:

- the matrix successfully exposes current 3/4-player progression and route interaction on two map families;
- seat rotation removes the most obvious fixed-seat confound within each block;
- map, roster, policy competence and route intent remain intertwined;
- two seeds cannot distinguish map-family effects from one unusual generated world;
- the absence of Conquest/Diplomatic wins is an outcome of these controllers and controls, not proof those victory routes are pointless or impossible.

## What this does and does not answer

This closes the requested multiplayer baseline slice and supplies current-head telemetry for the next experiment. It does not establish:

- faction equivalence for Forge, Mariner, Scholar or Merchant;
- conditional victory fairness, because route-capable controllers are not comparably strong;
- general 3/4-player balance across maps, speeds, hostiles or independent seeds;
- causal map versus roster effects, because each family has one new seed;
- diplomatic fairness, especially the known two-player structural rival-vote veto;
- multiplayer networking/rednet or interactive CraftOS behavior;
- approval for any gameplay rebalance.

The next valid use is a larger seeded tournament with competent route controls, route-feasibility/intention denominators, clustered uncertainty by independent map seed, and explicit censor/error accounting. This 28-game slice should be retained as a current-rules reference block rather than merged into an unconditional faction win-rate leaderboard.
