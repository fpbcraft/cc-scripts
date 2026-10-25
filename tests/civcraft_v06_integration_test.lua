-- CIVCRAFT v0.6 integration regression: six-edge territory, direct hex staffing,
-- time-based queues and research. Uses production modules without UI mocks.
local originalDofile = dofile
dofile = function(path)
  if path:sub(1, 16) == "/games/civcraft/" then
    return originalDofile(path:sub(2))
  end
  return originalDofile(path)
end
local World = originalDofile("games/civcraft/world.lua")
local Hex = originalDofile("games/civcraft/hex.lua")
local Systems = originalDofile("games/civcraft/systems.lua")
dofile = originalDofile
local world = World.generate(75123, "standard", 2, "continents")
local a, b = world.starts[1], world.starts[2]
local state = {
  phase = "game",
  round = 1,
  version = 3,
  world = world,
  nextId = 10,
  players = {
    { id = 1, name = "A", civ = "verdant", techs = { agriculture = true }, food = 0, wood = 0, science = 0 },
    { id = 2, name = "B", civ = "iron", techs = {}, food = 0, wood = 0, science = 0 },
  },
  cities = {
    { id = 1, owner = 1, x = a.x, y = a.y, population = 2, buildings = {} },
    { id = 2, owner = 2, x = b.x, y = b.y, population = 2, buildings = {} },
  },
  units = {},
}
Systems.migrate(state)
local city, player = state.cities[1], state.players[1]
local borders = World.territory(state, Hex)
for y = 1, world.height do
  for x = 1, world.width do
    assert(
      borders[World.key(x, y)]
        == (World.territoryCity(state, Hex, x, y) and World.territoryCity(state, Hex, x, y).owner or nil),
      "City ownership and hex border renderer must use the same territory"
    )
  end
end
assert(
  World.deposit(world, a.x + (a.x < world.width / 2 and 1 or -1), a.y) == "grain",
  "Starting city must have a food resource nearby"
)
local workable = Systems.workable(state, city)
assert(#workable >= 2, "New capital needs at least two workable hexes")
Systems.ensureWorkers(state, city)
local assigned = 0
for _ in pairs(city.worked) do
  assigned = assigned + 1
end
assert(assigned == city.population, "Capital citizens are staffed on individual map hexes")
local target
for _, tile in ipairs(workable) do
  if city.worked[tile.key] then
    target = tile
    break
  end
end
assert(target, "Expected a staffed hex")
local oldYield = Systems.yields(player, city, state, Hex, World.territory(state, Hex))
assert(Systems.workTile(state, city, target.x, target.y), "Click to unwork a hex")
local yieldAfter = Systems.yields(player, city, state, Hex, borders)
assert(
  yieldAfter.food == oldYield.food - target.yield.food
    and yieldAfter.industry == oldYield.industry - target.yield.industry
    and yieldAfter.science == oldYield.science - target.yield.science,
  "Removing a citizen must remove precisely that tile's yield"
)
assert(Systems.workTile(state, city, target.x, target.y), "Click again to work the hex")
assert(
  not Systems.workTile(state, city, world.width, world.height),
  "Citizens cannot be assigned beyond the city boundary"
)
local oldWood = player.wood
assert(Systems.queue(player, city, "building", "farm", state, Hex))
assert(not city.buildings.farm, "Queueing production may not instantly finish a building")
assert(player.wood == oldWood, "Standard projects never spend stored industry")
local cost = Systems.projectCost("building", "farm")
local turns = 0
while not city.buildings.farm and turns < 50 do
  turns = turns + 1
  Systems.production(state, Hex)
end
assert(turns > 0 and city.buildings.farm, "Building must finish via per-turn production")
assert(Systems.research(player, "mining"), "An unlocked technology may be selected")
assert(
  not player.techs.mining and player.researchTarget == "mining",
  "Research selection must not instantly award technology"
)
local progress
for i = 1, 30 do
  Systems.production(state, Hex)
  if not player.techs.mining and player.researchTarget then
    progress = player.researchProgress.mining
    assert(progress >= 0, "Research progress accumulates across turns")
  end
  if player.techs.mining then
    break
  end
end
assert(player.techs.mining, "Research completes across global turn boundaries")
print("CIVCRAFT v0.6: territory, workforce, tile yields, production & research passed.")
