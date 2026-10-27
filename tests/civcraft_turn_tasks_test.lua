local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Actions = dofile("/games/civcraft/actions.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Tasks = dofile("/games/civcraft/turn_tasks.lua")
local UI = dofile("/games/civcraft/ui.lua")
local World = dofile("/games/civcraft/world.lua")
local function fixture()
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		nextId = 10,
		players = {
			{ id = 1, name = "ONE", civ = "iron", techs = {} },
			{ id = 2, name = "TWO", civ = "forge", techs = {} },
		},
		cities = {
			{
				id = 1,
				owner = 1,
				x = 3,
				y = 4,
				population = 2,
				jobs = {
					food = 1,
					wood = 1,
					science = 0,
				},
				buildings = {},
			},
		},
		units = {
			{ id = 2, owner = 1, x = 5, y = 4, kind = "warrior", movesLeft = 2 },
			{ id = 3, owner = 1, x = 4, y = 5, kind = "scout", movesLeft = 3, standby = true },
		},
		scheduler = Scheduler.new(),
		world = { width = 12, height = 10, tiles = {}, resources = {}, landmarks = {}, rails = {} },
	}
	for y = 1, 10 do
		for x = 1, 12 do
			state.world.tiles[World.key(x, y)] = "plains"
		end
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	return state
end
local state = fixture()
local unit = state.units[1]
assert(not Actions.apply(state, 2, { action = "skipTurn", x = 5, y = 4, unitID = 2 }, Systems))
assert(not Actions.apply(state, 1, { action = "skipTurn", x = 5, y = 4, unitID = 999 }, Systems))
assert(Actions.apply(state, 1, { action = "skipTurn", x = 5, y = 4, unitID = 2 }, Systems))
assert(
	unit.movesLeft == 2 and not unit.standby and not Tasks.idle(state, unit, 1),
	"Skip is temporary attention state, not sleep or spent movement"
)
local snapshot = World.forPlayer(state, 1)
assert(
	not Tasks.idle(snapshot, snapshot.units[1], 1),
	"A saved/projected skip retains its turn identity"
)
assert(not Actions.apply(state, 1, { action = "move", sx = 5, sy = 4, x = 12, y = 10 }, Systems))
assert(not Tasks.idle(state, unit, 1), "Rejected orders preserve Skip Turn")
assert(Actions.apply(state, 1, { action = "move", sx = 5, sy = 4, x = 6, y = 4 }, Systems))
assert(
	unit.skippedTurn == nil and Tasks.idle(state, unit, 1),
	"A new accepted order restores attention if moves remain"
)
assert(Actions.apply(state, 1, { action = "skipTurn", x = 6, y = 4 }, Systems))
state.round = 2
assert(Tasks.idle(state, unit, 1), "Skip expires next round without refreshing any movement")
state.round = 1
state.scheduler.reactions[1] = true
assert(Tasks.idle(state, unit, 1), "An ended defender's response is a fresh eligible turn window")
assert(Actions.apply(state, 1, { action = "skipTurn", x = 6, y = 4 }, Systems))
assert(not Tasks.idle(state, unit, 1))
state.players[1].ready = true
state.scheduler.reactions[1] = nil
assert(
	not Actions.apply(state, 1, { action = "skipTurn", x = 6, y = 4 }, Systems),
	"Ready cannot issue unit orders"
)

for _, graphics in ipairs({ false, true }) do
	state = fixture()
	local width, height = graphics and 57 or 51, graphics and 38 or 19
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return width * 6, height * 9
			end
			return width, height
		end,
		setCursorPos = function() end,
		setTextColor = function() end,
		setBackgroundColor = function() end,
		write = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.getPaletteColor = function()
			return 0, 0, 0
		end
		monitor.setPaletteColor = function() end
		monitor.drawPixels = function() end
	end
	local ends = 0
	local ui = UI.new(monitor, function(action, request)
		if action == "end" then
			ends = ends + 1
		else
			request.action = action
			assert(Actions.apply(state, 1, request, Systems))
		end
	end)
	local function draw()
		ui:draw(World.forPlayer(state, 1), 1, {})
	end
	local function click(label)
		for _, button in ipairs(ui.r.buttons) do
			if button.label == label then
				button.fn(button.x + button.w / 2, button.y + button.h / 2)
				return true
			end
		end
	end
	local function find(label)
		for _ = 1, 40 do
			draw()
			if click(label) then
				return true
			end
			click("NEXT")
		end
		error("Missing task control " .. label)
	end
	draw()
	assert(ui:turnAction() == "UNIT ORDERS")
	assert(click("UNIT ORDERS") and ui.selected.kind == "unit" and not ui.source)
	assert(find("SKIP TURN"))
	draw()
	assert(ui:turnAction() == "PRODUCTION" and ends == 0)
	assert(click("PRODUCTION") and ui.selected.kind == "city" and ui.cityPanel == "production")
	assert(find("NO PRODUCTION"))
	if ui.panel == "inspector" then
		ui:back()
	end
	draw()
	assert(
		ui:turnAction() == "RESEARCH" and ends == 0,
		"Explicit No Production satisfies the city reminder"
	)
	assert(click("RESEARCH") and ui.panel == "tech")
	ui:command("researchTech", { id = "agriculture" })
	ui.panel = "context"
	draw()
	assert(ui:turnAction() == "END TURN")
	local primary = 0
	for _, button in ipairs(ui.r.buttons) do
		if button.turnAction then
			primary = primary + 1
		end
		assert(button.label ~= "NEXT IDLE UNIT", "Only one primary turn control is displayed")
	end
	assert(primary == 1 and click("END TURN") and ends == 1 and not ui.endConfirm)
	ui:close()
end
print(
	"CIVCRAFT: unified unit/production/research/end workflow, Skip Turn validation, remaining budgets, snapshots and response windows passed."
)
