# M4.1 resource lifecycle, machinery recipes and local stress

Status: **accepted implementation contract**. The owner accepted PR #153's
concrete coal, resource-cap, SU and fuel proposal on 2026-10-30. Numeric values
are implementation baselines, not calibrated balance results. Implementation
may proceed; balance experiments remain paused. Acceptance does not authorize
merging later PRs or deployment.

The owner's subsequent unreleased-game compatibility decision supersedes the
historical-profile requirements below: use one current ruleset, automatically
migrate/repair old saves where practical, and clearly require a user reset or
deletion when a save cannot be safely repaired. See
[ADR-0039](adr/0039-current-rules-and-save-migration.md). Save-schema versions
are migration markers, not parallel historical gameplay engines.

This record serves issue [#101](https://github.com/fpbcraft/cc-scripts/issues/101)
and follows the accepted direction in [ADR-0009](adr/0009-building-families-and-operating-costs.md),
[ADR-0015](adr/0015-strategic-resources-and-manufacturing.md),
[ADR-0038](adr/0038-power-fuel-and-environmental-consequences.md), and the
[M4 roadmap](ROADMAP-balance.md#m4--make-machinery-and-materials-operational-choices).
M3's [specialization contract](M3-SPECIALIZATION.md) remains the authority for
V5 family prerequisites, focus, legacy End access, and observation boundaries.

## Evidence and design boundary

At the specification base, `content.lua` defines iron, copper, zinc, redstone,
diamond, brass, horses, and saltpeter. `economy.lua` initializes and calculates
rates by iterating all of `Content.resources`, not just `resourceOrder`; owned
horses deposits therefore add one horse to `player.stockpile` per round without
a technology gate. `resourceOrder` drives HUD/deal choices and AI material
iteration, not extraction; exchange validates `Content.resources` directly and
explicitly rejects horses and saltpeter. The rate function allows any owned
deposit whose resource has a record, with a technology gate only when that
record defines one.
The worldgen resource list places horses but not saltpeter. No current unit has a
horse or saltpeter cost, although the generic unit resource-cost path supports
any resource ID. The stockpile has no cap. `exchange` permits records other
than horses/saltpeter after Currency, a material technology when defined, and
market/friendly-village access. Current unit content requires iron, diamond,
brass, and redstone. Each configured unit resource costs exactly two stockpile
units when the unit completes; `horseman` has no horse cost.

`worldgen.lua` places horses, iron, copper, zinc, redstone, and diamond;
saltpeter is not in the generated deposit table. `world.yields` gives several
deposits worked-tile yield bonuses. Territory-owned deposits, not a machine,
currently drive recurring extraction. `systems.strategic` returns the full
`Economy.rates` result, including horse rate; it is not a horse/saltpeter unit
cost. Unit completion checks and debits exactly two of `u.resource` when set.
`world.lua` exposes resources only for visible tiles and remembers explored
observations. Preserve that visibility model. `systems.production` is the one
round-resolution path; M4 should extend it in a bounded city/resource pass, not
create a per-tick simulation. Save state is versioned (`state.version = 6`), and
M3 has its own specialty schema/validation. `ai_materials.lua` uses the same
observed stockpile/rate view and currently has no machinery-order action.

Horses are a **live generated stockpile** today, but have no current unit cost,
exchange access, or listed M4 machinery consumer. Saltpeter is a resource
record, but has no generated source, exchange access, or current unit consumer.
Preserve both IDs and their current meanings; do not silently remove horse
accumulation or introduce either as a new unit cost. M4 proposes explicit caps
and visible rates for both compatibility records. Coal is a proposed new
identifier because a finite fuel input needs a real, visible supply. It must be
added deliberately to world generation, resource ordering, extraction,
projections, exchanges, AI, saves, and tests rather than being treated as
already present. The actual Steam Power technology ID is `steampower`.

## Proposed resource catalog and lifecycle

The following values are a small implementation baseline, not a balance result.
All quantities are integer units per city/empire per round as specified. Apply
the cap separately after each extraction, exchange, or recipe-output stage;
discarded overflow is previewed and reported.
No resource can go below zero. M4 does not add depletion, transport, storage
buildings, or hidden deposits.

| Resource | Current generation/reveal | Cap proposal | Current cost/use; M4 proposal | Bounded access before M5 |
|---|---|---:|---|---|
| Iron | Existing owned deposit: +1/round after Bronze; visible/remembered tile as today | 10 | Existing unit costs unchanged; optional machine inputs below | Current paid exchange; owned deposit |
| Copper | Existing owned deposit: +1/round after Deep Mining | 10 | Mixer recipe input: 1 per batch | Current paid exchange; owned deposit |
| Zinc | Existing owned deposit: +1/round after Deep Mining | 10 | Mixer recipe input: 1 per batch | Current paid exchange; owned deposit |
| Redstone | Existing owned deposit: +1/round after Redstone | 10 | Existing two-redstone unit debit unchanged; no new recipe | Current paid exchange; owned deposit |
| Diamond | Existing owned deposit: +1/round after Deep Mining | 6 | Existing unit requirements unchanged | Current paid exchange; owned deposit |
| Brass | No deposit; current effective Mixer consumes 1 copper + 1 zinc and adds 2 brass/round after Brassworking | 10 | Existing two-brass unit debit unchanged; M4 makes conversion selected | Existing paid exchange after Brassworking and market/village access |
| Horses (compatibility) | Existing worldgen deposit: +1/round on owned tile, no tech gate | 10 | No current unit consumer; do not add one in M4 | No exchange; existing diplomacy trades remain |
| Saltpeter (compatibility) | No current worldgen source; old saved value may exist | 10 | No current unit consumer; do not add one in M4 | No exchange; existing diplomacy trades remain |
| Coal (new) | Proposed generated deposit, +1/round after `steampower`; placement biome and density remain an owner choice; reveal follows current visible/remembered deposit observation | 10 | Steam Plant burns 1/round when active | Paid exchange after Currency and `steampower`; owned deposit |

The M4 profile should append `horses`, `saltpeter`, and `coal` to
`resourceOrder` so existing HUD and diplomacy selectors can show their stock
and choices. Keep horses/saltpeter excluded from AI exchange requests and from
`exchange`; their diplomacy trades only transfer a party's existing stock.
These compatibility records are not new unit costs or machine recipes.

Each owned eligible deposit supplies one unit per round independent of worker
assignment, matching the present extraction rule. A deposit contributes only
once to its owner's rate, even if overlapping city territories resolve to the
same owner; iterate unique world tile keys. Research is a generation gate, not
a retroactive grant: newly researched resources begin on the next production
resolution. Apply the cap immediately after each inflow stage: extraction,
exchange, and recipe output. For each stage, add only available room and report
the discarded overflow. Before reserving recipe inputs, require room for the
recipe's full output; if there is not room, pause it as `output_cap` without
debiting inputs. Legacy saves already above a proposed cap retain their exact
stock; they receive no additional inflow until below cap. Migration never clamps
or deletes historical stock.

Production order is: calculate territory/deposit rates; add extraction up to
cap; snapshot stocks; reserve each eligible machine's inputs and output room
from that snapshot, ordered by priority, city ID, then building ID; resolve
reserved operations in that same order. Inputs cannot be reserved twice, and no
machine output can fund another machine until next round. The snapshot allows
same-round extraction to fund an operation, matching the present mixer pass,
without letting city-array ordering create or deny inputs. Record extraction
and recipe overflow separately.

Exchange remains a paid, discrete action with existing market/village, tech,
embargo, and gold validation. Proposed M4 changes: add coal to supported
resource records; reject exchange at cap; no resource may be exchanged out for
gold in M4. Existing accepted diplomacy trades can also transfer resources;
validate both parties' stock and gold, including recipient room under the cap,
before atomically applying either side. Reject the entire deal if a recipient
would exceed cap. Trades transfer stock and cannot mint it, so they remain a
bounded pre-M5 access path without circular production arbitrage.
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
| Waterwheel | Generator capacity +4; retain current +2 industry | None | 0 | Generator resolves first |
| Windmill | Generator capacity +3; retain current +2 food and +2 industry | None | 0 | Generator resolves first |
| Steam Plant | Generator capacity +8 and current +6 industry while its generator is needed | 1 coal only when non-Steam capacity cannot run an otherwise eligible operation | 0 | Generator resolves before machine priorities |
| Deep Mine | Current +2 industry | None | 2 | 2 |
| Mechanical Press | Current +3 industry | None | 2 | 1 |
| Heated Mixer | Select `brass` (1 copper + 1 zinc -> 2 brass) or `industry` (current +2 industry) | Brass recipe only; requires Brassworking | 3 | 3 |
| Deployer Workshop | Current +3 industry | None | 2 | 2 |
| Assembly Workshop | Current +4 industry and +2 science | None | 4 | 1 |
| Mechanical Crafter | Current +5 industry | None | 4 | 1 |
| Crusher | Current +3 industry | None | 2 | 1 |
| Belt Logistics | Current +2 industry | None | 1 | 1 |
| Workshop | Current +1 industry; retain as unpowered Works basic | None | 0 | Always available |
| Burner | Current +1 industry | None | 1 | 2 |
| Redstone Workshop | Current +2 science; retain as unpowered Knowledge basic | None | 0 | Always available |

Only the Mixer introduces a selected material recipe in M4. The Press,
Deployer, Assembly Workshop, and Mechanical Crafter use their existing
`content.lua` effects when powered; they do not create unusable intermediate
tokens or consume inputs without an existing gameplay use. Their distinct
industry/science outputs are their bounded roles until a later reviewed
milestone defines a real consuming recipe. Existing unit material costs stay
unchanged. The only recurring inputs in this proposal are Mixer copper/zinc and
Steam Plant coal.

The historical mixer behavior becomes a selected operation: an effective mixer
does not convert automatically. The player selects `brass` or `industry`. Do
not add free brass by preserving both the old passive conversion and the
selected recipe. Existing outputs shown in the table are each building's total
operating effects, not additional effects stacked on top of old passive yields.
City base yields; Library, Market, Furnace, Portal, Housing, Well, Walls,
Fortress, Workshop, Redstone Workshop, and retained End projects continue to
work without SU. Other listed machines need an enabled operation and sufficient
local capacity.

Generator capacity is the sum of completed, effective generators, with a
fuel-consuming Steam Plant contributing only when a powered operation is
otherwise eligible but cannot fit under non-Steam capacity. It reserves one
coal for that round, adds +8 capacity, and grants its current +6 industry only
while active. If no eligible operation needs the extra capacity, it pauses as
`no_demand` and preserves coal. A generator itself uses no SU; resolve
generation/fuel before machine operations.
Active machine impacts are considered in priority order (lower number first),
then city ID and building ID. An operation starts only if its whole impact fits
remaining capacity, all required inputs are reserved, and its full output fits
the relevant stock cap. Otherwise it pauses with one stable reason
(`no_capacity`, `missing_input`, `missing_fuel`, `inactive_family`, `disabled`,
`no_recipe`, `output_cap`, or `no_demand`). Higher-priority feasible machines
may run while a later one pauses. No partial recipes, fractional SU, or automatic priority shuffling.

Proposed recovery: each round recompute available capacity and inputs from
authoritative state; resume a paused machine automatically if its existing
priority now fits. Explicit player priority/recipe selection persists. No
repeated action is needed to recover. If a selected recipe becomes unavailable,
keep the selection and report its pause reason; do not silently choose a
different recipe. A shortage never deletes a machine or its settings. M4 recipes
resolve atomically; they have no partial progress.

## Retained M3 building roles and End bridge

M3's V5 family mapping and prerequisite edges remain unchanged. M4 changes only
operating effects and adds selected resource/power conditions. Apply these
accepted caps and machine rules to the single current ruleset when the combined
M4 implementation/native gate passes. Historical profile IDs are migration
inputs, not selectable or executable old rule engines. Do not activate an
incomplete machinery implementation. `farm` and `mine` remain retired in Builder
profiles; `councilhall` remains retired; the End
sequence remains `observatory -> eyes -> equipment -> dragon` with the M3
temporary bridge and existing costs/tech gates. None of these End projects
requires a Works site, SU, fuel, or a recipe. The End chain is progressable from
the unpowered basics even with zero deposits.

| Retained role | IDs | M4 behavior proposal |
|---|---|---|
| Unpowered survival/development basics | `craftinghall`, `pens`, `housing`, `well`, `shipyard`, `furnace`, `smithy`, `library`, `walls`, `market`, `fortress`, `portal`, `brewery` | Preserve current basic effects/utility; no SU or recurring material demand |
| Works support and generators | `workshop`, `waterwheel`, `windmill`, `press`, `crusher`, `beltlogistics`, `deepmine` | Apply operation/capacity table above; no new forced multi-building chain |
| Powered production chain | `burner`, `mixer`, `deployer`, `assembly`, `crafter`, `steamplant` | Existing yields require local SU; Steam Plant is a 0-impact generator that runs only for eligible unmet demand and consumes coal |
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

Names here are the accepted contract, not already implemented APIs. Introduce
`resourceSchema = 1` and `machinerySchema = 1` at campaign state level, with
explicit migration. Build on the current M3 mechanics and migrate historical
profile IDs to the one supported current ruleset. A format/schema identifier
may change to drive migration, but must not retain old gameplay branches.
Validate the full migrated candidate before replacing a save. Unsupported or
malformed saves need a clear reset/delete instruction rather than silent
delete, resource grants, or a partially loaded campaign. Suggested state:

```lua
state.resourceSchema = 1
state.machinerySchema = 1
player.stockpile = { iron = 0, copper = 0, zinc = 0, redstone = 0,
                     diamond = 0, brass = 0, horses = 0, saltpeter = 0,
                     coal = 0 }
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
resource/recipe IDs, duplicate/cross-city machine ownership, negative or
non-integer stocks, malformed priority, and machine records without an effective
building. Preserve nonnegative legacy stock above cap; it blocks further inflow
until below cap. Migration never clamps or deletes historical stock. Never
repair invalid state by granting resource/output.

Proposed actions: `selectMachineRecipe { city, building, recipe }`,
`setMachinePriority { city, building, priority }`, and
`setMachineEnabled { city, building, enabled }`. Use stable numeric city ID and
building ID; never accept a client city table. Each request validates actor,
phase, ownership, research, effective family/building, recipe, and input schema
before mutation. Rejections leave resources, orders, RNG, progress, events, and
snapshots unchanged. Preview is read-only and recomputed by the host at action
time. A single turn resolution reserves input atomically, applies all debits and
outputs according to staged caps above, then emits one deterministic operation result per
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

1. Deterministic generated coal and all existing generated deposits (including
   horses; saltpeter remains ungenerated); reveal, last-seen memory, ownership
   transfer, overlapping territory and extraction counted once; no hidden deposit
   in owner/opponent projections.
2. Each cap at zero, one below cap, and cap; extraction, exchange, diplomacy
   transfer, recipe input, output-cap pause, overflow and legacy over-cap stock
   are conserved and ordered as specified.
3. Mixer absent/inactive/unpowered, no recipe, each single missing input, both
   inputs, cap reached, available exchange, embargo, and non-market exchange.
4. SU capacity exact fit, one below, generator add/remove/capture, fuel exhaustion
   and recovery, priorities/ties, disabled operation, and no rail torque.
5. Zero deposits and no fuel: city base, Library, Market, Furnace, Portal,
   housing/well and End chain remain usable; basics do not become stranded.
6. Resource and machine schema migration from legacy/P1/V5 saves, save/restart,
   preservation of over-cap stock, two-unit existing unit debits, horseman with
   no horse debit, unknown identifiers, malformed stocks, and validation
   rollback without resource duplication or data loss.
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

## Acceptance and remaining generation detail

The owner accepted the concrete stock caps, SU values, machine priorities and
demand-driven Steam Plant coal rule as implementation baselines, not calibrated
values. Coal is accepted as a new resource. The table deliberately leaves its
biome eligibility and map density unspecified; settle that bounded generation
detail before implementing placement rather than inventing an accepted value.
Other independent M4 implementation tasks can proceed. Historical gameplay
compatibility requirements are superseded by ADR-0039; migration validation,
privacy, conservation, useful unpowered basics and the End bridge still apply.
