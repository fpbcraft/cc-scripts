local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
native("games/civcraft/module_cache.lua").install(_G)
local UI = dofile("/games/civcraft/ui.lua")
local World = dofile("/games/civcraft/world.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Actions = dofile("/games/civcraft/unit_actions.lua")
local Render = dofile("/games/civcraft/render.lua")
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

local function monitor(width, height, graphics)
	local m = {}
	function m.getSize(mode)
		if mode == 2 then
			return width * 6, height * 9
		end
		return width, height
	end
	function m.getPaletteColor()
		return 0, 0, 0
	end
	function m.setPaletteColor() end
	if graphics then
		function m.setGraphicsMode() end
		function m.drawPixels() end
	else
		function m.setCursorPos() end
		function m.setBackgroundColor() end
		function m.setTextColor() end
		function m.write() end
	end
	return m
end

local function layout(width, height, graphics, expectIconsOnly)
	local ui = UI.new(monitor(width, height, graphics), function() end, { layoutOnly = true })
	ui:draw(state, 1)
	ui:focus("unit", state.units[1])
	ui:draw(state, 1)
	local expected = {
		["MOVE / ATTACK"] = "right",
		["QUEUE MOVES"] = "map",
		["SKIP TURN"] = "clock",
		["SLEEP UNIT"] = "pause",
		["FORTIFY / HEAL"] = "shield",
		["DISBAND"] = "danger",
		["DESELECT"] = "minus",
	}
	local byLabel = {}
	for page = 1, 15 do
		local visibleActions = {}
		for _, button in ipairs(ui.r.buttons) do
			if expected[button.label] then
				assert(
					not visibleActions[button.label],
					"Action is drawn once per page: " .. button.label
				)
				visibleActions[button.label] = true
				byLabel[button.label] = button
			end
		end
		local nextPage
		for _, button in ipairs(ui.r.buttons) do
			if
				button.label == "NEXT"
				and button.x >= ui.inspectorBounds.x
				and button.y >= ui.inspectorBounds.y
			then
				nextPage = button
				break
			end
		end
		if not nextPage then
			break
		end
		local previousOffset = ui.inspectorOffset
		nextPage.fn()
		if ui.inspectorOffset == previousOffset then
			break
		end
		ui:draw(state, 1)
	end
	for _, label in ipairs({
		"MOVE / ATTACK",
		"QUEUE MOVES",
		"SKIP TURN",
		"SLEEP UNIT",
		"FORTIFY / HEAL",
		"DISBAND",
		"DESELECT",
	}) do
		local button = assert(byLabel[label], "Visible unit action retains label: " .. label)
		assert(
			button.help and button.icon == expected[label],
			"Action retains its icon and help: " .. label
		)
		assert(type(button.fn) == "function", "Action remains reachable: " .. label)
		assert(button.iconOnly == expectIconsOnly, "Responsive text/icon mode: " .. label)
		if expectIconsOnly then
			assert(
				button.displayLabel == label,
				"Icon-only presentation keeps descriptive metadata"
			)
		else
			assert(button.displayLabel ~= label, "Wide presentation uses compact visible text")
		end
	end
	local sample = {}
	for label in pairs(expected) do
		sample[#sample + 1] = Actions.decorate({ label = label, run = function() end })
	end
	local columns = Actions.columns(ui.inspectorBounds.w - 6)
	local grouped =
		Actions.expand({ { unitActions = true, buttons = sample } }, ui.inspectorBounds.w - 6)
	assert(#grouped == math.ceil(#sample / columns), "Actions are packed into responsive rows")
	local logicalCounts = {}
	for _, row in ipairs(grouped) do
		for _, button in ipairs(row.actionButtons) do
			logicalCounts[button.label] = (logicalCounts[button.label] or 0) + 1
		end
	end
	for label in pairs(expected) do
		assert(logicalCounts[label] == 1, "Each logical action is assigned once: " .. label)
	end
	ui.inspectorOffset = 0
	ui:draw(state, 1)
	local function findVisible(label)
		ui.inspectorOffset = 0
		for _ = 1, 15 do
			ui:draw(state, 1)
			for _, button in ipairs(ui.r.buttons) do
				if button.label == label then
					return button
				end
			end
			local nextPage
			for _, button in ipairs(ui.r.buttons) do
				if
					button.label == "NEXT"
					and button.x >= ui.inspectorBounds.x
					and button.y >= ui.inspectorBounds.y
				then
					nextPage = button
					break
				end
			end
			if not nextPage then
				break
			end
			local previousOffset = ui.inspectorOffset
			nextPage.fn()
			if ui.inspectorOffset == previousOffset then
				break
			end
		end
	end
	local move = assert(findVisible("MOVE / ATTACK"), "Move action is reachable")
	move.fn()
	assert(ui.source and ui.source.unitID == state.units[1].id, "Move callback is unchanged")
	local cancel = assert(findVisible("CANCEL MOVE"), "Move mode exposes its cancel action")
	cancel.fn()
	assert(not ui.source, "Cancel callback leaves movement unarmed")
end

local contextIcons = {
	["ATTACH ESCORT"] = "plus",
	["DETACH ESCORT"] = "minus",
	["ADD WAYPOINT"] = "plus",
	["CANCEL ROUTE"] = "back",
	["FOUND CITY"] = "station",
	["FOUND CAPITAL"] = "star",
	["BUILD RAIL (2 IRON)"] = "train",
	["CANCEL WORK"] = "wrench",
	["RESUME WORK"] = "right",
	["SLEEP UNIT"] = "pause",
	["STOP EXPLORING"] = "back",
	["CANCEL MOVE"] = "minus",
}
for label, icon in pairs(contextIcons) do
	local button = Actions.decorate({ label = label, run = function() end })
	assert(
		button.icon == icon and button.shortLabel and button.help,
		"Context action icon and metadata: " .. label
	)
end

local workActions = {
	["PLAN WHEAT FIELD"] = { icon = "food", stage = "plan" },
	["WHEAT FIELD HERE"] = { icon = "food", stage = "here" },
	["PLAN QUARRY"] = { icon = "ore", stage = "plan" },
	["QUARRY HERE"] = { icon = "ore", stage = "here" },
	["PLAN LUMBER CAMP"] = { icon = "wood", stage = "plan" },
	["LUMBER CAMP HERE"] = { icon = "wood", stage = "here" },
}
local workButtons = {}
for label, expected in pairs(workActions) do
	local button = Actions.decorate({ label = label, run = function() end })
	assert(
		button.icon == expected.icon,
		"Builder action uses a distinct improvement glyph: " .. label
	)
	assert(button.workAction == expected.stage, "Builder action exposes its stage: " .. label)
	assert(
		button.shortLabel == expected.stage:upper(),
		"Builder action keeps a wide-layout label: " .. label
	)
	assert(
		button.help and button.help ~= label,
		"Builder help describes the tile action: " .. label
	)
	workButtons[label] = button
end

local drawnPixels = {}
local pixelMonitor = monitor(100, 30, true)
pixelMonitor.drawPixels = function(x, y, color, width, height)
	drawnPixels[#drawnPixels + 1] = table.concat({ x, y, color, width, height }, ",")
end
local raster = Render.new(pixelMonitor)
local function buttonRaster(button)
	drawnPixels = {}
	Actions.draw(raster, { x = 0, y = 0, w = 30 }, {
		columns = 1,
		showLabels = false,
		actionButtons = { button },
	}, 0)
	return table.concat(drawnPixels, ";")
end
local function actionRaster(label)
	return buttonRaster(workButtons[label])
end
local rasterByLabel = {}
for label in pairs(workActions) do
	rasterByLabel[label] = actionRaster(label)
	assert(rasterByLabel[label] ~= "", "Compact work action paints real pixels: " .. label)
end
for _, label in ipairs({ "PLAN WHEAT FIELD", "PLAN QUARRY", "PLAN LUMBER CAMP" }) do
	for _, other in ipairs({ "PLAN WHEAT FIELD", "PLAN QUARRY", "PLAN LUMBER CAMP" }) do
		if label ~= other then
			assert(
				rasterByLabel[label] ~= rasterByLabel[other],
				"Work types look different on touch: " .. label
			)
		end
	end
end
for _, pair in ipairs({
	{ "PLAN WHEAT FIELD", "WHEAT FIELD HERE" },
	{ "PLAN QUARRY", "QUARRY HERE" },
	{ "PLAN LUMBER CAMP", "LUMBER CAMP HERE" },
}) do
	assert(
		rasterByLabel[pair[1]] ~= rasterByLabel[pair[2]],
		"Plan and HERE markers differ visually: " .. pair[1]
	)
end
for _, group in ipairs({
	{ "CANCEL ROUTE", "CANCEL WORK", "CANCEL MOVE" },
	{ "SLEEP UNIT", "STOP EXPLORING" },
	{ "QUEUE MOVES", "ADD WAYPOINT" },
	{ "FOUND CITY", "FOUND CAPITAL" },
	{ "WORK MODE: APPEND", "WORK MODE: REPLACE" },
}) do
	local seenRasters = {}
	for _, label in ipairs(group) do
		local button = Actions.decorate({ label = label, run = function() end })
		local signature = buttonRaster(button)
		assert(signature ~= "", "Compact action paints its glyph: " .. label)
		assert(not seenRasters[signature], "Context actions use distinct compact glyphs: " .. label)
		seenRasters[signature] = true
	end
end

layout(57, 38, false, true)
layout(140, 67, true, false)
print(
	"CIVCRAFT: inspector unit actions retain callbacks and descriptive labels across compact and wide layouts."
)
