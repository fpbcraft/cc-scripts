# ADR-0005: Growth constraints: food, housing and amenities

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D05; F01
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft uses food storage, food consumption, growth
thresholds and minimum growth time. It has no separate housing/amenity economy.
Civ VI uses both as additional growth/development constraints. [Housing](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_14/),
[happiness](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_16/)

## Decision

Add one Settlement Capacity affecting growth, alongside food. Do not add a separate amenities/happiness economy. Water, housing and selected services can increase capacity; exact curve and sources remain tunable.

## Rationale and consequences

One growth constraint is easier to communicate than separate housing and amenities. It loses independent happiness, luxury allocation and war-weariness choices; food and expansion still need joint tuning.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep food plus the existing growth rules.** Plus: easy to understand.
  Minus: fewer reasons to balance a large city against several smaller ones.
- **B — Separate housing and amenities.** Plus: distinct expansion and growth
  pressures. Minus: several new meters and supporting content.
- **C — One simple development capacity.** Plus: growth has an infrastructure
  cost with one meter. Minus: combines two different economic functions.

## Dependencies and validation

Related decisions: [D02](0002-what-prevents-every-city-building-everything.md), [D06](0006-does-a-settler-consume-population.md), [D25](0025-faction-identity-and-balance.md), [D32](0032-capture-occupation-and-defeat.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
