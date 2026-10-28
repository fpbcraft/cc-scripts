-- Civ VI terrain/feature parity and automatic upgrade of every prior save version.
local nativeDofile = dofile
dofile = function(path)
	return nativeDofile(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)

local Biomes = dofile("/games/civcraft/biomes.lua")
local World = dofile("games/civcraft/world.lua")
local Systems = dofile("games/civcraft/systems.lua")
local Encyclopedia = dofile("games/civcraft/encyclopedia.lua")
local Works = dofile("games/civcraft/tile_improvements.lua")

local function natural(biome, elevation, feature)
	return { biome = biome, elevation = elevation, feature = feature }
end
local function sameYield(actual, food, industry, gold, label)
	assert(
		actual.food == food and actual.industry == industry and (actual.gold or 0) == gold,
		label .. ": expected " .. food .. "/" .. industry .. "/" .. gold
	)
end
local function check(biome, elevation, feature, food, industry, gold)
	local f, p, g = Biomes.yields(natural(biome, elevation, feature))
	assert(
		f == food and p == industry and g == gold,
		table.concat({ biome, elevation, feature, f, p, g }, " ")
	)
end

-- Civ VI base terrain and additive hills/woods/rainforest/marsh.
check("plains", "flat", "none", 1, 1, 0)
check("plains", "hill", "none", 1, 2, 0)
check("plains", "hill", "woods", 1, 3, 0)
check("forest", "flat", "none", 2, 0, 0)
check("forest", "flat", "woods", 2, 1, 0)
check("forest", "hill", "woods", 2, 2, 0)
check("savanna", "flat", "none", 1, 1, 0)
check("savanna", "hill", "none", 1, 2, 0)
check("desert", "flat", "none", 0, 0, 0)
check("desert", "hill", "none", 0, 1, 0)
check("taiga", "flat", "none", 1, 0, 0)
check("taiga", "hill", "woods", 1, 2, 0)
check("jungle", "flat", "none", 1, 1, 0)
check("jungle", "flat", "dense", 2, 1, 0)
check("swamp", "flat", "none", 2, 0, 0)
check("swamp", "flat", "marsh", 3, 0, 0)
check("snowy_plains", "flat", "none", 0, 0, 0)
check("snowy_plains", "hill", "none", 0, 1, 0)
check("badlands", "flat", "none", 0, 0, 0)
check("badlands", "hill", "none", 0, 1, 0)
check("mushroom", "flat", "none", 2, 0, 0)
check("ocean", "flat", "none", 1, 0, 0)
check("coast", "flat", "none", 1, 0, 1)
for _, biome in ipairs({ "plains", "forest", "desert", "taiga", "snowy_plains" }) do
	check(biome, "mountain", "none", 0, 0, 0)
end
-- Maps edited by older tooling fall back to the legacy tile adapter.
local legacyWorld = { tiles = { ["1:1"] = "hills", ["2:1"] = "forest", ["3:1"] = "desert" } }
sameYield(World.yields(legacyWorld, 1, 1), 1, 2, 0, "Legacy hills")
sameYield(World.yields(legacyWorld, 2, 1), 2, 1, 0, "Legacy forest")
sameYield(World.yields(legacyWorld, 3, 1), 0, 0, 0, "Legacy desert")

