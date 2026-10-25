# CivCraft — Gameplay, AI, Diplomacy & Multiplayer Roadmap

**Status:** Design draft v0.9.1; confirmed requirements plus explicitly open decisions  
**Target:** Next major CivCraft gameplay iteration (working name: v0.9; release number not committed)  
**Repository:** https://github.com/fpbcraft/cc-scripts/tree/main/games/civcraft  
**Last revised:** 2026-10-24

> **Scope boundary:** This is a planning document, not an implementation report. No changes described here have been committed as a result of this conversation. Values identified as *proposed* are balancing hypotheses to verify in playtests.

## 1. Product goals

Make CivCraft a compact, engaging 4X Civilization-like game for CC:Tweaked with up to four civilizations, one to four human players and remaining slots controlled by AI. Preserve local hotseat, rednet multiplayer, touch-first advanced-monitor controls, fair and informative fog of war, deterministic seeded worlds, and compatibility with existing saves wherever possible.

Primary outcomes:

1. Responsive, expressive moment-to-moment play: smooth unit movement, combat animations, visible opponent actions, strong ownership cues and combat forecasts.
2. Better geography and balance: coherent Minecraft-inspired biomes, mostly traversable terrain, sparse logical resource distribution, fair starting locations, larger maps and natural wonders that are not laid out in rows.
3. Credible opponents: personalities, goals, economic specialization, tactical competence, realistic threat responses and difficulty that increases intelligence rather than cheats.
4. Strategic diplomacy: relationships, memories, war and peace, treaties, alliances, meaningful conversations and a Council of Civilizations.
5. Robust multiplayer: simultaneous peaceful actions and sequential turns among connected wartime participants, using an authoritative host and visibility-filtered event stream.
6. Explainable decisions: research details, Codex links, threat visualization, faction profiles, production control and victory progress.

## 2. Decision register

### Confirmed

| Topic | Decision |
|---|---|
| AI model | Goal-oriented utility-based strategic, economic, military and diplomatic layers, with bounded calculations |
| AI personalities | **Fixed** profile for each civilization; behavior can adapt to circumstances |
| AI difficulty | Settler, Chieftain, Prince, King, Deity; primarily smarter decision-making |
| First AI milestone | Competent Prince baseline with meaningful strategic and tactical AI before adding advanced difficulties |
| Game duration | Quick / Standard / Epic presets adjust both turn cap and progression speed |
| Victories | Lobby-selectable enabled victory conditions; Diplomatic victory will be added through Council elections |
| Council | Leadership elections **and resolutions** (trade, embargoes, peace initiatives, etc.) |
| Diplomacy scope | Advanced: trade, peace/war, open borders, alliances, joint wars, relationship memories, conversations |
| Hybrid multiplayer | Peaceful players may act simultaneously; **only civilizations in connected wartime groups** use sequential turns |
| War declarations | **Normal war** announced now, activated next round; **Surprise War** takes effect immediately with severe diplomatic consequences |
| Defensive alliance response | An attacked ally **requests assistance**; partners choose to join or refuse, with relationship/reputation consequences for refusal; no automatic joining |
| AI strategic planning | **Stable long-term victory goal** and persistent medium-term plans; reevaluate on major events and bounded periodic reviews, avoiding oscillation |
| World representation | Full **biome + elevation + feature** tile model inspired by Minecraft |
| Land movement | Open terrain typically costs **1**, most difficult terrain **2** (no routine 3-point penalty) |
| Settlers | Base movement **3**, ignore most ordinary terrain penalties; founding requires **positive movement remaining** and consumes the settler |
| Attack indications | Show **both** currently attackable targets and threatened destination tiles |
| Healing | Passive healing only in owned territory; dedicated support units may heal outside it |
| Research pace | At Standard speed, approximately **20–25% faster** than present baseline |
| Animation style | **Smooth interpolation between hexes**; short combat and key-event effects; no teleport-only movement |
| Fog | Never reveal unseen units, deposits or action details; advanced-resource technology visibility deferred to a later update |
| Faction colors | Remove the green player slot; use visually distinct colors and ownership outlines/badges |
| Map | Larger playable size presets; test performance before selecting exact dimensions |

### Open — to resolve in subsequent design discussion

- How much of a first strike to permit on immediate Surprise War and how a defender whose turn was already ended receives a response opportunity (without fresh movement points).
- Whether a small **zone-of-control** mechanic should accompany the smarter tactical AI, or whether movement/combat rules remain otherwise unchanged.
- Whether AI commanders can visibly muster forces while at peace, and whether a human can see a non-secret "mobilizing" assessment.
- Peace-deal scope (simple ceasefire versus negotiated gold, resources, reparations, and territorial concessions).
- Whether peaceful units may cross foreign territory without open borders, and applicable penalties.
- How frequently Council sessions occur, how votes are allocated, and the anti-exploit rules for diplomatic victory.
- Whether observed opponent actions play automatically, via recap, or both; whether animations auto-pan the camera.
- Exact duration multipliers, number of rounds, map sizes, resource density and Council thresholds (proposals below).
- Whether Score is a separately toggleable victory or a mandatory end-of-round-limit tie-break.

