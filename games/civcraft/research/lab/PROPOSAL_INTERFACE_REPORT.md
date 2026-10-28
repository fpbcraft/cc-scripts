# Observer proposal interface expansion

## Scope

The research adapter's proposal list now exposes observer-derived candidates
for more of the existing action vocabulary without changing gameplay rules or
authoritative validation. `games/civcraft/actions.lua` remains the legality
oracle. The interface is explicitly non-exhaustive: hidden terrain, private
offers, stockpiles, treaty terms, world-unique landmarks and other omitted
state can make a candidate reject.

`Engine.legalActions` still returns its original two values (candidate list and
coverage string). `Engine.legalActionMetadata()` provides a separate schema
with `exhaustive=false`, observer-only status, covered families, and explicit
unbounded diplomatic/Council term limits.

Covered families now include:

* research and building/unit/queue-none production;
* visible city work tiles and bounded citizen assignments;
* movement, heal, standby, skip, cancel-route, auto-explore and disband unit
  modes;
* settler founding, escort attach/detach, engineer rail candidates and visible
  city strikes;
* exchange and independent-village envoy candidates when public prerequisites
  are visible;
* known-contact talks/war declarations, bounded diplomacy templates, pending
  offer replies/counters, and public Council votes/proposals.

The existing `disband` action is represented once as a proposal; no duplicate
game action was introduced.

## Validation

The focused Lupa tests pass:

```text
/tmp/civcraft-lua-env/bin/python -m unittest \
  games/civcraft/research/lab/test_proposal_interface.py \
  tests/test_civcraft_lab.py
```

18 tests passed (six proposal-specific and twelve lab tests). They cover metadata limits, read-only behavior of both host state and the detached observation, privacy of
rival gold/stockpiles/private plans, and a representative accepted subset of
research, production, healer, standby and route-cancel commands. The proposal
list is compared before and after injecting rival-only private data. Finished
turns and waiting war actors exclude ordinary orders; the existing exception
for replies and Council actions remains available. A self-vote and a censure
proposal targeting another member are accepted through the authoritative
dispatcher after ending the actor's turn. Council candidates also include
public war pairs for peace proposals.

The native companion also passes:

```text
/tmp/civcraft-lua-env/bin/python \
  games/civcraft/research/lab/check_proposal_native_parity.py
```

On a fresh two-player compact Continents state, the native CraftOS result and
Lupa result matched exactly for the canonical proposal list, coverage string,
metadata schema and initial-state hash. Native host was CraftOS-PC /
ComputerCraft 1.112.0; exit code was 0. Source fingerprints before and after
the run match; the result also records the fixture script hashes. This native
fixture covers initialization, while the Council dispatch checks run in Lupa.

The compact machine-readable result is
`results/proposal_native_parity.json`. Raw native output remains in its
disposable profile and is not committed.

## Limits

Candidate count and family presence vary with the observer's current public
projection. This is an action-candidate interface for research policy tooling,
not an exhaustive legal mask and not a claim that all candidate templates are
accepted in every state. Diplomatic offer and Council term spaces remain
bounded templates by design; full offer/resource/deadline enumeration belongs
in a separate, explicitly stateful experiment.
