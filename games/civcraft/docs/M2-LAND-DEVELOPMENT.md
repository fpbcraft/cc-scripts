# M2 land development — implementation record

M2 is in progress. M2a delivers Settlement Capacity and population-consuming
Settlers in the selectable **Development V2** (`balance2`) profile. New campaigns
still default to Redesign V1 while charged Builders and their complete player/AI
workflow are implemented. Original, P1 and Redesign V1 retain their economies.
This is a mechanics prototype, not a balance-calibration result.

## M2a rules

Capacity starts at 4. Any adjacent water adds 1; CivCraft currently has no
freshwater/river classification. Homesteads (Crafting, 24 industry) and Water
Services (Masonry, 28) each add 2. A Trading Hall adds 1. These basics do not
consume a future specialty focus slot. Capacity is derived from map/buildings,
not stored as a separate population currency.

| Population relative to capacity | Positive growth food | Minimum growth time |
|---|---:|---:|
| Two or more below | 100% | 1x |
| One below | 50% | 2x |
| At capacity or one above | 25% | 4x |
| Two or more above | 12.5% | 8x |

Food consumption and starvation are unchanged. Fractional growth food accumulates
in city storage. The longer minimum time prevents banked food bypassing capacity;
food threshold and minimum age are concurrent constraints. The inspector shows
capacity sources, the rate, raw surplus and effective food gain.

Settlers cost 28 industry plus 8 for every previously completed Settler, scaled
by game speed. They require at least two population and consume one citizen
only when successfully placed. Failed placement never spends a citizen or
increments the trained count. Growth/starvation resolves before recruitment.
A queued Settler below two population keeps its progress and waits; growth can
make it eligible in the same round. Departing citizens stop working tiles and
reset the city's growth age; stored food is retained. Current-round production
was collected before departure; subsequent rounds use the smaller workforce.

Research and Codex entries filter Development V2 infrastructure out of older
profiles. Production help explains the citizen cost and pause reason. AI
production values capacity infrastructure when positive growth is constrained.
Redesign victory/recovery logic applies to both balance1 and balance2.

## Verification

`tests/civcraft_m2_growth_test.lua` covers source totals, growth tiers, banked
food, unchanged starvation, cost escalation, blocked/successful recruitment,
paused/resumed completion, actual worked-tile trimming, legacy profile behavior,
research/Codex filtering, capacity AI valuation and inspector row generation.
Its native-only branch checks actual save/load, fractional storage, capacity
reconstruction and no repeated citizen debit. It passed on CraftOS-PC 2.8.3 /
ComputerCraft 1.112.0. Inspector assertions verify row generation, not visual
readability or multiplayer delivery.

All 61 Lua regression scripts pass. The final capacity-preview/Codex additions
were then rechecked through focused native rules and a native hotseat/war flow.
[Validation record](validation/m2a-source-validation.json).

M1 and P1 focused native rule scripts also pass. Lua lifecycle conformance and
technology-canvas tests pass. All 41 Python laboratory contracts pass, including Development V2 Lua 5.3 /
LuaJIT checkpoint and round-boundary equality. Native host/AI and hotseat/war
sessions select Development V2, process round two and reload its saved campaign.
The published f1d1b8d installer also passes a native host session with the existing
Redesign V1 default, confirming the new runtime module is packaged. These are
scripted text-terminal input flows; physical monitor/rednet remains unverified.
Selene reports
zero errors/warnings for changed rules/UI and the new test.

## Remaining M2 work

- Charged Builder, initial improvements and the Farm/Quarry double-yield audit.
- Queued work with threat interruption, capture and invalidated routes.
- Tile yield/charge previews and operational Builder AI.
- Native interactive development, save/observer/network integration and a
  campaign version ready to become the default.
- Joint opening calibration remains deferred while balance studies are paused.
