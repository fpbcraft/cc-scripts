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

Conversations are accessible through each faction's Talk button. Authored topics cover greeting, warning, apology, denunciation, trade, borders, peace, alliances, defense, joint war and withdrawal. Players see actual terms, pending responses, AI acceptance/refusal reasons, attitudes, remembered causes and agreement states. Repeated greetings cannot farm trust. AI decisions use their own treasury, supplies, known deposits, observed forces, own war progress and fixed personality. Diplomatic replies remain possible after End Turn but do not grant unit actions. AI withdrawal promises take priority over exploration and route through normal movement; verification uses the recipient's observations after two following rounds. Private offers, treaty identities, drafts and other parties' relations remain private, including across hotseat handoffs and campaign switches. Council-vote requests and voluntary pledges are implemented in workstream 09 below.

Optional version 1 diplomacy records gain offers, treaties, pair-scoped offer counters, promises and armistices; existing schema 6 saves normalize missing collections without replacing their worlds or budgets. Public war records whitelist fields and expose only the observer's own starting-city baseline, not private intervention source IDs or rival counts.

All 65 regression scripts pass. New scenarios cover transaction validation, double-response rejection, counters, private snapshots, active/expired commerce, explicit defense acceptance/refusal/expiry, armistice breaches, obsolete interventions, joint-war obligations, pressure versus memory, border permissions, AI withdrawal, invalid trade amounts and compacted memory expiry. Six text/graphics conversation layouts verify controls, actual AI trade responses and private-draft resets. Native CraftOS-PC passes the diplomacy scenarios and a complete mouse-driven conversation/trade/commerce plus Surprise War/hotseat/AI session, including a mid-response save and settings/research/campaign reload. A separate native host-mode conversation session passes. These are text-backend tests without live modem traffic.

## Remaining workstreams

09. Council elections, resolutions and diplomatic victory are implemented below.
10. Final display/diplomacy interaction audit.
    Larger presets are implemented below; the final integrated interaction
    audit remains. Frozen grey fog, event history, replay pauses, capture, attached escorts,
    queued movement and sharp zoom labels are implemented below.
11. Five AI difficulty variants are implemented below; broader balance sampling remains release work.
12. Save/integration/fuzz/performance/network validation and release metadata.

Remaining foundation concerns: physical Minecraft monitor/target-server verification, release validation, and the remaining requirements in FOLLOWUPS-v0.9.md. Native emulated monitor and three-computer modem sessions now pass, as documented in NATIVE-TESTS.md. Native CraftOS-PC event, rendering and save checks complement the automated suite. Public city/unit ratings resolve the earlier hidden-army forecast mismatch; event-time path projection resolves replay visibility, and detached local display snapshots separate simulation from cooperative rendering.

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

### Unified turn decisions and Skip Turn

A single primary footer button resolves remaining decisions in this order:
awake idle units, cities without production, and unassigned available research.
Its text changes between Unit Orders, Production, Research and End Turn. It
navigates to the relevant unit or production inspector, or the research tree,
without arming movement. Extremely short sidebars use the full-screen inspector.
No Production satisfies a city decision. Sleep, automatic exploration and spent
movement do not create idle-unit reminders. Waiting/Ready players cannot use the
button to gain an extra turn.

Skip Turn is a host-validated unit order, with ownership, identity, round and
scheduler validation. It retains movement/attack budgets, cancels previous
sleep/heal/exploration intentions and records only a temporary attention stamp.
A rejected new order retains the skip; an accepted unit order clears it. Optional
`unit.skippedTurn` persists through saves and private snapshots. The stamp expires
on the next round, and distinguishes the Surprise War response from the ended
normal turn so a defender can use only its remaining actions in that new window.
No loading or skipping action replenishes movement.

