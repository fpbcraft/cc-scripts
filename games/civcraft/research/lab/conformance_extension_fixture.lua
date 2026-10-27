-- Fast Lupa-only conformance fixtures. No gameplay modules are modified.
local Hex = dofile("/games/civcraft/hex.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Events = dofile("/games/civcraft/events.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Fixture = {}

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

local function clearOfKnown(observer, state, x, y)
	for yy = math.max(1, y - 2), math.min(state.world.height, y + 2) do
		for xx = math.max(1, x - 2), math.min(state.world.width, x + 2) do
			local key = xx .. ":" .. yy
			if observer.explored[key] or observer.visible and observer.visible[key] then
				return false
			end
		end
	end
	return true
end

local function pair(state)
	for y = 2, state.world.height - 1 do
		for x = 2, state.world.width - 1 do
			if land(state, x, y) and not cityAt(state, x, y) then
				for _, nextTile in ipairs(Hex.neighbours(x, y, state)) do
					if
						land(state, nextTile.x, nextTile.y)
						and not cityAt(state, nextTile.x, nextTile.y)
					then
						return { x = x, y = y }, nextTile
					end
				end
			end
		end
	end
	assert(false, "No adjacent passable fixture pair")
end

function Fixture.hideRival(state)
	local observer, rival = state.players[1], state.players[2]
	local hidden
	for y = 2, state.world.height - 1 do
		for x = 2, state.world.width - 1 do
			local key = x .. ":" .. y
			if
				not observer.explored[key]
				and clearOfKnown(observer, state, x, y)
				and not cityAt(state, x, y)
				and land(state, x, y)
			then
				hidden = { x = x, y = y }
				break
			end
		end
		if hidden then
			break
		end
	end
	assert(hidden, "Could not find an unexplored land tile")
	rival.aiPlan = { version = 1, primary = "secret-conquest", privatePlan = "do-not-leak" }
	rival.gold = 987654321
	rival.stockpile = { diamond = 777, iron = 666, secret = 555 }
	state.cities[#state.cities + 1] = {
		id = 901,
		owner = rival.id,
		x = hidden.x,
		y = hidden.y,
		name = "HIDDEN CAPITAL",
		population = 9,
		buildings = { eyes = true, bank = true },
	}
	state.units[#state.units + 1] = {
		id = 902,
		owner = rival.id,
		kind = "warrior",
		x = hidden.x,
		y = hidden.y,
		hp = 100,
		movesLeft = 1,
		moved = false,
	}
	Events.emit(state, { type = "order", recipient = rival.id, content = "SECRET-RIVAL-EVENT" })
	return hidden
end

function Fixture.setupSurprise(state)
	local target, attacker = pair(state)
	state.round = 20
	state.hostileMode = "off"
	state.units = {
		{
			id = 801,
			owner = state.players[1].id,
			kind = "warrior",
			x = attacker.x,
			y = attacker.y,
			hp = 100,
			movesLeft = 1,
			moved = false,
		},
		{
			id = 802,
			owner = state.players[2].id,
			kind = "warrior",
			x = target.x,
			y = target.y,
			hp = 100,
			movesLeft = 1,
			moved = false,
		},
	}
	for _, player in ipairs(state.players) do
		player.ready = false
		player.contacts = player.contacts or {}
	end
	state.players[1].contacts[state.players[2].id] = true
	state.players[2].contacts[state.players[1].id] = true
	-- The defender has ended its turn; surprise war should grant its one
	-- reaction allowance in Scheduler.rebuild().
	state.players[2].ready = true
	Systems.migrate(state)
	Diplomacy.migrate(state)
	World.reveal(state, Hex, Systems)
	return { attacker = attacker, target = target }
end

function Fixture.declareSurprise(state)
	return Actions.apply(state, state.players[1].id, {
		action = "declareWar",
		target = state.players[2].id,
		kind = "surprise",
	}, Systems)
end

function Fixture.defenderReaction(state, positions)
	return Actions.apply(state, state.players[2].id, {
		action = "move",
		sx = positions.target.x,
		sy = positions.target.y,
		x = positions.attacker.x,
		y = positions.attacker.y,
	}, Systems)
end

return Fixture
