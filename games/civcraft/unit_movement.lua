--[[
	Walk only an already validated route, revealing each traversed hex in order.
	Presentation consumes the frozen event; it never drives simulation positions.
]]
local Events = dofile("/games/civcraft/events.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Perception = dofile("/games/civcraft/diplomatic_perception.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local UnitMovement = {}

function UnitMovement.walk(state, unit, path, systems, lastPoint)
	local finish = lastPoint or #path
	if finish < 2 then
		return
	end
	local notices = {}
	World.reveal(state, Hex, systems, notices)
	local event = Events.move(state, unit)
	for index = 2, finish do
		local position = path[index]
		assert(
			Hex.distance(unit.x, unit.y, position.x, position.y) == 1,
			"Nonadjacent approved route"
		)
		unit.x, unit.y = position.x, position.y
		unit.actedThisRound = true
		World.reveal(state, Hex, systems, notices)
		Perception.move(state, unit, Hex, World, Diplomacy)
		Events.step(event, state, unit)
	end
	Events.emit(state, event)
	for _, notice in ipairs(notices) do
		Events.emit(state, notice)
	end
end

return UnitMovement
