local Sites = dofile("/games/civcraft/specialty_sites.lua")
-- Charge-based land development. No hidden routing or alternate economy model.
local Rules = dofile("/games/civcraft/content_rules.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Works = {
	order = { "farm", "quarry", "lumber" },
	definitions = {
		farm = { name = "WHEAT FIELD", tech = "agriculture", food = 2, industry = 0 },
		quarry = { name = "QUARRY", tech = "mining", food = 0, industry = 2 },
		lumber = { name = "LUMBER CAMP", tech = "crafting", food = 0, industry = 1 },
	},
}
function Works.bonus(world, x, y)
	local record = world and (world.improvements or {})[x .. ":" .. y]
	local definition = record
		and not record.damaged
		and not (world.landmarks or {})[x .. ":" .. y]
		and Works.definitions[record.kind]
	return definition and definition.food or 0, definition and definition.industry or 0
end
function Works.canPlace(state, player, kind, x, y, systems)
	local definition = Works.definitions[kind]
	if not Rules.hasBuilders(state) or not state.world or not definition then
		return false, "Tile development is unavailable"
	end
	if
		type(x) ~= "number"
		or type(y) ~= "number"
		or x % 1 ~= 0
		or y % 1 ~= 0
		or not Hex.inBounds(x, y, state)
	then
		return false, "Invalid work tile"
	end
	if not (player.techs or {})[definition.tech] then
		return false, "Research " .. definition.tech .. " first"
	end
	local key = x .. ":" .. y
	if Sites.at(state, x, y) then
		return false, "Specialty reserves this tile"
	end
	if not state.world.tiles[key] then
		return false, "Explore the tile before assigning work"
	end
	local city = systems.territoryCity(state, x, y)
	if not city or city.owner ~= player.id then
		return false, "Work requires an owned city tile"
	end
	if city.x == x and city.y == y then
		return false, "City centers cannot be improved"
	end
	if
		city.project
		and city.project.kind == "wonder"
		and city.project.x == x
		and city.project.y == y
	then
		return false, "Tile is reserved for a wonder"
	end
	if (state.world.landmarks or {})[key] then
		return false, "Landmarks and wonders reserve this tile"
	end
	if (state.world.improvements or {})[key] then
		return false, "Tile already has an improvement"
	end
	local tile = Biomes.tile(state.world, x, y)
	if tile.elevation == "mountain" or tile.biome == "coast" or tile.biome == "ocean" then
		return false, "Builders require workable land"
	end
	local wooded = tile.feature == "woods" or tile.feature == "dense"
	if
		kind == "farm"
		and (
			tile.elevation ~= "flat"
			or tile.feature ~= "none"
			or tile.biome == "desert"
			or tile.biome == "snowy_plains"
			or tile.biome == "badlands"
		)
	then
		return false, "Fields require open fertile flat land"
	end
	if
		kind == "quarry"
		and (
			tile.feature ~= "none"
			or (tile.elevation ~= "hill" and (state.world.resources or {})[key] ~= "stone")
		)
	then
		return false, "Quarries require clear hills or stone"
	end
	if kind == "lumber" and not wooded then
		return false, "Lumber camps require woods or jungle"
	end
	return true
end
function Works.preview(state, player, unit, kind, x, y, systems)
	if
		not unit
		or unit.owner ~= player.id
		or unit.kind ~= "builder"
		or (unit.charges or 0) <= 0
	then
		return nil, "Select an owned Builder with charges"
	end
	local ok, reason = Works.canPlace(state, player, kind, x, y, systems)
	if not ok then
		return nil, reason
	end
	local before = systems.tileYields(state, x, y)
	local definition = Works.definitions[kind]
	local food, industry = definition.food, definition.industry
	if kind == "farm" and player.civ == "verdant" then
		food = food + 1
	end
	if kind == "quarry" and player.civ == "iron" then
		industry = industry + 1
	end
	return {
		kind = kind,
		x = x,
		y = y,
		before = before,
		after = {
			food = before.food + food,
			industry = before.industry + industry,
			science = before.science,
		},
		chargesBefore = unit.charges,
		chargesAfter = unit.charges - 1,
	}
end
function Works.complete(state, player, unit, kind, systems)
	local preview, reason = Works.preview(state, player, unit, kind, unit.x, unit.y, systems)
	if not preview then
		return false, reason
	end
	if unit.moved or (unit.movesLeft or 0) <= 0 or unit.embarked then
		return false, "Builder needs movement remaining on land"
	end
	state.world.improvements = state.world.improvements or {}
	state.world.improvements[unit.x .. ":" .. unit.y] = { kind = kind, builtRound = state.round }
	unit.charges = unit.charges - 1
	unit.movesLeft, unit.moved, unit.actedThisRound = 0, true, true
	unit.healing, unit.standby = false, false
	state.improvementRevision = (state.improvementRevision or 0) + 1
	if unit.charges == 0 then
		local Stacks = dofile("/games/civcraft/unit_stacks.lua")
		Stacks.unlink(state, unit)
		for index, candidate in ipairs(state.units) do
			if candidate == unit then
				table.remove(state.units, index)
				break
			end
		end
	end
	return true, "Built " .. Works.definitions[kind].name, preview
end
return Works
