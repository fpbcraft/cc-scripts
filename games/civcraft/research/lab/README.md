# CivCraft research and balance laboratory

This initiative follows [the supplied authoritative specification](GOAL_SPECIFICATION.md), SHA-256 `4d5a275d8dec5442b77f5547641920193c1e1a69797262e16b63f90410af60a3`. The user supplied `/Users/fpbrault/Documents/CivCraft_Research_Simulation_ML_Balance_Goal.md`. The specification has been copied here for reproducibility.

**Current status: P1 approved and implemented on `codex/civcraft-p1-balance`; validation and draft PR preparation are in progress.** The user-requested healer change H1 is implemented. P2–P4 remain unapproved proposals. Shared authoritative lifecycle extraction, authentic headless simulation, bounded workers, observer-only candidate generation, policy experiments, checkpoints, and initial measurements exist. Broad conditional balance, robust adversarial policies, recoverability estimates, and the ML deployment comparison remain validation work. See [requirement coverage](REQUIREMENTS_MATRIX.md) rather than treating the existence of ten documents as proof of completion.

## Research documents

Start with [the first gameplay change package](FIRST_CHANGE_PACKAGE.md), including the user-requested healing change, and [the research review brief](REVIEW_BRIEF.md).

1. [Current implementation audit](CURRENT_STATE_AUDIT.md)
2. [Civilization VI comparison](CIV6_COMPARISON.md)
3. [Simulation architecture](SIMULATION_ARCHITECTURE.md)
4. [AI and ML research plan](AI_ML_RESEARCH_PLAN.md)
5. [Experiment protocol](EXPERIMENT_PROTOCOL.md)
6. [Executed baseline report](BASELINE_BALANCE_REPORT.md)
7. [Prioritized issue register](BALANCE_ISSUES.md)
8. [Coherent redesign proposal](REDESIGN_PROPOSAL.md)
9. [Implementation-ready roadmap](IMPLEMENTATION_ROADMAP.md)
10. [Continuous balance testing](CONTINUOUS_BALANCE_TESTING.md)

Earlier [opening balance research](../civ6-balance-2026-10-26/BALANCE-RESEARCH.md), [specialization/faction/victory investigation](../civ6-balance-2026-10-26/SPECIALIZATION-FACTIONS-VICTORY.md), and [Civ VI reference catalog](../civ6-balance-2026-10-26/README.md) provide the initial facts and source links. Newer proposals remain hypotheses until tested under the experiment protocol.

P1 implementation and validation: [P1_IMPLEMENTATION.md](P1_IMPLEMENTATION.md).

Latest focused checks: [expanded observer proposals](PROPOSAL_INTERFACE_REPORT.md),
[requested healing boundary](HEALING_CHANGE_VALIDATION.md), and
[lead persistence/endgame timing](LEAD_PERSISTENCE_REPORT.md).
The [coordinated siege follow-up](COORDINATED_SIEGE_REPORT.md) separates a
native-validated supplied-army capture from a negative eight-game economic
evaluation; it does not establish conquest-route parity.
The [operational follow-up](OPERATIONAL_SIEGE_REPORT.md) reproduces that game,
isolates a routing trap from a shared checkpoint, and confirms that upkeep
automatically removes two full-health siege reinforcements.

## Run locally

From the repository root:

```sh
python3 -m venv /tmp/civcraft-lab-env
/tmp/civcraft-lab-env/bin/pip install -r tools/civcraft_lab/requirements.txt
/tmp/civcraft-lab-env/bin/python -m unittest discover -s tests -p test_civcraft_lab.py -v
/tmp/civcraft-lab-env/bin/python tools/civcraft_lab/check_native_parity.py \
  --output /tmp/civcraft-native-parity.json
/tmp/civcraft-lab-env/bin/python tools/civcraft_lab/run.py \
  --config games/civcraft/research/lab/pilot_manifest.json \
  --output /tmp/civcraft-pilot.json --workers 2
```

