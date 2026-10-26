-- Drag state is a preview only. Inventory and simulation change on a valid drop.
local E = require("games.cogworks.engine")
local P = {}
function P.valid(g, drag, x, y)
  if not x or not y or not E.inside(x, y, g) then
    return false
  end
  local target = E.get(g, x, y)
  if drag.origin == "board" then
    local source = E.get(g, drag.fromX, drag.fromY)
    return source ~= nil
      and (not source.fixed or g.editor)
      and source.kind == drag.kind
      and source.r == drag.r
      and (not target or target == source)
  end
  return not target and (g.remaining[drag.kind] or 0) > 0
end
function P.begin(g, renderer, button, action, x, y, px, py, selected, touch)
  local cx, cy = renderer:toCanvas(px, py)
  local drag = { button = button, touch = touch == true, startX = cx, startY = cy, cursorX = cx, cursorY = cy, moved = false }
  if action == "tool" and E.parts[x] then
    drag.origin, drag.kind, drag.r = "inventory", x, 0
    drag.offsetX, drag.offsetY = renderer.cell / 2, renderer.cell / 2
  elseif action == "cell" and (button == 2 or touch) and selected ~= "erase" then
    local tile = E.get(g, x, y)
    if tile and tile.fixed and not g.editor then
      return nil
    end
    drag.origin = tile and "board" or "paint"
    drag.fromX, drag.fromY = x, y
    drag.kind, drag.r = tile and tile.kind or selected, tile and tile.r or 0
    drag.offsetX = cx - (renderer.boardX + (x - 1) * renderer.cell)
    drag.offsetY = cy - (renderer.boardY + (y - 1) * renderer.cell)
  else
    return nil
  end
  return drag
end
function P.update(drag, g, renderer, px, py)
  drag.cursorX, drag.cursorY = renderer:toCanvas(px, py)
  local dx, dy = drag.cursorX - drag.startX, drag.cursorY - drag.startY
  drag.moved = drag.moved or dx * dx + dy * dy >= 4
  drag.targetX, drag.targetY = renderer:boardCell(px, py)
  -- Inventory/paint previews show the same auto-alignment as a click-to-place.
  -- Board moves deliberately preserve the player's existing rotation.
  if drag.origin ~= "board" and drag.targetX and drag.targetY then
    drag.r = E.bestRotation(g, drag.targetX, drag.targetY, drag.kind)
  end
  drag.valid = P.valid(g, drag, drag.targetX, drag.targetY)
  return drag
end
return P
