-- Saved Builder tasks; each movement and improvement uses shared authoritative actions.
local Works = dofile("/games/civcraft/tile_improvements.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Routes = dofile("/games/civcraft/queued_routes.lua")
local Hostility = dofile("/games/civcraft/hostility.lua")
local Tasks = dofile("/games/civcraft/turn_tasks.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Events = dofile("/games/civcraft/events.lua")
local Work = { maxTasks = 16 }
function Work.threat(view, owner, x, y, systems)
	for _, other in ipairs(view.units or {}) do
		local stats = systems.units[other.kind] or {}
		if
			Hostility.canAttack(view, owner, other.owner)
			and (stats.strength or 0) > 0
			and Hex.distance(x, y, other.x, other.y, view) <= math.max(2, stats.range or 1)
		then
			return true
		end
	end
	for _, city in ipairs(view.cities or {}) do
		if
			Hostility.canAttack(view, owner, city.owner)
			and Hex.distance(x, y, city.x, city.y, view) <= 2
		then
			return true
		end
	end
	return false
end
function Work.submit(state, player, unit, kind, x, y, append, systems, auto)
	local view = World.forPlayer(state, player.id)
	local preview, reason = Works.preview(view, player, unit, kind, x, y, systems)
	if not preview then
		return false, reason
	end
	local previous = append and unit.workQueue and unit.workQueue.tasks or {}
	if #previous >= math.min(Work.maxTasks, unit.charges or 0) then
		return false, "Not enough Builder charges for another queued task"
	end
	local traveler = {}
	for key, value in pairs(unit) do
		traveler[key] = value
	end
	local tail = previous[#previous]
	if tail then
		traveler.x, traveler.y = tail.x, tail.y
	end
	if traveler.x ~= x or traveler.y ~= y then
		local path, why = Routes.preview(view, traveler, x, y, false, systems)
		if not path then
			return false, why
		end
	end
	local tasks = {}
	for _, task in ipairs(previous) do
		if task.x == x and task.y == y then
			return false, "Tile is already queued"
		end
		tasks[#tasks + 1] = { kind = task.kind, x = task.x, y = task.y }
	end
	tasks[#tasks + 1] = { kind = kind, x = x, y = y }
	unit.moveQueue = nil
	unit.workQueue = { version = 1, tasks = tasks, auto = auto == true }
	local Stacks = dofile("/games/civcraft/unit_stacks.lua")
	for _, member in ipairs({ unit, Stacks.partner(state, unit) }) do
		member.standby, member.healing, member.skippedTurn = false, false, nil
	end
	return true, "Builder work queued", preview
end
function Work.pause(state, unit, reason)
	if not unit.workQueue then
		return
	end
	unit.workQueue.paused = reason
	if unit.workQueue.auto then
		unit.autoWorkPaused = reason
	end
	Events.notice(state, "order", unit, "Builder paused: " .. reason, unit.owner)
end
function Work.planAuto(state, owner, systems, apply)
	local Builders = dofile("/games/civcraft/ai_builders.lua")
	local ids = {}
	local stamp = Tasks.stamp(state, owner)
	for _, unit in ipairs(state.units or {}) do
		if
			unit.owner == owner
			and unit.kind == "builder"
			and unit.autoWork
			and not unit.autoWorkPaused
			and not unit.workQueue
			and unit.autoWorkScanStamp ~= stamp
			and (unit.charges or 0) > 0
		then
			ids[#ids + 1] = unit.id
		end
	end
	local Stacks = dofile("/games/civcraft/unit_stacks.lua")
	for _, id in ipairs(ids) do
		local unit = Stacks.byID(state, id)
		if unit and unit.autoWork and not unit.autoWorkPaused and not unit.workQueue then
			unit.autoWorkScanStamp = stamp
			local view = World.forPlayer(state, owner)
			local player
			for _, candidate in ipairs(view.players or {}) do
				if candidate.id == owner then
					player = candidate
					break
				end
			end
			local request, reason
			if player then
				request, reason = Builders.order(view, player, unit, systems)
			end
			if request then
				unit.autoWorkPlanning = true
				local ran, ok = pcall(apply, state, owner, request, systems)
				unit.autoWorkPlanning = nil
				if not ran then
					error(ok, 0)
				end
				if ok then
					unit.autoWorkPaused = nil
				else
					unit.autoWorkPaused = "The selected improvement could not be queued"
				end
			elseif reason or Work.threat(view, owner, unit.x, unit.y, systems) then
				unit.autoWorkPaused = reason or "Visible threat nearby"
			else
				unit.autoWorkPaused =
					"No useful legal improvement is available on observed owned land"
			end
		end
	end
end
function Work.run(state, owner, systems, apply, force)
	if state.phase ~= "game" or not Scheduler.canAct(state, owner) then
		return
	end
	local ids = {}
	for _, unit in ipairs(state.units) do
		if unit.owner == owner and unit.workQueue then
			ids[#ids + 1] = unit.id
		end
	end
	local Stacks = dofile("/games/civcraft/unit_stacks.lua")
	local stamp = Tasks.stamp(state, owner)
	for _, id in ipairs(ids) do
		local unit = Stacks.byID(state, id)
		local queue = unit and unit.workQueue
		if queue and not queue.paused and (force == unit or queue.processed ~= stamp) then
			queue.processed = stamp
			-- At most one task completes per turn; movement is bounded by the unit allowance.
			for _ = 1, 32 do
				local companion = Stacks.partner(state, unit)
				if companion and (companion.moved or (companion.movesLeft or 0) <= 0) then
					break
				end
				if
					unit.skippedTurn == stamp
					or unit.moved
					or (unit.movesLeft or 0) <= 0
					or not unit.workQueue
				then
					break
				end
				local task = queue.tasks[1]
				if not task then
					unit.workQueue = nil
					break
				end
				local view = World.forPlayer(state, owner)
				local player
				for _, candidate in ipairs(view.players) do
					if candidate.id == owner then
						player = candidate
					end
				end
				local valid, reason =
					Works.canPlace(view, player, task.kind, task.x, task.y, systems)
				if not valid then
					Work.pause(state, unit, reason)
					break
				end
				if Work.threat(view, owner, unit.x, unit.y, systems) then
					Work.pause(state, unit, "Visible threat nearby")
					break
				end
				local request = { x = unit.x, y = unit.y, unitID = unit.id }
				if unit.x == task.x and unit.y == task.y then
					request.action, request.kind = "improve", task.kind
				else
					local path, why = Routes.preview(view, unit, task.x, task.y, false, systems)
					if not path then
						Work.pause(state, unit, why)
						break
					end
					local step = path[2]
					if not step then
						Work.pause(state, unit, "Work route changed")
						break
					end
					if Work.threat(view, owner, step.x, step.y, systems) then
						Work.pause(state, unit, "Visible threat on work route")
						break
					end
					local legal
					for _, choice in ipairs(Hex.reachable(state, unit, owner, systems)) do
						if not choice.attack and choice.x == step.x and choice.y == step.y then
							legal = choice
							break
						end
					end
					if not legal then
						local cost = Hex.moveCost(
							step.x,
							step.y,
							view,
							unit,
							systems,
							unit.x,
							unit.y,
							unit.movesLeft
						)
						if cost and cost > unit.movesLeft then
							break
						end
						Work.pause(state, unit, "Work route blocked")
						break
					end
					request.action, request.sx, request.sy, request.x, request.y =
						"move", unit.x, unit.y, step.x, step.y
				end
				unit.executingWork = true
				local ran, ok, why = pcall(apply, state, owner, request, systems)
				unit.executingWork = nil
				if not ran then
					error(ok, 0)
				end
				if not ok then
					Work.pause(state, unit, why or "Work order rejected")
					break
				end
				if request.action == "improve" then
					table.remove(queue.tasks, 1)
					if #queue.tasks == 0 or unit.charges == 0 then
						unit.workQueue = nil
						if unit.charges == 0 then
							unit.autoWork = false
							unit.autoWorkPaused = "No Builder charges remain"
						end
					end
					break
				end
			end
		end
	end
end
return Work
