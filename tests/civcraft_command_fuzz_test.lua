local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Actions = dofile("/games/civcraft/actions.lua")
local Council = dofile("/games/civcraft/council.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Random = dofile("/games/civcraft/world_random.lua")
local Cooperative = dofile("/games/civcraft/cooperative.lua")
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end
local function equal(a, b)
	if type(a) ~= "table" then
		return a == b
	end
	if type(b) ~= "table" then
		return false
	end
	for key, item in pairs(a) do
		if not equal(item, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end
local state = {
	phase = "game",
	ruleset = "create",
	round = 1,
	campaignID = "fuzz",
	victoryRulesVersion = 2,
	nextId = 10,
	world = { width = 12, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} },
	players = {
		{
			id = 0,
			name = "HOST",
			civ = "iron",
			techs = { currency = true },
			gold = 100,
			contacts = { [1] = true },
		},
		{
			id = 1,
			name = "RIVAL",
			civ = "forge",
			techs = {},
			gold = 100,
			contacts = { [0] = true },
		},
	},
	cities = {
		{ id = 1, owner = 0, x = 3, y = 4, population = 2, buildings = { market = true } },
		{ id = 2, owner = 1, x = 10, y = 7, population = 2, buildings = {} },
	},
	units = {
		{ id = 3, owner = 0, kind = "warrior", x = 4, y = 4, movesLeft = 2 },
		{ id = 5, owner = 0, kind = "scout", x = 4, y = 6, movesLeft = 2 },
		{ id = 6, owner = 1, kind = "warrior", x = 9, y = 7, movesLeft = 2 },
	},
	diplomacy = Diplomacy.new(),
}
for y = 1, 10 do
	for x = 1, 12 do
		state.world.tiles[World.key(x, y)] = "plains"
	end
end
Systems.migrate(state)
Diplomacy.migrate(state)
World.reveal(state, Hex, Systems)
Council.advance(state)
local bases = {
	{ action = "move", unitID = 3, sx = 4, sy = 4, x = 5, y = 4 },
	{ action = "standby", unitID = 3, x = 4, y = 4, value = true },
	{ action = "autoExplore", unitID = 5, x = 4, y = 6 },
	{ action = "queueMove", unitID = 3, sx = 4, sy = 4, x = 7, y = 4 },
	{ action = "cancelRoute", unitID = 3, x = 4, y = 4 },
	{ action = "skipTurn", unitID = 3, x = 4, y = 4 },
	{ action = "heal", unitID = 3, x = 4, y = 4 },
	{ action = "queue", cityX = 3, cityY = 4, kind = "none" },
	{ action = "researchTech", id = "agriculture" },
	{ action = "declareWar", target = 1, kind = "normal" },
	{ action = "diplomaticOffer", target = 1, kind = "trade", terms = { gold = 1 } },
	{ action = "councilVote", session = 1, candidate = 1 },
	{ action = "councilPropose", session = 1, kind = "embargo", target = 1 },
}
local fields = {
	"action",
	"unitID",
	"sx",
	"sy",
	"x",
	"y",
	"cityX",
	"cityY",
	"kind",
	"id",
	"value",
	"target",
	"terms",
	"round",
	"campaignID",
	"session",
	"candidate",
	"resolution",
	"support",
}
local atoms = {
	{},
	{ value = false },
	{ value = true },
	{ value = 0 },
	{ value = -1 },
	{ value = 1 },
	{ value = 2 },
	{ value = 1.5 },
	{ value = math.huge },
	{ value = -math.huge },
	{ value = 0 / 0 },
	{ value = "invalid" },
	{ value = "move" },
	{ value = "normal" },
	{ value = {} },
	{ value = { nested = true } },
}
local rng, work = Random.new(9871, 42), {}
local function checkpoint()
	Cooperative.checkpoint(work, false, true)
end
World.checkpoint, Systems.checkpoint = checkpoint, checkpoint
local accepted, rejected = 0, 0
for index = 1, 2048 do
	local game = copy(state)
	if index % 19 == 0 then
		game.players[1].ready = true
	end
	if index % 17 == 0 then
		game.units[1].movesLeft = 0
	end
	if index % 13 == 0 then
		game.units[1].standby, game.units[1].healing = true, true
	end
	local request = copy(bases[rng:integer(#bases)])
	if index % 4 ~= 0 then
		request[fields[rng:integer(#fields)]] = copy(atoms[rng:integer(#atoms)].value)
	end
	if index % 31 == 0 then
		request = "not a request"
	end
	local actor = index % 7 == 0 and 999 or 0
	local before = copy(game)
	local survived, ok, why = pcall(Actions.apply, game, actor, request, Systems)
	assert(survived, "Command fuzz sample " .. index .. " crashed: " .. tostring(ok))
	if ok then
		accepted = accepted + 1
		for _, unit in ipairs(game.units) do
			assert(
				Hex.inBounds(unit.x, unit.y, game) and unit.movesLeft >= 0 and unit.movesLeft <= 2,
				"Accepted orders cannot grant movement or leave the map"
			)
		end
		assert(game.players[1].gold >= 0 and game.players[2].gold >= 0)
	else
		rejected = rejected + 1
		assert(type(why) == "string")
		assert(
			equal(before, game),
			"Rejected command fuzz sample " .. index .. " changed state: " .. why
		)
	end
	local view = World.forPlayer(game, 0)
	assert(
		not view.players[2].techs
			and not view.players[2].stockpile
			and not view.players[2].visible
			and not view.players[2].aiPlan
	)
	assert(not view.eventJournal, "Command handling must preserve observer redaction")
	if index % 16 == 0 then
		checkpoint()
	end
end
assert(accepted > 100 and rejected > 100)
print(
	"CIVCRAFT: 2,048 deterministic command mutations passed; accepted "
		.. accepted
		.. ", rejected "
		.. rejected
		.. "; no crashes, rejected mutations, extra movement or private-player fields."
)
