# Council victory reachability across player counts

The current route requires voluntary support from another civilization at
every supported player count. A coalition makes it reachable in multiplayer;
it does not create an independent path against uniformly refusing opponents.

The audit runs the actual `Actions.apply`, Council opening/vote/tally and
`Victory.check` implementations. It enumerates every ballot vector over
abstention and living members, for every 2/3-delegate profile with 2–4 players.
Commerce, Council Halls and eligible village loyalty are supplied fixture
preconditions, not achievements credited to an agent.

| Players | Election cases | Candidate 0 receives no outside vote | Candidate 0 wins in those cases | Everyone self-votes or abstains | Wins in those cases |
|---|---:|---:|---:|---:|---:|
| 2 | 36 | 24 | 0 | 16 | 0 |
| 3 | 512 | 288 | 0 | 64 | 0 |
| 4 | 10,000 | 5,120 | 0 | 256 | 0 |

All 28 unanimous-for-candidate-0 positive controls produce an actual Diplomatic
finish. The route is reachable with support, not globally impossible. Native
CraftOS and Lupa agree on all aggregates and the ordered outcome digest for
10,548 cases; exit code is zero and source fingerprints remain unchanged.
These are bounded logical cases, **not sampled win probabilities**.

The source grants two delegates and at most one village bonus. More villages
do not grant unlimited independent votes. Tally requires a strict majority,
at least two-thirds of all allocated delegates, an outside supporter, an
eligible Hall owner and enabled victory. Abstaining therefore does not shrink
the denominator. Lowering Hall costs or improving an AI's economic play cannot
remove the outside-support requirement.

The redesign should separate Council leadership/powers from the competitive
finish condition. A reviewed points/objective route needs enough progress
available without an opponent consenting to lose, plus meaningful, costly
counterplay. An election-only route can instead remain an explicitly negotiated
coalition condition. These are different design promises; changing the name or
denominator in a simulation cannot reconcile them.

Civ VI Gathering Storm accumulates Diplomatic Victory points through Congress,
competitions and other milestones; the Statue of Liberty grants four points.
This offers multiple channels rather than requiring a final rival endorsement.
Congress can also remove points, so the reference is contested progress, not
guaranteed victory or evidence of equal route success.
[Diplomatic Victory](https://www.civilopedia.net/en-US/gathering-storm/concepts/diplomatic_victory/),
[Statue of Liberty](https://www.civilopedia.net/en-US/gathering-storm/wonders/building_statue_liberty/)

Reproduce with:

```sh
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/check_council_reachability.py
```

[Machine-readable result](results/council_reachability.json). This does not
enumerate negotiation histories, eliminated members, every faction combination
or natural map frequencies. No election or victory rule was changed.
