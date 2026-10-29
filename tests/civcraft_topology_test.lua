-- Explicit opt-in cylindrical topology and bounded legacy geometry.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local H = dofile("games/civcraft/hex.lua")
local World = dofile("games/civcraft/world.lua")
local Systems = dofile("games/civcraft/systems.lua")
dofile = native

local function key(x, y)
	return x .. ":" .. y
end

local function bfsDistance(x, y, targetX, targetY, state)
	local queue, cursor = { { x = x, y = y, distance = 0 } }, 1
	local visited = { [key(x, y)] = true }
	while cursor <= #queue do
		local current = queue[cursor]
		cursor = cursor + 1
		if current.x == targetX and current.y == targetY then
			return current.distance
		end
		for _, neighbor in ipairs(H.neighbours(current.x, current.y, state)) do
			local neighborKey = key(neighbor.x, neighbor.y)
			if not visited[neighborKey] then
				visited[neighborKey] = true
				queue[#queue + 1] = {
					x = neighbor.x,
					y = neighbor.y,
					distance = current.distance + 1,
				}
			end
		end
	end
	return math.huge
end

for width = 1, 6 do
	for height = 1, 5 do
		local state = { width = width, height = height, wrapX = true }
		for y = 1, height do
			for x = 1, width do
				local neighbors, seen = H.neighbours(x, y, state), {}
				for _, neighbor in ipairs(neighbors) do
					local neighborKey = key(neighbor.x, neighbor.y)
					assert(neighborKey ~= key(x, y), "A wrapped tile is not its own neighbor")
					assert(not seen[neighborKey], "Narrow cylinders deduplicate neighbors")
					seen[neighborKey] = true
					assert(H.distance(x, y, neighbor.x, neighbor.y, state) == 1)
					local reciprocal = false
					for _, reverse in ipairs(H.neighbours(neighbor.x, neighbor.y, state)) do
						if reverse.x == x and reverse.y == y then
							reciprocal = true
						end
					end
					assert(reciprocal, "Wrapped adjacency is symmetric")
				end
				for targetY = 1, height do
					for targetX = 1, width do
						local distance = H.distance(x, y, targetX, targetY, state)
						assert(distance == bfsDistance(x, y, targetX, targetY, state))
						assert(distance == H.distance(targetX, targetY, x, y, state))
					end
				end
				for radius = 0, 6 do
					local actual = {}
					for _, position in ipairs(H.withinRadius(x, y, radius, state)) do
						actual[key(position.x, position.y)] = true
					end
					for targetY = 1, height do
						for targetX = 1, width do
							local expected = H.distance(x, y, targetX, targetY, state) <= radius
							assert(
								(actual[key(targetX, targetY)] == true) == expected,
								"Radius mismatch "
									.. width
									.. ":"
									.. height
									.. " center="
									.. x
									.. ":"
									.. y
									.. " radius="
									.. radius
									.. " target="
									.. targetX
									.. ":"
									.. targetY
							)
						end
					end
				end
			end
		end
	end
end

local wrapped = { width = 5, height = 4, wrapX = true }
assert(H.canonical(0, 2, wrapped) == 5)
assert(H.canonical(-6, 3, wrapped) == 4)
assert(H.canonical(6, 4, wrapped) == 1)
assert(H.canonical(2, 0, wrapped) == nil and H.canonical(2, 5, wrapped) == nil)
assert(H.canonical(1.5, 2, wrapped) == nil)
assert(not H.inBounds(0, 2, wrapped) and not H.inBounds(6, 2, wrapped))
assert(not H.inBounds(1.5, 2, wrapped) and not H.inBounds(math.huge, 2, wrapped))
assert(not H.inBounds(-math.huge, 2, wrapped) and not H.inBounds(0 / 0, 2, wrapped))
assert(H.canonical(math.huge, 2, wrapped) == nil and H.canonical(0 / 0, 2, wrapped) == nil)
assert(H.distance(0, 2, 5, 2, wrapped) == 0)
assert(H.distance(1, 0, 2, 2, wrapped) == math.huge)
assert(H.distance(1, 1, 5, 1, wrapped) == 1, "Horizontal seam is one hex")
assert(H.distance(1, 1, 5, 2, wrapped) == 1, "Odd-row seam diagonal is adjacent")

