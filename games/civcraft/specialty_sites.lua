-- Campaign-scoped city specialties. Reservations are derived from retained projects.
local Rules = dofile("/games/civcraft/content_rules.lua")
local Campaign = dofile("/games/civcraft/campaign_rules.lua")
local Content = dofile("/games/civcraft/content.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Sites = {
	order = { "works", "knowledge", "freight" },
	definitions = {
		works = {
			name = "CREATE WORKS",
			tech = "engineering",
			production = 30,
			output = "industry",
		},
		knowledge = {
			name = "PONDER CAMPUS",
			tech = "writing",
			production = 30,
			output = "science",
		},
		freight = { name = "FREIGHT YARD", tech = "currency", production = 30, output = "gold" },
	},
	families = {},
	requirements = {
		press = {},
		mixer = { "burner" },
		assembly = { "deployer" },
		steamplant = { "assembly" },
		bank = { "freight" },
		observatory = { "portal" },
	},
}
for _, id in ipairs({
	"deepmine",
	"workshop",
	"waterwheel",
	"windmill",
	"press",
	"crusher",
	"beltlogistics",
	"burner",
	"mixer",
	"deployer",
	"assembly",
	"crafter",
	"steamplant",
}) do
	Sites.families[id] = "works"
end
for _, id in ipairs({ "academy", "redstoneworkshop", "university", "grandacademy" }) do
	Sites.families[id] = "knowledge"
end
for _, id in ipairs({ "bazaar", "station", "freight", "bank" }) do
	Sites.families[id] = "freight"
end
local function key(x, y)
	return x .. ":" .. y
