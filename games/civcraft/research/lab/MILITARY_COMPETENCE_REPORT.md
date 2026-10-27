# Military competence benchmark preparation

**Follow-up:** [coordinated siege study](COORDINATED_SIEGE_REPORT.md) now
includes eight corrected full games, matched fixture checks and standalone
native Lua parity. It achieves a supplied-army fortified capture and changes
full-game siege composition/timing, but still produces zero opponent-city
captures in four paired evaluation cells. The historical diagnostics below
remain evidence for the earlier hooks; they are not current-policy reruns.

**Status:** bounded benchmark completed. This report is a research-only hook/scenario design; it does not change gameplay or installed live AI. The benchmark driver is [`military_competence_benchmark.py`](military_competence_benchmark.py), scenario definitions are [`military_scenarios.json`](military_scenarios.json), and compact results are [`results/military_competence_benchmark.json`](results/military_competence_benchmark.json), [`results/military_contact_diagnostic.json`](results/military_contact_diagnostic.json), [`results/military_frontier_hook_matrix.json`](results/military_frontier_hook_matrix.json), [`results/military_frontier_contact_retest.json`](results/military_frontier_contact_retest.json), [`results/military_campaign_memory_retest.json`](results/military_campaign_memory_retest.json), [`results/military_followup_retests.json`](results/military_followup_retests.json), and [`results/military_siege_gate_diagnostic.json`](results/military_siege_gate_diagnostic.json). Full traces remain in `/tmp/civcraft-military-competence.raw.json`, `/tmp/civcraft-military-diagnostic-95117.json`, `/tmp/civcraft-frontier-hook-matrix.json`, `/tmp/civcraft-campaign-memory-retest.json`, `/tmp/civcraft-campaign-memory-retest2-hook.json`, `/tmp/civcraft-campaign-memory-diagnostic.json`, and `/tmp/civcraft-siege-gate-diagnostic.json`.

## What the current AI actually does

The live conquest path is coherent but narrow:

- `Strategy.review()` selects a primary goal from civilization personality, victory state, city bonuses and deterministic tie-breaking (`games/civcraft/ai_strategy.lua:60-90,120-211`). The research policy wrapper can force `plan.primary`, but it does not replace tactics, production, or actions (`tools/civcraft_lab/policies.lua:27-44`).
- Conquest research scores dependencies to `netherite`, explicitly adds `tactics`, and adds `engineering` only when the campaign reports a siege need (`games/civcraft/ai_research.lua:5-18,38-75`).
- `Campaigns.update()` targets the highest-scoring visible enemy city, creates a corridor/muster point, assigns garrison/escort/screen/siege roles, and requests siege only when a fortified target has no siege unit (`games/civcraft/ai_campaigns.lua:49-133,155-257`). A hidden target is remembered for only ten rounds (`ai_campaigns.lua:189-205`).
- `Production.ranked()` recruits according to city/army quotas and only gives a siege unit a high value when `campaign.needsSiege` is true and siege count is zero (`games/civcraft/ai_production.lua:74-96,161-168`). It can skip a siege if target visibility/campaign state is late or if actual treasury/upkeep checks reject it (`ai_production.lua:161-166`).
- `Tactics.ranked()` considers up to the difficulty candidate count, forecasts combat through `Combat.predictOrder`, scores kills/captures/wall damage against retaliation and threat risk, and may retreat units below 50 HP (`games/civcraft/ai_tactics.lua:65-89,166-271`). `AI.military()` retries rejected actions up to three failures and executes through `Actions.apply()` (`games/civcraft/ai.lua:63-124`).
- `Systems.aiTurn()` calls diplomacy/materials/staff/research/production/strike and then every unit’s military/settlement/engineer routine before finishing the turn (`games/civcraft/systems.lua:872-943`).

These facts explain why “conquest intent” is not yet “conquest competence.” It can select a conquest plan while still changing target/phase, waiting for visible cities, building only one siege unit, or pursuing a different terminal route before a capture. The archived protocol reports conquest at `0/12` in one goal-specialist cross-play slice (`EXPERIMENT_PROTOCOL.md:230-251`), but that result is controller evidence, not a proof that the rules make conquest impossible.

## Fixed scenarios

The three fixtures in `military_scenarios.json` isolate the actual military decisions that a full game confounds:

1. **Siege breach:** quality of siege recruitment, wall damage, melee timing and survival.
2. **Capital defense:** threat detection, city strike, safe attack/retreat and capital preservation.
3. **Settler protection:** escort attachment, safe corridor selection and founding under visible pressure.

Fixture setup constructs a controlled wartime state for repeatability, but every measured turn is sent through `Engine.pump`: `ActorLifecycle` calls the ordinary `Systems.aiTurn`, and every resulting order still reaches `Actions.apply` (the same validator used by a human). Setup mutation is not a gameplay permission and is recorded separately from action traces. The setup primes research/stockpiles and declares the fixture war only to remove contacts and opening-economy confounds; those are not credited as AI competence.

## Full-game comparison

