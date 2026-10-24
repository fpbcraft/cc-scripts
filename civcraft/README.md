# CIVCRAFT — Networked Pocket Civilization

A small Civilization-inspired, turn-based 4X game for **CC:Tweaked**. One computer hosts the authoritative match; **2–4 human players** each use their own computer and optionally an Advanced Monitor. Computers communicate through **rednet modems**, either wireless (within range) or wired (via the same wired modem network). It also works over interdimensional wireless modems. No HTTP or external web server is needed after installation.

## Install on every participating computer

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-civcraft.lua
```

On the host:

```sh
/civcraft/game.lua host
```

On each client:

```sh
/civcraft/game.lua join
```

The join command discovers a hosted game automatically. If discovery fails or multiple hosts exist, use `/civcraft/game.lua join <host-computer-ID>`. The lobby shows the host ID. Connect 2–4 players, then tap **START GAME** on the host. Players are identified by ComputerCraft computer ID; use fixed dedicated machines if you intend to resume saves. The host also plays.

For a clean new match, explicitly run `/civcraft/game.lua host --new`. This deletes the existing match save. Simply reinstalling will **not** delete saves. To opt into host autostart for a dedicated computer, add `--startup` to the installer command; it will not overwrite an existing startup script.

## Gameplay

The map is a 12×8 continent grid: `.` plains, `f` forest, `^` mountain, `~` water; mountains and water block movement. Your settlements and units are coloured by player. `C` denotes a city, `W` a warrior, and `S` a settler. Touch a tile to select it.

- **Cities:** Each city produces 2 food, 2 wood, and 1 science at the end of a full round. Technology boosts food and science production.
- **Warriors:** Recruit for 5 wood at an unoccupied city. Select one, tap MOVE, then tap an adjacent passable tile. Warriors can defeat an enemy unit or capture an enemy city.
- **Settlers:** Recruit for 8 food and 8 wood at an unoccupied city. Move to unoccupied land, then tap FOUND. New cities must be at least 3 Manhattan tiles from another city.
- **Research:** Spend science on up to 3 technology levels (8, 14, and 20 science). These boost city production.
- **Turns:** Each player issues orders independently; actions are applied by the host. Tap END TURN when finished. Only after everyone finishes does production accrue and movement reset.
- **Victory:** Found or capture 5 cities, or have the highest resource/technology/city score after 25 rounds.

A full game should be playable in a short session. The host saves game state to `/civcraft/data/save.dat` after actions and at round boundaries. Clients reconnect using their original ComputerCraft IDs. A player's actions and turn ending are rejected when they aren't registered or have ended their turn.

## Display and modems

Best experienced on a **5×5 Advanced Monitor** at scale 0.5 (a 4×3 monitor can also work). The program selects the largest monitor on each machine, or falls back to a colour-capable computer terminal. Monitor taps and terminal mouse clicks are supported. The visual presentation intentionally uses standard CC colour text, so no graphics mod, Basalt, Pine3D or extra dependency is required.

Each machine needs a peripheral modem for networked play; wired modems need to be part of the same wired network. CC:Tweaked does **not** offer unlimited-range normal wireless networking—distance and dimensions matter.

## Implementation notes

The host maintains the only authoritative world state, checks unit ownership and resource costs, and broadcasts snapshots. Clients display those snapshots and submit commands; they never directly modify the host state. This is a cooperative local network game, not an adversarial or cryptographically secure network protocol. There is no AI in this first edition. For now, a game requires at least 2 connected human computers to start.

The initial release is intentionally small. Natural next steps are procedural maps, diplomacy, tactical combat, city upgrades, fog of war, AI seats, richer graphics, and reconnect/lobby management.

## Local hot-seat mode (2–4 players, one computer)

Run `/civcraft/game.lua local`. From the lobby, add or remove participants (two to four), then start the match. Each player uses the same screen and passes it along after pressing **END TURN**. The handoff screen hides the map and resources until the next player taps **READY TO PLAY**. No modem, rednet, network connection or second computer is required. Hot-seat progress is saved separately at `/civcraft/data/local-save.dat`, so network saves remain untouched. Start a new local match with `/civcraft/game.lua local --new` (which replaces only the local save).

### Updated graphics

CIVCRAFT now uses a pixel-art map, icon-based units and cities, a dark Railbreak-inspired UI, large touch targets, a compact local-player lobby, and a dynamically scaled renderer. The game continues to work in ordinary text terminals without pixel graphics, with fewer visual details.
