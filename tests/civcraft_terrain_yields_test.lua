-- Versioned sparse terrain keeps old maps on their stored yield semantics.
local nativeDofile = dofile
dofile = function(path)
	return nativeDofile(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)

local Biomes = dofile("/games/civcraft/biomes.lua")
local World = dofile("games/civcraft/world.lua")
local Systems = dofile("games/civcraft/systems.lua")
local Encyclopedia = dofile("games/civcraft/encyclopedia.lua")

local function sameYield(actual, food, industry, label)
	assert(actual.food == food and actual.industry == industry, label)
end
local function natural(biome, elevation, feature)
	return { biome = biome, elevation = elevation, feature = feature }
end
local function check(biome, elevation, feature, version, food, industry)
	local actualFood, actualIndustry = Biomes.yields(natural(biome, elevation, feature), version)
	assert(
		actualFood == food and actualIndustry == industry,
		table.concat(
			{ biome, elevation, feature, tostring(version), actualFood, actualIndustry },
			" "
		)
	)
end

-- Unversioned geography keeps the pre-change natural yields.
check("desert", "flat", "none", nil, 1, 1)
check("desert", "hill", "none", nil, 1, 2)
check("taiga", "flat", "none", nil, 2, 1)
check("taiga", "flat", "woods", nil, 1, 2)
check("taiga", "hill", "none", nil, 1, 2)

-- sparse1 changes only desert and taiga natural yields.
check("desert", "flat", "none", "sparse1", 0, 0)
check("desert", "hill", "none", "sparse1", 0, 1)
check("desert", "mountain", "none", "sparse1", 0, 1)
check("taiga", "flat", "none", "sparse1", 0, 0)
check("taiga", "flat", "woods", "sparse1", 0, 1)
check("taiga", "flat", "dense", "sparse1", 0, 1)
check("taiga", "hill", "none", "sparse1", 0, 1)
check("taiga", "mountain", "none", "sparse1", 0, 1)
check("plains", "flat", "none", "sparse1", 2, 1)
check("forest", "flat", "woods", "sparse1", 1, 2)
check("savanna", "flat", "none", "sparse1", 2, 1)
check("snowy_plains", "flat", "none", "sparse1", 1, 1)
check("badlands", "flat", "none", "sparse1", 1, 2)
check("jungle", "flat", "dense", "sparse1", 2, 2)
check("swamp", "flat", "marsh", "sparse1", 2, 1)
check("mushroom", "flat", "none", "sparse1", 3, 1)
check("ocean", "flat", "none", "sparse1", 2, 0)
check("coast", "flat", "none", "sparse1", 2, 0)

