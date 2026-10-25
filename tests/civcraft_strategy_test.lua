local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Personalities = dofile("games/civcraft/ai_personalities.lua")
local Strategy = dofile("games/civcraft/ai_strategy.lua")
local AI = dofile("games/civcraft/ai.lua")
local Systems = dofile("games/civcraft/systems.lua")
local World = dofile("games/civcraft/world.lua")

local function scenario(civ, id)
	local player = { id = id or 1, civ = civ, gold = 100, techs = {} }
	local view = {
		observerID = player.id,
		round = 1,
		roundLimit = 180,
		players = { player, { id = 9, industryTurns = 0 } },
		units = {},
		cities = {
			{ id = 10, owner = player.id, capitalOf = player.id, x = 3, y = 3, buildings = {} },
		},
	}
	return view, player
end
local expected = {
	verdant = "guardian",
	iron = "conqueror",
	scholar = "scholar",
	nomad = "expansionist",
	mariner = "expansionist",
	forge = "industrialist",
	highland = "guardian",
	merchant = "merchant",
	sentinel = "guardian",
	wild = "expansionist",
}
for civ, archetype in pairs(expected) do
	assert(Personalities.forCivilization(civ).archetype == archetype)
end
local profile = Personalities.forCivilization("scholar")
profile.aggression = 100
assert(
	Personalities.forCivilization("scholar").aggression == 20,
	"Profiles cannot mutate shared preferences"
)
for _, civ in ipairs({ "scholar", "forge", "iron", "merchant" }) do
	local firstGoal
	for _, id in ipairs({ 1, 2, 103, 104 }) do
		local view, player = scenario(civ, id)
		local plan = Strategy.review(view, player, 802)
		firstGoal = firstGoal or plan.primary
		assert(plan.primary == firstGoal, "Civilization goals cannot depend on computer ID parity")
		assert(player.aiPlan == plan and plan.version == 1 and plan.revision == 1)
	end
end

local view, player = scenario("scholar")
local plan = Strategy.review(view, player, 13)
assert(plan.primary == "expedition" and plan.citySpecializations[10] == "science")
for round = 2, 10 do
	view.round = round
	Strategy.review(view, player, 13)
	assert(plan.lastReviewRound == 1 and plan.revision == 1)
end
view.round = 11
Strategy.review(view, player, 13)
assert(plan.reviewReason == "periodic" and plan.lastReviewRound == 11 and plan.revision == 1)
view.round = 12
player.gold = -5
Strategy.review(view, player, 13)
assert(plan.emergency == "avoidBankruptcy" and plan.primary == "expedition")
assert(plan.reviewReason == "treasuryShock")
player.gold = 100
view.units = { { id = 20, owner = 9, kind = "warrior", x = 4, y = 3 } }
Strategy.review(view, player, 13)
assert(plan.emergency == "defendCapital" and plan.primary == "expedition")
view.units = {}
view.cities[2] = { id = 11, owner = player.id, x = 8, y = 8, buildings = {} }
Strategy.review(view, player, 13)
view.cities[2] = nil
view.round = 13
Strategy.review(view, player, 13)
assert(plan.reviewReason == "cityLoss" and not plan.citySpecializations[11])
player.techs.astronomy = true
view.round = 14
Strategy.review(view, player, 13)
assert(plan.reviewReason == "decisiveTechnology")
view.players[2].industryTurns = 7
view.round = 15
Strategy.review(view, player, 13)
assert(plan.reviewReason == "rivalVictory" and plan.emergency == "contestVictory")
view.round = 16
Strategy.review(view, player, 13)
assert(plan.lastReviewRound == 15, "An unchanged public warning does not force repeated reviews")
Strategy.signal(player, "newWar")
Strategy.review(view, player, 13)
assert(plan.reviewReason == "newWar" and player.strategySignal == nil)

-- A material challenger can win a deliberate reassessment; small fluctuations cannot.
for i = 2, 8 do
	view.cities[i] = {
		id = 10 + i,
		owner = player.id,
		x = i,
		y = 8,
		buildings = { bank = true, station = true },
	}
end
Strategy.signal(player, "resourceShock")
Strategy.review(view, player, 13)
assert(plan.primary == "industrial" and plan.revision == 2 and plan.revisionRound == 16)

local hiddenState = {
	phase = "game",
	round = 1,
	players = {
		{ id = 1, civ = "scholar", gold = 100, techs = {}, visible = {}, explored = {} },
		{ id = 2, techs = {} },
	},
	cities = { { id = 1, owner = 1, capitalOf = 1, x = 3, y = 3, buildings = {} } },
	units = { { id = 5, owner = 2, kind = "warrior", x = 4, y = 3 } },
	world = { width = 10, height = 10, seed = 22, tiles = {}, landmarks = {}, resources = {} },
}
local ai = hiddenState.players[1]
local safePlan = AI.beginTurn(hiddenState, ai)
assert(not safePlan.emergency, "A hidden nearby army cannot affect the strategic director")
ai.visible["4:3"] = true
AI.beginTurn(hiddenState, ai)
assert(safePlan.emergency == "defendCapital")
local other = World.forPlayer(hiddenState, 2)
for _, publicPlayer in ipairs(other.players) do
	assert(not publicPlayer.aiPlan, "Rival snapshots cannot expose strategic plans")
end

-- Restore the complete persisted table, then continue the incumbent review schedule.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end
local restored = copy(player)
view.players[1] = restored
view.round = 17
local continued = Strategy.review(view, restored, 13)
assert(
	continued.primary == "industrial"
		and continued.revision == 2
		and continued.lastReviewRound == 16
)
for id in pairs(Systems.techs) do
	restored.techs[id] = true
end
restored.techs.mechanicalcrafting = nil
restored.techs.astronomy = nil
local first = AI.research(restored, Systems)
assert(first == "mechanicalcrafting", "Industrial strategy selects its own late-game fork")
restored.id = 102
assert(
	AI.research(restored, Systems) == first,
	"Research follows the saved goal rather than ID parity"
)
local lateView, latePlayer = scenario("forge")
Strategy.review(lateView, latePlayer, 13)
lateView.round = 170
assert(
	Strategy.review(lateView, latePlayer, 13).primary == "score",
	"A low-progress empire may deliberately pivot to score near the round cap"
)
assert(not pcall(Strategy.review, { observerID = 9 }, player, 13))
print(
	"CIVCRAFT: fixed personalities, saved stable goals, deliberate reviews, emergencies and observer-only strategy passed."
)
