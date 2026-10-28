# First CivCraft gameplay change package

27 October 2026. This is the concrete review package for moving from research
into game changes. **H1 is the specific healer change requested by the user
and is implemented in the working tree. P1 was subsequently approved by the user and is being implemented on
`codex/civcraft-p1-balance`; P2–P4 remain unapproved proposals.**

We have enough evidence to build and play a prototype. Perfect military AI,
exhaustive tournaments and equal victory shares are not prerequisites for
starting that prototype. Simulations, native checks and human playtests will
continue alongside implementation, and will determine which numbers survive.

The first playable slice should make opening choices compete and give a mature
city useful civilian work. Specialization and complementary Industrial victory
come next as one coordinated change. Army continuity follows; larger victory
and wonder reworks get their own focused review.

## H1 — user-requested healing split

**Implemented; validation recorded separately.**

- Passive rest/fortify healing remains **20 HP per round, owned territory only**.
- Healer support remains **10 HP per round within one hex**, and now works in
  owned, neutral or enemy territory.
- Existing ownership, range, HP cap, stacking and self-support behavior remain;
  this does not grant healing to another civilization's units.
- Healer AI values wounded friendly recipients outside owned territory.
- Help text describes both rules separately.

This gives armies a support-based recovery option during an expedition without
giving every unit free fortify healing abroad. It is separate from future
decisions about merging healer unit types or changing healing amounts.

## P1 — approved first implementation slice

### Opening calibration

These are explicit **starting values for a prototype**, not measured optima.
Run component ablations and a combined candidate against the unchanged rules.

| Item | Current | Proposed P1 |
|---|---|---|
| Ordinary city-center science | 1 | 2 |
| Scholar bonus | +2 science in every city | +1 science in the capital |
| Scout production | 5 | 15 |
| Stone Guard production | 13 | 20 |
| Settler production | 12 + 5 per previously trained Settler | 40 + 12 per previously trained Settler |
| Settler population cost | None | Keep none in this first candidate; test separately later |
| Wheat Farm | 15 production, Agriculture required, +2 food | 15 production, available immediately, +1 food; Agriculture adds the second food |

At frozen income of five industry/two science, those prices imply a three-round
Scout, four-round Guard, eight-round Settler and twelve-round 24-science
technology. Actual openings change as workers, growth, terrain and expansion
change income. In the measured current AI, a second city can already appear
at round three; “24 science at one science” is not an actual 24-round optimal
opening. Raising settler costs and changing the science floor must be evaluated
together.

Why this is worth prototyping: Civ VI's Scout/Warrior/Settler investments,
population-consuming settlement and research boosts give early choices a
visible future cost. CivCraft can create that relationship with its own shorter
campaign and Minecraft production theme. Copying Civ VI's raw prices would not
establish suitable timing.

### Three repeatable civilian projects

Add a production kind for repeatable projects alongside buildings, units and
wonders. They run until changed, use the city's industry instead of advancing
a construction queue, and retain existing passive building yields.

| New project | Requirement | Initial conversion rule |
|---|---|---|
| Ponder Research | Bookshelf Library and a selected unfinished technology | Every 4 industry supplies 1 additional science to that research |
| Tend Crops | Wheat Farm | Every 2 industry adds 1 to this city's food store |
| Trade Contract | Trading Hall | Every 2 industry supplies 1 gold |

For each project, carry only its small integer conversion remainder between
rounds; switching does not duplicate or transfer the remainder. For example,
Ponder's remainder is 0–3 industry. Resolve each city's contribution once per
round through the authoritative production/economy boundary. If Ponder has no
research target, show it as paused; do not silently waste or stockpile science.
Paused building/unit progress remains preserved under the existing rules.

These are the same kind of differentiated production outlet as Civ VI's Campus
Research Grants and Commercial Hub Investment. They create an alternative to
idle production or recruiting another unit. Their rates must be tested against
new construction and military investment; they are not meant to dominate them.

P1 adds **three projects and no new unit or wonder**. It changes no combat
strengths, movement, faction bonuses other than Scholar, victory thresholds or
technology prices. Those are separate causal candidates.

### P1 acceptance and rejection criteria

Keep the candidate only if opening investment choices remain credible across
terrain and factions, first expansion is a deliberate cost, and useful new
research/building decisions arrive while the player still cares about them.
Measure growth, first technology/settlement/contact, queue idle time, project
usage, meaningful alternatives, single-error recovery and later-age timing.
Reject a universal best opening or a repeatable that beats relevant buildings
in nearly every state. Include hostile and military-pressure playtests once
runtime integrity allows them; peaceful AI races alone cannot judge a Guard.

## P2 — specialization and Industrial victory together

This is the next coordinated prototype, not a distant dependency on perfect AI.

### Four city focuses

