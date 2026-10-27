-- Dedicated CraftOS profile only: generated benchmark campaigns overwrite slot 1.
local env =
	dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
env.dofile("/games/civcraft/module_cache.lua").install(env)
local World = env.dofile("/games/civcraft/world.lua")
local Hex = env.dofile("/games/civcraft/hex.lua")
local Systems = env.dofile("/games/civcraft/systems.lua")
local Saves = env.dofile("/games/civcraft/saves.lua")
local Cooperative = env.dofile("/games/civcraft/cooperative.lua")
local Diplomacy = env.dofile("/games/civcraft/diplomacy.lua")
local Movement = env.dofile("/games/civcraft/movement_budget.lua")
local work, checkpoints = {}, 0
local function checkpoint()
	checkpoints = checkpoints + 1
	Cooperative.checkpoint(work, false, true)
end
World.checkpoint, Systems.checkpoint, Saves.checkpoint = checkpoint, checkpoint, checkpoint
local report = { host = _G._HOST, worlds = {}, turns = {} }
local largest
for _, size in ipairs(World.sizeOrder) do
	for _, kind in ipairs(World.types) do
		local started = os.epoch("utc")
		local world = World.generate(75123, size, 4, kind)
		assert(world.width == World.sizes[size][1] and world.height == World.sizes[size][2])
		report.worlds[#report.worlds + 1] =
			{ size = size, kind = kind, elapsed = os.epoch("utc") - started }
		if size == "vast" and kind == "continents" then
			largest = world
		end
		checkpoint()
	end
end
local state = {
	version = 6,
	phase = "game",
	ruleset = "create",
	round = 1,
	nextId = 20,
	world = largest,
	players = {},
	cities = {},
	units = {},
	diplomacy = Diplomacy.new(),
	hostileMode = "off",
}
for index, civ in ipairs({ "iron", "scholar", "forge", "merchant" }) do
	local start = largest.starts[index]
	state.players[index] = {
		id = index - 1,
		name = "BENCHMARK " .. index,
		civ = civ,
		techs = {},
		gold = 20,
		ai = true,
	}
	state.cities[index] = {
		id = index,
		owner = index - 1,
		capitalOf = index - 1,
		x = start.x,
		y = start.y,
		population = 2,
		buildings = {},
	}
	state.units[index] = {
		id = index + 4,
		owner = index - 1,
		kind = "warrior",
		x = start.x + 1,
		y = start.y,
		movesLeft = 2,
	}
end
Systems.migrate(state)
Diplomacy.migrate(state)
for round = 1, 3 do
	state.round = round
	Diplomacy.boundary(state)
	World.reveal(state, Hex, Systems)
	for _, player in ipairs(state.players) do
		player.ready = false
		local started = os.epoch("utc")
		Systems.aiTurn(state, player, Hex)
		report.turns[#report.turns + 1] =
			{ round = round, player = player.id, elapsed = os.epoch("utc") - started }
	end
	Systems.production(state, Hex)
	for _, unit in ipairs(state.units) do
		Movement.reset(
			{ round = round + 1, world = state.world },
			unit,
			Systems.units[unit.kind],
			state.players[unit.owner + 1],
			Hex
		)
	end
end
local started = os.epoch("utc")
Saves.save(1, state)
local restored = assert(Saves.load(1))
assert(restored.world.width == 96 and restored.world.height == 60)
assert(restored.world.tiles["96:60"] == state.world.tiles["96:60"])
assert(restored.players[1].aiPlan.primary == state.players[1].aiPlan.primary)
report.saveElapsed, report.bytes = os.epoch("utc") - started, fs.getSize(Saves.path(1))
report.checkpoints, report.yields = checkpoints, work.yieldToken or 0
local file = assert(fs.open("/civcraft-world-stress.txt", "w"))
file.write(textutils.serialize(report))
file.close()
print("CIVCRAFT: larger map generation, four AI actors, reveal and save/reload passed.")
