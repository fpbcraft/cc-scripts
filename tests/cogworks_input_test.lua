package.path = "./?.lua;./?/init.lua;" .. package.path
-- Exercise the real main.lua click dispatcher, not a duplicate button mapping.
local api = assert(loadfile("games/cogworks/main.lua"))("--test-api")
local E, App = api.engine, api.app
local boardAction = api.boardAction
assert(boardAction(1, "I", false) == "remove", "Left click removes")
assert(boardAction(2, "I", false) == "cell", "Right click builds or rotates")
assert(boardAction(2, "erase", false) == "remove", "Erase tool removes with either button")
assert(boardAction(nil, "I", true) == "inspect", "A buttonless monitor touch still builds / inspects")
assert(boardAction(1, "I", true) == "remove", "Monitor-window left click removes")
assert(boardAction(2, "I", true) == "inspect", "Monitor-window right click builds / inspects")
assert(boardAction(nil, "erase", true) == "remove", "Buttonless erase still removes")

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
app:act(boardAction(2, kind, false), x, y)
assert(E.get(game, x, y).kind == kind, "Computer right click places a part")
assert(game.remaining[kind] == initialStock - 1, "Placing a part consumes stock")
app:act(boardAction(1, kind, false), x, y)
assert(not E.get(game, x, y), "Computer left click removes the part")
assert(game.remaining[kind] == initialStock, "Removing a part restores stock")
app:act(boardAction(nil, kind, true), x, y)
assert(E.get(game, x, y).kind == kind, "Monitor touch places a part")
app.selected = "erase"
app:act(boardAction(nil, "erase", true), x, y)
assert(not E.get(game, x, y), "Monitor touch with erase selected removes a part")
print("COGWORKS: right-click placement, left-click removal, touch placement and erase controls passed.")
