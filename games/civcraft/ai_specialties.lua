-- Specialty investment uses the same observed placement and production rules as players.
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Values = dofile("/games/civcraft/ai_economy_values.lua")
local Specialties = {}
local roles = { works = "industry", knowledge = "science", freight = "commerce" }

local function safe(view, player, x, y, systems)
	for _, unit in ipairs(view.units or {}) do
		if unit.owner ~= player.id and Diplomacy.canAttack(view, player.id, unit.owner) then
			local stats = systems.units[unit.kind] or {}
			if Hex.distance(x, y, unit.x, unit.y) <= math.max(2, stats.range or 0) then
				return false
			end
		end
	end
	for _, city in ipairs(view.cities or {}) do
		if
			city.owner ~= player.id
			and Diplomacy.canAttack(view, player.id, city.owner)
			and Hex.distance(x, y, city.x, city.y) <= 2
		then
			return false
		end
	end
	return true
end

local function sitesInRange(view, player, city, kind, systems, project, original)
	local result = {}
	for y = math.max(1, city.y - 3), math.min(view.world.height, city.y + 3) do
		for x = math.max(1, city.x - 3), math.min(view.world.width, city.x + 3) do
			if
				Sites.canPlace(view, player, city, kind, x, y, project, original)
				and safe(view, player, x, y, systems)
			then
				result[#result + 1] =
					{ x = x, y = y, bonus = Sites.bonus(view, player, kind, x, y) }
			end
		end
	end
	return result
end

function Specialties.roles(view, player, systems)
	local result = {}
	for _, city in ipairs(view.cities or {}) do
		if city.owner == player.id then
			local best, score
			for _, kind in ipairs(Sites.order) do
				local value = 0
				for _, tile in ipairs(sitesInRange(view, player, city, kind, systems)) do
					value = math.max(value, tile.bonus * 4 + 1)
				end
				if (city.sites or {})[kind] then
					value = value + 8
				end
				for _, project in pairs(city.siteProjects or {}) do
					if project.kind == kind then
						value = value + 8
					end
				end
				for id, built in pairs(city.buildings or {}) do
					if built and Sites.families[id] == kind then
						value = value + 2
					end
				end
				if not score or value > score then
					best, score = kind, value
				end
			end
			result[city.id] = roles[best]
		end
	end
	return result
end

local function value(view, player, city, kind, bonus, context, systems)
	local output = Sites.definitions[kind].output
	local result = (1 + bonus) * context[output] * 18
	-- An available first family upgrade gives the placement a concrete next use.
	local upgrade = 0
	for id, family in pairs(Sites.families) do
		local building = systems.buildings[id]
		local prerequisites = true
		for _, need in ipairs(Sites.prerequisites(view, id)) do
			if not Sites.effectiveBuilding(view, city, need) then
				prerequisites = false
			end
		end
		if
			family == kind
			and not (city.buildings or {})[id]
			and (not building.tech or player.techs[building.tech])
			and prerequisites
		then
			upgrade = math.max(upgrade, Values.effects(building.effects, context) * 5)
		end
	end
	return result + math.min(60, upgrade)
end

function Specialties.ranked(view, player, city, systems, context)
	if not Sites.enabled(view) then
		return {}
	end
	local result = {}
	local function add(kind, x, y, request, id, cost, progress, bonus)
		local turns =
			math.max(1, math.ceil((cost - (progress or 0)) / math.max(1, context.yields.industry)))
		result[#result + 1] = {
			kind = "site",
			id = id,
			siteKind = kind,
			tileX = x,
			tileY = y,
			request = request,
			turns = turns,
			score = value(view, player, city, kind, bonus, context, systems) / (2 + turns),
		}
	end
	local projects = {}
	for id in pairs(city.siteProjects or {}) do
		projects[#projects + 1] = id
	end
	table.sort(projects)
	for _, id in ipairs(projects) do
		local project = city.siteProjects[id]
		if
			Sites.canPlace(
				view,
				player,
				city,
				project.kind,
				project.x,
				project.y,
				id,
				project.sourceSiteId
			) and safe(view, player, project.x, project.y, systems)
		then
			add(
				project.kind,
				project.x,
				project.y,
				{ action = "resumeSite", city = city.id, projectId = id },
				id,
				Sites.cost(player, project),
				project.progress,
				Sites.bonus(view, player, project.kind, project.x, project.y)
			)
		end
	end
	for order, kind in ipairs(Sites.order) do
		local existing = (city.sites or {})[kind]
		local inactive = existing and not Sites.active(view, city, existing)
		-- Only restore inactive sites. Active investments never churn for a small adjacency gain.
		if not existing or inactive then
			for _, tile in
				ipairs(
					sitesInRange(view, player, city, kind, systems, nil, inactive and existing.id)
				)
			do
				local request = {
					action = inactive and "redevelopSite" or "placeSite",
					city = city.id,
					kind = kind,
					x = tile.x,
					y = tile.y,
					siteId = inactive and existing.id or nil,
				}
				local cost = Sites.cost(player, { sourceSiteId = request.siteId })
				add(
					kind,
					tile.x,
					tile.y,
					request,
					"new:" .. order .. ":" .. tile.y .. ":" .. tile.x,
					cost,
					0,
					tile.bonus
				)
			end
		end
	end
	return result
end

return Specialties
