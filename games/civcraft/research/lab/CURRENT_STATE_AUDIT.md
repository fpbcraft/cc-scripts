# CivCraft current-state audit

**Audit revision:** `97944b8bc85e011d00abbdf45bf9aecdb82050ae`
**Checked out:** 2026-10-26 15:00 EDT
**Scope:** static audit of the frozen HEAD implementation and its regression/native-test boundaries. No gameplay rules were changed by this audit. The parent agent has since made an uncommitted, behavior-preserving lifecycle extraction in the shared working tree; that delta is called out explicitly below.

This is an implementation inventory, not a claim that every balance hypothesis is confirmed. I use **OBSERVED** for a direct code/test fact, **CONFIRMED** when a test or deterministic calculation establishes behavior, and **HYPOTHESIS** for a balance interpretation requiring matched games or player testing.

## Executive state

CivCraft is a functioning, host-authoritative hotseat/rednet game whose core orders are routed through one validator. The current default is a Create ruleset, two-to-four civilizations, standard speed, a 180-round limit, seeded generated maps, six named ages, five selectable victories, fog-of-war, villages/hostiles, diplomacy, and AI. At the frozen audit HEAD, state creation, turn resolution, save I/O, network projection, UI dispatch, and CraftOS scheduling were coupled in `game.lua`. In the current uncommitted working tree, the parent has extracted setup/round boundaries to `match_lifecycle.lua` and actor pumping to `actor_lifecycle.lua`; this is a meaningful architecture improvement, and the lab adapter exposes the proposed experiment API with partial action proposals and explicit budgets. This is not a full conformance proof.

The strongest balance-relevant implementation facts are:

1. **Research, production, and growth all use the same speed factor, but initial stores/yields are not speed-scaled.** Costs and deadlines scale in `campaign_rules.lua:1-8,32-35`; start values are fixed in `game.lua:199-227`.
2. **Paused project progress is retained, but completion overflow is discarded.** Queue selection stores per-project progress in `systems.lua:394-431`; production and research stop at completion in `systems.lua:795-864` without carrying excess output forward.
3. **There is no explicit elimination lifecycle.** Combat can remove units and capture cities (`combat.lua:337-388`), but no player is marked eliminated or removed from scheduler/victory participation. `victory.lua:68-130` iterates all players and only checks victory qualifications/round limit.
4. **Two strategic-resource entries are inert or incomplete in the live content surface.** `content.lua:674-684` defines `horses` and `saltpeter`, but `resourceOrder` omits both; world generation creates horses but not saltpeter (`worldgen.lua:284-295`), and current recruitable horsemen have no horse resource gate (`content.lua:352-362`). This is a verified content/data mismatch, not yet a quantified win-rate effect.
5. **Prior numerical measurements are useful baselines with provenance caveats.** The archived harness/report under [`civ6-balance-2026-10-26`](../civ6-balance-2026-10-26/) records CraftOS-PC measurements at commit `c5d7e4df...`, while this audit is at `97944b8b...`. The exported content files are unchanged relative to the audited source, so their counts/values remain useful arithmetic evidence; rerun the harness before treating a number as a current regression or attributing it to the extracted working tree.
6. **The lifecycle extraction now has partial native/offline parity evidence.** The parent’s uncommitted `match_lifecycle.lua`/`actor_lifecycle.lua` path matched native CraftOS for 2- and 4-player fixtures over three rounds, including authoritative state, observer projections, accepted research, rejected orders, actor pumping, and round boundaries. Raw evidence is `/tmp/civcraft-lab-native-parity.json`. Wartime, saves, multiplayer transport, and full-game victory parity remain unproven.

## Live lifecycle and authority boundaries

### Bootstrap and runtime dependencies

At the frozen HEAD, `game.lua:1-16` delegates through the FPB loader, installs the CivCraft module cache, parses `local|host|join`, chooses protocol `fpbcraft.civcraft.v2`, and uses `/games/civcraft/data/save.dat` for network-host saves. It probes modems/monitors and mutates the monitor mouse setting at `game.lua:47-80`. The module graph and shared cooperative checkpoint are installed at `game.lua:82-107`; `Systems`, `World`, and `Saves` all receive the same checkpoint callback. In the current uncommitted tree, `game.lua` additionally loads `match_lifecycle.lua` and `actor_lifecycle.lua`; the extracted modules keep the same CraftOS calls around the boundary while making setup/advance/actor pumping callable by a research adapter.

