# ADR-0026: Which kinds of victory belong in CivCraft?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D26; F05
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has Conquest, Industrial, End Expedition, Diplomatic
and Score. It has no full culture/tourism or religious spread systems. Civ VI
has cultural and religious victory alongside its other routes. [Victory concepts](https://www.civilopedia.net/en-US/gathering-storm/concepts/victory_1/)

## Decision

For this version retain Conquest and End Expedition as active victory races, with Score as the deadline fallback. Remove Diplomatic and Industrial victories under ADR-0029 and ADR-0027. Magic/religion and culture/tourism victories are future possibilities, not current scope.

## Rationale and consequences

Two active routes keep the next version focused while preserving Score as a deadline resolution. Peaceful strategic diversity narrows; evaluate End counterplay and keep timeout frequency separate from route balance.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the existing five categories.** Plus: compact and Minecraft-themed.
  Minus: fewer nonmilitary ways to interact with rivals.
- **B — Add full culture/tourism and religion.** Plus: wider strategic domains.
  Minus: major new economies, units, defenses and AI systems.
- **C — Add at most one themed influence/culture route later.** Plus: selected
  strategic breadth. Minus: a partial system can feel shallow or overlap diplomacy.

## Supersession

The initial D26 A reference to the existing five categories is qualified by the explicit removal of Diplomatic (D29) and Industrial (F05). Score is a deadline fallback, not a third equally targeted active strategy.

## Dependencies and validation

Related decisions: [D11](0011-one-research-stream-or-science-plus-civics.md), [D25](0025-faction-identity-and-balance.md), [D29](0029-does-diplomatic-victory-require-a-rival-s-consent.md), [D30](0030-villages-trade-diplomacy-and-global-institutions.md), [D35](0035-great-people-and-secondary-project-rewards.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
