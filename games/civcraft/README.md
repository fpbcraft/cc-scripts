# CIVCRAFT — v0.9 development branch

New campaigns default to **Specialization V5**: one Settler and one Stone Guard,
player-chosen first-city placement, larger maps, city population/status banners
and three geographic specialty site types. It includes Landwork V3's charge-based
Builders, worked-tile fields/quarries/lumber camps, Settlement Capacity and population-consuming
Settlers, alongside Conquest/End Expedition, a 250-round Standard deadline with
Score fallback and territory-based recovery. Earlier campaign saves retain their
rules. Existing saves keep their selected profile; new campaigns can still
select earlier profiles from Campaign Options. See
[the opening and banner contract](docs/FOUNDERS-OPENING.md),
[M2's implementation record](docs/M2-LAND-DEVELOPMENT.md) and
[M1's campaign contract](docs/M1-CAMPAIGN-SCOPE.md). Later redesign systems
remain upcoming. Prototype prices are not calibrated
balance guarantees.

Implementation of the next gameplay iteration is tracked in [IMPLEMENTATION-v0.9.md](IMPLEMENTATION-v0.9.md), based on [design draft v0.9.1](ROADMAP-v0.9.md).

The subsequent balance redesign is specified in the [design ADRs](docs/adr/README.md)
and [balance implementation roadmap](docs/ROADMAP-balance.md). These capture
accepted design choices and planned milestones, rather than claiming the redesign
is already implemented.

New worlds use layered Minecraft-inspired biomes, habitat-specific deposits and
connected, nonpolar starting regions. Specialization V5 includes map presets
through **Huge 96×60** and **Vast 120×76**; existing saves keep their recorded
dimensions and geography. See the [generation contract](WORLDGEN.md) for opening
guarantees and versioned seeds, and [earlier world-generation benchmarks](WORLDGEN-BENCHMARK.md)
for their measured source and remaining validation limits.

A Civilization-inspired, turn-based hex 4X for **CC:Tweaked**, supporting local hot-seat (2–4 human/AI slots) or multiplayer over rednet. Local games use one computer or an Advanced Monitor; networked games use an authoritative host. Computers communicate through **rednet modems**, either wireless (within range) or wired (via the same wired modem network). It also works over interdimensional wireless modems. No HTTP or external web server is needed after installation.

## Diagnosing freezes

Run `/games/civcraft/game.lua local --debug` to record actions, AI turns, saves,
rendering stages and cooperative waits in `/games/civcraft/data/debug.log`.
The log is closed after each entry so it can be inspected after a forced restart.
The previous log segment is retained as `debug.log.previous` when the log rotates.
For network games, use `host --debug` or `join <host-computer-ID> --debug`.
For `Too long without yielding` during world loading or saving, update the full
program installation: the roadmap branch now includes a cooperative streaming
save writer and visibility checkpoints. Existing saves remain readable.

A diagnostic run records the CraftOS host version and display dimensions,
repeating them when the log rotates.
`gc.begin`/`gc.end` distinguish a full collection from
`yield.wait.begin`/`yield.wait.end`. Graphics uploads record each strip and the
freeze/unfreeze calls separately. An unmatched begin line locates the operation
that had not returned; elapsed values help distinguish slow work from waiting.
Keep both log files after a recurrence, before starting another session.

Logs are disabled during normal play. A last `*.begin` without its matching
`*.end` helps identify the stalled operation; it does not by itself prove its cause.

## Install on every participating computer

This branch contains the unreleased v0.9 roadmap implementation. To test the
same development code on every participating computer, use:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/codex/civcraft-roadmap/installers/civcraft.lua codex/civcraft-roadmap
```

The published `main` version can be installed with:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/installers/civcraft.lua
```

On the host:

```sh
/games/civcraft/game.lua host
```

On each client:

```sh
/games/civcraft/game.lua join
```

The join command discovers a hosted game automatically. If discovery fails or multiple hosts exist, use `/games/civcraft/game.lua join <host-computer-ID>`. The lobby shows the host ID. Connect 2–4 players, then tap **START GAME** on the host. Players are identified by ComputerCraft computer ID; use fixed dedicated machines if you intend to resume saves. The host also plays.

For a clean new match, explicitly run `/games/civcraft/game.lua host --new`. This deletes the existing match save. Simply reinstalling will **not** delete saves. To opt into host autostart for a dedicated computer, add `--startup` to the installer command; it will not overwrite an existing startup script.

## Minecraft & Create campaigns (v0.8)

New campaigns progress through **Survival**, **Iron**, **Redstone & Diamond**,
**Rotation**, **Brass**, and **Steam & Rail**. Each empire advances independently
by researching milestone technologies. The roster includes 45 technologies,
25 recruitable units, 38 buildings/projects, five hostile mobs, six natural
landmarks and six constructed wonders. The ten civilizations now represent
Minecraft villagers, miners, enchanters, engineers and explorers.

**Production chains:** develop wheat farms, libraries and furnaces, then deep
mines and diamond equipment. Andesite engineering and redstone lead to water
wheels, presses, crushing wheels and belts. Nether portals provide access to
blaze burners. A heated mixer needs a mechanical press and blaze burner; after
Brassworking, each mixer consumes one copper and one zinc to produce two brass
per round. Deployers, assembly workshops and mechanical crafters lead to steam
plants and industrial complexes. These are turn-based city buildings: fuel and
intermediate parts are included in industry costs.

**Materials:** claimed deposits provide iron, copper, zinc, redstone and diamonds
once their associated technology is researched. Specialized units consume two
stock on completion. The resource ledger shows stocks and projected net rates,
and offers purchases at 20 gold per stock once the material technology and a
trading hall are available. Friendly independent villages offer the same trade
access at 20 influence. This is the fallback when a rare deposit is inaccessible.

**Railways:** research Railways, select an engineer, and choose **BUILD RAIL**.
Choose a highlighted current or adjacent friendly land hex and confirm. Each
segment costs two iron and the engineer's remaining movement. Both ends of an
edge must have friendly rail to reduce movement cost to one-quarter point.
Stations require rail on the city-center hex. Connecting two or more stations
grants each linked city +2 industry and +2 gold; loops do not multiply bonuses.
Water, mountains, foreign land and landmark tiles cannot receive rails. Rail
ownership follows current territory, so captures can break or transfer networks.

**Special tiles:** Lush Caverns, Amethyst Geodes, Mushroom Islands, Ice Spikes,
Dripstone Caves and Ancient Cities provide additional food, industry or science
when worked by a citizen. Inspect the tile or open **CODEX → SITES** for its
bonus. In city production, **WONDER** offers the Great Oak Sanctuary, Beacon
Pyramid, Prismarine Monument, Enchanted Vault, Great Clockwork and Grand Terminal.
Choose an empty owned land hex and confirm its placement. Wonders finish through
city industry and are unique across the world. A competing completion releases
your queue while retaining invested progress. Their city bonuses follow control
of the landmark tile; they cannot overlap cities, other landmarks or rails.

**Hostile mobs:** choose **Off / Standard / Dangerous** in the lobby. Spawners
and pillager outposts appear outside a five-hex starting safety zone. After round
five, Standard spawns every five rounds and Dangerous every three. Each camp
supports at most three living mobs, with a global cap of one mob per twenty map
hexes. Zombies, skeletons and spiders appear first, creepers after round 25 and
pillagers later. Mobs pursue local targets and raid cities for limited loot;
they cannot capture a city or reduce it below one HP. Surviving melee infantry
occupying a camp clear it permanently for 25 gold. Creepers die after exploding.

**Villager city-states:** independent farmer, librarian and toolsmith villages
have their own guards and face mob raids. They do not use player slots or count
as rival capitals. Inspect a discovered village to send an envoy: 25 gold grants
10 influence, once per five rounds. Defeating a mob within three hexes grants
another 10 influence. Trade opens at 20 influence. The highest influence at or
above 40 earns the alliance, with player ID breaking ties. Its bonus goes once
to the ally's oldest remaining city: +2 food, science or industry according to
village type. Villages can be conquered; their diplomatic benefits then end.

**Victory:** new campaigns offer four routes, checked at the round boundary:

- Conquest: control every original rival capital as well as your own.
- Industry: maintain three industrial complexes in cities on the same station
  network for ten consecutive rounds. A disconnected network resets the counter.
- End expedition: research End Expedition and complete an End Staging Ground,
  Eyes of Ender, Expedition Equipment and Dragon Expedition in the same city.
- Score: at round 180, lead in cities, population, completed buildings and
  technologies. Unspent science is excluded. Simultaneous qualifiers share victory.

The resource ledger exposes victory progress. The Codex describes all content
and requirements; turn reports include Age changes, wonders, raids, influence
and victory progress. Nether and End exploration use city research/projects on
the existing map rather than additional dimension maps.

### Updating existing campaigns

Saves migrate to version 6 without rerolling terrain, replacing cities, deleting
units, clearing research/production progress, or changing campaign slots. Stable
content identifiers resolve to their new Minecraft names. Campaigns without the Create ruleset
retain the eight-city / round-90 victory rules and default to mobs off; they do
not receive newly generated landmarks, spawners or villages. New prerequisites
and balance apply to the updated content, so an unfinished project may need
additional research or a local prerequisite building before it resumes.

Network players should all run the same version to share the same rules,
research controls and observer-safe event playback. The installer preserves `/games/civcraft/data`. To test this branch:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/codex/civcraft-roadmap/installers/civcraft.lua codex/civcraft-roadmap
```

Create a new campaign in an empty slot to get the full expansion. Do not use
`host --new` on a network save you want to retain.

## AI difficulty

In the lobby, open Campaign Options and select an AI's level to cycle Settler,
Chieftain, Prince, King and Deity. Each AI can have its own setting, independently
of hostile mobs. Prince is the default for existing saves. Levels change planning,
search depth and decision quality; civilization personality, resources, vision,
combat statistics, costs and action budgets stay the same. King and Deity consider
legal follow-up attacks and future city yields. Difficulty is fixed after starting.

## Council of Civilizations

The Council forms after Currency with two living civilizations. Open its top-bar
button for Status, Election or Agenda. Sessions recur every ten speed-scaled
rounds; ballots close after three. Each civilization has two delegates, with at
most one extra from a village allied at 60 influence for three rounds. Votes are
secret until closing; Recent Results shows public ballots and AI explanations.

A strict majority elects leadership. Diplomatic victory additionally needs two
thirds of all delegates, another civilization's support, Stock Logistics and a
Council Hall. It is selectable in new campaigns; older saves retain their victory
settings. Each member can propose one opening-round resolution. Temporary trade
facilitation, embargo, peace and censure affect real market, commerce, combat and
reputation rules. Conversation Requests can ask for a voting pledge; the ballot
must still be cast in Council. Ready members may vote without gaining actions.

## Shared gameplay and controls

CIVCRAFT is a turn-based 4X game on a **seeded hexagonal world**. In the lobby,
choose a map size (**Compact 24×16**, **Standard 40×26**, **Large 56×36**,
**Huge 72×46**, or **Vast 96×60**),
a map type (**Continents**, **Archipelago**, **Pangaea**, or **Highlands**),
the seed, and each participant's civilization. Two to four human/AI empires
compete to explore, settle, develop, research, and conquer. Saves preserve the
generated terrain, territory, fog, technology, and production progress. Cities
receive short, randomly selected names from their civilization's themed pool.
Names appear above cities and in city navigation, and remain stable in saves.

- **Explore and expand:** Units use movement points, terrain-dependent movement
  costs, vision and attack ranges. Scouts reveal farther, naval vessels travel
  on water, and settlers found cities at least three hexes apart. Fog hides
  unexplored land and enemy units outside current sight.
- **Settlers and protection:** An unprotected settler is captured immediately
  when a melee attacker reaches its tile. Ranged attacks damage it normally.
  One settler and one protecting unit can share a hex; attacks hit the protector
  first. Winning melee combat captures the remaining settler, while defeating
  the protector at range leaves its settler unprotected. Captured settlers have
  no movement until a later turn. Use Select Settler / Select Guard in the
  inspector to order the intended unit. Use Attach Escort to link their movement; both units must afford each step.
- **Zone of control:** Hostile melee land units control adjacent passable land,
  combat ships control adjacent water, and cities control both. Entering control
  stops further movement for the current turn; military units can still attack
  with remaining movement. Civilians and support units exhaust their remaining
  movement on entry. Mounted units ignore control. Amber destination rings mark
  stops. A fresh turn may leave a zone it started in. Discovering a hidden guard
  can interrupt a route or attack approach; the unit stops at its actual position
  and retains any unused attack. Current maps have no river-edge control rules.
- **Manage cities:** Each citizen works a tile and has a Food, Industry or Science
  assignment. Jobs and worked tiles share the same population pool. **JOBS +**
  automatically chooses a free owned tile of that yield type; **-** unworks one
  and makes that citizen idle. **TILES** (or **HEX** on compact screens) lets
  you choose the exact tile. Jobs are derived from the tile's strongest yield,
  with science winning ties, then industry if it exceeds food. No matching free
  tile means that job cannot be added. Manual and automatic assignments update
  the same yields; citizens cannot be counted twice.
- **Production:** Choose **PROD**, then **UNITS** or **BUILDS**. City projects
  accumulate industry each full turn instead of consuming a resource wallet
  immediately. Changing projects preserves their individual progress.
  Switching asks for confirmation. Locked projects are hidden; the adjacent book opens their Codex entry. Most projects take 2.5 times their former wood cost in industry. Scouts cost 5 industry; settlers start at 12 and rise by 5 for each settler your empire finishes training (12, 17, 22, 27, ...). The count persists after founding or losing a unit, and applies across all cities. Old saves estimate the initial count from surviving settlers and cities beyond the capital. Technologies and strategic stocks unlock specialized units.
- **Research:** The connected **TECH TREE** shows prerequisites, researched
  and available technologies, progress and expected turns. Select a technology
  and start research; science accumulates when a full round ends. Research costs
  are three times the earlier values, starting at 24 science. Drag the
  research canvas to pan, or drag compact details to scroll.
- **Turns and victory:** Each human player issues orders independently and ends
  their turn. AI players use the same production and research rules. A round
  advances after everyone finishes; the match ends upon reaching a
  campaign victory condition or the round limit.
  A waiting screen names the AI currently taking its turn, then shows
  **PROCESSING ROUND** while the next round is prepared.

The map stays central with a permanent inspector. City **INFO**, **JOBS**,
**TILES** and **PROD** views separate statistics from the task being edited;
compact unit inspectors separate actions from secondary details. Unit actions
use a compact icon grid; wider inspectors pair icons with short labels, while
narrow ones show the icons alone. Extremely short sidebars open a full-screen
inspector. **PREV/NEXT**, the scrollbar and
mouse wheel navigate long lists. Status messages appear below the map.

One primary button occupies the inspector footer. It shows **UNIT ORDERS**,
**PRODUCTION** or **RESEARCH** and opens the corresponding unresolved decision.
Once those decisions are resolved, it becomes **END TURN**. Explicitly selecting
**NO PRODUCTION** satisfies a city's reminder while preserving project progress.
The top-right buttons open **TECH TREE**, **FACTIONS**, **EMPIRE**, **CODEX**,
**REPORT** and **PAUSE**. Zoom buttons remain in the left sidebar, with
**WORLD OVERVIEW** at its bottom. Four clickable map edges pan the view.
Drag inside the map to pan on a computer; CraftOS monitor windows also support
mouse dragging. Vanilla Minecraft monitor taps use the edge strips.

**+ / -** zoom while preserving the camera center. The world overview respects
fog of war and can be clicked to jump to a region. The default map shows terrain,
cities, units and borders. **RESOURCES**, **YIELDS**, and **TERRITORY** are
independent overlay toggles; **TERRAIN** clears them. Yields zoom in to show
consistent drumstick/cog/flask icons. Yields of one through five repeat the icon;
larger yields use an icon and number. Zero yields are omitted. A city tile shows
its base yields plus buildings and civilization bonuses; adding its worked tiles
gives the total shown in the inspector. Terrain detail increases with zoom.

**EMPIRE** opens a paged list of all owned units and cities; selecting an entry
centers the map and opens its inspector. **UNIT ORDERS** cycles through awake
units with movement left, excluding sleeping, auto-exploring and skipped units.
This navigation never activates movement mode. When a unit occupies a city tile, use the
inspector's **CITY / UNIT** chooser to inspect either one; map taps select the
unit first.

Selecting a unit only inspects it. Click it again, or **DESELECT**, to clear it.
Use **MOVE / ATTACK** to show destinations: cyan dotted outlines and movement
cost numbers mark moves; red crosses mark attacks. Choose a target to preview
the route, then click it again or press the confirm icon. Gold pips identify
units that can still act. Gold-framed worker badges identify worked tiles. **CANCEL MOVE** leaves the unit selected.
**QUEUE MOVES** and **ADD WAYPOINT** can target undiscovered hexes. Selecting a
unit with a route shows the committed known path in solid gold, its fogged
continuation as blue dots, and muted dashed estimates for later waypoints;
square markers show each destination. Newly discovered blocked steps pause the
route without starting combat.
**SLEEP UNIT** excludes a unit from unfinished-order reminders across rounds;
**WAKE UNIT** restores active orders. Other unit actions require their own
inspector buttons. Escape closes a dialog or cancels the current action first.

**SKIP TURN** ignores a unit for the current turn's reminders without spending
its remaining movement. It becomes available again next turn; accepted new
orders clear the skip immediately. Unlike Sleep, Skip Turn does not persist
across turns. An eligible Surprise War response is a new reminder window, using
only the defender's unspent actions. The primary turn button handles remaining
unit, production and research decisions before it offers **END TURN**.
Hotseat handoffs clear the outgoing camera, selection and action overlays; the
next player starts centered on their own city or unit.
A scrollable **turn report dialog** lists economic changes, completed research
and buildings, city growth, and recruited/lost/damaged units. **REPORT** reopens
it. Reports contain only that player's empire information.

**CODEX** contains every unit, building, technology and gameplay mechanic,
including costs, requirements, abilities and controls. The technology graph has a separate
detail inspector. A pause menu provides **Resume**, **Save**, **Main Menu**, **Exit** and
a persistent **Audio** toggle. A connected speaker plays interaction effects
and an original title-screen melody; play remains silent without a speaker.

## Economy, growth and combat

The top strip shows gold, food, industry, science and strategic stocks with
projected changes. Click it for the complete ledger. Cities earn two gold plus
population each round, with market/bazaar/bank bonuses. Units pay their listed
upkeep; an exhausted treasury disbands unpaid units. You can disband a unit
from its inspector after confirmation. Owned iron, horses and saltpeter deposits
produce one stock per round; specialized units consume two on completion.

Each citizen eats two food per round. Growth needs surplus food in storage
(20 + 8 × population) and at least four rounds since the last population change.
The inspector shows growth time, stagnation or starvation. Three hungry rounds
with empty storage lose a citizen, down to one. Borders grow independently,
claiming one adjacent hex at a time within three hexes of the city.

Units have 100 HP, experience, levels and effective attack/defense power.
Injuries weaken them; levels strengthen them. Melee exchanges damage, while
ranged attacks avoid immediate retaliation. Each unit attacks once per round.
**FORTIFY / HEAL** restores health each round, faster in friendly territory;
resting units also recover. Cities have 200 HP and separate outer defenses:
walls add 100 HP, fortresses 200. Siege units deal full damage against walls.
Only surviving melee units capture cities. Cities recover unless besieged;
functioning walls permit one ranged strike per round. The Codex explains the
combat formulas, healing, siege and experience rules.

Scouts and explorers can **AUTO EXPLORE** along safe routes, continuing on new
rounds until stopped or no frontier remains. Coastal cities need a **SHIPYARD**
to build naval units. **NAVIGATION** permits land units to embark at two movement points per water
hex during a land-start turn. Starting a normal round at sea grants at least six
movement points and reduces water travel to one point per hex. Landing consumes
the remaining allowance, so it cannot fund extra movement inland. Embarked
combat units, including archers, make adjacent melee attacks onto land and receive
normal retaliation. Land melee cannot initiate attacks against units on water;
land ranged units may fire at embarked targets without Navigation. Settlers
cannot found cities at sea. Loading never refreshes movement. A Surprise War
response starting at sea uses the faster rate with only its unspent movement.

## Display and modems

Designed for **3×3 through 5×5 Advanced Monitors** at scale 0.5, including rectangular arrangements. Compact layouts preserve both side panels and page long lists. The program selects the largest monitor on each machine, or falls back to a colour-capable computer terminal. Monitor taps and terminal mouse clicks are supported. The renderer uses native pixel graphics when available and standard CC colour text otherwise. No graphics mod or Pine3D is required. Diplomacy uses a bundled, pinned Basalt 2.5 runtime; the normal CivCraft installer includes it, so no separate dependency installation is needed.

Each machine needs a peripheral modem for networked play; wired modems need to be part of the same wired network. CC:Tweaked does **not** offer unlimited-range normal wireless networking—distance and dimensions matter.

## Implementation notes

Pixel rendering batches the whole frame into a single `drawPixels` call.
Terrain sprites and territory claims are cached, and only visible map rows and
columns are traversed while panning. Text terminals batch changed rows with
`blit`. Drag events are coalesced to avoid building a backlog of redraws. Long drawing
and pathfinding work yields cooperatively to CraftOS without dropping queued
input or disabling its watchdog.

The host maintains the only authoritative world state, checks unit ownership and resource costs, and broadcasts snapshots. Clients display those snapshots and submit commands; they never directly modify the host state. This is a cooperative local network game, not an adversarial or cryptographically secure network protocol. Local hot-seat supports human and AI seats; networked games currently require at least two registered computers to start.

Earlier release notes below document the incremental development of CIVCRAFT. For current gameplay rules, see **Minecraft & Create campaigns** above.

## Local hot-seat mode (2–4 players, one computer)

Run `/games/civcraft/game.lua local`. From the lobby, add or remove participants (two to four), then start the match. Each player uses the same screen and passes it along after pressing **END TURN**. The handoff screen hides the map and resources until the next player taps **READY TO PLAY**. No modem, rednet, network connection or second computer is required. Hot-seat progress is saved separately at `/games/civcraft/data/local-save.dat`, so network saves remain untouched. Start a new local match with `/games/civcraft/game.lua local --new` (which replaces only the local save).

### Updated graphics

CIVCRAFT now uses a pixel-art map, icon-based units and cities, a dark Railbreak-inspired UI, large touch targets, a compact local-player lobby, and a dynamically scaled renderer. The game continues to work in ordinary text terminals without pixel graphics, with fewer visual details.

## Hex map and contextual touch controls (v0.3.0)

The six-direction hex grid is shared between CIVCRAFT's rules and visual interface. Selecting one of your unmoved units highlights its **legal destinations**; blocked water and mountain hexes, friendly occupied hexes, and invalid attacks are excluded. Select a highlighted hex to move or attack. A city selection exposes **WARRIOR**, **SETTLER**, and **RESEARCH** commands; a settler selection exposes **FOUND CITY**, while open terrain can be inspected. The contextual action bar also offers **CANCEL** and **END TURN**. Hex selection resolves the actual six-sided polygon, not overlapping rectangular hitboxes.

Local multiplayer: run `/games/civcraft/game.lua local` (or simply launch CIVCRAFT from FPB Store) for 2–4 players sharing one screen, with private turn handoffs and separate local saves. To host a network match, explicitly run `/games/civcraft/game.lua host`.

## Expanded 4X systems (v0.4.0)

The title screen now offers **New Campaign**, **Continue**, and **Exit**. During a game, use **Pause** (or Escape/Q) for **Resume**, **Save**, **Main Menu**, or **Exit**. Local hot-seat and rednet games remain separate, and older local save files are upgraded in memory without deleting them.

### Civilizations and AI

The lobby allows 2–4 participants with each slot assigned to a human or AI, while retaining at least one human. Tap **CIV** beside a player to cycle through the Verdant League (farm food bonus), Iron Dominion (mine output bonus), Astral Academy (research bonus), and Dust Nomads (fast scouts). AI empires research technology, construct improvements, recruit and move units, and found/capture settlements. AI behavior uses lightweight deterministic heuristics suitable for ComputerCraft.

### Technology and army

Eight technologies form a prerequisite-based tree: Agriculture, Mining, Writing, Bronze Working, Masonry, Horseback Riding, Engineering, and Philosophy. A city's **TECH TREE** opens the whole tree, including locked and completed nodes, costs, and available technologies. Units now include Warriors, Settlers, Scouts, Spearmen and Horsemen with differing costs, strength and movement allowances. Spearmen and horsemen require technology; battles account for unit strength and defensive walls.

### City development

Cities contain a population of citizens assigned to **food**, **wood**, and **science** jobs. The **POPULATION** menu reallocates workers between sectors, with their sum constrained to the city's population. Food surplus accumulates and grows the city, adding another worker. Different buildings can be constructed inside each city: Farms, Mines, Libraries, Walls, Workshops and Academies. They cost wood, require technology, and modify production or defense. Select a city to see its population, assignments and completed improvements in the inspector.

The economic system uses per-turn resource yields and does not require continuous redstone input or external peripherals.

## Generated campaigns and discovery (v0.5)

Each local game now has **three independent campaign slots**, selectable from the title screen. The selected slot shows its campaign name and current round; you can create a new game, continue, or delete a slot (with a second-tap confirmation). The original `/games/civcraft/data/local-save.dat` is still importable into an untouched first slot. Previous campaign files are preserved as backups during save replacement, and removing a migrated slot does not resurrect a deleted game.

From the lobby, choose **MAP SIZE** and **REROLL SEED**. Specialization V5 uses Compact 32×22, Standard 56×36, Large 72×46, Huge 96×60 and Vast 120×76. Earlier profiles retain their setup sizes. The seed, generation version, dimensions, terrain and starting locations are serialized in each campaign. Identical setup and generation versions reproduce the same map; loading an older map preserves its recorded geography rather than regenerating it. See the [generation contract](WORLDGEN.md).

**Fog of war** is owned independently by each civilization. Capitals initially reveal nearby terrain; scouts, explorers and ships extend the field of view according to their own vision stat. Moving away leaves discovered hexes dimmed while still-unexplored hexes remain dark. Enemy units appear only when in current sight. Hot-seat changes remove the previous player's selection and movement preview, preventing accidental map leaks.

## Strategy depth

There are **24 connected technologies**, spanning navigation, astronomy, cavalry, fortification, commerce and late-game advances. The **TECH TREE** in a city opens a connected graphical research canvas. Prerequisite links are drawn behind nodes, researched/available/locked states are visually distinct, nodes can be tapped for details, and the view can be panned and zoomed. On text-only computers, the game uses an efficient era-by-era technology list instead.

The game now offers **10 civilizations**, **13 units**, and **13 city improvements**. Units have separate attack, defense, sight, attack range, and movement-point budgets. Pathfinding considers movement costs: hills and forest slow most land units, scouts travel through forest efficiently, cavalry is faster on open ground, and ships navigate water. Ranged units can strike visible enemy targets without occupying the target's hex. The unit inspector describes each unit's distinctive ability and statistics; valid movement is highlighted in green and attacks in red.

City management retains production, workforce assignment and population growth. Opponents have lightweight AI for research, development, exploration, recruitment and warfare. These mechanics are designed to run without requiring a dedicated monitor or external dependency; pixel graphics are used automatically when available.

### Version and compatibility

This edition is **v0.6.0**. Run the existing `installers/civcraft.lua` installer or update through FPB Store. Game code is updated without deleting `/games/civcraft/data`. Network-host sessions continue using their existing dedicated save, while local hot-seat campaigns use the three-slot manager.

## v0.6: Game systems and UX redesign

The authoritative implementation objectives, touch layout, world generation, turn-based city projects, tech graph, diplomacy-ready civilization abilities, fog of war and QA checklist are tracked in [DESIGN-v0.6.md](DESIGN-v0.6.md). Do not treat a checked task as complete until integration and regression tests pass.

## v0.6: Worked hexes, production, and research

[Read the full v0.6 design and acceptance specification](DESIGN_4X.md).

- **Territory:** each city controls a contiguous radius-two hex region (radius three at population six). Distinct owners have visible six-edge borders. Contested hexes belong to the nearest city, with a stable city-ID tie break.
- **Resource deposits:** worlds generate food/production resources and strategic iron, horses, and saltpeter. Change the left map-mode panel between **Terrain, Territory, Resources, and Yields**; unrevealed deposits stay hidden by fog of war.
- **Assign citizens by tapping:** select a city, choose **WORK HEXES**, and tap highlighted owned hexes to work/unwork them. Workers cannot exceed city population. The city center is always worked, and each staffed hex contributes its displayed food/industry/science yields. Choose **DONE WORK** to resume ordinary selection.
- **Production:** a city's right sidebar lists units and buildings with estimated **turns**, project selection and page controls. Production accumulates at each round boundary. Ordinary production does **not** consume stockpiled food or wood. Certain advanced units require an eligible strategic deposit inside your territory.
- **Research:** selecting a technology in the connected canvas assigns a research target. The graph nodes show an icon and name; the adjacent detail inspector describes its prerequisites, unlock and expected completion time. The civilization's per-turn science advances research without an upfront science purchase.
- **Campaign safety:** named three-slot saves, deterministic world seeds and separate civilization discovery histories remain supported, including on single-terminal CraftOS environments. Older campaign saves migrate without deleting existing slot data.

The game is designed for touch input but also supports keyboards and text terminals. Automated test coverage includes deferred construction and research, strategic eligibility, worked-tile yields, deterministic geography, hot-seat privacy and graphics navigation.


## Current campaign navigation and research

The title menu offers New Campaign, Load Campaign, Remote Multiplayer, Settings
and Exit. New and Load use separate slot menus with Back controls. Replacing an
occupied campaign requires confirmation; updating the program preserves saves.
Loading keeps previous events readable in the Event Log without replaying them.

Choose a civilization from its lobby dropdown; the lobby shows its bonuses and
fixed AI personality. Hosts can configure other participants, while remote human
players can change only their own civilization before starting.

The research screen keeps the connected tree and a technology sidebar visible
at every screen size. Select a node, then use the pinned Research button to make
it active. The sidebar lists its progress, prerequisites, purpose and unlocks,
with links to their Codex entries. Prerequisites are left of their dependents;
arrows show direction, amber links enter the selected technology and blue links
lead onward. Click a prerequisite/dependent in the sidebar to focus it. Pan/zoom
controls remain available on touch-only screens; the sidebar pages separately.

Click the science value in the top resource strip, or the turn prompt when research is pending, to choose from available technologies. The quick picker shows saved progress, science cost, the current project, and estimated turns at the current science rate. Switching projects retains progress; **TECH TREE** still opens the complete technology graph.

Visible formations have separate faction-colored map badges. Click a badge to select that exact unit, including a civilian sharing a military unit’s hex; click the city banner to inspect the city. Badges stay above city labels, and an armed move or attack continues to use the hex target. Remembered terrain does not retain unit badges.
