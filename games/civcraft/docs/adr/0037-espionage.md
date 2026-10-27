# ADR-0037: Espionage

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D37; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has no spy mission system. Civ VI spies can
perform offensive missions and counterspy. [Espionage](https://www.civilopedia.net/en-US/gathering-storm/concepts/diplo_5/)

## Decision

Defer espionage for this version. Deliver leader counterplay through the selected economic warfare and military systems; reconsider spies only through a later ADR.

## Rationale and consequences

Deferral keeps rival interference visible and avoids probabilistic mission overhead. The selected military and economic-warfare tools must supply meaningful leader counterplay.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep spies absent.** Plus: simple, visible causes. Minus: fewer ways to
  challenge a distant peaceful leader.
- **B — Full spy units, missions and counterspies.** Plus: a separate interaction
  layer. Minus: more units, probabilistic events and difficult-to-explain losses.
- **C — A small, costly abstract mission system.** Plus: counterplay without
  additional map pieces. Minus: needs warnings, defense and anti-spam limits.

## Dependencies and validation

Related decisions: [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D26](0026-which-kinds-of-victory-belong-in-civcraft.md), [D30](0030-villages-trade-diplomacy-and-global-institutions.md), [D34](0034-simultaneous-peaceful-turns-and-wartime-ordering.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
