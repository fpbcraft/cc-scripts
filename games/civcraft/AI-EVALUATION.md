# AI development checks

Workstream 05 was checked with the repository's Lua 5.3 regression runner and
native CraftOS-PC 2.8.3 / ComputerCraft 1.112.0 in isolated profiles.

`tests/civcraft_economic_ai_test.lua` exercises food-preserving specialization,
treasury pressure, deliberate production idle/resume, saved settlement detours,
rejected commands, hidden-world independence, persistent rails and bounded
material purchases. The native scenario suite took 0.294 seconds in the recorded
run. The native rendering/save smoke test and full two-human/one-AI session also
passed. The full session took 1.144 seconds including actual mouse events,
rendering, AI execution and filesystem saves; this is not an isolated AI timer.

The seeded progression scenarios use seed 75123, Standard/Pangaea, two AIs,
standard hostile mobs and independent villages. The current two-Scholar scenario
reached End Expedition in round 93; two Engineers reached Industrial in round
137. These scenarios establish reachable progression, not win-rate balance.

Run the existing desktop benchmark from the repository root:

```sh
lua5.3 tests/civcraft_world_benchmark.lua
```

The recorded Lua 5.3/Lupa run measured all four initial AI turns together:

| Map | Four AI turns |
| --- | ---: |
| Compact 18×12 | 23.0 ms |
| Standard 28×18 | 36.3 ms |
| Large 40×26 | 54.9 ms |
| Huge 48×32 | 69.8 ms |
| Vast 64×40 | 96.7 ms |

That fixture has four new cities and four scouts, with one observer knowing the
map. It does not represent a mature empire, a siege, modem latency or physical
monitor performance. Release checks still need wider seed/personality/difficulty
matrices, casualty and wasted-order metrics, large armies, campaign recovery,
interactive graphics pacing and concurrent network sessions.