## 3. Architecture and shared action processing

**Current starting point:** CivCraft already has authoritative game logic, per-player exploration/visibility, a rednet snapshot system, movement pathfinding, combat formulas, terrain rendering and local hotseat; however, several AI actions still mutate game state directly, movement is visually instantaneous, and the compact research screen switches to a list.

Introduce a common command dispatcher for human, AI and remote-player actions:

`propose action → validate ownership/rules/phase/visibility → apply authoritative state transition → emit sequenced action event → update visibility → send observer-filtered changes → animate presentation`

Implementation requirements:

- The host remains authoritative for all local and network sessions.
- AI must not directly teleport units, bypass costs or inspect unrevealed opponent plans. It calls the same legal action engine as humans.
- Make core rules deterministic and unit-testable, decoupled from renderer and CC peripherals.
- Use an explicit versioned save migration policy; preserve older world layouts instead of silently regenerating them.
- Keep simulation state and presentation state separate. A skipped animation cannot affect rules.
- Employ cooperative yielding for expensive pathfinding, world loops, AI selection and redraws.

Proposed modules (names provisional): `actions.lua`, `events.lua`, `animations.lua`, `visibility_events.lua`, `turn_scheduler.lua`, `ai/strategy.lua`, `ai/economy.lua`, `ai/tactics.lua`, `ai/diplomacy.lua`, `diplomacy.lua`, `council.lua`, `biomes.lua`.

## 4. World generation and biomes

### 4.1 Tile model

Store separate tile properties:

- `biome`: plains, forest, savanna, desert, taiga, jungle, swamp/mangrove, snowy plains, badlands, coast/ocean; rare mushroom biome/landmark.
- `elevation`: flat, hill, mountain.
- `feature`: none, woods, dense vegetation, marsh, etc.
- Additional properties as needed: water/coast classification, resource deposit, wonder, railway, city and territory ownership.

Avoid contradictory combinations, e.g. marsh-covered steep mountains. Use seeded macro terrain/climate fields so regions resemble actual Minecraft landscapes, rather than tile-level independent noise and diagonal modular patterns. Generate elevation, temperature, moisture, biomes and features as separate layers, then validate and repair starting areas.

### 4.2 Traversability and yields

Proposed baseline:

| Destination terrain | Ordinary land unit | Settler |
|---|---:|---:|
| Open flat land (plains, savanna, open desert, snowy plains) | 1 | 1 |
| Woods / hills / jungle / swamp | 2 | 1 |
| Multiple ordinary difficult features (e.g. forested hill) | 2 maximum | 1 |
| Mountain | impassable | impassable |
| Water | embark/navigation rules | embark/navigation rules |

Some specialized units and civilization bonuses can ignore terrain penalty; railways retain their dedicated movement behavior. Balance terrain distribution so a majority of traversable land permits one-point movement, without requiring every land tile to be the Plains biome. Tune yields with the same tile model and avoid making attractive settlements too rare.

### 4.3 Resource distribution

Proposed target: **15–20% of tiles with deposits**, subject to world type, water share and fairness testing. Cap mutually exclusive deposits at one per tile. Different resources use biome/elevation/feature eligibility:

| Resource | Proposed habitats |
|---|---|
| Grain | Open plains/savanna and fertile floodplain-like land, if implemented |
| Horses | Open plains and savanna, without dense vegetation |
| Timber | Forest, taiga, jungle and relevant wooded features |
| Stone | Hills and rocky mountains |
| Iron | Non-snowy hills, rocky uplands |
| Copper / Zinc | Hills, rocky ranges, badlands |
| Redstone | Rocky uplands and badlands, rarer than copper/zinc |
| Diamond | Scarce rocky terrain, deep-mining thematic regions |
| Fish | Coast and water |
| Legacy saltpeter | Open plains and selected hills, pending resource clean-up |

Respect resource unlocks and current resource mechanics; **hide undiscovered deposits**, but do **not** implement tech-gated map visibility for later-era resources yet. Keep guaranteed reasonable starting food and access to at least one useful early strategic deposit, without symmetrical clones.

### 4.4 Wonders and larger maps

- Natural wonders: select seeded eligible candidates using a proper deterministic PRNG or well-mixed hash, minimum distance from player spawns (proposed six hexes, scaled by map size), separation between wonders, thematic biome restrictions and geographic dispersion. No conspicuous common row or diagonal.
- Constructed wonders: remain city-produced, unique, territory-dependent and distinct from naturally spawned landmarks.
- Larger worlds: define new presets after renderer, pathfinder, snapshots, AI and save performance testing. Maintain smaller option for limited monitors.
- Legacy saves: keep generated terrain/resources intact; version new generation and provide a compatibility adapter for old tile types.

