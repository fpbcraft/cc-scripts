# ADR-0020: Stacking and support-unit handling

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D20; F07
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft supports a linked settler/guard pair but not the
full military/civilian/support grouping model of Civ VI. [Formations](https://www.civilopedia.net/en-US/gathering-storm/concepts/combat_12/)

## Decision

Adopt Civ VI-like military/civilian/support grouping and shared movement. Specify occupancy, selection, targeting, capture, detachment and escort behavior without creating unrestricted military stacks.

## Rationale and consequences

Shared movement reduces escort and support orders while retaining useful unit roles. Occupancy, selection and targeting must remain explicit; grouping is not permission for unlimited military stacking.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep current escort rules and separate support pieces.** Plus: clear
  occupancy. Minus: congestion and more healer/engineer movement orders.
- **B — Civ VI-like support/civilian formations.** Plus: escorts and support move
  together. Minus: selecting, targeting and displaying a tile becomes harder.
- **C — Attach support as a visible army component.** Plus: fewer separate pieces.
  Minus: new damage, detachment and equipment rules must be explicit.

## Dependencies and validation

Related decisions: [D17](0017-unit-roster-and-distinct-roles.md), [D19](0019-combining-units-into-formations.md), [D21](0021-combat-walls-and-siege.md), [D23](0023-healing-away-from-home.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
