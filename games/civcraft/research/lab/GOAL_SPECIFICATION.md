# CivCraft — Evidence-Based Gameplay Redesign, AI Research & Balance Laboratory

## Mission

Conduct an in-depth, empirical investigation of CivCraft's **balance, pacing, strategic diversity, civilization identities, AI quality, and player experience**, using **Civilization VI** as a major reference for what makes a 4X game compelling. Then identify verified issues, develop a coherent high-level redesign, and produce an implementation-ready plan to fix them.

In parallel, **design and, where necessary to gather genuine evidence, prototype a permanent simulation and machine-learning research platform** that can run large batches of authentic CivCraft games, discover strong and adversarial strategies, evaluate civilization balance, and train improved AI policies for eventual deployment in CC:Tweaked.

This is a research, measurement, simulation, and **planning-first** initiative—not permission to immediately rebalance the live game. Behavioral changes to gameplay should wait for review of the findings and roadmap. Behavior-preserving refactoring, test harnesses, instrumentation, and proof-of-concept training infrastructure are allowed if needed to produce real measurements.

## Core design objectives

1. **Compelling pacing:** Civilization-like progression, worthwhile decisions throughout early/mid/late game, satisfying game length and milestone timing. Moving closer to Civ VI's pacing is welcome when justified.
2. **Strategic depth and diversity:** Expansion, concentrated development, science, industry, military, diplomacy, and relevant alternate victories should involve meaningful trade-offs. No one build order or play style should dominate regardless of context.
3. **Fair asymmetric civilizations:** Under comparably strong play, each civilization should have approximately equal overall winning potential, accounting for matchup, position, map, player count, and uncertainty. They need not be equally strong in every situation.
4. **Forgiving but skillful:** Moderate mistakes should create disadvantages, not routinely cause an irreversible early defeat. Consistently poor decisions can and should lose. Avoid opaque, excessive rubber-banding that punishes good play.
5. **Distinct, capable AI:** Different personalities and difficulty levels should arise primarily from decisions, planning, and competence—not arbitrary resource cheats. Strong agents must also expose gameplay exploits.
6. **Minecraft identity:** Large changes to mechanics and content are allowed—including adding, replacing, reworking, or removing units, buildings, technologies, wonders, victory conditions, and systems—but maintain CivCraft's Minecraft/modded-Minecraft/Create theme and respect CC:Tweaked constraints.
7. **Reproducibility:** Important conclusions must be supported by actual data, runnable experiments, documented assumptions, and repeatable results.

---

## A. Audit the real current implementation

Inspect **the checked-out repository/branch**, not assumptions from previous plans or old documentation. Map current behavior and dependencies, including match setup; world generation and starting positions; city growth and tile work; resources and yields; production, upkeep and trade; tech progression; military movement and combat; villages, mobs and diplomacy; victory routes; content definitions; AI; turn order; fog-of-war; saves; multiplayer and UI interactions.

The existing `games/civcraft/` structure has contained modules such as `game.lua`, `systems.lua`, `world.lua`, `combat.lua`, `economy.lua`, `victory.lua`, `content.lua`, and `ai.lua`. Verify actual files, interfaces, rules, and test coverage at the checked-out revision before designing changes. Identify where UI, filesystem, timer, network, and CraftOS dependencies are mixed with authoritative mechanics.

Build a structured inventory of every civilization, unit, building, wonder, technology, ability, and victory requirement. Trace the actual values and effects, not just descriptions. Identify inconsistencies between source code, player-facing documentation, and implementation.

## B. Compare CivCraft and Civilization VI in depth

Use verifiable Civ VI mechanics, published references, and observed CivCraft behavior. Distinguish factual comparison from an inferred design principle. Do **not** imply direct numerical parity is meaningful where the games' scales differ.

Investigate:

- Overall turn counts, era transition times, progression curves, endgame length and decision frequency.
- Opening choices, expansion tempo, city specialization, trade-offs between infrastructure and military, and payoff horizons.
- Population, food, industry, research, gold, strategic resources, technology unlocks, and compounding economic growth.
- Unit movement, combat, defenses, sieges, war duration, logistics, tactical importance of terrain, and wartime turns.
- Wonders, special abilities, unique units/buildings, technology paths, and whether content creates genuine decisions or dead choices.
- Victory paths, interaction among strategies, counterplay, runaway leaders, catch-up opportunities, and game-ending predictability.
- Player-count effects, geography, difficulty, AI personalities, and multiplayer dynamics.
- What to **adopt, adapt, simplify, or intentionally reject** from Civ VI because of Minecraft themes and ComputerCraft limitations.

