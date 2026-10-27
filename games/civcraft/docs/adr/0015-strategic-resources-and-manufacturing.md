# ADR-0015: Strategic resources and manufacturing

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D15; F13, F16
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has resource stocks and brass processing, but
horses/saltpeter have incomplete generation/use links. Gathering Storm uses
strategic-resource accumulation, unit requirements and ongoing consumption for
some advanced units. [Consumable resources](https://www.civilopedia.net/en-US/gathering-storm/concepts/consumeable_resources/)

## Decision

Use Minecraft-themed strategic resource accumulation, stockpile limits and selected ongoing consumption. Provide costly imports, village contracts and selected inferior substitutes to prevent hard exclusion by starting geography.

## Rationale and consequences

Stockpiles and selected consumption make geography and trade consequential. Imports, contracts and substitutes reduce hard map exclusion, but require prices that preserve scarcity without enabling free arbitrage.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the small current resource model, repair inconsistencies.** Plus:
  little new complexity. Minus: several resources may remain shallow gates.
- **B — Closely match resource stockpile/cap/consumption systems.** Plus: access
  and trade matter. Minus: more shortage states and map-dependent exclusion.
- **C — A few meaningful Minecraft inputs and outputs.** Plus: distinctive Create
  economy. Minus: recipes can become compulsory chores without alternative access.

## Dependencies and validation

Related decisions: [D03](0003-how-much-should-geography-determine-a-city-s-role.md), [D09](0009-building-families-and-operating-costs.md), [D16](0016-trade-roads-and-rail-logistics.md), [D17](0017-unit-roster-and-distinct-roles.md), [D19](0019-combining-units-into-formations.md), [D25](0025-faction-identity-and-balance.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
