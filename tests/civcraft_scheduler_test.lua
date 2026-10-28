local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Actions = dofile("/games/civcraft/actions.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local function fixture()
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		players = {},
		cities = {},
		units = {},
		world = { width = 20, height = 14, tiles = {}, resources = {}, landmarks = {}, rails = {} },
		diplomacy = Diplomacy.new(),
		scheduler = Scheduler.new(),
	}
	for y = 1, 14 do
		for x = 1, 20 do
			state.world.tiles[World.key(x, y)] = "plains"
		end
	end
	for id = 1, 4 do
		state.players[id] = { id = id, name = "PLAYER " .. id, civ = "iron", techs = {} }
	end
	state.units = {
		{ id = 1, owner = 1, kind = "warrior", x = 3, y = 4, movesLeft = 2 },
		{ id = 2, owner = 2, kind = "warrior", x = 4, y = 4, movesLeft = 1 },
	}
	-- These scenarios begin after all participants have made contact.
	for _, participant in ipairs(state.players) do
		participant.contacts = {}
		for _, other in ipairs(state.players) do
			participant.contacts[other.id] = true
		end
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	return state
end
local state = fixture()
for id = 1, 4 do
	assert(Scheduler.canAct(state, id))
end
assert(
	not Actions.apply(state, 1, { action = "move", sx = 3, sy = 4, x = 4, y = 4 }, Systems),
	"Peace blocks attacks through the shared command executor"
)
assert(Diplomacy.declare(state, 1, 2, "normal"))
assert(not Diplomacy.canAttack(state, 1, 2) and Scheduler.canAct(state, 2))
state.round = 2
Diplomacy.boundary(state)
assert(Diplomacy.canAttack(state, 1, 2) and Scheduler.group(state, 1).active == 2)
assert(not Scheduler.canAct(state, 1) and Scheduler.canAct(state, 3))
assert(not Actions.apply(state, 1, { action = "researchTech", id = "mining" }, Systems))
assert(Actions.apply(state, 3, { action = "researchTech", id = "mining" }, Systems))
assert(Scheduler.finish(state, 2) and Scheduler.canAct(state, 1))
assert(
	Actions.apply(state, 1, { action = "move", sx = 3, sy = 4, x = 4, y = 4 }, Systems),
	"Active war permits the ordinary legal attack"
)

state = fixture()
state.players[2].ready = true
state.units[1].movesLeft, state.units[2].movesLeft = 1, 0
state.units[2].attackedRound = 1
assert(Diplomacy.declare(state, 1, 2, "surprise"))
assert(Scheduler.canAct(state, 1) and not Scheduler.canAct(state, 2) and Scheduler.canAct(state, 3))
assert(
	state.players[2].ready and state.units[2].movesLeft == 0 and state.units[2].attackedRound == 1
)
assert(state.units[1].movesLeft == 1, "Surprise War never replenishes the attacker")
assert(state.diplomacy.reputation[1] == -50 and state.diplomacy.relations["2:1"].trust == -75)
assert(
	Scheduler.finish(state, 1) and Scheduler.canAct(state, 2),
	"An already-ended defender responds only after the attacker finishes"
)
assert(Scheduler.finish(state, 2) and not Scheduler.canAct(state, 2))
assert(not Scheduler.finish(state, 2), "There is no second turn or repeated response")
assert(not Scheduler.complete(state), "Unrelated peaceful players still owe their turns")
assert(Scheduler.finish(state, 3) and Scheduler.finish(state, 4) and Scheduler.complete(state))
local view = World.forPlayer(state, 2)
assert(view.diplomacy.relations["3:1"] == nil, "Other civilizations' private relations stay hidden")
view.diplomacy.wars[1].active = false
assert(state.diplomacy.wars[1].active, "Public diplomacy is detached from authoritative state")

local pairs = { { 1, 2 }, { 1, 3 }, { 1, 4 }, { 2, 3 }, { 2, 4 }, { 3, 4 } }
for mask = 0, 63 do
	state = fixture()
	for index, pair in ipairs(pairs) do
		if math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then
			state.diplomacy.wars[#state.diplomacy.wars + 1] =
				{ a = pair[1], b = pair[2], active = true, activatesRound = 1 }
		end
	end
	Scheduler.rebuild(state, state.diplomacy.wars)
	for _, war in ipairs(state.diplomacy.wars) do
		assert(
			Scheduler.group(state, war.a) == Scheduler.group(state, war.b),
			"Overlapping wars share a component"
		)
	end
	for _ = 1, 4 do
		for id = 1, 4 do
			if Scheduler.canAct(state, id) then
				assert(Scheduler.finish(state, id))
			end
		end
	end
	assert(Scheduler.complete(state), "Every four-player war graph terminates exactly one round")
end
state = fixture()
state.diplomacy.wars = {
	{ a = 1, b = 2, active = true, activatesRound = 1 },
	{ a = 3, b = 4, active = true, activatesRound = 1 },
}
for round = 1, 4 do
	state.round = round
	Scheduler.beginRound(state, state.diplomacy.wars)
	assert(Scheduler.group(state, 1).active == (round % 2 == 1 and 1 or 2))
	assert(
		Scheduler.group(state, 3).active == (round % 2 == 1 and 3 or 4),
		"Each independent component rotates fairly"
	)
end
state.round = 1
Scheduler.beginRound(state, state.diplomacy.wars)
assert(Diplomacy.declare(state, 3, 2, "surprise"))
assert(
	#state.scheduler.groups == 1
		and state.scheduler.groups[1].active == 3
		and #state.scheduler.groups[1].order == 4,
	"Surprise War atomically merges existing components"
)
state.diplomacy.wars[3].endsRound = 2
state.round = 2
Diplomacy.boundary(state)
assert(#state.scheduler.groups == 2, "Scheduled peace splits war groups at a boundary")
state = fixture()
state.diplomacy.wars = { { a = 3, b = 4, active = true, activatesRound = 1 } }
Scheduler.rebuild(state, state.diplomacy.wars)
assert(Scheduler.finish(state, 3) and Scheduler.group(state, 4).active == 4)
assert(Diplomacy.declare(state, 1, 2, "surprise"))
assert(
	Scheduler.group(state, 4).active == 4 and state.players[3].ready,
	"An unrelated component retains its current participant and Ready state"
)
local count = #state.diplomacy.wars
assert(
	not Diplomacy.declare(state, 2, 3, "surprise") and #state.diplomacy.wars == count,
	"An inactive attacker cannot change the war graph"
)
state = fixture()
state.diplomacy, state.scheduler = nil, nil
state.activeIndex = 2
state.players[1].ready = true
state.units[1].movesLeft, state.units[2].movesLeft = 0, 1
state.units[1].attackedRound = state.round
Diplomacy.migrate(state)
assert(#state.diplomacy.wars == 6 and state.diplomacy.importedLegacy)
assert(state.scheduler.groups[1].active == 2 and state.players[1].ready)
assert(
	state.units[1].movesLeft == 0
		and state.units[2].movesLeft == 1
		and state.units[1].attackedRound == state.round,
	"Migration preserves action spending and Ready locks"
)
Diplomacy.migrate(state)
assert(#state.diplomacy.wars == 6, "Migration is idempotent")
print(
	"CIVCRAFT: peaceful concurrency, 64 war graphs, fair rotation, declaration timing, preserved budgets and Surprise War reactions passed."
)
