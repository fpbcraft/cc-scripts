# CivCraft balance implementation roadmap

Date: 2026-10-27. Mode: implementation. Current position: **M1 delivered; M2 next**. This document plans the accepted [38 ADRs](adr/README.md); it
does not mark the redesign implemented. All 16 follow-up answers were A.

## Product and delivery target

Deliver a compact Minecraft/Create strategy game where opening investments
compete, cities develop distinct roles, armies remain useful, and rivals can
contest Conquest or End Expedition. Standard has a prototype 250-round deadline;
180–230-round competitive wins are an initial hypothesis. Score resolves the
deadline. Industrial and Diplomatic victories are removed in the new ruleset.

The primary players use ComputerCraft, including multiplayer. Preserve readable
monitor UI, bounded native turn costs and clear action consequences. More
content is useful only when it creates a meaningful choice.

Each milestone ends in a playable campaign version with its UI, AI and tests.
Do not wait for perfect agents or exhaustive simulations before human play.
Execution was authorized by the subsequent user request to pause balance
experiments, follow this roadmap and its ADRs, and commit frequently with stacked
PRs as useful. The original planning-only boundary is superseded by that request.
The prior explicit P1 implementation approval remains valid independently.

## Existing implementation and evidence

Current sources already include `content_rules.lua`, `civilian_projects.lua` and
campaign selection for P1. Recent Git history includes P1 forecast/help fixes and
adapted-opening simulation studies. M0 must verify their current behavior and
read their results; this plan neither repeats their work nor assumes all gates
passed. Earlier H1 healing is superseded for the new design by ADR-0023/F06.
Earlier P2/P3/P4 proposals are historical inputs; these ADRs govern the new plan.

No gameplay code is changed by writing these records. Retain unrelated staged
work and concurrent research files. Do not rewrite historical benchmark results.

## Technical approach

| Layer | Choice | Implementation boundary |
|---|---|---|
| Authoritative rules | Existing Lua engine and action validation | Reuse `systems.lua`, `actions.lua`, economy, combat and lifecycle modules; extract domain modules when needed. |
| Content | Data-driven Minecraft definitions | Keep stable IDs, explicit prerequisites and versioned costs/effects. |
| Campaign state | Versioned deterministic tables | Save/load, snapshots, replay and multiplayer consume the same semantics. |
| Interface | Existing ComputerCraft monitor UI | Add concise previews, inspectors, orders and event explanations. |
| AI | Existing strategic/tactical modules | New actions require legal-action support, valuation and operational behavior. |
| Simulation | Actual shared Lua rules in existing harness | Reuse verified native/LuaJIT acceleration where available; verify parity after rule changes. |
| Analysis | Existing Python research tooling | Seeded paired studies, manifests, confidence intervals, held-out maps and profiles. |
| Runtime validation | Native CraftOS-PC and real rednet checks | Offline tests do not substitute for rendering, input, network or restart evidence. |

No web backend, database, cloud service or new runtime is required. Rust/runtime
feasibility research is separate from these accepted gameplay decisions.

## State and action evolution

Names below describe proposed fields/actions, not already implemented APIs.
Specify exact schemas at the start of each milestone and migrate explicitly.

| Domain | State additions | Actions / commands | First milestone |
|---|---|---|---|
| Campaign | ruleset version, enabled victories, speed/deadline | create/select ruleset | M1 |
| Growth | settlement capacity sources and growth curve | city infrastructure selection | M2 |
| Tile works | improvement kind, owner, damage, Builder charges | improve, queue work, repair | M2 |
| Specialization | specialty sites, focus allowance, redevelopment state | place/redevelop site | M3 |
| Materials | stockpile caps, recurring demand, recipe outputs | select recipe, acquire substitute | M4 |
| Kinetics | local SU capacity/impact, active-machine priorities | activate/reorder machines | M4 |
| Trade | route capacity, endpoints, progress, safety/interruption | assign/resume route | M5 |
| Organization | milestone unlocks, doctrines, switch boundaries | choose/switch doctrine | M6 |
| Research | experiment completion, bounded overflow | select research, resolve boost | M6 |
| Army | upgrade family, formation, grouped support, shortage deadline | upgrade, merge, group, detach, retire | M7 |
| Warfare | pillage damage, repairs, occupation and defeated actors | raid, repair, capture/resolve defeat | M8 |
| End race | stage state, public milestones, interruption/recovery | complete stage, contest/recover | M9 |
| Factions/wonders | signature effects and distinct placement/effect definitions | existing build/selection actions | M10 |

Every action must validate ownership, phase, visibility, prerequisites, cost and
target. Update save migration, public/private projections, replay, help and
simulation adapters whenever its state changes. Keep hidden opponent plans out
of normal policy observations.

## Build order

