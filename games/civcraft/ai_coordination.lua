-- One friendly follow-up is evaluated on detached, currently observed state.
local Combat = dofile("/games/civcraft/combat.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Coordination = {}
local function copy(value)
	local result = {}
	for key, item in pairs(value) do
		result[key] = item
	end
	return result
end
function Coordination.followup(view, player, unit, order, forecast, position, systems, limit)
	if
		limit <= 0
		or not forecast
		or forecast.attackerDied
		or forecast.defenderDied
		or forecast.captured
		or forecast.capturedSettler
	then
		return 0
	end
	local projected = copy(view)
	projected.units, projected.cities = {}, {}
	local allies = {}
	for _, entity in ipairs(view.units) do
		local simulated = copy(entity)
		if entity.id == unit.id then
			simulated.x, simulated.y, simulated.hp = position.x, position.y, position.hp
			simulated.attackedRound, simulated.movesLeft = view.round, 0
		elseif entity.x == order.x and entity.y == order.y and entity.owner ~= player.id then
			simulated.hp = forecast.defenderHP or entity.hp
		elseif
			entity.owner == player.id
			and (entity.movesLeft or 0) > 0
			and entity.attackedRound ~= view.round
			and not entity.standby
			and ((systems.units[entity.kind] or {}).strength or 0) > 0
		then
			allies[#allies + 1] = simulated
		end
		projected.units[#projected.units + 1] = simulated
	end
	for _, entity in ipairs(view.cities) do
		local simulated = copy(entity)
		if entity.x == order.x and entity.y == order.y and entity.owner ~= player.id then
			simulated.hp, simulated.wallHP =
				forecast.cityHP or entity.hp, forecast.wallHP or entity.wallHP
		end
		projected.cities[#projected.cities + 1] = simulated
	end
	table.sort(allies, function(a, b)
		local aa, bb =
			Hex.distance(a.x, a.y, order.x, order.y), Hex.distance(b.x, b.y, order.x, order.y)
		return aa == bb and a.id < b.id or aa < bb
	end)
	local best = 0
	for index = 1, math.min(limit, #allies) do
		if systems.checkpoint then
			systems.checkpoint()
		end
		local ally = allies[index]
		for _, move in ipairs(Hex.reachable(projected, ally, player.id, systems)) do
			if move.attack and move.x == order.x and move.y == order.y then
				local nextStrike = Combat.predictOrder(projected, ally, move, systems)
				if nextStrike and not nextStrike.attackerDied then
					local value = nextStrike.damage * 0.15 - nextStrike.retaliation * 0.1
					if nextStrike.defenderDied or nextStrike.captured then
						value = value + 40
					end
					best = math.max(best, value)
				end
			end
		end
	end
	return best
end
return Coordination
