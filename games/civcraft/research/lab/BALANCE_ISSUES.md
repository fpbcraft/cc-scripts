# CivCraft balance issue register

**Evidence revision:** frozen HEAD `97944b8bc85e011d00abbdf45bf9aecdb82050ae`; current working tree also contains the parent’s uncommitted behavior-preserving lifecycle extraction.
**Method:** source inspection plus existing test/harness inspection. No live gameplay rules were changed. Findings tied to the original coupling are labelled as frozen-HEAD gaps; current extraction/parity evidence is called out separately.

Each entry follows the required register: symptom, evidence, root cause, affected matchups, severity, alternatives, preferred remedy, trade-offs, and validation experiment. “Confirmed” means the implementation behavior is established; it does not mean the player-experience impact is already effect-sized.

## BAL-00 — Standard-hostiles captured settler causes a deterministic runtime crash (CONFIRMED runtime integrity bug; P0 experiment blocker)

**Symptom.** A standard-hostiles match can abort on round 15 instead of producing a result. This is an engine error, not a civilization loss, and must be excluded from win-rate or pacing scoring.

**Evidence.** The standalone native fixture [`reproduce_hostile_capture.py`](reproduce_hostile_capture.py) uses the shared `engine.newGame`, `Engine.pump` and `Engine.advance` path for seed 95117, compact Pangaea, standard hostiles and Forge-v-Forge. The raw result is [`hostile_capture_reproduction.json`](../../../../tools/civcraft_lab/results/hostile_capture_reproduction.json): CraftOS-PC 2.8.3 reports `games/civcraft/hostiles.lua:103: table index is nil` at `errorRound=15`, after `completedRounds=14`. Immediately before the error, unit 22 is `{kind="settler", owner=-2147483647, spawner=nil}`. The archived Lupa pilot independently reported the same line for seed 95117 Forge-v-Forge and Scholar-v-Iron; Lupa was not installed in this reproduction environment, so the fresh runtime proof is native only.

**Root cause.** Confirmed invariant violation. Hostile units are counted in `games/civcraft/hostiles.lua:97-105`, where every unit with `owner == H.owner` is indexed by `per[u.spawner]` at line 103. Hostile spawning normally supplies `spawner=s.id` at `hostiles.lua:125-137`. Combat’s captured-settler branch (`games/civcraft/combat.lua:372-376`) calls `Stacks.capture`, which changes ownership and clears settler AI fields but does not assign hostile spawner metadata (`games/civcraft/unit_stacks.lua:148-161`). The reproduced hostile-owned settler therefore reaches the next hostile round with a nil spawner and crashes during the per-spawner count.

**Affected matchups.** Any standard/dangerous-hostiles match in which a hostile unit captures a settler; the known seed/configs are Forge-v-Forge and Scholar-v-Iron at seed 95117. Policies that expose settlers early or permit hostile contact are more likely to reach the path.

**Severity.** P0 for runtime integrity and the balance lab: the run has no valid winner, victory turn or pacing trajectory. It is not evidence that Forge or the affected opponent lost, and it is not a direct balance-severity rating.

**Alternatives.** (A) preserve hostile spawner metadata through capture; (B) exclude captured settlers from the hostile-owned mob list and define their conversion/cleanup; (C) convert the captured settler to a normal player-owned unit or remove it; (D) reject/forbid hostile settler capture. A preserves the smallest behavior surface but may retain unusual hostile semantics; B/C clarify ownership at the cost of migration rules; D is safest for stability but changes counterplay.

**Preferred remedy.** Keep the bug unfixed pending gameplay design review. First decide whether a captured settler should remain a hostile entity, be converted, or be removed; then add the smallest invariant-preserving implementation and a regression fixture. Until then, classify this path as `error`, never as a win/loss or censored match.

**Trade-offs.** Any repair changes unit ownership, fog, settlement potential, hostile caps or future spawn pressure. A narrow nil guard would prevent the crash while silently leaving undefined semantics, making it unsuitable as the final gameplay fix.

**Validation experiment.** Re-run the native fixture and both historical failing configs, assert no uncaught exception through round 180, inspect the captured unit’s owner/spawner/settlement behavior, and compare hostile counts before/after. Add Lupa/native parity for the capture boundary, then hold out hostile seeds and verify `error=0`; report infrastructure errors separately from route wins and losses.

## BAL-01 — No elimination lifecycle (CONFIRMED implementation gap; HIGH)

**Symptom.** A civilization that loses all cities may still be a required participant in the round/readiness cycle, with no explicit defeat state or elimination timestamp.

**Evidence.** Combat removes defeated units and captures cities but does not remove or mark the owning player (`games/civcraft/combat.lua:337-388`). Victory iterates every `state.players` entry (`games/civcraft/victory.lua:68-99`), while `Scheduler.complete()` requires every participant to be ready (`games/civcraft/turn_scheduler.lua:155-164`). Repository search at this revision finds no live `eliminated`/`defeatedRound` transition in `games/civcraft/`.

**Suspected/verified root cause.** Verified missing lifecycle state. Whether the UI becomes visibly stuck depends on the exact defeated state (remaining units, local/remote seat, and enabled victories), so that player-facing symptom is still a hypothesis until a fixture is run.

**Affected matchups.** Any conquest/war game, especially 3–4 player games where one seat is conquered before another victory; hotseat and rednet games are most exposed.

