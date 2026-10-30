-- Saved player intentions. Execution always delegates each affordable step to shared actions.
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Routes = dofile("/games/civcraft/ai_routes.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Tasks = dofile("/games/civcraft/turn_tasks.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Zone = dofile("/games/civcraft/zone_control.lua")
local Events = dofile("/games/civcraft/events.lua")
local Queue = { maxGoals = 16 }
local function copy(unit)
	local result = {}
	for key, value in pairs(unit) do
		result[key] = value
	end
	return result
end
function Queue.get(state, unit)
	if unit.moveQueue then
		return unit.moveQueue, unit
	end
	local partner = Stacks.partner(state, unit)
	if partner then
		return partner.moveQueue, partner
	end
end
function Queue.cancel(state, unit)
	unit.moveQueue = nil
	local partner = Stacks.partner(state, unit)
	if partner then
		partner.moveQueue = nil
	end
end
function Queue.preview(view, unit, x, y, append, systems, options)
	options = options or {}
	if not Hex.inBounds(x, y, view) then
		return nil, "Choose a destination on the map"
	end
	if not view.world then
		return nil, "Route map is unavailable"
	end
	local knownTiles = view.world and view.world.tiles or {}
	local unknownDestination = knownTiles[World.key(x, y)] == nil
	local saved = Queue.get(view, unit)
	local companion = Stacks.partner(view, unit)
	local traveler = copy(unit)
	if append and saved and #saved.goals > 0 then
		local tail = saved.goals[#saved.goals]
		traveler.x, traveler.y = tail.x, tail.y
	end
	local function canEnter(xx, yy)
		return Stacks.canEnterGroup(view, traveler, companion, xx, yy)
	end
	if not canEnter(x, y) then
		return nil, "Route destination is occupied"
	end
	for _, city in ipairs(view.cities or {}) do
		if city.owner ~= unit.owner and city.x == x and city.y == y then
			return nil, "Route orders cannot initiate combat"
		end
	end
	local routes = Routes.from(view, traveler, systems, {
		maxCost = view.world.width * view.world.height * 6,
		maxNodes = view.world.width * view.world.height,
		allowUnknown = unknownDestination or options.allowUnknown == true,
		targetKey = World.key(x, y),
		canEnter = canEnter,
		step = function(from, to)
			local fromKnown = knownTiles[World.key(from.x, from.y)] ~= nil
			local toKnown = knownTiles[World.key(to.x, to.y)] ~= nil
			if not toKnown then
				-- Unknown terrain has a neutral estimate. The observer projection
				-- deliberately contains no terrain, deposit, or unit data for it.
				return 1
			end
			local fromX, fromY = fromKnown and from.x or nil, fromKnown and from.y or nil
			local a = Hex.moveCost(to.x, to.y, view, traveler, systems, fromX, fromY)
			local b = companion and Hex.moveCost(to.x, to.y, view, companion, systems, fromX, fromY)
			if not a or companion and not b then
				return nil
			end
			return math.max(a, b or a)
		end,
	})
	local path = routes.pathTo(x, y)
	if not path then
		return nil, "No route through explored, passable terrain"
	end
	return path
end
function Queue.submit(state, unit, x, y, append, systems)
	local saved, leader = Queue.get(state, unit)
	if append and saved then
		unit = leader
	end
	if append and saved and #saved.goals >= Queue.maxGoals then
		return false, "Movement queue is full"
	end
	local path, reason =
		Queue.preview(World.forPlayer(state, unit.owner), unit, x, y, append, systems)
	if not path then
		return false, reason
	end
	if #path < 2 then
		return false, "Choose another route destination"
	end
	local goals = {}
	if append and saved then
		for _, goal in ipairs(saved.goals) do
			goals[#goals + 1] = { x = goal.x, y = goal.y }
		end
	end
	goals[#goals + 1] = { x = x, y = y }
	local companion = Stacks.partner(state, unit)
	Queue.cancel(state, unit)
	unit.moveQueue = {
		version = 1,
		goals = goals,
		path = append and saved and saved.path or path,
		next = append and saved and saved.next or 2,
	}
	for _, member in ipairs({ unit, companion }) do
		member.standby, member.healing, member.autoExplore, member.skippedTurn =
			false, false, false, nil
	end
	Events.notice(state, "order", unit, "Movement route queued", unit.owner)
	return true
end
local function pause(state, unit, queue, reason)
	queue.paused = reason or "Movement route blocked"
	Events.notice(
		state,
		"order",
		unit,
		queue.paused .. "; reassign or cancel the route",
		unit.owner
	)
end
local function nextLeg(state, unit, queue, systems)
	table.remove(queue.goals, 1)
	local goal = queue.goals[1]
	if not goal then
		unit.moveQueue = nil
		Events.notice(state, "order", unit, "Movement route completed", unit.owner)
		return false
	end
	local path, reason =
		Queue.preview(World.forPlayer(state, unit.owner), unit, goal.x, goal.y, false, systems)
	if not path then
		pause(state, unit, queue, reason)
		return false
	end
	queue.path, queue.next = path, 2
	return true
end
function Queue.run(state, owner, systems, apply, force)
	if state.phase ~= "game" or not Scheduler.canAct(state, owner) then
		return
	end
	local stamp = Tasks.stamp(state, owner)
	for _, unit in ipairs(state.units) do
		local queue = unit.owner == owner and unit.moveQueue
		if
			queue
			and not queue.paused
			and (force == unit or not force and queue.processed ~= stamp)
		then
			queue.processed = stamp
			local limit = state.world.width * state.world.height + Queue.maxGoals
			for _ = 1, limit do
				local companion = Stacks.partner(state, unit)
				if
					unit.moved
					or (unit.movesLeft or 0) <= 0
					or companion and (companion.moved or (companion.movesLeft or 0) <= 0)
					or Zone.locked(state, unit, systems)
					or companion and Zone.locked(state, companion, systems)
				then
					break
				end
				local goal = queue.goals[1]
				if not goal then
					unit.moveQueue = nil
					break
				end
				if unit.x == goal.x and unit.y == goal.y then
					if not nextLeg(state, unit, queue, systems) then
						break
					end
					goal = queue.goals[1]
				end
				local step = queue.path[queue.next]
				if not step or Hex.distance(unit.x, unit.y, step.x, step.y, state) ~= 1 then
					pause(state, unit, queue, "Movement route changed")
					break
				end
				local cost = Hex.moveCost(
					step.x,
					step.y,
					state,
					unit,
					systems,
					unit.x,
					unit.y,
					unit.movesLeft
				)
				local otherCost = companion
					and Hex.moveCost(
						step.x,
						step.y,
						state,
						companion,
						systems,
						companion.x,
						companion.y,
						companion.movesLeft
					)
				if
					cost and cost > unit.movesLeft
					or companion and otherCost and otherCost > companion.movesLeft
				then
					break
				end
				local legal
				for _, choice in ipairs(Hex.reachable(state, unit, owner, systems)) do
					if choice.x == step.x and choice.y == step.y and not choice.attack then
						legal = choice
						break
					end
				end
				if not legal then
					pause(state, unit, queue, "Movement route blocked")
					break
				end
				unit.executingQueue = true
				local ran, ok, reason = pcall(apply, state, owner, {
					action = "move",
					unitID = unit.id,
					sx = unit.x,
					sy = unit.y,
					x = step.x,
					y = step.y,
				}, systems)
				unit.executingQueue = nil
				if not ran then
					error(ok, 0)
				end
				if not ok or unit.x ~= step.x or unit.y ~= step.y then
					pause(state, unit, queue, reason)
					break
				end
				queue.next = queue.next + 1
				if
					unit.x == goal.x
					and unit.y == goal.y
					and not nextLeg(state, unit, queue, systems)
				then
					break
				end
			end
		end
	end
end
function Queue.migrate(state)
	local area = (state.world and state.world.width or Hex.width)
		* (state.world and state.world.height or Hex.height)
	for _, unit in ipairs(state.units or {}) do
		local queue = unit.moveQueue
		if queue then
			local valid = type(queue) == "table"
				and queue.version == 1
				and type(queue.goals) == "table"
				and #queue.goals > 0
				and #queue.goals <= Queue.maxGoals
				and type(queue.path) == "table"
				and #queue.path >= 2
				and #queue.path <= area + 1
				and type(queue.next) == "number"
				and queue.next % 1 == 0
				and queue.next >= 2
				and queue.next <= #queue.path + 1
			for _, point in ipairs(valid and queue.path or {}) do
				if
					type(point) ~= "table"
					or type(point.x) ~= "number"
					or type(point.y) ~= "number"
					or point.x % 1 ~= 0
					or point.y % 1 ~= 0
					or not Hex.inBounds(point.x, point.y, state)
				then
					valid = false
					break
				end
			end
			for _, goal in ipairs(valid and queue.goals or {}) do
				if
					type(goal) ~= "table"
					or type(goal.x) ~= "number"
					or type(goal.y) ~= "number"
					or goal.x % 1 ~= 0
					or goal.y % 1 ~= 0
					or not Hex.inBounds(goal.x, goal.y, state)
				then
					valid = false
					break
				end
			end
			if not valid then
				unit.moveQueue = nil
			end
		end
	end
end
return Queue
