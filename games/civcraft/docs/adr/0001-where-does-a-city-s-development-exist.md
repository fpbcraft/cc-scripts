# ADR-0001: Where does a city's development exist?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D01; F08
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

Most CivCraft buildings live inside the city record;
wonders already occupy map tiles. Civ VI places districts outside the center,
with buildings belonging to them. [District reference](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/)

## Decision

Place a small set of visible specialty sites (such as Works, Knowledge and Freight); keep ordinary buildings in cities. Each specialty site consumes one focus slot.

## Rationale and consequences

Visible sites create spatial commitment and limited-war targets without a full district catalog. Placement and crowded-map readability become new UI/AI responsibilities.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep compact cities.** Plus: clear map and cheap management. Minus:
  less spatial commitment and fewer distinct targets outside city centers.
- **B — Civ VI-style districts.** Plus: placement, land use and raiding become
  major decisions. Minus: more UI, placement rules and AI work; crowded small maps.
- **C — A few visible special sites.** Place a limited Works, Knowledge or
  Freight site, while ordinary buildings stay inside cities. Plus: spatial
  identity with fewer objects. Minus: another boundary to explain and balance.

## Dependencies and validation

Related decisions: [D02](0002-what-prevents-every-city-building-everything.md), [D03](0003-how-much-should-geography-determine-a-city-s-role.md), [D04](0004-builders-and-tile-improvements.md), [D10](0010-wonders-general-bonuses-or-strategic-commitments.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D27](0027-industrial-victory-and-city-specialization.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