- A new city has **one focus slot**; population **5** unlocks a second.
- Maximum two slots in the first focus prototype. Add a third only when more
  genuinely distinct roles are introduced.
- Initial roles: **Knowledge (+1 science), Works (+1 industry), Stewardship
  (+1 food), Logistics (+1 gold)**.
- Choosing the first focus is free. Replacing a focus uses a **15-industry
  Reorganize project**; the old focus remains active until it completes.
- Universal food/basic city facilities and defenses remain available.
  Role buildings retain their data/progress when inactive, but their role
  effects work only while that focus is active. Changing focuses cannot be
  used to collect all permanent role bonuses without paying capacity costs.
- Knowledge hosts Library/Enchanting/Ponder/End knowledge; Works hosts advanced
  Create processing/assembly; Stewardship improves food/population development;
  Logistics hosts advanced freight and trade.
- Before confirmation, show the focus being replaced and the buildings/yields
  that would become inactive. This is a city-management choice, not mandatory
  district placement on the world map.

Finalize the complete building-to-focus mapping before implementing the
capacity validator. An item may allow either of two roles, such as a mixed
food/industry building. The mapping must not accidentally prohibit basic
defense or strand every city behind the same prerequisite.

### Replace three identical Industrial checklists

Keep the rail-network theme and three-city requirement, but require three
**different contributing cities**:

1. Works focus with an Assembly Workshop.
2. Knowledge focus with a Ponder Hall.
3. Logistics focus with a Freight Depot.

All three must be connected and operating. Require Economics. Prototype a
shared **1,200-industry Commission the Network project**, contributed by
connected qualified cities, followed by the existing **10-round hold**.
The pool size is a test parameter, not a claim that this equals the old route's
timing. Retain commissioning work when interrupted, pause it while eligibility
fails, and reset the final hold when the qualifying network breaks.

The current Industrial Complex remains a useful Works building; it stops being
the flag that must be copied in three cities. The current closures are 1,776
global science/2,670 aggregate industry for Industrial versus 1,744 science/728
local industry for End. Industry can run in parallel, so these are not turn
ratios. The replacement must be calibrated using actual city production,
research, investment and interruption opportunities.

Counterplay must be implementable: city capture already interrupts the network;
a later reviewed rail-pillage order can make raiding explicit. Do not advertise
a disruption action in the UI before the shared rules support it.

## P3 — units: refit existing investment and consolidate overlap

Proposed upgrade families, retaining current IDs for saves and legacy entities:

| Family | Upgrade path |
|---|---|
| Guard | Stone Guard → Iron Swordsman → Diamond Swordsman → Netherite Guard |
| Ranged | Bow Archer → Crossbow Guard → Expedition Company |
| Scout | Scout → Expedition Scout |
| Siege | Siege Contraption → Deployer Siege |
| Engineering | Engineer → Armored Engineer or Railway Engineer |
| Healing support | Potion Support → Supply Crew |

Initial refit price: **25 + 3 × max(0, new production cost − old production cost)
gold**, plus the target unit's normal strategic-material cost. Require target
research and owned territory. Preserve HP and XP; consume the remaining turn's
movement/attack allowance. No free healing, teleport, extra attack or XP reset.
Evaluate the price against buying a fresh unit and against treasury growth.

Stop listing Armored Engineer, Railway Engineer and Supply Crew as three extra
independent support purchases once these upgrade branches work. Keep their
definitions for existing units and refits. Engineering's early unlock currently
precedes its rail utility; the first content pass must either move recruitment
to the useful rail stage or give the early form an explicitly designed job.
Do not ship an early Engineer with no useful action.

Disband already exists, including a confirmation UI; keep it as the option to
remove a unit. Refits solve the different problem of preserving an old unit's
useful investment. This reduces duplicate choices without simply deleting
three unit definitions.
Keep mounted, naval, anti-mounted, golem and settler roles. Test quality-aware
army planning before imposing a hard global unit cap or changing the damage
curve. A separate optional formation design can follow refits; it is not a
prerequisite for this pass.

New review consideration: the [operational diagnosis](OPERATIONAL_SIEGE_REPORT.md)
confirms that negative treasury can automatically disband recent, full-health
siege units. Forecast post-refit/recruitment upkeep and make the consequence
visible. A different insolvency priority or bounded player-choice window is
a separate candidate to review; it is not included in the stated P1 values
or implemented by the research controller.

## P4 — targeted content and victory follow-up

