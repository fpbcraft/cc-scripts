# Cogworks — discovery campaign, version 7

This campaign replaces all 64 starting boards in the eight-district factory.
It uses literal authored data rather than transformed seed puzzles. The
mechanical rules, branching map, editor and custom packs remain compatible.

## Design and pacing

The intended audience is experienced puzzle players. The opening two puzzles
establish controls and gearbox behavior; later discovery stages are compact
breathers between harder combinations, repair tasks and optional expert nodes.
The engine accepts any mechanically valid construction, including unexpected
solutions. A reference is evidence of solvability, never a required recipe.

Each level carries a stable ID, a designer-only insight, a documented failed
approach and its reproducible counterexample. Remixes explicitly name their
source. Fixed machinery provides useful infrastructure, a spatial constraint,
or an intentionally disconnected return path. For example, level 39 changes
the axis of an installed return shaft; the previously unsafe bridge becomes
useful. Levels 36 and 53 deliberately revisit the same completed assembly as
an omission puzzle and a repair of an overconnected starting gearbox.

The method draws on interaction-driven design and meaningful variations in
[Patrick Traynor's puzzle-design strategies](https://cwpat.me/misc/puzzle-level-idea-strategies/),
and layered challenge with periodic relief in the
[Ludaxis level-design guide](https://www.ludaxis.io/blog/level-design-puzzle-games-guide).
Board size and shaft length alone do not justify another puzzle.

### Districts

1. **The Apprentice:** axial versus tooth transmission, branching, parity and compatible connections.
2. **Impossible Routes:** competing approaches, fixed infrastructure and spatial reinterpretation.
3. **Unexpected Motion:** reductions, multiplication, parity and separately compensated clock branches.
4. **Transmission Tricks:** chain distribution, pulley landings, shaft crossings and mixed approaches.
5. **Tangled Machinery:** shared feeds, return paths, selective separation and compact multi-output networks.
6. **The Control Room:** routing signals, mechanical alternatives, selective shifts and clutch isolation.
7. **The Repair Shop:** fault diagnosis, correcting overconnections and reusing installed assemblies.
8. **The Grand Factory:** synthesis, reciprocal clocks, constrained distribution and selective controls.

The existing navigation graph is unchanged: any three distinct main clears
open the next district. Replays and medals do not contribute additional clears.
Expert node 7 and finale node 8 remain optional. Ponder offers every available
mechanism on entry and filters lessons using the slot's seen flags, so skipping
a discovery node cannot leave a required rule unexplained.

## Inventories and optional redesigns

Stock is explicit per level and independent of all reference constructions.
Every normal reference leaves supplies unused. Alternative parts have credible
uses; fixed fixtures are excluded from movable-part budgets.

The campaign has **66 bonuses**: seven stages have none, 48 have one, and nine
have two. Bonuses are independent and permanent; they may be earned on separate
builds and never block progression. Move limits, cleanliness and full-stock
quotas are absent from this campaign.

Shipped challenge families are:

- **Part restrictions and budgets:** omit a movable part family or meet an explicit per-kind count.
- **Clear corridors:** leave an identified cell empty and find a different feed.
- **Useful mounts:** a press must stop if the component at the marked cell is removed.
- **Functional transmissions:** a press must depend on a belt, chain link or diagonal cog contact.

Transmission checks evaluate the actual powered graph and temporarily exclude
the candidate link. Useful mounts evaluate a view without the marked component.
A decorative powered spur cannot earn either reward. These analyses do not alter
the live board and are cached for animation frames until a new game evaluation.

Every bonus has a certified winning witness; every normal witness misses all
bonuses, including intermediate placement and rotation states. This establishes
a concrete separation between normal clears and optional redesigns. It does
**not** establish that every player's first construction will miss a bonus;
a player may discover a stronger construction immediately, which is welcome.

Marked cells have outlines on graphics boards and A/B labels in text mode.
Counters remain visible beside objective labels. Tap an objective for its exact
rule in the status line; larger graphics layouts also show the rule below it.

## Data and reproducible validation

`campaign/district_1.lua` through `district_8.lua` are the source of truth.
Each level includes its starting fixtures, target ports/rates/spins, obstacles,
initial editable machinery, explicit stock, main construction and independent
solution snapshots. Designer notes and witnesses are not included in briefings.

`witnesses.play(number, name)` replays a construction through placement,
clockwise rotation, removal and control actions using the real inventory.
Names are `normal`, `alternate`, `other` where present, `misconception`, or an
objective ID (`extra1` / `extra2`). Starting-part removals run before placements,
so repairs may replace a faulty component in the same cell. Ordinary snapshot
restoration retains the resulting electrical and mechanical state.

Automated coverage includes 64 main clears, 62 alternate clears, nine further
bonus builds, 64 legal failed approaches, all 66 bonus predicates and save/restore
of bonus solutions. It also checks normal-build prefixes, decorative-path
exploits, fixed machinery, optional map routes, lesson availability, migration
failure modes, renderer bounds, hit targets and installer manifests.

Run `lua5.3 tests/cogworks_campaign_design_test.lua` and
`lua5.3 tests/cogworks_bonus_witnesses_test.lua`, or every
`tests/cogworks*_test.lua` regression.

The isolated CraftOS-PC session in `tests/cogworks_craftos_session.lua` also
replays the seven pilot puzzles (04, 09, 20, 28, 44, 49 and 64) through actual
renderer hit targets and controller actions. The final campaign passed 20
builds and 469 actions in both native graphics and the text viewport. These
scripted interactions and inspected graphics are runtime validation, not blind
human discovery testing or a Minecraft deployment test.

## Save migration

Campaign version 7 starts old campaign slots fresh. Before replacing a slot,
the storage layer copies and verifies its original bytes in
`slot-N.dat.campaign-v6` (or the corresponding older version). Unknown or
undecodable versions use `campaign-vunknown`. Archive creation, verification,
rename or existing-archive mismatch failures prevent overwriting the slot.
Permanent archives are never silently replaced. Settings, custom packs and
user-authored levels are preserved; the legacy `save.dat` remains untouched.

## Human validation boundary

Simulator certification proves the supplied constructions, failures and bonus
checks. It cannot prove subjective difficulty, surprise, pacing or the quality
of an expert player's first solution. Blind human playtesting and Minecraft
Advanced Monitor validation remain separate acceptance work; do not describe
them as completed on the strength of automated tests or rendered previews.

## Designer index — contains solution ideas

The following insights describe the current boards, not unimplemented proposals.

| Level | Puzzle | Intended realization | Bonuses |
| --- | --- | --- | --- |
| 01 | FIRST POWER | Facing shaft ends transmit without changing rotation. | 0 |
| 02 | AROUND THE CORNER | A gearbox both turns a route and reverses its output. | 0 |
| 03 | NOT THAT SIDE | An axial cog can supply its shaft and its toothed rim separately. | 1 |
| 04 | THE MISPLACED COG | The far cog can be driven through either its axle or its rim; changing the feed changes both outputs. | 2 |
| 05 | THE OTHER DIRECTION | Reverse before the installed cog or after it; the old feed has the wrong parity. | 2 |
| 06 | LESS IS MORE | A fourth gearbox closes a contradictory circuit; replacing the branching junction with a straight shaft makes a different feed possible. | 1 |
| 07 | THE COG WAS NEVER MISPLACED | Diagonal mixed-size contact changes both speed and approach geometry. | 0 |
| 08 | APPRENTICE EXAM | A tooth branch and a gearbox branch can share one cog without sharing a reversal. | 1 |
| 09 | BLOCKED PASSAGE | A pair of turns preserves spin, but two cog contacts can also cross the offset. | 2 |
| 10 | THE WRONG CORNER | The fixed junction reverses every branch; the return corner reverses only one of them. | 1 |
| 11 | A TIGHT SQUEEZE | A cog can continue axially while its rim supplies a second output of opposite sign. | 1 |
| 12 | THE UNMOVABLE GEAR | The fixed cog supplies two exits; reversing the shared input changes both repairs. | 1 |
| 13 | CROSSROADS | A missing link can protect two useful branches from a contradictory loop. | 1 |
| 14 | THE DETOUR | Two tooth reversals after one corner are wrong; choose the side contact that cancels the corner. | 1 |
| 15 | BLOCKED PASSAGE? | The sealed route can be replaced by two meshes around the other side of the obstruction. | 1 |
| 16 | WAREHOUSE RENOVATION | Each installed junction offers a different sign; an extra reversal must be confined to the right branch. | 1 |
| 17 | TOO FAST | The receiving cog size, rather than path length, determines the reduction. | 0 |
| 18 | DOUBLE TIME | A large driver and small follower reverse the reduction without changing the motor. | 1 |
| 19 | THE DIAGONAL TRICK | A mixed-size diagonal contact can change axis as well as speed. | 1 |
| 20 | TWO CLOCKS | Split the shared trunk before the ratio change, or scale first and compensate one branch. | 2 |
| 21 | SPEED, WRONG DIRECTION | Equal-size meshing changes parity without changing an already correct gear ratio. | 1 |
| 22 | THE FEEDBACK TRAP | An attractive shared mesh feeds the normal-speed trunk back at twice its rate. | 1 |
| 23 | MIRROR CLOCKS | The familiar fast branch must reverse which wheel is driver; copying the earlier assembly fails. | 1 |
| 24 | CLOCKMAKER CERTIFICATION | Each rate belongs on its own side of the common trunk, while corners account for the final sign. | 1 |
| 25 | LINKED TOGETHER | Sideways chain links distribute motion without the reversals imposed by gearboxes. | 0 |
| 26 | OVER THE GAP | A belt can relocate a shaft while preserving its axis and spin. | 2 |
| 27 | CLOSE COUPLING | Adjacent pulleys work; a third pulley interrupts the longer connection and becomes a new relay. | 1 |
| 28 | CROSSING THE LINE | A shaft can cross a moving belt without joining it; replacing the crossing with a gearbox severs the span. | 2 |
| 29 | CHAIN REACTION | A chain row can supply sideways links and axial outputs at the same time. | 1 |
| 30 | ABOVE AND BELOW | Relocate the unconverted shaft first, then choose separate ratio changes at each destination. | 1 |
| 31 | OVER THE GAP? | A crossing may sit inside the belt run, but an occupied pulley landing needs a different axis. | 1 |
| 32 | TRANSMISSION ENGINEER | A chain branches near the motor, leaving a belt to carry one rate across another route. | 1 |
| 33 | BRANCH OFFICE | Sharing the trunk saves routing space, but the tooth branch reverses only one destination. | 1 |
| 34 | THREE DIFFERENT DIRECTIONS | One tooth branch can reverse two destinations together; separate reversal devices waste the useful junction. | 1 |
| 35 | SHARED INFRASTRUCTURE | A chain can distribute equal spin while a gearbox distributes reversed spin; choose where each belongs. | 1 |
| 36 | THE UNWANTED LOOP | Keep the return bridge absent: the gearbox pair and the tooth contact disagree about the same shaft. | 1 |
| 37 | MIXED SPEED FACTORY | The same large cog can be a follower on one branch and a driver on another. | 1 |
| 38 | NO DEAD MACHINERY | A powered salvage piece is not necessarily useful; the chosen feed must reach its output. | 1 |
| 39 | ONE MORE CONNECTION? | The changed fixture axis interrupts the return connection; the previously jamming bridge now supplies the far press. | 1 |
| 40 | DISTRIBUTION DIRECTOR | The second junction reverses only half the outputs, while a chain preserves a third branch. | 1 |
| 41 | THE REVERSE LEVER | An electrical reversal can replace a mechanical reversal without moving the shaft. | 0 |
| 42 | WIRE IT UP | A dust route may turn, but cannot share cells with a mechanical route. | 1 |
| 43 | EMERGENCY STOP | Powering a clutch removes one contradictory link while leaving both useful outputs supplied. | 1 |
| 44 | TWO DIFFERENT COMMANDS | A shared redstone net is convenient but wrong when only one branch needs reversal. | 2 |
| 45 | SIGNAL ROUTING | A forked signal saves wiring, but its junction must stay away from an isolation clutch. | 2 |
| 46 | NORMALLY OFF | Removing a control signal can restore motion; more electrical power is not always progress. | 1 |
| 47 | ONE BLOCK TOO MANY | Move the active signal to the other branch rather than powering both. | 1 |
| 48 | CONTROL ENGINEER | A common mechanical trunk can require separate electrical nets downstream. | 1 |
| 49 | ONE MISSING GEAR | A plain shaft restores only one press; a cog at the shared socket restores two different rotations. | 2 |
| 50 | REVERSED INSTALLATION | Correct the sign before the ratio stage or after it; changing wheel sizes fixes the wrong problem. | 1 |
| 51 | MECHANICAL JAM | Break the feedback mechanically or disable its clutch electrically, preserving the useful branches. | 1 |
| 52 | FAULTY CONTROLS | Repair electrical routing before replacing correctly oriented mechanical parts. | 1 |
| 53 | A BAD REPAIR | An overconnected replacement gearbox closes a contradictory loop; an axial shaft restores the useful branch without the cross-connection. | 1 |
| 54 | SALVAGE OPERATION | A belt can feed a salvaged ratio stage from a different shaft without disturbing its geometry. | 1 |
| 55 | FACTORY BLACKOUT? | Removing electrical power restores a clutch while a separate gearshift still needs a signal. | 1 |
| 56 | CHIEF MECHANIC | The shift controls one branch while the ratio stage supplies a different branch from the same junction. | 1 |
| 57 | FOUNDRY RESTART | Distribute normal rotation first, then localise reversals and speed changes at the machines. | 1 |
| 58 | THE CLOCK TOWER | Two ratio stages can share a driver, but their reversals and approach directions remain independent. | 1 |
| 59 | CRANE BAY | Moving the belt landing can replace a crossing, but changes how the shaft enters the distant press. | 1 |
| 60 | THE PISTON CHOIR | Two neighbouring junctions can supply a whole choir; each added junction changes which outputs reverse. | 1 |
| 61 | MINIMUM MATERIALS | The shorter geometric route consumes more reversals; one shared side transmission handles two outputs. | 1 |
| 62 | THE OVERRIDE CIRCUIT | A shared electrical network must route around the device it would accidentally reverse. | 1 |
| 63 | THE INCOMPLETE BLUEPRINT | The old shared distribution must split before the speed change, not after it. | 1 |
| 64 | THE GRAND COMMISSION | A functional crossing lets the ratio stage and the controlled shaft coexist without merging their rates. | 0 |
