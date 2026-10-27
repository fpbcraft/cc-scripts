# Lead persistence and endgame timing

This is a descriptive analysis of the existing outcome-model holdout, not a
new batch of games. The 24 completed matches span six independent test map
seeds, four controller/seat configurations per map. They use compact Pangaea,
Forge, no hostiles and the historical pre-H1 source fingerprint. See
[machine-readable results](results/lead_persistence.json) and
[outcome model study](OUTCOME_MODEL_REPORT.md) for provenance and split details.

| Snapshot round | Unique score leaders | Leader's mean final win credit | Model confidence at least 80% | Median rounds remaining in those confident cases |
|---|---:|---:|---:|---:|
| 31 | 16/24 | 75.0% | 5/24 | 92 |
| 61 | 24/24 | 54.2% | 5/24 | 62 |
| 91 | 24/24 | 79.2% | 9/24 | 34 |

Score alone does not reliably identify who is closest to the actual finish:
at round 61, its leader wins only about half these games. Even late, nine
confident predictions leave a median 34 rounds before completion. These are
useful cases to inspect for late-game waiting and meaningful counterplay.
They do not establish that the intervening turns are pointless: the analysis
does not evaluate alternative continuations, invasions or optimal resistance.

The critic receives privileged evaluator totals; playing policies never
receive those features. Its probability threshold and calibrated weights
were fixed before this final-test analysis. At rounds 31 and 61, four of five
confident predictions win; at round 91, nine of nine win. Six map clusters
give very wide uncertainty, so those small subsets are not a calibrated
guarantee of inevitability. Score ties are excluded from leader averages.

The design implication is to track route progress and intervention windows
alongside aggregate score. The existing Civ VI comparison describes staged
space projects and the expedition travel phase; those are useful templates
for separating preparation, commitment and a visible contest window. The
proposed complementary Industrial contributions and staged End requirements
should expose their equivalent progress to opponents. This study gives no
basis for choosing an exact hold duration or adding a comeback subsidy.

For a reviewed prototype, compare matched control/candidate checkpoints:
record when a rival can first identify the route, the cost and travel time
of a credible interruption, progress lost when interrupted, recovery time,
and the final gap between a persistent lead and completion. Use adapted
opponents and count failed interventions as well as successful ones. A
stronger controller overturning an apparent early lead is evidence against
treating that checkpoint as already decided.
