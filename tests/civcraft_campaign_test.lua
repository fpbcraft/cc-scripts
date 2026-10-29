local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("games/civcraft/systems.lua")
local H = dofile("games/civcraft/hex.lua")
local W = dofile("games/civcraft/world.lua")
local C = dofile("games/civcraft/combat.lua")
local function campaign()
	local tiles = {}
	for y = 1, 8 do
		for x = 1, 12 do
			tiles[W.key(x, y)] = x >= 11 and "water" or "plains"
		end
	end
	-- Keep the opening city's food production equivalent to the previous
	-- 2-food plains rule using Civ VI grassland with Woods.
	for _, point in ipairs({ { 2, 3 }, { 3, 2 }, { 3, 4 }, { 4, 3 } }) do
		tiles[W.key(point[1], point[2])] = "forest"
	end
	local state = {
		version = 5,
		phase = "game",
		round = 1,
		nextId = 10,
		world = { width = 12, height = 8, tiles = tiles, resources = {}, seed = 12 },
		players = {
			{ id = 1, name = "A", civ = "verdant", techs = {}, gold = 20 },
			{
				id = 2,
				name = "B",
				civ = "iron",
				techs = {},
				gold = 20,
			},
		},
		cities = { { id = 1, owner = 1, x = 3, y = 3, population = 2, buildings = {} } },
		units = { { id = 3, owner = 1, x = 4, y = 3, kind = "warrior", movesLeft = 2 } },
	}
	S.migrate(state)
	W.reveal(state, H, S)
	return state, state.players[1], state.cities[1], state.units[1]
end
local state, p, city, u = campaign()
for _, civ in ipairs(S.civs) do
	local testPlayer = { civ = civ.id }
	local center = S.centerYields(testPlayer, city)
	assert(
		center.food == 2
			and center.industry == 1
			and center.science == (civ.id == "scholar" and 3 or 1),
		"City center includes base science and civilization bonuses"
	)
end
local originalCiv = p.civ
p.civ = "scholar"
city.buildings.library = true
local center = S.centerYields(p, city)
assert(center.science == 5, "City tile includes library science")
local sums = {
	food = center.food,
	industry = center.industry,
	science = center.science,
	gold = center.gold or 0,
}
for _, tile in ipairs(S.workable(state, city)) do
	if city.worked[tile.key] then
		for key, value in pairs(tile.yield) do
			sums[key] = sums[key] + value
		end
	end
end
local totals = S.yields(p, city, state, H)
for key, value in pairs(sums) do
	assert(totals[key] == value, "City map yield plus worked tiles equals inspector total")
end
p.civ = originalCiv
city.buildings.library = nil
assert(
	S.projectCost("unit", "warrior") > S.units.warrior.wood,
	"Projects require more industry than before"
)
local t = S.treasury(p, state)
assert(t.income == 4 and t.upkeep == 1 and t.net == 3)
S.production(state, H)
assert(p.gold == 23, "Treasury pays maintenance at the round boundary")
city.foodStore = 1000
city.growthAge = 0
for i = 1, 3 do
	S.production(state, H)
	assert(city.population == 2, "Stored food alone cannot bypass growth time")
end
S.production(state, H)
assert(city.population == 3)
city.population = 2
city.foodStore = 0
city.hungryTurns = 0
city.worked = {}
S.ensureWorkers(state, city)
assert(S.growth(p, city, state).status == "STARVING")
for i = 1, 3 do
	S.production(state, H)
end
assert(city.population == 1, "Sustained starvation reduces population")
state, p, city, u = campaign()
local function claimed()
	local n = 0
	for _ in pairs(city.claimed) do
		n = n + 1
	end
	return n
end
assert(claimed() == 7)
for i = 1, 6 do
	assert(not W.expandCity(state, H, city))
	assert(claimed() == 7)
end
assert(W.expandCity(state, H, city) and claimed() == 8, "Borders grow by one contiguous hex")
p.techs.sailing = true
assert(not S.canBuild(p, city, "shipyard", state), "Inland shipyards are forbidden")
local coast = { id = 2, owner = 1, x = 10, y = 3, population = 2, buildings = {} }
state.cities[2] = coast
S.migrate(state)
assert(S.canBuild(p, coast, "shipyard", state))
assert(not S.queue(p, coast, "unit", "galley", state, H), "Galleys require a shipyard")
coast.buildings.shipyard = true
assert(S.queue(p, coast, "unit", "galley", state, H))
u.x = 10
u.y = 4
u.movesLeft = 2
assert(not H.moveCost(11, 4, state, u, S))
p.techs.navigation = true
assert(H.moveCost(11, 4, state, u, S) == 2, "Navigation permits embarkation")
local target
for _, v in ipairs(H.reachable(state, u, 1, S)) do
	if v.x == 11 and v.y == 4 then
		target = v
	end