The full-game comparisons use the ordinary live `Runtime` and `ActorLifecycle` for the baseline. Research arms run inside an isolated `Runtime` and wrap the existing production, campaign, tactics and (only when explicitly enabled) research tables. The production layer calls the original `Production.ranked`, adds bounded quality/siege scores, and may append only the strongest modern unit that passes live `canRecruit` plus treasury/upkeep gates when the old soldier quota is full. The frontier layer re-ranks only original legal scout moves; the campaign layer preserves only a bounded remembered enemy-city record; and the timely-research layer re-ranks only already-legal candidates on the live engineering prerequisite chain. None injects an unaffordable unit, changes a cost, grants a resource, bypasses `Systems.canRecruit`/`canResearch`, or replaces declarations, settlement, diplomacy or legal-action validation. The opponent remains the normal AI. The original production/frontier matrix used hostile-off compact Pangaea, seeds `75123, 95117, 18731`, both conquest seats, and action tracing; the timely-siege and difficulty holdouts are listed separately below.

### Bounded result

All 12 full-game arms finished without timeout, censor or runtime error. Baseline and hook were identical on all six matched seed/seat pairs: the conquest-policy seat never won a CONQUEST route; terminal routes were one SCORE and eleven INDUSTRIAL outcomes. This small holdout does not establish that conquest is impossible, and no elimination rate is inferred.

The isolated siege fixture did show the intended ranking intervention: baseline queued catapult/warrior/catapult timing, while the hook queued catapults earlier and again; capital-defence and settler-protection traces were identical. None of the three eight-round fixtures captured a city. These are decision diagnostics, not victory results.

### Contact bottleneck and causal hook

The privileged checkpoint for seed `95117`, conquest seat 0, shows the root cause directly. The scout was alive at `(4,5)` with four moves available from round 14 through the terminal round; there were no foreign contacts or visible enemy cities, the campaign stayed `explore` against the player's own capital, and the seat accumulated six warriors, one scout, 16 technologies, 2391 gold and abundant iron. Consequently, no declaration, siege target or enemy path existed. The existing frontier score only rewarded an immediately frontier-adjacent move, so the scout preferred standby after its initial revealed ring.

The research-only frontier hook reuses `ai_routes.lua` over `view.world.tiles` and re-ranks only the original legal reachable scout moves toward a reachable known tile adjacent to an unknown tile. It does not reveal hidden terrain or create actions. In the matched seed `95117` seat 0 it produced contact and an accepted declaration at round 25; the baseline produced neither. Across the six hook-arm seed/seat cases, four declared war (rounds 20, 25, 26 and 31), while two did not. All six still ended INDUSTRIAL, with no observed city capture; this fixes the contact gate but does not solve military execution.

### Post-contact campaign-retention retest

The next diagnostic isolated the first declared-war case rather than treating the unchanged terminal route as a generic arms failure. At round 40, the conquest seat had a city target at `(20,13)`, was in `siege`, had six warriors and three swordsmen, and `canRecruit(swordsman)=true` while `canRecruit(catapult)=false`. By round 50 it had ten swordsmen, but target visibility and campaign state were fragile. At round 60 the ordinary AI correctly changed to `defense` for a threatened home city; once that interruption ended, the original ten-round target memory expired and the plan returned to exploring its own capital. Walls had meanwhile recovered to 100. Engineering made `canRecruit(catapult)=true` by round 110, but the lost city campaign meant `needsSiege=false`, so the siege unit was not the operative answer.

The research-only campaign-memory hook stores only the AI's last observed enemy-city record, for at most 40 rounds, and restores it only after the ordinary planner returns to `explore`; it does not override a live defensive plan, reveal map state, inject actions, or alter costs/stats. In the matched full run it restored a city campaign by round 70, produced 15 swordsmen and one catapult, and generated two accepted city-strike actions, but still captured no city and still ended INDUSTRIAL (round 131 versus baseline round 135). The conquest seat finished with 843 combat power versus 135 baseline, yet had only 11 gold and remained in age 4, while the industrial opponent retained the terminal victory. This is a policy bottleneck and a useful negative result: keeping the target and building an army is insufficient when the attack/siege sequence does not reach a capture before the rival's industrial route.

The raw/compact evidence and exact source/driver hashes are in [`results/military_campaign_memory_retest.json`](results/military_campaign_memory_retest.json). This remains one deterministic seed/seat; the internal `move.attack` flag is not present in the runner trace, so accepted `cityStrike` and city capture are counted directly while ordinary move requests are not mislabelled as attacks.

### Timely-siege and capture controls

The follow-up adds a second research-only arm to the same frontier-plus-memory case. Once the AI has recorded a fortified enemy city, it boosts only already-legal candidates on the existing dependency chain `deepmining -> redstone -> engineering`; it never marks a technology researched, bypasses `canResearch`, changes science, or interrupts an existing research project. The corrected hook is active during a temporary defensive campaign as well, using only the remembered enemy target. In the matched seed `95117` case, redstone moved from round 74 to 61, engineering from 87 to 74, and the first catapult queue from round 99 to 86. The conquest seat still captured zero cities and the opponent still won INDUSTRIAL (round 130 versus 131), so late siege access is a confirmed contributing bottleneck, not a complete causal explanation.