**OBSERVED at frozen HEAD:** UI, network, file system, cooperative yielding, and authoritative simulation are all reachable from the same `game.lua` process. There was no public `newGame`, `observe`, `legalActions`, `applyAction`, `endTurn`, `isFinished`, or `metrics` interface. **CURRENT WORKING TREE:** the extracted lifecycle modules provide setup/advance/finish and actor-pump seams, and the laboratory adapter now exposes the proposed API, privileged metrics, instruction/action budgets and process timeouts. Legal action proposals remain partial, and conformance is narrower than the full protocol.

### New campaign and map start

`newGame()` sets schema/version 6, ruleset `create`, standard speed, round limit 180, victory-rules version 2, hostile mode `standard`, lobby phase, round/turn 1, empty participant/entity arrays, standard/continents map defaults, and seed 12345 (`game.lua:130-154`). Local mode creates two persistent hotseat IDs when no players exist (`game.lua:539-549`); lobby commands can add up to four players or AIs (`game.lua:405-435,876-918`). The host must start from the lobby with at least two players (`game.lua:445-453`).

`initMap()` generates a seeded world for the participant count and assigns one size-dependent start to each participant (`game.lua:199-205` at frozen HEAD; current extraction: `match_lifecycle.lua:65-102`). Each participant receives a population-2 capital with `foodStore=0` and jobs `{food=1, wood=1, science=0}`, a starting warrior, `food=12`, `wood=12`, `science=0`, and an initial civilization fallback (`game.lua:206-227` at frozen HEAD; `match_lifecycle.lua:68-92`). Hostiles, villages, migration, council state, diplomacy boundaries, and visibility happen before returning; the CraftOS adapter then pumps actors and saves (`game.lua:228-240`; current extraction returns from `match_lifecycle.initialize()` and leaves those adapter callbacks outside the module).

`World.generate()` clamps seed/count/map type and delegates to the deterministic generator (`world.lua:94-105`). Start repair guarantees nearby land plus a grain and iron deposit (`worldgen.lua:184-210`); additional deposits are seeded from a weighted eligible-resource list (`worldgen.lua:323-365`). This is a designed opening guarantee, not a random-start baseline.

### Round and action lifecycle

The host dispatches every request through `game.lua:380-508`. It first checks player membership and campaign/round tokens via `Actions.validateIntent()` (`actions.lua:22-30`), then handles lobby/save/options, checks phase, applies the scheduler gate for ordinary actions, and finally calls `Actions.apply()`.

`nextTurn()` is the authoritative round boundary (`game.lua:273-320` at frozen HEAD): increment round; clear `ready`; advance council/diplomacy; prune events; resolve combat healing and city recovery; run economy/production; advance villages and hostiles; reset unit movement; reveal visibility; run auto-exploration; build reports/age/end-stage fields; evaluate victory; pump AI; log and save. In the current working tree, that state transition is `match_lifecycle.advance()` (`match_lifecycle.lua:105-145`), while victory, actor pumping, logging and save remain adapter orchestration in `game.lua`. A player pressing END calls the extracted finish path and either waits or invokes this boundary (`game.lua:483-496`; `match_lifecycle.lua:147-158`).

The local hotseat loop rotates to the next eligible human after accepted END, hiding the prior player's selection/map until handoff is acknowledged (`game.lua:920-959`). Host mode runs a rednet server in parallel with the UI; clients receive observer projections and submit stamped requests (`game.lua:1010-1135,1215-1222`).

### Shared action semantics and scheduler

`actions.lua:1-20` explicitly defines shared host-authoritative orders. `Actions.apply()` validates ownership, phase, scheduler eligibility, coordinates, movement, visibility, combat, city ownership, settlement spacing, production, research, rails, diplomacy, and council actions (`actions.lua:32-61,170-221,223-505`). AI orders call the same function (`ai.lua:26-32,107-108,135,153-156,196-204,248-249,281-283`; frozen-HEAD `systems.lua:867-940`; current actor extraction: `actor_lifecycle.lua:54-63`).

