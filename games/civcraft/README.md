# CIVCRAFT v0.7.0 — Territorial Hex Civilization

A Civilization-inspired, turn-based hex 4X for **CC:Tweaked**, supporting local hot-seat (2–4 human/AI slots) or multiplayer over rednet. Local games use one computer or an Advanced Monitor; networked games use an authoritative host. Computers communicate through **rednet modems**, either wireless (within range) or wired (via the same wired modem network). It also works over interdimensional wireless modems. No HTTP or external web server is needed after installation.

## Install on every participating computer

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

## Gameplay (v0.7)

CIVCRAFT is a turn-based 4X game on a **seeded hexagonal world**. In the lobby,
choose a map size (**Compact 18×12**, **Standard 28×18**, or **Large 40×26**),
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
  Switching asks for confirmation. Locked projects are hidden; the adjacent book opens their Codex entry. Projects take 2.5 times their former wood cost in industry. Technologies and strategic stocks unlock specialized units.
- **Research:** The connected **TECH TREE** shows prerequisites, researched
  and available technologies, progress and expected turns. Select a technology
  and start research; science accumulates when a full round ends. Drag the
  research canvas to pan, or drag compact details to scroll.
- **Turns and victory:** Each human player issues orders independently and ends
  their turn. AI players use the same production and research rules. A round
  advances after everyone finishes; the match ends upon reaching the city
  victory condition or the round limit.

The map stays central with a permanent, scrollable inspector. The left controls
always use square icons. **PREV/NEXT**, the scrollbar, and mouse wheel scrolling
keep inspector actions reachable. The square bottom icons open **TECH TREE**,
**EMPIRE**, **NEXT IDLE UNIT**, **NEXT IDLE CITY**, zoom in/out, and **END TURN**.
The top-right book, clipboard, and pause icons open **CODEX**, **REPORT**, and
**PAUSE**. Four narrow, clickable map edges pan in their respective directions.
Drag inside the map to pan on a computer; CraftOS monitor windows also support
mouse dragging. Vanilla Minecraft monitor taps use the edge strips.

**+ / -** zoom while preserving the camera center. The compact minimap respects fog of
war and can be clicked to jump to a region; its adjacent icon opens a larger overview. The default map shows terrain,
cities, units and borders. **RESOURCES**, **YIELDS**, and **TERRITORY** are
independent overlay toggles; **TERRAIN** clears them. Yields zoom in to show
consistent drumstick/cog/flask icons. Yields of one through five repeat the icon;
larger yields use an icon and number. Zero yields are omitted. Terrain detail increases with zoom.

**EMPIRE** opens a paged list of all owned units and cities; selecting an entry
centers the map and opens its inspector. **NEXT IDLE UNIT** cycles through awake
units with movement left, skipping sleeping and spent units. These navigation
actions never activate movement mode. When a unit occupies a city tile, use the
inspector's **CITY / UNIT** chooser to inspect either one; map taps select the
unit first.

Selecting a unit only inspects it. Click it again, or **DESELECT**, to clear it.
Use **MOVE / ATTACK** to show destinations: cyan dotted outlines and movement
cost numbers mark moves; red crosses mark attacks. Choose a target to preview
the route, then click it again or press the confirm icon. Gold pips identify
units that can still act. Gold-framed worker badges identify worked tiles. **CANCEL MOVE** leaves the unit selected.
**SLEEP UNIT** excludes a unit from unfinished-order reminders across rounds;
**WAKE UNIT** restores active orders. Other unit actions require their own
inspector buttons. Escape closes a dialog or cancels the current action first.

**END TURN** asks for confirmation when awake units have moves remaining, a city
has no production, or an available research project is unassigned. **GO TO** buttons jump to the missing orders; **END ANYWAY**
skips them. Hotseat handoffs clear the outgoing camera, selection and
action overlays; the next player starts centered on their own city or unit.
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
to build naval units. **NAVIGATION** permits land units to embark at two moves
per water hex; embarked units cannot attack or found cities.

## Display and modems

Designed for **3×3 through 5×5 Advanced Monitors** at scale 0.5, including rectangular arrangements. Compact layouts preserve both side panels and page long lists. The program selects the largest monitor on each machine, or falls back to a colour-capable computer terminal. Monitor taps and terminal mouse clicks are supported. The renderer uses native pixel graphics when available and standard CC colour text otherwise. No graphics mod, Basalt, Pine3D or extra dependency is required.

Each machine needs a peripheral modem for networked play; wired modems need to be part of the same wired network. CC:Tweaked does **not** offer unlimited-range normal wireless networking—distance and dimensions matter.

## Implementation notes

Pixel rendering batches the whole frame into a single `drawPixels` call.
Terrain sprites and territory claims are cached, and only visible map rows and
columns are traversed while panning. Text terminals batch changed rows with
`blit`. Drag events are coalesced to avoid building a backlog of redraws. Long drawing
and pathfinding work yields cooperatively to CraftOS without dropping queued
input or disabling its watchdog.

The host maintains the only authoritative world state, checks unit ownership and resource costs, and broadcasts snapshots. Clients display those snapshots and submit commands; they never directly modify the host state. This is a cooperative local network game, not an adversarial or cryptographically secure network protocol. Local hot-seat supports human and AI seats; networked games currently require at least two registered computers to start.

Earlier release notes below document the incremental development of CIVCRAFT. For current gameplay rules, see **Gameplay (v0.7)** above.

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

From the local lobby, choose **MAP SIZE** (compact 12×8, standard 16×10, large 20×12) and **REROLL SEED**. Worlds are generated deterministically, and the seed, map dimensions, terrain and starting locations are serialized in each campaign. A seed always regenerates the same map. Loading an older map preserves its original 12×8 terrain instead of silently changing geography.

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
