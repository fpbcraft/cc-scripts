# CivCraft roadmap implementation

Source: [design draft v0.9.1](ROADMAP-v0.9.md). Open design choices remain open; proposed balancing values are not confirmed requirements. Work is on `codex/civcraft-roadmap`.

## 01: Shared gameplay rules

Implemented locally:

- `actions.lua` owns gameplay-order validation and execution. Local/remote human requests, AI research/production/staffing/trading/envoys, movement, founding, city strikes and engineer orders use it. Session startup, ready-state transitions and persistence remain in `game.lua`; wilderness monsters keep their separate local-sight rules.
- Settlers have three base movement points, pay one on ordinary land and require positive movement remaining to found. Founding checks ownership, terrain, landmarks, camps and city spacing before consuming the unit. Cavalry difficult-terrain cost is capped at two.
- Valid movement/attack/rail orders wake sleeping units. Invalid orders preserve sleep. The inspector allows orders without a manual Wake step.
- Passive healing requires owned territory; support healing still works outside it.
- `Combat.predict` is pure, includes HP, wall loss, retaliation, deaths and capture, and supplies the result applied by combat resolution. Unit attack previews show predicted remaining HP and walls in the status line.
- No Production preserves project progress and suppresses deliberate-idle reminders. Selecting production resumes saved work.
- The installer package includes the new action module.

Save compatibility: save schema remains version 6. The only new persisted gameplay field is optional `city.productionIdle`; absent means the existing idle/reminder behavior. Existing world terrain, resources, claims, seed and dimensions stay intact. Stored movement budgets are preserved when loading; the new settler allowance applies at the next normal reset and to newly produced units. No migration grants extra movement mid-round. Future world generation and diplomacy changes need explicit independent versions and migration tests before landing.

Validation: new command tests cover human/AI founding parity, failed orders, movement costs, support healing, paused progress and 180 pure combat forecasts. New text/graphics UI checks cover No Production confirmation, sleeping orders and forecast confirmation. Seeded progression scenarios separately exercise expedition-oriented and industry-oriented AI; the mixed-goal campaign now allows an earlier legal Industrial victory after faster expansion. Automated checks do not establish actual monitor performance, live rednet behavior or multiplayer privacy under races.

## Remaining workstreams

02. Biomes, geography, resource eligibility/distribution, wonder spacing and measured larger maps.
03. Sequenced events and event-time observer projections.
04. Smooth movement/combat animation, playback controls and bounded replay.
05. Stable strategic plans, fixed personalities and economic utilities.
06. Threat maps, tactical campaigns, retreat and coordinated support.
07. Hybrid peaceful/war-group turns and declaration transitions.
08. Relations, treaty offers, explicit defense calls and authored conversations.
09. Council elections, resolutions and diplomatic victory.
10. Duration/victory lobby settings, compact graphical research, HUD and factions.
11. AI difficulty variants after the Prince baseline.
12. Save/integration/fuzz/performance/network validation and release metadata.

Remaining foundation concerns: threat highlights and destination scores; exact city-defense forecasts when remote snapshots omit units that contribute to global city strength; event-backed per-segment movement/visibility; live CC:Tweaked verification. Keep hidden unit information out of forecasts instead of exposing authoritative records to clients. Resolve the remote defense rule in the event/snapshot workstream before calling all combat previews exact across clients.

The full roadmap is not complete. Do not treat this first slice as a v0.9 release.
