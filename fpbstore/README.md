# FPB Store

Small standalone app store for games in [fpbcraft/cc-scripts](https://github.com/fpbcraft/cc-scripts). Compatible with CC:Tweaked and CraftOS-PC / CraftOS iOS. It works on a normal computer terminal, including without an attached monitor.

## Install once

Run this on your computer (HTTP must be enabled):

```lua
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-fpbstore.lua
```

Then open it any time with `store` (or `/fpbstore/main.lua`). The installer installs a permanent `/store.lua` launcher **without overwriting an existing, unrelated launcher**.

## What you can do

- Browse **COGWORKS**, **RAILBREAK**, **TIDEBOUND**, and **CIVCRAFT**. Games already installed through their own installers are detected automatically.
- Install a missing game with its existing, tested, one-command installer.
- Show the installed version and latest catalog version, with **UPDATE AVAILABLE** when a newer version is found. Press **R** to refresh the online version catalog. Existing installations with no identifiable version show `v?` until reinstalled through the Store.
- Update or reinstall any installed game with the existing installer, without changing its save data.
- Launch a game and return to the store after the game exits.
- Remove an installed game's known application code without deleting its saved progress.
- Update the store itself from the **STORE UPDATE** button. Downloads are staged and validated before activation, with rollback on failure; the Store automatically reloads the new code and catalog afterward.

**Mouse/touch:** click game rows to select, then use INSTALL/UPDATE, PLAY, REMOVE or STORE UPDATE. **Keyboard:** up/down chooses a game, Enter installs/updates, Space plays, Q/Escape quits. Each removal asks for confirmation.

### Safe by default

- **Uninstall preserves saves.** Saved worlds, board progress, settings, custom files and unknown files are not deleted. This intentionally leaves empty directories behind.
- No automatic startup is added. The store tells each game installer **not to modify** existing startup programs.
- Game installers continue to stage and validate downloads and roll back errors independently.
- Store updates also stage all source files before activating, keeping the launcher and its local metadata intact.
- If any game has an autostart script elsewhere on the computer, disable that autostart before removing it.

### Adding future games

Edit `fpbstore/catalog.lua` and append a catalog item containing a unique id, display name, installed entry point, installer filename, and an **explicit list of managed application files**. Never include save files or data directories in the managed list. The store UI automatically renders new catalog items without hard-coded additional buttons.

The Store reads version declarations from the latest remote `fpbstore/catalog.lua` (and uses its bundled catalog if offline). The installed version is recorded in the Store metadata after a successful install, or inferred from the game entry-point header for some legacy installations. It never guesses unknown versions. App versions must be updated in the catalog when publishing a new game release; unversioned apps cannot show a reliable update indicator. Checking versions needs HTTP; installs still use the existing safe app installers. **REINSTALL** remains available for installed games even if no newer version is detected.

## Files

- `/fpbstore/main.lua` — interactive storefront.
- `/fpbstore/catalog.lua` — app catalog.
- `/fpbstore/manager.lua` — installer/launcher/removal logic.
- `/fpbstore/installed/` — store-managed install metadata.
- `/store.lua` — permanent shortcut.

Existing /cogworks, /railbreak, /tidebound and /civcraft saves are preserved.
