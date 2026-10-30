-- Dedicated isolated CraftOS profile: slot 1 is overwritten with controlled late-game data.
local arguments = { ... }
local backend = arguments[1] or "text"
local profileFirstFrame = false
for _, argument in ipairs(arguments) do
	profileFirstFrame = profileFirstFrame or argument == "--profile-first-frame"
end
assert(backend == "text" or backend == "gui" or backend == "monitor", "Unknown backend")
if backend == "monitor" then
	assert(_G.periphemu.create("top", "monitor"), "Create a monitor in a fresh CraftOS profile")
end

local loader = dofile("/games/civcraft/_lib/fpb/loader.lua")
local env = loader.environment("/games/civcraft", _ENV, "game.lua")
env.dofile("/games/civcraft/module_cache.lua").install(env)
local function module(name)
	return env.dofile("/games/civcraft/" .. name .. ".lua")
end

local Cooperative = module("cooperative")
local Hex = module("hex")
local Match = module("match_lifecycle")
local Saves = module("saves")
local Presentation = module("presentation")
local Systems = module("systems")
local UI = module("ui")
local World = module("world")
local work = {}
local function checkpoint()
	Cooperative.checkpoint(work, false, true)
end
World.checkpoint, Systems.checkpoint, Saves.checkpoint = checkpoint, checkpoint, checkpoint

local profiles = {
	{ name = "founders-v4", contentRules = "balance4", seedOffset = 0 },
	{ name = "specialization-v5", contentRules = "balance5", seedOffset = 1009 },
}
local sizes = { "huge", "vast" }
local report = {
	backend = backend,
	host = _G._HOST,
	profileOnly = profileFirstFrame,
	profileMode = profileFirstFrame and "first-frame" or nil,
	scenarios = {},
	fixture = { rounds = 100, cities = 40, units = 200, players = 4, mapType = "continents" },
}
local maximum = { name = "none", elapsedMillis = 0 }
local function progress(stage)
	local file = assert(fs.open("/founders-stress-progress.log", "a"))
	file.writeLine(tostring(os.epoch("utc")) .. " " .. stage)
	file.close()
end

local function persistPartial(stage)
	report.progressStage = stage
	local file = assert(fs.open("/civcraft-founders-stress-partial.json", "w"))
	file.write(textutils.serializeJSON(report))
	file.close()
end

