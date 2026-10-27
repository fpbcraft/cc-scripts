# ADR-0027: Industrial victory and city specialization

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D27; F05
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft requires three connected cities with the same
Industrial Complex flag. Civ VI has no directly equivalent industrial victory;
its productive cities support multiple routes.

## Decision

Remove the separate Industrial victory for this version. Preserve industrial specialization and connected production as support for the remaining strategies. Reconsider a distinct operational-network victory only in a later design decision.

## Rationale and consequences

Removing an overlapping production checklist simplifies victory balance. Industry must still provide valuable choices and support Conquest and End instead of losing its strategic purpose.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep three matching developed factory cities.** Plus: clear objective.
  Minus: rewards identical building chains.
- **B — Remove the separate industrial win and align to Civ VI's route set.**
  Plus: fewer overlapping races. Minus: loses a strong Create identity.
- **C — A complementary manufacturing/knowledge/freight network.** Plus: specialized
  cities cooperate. Minus: can become another prescribed three-city checklist.

## Supersession

The initial D27 C radio answer was tentative and accompanied by a preference for removal. F05 A resolves this in favor of removing Industrial victory. Earlier complementary-network victory proposals are historical research.

## Dependencies and validation

Related decisions: [D01](0001-where-does-a-city-s-development-exist.md), [D02](0002-what-prevents-every-city-building-everything.md), [D08](0008-what-does-a-developed-city-produce-indefinitely.md), [D09](0009-building-families-and-operating-costs.md), [D16](0016-trade-roads-and-rail-logistics.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D26](0026-which-kinds-of-victory-belong-in-civcraft.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)

## M1 implementation record

The new `balance1` campaign implements this decision's M1 scope while retaining
Original/P1 semantics. The [versioned contract and prototype parameters](../M1-CAMPAIGN-SCOPE.md)
and its linked native/save evidence distinguish delivered behavior from later
End staging, economic calibration and other roadmap work.
