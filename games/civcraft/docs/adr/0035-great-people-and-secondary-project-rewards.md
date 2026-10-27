# ADR-0035: Great People and secondary project rewards

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D35; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has no Great Person recruitment race. Civ VI
specialized development produces points toward individual powerful figures.
[Great People](https://www.civilopedia.net/en-US/gathering-storm/concepts/greatpeople_2/)

## Decision

Defer Great People and recruitment races for this version. They may be reconsidered in a future expansion; their addition is not required by a future diplomatic victory.

## Rationale and consequences

Deferral avoids a new point currency and unique-reward race while the core economy changes. Projects need useful direct payoffs without depending on Great Person rewards.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep this layer absent.** Plus: no additional race/currency. Minus:
  projects and specialization have fewer long-term secondary payoffs.
- **B — Full category-based Great People.** Plus: strong timing and competition.
  Minus: many unique effects, points and AI valuations.
- **C — A small shared set of Inventors/Master Craftspeople.** Plus: notable
  rewards at smaller scope. Minus: still risks snowballing and must have fallbacks.

## Dependencies and validation

Related decisions: [D02](0002-what-prevents-every-city-building-everything.md), [D08](0008-what-does-a-developed-city-produce-indefinitely.md), [D10](0010-wonders-general-bonuses-or-strategic-commitments.md), [D11](0011-one-research-stream-or-science-plus-civics.md), [D25](0025-faction-identity-and-balance.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
