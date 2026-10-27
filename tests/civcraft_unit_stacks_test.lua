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
local UI = dofile("/games/civcraft/ui.lua")
local Tactics = dofile("/games/civcraft/ai_tactics.lua")
local W = dofile("/games/civcraft/world.lua")
local function fixture(kind)
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		nextId = 10,
		players = {
			{ id = 1, name = "ONE", civ = "iron", techs = {} },
			{ id = 2, name = "TWO", civ = "forge", techs = {} },
		},
		cities = {},
		units = {
			{ id = 1, owner = 1, kind = kind or "warrior", x = 3, y = 4, movesLeft = 3 },
			{ id = 2, owner = 2, kind = "settler", x = 4, y = 4, movesLeft = 3 },
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
local function attack(state, unit)
	for _, point in ipairs(H.reachable(state, unit, unit.owner, S)) do
		if point.x == 4 and point.y == 4 and point.attack then
			return point
		end
	end
end
local state, unit, settler = fixture()
settler.hp = 7
settler.aiSettlement = { x = 11, y = 9, purpose = "PRIVATE OLD OWNER PLAN" }
local ranked = Tactics.ranked(W.forPlayer(state, 1), state.players[1], unit, S)
assert(
	ranked[1].forecast
		and ranked[1].forecast.capturedSettler
		and ranked[1].request.unitID == unit.id,
	"AI ranks a legal free capture and retains the acting unit's identity"
)
local prediction = assert(C.predictOrder(state, unit, assert(attack(state, unit)), S))
assert(
	prediction.captureOnly
		and prediction.capturedSettler
		and prediction.damage == 0
		and prediction.retaliation == 0
)
assert(A.apply(state, 1, { action = "move", unitID = 1, sx = 3, sy = 4, x = 4, y = 4 }, S))
assert(
	#state.units == 2
		and settler.owner == 1
		and settler.id == 2
		and settler.hp == 7
		and settler.movesLeft == 0
)
assert(
	settler.aiSettlement == nil and settler.aiRole == nil,
	"Capture clears the previous owner's private plans"
)
assert(unit.x == 4 and unit.hp == 100 and Stack.at(state.units, 4, 4) == unit)
local event
for _, entry in ipairs(E.forPlayer(state, 2).entries) do
	if entry.type == "combat" then
		event = entry
	end
end
assert(
	event and event.result.capturedSettler,
	"The former owner observes the capture without a fabricated death"
)
assert(not A.apply(state, 2, { action = "move", unitID = 2, sx = 4, sy = 4, x = 5, y = 4 }, S))
assert(
	not A.apply(state, 1, { action = "move", unitID = 2, sx = 4, sy = 4, x = 5, y = 4 }, S),
	"Captured settlers gain no fresh movement"
)
state, unit, settler = fixture("archer")
prediction = assert(C.predictOrder(state, unit, assert(attack(state, unit)), S))
assert(prediction.ranged and not prediction.capturedSettler and prediction.damage > 0)
assert(A.apply(state, 1, { action = "move", unitID = 1, sx = 3, sy = 4, x = 4, y = 4 }, S))
assert(
	settler.owner == 2 and settler.hp < 100 and unit.x == 3,
	"Ranged attacks damage instead of capturing settlers"
)

for _, kind in ipairs({ "warrior", "archer" }) do
	state, unit, settler = fixture(kind)
	local guard = { id = 3, owner = 2, kind = "warrior", x = 4, y = 4, movesLeft = 2, hp = 1 }
	state.units = { settler, unit, guard }
	S.migrate(state)
	W.reveal(state, H, S)
	assert(
		Stack.at(state.units, 4, 4) == guard,
		"The protector is selected independently of array order"
	)
	prediction = assert(C.predictOrder(state, unit, assert(attack(state, unit)), S))
	assert(prediction.defenderDied and prediction.capturedSettler == (kind == "warrior"))
	assert(A.apply(state, 1, { action = "move", unitID = 1, sx = 3, sy = 4, x = 4, y = 4 }, S))
	assert(#state.units == 2 and settler.owner == (kind == "warrior" and 1 or 2))
end
state, unit, settler = fixture()
state.cities = { { id = 4, owner = 2, x = 4, y = 4, hp = 1, population = 2, buildings = {} } }
S.migrate(state)
W.reveal(state, H, S)
assert(A.apply(state, 1, { action = "move", unitID = 1, sx = 3, sy = 4, x = 4, y = 4 }, S))
assert(
	state.cities[1].owner == 1 and settler.owner == 1 and #state.units == 2,
	"Coastal/city capture retains and transfers a protected settler"
)

for _, graphics in ipairs({ false, true }) do
	state, unit, settler = fixture()
	settler.owner = 1
	assert(A.apply(state, 1, { action = "move", unitID = 1, sx = 3, sy = 4, x = 4, y = 4 }, S))
	assert(Stack.canEnter(state, { id = 8, owner = 1, kind = "warrior" }, 4, 4) == false)
	assert(
		Stack.canEnter(state, { id = 9, owner = 1, kind = "settler" }, 4, 4) == false,
		"No double military/civilian stacking"
	)
	settler.movesLeft, settler.moved = 3, false
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
	local function draw()
		ui:draw(W.forPlayer(state, 1), 1, {})
	end
	local function find(label)
		for _ = 1, 40 do
			draw()
			for _, button in ipairs(ui.r.buttons) do
				if button.label == label then
					button.fn(button.x + button.w / 2, button.y + button.h / 2)
					return
				end
			end
			for _, button in ipairs(ui.r.buttons) do
				if button.label == "NEXT" then
					button.fn()
				end
			end
		end
		error("Missing shared-tile control: " .. label)
	end
	draw()
	ui:focus("unit", unit)
	find("SELECT SETTLER")
	assert(ui.selected.unitID == 2)
	find("MOVE / ATTACK")
	ui:tile(5, 4)
	assert(ui.pendingMove and ui.pendingMove.unitID == 2)
	assert(ui:confirmMove())
	assert(
		settler.x == 5 and unit.x == 4,
		"Unit identity selects the settler, rather than moving its guard"
	)
	ui:close()
end
print(
	"CIVCRAFT: melee settler capture, ranged damage, protector priority, city capture, stack limits, private events and explicit shared-tile selection passed."
)
