local native = dofile
dofile = function(path)
  return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local S = dofile("games/civcraft/systems.lua")
local W = dofile("games/civcraft/world.lua")
local H = dofile("games/civcraft/hex.lua")
local C = dofile("games/civcraft/combat.lua")
local L = dofile("games/civcraft/landmarks.lua")
local R = dofile("games/civcraft/railways.lua")
local M = dofile("games/civcraft/hostiles.lua")
local V = dofile("games/civcraft/villages.lua")
local Victory = dofile("games/civcraft/victory.lua")
local function fixture()
  local world = {
    seed = 42,
    width = 18,
    height = 12,
    tiles = {},
    resources = {},
    landmarks = {},
    rails = {},
    starts = { { x = 3, y = 4 }, { x = 15, y = 9 } },
    contentVersion = 1,
  }
  for y = 1, 12 do
    for x = 1, 18 do
      world.tiles[W.key(x, y)] = "plains"
    end
  end
  local state = {
    ruleset = "create",
    hostileMode = "standard",
    version = 6,
    phase = "game",
    round = 1,
    nextId = 20,
    world = world,
    players = { { id = 1, name = "A", civ = "iron", techs = {}, gold = 100 }, {
      id = 2,
      name = "B",
      civ = "verdant",
      techs = {},
      gold = 100,
    } },
    cities = {
      { id = 1, owner = 1, capitalOf = 1, x = 3, y = 4, population = 2, buildings = {} },
      { id = 2, owner = 2, capitalOf = 2, x = 15, y = 9, population = 2, buildings = {} },
    },
    units = {},
  }
  S.migrate(state)
  W.reveal(state, H, S)
  return state, state.players[1], state.cities[1]
end
local function allTech(p)
  for _, id in ipairs(S.techOrder) do
    p.techs[id] = true
  end
end
-- The expanded content graph must be complete, acyclic and genuinely unlockable.
local p = { techs = {} }
for _ = 1, #S.techOrder do
  for _, id in ipairs(S.techOrder) do
    if S.canResearch(p, id) then
      p.techs[id] = true
    end
  end
