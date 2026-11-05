local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Operations = dofile("/games/civcraft/machine_operations.lua")
local function machine(plan, id, cityID)
	for _, item in ipairs(plan.machines) do
		if item.buildingID == id and (cityID == nil or item.cityID == cityID) then
			return item
		end
	end
end

local function city(id, owner, buildings, machines)
	return {
		id = id,
		owner = owner,
		x = 4 + (id - 1) * 3,
		y = 4,
		population = 3,
		buildings = buildings,
		machines = machines,
		sites = { works = { id = id, kind = "works", x = 5 + (id - 1) * 3, y = 4 } },
	}
end

local tiles = {}
for y = 1, 10 do
	for x = 1, 12 do
		tiles[x .. ":" .. y] = "plains"
	end
end
local techs = {
	engineering = true,
	waterpower = true,
	windpower = true,
	pressing = true,
	crushing = true,
	belts = true,
	deepmining = true,
	heatedmixing = true,
	brassworking = true,
	deployers = true,
	precision = true,
	mechanicalcrafting = true,
	steampower = true,
}
local player = { id = 1, techs = techs, explored = { ["5:4"] = true } }
local state = {
	contentRules = "balance5",
	world = { width = 12, height = 10, tiles = tiles, resources = {} },
	players = { player, { id = 2, techs = {} } },
	cities = {
		city(1, 1, { waterwheel = true, press = true, mixer = true, steamplant = true }, {
			waterwheel = { recipe = "generator", priority = 4, enabled = true },
			press = { recipe = "industry", priority = 1, enabled = true },
			mixer = { recipe = "brass", priority = 3, enabled = true },
			steamplant = { recipe = "generator", priority = 4, enabled = true },
		}),
		city(
			2,
			2,
			{ mixer = true },
			{ mixer = { recipe = "brass", priority = 1, enabled = true } }
		),
	},
	units = {},
}
player.visible = player.explored
state.cities[2].machines.mixer.recipe = "rival-malformed"

local stock = { coal = 1, copper = 1, zinc = 1 }
local forecast = assert(Operations.plan(state, 1, stock))
assert(forecast.owner == 1 and forecast.stock.coal == 0)
assert(forecast.stock.brass == 2 and forecast.stock.copper == 0 and forecast.stock.zinc == 0)
assert(forecast.capacity[1].capacity == 12 and forecast.capacity[1].used == 5)
assert(forecast.reservations.inputs.coal == 1, "Fuel must be reported as a material reservation")
assert(stock.coal == 1 and stock.copper == 1 and stock.zinc == 1)
for _, resource in ipairs(dofile("/games/civcraft/resource_stock.lua").order) do
	assert(
		forecast.reservations.snapshot[resource]
				+ forecast.reservations.outputs[resource]
				- forecast.reservations.inputs[resource]
			== forecast.stock[resource],
		"Combined fuel and operation reservations must conserve " .. resource
	)
end
forecast.machines[1].choice.recipe = "mutated-copy"
assert(state.cities[1].machines.waterwheel.recipe == "generator")
for _, result in ipairs(forecast.machines) do
	assert(result.cityID ~= 2, "Enemy machine choices must not appear in owner forecast")
end

local noDemand = assert(Operations.plan(state, 1, { coal = 1 }))
assert(noDemand.stock.coal == 1, "No-demand fuel must remain unspent")
for _, machine in ipairs(noDemand.machines) do
	if machine.buildingID == "steamplant" then
		assert(not machine.active and machine.reason == "no_demand")
	end
end
local capped = assert(Operations.plan(state, 1, { coal = 1, brass = 10 }))
assert(capped.stock.coal == 1, "Output-capped operations must not consume fuel")
local shortage = assert(Operations.plan(state, 1, { copper = 1, zinc = 1 }))
assert(shortage.stock.coal == nil or shortage.stock.coal == 0)
assert(shortage.capacity[1].capacity == 4 and shortage.capacity[1].used == 2)

