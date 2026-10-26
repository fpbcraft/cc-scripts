-- High-resolution Cogworks graphics and touch regression tests.
package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local C = require("games.cogworks.chapters")
local R = require("games.cogworks.render")
local B = require("games.cogworks.briefing")
local monitor = { cw = 115, ch = 65, pw = 920, ph = 650, mode = 0, uploads = 0, clears = 0 }
function monitor.getSize(mode)
  if mode == 2 then
    return monitor.pw, monitor.ph
  end
  return monitor.cw, monitor.ch
end
function monitor.setGraphicsMode(mode)
  monitor.mode = mode
end
function monitor.getPaletteColor()
  return 0, 0, 0
end
function monitor.setPaletteColor() end
function monitor.setFrozen() end
function monitor.drawPixels(x, y, data, w, h)
  assert(x >= 0 and y >= 0 and x + w <= monitor.pw and y + h <= monitor.ph)
  if type(data) == "table" then
    assert(#data == h and #data[1] == w, "Each pixel row fits the upload")
    monitor.uploads = monitor.uploads + 1
  else
    assert(data == 0, "Clear uses the blueprint background")
    monitor.clears = monitor.clears + 1
  end
end
local r = R.new(monitor)
assert(r.mode == "graphics" and r.wide)
assert(r.canvasW == 345 and r.canvasH == 260, "Canvas follows terminal resolution")
assert(r.ox >= 0 and r.scale > 1, "Responsive canvas fits the physical display")

local model = {
  scene = "briefing",
  game = E.new(4),
  progress = { best = {}, awards = {} },
  result = nil,
  selected = "I",
  message = "",
  settings = { animations = false, showPorts = true },
  slots = { { number = 1, empty = true }, { number = 2, empty = true }, { number = 3, empty = true } },
  chapters = C.chapters,
  levelChapter = 1,
  objectives = 0,
  catalogPage = 1,
  briefing = B.forLevel(4),
}
model.result = E.evaluate(model.game)
local function find(action, arg)
  for _, target in ipairs(r.targets) do
    if target.action == action and (arg == nil or target.arg == arg) then
      return target
    end
  end
  return nil
end
local function assertTap(action, arg)
  local target = assert(find(action, arg), "Missing action: " .. action)
  assert(target.x >= 0 and target.y >= 0 and target.x + target.w <= r.canvasW)
  assert(target.y + target.h <= r.canvasH, "Touch target fits the responsive canvas")
  local px = r.ox + (target.x + target.w / 2) * r.scale
  local py = r.oy + (target.y + target.h / 2) * r.scale
  local got, value = r:hit(px, py)
  assert(got == action and (arg == nil or arg == value), "Pixel hit maps to drawn action: " .. action)
  got, value = r:hitNormalized(px / r.pw, py / r.ph)
  assert(got == action and (arg == nil or arg == value), "Normalized touch matches: " .. action)
end
r:draw(model)
assertTap("beginLevel")
assert(r.canvasW > 200 and r.canvasH > 120 and monitor.uploads > 0, "Briefing fills larger raster")

model.scene = "game"
r:draw(model)
assertTap("tool", "I")
assertTap("tool", "G")
assertTap("pause")
assertTap("help")
assertTap("cell")
assert(r.boardX >= 4 and r.boardY >= 22, "The board reaches close to the new header")
local layout = r.currentGameLayout
assert(layout.board.w <= layout.board.h and layout.sidebar.w >= 100, "Board is square and extra width goes to sidebar")
assert(layout.grid.x >= layout.board.x and layout.grid.y >= layout.board.y, "Grid remains inside its board area")
assert(
  layout.sidebar.x - (layout.grid.x + layout.grid.w) < 26,
  "Grid no longer has a large empty right margin"
)
assert(layout.grid.y + layout.grid.h <= layout.board.y + layout.board.h, "Grid fits the playable height")
assert(layout.sidebar.x + layout.sidebar.w <= r.canvasW, "Sidebar fits screen")
local previousCell = r.cell
model.game = E.new(64, true)
model.result = E.evaluate(model.game)
model.selected = "G"
model.inspected = { x = 3, y = 3 }
r:draw(model)
assertTap("tool", "G")
model.inspected = nil
r:draw(model)

model.scene = "levels"
r:draw(model)
assertTap("chapter", 1)
assertTap("back")
model.scene = "chapter"
r:draw(model)
assertTap("level", 1)
assert(not find("level", 2), "Locked map node cannot be tapped")
model.scene = "pause"
r:draw(model)
assertTap("resume")
assertTap("levels")
model.scene = "settings"
r:draw(model)
assertTap("toggleAnimations")
model.scene = "title"
r:draw(model)
assertTap("slots")
assertTap("sandbox")
model.scene = "editorList"
model.editorFiles = { "test-level" }
r:draw(model)
assertTap("editorLoadFile", "test-level")
model.scene = "packList"
model.packFiles = { "test-pack" }
r:draw(model)
assertTap("pack", "test-pack")
model.scene = "packLevels"
model.activePack = { title = "TEST PACK", levels = { E.levels[1] } }
r:draw(model)
assertTap("packLevel", 1)
model.scene = "help"
r:draw(model)
assertTap("back")
model.scene = "confirm"
model.pending = "restart"
r:draw(model)
assertTap("confirm")
model.scene = "tutorial"
model.tutorial =
  { steps = { { key = "G", title = "COGWHEEL", lines = { "MESH THE RIMS", "REVERSE ROTATION" } } }, index = 1 }
r:draw(model)
assertTap("tutorialSkip")
assert(not find("cell"), "Tutorial must block board taps")
assert(previousCell >= 6)

-- Resizing recalculates both visual and interaction geometry.
monitor.cw, monitor.ch, monitor.pw, monitor.ph = 130, 70, 1040, 700
r:resize()
model.scene, model.game = "game", E.new(4)
model.result, model.tutorial = E.evaluate(model.game), nil
r:draw(model)
assert(r.canvasW == 390 and r.canvasH == 280)
assertTap("cell")
assertTap("tool", "I")
assert(monitor.clears >= 2, "A resize clears the entire display")
r:close()
assert(monitor.mode == 0, "Graphics mode restored on exit")
print("COGWORKS: full-resolution briefing, board, map, menus, editor, tutorial, touch and resize passed.")
