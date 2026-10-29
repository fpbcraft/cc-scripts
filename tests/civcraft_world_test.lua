-- Deterministic worlds, seed differentiation, exploration and hotseat isolation.
local oldDofile = dofile
dofile = function(p)
	if p:sub(1, 16) == "/games/civcraft/" then
		return oldDofile(p:sub(2))
	end
	return oldDofile(p)
end
local W = assert(loadfile("games/civcraft/world.lua"))()
local Biomes = assert(loadfile("games/civcraft/biomes.lua"))()
local H = assert(loadfile("games/civcraft/hex.lua"))()
local S = assert(loadfile("games/civcraft/systems.lua"))()
dofile = oldDofile
local expectedSizes = {
	compact = { 24, 16 },
	standard = { 40, 26 },
	large = { 56, 36 },
	huge = { 72, 46 },
	vast = { 96, 60 },
}
for size, dimensions in pairs(expectedSizes) do
	assert(W.sizes[size][1] == dimensions[1] and W.sizes[size][2] == dimensions[2])
end
local existing = {
	world = {
		width = 28,
		height = 18,
		size = "standard",
		generationVersion = 2,
		tiles = { ["28:18"] = "forest" },
		geography = { ["28:18"] = { biome = "forest", elevation = "flat", feature = "woods" } },
		resources = { ["28:18"] = "iron" },
		seed = 12345,
	},
	cities = {},
	units = {},
	players = {},
}
local savedTiles, savedGeography = existing.world.tiles, existing.world.geography
W.migrate(existing)
assert(existing.world.width == 28 and existing.world.height == 18 and existing.world.seed == 12345)
assert(
	existing.world.tiles == savedTiles
		and existing.world.geography == savedGeography
		and existing.world.resources["28:18"] == "iron",
	"Larger presets must never resize or regenerate saved worlds"
)
assert(existing.world.generationVersion == 2, "Migration preserves saved generation version")
local a = W.generate(12345, "standard", 3)
local b = W.generate(12345, "standard", 3)
local c = W.generate(12346, "standard", 3)
local islands = W.generate(12345, "standard", 3, "archipelago")
local inland = W.generate(12345, "standard", 3, "pangaea")
local differing = 0
for k, v in pairs(islands.tiles) do
	if v ~= inland.tiles[k] then
		differing = differing + 1
	end
end
assert(differing > 30, "Map presets produce distinct geography")
assert(a.width == 40 and a.height == 26)
for y = 1, a.height do
	for x = 1, a.width do
		assert(a.tiles[W.key(x, y)] == b.tiles[W.key(x, y)])
	end
end
local differences = 0
for k, v in pairs(a.tiles) do
	if c.tiles[k] ~= v then
		differences = differences + 1
	end
end
assert(differences > 12, "Different seeds should produce different geography")
for _, size in ipairs({ "compact", "standard", "large" }) do
	local world = W.generate(731, size, 4)
	for _, pos in ipairs(world.starts) do
		assert(W.terrain(world, pos.x, pos.y) == "plains", "Start must be habitable")
	end
end

