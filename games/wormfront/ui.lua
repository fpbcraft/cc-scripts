-- Compact touchscreen / CraftOS-PC renderer for WORMFRONT.
local Canvas = require("lib.fpb.canvas")
local Sim = require("sim")
local UI = {}
UI.__index = UI
local teamColors = { 13, 10, 18, 11 }

function UI.new(monitor, dispatch)
  return setmetatable({ r = Canvas.new(monitor), dispatch = dispatch }, UI)
end

function UI:close()
  self.r:close()
end

function UI:resize()
  self.r:resize()
end

function UI:touch(x, y)
  local vx, vy = self.r:touch(x, y)
  if vx then
    return self.r:hit(vx, vy)
  end
  return false
end

local function buttons(r, items, y, height, usable)
  local gap = 2
  local width = math.floor((r.w - gap * (#items + 1)) / #items)
  for i, item in ipairs(items) do
    local x = gap + (i - 1) * (width + gap)
    r:button(x, y, width, height, item[1], usable and item[2] or nil, {
      primary = item[3],
    })
  end
end

local function drawBoard(r, g)
  local size = math.max(1, math.floor(math.min((r.w - 6) / Sim.W, (r.h - 51) / Sim.H)))
  local bx = math.floor((r.w - Sim.W * size) / 2)
  local by = 18 + math.floor(math.max(0, r.h - 50 - Sim.H * size) / 2)
  r:fill(bx, by, Sim.W * size, Sim.H * size, 19)
  for x = 1, Sim.W do
    local column = g.terrain[x]
    local start, oldColor = nil, nil
    for y = 1, Sim.H + 1 do
      local filled = y <= Sim.H and column:sub(y, y) == "#"
      local color = filled and (y == 1 or column:sub(y - 1, y - 1) == "." and 11 or 16) or nil
      if color ~= oldColor then
        if start then
          r:fill(bx + (x - 1) * size, by + (start - 1) * size, size, (y - start) * size, oldColor)
        end
        start = filled and y or nil
        oldColor = color
      end
    end
  end
  for _, worm in ipairs(g.worms) do
    if worm.hp > 0 then
      local px = bx + (worm.x - 1) * size
      local py = by + (worm.y - 1) * size
      local ww, hh = math.max(3, size * 2), math.max(4, size * 2)
      r:fill(px - math.floor(ww / 2), py - hh + size, ww, hh, teamColors[worm.team])
      r:fill(px, py - hh + size + 1, math.max(1, math.floor(size / 2)), 1, 7)
      local bar = math.max(3, ww + 2)
      r:fill(px - math.floor(bar / 2), py - hh - 2, bar, 1, 10)
      r:fill(px - math.floor(bar / 2), py - hh - 2, math.ceil(bar * worm.hp / 100), 1, 11)
      if g.selected[worm.team] then
        local selected = g.worms[g.selected[worm.team]] == worm
        if selected and worm.team == g.turn and g.phase == "playing" then
          r:outline(px - math.floor(ww / 2) - 1, py - hh + size - 1, ww + 2, hh + 2, 7)
        end
      end
    end
  end
  for i, p in ipairs(g.trace or {}) do
    if i % 2 == 0 and p.x >= 1 and p.x <= Sim.W and p.y >= 1 and p.y <= Sim.H then
      r:fill(bx + (p.x - 1) * size, by + (p.y - 1) * size, math.max(1, size), math.max(1, size), 8)
    end
  end
  if g.blast then
    local blast = g.blast
    local radius = blast.radius * size
    local x = bx + (blast.x - 1) * size
    local y = by + (blast.y - 1) * size
    r:outline(x - radius, y - radius, radius * 2, radius * 2, 31)
  end
  if g.phase == "playing" then
    local worm = Sim.worm(g)
    if worm then
      local x = bx + (worm.x - 1) * size
      local y = by + (worm.y - 1) * size
      local angle = math.rad(worm.aim)
      r:line(x, y - size, x + math.cos(angle) * 8 * size, y - size - math.sin(angle) * 8 * size, 7)
    end
  end
  r:outline(bx - 1, by - 1, Sim.W * size + 2, Sim.H * size + 2, 3)
end

function UI:draw(g, opts)
  opts = opts or {}
  local r = self.r
  r:begin()
  r:fill(0, 0, r.w, 16, 1)
  r:text(3, 2, "WORMFRONT", 8)
  if not g then
    local count = opts.count or 1
    r:center(math.floor(r.h * 0.3), "MULTIPLAYER ARTILLERY", 7)
    r:center(math.floor(r.h * 0.3) + 10, "PLAYERS " .. count .. "/4", 13)
    r:center(math.floor(r.h * 0.3) + 20, opts.status or "WAITING FOR PLAYERS", 6)
    if opts.role == "host" then
      r:center(math.floor(r.h * 0.3) + 30, "HOST ID " .. tostring(opts.hostId or "?"), 8)
      r:button(math.floor(r.w / 2) - 32, r.h - 30, 64, 16, "START", function()
        self.dispatch({ kind = "start" })
      end, { primary = true })
    end
    r:button(r.w - 46, r.h - 18, 44, 13, "EXIT", function()
      self.dispatch({ kind = "exit" })
    end)
    r:finish()
    return
  end
  local mine = opts.role == "local" or g.turn == opts.slot
  r:text(math.max(75, r.w - 94), 2, "TEAM " .. g.turn .. "  ROUND " .. g.round, 7, 1, 94)
  r:text(3, 10, "WIND " .. (g.wind > 0 and "+" or "") .. g.wind .. "  " .. g.message, 6, 1, r.w - 6)
  drawBoard(r, g)
  if g.phase == "finished" then
    r:fill(5, r.h - 27, r.w - 10, 26, 1)
    r:center(r.h - 23, g.message, 18)
    r:button(r.w - 52, r.h - 14, 49, 12, "EXIT", function()
      self.dispatch({ kind = "exit" })
    end)
  else
    local worm = Sim.worm(g)
    local y = r.h - 29
    local detail = worm and ("HP " .. worm.hp .. "   ANGLE " .. worm.aim .. "   POWER " .. worm.power
      .. "   " .. (worm.weapon == 2 and ("MEGA " .. worm.mega) or "ROCKET")
      .. "   STEPS " .. (4 - g.moves)) or ""
    r:fill(0, y - 10, r.w, 9, 1)
    r:text(3, y - 8, (mine and "YOUR TURN  " or "WAITING  ") .. detail, mine and 18 or 5, 1, r.w - 6)
    local function act(kind, dir)
      return function()
        self.dispatch({ kind = kind, dir = dir })
      end
    end
    buttons(r, {
      { "WORM", act("select") },
      { "LEFT", act("move", -1) },
      { "RIGHT", act("move", 1) },
      { "AIM -", act("aim", -1) },
      { "AIM +", act("aim", 1) },
    }, y, 12, mine)
    buttons(r, {
      { "PWR -", act("power", -1) },
      { "PWR +", act("power", 1) },
      { "WEAPON", act("weapon") },
      { "FIRE", act("fire"), true },
      { "EXIT", act("exit") },
    }, y + 14, 12, true)
  end
  r:finish()
end

return UI
