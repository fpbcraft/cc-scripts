# Cogworks — Discovery-Driven 64-Level Campaign Design

> **Status:** Design specification / proposal only — **not implemented**. Updated October 25, 2026.  
> **Target branch:** `feat/cogworks-64-campaign-editor` (PR #52).  
> **Scope of this update:** Documentation only. The current `levels.lua` still generates repetitive placeholder layouts (notably straight shaft extensions), `chapters.lua` still uses its existing unlock thresholds, and `engine.lua` still awards generic bonus types. Those existing files are **not** representative of the campaign specified below.

## Creative direction

Build a satisfying **Create-inspired mechanical puzzle game** that rewards seeing surprising relationships between familiar parts. Take inspiration from *Baba Is You*'s design process and branched map, **not** from its rule-changing text mechanic:

1. **One revelation per main puzzle.** Start from a sentence describing an unexpected but fair behavior; build the smallest board demonstrating it.
2. **Ideas, not distance.** Longer shafts, more walls, and a larger grid are never enough to justify a new level.
3. **Revisit and subvert.** Recognizable remix levels change one decisive assumption, not just mirror or enlarge the same reference solution.
4. **Good fixed machinery has a purpose.** It may help, obstruct, mislead, or contain a subtle fault. The player cannot simply move it.
5. **Interesting alternative solutions are welcome.** Core wins should permit creative constructions; authored bonuses reward genuinely different engineering strategies.
6. **No undocumented rules or trial-and-error traps.** Introduce mechanics before requiring them; reveal target RPM, direction, jams, electrical state, and powered-path hints.
7. **No timing/reflex puzzles in this campaign.** This is a stable-state mechanical solver. Redstone means block/dust states driving clutch/gearshift behavior, not simulated tick sequencing.
8. **Small is good.** Compact 5×5 and 6×6 boards may appear late when insight matters more than space.

## Chapter anatomy and paths

Each eight-level chapter is a **small branching collection**, rather than a linear ladder of progressively larger puzzles:

| Stage in chapter | Purpose | Node availability |
| --- | --- | --- |
| 1 | Initial discovery; unusually clear insight | Open on chapter entry |
| 2 | Apply the insight under a mild constraint | After stage 1 |
| 3 | Different interpretation / alternative approach | After stage 1 |
| 4 | A twist on the assumption | After stage 2 **or** 3 |
| 5 | New combination or contrasting solution | After stage 2 **or** 3 |
| 6 | Synthesis of earlier chapter ideas | After **any two** of stages 2–5 |
| 7 | Optional difficult remix of a recognizable earlier level | After stage 4 and at least one other chapter clear |
| 8 | Optional chapter examination, without step-by-step hints | After **four** clears among stages 1–6 |

These node conditions are the **design intent**, not current behavior. They prevent a single puzzle from blocking the chapter, preserve deliberate pacing and keep exams available to interested players. Chapters should be a compact blueprint/factory-node map with shaft-shaped connections, not a flat 64-button grid.

### Progress and unlocks

- Each level offers **1 main clear + 2 independent, authored bonuses** (maximum 3 objective points).
- Bonus points are awarded and saved **only after the main goal has been cleared**. Once earned, badges remain earned when the player experiments with other solutions.
- Open the **next chapter** at **at least six points from the current chapter AND at least four distinct main clears from its first six stages**. Either clear all six ordinary puzzles without bonuses, or clear four and earn two bonuses. Stages 7 and 8 are never required. Their points may help meet the six-point requirement, but not substitute for the four basic clears.
- A completed chapter examination earns an additional **non-gating mastery emblem** (not another objective point), so completionists have a separate reason to tackle it.
- The map shows each level's clear badge and two individual bonus markers; the current chapter shows `points / 6` and `main clears / 4`. Locked chapters state **both remaining requirements**, not merely "LOCKED".
- Players may freely replay cleared/open levels; unlocks never regress. A player reaching a later chapter without completing every prior puzzle receives concise mechanic reminders as needed.

**Scoring clarification:** Total earnable objective points across 64 levels = **192**. This is a *proposed local-chapter gating scheme*; the previous cumulative thresholds in `chapters.lua` are placeholders to be replaced when this specification is implemented.

### Mechanical vocabulary, deliberately revisited

- **Early core:** shaft axial ports (I), four-way gearbox (Q), small cog side-mesh (G). One optional first-chapter preview of large cogs (O) is allowed, with its own hint.
- **Speed chapter:** large/small cog 2:1 relationships (O/G), diagonal meshing independent of axis orientation, multiple speeds and competing paths.
- **Transmission chapter:** encased chains (D), adjacent and longer-span belt pulleys (V), shaft crossing a belt *link* rather than occupying a belt pulley cell.
- **Control chapter:** redstone blocks (B) and automatically connected orthogonal dust (R); powered gearshift (Z) reverses, powered clutch (C) disconnects. No overlap with other parts.
- Later chapters synthesize prior vocabulary. Fixed source/targets, fixed mechanical fixtures, immovable obstacles and authored starting redstone may appear where the insight needs them.

**Caution:** The level descriptions below are **design briefs**, not coordinates or certified solutions. Board dimensions and bonus limits labeled `N` must be finalized through editing and solver-backed playtesting. Never claim a proposed puzzle or bonus is solvable until a concrete reference solution passes the engine.

## The 64 level briefs

Every entry specifies an intended *aha moment*, distinctive board/fixture setup, and two deliberately varied bonus candidates. “Fixed” always means player cannot remove, rotate or move the preinstalled piece; fixtures must make the puzzle better, not merely force a detour.

## Chapter 1 — The Apprentice (levels 01–08)

**Puzzle promise:** A small workshop that introduces how connections behave, not progressively longer shaft runs. **Board envelope:** mostly 5×5–6×6. **New emphasis:** I, Q, G; one optional preview of O. **Recognizable variation family:** 04 → 05 → optional 07.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 01 | Discovery | **First Power** — Connect one source to one press. Establish ports, target feedback and the difference between placement and rotation. | 5×5; no fixed extras; one simple path. | Clean Machine; Par ≤ 2 moves |
| 02 | Application | **Around the Corner** — The output is one row away: an axial shaft alone cannot turn the corner. A gearbox redirects it. | 5×5; one corner blocked; gearbox accessible. | Keep It Clear: marked center cell; Under Budget: ≤ 2 placed parts |
| 03 | Alternative | **Not That Side!** — The shaft-facing interpretation of a small cog fails; a perpendicular gear mesh solves the neighboring press. | 5×5; two suggested contact positions. | No New Gearbox; Dual Rotation |
| 04 | Discovery | **The Misplaced Cog** — A fixed small cog occupies the obvious route. Power it from its teeth and make it useful instead of bypassing it. | 5×5; one immutable cog in a choke point. | Use the Mount: marked cell; Restore the Original: fixed cog on powered path |
| 05 | Twist | **The Other Direction** — A recognizable remix of 04: same fixed cog, target's required spin reversed. Repeating 04 is wrong. | 5×5; near-identical silhouette, adjusted target and stock. | No New Gearbox; Compact Design: marked 3×4 zone |
| 06 | Synthesis | **Less Is More** — One generator feeds two targets; a tempting extra gear contact causes a jam. Learn to leave a connection absent. | 6×5; one fixed non-removable gear near the branch. | Shared Infrastructure: one path segment shared; Clean Machine |
| 07 | Extra remix | **The Cog Was Never Misplaced** — Optional advanced remix of 04/05. A fixed large cog offers diagonal meshing independent of shaft orientation; a preview, not a mandatory first-chapter lesson. | 6×6; marked fixed large cog; O supplied with an optional hint. | Diagonal Thinking; No New Gearbox |
| 08 | Examination | **Apprentice Examination** — Supply two presses with different directions, branching around a fixed gearbox and a cog. Must combine several discoveries. | 6×6; fixed Q and G; limited inventory. | Under Budget: stage-specific limit; Preserve Corridor: marked cells unused |

**Authoring note:** Stage 07 is an explicitly optional remix; stage 08 is the chapter examination. Neither should require clearing the other.

## Chapter 2 — Impossible Routes (levels 09–16)

**Puzzle promise:** Spatial reasoning and the discovery that the obvious route or obstacle is sometimes misleading. **Board envelope:** 5×5–7×7. **New emphasis:** No mandatory new part; deepen I/Q/G and selected O reuse. **Recognizable variation family:** 09 → optional 15; 12 → 16.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 09 | Discovery | **Blocked Passage** — A wall separates source and press. The shortest geometric route is impossible; route power through a side opening. | 6×5; L-shaped fixed stone. | Keep It Clear: another marked opening; Under Budget: ≤ N parts |
| 10 | Application | **The Wrong Corner** — A fixed four-way gearbox points toward an unhelpful wall, but another output gives a useful approach. | 6×5; one fixed Q and asymmetric stone. | Restore the Original: Q on goal path; No New Gearbox |
| 11 | Alternative | **A Tight Squeeze** — Two nearby presses cannot both be approached by independent long shafts; sideways tooth contact makes room. | 5×6; tight central pocket; small cogs. | Compact Design: central region; Minimal Gearing: ≤ N cogs |
| 12 | Twist | **The Unmovable Gear** — A fixed gear blocks direct construction; instead of routing around it, exploit its toothed side for a second purpose. | 6×6; fixed G inside narrow corridor. | Use the Mount: marked side cell; Clean Machine |
| 13 | Discovery | **Crossroads** — Multiple paths look productive, but one closes a loop with incompatible rotation. More connectivity is not always helpful. | 6×6; a near-loop of fixed fixtures, one safe break. | No New Gearbox; Under Budget: ≤ N parts |
| 14 | Synthesis | **The Detour** — The obvious bypass exhausts stock. A counterintuitive short route uses a gearbox and a side mesh. | 7×6; wall with two openings; spare stock constrained. | Par Performance: ≤ N moves; Keep It Clear: direct corridor |
| 15 | Extra remix | **Blocked Passage?** — Revisit 09 with the familiar opening sealed; the player must reinterpret an awkward fixed cog as the passage. | 6×5; same silhouette as 09, alternate fixture. | No New Gearbox; Restore the Original |
| 16 | Examination | **Warehouse Renovation** — Finish two preinstalled assemblies without moving any fixture; the two presses demand different routes and spin. | 7×7; fixed Q, G and stone; distinct openings. | Use the Mount: exact repair socket; Under Budget: ≤ N parts |

**Authoring note:** Stage 15 is an explicitly optional remix; stage 16 is the chapter examination. Neither should require clearing the other.

## Chapter 3 — Unexpected Motion (levels 17–24)

**Puzzle promise:** Discover speed transformations, sign changes and how two valid transmissions can disagree. **Board envelope:** 5×5–8×7. **New emphasis:** O (large cog); reinforced G/Q. **Recognizable variation family:** 20 → optional 23; 21 → 24.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 17 | Discovery | **Too Fast!** — A 1× source must power a 0.5× target: small-to-large meshing slows the output. | 5×5; strong visual contrast between G/O. | Minimal Gearing: ≤ 2 cogs; Clean Machine |
| 18 | Application | **Double Time** — Swap the transmission roles to create 2× output; the fast solution is not another gearbox. | 5×5; different generator/target geometry. | Under Budget: ≤ N parts; No New Gearbox |
| 19 | Alternative | **The Diagonal Trick** — A fixed large cog appears misaligned; its diagonal rim can mesh with a small cog regardless of shaft orientation. | 6×5; fixed O in a diagonal pocket. | Diagonal Thinking; Restore the Original |
| 20 | Discovery | **Two Clocks** — One source powers presses at 1× and 2×; a shared trunk must split before the ratio change. | 6×6; two targets with distinct speed labels. | Shared Infrastructure; Minimal Gearing: ≤ N cogs |
| 21 | Twist | **Speed, Wrong Direction** — The chosen gearing achieves the target RPM but inverts the sign. A further reversal must preserve the ratio. | 6×6; fixed target, constrained return corner. | No New Gearbox; Dual Rotation |
| 22 | Synthesis | **The Feedback Trap** — Two individually valid powered paths recombine with incompatible rates. Keep the necessary outputs while preventing feedback. | 7×6; near-loop and two target presses. | Clean Machine; Under Budget: ≤ N parts |
| 23 | Extra remix | **Mirror Clocks** — Recognizable remix of 20: swap 0.5× and 2× demands and lock a large cog in the formerly easy branch. | 7×6; recognizable split and fixed O. | Diagonal Thinking; Perfect Fit: exactly N new mechanical parts |
| 24 | Examination | **Clockmaker's Certification** — Feed three outputs at 0.5×, 1× and 2× with specified directions; one gearbox and one gear are fixed. | 8×7; constrained distribution hub. | Minimal Gearing: ≤ N cogs; Dual Rotation |

**Authoring note:** Stage 23 is an explicitly optional remix; stage 24 is the chapter examination. Neither should require clearing the other.

## Chapter 4 — Transmission Tricks (levels 25–32)

**Puzzle promise:** Exploit chain/belt geometry and crossings; distance is a property of the transmission, not the puzzle's difficulty knob. **Board envelope:** 6×6–9×8. **New emphasis:** D (chain), V (belt). **Recognizable variation family:** 26 → optional 31; 28 → 32.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 25 | Discovery | **Linked Together** — Two adjacent chain drives transmit sideways while their shaft ports face a different axis. | 6×6; perpendicular power entry; D introduced. | Chain Reaction: three powered links; No New Gearbox |
| 26 | Application | **Over the Gap** — Use a long belt between parallel pulleys to pass an unusable space without filling intermediate cells. | 7×6; empty gap surrounded by stone. | Belt Specialist: span ≥ 3 cells; Clean Machine |
| 27 | Alternative | **Close Coupling** — Two adjacent pulleys still connect. The useful answer is compact, contradicting the assumption that belts require a long gap. | 6×6; close pulleys; short path. | Compact Design: marked zone; Minimal Gearing: ≤ N cogs |
| 28 | Twist | **Crossing the Line** — A second shaft transmission must cross an existing belt span. The shaft doesn't interrupt the belt route. | 7×7; fixed pulley endpoints with crossing socket. | The Crossover; Keep It Clear: marked alternate lane |
| 29 | Application | **Chain Reaction** — A chain-drive row must feed a side press while an axial exit continues to another; keep rotations compatible. | 7×7; multiple D fixtures and different port directions. | Chain Reaction: ≥ 3 links; Shared Infrastructure |
| 30 | Synthesis | **Above and Below** — Two presses lie on either side of a blocked center; belt routes must be coordinated with shaft/gear entry points. | 8×7; two obstacles, multiple possible belt lanes. | Belt Specialist: ≥ 4-cell span; Compact Design: middle five columns |
| 31 | Extra remix | **Over the Gap?** — Revisit 26 with the original pulley landing blocked; the only useful new landing also creates a shaft/belt crossing. | 8×7; familiar layout with changed endpoint. | The Crossover; No New Gearbox |
| 32 | Examination | **Transmission Engineer** — Connect three machines through chains, nearby/long belts and a necessary shaft crossing while preserving target sign. | 9×8; mixed fixed pulleys and chain. | Single Long Belt: ≥ 4-cell span; Clean Machine |

**Authoring note:** Stage 31 is an explicitly optional remix; stage 32 is the chapter examination. Neither should require clearing the other.

## Chapter 5 — Tangled Machinery (levels 33–40)

**Puzzle promise:** Graph intuition: shared trunks, branches, redundant links, and when removing a path makes more devices work. **Board envelope:** 7×7–9×9. **New emphasis:** No new parts; integrate gearing, belts, chains and multi-press diagnostics. **Recognizable variation family:** 36 → optional 39; 35 → 40.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 33 | Discovery | **Branch Office** — Two far presses share one useful powered trunk instead of consuming independent full-length routes. | 7×7; two endpoint wings. | Shared Infrastructure; Under Budget: ≤ N parts |
| 34 | Application | **Three Different Directions** — A shared generator branches to three presses; each requires a different number of inversions. | 7×7; distributed target orientations. | Dual Rotation; No New Gearbox |
| 35 | Alternative | **Shared Infrastructure** — A built-in gearbox looks like the only branching option, but a mixed chain/cog layout can reuse fewer parts. | 8×7; partly fixed spur line. | Restore the Original; Minimal Gearing: ≤ N cogs |
| 36 | Twist | **The Unwanted Loop** — Connecting every open port jams the network. The winning insight is to *omit* a tempting bridge. | 7×8; almost-closed mesh loop. | Clean Machine; Keep It Clear: marked loop-closing cell |
| 37 | Application | **Mixed-Speed Factory** — Create 0.5×/1×/2× branches without combining inconsistent rates in the same mechanical circuit. | 8×8; multiple speed-labeled goals. | Shared Infrastructure; Minimal Gearing: ≤ N cogs |
| 38 | Synthesis | **No Dead Machinery** — Several routes work, but fixed salvage machinery is scattered throughout. Decide which common trunk can use those pieces. | 9×8; preinstalled useful and decorative parts. | Factory Salvage: marked fixtures on goal paths; Under Budget: ≤ N parts |
| 39 | Extra remix | **One More Connection?** — Remix of 36: one fixture moves, turning the previously forbidden link into the essential connection while a *different* loop must remain open. | 8×8; recognizable loop with shifted fixture. | Perfect Fit: exactly N new parts; Keep It Clear: decoy bridge |
| 40 | Examination | **Distribution Director** — Power four presses with different signs and rates using one engine, limited junction cells and fixed infrastructure. | 9×9; dense central service gallery. | Shared Infrastructure; Full Utilization: all stock productive |

**Authoring note:** Stage 39 is an explicitly optional remix; stage 40 is the chapter examination. Neither should require clearing the other.

## Chapter 6 — The Control Room (levels 41–48)

**Puzzle promise:** Mechanical and redstone networks coexist but never overlap; powering more control devices can be the *wrong* action. **Board envelope:** 6×6–9×9. **New emphasis:** B/R redstone block/dust, Z/C gearshift/clutch. **Recognizable variation family:** 44 → optional 47; 43 → 46.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 41 | Discovery | **The Reverse Lever** — A fixed gearshift reaches a press with wrong spin; an adjacent redstone block changes output direction. | 6×6; fixed Z with clear power socket. | Single Power Source; Minimal Wiring: zero dust |
| 42 | Application | **Wire It Up** — The power source is too far away for direct activation; connect dust around a blocked mechanical path. | 7×6; redstone route separate from shafts. | Minimal Wiring: ≤ N dust; Keep It Clear: marked machine bay |
| 43 | Alternative | **Emergency Stop** — An extra kinetic connection induces a jam. Redstone-powered clutch isolates it, allowing the press to run. | 7×6; fixed C in branch. | Selective Control: marked Z remains off; Clean Machine |
| 44 | Discovery | **Two Different Commands** — One mechanical source feeds two outputs; only one gearshift must receive redstone while a neighboring device stays off. | 7×7; adjacent Z devices and narrow redstone lane. | Selective Control; Single Power Source |
| 45 | Twist | **Signal Routing** — The obvious dust line would overlap gears. Use a longer but non-overlapping connected circuit. | 8×7; checkerboard-like machine obstructions. | Minimal Wiring: ≤ N dust; Compact Design: defined signal region |
| 46 | Synthesis | **Normally Off** — A clutch starts powered and cuts off the useful branch; isolate/remove redstone power without disturbing working kinetic fixtures. | 8×8; fixed powered C + detachable R/B, no removal of fixed parts. | Preserve the Controls: another marked shift stays on; No New Gearbox |
| 47 | Extra remix | **One Block Too Many** — Recognizable remix of 44: a different device is now adjacent to the source. Sharing the old signal accidentally powers the wrong machine. | 8×8; remixed redstone device placement. | Selective Control; Signal Sharing: only designated two devices |
| 48 | Examination | **Control Engineer** — Repair a stable factory with wrong gearshift states, a clutch isolating a good branch, and overlapping route temptations. | 9×9; fixed Z/C and dust. | Single Power Source; Minimal Wiring: ≤ N dust |

**Authoring note:** Stage 47 is an explicitly optional remix; stage 48 is the chapter examination. Neither should require clearing the other.

## Chapter 7 — The Repair Shop (levels 49–56)

**Puzzle promise:** Read somebody else's mechanism. Fixed machinery is sometimes helpful, sometimes misleading, and cannot simply be removed. **Board envelope:** 7×7–10×9. **New emphasis:** No new parts; diagnostic framing and complex partial assemblies. **Recognizable variation family:** 51 → optional 55; 49 → 53.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 49 | Discovery | **One Missing Gear** — A mostly functioning fixed line has a small gap. Locate the missing toothed interface rather than rebuild everything. | 7×7; fixed assembly, one missing join. | Restore the Original; Under Budget: ≤ N new parts |
| 50 | Application | **Reversed Installation** — The fixed network reaches the press at 1× but spins the wrong way; find space for an additional reversal downstream. | 7×7; immovable output gear/shaft. | No New Gearbox; Compact Design: repair bay |
| 51 | Discovery | **Mechanical Jam** — Two preinstalled branches impose incompatible motion at one junction; route the output through only one safe path. | 8×7; fixed half-constructed loop. | Keep It Clear: forbidden bridge; Clean Machine |
| 52 | Application | **Faulty Controls** — The fixed kinetic routing is almost correct, but gearshift/clutch redstone states are wrong. Repair just the electrical network. | 8×8; fixed mechanical devices; movable B/R. | Minimal Wiring: ≤ N dust; Preserve the Controls: marked device off |
| 53 | Twist | **A Bad Repair** — One fixed component looks like a helpful shortcut but would create a jam. Use the other installed path instead. | 8×8; one misleading and one useful fixed fixture. | Factory Salvage: useful marked set only; No New Gearbox |
| 54 | Synthesis | **Salvage Operation** — Two disconnected fixed assemblies can both contribute if bridged through an indirect belt/cog path. | 9×8; separate clusters; limited spares. | Restore the Original: both clusters on goal paths; Belt Specialist |
| 55 | Extra remix | **Factory Blackout?** — Remix of 51: the previously jam-producing bridge is safe now, but a new fixed ratio difference makes another bridge dangerous. | 9×9; recognizable repair topology; shifted ratio. | Keep It Clear: new incompatible bridge; Perfect Fit: exactly N new parts |
| 56 | Examination | **Chief Mechanic** — Fix an interconnected factory with incorrect rotation, gear ratio and redstone state without moving installed machines. | 10×9; mixed fixed Q/O/Z/C; three faulty endpoints. | No Replacement Parts: restricted kit; Restore the Original: designated fixtures |

**Authoring note:** Stage 55 is an explicitly optional remix; stage 56 is the chapter examination. Neither should require clearing the other.

## Chapter 8 — The Grand Factory (levels 57–64)

**Puzzle promise:** Culminating insight puzzles, not eight ever-larger factory mazes. Favor unexpected simplifications and multiple valid designs. **Board envelope:** 8×8–10×10 (with one compact 7×7 interlude). **New emphasis:** All parts available; hints intentionally sparse. **Recognizable variation family:** 57 → optional 63; 60 → 64.

| # | Role | Level / intended realization | Board setup and immovable fixtures | Candidate bonuses (A; B) |
| --- | --- | --- | --- | --- |
| 57 | Discovery | **Foundry Restart** — Three prebuilt factory sections need a coherent central power plan. Decide which sections should share a trunk. | 9×8; fixed shaft, belt and gear subassemblies. | Shared Infrastructure; Restore the Original |
| 58 | Application | **The Clock Tower** — A dense fixed cog cluster needs 0.5×/1×/2× outputs. The surprising solution uses fewer extra gears than expected. | 8×8; immovable large cogs. | Minimal Gearing: ≤ N added cogs; Dual Rotation |
| 59 | Alternative | **Crane Bay** — A belt/shaft crossing is unavoidable, but choosing the crossing position solves both target direction constraints. | 9×9; two fixed belt anchors. | The Crossover; Keep It Clear: marked crane lane |
| 60 | Twist | **The Piston Choir** — Four nearby presses demand alternating CW/CCW. A tiny cluster can serve all four; a sprawling build creates conflict. | 7×7; compact late-game challenge. | Compact Design: tight work zone; Under Budget: ≤ N parts |
| 61 | Application | **Minimum Materials** — Everything needed is supplied, but spare count is almost exact. Look for a shared use of a gearbox and gear mesh. | 9×9; fixed central spine and scarce inventory. | Perfect Fit; No New Gearbox |
| 62 | Synthesis | **The Override Circuit** — Fixed clutches and shifts can be controlled with a single network, except one device must remain unpowered. | 9×9; one fixed redstone block and several switches. | Selective Control; Minimal Wiring: ≤ N dust |
| 63 | Extra remix | **The Incomplete Blueprint** — Remix of 57: superficially the same layout, but the familiar shared trunk now causes a ratio conflict; separate the sections instead. | 10×10; alternate fixed ratio arrangement. | Two Separate Paths: after splitter; Factory Salvage |
| 64 | Final examination | **The Grand Commission** — Four presses with mixed rates and spin, fixed cogs/gearboxes, at least one belt crossing and selective redstone; reward the simplest insight, not sheer length. | 10×10; multi-system fixed plant; several plausible solutions. | Full Utilization: all stock productive; Perfect Fit: exact part limit |

**Authoring note:** Stage 63 is an explicitly optional remix; stage 64 is the chapter examination. Neither should require clearing the other.
## Bonus objective system — varied, authored, measurable

Each of the 64 levels has **exactly two authored bonus slots**, not a global generic trio. The table above gives the intended type for each slot. Final numeric limits (`N`), marked cells and affected parts belong to each level's file.

| Family | Example objective types | Authoritative check required |
| --- | --- | --- |
| Efficiency | Under Budget, Par Performance, Perfect Fit, Full Utilization, Clean Machine | Count newly placed components, move history, final stock, effective powered machinery |
| Part choice | No New Gearbox, Minimal Gearing, Gearhead, No Replacement Parts | Authored allowed/forbidden part-kind totals; **fixed fixtures don't count as newly placed** |
| Architecture | Shared Infrastructure, Two Separate Paths, Dual Rotation | Trace energized paths and junctions to designated presses; sign of powered transmissions |
| Geometry | Compact Design, Keep It Clear / Preserve Corridor, Use the Mount, The Long Way | Defined rectangular/marked cells and validated path traversal |
| Transmissions | Belt Specialist, Single Long Belt, Chain Reaction, The Crossover, Diagonal Thinking | Actual powered links and spans (not mere placement), and correct meshing adjacency |
| Redstone | Minimal Wiring, Single Power Source, Signal Sharing, Selective Control, Preserve the Controls | Actual electrically powered graph and chosen device states |
| Restoration | Restore the Original, Factory Salvage | Marked fixed/salvage pieces are on functional generator-to-target paths, not merely powered dead ends |

**Rules for high-quality bonuses**

1. Two bonuses on the same level should test **different solution strategies**; avoid pairs like `≤ 5 parts` + `≤ 6 parts`.
2. Bonuses should sometimes pull toward *contrasting* designs (e.g., compact route vs long belt), but a **joint three-point solution must be possible** wherever the level claims a perfect 3/3.
3. `Par Performance` and `Full Utilization` remain in the catalogue but should **not dominate**. Target no more than one par objective per chapter and no more than two full-inventory objectives in the whole 64-level campaign.
4. A player's exploratory actions should not be punished unnecessarily. Avoid "never jammed even once" and hidden input sequences.
5. Every objective needs a short label, a clear human-readable rule and, where applicable, a live measurement (`3 / 4 cells`, `2 / 3 powered links`, `5 / 6 placed`).
6. Bonuses are checked against actual final mechanics. For example, a crossing only counts when both transmissions function; a redstone sharing bonus only counts if both named devices respond to the same connected network.
7. Bonus checks must not accidentally reward preinstalled fixtures as "player-placed" unless explicitly described.
8. Objectives should be attainable through a verified solution without relying on screen size, click button, touch gestures or animation timing.

## Level-editor and pack authoring requirements

The current branch already experiments with file-backed editing; this section defines what campaign-quality authoring must ultimately support. **Do not assume these capabilities are already implemented.**

### Level definition

Each proposed `.coglevel` entry should carry:

- Stable `id`, short `name`, `chapter`, `stage`, `role` (`discovery|application|alternative|twist|synthesis|extra|examination`), optional `remixOf`, `tags`, and brief *designer-only* `intendedInsight`.
- Board `width`, `height`, exact source and goal ports/rates/signs, stone, editable starting pieces, **fixed fixtures with purpose**, starting redstone and available stock.
- Two `bonus` definitions: stable evaluator ID, typed parameters (e.g. region, target fixture IDs, `maxParts`, `minSpan`), short name, full hint and live-progress formatter.
- `hintLadder`: observational hint → conceptual hint → optional solution-oriented hint. Do not spoil surprise in the initial briefing.
- `referenceSolutions`: core win, bonus A, bonus B, and **both** where the 3/3 badge is offered, all including starting fixture states.
- `designNotes`: what tempting approach fails, what assumption changes from the remix source, and which valid alternate solutions were found during playtesting.

Levels should be stored as validated **data**, not dynamically executed Lua. User-authored packs may reorder stages but need explicit local progression metadata instead of silently inheriting the built-in 64-stage numbering.

### Editor UX

- Toggle **fixed/movable** on authoring parts; show distinct border/lock treatment.
- Set per-goal RPM and spin; configure supplies, walls, starts, board size and two bonuses.
- Draw marked bonus zones and alternate-path waypoints on the grid.
- Test **playable initial state** separate from the solution-state editing canvas, so editor testing cannot accidentally count a premade solution as a new clear.
- Save drafts as `.coglevel`; compile one or more to `.cogpack`; preserve stable IDs so revised packs can retain user progress when compatible.
- Export reference solutions with reproducible move order where the move-par objective is used; include fixture and electrical states in snapshots.

### Acceptance gates for every level (before implementation is declared complete)

- [ ] Unique *player-facing* discovery; neither a stretched clone nor a one-for-one mirror of a prior board.
- [ ] All required concepts have been discovered earlier on at least one accessible path, or are taught by this level's Ponder hint.
- [ ] The authored starting board is valid, isn't already solved and is not secretly jammed unless the puzzle explicitly concerns diagnosing a jam.
- [ ] At least one normal solution reaches **all** required presses with correct RPM, spin and no jam.
- [ ] Two distinct bonus requirements are understandable and individually achievable; the 3/3 joint solution is verified if offered.
- [ ] Fixed fixtures are neither removable nor rotatable in play; each has a justified purpose.
- [ ] A remix has a recognizably shared layout but decisively **changes the winning insight**, so a trivial repeated solution does not pass.
- [ ] Multiple solutions are accepted unless uniqueness is essential and explicitly tested; reference route is never hardcoded as the only allowed win.
- [ ] Exact stage board, fixture count and controls remain legible on a real Advanced Monitor at text scale 0.5.
- [ ] Chapter gating is exhaustively simulated: no softlocks, no need to complete #7/#8, no grinding by repeating already awarded objectives.
- [ ] Internal level IDs, pack persistence, save migration and custom pack data survive installation/update tests.

## Implementation sequence — deferred

1. **Author and playtest Chapter 1 manually** in the editor. Verify the 04→05→07 family is a true intellectual remix, not mere shape variation.
2. Build a reliable **typed bonus evaluator** and designer-facing objective overlays before scaling the campaign.
3. Implement chapter-path UI, 6-point/4-main gating and clear/bonus status per node; test skip/replay/unlock scenarios.
4. Hand-author one chapter at a time, recording core and each bonus reference solution, and run the solver as an acceptance gate.
5. Perform blind playtests with hint frequency, alternative solutions and pacing tracked. Refine or remove repetitive entries instead of lengthening them.
6. Retire the generated `shaftLesson` / `fromSeed` placeholder campaign **only when authored replacement stages are proven playable**.

### Explicitly out of scope for this documentation commit

No level geometry, `levels.lua`, `chapters.lua`, bonus logic, editor implementation, save schema, installation manifest or graphics code is changed here. PR #52 is currently **implementation-in-progress**; this document records the **revised creative target**, not a claim that the playable campaign already matches it.