-- Fixed regression for the former polar-corner starts on the expanded map.
local opening = W.generate(12345, "standard", 4, "continents", { contentRules = "balance4" })
assert(opening.generationVersion == 4)
local function openingTiles(world, start, radius)
	local count, snow = 0, 0
	local reached = { [W.key(start.x, start.y)] = true }
	local queue, index = { start }, 1
	while index <= #queue do
		local current = queue[index]
		index = index + 1
		for _, neighbor in ipairs(H.neighbours(current.x, current.y, { world = world })) do
			local neighborKey = W.key(neighbor.x, neighbor.y)
			local terrain = W.terrain(world, neighbor.x, neighbor.y)
			if
				H.distance(start.x, start.y, neighbor.x, neighbor.y) <= radius
				and terrain ~= "water"
				and terrain ~= "mountain"
				and not reached[neighborKey]
			then
				reached[neighborKey] = true
				queue[#queue + 1] = neighbor
			end
		end
	end
	for y = math.max(1, start.y - radius), math.min(world.height, start.y + radius) do
		for x = math.max(1, start.x - radius), math.min(world.width, start.x + radius) do
			if H.distance(start.x, start.y, x, y) <= radius then
				local tile = Biomes.tile(world, x, y)
				if reached[W.key(x, y)] then
					count = count + 1
				end
				if tile.biome == "snowy_plains" then
					snow = snow + 1
				end
			end
		end
	end
	return count, snow
end
for index, start in ipairs(opening.starts) do
	assert(start.y > 3 and start.y < opening.height - 2, "Start avoids polar map edges")
	local land = openingTiles(opening, start, 4)
	local _, snow = openingTiles(opening, start, 3)
	assert(land >= 30, "Start has a substantial nearby connected land opening")
	assert(snow <= 4, "Start opening is not surrounded by snow")
	for other = 1, index - 1 do
		assert(H.distance(start.x, start.y, opening.starts[other].x, opening.starts[other].y) >= 6)
	end
end
local function sharesPassableLand(world)
	local reached = { [W.key(world.starts[1].x, world.starts[1].y)] = true }
	local queue, queueIndex = { world.starts[1] }, 1
	while queueIndex <= #queue do
		local current = queue[queueIndex]
		queueIndex = queueIndex + 1
		for _, neighbor in ipairs(H.neighbours(current.x, current.y, { world = world })) do
			local tile = W.terrain(world, neighbor.x, neighbor.y)
			local neighborKey = W.key(neighbor.x, neighbor.y)
			if tile ~= "water" and tile ~= "mountain" and not reached[neighborKey] then
				reached[neighborKey] = true
				queue[#queue + 1] = neighbor
			end
		end
	end
	for _, start in ipairs(world.starts) do
		if not reached[W.key(start.x, start.y)] then
			return false
		end
	end
	return true
end
assert(sharesPassableLand(opening), "Continents starts share a connected mainland")
for _, mapType in ipairs({ "archipelago", "highlands" }) do
	local fixture = W.generate(41823, "standard", 4, mapType)
	for index, start in ipairs(fixture.starts) do
		local land = openingTiles(fixture, start, 4)
		local _, snow = openingTiles(fixture, start, 3)
		assert(land >= 30 and snow <= 4, mapType .. " start has a viable regional opening")
		for other = 1, index - 1 do
			assert(
				H.distance(start.x, start.y, fixture.starts[other].x, fixture.starts[other].y) >= 6,
				mapType .. " starts remain separated"
			)
		end
	end
	assert(sharesPassableLand(fixture), mapType .. " starts share a connected mainland")
end
local coastalOpening = W.generate(47531, "compact", 2, "archipelago")
for _, start in ipairs(coastalOpening.starts) do
	for _, neighbor in ipairs(H.neighbours(start.x, start.y, { world = coastalOpening })) do
		local terrain = W.terrain(coastalOpening, neighbor.x, neighbor.y)
		assert(
			terrain ~= "water" and terrain ~= "mountain",
			"Immediate start neighbors stay passable"
		)
	end
end
local fallbackWonder = W.generate(7031, "compact", 4, "archipelago")
local wonderCount = 0
for wonderKey, landmark in pairs(fallbackWonder.landmarks) do
	if landmark.natural then
		wonderCount = wonderCount + 1
		local x, y = wonderKey:match("^(%d+):(%d+)$")
		for _, start in ipairs(fallbackWonder.starts) do
			assert(H.distance(tonumber(x), tonumber(y), start.x, start.y) >= 6)
		end
	end
end
assert(wonderCount >= 1, "Fallback opening preserves a natural wonder outside the start buffer")
local state = {
	world = a,
	players = {
		{ id = 1, explored = {} },
		{ id = 2, explored = {} },
		{ id = 3, explored = {} },
	},
	cities = { { owner = 1, x = 2, y = 2 }, { owner = 2, x = 27, y = 17 } },
	units = {
		{ kind = "scout", owner = 1, x = 3, y = 2 },
		{ kind = "warrior", owner = 2, x = 26, y = 17 },
	},
}
W.reveal(state, H, S)
assert(W.known(state.players[1], 2, 2) == "visible")
assert(W.known(state.players[1], 27, 17) == "hidden", "Hotseat must not reveal opponent territory")
assert(W.known(state.players[2], 27, 17) == "visible")
state.phase = "game"
state.version = 4
state.round = 1
state.players[2].techs = { mining = true }
local view = W.forPlayer(state, 1)
assert(
	#view.cities == 1 and #view.units == 1,
	"Network clients must never receive unseen enemy cities or units"
)
assert(
	not view.world.tiles[W.key(27, 17)] and not view.world.resources[W.key(27, 17)],
	"Unexplored terrain and deposits must not be transmitted"
)
assert(
	not view.players[2].techs and not view.players[2].explored,
	"Opponents' research and exploration remain private"
)
local old = state.players[1].explored[W.key(5, 2)]
state.units[1].x = 12
state.units[1].y = 5
W.reveal(state, H, S)
assert(
	old and W.known(state.players[1], 5, 2) == "explored",
	"Discovery persists when scouts leave an area"
)
local fog = W.known(state.players[3], 5, 2)
assert(fog == "hidden", "Third civilization must have its own map")
print("CIVCRAFT: seeded worlds, guaranteed starts, explorer sight and private discovery passed.")
