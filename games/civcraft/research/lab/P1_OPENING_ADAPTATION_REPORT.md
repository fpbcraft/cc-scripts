# P1 opening adaptation and exploration diagnostic

A restricted opening search did not recover the expedition controller's
performance under P1. Farm-first is a viable alternative in the tested
conditions, but not a demonstrated stronger policy. Scout-first losing
cannot be read as proof that exploration is a bad investment: a passive
replay confirms that one early Scout never leaves its spawn hex.

No live AI, production price or gameplay rule changed in this study.

## Executed design

[Experiment](p1_opening_adaptation.py),
[summary script](summarize_opening_adaptation.py),
[training results](results/p1_opening_train.json),
[held-out results](results/p1_opening_evaluate.json),
[compact summary](results/p1_opening_summary.json).

**80 training games and 48 held-out games**, all finished without censoring,
timeout or error. Four training map blocks and four disjoint evaluation map
blocks; compact maps, standard speed, hostiles off. Each block has both target
seats against two opponents: Industrial specialist and archived adapted
Expedition policy. Target and opponent are Forge, with fixed Forge
personalities. The target uses the previously selected Expedition weights;
only its first queue order varies.

| Split | Pangaea | Continents | Archipelago | Highlands |
| --- | ---: | ---: | ---: | ---: |
| Training seed | 271003 | 382021 | 493031 | 604043 |
| Evaluation seed | 715049 | 826061 | 937069 | 148079 |

Each condition restores one identical canonical round-1 checkpoint. The
intervention issues one normal `queue` action through `Actions.apply`:
Scout-first, Farm-first, or unchanged source opening. No unit, technology,
production, resource, movement or visibility is granted. Farm-first is tested
only under P1; the baseline Farm remains technology-locked. Later decisions
use the same controller and can respond normally.

The selection rule was written before training: per economy, maximize mean
fractional win credit; break ties by explored tiles at round 30, then earlier
second city, then a fixed default/Scout/Farm ordering. Four conditions per
map make the game-weighted and map-block-weighted means equal. Shared wins
receive `1 / number of winners` credit. Training and evaluation source/input
fingerprints remained unchanged.

This is adaptation over **two or three initial orders**, not a sophisticated
new agent or full nested policy optimization. The two opponent policies are
known during training; only maps are held out. Do not call them independently
held-out opponents or use these results as all-context faction balance.

## Selection and evaluation

| Training arm | Games | Mean target win credit | Mean explored tiles, round 30 | Mean second-city round |
| --- | ---: | ---: | ---: | ---: |
| Original, source opening | 16 | 0.750 | 66.50 | 4.50 |
| Original, Scout-first | 16 | 0.656 | 65.88 | 5.63 |
| P1, source opening | 16 | 0.375 | 73.38 | 9.50 |
| P1, Scout-first | 16 | 0.188 | 61.63 | 12.63 |
| P1, Farm-first | 16 | 0.375 | 79.75 | 12.50 |

Original rules retain the source opening. P1 selects Farm-first on the
exploration tiebreaker; **its training win result is a tie**, not an improvement.
P1's first Scout appears at median round 4 under Scout-first, compared with
19 under the source opening. Therefore the earlier 48-game pilot's late Scout
was partly a queue-order effect. In these trials, making a Scout early does
not translate into more total exploration or better outcomes.

| Held-out arm | Games | Total fractional win credit | Mean credit | Median second-city round |
| --- | ---: | ---: | ---: | ---: |
| Original, source opening | 16 | 10 | 0.625 | 4 |
| P1, source opening | 16 | 5 | 0.313 | 9 |
| P1, selected Farm-first | 16 | 5 | 0.313 | 12 |

P1 Farm-first changes **none of the 16 held-out winner sets**. It delays the
second city by three rounds in most cells (map-block averages +3, +3, +3,
+2.5). The training exploration gain does not persist: mean explored tiles
at round 30 are 68.125 for P1 source versus 67.5 Farm-first. Observer candidate
site counts are 13.75 versus 13.625. Those sites are scored from known terrain;
hidden occupancy and route reachability can still make a candidate unavailable.
These diagnostic counts never enter the acting policy.

The original/P1 win-credit difference is conditional on these controllers,
Forge and two known opponents. It does not prove that P1 reduces human skill
expression or that an optimized P1 controller cannot recover. It does show
that one initial order is insufficient adaptation. Farm-first's unchanged
outcomes are useful moderate-investment evidence, not a non-inferiority proof
or a universal recoverability estimate from four evaluation maps.

## Confirmed Scout behavior

No target continuation among the 128 games records contact with another
registered civilization. This seriously limits military/diplomatic balance
inferences from this controller population.

