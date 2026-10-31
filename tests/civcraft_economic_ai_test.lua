local rejectMove, commands = false, {}
local forcedWonder, wonderAttempts = false, 0
dofile = function(path)
	-- CraftOS's built-in dofile may use its defining environment. Explicitly carry
	-- this test's command instrumentation into nested modules on both runtimes.
	local module = assert(loadfile(path:gsub("^/games/civcraft/", "games/civcraft/"), "t", _ENV))()
	if path == "/games/civcraft/ai_production.lua" then
		local ranked = module.ranked
		module.ranked = function(view, player, city, systems, canExpand)
			if forcedWonder then
				return { { kind = "wonder", id = "beacon", tileX = 4, tileY = 5, score = 100 } }, {
					surplus = 1,
				}
			end
			return ranked(view, player, city, systems, canExpand)
		end
	end
	if path == "/games/civcraft/actions.lua" then
		local apply = module.apply
		module.apply = function(state, id, request, systems)
			commands[#commands + 1] = request.action
			if forcedWonder and request.kind == "wonder" then
				wonderAttempts = wonderAttempts + 1
				return false, "Wonder order unavailable"
			end
			if rejectMove and request.action == "move" then
				return false, "Order changed"
			end
			return apply(state, id, request, systems)
		end
	end
	return module
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Actions = dofile("/games/civcraft/actions.lua")
local AI = dofile("/games/civcraft/ai.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Infrastructure = dofile("/games/civcraft/ai_infrastructure.lua")
local Materials = dofile("/games/civcraft/ai_materials.lua")
local Production = dofile("/games/civcraft/ai_production.lua")
local Research = dofile("/games/civcraft/ai_research.lua")
local Routes = dofile("/games/civcraft/ai_routes.lua")
local Settlement = dofile("/games/civcraft/ai_settlement.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Workers = dofile("/games/civcraft/ai_workers.lua")
local World = dofile("/games/civcraft/world.lua")
local function fixture()
	local world = {
		width = 18,
		height = 12,
		seed = 22,
		tiles = {},
		resources = {},
		landmarks = {},
		rails = {},
	}
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local player = { id = 1, name = "ONE", civ = "forge", gold = 100, techs = {}, ai = true }
	local city = { id = 1, owner = 1, capitalOf = 1, x = 3, y = 5, population = 2, buildings = {} }
	local state = {
		version = 6,
		campaignID = "economy-ai",
		ruleset = "create",
		phase = "game",
		round = 1,
		world = world,
		players = { player, { id = 2, civ = "scholar", techs = {} } },
		cities = { city },
		units = {},
		nextId = 20,
	}
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	AI.beginTurn(state, player)
	return state, player, city
end
local function known(state, player)
	for y = 1, state.world.height do
		for x = 1, state.world.width do
			player.explored[World.key(x, y)] = true
			player.visible[World.key(x, y)] = true
		end
	end
end

local state, player, city = fixture()
state.world.resources["3:4"] = "grain"
state.world.resources["4:5"] = "saltpeter"
state.world.tiles["3:6"] = "forest"
state.world.resources["3:6"] = "iron"
city.worked = { ["3:6"] = true }
player.aiPlan.citySpecializations[1] = "science"
local view = AI.knowledge(state, player)
local orders = Workers.orders(view, player, view.cities[1], Systems)
assert(
	city.worked["3:6"] and not city.worked["3:4"],
	"Planning cannot change authoritative workers"
)
assert(#orders > 0)
AI.staff(state, player, city, Systems)
assert(
	city.worked["4:5"] and city.worked["3:6"] and not city.worked["3:4"],
	"Science specialization now prefers worked Iron science alongside food-secure Niter"
)
assert(Systems.growth(player, city, state).surplus >= 0)
player.aiPlan.citySpecializations[1] = "industry"
AI.staff(state, player, city, Systems)
assert(
	city.worked["4:5"] and city.worked["3:6"],
	"Industry specialists keep the productive Niter tile without sacrificing food"
)

state, player, city = fixture()
player.techs = { mining = true, agriculture = true, writing = true }
player.gold = 1
for i = 1, 10 do
	state.units[i] = { id = i, owner = 1, kind = "warrior", x = 10 + i % 5, y = 9 }
end
view = AI.knowledge(state, player)
assert(AI.beginTurn(state, player, Systems).emergency == "avoidBankruptcy")
assert(
	Research.ranked(view, player, Systems)[1].id == "currency",
	"A weak treasury values the trading unlock"
)
local list = Production.ranked(view, player, view.cities[1], Systems, false)
for _, choice in ipairs(list) do
	assert(choice.kind ~= "unit", "Low funds cannot support more upkeep")
end

state, player, city = fixture()
for id in pairs(Systems.buildings) do
	city.buildings[id] = true
end
state.cities[2] = { id = 2, owner = 1, x = 8, y = 5, population = 2, buildings = {} }
state.cities[3] = { id = 3, owner = 1, x = 13, y = 5, population = 2, buildings = {} }
Systems.migrate(state)
-- Current civilian fallback recovers scarce funds, then resumes construction for a new need.
for i = 1, 6 do
	state.units[i] = { id = i + 2, owner = 1, kind = "diamondguard", x = 10 + i % 5, y = 9 }
end
state.units[7] = { id = 12, owner = 1, kind = "scout", x = 12, y = 10 }
player.gold = 0
city.productionIdle = true
assert(
	AI.choose(state, player, city, Systems)
		and city.project.kind == "project"
		and city.project.id == "trade"
)
assert(Systems.queue(player, city, "none", nil, state, Hex))
city.buildings.library = nil
player.techs.writing = true
assert(
	AI.choose(state, player, city, Systems)
		and city.project.id == "library"
		and not city.productionIdle
)

state, player, city = fixture()
known(state, player)
for y = 3, 12 do
	state.world.tiles[World.key(6, y)] = "mountain"
end
local settler = { id = 3, owner = 1, kind = "settler", x = 4, y = 5, movesLeft = 3 }
state.units[1] = settler
settler.aiSettlement = { version = 1, x = 8, y = 5, selectedRound = 1 }
view = AI.knowledge(state, player)
local saved = Settlement.select(view, player, settler, Systems)
assert(saved.x == 8 and saved.y == 5 and saved.selectedRound == 1 and #saved.path > 5)
for i = 2, #saved.path do
	assert(
		Hex.distance(saved.path[i - 1].x, saved.path[i - 1].y, saved.path[i].x, saved.path[i].y)
			== 1
	)
end
for round = 1, 8 do
	state.round = round
	settler.movesLeft, settler.moved = 3, false
	if AI.settle(state, player, settler, Systems) then
		break
	end
	assert(
		settler.aiSettlement
			and settler.aiSettlement.x == 8
			and settler.aiSettlement.selectedRound == 1
	)
end
assert(
	#state.cities == 2 and state.cities[2].x == 8,
	"A saved destination survives a multi-round obstacle detour"
)

state, player, city = fixture()
local unit = { id = 5, owner = 1, kind = "settler", x = 4, y = 5, movesLeft = 3 }
state.units[1] = unit
rejectMove, commands = true, {}
AI.settle(state, player, unit, Systems)
assert(
	unit.x == 4 and unit.y == 5 and unit.movesLeft == 3 and #commands == 1,
	"Rejected orders cannot teleport or retry indefinitely"
)
rejectMove = false
for y = 2, 8 do
	for x = 1, 8 do
		player.explored[World.key(x, y)], player.visible[World.key(x, y)] = true, true
	end
end
local first = Settlement.select(AI.knowledge(state, player), player, unit, Systems)
assert(first)
state.world.resources["18:12"] = "diamond"
state.cities[2] = { id = 2, owner = 2, x = 17, y = 12, buildings = {} }
local second = Settlement.select(AI.knowledge(state, player), player, unit, Systems)
assert(
	first.x == second.x and first.y == second.y,
	"Unrevealed deposits and cities cannot influence a settlement target"
)

state, player, city = fixture()
known(state, player)
player.techs.railways, player.techs.currency, player.techs.bronze = true, true, true
city.buildings.market, city.buildings.station = true, true
state.cities[2] =
	{ id = 2, owner = 1, x = 6, y = 5, population = 2, buildings = { station = true } }
Systems.migrate(state)
local engineer = { id = 8, owner = 1, kind = "engineer", x = 3, y = 4, movesLeft = 3 }
state.units[1] = engineer
player.stockpile.iron = 0
local requests = Materials.orders(AI.knowledge(state, player), player, Systems)
assert(#requests == 2 and requests[1].resource == "iron" and player.gold == 100)
AI.materials(state, player, Systems)
assert(player.stockpile.iron == 2 and player.gold == 60)
AI.engineer(state, player, engineer, Systems)
assert(engineer.aiRail and engineer.aiRail.fromCityID == 1 and engineer.aiRail.toCityID == 2)
assert(state.world.rails[World.key(city.x, city.y)] and player.stockpile.iron == 0)
local persisted = engineer.aiRail.selectedRound
state.round = 2
engineer.movesLeft, engineer.moved = 3, false
player.stockpile.iron = 10
local plan = Infrastructure.plan(AI.knowledge(state, player), player, engineer, Systems)
assert(plan.selectedRound == persisted and plan.toCityID == 2)
local routes = Routes.from(AI.knowledge(state, player), engineer, Systems, { maxNodes = 5 })
assert(routes.visited <= 5, "Candidate search is explicitly bounded")

-- Founding follows the same territorial ownership rule for every command issuer.
state.units[2] = { id = 9, owner = 2, kind = "settler", x = 4, y = 5, movesLeft = 3 }
local ok = Actions.apply(state, 2, { action = "found", x = 4, y = 5 }, Systems)
assert(not ok and #state.cities == 2)
state, player, city = fixture()
known(state, player)
player.techs.railways = true
for i, point in ipairs({ { 7, 3 }, { 11, 3 }, { 7, 8 }, { 13, 8 } }) do
	state.cities[#state.cities + 1] =
		{ id = i + 1, owner = 1, x = point[1], y = point[2], population = 2, buildings = {} }
end
Systems.migrate(state)
AI.beginTurn(state, player, Systems)
local roles = {}
for _, role in pairs(player.aiPlan.citySpecializations) do
	roles[role] = true
end
assert(
	roles.science and roles.industry and roles.military and roles.commerce and roles.infrastructure
)
local persistedRoles = player.aiPlan.citySpecializations
state.round = 2
AI.beginTurn(state, player, Systems)
assert(
	player.aiPlan.citySpecializations == persistedRoles,
	"City specializations remain stable between deliberate reviews"
)
state, player, city = fixture()
known(state, player)
state.cities = {}
local survivor = { id = 31, owner = 1, kind = "settler", x = 4, y = 5, movesLeft = 3 }
state.units = { survivor }
assert(
	AI.settle(state, player, survivor, Systems) and #state.cities == 1,
	"A surviving settler can rebuild after the civilization loses its last city"
)
print(
	"CIVCRAFT: economic utilities, food-secure staffing, legal persistent settlement/rail plans, budgets and private knowledge passed."
)

state, player, city = fixture()
player.techs.diamondworking = true
local function beaconChoice()
	local view = World.forPlayer(state, player.id)
	local ranked = Production.ranked(view, player, view.cities[1], Systems, false)
	for _, choice in ipairs(ranked) do
		if choice.kind == "wonder" and choice.id == "beacon" then
			return true
		end
	end
	return false
end
assert(beaconChoice(), "Unseen rival activity cannot suppress a legal observed wonder candidate")
forcedWonder = true
AI.choose(state, player, city, Systems)
forcedWonder = false
assert(wonderAttempts == 1 and player.aiPlan.productionRetryAfter["wonder:beacon"] == 11)
assert(not beaconChoice(), "A rejected wonder order suppresses repeated attempts across cities")
Systems.migrate(state)
assert(not beaconChoice(), "Feedback survives campaign migration")
state.round = 11
assert(beaconChoice(), "Transient rejection is reconsidered after a bounded cooldown")
print(
	"CIVCRAFT: AI wonder retries use only command feedback and expire without hidden-map knowledge."
)

state, player, city = fixture()
known(state, player)
local civilian =
	{ id = 40, owner = 1, kind = "settler", x = 6, y = 5, movesLeft = 3, hp = 100, escortID = 41 }
local escort =
	{ id = 41, owner = 1, kind = "warrior", x = 6, y = 5, movesLeft = 0, hp = 100, escortID = 40 }
state.units = { civilian, escort }
civilian.aiSettlement = { version = 1, x = 8, y = 5, selectedRound = 1 }
local request, destination = Settlement.order(World.forPlayer(state, 1), player, civilian, Systems)
assert(
	not request and destination,
	"An exhausted escort pauses settlement travel without discarding its target"
)
escort.movesLeft = 2
request = Settlement.order(World.forPlayer(state, 1), player, civilian, Systems)
assert(request and request.action == "move", "Settlement travel resumes when both members can move")
print("CIVCRAFT: settlement routes respect shared escort allowances before issuing movement.")
