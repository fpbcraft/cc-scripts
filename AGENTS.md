# Repository agent instructions

These instructions apply to work in this repository. Follow task-specific instructions as well; do not relax existing code quality, safety, or validation requirements.

## Tooling and validation

This is a Lua/CC:Tweaked repository, not a Bun/Node project. Use the existing tools and the commands in the root `Makefile` and `README.md`:

| Task | Command |
| --- | --- |
| Format Lua | `make format` |
| Check formatting | `make format-check` |
| Lint | `make lint` |
| Check formatting and lint | `make style-check` |
| Run a focused standalone regression | `lua5.3 tests/<relevant>_test.lua` |
| Validate the Lua test selector | `python3 -m unittest discover -s scripts -p 'test_ci_lua_select.py' -v` |
| Run a native CivCraft session (requires CraftOS-PC) | `python3 tests/run_civcraft_native_session.py` |

CI also syntax-checks Lua with `luac5.3 -p`, chooses affected `tests/*_test.lua` regressions, and runs application-specific workflows. The Lua formatter is **StyLua 2.6.0** and the linter is **Selene 0.32.0**.

### Validation is mandatory

- After Lua changes, run `make style-check`, a Lua syntax check, and the relevant regression tests before claiming the work is complete. Fix failures or report them clearly.
- For broad or shared-library changes, expand testing to affected games, installers, and integration paths; use the full suite when practical. Do not treat an automatically selected subset as evidence of exhaustive validation.
- For changes to UI/input, loading, installation, saves, networking, or runtime-specific behavior, exercise the appropriate CraftOS-PC or in-game scenarios when available. Describe remaining gaps explicitly.
- Do not claim a test passed solely because code was written or a CI job is expected to run. Distinguish **not run**, **failed**, and **passed** in the PR description.
- If a dependency or emulator is unavailable, say what was blocked and what alternative verification was performed. Do not silently skip required checks.

## Repository architecture

- `games/` — independent CC:Tweaked games such as CivCraft, Cogworks, Railbreak, Shattered, Ironspire, and Wormfront. Follow the individual game's README and existing architecture.
- `apps/` — programs including FPB Store, airship navigation, factory controls, and remote nodes.
- `lib/fpb/` — shared runtime, displays, loader, authentication, and installation infrastructure. **`lib/fpb/packages.lua` is the authoritative manifest** for packaged files, entrypoints, install roots, dependencies, and persistent paths.
- `installers/` — user-facing bootstraps for installing/updating each program from a Git ref.
- `tests/` — standalone Lua regressions, support fixtures, and native CraftOS-PC test drivers. `scripts/` contains the CI Lua test selector and runner.
- `.github/workflows/` — formatting/lint enforcement and Lua or game-specific CI.

Prefer one canonical source for shared functionality, with small adapters where an existing program needs a different interface. When adding, moving, or removing a runtime module, check the package manifest, loader paths, installer, and relevant tests. Treat packaging changes as part of the feature, not as unrelated generated noise.

## Coding and runtime conventions

- Use ordinary CC:Tweaked-compatible Lua (project formatting parses Lua 5.3); do not introduce Luau-only syntax or unsupported runtime APIs.
- Follow `.stylua.toml`: tabs, a 100-column target, Unix line endings, and double-quoted strings where applicable. Use StyLua rather than manually imposing another style.
- Keep changes focused and maintain clear module boundaries. Prefer small, testable functions and reuse established libraries rather than duplicating UI, persistence, or input infrastructure.
- Respect CC:Tweaked constraints: limited terminal/monitor space, event-driven input, peripheral availability, and cooperative execution. Avoid busy loops, unnecessary redraws, and blocking operations that risk `Too long without yielding`.
- For a temporary workaround, place an actionable `TODO:` at the relevant code location and explain any consequential limitation in the PR.
- Commit messages should normally use Conventional Commits (for example, `fix(civcraft): preserve unit selection` or `test(cogworks): cover touch drag`). PR titles remain short, descriptive, and human-readable; do not assume a conventional-title rule is enforced here.

