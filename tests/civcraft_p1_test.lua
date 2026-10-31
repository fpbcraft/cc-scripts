-- Historical filename retained; civilian projects now use only current rules.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Systems = dofile("/games/civcraft/systems.lua")
local Projects = dofile("/games/civcraft/civilian_projects.lua")
local Rules = dofile("/games/civcraft/content_rules.lua")
local player = { id = 1, contentRules = Rules.current, techs = {}, researchTarget = "agriculture" }
local city =
	{ buildings = { housing = true, library = true, market = true }, projectRemainders = {} }
assert(Systems.projectCost("unit", "scout", player) == 15)
assert(Systems.projectCost("unit", "warrior", player) == 20)
assert(Systems.projectCost("unit", "settler", player) == 28)
player.settlersTrained = 3
assert(Systems.projectCost("unit", "settler", player) == 52)
player.gameSpeed = "quick"
assert(Systems.projectCost("unit", "settler", player) == 35)
player.gameSpeed = "epic"
assert(Systems.projectCost("unit", "settler", player) == 78)
player.gameSpeed = "standard"
for _, id in ipairs({ "ponder", "tend", "trade" }) do
	assert(Projects.available(player, city, id))
end
city.buildings.housing = nil
city.buildings.farm = true
assert(not Projects.available(player, city, "tend"), "Retired Farm cannot replace current Housing")
city.buildings.housing = true
for _, case in ipairs({ { "ponder", "science", 4 }, { "tend", "food", 2 }, { "trade", "gold", 2 } }) do
	local id, field, turns = case[1], case[2], case[3]
	city.project = { kind = "project", id = id }
	local total = 0
	for round = 1, turns do
		local output = Projects.preview(player, city, 1, Systems)
		assert(output.active)
		assert(output[field] == (round == turns and 1 or 0), "Conversion waits for whole output")
		total = total + output[field]
		Projects.commit(city, output)
	end
	assert(total == 1 and city.projectRemainders[id] == 0, "Industry and remainder are conserved")
end
city.project = { kind = "project", id = "ponder" }
city.projectRemainders.ponder = 2
player.researchTarget = nil
local paused = Projects.preview(player, city, 10, Systems)
assert(not paused.active and paused.science == 0)
Projects.commit(city, paused)
assert(city.projectRemainders.ponder == 2, "A paused project cannot lose its remainder")
player.researchTarget = "agriculture"
player.techs.agriculture = true
assert(
	not Projects.preview(player, city, 10, Systems).active,
	"Completed research cannot receive project output"
)
player.techs.agriculture = nil
local resumed = Projects.preview(player, city, 2, Systems)
assert(resumed.active and resumed.science == 1)
Projects.commit(city, resumed)
assert(city.projectRemainders.ponder == 0)
city.project = { kind = "project", id = "unknown" }
assert(not Projects.preview(player, city, 100, Systems).active)
print(
	"CIVCRAFT: current production costs and civilian-project conservation, pause and recovery passed"
)