**CONFIRMED:** Existing action tests exercise the same dispatcher for human and AI settlers, hidden attacks, movement, production pause/resume, founding, healing, pure combat forecasts and resource/territory constraints (`tests/civcraft_actions_test.lua:88-181,182-265`). This supports “AI does not receive free illegal actions” for covered orders.

The scheduler keeps peaceful civilizations independent and serializes connected active-war components (`turn_scheduler.lua:1-38,52-131`). It rotates war groups by round, grants a once-per-round defender reaction for Surprise War, and requires every participant to finish before the round boundary (`turn_scheduler.lua:133-182`). Diplomacy replies/counters and council operations are deliberately allowed through the side-action exception (`game.lua:458-469`; `actions.lua:52-60`).

**OBSERVED boundary to preserve in experiments:** an action trace must record scheduler group, active actor, ready/reaction state, and whether an order was a normal turn action or an out-of-turn diplomatic/council response. Aggregating only round numbers will hide these timing rules.

## Economy, growth, research, and production

### Yields and population

Base city-center yields are 2 food, 1 industry, 1 science, modified by buildings and civilization bonuses (`systems.lua:507-527`). Worked tiles add their generated food/industry/science (`systems.lua:529-548`; terrain/deposit effects are `world.lua:262-288`). City growth consumes `2 * population` food; threshold is `20 + 8 * population` and minimum growth age is four turns, all speed-scaled (`systems.lua:601-625`). Production applies surplus, stores food, grows/shrinks population, auto-adds a worker, expands territory, then projects output (`systems.lua:736-835`).

**OBSERVED:** The opening economy is not a single fixed “5 industry/1 science” abstraction in all contexts; it is the center plus worked tiles and civ/building bonuses. The archived native measurement harness should be used for exact starting samples rather than manually inferred values. It reported, at the older commit, one-city starting samples of 7 food/5 industry/1 science for Forge/Verdant and 7 food/5 industry/3 science for Scholar, with Scholar’s first agriculture research materially faster. See [`civcraft_measurements.json`](../civ6-balance-2026-10-26/civcraft_measurements.json), `metadata.repository_head`, and the harness [`measure_civcraft.lua`](../civ6-balance-2026-10-26/measure_civcraft.lua). This has not been revalidated at the audit HEAD.

### Research

Tech selection checks prerequisites and stores per-tech progress (`systems.lua:272-293`). At the round boundary each player accumulates total city science and advances only the selected target (`systems.lua:748-756,853-864`). Content defines six age lanes and 45 technologies with costs 24/32/50/70/100/130 by age (`content.lua:3-10,165-181,183-287`); exact runtime counts were exported in the older native content snapshot [`civcraft_content.json`](../civ6-balance-2026-10-26/civcraft_content.json), whose metadata is stale relative to this checkout.

**CONFIRMED:** Switching projects retains prior progress (`systems.lua:394-431`; `tests/civcraft_actions_test.lua:164-180`). **CONFIRMED:** There is no overflow carry: research sets the tech complete and clears the target when `progress >= cost`, without retaining `progress - cost` (`systems.lua:855-863`).

### Production, upkeep, stockpiles

Projects are city-local buildings, units, wonders, or `none` (`systems.lua:394-435`). Costs are speed-scaled; settlers add `productionStep * settlersTrained` (`systems.lua:489-505`). Unit recruitment checks tech, unique civilization, required building/coast, gold pressure, and strategic resource availability (`systems.lua:364-392`); completion consumes two units of a resource from stockpile (`systems.lua:559-598`). Economy adds one stock per owned eligible deposit per round and converts copper+zinc to brass when the mixer/technology conditions hold (`economy.lua:48-88`).

Treasury income is 2 + population + building effects per city plus commerce treaties; each unit pays listed upkeep, and negative gold can disband units (`systems.lua:305-327,836-852`). **HYPOTHESIS:** because output scales with city count and late buildings add large flat yields, expansion and industrial chains may compound faster than intended; this needs fixed-policy matched trajectories, not static cost inspection.

**CONFIRMED:** Completion overflow is discarded for buildings/units/wonders: production adds `yield.industry` to the current project, completes it, and clears `c.project` (`systems.lua:795-832`) without applying excess to the next project. This disproportionately affects high-output cities and should be measured as a pacing choice rather than “free production.”

