# CivCraft v0.9 release acceptance

Feature status is tracked in [FOLLOWUPS-v0.9.md](FOLLOWUPS-v0.9.md).
Implementation details and earlier measurements are in
[IMPLEMENTATION-v0.9.md](IMPLEMENTATION-v0.9.md). Passing checks below are evidence
for their stated scope, not a declaration that the full release is complete.

## Implemented and checked

- [x] Shared human/AI/remote actions, deterministic combat forecasts, positive
  settler founding allowance, accepted-order waking and owned-territory healing.
- [x] Biome generation, fair starts and larger presets: 600-world audits plus
  native Vast generation, early AI and save/reload stress.
- [x] Observer-filtered events/snapshots, frozen explored terrain and cities,
  chronological private history, automatic paced camera-following playback,
  own-exploration exclusion and suppression of saved history on load.
- [x] Strategic/economic/tactical AI, persistent campaigns, fixed personalities
  and five host-configured difficulty levels without resource/rule bonuses.
  Sixty 100-round desktop samples and ten native 60-round samples are recorded in
  [AI-BENCHMARK.md](AI-BENCHMARK.md).
- [x] Peaceful concurrency, sequential war components, normal/surprise timing,
  spent-budget preservation, explicit defender responses and defense calls.
  Scheduler tests cover all 64 four-player war graphs; native modem tests cover
  actual command races, a surprise-war response and client reboot/rejoin.
- [x] Discovery-gated negotiations, agreements, promises, diplomatic memory,
  Council elections/resolutions and diplomatic victory safeguards.
- [x] Campaign speeds/victories, civilization descriptions/dropdown, verbose
  research sidebar/Codex, prerequisite graph, economy HUD, faction screens,
  focused compact inspectors, settings and campaign menus.
- [x] Unified next-decision control, Skip Turn/No Production, zone of control,
  coastal embarkation/melee rules, settler capture/protection/escorts and saved
  waypoint movement.
- [x] Native local, host and emulated-monitor touch sessions, plus a real
  three-computer private modem network. Tests use temporary profiles and generated
  data; installed user campaigns remain untouched.
- [x] Reproduced watchdog/collector stalls addressed and stress-tested. Native
  pan/zoom/panel rendering and longer AI simulations complete with measured bounds.
- [x] Real GitHub installer at a pinned published revision, installed private-loader
  dependencies, generated legacy-data migration and a complete installed campaign
  session. Source-tree copies cannot satisfy this installed-runtime check.
- [x] Save versions 3–6 across legacy/Create rulesets and all three game speeds:
  24 installed-loader upgrades/round trips preserve world layout, resources,
  progress, identity and explicit mid-turn movement budgets. Installer failure,
  rollback, repeat-update and startup ownership checks also pass.

- [x] Combined save/resume audit: six attacker/defender-window cases across all
  speeds preserve scheduler reactions, queued escorts, diplomacy/Council records,
  AI plans, fog memory and event cursors; queued movement does not run twice.

## Remaining before calling the full release complete

- [ ] Extend real multi-computer tests to overlapping war-component merges and
  peace splits, including disconnected participants and no duplicate resets.
- [ ] Measure late-game large-map rendering, simulation and network payload costs
  together; early Vast tests and small-map tournaments have narrower coverage.
- [ ] Verify the final flows on target-server CC:Tweaked and physical advanced
  monitors. Native emulation does not establish Minecraft server tick behavior,
  real modem range/latency, touch hardware or recurrence-free normal play.
- [ ] Finish release metadata/version and final documentation/PR review after the
  remaining checks. No release tag, final release or automatic PR merge is implied.
