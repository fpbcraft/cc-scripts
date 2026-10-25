local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Actions = dofile("/games/civcraft/actions.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local DiplomaticAI = dofile("/games/civcraft/diplomatic_ai.lua")
local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Perception = dofile("/games/civcraft/diplomatic_perception.lua")
local UnitMovement = dofile("/games/civcraft/unit_movement.lua")
local AI = dofile("/games/civcraft/ai.lua")
local function fixture()
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		players = {},
		cities = {},
		units = {},
		world = { width = 20, height = 14, tiles = {}, resources = {}, landmarks = {}, rails = {} },
		diplomacy = Diplomacy.new(),
		scheduler = Scheduler.new(),
	}
	for y = 1, 14 do
		for x = 1, 20 do
			state.world.tiles[World.key(x, y)] = "plains"
		end
	end
	for id = 1, 3 do
		state.players[id] = {
			id = id,
			name = "PLAYER " .. id,
			civ = id == 3 and "verdant" or "iron",
			techs = {},
			gold = 100,
		}
		state.cities[id] = {
			id = id,
			owner = id,
			capitalOf = id,
			x = id * 5,
			y = 6,
			population = 2,
			buildings = {},
		}
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	return state
end
local function propose(state, from, to, kind, terms)
	assert(
		Actions.apply(
			state,
			from,
			{ action = "diplomaticOffer", target = to, kind = kind, terms = terms },
			Systems
		)
	)
	return state.diplomacy.offers[#state.diplomacy.offers]
end
local function reply(state, actor, offer, response)
	return Actions.apply(
		state,
		actor,
		{ action = "diplomaticReply", offerID = offer.id, response = response },
		Systems
	)
end
local state = fixture()
state.players[2].stockpile.iron = 2
local offer = propose(state, 1, 2, "trade", { gold = 25, askResource = "iron", askAmount = 1 })
assert(
	state.players[1].gold == 100 and state.players[2].stockpile.iron == 2,
	"Proposals do not transfer resources"
)
assert(not reply(state, 3, offer, "accept"), "Only the named recipient may answer")
state.players[2].ready = true
assert(reply(state, 2, offer, "accept"), "Diplomatic replies remain possible after End Turn")
assert(
	state.players[1].gold == 75
		and state.players[2].gold == 125
		and state.players[1].stockpile.iron == 1
		and state.players[2].stockpile.iron == 1
)
assert(not reply(state, 2, offer, "accept"), "An accepted exchange cannot execute twice")
offer = propose(state, 1, 2, "trade", { gold = 25, askResource = "iron", askAmount = 1 })
state.players[2].stockpile.iron = 0
assert(
	not reply(state, 2, offer, "accept")
		and state.players[1].gold == 75
		and offer.status == "pending",
	"Acceptance revalidates all funding before changing anything"
)
local hidden = World.forPlayer(state, 3)
assert(
	#hidden.diplomacy.offers == 0,
	"Private negotiations do not appear in another observer's snapshot"
)
state.players[2].ready = false
local income = Systems.treasury(state.players[1], state).income
offer = propose(state, 1, 2, "commerce", { duration = 3 })
assert(reply(state, 2, offer, "accept"))
assert(Systems.treasury(state.players[1], state).income == income + 2)
state.round = 4
Diplomacy.boundary(state)
assert(
	Systems.treasury(state.players[1], state).income == income,
	"Commerce expiry changes the actual economy"
)

state = fixture()
offer = propose(state, 2, 3, "defensivePact", { duration = 10 })
assert(reply(state, 3, offer, "accept"))
assert(Diplomacy.declare(state, 1, 2, "surprise"))
local call = state.diplomacy.offers[#state.diplomacy.offers]
assert(call.kind == "defenseCall" and call.to == 3 and call.terms.enemy == 1)
assert(
	not Diplomacy.war(state, 1, 3) and Scheduler.canAct(state, 3),
	"A pact creates a choice, never forced war entry"
)
state.players[3].ready = true
assert(reply(state, 3, call, "accept"))
assert(
	not Diplomacy.war(state, 1, 3).active and #state.scheduler.groups[1].order == 2,
	"Accepted intervention begins next round"
)
state.round = 2
for _, p in ipairs(state.players) do
	p.ready = false
end
Diplomacy.boundary(state)
assert(Diplomacy.war(state, 1, 3).active and #state.scheduler.groups[1].order == 3)

for _, refusal in ipairs({ "reject", "expire" }) do
	state = fixture()
	offer = propose(state, 2, 3, "defensivePact", { duration = 10 })
	assert(reply(state, 3, offer, "accept"))
	assert(Diplomacy.declare(state, 1, 2, "surprise"))
	call = state.diplomacy.offers[#state.diplomacy.offers]
	if refusal == "reject" then
		assert(reply(state, 3, call, "reject"))
	else
		state.round = call.expiresRound
		Diplomacy.boundary(state)
	end
	assert(not Diplomacy.war(state, 1, 3) and state.diplomacy.reputation[3] == -10)
	assert(
		state.diplomacy.relations["2:3"].grievances >= 20,
		"Ignoring or refusing a pact has recorded consequences"
	)
end

state = fixture()
assert(Diplomacy.declare(state, 1, 2, "surprise"))
offer = propose(state, 1, 2, "peace", { duration = 5 })
assert(reply(state, 2, offer, "accept") and Diplomacy.canAttack(state, 1, 2))
state.round = 2
Diplomacy.boundary(state)
assert(not Diplomacy.canAttack(state, 1, 2) and Diplomacy.state(state, 1, 2) == "ARMISTICE")
assert(not Diplomacy.declare(state, 1, 2, "normal"))
assert(Diplomacy.declare(state, 1, 2, "surprise"))
assert(
	state.diplomacy.relations["2:1"].grievances >= 150,
	"Breaking an armistice leaves lasting grievances"
)

state = fixture()
state.players[2].stockpile.iron = 2
offer = propose(state, 1, 2, "trade", { gold = 25, askResource = "iron", askAmount = 1 })
local response, reason =
	DiplomaticAI.evaluate(World.forPlayer(state, 2), state.players[2], offer, Systems)
assert(response == "accept" and #reason > 10)
offer.terms.gold = 1
assert(
	DiplomaticAI.evaluate(World.forPlayer(state, 2), state.players[2], offer, Systems) == "reject"
)
offer.terms.gold = 25
state.players[3].gold = 999999
state.units = { { id = 50, owner = 3, kind = "netherguard", x = 1, y = 1, hp = 100 } }
assert(
	DiplomaticAI.evaluate(World.forPlayer(state, 2), state.players[2], offer, Systems) == response,
	"Unseen rival resources and armies cannot change a diplomatic decision"
)

state = fixture()
for round = 1, 40 do
	state.round = round
	Memory.add(state, 1, 2, "temporary" .. round, 1, 1, 50, "Temporary cooperation")
end
assert(#state.diplomacy.relations["1:2"].memories == 32)
state.round = 100
Offers.advance(state)
assert(
	state.diplomacy.relations["1:2"].trust == 0 and state.diplomacy.relations["1:2"].grievances == 0,
	"Compacted explanations retain their proper expiry effects"
)
state = fixture()
offer = propose(state, 1, 2, "trade", { gold = 20 })
assert(
	Actions.apply(
		state,
		2,
		{ action = "diplomaticCounter", offerID = offer.id, terms = { requestGold = 30 } },
		Systems
	)
)
assert(offer.status == "countered" and state.players[1].gold == 100)
local counter = state.diplomacy.offers[#state.diplomacy.offers]
assert(
	reply(state, 1, counter, "accept")
		and state.players[1].gold == 70
		and state.players[2].gold == 130
)
assert(
	Actions.apply(state, 1, { action = "diplomaticTalk", target = 2, topic = "greeting" }, Systems)
)
local trust = state.diplomacy.relations["2:1"].trust
assert(
	not Actions.apply(
		state,
		1,
		{ action = "diplomaticTalk", target = 2, topic = "greeting" },
		Systems
	)
)
assert(state.diplomacy.relations["2:1"].trust == trust, "Repeating a greeting cannot farm trust")
offer = propose(state, 1, 2, "alliance", { duration = 10 })
assert(reply(state, 2, offer, "accept"))
assert(not Diplomacy.declare(state, 1, 2, "normal"))
assert(Actions.apply(state, 1, { action = "cancelTreaty", treatyID = offer.id }, Systems))
assert(
	state.diplomacy.treaties[1].status == "broken"
		and state.players[1].strategySignal == "brokenAlliance"
)

state = fixture()
Memory.add(state, 2, 3, "betrayal", -40, 40, nil, "A remembered betrayal")
state.units = { { id = 60, owner = 3, kind = "warrior", x = 10, y = 7, movesLeft = 2 } }
World.reveal(state, Hex, Systems)
local near = World.forPlayer(state, 2).diplomacy.relations["2:3"]
assert(near.pressure > 0)
state.units[1].x, state.units[1].y = 1, 1
World.reveal(state, Hex, Systems)
local far = World.forPlayer(state, 2).diplomacy.relations["2:3"]
assert(
	far.pressure == 0 and far.trust == near.trust,
	"Withdrawing observed pressure does not erase a betrayal"
)
state.units = { { id = 61, owner = 2, kind = "warrior", x = 7, y = 6, movesLeft = 2 } }
World.reveal(state, Hex, Systems)
UnitMovement.walk(state, state.units[1], { { x = 7, y = 6 }, { x = 6, y = 6 } }, Systems)
assert(state.diplomacy.relations["1:2"].grievances == 3)
state = fixture()
offer = propose(state, 1, 2, "openBorders", { duration = 10 })
assert(reply(state, 2, offer, "accept"))
state.units = { { id = 62, owner = 2, kind = "warrior", x = 7, y = 6, movesLeft = 2 } }
World.reveal(state, Hex, Systems)
UnitMovement.walk(state, state.units[1], { { x = 7, y = 6 }, { x = 6, y = 6 } }, Systems)
assert(
	state.diplomacy.relations["1:2"].grievances == 0,
	"Open borders changes actual crossing consequences"
)

state = fixture()
state.players[2].ai = true
state.units =
	{ { id = 63, owner = 2, kind = "scout", x = 5, y = 6, movesLeft = 2, autoExplore = true } }
World.reveal(state, Hex, Systems)
offer = propose(state, 2, 1, "withdrawal", { by = 2 })
assert(reply(state, 1, offer, "accept"))
assert(
	not Systems.autoExplore(state, state.units[1], Hex),
	"AI exploration cannot override a withdrawal promise"
)
AI.withdraw(state, state.players[2], Systems)
state.round = 2
state.units[1].movesLeft, state.units[1].moved = 2, false
AI.withdraw(state, state.players[2], Systems)
local claim = World.territoryCity(state, Hex, state.units[1].x, state.units[1].y)
assert(not claim or claim.owner ~= 1, "AI executes a promised withdrawal through normal movement")
state.round = 4
World.reveal(state, Hex, Systems)
Perception.promises(state, Hex, World, Systems.units)
assert(state.diplomacy.promises[1].status == "fulfilled")
state = fixture()
state.units = { { id = 64, owner = 2, kind = "warrior", x = 5, y = 6, movesLeft = 2 } }
World.reveal(state, Hex, Systems)
offer = propose(state, 2, 1, "withdrawal", { by = 2 })
assert(reply(state, 1, offer, "accept"))
state.round = 4
Perception.promises(state, Hex, World, Systems.units)
assert(
	state.diplomacy.promises[1].status == "broken"
		and state.diplomacy.relations["1:2"].grievances >= 20
)
state = fixture()
offer = propose(state, 2, 3, "defensivePact", { duration = 10 })
assert(reply(state, 3, offer, "accept"))
assert(Diplomacy.declare(state, 1, 2, "surprise"))
call = state.diplomacy.offers[#state.diplomacy.offers]
assert(reply(state, 3, call, "accept"))
local attackView = World.forPlayer(state, 1)
assert(
	attackView.diplomacy.wars[2].supporting == nil and #attackView.diplomacy.offers == 0,
	"Public war graphs never disclose private defense-call identities or offers"
)
offer = propose(state, 1, 2, "peace", { duration = 5 })
assert(reply(state, 2, offer, "accept"))
state.round = 2
for _, participant in ipairs(state.players) do
	participant.ready = false
end
Diplomacy.boundary(state)
assert(
	not Diplomacy.war(state, 1, 3) and call.status == "cancelled",
	"A peace reached before intervention prevents an obsolete war entry"
)
assert(not state.diplomacy.reputation[3], "Obsolete defense calls never punish the ally")

state = fixture()
offer = propose(state, 2, 3, "defensivePact", { duration = 10 })
assert(reply(state, 3, offer, "accept"))
assert(Diplomacy.declare(state, 1, 2, "surprise"))
call = state.diplomacy.offers[#state.diplomacy.offers]
assert(reply(state, 3, call, "accept"))
state.round = 2
Diplomacy.boundary(state)
offer = propose(state, 2, 1, "peace", { duration = 5 })
assert(reply(state, 1, offer, "accept"))
state.round = 3
Diplomacy.boundary(state)
assert(
	Diplomacy.war(state, 1, 3) and state.diplomacy.relations["3:2"].grievances >= 15,
	"Separate peace during an active joint war has a remembered cost"
)
for _, invalid in ipairs({ -1, 1.5, math.huge, 0 / 0 }) do
	state = fixture()
	assert(
		not Actions.apply(
			state,
			1,
			{ action = "diplomaticOffer", target = 2, kind = "trade", terms = { gold = invalid } },
			Systems
		)
	)
	assert(state.players[1].gold == 100 and #state.diplomacy.offers == 0)
end
state = fixture()
state.diplomacy.wars = {
	{ a = 1, b = 2, active = true, activatesRound = 1, endsRound = 3 },
	{ a = 3, b = 1, active = true, activatesRound = 1, endsRound = 3 },
}
state.diplomacy.treaties = {
	{
		id = "joint",
		a = 2,
		b = 3,
		kind = "jointWar",
		status = "active",
		startsRound = 1,
		endsRound = 20,
		terms = { enemy = 1 },
	},
}
state.round = 3
Diplomacy.boundary(state)
assert(
	state.diplomacy.treaties[1].status == "completed" and not state.diplomacy.relations["3:2"],
	"Simultaneous coalition peace never arbitrarily blames one participant"
)
print(
	"CIVCRAFT: private offers, atomic trades, commerce, explicit defense choices, armistices, AI reasons and diplomatic memory passed."
)
