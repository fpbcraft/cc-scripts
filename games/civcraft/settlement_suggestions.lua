-- Advisory scoring over a player's projected, explored world view only.
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Founding = dofile("/games/civcraft/founding.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local Content = dofile("/games/civcraft/content.lua")
local Suggestions = {}
local MAX_RESULTS = 256

local function known(view, x, y)
	local key = World.key(x, y)
	return (view.world.tiles or {})[key] ~= nil
end

local function opportunity(view, player, kind, x, y)
	local function matches(point)
		if not known(view, point.x, point.y) then
			return false
		end
		local key = World.key(point.x, point.y)
		local terrain = view.world.geography and view.world.geography[key]
		local name = view.world.tiles[key]
		terrain = terrain or (name and Biomes.legacy(name))
		local resource = (view.world.resources or {})[key]
		if kind == "works" and terrain and terrain.elevation == "hill" then
			return "explored hill"
		end
		if kind == "knowledge" and terrain and terrain.elevation == "mountain" then
			return "explored mountain"
		end
		if
			kind == "freight"
			and terrain
			and (terrain.biome == "coast" or terrain.biome == "ocean")
		then
			return "explored coast or ocean"
		end
		if
			kind == "works" and (resource == "iron" or resource == "copper" or resource == "zinc")
		then
			local tech = (Content.resources[resource] or {}).tech
			return (not tech or (player.techs or {})[tech] == true) and ("revealed " .. resource)
		end
		return kind == "knowledge"
				and (resource == "redstone" or resource == "diamond")
				and ((not (Content.resources[resource] or {}).tech) or (player.techs or {})[(
					Content.resources[resource] or {}
				).tech] == true)
				and ("revealed " .. resource)
			or kind == "freight"
				and ((view.world.rails or {})[key] or (view.world.roads or {})[key])
				and "known road or rail"
	end
	local ownName = view.world.tiles[World.key(x, y)]
	local own = view.world.geography and view.world.geography[World.key(x, y)]
	local tile = own or (ownName and Biomes.legacy(ownName))
	if tile and kind == "works" and tile.elevation == "hill" then
		return "explored city-site hill"
	end
	for _, point in ipairs(Hex.neighbours(x, y, view)) do
		local evidence = matches(point)
		if evidence then
			return evidence
		end
	end
	local key = World.key(x, y)
	local resource = (view.world.resources or {})[key]
	if kind == "knowledge" and (resource == "redstone" or resource == "diamond") then
		local tech = (Content.resources[resource] or {}).tech
		return (not tech or (player.techs or {})[tech] == true) and ("revealed " .. resource)
	end
	if kind == "freight" then
		return ((view.world.rails or {})[key] == true or (view.world.roads or {})[key] == true)
			and "known road or rail"
	end
	return false
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
				if legal then
					local yields = World.yields(view.world, x, y, view)
					local spacing = math.huge
					for _, city in ipairs(view.cities or {}) do
						spacing = math.min(spacing, Hex.distance(x, y, city.x, city.y, view))
					end
					if spacing == math.huge then
						spacing = 0
					end
					local water = false
					for _, point in ipairs(Hex.neighbours(x, y, view)) do
						if
							known(view, point.x, point.y)
							and Hex.terrain(point.x, point.y, view) == "water"
						then
							water = true
							break
						end
					end
					local resources = {}
					for _, point in ipairs(Hex.neighbours(x, y, view)) do
						local resource = (view.world.resources or {})[World.key(point.x, point.y)]
						if resource then
							resources[#resources + 1] = resource
						end
					end
					table.sort(resources)
					local future, reasons =
						{}, {
							"Food yield: " .. yields.food,
							"Industry yield: " .. yields.industry,
							water and "Adjacent explored water adds 1 city capacity" or "No adjacent explored water capacity bonus",
							spacing == 0 and "No known cities affect spacing" or "Nearest known city is " .. spacing .. " hexes away",
						}
					for _, resource in ipairs(resources) do
						reasons[#reasons + 1] = "Adjacent explored resource: " .. resource
					end
					if Sites.enabled(view) then
						for _, kind in ipairs(Sites.order) do
							local evidence = opportunity(view, player, kind, x, y)
							if evidence then
								local definition = Sites.definitions[kind]
								future[#future + 1] = {
									kind = kind,
									name = definition.name,
									output = definition.output,
									tech = definition.tech,
									evidence = evidence,
									conditional = true,
								}
								reasons[#reasons + 1] = definition.name
									.. " may be a future opportunity ("
									.. evidence
									.. "); eligibility and placement are not guaranteed"
							end
						end
					end
					local score = yields.food * 2
						+ yields.industry
						+ (water and 1 or 0)
						+ math.min(#resources, 3)
					found[#found + 1] = {
						x = x,
						y = y,
						score = score,
						reasons = reasons,
						incompleteKnowledge = true,
						capacity = {
							base = 4,
							waterBonus = water and 1 or 0,
							observedMinimum = 4 + (water and 1 or 0),
						},
						resources = resources,
						specialties = future,
						knowledgeNote = "Uses explored observations only; values may be incomplete or remembered.",
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
	while #found > limit do
		found[#found] = nil
	end
	return found
end

return Suggestions
