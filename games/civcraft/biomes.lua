--[[
	Layered geography with a read-only adapter for previously saved terrain strings.
]]
local Biomes = {}
Biomes.names = {
	plains = "PLAINS",
	forest = "FOREST",
	savanna = "SAVANNA",
	desert = "DESERT",
	taiga = "TAIGA",
	jungle = "JUNGLE",
	swamp = "MANGROVE SWAMP",
	snowy_plains = "SNOWY PLAINS",
	badlands = "BADLANDS",
	coast = "COAST",
	ocean = "OCEAN",
	mushroom = "MUSHROOM FIELDS",
}
function Biomes.terrain(tile)
	if tile.biome == "ocean" or tile.biome == "coast" then
		return "water"
	end
	if tile.elevation == "mountain" then
		return "mountain"
	end
	if tile.elevation == "hill" then
		return "hills"
	end
	if tile.feature == "woods" or tile.feature == "dense" or tile.feature == "marsh" then
		return "forest"
	end
	return "plains"
end

function Biomes.legacy(terrain)
	local tile = { biome = "plains", elevation = "flat", feature = "none", legacy = true }
	if terrain == "water" then
		tile.biome = "ocean"
	elseif terrain == "forest" then
		tile.biome = "forest"
		tile.feature = "woods"
	elseif terrain == "desert" then
		tile.biome = "desert"
	elseif terrain == "mountain" then
		tile.elevation = "mountain"
	elseif terrain == "hills" then
		tile.elevation = "hill"
	end
	return tile
end

function Biomes.tile(world, x, y)
	local tileKey = x .. ":" .. y
	local terrain = world and world.tiles and world.tiles[tileKey] or "plains"
	local tile = world and world.geography and world.geography[tileKey]
	-- Respect legacy terrain edits by map tools rather than using stale derived
	-- layers.
	if tile and Biomes.terrain(tile) == terrain then
		return tile
	end
	return Biomes.legacy(terrain)
end

function Biomes.label(tile)
	local label = Biomes.names[tile.biome] or tile.biome:upper()
	if tile.elevation ~= "flat" then
		label = label .. " / " .. tile.elevation:upper()
	end
	if tile.feature ~= "none" then
		label = label .. " / " .. tile.feature:upper()
	end
	return label
end

-- Standard Civ VI terrain yields. CivCraft's Minecraft biomes map to the
-- closest terrain/feature combination; custom biomes have explicit analogues.
-- Returns Food, Production (industry in CivCraft), and Gold.
local baseYields = {
	plains = { 1, 1 },
	forest = { 2, 0 }, -- Grassland with optional Woods
	savanna = { 1, 1 }, -- Plains
	desert = { 0, 0 },
	taiga = { 1, 0 }, -- Tundra
	jungle = { 1, 1 }, -- Plains with optional Rainforest
	swamp = { 2, 0 }, -- Grassland with optional Marsh
	snowy_plains = { 0, 0 }, -- Snow
	badlands = { 0, 0 }, -- Desert
	mushroom = { 2, 0 }, -- Grassland (no direct Civ VI counterpart)
}
function Biomes.yields(tile)
	if tile.elevation == "mountain" then
		return 0, 0, 0 -- Unworkable in Civ VI.
	end
	if tile.biome == "coast" then
		return 1, 0, 1
	end
	if tile.biome == "ocean" then
		return 1, 0, 0
	end
	local base = baseYields[tile.biome] or baseYields.plains
	local food, industry = base[1], base[2]
	if tile.elevation == "hill" then
		industry = industry + 1
	end
	if tile.feature == "woods" then
		industry = industry + 1
	elseif tile.feature == "dense" or tile.feature == "marsh" then
		food = food + 1
	end
	return food, industry, 0
end

function Biomes.eligible(tile, resource)
	local water = tile.biome == "coast" or tile.biome == "ocean"
	if resource == "fish" then
		return water
	end
	if water then
		return false
	end
	local open = tile.elevation == "flat" and tile.feature == "none"
	local rocky = tile.elevation == "hill" or tile.elevation == "mountain"
	if resource == "grain" or resource == "horses" then
		return open and (tile.biome == "plains" or tile.biome == "savanna")
	end
	if resource == "timber" then
		return tile.elevation ~= "mountain" and (tile.feature == "woods" or tile.feature == "dense")
	end
	if resource == "stone" then
		return rocky
	end
	if resource == "iron" or resource == "coal" then
		return rocky and tile.biome ~= "snowy_plains"
	end
	if resource == "copper" or resource == "zinc" or resource == "redstone" then
		return rocky or tile.biome == "badlands"
	end
	if resource == "diamond" then
		return rocky
	end
	if resource == "saltpeter" then
		return tile.biome == "plains" and tile.feature == "none" and tile.elevation ~= "mountain"
	end
	return false
end
return Biomes
