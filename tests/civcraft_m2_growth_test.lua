local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("/games/civcraft/systems.lua")
local H = dofile("/games/civcraft/hex.lua")
local W = dofile("/games/civcraft/world.lua")
local C = dofile("/games/civcraft/settlement_capacity.lua")
local E = dofile("/games/civcraft/encyclopedia.lua")
local Details = dofile("/games/civcraft/research_details.lua")
local Production = dofile("/games/civcraft/ai_production.lua")
local function fixture(version)
	local state = {
		version = 6,
		ruleset = "create",
		contentRules = version or "balance2",
		phase = "game",
		round = 1,
		nextId = 3,
		players = {
			{ id = 0, civ = "forge", techs = { crafting = true, masonry = true }, gold = 100 },
		},
		units = {},
		cities = {
			{
				id = 1,
				owner = 0,
				capitalOf = 0,
				x = 5,
				y = 5,
				population = 2,
				foodStore = 0,
				jobs = { food = 2, wood = 0, science = 0 },
				buildings = { farm = true },
			},
		},
	}
	S.migrate(state)
	return state, state.players[1], state.cities[1]
end
local state, p, c = fixture()
assert(S.projectCost("unit", "settler", p) == 28)
p.settlersTrained = 2
assert(S.projectCost("unit", "settler", p) == 44)
p.settlersTrained = 0
assert(S.canBuild(p, c, "housing", state) and S.canBuild(p, c, "well", state))
local amounts = { 1, 1, 0.5, 0.25, 0.25, 0.125, 0.125 }
for pop, factor in ipairs(amounts) do
	assert(C.factor(pop, 4) == factor)
