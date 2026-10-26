local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Writer = dofile("/games/civcraft/state_writer.lua")
local Coop = dofile("/games/civcraft/cooperative.lua")
local W = dofile("/games/civcraft/world.lua")
local H = dofile("/games/civcraft/hex.lua")
local value = {
	name = 'quote"\\\n\0é',
	[0] = false,
	[-4] = 0.125,
	positive = math.huge,
	negative = -math.huge,
	nan = 0 / 0,
	tiles = {},
}
for index = 1, 4096 do
	value.tiles["hex:" .. index] = { owner = index % 4, terrain = "forest", known = true }
end
value.long = ('binary\0quote"\n'):rep(2000)
local chunks, calls, total = {}, 0, 0
Writer.write(
	{
		write = function(text)
			assert(#text <= Writer.chunkSize, "Each save write is bounded")
			chunks[#chunks + 1], total = text, total + #text
		end,
	},
	value,
	function()
		calls = calls + 1
	end
)
assert(calls > 100 and #chunks > 10 and total > 100000)
local restored = assert(load("return " .. table.concat(chunks), "saved state", "t", {}))()
assert(restored.name == value.name and restored.long == value.long)
assert(restored[0] == false and restored[-4] == 0.125 and restored.nan ~= restored.nan)
assert(restored.positive == math.huge and restored.negative == -math.huge)
for key, tile in pairs(value.tiles) do
	assert(restored.tiles[key].owner == tile.owner and restored.tiles[key].known)
end
local recursive = {}
recursive.self = recursive
assert(not pcall(Writer.write, { write = function() end }, recursive))
assert(not pcall(Writer.write, { write = function() end }, { fn = function() end }))
local shared = { x = 7 }
chunks = {}
Writer.write({
	write = function(text)
		chunks[#chunks + 1] = text
	end,
}, { a = shared, b = shared })
restored = assert(load("return " .. table.concat(chunks), "aliases", "t", {}))()
assert(restored.a.x == 7 and restored.b.x == 7)
local oldEpoch, oldQueue, oldPull, oldStart, oldCancel =
	os.epoch, os.queueEvent, os.pullEvent, os.startTimer, os.cancelTimer
local now, events = 0, {}
os.epoch = function()
	return now
end
os.queueEvent = function(...)
	events[#events + 1] = { ... }
end
os.startTimer = function()
	return 99
end
os.cancelTimer = function() end
os.pullEvent = function()
	return table.unpack(assert(table.remove(events, 1)))
end
local startup = {}
Coop.checkpoint(startup, false, true)
now = 40
events = { { "mouse_click", 1, 4, 5 }, { "rednet_message", 7, { action = "end" }, "protocol" } }
Coop.checkpoint(startup, false, true)
assert(
	startup.yieldToken == 1 and startup.work < 128,
	"Bootstrap checkpoints sample elapsed time without waiting for 128 calls"
)
assert(
	#startup.pendingEvents == 2
		and startup.pendingEvents[1][1] == "mouse_click"
		and startup.pendingEvents[2][1] == "rednet_message",
	"Watchdog yields preserve pending input"
)
os.epoch, os.queueEvent, os.pullEvent, os.startTimer, os.cancelTimer =
	oldEpoch, oldQueue, oldPull, oldStart, oldCancel
local state = {
	phase = "game",
	round = 1,
	players = { { id = 0, techs = {} } },
	cities = {},
	units = { { id = 1, owner = 0, kind = "scout", x = 16, y = 12 } },
	world = { width = 32, height = 24, tiles = {} },
}
for y = 1, 24 do
	for x = 1, 32 do
		state.world.tiles[W.key(x, y)] = "plains"
	end
end
local checks, oldCheckpoint = 0, W.checkpoint
W.checkpoint = function()
	checks = checks + 1
end
W.reveal(state, H, { units = { scout = { vision = 40 } } })
W.checkpoint = oldCheckpoint
assert(
	checks >= 25 and state.players[1].mapMemory.observations["32:24"],
	"Large visibility memory updates checkpoint inside the tile loop"
)
print(
	"CIVCRAFT: bounded streaming saves, exact Lua round trips, encoding failures, bootstrap/input safety and visibility checkpoints passed."
)
