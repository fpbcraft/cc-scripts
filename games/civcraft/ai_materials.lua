local Villages = dofile("/games/civcraft/villages.lua")
local CouncilRules = dofile("/games/civcraft/council_rules.lua")
local Materials = {}

function Materials.orders(view, player, systems)
	local targets, cities, market = {}, 0, false
	for _, city in ipairs(view.cities or {}) do
		if city.owner == player.id then
			cities = cities + 1
			market = market or city.buildings.market == true
			if city.buildings.mixer and player.techs.brassworking then
				targets.copper, targets.zinc = 1, 1
			end
			local project = city.project
			local resource = project
				and project.kind == "unit"
				and (systems.units[project.id] or {}).resource
			if resource then
				targets[resource] = math.max(targets[resource] or 0, 2)
			end
		elseif Villages.independent(city) and ((city.influence or {})[player.id] or 0) >= 20 then
			market = true
		end
	end
	if cities >= 2 and player.techs.railways then
		targets.iron = math.max(targets.iron or 0, 4)
	end
	if not player.techs.currency or not market or CouncilRules.embargoed(view, player.id) then
		return {}, targets
	end
	local price = CouncilRules.exchangeCost(view)
	local reserve = math.max(40, -systems.treasury(player, view).net * 6)
	local gold, requests = player.gold or 0, {}
	for _, id in ipairs(systems.resourceOrder) do
		local record = systems.resources[id]
		local have = (player.stockpile or {})[id] or 0
		if
			id ~= "horses"
			and id ~= "saltpeter"
			and (not record.tech or player.techs[record.tech])
		then
			while have < (targets[id] or 0) and gold - price >= reserve and #requests < 2 do
				requests[#requests + 1] = { action = "exchange", resource = id }
				have, gold = have + 1, gold - price
			end
		end
	end
	return requests, targets
end

return Materials
