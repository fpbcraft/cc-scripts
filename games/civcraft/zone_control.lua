-- Control uses only the moving civilization's current observations.
local Hostility = dofile("/games/civcraft/hostility.lua")
local Tasks = dofile("/games/civcraft/turn_tasks.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Zone = {}
local function stats(unit, systems)
	return systems and systems.units and (systems.units[unit.kind] or systems.units.warrior) or {}
end
function Zone.ignores(unit, systems, state)
	local kind = stats(unit, systems)
	local other = state and Stacks.isCivilian(unit) and Stacks.partner(state, unit)
	local guard = other and stats(other, systems) or {}
	return kind.mounted
		or kind.air
		or kind.ignoreZoneControl
		or kind.navalRaider
		or unit.kind == "horseman"
		or guard.mounted
		or guard.ignoreZoneControl
		or guard.navalRaider
		or other and other.kind == "horseman"
end
function Zone.civilian(unit, systems)
	local kind = stats(unit, systems)
	return (kind.strength or 0) <= 0 or kind.engineer or kind.support
end
function Zone.locked(state, unit, systems)
	return not Zone.ignores(unit, systems, state)
		and unit.zoneEnteredTurn == Tasks.stamp(state, unit.owner)
end
function Zone.visible(state, unit, entity, systems)
	if entity.owner == unit.owner or stats(unit, systems).hostile or unit.villageGuard then
		return true
	end
	for _, observer in ipairs(state.players or {}) do
		if observer.id == unit.owner then
			return (observer.visible or {})[entity.x .. ":" .. entity.y] == true
		end
	end
	return state.players == nil
end
function Zone.map(state, unit, systems, hex)
	local result = {}
	if Zone.ignores(unit, systems, state) then
		return result
	end
	local function add(entity, domain)
		if
			entity.owner == unit.owner
			or not Hostility.canAttack(state, unit.owner, entity.owner)
			or not Zone.visible(state, unit, entity, systems)
		then
			return
		end
		for _, point in ipairs(hex.neighbours(entity.x, entity.y, state)) do
			local water = hex.terrain(point.x, point.y, state) == "water"
			if
				(domain == "both" or domain == "water" and water or domain == "land" and not water)
				and hex.passable(point.x, point.y, state, unit, systems)
			then
				result[point.x .. ":" .. point.y] = true
			end
		end
	end
	for _, enemy in ipairs(state.units or {}) do
		local kind = stats(enemy, systems)
		if not kind.air and not kind.navalRaider and (kind.strength or 0) > 0 then
			if kind.naval then
				add(enemy, "water")
			elseif (kind.range or 1) == 1 and not kind.engineer and not kind.support then
				add(enemy, "land")
			end
		end
	end
	for _, city in ipairs(state.cities or {}) do
		add(city, "both")
	end
	return result
end
function Zone.enter(state, unit, systems, hex)
	if Zone.map(state, unit, systems, hex)[unit.x .. ":" .. unit.y] then
		unit.zoneEnteredTurn = Tasks.stamp(state, unit.owner)
		return true
	end
	return false
end
return Zone
