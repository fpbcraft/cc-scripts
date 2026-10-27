# ADR-0011: One research stream or science plus civics?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D11; F03, F04
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has one global science tree. Civ VI has separate
technology and culture-driven civic trees, including governments and policies.
[Civics](https://www.civilopedia.net/en-US/gathering-storm/concepts/culture_4/), [governments](https://www.civilopedia.net/en-US/gathering-storm/concepts/govt_1/)

## Decision

Use a small milestone-based doctrine system, with empire policy choices and maintenance reductions. Do not add a separately accumulated civic/culture yield or full second tree. Avoid making science the only milestone source.

## Rationale and consequences

Doctrines offer empire choices and upkeep tools without another full research economy. Milestones must not all reward science or force an identical expansion checklist; switching needs bounded rules.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep one research tree.** Plus: least UI and bookkeeping. Minus: science
  tends to unlock many kinds of advantage together.
- **B — Separate science and culture/civic trees.** Plus: independent strategic
  clocks. Minus: another yield, tree and balancing problem.
- **C — A small milestone-based doctrine track.** Plus: organization choices
  without a second full tree. Minus: requires clear milestone and respec rules.

## Dependencies and validation

Related decisions: [D07](0007-opening-investment-ratios.md), [D12](0012-research-boosts-earned-through-actions.md), [D13](0013-research-tree-breadth-and-unlock-spacing.md), [D26](0026-which-kinds-of-victory-belong-in-civcraft.md), [D36](0036-governors-and-persistent-city-administrators.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
