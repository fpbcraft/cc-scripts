# ADR-0034: Simultaneous peaceful turns and wartime ordering

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D34; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft lets peaceful players act independently and
sequences active war groups. Civ VI offers turn modes including sequential,
simultaneous and dynamic multiplayer; there is not one universal Civ VI mode.

## Decision

Keep the existing peaceful simultaneous / active-war-component turn model. Improve its visibility and verify fairness; do not replace it with another combat phase structure by default.

## Rationale and consequences

The existing war-component model reduces peaceful waiting while sequencing conflicts. New group, route and raid actions must preserve fairness under simultaneous orders and real network timing.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep CivCraft's war-component model.** Plus: little peaceful waiting.
  Minus: reaction/order rules need clear presentation.
- **B — Align to a selected Civ VI multiplayer mode.** Plus: familiar behavior.
  Minus: sequential waiting or simultaneous click races depend on the mode chosen.
- **C — Keep the hybrid but expose a simpler explicit combat phase/order.** Plus:
  readable fairness. Minus: adds a transition and may increase waiting.

## Dependencies and validation

Related decisions: [D20](0020-stacking-and-support-unit-handling.md), [D21](0021-combat-walls-and-siege.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D32](0032-capture-occupation-and-defeat.md), [D33](0033-campaign-length-and-game-speed-scaling.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
