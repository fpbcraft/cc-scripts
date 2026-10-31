local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Stock = dofile("/games/civcraft/resource_stock.lua")
local Economy = dofile("/games/civcraft/economy.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local AI = dofile("/games/civcraft/diplomatic_ai.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local function fixture()
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		players = {},
		cities = {},
		units = {},
		world = { width = 16, height = 10, tiles = {}, resources = {} },
		diplomacy = Diplomacy.new(),
	}
	for y = 1, 10 do
		for x = 1, 16 do
			state.world.tiles[x .. ":" .. y] = "plains"
		end
	end
	for id = 1, 2 do
		state.players[id] = {
			id = id,
			name = "PLAYER " .. id,
			civ = "forge",
			gold = 100,
			techs = { currency = true, steampower = true },
			contacts = { [1] = true, [2] = true },
		}
		state.cities[id] = {
			id = id,
			owner = id,
			capitalOf = id,
			x = id * 5,
			y = 5,
			population = 2,
			buildings = { market = true },
		}
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	return state, state.players[1], state.players[2]
end
local function propose(state, terms)
	assert(
		Actions.apply(
			state,
			1,
			{ action = "diplomaticOffer", target = 2, kind = "trade", terms = terms },
			Systems
		)
	)
	return state.diplomacy.offers[#state.diplomacy.offers]
end
local function accept(state, offer)
	return Actions.apply(
		state,
		2,
		{ action = "diplomaticReply", offerID = offer.id, response = "accept" },
		Systems
	)
end
local a, b = { coal = 10 }, { coal = 10 }
local swapped = assert(Stock.trade(a, b, "coal", 2, "coal", 2))
assert(swapped.first.coal == 10 and swapped.second.coal == 10 and a.coal == 10 and b.coal == 10)
assert(not Stock.trade(a, b, "coal", 2, "coal", 1))
assert(not Stock.trade(a, b, "coal", -1, nil, 0))
assert(not Stock.trade(a, b, "coal", 0.5, nil, 0))
assert(not Stock.trade(a, b, "secret", 1, nil, 0))
assert(not Stock.trade(a, b, nil, nil, nil, 0))
assert(a.coal == 10 and b.coal == 10, "Failed plans preserve both source stocks")
local state, sender, recipient = fixture()
sender.stockpile.coal, recipient.stockpile.coal = 5, 9
local offer = propose(state, { giveResource = "coal", giveAmount = 2, gold = 10, requestGold = 5 })
local response, reason = AI.evaluate(World.forPlayer(state, 2), recipient, offer, Systems)
assert(response == "reject" and reason:find("capacity", 1, true))
assert(not accept(state, offer))
assert(
	sender.gold == 100
		and recipient.gold == 100
		and sender.stockpile.coal == 5
		and recipient.stockpile.coal == 9
)
assert(offer.status == "pending", "Rejected acceptance preserves the offer")
recipient.stockpile.coal = 8
assert(accept(state, offer))
assert(
	sender.gold == 95
		and recipient.gold == 105
		and sender.stockpile.coal == 3
		and recipient.stockpile.coal == 10
)
state, sender, recipient = fixture()
sender.stockpile.coal, recipient.stockpile.coal = 10, 10
offer =
	propose(state, { giveResource = "coal", giveAmount = 1, askResource = "coal", askAmount = 1 })
assert(accept(state, offer) and sender.stockpile.coal == 10 and recipient.stockpile.coal == 10)
state, sender, recipient = fixture()
sender.stockpile.coal = 2
offer = propose(state, { giveResource = "coal", giveAmount = 2, requestGold = 10 })
sender.stockpile.coal = 1
assert(
	not accept(state, offer)
		and sender.gold == 100
		and recipient.gold == 100
		and recipient.stockpile.coal == 0
)
offer.terms.giveAmount = -1
assert(not accept(state, offer) and sender.stockpile.coal == 1)
state, sender, recipient = fixture()
sender.stockpile.coal = 12
offer = propose(state, { gold = 10 })
assert(
	accept(state, offer) and sender.stockpile.coal == 12,
	"Gold-only trades preserve above-cap legacy stocks"
)
state, sender = fixture()
for _, amount in ipairs({ 10, 12 }) do
	sender.stockpile.coal = amount
	assert(not Economy.exchange(state, sender, "coal"))
	assert(
		sender.gold == 100 and sender.stockpile.coal == amount,
		"At-cap import cannot charge gold"
	)
end
sender.stockpile.coal = 9
assert(Economy.exchange(state, sender, "coal"))
assert(sender.gold == 80 and sender.stockpile.coal == 10)
sender.stockpile.coal, sender.techs.steampower = 0, nil
assert(
	not Economy.exchange(state, sender, "coal") and sender.gold == 80 and sender.stockpile.coal == 0
)
print(
	"CIVCRAFT: atomic capped imports, same-resource swaps, stale offers and private AI capacity passed"
)
