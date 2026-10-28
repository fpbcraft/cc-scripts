--[[
	Walk only an already validated route, revealing each traversed hex in order.
	Presentation consumes the frozen event; it never drives simulation positions.
]]
local Events = dofile("/games/civcraft/events.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Perception = dofile("/games/civcraft/diplomatic_perception.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Zone = dofile("/games/civcraft/zone_control.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local UnitMovement = {}

function UnitMovement.walk(state, unit, path, systems, lastPoint)
	local finish = lastPoint or #path
	if finish < 2 then
		return 0, true
	end
	local spent, completed, reason = 0, true, nil
	local companion = Stacks.partner(state, unit)
	local notices = {}
	World.reveal(state, Hex, systems, notices)
	local event = Events.move(state, unit)
	local following = companion and Events.move(state, companion)
	if following then
		following.autoExplore = event.autoExplore
	end
	for index = 2, finish do
		local position = path[index]
		assert(
			Hex.distance(unit.x, unit.y, position.x, position.y) == 1,
			"Nonadjacent approved route"
		)
		if
			Zone.locked(state, unit, systems)
			or companion and Zone.locked(state, companion, systems)
		then
			completed, reason = false, "Stopped in enemy zone of control"
			break
		end
		local blocked = not Stacks.canEnterGroup(state, unit, companion, position.x, position.y)
		for _, city in ipairs(state.cities or {}) do
			if city.owner ~= unit.owner and city.x == position.x and city.y == position.y then
				blocked = true
			end
		end
		local cost = Hex.moveCost(
			position.x,
			position.y,
			state,
			unit,
			systems,
			unit.x,
			unit.y,
			(unit.movesLeft or 0) - spent
		)
		local otherCost = companion
			and Hex.moveCost(
				position.x,
				position.y,
				state,
				companion,
				systems,
				companion.x,
				companion.y,
				companion.movesLeft or systems.units[companion.kind].move
			)
		if
			companion
			and (not otherCost or otherCost > (companion.movesLeft or 0) or companion.moved)
		then
			completed, reason = false, "Escort cannot continue: no affordable legal step"
			break
		end
		if blocked or not cost then
			completed, reason = false, "Route blocked"
			break
		end
		spent = spent + cost
		unit.x, unit.y = position.x, position.y
		unit.actedThisRound = true
		if companion then
			companion.x, companion.y = position.x, position.y
			companion.movesLeft = math.max(0, companion.movesLeft - otherCost)
			companion.moved = companion.movesLeft <= 0
			companion.actedThisRound = true
			companion.standby, companion.healing, companion.autoExplore, companion.skippedTurn =
				false, false, false, nil
		end
		World.reveal(state, Hex, systems, notices)
		Perception.move(state, unit, Hex, World, Diplomacy)
		if companion then
			Perception.move(state, companion, Hex, World, Diplomacy)
		end
		Events.step(event, state, unit)
		if following then
			Events.step(following, state, companion)
		end
		local ownStop = Zone.enter(state, unit, systems, Hex)
		local otherStop = companion and Zone.enter(state, companion, systems, Hex)
		if ownStop or otherStop then
			if ownStop and Zone.civilian(unit, systems) then
				spent = math.max(spent, unit.movesLeft or spent)
			end
			if otherStop and Zone.civilian(companion, systems) then
				companion.movesLeft, companion.moved = 0, true
			end
			if index < finish then
				completed, reason = false, "Stopped in enemy zone of control"
			end
			break
		end
	end
	if #event.frames > 1 then
		Events.emit(state, event)
	end
	if following and #following.frames > 1 then
		Events.emit(state, following)
	end
	for _, notice in ipairs(notices) do
		Events.emit(state, notice)
	end
	return spent, completed, reason
end

-- Combat has already advanced the guard. Move its companion atomically before snapshots publish;
-- return frozen events so the caller can emit combat before the follow-through.
function UnitMovement.followAttack(state, unit, companion, systems)
	if
		not companion
		or companion.owner ~= unit.owner
		or companion.x == unit.x and companion.y == unit.y
	then
		return
	end
	local cost = Hex.moveCost(
		unit.x,
		unit.y,
		state,
		companion,
		systems,
		companion.x,
		companion.y,
		companion.movesLeft
	)
	assert(cost and cost <= companion.movesLeft, "Unaffordable escort advance")
	local event, notices = Events.move(state, companion), {}
	companion.x, companion.y = unit.x, unit.y
	companion.movesLeft = companion.movesLeft - cost
	companion.actedThisRound = true
	companion.standby, companion.healing, companion.autoExplore, companion.skippedTurn =
		false, false, false, nil
	World.reveal(state, Hex, systems, notices)
	Perception.move(state, companion, Hex, World, Diplomacy)
	if Zone.enter(state, companion, systems, Hex) and Zone.civilian(companion, systems) then
		companion.movesLeft = 0
	end
	companion.moved = companion.movesLeft <= 0
	Events.step(event, state, companion)
	return event, notices
end
return UnitMovement
