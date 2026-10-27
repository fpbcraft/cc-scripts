# ADR-0010: Wonders: general bonuses or strategic commitments?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D10; F12
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft already places world-unique wonders on tiles; this
is a similarity. Its six wonders have a smaller, mostly yield-oriented role set.
Civ VI has a much wider set of specialized, placement-constrained wonders.
[Wonder reference](https://www.civilopedia.net/en-US/gathering-storm/wonders/)

## Decision

Target approximately 12–16 differentiated Minecraft wonders across six Ages. Preserve viable alternatives to each; the range is a proposal target rather than a requirement to add filler.

## Rationale and consequences

A moderate wonder roster supports contested, distinct investments without Civ VI-scale content overhead. Missing a wonder must not invalidate a victory; cut duplicate effects rather than filling a count.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep six broadly useful bonuses.** Plus: easy to learn. Minus: limited
  identity and weaker build-versus-develop dilemmas.
- **B — A broad Civ VI-like wonder ecosystem.** Plus: many distinct strategies.
  Minus: content, AI valuation and balance workload grow substantially.
- **C — A few sharply differentiated Minecraft wonders.** Plus: memorable
  commitments with a small roster. Minus: missing a contested wonder may sting.

## Dependencies and validation

Related decisions: [D01](0001-where-does-a-city-s-development-exist.md), [D02](0002-what-prevents-every-city-building-everything.md), [D25](0025-faction-identity-and-balance.md), [D29](0029-does-diplomatic-victory-require-a-rival-s-consent.md), [D35](0035-great-people-and-secondary-project-rewards.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
