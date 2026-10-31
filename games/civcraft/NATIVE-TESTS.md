# Native CraftOS checks

The developer machine has CraftOS-PC at `/Applications/CraftOS-PC.app`. Use a
dedicated emulator directory: these test programs write campaign slots 1 and 3
and diagnostic files. The repository is mounted read-only; the game is copied
into the isolated computer's writable filesystem. Existing user computers and
campaigns are not used.

From the repository root, create a fresh profile and run:

```sh
civcraft_test_root=$(mktemp -d /tmp/civcraft-native.XXXXXX)
/Applications/CraftOS-PC.app/Contents/MacOS/craftos \
  --headless --directory "$civcraft_test_root" \
  --mount-ro "/repo=$PWD" \
  --exec 'fs.copy("/repo/games/civcraft","/games/civcraft");fs.copy("/repo/tests","/tests");local results={};for _,name in ipairs({"civcraft_events_test.lua","civcraft_animations_test.lua","civcraft_craftos_smoke.lua","civcraft_craftos_session.lua"})do results[name]=shell.run("/tests/"..name)end;local out=assert(fs.open("/native-results.txt","w"));out.write(textutils.serialize({host=_HOST,results=results}));out.close();os.shutdown()'
```

Results are under `$civcraft_test_root/computer/0/`:

- `native-results.txt`: each program's pass/fail result and emulator version.
- `civcraft-native-smoke.txt`: renderer mode, actual button commands, journal
  sequence, interpolated positions, elapsed playback time, successful Skip and
  filesystem campaign/AI-plan save/reload.
- `civcraft-native-session.txt`: full game-loop stages, round two, renderer mode
  and successful save/reload.
- `session-input.log`: injected mouse coordinates and the actual buttons under
  those coordinates, for diagnosing the native session driver.

The full-session driver uses real `os.queueEvent` mouse down/up events. Its UI
instrumentation chooses button coordinates and acknowledges when the game's
renderer has consumed the input marker. It follows paged controls, introductory
reports, two human turns, private handoffs, pause, save and exit. It does not
replace the terminal, renderer, filesystem, peripheral APIs, input loop, rules
or save implementation.

For the slow-render watchdog regression, run
`/tests/civcraft_craftos_render_watchdog.lua` in the same isolated installation.
It deliberately spends 200 ms on each of 100 sprite rows: the complete drawing
operation exceeds the default 17-second watchdog, but each row remains bounded.
The original renderer fails; row checkpoints let the patched renderer finish.
Results are written to `/civcraft-render-watchdog.txt`. Headless runs instrument
the graphics output; GUI runs use the native graphics terminal when available.

Recorded local validation used **CraftOS-PC 2.8.3 / ComputerCraft 1.112.0**.
Headless checks use the real **text** backend at the default **51×19** terminal.
The separate regression suite covers graphics primitives and text/graphics
layout with fake displays. GUI pixel animation, physical advanced-monitor input,
network modem traffic and multi-client reconnects still need their own tests;
headless success does not establish those behaviors.

For the economic AI scenarios, run `/tests/civcraft_economic_ai_test.lua` inside
the isolated computer. Run `/tests/civcraft_craftos_session.lua --ai` to configure
a third AI through the session commands and execute its real turn alongside the
two human turns. Its session result also verifies AI-plan reload. This variant
still overwrites only the isolated profile's save slot 1.

Add `--settings` to that full-session command to open Settings with real mouse
input, change animation speed, cycle the display preference twice and continue
through the campaign. `settingsReload` in the session result confirms the saved
preferences. `tests/civcraft_settings_test.lua` separately checks all settings,
including independent sound/music and volume gain, with instrumented displays
and a speaker.

Add `--research` to traverse the compact technology graph, open a technology's
description, follow its building Codex link, return to research and choose it
using real mouse input. `researchFlow` records that the selected research order
survives the round boundary and save reload. The driver preserves and navigates
the detail scroll position when reopening research.

