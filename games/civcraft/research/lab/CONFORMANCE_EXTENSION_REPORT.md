# Conformance extension report

**Scope:** fast Lupa checks plus a short native CraftOS-PC companion run on the current working tree. No full-game benchmark was launched. The fixtures do not modify gameplay modules.

Run:

```sh
/tmp/civcraft-lua-env/bin/python \
  games/civcraft/research/lab/run_conformance_extensions.py
```

Raw compact output: [`results/conformance_extension.json`](results/conformance_extension.json). Fixture source: [`conformance_extension_fixture.lua`](conformance_extension_fixture.lua).

Native comparison:

```sh
/tmp/civcraft-lua-env/bin/python \
  games/civcraft/research/lab/check_conformance_extension_native.py
```

Native compact output: [`results/conformance_extension_native.json`](results/conformance_extension_native.json). Native driver: [`conformance_extension_native.lua`](conformance_extension_native.lua). Raw canonical payloads: `/tmp/civcraft-conformance-extension-native.raw.json`.

## Results

### Observer information boundary — pass

The fixture records player 0's detached observation and candidate proposals, then mutates only hidden player 1 data: a private AI plan, large gold/stockpiles, an unseen rival city/unit and a recipient-1-only event. The hidden tile is outside the observer's explored/visible two-tile neighborhood so the test does not conflate hidden data with a legitimate newly visible territory update.

Observation and proposal canonical hashes remain identical before/after mutation:

- observation: `cf39dac1…ed412`
- proposals: `318c751e…1d120`

This is evidence for the covered fields, not a proof for every future snapshot/event field. The report should be extended whenever `World.forPlayer`, event projection or policy input fields change.

### Unordered-state hash determinism — pass

Four subprocesses with `PYTHONHASHSEED` values 0, 1, 42 and 123 each created three identical four-player Archipelago states. All 12 canonical state hashes equal:

`08da23dedf0295be7fa1d75e8ea8d0a46650e54bb69635d550fb10876d031273`

This checks canonical sorting and repeatability under Python hash-seed variation. It does not establish native CraftOS parity or prove all later action paths deterministic.

The `PYTHONHASHSEED` check varies Python orchestration only; it does not vary a Lua hash seed.

### Surprise War/reaction/trace replay — pass

Two identical registered-player Lupa runtimes execute the complete intended sequence: Surprise War declaration, attacker `Engine.endTurn`, `Actors.pump`, defender reaction movement, and defender `Engine.endTurn`. The declaration succeeds, the war is active, and the defender's reaction is granted before the scheduler handoff. Both runtimes produce equal outcomes, equal hashes at five checkpoints, equal telemetry traces, and equal final hash `b4440519…e859e10`. A fresh Lupa runtime replaying the same orders, lifecycle finishes and pump handoff also matches state, outcomes and trace exactly.

The earlier pre-handoff rejection was expected scheduler behaviour, not a defect: a Surprise War grants the ended defender a reaction but leaves the attacker as the active war-group member until the attacker finishes. After that legitimate handoff, `Actors.pump` marks `responseMovementRound`, the defender move is accepted, and finishing the response consumes the reaction. The final checks are `warActive=true`, `reactionGrantedBeforeHandoff=true`, `responseMovementMarkedAfterPump=true`, `defenderMoveAccepted=true`, `reactionConsumedAfterDefenderFinish=true`, and `reactionPathBlocked=false`.

### Native CraftOS-PC comparison — pass

The native companion runs the same fixture in a fresh CraftOS-PC profile and compares it with the Lupa payloads. All 75 checks pass: adversarial observer before/after fields, five canonical state checkpoints, both observer views at each checkpoint, legal proposals, lifecycle/action outcomes, reaction checks, telemetry trace, and final canonical state. The native primary trace contains two accepted gameplay actions (declaration and defender movement); lifecycle finishes are compared as explicit outcome steps.

The compact native record includes the full `sourceManifest` plus SHA-256 values for the Python drivers and both Lua fixture scripts. The existing 21-check wartime/save parity artifact, including its known orphan-settler diagnostic, remains separate and is not folded into this result.

## Remaining limits

- No full-game benchmark, network/rednet replay or production save replay was run in this extension.
- The observer test covers hidden plan/stockpile/city/unit/event data but not every possible rival field or future policy API.
- The replay is a two-player Surprise War reaction fixture, not a balance sample, victory test or latency measurement.
- This validates the registered-player scheduler handoff in Lupa; native CraftOS-PC and network timing remain outside this extension.