-- New worlds set the rules version before the start-placement scorer runs.
local scorerVersions = {}
local originalYields = Biomes.yields
Biomes.yields = function(tile, version)
	scorerVersions[#scorerVersions + 1] = version
	return originalYields(tile)
end
local generated = World.generate(9001, "compact", 2, "pangaea")
Biomes.yields = originalYields
assert(generated.terrainYieldVersion == "civ6-1", "Direct generation marks Civ VI yields")
assert(#scorerVersions > 0, "Generation evaluates terrain for start placement")
for _, version in ipairs(scorerVersions) do
	assert(version == "civ6-1", "Start scoring uses current rules")
end
assert(generated.generationVersion == 2, "Yield changes do not regenerate the map")

local world = {
	width = 12,
	height = 10,
	tiles = {},
	geography = {},
	resources = {},
	landmarks = {},
	improvements = {},
	terrainYieldVersion = "civ6-1",
}
for y = 1, world.height do
	for x = 1, world.width do
		local tile = natural("plains", "flat", "none")
		world.geography[x .. ":" .. y] = tile
		world.tiles[x .. ":" .. y] = Biomes.terrain(tile)
	end
end
local function setTile(x, biome, elevation, feature)
	local tile = natural(biome, elevation, feature)
	world.geography[x .. ":4"] = tile
	world.tiles[x .. ":4"] = Biomes.terrain(tile)
end
setTile(1, "desert", "flat", "none")
setTile(2, "plains", "flat", "none")
setTile(3, "forest", "flat", "woods")
setTile(4, "plains", "hill", "none")
setTile(5, "coast", "flat", "none")
setTile(6, "ocean", "flat", "none")
setTile(7, "plains", "flat", "none")
setTile(8, "plains", "flat", "none")
setTile(9, "plains", "flat", "none")
setTile(10, "plains", "flat", "none")
setTile(11, "plains", "flat", "none")
setTile(12, "plains", "flat", "none")
world.resources = {
	["2:4"] = "grain",
	["3:4"] = "timber",
	["4:4"] = "stone",
	["5:4"] = "fish",
	["6:4"] = "fish",
	["7:4"] = "copper",
	["8:4"] = "diamond",
	["9:4"] = "iron",
	["10:4"] = "horses",
	["11:4"] = "saltpeter",
	["12:4"] = "zinc",
}
sameYield(World.yields(world, 1, 4), 0, 0, 0, "Bare desert")
sameYield(World.yields(world, 2, 4), 2, 1, 0, "Wheat adds 1 food")
sameYield(World.yields(world, 3, 4), 2, 3, 0, "Custom timber retains bonus")
sameYield(World.yields(world, 4, 4), 1, 3, 0, "Stone adds 1 production")
sameYield(World.yields(world, 5, 4), 2, 0, 1, "Coastal fish and gold")
sameYield(World.yields(world, 6, 4), 2, 0, 0, "Ocean fish")
sameYield(World.yields(world, 7, 4), 1, 1, 2, "Copper adds 2 gold")
sameYield(World.yields(world, 8, 4), 1, 1, 3, "Diamonds add 3 gold")
assert(World.yields(world, 9, 4).science == 1, "Iron adds 1 science")
sameYield(World.yields(world, 10, 4), 2, 2, 0, "Horses")
sameYield(World.yields(world, 11, 4), 2, 2, 0, "Niter")
sameYield(World.yields(world, 12, 4), 1, 2, 0, "Custom zinc retains bonus")

world.landmarks["1:4"] = { natural = true, kind = "dripstone" }
sameYield(World.yields(world, 1, 4), 0, 4, 0, "Natural wonder still adds yield")
world.improvements["2:4"] = { kind = "farm" }
world.improvements["3:4"] = { kind = "lumber" }
world.improvements["4:4"] = { kind = "quarry" }
sameYield(World.yields(world, 2, 4), 3, 1, 0, "Farm adds 1 food")
sameYield(World.yields(world, 3, 4), 2, 4, 0, "Lumber adds 1 production")
sameYield(World.yields(world, 4, 4), 1, 4, 0, "Quarry adds 1 production")
world.improvements["4:4"].damaged = true
sameYield(World.yields(world, 4, 4), 1, 3, 0, "Damaged improvements add nothing")
assert(Works.definitions.farm.food == 1 and Works.definitions.quarry.industry == 1)
local center = Systems.centerYields({}, { buildings = {} }, nil)
assert(
	center.food == 2 and center.industry == 1 and center.science == 1 and center.gold == 0,
	"City-center rules remain independent of tile yield migration"
)

-- Worked Gold must actually enter treasury once, not just show on the map.
local city = {
	id = 1,
	owner = 1,
	x = 6,
	y = 5,
	population = 2,
	buildings = {},
	worked = { ["5:4"] = true, ["7:4"] = true },
	claimed = { ["5:4"] = true, ["7:4"] = true, ["6:5"] = true },
}
local state = {
	version = 6,
	phase = "game",
	contentRules = "balance3",
	round = 1,
	world = world,
	players = { { id = 1, civ = "iron", gold = 20, techs = {} } },
	cities = { city },
	units = {},
}
Systems.migrate(state)
local player = state.players[1]
local cityYield = Systems.yields(player, city, state)
assert(cityYield.gold == 3, "Worked coast and copper total 3 gold")
local income = Systems.treasury(player, state).income
city.worked["5:4"] = nil
city.worked["7:4"] = nil
assert(Systems.treasury(player, state).income == income - 3, "Worked tile gold enters income")
assert(Systems.yields(player, city, state).gold == 0, "Unworked tiles earn no gold")

-- Every old save, including sparse1 maps, migrates without mutating terrain or cities.
local oldState = {
	phase = "game",
	world = {
		width = 1,
		height = 1,
		tiles = { ["1:1"] = "desert" },
		resources = {},
		seed = 17,
		terrainYieldVersion = "sparse1",
	},
	players = { { id = 1, visible = {}, explored = {} } },
	cities = {},
	units = {},
}
local savedTiles = oldState.world.tiles
World.migrate(oldState)
assert(
	oldState.world.tiles == savedTiles and oldState.world.seed == 17,
	"Migration preserves terrain and seed"
)
assert(oldState.world.terrainYieldVersion == "civ6-1", "Sparse saves auto-migrate")
sameYield(World.yields(oldState.world, 1, 1), 0, 0, 0, "Migrated desert")
World.migrate(oldState)
assert(oldState.world.tiles == savedTiles, "Migration is idempotent")
local unversioned = {
	phase = "game",
	world = { width = 1, height = 1, tiles = { ["1:1"] = "forest" }, resources = {} },
	players = {},
	cities = {},
	units = {},
}
World.migrate(unversioned)
assert(unversioned.world.terrainYieldVersion == "civ6-1", "Unversioned maps auto-migrate")
sameYield(World.yields(unversioned.world, 1, 1), 2, 1, 0, "Old forest migrated")

local projected = World.forPlayer({
	phase = "game",
	round = 1,
	world = generated,
	players = { { id = 1, visible = {}, explored = {} } },
	cities = {},
	units = {},
}, 1)
assert(projected.world.terrainYieldVersion == "civ6-1", "Observer uses current rules")
local yieldEntry
for _, entry in ipairs(Encyclopedia.entries("mechanics")) do
	if entry.id == "yields" then
		yieldEntry = entry
		break
	end
end
assert(yieldEntry)
local help = table.concat(
	Encyclopedia.describe(
		"mechanics",
		yieldEntry,
		nil,
		{ world = { terrainYieldVersion = "civ6-1" } }
	),
	" "
)
assert(help:find("Civ VI tile yields", 1, true), "Codex documents current yields")

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
	"Disk contains old marker before migration"
)
World.migrate(sparseLoaded)
assert(sparseLoaded.world.terrainYieldVersion == "civ6-1", "Loaded sparse save migrated")
sameYield(World.yields(sparseLoaded.world, 1, 1), 0, 0, 0, "Loaded sparse yields migrate")
local legacySave = {
	phase = "game",
	world = { width = 1, height = 1, tiles = { ["1:1"] = "desert" }, resources = {}, seed = 606 },
}
Saves.save(2, legacySave)
local legacyLoaded = Saves.load(2)
World.migrate(legacyLoaded)
assert(legacyLoaded.world.terrainYieldVersion == "civ6-1", "Legacy saves migrate automatically")
sameYield(World.yields(legacyLoaded.world, 1, 1), 0, 0, 0, "Loaded legacy yields updated")

print(
	"CIVCRAFT: Civ VI parity, automatic migration, gold income, start scoring, projection, help "
		.. "and save/load passed."
)
