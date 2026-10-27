# ADR-0004: Builders and tile improvements

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D04; F07, F10
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft's Farm and Quarry are city buildings, not a general
Builder improvement system. Engineers lay rails. Civ VI Builders spend charges
on improvements and can harvest resources/remove features. [Builder](https://www.civilopedia.net/en-US/gathering-storm/units/unit_builder/)

## Decision

Add charge-based Builder units for tile development. Support queued tasks and safe interruption on threats; select concrete charges, improvement catalog and harvest rules in the implementation specification.

## Rationale and consequences

Charged labor creates a production-versus-land-development choice. Queuing and safety behavior must offset the extra units and repair workload.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep city-level development.** Plus: few civilian pieces and clicks.
  Minus: less control over individual tiles and development timing.
- **B — Builders with improvement charges.** Plus: meaningful labor investment
  and tile choices. Minus: more units, routing and repeated orders.
- **C — City-funded tile works without Builder units.** Plus: land-use choices
  with fewer pieces. Minus: loses escort/logistics play; still needs tile UI.

## Dependencies and validation

Related decisions: [D01](0001-where-does-a-city-s-development-exist.md), [D03](0003-how-much-should-geography-determine-a-city-s-role.md), [D06](0006-does-a-settler-consume-population.md), [D12](0012-research-boosts-earned-through-actions.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
