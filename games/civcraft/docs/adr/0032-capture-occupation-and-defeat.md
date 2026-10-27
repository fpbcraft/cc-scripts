# ADR-0032: Capture, occupation and defeat

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D32; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft transfers cities and lacks a genuine player
elimination transition. Civ VI has explicit defeat handling and, with its
expansions, loyalty/occupation pressures on conquest. [Loyalty](https://www.civilopedia.net/en-US/gathering-storm/concepts/loyalty/)

## Decision

Add simple occupation/recovery and explicit player defeat handling. Ensure correct turns, ownership, surviving actors and winner reporting without a full loyalty simulation.

## Rationale and consequences

Simple occupation gives conquest a cost while explicit defeat prevents endless actor/turn cleanup. Audit orphan units, hostile ownership, routes and diplomacy without introducing a full loyalty simulation.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep immediate transfer with minimal friction.** Plus: quick resolution.
  Minus: weak recovery/occupation choices; missing defeat handling still needs repair.
- **B — Fuller loyalty/occupation systems.** Plus: conquest has lasting costs.
  Minus: more city meters, unrest and potentially repetitive reconquest.
- **C — Simple occupation/recovery plus explicit defeat rules.** Plus: counterplay
  without a loyalty simulation. Minus: needs carefully limited penalties.

## Dependencies and validation

Related decisions: [D05](0005-growth-constraints-food-housing-and-amenities.md), [D21](0021-combat-walls-and-siege.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D25](0025-faction-identity-and-balance.md), [D29](0029-does-diplomatic-victory-require-a-rival-s-consent.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
