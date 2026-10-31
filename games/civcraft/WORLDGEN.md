# World generation contract

New maps use deterministic generation version 6. Coal uses iron terrain eligibility
(hills/mountains outside snowy plains), weight 16, inside the unchanged 17.5%
total resource density. Version 6 changes deposit selection; it does not add
coal to existing saved geography. Version 4 added recorded
horizontal topology to version 3's starting-region guarantees; version 5 adds
bounded, seed-deterministic variety to viable start sites and player seats.
Campaigns default to horizontal wrapping, while saved maps retain their
serialized terrain, geography, starts, and generation version. Migration does
not rerun generation.

The start placer measures land connectivity with CivCraft's recorded hex
topology, treating water and mountains as impassable. It prefers a single
connected landmass of at least 90 passable tiles that can fit every player at
least six hexes apart. Candidate sites avoid the polar map bands, reject a
radius-three opening with more than four snowy-plains tiles, and score nearby
food, industry, workable land, and cold terrain. A private seeded stream
perturbs site scores by at most four points, allowing close viable sites to
vary without discarding fertility ranking. The selected sites are assigned to
players in seeded order, so player one does not always receive the first
fertility-ranked site. A seed, player count, map settings, and player order
reproduce the same starts; different seeds can choose different viable
openings. Existing saves keep their original starts.

When no qualifying common landmass fits all players, the fallback chooses a
nonpolar opening within four score points of the best available and constructs
one compact shared starting land patch with six-hex spacing. Overlapping radius-three patches connect the
players without filling distant ocean corridors. Each opening is expanded to
30 connected passable tiles within radius four. This local fallback can join
nearby island fragments, while leaving the rest of archipelago geography
intact. If a generated map has no natural-wonder habitat outside the existing
spawn buffer, generation reserves one distant passable hill while keeping the
wonder placer authoritative. Each start retains a plains center and nearby
grain and iron deposits.

The generation model borrows the staged terrain and start-plot separation of
Civ V map scripts, not a claimed replica of Firaxis' generator. The [Civ V
Fractal API reference](https://modiki.civfanatics.com/index.php/Fractal.Create_%28Civ5_API%29)
documents a seeded fractal field and wrapping flags, but not the full world
generation contract. The [Civ VI Shuffle map script
mirror](https://github.com/mrobaczyk/civ6/blob/main/Base/Assets/Maps/Shuffle.lua)
and its [starting-plot assignment helper](https://github.com/mrobaczyk/civ6/blob/main/Base/Assets/Maps/Utility/AssignStartingPlots.lua)
illustrate separating terrain generation, fertility-aware site selection, and
player assignment. They are reference scripts, not a claim that CivCraft
replicates Firaxis' algorithm.
The [DTU thesis on multiplayer map generation](https://www2.imm.dtu.dk/pubdb/edoc/imm6474.pdf)
motivates checking connectivity, player distance, strategic access, and nearby
productive tiles; its evolutionary optimization and aggregate metrics are not
used as claims about Civ V or as a runtime search strategy here.
