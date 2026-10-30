local Hex = dofile("/games/civcraft/hex.lua")
local Routes = dofile("/games/civcraft/ai_routes.lua")
local Threats = dofile("/games/civcraft/threats.lua")
local World = dofile("/games/civcraft/world.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Campaigns = {}

local function corridor(view, player, city, target, systems)
	local virtual = { id = -1, owner = player.id, kind = "warrior", x = city.x, y = city.y }
	local routes = Routes.from(view, virtual, systems, { ignoreFriendly = true })
	local best, cost
	for _, point in ipairs(Hex.neighbours(target.x, target.y, view)) do
		local distance = routes.costs[World.key(point.x, point.y)]
		if distance and (not cost or distance < cost) then
			best, cost = point, distance
		end
	end
	return best and routes.pathTo(best.x, best.y) or {}
end

function Campaigns.update(view, player, systems)
	local plan = player.aiPlan
	if not plan then
		return {}
	end
	Threats.remember(view, player, systems)
	local cities, units = {}, {}
	for _, city in ipairs(view.cities) do
		if city.owner == player.id then
			cities[#cities + 1] = city
		end
	end
	for _, unit in ipairs(view.units) do
		if unit.owner == player.id then
			units[#units + 1] = unit
		end
	end
	table.sort(cities, function(a, b)
		return a.id < b.id
	end)
	table.sort(units, function(a, b)
		return a.id < b.id
	end)
	local home = cities[1]
	if not home then
		plan.campaign = nil
		return {}
	end
	local roles, guard, settler, strength, hp, army, siege = {}, nil, nil, 0, 0, 0, 0
	for _, unit in ipairs(units) do
		if unit.kind == "settler" then
			settler = settler or unit
		end
	end
	local alive = {}
	local needsScreen = false
	if not settler then
		plan.escortID = nil
	end
	for _, unit in ipairs(units) do
		alive[unit.id] = true
		local stats = systems.units[unit.kind] or {}
		if not stats.naval and (stats.siege or stats.healer or (stats.range or 1) > 1) then
			needsScreen = true
		end
	end
	if not alive[plan.escortID] then
		plan.escortID = nil
	end
	if not alive[plan.screenID] or not needsScreen then
		plan.screenID = nil
	end
	for _, unit in ipairs(units) do
		local stats = systems.units[unit.kind] or {}
		if
			not guard
			and (stats.strength or 0) > 1
			and not stats.naval
			and not stats.engineer
			and not stats.healer
			and (stats.range or 1) == 1
			and unit.id ~= plan.escortID
		then
			guard = unit.id
		end
	end
	if guard == plan.screenID then
		plan.screenID = nil
	end
	for _, unit in ipairs(units) do
		local stats = systems.units[unit.kind] or {}
		local role = unit.kind == "settler" and "settler"
			or stats.builder and "builder"
			or stats.engineer and "engineer"
			or stats.healer and "healer"
			or stats.naval and "naval"
			or (unit.kind == "scout" or unit.kind == "explorer") and "scout"
			or stats.siege and "siege"
			or (stats.range or 1) > 1 and "ranged"
			or "mainArmy"
		if unit.id == guard then
			role = "garrison"
		end
		if role == "mainArmy" and settler and not plan.escortID then
			role, plan.escortID = "settlerEscort", unit.id
		end
		if unit.id == plan.escortID and settler and unit.id ~= guard then
			role = "settlerEscort"
		end
		if role == "mainArmy" and needsScreen and not plan.screenID then
			plan.screenID = unit.id
		end
		if role == "mainArmy" and unit.id == plan.screenID then
			role = "screening"
		end
		roles[unit.id] = {
			version = 1,
			name = role,
			escortID = role == "settlerEscort" and settler.id or nil,
			homeX = role == "garrison" and home.x or nil,
			homeY = role == "garrison" and home.y or nil,
		}
		if
			role == "mainArmy"
			or role == "screening"
			or role == "siege"
			or role == "ranged"
			or role == "healer"
		then
			army, hp, strength = army + 1, hp + (unit.hp or 100), strength + (stats.strength or 0)
			if stats.siege then
				siege = siege + 1
			end
		end
	end
	if not settler then
		plan.escortID = nil
	end
	local previous = plan.campaign
	local coast, enemyShips = false, 0
	for _, city in ipairs(cities) do
		coast = coast or systems.coastal(view, city)
	end
	for _, unit in ipairs(view.units) do
		if
			unit.owner ~= player.id
			and Diplomacy.canAttack(view, player.id, unit.owner)
			and (systems.units[unit.kind] or {}).naval
		then
			enemyShips = enemyShips + 1
		end
	end
	plan.needsFleet = coast
			and math.min(3, enemyShips > 0 and enemyShips + 1 or player.civ == "mariner" and 1 or 0)
		or 0
	local target, bestScore
	for _, city in ipairs(view.cities) do
		if
			city.owner ~= player.id
			and Diplomacy.canAttack(view, player.id, city.owner)
			and not city.village
			and (player.visible or {})[World.key(city.x, city.y)]
		then
			local score = 80
				+ (city.capitalOf and 40 or 0)
				- Hex.distance(home.x, home.y, city.x, city.y, view)
			if previous and previous.targetID == city.id then
				score = score + 25
			end
			if not bestScore or score > bestScore then
				target, bestScore = city, score
			end
		end
	end
	local defend
	for _, city in ipairs(cities) do
		for _, enemy in ipairs(view.units) do
			if
				Threats.opponent(view, player, enemy, systems)
				and Hex.distance(city.x, city.y, enemy.x, enemy.y, view) <= 3
			then
				defend = city
				break
			end
		end
		if defend then
			break
		end
	end
	if
		not target
		and previous
		and previous.kind == "city"
		and Diplomacy.canAttack(view, player.id, previous.owner)
		and (view.round or 1) - previous.seenRound <= 10
	then
		local seen = (player.visible or {})[World.key(previous.x, previous.y)]
		if not seen then
			target = {
				id = previous.targetID,
				owner = previous.owner,
				x = previous.x,
				y = previous.y,
				wallHP = previous.wallHP,
			}
		end
	end
	local kind = defend and "defense" or target and "city" or "explore"
	target = defend or target or home
	if kind == "city" then
		for _, city in ipairs(cities) do
			if
				Hex.distance(city.x, city.y, target.x, target.y, view)
				< Hex.distance(home.x, home.y, target.x, target.y, view)
			then
				home = city
			end
		end
	end
	local same = previous and previous.targetID == target.id and previous.kind == kind
	local phase = kind == "defense" and "defend"
		or army > 0 and hp / army < 55 and "regroup"
		or army < ((plan.personality == "conqueror") and 3 or 2) and "muster"
		or "approach"
	local needsSiege = kind == "city" and (target.wallHP or 0) > 0 and siege == 0
	if needsSiege then
		phase = "muster"
	end
	if kind == "city" and phase == "approach" then
		for _, unit in ipairs(units) do
			if Hex.distance(unit.x, unit.y, target.x, target.y, view) <= 2 then
				phase = "siege"
			end
		end
	end
	local path = kind == "city" and corridor(view, player, home, target, systems) or {}
	local muster = path[math.min(3, #path)] or home
	plan.campaign = {
		version = 1,
		groupID = same and previous.groupID
			or tostring(player.id) .. ":" .. tostring(view.round or 1),
		kind = kind,
		targetID = target.id,
		owner = target.owner,
		x = target.x,
		y = target.y,
		wallHP = target.wallHP or 0,
		phase = phase,
		seenRound = (player.visible or {})[World.key(target.x, target.y)] and (view.round or 1)
			or same and previous.seenRound
			or (view.round or 1),
		muster = { x = muster.x, y = muster.y },
		needsSiege = needsSiege,
		needsSupport = army >= 3 and hp / math.max(1, army) < 80,
		strength = strength,
		corridor = path,
	}
	return roles
end

return Campaigns
