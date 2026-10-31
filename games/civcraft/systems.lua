local Sites = dofile("/games/civcraft/specialty_sites.lua")
-- CIVCRAFT 4X data & deterministic mechanics, no dependencies on UI/peripherals.
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Queue = dofile("/games/civcraft/queued_routes.lua")
local CouncilRules = dofile("/games/civcraft/council_rules.lua")
local M = {}
local CampaignRules = dofile("/games/civcraft/campaign_rules.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local DiplomaticOffers = dofile("/games/civcraft/diplomatic_offers.lua")
local AI = dofile("/games/civcraft/ai.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local Content = dofile("/games/civcraft/content.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local ResourceStock = dofile("/games/civcraft/resource_stock.lua")
local Capacity = dofile("/games/civcraft/settlement_capacity.lua")
local Projects = dofile("/games/civcraft/civilian_projects.lua")
local Economy = dofile("/games/civcraft/economy.lua")
local Events = dofile("/games/civcraft/events.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Rails = dofile("/games/civcraft/railways.lua")
local World = dofile("/games/civcraft/world.lua")
M.civs = Content.civs
M.techs = Content.techs
M.techOrder = Content.techOrder
M.units = Content.units
M.buildings = Content.buildings
M.projects = Projects.definitions
M.canProject = Projects.available
M.ages = Content.ages
M.resources = Content.resources
M.resourceOrder = Content.resourceOrder
M.wonders = Content.wonders
M.naturalWonders = Content.naturalWonders
M.jobs = { "food", "wood", "science" }
M.exchange = Economy.exchange
function M.territoryCity(state, x, y)
	return World.territoryCity(state, Hex, x, y)
end
function M.age(p)
	local age = 1
	for i, a in ipairs(Content.ages) do
		if (p.techs or {})[a.milestone] then
			age = math.max(age, i)
		end
	end
	return age
end
function M.label(kind, id)
	local source = kind == "unit" and M.units
		or kind == "wonder" and M.wonders
		or kind == "tech" and M.techs
		or kind == "project" and M.projects
		or M.buildings
	return (source[id] or {}).name or tostring(id):upper()
end
function M.workable(state, city)
	local tiles = {}
	if not state.world or not city then
		return tiles
	end
	for _, position in ipairs(Hex.withinRadius(city.x, city.y, 3, state)) do
		local xx, yy = position.x, position.y
		if
			not (xx == city.x and yy == city.y)
			and World.terrain(state.world, xx, yy) ~= "mountain"
			and World.territoryCity(state, Hex, xx, yy) == city
		then
			local yield = World.yields(state.world, xx, yy, state)
			tiles[#tiles + 1] = { x = xx, y = yy, key = World.key(xx, yy), yield = yield }
		end
	end
	table.sort(tiles, function(a, b)
		local aa = a.yield.food + a.yield.industry + a.yield.science * 2
		local bb = b.yield.food + b.yield.industry + b.yield.science * 2
		if aa ~= bb then
			return aa > bb
		end
		return a.y == b.y and a.x < b.x or a.y < b.y
	end)
	return tiles
end
function M.tileJob(tile)
	local y = tile.yield
	if y.science > 0 and y.science >= y.food and y.science >= y.industry then
		return "science"
	end
	if y.industry > y.food then
		return "wood"
	end
	return "food"
end
local function workerSelection(state, city, readOnly, tiles)
	tiles = tiles or M.workable(state, city)
	local had = city.worked ~= nil
	local worked = city.worked or {}
	if readOnly then
		local copy = {}
		for key, value in pairs(worked) do
			copy[key] = value
		end
		worked = copy
	end
	local available = {}
	for _, t in ipairs(tiles) do
		available[t.key] = t
	end
	local keys = {}
	for k in pairs(worked) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local count = 0
	for _, k in ipairs(keys) do
		if not available[k] or count >= (city.population or 2) then
			worked[k] = nil
		else
			count = count + 1
		end
	end
	if not had then
		for _, tile in ipairs(tiles) do
			if count >= (city.population or 2) then
				break
			end
			worked[tile.key] = true
			count = count + 1
		end
	end
	local jobs = { food = 0, wood = 0, science = 0 }
	for _, tile in ipairs(tiles) do
		if worked[tile.key] then
			local job = M.tileJob(tile)
			jobs[job] = jobs[job] + 1
		end
	end
	return worked, jobs
end
function M.ensureWorkers(state, city, tiles)
	if not state.world or not city then
		return
	end
	city.worked, city.jobs = workerSelection(state, city, false, tiles)
end
function M.workTile(state, city, x, y)
	if not city or not state.world or not Hex.inBounds(x, y, state) then
		return false, "Invalid city or hex"
	end
	M.ensureWorkers(state, city)
	local k = World.key(x, y)
	local allowed = false
	for _, tile in ipairs(M.workable(state, city)) do
		if tile.key == k then
			allowed = true
			break
		end
	end
	if not allowed then
		return false, "Hex is outside this city's workable land"
	end
	if city.worked[k] then
		city.worked[k] = nil
	elseif M.idle(city) > 0 then
		city.worked[k] = true
	else
		return false, "No idle population; unwork a hex first"
	end
	M.ensureWorkers(state, city)
	return true
end
function M.civ(id, context)
	for _, v in ipairs(M.civs) do
		if v.id == id then
			if id == "scholar" and ContentRules.usesP1Economy(context) then
				return { id = v.id, name = v.name, bonus = "Capital +1 science" }
			end
			return v
		end
	end
	return M.civs[1]
end
function M.nameCity(state, city)
	if city.name and city.name ~= "" then
		return city.name
	end
	local civ = "verdant"
	for _, p in ipairs(state.players or {}) do
		if p.id == city.owner then
			civ = p.civ or civ
			break
		end
	end
	local pool = Content.cityNames[civ] or Content.cityNames.verdant
	local used = {}
	for _, c in ipairs(state.cities or {}) do
		if c.name then
			used[c.name:upper()] = true
		end
	end
	-- Campaign-seeded randomness keeps host/client migrations reproducible.
	local seed = (state.world and state.world.seed or state.mapSeed or 1) % 2147483647
	seed = (seed * 48271 + (city.id or 0) * 997 + (city.x or 0) * 131 + (city.y or 0) * 71)
		% 2147483647
	local start = seed % #pool
	for i = 0, #pool - 1 do
		local name = pool[(start + i) % #pool + 1]
		if not used[name] then
			city.name = name
			return name
		end
	end
	local base = pool[start + 1]
	local suffix = 2
	while true do
		local tail = tostring(suffix)
		local name = base:sub(1, 8 - #tail) .. tail
		if not used[name] then
			city.name = name
			return name
		end
		suffix = suffix + 1
	end
end
function M.migrate(state)
	assert(type(state) == "table", "Invalid campaign save; delete/reset this save to continue")
	local currentRules, rulesReason = ContentRules.migrateId(state.contentRules)
	assert(currentRules, tostring(rulesReason) .. ". Delete/reset this save to continue.")
	assert(
		type(state.players or {}) == "table",
		"Invalid players; delete/reset this save to continue"
	)
	assert(
		type(state.cities or {}) == "table",
		"Invalid cities; delete/reset this save to continue"
	)
	assert(type(state.units or {}) == "table", "Invalid units; delete/reset this save to continue")
	for _, player in ipairs(state.players or {}) do
		if player.stockpile ~= nil then
			local valid, reason = ResourceStock.validate(player.stockpile)
			assert(valid, tostring(reason) .. ". Delete/reset this save to continue.")
		end
	end
	state.contentRules = currentRules
	assert(
		state.ruleset == nil or state.ruleset == "legacy" or state.ruleset == "create",
		"Unsupported ruleset; delete/reset this save to continue"
	)
	state.ruleset = "create"
	state.gameSpeed = state.gameSpeed or "standard"
	state.roundLimit = CampaignRules.rounds(state)
	state.hostileMode = state.hostileMode or (state.ruleset == "create" and "standard" or "off")
	if state.world then
		state.world.landmarks = state.world.landmarks or {}
		state.world.rails = state.world.rails or {}
	end
	World.ensureTerritories(state, Hex, (state.version or 0) < 5)
	for i, p in ipairs(state.players or {}) do
		p.contentRules = state.contentRules
		p.civ = p.civ or M.civs[(i - 1) % #M.civs + 1].id
		p.techs = p.techs or {}
		if p.settlersTrained == nil then
			local cities, settlers = 0, 0
			for _, c in ipairs(state.cities or {}) do
				if c.owner == p.id then
					cities = cities + 1
				end
			end
			for _, u in ipairs(state.units or {}) do
				if
					u.owner == p.id
					and u.kind == "settler"
					and not (ContentRules.startsWithSettler(state) and u.initialSettler)
				then
					settlers = settlers + 1
				end
			end
			p.settlersTrained = math.max(0, cities - 1) + settlers
		end
		if ContentRules.startsWithSettler(state) and p.capitalFounded == nil then
			p.capitalFounded = false
			for _, city in ipairs(state.cities or {}) do
				if city.capitalOf == p.id then
					p.capitalFounded = true
					break
				end
			end
		end
		p.ai = p.ai or false
		p.explored = p.explored or {}
		if not p.knownLandmarks then
			p.knownLandmarks = {}
			for tileKey in pairs(state.world and state.world.landmarks or {}) do
				if p.explored[tileKey] and state.world.landmarks[tileKey].natural then
					p.knownLandmarks[tileKey] = true
				end
			end
		end
		p.gameSpeed = state.gameSpeed
		p.food = p.food or 0
		p.wood = p.wood or 0
		p.science = p.science or 0
		p.gold = p.gold or 20
		p.researchProgress = p.researchProgress or {}
		local migrated, reason = ResourceStock.migrate(p.stockpile or {})
		assert(migrated, tostring(reason) .. ". Delete/reset this save to continue.")
		p.stockpile = migrated
	end
	for _, c in ipairs(state.cities or {}) do
		M.nameCity(state, c)
		c.population = c.population or 2
		c.foodStore = c.foodStore or 0
		c.growthAge = c.growthAge or 0
		c.hungryTurns = c.hungryTurns or 0
		c.jobs = c.jobs or { food = 1, wood = 1, science = 0 }
		c.buildings = c.buildings or {}
		c.projectProgress = c.projectProgress or {}
		M.ensureWorkers(state, c)
	end
	for _, u in ipairs(state.units or {}) do
		local stats = M.units[u.kind] or M.units.warrior
		if u.movesLeft == nil then
			u.movesLeft = u.moved and 0 or stats.move
		end
	end
	Combat.migrate(state)
	Stacks.migrate(state)
	Queue.migrate(state)
	Sites.validate(state)
	state.version = 6
	state.resourceSchema = 1
	return state
end
function M.canResearch(p, id)
	local t = M.techs[id]
	if not t or p.techs[id] then
		return false
	end
	for _, req in ipairs(t.requires) do
		if not p.techs[req] then
			return false
		end
	end
	return true
end
-- Research selects a project. Science arrives at the global turn boundary.
function M.research(p, id)
	if not M.canResearch(p, id) then
		return false, "Technology prerequisites unmet"
	end
	p.researchTarget = id
	p.researchProgress = p.researchProgress or {}
	p.researchProgress[id] = p.researchProgress[id] or 0
	return true
end
function M.coastal(state, c)
	if not state or not state.world then
		return false
	end
	for _, n in ipairs(Hex.neighbours(c.x, c.y, state)) do
		if Hex.terrain(n.x, n.y, state) == "water" then
			return true
		end
	end
	return false
end
function M.treasury(p, state, includeProjects)
	local income, upkeep = 0, 0
	for _, other in ipairs(state.players or {}) do
		if
			other.id ~= p.id
			and not CouncilRules.embargoed(state, p.id, other.id)
			and DiplomaticOffers.treaty(state, p.id, other.id, "commerce")
		then
			income = income + 2 + CouncilRules.commerceBonus(state)
		end
	end
	for _, city in ipairs(state.cities or {}) do
		if city.owner == p.id then
			local effects = Economy.effects(city, state, M)
			income = income + 2 + (city.population or 2) + effects.gold
			-- Gold on worked coast/resource hexes enters the treasury once per turn.
			income = income + M.yields(p, city, state, Hex, nil, true).gold
			if
				includeProjects ~= false
				and ContentRules.usesP1Economy(p)
				and city.project
				and city.project.kind == "project"
			then
				income = income + M.projectOutput(p, city, state).gold
			end
		end
	end
	for _, unit in ipairs(state.units or {}) do
		if unit.owner == p.id then
			upkeep = upkeep + ((M.units[unit.kind] or {}).upkeep or 1)
		end
	end
	return { income = income, upkeep = upkeep, net = income - upkeep }
end
function M.economy(p, state)
	local result = M.treasury(p, state)
	result.food = 0
	result.industry = 0
	result.science = 0
	result.strategic = { iron = 0, horses = 0, saltpeter = 0 }
	for _, city in ipairs(state.cities or {}) do
		if city.owner == p.id then
			local y = M.yields(p, city, state, Hex)
			result.food = result.food + y.food - 2 * (city.population or 2)
			result.industry = result.industry + y.industry
			result.science = result.science + y.science
		end
	end
	local owned = World.territory(state, Hex)
	result.strategic = Economy.rates(p, state, owned)
	return result
end
function M.canBuild(p, c, id, state)
	if ContentRules.isRedesign(state or p) and id == "councilhall" then
		return false
	end
	local b = M.buildings[id]
	if b and not ContentRules.available(b, state or p) then
		return false
	end
	if
		not b
		or b.tech and not p.techs[b.tech] and not (id == "farm" and ContentRules.usesP1Economy(p))
		or c.buildings[id]
		or b.coastal and not M.coastal(state, c)
	then
		return false
	end
	if Sites.enabled(state or p) then
		local family = Sites.families[id]
		if
			family and (not (c.sites or {})[family] or not Sites.active(state, c, c.sites[family]))
		then
			return false
		end
	end
	for _, need in ipairs(Sites.prerequisites(state or p, id)) do
		if not Sites.effectiveBuilding(state or p, c, need) then
			return false
		end
	end
	return true
end
function M.canRecruit(p, id, state, hex, city)
	local u = M.units[id]
	if
		not u
		or u.hostile
		or not ContentRules.available(u, state or p)
		or (u.tech and not p.techs[u.tech])
	then
		return false
	end
	if
		id == "settler"
		and ContentRules.hasDevelopment(state or p)
		and (not city or (city.population or 2) < 2)
	then
		return false
	end
	if u.unique and p.civ ~= u.unique then
		return false
	end
	if
		u.building
		and (
			not city
			or not Sites.effectiveBuilding(state or p, city, u.building)
			or u.naval and not M.coastal(state, city)
		)
	then
		return false
	end
	if state and (p.gold or 20) <= 0 and M.treasury(p, state).net < (u.upkeep or 1) then
		return false
	end
	if
		u.resource
		and ((p.stockpile or {})[u.resource] or 0) < 2
		and (not state or not hex or not World.strategic(state, p, hex, u.resource))
	then
		return false
	end
	return true
end
-- Retain familiar action names as pure queue selection (no purchases).
function M.queue(p, c, kind, id, state, hex, x, y)
	if kind == "none" then
		Sites.pause(c)
		if c.project and c.project.kind ~= "project" and c.project.kind ~= "site" then
			c.projectProgress = c.projectProgress or {}
			c.projectProgress[c.project.kind .. ":" .. c.project.id] = c.project.progress
		end
		c.project = nil
		c.productionIdle = true
		return true
	end
	if kind == "wonder" then
		if not Landmarks.canPlace(state, c, id, x, y, M) then
			return false, "Wonder needs its research and an empty owned land hex; one per world"
		end
	elseif kind == "building" then
		if not M.canBuild(p, c, id, state) then
			return false, "Building locked or already completed"
		end
	elseif kind == "unit" then
		if not M.canRecruit(p, id, state, hex, c) then
			if
				id == "settler"
				and ContentRules.hasDevelopment(state or p)
				and (c.population or 2) < 2
			then
				return false,
					"Settlers require at least two population; completion consumes one citizen"
			end
			return false, "Unit locked or missing strategic resource"
		end
	elseif kind == "project" then
		if not M.canProject(p, c, id) then
			return false, "Civilian project needs its city building and P1 economy"
		end
	else
		return false, "Unknown project category"
	end
	if c.project and c.project.kind ~= "project" and c.project.kind ~= "site" then
		c.projectProgress = c.projectProgress or {}
		c.projectProgress[c.project.kind .. ":" .. c.project.id] = c.project.progress
	end
	Sites.pause(c)
	c.productionIdle = false
	c.project = {
		kind = kind,
		id = id,
		x = x,
		y = y,
		progress = (c.projectProgress or {})[kind .. ":" .. id] or 0,
	}
	return true
end
function M.build(p, c, id, state, hex)
	return M.queue(p, c, "building", id, state, hex)
end
function M.idle(c)
	local total = 0
	for _, job in ipairs(M.jobs) do
		total = total + (c.jobs[job] or 0)
	end
	return math.max(0, (c.population or 2) - total)
end
function M.assign(c, from, to, state)
	local function valid(job)
		return job == "idle" or job == "food" or job == "wood" or job == "science"
	end
	if not valid(from) or not valid(to) or from == to then
		return false, "Invalid citizen assignment"
	end
	if state and state.world then
		M.ensureWorkers(state, c)
	end
	local count = from == "idle" and M.idle(c) or (c.jobs[from] or 0)
	if count <= 0 then
		return false, from == "idle" and "No idle citizens" or "No citizens assigned to this job"
	end
	if state and state.world then
		local remove, candidates = nil, {}
		for _, tile in ipairs(M.workable(state, c)) do
			if c.worked[tile.key] and M.tileJob(tile) == from then
				remove = tile.key
			end
			if not c.worked[tile.key] and M.tileJob(tile) == to then
				candidates[#candidates + 1] = tile.key
			end
		end
		if to ~= "idle" and #candidates == 0 then
			return false, "No free owned tile of this job type"
		end
		if remove then
			c.worked[remove] = nil
		end
		if to ~= "idle" then
			local index = ((state.round or 1) * 31 + c.x * 17 + c.y * 13 + count) % #candidates + 1
			c.worked[candidates[index]] = true
		end
		M.ensureWorkers(state, c)
		return true
	end
	if from ~= "idle" then
		c.jobs[from] = c.jobs[from] - 1
	end
	if to ~= "idle" then
		c.jobs[to] = (c.jobs[to] or 0) + 1
	end
	return true
end
function M.techCost(id, player)
	local tech = M.techs[id]
	return tech and CampaignRules.cost(tech.cost, player) or nil
end
function M.projectCost(kind, id, player, city)
	if kind == "site" then
		local retained = city and (city.siteProjects or {})[id]
		return retained and Sites.cost(player, retained) or nil
	end
	if kind == "project" then
		return M.projects[id] and M.projects[id].divisor or nil
	end
	local record = (kind == "unit" and M.units or kind == "wonder" and M.wonders or M.buildings)[id]
	if not record then
		return nil
	end
	local base = record.production or math.ceil((record.wood or 8) * 2.5)
	local step = record.productionStep or 0
	if kind == "unit" then
		base, step = ContentRules.unitCost(id, record, player)
	end
	if kind == "unit" and id == "settler" then
		return CampaignRules.cost(base + step * ((player and player.settlersTrained) or 0), player)
	end
	return CampaignRules.cost(base, player)
end
function M.centerYields(p, c, state)
	local e = Economy.effects(c, state, M)
	local civ = p.civ
	local buildings = c.buildings or {}
	local food, industry, science = 2 + e.food, 1 + e.industry, 1 + e.science
	if ContentRules.usesP1Economy(p) then
		science = science + 1
		if
			buildings.farm
			and not ContentRules.hasBuilders(p)
			and not (p.techs or {}).agriculture
		then
			food = food - 1
		end
	end
	if civ == "verdant" and buildings.farm and not ContentRules.hasBuilders(p) then
		food = food + 1
	end
	if civ == "iron" and buildings.mine and not ContentRules.hasBuilders(p) then
		industry = industry + 1
	end
	if civ == "scholar" then
		science = science
			+ (ContentRules.usesP1Economy(p) and (c.capitalOf == p.id and 1 or 0) or 2)
	end
	if civ == "forge" and Sites.effectiveBuilding(state or p, c, "workshop") then
		industry = industry + 2
	end
	if civ == "merchant" and buildings.market then
		food = food + 2
	end
	return { food = food, industry = industry, science = science, gold = 0 }
end
function M.yields(p, c, state, hex, owned, readOnly)
	local center = M.centerYields(p, c, state)
	local jobs = c.jobs
	local food = center.food - 1 + jobs.food * 2
	local industry = center.industry + jobs.wood * 2
	local science = center.science - 1 + jobs.science * 2
	local gold = 0
	if state and state.world then
		-- Reuse the same tile snapshot for worker selection and yield summing.
		local tiles = M.workable(state, c)
		local worked
		if readOnly then
			worked = workerSelection(state, c, true, tiles)
		else
			M.ensureWorkers(state, c, tiles)
			worked = c.worked
		end
		local center = M.centerYields(p, c, state)
		food, industry, science = center.food, center.industry, center.science
		for _, tile in ipairs(tiles) do
			if worked and worked[tile.key] then
				food = food + tile.yield.food
				industry = industry + tile.yield.industry
				science = science + tile.yield.science
				gold = gold + (tile.yield.gold or 0)
			end
		end
	end
	return { food = food, industry = industry, science = science, gold = gold }
end
-- Stable city yield entry point for UI, AI and regression tests.
function M.cityYield(state, city)
	for _, p in ipairs(state.players or {}) do
		if p.id == city.owner then
			return M.yields(p, city, state, Hex)
		end
	end
	return nil
end
local function spawn(state, p, c, id, hex)
	local stats = M.units[id]
	if not stats then
		return false
	end
	if id == "settler" and ContentRules.hasDevelopment(state) and (c.population or 2) < 2 then
		return false
	end
	local function available(x, y)
		for _, u in ipairs(state.units) do
			if u.x == x and u.y == y then
				return false
			end
		end
		return hex.passable(x, y, state, { kind = id, owner = p.id }, M)
	end
	local x, y = c.x, c.y
	if stats.naval or not available(x, y) then
		x = nil
		for _, n in ipairs(hex.neighbours(c.x, c.y, state)) do
			if available(n.x, n.y) then
				x, y = n.x, n.y
				break
			end
		end
	end
	if not x then
		return false
	end
	if stats.resource then
		p.stockpile = p.stockpile or {}
		if (p.stockpile[stats.resource] or 0) < 2 then
			return false
		end
		p.stockpile[stats.resource] = p.stockpile[stats.resource] - 2
	end
	state.units[#state.units + 1] =
		{ id = state.nextId, owner = p.id, x = x, y = y, kind = id, moved = true, movesLeft = 0 }
	if stats.builder then
		state.units[#state.units].charges = stats.charges
	end
	Events.notice(state, "spawn", state.units[#state.units])
	state.nextId = state.nextId + 1
	if id == "settler" then
		p.settlersTrained = (p.settlersTrained or 0) + 1
		if ContentRules.hasDevelopment(state) then
			c.population = c.population - 1
			c.growthAge = 0
			if state.world then
				M.ensureWorkers(state, c)
			else
				local excess = (c.jobs.food or 0)
					+ (c.jobs.wood or 0)
					+ (c.jobs.science or 0)
					- c.population
				for _, job in ipairs({ "science", "wood", "food" }) do
					local remove = math.min(math.max(0, excess), c.jobs[job] or 0)
					c.jobs[job], excess = (c.jobs[job] or 0) - remove, excess - remove
				end
			end
		end
	end
	return true
end
function M.projectOutput(p, c, state, yield)
	yield = yield or M.yields(p, c, state, Hex, nil, true)
	return Projects.preview(p, c, yield.industry, M)
end
function M.projectPreview(p, c, id, state, yield)
	yield = yield or M.yields(p, c, state, Hex, nil, true)
	return Projects.preview(p, c, yield.industry, M, id)
end
function M.tileYields(state, x, y)
	return World.yields(state.world, x, y, state)
end
function M.settlementCapacity(state, city)
	return Capacity.details(state, city, M.buildings)
end
function M.growth(p, c, state, yield)
	yield = yield or M.yields(p, c, state, Hex, nil, true)
	local surplus = yield.food - 2 * (c.population or 2) + M.projectOutput(p, c, state, yield).food
	local threshold = CampaignRules.cost(20 + 8 * (c.population or 2), p)
	local result = {
		surplus = surplus,
		threshold = threshold,
		minimumTurns = CampaignRules.cost(4, p),
		stored = c.foodStore or 0,
		foodGain = surplus,
	}
	if ContentRules.hasDevelopment(state or p) then
		result.capacitySources = M.settlementCapacity(state, c)
		result.capacity = result.capacitySources.total
		result.growthFactor = Capacity.factor(c.population or 2, result.capacity)
		result.foodGain = surplus > 0 and surplus * result.growthFactor or surplus
		result.minimumTurns = math.ceil(result.minimumTurns / result.growthFactor)
	end
	if surplus > 0 then
		result.status = "GROWING"
		result.turns = math.max(
			1,
			result.minimumTurns - (c.growthAge or 0),
			math.ceil((threshold - result.stored) / result.foodGain)
		)
	elseif surplus == 0 then
		result.status = "STAGNANT"
	else
		result.status = "STARVING"
		result.canShrink = (c.population or 2) > 1
		result.turns = math.max(3 - (c.hungryTurns or 0), math.ceil(result.stored / -surplus), 1)
	end
	return result
end
function M.autoExplore(state, unit, hex)
	if unit.kind ~= "scout" and unit.kind ~= "explorer" then
		return false, "Only scouts and explorers can auto explore"
	end
	local player
	for _, p in ipairs(state.players) do
		if p.id == unit.owner then
			player = p
		end
	end
	if not player or not state.world then
		return false, "No world to explore"
	end
	if player.ai and DiplomaticOffers.withdrawing(state, player.id) then
		return false, "Withdrawal orders take priority over exploration"
	end
	unit.autoExplore = true
	for _, member in ipairs({ unit, Stacks.partner(state, unit) }) do
		member.standby, member.healing, member.skippedTurn = false, false, nil
	end
	local steps = 0
	while (unit.movesLeft or 0) > 0 and not unit.moved do
		steps = steps + 1
		if steps > 64 then
			unit.autoExplore = false
			return false, "Exploration turn exceeded its movement safety limit"
		end
		local companion = Stacks.partner(state, unit)
		if companion and (companion.moved or (companion.movesLeft or 0) <= 0) then
			break
		end
		World.reveal(state, hex, M)
		local scout = {}
		for k, v in pairs(unit) do
			scout[k] = v
		end
		scout.movesLeft = state.world.width * state.world.height * 3
		scout.moved = false
		local best, bestScore
		local vision = (M.units[unit.kind] or M.units.scout).vision
		local choices, routeTo = hex.reachable(state, scout, unit.owner, M, { deferPaths = true })
		for _, choice in ipairs(choices) do
			if not choice.attack then
				local discoveries = 0
				for _, position in ipairs(hex.withinRadius(choice.x, choice.y, vision, state)) do
					if not (player.explored or {})[World.key(position.x, position.y)] then
						discoveries = discoveries + 1
					end
				end
				local score = discoveries / (choice.cost + 1)
				if discoveries > 0 and (not bestScore or score > bestScore) then
					best = choice
					bestScore = score
				end
				if M.checkpoint then
					M.checkpoint()
				end
			end
		end
		if not best then
			unit.autoExplore = false
			return true, "No safe unexplored frontier remains"
		end
		if routeTo then
			best.path = routeTo(best.x, best.y)
		end
		local spent = 0
		local destination
		for i = 2, #best.path do
			local point = best.path[i]
			local cost = hex.moveCost(
				point.x,
				point.y,
				state,
				unit,
				M,
				best.path[i - 1].x,
				best.path[i - 1].y,
				unit.movesLeft - spent
			)
			if not cost or spent + cost > unit.movesLeft then
				break
			end
			spent = spent + cost
			destination = point
		end
		if not destination then
			unit.movesLeft = 0
			unit.moved = true
			break
		end
		local previousX, previousY, previousMoves = unit.x, unit.y, unit.movesLeft
		unit.executingAutoExplore = true
		local request = {
			action = "move",
			unitID = unit.id,
			sx = unit.x,
			sy = unit.y,
			x = destination.x,
			y = destination.y,
		}
		local completed, ok = pcall(Actions.apply, state, unit.owner, request, M)
		unit.executingAutoExplore = nil
		if not completed then
			error(ok, 0)
		end
		if not ok then
			unit.autoExplore = false
			return false, "Exploration route blocked"
		end
		if unit.x == previousX and unit.y == previousY and unit.movesLeft == previousMoves then
			unit.autoExplore = false
			return false, "Exploration order made no progress"
		end
		unit.autoExplore = true
	end
	World.reveal(state, hex, M)
	return true
end
function M.production(state, hex)
	local owned = state.world and hex and World.territory(state, hex) or {}
	for _, p in ipairs(state.players) do
		if M.checkpoint then
			M.checkpoint()
		end
		p.researchProgress = p.researchProgress or {}
		Economy.stocks(p)
		local rates = Economy.rates(p, state, owned)
		for id, rate in pairs(rates) do
			p.stockpile[id] = p.stockpile[id] + rate
		end
		local totalScience, projectGold = 0, 0
		for _, c in ipairs(state.cities) do
			if c.owner == p.id then
				if M.checkpoint then
					M.checkpoint()
				end
				local yield = M.yields(p, c, state, hex, owned)
				local output = M.projectOutput(p, c, state, yield)
				totalScience = totalScience + yield.science + output.science
				projectGold = projectGold + output.gold
				p.food = math.max(0, (p.food or 0) + yield.food - 2 * (c.population or 2))
				p.wood = (p.wood or 0) + yield.industry
				local growth = M.growth(p, c, state, yield)
				Projects.commit(c, output)
				c.growthAge = (c.growthAge or 0) + 1
				c.foodStore = math.max(0, (c.foodStore or 0) + growth.foodGain)
				if growth.surplus < 0 then
					c.hungryTurns = (c.hungryTurns or 0) + 1
					if c.foodStore <= 0 and c.hungryTurns >= 3 and c.population > 1 then
						c.population = c.population - 1
						c.hungryTurns = 0
						c.growthAge = 0
						M.ensureWorkers(state, c)
					end
				else
					c.hungryTurns = 0
					if
						growth.surplus > 0
						and c.foodStore >= growth.threshold
						and c.growthAge >= growth.minimumTurns
					then
						c.foodStore = c.foodStore - growth.threshold
						c.population = c.population + 1
						c.growthAge = 0
						if state.world then
							for _, tile in ipairs(M.workable(state, c)) do
								if not c.worked[tile.key] then
									c.worked[tile.key] = true
									break
								end
							end
							M.ensureWorkers(state, c)
						else
							c.jobs.food = c.jobs.food + 1
						end
					end
				end
				if state.world then
					World.expandCity(state, hex, c)
				end
				if c.project and c.project.kind == "site" then
					local complete, record = Sites.advance(state, p, c, yield.industry)
					if complete then
						Events.site(state, c, record)
					end
				end
				if c.project and c.project.kind ~= "project" and c.project.kind ~= "site" then
					local pr = c.project
					local valid = pr.kind == "wonder"
							and Landmarks.canPlace(state, c, pr.id, pr.x, pr.y, M)
						or pr.kind == "building" and M.canBuild(p, c, pr.id, state)
						or pr.kind == "unit" and M.canRecruit(p, pr.id, state, hex, c)
					if valid then
						pr.progress = pr.progress + yield.industry
						local cost = M.projectCost(pr.kind, pr.id, p)
						if pr.progress >= cost then
							local completed
							if pr.kind == "wonder" then
								completed = Landmarks.complete(state, c, pr, M)
							elseif pr.kind == "building" then
								c.buildings[pr.id] = true
								Combat.city(c)
								completed = true
							else
								completed = spawn(state, p, c, pr.id, hex)
							end
							if completed then
								if pr.kind ~= "unit" then
									local target = c
									if pr.kind == "wonder" then
										target = { x = pr.x, y = pr.y, owner = c.owner }
									end
									Events.notice(state, pr.kind, target, pr.id)
								end
								c.project = nil
								c.projectProgress = c.projectProgress or {}
								c.projectProgress[pr.kind .. ":" .. pr.id] = nil
							end
						end
					end
					if c.project then
						c.projectProgress = c.projectProgress or {}
						c.projectProgress[pr.kind .. ":" .. pr.id] = pr.progress
					end
				end
			end
		end
		local treasury = M.treasury(p, state, false)
		p.gold = (p.gold or 20) + treasury.net + projectGold
		if p.gold < 0 then
			for index = #state.units, 1, -1 do
				local unit = state.units[index]
				if unit.owner == p.id then
					p.gold = p.gold + ((M.units[unit.kind] or {}).upkeep or 1)
					Events.notice(state, "disband", unit)
					Stacks.unlink(state, unit)
					table.remove(state.units, index)
					if p.gold >= 0 then
						break
					end
				end
			end
			p.gold = math.max(0, p.gold)
		end
		p.scienceRate = totalScience
		p.science = (p.science or 0) + totalScience
		local id = p.researchTarget
		if id and M.canResearch(p, id) then
			local progress = (p.researchProgress[id] or 0) + totalScience
			p.researchProgress[id] = progress
			if progress >= M.techCost(id, p) then
				p.techs[id] = true
				p.researchTarget = nil
				Events.notice(state, "research", nil, id, p.id)
			end
		end
	end
end
-- AI plays by the same research and production queue rules as humans.
function M.diplomaticResponses(state, p)
	AI.respond(state, p, M)
end

function M.aiTurn(state, p, hex)
	if not Scheduler.canAct(state, p.id) then
		return
	end
	AI.beginTurn(state, p, M)
	AI.withdraw(state, p, M)
	AI.diplomacy(state, p, M)
	AI.materials(state, p, M)
	for _, city in ipairs(state.cities) do
		if city.owner == p.id then
			AI.staff(state, p, city, M)
		end
	end
	if not p.researchTarget then
		local id = AI.research(p, M, AI.knowledge(state, p))
		if id then
			Actions.apply(state, p.id, { action = "researchTech", id = id }, M)
		end
	end
	for _, city in ipairs(state.cities) do
		if city.owner == p.id then
			AI.strike(state, p, city, M)
			AI.choose(state, p, city, M)
		end
	end
	local orders = {}
	for _, unit in ipairs(state.units) do
		if unit.owner == p.id then
			orders[#orders + 1] = unit
		end
	end
	local priority = {
		settler = 0,
		scout = 1,
		siege = 2,
		ranged = 3,
		mainArmy = 4,
		screening = 4,
		naval = 4,
		settlerEscort = 4,
		healer = 5,
		engineer = 6,
		garrison = 7,
	}
	table.sort(orders, function(a, b)
		local aa = priority[(a.aiRole or {}).name] or 4
		local bb = priority[(b.aiRole or {}).name] or 4
		if aa ~= bb then
			return aa < bb
		end
		return a.id < b.id
	end)
	for _, unit in ipairs(orders) do
		local present = false
		for _, current in ipairs(state.units) do
			if current == unit then
				present = true
				break
			end
		end
		if present and not unit.moved then
			if unit.kind == "settler" then
				AI.settle(state, p, unit, M)
			elseif (M.units[unit.kind] or {}).builder then
				AI.builder(state, p, unit, M)
			elseif (M.units[unit.kind] or {}).engineer then
				AI.engineer(state, p, unit, M)
			else
				AI.military(state, p, unit, M)
			end
		end
	end
	Scheduler.finish(state, p.id)
end
return M
