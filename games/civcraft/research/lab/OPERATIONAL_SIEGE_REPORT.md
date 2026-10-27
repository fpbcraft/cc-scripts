# Operational routing and upkeep diagnosis

This follow-up separates three failures that a terminal win rate conceals:
recruiting a force, getting it to a target and keeping it solvent. It uses
the previously evaluated seed 923671, conquest seat 1, compact Pangaea,
Forge mirror, hostiles off. This is a known-case causal diagnostic, not a
new holdout or a general conquest-strength estimate.

## Observer instrumentation reproduces the original game

[`operational_probe.lua`](operational_probe.lua) wraps the completed research
ranker, returns the original candidate table and records the first ranked
decision per unit/round. It never supplies diagnostic data to a policy.
For siege units at ten-round checkpoints, it also computes bounded routes
through discovered terrain, both respecting and ignoring friendly occupancy.
Costs to geometric firing range do not establish line of sight or attack
legality; those remain the authoritative dispatcher's responsibility.

The instrumented full game finishes at round 129 with the exact final hash
of the earlier evaluation. Source fingerprints remain unchanged. Among 56
recorded siege decisions, none contains a positive wall-damage forecast.
For example, at round 110, catapult 38 at (20,6) chooses standby despite a
known route costing 28 to geometric range of the remembered capital. At
round 120, its known route to range of the visible city (8,8) costs 16,
while ignoring friendly occupancy reduces that cost to 14. Friendly
congestion increases route cost in this case; it does not eliminate the
route. The ranker still chooses standby.

These observations narrow the bottleneck to operational progress/ranking;
they do not prove every candidate on the route is safe or immediately legal.
See [full-game diagnostic](results/operational_siege_diagnostic.json).

## Matched round-80 route intervention

[`route_detour_policy.lua`](route_detour_policy.lua) is an offline ablation,
not a game rule or a shipping AI change. For healthy main-army/siege roles
in an approaching city campaign, it uses the existing discovered-terrain
route finder, with a 64-cost/1024-node bound. It re-ranks only original
move candidates on that route, excluding forecast attacks and moves whose
estimated damage is at least half current HP. It grants no movement,
visibility, resources or new action type. Garrisons, escorts, defensive
campaigns and wounded retreats retain their source behavior.

A prefix run saves the complete canonical research state after round 80's
actor pump. Both branches restore that exact state in fresh runtimes. The
restored control reproduces the original full-game final hash, validating
this checkpoint/continuation boundary as well as the passive probe.

| Result | Control | Route-following branch |
|---|---:|---:|
| Start checkpoint | Same round-80 state | Same round-80 state |
| Catapult 38 at round 120 | (20,6) | (11,9) |
| Distance to the same visible city (8,8) | 13 hexes | 3 hexes |
| Opponent-city captures after checkpoint | 0 | 0 |
| Finish | Industrial rival, round 129 | Industrial rival, round 130 |

The intervention causes substantial travel progress but does not complete a
siege. Later catapults approach different nearby cities, and the existing
campaign still targets the original capital. A proximity improvement is not
a victory improvement. The safety filter, target consistency, group arrival
and exposure during the final approach remain hypotheses to isolate; this
study does not justify relaxing all tactical risk penalties.

See [matched branches](results/route_detour_diagnostic.json). Both finish
without errors/timeouts, share the checkpoint hash, and retain unchanged
source fingerprints. The intervention's parameters were selected after
examining the failed case, so this is not an unbiased performance estimate.

## Two siege units disappear through upkeep, not combat

The earlier trace also loses catapults 36 and 37 while they still have full
health. A short replay from the same checkpoint records existing disband
events without changing their behavior. At round 82:

| Unit | Health | Gold at disband notice | Treasury net before that unit is removed |
|---|---:|---:|---:|
| Catapult 37 | 100 | -2 | -4 |
| Catapult 36 | 100 | 0 | -2 |

There are **zero manual disband requests**. The instrumented and uninstrumented
continuations have identical full-state hashes at round 84.
[Upkeep replay](results/siege_upkeep_diagnostic.json)

The source explains the round-economy order: `Systems.production` completes production, pays
the treasury net, then, if gold is negative, scans `state.units` backwards.
It removes the current player's units until gold is nonnegative, refunding
each removed unit's upkeep against the shortage. With appended recruits,
recent reinforcements are first in line. This is confirmed current behavior,
not an assertion that its original implementation violated an intended rule.

That creates a policy/rule interaction: an army can preserve obsolete guards
while losing freshly built siege, then spend more production replacing it.
Counting unit queues or nominal combat power misses the lost investment.
The next economic policy test should forecast upkeep at completion and over
deployment, budget reserves and stop replacement recruitment before insolvency.
It should compare legal economic-project switches and voluntary disbands
from identical checkpoints, preserving action and progress rules.