The focused text/graphics workflow test exercises the actual primary controls,
Skip Turn, No Production, research assignment and final end dispatch. Rule tests
cover foreign/stale unit targets, invalid/valid new orders, stored skips, round
expiry, Ready locks and response windows. The native full-session driver now
resolves decisions through actual mouse input instead of End Anyway. Both the
hotseat/Surprise War and host-with-AI sessions pass, including real trades,
settings/research/campaign controls and save reload. The host result also asserts
saved skip orders and resolved human production/research (`turnTasks = true`).

### Zone of control and discovered-route interruption

Known hostile melee land units control adjacent passable land. Naval combat units
control water; cities control both domains. Ordinary ranged land units, civilian
and support units do not exert control. Mounted units ignore control. A military
unit entering control retains movement for a legal attack but cannot move again
in that turn window; civilian/support entry spends the remaining movement.
Starting a fresh normal turn or Surprise War response removes the prior movement
lock without granting any movement beyond the scheduler's existing budget.
Current geography has no river-edge representation, so river exceptions are not
claimed. Linked settlers inherit mounted/naval-raider escort immunity; other
formations stop when either member enters control.

The same control map governs human/AI reachability and pure approach forecasting.
Movement resolves each actual step, revealing normally before considering newly
observed control. Hidden units and cities no longer block an ostensibly unknown
preview through authoritative-only occupancy checks. A newly discovered obstacle
or control zone can stop the actual route. Shared actions charge the traversed
terrain and applicable civilian control penalty, retain an unused attack when an
approach is interrupted, and return an interruption reason. Frozen move events
end at the actual position; an aborted approach creates no combat event. Amber
rings and the selected destination summary identify known stopping tiles.
Optional `unit.zoneEnteredTurn` survives saved/private own-unit state and expires
by turn-window identity. No new field reveals a hidden foreign control source.

Attack eligibility is extracted into pure `hostility.lua`, shared by diplomacy
and control, so pathfinding does not reload the full negotiation dependency graph.
A native full-session startup initially hit the watchdog with that redundant
loading; it passes after the extraction. Native CraftOS-PC also passes the
control-rule scenarios. Regression scenarios cover attack-after-entry, forecast
parity, civilian exhaustion, cavalry, naval/land domains, peace, private snapshots,
unseen guard discovery, actual travel charging and interrupted attack approaches.
The complete native hotseat/AI/Surprise War session passes settings, research,
campaign controls, conversations, turn decisions and save reload. Physical
monitors and live remote-client transport remain release validation.

### Embarked movement and coastal combat

A navigation-enabled land unit starting the normal round reset at sea receives
at least six movement points and pays one per water hex. Land-start embarkation
retains its two-point water cost and grants no mid-turn movement. Landing spends
the remaining allowance, preventing the sea budget from funding a land march.
The round reset and inspector share the recorded allowance. Optional sea-rate
and allowance fields persist without replenishing movement on migration/load.
A newly eligible Surprise War response beginning at sea changes only its water
rate; it never grants another allowance. A per-round response marker prevents
repeated activation from changing a response that began on land.

Embarked combat units, including normally ranged units, use adjacent melee
attacks against land targets. Surviving defenders retaliate normally. Land melee
cannot initiate attacks against embarked units or ships; land ranged units can
fire on embarked targets without Navigation. A surviving amphibious attacker
can capture a coastal city. Melee landings use the same remaining-budget rule
for forecasts and actual movement. Naval vessels retain their native allowances
and existing coastal-city behavior.

Shared movement-range helpers drive reachability, combat forecasting/resolution
and visible-enemy threat estimates. Observed embarked status is public; threat
forecasting infers sea travel from that observation without transmitting hidden
foreign technologies. The seeded progression harness now uses the same next-round
movement reset as the host rather than resetting every unit to its land stat.

Dedicated scenarios cover six water steps, partial sea travel followed by landing,
no extra movement inland, embarkation/load/response budgets, amphibious archers,
melee shore restrictions, ranged fire without Navigation, public threat parity,
forecast damage/retaliation parity and coastal capture. Native CraftOS-PC passes
those rules and the full hotseat/AI/Surprise War session with turn decisions,
settings, research, conversations and save reload. Instrumented text/graphics UI
coverage does not establish physical monitor or live remote-client behavior.

