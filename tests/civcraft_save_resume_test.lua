-- Coupled feature records must survive a real serialized load in either surprise-war window.
local disk = dofile("tests/support/craftos.lua").new()
disk.install("civcraft", "main", "--no-startup")
disk.withoutRuntime()
local root = "/games/civcraft/"
local env = disk.env
	.dofile(root .. "_lib/fpb/loader.lua")
	.environment("/games/civcraft", disk.env, "game.lua")
env.dofile(root .. "module_cache.lua").install(env)
local function module(name)
	return env.dofile(root .. name .. ".lua")
end
local Systems, World, Hex = module("systems"), module("world"), module("hex")
local Actions, Saves, Events = module("actions"), module("saves"), module("events")
local Diplomacy, Council, CouncilRules =
	module("diplomacy"), module("council"), module("council_rules")
local Scheduler, Movement, Queue =
	module("turn_scheduler"), module("movement_budget"), module("queued_routes")
local Stacks = module("unit_stacks")
local function equal(a, b, label)
	assert(type(a) == type(b), label)
	if type(a) ~= "table" then
		assert(a == b, label)
		return
	end
	for key, value in pairs(a) do
		equal(value, b[key], label .. "." .. tostring(key))
	end
	for key in pairs(b) do
		assert(a[key] ~= nil, label .. ".extra " .. tostring(key))
	end
end
local function order(state, actor, request)
	local ok, why = Actions.apply(state, actor, request, Systems)
	assert(ok, why)
