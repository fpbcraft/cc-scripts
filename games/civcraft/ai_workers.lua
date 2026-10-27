local Values = dofile("/games/civcraft/ai_economy_values.lua")
local Workers = {}

function Workers.orders(view, player, city, systems)
	if not view.world then
		return {}
	end
	local context = Values.context(view, player, city, systems)
	local tiles = systems.workable(view, city)
	local selected, food = {}, systems.centerYields(player, city, view).food
	local count, population = 0, city.population or 2
	-- Secure food first; only then optimize a city's assigned specialization.
	while count < population do
		local best, bestScore
		for _, tile in ipairs(tiles) do
			if not selected[tile.key] then
				local score = Values.effects(tile.yield, context)
				if food < population * 2 then
					score = score + tile.yield.food * 30
				end
				if
					not bestScore
					or score > bestScore
					or score == bestScore and tile.key < best.key
				then
					best, bestScore = tile, score
				end
			end
		end
		if not best then
			break
		end
		selected[best.key], count, food = true, count + 1, food + best.yield.food
	end
	local orders = {}
	for _, tile in ipairs(tiles) do
		if city.worked[tile.key] and not selected[tile.key] then
			orders[#orders + 1] =
				{ action = "workTile", cityX = city.x, cityY = city.y, x = tile.x, y = tile.y }
		end
	end
	for _, tile in ipairs(tiles) do
		if selected[tile.key] and not city.worked[tile.key] then
			orders[#orders + 1] =
				{ action = "workTile", cityX = city.x, cityY = city.y, x = tile.x, y = tile.y }
		end
	end
	return orders
end

return Workers
