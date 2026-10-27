# ADR-0021: Combat, walls and siege

- Date: 2026-10-27
- Status: Provisional — revisit combat after the economy and roster
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D21; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

Both games have tactical hex combat, ranged attacks and
walls, but their damage rules and siege options differ. CivCraft has deterministic
forecasts and no general ram-like early wall-support role. [Catapult](https://www.civilopedia.net/en-US/gathering-storm/units/unit_catapult/), [ram](https://www.civilopedia.net/en-US/gathering-storm/units/unit_battering_ram/)

## Decision

Provisionally pursue a compact Minecraft combat/wall/siege ecosystem while preserving readable forecasts. Revisit after economy and roster work; damage formulas, siege roles and wall counters are not yet finalized.

## Rationale and consequences

Compact siege roles can restore useful counters while forecasts stay readable. The user deliberately deferred the exact combat model; do not treat damage formulas or wall behavior as accepted parameters.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep current combat and improve AI/clarity.** Plus: preserves a working
  core. Minus: large equipment breakpoints and siege friction may remain.
- **B — Closely align combat classes, counters and siege progression.** Plus:
  a richer reference model. Minus: much wider rebalancing and tactical complexity.
- **C — Retain deterministic combat, fix selected role/counter gaps.** Plus:
  targeted changes. Minus: bespoke systems need equally good explanations.

## Dependencies and validation

Related decisions: [D17](0017-unit-roster-and-distinct-roles.md), [D20](0020-stacking-and-support-unit-handling.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D24](0024-unit-upkeep-and-insolvency.md), [D32](0032-capture-occupation-and-defeat.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
