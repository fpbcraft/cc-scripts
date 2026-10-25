-- Odd-row offset pointy hexes. All geometry/pathfinding uses the same rules.
local Biomes = dofile("/games/civcraft/biomes.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Zone = dofile("/games/civcraft/zone_control.lua")
local MovementBudget = dofile("/games/civcraft/movement_budget.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local H = { width = 12, height = 8 }
local function dims(state)
	local world = state and state.world
	return world and world.width or H.width, world and world.height or H.height
end
function H.inBounds(x, y, state)
	local w, h = dims(state)
	return x >= 1 and x <= w and y >= 1 and y <= h
end
function H.toCube(x, y)
	local q = x - 1 - math.floor((y - 1 - ((y - 1) % 2)) / 2)
	local r = y - 1
	return q, r, -q - r
end
function H.distance(x, y, xx, yy)
	local a, b, c = H.toCube(x, y)
	local d, e, f = H.toCube(xx, yy)
	return math.max(math.abs(a - d), math.abs(b - e), math.abs(c - f))
end
function H.neighbours(x, y, state)
	local dirs = ((y - 1) % 2 == 0)
			and { { -1, -1 }, { 0, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, {
				0,
				1,
			} }
		or { { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }
	local out = {}
	for _, d in ipairs(dirs) do
		local nx, ny = x + d[1], y + d[2]
		if H.inBounds(nx, ny, state) then
			out[#out + 1] = { x = nx, y = ny }
		end
	end
	return out
end
-- Clockwise polygon edges: NE, E, SE, SW, W, NW. Includes map edges.
function H.edgeNeighbours(x, y)
	local shift = (y - 1) % 2
	return {
		{ x = x + shift, y = y - 1 },
		{ x = x + 1, y = y },
		{ x = x + shift, y = y + 1 },
		{ x = x + shift - 1, y = y + 1 },
		{ x = x - 1, y = y },
		{ x = x + shift - 1, y = y - 1 },
	}
end
function H.vertices(x, y, size)
	return {
		{ x = x + size / 2, y = y },
		{ x = x + size, y = y + size / 4 },
		{ x = x + size, y = y + size * 3 / 4 },
		{ x = x + size / 2, y = y + size },
		{ x = x, y = y + size * 3 / 4 },
		{ x = x, y = y + size / 4 },
	}
end
function H.contains(px, py, size, x, y)
	local dx, dy = x - px, y - py
	if dx < 0 or dy < 0 or dx >= size or dy >= size then
		return false
	end
	local inset = dy < size / 4 and size / 2 - 2 * dy
		or dy > size * 3 / 4 and 2 * dy - size * 1.5
		or 0
	return dx >= inset and dx < size - inset
end
function H.tile(x, y, state)
	if state and state.world then
		return Biomes.tile(state.world, x, y)
	end
	return Biomes.legacy(H.terrain(x, y, state))
end
function H.terrain(x, y, state)
	local world = state and state.world
	if world and world.tiles then
		return world.tiles[x .. ":" .. y] or "plains"
	end
	local v = (x * 37 + y * 61 + x * y * 13) % 19
	if v <= 1 then
		return "water"
	end
	if v <= 3 then
		return "mountain"
	end
	if v < 9 then
		return "forest"
	end
	return "plains"
end
local function statsFor(unit, Systems)
	return Systems and Systems.units and Systems.units[unit.kind]
		or ({
			scout = { move = 2, vision = 3, strength = 1 },
			warrior = { move = 1, strength = 2 },
			settler = { move = 3, strength = 0 },
			horseman = { move = 2, strength = 4 },
			spearman = { move = 1, strength = 3 },
		})[unit.kind]
		or { move = 1, strength = 2 }
end
function H.moveCost(x, y, state, unit, Systems, fromX, fromY, remaining)
	local t = H.terrain(x, y, state)
	local stats = statsFor(unit, Systems)
	if stats.naval then
		return t == "water" and 1 or nil
	end
	if t == "water" then
		for _, p in ipairs(state and state.players or {}) do
			if p.id == unit.owner and ((p.techs or {}).navigation or unit.publicEmbarked) then
				return unit.waterMovementRound == state.round and 1 or 2
			end
		end
		return nil
	end
	if t == "mountain" then
		return nil
	end
	if fromX and H.terrain(fromX, fromY, state) == "water" then
		-- Landing spends the remaining allowance; a sea bonus cannot fund a land march.
		return math.max(1, remaining or unit.movesLeft or stats.move or 1)
	end
	local rails = state and state.world and state.world.rails or {}
	if
		fromX
		and rails[x .. ":" .. y]
		and rails[fromX .. ":" .. fromY]
		and Systems
		and Systems.territoryCity
	then
		local a = Systems.territoryCity(state, x, y)
		local b = Systems.territoryCity(state, fromX, fromY)
		if a and b and a.owner == unit.owner and b.owner == unit.owner then
			return 0.25
		end
	end
	if unit.kind == "settler" then
		return 1
	end
	local tile = H.tile(x, y, state)
	local wooded = tile.feature == "woods" or tile.feature == "dense"
	if t == "forest" and stats.forest then
		return 1
	end
	if t == "forest" and (unit.kind == "scout" or unit.kind == "ranger") then
		return 1
	end
	if wooded and t ~= "hills" and Systems and state and state.players then
		for _, p in ipairs(state.players) do
			if p.id == unit.owner and p.civ == "wild" then
				return 1
			end
		end
	end
	if t == "forest" or t == "hills" then
		return 2
	end
	return 1
end
function H.passable(x, y, state, unit, Systems)
	return H.moveCost(x, y, state, unit or { kind = "warrior" }, Systems) ~= nil
end
local occupant = Stacks.at
local function settlement(state, x, y)
	for _, c in ipairs(state.cities or {}) do
		if c.x == x and c.y == y then
			return c
		end
	end
end
function H.reachable(state, unit, owner, Systems)
	local out = {}
	if not unit or unit.owner ~= owner or unit.moved then
		return out
	end
	local budget = unit.movesLeft
	if budget == nil then
		budget = statsFor(unit, Systems).move or 1
	end
	if budget <= 0 then
		return out
	end
	local stats = statsFor(unit, Systems)
	local attackRange = MovementBudget.attackRange(state, unit, stats, H)
	local w, h = dims(state)
	local start = unit.y * w + unit.x
	local distance = { [start] = 0 }
	local fringe = { { x = unit.x, y = unit.y, cost = 0 } }
	local attacks = {}
	local zones = Zone.map(state, unit, Systems, H)
	local stopped = { [start] = Zone.locked(state, unit, Systems) }
	local previous = {}
	local function visible(x, y)
		if stats.hostile or unit.villageGuard then
			return true
		end
		for _, p in ipairs(state.players or {}) do
			if p.id == owner then
				return (p.visible or {})[x .. ":" .. y] == true
			end
		end
		return state.players == nil
	end
	local function route(x, y, last)
		local points = { { x = x, y = y } }
		local index = y * w + x
		if last then
			points[#points + 1] = { x = last.x, y = last.y }
			index = last.y * w + last.x
		end
		while previous[index] do
			local p = previous[index]
			points[#points + 1] = { x = p.x, y = p.y }
			index = p.y * w + p.x
		end
		local ordered = {}
		for i = #points, 1, -1 do
			ordered[#ordered + 1] = points[i]
		end
		return ordered
	end
	while #fringe > 0 do
		if Systems and Systems.checkpoint then
			Systems.checkpoint()
		end
		table.sort(fringe, function(a, b)
			return a.cost < b.cost
		end)
		local cur = table.remove(fringe, 1)
		if cur.cost == distance[cur.y * w + cur.x] then
			for _, nextHex in ipairs(H.neighbours(cur.x, cur.y, state)) do
				local nx, ny = nextHex.x, nextHex.y
				local moveCost =
					H.moveCost(nx, ny, state, unit, Systems, cur.x, cur.y, budget - cur.cost)
				local total = moveCost and cur.cost + moveCost
				local u = occupant(state.units, nx, ny)
				local c = settlement(state, nx, ny)
				if u and not Zone.visible(state, unit, u, Systems) then
					u = nil
				end
				if c and not Zone.visible(state, unit, c, Systems) then
					c = nil
				end
				local enemy = (u and u.owner ~= owner) or (c and c.owner ~= owner)
				if stats.naval and c and c.owner ~= owner then
					moveCost = 1
					total = cur.cost + 1
				end
				if total and total <= budget then
					if enemy then
						if
							visible(nx, ny)
							and Diplomacy.canAttack(
								state,
								owner,
								(c and c.owner) or (u and u.owner)
							)
							and (stats.strength or 0) > 0
							and (not unit.attackedRound or unit.attackedRound ~= state.round)
							and attackRange == 1
							and (stats.naval or not state.world or H.terrain(nx, ny, state) ~= "water")
							and (not u or u.owner ~= owner)
						then
							if not attacks[ny * w + nx] or total < attacks[ny * w + nx].cost then
								attacks[ny * w + nx] = {
									x = nx,
									y = ny,
									cost = total,
									attack = true,
									ranged = attackRange > 1,
									path = route(nx, ny, cur),
								}
							end
						end
					elseif
						not stopped[cur.y * w + cur.x]
						and Stacks.canEnter(state, unit, nx, ny, function(other)
							return Zone.visible(state, unit, other, Systems)
						end)
						and (not c or c.owner == owner)
					then
						local idx = ny * w + nx
						if not distance[idx] or total < distance[idx] then
							local controlled = zones[nx .. ":" .. ny]
							if controlled and Zone.civilian(unit, Systems) then
								total = budget
							end
							distance[idx] = total
							stopped[idx] = controlled
							previous[idx] = { x = cur.x, y = cur.y }
							fringe[#fringe + 1] = { x = nx, y = ny, cost = total }
						end
					end
				end
			end
		end
	end
	for y = 1, h do
		for x = 1, w do
			local idx = y * w + x
			if idx ~= start and distance[idx] then
				out[#out + 1] = {
					x = x,
					y = y,
					cost = distance[idx],
					path = route(x, y),
					zoneStop = stopped[idx] or false,
				}
			end
			if attacks[idx] then
				out[#out + 1] = attacks[idx]
			end
		end
	end
	-- Ranged strikes do not teleport the unit into an enemy tile.
	if
		attackRange > 1
		and (stats.strength or 0) > 0
		and (not unit.attackedRound or unit.attackedRound ~= state.round)
		and (stats.naval or H.terrain(unit.x, unit.y, state) ~= "water")
	then
		local targets = {}
		for _, list in ipairs({ state.units or {}, state.cities or {} }) do
			for _, target in ipairs(list) do
				targets[#targets + 1] = target
			end
		end
		for _, u in ipairs(targets) do
			if
				u.owner ~= owner
				and Diplomacy.canAttack(state, owner, u.owner)
				and H.distance(unit.x, unit.y, u.x, u.y) <= stats.range
				and H.distance(unit.x, unit.y, u.x, u.y) > 0
			then
				local p = state.players or {}
				local visible = false
				for _, player in ipairs(p) do
					if
						player.id == owner
						and player.visible
						and player.visible[u.x .. ":" .. u.y]
					then
						visible = true
					end
				end
				if stats.hostile or unit.villageGuard then
					visible = true
				end
				if visible then
					local idx = u.y * w + u.x
					if not attacks[idx] then
						out[#out + 1] = {
							x = u.x,
							y = u.y,
							cost = budget,
							attack = true,
							ranged = true,
							path = { { x = unit.x, y = unit.y }, { x = u.x, y = u.y } },
						}
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return a.y == b.y and a.x < b.x or a.y < b.y
	end)
	return out
end
return H
