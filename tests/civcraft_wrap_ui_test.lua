local oldDofile = dofile
dofile = function(path)
	if path:sub(1, 16) == "/games/civcraft/" then
		return oldDofile(path:sub(2))
	end
	return oldDofile(path)
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
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local UI = oldDofile("games/civcraft/ui.lua")
local World = oldDofile("games/civcraft/world.lua")
local Systems = oldDofile("games/civcraft/systems.lua")
local Minimap = oldDofile("games/civcraft/minimap.lua")
local Hex = oldDofile("games/civcraft/hex.lua")
dofile = oldDofile

local monitor = {
	getSize = function(mode)
		if mode == 2 then
			return 720, 540
		end
		return 80, 40
	end,
	getPaletteColor = function()
		return 0, 0, 0
	end,
	setPaletteColor = function() end,
	setCursorPos = function() end,
	setBackgroundColor = function() end,
	setTextColor = function() end,
	write = function() end,
	setGraphicsMode = function() end,
	drawPixels = function() end,
}

local function makeWorld(wrapX)
	local state = {
		phase = "game",
		campaignID = "wrap-ui-test",
		round = 1,
		ruleset = "create",
		players = { { id = 1, name = "HOST", civ = "iron", techs = {} } },
		cities = { { id = 10, owner = 1, x = 1, y = 4, population = 2, buildings = {} } },
		units = { { id = 11, owner = 1, kind = "scout", x = 3, y = 4, movesLeft = 2 } },
		world = {
			width = 6,
			height = 8,
			wrapX = wrapX,
			tiles = {},
			resources = {},
			rails = {},
			landmarks = {},
		},
	}
	for y = 1, 8 do
		for x = 1, 6 do
			state.world.tiles[World.key(x, y)] = "plains"
		end
	end
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	return state
end