The [passive Scout diagnostic](trace_opening_scout.py) chooses, after seeing
training outcomes, the first P1 condition where Scout-first loses win credit:
Continents seed 382021, target seat 0, Industrial opponent. This is a
known-case investigation, not another held-out test.

The Scout completes by round 4. It remains at `(4,3)` for **118 consecutive
post-actor observations**, through round 121. Its role is `scout`, and all
118 first tactical decisions rank standby first. Early examples give standby
score 0 and legal move scores −1. Later examples give standby 0 versus moves
−9. Its exploration campaign target remains near home `(4,4)`, initially in
muster and later approach. See [diagnostic records](results/p1_scout_diagnostic.json).

The probe wraps the existing tactical ranker, returns its original choices
unchanged and records a small detached summary. Its final authoritative hash
is **identical to the original training continuation**. This is direct
behavioral evidence, not a conclusion inferred from a queue or from source
inspection alone.

Source interpretation: `ai_tactics.lua` gives scouts local frontier value,
but still scores geometric progress against the campaign/muster target.
A scout inside fully known nearby terrain may need several moves without
immediate new visibility before reaching a frontier. Standby can then dominate
all local steps. The replay confirms this trap in one condition; it does not
establish a complete explanation for every no-contact game.

**Design implication:** do not lower Scout prices merely to compensate for
an idle research controller. The next agent test should reuse the existing
bounded discovered-frontier routing prototype, with a separate Scout objective
and progress memory, while retaining risk, legal movement and observer-only
knowledge. Compare route competence separately from first-build order, then
repeat price evaluation with independently adapted opponents. This remains
offline research work, not permission to replace shipping AI.

## Civ VI equivalents and what to adapt

Civ VI's Scout has base production 30 and movement 3. Its value depends on
using that mobility to gain information and reach opportunities. This study
cannot evaluate a comparable investment when an early CivCraft Scout remains
stationary. Assess useful Scout actions, first contact and discovered sites
before interpreting piece count or build date as exploration value.
Source: [Civ VI Scout](https://www.civilopedia.net/en-US/gathering-storm/units/unit_scout/).

Civ VI explicitly connects exploration to progression: Writing costs base
50 science and has a boost for meeting another civilization. CivCraft's
`Contacts.meet` records contact and emits a notice; it does not grant a Writing
boost. The useful design principle is **visible consequences for discovery**,
not copying a technology discount into every contact. Minecraft-themed
alternatives for review include Cartographer discovery commissions, useful
village trade offers and information about distinct resource regions. Each
would need bounded rewards, map guarantees and an opportunity-cost test.
Source: [Civ VI Writing](https://www.civilopedia.net/en-US/gathering-storm/technologies/tech_writing/).

Civ VI's Builder costs base 50 production and normally has three charges for
improvements, harvesting and feature removal. Its early economic decision
includes where and when to spend those charges. P1 Farm-first commits 15
industry to a permanent city food building, with no placement or charge
allocation. The observed Farm-first alternative is encouraging for opening
investment variety, but it does not implement Civ VI's spatial specialization
or multiple charge-use choices. Those remain reasons to review P2's city-role
and site constraints rather than add interchangeable city-wide yield buildings.
Source: [Civ VI Builder](https://www.civilopedia.net/en-US/gathering-storm/units/unit_builder/).

## Native checks and reproduction

[Native driver](native_opening_match.lua),
[validator](check_opening_native.py),
[native results](results/p1_opening_native.json).
The first held-out selected continuation in each economy reproduces its
LuaJIT initial state, final full state and dispatch counts in real CraftOS:
original/source finishes round 131; P1/Farm-first finishes round 119.
This validates those research interventions, not a physical Minecraft session
or a deployed policy change.

```sh
/tmp/civcraft-lua-env/bin/python -m unittest tests/test_civcraft_opening_adaptation.py
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/p1_opening_adaptation.py \
  --stage train --output /tmp/p1-opening-train.json
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/p1_opening_adaptation.py \
  --stage evaluate --training /tmp/p1-opening-train.json --output /tmp/p1-opening-evaluate.json
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/summarize_opening_adaptation.py \
  --training /tmp/p1-opening-train.json --evaluation /tmp/p1-opening-evaluate.json \
  --output /tmp/p1-opening-summary.json
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/trace_opening_scout.py \
  --training /tmp/p1-opening-train.json --output /tmp/p1-scout-diagnostic.json
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/check_opening_native.py \
  --input /tmp/p1-opening-evaluate.json --output /tmp/p1-opening-native.json
```

Use fresh output paths or the exact recorded source/harness/input fingerprints
when resuming. Training selection must finish before evaluation configurations
are generated. The runner checkpoints completed condition batches; errors,
unavailable actions and cutoffs retain distinct statuses and never receive
fabricated victory credit. Native probes require CraftOS-PC.
