local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Actions = dofile("games/civcraft/actions.lua")
local Combat = dofile("games/civcraft/combat.lua")
local CommandQueue = dofile("games/civcraft/command_queue.lua")
local Events = dofile("games/civcraft/events.lua")
local Hex = dofile("games/civcraft/hex.lua")
local Snapshots = dofile("games/civcraft/snapshots.lua")
local Systems = dofile("games/civcraft/systems.lua")
local VisibilityEvents = dofile("games/civcraft/visibility_events.lua")
local World = dofile("games/civcraft/world.lua")

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

local function hasSecret(value)
	if type(value) == "string" then
		return value:find("DO_NOT_LEAK", 1, true) ~= nil
	end
	if type(value) ~= "table" then
		return false
	end
	for key, item in pairs(value) do
		if hasSecret(key) or hasSecret(item) then
			return true
		end
	end
	return false
end

local function fixture()
	local world =
		{ width = 18, height = 12, tiles = {}, resources = {}, landmarks = {}, rails = {} }
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local state = {
		version = 6,
		ruleset = "create",
		phase = "game",
		round = 1,
		nextId = 20,
		campaignID = "test",
		world = world,
		players = {
			{ id = 1, name = "ONE", techs = {} },
			{ id = 2, name = "TWO", techs = {} },
			{ id = 3, name = "THREE", techs = {} },
		},
		cities = {},
		units = {},
	}
	Systems.migrate(state)
	return state
end