### Settler capture, protection and shared-tile identity

Per the user's clarification, instant capture is melee-only; ranged attacks damage
settlers normally. A melee attacker reaching an unprotected settler transfers its
ownership without a damage exchange, movement refresh or loss of identity/health.
Captured units discard their previous owner's AI settlement/role/infrastructure
plans and allowance bookkeeping. One settler and one protecting unit may share a
hex. Protection always takes combat first, independent of array order. A surviving
melee victor captures the remaining settler after defeating its guard; ranged
victory leaves it unprotected. City capture likewise preserves and transfers a
settler rather than deleting it as a garrison. Capture forecasts and observer-local
combat events include the distinction, and AI values legal capture opportunities.

Human and AI commands carry explicit unit IDs on shared tiles, including movement,
founding, standby, healing, exploration and rail orders. Stale or foreign identities
cannot silently select the other unit. Inspectors switch between guard and settler;
a city/guard/settler tile cycles the selector in a single row on compact displays.
The map prioritizes the protector and adds a separate small settler marker.
Linked movement and its additional restrictions are described below.

As the module graph grew, native startup exceeded CraftOS's watchdog while the
same source modules were repeatedly loaded through absolute `dofile` calls. The
shared loader caches `require`, but not those `dofile` calls. CivCraft now installs
its own per-program internal module cache before loading gameplay/UI. Other
program paths, nil-return entry scripts and failures retain their semantics; new
program globals receive independent caches. The module-cache tests cover reuse,
external scripts, failure recovery, isolation and circular-load rejection. Native
capture/UI rules and the full hotseat/AI/Surprise War session pass with this actual
program loading path; the watchdog is unchanged.

Capture tests exercise melee/ranged distinctions, guard priority and death, city
capture, stack limits, former-owner permissions, captured-plan privacy, explicit
shared-tile selection in text/graphics and AI capture ranking. Native tests remain
headless/instrumented rather than physical-monitor or live remote-client proof.

### Attached settler escorts

Owned settlers can attach to a co-located military land unit or ship through the
inspector, and either member can detach. Mutual unit IDs persist in owner snapshots
and saves. Attachment wakes both units without refreshing movement or attacks.
Invalid saved links are discarded without changing budgets. Founding, disbanding,
bankruptcy, capture and combat death clear the other member's link.

Either member can lead a move. Reachability keeps nondominated pairs of terrain
costs, so a cheaper route for one member does not conceal the only affordable route
for the other. Each step must be passable and affordable for both members; water
allowances, landing costs, discovered obstacles and zone-of-control stops apply
individually. Mounted and naval-raider escorts pass their control immunity to their
settler. Both actors receive separate frozen movement events with their actual
endpoints; automatic-exploration suppression applies to both events.

A melee guard can advance after combat only when its settler can follow. A ranged
guard may attack without moving a spent companion. An attached guard cannot capture
an additional settler, which would create three occupants; detaching first leaves
its original settler behind. Protection priority does not depend on attachment.
Skip Turn and Sleep apply to the pair, and the primary turn control represents
the formation once. The compact text/graphics inspector exposes Attach/Detach
without adding a separate persistent panel. AI-assigned escorts attach through
the same host action when they meet their settler, then let the settler lead.

`civcraft_escorts_test.lua` covers ownership and stale links, projections, both
leaders' costs, a route requiring a nondominated cost pair, spent companions,
ranged/melee combat, capture capacity, removal, sea movement, control immunity,
unknown-route interruption, AI attachment and actual compact inspector controls.
Queued future movement is described below.

### Sharp labels immediately after zooming

