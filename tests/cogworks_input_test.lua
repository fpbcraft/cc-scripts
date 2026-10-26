package.path = "./?.lua;./?/init.lua;" .. package.path
-- Exercise the real main.lua click dispatcher, not a duplicate button mapping.
local api = assert(loadfile("games/cogworks/main.lua"))("--test-api")
local E, App = api.engine, api.app
local boardAction = api.boardAction
local pointerTransition = api.pointerTransition
-- iPad: a tap can send mouse_click with no matching mouse_up.
local pointer = pointerTransition(nil, "down", 1, 2, 3, "I")
assert(pointer and pointer.x == 2 and pointer.y == 3)
local action, px, py
pointer, action, px, py = pointerTransition(pointer, "timeout", nil, nil, nil, "I")
assert(pointer == nil and action == "cell" and px == 2 and py == 3,
  "Timer must commit mouse_click even when iPad omits mouse_up")
pointer, action = pointerTransition(pointer, "up", 1, 2, 3, "I")
assert(pointer == nil and action == nil, "Late release must not duplicate a tap")
pointer = pointerTransition(nil, "down", 2, 3, 4, "G")
pointer, action, px, py = pointerTransition(pointer, "up", 2, 3, 4, "G")
assert(pointer == nil and action == "remove" and px == 3 and py == 4,
  "Right-button mouse_up commits removal")
pointer = pointerTransition(nil, "down", 1, 2, 3, "G")
pointer = pointerTransition(pointer, "drag", 1, 4, 3, "G")
local _, fallback = pointerTransition(pointer, "timeout", nil, nil, nil, "G")
assert(fallback == nil, "Tap timeout cannot rotate a piece being dragged")
local destX, destY
pointer, action, px, py, destX, destY = pointerTransition(pointer, "up", 1, 4, 3, "G")
assert(pointer == nil and action == "move" and px == 2 and py == 3 and destX == 4 and destY == 3,
  "Drag must retain movement instead of rotating on pointer-down")
assert(boardAction(1, "I", false) == "cell", "Left mouse button must place / rotate")
assert(boardAction(2, "I", false) == "remove", "Right mouse button must remove")
assert(boardAction(1, "erase", false) == "remove", "Erase tool removes with left mouse button")
assert(boardAction(nil, "I", true) == "inspect", "Touch on empty cell should place")
assert(boardAction(1, "I", true) == "inspect", "Windowed monitor left click should place")
assert(boardAction(2, "I", true) == "remove", "Windowed monitor right click should remove")
assert(boardAction(nil, "erase", true) == "remove", "Touch erase mode must remove")

local game = E.new(1)
local kind
for _, part in ipairs(E.order) do
  if (game.remaining[part] or 0) > 0 then
    kind = part
    break
  end
end
assert(kind, "First mission should have at least one placeable component")
local x, y
for row = 1, game.height do
  for col = 1, game.width do
    if not E.get(game, col, row) then
      x, y = col, row
      break
    end
  end
  if x then
    break
  end
end
assert(x and y, "First mission needs a buildable cell")
-- Drive the public game controller through each input pathway.
-- Developer mode avoids saving files, without changing any build rules.
local app = setmetatable({
  scene = "game",
  game = game,
  result = E.evaluate(game),
  progress = { best = {}, awards = {} },
  selected = kind,
  message = "",
  devSession = true,
}, App)
local initialStock = game.remaining[kind]
app:act(boardAction(1, kind, false), x, y)
assert(E.get(game, x, y).kind == kind, "Computer left click places a part")
assert(game.remaining[kind] == initialStock - 1, "Placing a part consumes stock")
app:act(boardAction(2, kind, false), x, y)
assert(not E.get(game, x, y), "Computer right click removes the part")
assert(game.remaining[kind] == initialStock, "Removing a part restores stock")
app:act(boardAction(nil, kind, true), x, y)
assert(E.get(game, x, y).kind == kind, "Monitor touch places a part")
app.selected = "erase"
app:act(boardAction(nil, "erase", true), x, y)
assert(not E.get(game, x, y), "Monitor touch with erase selected removes a part")
print("COGWORKS: left-click placement, right-click removal, touch placement and erase controls passed.")