**Acceptance:** Same seed/settings produce identical worlds; different seeds differ; resources never violate eligibility; target density holds within tolerance across hundreds of seeds; capitals are settleable and have useful local yields; wonders satisfy spacing; no obvious rows/diagonals; old saves remain playable.

## 5. Movement, founding, healing and combat

- Settlers move 3 per round (adjust civ bonuses carefully), usually pay 1 on non-mountain land, and may found only when `movesLeft > 0`. City founding consumes the settler after all settlement legality checks. AI obeys exactly the same rule.
- All actionable orders automatically wake a sleeping unit before rule checks; explicit sleeping remains for idle-turn suppression. If an attempted order fails, define whether standby remains unchanged (preferred: unchanged).
- Healing and passive regeneration work only when a unit is in territory owned by its civilization. Dedicated healers may provide an explicit adjacent healing effect outside owned territory; do not grant automatic neutral/enemy regeneration.
- Extract a pure combat prediction routine shared by preview and resolution: attacker/defender HP after hit, retaliation, wall damage, ranged behavior, deaths and possible city capture. The predictor must not mutate the game state.
- Indicate (a) attackable enemy targets and (b) destination tiles threatened by currently visible enemies. Distinguish them visually and in legend/tooltips; do not leak hidden enemies in threat highlights.
- Add optional strategic threat scoring to support AI pathfinding and player destination previews.

**Acceptance:** Found-city fails after movement reaches zero, succeeds with positive movement remaining, and uses identical human/AI validation; healing location conditions are enforced at round transition and for support abilities; predicted combat result exactly matches deterministic resolution for stable input; threatened destinations use only observer-known units.

## 6. Smooth animations and observed action replay — CONFIRMED

### 6.1 Required visual behaviors

1. **Unit movement:** Smoothly interpolate sprite position between successive hex centers along the **actual host-approved path**. No instant teleport except when animations are disabled/skipped.
2. **Melee combat:** A short lunge/strike, impact flash and HP-loss feedback, then return or advance on victory.
3. **Ranged combat:** Projectile or directional flash from attacker toward target, distinct from melee. Defender updates after impact.
4. **Unit defeat:** Brief fade/disappearance; avoid leaving a static sprite at a destroyed location.
5. **Founding/capture:** Brief settlement-appearance or ownership-transition effect.
6. **Other major outcomes:** Small contextual effects for completed wonders, newly revealed landmarks, key research and treaty/war announcements as appropriate.
7. **Observed rival actions:** Animate enemy and AI movement and combat when relevant action portions were genuinely visible to the observer; local hotseat may replay events on the next player's turn.

### 6.2 Timing, controls and performance

Proposed initial tuning: ~**100–150 ms per hex**, with interpolation between frames; adaptive frame rate suitable for supported graphics modes (measure rather than promise constant FPS). Group long paths or speed up event queues to prevent excess delays. Offer **Normal / Fast / Off** animation preferences, plus **Skip** for current playback; reduced-motion option should show final state directly without losing event summaries. Preserve audio settings separately.

Use animation overlays separate from authoritative unit positions, with a consistent transition between static and animated sprites to prevent both old and final instances being shown simultaneously. Do not block incoming host commands while drawing: process network/events cooperatively and cap queue growth. Network snapshot updates must not cause visual rewinds or frame-order inversions.

### 6.3 Action event format and visibility safety

Versioned event envelope (illustrative): `seq`, `round`, `actor`, `type`, `start`, `path`, `target`, `result`, `publicMetadata`. Event records are *authoritative*, but each client's payload must be filtered before transmission.

- Check visibility at **each movement segment / each relevant action time**, not merely at the final coordinate. A unit may enter view midway through a path or disappear from view.
- Send only visible path segments with safely bounded context. Never reveal a concealed origin, destination, hidden combatant, invisible target, or a hidden unit's full path.
- Public events (e.g. formal war declarations) may be visible to all if their information category explicitly permits it.
- Record enough temporal/position information for clients to animate observed effects despite the host already having committed the new state.
- Provide deterministic event ordering and bounded persistence for hotseat replays and reconnects. Do not embed hidden, full-information events in player-facing save or snapshot structures.

### 6.4 Presentation behavior and replay choices

**Proposal, not yet confirmed:**

- **Network live view:** Automatically animate observed events that intersect the current viewport, at the event sequence position; avoid interrupting an ongoing local command with unsolicited camera changes. Offscreen observed events produce a compact actionable feed item, not an automatic camera jump.
- **Local hotseat:** After the private handoff, display a per-player summary of qualifying events since that player's last turn, with **Play All / Watch Selected / Skip**. Generate this summary from each observer's permitted event projection, never from full authoritative action logs.
- **Animation backlog:** Batch low-priority movement during bursts, but preserve combat, city capture and founding messages. Cap buffered events in count/age; if playback falls behind, coalesce visuals and retain essential event summaries.
- **Paused/hidden sessions:** Reconnection supplies an observer-filtered current state plus a small replay window, not an unrestricted historical action log. Animation preferences (Normal / Fast / Off) must not affect actual turn simulation.
- **Camera:** No automatic pan by default for offscreen events; offer Watch/follow when the user requests it. The player can dismiss an observed event without affecting diplomacy or turn order.
- **Information leakage:** An event viewed after fog changes must retain the **visibility and redaction from event time**. Later exploration cannot retroactively reveal an unseen path in the replay.

