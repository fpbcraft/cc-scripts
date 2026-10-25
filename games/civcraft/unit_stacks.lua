-- One settler and one protecting unit may share a hex. Unit identity stays explicit.
local Stacks = {}
function Stacks.at(units, x, y, id)
	local civilian
	for _, unit in ipairs(units or {}) do
		if unit.x == x and unit.y == y then
			if id ~= nil then
				if unit.id == id then
					return unit
				end
			elseif unit.kind ~= "settler" then
				return unit
			else
				civilian = civilian or unit
			end
		end
	end
	return id == nil and civilian or nil
end
function Stacks.settler(units, x, y)
	for _, unit in ipairs(units or {}) do
		if unit.kind == "settler" and unit.x == x and unit.y == y then
			return unit
		end
	end
end
function Stacks.canEnter(state, unit, x, y, visible)
	for _, other in ipairs(state.units or {}) do
		if
			other ~= unit
			and not (unit.id and other.id == unit.id)
			and other.x == x
			and other.y == y
			and (other.owner == unit.owner or not visible or visible(other))
		then
			if
				other.owner ~= unit.owner
				or (other.kind == "settler") == (unit.kind == "settler")
			then
				return false
			end
		end
	end
	return true
end
function Stacks.capture(state, settler, owner)
	local previous = settler.owner
	settler.owner = owner
	settler.movesLeft, settler.moved = 0, true
	settler.standby, settler.healing, settler.autoExplore = false, false, false
	settler.skippedTurn, settler.zoneEnteredTurn, settler.waterMovementRound = nil, nil, nil
	settler.aiSettlement, settler.aiRole, settler.aiRail = nil, nil, nil
	settler.movementAllowanceRound, settler.turnMovementAllowance, settler.responseMovementRound =
		nil, nil, nil
	settler.actedThisRound = true
	return previous
end
return Stacks
