local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local A = dofile("/games/civcraft/actions.lua")
local C = dofile("/games/civcraft/combat.lua")
local D = dofile("/games/civcraft/diplomacy.lua")
local E = dofile("/games/civcraft/events.lua")
local H = dofile("/games/civcraft/hex.lua")
local S = dofile("/games/civcraft/systems.lua")
local W = dofile("/games/civcraft/world.lua")
local Z = dofile("/games/civcraft/zone_control.lua")
local function fixture(kind, x, budget)
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		players = {},
		units = {},
		cities = {},
		world = { width = 14, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} },
	}
	for id = 1, 3 do
		state.players[id] = { id = id, name = "PLAYER " .. id, techs = { navigation = true } }
	end
	for y = 1, 10 do
		for xx = 1, 14 do
			state.world.tiles[W.key(xx, y)] = "plains"
		end
	end
	state.units = {
		{ id = 1, owner = 1, x = x or 3, y = 4, kind = kind or "warrior", movesLeft = budget or 4 },
		{ id = 2, owner = 2, x = 5, y = 4, kind = "warrior", movesLeft = 2 },
	}
	S.migrate(state)
	W.reveal(state, H, S)
	return state, state.units[1], state.units[2]
end
local function choice(state, unit, x, y)
	for _, point in ipairs(H.reachable(state, unit, 1, S)) do
		if point.x == x and point.y == y then
			return point
		end
	end
