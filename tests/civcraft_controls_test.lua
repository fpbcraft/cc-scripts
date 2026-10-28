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
local World = dofile("games/civcraft/world.lua")
local Systems = dofile("games/civcraft/systems.lua")
local Reports = dofile("games/civcraft/reports.lua")
local Hex = dofile("games/civcraft/hex.lua")
local world = World.generate(75123, "standard", 2, "continents")
local a, b = world.starts[1], world.starts[2]
local state = {
	phase = "game",
	round = 1,
	world = world,
	nextId = 4,
	players = {
		{ id = 1, name = "ONE", techs = {}, civ = "verdant" },
		{ id = 2, name = "TWO", techs = {}, civ = "iron" },
	},
	cities = {
		{
			owner = 1,
			x = a.x,
			y = a.y,
			population = 2,
			jobs = { food = 1, wood = 1, science = 0 },
			buildings = {},
		},
		{
			owner = 2,
			x = b.x,
			y = b.y,
			population = 2,
			jobs = { food = 1, wood = 1, science = 0 },
			buildings = {},
		},
	},
	units = {
		{ id = 1, owner = 1, x = a.x + 1, y = a.y, kind = "warrior", movesLeft = 2 },
		{ id = 2, owner = 2, x = b.x, y = b.y, kind = "scout", movesLeft = 3 },
	},
}
Systems.migrate(state)
World.reveal(state, Hex, Systems)
local function monitor(w, h, graphics)
	local m = {}
	function m.getSize(mode)
		if mode == 2 then
			return w * 6, h * 9
		end
		return w, h
	end
	function m.getPaletteColor()
		return 0, 0, 0
	end
	function m.setPaletteColor() end
	if graphics then
		function m.setGraphicsMode() end
		function m.drawPixels(x, y, c, bw, bh)
			assert(x >= 0 and y >= 0 and x + bw <= w * 6 and y + bh <= h * 9, "Pixel overflow")
		end
	else
		function m.setCursorPos(x, y)
			assert(x >= 1 and x <= w and y >= 1 and y <= h, "Text cursor overflow")
		end
		function m.setBackgroundColor() end
		function m.setTextColor() end
		function m.write() end
	end
	return m
end
for _, y in ipairs({ 2, 3 }) do
	local size = 24
	local x = 3
	local function vertices(tx, ty)
		return Hex.vertices((tx - 1 + (ty - 1) % 2 * 0.5) * size, (ty - 1) * size * 0.75, size)
	end
	local own = vertices(x, y)
	for side, n in ipairs(Hex.edgeNeighbours(x, y)) do
		local other = vertices(n.x, n.y)
		local matches = 0
		for _, v in ipairs({ own[side], own[side % 6 + 1] }) do
			for _, o in ipairs(other) do
				if v.x == o.x and v.y == o.y then
					matches = matches + 1
				end
			end
		end
		assert(matches == 2, "Territory side must share both endpoints with its neighbour")
	end
end
-- CI distributes the 18 monitor/mode combinations across independent workers.
-- Without these variables, running this file locally still checks every layout.
local shardValue = os.getenv("CIVCRAFT_CONTROLS_SHARD")
local shardCountValue = os.getenv("CIVCRAFT_CONTROLS_SHARDS")
local shard = tonumber(shardValue)
local shardCount = tonumber(shardCountValue)
local validShard = shard
	and shardCount
	and shard >= 0
	and shard < shardCount
	and shard % 1 == 0
	and shardCount % 1 == 0
