# Lua regression test selection

The required **CC Lua quality / test** check now runs affected regression tests on
pull requests, with a full suite on pushes to main, nightly (06:15 UTC) and on
manual dispatch. Lua syntax, formatting and linting remain unconditional.

## Local preview

From the repository root:

```sh
python3 -m unittest discover -s scripts -p 'test_ci_lua_select.py' -v
python3 scripts/ci_lua_select.py --changed games/civcraft/ai_tactics.lua
python3 scripts/ci_lua_select.py --changed games/cogworks/render.lua
python3 scripts/ci_lua_select.py --changed README.md
python3 scripts/ci_lua_select.py --full
```

The JSON plan explains which tests were selected, why, how many shards are
needed, and whether the plan is a full run. It is safe to inspect even without
Lua installed. To run a selected plan use:

```sh
python3 scripts/ci_lua_tests.py --shard 0 --shards 1 --selected-json '["tests/core_test.lua"]'
```

## Selection rules

- **Documentation-only PR:** skip regression jobs, still run selector tests and
  full-repository Lua syntax and style checks.
- **Application Lua changes:** find every test that transitively imports the
  changed Lua file through literal `dofile`, `require`, etc. Inspect tests
  across all applications, not only those with a matching filename prefix.
- **High-impact application modules** (`ui.lua`, `render.lua`, `systems.lua`,
  `game.lua`, `world.lua`, etc.), dynamic imports, binary assets, deleted or
  otherwise unresolved application files: run *every* test for that application.
- **Shared modules, test support, workflows, build/CI tools, unknown paths or
  failed Git diffs:** fall back to the complete regression suite.
- **Direct changes to individual `*_test.lua` files:** run those tests.
- **All non-documentation PRs:** additionally run inexpensive core, loader and
  package smoke tests.

Test selection uses a full checkout and compares the GitHub PR base SHA with
the checked-out merge commit; renames expose both paths. Test execution remains
deterministically cost-balanced. Small plans use one worker; larger plans use
more. CivCraft's controls suite always uses nine workers to spread its 18 screen
combinations across the same nine workers as before.

**Safety limitation:** static Lua import analysis cannot prove that arbitrary
global variables, runtime paths or generated code have no hidden dependents.
The application-level and full-suite fallbacks intentionally over-select.
In particular, changes to application files whose direct imports cannot be
resolved broaden selection rather than treating zero hits as safe. Nightly and
main-branch full runs catch any remaining cross-system interactions.
