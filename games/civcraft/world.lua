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
local W = {}
W.sizes = {
	compact = { 18, 12 },
	standard = { 28, 18 },
	large = { 40, 26 },
	huge = { 48, 32 },
	vast = {
		64,
		40,
	},
}
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
	return player.mapMemory
end

W.generationVersion = Generator.version
function W.generate(seed, size, count, mapType)
	size = W.sizes[size] and size or "standard"
	seed = math.floor(tonumber(seed) or 12345) % 1000000
	count = math.max(1, math.min(4, math.floor(tonumber(count) or 4)))
	if
		not ({ continents = true, archipelago = true, pangaea = true, highlands = true })[mapType]
	then
		mapType = "continents"
	end
	return Generator.generate(seed, size, count, mapType, W.sizes[size], W.checkpoint)
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
				dist = hex.distance(x, y, city.x, city.y)
			end
		else
			local candidate = hex.distance(x, y, city.x, city.y)
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
			for y = math.max(1, city.y - range), math.min(state.world.height, city.y + range) do
				for x = math.max(1, city.x - range), math.min(state.world.width, city.x + range) do
					if hex.distance(city.x, city.y, x, y) <= range then
						city.claimed[key(x, y)] = true
					end
				end
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
	for y = math.max(1, city.y - 3), math.min(state.world.height, city.y + 3) do
		for x = math.max(1, city.x - 3), math.min(state.world.width, city.x + 3) do
			if
				hex.distance(city.x, city.y, x, y) <= 3 and not W.territoryCity(state, hex, x, y)
			then
				local adjacent = false
				for _, n in ipairs(hex.neighbours(x, y, state)) do
					if city.claimed[key(n.x, n.y)] then
						adjacent = true
						break
					end
				end
				if adjacent then
					local yield = W.yields(state.world, x, y)
					candidates[#candidates + 1] = {
						x = x,
						y = y,
						distance = hex.distance(city.x, city.y, x, y),
						score = yield.food + yield.industry + yield.science,
					}
				end
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
function W.yields(world, x, y)
	local food, industry = Biomes.yields(Biomes.tile(world, x, y))
	local science = 0
	local deposit = W.deposit(world, x, y)
	if deposit == "grain" or deposit == "fish" then
		food = food + 2
	elseif deposit == "stone" or deposit == "timber" then
		industry = industry + 2
	elseif deposit == "iron" then
		industry = industry + 1
	elseif deposit == "saltpeter" then
		science = science + 2
	elseif deposit == "horses" then
		food = food + 1
	end
	local landmark = world and (world.landmarks or {})[key(x, y)]
	local extra = landmark and landmark.natural and Content.naturalWonders[landmark.kind] or {}
	food = food + (extra.food or 0)
	industry = industry + (extra.industry or 0)
	science = science + (extra.science or 0)
	if deposit == "copper" or deposit == "zinc" then
		industry = industry + 1
	end
	if deposit == "redstone" or deposit == "diamond" then
		science = science + 1
	end
	return { food = food, industry = industry, science = science }
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
	for _, camp in ipairs(state.spawners or {}) do
		camps[key(camp.x, camp.y)] = camp
	end
	for _, p in ipairs(state.players or {}) do
		if W.checkpoint then
			W.checkpoint()
		end
		p.explored = p.explored or {}
		local visible = {}
		local function reveal(x, y, r)
			for yy = math.max(1, y - r), math.min(world.height, y + r) do
				for xx = math.max(1, x - r), math.min(world.width, x + r) do
					if hex.distance(x, y, xx, yy) <= r then
						local k = key(xx, yy)
						visible[k] = true
						p.explored[k] = true
					end
				end
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
		p.visible = visible
		Contacts.observe(state, p, pendingNotices)
		local memory = mapMemory(p, world)
		for tileKey in pairs(visible) do
			memory.landmarks[tileKey] = landmarkView((world.landmarks or {})[tileKey])
			memory.rails[tileKey] = (world.rails or {})[tileKey] and true or nil
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
		phase = state.phase,
		round = state.round,
		turn = state.turn,
		name = state.name,
		winner = state.winner,
		ruleset = state.ruleset,
		roundLimit = state.roundLimit,
		gameSpeed = state.gameSpeed,
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
		for _, player in ipairs(state.players) do
			view.players[#view.players + 1] = {
				id = player.id,
				name = player.name,
				civ = player.civ,
				ai = player.ai,
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
			rails = {},
			contentVersion = world.contentVersion,
			generationVersion = world.generationVersion,
		}
		for y = 1, world.height do
			if W.checkpoint then
				W.checkpoint()
			end
			for x = 1, world.width do
				local k = key(x, y)
				if (observer.explored or {})[k] or (observer.visible or {})[k] then
					view.world.tiles[k] = world.tiles[k]
					view.world.geography[k] = (world.geography or {})[k]
					view.world.resources[k] = (world.resources or {})[k]
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
				ready = p.ready,
				age = p.age,
				industryTurns = p.industryTurns,
				endStage = p.endStage,
			}
		end
	end
	for _, c in ipairs(state.cities or {}) do
		if
			c.owner == id
			or (observer.visible or {})[key(c.x, c.y)]
			or c.village and (observer.explored or {})[key(c.x, c.y)]
		then
			local copy = {}
			if c.owner == id then
				for field, value in pairs(c) do
					copy[field] = value
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
					publicDefense = CombatStrength.unit(u, Content, true, state),
				}
			end
		end
	end
	view.spawners = W.observedCamps(state, observer)
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
