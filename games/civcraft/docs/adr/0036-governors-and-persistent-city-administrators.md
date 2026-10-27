# ADR-0036: Governors and persistent city administrators

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D36; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has no governor progression. Civ VI governors
provide assignable city specialization with promotion choices. [Governors](https://www.civilopedia.net/en-US/gathering-storm/concepts/governors_1/)

## Decision

Defer governors and administrator progression for this version. Specialization comes from sites, geography and development rather than another assignable promotion layer.

## Rationale and consequences

Deferral avoids duplicating site specialization and doctrines with another assignment/promotion layer. City identity must be delivered by the accepted geography and infrastructure systems.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep governors absent.** Plus: fewer overlapping specialization systems.
  Minus: less ability to move a development advantage between cities.
- **B — Governor trees and establishment delays.** Plus: distinctive city plans.
  Minus: another promotion/assignment system.
- **C — One simple specialist appointment per empire.** Plus: a movable emphasis.
  Minus: can still duplicate focus-slot decisions rather than add value.

## Dependencies and validation

Related decisions: [D02](0002-what-prevents-every-city-building-everything.md), [D05](0005-growth-constraints-food-housing-and-amenities.md), [D11](0011-one-research-stream-or-science-plus-civics.md), [D25](0025-faction-identity-and-balance.md), [D32](0032-capture-occupation-and-defeat.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
