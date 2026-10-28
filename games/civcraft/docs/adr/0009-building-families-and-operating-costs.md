# ADR-0009: Building families and operating costs

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D09; F02, F13, F14
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has thematic prerequisite chains and many additive
yield buildings, including Create processing. Civ VI groups buildings into
district families and uses maintenance and, in Gathering Storm, power for some
advanced effects. [Buildings](https://www.civilopedia.net/en-US/gathering-storm/buildings/), [power](https://www.civilopedia.net/en-US/gathering-storm/concepts/power/)

## Decision

Use compact Minecraft building chains with distinct operating roles and selected recipe/SU requirements. Keep the chain short rather than copying every Civ VI tier. Final names, branches and values require a content table.

## Rationale and consequences

Role-based machines create operating decisions instead of a universal additive shopping list. Resource inputs and SU can create deadlocks if chains lack alternatives or essential basics require unavailable power.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the current additive chains.** Plus: transparent progression. Minus:
  can remain a compulsory shopping list.
- **B — Closely align district tiers, maintenance and power.** Plus: richer
  trade-offs. Minus: several operating budgets and prerequisites.
- **C — Short role-based chains with selected operating requirements.** Plus:
  each machine has a job. Minus: content must be audited to avoid filler links.

## Dependencies and validation

Related decisions: [D02](0002-what-prevents-every-city-building-everything.md), [D08](0008-what-does-a-developed-city-produce-indefinitely.md), [D15](0015-strategic-resources-and-manufacturing.md), [D16](0016-trade-roads-and-rail-logistics.md), [D24](0024-unit-upkeep-and-insolvency.md), [D27](0027-industrial-victory-and-city-specialization.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
