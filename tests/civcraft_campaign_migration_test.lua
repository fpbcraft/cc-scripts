local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Migration = dofile("/games/civcraft/campaign_migration.lua")
local Rules = dofile("/games/civcraft/content_rules.lua")
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Campaign = dofile("/games/civcraft/campaign_rules.lua")
local function fixture()
	local world = { width = 12, height = 10, tiles = {}, resources = {} }
	for y = 1, 10 do
		for x = 1, 12 do
			world.tiles[x .. ":" .. y] = "plains"
		end
	end
	return {
		version = 6,
		ruleset = "create",
		contentRules = "balance5",
		phase = "game",
		round = 9,
		nextId = 2,
		world = world,
		players = { { id = 1, name = "ONE", civ = "forge", techs = {}, stockpile = { iron = 12 } } },
		cities = {
			{ id = 1, owner = 1, capitalOf = 1, x = 4, y = 4, population = 3, buildings = {} },
		},
		units = {},
	}
end
local fresh = Lifecycle.newLobby("fresh-treasury")
fresh.players = { { id = 0, civ = "forge" }, { id = 1, civ = "scholar" } }
Lifecycle.initialize(fresh)
assert(
	fresh.players[1].gold == 20 and fresh.players[2].gold == 20,
	"Fresh campaigns explicitly initialize treasury before save migration"
)
for _, old in ipairs({
	false,
	"baseline",
	"p1",
	"balance1",
	"balance2",
	"balance3",
	"balance4",
	"balance5",
}) do
	local saved = fixture()
	saved.contentRules = old or nil
	saved.ruleset = "legacy"
	local current, problem = Migration.load(saved)
	assert(current, problem)
	assert(current.contentRules == Rules.current and current.ruleset == "create")
	assert(current.players[1].contentRules == Rules.current and current.resourceSchema == 1)
	assert(current.players[1].stockpile.iron == 12 and current.players[1].stockpile.coal == 0)
	assert(current.round == 9 and #current.cities == 1 and #current.units == 0)
	assert(current.players[1].gold == 0, "Missing legacy treasury cannot grant money")
	assert(saved.contentRules == (old or nil) and saved.ruleset == "legacy")
	assert(saved.players[1].stockpile.coal == nil and saved.world.terrainYieldVersion == nil)
	current.cities[1].buildings.library = true
	assert(saved.cities[1].buildings.library == nil, "Migrated candidate must be detached")
	local again = assert(Migration.load(current))
	assert(again.contentRules == current.contentRules and again.players[1].stockpile.iron == 12)
end
local savedPlan = fixture()
savedPlan.players[1].aiPlan = { version = 999, primary = "industrial" }
assert(assert(Migration.load(savedPlan)).players[1].aiPlan == nil)
assert(savedPlan.players[1].aiPlan.version == 999)
savedPlan.players[1].aiPlan = { version = 1, primary = "expedition" }
assert(assert(Migration.load(savedPlan)).players[1].aiPlan.primary == "expedition")
savedPlan.cities[1].project = { kind = "unit", id = "scout", progress = 7 }
assert(assert(Migration.load(savedPlan)).cities[1].project.progress == 7)
for _, breakSave in ipairs({
	function(s)
		s.players[1].gold = "bad"
	end,
	function(s)
		s.players[1].gold = -1
	end,
	function(s)
		s.version = -1
	end,
	function(s)
		s.cities[1].project = { kind = "building", id = "farm" }
	end,
	function(s)
		s.cities[1].project = { kind = "unknown", id = "scout" }
	end,
	function(s)
		s.score = math.huge
	end,
	function(s)
		s.cities[1].population = nil
	end,
	function(s)
		s.cities[1].buildings.unknown = true
	end,
	function(s)
		s.contentRules = "future-rules"
	end,
	function(s)
		s.version = 999
	end,
	function(s)
		s.resourceSchema = 999
	end,
	function(s)
		s.players[1].stockpile.iron = -1
	end,
	function(s)
		s.players[1].stockpile.unknown = 1
	end,
	function(s)
		s.players = "broken"
	end,
	function(s)
		s.units = { { id = 2, owner = 1, x = 4, y = 4, kind = "unknown" } }
	end,
	function(s)
		s.cities[1].x = 999
	end,
	function(s)
		s.world.width = "broken"
	end,
	function(s)
		s.self = s
	end,
}) do
	local saved = fixture()
	breakSave(saved)
	local before = saved.players
	local candidate, reason = Migration.load(saved)
	assert(not candidate and reason:lower():find("delete/reset", 1, true), tostring(reason))
	assert(saved.players == before, "Rejected migration must not replace input collections")
end
local lobby = Lifecycle.newLobby("current-only", "balance1")
assert(lobby.contentRules == Rules.current)
lobby.players = { { id = 1 } }
assert(not Campaign.configure(lobby, 1, { action = "contentRules", version = "balance1" }))
assert(lobby.contentRules == Rules.current, "Historical rules cannot be selected")
print("CIVCRAFT: current rules, detached save migration and explicit reset failures passed")
