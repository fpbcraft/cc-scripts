# ADR-0039: One current ruleset and explicit save migration

Status: Accepted, 2026-10-30.

## Context

CivCraft is unreleased. Keeping separate historical gameplay branches adds
maintenance and validation work without a released compatibility commitment.
The owner explicitly permits breaking rules changes provided old saves are
automatically fixed or the player is instructed to delete/reset them.

## Decision

Maintain one current gameplay ruleset. Historical profile IDs and save-schema
versions may be read to select migrations, but must not preserve executable
historical economy, generation, AI or gameplay engines.

Migrate/repair supported saves deterministically into current state, validate
the complete candidate, and only then use or persist it. Preserve meaningful
campaign data where practical; do not fabricate resource, technology or project
progress to conceal malformed state. If reliable repair is unavailable, reject
the load with a clear reset/delete instruction. Do not silently erase saves,
unknown installation files, or partially overwrite a valid campaign.

Current rules still require authoritative actions, private projections,
consistent UI/AI forecasts, persistence and native validation. Test old saves as
migration/reset inputs and test the resulting current behavior, rather than
requiring old gameplay outcomes. Keep M4 activation gated on complete integrated
rules/UI/AI/native delivery. Balance experiments remain paused.

## Supersession

This decision supersedes earlier blanket promises that historical campaign
profiles retain their gameplay semantics, including that wording in the ADR
index, roadmap and original M4 proposal. Earlier design reasoning remains as
history; save-format compatibility is now implemented by migration or explicit
reset, not parallel rule engines.