Add `--campaign` to open Campaign Options in the lobby, select Quick and disable
Score, then start the campaign. `campaignOptions` confirms that the selected
pace, deadline and victory toggles survive the full session and save reload.

Add `--war` to the two-human session to have the second human declare Surprise
War after the first human has ended. The driver hands the screen back for the
first human's response, saves during that response and finishes it before the
round boundary. `warResponse` and `responseSaved` confirm the path and persisted
Ready/reaction state. The next round rotates the war group's starting player.

Use `--host-ai` instead of `--ai` for a separate host-mode scenario: add an AI
through the network lobby, complete the host/AI round, save and exit.
`hostModeAI` confirms this path. It can combine with `--settings`, `--research`
and `--campaign`, but not `--war` (which requires the two-human scenario).
This tests the actual host code without a modem; it does not establish live
rednet transport or multi-client reconnect behavior.

Add `--conversation` to either AI session to open the AI faction's conversation,
greet it, offer commerce and send gold through real mouse input. The host must
execute the AI replies and actual agreement/exchange effects; `conversationFlow`
confirms that the accepted exchange and active commerce survive save reload.
This combines with the hotseat `--war` response/save scenario. Run
`/tests/civcraft_diplomacy_test.lua` separately for offer ownership, atomic
funding, defense choices, armistices, counters, obligations, observation privacy,
promise movement and expiry scenarios.

The conversation driver now navigates Basalt tabs, agreement menus and trade
review dialogs. With `--conversation` or `--war`, its isolated map fixture places
capitals within normal sight so first contact is established through revelation.
It never assigns contact flags or bypasses host diplomacy validation. Run
`civcraft_contacts_test.lua` and `civcraft_conversation_ui_test.lua` in the isolated
computer for contact privacy, actual widget input and counteroffer checks.

The main session now follows the unified turn button, chooses Skip Turn for its
human units, chooses No Production for idle cities and assigns research before
ending. `turnTasks` verifies those accepted orders in the saved campaign. The
response scenario uses the same task workflow during the defender's unspent-action
window. The driver allows 45 seconds for the longer sequence of real mouse events.

Run `civcraft_zone_control_test.lua` in its own isolated computer for movement
locks, civilian costs, domain/peace exceptions, hidden-guard discovery and aborted
attack approaches. It asserts actual frozen replay endpoints and preserves an
unused attack on interruption. Full-session success also verifies startup and
existing turn/diplomacy flows with control enabled.

Run `civcraft_embarkation_test.lua` in an isolated profile for sea allowances,
landing and response budgets, amphibious forecast/resolution parity, coastal
capture, shore attack restrictions and observed-enemy danger estimates. The
normal full session also exercises the response activation hook without granting
an ended defender a second movement budget.

`civcraft_unit_stacks_test.lua` tests capture/protection and shared-tile selection
with real core rules and instrumented text/graphics displays. It installs the
same CivCraft-specific internal module cache as `game.lua`; it does not change
the CraftOS watchdog. `civcraft_module_cache_test.lua` checks isolation, failure
recovery and external-script behavior.

`civcraft_escorts_test.lua` runs linked movement, attack/removal cleanup, sea and
control rules, assigned AI attachment, cost-pair routing and compact inspector
controls in an isolated CraftOS profile. Both text and graphics controls use
instrumented monitors; this does not establish physical-monitor behavior. For
full-session tests, run the driver in the installed loader environment with
`_lib/fpb/loader.lua`, so entry-point globals and the module cache match installation.


`civcraft_queued_routes_test.lua` exercises saved waypoints, undiscovered
destinations, fog-safe path previews, selected-unit route overlays, independent
and escort budgets, no automatic attacks, private projections, malformed saves,
sea landing and compact queue controls. Run the full-session driver with `--routes`
to verify the actual host start-of-turn hook and saved progress. A peaceful run
asserts resumption; combining it with `--war` verifies waiting for the rotated
war-group activation. These scenarios use isolated computers and the installed
loader environment.