end
-- An in-place attack is not a fresh entry into control.
local still, attacker, defender = fixture("warrior", 4, 2)
assert(not Z.locked(still, attacker, S))
assert(A.apply(still, 1, { action = "move", sx = 4, sy = 4, x = 5, y = 4 }, S))
assert(attacker.x == 4 and defender.hp > 0 and attacker.movesLeft == 1)
assert(not Z.locked(still, attacker, S) and choice(still, attacker, 3, 4))
assert(A.apply(still, 1, { action = "move", sx = 4, sy = 4, x = 3, y = 4 }, S))
assert(attacker.movesLeft == 0)
local advancing, captor, victim = fixture("warrior", 4, 2)
victim.hp = 1
advancing.units[#advancing.units + 1] =
	{ id = 3, owner = 2, kind = "warrior", x = 6, y = 4, hp = 100, movesLeft = 2 }
W.reveal(advancing, H, S)
assert(A.apply(advancing, 1, { action = "move", sx = 4, sy = 4, x = 5, y = 4 }, S))
assert(
	captor.x == 5 and captor.movesLeft == 1 and Z.locked(advancing, captor, S),
	"A real combat advance into another enemy's control still locks movement"
)
local state, unit, enemy = fixture()
assert(choice(state, unit, 4, 4).zoneStop)
assert(
	choice(state, unit, 5, 4).attack,
	"Military units may enter control and attack with remaining movement"
)
assert(A.apply(state, 1, { action = "move", sx = 3, sy = 4, x = 4, y = 4 }, S))
assert(unit.movesLeft == 3 and Z.locked(state, unit, S))
for _, point in ipairs(H.reachable(state, unit, 1, S)) do
	assert(point.attack, "Entry locks further movement, not legal attacks")
end
local snapshot = W.forPlayer(state, 1)
assert(
	Z.locked(snapshot, snapshot.units[1], S),
	"Own control lock survives private snapshots and save data"
)
local forecast = C.predictOrder(state, unit, choice(state, unit, 5, 4), S)
assert(forecast)
assert(A.apply(state, 1, { action = "move", sx = 4, sy = 4, x = 5, y = 4 }, S))
assert(unit.hp == forecast.attackerHP and enemy.hp == forecast.defenderHP)
state.round = 2
unit.attackedRound = nil
assert(choice(state, unit, 3, 4), "A fresh turn may leave a zone it started in")

state, unit = fixture("settler")
state.units[#state.units + 1] = { id = 4, owner = 1, x = 3, y = 6, kind = "scout", movesLeft = 0 }
W.reveal(state, H, S)
assert(choice(state, unit, 4, 4).cost == unit.movesLeft)
assert(A.apply(state, 1, { action = "move", sx = 3, sy = 4, x = 4, y = 4 }, S))
assert(unit.movesLeft == 0 and unit.moved, "Civilian entry exhausts remaining movement")
state, unit = fixture("horseman", 2, 8)
assert(next(Z.map(state, unit, S, H)) == nil)
assert(choice(state, unit, 6, 5), "Mounted units ignore control while respecting occupied hexes")

state, unit, enemy = fixture()
enemy.kind = "archer"
assert(not Z.map(state, unit, S, H)["4:4"], "Ordinary ranged land units do not exert control")
enemy.kind = "warrior"
state.diplomacy = D.new()
assert(next(Z.map(state, unit, S, H)) == nil, "Peaceful forces exert no hostile control")
state.diplomacy = nil
state.players[1].visible = {}
assert(next(Z.map(state, unit, S, H)) == nil, "Hidden forces do not leak control through previews")
state.units = { unit }
state.cities = { { id = 3, owner = 2, x = 5, y = 4, population = 2, buildings = {} } }
state.players[1].visible = { ["5:4"] = true }
assert(Z.map(state, unit, S, H)["4:4"], "Visible hostile cities exert control")
state, unit, enemy = fixture("galley", 3, 8)
state.world.tiles["3:4"], state.world.tiles["5:4"], state.world.tiles["6:4"] =
	"water", "water", "water"
enemy.kind = "galley"
state.players[1].visible["5:4"] = true
local controlled = Z.map(state, unit, S, H)
assert(controlled["6:4"] and not controlled["5:3"], "Naval control stays in water")
unit.kind = "warrior"
enemy.kind = "warrior"
controlled = Z.map(state, unit, S, H)
assert(
	not controlled["6:4"] and controlled["5:3"],
	"Embarked land melee controls adjacent land, not water"
)

-- A long route is valid with current knowledge, then stops when a hidden guard is discovered.
state, unit, enemy = fixture("warrior", 2, 8)
enemy.x = 6
W.reveal(state, H, S)
local planned = choice(state, unit, 8, 4)
assert(planned and not planned.attack)
local projected = W.forPlayer(state, 1)
assert(
	choice(projected, projected.units[1], 8, 4),
	"Host and observer can plan the same unknown route"
)
assert(A.apply(state, 1, { action = "move", sx = 2, sy = 4, x = 8, y = 4 }, S))
assert(
	unit.x ~= 8 and H.distance(unit.x, unit.y, enemy.x, enemy.y) == 1 and Z.locked(state, unit, S)
)
assert(
	unit.movesLeft > 0 and unit.movesLeft < 8,
	"Interrupted movement charges actual traversed terrain"
)
local events = E.forPlayer(state, 1).entries
local movement
for _, event in ipairs(events) do
	if event.type == "move" then
		movement = event
	end
end
assert(
	movement and movement.paths[1][#movement.paths[1]].x == unit.x,
	"Replay freezes the actual stop, never the planned destination"
)
assert(unit.movesLeft == 8 - (#movement.paths[1] - 1), "Only traversed plains hexes are charged")
assert(E.forPlayer(state, 3).lastSeq == 0)

-- An unseen flank guard interrupts the approach before a visible distant target is attacked.
state, unit, enemy = fixture("warrior", 1, 13)
enemy.x = 10
state.units[#state.units + 1] = { id = 3, owner = 1, kind = "scout", x = 12, y = 4, movesLeft = 0 }
state.units[#state.units + 1] = { id = 4, owner = 3, kind = "warrior", x = 6, y = 4, movesLeft = 0 }
W.reveal(state, H, S)
local attack = choice(state, unit, 10, 4)
assert(attack and attack.attack and C.predictOrder(state, unit, attack, S))
assert(A.apply(state, 1, { action = "move", sx = 1, sy = 4, x = 10, y = 4 }, S))
assert(
	enemy.hp == 100 and not unit.attackedRound and unit.movesLeft > 13 - attack.cost,
	"Interrupted approaches neither teleport attacks nor spend an unused attack"
)
for _, event in ipairs(E.forPlayer(state, 1).entries) do
	assert(event.type ~= "combat")
end
print(
	"CIVCRAFT: control locks, legal attacks, civilian exhaustion, cavalry/domain/peace exceptions, private previews and discovered-route interruptions passed."
)
