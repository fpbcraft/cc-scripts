--[[
	Version 3 generation combines smooth climate with viable regional starts.
	Saved geography never depends on renderer or simulation random state.
]]
local Biomes = dofile("/games/civcraft/biomes.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Random = dofile("/games/civcraft/world_random.lua")
local RESOURCE_DENSITY = 0.175
local START_LAND_TARGET = 30
local START_SEARCH_RADIUS = 4
local START_COMPONENT_MINIMUM = START_LAND_TARGET * 3
local DIFFICULT_LAND_LIMIT = 0.45

local WorldGen = { version = 3 }
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

local function passable(world, x, y)
	local terrain = world.tiles[key(x, y)]
	return terrain ~= "water" and terrain ~= "mountain"
end

local function landComponents(world, checkpoint)
	local components, membership = {}, {}
	for y = 1, world.height do
		if checkpoint then
			checkpoint()
		end
		for x = 1, world.width do
			local tileKey = key(x, y)
			if passable(world, x, y) and not membership[tileKey] then
				local component = { tiles = {}, size = 0, id = #components + 1 }
				local queue, index = { { x = x, y = y } }, 1
				membership[tileKey] = component
				while index <= #queue do
					if checkpoint and index % 64 == 0 then
						checkpoint()
					end
					local current = queue[index]
					index = index + 1
					component.tiles[#component.tiles + 1] = current
					component.size = component.size + 1
					for _, neighbor in
						ipairs(Hex.neighbours(current.x, current.y, { world = world }))
					do
						local neighborKey = key(neighbor.x, neighbor.y)
						if
							passable(world, neighbor.x, neighbor.y) and not membership[neighborKey]
						then
							membership[neighborKey] = component
							queue[#queue + 1] = neighbor
						end
					end
				end
				components[#components + 1] = component
			end
		end
	end
	return components, membership
end

local function openingScore(world, x, y)
	local food, industry, openLand, cold, radius = 0, 0, 0, 0, START_SEARCH_RADIUS
	local snowWithinOpening = 0
	for yy = math.max(1, y - radius), math.min(world.height, y + radius) do
		for xx = math.max(1, x - radius), math.min(world.width, x + radius) do
			if Hex.distance(x, y, xx, yy) <= radius then
				local tile = Biomes.tile(world, xx, yy)
				if passable(world, xx, yy) then
					local tileFood, tileIndustry = Biomes.yields(tile, world.terrainYieldVersion)
					food, industry = food + tileFood, industry + tileIndustry
					if tile.elevation ~= "mountain" and tile.biome ~= "snowy_plains" then
						openLand = openLand + 1
					end
					if tile.biome == "snowy_plains" or tile.biome == "taiga" then
						cold = cold + 1
					end
					if tile.biome == "snowy_plains" and Hex.distance(x, y, xx, yy) <= 3 then
						snowWithinOpening = snowWithinOpening + 1
					end
				end
			end
		end
	end
	return food + industry * 1.25 + openLand * 0.7 - cold * 1.5, snowWithinOpening
end

local function starts(world, count, checkpoint)
	local width, height = world.width, world.height
	local components = landComponents(world, checkpoint)
	local minimumY = math.max(5, math.floor(height * 0.25))
	local maximumY = math.min(height - 4, math.ceil(height * 0.75))
	local candidates, fallbackCandidates = {}, {}
	local scanned = 0
	for _, component in ipairs(components) do
		-- A viable start belongs to a connected land area large enough to support
		-- a local opening. Tiny islands remain part of the generated archipelago.
		if component.size >= START_LAND_TARGET then
			for _, point in ipairs(component.tiles) do
				scanned = scanned + 1
				if checkpoint and scanned % 64 == 0 then
					checkpoint()
				end
				if
					point.x >= 4
					and point.x <= width - 3
					and point.y >= minimumY
					and point.y <= maximumY
				then
					local score, snow = openingScore(world, point.x, point.y)
					if snow <= 4 then
						local candidate = {
							x = point.x,
							y = point.y,
							component = component,
							score = score + math.min(component.size, width * height * 0.3) * 0.25,
						}
						fallbackCandidates[#fallbackCandidates + 1] = candidate
						if component.size >= START_COMPONENT_MINIMUM then
							candidates[#candidates + 1] = candidate
						end
					end
				end
			end
		end
	end
	-- Prefer one substantial landmass that can fit every player at minimum
	-- spacing; retain the exact fertility-ranked feasible set for placement.
	local mainComponent, mainScore, mainSites
	local sitesByComponent = {}
	for rank, candidate in ipairs(candidates) do
		if checkpoint and rank % 64 == 0 then
			checkpoint()
		end
		local sites = sitesByComponent[candidate.component]
		if not sites then
			sites = {}
			sitesByComponent[candidate.component] = sites
		end
		sites[#sites + 1] = candidate
	end
	local feasibilityScanned = 0
	for component, sites in pairs(sitesByComponent) do
		local selected, score = {}, 0
		for _ = 1, count do
			local bestSite
			for _, candidate in ipairs(sites) do
				feasibilityScanned = feasibilityScanned + 1
				if checkpoint and feasibilityScanned % 64 == 0 then
					checkpoint()
				end
				local spaced = true
				for _, prior in ipairs(selected) do
					if Hex.distance(candidate.x, candidate.y, prior.x, prior.y) < 6 then
						spaced = false
						break
					end
				end
				if
					spaced
					and (
						not bestSite
						or candidate.score > bestSite.score
						or (
							candidate.score == bestSite.score
							and (
								candidate.y < bestSite.y
								or (candidate.y == bestSite.y and candidate.x < bestSite.x)
							)
						)
					)
				then
					bestSite = candidate
				end
			end
			if bestSite then
				selected[#selected + 1] = bestSite
				score = score + bestSite.score
			end
		end
		if #selected >= count then
			local merit = component.size + score / count
			if
				not mainScore
				or merit > mainScore
				or (merit == mainScore and component.id < mainComponent.id)
			then
				mainComponent, mainScore, mainSites = component, merit, selected
			end
		end
	end
	if mainComponent then
		candidates = mainSites
	else
		-- If no existing mainland fits the whole roster, form a compact, shared
		-- start region near the best nonpolar land. The radius-three patches
		-- overlap, joining starts locally without filling ocean corridors elsewhere.
		local anchor, anchorRank
		for rank, candidate in ipairs(fallbackCandidates) do
			if checkpoint and rank % 64 == 0 then
				checkpoint()
			end
			if
				not anchorRank
				or candidate.score > anchorRank
				or (
					candidate.score == anchorRank
					and (
						candidate.y < anchor.y
						or (candidate.y == anchor.y and candidate.x < anchor.x)
					)
				)
			then
				anchor, anchorRank = candidate, candidate.score
			end
		end
		local baseX, baseY =
			anchor and anchor.x or math.floor(width / 2),
			anchor and anchor.y or math.floor(height / 2)
		local firstX = math.max(3, math.min(width - 2 - (count - 1) * 6, baseX - (count - 1) * 3))
		candidates = {}
		local clusterScore = openingScore(world, baseX, baseY)
		for index = 1, count do
			local x, y = firstX + (index - 1) * 6, baseY
			if x > width - 2 then
				x = width - 2
			end
			for patchY = math.max(1, y - 3), math.min(height, y + 3) do
				if checkpoint then
					checkpoint()
				end
				for patchX = math.max(1, x - 3), math.min(width, x + 3) do
					local tile = Biomes.tile(world, patchX, patchY)
					if
						Hex.distance(x, y, patchX, patchY) <= 3
						and (not passable(world, patchX, patchY) or tile.biome == "snowy_plains")
					then
						setTile(world, patchX, patchY, {
							biome = "plains",
							elevation = "flat",
							feature = "none",
						})
					end
				end
			end
			candidates[index] = {
				x = x,
				y = y,
				component = nil,
				score = clusterScore,
			}
		end
	end
	local selectedComponents = {}
	for index = 1, count do
		local best, bestScore
		for rank, candidate in ipairs(candidates) do
			if checkpoint and rank % 128 == 0 then
				checkpoint()
			end
			local distance, safe = math.huge, true
			for _, prior in ipairs(world.starts) do
				local candidateDistance = Hex.distance(candidate.x, candidate.y, prior.x, prior.y)
				distance = math.min(distance, candidateDistance)
				if candidateDistance < 6 then
					safe = false
				end
			end
			if safe then
				local spread = #world.starts == 0 and 0 or math.min(distance, 12)
				local sharedLand = 0
				for _, priorComponent in ipairs(selectedComponents) do
					if priorComponent == candidate.component then
						sharedLand = sharedLand + 1
					end
				end
				local score = candidate.score + spread * 1.5 + sharedLand * 25
				if not bestScore or score > bestScore then
					best, bestScore = candidate, score
				end
			end
		end
		assert(best, "Start placement must provide a bounded common land site set")
		world.starts[index] = { x = best.x, y = best.y }
		selectedComponents[index] = best.component
		setTile(world, best.x, best.y, { biome = "plains", elevation = "flat", feature = "none" })
		local adjacentX = best.x < width / 2 and best.x + 1 or best.x - 1
		setTile(
			world,
			adjacentX,
			best.y,
			{ biome = "plains", elevation = "flat", feature = "none" }
		)
		local ironX = Hex.distance(best.x, best.y, adjacentX, best.y + 1) == 1 and adjacentX
			or best.x
		setTile(
			world,
			ironX,
			best.y + 1,
			{ biome = "plains", elevation = "hill", feature = "none" }
		)
		world.resources[key(adjacentX, best.y)] = "grain"
		world.resources[key(ironX, best.y + 1)] = "iron"
	end
end

local function repairStart(world, start, rng, checkpoint)
	-- Ensure each start has useful connected growth space without building
	-- corridors to unrelated landmasses.
	local reached = { [key(start.x, start.y)] = true }
	local queue = { { x = start.x, y = start.y } }
	local index = 1
	local frontier = {}
	local queued = {}
	local visited = 0
	local function visit()
		while index <= #queue do
			visited = visited + 1
			if checkpoint and visited % 32 == 0 then
				checkpoint()
			end
			local candidate = queue[index]
			index = index + 1
			for _, neighbor in ipairs(Hex.neighbours(candidate.x, candidate.y, { world = world })) do
				local tileKey = key(neighbor.x, neighbor.y)
				if
					not reached[tileKey]
					and Hex.distance(start.x, start.y, neighbor.x, neighbor.y)
						<= START_SEARCH_RADIUS
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
	for y = math.max(1, start.y - 3), math.min(world.height, start.y + 3) do
		if checkpoint then
			checkpoint()
		end
		for x = math.max(1, start.x - 3), math.min(world.width, start.x + 3) do
			if Hex.distance(start.x, start.y, x, y) <= 3 then
				local tile = Biomes.tile(world, x, y)
				if tile.biome == "snowy_plains" then
					setTile(world, x, y, {
						biome = "plains",
						elevation = tile.elevation,
						feature = "none",
					})
				end
			end
		end
	end
	-- Preserve the legacy opening guarantee: every immediate neighbor is
	-- walkable, even if the selected viable site has a local shoreline or peak.
	for _, neighbor in ipairs(Hex.neighbours(start.x, start.y, { world = world })) do
		if not passable(world, neighbor.x, neighbor.y) then
			setTile(world, neighbor.x, neighbor.y, {
				biome = "plains",
				elevation = "flat",
				feature = "none",
			})
		end
	end
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

local function reserveWonderSiteIfNeeded(world, checkpoint)
	local buffer = Landmarks.spawnBuffer(world)
	local best, bestDistance, reserved
	for y = 2, world.height - 1 do
		if checkpoint then
			checkpoint()
		end
		for x = 2, world.width - 1 do
			local nearest = math.huge
			for _, start in ipairs(world.starts) do
				nearest = math.min(nearest, Hex.distance(x, y, start.x, start.y))
			end
			if nearest >= buffer then
				local tile = Biomes.tile(world, x, y)
				for _, kind in ipairs(Landmarks.kinds) do
					if Landmarks.habitat(tile, kind) then
						return
					end
				end
				if passable(world, x, y) and (not bestDistance or nearest > bestDistance) then
					best, bestDistance = { x = x, y = y, tile = tile }, nearest
				end
				if not reserved or nearest > reserved.distance then
					reserved = { x = x, y = y, tile = tile, distance = nearest }
				end
			end
		end
	end
	if not best then
		best = reserved
	end
	assert(best, "Start layout must leave a natural-wonder site outside its buffer")
	local tile = best.tile
	local water = tile.biome == "ocean" or tile.biome == "coast"
	local biome = water and "plains" or tile.biome
	setTile(world, best.x, best.y, {
		biome = biome,
		elevation = "hill",
		feature = water and "none" or tile.feature,
	})
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

function WorldGen.generate(seed, size, count, mapType, dimensions, checkpoint, terrainYieldVersion)
	local world = {
		width = dimensions[1],
		height = dimensions[2],
		seed = seed,
		size = size,
		mapType = mapType,
		generationVersion = WorldGen.version,
		terrainYieldVersion = terrainYieldVersion or "civ6-1",
		contentVersion = 1,
		tiles = {},
		geography = {},
		resources = {},
		starts = {},
	}
	layers(world, checkpoint)
	starts(world, count, checkpoint)
	local rng = Random.new(seed, 81)
	for _, start in ipairs(world.starts) do
		repairStart(world, start, rng, checkpoint)
	end
	traversability(world)
	reserveWonderSiteIfNeeded(world, checkpoint)
	coasts(world)
	Landmarks.generate(world, checkpoint)
	deposits(world, checkpoint)
	return world
end
return WorldGen
