local Combat = dofile("/games/civcraft/combat.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Threats = dofile("/games/civcraft/threats.lua")
local World = dofile("/games/civcraft/world.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Tactics = { maxCandidates = 24 }
local function copy(value)
	local result = {}
	for key, item in pairs(value) do
		result[key] = item
	end
	return result
end
local function at(list, x, y)
	for _, entity in ipairs(list) do
		if entity.x == x and entity.y == y then
			return entity
		end
	end
end
local function frontier(view, x, y)
	local count = 0
	for _, point in ipairs(Hex.neighbours(x, y, view)) do
		if not view.world.tiles[World.key(point.x, point.y)] then
			count = count + 1
		end
	end
	return count
end
local function home(view, player, unit)
	local best, distance
	for _, city in ipairs(view.cities) do
		if city.owner == player.id then
			local d = Hex.distance(unit.x, unit.y, city.x, city.y)
			if not distance or d < distance then
				best, distance = city, d
			end
		end
	end
	return best or unit
end
local function support(view, player, unit, x, y, systems)
	if not (systems.units[unit.kind] or {}).healer then
		return 0
	end
	local value = 0
	for _, other in ipairs(view.units) do
		local claim = World.territoryCity(view, Hex, other.x, other.y)
		if
			other.id ~= unit.id
			and other.owner == player.id
			and claim
			and claim.owner == player.id
			and Hex.distance(x, y, other.x, other.y) <= 1
		then
			value = value + math.min(10, 100 - (other.hp or 100)) * 2
		end
	end
	return value
end

function Tactics.ranked(view, player, unit, systems)
	local plan, role = player.aiPlan or {}, unit.aiRole or { name = "mainArmy" }
	local campaign = plan.campaign
		or { kind = "explore", phase = "approach", x = unit.x, y = unit.y }
	local nearest = home(view, player, unit)
	local target = campaign
	local exploring = role.name == "scout"
		or campaign.kind == "explore"
			and role.name ~= "garrison"
			and role.name ~= "healer"
			and role.name ~= "settlerEscort"
	if campaign.phase == "muster" or campaign.phase == "regroup" then
		target = campaign.muster or nearest
	end
	if campaign.kind == "city" and campaign.phase == "approach" and role.name ~= "naval" then
		local index, distance
		for i, point in ipairs(campaign.corridor or {}) do
			local d = Hex.distance(unit.x, unit.y, point.x, point.y)
			if not distance or d < distance then
				index, distance = i, d
			end
		end
		if index then
			target = campaign.corridor[math.min(#campaign.corridor, index + 1)]
		end
	end
	if role.name == "garrison" then
		target = { x = role.homeX or nearest.x, y = role.homeY or nearest.y }
	end
	if role.name == "settlerEscort" then
		for _, other in ipairs(view.units) do
			if other.id == role.escortID then
				target = other
			end
		end
	end
	if role.name == "screening" then
		local closest, distance
		for _, other in ipairs(view.units) do
			local stats = systems.units[other.kind] or {}
			if
				other.owner == player.id
				and other.id ~= unit.id
				and not stats.naval
				and (stats.healer or stats.siege or (stats.range or 1) > 1)
			then
				local d = Hex.distance(unit.x, unit.y, other.x, other.y)
				if not distance or d < distance then
					closest, distance = other, d
				end
			end
		end
		if closest then
			local best, distanceToEnemy
			for _, point in ipairs(Hex.neighbours(closest.x, closest.y, view)) do
				local d = Hex.distance(point.x, point.y, campaign.x, campaign.y)
				if not distanceToEnemy or d < distanceToEnemy then
					best, distanceToEnemy = point, d
				end
			end
			target = best or closest
		end
	end
	if (unit.hp or 100) < 50 then
		target = nearest
	end
	local map = Threats.build(view, player, systems)
	local personality = Personalities.forCivilization(player.civ)
	local candidates = Hex.reachable(view, unit, player.id, systems)
	table.sort(candidates, function(a, b)
		if (a.attack == true) ~= (b.attack == true) then
			return a.attack == true
		end
		local aa = Hex.distance(a.x, a.y, target.x, target.y)
		local bb = Hex.distance(b.x, b.y, target.x, target.y)
		if exploring then
			aa, bb = -frontier(view, a.x, a.y), -frontier(view, b.x, b.y)
		end
		if aa ~= bb then
			return aa < bb
		end
		return a.y == b.y and a.x < b.x or a.y < b.y
	end)
	local owned = World.territory(view, Hex)
	local held = Threats.at(map, unit.x, unit.y, unit)
	local resting = owned[World.key(unit.x, unit.y)] == player.id
	local result = {
		{
			request = {
				action = resting and (unit.hp or 100) < 100 and "heal" or "standby",
				unitID = unit.id,
				x = unit.x,
				y = unit.y,
				value = true,
			},
			score = (resting and (100 - (unit.hp or 100)) * 0.5 or 0)
				+ support(view, player, unit, unit.x, unit.y, systems)
				- held.damage,
		},
	}
	for index = 1, math.min(Tactics.maxCandidates, #candidates) do
		if systems.checkpoint then
			systems.checkpoint()
		end
		local choice = candidates[index]
		local score, forecast = 0, nil
		local position = copy(unit)
		position.x, position.y = choice.x, choice.y
		if choice.attack then
			local defender = at(view.cities, choice.x, choice.y)
				or Stacks.at(view.units, choice.x, choice.y)
			if
				defender
				and not (defender.village and defender.owner == defender.villageOwner)
				and (
					defender.kind == "settler" or Threats.opponent(view, player, defender, systems)
				)
			then
				forecast = Combat.predictOrder(view, unit, choice, systems)
				if forecast then
					local damage =
						math.max(0, (defender.hp or 100) - (forecast.defenderHP or forecast.cityHP))
					local retaliation = (unit.hp or 100) - forecast.attackerHP
					score = damage
						+ (forecast.defenderDied and 70 or 0)
						+ (forecast.captured and 250 or 0)
						+ (forecast.capturedSettler and 120 or 0)
						+ math.max(0, (defender.wallHP or 0) - (forecast.wallHP or 0)) * 0.6
						- retaliation * 1.1
						- (forecast.attackerDied and 220 or 0)
					position.hp = forecast.attackerHP
					if forecast.ranged then
						position.x, position.y = unit.x, unit.y
					elseif
						not forecast.defenderDied
						and not forecast.captured
						and not forecast.capturedSettler
					then
						local point = choice.path[#choice.path - 1]
						position.x, position.y = point.x, point.y
					end
				end
			end
			if not forecast then
				score = -math.huge
			end
		else
			score = (
				Hex.distance(unit.x, unit.y, target.x, target.y)
				- Hex.distance(choice.x, choice.y, target.x, target.y)
			)
					* 8
				- choice.cost
			if role.name == "garrison" then
				score = score * 2
			end
			if exploring then
				score = score + frontier(view, choice.x, choice.y) * 6
			end
			if (unit.hp or 100) < 50 and owned[World.key(choice.x, choice.y)] == player.id then
				score = score + 25
			end
			if role.name == "healer" then
				score = score + support(view, player, unit, choice.x, choice.y, systems)
			end
		end
		local excluded = {}
		if forecast and forecast.defenderDied then
			local defender = at(view.units, choice.x, choice.y)
			if defender and defender.id then
				excluded[defender.id] = true
			end
		end
		local risk = Threats.at(map, position.x, position.y, position, excluded)
		score = score - risk.damage * (1.4 - personality.risk / 100)
		if risk.damage >= (position.hp or 100) then
			score = score - 160
		end
		score = score - Threats.uncertainty(player, position.x, position.y, view.round or 1)
		result[#result + 1] = {
			request = {
				action = "move",
				unitID = unit.id,
				sx = unit.x,
				sy = unit.y,
				x = choice.x,
				y = choice.y,
			},
			score = score,
			forecast = forecast,
			risk = risk,
			x = choice.x,
			y = choice.y,
		}
	end
	table.sort(result, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		local aa, bb = a.request, b.request
		if aa.action ~= bb.action then
			return aa.action < bb.action
		end
		return aa.y == bb.y and aa.x < bb.x or aa.y < bb.y
	end)
	return result
end

function Tactics.cityStrike(view, player, city, systems)
	if (city.wallHP or 0) <= 0 or city.struckRound == view.round then
		return nil
	end
	local best, score
	for _, enemy in ipairs(view.units) do
		if
			Threats.opponent(view, player, enemy, systems)
			and Hex.distance(city.x, city.y, enemy.x, enemy.y) <= 2
		then
			local damage = Combat.damage(
				Combat.cityPower(view, city, systems),
				Combat.power(enemy, systems, true, view)
			)
			local value = math.min(damage, enemy.hp or 100)
				+ (damage >= (enemy.hp or 100) and 70 or 0)
			if not score or value > score then
				best, score = enemy, value
			end
		end
	end
	return best and { action = "cityStrike", x = city.x, y = city.y, tx = best.x, ty = best.y }
end

return Tactics
