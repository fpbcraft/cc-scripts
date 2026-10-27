# ADR-0008: What does a developed city produce indefinitely?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D08; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

The baseline economy offers construction, recruitment, wonders
or explicit idling; P1 adds three recurring projects. Civ VI district projects provide continuing economic activity
and often Great Person progress. [Example](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_enhance_district_commercial_hub/)

## Decision

Retain P1 Ponder/Tend/Trade recurring civilian conversions, including separate remainders and paused-target semantics. Recalibrate them against new building and resource economies.

## Rationale and consequences

Continuing civilian work gives developed cities an alternative to surplus recruitment. Conversion rates must not dominate construction, and changing projects must conserve each remainder.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the existing finite menu.** Plus: least complexity. Minus: idle
  cities and unnecessary recruitment remain likely outlets.
- **B — District projects plus Great People.** Plus: mature cities contribute to
  economic and recruitment races. Minus: adds another progression system.
- **C — P1's three simple ongoing conversions.** Plus: useful work with small
  integer rules. Minus: needs calibration so operating does not beat all construction.

## Dependencies and validation

Related decisions: [D02](0002-what-prevents-every-city-building-everything.md), [D09](0009-building-families-and-operating-costs.md), [D14](0014-switching-investments-and-completion-overflow.md), [D24](0024-unit-upkeep-and-insolvency.md), [D27](0027-industrial-victory-and-city-specialization.md), [D35](0035-great-people-and-secondary-project-rewards.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
