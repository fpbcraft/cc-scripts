# M1 — Redesign V1 campaign scope and recovery

M1 implements ADR-0023, ADR-0026–0029 and the deadline portion of ADR-0033.
The new live-campaign default is **Redesign V1**, persisted as
`state.contentRules = "balance1"`. This is a playable intermediate version,
not completion of the full balance roadmap. Simulation/balance searches remain
paused; verification uses targeted rule, save, UI and native correctness checks.

## Version and campaign contract

| Campaign | Content field | Active races | Deadline fallback | Standard / Quick / Epic |
| --- | --- | --- | --- | --- |
| Original | absent | Existing configured routes | Existing Score/draw options | 180 / 120 / 270 |
| P1 | `p1` | Existing configured routes | Existing Score/draw options | 180 / 120 / 270 |
| Redesign V1 | `balance1` | Conquest, End Expedition | Mandatory Score | 250 / 167 / 375 |

Existing Legacy campaigns also keep their prior rules; they cannot silently
become Redesign V1 through a loaded legacy lobby. Missing old-save deadlines
retain their historical migration fallback. Existing explicit deadlines are
preserved. New preset deadlines use `ceil(250 × existing speed factor)`;
production/research/growth scaling and movement budgets keep their current rules.
The 180–230-round finish range in ADR-0033 is a later calibration hypothesis,
not a claim established by adding this deadline.

No save-container format change is needed: schema 6 already serializes the
campaign content field. Validation explicitly accepts `balance1`; player
contexts inherit it on migration, and observer snapshots publish it. Original
and P1 saves do not acquire the new profile implicitly. Later milestones must
version incompatible campaign semantics explicitly rather than reinterpreting
these published profiles.

Redesign V1 initially inherits P1's opening science, capital-only Scholar bonus,
unit costs, immediate Farm/Agriculture improvement, and Ponder/Tend/Trade project
contracts. M2 adds Settler population cost and Builder development with explicit prototype
parameters; P1 prices are a starting point rather than permanent constants.

## Victory and diplomacy behavior

Industrial and Diplomatic victory are hard-disabled in the rules query, even
when a stale or edited flag says otherwise. Old industrial counters or Council
victory records cannot terminate Redesign V1. Conquest and the existing
Eyes/Equipment/Dragon path still work; M9 will replace End staging. Score
resolves the deadline and shares victory on equal scores. It cannot be disabled
in this profile.

Campaign setup offers the supported routes, objectives show Conquest/End/Score,
and industrial progress reports are suppressed. Existing AI goals are reviewed
immediately if their route is unavailable; normal strategic selection and
research fallback choose among the campaign's remaining goals. Council member
records no longer mark diplomatic-victory eligibility in this profile.

Council formation, voting, leadership, resolutions, village delegates, pledges,
trade, embargoes and treaties remain. The victory-only Council Hall is unavailable
for new construction in Redesign V1 and described as retired in its Codex entry.
Stock Logistics, the Stock Exchange, railways, Industrial Complexes and their
ordinary economic benefits remain useful content. No Council Hall is required
to lead or participate in the Council.

## Recovery specification

These are explicit prototype values chosen within ADR-0023's tunable direction:

| Current territory | Base HP per resting boundary |
| --- | ---: |
| Owned | 20 |
| Foreign with active Open Borders | 15 |
| Neutral or other peaceful territory | 10 |
| Active enemy territory | 5 |

One living adjacent owned healer contributes **+10 HP**. Further healers do not
stack; a healer cannot support itself. A healer may reposition to support a
resting ally, but a recipient that moved, attacked or otherwise spent an action
cannot recover. Issuing Fortify/Heal after moving does not bypass that rule.
Health caps at 100. Unregistered wilderness actors and captured civilians do
not gain this new passive recovery.

All recovery amounts are computed before clearing action flags, so reversing
the unit array cannot make an acting recipient eligible. Original/P1 retain
their prior owned-territory passive healing and healer-aura behavior.

The inspector uses the same recovery query as the boundary, capped by missing
HP. Tactical rest valuation and healer support positioning use the new
eligibility. Forecasts use currently observed territory ownership even when its
claiming city is hidden. They describe current conditions: later movement,
territory changes or treaty expiry can alter recovery at the actual boundary.

## Validation and delivery

- M1 rule tests cover version selection, speed presets, mandatory Score, retired
  route hardening, End/Conquest positive controls and old route compatibility.
- Forty-eight recovery combinations cover territory, action use, support count
  and HP cap. Additional cases cover array-order independence, captives and
  observer forecasts with an unseen claiming city.
- Actual native save/load retains `balance1`, its deadline, project remainders
  and subsequent neutral-territory recovery.
- Campaign-panel paging exposes only the correct controls for all three profiles.
- Python contracts cover observers, restored P1 state, deadline resolution and
  a short exact Lua 5.3/LuaJIT checkpoint continuation.
- Native host/AI and hotseat/war input flows pass; the published implementation
  is also checked through the real GitHub installer, preserving old fixtures.

See [machine-readable validation](validation/m1-source-validation.json) for
source fingerprints, commands, profiles and exact result scope. Physical
Minecraft monitors, live rednet and sustained late-game performance remain
later validation work. These checks do not assert balance or campaign fun.

M2 is next: Settlement Capacity, population-consuming Settlers and charge-based
Builder development, with save/UI/AI handling in the same playable slice.