## Content and strategic choices

Content is data-driven through `content.lua`, then re-exported by `systems.lua:1-29`. Ten civilization identities are defined at `content.lua:11-21`; the live list covers food, industry, science, movement, naval movement, defense, and trade bonuses. Units, buildings, wonders, ages, technology prerequisites and resource metadata are in `content.lua:165-730`.

**OBSERVED content trap:** `content.resources` contains eight IDs, but `resourceOrder` contains only six (`content.lua:674-684`). World generation includes horses but not saltpeter (`worldgen.lua:284-295`); horseman has no `resource="horses"` field (`content.lua:352-362`). The resource exchange explicitly rejects horses/saltpeter (`economy.lua:90-128`). This makes the documented horse/saltpeter strategic layer incomplete. It may be a harmless legacy residue for current units, but it is not a balanced strategic choice until either wired, hidden, or removed from player-facing claims.

## Military, diplomacy, villages, hostiles

Combat normalizes units to 100 HP and cities to 200 HP, with separate wall HP; recovery is territory/fortification dependent (`combat.lua:31-55,96-128`). Damage is exponential in attack-defense difference and clamped 8–80: `floor(30 * exp((attack-defense)/25)+0.5)` (`combat.lua:58-60`). Ranged attacks avoid retaliation; walls absorb damage; melee captures cities at surviving attacker HP and removes a defending unit where applicable (`combat.lua:183-239,303-408`). Movement legality and attack forecasts are validated through hex range, war state, visibility, terrain, zone control and escort rules (`actions.lua:322-387`; `combat.lua:137-260`).

The archived measurement harness recorded Stone Guard strength 20 versus Swordsman 45 in its combat-strength scale, with approximately 30 damage in a Stone-v-Stone exchange, 80 damage from the stronger attacker into the weaker defender, and 16 retaliation in the reverse direction. This is a historical snapshot at `c5d7e4df...`; re-run at `97944b...` before using it for balance tuning.

Diplomacy and villages are not cosmetic: diplomacy has offers, wars, treaties and reactions; village influence/envoys, council elections and commerce gates feed economy/victory (`actions.lua:92-169`; `economy.lua:7-46,90-128`; `victory.lua:24-60`). Hostile camps advance and can raid; the round pipeline resolves villages/hostiles before movement reset (`game.lua:283-291`). Council election arithmetic has a specific two-player agency constraint: members have 2 or 3 delegates (`council.lua:69-92`), while victory requires a strict majority, two-thirds of allocated delegates, and a non-self supporter (`council.lua:155-185`). Thus a 3-delegate candidate facing a 2-delegate rival cannot win by self-vote (60% < 2/3); the rival must vote for the candidate. This is a confirmed rule fact and a route-agency hypothesis, not proof that diplomacy is globally impossible.

## Victory and elimination boundary