**Severity.** High for game pacing and multiplayer fairness; low for a match that ends immediately by conquest.

**Alternatives.** (A) Keep a ghost participant who can only observe; (B) mark eliminated and exclude from readiness, economy, AI and victory qualification while retaining a public observer; (C) remove the player and transfer its remaining units/territory. A is simplest but can preserve dead-seat turn friction. C has the largest diplomacy/fog/save consequences.

**Preferred remedy.** Add an explicit authoritative `eliminated`/`eliminatedRound` lifecycle and define exactly which scheduler, victory, snapshot, diplomacy, save and observer paths exclude or preserve it. Keep the seat visible as eliminated rather than silently deleting identity.

**Trade-offs.** New save/schema migration and network/UI states; clearer pacing and no dead-seat ambiguity. Removing a player can alter score, diplomatic delegates and conquest timing, so it must be specified before balance tuning.

**Validation experiment.** Build a deterministic fixture with two capitals and a surviving unit, capture/destroy one capital, then assert: the defeated player cannot issue economic/military orders; `Scheduler.complete()` ignores it; observer snapshots show eliminated but redact private state; all enabled victories resolve; save/reload preserves status; 2/3/4-player hotseat and rednet variants terminate without waiting.

## BAL-02 — Overflow is discarded at research and project completion (CONFIRMED; MEDIUM/HIGH)

**Symptom.** A high-science player or high-industry city loses any output beyond the cost on the completion round. The next technology/project starts at zero unless it had previously retained progress.

**Evidence.** Research adds `totalScience` and, on `progress >= cost`, unlocks and clears the target without carrying `progress - cost` (`games/civcraft/systems.lua:853-864`). Production adds industry, completes the project, clears it, and never applies excess output to another project (`games/civcraft/systems.lua:795-832`). Queue switching does retain prior per-project progress (`games/civcraft/systems.lua:394-431`; `tests/civcraft_actions_test.lua:164-180`), so this is not a claim that switching opportunity cost disappears.

**Suspected/verified root cause.** Verified intentional/simple completion branch; balance impact is a hypothesis.

**Affected matchups.** Scholar/high-science versus low-science; Forge/Iron or late rail/industrial cities versus generalist cities; fast/epic speeds and wonder races where per-turn output is large relative to cost.

**Severity.** Medium for ordinary pacing; potentially high for endgame race outcomes if one completion consumes a large fraction of a turn’s output.

**Alternatives.** (A) Preserve current sink; (B) carry overflow to the next selected target; (C) cap carryover (for example one target’s cost) to prevent chains; (D) convert excess to a bounded stockpile/bonus. A is simplest; B improves smoothness but can make snowballs sharper.

**Preferred remedy.** Do not change live rules until measured. Compare current sink with bounded carryover in matched trajectories; if carryover wins, cap it and record each completion/overflow in telemetry.

**Trade-offs.** Carryover reduces feel-bad waste and shortens late queues, but increases compounding output and can make high-yield civs more dominant. A sink preserves discrete decisions but creates timing cliffs.

**Validation experiment.** Construct identical 1/3-city states at science/industry rates that overshoot costs by 1–100 output. Compare turns to first/second tech and unit/building, idle rounds, civ win probability and lead reversal under current AI and a competent fixed-policy adapter. Repeat quick/standard/epic and hold out seeds.

## BAL-03 — Speed changes cost/deadline but not opening stores/yields (CONFIRMED design asymmetry; MEDIUM)

**Symptom.** Quick/standard/epic are not pure tempo rescalings: costs and round limits change, while start `food=12`, `wood=12`, `science=0`, capital population/jobs and base yields remain unchanged.

**Evidence.** Speed presets are factors 2/3, 1, 3/2 with 120/180/270 round limits (`games/civcraft/campaign_rules.lua:1-8`); cost scaling is centralized (`campaign_rules.lua:32-35`). Starting state is fixed in `games/civcraft/game.lua:206-227`; yields and growth threshold/minimum use the factor in `games/civcraft/systems.lua:507-527,601-625`.

**Suspected/verified root cause.** Verified asymmetry. Whether it is undesirable is a hypothesis.

**Affected matchups.** All civs, especially early science Scholar and early-industry Forge/Iron; opening expansion versus research/production choices on quick and epic.

**Severity.** Medium: it can change the identity of a speed preset and confound balance comparisons.

**Alternatives.** (A) Keep Civ-style cost/deadline scaling only; (B) also scale opening stores and/or initial worker output; (C) define speed as a separate pacing mode with explicitly tuned milestone targets; (D) remove speed from balance claims and benchmark each preset independently.

**Preferred remedy.** Treat each speed as a separately calibrated ruleset for now. Before tuning civ bonuses, measure first growth, first tech, first unit, first settler, age milestones and first contact on all three speeds.

**Trade-offs.** Separate calibration increases content/test burden but avoids assuming linearity where none exists. Scaling starts may make quick more playable but can erase meaningful opening choices.

**Validation experiment.** Same seed/map/civ/policy across quick/standard/epic, with 30–40-turn traces and milestone timing normalized by configured round limit. Compare to current standard baseline and player-perceived action density; do not infer from cost arithmetic alone.

## BAL-04 — Inert/incomplete horse and saltpeter resource layer (CONFIRMED data mismatch; MEDIUM)

**Symptom.** Player-facing strategic-resource concepts include horse/saltpeter, but the live data path does not make them complete strategic choices.