Fractional camera offsets caused a one-pixel bitmap stroke to span two pixels:
rectangle drawing covers both floor(origin) and ceil(origin + width). Text now
snaps its graphics origin to the pixel grid before drawing any stroke, matching
sprite blitting. It remains sharp on the first frame after zooming or panning.
The scaled-row cache keys exact source rows and did not require invalidation.
Renderer tests compare the complete source and uploaded frames for fractional
origins at normal and enlarged text scales, with both warm and cold row caches.

### Saved movement routes and waypoints

Move/Attack accepts a destination beyond the current allowance by previewing a
route through explored terrain. Queue Moves also lets a spent unit issue future
orders; Add Waypoint appends destinations (up to sixteen). Existing routes can be
cancelled in the inspector or replaced by a new normal move/route. Accepted manual
Skip Turn, Sleep, Heal, exploration or other unit orders cancel the old route;
rejected orders preserve it. Detaching, capture or unit removal clears group
intentions. Owned snapshots and saves retain route progress; foreign projections
omit waypoints, progress stamps and future destinations.

Issuing a route spends only currently available movement, then resumes once per
eligible normal/response turn window. The host runs these orders after existing
allowances and sea-response rules, using shared movement actions for every step.
Ready players and inactive war-group members wait; loading never refills budgets.
Both members of an escort must afford each step. Control entry stops the group
until its next window. Newly occupied or impassable routes pause with a private
notice and become an idle decision; automatic orders never initiate combat.
Users can reassign or cancel a paused route. Unexplored destinations receive an
explicit exploration message instead of exposing hidden terrain or occupancy.

The bounded weighted planner shares the AI route heap through optional step and
occupancy policies; existing AI defaults are unchanged. Saved version 1 queues
validate bounds, shape, waypoint count and cursor without granting movement. The
queue tests cover round-by-round spending, multiple waypoints, replacement and
cancellation, failed orders, fog and foreign privacy, automatic capture rejection,
war eligibility, response budgets, malformed saves, escorts and sea landing.
Actual compact text/graphics controls assign, append, confirm and cancel routes.

Native CraftOS-PC rule tests pass. The full-session driver adds `--routes` and
issues the order through the actual inspector/confirmation dispatch before
ending turns and reloading the save. Peaceful sessions assert host-driven route
resumption in round two; Surprise War sessions assert that an inactive war-group
member retains its new allowance and pending route while waiting for activation.
Physical monitors and live rednet clients remain unverified.

### Frozen explored terrain and remembered cities

Each observer saves last-look terrain/geography, deposits, ownership and a public
city record alongside existing rail/wonder/camp memory. Records update in sight,
including the final view when a unit/city sight source is lost, then freeze until
re-scouted. Capturing a player's last visible city therefore records its observed
new owner. Unseen construction, renaming, damage, ownership changes, destruction
and village alliances cannot update the remembered scene. A newly discovered
city appears only when actually seen. Units have no fog markers. Own city controls
and known own claims remain available as the player's own information.

Observer snapshots carry frozen deposits and terrain, and an observed ownership
map for exact border rendering without exposing unseen city claims. Remembered
foreign cities stay in the observer's private memory, separate from current
combat entities. Known villages retain their frozen remote record. Ordinary
remembered cities show their name and last-observed round in a read-only inspector.
Re-scouting clears destroyed-city markers and refreshes the observed facts. Old
saves retain immutable explored geography, while unsupported dynamic facts are
left unknown until seen rather than reconstructed from hidden current state.

Remembered terrain keeps its silhouettes/details under a dedicated seven-shade
grey palette. Cities, deposits, infrastructure, borders, labels and minimap
markers share that treatment. The grey renderer caches tinted sprite rows and
refreshes when display settings replace the underlying renderer. Faction colors
remain separate from terrain. Instrumented text/graphics tests compare frozen
map pixels before/after unseen city destruction, check grey city pixels and
read-only last-seen labels, and exercise detached local and network snapshots.
Native CraftOS-PC rule and full-session scenarios pass; physical-monitor and
live-modem behavior remain separate validation boundaries.

### Persistent observed Event Log and paced replays