| Milestone | Playable outcome | Depends on | Main ADRs |
|---|---|---|---|
| M0 | Verified current P1 baseline and reproducible measurements | Existing checkout | 7–8, 33 |
| M1 | New campaign scope, revised healing and pacing settings | M0 | 23, 26–29, 33–34 |
| M2 | Deliberate expansion and Builder development | M1 | 4–7 |
| M3 | Distinct cities with placed specialty sites | M2 | 1–3, 8–9 |
| M4 | Resource-driven industry and local SU operations | M3 | 9, 15, 38 |
| M5 | Automated trade, roads and resource access | M4 | 15–16, 30 |
| M6 | Better-spaced research, boosts and doctrine choices | M3; integrate M5 benefits | 11–14, 24 |
| M7 | Compact persistent armies and manageable budgets | M4–M6 | 17–20, 24 |
| M8 | Readable threats, limited raids and resolved conquest | M3, M5, M7 | 21–22, 31–32, 34 |
| M9 | Staged, contestable End Expedition | M6, M8 | 26, 28, 33 |
| M10 | Distinct factions and differentiated wonders | M3–M9 | 10, 25 |
| M11 | Calibrated full campaigns and native release evidence | M0–M10 | All, including 35–37 scope exclusions |

Milestones are ordered delivery slices, not calendar estimates. Split any slice
that cannot stay playable or cannot be validated within a short implementation
cycle. A dependency does not justify postponing all testing until the end.

## M0 — Verify the current baseline

Goal: start from the actual P1 implementation and trustworthy comparison runs.

- [x] Read current Git changes and latest P1 study manifests; preserve unrelated work.
- [x] Verify campaign-selected baseline/P1 costs, Farm help, project remainders,
  read-only forecasts, save/load and original-campaign compatibility.
- [x] Capture source fingerprints, map seeds, policies, enabled hostiles, victory
  flags and speed for a small reproducible baseline suite.
- [x] Reproduce or inspect the known hostile captured-Settler failure and fix its
  actor/spawner lifecycle before using hostile-enabled runs as balance evidence.
- [ ] Capture native opening observations: first build/research choices, city
  expansion, menu starvation, civilian projects, turn time and order load.

Done when: current ruleset tests and selected native cases have explicit results;
remaining correctness/performance failures are identified without being labeled
balance findings. No historical no-hostile result is relabeled hostile-enabled.

M0 correctness record: [verified baseline and capture repair](M0-BASELINE.md).
58 Lua scripts, 34 Python checks, two focused native rule tests, 21 native/save
parity comparisons and the native host/AI session pass. Broader native expansion,
menu-load and latency observations remain open. New balance experiments are
paused by the user's execution instruction; continue with playable mechanics.

## M1 — Establish the new campaign scope

Goal: a versioned playable campaign reflects the chosen victories and healing.

- [x] Add a new ruleset/content version without changing old save semantics.
- [x] Disable Industrial and Diplomatic victory evaluation in that version;
  update setup, objectives, AI goals, scoreboards, reports and encyclopedia.
- [x] Keep villages, treaties and useful Council gameplay; remove victory-only
  requirements/rewards without deleting unrelated diplomatic features.
- [x] Set the prototype Standard deadline to 250 and label speed presets clearly.
- [x] Specify and implement territory-dependent passive healing abroad and healer
  enhancement. Cover rest/action conditions, caps and support stacking.
- [x] Update UI forecasts, healer tactics, rule manifests and replay fixtures.

Done when: no removed victory can terminate a new campaign, old campaigns retain
their configured behavior, and native healing observations match the chosen new
rules. End remains reachable through its existing path until M9 replaces staging.

M1 delivery record: [Redesign V1 campaign scope and recovery](M1-CAMPAIGN-SCOPE.md).
New campaigns use the versioned scope; Original/P1 are retained. Native rule,
UI, save/reload and published-installer checks pass. Full campaign balance
calibration remains deferred while mechanics implementation continues.

## M2 — Make expansion and land development compete

Goal: population, production and Builder work create distinct opening investments.

- [ ] Define Settlement Capacity sources and a visible growth slowdown curve;
  retain food consumption and avoid an independent amenities meter.
- [ ] Implement population-consuming Settlers with minimum-population validation;
  prevent invalid completions and specify growth/production ordering.
- [ ] Add Builder charges and a small initial improvement catalog. Audit existing
  Farm/Quarry city bonuses to prevent duplicate yields from the new tile model.
- [ ] Implement queued work, safe interruption, capture and route invalidation.
- [ ] Show before/after tile yields, charges and capacity effects before spending.
- [ ] Adapt settlement and worker AI; compare candidate Settler prices/growth
  jointly against P1 using matched seeds and explicit Builder investment.

Done when: a human can choose a competitive development or expansion opening;
AI uses Builders, and population/charge/yield invariants survive save/load.
P1 Settler costs are a comparison baseline, not a mandated final result.