**Evidence.** `content.lua:674-684` defines `horses` and `saltpeter` but omits both from `resourceOrder`. The worldgen weighted list includes horses but not saltpeter (`worldgen.lua:284-295`). Horseman has no `resource` field (`content.lua:352-362`), and exchange rejects both IDs (`economy.lua:90-128`). The encyclopedia/README still describe owned horses/saltpeter deposits as strategic (`games/civcraft/encyclopedia.lua:101`; `games/civcraft/README.md:300,411`).

**Suspected/verified root cause.** Verified content/UI/legacy mismatch. No claim is made that this currently changes win rate; the unused choice is the confirmed issue.

**Affected matchups.** Horseman openings, map-resource contests, and any future gunpowder/saltpeter branch; resource-focused AI versus generalist AI; resource map-type comparisons.

**Severity.** Medium for strategic diversity and player trust; low if these are deliberately legacy-only fields.

**Alternatives.** (A) Remove/retire the dead IDs and update docs/UI; (B) wire horse gates and a real saltpeter-era unit branch; (C) keep deposits as yield-only exploration content. B creates meaningful map/diplomacy choices but needs generation guarantees and counterplay.

**Preferred remedy.** Decide explicitly whether horses/saltpeter are live mechanics. If live, add them to ordered UI/telemetry, gate the intended units, generate/guarantee fair deposits, and test exchange/stockpile semantics. If not, remove them from strategic claims and benchmark content.

**Trade-offs.** Wiring resources adds asymmetry and possible start unfairness; removal reduces content but makes the rules legible and avoids false strategic signals.

**Validation experiment.** Export all runtime content and generated deposits over 100 holdout seeds; assert every strategic resource is (1) generated, (2) visible in the resource UI/order, (3) consumed or otherwise used by at least one legal action, and (4) reachable/counterable in 2–4-player maps. Then test horse/no-horse and saltpeter/no-saltpeter matchups.

## BAL-05 — Headless/conformance boundary is newly extracted but incomplete (PARTIALLY ADDRESSED; HIGH for measurement)

**Symptom.** At the audited HEAD, balance experiments could not call a stable authoritative engine API or replay the same state/actions through CraftOS and a native runner. The current working tree improves this by extracting match and actor lifecycle seams, but it still lacks the full public experiment contract and broad replay coverage.

**Evidence.** Frozen HEAD `game.lua` owns initialization, state, save, round resolution, UI dispatch, rednet server/client, publish/snapshot flow and the event loop (`game.lua:1-130,130-240,273-379,380-508,1010-1135,1215-1245`). Current uncommitted `match_lifecycle.lua:23-158` now exposes lobby initialization, map setup, round advancement and finish; `actor_lifecycle.lua:13-71` exposes actor pumping while preserving `Actions.apply()`. `/tmp/civcraft-lab-native-parity.json` reports all 36 state/observation checks equal across 2- and 4-player, three-round peaceful fixtures, including accepted research and rejected orders. The spec’s complete `newGame/observe/legalActions/applyAction/endTurn/isFinished/metrics` contract is still not present, and no wartime full parity has been run.

**Suspected/verified root cause.** The original architectural coupling is verified at frozen HEAD; the parent’s extraction addresses setup/round/actor seams. Remaining gaps are an incomplete API/metrics contract and untested wartime/save/network/victory parity, not evidence that the extraction is incorrect.

**Affected matchups.** Every balance claim, especially multi-seed civ matrices, elimination, victory timing, and adapted AI policies.

**Severity.** High for the research initiative; otherwise no direct player-visible severity.

**Alternatives.** (A) Wrap the existing `game.lua` with a test adapter; (B) extract a shared pure engine while preserving CraftOS adapter behavior; (C) maintain a second simulator. C is fastest initially but risks rule drift and is contrary to the spec.

**Preferred remedy.** Continue the behavior-preserving extraction around observer projection, legal-action enumeration, victory, metrics, action budgets and save/replay. Keep CraftOS UI/network/save adapters thin. Extend differential replay to wartime scheduler reactions, all victory paths, save/reload and live network projection before any rebalance.

**Trade-offs.** Refactor risk and test work now; major reduction in false balance conclusions and ability to run held-out policy tournaments later.

**Validation experiment.** Preserve the passed 2/4-player, 3-round parity fixture as CI coverage. Add seeded war graphs, Surprise War reactions, save/reload, each victory route, 2–4 player observation projections and rednet snapshots; assert authoritative state, observer view and victory reason/turn after every boundary.

## BAL-06 — No explicit action-budget/timeout/elimination policy for full-game AI experiments (CONFIRMED platform gap; MEDIUM/HIGH)

**Symptom.** AI work is bounded locally by loops and cooperative checkpoints, but the game-level experiment contract does not define invalid-action budgets, global turn/action caps, infinite-loop handling, or what happens when a policy cannot act.

**Evidence.** AI tactical/settlement/engineering loops have local limits (`ai.lua:63-124,227-297`), while `Systems.aiTurn()` runs multiple phases and calls actions directly (`systems.lua:872-940`). `Cooperative.checkpoint()` yields and performs GC (`cooperative.lua:24-66`) but is not a match result policy. Existing scheduler completion only checks ready state (`turn_scheduler.lua:155-164`).

**Suspected/verified root cause.** Verified missing experiment-level contract. It is not evidence that current AI can loop forever in normal sessions.

