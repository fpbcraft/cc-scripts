package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local R = require("games.cogworks.render")
local display = { pw = 720, ph = 520, updates = {} }
function display.getSize(mode)
  if mode == 2 then
    return display.pw, display.ph
  end
  return 120, 65
end
function display.setGraphicsMode() end
function display.setPaletteColor() end
function display.drawPixels(x, y, data, w, h)
  assert(x >= 0 and y >= 0 and x + w <= display.pw and y + h <= display.ph)
  display.updates[#display.updates + 1] = { x = x, y = y, w = w, h = h }
end
local r = R.new(display)
local function count(x1, y1, x2, y2)
  local n = 0
  for y = y1, y2 do
    for x = x1, x2 do
      if (r.buffer[y + 1] or {})[x + 1] then
        n = n + 1
      end
    end
  end
  return n
end
local function glyph(kind, rotation, spin)
  r.buffer = {}
  r.motionOverride = 0
  r:piece(10, 10, 32, { kind = kind, r = rotation }, spin)
  local rows = {}
  for y = 11, 42 do
    local row = {}
    for x = 11, 42 do
      row[#row + 1] = string.char(((r.buffer[y] or {})[x] or 0) + 65)
    end
    rows[#rows + 1] = table.concat(row)
  end
  return table.concat(rows, "\n")
end
local smallX = glyph("G", 1)
-- A horizontal shaft crosses the tile, with the edge-on cog rising vertically.
assert(count(22, 12, 30, 17) > 10, "The sideways cog has wood above its hub")
assert((r.buffer[14] or {})[27] ~= nil, "Wooden cog edge spans the shaft")
local smallY = glyph("G", 0)
assert(smallX ~= smallY, "Sideways cog rotates 90 degrees with its shaft")
local top = glyph("O", 1)
assert(top ~= smallX, "Large and small gears retain different silhouettes")
local variants = {}
for _, kind in ipairs({ "Q", "C", "Z", "D" }) do
  variants[kind] = glyph(kind, 1)
  assert(glyph(kind, 1) ~= glyph(kind, 0), "Top texture respects direction: " .. kind)
end
for a, pixels in pairs(variants) do
  for b, other in pairs(variants) do
    if a ~= b then
      assert(pixels ~= other, a .. " and " .. b .. " must have distinct top textures")
    end
  end
end
local on = { powered = true, ports = { [1] = { rate = 1, sign = 1 } }, redstone = true }
r.motionOverride = 0
local still = glyph("G", 1, on)
r.motionOverride = 0.25
r.buffer = {}
r:piece(10, 10, 32, { kind = "G", r = 1 }, on)
local moving = {}
for y = 11, 42 do
  for x = 11, 42 do
    moving[#moving + 1] = string.char(((r.buffer[y] or {})[x] or 0) + 65)
  end
end
assert(still:gsub("\n", "") ~= table.concat(moving), "Side cog teeth animate at subsecond intervals")
local model = {
  scene = "game",
  game = E.sandbox(5, 5),
  selected = "G",
  inspected = nil,
  result = nil,
  message = "",
  settings = { animations = false, showPorts = false },
  progress = { awards = {}, best = {}, unlocked = 1 },
  slots = {},
}
model.result = E.evaluate(model.game)
r.motionOverride = nil
r:draw(model)
assert(r.baseBuffer and r.previousBuffer, "Full frame exposes cached unmodified background")
local base = r.baseBuffer
local tx = r.boardX + 2 * r.cell
local ty = r.boardY + 2 * r.cell
local function move(x, y)
  model.drag = {
    origin = "inventory",
    kind = "G",
    r = 1,
    moved = true,
    valid = true,
    cursorX = x,
    cursorY = y,
    offsetX = r.cell / 2,
    offsetY = r.cell / 2,
    targetX = 3,
    targetY = 3,
  }
  r:drawDragPreview(model)
  assert(r.baseBuffer == base, "Pointer update must reuse board instead of rebuilding scene")
end
move(tx + r.cell / 2, ty + r.cell / 2)
move(tx + r.cell / 2 + 4, ty + r.cell / 2 + 3)
local last = display.updates[#display.updates]
assert(last and last.w * last.h < display.pw * display.ph / 4, "Drag sends a small damage region")
assert(#display.updates >= 2, "Moved preview uploads a changed region")
print(
  "COGWORKS: edge-on cogs, directional top textures, animated teeth and cached small-region pointer painting passed."
)
