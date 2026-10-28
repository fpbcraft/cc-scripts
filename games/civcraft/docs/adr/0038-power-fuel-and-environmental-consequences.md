# ADR-0038: Power, fuel and environmental consequences

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D38; F13, F14
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has themed machinery and processing but no
Gathering Storm-style power/fuel/climate system. [Power](https://www.civilopedia.net/en-US/gathering-storm/concepts/power/), [environment](https://www.civilopedia.net/en-US/gathering-storm/concepts/environmental_effects/)

## Decision

Use local per-city Create stress capacity and machine impact measured in SU. Do not store or spend SU as fuel. Provide machine activation/priorities: lower-priority powered operations pause when capacity is insufficient while basics continue. Abstract shafts and RPM; rails do not transmit torque. Fuel is a separate resource if a generator needs it.

## Rationale and consequences

Local SU makes machine operation thematic and bounded in cost. Priority-based suspension deliberately differs from Create-wide overstress stalls; fuel, stored resources and mechanical capacity must remain distinct.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep current passive machines/limited recipes.** Plus: minimal overhead.
  Minus: little operating trade-off after construction.
- **B — Power, fuel and climate/disaster consequences.** Plus: a substantial
  late economic layer. Minus: several new simulations and balance dependencies.
- **C — Simple Create power capacity, without global climate.** Plus: thematic
  machine operation choices. Minus: another capacity meter; avoid compulsory wiring chores.

## Dependencies and validation

Related decisions: [D09](0009-building-families-and-operating-costs.md), [D15](0015-strategic-resources-and-manufacturing.md), [D16](0016-trade-roads-and-rail-logistics.md), [D25](0025-faction-identity-and-balance.md), [D27](0027-industrial-victory-and-city-specialization.md), [D33](0033-campaign-length-and-game-speed-scaling.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
