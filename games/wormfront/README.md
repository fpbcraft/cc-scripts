# WORMFRONT v0.2 — Tactical Artillery

A lightweight, original Worms-inspired game for **CC:Tweaked**. Two to four
teams battle with three worms each across procedurally generated, destructible
landscapes. Compatible with **local hotseat** or **rednet multiplayer** on the
same wired or wireless modem network.

## Install the feature branch

Run this command **on each participating computer** before the PR merges:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/codex/wormfront-multiplayer/installers/wormfront.lua codex/wormfront-multiplayer
```

After merge, the regular command is:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/wormfront.lua
```

## Start

- Single terminal, 2–4 hotseat teams:
  `/games/wormfront/main.lua local 2`
- Create a remote match:
  `/games/wormfront/main.lua host`
- Join from each separate ComputerCraft computer:
  `/games/wormfront/main.lua join`
- If multiple hosts exist:
  `/games/wormfront/main.lua join <HOST_ID>`

The host presses **START** once 2–4 players are connected. A disconnected
player can rejoin from the **same computer ID** as long as the host is still
running. Different Minecraft servers do not automatically connect through
rednet: an external relay is outside this release.

## Gameplay

- Each team gets three worms with 100 HP.
- **45-second turns** tick in real time on the authoritative host, independent
  of how many movements a player makes.
- **Walking:** as many steps as time permits, with small slope climbing.
- **Jumping:** forward ballistic leap with gravity, optional air steering.
- **Aim:** change the barrel angle in 3-degree increments; a visible barrel,
  angle readout and protractor ticks indicate direction.
- **Power:** hold Space to charge, release to shoot. A moving bar shows charge
  progress up to maximum power in 1.8 seconds. On touchscreens, tap **CHARGE**
  once to begin and **RELEASE** once to launch.
- **Wind** affects the rocket's flight; projectiles visibly arc over terrain.
- Rocket ammo is unlimited. Each worm starts with two **MEGA** shots, which
  have a larger blast radius.
- **Random crates** can contain a 30-HP medkit, another MEGA round or a
  damage-reducing shield. Crates appear at match start and over subsequent
  rounds and can be collected by walking or jumping into them.
- The last surviving team wins. Falling into deep holes can eliminate worms.

### Controls

| Action | Advanced Monitor | Keyboard |
| --- | --- | --- |
| Walk left/right | LEFT / RIGHT | Left / Right (hold) |
| Rotate barrel | AIM - / AIM + or tap battlefield | Down / Up (hold) |
| Jump | JUMP | J |
| Change active worm | WORM | Tab |
| Choose weapon | WEAPON | W |
| Charge / shoot | CHARGE then RELEASE | Hold Space, then release (or F twice) |
| End turn without a shot | PASS | Enter |
| Exit | EXIT | Q |

The controls disable battle actions on spectators' screens or out-of-turn
players. Remote players see the same real-time projectiles and explosions.

### Graphics and hardware

The game **automatically sets an attached Advanced Monitor to text scale 0.5**
before initializing the shared FPB pixel canvas, and restores its previous
scale on exit. It chooses the largest monitor automatically.

The updated graphics include four themed randomized battlefields, layered
terrain, background clouds and hills, helmeted worms with team colors and
health bars, aiming guides, animated projectiles and smoke trails, and
multi-stage explosions. Animations use the event/timer loop; no animations
are played synchronously inside input callbacks.

Native CraftOS-PC pixel graphics are supported when available; regular
text-mode computers use the existing virtual terminal fallback. A large
Advanced Monitor is recommended to see fine sprite details.

## Architecture and limitations

`sim.lua` owns authoritative rules and time-stepped projectile/jump physics.
`ui.lua` renders the pixel battlefield and normalizes pointer input using
`lib/fpb/canvas.lua`. `main.lua` runs the event loop, host, client, and hotseat
modes. Host state is sent approximately every 150 ms to all clients and
validated actions are applied only on the host.

For this first expanded edition there are no saved or persistent matches,
ropes, terrain editor, matchmaking service, or support for reconnecting from
a different computer ID. Animations and performance should be verified on a
real multiplayer CC:Tweaked monitor setup before merging.

## Tests

```sh
lua5.3 tests/wormfront_test.lua
lua5.3 tests/wormfront_ui_test.lua
lua5.3 tests/wormfront_installer_test.lua
make style-check
```
