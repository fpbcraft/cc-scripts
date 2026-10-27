# ADR-0006: Does a Settler consume population?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D06; F09
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft Settlers cost production and become more expensive
as more are trained, but do not consume population. A Civ VI Settler normally
removes one population on completion. [Settler](https://www.civilopedia.net/en-US/gathering-storm/units/unit_settler/)

## Decision

Completing a Settler consumes one population. Recalibrate its production cost and the growth economy together; do not assume the higher P1 price remains optimal after this added cost.

## Rationale and consequences

Expansion now trades a citizen as well as production for future cities. Combining that cost with expensive P1 Settlers and capacity can over-penalize growth unless prices are recalibrated.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep no population cost.** Plus: simpler expansion and recovery. Minus:
  expansion needs sufficient competing production/protection costs.
- **B — Consume one population.** Plus: directly trades present growth for
  expansion. Minus: food and growth tuning become more sensitive.
- **C — Temporary growth/labor commitment.** Plus: meaningful cost without losing
  a citizen. Minus: another temporary state and a less familiar rule.

## Dependencies and validation

Related decisions: [D04](0004-builders-and-tile-improvements.md), [D05](0005-growth-constraints-food-housing-and-amenities.md), [D07](0007-opening-investment-ratios.md), [D25](0025-faction-identity-and-balance.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
