-- Pixel-art artillery battlefield. View coordinates are scaled by FPB Canvas.
local Canvas = require("lib.fpb.canvas")
local Sim = require("sim")
local UI = {}
UI.__index = UI
local teamColors = { 13, 31, 18, 11 }
local themes = {
  { sky = 19, far = 3, dirt = 16, stone = 17, grass = 11, cloud = 24 },
  { sky = 20, far = 25, dirt = 9, stone = 26, grass = 8, cloud = 30 },
  { sky = 23, far = 20, dirt = 17, stone = 27, grass = 13, cloud = 24 },
  { sky = 25, far = 12, dirt = 26, stone = 17, grass = 28, cloud = 6 },
}

function UI.new(monitor, dispatch)
  return setmetatable({ r = Canvas.new(monitor), dispatch = dispatch, board = nil }, UI)
end
function UI:close()
  self.r:close()
end
function UI:resize()
  self.r:resize()
end
local function rect(r, x, y, width, height, c)
  r:fill(math.floor(x), math.floor(y), width, height, c)
end
local function dot(r, x, y, radius, c)
  for dy = -radius, radius do
    local dx = math.floor(math.sqrt(math.max(0, radius * radius - dy * dy)))
    rect(r, x - dx, y + dy, dx * 2 + 1, 1, c)
  end
end

