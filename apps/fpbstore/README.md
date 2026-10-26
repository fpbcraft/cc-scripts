# FPB Store 2.1

ComputerCraft-native storefront for CC:Tweaked and CraftOS-PC/iOS, using Basalt 2.5 widgets over the 16-color character-cell display. The previous terminal renderer remains a fallback if Basalt cannot load.

## Install

    wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/fpbstore.lua
    /apps/fpbstore/main.lua

An optional installer --startup flag enables autostart. The installer bundles Basalt 2.5. The UI begins with a short five-line animated FPB logo.

## Catalog and controls

Browse Games, Apps, Installed, or Updates. Games: Cogworks, Railbreak, Shattered Expanse, Ironspire, Wormfront, CivCraft. Apps: Airship Autopilot, Factory Control, Factory Node. Details include description, type, version, installed source, destination and launch target.

| Key | Action |
| --- | --- |
| Arrows, wheel, touch | Navigate and select |
| Enter | Open details or confirm a dialog |
| Escape / Q | Return or quit |
| Tab | Next category / build source mode |
| / | Search name, subtitle, genre and description |
| I | Install or reinstall |
| B | Choose main, PR or branch build |
| T | Cycle per-app terminal / monitor / ask preference |
| S | Store settings |
| D | Remove program code while preserving saves |
| R | Refresh update status |
| U | Update and reload FPB Store |

Minimum size: 26 by 12 character cells. Larger monitors show an additional details panel. The compact Basalt UI has Menu, Manage, Install Options, and Opus pages so touch users can reach every action. Native Basalt lists, focusable buttons and one-line inputs support keyboard operation. Search and PR/branch fields offer a paginated on-screen keyboard for monitor-only touch input.

## Installing to a disk

Installation offers the standard computer location plus writable connected disk drives. For example, a game can be installed under /disk/games/cogworks. The installer validates external targets against actual mounted disk paths and retains staged file activation.

The app's install root is recorded in its marker under /apps/fpbstore/installed. Launches, updates, uninstall and status checks follow the recorded root. If a disk is removed, its install is reported as missing without deleting tracking metadata. Reattach the disk to regain access.

Changing an install's destination does not automatically migrate earlier save data or delete previous installs. Save files and unknown user files are preserved. Apps with hardcoded absolute paths may require a fixed local installation.

## Store display vs program launch

Store settings offer Auto (prefer a connected monitor), Terminal, and Monitor (falling back to Terminal when unavailable). The Store automatically sets attached monitors to text scale 0.5.

Every installed program independently supports START ON: TERM, MON, or ASK. On CraftOS-PC, choosing MONITOR automatically attaches a virtual monitor via periphemu.create if no monitor exists. This also works from Opus shortcuts and the legacy launcher. In Minecraft, where periphemu is not available, an unattached monitor cannot be created, and a terminal fallback is offered. Existing monitors are reused; no user-owned peripheral is detached. The Store restores the previous output, graphics mode and palette after launching a program. While using a CraftOS monitor as the Store screen, it temporarily turns off CraftOS\x27s monitorsUseMouseEvents compatibility option so Basalt receives ordinary monitor_touch events, then restores the original setting.

## Opus integration

When Opus is detected via /sys/apps/Overview.lua, FPB Store writes launch entries to /usr/.registry/fpbstore-* and small per-app shims to /apps/fpbstore/shortcuts/. This follows Opus Overview's custom application registry, not its bundled app database. The settings screen toggles Store registration and app registration; the installer has an individual Opus shortcut toggle.

Registrations are refreshed on Store startup, install/remove, and setting changes. They are optional and never required on computers without Opus.

## PR and branch installs

The build picker accepts main, PR numbers/URLs, and branches/URLs. Source selection and the installed revision are tracked per program. File-level fingerprints avoid showing unrelated apps as outdated after a repository-wide commit. Unavailable PR/branch metadata never silently falls back to main. Saves and unknown user files are preserved during reinstall and removal.

Offline installs are not supported, but installed programs continue launching offline. Store updates stage new files and reload a fresh module cache.
