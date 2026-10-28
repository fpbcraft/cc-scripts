-- CraftOS side of the research-only wartime/save parity fixture.
local environment = setmetatable({}, { __index = _G })
environment._G = environment
environment.dofile = function(path)
	local handle = assert(fs.open(path, "r"))
	local source = handle.readAll()
	handle.close()
	return assert(load(source, "@" .. path, "t", environment))()
end

environment.dofile("/games/civcraft/module_cache.lua").install(environment)
local Engine = environment.dofile("/lab/engine.lua")
local Canonical = environment.dofile("/lab/canonical.lua")
local Fixture = environment.dofile("/lab/wartime_save_parity_fixture.lua")
local Lifecycle = environment.dofile("/games/civcraft/match_lifecycle.lua")
local Saves = environment.dofile("/games/civcraft/saves.lua")
local Systems = environment.dofile("/games/civcraft/systems.lua")
local World = environment.dofile("/games/civcraft/world.lua")
local Diplomacy = environment.dofile("/games/civcraft/diplomacy.lua")

local config = {
	seed = 75123,
	mapSize = "compact",
	mapType = "pangaea",
	hostileMode = "off",
	players = {
		{ civilization = "forge" },
		{ civilization = "scholar" },
	},
}

local state = Engine.newGame(config)
Fixture.setup(state)
local function capture(label, current)
	return {
		label = label,
		state = Canonical.encode(current),
		observation0 = Canonical.encode(Engine.observe(current, 0)),
		observation1 = Canonical.encode(Engine.observe(current, 1)),
	}
end

local checkpoints = { capture("before-capture", state) }
Fixture.capture(state)
checkpoints[#checkpoints + 1] = capture("after-capture", state)

-- The direct branch is the expected continuation. The loaded branch below
-- must reach the same canonical state after the same lifecycle boundary.
local hostileProbe = Canonical.decode(Canonical.encode(state))
local hostileOK, hostileError = pcall(function()
	Lifecycle.advance(hostileProbe)
end)
local direct = Canonical.decode(Canonical.encode(state))
assert(Saves.save(1, state))
local loaded = assert(Saves.load(1), "Expected saved fixture")
loaded = Systems.migrate(World.migrate(loaded))
Diplomacy.migrate(loaded)
World.reveal(loaded, environment.dofile("/games/civcraft/hex.lua"), Systems)
checkpoints[#checkpoints + 1] = capture("after-save-load", loaded)
-- Keep the known orphan-settler crash as an explicit diagnostic, then use a
-- controlled hostile-off continuation to test save/reload state continuity.
direct.hostileMode = "off"
loaded.hostileMode = "off"
Lifecycle.advance(direct)
Lifecycle.advance(loaded)

local registeredState = Engine.newGame(config)
local registeredWar = Fixture.registeredWar(registeredState)
local registeredCheckpoint = capture("registered-war-capture", registeredState)
checkpoints[#checkpoints + 1] = capture("continuation-direct", direct)
checkpoints[#checkpoints + 1] = capture("continuation-loaded", loaded)

local output = assert(fs.open("/wartime_save_parity_native.json", "w"))
local capturedOwner
for _, unit in ipairs(loaded.units or {}) do
	if unit.id == 201 then
		capturedOwner = unit.owner
	end
end
output.write(textutils.serializeJSON({
	host = _G._HOST,
	checkpoints = checkpoints,
	registeredWar = { outcome = registeredWar, checkpoint = registeredCheckpoint },
	hostileContinuation = { ok = hostileOK, error = hostileError },
	savePath = Saves.path(1),
	capturedSettlerOwner = capturedOwner,
}))
output.close()
return true
