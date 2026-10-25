# CivCraft roadmap implementation

Source: [design draft v0.9.1](ROADMAP-v0.9.md). Open design choices remain open; proposed balancing values are not confirmed requirements. Work is on `codex/civcraft-roadmap`.

## 01: Shared gameplay rules

Implemented locally:

- `actions.lua` owns gameplay-order validation and execution. Local/remote human requests, AI research/production/staffing/trading/envoys, movement, founding, city strikes and engineer orders use it. Session startup, ready-state transitions and persistence remain in `game.lua`; wilderness monsters keep their separate local-sight rules.
- Settlers have three base movement points, pay one on ordinary land and require positive movement remaining to found. Founding checks ownership, terrain, landmarks, camps and city spacing before consuming the unit. Cavalry difficult-terrain cost is capped at two.
- Valid movement/attack/rail orders wake sleeping units. Invalid orders preserve sleep. The inspector allows orders without a manual Wake step.
- Both passive and support healing require the receiving unit to be in its own territory, following the user's 25 October clarification.
- `Combat.predict` is pure, includes HP, wall loss, retaliation, deaths and capture, and supplies the result applied by combat resolution. Unit attack previews show predicted remaining HP and walls in the status line.
- No Production preserves project progress and suppresses deliberate-idle reminders. Selecting production resumes saved work.
- The installer package includes the new action module.

Save compatibility: save schema remains version 6. The only new persisted gameplay field is optional `city.productionIdle`; absent means the existing idle/reminder behavior. Existing world terrain, resources, claims, seed and dimensions stay intact. Stored movement budgets are preserved when loading; the new settler allowance applies at the next normal reset and to newly produced units. No migration grants extra movement mid-round. Future world generation and diplomacy changes need explicit independent versions and migration tests before landing.

Validation: new command tests cover human/AI founding parity, failed orders, movement costs, support healing, paused progress and 180 pure combat forecasts. New text/graphics UI checks cover No Production confirmation, sleeping orders and forecast confirmation. Seeded progression scenarios separately exercise expedition-oriented and industry-oriented AI; the mixed-goal campaign now allows an earlier legal Industrial victory after faster expansion. Automated checks do not establish actual monitor performance, live rednet behavior or multiplayer privacy under races.

## 02: Biome world generation

New campaigns use generation version 2, with separate `biome`, `elevation` and `feature` records in `world.geography`. `world.tiles` remains a terrain projection for existing mechanics and save readers. A read-only adapter supplies layered information for old terrain strings. Loading an existing world does not regenerate or fill its deposits, terrain, wonders or starting locations.

The generator uses private seeded PRNG streams and smooth macro height, elevation, temperature, moisture and vegetation fields. It targets 17.5% deposits as an initial balance setting; habitat rules select each deposit, with rarer redstone and diamond. Every start has immediate grain and non-snowy hill iron, a passable first ring and at least 18 connected land tiles within three hexes. Repairs preserve surrounding climates where possible. At least 55% of traversable land is open; ordinary combined difficult terrain remains capped at two movement points.

Natural wonders choose shuffled eligible habitat candidates with geographic separation. Spawn buffers scale from five hexes on Compact to six on Standard and eight on larger maps; separation is three or four hexes. Habitat availability determines wonder variety rather than forcing every wonder into every world. Mushroom landmarks create rare mushroom-field patches before resource allocation. Constructed wonders retain their existing production and uniqueness rules.

Terrain rendering, minimaps and tile inspection use the new layers. Woodland can appear on a hill, snowy land and coasts have their own palette, and the terrain sprite cache is bounded. Observer snapshots filter geographic records by discovery just like terrain and resources. New deposit visibility is not gated by technology.

Added Huge (48×32) and Vast (64×40) to the lobby. Existing Compact (18×12), Standard (28×18) and Large (40×26) remain available. Cooperative checkpoints cover generation, snapshot rows and large territory loops.

Validation:

