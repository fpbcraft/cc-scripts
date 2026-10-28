# Coordinated siege policy study

The [operational follow-up](OPERATIONAL_SIEGE_REPORT.md) now isolates known-route
stagnation and confirms automatic upkeep disbanding of two healthy catapults.
It improves travel from a matched checkpoint but still produces no capture.

The current rules permit a fortified capture with a properly used army, but
that does not establish a competitive conquest route. This study tests an
offline policy intervention before recommending combat or wall changes.
The live AI is unchanged.

## Intervention and controlled checks

The control retains the earlier research-only quality-production, frontier,
campaign-memory and timely-engineering hooks. The candidate adds
[`coordinated_siege_policy.lua`](coordinated_siege_policy.lua):

- Recruit toward three siege units, counting both existing pieces and queued
  siege projects, once at least two melee units of Iron Swordsman strength
  exist. Candidates must pass actual `Systems.canRecruit`, resource,
  technology and treasury checks. Original project-completion behavior stays
  in the source AI.
- Give an existing legal wall shot a 120-point ranking bonus when at least
  two friendly siege pieces are within three hexes of the target, or when
  the forecast shot immediately breaches the wall.
- Evaluate visible local siege opportunities even while the empire's main
  campaign is defending its capital. This does not redirect the other
  defensive units or reveal an unseen city.

These are fixed hypotheses, not learned optimal parameters. Recruitment
composition and shot ranking are bundled here; their individual causal
effects are not isolated by the full-game comparison.

Eight controlled scenario arms start from matched states, with supplied
armies and research/stores. The candidate's three-catapult group reduces
the fortified target's wall from 100 to 4 in round 1 and to zero in round 2;
ownership transfers in round 3. The control keeps the wall at 100 through
the eight-round horizon. Neither arm captures with the one-catapult group.
Capital-defense and settler-protection final hashes are identical between
arms. Scenario horizons are recorded as `scenario_horizon`, not actual
finished games or fabricated losses.

See [scenario results](results/coordinated_siege_fixtures.json). Supplied
armies do not count as an economic achievement: this group's base unit
production is 3×45 + 2×40 + 13 = **228 industry**, before research, materials,
maintenance and deployment. The defender's 20-industry wall is only part of
its defense; a comparison of those two costs is not a victory-balance ratio.

## Implementation corrections and provenance

The initial campaign-only tactic never activated while the capital-defense
plan was selected. Those negative checks are retained in
`results/coordinated_siege_fixtures_campaign_only.json`.

A composition test then caught a threshold error: strength 8 excluded the
actual strength-7 Iron Swordsman. The corrected policy compares against the
content definition and requires a melee-range unit. The two-seed/eight-game
preflight with that earlier gate is retained in
[preflight results](results/coordinated_siege_holdout_strength8.json).
It is not evidence that the corrected composition policy works. Its raw
games were preserved when the first reducer failed on the list-valued
`cities` metric; reduction was repaired without rerunning those games.
Artifacts retain the original gameplay/driver/policy hashes and a separate
analysis-driver hash.

Both the threshold correction and the recruitment regression test preceded
inspection of the preflight outcome summaries. The corrected evaluation
reuses the registered two map seeds, so it is an evaluation after an
implementation correction, not a fresh independent confirmation set.

Actual ownership transfers are captured around `Actions.apply`, separately
from founded cities and queued-unit counts. An accepted recruitment queue
does not prove a unit completed. Rejected orders remain rejected; errors and
timeouts remain separate outcomes.

## Native fidelity

The standalone Lua policy is **4,979 bytes**. A fresh CraftOS-PC run matches
Lupa on 32 canonical state checkpoints, 56 detached player-observation
snapshots and four final states, across one- and three-siege scenarios with
and without the policy. Native exit code is zero and source fingerprints
remain unchanged. See [native results](results/coordinated_siege_native_parity.json).

That native test loads the standalone Lua policy with ordinary source AI;
it does not install the Python-defined earlier hook bundle. It proves this
scenario behavior is available in native Lua, not full-game strength
retention for the entire experimental controller or a deployed AI release.

## Detailed Civ VI equivalent

