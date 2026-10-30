# World generation contract

New maps use deterministic generation version 4, adding opt-in horizontal
topology to version 3's starting-region guarantees. Maps remain finite by
default until the gameplay and interface integration is complete. Existing
saved maps retain their serialized terrain, geography, starts, and generation
version; migration
does not rerun generation.

The start placer measures land connectivity with CivCraft's recorded hex
topology, treating water and mountains as impassable. It prefers a single
connected landmass of at least 90 passable tiles that can fit every player at
least six hexes apart. Candidate sites avoid the polar map bands, reject a
radius-three opening with more than four snowy-plains tiles, and score nearby
food, industry, workable land, and cold terrain. Starts are deterministic for
a seed and player ordering; randomized player-to-site assignment is a separate
follow-up.

When no qualifying common landmass fits all players, the fallback chooses the
best available nonpolar opening and constructs one compact shared starting
land patch with six-hex spacing. Overlapping radius-three patches connect the
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
illustrates separate terrain generation and fertility-aware start placement.
The [DTU thesis on multiplayer map generation](https://www2.imm.dtu.dk/pubdb/edoc/imm6474.pdf)
motivates checking connectivity, player distance, strategic access, and nearby
productive tiles; its evolutionary optimization and aggregate metrics are not
used as claims about Civ V or as a runtime search strategy here.
