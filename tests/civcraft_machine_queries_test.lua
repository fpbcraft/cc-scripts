local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Stock = dofile("/games/civcraft/resource_stock.lua")
local Content = dofile("/games/civcraft/content.lua")
local player = {
	id = 1,
	name = "OWNER",
	civ = "forge",
	techs = {},
	gold = 100,
	stockpile = { coal = 1, copper = 1, zinc = 1 },
}
for id in pairs(Systems.techs) do
	player.techs[id] = true
end
local city = {
	id = 1,
	owner = 1,
	x = 4,
	y = 4,
	population = 3,
	buildings = {
		waterwheel = true,
		press = true,
		mixer = true,
		steamplant = true,
		workshop = true,
		library = true,
		market = true,
	},
	sites = { works = { id = 1, kind = "works", x = 5, y = 4 } },
}
local state = {
	phase = "game",
	round = 1,
	contentRules = "balance5",
	ruleset = "create",
	nextId = 3,
	specialtySchema = 1,
	nextSiteId = 3,
	players = { player, { id = 2, name = "RIVAL", civ = "forge", techs = {} } },
	cities = {
		city,
		{
			id = 2,
			owner = 2,
			x = 12,
			y = 8,
			population = 2,
			buildings = { mixer = true },
			sites = { works = { id = 2, kind = "works", x = 13, y = 8 } },
		},
	},
	units = {},
	world = { width = 16, height = 12, tiles = {}, resources = { ["4:4"] = "coal" } },
}
for y = 1, 12 do
	for x = 1, 16 do
		state.world.tiles[x .. ":" .. y] = "plains"
	end
end
Systems.migrate(state)
World.reveal(state, Hex, Systems)
assert(
	Actions.apply(
		state,
		1,
		{ action = "selectMachineRecipe", city = 1, building = "mixer", recipe = "brass" },
		Systems
	)
)
local before = assert(Stock.copy(player.stockpile))
local plan = assert(Systems.machinePlan(state, player, 1))
assert(plan.owner == 1 and plan.stock.brass == 2 and plan.stock.coal == 1)
assert(plan.extraction.rates.coal == 1 and plan.reservations.inputs.coal == 1)
assert(plan.rates.coal == 0 and plan.rates.brass == 2)
for id, value in pairs(before) do
	assert(player.stockpile[id] == value, "Plan mutated stock")
end
assert(plan.effects[1].industry == 11, "Brass recipe cannot also grant Mixer industry")
local capacity = assert(Systems.machineCapacity(state, 1, 1))
assert(
	capacity.capacity == 12 and capacity.used == 5 and capacity.base == 4 and capacity.steamActive
)
capacity.capacity = 999
assert(Systems.machineCapacity(state, 1, 1).capacity == 12)
assert(not Systems.machineCapacity(state, 1, 2))
assert(not Systems.machinePlan(state, 99))
local preview = assert(Systems.previewMachine(state, 1, 1, "mixer", "industry"))
assert(preview.stock.brass == 0 and preview.stock.copper == before.copper)
assert(preview.effects[1].industry == plan.effects[1].industry + 2)
assert(city.machines.mixer.recipe == "brass", "Preview changed selected recipe")
assert(not Systems.previewMachine(state, 1, 1, "mixer", "unknown"))
assert(not Systems.previewMachine(state, 1, 2, "mixer", "industry"))
local forecast = assert(Systems.machineForecast(state, 1))
assert(forecast.economy.strategic.brass == 2 and forecast.economy.strategic.coal == 0)
local frozen = Systems.centerYields(player, city, state, plan)
city.buildings.library = false
assert(
	frozen.science - Systems.centerYields(player, city, state, plan).science
		== Content.buildings.library.effects.science,
	"Unpowered Library continues independently of machine capacity"
)
city.buildings.library = true
player.stockpile = plan.stock
assert(
	Systems.centerYields(player, city, state, plan).industry == frozen.industry,
	"Resolution must use its frozen plan after input debit"
)
assert(
	Systems.machinePlan(state, 1).effects[1].industry < plan.effects[1].industry,
	"A fresh next-round forecast may differ after inputs were consumed"
)
player.stockpile = before
local ownerView = World.forPlayer(state, 1)
local observed = assert(Systems.machinePlan(ownerView, 1))
assert(
	observed.stock.brass == plan.stock.brass
		and observed.effects[1].industry == plan.effects[1].industry
)
state.cities[2].machines.mixer.recipe = "private-invalid"
local private = assert(Systems.machinePlan(state, 1))
assert(private.stock.brass == 2 and #private.machines == #plan.machines)
for _, row in ipairs(private.machines) do
	assert(row.cityID == 1)
end
print("CIVCRAFT: owner-only machine queries, previews, basic effects and frozen-plan yields passed")
