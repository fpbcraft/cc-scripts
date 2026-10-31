local nativeDofile = dofile
dofile = function(p)
	if p:sub(1, 16) == "/games/civcraft/" then
		return nativeDofile(p:sub(2))
	end
	return nativeDofile(p)
end
local S = assert(loadfile("games/civcraft/systems.lua"))()
local H = assert(loadfile("games/civcraft/hex.lua"))()
local W = assert(loadfile("games/civcraft/world.lua"))()
local state = {
	version = 3,
	nextId = 3,
	phase = "game",
	players = {
		{ id = 1, name = "P1", civ = "verdant", techs = {}, food = 30, wood = 60, science = 0 },
		{ id = 2, name = "P2", civ = "iron", ai = true, food = 30, wood = 60, science = 0 },
	},
	cities = { { id = 1, owner = 1, x = 3, y = 3 }, { id = 2, owner = 2, x = 16, y = 10 } },
	units = {},
}
state.world = W.generate(802, "compact", 2, "continents")
S.migrate(state)
local city, p = state.cities[1], state.players[1]
assert(state.version == 6 and city.population == 2)
assert(not S.canResearch(p, "writing"), "Research prerequisites enforced")
assert(S.research(p, "agriculture"))
assert(
	p.researchTarget == "agriculture" and not p.techs.agriculture,
	"Research should be scheduled, not instantly purchased"
)
-- Use a controlled worked-hex fixture rather than relying on generated
-- biome/resource composition or old 2-food plains expectations.
for key in pairs(city.claimed) do
	if key ~= W.key(city.x, city.y) then
		state.world.tiles[key] = "hills"
		state.world.geography[key] = nil
		state.world.resources[key] = nil
		state.world.landmarks[key] = nil
	end
end
state.world.tiles["4:3"] = "hills"
state.world.geography["4:3"] = nil -- Override generated biome with a plains hill.
state.world.resources["4:3"] = nil
state.world.tiles["3:4"] = "plains"
state.world.geography["3:4"] = nil -- Ensure the iron hex has 1/1/1 yields.
state.world.resources["3:4"] = "iron"
city.worked = {}
S.ensureWorkers(state, city)
assert(S.assign(city, "idle", "wood", state))
assert(city.jobs.wood == 1 and S.idle(city) == 1)
local beforeStaffing = S.yields(p, city, state, H)
assert(S.assign(city, "wood", "science", state))
local afterStaffing = S.yields(p, city, state, H)
assert(
	afterStaffing.science > beforeStaffing.science,
	"Job shortcut chooses a science-yielding tile"
)
assert(city.jobs.wood == 0 and city.jobs.science == 1)
assert(not S.assign(city, "wood", "science", state))
city.worked = {}
state.world.tiles["2:3"] = "forest"
state.world.geography["2:3"] = nil
state.world.resources["2:3"] = nil
state.world.tiles["3:2"] = "forest"
state.world.geography["3:2"] = nil
state.world.resources["3:2"] = nil
S.ensureWorkers(state, city)
assert(S.assign(city, "idle", "food", state))
assert(S.assign(city, "idle", "food", state))
local oldPop = city.population
for i = 1, 40 do
	S.production(state, H)
end
assert(
	p.techs.agriculture and not p.researchTarget,
	"Research completes after enough global turn science"
)
assert(city.population > oldPop, "Food surplus grows population")
assert(
	city.jobs.food + city.jobs.wood + city.jobs.science <= city.population,
	"Population allocation is conserved"
)
assert(S.research(p, "writing"))
for i = 1, S.techCost("writing") do
	S.production(state, H)
end
assert(p.techs.writing, "Prerequisite tech completed over turns")
assert(S.build(p, city, "library", state, H))
assert(not city.buildings.library, "Buildings must enter a production project")
local beforeWood = p.wood
assert(city.project.kind == "building" and city.project.id == "library")
for _ = 1, S.projectCost("building", "library", p) do
	if not city.project then
		break
	end
	S.production(state, H)
end
assert(city.buildings.library and not city.project, "Building finishes on turn boundary")
assert(p.wood >= beforeWood, "No instant building purchase")
assert(not S.canRecruit(p, "horseman", state, H), "Units require technology")
assert(S.research(p, "husbandry"))
for i = 1, S.techCost("husbandry") do
	S.production(state, H)
end
assert(S.research(p, "horseback"))
for i = 1, S.techCost("horseback") do
	S.production(state, H)
end
assert(p.techs.horseback)
assert(
	S.canRecruit(p, "horseman", state, H),
	"Horse riding and animal husbandry unlock cavalry without an extra strategic stock"
)
local unitBefore = #state.units
assert(S.queue(p, city, "unit", "scout", state, H))
for i = 1, 8 do
	S.production(state, H)
end
assert(#state.units > unitBefore, "Produced units spawn after turns")
local ai = state.players[2]
ai.ready = false
S.aiTurn(state, ai, H)
assert(
	ai.ready and ai.researchTarget and state.cities[2].project,
	"AI selects research and production without instant purchases"
)
print("CIVCRAFT: turn research/production, population, resources, AI OK")
