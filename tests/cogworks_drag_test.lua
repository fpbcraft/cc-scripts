package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local App = require("games.cogworks.app")
local R = require("games.cogworks.render")
local P = require("games.cogworks.pointer")
local function monitor(w, h)
  return {
    getSize = function(mode)
      return mode == 2 and w or 100, mode == 2 and h or 55
    end,
    setGraphicsMode = function() end,
    setPaletteColor = function() end,
    drawPixels = function() end,
  }
end
local function setup()
  local g = E.new(4)
  local app = setmetatable({
    game = g,
    result = E.evaluate(g),
    scene = "game",
    devSession = true,
    progress = { best = {}, awards = {} },
    selected = "G",
    message = "",
    settings = { animations = false, showPorts = true },
  }, App)
  local renderer = R.new(monitor(700, 600))
  renderer:draw(app)
  return app, renderer
end
local function screen(renderer, x, y, fx, fy)
  return (renderer.boardX + (x - 1 + (fx or 0.5)) * renderer.cell) * renderer.scale,
    (renderer.boardY + (y - 1 + (fy or 0.5)) * renderer.cell) * renderer.scale
end
local app, renderer = setup()
assert(E.place(app.game, 2, 3, "G", 1))
app.result = E.evaluate(app.game)
renderer:draw(app)
local sx, sy = screen(renderer, 2, 3)
local drag = assert(P.begin(app.game, renderer, 2, "cell", 2, 3, sx, sy, "I"))
local moves, stock = app.game.moves, app.game.remaining.G
local px, py = screen(renderer, 4, 5, 0.27, 0.61)
app.drag = P.update(drag, app.game, renderer, px, py)
assert(drag.moved and drag.valid and drag.r == 1)
assert(math.abs(drag.cursorX - px / renderer.scale) < 0.001, "Ghost follows raw cursor rather than snapping")
renderer:draw(app)
assert(E.get(app.game, 2, 3) and not E.get(app.game, 4, 5), "Preview cannot move the live component")
assert(app.game.moves == moves and app.game.remaining.G == stock)
assert(app:dropDrag(4, 5))
assert(not E.get(app.game, 2, 3) and E.get(app.game, 4, 5).r == 1)
assert(app.game.moves == moves + 1 and app.game.remaining.G == stock, "Moving preserves stock and costs one move")

local function palette(kind)
  renderer:draw(app)
  for _, target in ipairs(renderer.targets) do
    if target.action == "tool" and target.arg == kind then
      return (target.x + target.w / 2) * renderer.scale, (target.y + target.h / 2) * renderer.scale
    end
  end
  error("No palette tool")
end
px, py = palette("I")
drag = assert(P.begin(app.game, renderer, 1, "tool", "I", nil, px, py, "I"))
local before = app.game.remaining.I
local dx, dy = screen(renderer, 2, 5)
app.drag = P.update(drag, app.game, renderer, dx, dy)
assert(drag.valid and app.game.remaining.I == before)
renderer:draw(app)
assert(app:dropDrag(2, 5) and app.game.remaining.I == before - 1, "Inventory consumes only on drop")

for _, target in ipairs({ { 4, 5 }, { 1, 3 }, { 0, 0 } }) do
  px, py = palette("I")
  drag = P.begin(app.game, renderer, 2, "tool", "I", nil, px, py, "I")
  dx, dy = screen(renderer, target[1], target[2])
  app.drag = P.update(drag, app.game, renderer, dx, dy)
  local unchangedMoves, unchangedStock = app.game.moves, app.game.remaining.I
  assert(not drag.valid and not app:dropDrag(drag.targetX, drag.targetY))
  assert(app.game.moves == unchangedMoves and app.game.remaining.I == unchangedStock, "Invalid drop is atomic")
end
px, py = screen(renderer, 1, 3)
assert(not P.begin(app.game, renderer, 2, "cell", 1, 3, px, py, "I"), "Fixed machinery cannot be lifted")
px, py = screen(renderer, 4, 5)
assert(not P.begin(app.game, renderer, 1, "cell", 4, 5, px, py, "I"), "Left button is reserved for removal")
local finger = assert(P.begin(app.game, renderer, 1, "cell", 4, 5, px, py, "I", true))
assert(
  finger.touch and finger.button == 1 and finger.origin == "board",
  "Finger press can drag while retaining its button ID"
)
P.update(finger, app.game, renderer, sx, sy)
assert(finger.moved, "Native touch motion updates a drag preview")
app.game.remaining.O = 0
px, py = palette("O")
drag = P.begin(app.game, renderer, 1, "tool", "O", nil, px, py, "O")
dx, dy = screen(renderer, 2, 6)
app.drag = P.update(drag, app.game, renderer, dx, dy)
assert(not drag.valid and not app:dropDrag(drag.targetX, drag.targetY), "Empty stock cannot be dragged into existence")

-- The preview also supports redstone without a real tile ID or grid position.
app.game.remaining.R = 2
px, py = palette("R")
drag = P.begin(app.game, renderer, 1, "tool", "R", nil, px, py, "R")
dx, dy = screen(renderer, 3, 5)
app.drag = P.update(drag, app.game, renderer, dx, dy)
renderer:draw(app)
assert(app:dropDrag(3, 5) and E.get(app.game, 3, 5).kind == "R")
print(
  "COGWORKS: cursor-following previews, stock reservation, preserved rotation, fixed parts and atomic invalid drops passed."
)