`civcraft_fog_memory_test.lua` checks frozen scenery/cities/deposits/borders,
last-look capture, re-scouting, local and network projections, grey sprite pixels
and recreated display preferences. Its pixel comparison uses instrumented
graphics and its core rules also run in isolated CraftOS-PC. The normal full
session covers renderer preference changes, hotseat, routes and save reload.


`civcraft_event_history_test.lua` verifies private complete history after replay
pruning, bounded reverse pages, legacy migration and fixed navigation across
51x19, 57x38 and 100x67 text/graphics layouts. `--history` in the full-session
driver opens the top-bar log, refreshes through actual host dispatch and asserts
that the observer's action count does not change. It combines with `--routes`,
`--conversation`, settings/research/campaign flags and Surprise War. Animation
tests cover per-event opening pauses, menu-pause timing and fast/off behavior.

`civcraft_watchdog_test.lua` checks bounded streaming output, Lua round trips,
bootstrap timing/input preservation and per-tile visibility checkpoints. Save
tests cover encoding, disk-write and rename failure recovery for local and host
paths. `civcraft_craftos_save_stress.lua` rewrites isolated copies of all occupied
slots four times, compares every loaded field and records checkpoint/yield counts
and cycle timings in `/civcraft-save-stress.txt`. Keep originals mounted read-only
and copy them into a separate profile before running it. The original serializer
reproduced a watchdog on the largest copied save; patched load/save/reload cycles
finished in 34-35 ms. An isolated real-game continue/render/save/reload also passes.
No production save files are required in the repository.


`civcraft_council_test.lua` checks private/frozen ballots, delegate safeguards,
ID zero, victory prerequisites, AI incentives, voluntary pledges, actual market
and commerce restrictions, forced peace and expiry. `civcraft_council_ui_test.lua`
uses actual click coordinates in six text/graphics layouts and resets hotseat
drafts. Both install the same module cache as the game. The full-session driver
accepts `--council`: its explicit Currency-era fixture opens a normal session and
casts an abstention through the top-bar menu and host dispatch. Combine it with
`--history --routes --conversation --settings --research --campaign` and either
`--ai --war` or `--host-ai`. Isolated native local and host runs pass. These are
text-backend runtime checks; graphics layout tests use an instrumented display.


`civcraft_craftos_world_stress.lua` is for a dedicated temporary profile: it
overwrites slot 1 with generated benchmark data. It generates every size/type
pair, executes three early rounds for four AI actors on the 96×60 Vast map,
reveals observers and saves/reloads. `/civcraft-world-stress.txt` records per-map
and per-actor timings, saved bytes and cooperative checkpoints/yields. The run
passes on installed CraftOS-PC 2.8.3. It measures early simulation and persistence;
it does not establish late-game physical-monitor or network performance.


`civcraft_compact_toolbar_test.lua` verifies eight text/graphics layouts, including
51×19 and 57×26: every map control fits, controls do not overlap, and paged map
tools perform overlays, zoom and overview navigation. `--map-tools` in the native
full-session driver clicks the actual Map Tools/Zoom/Overview controls on a short
terminal. Taller sessions retain their direct toolbar.


`civcraft_difficulty_test.lua` checks five tiers, host validation, public settings,
unchanged resources/costs/budgets/personality, deterministic easier choices and a
legal coordinated kill. `civcraft_difficulty_ui_test.lua` cycles all tiers in four
compact/wide text/graphics campaign panels. `--difficulty` in the full-session
driver sets the AI to Deity and verifies save persistence in local or host mode.

`civcraft_ai_tournament.lua [rounds] [seed] [civilization]` runs ten same-seed,
swapped-seat tier-versus-Prince matches. Defaults are 40 rounds, seed 75123 and
Andesite Engineers (`forge`). It records score, cities, research, shared-action
counts/rejection reasons, winning IDs, actor time and collection/yield counters.
Native results go to `/civcraft-ai-tournament.txt`; a small progress file identifies
the current stage. These are generated-data smoke tests, not win-rate estimates.