**Affected matchups.** AI-v-AI tournaments, stronger-policy evaluation, eliminated seats, malformed-policy fuzzing, and late-game large maps.

**Severity.** Medium for current play; high for reproducible optimization and ML data quality.

**Alternatives.** (A) Hard fail a match on budget; (B) policy timeout/forfeit; (C) deterministic pass/idle with a diagnostic flag; (D) grant fallback legal action. C preserves game completion but can bias balance if frequent.

**Preferred remedy.** Define a per-action/per-player/per-round budget, invalid-action accounting, timeout result, dead-seat policy, and deterministic fallback. Record these in metrics and never silently classify them as gameplay losses.

**Trade-offs.** Strict budgets make weak policies look worse but reveal competence honestly; fallback passes make datasets complete but can hide policy bugs.

**Validation experiment.** Run deliberately invalid, no-op, overlong and eliminated-player policies on 2–4-player fixed seeds; verify every game terminates with an explicit result and no unauthorized state mutation. Report budget forfeits separately from victories.

## BAL-07 — Victory-route interaction and timing are not yet effect-sized (HYPOTHESIS; HIGH research priority)

**Symptom.** The game exposes five victory routes with materially different prerequisites and timer shapes; current evidence does not establish whether routes create counterplay or one route dominates under strong play.

**Evidence.** Conquest, expedition, industrial, diplomatic and score qualification are implemented in `victory.lua:24-130`. Industrial needs a connected network with three bank cities plus a ten-round timer; expedition is a multi-project Dragon chain; score is a round-limit fallback; diplomatic depends on the current council winner. Existing campaign tests verify route resolution (`tests/civcraft_campaign_rules_test.lua:80-130`), not competitive parity.

**Suspected/verified root cause.** Route definitions are verified; dominance/runaway/recoverability are unmeasured hypotheses. Historical Forge mirror data reached Industrial on round 149 under a no-hostiles compact/Pangaea fixture, but the report is at old commit `c5d7e4df...` and the two seats are deterministic swaps: [`civcraft_full180_prince.json`](../civ6-balance-2026-10-26/civcraft_full180_prince.json).

**Affected matchups.** Science/Scholar versus industrial/Forge/Iron; diplomacy in 2-player versus 3–4-player games; conquest on close versus separated starts; all victory-toggle combinations.

**Severity.** High if confirmed; the game can be mechanically valid yet strategically pointless if routes are not contestable.

**Alternatives.** (A) Tune route costs/timers; (B) add route-specific counterplay and visible progress; (C) temporarily benchmark with one route at a time; (D) leave rules and improve AI competence first. D avoids tuning around weak AI but delays player-facing fixes.

**Preferred remedy.** Measure before changing: route completion turn, first-contender turn, interruption rate, final-lead reversals, and route utilization under competent policies. Tune systemic prerequisites/counterplay rather than only nerfing the historical winner.

**Trade-offs.** More counterplay increases interaction and may lengthen games; shorter routes improve pacing but can reduce strategic runway.

**Validation experiment.** Matched 2/3/4-player mirrors across all civs, rotated seats, holdout seeds/maps, and each victory toggle. Run fixed expansion/science/industry/military/diplomacy specialists plus adaptive policy; report route win rates with confidence intervals and checkpoint recoverability.

## BAL-08 — Historical balance numbers have provenance/sample limits (CONFIRMED evidence limitation; HIGH process priority)

**Symptom.** Existing AI benchmark and balance harness numbers can be mistaken for current-HEAD or strong-play conclusions, even though their arithmetic content values remain useful where source data is unchanged.

**Evidence.** `games/civcraft/AI-BENCHMARK.csv` is documented as a 100-round/Lupa snapshot, while archived native JSON metadata records commit `c5d7e4df...`; this audit is `97944b8b...`. The exported runtime content files are unchanged relative to the audited source, so their counts and listed values are still useful arithmetic evidence; only their provenance hash is historical. The full-180 Forge mirror fixture explicitly says seat swaps are the same deterministic matchup and that the wrapper action counter was zero. The README/native test docs classify tournament outputs as generated-data smoke tests, not win-rate estimates (`games/civcraft/NATIVE-TESTS.md`, tournament section). The new `/tmp/civcraft-lab-native-parity.json` is current-working-tree parity evidence, but only for peaceful 2/4-player three-round traces.

**Suspected/verified root cause.** Verified provenance/sample limitation, not a gameplay defect.

**Affected matchups.** Any report comparing civilizations, AI tiers, victories, city counts, research or pacing from those files.

**Severity.** High for decision quality; low for current player behavior.

**Alternatives.** (A) Keep as historical regression snapshots; (B) rerun exact fixtures at current HEAD; (C) replace with a versioned benchmark matrix and holdout set. A preserves history but is unsafe as current balance evidence.

**Preferred remedy.** Label every result with commit/runtime/fixture/sample caveat; retain unchanged content arithmetic as a reference, and regenerate match outcomes at the current extraction before tuning. Keep old files immutable as regression evidence.

**Trade-offs.** Reruns cost time/CPU, but prevent tuning against stale code or deterministic seat artifacts.

**Validation experiment.** Re-run the same harness at `97944b...`, then add independent seeds, both seat orders, civ mirrors, victory/mode metadata, per-round rates and accepted/rejected action counts. Compare deltas to identify code drift before interpreting balance.