-- New worlds have the version before start scoring runs, and use it in that score.
local scorerVersions = {}
local originalYields = Biomes.yields
Biomes.yields = function(tile, version)
	scorerVersions[#scorerVersions + 1] = version
	return originalYields(tile, version)
end
local generated = World.generate(9001, "compact", 2, "pangaea")
Biomes.yields = originalYields
assert(generated.terrainYieldVersion == "sparse1", "Direct generation marks new worlds")
assert(#scorerVersions > 0, "Generation evaluates terrain for the start score")
for _, version in ipairs(scorerVersions) do
	assert(version == "sparse1", "Start scoring uses the world's saved yield version")
end
assert(generated.generationVersion == 2, "Yield rules do not renumber map generation")

-- Shared world yields retain deposits, improvements, wonders and city centers.
local world = {
	width = 5,
	height = 1,
	tiles = {},
	geography = {},
	resources = { ["2:1"] = "grain", ["3:1"] = "timber" },
	landmarks = { ["4:1"] = { natural = true, kind = "dripstone" } },
	improvements = { ["5:1"] = { kind = "farm" } },
	terrainYieldVersion = "sparse1",
}
local sampleTiles = {
	natural("desert", "flat", "none"),
	natural("desert", "flat", "none"),
	natural("taiga", "flat", "woods"),
	natural("desert", "flat", "none"),
	natural("taiga", "flat", "none"),
}
for x, tile in ipairs(sampleTiles) do
	world.geography[x .. ":1"] = tile
	world.tiles[x .. ":1"] = Biomes.terrain(tile)
end
sameYield(World.yields(world, 1, 1), 0, 0, "Sparse desert base")
sameYield(World.yields(world, 2, 1), 2, 0, "Grain still adds food")
sameYield(World.yields(world, 3, 1), 0, 3, "Timber still adds industry")
sameYield(World.yields(world, 4, 1), 0, 4, "Natural wonder still adds industry")
sameYield(World.yields(world, 5, 1), 2, 0, "Farm still adds food")
local center = Systems.centerYields({}, { buildings = {} }, nil)
assert(
	center.food == 2 and center.industry == 1 and center.science == 1,
	"City center yields stay fixed"
)

-- Migration does not backfill old worlds, preserving their exact legacy yields.
local oldState = {
	phase = "game",
	world = {
		width = 1,
		height = 1,
		tiles = { ["1:1"] = "desert" },
		resources = {},
		seed = 17,
	},
	players = { { id = 1, visible = {}, explored = {} } },
	cities = {},
	units = {},
}
World.migrate(oldState)
assert(oldState.world.terrainYieldVersion == nil, "Old worlds keep a nil version")
sameYield(World.yields(oldState.world, 1, 1), 1, 1, "Old desert yield is unchanged")

-- Observer projection carries the public rule marker with the redacted world.
local state = {
	phase = "game",
	round = 1,
	world = generated,
	players = { { id = 1, visible = {}, explored = {} } },
	cities = {},
	units = {},
}
local projected = World.forPlayer(state, 1)
assert(projected.world.terrainYieldVersion == "sparse1", "Observer sees the world rule version")
local oldProjection = World.forPlayer(oldState, 1)
assert(oldProjection.world.terrainYieldVersion == nil, "Observer does not backfill legacy versions")

-- The Codex explains the active terrain version, and leaves legacy help accurate.
local yieldEntry
for _, entry in ipairs(Encyclopedia.entries("mechanics")) do
	if entry.id == "yields" then
		yieldEntry = entry
		break
	end
end
assert(yieldEntry)
local sparseHelp = table.concat(
	Encyclopedia.describe(
		"mechanics",
		yieldEntry,
		nil,
		{ world = { terrainYieldVersion = "sparse1" } }
	),
	" "
)
assert(sparseHelp:find("flat desert yields 0 food", 1, true), "Help explains sparse terrain")
local legacyHelp = table.concat(
	Encyclopedia.describe("mechanics", yieldEntry, nil, { world = { terrainYieldVersion = nil } }),
	" "
)
assert(
	not legacyHelp:find("flat desert yields 0 food", 1, true),
	"Legacy help does not claim new yields"
)

-- Actual save writer round-trips the explicit new version and keeps nil old saves.
local files, dirs = {}, {}
fs = {}
function fs.exists(file)
	return files[file] ~= nil or dirs[file]
end
function fs.makeDir(directory)
	dirs[directory] = true
end
function fs.open(file, mode)
	if mode == "r" then
		if files[file] == nil then
			return nil
		end
		return {
			readAll = function()
				return files[file]
			end,
			close = function() end,
		}
	end
	local body = ""
	return {
		write = function(value)
			body = body .. value
		end,
		close = function()
			files[file] = body
		end,
	}
end
function fs.move(from, to)
	assert(files[from] ~= nil)
	files[to] = files[from]
	files[from] = nil
end
function fs.delete(file)
	files[file] = nil
end
textutils = {
	unserialize = function(encoded)
		local read = load("return " .. encoded, "campaign", "t", {})
		return read and read() or nil
	end,
}
local Saves = dofile("/games/civcraft/saves.lua")
local sparseSave = {
	phase = "game",
	world = {
		width = 1,
		height = 1,
		tiles = { ["1:1"] = "desert" },
		resources = {},
		seed = 505,
		terrainYieldVersion = "sparse1",
	},
}
Saves.save(1, sparseSave)
local sparseLoaded = Saves.load(1)
assert(
	sparseLoaded.world.terrainYieldVersion == "sparse1",
	"Save/load preserves the new version marker"
)
sameYield(
	World.yields(sparseLoaded.world, 1, 1),
	0,
	0,
	"Loaded sparse yields use the saved version"
)
local legacySave = {
	phase = "game",
	world = { width = 1, height = 1, tiles = { ["1:1"] = "desert" }, resources = {}, seed = 606 },
}
Saves.save(2, legacySave)
local legacyLoaded = Saves.load(2)
World.migrate(legacyLoaded)
assert(legacyLoaded.world.terrainYieldVersion == nil, "Loading old saves does not backfill markers")
sameYield(World.yields(legacyLoaded.world, 1, 1), 1, 1, "Loaded legacy yields remain unchanged")

print(
	"CIVCRAFT: sparse1 terrain, legacy parity, start scoring, modifiers, projection, help "
		.. "and save/load passed."
)
