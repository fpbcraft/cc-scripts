# LuaJIT simulation backend

The research runner supports `runtimeBackend: "luajit21"` and
`tools/civcraft_lab/run.py --backend luajit21`. Both execute the same Lua rules,
AI, lifecycle, action dispatch and observer code as the Lua 5.3 reference.
Lua 5.3 remains the default for old configurations and historical reproduction.
New performance-sensitive studies should explicitly select LuaJIT and record
its version and extension fingerprint. This does not change the Minecraft
runtime or deploy a new AI policy.

## Install in a temporary virtual environment

The macOS Lupa 2.8 wheel used here does not contain its LuaJIT extension. Build
that extension alongside its existing Lua 5.x modules. The helper requires a
C compiler and an already built LuaJIT tree; it does not install anything
globally or replace the reference module.

```sh
python3 -m venv /tmp/civcraft-lua-env
/tmp/civcraft-lua-env/bin/python -m pip install -r tools/civcraft_lab/requirements.txt
/tmp/civcraft-lua-env/bin/python -m pip install setuptools wheel Cython

git clone https://github.com/LuaJIT/LuaJIT.git /tmp/civcraft-luajit-probe
git -C /tmp/civcraft-luajit-probe checkout a4c064539ea931274d407e1249b4bb575424a0f4
MACOSX_DEPLOYMENT_TARGET=11.0 make -C /tmp/civcraft-luajit-probe -j4

/tmp/civcraft-lua-env/bin/python -m pip download lupa==2.8 --no-deps --no-binary=lupa -d /tmp/civcraft-lupa-jit-build
/tmp/civcraft-lua-env/bin/python tools/civcraft_lab/build_luajit_backend.py \
  --luajit-source /tmp/civcraft-luajit-probe \
  --lupa-archive /tmp/civcraft-lupa-jit-build/lupa-2.8.tar.gz
```

Reuse existing paths rather than creating or cloning over them. The helper
checks the official source archive SHA256
`d8022641b9ec8ecf2c5ecbe9f47e5a70e0b87c4b5ae921b92cb02a638e0acd08`.
Its only Lupa setup modification names the custom-library extension
`luajit21`, preserving `lupa.lua53`. This follows Lupa's supported custom
`--lua-lib` / `--lua-includes` build path; see the
[upstream build documentation](https://github.com/scoder/lupa#building-with-different-lua-versions).
The compiled extension fingerprint is recorded in normal match results.

## Compatibility and budgets

The adapter provides Lua 5.1-compatible `table.pack` / `table.unpack` shims.
Lua table conversion recognizes each backend's own table type, including
nested records and checkpoint restoration. Unknown or unavailable backends
produce errors; there is no silent fallback.

The existing count hook remains enabled. **Compiled LuaJIT traces do not have
an established equivalent instruction ceiling.** Always use the bounded
spawned-worker runner, which terminates a child exceeding its wall budget,
and retain action limits. A timeout remains a timeout, never a game loss.
The small-budget regression checks an immediate error; it does not prove
instruction-hook coverage for long compiled loops.

## Conformance and measurements

```sh
/tmp/civcraft-lua-env/bin/python -m unittest discover -s tests -p test_civcraft_luajit.py
/tmp/civcraft-lua-env/bin/python -m unittest discover -s tests -p test_civcraft_pacing_probe.py
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/compare_runtime_backends.py
```

The comparison runs four full-match configurations (original/P1, two/four
players, Pangaea/Archipelago, Scholar/Forge/Iron/Merchant), plus four eight-round
hostile prefixes with three players, Highlands/Continents and
Verdant/Mariner/Sentinel. It checks canonical state after initialization,
every actor pump and round advance, ordered action traces, plus observer and
metric snapshots in the first five rounds and every tenth round.
Results: [runtime backend parity](results/runtime_backend_parity.json).
The final run passed **936 canonical boundary checks, 500 observer comparisons
and 9,664 ordered action attempts**, with an unchanged source manifest.
All four full matches finished (rounds 102, 112, 113 and 113). Their aggregate
simulation CPU ratio was **2.684x**, with individual full-match ratios
2.606–2.888x. These are measured results on this machine, not a promised
speedup for every configuration.
These are eight controlled cases, not all possible gameplay states.
Hostile prefixes do not establish full-game stability of the known
captured-Settler bug.

Initial checks exposed nondeterministic ordering in `Reports.build`: unsorted
unit-map iteration could swap two recruitment lines. The actions were equal,
but full saved state differed. Report sections now sort their entity keys;
report content and gameplay rules are unchanged. The first exploratory
artifact is retained as [initial probe](results/runtime_backend_initial_probe.json);
its source manifest changed because the unused build helper was added during
that run, so it is diagnostic evidence rather than the final validation run.
A separate read-only telemetry regression caught city-yield measurement
initializing worked tiles. Lab metrics now use the existing read-only yield
path; measuring a round must leave its canonical state untouched.

CPU speedups are measured around authoritative `pump` / `advance` calls only,
with alternating backend call order. They exclude initialization, hashing,
observation/metrics checks and trace conversion. Two comparison workers run
concurrently, so these are paired workload timings, not isolated sustained
throughput or thermal benchmarks. Do not multiply them by historical worker
scaling numbers. Native CraftOS parity remains a separate requirement.
