# ADR-0023: Healing away from home

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D23; F06
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

Your requested H1 is implemented: normal rest/fortify heals
only in owned territory, while healer support works abroad. Civ VI permits
ordinary healing abroad at territory-dependent rates. [Territory](https://www.civilopedia.net/en-US/gathering-storm/concepts/diplo_15/)

## Decision

Allow ordinary rest healing outside owned territory at lower territory-dependent rates, with healers improving recovery. This explicitly supersedes the earlier H1 rule restricting passive healing to owned territory. Exact rates and stacking remain tunable.

## Rationale and consequences

Ordinary recovery abroad makes expeditions less punishing and allows longer operations. Healers remain useful through enhanced recovery, but exact rates must preserve support value rather than making it mandatory or irrelevant.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep H1.** Plus: healers and retreat routes matter. Minus: an unsupported
  expedition has limited recovery.
- **B — Civ VI-like ordinary healing abroad.** Plus: less punishing distance.
  Minus: reduces support/logistics dependence.
- **C — A limited supply/camp alternative.** Plus: an additional recovery choice.
  Minus: introduces another support rule.

## Supersession

Earlier H1 allowed healer support abroad but passive rest only at home. D23 B, explicitly confirmed by F06 A, replaces that passive-healing restriction for the new design. Preserve old campaign semantics through versioning.

## Dependencies and validation

Related decisions: [D16](0016-trade-roads-and-rail-logistics.md), [D20](0020-stacking-and-support-unit-handling.md), [D21](0021-combat-walls-and-siege.md)

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
