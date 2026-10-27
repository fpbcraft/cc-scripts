local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
colors = {
	black = 32768,
	white = 1,
	gray = 128,
	lightGray = 256,
	orange = 2,
	lightBlue = 8,
	yellow = 16,
	green = 8192,
	blue = 2048,
	lime = 32,
	red = 16384,
	brown = 4096,
}
local UI = dofile("games/civcraft/ui.lua")
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local S = dofile("games/civcraft/systems.lua")
local A = dofile("games/civcraft/actions.lua")
local W = dofile("games/civcraft/world.lua")
local H = dofile("games/civcraft/hex.lua")
for _, graphics in ipairs({ false, true }) do
	local world =
		{ width = 18, height = 12, tiles = {}, resources = {}, landmarks = {}, rails = {} }
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[W.key(x, y)] = "plains"
		end
	end
	local state = {
		ruleset = "create",
		phase = "game",
		round = 1,
		nextId = 5,
		world = world,
		players = {
			{ id = 1, name = "ONE", techs = {}, civ = "iron" },
			{ id = 2, name = "TWO", techs = {}, civ = "verdant" },
		},
		cities = {
			{ id = 1, owner = 1, x = 3, y = 4, population = 2, buildings = {} },
			{ id = 2, owner = 2, x = 15, y = 9, population = 2, buildings = {} },
		},
		units = {
			{ id = 3, owner = 1, kind = "warrior", x = 4, y = 4, movesLeft = 2, standby = true },
			{ id = 4, owner = 2, kind = "warrior", x = 5, y = 4, movesLeft = 2 },
		},
	}
	S.migrate(state)
	W.reveal(state, H, S)
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 342, 342
			end
			return 57, 38
		end,
		getPaletteColor = function()
			return 0, 0, 0
		end,
		setPaletteColor = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.drawPixels = function() end
	else
		monitor.setCursorPos = function() end
		monitor.setBackgroundColor = function() end
		monitor.setTextColor = function() end
		monitor.write = function() end
	end
	local ui = UI.new(monitor, function(action, params)
		params.action = action
		assert(A.apply(state, 1, params, S))
	end)
	local function draw()
		ui:draw(state, 1, { screen = "game" })
	end
	local function click(label)
		for _, b in ipairs(ui.r.buttons) do
			if b.label == label then
				b.fn()
				return true
			end
		end
	end
	local function find(label)
		for _ = 1, 50 do
			if click(label) then
				return true
			end
			ui.inspectorOffset = (ui.inspectorOffset or 0) + 1
			draw()
		end
	end
	local city = state.cities[1]
	assert(S.queue(state.players[1], city, "unit", "scout", state, H))
	city.project.progress = 3
	draw()
	ui:focus("city", city)
	ui.cityPanel = "production"
	draw()
	assert(find("NO PRODUCTION"))
	assert(ui.productionConfirm)
	draw()
	assert(click("CHANGE"))
	draw()
	assert(city.productionIdle and not city.project and city.projectProgress["unit:scout"] == 3)
	for _, warning in ipairs(ui:endWarnings()) do
		assert(warning.item ~= city, "Intentionally idle cities do not nag")
	end
	ui:focus("unit", state.units[1])
	draw()
	assert(find("MOVE / ATTACK"))
	assert(ui.source and #ui.reachable > 0, "Sleeping units can preview orders")
	ui:tile(5, 4)
	assert(ui.pendingMove and ui.pendingMove.forecast)
	local forecast = ui.pendingMove.forecast
	assert(state.units[1].standby, "Preview must not wake authoritative unit")
	draw()
	assert(click("CONFIRM"))
	assert(not state.units[1].standby and state.units[1].hp == forecast.attackerHP)
end
print(
	"CIVCRAFT: text/graphics No Production confirmation, quiet idle cities, sleeping orders and combat forecast passed."
)