**Open choice:** automatic onscreen action playback versus always using an optional event feed/recap; optional camera-follow rules.

**Acceptance:** A 5-hex move visibly traverses the calculated route; transition lasts roughly according to speed setting; no sprite duplication; users can skip; combat animation does not change HP calculation; rival action segments appear only to legitimate observers; hotseat replay never leaks hidden information; long movement batches remain responsive on CC:Tweaked and text fallback remains functional.

## 7. AI system: strategy, economy, military and diplomacy

### 7.1 Common principles

- Build a **goal-oriented, utility-scored AI**, not a longer list of hardcoded actions.
- Prefer bounded top-N candidate evaluation, shallow tactical lookahead, cached threat maps and seeded tie-breaks over expensive brute force or neural networks.
- Store long-lived plans in the save, but recompute volatile local choices when state changes.
- Keep **personality** (what the AI prefers) separate from **difficulty** (how well it executes).
- Run AI through the same command validator and visibility-respecting state representation as humans.
- Provide understandable observable intentions: mobilization, railway construction, diplomatic warnings, new technological era, completed wonder—without revealing secret plans.

### 7.2 Strategic director

Choose a primary victory goal and supporting objectives. **Confirmed: keep plans stable.** Persist the active strategy instead of reconstructing it from scratch each turn. Trigger a deliberate reassessment on major events (loss of a city, new war, broken alliance, severe treasury/resource shock, rival near victory, unlocked decisive technology). Perform a low-cost periodic strategic review as well (proposed: every 8–12 global rounds); retain the incumbent strategy unless a challenger substantially outperforms it. Numerical switch thresholds are tuning values, not locked rules.

Separate **emergency overrides** (defend capital, avoid bankruptcy, heal threatened units) from **strategy replacement** so a temporary crisis does not permanently turn a Scholar into a Conqueror. Medium-term campaign goals should survive save/reload and unit-turn boundaries. Use a deterministic seeded tie-break for near-equal plans.

Five possible outcomes: **Conquest**, **Industrial**, **End Expedition**, **Diplomatic**, and **Score at round cap** (pending final score-toggle rules). A Scholar tends toward End Expedition, Industrialist toward Industrial, Merchant toward Diplomatic, but any AI may pivot if conditions demand.

Persist a compact plan: primary goal, current goals, targets, priorities, target city specializations, known threats, strategic mood, diplomatic stances and plan revision timestamp.

### 7.3 Economic AI

- Technology selection evaluates unlock value relative to ongoing victory objective, bottlenecks and projected research time.
- Buildings and units compete through expected-value and urgency, not fixed global ordering.
- Specialize cities in science, industry, military production, commerce or infrastructure.
- Manage city worker allocations, upkeep, stockpiles, gold and city production; allow intentional **No Production** when sensible.
- Select settlement sites based on yields, strategic materials, natural wonders, spacing, connectivity, defense, competition and scouting knowledge. Give settlers saved destinations and valid routes.
- Plan railway links for industrial win conditions and resource logistics.

### 7.4 Tactical AI and military campaigns

- Use **the same pure combat forecast** as the human attack preview: exact initial damage/retaliation, city walls/capture, and estimated exposed counterattack risk (future damage is an estimate, not deterministic).
- Compute a **visibility-limited threat map** from currently seen enemies and coarse uncertainty from remembered sightings; never use hidden current locations. The human danger overlay only shows confirmed visible threats, not guesses.
- Assign persistent unit roles: garrison, scout, settler escort, screening force, main army, ranged support, siege support and healer. Evaluate survival, role and strategic value when scoring each action.
- Plan campaigns as bounded objectives: **target city / border defense / strategic resource → muster point → approach corridor → siege or decisive attack → regroup and heal**. Retain a small army group ID and target so units cooperate across turns.
- Cap tactical calculations to a shortlist of legal moves/attacks per unit. Favor focus fire on high-value targets, screen vulnerable ranged/support units, withdraw damaged forces, and avoid attacking defensive cities without suitable strength or siege support.
- Respect turn groups in hybrid mode. No tactical command may move an inactive unit or bypass the common action executor.
- Use deterministic action priority to keep multi-unit planning reproducible. Replan the immediate action when an action is rejected by concurrent changes rather than teleport or retry indefinitely.
- **Open combat rule:** should hostile adjacent units exert a lightweight zone of control, or should movement constraints remain limited to passability, occupancy and movement points? Avoid introducing heavy global path searches.

**Proposed tactical scoring:** `utility = expected_damage + target_value + objective_progress + defensive_position - expected_retaliation - next_turn_exposure - casualty_risk - opportunity_cost` with difficulty/personality weighting and bounded lookahead. Do not overfit specific constants until scenario tests.

