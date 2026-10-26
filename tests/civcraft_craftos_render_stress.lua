-- Dedicated native profile: exercise real text output and instrumented graphics.
local env =
	dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
env.dofile("/games/civcraft/module_cache.lua").install(env)
local World = env.dofile("/games/civcraft/world.lua")
local Hex = env.dofile("/games/civcraft/hex.lua")
local Systems = env.dofile("/games/civcraft/systems.lua")
local UI = env.dofile("/games/civcraft/ui.lua")
local Cooperative = env.dofile("/games/civcraft/cooperative.lua")
local work = {}
local function checkpoint()
	Cooperative.checkpoint(work, false, true)
end
World.checkpoint, Systems.checkpoint = checkpoint, checkpoint
local world = World.generate(238711, "standard", 2, "continents")
local point = world.starts[1]
local player = { id = 0, name = "RENDER BENCHMARK", civ = "iron", techs = {}, gold = 50 }
local state = {
	version = 6,
	ruleset = "create",
	phase = "game",
	round = 1,
	world = world,
	players = { player },
	cities = { { id = 1, owner = 0, x = point.x, y = point.y, population = 2, buildings = {} } },
	units = {},
}
Systems.migrate(state)
World.reveal(state, Hex, Systems)
for key in pairs(world.tiles) do
	player.visible[key], player.explored[key] = true, true
end
local report = { host = _G._HOST, layouts = {} }
for _, backend in ipairs({ "text", "graphics" }) do
	local monitor = term
	if backend == "graphics" then
		monitor = {
			getSize = function(mode)
				if mode == 2 then
					return 474, 468
				end
				return 79, 52
			end,
			getPaletteColor = function()
				return 0, 0, 0
			end,
			setPaletteColor = function() end,
			setGraphicsMode = function() end,
			drawPixels = function() end,
		}
	end
	local ui = UI.new(monitor, function()
		error("Rendering must not issue gameplay orders")
	end)
	local durations, started = {}, os.epoch("utc")
	for frame = 1, 500 do
		local tick = os.epoch("utc")
		ui.panel = "context"
		if ui.mapViewport then
			ui:pan(frame % 2 == 0 and 9 or -7, frame % 3 == 0 and 5 or -3)
			if frame % 5 == 0 then
				ui:zoom(frame % 20 < 10 and 1 or -1)
			end
		end
		if frame % 11 == 0 then
			ui.panel = "report"
		end
		if frame % 17 == 0 then
			ui.panel = "council"
		end
		ui:draw(World.forPlayer(state, 0), 0, { screen = "game" })
		durations[#durations + 1] = os.epoch("utc") - tick
	end
	table.sort(durations)
	report.layouts[#report.layouts + 1] = {
		backend = backend,
		frames = #durations,
		median = durations[math.ceil(#durations / 2)],
		maximum = durations[#durations],
		elapsed = os.epoch("utc") - started,
		gcCycles = ui.r.gcCycles or 0,
		gcMaxMillis = ui.r.gcMaxMillis or 0,
	}
	ui:close()
end
report.checkpointCollections, report.gcMaxMillis = work.gcCycles or 0, work.gcMaxMillis or 0
local file = assert(fs.open("/civcraft-render-stress.txt", "w"))
file.write(textutils.serialize(report))
file.close()
print("CIVCRAFT: 1,000 native-runtime pan/zoom/report/Council frames completed.")