state.units = { { owner = 2, x = 5, y = 4 } }
local occupied = assert(Operations.plan(state, 1, { coal = 1, copper = 1, zinc = 1 }))
assert(occupied.stock.coal == 1 and machine(occupied, "press").reason == "inactive_family")
state.units = {}
state.cities[1].owner = 2
local captured = assert(Operations.plan(state, 1, { coal = 1 }))
assert(#captured.machines == 0, "Captured cities must leave the former owner's forecast")
state.cities[1].owner = 1

local mixerOnly = city(1, 1, { mixer = true, steamplant = true }, {
	mixer = { recipe = "brass", priority = 3, enabled = true },
	steamplant = { recipe = "generator", priority = 4, enabled = true },
})
state.cities = { mixerOnly }
for _, missing in ipairs({ { zinc = 1 }, { copper = 1 }, {} }) do
	local missingPlan = assert(
		Operations.plan(
			state,
			1,
			{ coal = 1, brass = 0, copper = missing.copper, zinc = missing.zinc }
		)
	)
	assert(missingPlan.stock.coal == 1, "Missing single or both recipe inputs must preserve coal")
	assert(machine(missingPlan, "mixer").reason == "missing_input")
end
mixerOnly.machines.mixer.recipe = "no_recipe"
local unselected = assert(Operations.plan(state, 1, { coal = 1 }))
assert(unselected.stock.coal == 1 and machine(unselected, "mixer").reason == "no_recipe")

local disabled = city(1, 1, { waterwheel = true, press = true, steamplant = true }, {
	waterwheel = { recipe = "generator", priority = 4, enabled = true },
	press = { recipe = "industry", priority = 1, enabled = false },
	steamplant = { recipe = "generator", priority = 4, enabled = true },
})
state.cities = { disabled }
local disabledPlan = assert(Operations.plan(state, 1, { coal = 1 }))
assert(disabledPlan.stock.coal == 1)

-- Two cities contend globally for one batch; speculative extra fuel is released.
local secondOwned = city(3, 1, { mixer = true, steamplant = true }, {
	mixer = { recipe = "brass", priority = 3, enabled = true },
	steamplant = { recipe = "generator", priority = 4, enabled = true },
})
player.explored["11:4"], player.visible["11:4"] = true, true
state.cities = {
	city(1, 1, { waterwheel = true, press = true, mixer = true, steamplant = true }, {
		waterwheel = { recipe = "generator", priority = 4, enabled = true },
		press = { recipe = "industry", priority = 1, enabled = true },
		mixer = { recipe = "brass", priority = 3, enabled = true },
		steamplant = { recipe = "generator", priority = 4, enabled = true },
	}),
	secondOwned,
}
local contention = assert(Operations.plan(state, 1, { coal = 2, copper = 1, zinc = 1 }))
assert(contention.stock.coal == 1, "Fuel for a globally input-starved city must be released")
assert(contention.stock.brass == 2)

local higherFuelPriority = city(3, 1, { deepmine = true, steamplant = true }, {
	deepmine = { recipe = "industry", priority = 2, enabled = true },
	steamplant = { recipe = "generator", priority = 1, enabled = true },
})
state.cities = {
	city(1, 1, { waterwheel = true, press = true, mixer = true, steamplant = true }, {
		waterwheel = { recipe = "generator", priority = 4, enabled = true },
		press = { recipe = "industry", priority = 1, enabled = true },
		mixer = { recipe = "brass", priority = 3, enabled = true },
		steamplant = { recipe = "generator", priority = 4, enabled = true },
	}),
	higherFuelPriority,
}
local priorityFuel = assert(Operations.plan(state, 1, { coal = 1, copper = 1, zinc = 1 }))
assert(machine(priorityFuel, "steamplant", 1).active == false)
local prioritySteam
for _, item in ipairs(priorityFuel.machines) do
	if item.cityID == 3 and item.buildingID == "steamplant" then
		prioritySteam = item
	end
end
assert(
	prioritySteam and prioritySteam.active,
	"Steam fuel must honor persisted priority before city ID"
)

higherFuelPriority.machines.steamplant.priority = 4
local reallocated = assert(Operations.plan(state, 1, { coal = 1 }))
local recoveredSteam
for _, item in ipairs(reallocated.machines) do
	if item.cityID == 3 and item.buildingID == "steamplant" then
		recoveredSteam = item
	end
end
assert(
	recoveredSteam and recoveredSteam.active and recoveredSteam.reason == nil,
	"Freed no-demand fuel must reach a previously unfunded city"
)
assert(reallocated.stock.coal == 0 and reallocated.capacity[3].used == 2)
assert(Operations.effects(reallocated, 3).industry == 8, "Steam and Deep Mine contribute once")
local beforeOrder = {}
for _, item in ipairs(reallocated.machines) do
	beforeOrder[#beforeOrder + 1] = item.cityID .. ":" .. item.buildingID
end
state.cities[1], state.cities[2] = state.cities[2], state.cities[1]
local reordered = assert(Operations.plan(state, 1, { coal = 1 }))
for i, item in ipairs(reordered.machines) do
	assert(
		beforeOrder[i] == item.cityID .. ":" .. item.buildingID,
		"Forecast order must not depend on city array order"
	)
	assert(type(item.active) == "boolean" and type(item.effects) == "table")
	if item.active then
		assert(item.reason == nil)
	end
end
assert(machine(shortage, "mixer").reason == "missing_fuel")
disabled.machines.press.enabled = true
disabled.machines.press.recipe = "bad"
state.cities = { disabled }
assert(not Operations.plan(state, 1, { coal = 1 }), "Malformed owner choices must be rejected")

print("CIVCRAFT: owner-only detached machine forecasts and conditional fuel passed")