end
assert(
	target and target.cost == 2 and #target.path == 2,
	"Move preview contains the authoritative weighted route"
)
state, p, city, u = campaign()
local enemy = { id = 4, owner = 2, x = 5, y = 3, kind = "warrior", hp = 100, movesLeft = 2 }
state.units[2] = enemy
C.migrate(state)
u.xp = 9
local ok, why, result = C.attack(state, u, { x = 5, y = 3, cost = 1 }, S)
assert(
	ok and enemy.hp > 0 and enemy.hp < 100 and u.hp > 0 and u.hp < 100,
	"Melee exchanges damage without instant removal"
)
assert(
	result.retaliation > 0 and u.level == 2 and u.xp >= 10,
	"Combat grants experience and levels"
)
assert(not C.attack(state, u, { x = 5, y = 3, cost = 1 }, S), "One attack per round")
u.healing = true
local hp = u.hp
state.round = 2
C.round(state, S)
assert(u.hp > hp and u.hp <= 100, "Fortified units heal")
local town = { id = 2, owner = 2, x = 8, y = 3, population = 4, buildings = { walls = true } }
state.cities[2] = town
local siege = { id = 5, owner = 1, x = 6, y = 3, kind = "catapult", hp = 100 }
state.units[3] = siege
C.migrate(state)
local hp = town.hp
assert(C.attack(state, siege, { x = 8, y = 3, ranged = true }, S))
assert(
	town.wallHP < 100 and town.hp == hp and siege.hp == 100,
	"Siege damages walls without ranged retaliation"
)
state.round = 3
town.wallHP = 0
town.hp = 1
assert(C.attack(state, siege, { x = 8, y = 3, ranged = true }, S))
assert(town.owner == 2 and town.hp == 1, "Ranged units cannot capture a city")
state.round = 4
u.hp = 100
u.attackedRound = nil
assert(C.attack(state, u, { x = 8, y = 3 }, S))
assert(town.owner == 1 and u.x == 8 and u.y == 3, "A melee attack captures a defeated city")
state, p, city, u = campaign()
city.buildings.walls = true
state.units[2] = { id = 5, owner = 2, x = 5, y = 3, kind = "warrior" }
C.migrate(state)
W.reveal(state, H, S)
assert(C.strike(state, city, 5, 3, S))
assert(not C.strike(state, city, 5, 3, S), "Walled cities have one ranged strike per round")
state.cities = {}
p.gold = 0
S.production(state, H)
for _, v in ipairs(state.units) do
	assert(v.owner ~= 1, "Unpaid units disband rather than creating unlimited free armies")
end
state, p, city, u = campaign()
state.world.resources[W.key(city.x, city.y)] = "iron"
S.production(state, H)
assert(p.stockpile.iron == 1, "Owned strategic deposits accrue stock")
u.kind = "scout"
u.movesLeft = 3
u.moved = false
W.reveal(state, H, S)
local x, y = u.x, u.y
assert(S.autoExplore(state, u, H))
assert(
	u.autoExplore and (u.x ~= x or u.y ~= y) and u.movesLeft < 3,
	"Auto exploration follows a legal frontier route"
)
state, p, city, u = campaign()
assert(
	S.projectCost("unit", "scout", p) == 5 and S.projectCost("unit", "settler", p) == 12,
	"Early exploration and expansion are cheaper"
)
assert(S.research(p, "mining") and S.queue(p, city, "unit", "scout", state, H))
S.production(state, H)
assert(city.project, "Scout takes more than one starting round")
S.production(state, H)
assert(not city.project and not p.techs.mining, "A scout finishes before the first technology")
assert(S.queue(p, city, "unit", "settler", state, H))
for i = 1, 4 do
	S.production(state, H)
end
assert(
	p.settlersTrained == 1 and S.projectCost("unit", "settler", p) == 17,
	"Completed settlers increase the next cost empire-wide"
)
assert(not p.techs.mining, "First research is slower than early expansion")
for i = #state.units, 1, -1 do
	if state.units[i].kind == "settler" then
		table.remove(state.units, i)
	end
end
S.migrate(state)
assert(
	p.settlersTrained == 1 and S.projectCost("unit", "settler", p) == 17,
	"Loss and migration never reduce the trained count"
)
assert(S.queue(p, city, "unit", "settler", state, H))
assert(p.settlersTrained == 1, "Queueing does not charge the next settler cost")
assert(S.queue(p, city, "unit", "scout", state, H))
assert(p.settlersTrained == 1, "Changing a project does not increment trained settlers")
local other = state.players[2]
assert(S.projectCost("unit", "settler", other) == 12, "Each empire has its own settler scaling")
for i = 1, S.techCost("mining") do
	S.production(state, H)
end
assert(p.techs.mining, "Slower research still completes through accumulated science")
-- Simultaneous queues cannot both finish at the first-settler cost.
state, p, city, u = campaign()
p.gold = 100
local second = { id = 9, owner = 1, x = 8, y = 4, population = 2, buildings = {} }
state.cities[2] = second
S.migrate(state)
for _, c in ipairs(state.cities) do
	c.project = { kind = "unit", id = "settler", progress = 11 }
end
S.production(state, H)
assert(
	p.settlersTrained == 1 and second.project,
	"The second city pays the new cost after the first completes"
)
print(
	"CIVCRAFT: growth time, starvation, one-hex borders, gold/upkeep, shipyards, embarkation, paths, HP/XP/healing and city combat passed."
)