end
local function fixture(speed)
	local state = {
		version = 6,
		phase = "game",
		round = 1,
		campaignID = "coupled-" .. speed,
		ruleset = "create",
		gameSpeed = speed,
		victoryRulesVersion = 2,
		nextId = 100,
		players = {},
		cities = {},
		units = {},
		diplomacy = Diplomacy.new(),
		world = {
			width = 24,
			height = 14,
			seed = 9021,
			tiles = {},
			resources = {},
			rails = {},
			landmarks = {},
		},
	}
	for y = 1, 14 do
		for x = 1, 24 do
			state.world.tiles[x .. ":" .. y] = "plains"
		end
	end
	for id = 1, 3 do
		state.players[id] = {
			id = id,
			name = "PLAYER " .. id,
			civ = "iron",
			gold = 100,
			contacts = { true, true, true },
			techs = { agriculture = true, currency = true, commerce = true, bronze = true },
			researchTarget = "writing",
			researchProgress = { writing = 9 },
		}
		state.cities[id] = {
			id = id,
			owner = id,
			capitalOf = id,
			x = 4 + (id - 1) * 8,
			y = 6,
			population = 2,
			buildings = { market = true, councilhall = true },
			project = { kind = "building", id = "library", progress = 6 },
		}
	end
	state.units = {
		{ id = 10, owner = 1, kind = "warrior", x = 5, y = 6, movesLeft = 2, hp = 80 },
		{ id = 11, owner = 1, kind = "settler", x = 5, y = 6, movesLeft = 3, hp = 90 },
		{ id = 12, owner = 2, kind = "warrior", x = 11, y = 6, movesLeft = 1, hp = 72 },
		{ id = 13, owner = 3, kind = "warrior", x = 19, y = 6, movesLeft = 2, hp = 100 },
	}
	Systems.migrate(state)
	Diplomacy.migrate(state)
	for x = 4, 10 do
		state.players[1].explored[x .. ":6"] = true
	end
	World.reveal(state, Hex, Systems)
	Council.advance(state)
	order(state, 1, { action = "attachEscort", unitID = 10, partnerID = 11, x = 5, y = 6 })
	order(state, 1, { action = "queueMove", unitID = 10, sx = 5, sy = 6, x = 9, y = 6 })
	assert(
		state.units[1].x == 7 and state.units[1].movesLeft == 0 and state.units[2].movesLeft == 1
	)
	order(
		state,
		1,
		{ action = "diplomaticOffer", target = 3, kind = "commerce", terms = { duration = 10 } }
	)
	local offer = state.diplomacy.offers[#state.diplomacy.offers]
	order(state, 3, { action = "diplomaticReply", offerID = offer.id, response = "accept" })
	order(
		state,
		3,
		{ action = "diplomaticOffer", target = 1, kind = "trade", terms = { gold = 7 } }
	)
	assert(CouncilRules.pledge(state, 1, 3, state.council.session.id))
	order(state, 1, { action = "councilVote", session = state.council.session.id, candidate = 3 })
	state.players[1].aiPlan =
		{ version = 1, goal = "diplomatic", productionRetryAfter = { ["wonder:beacon"] = 11 } }
	state.players[2].ready = true
	assert(Diplomacy.declare(state, 1, 2, "surprise"))
	assert(state.scheduler.reactions[2] and Scheduler.group(state, 1).active == 1)
	return state
end
local function reload(state)
	local cursors = {}
	for id = 1, 3 do
		cursors[id] = Events.forPlayer(state, id).lastSeq
	end
	assert(Saves.save(3, state))
	local restored = Saves.load(3)
	for _ = 1, 2 do
		Systems.migrate(World.migrate(restored))
		Diplomacy.migrate(restored)
		World.reveal(restored, Hex, Systems)
		Council.advance(restored)
	end
	for _, field in ipairs({ "scheduler", "diplomacy", "council", "eventJournal" }) do
		equal(state[field], restored[field], field)
	end
	equal(state.players[1].aiPlan, restored.players[1].aiPlan, "AI plan")
	for index, unit in ipairs(state.units) do
		local other = restored.units[index]
		assert(
			unit.x == other.x
				and unit.y == other.y
				and unit.hp == other.hp
				and unit.movesLeft == other.movesLeft
		)
		equal(unit.moveQueue, other.moveQueue, "route")
		assert(
			unit.escortID == other.escortID
				and unit.responseMovementRound == other.responseMovementRound
		)
	end
	assert(Stacks.partner(restored, restored.units[1]) == restored.units[2])
	for id = 1, 3 do
		assert(
			#Events.forPlayer(restored, id, cursors[id]).entries == 0,
			"Loading invented replay events"
		)
		equal(state.players[id].mapMemory, restored.players[id].mapMemory, "remembered world")
		assert(
			restored.players[id].researchProgress.writing == 9
				and restored.cities[id].project.progress == 6
		)
	end
	local stranger = World.forPlayer(restored, 2)
	assert(not stranger.eventJournal and not stranger.council.session.election)
	assert(#stranger.diplomacy.offers == 0 and not stranger.players[1].aiPlan)
	return restored
end
for _, speed in ipairs({ "quick", "standard", "epic" }) do
	local state = reload(fixture(speed))
	assert(Scheduler.finish(state, 1))
	Movement.response(state, state.units[3], Systems.units.warrior, state.players[2], Hex)
	assert(state.units[3].movesLeft == 1 and Scheduler.group(state, 1).active == 2)
	state = reload(state)
	Queue.run(state, 1, Systems, Actions.apply)
	assert(state.units[1].x == 7 and state.units[1].movesLeft == 0)
	local moved = false
	for _, choice in ipairs(Hex.reachable(state, state.units[3], 2, Systems)) do
		if not choice.attack and choice.cost == 1 then
			order(
				state,
				2,
				{ action = "move", unitID = 12, sx = 11, sy = 6, x = choice.x, y = choice.y }
			)
			moved = true
			break
		end
	end
	assert(moved and state.units[3].movesLeft == 0)
	assert(Scheduler.finish(state, 2) and Scheduler.canAct(state, 3))
	state.round = 2
	for _, player in ipairs(state.players) do
		player.ready = false
	end
	Council.advance(state)
	Diplomacy.boundary(state)
	for _, unit in ipairs(state.units) do
		Movement.reset(state, unit, Systems.units[unit.kind], state.players[unit.owner], Hex)
	end
	assert(Scheduler.finish(state, 2))
	Queue.run(state, 1, Systems, Actions.apply)
	assert(state.units[1].x == 9 and state.units[2].x == 9 and not state.units[1].moveQueue)
	local budget = state.units[1].movesLeft
	Queue.run(state, 1, Systems, Actions.apply)
	assert(
		state.units[1].x == 9 and state.units[1].movesLeft == budget,
		"A resumed queue ran twice"
	)
end
print(
	"CIVCRAFT: six coupled save/load windows preserve reactions, escort routes, deals, votes, AI plans, fog memory and observer cursors."
)