## User-facing behavior and regression coverage

- Test behavior and player workflows, not just implementation internals. Include relevant positive, negative, and regression cases.
- For interface changes, consider small and large screens, text and graphics modes, terminal versus advanced monitor, text scale, coordinate transforms, mouse/keyboard input, and touch-only operation as applicable. Restore altered monitor, terminal, palette, or graphics state after use.
- For networked games or remotely controlled apps, preserve authoritative state and ownership/visibility boundaries; do not expose hidden multiplayer information through UI or prediction helpers.
- For installers and updates, preserve saves, configuration, unknown user files, and prior installations unless a specifically designed and tested migration says otherwise. Test rollback and repeat installation when modifying installation logic.
- For saved-game or protocol changes, consider older versions and migration/compatibility tests. Never silently delete or overwrite user data.
- For factory/machinery control, preserve physical/manual override and fail-safe behavior; do not treat software-only control as a safety mechanism.
- When describing results, distinguish standalone Lua tests, headless CraftOS-PC, simulated monitor tests, actual Minecraft/CC:Tweaked interaction, and physical hardware measurements.

## Pull requests

Write PR titles and descriptions for a human reviewer, not as an agent activity log. The goal is to explain **why the change matters, what it does, and how it was validated**. A reviewer unfamiliar with the task should grasp the purpose and review readiness within about 30 seconds.

### Before writing

- Examine the **actual PR diff against its target (base) branch**, which may be another feature branch in a stacked PR. Do not summarize changes already present in the base branch.
- Read the related issue or task for motivation. Verify that your proposed title, behavior claims, and issue references match the implementation.
- Use `Fixes #123` only when the PR truly resolves that issue; otherwise use `Refs #123` or a descriptive link.
- Verify test results, PR dependencies, limitations, and outstanding work from evidence available in this run. Do not claim independent review, CI success, physical-device testing, or other verification without evidence.

### Description format

Follow `.github/pull_request_template.md`; omit optional sections when they add no value.

1. **Summary:** One or two sentences explaining the problem, outcome, and user impact.
2. **What changed:** Usually 2–5 concise bullets, grouping meaningful behavior and significant design decisions. Focus on observable changes; mention implementation details only when they help reviewers understand the approach or risk.
3. **Testing:** Name meaningful automated tests and manual scenarios, and say what passed, failed, or was not run. Distinguish standalone Lua tests, CraftOS-PC/native tests, actual CC:Tweaked/Minecraft or monitor testing, and performance or balance experiments.
4. **Notes (optional):** Call out stacked-PR dependencies, breaking changes, migration steps, unresolved issues, risks, and next steps when relevant.

Keep ordinary PR descriptions around 100–250 words when practical. Longer descriptions are fine for genuinely complex changes, but keep them scannable with short paragraphs and bullets.

### Writing rules

- Prefer clear, outcome-oriented titles (e.g. `Make city banners and unit badges independently selectable`) over vague titles or implementation logs.
- Lead with the user-visible result, then relevant technical context. Be precise and avoid marketing language or unsupported generalizations.
- Do **not** include agent session IDs, temporary test-profile names, worker dispatch details, thread-limit failures, timestamps, or internal orchestration narratives.
- Omit commit hashes, exhaustive command transcripts, and test run identifiers unless they are genuinely needed for reviewer traceability. Link to CI or detailed evidence when it adds value rather than pasting logs.
- Avoid repetitive assertions that unrelated systems were not changed. Mention unchanged behavior only if it addresses an important compatibility concern.
- Do not hide a meaningful failure or unresolved finding to make the description shorter. State it succinctly in Testing or Notes.
- Do not leave template instructions, empty sections, or placeholder text in the submitted PR.

### When updating a PR

Recheck its current base branch, actual diff, and most recent known validation results. Revise the description when the implementation changes materially, preserve accurate caveats, and ensure it still describes **only this PR's changes**.

A PR description is a review summary—not a transcript, release announcement, or substitute for permanent documentation.