- 600 generated worlds spanning all five sizes, four map types and 2–4 civilizations passed density, habitat, traversability, climate coherence, fair-start, wonder-spacing and fog checks. Across that matrix, open traversable land was at least 55%, matching neighbouring biomes averaged 69%, and every map had at least one eligible wonder.
- Lua 5.2 and Lua 5.3 generated identical data for 40 additional seed/settings combinations.
- All 52 repository regression scripts passed with a Lua 5.3 runtime and the repository's existing `bit32` compatibility shim. A renderer preview was visually inspected. These are local automated/rendered checks, not live multiplayer or monitor validation.
- Run `lua5.3 tests/civcraft_world_benchmark.lua` for reproducible desktop timing output. See [WORLDGEN-BENCHMARK.md](WORLDGEN-BENCHMARK.md) for the measured scenarios and limitations.

## 03: Action events and observer snapshots

Implemented locally:

- Version 1 observer journals retain up to 128 entries with an age limit of eight rounds. Movement, combat, capture/defeat, founding, disbanding, rail work, unit production, completed buildings/wonders, research and landmark discoveries emit action-time records. Research and administrative orders are private to their issuer.
- Each movement segment updates exploration and records who could actually see that position. Observer projections split paths at fog boundaries, omit hidden origins/endpoints and never reconstruct them from later exploration. Partially observed combat sends either an impact without its concealed attacker or visible actor activity without the concealed target. Only explicitly supported fields and event categories survive projection.
- The host assigns observer-local sequence numbers, so a recipient cannot infer the count of hidden actions from sequence gaps. The host retains no separate unrestricted raw-action history. Trusted host saves contain the observers' bounded journals; snapshots contain only the receiving observer's `eventStream`.
- Snapshots have per-observer transport serials and host-session identifiers. Receivers reject duplicates, stale snapshots, retired sessions, malformed streams and streams belonging to another observer. Campaign changes reset replay windows; received windows merge before acknowledgement so a fast empty snapshot cannot erase queued presentation data. Old protocol peers remain usable without the new replay guarantees.
- Host UI and network commands pass through one bounded cooperative queue, including snapshot construction. A yielded rule calculation or snapshot cannot interleave another mutation; overflow returns a retry result. Event acknowledgements cannot create a publication loop. New network orders include campaign/round context so stale commands cannot spend a new round's movement. Remote Save asks the host to persist its authoritative state.
- Visible rival cities/units use public-field snapshots instead of copying production, worker allocation or auto-exploration plans. Public combat ratings keep remote forecasts consistent without transmitting the hidden army that contributes to city strength. Melee attacks physically follow their approved approach, and ranged attacks cannot use an untraversed path to shoot outside their actual range.
- Version 1 map-memory records preserve last-observed rails, landmarks and camps while terrain is in explored fog. Rival construction and camp clearing stay private until re-scouted, in both network snapshots and local map/inspector rendering. Old saves preserve terrain/deposits; unknown dynamic infrastructure is not invented during migration. Immutable natural landmarks can restore previously explored knowledge.
- The package manifest installs all new runtime modules.

All 54 repository regression scripts passed. Automated evidence includes privacy and temporal-order assertions, interrupted command/snapshot coroutines, replay bounds/cursors, stale/malformed packets, hidden infrastructure and text/graphics inspector checks. Three checks passed together in a fresh native CraftOS-PC profile: the core event suite, actual renderer/button calls with filesystem serialization/reload, and a complete game session. That session uses real mouse events to traverse the paged lobby, initial reports, two human turns and private handoffs, round processing, pause, save and exit. See [NATIVE-TESTS.md](NATIVE-TESTS.md) for isolated reproduction and exact boundaries. These do not yet prove multi-client rednet behavior, physical monitor input or animation responsiveness. The visible replay/feed and interpolation controller belong to workstream 04.

## 04: Presentation playback

Implemented locally:

- Separate timing and frame-projection modules animate only frozen observer events. Movement interpolates actual approved hex centers at a nominal 120 ms per hex; concealed gaps disappear rather than drawing an invented connecting path. Melee uses a lunge and return/advance, ranged attacks use a projectile, impact changes the displayed HP, defeated units briefly disappear, and founding/capture use contextual effects. Research and other notices retain feed summaries.
- Static instances of animated entities are suppressed, including entities with later queued actions. Animation never changes positions, HP, movement budgets or turn order. Local display snapshots detach all nested tables from host state; cooperative rendering cannot read a partially mutated host entity. Host display snapshots are cached by state revision. Animation-only redraws do not broadcast new network snapshots.
- Observer-safe actions play automatically one at a time, and the camera follows the current action. There is no handoff replay question. Returning players automatically receive their permitted deferred actions after private handoff/report screens; modal/pause screens suspend timing without consuming the animation. The optional event feed remains available for manually reviewing prior observations.
- The observer's own auto-explore movement is excluded from playback. A private event-time flag distinguishes automatic travel from a manual order overriding exploration; other observers do not receive that order metadata. Normal/Fast/Off and reduced motion remain separate from campaign/audio data. Reduced motion and Skip retain non-excluded summaries.