## BAL-09 — Two-player diplomatic victory has structurally weak agency (CONFIRMED arithmetic; HIGH 2-player route concern)

**Symptom.** In a two-player game, a diplomatic specialist cannot normally complete the diplomatic route without the rival’s election vote. The route can therefore be a negotiation/veto test rather than an independently actionable victory path.

**Evidence.** Council membership grants two delegates by default and three with the loyalty bonus (`games/civcraft/council.lua:69-92`). At tally, a candidate needs a strict majority (`council.lua:168-173`), at least two-thirds of allocated delegates (`council.lua:177-180`), and `supporters[candidate]`, which is set only when a *different* member votes for that candidate (`council.lua:155-166`). In a two-player session with the diplomatic candidate’s maximum three delegates and the rival’s two, the candidate’s self-vote is 3/5 = 60%, below the two-thirds requirement; with two delegates each, self-voting is only 2/4 = 50% and fails the strict majority. A rival can veto by abstaining or voting for itself. The route also requires commerce technology and an owned Council Hall (`council_rules.lua:59-74`) and an enabled diplomatic victory (`council.lua:177-183`).

The compact cross-play summary is preserved at [`results/route_crossplay.json`](results/route_crossplay.json), with raw outcomes at `/tmp/civcraft-route-crossplay.raw.json`; both record HEAD `97944b8bc85e011d00abbdf45bf9aecdb82050ae`. All 24 matches finished across two seeds, with 12 `END EXPEDITION` and 12 `INDUSTRIAL` wins and zero `DIPLOMATIC` wins. The 12 matches involving the diplomatic policy seat produced five seat wins, but every one was by another route (industrial), so the summary’s seat `credit` must not be read as diplomatic-route success. The diplomatic policy remained labeled `diplomatic` in final metrics; this is consistent with route switching/alternate qualification, not proof that its council plan succeeded.

**Suspected/verified root cause.** The threshold and supporter arithmetic is verified. The player-impact conclusion is a high-confidence structural hypothesis: 2-player diplomatic progress depends on opponent consent, while current cross-play telemetry does not record ballots, pledges, candidate counts or veto decisions. `council_ai.lua:20-71` can choose another candidate based on relations, eligibility, war and pledges, so observed wins can be sensitive to opponent voting weakness rather than the route’s intrinsic agency.

**Affected matchups.** All two-player diplomatic-specialist games, especially against a rational opponent who abstains/self-votes; 3–4 player games may have a reachable coalition but still depend on delegate/loyalty distribution. Cross-play with the current Forge-only policy league is not a general equilibrium test.

**Severity.** High for 2-player route identity and strategic agency; not evidence that diplomacy is globally impossible or that the current 24-match sample establishes route dominance.

**Alternatives.** (A) Keep unanimous/coalition consent and make diplomacy an explicit negotiation victory; (B) lower or reshape the two-player threshold so a qualified self-vote can win, preserving a rival veto only through a separate censure/war condition; (C) add neutral/independent delegates or durable alliance/pledge rewards; (D) disable diplomatic victory in 2-player games until a dedicated rule is designed. A preserves diplomacy but risks veto frustration; B improves agency but can make the route too deterministic; C adds meaningful diplomacy but increases state/UI complexity; D is clear but removes route variety.

**Preferred remedy.** Do not tune the threshold from these outcomes alone. Instrument council sessions with allocated delegates, each ballot, candidate counts, supporter set, eligibility and veto/pledge reasons; run rational-veto, cooperative, and adversarial policies in 2/3/4-player fixtures. Then choose a rule that makes the diplomatic player’s actions (alliances, pledges, loyalty, trade or concessions) change the probability of success rather than relying on an unobserved opponent mistake.

**Trade-offs.** Removing the veto increases route accessibility and may shorten games; retaining it creates strong social negotiation but can make the route pointless in isolated 2-player play. Any threshold change must be evaluated against industrial/expedition timing and comeback metrics, not only diplomatic win counts.

**Validation experiment.** Add a council-only deterministic fixture for 2 players with delegate pairs (2/2, 3/2), testing self-vote, abstention, rival vote, pledge honored/broken, war and eligibility. Repeat with 3/4 players and rational/adversarial voters; report diplomatic-route wins separately from policy-seat wins, ballot coalition rate, first eligible round, failed-vote count, route switching and opponent-veto attribution. Preserve the current 24-match cross-play as a baseline, not a diplomatic balance estimate.

## BAL-10 — Faction-policy pilot confounds faction bonuses with AI personality and seat order (CONFIRMED evidence limitation; HIGH process priority)

**Symptom.** A 36-match faction-policy pilot appears to compare civilization bonuses under one identical policy, but it does not isolate the bonus effect: every civilization keeps its fixed AI personality, and seat order is strongly predictive of the observed winner.

**Evidence.** The compact result is [`results/faction_policy_pilot.json`](results/faction_policy_pilot.json), with raw output at `/tmp/civcraft-faction-policy-pilot.json`, source-clean at HEAD `97944b8bc85e011d00abbdf45bf9aecdb82050ae`. All 36 matches finished, all ended `END EXPEDITION`, and every player received identical expedition weights/goal. Nevertheless `ai_personalities.lua:53-64` maps civilizations to different archetypes, and `Personalities.forCivilization()` returns those profiles at lines 66-72; AI strategy, tactics and diplomacy consume that profile (`ai_strategy.lua:122-186`; `ai_tactics.lua:132-251`; `council_ai.lua:37-71`). Aggregate wins were Scholar 4/4, Nomad 4/4, Wild 4/4, Mariner 3/4 and every other tested non-Forge faction 2/4. The observed seat-0 association is also strong: seat 0 won 29/36, and every non-Forge faction won both trials when placed in seat 0. This is a start-position/seat association, not proof that actor ordering caused the result; the pilot combines faction rules, personality, deterministic IDs, map realization and possible scheduling effects.

