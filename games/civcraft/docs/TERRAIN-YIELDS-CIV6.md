# Civ VI tile-yield parity

CivCraft now uses the **base, unimproved** terrain, feature, and directly
corresponding resource yields from Civilization VI. Production is called
**Industry** inside CivCraft. A tile contributes its yields only when worked.

| CivCraft biome | Civ VI analogue | Flat Food / Industry / Gold |
| --- | --- | --- |
| Plains | Plains | 1 / 1 / 0 |
| Forest | Grassland | 2 / 0 / 0 |
| Savanna | Plains | 1 / 1 / 0 |
| Desert | Desert | 0 / 0 / 0 |
| Taiga | Tundra | 1 / 0 / 0 |
| Jungle | Plains | 1 / 1 / 0 |
| Swamp | Grassland | 2 / 0 / 0 |
| Snowy Plains | Snow | 0 / 0 / 0 |
| Badlands | Desert | 0 / 0 / 0 |
| Mushroom Fields | Grassland (custom analogue) | 2 / 0 / 0 |
| Coast | Coast | 1 / 0 / 1 |
| Ocean | Ocean | 1 / 0 / 0 |

- Hills: +1 Industry (Production). Mountains: 0/0/0 and remain unworkable.
- Woods: +1 Industry; Dense (Rainforest): +1 Food; Marsh: +1 Food.
- Grain (Wheat), Fish: +1 Food; Stone: +1 Industry.
- Horses: +1 Food and +1 Industry; Iron: +1 Science.
- Saltpeter (Niter): +1 Food and +1 Industry.
- Copper: +2 Gold; Diamond: +3 Gold.
- Farm: +1 Food; Quarry: +1 Industry; Lumber Camp: +1 Industry.
- Existing CivCraft-only deposits such as Timber, Zinc, and Redstone retain
  their distinct bonuses rather than claiming an inaccurate Civ VI equivalent.

Coastal and resource Gold is added to the treasury **once per worked tile**
through ordinary city income. Gold is visible in tile inspections and the yield
overlay. Natural landmarks and civilization-specific improvement bonuses remain
CivCraft mechanics. City centers, buildings, project yields, adjacency bonuses
and unlock-based improvement scaling are not part of this terrain parity change.

## Save migration

When a game loads, `World.migrate` marks its existing world
`terrainYieldVersion = "civ6-1"`. This is done for both unversioned worlds
and the prior `sparse1` rules. Terrain, resources, improvements, city
assignments, map seed, and game progress are untouched. The new yields apply
immediately, with the marker saved during the next regular save. Loading
repeatedly is idempotent.

## References

- [Civilization VI terrain and feature yields](https://civilization.fandom.com/wiki/List_of_terrains_in_Civ6)
- [Civilization VI resource yields](https://civilization.fandom.com/wiki/List_of_resources_in_Civ6)
- [Farm](https://www.civilopedia.net/en-US/standard-rules/improvements/improvement_farm/)
- [Quarry](https://www.civilopedia.net/en-US/standard-rules/improvements/improvement_quarry/)
- [Lumber Mill](https://www.civilopedia.net/en-US/rise-and-fall/improvements/improvement_lumber_mill/)