- Presentation queues are capped at 32 events, summaries at 128 and age at eight rounds. Motion is discarded first under pressure so combat/founding summaries survive motion bursts. Queues accelerate under backlog; monotonic elapsed time prevents frame rewinds. Timers request redraws cooperatively rather than blocking the command loop.

The user's 25 October clarification supersedes the earlier optional/onscreen playback proposal: automatic playback also follows offscreen observed actions. See [FOLLOWUPS-v0.9.md](FOLLOWUPS-v0.9.md). Future diplomacy and Council effects must accompany their respective workstreams.

All 56 repository regression scripts passed, including the recap. Tests cover a five-hex timeline, fog gaps, ranged/melee phases, HP/fade timing, stale duplicate ingestion, queue bounds, age, skips and detached nested data. Text/graphics UI checks cover automatic playback, one rendered sprite, feed controls, reduced motion and private recaps without reconstructing concealed paths. Four native CraftOS-PC checks passed together in an isolated profile. The latest text playback traversed six hexes at 13 distinct positions across 14 draws in 0.806 seconds, then accepted Skip without losing the feed. This measures the default 51×19 text backend; native GUI/graphics animation, physical monitor input, frame pacing on larger displays and live rednet races remain release-validation work.

## 05: Strategic and economic AI

- Civilization archetypes have fixed aggression, ambition, risk, diplomacy, loyalty and border preferences, separate from difficulty. Values are initial tuning settings. Scholars prefer End Expedition, Engineers prefer Industrial and Miners prefer Conquest. Merchants use Industrial until Council victory exists; their diplomatic preference is retained for that later workstream.
- Optional version 1 `player.aiPlan` saves the primary goal, objectives, priorities, revision/review rounds and city specializations. A review occurs every ten rounds or on city loss, a treasury shock, decisive technology, newly urgent public rival progress or an explicit strategic signal. An incumbent survives unless a challenger exceeds a substantial utility margin. Seeded goal tie-breaks do not consume global randomness.
- Bankruptcy, a visible threat near the capital and urgent public rival progress add emergency priorities without replacing the primary goal. Economic decisions now consume these priorities and city specializations; coordinated tactical execution belongs to workstream 06.
- The director receives `World.forPlayer` output, so an undiscovered nearby army cannot trigger its emergency assessment. Rival snapshots omit saved plans. Research/final-project preference now follows the saved goal instead of computer-ID parity.

Economic execution now adds:

- Scored legal technology candidates evaluate building/unit unlocks, known material access, missing victory prerequisites and projected completion time. Scored buildings, units and optional wonders compete using expected yields, urgency, affordability, remaining production time and prerequisite value. Normal investments finish before being replaced; food/defense/treasury emergencies may redirect them. Idle cities reconsider needs on later turns, preserving deliberate No Production when no useful project is available.
- City roles cover science, industry, military, commerce and infrastructure. They use observed workable yields, capital defense and network centrality and remain stable between strategic reviews. Worker orders secure food first, then optimize the assigned role through ordinary work-tile commands. No hidden deposit contributes to a score.
- Bounded weighted routes use discovered terrain and observed occupancy. Settlers save version 1 destinations and routes, reserve sites against other friendly settlers, evaluate yields/materials/wonders/spacing/connectivity/visible pressure and replan after obstruction. Rejected orders stop; positive movement remains required for founding. Surviving settlers may rebuild after losing the last city. The shared human/AI founding rule also rejects foreign-owned territory.
- Engineers save version 1 city-link plans, preserve endpoints across turns, navigate around obstacles and build through the shared action executor. Material trades target current projects and rail/mixer shortages, cap purchases per turn and preserve an upkeep reserve. Approaching insolvency produces an economic emergency before the automatic disband boundary.
- Research, production, staffing, settlements, infrastructure and village decisions read detached observer knowledge. Military candidate generation and city-strike target enumeration also use permitted observations; exact forecast-driven tactics and campaign coordination remain in workstream 06.