For gameplay review, make insolvency consequences visible and compare forced
removal priorities or a bounded player-choice window. An oldest-first rule
can invite sacrificial-unit exploits; an unlimited grace period can enable
free armies. Do not select a global rule from this one case. No upkeep,
disband, unit cost or combat rule was changed by this study.

## Civ VI comparison and redesign implication

### A legal recovery decision preserves investment

The [guard-retirement study](results/retire_guard_study.json) extends the same
round-80 checkpoint to a small two-factor comparison. The existing control
and route-only continuations are reused with matching source/policy hashes;
only two new continuations are launched. At the first eligible actor turn in
round 81, the intervention submits four ordinary `disband` requests for
lowest-XP nongarrison, unescorted Stone Guards. It retains at least one guard
and does not change the opponent, rules or subsequent controller.

All eight requests across the two new arms are accepted. Gold remains zero;
treasury net improves from **−4 to 0**. Four Stone Guards represent 52 base
industry of sunk investment and four upkeep per round. The decision preserves
two Siege Contraptions representing 90 base industry and the same four upkeep.
There is no gold refund or free replacement unit.

| Branch | Last post-actor sighting of original catapults 36/37 | Opponent-city captures | Finish |
|---|---:|---:|---|
| Existing control | 81 / 81 | 0 | Industrial rival, round 129 |
| Route only | 81 / 81 | 0 | Industrial rival, round 130 |
| Retire four guards | 129 / 129 | 0 | Industrial rival, round 130 |
| Retire guards + route | 135 / 135 | 0 | Industrial rival, round 136 |

The unit observations stop at the last actor phase before victory, so the
table reports observed preservation, not an inferred death date. Retirement
alone still loses another full-health swordsman to upkeep at round 99. The
combined arm has later automatic swordsman removals too. One decision repairs
the immediate shortage; continued replacement recruitment remains unsustainable.
The longer terminal time in the combined arm is not evidence of stronger play
or better pacing. All four branches lose and none produces a positive wall-shot
forecast in the recorded first siege decisions.

This is a verified local recovery of investment under current rules, not a
recovery of winning chances or evidence that players should always disband
four guards. The choice changes army composition and subsequent decisions as
well as upkeep. There is only one known map/seat/checkpoint; no population
win-rate interval or optimal-continuation claim is appropriate.

### Detailed budget-choice equivalent

Gathering Storm's **Conscription** military policy reduces each unit's
maintenance by one gold and unlocks at **State Workforce**. That civic costs
70 culture before modifiers and is boosted by constructing a specialty
district. Thus a city investment can accelerate a civic that opens a military
budget option, linking several early decisions. The facts do not establish
that every Civ VI army or opening is balanced.
[Conscription](https://www.civilopedia.net/en-US/gathering-storm/governments/policy_conscription/),
[State Workforce](https://www.civilopedia.net/en-US/gathering-storm/civics/civic_state_workforce/)

For CivCraft, a flat −1 upkeep copy would make one-upkeep Stone Guards free
and could worsen excess piece counts. The proposed Trade Contract project
and complementary Freight role instead offer a useful place for city
production to support a chosen army. Their rates and opportunity costs still
need reviewed prototypes and adapted-policy evaluation. This experiment tests
neither proposed mechanic. A player-facing forecast should expose current
income, committed upkeep and the forced-removal consequence, while leaving
recruitment, retirement and development as real choices.

Civ VI's Catapult-to-Trebuchet upgrade path gives a direct example of retaining
a siege role's investment across research tiers. Its Catapult also requires
positioning before firing. The relevant lesson is to connect investment,
arrival and sustained use; merely adding another siege type cannot ensure
that a force reaches its target or survives its budget.
[Gathering Storm Catapult](https://www.civilopedia.net/en-US/gathering-storm/units/unit_catapult/)

The proposed CivCraft equipment refits and useful civilian repeatables address
different parts of this chain: retain useful veterans, and give production
an alternative to more bodies. Their balance still needs reviewed prototypes.
Refitting alone will not fix an army that cannot pay upkeep. City roles
should make the economy capable of supporting a chosen campaign without
making every city an identical permanent unit factory.

## Reproduction

```sh
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/operational_siege_diagnostic.py
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/route_detour_diagnostic.py
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/check_siege_upkeep.py
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/retire_guard_study.py
```

The first command records a read-only full-game diagnosis. The second creates
a fresh round-80 checkpoint and two bounded continuations. The third consumes
that raw checkpoint and compares two four-round continuations. Raw traces and
checkpoint strings remain under ignored `runs/`; compact results record hashes
and source fingerprints. Native validation of the standalone coordinated
wall-shot policy is documented separately; native execution of the new
route-following policy has not yet been claimed.
The retirement command consumes the same saved checkpoint, reuses the two
verified reference continuations and adds two bounded, fully legal recovery
branches. Its callback runs only when the target actor is eligible.