end
local function integer(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v % 1 == 0
end
local function owner(state, city)
	for _, p in ipairs(state.players or {}) do
		if p.id == city.owner then
			return p
		end
	end
end
local function world()
	return dofile("/games/civcraft/world.lua")
end
function Sites.enabled(state)
	return Rules.hasSpecialties(state)
end
function Sites.prerequisites(state, id)
	return Sites.enabled(state) and Sites.requirements[id]
		or (Content.buildings[id] or {}).requires
		or {}
end
function Sites.allowance(state, city)
	local used, reserved = 0, 0
	for _ in pairs(city.sites or {}) do
		used = used + 1
	end
	for _, pr in pairs(city.siteProjects or {}) do
		reserved = reserved + 1
		if not pr.sourceSiteId then
			used = used + 1
		end
	end
	local allowed = math.min(3, 1 + math.floor(math.max(0, (city.population or 1) - 1) / 3))
	return {
		allowed = allowed,
		used = used,
		reserved = reserved,
		overage = math.max(0, used - allowed),
	}
end
function Sites.reservations(state)
	local result = {}
	for _, city in ipairs(state.cities or {}) do
		for _, kind in ipairs(Sites.order) do
			local s = (city.sites or {})[kind]
			if s then
				result[#result + 1] =
					{ city = city.id, id = s.id, kind = kind, x = s.x, y = s.y, completed = true }
			end
		end
		local ids = {}
		for id in pairs(city.siteProjects or {}) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local pr = city.siteProjects[id]
			result[#result + 1] = {
				city = city.id,
				id = id,
				kind = pr.kind,
				x = pr.x,
				y = pr.y,
				sourceSiteId = pr.sourceSiteId,
			}
		end
	end
	return result
end
function Sites.at(state, x, y)
	if not Sites.enabled(state) then
		return nil
	end
	for _, r in ipairs(Sites.reservations(state)) do
		if r.x == x and r.y == y then
			return r
		end
	end
end
local function source(city, id)
	for _, site in pairs(city.sites or {}) do
		if site.id == id then
			return site
		end
	end
end
-- Read remembered terrain/resources when a neighboring tile is outside current sight.
local function known(state, p, x, y)
	local k = key(x, y)
	if not (p.explored or {})[k] and not (p.visible or {})[k] then
		return nil
	end
	local memory = p.mapMemory and p.mapMemory.observations and p.mapMemory.observations[k]
	if not (p.visible or {})[k] and memory then
		local tile = memory.geography
		if not tile or Biomes.terrain(tile) ~= memory.tile then
			tile = Biomes.legacy(memory.tile)
		end
		return tile, memory.resource or nil, p.mapMemory.rails and p.mapMemory.rails[k]
	end
	return Biomes.tile(state.world, x, y),
		(state.world.resources or {})[k],
		(state.world.rails or {})[k]
end
local function revealed(p, id)
	local r = Content.resources[id]
	return r and (not r.tech or (p.techs or {})[r.tech])
end
function Sites.bonus(state, p, kind, x, y)
	local tile, resource, rail = known(state, p, x, y)
	if not tile then
		return 0
	end
	if kind == "works" and tile.elevation == "hill" then
		return 1
	end
	if
		kind == "knowledge"
		and (resource == "redstone" or resource == "diamond")
		and revealed(p, resource)
	then
		return 1
	end
	if kind == "freight" and (rail or (state.world.roads or {})[key(x, y)]) then
		return 1
	end
	for _, n in ipairs(Hex.neighbours(x, y, state)) do
		local t, r = known(state, p, n.x, n.y)
		if t then
			if
				kind == "works"
				and (r == "iron" or r == "copper" or r == "zinc")
				and revealed(p, r)
			then
				return 1
			end
			if kind == "knowledge" and t.elevation == "mountain" then
				return 1
			end
			if kind == "freight" and (t.biome == "coast" or t.biome == "ocean") then
				return 1
			end
		end
	end
	return 0
end
local function occupied(state, p, x, y, observed)
	for _, u in ipairs(state.units or {}) do
		if
			u.x == x
			and u.y == y
			and u.owner ~= p.id
			and Diplomacy.canAttack(state, p.id, u.owner)
			and (not observed or (p.visible or {})[key(x, y)])
		then
			return true
		end
	end
	return false
end
local function geography(state, p, city, kind, x, y)
	if not Sites.enabled(state) or not Sites.definitions[kind] then
		return false, "Specialties unavailable"
	end
	if not p or city.owner ~= p.id then
		return false, "Select an owned city"
	end
	if not state.world or not integer(x) or not integer(y) or not Hex.inBounds(x, y, state) then
		return false, "Invalid site hex"
	end
	if not (p.explored or {})[key(x, y)] and not (p.visible or {})[key(x, y)] then
		return false, "Explore the site hex"
	end
	if not (p.techs or {})[Sites.definitions[kind].tech] then
		return false, "Research " .. Sites.definitions[kind].tech
	end
	local distance = Hex.distance(city.x, city.y, x, y)
	if distance < 1 or distance > 3 then
		return false, "Site must be within three hexes"
	end
	if world().territoryCity(state, Hex, x, y) ~= city then
		return false, "Site requires this city's land"
	end
	local tile = Biomes.tile(state.world, x, y)
	if tile.elevation == "mountain" or tile.biome == "coast" or tile.biome == "ocean" then
		return false, "Site requires workable land"
	end
	if (state.world.landmarks or {})[key(x, y)] or (state.world.improvements or {})[key(x, y)] then
		return false, "Tile already developed"
	end
	for _, c in ipairs(state.cities or {}) do
		if c.x == x and c.y == y then
			return false, "City center reserved"
		end
		if c.project and c.project.kind == "wonder" and c.project.x == x and c.project.y == y then
			return false, "Wonder reserves tile"
		end
	end
	return true
end
function Sites.canPlace(state, p, city, kind, x, y, projectId, sourceId)
	local ok, why = geography(state, p, city, kind, x, y)
	if not ok then
		return false, why
	end
	local original = sourceId and source(city, sourceId)
	if sourceId and not original then
		return false, "Source site missing"
	end
	if original and original.kind == kind and original.x == x and original.y == y then
		return false, "Site unchanged"
	end
	for _, r in ipairs(Sites.reservations(state)) do
		if r.id ~= projectId and r.id ~= sourceId then
			if r.x == x and r.y == y then
				return false, "Site reserves tile"
			end
			if r.city == city.id and r.kind == kind then
				return false, "City already has this specialty"
			end
			if sourceId and r.sourceSiteId == sourceId then
				return false, "Source already being redeveloped"
			end
		end
	end
	if
		not sourceId
		and not projectId
		and Sites.allowance(state, city).used >= Sites.allowance(state, city).allowed
	then
		return false, "No free focus slot"
	end
	-- Hidden units cannot alter request legality. Completion rechecks actual occupancy.
	if occupied(state, p, x, y, true) then
		return false, "Hostile unit occupies site"
	end
	return true
end
function Sites.active(state, city, site)
	local p = owner(state, city)
	local ok, why = geography(state, p, city, site.kind, site.x, site.y)
	if not ok then
		return false, why
	end
	if occupied(state, p, site.x, site.y, false) then
		return false, "Hostile unit occupies site"
	end
	return true
end
function Sites.effectiveBuilding(state, city, id)
	if not (city.buildings or {})[id] then
		return false
	end
	if not Sites.enabled(state) then
		return true
	end
	local kind = Sites.families[id]
	if not kind then
		return true
	end
	local site = (city.sites or {})[kind]
	local p = owner(state, city)
	local record = Content.buildings[id]
	return site ~= nil
			and Sites.active(state, city, site)
			and p ~= nil
			and (not record.tech or (p.techs or {})[record.tech])
		or false
end
function Sites.effects(state, city)
	local result = { food = 0, industry = 0, science = 0, gold = 0, reasons = {} }
	if not Sites.enabled(state) then
		return result
	end
	local p = owner(state, city)
	for _, kind in ipairs(Sites.order) do
		local s = (city.sites or {})[kind]
		if s then
			local ok, reason = Sites.active(state, city, s)
			if ok then
				local output = Sites.definitions[kind].output
				result[output] = result[output] + 1 + Sites.bonus(state, p, kind, s.x, s.y)
			else
				result.reasons[#result.reasons + 1] = { kind = kind, reason = reason }
			end
		end
	end
	return result
end
function Sites.cost(p, pr)
	return Campaign.cost(30, p) + (pr.sourceSiteId and Campaign.cost(15, p) or 0)
end
function Sites.progressKey(pr)
	return "site:" .. pr.id .. ":" .. pr.kind .. ":" .. key(pr.x, pr.y)
end
function Sites.pause(city)
	local pr = city.project
	if not pr or pr.kind == "project" then
		return
	end
	if pr.kind == "site" then
		-- The retained record is authoritative, never import a projected progress value.
		local retained = (city.siteProjects or {})[pr.id]
		if retained then
			pr.progress = retained.progress
		end
	else
		city.projectProgress = city.projectProgress or {}
		city.projectProgress[pr.kind .. ":" .. pr.id] = pr.progress
	end
end
function Sites.preview(state, p, city, request)
	local sourceId = request.siteId
	local ok, why =
		Sites.canPlace(state, p, city, request.kind, request.x, request.y, nil, sourceId)
	if not ok then
		return nil, why
	end
	local before = Sites.allowance(state, city)
	local loss, lostProgress = {}, {}
	local original = sourceId and source(city, sourceId)
	if original and original.kind ~= request.kind then
		for id, built in pairs(city.buildings or {}) do
			if built and Sites.families[id] == original.kind then
				loss[#loss + 1] = id
			end
		end
	end
	if original and original.kind ~= request.kind then
		for progressKey, amount in pairs(city.projectProgress or {}) do
			local id = progressKey:match("^building:(.+)$")
			if id and Sites.families[id] == original.kind then
				lostProgress[#lostProgress + 1] = { id = id, progress = amount }
			end
		end
	end
	table.sort(lostProgress, function(a, b)
		return a.id < b.id
	end)
	table.sort(loss)
	return {
		kind = request.kind,
		x = request.x,
		y = request.y,
		cost = Sites.cost(p, { sourceSiteId = sourceId }),
		progress = 0,
		focusBefore = before.used,
		focusAfter = before.used + (sourceId and 0 or 1),
		allowance = before.allowed,
		base = 1,
		bonus = Sites.bonus(state, p, request.kind, request.x, request.y),
		lostBuildings = loss,
		lostProgress = lostProgress,
		tile = Biomes.tile(state.world, request.x, request.y),
		tileYields = dofile("/games/civcraft/systems.lua").tileYields(state, request.x, request.y),
	}
end
function Sites.request(state, p, city, req)
	if not Sites.enabled(state) then
		return false, "Specialties unavailable"
	end
	if req.action == "resumeSite" or req.action == "cancelSite" then
		local pr = (city.siteProjects or {})[req.projectId]
		if not pr then
			return false, "Site project missing"
		end
		if req.action == "cancelSite" then
			if city.project and city.project.kind == "site" and city.project.id == pr.id then
				city.project = nil
			end
			city.siteProjects[pr.id] = nil
			return true, "Site project canceled; invested industry forfeited"
		end
		Sites.pause(city)
		city.project = { kind = "site", id = pr.id, progress = pr.progress, x = pr.x, y = pr.y }
		city.productionIdle = false
		return true, "Site production resumed"
	end
	local sourceId = req.action == "redevelopSite" and req.siteId or nil
	if req.action == "redevelopSite" and not integer(sourceId) then
		return false, "Invalid source site"
	end
	local ok, why = Sites.canPlace(state, p, city, req.kind, req.x, req.y, nil, sourceId)
	if not ok then
		return false, why
	end
	Sites.pause(city)
	local id = state.nextSiteId or 1
	state.nextSiteId = id + 1
	city.siteProjects = city.siteProjects or {}
	local pr = {
		id = id,
		operation = sourceId and "redevelop" or "place",
		kind = req.kind,
		x = req.x,
		y = req.y,
		progress = 0,
		sourceSiteId = sourceId,
	}
	city.siteProjects[id] = pr
	city.project = { kind = "site", id = id, progress = 0, x = pr.x, y = pr.y }
	city.productionIdle = false
	return true, "Site production selected"
end
function Sites.advance(state, p, city, industry)
	local selection = city.project
	local pr = selection and (city.siteProjects or {})[selection.id]
	if not pr then
		return false
	end
	local ok = Sites.canPlace(state, p, city, pr.kind, pr.x, pr.y, pr.id, pr.sourceSiteId)
	if not ok or occupied(state, p, pr.x, pr.y, false) then
		return false
	end
	pr.progress = pr.progress + industry
	selection.progress = pr.progress
	if pr.progress < Sites.cost(p, pr) then
		return false
	end
	local original = pr.sourceSiteId and source(city, pr.sourceSiteId)
	if original then
		if original.kind ~= pr.kind then
			for id, kind in pairs(Sites.families) do
				if kind == original.kind then
					city.buildings[id] = nil
					if city.projectProgress then
						city.projectProgress["building:" .. id] = nil
					end
				end
			end
		end
		city.sites[original.kind] = nil
	end
	city.sites = city.sites or {}
	city.sites[pr.kind] = { id = pr.id, kind = pr.kind, x = pr.x, y = pr.y }
	city.siteProjects[pr.id] = nil
	city.project = nil
	return true, pr
end
function Sites.validate(state)
	if not Sites.enabled(state) then
		return
	end
	assert(
		state.specialtySchema == nil or state.specialtySchema == 1,
		"Unsupported specialty schema"
	)
	local ids, tiles, maxId = {}, {}, 0
	if state.specialtySchema == nil then
		for _, city in ipairs(state.cities or {}) do
			assert(
				not next(city.sites or {}) and not next(city.siteProjects or {}),
				"Missing specialty schema"
			)
		end
	end
	local function check(r)
		assert(
			type(r) == "table" and integer(r.id) and r.id > 0 and not ids[r.id],
			"Duplicate or invalid specialty ID"
		)
		assert(
			Sites.definitions[r.kind]
				and integer(r.x)
				and integer(r.y)
				and Hex.inBounds(r.x, r.y, state),
			"Invalid specialty record"
		)
		ids[r.id] = true
		maxId = math.max(maxId, r.id)
	end
	for _, city in ipairs(state.cities or {}) do
		assert(city.sites == nil or type(city.sites) == "table", "Invalid specialty collection")
		assert(
			city.siteProjects == nil or type(city.siteProjects) == "table",
			"Invalid specialty projects"
		)
		local kinds, sources = {}, {}
		for kind, r in pairs(city.sites or {}) do
			check(r)
			assert(kind == r.kind, "Invalid specialty kind key")
			local k = key(r.x, r.y)
			assert(not tiles[k], "Duplicate specialty hex")
			tiles[k] = r.id
			kinds[kind] = r.id
		end
		for id, r in pairs(city.siteProjects or {}) do
			check(r)
			assert(
				id == r.id and (r.operation == "place" or r.operation == "redevelop"),
				"Invalid specialty project key/operation"
			)
			assert(
				type(r.progress) == "number"
					and r.progress == r.progress
					and r.progress >= 0
					and r.progress < math.huge,
				"Invalid specialty progress"
			)
			assert(
				r.operation ~= "place" or r.sourceSiteId == nil,
				"Unexpected redevelopment source"
			)
			local original = r.sourceSiteId and source(city, r.sourceSiteId)
			assert(
				(r.operation == "redevelop") == (original ~= nil),
				"Invalid redevelopment source"
			)
			if original then
				assert(not sources[original.id], "Duplicate redevelopment source")
				sources[original.id] = true
				assert(
					original.kind ~= r.kind or original.x ~= r.x or original.y ~= r.y,
					"Unchanged redevelopment"
				)
			end
			assert(
				not kinds[r.kind] or original and kinds[r.kind] == original.id,
				"Duplicate specialty kind"
			)
			kinds[r.kind] = r.id
			local k = key(r.x, r.y)
			assert(not tiles[k] or original and tiles[k] == original.id, "Duplicate specialty hex")
			tiles[k] = r.id
		end
		if city.project and city.project.kind == "site" then
			local r = (city.siteProjects or {})[city.project.id]
			assert(r and city.project.progress == r.progress, "Invalid active specialty projection")
		end
	end
	assert(
		state.nextSiteId == nil and maxId == 0
			or integer(state.nextSiteId) and state.nextSiteId > maxId,
		"Invalid next specialty ID"
	)
	state.specialtySchema = 1
	state.nextSiteId = state.nextSiteId or 1
end
return Sites
