local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Reports = dofile("/games/civcraft/reports.lua")
local captured = {
	food = 0,
	wood = 0,
	science = 0,
	gold = 0,
	cities = {},
	techs = {},
	wonders = {},
	influence = {},
	units = { ["3"] = { kind = "settler", hp = 100 }, ["2"] = { kind = "warrior", hp = 100 } },
	raids = 0,
	mobClears = 0,
	age = 1,
	industryTurns = 0,
	endStage = 0,
}
local original = Reports.capture
Reports.capture = function()
	return captured
end
local before = {
	food = 0,
	wood = 0,
	science = 0,
	gold = 0,
	cities = {},
	techs = {},
	wonders = {},
	influence = {},
	units = { ["5"] = { kind = "scout", hp = 100 }, ["4"] = { kind = "settler", hp = 100 } },
}
local lines = Reports.build({}, {}, before)
assert(lines[5] == "Unit recruited: STONE GUARD")
assert(lines[6] == "Unit recruited: SETTLER")
assert(lines[7] == "Unit lost: SETTLER")
assert(lines[8] == "Unit lost: SCOUT")
Reports.capture = original
print("PASS: recruited and lost unit reports have stable identifier order")