A top-right Event Log opens a focused full-screen list, newest first. Fixed Recent,
Newer and Older controls remain visible even on a 51x19 terminal; body pagination
handles long entries. Compact summaries retain every newly observed event after
the bounded replay window expires, including known actions that do not animate.
The log records observer-local sequence and round, readable text and observed
movement endpoints; it stores no unrestricted event frames, hidden route segments,
foreign private data or global action counts. Saved history is independent of the
128-event/eight-round replay journal. Earlier saves seed their retained events and
state clearly when the already-pruned past is unavailable.

Snapshots include only the latest twenty compact records. Older pages use a
read-only host request (maximum fifty per page), keyed to the authenticated sender
and campaign. The response echoes a bounded request token. Pagination does not
create events, change readiness, spend actions, advance a war group or publish
new game revisions. The client rejects wrong-observer, wrong-campaign, stale-token,
closed-panel and superseded requests. Hotseat/campaign changes discard private
pages and cursor history. The existing recent replay feed remains separate;
older text-only history cannot invent replay geometry. Sparse observed-owner
projection avoids transmitting unowned entries for every explored tile.

Each automatic turn-recap event holds its observed opening pose for 350 ms before
animation, centering the camera first. Fast mode uses 175 ms; reduced-motion/off
mode skips animation. Backlog acceleration cannot remove the gap. Pause menus
preserve the remaining lead-in; live manual actions keep their immediate feedback.
Timing runs only in presentation and never delays simulation or changes budgets.

The 75-file regression suite passes, including archival retention across replay
pruning, reverse-page continuity, private history, legacy migration, compact
text/graphics controls, request isolation and serial/paused/fast/off replay timing.
Native CraftOS-PC passes the history rules and a full mouse-driven host-loop
session with `--history`, including a read-only refresh, fog, routes, diplomacy,
Surprise War responses, hotseat, research/settings/campaign options and save reload.
Live rednet and physical monitor validation remain outstanding.

### CraftOS watchdog crashes during reveal and campaign saves

A copied existing campaign reproduced `Too long without yielding` inside the
installed CraftOS `textutils.serialize` implementation. Its table encoder
repeatedly concatenates an ever-growing string and has no cooperative checkpoint.
The largest copied slot loaded/migrated/revealed in 22 ms, then hit the watchdog
while encoding. Visibility memory also lacked checkpoints inside its tile loop,
and the session only registered its checkpoint after its initial loaded-world
reveal.

Campaign saves now use a linear Lua-table writer with writes bounded to 8 KiB
and periodic checkpoint callbacks. Existing Lua-table saves remain readable;
old and new fields round-trip without a schema reset. Local and host saves share
the temporary-file/backup commit path. Encoding/write failures close and remove
the temporary output without replacing either committed file, and failed rename
restores the previous campaign. Aliases, sparse/zero/negative keys, booleans,
Unicode/control characters, fractional movement and non-finite numbers are
covered; recursive/unsupported values fail before committing.

The renderer's existing bounded input-preserving yield mechanism is shared with
boot/simulation/save work. The host registers elapsed-time checkpoints before
loading/revealing a campaign, refreshes against the current renderer after display
changes, and samples inside visibility tile loops. Bootstrap input survives
renderer creation; early network events are replayed to the server listener.
There is no watchdog timeout increase or movement/turn-budget change.

On isolated copies of three existing campaigns, twelve full
load/migrate/reveal/save/reload comparisons passed. The largest cycle completed
in 34-35 ms and encoded to 281,252 bytes; the workload yielded nine times. The
actual game also selected, continued, rendered, saved and reloaded that copied
campaign in native CraftOS-PC. Native core/normal-session checks and the 76-file
regression suite pass. This fixes the reproduced paths; it does not establish
that every possible renderer, modem or emulator stall is eliminated.

## 09: Council of Civilizations