Do not assume Civ VI is perfectly balanced. Treat it as a pacing and design reference, not a mathematical target.

## C. Quantitative baseline and diagnostics

Before recommending significant balance changes, obtain a baseline using a combination of static/formula analysis, existing tests, controlled experiments, automated matches, game telemetry, and representative manual play where appropriate.

Collect at least:

- Game duration, victory type, winner/ties, turn of decisive milestones and approximate player elimination.
- City counts, population, expansion timing, production and science per turn, treasury, resources, technologies, buildings, units, combat power and losses.
- Per-era decision opportunity and utilization, idle turns, unchosen content, investment efficiency and opportunity cost.
- Leads and reversals at fixed checkpoints; estimated win chances given state; runaway-lead incidence; paths back into contention.
- Results by civilization, AI policy, decision quality, map preset, starting position, opponent composition, difficulty, and player count.
- Execution time, turn costs, simulator throughput, and stability.

Define operational metrics **before** running the decisive experiments. Distinguish experiments, plausible hypotheses, and confirmed findings; provide sample sizes, effect sizes, uncertainty intervals, seeds, code version, limitations, and known confounders. Do not claim an empirical conclusion from an unexecuted simulation or from AI incapable of using the relevant mechanics.

---

## D. Build a faithful, headless CivCraft simulation engine

The simulation framework must become a permanent tool. **There must be one authoritative gameplay implementation**: the real CraftOS game and native/offline simulator use the same Lua rules, not independently reimplemented approximations.

### Recommended separation

- **Shared deterministic engine:** match initialization, action validation/application, turn resolution, game-state transitions, victory, observation generation, and controllable RNG; no rendering/network/real-time dependencies.
- **CraftOS adapter:** actual UI, input, rednet multiplayer, persistence, audio, timing, and platform integration.
- **Headless Lua runner:** runs whole games as fast as possible without rendering, waiting, saving each turn, or depending on Minecraft.
- **Experiment orchestrator:** Python can schedule match configurations, parallel native-Lua workers, training jobs and parameter sweeps; do not round-trip to Python for each tiny action unless performance justifies it.
- **Analysis and reporting:** CSV/JSONL initially, columnar storage/SQL if scale requires; statistical analysis, plots, tables, Markdown/HTML reports.

Extract existing match lifecycle code as needed without changing player-visible mechanics. Define stable interfaces such as `newGame(config)`, `observe(state, playerId)`, `legalActions(state, playerId)`, `applyAction(state, playerId, action)`, `endTurn(state, playerId)`, `isFinished(state)`, and `metrics(state)`. These are proposed APIs, not assumed existing ones.

**Critical correctness conditions:**

- All policies, including automated policies, act through the **same validated action semantics** as human players. No free resources, extra moves, direct illegal state mutation, or inaccessible information.
- `observe` respects player visibility/fog of war; privileged full-state access exists only for offline diagnostics and clearly labeled oracle tests.
- Seeded world generation, stochastic events, agent sampling, and ties are deterministic and reproducible for a given experiment version/configuration. Control random streams and state iteration ordering where necessary.
- Define policies for timeouts, infinite loops, action budgets, invalid actions, draws, and genuine elimination.
- Support 2–4 players initially (matching current rules if applicable), all civilization combinations including mirror matches, mixed policies, varied skills/difficulties, and diverse maps/seeds.
- Write **differential/conformance tests**: replay identical initial states and ordered actions through CraftOS-compatible execution and native Lua, asserting equivalent authoritative state transitions and victory outcomes. Validate actual game compatibility and save migration; do not merely test a toy model.
- Preserve performance and memory limits in CraftOS. Any deployed shared-engine changes must continue to work on target computers and monitors.

### Experiment design

Use controlled, reproducible seeded experiments. Rotate civilizations, policies, and seating/starting positions on matched maps. Include mirrors and same-policy controls; use holdout seeds not seen during training. Report confidence intervals and effect sizes, not only raw win rates. Detect rare but important strategic failures. Separate exploration/training samples from independent evaluation samples.