local edges = H.edgeNeighbours(1, 2, wrapped)
assert(edges[5].x == 5 and edges[5].y == 2, "West edge points across the horizontal seam")
assert(H.edgeNeighbours(1, 1, wrapped)[1].y == 0, "Vertical world edges stay bounded")
local radius = H.withinRadius(1, 2, 2, { world = wrapped })
local radiusKeys = {}
for _, position in ipairs(radius) do
	local positionKey = key(position.x, position.y)
	assert(not radiusKeys[positionKey], "Wrapped radius contains unique canonical positions")
	radiusKeys[positionKey] = true
	assert(H.distance(1, 2, position.x, position.y, wrapped) <= 2)
end
assert(radiusKeys[key(5, 2)], "Wrapped radius crosses the seam")
local narrowWrapped = { width = 3, height = 4, wrapX = true }
local narrowFinite = { width = 3, height = 4 }
assert(
	#H.withinRadius(1, 1, 2, narrowWrapped) > #H.withinRadius(1, 1, 2, narrowFinite),
	"Wrapped radius includes seam tiles on narrow maps"
)
assert(#H.withinRadius(1, 1, -1, wrapped) == 0, "Negative radius is invalid")
assert(#H.withinRadius(1, 1, math.huge, wrapped) == 0, "Infinite radius is invalid")
local wholeWorld = H.withinRadius(1, 1, 1e100, wrapped)
assert(
	#wholeWorld == wrapped.width * wrapped.height,
	"Large finite radius visits each map cell once"
)

local bounded = { width = 5, height = 4, wrapX = false }
assert(H.canonical(0, 2, bounded) == nil and H.distance(0, 2, 1, 2, bounded) == math.huge)
assert(H.distance(1, 1, 5, 1) == 4, "Calls without state preserve finite-map distance")
assert(#H.edgeNeighbours(40, 20) == 6, "Legacy edge geometry accepts arbitrary map coordinates")

local finiteWorld = World.generate(61273, "compact", 2, "continents")
local wrappedWorld = World.generate(61273, "compact", 2, "continents", { wrapX = true })
local wrappedAgain = World.generate(61273, "compact", 2, "continents", { mapWrapX = true })
assert(finiteWorld.wrapX == false and wrappedWorld.wrapX == true)
assert(wrappedWorld.generationVersion == World.generationVersion)
local wrappedDifferences = 0
for tileKey, terrain in pairs(wrappedWorld.tiles) do
	assert(terrain == wrappedAgain.tiles[tileKey], "Wrapped generation is deterministic")
	if terrain ~= finiteWorld.tiles[tileKey] then
		wrappedDifferences = wrappedDifferences + 1
	end
end
assert(wrappedDifferences > 0, "Opt-in periodic generation changes the world")
for index, start in ipairs(wrappedWorld.starts) do
	for previous = 1, index - 1 do
		local prior = wrappedWorld.starts[previous]
		assert(H.distance(start.x, start.y, prior.x, prior.y, wrappedWorld) >= 6)
	end
end

local savedTiles = { ["1:1"] = "forest" }
local legacy = {
	phase = "game",
	world = { width = 5, height = 4, tiles = savedTiles, generationVersion = 3 },
}
World.migrate(legacy)
assert(legacy.world.wrapX == false and legacy.world.tiles == savedTiles)
assert(legacy.world.generationVersion == 3, "Topology migration does not regenerate old worlds")

local viewState = {
	phase = "game",
	version = 6,
	round = 1,
	world = wrappedWorld,
	players = { { id = 1, explored = {}, visible = {} } },
	cities = {},
	units = {},
}
World.reveal(viewState, H, Systems)
local view = World.forPlayer(viewState, 1)
assert(view.world.wrapX == true and view.world.seed == nil and view.world.starts == nil)
local lobbyView = World.forPlayer({
	phase = "lobby",
	players = { { id = 1 } },
	mapWrapX = true,
}, 1)
assert(lobbyView.mapWrapX == true, "Lobby projection includes only public topology setup")
print(
	"CIVCRAFT topology: odd-row seam geometry, opt-in generation, migration and projection passed."
)
