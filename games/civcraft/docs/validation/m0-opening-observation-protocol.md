# M0 native opening observation protocol

This bounded driver records opening correctness and runtime observations for issue #75. It does not establish target-device release budgets. It uses the installed loader and actual `game.lua` main loop in a fresh CraftOS-PC profile. Its fixed scenario is Specialization V5, seed 319497, compact Continents map, one human and one AI. The map seed/configuration hook applies only to this reproducible correctness workflow.

Run on the target Mac with:

```sh
python3 tests/run_civcraft_native_opening_observation.py
```

Add `--gui` to observe native GUI rendering. The harness prints its isolated profile path; `computer/0/opening-observation.jsonl` contains timestamped campaign metadata, frame draw times, command dispatch times, UI input markers, and stage progress. `native-console.log` preserves runtime diagnostics. Never replace an existing validation record with this sample.

## Timing interpretation

- `command_callback` measures UI dispatch callback return. An initially idle callback may drain synchronous host work; a busy queue may return before authoritative execution. It is not a general command acknowledgement or click-to-visible measurement.
- `frame` is inclusive elapsed time for one `view.draw`; nested component timings can overlap and must not be summed.
- Renderer/GC, AI, rules, and network costs require their own observed trace spans. Report GC only when the runtime naturally emits a GC span; do not force collection in the opening workflow. Network is N/A for the local host baseline and requires a distinct native network run.
- Mouse menu and map viewport measurements are event-to-result observations. The bounded sample does not measure pan/zoom/drag latency distributions or define release budgets.

## M0 gates still pending

Record the source revision, runtime, actual screen/backend, profile, seed, map dimensions/type, and player count for each completed run. The full deterministic opening workflow must use ordinary visible UI actions and main-queue commands, preserve action validation, and stop at 40 rounds. Observe first build and research completion, second-city founding, a repeatable civilian project, menu responsiveness during long work, order latency, and turn time. Record milestones that were not reached as missing; do not extend the bound or tune the scenario to force them. Separate rules, AI, renderer, GC, and network timing while identifying inclusive/overlapping measurements. Derive provisional budgets only from repeated evidence on the target hardware. Actual Minecraft, physical monitor, iPad, and rednet results remain separate evidence.

## Recorded reference observations

See [m0-opening-observations.json](m0-opening-observations.json) for exact source, commands, actual configuration, milestones, timing summaries and artifact checksums. Both native text and hardware graphics runs reached expansion at round 8, first research at round 9, first building at round 13 and civilian-project output at round 26, using ordinary commands with no granted resources or technology. The fixed workflow is a usability observation, not an AI pacing or balance experiment. It uses the existing Settler planner for legal founding/movement and scripted production priorities.

The driver clicks the visible zoom control, verifies a changed viewport after wheel-pan/drag, opens/resumes the pause menu, and queues a menu key during the first round resolution. That queued key was serviced at round 6 (217 ms text / 332 ms graphics); record this queue delay explicitly. It does not prove immediate menu service inside long work. Graphics inclusive round maximum was 205 ms and text 160 ms for this compact scenario. These two samples cannot establish worst-case budgets or Huge-map/iPad responsiveness.

Native logs provide separate AI, save, draw and natural runtime GC spans. Round spans include rules and nested work; pure rules CPU cost is not isolated. Network is not exercised. Physical target measurements and release-budget decisions remain open in #75.

## Separate native transport observations

Run `python3 tests/run_civcraft_native_network.py --timings` and repeat with `--reverse-race`. The existing three-computer emulated-modem fixture uses V3, generated seed 12345 on a 40x26 map, with controlled starting positions/terrain and scenario injections. This is shared transport/legacy compatibility evidence, not a natural V5 opening run.

Optional timing mode independently observes accepted result packets and snapshots proving the expected new position plus remaining movement budget for two serialized movement commands. The Python runner fails if either observation is missing. Since result packets do not carry request IDs, these measurements do not support arbitrary pipelined-command correlation. No production packet fields are added.

[m0-network-timing-observations.json](m0-network-timing-observations.json) records source, commands, actual metadata, samples and artifact hashes. The final source samples were 22–24 ms to acknowledgement and 24–26 ms to the changed snapshot. These are four controlled local commands across two scenarios, not a network latency distribution or a physical rednet budget. Natural V5 opening measurements are recorded separately below.

## Natural V5 network opening

Run `python3 tests/run_civcraft_native_network.py --v5-opening`. This uses two real CraftOS-PC computer states connected by emulated modems: one host, one guest and one ordinary AI in a generated V5 compact Continents world, seed 319497. Hostile mode is off; no generated terrain, resources, population, technology or units are replaced or granted. Both humans use normal validated Settler orders to found their first city. The guest then makes a legal one-point Warrior move and ends its turn; the host also ends normally so the AI and round boundary execute. This is an initial network opening check, not the full 26-round milestone workflow from the separate host observations.

The guest keeps commands serialized until an accepted result and a state snapshot proving the actual effect both arrive, and its current UI snapshot reflects that effect. Move timing requires the exact unit ID, destination and remaining movement; round timing requires the next round. Timing does not equate a result packet with state delivery. Two fixed-source repetitions passed: movement acknowledgement 15–16 ms, changed movement snapshot 17–19 ms; round-end acknowledgement 47–49 ms, next-round snapshot 48–51 ms. The next-round latency includes host/AI/round work and transport; it is not pure network overhead. Samples, exact source and failed-attempt disposition are in the `naturalV5Opening` section of the network evidence JSON.

The legacy V3 reversed collision scenario also passed after this driver extension. Physical network/device timing, long multiplayer observations, repeated distributions and release budgets remain open in #75.

## Sustained ordinary network order load

Add `--opening-rounds 20` to the V5 command to observe repeated accepted end-turn orders through round 20 (allowed bound 3–40). Every round boundary from the initial timed boundary through the requested limit must have its own acknowledgement and matching next-round snapshot sample; missing/non-contiguous samples fail the runner. The default remains the short round-3 check.

The recorded 20-round run passed both computers and all 18 consecutive boundaries (3–20). Acknowledgement min/median/max was 47/100/142 ms; matching snapshot min/median/max was 49/102/144 ms. Full samples, provenance and the failed JSON-output attempt are in `sustainedV5OrderLoad` in the network evidence JSON. Human production/research queues are deliberately idle, while the ordinary AI advances normally. This is a fixed native correctness/order-load fixture, not a played-campaign pacing or balance experiment. It does not establish physical-device or network budgets.
