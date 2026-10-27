local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hostiles = dofile("/games/civcraft/hostiles.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Fixture = dofile("/games/civcraft/research/lab/wartime_save_parity_fixture.lua")
if os.queueEvent and os.pullEvent then
	local Cooperative = dofile("/games/civcraft/cooperative.lua")
	local World = dofile("/games/civcraft/world.lua")
	local work = {}
	local function checkpoint()
		Cooperative.checkpoint(work, false, true)
	end
	Systems.checkpoint, World.checkpoint = checkpoint, checkpoint
end
local state = Lifecycle.newLobby("hostile-capture-regression", "p1")
state.mapSeed, state.mapSize, state.mapType, state.hostileMode = 75123, "compact", "pangaea", "off"
state.players = { { id = 0, name = "P1", civ = "forge" }, { id = 1, name = "P2", civ = "scholar" } }
state = Lifecycle.initialize(state)
Fixture.setup(state)
Fixture.capture(state)
local prisoner
for _, unit in ipairs(state.units) do
	if unit.id == 201 then
		prisoner = unit
	end
end
assert(prisoner and prisoner.owner == Hostiles.owner and prisoner.spawner == nil)
local x, y = prisoner.x, prisoner.y
state.round = 21
Hostiles.round(state, Systems)
assert(prisoner.x == x and prisoner.y == y and prisoner.movesLeft == 0)
assert(prisoner.owner == Hostiles.owner and not prisoner.movementAllowanceRound)
-- Preserve legacy saves containing a real mob without a spawn association.
for _, unit in ipairs(state.units) do
	if unit.kind == "zombie" then
		unit.spawner = nil
	end
end
state.round = 22
Hostiles.round(state, Systems)
assert(prisoner.x == x and prisoner.y == y and prisoner.owner == Hostiles.owner)
local previous = Stacks.capture(state, prisoner, 0)
assert(previous == Hostiles.owner and prisoner.owner == 0 and prisoner.movesLeft == 0)
assert(prisoner.actedThisRound and not prisoner.autoExplore)
print(
	"PASS: hostile capture survives subsequent rounds, civilians stay captive, and orphan mobs remain valid"
)
