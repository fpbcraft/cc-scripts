-- Exercise the actual host dispatcher and deterministic combat forecasts.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local S = dofile("games/civcraft/systems.lua")
local A = dofile("games/civcraft/actions.lua")
local C = dofile("games/civcraft/combat.lua")
local H = dofile("games/civcraft/hex.lua")
local W = dofile("games/civcraft/world.lua")
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = copy(v)
	end
	return out
end
local function equal(a, b)
	if type(a) ~= "table" then
		return a == b
	end
	if type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if not equal(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end
local function fixture()
	local world = {
		width = 18,
		height = 12,
		tiles = {},
		resources = {},
		landmarks = {},
		rails = {},
		starts = {},
	}
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[W.key(x, y)] = "plains"
		end
	end
	local state = {
		phase = "game",
		round = 1,
		version = 6,
		ruleset = "create",
		nextId = 10,
		world = world,
		players = {
			{ id = 1, name = "A", civ = "iron", techs = {} },
			{
				id = 2,
				name = "B",
				civ = "verdant",
				techs = {},
			},
		},
		cities = {
			{ id = 1, owner = 1, x = 3, y = 4, population = 2, buildings = {} },
			{ id = 2, owner = 2, x = 15, y = 9, population = 2, buildings = {} },
		},
		units = { { id = 3, owner = 1, kind = "settler", x = 7, y = 4, movesLeft = 3 } },
	}
	S.migrate(state)
	W.reveal(state, H, S)
	return state, state.units[1]
end
local function order(state, action, x, y, extra)
	local req = extra or {}
	req.action = action
	req.x = x
	req.y = y
	return A.apply(state, 1, req, S)
end
-- The same dispatcher rejects exhausted human and AI settlers without consumption.
for _, ai in ipairs({ false, true }) do
	local state, u = fixture()
	state.players[1].ai = ai
	u.movesLeft = 0
	u.standby = true
	assert(not order(state, "found", u.x, u.y))
	assert(#state.units == 1 and #state.cities == 2 and u.standby)
	u.movesLeft = 1
	assert(order(state, "found", u.x, u.y))
	assert(#state.units == 0 and #state.cities == 3)
	assert(state.cities[3].owner == 1 and state.cities[3].claimed)
end
local state, u = fixture()
assert(S.units.settler.move == 3)
for _, kind in ipairs({ "plains", "forest", "hills" }) do
	state.world.tiles["8:4"] = kind
	assert(H.moveCost(8, 4, state, u, S) == 1)
	u.kind = "horseman"
	assert(H.moveCost(8, 4, state, u, S) == (kind == "plains" and 1 or 2))
	u.kind = "settler"
end
state.world.tiles["8:4"] = "mountain"
assert(H.moveCost(8, 4, state, u, S) == nil)
state.world.tiles["8:4"] = "forest"
u.standby = true
u.healing = true
assert(not order(state, "move", 15, 8, { sx = 7, sy = 4 }))
assert(u.standby and u.healing)
assert(order(state, "move", 8, 4, { sx = 7, sy = 4 }))
assert(u.movesLeft == 2 and not u.standby and not u.healing)
assert(not order(state, "move", 8.5, 4, { sx = 8, sy = 4 }))
state.players[1].ready = true
assert(not order(state, "found", 8, 4))
state.players[1].ready = false
assert(not A.apply(state, 2, { action = "found", x = 8, y = 4 }, S))
-- Authoritative movement must not offer or execute attacks on concealed units.
state, u = fixture()
u.kind = "warrior"
state.units[2] = { id = 4, owner = 2, kind = "warrior", x = 8, y = 4, hp = 100 }
state.players[1].visible = {}
for _, dest in ipairs(H.reachable(state, u, 1, S)) do
	assert(not dest.attack)
end
assert(not order(state, "move", 8, 4, { sx = 7, sy = 4 }))
state.players[1].visible["8:4"] = true
assert(order(state, "move", 8, 4, { sx = 7, sy = 4 }))
-- AI founding cannot bypass movement requirements or skip the next unit after consumption.
state, u = fixture()
state.players[1].ai = true
u.movesLeft = 0
S.aiTurn(state, state.players[1], H)
assert(#state.cities == 2)
state, u = fixture()
state.players[1].ai = true
u.movesLeft = 1
state.units[2] = { id = 4, owner = 1, kind = "settler", x = 11, y = 4, movesLeft = 1 }
S.aiTurn(state, state.players[1], H)
assert(#state.cities == 4 and #state.units == 0)
-- Paused projects keep their work across production and resume selection.
state, u = fixture()
local city, p = state.cities[1], state.players[1]
assert(order(state, "queue", city.x, city.y, { kind = "unit", id = "scout" }))
city.project.progress = 3
assert(order(state, "queue", city.x, city.y, { kind = "none" }))
assert(not city.project and city.productionIdle)
S.production(state, H)
assert(city.projectProgress["unit:scout"] == 3 and not city.project)
assert(order(state, "queue", city.x, city.y, { kind = "unit", id = "scout" }))
assert(city.project.progress == 3 and not city.productionIdle)
-- Additive migration retains paused production, stored moves and old geography.
assert(order(state, "queue", city.x, city.y, { kind = "none" }))
u.movesLeft = 2
local geography = copy(state.world)
S.migrate(state)
assert(u.movesLeft == 2 and city.productionIdle and city.projectProgress["unit:scout"] == 3)
assert(equal(geography, state.world), "Rules migration rerolled the saved world")
-- Passive healing is owned-only; support healing works in neutral and hostile territory.
state, u = fixture()
u.hp = 40
u.healing = true
C.round(state, S)
assert(u.hp == 40)
u.x = 3
u.y = 4
C.round(state, S)
assert(u.hp == 60)
u.x = 15
u.y = 9
C.round(state, S)
assert(u.hp == 60)
local healerKind
for kind, stats in pairs(S.units) do
	if stats.healer then
		healerKind = kind
		break
	end
end
assert(healerKind)
state.units[2] = { id = 4, owner = 1, kind = healerKind, x = 14, y = 9, hp = 100 }
C.round(state, S)
assert(u.hp == 70)
-- Forecast is pure even on unmigrated HP/XP/walls, and matches actual resolution.
local combinations = 0
for _, kind in ipairs({ "warrior", "archer", "spearman", "diamondguard", "creeper" }) do
	for _, hp in ipairs({ 1, 30, 100 }) do
		for _, targetHP in ipairs({ 1, 40, 100 }) do
			for _, walls in ipairs({ false, true }) do
				for _, isCity in ipairs({ false, true }) do
					state, u = fixture()
					u.kind = kind
					u.x = 10
					u.y = 8
					u.hp = hp
					u.level = nil
					u.xp = nil
					u.maxHP = nil
					local defender =
						{ id = 4, owner = 2, kind = "horseman", x = 11, y = 8, hp = targetHP }
					state.units[2] = defender
					local target = defender
					if isCity then
						target = state.cities[2]
						target.x = 11
						target.y = 8
						target.hp = targetHP
						target.buildings = walls and { walls = true } or {}
						target.maxWalls = nil
						target.wallHP = nil
					end
					local before = copy(state)
					local predicted = assert(C.predict(state, u, target, S))
					assert(equal(before, state), "Forecast mutated state")
					local ok, _, actual = C.attack(state, u, target, S)
					assert(ok and equal(predicted, actual))
					assert(u.hp == predicted.attackerHP)
					if isCity then
						assert(
							target.hp == predicted.cityHP
								and target.wallHP == predicted.wallHP
								and (target.owner == 1) == predicted.captured
						)
					else
						assert(defender.hp == predicted.defenderHP)
					end
					combinations = combinations + 1
				end
			end
		end
	end
end
print(
	"CIVCRAFT: shared commands, founding, wake, movement, production, healing and "
		.. combinations
		.. " pure combat forecasts passed."
)
