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
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local UI = dofile("games/civcraft/ui.lua")
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local Hex = dofile("games/civcraft/hex.lua")
local World = dofile("games/civcraft/world.lua")
local Systems = dofile("games/civcraft/systems.lua")
local Presentation = dofile("games/civcraft/presentation.lua")
local Suggestions = dofile("games/civcraft/settlement_suggestions.lua")
local originalCheckpoint = Systems.checkpoint

local function fixture(wrap, contentRules)
	local state = {
		phase = "game",
		campaignID = "settlement-ui-" .. tostring(wrap),
		contentRules = contentRules or "balance5",
		ruleset = "create",
		round = 1,
		players = {
			{
				id = 1,
				name = "ONE",
				civ = "iron",
				techs = {},
				mapMemory = {
					version = 1,
					observations = {},
					landmarks = {},
					rails = {},
					spawners = {},
					cities = {},
					sites = {},
				},
			},
			{ id = 2, name = "TWO", civ = "verdant", techs = {} },
		},
		cities = {
			{ id = 10, owner = 1, name = "HOME", x = 14, y = 8, population = 2, buildings = {} },
		},
		units = { { id = 20, owner = 1, kind = "settler", x = 7, y = 8, movesLeft = 3 } },
		spawners = {},
		world = {
			width = 24,
			height = 16,
			wrapX = wrap,
			mapType = "continents",
			tiles = {},
			geography = {},
			resources = {},
			landmarks = {},
			rails = {},
		},
	}
	state.world.rails = {}
	for y = 1, state.world.height do
		for x = 1, state.world.width do
			local key = World.key(x, y)
			state.world.tiles[key] = "plains"
			state.world.geography[key] = { biome = "plains", elevation = "flat", feature = "none" }
		end
	end
	Systems.migrate(state)
	local player = state.players[1]
	for y = 1, state.world.height do
		for x = 1, 17 do
			local key = World.key(x, y)
			player.explored[key] = true
			player.mapMemory.observations[key] = {
				tile = state.world.tiles[key],
				geography = state.world.geography[key],
			}
		end
	end
	World.reveal(state, Hex, Systems)
	return state
end

local function monitor(width, height, graphics)
	local display = {
		getSize = function(mode)
			if mode == 2 then
				return width * 6, height * 9
			end
			return width, height
		end,
		getPaletteColor = function()
			return 0, 0, 0
		end,
		setPaletteColor = function() end,
		setCursorPos = function() end,
		setBackgroundColor = function() end,
		setTextColor = function() end,
		write = function() end,
	}
	if graphics then
		display.setGraphicsMode = function() end
		display.drawPixels = function() end
	end
	return display
end

local function tap(ui, x, y)
	if ui.r.mode == "graphics" then
		x = math.floor(ui.r.ox + x * ui.r.sx)
		y = math.floor(ui.r.oy + y * ui.r.sy)
	else
		x = math.floor(x / 2) + 1
		y = math.floor(y / 3) + 1
	end
	return ui:tap(x, y)
end