## M3 — Make cities specialize

Goal: location and specialty investments give cities different useful roles.

- [ ] Define a small specialty-site catalog and placement rules. One site uses
  one focus slot; basics, defenses and ordinary improvements use none.
- [ ] Define the modest population-based allowance and redevelopment cost;
  avoid a second independent slot system or accidental loss after Settler completion.
- [ ] Add simple terrain/resource bonuses, range rules and full placement previews.
- [ ] Audit existing building prerequisites into compact role-based chains;
  maintain useful civilian projects rather than starving specialized city menus.
- [ ] Add AI site placement and city-role selection, map symbols and inspectors.
- [ ] Retain a viable legacy End path during the transition, using temporary
  prerequisite mapping where necessary until the new M9 objectives exist.

Done when: two cities in one campaign make different defensible investments,
the player understands why, and redevelopment/save/load cannot duplicate sites
or permanently strand a victory prerequisite.

## M4 — Make machinery and materials operational choices

Goal: industrial cities choose useful processing under local SU constraints.

- [ ] Specify Minecraft strategic resources, generation, accumulation, caps and
  selected recurring demand; repair incomplete world-generation/use links.
- [ ] Define a small recipe graph with alternative acquisition points, avoiding
  compulsory long chains for every city or faction.
- [ ] Add local generator capacity and machine impact measured in SU; separate
  generator fuel from capacity and never bank SU as a consumable resource.
- [ ] Implement persistent machine priorities and automatic pausing of lower
  priorities, while retaining basic unpowered city functions.
- [ ] Show demand/capacity, input forecasts and pause reasons; add AI activation
  and recipe valuation. Avoid per-turn reactivation orders.

Done when: power/input shortages are predictable, prioritization changes output
without bookkeeping exploits, and alternative access exists even before full
Trader functionality. Rail links cannot transfer mechanical torque.

## M5 — Connect specialized cities

Goal: actual Traders carry out deliberate route choices with little routine work.

- [ ] Define route capacity, domestic/international yields, road creation,
  repetition, duration and transport rules. Specify material transfer separately
  from generated route income to prevent duplicated stockpiles.
- [ ] Add autonomous Trader movement and threatened-route stop/resume behavior;
  integrate road and advanced railway benefits into existing movement budgets.
- [ ] Implement costly imports, village contracts and selected inferior resource
  substitutes. Protect against contract farming and circular free arbitrage.
- [ ] Add route previews, failure notices, income forecasts and safe AI routing.
- [ ] Preserve useful existing treaties and integrate embargo/war behavior.

Done when: the player can sustain interdependent cities and resource-poor starts
through paid alternatives; route interruption and recovery are observable and
resource-conserving in native play and replay.

## M6 — Give research and organization distinct choices

Goal: research unlocks arrive at useful intervals and doctrines support pivots.

- [ ] Rewrite the six-Age prerequisite/unlock table around M2–M5 roles, including
  essential nonmilitary alternatives and travel/production payback windows.
- [ ] Add a small set of action-earned experiments; specify one-time credit,
  retrospective triggering and completion ordering to prevent repeated boosts.
- [ ] Implement retained progress with bounded overflow and explicit category/
  modifier rules. Compare alternate build sequences to detect output duplication.
- [ ] Define broad doctrine milestones, active choices and switching boundaries;
  include upkeep options without adding a new civic yield or governors.
- [ ] Add research/doctrine previews and AI planning for objectives and experiments.

Done when: alternative early/mid paths each provide useful actions before their
next unlock, doctrines are understandable, and switching/boosts conserve output.

## M7 — Preserve armies and control their workload

Goal: veterans modernize and combine; support and budgets remain manageable.

- [ ] Publish the compact family/upgrade table: land counters, navy and support;
  consolidate overlapping definitions instead of adding a type for every era.
- [ ] Implement upgrades with material/gold/location/action conditions and XP
  preservation; display post-upgrade recurring affordability.
- [ ] Add one formation tier with explicit compatible members, strength, XP,
  upkeep and irreversible/undo semantics; test merge versus separate utility.
- [ ] Extend grouping to military/civilian/support movement with clear selection,
  targeting, detach, civilian capture and stacked-display behavior.
- [ ] Add forecast warnings, bounded retirement choice and deterministic unpaid
  fallback; prevent permanent free credit or repeated warning reset exploits.
- [ ] Adapt recruitment, upgrade, group movement and retirement AI so armies
  actually reach useful fronts instead of merely looking affordable.

Done when: a native veteran survives modernization, grouped support moves and
targets correctly, and insolvency consequences are predictable across save/load
and multiplayer. Measure map pieces and orders, not just number of unit types.

## M8 — Make disruption and conquest legible

Goal: players can anticipate threats and contest investments without full conquest.