**Campaign event signaling:** Discovered enemy concentrations, deployments and siege approaches may appear as contextual reports or diplomatic warnings where observation permits. AI may *plan* an invasion before a war, but no hostile action may execute without active war (except existing independent hostile-mob rules).

### 7.5 Fixed civilization personalities

Proposed fixed primary archetypes, to tune after playtests:

| Civilization | Primary AI personality | Core tendency |
|---|---|---|
| Oak Villagers | Guardian | Cooperative, food security, protected lands |
| Deepslate Miners | Conqueror | Resource competition, military leverage |
| Enchanters Guild | Scholar | Research and End Expedition |
| Desert Wanderers | Expansionist | Rapid settlement, contested frontier |
| Ocean Explorers | Expansionist | Coast/naval control |
| Andesite Engineers | Industrialist | Machinery, production, rails |
| Mountain Builders | Guardian | Territorial defense, guarded diplomacy |
| Emerald Traders | Merchant | Gold, trade, alliances, Council |
| Golem Keepers | Guardian | Fortified cities and deterrence |
| Taiga Rangers | Expansionist | Exploration and forest-adapted settlement |

Attach fixed numerical values for aggression, ambition, risk tolerance, diplomacy, loyalty and border sensitivity. Archetypes guide preferences, not prohibit actions; the same Guardian must still fight a defensive war.

### 7.6 Five difficulty levels

| Level | Desired behavioral differences |
|---|---|
| Settler | Forgiving expansion and tactical choices, limited proactive attack |
| Chieftain | Basic strategic coordination, inconsistent optimization |
| Prince | Competent baseline, sensible expansion, production, military and diplomacy |
| King | Better evaluation, tactical planning, anticipation and threat handling |
| Deity | Stronger coordination, long-term planning, efficient counterplay; optional small disclosed bonuses only if necessary |

**Keep hostile mob difficulty separate.** Difficulty must not let AI see undiscovered resources, ignore movement rules, build instantly or gain undocumented stock.

### 7.7 Test harness and measurable quality

Create seeded AI-vs-AI and AI-vs-scripted-scenario simulations collecting: win rates by personality/difficulty, research/production efficiency, idle/wasted actions, expansion pace, failed founding actions, unit trades/casualties, successful defense/capture, diplomatic state transitions, perceived fairness, worst-case turn processing time and cooperative yield behavior. Validate the Prince baseline before implementing harder tiers.

## 8. Hybrid simultaneous/sequential multiplayer

### 8.1 Scheduling model — CONFIRMED

- Each global round has a common economy/science/production/victory boundary.
- Civilizations not involved in war can act **simultaneously**, with commands individually serialized and validated at the host.
- War creates a graph of civilizations: edges connect opponents currently at war. Each nontrivial **connected component** forms one sequential scheduling group.
- E.g. A–B and B–C wars make A/B/C one sequential group; D remains simultaneous. Distinct unconnected war groups can progress independently.
- Turn order within each war group must be deterministic, balanced and clearly displayed. AI and human take turns through the same scheduler.
- Last-valid-state wins: when concurrent orders conflict, the first valid server-committed action succeeds; the other receives a visible rejection and can reselect.
- Players who press End Turn are locked for that round; the round closes only when every participant has fulfilled its scheduling obligation.
- Local hotseat has privacy-preserving sequential player handoff even while the rules use shared global rounds.

### 8.2 Normal and surprise war — CONFIRMED core behavior

**Normal War:** Declare intent now; declaration and warning are public according to diplomacy visibility rules; war becomes active at the **next global round boundary**. Before activation, attacks against that opponent remain illegal; movement across borders follows peacetime treaty rules. This gives the target an opportunity to react and lets the scheduler regroup cleanly.

**Surprise War:** Declare and activate **immediately**, before the first hostile command, with major persistent diplomatic penalties (grievances/reputation, reduced trust, and stronger negative reactions from peaceful or loyal civilizations). The decision is explicit in the UI; avoid concealing its consequences. Surprise War must not bypass normal attack legality, movement, visibility, or ability to act. Consider diplomatic penalties and war exhaustion as independent balance factors; exact numbers remain provisional.

**Mid-round scheduler safety:** A Surprise War atomically adds the war edge and recomputes connected components, potentially merging several existing war groups. Pause only affected group participants while scheduler membership is rebased; unrelated peaceful players continue simultaneously. Each player's already committed moves, attacks, production choices and Ready state remain recorded; **never refill movement or grant an extra round**. Resume the affected component with a deterministic, fair order. The client receives a War Started / Your Turn / Waiting status. Host validates group eligibility on every action to prevent the attacking civilization from bypassing the new order.

**Unresolved first-strike policy:** To prevent severe unfairness when the defender has already pressed End Turn, either (a) give the attacker one immediate hostile action and then grant the defender a **reaction window with unspent actions only**, even if previously Ready; or (b) allow the attacker to use all remaining legal actions before the defender can respond. Both preserve previously spent movement and combat limits. Recommended **(a)** for a four-player strategy game; finalize before implementing the scheduler.

