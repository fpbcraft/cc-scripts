# ADR-0018: Upgrading an existing unit

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D18; F09, F11
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has XP/levels but no general equipment-refit action.
Civ VI has research/resource/gold-gated upgrade paths. [Example](https://www.civilopedia.net/en-US/gathering-storm/units/unit_swordsman/)

## Decision

Add research/resource/gold-gated upgrades for existing units, retaining veteran continuity. Define location, action use, XP preservation, shortage and affordability rules explicitly.

## Rationale and consequences

Upgrades preserve veteran investment and reduce obsolete bodies. Sudden affordable upgrade waves can distort timing, so forecast both one-time costs and resulting recurring upkeep.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep separate recruitment and disbanding.** Plus: simple rules. Minus:
  obsolete bodies accumulate and prior investment is lost.
- **B — Civ VI-like upgrade chains.** Plus: veterans stay useful. Minus: upgrade
  financing can create large sudden military swings.
- **C — Minecraft equipment refits.** Plus: role continuity with selected material
  costs. Minus: prices, territory and turn consumption still need balancing.

## Dependencies and validation

Related decisions: [D14](0014-switching-investments-and-completion-overflow.md), [D15](0015-strategic-resources-and-manufacturing.md), [D17](0017-unit-roster-and-distinct-roles.md), [D24](0024-unit-upkeep-and-insolvency.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
