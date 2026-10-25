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
	local notices = {}
	World.reveal(state, Hex, systems, notices)
	local event = Events.move(state, unit)
	for index = 2, finish do
		local position = path[index]
		assert(
			Hex.distance(unit.x, unit.y, position.x, position.y) == 1,
			"Nonadjacent approved route"
		)
		if Zone.locked(state, unit, systems) then
			completed, reason = false, "Stopped in enemy zone of control"
			break
		end
		local blocked = not Stacks.canEnter(state, unit, position.x, position.y)
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
		if blocked or not cost then
			completed, reason = false, "Route blocked by a discovered obstacle"
			break
		end
		spent = spent + cost
		unit.x, unit.y = position.x, position.y
		unit.actedThisRound = true
		World.reveal(state, Hex, systems, notices)
		Perception.move(state, unit, Hex, World, Diplomacy)
		Events.step(event, state, unit)
		if Zone.enter(state, unit, systems, Hex) then
			if Zone.civilian(unit, systems) then
				spent = math.max(spent, unit.movesLeft or spent)
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
	for _, notice in ipairs(notices) do
		Events.emit(state, notice)
	end
	return spent, completed, reason
end

return UnitMovement