**Suspected/verified root cause.** Verified experimental-design confound, not a gameplay defect. The policy injection holds goal/weights constant but leaves the live civilization-to-personality mapping and player IDs untouched. A research-only fixed-personality ablation has now been run through the same runner using Lupa 2.8, with no gameplay/tool-source changes: all 36 matches finished, seat 0 won 33/36, and wins changed Mariner 3/4→1/4, Nomad 4/4→2/4, Wild 4/4→2/4, while Scholar stayed 4/4 and the remaining factions stayed 2/4. This isolates a material expansionist-personality contribution but does not identify whether the remaining seat association is geography/start position or actor scheduling.

**Affected matchups.** Any faction comparison using AI policies without holding personality and independent map starts/seat constant; especially current 2-player Forge mirrors, where the observed seat association can dominate small faction effects.

**Severity.** High for balance inference and policy evolution; no direct player-facing severity is established by this pilot.

**Alternatives.** (A) Treat fixed personalities as part of the intended faction identity and report the combined package; (B) run independent-map-start and paired-seat controls after the fixed-personality ablation; (C) use human/scripted policies that do not call civilization personality; (D) statistically model personality, seat and map start as factors. A is faithful to current AI identity but cannot estimate pure bonuses; B gives the cleanest diagnosis; C reduces AI confounding but may be less representative; D needs more samples.

**Preferred remedy.** Do not rebalance faction bonuses from this pilot. Keep the fixed-personality result as an ablation, then rerun with independent map starts and paired seat rotations while `Personalities.forCivilization()` is pinned to the same Forge profile. Compare paired deltas to the original and retain the unablated result as a combined faction-plus-personality baseline.

**Trade-offs.** Removing personality variation makes the policy less like live AI and may understate intended faction identity; retaining it preserves player-facing AI flavor but makes attribution impossible. Seat rotation and fixed-personality controls cost additional matches but prevent deterministic ordering from masquerading as balance.

**Validation experiment.** For each civilization and seed, run both seat orders under the same fixed personality and identical policy, then repeat on independent maps/start assignments. Record winner ID, route, round, per-round yields/science/industry, rejected actions and initial/final hashes. Require source-clean output, paired map identity and no errors before estimating faction effects. Compare against the 29/36 original and 33/36 ablation seat-0 associations, reporting personality, seat, start position and actor-scheduling interactions separately.

## Explicit non-issues / traps to avoid

- **Retained project progress is not free switching.** `systems.lua:420-431` preserves progress, but switching still sacrifices the current turn’s output and can leave projects idle; do not “fix” this by deleting retention without measuring.
- **Zero-yield Dock/Walls are conditional content, not automatically dead.** Dock enables naval recruitment and Walls add HP/ranged city strikes (`content.lua:551-570`); evaluate coastal/wartime utility by matchup rather than their static yield being zero.
- **AI shared actions are not evidence of good AI.** The same validator proves legality, not competence or strategic parity.
- **A passing UI/native test is not a balance result.** It establishes a lifecycle/visibility/save boundary only; it does not establish pacing, win rate, or comeback probability.


## BAL-11 — Opening production outruns ordinary research (CONFIRMED clock relationship; HIGH experience hypothesis)

**Symptom.** Scouts and expansion finish before ordinary research supplies another development choice; Scholar experiences a substantially different opening clock.

**Evidence.** The seeded native opening has five industry and one science: Scout 5 costs one round, Guard 13/Settler 12 three rounds, and a 24-science technology 24 rounds at constant income. Scholar's city bonus gives three science and an eight-round technology in that fixture. Growth takes twelve rounds at its measured surplus. See the native opening JSON and detailed Civ VI comparison; these are exact local divisions, not whole-population timing distributions.

**Root cause.** Very low production costs, one-science city centers, the +2 per-city Scholar bonus, and food infrastructure locked behind research create mismatched clocks. Civilization VI instead combines a 30-production Scout, 40 Warrior, 80 Settler with population cost, and action-triggered research boosts; relative timing matters more than copying these numbers.

**Affected matches / severity.** All ordinary openings, especially ordinary-versus-Scholar, across expansion/research policies; HIGH design priority. Actual player frustration and fairness effect sizes need controlled trials.

**Alternatives.** Globally speed research; globally slow production; or calibrate the opening together with an immediately useful development fork and conditional Scholar identity.

**Preferred remedy.** Test the coherent opening candidate in REVIEW_BRIEF.md, with separate component ablations and an unchanged control. Preserve terrain/scouting/defense alternatives and progress retention.

**Trade-offs.** Increasing unit/settler investment can make early losses harsher; raising baseline science accelerates later Ages unless the research curve is calibrated. A capital-only Scholar change affects wide expansion, not merely the first technology.

