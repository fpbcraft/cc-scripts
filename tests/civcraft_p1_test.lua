local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("/games/civcraft/systems.lua")
local H = dofile("/games/civcraft/hex.lua")
local W = dofile("/games/civcraft/world.lua")
local Rules = dofile("/games/civcraft/campaign_rules.lua")
local E = dofile("/games/civcraft/encyclopedia.lua")
local function fixture(version)
	local state = {
		version = 6,
		ruleset = "create",
		contentRules = version,
		phase = "game",
		round = 1,
		nextId = 3,
		players = { { id = 0, civ = "forge", techs = {}, gold = 100 } },
		units = {},
		cities = {
			{
				id = 1,
				owner = 0,
				capitalOf = 0,
				x = 5,
				y = 5,
				population = 2,
				foodStore = 100,
				worked = {},
				buildings = {},
			},
		},
		world = { width = 12, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} },
	}
	for y = 1, 10 do
		for x = 1, 12 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	S.migrate(state)
	return state, state.players[1], state.cities[1]
end
local state, p, c = fixture()
assert(S.centerYields(p, c, state).science == 1 and not S.canBuild(p, c, "farm", state))
assert(S.projectCost("unit", "scout", p) == 5 and S.projectCost("unit", "settler", p) == 12)
assert(not S.queue(p, c, "project", "trade", state, H))
state, p, c = fixture("p1")
assert(S.centerYields(p, c, state).science == 2 and S.canBuild(p, c, "farm", state))
assert(S.projectCost("unit", "scout", p) == 15 and S.projectCost("unit", "warrior", p) == 20)
assert(S.projectCost("unit", "settler", p) == 40)
p.settlersTrained = 3
assert(S.projectCost("unit", "settler", p) == 76)
assert(S.units.settler.upkeep == 1, "P1 must not silently change upkeep")
p.gameSpeed = "quick"
assert(S.projectCost("unit", "settler", p) == 51)
p.gameSpeed = "epic"
assert(S.projectCost("unit", "settler", p) == 114)
p.gameSpeed = "standard"
p.civ = "scholar"
assert(S.centerYields(p, c, state).science == 3)
local originalCapital = c.capitalOf
c.capitalOf = nil
assert(S.centerYields(p, c, state).science == 2)
c.capitalOf = originalCapital
p.civ = "forge"
c.buildings.farm = true
assert(S.centerYields(p, c, state).food == 3)
p.techs.agriculture = true
assert(S.centerYields(p, c, state).food == 4)
p.techs.agriculture = nil
assert(not S.queue(p, c, "project", "ponder", state, H))
assert(S.queue(p, c, "project", "tend", state, H))
local food = c.foodStore
for _ = 1, 2 do
	S.production(state, H)
end
-- 2 passive food + 1 farm - 4 consumption = -1 per round;
-- one industry each round converts into one extra food after two rounds.
assert(c.foodStore == food - 1)
assert(c.projectRemainders.tend == 0 and c.project.kind == "project")
c.buildings.library = true
assert(S.queue(p, c, "project", "ponder", state, H))
local science = p.science
for _ = 1, 4 do
	S.production(state, H)
end
assert(p.science == science + 4 * 4, "Ponder must pause without a research target")
assert(c.projectRemainders.ponder == nil)
p.researchTarget = "mining"
local progress = (p.researchProgress.mining or 0)
for _ = 1, 4 do
	S.production(state, H)
end
assert(p.researchProgress.mining == progress + 4 * 4 + 1)
assert(c.projectRemainders.ponder == 0)
S.production(state, H)
assert(c.projectRemainders.ponder == 1)
S.production(state, H)
assert(p.techs.mining and p.researchTarget == nil and c.projectRemainders.ponder == 2)
assert(S.queue(p, c, "building", "mine", state, H))
S.production(state, H)
local construction = c.project.progress
assert(construction == 1)
c.buildings.market = true
c.foodStore = 0
assert(S.queue(p, c, "project", "trade", state, H))
local gold = p.gold
local passive = S.treasury(p, state, false).net
for _ = 1, 2 do
	S.production(state, H)
end
assert(p.gold == gold + 2 * passive + 1)
assert(c.projectProgress["building:mine"] == construction)
assert(S.queue(p, c, "project", "ponder", state, H))
assert(c.projectRemainders.ponder == 2 and c.projectRemainders.trade == 0)
assert(S.queue(p, c, "building", "mine", state, H) and c.project.progress == construction)
local oldGold = p.gold
assert(S.queue(p, c, "none", nil, state, H))
S.production(state, H)
assert(p.gold == oldGold + S.treasury(p, state, false).net)
local fake = { phase = "lobby", players = { { id = 0 } } }
assert(
	Rules.configure(fake, 0, { action = "contentRules", version = "p1" })
		and fake.contentRules == "p1"
)
fake.phase = "game"
assert(not Rules.configure(fake, 0, { action = "contentRules", version = "baseline" }))
local desc = E.describe("buildings", { id = "farm", record = S.buildings.farm }, p)
assert(table.concat(desc, " "):find("Available immediately", 1, true))
if fs and textutils then
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/p1-save-validation"
	assert(S.queue(p, c, "project", "ponder", state, H))
	assert(Saves.writeFile(Saves.path(3), state))
	local restored = S.migrate(assert(Saves.load(3)))
	assert(restored.contentRules == "p1" and restored.players[1].contentRules == "p1")
	assert(restored.cities[1].projectRemainders.ponder == 2)
	assert(restored.cities[1].projectProgress["building:mine"] == construction)
	assert(
		restored.cities[1].project.kind == "project" and restored.cities[1].project.id == "ponder"
	)
	S.production(state, H)
	S.production(restored, H)
	assert(
		state.players[1].gold == restored.players[1].gold
			and state.players[1].science == restored.players[1].science
	)
	assert(state.cities[1].foodStore == restored.cities[1].foodStore)
	print(
		"CIVCRAFT: native P1 save/load preserves profile, civilian remainder and paused construction with matching continuation."
	)
end
print(
	"CIVCRAFT: P1 economy versions, costs, capital science, early farm, project conversions, pause and retained progress passed."
)
