-- Manual desktop benchmark: lua5.3 tests/civcraft_world_benchmark.lua
-- This measures simulation/renderer code; it does not measure peripheral or rednet latency.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local W = dofile("games/civcraft/world.lua")
local H = dofile("games/civcraft/hex.lua")
local S = dofile("games/civcraft/systems.lua")
local UI = dofile("games/civcraft/ui.lua")
local function serialize(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = { "{" }
	for k, v in pairs(value) do
		parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
	end
	parts[#parts + 1] = "}"
	return table.concat(parts)
end
local function measure(fn)
	local start = os.clock()
	local out = fn()
	return (os.clock() - start) * 1000, out
end
for _, size in ipairs(W.sizeOrder) do
	collectgarbage("collect")
	local before = collectgarbage("count")
	local checkpoints = 0
	W.checkpoint = function()
		checkpoints = checkpoints + 1
	end
	local generation, world = measure(function()
		return W.generate(238711, size, 4, "continents")
	end)
	local state = {
		phase = "game",
		ruleset = "create",
		round = 1,
		nextId = 100,
		world = world,
		players = {},
		cities = {},
		units = {},
	}
	for i, start in ipairs(world.starts) do
		state.players[i] =
			{ id = i, name = "PLAYER " .. i, techs = {}, ai = true, civ = S.civs[i].id }
		state.cities[i] =
			{ id = i, owner = i, x = start.x, y = start.y, population = 2, buildings = {} }
		state.units[i] =
			{ id = i + 4, owner = i, kind = "scout", x = start.x + 1, y = start.y, movesLeft = 4 }
	end
	S.migrate(state)
	W.reveal(state, H, S)
	local p = state.players[1]
	for y = 1, world.height do
		for x = 1, world.width do
			p.explored[W.key(x, y)] = true
		end
	end
	local path = measure(function()
		return H.reachable(state, state.units[1], 1, S)
	end)
	local exhaustive = measure(function()
		local scout = {}
		for k, v in pairs(state.units[1]) do
			scout[k] = v
		end
		scout.movesLeft = world.width * world.height * 3
		return H.reachable(state, scout, 1, S)
	end)
	local snapshot, view = measure(function()
		return W.forPlayer(state, 1)
	end)
	local saved, encoded = measure(function()
		return serialize(state)
	end)
	local loaded = measure(function()
		local restored = assert(load("return " .. encoded))()
		W.migrate(restored)
		S.migrate(restored)
		return restored
	end)
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 474, 468
			end
			return 79, 52
		end,
		getPaletteColor = function()
			return 0, 0, 0
		end,
		setPaletteColor = function() end,
		setGraphicsMode = function() end,
		drawPixels = function() end,
	}
	local ui = UI.new(monitor, function() end)
	local rendering = measure(function()
		ui:draw(state, 1, { screen = "game" })
	end)
	local redraw = measure(function()
		ui:draw(state, 1, { screen = "game" })
	end)
	local ai = measure(function()
		for _, p in ipairs(state.players) do
			S.aiTurn(state, p, H)
		end
	end)
	collectgarbage("collect")
	local retained = collectgarbage("count") - before
	print(
		string.format(
			"%s %dx%d gen=%.1f path=%.1f allLand=%.1f snapshot=%.1f save=%.1f load=%.1f draw=%.1f redraw=%.1f ai4=%.1f saveKB=%.1f liveKB=%.1f checkpoints=%d",
			size,
			world.width,
			world.height,
			generation,
			path,
			exhaustive,
			snapshot,
			saved,
			loaded,
			rendering,
			redraw,
			ai,
			#encoded / 1024,
			retained,
			checkpoints
		)
	)
end
