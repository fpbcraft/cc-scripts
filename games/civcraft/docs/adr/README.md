# CivCraft design decision records

All 38 initial decisions and all 16 follow-up answers are recorded here. D20 B
was supplied separately. Follow-up A means the concrete first option in that
question; it does not mean Keep from the original questionnaire.

These records capture accepted design intent, not implementation completion.
ADR-0021 deliberately remains provisional. Quantities described as prototype
values or ranges remain tunable. No further unresolved direct conflict was found;
specific mechanics still need detailed specifications and tests.

Authority: the final Decision section includes later follow-ups and supersedes
conflicting earlier alternatives or research proposals. Keep prior reasoning;
record subsequent changes through explicit supersession rather than silently
rewriting the user's choice. Existing campaign versions retain their semantics.

[Implementation roadmap](../ROADMAP-balance.md) ·
[Raw answers](../../research/lab/design_decision_answers.json)

## Core decisions

| Record | Topic | Status |
|---|---|---|
| ADR-0001 / D01 | [Where does a city's development exist?](0001-where-does-a-city-s-development-exist.md) | Accepted direction |
| ADR-0002 / D02 | [What prevents every city building everything?](0002-what-prevents-every-city-building-everything.md) | Accepted direction |
| ADR-0003 / D03 | [How much should geography determine a city's role?](0003-how-much-should-geography-determine-a-city-s-role.md) | Accepted direction |
| ADR-0004 / D04 | [Builders and tile improvements](0004-builders-and-tile-improvements.md) | Accepted direction |
| ADR-0005 / D05 | [Growth constraints: food, housing and amenities](0005-growth-constraints-food-housing-and-amenities.md) | Accepted direction |
| ADR-0006 / D06 | [Does a Settler consume population?](0006-does-a-settler-consume-population.md) | Accepted direction |
| ADR-0007 / D07 | [Opening investment ratios](0007-opening-investment-ratios.md) | Accepted direction |
| ADR-0008 / D08 | [What does a developed city produce indefinitely?](0008-what-does-a-developed-city-produce-indefinitely.md) | Accepted direction |
| ADR-0009 / D09 | [Building families and operating costs](0009-building-families-and-operating-costs.md) | Accepted direction |
| ADR-0010 / D10 | [Wonders: general bonuses or strategic commitments?](0010-wonders-general-bonuses-or-strategic-commitments.md) | Accepted direction |
| ADR-0011 / D11 | [One research stream or science plus civics?](0011-one-research-stream-or-science-plus-civics.md) | Accepted direction |
| ADR-0012 / D12 | [Research boosts earned through actions](0012-research-boosts-earned-through-actions.md) | Accepted direction |
| ADR-0013 / D13 | [Research-tree breadth and unlock spacing](0013-research-tree-breadth-and-unlock-spacing.md) | Accepted direction |
| ADR-0014 / D14 | [Switching investments and completion overflow](0014-switching-investments-and-completion-overflow.md) | Accepted direction |
| ADR-0015 / D15 | [Strategic resources and manufacturing](0015-strategic-resources-and-manufacturing.md) | Accepted direction |
| ADR-0016 / D16 | [Trade, roads and rail logistics](0016-trade-roads-and-rail-logistics.md) | Accepted direction |
| ADR-0017 / D17 | [Unit roster and distinct roles](0017-unit-roster-and-distinct-roles.md) | Accepted direction |
| ADR-0018 / D18 | [Upgrading an existing unit](0018-upgrading-an-existing-unit.md) | Accepted direction |
| ADR-0019 / D19 | [Combining units into formations](0019-combining-units-into-formations.md) | Accepted direction |
| ADR-0020 / D20 | [Stacking and support-unit handling](0020-stacking-and-support-unit-handling.md) | Accepted direction |
| ADR-0021 / D21 | [Combat, walls and siege](0021-combat-walls-and-siege.md) | Provisional |
| ADR-0022 / D22 | [Raiding an economy without capturing its city](0022-raiding-an-economy-without-capturing-its-city.md) | Accepted direction |
| ADR-0023 / D23 | [Healing away from home](0023-healing-away-from-home.md) | Accepted direction |
| ADR-0024 / D24 | [Unit upkeep and insolvency](0024-unit-upkeep-and-insolvency.md) | Accepted direction |
| ADR-0025 / D25 | [Faction identity and balance](0025-faction-identity-and-balance.md) | Accepted direction |
| ADR-0026 / D26 | [Which kinds of victory belong in CivCraft?](0026-which-kinds-of-victory-belong-in-civcraft.md) | Accepted direction |
| ADR-0027 / D27 | [Industrial victory and city specialization](0027-industrial-victory-and-city-specialization.md) | Accepted direction |
| ADR-0028 / D28 | [End Expedition: preparation versus final checklist](0028-end-expedition-preparation-versus-final-checklist.md) | Accepted direction |
| ADR-0029 / D29 | [Does diplomatic victory require a rival's consent?](0029-does-diplomatic-victory-require-a-rival-s-consent.md) | Accepted direction |
| ADR-0030 / D30 | [Villages, trade diplomacy and global institutions](0030-villages-trade-diplomacy-and-global-institutions.md) | Accepted direction |
| ADR-0031 / D31 | [Wilderness threats and warning windows](0031-wilderness-threats-and-warning-windows.md) | Accepted direction |
| ADR-0032 / D32 | [Capture, occupation and defeat](0032-capture-occupation-and-defeat.md) | Accepted direction |
| ADR-0033 / D33 | [Campaign length and game-speed scaling](0033-campaign-length-and-game-speed-scaling.md) | Accepted direction |
| ADR-0034 / D34 | [Simultaneous peaceful turns and wartime ordering](0034-simultaneous-peaceful-turns-and-wartime-ordering.md) | Accepted direction |
| ADR-0035 / D35 | [Great People and secondary project rewards](0035-great-people-and-secondary-project-rewards.md) | Accepted direction |
| ADR-0036 / D36 | [Governors and persistent city administrators](0036-governors-and-persistent-city-administrators.md) | Accepted direction |
| ADR-0037 / D37 | [Espionage](0037-espionage.md) | Accepted direction |
| ADR-0038 / D38 | [Power, fuel and environmental consequences](0038-power-fuel-and-environmental-consequences.md) | Accepted direction |

## Follow-up coverage

| Follow-up | Topic | Answer | Incorporated into |
|---|---|---|---|
| F01 | Growth: capacity or housing and amenities? | A | ADR-0005 |
| F02 | Building chains: closer Civ VI structure or compact roles? | A | ADR-0009 |
| F03 | Civics: independent progress or milestone doctrines? | A | ADR-0011, ADR-0013 |
| F04 | Bankruptcy: how close should we copy Civ VI? | A | ADR-0011, ADR-0024 |
| F05 | Industrial victory: retain or remove? | A | ADR-0026, ADR-0027, ADR-0028 |
| F06 | Healing: confirm the change from your earlier rule | A | ADR-0023 |
| F07 | Builders and Traders without excessive orders | A | ADR-0004, ADR-0016, ADR-0020 |
| F08 | Focus slots and placed sites: use one limit | A | ADR-0001, ADR-0002 |
| F09 | Settler population cost versus P1 prices | A | ADR-0006, ADR-0007, ADR-0018 |
| F10 | Builder improvements versus limited raiding | A | ADR-0004, ADR-0022 |
| F11 | Unit roster: define the middle ground | A | ADR-0017, ADR-0018, ADR-0019 |
| F12 | Wonder roster: between a few and a Civ-sized ecosystem | A | ADR-0010 |
| F13 | SU: where is mechanical capacity shared? | A | ADR-0009, ADR-0015, ADR-0038 |
| F14 | SU overload and machine operating choices | A | ADR-0009, ADR-0038 |
| F15 | 250 turns: deadline or intended finish? | A | ADR-0007, ADR-0013, ADR-0028, ADR-0033 |
| F16 | Resource scarcity and viable strategies | A | ADR-0015, ADR-0016, ADR-0025, ADR-0030 |

## Cross-cutting implementation requirements

- Use the actual shared Lua rules for simulation and gameplay; do not create a
  divergent balance model. A runtime rewrite is a separate architecture decision.
- Version new campaign semantics, save formats, snapshots and policy artifacts.
- Pair every new player action with UI, AI behavior and native validation.
- Measure conditional success per active victory pursuer, faction and matchup;
  report Score/timeouts separately. Exact equality on every map and opponent mix
  is not promised.
- Distinguish accepted direction, a concrete implementation specification,
  completed code, automated tests and observed native gameplay evidence.
