local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Renderer = native("games/civcraft/render.lua")
local uploads = 0
local monitor = {
	getSize = function(mode)
		if mode == 2 then
			return 240, 180
		end
		return 40, 20
	end,
	setGraphicsMode = function() end,
	getPaletteColor = function()
		return 0, 0, 0
	end,
	setPaletteColor = function() end,
	drawPixels = function()
		uploads = uploads + 1
	end,
}
local full = Renderer.new(monitor)
local layout = Renderer.new(monitor, { layoutOnly = true })
assert(layout.mode == full.mode and layout.w == full.w and layout.h == full.h)
assert(layout:textWidth("HELLO") == full:textWidth("HELLO"))
local selected = false
layout:begin()
layout:fill(0, 0, layout.w, layout.h, 0)
layout:text(4, 4, "HELLO", 7)
layout:icon("station", 5, 5, 1)
layout:line(0, 0, 40, 30, 8)
layout:blit({ string.char(2, 2) }, 0, 0)
layout:button(4, 5, 48, 12, "SELECT", function()
	selected = true
end)
assert(layout.buffer == nil and layout.textBuffer == nil)
assert(#layout.buttons == 1 and layout.buttons[1].label == "SELECT")
assert(layout:hit(10, 10) == "SELECT" and selected)
layout:finish()
assert(uploads == 0, "Layout-only renderer cannot upload pixels")
full:begin()
full:fill(0, 0, full.w, full.h, 0)
full:button(4, 5, 48, 12, "SELECT", function() end)
full:finish()
assert(#full.buttons == 1 and uploads == 1)
assert(full.buttons[1].x == layout.buttons[1].x)
assert(full.buttons[1].w == layout.buttons[1].w)
print("CIVCRAFT: layout-only buttons, geometry and hit tests match the full renderer.")

-- Use the same module cache as the installed game for the integration fixture.
native("games/civcraft/module_cache.lua").install(_G)
-- Tile visibility must not shadow animation actor identities in layout maps.
local Map = dofile("/games/civcraft/map_view.lua")
local World = dofile("/games/civcraft/world.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local UI = dofile("/games/civcraft/ui.lua")
local world = World.generate(75123, "compact", 2, "continents")
local start = world.starts[1]
local state = {
	phase = "game",
	round = 1,
	world = world,
	players = { { id = 1, name = "ONE", techs = {}, civ = "verdant" } },
	cities = {
		{
			id = 7,
			owner = 1,
			name = "TEST",
			x = start.x,
			y = start.y,
			population = 2,
			jobs = { food = 1, wood = 1, science = 0 },
			buildings = {},
		},
	},
	units = {},
}
Systems.migrate(state)
World.reveal(state, Hex, Systems)
local ui = UI.new(monitor, function() end, { layoutOnly = true })
ui.playerID = 1
local names = 0
local drawText = ui.r.text
ui.r.text = function(self, x, y, value, ...)
	if value == "TEST" then
		names = names + 1
	end
	return drawText(self, x, y, value, ...)
end
local function drawMap(hidden)
	ui.animationFrame = { hidden = hidden, effects = {}, sprites = {} }
	ui.hexTargets = {}
	ui.r:begin()
	Map.draw(ui, state, state.players[1], { x = 0, y = 0, w = 240, h = 180 })
	ui.r:finish()
end
drawMap({})
assert(names > 0, "Visible city label survives layout-only rendering")
names = 0
local hiddenActors = { ["city:7"] = true }
drawMap(hiddenActors)
assert(names == 0, "Animated hidden city has no duplicate layout label")
assert(hiddenActors["city:7"], "Layout rendering preserves animation identities")
print("CIVCRAFT: layout-only city labels respect hidden animation actors.")