end
assert(S.settlementCapacity(state, c).total == 4)
c.buildings.housing, c.buildings.well, c.buildings.market = true, true, true
assert(S.settlementCapacity(state, c).total == 9)
state.world = { width = 12, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} }
state.world.tiles[W.key(4, 5)] = "water"
local sources = S.settlementCapacity(state, c)
assert(sources.total == 10 and sources.water == 1 and #sources.sources == 3)
assert(sources.sources[1].id == "housing" and sources.sources[2].id == "market")
assert(c.capacity == nil, "Capacity is derived, not another persistent meter")
state.world = nil
c.buildings = { farm = true }
c.population = 3
c.jobs.food = 3
local g = S.growth(p, c, state)
assert(g.surplus == 1 and g.foodGain == 0.5 and g.minimumTurns == 8 and g.capacity == 4)
c.foodStore = 100
c.growthAge = 0
assert(S.growth(p, c, state).turns == 8, "Stored food must not bypass capacity's minimum time")
c.population = 4
c.jobs.food = 0
assert(
	S.growth(p, c, state).foodGain == S.growth(p, c, state).surplus,
	"Starvation is not discounted"
)
-- Recruitment spends population only after placement succeeds.
local passable = true
local hex = {
	neighbours = function()
		return {}
	end,
	passable = function()
		return passable
	end,
}
state, p, c = fixture()
assert(S.queue(p, c, "unit", "settler", state, hex))
c.project.progress = 100
passable = false
S.production(state, hex)
assert(#state.units == 0 and c.population == 2 and p.settlersTrained == 0 and c.project)
passable = true
S.production(state, hex)
assert(#state.units == 1 and c.population == 1 and p.settlersTrained == 1 and not c.project)
assert(c.jobs.food + c.jobs.wood + c.jobs.science <= c.population)
local ok, reason = S.queue(p, c, "unit", "settler", state, hex)
assert(not ok and reason:find("two population", 1, true))
-- A queued Settler pauses below minimum population and resumes after growth.
c.project = { kind = "unit", id = "settler", progress = 100 }
c.foodStore = 0
c.jobs.food = 1
S.production(state, hex)
assert(c.project.progress == 100 and #state.units == 1)
c.foodStore = 100
c.growthAge = 100
c.buildings.farm = true
-- Remove the first unit so a newly eligible completion has a spawn tile.
state.units = {}
S.production(state, hex)
assert(
	#state.units == 1 and c.population == 1 and p.settlersTrained == 2,
	"Growth resolves before Settler completion, spending the newly available citizen once"
)
for _, version in ipairs({ "baseline", "p1", "balance1" }) do
	state, p, c = fixture(version)
	assert(not S.canBuild(p, c, "housing", state) and not S.canBuild(p, c, "well", state))
	assert(S.growth(p, c, state).capacity == nil)
	assert(S.queue(p, c, "unit", "settler", state, hex))
	c.project.progress = 100
	S.production(state, hex)
	assert(c.population == 2 and #state.units == 1, "Old profiles retain population-free Settlers")
	for _, entry in ipairs(E.entries("buildings", state)) do
		assert(entry.id ~= "housing" and entry.id ~= "well")
	end
	for _, entry in ipairs(Details.unlocks(S, "crafting", p)) do
		assert(entry.id ~= "housing")
	end
end
state, p, c = fixture()
local found = false
for _, entry in ipairs(Details.unlocks(S, "crafting", p)) do
	if entry.id == "housing" then
		found = true
	end
end
assert(found)
local settler =
	table.concat(E.describe("units", { id = "settler", record = S.units.settler }, p, state), " ")
assert(settler:find("28 industry", 1, true) and settler:find("one citizen", 1, true))
local developmentRank
c.population = 3
c.jobs.food = 3
for _, item in ipairs(Production.ranked(state, p, c, S, false)) do
	if item.id == "housing" then
		developmentRank = item.score
	end
end
assert(
	developmentRank and developmentRank > 0,
	"AI values capacity with constrained positive growth"
)
-- Real worked tiles must shrink with the departing citizen.
state, p, c = fixture()
state.world = { width = 12, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} }
for y = 1, 10 do
	for x = 1, 12 do
		state.world.tiles[W.key(x, y)] = "plains"
	end
end
S.migrate(state)
c.worked = nil
S.ensureWorkers(state, c)
local workers = 0
for _ in pairs(c.worked) do
	workers = workers + 1
end
assert(workers == 2)
assert(S.queue(p, c, "unit", "settler", state, H))
c.project.progress = 100
S.production(state, H)
workers = 0
for _ in pairs(c.worked) do
	workers = workers + 1
end
assert(c.population == 1 and workers <= 1 and #state.units == 1)
if fs and textutils then
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/m2-growth-save-validation"
	c.foodStore = 3.125
	c.buildings.housing = true
	assert(Saves.writeFile(Saves.path(1), state))
	local restored = S.migrate(assert(Saves.load(1)))
	assert(restored.contentRules == "balance2" and restored.cities[1].foodStore == 3.125)
	assert(S.settlementCapacity(restored, restored.cities[1]).total == 6)
	assert(restored.players[1].settlersTrained == 1 and restored.cities[1].population == 1)
	S.production(restored, H)
	assert(
		restored.cities[1].population == 1 and #restored.units == 1,
		"Reload cannot repeat a completed citizen debit"
	)
end
-- Inspect actual row generation without substituting rule calculations.
local Inspector = dofile("/games/civcraft/inspector.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local originalRows = Panels.rows
local captured = {}
Panels.rows = function(_, _, rows)
	for _, row in ipairs(rows) do
		if row.text then
			captured[#captured + 1] = row.text
		end
	end
end
local renderer = { buttons = {} }
function renderer:fill() end
function renderer:outline() end
function renderer:text() end
function renderer:button() end
function renderer:textWidth(value)
	return #tostring(value) * 4
end
local ui = {
	r = renderer,
	playerID = 0,
	selected = { x = c.x, y = c.y, kind = "city" },
	cityPanel = "overview",
}
Inspector.draw(ui, state, p, { x = 1, y = 1, w = 220, h = 200 }, true)
local output = table.concat(captured, " ")
assert(output:find("CAPACITY", 1, true) and output:find("GROWTH FOOD", 1, true))
captured = {}
ui.cityPanel = "production"
c.project = { kind = "unit", id = "settler", progress = 100 }
Inspector.draw(ui, state, p, { x = 1, y = 1, w = 220, h = 200 }, true)
assert(table.concat(captured, " "):find("SETTLER PAUSED", 1, true))
Panels.rows = originalRows
print(
	"PASS: M2 capacity sources, growth curve, Settler population transactions, legacy content and AI valuation"
)
