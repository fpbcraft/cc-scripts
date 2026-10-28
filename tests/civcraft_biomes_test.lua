-- Hundreds of independent worlds, plus preserved old maps and observer privacy.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local W = dofile("games/civcraft/world.lua")
local H = dofile("games/civcraft/hex.lua")
local B = dofile("games/civcraft/biomes.lua")
local L = dofile("games/civcraft/landmarks.lua")
local S = dofile("games/civcraft/systems.lua")
local function equal(a, b)
	if type(a) ~= "table" then
		return a == b
	end
	if type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if not equal(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end
local sizes = W.sizeOrder
local total, coherent, pairsChecked, aligned, eligibleLines = 0, 0, 0, 0, 0
local counts = {}
local minimumWonders = 10
local minimumOpen = 1
local minStartLand = 100
for index = 1, 600 do
	local size = sizes[(index - 1) % #sizes + 1]
	local kind = W.types[math.floor((index - 1) / #sizes) % #W.types + 1]
	local seed = (index * 7919 + 17) % 1000000
	local world = W.generate(seed, size, index % 3 + 2, kind)
	assert(world.generationVersion == 2 and world.geography)
	local n, open, land = 0, 0, 0
	local landmarks = {}
	for y = 1, world.height do
		for x = 1, world.width do
			local k = W.key(x, y)
			local tile = world.geography[k]
			local terrain = world.tiles[k]
			assert(
				B.names[tile.biome]
					and ({ flat = true, hill = true, mountain = true })[tile.elevation]
			)
			assert(({ none = true, woods = true, dense = true, marsh = true })[tile.feature])
			assert(terrain == B.terrain(tile))
			assert(tile.feature ~= "marsh" or tile.elevation == "flat", "Marsh on steep land")
			assert(
				tile.elevation ~= "mountain" or tile.feature == "none",
				"Vegetation on a mountain"
			)
			local res = world.resources[k]
			if res then
				assert(B.eligible(tile, res), "Illegal " .. res .. " on " .. B.label(tile))
				n = n + 1
				counts[res] = (counts[res] or 0) + 1
			end
			if terrain ~= "water" and terrain ~= "mountain" then
				land = land + 1
				if terrain == "plains" then
					open = open + 1
				end
				assert(H.moveCost(x, y, { world = world }, { owner = 1, kind = "settler" }, S) == 1)
				assert(H.moveCost(x, y, { world = world }, { owner = 1, kind = "warrior" }, S) <= 2)
			end
			for _, adjacent in ipairs(H.neighbours(x, y, { world = world })) do
				pairsChecked = pairsChecked + 1
				if tile.biome == world.geography[W.key(adjacent.x, adjacent.y)].biome then
					coherent = coherent + 1
				end
			end
		end
	end
	assert(
		n == math.floor(world.width * world.height * 0.175 + 0.5),
		"Resource density target not met"
	)
	assert(open / land > 0.5, "Most traversable land must permit one-point movement")
	minimumOpen = math.min(minimumOpen, open / land)
	for _, start in ipairs(world.starts) do
		assert(world.tiles[W.key(start.x, start.y)] == "plains")
		local food, strategic = false, false
		for _, tile in ipairs(H.neighbours(start.x, start.y, { world = world })) do
			local resource = world.resources[W.key(tile.x, tile.y)]
			food = food or resource == "grain"
			strategic = strategic or resource == "iron"
			assert(
				world.tiles[W.key(tile.x, tile.y)] ~= "water"
					and world.tiles[W.key(tile.x, tile.y)] ~= "mountain"
			)
		end
		assert(food and strategic, "Start needs local food and useful strategic access")
		local visited = { [W.key(start.x, start.y)] = true }
		local connected = { { x = start.x, y = start.y } }
		local cursor = 1
		while cursor <= #connected do
			local current = connected[cursor]
			cursor = cursor + 1
			for _, neighbor in ipairs(H.neighbours(current.x, current.y, { world = world })) do
				local tileKey = W.key(neighbor.x, neighbor.y)
				local terrain = world.tiles[tileKey]
				if
					not visited[tileKey]
					and H.distance(start.x, start.y, neighbor.x, neighbor.y) <= 3
					and terrain ~= "water"
					and terrain ~= "mountain"
				then
					visited[tileKey] = true
					connected[#connected + 1] = neighbor
				end
			end
		end
		local landHere = #connected
		minStartLand = math.min(minStartLand, landHere)
		assert(landHere >= 18, "Start has too little usable local land")
	end
	for k, landmark in pairs(world.landmarks) do
		local x, y = k:match("^(%d+):(%d+)$")
		x, y = tonumber(x), tonumber(y)
		assert(
			landmark.natural and L.habitat(world.geography[k], landmark.kind),
			"Wonder violates habitat"
		)
		for _, start in ipairs(world.starts) do
			assert(H.distance(x, y, start.x, start.y) >= world.wonderSpawnBuffer)
		end
		for _, other in ipairs(landmarks) do
			assert(H.distance(x, y, other.x, other.y) >= world.wonderSeparation)
		end
		landmarks[#landmarks + 1] = { x = x, y = y }
	end
	minimumWonders = math.min(minimumWonders, #landmarks)
	assert(#landmarks >= 1, "World has no natural wonders: " .. seed .. " " .. size .. " " .. kind)
	if #landmarks >= 4 then
		eligibleLines = eligibleLines + 1
		local a = landmarks[1]
		local q, r, z = H.toCube(a.x, a.y)
		local allQ, allR, allZ = true, true, true
		for _, point in ipairs(landmarks) do
			local qq, rr, zz = H.toCube(point.x, point.y)
			allQ = allQ and q == qq
			allR = allR and r == rr
			allZ = allZ and z == zz
		end
		if allQ or allR or allZ then
			aligned = aligned + 1
		end
	end
	if index <= 12 then
		math.randomseed(index + 123)
		assert(math.random() >= 0)
		assert(
			equal(world, W.generate(seed, size, index % 3 + 2, kind)),
			"Determinism depends on global random state"
		)
	end
	total = total + 1
end
assert(coherent / pairsChecked > 0.5, "Biomes lack spatial coherence")
assert(aligned == 0, "Wonders form a common row/diagonal")
assert(
	counts.redstone < counts.copper and counts.diamond < counts.redstone,
	"Late minerals lack relative scarcity"
)
-- Old geography and deposits are read through adapters, not overwritten on migration.
local old = {
	phase = "game",
	world = {
		width = 3,
		height = 2,
		tiles = {
			["1:1"] = "forest",
			["2:1"] = "hills",
			["3:1"] = "mountain",
			["1:2"] = "water",
			["2:2"] = "plains",
			["3:2"] = "plains",
		},
		resources = { ["2:1"] = "diamond" },
		seed = 17,
	},
	players = {},
	cities = {},
	units = {},
}
local oldTiles, oldResources = old.world.tiles, old.world.resources
W.migrate(old)
W.migrate(old)
assert(old.world.generationVersion == 1 and not old.world.geography)
assert(
	old.world.tiles == oldTiles
		and old.world.resources == oldResources
		and oldResources["2:1"] == "diamond"
)
local resources = 0
for _ in pairs(oldResources) do
	resources = resources + 1
end
assert(resources == 1)
assert(B.tile(old.world, 1, 1).feature == "woods" and B.tile(old.world, 2, 1).elevation == "hill")
-- New geographic layers follow exactly the same discovery filter as terrain/deposits.
local world = W.generate(9001, "standard", 2, "continents")
local state = {
	phase = "game",
	round = 1,
	world = world,
	players = { { id = 1, visible = { ["2:2"] = true }, explored = { ["3:3"] = true } } },
	cities = {},
	units = {},
}
local snapshot = W.forPlayer(state, 1)
assert(
	snapshot.world.generationVersion == 2
		and snapshot.world.geography["2:2"]
		and snapshot.world.geography["3:3"]
)
assert(not snapshot.world.geography["4:4"] and not snapshot.world.resources["4:4"])
print(
	"CIVCRAFT biomes: "
		.. total
		.. " worlds; minimum open land "
		.. math.floor(minimumOpen * 100)
		.. "%; coherent neighbours "
		.. math.floor(coherent / pairsChecked * 100)
		.. "%; min wonders "
		.. minimumWonders
		.. "; min nearby start land "
		.. minStartLand
		.. "; migrations and snapshots passed."
)
