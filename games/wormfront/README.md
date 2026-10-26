# WORMFRONT — Tactical Artillery v0.1

A small Worms-inspired artillery game for **CC:Tweaked** with destructible terrain.
It supports **2–4 players** over **rednet** on separate computers, or 2–4 local
hotseat players on one computer. Each player has three worms. This is an original,
simplified game with procedural art; no Worms assets are included.

## Install

On every computer that will play:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/wormfront.lua
```

To install the development branch before merge, use **both** the branch URL
and the branch argument:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/codex/wormfront-multiplayer/installers/wormfront.lua codex/wormfront-multiplayer
```

Installations are under `/games/wormfront`. The installer uses the common
FPB manifest engine, stages files, and rolls back interrupted updates.
The game is also listed in FPB Store after that catalog is updated.

## Start a game

**Hotseat, without a modem:**

```sh
/games/wormfront/main.lua local 2
```

You can replace `2` with `3` or `4`.

**Remote, using modems on the same Minecraft server/network:**

1. Attach a wired or wireless modem to every participating computer.
2. On one computer run `/games/wormfront/main.lua host`.
3. On each other computer run `/games/wormfront/main.lua join`.
   If more than one host is available, use `join <HOST_ID>` (the host ID is
   visible in its lobby).
4. When at least two players have joined, the host presses **START**.
   Participants can play on separate Advanced Monitors.

A player can reconnect from the **same ComputerCraft computer ID** by joining
the original host again. Joining with a new computer ID during an active match
is not supported. The host must stay online. The first version does not save
in-progress matches, use accounts, or support internet matchmaking.

rednet works across suitably connected modem networks (including Ender Modems).
It does not automatically connect separate Minecraft servers or emulator
instances on the public internet.

## Controls

| Action | Touchscreen | Keyboard |
| --- | --- | --- |
| Choose another living worm | WORM | Tab |
| Move (maximum four steps per turn) | LEFT / RIGHT | Left / Right |
| Aim in 5-degree increments | AIM - / AIM + | Down / Up |
| Adjust shot power | PWR - / PWR + | Page Down / Page Up |
| Switch between rocket / mega bomb | WEAPON | M |
| Fire and end turn | FIRE | Space |
| Exit | EXIT | Q |

- **Rocket:** unlimited ammunition, small crater, up to 42 damage.
- **Mega bomb:** two per worm, larger crater, up to 60 damage.
- Wind changes between turns and affects projectile flight.
- Splash damage and falling into craters can damage or eliminate worms.
- The last team with surviving worms wins; simultaneous elimination is a draw.
- Weapons are physical projectiles rather than instant hits.

The game automatically selects the largest attached monitor and requests
text scale **0.5**. It also supports CraftOS-PC's pixel-graphics terminal,
plus a simpler text fallback on ordinary computers.

## Technical scope

`sim.lua` is the rules engine; `ui.lua` handles procedural pixel graphics
using the shared FPB canvas, and `main.lua` handles the local and rednet
event loops. The host validates whose turn it is, simulates actions, and
broadcasts the authoritative state. Clients never decide damage or winners.

v0.1 deliberately omits animations, jumping/ropes, item drops, customizable
teams, terrain themes, matchmaking, turn timers, and persistent campaigns.
All display art is original and procedural.

Run `texlua tests/wormfront_test.lua` at the repository root for rules tests.
