# ADR-0016: Trade, roads and rail logistics

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D16; F07, F16
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has commerce treaties, material exchange and
engineer-built rails with network benefits. It lacks Civ VI's general Trader-unit
route economy and automatic road creation through trading. [Trade](https://www.civilopedia.net/en-US/gathering-storm/concepts/trade_5/), [roads](https://www.civilopedia.net/en-US/gathering-storm/concepts/movement_2/)

## Decision

Add Trader units and route capacity, with autonomous repeating travel after a destination choice. Integrate roads and retain advanced Create railway logistics. Threatened routes must have explicit interruption, recovery and warning behavior.

## Rationale and consequences

Actual trade units create vulnerable connections and early roads. Autonomous repetition reduces routine orders; route safety, capture and restart behavior introduce pathfinding and state responsibilities.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep treaties/exchange/rails.** Plus: simple and strongly themed. Minus:
  early connections and economic interdependence are limited.
- **B — Trader units and route capacities.** Plus: active connections, roads and
  vulnerable commerce. Minus: more moving pieces and path management.
- **C — Abstract trade routes with visible links.** Plus: network choices without
  extra units. Minus: raiding and route visibility must be explicitly designed.

## Dependencies and validation

Related decisions: [D01](0001-where-does-a-city-s-development-exist.md), [D09](0009-building-families-and-operating-costs.md), [D15](0015-strategic-resources-and-manufacturing.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D24](0024-unit-upkeep-and-insolvency.md), [D27](0027-industrial-victory-and-city-specialization.md), [D30](0030-villages-trade-diplomacy-and-global-institutions.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
