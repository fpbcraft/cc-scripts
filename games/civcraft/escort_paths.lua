-- Keep nondominated cost pairs: the cheapest route for one member may exhaust the other.
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Hostility = dofile("/games/civcraft/hostility.lua")
local Movement = dofile("/games/civcraft/movement_budget.lua")
local Paths = {}
function Paths.reachable(state, unit, partner, owner, systems, hex, zone, individual)
	local out, endpoints, attacks = {}, {}, {}
	local stats, otherStats = systems.units[unit.kind], systems.units[partner.kind]
	local budget = unit.movesLeft or stats.move
	local otherBudget = partner.movesLeft or otherStats.move
	local function seen(entity)
		return zone.visible(state, unit, entity, systems)
	end
	local function key(x, y)
		return x .. ":" .. y
	end
	local function path(node, target)
		local reverse = target and { { x = target.x, y = target.y } } or {}
		while node do
			reverse[#reverse + 1] = { x = node.x, y = node.y }
			node = node.previous
		end
		local result = {}
		for index = #reverse, 1, -1 do
			result[#result + 1] = reverse[index]
		end
		return result
	end
	local function better(a, b)
		return not b or a.cost < b.cost or a.cost == b.cost and a.escortCost < b.escortCost
	end
	if budget > 0 and otherBudget > 0 and not unit.moved and not partner.moved then
		local ownZones, otherZones =
			zone.map(state, unit, systems, hex), zone.map(state, partner, systems, hex)
		local start = {
			x = unit.x,
			y = unit.y,
			cost = 0,
			escortCost = 0,
			stopped = zone.locked(state, unit, systems) or zone.locked(state, partner, systems),
		}
		local fringe, labels = { start }, { [key(unit.x, unit.y)] = { start } }
		while #fringe > 0 do
			if systems.checkpoint then
				systems.checkpoint()
			end
			table.sort(fringe, function(a, b)
				if a.cost ~= b.cost then
					return a.cost < b.cost
				end
				if a.escortCost ~= b.escortCost then
					return a.escortCost < b.escortCost
				end
				return a.y == b.y and a.x < b.x or a.y < b.y
			end)
			local node = table.remove(fringe, 1)
			if not node.dominated then
				for _, point in ipairs(hex.neighbours(node.x, node.y, state)) do
					local a = hex.moveCost(
						point.x,
						point.y,
						state,
						unit,
						systems,
						node.x,
						node.y,
						budget - node.cost
					)
					local b = hex.moveCost(
						point.x,
						point.y,
						state,
						partner,
						systems,
						node.x,
						node.y,
						otherBudget - node.escortCost
					)
					local defender = Stacks.at(state.units, point.x, point.y)
					if defender and not seen(defender) then
						defender = nil
					end
					local city
					for _, candidate in ipairs(state.cities or {}) do
						if
							candidate.x == point.x
							and candidate.y == point.y
							and seen(candidate)
						then
							city = candidate
							break
						end
					end
					local enemy = defender and defender.owner ~= owner
						or city and city.owner ~= owner
					if stats.naval and city and city.owner ~= owner then
						a = 1
					end
					local cost, escortCost = a and node.cost + a, b and node.escortCost + b
					if cost and escortCost and cost <= budget and escortCost <= otherBudget then
						local id = key(point.x, point.y)
						if enemy then
							local civilian = Stacks.civilian(state.units, point.x, point.y)
							if
								not Stacks.isCivilian(unit)
								and (stats.strength or 0) > 0
								and Movement.attackRange(state, unit, stats, hex) == 1
								and unit.attackedRound ~= state.round
								and (stats.naval or hex.terrain(point.x, point.y, state) ~= "water")
								and Hostility.canAttack(
									state,
									owner,
									city and city.owner or defender.owner
								)
								and not (civilian and seen(civilian))
							then
								local attack = {
									x = point.x,
									y = point.y,
									cost = cost,
									escortCost = escortCost,
									attack = true,
									ranged = false,
									path = path(node, point),
								}
								if better(attack, attacks[id]) then
									attacks[id] = attack
								end
							end
						elseif
							not node.stopped
							and Stacks.canEnterGroup(state, unit, partner, point.x, point.y, seen)
						then
							local stopped = ownZones[id] or otherZones[id]
							if stopped then
								if zone.civilian(unit, systems) then
									cost = budget
								end
								if zone.civilian(partner, systems) then
									escortCost = otherBudget
								end
							end
							local bucket, dominated = labels[id] or {}, false
							for _, old in ipairs(bucket) do
								if
									not old.dominated
									and old.cost <= cost
									and old.escortCost <= escortCost
								then
									dominated = true
									break
								end
							end
							if not dominated then
								for _, old in ipairs(bucket) do
									if cost <= old.cost and escortCost <= old.escortCost then
										old.dominated = true
									end
								end
								local nextNode = {
									x = point.x,
									y = point.y,
									cost = cost,
									escortCost = escortCost,
									stopped = stopped,
									previous = node,
								}
								bucket[#bucket + 1], labels[id] = nextNode, bucket
								fringe[#fringe + 1] = nextNode
								if better(nextNode, endpoints[id]) then
									endpoints[id] = nextNode
								end
							end
						end
					end
				end
			end
		end
	end
	for y = 1, state.world.height do
		for x = 1, state.world.width do
			local id = key(x, y)
			local node = endpoints[id]
			if node and (x ~= unit.x or y ~= unit.y) then
				out[#out + 1] = {
					x = x,
					y = y,
					cost = node.cost,
					escortCost = node.escortCost,
					path = path(node),
					zoneStop = node.stopped or false,
				}
			end
			if attacks[id] then
				out[#out + 1] = attacks[id]
			end
		end
	end
	if Movement.attackRange(state, unit, stats, hex) > 1 then
		local alone = {}
		for field, value in pairs(unit) do
			alone[field] = value
		end
		alone.escortID = nil
		for _, choice in ipairs(individual(state, alone, owner, systems)) do
			if choice.attack and choice.ranged then
				choice.escortCost = 0
				out[#out + 1] = choice
			end
		end
	end
	return out
end
return Paths
