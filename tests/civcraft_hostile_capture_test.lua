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
assert(state.hostileMode == "standard", "Capture fixture must enable hostile processing")
Fixture.capture(state)
assert(state.hostileRound == 20, "Capture must run a real hostile round")
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
assert(state.hostileRound == 21, "Captured civilian must survive an active hostile round")
assert(prisoner.x == x and prisoner.y == y and prisoner.movesLeft == 0)
assert(prisoner.owner == Hostiles.owner and not prisoner.movementAllowanceRound)
-- Preserve legacy saves containing a real mob without a spawn association.
local orphan
for _, unit in ipairs(state.units) do
	if unit.owner == Hostiles.owner and unit.kind == "zombie" then
		orphan = unit
		break
	end
end
assert(orphan, "Fixture must retain a real hostile mob")
orphan.spawner = nil
-- The capture-only attack can leave the zombie sharing the prisoner's tile.
-- Move it back to its empty spawn site so the hostile loop can process it.
local spawner = assert(state.spawners[1], "Fixture must retain its spawner")
assert(spawner.x ~= x or spawner.y ~= y, "Orphan test needs a separate tile")
orphan.x, orphan.y = spawner.x, spawner.y
orphan.movesLeft, orphan.moved = -1, false
state.round = 22
Hostiles.round(state, Systems)
assert(state.hostileRound == 22, "Orphan mob must not abort its hostile round")
assert(orphan.movesLeft == 0 and orphan.moved, "Orphan mob must execute its hostile turn")
assert(prisoner.x == x and prisoner.y == y and prisoner.owner == Hostiles.owner)
local previous = Stacks.capture(state, prisoner, 0)
assert(previous == Hostiles.owner and prisoner.owner == 0 and prisoner.movesLeft == 0)
assert(prisoner.actedThisRound and not prisoner.autoExplore)
print(
	"PASS: hostile capture survives subsequent rounds, civilians stay captive, and orphan mobs remain valid"
)
