# First design reconciliation

**Current resolution:** All F01–F16 answers were subsequently A. The accepted
[ADRs](../../docs/adr/README.md) and [implementation roadmap](../../docs/ROADMAP-balance.md)
now govern: remove Industrial and Diplomatic victories; ordinary healing abroad
supersedes H1; one growth capacity, milestone doctrines, compact chains and local
SU machine priorities are selected. The questions and tentative language below
are retained as the first-pass explanation, not remaining unanswered decisions.

27 October 2026. All 38 initial questions now have answers, including D20 B
from the user's follow-up. This records preferences and unresolved questions;
it does not mark the broader redesign implemented. P1's prior approval persists.
The source of truth for verbatim notes is `design_decision_answers.json`.
The next questionnaire is `design_followup_questions.json` (F01–F16).

## Direction selected

Small placed specialty sites, limited city focuses, and simple geographic
bonuses; actual charge-based Builders and Trader units; population-consuming
Settlers; reshaped six-Age progression; retained investment and bounded overflow;
Minecraft-themed strategic stockpiles and consumption; upgrade families and one
formation tier; Civ VI-like support/civilian grouping; limited economic raiding;
one signature faction mechanic with a fallback; staged End Expedition; village
contracts and consequential treaties; visible hostile alerts; simple occupation
and explicit defeat. Keep the existing war-component turn model.

Wonders and the unit roster should lie between a minimal set and Civ VI's broad
ecosystem. Great People, governors and espionage remain absent for this version.
Magic as a possible religion equivalent is future scope, not a current feature.
Their future addition alongside diplomacy is an option, not a dependency or promise.

Remove Diplomatic victory for this version, while retaining diplomacy gameplay.
This explicit D29 instruction qualifies D26's general selection of the existing
victory categories. Industrial victory remains undecided: the user selected C
but explicitly leans toward B (removal). Score is a deadline fallback, not a
third active victory race if both Diplomatic and Industrial are removed.

## Explanations requested

### D05: one capacity versus two constraints

B represents separate housing and amenities: housing limits how readily another
citizen can be accommodated, while amenities affect contentment and its economic
consequences. They create different problems and different investments. A city
can have adequate housing and inadequate amenities, or the reverse. Civ VI's
housing and happiness concepts document these distinct roles; exact bonus tables
on public concept pages can be outdated and are not copied here.

C proposes one Settlement Capacity affecting growth, not a hidden combination of
every happiness effect. Illustratively, a population-5 city with capacity 6 could
grow more slowly as it approaches capacity; water, housing and selected civic
infrastructure increase that capacity. Food still pays for growth. This removes
independent happiness, luxury allocation, war weariness and amenity-based yield
penalties. It is simpler but provides less pressure on empire-wide expansion.
Housing-only is an equally coherent simpler alternative and may communicate the
rule better. Capacity should not simultaneously unlock specialty slots unless
the resulting double gate is deliberately selected.

### D09: two practical building models

B would give a Works site a district-style ladder analogous to Civ VI's Workshop,
Factory and Power Plant, with tier prerequisites, gold maintenance and selected
advanced SU-powered effects. Other specialties receive comparable ladders. It
would require a broader operating-economy audit and risks becoming an automatic
sequence unless location, timing and competing expenditure matter.

C would retain shorter Minecraft-specific chains with distinct jobs: a Workshop
provides basic fabrication; a processing choice improves material conversion;
an Assembly upgrade enables advanced manufacture. Only appropriate machinery
requires SU or recipe inputs. Knowledge and Freight have their own short roles.
An alternative is two or three tiers with a mutually exclusive branch. These
names and structures are proposals, not approved new definitions. Choosing
machines to operate must not become a per-turn click tax.

### D11: what a separate civics track would look like

B could be a compact 12–18-entry Charter/Guild tree, progressed through a separate
culture-like yield, granting empire-wide doctrines, route capacity or policies.
It need not contain culture victory, religion, governors or diplomatic victory.
The benefit is an independently investable strategic clock; the cost is another
yield, producers, research interface and AI valuation. The count is illustrative.

C could grant doctrine choices at a few broad settlement/era achievements, with
a small active policy allowance and bounded switching opportunities. Avoid tying
all unlocks only to technology, which would restore science's dominance over
organization. Avoid rigid achievements that force every empire into the same
three-city or trade checklist. Maintenance doctrines can exist under either B or C.

### D24: is the Civ VI budget ecosystem already present?

No. Current `Systems.treasury` sums city/treaty/project income and unit upkeep.
The production settlement removes units in reverse state-array order when gold
goes negative, adding each removed unit's upkeep until the immediate deficit is
covered. There is no complete government/policy, amenity or graduated shortage
system corresponding to the full B package.

Civ VI's Bankruptcy concept itself includes forced disbanding and amenity
penalties, so exact alignment does not solve involuntary losses. A chosen
adaptation could combine maintenance policies, forecasts, a bounded response
window, explicit retirement selection and a deterministic last-resort fallback.
If amenities are omitted, their bankruptcy penalties require replacement or
intentional omission. Gold, material shortages and SU overload should each have
a clear cause and response rather than duplicating penalties indiscriminately.

