local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Contacts = dofile("/games/civcraft/contacts.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Events = dofile("/games/civcraft/events.lua")
local state = {
	phase = "game",
	round = 1,
	ruleset = "create",
	diplomacy = Diplomacy.new(),
	players = {
		{ id = 0, name = "HOST", civ = "forge", techs = {} },
		{ id = -2000000000, name = "AI", civ = "iron", techs = {} },
		{ id = 17, name = "UNMET", civ = "verdant", techs = {} },
	},
	cities = {},
	units = {
		{ id = 1, owner = 0, kind = "scout", x = 2, y = 3 },
		{ id = 2, owner = -2000000000, kind = "warrior", x = 13, y = 3 },
	},
	world = { width = 20, height = 10, tiles = {}, resources = {}, landmarks = {}, rails = {} },
}
for y = 1, 10 do
	for x = 1, 20 do
		state.world.tiles[World.key(x, y)] = "plains"
	end
end
Systems.migrate(state)
World.reveal(state, Hex, Systems)
assert(not Contacts.knows(state, 0, -2000000000))
assert(not Diplomacy.talk(state, 0, -2000000000, "greeting"))
assert(not Diplomacy.declare(state, 0, -2000000000, "surprise"))
assert(
	not Offers.propose(
		state,
		0,
		{ target = -2000000000, kind = "commerce", terms = { duration = 10 } },
		Systems,
		Diplomacy
	)
)
assert(not Contacts.meet(state, 0, -99), "NPC owners are not civilizations")
state.units[2].x = 3
World.reveal(state, Hex, Systems)
assert(
	Contacts.knows(state, 0, -2000000000) and Contacts.knows(state, -2000000000, 0),
	"Visible foreign units establish mutual contact"
)
assert(not Contacts.knows(state, 17, 0), "Contact is not shared globally")
local function contactCount(id)
	local count = 0
	for _, event in ipairs(Events.forPlayer(state, id).entries) do
		if event.type == "contact" then
			count = count + 1
		end
	end
	return count
end
assert(contactCount(0) == 1 and contactCount(-2000000000) == 1 and contactCount(17) == 0)
World.reveal(state, Hex, Systems)
state.units[2].x = 13
World.reveal(state, Hex, Systems)
assert(
	contactCount(0) == 1 and Contacts.knows(state, 0, -2000000000),
	"Contact survives loss of vision without repeated notices"
)
local view = World.forPlayer(state, 0)
assert(Contacts.knows(view, 0, -2000000000) and not Contacts.knows(view, 0, 17))
assert(not view.players[2].contacts, "Foreign contact networks stay private")
assert(Diplomacy.talk(state, 0, -2000000000, "greeting"))
assert(
	Offers.propose(
		state,
		0,
		{ target = -2000000000, kind = "commerce", terms = { duration = 10 } },
		Systems,
		Diplomacy
	)
)
state.cities = { { id = 1, owner = 17, x = 3, y = 3, population = 1, buildings = {} } }
World.reveal(state, Hex, Systems)
assert(Contacts.knows(state, 0, 17), "Visible settlements also establish contact")
print(
	"CIVCRAFT: first contact, private notices, persistent discovery and host-side diplomacy gates passed."
)
