# ADR-0014: Switching investments and completion overflow

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D14; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft retains research/paused production progress but
discards excess output at completion. Civ VI has overflow rules and switching
details that vary by yield and modifier; exact replication needs a separate audit.

## Decision

Retain paused research and production progress; add bounded, explicit completion overflow. Specify category transitions and modifier treatment to prevent duplication.

## Rationale and consequences

Bounded overflow removes arbitrary threshold waste while preserving the cost of switching plans. Cross-category and modifier interactions can duplicate output unless conservation is explicit.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep retention with discarded overflow.** Plus: easy rules. Minus:
  threshold waste and output timing can feel arbitrary.
- **B — Closely reproduce Civ VI's detailed rules.** Plus: familiar optimizations.
  Minus: modifier interactions and less transparent edge cases.
- **C — Retain progress and bounded, explicit overflow.** Plus: reduces waste
  and supports pivots. Minus: needs anti-duplication and cross-category rules.

## Dependencies and validation

Related decisions: [D08](0008-what-does-a-developed-city-produce-indefinitely.md), [D12](0012-research-boosts-earned-through-actions.md), [D13](0013-research-tree-breadth-and-unlock-spacing.md), [D19](0019-combining-units-into-formations.md), [D28](0028-end-expedition-preparation-versus-final-checklist.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
