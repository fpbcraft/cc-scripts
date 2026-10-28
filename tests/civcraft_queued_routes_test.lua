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
assert(
	unit.moveQueue.paused == "Movement route blocked"
		and unit.moveQueue.next == 2
		and unit.moveQueue.goals[1].x == 9,
	"A blocked route reports no hidden cause and preserves its cursor and destination"
)
assert(Tasks.idle(state, unit, 1), "Paused routes need attention")
assert(command(state, unit, "cancelRoute"))
assert(move(state, unit, step.x, step.y) and enemy.owner == 1)

state, unit = fixture()
state.units = { unit }
local unknownGoal = { x = 12, y = 10 }
local privateView = W.forPlayer(state, unit.owner)
local goalKey = W.key(unknownGoal.x, unknownGoal.y)
assert(not privateView.world.tiles[goalKey], "The destination starts undiscovered")
local unseenPath = Queue.preview(privateView, unit, unknownGoal.x, unknownGoal.y, false, S)
assert(unseenPath and unseenPath[#unseenPath].x == unknownGoal.x)
local unknownStep
for index = 2, #unseenPath do
	local point = unseenPath[index]
	if not privateView.world.tiles[W.key(point.x, point.y)] then
		unknownStep = point
		break
	end
end
assert(unknownStep, "The planned path enters fog without terrain data")
state.world.tiles[goalKey] = "mountain"
state.units[#state.units + 1] = {
	id = 90,
	owner = 2,
	kind = "warrior",
	x = unknownStep.x,
	y = unknownStep.y,
	movesLeft = 1,
}
privateView = W.forPlayer(state, unit.owner)
local sameUnseenPath = Queue.preview(privateView, unit, unknownGoal.x, unknownGoal.y, false, S)
assert(#sameUnseenPath == #unseenPath, "Hidden terrain and units do not change preview routing")
for index, point in ipairs(unseenPath) do
	assert(
		sameUnseenPath[index].x == point.x and sameUnseenPath[index].y == point.y,
		"The route preview is independent of hidden map contents"
	)
end
privateView = W.forPlayer(state, unit.owner)
assert(not privateView.world.tiles[goalKey], "A queued destination does not expose its terrain")
for _, observed in ipairs(privateView.units) do
	assert(
		observed.id ~= 90,
		"A hidden unit on the proposed route is absent from the observer projection"
	)
end
state, unit = fixture()
state.units = { unit }
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

state, unit = fixture()
state.units = { unit }
unit.movesLeft = 4
local unseenView = W.forPlayer(state, unit.owner)
local costEstimate = Queue.preview(unseenView, unit, 12, 4, false, S)
assert(costEstimate and #costEstimate >= 6)
local expensiveStep = costEstimate[5]
local expensiveKey = W.key(expensiveStep.x, expensiveStep.y)
assert(
	not unseenView.world.tiles[expensiveKey],
	"The higher-cost tile starts hidden at " .. expensiveKey .. " from " .. tostring(#costEstimate)
)
state.world.tiles[expensiveKey] = "forest"
assert(order(state, unit, 12, 4))
assert(
	unit.x == costEstimate[4].x
		and unit.y == costEstimate[4].y
		and unit.movesLeft == 1
		and unit.moveQueue
		and not unit.moveQueue.paused
		and unit.moveQueue.next == 5,
	"A newly discovered forest waits for enough movement without pausing the route"
)
nextTurn(state)
assert(
	unit.x == expensiveStep.x
		and unit.y == expensiveStep.y
		and unit.moveQueue
		and not unit.moveQueue.paused,
	"The route continues through the revealed higher-cost tile next turn"
)

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
local MapView = dofile("/games/civcraft/map_view.lua")
state, unit = fixture()
state.units = { unit }
known(state)
unit.movesLeft, unit.moved = 0, true
assert(order(state, unit, 9, 4))
local blockedStep = unit.moveQueue.path[2]
state.units[#state.units + 1] = {
	id = 90,
	owner = 2,
	kind = "settler",
	x = blockedStep.x,
	y = blockedStep.y,
	movesLeft = 1,
}
state.round = state.round + 1
Movement.reset(state, unit, S.units[unit.kind], state.players[unit.owner], H)
W.reveal(state, H, S)
Queue.run(state, 1, S, A.apply)
assert(unit.moveQueue.paused == "Movement route blocked")
local blockedView = W.forPlayer(state, 1)
local blockedOverlay = MapView.queuedRoute(
	{ playerID = 1, selected = { kind = "unit", unitID = unit.id } },
	blockedView,
	blockedView.players[1]
)
assert(
	blockedOverlay and blockedOverlay.paused,
	"Observer route overlay marks a paused reason string"
)

for _, graphics in ipairs({ false, true }) do
	state, unit = fixture()
	state.units = { unit }
	assert(not W.forPlayer(state, 1).world.tiles[W.key(9, 4)])
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
	draw()
	local savedRoute = MapView.queuedRoute(ui, ui.state, ui.state.players[1])
	assert(
		savedRoute and #savedRoute.goals == 1 and #savedRoute.segments[1].points > 1,
		"Selecting a unit displays its committed path and unknown destination"
	)
	assert(
		MapView.queuedRoute(ui, ui.state, ui.state.players[1]) == savedRoute,
		"An unchanged selected route reuses its observer-safe overlay cache"
	)
	local entersFog = false
	for _, point in ipairs(savedRoute.segments[1].points) do
		if not ui.state.world.tiles[W.key(point.x, point.y)] then
			entersFog = true
		end
	end
	assert(entersFog, "The rendered route distinguishes its fogged continuation")
	ui:focus("unit", unit)
	press("ADD WAYPOINT")
	ui:tile(9, 6)
	assert(ui.pendingMove and ui.pendingMove.queued, "The pending waypoint has its own preview")
	local stillCommitted = MapView.queuedRoute(ui, ui.state, ui.state.players[1])
	assert(
		stillCommitted and #stillCommitted.goals == 1,
		"An armed waypoint preview preserves the previously committed route"
	)
	press("CONFIRM")
	assert(#unit.moveQueue.goals == 2)
	draw()
	local fullRoute = MapView.queuedRoute(ui, ui.state, ui.state.players[1])
	assert(
		fullRoute and #fullRoute.goals == 2 and #fullRoute.segments >= 2,
		"The selected unit shows every saved waypoint, including an observer-only estimate"
	)
	local beforeAdvance = unit.x .. ":" .. unit.y
	nextTurn(state)
	draw()
	assert(
		ui.selected.x == unit.x
			and ui.selected.y == unit.y
			and (unit.x .. ":" .. unit.y) ~= beforeAdvance,
		"Selection and route progress follow the unit after queued movement"
	)
	local afterAdvance = MapView.queuedRoute(ui, ui.state, ui.state.players[1])
	assert(
		afterAdvance
			and afterAdvance ~= fullRoute
			and afterAdvance.segments[1].points[1].x == unit.x
			and afterAdvance.segments[1].points[1].y == unit.y,
		"Movement progress invalidates the cached overlay and starts it at the unit"
	)
	local newlyObserved = afterAdvance.segments[1].points[2]
	assert(
		newlyObserved and W.forPlayer(state, 1).world.tiles[W.key(newlyObserved.x, newlyObserved.y)],
		"Newly discovered route steps use current terrain instead of a fog estimate"
	)
	ui:focus("unit", unit)
	press("CANCEL ROUTE")
	assert(not unit.moveQueue and unit.movesLeft == 0)
	draw()
	assert(
		MapView.queuedRoute(ui, ui.state, ui.state.players[1]) == nil,
		"Cancelling a saved route removes its overlay"
	)
	assert(order(state, unit, 9, 6), "A spent selected unit can queue a route before skipping")
	draw()
	assert(MapView.queuedRoute(ui, ui.state, ui.state.players[1]))
	assert(command(state, unit, "skipTurn"))
	draw()
	assert(
		ui.selected.kind == "unit"
			and ui.selected.x == unit.x
			and ui.selected.y == unit.y
			and MapView.queuedRoute(ui, ui.state, ui.state.players[1]) == nil,
		"Skipping clears the route without leaving a stale unit selection or overlay"
	)
	ui:close()
end
print(
	"CIVCRAFT: compact text/graphics route assignment, waypoint confirmation and cancellation passed."
)

state, unit = fixture()
state.units = { unit }
state.mapSize = "vast"
state.world.width, state.world.height = 120, 76
state.world.tiles = {}
state.world.geography = {}
state.world.resources = {}
state.world.rails = {}
state.world.landmarks = {}
for y = 1, state.world.height do
	for x = 1, state.world.width do
		state.world.tiles[W.key(x, y)] = "plains"
	end
end
state.players[1].explored = {}
W.reveal(state, H, S)
local largeView = W.forPlayer(state, 1)
local largeGoals = {
	{ x = 22, y = 4 },
	{ x = 42, y = 12 },
	{ x = 62, y = 24 },
	{ x = 83, y = 42 },
	{ x = 103, y = 58 },
	{ x = 119, y = 75 },
}
local largePath = Queue.preview(largeView, unit, largeGoals[1].x, largeGoals[1].y, false, S)
assert(largePath and #largePath > 12, "Vast route starts with a long saved leg")
local hiddenKey =
	W.key(largePath[math.floor(#largePath / 2)].x, largePath[math.floor(#largePath / 2)].y)
state.world.tiles[hiddenKey] = "mountain"
state.units[#state.units + 1] = {
	id = 90,
	owner = 2,
	kind = "warrior",
	x = tonumber(hiddenKey:match("^(%d+):")),
	y = tonumber(hiddenKey:match(":(%d+)$")),
	movesLeft = 1,
}
unit.moveQueue = { version = 1, goals = largeGoals, path = largePath, next = 2 }
largeView = W.forPlayer(state, 1)
assert(not largeView.world.tiles[hiddenKey], "The saved route's hidden mountain stays unknown")
for _, observed in ipairs(largeView.units) do
	assert(observed.id ~= 90, "The hidden blocker stays out of the observer projection")
end
local largeMonitor = {
	getSize = function()
		return 57, 38
	end,
	setCursorPos = function() end,
	setTextColor = function() end,
	setBackgroundColor = function() end,
	write = function() end,
}
local largeUI = UI.new(largeMonitor, function() end)
largeUI.selected = { kind = "unit", unitID = unit.id, x = unit.x, y = unit.y }
local originalPreview = Queue.preview
local previewCalls = 0
Queue.preview = function(...)
	previewCalls = previewCalls + 1
	return originalPreview(...)
end
local clipWrites = 0
local originalFill, originalWithClip = largeUI.r.fill, largeUI.r.withClip
local insideClip = false
largeUI.r.fill = function(renderer, x, y, w, h, color)
	if insideClip and (color == 13 or color == 16) then
		local clip = renderer.clip
		assert(
			clip
				and clip.x >= 0
				and clip.y >= 0
				and clip.x + clip.w <= renderer.w
				and clip.y + clip.h <= renderer.h,
			"Vast route overlay keeps dotted path drawing inside the renderer viewport"
		)
		clipWrites = clipWrites + 1
	end
	return originalFill(renderer, x, y, w, h, color)
end
largeUI.r.withClip = function(renderer, rect, draw)
	return originalWithClip(renderer, rect, function()
		local wasInside = insideClip
		insideClip = true
		local ok, result = pcall(draw)
		insideClip = wasInside
		if not ok then
			error(result, 0)
		end
		return result
	end)
end
local coldStart = os.clock()
largeUI:draw(largeView, 1, {})
local coldSeconds = os.clock() - coldStart
local coldSearches = previewCalls
assert(coldSearches == #largeGoals - 1, "Cold Vast overlay estimates each later waypoint once")
local warmStart = os.clock()
largeUI:draw(largeView, 1, {})
local warmSeconds = os.clock() - warmStart
local warmSearches = previewCalls - coldSearches
assert(warmSearches == 0, "A cached Vast redraw performs no new route searches")
assert(
	clipWrites > 0 and largeUI.r.clip == nil,
	"Vast route marks render under a restored viewport clip"
)
Queue.preview = originalPreview
largeUI:close()
print(
	string.format(
		"CIVCRAFT: Vast 120x76 route overlay cold %.3f s / %d future searches; cached %.3f s / 0 searches; %d clipped dotted writes.",
		coldSeconds,
		coldSearches,
		warmSeconds,
		clipWrites
	)
)
local metrics = assert(fs.open("/civcraft-route-overlay-metrics.txt", "w"))
metrics.write(
	string.format(
		"cold_seconds=%.3f\ncold_searches=%d\nwarm_seconds=%.3f\nwarm_searches=%d\nclipped_dotted_writes=%d\n",
		coldSeconds,
		coldSearches,
		warmSeconds,
		warmSearches,
		clipWrites
	)
)
metrics.close()

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
