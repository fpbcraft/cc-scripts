--[[
	Public tactical ratings are shared by prediction, resolution and snapshots.
	A visible city's rating must not require transmitting its hidden army.
]]
local Hex = dofile("/games/civcraft/hex.lua")
local CombatStrength = {}

function CombatStrength.unit(unit, systems, defending, state)
	if state and state.observerID then
		local rating = unit.publicAttack
		if defending then
			rating = unit.publicDefense
		end
		if rating then
			return rating
		end
	end
	local stats = systems.units[unit.kind] or systems.units.warrior
	local base = stats.strength or 0
	if defending then
		base = stats.defense or 0
	end
	local health = math.max(0, math.min(100, unit.hp or 100))
	local result = 10 + base * 5 + ((unit.level or 1) - 1) * 2 - math.floor((100 - health) / 10)
	if defending then
		local terrain = Hex.terrain(unit.x, unit.y, state)
		for _, player in ipairs(state and state.players or {}) do
			if player.id == unit.owner and player.civ == "highland" and terrain == "hills" then
				result = result + 3
			end
		end
		if terrain == "hills" or terrain == "forest" then
			result = result + 3
		end
		if unit.standby or unit.healing then
			result = result + 3
		end
	end
	return math.max(1, result)
end

function CombatStrength.city(state, city, systems)
	if state.observerID and city.publicDefense then
		return city.publicDefense
	end
	local strongest = 20
	for _, unit in ipairs(state.units or {}) do
		if unit.owner == city.owner then
			strongest = math.max(strongest, CombatStrength.unit(unit, systems, true, state))
		end
	end
	local bonus = 0
	for _, player in ipairs(state.players or {}) do
		if player.id == city.owner and player.civ == "sentinel" then
			bonus = 3
		end
	end
	local buildings = city.buildings or {}
	local walls = buildings.fortress or buildings.walls
	local health = math.max(0, math.min(200, city.hp or 200))
	return math.max(
		1,
		bonus
			+ 10
			+ math.floor(strongest / 2)
			+ (city.population or 2) * 2
			+ (walls and 8 or 0)
			- math.floor((200 - health) / 20)
	)
end

return CombatStrength
