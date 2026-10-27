# ADR-0030: Villages, trade diplomacy and global institutions

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D30; F16
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has influence-based village alliances, envoys,
treaties, pledges and Council resolutions. Civ VI adds city-state quests,
suzerainty, diplomatic favor and a broader Congress. [World Congress](https://www.civilopedia.net/en-US/gathering-storm/concepts/world_congress/)

## Decision

Use a few village contracts and consequential treaties, retaining useful existing diplomacy. A fuller city-state/favor/Congress ecosystem is future scope, not required now.

## Rationale and consequences

Contracts and treaties create active neutral-world choices with fewer currencies. Repeatability, collusion and contract farming must not produce unchecked income or resource loops.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the current diplomacy and village rules.** Plus: existing readable
  foundation. Minus: less active neutral-world interaction.
- **B — Closely reproduce city-states/favor/Congress.** Plus: a deep political
  economy. Minus: more currencies, exceptions and AI negotiation.
- **C — A few village contracts and consequential treaties.** Plus: active diplomacy
  with fewer meters. Minus: repeat contracts need farming/collusion protections.

## Dependencies and validation

Related decisions: [D15](0015-strategic-resources-and-manufacturing.md), [D16](0016-trade-roads-and-rail-logistics.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D25](0025-faction-identity-and-balance.md), [D29](0029-does-diplomatic-victory-require-a-rival-s-consent.md), [D37](0037-espionage.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