The Create ruleset checks conquest, expedition, industrial, diplomatic and score victories (`victory.lua:62-130`). Score is 20 per city + 2 per population + 3 per completed building + 8 per researched tech (`victory.lua:5-22`). Industrial status requires a rail network with at least three bank-equipped cities and then a ten-round timer; expedition requires the Dragon project; diplomatic requires the Council’s current eligible winner (`victory.lua:24-60`). At the round limit, score selects the highest score or declares a draw if score is disabled (`victory.lua:101-119`). A bounded current cross-play baseline (24 finished Forge-only matches, two seeds) produced 12 expedition and 12 industrial wins, no diplomatic wins; five diplomatic-policy seat wins were alternate industrial qualifications. Because ballots and pledges were not traced, this identifies a structural measurement gap: future diplomatic wins may reflect opponent voting weakness or route switching rather than diplomatic-route agency. See [`BALANCE_ISSUES.md` BAL-09](BALANCE_ISSUES.md#bal-09--two-player-diplomatic-victory-has-structurally-weak-agency-confirmed-arithmetic-high-2-player-route-concern) and [`results/route_crossplay.json`](results/route_crossplay.json).

**CONFIRMED gap:** Combat removes defeated units and transfers/captures cities, but there is no `eliminated`, `defeatedRound`, surrender, player removal, or elimination transition in the live code. `Scheduler.complete()` requires every `state.players` entry ready (`turn_scheduler.lua:155-164`), and victory iterates every `state.players` entry (`victory.lua:68-99`). A player with no cities may therefore remain a required turn participant until a different victory ends the game. The precise user-visible dead-seat behavior should be confirmed with a small fixture; the missing lifecycle itself is certain.

## AI and difficulty

AI planning is observer-derived (`ai.lua:37-61,127-142`), selects research/production/workers/materials/diplomacy/tactics, and issues actions through `Actions.apply()` (`ai.lua:150-225,227-377`). `Systems.aiTurn()` executes these phases and unit priorities (`systems.lua:872-940`). Difficulty profiles alter ranking/choice behavior through `ai_difficulty.lua`; existing difficulty tests assert unchanged rules/resources/costs/budgets and deterministic easier choices (`tests/civcraft_difficulty_test.lua`).

**CONFIRMED measurement confound:** the 36-match faction-policy pilot held the expedition policy weights/goal constant but did not hold AI personality or independent map starts/seat constant. `ai_personalities.lua:53-72` maps each civilization to a different archetype consumed by strategy/tactics/diplomacy. All 36 matches finished as Expedition; Scholar, Nomad and Wild won 4/4, Mariner 3/4, other non-Forge factions 2/4, while seat 0 won 29/36 and every non-Forge faction won both runs when assigned seat 0. A research-only fixed-Forge-personality ablation completed all 36 paired configs: Scholar stayed 4/4, Nomad/Wild fell to 2/4, Mariner fell to 1/4, and seat 0 won 33/36. This supports a material expansionist-personality confound, while the remaining seat/start-position association is not proof of actor-order causality. Compact results are [`results/faction_policy_pilot.json`](results/faction_policy_pilot.json) and [`results/faction_policy_ablation.json`](results/faction_policy_ablation.json); independent map-start and scheduling controls remain required.

**CONFIRMED semantic strength:** the covered AI path uses the same validated action semantics and observer projection as players. **HYPOTHESIS:** current AI quality is not a valid upper bound for civilization balance; the historical 100-round benchmark and older full-180 fixture are generated-data smoke tests, not a competent-policy tournament or current-HEAD estimate.

## Fog of war, visibility, and network projection

Visibility is per-player. `World.reveal()` derives current sight from owned cities/units and records explored observations (`world.lua:319-417`). `World.forPlayer()` creates a public observer snapshot with private player state, public rival stats, visible entities, remembered terrain/resources, and redacted city/unit details (`world.lua:502-708`). `Snapshots.receiver()` rejects malformed, stale, wrong-observer, wrong-campaign and non-monotonic event streams (`snapshots.lua:12-99`).

**CONFIRMED:** fog tests verify last-look city/terrain/resource memory, grey remembered rendering, re-scout updates, private snapshots and no invented remembered combat entities (`tests/civcraft_fog_memory_test.lua:62-102,173-238`). Network tests additionally assert rival private fields, event journals, council ballots and AI plans do not cross the modem (`tests/civcraft_craftos_network.lua:67-88`).

## Saves, migration, multiplayer, and readiness

Local mode has three independent slots; host mode writes `/games/civcraft/data/save.dat` through the same atomic writer (`saves.lua:1-121`). Writes go to `.tmp`, rotate an existing `.bak`, then move into place; failures restore the prior save (`saves.lua:58-88`). Startup loads/migrates old state before UI creation (`game.lua:510-576`), and `Systems.migrate()` fills defaults while retaining existing map/territory/progress (`systems.lua:204-270`).

The event journal is private per observer, capped at 128 live entries/eight rounds, with bounded historical pages (`events.lua:1-25,47-68,99-176`). The command queue serializes yielded host work, caps pending requests at 256, and never persists closures (`command_queue.lua:1-40`). Cooperative checkpoints preserve queued input and perform runtime-specific CraftOS-PC collection (`cooperative.lua:1-66`).

**CONFIRMED test coverage:** save slot/backup/legacy import/failure recovery (`tests/civcraft_saves_test.lua:49-126`), coupled save/load of scheduler, diplomacy, council, routes, AI plan, fog memory and progress (`tests/civcraft_save_resume_test.lua:127-217`), hotseat lobby/handoff/AI/round/save (`tests/civcraft_hotseat_test.lua:132-239`), scheduler war graphs and reactions (`tests/civcraft_scheduler_test.lua:46-176`), and native session/save/render boundaries documented in [`NATIVE-TESTS.md`](../../NATIVE-TESTS.md).

**RELEASE boundary:** repository documentation reports native text-backend and emulated-network coverage, but physical monitors, target Minecraft computers, live rednet reconnect races, and large-army/late-game balance remain separate validation concerns. Do not promote the passing unit/UI suites into win-rate or pacing evidence.

## Reproducibility and measurement status

The archived balance folder contains a native CraftOS harness, complete runtime content export, and an adapted full-180 Forge mirror fixture. Their metadata explicitly records commit `c5d7e4df...`, CraftOS-PC 2.8.3 / ComputerCraft 1.112.0, seed/fixture and the fact that the two seat results are deterministic swaps. The content export itself is unchanged relative to the audited source; the measurement provenance hash is still historical. Link those files with their metadata and do not attribute their match outcomes to the current uncommitted extraction.

The current working tree has [54 short state/observer parity checks](results/native_parity.json) across three fixtures, [one exact full native exported-policy game](results/full_policy_native_parity.json) through expedition victory at round 125, and [21 narrow war/capture/save checks](results/wartime_save_parity.json), including two expected known-hostile-crash diagnostics. The native save branch calls the production Saves.save/load and migration pipeline. Registered-player war/capture is a separate same-run handcrafted branch; Surprise War, old-save migration matrices and rednet are not covered by these checks. Six frozen lifecycle fixtures and twelve Python lab tests also pass. See BASELINE_BALANCE_REPORT.md for exact scope and validation caveats.

The permanent headless adapter now calls those authoritative modules without reimplementing formulas. Subsequent balance experiments should extend its telemetry and action coverage. At minimum record: seed/map type/size, civ and seat, policy/difficulty, speed/victory toggles, per-round city/population/food/industry/science/gold/stockpile, tech/age milestones, production queue and progress, unit strength/losses, war/contact/elimination state, victory reason/turn, action acceptance/rejection, actor time and checkpoint/GC counters. Preserve the exact fixture and raw JSON for every claim.

## Requirements gaps against the research specification

| Spec requirement | Current status | Evidence / consequence |
|---|---|---|
| One authoritative shared engine plus headless runner | **Partial, improved in working tree** | Frozen HEAD coupled lifecycle in `game.lua`; current `match_lifecycle.lua` and `actor_lifecycle.lua` provide extracted setup/advance/actor seams, with short peaceful native/Lua parity. |
| Observer-safe `observe` and legal-action enumeration | **Partial** | `Engine.observe` uses `Presentation.capture`; `legalActions` supplies a partial observer-only proposal list, not an exhaustive mask. |
| Full 2–4 player, mirror, map and policy benchmark | **Partial** | Existing tournament/session fixtures exist, but archived balance numbers are old-HEAD/limited-policy snapshots. |
| Genuine elimination and timeout/draw policy | **Gap** | No elimination state; round-limit score/draw and research wall/instruction/action budgets exist, but dead seats are not resolved. |
| Differential CraftOS/native conformance | **Partial** | 54 short checks, a full round-125 expedition game, and narrow war/capture/native save checks pass. Surprise War, broad old-save/multiplayer/route matrices remain open. |
| Current metric definitions, confidence intervals, effect sizes | **Gap** | Existing AI benchmark is historical smoke data; no current balanced-policy matrix. |
| Save migration and multiplayer privacy | **Strong partial** | Covered by save-resume/fog/network tests; physical/target runtime still separate. |


## Corrected unit-removal audit

`Actions.apply` already implements `disband` (present in audited HEAD), and
`ui.lua` confirms the command before dispatch. Earlier brief/issue wording
incorrectly grouped disband with missing equipment upgrades and formations.
Those are different capabilities: deleting a piece already works; preserving
its equipment/experience investment through modernization still lacks a
general action. The simulator proposal interface must expose the existing
disband action, not add a duplicate gameplay rule.
