P1 implementation status: [approved prototype and validation](P1_IMPLEMENTATION.md).

# Recommended direction and review order

Latest review sequence: [FIRST_CHANGE_PACKAGE.md](FIRST_CHANGE_PACKAGE.md).
Its explicit prototype parameters refine earlier candidate ranges. H1 is the
user-requested implemented healing exception; P1 is now approved and implemented as a prototype; P2–P4 still require review. Research gaps do not require waiting for perfect AI before
prototyping a reviewed gameplay package.


CivCraft's main problem is the relationship between its clocks and choices.
Changing every cost by the same percentage would preserve the same problems.
The first prototype should make an early production decision compete with
research and expansion; the next should give mature cities useful, different
jobs. Army continuity and contestable victory routes follow those foundations.

This brief summarizes the [full proposal](REDESIGN_PROPOSAL.md),
[implementation roadmap](IMPLEMENTATION_ROADMAP.md) and
[executed evidence](BASELINE_BALANCE_REPORT.md). All gameplay changes below
are recommendations for review. The working tree changes research/testing
infrastructure and extracts shared lifecycle logic; it does not rebalance
the published game.

## What to borrow from Civ VI

| Problem | Detailed Civ VI equivalent | Current CivCraft evidence | Recommended first candidate |
|---|---|---|---|
| Opening actions finish before research offers a new choice | Standard Scout 30, Warrior 40, Settler 80 production; the Settler removes a population; terrain work can trigger research boosts | In the measured five-industry opening, Scout 5 finishes in one round, Guard 13 and Settler 12 in three; a 24-science technology takes 24 rounds at one science | Reconcile these clocks together; keep exploration, defense, growth and expansion as competing early investments |
| Faction identity overwhelms the first research clock | Korea's Seowon is a placed, hill-requiring district with adjacency trade-offs; its payoff requires investment | Scholar adds two science to each city on top of the ordinary one-science center | Move some advantage behind a capital/knowledge/proof condition; preserve a recognizable research faction |
| Every city builds the same checklist | Specialty districts are population-gated at 1/4/7, consume tiles, and support different building tiers; Library costs 90 and supplies science plus scientist points | One peaceful trace had zero or one legal building at every city snapshot through round 100; current slots are unlimited | Universal basics plus limited city focuses: Knowledge, Create Works, Freight, Arsenal, Harbor and Embassy |
| A mature city runs out of useful work | Campus Research Grants supplies science and scientist points; Commercial Hub Investment gold and merchant points; Industrial Zone Logistics power and engineer points | No general repeatable civilian production category; once local buildings finish, production options often collapse | Repeatable research proofs, material processing, freight, influence and refits, each with a specific input, payoff and opportunity cost |
| Too many pieces and obsolete armies | Upgrade paths retain early investment; upkeep, strategic resources, roles and corps/armies constrain army management | Disband already exists; no general equipment upgrade or formation action preserves investment; early units can occupy AI recruitment caps long after obsolescence | Equipment refits preserving XP, clear roles, upkeep and eventual consolidation; improve quality before expanding army caps |
| Industrial victory undermines specialization | Civ VI's science race combines research, productive launch cities and staged projects rather than demanding identical districts everywhere | Current Industrial local closure is 13 buildings/890 industry in each of three connected cities | Complementary assembly, knowledge and freight contributions, a visible network hold and actionable disruption |
| Endgame timing and counterplay are uneven | Satellite, Moon, Mars and Exoplanet projects unlock at different research milestones; the expedition then travels, and laser projects accelerate it | Terminal End projects unlock together; terminal +science can arrive too late to repay | Spread preparation across late milestones; give Archive/proofs a use before the finish; expose a contest window |
| Diplomatic route may be impossible against rational opposition | Gathering Storm diplomacy accumulates victory points from multiple systems; it is not simply electing another human winner | CivCraft needs two-thirds delegates and another member's vote; in two-player play the rival can veto indefinitely | A reviewed diplomatic contract with neutral/village objectives and counterplay, or an explicit two-player variant; do not solve this only with cheaper buildings |