The system should run scalable batches of complete games and record compact turn-level statistics. Keep full action traces or snapshots selectively for abnormal games and replay. Make a benchmark command capable of running a small deterministic suite in CI and a larger suite locally.

**Hardware assumption:** local experimentation on an **Apple M3 MacBook Pro with 36 GB unified memory**. Optimize for realistic CPU simulation throughput, multi-process workers, efficient data recording, and bounded memory/thermals. GPU/Metal acceleration may help neural training but should be benchmarked, not assumed. Measure games/second and CPU time per turn before promising 10,000+ runs.

---

## E. AI research: evolution, machine learning, and adversarial self-play

Treat AI quality as both a **gameplay feature** and a **measurement instrument**. Poor agents can produce misleading balance conclusions; strong agents can reveal dominant strategies and loopholes.

### E1. Establish a policy API and fixed benchmarks

Define observations, legal action proposals, high-level goals, decision frequency, action budgets, and a unified evaluator. Separate personality from competence. Keep a fixed collection of reproducible baseline opponents and holdout maps, including current AI (as a baseline, not an upper bound). Track agent version, training parameters, and match results.

Start with rule-based agents spanning expansion, economy, science, industry, military, defense, diplomacy, and adaptive play. Improve tactical and operational competence, especially unit movement, settlement, protection, and project switching. Implement *realistic imperfect play* via decision ranking/noise, truncated planning horizon, systematic biases, and controlled mistakes—not unrestricted random illegal actions.

### E2. Evolutionary/black-box strategy optimization first

Implement tunable policy weights, thresholds, priorities, and phase-dependent behavior. Train on seeded tournaments using a suitable optimization method (evolution strategies, genetic algorithms, CMA-ES, or alternatives selected after benchmarking). Evaluate generalization across opponents/maps and guard against optimizing only for mirror matches or a fixed seed pool.

This is the preferred **first ML-assisted implementation** because it can generate stronger, interpretable Lua policies without a GPU and provides immediate empirical value.

### E3. Adversarial league training

Maintain a league of diverse contemporary and archived agents, including generalists, specialists, exploiters, and counters. Train agents against mixtures of opponents, not exclusively the latest champion. Support cross-play and matchup matrices, strategy cycling, historical regression detection, and exploit search.

Use adversarial findings to distinguish:

- **A genuine gameplay balance flaw** (dominates across many competent policies and conditions),
- **An opponent-specific weakness** (one policy fails against a counter), and
- **A simulation/AI exploit** (violating intended rule semantics or exploiting buggy implementation).

Document exploits and retain reproducible replay seeds and action traces.

### E4. Reinforcement learning as a staged research track

Once the engine is fast, validated and instrumented, prototype a Gymnasium-compatible interface. Consider action-masked PPO or another method selected by actual benchmarking. Prefer **hierarchical policies**: a learned strategic controller chooses goals (expand, specialize, research, defend, attack, pursue victory), while deterministic Lua tactics handle legal actions, pathfinding, and detailed micro. Full-game learning directly over every mouse-equivalent action is unlikely to be cost-effective.

Start with small or shortened scenarios, curriculum learning, clear reward design, multi-agent self-play, and held-out evaluations. Avoid reward hacking and optimizing arbitrary proxy scores at the expense of actual victories. Compare learned policies against strong evolutionary and heuristic baselines; **do not require neural RL if it does not outperform simpler methods**.

True perfect play is not realistically provable for this game. Estimate increasingly strong play through league competition, optimization, search, and cross-play while reporting the limits of that estimate.

### E5. Export small policies to CC:Tweaked

Training may use expensive Python/ML workloads, but in-game inference must be **fully offline, deterministic within an explicit RNG policy, small, fast, and compatible with Lua/CraftOS**.

Investigate and compare:

1. Exported heuristic weights, priorities, and thresholds;
2. Distilled decision trees or rule lists trained to imitate stronger agents;
3. Tiny quantized or otherwise compact neural networks evaluated infrequently for strategic decisions.

Require legal-action handling in Lua regardless of policy format. Benchmark deployed agents on target CraftOS constraints, including CPU usage, watchdog/cooperative yielding, memory, turn latency, and performance against the original training model. Measure full-game strength retention after distillation, not merely one-step prediction agreement.