### D27: the case for and against a distinct Industrial victory

C deserves a prototype only if it tests a different achievement from End science:
coordinated specialized production, transportation, public deliveries and keeping
a network functioning under disruption. Alternatives for inputs, routing and
city count must prevent a prescribed Works/Knowledge/Freight shopping list.
This offers a peaceful logistics route that rewards Create's identity.

Removal is coherent and may be preferable. A long building/material chain that
largely overlaps the End route would dilute balance and create two names for
one economic race. With Diplomatic also removed, the consequence is two active
routes, Conquest and End, plus Score fallback. Keep the network useful to both
even if it does not award victory. Do not infer approval for C from its original
radio selection when the user's note explicitly leans toward removal.

### D33: interpreting 250 rounds

250 is a reasonable prototype deadline, not an evidence-backed optimum. A
starting design hypothesis is most competitive victories around 180–230, with
the deadline reserving time for interrupted plans and recovery. Simply raising
180 to 250 does not retime research, production, movement or contest windows.
Measure actual minutes per era, useful unit lifespan, travel-to-front time,
first upgrade and late investment payback alongside round counts. Wins should
not be artificially delayed just to fill the deadline.

### D38: Create Stress Units

Adopt the requested SU terminology. Create generators contribute stress capacity;
machines have stress impact. SU is not a stockpile spent each round. Generator
fuel may be consumed separately. Real Create can stop an entire overstressed
network; choosing priority-based machine suspension would be an explicit game
adaptation. Recommend a local pool initially, with no RPM or shaft simulation.
Rails transport goods, not mechanical torque. A shared mechanical network would
need explicit physical/abstract connection rules. No version-specific Create
machine values are assumed from the older reference table.

The requested Fandom page could not be retrieved by the browsing service. The
capacity/impact/overstress model was cross-checked against the Create developers'
own documentation instead.

## Interaction audit

| Decisions | Classification | Resolution needed |
|---|---|---|
| D01/D02/D03 | Compatible with parameter dependency | One site should use one focus slot; do not add independent overlapping capacity gates. F08. |
| D04/D16/D20 and fewer unit orders | Design tension | Builders and Traders add civilian pieces; grouping, queued work and autonomous route travel can control order load. F07. |
| D05/D06/D07 | Parameter dependency | Population loss stacks with higher Settler prices and capacity constraints; recalibrate rather than assume approved P1 numbers remain optimal. F01/F09. |
| D09/D15/D38 | Parameter dependency | Specify building operation, resource stockpiles and local SU together. F02/F13/F14/F16. |
| D11/D24 | Missing dependency | Maintenance policies need a doctrine or civic mechanism; full amenity penalties need amenities. F03/F04. |
| D17/D18/D19/D20 | Compatible | Fewer families, upgrades, formations and grouped support jointly reduce obsolete pieces; grouped targeting and split rules still need a detailed spec. F11. |
| D21 | Intentionally provisional | Revisit deterministic combat, siege and wall counters after roster and economic decisions. Do not claim combat finalized. |
| D22/D04 | Design tension | Decide whether ordinary Builder improvements can be pillaged or only strategic extractors and key sites/routes. F10. |
| D23 B versus prior H1 | Direct conflict | Latest preference may intentionally supersede the explicit old rule; clarify before changing passive healing. F06. |
| D26 A and D29 custom removal | Resolved by explicit qualification | Remove Diplomatic victory now; preserve other chosen categories subject to D27. |
| D27 C and note leaning B | Unresolved preference | Explain differentiated logistics win, then ask retention/removal. F05. |
| Equal victory opportunities and removals | Evaluation scope change | Compare active routes per pursuer and matchup; Score frequency is a pacing/timeout measure, not an equal-share target. |
| D33 and richer mechanics | Design tension | Additional mechanics need meaningful operating time without making human turns too slow. F15. |

## References

- [Housing](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_14/)
- [Happiness](https://www.civilopedia.net/en-US/gathering-storm/concepts/cities_16/)
- [Workshop](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_workshop/)
- [Factory](https://www.civilopedia.net/en-US/gathering-storm/buildings/building_factory/)
- [Civics](https://www.civilopedia.net/en-US/gathering-storm/concepts/culture_4/)
- [Policies](https://www.civilopedia.net/en-US/gathering-storm/concepts/govt_2/)
- [Bankruptcy](https://www.civilopedia.net/en-US/gathering-storm/concepts/gold_4/)
- [Healing and territory](https://www.civilopedia.net/en-US/gathering-storm/concepts/diplo_15/)
- [Create developers: stress capacity and impact](https://github.com/Creators-of-Create/Create/wiki/Stress-Units%2C-Capacity-and-Impact)
- [Firaxis city design interview](https://gamesbeat.com/why-firaxis-decided-to-make-drastic-changes-to-cities-in-civilization-vi/)

The placed-site/geography direction serves the interview's stated goal of making
map decisions matter. It does not require reproducing every Civ VI subsystem.
