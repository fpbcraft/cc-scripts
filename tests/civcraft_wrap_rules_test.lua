-- Exercise authoritative rule consumers across an opted-in horizontal seam.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Actions = dofile("games/civcraft/actions.lua")
local AI = dofile("games/civcraft/ai.lua")
local Combat = dofile("games/civcraft/combat.lua")
local Events = dofile("games/civcraft/events.lua")
local Hex = dofile("games/civcraft/hex.lua")
local Hostiles = dofile("games/civcraft/hostiles.lua")
local Movement = dofile("games/civcraft/movement_budget.lua")
local Queue = dofile("games/civcraft/queued_routes.lua")
local Rails = dofile("games/civcraft/railways.lua")
local Sites = dofile("games/civcraft/specialty_sites.lua")
local Systems = dofile("games/civcraft/systems.lua")
local Tactics = dofile("games/civcraft/ai_tactics.lua")
local Villages = dofile("games/civcraft/villages.lua")
local World = dofile("games/civcraft/world.lua")

local function fixture(wrapX)
	local world = {
		width = 18,
		height = 12,
		wrapX = wrapX,
		seed = 17,
		tiles = {},
		resources = {},
		landmarks = {},
		rails = {},
		starts = {},
	}
	for y = 1, world.height do
		for x = 1, world.width do
			world.tiles[World.key(x, y)] = "plains"
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
			{ id = 1, name = "A", civ = "iron", techs = {}, visible = {}, explored = {} },
			{ id = 2, name = "B", civ = "verdant", techs = {}, visible = {}, explored = {} },
		},
		cities = {},
		units = { { id = 3, owner = 1, kind = "settler", x = 1, y = 4, movesLeft = 3 } },
	}
	Systems.migrate(state)
	return state
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end

local function equal(first, second)
	if type(first) ~= "table" then
		return first == second
	end
	if type(second) ~= "table" then
		return false
	end
	for key, value in pairs(first) do
		if not equal(value, second[key]) then
			return false
		end
	end
	for key in pairs(second) do
		if first[key] == nil then
			return false
		end
	end
	return true
end

