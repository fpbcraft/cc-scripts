local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local A = dofile("/games/civcraft/actions.lua")
local C = dofile("/games/civcraft/combat.lua")
local E = dofile("/games/civcraft/events.lua")
local H = dofile("/games/civcraft/hex.lua")
local S = dofile("/games/civcraft/systems.lua")
local Stack = dofile("/games/civcraft/unit_stacks.lua")
local Tasks = dofile("/games/civcraft/turn_tasks.lua")
local W = dofile("/games/civcraft/world.lua")
local function fixture(kind)
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		nextId = 10,
		players = {
			{ id = 1, name = "ONE", civ = "iron", techs = {}, gold = 100 },
			{ id = 2, name = "TWO", civ = "forge", techs = {}, gold = 100 },
		},
		cities = {},
		units = {
			{ id = 1, owner = 1, kind = kind or "warrior", x = 3, y = 4, movesLeft = 4 },
			{ id = 2, owner = 1, kind = "settler", x = 3, y = 4, movesLeft = 3 },
		},
		world = { width = 12, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} },
	}
	for y = 1, 10 do
		for x = 1, 12 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	S.migrate(state)
	W.reveal(state, H, S)
	return state, state.units[1], state.units[2]
end
local function command(state, unit, action, extra)
	local request = { action = action, unitID = unit.id, x = unit.x, y = unit.y }
	for key, value in pairs(extra or {}) do
		request[key] = value
	end
	return A.apply(state, unit.owner, request, S)
end
local function attach(state, unit, other)
	assert(command(state, unit, "attachEscort", { partnerID = other.id }))
	assert(Stack.partner(state, unit) == other and Stack.partner(state, other) == unit)
end
local function move(state, unit, x, y)
	return command(state, unit, "move", { sx = unit.x, sy = unit.y, x = x, y = y })
end
local function choice(state, unit, x, y)
	for _, option in ipairs(H.reachable(state, unit, unit.owner, S)) do
		if option.x == x and option.y == y then
			return option
		end
	end
end
local state, guard, settler = fixture()
guard.standby, settler.standby = true, true
attach(state, guard, settler)
assert(
	guard.movesLeft == 4 and settler.movesLeft == 3 and not guard.standby and not settler.standby
)
assert(Tasks.idle(state, guard, 1) and not Tasks.idle(state, settler, 1))
local projection = W.forPlayer(state, 1)
assert(
	Stack.partner(projection, projection.units[1]),
	"Owned projections retain the saved formation"
)
assert(command(state, settler, "skipTurn"))
assert(not Tasks.idle(state, guard, 1) and guard.skippedTurn == settler.skippedTurn)
assert(command(state, settler, "standby", { value = true }))
assert(guard.standby and settler.standby)
assert(command(state, guard, "standby", { value = false }))
assert(not guard.standby and not settler.standby)
assert(command(state, settler, "detachEscort"))
assert(not guard.escortID and not settler.escortID and guard.movesLeft == 4)
settler.x = 4
assert(not command(state, guard, "attachEscort", { partnerID = settler.id }))
settler.x, settler.owner = 3, 2
assert(not command(state, guard, "attachEscort", { partnerID = settler.id }))
settler.owner = 1
attach(state, guard, settler)
settler.x = 4
Stack.migrate(state)
assert(not guard.escortID and not settler.escortID)

-- Distinct terrain costs must retain both budgets, rather than using the smaller one for both.
for _, lead in ipairs({ 1, 2 }) do
	state, guard, settler = fixture()
	state.world.tiles[W.key(4, 4)] = "forest"
	attach(state, guard, settler)
	local unit = state.units[lead]
	local destination = assert(choice(state, unit, 6, 4))
	assert(
		destination.cost <= unit.movesLeft
			and destination.escortCost <= state.units[3 - lead].movesLeft
	)
	assert(move(state, unit, 6, 4))
	assert(guard.x == 6 and settler.x == 6 and guard.y == settler.y)
	assert(
		guard.movesLeft == 0 and settler.movesLeft == 0,
		"Each member pays its own three-step cost"
	)
	local moved = {}
	for _, event in ipairs(E.forPlayer(state, 1).entries) do
		if event.type == "move" then
			moved[event.actor.id] = event
		end
	end
	assert(moved[1] and moved[2], "Both movements have frozen observer events")
end

state, guard, settler = fixture()
attach(state, guard, settler)
settler.movesLeft, settler.moved = 0, true
assert(not choice(state, guard, 4, 4))
assert(not move(state, guard, 4, 4))
assert(guard.x == 3 and guard.movesLeft == 4 and settler.x == 3)
assert(command(state, guard, "detachEscort"))
assert(move(state, guard, 4, 4), "Detachment releases only the guard's existing movement")

