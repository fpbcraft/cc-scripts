# ADR-0022: Raiding an economy without capturing its city

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D22; F10
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft supports city capture but no general player
pillage action for its economy/rails. Civ VI lets attackers pillage improvements
and districts, making external infrastructure a military target. [Pillaging](https://www.civilopedia.net/en-US/gathering-storm/concepts/combat_13/)

## Decision

Allow limited pillaging of specialty sites, trade/transport links and strategic-resource improvements. Protect ordinary food improvements. Provide visible disruption and bounded repair work; do not expand pillaging to every improved tile by default.

## Rationale and consequences

Key-site and strategic-input disruption enables limited war with bounded repairs. Those few targets must not be so brittle that one raid irreversibly decides an entire economy.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep capture as the main disruption.** Plus: low UI/rules cost. Minus:
  fewer limited wars or ways to delay a leading rival.
- **B — Broad pillage/repair rules.** Plus: many targets and tactical choices.
  Minus: repetitive damage/repair management and snowball risks.
- **C — Raid only key sites and transport links.** Plus: clear counterplay with
  bounded repair work. Minus: fewer options; those few targets must not be brittle.

## Dependencies and validation

Related decisions: [D01](0001-where-does-a-city-s-development-exist.md), [D04](0004-builders-and-tile-improvements.md), [D16](0016-trade-roads-and-rail-logistics.md), [D21](0021-combat-walls-and-siege.md), [D27](0027-industrial-victory-and-city-specialization.md), [D28](0028-end-expedition-preparation-versus-final-checklist.md), [D30](0030-villages-trade-diplomacy-and-global-institutions.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
