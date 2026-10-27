# ADR-0031: Wilderness threats and warning windows

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D31; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft uses Minecraft spawners/outposts and deterministic
hostile behavior. Civ VI's barbarian scout/report/raid loop can reveal an
approaching threat before the attack. This intent is discussed in the [interview](https://gamesbeat.com/why-firaxis-decided-to-make-drastic-changes-to-cities-in-civilization-vi/).

## Decision

Use visible spawner alert levels and raid warnings so wilderness threats create anticipation and preparation choices. A fuller hostile scout/report loop can be considered later.

## Rationale and consequences

Visible alerts turn wilderness pressure into preparation choices. Reaction time must fit movement speed and avoid either unavoidable raids or harmless repeated warnings.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep current spawner pressure.** Plus: themed and compact. Minus:
  pressure can be harder to anticipate or influence.
- **B — Scout discovery followed by organized raids.** Plus: information and
  interception matter. Minus: more hostile state and pathfinding.
- **C — Simple visible spawner alert levels and raid warnings.** Plus: readable
  preparation choices. Minus: fewer emergent scout interactions.

## Dependencies and validation

Related decisions: [D06](0006-does-a-settler-consume-population.md), [D07](0007-opening-investment-ratios.md), [D17](0017-unit-roster-and-distinct-roles.md), [D21](0021-combat-walls-and-siege.md), [D23](0023-healing-away-from-home.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