Aim for distinct personalities and multiple meaningful difficulty levels via planning depth, policy quality, learned parameters, or decision noise; avoid difficulty relying solely on resource cheating.

---

## F. ML-assisted simulation and balance optimization

**Never substitute a learned approximate simulator for authoritative balance evidence** without validation against the true engine.

Useful auxiliary ML applications include:

- Win-probability and remaining-game-length prediction from observed match states.
- Identifying states where a lead becomes difficult to reverse and measuring actual recoverability.
- Predicting promising candidate balance configurations as a **surrogate model**, followed by real simulation to validate them.
- Classifying unusual matches, detecting exploits, and prioritizing expensive evaluation runs.
- Sensitivity and multi-objective optimization over costs, yields, growth rates, starting conditions, civ bonuses, and other balance parameters.

Balance optimization must preserve skill expression, strategic variety, distinct civ identities, and Minecraft flavor. Set explicit design constraints and penalize homogenization, degenerate strategies, or major pacing regressions. Do not modify the published gameplay rules automatically during this planning initiative; produce recommended candidates and validating evidence.

**Nested evaluation is essential:** when game parameters change, agents may need adaptation or retraining before conclusions are valid. Test against a combination of fixed baseline policies, adapted strong policies, and independently trained/held-out agents. Otherwise changes can merely exploit current AI blind spots.

---

## G. Quantify fairness, pacing and mistake tolerance

Develop measurable, context-aware acceptance targets, then calibrate actual thresholds based on baseline and player experience.

- **Civilization balance:** estimate expected win chance of each civ under *comparably strong* play. For symmetric four-player evaluation, 25% is a reference chance, **not** a guarantee or universal target across heterogeneous matchups. Use position rotations, matchup controls and uncertainty intervals; avoid only aggregate analysis.
- **Strategic diversity:** measure the competitive performance and counterplay of several distinct strategies. Track collapse into a single dominant build order.
- **Skill differentiation:** test whether stronger policies reliably outperform weaker ones on balanced conditions, while preserving meaningful games rather than overwhelming early eliminations.
- **Recoverability:** build counterfactual experiments from identical checkpoints: compare optimal continuation with plausible moderate mistakes (delaying a settler, suboptimal building, inefficient research, a poor defensive decision). Track win-probability impact and time to recover. Distinguish one moderate error from sustained incompetence.
- **Runaway leads:** measure the probability that a leader at each checkpoint ultimately wins; identify when games are functionally decided and how long the remaining turns last.
- **Pacing:** compare time to first expansion, economy acceleration, age transitions, military contact, meaningful wars, victory contention and game conclusion, normalized to meaningful Civ VI design patterns where appropriate.
- **Difficulty fairness:** ensure AI levels differ in meaningful decision quality rather than arbitrary and unexplained bonuses.

Never optimize the entire game to a single metric; victories, variety, skill, uncertainty, and fun can conflict. Explain trade-offs.

---

## H. Diagnose problems and design substantial improvements

Create a prioritized issue register. Every major finding must include **symptom, evidence, suspected/verified root cause, affected matchups, severity, alternatives, preferred remedy, trade-offs, and validation experiment**. Label issues as confirmed versus hypotheses needing more tests.

Prioritize systemic causes such as production scaling, expansion incentives, research snowballing, economic compounding, weak defensive counterplay, overly rigid tech progression, underpowered victory paths, insufficient interactions, and AI-specific weaknesses. Do not automatically nerf the visible winning unit when a deeper system causes dominance.

Propose a coherent high-level redesign allowing large content and rules changes. Maintain Minecraft and modded-Minecraft/Create identity, avoid needless complexity, and retain strong pacing. Describe why each major mechanic from Civ VI is worth adapting or avoiding.

Then produce a **detailed, phased implementation plan**, with concrete proposed mechanics/formulas/values where justified; prerequisite refactors; data migrations; implications for AI and UX; test strategy; experimental acceptance criteria; dependencies; risks; and rollback/replay strategy. The implementation roadmap should be specific enough for later Codex tasks and PRs.

---

## I. Deliverables and repository documentation

Create maintainable, linked Markdown documents in an appropriate repository documentation folder, including at least:

1. `CURRENT_STATE_AUDIT.md` — verified mechanics, content inventory, action lifecycle, and architectural audit.
2. `CIV6_COMPARISON.md` — sourced comparative analysis and pacing/design principles.
3. `SIMULATION_ARCHITECTURE.md` — shared engine interfaces, CraftOS parity, deterministic execution, experiment runner and performance approach.
4. `AI_ML_RESEARCH_PLAN.md` — agent interface, evolutionary training, adversarial league, RL experiments, deployment/distillation, compute requirements and validation gates.
5. `EXPERIMENT_PROTOCOL.md` — factorial/paired experimental design, sample size, holdouts, bias/confound handling and statistical methods.
6. `BASELINE_BALANCE_REPORT.md` — **actual executed results** with caveats, figures, distributions, measurements, commands, seeds, and versions.
7. `BALANCE_ISSUES.md` — ranked issue register with links to empirical evidence.
8. `REDESIGN_PROPOSAL.md` — coordinated high-level changes, alternatives, expected improvements and trade-offs.
9. `IMPLEMENTATION_ROADMAP.md` — detailed phase/task breakdown, acceptance criteria and dependencies.
10. `CONTINUOUS_BALANCE_TESTING.md` — local runs, CI smoke suite, larger tournaments, regression thresholds and reproducibility.

Add or update reproducible scripts, fixtures and test harnesses when necessary. Keep raw results or compact machine-readable aggregates and an exact reproduction procedure. Avoid committing enormous generated datasets, trained-model binaries, or noisy traces by default; document where artifacts are stored. Provide charts and summary tables when helpful.

If a full simulation or training phase exceeds the practical budget, run a **valid, bounded experiment**, report its scope honestly, and document the precise next commands and additional evidence required. A short real experiment is better than fictional large-scale results.

---

## J. Execution order and boundaries

**Stage 1 — Audit & reference research.** Inspect current code and tests; inventory rules/content; research Civ VI's relevant gameplay and pacing; define baselines and questions.

**Stage 2 — Measurement-ready engine.** Design and perform only necessary *behavior-preserving* extraction/instrumentation; build and validate a deterministic headless vertical slice against real CivCraft rules and existing tests. Establish preliminary game-throughput benchmarks on an M3/36 GB-class environment if available; otherwise provide runnable benchmarks, with no invented timings.

**Stage 3 — Representative agents & baseline.** Establish original and simple specialist baselines; run controlled seeded matches; evolve tunable policies; demonstrate that improved policies learn and generalize on held-out matchups. Identify measurement blind spots.

**Stage 4 — Adversarial/ML design and targeted prototypes.** Plan and, where feasible, prototype a cross-play league, archived policies and exploiters. Evaluate whether hierarchical RL and Lua policy distillation are worthwhile using bounded evidence rather than presupposing neural models are better.

**Stage 5 — Diagnosis & high-level redesign.** Analyze actual runs, Civ VI differences, and systemic dynamics. Distinguish actual game imbalance from underdeveloped policies. Produce prioritized findings and design alternatives.

**Stage 6 — Detailed roadmap.** Translate the preferred solution into implementation-ready changes with acceptance tests, including continued AI learning and balance regression testing.

### Important boundaries

- **Do not implement the actual gameplay rebalance or major new content in this phase.** Design it thoroughly first for review.
- **Behavior-preserving engine extraction, tests, telemetry, benchmark tools, and limited simulation/ML prototypes are authorized** when required for meaningful empirical research. Preserve existing saves, gameplay behavior, multiplayer and CraftOS operation; test any changed infrastructure thoroughly.
- Do not silently rewrite the AI as a gameplay release in this research stage; development/training policies can remain offline until their intended deployment is reviewed.
- Make trade-offs and unresolved questions explicit. Avoid speculative claims about optimal play, Civilization VI's behavior, measured throughput, or agent strength.
- Preserve existing user-facing design decisions and project's current theme unless the redesign explicitly discusses and justifies changing them.

## Definition of success

At the end of this initiative, we should understand **which parts of CivCraft actually underperform, why, how strongly the evidence supports that, and exactly what to change**. We should also possess a credible, validated path to repeatable headless simulations, adversarial/ML-driven AI improvement, and deployable compact Lua policies—so future balance changes can be tested rather than guessed.

The ultimate optimization target is **a more engaging strategy game**, not merely equal-looking win-rate numbers.
