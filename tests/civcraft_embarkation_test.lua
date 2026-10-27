local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local A = dofile("/games/civcraft/actions.lua")
local C = dofile("/games/civcraft/combat.lua")
local H = dofile("/games/civcraft/hex.lua")
local M = dofile("/games/civcraft/movement_budget.lua")
local S = dofile("/games/civcraft/systems.lua")
local T = dofile("/games/civcraft/threats.lua")
local W = dofile("/games/civcraft/world.lua")
local function fixture(kind, x, enemyKind, enemyX)
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		players = {
			{ id = 1, name = "ONE", civ = "iron", techs = { navigation = true } },
			{ id = 2, name = "TWO", civ = "forge", techs = {} },
		},
		cities = {},
		units = {},
		world = { width = 16, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} },
	}
	for y = 1, 10 do
		for xx = 1, 16 do
			state.world.tiles[W.key(xx, y)] = xx <= 10 and "water" or "plains"
		end
	end
	state.units = { { id = 1, owner = 1, x = x, y = 5, kind = kind, movesLeft = 2 } }
	if enemyKind then
		state.units[2] = { id = 2, owner = 2, x = enemyX, y = 5, kind = enemyKind, movesLeft = 2 }
	end
	S.migrate(state)
	W.reveal(state, H, S)
	return state, state.units[1], state.units[2]
end
local function reset(state, unit)
	M.reset(state, unit, S.units[unit.kind], state.players[unit.owner], H)
end
local function find(state, unit, x, y)
	for _, point in ipairs(H.reachable(state, unit, unit.owner, S)) do
		if point.x == x and point.y == y then
			return point
		end
	end
end
local state, unit = fixture("warrior", 3)
reset(state, unit)
assert(
	unit.movesLeft == 6 and find(state, unit, 9, 5).cost == 6 and not find(state, unit, 10, 5),
	"A sea-start unit has six one-point water steps"
)
state, unit = fixture("warrior", 8)
reset(state, unit)
assert(A.apply(state, 1, { action = "move", sx = 8, sy = 5, x = 10, y = 5 }, S))
assert(unit.movesLeft == 4 and H.moveCost(9, 5, state, unit, S) == 1)
assert(find(state, unit, 11, 5).cost == 4)
assert(A.apply(state, 1, { action = "move", sx = 10, sy = 5, x = 11, y = 5 }, S))
assert(
	unit.movesLeft == 0 and unit.moved and not find(state, unit, 12, 5),
	"Landing exhausts the sea allowance"
)
state.round = 2
reset(state, unit)
assert(unit.movesLeft == S.units.warrior.move and unit.waterMovementRound == nil)
assert(A.apply(state, 1, { action = "move", sx = 11, sy = 5, x = 10, y = 5 }, S))
assert(
	unit.movesLeft == 0 and unit.waterMovementRound == nil,
	"Embarking mid-turn does not grant sea movement"
)
S.migrate(state)
assert(unit.movesLeft == 0, "Loading/migrating never replenishes an embarked unit")
state.round = 3
reset(state, unit)
assert(unit.movesLeft == 6)
assert(A.apply(state, 1, { action = "move", sx = 10, sy = 5, x = 9, y = 5 }, S))
state.scheduler =
	{ version = 1, groups = {}, reactions = { [1] = true }, reactionGranted = { [1] = true } }
assert(
	unit.movesLeft == 5 and H.moveCost(8, 5, state, unit, S) == 1,
	"A response keeps unspent sea movement without a second allowance"
)

state, unit = fixture("scout", 11)
reset(state, unit)
assert(A.apply(state, 1, { action = "move", sx = 11, sy = 5, x = 10, y = 5 }, S))
local unspent = unit.movesLeft
M.response(state, unit, S.units.scout, state.players[1], H)
assert(
	unit.movesLeft == unspent and H.moveCost(9, 5, state, unit, S) == 1,
	"A response starting at sea uses the sea rate but never grants fresh movement"
)
unit.x = 11
M.response(state, unit, S.units.scout, state.players[1], H)
assert(unit.movesLeft == unspent, "Repeated activation cannot regenerate movement")

for _, kind in ipairs({ "warrior", "archer" }) do
	local enemy
	state, unit, enemy = fixture(kind, 10, "warrior", 11)
	reset(state, unit)
	local attack = find(state, unit, 11, 5)
	assert(attack and attack.attack and not attack.ranged and attack.cost == 6)
	local forecast = assert(C.predictOrder(state, unit, attack, S))
	assert(
		not forecast.ranged and forecast.retaliation > 0,
		"Embarked combat units attack land in melee and receive retaliation"
	)
	assert(A.apply(state, 1, { action = "move", sx = 10, sy = 5, x = 11, y = 5 }, S))
	assert(
		unit.hp == forecast.attackerHP and enemy.hp == forecast.defenderHP and unit.movesLeft == 0
	)
end
local enemy
state, unit, enemy = fixture("warrior", 11, "warrior", 10)
reset(state, unit)
assert(not find(state, unit, 10, 5) and not C.predict(state, unit, { x = 10, y = 5 }, S))
assert(
	not A.apply(state, 1, { action = "move", sx = 11, sy = 5, x = 10, y = 5 }, S),
	"Land melee cannot initiate an attack on embarked units"
)
assert(
	T.at(T.build(state, state.players[2], S), 10, 5, enemy).attackers == 0,
	"Threat forecasts also exclude shore melee attacks"
)
state, unit, enemy = fixture("archer", 11, "warrior", 10)
state.players[1].techs.navigation = nil
reset(state, unit)
local attack = assert(find(state, unit, 10, 5))
assert(attack.attack and attack.ranged)
local forecast = assert(C.predictOrder(state, unit, attack, S))
assert(forecast.retaliation == 0)
assert(A.apply(state, 1, { action = "move", sx = 11, sy = 5, x = 10, y = 5 }, S))
assert(
	enemy.hp == forecast.defenderHP and unit.hp == 100,
	"Land ranged attacks do not require Navigation"
)
assert(T.at(T.build(state, state.players[2], S), 10, 5, enemy).attackers == 1)

state, unit, enemy = fixture("warrior", 11, "warrior", 10)
local view = W.forPlayer(state, 1)
assert(view.units[2].publicEmbarked and not view.players[2].techs)
local threats = T.build(view, state.players[1], S)
assert(
	threats.entries[1].moves == 6 and T.at(threats, 11, 5, unit).attackers == 1,
	"Visible embarked enemies have the same future sea allowance and amphibious threat"
)
assert(
	not view.players[2].techs,
	"Public embarkation is inferred without revealing the enemy technology tree"
)
state, unit = fixture("warrior", 10)
state.cities = { { id = 5, owner = 2, x = 11, y = 5, population = 2, hp = 1, buildings = {} } }
S.migrate(state)
W.reveal(state, H, S)
reset(state, unit)
assert(A.apply(state, 1, { action = "move", sx = 10, sy = 5, x = 11, y = 5 }, S))
assert(
	state.cities[1].owner == 1 and unit.x == 11 and unit.movesLeft == 0,
	"A surviving amphibious melee attacker can capture a coastal city"
)
print(
	"CIVCRAFT: six-hex sea allowance, landing budget, no load/response refresh, amphibious melee, shore restrictions, ranged fire, threat parity and coastal capture passed."
)
