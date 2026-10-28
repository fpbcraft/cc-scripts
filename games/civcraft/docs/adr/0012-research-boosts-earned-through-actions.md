# ADR-0012: Research boosts earned through actions

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D12; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft lacks an Eureka/Inspiration-equivalent layer.
Civ VI boosts connect actions to research, such as coastal settlement helping
Sailing or a Pasture helping Horseback Riding. [Eurekas](https://www.civilopedia.net/en-US/gathering-storm/concepts/science_3/)

## Decision

Add a limited set of pivotal Minecraft experiments that boost related research. They provide alternative acceleration rather than mandatory checklist tasks.

## Rationale and consequences

Selected experiments connect exploration and development to research timing. Boosts must not turn every branch into mandatory chores or reward repeated triggers.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep science-only progress.** Plus: predictable and simple. Minus:
  exploration and production have fewer direct research payoffs.
- **B — Boost objectives across most technologies/civics.** Plus: varied plans.
  Minus: checklist optimization and much more content/AI logic.
- **C — A few pivotal Minecraft experiments.** Plus: meaningful links without
  dozens of chores. Minus: unmatched branches could become less attractive.

## Dependencies and validation

Related decisions: [D04](0004-builders-and-tile-improvements.md), [D11](0011-one-research-stream-or-science-plus-civics.md), [D13](0013-research-tree-breadth-and-unlock-spacing.md), [D25](0025-faction-identity-and-balance.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
