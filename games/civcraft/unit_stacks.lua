-- One civilian and one protecting unit may share a hex. Unit identity stays explicit.
local Stacks = {}
function Stacks.isCivilian(unit)
	return unit and (unit.kind == "settler" or unit.kind == "builder")
end
function Stacks.civilian(units, x, y)
	for _, unit in ipairs(units or {}) do
		if Stacks.isCivilian(unit) and unit.x == x and unit.y == y then
			return unit
		end
	end
end
function Stacks.at(units, x, y, id)
	local civilian
	for _, unit in ipairs(units or {}) do
		if unit.x == x and unit.y == y then
			if id ~= nil then
				if unit.id == id then
					return unit
				end
			elseif not Stacks.isCivilian(unit) then
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
			if other.owner ~= unit.owner or Stacks.isCivilian(other) == Stacks.isCivilian(unit) then
				return false
			end
		end
	end
	return true
end
function Stacks.byID(state, id)
	if id == nil then
		return
	end
	for _, unit in ipairs(state.units or {}) do
		if unit.id == id then
			return unit
		end
	end
end
function Stacks.partner(state, unit)
	local other = unit.escortID and Stacks.byID(state, unit.escortID)
	if
		other
		and other ~= unit
		and other.escortID == unit.id
		and other.owner == unit.owner
		and other.x == unit.x
		and other.y == unit.y
		and Stacks.isCivilian(other) ~= Stacks.isCivilian(unit)
	then
		return other
	end
end
function Stacks.unlink(state, unit)
	local other = unit.escortID and Stacks.byID(state, unit.escortID)
	unit.moveQueue = nil
	unit.escortID = nil
	if other and other.escortID == unit.id then
		other.moveQueue = nil
		other.escortID = nil
	end
end
function Stacks.canLink(state, unit, other, systems)
	if
		not unit
		or not other
		or unit == other
		or not unit.id
		or not other.id
		or unit.owner ~= other.owner
		or unit.x ~= other.x
		or unit.y ~= other.y
		or Stacks.isCivilian(unit) == Stacks.isCivilian(other)
	then
		return false, "Select an owned civilian and protecting unit on the same hex"
	end
	local guard = Stacks.isCivilian(unit) and other or unit
	local stats = systems.units[guard.kind] or {}
	if
		(stats.strength or 0) <= 0
		or stats.engineer
		or stats.healer
		or stats.support
		or stats.air
	then
		return false, "Escort requires a military land unit or ship"
	end
	if
		unit.escortID and unit.escortID ~= other.id
		or other.escortID and other.escortID ~= unit.id
	then
		return false, "Detach the existing escort first"
	end
	return true
end
function Stacks.link(state, unit, other, systems)
	local ok, reason = Stacks.canLink(state, unit, other, systems)
	if not ok then
		return false, reason
	end
	unit.escortID, other.escortID = other.id, unit.id
	return true
end
function Stacks.migrate(state)
	for _, unit in ipairs(state.units or {}) do
		if unit.escortID and not Stacks.partner(state, unit) then
			Stacks.unlink(state, unit)
		end
	end
end
function Stacks.canEnterGroup(state, unit, partner, x, y, visible)
	if not Stacks.canEnter(state, unit, x, y, visible) then
		return false
	end
	if partner then
		for _, other in ipairs(state.units or {}) do
			if
				other ~= unit
				and other ~= partner
				and other.id ~= unit.id
				and other.id ~= partner.id
				and other.x == x
				and other.y == y
				and (other.owner == unit.owner or not visible or visible(other))
			then
				return false
			end
		end
	end
	return true
end
function Stacks.capture(state, settler, owner)
	local previous = settler.owner
	Stacks.unlink(state, settler)
	settler.owner = owner
	settler.movesLeft, settler.moved = 0, true
	settler.standby, settler.healing, settler.autoExplore = false, false, false
	settler.skippedTurn, settler.zoneEnteredTurn, settler.waterMovementRound = nil, nil, nil
	settler.aiSettlement, settler.aiRole, settler.aiRail = nil, nil, nil
	settler.workQueue, settler.aiWork = nil, nil
	settler.autoWork, settler.autoWorkPaused, settler.autoWorkScanStamp = false, nil, nil
	settler.movementAllowanceRound, settler.turnMovementAllowance, settler.responseMovementRound =
		nil, nil, nil
	settler.actedThisRound = true
	return previous
end
return Stacks
