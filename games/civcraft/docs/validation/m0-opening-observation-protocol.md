# M0 native opening observation protocol

This bounded driver is an instrumentation base, not completion evidence for issue #75. It uses the installed loader and actual `game.lua` main loop in a fresh CraftOS-PC profile. Its fixed scenario is Specialization V5, seed 319497, compact Continents map, one human and one AI. The map seed/configuration hook applies only to this reproducible correctness workflow.

Run on the target Mac with:

```sh
python3 tests/run_civcraft_native_opening_observation.py
```

Add `--gui` to observe native GUI rendering. The harness prints its isolated profile path; `computer/0/opening-observation.jsonl` contains timestamped campaign metadata, frame draw times, command dispatch times, UI input markers, and stage progress. `computer/0/native-console.log` preserves runtime diagnostics. Never replace an existing validation record with this sample.

## Timing interpretation

- `ui_command_dispatch` measures from UI callback entry through the actual main-loop dispatch and synchronous local host queue return. It is command latency, not click-to-visible latency.
- `frame_draw` is inclusive elapsed time for one `view.draw`; nested component timings can overlap and must not be summed.
- Renderer/GC, AI, rules, and network costs require their own observed trace spans. Report GC only when the runtime naturally emits a GC span; do not force collection in the opening workflow. Network is N/A for the local host baseline and requires a distinct native network run.
- Mouse menu and map viewport measurements are event-to-result observations. The bounded sample does not measure pan/zoom/drag latency distributions or define release budgets.

## M0 gates still pending

Record the source revision, runtime, actual screen/backend, profile, seed, map dimensions/type, and player count for each completed run. The full deterministic opening workflow must use ordinary visible UI actions and main-queue commands, preserve action validation, and stop at 40 rounds. Observe first build and research completion, second-city founding, a repeatable civilian project, menu responsiveness during long work, order latency, and turn time. Record milestones that were not reached as missing; do not extend the bound or tune the scenario to force them. Separate rules, AI, renderer, GC, and network timing while identifying inclusive/overlapping measurements. Derive provisional budgets only from repeated evidence on the target hardware. Actual Minecraft, physical monitor, iPad, and rednet results remain separate evidence.
