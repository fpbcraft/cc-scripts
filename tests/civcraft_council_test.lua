local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Council = dofile("/games/civcraft/council.lua")
local Rules = dofile("/games/civcraft/council_rules.lua")
local AI = dofile("/games/civcraft/council_ai.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Economy = dofile("/games/civcraft/economy.lua")
local Campaign = dofile("/games/civcraft/campaign_rules.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local function fixture(count)
	local state = {
		phase = "game",
		round = 1,
		campaignID = "council-test",
		ruleset = "create",
		victoryRulesVersion = 2,
		players = {},
		cities = {},
		units = {},
		world = { width = 20, height = 14, tiles = {}, resources = {}, landmarks = {}, rails = {} },
		diplomacy = Diplomacy.new(),
	}
	for y = 1, 14 do
		for x = 1, 20 do
			state.world.tiles[World.key(x, y)] = "plains"
		end
	end
	for index = 1, count or 3 do
		local id = index - 2
		local contacts = {}
		for other = 1, count or 3 do
			contacts[other - 2] = true
		end
		state.players[index] = {
			id = id,
			name = "MEMBER " .. id,
			civ = "iron",
			techs = { currency = true, commerce = true, bronze = true },
			gold = 100,
			contacts = contacts,
		}
		state.cities[index] = {
			id = index,
			owner = id,
			capitalOf = id,
			x = index * 4,
			y = 6,
			population = 2,
			buildings = { market = true, councilhall = true },
		}
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	Council.advance(state)
	return state
end
local function propose(state, actor, target, kind, terms)
	return Offers.propose(
		state,
		actor,
		{ target = target, kind = kind, terms = terms },
		Systems,
		Diplomacy
	)
end
local function vote(state, actor, candidate)
	return Actions.apply(
		state,
		actor,
		{ action = "councilVote", session = state.council.session.id, candidate = candidate },
		Systems
	)
end
local function resolution(state, actor, id, support)
	return Council.vote(
		state,
		actor,
		{ session = state.council.session.id, resolution = id, support = support }
	)
end
local function close(state)
	state.round = state.council.session.closesRound
	Council.advance(state)
end
local state = fixture()
local session = state.council.session
assert(session.allocated == 6 and #session.members == 3 and session.closesRound == 4)
Council.advance(state)
assert(state.council.nextSession == 2, "One opening per round")
assert(not Campaign.enabled({}, "diplomatic"), "Legacy victories stay unchanged")
assert(Campaign.enabled({ victories = { diplomatic = true } }, "diplomatic"))
assert(Campaign.enabled(state, "diplomatic"))
state.players[1].ready = true
state.units[1] =
	{ id = 99, owner = -1, kind = "warrior", x = 4, y = 5, movesLeft = 0, attacksLeft = 0 }
assert(vote(state, -1, 0), "A Ready member may vote for computer ID zero")
assert(state.units[1].movesLeft == 0 and state.units[1].attacksLeft == 0)
assert(not vote(state, -1, 999))
assert(not Council.vote(state, -1, { session = 999, candidate = 0 }))
assert(not resolution(state, -1, 1, "yes"))
assert(
	not Actions.apply(
		state,
		-1,
		{ action = "councilVote", session = session.id, candidate = 0, campaignID = "old" },
		Systems
	)
)
assert(vote(state, 0, 0))
assert(vote(state, 1, false), "Explicit abstention")
assert(Rules.pledge(state, -1, 0, session.id))
local public = Council.public(state, 1)
assert(
	public.session.election == nil
		and public.session.agenda[1].votes == nil
		and #public.session.pledges == 0
)
assert(public.session.ownElection.candidate == false)
assert(Council.public(state, -1).session.pledges[1].to == 0)
assert(resolution(state, -1, 1, true) and resolution(state, 0, 1, true))
close(state)
assert(state.council.leader == 0 and state.council.victory.id == 0)
assert(state.council.history[1].pledges == nil)
assert(Council.public(state, 1).session.election[-1].candidate == 0)
assert(Rules.exchangeCost(state) == 15)
local before = state.players[2].gold
assert(Economy.exchange(state, state.players[2], "iron"))
assert(state.players[2].gold == before - 15)
assert(not vote(state, 0, 0), "Closed votes cannot be replaced")
for _, count in ipairs({ 2, 3, 4 }) do
	state = fixture(count)
	for _, player in ipairs(state.players) do
		assert(vote(state, player.id, player.id))
	end
	close(state)
	assert(
		state.council.leader == nil and state.council.victory == nil,
		"Self voting creates no automatic winner"
	)
end
state = fixture()
state.victories = { diplomatic = false }
assert(vote(state, -1, 0) and vote(state, 0, 0))
close(state)
assert(state.council.leader == 0 and state.council.victory == nil)
state = fixture()
state.cities[2].buildings.councilhall = nil
assert(vote(state, -1, 0) and vote(state, 0, 0))
close(state)
assert(state.council.victory == nil, "Leadership without the hall is not victory")
state = fixture()
assert(vote(state, -1, 0) and vote(state, 0, 0))
state.cities[1].owner = 1
close(state)
assert(
	state.council.session.allocated == 6 and state.council.leader == nil,
	"Elimination cannot lower the frozen denominator"
)
state = fixture()
state.cities[4] = {
	id = 4,
	owner = -1004,
	villageOwner = -1004,
	village = "farmer",
	influence = { [0] = 60 },
	x = 10,
	y = 12,
	buildings = {},
}
for round = 2, 11 do
	state.round = round
	Council.advance(state)
end
assert(Rules.member(state.council.session, 0).delegates == 3)
state.cities[5] = { id = 5, owner = 0, x = 11, y = 12, buildings = {} }
assert(state.council.session.allocated == 7, "Extra cities grant no delegates")
state.cities[4].owner = -1
for round = 12, 21 do
	state.round = round
	Council.advance(state)
end
assert(
	Rules.member(state.council.session, 0).delegates == 2,
	"Conquered villages grant no allied delegate"
)
state = fixture()
assert(Council.propose(state, -1, { session = 1, kind = "embargo", target = 0 }))
assert(not Council.propose(state, -1, { session = 1, kind = "censure", target = 1 }))
assert(Council.propose(state, 0, { session = 1, kind = "censure", target = 1 }))
for _, id in ipairs({ -1, 0 }) do
	assert(resolution(state, id, 2, true))
	assert(resolution(state, id, 3, true))
end
close(state)
assert(Rules.embargoed(state, 0) and Rules.reputation(state, 1) == -20)
assert(not Economy.exchange(state, state.players[2], "iron"))
assert(not propose(state, -1, 0, "commerce", { duration = 10 }))
state.round = state.council.effects[1].endsRound
Council.advance(state)
assert(not Rules.embargoed(state, 0) and Rules.reputation(state, 1) == 0)
state = fixture()
state.diplomacy.wars[1] = { a = -1, b = 0, declaredRound = 1, startsRound = 1 }
assert(Council.propose(state, 1, { session = 1, kind = "peace", target = -1, other = 0 }))
assert(resolution(state, -1, 2, true) and resolution(state, 1, 2, true))
close(state)
assert(state.diplomacy.wars[1].forcedPeace and state.diplomacy.wars[1].endsRound == state.round)
assert(Rules.peaceProtected(state, 0, -1) and not Diplomacy.canAttack(state, -1, 0))
state = fixture()
local view = World.forPlayer(state, -1)
assert(
	AI.election(view, view.players[1]) == -1,
	"Neutral relations favor self over trivial diplomacy wins"
)
assert(Rules.pledge(state, -1, 0, 1))
view = World.forPlayer(state, -1)
assert(AI.election(view, view.players[1]) == 0)
AI.run(state, state.players[1], view)
assert(state.council.session.election[-1].candidate == 0)
assert(type(state.council.session.election[-1].reason) == "string")
state = fixture()
local ok = propose(state, -1, 0, "councilSupport", { session = 1 })
assert(ok)
local offer = state.diplomacy.offers[#state.diplomacy.offers]
assert(Offers.respond(state, 0, { offerID = offer.id, response = "accept" }, Systems, Diplomacy))
assert(state.council.session.pledges[1].from == 0 and state.council.session.pledges[1].to == -1)
assert(not propose(state, 1, 0, "councilSupport", { session = 1 }))
assert(propose(state, -1, 1, "councilSupport", { session = 1 }))
local stale = state.diplomacy.offers[#state.diplomacy.offers]
close(state)
Offers.advance(state)
assert(stale.status == "withdrawn", "Unanswered Council requests expire with their ballot")
print(
	"CIVCRAFT: Council secrets, frozen delegates, voting validation, AI, pledges and real resolutions passed."
)
