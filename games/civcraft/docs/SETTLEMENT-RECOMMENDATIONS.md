# Map settlement recommendations

Selecting a Settler shows passive city icons on explored land. There is no
recommendation list or detail menu. Tapping an icon keeps the Settler selected;
movement and founding remain separate ordinary orders.

Recommendations evaluate the known radius-three region, rather than only the
candidate center tile. Food, industry and science use CivCraft's authoritative
tile yields, with nearer tiles weighted more heavily; known resources add value.
Existing claimed land is discounted. Unknown tiles contribute nothing. These
are provisional advisory weights, not a calibrated balance result or a forecast
of exact city production.

Sites must pass ordinary founding checks and remain at least four hexes from
all known cities. A deterministic descending-score selection also keeps icons
at least four hexes apart. Distances use saved map topology, including wrapping.
This advisory rule does not change the three-hex legal founding minimum.

The cache keys the actual projected observations, known cities/sites and own
technologies. New exploration, changed remembered terrain/resources, and new or
changed known cities therefore refresh advice, including in-place updates to a
projected view. Hidden authority data never enters the query or cache key.

## Civ V source reference

The reference is the Firaxis SDK-source mirror in `Gedemon/Civ5-DLL`, pinned at
`aa29e80751f541ae04858b6d2a2c7dcca454201e`. It is not a claim that this mirror is
an untouched latest vanilla release. The relevant in-game path is:

- [CvPlot::isBestAdjacentFound](https://github.com/Gedemon/Civ5-DLL/blob/aa29e80751f541ae04858b6d2a2c7dcca454201e/CvGameCoreDLL_Expansion2/CvPlot.cpp#L7579)
  excludes zero-valued plots and plots with a stronger revealed neighbour.
- [CvPlayerAI::AI_updateFoundValues](https://github.com/Gedemon/Civ5-DLL/blob/aa29e80751f541ae04858b6d2a2c7dcca454201e/CvGameCoreDLL_Expansion2/CvPlayerAI.cpp#L164)
  reevaluates revealed plots with the settler-site evaluator.
- [CvCitySiteEvaluator::PlotFoundValue](https://github.com/Gedemon/Civ5-DLL/blob/aa29e80751f541ae04858b6d2a2c7dcca454201e/CvGameCoreDLL_Expansion2/CvSiteEvaluationClasses.cpp#L272)
  checks founding eligibility and evaluates surrounding rings, yields, resources
  and existing cities. Its `CanFound` uses configured city-range constraints.

These are in-game site recommendations, distinct from `AssignStartingPlots`
world-generation placement. CivCraft adapts region evaluation, revealed-world
updates and separated local alternatives; it does not copy Civ V's full flavor,
happiness, faith, civilization-trait or resource formulas. No balance experiment
or parameter search is part of this change.