Extended native tournaments exposed collection stalls in CraftOS-PC 2.8.3. The
shared checkpoint now performs supported collection between work chunks on that
runtime. Unpatched eight-round matrices exceeded 180 seconds; patched ones finish
in 2.8 seconds. A forty-round matrix completes in 27.5 seconds with 4,642 orders,
zero rejections, a 144 ms worst actor and 14 ms maximum collection under concurrent
load. Collector settings remain unchanged; unsupported operations preserve normal
yields. The watchdog regression checks throttling and fallback.

`civcraft_craftos_render_stress.lua` executes 500 real text frames and 500
instrumented graphics frames, panning, zooming and opening Report/Council panels.
`/civcraft-render-stress.txt` records median/maximum frame time and collector costs.
The installed runtime passes all 1,000 frames: text 8/13 ms and graphics 18/26 ms
median/maximum, with collections at most 2 ms. Graphics API calls are instrumented;
physical monitor performance remains a separate integration check.

## Reusable isolated session launcher

From the repository root, run:

```sh
python3 tests/run_civcraft_native_session.py
python3 tests/run_civcraft_native_session.py --host
python3 tests/run_civcraft_native_session.py --monitor
python3 tests/run_civcraft_native_session.py --unit-actions
python3 tests/run_civcraft_native_network.py
```

Use `--craftos /path/to/craftos` if the executable is not on PATH or installed in
its usual macOS location. Each command creates a fresh temporary profile and copies
only runtime sources and generated test data into it. Existing installed campaigns
are not read or changed. The printed profile contains diagnostics and results.
`--unit-actions` exercises the compact inspector fallback with a queued native
mouse click, then asserts the action arms a legal move before the standard session
continues.