Council sessions open once two civilizations own cities and one knows Currency.
The initial balance is two delegates per civilization, plus at most one from an
independent village allied at 60 influence for three consecutive rounds. Delegate
allocations are frozen for each ballot. City spam and conquest create no extra
votes. Sessions open every ten speed-scaled rounds and close after three.

Leadership requires a strict majority of all allocated delegates. Diplomatic
victory requires at least two thirds, another living civilization's support,
Stock Logistics and a Council Hall. The new hall requires a Trading Hall and
90 base industry. New campaigns enable this selectable victory; existing saves
without an explicit diplomatic-victory setting retain their earlier conditions.

Each member may add one opening-round proposal. Trade facilitation reduces
material purchases from 20 to 15 gold and adds one commerce income. Embargoes
block material purchases, new trade/commerce agreements and pending acceptances,
while suspending existing commerce income. Peace initiatives end the named war
at the closing boundary and prevent renewed attacks/declarations/interventions;
forced peace does not punish joint-war partners. Censure subtracts 20 public
reputation. Resolutions need a strict majority and expire after ten speed-scaled
rounds. Existing agreements resume after an embargo expires.

Voting uses the shared host command path, including campaign/round/session
validation. Ready or inactive members can vote without gaining unit actions.
Ballots remain private until closing, then publish counts and AI explanations.
AI uses its own observed relationships, economic interests, war aims and victory
risks. The merchant's diplomatic goal now researches commerce and builds a hall.
Conversation requests create a voluntary ballot pledge, never an automatic vote:
honoring it earns ten trust; breaking it costs 25 trust and 15 grievances for
30 rounds. Obsolete offers withdraw when the ballot becomes unavailable.

The top-bar Council opens separate Status, Election and Agenda panels, resolution
ballot/details, a staged proposal dialog and Recent Results. Controls are paged
at compact sizes; hotseat/campaign changes clear drafts. Council membership does
not discover another civilization or reveal city locations and private plans.

Validation: Council rules cover 2/3/4-civilization voting, computer ID zero and
negative IDs, fixed allocations, elimination, disabled/legacy victories, privacy,
pledges, actual market/commerce changes, pending-trade validation, Council peace,
joint-war obligations and reversible reputation. Six text/graphics layout tests
exercise actual ballot/proposal clicks, Codex navigation and hotseat reset.
Installed CraftOS-PC passes both Council tests and full local/host-mode sessions
with Council ballots, conversations, research, settings, history, queued routes
and save reload; the local session also tests Surprise War responses. Native
sessions use isolated profiles and the text renderer. Physical monitors and live
modem traffic remain release validation work.

## Larger world presets

New campaigns now use Compact 24×16, Standard 40×26, Large 56×36, Huge 72×46
and Vast 96×60. All five presets increase; the largest has 5,760 hexes. Existing
saves retain their stored dimensions, terrain, deposits, geography and seed even
when their preset name matches an updated size. The seeded generation algorithm
remains version 2; only new-campaign dimensions change.

The 600-world audit passes all sizes, four map types and 2–4 civilizations. Its
minimum open traversable land is 55%, coherent neighboring biomes average 76%,
all worlds have at least two eligible wonders, and starts retain 18 connected
usable nearby tiles. Migration assertions explicitly retain a 28×18 version 2
world labeled Standard.

The isolated CraftOS world stress driver generates all twenty size/type pairs,
executes three early rounds for four AI actors on Vast, reveals observers and
saves/reloads the resulting campaign. On this machine, Vast generation takes
roughly 100 ms, each early actor takes under 100 ms and a roughly 600 KB campaign
saves/reloads in under 50 ms. The driver records checkpoints and actual yields.
These measurements describe early-game text-backend runtime, not a late-game
physical-monitor or live network benchmark. The native full-session driver also
passes at the larger Standard dimensions.

## Short-terminal map controls

Terminals below 100 logical pixels high now use one Map Tools button instead of
stacking six toolbar controls over the overview button. Its focused menu contains
terrain/territory/resources/yields, zoom and World Overview; selecting an overlay
or zoom returns to the map. Taller screens keep direct controls. This also gives
short screens a wider map by removing the second sidebar column.

