# ADR-0019: Combining units into formations

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D19; F11
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has settler escorts but no Corps/Army merge.
Civ VI combines same-type military units into stronger formations after civic
unlocks, reducing the number of pieces. [Formations](https://www.civilopedia.net/en-US/gathering-storm/concepts/combat_12/)

## Decision

Add one later-game formation tier combining compatible units into one stronger piece. Define merge cost, XP handling and upkeep so merging is a choice rather than a costless universal action.

## Rationale and consequences

A single formation tier reduces late piece counts without multiple merge systems. Strength, upkeep and XP rules must leave a reason sometimes to retain separate units.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep independent units.** Plus: transparent and reversible positioning.
  Minus: late armies keep demanding many orders.
- **B — Corps/Armies and naval equivalents.** Plus: investment with fewer pieces.
  Minus: strength breakpoints, unlocks and irreversible merges add rules.
- **C — One simple late-game formation tier.** Plus: declutters armies. Minus:
  less gradual development; must avoid an automatic always-merge choice.

## Dependencies and validation

Related decisions: [D17](0017-unit-roster-and-distinct-roles.md), [D18](0018-upgrading-an-existing-unit.md), [D20](0020-stacking-and-support-unit-handling.md), [D21](0021-combat-walls-and-siege.md), [D24](0024-unit-upkeep-and-insolvency.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
