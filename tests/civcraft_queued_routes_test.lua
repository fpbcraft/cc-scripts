local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local A = dofile("/games/civcraft/actions.lua")
local H = dofile("/games/civcraft/hex.lua")
local S = dofile("/games/civcraft/systems.lua")
local Stack = dofile("/games/civcraft/unit_stacks.lua")
local Tasks = dofile("/games/civcraft/turn_tasks.lua")
local W = dofile("/games/civcraft/world.lua")
local function fixture(kind)
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		nextId = 10,
		players = {
			{ id = 1, name = "ONE", civ = "iron", techs = {}, gold = 100 },
			{ id = 2, name = "TWO", civ = "forge", techs = {}, gold = 100 },
		},
		cities = {},
		units = {
			{ id = 1, owner = 1, kind = kind or "warrior", x = 3, y = 4, movesLeft = 4 },
			{ id = 2, owner = 1, kind = "settler", x = 3, y = 4, movesLeft = 3 },
		},
		world = { width = 12, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} },
	}
	for y = 1, 10 do
		for x = 1, 12 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	S.migrate(state)
	W.reveal(state, H, S)
	return state, state.units[1], state.units[2]
end
local function command(state, unit, action, extra)
	local request = { action = action, unitID = unit.id, x = unit.x, y = unit.y }
	for key, value in pairs(extra or {}) do
		request[key] = value
	end
	return A.apply(state, unit.owner, request, S)
end
local function attach(state, unit, other)
	assert(command(state, unit, "attachEscort", { partnerID = other.id }))
	assert(Stack.partner(state, unit) == other and Stack.partner(state, other) == unit)
end
local function move(state, unit, x, y)
	return command(state, unit, "move", { sx = unit.x, sy = unit.y, x = x, y = y })
end
local Queue = dofile("/games/civcraft/queued_routes.lua")
local Movement = dofile("/games/civcraft/movement_budget.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local function order(state, unit, x, y, append)
	return command(
		state,
		unit,
		"queueMove",
		{ sx = unit.x, sy = unit.y, x = x, y = y, append = append }
	)
end
local function known(state)
	local owner = state.players[1]
	for key in pairs(state.world.tiles) do
		owner.explored[key] = true
	end
end
local function nextTurn(state)
	state.round = state.round + 1
	for _, unit in ipairs(state.units) do
		Movement.reset(state, unit, S.units[unit.kind], state.players[unit.owner], H)
	end
	W.reveal(state, H, S)
	Queue.run(state, 1, S, A.apply)
end
local state, unit = fixture()
state.units = { unit }
known(state)
unit.movesLeft = 2
assert(order(state, unit, 9, 4))
assert(unit.x == 5 and unit.movesLeft == 0 and unit.moveQueue)
assert(not Tasks.idle(state, unit, 1))
local queue, cursor = unit.moveQueue, unit.moveQueue.next
S.migrate(state)
assert(
	unit.movesLeft == 0 and unit.moveQueue == queue and queue.next == cursor,
	"Loading a route preserves progress and spent movement"
)
Queue.run(state, 1, S, A.apply)
assert(unit.x == 5 and queue.next == cursor)
nextTurn(state)
assert(unit.x == 7 and unit.movesLeft == 0 and unit.moveQueue)
nextTurn(state)
assert(unit.x == 9 and unit.movesLeft == 0 and not unit.moveQueue)

state, unit = fixture()
state.units = { unit }
known(state)
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 5, 4))
assert(order(state, unit, 7, 4, true))
assert(#unit.moveQueue.goals == 2 and unit.x == 3 and unit.movesLeft == 0)
nextTurn(state)
assert(
	unit.x == 5 and unit.moveQueue and #unit.moveQueue.goals == 1,
	"A reached waypoint leaves the queue immediately, even with no movement left"
)
nextTurn(state)
assert(unit.x == 7 and not unit.moveQueue)

state, unit = fixture()
state.units = { unit }
known(state)
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 9, 4))
assert(order(state, unit, 3, 7))
assert(#unit.moveQueue.goals == 1 and unit.moveQueue.goals[1].y == 7)
assert(not command(state, unit, "move", { sx = unit.x, sy = unit.y, x = 4, y = 4 }))
assert(unit.moveQueue, "Rejected manual orders retain future movement")
assert(command(state, unit, "cancelRoute"))
assert(not unit.moveQueue and unit.movesLeft == 0)

state, unit = fixture()
state.units = { unit }
known(state)
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 9, 4))
assert(command(state, unit, "skipTurn"))
assert(not unit.moveQueue)
assert(order(state, unit, 9, 4))
assert(command(state, unit, "standby", { value = true }))
assert(not unit.moveQueue and unit.standby)

