-- Native disk persistence of pending offers and capped acceptance.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Saves = dofile("/games/civcraft/saves.lua")
local Migration = dofile("/games/civcraft/campaign_migration.lua")
local state = Lifecycle.newLobby("native-import-restart")
state.mapSize, state.mapSeed, state.hostileMode = "compact", 319497, "off"
state.players =
	{ { id = 0, name = "HOST", civ = "forge" }, { id = 1, name = "GUEST", civ = "scholar" } }
Lifecycle.initialize(state)
for _, p in ipairs(state.players) do
	p.contacts = { [0] = true, [1] = true }
	p.techs.currency, p.techs.steampower = true, true
end
state.players[1].stockpile.coal, state.players[2].stockpile.coal = 5, 9
assert(Actions.apply(state, 0, {
	action = "diplomaticOffer",
	target = 1,
	kind = "trade",
	terms = { giveResource = "coal", giveAmount = 2, gold = 7 },
}, Systems))
local id = state.diplomacy.offers[#state.diplomacy.offers].id
assert(Saves.save(1, state))
local saved = assert(Migration.load(assert(Saves.load(1))))
assert(saved.players[1].gold == 20 and saved.players[2].gold == 20)
assert(
	not Actions.apply(
		saved,
		1,
		{ action = "diplomaticReply", offerID = id, response = "accept" },
		Systems
	)
)
assert(saved.players[1].gold == 20 and saved.players[2].gold == 20)
assert(saved.players[1].stockpile.coal == 5 and saved.players[2].stockpile.coal == 9)
assert(saved.diplomacy.offers[#saved.diplomacy.offers].status == "pending")
saved.players[2].stockpile.coal = 8
assert(Saves.save(1, saved))
saved = assert(Migration.load(assert(Saves.load(1))))
assert(
	Actions.apply(
		saved,
		1,
		{ action = "diplomaticReply", offerID = id, response = "accept" },
		Systems
	)
)
assert(saved.players[1].gold == 13 and saved.players[2].gold == 27)
assert(saved.players[1].stockpile.coal == 3 and saved.players[2].stockpile.coal == 10)
assert(Saves.save(1, saved))
saved = assert(Migration.load(assert(Saves.load(1))))
assert(saved.players[1].stockpile.coal + saved.players[2].stockpile.coal == 13)
assert(saved.players[1].gold + saved.players[2].gold == 40)
assert(
	not Actions.apply(
		saved,
		1,
		{ action = "diplomaticReply", offerID = id, response = "accept" },
		Systems
	),
	"Accepted offers cannot be paid twice after restart"
)
print(
	"CIVCRAFT: native pending-offer restart, cap rejection, conserved payment and no replay duplication passed"
)
