-- Shared settlement geography rules. Command-specific unit checks stay in Actions.
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Founding = {}

function Founding.canFound(state, owner, x, y, systems, settler)
	for _, city in ipairs(state.cities or {}) do
		if city.x == x and city.y == y then
			return false, "Tile has a city"
		end
	end
	local claim = World.territoryCity(state, Hex, x, y)
	if claim and claim.owner ~= owner then
		return false, "Cannot found in another civilization's territory"
	end
	if ((state.world or {}).landmarks or {})[World.key(x, y)] then
		return false, "Cannot settle on a landmark"
	end
	for _, camp in ipairs(state.spawners or {}) do
		if not camp.cleared and camp.x == x and camp.y == y then
			return false, "Clear the hostile camp first"
		end
	end
	settler = settler or { owner = owner, kind = "settler" }
	if Hex.terrain(x, y, state) == "water" or not Hex.passable(x, y, state, settler, systems) then
		return false, "Unsettleable terrain"
	end
	for _, city in ipairs(state.cities or {}) do
		if Hex.distance(city.x, city.y, x, y, state) < 3 then
			return false, "Cities need 3 hex spacing"
		end
	end
	return true
end

return Founding
