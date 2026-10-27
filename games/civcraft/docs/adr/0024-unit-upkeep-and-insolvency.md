# ADR-0024: Unit upkeep and insolvency

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D24; F04
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft charges upkeep and can automatically disband
recent recruits when gold becomes negative. A matched replay lost two healthy
catapults this way. Civ VI also treats military maintenance as a budget and
provides policy choices affecting it. [Local evidence](../../research/lab/OPERATIONAL_SIEGE_REPORT.md)

## Decision

Use Civ VI-inspired military budgeting with maintenance doctrines, visible forecasts, a bounded warning/retirement window and a deterministic fallback. Do not silently import amenity penalties into a game without amenities, or present this as exact Civ VI bankruptcy.

## Rationale and consequences

Forecasts, maintenance doctrines and a bounded choice window constrain armies while preserving player agency. Avoid indefinite free credit, repeated warning resets and unexplained retirement ordering.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep upkeep and current automatic removal.** Plus: a hard budget limit.
  Minus: valuable recent investment can disappear unexpectedly.
- **B — Closely reproduce Civ VI maintenance/shortage/policy rules.** Plus: a
  fuller reference. Minus: depends on several other adopted systems.
- **C — Keep upkeep, show forecasts and offer bounded retirement choices.** Plus:
  preserves agency. Minus: needs a deadline and anti-free-credit rules.

## Dependencies and validation

Related decisions: [D08](0008-what-does-a-developed-city-produce-indefinitely.md), [D11](0011-one-research-stream-or-science-plus-civics.md), [D16](0016-trade-roads-and-rail-logistics.md), [D18](0018-upgrading-an-existing-unit.md), [D19](0019-combining-units-into-formations.md), [D21](0021-combat-walls-and-siege.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