**War eligibility:** Units cannot attack another civilization unless active war permits it; attacking independent monsters or guarded neutral villages uses its own hostile/neutral rules. Peacetime border violations, if allowed, are diplomacy events rather than a loophole for warless conquest.

### 8.3 Networking and observation

Send sequenced authoritative events followed by observer-specific snapshots/deltas as needed. Separate command acknowledgements, player-visible playback, and private internal state. Reconnection should send a correct filtered snapshot plus at most a bounded recent public/visible event backlog. Network AI must not be tied exclusively to the hotseat local handler. Test disconnected/reconnected players, high-latency commands, race conditions and concurrent war transitions.

**Acceptance:** 4-player peaceful game accepts independent orders; A/B wartime scheduler is sequential while C/D act concurrently; overlapping wars merge war groups; ending wars splits groups at a defined boundary; illegal simultaneous collisions are rejected; no fog leaks; economy advances exactly once globally.

## 9. Diplomacy and Council

### 9.1 Relationships, grievances and stable diplomatic memory

Maintain pairwise opinions with explainable modifiers, persistent remembered grievances and positive cooperation: visible military pressure near borders, unpermitted crossing, settlement competition, promises honored/broken, trade assistance, protection against mobs, betrayals, surprise war, previous conflicts and mutual enemies. Distinguish **current military threat** from **trust/reputation**: pulling troops back can reduce immediate fear but doesn't erase a betrayed treaty. Some memories decay; severe breaches should last substantially longer. Fixed personalities weight these events differently; AI evaluation remains utility based.

States: Peace, Tension, War, Armistice; independent agreements: open borders, commerce, alliance, defensive pact, joint-war undertaking. Agreements carry explicit signatories, duration/expiry, obligations, state and rejection/violation outcomes; save their identity and status.

### 9.2 Defensive alliances: choice required — CONFIRMED

A defensive alliance does **not** automatically add allies to the war graph. When a member is attacked, each eligible ally receives a **Call to Arms** request and must accept or refuse; AI chooses deterministically from alliance strength, trust, military strength, opportunity, danger and personality. Refusal harms trust and may damage international reputation (severity depends on treaty terms); a valid acceptance enters the war through the standard war/join action and expands or merges connected turn groups through the scheduler.

Proposed flow: requests include attacker, defender, casus belli / surprise-war flag, response deadline measured in game rounds, explicit consequence preview and a reason for an AI refusal. Requests must remain pending through hotseat handoffs and network disconnections; expiration outcomes must be defined. Do not silently force a player into war. **Open:** whether accepted intervention is immediate (scheduler transition) or begins at next round boundary; recommend next-boundary entry except when an explicit immediate-response option is selected.

### 9.3 Structured diplomatic negotiations and peace proposals

Use host-validated offers with sender/recipient, terms, expiration, response and treaty execution. The conversation UI exposes dialogue choices and the actual offer terms; each side can accept, reject or counter when enabled. The AI assesses offer utility based on relationships, war progress, war exhaustion, resources, threats, promises and victory prospects. Price resources against the player's treasury and actual map holdings.

**Recommended initial peace terms:** immediate ceasefire / defined armistice, gold and strategic-resource transfers, and diplomatic promises (e.g. respect borders, withdraw troops); advanced city cessions can be a later extension because of large territory/save/UI implications. Negotiated peace should be more interesting than an unconditional "End War" button but remain practical on small touch screens. Reject impossible offers (insufficient treasury, resources, nonexistent cities, conflicts with other treaties) at execution.

### 9.4 Conversation interface

Offer event-driven contextual conversations with authored response options and deterministic effects. Topics: greeting, warning, apologize, promise troop withdrawal, trade, open borders, propose peace, offer alliance, request joint war, denounce and discuss Council votes. Show stated reason for attitude whenever that is player-visible. Avoid free-text generation and heavyweight NLP.

### 9.5 Council — CONFIRMED

Council periodically holds **leadership elections plus world resolutions**. Proposed resolution families: trade facilitations, embargoes, peace initiatives and diplomatic penalties. Resolutions must be bounded, temporary or reversible, and integrated into the host-authoritative rule engine.

Proposed victory format: require at least **two-thirds** of votes and a constraint preventing a single player from manufacturing victory only from trivial self-generated voting power. Count civilization delegates and limited village/influence contributions, subject to anti-farming rules; exact formula is **open**. Voters should make utility-based decisions reflecting allies, trust, interests, threats and desire to prevent a rival's victory.

**Acceptance:** Council votes are deterministic, explainable and correctly validated; AI votes according to incentives; embargoes/peace effects modify actual game rules; leadership victory respects enabled victory conditions; diplomacy works in 2-, 3- and 4-civ games without automatic wins from trivial friendship spam.

## 10. Research, cities, victories and economy UI

### 10.1 Research progression

