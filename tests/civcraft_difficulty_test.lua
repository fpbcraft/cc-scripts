local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local Coordination = dofile("/games/civcraft/ai_coordination.lua")
local Strategy = dofile("/games/civcraft/ai_strategy.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Tactics = dofile("/games/civcraft/ai_tactics.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Settlement = dofile("/games/civcraft/ai_settlement.lua")
local state = {
	phase = "lobby",
	players = {
		{ id = 0, name = "HOST", techs = {} },
		{ id = -1, name = "AI", ai = true, techs = {} },
	},
	cities = {},
	units = {},
	hostileMode = "dangerous",
}
assert(Difficulty.id(state.players[2]) == "prince")
assert(not Difficulty.configure(state, -1, { playerID = -1, level = "deity" }))
assert(not Difficulty.configure(state, 0, { playerID = 0, level = "deity" }))
assert(not Difficulty.configure(state, 0, { playerID = -1, level = "cheat" }))
assert(Difficulty.configure(state, 0, { playerID = -1 }))
assert(state.players[2].aiDifficulty == "king" and state.hostileMode == "dangerous")
assert(World.forPlayer(state, 0).players[2].aiDifficulty == "king")
state.phase = "game"
assert(not Difficulty.configure(state, 0, { playerID = -1, level = "settler" }))
local choices =
	{ { score = 100, id = "best" }, { score = 98, id = "second" }, { score = 96, id = "third" } }
assert(Difficulty.choices(choices, { id = 0 }, 4, 0) == choices)
assert(Difficulty.choices(choices, { id = 0, aiDifficulty = "settler" }, 4, 0)[1].id == "third")
assert(Difficulty.choices(choices, { id = 0, aiDifficulty = "chieftain" }, 4, 0)[1].id == "second")
assert(choices[1].id == "best", "Quality sampling never changes the ranking input")
local function fixture(level)
	local player = {
		id = 0,
		name = "AI",
		ai = true,
		aiDifficulty = level,
		civ = "iron",
		techs = {},
		gold = 50,
	}
	local world = {
		width = 18,
		height = 12,
		tiles = {},
		resources = {},
		rails = {},
		landmarks = {},
		seed = 21,
	}
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local game = {
		version = 6,
		ruleset = "create",
		phase = "game",
		round = 1,
		players = { player, { id = 1, name = "RIVAL", civ = "forge", techs = {} } },
		cities = {
			{ id = 1, owner = 0, capitalOf = 0, x = 3, y = 5, population = 2, buildings = {} },
		},
		units = {
			{ id = 3, owner = 0, kind = "archer", x = 6, y = 5, movesLeft = 2, hp = 100 },
			{ id = 4, owner = 0, kind = "archer", x = 7, y = 4, movesLeft = 2, hp = 100 },
			{ id = 5, owner = 1, kind = "warrior", x = 8, y = 5, movesLeft = 2, hp = 100 },
		},
		world = world,
		nextId = 10,
	}
	Systems.migrate(game)
	World.reveal(game, Hex, Systems)
	for key in pairs(world.tiles) do
		player.visible[key], player.explored[key] = true, true
	end
	Strategy.review(World.forPlayer(game, 0), player, 21)
	return game, player
end
local baseIncome, baseCost, basePower
for _, level in ipairs(Difficulty.order) do
	local game, player = fixture(level)
	local income = Systems.treasury(player, game).income
	local cost = Systems.techCost("agriculture", player)
	local power = Combat.power(game.units[1], Systems, false, game)
	baseIncome, baseCost, basePower = baseIncome or income, baseCost or cost, basePower or power
	assert(income == baseIncome and cost == baseCost and power == basePower)
	assert(player.gold == 50 and game.units[1].movesLeft == 2)
	local profile = Personalities.forCivilization(player.civ)
	assert(
		profile.aggression == 85 and profile.ambition == 85,
		"Quality never rewrites civilization personality"
	)
	local view = World.forPlayer(game, 0)
	local ranked = Tactics.ranked(view, player, game.units[1], Systems)
	assert(#ranked <= Difficulty.profile(player).candidates + 1)
	game.round = 4
	Strategy.review(World.forPlayer(game, 0), player, 21)
	assert(player.aiPlan.lastReviewRound == (level == "deity" and 4 or 1))
	assert(World.forPlayer(game, 1).players[1].aiDifficulty == level)
	assert(not World.forPlayer(game, 1).players[1].aiPlan)
end
local game, player = fixture("king")
local unit, target = game.units[1], game.units[3]
local order
for _, move in ipairs(Hex.reachable(World.forPlayer(game, 0), unit, 0, Systems)) do
	if move.attack and move.x == target.x and move.y == target.y then
		order = move
	end
end
assert(order)
local forecast, bonus, startingHP
for hp = 20, 100 do
	target.hp = hp
	local view = World.forPlayer(game, 0)
	forecast = Combat.predictOrder(view, unit, order, Systems)
	bonus = Coordination.followup(view, player, unit, order, forecast, unit, Systems, 2)
	if bonus >= 40 then
		startingHP = hp
		break
	end
end
assert(
	startingHP and not forecast.defenderDied,
	"A bounded friendly follow-up finds a combined kill"
)
assert(
	target.hp == startingHP and unit.movesLeft == 2 and not unit.attackedRound,
	"Lookahead never changes the live units or their budgets"
)
local coordinatedOption
for _, option in ipairs(Tactics.ranked(World.forPlayer(game, 0), player, unit, Systems)) do
	if option.x == target.x and option.y == target.y then
		coordinatedOption = option
	end
end
assert(
	coordinatedOption and coordinatedOption.coordination >= 40,
	"Harder tactical rankings use the legal finishing opportunity"
)
player.aiDifficulty = "prince"
for _, option in ipairs(Tactics.ranked(World.forPlayer(game, 0), player, unit, Systems)) do
	assert(
		not option.coordination or option.coordination == 0,
		"Prince preserves its existing tactical evaluation"
	)
end
player.aiDifficulty = "king"

local view = World.forPlayer(game, 0)
assert(Coordination.followup(view, player, unit, order, forecast, unit, Systems, 0) == 0)
game.units[2].movesLeft = 0
assert(
	Coordination.followup(World.forPlayer(game, 0), player, unit, order, forecast, unit, Systems, 2)
		== 0
)
game.units[2].movesLeft = 2
assert(
	Actions.apply(
		game,
		0,
		{ action = "move", unitID = unit.id, sx = unit.x, sy = unit.y, x = target.x, y = target.y },
		Systems
	)
)
local ally = game.units[2]
assert(
	Actions.apply(
		game,
		0,
		{ action = "move", unitID = ally.id, sx = ally.x, sy = ally.y, x = target.x, y = target.y },
		Systems
	)
)
local alive = false
for _, current in ipairs(game.units) do
	if current.id == target.id then
		alive = true
	end
end
assert(not alive, "The forecasted coordinated kill executes through ordinary actions")
game, player = fixture("prince")
view = World.forPlayer(game, 0)
local baseline = Settlement.value(view, player, 6, 8)
player.aiDifficulty = "king"
assert(
	Settlement.value(view, player, 6, 8) > baseline,
	"Harder AI accounts for observed future city tiles"
)
print(
	"CIVCRAFT: five difficulty levels, host validation, public settings, unchanged resources/budgets, deterministic quality and legal cooperative lookahead passed."
)