local raw = {
	type = "move",
	actor = {
		id = 10,
		owner = 2,
		kind = "scout",
		hp = 100,
		x = 1,
		y = 8,
		privatePlans = "DO_NOT_LEAK",
	},
	frames = {
		{ x = 1, y = 8, visible = {} },
		{ x = 2, y = 8, visible = { [1] = true } },
		{ x = 3, y = 8, visible = {} },
		{ x = 4, y = 8, visible = { [1] = true } },
		{ x = 5, y = 8, visible = {} },
	},
	privateMetadata = "DO_NOT_LEAK",
}
local projection = VisibilityEvents.project(raw, 1)
assert(#projection.paths == 2 and #projection.paths[1] == 1 and #projection.paths[2] == 1)
assert(projection.paths[1][1].x == 2 and projection.paths[2][1].x == 4)
assert(
	not projection.actor.x
		and not projection.start
		and not projection.target
		and not hasSecret(projection)
)
assert(not VisibilityEvents.project(raw, 3))
local automated = {
	type = "move",
	autoExplore = true,
	actor = { id = 4, owner = 1, kind = "scout" },
	frames = { { x = 3, y = 3, visible = { [1] = true, [2] = true } } },
}
assert(VisibilityEvents.project(automated, 1).ownAutoExplore == true)
assert(
	VisibilityEvents.project(automated, 2).ownAutoExplore == nil,
	"Other observers must not receive private auto-explore order metadata"
)
local state = fixture()
Events.emit(state, raw)
local first = Events.forPlayer(state, 1)
assert(first.lastSeq == 1 and Events.forPlayer(state, 3).lastSeq == 0)
raw.frames[2].x = 99
first.entries[1].paths[1][1].x = 88
assert(
	Events.forPlayer(state, 1).entries[1].paths[1][1].x == 2,
	"Stored observations must be frozen"
)
state.players[1].visible = { ["1:8"] = true, ["5:8"] = true }
assert(
	Events.forPlayer(state, 1).entries[1].paths[1][1].x == 2,
	"Later sight must not reveal old paths"
)
assert(not Events.forPlayer(state, 99))
assert(
	not VisibilityEvents.project({ type = "unknown", recipient = 1, content = "DO_NOT_LEAK" }, 1)
)

local battle = {
	type = "combat",
	actor = { id = 10, owner = 2, kind = "archer", privatePlans = "DO_NOT_LEAK" },
	start = { x = 10, y = 8, visible = {} },
	target = { x = 12, y = 8, visible = { [1] = true } },
	defender = { id = 11, owner = 1, kind = "warrior", privatePlans = "DO_NOT_LEAK" },
	result = { attackerHP = 100, defenderHP = 35, ranged = true, secret = "DO_NOT_LEAK" },
}
projection = VisibilityEvents.project(battle, 1)
assert(projection.type == "impact" and not projection.actor and not projection.start)
assert(
	not projection.result.attackerHP
		and projection.result.defenderHP == 35
		and not hasSecret(projection)
)
battle.start.visible[1] = true
battle.target.visible[1] = nil
projection = VisibilityEvents.project(battle, 1)
assert(projection.type == "activity" and not projection.target and not projection.defender)
battle.target.visible[1] = true
assert(VisibilityEvents.project(battle, 1).type == "combat")

-- A route crosses the observer's sight and ends in fog; the final snapshot is insufficient.
state = fixture()
for y = 1, 12 do
	for x = 1, 18 do
		state.world.tiles[World.key(x, y)] = "mountain"
	end
end
for x = 1, 18 do
	state.world.tiles[World.key(x, 6)] = "plains"
end
state.world.tiles["9:4"] = "plains"
state.cities = { { id = 1, owner = 1, x = 9, y = 4, population = 2, buildings = {} } }
local moving = { id = 10, owner = 2, kind = "scout", x = 2, y = 6, movesLeft = 14 }
state.units = { moving }
Systems.migrate(state)
World.reveal(state, Hex, Systems)
assert(Actions.apply(state, 2, { action = "move", sx = 2, sy = 6, x = 16, y = 6 }, Systems))
local own = Events.forPlayer(state, 2).entries[1]
assert(
	#own.paths == 1 and #own.paths[1] == 15,
	"Every host-approved movement segment must be recorded"
)
local observed = Events.forPlayer(state, 1).entries[1]
assert(observed and #observed.paths == 1 and not observed.actor.x)
for _, point in ipairs(observed.paths[1]) do
	assert(point.x > 2 and point.x < 16 and Hex.distance(9, 4, point.x, point.y) <= 2)
end
assert(Events.forPlayer(state, 3).lastSeq == 0)
local view = World.forPlayer(state, 1)
assert(#view.units == 0 and #view.eventStream.entries == 2 and not view.eventJournal)
assert(
	view.eventStream.entries[2].type == "contact",
	"First contact follows the movement that established it"
)
assert(state.players[2].explored["9:6"], "Travel must reveal intermediate terrain to its owner")
local order = state.eventJournal.order
assert(not Actions.apply(state, 2, { action = "move", sx = 16, sy = 6, x = 1, y = 1 }, Systems))
assert(state.eventJournal.order == order, "Rejected actions cannot create events")

-- Discoveries replay after the movement that revealed them, never before it.
state = fixture()
state.units = { { id = 10, owner = 1, kind = "scout", x = 2, y = 6, movesLeft = 6 } }
state.world.landmarks["10:6"] = { kind = "amethyst", natural = true }
World.reveal(state, Hex, Systems)
assert(Actions.apply(state, 1, { action = "move", sx = 2, sy = 6, x = 8, y = 6 }, Systems))
local discoveryStream = Events.forPlayer(state, 1)
assert(discoveryStream.entries[1].type == "move" and discoveryStream.entries[2].type == "landmark")
-- Melee approaches are real movement; terrain at the approach governs retaliation.
state = fixture()
state.units = {
	{ id = 10, owner = 1, kind = "warrior", x = 3, y = 6, movesLeft = 3 },
	{ id = 11, owner = 2, kind = "warrior", x = 5, y = 6, hp = 100 },
}
state.world.tiles["4:6"] = "hills"
World.reveal(state, Hex, Systems)
local attack
for _, choice in ipairs(Hex.reachable(state, state.units[1], 1, Systems)) do
	if choice.x == 5 and choice.y == 6 then
		attack = choice
	end
end
assert(attack and attack.attack)
local attackPreview = Combat.predictOrder(state, state.units[1], attack, Systems)
assert(Actions.apply(state, 1, { action = "move", sx = 3, sy = 6, x = 5, y = 6 }, Systems))
assert(state.units[1].hp == attackPreview.attackerHP)
assert(
	Hex.distance(state.units[1].x, state.units[1].y, 5, 6) <= 1,
	"Attacker did not walk its approved approach"
)
-- Wilderness/guard attacks using approved paths share the same physical approach.
state = fixture()
state.units = {
	{ id = 10, owner = -2147483647, kind = "zombie", x = 3, y = 6, movesLeft = 3 },
	{ id = 11, owner = 1, kind = "warrior", x = 5, y = 6, hp = 100 },
}
World.reveal(state, Hex, Systems)
local monsterAttack
for _, choice in ipairs(Hex.reachable(state, state.units[1], -2147483647, Systems)) do
	if choice.x == 5 and choice.y == 6 then
		monsterAttack = choice
	end
end
assert(monsterAttack and Combat.attack(state, state.units[1], monsterAttack, Systems))
assert(Hex.distance(state.units[1].x, state.units[1].y, 5, 6) == 1)

-- Ranged units cannot shoot a distant target by charging an untraversed approach.
state = fixture()
state.units = {
	{ id = 10, owner = 1, kind = "archer", x = 3, y = 6, movesLeft = 5 },
	{ id = 11, owner = 2, kind = "warrior", x = 7, y = 6 },
}
World.reveal(state, Hex, Systems)
state.players[1].visible["7:6"] = true
for _, choice in ipairs(Hex.reachable(state, state.units[1], 1, Systems)) do
	assert(not (choice.x == 7 and choice.y == 6 and choice.attack))
end

-- Public ratings match authoritative combat without sending the unseen contributing army.
state = fixture()
state.units = {
	{ id = 10, owner = 1, kind = "warrior", x = 8, y = 6, hp = 100, movesLeft = 2 },
	{
		id = 11,
		owner = 2,
		kind = "diamondguard",
		x = 17,
		y = 11,
		hp = 100,
		autoExplore = "DO_NOT_LEAK",
	},
	{ id = 12, owner = 2, kind = "warrior", x = 9, y = 6, hp = 100, autoExplore = "DO_NOT_LEAK" },
}
state.cities = {
	{
		id = 2,
		owner = 2,
		x = 9,
		y = 6,
		population = 2,
		buildings = { walls = true },
		project = { id = "DO_NOT_LEAK" },
		worked = { DO_NOT_LEAK = true },
	},
}
Systems.migrate(state)
World.reveal(state, Hex, Systems)
view = World.forPlayer(state, 1)
assert(
	#view.units == 2
		and not hasSecret(view)
		and not view.cities[1].project
		and not view.cities[1].worked
)
assert(not view.units[2].autoExplore and view.cities[1].publicDefense)
local expected = Combat.predict(state, state.units[1], { x = 9, y = 6 }, Systems)
local preview = Combat.predict(view, view.units[1], { x = 9, y = 6 }, Systems)
assert(equal(expected, preview), "Filtered snapshot forecast differs from host")
assert(Combat.attack(state, state.units[1], { x = 9, y = 6 }, Systems))
local stream = Events.forPlayer(state, 1)
assert(stream.entries[#stream.entries].type == "combat")
state.phase = "lobby"
view = World.forPlayer(state, 1)
assert(
	not view.eventJournal and #view.units == 0 and not hasSecret(view),
	"Lobby must not return unrestricted state"
)

-- Late commands cannot consume movement in a new round or a different campaign.
state = fixture()
state.units = { { id = 10, owner = 1, kind = "scout", x = 3, y = 6, movesLeft = 4 } }
World.reveal(state, Hex, Systems)
assert(
	not Actions.apply(
		state,
		1,
		{ action = "move", sx = 3, sy = 6, x = 4, y = 6, round = 2 },
		Systems
	)
)
assert(
	not Actions.apply(
		state,
		1,
		{ action = "move", sx = 3, sy = 6, x = 4, y = 6, campaignID = "other" },
		Systems
	)
)
assert(state.units[1].x == 3 and state.units[1].movesLeft == 4)

-- Explored fog retains observed infrastructure, not unseen rival construction/clearing.
state = fixture()
state.units = { { id = 10, owner = 1, kind = "scout", x = 3, y = 6, movesLeft = 4 } }
state.spawners = { { id = 44, x = 6, y = 6, kind = "spawner", cleared = false } }
World.reveal(state, Hex, Systems)
state.units[1].x = 16
World.reveal(state, Hex, Systems)
state.world.rails["6:6"] = true
state.world.landmarks["6:6"] = { kind = "beacon", natural = false, cityId = "DO_NOT_LEAK" }
state.spawners[1].cleared = true
view = World.forPlayer(state, 1)
assert(not view.world.rails["6:6"] and not view.world.landmarks["6:6"])
assert(#view.spawners == 1 and not view.spawners[1].cleared)
state.units[1].x = 3
World.reveal(state, Hex, Systems)
view = World.forPlayer(state, 1)
assert(view.world.rails["6:6"] and view.world.landmarks["6:6"].kind == "beacon")
assert(not view.world.landmarks["6:6"].cityId and view.spawners[1].cleared)

-- Bounded persistence, private research, replay cursors and explicit loss markers.
state = fixture()
for index = 1, 150 do
	Events.notice(state, "research", nil, "agriculture", 1)
end
stream = Events.forPlayer(state, 1)
assert(
	#stream.entries == Events.maxEvents
		and stream.lastSeq == 150
		and stream.firstSeq == 23
		and stream.truncated
)
assert(Events.forPlayer(state, 2).lastSeq == 0)
assert(#Events.forPlayer(state, 1, 149).entries == 1)
state.round = Events.maxRounds + 2
Events.prune(state)
assert(#Events.forPlayer(state, 1).entries == 0 and Events.forPlayer(state, 1).lastSeq == 150)

-- Network duplication, disorder, acknowledgement races, new campaigns and restarts.
state = fixture()
Events.notice(state, "research", nil, "agriculture", 1)
local sender = Snapshots.sender("host-one")
local packet1 = sender(1, World.forPlayer(state, 1))
Events.notice(state, "research", nil, "mining", 1)
local packet2 = sender(1, World.forPlayer(state, 1, 1))
local receiver = Snapshots.receiver()
local received, cursor = receiver:accept(packet1, 1)
assert(received and cursor == 1)
received, cursor = receiver:accept(packet2, 1)
assert(
	received and cursor == 2 and #received.eventStream.entries == 2,
	"Acknowledgement cannot erase pending presentation"
)
assert(
	not receiver:accept(packet1, 1) and not receiver:accept(packet2, 1),
	"Old snapshots must not rewind state"
)
local sender2 = Snapshots.sender("host-two")
assert(receiver:accept(sender2(1, World.forPlayer(state, 1)), 1))
assert(
	not receiver:accept(sender(1, World.forPlayer(state, 1)), 1),
	"Retired host sessions must not return"
)
state.campaignID = "new-campaign"
state.eventJournal = nil
received, cursor = receiver:accept(sender2(1, World.forPlayer(state, 1)), 1)
assert(received and cursor == 0 and #received.eventStream.entries == 0)
assert(
	not receiver:accept(sender2(1, World.forPlayer(state, 2)), 1),
	"Reject another observer's stream"
)

-- Malformed event packets are rejected without consuming a transport serial.
local good = sender2(1, World.forPlayer(state, 1))
good.state.eventStream.entries = nil
local beforeSerial = receiver.serial
assert(not receiver:accept(good, 1) and receiver.serial == beforeSerial)
good = sender2(1, World.forPlayer(state, 1))
good.serial = math.huge
assert(not receiver:accept(good, 1))
assert(
	not receiver:accept({ type = "state", state = World.forPlayer(state, 1) }, 1),
	"Late unsequenced packets must not replace a modern stream"
)

-- Cooperative yielding does not permit a second command to change an active transaction.
local queue = CommandQueue.new()
local trace = {}
local worker = coroutine.create(function()
	queue:submit(function()
		trace[#trace + 1] = "first-start"
		coroutine.yield("paused")
		trace[#trace + 1] = "first-end"
	end)
end)
assert(coroutine.resume(worker))
queue:submit(function()
	trace[#trace + 1] = "second"
end)
assert(#trace == 1 and queue.busy)
assert(coroutine.resume(worker))
assert(table.concat(trace, ",") == "first-start,first-end,second" and not queue.busy)
local notifications = 0
local reads = CommandQueue.new(function()
	notifications = notifications + 1
end)
local value = 0
local publishing = coroutine.create(function()
	reads:submit(function()
		assert(value == 0)
		coroutine.yield()
		assert(value == 0, "Snapshot construction interleaved a mutation")
	end, false)
end)
assert(coroutine.resume(publishing))
reads:submit(function()
	value = 1
end)
assert(coroutine.resume(publishing) and value == 1 and notifications == 1)
reads:submit(function()
	assert(value == 1)
end, false)
assert(notifications == 1, "Publishing must not trigger an endless state-change/publication loop")
local bounded = CommandQueue.new()
bounded.busy = true
bounded.maxPending = 2
assert(bounded:submit(function() end) and bounded:submit(function() end))
assert(not bounded:submit(function() end) and #bounded.pending == 2)
state = fixture()
state.units = {
	{ id = 10, owner = 1, kind = "warrior", x = 3, y = 6, movesLeft = 2 },
	{ id = 11, owner = 1, kind = "warrior", x = 5, y = 6, movesLeft = 2 },
}
World.reveal(state, Hex, Systems)
local second, queued
Systems.checkpoint = function()
	if not queued then
		queued = true
		queue:submit(function()
			second =
				Actions.apply(state, 1, { action = "move", sx = 5, sy = 6, x = 4, y = 6 }, Systems)
		end)
	end
end
queue:submit(function()
	assert(Actions.apply(state, 1, { action = "move", sx = 3, sy = 6, x = 4, y = 6 }, Systems))
end)
assert(second == false and state.units[1].x == 4 and state.units[2].x == 5)
Systems.checkpoint = nil
local autoState = fixture()
local scout = { id = 7, owner = 1, kind = "scout", x = 3, y = 6, hp = 100, movesLeft = 4 }
autoState.units = { scout }
World.reveal(autoState, Hex, Systems)
assert(Actions.apply(autoState, 1, { action = "autoExplore", x = scout.x, y = scout.y }, Systems))
local sawAutomated = false
for _, event in ipairs(Events.forPlayer(autoState, 1).entries) do
	if event.type == "move" then
		assert(event.ownAutoExplore)
		sawAutomated = true
	end
end
assert(sawAutomated and scout.executingAutoExplore == nil)
autoState.round, scout.movesLeft, scout.moved = 2, 2, false
local destination = Hex.reachable(autoState, scout, 1, Systems)[1]
assert(destination)
assert(
	Actions.apply(
		autoState,
		1,
		{ action = "move", sx = scout.x, sy = scout.y, x = destination.x, y = destination.y },
		Systems
	)
)
local manual
for _, event in ipairs(Events.forPlayer(autoState, 1).entries) do
	if event.type == "move" then
		manual = event
	end
end
assert(
	manual and not manual.ownAutoExplore,
	"A manual order overriding auto-explore is still replayable"
)
print(
	"CIVCRAFT: action-time redaction, partial combat, bounded replay, snapshot privacy/order and queued host commands passed."
)
