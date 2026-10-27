local U = require("games.railbreak.core.util")
local C = require("games.railbreak.content.catalog")
local S = { W = 12, H = 8 }
local function place(g, x, y, id, face, filter)
	g.grid[y][x] = {
		id = id,
		face = face or 1,
		filter = filter or "iron",
		slot = {},
		output = {},
		item = nil,
		work = 0,
	}
end
function S.new(options)
	options = options or {}
	local rnd = U.random(options.seed or 81267)
	local g = {
		version = 1,
		seed = options.seed or 81267,
		players = {},
		chapter = 1,
		totalChapters = 4,
		shift = 0,
		rounds = 0,
		currentPlayer = 1,
		contributions = {},
		warehouse = {
			iron = 17,
			logs = 17,
			cobble = 12,
			coal = 7,
			iron_sheet = 0,
			plank = 0,
			gravel = 0,
			track = 0,
			bridge = 0,
		},
		grid = {},
		unlocked = 0,
		reputation = 0,
		delivered = 0,
		penalty = 0,
		history = {},
		events = {},
		routeChoices = {},
		currentContract = 4,
		contractAge = 0,
		contractLimit = 16,
		routeHistory = {},
		finished = false,
		won = false,
		visualSeed = rnd(100000),
		contractStatus = "OPEN",
		machineStatus = { capacity = 0, load = 0, active = false, rpm = 0, connections = {} },
		totalManufactured = 0,
		production = {},
		scene = "factory",
	}
	local count = U.clamp(math.floor(tonumber(options.count) or 1), 1, 4)
	for i = 1, count do
		local name = U.name(options.names and options.names[i] or nil)
		g.players[i] = name ~= "" and name or ("ENGINEER " .. i)
		g.contributions[i] = { actions = 0, shifts = 0, contracts = 0, builds = 0 }
	end
	for y = 1, S.H do
		g.grid[y] = {}
		for x = 1, S.W do
			place(g, x, y, "empty")
		end
	end
	-- Immediately operable Create-like press line; players can rebuild the workshop.
	place(g, 2, 4, "depot", 1, "iron")
	place(g, 3, 4, "belt", 1)
	place(g, 4, 4, "press", 1)
	place(g, 5, 4, "belt", 1)
	place(g, 6, 4, "chest", 1)
	place(g, 4, 2, "wheel")
	place(g, 4, 3, "shaft")
	S.refreshRoutes(g)
	S.log(g, "Workshop commissioned. Produce sheets with a shift.")
	return g
end
function S.log(g, s)
	table.insert(g.history, 1, ("SHIFT %02d: %s"):format(g.shift, s))
	while #g.history > 40 do
		table.remove(g.history)
	end
end
function S.refreshRoutes(g)
	local rnd = U.random(g.seed + g.chapter * 31)
	local options = {}
	for i = 1, 2 do
		local idx = ((g.chapter - 1) * 2 + i - 1) % #C.routes + 1
		options[i] = U.copy(C.routes[idx])
		options[i].bonus = rnd(3) - 1
		local rewardItem = (g.chapter % 2 == 0 and "iron" or "logs")
		options[i].reward[rewardItem] = (options[i].reward[rewardItem] or 0) + options[i].bonus
	end
	if rnd(2) == 2 then
		options[1], options[2] = options[2], options[1]
	end
	g.routeChoices = options
end
function S.get(g, x, y)
	x, y = math.floor(x), math.floor(y)
	return g.grid[y] and g.grid[y][x] or nil
end
function S.valid(g)
	if
		type(g) ~= "table"
		or g.version ~= 1
		or type(g.grid) ~= "table"
		or type(g.warehouse) ~= "table"
		or type(g.players) ~= "table"
		or #g.players < 1
		or #g.players > 4
	then
		return false
	end
	if
		type(g.currentPlayer) ~= "number"
		or g.currentPlayer < 1
		or g.currentPlayer > #g.players
		or type(g.contributions) ~= "table"
		or type(g.routeChoices) ~= "table"
	then
		return false
	end
	for y = 1, S.H do
		if type(g.grid[y]) ~= "table" then
			return false
		end
		for x = 1, S.W do
			local t = g.grid[y][x]
			if
				type(t) ~= "table"
				or not C.spec[t.id]
				or type(t.face) ~= "number"
				or t.face < 1
				or t.face > 4
				or type(t.slot) ~= "table"
				or type(t.output) ~= "table"
			then
				return false
			end
		end
	end
	for _, k in ipairs(C.resources) do
		if type(g.warehouse[k]) ~= "number" or g.warehouse[k] < 0 then
			return false
		end
	end
	return true
end
return S
