# P1 matched pacing pilot

P1 improves production continuity and slows opening expansion in this pilot.
It does **not** establish good overall balance: exploration arrives later,
midgame unit counts converge, and Industrial endings become more common
under the fixed expedition controller. No further gameplay changes were made.

## Design and executed scope

[Runner](p1_pacing_study.py), [analysis](analyze_p1_pacing.py),
[per-game records](results/p1_pacing_pilot.json),
[paired summary](results/p1_pacing_summary.json).

48 full matches: 24 matched original/P1 conditions on **four distinct map
blocks**. Pangaea seeds 611953/753979; Archipelago 817069/932081; compact maps,
standard campaign speed, hostiles off. Each map uses Forge/Forge,
Scholar/Forge and Forge/Scholar, with both players using either the archived
selected Expedition policy or the Industrial specialist. All personalities
are held to Forge to separate faction rules from personality changes.

These are six correlated roster/policy cells per map, not 24 independent
maps or 96 independent players. Both economies have 24 finished games and
48 player appearances. There were no errors, timeouts or censored games.
The authoritative source manifest stayed unchanged. Runtime: LuaJIT 2.1,
with four bounded workers. All jobs retain backend fingerprints, initial and
final state hashes, actual outcomes and compact per-player metrics.
An exact repetition reproduced all 48 initial/final state hashes, milestone
and choice aggregates, dispatch counts and outcomes. See the
[reproduction check](results/p1_pacing_reproduction.json); repeated runs do
not add independent experimental conditions.

These policies were selected before P1. This is a **fixed-policy treatment
comparison**, not an adapted-agent tournament, all-faction ranking or
victory-fairness test. No unseen human play quality is inferred.

## Opening milestones

First post-actor observation round; missing milestones remain missing.
The paired column is the median of individual matched-player differences,
so it need not equal the difference between aggregate medians.

| Milestone | Original median round | P1 median round | Median paired P1 minus original |
| --- | ---: | ---: | ---: |
| First completed technology | 12 | 11 | −1 |
| First trained Settler | 4 | 9 | +5 |
| Second owned city | 4.5 | 9.5 | +5 |
| First Scout present | 5 | 19 | +14 |
| First Farm | 20.5 | 22 | +2 |
| First Library | 26 | 30 | −3 |
| Second Age | 25 | 20 | −5 |
| Third Age | 47 | 38 | −10 |

All 48 players in each economy reached the listed milestones, except Farm:
48/48 original versus 47/48 P1. The paired Farm statistic uses 47 complete
pairs. More expensive settlers delay every player's second city in this
slice (+5 to +9 rounds), while later scientific progression accelerates.
Slower expansion therefore does not imply a slower technology ladder.

Scouting is a specific concern: the old policies continue to invest in
settlement and defense before exploration, and the Scout itself costs three
times its original price. The observed +14 rounds combines queue decisions
with the price change. It does not establish that a Scout-first human opening
has the same delay or that the approved price should automatically be reverted.

## Production continuity and unit burden

The first two windows are fixed 30-round periods reached by every player.
A city-round means one owned city at one post-actor sample. Legal building
counts include legal in-progress buildings; they exclude units, wonders and
repeatable projects. They measure availability, **not strategic value**.

| Measure | Original rounds 1–30 | P1 rounds 1–30 | Original rounds 31–60 | P1 rounds 31–60 |
| --- | ---: | ---: | ---: | ---: |
| Mean units per player-round | 3.94 | 2.68 | 5.00 | 4.99 |
| Idle city-round share | 37.1% | 3.4% | 36.2% | 0.0% |
| No legal building option | 53.5% | 9.6% | 40.2% | 2.7% |
| Exactly one legal building option | 34.0% | 45.0% | 38.5% | 14.4% |
| Mean legal building options | 0.65 | 1.51 | 0.97 | 2.68 |
| Repeatable project city-round share | 0% | 7.3% | 0% | 37.5% |

P1 supplies useful continuous production and more available infrastructure
choices. It does not yet solve the player's unit-count concern: the opening
piece count falls, but midgame counts are essentially equal. Final unit
medians are 5 original versus 6 P1; those are observed at different ending
times, so they are not a fixed-round burden comparison.

In P1 rounds 31–60, the controller spends 1,414 city-rounds on Ponder,
190 on Trade and 14 on Tend. It often chooses a repeatable while several
buildings remain legal. That exposes the next question: are these buildings
poor investments before the expected ending, or does the fixed controller
undervalue them? More menu entries alone cannot prove more meaningful choices.

## Endings and faction signal

| Fixed controller profile | Original endings, 12 games | P1 endings, 12 games |
| --- | --- | --- |
| Selected Expedition mirror | 7 Expedition, 5 Industrial | 3 Expedition, 9 Industrial |
| Industrial specialist mirror | 12 Industrial | 11 Industrial, 1 shared Industrial |

