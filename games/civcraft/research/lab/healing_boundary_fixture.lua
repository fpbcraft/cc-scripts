-- Research-only healing/fortify boundary fixture.
-- It mutates a fresh actual runtime state, then calls Combat.round directly.
local Hex = dofile("/games/civcraft/hex.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local Canonical = dofile("/lab/canonical.lua")

local Fixture = {}

local locations = {
	owned = { x = 4, y = 4, owner = 0 },
	neutral = { x = 12, y = 8, owner = 0 },
	foreign_territory = { x = 20, y = 12, owner = 0 },
	-- Enemy ownership is tested on neutral geography so normal passive rest
	-- healing cannot be mistaken for healer support.
	enemy = { x = 12, y = 8, owner = 1 },
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

local function locationCase(name)
	local point = assert(locations[name], "unknown healing location")
	return { x = point.x, y = point.y, owner = point.owner }
end

function Fixture.cases()
	local result = {}
	local id = 0
	for _, healer in ipairs({ "alchemist", "supplycrew" }) do
		for _, location in ipairs({ "owned", "neutral", "foreign_territory", "enemy" }) do
			for _, acted in ipairs({ false, true }) do
				for _, fortified in ipairs({ false, true }) do
					for _, inRange in ipairs({ true, false }) do
						for _, hp in ipairs({ 40, 98 }) do
							id = id + 1
							result[#result + 1] = {
								id = id,
								healer = healer,
								location = location,
								acted = acted,
								fortified = fortified,
								inRange = inRange,
								hp = hp,
							}
						end
					end
				end
			end
		end
	end
	return result
end

local function setup(state, spec)
	state.round = 7
	state.units = {}
	state.cities = {
		{
			id = 101,
			owner = 0,
			x = 4,
			y = 4,
			name = "A",
			population = 6,
			buildings = {},
		},
		{
			id = 102,
			owner = 1,
			x = 20,
			y = 12,
			name = "B",
			population = 6,
			buildings = {},
		},
	}
	local point = locationCase(spec.location)
	local healerX = point.x + (spec.inRange and 1 or 2)
	local healerY = point.y
	state.units = {
		{
			id = 201,
			owner = 0,
			kind = spec.healer,
			x = healerX,
			y = healerY,
			hp = 80,
			actedThisRound = true,
			healing = false,
			movesLeft = 0,
		},
		{
			id = 202,
			owner = point.owner,
			kind = "warrior",
			x = point.x,
			y = point.y,
			hp = spec.hp,
			actedThisRound = spec.acted,
			healing = spec.fortified,
			movesLeft = 0,
		},
		{
			id = 203,
			owner = 1,
			kind = "warrior",
			x = 23,
			y = 14,
			hp = 40,
			actedThisRound = true,
			movesLeft = 0,
		},
	}
	for _, player in ipairs(state.players or {}) do
		player.ready = false
		player.ai = false
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
end

local function summary(state)
	local healer, recipient, enemy = state.units[1], state.units[2], state.units[3]
	return {
		healerHP = healer.hp,
		recipientHP = recipient.hp,
		enemyHP = enemy.hp,
		healerActedThisRound = healer.actedThisRound,
		recipientActedThisRound = recipient.actedThisRound,
		recipientHealing = recipient.healing == true,
	}
end

function Fixture.run(state, spec)
	setup(state, spec)
	Combat.round(state, Systems)
	return {
		id = spec.id,
		spec = copy(spec),
		afterState = Canonical.encode(state),
		after = summary(state),
	}
end

function Fixture.setupOnly(state, spec)
	setup(state, spec)
end

return Fixture
