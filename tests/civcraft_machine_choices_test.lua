local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Migration = dofile("/games/civcraft/campaign_migration.lua")
local function fixture()
	local tiles = {}
	for y = 1, 10 do
		for x = 1, 12 do
			tiles[x .. ":" .. y] = "plains"
		end
	end
	return {
		version = 6,
		specialtySchema = 1,
		nextSiteId = 2,
		ruleset = "create",
		contentRules = "balance5",
		phase = "game",
		round = 1,
		nextId = 2,
		world = { width = 12, height = 10, tiles = tiles, resources = {} },
		players = { { id = 1, name = "A", civ = "forge", techs = {}, stockpile = {} } },
		cities = {
			{
				id = 1,
				owner = 1,
				x = 4,
				y = 4,
				population = 3,
				buildings = { mixer = true, press = true },
				sites = { works = { id = 1, kind = "works", x = 5, y = 4 } },
				machineStatus = { mixer = { active = true } },
			},
		},
		units = {},
	}
end
local migrated = assert(Migration.load(fixture()))
local city = migrated.cities[1]
assert(city.machines.mixer.recipe == "no_recipe")
assert(city.machines.mixer.priority == 3 and city.machines.mixer.enabled == true)
assert(city.machines.press.recipe == "industry" and city.machines.press.priority == 1)
assert(city.machineStatus == nil, "Derived status must not survive migration")
local Choices = dofile("/games/civcraft/machine_choices.lua")
local before = city.machines.mixer.recipe
local ok = Choices.apply(migrated, 2, {
	action = "selectMachineRecipe",
	city = 1,
	building = "mixer",
	recipe = "brass",
})
assert(not ok and city.machines.mixer.recipe == before, "Foreign city request mutated choices")
for _, invalid in ipairs({
	{ recipe = "unknown" },
	{ recipe = "brass" },
	{ priority = 5 },
	{ priority = 1.5 },
	{ enabled = 1 },
}) do
	local saved = fixture()
	saved.cities[1].machines = { mixer = { recipe = "no_recipe", priority = 3, enabled = true } }
	local candidate = assert(Migration.load(saved))
	local choice = candidate.cities[1].machines.mixer
	local oldRecipe, oldPriority, oldEnabled = choice.recipe, choice.priority, choice.enabled
	local request = {
		action = invalid.recipe and "selectMachineRecipe"
			or invalid.priority and "setMachinePriority"
			or "setMachineEnabled",
		city = 1,
		building = "mixer",
		recipe = invalid.recipe,
		priority = invalid.priority,
		enabled = invalid.enabled,
	}
	local accepted = Choices.apply(candidate, 1, request)
	assert(not accepted, "Invalid machine request was accepted")
	assert(
		choice.recipe == oldRecipe
			and choice.priority == oldPriority
			and choice.enabled == oldEnabled
	)
end
local invalidRecords = {
	{ recipe = "unknown", priority = 3, enabled = true },
	{ recipe = "no_recipe", priority = -1, enabled = true },
	{ recipe = "no_recipe", priority = 3, enabled = "yes" },
}
for _, record in ipairs(invalidRecords) do
	local saved = fixture()
	saved.cities[1].machines = { mixer = record }
	assert(not Migration.load(saved), "Malformed saved machine choice was repaired")
end
local foreign = fixture()
foreign.cities[1].machines = { mixer = { recipe = "no_recipe", priority = 3, enabled = true } }
foreign.cities[1].buildings.mixer = nil
assert(not Migration.load(foreign), "Machine choice without its building was accepted")
local paused = fixture()
paused.specialtySchema = 1
paused.nextSiteId = 2
paused.cities[1].sites = { works = { id = 1, kind = "works", x = 6, y = 4 } }
paused.cities[1].machines = {
	mixer = { recipe = "industry", priority = 4, enabled = false },
}
local stillSaved = assert(Migration.load(paused))
assert(stillSaved.cities[1].machines.mixer.recipe == "industry")
assert(stillSaved.cities[1].machines.mixer.enabled == false)
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local active = fixture()
for tech in pairs(Systems.techs) do
	active.players[1].techs[tech] = true
end
active.cities[1].buildings = { burner = true, mixer = true }
active.specialtySchema = 1
active.nextSiteId = 2
active.cities[1].sites = { works = { id = 1, kind = "works", x = 5, y = 4 } }
Systems.migrate(active)
World.reveal(active, Hex, Systems)
local choice = active.cities[1].machines.mixer
assert(choice.recipe == "no_recipe")
assert(Actions.apply(active, 1, {
	action = "selectMachineRecipe",
	city = 1,
	building = "mixer",
	recipe = "brass",
}, Systems))
assert(choice.recipe == "brass")
assert(Actions.apply(active, 1, {
	action = "setMachinePriority",
	city = 1,
	building = "mixer",
	priority = 2,
}, Systems))
assert(choice.priority == 2)
assert(Actions.apply(active, 1, {
	action = "setMachineEnabled",
	city = 1,
	building = "mixer",
	enabled = false,
}, Systems))
assert(choice.enabled == false)
local events = dofile("/games/civcraft/events.lua").forPlayer(active, 1)
assert(events.entries[#events.entries].content == "mixer disabled")
if fs and textutils then
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/machine-choice-validation"
	assert(Saves.writeFile(Saves.path(1), active))
	local resumed = assert(Saves.load(1))
	assert(resumed.cities[1].machines.mixer.recipe == "brass")
	assert(resumed.cities[1].machines.mixer.priority == 2)
	assert(resumed.cities[1].machines.mixer.enabled == false)
	assert(resumed.cities[1].machineStatus == nil)
end
print("CIVCRAFT: machine choice defaults, validation and persistence passed")