**Validation.** Matched maps/seats, all factions, civilian/expansion/military policies; record first useful research, first scout/contact/settlement, growth and hostile loss, credible alternatives, moderate-mistake recovery and later-age pacing. Adapt agents to candidates after review rather than judging them only with old policies.

## BAL-12 — Mature production lacks distinct repeatable civilian uses (CONFIRMED content gap; HIGH choice hypothesis)

**Symptom.** Players can finish a city's relevant buildings and face idle production, more units, or one obvious next unlock.

**Evidence.** There are 39 one-time buildings/projects and no general repeatable economy-project category. In one peaceful Forge trace every city-round snapshot through round 100 had zero/one legal building; rounds 31–60 were idle in 66.7% of city snapshots. The observations are correlated and do not count units/wonders or measure strategic value. See PRODUCTION-CHOICE-MEASUREMENTS.json.

**Root cause.** Unlimited city slots, local prerequisite chains, flat yield accumulation and finite one-time content give little competition between development roles. AI role weights do not create an actual city specialization economy.

**Affected matches / severity.** Mature peaceful cities and specialist economies; potentially every faction. HIGH user-facing priority, with extent outside the fixture unmeasured.

**Alternatives.** Add many universal buildings; add blanket production conversion; or introduce a small differentiated focus/repeatable system.

**Preferred remedy.** Universal basics plus limited soft focuses and repeatables for research proofs, materials, freight, influence and refits. Civilization VI's population-gated specialty districts and different Campus/Commercial Hub/Industrial Zone projects provide specific equivalents; keep CivCraft's workshop/rail identity and UI constraints.

**Trade-offs.** Restricting old chains can strand a city or create a new mandatory choice. Repeatables can become runaway yield converters or a new universally optimal default. Focus transitions and previews need explicit costs and retained work.

**Validation.** Count both legal and credible alternatives, queue idleness, concentration of project choices, marginal payoff, inputs consumed and city-role diversity across research paths. Include mixed-city/fallback policies and military threats; do not optimize raw menu length.

## BAL-13 — Army generations do not preserve investment; controller caps confound military viability (CONFIRMED mechanics; HIGH research priority)

**Symptom.** Old units accumulate, better equipment arrives as another unit purchase, and conquest-controller failure can look like a weak victory route.

**Evidence.** There is no general equipment-upgrade or formation action. Disband already exists in the authoritative dispatcher and has UI confirmation; the issue is investment continuity and planning, not inability to remove a unit. The full-health combat fixture gives Iron Swordsman effective attack power 45 versus Stone Guard 20, with 80 versus 16 damage on the compared strikes. Production counts old soldiers against fixed recruitment need; its upper bound is six, or eight for conquest, with lower city-dependent targets. The first route cross-play's conquest controller lost 12/12; this is policy evidence, not an intrinsic Conquest balance estimate.

**Root cause.** Independent technology unlocks, an exponential capped damage curve and count-based AI recruitment. Replacing a whole army competes with the economy while obsolete bodies can prevent the AI from recruiting replacements.

**Affected matches / severity.** Military modernization, long games, advanced defense versus early armies and conquest-policy evaluations. HIGH, but player unit overload is not quantified by that small AI batch.

**Alternatives.** Raise caps/build more units; soften the combat curve alone; or add equipment continuity and quality-aware planning.

**Preferred remedy.** Reviewed equipment refits preserving experience, maintenance/quality trade-offs and eventual consolidation. Test quality-aware offline military controllers before calibrating route costs. Civ VI's resource/gold upgrades and corps/armies give a direct investment/management equivalent, without requiring the same formation rules.

**Trade-offs.** Cheap refits can create instant surprise power spikes and remove recruitment choices; harsh maintenance can punish defense. Changing both combat and equipment costs simultaneously obscures which mechanism improves play.

**Validation.** Equal-budget frontier battles, siege/defense and campaign scenarios; obsolete-unit share, strength per piece, player decision load, upgrade-versus-recruit choices, actual capital captures and recovery after army loss. Use legal observed-information actions under the same turn budgets.

## BAL-14 — Industrial qualification conflicts with complementary city specialization (CONFIRMED structural tension; HIGH redesign priority)

**Symptom.** Pursuing Industrial rewards repeating the same factory chain in three cities, while the intended experience is cities with different jobs. Terminal science can also have little time to contribute before a final race ends.

**Evidence.** Current Industrial qualification requires three bank/Industrial Complex cities in a rail network and ten scaled hold rounds. Each local closure contains thirteen buildings and 890 industry before rail. The End chain's final three projects unlock together; the late Archive science therefore needs a payoff-horizon audit. These are source/static facts, not route-speed estimates.

**Root cause.** Victory tests repeated local flags rather than complementary contributions. Flat global science/local production and simultaneous late unlocks can compress payoff horizons.

**Affected matches / severity.** Industrial specialization, End preparation and late research roles; HIGH design priority. No global route equivalence is established.

**Alternatives.** Keep three identical factories and specialize only non-victory cities; remove the network requirement; or change qualification to complementary assembly/knowledge/freight contributions while preserving network contest.

**Preferred remedy.** The complementary network prototype in REDESIGN_PROPOSAL.md, with calibrated total investment and visible interruption. Stage End preparation across research milestones and give Archive/proofs useful work before completion. Civ VI's differentiated district economy and Satellite/Moon/Mars/Exoplanet sequence provide the detailed comparison.