state, unit = fixture()
state.units = { unit }
known(state)
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 9, 4))
local step = unit.moveQueue.path[2]
local enemy = { id = 3, owner = 2, kind = "settler", x = step.x, y = step.y, movesLeft = 2 }
state.units[#state.units + 1] = enemy
S.migrate(state)
nextTurn(state)
assert(
	unit.x == 3 and unit.moveQueue.paused and enemy.owner == 2,
	"Automatic routes pause rather than initiate melee capture"
)
assert(Tasks.idle(state, unit, 1), "Paused routes need attention")
assert(command(state, unit, "cancelRoute"))
assert(move(state, unit, step.x, step.y) and enemy.owner == 1)

state, unit = fixture()
state.units = { unit }
assert(
	not order(state, unit, 12, 10),
	"Unexplored deposits or obstacles cannot affect route planning"
)
known(state)
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 9, 4))
state.players[1].ready = true
state.round = 2
Movement.reset(state, unit, S.units[unit.kind], state.players[1], H)
Queue.run(state, 1, S, A.apply)
assert(unit.x == 3 and unit.movesLeft == 2, "Ready players do not execute queued orders")
state.players[1].ready = false
state.scheduler = Scheduler.new()
state.scheduler.groups = { { order = { 2, 1 }, active = 2 } }
Queue.run(state, 1, S, A.apply)
assert(unit.x == 3, "Inactive war-group members wait")
state.scheduler.groups[1].active = 1
Queue.run(state, 1, S, A.apply)
assert(unit.x == 5)
local position = unit.x
state.scheduler.reactions[1] = true
Queue.run(state, 1, S, A.apply)
assert(unit.x == position and unit.movesLeft == 0, "A response never refreshes spent movement")

local guard, settler
state, guard, settler = fixture()
known(state)
attach(state, guard, settler)
guard.movesLeft, settler.movesLeft = 2, 1
assert(order(state, guard, 9, 4))
assert(guard.x == 4 and settler.x == 4 and guard.movesLeft == 1 and settler.movesLeft == 0)
assert(order(state, settler, 9, 6, true))
assert(guard.moveQueue and not settler.moveQueue and #guard.moveQueue.goals == 2)
nextTurn(state)
assert(guard.x == settler.x and guard.y == settler.y and guard.movesLeft == 0)
assert(command(state, settler, "detachEscort"))
assert(not guard.moveQueue and not settler.moveQueue)
print(
	"CIVCRAFT: saved multi-turn routes, waypoints, budgets, manual cancellation, fog, combat stops, war eligibility and escort queues passed."
)

local UI = dofile("/games/civcraft/ui.lua")
for _, graphics in ipairs({ false, true }) do
	state, unit = fixture()
	state.units = { unit }
	known(state)
	unit.movesLeft, unit.moved = 0, true
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 342, 342
			end
			return 57, 38
		end,
		setCursorPos = function() end,
		setTextColor = function() end,
		setBackgroundColor = function() end,
		write = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.drawPixels = function() end
		monitor.getPaletteColor = function()
			return 0, 0, 0
		end
		monitor.setPaletteColor = function() end
	end
	local ui = UI.new(monitor, function(action, request)
		request.action = action
		assert(A.apply(state, 1, request, S))
	end)
	local function draw()
		ui:draw(W.forPlayer(state, 1), 1, {})
	end
	local function press(label)
		for _ = 1, 50 do
			draw()
			for _, button in ipairs(ui.r.buttons) do
				if button.label == label then
					button.fn()
					return
				end
			end
			for _, button in ipairs(ui.r.buttons) do
				if button.label == "NEXT" then
					button.fn()
				end
			end
		end
		error("Missing queue control: " .. label)
	end
	draw()
	ui:focus("unit", unit)
	press("QUEUE MOVES")
	draw()
	assert(ui.source and ui.source.queue, "Spent units may assign future routes")
	ui:tile(9, 4)
	assert(ui.pendingMove and ui.pendingMove.queued and not ui.pendingMove.append)
	press("CONFIRM")
	assert(unit.moveQueue and unit.movesLeft == 0)
	ui:focus("unit", unit)
	press("ADD WAYPOINT")
	ui:tile(9, 6)
	press("CONFIRM")
	assert(#unit.moveQueue.goals == 2)
	ui:focus("unit", unit)
	press("CANCEL ROUTE")
	assert(not unit.moveQueue and unit.movesLeft == 0)
	ui:close()
end
print(
	"CIVCRAFT: compact text/graphics route assignment, waypoint confirmation and cancellation passed."
)

state, unit = fixture()
state.units = { unit }
known(state)
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 9, 4))
state.players[2].visible[W.key(unit.x, unit.y)] = true
local opponent = W.forPlayer(state, 2)
assert(
	#opponent.units == 1 and opponent.units[1].moveQueue == nil,
	"Visible foreign formations do not reveal destinations or processing stamps"
)
local savedQueue = unit.moveQueue
unit.moveQueue = { version = 999, goals = {}, path = {}, next = 2 }
S.migrate(state)
assert(not unit.moveQueue and unit.movesLeft == 0)
unit.moveQueue = savedQueue
savedQueue.path[2].x = -100
S.migrate(state)
assert(
	not unit.moveQueue and unit.movesLeft == 0,
	"Invalid saved paths are discarded without fresh movement"
)

state, unit = fixture()
state.units = { unit }
known(state)
state.players[1].techs.navigation = true
for y = 1, 10 do
	for x = 1, 12 do
		state.world.tiles[W.key(x, y)] = "water"
	end
end
state.world.tiles[W.key(9, 4)] = "plains"
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 9, 4))
nextTurn(state)
assert(
	unit.x == 9 and unit.movesLeft == 0 and not unit.moveQueue,
	"Queued sea travel uses water-start allowance and spends the rest on landing"
)
print("CIVCRAFT: route privacy, malformed-save cleanup and queued sea landing passed.")