local function buttonRow(r, items, y, enabled)
  local gap, height = 2, 13
  local width = math.floor((r.w - gap * (#items + 1)) / #items)
  for i, item in ipairs(items) do
    local x = gap + (i - 1) * (width + gap)
    r:button(x, y, width, height, item[1], (enabled or item[4]) and item[2] or nil, {
      primary = item[3] and enabled,
    })
  end
end

local function scene(r, g, b, frame)
  local palette = themes[g.theme or 1]
  local x0, y0, scale = b.x, b.y, b.scale
  local width, height = Sim.W * scale, Sim.H * scale
  r:fill(x0, y0, width, height, palette.sky)
  -- Atmospheric horizon layers; no bitmap assets or non-ComputerCraft colors.
  r:fill(x0, y0 + math.floor(height * 0.63), width, math.ceil(height * 0.37), palette.far)
  dot(r, x0 + width * 0.80, y0 + height * 0.21, math.max(2, 3 * scale), 18)
  for i = 1, 5 do
    local cx = x0 + ((i * 17 + (g.seed or 1) % 13) % Sim.W) * scale
    local cy = y0 + (4 + i % 3 * 3) * scale
    rect(r, cx - 3 * scale, cy, 6 * scale, scale, palette.cloud)
    rect(r, cx - scale, cy - scale, 4 * scale, scale, palette.cloud)
  end
  -- Terrain: draw columns in vertical runs, then grass rim and stratified pebbles.
  for x = 1, Sim.W do
    local column = g.terrain[x]
    local start, previous = nil, nil
    for y = 1, Sim.H + 1 do
      local isSolid = y <= Sim.H and column:sub(y, y) == "#"
      local color = isSolid and (((x * 7 + y * 13) % 17 == 0) and palette.stone or palette.dirt) or nil
      if color ~= previous then
        if start then
          rect(r, x0 + (x - 1) * scale, y0 + (start - 1) * scale, scale, (y - start) * scale, previous)
        end
        previous, start = color, (color and y or nil)
      end
    end
    for y = 1, Sim.H do
      if column:sub(y, y) == "#" and (y == 1 or column:sub(y - 1, y - 1) == ".") then
        rect(r, x0 + (x - 1) * scale, y0 + (y - 1) * scale, scale, math.max(1, math.ceil(scale / 2)), palette.grass)
      end
    end
  end
  -- Scenery remains deterministic across clients.
  for i = 1, 7 do
    local tx = 3 + ((i * 23 + g.seed) % (Sim.W - 5))
    local ty = Sim.ground(g, tx)
    if ty < Sim.H and ty > 4 and (i + g.theme) % 2 == 0 then
      local px = x0 + (tx - 1) * scale
      local py = y0 + (ty - 1) * scale
      rect(r, px, py - 3 * scale, math.max(1, scale - 1), 3 * scale, 22)
      rect(r, px - scale, py - 5 * scale, 3 * scale, 3 * scale, palette.grass)
    end
  end
  -- Animated pickup crates are deliberately drawn above the terrain.
  for i, item in ipairs(g.items or {}) do
    local x = x0 + (item.x - 1) * scale
    local y = y0 + (item.y - 1) * scale - 3 * scale
    local bob = (frame + i * 3) % 8 < 4 and 0 or 1
    rect(r, x - scale, y - bob, 3 * scale, 3 * scale, item.kind == "MEDKIT" and 11 or item.kind == "AMMO" and 8 or 13)
    r:outline(x - scale, y - bob, 3 * scale, 3 * scale, 7)
    if item.kind == "MEDKIT" then
      rect(r, x, y + scale - bob, scale, 1, 7)
      rect(r, x + math.floor(scale / 2), y - bob, 1, 3 * scale, 7)
    elseif item.kind == "AMMO" then
      dot(r, x, y + scale - bob, math.max(1, scale - 1), 10)
    else
      r:line(x - scale, y + scale - bob, x + scale, y + 2 * scale - bob, 18)
    end
  end
end

local function drawWorm(r, w, x0, y0, scale, selected, frame)
  if w.hp <= 0 then
    return
  end
  local x = x0 + (w.x - 1) * scale
  local y = y0 + (w.y - 1) * scale
  local s = math.max(2, scale)
  local facing = w.facing or 1
  local bob = selected and frame % 10 < 5 and 1 or 0
  local foot = y + math.floor(s * 0.3)
  local top = foot - 3 * s - bob
  -- Soft shadow, distinct feet, outlined body and helmet.
  rect(r, x - s, foot, 3 * s, 1, 23)
  rect(r, x - s, foot - s, s, s, 15)
  rect(r, x + s, foot - s, s, s, 15)
  rect(r, x - 2 * s, top + s, 4 * s, 2 * s, 23)
  rect(r, x - 2 * s + 1, top + s + 1, 4 * s - 2, 2 * s - 1, teamColors[w.team])
  rect(r, x - s, top, 3 * s, s + 1, 24)
  rect(r, x - s + 1, top + 1, 3 * s - 2, s - 1, teamColors[w.team])
  rect(r, x + facing * s, top + s, math.max(1, s - 1), math.max(1, s), 24)
  rect(r, x + facing * s, top + s, 1, 1, 0)
  rect(r, x + facing * s, top + 2 * s, 1, 1, 31)
  local barWidth = math.max(6, 4 * s + 2)
  rect(r, x - math.floor(barWidth / 2), top - 4, barWidth, 2, 10)
  rect(r, x - math.floor(barWidth / 2), top - 4, math.floor(barWidth * w.hp / 100), 2, 11)
  if w.shield then
    r:outline(x - 2 * s - 1, top - 1, 4 * s + 2, 3 * s + 2, 13)
  end
  if selected then
    r:line(x, top - 10, x - 3, top - 7, 18)
    r:line(x, top - 10, x + 3, top - 7, 18)
    r:line(x - 3, top - 7, x + 3, top - 7, 18)
  end
end

local function aimGuide(r, g, b, worm)
  if not worm or worm.hp <= 0 then
    return
  end
  local a = math.rad(worm.aim)
  local x = b.x + (worm.x - 1) * b.scale
  local y = b.y + (worm.y - 1) * b.scale - b.scale
  local len = math.max(12, b.scale * 8)
  r:line(x, y, x + math.cos(a) * len, y - math.sin(a) * len, 23)
  r:line(x, y - 1, x + math.cos(a) * len, y - math.sin(a) * len - 1, 7)
  dot(r, x + math.cos(a) * len, y - math.sin(a) * len, 1, 18)
  -- Simple protractor ticks anchored on the selected worm.
  for degrees = 15, 165, 15 do
    local t = math.rad(degrees)
    local inner, outer = b.scale * 4.4, b.scale * 4.8
    r:line(x + math.cos(t) * inner, y - math.sin(t) * inner, x + math.cos(t) * outer, y - math.sin(t) * outer, 6)
  end
end

local function effects(r, g, b, frame)
  local scale = b.scale
  for i, p in ipairs(g.trail or {}) do
    if p.x >= 1 and p.x <= Sim.W and p.y >= 1 and p.y <= Sim.H then
      dot(r, b.x + (p.x - 1) * scale, b.y + (p.y - 1) * scale, i % 3 == 0 and 1 or 0, i % 2 == 0 and 8 or 24)
    end
  end
  local p = g.projectile
  if p and p.x >= 1 and p.x <= Sim.W and p.y > 0 and p.y <= Sim.H then
    local x = b.x + (p.x - 1) * scale
    local y = b.y + (p.y - 1) * scale
    dot(r, x, y, math.max(2, scale), 31)
    dot(r, x, y, 1, 18)
  end
  local explosion = g.explosion
  if explosion and explosion.radius > 0 then
    local progress = math.min(1, explosion.elapsed / 0.85)
    local x = b.x + (explosion.x - 1) * scale
    local y = b.y + (explosion.y - 1) * scale
    local radius = math.floor(explosion.radius * scale * (0.3 + 0.7 * math.sin(progress * math.pi)))
    if radius > 0 then
      dot(r, x, y, radius, progress < 0.4 and 18 or 9)
      dot(r, x, y, math.max(1, math.floor(radius * 0.65)), progress < 0.35 and 7 or 31)
      for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2 + frame * 0.07
        local distance = radius * (1 + progress * 0.7)
        dot(r, x + math.cos(angle) * distance, y + math.sin(angle) * distance, 1, 8)
      end
    end
  end
end

local function battlefield(r, g, frame)
  local scale = math.max(1, math.floor(math.min((r.w - 6) / Sim.W, (r.h - 66) / Sim.H)))
  local b = {
    scale = scale,
    x = math.floor((r.w - Sim.W * scale) / 2),
    y = 20 + math.floor(math.max(0, r.h - 66 - Sim.H * scale) / 2),
  }
  scene(r, g, b, frame)
  for _, w in ipairs(g.worms) do
    drawWorm(r, w, b.x, b.y, scale, w == Sim.worm(g) and g.state == "aim", frame)
  end
  if g.state == "aim" then
    aimGuide(r, g, b, Sim.worm(g))
  end
  effects(r, g, b, frame)
  r:outline(b.x - 1, b.y - 1, Sim.W * scale + 2, Sim.H * scale + 2, 3)
  return b
end

function UI:touch(x, y)
  local vx, vy = self.r:touch(x, y)
  if not vx then
    return false
  end
  if self.r:hit(vx, vy) then
    return true
  end
  local b = self.board
  if
    b
    and self.canControl
    and vx >= b.x
    and vx < b.x + Sim.W * b.scale
    and vy >= b.y
    and vy < b.y + Sim.H * b.scale
  then
    local w = Sim.worm(self.game)
    local dx = vx - (b.x + (w.x - 1) * b.scale)
    local dy = (b.y + (w.y - 1) * b.scale) - vy
    if dx ~= 0 or dy ~= 0 then
      local angle = math.deg(math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx))
      self.dispatch({ kind = "setAim", angle = angle })
      return true
    end
  end
  return false
end

function UI:draw(g, opts)
  opts = opts or {}
  local r = self.r
  self.game, self.canControl, self.board = g, false, nil
  local frame = opts.frame or 0
  r:begin()
  r:fill(0, 0, r.w, 18, 1)
  r:text(3, 2, "WORMFRONT", 8)
  if not g then
    local y = math.floor(r.h * 0.29)
    r:center(y, "TACTICAL ARTILLERY", 7)
    r:center(y + 11, "PLAYERS " .. (opts.count or 1) .. "/4", 13)
    r:center(y + 21, opts.status or "WAITING FOR PLAYERS", 6)
    if opts.role == "host" then
      r:center(y + 31, "HOST " .. tostring(opts.hostId or "?"), 8)
      r:button(math.floor(r.w / 2) - 32, r.h - 33, 64, 16, "START", function()
        self.dispatch({ kind = "start" })
      end, { primary = true })
    end
    r:button(r.w - 46, r.h - 17, 44, 13, "EXIT", function()
      self.dispatch({ kind = "exit" })
    end)
    r:finish()
    return
  end

  local active = g.phase == "playing" and g.state == "aim"
  local mine = active and (opts.role == "local" or (opts.slot ~= nil and opts.slot == g.turn))
  self.canControl = mine
  local timer = math.ceil(g.turnLeft or 0)
  r:text(r.w - 104, 2, "TEAM " .. g.turn .. "  TIME " .. timer, timer < 10 and 31 or 7, 1, 100)
  r:fill(3, 11, r.w - 6, 3, 3)
  r:fill(3, 11, math.floor((r.w - 6) * (g.turnLeft or 0) / Sim.TURN_SECONDS), 3, timer < 10 and 10 or 11)
  r:text(3, 15, "WIND " .. (g.wind > 0 and "+" or "") .. g.wind .. "  " .. g.message, 7, 1, r.w - 6)
  self.board = battlefield(r, g, frame)

  if g.phase == "finished" then
    r:fill(0, r.h - 37, r.w, 35, 1)
    r:center(r.h - 31, g.message, 18)
    r:button(r.w - 51, r.h - 16, 49, 13, "EXIT", function()
      self.dispatch({ kind = "exit" })
    end)
  else
    local worm = Sim.worm(g)
    local y = r.h - 33
    r:fill(0, y - 13, r.w, 12, 1)
    local angle = worm and worm.aim or 0
    local status = worm
        and ("HP " .. worm.hp .. "  ANGLE " .. angle .. "  " .. (worm.weapon == 2 and ("MEGA " .. worm.mega) or "ROCKET"))
      or ""
    local charge = g.charging and math.min(1, (g.charge or 0) / 1.8) or 0
    local pw = math.min(74, math.max(20, math.floor(r.w * 0.33)))
    if r.w < 180 and worm then
      status = "HP " .. worm.hp .. "  ANG " .. angle
    end
    r:text(3, y - 11, status, 6, 1, r.w - pw - 9)
    r:fill(r.w - pw - 3, y - 12, pw, 7, 3)
    r:fill(r.w - pw - 3, y - 12, pw * charge, 7, charge > 0.85 and 31 or 18)
    r:outline(r.w - pw - 3, y - 12, pw, 7, 6)
    local function act(kind, dir)
      return function()
        self.dispatch({ kind = kind, dir = dir })
      end
    end
    buttonRow(r, {
      { "WORM", act("select") },
      { "AIM -", act("aim", -1) },
      { "AIM +", act("aim", 1) },
      { "JUMP", act("jump") },
      { "WEAPON", act("weapon") },
    }, y, mine)
    buttonRow(r, {
      { "LEFT", act("move", -1) },
      { "RIGHT", act("move", 1) },
      { g.charging and "RELEASE" or "CHARGE", act("fire"), true },
      { "PASS", act("pass") },
      { "EXIT", act("exit"), false, true },
    }, y + 15, mine)
  end
  r:finish()
end
return UI
