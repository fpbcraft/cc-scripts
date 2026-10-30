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
local RenderUI = UI.new
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local Hex = dofile("games/civcraft/hex.lua")
local World = dofile("games/civcraft/world.lua")
local Systems = dofile("games/civcraft/systems.lua")
local Presentation = dofile("games/civcraft/presentation.lua")
local Suggestions = dofile("games/civcraft/settlement_suggestions.lua")
local SettlementView = dofile("games/civcraft/settlement_view.lua")
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
	assert(ui.settlementSuggestionCache.signature, "Advice cache uses observed contents")
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

for _, graphics in ipairs({ false, true }) do
	local state = fixture(true)
	local ui = UI.new(monitor(160, 100, graphics), function()
		error("Advice must not issue commands")
	end)
	ui.zoomLevel = 8
	local projected = drawSelected(ui, state)
	local selectedID = ui.selected.unitID
	if graphics then
		local copies, repeated = {}, false
		for _, target in ipairs(ui.settlementSuggestionTargets) do
			copies[target.index] = (copies[target.index] or 0) + 1
			repeated = repeated or copies[target.index] > 1
		end
		assert(repeated, "Wrapped visible copies retain recommendation icons")
	end
	local marker = assert(ui.settlementSuggestionTargets[1], "A recommendation icon is visible")
	assert(tap(ui, marker.x + marker.w / 2, marker.y + marker.h / 2))
	assert(ui.panel ~= "settlementSuggestions", "Icons never open a menu")
	assert(ui.selected.unitID == selectedID and ui.selected.kind == "unit")
	ui.panel = "inspector"
	ui:draw(projected, 1, { screen = "game" })
	for _, button in ipairs(ui.r.buttons) do
		assert(
			not (button.label or ""):find("SETTLEMENT SITES", 1, true),
			"No recommendation menu entry"
		)
	end
	local oldSignature = ui.settlementSuggestionCache.signature
	projected.world.tiles["20:8"] = "plains"
	projected.world.resources["20:8"] = "grain"
	ui:draw(projected, 1, { screen = "game" })
	assert(
		ui.settlementSuggestionCache.signature ~= oldSignature,
		"In-place revealed observations refresh icons"
	)
	local sites = ui.settlementSuggestions
	ui:draw(projected, 1, { screen = "game" })
	assert(
		ui.settlementSuggestions == sites,
		"Unchanged observations reuse evaluated recommendations"
	)
	assert(Systems.checkpoint == originalCheckpoint)
	ui:deselect()
	assert(
		not ui.settlementSuggestions and #ui.settlementSuggestionTargets == 0,
		"Deselection removes advice"
	)
	ui:close()
end
print("PASS: dynamic map-only settlement icons, selection and privacy")