local function sameSites(a, b)
	assert(#a == #b)
	for index, site in ipairs(a) do
		assert(
			site.x == b[index].x and site.y == b[index].y,
			"Hidden map data changed a suggestion"
		)
	end
end

local function drawSelected(ui, state)
	local projected = Presentation.capture(state, 1)
	ui:draw(projected, 1, { screen = "game" })
	local settler = projected.units[1]
	ui:focus("unit", settler)
	ui:draw(projected, 1, { screen = "game" })
	assert(ui.selected.unitID == settler.id)
	assert(ui.settlementSuggestions and #ui.settlementSuggestions > 0)
	assert(
		ui.settlementSuggestionCache.view == projected,
		"Cache keeps only the projected view identity"
	)
	assert(
		Systems.checkpoint == originalCheckpoint,
		"Renderer checkpoints never mutate shared Systems"
	)
	for _, site in ipairs(ui.settlementSuggestions) do
		assert(World.known(projected.players[1], site.x, site.y) ~= "hidden")
	end
	return projected
end

local hiddenA = fixture(false)
local knownA = Presentation.capture(hiddenA, 1)
local suggestionsA = Suggestions.forSettler(knownA, 1, knownA.units[1], Systems, 3)
local hiddenB = fixture(false)
for y = 1, hiddenB.world.height do
	for x = 18, hiddenB.world.width do
		local key = World.key(x, y)
		hiddenB.world.tiles[key] = "water"
		hiddenB.world.resources[key] = "diamond"
		hiddenB.world.landmarks[key] = { kind = "hidden-wonder", natural = true }
	end
end
local knownB = Presentation.capture(hiddenB, 1)
local suggestionsB = Suggestions.forSettler(knownB, 1, knownB.units[1], Systems, 3)
sameSites(suggestionsA, suggestionsB)

local wrapState = fixture(true)
local ui = UI.new(monitor(160, 100, true), function()
	error("Settlement recommendations must not issue game commands")
end)
ui.zoomLevel = 8
local projected = drawSelected(ui, wrapState)
assert(ui.mapViewport.wrapX, "New-profile wrapping is supplied by the saved world state")
local copies = {}
for _, target in ipairs(ui.settlementSuggestionTargets) do
	assert(World.known(projected.players[1], target.site.x, target.site.y) ~= "hidden")
	copies[target.index] = (copies[target.index] or 0) + 1
end
local repeated
for _, count in pairs(copies) do
	if count > 1 then
		repeated = true
	end
end
assert(repeated, "Wrapped map markers should be clickable on repeated visible copies")
local selectedID = ui.selected.unitID
local marker = assert(ui.settlementSuggestionTargets[1], "Visible settlement marker")
assert(tap(ui, marker.x + marker.w / 2, marker.y + marker.h / 2))
assert(ui.panel == "settlementSuggestions", "Marker opens the explanation panel")
assert(ui.selected.kind == "unit" and ui.selected.unitID == selectedID)

local lines = {}
local originalText = ui.r.text
ui.r.text = function(self, x, y, value, ...)
	lines[#lines + 1] = tostring(value)
	return originalText(self, x, y, value, ...)
end
ui:draw(projected, 1, { screen = "game" })
local detailText = table.concat(lines, " "):upper()
assert(detailText:find("FOOD", 1, true) and detailText:find("INDUSTRY", 1, true))
assert(detailText:find("OBSERVED", 1, true), "Explanation labels knowledge as incomplete")
assert(not detailText:find("HIDDEN%-WONDER"), "Hidden landmarks never enter the panel")
assert(ui.selected.unitID == selectedID and ui.panel == "settlementSuggestions")
assert(#ui.r.buttons > 0)
for _, button in ipairs(ui.r.buttons) do
	if button.label == "CLOSE" then
		tap(ui, button.x + button.w / 2, button.y + button.h / 2)
		break
	end
end
assert(ui.panel == "context", "Suggestion explanation can be closed")
assert(ui.selected.unitID == selectedID)
ui.panel = "inspector"
ui:draw(projected, 1, { screen = "game" })
local inspectorButton
for _, button in ipairs(ui.r.buttons) do
	if button.label == "SETTLEMENT SITES " .. #ui.settlementSuggestions then
		inspectorButton = button
		break
	end
end
assert(inspectorButton, "Settler inspector exposes ranked settlement sites")
assert(
	tap(ui, inspectorButton.x + inspectorButton.w / 2, inspectorButton.y + inspectorButton.h / 2)
)
assert(ui.panel == "settlementSuggestions" and ui.selected.unitID == selectedID)

local boundedState = fixture(false)
local small = UI.new(monitor(56, 28, false), function()
	error("Small-screen recommendations cannot dispatch actions")
end)
small.zoomLevel = 8
local boundedView = drawSelected(small, boundedState)
assert(not small.mapViewport.wrapX, "Legacy bounded maps keep bounded suggestion geometry")
assert(#small.settlementSuggestions <= 3)
for _, target in ipairs(small.settlementSuggestionTargets) do
	assert(target.site.x >= 1 and target.site.x <= boundedView.world.width)
	assert(target.site.y >= 1 and target.site.y <= boundedView.world.height)
end
small:focus("city", boundedView.cities[1])
small:draw(boundedView, 1, { screen = "game" })
assert(#small.settlementSuggestionTargets == 0, "Changing selection clears site markers")
small:focus("unit", boundedView.units[1])
small:draw(boundedView, 1, { screen = "game" })
local nextCampaign = fixture(false)
nextCampaign.campaignID = "settlement-ui-next-campaign"
small:draw(Presentation.capture(nextCampaign, 1), 1, { screen = "game" })
assert(
	#small.settlementSuggestionTargets == 0,
	"Changing campaign clears site markers and selection"
)
small:draw(Presentation.capture(nextCampaign, 2), 2, { screen = "game" })
assert(#small.settlementSuggestionTargets == 0, "Changing observer clears site markers")
local legacyState = fixture(false, "baseline")
local legacyView = Presentation.capture(legacyState, 1)
local legacySites = Suggestions.forSettler(legacyView, 1, legacyView.units[1], Systems, 3)
assert(#legacySites > 0 and not legacySites[1].capacity.active)
assert(
	#legacySites[1].specialties == 0,
	"Legacy profiles do not show future specialty opportunities"
)
local legacyUI = UI.new(monitor(100, 60, false), function()
	error("Legacy settlement explanations cannot dispatch game commands")
end)
legacyUI.zoomLevel = 8
local legacyProjected = drawSelected(legacyUI, legacyState)
legacyUI.settlementSuggestionDetail = { x = legacySites[1].x, y = legacySites[1].y }
legacyUI.panel = "settlementSuggestions"
local legacyLines = {}
local legacyText = legacyUI.r.text
legacyUI.r.text = function(self, x, y, value, ...)
	legacyLines[#legacyLines + 1] = tostring(value)
	return legacyText(self, x, y, value, ...)
end
legacyUI:draw(legacyProjected, 1, { screen = "game" })
local legacyDetails = table.concat(legacyLines, " "):upper()
assert(legacyDetails:find("CITY CAPACITY IS NOT ACTIVE", 1, true))
assert(not legacyDetails:find("CAPACITY AT LEAST 0", 1, true))
ui:close()
small:close()
legacyUI:close()
print(
	"CIVCRAFT: ranked settlement hints stay observer-safe and advisory on wrapped and bounded maps."
)
