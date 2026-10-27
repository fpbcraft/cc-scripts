# ADR-0025: Faction identity and balance

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D25; F16
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft factions mainly have compact yield/movement/defense
bonuses. Civ VI combines civilization/leader abilities and unique content with
strong geography and infrastructure interactions. [Faction comparison](../../research/civ6-balance-2026-10-26/SPECIALIZATION-FACTIONS-VICTORY.md)

## Decision

Give each faction one signature mechanic and a modest fallback. Test conditional competitiveness across maps and opponents; avoid relying only on early flat-yield advantages.

## Rationale and consequences

One signature tool changes faction decisions without requiring many unique systems. Its fallback and resource access need conditional map/opponent tests; equal flat bonuses do not imply equal agency.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep small simple bonuses.** Plus: easy to learn and compare. Minus:
  a flat early yield can dominate without changing decisions.
- **B — Multiple abilities and unique content per faction.** Plus: strong identity.
  Minus: much more content and matchup complexity.
- **C — One signature mechanic plus a modest fallback.** Plus: meaningful identity
  at limited scope. Minus: still needs conditional map/opponent testing.

## Dependencies and validation

Related decisions: [D03](0003-how-much-should-geography-determine-a-city-s-role.md), [D05](0005-growth-constraints-food-housing-and-amenities.md), [D11](0011-one-research-stream-or-science-plus-civics.md), [D15](0015-strategic-resources-and-manufacturing.md), [D17](0017-unit-roster-and-distinct-roles.md), [D26](0026-which-kinds-of-victory-belong-in-civcraft.md), [D30](0030-villages-trade-diplomacy-and-global-institutions.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
