-- Render-and-hit-test smoke checks for the real shared Canvas.
package.loaded.sim = dofile("games/wormfront/sim.lua")
local Sim = package.loaded.sim
local UI = dofile("games/wormfront/ui.lua")

local function screen(width, height, graphics)
  local m = { width = width, height = height, frames = 0, colors = {} }
  function m.getSize(mode)
    if mode == 2 then
      return width * 3, height * 4
    end
    return width, height
  end
  function m.setGraphicsMode(mode)
    if graphics then
      m.graphicsMode = mode
    else
      error("No graphics")
    end
  end
  function m.drawPixels()
    m.frames = m.frames + 1
  end
  function m.setPaletteColor(index, ...)
    m.colors[index] = { ... }
  end
  function m.getPaletteColor()
    return 0.2, 0.3, 0.4
  end
  function m.setFrozen() end
  function m.setBackgroundColor() end
  function m.setTextColor() end
  function m.setCursorPos() end
  function m.write() end
  return m
end

for _, dimension in ipairs({ { 42, 34 }, { 70, 46 }, { 90, 64 } }) do
  local m = screen(dimension[1], dimension[2], true)
  local actions = {}
  local ui = UI.new(m, function(action)
    actions[#actions + 1] = action
  end)
  local g = Sim.new(2, 99)
  ui:draw(g, { role = "local" })
  assert(ui.r.mode == "graphics" and m.frames > 0, "Expected rendered graphics")
  local fire
  for _, b in ipairs(ui.r.buttons) do
    if b.label == "CHARGE" then
      fire = b
    end
  end
  assert(fire, "Charge control must be visible")
  local x = ui.r.ox + (fire.x + fire.w / 2) * ui.r.sx
  local y = ui.r.oy + (fire.y + fire.h / 2) * ui.r.sy
  ui:touch(x, y)
  assert(actions[#actions].kind == "fire", "Touch must activate charge/release")
  -- Tapping the playfield changes barrel angle through an authenticated action.
  local b = ui.board
  local targetX = b.x + (Sim.W - 2) * b.scale
  local targetY = b.y + 2 * b.scale
  ui:touch(ui.r.ox + targetX * ui.r.sx, ui.r.oy + targetY * ui.r.sy)
  assert(actions[#actions].kind == "setAim", "Board tap should aim the barrel")
  ui:draw(g, { role = "join", slot = 2 })
  for _, b in ipairs(ui.r.buttons) do
    assert(b.label == "EXIT", "Off-turn controls must be inactive")
  end
  ui:draw(nil, { role = "host", count = 2, hostId = 42 })
  assert(#ui.r.buttons == 2, "Lobby must offer START and EXIT")
  ui:resize()
  ui:close()
end

print("WORMFRONT graphics, lobby, turn ownership and monitor touches: OK")
