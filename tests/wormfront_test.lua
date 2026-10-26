local Sim = dofile("games/wormfront/sim.lua")
local function terrain(g)
  return table.concat(g.terrain, ",")
end
for teams = 2, 4 do
  local g = Sim.new(teams, 2026)
  local other = Sim.new(teams, 2026)
  assert(g.version == 3 and Sim.W == 144 and Sim.H == 60)
  assert(terrain(g) == terrain(other), "Maps must reproduce by seed")
  assert(#g.worms == teams * 3 and #g.items >= 1)
  assert(g.items[1].x == other.items[1].x)
  local platforms = 0
  for x = 1, Sim.W do
    assert(#g.terrain[x] == Sim.H)
    for y = 1, Sim.H do
      if g.terrain[x]:sub(y, y) == "=" then
        platforms = platforms + 1
      end
    end
  end
  assert(platforms > 0, "Random map must contain elevated platforms")
  for team = 1, teams do
    local items = g.inventory[team]
    assert(items[1] == -1, "Each team starts with only a bazooka")
    for id = 2, #Sim.weapons do
      assert(items[id] == nil, "Special weapons must be collected")
    end
  end
end
assert(terrain(Sim.new(2, 1)) ~= terrain(Sim.new(2, 2)))
assert(#Sim.weapons == 10, "All ten weapon types must be registered")

local g = Sim.new(2, 44)
local first1 = g.selected[1]
local first2 = g.selected[2]
assert(not Sim.apply(g, 1, { kind = "select" }), "Worm switching disabled")
assert(not Sim.apply(g, 2, { kind = "pass" }), "Only current team can act")
assert(not Sim.apply(g, 1, { kind = "weapon", id = 3 }), "No special weapons at spawn")
assert(not Sim.apply(g, 1, { kind = "rope", x = math.huge, y = 5 }))
assert(Sim.apply(g, 1, { kind = "pass" }))
assert(g.turn == 2 and g.selected[2] == first2, "Team 2 must use first worm")
assert(Sim.apply(g, 2, { kind = "pass" }))
assert(g.turn == 1 and g.selected[1] ~= first1, "Next round uses next worm")
local second = g.selected[1]
assert(Sim.apply(g, 1, { kind = "pass" }))
assert(Sim.apply(g, 2, { kind = "pass" }))
assert(g.selected[1] ~= second, "Third worm is next")
assert(Sim.apply(g, 1, { kind = "pass" }))
assert(Sim.apply(g, 2, { kind = "pass" }))
assert(g.selected[1] == first1, "Rotation must wrap back to first living worm")

local timed = Sim.new(2, 55)
timed.turnLeft = 0.2
Sim.tick(timed, 0.3)
assert(timed.turn == 2 and timed.turnLeft > Sim.TURN_SECONDS - 0.2)

-- Weapon pickups grant the owning team ammunition, not each individual worm.
local loot = Sim.new(2, 80)
local w = Sim.worm(loot)
loot.items = { { x = w.x + 1, y = w.y, kind = "WEAPON", weapon = 3 } }
-- Make a convenient flat path to pick the weapon up.
local base = w.y + 1
for x = math.floor(w.x), math.floor(w.x + 2) do
  loot.terrain[x] = ("."):rep(base - 1) .. ("#"):rep(Sim.H - base + 1)
end
assert(Sim.apply(loot, 1, { kind = "move", dir = 1 }))
assert(loot.inventory[1][3] == Sim.weapons[3].gift)
assert(Sim.apply(loot, 1, { kind = "weapon", id = 3 }))
assert(Sim.worm(loot).weapon == 3)

local shot = Sim.new(2, 99)
local shooter = Sim.worm(shot)
assert(Sim.apply(shot, 1, { kind = "charge" }))
Sim.tick(shot, 0.3)
Sim.tick(shot, 0.3)
assert(shot.charge >= 0.55)
assert(not Sim.apply(shot, 1, { kind = "move", dir = 1 }), "Charging blocks walking")
assert(Sim.apply(shot, 1, { kind = "release" }))
assert(shot.state == "flight" and shot.projectile.weapon == 1)
for _ = 1, 260 do
  if shot.turn ~= 1 or shot.phase == "finished" then
    break
  end
  Sim.tick(shot, 0.06)
end
assert(shot.turn == 2 or shot.phase == "finished", "Projectile flight eventually completes")

-- Ropes attach to actual collidable terrain, respect length and detach.
local rope = Sim.new(2, 77)
local unit = Sim.worm(rope)
local top = math.floor(unit.y - 12)
local x = math.floor(unit.x)
local col = rope.terrain[x]
rope.terrain[x] = col:sub(1, top - 1) .. "=" .. col:sub(top + 1)
assert(Sim.apply(rope, 1, { kind = "rope", x = x, y = top }))
assert(unit.rope and unit.airborne)
local length = unit.rope.length
assert(Sim.apply(rope, 1, { kind = "reel", dir = -1 }))
assert(unit.rope.length < length)
assert(Sim.apply(rope, 1, { kind = "move", dir = 1 }))
for _ = 1, 20 do
  Sim.tick(rope, 0.05)
end
assert(unit.rope and unit.x >= 1 and unit.x <= Sim.W)
assert(Sim.apply(rope, 1, { kind = "rope" }))
assert(not unit.rope)

-- Every special weapon has a real action and bounded ammo consumption.
for id = 2, #Sim.weapons do
  local weaponGame = Sim.new(2, 150 + id)
  local actor = Sim.worm(weaponGame)
  weaponGame.inventory[1][id] = 2
  assert(Sim.apply(weaponGame, 1, { kind = "weapon", id = id }))
  if id == 5 then
    assert(Sim.apply(weaponGame, 1, { kind = "setTarget", x = 66 }))
  end
  assert(Sim.apply(weaponGame, 1, { kind = "charge" }))
  Sim.tick(weaponGame, 0.2)
  assert(Sim.apply(weaponGame, 1, { kind = "release" }), Sim.weapons[id].name)
  assert(weaponGame.inventory[1][id] == 1)
  assert(weaponGame.state == "flight" or weaponGame.state == "blast")
end

local eliminated = Sim.new(2, 123)
for _, enemy in ipairs(eliminated.worms) do
  if enemy.team == 2 then
    enemy.hp = 0
  end
end
assert(Sim.apply(eliminated, 1, { kind = "pass" }))
assert(eliminated.phase == "finished" and eliminated.winner == 1)
assert(not Sim.apply(eliminated, 1, { kind = "pass" }))

print("WORMFRONT: rotation, larger maps, crates, arsenal, rope, wind and time passed")
