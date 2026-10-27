# ADR-0028: End Expedition: preparation versus final checklist

- Date: 2026-10-27
- Status: Accepted design direction
- Decision owner: project owner, via questionnaire D01–D38 and follow-ups F01–F16
- Traceability: D28; F05, F15
- Implementation: design record; this ADR does not assert that the change is implemented or tested.

## Context

The following comparison describes the research baseline, not necessarily the current P1 implementation.

CivCraft's three terminal End projects unlock together.
Gathering Storm's space race has staged project/research milestones and an
expedition that travels after launch; later projects accelerate it. [Exoplanet](https://www.civilopedia.net/en-US/gathering-storm/wonders/project_launch_exoplanet_expedition/)

## Decision

Rework End Expedition into a few Minecraft preparation stages and an explicit contest window with meaningful interruption/recovery. Keep it distinct from a forced identical-building checklist.

## Rationale and consequences

Staged preparation creates visible timing and response opportunities. A final countdown without an executable rival intervention would merely delay an inevitable result.

## Alternatives and their tradeoffs

These are the original questionnaire alternatives, retained as historical context.
The Decision section incorporates subsequent answers and takes precedence.

- **A — Keep the existing final queue.** Plus: simple endpoint. Minus: compressed
  preparation and limited late counterplay.
- **B — Closely mirror the staged science-race structure.** Plus: visible milestones
  and several investment windows. Minus: risks a long compulsory sequence.
- **C — A few Minecraft preparation stages and an explicit contest window.** Plus:
  thematic and readable. Minus: interruption/recovery must be precisely defined.

## Dependencies and validation

Related decisions: [D10](0010-wonders-general-bonuses-or-strategic-commitments.md), [D13](0013-research-tree-breadth-and-unlock-spacing.md), [D14](0014-switching-investments-and-completion-overflow.md), [D16](0016-trade-roads-and-rail-logistics.md), [D22](0022-raiding-an-economy-without-capturing-its-city.md), [D26](0026-which-kinds-of-victory-belong-in-civcraft.md), [D33](0033-campaign-length-and-game-speed-scaling.md)

Implement through the linked [balance roadmap](../ROADMAP-balance.md). Cover rule
invariants, AI use and readable UI in the same playable slice; verify save/load,
shared-rules simulation parity and relevant native behavior. Do not transfer
historical test results to changed rules without rerunning the appropriate checks.

## Evidence

- [Original decision review](../../research/lab/DESIGN_DECISIONS.md)
- [Recorded answers and verbatim user notes](../../research/lab/design_decision_answers.json)
- [Follow-up question wording](../../research/lab/design_followup_questions.json)
- [Design reconciliation](../../research/lab/DESIGN_RECONCILIATION.md)
