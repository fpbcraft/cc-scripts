-- Bounded owner-observation policy for persistent machinery choices.
local M = {}
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")

local function copyChoice(choice)
	return { recipe = choice.recipe, priority = choice.priority, enabled = choice.enabled }
end

local function projectChoice(view, owner, cityID, building, patch)
	local projected = {}
	for key, value in pairs(view) do
		projected[key] = value
	end
	projected.cities = {}
	for index, city in ipairs(view.cities or {}) do
		if city.owner == owner then
			local clone = {}
			for key, value in pairs(city) do
				clone[key] = value
			end
			clone.machines = {}
			for id, choice in pairs(city.machines or {}) do
				clone.machines[id] = copyChoice(choice)
			end
			if city.id == cityID and clone.machines[building] then
				for key, value in pairs(patch) do
					clone.machines[building][key] = value
				end
			end
			projected.cities[index] = clone
		else
			projected.cities[index] = city
		end
	end
	return projected
end

local function ownPlayer(view, player)
	local id = type(player) == "table" and player.id or player
	for _, candidate in ipairs(view.players or {}) do
		if candidate.id == id then
			return candidate
		end
	end
end

local function machine(plan, cityID, building)
	for _, record in ipairs((plan or {}).machines or {}) do
		if record.cityID == cityID and record.buildingID == building then
			return record
		end
	end
end

local function hasBrassProject(view, owner, systems)
	for _, city in ipairs(view.cities or {}) do
		local project = city.owner == owner and city.project
		local unit = project and project.kind == "unit" and systems.units[project.id]
		if unit and unit.resource == "brass" then
			return true
		end
	end
	return false
end

local function hasIndustryDemand(city, player, systems)
	local project = city.project
	if type(project) ~= "table" or type(project.kind) ~= "string" then
		return false
	end
	local cost = systems.projectCost(project.kind, project.id, player, city)
	return type(cost) == "number" and cost > (project.progress or 0)
end

local function projectedPlan(view, owner, city, patch, systems)
	local projected = projectChoice(view, owner, city.id, "mixer", patch)
	local forecast = systems.machineForecast(projected, owner)
	return forecast and forecast.plan
end

local function targetRecipe(view, player, city, forecast, systems)
	local current = machine(forecast.plan, city.id, "mixer")
	local brassNeed = hasBrassProject(view, player.id, systems)
		and ((player.stockpile or {}).brass or 0) < 2
	if brassNeed and current and current.active and current.choice.recipe == "brass" then
		return "brass"
	end
	if
		player.techs
		and player.techs.brassworking
		and brassNeed
		and ((forecast.plan.stock or {}).brass or 0) < 2
	then
		local brassPlan =
			projectedPlan(view, player.id, city, { recipe = "brass", enabled = true }, systems)
		local record = brassPlan and machine(brassPlan, city.id, "mixer")
		if record and record.active and brassPlan.stock.brass > forecast.plan.stock.brass then
			return "brass", brassPlan
		end
		if record and record.reason == "no_capacity" then
			local prioritized = projectedPlan(
				view,
				player.id,
				city,
				{ recipe = "brass", priority = 1, enabled = true },
				systems
			)
			local prioritizedRecord = prioritized and machine(prioritized, city.id, "mixer")
			if
				prioritizedRecord
				and prioritizedRecord.active
				and prioritized.stock.brass > forecast.plan.stock.brass
			then
				return "brass", brassPlan, true
			end
		end
	end
	local industryNeed = hasIndustryDemand(city, player, systems)
	if industryNeed and current and current.active and current.choice.recipe == "industry" then
		return "industry"
	end
	if industryNeed then
		local industryPlan =
			projectedPlan(view, player.id, city, { recipe = "industry", enabled = true }, systems)
		local record = industryPlan and machine(industryPlan, city.id, "mixer")
		local before = (forecast.plan.effects[city.id] or {}).industry or 0
		local after = industryPlan and (industryPlan.effects[city.id] or {}).industry or 0
		if record and record.active and after > before then
			return "industry", industryPlan
		end
		if record and record.reason == "no_capacity" then
			local prioritized = projectedPlan(
				view,
				player.id,
				city,
				{ recipe = "industry", priority = 1, enabled = true },
				systems
			)
			local prioritizedRecord = prioritized and machine(prioritized, city.id, "mixer")
			local prioritizedEffects = prioritized and (prioritized.effects[city.id] or {})
			if
				prioritizedRecord
				and prioritizedRecord.active
				and prioritizedEffects.industry > before
			then
				return "industry", industryPlan, true
			end
		end
	end
	return "no_recipe"
end

-- Returns at most one stable, legal persistent action. The caller applies it
-- through the normal action dispatcher and calls again with the next observation.
function M.recommend(view, player, systems)
	if
		type(view) ~= "table"
		or type(systems) ~= "table"
		or type(systems.machineForecast) ~= "function"
	then
		return {}
	end
	local owner = ownPlayer(view, player)
	if not owner then
		return {}
	end
	if view.phase ~= "game" or not Scheduler.canAct(view, owner.id) then
		return {}
	end
	local forecast = systems.machineForecast(view, owner.id)
	if not forecast or not forecast.plan then
		return {}
	end
	local cities = {}
	for _, city in ipairs(view.cities or {}) do
		if city.owner == owner.id and (city.buildings or {}).mixer == true then
			cities[#cities + 1] = city
		end
	end
	table.sort(cities, function(a, b)
		return a.id < b.id
	end)
	for _, city in ipairs(cities) do
		local choice = (city.machines or {}).mixer
		if choice then
			local recipe, candidatePlan, needsPriority =
				targetRecipe(view, owner, city, forecast, systems)
			if needsPriority and choice.priority > 1 then
				return {
					action = "setMachinePriority",
					city = city.id,
					building = "mixer",
					priority = 1,
				}
			end
			if choice.enabled == false and recipe ~= "no_recipe" and candidatePlan then
				return {
					action = "setMachineEnabled",
					city = city.id,
					building = "mixer",
					enabled = true,
				}
			end
			if recipe ~= choice.recipe then
				if recipe == "no_recipe" then
					local current = machine(forecast.plan, city.id, "mixer")
					if current and current.active then
						return {
							action = "selectMachineRecipe",
							city = city.id,
							building = "mixer",
							recipe = recipe,
						}
					end
				elseif candidatePlan then
					return {
						action = "selectMachineRecipe",
						city = city.id,
						building = "mixer",
						recipe = recipe,
					}
				end
			end
		end
	end
	return {}
end

return M
