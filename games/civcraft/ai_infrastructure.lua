local Hex = dofile("/games/civcraft/hex.lua")
local Rails = dofile("/games/civcraft/railways.lua")
local Routes = dofile("/games/civcraft/ai_routes.lua")
local World = dofile("/games/civcraft/world.lua")
local Infrastructure = {}

function Infrastructure.plan(view, player, unit, systems)
	local cities, byID = {}, {}
	for _, city in ipairs(view.cities) do
		if city.owner == player.id then
			cities[#cities + 1], byID[city.id] = city, city
		end
	end
	table.sort(cities, function(a, b)
		return a.id < b.id
	end)
	if #cities < 2 then
		return nil
	end
	local network = Rails.network(view, player)
	local owned = World.territory(view, Hex)
	local saved = unit.aiRail
	local pairsToTry = {}
	if saved and byID[saved.fromCityID] and byID[saved.toCityID] then
		pairsToTry[1] = { byID[saved.fromCityID], byID[saved.toCityID] }
	end
	for i = 2, #cities do
		pairsToTry[#pairsToTry + 1] = { cities[1], cities[i] }
	end
	for _, pair in ipairs(pairsToTry) do
		local first, last = pair[1], pair[2]
		local connected = false
		for _, member in ipairs(network[first.id] and network[first.id].cities or {}) do
			if member.id == last.id then
				connected = true
			end
		end
		if not connected then
			local virtual =
				{ id = unit.id, owner = player.id, kind = unit.kind, x = first.x, y = first.y }
			local routes = Routes.from(view, virtual, systems, {
				ignoreFriendly = true,
				allow = function(point)
					local key = World.key(point.x, point.y)
					return owned[key] == player.id and not (view.world.landmarks or {})[key]
				end,
			})
			local path = routes.pathTo(last.x, last.y)
			if path then
				return {
					version = 1,
					fromCityID = first.id,
					toCityID = last.id,
					path = path,
					selectedRound = saved
							and saved.fromCityID == first.id
							and saved.toCityID == last.id
							and saved.selectedRound
						or view.round,
				}
			end
		end
	end
	return nil
end

function Infrastructure.order(view, player, unit, systems)
	if not player.techs.railways then
		return nil
	end
	local plan = Infrastructure.plan(view, player, unit, systems)
	if not plan then
		return nil
	end
	local target
	for _, point in ipairs(plan.path) do
		if not (view.world.rails or {})[World.key(point.x, point.y)] then
			target = point
			break
		end
	end
	if not target then
		return nil, plan
	end
	if Rails.canBuild(view, player, unit, target.x, target.y, systems) then
		return {
			action = "buildRail",
			unitID = unit.id,
			sx = unit.x,
			sy = unit.y,
			x = target.x,
			y = target.y,
		},
			plan
	end
	local routes = Routes.from(view, unit, systems)
	local destination, cost
	local near = Hex.neighbours(target.x, target.y, view)
	near[#near + 1] = target
	for _, point in ipairs(near) do
		local distance = routes.costs[World.key(point.x, point.y)]
		if distance and (not cost or distance < cost) then
			destination, cost = point, distance
		end
	end
	if not destination then
		return nil, plan
	end
	local path = routes.pathTo(destination.x, destination.y)
	local legal = {}
	for _, choice in ipairs(Hex.reachable(view, unit, player.id, systems)) do
		if not choice.attack then
			legal[World.key(choice.x, choice.y)] = choice
		end
	end
	local best
	for _, point in ipairs(path) do
		local choice = legal[World.key(point.x, point.y)]
		if choice then
			best = choice
		end
	end
	if best then
		return {
			action = "move",
			unitID = unit.id,
			sx = unit.x,
			sy = unit.y,
			x = best.x,
			y = best.y,
		},
			plan
	end
	return nil, plan
end

return Infrastructure
