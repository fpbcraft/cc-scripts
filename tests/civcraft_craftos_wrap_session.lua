-- Native UI workflow for wrapped map rendering and canonical action/save data.
local monitorMode = ... == "--monitor"
if monitorMode then
	assert(_G.periphemu.create("top", "monitor"), "Create a monitor in a fresh profile")
end

local loader = dofile("/games/civcraft/_lib/fpb/loader.lua")
local env = loader.environment("/games/civcraft", _ENV, "game.lua")
env.dofile("/games/civcraft/module_cache.lua").install(env)
local function module(name)
	return env.dofile("/games/civcraft/" .. name .. ".lua")
end

local Actions = module("actions")
local AnimationFrame = module("animation_frame")
local DisplayGeometry = module("display_geometry")
local Hex = module("hex")
local Saves = module("saves")
local Systems = module("systems")
local UI = module("ui")
local World = module("world")

local width, height = 4, 24
local state = {
	version = 6,
	phase = "game",
	name = "NATIVE WRAP WORKFLOW",
	campaignID = "native-wrap-workflow",
	round = 1,
	ruleset = "create",
	gameSpeed = "normal",
	nextId = 20,
	players = {
		{ id = 1, name = "HOST", civ = "iron", techs = {}, gold = 100 },
		{ id = 2, name = "OBSERVER", civ = "verdant", techs = {}, gold = 100 },
	},
	cities = {
		{ id = 10, owner = 1, x = 2, y = 2, population = 2, buildings = {} },
	},
	units = {
		{ id = 11, owner = 1, kind = "scout", x = 1, y = 4, movesLeft = 3 },
	},
	world = {
		width = width,
		height = height,
		wrapX = true,
		seed = 114,
		tiles = {},
		resources = {},
		landmarks = {},
		rails = {},
	},
}
for y = 1, height do
	for x = 1, width do
		state.world.tiles[World.key(x, y)] = "plains"
	end
end
Systems.migrate(state)
World.reveal(state, Hex, Systems)