Eight text/graphics size combinations verify control bounds, non-overlap,
accessible paged actions, working zoom/yield magnification and overview return.
Existing eighteen-layout controls tests, general UI and Council UI checks pass.
Installed CraftOS-PC passes the new test and a full mouse-driven short-terminal
session with `--map-tools`, Council, routes, history, conversation, Surprise War,
research/settings and save reload. The remaining integrated action audit and
release/network/performance workstreams stay open.

## 11: Five AI difficulties

The host configures each AI independently in Campaign Options before starting.
Lobby rows and discovered faction details show its public difficulty separately
from its fixed civilization personality and hostile-mob setting. Missing saved
settings mean Prince; configuration changes require the host, an AI participant,
a known level and the lobby phase. Saved worlds, stock and movement are unchanged.

- Settler searches eight tactical candidates, reviews strategy every fourteen
  rounds, uses shorter settlement routes and occasionally chooses a near-best
  economic/tactical option. Proactive wars require seven units and an eight-round
  opportunity interval.
- Chieftain searches sixteen candidates, reviews every twelve rounds and has
  milder near-best choices. Proactive wars require five units and a four-round
  interval.
- Prince preserves the existing 24-candidate, ten-round baseline and normal
  economic, tactical and diplomatic execution.
- King searches 36 candidates, reviews every five rounds, considers observed
  second-ring settlement yields and evaluates a legal friendly follow-up from up
  to two nearby combat units after a hypothetical attack.
- Deity searches 48 candidates, reviews every three rounds, gives future city
  yields greater weight, anticipates exposure more strongly and evaluates up to
  four possible friendly follow-up actors.

Follow-up evaluation clones observed units/cities, applies the first forecast's
HP/position changes, and uses ordinary reachability and combat prediction for the
next attack. It does not move units or refresh actions. Tests execute a predicted
combined kill through the real shared action path. Personality values and all
production/research costs, combat strength, movement and treasury rules remain
identical across difficulties. AI cannot acquire unseen knowledge through quality
settings. Easier sampling is deterministic and stays within a small near-best
score band; it never rewrites the original ranking.

All 81 repository regression scripts pass. Four compact/wide text/graphics lobby
layouts cycle every level while preserving mob difficulty. Native local and host
sessions set an AI to Deity and retain it through gameplay/save reload, alongside
Council, routes, conversation, research, settings and event history; local also
covers Surprise War. The native difficulty rules/UI tests pass.

`civcraft_ai_tournament.lua` runs ten same-seed, swapped-seat matches against
Prince, with identical civilization and starting resources. The initial 40-round
matrix completes in both Lua 5.3 and native CraftOS, with 4,642 shared-action orders
and zero rejections. Native execution takes about 27.5 seconds total; the slowest
actor is 144 ms under concurrent test load. These are legality/progress smoke
measurements. Multiple seeds, archetypes and longer games remain balance/release
validation, rather than evidence that every higher tier wins every scenario.

## CraftOS-PC collection stalls

Extended native simulations reproduced a separate pause inside Lua garbage
collection. Process sampling showed the execution thread repeatedly marking and
sweeping Lua objects. Unpatched eight-round tournament runs exceeded 180 seconds;
cooperative input yields alone did not prevent the stalls. Explicit collection
between chunks avoids the reproduced incremental-collection thrash.

For CraftOS-PC 2.8.3, the shared cooperative checkpoint now completes collection
before yielding, throttled to at most once per thirty milliseconds per work
context. It changes no global collector settings. Restricted collector APIs fall
back to ordinary yielding. Other runtimes retain their existing collection policy.
Pending mouse/network input and lost-sentinel recovery retain their earlier
behavior. The optional runtime counters expose collection count and worst pause.