Two short real-action controls bound the interpretation. The fortified `siege_breach` fixture still ended eight turns with target wallHP 100 and no city capture or city strike in either arm; this is a negative controller diagnostic, not evidence that the shared combat formula is broken. The new `capture_breach` positive control starts with the visible target wall already at zero but keeps one defender. Both ordinary and hook arms transfer the city on round 3 through the shared move/combat path; the attacker swordsman finishes at 47 HP and the surviving defender at 49 HP. This proves that final ownership transfer works when the siege prerequisite has been removed, and narrows the remaining failure to getting a fortified army into a valid wall-breach/assault sequence.

The symmetric difficulty holdout used both players at the same level, not an attacker-only advantage, on two seed/seat cases. Both-player Deity matched both-player Prince exactly on conquest research, cities and combat power in seed `75123` (both SCORE at round 180); seed `95117` differed only slightly (Prince INDUSTRIAL round 151, Deity round 152, same conquest research/cities/combat power). These are deterministic-cell observations rather than a global ranking, but they show that Deity's broader search did not repair this conquest controller path without a target/siege state to exploit. Raw traces and compact summaries are in [`results/military_followup_retests.json`](results/military_followup_retests.json).

### Fortified siege tactical gate

The narrow planner-boundary diagnostic separates “no legal attack exists” from “the ranker declines a legal attack.” In the first round of the controlled `siege_breach` fixture, the campaign target is visible at `(20,13)`, in `siege` phase, with wallHP 100; a catapult at `(19,12)` has two movement points and a legal city-wall request costs two. `Combat.predictOrder` forecasts wallHP 100 -> 68, wall damage 32, attacker HP 100 and zero retaliation. The same request is accepted by `Actions.apply` on a fresh fixture and produces exactly that 32-point wall hit. The candidate is therefore legal and the shared combat path is functioning.

The ordinary `Tactics.ranked()` output instead puts three safe moves first (each score `-18`, risk damage `0`), the ordinary unit attack fourth (score `-32`), and the city-wall attack tenth (score `-60.8`, risk damage `80`). The wall shot's forecast damage is positive, but `Threats.at()` treats the fortified enemy city as an 80-damage threat at the catapult's position (`games/civcraft/ai_tactics.lua:174-211,243-255`; `games/civcraft/threats.lua:63-77,82-143`). The immediate gate is thus defensive-risk scoring, not action legality or a broken wall formula.

A research-only tactical hook that re-ranks only existing legal choices can force the one-catapult shot, but that exposes the next constraint: the target city strikes on rounds 1 and 2, reducing the catapult from HP 100 to 50 and then destroying it; the wall regenerates to 100 and no city is captured. This is evidence against “just make the AI fire one siege unit” as a safe fix. A controlled positive check with three ordinary catapults, two swordsmen, one warrior and one defender does breach the same 100 wall: wallHP is 100 -> 4 in round 1 -> 0 in round 2, and the city transfers on round 3 after two legal city strikes. Two catapults survive, one is lost, and the swordsmen finish at HP 100 and 61. The positive control uses a supplied scenario budget, so it proves fortified capture is reachable through current legal rules, not that a full-game economy can reliably field that force.

This narrows the live-balance problem to the interaction between one-siege production/army quotas, exposure-aware tactical ranking, wall regeneration and defensive city fire. It does not justify changing combat stats, wall rules or unit costs yet. The compact evidence, raw SHA-256 and driver hash are in [`results/military_siege_gate_diagnostic.json`](results/military_siege_gate_diagnostic.json); no full games were launched after this gate was isolated.

Recorded comparisons:

- baseline live conquest-policy AI versus the production hook on independent map seeds;
- seat-rotated mirrors and action traces;
- fixed scenario results before interpreting full-game routes.

Record first contact/declaration, siege queue, attacks accepted/rejected, city captures, military/settler losses, route changes, victory route/turn, and every error/censor/timeout separately. A controller win by Industrial or Expedition is not a conquest success; report intended goal and actual route as separate fields.

## Hypotheses and gates

**Observed implementation facts:** one-siege quota, visibility-dependent targets, real treasury/upkeep recruitment checks, forecast-based tactics and shared action validation.

**Testable hypotheses:** after contact is repaired, declaration-to-capture execution, siege timing, and route competition remain limiting; one siege unit may be insufficient against wall recovery/defense. The frontier hook changed contact/declaration and shortened one terminal game, but produced no conquest victory, so it is evidence for a staged bottleneck—not a balance fix.

Do not rebalance combat, unit costs, walls, research or victory thresholds from this preparation. First require: source-clean manifest, driver hash, zero fixture setup leakage in observations, no unauthorized actions, scenario-specific acceptance criteria, and a held-out full-game set with seat/start controls. The driver uses `runtime.call(runtime.engine.endTurn, ...)` only if a future custom diagnostic needs explicit completion; it does not call a nonexistent `Runtime.endTurn` method.
