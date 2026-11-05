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
local falseBuilding = fixture()
falseBuilding.cities[1].buildings.mixer = false
Choices.migrate(falseBuilding)
Choices.migrate(falseBuilding)
assert(falseBuilding.cities[1].machines.mixer == nil)
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
	{ recipe = "no_recipe", priority = 0, enabled = true },
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
local aliased = fixture()
local shared = { recipe = "no_recipe", priority = 3, enabled = true }
aliased.cities[1].machines = { mixer = shared }
aliased.cities[2] = {
	id = 2,
	owner = 1,
	x = 8,
	y = 4,
	population = 2,
	buildings = { mixer = true },
	sites = { works = { id = 2, kind = "works", x = 9, y = 4 } },
	machines = { mixer = shared },
}
aliased.nextSiteId = 3
assert(not Migration.load(aliased), "Shared machine record was accepted")
aliased.cities[2].machines = aliased.cities[1].machines
assert(not Migration.load(aliased), "Shared city machine map was accepted")
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
local firstSite = fixture()
firstSite.cities[1].sites, firstSite.cities[1].machineStatus = {}, nil
for tech in pairs(Systems.techs) do
	firstSite.players[1].techs[tech] = true
end
Systems.migrate(firstSite)
World.reveal(firstSite, Hex, Systems)
local firstCity = firstSite.cities[1]
assert(firstCity.machines.mixer == nil)
Systems.economy(firstSite.players[1], firstSite)
assert(firstCity.machines.mixer == nil, "Forecast must not create choices")
assert(
	Actions.apply(
		firstSite,
		1,
		{ action = "placeSite", city = 1, kind = "works", x = 5, y = 4 },
		Systems
	)
)
firstCity.siteProjects[firstCity.project.id].progress = 100
Systems.production(firstSite, Hex)
assert(
	firstCity.sites.works and firstCity.machines.mixer.recipe == "no_recipe",
	"First Works completion immediately initializes retained completed machines"
)
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
local replay = assert(Migration.load(active))
local orders = {
	{
		action = "selectMachineRecipe",
		city = 1,
		building = "mixer",
		recipe = "brass",
	},
	{
		action = "setMachinePriority",
		city = 1,
		building = "mixer",
		priority = 2,
	},
	{
		action = "setMachineEnabled",
		city = 1,
		building = "mixer",
		enabled = false,
	},
}
for _, request in ipairs(orders) do
	assert(Actions.apply(active, 1, request, Systems))
	assert(Actions.apply(replay, 1, request, Systems))
	local left, right = active.cities[1].machines.mixer, replay.cities[1].machines.mixer
	assert(
		left.recipe == right.recipe
			and left.priority == right.priority
			and left.enabled == right.enabled
	)
end
assert(choice.enabled == false)
local events = dofile("/games/civcraft/events.lua").forPlayer(active, 1)
assert(events.entries[#events.entries].content == "mixer disabled")
local replayEvents = dofile("/games/civcraft/events.lua").forPlayer(replay, 1)
assert(
	events.entries[#events.entries].content == replayEvents.entries[#replayEvents.entries].content
)
local rival = {
	id = 2,
	name = "B",
	civ = "forge",
	techs = {},
	visible = { ["8:8"] = true },
}
active.players[1].visible = { ["8:8"] = true }
active.players[2] = rival
active.cities[2] = {
	id = 2,
	owner = 2,
	x = 8,
	y = 8,
	population = 3,
	buildings = { mixer = true },
	sites = { works = { id = 2, kind = "works", x = 9, y = 8 } },
	machines = { mixer = { recipe = "no_recipe", priority = 3, enabled = true } },
}
active.nextId, active.nextSiteId = 3, 3
local captured = dofile("/games/civcraft/presentation.lua").capture(active, 1)
assert(captured.machinerySchema == 1)
local ownerView, rivalView
for _, cityView in ipairs(captured.cities) do
	if cityView.id == 1 then
		ownerView = cityView
	end
	if cityView.id == 2 then
		rivalView = cityView
	end
end
assert(ownerView.machines.mixer.recipe == "brass")
ownerView.machines.mixer.recipe = "industry"
assert(active.cities[1].machines.mixer.recipe == "brass", "Captured choices were not detached")
assert(rivalView and rivalView.machines == nil and rivalView.machineStatus == nil)
if fs and textutils then
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/machine-choice-validation"
	assert(Saves.writeFile(Saves.path(1), active))
	local resumed = assert(Migration.load(assert(Saves.load(1))))
	assert(resumed.cities[1].machines.mixer.recipe == "brass")
	assert(resumed.cities[1].machines.mixer.priority == 2)
	assert(resumed.cities[1].machines.mixer.enabled == false)
	assert(resumed.cities[1].machineStatus == nil)
end
print("CIVCRAFT: machine choice defaults, validation and persistence passed")
