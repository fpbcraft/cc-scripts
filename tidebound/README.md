# TIDEBOUND: The Shattered Expanse (v4.0)

A **four-civilization** shared-screen space 4X game for CC:Tweaked Advanced Monitors, redesigned around politics, discoveries, faction personalities, and narrative decisions. Supports **1–4 human players**, with the remaining empires operated by local AI. Best on a **5×5 Advanced Monitor** with the optional **CC: Graphics** mod's 256-color pixel mode. It falls back to character mode if graphics is unavailable.

> This is a gameplay overhaul, not a save-compatible update of Stellar Frontier 3.x. The installer preserves your existing v3 save and installs v3 separately.

## Installation

Run on an Advanced Computer attached to a color Advanced Monitor:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-tidebound.lua
/tidebound/tidebound.lua
```

The installer downloads and syntax-checks all nine Lua files before changing active game code. It preserves saves and automatically rolls back the code files if activation fails. Use `--startup` only on a dedicated game computer. Existing startup scripts are backed up if possible and otherwise left untouched.

Previous editions remain installed:

```sh
/tidebound/tidebound-stellar-frontier.lua   # Stellar Frontier v3.0.1
/tidebound/tidebound-kingdoms.lua           # Kingdoms v2.1
/tidebound/tidebound-classic.lua            # Naval game v1
```

Saves: `/tidebound/expanse-save.dat` (v4) and `/tidebound/save.dat` (v3). Each v4 save keeps a `.bak` fallback copy. Legacy saves are not converted.

## The world

- **Four empires**; choose 1–4 humans and AI fills the remainder.
- **40 connected star systems** with fog of war, worlds with unique properties, chokepoints, neutral settlements, Rift Aether resources and precursor anomalies.
- Play as the **Imperium**, **Concord**, **Ascendancy**, or **Free Systems** or change civilization names. Each civilization has different economic, scientific, military or diplomatic tendencies.
- Campaign length configurable from 16 to 32 galactic years (default 24). Rotating turn order across rounds.

## Your turn: empire economy vs. ship orders

There is **no empire-wide action cap**. As many economic, political, construction and science decisions as resources and queues permit may be made during your turn. Ship movements and actions are **per-vessel**. Every science ship, construction ship or military ship gets its own available orders, replenished at the start of each new galactic year.

- **Science vessels:** travel one connected star lane per order, reveal unknown systems, study anomalies and uncover narrative events.
- **Construction ships:** travel between connected systems, establish outposts in surveyed adjacent neutral territory, and found colonies.
- **Frigates / cruisers / capital ships:** strategic movement, fleet battles and planetary invasions against rivals at war. Capital ships are slow but powerful.
- **Construction:** each colony has one active district project, and each shipyard one active ship project. Buildings generally finish within 1–2 years. More colonies mean greater simultaneous production.
- **Research:** four branches (Engineering, Physics, Society and Exploration), four levels each. Technologies cost accrued Research; they don't consume ship orders.
- **Diplomacy:** trade accords, research sharing, non-aggression, defensive alliances, war declarations and requested peace treaties. Offers to humans await their response; AI accepts or refuses according to relationships and priorities.
- **RPG decisions:** 20 contextual dilemmas and linked follow-up chapters, with consequences for resources, prestige, stability, inter-empire trust and emergent civilization ethics.

## Resources

| Resource | Used for |
| --- | --- |
| **C**redits | Development, ships, treaties, civic policy, upkeep |
| **M**aterials | Outposts, ships, buildings, colony expansions |
| **R**esearch | Four technology branches, new production and strategic options |
| **A**ether | Rare ship classes, experimental technologies, scientific megaprojects |

Both ordinary and specialist colonies produce resources at the end of every galactic year. Choose between **Balanced, Industry, Scholarship, and Mercantile** civic priorities to alter production. Each policy change costs 4 Credits and may be made once per year.

## Victory routes

- **Domination:** occupy 22 of 40 systems.
- **Scientific:** finish Physics 4 and Exploration 4, collect and invest C35/M40/A4, and complete the three-year Transcendence project.
- **Diplomatic:** research Society 3, sign two defensive alliances, invest C45/M18, and complete the three-year Galactic Charter project.
- **Economic:** develop five colonies, stockpile C125/M65, and invest it in a three-year Mercantile Union project.
- **Legacy:** highest score at the final galactic year, calculated from territory, colony development, technology, resources, prestige and diplomacy.

## Using the touch UI

1. From the animated title screen choose **New Campaign** or **Continue**.
2. Choose the number of humans, adjust empire names using the on-screen keyboard and cycle their founding archetypes.
3. Pass the monitor to the person shown on the **Begin Turn** screen.
4. Tap a visible star to inspect its owner, colony and structures. Select **System Orders** to choose improvements, ships, colonization, diplomacy/integration and exploration actions. Disabled orders are still tappable to explain **why** they are unavailable.
5. **Ships** lists each vessel with its remaining orders. Tap **Order** and then an adjacent linked star to move the chosen ship.
6. **Science** spends research reserves on discoveries; **Empire** shows production and civic policies; **Diplomacy** manages rival governments; **History** records decisions and galactic events.
7. Choose the consequences of any pending events before ending your turn. Press **End** to pass control onward. All intervening AI turns execute automatically.

**Touch coordinates:** Graphics mode uses zero-based *pixel* touch coordinates, while vanilla text-mode monitors produce one-based *character* coordinates. The input boundary handles both formats before dispatching UI events.

**Hotseat privacy:** A handoff screen masks the world and says which human is next; complete privacy is inherently limited when sharing a physical monitor.

## Technical layout

```text
tidebound.lua                        Application launcher
expanse/content.lua                 Civilization definitions, machines, tech, ships, costs
expanse/events.lua                  Narrative dilemmas and follow-up event chains
expanse/sim.lua                     Pure seeded turn engine, AI, economy, warfare, diplomacy
expanse/render.lua                  Graphics-mode / text-mode drawing and hitboxes
expanse/ui.lua                      Title/setup, map, menus, orders, modal explanations, saves
```

The simulation never calls the monitor renderer. Touch input generates validated simulation commands. Save version is `4` and is intentionally independent of old releases.

## Testing

Local regression test suite under `tidebound/tests/simulation.lua` (run from the repository checkout on a system with `texlua`, from the project root). It tests procedural connectivity, AI turn progression, ship actions, economic production, research, diplomacy, event resolution, and simulated Graphics/text hit coordinates at three monitor sizes.

The offline renderer and Lua integration are tested. Physical Minecraft/NeoForge monitor tests have **not** yet been performed; performance on the actual server and overall game balance still need playtesting.