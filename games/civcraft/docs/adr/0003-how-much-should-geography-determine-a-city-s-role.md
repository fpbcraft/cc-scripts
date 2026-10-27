# ADR-0003: How much should geography determine a city's role?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D03; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft terrain affects worked yields, movement, resources
and some prerequisites. Most buildings add flat yields. Civ VI district adjacency
adds location-specific returns, such as Campus terrain bonuses. [Source](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/)

## Decision

Use a limited set of clear local terrain/resource bonuses with previews. Avoid a full adjacency exception matrix.

## Rationale and consequences

A few geographic bonuses make settlement roles legible without a large adjacency matrix. Cap extreme combinations and provide useful roles on poor terrain.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep mostly flat building effects.** Plus: predictable choices and fewer
  bad starts. Minus: cities can remain interchangeable.
- **B — Detailed district adjacency.** Plus: strong placement puzzles. Minus:
  more exceptions, map dependence and preview requirements.
- **C — A few local terrain/resource bonuses.** Plus: distinct cities with simple
  explanations. Minus: less precise placement play; needs caps to avoid jackpots.

## Dependencies and validation

Related decisions: [D01](0001-where-does-a-city-s-development-exist.md), [D02](0002-what-prevents-every-city-building-everything.md), [D04](0004-builders-and-tile-improvements.md), [D15](0015-strategic-resources-and-manufacturing.md), [D25](0025-faction-identity-and-balance.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
