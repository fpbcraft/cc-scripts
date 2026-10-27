-- Confirmed danger uses visible combatants only. Remembered uncertainty is AI-only.
local Combat = dofile("/games/civcraft/combat.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local MovementBudget = dofile("/games/civcraft/movement_budget.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Threats = {}
local function copy(value)
	local result = {}
	for key, item in pairs(value) do
		result[key] = item
	end
	return result
end

function Threats.opponent(view, player, entity, systems)
	if entity.owner == player.id or entity.villageGuard then
		return false
	end
	if not Diplomacy.canAttack(view, entity.owner, player.id) then
		return false
	end
	return not entity.kind or ((systems.units[entity.kind] or {}).strength or 0) > 0
end

function Threats.build(state, player, systems)
	local view = state.observerID == player.id and state or World.forPlayer(state, player.id)
	assert(view, "Threat map requires a registered observer")
	local result = { entries = {}, view = view, player = player, systems = systems }
	for _, enemy in ipairs(view.units or {}) do
		if
			(player.visible or {})[World.key(enemy.x, enemy.y)]
			and Threats.opponent(view, player, enemy, systems)
		then
			local stats = systems.units[enemy.kind] or systems.units.warrior
			local simulated = copy(enemy)
			simulated.moved, simulated.attackedRound = false, nil
			local owner
			for _, participant in ipairs(view.players) do
				if participant.id == enemy.owner then
					owner = participant
				end
			end
			local allowance, sea = MovementBudget.nextRound(view, simulated, stats, owner, Hex)
			simulated.movesLeft = allowance
			simulated.waterMovementRound = sea and view.round or nil

			local positions = { { x = enemy.x, y = enemy.y, cost = 0 } }
			for _, move in ipairs(Hex.reachable(view, simulated, enemy.owner, systems)) do
				if not move.attack and move.cost < simulated.movesLeft then
					positions[#positions + 1] = move
				end
			end
			result.entries[#result.entries + 1] = {
				actor = enemy,
				positions = positions,
				range = stats.range or 1,
				moves = simulated.movesLeft,
			}
		end
	end
	for _, city in ipairs(view.cities or {}) do
		if
			city.owner ~= player.id
			and not city.remoteVillage
			and ((city.buildings or {}).walls or (city.buildings or {}).fortress)
			and (city.wallHP or 0) > 0
			and (player.visible or {})[World.key(city.x, city.y)]
		then
			result.entries[#result.entries + 1] = {
				actor = city,
				range = 2,
				city = true,
				positions = { { x = city.x, y = city.y, cost = 0 } },
			}
		end
	end
	return result
end

function Threats.at(map, x, y, unit, excluded)
	local protector = Stacks.at(map.view.units, x, y)
	local target = unit
	if
		unit
		and unit.kind == "settler"
		and protector
		and protector.kind ~= "settler"
		and protector.owner == unit.owner
	then
		target = protector
	end
	local defender = copy(target or { kind = "warrior", owner = map.player.id, hp = 100 })
	defender.x, defender.y = x, y
	defender.standby, defender.healing = false, false
	local defense = Combat.power(defender, map.systems, true, map.view)
	local result = { damage = 0, attackers = 0, estimated = true }
	for _, entry in ipairs(map.entries) do
		if not excluded or not excluded[entry.actor.id] then
			local reaches = false
			for _, point in ipairs(entry.positions) do
				local distance = Hex.distance(x, y, point.x, point.y)
				local stats = map.systems.units[entry.actor.kind] or {}
				local range = entry.city and 2
					or MovementBudget.attackRange(map.view, point, stats, Hex)
				if distance > 0 and distance <= range then
					local cost = entry.city
						or range > 1 and 1
						or Hex.moveCost(
							x,
							y,
							map.view,
							entry.actor,
							map.systems,
							point.x,
							point.y,
							entry.moves - point.cost
						)
					if
						not entry.city
						and range <= 1
						and not stats.naval
						and Hex.terrain(x, y, map.view) == "water"
					then
						cost = nil
					end

					if cost and (entry.city or range > 1 or point.cost + cost <= entry.moves) then
						reaches = true
						break
					end
				end
			end
			if reaches then
				local attack = entry.city and Combat.cityPower(map.view, entry.actor, map.systems)
					or Combat.power(entry.actor, map.systems, false, map.view)
				result.attackers = result.attackers + 1
				result.damage = result.damage + Combat.damage(attack, defense)
			end
		end
	end
	return result
end

function Threats.remember(view, player, systems)
	local plan = player.aiPlan
	if not plan then
		return {}
	end
	local records = {}
	for _, old in ipairs(plan.knownThreats or {}) do
		if (view.round or 1) - old.round <= 4 then
			records[old.id] = old
		end
	end
	for _, enemy in ipairs(view.units) do
		if
			(player.visible or {})[World.key(enemy.x, enemy.y)]
			and Threats.opponent(view, player, enemy, systems)
		then
			records[enemy.id] = {
				id = enemy.id,
				owner = enemy.owner,
				kind = enemy.kind,
				x = enemy.x,
				y = enemy.y,
				round = view.round or 1,
			}
		end
	end
	local list = {}
	for _, record in pairs(records) do
		list[#list + 1] = record
	end
	table.sort(list, function(a, b)
		if a.round ~= b.round then
			return a.round > b.round
		end
		return a.id < b.id
	end)
	while #list > 32 do
		table.remove(list)
	end
	plan.knownThreats = list
	return list
end

function Threats.uncertainty(player, x, y, round)
	local score = 0
	for _, record in ipairs((player.aiPlan or {}).knownThreats or {}) do
		local age = round - record.round
		if age > 0 and age <= 4 and Hex.distance(x, y, record.x, record.y) <= 2 + age then
			score = score + 8 / age
		end
	end
	return score
end

return Threats
