# Recovery after one alternative opening investment

A separate [military budget recovery experiment](OPERATIONAL_SIEGE_REPORT.md)
now tests a legal one-time retirement decision from a shared midgame checkpoint.
It preserves the original siege investment but changes no winner; it is a
known-case recovery diagnostic, distinct from this opening study's held-out maps.

Status: executed under unchanged game rules. This study extends the earlier
four research-diversion pairs with a different decision type and new maps.
It does not classify every departure from the controller as a player mistake.

## Design and controls

Run `measure_opening_alternative.py` with the documented Lupa environment.
The manifest was written before execution: four new map seeds
375491/884323/318791/546311, both target seats, and two opponent policies
(Industrial and the adapted expedition archive). All factions are Forge,
compact Pangaea, hostiles off. The target uses the earlier selected expedition
policy. There are sixteen paired configurations and thirty-two continuations,
but only **four independent map blocks**.

Each pair starts from an identical round-one canonical checkpoint. One arm
continues normally. The other submits exactly one legal queue order for a
Stone Guard (`warrior`) in the initial capital, then uses the identical
continuation controller. No unit/resource is injected and no subsequent
choice is forced. Actual costs, production, recruitment and scheduling remain
the shared Lua implementation. The source, driver and input-policy hashes are
retained; no source/input changed during execution. All sixteen pairs finished.

[Manifest](opening_alternative_manifest.json), [compact results](results/opening_alternative.json),
raw `/tmp/civcraft-opening-alternative.raw.json`.

## Results

- The guard completed by round four in all sixteen intervention arms, verifying
  that the alternative choice was actually executed rather than immediately
  cancelled by the AI.
- The target's observed second city appeared between one round earlier and
  five rounds later than its baseline; median delay was **three rounds**, mean
  2.25. Downstream pathing/production choices can change, so even the sign of
  expansion timing is not forced by the word diversion.
- Target win credit was **12/16 in both arms**: 8/8 versus Industrial and 4/8
  versus the adapted expedition controller. Every paired winner was unchanged.
- Among the twelve target wins retained in both arms, finishing-time changes
  ranged from eight rounds earlier to three rounds later. These are local
  trajectories, not an estimate that building a guard improves the game.
- The mean map-block win-credit contrast was zero. A deliberately conservative
  95% Hoeffding interval under independent bounded map sampling spans the
  entire [-1,1] contrast range with only four blocks. **Zero observed changes
  is not evidence of equivalence or a universal recovery probability.**

The earlier round-ten Sailing experiment changed one winner and delayed two
wins by 10/11 rounds. This opening-production experiment changed timing but no
winner in its tested cells. Recoverability depends on decision type, geography,
opponent and continuation quality; one statistic cannot describe it.

## Correction to opening-clock interpretation

The earlier comparison of a 24-science technology at one base science per
round is a **frozen-income calibration anchor**, not a measured optimal-AI
24-round opening. In seed 375491, target seat zero had one science/six industry
after its first actor phase, and two cities/two science/eleven industry by
round three in the ordinary continuation. Guard-first kept one city and one
science through the first five actor samples and founded the second by round
seven. Thus cheap expansion itself accelerates research, before a Library or
Scholar bonus is considered.

Opening unit/settler costs and the science floor must therefore be calibrated
together. Raising settler costs alone removes some early science growth;
raising science alone speeds the already-fast expansion strategy. This is the
same kind of coupled opportunity cost illustrated by Civ VI's population-
consuming Settler and its competing growth, production and research clocks;
it is not a justification for copying Civ VI's numeric prices into a
180-round game. See [the sourced comparison](CIV6_COMPARISON.md) and
[the concrete opening candidate](REVIEW_BRIEF.md).

## Limits and next tests

The continuation policy is fixed, not optimal or adapted after the decision.
There are no hostile mobs and no early human aggression, so the guard's
insurance value is underrepresented. First-settler samples taken after actor
phases can miss immediate founding; second-city time is the more reliable
recorded milestone. Other factions, research diversions, bad defensive moves,
city loss and trained recovery policies remain separate tests. Do not use
these results to add hidden catch-up bonuses or to claim the proposed rebalance
has been simulated: no gameplay candidate was implemented.
