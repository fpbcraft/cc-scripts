# ADR-0002: What prevents every city building everything?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D02; F08
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft has building prerequisites but no advanced-city
capacity limit. Civ VI gates specialty district capacity at population 1/4/7,
then every three additional population; some districts are exceptions. [Source](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_10/)

## Decision

Use one specialization allowance: one focus slot per specialty site, with a small growth-based increase. Basics, defenses and ordinary improvements do not consume these slots. Redevelopment has an explicit cost.

## Rationale and consequences

One shared allowance prevents every city becoming identical without double-gating specialties. Population loss and occupation must not accidentally destroy a legal site or duplicate capacity.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep unrestricted building access.** Plus: flexible recovery and easy
  rules. Minus: specialization must come entirely from incentives and geography.
- **B — Population-gated specialty districts.** Plus: growth buys strategic
  options. Minus: more planning commitments and potentially punitive small cities.
- **C — Limited city focus slots.** Plus: strong role choices with compact UI.
  Minus: abstract capacity and focus-switching rules can feel artificial.

## Dependencies and validation

Related decisions: [D01](0001-where-does-a-city-s-development-exist.md), [D05](0005-growth-constraints-food-housing-and-amenities.md), [D09](0009-building-families-and-operating-costs.md), [D27](0027-industrial-victory-and-city-specialization.md), [D36](0036-governors-and-persistent-city-administrators.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
