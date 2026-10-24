# FPB Store

Small standalone app store for games in [fpbcraft/cc-scripts](https://github.com/fpbcraft/cc-scripts). Compatible with CC:Tweaked and CraftOS-PC / CraftOS iOS. It works on a normal computer terminal, including without an attached monitor.

## Install once

Run this on your computer (HTTP must be enabled):

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-fpbstore.lua
```

Then open it any time with `store` (or `/fpbstore/main.lua`). The installer installs a permanent `/store.lua` launcher **without overwriting an existing, unrelated launcher**.

## What you can do

- Browse **COGWORKS**, **RAILBREAK**, and **TIDEBOUND**. Games already installed through their own installers are detected automatically.
- Install a missing game with its existing, tested, one-command installer.
- Update any installed game by running the current repository installer again, without changing its save data.
- Launch a game and return to the store after the game exits.
- Remove an installed game's known application code without deleting its saved progress.
- Update the store itself to fetch new catalog entries and fixes.

**Mouse/touch:** click game rows to select, then use INSTALL/UPDATE, PLAY, REMOVE or STORE UPDATE. **Keyboard:** up/down chooses a game, Enter installs/updates, Space plays, Q/Escape quits. Each removal asks for confirmation.

### Safe by default

- **Uninstall preserves saves.** Saved worlds, board progress, settings, custom files and unknown files are not deleted. This intentionally leaves empty directories behind.
- No automatic startup is added. The store tells each game installer **not to modify** existing startup programs.
- Game installers continue to stage and validate downloads and roll back errors independently.
- Store updates also stage all source files before activating, keeping the launcher and its local metadata intact.
- If any game has an autostart script elsewhere on the computer, disable that autostart before removing it.

### Adding future games

Edit `fpbstore/catalog.lua` and append a catalog item containing a unique id, display name, installed entry point, installer filename, and an **explicit list of managed application files**. Never include save files or data directories in the managed list. The store UI automatically renders new catalog items without hard-coded additional buttons.

An update is an on-demand reinstall from the latest configured repository revision; the store currently does not query remote commit hashes for version comparisons. The **UPDATE** action is available for every installed game.

## Files

- `/fpbstore/main.lua` — interactive storefront.
- `/fpbstore/catalog.lua` — app catalog.
- `/fpbstore/manager.lua` — installer/launcher/removal logic.
- `/fpbstore/installed/` — store-managed install metadata.
- `/store.lua` — permanent shortcut.

Existing /cogworks, /railbreak and /tidebound saves are preserved.

## Optional Basalt 2.5 storefront

FPB Store now detects an installed Basalt 2.5 framework and uses a responsive,
touch-enabled Basalt catalog screen when available. Without Basalt, its built-in
terminal interface still works. To install Basalt, use the official command:

```lua
wget run https://basalt.madefor.cc/2.5/install.lua minified
```

This installs a `basalt.lua` module; make it importable on the CraftOS Lua
module path (for example at `/basalt.lua`). The Basalt frontend currently
handles catalog selection and app actions; the games' specialized gameplay
renderers are retained. Basalt is optional, not a requirement to install games.
Use `/fpbstore/main.lua --classic` to force the original storefront.
