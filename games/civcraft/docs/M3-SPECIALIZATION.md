# M3 specialization specification

Issue [#84](https://github.com/fpbcraft/cc-scripts/issues/84), parent #69.
Specification base: `f4ff4f9e2e6899e3d9916846ac45b05f94c230fc` (Founders #68).
This is the implementation contract for #85–#88, not implemented mechanics or
balance evidence. Prototype quantities below are deliberate implementation
choices under ADRs 0001–0003, 0008–0009; calibration remains paused. The roadmap
and ADR Decision sections remain authoritative.

## Campaign boundary

Introduce `balance5`, **Specialization V5**, inheriting Founders starting units,
map dimensions, growth, Builders, healing and victory scope. Extend each relevant
`content_rules.lua` capability explicitly; equality with `balance4` must not
silently drop Founders behavior. Store the profile on state and player records.
Missing/Original, P1 and balance1–balance4 retain their current building costs,
prerequisites, yields, project semantics and saved map dimensions. Never infer a
profile from the presence of sites and never upgrade old campaigns on load.

Add `specialtySchema=1` only to V5 state. An absent site collection in V5 means
empty; malformed or unsupported specialty schemas fail loading with a clear
error rather than discarding investments. Existing save-format migration and
slot backup behavior remain in place. New campaigns select V5 only when the
combined rules/UI/AI/native slice is ready; intermediate rules work is opt-in.

## Three sites, one allowance

A site is a single visible hex assigned to one city. It is not a unit, citizen
job, second city, resource extractor, or extra district-slot category. One
completed site or reserved new-site project uses one focus slot. One site of
each kind per city; at most three kinds. Basics, defenses, ordinary improvements,
wonders and buildings within a family use no additional focus slots.

`allowance = min(3, 1 + floor(max(0, population - 1) / 3))`: population 1–3
allows one site, 4–6 two, 7+ three. Allowance is derived, never banked. A city at
population four may train a Settler and retain both sites at population three.
All completed sites stay effective above the reduced allowance; reserve no new
slot until used falls below allowance. Existing valid construction may finish
after shrink. Redevelopment replaces an existing slot and is legal while over
allowance. Starvation and capture do not destroy sites or select an arbitrary
site to disable. There is no separate family-building allowance.

| Stable kind / visible name | Research | Standard industry | City output when complete | Local bonus, maximum one |
|---|---|---:|---|---|
| `works` / Create Works | engineering | 30 | +1 industry | +1 industry if its own hex is a hill OR any adjacent explored hex has a revealed iron/copper/zinc deposit |
| `knowledge` / Ponder Campus | writing | 30 | +1 science | +1 science if any adjacent explored hex is mountain OR its own hex has a revealed redstone/diamond deposit |
| `freight` / Freight Yard | currency | 30 | +1 gold | +1 gold if any adjacent explored hex is coast/ocean OR its own hex has a road or rail |

The OR conditions never stack. A poor location still earns the base output.
Bonuses use existing biome/elevation/resource/transport data, not invented river
or freshwater classes. Resource bonuses require the owner's existing reveal
technology. Only tiles currently visible or retained in the owner's explored
map can contribute; use the same observation query for owner forecasts and
authoritative yield evaluation. Discovering a qualifying neighbor can improve
output later; a hidden terrain/resource edit cannot become an information oracle.
The neighbor scan is exactly the six distance-one hexes. No city, wonder or
other specialty adjacency bonuses. M4 will replace selected machine effects with
local SU/recipes; V5 does not invent SU, fuel demand or new material consumption.
M5 will add actual Trader routes; Freight Yard itself creates none.

Each site requires an explored, currently owned workable land hex at distance
1–3 from its assigned city's center, with `territoryCity` resolving to that exact
city. Reject coast/ocean, mountains, city centers, natural/manmade landmarks,
wonders, existing improvements, another site or another city's reservation.
Use current authoritative territory, including explicit claims where present;
never assume population radius creates ownership. A hex need not have a citizen
working it. Site output goes to the city once, independently of worked tiles;
the underlying tile retains its ordinary worked yield. A site excludes Builder
improvements and wonder construction on that hex. It does not consume or erase
a deposit, road, rail or terrain feature. It does not block friendly movement.
Hostile occupancy is addressed below. No Builder charge constructs a site.

## Production, reservation and redevelopment

Site selection is ordinary city industry production, with game-speed scaling
through `CampaignRules.cost`. Reserve a slot and target atomically on accepting
`placeSite`; no output before completion. Switching away retains exact progress
and the reservation; cancel explicitly releases both and forfeits invested site
industry, with confirmation. A paused site's reservation counts against focus.
Prevent the same city kind or hex being reserved by any active/paused project.
Site project progress keys include the stable project ID, kind and coordinates;
existing `building:<id>` progress keys cannot alias them.

`redevelopSite` targets a completed site and a replacement kind/hex belonging to
the same city. It costs the replacement site's full scaled construction price
plus a scaled 15-industry redevelopment surcharge; no salvage or gold refund.
Moving the same kind pays the same cost. Reject an identical kind and hex and
reject another completed/reserved site of the destination kind. Redevelopment
uses the old slot, reserves both old and new hexes, and does not require spare
allowance. The old site and its family effects continue until atomic completion.
Then replace it, discard the old family's completed buildings and paused family
construction with no refund, and install the new site. Confirmation must list
all losses and costs. If only moving the same kind, retain that family's buildings
and progress. End exceptions below remain retained in both cases.

Canceling redevelopment forfeits its invested industry, releases the destination,
and retains the unchanged source site/family. No separate free demolition action
or conversion of progress between sites/buildings/units. Repeated switching,
canceling or save/reload cannot earn output, industry, refunds or spare slots.
No overflow change is introduced in M3; inherit existing construction behavior.

Before each production completion revalidate city ownership, slot identity,
research, destination terrain/claims and reservations. Temporary foreign hostile
occupancy pauses completion and site output, but does not delete progress or
investments; friendly/allied non-hostile units do not block it. A unit merely
passing through between resolutions does not steal the site. Existing combat
and movement rules stay unchanged. No new pillage or occupation timer in M3:
M8 owns damage/repair and broader city occupation.

If claims/terrain change, retain the site attached to its original city, counting
its slot, with an explicit inactive reason; never transfer it to a neighboring
city or silently delete it. Restore effects when legal again. Permit paid
redevelopment from an inactive site to legal owned land. An invalid pending
project pauses and can be canceled; never retarget it silently. City capture
transfers its site records, paused projects and reservations with the city ID.
All legality/research/output is recomputed for the new owner; unsupported
research disables relevant effects/construction without deleting them. Existing
capture clearing of the active production selection may remain, but must retain
its paused progress/reservation. Destroying/removing a city releases its sites
and reservations without yielding rewards to any actor.

## Exhaustive building-family mapping at the base revision

Stable building IDs remain, preserving historical saves. In V5 each ordinary
building stays stored in `city.buildings`; its site requirement controls new
construction and whether its effects operate. Sites do not copy these flags or
charge another focus slot. All costs, yields and technology gates stay at base
values unless explicitly changed here. Retained one-time End projects remain
building-backed completion flags until M9. The table covers all 41 base IDs.

| IDs | V5 family / prerequisites |
|---|---|
| `farm`, `mine` | Retired as in Landwork/Founders; no city yield, no new build. Tile fields/quarries remain Builder work. |
| `craftinghall`, `pens`, `housing`, `well`, `shipyard`, `furnace`, `smithy`, `library`, `walls`, `market`, `fortress`, `portal`, `brewery` | Basics, no site. Retain research/coastal requirements and current short dependencies (`smithy` needs `furnace`; `brewery` needs `portal`). |
| `councilhall` | Remains retired in redesign profiles; no Diplomatic victory reintroduction. |
| `deepmine` | Works; retains `furnace` prerequisite and deepmining research. |
| `workshop`, `waterwheel`, `windmill` | Works; each has no building prerequisite. |
| `press`, `crusher`, `beltlogistics` | Works; `press` has no building prerequisite; `crusher` and `beltlogistics` require `press`. |
| `burner`, `mixer`, `deployer`, `assembly`, `crafter`, `steamplant` | Works; `burner` needs `portal`; `mixer` needs `burner`; `deployer` needs `mixer`; `assembly` needs `deployer`; `crafter` and `steamplant` need `assembly`. |
| `academy`, `redstoneworkshop`, `university`, `grandacademy` | Knowledge; `academy` and `redstoneworkshop` have no building prerequisite, `university` needs `academy`, `grandacademy` needs `observatory`. |
| `bazaar`, `station`, `freight` | Freight; `bazaar` needs `market`, `station` has no building prerequisite, `freight` needs `station`. |
| `bank` | Freight; needs `freight` only. Removes the cross-family `steamplant`/`crafter` checklist. Industrial victory stays disabled. |
| `observatory`, `eyes`, `equipment`, `dragon` | Temporary unrestricted End family, no site; exact rules below. |

Only the listed prerequisite edges change in V5. This shortens compulsory chains
without deleting retained content ahead of M10's full role audit. M4 must give
retained machines distinct operating roles; this specification does not claim
all current additive effects are final design. Explicitly gate faction effects
(e.g. Forge's `workshop` bonus), brass conversion from `mixer`, rail-station
bonuses and AI dependency valuation through the same effective-building query.
An inactive/missing family must not continue supplying a hidden economy bonus.
Basics such as `library`, `market`, `portal` and `furnace` remain useful on maps
with poor specialty placement and keep civilian alternatives available.

### Legacy End bridge and civilian work

`observatory` keeps astronomy and `portal`, but removes `academy` from its V5
prerequisites. This avoids forcing both Knowledge and Works/Freight, or population
four, to pursue End. `eyes` still needs `observatory`; `equipment` needs `eyes`;
`dragon` needs `equipment`; all three retain enlightenment and existing costs.
`grandacademy` is an optional Knowledge upgrade, never an End prerequisite.
Capture/redevelopment/inactive sites never erase End completion flags or paused
End progress. Site output is unnecessary to make the chain legal. M9 explicitly
supersedes this temporary bridge; it is not the accepted final End design.

Ponder Research requires basic `library`, Tend Crops basic `housing`, Trade
Contract basic `market`. No specialty requirement. Retain separate modulo
remainders (4 industry/science, 2 industry/food, 2 industry/gold), selected
unfinished-research pause, exact paused construction and read-only previews.
Do not zero, pool or cash out remainders during redevelopment, capture or load.

## State and authoritative API contract

The names below are new proposed APIs, not claims of existing functions.
Implement a focused `specialty_sites.lua` domain module with content definitions
and pure queries, called by existing action/production/observation paths.

```lua
state.specialtySchema = 1
city.sites = { -- stable kind keys, one completed site per kind
  works = { id = 12, kind = "works", x = 5, y = 9 }
}
city.siteProjects = { -- retained independently of current production choice
  [13] = { id = 13, operation = "place", kind = "knowledge", x = 6, y = 9,
           progress = 7 },
  -- redevelopment additionally records sourceSiteId; source is not removed yet
}
state.nextSiteId = 14 -- monotonically increasing across both record types
city.project = { kind = "site", id = 13, progress = 7 }
```

`siteProjects[id].progress` is the single authoritative amount; active
`city.project.progress` is a synchronized compatibility projection, never a
second credit. Serializer/replay must preserve numeric IDs and monotonic next ID.
Reserve indexes and allowance/used/effect/reason values are derived and never
serialized as competing authority. Damage and machine priorities are future
schema extensions, not unused M3 fields. Save normalization must reject duplicate
IDs, kinds and hex claims; don't repair duplicates by granting output twice.

| Pure query | Required result |
|---|---|
| `allowance(state, city)` | allowed, used, reserved, overage; redevelopment source counted once |
| `canPlace(state, player, city, kind, x, y)` | legal boolean and stable reason, no mutation |
| `preview(view, player, city, request)` | exact scaled price/progress, focus before/after, base/bonus explanation, terrain/work opportunity, lost family flags/progress for redevelopment |
| `effectiveBuilding(state, city, id)` | retained flag plus family/site/owner-tech/occupancy validity; drives every economic special case |
| `effects(state, city)` | bounded site output once, deterministic reason list |
| `reservations(state)` | unique tile and city-kind ownership, stable iteration |

Expose `placeSite {city, kind, x, y}`, `redevelopSite {city, siteId, kind, x, y}`,
`resumeSite {city, projectId}`, and `cancelSite {city, projectId}` through
`actions.lua`; use normal city production selection to pause/switch. Validate
active actor, ownership, phase/war ordering, profile, visible target, research,
finite integer coordinates within map bounds, target eligibility and reservation atomically. Rejected
requests leave state, RNG, IDs, progress, queues, snapshots and events unchanged.
The host rechecks after preview; UI coordinates never authorize an action.
Requests identify the city by stable numeric city ID; never accept client-supplied
city tables. An already-reserved kind/hex or repeated cancellation is rejected
without allocating another ID, reservation or refund.
Completing a site emits one event containing city/site/kind/hex. Completing
redevelopment emits source and destination IDs; action logs and replay retain
all request fields. No RNG is needed. Replay applies ordinary validated actions.

Owned projections include sites, project progress, reservations, pause reasons,
focus and family availability. Visible opponents reveal completed site kind,
hex and publicly observable inactivity, never production, role plan, progress,
research, remainders or reservation destinations. Fog memory retains last-seen
public sites; losing vision must not expose later redevelopment/capture. Owner
queries and AI receive copied tables, never references to mutable host state.
Observer/replay views follow their existing privilege boundary. Proposals must
use normal player observations; no hidden-resource or enemy-queue shortcuts.

## UI, AI and integration delivery

#85 implements versioned rules, family effects, actions, reservations, completion,
save/projections/replay and correctness fixtures. #86 and #87 depend on that
contract; coordinate module ownership before either writes shared files. #88
integrates and validates the combined playable slice before default activation.

The city inspector shows `FOCUS used/allowance`, retained-overage explanation,
three site entries and family unlocks. Selecting a site previews legal owned
hexes with capped bonuses, full price, production turns and reservation state.
Confirmation names lost buildings/progress on redevelopment. Cancellation has a
loss confirmation. Active/paused sites expose resume/cancel; inactive sites show
reason and paid relocation. Site map symbols W/K/F and city associations remain
readable in compact terminals, monitors and zoomed maps without hiding units or
city-banner hit targets. City selection stays available. Codex/research help
explains site requirements and the temporary End bridge. Preview is read-only.

AI evaluates observed legal sites against food/industry/science/gold needs,
existing city investments, travel/front safety and current production alternatives.
A city-role preference is a valuation hint, not an extra slot lock. Compare
basic buildings, recurring projects and recruitment rather than always filling
focus. End planning uses the new bridge; basic `library` remains an independent
research option. Keep deterministic ties by kind order then y/x. Use the same
requests as humans; revalidate after rejection and avoid retry loops. Do not
redevelop every round: require the replacement's valuation to exceed lost
investment plus surcharge; preserve a chosen valid project unless its purpose
or legality changes. Deterministic fixtures demonstrate differing city choices;
no tournament or parameter search is authorized.

## Required invariants and evidence matrix

| Fixture / flow | Acceptance and evidence owner |
|---|---|
| Focus 1/3/4/6/7 population; Settler and starvation shrink | #85: exact allowance, overage retains output, no duplicate reservation, existing work can finish |
| Invalid ownership/fog/terrain/hex/research/phase; stale preview | #85: rejection is full-state/RNG/ID unchanged; no hidden information leak |
| Place/pause/switch/resume/cancel/redevelop/move | #85: single spend/output, unique target/kind, explicit losses, no shared-progress exploit |
| Capture, invalidated claim, occupied site, removed city | #85: deterministic transfer/inactivity/recovery and reservation cleanup; no orphan yield |
| All 41 building IDs and faction/economy exceptions | #85: table-driven family and dependency checks, no retired Farm/Quarry or retired victories resurfacing |
| End from one population / one slot, every chosen site role | #85: legal full bridge and positive victory control; no need to grow for another focus |
| Ponder/Tend/Trade with specialty pause/redevelopment | #85: unchanged separate remainders, selected-research pause and paused construction |
| Original/P1/balance1–4 saves and new V5 pending work | #85/#88: actual serializer restart/load, dimensions and previous semantics retained; stable IDs/progress |
| Owner/opponent/fog/observer snapshots and replay | #85/#88: copies, last-seen memory, private plans hidden, deterministic full state after replay |
| Two cities on contrasting known terrain | #87/#88: legal different investments, useful basics on poor terrain, deterministic AI requests and End bridge |
| Compact/wide renderer, mouse and terminal input | #86/#88: actual preview/confirm/cancel/redevelop, symbols and banners; no truncated costs/losses |
| Native host/AI, hotseat and Founders cityless rednet opening | #88: found capitals, construct/redevelop sites, capture, save/restart, normal/reversed competing target requests |
| Lua 5.3/LuaJIT shared-rule parity | #88: accepted/rejected ordered actions, effects, observations, lifecycle boundaries and final hashes |
| Published installer at exact immutable revision | #88: new modules packaged, real install/restart, old save fixtures preserved |

Record exact source revisions, commands, result files and limitations in #84–#88
and #67. Native CraftOS-PC is distinct from physical Minecraft monitor/rednet and
target-server latency. A documentation review proves no runtime or balance claim.
Physical hardware evidence, broader M0 latency, paused calibration and the open
Founders graphics-controls gate remain separately tracked. Do not close #69 or
mark M3 playable from this specification alone.