**Trade-offs.** Complementary roles can become three compulsory checkboxes, reduce city flexibility or change optimal empire size. Earlier End preparation can make a science lead even more dominant. Preserve flexible fallbacks and test adapted rivals.

**Validation.** Compare aggregate investment, city-role diversity, route reachability, completion/contest windows, disruption/recovery and success per pursuer across two-to-four players and opponent-route compositions. Implement candidates only after review; keep the unchanged rules as the control.

## BAL-15 — Insolvency can erase recent siege investment before it is used (CONFIRMED rule/policy interaction; HIGH military-investment concern)

**Symptom.** Repeated recruitment can produce a large nominal army while deleting its newly built specialist pieces through upkeep.

**Evidence.** In seed 923671, conquest seat 1, a round-80 checkpoint replay automatically disbands full-health catapults 37 and 36 at round 82. There are zero manual disband requests. Instrumented and uninstrumented continuations match the full round-84 state hash. `Systems.production` pays treasury net after project completion and scans the unit array backwards to cover a negative gold balance. Recent appended recruits are therefore exposed first. See [operational report](OPERATIONAL_SIEGE_REPORT.md) and [exact upkeep replay](results/siege_upkeep_diagnostic.json).

**Root cause.** A confirmed automatic removal order interacts with a controller that continues committing production without a sustainable deployment reserve. This is not evidence that insolvency should have no consequence, or that the existing source violated an intended design.

**Affected matches / severity.** Negative-treasury military buildup and modernization. HIGH for investment continuity; the confirmed frequency is one inspected case, not a measured universal player experience.

**Alternatives.** Keep newest-first removal; prioritize old/low-value units; require player choice with a bounded deadline; reserve upkeep at recruitment; or improve forecasting and warnings while retaining the rule initially.

**Preferred remedy.** First test offline completion/deployment budget forecasts and legal economic-project switches against replacement recruitment. For the reviewed gameplay package, expose the projected shortage and exact consequence before commitment; compare explicit disband choices and forced-priority alternatives. Refits must include the resulting upkeep, not only the purchase price.

**Trade-offs.** An oldest-first rule can encourage sacrificial-unit shields; a grace period can become free army credit; strict recruitment escrow can make defensive emergencies impossible. Removing upkeep would erase an important opportunity cost and is not justified by this case.

**Validation.** Matched checkpoint branches for reserve policy, economic switch and voluntary disband; completed/lost units, investment lost before first action, treasury trajectory, useful military pressure and actual victories. Test multiple deficits, unit insertion orders, retained project progress and speed settings. Review any rule change separately from AI prevention.

## BAL-16 — Local tactical progress can stall despite a known operational route (CONFIRMED controller weakness; HIGH for route evaluation)

**Symptom.** Siege pieces remain far from a known enemy and prefer standby, so a wall-damage bonus never activates.

**Evidence.** The passive operational probe reproduces the previous full-game hash and records 56 first siege decisions without a positive wall-damage forecast. At several checkpoints, discovered-terrain routes exist while the ranker chooses standby. From the identical round-80 state, a bounded route-following policy moves catapult 38 from a round-120 position 13 hexes from the visible city to a position three hexes away. The restored control matches the original final hash; neither branch captures a city. See [matched branches](results/route_detour_diagnostic.json).

**Root cause.** The source tactical scorer rewards immediate geometric progress toward its target/corridor, while a valid operational path may require a detour. Friendly occupancy, inconsistent local/campaign targets and threat penalties then interact with staging. The paired intervention verifies travel improvement, not a complete causal explanation for failed conquest.

**Affected matches / severity.** This known compact Pangaea cell and similarly obstructed campaigns are the relevant scope. HIGH measurement priority because a route that never receives a competent attack cannot be fairly calibrated against economic routes.

**Alternatives.** Increase troop counts or movement; reveal routes; ignore risk; or use bounded discovered-terrain routing, persistent group targets and staging assignments while retaining legal movement.

**Preferred remedy.** Continue the offline operational hierarchy: safe rally, role-specific arrival, commitment and retreat. Re-rank existing legal moves along discovered paths; then isolate coordinated final approach and reserve constraints. This is training-policy work, not permission to alter live movement or combat rules.

**Trade-offs.** Route searches cost CPU; static friendly-occupancy routing can deadlock; ignoring it can suggest unavailable paths; overly cautious staging never attacks, while large bonuses can feed units into city fire. Preserve deterministic bounds, checkpoints and authoritative validation.

**Validation.** Detour and congestion scenarios with known routes, safe staging and unreachable targets; bounded CPU/cooperative yields; group arrival spread; legal attack opportunities, losses and captures. Follow any known-case correction with fresh maps, seats and opponents rather than treating reduced distance as general playing strength.

**P1 Scout follow-up.** The [restricted opening adaptation study](P1_OPENING_ADAPTATION_REPORT.md) finishes 80 training and 48 held-out games, with no target contacting another registered civilization. In a known losing Scout-first condition (Continents seed 382021, target seat 0), passive instrumentation preserves the exact final state and records 118 first tactical choices of standby: the Scout never leaves its spawn hex, despite its Scout role. Local moves score below zero while the campaign target remains near home. This extends the operational-target concern to exploration; it is not evidence that competent scouting has poor gameplay value. Reuse the existing discovered-frontier routing research before changing Scout price to compensate for this controller weakness. A single observed Scout trap is not a complete causal account of every no-contact match.