Even controllers committed to Expedition increasingly finish through
Industrial. P1 changes the race between overlapping economic prerequisites;
it has not supplied distinct interaction, counterplay or competitive route
balance. There are no military or diplomatic controllers in this pilot.

Across all games, median finish is 109.5 original versus 115 P1; median paired
change is +4 rounds. Differences are heterogeneous: average paired finish
deltas by map are 0, +1.33, −2.83 and −2.33 rounds. Original endings span
92–145, P1 110–126. This is a narrower range in four maps, not proof of a
universally satisfying game duration.

Scholar wins 16/16 appearances under original rules and 13/16 under P1;
Forge wins 8/32 versus 12/32. These count shared winners as successes for
each participant, not fractional victory credits. The sample supports
continued investigation of the capital-only Scholar bonus, but does not
establish approximate faction fairness. Six of the 24 matched conditions
change winner sets; the map, roster and policy dependence must remain visible.

## Detailed Civ VI equivalents

Civ VI's Gathering Storm Scout has base production 30 and movement 3; its
Settler has base production 80, movement 2 and normally consumes one population
when completed. P1's Scout/first-Settler ratio 15/40 matches that base 30/80
ratio, yet the pilot still delays exploration substantially. This illustrates
why copying a ratio is insufficient: starting production, queue priorities,
expansion returns, population costs, movement and information rewards also
shape the opening. The original CivCraft ratio was already fairly close
(5/12). The observed opening clocks matter more than numerical resemblance.
Sources: [Scout](https://www.civilopedia.net/en-US/gathering-storm/units/unit_scout/),
[Settler](https://www.civilopedia.net/en-US/gathering-storm/units/unit_settler/).

Civ VI's Farm is a Builder-created tile improvement with +1 food and 0.5
housing, later improved by adjacency unlocks such as Feudalism. CivCraft's
Farm is a city building. Making it available immediately adds an early
investment alternative, but this controller still finishes it around round
22; availability and utilization are separate outcomes. P1 does not reproduce
Builder charges, tile placement or housing. Those differences belong in the
specialization and opportunity-cost review, rather than treating a Farm as
a direct one-for-one building equivalent.
Source: [Farm](https://www.civilopedia.net/en-US/gathering-storm/improvements/improvement_farm/).

Civ VI's district commitments, population-limited specialization, technology
and civic unlocks, and project alternatives remain the relevant design
patterns from [the detailed comparison](CIV6_COMPARISON.md). P1 adds a
production outlet; it has not implemented those specialization constraints.
The larger P2–P4 designs still require review.

## Next experiments and review decisions

1. **Adapt opening choices before another price recommendation.** Compare
   Settler-first, Scout-first and infrastructure-first continuations from
   identical initial states under each economy, then tune controller priorities
   on separate training maps. Evaluate on untouched map blocks. Measure first
   contact, discovered viable city sites and economic cost, not just Scout date.
2. **Audit building payback against actual ending clocks.** For states in which
   Ponder outranks available buildings, compare authoritative checkpoint
   continuations choosing the building versus the repeatable. Separate a
   bad investment from controller misvaluation. Include human review of the
   best two credible alternatives and the proposed P2 city specializations.
3. **Retest the victory overlap after adaptation.** Evaluate industrial and
   expedition specialists against independently adapted opponents, with
   progress and counterplay milestones. Use shared-win credit consistently.
   Do not aim for equal raw ending-label frequency when pursuit populations differ.
4. **Retain burden and recovery checks.** Count role-specific units at fixed
   rounds, upkeep failures and useful unit actions; do not use lower opening
   counts as evidence of a solved midgame problem. Repeat moderate opening
   mistake branches under P1 with adapted continuations.
5. **Review actual early/mid/late play.** Timings and legal-option counts cannot
   establish that the choices feel satisfying. Current evidence justifies
   testing the approved prototype, not declaring the rebalance finished.

## Reproduction

```sh
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/p1_pacing_study.py \
  --backend luajit21 --workers 4 --output /tmp/p1-pacing-pilot.json
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/analyze_p1_pacing.py \
  --input /tmp/p1-pacing-pilot.json --output /tmp/p1-pacing-summary.json
```

Use the [LuaJIT setup and conformance instructions](LUAJIT_BACKEND.md) first.
The runner saves each completed worker batch atomically and resumes only
when source, harness, adapter, configuration and planned count match. Its
metrics are read-only; Lua 5.3 and LuaJIT regressions verify unchanged canonical
trajectories after measurement. Large per-turn records are reduced before
publication; milestone, choice-count and period totals remain per player.
