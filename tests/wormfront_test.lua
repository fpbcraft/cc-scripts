-- WORMFRONT v0.2 rules: deterministic maps, time-based turns and ballistics.
local Sim = dofile("games/wormfront/sim.lua")
local function map(g)
	return table.concat(g.terrain, ",")
end
for teams = 2, 4 do
	local g = Sim.new(teams, 1234)
	assert(g.phase == "playing" and g.teams == teams)
	assert(#g.worms == teams * 3 and #g.items >= 1)
	assert(g.turnLeft == Sim.TURN_SECONDS)
	for x = 1, Sim.W do
		assert(#g.terrain[x] == Sim.H)
	end
	local same = Sim.new(teams, 1234)
	assert(map(g) == map(same) and g.theme == same.theme)
	assert(g.items[1].kind == same.items[1].kind and g.items[1].x == same.items[1].x)
	for team = 1, teams do
		assert(g.selected[team] and g.worms[g.selected[team]].team == team)
	end
end
assert(map(Sim.new(2, 4)) ~= map(Sim.new(2, 5)), "Maps should vary between seeds")

local g = Sim.new(2, 77)
local worm = Sim.worm(g)
assert(not Sim.apply(g, 2, { kind = "charge" }), "Opponent cannot fire")
assert(not Sim.apply(g, 1, { kind = "move", dir = 50 }))
assert(not Sim.apply(g, 1, { kind = "teleport" }))
local beforeAim = worm.aim
assert(Sim.apply(g, 1, { kind = "aim", dir = 1 }))
assert(worm.aim == beforeAim + 3)
assert(Sim.apply(g, 1, { kind = "setAim", angle = 123 }))
assert(worm.aim == 123)
assert(not Sim.apply(g, 1, { kind = "setAim", angle = math.huge }))
assert(not Sim.apply(g, 1, { kind = "setAim", angle = -99 }))

-- Movement no longer has a four-step quota; movement is timer-limited.
local flat = (".."):rep(11) .. ("#"):rep(Sim.H - 22)
for x = 1, Sim.W do
	g.terrain[x] = flat
end
worm.x, worm.y = 10, 22
worm.hp = 55
g.items = { { x = 11, y = 22, kind = "MEDKIT" }, { x = 18, y = 22, kind = "AMMO" } }
assert(Sim.apply(g, 1, { kind = "move", dir = 1 }))
assert(worm.hp == 85 and #g.items == 1)
for _ = 1, 5 do
	assert(Sim.apply(g, 1, { kind = "move", dir = 1 }))
end
assert(worm.x == 16)
worm.facing = 1
assert(Sim.apply(g, 1, { kind = "jump" }))
assert(worm.airborne)
assert(not Sim.apply(g, 1, { kind = "jump" }))
for _ = 1, 28 do
	Sim.tick(g, 0.05)
end
assert(not worm.airborne, "Jump should land")
assert(worm.x > 16, "Jump should move the worm")
assert(worm.y == 22)

-- A charge is held for real elapsed time. Release starts an animated flight.
assert(Sim.apply(g, 1, { kind = "weapon" }))
assert(worm.weapon == 2)
assert(Sim.apply(g, 1, { kind = "charge" }))
Sim.tick(g, 0.6)
assert(g.charging and g.charge >= 0.59)
assert(not Sim.apply(g, 1, { kind = "move", dir = 1 }), "No walking while charging")
assert(Sim.apply(g, 1, { kind = "release" }))
assert(g.state == "flight" and not g.charging and worm.mega == 1)
assert(g.projectile and g.projectile.vx)
assert(not Sim.apply(g, 1, { kind = "aim", dir = 1 }))
local steps = 0
while g.phase == "playing" and g.turn == 1 and steps < 300 do
	Sim.tick(g, 0.05)
	steps = steps + 1
end
assert(g.turn == 2 or g.phase == "finished", "Animated shot must finish")
assert(steps > 3, "Projectile must animate over more than a frame")
assert(not Sim.apply(g, 1, { kind = "charge" }))

local timed = Sim.new(2, 9)
timed.turnLeft = 0.25
Sim.tick(timed, 0.3)
assert(timed.turn == 2 and timed.turnLeft == Sim.TURN_SECONDS, "Timeout must pass the turn")

local tapped = Sim.new(2, 77)
assert(Sim.apply(tapped, 1, { kind = "fire" }))
Sim.tick(tapped, 0.3)
assert(Sim.apply(tapped, 1, { kind = "fire" }))
assert(tapped.state == "flight", "Two touchscreen taps should charge then release")

local noAmmo = Sim.new(2, 9)
local selected = Sim.worm(noAmmo)
selected.weapon, selected.mega = 2, 0
assert(not Sim.apply(noAmmo, 1, { kind = "charge" }))
assert(noAmmo.turn == 1)

local won = Sim.new(2, 23)
for _, target in ipairs(won.worms) do
	if target.team == 2 then
		target.hp = 0
	end
end
assert(Sim.apply(won, 1, { kind = "pass" }))
assert(won.phase == "finished" and won.winner == 1)
assert(not Sim.apply(won, 1, { kind = "charge" }))
print("WORMFRONT: seeded maps, pickups, jumps, charged shots, timing and victory passed")
