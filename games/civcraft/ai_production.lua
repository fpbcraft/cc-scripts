local Hex = dofile("/games/civcraft/hex.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Values = dofile("/games/civcraft/ai_economy_values.lua")
local CouncilRules = dofile("/games/civcraft/council_rules.lua")
local Production = {}

local function inventory(view, player, systems, currentCity)
	local result = {
		cities = 0,
		settlers = 0,
		soldiers = 0,
		engineers = 0,
		scouts = 0,
		siege = 0,
		healers = 0,
		naval = 0,
	}
	local function count(id)
		local stats = systems.units[id] or {}
		if stats.naval then
			result.naval = result.naval + 1
			return
		end
		if stats.siege then
			result.siege = result.siege + 1
		end
		if stats.healer then
			result.healers = result.healers + 1
		end
		local key = id == "settler" and "settlers"
			or stats.engineer and "engineers"
			or (id == "scout" or id == "explorer") and "scouts"
			or "soldiers"
		result[key] = result[key] + 1
	end
	for _, city in ipairs(view.cities or {}) do
		if city.owner == player.id then
			result.cities = result.cities + 1
			if city.id ~= currentCity and city.project and city.project.kind == "unit" then
				count(city.project.id)
			end
		end
	end
	for _, unit in ipairs(view.units or {}) do
		if unit.owner == player.id then
			count(unit.kind)
		end
	end
	return result
end

local function unitValue(id, stats, counts, context, player, canExpand)
	if id == "settler" then
		local target = 3
		if (player.aiPlan or {}).personality == "expansionist" and (player.gold or 0) >= 60 then
			target = 4
		end
		return canExpand and math.max(0, target - counts.cities - counts.settlers) * 65 or 0
	end
	if stats.engineer then
		return player.techs.railways
				and counts.cities >= 2
				and counts.engineers < 1
				and (context.specialization == "infrastructure" and 130 or 100)
			or 0
	end
	if id == "scout" or id == "explorer" then
		return counts.scouts < 1 and 35 or 0
	end
	if stats.naval then
		return counts.naval < ((player.aiPlan or {}).needsFleet or 0) and (90 + stats.strength * 3)
			or 0
	end
	local campaign = (player.aiPlan or {}).campaign or {}
	if stats.siege and campaign.needsSiege and counts.siege < 1 then
		return 260 + stats.strength * 3
	end
	if stats.healer and campaign.needsSupport and counts.healers < 1 then
		return 180
	end
	local need = math.max(
		0,
		math.min(
			context.goal == "conquest" and 8 or 6,
			counts.cities + 1 + (context.goal == "conquest" and 2 or 0)
		) - counts.soldiers
	)
	if need == 0 then
		return 0
	end
	return (
		need * 45
		+ (stats.strength + stats.defense) * 3
		+ (context.emergency == "defendCapital" and 150 or 0)
	) * (context.specialization == "military" and 1.3 or 1)
end

function Production.ranked(view, player, city, systems, canExpand)
	local context = Values.context(view, player, city, systems)
	local counts = inventory(view, player, systems, city.id)
	local dependencies = {}
	local target = context.goal == "expedition" and "dragon"
		or context.goal == "diplomatic" and not CouncilRules.eligible(view, player.id) and "councilhall"
		or "bank"
	Values.dependencies(systems.buildings, target, city.buildings, 400, dependencies)
	local result = {}
	local function add(kind, id, value, x, y)
		if
			value <= 0
			or ((player.aiPlan or {}).productionRetryAfter or {})[kind .. ":" .. id]
				and player.aiPlan.productionRetryAfter[kind .. ":" .. id] > (view.round or 1)
		then
			return
		end
		local progress = (city.projectProgress or {})[kind .. ":" .. id] or 0
		if city.project and city.project.kind == kind and city.project.id == id then
			progress = city.project.progress
		end
		local cost = systems.projectCost(kind, id, player)
		local turns =
			math.max(1, math.ceil((cost - progress) / math.max(1, context.yields.industry)))
		result[#result + 1] = {
			kind = kind,
			id = id,
			tileX = x,
			tileY = y,
			score = value / (2 + turns),
			turns = turns,
		}
	end
	for id, building in pairs(systems.buildings) do
		if systems.canBuild(player, city, id, view) then
			local value = Values.effects(building.effects, context) * 12 + (dependencies[id] or 0)
			if
				(building.capacity or 0) > 0
				and context.growthFactor
				and context.growthFactor < 1
				and context.surplus > 0
			then
				value = value + building.capacity * 60 * (1 - context.growthFactor)
			end
			if id == "councilhall" then
				local exists = false
				for _, owned in ipairs(view.cities) do
					exists = exists
						or owned.owner == player.id
							and (owned.buildings or {}).councilhall == true
				end
				value = exists and 0 or value + (context.goal == "diplomatic" and 300 or 60)
			end
			if id == "walls" then
				value = value + (context.emergency == "defendCapital" and 240 or 12)
			end
			if id == "fortress" then
				value = value + (context.emergency == "defendCapital" and 180 or 0)
			end
			if id == "mixer" and player.techs.brassworking then
				value = value + 45
			end
			if id == "station" and counts.cities >= 2 then
				value = value + (context.specialization == "infrastructure" and 100 or 60)
			end
			if id == "shipyard" and ((player.aiPlan or {}).needsFleet or 0) > 0 then
				value = value + 100
			end
			add("building", id, value)
		end
	end
	for id, unit in pairs(systems.units) do
		local reserve = math.max(20, ((unit.upkeep or 1) - context.treasury.net) * 8)
		if
			systems.canRecruit(player, id, view, Hex, city)
			and (context.treasury.net >= (unit.upkeep or 1) or (player.gold or 0) >= reserve)
		then
			add("unit", id, unitValue(id, unit, counts, context, player, canExpand))
		end
	end
	for id, project in pairs(systems.projects or {}) do
		if systems.canProject(player, city, id) then
			local output = systems.projectPreview(player, city, id, view, context.yields)
			if output.active then
				local score = Values.effects(
					{ [project.output] = context.yields.industry / project.divisor },
					context
				)
				result[#result + 1] = { kind = "project", id = id, score = score, turns = 1 }
			end
		end
	end
	for id, wonder in pairs(systems.wonders) do
		for _, tile in ipairs(systems.workable(view, city)) do
			if Landmarks.canPlace(view, city, id, tile.x, tile.y, systems) then
				add(
					"wonder",
					id,
					Values.effects(wonder.effects or wonder, context) * 8,
					tile.x,
					tile.y
				)
				break
			end
		end
	end
	table.sort(result, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.kind .. ":" .. a.id < b.kind .. ":" .. b.id
	end)
	return result, context
end

return Production