Gathering Storm's Catapult costs 120 production, requires Engineering,
has 35 bombard strength, range 2 and movement 2, and normally cannot move
and attack in the same turn before its Expert Crew promotion. Its 2-gold
maintenance and positioning restriction make committing and protecting the
piece part of the investment. CivCraft's Engineering Siege Contraption
costs 45 industry, has strength 5, defense 2, movement/range 2 and deals full
wall damage. Copying the numbers between combat formulas would be invalid.
[Civ VI Catapult](https://www.civilopedia.net/en-US/gathering-storm/units/unit_catapult/)

Civ VI also offers a different early wall answer: the 65-production,
1-gold-maintenance Battering Ram, unlocked by Masonry, enables adjacent
melee/anti-cavalry units to deal full damage to Ancient Walls. It does not
work against Medieval/Renaissance Walls or Urban Defenses. Ancient Walls
themselves cost 80 production and add 100 outer defense plus ranged strikes.
This supplies a role-specific alternative to accumulating catapults.
[Battering Ram](https://www.civilopedia.net/en-US/gathering-storm/units/unit_battering_ram/),
[Ancient Walls](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_walls/)

For CivCraft, the immediate research question is whether the existing
army can stage and execute together under an ordinary economy. If competent
controllers still need an excessive piece count, an early breaching role
on an existing engineer is an option to compare with more siege recruits;
it would need a clear wall-tier limit and a real investment cost. This is a
design alternative, not an implemented mechanic or a reason to copy Civ VI's
ram as another mandatory unit. The proposed army-refit and city-production
packages remain separate decisions.

## Full-game result

All **eight corrected games** finished without error, timeout or censoring,
in 141.21 seconds with four workers. Every game ended with the industrial
opponent winning; neither control nor candidate captured a registered
opponent's city. All four initial-state pairs match. The repeated controls
also match the preflight's exact final-state hashes despite using four
workers instead of two.

| Map seed / conquest seat | First siege queue, control → candidate | Completed siege at finish | Completed swordsmen at finish | Finish |
|---|---|---|---|---|
| 387493 / 0 | none → none | 0 → 0 | 0 → 0 | Industrial rival, round 127 |
| 387493 / 1 | 112 → 112 | 1 → 3 | 11 → 9 | Industrial rival, round 160 |
| 923671 / 0 | none → none | 0 → 0 | 0 → 0 | Industrial rival, round 136 |
| 923671 / 1 | 94 → 75 | 1 → 2 | 8 → 6 | Industrial rival, round 129 |

The two inactive cells retain identical final hashes. In the active cells,
the policy changes composition and, once, advances the first siege queue by
19 rounds. Yet there is no capture or terminal-outcome improvement. Those
conquest seats finish with 15–19 total units and only 1–10 gold; the number
of pieces and military spending do not establish effective pressure.

This is evidence that recruitment timing/composition and local wall-shot
ranking are insufficient interventions for these controllers. It is not
evidence that the game's conquest route is mathematically impossible, nor
that Industrial should be nerfed. The next operational test should budget
and stage a group at a safe rally point, measure arrival spread and actual
legal fire opportunities, and cap replacement recruitment by useful combat
roles and an explicit reserve. That can distinguish a travel/coordination
failure from an army whose upkeep delays the research and development it
needs. Do not enlarge army caps again as the default remedy.

The four paired cells share **two independent map seeds**. All players are
Forge, on compact Pangaea with hostiles off, so these are controller
diagnostics, not a conditional route-fairness estimate. Composition and
tactics remain bundled. Detailed accounting is in
[full-game results](results/coordinated_siege_holdout.json) and
[paired analysis](results/coordinated_siege_pair_analysis.json).

## Reproduction

```sh
/tmp/civcraft-lua-env/bin/python -m unittest \
  games/civcraft/research/lab/test_coordinated_siege_policy.py
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/coordinated_siege_study.py \
  --phase fixtures --workers 2
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/coordinated_siege_study.py \
  --phase holdout --workers 4
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/check_siege_policy_native.py
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/analyze_coordinated_siege.py
```

Large raw artifacts live under ignored `runs/`. The `--reduce PATH` mode
rebuilds a compact summary without launching any games. The two composition
tests, six proposal tests and twelve base lab tests also run in the lab CI
workflow. Physical Minecraft monitor/rednet validation is not claimed.
