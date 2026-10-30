local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Hex = dofile("games/civcraft/hex.lua")
local World = dofile("games/civcraft/world.lua")
local Founding = dofile("games/civcraft/founding.lua")
local Suggestions = dofile("games/civcraft/settlement_suggestions.lua")

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, entry in pairs(value) do
		result[key] = copy(entry)
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
	for key, entry in pairs(a) do
		if not equal(entry, b[key]) then
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

local function fixture(wrap)
	local world =
		{ width = 12, height = 8, wrapX = wrap == true, tiles = {}, resources = {}, landmarks = {} }
	for y = 1, world.height do
		for x = 1, world.width do
			world.tiles[x .. ":" .. y] = "plains"
		end
	end
	local player = {
		id = 1,
		techs = {},
		explored = {},
		visible = {},
		mapMemory = {
			version = 1,
			observations = {},
			landmarks = {},
			rails = {},
			cities = {},
			sites = {},
		},
	}
	local state = {
		phase = "game",
		ruleset = "create",
		contentRules = "balance5",
		round = 1,
		world = world,
		players = { player, { id = 2, techs = {}, explored = {}, visible = {} } },
		cities = { { id = 1, owner = 1, x = 2, y = 2, population = 2 } },
		units = { { id = 2, owner = 1, kind = "settler", x = 4, y = 4, movesLeft = 2 } },
	}
	for y = 1, world.height do
		for x = 1, world.width do
			local key = x .. ":" .. y
			if y <= 6 and x <= 8 then
				player.explored[key] = true
				player.mapMemory.observations[key] = {
					tile = "plains",
					geography = { biome = "plains", elevation = "flat", feature = "none" },
				}
			end
		end
	end
	world.tiles["7:4"] = "hills"
	player.mapMemory.observations["7:4"].tile = "hills"
	player.mapMemory.observations["7:4"].geography = {
		biome = "plains",
		elevation = "hill",
		feature = "none",
	}
	return state, player
end

local function snapshot(view)
	local rows = {}
	for _, site in ipairs(Suggestions.forSettler(view, 1, { owner = 1, kind = "settler" })) do
		rows[#rows + 1] =
			table.concat({ site.x, site.y, site.score, site.capacity.observedMinimum }, ":")
	end
	return table.concat(rows, ",")
end

local state, player = fixture(false)
local view = World.forPlayer(state, 1)
local originalView = copy(view)
local sites = Suggestions.forSettler(view, 1, state.units[1])
assert(equal(view, originalView), "Suggestion evaluation does not mutate the projected view")
assert(#sites > 0, "Known legal sites are suggested")
local top = Suggestions.forSettler(view, 1, state.units[1], nil, 1)
assert(#top == 1 and top[1].x == sites[1].x and top[1].y == sites[1].y)
local checkpoints = 0
Suggestions.forSettler(view, 1, state.units[1], {
	checkpoint = function()
		checkpoints = checkpoints + 1
	end,
}, 1)
assert(checkpoints > 0, "Large candidate scans cooperate with the scheduler")
assert(
	sites[1].incompleteKnowledge and sites[1].knowledgeNote:find("explored observations", 1, true)
)
local worksOpportunity = false
for index, site in ipairs(sites) do
	assert(player.explored[site.x .. ":" .. site.y])
	assert(site.capacity.base == 4 and site.capacity.observedMinimum >= 4)
	assert(#site.reasons >= 4, "Candidate includes concrete explanation reasons")
	local previous = sites[index - 1]
	assert(
		not previous
			or previous.score > site.score
			or previous.score == site.score
				and (previous.y < site.y or previous.y == site.y and previous.x < site.x),
		"Candidates are ranked globally with stable coordinate ties"
	)
	for _, specialty in ipairs(site.specialties) do
		assert(specialty.conditional and specialty.evidence)
		worksOpportunity = worksOpportunity or specialty.kind == "works"
	end
end
assert(worksOpportunity, "M3 site roles use the explored geography contract")
assert(not Founding.canFound(state, 1, 3, 2), "Three hex spacing is shared founding legality")
assert(Founding.canFound(state, 1, 6, 4), "A separated land tile is legal")
state.spawners = { { x = 6, y = 4, cleared = false } }
local legal, reason = Founding.canFound(state, 1, 6, 4)
assert(not legal and reason == "Clear the hostile camp first")

-- Hidden world changes cannot affect a view-derived model.
state, player = fixture(false)
view = World.forPlayer(state, 1)
local before = snapshot(view)
for y = 1, state.world.height do
	for x = 9, state.world.width do
		state.world.tiles[x .. ":" .. y] = (x + y) % 2 == 0 and "water" or "mountain"
		state.world.resources[x .. ":" .. y] = "diamond"
	end
end
local after = snapshot(World.forPlayer(state, 1))
assert(before == after, "Hidden terrain and resources do not change suggestions")

-- Ordering is deterministic, and wrapped city spacing honors the cylinder.
state = fixture(true)
view = World.forPlayer(state, 1)
local first = snapshot(view)
assert(first == snapshot(view), "Ranking has deterministic score and coordinate ties")
assert(not Founding.canFound(state, 1, 12, 2), "Wrapped city spacing rejects the seam neighbor")
state.contentRules = "baseline"
local legacy = Suggestions.forSettler(World.forPlayer(state, 1), 1, state.units[1])
for _, site in ipairs(legacy) do
	assert(#site.specialties == 0, "Older profiles do not gain M3-only future site opportunities")
end

print("CIVCRAFT: explored settlement suggestions and shared founding legality passed")