end
assert(#S.techOrder >= 40 and #S.ages == 6)
for _, id in ipairs(S.techOrder) do
  assert(p.techs[id], "Unreachable research " .. id)
end
for _, source in ipairs({ S.units, S.buildings, S.wonders }) do
  for id, record in pairs(source) do
    assert(not record.tech or S.techs[record.tech], "Missing research for " .. id)
    for _, need in ipairs(record.requires or {}) do
      assert(S.buildings[need], "Missing local prerequisite for " .. id)
    end
  end
end
assert(
  S.units.diamondguard.strength > S.units.swordsman.strength
    and S.units.netherguard.strength > S.units.diamondguard.strength
)
p = { techs = {} }
assert(S.age(p) == 1)
p.techs.bronze = true
assert(S.age(p) == 2)
p.techs.deepmining = true
assert(S.age(p) == 3)
for _, age in ipairs(S.ages) do
  p.techs[age.milestone] = true
end
assert(S.age(p) == 6)
-- Material gating, local machinery chains, conversion and a scarcity fallback.
local state, p, city = fixture()
state.world.resources["4:4"] = "diamond"
state.world.resources["3:5"] = "copper"
state.world.resources["2:4"] = "zinc"
S.production(state, H)
assert(p.stockpile.diamond == 0)
p.techs.deepmining = true
S.production(state, H)
assert(p.stockpile.diamond == 1 and p.stockpile.copper == 1)
p.techs.heatedmixing = true
p.techs.brassworking = true
assert(not S.canBuild(p, city, "mixer", state))
city.buildings.press = true
city.buildings.burner = true
assert(S.canBuild(p, city, "mixer", state))
city.buildings.mixer = true
local brass = p.stockpile.brass
S.production(state, H)
assert(p.stockpile.brass == brass + 2)
state.world.resources = {}
p.stockpile.copper = 0
p.stockpile.zinc = 0
brass = p.stockpile.brass
S.production(state, H)
assert(p.stockpile.brass == brass, "No free brass without ingredients")
p.techs.currency = true
city.buildings.market = true
p.gold = 100
assert(S.exchange(state, p, "copper"))
assert(p.stockpile.copper == 1 and p.gold == 80)
assert(not S.exchange(state, p, "not_a_material"))
assert(not S.canRecruit(p, "zombie", state, H, city), "Hostile records cannot enter production")
-- Natural landmark bonuses belong to worked hexes, never every city in the empire.
state, p, city = fixture()
local before = W.yields(state.world, 4, 4)
state.world.landmarks["4:4"] = { kind = "amethyst", natural = true }
local after = W.yields(state.world, 4, 4)
assert(after.science == before.science + 4)
city.worked = {}
local a = S.yields(p, city, state, H)
city.worked["4:4"] = true
local b = S.yields(p, city, state, H)
assert(b.science == a.science + after.science)
-- Constructed wonders reserve an eligible tile, finish via industry and are globally unique.
allTech(p)
city.worked = {}
assert(not L.canPlace(state, city, "beacon", 3, 4, S))
assert(not L.canPlace(state, city, "beacon", 4, 4, S))
assert(S.queue(p, city, "wonder", "beacon", state, H, 3, 5))
city.project.progress = 10000
S.production(state, H)
assert(state.world.landmarks["3:5"].kind == "beacon" and not city.project)
assert(not L.available(state, "beacon"))
assert(not S.queue(p, city, "wonder", "beacon", state, H, 2, 4))
a = S.centerYields(p, city, state)
state.world.landmarks["3:5"] = nil
b = S.centerYields(p, city, state)
assert(a.food == b.food + 2 and a.science == b.science + 3)
-- Competing wonder completion releases the other queue without deleting its work.
local rival = state.cities[2]
allTech(state.players[2])
rival.project = { kind = "wonder", id = "greattree", x = 14, y = 9, progress = 40 }
assert(S.queue(p, city, "wonder", "greattree", state, H, 2, 4))
city.project.progress = 10000
S.production(state, H)
assert(not rival.project and rival.projectProgress["wonder:greattree"] == 40)
-- Rail construction validates technology, ownership, distance, movement and stock.
state, p, city = fixture()
p.techs.railways = true
p.stockpile.iron = 10
local engineer = { id = 4, owner = 1, kind = "engineer", x = 3, y = 4, movesLeft = 3 }
state.units = { engineer }
assert(not R.canBuild(state, p, engineer, 15, 9, S))
assert(R.build(state, p, engineer, 3, 4, S))
assert(engineer.movesLeft == 0 and p.stockpile.iron == 8)
assert(not R.build(state, p, engineer, 4, 4, S))
engineer.movesLeft = 3
engineer.moved = false
assert(R.build(state, p, engineer, 4, 4, S))
engineer.movesLeft = 3
engineer.moved = false
local destination
for _, d in ipairs(H.reachable(state, engineer, 1, S)) do
  if d.x == 4 and d.y == 4 then
    destination = d
  end
end
assert(destination and destination.cost == 0.25)
-- Three connected station cities; loops cannot multiply bonuses; a break resets victory.
local second =
  { id = 3, owner = 1, x = 6, y = 4, population = 2, buildings = { station = true, bank = true }, claimed = {} }
local third =
  { id = 4, owner = 1, x = 9, y = 4, population = 2, buildings = { station = true, bank = true }, claimed = {} }
state.cities = { city, second, third, state.cities[2] }
city.buildings = { station = true, bank = true }
city.claimed = {}
for x = 2, 10 do
  local c = x < 5 and city or x < 8 and second or third
  c.claimed[W.key(x, 4)] = true
  state.world.rails[W.key(x, 4)] = true
end
S.migrate(state)
local net = R.network(state, p)
assert(net[1].size == 3)
a = S.centerYields(p, city, state)
state.world.rails["5:4"] = nil
b = S.centerYields(p, city, state)
assert(a.industry == b.industry + 2)
state.world.rails["5:4"] = true
for round = 1, 9 do
  state.round = round
  Victory.check(state, true)
  assert(state.phase == "game")
end
state.world.rails["5:4"] = nil
state.round = 10
Victory.check(state, true)
assert(p.industryTurns == 0)
state.world.rails["5:4"] = true
for round = 11, 20 do
  state.round = round
  Victory.check(state, true)
end
assert(state.phase == "over" and state.victoryReason == "INDUSTRIAL")
-- End, conquest, score, simultaneous victories and deadline compatibility.
state, p, city = fixture()
city.buildings.dragon = true
Victory.check(state, true)
assert(state.victoryReason == "END EXPEDITION")
state, p, city = fixture()
state.cities[2].owner = 1
Victory.check(state, true)
assert(state.victoryReason == "CONQUEST")
state, p, city = fixture()
state.cities[2].buildings.dragon = true
city.buildings.dragon = true
Victory.check(state, true)
assert(#state.winnerIDs == 2)
state, p, city = fixture()
state.round = 180
Victory.check(state, true)
assert(state.phase == "over" and #state.winnerIDs == 2, "Equal development shares score victory")
-- Mob camps respect the start buffer, spawn bounds, and replay guards.
state, p, city = fixture()
M.generate(state)
for _, camp in ipairs(state.spawners) do
  for _, start in ipairs(state.world.starts) do
    assert(H.distance(camp.x, camp.y, start.x, start.y) >= 5)
  end
end
state.round = 10
M.round(state, S)
local count = #state.units
assert(count > 0)
M.round(state, S)
assert(#state.units == count)
for round = 11, 60 do
  state.round = round
  M.round(state, S)
end
assert(#state.units <= math.floor(18 * 12 / 20))
-- City raids cannot transfer ownership or destroy the settlement, even at one HP.
state, p, city = fixture()
city.hp = 1
local zombie = { id = 10, owner = M.owner, kind = "zombie", x = 4, y = 4, hp = 100 }
state.units = { zombie }
assert(C.attack(state, zombie, { x = 3, y = 4 }, S))
assert(city.owner == 1 and city.hp == 1 and p.gold < 100)
local creeper = { id = 11, owner = M.owner, kind = "creeper", x = 4, y = 4, hp = 100 }
state.units = { creeper }
assert(C.attack(state, creeper, { x = 3, y = 4 }, S))
assert(#state.units == 0)
state, p, city = fixture()
state.spawners = { { id = 1, x = 4, y = 4, kind = "spawner" } }
state.units = { { id = 10, owner = 1, kind = "warrior", x = 4, y = 4 } }
M.clear(state, S)
assert(state.spawners[1].cleared and p.gold == 125)
M.clear(state, S)
assert(p.gold == 125)
-- Villages are sovereign, defended, threatened, diplomatically useful and conquerable.
state, p, city = fixture()
M.generate(state)
V.generate(state)
S.migrate(state)
local village
for _, c in ipairs(state.cities) do
  if c.village then
    village = c
    break
  end
end
assert(village and V.independent(village) and #state.players == 2)
p.explored[W.key(village.x, village.y)] = true
assert(V.envoy(state, p, village))
assert(not V.envoy(state, p, village))
state.round = 6
assert(V.envoy(state, p, village))
assert(village.influence[1] == 20)
assert(S.exchange(state, p, "horses") == false)
V.defended(state, 1, village.x, village.y)
V.defended(state, 1, village.x, village.y)
assert(V.ally(village) == 1)
local effect = V.effects(state, p)
assert(effect.food + effect.science + effect.industry == 2)
village.influence[2] = 50
assert(V.ally(village) == 2)
village.owner = 1
assert(not V.independent(village) and V.ally(village) == nil)
-- Guards do not attack peaceful players; local monster kills earn village influence.
state, p, city = fixture()
M.generate(state)
V.generate(state)
S.migrate(state)
for _, c in ipairs(state.cities) do
  if c.village then
    village = c
    break
  end
end
local guard
for _, u in ipairs(state.units) do
  if u.villageGuard == village.id then
    guard = u
  end
end
local visitor = { id = 200, owner = 1, kind = "warrior", x = village.x + 1, y = village.y, hp = 100 }
state.units[#state.units + 1] = visitor
V.round(state, S, C)
assert(visitor.hp == 100, "Peaceful visitors are safe from village guards")
local monster = { id = 201, owner = M.owner, kind = "zombie", x = village.x + 1, y = village.y, hp = 1 }
visitor.kind = "diamondguard"
visitor.x = village.x + 2
state.units[#state.units + 1] = monster
state.round = 2
assert(C.attack(state, visitor, { x = monster.x, y = monster.y }, S))
assert((village.influence[1] or 0) == 10)
p.explored[W.key(village.x, village.y)] = true
p.visible = {}
village.influence[2] = 50
local diplomatic = W.forPlayer(state, 1)
local public
for _, c in ipairs(diplomatic.cities) do
  if c.id == village.id then
    public = c
  end
end
assert(public and public.remoteVillage and public.hp == nil and public.influence[2] == nil and public.publicAlly == 2)
assert(
  V.ally(public) == 2,
  "Network alliance calculation must not mistake private relation filtering for an alliance change"
)
-- Observer snapshots conceal unseen hostiles, landmarks, rails, and private relations.
state, p, city = fixture()
p.explored = { ["3:4"] = true }
p.visible = { ["3:4"] = true }
state.world.landmarks["12:7"] = { kind = "amethyst", natural = true }
state.world.rails["12:7"] = true
state.spawners = { { id = 1, x = 12, y = 7 } }
state.units = { { id = 4, owner = M.owner, kind = "zombie", x = 12, y = 7 } }
local view = W.forPlayer(state, 1)
assert(not view.world.landmarks["12:7"] and not view.world.rails["12:7"] and #view.spawners == 0 and #view.units == 0)
local original = state.world.tiles["12:7"]
state.ruleset = nil
state.version = 5
state.roundLimit = nil
state.hostileMode = nil
state.spawners = nil
S.migrate(state)
S.migrate(state)
W.migrate(state)
assert(
  state.ruleset == "legacy"
    and state.roundLimit == 90
    and state.hostileMode == "off"
    and state.spawners == nil
    and state.world.tiles["12:7"] == original
)
local failures = 0
for _, size in ipairs({ "compact", "standard", "large" }) do
  for _, kind in ipairs(W.types) do
    for count = 2, 4 do
      for _, seed in ipairs({ 1, 75123, 999999 }) do
        local world = W.generate(seed, size, count, kind)
        local state = { world = world, nextId = 10, hostileMode = "standard", cities = {}, units = {} }
        for i, start in ipairs(world.starts) do
          state.cities[#state.cities + 1] = { id = i, owner = i, x = start.x, y = start.y }
        end
        M.generate(state)
        V.generate(state)
        local villages = #state.cities - count
        local landmarks = 0
        for _ in pairs(world.landmarks) do
          landmarks = landmarks + 1
        end
        if villages == 0 or landmarks < 6 or #state.spawners == 0 then
          failures = failures + 1
          print(size, kind, count, seed, "villages", villages, "landmarks", landmarks, "camps", #state.spawners)
        end
      end
    end
  end
end
assert(failures == 0, "New-world content missing from " .. failures .. " presets")
print("CIVCRAFT expansion: content, chains, wonders, rails, mobs, villages, victories, fog and migration passed.")