local requests = {}
local function dispatch(action, request)
	requests[#requests + 1] =
		{ action = action, x = request and request.x, y = request and request.y }
	local ok, why = Actions.apply(state, 1, request, Systems)
	assert(ok, why)
end
local display = monitorMode and peripheral.wrap("top") or term.current()
if monitorMode then
	display.setTextScale(0.5)
end
local ui = UI.new(display, dispatch)
assert(ui.r.mode == "graphics", "Wrapped native workflow requires the real graphics renderer")
ui.zoomLevel = 8
local drawOptions = { screen = "game", localMode = true, report = false }
local function draw()
	local snapshot = World.forPlayer(state, 1)
	ui:draw(snapshot, 1, drawOptions)
	return snapshot
end

local function screenPoint(x, y)
	local r = ui.r
	if r.mode == "graphics" then
		return math.floor(r.ox + x * r.sx), math.floor(r.oy + y * r.sy)
	end
	return math.floor(x / 2 + 1), math.floor(y / 3 + 1)
end

local function tap(x, y)
	local sx, sy = screenPoint(x, y)
	if monitorMode then
		os.queueEvent("monitor_touch", "top", sx, sy)
		local event, side, px, py = os.pullEvent()
		assert(
			event == "monitor_touch" and side == "top",
			"Native monitor touch event was not queued"
		)
		ui:tap(px, py)
	else
		os.queueEvent("mouse_click", 1, sx, sy)
		local event, button, px, py = os.pullEvent()
		assert(event == "mouse_click" and button == 1, "Native mouse click event was not queued")
		ui:pointerDown(px, py)
		os.queueEvent("mouse_up", 1, sx, sy)
		local release, releaseButton, rx, ry = os.pullEvent()
		assert(release == "mouse_up" and releaseButton == 1, "Native mouse release was not queued")
		ui:pointerUp(rx, ry)
	end
end

local function button(label)
	for _, target in ipairs(ui.r.buttons or {}) do
		if target.label == label then
			return target
		end
	end
end

local function tapButton(label)
	local target = assert(button(label), "Native UI is missing button: " .. label)
	tap(target.x + target.w / 2, target.y + target.h / 2)
	draw()
end

local function targetPoint(target)
	return target.x + target.w / 2, target.y + target.h / 2
end

local function findCityCopies()
	local result = {}
	for _, target in ipairs(ui.cityBannerTargets or {}) do
		if target.city.id == 10 then
			result[#result + 1] = target
		end
	end
	return result
end

local function findUnitCopies()
	local result = {}
	for _, target in ipairs(ui.unitIconTargets or {}) do
		if target.unit.id == 11 then
			result[#result + 1] = target
		end
	end
	if #result == 0 then
		for _, target in ipairs(ui.unitBadgeTargets or {}) do
			if target.unit.id == 11 then
				result[#result + 1] = target
			end
		end
	end
	return result
end

draw()
local viewport = assert(ui.mapViewport)
assert(viewport.wrapX and viewport.world.wrapX, "Native viewport lacks cylinder geometry metadata")
assert(viewport.world.width == width and viewport.world.height == height)
assert(viewport.w > viewport.periodX, "Native viewport does not expose multiple cylinder copies")

-- Keep the owned city row comfortably inside the map viewport before testing
-- repeated hit targets; native inspector height varies by terminal size.
ui.panY = math.max(
	0,
	math.min(viewport.maxY, (2 - 1) * viewport.tile * 0.75 + viewport.tile / 2 - viewport.h / 2)
)
draw()
local cityCopies = findCityCopies()
if #cityCopies <= 1 then
	local cityTileCopies = 0
	local cityTiles = {}
	for _, target in ipairs(ui.hexTargets or {}) do
		if target.tx == 2 and target.ty == 2 then
			cityTileCopies = cityTileCopies + 1
			cityTiles[#cityTiles + 1] = string.format("%.1f,%.1f", target.x, target.y)
		end
	end
	local projectedCities = {}
	for _, city in ipairs(ui.state and ui.state.cities or {}) do
		projectedCities[#projectedCities + 1] =
			table.concat({ city.id or "?", city.x or "?", city.y or "?", city.name or "?" }, ":")
	end
	error(
		string.format(
			"Repeated native city banners were not produced (copies=%d, cityTiles=%d [%s], "
				.. "viewport=%dx%d period=%.1f pan=%.1f,%.1f city=%s)",
			#cityCopies,
			cityTileCopies,
			table.concat(cityTiles, ";"),
			viewport.w,
			viewport.h,
			viewport.periodX,
			ui.panX,
			ui.panY,
			table.concat(projectedCities, ";")
		)
	)
end
local cityX, cityY = targetPoint(cityCopies[#cityCopies])
tap(cityX, cityY)
assert(ui.selected.kind == "city" and ui.selected.x == 2 and ui.selected.y == 2)
draw()

local unitCopies = findUnitCopies()
assert(#unitCopies > 1, "Repeated native unit icon or badge targets were not produced")
local unitX, unitY = targetPoint(unitCopies[#unitCopies])
tap(unitX, unitY)
assert(ui.selected.kind == "unit" and ui.selected.unitID == 11)
draw()

local beforeZoom = ui.mapViewport.tile
if not button("ZOOM IN") then
	tapButton("MAP TOOLS")
end
tapButton("ZOOM IN")
assert(ui.mapViewport.tile > beforeZoom, "Queued native zoom input did not zoom the wrapped map")
local periodX = ui.mapViewport.periodX
ui.panX = periodX - 2
draw()
local beforePan = ui.panX
local edge = assert(button("MAP RIGHT"), "Wrapped map has no right pan target")
local edgeX, edgeY = targetPoint(edge)
tap(edgeX, edgeY)
assert(ui.panX ~= beforePan, "Queued native edge input did not pan the wrapped map")
assert(ui.panX >= 0 and ui.panX < ui.mapViewport.periodX, "Wrapped pan escaped its display period")
draw()

-- Start movement through the actual inspector control, select a repeated target
-- hex, and confirm through the real UI dispatch path into Actions.apply.
local moveButton = assert(button("MOVE / ATTACK"), "Selected scout has no native move control")
local moveX, moveY = targetPoint(moveButton)
tap(moveX, moveY)
draw()
local seamTarget
for _, target in ipairs(ui.hexTargets or {}) do
	if target.tx == width and target.ty == 4 then
		seamTarget = target
		break
	end
end
assert(seamTarget, "Canonical seam destination has no visible native hex target")
local targetX, targetY = targetPoint(seamTarget)
tap(targetX, targetY)
assert(ui.pendingMove and ui.pendingMove.x == width and ui.pendingMove.y == 4)
draw()
tapButton("CONFIRM")
assert(
	state.units[1].x == width and state.units[1].y == 4,
	"Confirmed native seam move did not apply"
)
assert(requests[#requests].action == "move" and requests[#requests].x == width)

local moveEvent
for _, entry in ipairs(state.eventJournal.streams[1].entries) do
	if entry.type == "move" then
		moveEvent = entry
	end
end
assert(moveEvent, "Authoritative seam move emitted no event")
local finalPath = moveEvent.paths[#moveEvent.paths]
assert(finalPath[#finalPath].x == width and finalPath[#finalPath].y == 4)
assert(moveEvent.actor.x == nil, "Observer event actor leaked non-projected position data")

local hidden = World.forPlayer(state, 2)
for _, unit in ipairs(hidden.units or {}) do
	assert(unit.id ~= 11, "Observer snapshot exposed an unobserved unit")
end
for _, entry in ipairs((hidden.eventStream or {}).entries or {}) do
	assert(entry.type ~= "move", "Observer event stream exposed an unseen seam movement")
end

local ownView = draw()
assert(
	ui:animating() and ui.animationFrame.event.type == "move",
	"Native map did not render movement playback"
)
local now = os.epoch("utc") / 1000
ui.playback.active.start = now - 0.06
ui.playback.active.finish = now + 0.06
ownView = draw()
assert(ui.animationFrame.progress > 0.45 and ui.animationFrame.progress < 0.55)
local displayFrame = { hidden = {}, sprites = {}, effects = {} }
AnimationFrame.paint(
	displayFrame,
	ui.animationFrame.event,
	ui.animationFrame.progress,
	ownView.world
)
assert(
	math.abs(displayFrame.sprites[1].position.x - 0.75) < 0.001,
	"Seam movement animation took the long map path"
)
local cameraCenterX = (ui.panX + ui.mapViewport.w / 2) / ui.mapViewport.tile
local followDistance = math.abs(
	DisplayGeometry.nearestX(displayFrame.sprites[1].position.x, cameraCenterX, ownView)
		- cameraCenterX
)
assert(followDistance < 0.01, "Camera did not follow the nearby animated copy")

if not button("WORLD OVERVIEW") then
	tapButton("MAP TOOLS")
end
tapButton("WORLD OVERVIEW")
local minimap = assert(button("MINIMAP"), "Native minimap has no pointer target")
local beforeMiniY = ui.panY
tap(minimap.x + minimap.w / 2, minimap.y + minimap.h * 0.9)
assert(ui.panY ~= beforeMiniY, "Queued minimap input did not pan the bounded Y axis")
draw()

assert(Saves.save(1, state), "Native wrapped campaign save failed")
local wrappedSave = assert(Saves.load(1), "Native wrapped campaign did not reload")
assert(wrappedSave.world.wrapX == true, "Native save lost its cylinder topology")
assert(wrappedSave.units[1].x == width, "Native save changed canonical unit coordinates")
local legacy = {}
for key, value in pairs(state) do
	legacy[key] = value
end
legacy.world = {}
for key, value in pairs(state.world) do
	legacy.world[key] = value
end
legacy.world.wrapX = nil
assert(Saves.save(2, legacy), "Native legacy bounded campaign save failed")
local legacySave = assert(Saves.load(2), "Native legacy campaign did not reload")
Systems.migrate(legacySave)
assert(legacySave.world.wrapX == false, "Missing wrap flag did not migrate to bounded topology")
assert(Hex.canonical(0, 4, legacySave) == nil, "Legacy missing-wrap save accepted a wrapped alias")
assert(
	not Hex.inBounds(width + 1, 4, wrappedSave),
	"External action coordinates must remain canonical"
)

local report = {
	ok = true,
	mode = monitorMode and "monitor" or "gui",
	renderer = ui.r.mode,
	viewport = {
		width = viewport.world.width,
		height = viewport.world.height,
		periodX = viewport.periodX,
		viewportWidth = viewport.w,
	},
	cityCopies = #cityCopies,
	unitCopies = #unitCopies,
	move = { fromX = 1, toX = width, eventCanonical = finalPath[#finalPath].x },
	savedWrap = wrappedSave.world.wrapX,
	legacyWrap = legacySave.world.wrapX,
	privateSnapshotUnits = #hidden.units,
}
local output = assert(fs.open("/civcraft-wrap-session-result.json", "w"))
output.write(textutils.serializeJSON(report))
output.close()
ui:close()
print("CIVCRAFT: native wrapped UI, seam movement, privacy and save workflow passed.")
