# ADR-0017: Unit roster and distinct roles

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D17; F11
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has 25 recruitable unit definitions, including
overlapping engineer/healer generations, and no air-combat layer. Civ VI has a
larger roster, upgrade families and more late-game domains. [Unit catalog](https://www.civilopedia.net/en-US/gathering-storm/units/)

## Decision

Consolidate into clear core land roles (melee, ranged, mobile, anti-mobile and siege), a compact navy, and a small support roster. Provide milestone upgrades. Do not add an initial air-combat layer; roster size follows role usefulness.

## Rationale and consequences

Clear counters and upgrades support tactical choice with a smaller roster. Nominally distinct roles must earn their place on real map sizes; no initial aircraft avoids a separate basing/interception layer.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the current roster.** Plus: low learning/content cost. Minus:
  duplicated support jobs and some role gaps remain.
- **B — Broad class and domain coverage.** Plus: more counters and era variety.
  Minus: more pieces, UI, AI and balance work, especially aircraft.
- **C — Fewer clear families with equipment variants.** Plus: more useful choices
  per unit type. Minus: requires migration and explicit role/counter design.

## Dependencies and validation

Related decisions: [D15](0015-strategic-resources-and-manufacturing.md), [D18](0018-upgrading-an-existing-unit.md), [D19](0019-combining-units-into-formations.md), [D20](0020-stacking-and-support-unit-handling.md), [D21](0021-combat-walls-and-siege.md), [D23](0023-healing-away-from-home.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
