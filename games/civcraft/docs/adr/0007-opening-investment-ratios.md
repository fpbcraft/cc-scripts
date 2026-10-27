# ADR-0007: Opening investment ratios

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D07; F09, F15
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

Current CivCraft Scout/Guard/first Settler cost 5/13/12
industry against one ordinary center science. Civ VI's early investments create
competing build commitments; its raw prices are not suitable targets for CivCraft.

## Decision

Retain approved P1 as the opening-calibration starting point. Adjust the eventual redesign opening jointly with Settler population consumption, Builders, capacity and the longer campaign; P1 values are not permanent constants.

## Rationale and consequences

P1 coordinates science and build commitment rather than copying raw Civ VI prices. New population, Builder and capacity mechanics invalidate assuming its original ratios are final.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep current ratios.** Plus: quick expansion. Minus: production can
  exhaust choices before useful research arrives.
- **B — Closely reproduce Civ VI relative timings.** Plus: a recognizable
  reference. Minus: different maps, growth rules and campaign length undermine copying.
- **C — The approved P1 calibration.** Plus: coordinated production/science
  changes with fewer new mechanics. Minus: its numerical balance remains unproven.

## Dependencies and validation

Related decisions: [D05](0005-growth-constraints-food-housing-and-amenities.md), [D06](0006-does-a-settler-consume-population.md), [D08](0008-what-does-a-developed-city-produce-indefinitely.md), [D11](0011-one-research-stream-or-science-plus-civics.md), [D13](0013-research-tree-breadth-and-unlock-spacing.md), [D33](0033-campaign-length-and-game-speed-scaling.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
