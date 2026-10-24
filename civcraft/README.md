# CIVCRAFT v0.6 — Territorial Hex Civilization

A Civilization-inspired, turn-based hex 4X for **CC:Tweaked**, supporting local hot-seat (2–4 human/AI slots) or multiplayer over rednet. Local games use one computer or an Advanced Monitor; networked games use an authoritative host. Computers communicate through **rednet modems**, either wireless (within range) or wired (via the same wired modem network). It also works over interdimensional wireless modems. No HTTP or external web server is needed after installation.

## Install on every participating computer

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-civcraft.lua
```

On the host:

```sh
/civcraft/game.lua host
```

On each client:

```sh
/civcraft/game.lua join
```

The join command discovers a hosted game automatically. If discovery fails or multiple hosts exist, use `/civcraft/game.lua join <host-computer-ID>`. The lobby shows the host ID. Connect 2–4 players, then tap **START GAME** on the host. Players are identified by ComputerCraft computer ID; use fixed dedicated machines if you intend to resume saves. The host also plays.

For a clean new match, explicitly run `/civcraft/game.lua host --new`. This deletes the existing match save. Simply reinstalling will **not** delete saves. To opt into host autostart for a dedicated computer, add `--startup` to the installer command; it will not overwrite an existing startup script.

## Gameplay

The map is a 12×8 **pointy-top hexagonal** continent map: `.` plains, `f` forest, `^` mountain, `~` water; mountains and water block movement. Your settlements and units are coloured by player. Cities are walled-settlement icons, warriors carry a shield and sword, and settlers appear as wagons. Forest, mountain and water also have distinct pixel-art symbols. Touch a tile to select it.

- **Cities:** Each city produces 2 food, 2 wood, and 1 science at the end of a full round. Technology boosts food and science production.
- **Warriors:** Recruit for 5 wood at an unoccupied city. Select one, tap MOVE, then tap an adjacent passable tile. Warriors can defeat an enemy unit or capture an enemy city.
- **Settlers:** Recruit for 8 food and 8 wood at an unoccupied city. Move to unoccupied land, then tap FOUND. New cities must be at least 3 hexes from another city.
- **Research:** Spend science on up to 3 technology levels (8, 14, and 20 science). These boost city production.
- **Turns:** Each player issues orders independently; actions are applied by the host. Tap END TURN when finished. Only after everyone finishes does production accrue and movement reset.
- **Victory:** Found or capture 5 cities, or have the highest resource/technology/city score after 25 rounds.

A full game should be playable in a short session. The host saves game state to `/civcraft/data/save.dat` after actions and at round boundaries. Clients reconnect using their original ComputerCraft IDs. A player's actions and turn ending are rejected when they aren't registered or have ended their turn.

## Display and modems

Best experienced on a **5×5 Advanced Monitor** at scale 0.5 (a 4×3 monitor can also work). The program selects the largest monitor on each machine, or falls back to a colour-capable computer terminal. Monitor taps and terminal mouse clicks are supported. The visual presentation intentionally uses standard CC colour text, so no graphics mod, Basalt, Pine3D or extra dependency is required.

Each machine needs a peripheral modem for networked play; wired modems need to be part of the same wired network. CC:Tweaked does **not** offer unlimited-range normal wireless networking—distance and dimensions matter.

## Implementation notes

The host maintains the only authoritative world state, checks unit ownership and resource costs, and broadcasts snapshots. Clients display those snapshots and submit commands; they never directly modify the host state. This is a cooperative local network game, not an adversarial or cryptographically secure network protocol. There is no AI in this first edition. For now, a game requires at least 2 connected human computers to start.

The initial release is intentionally small. Natural next steps are procedural maps, diplomacy, tactical combat, city upgrades, fog of war, AI seats, richer graphics, and reconnect/lobby management.

## Local hot-seat mode (2–4 players, one computer)

Run `/civcraft/game.lua local`. From the lobby, add or remove participants (two to four), then start the match. Each player uses the same screen and passes it along after pressing **END TURN**. The handoff screen hides the map and resources until the next player taps **READY TO PLAY**. No modem, rednet, network connection or second computer is required. Hot-seat progress is saved separately at `/civcraft/data/local-save.dat`, so network saves remain untouched. Start a new local match with `/civcraft/game.lua local --new` (which replaces only the local save).

### Updated graphics

CIVCRAFT now uses a pixel-art map, icon-based units and cities, a dark Railbreak-inspired UI, large touch targets, a compact local-player lobby, and a dynamically scaled renderer. The game continues to work in ordinary text terminals without pixel graphics, with fewer visual details.

## Hex map and contextual touch controls (v0.3.0)

The six-direction hex grid is shared between CIVCRAFT's rules and visual interface. Selecting one of your unmoved units highlights its **legal destinations**; blocked water and mountain hexes, friendly occupied hexes, and invalid attacks are excluded. Select a highlighted hex to move or attack. A city selection exposes **WARRIOR**, **SETTLER**, and **RESEARCH** commands; a settler selection exposes **FOUND CITY**, while open terrain can be inspected. The contextual action bar also offers **CANCEL** and **END TURN**. Hex selection resolves the actual six-sided polygon, not overlapping rectangular hitboxes.

Local multiplayer: run `/civcraft/game.lua local` (or simply launch CIVCRAFT from FPB Store) for 2–4 players sharing one screen, with private turn handoffs and separate local saves. To host a network match, explicitly run `/civcraft/game.lua host`.

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

Each local game now has **three independent campaign slots**, selectable from the title screen. The selected slot shows its campaign name and current round; you can create a new game, continue, or delete a slot (with a second-tap confirmation). The original `/civcraft/data/local-save.dat` is still importable into an untouched first slot. Previous campaign files are preserved as backups during save replacement, and removing a migrated slot does not resurrect a deleted game.

From the local lobby, choose **MAP SIZE** (compact 12×8, standard 16×10, large 20×12) and **REROLL SEED**. Worlds are generated deterministically, and the seed, map dimensions, terrain and starting locations are serialized in each campaign. A seed always regenerates the same map. Loading an older map preserves its original 12×8 terrain instead of silently changing geography.

**Fog of war** is owned independently by each civilization. Capitals initially reveal nearby terrain; scouts, explorers and ships extend the field of view according to their own vision stat. Moving away leaves discovered hexes dimmed while still-unexplored hexes remain dark. Enemy units appear only when in current sight. Hot-seat changes remove the previous player's selection and movement preview, preventing accidental map leaks.

## Strategy depth

There are **24 connected technologies**, spanning navigation, astronomy, cavalry, fortification, commerce and late-game advances. The **TECH TREE** in a city opens a connected graphical research canvas. Prerequisite links are drawn behind nodes, researched/available/locked states are visually distinct, nodes can be tapped for details, and the view can be panned and zoomed. On text-only computers, the game uses an efficient era-by-era technology list instead.

The game now offers **10 civilizations**, **13 units**, and **13 city improvements**. Units have separate attack, defense, sight, attack range, and movement-point budgets. Pathfinding considers movement costs: hills and forest slow most land units, scouts travel through forest efficiently, cavalry is faster on open ground, and ships navigate water. Ranged units can strike visible enemy targets without occupying the target's hex. The unit inspector describes each unit's distinctive ability and statistics; valid movement is highlighted in green and attacks in red.

City management retains production, workforce assignment and population growth. Opponents have lightweight AI for research, development, exploration, recruitment and warfare. These mechanics are designed to run without requiring a dedicated monitor or external dependency; pixel graphics are used automatically when available.

### Version and compatibility

This edition is **v0.6.0**. Run the existing `install-civcraft.lua` installer or update through FPB Store. Game code is updated without deleting `/civcraft/data`. Network-host sessions continue using their existing dedicated save, while local hot-seat campaigns use the three-slot manager.

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
