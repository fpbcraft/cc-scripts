local Hex = dofile("/games/civcraft/hex.lua")
local Routes = dofile("/games/civcraft/ai_routes.lua")
local World = dofile("/games/civcraft/world.lua")
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local Settlement = {}

function Settlement.value(view, player, x, y, unit)
	local key = World.key(x, y)
	local claim = World.territoryCity(view, Hex, x, y)
	if claim and claim.owner ~= player.id then
		return nil
	end
	if
		not view.world.tiles[key]
		or Hex.terrain(x, y, view) == "water"
		or not Hex.passable(x, y, view, unit or { owner = player.id, kind = "settler" })
		or (view.world.landmarks or {})[key]
	then
		return nil
	end
	local home, homes = math.huge, 0
	for _, city in ipairs(view.cities or {}) do
		local distance = Hex.distance(x, y, city.x, city.y)
		if distance < 3 then
			return nil
		end
		if city.owner == player.id then
			homes = homes + 1
			home = math.min(home, distance)
		end
	end
	if homes == 0 then
		home = 0
	end
	if home > 8 then
		return nil
	end
	for _, camp in ipairs(view.spawners or {}) do
		if not camp.cleared and camp.x == x and camp.y == y then
			return nil
		end
	end
	local score = 25 - home * 1.5
	local future = Difficulty.profile(player).futureSites
	if future > 0 then
		for yy = math.max(1, y - 2), math.min(view.world.height, y + 2) do
			for xx = math.max(1, x - 3), math.min(view.world.width, x + 3) do
				if Hex.distance(x, y, xx, yy) == 2 and view.world.tiles[World.key(xx, yy)] then
					local yields = World.yields(view.world, xx, yy)
					score = score + (yields.food + yields.industry + yields.science) * future
				end
			end
		end
	end
	for _, point in ipairs(Hex.neighbours(x, y, view)) do
		local tileKey = World.key(point.x, point.y)
		if view.world.tiles[tileKey] then
			local yields = World.yields(view.world, point.x, point.y)
			score = score + yields.food * 0.8 + yields.industry * 0.8 + yields.science
			local resource = (view.world.resources or {})[tileKey]
			if resource then
				score = score + (((player.stockpile or {})[resource] or 0) < 2 and 4 or 1)
			end
			if (view.world.landmarks or {})[tileKey] then
				score = score + 5
			end
		end
	end
	for _, other in ipairs(view.units or {}) do
		if other.owner ~= player.id and Hex.distance(x, y, other.x, other.y) <= 3 then
			score = score - 15
		end
		local reserved = other.aiSettlement
		if
			other.id ~= (unit or {}).id
			and reserved
			and Hex.distance(x, y, reserved.x, reserved.y) < 3
		then
			return nil
		end
	end
	return score + (Hex.terrain(x, y, view) == "hills" and 2 or 0)
end

function Settlement.select(view, player, unit, systems)
	local routes =
		Routes.from(view, unit, systems, { maxCost = Difficulty.profile(player).routeCost })
	local saved = unit.aiSettlement
	if saved and Settlement.value(view, player, saved.x, saved.y, unit) then
		local path = routes.pathTo(saved.x, saved.y)
		if path then
			return {
				version = 1,
				x = saved.x,
				y = saved.y,
				path = path,
				selectedRound = saved.selectedRound,
			}
		end
	end
	local best, bestScore
	local checked = 0
	for key, distance in pairs(routes.costs) do
		checked = checked + 1
		if checked % 64 == 0 and systems.checkpoint then
			systems.checkpoint()
		end
		local x, y = key:match("^(%d+):(%d+)$")
		x, y = tonumber(x), tonumber(y)
		local value = Settlement.value(view, player, x, y, unit)
		if value then
			local score = value - distance
			if
				not bestScore
				or score > bestScore
				or score == bestScore and (y < best.y or y == best.y and x < best.x)
			then
				bestScore, best =
					score, {
						version = 1,
						x = x,
						y = y,
						path = routes.pathTo(x, y),
						selectedRound = view.round,
					}
			end
		end
	end
	return best
end

function Settlement.available(view, player, city, systems)
	local unit = { id = -1, owner = player.id, kind = "settler", x = city.x, y = city.y }
	return Settlement.select(view, player, unit, systems) ~= nil
end

function Settlement.order(view, player, unit, systems)
	local target = Settlement.select(view, player, unit, systems)
	if target then
		if target.x == unit.x and target.y == unit.y then
			return { action = "found", unitID = unit.id, x = unit.x, y = unit.y }, target
		end
		local step = target.path[2]
		if step then
			return {
				action = "move",
				unitID = unit.id,
				sx = unit.x,
				sy = unit.y,
				x = step.x,
				y = step.y,
			},
				target
		end
	end
	-- Scout the nearest known frontier rather than evaluating unrevealed deposits.
	local best, score
	for _, choice in ipairs(Hex.reachable(view, unit, player.id, systems)) do
		if not choice.attack and view.world.tiles[World.key(choice.x, choice.y)] then
			local frontier = 0
			for _, point in ipairs(Hex.neighbours(choice.x, choice.y, view)) do
				if not view.world.tiles[World.key(point.x, point.y)] then
					frontier = frontier + 1
				end
			end
			local value = frontier * 4 - choice.cost
			if frontier > 0 and (not score or value > score) then
				best, score = choice, value
			end
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
		}
	end
	return nil
end

return Settlement
