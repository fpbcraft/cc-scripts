-- Advisory scoring over a player's projected, explored world view only.
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Founding = dofile("/games/civcraft/founding.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local Content = dofile("/games/civcraft/content.lua")
local Capacity = dofile("/games/civcraft/settlement_capacity.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Suggestions = {}
local MAX_RESULTS = 256
Suggestions.minimumCityDistance = 4
Suggestions.minimumRecommendationDistance = 4

local function known(view, x, y)
	local key = World.key(x, y)
	return (view.world.tiles or {})[key] ~= nil
end

local function capacityFor(view, x, y, buildings)
	if not ContentRules.hasDevelopment(view) then
		return {
			active = false,
			base = 0,
			waterBonus = 0,
			infrastructure = 0,
			observedMinimum = 0,
			sources = {},
		}
	end
	local observed = {
		world = {
			width = view.world.width,
			height = view.world.height,
			wrapX = view.world.wrapX == true,
			tiles = {},
		},
	}
	for _, point in ipairs(Hex.neighbours(x, y, view)) do
		local key = World.key(point.x, point.y)
		if known(view, point.x, point.y) then
			observed.world.tiles[key] = view.world.tiles[key]
		end
	end
	local details = Capacity.details(observed, { x = x, y = y, buildings = {} }, buildings)
	return {
		active = true,
		base = details.base,
		waterBonus = details.water,
		infrastructure = details.infrastructure,
		observedMinimum = details.total,
		sources = details.sources,
	}
end

local function cityCenter(view, x, y)
	for _, city in ipairs(view.cities or {}) do
		if city.x == x and city.y == y then
			return true
		end
	end
	return false
end

local function futureSpecialties(view, player, x, y)
	local result, foundKind = {}, {}
	if not Sites.enabled(view) then
		return result
	end
	for _, point in ipairs(Hex.withinRadius(x, y, 3, view)) do
		local distance = Hex.distance(x, y, point.x, point.y, view)
		local key = World.key(point.x, point.y)
		if
			distance > 0
			and known(view, point.x, point.y)
			and not cityCenter(view, point.x, point.y)
			and not (view.world.landmarks or {})[key]
			and not (view.world.improvements or {})[key]
			and not Sites.at(view, point.x, point.y)
		then
			local tile = Biomes.tile(view.world, point.x, point.y)
			if tile.elevation ~= "mountain" and tile.biome ~= "coast" and tile.biome ~= "ocean" then
				for _, kind in ipairs(Sites.order) do
					local bonus = Sites.bonus(view, player, kind, point.x, point.y)
					if bonus > 0 and not foundKind[kind] then
						local definition = Sites.definitions[kind]
						foundKind[kind] = true
						result[#result + 1] = {
							kind = kind,
							name = definition.name,
							output = definition.output,
							tech = definition.tech,
							bonus = bonus,
							x = point.x,
							y = point.y,
							distance = distance,
							conditional = true,
							evidence = "Canonical site bonus observed at "
								.. point.x
								.. ":"
								.. point.y,
							caveat = "Observed bonus only; future ownership, tech, focus and placement may prevent assignment.",
						}
					end
				end
			end
		end
	end
	return result
end

-- Exact observed inputs keep same-table exploration updates from leaving stale icons.
function Suggestions.observationSignature(view, observerId, settler, systems)
	local parts = {
		tostring(observerId),
		tostring(settler.id),
		tostring(view.contentRules),
		tostring(view.campaignID),
	}
	local function add(value)
		if type(value) ~= "table" then
			parts[#parts + 1] = type(value) .. ":" .. tostring(value)
			return
		end
		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = key
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		parts[#parts + 1] = "{"
		for _, key in ipairs(keys) do
			add(key)
			add(value[key])
		end
		parts[#parts + 1] = "}"
	end
	local world = view.world
	add({ world.width, world.height, world.wrapX, world.terrainYieldVersion })
	local checked = 0
	for y = 1, world.height do
		for x = 1, world.width do
			if known(view, x, y) then
				local key = World.key(x, y)
				add(key)
				for _, field in ipairs({
					"tiles",
					"geography",
					"resources",
					"improvements",
					"observedOwners",
					"landmarks",
				}) do
					add((world[field] or {})[key])
				end
				checked = checked + 1
				if checked % 64 == 0 and systems and systems.checkpoint then
					systems.checkpoint()
				end
			end
		end
	end
	for _, city in ipairs(view.cities or {}) do
		add({ city.id, city.owner, city.x, city.y, city.sites, city.siteProjects })
	end
	add(view.spawners or {})
	for _, player in ipairs(view.players or {}) do
		if player.id == observerId then
			add(player.techs or {})
		end
	end
	return table.concat(parts, "\31")
end

local function regionScore(view, x, y)
	local score, food, industry = 0, 0, 0
	for _, point in ipairs(Hex.withinRadius(x, y, 3, view)) do
		if known(view, point.x, point.y) then
			local key = World.key(point.x, point.y)
			local owner = (view.world.observedOwners or {})[key]
			-- Existing claims are less useful than fresh workable land for a new city.
			local weight = (4 - Hex.distance(x, y, point.x, point.y, view))
				* (owner ~= nil and 0.5 or 1)
			local yields = World.yields(view.world, point.x, point.y, view)
			food = food + yields.food * weight
			industry = industry + yields.industry * weight
			score = score + (yields.food * 2 + yields.industry + (yields.science or 0)) * weight
			if (view.world.resources or {})[key] then
				score = score + 3 * weight
			end
		end
	end
	return score, food, industry
end

function Suggestions.forSettler(view, observerId, settler, systems, limit)
	-- Returns globally ranked canonical candidates from the projected view. Checkpoints run
	-- each row and every 64 known tiles; output is capped after ranking to `limit` (max 256).
	if type(view) ~= "table" or type(view.world) ~= "table" or type(settler) ~= "table" then
		return {}
	end
	local player
	for _, candidate in ipairs(view.players or {}) do
		if candidate.id == observerId then
			player = candidate
			break
		end
	end
	if not player or settler.owner ~= observerId or settler.kind ~= "settler" then
		return {}
	end
	limit = type(limit) == "number" and limit == math.floor(limit) and limit or MAX_RESULTS
	limit = math.max(1, math.min(MAX_RESULTS, limit))
	local found, checked = {}, 0
	for y = 1, view.world.height do
		if systems and systems.checkpoint then
			systems.checkpoint()
		end
		for x = 1, view.world.width do
			local key = World.key(x, y)
			if known(view, x, y) then
				checked = checked + 1
				if checked % 64 == 0 and systems and systems.checkpoint then
					systems.checkpoint()
				end
				local legal = Founding.canFound(view, observerId, x, y, systems)
				local observedOwner = (view.world.observedOwners or {})[key]
				if observedOwner and observedOwner ~= observerId then
					legal = false
				end
				for _, city in ipairs(view.cities or {}) do
					if
						Hex.distance(x, y, city.x, city.y, view) < Suggestions.minimumCityDistance
					then
						legal = false
						break
					end
				end
				if legal then
					local score, food, industry = regionScore(view, x, y)
					found[#found + 1] = {
						x = x,
						y = y,
						score = score,
						food = food,
						industry = industry,
					}
				end
			end
		end
	end
	table.sort(found, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.y == b.y and a.x < b.x or a.y < b.y
	end)
	local separated = {}
	for _, candidate in ipairs(found) do
		local distinct = candidate.score > 0
		for _, prior in ipairs(separated) do
			if
				Hex.distance(candidate.x, candidate.y, prior.x, prior.y, view)
				< Suggestions.minimumRecommendationDistance
			then
				distinct = false
				break
			end
		end
		if distinct then
			separated[#separated + 1] = candidate
		end
		if #separated >= limit then
			break
		end
	end
	found = separated
	for index, candidate in ipairs(found) do
		if systems and systems.checkpoint and index % 16 == 0 then
			systems.checkpoint()
		end
		local spacing, nearest = math.huge, nil
		for _, city in ipairs(view.cities or {}) do
			local distance = Hex.distance(candidate.x, candidate.y, city.x, city.y, view)
			if distance < spacing then
				spacing, nearest = distance, city
			end
		end
		if spacing == math.huge then
			spacing = 0
		end
		local resources = {}
		for _, point in ipairs(Hex.neighbours(candidate.x, candidate.y, view)) do
			local resource = (view.world.resources or {})[World.key(point.x, point.y)]
			if known(view, point.x, point.y) and resource then
				resources[#resources + 1] = resource
			end
		end
		table.sort(resources)
		local capacity = capacityFor(
			view,
			candidate.x,
			candidate.y,
			systems and systems.buildings or Content.buildings
		)
		local reasons = {
			"Food yield: " .. candidate.food,
			"Industry yield: " .. candidate.industry,
			capacity.active and "Observed city capacity: " .. capacity.observedMinimum
				or "City capacity is not active in this campaign profile",
			spacing == 0 and "No known cities affect spacing"
				or "Nearest known city is " .. spacing .. " hexes away",
		}
		for _, resource in ipairs(resources) do
			reasons[#reasons + 1] = "Adjacent explored resource: " .. resource
		end
		local specialties = futureSpecialties(view, player, candidate.x, candidate.y)
		for _, specialty in ipairs(specialties) do
			reasons[#reasons + 1] = specialty.name
				.. " may be a future opportunity near "
				.. specialty.x
				.. ":"
				.. specialty.y
		end
		candidate.capacity = capacity
		candidate.resources = resources
		candidate.specialties = specialties
		candidate.reasons = reasons
		candidate.nearestCity = nearest and { id = nearest.id, distance = spacing } or nil
		candidate.incompleteKnowledge = true
		candidate.knowledgeNote =
			"Uses explored observations only; values may be incomplete or remembered."
		candidate.food, candidate.industry = nil, nil
	end
	return found
end

return Suggestions
