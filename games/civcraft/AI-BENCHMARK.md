# AI integration benchmark

Measured on 26 October 2026 with Lua 5.3 (Lupa), on `codex/civcraft-roadmap`.
The generated-data tournament uses Compact/Pangaea maps without wilderness mobs,
all five AI tiers against Prince, and both starting seats. Each cohort reaches
its 100-round deadline or an earlier enabled victory. Civilizations keep their
normal bonuses, costs and fixed personalities. Results are deterministic samples,
not confidence intervals or proof of a universal difficulty ranking.

[Per-match measurements](AI-BENCHMARK.csv) preserve scores, research/city counts,
winners, reasons, command counts and timings. Wall-clock timings were taken under
concurrent validation load and should not be treated as isolated performance
comparisons between tiers.

| Seed | Matchup | Orders | Host denials | Worst actor |
|---|---|---:|---:|---:|
| 75123 | forge vs forge | 12,921 | 24 | 78 ms |
| 95117 | scholar vs iron | 13,547 | 29 | 70 ms |
| 18731 | iron vs scholar | 13,483 | 13 | 69 ms |
| 47771 | merchant vs sentinel | 13,249 | 33 | 125 ms |
| 99119 | nomad vs mariner | 16,268 | 31 | 194 ms |
| 61283 | wild vs highland | 14,165 | 27 | 133 ms |

All sixty matches completed: 83,633 shared-action orders, 157 expected
host denials (156 unseen completed-wonder attempts and 1 moves legal in
observed state but blocked in authoritative state), and no unexplained rejection.
The diagnostic comparison uses full state only in the test harness. Planning
never receives the hidden obstruction or rival's construction location.

Long runs found two avoidable behaviors: repeated rejected wonder production and
settlement steps unaffordable by an attached escort. The AI now records a bounded
production retry cooldown from its own command feedback, and checks shared
observed reachability before issuing settlement travel. Regression tests cover
cooldown expiry/migration and preserving an escorted settler's destination.

A separate native CraftOS-PC 2.8.3 sixty-round matrix runs ten Miners/Scholars
matches on seed 18731: 8,057 orders, zero rejections, 220 ms maximum actor and
33 ms maximum cooperative collection pause. Native monitor-touch full-session
validation and all 83 regression scripts also pass.

Reproduce with `tests/civcraft_ai_matrix.lua 100` in the documented isolated test
environment. `tests/civcraft_ai_tournament.lua` can run individual cohorts. See
[NATIVE-TESTS.md](NATIVE-TESTS.md). More seeds, map sizes, mobs and full-duration
campaigns remain useful balance coverage; this matrix does not establish a release
or physical Minecraft-server performance.
