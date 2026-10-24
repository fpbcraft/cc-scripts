# FPB runtime library and package layout

`packages.lua` owns source paths, installed roots, entrypoints, code file lists,
required library modules, persistent data, startup defaults and Store metadata.
A source file has one canonical implementation. Small app-local adapters preserve
existing display/render/auth APIs while forwarding to this library.

## Modules

- `display` — monitor/native pixel/virtual text selection and pointer routing.
- `terminal_view` — scrollable terminal viewport for large game layouts.
- `canvas` — existing low-resolution IRONSPIRE/RAILBREAK drawing API.
- `auth` — existing HMAC-SHA256 and paired factory protocol authentication.
- `loader.environment(root, parent, entry)` — isolated globals and module cache.
- `loader.run(root, entry, parent, ...)` — load and execute a program in that scope.
- `installer.install(id, ref, args)` — manifest-driven download and activation.

Installers bundle required modules at `<program>/_lib/fpb/`; programs never depend
on another app's copy. Library changes must update this source, not generated
installed copies. Basalt remains a dependency of factory and airship only.

## Installer behaviour

Each standalone bootstrap validates its ref, resolves `main` when possible, then
downloads the engine. The engine downloads the manifest and every program/library
file from the same ref, checking HTTP responses and Lua syntax before activation.
Without the GitHub API it uses cache-busted branch downloads; those cannot offer
an immutable snapshot if the branch changes during installation. Pass a commit
SHA when an immutable revision is required in that environment.

Games, Store and airship use staging plus code-file rollback, including failed
RAILBREAK/IRONSPIRE boot checks. Factory and node retain their low-disk policy:
download and validate code in memory, then replace one file at a time without
backups. A disk failure during that replacement may require rerunning the installer.
Basalt is reused when already installed, and installed on first use otherwise.
Unknown files and saves are never removed by code updates.

Startup is only replaced when absent or recognised as that program's generated
launcher. Unrelated startup is retained; factory/node refuse installation when
an enabled startup would conflict. `--no-startup` leaves it alone.

## Migration

Layout v2 maps `/cogworks`, `/railbreak`, `/shattered`, `/ironspire`, `/civcraft`
to `/games/<id>`, and `/fpb-airship`, `/fpb-factory`, `/fpb-node`, `/fpbstore`
to `/apps/<id>`. Manifests allowlist each program's save/config paths. SHATTERED
also checks `/tidebound`; airship retains migration from computer-root pilot files.

Before code activation, compare all known source files to destination files.
Identical files are safe; conflicting contents or file/directory types stop the
install with an actionable path. Copy only missing data and retain all originals.
A `.layout-v2` marker prevents later reinstalls from importing stale legacy data.
Store installation records do not make an old-path game count as installed.
Old program roots, shortcuts and custom launchers are left for manual cleanup.

A remaining `.install-backup` directory indicates an interrupted staged install.
The installer refuses to discard it. Restore its files into the program root
before retrying; keep saves and unknown files. Normal activation failures roll
back automatically. No live server or computer is modified by repository changes.

## Validation

CI syntax-checks all Lua and runs `tests/*_test.lua` in fresh Lua processes, plus
the game-specific workflows. The CraftOS disk/HTTP harness executes real
bootstraps, manifests, installed loaders and package-free Store flows.

Three older SHATTERED test entrypoints (`tests.lua`, `tests/ai_only.lua` and
`tests/simulation.lua` inside that game) already target removed historical
editions on the pre-refactor main branch. They are retained with the game;
`games/shattered/tests/v5.lua` is its maintained regression suite.