local calls = {}
local ui = UI.new(monitor, function(action)
	calls[#calls + 1] = action
end)
ui.zoomLevel = 12
local state = makeWorld(true)
state.cities, state.units = {}, {}
Systems.migrate(state)
World.reveal(state, Hex, Systems)
ui:draw(World.forPlayer(state, 1), 1, { screen = "game", localMode = true })
assert(ui.mapViewport.wrapX and ui.mapViewport.world.wrapX, "Viewport publishes cylinder metadata")
assert(ui.mapViewport.world.width == 6 and ui.mapViewport.world.height == 8)

local byTile = {}
for _, target in ipairs(ui.hexTargets) do
	local key = target.tx .. ":" .. target.ty
	byTile[key] = byTile[key] or {}
	byTile[key][#byTile[key] + 1] = target
end
local visibleCopies = {}
for _, copies in pairs(byTile) do
	if #copies > 1 then
		for _, target in ipairs(copies) do
			local centerX = target.x + target.w / 2
			if
				centerX >= ui.mapViewport.x
				and centerX < ui.mapViewport.x + ui.mapViewport.w
				and target.y + target.h / 2 >= ui.mapViewport.y
				and target.y + target.h / 2 < ui.mapViewport.y + ui.mapViewport.h
			then
				visibleCopies[#visibleCopies + 1] = target
			end
		end
		if #visibleCopies > 1 then
			break
		end
	end
end
assert(#visibleCopies > 1, "Repeated canonical tile copies have hit targets")
local selected = visibleCopies[#visibleCopies]
local px = ui.r.ox + (selected.x + selected.w / 2) * ui.r.sx
local py = ui.r.oy + (selected.y + selected.h / 2) * ui.r.sy
assert(ui:tap(px, py), "Repeated tile copy consumes pointer input")
assert(
	ui.selected.x == selected.tx and ui.selected.y == selected.ty,
	"Repeated hit target selects canonical tile: target="
		.. selected.tx
		.. ":"
		.. selected.ty
		.. " selected="
		.. tostring(ui.selected.x)
		.. ":"
		.. tostring(ui.selected.y)
)
local repeatedIcons = {}
local actorState = makeWorld(true)
ui.worldReady = false
ui.panX = 0
ui:draw(World.forPlayer(actorState, 1), 1, { screen = "game", localMode = true })
for _, icon in ipairs(ui.unitIconTargets or {}) do
	if icon.unit.id == 11 then
		repeatedIcons[#repeatedIcons + 1] = icon
	end
end
assert(#repeatedIcons > 1, "Unit icon hit targets repeat with the map")
for _, icon in ipairs(repeatedIcons) do
	local bx, by = icon.x + icon.w / 2, icon.y + icon.h / 2
	if
		bx >= ui.mapViewport.x
		and bx < ui.mapViewport.x + ui.mapViewport.w
		and by >= ui.mapViewport.y
		and by < ui.mapViewport.y + ui.mapViewport.h
	then
		local screenX = ui.r.ox + bx * ui.r.sx
		local screenY = ui.r.oy + by * ui.r.sy
		assert(ui:tap(screenX, screenY), "Each repeated icon copy is clickable")
		assert(ui.selected.unitID == 11, "Repeated icon selects the canonical unit")
	end
end
local cityBanner
for _, banner in ipairs(ui.cityBannerTargets or {}) do
	if banner.city.id == 10 then
		cityBanner = banner
		break
	end
end
assert(cityBanner, "City banner has an input target")
local bannerX = ui.r.ox + (cityBanner.x + cityBanner.w / 2) * ui.r.sx
local bannerY = ui.r.oy + (cityBanner.y + cityBanner.h / 2) * ui.r.sy
assert(ui:tap(bannerX, bannerY), "City banner remains clickable on wrapped maps")
assert(ui.selected.kind == "city" and ui.selected.x == 1, "Banner selects canonical city")

local period = ui.mapViewport.periodX
ui.panX = period - 2
assert(ui:pan(5, 0) and ui.panX == 3, "Wrapped camera pans continuously through the seam")
ui:draw(World.forPlayer(state, 1), 1, { screen = "game", localMode = true })
assert(ui.mapViewport.wrapX and ui.mapViewport.periodX == period)
local fullOutlines = {}
local drawOutline = ui.r.outline
ui.r.outline = function(_, x, y, width, height)
	fullOutlines[#fullOutlines + 1] = { x = x, y = y, w = width, h = height }
end
local minimapRect = { x = 10, y = 10, w = 100, h = 60 }
Minimap.draw(ui, World.forPlayer(state, 1), World.forPlayer(state, 1), minimapRect)
ui.r.outline = drawOutline
assert(fullOutlines[1].x == minimapRect.x and fullOutlines[1].w == minimapRect.w)

local bounded = makeWorld(false)
ui.worldReady = false
ui.panX = 0
ui:draw(World.forPlayer(bounded, 1), 1, { screen = "game", localMode = true })
assert(not ui.mapViewport.wrapX, "Explicit bounded worlds stay bounded")
assert(ui:pan(period, 0) and ui.panX == ui.mapViewport.maxX, "Bounded camera still clamps at edge")

local wideState = makeWorld(true)
wideState.world.width = 40
wideState.world.height = 26
wideState.world.tiles = {}
for y = 1, 26 do
	for x = 1, 40 do
		wideState.world.tiles[World.key(x, y)] = "plains"
	end
end
wideState.cities[1].x, wideState.cities[1].y = 1, 13
wideState.units[1].x, wideState.units[1].y = 1, 13
Systems.migrate(wideState)
World.reveal(wideState, Hex, Systems)
ui.worldReady = false
ui.panX = 0
ui:draw(World.forPlayer(wideState, 1), 1, { screen = "game", localMode = true })
local viewport = ui.mapViewport
assert(viewport.w < viewport.periodX, "The minimap seam case has a sub-period viewport")
ui.panX = viewport.periodX - viewport.w / 2
local outlines = {}
local outline = ui.r.outline
ui.r.outline = function(_, x, y, width, height)
	outlines[#outlines + 1] = { x = x, y = y, w = width, h = height }
end
Minimap.draw(ui, World.forPlayer(wideState, 1), World.forPlayer(wideState, 1), {
	x = 10,
	y = 10,
	w = 100,
	h = 60,
})
ui.r.outline = outline
assert(#outlines >= 3, "A viewport crossing the minimap seam splits into two markers")
assert(
	outlines[1].x > 10 and outlines[2].x == 10,
	"The seam marker is split across both minimap edges"
)

local minimapButton = ui.r.buttons[#ui.r.buttons]
local beforePan = ui.panX
local mx = ui.r.ox + (minimapButton.x + minimapButton.w * 0.75) * ui.r.sx
local my = ui.r.oy + (minimapButton.y + minimapButton.h / 2) * ui.r.sy
assert(ui:tap(mx, my), "Minimap remains clickable with wrapped topology")
assert(ui.panX ~= beforePan, "Wrapped minimap click pans modulo the map period")

for _, scenario in ipairs({ { value = nil }, { value = false }, { value = true } }) do
	local wrap = scenario.value
	local lobby = {
		phase = "lobby",
		mapWrapX = wrap,
		players = { { id = 1, name = "HOST", civ = "iron", techs = {} } },
	}
	ui.lastCampaign = nil
	ui.lastPlayer = nil
	ui.panel = "campaign"
	ui:draw(lobby, 1, { localMode = true, screen = "game" })
	local expected = wrap == true and "MAP WRAP: CYLINDER" or "MAP WRAP: BOUNDED"
	local toggle
	for _, button in ipairs(ui.r.buttons) do
		if button.label == expected then
			toggle = button
		end
	end
	if not toggle then
		local labels = {}
		for _, button in ipairs(ui.r.buttons) do
			labels[#labels + 1] = tostring(button.label)
		end
		error("Campaign topology option missing: " .. table.concat(labels, ", "))
	end
	local bx = ui.r.ox + (toggle.x + toggle.w / 2) * ui.r.sx
	local by = ui.r.oy + (toggle.y + toggle.h / 2) * ui.r.sy
	assert(ui:tap(bx, by), "Campaign topology option is clickable")
	assert(calls[#calls] == "mapWrapX", "Lobby control dispatches topology change")
end

print("CivCraft wrap UI tests passed")