assert((not shardValue and not shardCountValue) or validShard, "Invalid controls layout shard")
local layoutIndex = 0
local function heightsForShard()
	local heights = {}
	for _, height in ipairs({ 38, 52, 67 }) do
		if not shard or layoutIndex % shardCount == shard then
			heights[#heights + 1] = height
		end
		layoutIndex = layoutIndex + 1
	end
	return heights
end
local checks = 0
local started = os.clock()
for _, graphics in ipairs({ false, true }) do
	for _, cw in ipairs({ 57, 79, 100 }) do
		for _, ch in ipairs(heightsForShard()) do
			local calls = {}
			-- This suite validates hit targets and actions across all 18 layouts.
			-- Full-frame raster verification belongs to the renderer/backend
			-- regressions; redrawing full pixel buffers at every UI step is prohibitively
			-- expensive under the reference Lua 5.3 interpreter.
			local layoutOnly = true
			local ui = UI.new(monitor(cw, ch, graphics), function(action, args)
				calls[#calls + 1] = { action, args }
			end, { layoutOnly = layoutOnly })
			local function draw(opts)
				ui:draw(state, 1, opts or {})
			end
			local function click(label)
				for _, button in ipairs(ui.r.buttons) do
					if button.label == label then
						button.fn(button.x + button.w / 2, button.y + button.h / 2)
						return true
					end
				end
			end
			local function bounds()
				for i, button in ipairs(ui.r.buttons) do
					assert(
						button.x >= 0
							and button.y >= 0
							and button.x + button.w <= ui.r.w
							and button.y + button.h <= ui.r.h,
						"Control outside screen: " .. tostring(button.label)
					)
					for j = 1, i - 1 do
						local other = ui.r.buttons[j]
						assert(
							button.x >= other.x + other.w
								or other.x >= button.x + button.w
								or button.y >= other.y + other.h
								or other.y >= button.y + button.h,
							"Overlapping controls: "
								.. tostring(button.label)
								.. " / "
								.. tostring(other.label)
						)
					end
				end
			end
			draw()
			bounds()
			assert(
				ui.inspectorBounds and ui.mapViewport.w >= 16,
				"Usable map and persistent inspector"
			)
			ui:turnProgress("AI TAKING ITS TURN", "TWO")
			assert(
				#ui.r.buttons == 0 and not ui.mapViewport and #ui.hexTargets == 0,
				"Waiting screen hides gameplay controls and map targets"
			)
			draw()
			bounds()
			assert(ui.mapViewport, "Normal gameplay returns after processing")
			assert(not click("INSPECT"), "Inspector shortcut is removed")
			local icons = {}
			for _, button in ipairs(ui.r.buttons) do
				icons[button.label] = button.icon
			end
			assert(icons.EMPIRE == "station", "Empire uses the original city symbol")
			assert(not icons["NEXT IDLE CITY"], "There is no separate idle-city button")
			assert(
				icons["WORLD OVERVIEW"] == "fullscreen",
				"World overview uses a fullscreen symbol"
			)
			for _, button in ipairs(ui.r.buttons) do
				if
					button.label == "ZOOM IN"
					or button.label == "ZOOM OUT"
					or button.label == "WORLD OVERVIEW"
				then
					assert(
						button.x < 30 and button.y > 30 and button.y < ui.r.h - 15,
						"Zoom and overview stay in the left sidebar"
					)
				end
				assert(button.label ~= "MINIMAP", "There is no always-visible minimap")
				if button.label == "END TURN" then
					assert(
						button.x + button.w == ui.r.w - 2 and button.w >= 30,
						"End turn is a labeled button aligned right"
					)
				end
			end
			assert(not next(ui.overlays), "Default view has no optional overlays")
			assert(click("RESOURCES"))
			draw()
			assert(ui.overlays.resources)
			assert(click("YIELDS"))
			draw()
			assert(ui.overlays.yields and ui.overlays.resources and ui.mapViewport.tile == 40)
			assert(click("RESOURCES"))
			draw()
			assert(not ui.overlays.resources and ui.overlays.yields)
			assert(click("TERRAIN"))
			draw()
			assert(not next(ui.overlays))
			assert(click("MAP RIGHT EDGE"))
			draw()
			bounds()
			local v = ui.mapViewport
			ui.panX = math.min(50, v.maxX)
			ui.panY = math.min(50, v.maxY)
			local function pointer(x, y)
				if not graphics then
					return x / 2 + 1, y / 3 + 1
				end
				return ui.r.ox + x * ui.r.sx, ui.r.oy + y * ui.r.sy
			end
			local x, y = pointer(v.x + v.w / 2, v.y + v.h / 2)
			assert(ui:drag(x, y))
			local oldX = ui.panX
			assert(ui:drag(x - 5 * ui.r.sx, y))
			assert(ui.panX >= oldX, "Dragging pans the map")
			ui.lastDrag = nil
			ui.source = { x = a.x + 1, y = a.y }
			ui.reachable = Hex.reachable(state, state.units[1], 1, Systems)
			local selection = ui.selected
			local commands = #calls
			ui.panX = math.min(40, v.maxX)
			assert(ui:pointerDown(x, y))
			local anchor = ui.panX
			assert(ui:drag(x - 5 * ui.r.sx, y))
			ui:pointerUp()
			assert(
				ui.panX > anchor
					and ui.selected == selection
					and not ui.pendingMove
					and #calls == commands,
				"Single drag event pans without selecting or ordering a unit"
			)
			ui.source = nil
			ui.reachable = {}
			ui:zoom(-1)
			draw()
			local old = ui.mapViewport.tile
			assert(click("ZOOM IN"))
			draw()
			assert(ui.mapViewport.tile == old + 4)
			for _ = 1, 10 do
				ui:zoom(-1)
				draw()
				bounds()
			end
			assert(ui.mapViewport.tile == 8)
			for _ = 1, 10 do
				ui:zoom(1)
				draw()
				bounds()
			end
			assert(ui.mapViewport.tile == 48)
			ui.selected = { x = a.x + 1, y = a.y }
			draw()
			assert(not ui.source)
			ui:tile(a.x + 1, a.y)
			assert(ui.selected.empty, "Clicking selected unit deselects")
			ui:tile(a.x + 1, a.y)
			draw()
			local slept = false
			for _ = 1, 15 do
				if click("SLEEP UNIT") then
					slept = true
					break
				end
				click("NEXT")
				draw()
				bounds()
			end
			assert(slept)
			assert(calls[#calls][1] == "standby")
			state.units[1].standby = true
			assert(
				#ui:endWarnings() == 2,
				"Sleep excludes unit but production and research need attention"
			)
			state.units[1].standby = nil
			ui.selected = { x = a.x, y = a.y }
			ui.inspectorOffset = 0
			draw()
			assert(click("PROD"))
			draw()
			local queued = false
			for _ = 1, 15 do
				for _, button in ipairs(ui.r.buttons) do
					if button.label and button.label:match("^[A-Z]+ %d+T$") then
						button.fn()
						queued = true
						break
					end
				end
				if queued then
					break
				end
				click("NEXT")
				draw()
				bounds()
			end
			assert(
				queued and calls[#calls][1] == "queue",
				"Production reachable through paged inspector"
			)
			local projectID = calls[#calls][2].id
			assert(click("CODEX " .. projectID))
			draw()
			bounds()
			assert(
				ui.codex.entry.id == projectID,
				"Project book opens its corresponding Codex entry"
			)
			assert(click("CLOSE"))
			draw()
			state.cities[1].project = { kind = "unit", id = "warrior", progress = 3 }
			local previousCalls = #calls
			ui:command("queue", { cityX = a.x, cityY = a.y, kind = "unit", id = "scout" })
			assert(
				ui.productionConfirm and #calls == previousCalls,
				"Changing production requires confirmation"
			)
			draw()
			bounds()
			assert(click("KEEP CURRENT"))
			assert(state.cities[1].project.id == "warrior")
			ui:command("queue", { cityX = a.x, cityY = a.y, kind = "unit", id = "scout" })
			draw()
			assert(click("CHANGE"))
			assert(
				calls[#calls][1] == "queue" and calls[#calls][2].confirmed,
				"Only confirmed switching sends a project order"
			)
			state.cities[1].project = nil
			assert(
				ui:nextIdleCity() and ui.selected.kind == "city" and ui.cityPanel == "production"
			)
			state.cities[1].project = { kind = "unit", id = "warrior", progress = 0 }
			assert(not ui:nextIdleCity())
			state.cities[1].project = nil
			ui:focus("unit", state.units[1])
			ui.source = { x = state.units[1].x, y = state.units[1].y }
			ui.reachable = Hex.reachable(state, state.units[1], 1, Systems)
			local destination = ui.reachable[1]
			assert(destination.path and #destination.path >= 2)
			ui:tile(destination.x, destination.y)
			assert(ui.pendingMove and ui.pendingMove.path)
			ui:tile(destination.x, destination.y)
			assert(
				not ui.pendingMove and calls[#calls][1] == "move",
				"Clicking the preview tile again confirms its route"
			)
			ui:focus("city", state.cities[1])
			draw()
			for _, button in ipairs(ui.r.buttons) do
				if button.label == "TERRAIN" or button.label == "YIELDS" then
					assert(
						button.w == button.h and button.w == 12,
						"Navigation controls stay square at every size"
					)
				end
			end
			assert(click("EMPIRE"))
			draw()
			bounds()
			assert(click("CITIES"))
			draw()
			bounds()
			local chosen = false
			for _, button in ipairs(ui.r.buttons) do
				if button.label and button.label:find(state.cities[1].name, 1, true) == 1 then
					button.fn()
					chosen = true
					break
				end
			end
			assert(
				chosen and ui.panel == "context" and ui.selected.kind == "city",
				"Empire menu focuses owned cities"
			)
			draw()
			assert(click("UNIT ORDERS"))
			draw()
			assert(
				ui.selected.kind == "unit" and not ui.source,
				"Next idle selects without arming orders"
			)
			state.units[1].standby = true
			assert(not ui:nextIdle(), "Sleeping units are skipped")
			state.units[1].standby = nil
			state.units[1].movesLeft = 0
			assert(not ui:nextIdle(), "Spent units are skipped")
			state.units[1].movesLeft = 2
			local oldX, oldY = state.units[1].x, state.units[1].y
			state.units[1].x, state.units[1].y = a.x, a.y
			ui:deselect()
			ui:tile(a.x, a.y)
			draw()
			bounds()
			assert(
				ui.selected.kind == "unit" and click("CITY"),
				"Stacked units and cities have an explicit chooser"
			)
			draw()
			bounds()
			assert(ui.selected.kind == "city" and click("UNIT"))
			draw()
			bounds()
			assert(ui.selected.kind == "unit", "Produced units on city tiles remain selectable")
			state.units[1].x, state.units[1].y = oldX, oldY
			ui:focus("city", state.cities[1])
			draw()
			for _, button in ipairs(ui.r.buttons) do
				if
					button.label == "CODEX"
					or button.label == "REPORT"
					or button.label == "PAUSE"
					or button.label == "EMPIRE"
				then
					assert(
						button.icon and button.y < 24,
						"Secondary actions are icons in the top bar"
					)
				elseif button.turnAction then
					assert(
						button.icon and button.y >= ui.r.h - 15,
						"Primary actions use a compact icon footer"
					)
				end
			end
			local research, turnButton
			for _, button in ipairs(ui.r.buttons) do
				if button.label == "TECH TREE" then
					research = button
				end
				if button.turnAction then
					assert(not turnButton)
					turnButton = button
				end
				assert(button.label ~= "NEXT IDLE UNIT")
			end
			assert(research and research.y < 14, "Research belongs in the top bar")
			assert(
				turnButton and turnButton.x + turnButton.w == ui.r.w - 2,
				"A single primary turn action fills the inspector footer"
			)
			assert(
				ui.statusBounds.y >= ui.mapViewport.y + ui.mapViewport.h
					and ui.statusBounds.x + ui.statusBounds.w <= turnButton.x,
				"Status feedback occupies the strip below the map, beside the inspector footer"
			)

			assert(click("FACTIONS"))
			draw()
			bounds()
			assert(ui.panel == "factions" and click("CLOSE"), "Faction details open and close")
			ui.panel = "tech"
			draw()
			bounds()
			local px, py = ui.panX, ui.panY
			assert(not ui:pan(10, 10))
			assert(ui.panX == px and ui.panY == py)
			ui.panel = "encyclopedia"
			draw()
			bounds()
			ui.panel = "context"
			ui:command("end")
			assert(ui.endConfirm)
			draw()
			bounds()
			assert(click("GO TO UNIT"))
			assert(
				not ui.endConfirm and ui.selected.kind == "unit",
				"Reminders provide direct navigation"
			)
			ui:command("end")
			draw()
			assert(click("GO BACK"))
			ui:command("end")
			draw()
			assert(click("END ANYWAY"))
			assert(calls[#calls][1] == "end")
			ui.panel = "context"
			ui.panX = 999
			ui.panY = 999
			ui.source = { x = a.x + 1, y = a.y }
			ui:draw(state, 2, { handoff = true })
			assert(
				not ui.source and ui.panX == 0 and ui.panY == 0,
				"Handoff clears outgoing camera and orders"
			)
			assert(not ui.mapViewport, "Handoff conceals map")
			ui:draw(state, 2, {})
			assert(
				ui.selected.x == b.x and ui.selected.y == b.y,
				"Incoming camera focuses own city"
			)
			draw({ report = true })
			assert(ui.panel == "report")
			bounds()
			assert(ui.modalBounds.w < ui.r.w and ui.modalBounds.h < ui.r.h, "Report is a dialog")
			assert(not ui:pan(12, 12), "Dialog blocks map panning")
			assert(click("CLOSE"))
			draw({ report = true })
			assert(ui.panel == "context", "Report only opens once per turn")
			local originalWorld = state.world
			local replacement = {}
			for k, value in pairs(originalWorld) do
				replacement[k] = value
			end
			state.world = replacement
			local savedPan = ui.panX
			draw({ report = true })
			assert(
				ui.panel == "context" and ui.panX == savedPan,
				"Network snapshots preserve camera and report dismissal"
			)
			state.world = originalWorld
			state.round = 2
			draw({ report = true })
			assert(ui.panel == "report")
			state.round = 1
			for _, opts in ipairs({
				{ screen = "title", slots = { { occupied = true }, {}, {} } },
				{ paused = true },
				{
					handoff = true,
				},
			}) do
				draw(opts)
				bounds()
			end
			ui:close()
			checks = checks + 1
			print(
				string.format(
					"CIVCRAFT controls: %s %dx%d completed in %.2fs",
					graphics and "graphics" or "text",
					cw,
					ch,
					os.clock() - started
				)
			)
		end
	end
end
assert(checks == (validShard and 2 or 18), "Every assigned monitor layout must be covered")
local before = Reports.capture(state, state.players[1])
state.players[1].techs.mining = true
state.cities[1].buildings.farm = true
state.cities[1].population = 3
state.units[1] = state.units[2]
state.units[2] = nil
local lines = table.concat(Reports.build(state, state.players[1], before), "|")
assert(
	lines:find("STONE TOOLS")
		and lines:find("completed WHEAT FARM")
		and lines:find("population 2 %-> 3")
		and lines:find("Unit lost: STONE GUARD")
)
assert(not lines:find("scout"), "Report must not leak enemy units")
local city = state.cities[1]
city.worked = {}
Systems.ensureWorkers(state, city)
local tile = Systems.workable(state, city)[1]
local job = Systems.tileJob(tile)
assert(Systems.workTile(state, city, tile.x, tile.y))
assert(city.jobs[job] == 1)
assert(Systems.assign(city, job, "idle", state))
assert(not city.worked[tile.key] and city.jobs[job] == 0)
assert(Systems.assign(city, "idle", job, state))
assert(city.jobs[job] == 1)
print(
	"CIVCRAFT: "
		.. checks
		.. " monitor/mode layouts, zoom, modal isolation, production, sleep, handoff and reports passed."
)
