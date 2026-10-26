-- Pure-Lua regression coverage for WORMFRONT's authoritative rules.
local Sim = dofile("games/wormfront/sim.lua")
local function snapshot(g)
  return table.concat(g.terrain, ",")
end

for teams = 2, 4 do
  local g = Sim.new(teams, 1234)
  assert(g.phase == "playing" and g.teams == teams)
  assert(#g.worms == teams * 3)
  assert(#g.terrain == Sim.W)
  for x = 1, Sim.W do
    assert(#g.terrain[x] == Sim.H)
  end
  for team = 1, teams do
    assert(g.selected[team] and g.worms[g.selected[team]].team == team)
  end
  assert(snapshot(g) == snapshot(Sim.new(teams, 1234)), "Seed must reproduce terrain")
end

local g = Sim.new(2, 77)
local worm = Sim.worm(g)
assert(worm == g.worms[g.selected[1]])
assert(not Sim.apply(g, 2, { kind = "fire" }), "Opponent cannot fire")
assert(not Sim.apply(g, 1, { kind = "move", dir = 50 }), "Reject malformed movement")
assert(not Sim.apply(g, 1, { kind = "teleport" }), "Reject arbitrary actions")
local beforeAim = worm.aim
assert(Sim.apply(g, 1, { kind = "aim", dir = 1 }))
assert(worm.aim == beforeAim + 5)
assert(Sim.apply(g, 1, { kind = "power", dir = -1 }))
assert(worm.power == 60)
assert(Sim.apply(g, 1, { kind = "weapon" }))
assert(worm.weapon == 2 and worm.mega == 2)
assert(Sim.apply(g, 1, { kind = "fire" }))
assert(worm.mega == 1 and g.turn == 2 and g.round == 1)
assert(#g.trace > 0, "Shot must produce a trajectory")
assert(not Sim.apply(g, 1, { kind = "aim", dir = 1 }))
assert(Sim.apply(g, 2, { kind = "fire" }))
assert(g.turn == 1 and g.round == 2)

local endgame = Sim.new(2, 23)
for _, other in ipairs(endgame.worms) do
  if other.team == 2 then
    other.hp = 0
  end
end
assert(Sim.apply(endgame, 1, { kind = "fire" }))
assert(endgame.phase == "finished" and endgame.winner == 1)
assert(not Sim.apply(endgame, 1, { kind = "fire" }), "Finished matches are immutable")

local noAmmo = Sim.new(2, 9)
local unit = Sim.worm(noAmmo)
unit.weapon = 2
unit.mega = 0
assert(not Sim.apply(noAmmo, 1, { kind = "fire" }))
assert(noAmmo.turn == 1)
print("WORMFRONT terrain, turns, projectiles, authorization and victory: OK")