At Standard duration, aim for **20–25% faster progression** via a balanced combination of lower technology costs and appropriate science yields; do not blindly multiply both. Proposed first implementation: reduce tech costs around 20% and profile actual age milestones. Carry excess science into subsequent progress if the adopted science accounting design allows; decide whether science remains tracked internally as a cumulative statistic while the HUD shows only rate.

Expand research descriptions with what the technology does strategically, prerequisites, unlocked units/buildings/wonders, gameplay impact and Codex-link buttons. On small screens, keep a pannable/zoomable **graph**, never replace the tree with a simple list; provide a compact detail drawer.

### 10.2 Economy and production

- HUD: **Science, Food and Industry show only net per-round rate**; keep city-specific production/growth details in inspector.
- Gold and stockpiled strategic materials show stock and only nonzero delta (`+N`/`-N`); hide unrevealed tech-dependent strategic stock categories until research requirements are met (without hiding map deposits by tech in this release).
- Preserve historical economy values internally until underlying accounting is deliberately migrated.
- Cities can explicitly select **No Production**, cancelling/pausing active production while preserving earned project progress; don't nag about intentionally idle cities.
- Increase clarity of working tiles, production selection and resource ledger.

### 10.3 Lobby setup and victory settings

- Quick / Standard / Epic adjust game deadline and appropriately scaled research, growth and production progression. Proposed baseline: Standard 180 rounds, Quick ≈110, Epic ≈270; tune against playtest outcomes.
- Provide checkboxes/toggles for allowed **Conquest, Industrial, End Expedition, Diplomatic**, and Score/fallback behavior (open).
- Show full civilization bonus descriptions and fixed AI personality tendencies during selection.
- Show each AI difficulty in lobby separately from hostile-mob difficulty.
- Expand map presets and show biome/map generation style options without overwhelming small monitors.

## 11. HUD, ownership and faction screens

- Move Research/Tech Tree access into top-right action bar.
- Put Next Idle Unit beside End Turn. Restrict persistent bottom bar to the width needed by inspector/turn controls so map gains vertical space.
- Add top-right **Factions** panel showing discovered civilizations, their visible cities and units, relations, wars, alliances, reputation and known bonuses; hide truly secret information.
- Assign distinct non-green player colors, with color-blind-friendly outlines/shapes. Make each unit's owner unmistakable via consistent badge/ring and in inspector.
- Show attackable units and unsafe destinations simultaneously with differentiated rings/colors/markers.
- Automatically wake units when real orders are issued; remove the need to use Wake before Move/Attack.
- Maintain mouse, touch-only advanced monitor, text fallback and compact viewport usability.

## 12. Suggested implementation sequence and PR boundaries

The sequence prioritizes underlying command correctness and a credible Prince AI before advanced diplomacy, while delivering visible feel early. UI tasks can run in parallel after architecture stabilizes.

| PR / workstream | Primary work | Exit gate |
|---|---|---|
| 01: Shared gameplay rules | Common validated actions, movement/founding/healing, pure combat forecasting, auto-wake, No Production | Identical legality for human and AI, no regression |
| 02: Biome worldgen | Climate/elevation/features, movement balance, resource eligibility, wonder placement, larger maps | Hundreds of seeds pass fairness and density tests |
| 03: Event backbone | Sequenced action events, visibility filtering and observer projections | No hidden-event leaks; multiplayer ordering stable |
| 04: Smooth animations | Interpolated movement, melee/ranged effects, death/city events, replay/skip | Smooth movement in path order; no sprite duplication or input lock |
| 05: AI strategic/economic | Goals, personalities, tech/production utility, city specialization, settlement targets | Prince builds coherent empires and legal plans |
| 06: AI tactical | Threat map, persistent campaigns, safe moves, roles, coordinated attacks, retreat/support | Prince defends/attacks coherently without suicidal defaults |
| 07: Hybrid turns | Peaceful simultaneous turns; wartime components; normal/surprise war transitions; no double turns; network AI | Mid-round surprise declaration safely re-groups only affected players |
| 08: Diplomacy | Persistent relations, defense calls with explicit choice, peace offers, treaties, conversation decisions | AI/human responses obey agreements; refusal and surprise war have lasting consequences |
| 09: Council | Leadership elections, resolutions, voting AI, diplomatic victory | Explainable votes; no trivial wins |
| 10: Research/lobby/HUD | Durations/victory toggles, graphical compact tree, Codex, economy HUD, faction UI | Touch-friendly layout and configurable campaigns |
| 11: AI difficulties | Settler/Chieftain/King/Deity variants built atop Prince and tests | Measurable behavior/competence differences, little or no cheating |
| 12: Release validation | Migration, integration, fuzz/seeded AI sim, multiplayer race/perf tests, installer metadata | Tests pass, responsiveness acceptable, saves upgrade |

*Scheduling note:* Workstreams 03–04 may precede or run alongside the AI foundation so animations and observable actions are testable early. War graph scheduling requires explicit diplomacy state even before full diplomacy UI lands. Use thin vertical slices for PR review.

## 13. Testing matrix and release acceptance