All 58 repository regression scripts passed. Economic scenarios additionally cover food-secure roles, treasury pressure, intentional idle/resume, multi-round settlement detours, failed movement, invisible-world changes, rail persistence and purchase limits. The current seeded Scholar and Engineer scenarios won by expedition in round 93 and industry in round 137. CraftOS-PC passed the economic scenario suite, rendering/save smoke test and a full mouse-driven two-human/one-AI game session, including persisted AI planning. See [AI-EVALUATION.md](AI-EVALUATION.md) for timing scope and limitations.

## 06: Threats and tactical campaigns

- Confirmed danger maps derive only from visible combatants and functioning visible city walls. They estimate next-turn reach and damage; remembered sightings are separately capped/aged AI uncertainty and never contribute to the human danger overlay. Move destinations show amber warning marks separately from red attack targets, with estimated exposure in the preview.
- Tactical shortlists use the same pure `Combat.predictOrder` forecast as human previews and resolution, then score retaliation, kills/capture, wall damage, next-turn exposure, survival, objective progress, support and personality risk tolerance. Damaged units withdraw toward owned land; support placement respects owned-territory healing. Rejected candidates trigger bounded replanning through the shared executor.
- Optional version 1 unit roles cover capital garrison, scout, settler escort, screening, main army, ranged/siege support, healer, engineer and fleet roles. Version 1 campaigns persist target identity, last observed position/walls, group ID, muster point and known approach corridor. Campaign phases distinguish defense, muster, approach, siege and regroup. Unknown current target changes cannot update remembered coordinates.
- Fortified objectives request siege even at an ordinary army quota; damaged groups request support, and coastal/naval observations influence shipyard/fleet demand. Deterministic action order lets ranged/siege fire soften targets before melee and support repositioning.

All 59 repository regression scripts passed. Focused scenarios verify exact forecast application, safe ranged focus fire, retreat instead of lethal attacks, private threat memory, persisted fortified objectives, siege/support demand and text/graphics danger previews. Five native CraftOS-PC checks passed together, including the tactical scenarios, event privacy/auto-explore tagging, animation timing, real rendering/save smoke and a complete human/AI session. Live modem scheduling, large-army quality/balance, wider campaign recovery and physical graphics/monitor validation remain release checks.

Confirmed scheduler choice: a Surprise War attacker uses **all remaining legal actions** before the defender responds. Spent movement and attacks remain spent.

## Device settings followup

A dedicated Settings screen is accessible from the title and pause menus. It persists master sound, independent title music, speaker volume, Normal/Fast/Off animations, reduced motion and Auto/Text display preference. Changing display mode recreates the renderer while preserving buffered input and activation/diagnostic callbacks. Settings suspend animation timing and return to the existing title/pause screen without changing the campaign. Device audio actions do not trigger host-state publications.

Focused text/graphics checks cover every control, persistence, independent music/effects, volume gain, display fallback and Back. Native CraftOS-PC passed the settings scenarios and a full mouse-driven session with AI, animation-speed changes and two renderer recreations, including settings/AI-plan/save reload. Native headless validation remains a text-backend check; physical monitor and GUI pixel validation are still separate release work.

## Lua style and upstream integration

The user's governing guide is the [Roblox Lua style guide](https://roblox.github.io/lua-style-guide/), replacing the earlier LuaRocks reference. After rebasing, the user authorized updating `.stylua.toml` to align with the Roblox guide: tabs displayed at four columns, a 100-column target, double-quoted strings and expanded blocks. `.editorconfig` and repository documentation match; the repository was reformatted with AST verification. Modified code follows the guide's readability, expanded blocks, double-quoted strings and camelCase naming where introduced; existing save/API names remain compatible. New code remains ordinary Lua, without Luau-only syntax.

