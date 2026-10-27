# ADR-0033: Campaign length and game-speed scaling

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D33; F15
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft's Standard deadline is 180 rounds, with Quick/Epic
variants. Civ VI normally runs a much longer strategic arc. Movement does not
simply accelerate with economic costs in either comparison.

## Decision

Use a prototype Standard deadline of 250 rounds; initially target most competitive wins around 180–230 rounds. This is a test hypothesis, not a guaranteed duration. Retune production, research, useful unit lifetimes, travel and contest windows together.

## Rationale and consequences

A longer deadline allows development and recovery, but does not itself improve pacing. Measure human minutes, travel, unit usefulness and late returns; do not delay successful play merely to hit a round target.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the current duration/speed framework.** Plus: manageable sessions.
  Minus: current unlock and travel clocks may not fit it.
- **B — A substantially longer Civ VI-like arc.** Plus: more time for each era.
  Minus: late-turn workload and multiplayer commitment increase.
- **C — Keep shorter campaigns but retime unlocks, travel and contest windows together.**
  Plus: preserves format. Minus: compressing meaningful eras needs careful pruning.

## Dependencies and validation

Related decisions: [D06](0006-does-a-settler-consume-population.md), [D07](0007-opening-investment-ratios.md), [D13](0013-research-tree-breadth-and-unlock-spacing.md), [D19](0019-combining-units-into-formations.md), [D28](0028-end-expedition-preparation-versus-final-checklist.md), [D31](0031-wilderness-threats-and-warning-windows.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
