local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local S = dofile("/games/civcraft/systems.lua")
local H = dofile("/games/civcraft/hex.lua")
local W = dofile("/games/civcraft/world.lua")
local A = dofile("/games/civcraft/actions.lua")
local Actors = dofile("/games/civcraft/actor_lifecycle.lua")
local Victory = dofile("/games/civcraft/victory.lua")
if rawget(_G, "_HOST") then
	local function checkpoint()
		os.queueEvent("opening-checkpoint")
		os.pullEvent("opening-checkpoint")
	end
	W.checkpoint = checkpoint
	S.checkpoint = checkpoint
end
local function fixture(version, ai)
	local state = Lifecycle.newLobby("opening-test", version or "balance4")
	state.mapSeed = 75123
	state.mapSize = "compact"
	state.hostileMode = "off"
	state.players = {
		{ id = 0, name = "OAK", civ = "verdant" },
		{
			id = 1,
			name = "FORGE",
			civ = "forge",
			ai = ai,
		},
	}
	Lifecycle.initialize(state)
	return state, state.players[1]
end
local function ownCities(state, owner)
	local list = {}
	for _, city in ipairs(state.cities) do
		if city.owner == owner then
			list[#list + 1] = city
		end
	end
	return list
end
local function settler(state, owner)
	for _, unit in ipairs(state.units) do
		if unit.owner == owner and unit.kind == "settler" then
			return unit
		end
	end
end
local state, p = fixture()
assert(#ownCities(state, 0) == 0 and #ownCities(state, 1) == 0)
assert(
	state.world.width == 32
		and state.world.height == 22
		and state.world.mapScaleVersion == "founders-v1"
)
for _, player in ipairs(state.players) do
	local counts = {}
	for _, unit in ipairs(state.units) do
		if unit.owner == player.id then
			counts[unit.kind] = (counts[unit.kind] or 0) + 1
			assert(H.passable(unit.x, unit.y, state, unit, S))
		end
	end
	assert(counts.settler == 1 and counts.warrior == 1 and not counts.scout and not counts.builder)
	assert(player.settlersTrained == 0 and not player.capitalFounded)
	assert(S.projectCost("unit", "settler", player) == 28)
end
Victory.check(state, false)
assert(state.phase == "game", "Cityless opening is not a conquest victory")
local unit = assert(settler(state, 0))
local startX, startY = unit.x, unit.y
local target
for _, choice in ipairs(H.reachable(state, unit, 0, S)) do
	if
		not choice.attack
		and choice.cost < unit.movesLeft
		and H.distance(startX, startY, choice.x, choice.y) == 1
	then
		local allowed = true
		for _, city in ipairs(state.cities) do
			if H.distance(city.x, city.y, choice.x, choice.y) < 3 then
				allowed = false
			end
		end
		if allowed then
			target = choice
			break
		end
	end
end
assert(target)
assert(
	A.apply(
		state,
		0,
		{ action = "move", unitID = unit.id, sx = unit.x, sy = unit.y, x = target.x, y = target.y },
		S
	)
)
assert(A.apply(state, 0, { action = "found", unitID = unit.id, x = unit.x, y = unit.y }, S))
local capital = ownCities(state, 0)[1]
assert(
	capital.x == target.x and capital.y == target.y and capital.capitalOf == 0 and p.capitalFounded
)
assert(not settler(state, 0) and p.settlersTrained == 0)
assert(S.centerYields(p, capital, state).science == 2)
Victory.check(state, false)
assert(state.phase == "game", "An opponent who has not yet settled still contests the game")
-- The first-city designation survives migration and does not move to a later city.
S.migrate(state)
assert(p.capitalFounded and capital.capitalOf == 0)
state, p = fixture(nil, true)
Actors.pump(state)
local ai = state.players[2]
assert(ai.capitalFounded and #ownCities(state, 1) == 1, "AI must found its own capital promptly")
assert(ownCities(state, 1)[1].project, "AI must choose first-city production in its founding turn")
assert(#ownCities(state, 0) == 0, "AI processing cannot auto-found the human capital")
for _, version in ipairs({ "baseline", "p1", "balance1", "balance2", "balance3" }) do
	local old = fixture(version)
	assert(old.world.width == 24 and old.world.height == 16)
	assert(
		#ownCities(old, 0) == 1 and not settler(old, 0),
		"Earlier profiles retain their founded-city opening"
	)
end
if fs and textutils then
	state, p = fixture()
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/opening-save-check"
	assert(Saves.writeFile(Saves.path(1), state))
	local restored = S.migrate(assert(Saves.load(1)))
	local traveler = assert(settler(restored, 0))
	assert(#ownCities(restored, 0) == 0 and restored.players[1].settlersTrained == 0)
	assert(
		A.apply(
			restored,
			0,
			{ action = "found", unitID = traveler.id, x = traveler.x, y = traveler.y },
			S
		)
	)
	assert(ownCities(restored, 0)[1].capitalOf == 0)
end
print(
	"PASS: Settler/Guard starts, chosen capital placement, initial price, cityless saves, AI founding and legacy openings"
)