Rebased onto `main` at `3a7518b` after PR #47 merged. Formatting conflicts were resolved through normalized three-way merges and checked against the pre-rebase implementation; upstream fixes and Selene annotations were retained. Use the repository's `.stylua.toml`, `selene.toml` and `cc-tweaked.yml` for all future work. StyLua 2.6.0 verifies formatting and Selene 0.32.0 checks the branch. The local Selene build enables `selene-lib/lua52` and `selene-lib/lua53` so the full CraftOS standard library loads without the prebuilt macOS binary's diagnostic. Refresh and rebase against `main` again before the final PR if it advances.

## HUD, lobby and faction follow-ups

Science, food and industry now show per-round rates in the HUD and ledger. Material stocks appear only after their technology unlocks, with signed rate suffixes only when nonzero. Lobby selection exposes the actual civilization bonus on compact and wide displays. Four shared gold/cyan/ivory/rose faction colors apply consistently to units, territory, animation and overview; bitmap sprites honor the faction tint.

Research and faction details occupy the top-right bar. Next Idle Unit sits beside End Turn inside the inspector-width footer; the map extends into the freed vertical space. The faction panel shows public civilization bonuses, AI archetypes and age, plus own totals or currently visible rival forces. Hidden economy and AI plans are excluded. Focused controls checks cover 18 monitor/mode combinations, and a native two-human/one-AI session passes with Settings persistence and save reload. Campaign duration and victory controls still belong to workstream 10.

Research now retains a connected, draggable prerequisite graph on compact text and graphics displays, with pan/zoom buttons for touch input. The detail view scrolls full explanations, gives every technology an authored purpose and derives project effects from the actual content. Unlock buttons open the corresponding building, unit or wonder Codex entry. The large canvas also offers these details. All 61 regression scripts pass; native CraftOS-PC passed the compact graph scenarios and a real mouse-driven graph/details/Codex/research flow before completing both hotseat turns, an AI turn and settings/save reload. The test driver pages back to the preserved Research action after returning from the Codex.

## Campaign duration and victory options

Campaign Options in both lobby layouts selects Quick (120 rounds, two-thirds costs), Standard (180, unchanged costs) or Epic (270, one-and-a-half costs). Research, production including escalating settler costs, food growth thresholds, minimum growth time and the Industrial victory timer use the same scaling helper. Movement, attacks, yields, upkeep and material consumption keep their normal per-round rules. UI costs, estimates and AI research/production scoring consume the scaled costs.

The host chooses Conquest, Industrial, End Expedition and Score independently before starting; at least one remains enabled. Disabled conditions cannot win, and AI plans select from enabled goals. At the deadline, an enabled Score condition resolves the highest score; otherwise an unresolved game ends in a draw, as explained in the menu. Council remains a later workstream. The resource ledger shows the chosen length and enabled victories.

Optional `gameSpeed` and `victories` fields remain compatible with schema 6. Migration gives old campaigns Standard progression while retaining their saved deadline and map; each player's pace is synchronized from the campaign for shared cost APIs. Observer snapshots copy the public options without aliasing the host's table. Host validation rejects unauthorized edits, invalid values, edits after launch and disabling the last victory. All 62 regression scripts pass. Native CraftOS-PC passed rule scenarios and a mouse-driven lobby that selects Quick and disables Score, then completes research/Codex navigation, two human turns, an AI turn, settings and save reload.

## 07: Hybrid turns and declarations

Peaceful civilizations act independently through the serialized host command queue. Active wars form connected components, each with one eligible civilization. Each component rotates its starting player each round; independent groups keep progressing separately. Every human and AI gameplay order checks the same scheduler, and End Turn advances its component without resetting movement. Economy, growth, research, production and victory advance only after all participants and response windows finish.

Normal War is announced now and activates at the next global boundary, before round effects. Surprise War activates immediately, merging only affected components and retaining the attacker's remaining-action window until End Turn. An already-ended defender keeps Ready recorded but receives one response window using only its remaining budgets. No declaration refreshes movement, attack limits or production. The faction panel exposes explicit declaration choices and their initial reputation/trust penalties; turn status and group order are visible. Peace takes effect at a specified boundary; negotiation UI belongs to workstream 08.

