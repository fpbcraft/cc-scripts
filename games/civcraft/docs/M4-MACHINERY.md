# M4.1 resource lifecycle, machinery recipes and local stress

Status: **implementation contract proposal; pending owner review**. This is a
specification only. The table's numeric baselines are concrete proposals for a
playable implementation, not accepted balance values, calibrated values, or
claims about current behavior. M4 balance studies remain paused. This contract
does not authorize implementation of M4.2 or calibration before review.

This record serves issue [#101](https://github.com/fpbcraft/cc-scripts/issues/101)
and follows the accepted direction in [ADR-0009](adr/0009-building-families-and-operating-costs.md),
[ADR-0015](adr/0015-strategic-resources-and-manufacturing.md),
[ADR-0038](adr/0038-power-fuel-and-environmental-consequences.md), and the
[M4 roadmap](ROADMAP-balance.md#m4--make-machinery-and-materials-operational-choices).
M3's [specialization contract](M3-SPECIALIZATION.md) remains the authority for
V5 family prerequisites, focus, legacy End access, and observation boundaries.

## Evidence and design boundary

At the specification base, `content.lua` defines iron, copper, zinc, redstone,
diamond, brass, horses, and saltpeter, but only the first six appear in
`resourceOrder`. `economy.lua` accumulates owned deposits for records in that
order and gates them by technology; it consumes one copper and one zinc per
eligible city with an effective mixer and Brassworking, producing two brass per
round. Rates are applied to `player.stockpile` in `systems.production`. The
stockpile has no cap. `exchange` permits ordered resources after Currency and a
market/friendly village; horses and saltpeter are explicitly rejected. Current
unit requirements include iron, diamond, and brass, not horses or saltpeter.

`worldgen.lua` places deposits (including horses, iron, copper, zinc, redstone,
and diamond); `world.yields` gives several deposits worked-tile yield bonuses.
Territory-owned deposits, not a machine, currently drive recurring extraction.
`world.lua` exposes resources only for visible tiles and remembers explored
observations. Preserve that visibility model. `systems.production` is the one
round-resolution path; M4 should extend it in a bounded city/resource pass, not
create a per-tick simulation. Save state is versioned (`state.version = 6`), and
M3 has its own specialty schema/validation. `ai_materials.lua` uses the same
observed stockpile/rate view and currently has no machinery-order action.

Horses and saltpeter are therefore **tile-yield/legacy resource identifiers** in
this base, not live strategic stockpiles. They are not included in M4 stockpile
generation or recipe inputs. Retain their terrain modifiers and old-save
resource identifiers; do not silently turn them into consumed unit resources.
The M4 generated stockpile set is the six `resourceOrder` entries. Coal is
proposed below as a new identifier because a finite fuel input needs a real,
visible supply. It must be added deliberately to world generation, resource
ordering, extraction, projections, exchanges, AI, saves, and tests rather than
being treated as already present.

## Proposed resource catalog and lifecycle

The following values are a small implementation baseline, not a balance result.
All quantities are integer units per city/empire per round as specified. Cap
applies after extraction and production; overflow is discarded and previewed.
No resource can go below zero. M4 does not add depletion, transport, storage
buildings, or hidden deposits.

| Resource | Generation and reveal | Cap proposal | Cost/use proposal | Bounded access before M5 |
|---|---|---:|---|---|
| Iron | Existing owned deposit: +1/round after Bronze; visible/remembered tile as today | 10 | Existing unit costs unchanged; optional machine inputs below | Current paid exchange; owned deposit |
| Copper | Existing owned deposit: +1/round after Deep Mining | 10 | Mixer recipe input: 1 per batch | Current paid exchange; owned deposit |
| Zinc | Existing owned deposit: +1/round after Deep Mining | 10 | Mixer recipe input: 1 per batch | Current paid exchange; owned deposit |
| Redstone | Existing owned deposit: +1/round after Redstone | 10 | No new compulsory recipe | Current paid exchange; owned deposit |
| Diamond | Existing owned deposit: +1/round after Deep Mining | 6 | Existing unit requirements unchanged | Current paid exchange; owned deposit |
| Brass | Mixer recipe: 2 per completed batch after Brassworking | 10 | Existing unit requirements unchanged | Existing paid exchange remains available under the current material-tech/market rules |
| Coal (new) | Proposed coal deposit: +1/round after Steam Power; deposit can be revealed/extracted on a city-owned tile | 10 | Steam Plant burns 1/round when active | Paid exchange after Currency; coal deposit |

Each owned eligible deposit supplies one unit per round independent of worker
assignment, matching the present extraction rule. A deposit contributes only
once to its owner's rate, even if overlapping city territories resolve to the
same owner; iterate unique world tile keys. Research is a generation gate, not
a retroactive grant: newly researched resources begin on the next production
resolution. If a cap is reached, extraction is suppressed before recipes, so a
recipe can never consume phantom overflow. Production order is: calculate
territory/deposit rates; add extraction up to cap; snapshot stocks; reserve each
eligible machine's inputs from that snapshot ordered by priority, city ID, then
building ID; resolve reserved operations in that same order and cap outputs.
Inputs cannot be reserved twice, and no machine output can fund another machine until next round. The
snapshot allows same-round extraction to fund an operation, matching the
present mixer pass, without letting city-array ordering create or deny inputs.
Record extraction and recipe overflow separately.

Exchange remains a paid, discrete action with existing market/village, tech,
embargo, and gold validation. Proposed M4 changes: permit coal; cap stocks after
exchange and reject at cap; no resource may be exchanged out for gold in M4.
Retain the existing price formula and access through an owned market or a
discovered friendly village. The player can access each recipe input by deposit
or paid exchange. This is an access floor, not a guarantee of affordable imports
under insolvency or embargo. Machines never create exchange credits or consume
and re-import output in the same resolution.

## Proposed recipes, machines and local SU

Stress Units (SU) are capacity accounting only. SU is never stored, transferred,
spent as fuel, or included in stockpiles. Each city resolves its own machines;
rail links and stations grant no SU. No shafts, RPM, wire/pipe placement,
overstress destruction, climate effects, or per-tick machinery are modeled.
The small integer capacity/impact values below are abstract CivCraft points,
not Create's real SU measurements or a claim about mechanical throughput.

| Building / role | Proposed operation and output | Input/fuel | SU impact | Priority proposal |
|---|---|---|---:|---:|
| Waterwheel | Generator, capacity +4 | None; existing building/research rules | 0 | Always available |
| Windmill | Generator, capacity +3 | None; existing building/research rules | 0 | Always available |
| Steam Plant | Generator, capacity +8 | 1 coal each active round | 0 | 4 |
| Deep Mine | +2 industry while operation is active; no additional deposit extraction | None | 2 | 2 |
| Mechanical Press | Pressing: +1 iron OR +1 copper OR +1 zinc, selected recipe | 1 matching ore stock; does not create ore from nothing | 2 | 1 |
| Heated Mixer | Brass: 1 copper + 1 zinc -> 2 brass | As shown; requires Brassworking | 3 | 3 |
| Deployer Workshop | Components: 1 iron -> 1 brass substitute component token | 1 iron; token is not brass and cannot satisfy brass unit costs | 2 | 2 |
| Assembly Workshop | Assembly: 1 iron + 1 brass -> 1 assembled-part token | 1 each; token has no use until a later reviewed milestone | 4 | 1 |
| Mechanical Crafter | Crafting: 1 redstone + 1 iron -> 1 precision-part token | 1 each; token has no use until a later reviewed milestone | 4 | 1 |
| Crusher / Belt Logistics | Infrastructure effects only in M4; no material recipe | None | 1 each | 1 |
| Workshop / Burner / Redstone Workshop | Existing non-recipe role; retain utility described below | None | 0 (basics) | 0 (basics) |

The Deployer/Assembly/Crafter outputs above are proposed bounded intermediate
outputs for M4. They are not consumed by current content and must be persisted
and visible if implemented; their purpose is to make operations observable
without silently rewriting existing unit prices. If the owner prefers no orphan
intermediates before M7, leave those machines as power-gated industry effects
and defer those recipes; do not substitute brass or unlocks. This is a concrete
choice for review, not a design decision inferred from the ADRs.

The historical mixer behavior becomes a selected operation: an effective mixer
does not convert automatically. The player selects brass or a non-material
industry mode. Do not add free brass by preserving both the old passive
conversion and the recipe. Machine construction effects become the operation's
output, not an always-on additive yield on top of the recipe. Basic buildings
remain unpowered. In this proposal, city base yields; Library, Market, Furnace,
Portal, Housing, Well, Walls, Fortress, and retained End projects continue to
work without SU. Workshop is also unpowered basic industry. All other family
machines need an enabled operation and sufficient SU for their defined output.

Generator capacity is the sum of completed, effective generators, with a
fuel-consuming Steam Plant contributing only while fuel is reserved. A generator
itself uses no SU. Active machine impacts are considered in priority order
(lower number first), then stable machine ID and city ID tie-breaks. A machine
starts only if its whole impact fits remaining capacity and all required inputs
are reserved. Otherwise it pauses with exactly one stable reason (`no_capacity`,
`missing_input`, `missing_fuel`, `inactive_family`, `no_recipe`, or
`no_observed_deposit`). Higher-priority feasible machines may run while a later
one pauses. No partial recipes, fractional SU, or automatic priority shuffling.

Proposed recovery: each round recompute available capacity and inputs from
authoritative state; resume a paused machine automatically if its existing
priority now fits. Explicit player priority/recipe selection persists. No
repeated action is needed to recover. If a selected recipe becomes unavailable,
keep the selection and report its pause reason; do not silently choose a
different recipe. A shortage never deletes a machine or its progress. One-shot
recipes resolve atomically; these proposed recipes have no partial progress.

## Retained M3 building roles and End bridge

M3's V5 family mapping and prerequisite edges remain unchanged. M4 changes only
operating effects and adds selected resource/power conditions. `farm` and `mine`
remain retired in Builder profiles; `councilhall` remains retired; the End
sequence remains `observatory -> eyes -> equipment -> dragon` with the M3
temporary bridge and existing costs/tech gates. None of these End projects
requires a Works site, SU, fuel, or a recipe. The End chain is progressable from
the unpowered basics even with zero deposits.

| Retained role | IDs | M4 behavior proposal |
|---|---|---|
| Unpowered survival/development basics | `craftinghall`, `pens`, `housing`, `well`, `shipyard`, `furnace`, `smithy`, `library`, `walls`, `market`, `fortress`, `portal`, `brewery` | Preserve current basic effects/utility; no SU or recurring material demand |
| Works support and generators | `workshop`, `waterwheel`, `windmill`, `press`, `crusher`, `beltlogistics`, `deepmine` | Apply operation/capacity table above; no new forced multi-building chain |
| Powered production chain | `burner`, `mixer`, `deployer`, `assembly`, `crafter`, `steamplant` | Each has a distinct selected role/recipe; activity may pause by input or local SU |
| Knowledge | `academy`, `redstoneworkshop`, `university`, `grandacademy`, `observatory` | Preserve science/End role; `redstoneworkshop` remains unpowered and does not consume redstone merely to grant science |
| Freight | `bazaar`, `station`, `freight`, `bank` | Preserve M3 family and existing effects pending M5; station/rails grant no torque or SU |
| End bridge | `observatory`, `eyes`, `equipment`, `dragon` | Existing M3 temporary chain remains independent of operational machinery |

This table deliberately does not replace every existing building effect with a
machine recipe. The implementation must inventory the exact V5 effective
building query paths (including faction bonuses, mixer conversion, station/rail
bonus, and AI valuations) and ensure an inactive machine grants no operating
effect. Ordinary basics and the End bridge must remain functional when power,
fuel, or resources are absent.

## Proposed versioned state, actions and queries

Names here are a proposed contract, not existing APIs. Introduce
`resourceSchema = 1` and `machinerySchema = 1` at campaign state level, with
explicit migration. Keep the existing campaign/ruleset identity and M3 schema;
do not bump or reinterpret historical saves until the migration plan is
implemented. Suggested state:

```lua
state.resourceSchema = 1
state.machinerySchema = 1
player.stockpile = { iron = 0, copper = 0, zinc = 0, redstone = 0,
                     diamond = 0, brass = 0, coal = 0 }
city.machines = {
  mixer = { recipe = "brass", priority = 3, enabled = true },
  steamplant = { recipe = "generator", priority = 4, enabled = true },
}
city.machineStatus = {} -- derived; never serialized as authority
```

One record per building ID; ownership and effective building state remain
authoritative in the existing city/building system. Recipe and priority are
player-authored persisted choices; enabled defaults true for a newly constructed
machine. Defaults are created deterministically during migration/new city
initialization. Derived capacity, reservations, active/pause status, projected
rates, and pause reasons are recomputed and not serialized. Reject unknown
resource/recipe IDs, duplicate/cross-city machine ownership, non-integer stocks,
stocks outside 0..cap, malformed priority, and machine records without an
effective building. Never repair invalid state by granting resource/output.

Proposed actions: `selectMachineRecipe { city, building, recipe }`,
`setMachinePriority { city, building, priority }`, and
`setMachineEnabled { city, building, enabled }`. Use stable numeric city ID and
building ID; never accept a client city table. Each request validates actor,
phase, ownership, research, effective family/building, recipe, and input schema
before mutation. Rejections leave resources, orders, RNG, progress, events, and
snapshots unchanged. Preview is read-only and recomputed by the host at action
time. A single turn resolution reserves input atomically, applies all debits and
outputs, clamps cap overflow, then emits one deterministic operation result per
machine. A failed resolution applies nothing for that machine. Replay records
the action fields and resolved operation events; replay must not rerun policy
selection or reveal hidden deposits.

Pure queries: `resourceRates(view, player)`, `stockpile(view, player)`,
`machineCapacity(view, player, city)`, `machinePlan(view, player, city)`, and
`previewMachine(view, player, city, building, recipe)`. They return copied
values, stable IDs/order, cap/overflow/input/output/SU/pause reasons and visible
deposit requirements. The plan preview names which machines would operate and
which pause, without promising hidden enemy deposits or mutable-state references.
Owner projection includes own stockpiles, capacity, recipes, priorities,
selected/enabled state and operation/pause reasons. Opponent projection includes
only public completed buildings and visible/remembered deposits under existing
fog rules; it does not expose opponent stockpiles, recipe selections, priorities,
machine pause reasons, or next-turn plans. Existing global/public rate summaries
must not leak private rates.

## AI and presentation contract

AI uses only its owner observation and the same pure preview/action contract as a
human. It may choose a recipe or priority when a building is completed, a chosen
input becomes unavailable, or its material valuation changes enough to justify
a deliberate switch. It must not emit a machine action each turn merely to keep
operations running; automatic recovery is rules resolution. AI cannot inspect
unexplored deposits, rival stockpiles, rival machine settings, or hidden queues.
Use deterministic ties by priority, building ID, and recipe ID. After rejection,
recompute once from the updated observation and avoid retry loops.

City/empire views show current and next-resolution stock/cap, deposit rates,
selected input/output, fuel use, local SU capacity and planned impact, projected
output, cap overflow, and a concise pause reason. Preview distinguishes observed
fact from an assumed future extraction; no hidden resource guess is rendered as
certain. Keep compact terminal/monitor layouts readable and retain existing
city selection and M3 site/map symbols.

## Required correctness and native cases before implementation sign-off

1. Deterministic generated coal and all existing deposit types; reveal, last-seen
   memory, ownership transfer, contested/overlapping territory and extraction
   counted once; no hidden deposit in owner/opponent projections.
2. Each cap at zero, one below cap, and cap; extraction, exchange, recipe input,
   multiple outputs and overflow are conserved and ordered as specified.
3. Mixer absent/inactive/unpowered, no recipe, each single missing input, both
   inputs, cap reached, available exchange, embargo, and non-market exchange.
4. SU capacity exact fit, one below, generator add/remove/capture, fuel exhaustion
   and recovery, priorities/ties, disabled operation, and no rail torque.
5. Zero deposits and no fuel: city base, Library, Market, Furnace, Portal,
   housing/well and End chain remain usable; basics do not become stranded.
6. Resource and machine schema migration from legacy/P1/V5 saves, save/restart,
   unknown identifiers, malformed stocks, and validation rollback without
   resource duplication or data loss.
7. Accepted/rejected actions preserve full state/RNG/events as applicable;
   ordered replay and Lua 5.3/LuaJIT parity for rates, caps, recipes, snapshots,
   resolution, and final state.
8. AI receives private owner facts only, chooses a legal operation, respects
   cost/alternative access, and does not retry or spam actions.
9. Native CraftOS-PC host and hotseat: inspect preview, change recipe/priority,
   exhaust fuel/input, observe automatic pause/recovery, save/restart, and check
   compact terminal/monitor rendering. Physical Minecraft monitor/rednet remains
   separate evidence and must be recorded separately when performed.

These are correctness/runtime cases, not balance experiments. Do not run
tournaments, parameter sweeps, price tuning, comparative pacing studies, or
calibration until the user explicitly resumes those studies.

## Review choices left open

The ADRs fix the system shape but do not accept concrete table values, generator
fuel, intermediate outputs, or whether all retained machines become powered.
The tables above give an implementable baseline for owner review. In particular,
coal is a proposed new resource; coal generation/access and the orphan
intermediate outputs need explicit acceptance. Do not label the values accepted
or calibrated, and do not dispatch the dependent implementation issue until the
contract is reviewed.
