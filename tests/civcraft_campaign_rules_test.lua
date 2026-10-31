local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Rules = dofile("/games/civcraft/campaign_rules.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Victory = dofile("/games/civcraft/victory.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local defaultLobby = Lifecycle.newLobby("default-campaign", ContentRules.default)
assert(
	defaultLobby.contentRules == "balance5"
		and defaultLobby.roundLimit == 250
		and ContentRules.hasSpecialties(defaultLobby),
	"Normal new campaigns default to Specialization V5"
)
local priorLobby = Lifecycle.newLobby("explicit-founders", "balance4")
assert(
	priorLobby.contentRules == "balance5"
		and priorLobby.roundLimit == 250
		and ContentRules.hasSpecialties(priorLobby)
		and ContentRules.startsWithSettler(priorLobby),
	"Historical lobby IDs normalize to the single current ruleset"
)
local function fixture()
	local world =
		{ width = 12, height = 10, tiles = {}, resources = {}, landmarks = {}, rails = {} }
	for y = 1, 10 do
		for x = 1, 12 do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local state = {
		version = 6,
		phase = "lobby",
		ruleset = "create",
		round = 1,
		world = world,
		players = {
			{ id = 1, name = "ONE", civ = "scholar", techs = {} },
			{ id = 2, name = "TWO", techs = {} },
		},
		cities = {
			{ id = 1, owner = 1, capitalOf = 1, x = 3, y = 4, buildings = {}, population = 2 },
			{ id = 2, owner = 2, capitalOf = 2, x = 9, y = 7, buildings = {}, population = 2 },
		},
		units = {},
	}
	Systems.migrate(state)
	return state
end

for _, speed in ipairs(Rules.speeds) do
	local state = fixture()
	assert(not Rules.configure(state, 2, { action = "gameSpeed", speed = speed }))
	assert(Rules.configure(state, 1, { action = "gameSpeed", speed = speed }))
	assert(state.roundLimit == Rules.presets[speed].rounds)
	local p, city = state.players[1], state.cities[1]
	assert(Systems.techCost("agriculture", p) == Rules.cost(24, state))
	p.settlersTrained = 3
	assert(Systems.projectCost("unit", "settler", p) == Rules.cost(52, state))
	state.phase = "game"
	assert(not Rules.configure(state, 1, { action = "gameSpeed", speed = "standard" }))
	p.techs.writing = true
	assert(Systems.research(p, "agriculture"))
	assert(Systems.queue(p, city, "building", "library", state, Hex))
	assert(not city.buildings.library)
	for _ = 1, Systems.projectCost("building", "library", p) + 30 do
		Systems.production(state, Hex)
	end
	assert(
		p.techs.agriculture and city.buildings.library,
		"Scaled research and construction resolve across turns"
	)
end
local state = fixture()
for _, version in ipairs({
	"baseline",
	"p1",
	"balance1",
	"balance2",
	"balance3",
	"balance4",
	"balance5",
}) do
	assert(not Rules.configure(state, 1, { action = "contentRules", version = version }))
	assert(state.contentRules == "balance5")
end
assert(
	not Rules.configure(
		state,
		1,
		{ action = "toggleVictory", victory = "industrial", enabled = true }
	)
)
assert(
	not Rules.configure(
		state,
		1,
		{ action = "toggleVictory", victory = "diplomatic", enabled = true }
	)
)
assert(
	not Rules.configure(state, 1, { action = "toggleVictory", victory = "score", enabled = false })
)
state.phase = "game"
state.players[1].industryTurns = 999
state.council = { victory = { id = 1, round = 1 } }
Victory.check(state, false)
assert(state.phase == "game", "Retired victory progress cannot terminate a current campaign")
for _, victory in ipairs({ "conquest", "expedition" }) do
	local current = fixture()
	current.phase = "game"
	if victory == "conquest" then
		current.cities[2].owner = 1
	else
		current.cities[1].buildings.dragon = true
	end
	Victory.check(current, false)
	assert(current.phase == "over" and current.winnerIDs[1] == 1)
end
state = fixture()
state.phase, state.round = "game", state.roundLimit
state.victories = { conquest = false, expedition = false, score = false }
Victory.check(state, false)
local expected = {}
for _ in ipairs(state.winnerIDs or {}) do
	expected[#expected + 1] = "SCORE"
end
assert(
	state.phase == "over" and #expected > 0 and state.victoryReason == table.concat(expected, " / "),
	"Score always resolves the deadline"
)
local source = fixture()
source.victories = { conquest = true }
local snapshot = World.forPlayer(source, 1)
snapshot.victories.conquest = false
assert(source.victories.conquest, "Observer changes cannot alter authoritative options")
print(
	"CIVCRAFT: current host-only options, scaled costs, enabled victories and mandatory Score passed"
)
