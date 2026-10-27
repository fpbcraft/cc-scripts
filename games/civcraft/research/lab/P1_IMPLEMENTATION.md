# Approved P1 prototype

Implemented on `codex/civcraft-p1-balance` after the user approved P1.
The specific H1 healer change is also retained. P2–P4 remain unapproved.

New live lobbies select the P1 economy; Campaign Options can choose Original.
The selected `contentRules` version persists in the campaign and observer
projection. Missing versions remain the original economy. Baseline content
definitions remain available, so existing saves retain their original prices,
science and Farm requirements. Laboratory configs select `contentRules="p1"`
explicitly; omitted lab configs retain their historical baseline behavior.

P1 uses ordinary center science 2, Scholar +1 in the original capital,
Scout/Guard production 15/20, Settler 40 + 12 per previously trained Settler,
and the 15-industry Farm available immediately with one food and a second
after Agriculture. Population costs, technology costs, combat and upkeep are
unchanged. In particular, the higher Settler production does not silently
increase its upkeep.

Ponder Research, Tend Crops and Trade Contract are repeatable production
projects requiring Library, Farm and Market respectively. They convert industry
at 4:1 science, 2:1 city food and 2:1 gold. Each retains its own bounded integer
remainder. Switching retains construction progress. Ponder pauses without
eligible unfinished research, retaining its remainder without stockpiling
industry. Food participates in growth; Trade gold is credited before upkeep.
The forecast treasury includes expected Trade output without counting it twice
at resolution.

The inspector lists the projects, next-round output, remainder and paused
state. Codex and research descriptions distinguish immediate Farm availability
from Agriculture's improvement. Wonders and natural-site categories remain
available. AI ranks repeatables as marginal output and reconsiders them each
turn; they do not inherit the finish-current-construction lock.

Validation before PR preparation:

- 56 CivCraft Lua regression scripts passed, including P1, frozen lifecycle,
  installed-loader dependencies, legacy migration, actions, UI and save tests.
- 20 existing Python lab/proposal/composition tests passed. Three additional
  P1 tests pass through action/round boundaries, including checkpoint replay
  and rejection of projects in original-economy campaigns.
- Native P1 semantic and real `Saves.writeFile`/`Saves.load` checks pass,
  preserving the economy version, project remainder and paused construction.
- Native hotseat and host/AI scripted sessions pass through the private loader.
- One P1 Forge policy match reaches victory at round 115 with exact full-state
  native/Lupa parity. This is conformance evidence, not a balanced opening,
  faction or victory-rate claim.

The native semantic profile was
`/var/folders/jc/y2kx8rr53mn1tk5s2n8ybv140000gp/T/civcraft-p1-semantics-cci1w8pm`.
The full-match result is [recorded here](results/p1_full_policy_native_parity.json).
Post-merge/review checks and CI status must be reported separately.

Human early/mid/late pacing review and broader paired candidate evaluation
remain necessary before treating these prototype numbers as selected balance
values. Known hostile-captured-Settler failures remain errors, and no trained
AI or P2–P4 mechanics are deployed by this prototype.