| Current content | Proposed disposition |
|---|---|
| End Archive | Move its unlock from End Expedition to Astronomy, after the staging ground, so its research has time to matter; test this timing change before adding another effect |
| Eyes / Equipment / Dragon | Stage across Astronomy / Netherite / End Expedition rather than unlocking all three at the final technology; add a visible contest stage and calibrate its duration |
| Council election victory | Replace compulsory rival consent with a reviewed, contested diplomatic objective system; keep elections for meaningful Council powers |
| Enchanted Vault | Rework toward Knowledge/Ponder specialization; initial candidate +3 science and +50% Ponder output, local only |
| Grand Terminal | Rework toward freight/refit financing; initial candidate +3 industry/+3 gold, Trade Contract improves from 2:1 to 1:1 when connected to three cities |
| Great Oak Sanctuary / Beacon Pyramid / Great Clockwork / Prismarine Monument | Keep as controls in the first content pass; reconsider their opportunity costs once focuses and repeatables are playable |
| New wonders | Design after the existing six have clear jobs; no placeholder wonder additions in P1 |
| Horses / saltpeter | Resolve generation, access and unit-consumption mismatches before adding more resource-dependent units |

Diplomacy needs a separate concrete objective contract before implementation;
lowering a building cost cannot remove its current voluntary-support veto.
The End staging/Archive candidates interact, so test them separately and then
together. Preserve Minecraft/Create identity and existing content IDs throughout.

## Implementation and review boundary

Your healer request specifically authorizes H1, and P1 is now approved.
P2–P4 still require the design review requested in the original specification. Use a
dedicated prototype branch with separate commits/configurations for opening,
repeatables, focus/Industrial, refits and victory/wonder changes. Existing
campaigns must not silently adopt a different content economy: persist the
rules version, keep a baseline loader, and test content lookup consistency in
combat, UI, AI, costs, saves and the simulator before exposing new-game options.

Do not wait for every research question to be settled before prototyping an
approved package. Do require shared action validation, native/offline checks,
error-accounted simulations, and a real early/mid/late playtest of each package.
The outcome measure is better decisions and pacing, with competitive route
viability—not an attractive aggregate win-rate chart.

Supporting evidence: [review brief](REVIEW_BRIEF.md),
[opening recovery experiment](RECOVERY_OPENING_REPORT.md),
[faction matrix](BASELINE_MATRIX_REPORT.md),
[multiplayer slice](MULTIPLAYER_BASELINE_REPORT.md),
[military diagnostics](MILITARY_COMPETENCE_REPORT.md), and
[detailed implementation roadmap](IMPLEMENTATION_ROADMAP.md).

## P2 building mapping for review

All 39 existing definitions remain. Core still respects its current technology,
terrain and building prerequisites. Focus requirements are additional rules.
Either listed focus activates an “or” building. An inactive building retains
its construction/prerequisite presence but produces no effects and cannot
qualify as an active victory contribution. Train Stations remain core so a
city does not need a Logistics slot merely to join the rail network.

| Current building / project | ID | Proposed role |
|---|---|---|
| ENCHANTING ROOM | `academy` | Knowledge |
| ASSEMBLY WORKSHOP | `assembly` | Works |
| INDUSTRIAL COMPLEX | `bank` | Works |
| STOCK EXCHANGE | `bazaar` | Logistics |
| BELT LOGISTICS | `beltlogistics` | Works or Logistics |
| BREWING STAND | `brewery` | Core |
| BLAZE BURNER | `burner` | Works |
| COUNCIL HALL | `councilhall` | Core |
| MECHANICAL CRAFTER | `crafter` | Works |
| CRAFTING HALL | `craftinghall` | Core |
| CRUSHING WHEELS | `crusher` | Works |
| DEEP MINE | `deepmine` | Works |
| DEPLOYER WORKSHOP | `deployer` | Works |
| DRAGON EXPEDITION | `dragon` | Knowledge or Works |
| EXPEDITION EQUIPMENT | `equipment` | Knowledge or Works |
| EYES OF ENDER | `eyes` | Knowledge |
| WHEAT FARM | `farm` | Core |
| GOLEM FORTRESS | `fortress` | Core |
| FREIGHT DEPOT | `freight` | Logistics |
| FURNACE | `furnace` | Core |
| END ARCHIVE | `grandacademy` | Knowledge |
| BOOKSHELF LIBRARY | `library` | Knowledge |
| TRADING HALL | `market` | Core |
| QUARRY | `mine` | Works |
| HEATED MIXER | `mixer` | Works |
| END STAGING GROUND | `observatory` | Knowledge |
| ANIMAL PENS | `pens` | Stewardship |
| NETHER PORTAL | `portal` | Core |
| MECHANICAL PRESS | `press` | Works |
| REDSTONE WORKSHOP | `redstoneworkshop` | Knowledge or Works |
| DOCK | `shipyard` | Core |
| SMITHY | `smithy` | Works |
| TRAIN STATION | `station` | Core |
| STEAM PLANT | `steamplant` | Works |
| PONDER HALL | `university` | Knowledge |
| STONE WALLS | `walls` | Core |
| WATER WHEEL | `waterwheel` | Works |
| WINDMILL | `windmill` | Stewardship or Works |
| BELT WORKSHOP | `workshop` | Works |
