local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local M = {}
function M.draw(ui, state, player, rect)
  local r = ui.r
  local world = state.world
  local width, height = world and world.width or Hex.width, world and world.height or Hex.height
  r:fill(rect.x, rect.y, rect.w, rect.h, 15)
  local fullW = width + 0.5
  local fullH = (height - 1) * 0.75 + 1
  r:withClip(rect, function()
    for y = 1, height do
      for x = 1, width do
        local known = World.known(player, x, y)
        if known ~= "hidden" then
          local land = Hex.terrain(x, y, state)
          local color = known == "explored" and 14 or land == "water" and 19 or land == "mountain" and 4 or 12
          r:fill(
            rect.x + (x - 1 + (y - 1) % 2 * 0.5) * rect.w / fullW,
            rect.y + (y - 1) * 0.75 * rect.h / fullH,
            math.max(1, rect.w / fullW),
            math.max(1, rect.h / fullH),
            color
          )
        end
      end
    end
    for _, list in ipairs({ state.cities, state.units }) do
      for _, item in ipairs(list or {}) do
        if item.owner == ui.playerID or World.known(player, item.x, item.y) == "visible" then
          r:fill(
            rect.x + (item.x - 0.5) * rect.w / fullW,
            rect.y + ((item.y - 1) * 0.75 + 0.5) * rect.h / fullH,
            2,
            2,
            item.owner == ui.playerID and 8 or 10
          )
        end
      end
    end
    local v = ui.mapViewport
    r:outline(
      rect.x + ui.panX / (fullW * v.tile) * rect.w,
      rect.y + ui.panY / (fullH * v.tile) * rect.h,
      math.min(rect.w, v.w / (fullW * v.tile) * rect.w),
      math.min(rect.h, v.h / (fullH * v.tile) * rect.h),
      7
    )
  end)
  r:outline(rect.x, rect.y, rect.w, rect.h, 3)
  r.buttons[#r.buttons + 1] = {
    x = rect.x,
    y = rect.y,
    w = rect.w,
    h = rect.h,
    label = "MINIMAP",
    fn = function(x, y)
      if (ui.panel ~= "context" and ui.panel ~= "minimap") or ui.pendingMove then
        return
      end
      local v = ui.mapViewport
      ui.panX = math.max(0, math.min(v.maxX, (x - rect.x) / rect.w * fullW * v.tile - v.w / 2))
      ui.panY = math.max(0, math.min(v.maxY, (y - rect.y) / rect.h * fullH * v.tile - v.h / 2))
      if ui.panel == "minimap" then
        ui.panel = "context"
      end
    end,
  }
end
return M
