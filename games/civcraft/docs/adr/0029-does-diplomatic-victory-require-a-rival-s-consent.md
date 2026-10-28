# ADR-0029: Does diplomatic victory require a rival's consent?

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D29; initial answer / explicit follow-up note
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft needs two-thirds of allocated delegates plus a
different member's vote. Civ VI accumulates diplomatic victory points through
several systems, rather than one final election. [Diplomatic victory](https://www.civilopedia.net/en-US/gathering-storm/concepts/diplomatic_victory/)

## Decision

Remove Diplomatic victory for this version while retaining diplomacy gameplay. A later expansion can reconsider it; do not award wins via the current final-election rule in the new ruleset.

## Rationale and consequences

Removing a rival-consent-dependent win avoids treating negotiation refusal as a numerical balance problem. Diplomacy retains economic and political value; future victory reintroduction requires its own design.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep a negotiated coalition victory.** Plus: real negotiation. Minus:
  noncooperating rivals can prevent it indefinitely.
- **B — Closely align to Civ VI's point-based ecosystem.** Plus: multiple progress
  sources. Minus: more rules, timing manipulation and possible point farming.
- **C — A compact public-objective/mandate route.** Plus: independent progress with
  costly counterplay. Minus: risks becoming another economic construction race.

## Dependencies and validation

Related decisions: [D11](0011-one-research-stream-or-science-plus-civics.md), [D16](0016-trade-roads-and-rail-logistics.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D25](0025-faction-identity-and-balance.md), [D26](0026-which-kinds-of-victory-belong-in-civcraft.md), [D30](0030-villages-trade-diplomacy-and-global-institutions.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)

## M1 implementation record

The new `balance1` campaign implements this decision's M1 scope while retaining
Original/P1 semantics. The [versioned contract and prototype parameters](../M1-CAMPAIGN-SCOPE.md)
and its linked native/save evidence distinguish delivered behavior from later
End staging, economic calibration and other roadmap work.