The monitor variant requires the GUI: headless CraftOS cannot create monitors.
It creates an isolated `top` monitor through the real peripheral emulator and sends
`monitor_touch` events at rendered button coordinates, rather than mouse events.
It passes title/campaign setup, AI difficulty, settings, research, conversations,
Council, routes/history, Surprise War/hotseat responses and save reload. Its driver
handles both inline wide-inspector actions and compact inspector dialogs. This
verifies native emulated monitor rendering/input; physical Minecraft monitors and
target-server CC:Tweaked remain separate acceptance checks. See the official
[peripheral emulator API](https://www.craftos-pc.cc/docs/periphemu).

The three-computer network driver uses genuine emulated modem/rednet traffic on a
private network ID. It checks simultaneous movement collisions, sender ownership,
observer filtering, Council votes after Ready, Surprise War budget preservation,
a mid-response save, client reboot/rejoin and recovery from deliberately dropped
join/state messages. All three computers report passing results. Its output does
not establish real-world latency, modem range or Minecraft-server tick behavior.

`civcraft_ai_matrix.lua [rounds]` repeats the tournament across six seeds and nine
civilizations, including same-civilization mirrors and mixed economic, expansion,
naval and defensive matchups. Each case uses all five tiers in both seats against
Prince. It defaults to 100 rounds and writes completed cases progressively to
`/civcraft-ai-matrix.txt` on CraftOS. Use an isolated profile; it produces sixty
matches and can take several minutes. `civcraft_ai_tournament.lua` additionally
accepts an opponent civilization as its fifth argument; pass an empty fourth
argument when not enabling its diagnostic `--gc` option.

Reports distinguish host rejections of unseen completed wonders and movement
that is legal in the observer's view but blocked in authoritative state. Any
other rejected AI action fails the run. The test harness may compare full and
filtered state to classify a denial; the AI itself receives no hidden information.


The session launcher also enables `--civilization`: it selects Desert Wanderers
from the actual dropdown and verifies campaign-save persistence. Research checks
now use the persistent sidebar's Codex links and pinned Research action, without
an intermediate Details screen. Wide-inline and compact inspector controls remain
part of the same mouse/monitor-touch driver. The network test exercises guest
civilization selection and rejects changing the host's choice.

## Installed-runtime validation

```sh
python3 tests/run_civcraft_native_session.py --installed-ref <published-commit-sha>
```

This variant downloads the actual pinned GitHub installer/runtime instead of
copying source files. It seeds only generated legacy slot-2 data in a new temporary
profile, runs the complete campaign session in slot 1 and checks that both the
migrated slot and its original legacy copy remain byte-for-byte intact. It also
checks that no startup script was created. The full session passes at published
revision `fee211b7d3334089123b4f184e13cc5a98658122`, exercising the installed Basalt
conversation, Council, research sidebar, dropdown and save/reload dependencies.
An invalid revision is reported as failure and the temporary native process exits.

`civcraft_installer_test.lua` additionally loads the installed modules through
their private loader with source-tree `require`, `package` and shell fallbacks
unavailable. Twenty-four version/ruleset/speed migration combinations preserve
terrain/deposits/rails, campaign identity, research/production progress and spent
movement allowances. These complement the shared installer download/move-failure,
repeat-update, legacy conflict and startup ownership checks.


`civcraft_save_resume_test.lua` exercises installed runtime serialization with
current feature records combined: attacker/defender Surprise War windows across
all three speeds, linked queued escorts, private deals, Council pledges/votes,
AI plans, fog memory and journal cursors. It verifies post-load eligibility,
remaining response budgets, normal-boundary resets and exactly-once route progress.
It is a desktop installed-loader regression, complementing native session and
client-reboot tests rather than claiming a physical-server host reboot.


## Overlapping network wars

The network driver continues through round four after its original response-window
reconnect. It exercises an immediate three-member merge, a second waiting-client
reboot, negotiated peace at the boundary, a peaceful player's independent action,
a waiting-member rejection, a pending normal declaration and its next-boundary
merge. It checks explicit remaining budgets before transitions and allowance
stamps in the final authoritative save. Private snapshots are checked throughout.

```sh
python3 tests/run_civcraft_native_network.py
python3 tests/run_civcraft_native_network.py --reverse-race
```

The second command makes client 2 win the initial collision, also exercising
client 1's legal fallback movement. Both variants pass. The harness waits for
individual result packets and updated snapshots separately; receiving a new round
does not imply that another client's result acknowledgement has already arrived.

## Specialization V5 network recovery

Run the generated cityless V5 opening and specialty command flow on three actual
CraftOS-PC computers with:

```sh
python3 tests/run_civcraft_native_specialty_network.py
python3 tests/run_civcraft_native_specialty_network.py --reverse-race
```

Both contention orders cover legal founding commands, duplicate-site rejection,
production and pausing, host save/exit/restart, client OS reboot/rejoin, and owner and
foreign projections. Client 2 confirms an actually completed but unseen foreign site
is absent, then receives the expected foreign city and public site IDs in a newer
snapshot from the same campaign at or after the expectation round. That public site
record omits progress, source-site, project and pause-reason fields; foreign city
records omit private site, project, focus and progress fields. After the real Knowledge
site project has positive owner-side progress, client 2 must receive a second newer
snapshot containing the same foreign city and completed site while omitting the active
project, `siteProjects`, focus, and progress fields. The project is paused only after
this check; the temporary vision boost and original unit stat are retained until the
second acknowledgement. The controlled post-founding fixture grants research,
population, gold, food, industry buildings and owned claims; terrain, generated
starting actor positions, site legality, site commands and production remain
authoritative. This is native CraftOS-PC evidence, not an unmodified progression run
or physical Minecraft monitor/rednet validation.

## Desktop graphics and stall diagnostics

`python3 tests/run_civcraft_native_session.py --gui --default-specialization --host`
uses the native GUI terminal instead of headless text. `--monitor` instead
exercises an emulated advanced monitor and queued `monitor_touch` events. These
are desktop runtime checks; neither proves iPad or physical Minecraft behavior.
The contact-HUD scenario follows the compact menu or the direct contact badge
provided by the actual viewport.

The session fixture enables `--debug`. Rotated logs retain host/display headers
and distinguish `gc.begin/end`, `yield.wait.begin/end`, graphics strip calls,
and freeze/unfreeze calls. Compare both retained log segments after a stall.
`civcraft_upload_recovery_test.lua` injects native graphics and diagnostic
failures; `civcraft_yield_trace_test.lua` separates simulated collection time
from event waiting and verifies pending input order. Fault injection is not a
reproduction on the target device.

## Wrapped-map graphics and input

Run the focused wrapped-map workflow in a graphics-capable CraftOS-PC build:

```sh
python3 tests/run_civcraft_native_wrap.py --gui
python3 tests/run_civcraft_native_wrap.py --monitor
```

The fixture uses a three-column cylinder with enough visible width to show two
complete periods. It queues native mouse or monitor-touch events through real UI
controls to select repeated city banners and unit targets, zoom, pan, confirm a
canonical seam movement and use the minimap. Assertions cover short-path playback
and camera following, hidden-observer projections, native wrapped save/load and
the normal world/system migration pipeline for an older missing-wrap save.
Controlled terrain and actors isolate the seam; general campaign progression,
installed runtime and multiplayer still require their separate drivers. Desktop
CraftOS graphics do not prove iPad or physical Minecraft behavior.

Specialty-session timeouts retain the last visible controls and text in the error,
and up to 40 distinct recent menu pages in `/specialty-session-pages.json`. These
are diagnostics; a timeout remains a failed scenario.

## Controlled Founders late-state runtime

```sh
python3 tests/run_civcraft_native_founders_stress.py --backend text
python3 tests/run_civcraft_native_founders_stress.py --backend gui
python3 tests/run_civcraft_native_founders_stress.py --backend monitor
python3 tests/run_civcraft_native_founders_stress.py --backend text --profile-first-frame
```

The full matrix checks V4 bounded and V5 wrapped Huge/Vast worlds with 40 cities,
200 units and full-map observer visibility at a constructed round 100. It exercises
native banner input, zoom, mouse drag or monitor pan, and save/reload. Each actual
draw has an explicit frame record; the runner verifies frame counts, maxima and
renderer backend. For hardware-backed graphics, use `--craftos` with a launcher
that adds CraftOS-PC's `--hardware` option.

The last command profiles only one V4 Huge frame, with inclusive component and
GC timings; it does not pass the four-case matrix. Progress and partial reports
remain in the isolated profile. The retained summary is
[`docs/validation/founders-runtime-validation.json`](docs/validation/founders-runtime-validation.json).
These are controlled desktop measurements, not AI-turn throughput, played campaign
balance, iPad or physical Minecraft/monitor/rednet/server evidence.

## Settler settlement advice

Add `--settlement-suggestions` to the native session runner to exercise the real
opening Settler's advisory list, paginated explanations, Show on Map and canonical
marker input before continuing ordinary founding and save/restart. Combine it
with `--host`, `--gui`, `--monitor` or `--installed-ref` as appropriate. The fixture
asserts unchanged Settler position/budget and zero game orders during advice;
hotseat runs also verify private advice is cleared at handoff. Display-setting
changes rebuild the renderer, so the text observer reattaches to each new canvas.
Exact scope and limits are retained in
[`docs/validation/settlement-suggestions-validation.json`](docs/validation/settlement-suggestions-validation.json).

## Saved Builder auto work

Run `python3 tests/run_civcraft_native_builder_auto.py` for real Auto/Pause/Resume
input, save/exit and a fresh-process restart that completes an improvement and
consumes a charge. Add `--gui` for GUI rendering, `--gui --monitor` for emulated
monitor-touch controls, or `--installed-ref <published-ref>` to install that
revision first. A controlled generated V5 fixture supplies capitals, research,
a charged Builder and an open owned tile; it does not seed completed work.
The monitor scenario uses keyboard Q to open pause, so it does not prove a
touch-only pause workflow.

`python3 tests/run_civcraft_native_specialty_network.py` and `--reverse-race`
also check owner Builder auto commands, spoofed-owner rejection, acknowledged
snapshots and rival privacy before the existing specialty/restart/rejoin cases.
Detailed revisions, outcomes and limits are in
[builder-auto-validation.json](docs/validation/builder-auto-validation.json).
