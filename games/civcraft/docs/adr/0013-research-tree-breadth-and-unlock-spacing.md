# ADR-0013: Research-tree breadth and unlock spacing

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D13; F03, F15
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has 45 technologies across six Ages. Gathering
Storm's reference tree is larger and spans nine eras. More entries alone do
not guarantee useful decisions. [Reference catalog](../../research/civ6-balance-2026-10-26/README.md)

## Decision

Keep six Ages and reshape research branches, prerequisites and unlock spacing. Give each era useful choices and operating time instead of expanding to Civ VI tree size.

## Rationale and consequences

Reshaping six Ages preserves the existing thematic scale while fixing dead unlock windows. Prerequisite changes require explicit campaign versioning and useful late investment lifetimes.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep six Ages and the current tree.** Plus: recognizable, compact theme.
  Minus: existing unlock gaps and bottlenecks need other remedies.
- **B — A similarly broad era-by-era tree.** Plus: more intermediate choices.
  Minus: longer campaigns and potential filler technologies.
- **C — Keep six Ages, reshape branches and unlock spacing.** Plus: focused
  decisions at manageable size. Minus: prerequisites and saves need careful versioning.

## Dependencies and validation

Related decisions: [D07](0007-opening-investment-ratios.md), [D09](0009-building-families-and-operating-costs.md), [D11](0011-one-research-stream-or-science-plus-civics.md), [D12](0012-research-boosts-earned-through-actions.md), [D28](0028-end-expedition-preparation-versus-final-checklist.md), [D33](0033-campaign-length-and-game-speed-scaling.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
