-- Pure display helpers for showing canonical horizontal map coordinates in repeated copies.
local Geometry = {}

local function worldFor(state)
	return state and state.world or state
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Geometry.isWrapped(state)
	local world = worldFor(state)
	return world ~= nil and world.wrapX == true
end

-- Return the periodic display copy nearest referenceX. The original world coordinate is
-- retained on bounded maps and by callers; this is only for camera and drawing positions.
function Geometry.nearestX(x, referenceX, state)
	if not Geometry.isWrapped(state) or not finite(x) or not finite(referenceX) then
		return x
	end
	local world = worldFor(state)
	local width = world.width
	if not finite(width) or width <= 0 then
		return x
	end
	local periods = math.floor((referenceX - x) / width + 0.5)
	return x + periods * width
end

return Geometry
