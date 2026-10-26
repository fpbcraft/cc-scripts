# FPB Store 2

A compact game browser and app launcher for CC:Tweaked and CraftOS-PC/iOS.
The same terminal UI works without Basalt, including shell-less processes.

## Install and launch

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/fpbstore.lua
/apps/fpbstore/main.lua
```

An optional first installer argument selects a Git ref. The Store does not enable
startup by default. Use `--startup` to enable it on a dedicated computer.

Existing users must run the new installer once: old installer URLs and the
`store` shortcut are retired. Store metadata is copied from `/fpbstore/installed`;
reinstall each game to migrate its saves and install it under `/games/<id>`.
Old game code is not reported as installed at the new path.

## Browse and manage games

The catalog includes COGWORKS, RAILBREAK, SHATTERED, IRONSPIRE and CIVCRAFT.
The list scrolls to keep the selected app visible without covering the controls.
The minimum terminal size is 26 columns by 12 rows; resize a smaller terminal
before using actions.

| Input | Action |
| --- | --- |
| Up / Down or mouse wheel | Select an app |
| Page Up / Page Down | Move through a long list |
| Tab or filter buttons | Switch All apps / Installed |
| `/`, then type or paste | Search names, subtitles and genres |
| Enter / Escape while searching | Leave the search field |
| Enter / primary button | Launch an installed game or install a missing one |
| Space | Launch the selected installed game |
| I / Reinstall / Update | Reinstall or update from the app's currently selected source |
| B / Build Source | Choose `main`, a PR number/URL, or a branch name/URL and install it |
| D / Remove | Confirm removal of app code; saves stay |
| R / Refresh | Check the online catalog |
| U / Store Update | Update and reload the Store |
| Q / Escape | Cancel a confirmation or exit |

Mouse clicks and terminal touch events activate rows and buttons. Reinstall stays
available even when no update is known. Offline mode keeps installed games usable.
Errors open a scrollable diagnostic; use arrows or the wheel to scroll, then Enter
or a tap to return. The Store restores its terminal, text mode and palette after
a game returns or fails.

Each launch gets private globals and a private module cache, so two apps can use
different bundled library versions. CIVCRAFT opens in local hotseat mode.

## Catalog and lifecycle

`lib/fpb/packages.lua` is the authoritative manifest and catalog. Register package
files, required library modules, persistent data and presentation there;
`catalog.lua` is a small adapter. Store removal only deletes allowlisted code and
bundled dependencies, preserving saves and unknown user files.

Remote checks fetch the same manifest, resolving each source to an immutable
commit when GitHub's API is available. Installers fetch program and library files
from that revision.

### Installing test builds

Select a game, press **B** (or click **BUILD SOURCE**), and choose **MAIN**,
**PR**, or **BRANCH**. Enter a PR number (such as `52`), a PR URL
(`https://github.com/fpbcraft/cc-scripts/pull/52`), or a branch name
(`feat/cogworks-64-campaign-editor`). Paste is supported. Press **Enter**
or click **INSTALL BUILD**.

The Store records the chosen source and installed commit **per game**.
Reinstall/Update follows that PR or branch until you explicitly select
MAIN again. The game list shows PR or branch builds separately from stable
installs. If a PR or branch moves, Refresh checks its new head, and the
Store offers an update when that game's actual files have changed.

PRs must currently originate from a branch inside `fpbcraft/cc-scripts`
(fork-based PRs are not yet supported). Resolving a PR or branch requires
the GitHub API; if it is unreachable, installation fails without silently
falling back to `main`.

Update availability is based on each game's managed program and bundled
library file identities, not every commit to the repository. Updating the
Store itself or changing another game must not produce unrelated game updates.
Existing installs without this file fingerprint still fall back to version
comparison until they are reinstalled. Self-update uses staged activation and immediately reloads the
installed entrypoint with a fresh module cache.

Store metadata lives at `/apps/fpbstore/installed/<id>.dat`. Unknown installed
versions show `?` until a successful tracked install.
