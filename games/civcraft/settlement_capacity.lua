-- One growth constraint alongside food, derived from geography and infrastructure.
local Hex = dofile("/games/civcraft/hex.lua")
local Capacity = {}
function Capacity.details(state, city, buildings)
	local result = { base = 4, water = 0, infrastructure = 0, total = 4, sources = {} }
	if state and state.world then
		for _, point in ipairs(Hex.neighbours(city.x, city.y, state)) do
			if Hex.terrain(point.x, point.y, state) == "water" then
				result.water = 1
				break
			end
		end
	end
	local keys = {}
	for id, built in pairs(city.buildings or {}) do
		if built then
			keys[#keys + 1] = id
		end
	end
	table.sort(keys)
	for _, id in ipairs(keys) do
		local amount = (buildings[id] or {}).capacity or 0
		if amount > 0 then
			result.infrastructure = result.infrastructure + amount
			result.sources[#result.sources + 1] = { id = id, amount = amount }
		end
	end
	result.total = result.base + result.water + result.infrastructure
	return result
end
function Capacity.factor(population, capacity)
	if population <= capacity - 2 then
		return 1
	end
	if population == capacity - 1 then
		return 0.5
	end
	if population < capacity + 2 then
		return 0.25
	end
	return 0.125
end
return Capacity
