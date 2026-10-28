-- Offline research policy. No rules, resources or authoritative state access.
local Production = dofile("/games/civcraft/ai_production.lua")
local Tactics = dofile("/games/civcraft/ai_tactics.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Policy = {}

local function target(player)
	local plan = player.aiPlan or {}
	if plan.primary ~= "conquest" then
		return nil
	end
	local campaign = plan.campaign or {}
	if campaign.kind == "city" and campaign.owner ~= player.id then
		return campaign
	end
	return plan.__militaryLastEnemyCampaign
end

local function army(view, player, systems, city)
	local siege, melee, closeSiege = 0, 0, 0
	for _, unit in ipairs(view.units or {}) do
		if unit.owner == player.id then
			local stats = systems.units[unit.kind] or {}
			if stats.siege then
				siege = siege + 1
				if city and Hex.distance(unit.x, unit.y, city.x, city.y) <= 3 then
					closeSiege = closeSiege + 1
				end
			elseif
				not stats.naval
				and not stats.engineer
				and not stats.healer
				and (stats.range or 1) == 1
				and (stats.strength or 0) >= (systems.units.swordsman or {}).strength
			then
				melee = melee + 1
			end
		end
	end
	return siege, melee, closeSiege
end

function Policy.install(options)
	local desired = options.siegeCount or 3
	local quorum = options.attackQuorum or 2
	local shotBonus = options.shotBonus or 120
	assert(desired >= 1 and desired <= 4 and quorum >= 1 and quorum <= desired)
	local production = Production.ranked
	Production.ranked = function(view, player, city, systems, canExpand)
		local choices, context = production(view, player, city, systems, canExpand)
		local campaign = target(player)
		if not campaign or (campaign.wallHP or 0) <= 0 then
			return choices, context
		end
		local siege, melee = army(view, player, systems, campaign)
		local committed = siege
		for _, ownCity in ipairs(view.cities or {}) do
			local project = ownCity.project or {}
			if
				ownCity.owner == player.id
				and project.kind == "unit"
				and (systems.units[project.id] or {}).siege
			then
				committed = committed + 1
			end
		end
		if committed >= desired or melee < 2 then
			return choices, context
		end
		local best, bestStrength
		for id, stats in pairs(systems.units) do
			if
				stats.siege
				and systems.canRecruit(player, id, view, Hex, city)
				and ((context.treasury or {}).net or 0) + (player.gold or 0) / 8
					>= (stats.upkeep or 1)
			then
				local strength = stats.strength or 0
				if
					not best
					or strength > bestStrength
					or strength == bestStrength and id < best
				then
					best, bestStrength = id, strength
				end
			end
		end
		if best then
			local maximum, selected = 0, nil
			for _, choice in ipairs(choices) do
				maximum = math.max(maximum, choice.score)
				if choice.kind == "unit" and choice.id == best then
					selected = choice
				end
			end
			if not selected then
				selected = {
					kind = "unit",
					id = best,
					turns = math.max(
						1,
						math.ceil(
							systems.projectCost("unit", best, player)
								/ math.max(1, context.yields.industry)
						)
					),
				}
				choices[#choices + 1] = selected
			end
			selected.score = maximum + 80
			table.sort(choices, function(a, b)
				if a.score ~= b.score then
					return a.score > b.score
				end
				return a.kind .. ":" .. a.id < b.kind .. ":" .. b.id
			end)
		end
		return choices, context
	end
	local tactics = Tactics.ranked
	Tactics.ranked = function(view, player, unit, systems)
		local choices = tactics(view, player, unit, systems)
		local campaign = target(player)
		-- A home-defense campaign need not cancel an already positioned siege
		-- group's local opportunity. Use only currently visible enemy cities.
		if (player.aiPlan or {}).primary == "conquest" then
			local bestDistance
			for _, city in ipairs(view.cities or {}) do
				local distance = Hex.distance(unit.x, unit.y, city.x, city.y)
				if
					not city.village
					and Diplomacy.canAttack(view, player.id, city.owner)
					and distance <= 4
					and (not bestDistance or distance < bestDistance)
				then
					campaign, bestDistance = city, distance
				end
			end
		end
		if not campaign then
			return choices
		end
		local _, _, closeSiege = army(view, player, systems, campaign)
		if not (systems.units[unit.kind] or {}).siege then
			return choices
		end
		for _, choice in ipairs(choices) do
			local forecast = choice.forecast or {}
			if
				(forecast.wallDamage or 0) > 0
				and (closeSiege >= quorum or (forecast.wallHP or 1) <= 0)
			then
				choice.score = choice.score + shotBonus
			end
		end
		table.sort(choices, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			local aReq, bReq = a.request, b.request
			return aReq.action .. ":" .. tostring(aReq.x) .. ":" .. tostring(aReq.y)
				< bReq.action .. ":" .. tostring(bReq.x) .. ":" .. tostring(bReq.y)
		end)
		return choices
	end
end

return Policy
