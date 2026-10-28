# Healing boundary change validation

## Scope

This is a focused correctness fixture for the explicitly user-approved
exception to the pre-rebalance review gate:

* ordinary passive/rest healing remains limited to a unit's own civilization's
  territory;
* healer support from `alchemist` and `supplycrew` may heal an adjacent owned
  ally in neutral or enemy geography;
* healer support does not heal enemy-owned units;
* the existing healer self-aura remains, without adding an extra passive-rest
  heal outside owned territory.

The fixture uses the actual `Runtime`, production `Combat.round`, `Systems`,
world territory logic, presentation observer, and canonical encoder. Every
case starts from a fresh two-player actual runtime state. The native companion
uses a fresh CraftOS state for every case in one disposable profile.

## Matrix and expectations

There are 128 cases: 2 healer types × 4 recipient ownership/geography cases ×
2 acted states × 2 fortify states × 2 ranges × 2 HP bands.

* `owned`: owner 0 recipient in owner 0 city territory.
* `neutral`: owner 0 recipient outside either city's territory.
* `foreign_territory`: owner 0 recipient in owner 1 city territory.
* `enemy`: owner 1 recipient on neutral geography. This deliberately separates
  enemy ownership from the enemy's passive territory healing.
* `acted`: `actedThisRound`; `fortified`: the production `healing` flag.
* HP bands are 40 and 98, testing the 100 HP cap.
* The healer starts at 80 HP, is marked acted, and is always expected to reach
  90 from its existing adjacent self-aura. It must not receive an extra +20
  passive heal merely because it is in range of a city.

Expected recipient behavior is:

| Recipient | Passive/rest component | Support component when adjacent | Enemy-support control |
| --- | --- | --- | --- |
| owned ally | +20 when not acted or fortified | +10 | yes |
| neutral ally | 0 | +10 | yes |
| own ally on enemy land | 0 | +10 | yes |
| enemy-owned unit on neutral land | 0 | 0 | no |

All results are capped at 100. The round then clears `actedThisRound`, while
the explicit `healing` flag remains available for inspection.

## Evidence

The 96-case comparison passed:

* canonical authoritative state before and after the round matched exactly
  between Lupa and native CraftOS for every case;
* both player observations before and after the round matched exactly for every
  case;
* all 96 semantic expectations passed, including cap behavior, enemy-owned
  non-healing, range rejection, both healer types, and self-aura behavior;
* native exit code was 0 on CraftOS-PC `ComputerCraft 1.112.0 (CraftOS-PC
  v2.8.3)`;
* native execution took 4.200 seconds;
* source manifest was unchanged during the run.

The compact machine-readable record is
`results/healing_boundary_validation.json`. It contains the full before/after
source manifest, script hashes, per-case canonical/observation hashes, and
failure counts. Raw native JSON remains in the disposable profile recorded in
that result and is not committed.

## Reproduction

From the repository root:

```text
/tmp/civcraft-lua-env/bin/python games/civcraft/research/lab/healing_boundary_validation.py
```

The fixture files are `healing_boundary_fixture.lua`,
`healing_boundary_native.lua`, and `healing_boundary_validation.py`.

## Limits

This validates the current round-resolution boundary and observer parity; it
is not a healing-throughput or faction-balance study. It calls the production
combat round path directly on a controlled state, while normal action dispatch
and AI tactics remain covered by the parent task's focused tests. It does not
claim that healing outside territory is balanced in long matches; it only
establishes the explicitly approved rule semantics and native/offline parity.
