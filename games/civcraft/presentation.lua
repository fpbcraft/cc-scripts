-- Detach local rendering from mutable host tables, including nested own-player data.
local World = dofile("/games/civcraft/world.lua")
local Presentation = {}

local function detach(value, copies)
	if type(value) ~= "table" then
		return value
	end
	if copies[value] then
		return copies[value]
	end
	local result = {}
	copies[value] = result
	for key, item in pairs(value) do
		result[key] = detach(item, copies)
	end
	return result
end

function Presentation.capture(state, observer)
	local projected = World.forPlayer(state, observer)
	if not projected then
		return { phase = "lobby", round = state.round, players = {}, units = {}, cities = {} }
	end
	return detach(projected, {})
end

return Presentation
