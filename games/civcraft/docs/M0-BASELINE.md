# M0 baseline verification and hostile capture repair

Implementation is authorized under the accepted [roadmap](ROADMAP-balance.md)
and [38 ADRs](adr/README.md). Balance tournaments and parameter searches are
paused at the user's request. The unfinished building-payback research remains
local and is not part of this milestone.

## Current campaign baseline

Original and P1 campaigns retain their existing content versions and opening
rules. P1 center science, original-capital Scholar bonus, Scout/Guard/Settler
prices, early Farm/Agriculture help and recurring civilian projects are covered
by the focused contract checks. Separate project remainders, research-paused
Ponder, retained construction and rejected-order forecast immutability pass.
The native P1 test includes actual file save/load and resumed project state.

The native host/AI session reaches round two through real rendered/input flows,
selects Agriculture through the research interface and opens the Wheat Farm
Codex. Campaign options, reports, Council, queued routes, save/reload and AI
memory survive. This is a scripted native text-terminal session; it is not
human pacing feedback or a physical Minecraft monitor/network test.

The [machine-readable validation record](validation/m0-source-validation.json)
contains the actual source fingerprints, test names, commands and native
profiles. Historical study results retain their original source hashes.

## Fixed failure

A zombie can legally capture a player's Settler through
`Hostiles.round → Combat.attack → Stacks.capture`. The captive has wilderness
ownership but no spawn association. The next hostile round previously indexed
a spawn-count table with that missing key, crashing the campaign. It would also
have treated the civilian as a combat actor.

`Hostiles.round` now counts and schedules only content-defined hostile mobs.
Captured civilians remain captives, retain zero movement and do not consume mob
spawn slots. Real legacy mobs without a spawn association still count toward
the global cap and can act, while skipping nonexistent per-spawner accounting.
Capture reset semantics remain intact. No new campaign fields or migration are
needed, and the correctness repair applies to existing campaigns as well.

## Executed checks

- All **58 CivCraft Lua regression scripts pass**.
- All **34 Python contract/interface tests pass**. These are correctness checks,
  not a new balance tournament or optimization run.
- Native CraftOS runs the new hostile-capture regression and the P1 contract
  regression successfully. Use `python3 tests/run_civcraft_native_rules.py`.
- **21 native/offline state, observer, capture and actual save/reload checks pass**
  with hostile processing retained through continuation. See
  [current parity evidence](validation/m0-wartime-save-parity.json).
- The real native host/AI session passes with current sources.
- Modified Lua files pass formatting and linting.

The wartime harness now expects successful active-hostile continuation instead
of the historical crash. Its current default artifact has an M0 suffix; the
old pre-fix result is preserved. Reproduce it with:

```sh
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/check_wartime_save_parity.py \
  --output /tmp/civcraft-m0-wartime-parity.json
python3 tests/run_civcraft_native_rules.py
python3 tests/run_civcraft_native_session.py --host
```

## Remaining observations and next slice

Native expansion timing, midgame menu starvation, sustained turn/render latency,
physical monitor input and real multiplayer are not established by these narrow
checks. Keep those observations open and collect them during playable milestone
review; do not block implementing accepted mechanics on exhaustive agent training.

M1 introduces a new campaign version for the accepted Conquest/End/Score scope,
250-round Standard deadline and territory-dependent recovery. It must preserve
Original/P1 victory and healing semantics, and update setup, objectives, AI,
reports, help and save/replay contracts in the same playable slice.