Sources and rule-version qualifications: [Civ VI comparison](CIV6_COMPARISON.md),
[555-entry public reference catalog](../civ6-balance-2026-10-26/README.md),
and [detailed specialization/project references](../civ6-balance-2026-10-26/SPECIALIZATION-FACTIONS-VICTORY.md).
The catalog is not a complete merged installed-game database. Civ VI is a
useful reference, not evidence that every faction, route or opening is perfect.

## A concrete opening calibration to test

Use the current rules as the control. One coherent numerical candidate for
review is ordinary center science **2**, Scholar **+1 in the capital** instead
of +2 in every city, Scout **15**, Guard **20**, Settler **40 + 12 per previous
Settler**, and a useful basic food/development choice available immediately.
These are hypothesis values from the earlier study, not selected optima.

At a constant five industry/two science, that means Scout three rounds,
Guard four, first Settler eight, and a 24-science technology twelve. The
capital Scholar's three science reaches that technology in eight rounds.
Actual games must include growth, terrain, production prerequisites and
competing queues; these divisions are calibration anchors, not simulated
build orders. Test components separately before the combined candidate to
find which change helps. Population cost, overflow and focus capacity are
separate candidates; combining all at once would obscure causality.

Judge the result by whether players have several credible next actions and
can see their payoff, rather than by hitting a prescribed opening script.
Target a meaningful first research/development change around rounds 8–12,
with expansion a deliberate subsequent investment. Retain progress when
switching; test bounded overflow rather than discarding output at thresholds.

## What the simulations currently establish

- A clean small evolutionary search selected an expedition controller with
  6/8 held-out win credit versus the original controller's 2/8. Economic-only
  search showed no gain. The larger improvement therefore cannot be credited
  solely to yield weights. A further 32-match archive-adaptation study selected
  a mutant that beat that previous champion 3/4 on untouched maps; neither is
  an optimal-play reference.
- In 24 archived-controller games, selected expedition won all 12 appearances.
  Conquest won none. Five diplomatic-controller seat wins were all Industrial
  finishes, **zero Diplomatic**. These controllers are not equally competent.
- In four identical-checkpoint mistake pairs, diverting early research to
  Sailing delayed two wins by 10/11 rounds, reversed one against a closer
  expedition rival, and left one loss unchanged. A saved investment can still
  have a large timing cost.
- The 36-game faction sweep used the same strategic wrapper but retained
  civilization personalities. Its strong seat association and expansionist
  results require a personality-controlled follow-up; it is not a faction tier
  list. A paired 36-game fixed-personality ablation removed Nomad/Wild
  advantages (4/4 to 2/4 each), while Scholar stayed 4/4; the seat association
  persisted and remains unresolved.
- The actual selected Lua export completed a full native/offline game with
  identical final state at round 125. Real native save/load and narrow war/
  capture checks also pass. A captured-settler hostile crash is independently
  reproduced and remains an explicit runtime blocker.

For victory fairness, measure **success per pursuer**, plus actual route
finishes, reachability and pivots. Three science pursuers and one industrial
pursuer with equal individual odds should produce approximately 75%/25%
ending labels. Equalizing raw labels would bias the game. Test faction,
opponent composition, map and player-count interactions under comparably
strong policies, with independent map blocks and uncertainty intervals.

## Delivery sequence

1. Repair reviewed runtime invariants and finish representative parity/observer
   coverage; preserve errors as errors in every study.
2. Review and test the opening/science/settler calibration and bounded overflow.
3. Review city focuses and a small set of useful repeatables together, with
   complementary Industrial qualification so specialization is rewarded.
4. Review equipment refits, army consolidation, resource access and defensive
   counterplay. Strengthen research-only military controllers before using
   them to judge route balance.
5. Review staged End and diplomatic route contracts, then calibrate all ten
   factions using adapted agents, archived counters and independent holdouts.
6. Compare exported weights, distilled trees and tiny networks on native CC;
   keep the simplest model that retains strength and meets runtime limits.

The [evidence ledger](REQUIREMENTS_MATRIX.md) identifies the unfinished work.
No broad fairness claim or live trained-AI deployment follows from these pilots.

Opening-clock evidence note: 24 science / one starting science is a frozen-income
anchor, not the actual technology completion time of a growing empire. The
[paired opening study](RECOVERY_OPENING_REPORT.md) records two cities and two
science by round three in one ordinary AI continuation. Cheap expansion and
research pace must be considered together.
