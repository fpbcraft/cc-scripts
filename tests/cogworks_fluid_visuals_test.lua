package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local R = require("games.cogworks.render")
local monitor = { pw = 800, ph = 850 }
function monitor.getSize(mode)
  return mode == 2 and monitor.pw or 70, mode == 2 and monitor.ph or 40
end
function monitor.setGraphicsMode() end
function monitor.setPaletteColor() end
function monitor.drawPixels(x, y, _, w, h)
  assert(x >= 0 and y >= 0 and x + w <= monitor.pw and y + h <= monitor.ph)
end
local renderer = R.new(monitor)
local dock, side = false, false
for _, shape in ipairs({ { 800, 850 }, { 1240, 830 }, { 1700, 500 }, { 600, 1200 }, { 400, 240 }, { 300, 180 } }) do
  monitor.pw, monitor.ph = shape[1], shape[2]
  renderer:resize()
  local game = E.new(4)
  renderer:draw({
    scene = "game",
    game = game,
    result = E.evaluate(game),
    selected = "I",
    settings = { animations = false, showPorts = false },
    progress = { awards = {} },
    message = "",
  })
  assert(renderer.ox == 0 and renderer.oy == 0)
  assert(
    renderer.canvasW * renderer.scale >= monitor.pw - 0.01 and renderer.canvasH * renderer.scale >= monitor.ph - 0.01
  )
  local layout = renderer.currentGameLayout
  dock, side = dock or layout.docked, side or not layout.docked
  assert(layout.grid.x >= 0 and layout.grid.y >= 0)
  assert(layout.grid.x + layout.grid.w <= renderer.canvasW and layout.grid.y + layout.grid.h <= renderer.canvasH)
  assert(
    layout.sidebar.x + layout.sidebar.w <= renderer.canvasW and layout.sidebar.y + layout.sidebar.h <= renderer.canvasH
  )
  for _, kind in ipairs(E.order) do
    local found = false
    for _, target in ipairs(renderer.targets) do
      if target.action == "tool" and target.arg == kind then
        found = true
        local action, value =
          renderer:hit((target.x + target.w / 2) * renderer.scale, (target.y + target.h / 2) * renderer.scale)
        assert(action == "tool" and value == kind)
      end
    end
    assert(found, "Every aspect ratio keeps every part selectable")
  end
end
assert(dock and side, "Inventory adapts between side and bottom arrangements")
monitor.pw, monitor.ph = 800, 850
renderer:resize()
local lit = { powered = true, ports = { [1] = { sign = 1, rate = 1 } } }
for _, size in ipairs({ 10, 13, 20, 32, 48 }) do
  for _, kind in ipairs({ "I", "G", "O", "Q", "D", "V", "C", "Z", "S", "M", "X" }) do
    renderer.buffer = {}
    renderer.motionOverride = 0
    renderer:piece(10, 10, size, { kind = kind, r = 1, speed = 1, sign = 1 }, lit)
    for y, row in pairs(renderer.buffer) do
      for x in pairs(row) do
        assert(x >= 11 and x <= 10 + size and y >= 11 and y <= 10 + size, "Sprite stays within its own tile")
      end
    end
    if kind == "I" or kind == "G" or kind == "O" or kind == "Q" then
      local left, right = false, false
      for _, row in pairs(renderer.buffer) do
        left, right = left or row[11] ~= nil, right or row[10 + size] ~= nil
      end
      assert(left and right, "Native part reaches both tile edges: " .. kind .. "/" .. size)
    end
  end
end
renderer.buffer = {}
renderer:fixedFrame(10, 10, 20, { fixed = true }, false)
assert(renderer.buffer[11][11] == 15 and renderer.buffer[30][30] == 6)
renderer.buffer = {}
renderer:fixedFrame(10, 10, 20, { fixed = false }, false)
assert(next(renderer.buffer) == nil, "Movable parts have no fixed frame")
print(
  "COGWORKS: portrait/landscape canvas coverage, adaptive inventory, full-tile sprite bounds and fixed-part frames passed."
)
