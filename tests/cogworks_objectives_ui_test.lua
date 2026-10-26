package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local R = require("games.cogworks.render")
local function graphics(width, height)
  local monitor = {}
  function monitor.getSize(mode)
    return mode == 2 and width * 3 or width, mode == 2 and height * 4 or height
  end
  function monitor.setGraphicsMode() end
  function monitor.setPaletteColor() end
  function monitor.drawPixels() end
  return monitor
end
local function model(number)
  local game = E.new(number)
  return {
    scene = "game",
    game = game,
    result = E.evaluate(game),
    settings = { animations = false, showPorts = true },
    selected = "I",
    progress = { best = {}, awards = {} },
    message = "",
  }
end
local function assertInspection(renderer, id)
  for _, target in ipairs(renderer.targets) do
    if target.action == "inspectBonus" and target.arg == id then
      local x, y = target.x + target.w / 2, target.y + target.h / 2
      if renderer.mode == "graphics" then
        x, y = renderer.ox + x * renderer.scale, renderer.oy + y * renderer.scale
      end
      local action, value = renderer:hit(x, y)
      assert(action == "inspectBonus" and value == id)
      return target
    end
  end
  error("Objective has no inspection hit target: " .. id)
end
for _, size in ipairs({ { 70, 40 }, { 115, 65 } }) do
  local renderer = R.new(graphics(size[1], size[2]))
  local m = model(4)
  renderer:draw(m)
  assertInspection(renderer, "extra1")
  assertInspection(renderer, "extra2")
  local index, color = renderer:bonusMark(m.game, 4, 3)
  assert(index == 1 and color == 6, "Authored clear-cell objective is marked")
  assert(not renderer:bonusMark(m.game, 2, 2), "Unrelated cells stay uncluttered")
  local px = renderer.boardX + 3 * renderer.cell
  local py = renderer.boardY + 2 * renderer.cell
  assert(renderer.buffer[py + 1][px + 1] == 6, "Marker survives drawing occupied machinery")
  assert(renderer:bonusMark(E.sandbox(), 4, 3) == nil)
  renderer:close()
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
  brown = 4096,
}
local text = { x = 1, y = 1, rows = {} }
function text.getSize()
  return 70, 40
end
function text.setBackgroundColor() end
function text.setTextColor() end
function text.setCursorPos(x, y)
  assert(x >= 1 and x <= 70 and y >= 1 and y <= 40)
  text.x, text.y = x, y
end
function text.clear()
  text.rows = {}
end
function text.write(value)
  text.rows[text.y] = (text.rows[text.y] or "") .. value
end
local renderer = R.new(text)
local m = model(62)
m.game.height = 10 -- Maximum supported workshop height.
renderer:draw(m)
local objective = assertInspection(renderer, "extra1")
local lastCell, firstTool
for _, target in ipairs(renderer.targets) do
  if target.action == "cell" then
    lastCell = math.max(lastCell or 0, target.y + target.h - 1)
  elseif target.action == "tool" then
    firstTool = math.min(firstTool or 40, target.y)
  end
end
assert(
  lastCell < objective.y and objective.y < firstTool,
  "Tall text boards keep machinery, objectives and tools separate"
)
m = model(5)
renderer:draw(m)
assertInspection(renderer, "extra1")
assertInspection(renderer, "extra2")
assert(renderer:bonusMark(m.game, 3, 4) == 1, "Useful mount has an explicit text mark")
print("COGWORKS: compact/wide objective hit targets, occupied-cell outlines, mount marks and tall text layout passed.")