local wrapped = fixture(true)
local unit = wrapped.units[1]
World.reveal(wrapped, Hex, Systems)
assert(wrapped.players[1].visible[World.key(18, 4)], "Vision crosses the seam")
local ok = Actions.apply(wrapped, 1, { action = "move", sx = 1, sy = 4, x = 18, y = 4 }, Systems)
assert(ok and unit.x == 18 and unit.y == 4, "An authoritative move can cross the seam")
local canonicalMoveEvent = false
for _, event in ipairs(wrapped.eventJournal.streams[1].entries) do
	if
		event.type == "move"
		and event.paths
		and event.paths[#event.paths]
		and event.paths[#event.paths][#event.paths[#event.paths]]
		and event.paths[#event.paths][#event.paths[#event.paths]].x == 18
	then
		canonicalMoveEvent = true
	end
end
assert(canonicalMoveEvent, "Movement events record canonical seam coordinates")

local rejected = fixture(true)
for _, invalid in ipairs({
	{ x = 0, y = 4 },
	{ x = 19, y = 4 },
	{ x = 1, y = 0 },
	{ x = 1, y = 13 },
	{ x = 1.5, y = 4 },
	{ x = math.huge, y = 4 },
	{ x = -math.huge, y = 4 },
	{ x = 0 / 0, y = 4 },
}) do
	local before = copy(rejected)
	local accepted = Actions.apply(
		rejected,
		1,
		{ action = "move", sx = 1, sy = 4, x = invalid.x, y = invalid.y },
		Systems
	)
	assert(not accepted, "A noncanonical external request coordinate is rejected")
	assert(equal(rejected, before), "Rejected coordinate leaves the full saved state unchanged")
end
local beforeForeign = copy(rejected)
assert(
	not Actions.apply(rejected, 2, { action = "move", sx = 1, sy = 4, x = 18, y = 4 }, Systems),
	"A foreign unit cannot be moved"
)
assert(equal(rejected, beforeForeign), "Rejected foreign order leaves state unchanged")

local battle = fixture(true)
battle.units = { { id = 4, owner = 2, kind = "warrior", x = 18, y = 4, hp = 100 } }
battle.players[1].visible[World.key(18, 4)] = true
local city = { id = 1, owner = 1, x = 1, y = 6, buildings = { walls = true }, wallHP = 100 }
battle.cities = { city }
battle.units[2] = { id = 5, owner = 2, kind = "warrior", x = 18, y = 6, hp = 100 }
battle.players[1].visible[World.key(18, 6)] = true
battle.units[3] = { id = 6, owner = 1, kind = "archer", x = 1, y = 4, movesLeft = 2 }
local seamRangedAttack = false
for _, choice in ipairs(Hex.reachable(battle, battle.units[3], 1, Systems)) do
	if choice.x == 18 and choice.y == 4 and choice.attack and choice.ranged then
		seamRangedAttack = true
	end
end
assert(seamRangedAttack, "A ranged unit can target an enemy across the seam")
local strike = Combat.strike(battle, city, 18, 6, Systems)
assert(strike, "A city can strike a visible enemy across the seam")

local city = { id = 1, owner = 1, x = 1, y = 6, population = 2, claimed = { ["18:6"] = true } }
wrapped.cities = { city }
wrapped.contentRules = "balance5"
wrapped.players[1].techs.engineering = true
wrapped.players[1].techs.railways = true
wrapped.players[1].techs.writing = true
wrapped.players[1].techs.currency = true
wrapped.players[1].explored[World.key(18, 6)] = true
wrapped.players[1].stockpile = { iron = 10 }
local workable = Systems.workable(wrapped, city)
local seamTileWorkable = false
for _, tile in ipairs(workable) do
	if tile.x == 18 and tile.y == 6 then
		seamTileWorkable = true
	end
end
assert(seamTileWorkable, "City workforce radius crosses the seam")
local engineer = { id = 7, owner = 1, kind = "engineer", x = 1, y = 6, movesLeft = 2 }
wrapped.units[#wrapped.units + 1] = engineer
assert(Rails.canBuild(wrapped, wrapped.players[1], engineer, 18, 6, Systems))
assert(Sites.canPlace(wrapped, wrapped.players[1], city, "knowledge", 18, 6))
local projection = World.forPlayer(wrapped, 1)
assert(projection.world.wrapX and not projection.world.tiles[World.key(9, 9)])

local bounded = fixture(false)
World.reveal(bounded, Hex, Systems)
assert(not bounded.players[1].visible[World.key(18, 4)], "Legacy bounded vision stays bounded")
local boundedMove =
	Actions.apply(bounded, 1, { action = "move", sx = 1, sy = 4, x = 18, y = 4 }, Systems)
assert(not boundedMove, "Legacy bounded movement does not cross the seam")
assert(bounded.units[1].x == 1 and bounded.units[1].y == 4)

local queued = fixture(true)
local queuedUnit = queued.units[1]
queuedUnit.movesLeft = 1
for key in pairs(queued.world.tiles) do
	queued.players[1].explored[key] = true
end
local queuedOk =
	Actions.apply(queued, 1, { action = "queueMove", sx = 1, sy = 4, x = 17, y = 4 }, Systems)
assert(queuedOk and queuedUnit.x == 18 and queuedUnit.moveQueue)
assert(
	queuedUnit.moveQueue.goals[1].x == 17
		and queuedUnit.moveQueue.path[2].x == 18
		and queuedUnit.moveQueue.path[3].x == 17,
	"Queued paths and persisted goals use canonical seam coordinates"
)

local aiState = fixture(true)
local aiPlayer = aiState.players[1]
aiPlayer.ai = true
aiPlayer.aiPlan = { campaign = { kind = "city", phase = "approach", x = 18, y = 4 } }
aiState.units = {
	{ id = 30, owner = 1, kind = "archer", x = 1, y = 4, movesLeft = 2, hp = 100 },
	{ id = 31, owner = 2, kind = "warrior", x = 18, y = 4, movesLeft = 2, hp = 100 },
}
Systems.migrate(aiState)
World.reveal(aiState, Hex, Systems)
local observedView = AI.knowledge(aiState, aiPlayer)
assert(
	observedView.world.tiles[World.key(18, 4)] and not observedView.world.tiles[World.key(9, 9)],
	"The AI gets observed seam terrain without hidden terrain"
)
local aiChoice = Tactics.ranked(observedView, aiPlayer, aiState.units[1], Systems)[1]
assert(
	aiChoice.request.action == "move"
		and aiChoice.request.x == 18
		and aiChoice.request.y == 4
		and aiChoice.forecast,
	"Observed AI tactical policy selects the visible seam attack"
)

if type(fs) == "table" and type(textutils) == "table" then
	local Saves = dofile("games/civcraft/saves.lua")
	local ok, reason = pcall(function()
		Saves.delete(1)
		assert(Saves.save(1, queued))
		local restored = assert(Saves.load(1))
		assert(restored.world.wrapX == true)
		local restoredUnit = restored.units[1]
		assert(
			restoredUnit.x == 18
				and restoredUnit.moveQueue.goals[1].x == 17
				and restoredUnit.moveQueue.path[2].x == 18
				and restoredUnit.moveQueue.path[3].x == 17,
			"Saved queue retains canonical seam coordinates"
		)
		local savedOwnerEvents = Events.forPlayer(restored, 1)
		local savedRivalEvents = Events.forPlayer(restored, 2)
		assert(#savedOwnerEvents.entries > 0 and #savedRivalEvents.entries == 0)
		restored.round = restored.round + 1
		for _, unit in ipairs(restored.units) do
			Movement.reset(
				restored,
				unit,
				Systems.units[unit.kind],
				restored.players[unit.owner],
				Hex
			)
		end
		World.reveal(restored, Hex, Systems)
		Queue.run(restored, 1, Systems, Actions.apply)
		assert(restoredUnit.x == 17 and restoredUnit.y == 4 and not restoredUnit.moveQueue)
		local resumedEvents = Events.forPlayer(restored, 1)
		local seamArrival, rivalMove = false, false
		for _, event in ipairs(resumedEvents.entries) do
			for _, path in ipairs(event.paths or {}) do
				for _, point in ipairs(path) do
					if point.x == 17 and point.y == 4 then
						seamArrival = true
					end
				end
			end
		end
		for _, event in ipairs(Events.forPlayer(restored, 2).entries) do
			if event.type == "move" then
				rivalMove = true
			end
		end
		assert(seamArrival and not rivalMove, "Resumed route reveals only the owner's seam arrival")
	end)
	Saves.delete(1)
	assert(ok, reason)
end

local escortState = fixture(true)
escortState.units = {
	{ id = 20, owner = 1, kind = "warrior", x = 1, y = 4, movesLeft = 1 },
	{ id = 21, owner = 1, kind = "settler", x = 1, y = 4, movesLeft = 1 },
}
Systems.migrate(escortState)
assert(
	Actions.apply(
		escortState,
		1,
		{ action = "attachEscort", unitID = 20, partnerID = 21, x = 1, y = 4 },
		Systems
	)
)
assert(
	Actions.apply(
		escortState,
		1,
		{ action = "move", unitID = 20, sx = 1, sy = 4, x = 18, y = 4 },
		Systems
	)
)
assert(
	escortState.units[1].x == 18
		and escortState.units[1].y == 4
		and escortState.units[2].x == 18
		and escortState.units[2].y == 4,
	"An escorted pair crosses the seam atomically"
)

local function edgeCandidate()
	local state = fixture(true)
	for y = 1, state.world.height do
		for x = 1, state.world.width do
			state.world.tiles[World.key(x, y)] = "water"
		end
	end
	state.world.tiles[World.key(18, 10)] = "plains"
	state.world.starts = { { x = 1, y = 4 } }
	return state
end

local hostileState = edgeCandidate()
Hostiles.generate(hostileState)
assert(
	#hostileState.spawners == 1
		and hostileState.spawners[1].x == 18
		and hostileState.spawners[1].y == 10,
	"Hostile candidates can use the safe horizontal seam column"
)

local villageState = edgeCandidate()
villageState.units = {}
Villages.generate(villageState)
assert(
	#villageState.cities == 1 and villageState.cities[1].x == 18 and villageState.cities[1].y == 10,
	"Village candidates can use the safe horizontal seam column"
)

local protectedEdge = edgeCandidate()
protectedEdge.world.starts = { { x = 1, y = 10 } }
Hostiles.generate(protectedEdge)
assert(#protectedEdge.spawners == 0, "Hostile safety buffers cross the seam")
protectedEdge.spawners = {}
protectedEdge.cities = {}
protectedEdge.units = {}
Villages.generate(protectedEdge)
assert(#protectedEdge.cities == 0, "Village safety buffers cross the seam")

print(
	"CIVCRAFT wrap rules: movement, escorts, queues, combat, sites, rails, mobs, privacy and bounded legacy passed."
)