Core:
- Deterministic seed and save tests, including legacy map migrations.
- Hundreds of seeded world distributions checked for resource density, biome-specific eligibility, valid wonder spacing and fair starts.
- City founding legality with one or zero movement remaining; sleeping auto-wake and support-only external healing.
- Deterministic combat preview matched to resolution, including city wall/capture edge cases.

Presentation:
- Movement visually visits each path segment smoothly, without duplicate sprites.
- Audio/movement timers do not block touch controls, rednet messages or cooperative watchdog yielding.
- Player can skip action playback and animations can be disabled without loss of game state or reports.
- Unit owner is identifiable without reliance on green colors.
- Small screens retain a genuine visual research DAG with selection/pan/zoom.

Multiplayer and privacy:
- Hidden enemy paths and resources never appear in events, snapshots, replay, Codex or faction views.
- Three-or-four-way overlapping wars form correct connected turn groups.
- Normal War activates at next-round boundary; Surprise War activates immediately and only re-groups affected war participants, with no extra movement reset or double turn.
- Defender reaction windows (if adopted) and pending Call to Arms persist across hotseat handoff, save/resume and reconnection. Declining an alliance invitation has explainable diplomatic penalties; no implicit forced war.
- Simultaneous commands never bypass unit occupancy or action-cost validation.
- Fresh join and reconnect maintain correct public/private view.
- Hotseat handoff and observer recap are privacy-safe.

AI and balance:
- Same actions/rules as humans; no access to global hidden map during planning.
- Prince competently researches, expands, responds to threats, defends cities and attempts coherent victory goals.
- Stable plans persist through save/reload and temporary emergencies; AI reconsiders objectives only for meaningful new reasons and bounded periodic reviews.
- Tactical campaigns cooperate across multiple units rather than chasing independently; tactical utilities use only observer-legal information.
- Fixed personalities differ measurably over seeded runs, without disabling defensive/self-preserving behavior.
- AI-vs-AI seeds report win mix, progress rate, invalid action count and processing time; difficulty gains come primarily from decision quality.
- Diplomatic victory does not default to an automatic two-player win or simple delegate farming.

## 14. Open questions for the next design round

Newly **confirmed** in this iteration: Normal War activates at the next round boundary; Surprise War activates immediately with major diplomatic penalties. Defensive allies decide whether to join and face relationship consequences for refusing. AI retains a stable victory strategy, with event-driven and bounded periodic reassessment. Smooth movement remains the chosen animation style.

**Next decisions (recommended options marked):**

1. **Surprise first strike and reaction:** Should an attacker be permitted **one immediate hostile action before a defender reaction window** with only unspent movement/attacks (recommended for fairness), or continue using all remaining actions before the defender can respond? How should already-Ready defenders respond?
2. **Zone of control / tactical combat rules:** Keep existing movement/attack rules with substantially smarter AI only (**recommended for this update**), or add a lightweight zone of control that limits movement adjacent to hostile units?
3. **Pre-war military campaigns:** Allow AI to muster forces and approach borders visibly before formal war (**recommended**, triggering warnings and threat responses), or require major army movement toward enemy borders only after war starts?
4. **Peace terms:** Implement ceasefire + gold/resources + temporary promises/armistice (**recommended**), or also allow transferring ownership of cities immediately?
5. **Observed action playback:** Auto-animate observed **onscreen** activity in network play and show optional Watch buttons for offscreen activity; show a Play/Skip recap on hotseat handoff (**recommended**). Alternative: exclusively user-initiated event feed in both modes.
6. **Council math and timing:** Delegate allocations, two-player voting safeguards, interval, resolution costs and required supermajority (still open).
7. **Foreign territory:** Block peaceful entry without open borders, or permit incursions with grievances (still open).
8. **Score:** Toggleable independent victory or fixed deadline fallback (still open).

### Interaction dependencies to verify before implementing

- Surprise War re-groups connected war components immediately, but must not regenerate movement, allow an illegal second turn, or leak planned movements.
- Call to Arms is not forced entry into the war; acceptance and its activation timing must be made explicit and coordinated with the same scheduler.
- Cinematic/event presentation is independent of the authoritative simulation and opponent-specific visibility; the observer's event-time visibility is authoritative for replay.
- AI pre-war mobilization can be perceived from legally visible units and should affect diplomatic threat calculations without silently becoming active war.

## 15. Explicitly deferred (not in this release)

- Hide resource *deposits on the map* until their unlocking technology has been researched (distinct from hiding resource stock categories on the HUD).
- Fully dynamic AI personality assignment: fixed mapping is the agreed rule.
- Real-language, model-powered conversations; stick to designed dialogue choices and deterministic effects.
- Heavyweight tactical search, omniscient AI, or graphics workloads outside practical CC:Tweaked limits.

---

**Definition of completion for the design phase:** Resolve the open mechanics above; set numeric goals for game duration, map sizes, resource density and animation timing from initial benchmark scenarios; convert these workstreams into scoped issues/PR acceptance criteria; then publish a finalized Markdown specification.
