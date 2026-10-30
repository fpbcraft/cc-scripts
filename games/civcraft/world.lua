local Sites = dofile("/games/civcraft/specialty_sites.lua")
-- Seeded hex geography, strategic deposits, private discovery and territory.
-- World state is authoritative and saved; map presets never reroll on reload.
local Biomes = dofile("/games/civcraft/biomes.lua")
local Contacts = dofile("/games/civcraft/contacts.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local CombatStrength = dofile("/games/civcraft/combat_strength.lua")
local Content = dofile("/games/civcraft/content.lua")
local Events = dofile("/games/civcraft/events.lua")
local Generator = dofile("/games/civcraft/worldgen.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local Council = dofile("/games/civcraft/council.lua")
local Works = dofile("/games/civcraft/tile_improvements.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local W = {}
W.sizes = {
	compact = { 24, 16 },
	standard = { 40, 26 },
	large = { 56, 36 },
	huge = { 72, 46 },
	vast = { 96, 60 },
}
W.expandedSizes = {
	compact = { 32, 22 },
	standard = { 56, 36 },
	large = { 72, 46 },
	huge = { 96, 60 },
	vast = {
		120,
		76,
	},
}
function W.dimensions(size, context)
	local sizes = ContentRules.startsWithSettler(context) and W.expandedSizes or W.sizes
	return sizes[size] or sizes.standard
end
W.sizeOrder = { "compact", "standard", "large", "huge", "vast" }
W.types = { "continents", "archipelago", "pangaea", "highlands" }
local function key(x, y)
	return x .. ":" .. y
end
W.key = key
local function landmarkView(landmark)
	if not landmark then
		return nil
	end
	return { kind = landmark.kind, natural = landmark.natural == true }
end

local function campView(camp)
	return { id = camp.id, x = camp.x, y = camp.y, kind = camp.kind, cleared = camp.cleared == true }
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for field, item in pairs(value) do
		result[field] = copy(item)
	end
	return result
end

local function cityObservation(state, city, observer)
	return {
		id = city.id,
		name = city.name,
		owner = city.owner,
		x = city.x,
		y = city.y,
		hp = city.hp,
		maxHP = city.maxHP,
		wallHP = city.wallHP,
		maxWalls = city.maxWalls,
		population = city.population,
		capitalOf = city.capitalOf,
		village = city.village,
		villageOwner = city.villageOwner,
		villageKind = city.villageKind,
		buildings = {
			walls = (city.buildings or {}).walls,
			fortress = (city.buildings or {}).fortress,
		},
		publicDefense = CombatStrength.city(state, city, Content),
		influence = city.village and { [observer] = (city.influence or {})[observer] } or nil,
		envoyRounds = city.village and { [observer] = (city.envoyRounds or {})[observer] } or nil,
		publicAlly = city.village and (Villages.ally(city) or false) or nil,
		remembered = true,
		lastSeenRound = state.round or 1,
	}
end

local function mapMemory(player, world)
	if not player.mapMemory or player.mapMemory.version ~= 1 then
		player.mapMemory = { version = 1, landmarks = {}, rails = {}, spawners = {} }
		-- Natural geography is immutable; old explored land may restore that knowledge.
		for tileKey, landmark in pairs(world.landmarks or {}) do
			if landmark.natural and (player.explored or {})[tileKey] then
				player.mapMemory.landmarks[tileKey] = landmarkView(landmark)
			end
		end
	end
	if Sites.enabled(player) then
		player.mapMemory.sites = player.mapMemory.sites or {}
	end
	player.mapMemory.observations = player.mapMemory.observations or {}
	player.mapMemory.cities = player.mapMemory.cities or {}
	return player.mapMemory
end

W.generationVersion = Generator.version
W.currentTerrainYieldVersion = "civ6-1"
function W.generate(seed, size, count, mapType, context)
	size = W.sizes[size] and size or "standard"
	seed = math.floor(tonumber(seed) or 12345) % 1000000
	count = math.max(1, math.min(4, math.floor(tonumber(count) or 4)))
	if
		not ({ continents = true, archipelago = true, pangaea = true, highlands = true })[mapType]
	then
		mapType = "continents"
	end
	local world = Generator.generate(
		seed,
		size,
		count,
		mapType,
		W.dimensions(size, context),
		W.checkpoint,
		context and context.terrainYieldVersion or W.currentTerrainYieldVersion,
		context and (context.wrapX == true or context.mapWrapX == true) or false
	)
	if ContentRules.startsWithSettler(context) then
		world.mapScaleVersion = "founders-v1"
	end
	return world
end
W.tile = Biomes.tile
function W.terrain(world, x, y)
	if not world or x < 1 or y < 1 or x > world.width or y > world.height then
		return nil
	end
	return world.tiles[key(x, y)] or "plains"
end
function W.deposit(world, x, y)
	if not world or not world.resources then
		return nil
	end
	return world.resources[key(x, y)]
end
-- Migrate pre-v0.5 legacy maps without changing existing city terrain.
function W.migrate(state)
	if not state.world and state.phase == "game" then
		local world = {
			width = 12,
			height = 8,
			seed = 0,
			size = "legacy",
			mapType = "legacy",
			tiles = {},
			resources = {},
			starts = {},
		}
		for y = 1, 8 do
			for x = 1, 12 do
				local v = (x * 37 + y * 61 + x * y * 13) % 19
				local t = v <= 1 and "water"
					or v <= 3 and "mountain"
					or v < 9 and "forest"
					or "plains"
				world.tiles[key(x, y)] = t
			end
		end
		state.world = world
		state.mapSize = "compact"
		state.mapSeed = 0
	end
	if state.world then
		local world = state.world
		world.mapType = world.mapType or "continents"
		world.resources = world.resources or {}
		world.generationVersion = world.generationVersion or 1
		-- Old serialized maps remain finite unless a save explicitly records wrap.
		world.wrapX = world.wrapX == true
		-- Upgrade all existing saves in place; no world regeneration or reset.
		world.terrainYieldVersion = W.currentTerrainYieldVersion
	end
	state.mapType = state.mapType or state.world and state.world.mapType or "continents"
	return state
end
local function radius(city)
	return city.population and city.population >= 6 and 3
		or city.population and city.population >= 4 and 2
		or 1
end
function W.territoryCity(state, hex, x, y)
	local best, bestDist
	local tileKey = key(x, y)
	for _, city in ipairs(state.cities or {}) do
		local dist
		if city.claimed then
			if city.claimed[tileKey] then
				dist = hex.distance(x, y, city.x, city.y, state)
			end
		else
			local candidate = hex.distance(x, y, city.x, city.y, state)
			if candidate <= radius(city) then
				dist = candidate
			end
		end
		if
			dist
			and (
				not bestDist
				or dist < bestDist
				or (dist == bestDist and (city.id or 0) < (best.id or 0))
			)
		then
			best, bestDist = city, dist
		end
	end
	return best
end
function W.ensureTerritories(state, hex, legacy)
	if not state.world then
		return
	end
	for _, city in ipairs(state.cities or {}) do
		if not city.claimed then
			local range = legacy and radius(city) or 1
			city.claimed = {}
			city.borderProgress = city.borderProgress or 0
			for _, position in ipairs(hex.withinRadius(city.x, city.y, range, state)) do
				city.claimed[key(position.x, position.y)] = true
			end
		end
	end
end
function W.expandCity(state, hex, city)
	W.ensureTerritories(state, hex, false)
	city.borderProgress = (city.borderProgress or 0) + 1
	local count = 0
	for _ in pairs(city.claimed or {}) do
		count = count + 1
	end
	local delay = 6 + math.floor(count / 4)
	if city.borderProgress < delay then
		return false
	end
	local candidates = {}
	for _, position in ipairs(hex.withinRadius(city.x, city.y, 3, state)) do
		local x, y = position.x, position.y
		if not W.territoryCity(state, hex, x, y) then
			local adjacent = false
			for _, n in ipairs(hex.neighbours(x, y, state)) do
				if city.claimed[key(n.x, n.y)] then
					adjacent = true
					break
				end
			end
			if adjacent then
				local yield = W.yields(state.world, x, y, state)
				candidates[#candidates + 1] = {
					x = x,
					y = y,
					distance = hex.distance(city.x, city.y, x, y, state),
					score = yield.food + yield.industry + yield.science,
				}
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.y == b.y and a.x < b.x or a.y < b.y
	end)
	local tile = candidates[1]
	if not tile then
		city.borderProgress = math.min(city.borderProgress, delay)
		return false
	end
	city.claimed[key(tile.x, tile.y)] = true
	city.borderProgress = 0
	state.territoryRevision = (state.territoryRevision or 0) + 1
	return true, tile
end
function W.yields(world, x, y, context)
	local food, industry, gold = Biomes.yields(Biomes.tile(world, x, y))
	local science = 0
	local deposit = W.deposit(world, x, y)
	-- Match Civ VI where a resource has a direct counterpart. CivCraft-only
	-- deposits (timber, zinc, redstone) retain their own modifiers.
	if deposit == "grain" or deposit == "fish" then
		food = food + 1
	elseif deposit == "stone" then
		industry = industry + 1
	elseif deposit == "timber" then
		industry = industry + 2
	elseif deposit == "iron" then
		science = science + 1
	elseif deposit == "saltpeter" then
		food, industry = food + 1, industry + 1
	elseif deposit == "horses" then
		food, industry = food + 1, industry + 1
	end

	local landmark = world and (world.landmarks or {})[key(x, y)]
	local extra = landmark and landmark.natural and Content.naturalWonders[landmark.kind] or {}
	food = food + (extra.food or 0)
	industry = industry + (extra.industry or 0)
	science = science + (extra.science or 0)
	if deposit == "copper" then
		gold = gold + 2
	elseif deposit == "zinc" then
		industry = industry + 1
	elseif deposit == "redstone" then
		science = science + 1
	elseif deposit == "diamond" then
		gold = gold + 3
	end
	local extraFood, extraIndustry = Works.bonus(world, x, y)
	local improvement = (world.improvements or {})[key(x, y)]
	if
		improvement
		and not improvement.damaged
		and not (world.landmarks or {})[key(x, y)]
		and context
	then
		local owner
		if world.observedOwners then
			owner = world.observedOwners[key(x, y)]
		else
			local city = W.territoryCity(context, Hex, x, y)
			owner = city and city.owner
		end
		for _, player in ipairs(context.players or {}) do
			if player.id == owner then
				if improvement.kind == "farm" and player.civ == "verdant" then
					extraFood = extraFood + 1
				end
				if improvement.kind == "quarry" and player.civ == "iron" then
					extraIndustry = extraIndustry + 1
				end
			end
		end
	end
	return {
		food = food + extraFood,
		industry = industry + extraIndustry,
		science = science,
		gold = gold,
	}
end
-- Hex territory nearest owner; deterministic tie break by city ID.
function W.territory(state, hex)
	local w = state.world
	local result = {}
	if not w then
		return result
	end
	for y = 1, w.height do
		if W.checkpoint then
			W.checkpoint()
		end
		for x = 1, w.width do
			local city = W.territoryCity(state, hex, x, y)
			if city then
				result[key(x, y)] = city.owner
			end
		end
	end
	return result
end
function W.strategic(state, player, hex, res)
	local owned = W.territory(state, hex)
	for k, id in pairs(owned) do
		if id == player.id and state.world.resources and state.world.resources[k] == res then
			return true
		end
	end
	return false
end
function W.reveal(state, hex, systems, pendingNotices)
	local world = state.world
	if not world then
		return
	end
	local camps = {}
	local cities = {}
	for _, city in ipairs(state.cities or {}) do
		cities[key(city.x, city.y)] = city
	end
	for _, camp in ipairs(state.spawners or {}) do
		camps[key(camp.x, camp.y)] = camp
	end
	-- A per-reveal lookup avoids scanning every city's sites for each visible
	-- tile of every player. Keep the same last-matching-site precedence.
	local sitesEnabled = Sites.enabled(state)
	local sites = {}
	if sitesEnabled then
		for _, city in ipairs(state.cities or {}) do
			for _, site in pairs(city.sites or {}) do
				if site.x and site.y then
					sites[key(site.x, site.y)] = { city = city, site = site }
				end
			end
		end
	end
	for _, p in ipairs(state.players or {}) do
		if W.checkpoint then
			W.checkpoint()
		end
		p.explored = p.explored or {}
		local visible = {}
		local function reveal(x, y, r)
			for _, position in ipairs(hex.withinRadius(x, y, r, state)) do
				local k = key(position.x, position.y)
				visible[k] = true
				p.explored[k] = true
			end
		end
		for _, c in ipairs(state.cities or {}) do
			if c.owner == p.id then
				reveal(c.x, c.y, 2)
			end
		end
		for _, unit in ipairs(state.units or {}) do
			if unit.owner == p.id then
				local stat = systems.units[unit.kind] or systems.units.warrior
				reveal(unit.x, unit.y, stat.vision or 2)
			end
		end
		local lastLook = {}
		for tileKey in pairs(p.visible or {}) do
			lastLook[tileKey] = true
		end
		for tileKey in pairs(visible) do
			lastLook[tileKey] = true
		end
		p.visible = visible
		Contacts.observe(state, p, pendingNotices)
		local memory = mapMemory(p, world)
		local observedCount = 0
		for tileKey in pairs(lastLook) do
			observedCount = observedCount + 1
			if observedCount % 32 == 0 and W.checkpoint then
				W.checkpoint()
			end
			local x, y = tileKey:match("^(%d+):(%d+)$")
			x, y = tonumber(x), tonumber(y)
			local claim = W.territoryCity(state, hex, x, y)
			memory.observations[tileKey] = {
				tile = copy(world.tiles[tileKey]),
				geography = copy((world.geography or {})[tileKey]),
				resource = (world.resources or {})[tileKey] or false,
				road = Sites.enabled(state) and ((world.roads or {})[tileKey] == true) or nil,
				improvement = world.improvements and (copy(world.improvements[tileKey]) or false)
					or nil,
				owner = claim and claim.owner or false,
				round = state.round or 1,
			}
			memory.cities[tileKey] = cities[tileKey]
					and cityObservation(state, cities[tileKey], p.id)
				or nil
			memory.landmarks[tileKey] = landmarkView((world.landmarks or {})[tileKey])
			memory.rails[tileKey] = (world.rails or {})[tileKey] and true or nil
			if sitesEnabled then
				local record = sites[tileKey]
				memory.sites[tileKey] = record and Sites.public(state, record.city, record.site)
					or nil
			end
			memory.spawners[tileKey] = camps[tileKey] and campView(camps[tileKey]) or nil
		end
		p.knownLandmarks = p.knownLandmarks or {}
		local landmarkKeys = {}
		for tileKey in pairs(world.landmarks or {}) do
			landmarkKeys[#landmarkKeys + 1] = tileKey
		end
		table.sort(landmarkKeys)
		for _, tileKey in ipairs(landmarkKeys) do
			local landmark = world.landmarks[tileKey]
			if visible[tileKey] and not p.knownLandmarks[tileKey] then
				p.knownLandmarks[tileKey] = true
				local x, y = tileKey:match("^(%d+):(%d+)$")
				local event = {
					type = "landmark",
					recipient = p.id,
					content = landmark.kind,
					target = { x = tonumber(x), y = tonumber(y), visible = { [p.id] = true } },
				}
				if pendingNotices then
					pendingNotices[#pendingNotices + 1] = event
				else
					Events.emit(state, event)
				end
			end
		end
	end
end
function W.observedCity(state, observer, x, y)
	local tileKey = key(x, y)
	for _, city in ipairs(state.cities or {}) do
		if
			city.x == x
			and city.y == y
			and (city.owner == observer.id or (observer.visible or {})[tileKey])
		then
			return city
		end
	end
	if not (observer.visible or {})[tileKey] and (observer.explored or {})[tileKey] then
		return observer.mapMemory
			and observer.mapMemory.cities
			and observer.mapMemory.cities[tileKey]
	end
end

function W.observedOwner(state, observer, x, y)
	local tileKey = key(x, y)
	if state.world and state.world.observedOwners then
		return state.world.observedOwners[tileKey] or nil
	end
	local claim = W.territoryCity(state, Hex, x, y)
	if (observer.visible or {})[tileKey] or claim and claim.owner == observer.id then
		return claim and claim.owner
	end
	local record = observer.mapMemory
		and observer.mapMemory.observations
		and observer.mapMemory.observations[tileKey]
	return record and record.owner or nil
end
function W.observedFeatures(state, observer, x, y)
	if not observer or not state.world then
		return nil, nil
	end
	local tileKey = key(x, y)
	local world = state.world
	if (observer.visible or {})[tileKey] then
		return landmarkView((world.landmarks or {})[tileKey]),
			(world.rails or {})[tileKey] and true or nil
	end
	if not (observer.explored or {})[tileKey] then
		return nil, nil
	end
	local memory = observer.mapMemory
	if memory and memory.version == 1 then
		return memory.landmarks[tileKey], memory.rails[tileKey]
	end
	local landmark = (world.landmarks or {})[tileKey]
	if landmark and landmark.natural then
		return landmarkView(landmark), nil
	end
	return nil, nil
end

function W.observedCamps(state, observer)
	if not observer then
		return {}
	end
	local knownCamps = {}
	for tileKey, camp in pairs(observer.mapMemory and observer.mapMemory.spawners or {}) do
		if (observer.explored or {})[tileKey] and not (observer.visible or {})[tileKey] then
			knownCamps[tileKey] = campView(camp)
		end
	end
	for _, camp in ipairs(state.spawners or {}) do
		if (observer.visible or {})[key(camp.x, camp.y)] then
			knownCamps[key(camp.x, camp.y)] = campView(camp)
		end
	end
	local campKeys = {}
	for tileKey in pairs(knownCamps) do
		campKeys[#campKeys + 1] = tileKey
	end
	table.sort(campKeys)
	local result = {}
	for _, tileKey in ipairs(campKeys) do
		result[#result + 1] = knownCamps[tileKey]
	end
	return result
end

-- Build an observer-safe network snapshot. Local saves keep the authoritative state.
function W.forPlayer(state, id, afterSeq)
	local observer
	for _, p in ipairs(state.players or {}) do
		if p.id == id then
			observer = p
			break
		end
	end
	if not observer then
		return nil
	end
	local view = {
		version = state.version,
		observerID = id,
		campaignID = state.campaignID,
		eventStream = Events.forPlayer(state, id, afterSeq),
		eventHistory = Events.history(state, id),
		phase = state.phase,
		round = state.round,
		turn = state.turn,
		name = state.name,
		winner = state.winner,
		ruleset = state.ruleset,
		roundLimit = state.roundLimit,
		gameSpeed = state.gameSpeed,
		contentRules = state.contentRules,
		specialtySchema = state.specialtySchema,
		victoryRulesVersion = state.victoryRulesVersion,
		council = Council.public(state, id),
		diplomacy = Diplomacy.public(state, id, Hex, Content.units),
		scheduler = Scheduler.public(state),
		victories = state.victories and {},
		hostileMode = state.hostileMode,
		victoryReason = state.victoryReason,
		spawners = {},
		players = {},
		cities = {},
		units = {},
		logs = {},
	}
	for victory, enabled in pairs(state.victories or {}) do
		view.victories[victory] = enabled
	end
	if state.phase ~= "game" and state.phase ~= "over" then
		view.mapSize, view.mapType, view.mapSeed = state.mapSize, state.mapType, state.mapSeed
		view.mapWrapX = state.mapWrapX == true or state.wrapX == true
		for _, player in ipairs(state.players) do
			view.players[#view.players + 1] = {
				id = player.id,
				name = player.name,
				civ = player.civ,
				ai = player.ai,
				aiDifficulty = player.aiDifficulty,
				ready = player.ready,
			}
		end
		return view
	end
	local world = state.world
	if world then
		view.world = {
			width = world.width,
			height = world.height,
			size = world.size,
			mapType = world.mapType,
			tiles = {},
			geography = {},
			resources = {},
			landmarks = {},
			improvements = {},
			rails = {},
			observedOwners = {},
			specialtySites = Sites.enabled(state) and {} or nil,
			roads = Sites.enabled(state) and {} or nil,
			contentVersion = world.contentVersion,
			generationVersion = world.generationVersion,
			wrapX = world.wrapX == true,
			mapScaleVersion = world.mapScaleVersion,
			terrainYieldVersion = world.terrainYieldVersion,
		}
		for y = 1, world.height do
			if W.checkpoint then
				W.checkpoint()
			end
			for x = 1, world.width do
				local k = key(x, y)
				if (observer.explored or {})[k] or (observer.visible or {})[k] then
					local record = observer.mapMemory
						and observer.mapMemory.observations
						and observer.mapMemory.observations[k]
					local visible = (observer.visible or {})[k]
					if not visible and record then
						view.world.tiles[k], view.world.geography[k] = record.tile, record.geography
					else
						view.world.tiles[k], view.world.geography[k] =
							world.tiles[k], (world.geography or {})[k]
					end
					if visible then
						view.world.resources[k] = (world.resources or {})[k]
					elseif record then
						view.world.resources[k] = record.resource or nil
					end
					if visible then
						view.world.improvements[k] = copy((world.improvements or {})[k])
					elseif record then
						view.world.improvements[k] = copy(record.improvement) or nil
					end
					if Sites.enabled(state) then
						view.world.roads[k] = visible and ((world.roads or {})[k] == true)
							or not visible and record and record.road == true
							or nil
						if visible then
							for _, c in ipairs(state.cities or {}) do
								for _, site in pairs(c.sites or {}) do
									if site.x == x and site.y == y then
										view.world.specialtySites[k] = Sites.public(state, c, site)
									end
								end
							end
						else
							view.world.specialtySites[k] = copy(
								observer.mapMemory
									and observer.mapMemory.sites
									and observer.mapMemory.sites[k]
							)
						end
					end
					view.world.observedOwners[k] = W.observedOwner(state, observer, x, y)
					view.world.landmarks[k], view.world.rails[k] =
						W.observedFeatures(state, observer, x, y)
				end
			end
		end
	end
	for _, p in ipairs(state.players or {}) do
		if p.id == id then
			view.players[#view.players + 1] = p
		else
			view.players[#view.players + 1] = {
				id = p.id,
				name = p.name,
				civ = p.civ,
				ai = p.ai,
				aiDifficulty = p.aiDifficulty,
				ready = p.ready,
				age = p.age,
				industryTurns = p.industryTurns,
				endStage = p.endStage,
			}
		end
	end
	for _, c in ipairs(state.cities or {}) do
		if c.owner == id or (observer.visible or {})[key(c.x, c.y)] then
			local copy = {}
			if c.owner == id then
				for field, value in pairs(c) do
					copy[field] = value
				end
				if Sites.enabled(state) then
					local details = Sites.owned(state, observer, c)
					for field, value in pairs(details) do
						copy[field] = value
					end
				end
			else
				copy = {
					id = c.id,
					name = c.name,
					owner = c.owner,
					x = c.x,
					y = c.y,
					hp = c.hp,
					maxHP = c.maxHP,
					wallHP = c.wallHP,
					maxWalls = c.maxWalls,
					population = c.population,
					capitalOf = c.capitalOf,
					village = c.village,
					villageOwner = c.villageOwner,
					villageKind = c.villageKind,
					buildings = {
						walls = (c.buildings or {}).walls,
						fortress = (c.buildings or {}).fortress,
					},
				}
			end
			copy.publicDefense = CombatStrength.city(state, c, Content)
			if c.village then
				if not (observer.visible or {})[key(c.x, c.y)] then
					copy = {
						id = c.id,
						name = c.name,
						owner = c.owner,
						x = c.x,
						y = c.y,
						village = true,
						villageOwner = c.villageOwner,
						villageKind = c.villageKind,
						remoteVillage = true,
					}
				end
				copy.influence = { [id] = (c.influence or {})[id] }
				copy.envoyRounds = { [id] = (c.envoyRounds or {})[id] }
				copy.publicAlly = Villages.ally(c) or false
			end
			view.cities[#view.cities + 1] = copy
		end
	end
	for tileKey, remembered in pairs(observer.mapMemory and observer.mapMemory.cities or {}) do
		if
			remembered.village
			and not (observer.visible or {})[tileKey]
			and (observer.explored or {})[tileKey]
		then
			local village = copy(remembered)
			village.remoteVillage = true
			village.hp, village.maxHP, village.wallHP, village.maxWalls = nil, nil, nil, nil
			village.population, village.buildings, village.publicDefense = nil, nil, nil
			view.cities[#view.cities + 1] = village
		end
	end
	for _, u in ipairs(state.units or {}) do
		if u.owner == id or (observer.visible or {})[key(u.x, u.y)] then
			if u.owner == id then
				view.units[#view.units + 1] = u
			else
				view.units[#view.units + 1] = {
					id = u.id,
					owner = u.owner,
					kind = u.kind,
					x = u.x,
					y = u.y,
					hp = u.hp,
					maxHP = u.maxHP,
					level = u.level,
					villageGuard = u.villageGuard and true or nil,
					publicAttack = CombatStrength.unit(u, Content, false, state),
					publicEmbarked = not (Content.units[u.kind] or {}).naval
						and W.terrain(state.world, u.x, u.y) == "water",
					publicDefense = CombatStrength.unit(u, Content, true, state),
				}
			end
		end
	end
	view.spawners = W.observedCamps(state, observer)
	if Sites.enabled(state) then
		return copy(view)
	end
	return view
end
function W.known(player, x, y)
	if not player then
		return "hidden"
	end
	local k = key(x, y)
	if player.visible and player.visible[k] then
		return "visible"
	end
	if player.explored and player.explored[k] then
		return "explored"
	end
	return "hidden"
end
return W
