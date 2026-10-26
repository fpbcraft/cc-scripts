local Hex = dofile("/games/civcraft/hex.lua")
local Values = dofile("/games/civcraft/ai_economy_values.lua")
local Research = {}

function Research.ranked(view, player, systems)
	local goal = (player.aiPlan or {}).primary
		or (player.civ == "scholar" and "expedition" or "industrial")
	local dependencies = {}
	local terminal = goal == "expedition" and "enlightenment"
		or goal == "conquest" and "netherite"
		or goal == "diplomatic" and "commerce"
		or "economics"
	Values.dependencies(systems.techs, terminal, player.techs, 48, dependencies)
	if goal == "conquest" then
		Values.dependencies(systems.techs, "tactics", player.techs, 25, dependencies)
	end
	if ((player.aiPlan or {}).campaign or {}).needsSiege then
		Values.dependencies(systems.techs, "engineering", player.techs, 65, dependencies)
	end
	if ((player.aiPlan or {}).needsFleet or 0) > 0 then
		Values.dependencies(systems.techs, "sailing", player.techs, 50, dependencies)
	end
	local contexts, science, coast = {}, 0, false
	for _, city in ipairs(view.cities or {}) do
		if city.owner == player.id then
			contexts[#contexts + 1] = Values.context(view, player, city, systems)
			science = science + contexts[#contexts].yields.science
			coast = coast or systems.coastal(view, city)
		end
	end
	local bestStrength = 2
	for _, unit in ipairs(view.units or {}) do
		if unit.owner == player.id then
			bestStrength = math.max(bestStrength, (systems.units[unit.kind] or {}).strength or 0)
		end
	end
	local result = {}
	for _, id in ipairs(systems.techOrder) do
		if systems.canResearch(player, id) then
			local score = (dependencies[id] or 0) + 1
			for _, building in pairs(systems.buildings) do
				if building.tech == id and (not building.coastal or coast) then
					local value = 0
					for _, context in ipairs(contexts) do
						value = math.max(value, Values.effects(building.effects, context))
					end
					score = score + value * 1.2
				end
			end
			for _, unit in pairs(systems.units) do
				if
					unit.tech == id
					and not unit.hostile
					and (not unit.unique or unit.unique == player.civ)
					and (not unit.naval or coast)
				then
					local improvement = math.max(0, (unit.strength or 0) - bestStrength)
					score = score
						+ improvement
							* ((player.aiPlan or {}).emergency == "defendCapital" and 4 or 0.8)
				end
			end
			for key, material in pairs(view.world and view.world.resources or {}) do
				if (systems.resources[material] or {}).tech == id then
					local x, y = key:match("^(%d+):(%d+)$")
					local city = systems.territoryCity(view, tonumber(x), tonumber(y))
					if city and city.owner == player.id then
						score = score + 3
					end
				end
			end
			local remaining = systems.techCost(id, player)
				- ((player.researchProgress or {})[id] or 0)
			local turns = math.max(1, math.ceil(remaining / math.max(1, science)))
			result[#result + 1] = { id = id, score = score / math.sqrt(turns), turns = turns }
		end
	end
	table.sort(result, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.id < b.id
	end)
	return result
end

return Research
