-- Privileged diagnostics. Never pass these records to a playing policy.
local Systems = dofile("/games/civcraft/systems.lua")
local Victory = dofile("/games/civcraft/victory.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local Metrics = {}

local function count(records)
	local n = 0
	for _, value in pairs(records or {}) do
		if value then
			n = n + 1
		end
	end
	return n
end

function Metrics.capture(state)
	local result = { round = state.round, phase = state.phase, players = {} }
	for _, player in ipairs(state.players) do
		local row = {
			id = player.id,
			civilization = player.civ,
			gold = player.gold,
			age = Systems.age(player),
			technologies = count(player.techs),
			cities = {},
			units = {},
			population = 0,
			industry = 0,
			science = 0,
			unitCount = 0,
			combatPower = 0,
			idleCities = 0,
			buildings = 0,
			resources = {},
			score = Victory.score(state, player),
			strategy = player.aiPlan and player.aiPlan.primary or "unassigned",
			treasury = Systems.treasury(player, state),
		}
		for resource, amount in pairs(player.stockpile or {}) do
			row.resources[resource] = amount
		end
		for _, city in ipairs(state.cities) do
			if city.owner == player.id then
				local yield = Systems.yields(player, city, state, nil, nil, true)
				local available = {}
				for id in pairs(Systems.buildings) do
					if Systems.canBuild(player, city, id, state) then
						available[#available + 1] = id
					end
				end
				table.sort(available)
				row.population = row.population + city.population
				row.industry = row.industry + yield.industry
				row.science = row.science + yield.science
				row.buildings = row.buildings + count(city.buildings)
				row.idleCities = row.idleCities + (city.project and 0 or 1)
				row.cities[#row.cities + 1] = {
					id = city.id,
					population = city.population,
					yields = yield,
					buildings = count(city.buildings),
					availableBuildings = available,
					projectKind = city.project and city.project.kind,
					projectId = city.project and city.project.id,
				}
			end
		end
		for _, unit in ipairs(state.units) do
			if unit.owner == player.id then
				row.unitCount = row.unitCount + 1
				row.units[unit.kind] = (row.units[unit.kind] or 0) + 1
				if (Systems.units[unit.kind].strength or 0) > 0 then
					row.combatPower = row.combatPower + Combat.power(unit, Systems, false, state)
				end
			end
		end
		row.hasCities = #row.cities > 0
		row.hasSettler = (row.units.settler or 0) > 0
		-- Diagnostic loss of assets is not an invented live-game elimination rule.
		row.noCityOrSettler = not row.hasCities and not row.hasSettler
		result.players[#result.players + 1] = row
	end
	return result
end

return Metrics
