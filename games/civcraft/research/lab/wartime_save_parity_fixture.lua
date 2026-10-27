-- Research-only handcrafted wartime fixture.
--
-- The production hostile loop is the actor that captures a settler: an
-- unregistered hostile owner cannot submit Actions.apply() itself.  This
-- fixture therefore places a melee hostile and a player settler on adjacent
-- passable tiles, then invokes Hostiles.round(), which reaches
-- Combat.attack()/Stacks.capture() through the normal game path.  No core
-- gameplay module is changed.
local Hex = dofile("/games/civcraft/hex.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Hostiles = dofile("/games/civcraft/hostiles.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Fixture = { hostileOwner = -2147483647 }

local function cityAt(state, x, y)
	for _, city in ipairs(state.cities or {}) do
		if city.x == x and city.y == y then
			return true
		end
	end
	return false
end

local function land(state, x, y)
	local terrain = Hex.terrain(x, y, state)
	return terrain ~= "water" and terrain ~= "mountain"
end

local function distantFromCities(state, x, y)
	for _, city in ipairs(state.cities or {}) do
		if Hex.distance(city.x, city.y, x, y) <= 4 then
			return false
		end
	end
	return true
end

local function adjacentPair(state)
	for y = 2, state.world.height - 1 do
		for x = 2, state.world.width - 1 do
			if land(state, x, y) and not cityAt(state, x, y) and distantFromCities(state, x, y) then
				for _, neighbour in ipairs(Hex.neighbours(x, y, state)) do
					if
						land(state, neighbour.x, neighbour.y)
						and not cityAt(state, neighbour.x, neighbour.y)
						and distantFromCities(state, neighbour.x, neighbour.y)
					then
						return { x = x, y = y }, neighbour
					end
				end
			end
		end
	end
	return nil
end

function Fixture.setup(state)
	assert(state.phase == "game" and state.world, "Expected an initialized game")
	local target, attacker = adjacentPair(state)
	assert(target and attacker, "Could not find a distant adjacent land pair")
	state.round = 20
	state.hostileRound = nil
	state.hostileMode = "standard"
	state.nextId = 200
	state.spawners = {
		{ id = 1, x = attacker.x, y = attacker.y, kind = "spawner", cleared = false },
	}
	-- Remove generated actors so the target choice is deterministic and the
	-- only nearby non-city target is the labeled player settler.
	state.units = {
		{
			id = 201,
			owner = state.players[1].id,
			kind = "settler",
			x = target.x,
			y = target.y,
			hp = 100,
			movesLeft = 3,
			moved = false,
		},
		{
			id = 202,
			owner = Fixture.hostileOwner,
			kind = "zombie",
			x = attacker.x,
			y = attacker.y,
			hp = 100,
			movesLeft = 2,
			moved = false,
			spawner = 1,
		},
	}
	for _, player in ipairs(state.players) do
		player.ready = false
	end
	Systems.migrate(state)
	Diplomacy.migrate(state)
	World.reveal(state, Hex, Systems)
	return state
end

function Fixture.capture(state)
	Hostiles.round(state, Systems)
	local captured
	for _, unit in ipairs(state.units or {}) do
		if unit.id == 201 then
			captured = unit
		end
	end
	assert(captured and captured.owner == Fixture.hostileOwner, "Expected hostile settler capture")
	return state
end

-- Separate registered-player control: this is intentionally not used by the
-- hostile save fixture above. It proves that a normal declared war can legally
-- capture an opposing settler through Actions.apply -> Combat.attack.
function Fixture.registeredWar(state)
	assert(state.phase == "game" and state.world, "Expected an initialized game")
	local target, attacker = adjacentPair(state)
	assert(target and attacker, "Could not find a distant adjacent land pair")
	state.hostileMode = "off"
	state.round = 20
	state.units = {
		{
			id = 301,
			owner = state.players[1].id,
			kind = "warrior",
			x = attacker.x,
			y = attacker.y,
			hp = 100,
			movesLeft = 1,
			moved = false,
		},
		{
			id = 302,
			owner = state.players[2].id,
			kind = "settler",
			x = target.x,
			y = target.y,
			hp = 100,
			movesLeft = 3,
			moved = false,
		},
	}
	for _, player in ipairs(state.players) do
		player.ready = false
		player.contacts = player.contacts or {}
	end
	state.players[1].contacts[state.players[2].id] = true
	state.players[2].contacts[state.players[1].id] = true
	Systems.migrate(state)
	Diplomacy.migrate(state)
	World.reveal(state, Hex, Systems)
	local declared, declareReason = Actions.apply(state, state.players[1].id, {
		action = "declareWar",
		target = state.players[2].id,
		kind = "normal",
	}, Systems)
	assert(declared, declareReason)
	-- Normal registered war is announced first; the next authoritative round
	-- boundary activates it before the settler capture order is legal.
	Lifecycle.advance(state)
	local captured, captureReason = Actions.apply(state, state.players[1].id, {
		action = "move",
		sx = attacker.x,
		sy = attacker.y,
		x = target.x,
		y = target.y,
	}, Systems)
	local settlerOwner
	for _, unit in ipairs(state.units or {}) do
		if unit.id == 302 then
			settlerOwner = unit.owner
		end
	end
	return {
		declareWar = { ok = declared, reason = declareReason },
		capture = { ok = captured, reason = captureReason },
		settlerOwner = settlerOwner,
		warActive = Diplomacy.war(state, state.players[1].id, state.players[2].id) ~= nil,
	}
end

return Fixture
