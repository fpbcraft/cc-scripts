# WORMFRONT v0.3 — Artillery and ninja rope

Original lightweight Worms-inspired game for CC:Tweaked and CraftOS-PC. Supports
2–4 players, with three worms per team, locally (hotseat) or over rednet modems.
Install from FPB Store or use the repository's one-command installer.

## Install

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/codex/wormfront-arsenal-rope/installers/wormfront.lua codex/wormfront-arsenal-rope
```

Once merged, use the regular `main` installer. On each client use the **same
revision** of the game; v0.3 uses its own rednet protocol.

```sh
/games/wormfront/main.lua local 2
/games/wormfront/main.lua host
/games/wormfront/main.lua join
```

The host starts a 2–4 player session. Everyone needs a modem or a correctly
connected wired modem network. Only the host simulates combat and turn timing.

## Gameplay

- 45-second timed turns; no movement quota
- **Sequential team worm order**: each time a team gets a turn it receives the
  next living worm in roster order. Players cannot manually switch worms.
- Each team's initial inventory contains **only unlimited BAZOOKA**.
- Collect random **WEAPON** crates to unlock other equipment and ammunition.
  Weapon stocks belong to teams, so later worms share the ammo collected.
- Medkits restore 30 HP; shields reduce the next damage event.
- Large 144×60-cell destructible maps with themed hills, elevated platforms and
  a camera which follows the active worm or projectile.
- Wind changes gently per turn (−3 through +3), deflecting thrown and fired
  projectiles. The HUD shows its current value.
- Projectiles animate; explosions carve craters and can knock worms into the air.
- A physics-based **ninja rope** attaches to solid terrain, swings with
  horizontal controls, reels in/out, and detaches using the rope or jump key.

## Weapons

| Weapon | Initial stock | Stock from a weapon crate | Behavior |
| --- | --- | --- | --- |
| Bazooka | Unlimited | N/A | Wind-affected explosive rocket |
| Grenade | 0 | 3 | Bouncing, timed explosive |
| Dynamite | 0 | 1 | Close-range timed heavy explosive |
| Baseball Bat | 0 | 2 | Short-range damage and knockback |
| Air Strike | 0 | 1 | Five explosions around a chosen horizontal position |
| Minigun | 0 | 1 | Eight rapid shots |
| Mine | 0 | 2 | Placed proximity-triggered explosive |
| Fire Punch | 0 | 2 | Short-range uppercut knockback |
| Handgun | 0 | 3 | Two accurate direct-hit bullets |
| Petrol Bomb | 0 | 2 | Explosive impact and lingering fire |

Special weapon ammo is consumed when used. No special weapons are preloaded.
Crates appear throughout a match, rather than giving every worm its own stock.

## Controls

| Action | Keyboard | Advanced Monitor |
| --- | --- | --- |
| Move / rope swing | Left / Right (hold) | LEFT / RIGHT |
| Aim | Up / Down (hold) | AIM − / AIM + or touch world |
| Charge & fire | Hold/release Space | CHARGE then RELEASE |
| Jump / detach rope | J | JUMP |
| Rope attach / detach | R or T | ROPE then touch a terrain anchor |
| Reel rope | Page Up / Page Down | REEL − / REEL + |
| Open weapons | W cycles unlocked weapons; number keys 1–0 choose slot | ARMS menu |
| Target air strike | Touch world | Touch battlefield |
| End turn | Enter | PASS |
| Quit | Q | EXIT |

The weapon menu marks locked weapon entries unavailable. Number 0 is the
tenth weapon. Use the same computer ID to reconnect after a disconnection.

## Graphics and performance

Attached Advanced Monitors automatically switch to **0.5 text scale** before
pixel graphics initialization, restoring the previous scale on exit. The game
also uses CraftOS-PC graphics mode if supported.

The renderer follows the camera rather than drawing all 144×60 tiles, batches
terrain columns, and caps frame updates at about 6 fps. Input and network
events do **not** issue immediate full-screen redraws; this addresses flicker
while typing or holding down movement/aim keys.

## Tests

```sh
lua5.3 tests/wormfront_test.lua
lua5.3 tests/wormfront_ui_test.lua
lua5.3 tests/wormfront_installer_test.lua
make style-check
```

Monitor-specific rendering, frame cadence, and multiplayer latency should
still be checked on real CraftOS-PC and CC: Graphics hardware. This edition
does not include match saves, cross-server relay, or full Worms physics.