Combat forecasts, actual attacks, movement attack overlays, city strikes, sieges, danger maps and AI military targets respect active war. Independent monsters and guarded villages retain their separate rules. Conquest AI can announce a normal war through the shared action executor when it has a field army and an observed foreign city. The host AI runner operates in both local and network modes, including transitions that activate an AI. Network hosts can add/remove AI civilizations in the lobby.

Optional version 1 diplomacy and scheduler records persist war edges, turn order, reactions and diplomatic penalties in schema 6 saves. Loading a pre-diplomacy campaign imports its former unrestricted foreign hostility as active wars, without penalties, preserves its current hotseat participant where eligible and retains all spent actions/Ready locks. Public snapshots detach war/order data and omit other parties' private relations. Migration is idempotent.

The 63-script regression suite passes. Scheduler scenarios cover all 64 four-player war graphs, separate/merged/split groups, fair rotation, normal activation, Surprise War against an ended defender, unrelated active participants, illegal inactive declarations, shared attack legality, legacy migration and snapshot detachment. Native CraftOS-PC passes the scheduler scenarios and a complete mouse-driven Surprise War/hotseat/AI session, including saving during the defender's response. A separate real host-mode session adds an AI through the network lobby and completes its turn and save reload. These headless tests use the text backend and no modem; live remote clients, reconnect races and physical displays remain release validation.

## 08: Diplomatic memory, offers and conversations

Pairwise trust and grievances retain bounded explanations plus aggregated lasting effects; temporary modifiers expire without losing their expiry accounting when explanations are compacted. Observed military pressure is assessed separately from trust, using only visible forces near the observer's cities. Pulling back removes current pressure but does not erase a betrayal. Observed unpermitted crossings, nearby settlement competition, protection against mobs, cooperation, treaty breaches, past wars and withdrawal promises affect relations. Fixed personalities weight witnessed Surprise War reactions differently.

Host-validated offers support gold/material exchanges, open borders, commerce, alliances, defensive pacts, joint-war commitments, armistices and withdrawal promises. Agreements record signatories, identity, duration and status. Trade acceptance rechecks both inventories before any transfer; it cannot execute twice. Counteroffers replace a pending trade without transferring resources. Commerce adds two gold per partner per round through the actual economy; open borders suppress crossing grievances. Ending agreements early has stated consequences. Peace starts at the next boundary and records a finite armistice; Surprise War can breach it with lasting penalties.

Defensive pacts create explicit Calls to Arms with a round deadline and refusal consequences. They never force entry. Acceptance schedules intervention at the next boundary without replenishing actions; rejection or expiry harms trust/reputation. Conflicting alliances must be ended explicitly. If peace makes an invitation obsolete, it is withdrawn without punishing the ally, and a pending intervention is cancelled before activation. Active joint-war commitments record a separate-peace breach; simultaneous coalition peace does not arbitrarily blame one participant.

Conversations are accessible through each faction's Talk button. Authored topics cover greeting, warning, apology, denunciation, trade, borders, peace, alliances, defense, joint war and withdrawal. Players see actual terms, pending responses, AI acceptance/refusal reasons, attitudes, remembered causes and agreement states. Repeated greetings cannot farm trust. AI decisions use their own treasury, supplies, known deposits, observed forces, own war progress and fixed personality. Diplomatic replies remain possible after End Turn but do not grant unit actions. AI withdrawal promises take priority over exploration and route through normal movement; verification uses the recipient's observations after two following rounds. Private offers, treaty identities, drafts and other parties' relations remain private, including across hotseat handoffs and campaign switches. Council-vote discussion belongs to workstream 09.

Optional version 1 diplomacy records gain offers, treaties, pair-scoped offer counters, promises and armistices; existing schema 6 saves normalize missing collections without replacing their worlds or budgets. Public war records whitelist fields and expose only the observer's own starting-city baseline, not private intervention source IDs or rival counts.

All 65 regression scripts pass. New scenarios cover transaction validation, double-response rejection, counters, private snapshots, active/expired commerce, explicit defense acceptance/refusal/expiry, armistice breaches, obsolete interventions, joint-war obligations, pressure versus memory, border permissions, AI withdrawal, invalid trade amounts and compacted memory expiry. Six text/graphics conversation layouts verify controls, actual AI trade responses and private-draft resets. Native CraftOS-PC passes the diplomacy scenarios and a complete mouse-driven conversation/trade/commerce plus Surprise War/hotseat/AI session, including a mid-response save and settings/research/campaign reload. A separate native host-mode conversation session passes. These are text-backend tests without live modem traffic.

