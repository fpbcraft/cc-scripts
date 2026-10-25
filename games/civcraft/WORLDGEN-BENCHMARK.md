# Layered-world desktop benchmark

Run from the repository root:

```sh
lua5.3 tests/civcraft_world_benchmark.lua
```

Measured locally using the Lua 5.3 runtime provided by Lupa 2.8 on the development Mac. These numbers measure game code with mocked peripherals; they do not predict CC:Tweaked FPS, rednet latency, disk latency or late-game AI processing.

Seed 238711, Continents, four civilizations, one city/scout per civilization. Player one has explored the whole map. Each case generates a world, calculates ordinary and continent-wide movement, constructs a filtered snapshot, serializes/restores a save, draws the map twice and runs four AI turns. The serialization helper approximates CraftOS table saves; actual `textutils.serialize` timings and bytes can differ. Retained memory is collected after the scenario and includes renderer buffers, snapshot/save data and simulation state.

| Size | Dimensions | Generate ms | Full land path ms | Snapshot ms | Save/load ms | Draw/redraw ms | Four AI turns ms | Approx save KiB | Retained KiB |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Compact | 18×12 | 2.9 | 2.7 | 0.1 | 1.0 / 0.5 | 11.4 / 6.1 | 4.0 | 30.4 | 1294 |
| Standard | 28×18 | 5.9 | 6.5 | 0.3 | 1.9 / 0.9 | 11.4 / 7.3 | 6.3 | 62.2 | 1386 |
| Large | 40×26 | 11.8 | 18.0 | 0.6 | 3.7 / 1.5 | 13.8 / 9.5 | 6.3 | 118.6 | 1783 |
| Huge | 48×32 | 18.0 | 28.2 | 0.9 | 5.3 / 2.0 | 15.1 / 10.9 | 5.6 | 171.4 | 2020 |
| Vast | 64×40 | 30.0 | 53.2 | 1.6 | 8.9 / 3.2 | 20.1 / 15.0 | 6.6 | 280.6 | 2668 |

Ordinary four-point scout paths took 0.7–1.1 ms. Generation/snapshot/simulation scenarios invoked cooperative checkpoints, increasing from 50 in the Compact scenario to 252 in Vast. These counts show the yielding hooks were exercised, not that a real peripheral event loop was tested.

Huge and Vast are initial available dimensions, subject to actual CC:Tweaked testing. Before release, measure a populated late-game save, four live network clients, save/reconnect, monitor redraws while receiving commands, auto-exploration and AI turns under the target server's computer limits. Preserve Compact for smaller displays or constrained computers.