- [ ] Revisit provisional ADR-0021 using the new roster and economy; specify
  wall counters and compact siege roles before changing combat parameters.
- [ ] Implement pillage/repair for sites, routes and strategic improvements;
  ordinary food improvements remain protected. Define occupier and repair costs.
- [ ] Implement spawner alert levels and clear raid warnings with reaction time.
- [ ] Add simple occupation/recovery and explicit defeat transitions; audit
  remaining units, diplomacy, routes, turns and winner resolution after capture.
- [ ] Preserve war-component scheduling; test disputed tile races and grouped
  actions for ordering and fairness in real multiplayer.
- [ ] Adapt tactical AI to approach reachable targets, sustain siege, raid useful
  links and repair; separate controller failure from impossible rules.

Done when: native scenarios demonstrate siege, limited disruption, recovery and
defeat without orphan actors or stalled turns. Any material new combat direction
is recorded through ADR-0021's resolution rather than assumed from its provisional status.

## M9 — Stage the End race

Goal: a public, contestable End Expedition rewards preparation and recovery.

- [ ] Define a short stage graph with distinct research, production and resource
  commitments; replace temporary legacy prerequisite mappings from M3.
- [ ] Define information revealed at each stage and meaningful interruption;
  specify protected progress, recovery and whether final progress can regress.
- [ ] Tune the contest window against actual frontier travel and repair times.
- [ ] Update objective UI, announcements, AI pursuit/response and victory replay.
- [ ] Test rivals with different strategies and initial deficits; do not require
  consent, a unique wonder or one unavoidable geography roll for completion.

Done when: a rival has a costly, executable response to a visible lead, while a
defended leader can finish. A countdown alone does not establish counterplay.

## M10 — Differentiate content and factions

Goal: factions and wonders change plans without determining the winner at setup.

- [ ] Produce the proposed 12–16-wonder table: role, placement, unlock, price,
  alternative, contest value and failure/refund behavior. Cut redundant entries.
- [ ] Give each faction a signature mechanic and a modest fallback compatible
  with the new economy; show useful choices and unsupported-map behavior.
- [ ] Audit all retained units/buildings/techs: keep, rework, merge or remove,
  citing the role and era window. This is the full content pass, not just costs.
- [ ] Adapt AI valuation for faction tools and wonder opportunity costs.
- [ ] Run small paired faction/map studies and human openings before broad tuning.

Done when: factions differ in decisions, every wonder has a viable alternative,
and content has a stated use rather than existing solely to lengthen a checklist.

## M11 — Balance and release verification

Goal: demonstrated pacing, competitive agency and native runtime usability.

- [ ] Freeze candidate rules fingerprints and split maps/seeds into tuning,
  validation and held-out sets. Keep factions and seats counterbalanced.
- [ ] Run staged workloads: deterministic mechanics fixtures; small paired
  ablations; mixed-goal multiplayer matrices; then larger adaptive-policy studies.
- [ ] Update policies to the new rules before comparing routes; include multiple
  competent strategy families, opponent mixtures and map/resource conditions.
- [ ] Use adversarial/evolutionary or learned agents where they improve coverage;
  require full-game holdouts and legal observation boundaries before deployment.
- [ ] Report victory success per pursuer, faction/map-conditioned results,
  uncertainty and draws. Report Score/timeouts separately; avoid equating winner
  counts with fairness when different numbers pursue each route.
- [ ] Compare early choices, city menu alternatives, expansion timing, upgrade
  life, wonder payback, unit/order counts, lead recovery and human minutes per era.
- [ ] Profile AI time, frame/render latency, memory/GC and network/snapshot volume
  on native early/mid/late campaigns, including pan/zoom/drag and dense maps.
- [ ] Verify installer/manifests, migrations, restart/resume, actual rednet races
  and player/observer projections. Publish exact checks and remaining limits.

Done when: active routes have demonstrated agency in held-out mixed opponents,
major faction/map weaknesses are explained or corrected, and native user flows
pass declared runtime budgets. Set numeric budgets from M0 measurements and the
actual target hardware; do not invent throughput or universal fairness guarantees.

## Per-milestone completion record

For each milestone update this document with date, source revision, ruleset,
changed files, selected content parameters, automated results, native evidence,
simulation manifests and known limitations. Keep incomplete boxes unchecked.
Use targeted commits containing only that milestone when execution is requested;
publication and deployment follow the user's authorization for that execution.

## Deferred scope

Great People (ADR-0035), governors (ADR-0036), espionage (ADR-0037), Magic/religion,
culture/tourism victory, Diplomatic victory and Industrial victory remain future
scope. No initial aircraft layer, detailed adjacency matrix, separate amenities
economy, full civic tree, global climate simulation, RPM or shaft wiring. Future
expansions can revisit these through new or superseding ADRs; they are not an
automatic bundle with diplomacy.