The native parity command requires CraftOS-PC; the other commands run without Minecraft, rendering, or network access after installing Lupa. Full game boundaries and rule functions come from the actual installed-game modules. Cutoffs, errors, and timeouts are never relabeled as Score wins.

Standard-hostiles games currently expose confirmed issue BAL-00: a mob-captured Settler crashes the next spawner accounting update. The pilot preserves errors; no-hostile controlled experiments must declare that restriction. No gameplay fix or live AI deployment was silently bundled into this research.

## Bounded optimization and cross-play

```sh
/tmp/civcraft-lab-env/bin/python tools/civcraft_lab/evolve.py \
  --output-dir /tmp/civcraft-strategy-evolution --strategy-search \
  --train-seeds 75123 --eval-seeds 95117,18731 \
  --population 3 --generations 2 --workers 2
/tmp/civcraft-lab-env/bin/python tools/civcraft_lab/crossplay.py \
  --league /tmp/civcraft-strategy-evolution/league.json \
  --output /tmp/civcraft-crossplay.json --seeds 99119,61283 --workers 2
```

These are bounded pilots, not sufficient sample sizes for faction/victory equivalence. Economic-only search is available without `--strategy-search`; high-level goal commitment is a distinct experiment. Training/evaluation seeds are disjoint. Holdouts are consulted only after training selection, source hashes are recorded, and a source change invalidates a candidate's evaluation. Freeze engine/policy source while running a study.

Large raw per-turn traces and model outputs belong in disposable/local output directories by default. Commit compact manifests/results and explicit reproduction commands. Exported `champion.lua` is small policy **data** for the offline adapter; it does not replace the shipping AI. Full-game native conformance and strength retention must precede a deployment proposal.

## Executed evidence

The [baseline report](BASELINE_BALANCE_REPORT.md) distinguishes measured results from the larger research plan:

- Clean bounded strategy search: selected controller 6/8 held-out win credit versus original 2/8; only two independent evaluation maps. Economic-weight-only search showed no gain.
- Route-controller cross-play: 24/24 completed; selected expedition 12/12 appearances. Diplomatic-controller seat wins all ended through Industrial, illustrating why policy intent and actual route are separate fields.
- Four exact-checkpoint mistake pairs: a legal early research diversion delayed two wins 10–11 rounds and reversed another against a closer rival.
- Actual selected Lua export: complete native/offline final-state equality at expedition victory, round 125; measured native runtime and sampled memory are recorded.
- Auxiliary offline outcome regression: held-out Brier 0.1700 versus constant 0.2500, with only one independent map block per split. It uses privileged totals and is excluded from playing agents.

Reproduce the diagnostic model after generating route cross-play raw results:

```sh
python3 games/civcraft/research/lab/fit_outcome_pilot.py \
  --input /tmp/civcraft-route-crossplay.raw.json \
  --output /tmp/civcraft-outcome-model.json
```

These results support the next research decisions; they do not establish balanced factions/routes or approve gameplay changes.

Further controlled studies are recorded in the baseline: 32 archive-adaptation
games found a counter to the previous champion (3/4 held-out credit), and a
36-game faction sweep plus 36 fixed-personality ablations showed how much AI
personality can masquerade as faction strength. These are bounded studies,
with no all-map faction ranking or calibrated route-fairness conclusion.

- [M3 CPU/RSS scaling and Lua hotspots](PERFORMANCE_REPORT.md)

- [Native observer/Surprise War/trace conformance](CONFORMANCE_EXTENSION_REPORT.md)

- [Starting-position controls](START_POSITION_REPORT.md)

- [Military competence and exploration bottleneck](MILITARY_COMPETENCE_REPORT.md)

- [Compact format experiments and retention controls](POLICY_FORMAT_COMPARISON.md)

Historical experiments with source hash `9b12a1a2…` precede H1. They remain
source-frozen research evidence, not post-healing-change balance measurements.
See [healing validation](HEALING_CHANGE_VALIDATION.md) for the new rule boundary.

[Council reachability audit](COUNCIL_REACHABILITY_REPORT.md): 10,548 native/Lupa election cases; external-support dependence applies at 2–4 players.