state, guard, settler = fixture("archer")
attach(state, guard, settler)
settler.movesLeft, settler.moved = 0, true
local enemy = { id = 3, owner = 2, kind = "warrior", x = 5, y = 4, movesLeft = 2 }
state.units[#state.units + 1] = enemy
S.migrate(state)
W.reveal(state, H, S)
assert(choice(state, guard, 5, 4).ranged)
assert(move(state, guard, 5, 4))
assert(guard.x == 3 and settler.x == 3 and enemy.hp < 100 and Stack.partner(state, guard))

state, guard, settler = fixture()
attach(state, guard, settler)
enemy = { id = 3, owner = 2, kind = "archer", x = 4, y = 4, movesLeft = 2, hp = 1 }
state.units[#state.units + 1] = enemy
S.migrate(state)
W.reveal(state, H, S)
assert(move(state, guard, 4, 4))
assert(guard.x == 4 and settler.x == 4 and settler.movesLeft == 2 and Stack.partner(state, guard))

state, guard, settler = fixture()
attach(state, guard, settler)
enemy = { id = 3, owner = 2, kind = "settler", x = 4, y = 4, movesLeft = 2 }
state.units[#state.units + 1] = enemy
S.migrate(state)
W.reveal(state, H, S)
assert(
	not choice(state, guard, 4, 4),
	"An escorted guard cannot create a third occupant by capture"
)
local forecast, why = C.predict(state, guard, { x = 4, y = 4 }, S)
assert(not forecast and why:find("Detach"))
assert(command(state, settler, "detachEscort"))
assert(move(state, guard, 4, 4) and enemy.owner == 1 and settler.x == 3)

for _, action in ipairs({ "disband", "found" }) do
	state, guard, settler = fixture()
	attach(state, guard, settler)
	assert(command(state, settler, action))
	assert(not guard.escortID and not Stack.byID(state, 2), "Removing a settler detaches its guard")
end
state, guard, settler = fixture()
attach(state, guard, settler)
guard.hp = 1
enemy = { id = 3, owner = 2, kind = "archer", x = 4, y = 4, movesLeft = 2 }
state.units[#state.units + 1] = enemy
S.migrate(state)
W.reveal(state, H, S)
assert(move(state, enemy, 3, 4))
assert(not Stack.byID(state, 1) and not settler.escortID and settler.owner == 1)
print(
	"CIVCRAFT: escort ownership, saved links, shared tasks, dual movement budgets, attacks and removal cleanup passed."
)

local Paths = dofile("/games/civcraft/escort_paths.lua")
local graph = {
	["1:1"] = { { x = 2, y = 1 }, { x = 1, y = 2 } },
	["2:1"] = { { x = 2, y = 2 } },
	["1:2"] = { { x = 2, y = 2 } },
	["2:2"] = { { x = 3, y = 2 } },
}
local syntheticHex = {
	neighbours = function(x, y)
		return graph[x .. ":" .. y] or {}
	end,
	terrain = function()
		return "plains"
	end,
	moveCost = function(x, y, _, unit)
		local civilian = unit.kind == "settler"
		if x == 2 and y == 1 then
			return civilian and 3 or 1
		end
		if x == 1 and y == 2 then
			return civilian and 1 or 3
		end
		if x == 3 then
			return civilian and 2 or 1
		end
		return 1
	end,
}
local noZones = {
	map = function()
		return {}
	end,
	locked = function()
		return false
	end,
	visible = function()
		return true
	end,
}
state, guard, settler = fixture()
guard.x, guard.y, settler.x, settler.y = 1, 1, 1, 1
guard.movesLeft, settler.movesLeft = 5, 5
attach(state, guard, settler)
local route
for _, candidate in ipairs(Paths.reachable(state, guard, settler, 1, S, syntheticHex, noZones)) do
	if candidate.x == 3 and candidate.y == 2 then
		route = candidate
	end
end
assert(
	route and route.cost == 5 and route.escortCost == 4 and route.path[2].y == 2,
	"Keep the more expensive guard path when the cheaper path exhausts the settler"
)

local Movement = dofile("/games/civcraft/movement_budget.lua")
for _, kind in ipairs({ "warrior", "horseman" }) do
	state, guard, settler = fixture(kind)
	attach(state, guard, settler)
	state.units[#state.units + 1] =
		{ id = 3, owner = 2, kind = "warrior", x = 5, y = 4, movesLeft = 2 }
	S.migrate(state)
	W.reveal(state, H, S)
	assert(move(state, settler, 4, 4))
	assert(guard.x == 4 and settler.x == 4)
	if kind == "horseman" then
		assert(
			settler.movesLeft == 2 and choice(state, settler, 4, 3),
			"Civilian inherits mounted escort immunity"
		)
	else
		assert(
			settler.movesLeft == 0 and not choice(state, guard, 4, 3),
			"Civilian control entry stops the group"
		)
	end
end
state, guard, settler = fixture()
state.players[1].techs.navigation = true
for y = 1, 10 do
	for x = 1, 12 do
		state.world.tiles[W.key(x, y)] = "water"
	end
end
state.world.tiles[W.key(8, 4)] = "plains"
Movement.reset(state, guard, S.units[guard.kind], state.players[1], H)
Movement.reset(state, settler, S.units[settler.kind], state.players[1], H)
attach(state, guard, settler)
assert(guard.movesLeft == 6 and settler.movesLeft == 6)
assert(move(state, guard, 8, 4))
assert(
	guard.x == 8 and settler.x == 8 and guard.movesLeft == 0 and settler.movesLeft == 0,
	"Both embarked members receive sea allowance only at reset and spend all remaining movement landing"
)

local AI = dofile("/games/civcraft/ai.lua")
state, guard, settler = fixture()
guard.aiRole = { name = "settlerEscort", escortID = settler.id }
assert(AI.military(state, state.players[1], guard, S))
assert(Stack.partner(state, guard) == settler and guard.movesLeft == 4)
assert(
	not AI.military(state, state.players[1], guard, S) and guard.x == 3,
	"A linked AI guard follows its settler instead of taking a separate campaign move"
)
print(
	"CIVCRAFT: escort Pareto routes, control immunity, embarkation and assigned AI escorts passed."
)

state, guard, settler = fixture()
attach(state, guard, settler)
state.players[1].gold = -1
S.production(state, H)
for _, survivor in ipairs(state.units) do
	assert(
		not survivor.escortID or Stack.partner(state, survivor),
		"Bankruptcy cannot leave a dangling escort"
	)
end

local UI = dofile("/games/civcraft/ui.lua")
for _, graphics in ipairs({ false, true }) do
	state, guard, settler = fixture()
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 342, 342
			end
			return 57, 38
		end,
		setCursorPos = function() end,
		setTextColor = function() end,
		setBackgroundColor = function() end,
		write = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.drawPixels = function() end
		monitor.getPaletteColor = function()
			return 0, 0, 0
		end
		monitor.setPaletteColor = function() end
	end
	local ui = UI.new(monitor, function(action, request)
		request.action = action
		assert(A.apply(state, 1, request, S))
	end)
	local function press(label)
		for _ = 1, 40 do
			ui:draw(W.forPlayer(state, 1), 1, {})
			for _, button in ipairs(ui.r.buttons) do
				if button.label == label then
					button.fn()
					return
				end
			end
			for _, button in ipairs(ui.r.buttons) do
				if button.label == "NEXT" then
					button.fn()
				end
			end
		end
		error("Missing escort control: " .. label)
	end
	ui:draw(W.forPlayer(state, 1), 1, {})
	ui:focus("unit", guard)
	press("ATTACH ESCORT")
	assert(Stack.partner(state, guard) == settler)
	press("DETACH ESCORT")
	assert(not guard.escortID and not settler.escortID)
	ui:close()
end
print("CIVCRAFT: bankruptcy cleanup and actual compact text/graphics escort controls passed.")

local Zone = dofile("/games/civcraft/zone_control.lua")
state, guard, settler = fixture()
guard.x, settler.x = 2, 2
guard.movesLeft, settler.movesLeft = 8, 8
state.units[#state.units + 1] = { id = 3, owner = 2, kind = "warrior", x = 6, y = 4, movesLeft = 2 }
S.migrate(state)
W.reveal(state, H, S)
attach(state, guard, settler)
assert(choice(state, guard, 8, 4), "Unseen control cannot leak into an escort preview")
projection = W.forPlayer(state, 1)
assert(choice(projection, projection.units[1], 8, 4))
assert(move(state, guard, 8, 4))
assert(guard.x ~= 8 and guard.x == settler.x and guard.y == settler.y)
assert(Zone.locked(state, guard, S) and settler.movesLeft == 0 and guard.movesLeft > 0)
for _, event in ipairs(E.forPlayer(state, 1).entries) do
	if event.type == "move" then
		local last = event.paths[1][#event.paths[1]]
		assert(
			last.x == guard.x and last.y == guard.y,
			"Both replays end at the discovered control stop"
		)
	end
end
print("CIVCRAFT: escort fog previews and actual discovered control stops passed.")