## Remaining workstreams

09. Council elections, resolutions and diplomatic victory.
10. Remaining display integration, faction diplomacy controls and larger map presets.
    New 25 October requirements also include settler capture/stacked escorts,
    queued multi-turn movement, immediate sharp labels after zoom, frozen grey
    fog memory, the top-right reverse-chronological Event Log and replay pauses.
11. AI difficulty variants after the Prince baseline.
12. Save/integration/fuzz/performance/network validation and release metadata.

Remaining foundation concerns: physical monitor and live rednet verification, plus the remaining requirements in FOLLOWUPS-v0.9.md. Native CraftOS-PC event, rendering and save checks complement the automated suite. Public city/unit ratings resolve the earlier hidden-army forecast mismatch; event-time path projection resolves replay visibility, and detached local display snapshots separate simulation from cooperative rendering.

The full roadmap is not complete. Target-server CC:Tweaked and live rednet validation is still required; do not treat these commits as a v0.9 release.

### Conversation redesign and first contact

Seeing a foreign civilization's city or unit establishes persistent, mutual first
contact. Only the two participants receive a first-contact notice; foreign contact
networks remain private. Conversation, proactive offers and war declarations are
host-validated against contact, and joint-war offers require both parties to know
the named opponent. Unmet factions display placeholders in the faction screen.
Existing campaigns discover contacts from their current normal vision, without
revealing hidden map information.

The conversation UI now embeds real Basalt TabControl, List, Input, Dropdown and
Dialog widgets in the existing text/graphics canvas and event loop. Talk, Deals,
Agreements and Messages are separate tabs; relationship explanations, treaty
consequences, message responses and trade reviews open focused modal dialogs.
The trade editor supports numeric keyboard/paste input and editable counteroffers.
Compact graphics use shorter captions and scroll only the relevant editor;
large screens use a centered bounded panel. Escape closes the active dialog first.
Hotseat and campaign changes destroy the private widget tree and trade draft.
The pinned, unmodified upstream runtime and provenance live under `vendor/`.

New contact tests verify private one-time notices, persistence, city/unit encounters,
zero/negative computer IDs and rejected unseen diplomacy. Six layout scenarios
exercise actual widgets, numeric editing, review/send, treaties, messages,
counteroffers and private draft clearing. Native CraftOS-PC runs those scenarios
and a host-mode full session with contact, commerce/trade, settings, research,
campaign options and save reload; the hotseat session also exercises Surprise War.
Native contact fixtures put capitals in actual sight rather than bypassing contact
validation. Graphics review captures the actual renderer with instrumented displays;
it does not establish physical monitor or live modem behavior.

### Compact inspectors and faction contrast

Cities now separate Overview, Jobs, Tiles and Production. Population/growth,
yields, health and city strikes appear in Overview rather than preceding every
production or tile-management action. Narrow inspectors arrange the four tabs
in two rows; extremely short sidebars open the existing full-screen inspector.
Compact unit inspectors separate actions and secondary statistics. Status feedback
occupies a dedicated strip below the map, and the removed header status row makes
room above it. The turn footer still has its previous two controls; replacing
those with the unified required-task button remains a separate follow-up.

Four dedicated palette entries (amber, violet, pink and azure) are reserved for
civilizations and are absent from all biome fills and terrain details. Their
terminal fallback colors are also outside the terrain mappings. Borders have
dark edging, and city/unit markers retain a dark backing during normal rendering
and playback. Both graphics pixel lookup paths now cover the complete palette.

Eight affected layout/rendering regression scripts pass, including eighteen
monitor/mode control layouts, fog privacy, sprite tinting and all-biome palette
checks. A fresh isolated CraftOS-PC full session passes contact, conversations,
Surprise War, hotseat handoff, settings/research/campaign options and save reload.
The actual graphics renderer was captured at 57x38 text cells for visual review.
These remain instrumented graphics and native text checks, not physical-monitor
or live remote-client validation.
