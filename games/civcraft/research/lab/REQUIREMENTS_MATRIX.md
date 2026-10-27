# Scope and current evidence

The research goal remains active. The current review/implementation sequence is
[FIRST_CHANGE_PACKAGE.md](FIRST_CHANGE_PACKAGE.md). The user's specific H1
request is implemented: healer support works outside owned territory, while
ordinary rest/fortify healing remains territory-restricted. P1 has been approved and implemented as a versioned prototype; its validation
is recorded in [P1_IMPLEMENTATION.md](P1_IMPLEMENTATION.md). P2–P4 remain pending review.

## Evidence and remaining work

| Requirement | Verified evidence | Remaining scope |
|---|---|---|
| A: source/content/lifecycle audit | Current-state audit, runtime inventory, static route closures, source manifests | Keep the audit synchronized with approved gameplay changes |
| B: detailed Civ VI reference | 555 public entries, all six sections/CSVs, corrected era provenance, 53 wonders and 83 projects distinguished | Public catalog is not a merged installed-game/modifier database |
| C: quantitative baseline | Source-frozen pilots; 152-game fixed-strategy faction/map matrix; 28 three-/four-player games; policy and recovery studies | Broad all-route fairness remains unproven; controllers and contexts must be distinguished |
| D: authoritative simulation | Shared Lua initialization/actor/boundary modules, actual Actions.apply, bounded isolated workers; expanded observer proposals with native initialization parity and 18 lab/interface tests | Candidates remain non-exhaustive, with bounded diplomatic terms and authoritative rejection |
| D: native fidelity | 54 short native checks; full native round-125 policy game; 21 war/save/capture checks; 75 privacy/Surprise-War/replay checks | Broader old-save/rednet/hostile/full-duration matrices remain |
| D: performance/restart | M3 1/2/4-worker CPU/RSS study, inclusive Lua profile, per-game atomic records, matching-fingerprint resume smoke | Sustained thermals and larger/war-heavy workloads remain unmeasured |
| E: policy evolution/league | Bounded strategy search, archived route cross-play, adaptation against an archived mixture; coordinated siege scenario capture, native Lua parity and eight corrected full games | Conquest still has zero opponent-city captures in the four paired evaluation cells; comparably competent route play remains research work |
| E/G: operational/economic separation | Passive full-game probe retains exact final hash; shared round-80 route branch improves travel but not capture; four-round paired replay confirms automatic full-health siege disbanding | Known-case diagnostics need fresh-map confirmation and a sustainable group-commitment policy; no live AI or insolvency-rule change |
| G: military investment recovery | Two additional continuations reuse the verified round-80 controls; four legal guard disbands change treasury net −4→0 and preserve the original siege pieces through the last actor observations | All four branches still lose with no capture; one known checkpoint does not establish win-probability recovery or optimal play |
| E: compact native exports | 207-byte strategic export retains exact full native outcome; tree/linear/MLP native prediction parity; corrected rank-only adapter oracle 4/4 exact | Learned rankers underperform in the small holdout and are not deployment candidates |
| F: auxiliary ML | 96 actual games; separate 12/6/6 train/calibration/test map blocks; privileged calibrated critic improves held-out Brier 0.2969 to 0.1753 | Six final-test clusters and fixed controllers do not give universal or causal recovery probabilities |
| G: recovery/pacing | Four research-diversion pairs; sixteen guard-first pairs; milestone telemetry; lead-persistence analysis | Other mistake types, trained recovery and broad human-play pacing need evaluation |
| G: faction/route fairness | All ten factions in a fixed-strategy four-map-family slice, seat/personality/start controls, multiplayer role denominators | This is not an all-context faction tier list or equality guarantee |
| H/I: design and deliverables | All ten named documents, detailed roadmap, issue register, concrete first package and 39-building role map | Review P1 before its implementation; keep later mechanics as separate controlled packages |
| H1: requested healer rule | Action/tactics/campaign regressions; 12 lab tests; 128 native/Lupa healing boundary cases | No long-match balance or deployed-Minecraft claim follows from focused correctness tests |

## Important findings to carry into implementation

- Early production, growth and research are coupled; frozen-income ratios are
  calibration anchors, not actual optimal opening times.
- A fixed-strategy faction matrix found Scholar won all sixteen appearances
  across eight map-family/seed blocks. The result concerns this science-race
  slice, not every strategy or multiplayer context.
- Industrial and End each have twenty-four required technologies, eighteen
  shared, but very different local production structures. Parallel industry,
  investment payoffs and military pressure prevent reading totals as turn ratios.
- Scouts can stop before contact; target memory, siege timing, force composition
  and exposure then limit conquest. A legal multi-siege positive control can
  breach and capture; one exposed catapult cannot sustain the same operation.
- Diplomatic completion requires another member's support. Treat competitive
  agency separately from weak AI voting or alternate Industrial finishes.
- High recommendation agreement is not multi-turn strength. Preserve source AI
  completion semantics, use oracle controls, and distinguish strategic policy
  data from an entirely different learned production/research ranker.

## Boundaries

Most experimental results below H1 were generated with source hash
`9b12a1a2…`. Preserve them as pre-H1 evidence; do not present them as reruns
under the changed healing rule. New studies record the new source fingerprint.
The known hostile-captured-Settler runtime error is retained as an error, not a
loss. Controlled no-hostile studies declare that restriction.

These gaps guide continued research; they are not an additional veto on
prototyping a reviewed package. Gameplay proposals must be reviewed before
implementation, as requested by the user. H1 was separately and explicitly
requested. P1 was subsequently approved and implemented; its
[48-match paired pilot](P1_PACING_REPORT.md) now provides fixed-policy
evidence, with adaptation and human pacing review still outstanding.
The [LuaJIT backend](LUAJIT_BACKEND.md) passed eight controlled conformance
cases and accelerates new studies while retaining Lua 5.3 as a reference.
No trained AI has
been installed live, no release has been published, and physical Minecraft
monitor/rednet validation is not claimed.
