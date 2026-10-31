local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Economy = dofile("/games/civcraft/economy.lua")
local Stock = dofile("/games/civcraft/resource_stock.lua")
local Content = dofile("/games/civcraft/content.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local World = dofile("/games/civcraft/world.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
assert(Content.resources.coal.tech == "steampower")
local ordered = false
for _, id in ipairs(Content.resourceOrder) do
	ordered = ordered or id == "coal"
end
assert(ordered)
for _, biome in ipairs({ "plains", "badlands", "snowy_plains", "coast", "ocean" }) do
	for _, elevation in ipairs({ "flat", "hill", "mountain" }) do
		local tile = { biome = biome, elevation = elevation, feature = "none" }
		assert(Biomes.eligible(tile, "coal") == Biomes.eligible(tile, "iron"))
	end
end
local p = { id = 1, techs = {}, stockpile = assert(Stock.migrate({ coal = 9, diamond = 6 })) }
local state = {
	ruleset = "create",
	players = { p },
	cities = {},
	units = {},
	world = {
		width = 8,
		height = 6,
		tiles = {},
		resources = {
			["2:2"] = "coal",
			["3:2"] = "coal",
			["4:2"] = "coal",
			["5:2"] = "diamond",
		},
	},
}
for y = 1, 6 do
	for x = 1, 8 do
		state.world.tiles[x .. ":" .. y] = "plains"
	end
end
local owned = { ["2:2"] = 1, ["3:2"] = 1, ["4:2"] = 2, ["5:2"] = 1 }
local locked = Economy.plan(p, state, owned)
assert(locked.stock.coal == 9 and locked.rates.coal == 0 and locked.overflow.coal == 0)
p.techs.steampower, p.techs.deepmining = true, true
local plan = Economy.plan(p, state, owned)
assert(plan.stock.coal == 10 and plan.rates.coal == 1 and plan.overflow.coal == 1)
assert(plan.stock.diamond == 6 and plan.rates.diamond == 0 and plan.overflow.diamond == 1)
assert(p.stockpile.coal == 9 and p.stockpile.diamond == 6, "Forecast must be read-only")
plan.stock.coal = 0
assert(p.stockpile.coal == 9, "Forecast result must be detached")
p.stockpile.coal = 12
local above = Economy.plan(p, state, owned)
assert(above.stock.coal == 12 and above.rates.coal == 0 and above.overflow.coal == 2)
-- Authoritative round production uses the same cap even when cities overlap.
p.stockpile.coal = 9
state.cities = {
	{ id = 1, owner = 1, x = 2, y = 2, population = 2, buildings = {} },
	{ id = 2, owner = 1, x = 3, y = 2, population = 2, buildings = {} },
}
p.civ, p.gold, state.phase, state.round = "forge", 100, "game", 1
Systems.migrate(state)
local forecast = Systems.economy(p, state)
Systems.production(state, Hex)
assert(p.stockpile.coal == 10 and p.resourceOverflow.coal == forecast.resourceOverflow.coal)
p.visible, p.explored = { ["2:2"] = true }, { ["2:2"] = true }
local view = World.forPlayer(state, p.id)
assert(
	view.world.resources["2:2"] == "coal" and view.world.resources["4:2"] == nil,
	"Coal follows visible/remembered observations without exposing hidden deposits"
)
local old = {
	world = {
		width = 8,
		height = 6,
		tiles = {},
		resources = { ["2:2"] = "iron" },
		generationVersion = 5,
	},
}
World.migrate(old)
assert(
	old.world.generationVersion == 5
		and old.world.resources["2:2"] == "iron"
		and old.world.resources["3:2"] == nil,
	"Migration never adds coal to saved geography"
)
local coal = 0
for _, seed in ipairs({ 1, 75123, 319497 }) do
	local world = World.generate(seed, "compact", 2, "continents", { contentRules = "balance5" })
	local count = 0
	for key, resource in pairs(world.resources) do
		count = count + 1
		if resource == "coal" then
			local x, y = key:match("^(%d+):(%d+)$")
			assert(Biomes.eligible(Biomes.tile(world, tonumber(x), tonumber(y)), "coal"))
			coal = coal + 1
		end
	end
	assert(
		count == math.floor(world.width * world.height * 0.175 + 0.5),
		"Deposit density stays fixed"
	)
end
assert(coal > 0, "Fixed generation fixtures include coal")
print("CIVCRAFT: coal terrain, density, tech gates, unique extraction and capped forecasts passed")
