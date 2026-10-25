-- Bounded weighted routes over discovered terrain and observed occupancy only.
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Routes = { maxNodes = 1024 }
local function before(a, b)
	if a.cost ~= b.cost then
		return a.cost < b.cost
	end
	return a.y == b.y and a.x < b.x or a.y < b.y
end
local function push(heap, item)
	heap[#heap + 1] = item
	local i = #heap
	while i > 1 do
		local parent = math.floor(i / 2)
		if not before(item, heap[parent]) then
			break
		end
		heap[i], i = heap[parent], parent
	end
	heap[i] = item
end
local function pop(heap)
	local result, last = heap[1], table.remove(heap)
	if #heap == 0 then
		return result
	end
	local i = 1
	while i * 2 <= #heap do
		local child = i * 2
		if heap[child + 1] and before(heap[child + 1], heap[child]) then
			child = child + 1
		end
		if not before(heap[child], last) then
			break
		end
		heap[i], i = heap[child], child
	end
	heap[i] = last
	return result
end

function Routes.from(view, unit, systems, options)
	options = options or {}
	local costs, previous, blocked = {}, {}, {}
	for _, other in ipairs(view.units or {}) do
		if
			other.id ~= unit.id
			and (other.owner ~= unit.owner or not options.ignoreFriendly)
			and not (options.canEnter and options.canEnter(other.x, other.y))
		then
			blocked[World.key(other.x, other.y)] = true
		end
	end
	for _, city in ipairs(view.cities or {}) do
		if city.owner ~= unit.owner then
			blocked[World.key(city.x, city.y)] = true
		end
	end
	local start = World.key(unit.x, unit.y)
	local heap, visited = {}, 0
	costs[start] = 0
	push(heap, { x = unit.x, y = unit.y, cost = 0 })
	while #heap > 0 and visited < (options.maxNodes or Routes.maxNodes) do
		local current = pop(heap)
		if current.cost == costs[World.key(current.x, current.y)] then
			visited = visited + 1
			if visited % 64 == 0 and systems.checkpoint then
				systems.checkpoint()
			end
			for _, nextPoint in ipairs(Hex.neighbours(current.x, current.y, view)) do
				local key = World.key(nextPoint.x, nextPoint.y)
				if
					(view.world.tiles or {})[key]
					and not blocked[key]
					and (not options.allow or options.allow(nextPoint))
				then
					local step
					if options.step then
						step = options.step(current, nextPoint)
					else
						step = Hex.moveCost(
							nextPoint.x,
							nextPoint.y,
							view,
							unit,
							systems,
							current.x,
							current.y
						)
					end
					local cost = step and current.cost + step
					if
						cost
						and cost <= (options.maxCost or 32)
						and (not costs[key] or cost < costs[key])
					then
						costs[key], previous[key] = cost, { x = current.x, y = current.y }
						push(heap, { x = nextPoint.x, y = nextPoint.y, cost = cost })
					end
				end
			end
		end
	end
	local function pathTo(x, y)
		local key = World.key(x, y)
		if not costs[key] then
			return nil
		end
		local reverse = { { x = x, y = y } }
		while previous[key] do
			local point = previous[key]
			reverse[#reverse + 1] = { x = point.x, y = point.y }
			key = World.key(point.x, point.y)
		end
		local path = {}
		for i = #reverse, 1, -1 do
			path[#path + 1] = reverse[i]
		end
		return path
	end
	return { costs = costs, pathTo = pathTo, visited = visited }
end

return Routes
