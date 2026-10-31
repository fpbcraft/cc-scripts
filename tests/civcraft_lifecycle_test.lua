-- Current lifecycle invariants, not a copied historical simulation engine.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Actors = dofile("/games/civcraft/actor_lifecycle.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local function fixture(count, seed)
	local state = Lifecycle.newLobby("lifecycle", "balance1")
	assert(state.contentRules == "balance5" and state.roundLimit == 250)
	state.mapSeed, state.mapSize, state.hostileMode, state.mapWrapX = seed, "compact", "off", true
	for id = 1, count do
		state.players[id] = { id = id, ai = false, ready = false }
	end
	Lifecycle.initialize(state)
	return state
end
for _, count in ipairs({ 2, 3, 4 }) do
	for _, seed in ipairs({ 12345, 24680 }) do
		local state, same = fixture(count, seed), fixture(count, seed)
		assert(state.world.seed == seed and state.world.width == 32 and state.world.height == 22)
		for key, tile in pairs(state.world.tiles) do
			assert(same.world.tiles[key] == tile)
		end
		for index, p in ipairs(state.players) do
			local settler, guard, ownCities = nil, nil, 0
			for _, c in ipairs(state.cities) do
				if c.owner == p.id then
					ownCities = ownCities + 1
				end
			end
			for _, u in ipairs(state.units) do
				if u.owner == p.id then
					if u.kind == "settler" then
						settler = u
					elseif u.kind == "warrior" then
						guard = u
					end
				end
			end
			local start = state.world.starts[index]
			assert(ownCities == 0 and settler and guard, "Humans must found their own first city")
			assert(settler.initialSettler and settler.x == start.x and settler.y == start.y)
			assert(p.settlersTrained == 0 and p.capitalFounded == false)
			assert(Hex.distance(settler.x, settler.y, guard.x, guard.y, state) <= 1)
			p.ready = true
		end
		for _, u in ipairs(state.units) do
			u.movesLeft = 0
		end
		Lifecycle.advance(state)
		assert(state.round == 2)
		for _, p in ipairs(state.players) do
			assert(not p.ready and p.reportRound == 2 and p.turnReport)
		end
		for _, u in ipairs(state.units) do
			assert(
				u.movesLeft == Systems.units[u.kind].move,
				"Round boundary restores a single allowance"
			)
		end
		state.players[1].ai = true
		local calls = {}
		Actors.pump(state, {
			before = function(_, p)
				calls[#calls + 1] = "before:" .. p.id
			end,
			after = function(_, p)
				calls[#calls + 1] = "after:" .. p.id
			end,
		})
		assert(
			state.players[1].ready
				and #calls == 2
				and calls[1] == "before:1"
				and calls[2] == "after:1"
		)
		for index = 2, count do
			assert(not state.players[index].ready, "AI pump cannot end a human turn")
		end
	end
end
print(
	"CIVCRAFT: six seeded current lifecycle fixtures preserve manual founding, reports, budgets and actor ownership"
)