local function measured(operations, name, fn)
	progress("begin " .. name)
	local started = os.epoch("utc")
	local result = table.pack(fn())
	local elapsed = os.epoch("utc") - started
	operations[#operations + 1] = { name = name, elapsedMillis = elapsed }
	if elapsed > maximum.elapsedMillis then
		maximum = { name = name, elapsedMillis = elapsed }
	end
	progress("end " .. name .. " elapsed=" .. elapsed)
	return table.unpack(result, 1, result.n)
end

local function newState(profile, size, scenarioIndex)
	local state = Match.newLobby(
		"native-founders-stress-" .. profile.name .. "-" .. size,
		profile.contentRules
	)
	state.mapSize = size
	state.mapType = "continents"
	state.mapSeed = 82471 + profile.seedOffset + scenarioIndex * 97
	state.mapWrapX = profile.contentRules == "balance5"
	state.hostileMode = "off"
	for index = 1, 4 do
		state.players[index] = {
			id = index - 1,
			name = "STRESS " .. index,
			civ = Systems.civs[index].id,
			techs = {},
			gold = 120,
			ai = false,
			ready = false,
		}
	end
	Match.initialize(state)
	state.round = 100
	state.cities = {}
	state.units = {}
	state.spawners = {}
	state.nextId = 1
	for _, player in ipairs(state.players) do
		player.capitalFounded = true
		player.settlersTrained = 12
	end

	local width, height = state.world.width, state.world.height
	local total = width * height
	local usedCities = {}
	local function cityPosition(index)
		if index <= #state.players then
			local start = state.world.starts[index]
			return start.x, start.y
		end
		local cell = (index * 257 + 43) % total
		for _ = 1, total do
			local x, y = cell % width + 1, math.floor(cell / width) + 1
			local key = World.key(x, y)
			if not usedCities[key] then
				return x, y
			end
			cell = (cell + 1) % total
		end
		error("No distinct city fixture coordinate remains")
	end
	for index = 1, 40 do
		local x, y = cityPosition(index)
		usedCities[World.key(x, y)] = true
		local ownerIndex = (index - 1) % #state.players + 1
		local owner = state.players[ownerIndex]
		state.cities[index] = {
			id = state.nextId,
			name = "STRESS CITY " .. index,
			owner = owner.id,
			capitalOf = index <= #state.players and owner.id or nil,
			x = x,
			y = y,
			population = 8 + index % 5,
			foodStore = 40,
			buildings = {},
			jobs = { food = 1, wood = 1, science = 1 },
		}
		state.nextId = state.nextId + 1
	end
	local usedUnits = {}
	for index = 1, 200 do
		local x, y
		if index <= #state.players then
			local start = state.world.starts[index]
			x, y = start.x, start.y
		else
			local cell = (index * 173 + 101) % total
			for _ = 1, total do
				local key = World.key(cell % width + 1, math.floor(cell / width) + 1)
				if not usedUnits[key] then
					x, y = cell % width + 1, math.floor(cell / width) + 1
					usedUnits[key] = true
					break
				end
				cell = (cell + 1) % total
			end
		end
		local kinds = { "warrior", "scout", "builder", "settler" }
		state.units[index] = {
			id = state.nextId,
			owner = state.players[(index - 1) % #state.players + 1].id,
			kind = kinds[(index - 1) % #kinds + 1],
			x = x,
			y = y,
			movesLeft = 0,
			moved = true,
		}
		state.nextId = state.nextId + 1
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	local observer = state.players[1]
	for y = 1, height do
		checkpoint()
		for x = 1, width do
			local key = World.key(x, y)
			observer.visible[key], observer.explored[key] = true, true
		end
	end
	-- This controlled R100 state has no retained opening playback.
	state.eventJournal = nil
	return state
end

local function displayFor(mode)
	if mode == "monitor" then
		local display = assert(peripheral.wrap("top"))
		display.setTextScale(0.5)
		return display
	end
	local display = term.current()
	if mode == "text" and display.setGraphicsMode and display.drawPixels then
		return setmetatable({}, {
			__index = function(_, key)
				if key == "setGraphicsMode" or key == "drawPixels" then
					return nil
				end
				return display[key]
			end,
		})
	end
	return display
end

local function screenPoint(renderer, x, y)
	if renderer.mode == "graphics" then
		return math.floor(renderer.ox + x * renderer.sx), math.floor(renderer.oy + y * renderer.sy)
	end
	return math.floor(x / 2 + 1), math.floor(y / 3 + 1)
end

local function unobstructedNativeMapPoint(ui)
	local viewport = assert(ui.mapViewport)
	for _, target in ipairs(ui.hexTargets or {}) do
		local x, y = target.x + target.w / 2, target.y + target.h / 2
		local sx, sy = screenPoint(ui.r, x, y)
		local rx, ry = ui.r:touch(sx, sy)
		local inside = rx
			and ry
			and rx >= viewport.x
			and rx < viewport.x + viewport.w
			and ry >= viewport.y
			and ry < viewport.y + viewport.h
			and Hex.contains(target.x, target.y, target.w, rx, ry)
		if inside then
			for _, button in ipairs(ui.r.buttons or {}) do
				if
					rx >= button.x
					and rx < button.x + button.w
					and ry >= button.y
					and ry < button.y + button.h
				then
					inside = false
					break
				end
			end
		end
		for _, targets in ipairs({
			ui.cityBannerTargets or {},
			ui.unitBadgeTargets or {},
			ui.unitIconTargets or {},
		}) do
			for _, obstruction in ipairs(targets) do
				if
					rx >= obstruction.x
					and rx < obstruction.x + obstruction.w
					and ry >= obstruction.y
					and ry < obstruction.y + obstruction.h
				then
					inside = false
					break
				end
			end
			if not inside then
				break
			end
		end
		if inside then
			return sx, sy, rx, ry
		end
	end
	error("Native map viewport has no unobstructed input cell for drag staging")
end

local function queuedEvent(name, ...)
	os.queueEvent(name, ...)
	local event = table.pack(os.pullEvent(name))
	assert(event[1] == name, "Native input event was not received: " .. name)
	return table.unpack(event, 1, event.n)
end

local function tap(ui, x, y)
	local sx, sy = screenPoint(ui.r, x, y)
	if backend == "monitor" then
		local _, side, px, py = queuedEvent("monitor_touch", "top", sx, sy)
		assert(side == "top")
		return ui:tap(px, py)
	end
	local _, button, px, py = queuedEvent("mouse_click", 1, sx, sy)
	assert(button == 1)
	ui:pointerDown(px, py)
	local _, upButton, upX, upY = queuedEvent("mouse_up", 1, sx, sy)
	assert(upButton == 1)
	ui:pointerUp(upX, upY)
	return true
end

local function tapButton(ui, label, draw, operations)
	local target
	for _, button in ipairs(ui.r.buttons or {}) do
		if button.label == label then
			target = button
			break
		end
	end
	assert(target, "Native UI is missing button: " .. label)
	local x, y = target.x + target.w / 2, target.y + target.h / 2
	measured(operations, "input:" .. label, function()
		assert(tap(ui, x, y), "Native button did not consume input: " .. label)
	end)
	draw()
end

local projectedState, projectedSnapshot
local presentationCaptures, presentationReuses = 0, 0
local function frame(ui, state, operations, name)
	progress("begin " .. name)
	local started = os.epoch("utc")
	if projectedState ~= state then
		projectedSnapshot = measured(operations, "observer-projection", function()
			return Presentation.capture(state, state.players[1].id)
		end)
		projectedState = state
		presentationCaptures = presentationCaptures + 1
	else
		presentationReuses = presentationReuses + 1
	end
	ui:draw(projectedSnapshot, state.players[1].id, { screen = "game", report = false })
	local elapsed = os.epoch("utc") - started
	operations[#operations + 1] = { name = name, elapsedMillis = elapsed }
	if elapsed > maximum.elapsedMillis then
		maximum = { name = name, elapsedMillis = elapsed }
	end
	progress("end " .. name .. " elapsed=" .. elapsed)
	return elapsed
end

local function componentStats()
	return {
		clock = "os.epoch(utc), milliseconds",
		inclusive = true,
		components = {},
		cooperative = {
			work = { yields = 0, gcCycles = 0, gcTotalMillis = 0, gcMaximumMillis = 0 },
			renderer = { yields = 0, gcCycles = 0, gcTotalMillis = 0, gcMaximumMillis = 0 },
		},
	}
end

local function instrumentComponent(target, field, label, stats)
	local original = target[field]
	assert(type(original) == "function", "Missing component draw function: " .. label)
	local item = { calls = 0, totalMillis = 0, maximumMillis = 0 }
	stats.components[label] = item
	target[field] = function(...)
		local started = os.epoch("utc")
		local result = table.pack(pcall(original, ...))
		local elapsed = os.epoch("utc") - started
		item.calls = item.calls + 1
		item.totalMillis = item.totalMillis + elapsed
		item.maximumMillis = math.max(item.maximumMillis, elapsed)
		if not result[1] then
			error(result[2], 0)
		end
		return table.unpack(result, 2, result.n)
	end
end

local function cooperativeTrace(stats, name)
	return function(stage, detail)
		local item = stats.cooperative[name]
		if stage == "yield.begin" then
			item.yields = item.yields + 1
		elseif stage == "gc.end" then
			local elapsed = tonumber(tostring(detail):match("elapsed=(%d+)")) or 0
			item.gcCycles = item.gcCycles + 1
			item.gcTotalMillis = item.gcTotalMillis + elapsed
			item.gcMaximumMillis = math.max(item.gcMaximumMillis, elapsed)
		end
	end
end

local profileStats = profileFirstFrame and componentStats() or nil
if profileStats then
	work.trace = cooperativeTrace(profileStats, "work")
end

for profileIndex, profile in ipairs(profiles) do
	if profileFirstFrame and profileIndex > 1 then
		break
	end
	for sizeIndex, size in ipairs(sizes) do
		if profileFirstFrame and sizeIndex > 1 then
			break
		end
		progress("scenario " .. profile.name .. " " .. size)
		local operations = {}
		local scenarioIndex = (profileIndex - 1) * #sizes + sizeIndex
		local state = measured(operations, "generate-and-prepare", function()
			return newState(profile, size, scenarioIndex)
		end)
		local dimensions = World.dimensions(size, state)
		local expectedWidth, expectedHeight = dimensions[1], dimensions[2]
		assert(state.world.width == expectedWidth and state.world.height == expectedHeight)
		local acceptedDimensions = {
			huge = { 96, 60 },
			vast = { 120, 76 },
		}
		assert(
			expectedWidth == acceptedDimensions[size][1]
				and expectedHeight == acceptedDimensions[size][2],
			"Founders profiles must use their accepted expanded map dimensions"
		)
		assert(#state.cities == 40 and #state.units == 200)
		local expectedWrap = profile.contentRules == "balance5"
		assert(state.round == 100 and state.world.wrapX == expectedWrap)
		local expectedTiles = expectedWidth * expectedHeight
		local observedTiles = 0
		for _ in pairs(state.players[1].visible) do
			observedTiles = observedTiles + 1
		end
		assert(
			observedTiles == expectedTiles,
			"Controlled late-state observer must see the full map"
		)
		local rivalID = state.players[2].id
		local rivalView = World.forPlayer(state, rivalID)
		for _, unit in ipairs(rivalView.units or {}) do
			if unit.owner ~= rivalID then
				assert(
					state.players[2].visible[World.key(unit.x, unit.y)],
					"Runtime projection leaked a hidden rival unit"
				)
			end
		end

		local ui = UI.new(displayFor(backend), function()
			error("The performance fixture must not mutate gameplay through UI commands")
		end)
		local playerID = state.players[1].id
		if profileFirstFrame then
			local GameView = module("game_view")
			local MapView = module("map_view")
			local Inspector = module("inspector")
			local CityBanner = module("city_banner")
			local HUD = module("hud")
			local Railways = module("railways")
			instrumentComponent(HUD, "resources", "HUD.resources", profileStats)
			instrumentComponent(Systems, "economy", "Systems.economy", profileStats)
			instrumentComponent(Systems, "yields", "Systems.yields", profileStats)
			instrumentComponent(World, "territory", "World.territory", profileStats)
			instrumentComponent(Railways, "network", "Railways.network", profileStats)
			instrumentComponent(GameView, "draw", "GameView.draw", profileStats)
			instrumentComponent(MapView, "draw", "MapView.draw", profileStats)
			instrumentComponent(Inspector, "draw", "Inspector.draw", profileStats)
			instrumentComponent(CityBanner, "model", "CityBanner.model", profileStats)
			instrumentComponent(CityBanner, "layout", "CityBanner.layout", profileStats)
			instrumentComponent(CityBanner, "draw", "CityBanner.draw", profileStats)
			ui.r.trace = cooperativeTrace(profileStats, "renderer")
			report.componentProfile = profileStats
			report.scenarios[1] = {
				profile = profile.name,
				contentRules = profile.contentRules,
				size = size,
				width = expectedWidth,
				height = expectedHeight,
				wrapX = state.world.wrapX,
				cities = #state.cities,
				units = #state.units,
				round = state.round,
				stage = "state-prepared",
			}
			persistPartial("state-prepared")
			projectedSnapshot = measured(operations, "observer-projection", function()
				return Presentation.capture(state, playerID)
			end)
			projectedState = state
			presentationCaptures = presentationCaptures + 1
			report.presentationCaptures = presentationCaptures
			persistPartial("presentation-ready")
		end
		local function draw(name)
			return frame(ui, state, operations, name)
		end
		local initialElapsed = draw("initial-render")
		if profileFirstFrame then
			local scenario = report.scenarios[1]
			scenario.stage = "first-frame-complete"
			scenario.firstFrameMillis = initialElapsed
			scenario.operations = operations
			scenario.presentationReuses = presentationReuses
			scenario.renderer = ui.r.mode
			scenario.rendererYields = ui.r.yieldToken or 0
			scenario.cooperativeYields = work.yieldToken or 0
			scenario.gc = {
				workCycles = work.gcCycles or 0,
				workMaximumMillis = work.gcMaxMillis or 0,
				rendererCycles = ui.r.gcCycles or 0,
				rendererMaximumMillis = ui.r.gcMaxMillis or 0,
				tracedWork = profileStats.cooperative.work,
				tracedRenderer = profileStats.cooperative.renderer,
			}
			local partialMaximum = { name = "none", elapsedMillis = 0 }
			for _, operation in ipairs(operations) do
				if operation.elapsedMillis > partialMaximum.elapsedMillis then
					partialMaximum = {
						name = operation.name,
						elapsedMillis = operation.elapsedMillis,
					}
				end
			end
			scenario.maximumOperation = partialMaximum
			report.maximumOperation = maximum
			report.checkpoints = work.work or 0
			report.yields = work.yieldToken or 0
			report.profileOnly = true
			persistPartial("first-frame-complete")
			ui:close()
			return report
		end
		assert(ui.mapViewport and ui.mapViewport.world.width == expectedWidth)
		if backend == "text" then
			assert(ui.r.mode == "text", "Text backend did not use the native text renderer")
		elseif backend == "monitor" then
			assert(ui.r.mode == "graphics", "Monitor backend did not use native graphics mode")
		end
		local firstCity = state.cities[1]
		ui:focus("city", firstCity)
		draw("focus-city-render")
		local banner
		for _, target in ipairs(ui.cityBannerTargets or {}) do
			if target.city.id == firstCity.id then
				banner = target
				break
			end
		end
		assert(
			banner,
			"Native viewport did not produce a city banner target: "
				.. textutils.serialize({
					profile = profile.name,
					size = size,
					city = firstCity.id,
					x = firstCity.x,
					y = firstCity.y,
					viewport = ui.mapViewport,
					panX = ui.panX,
					panY = ui.panY,
					targets = ui.cityBannerTargets,
				})
		)
		local v = ui.mapViewport
		local left, top = math.max(banner.x, v.x), math.max(banner.y, v.y)
		local right = math.min(banner.x + banner.w, v.x + v.w)
		local bottom = math.min(banner.y + banner.h, v.y + v.h)
		assert(right > left and bottom > top, "City banner has no visible clickable area")
		local clickX, clickY = (left + right) / 2, (top + bottom) / 2
		if ui.r.mode == "text" then
			clickX, clickY = math.ceil(left / 2) * 2, math.ceil(top / 3) * 3
			assert(
				clickX < right and clickY < bottom,
				"Clipped city banner has no native text input cell"
			)
		end
		measured(operations, "input:city-banner", function()
			assert(tap(ui, clickX, clickY), "Native city banner input was not handled")
		end)
		assert(
			ui.selected.kind == "city" and ui.selected.x == firstCity.x,
			"Visible banner input selected a different actor: "
				.. textutils.serialize({
					selected = ui.selected,
					banner = banner,
					point = { clickX, clickY },
					viewport = v,
				})
		)
		draw("city-selection-render")

		local beforeZoom = ui.mapViewport.tile
		if
			not (function()
				for _, button in ipairs(ui.r.buttons or {}) do
					if button.label == "ZOOM IN" then
						return true
					end
				end
				return false
			end)()
		then
			tapButton(ui, "MAP TOOLS", function()
				draw("open-map-tools")
			end, operations)
		end
		for _ = 1, 8 do
			local hasZoom = false
			for _, button in ipairs(ui.r.buttons or {}) do
				hasZoom = hasZoom or button.label == "ZOOM IN"
			end
			if hasZoom then
				break
			end
			tapButton(ui, "NEXT", function()
				draw("map-tools-page")
			end, operations)
		end
		tapButton(ui, "ZOOM IN", function()
			draw("zoom-render")
		end, operations)
		assert(ui.mapViewport.tile > beforeZoom, "Native zoom input did not change map scale")

		if backend == "monitor" then
			if ui.panel == "mapTools" then
				tapButton(ui, "CLOSE", function()
					draw("close-map-tools")
				end, operations)
			end
			local edge
			for _, button in ipairs(ui.r.buttons or {}) do
				if button.label == "MAP RIGHT EDGE" then
					edge = button
					break
				end
			end
			assert(edge, "Native monitor map has no pan edge target")
			local beforePan = ui.panX
			measured(operations, "input:monitor-pan", function()
				assert(tap(ui, edge.x + edge.w / 2, edge.y + edge.h / 2))
			end)
			assert(ui.panX ~= beforePan, "Monitor pan edge input did not move the camera")
			draw("monitor-pan-render")
		else
			local view = ui.mapViewport
			local sx, sy = unobstructedNativeMapPoint(ui)
			local dragDistance = math.max(2, math.min(8, math.floor(view.w / 4)))
			local dx, dy
			for _, direction in ipairs({ sx < ui.r.w / 2 and 1 or -1, sx < ui.r.w / 2 and -1 or 1 }) do
				local candidateX = sx + dragDistance * direction
				local rx, ry = ui.r:touch(candidateX, sy)
				if
					rx
					and ry
					and rx >= view.x
					and rx < view.x + view.w
					and ry >= view.y
					and ry < view.y + view.h
				then
					dx, dy = candidateX, sy
					break
				end
			end
			assert(dx, "Native map viewport has no in-bounds drag endpoint")
			local beforePan = ui.panX
			measured(operations, "input:mouse-drag", function()
				local _, downButton, downX, downY = queuedEvent("mouse_click", 1, sx, sy)
				assert(downButton == 1)
				ui:pointerDown(downX, downY)
				local _, dragButton, dragX, dragY = queuedEvent("mouse_drag", 1, dx, dy)
				assert(dragButton == 1)
				assert(ui:drag(dragX, dragY), "Native mouse drag was not handled")
				local _, upButton, upX, upY = queuedEvent("mouse_up", 1, dx, dy)
				assert(upButton == 1)
				ui:pointerUp(upX, upY)
			end)
			assert(ui.panX ~= beforePan, "Native mouse drag did not pan the camera")
			draw("drag-render")
		end

		local beforeSave = {
			width = state.world.width,
			height = state.world.height,
			wrapX = state.world.wrapX,
			contentRules = state.contentRules,
			cities = #state.cities,
			units = #state.units,
		}
		measured(operations, "save", function()
			Saves.save(1, state)
		end)
		local restored = measured(operations, "load", function()
			return assert(Saves.load(1), "Native save did not reload")
		end)
		restored = Systems.migrate(World.migrate(restored))
		assert(restored.round == 100 and restored.contentRules == profile.contentRules)
		assert(
			restored.world.width == beforeSave.width and restored.world.height == beforeSave.height
		)
		assert(restored.world.wrapX == beforeSave.wrapX)
		assert(#restored.cities == beforeSave.cities and #restored.units == beforeSave.units)
		for key, tile in pairs(state.world.tiles) do
			assert(restored.world.tiles[key] == tile, "Save changed generated terrain at " .. key)
		end
		for index, city in ipairs(state.cities) do
			local saved = restored.cities[index]
			assert(saved.id == city.id and saved.x == city.x and saved.y == city.y)
		end
		for index, unit in ipairs(state.units) do
			local saved = restored.units[index]
			assert(saved.id == unit.id and saved.x == unit.x and saved.y == unit.y)
		end
		state = restored
		ui.worldReady = false
		ui.panX, ui.panY = 0, 0
		draw("restored-render")
		ui:close()
		local scenario = {
			profile = profile.name,
			contentRules = profile.contentRules,
			size = size,
			width = expectedWidth,
			height = expectedHeight,
			wrapX = state.world.wrapX,
			seed = state.world.seed,
			cities = #state.cities,
			units = #state.units,
			round = state.round,
			renderer = ui.r.mode,
			frames = 0,
			maximumFrameMillis = initialElapsed,
			maximumOperation = { name = "none", elapsedMillis = 0 },
			operations = operations,
			rendererYields = ui.r.yieldToken or 0,
			cooperativeYields = work.yieldToken or 0,
			savedBytes = fs.getSize(Saves.path(1)),
			gcCycles = ui.r.gcCycles or 0,
			gcMaximumMillis = ui.r.gcMaxMillis or 0,
		}
		for _, operation in ipairs(operations) do
			if operation.name:find("render", 1, true) or operation.name == "drag-render" then
				scenario.frames = scenario.frames + 1
				scenario.maximumFrameMillis =
					math.max(scenario.maximumFrameMillis, operation.elapsedMillis)
			end
			if operation.elapsedMillis > scenario.maximumOperation.elapsedMillis then
				scenario.maximumOperation = {
					name = operation.name,
					elapsedMillis = operation.elapsedMillis,
				}
			end
		end
		report.scenarios[#report.scenarios + 1] = scenario
		checkpoint()
	end
end

report.maximumOperation = maximum
report.checkpoints = work.work or 0
report.yields = work.yieldToken or 0
report.gcCycles = work.gcCycles or 0
report.gcMaximumMillis = work.gcMaxMillis or 0
assert(#report.scenarios == 4, "Expected fixed Founders V4/V5 by Huge/Vast scenario matrix")
return report
