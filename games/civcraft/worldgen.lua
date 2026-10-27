--[[
	Version 2 generation combines smooth climate with sparse deposits.
	Saved geography never depends on renderer or simulation random state.
]]
local Biomes = dofile("/games/civcraft/biomes.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Random = dofile("/games/civcraft/world_random.lua")
local RESOURCE_DENSITY = 0.175
local START_LAND_TARGET = 18
local DIFFICULT_LAND_LIMIT = 0.45

local WorldGen = { version = 2 }
local function key(x, y)
	return x .. ":" .. y
end

local function clamp(value)
	return math.max(0, math.min(1, value))
end

local function climateField(seed, salt, width, height, scale)
	local rng = Random.new(seed, salt)
	local cells = {}
	for y = 0, math.ceil(height / scale) + 1 do
		cells[y] = {}
		for x = 0, math.ceil(width / scale) + 1 do
			cells[y][x] = rng:next()
		end
	end
	return function(x, y)
		x, y = x / scale, y / scale
		local xx, yy = math.floor(x), math.floor(y)
		local fx, fy = x - xx, y - yy
		fx = fx * fx * (3 - 2 * fx)
		fy = fy * fy * (3 - 2 * fy)
		local a = cells[yy][xx] * (1 - fx) + cells[yy][xx + 1] * fx
		local b = cells[yy + 1][xx] * (1 - fx) + cells[yy + 1][xx + 1] * fx
		return a * (1 - fy) + b * fy
	end
end

local function selectBiome(temperature, moisture, height)
	if temperature < 0.24 then
		return "snowy_plains"
	end
	if temperature < 0.40 and moisture > 0.43 then
		return "taiga"
	end
	if temperature > 0.65 and moisture < 0.30 then
		return height > 0.56 and "badlands" or "desert"
	end
	if temperature > 0.61 and moisture > 0.66 then
		return "jungle"
	end
	if moisture > 0.75 and height < 0.52 then
		return "swamp"
	end
	if moisture > 0.55 then
		return "forest"
	end
	if temperature > 0.57 and moisture < 0.5 then
		return "savanna"
	end
	return "plains"
end

local function layers(world, checkpoint)
	local width, height, seed = world.width, world.height, world.seed
	local macro = climateField(seed, 11, width, height, math.max(4, width / 5))
	local detail = climateField(seed, 23, width, height, 3)
	local elevation = climateField(seed, 37, width, height, 5)
	local moisture = climateField(seed, 41, width, height, math.max(4, width / 6))
	local heat = climateField(seed, 53, width, height, 7)
	local vegetation = climateField(seed, 67, width, height, 2)
	local heights, sorted, rises = {}, {}, {}
	local waterShare = ({ continents = 0.32, archipelago = 0.46, pangaea = 0.25, highlands = 0.12 })[world.mapType]
	for y = 1, height do
		for x = 1, width do
			local normalizedX, normalizedY =
				(x - (width + 1) / 2) / (width / 2), (y - (height + 1) / 2) / (height / 2)
			local distance = math.sqrt(normalizedX * normalizedX + normalizedY * normalizedY)
			local edge = world.mapType == "pangaea" and distance * 0.24
				or math.max(0, distance - 0.65) * 0.12
			local height = macro(x, y) * 0.75 + detail(x, y) * 0.25 - edge
			heights[key(x, y)] = height
			sorted[#sorted + 1] = height
		end
	end
	table.sort(sorted)
	local sea = sorted[math.max(1, math.floor(#sorted * waterShare))]
	for y = 1, height do
		for x = 1, width do
			if heights[key(x, y)] > sea then
				rises[#rises + 1] = elevation(x, y) * 0.7 + detail(x, y) * 0.3
			end
		end
	end
	table.sort(rises)
	local hill =
		rises[math.max(1, math.floor(#rises * (world.mapType == "highlands" and 0.65 or 0.77)))]
	local mountain =
		rises[math.max(1, math.floor(#rises * (world.mapType == "highlands" and 0.95 or 0.97)))]
	for y = 1, height do
		if checkpoint then
			checkpoint()
		end
		for x = 1, width do
			local ny = (y - (height + 1) / 2) / (height / 2)
			local temperature = clamp(0.87 - math.abs(ny) * 0.78 + (heat(x, y) - 0.5) * 0.32)
			local wet = moisture(x, y)
			local tile = { biome = "ocean", elevation = "flat", feature = "none" }
			if heights[key(x, y)] > sea then
				tile.biome = selectBiome(temperature, wet, macro(x, y))
				local rise = elevation(x, y) * 0.7 + detail(x, y) * 0.3
				tile.elevation = rise > mountain and "mountain" or rise > hill and "hill" or "flat"
				local vegetationValue = vegetation(x, y)
				if tile.elevation ~= "mountain" then
					if
						(tile.biome == "forest" or tile.biome == "taiga")
						and vegetationValue > 0.40
					then
						tile.feature = "woods"
					elseif tile.biome == "jungle" and vegetationValue > 0.28 then
						tile.feature = "dense"
					elseif
						tile.biome == "swamp"
						and tile.elevation == "flat"
						and vegetationValue > 0.25
					then
						tile.feature = "marsh"
					end
				end
			end
			world.geography[key(x, y)] = tile
			world.tiles[key(x, y)] = Biomes.terrain(tile)
		end
	end
end

local function setTile(world, x, y, tile)
	local tileKey = key(x, y)
	world.geography[tileKey] = tile
	world.tiles[tileKey] = Biomes.terrain(tile)
end

local function starts(world, count)
	local width, height = world.width, world.height
	local rng = Random.new(world.seed, 79)
	local anchors = { { 3, 3 }, { width - 2, height - 2 }, { width - 2, 3 }, { 3, height - 2 } }
	for index = 1, count do
		local a = anchors[index]
		local candidates = {}
		for y = math.max(3, a[2] - 2), math.min(height - 2, a[2] + 2) do
			for x = math.max(3, a[1] - 2), math.min(width - 2, a[1] + 2) do
				local score = 0
				for _, neighbor in ipairs(Hex.neighbours(x, y, { world = world })) do
					local tile = Biomes.tile(world, neighbor.x, neighbor.y)
					local food, industry = Biomes.yields(tile)
					score = score + food + industry - (Biomes.terrain(tile) == "water" and 2 or 0)
				end
				candidates[#candidates + 1] = { x = x, y = y, score = score + rng:next() * 4 }
			end
		end
		table.sort(candidates, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return a.y == b.y and a.x < b.x or a.y < b.y
		end)
		local pos
		for _, candidate in ipairs(candidates) do
			local safe = true
			for _, prior in ipairs(world.starts) do
				if Hex.distance(candidate.x, candidate.y, prior.x, prior.y) < 6 then
					safe = false
				end
			end
			if safe then
				pos = candidate
				break
			end
		end
		-- Compact four-civilization worlds need the full corner separation for
		-- landmarks.
		if height <= 12 then
			pos = { x = a[1], y = a[2] }
		end
		pos = pos or { x = a[1], y = a[2] }
		world.starts[index] = { x = pos.x, y = pos.y }
		-- Repair only the immediate neighbourhood, keeping each surrounding
		-- climate.
		for _, neighbor in ipairs(Hex.neighbours(pos.x, pos.y, { world = world })) do
			local tile = Biomes.tile(world, neighbor.x, neighbor.y)
			if Biomes.terrain(tile) == "water" or tile.elevation == "mountain" then
				setTile(world, neighbor.x, neighbor.y, {
					biome = rng:next() < 0.5 and "plains" or "savanna",
					elevation = "flat",
					feature = "none",
				})
			end
		end
		setTile(world, pos.x, pos.y, { biome = "plains", elevation = "flat", feature = "none" })
		local adjacentX = pos.x + (pos.x < width / 2 and 1 or -1)
		setTile(world, adjacentX, pos.y, { biome = "plains", elevation = "flat", feature = "none" })
		local ironX = Hex.distance(pos.x, pos.y, adjacentX, pos.y + 1) == 1 and adjacentX or pos.x
		setTile(world, ironX, pos.y + 1, { biome = "plains", elevation = "hill", feature = "none" })
		world.resources[key(adjacentX, pos.y)] = "grain"
		world.resources[key(ironX, pos.y + 1)] = "iron"
	end
end

local function repairStart(world, start, rng)
	-- Keep a connected settlement area even when an archipelago seed puts a
	-- corner at sea.
	local reached = { [key(start.x, start.y)] = true }
	local queue = { { x = start.x, y = start.y } }
	local index = 1
	local frontier = {}
	local queued = {}
	local function visit()
		while index <= #queue do
			local candidate = queue[index]
			index = index + 1
			for _, neighbor in ipairs(Hex.neighbours(candidate.x, candidate.y, { world = world })) do
				local tileKey = key(neighbor.x, neighbor.y)
				if
					not reached[tileKey]
					and Hex.distance(start.x, start.y, neighbor.x, neighbor.y) <= 3
				then
					local terrain = world.tiles[tileKey]
					if terrain ~= "water" and terrain ~= "mountain" then
						reached[tileKey] = true
						queue[#queue + 1] = neighbor
					elseif not queued[tileKey] then
						queued[tileKey] = true
						frontier[#frontier + 1] =
							{ x = neighbor.x, y = neighbor.y, rank = rng:next(), near = candidate }
					end
				end
			end
		end
	end
	visit()
	while #queue < START_LAND_TARGET and #frontier > 0 do
		table.sort(frontier, function(a, b)
			local da, db =
				Hex.distance(start.x, start.y, a.x, a.y), Hex.distance(start.x, start.y, b.x, b.y)
			if da ~= db then
				return da < db
			end
			return a.rank < b.rank
		end)
		local candidate = table.remove(frontier, 1)
		local tileKey = key(candidate.x, candidate.y)
		local nearby = Biomes.tile(world, candidate.near.x, candidate.near.y)
		local tile = { biome = nearby.biome, elevation = "flat", feature = nearby.feature }
		if tile.biome == "mushroom" then
			tile.biome = "plains"
			tile.feature = "none"
		end
		setTile(world, candidate.x, candidate.y, tile)
		reached[tileKey] = true
		queue[#queue + 1] = candidate
		visit()
	end
end

local function coasts(world)
	for y = 1, world.height do
		for x = 1, world.width do
			local tile = world.geography[key(x, y)]
			if tile.biome == "ocean" then
				for _, neighbor in ipairs(Hex.neighbours(x, y, { world = world })) do
					if world.tiles[key(neighbor.x, neighbor.y)] ~= "water" then
						tile.biome = "coast"
						break
					end
				end
			end
		end
	end
end
local resources = {
	{ "grain", 28 },
	{ "horses", 10 },
	{ "timber", 24 },
	{ "stone", 20 },
	{ "iron", 16 },
	{ "copper", 12 },
	{ "zinc", 12 },
	{ "redstone", 5 },
	{ "diamond", 2 },
	{ "fish", 25 },
}
local function traversability(world)
	local openable = {}
	local traversable, difficult = 0, 0
	for y = 1, world.height do
		for x = 1, world.width do
			local tile = Biomes.tile(world, x, y)
			local land = Biomes.terrain(tile)
			if land ~= "water" and land ~= "mountain" then
				traversable = traversable + 1
				if land == "forest" or land == "hills" then
					difficult = difficult + 1
				end
				if tile.elevation == "flat" and tile.feature ~= "none" then
					openable[#openable + 1] = { x = x, y = y, tile = tile }
				end
			end
		end
	end
	Random.new(world.seed, 89):shuffle(openable)
	local excess = difficult - math.floor(traversable * DIFFICULT_LAND_LIMIT)
	for i = 1, math.min(#openable, excess) do
		local candidate = openable[i]
		candidate.tile.feature = "none"
		world.tiles[key(candidate.x, candidate.y)] = Biomes.terrain(candidate.tile)
	end
end

local function deposits(world, checkpoint)
	local rng = Random.new(world.seed, 97)
	local candidates = {}
	local count = 0
	for _ in pairs(world.resources) do
		count = count + 1
	end
	for y = 1, world.height do
		if checkpoint then
			checkpoint()
		end
		for x = 1, world.width do
			local tileKey = key(x, y)
			if not world.resources[tileKey] then
				local tile = Biomes.tile(world, x, y)
				local options = {}
				local total = 0
				for _, entry in ipairs(resources) do
					if Biomes.eligible(tile, entry[1]) then
						total = total + entry[2]
						options[#options + 1] = { id = entry[1], limit = total }
					end
				end
				if total > 0 then
					candidates[#candidates + 1] =
						{ key = tileKey, options = options, total = total }
				end
			end
		end
	end
	rng:shuffle(candidates)
	local target = math.floor(world.width * world.height * RESOURCE_DENSITY + 0.5)
	for i = 1, math.min(#candidates, target - count) do
		local candidate = candidates[i]
		local choice = rng:next() * candidate.total
		for _, option in ipairs(candidate.options) do
			if choice < option.limit then
				world.resources[candidate.key] = option.id
				break
			end
		end
	end
end

function WorldGen.generate(seed, size, count, mapType, dimensions, checkpoint)
	local world = {
		width = dimensions[1],
		height = dimensions[2],
		seed = seed,
		size = size,
		mapType = mapType,
		generationVersion = WorldGen.version,
		contentVersion = 1,
		tiles = {},
		geography = {},
		resources = {},
		starts = {},
	}
	layers(world, checkpoint)
	starts(world, count)
	local rng = Random.new(seed, 81)
	for _, start in ipairs(world.starts) do
		repairStart(world, start, rng)
	end
	traversability(world)
	coasts(world)
	Landmarks.generate(world, checkpoint)
	deposits(world, checkpoint)
	return world
end
return WorldGen
