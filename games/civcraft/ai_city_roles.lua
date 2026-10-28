local Hex = dofile("/games/civcraft/hex.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Specialties = dofile("/games/civcraft/ai_specialties.lua")
local CityRoles = {}

function CityRoles.choose(view, player, systems)
	if Sites.enabled(view) then
		return Specialties.roles(view, player, systems)
	end
	local cities, scores, assigned, result = {}, {}, {}, {}
	for _, city in ipairs(view.cities) do
		if city.owner == player.id then
			cities[#cities + 1] = city
		end
	end
	table.sort(cities, function(a, b)
		return a.id < b.id
	end)
	for _, city in ipairs(cities) do
		local center = systems.centerYields(player, city, view)
		local score = {
			science = center.science,
			industry = center.industry,
			infrastructure = 0,
			military = city.capitalOf == player.id and 100 or (city.population or 2),
		}
		for _, tile in ipairs(systems.workable(view, city)) do
			if view.world.tiles[tile.key] then
				score.science = score.science + tile.yield.science * 2
				score.industry = score.industry + tile.yield.industry
			end
		end
		for _, other in ipairs(cities) do
			score.infrastructure = score.infrastructure
				- Hex.distance(city.x, city.y, other.x, other.y)
		end
		scores[city.id], result[city.id] = score, "commerce"
	end
	local function allocate(role)
		local best
		for _, city in ipairs(cities) do
			if
				not assigned[city.id]
				and (not best or scores[city.id][role] > scores[best.id][role])
			then
				best = city
			end
		end
		if best then
			result[best.id], assigned[best.id] = role, true
		end
	end
	local primary = (player.aiPlan or {}).primary
	allocate(
		primary == "expedition" and "science" or primary == "conquest" and "military" or "industry"
	)
	if #cities >= 3 and player.techs.railways then
		allocate("infrastructure")
	end
	if #cities >= 2 then
		allocate(primary == "expedition" and "industry" or "science")
	end
	if #cities >= 4 and primary ~= "conquest" then
		allocate("military")
	end
	return result
end

return CityRoles
