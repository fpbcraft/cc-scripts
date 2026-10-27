package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local A = require("games.cogworks.app")
local R = require("games.cogworks.render")

-- Shaft connections outrank side meshing and are selected automatically.
local g = E.sandbox(7, 7)
assert(E.place(g, 2, 3, "I"))
assert(E.get(g, 2, 3).r == 1, "New shaft faces the horizontal starter axle")
assert(E.connection(g, E.get(g, 2, 3), 3), "New shaft connects to source")
assert(E.place(g, 3, 3, "G"))
assert(E.get(g, 3, 3).r == 1, "Small gear automatically aligns its axle")
assert(E.place(g, 3, 4, "O"))
assert(E.get(g, 3, 4).r == 1, "Large gear defaults to compatible sideways meshing")

local vertical = E.sandbox(7, 7)
assert(E.place(vertical, 5, 2, "I", 0))
assert(E.place(vertical, 5, 3, "C"))
assert(E.get(vertical, 5, 3).r == 0, "Clutch lines up with vertical shaft")
assert(E.place(vertical, 5, 4, "Z"))
assert(E.get(vertical, 5, 4).r == 0, "Gearshift connects without extra rotation")
assert(E.place(vertical, 6, 3, "I", 0))
assert(E.get(vertical, 6, 3).r == 0, "Explicit player orientation overrides suggestion")
local belts = E.sandbox(7, 7)
assert(E.place(belts, 5, 2, "V", 1))
assert(E.place(belts, 5, 4, "V"))
assert(E.get(belts, 5, 4).r == 1, "Pulley matches an existing belt across empty cells")

-- A Move operation is a two-tap action. It preserves rotation, refuses
-- occupied destinations and can be cancelled by pressing Move again.
local app = setmetatable({
	scene = "game",
	game = g,
	result = E.evaluate(g),
	selected = "G",
	message = "",
	settings = { animations = false, showPorts = false },
	progress = { best = {}, awards = {}, unlocked = 1 },
	slots = {},
}, A)
local previousRotation = E.get(g, 2, 3).r
local originalMoves = g.moves
app:act("inspect", 2, 3)
app:act("moveStart", 2, 3)
assert(app.moving and app.moving.x == 2, "Move button arms the inspected part")
app:act("moveTo", 3, 3) -- occupied by the gear
assert(app.moving and E.get(g, 2, 3), "Occupied destination does not delete source")
app:act("moveTo", 4, 5)
assert(not app.moving and not E.get(g, 2, 3), "Valid destination moves, rather than copies")
assert(E.get(g, 4, 5).r == previousRotation, "Move preserves existing rotation")
assert(g.moves == originalMoves + 1, "Move counts as one move")
app:act("moveStart", 4, 5)
app:act("moveStart", 4, 5)
assert(not app.moving and E.get(g, 4, 5), "Move button toggles/cancels destination selection")
app:act("moveStart", 1, 3)
assert(not app.moving, "Fixed starter shaft cannot be moved")

-- The compact and wide renderer must both expose the new on-part target.
local monitor = { pw = 720, ph = 540 }
function monitor.getSize(mode)
	return mode == 2 and monitor.pw or 120, mode == 2 and monitor.ph or 60
end
function monitor.setGraphicsMode() end
function monitor.setPaletteColor() end
function monitor.drawPixels() end
local renderer = R.new(monitor)
app.scene = "game"
app.inspected = { x = 4, y = 5 }
local model = {
	scene = "game",
	game = app.game,
	result = app.result,
	selected = "I",
	inspected = app.inspected,
	moving = nil,
	message = "",
	settings = app.settings,
	progress = app.progress,
	slots = {},
}
renderer:draw(model)
local found = false
for _, hit in ipairs(renderer.targets) do
	if hit.action == "moveStart" and hit.arg == 4 and hit.arg2 == 5 then
		found = true
	end
end
assert(found, "Wide board exposes a Move button alongside Rotate and Delete")
renderer:close()
print("COGWORKS: auto-oriented shafts/gears/belts and two-tap Move control passed.")