The patched eight-round matrix completes in 2.8 seconds, with a 1 ms maximum
collection. The forty-round matrix completes in 27.5 seconds, with a 14 ms maximum.
A further 1,000 native-runtime pan/zoom/report/Council frames pass: real text output
has 8 ms median / 13 ms maximum; instrumented graphics has 18 ms median / 26 ms
maximum. Collections in that run take at most 2 ms. Full local/host sessions and
Vast-map generation, AI and save reload also pass. This addresses the reproduced
collector stall; recurrence during normal play still needs observation. Physical
monitor and live modem validation remain part of the final integration work.

## Campaign navigation and toolbar cleanup

The title menu now presents five actions: New Campaign, Load Campaign, Remote
Multiplayer, Settings and Exit. Creation and loading use separate slot menus;
replacement requires explicit confirmation before resetting an occupied campaign.
The load menu retains confirmed deletion on compact and wide displays. Back
controls return from slot selection, replacement, multiplayer and campaign setup.
Multiplayer can host or discover/join a game directly from the menu, returning to
the local title when leaving a network session.

Research reuses the yield flask. Factions, Codex, history, Council and pause use
people, question-mark, clock, globe and hamburger icons, respectively. World
Overview sits beneath Zoom Out, including the two-column toolbar layout. Very
short terminals retain the focused Map Tools menu.

Loading establishes a fixed event cutoff for every saved observer. Existing
history remains readable without automatic replay; subsequent events still play,
including after hotseat handoff. Hosts publish only the recipient's cutoff to
remote clients. Changing save slots clears stale playback instances.

All 83 regression scripts pass, including six title-menu text/graphics layouts,
per-observer replay baselines and access to every submenu action. A fresh native
CraftOS full session passes. A separate native check loads an existing campaign,
rejects unconfirmed replacement, resumes without replay, explicitly creates a new
campaign and verifies that the saved file stays intact until a later save.
Compact and wide rendered menu previews were visually inspected.


## Extended AI and native monitor audit

Longer campaigns found repeated wonder attempts when a rival's completed wonder
was outside the AI's observations. The AI now remembers only its own rejected
production order and suppresses that wonder for ten rounds before reconsidering.
It does not consult hidden construction or record the rival's location. This
optional bounded `aiPlan.productionRetryAfter` table survives normal save migration.

Settlement travel now validates the next planned step against shared observed
reachability, including attached escorts' remaining allowances and control stops.
An unaffordable step pauses travel while preserving the destination. Regression
checks cover denial feedback, expiry, migration and an exhausted escort recovering
its allowance.

The tournament driver now follows the real boundary sequence: Council/diplomacy,
healing, production, villages/hostiles, movement reset, observations/promises and
victory checking. It pumps eligible actors under the scheduler and asserts that
rounds complete. Different opponent civilizations can be supplied as a fifth
argument (the optional fourth remains `--gc`). Reports include opponent score,
winners and victory reasons. Legitimate host denials caused by unseen completed
wonders or differences between observed and authoritative reachability are counted
separately; other rejected orders fail the run. Those diagnostics stay in the test
harness and never feed hidden information into AI planning.

A fresh native sixty-round, ten-match Miners-versus-Scholars matrix passes with
8,057 orders and zero rejections. The worst actor takes 220 ms and the largest
collection takes 33 ms under concurrent validation load. These are measured smoke
and responsiveness results, not a statistically established difficulty ranking.
All 83 regression scripts pass. A real native emulated-monitor session now passes
using monitor-touch events through the full game loop; the isolated Python launcher
makes both monitor and headless/host scenarios reproducible.

The expanded desktop matrix completes sixty 100-round matches across six seeds
and nine civilizations: 83,633 orders, 156 denials for unseen completed wonders,
one movement denial from an unseen obstruction, and no unexplained rejection.
[AI-BENCHMARK.md](AI-BENCHMARK.md) and its CSV preserve the individual results.
They remain sampled integration/balance evidence rather than proof of monotonic
win-rate gains between every tier.
