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
local Strategy = dofile("/games/civcraft/ai_strategy.lua")
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
	Systems.migrate(state)
	local player, city = state.players[1], state.cities[1]
	assert(Systems.techCost("agriculture", player) == Rules.cost(24, state))
	assert(Systems.projectCost("building", "farm", player) == Rules.cost(15, state))
	player.settlersTrained = 3
	assert(Systems.projectCost("unit", "settler", player) == Rules.cost(27, state))
	local growth = Systems.growth(player, city, state)
	assert(
		growth.threshold == Rules.cost(36, state) and growth.minimumTurns == Rules.cost(4, state)
	)
	state.phase = "game"
	assert(not Rules.configure(state, 1, { action = "gameSpeed", speed = "standard" }))
	player.researchTarget = "agriculture"
	player.techs.mining = true
	player.researchProgress.agriculture = Systems.techCost("agriculture", player) - 1
	city.project = {
		kind = "building",
		id = "mine",
		progress = Systems.projectCost("building", "mine", player) - 1,
	}
	Systems.production(state, Hex)
	assert(
		player.techs.agriculture and city.buildings.mine,
		"Actual research and production consume scaled costs"
	)
end

local legacy = fixture()
legacy.gameSpeed, legacy.players[1].gameSpeed = nil, nil
legacy.roundLimit = 91
Systems.migrate(legacy)
assert(
	legacy.roundLimit == 91 and Systems.techCost("agriculture", legacy.players[1]) == 24,
	"Old saves preserve their deadline and Standard progression"
)
assert(not Rules.configure(legacy, 1, { action = "gameSpeed", speed = "invalid" }))
for _, victory in ipairs({ "industrial", "expedition", "conquest" }) do
	assert(Rules.configure(legacy, 1, { action = "toggleVictory", victory = victory }))
end
assert(
	not Rules.configure(legacy, 1, { action = "toggleVictory", victory = "score" }),
	"The last enabled victory cannot be disabled"
)
legacy.phase = "game"
legacy.players[1].industryTurns = 99
legacy.cities[1].buildings.dragon = true
legacy.cities[2].owner = 1
Victory.check(legacy, false)
assert(legacy.phase == "game", "Disabled victories cannot end a game")
Victory.check(legacy, true)
assert(
	legacy.players[1].industryTurns == 0,
	"A disabled Industrial victory never accumulates its timer"
)
local view = World.forPlayer(legacy, 1)
assert(
	Strategy.review(view, legacy.players[1], 1).primary == "score",
	"AI chooses an enabled victory"
)
view.victories.conquest = true
assert(legacy.victories.conquest == false, "Campaign options in observer snapshots are detached")
legacy.round = legacy.roundLimit
Victory.check(legacy, false)
assert(legacy.phase == "over" and legacy.victoryReason == "SCORE")

local draw = fixture()
draw.phase, draw.round, draw.roundLimit = "game", 120, 120
draw.victories = { score = false }
Victory.check(draw, false)
assert(
	draw.phase == "over" and draw.victoryReason == "SCORE",
	"Current deadline always resolves Score"
)
for _, victory in ipairs({ "conquest", "expedition", "industrial" }) do
	local state = fixture()
	state.phase = "game"
	state.victories = { conquest = false, expedition = false, industrial = false, score = false }
	state.victories[victory] = true
	if victory == "conquest" then
		state.cities[2].owner = 1
	end
	if victory == "expedition" then
		state.cities[1].buildings.dragon = true
	end
	if victory == "industrial" then
		state.players[1].industryTurns = 10
	end
	Victory.check(state, false)
	if victory == "industrial" then
		assert(state.phase == "game", "Retired victory cannot be re-enabled")
	else
		assert(state.phase == "over" and state.winnerIDs[1] == 1, "Enabled victory still resolves")
	end
end
print(
	"CIVCRAFT: duration scaling, authoritative campaign options, enabled victories, AI choices and legacy compatibility passed."
)

-- Historical selection requests cannot restore an old engine.
local specialization = fixture()
for _, version in ipairs({
	"baseline",
	"p1",
	"balance1",
	"balance2",
	"balance3",
	"balance4",
	"balance5",
}) do
	assert(not Rules.configure(specialization, 1, { action = "contentRules", version = version }))
	assert(specialization.contentRules == "balance5")
end
print("PASS: current rules cannot be changed into historical gameplay")
