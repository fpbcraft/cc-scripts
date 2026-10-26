-- WORMFRONT view: camera-following battlefield, platforms, rope and weapon picker.
local Canvas = require("lib.fpb.canvas")
local Sim = require("sim")
local UI = {}
UI.__index = UI
local colorsByTeam = { 13, 31, 18, 11 }
local themes = {
  { sky = 19, ground = 16, grass = 11, hill = 3 },
  { sky = 20, ground = 9, grass = 8, hill = 25 },
  { sky = 23, ground = 17, grass = 13, hill = 20 },
  { sky = 25, ground = 26, grass = 28, hill = 12 },
}
local function fill(r, x, y, w, h, c)
  r:fill(math.floor(x), math.floor(y), math.max(0, math.ceil(w)), math.max(0, math.ceil(h)), c)
end
local function dot(r, x, y, radius, color)
  radius = math.floor(radius)
  for dy = -radius, radius do
    local reach = math.floor(math.sqrt(math.max(0, radius * radius - dy * dy)))
    fill(r, x - reach, y + dy, 2 * reach + 1, 1, color)
  end
end
local function buttonRow(r, entries, y, enabled)
  local gap = 2
  local width = math.floor((r.w - gap * (#entries + 1)) / #entries)
  for i, entry in ipairs(entries) do
    local x = gap + (i - 1) * (width + gap)
    r:button(x, y, width, 13, entry[1], (enabled or entry[4]) and entry[2] or nil, { primary = entry[3] and enabled })
  end
end
function UI.new(mon, dispatch)
  return setmetatable({ r = Canvas.new(mon), dispatch = dispatch, picker = false }, UI)
end
function UI:resize()
  self.r:resize()
end
function UI:close()
  self.r:close()
end

-- World coordinates are mapped through the scrolling camera.
local function screen(b, x, y)
  return b.x + (x - 1 - b.scrollX) * b.scale, b.y + (y - 1 - b.scrollY) * b.scale
end
local function visible(b, x, y, pad)
  pad = pad or 2
  return x >= b.scrollX - pad and x < b.scrollX + b.w / b.scale + pad
    and y >= b.scrollY - pad and y < b.scrollY + b.h / b.scale + pad
end
local function camera(r, g)
  local areaW, areaH = r.w - 6, math.max(30, r.h - 68)
  local scale = math.max(1, math.min(3, math.floor(areaH / 42)))
  local focus = g.projectile or Sim.worm(g)
  focus = focus or { x = Sim.W / 2, y = Sim.H / 2 }
  local vw, vh = areaW / scale, areaH / scale
  local clamp = function(n, a, z)
    return math.max(a, math.min(z, n))
  end
  return {
    x = 3, y = 20, w = areaW, h = areaH, scale = scale,
    scrollX = clamp(focus.x - vw / 2, 0, math.max(0, Sim.W - vw)),
    scrollY = clamp(focus.y - vh * 0.62, 0, math.max(0, Sim.H - vh)),
  }
end
local function scene(r, g, b, frame)
  local theme = themes[g.theme or 1]
  fill(r, b.x, b.y, b.w, b.h, theme.sky)
  fill(r, b.x, b.y + b.h * 0.65, b.w, b.h * 0.35, theme.hill)
  -- Background detail is kept independent of camera position.
  for i = 1, 6 do
    local x, y = screen(b, i * 27 - 7, 8 + i % 4 * 3)
    if x > b.x + 4 and x < b.x + b.w - 12 and y > b.y + 3 and y < b.y + b.h - 5 then
      fill(r, x, y, 9, 2, 24)
      fill(r, x + 2, y - 2, 6, 3, 24)
    end
  end
  local xStart = math.max(1, math.floor(b.scrollX + 1))
  local xEnd = math.min(Sim.W, math.ceil(b.scrollX + b.w / b.scale))
  local yStart = math.max(1, math.floor(b.scrollY + 1))
  local yEnd = math.min(Sim.H, math.ceil(b.scrollY + b.h / b.scale))
  -- Batch contiguous terrain columns. Thousands of tiny drawPixels caused flicker.
  for x = xStart, xEnd do
    local column = g.terrain[x]
    local px = b.x + (x - 1 - b.scrollX) * b.scale
    local groundStart
    for y = yStart, yEnd do
      if column:sub(y, y) == "#" then
        groundStart = y
        break
      end
    end
    if groundStart then
      local py = b.y + (groundStart - 1 - b.scrollY) * b.scale
      fill(r, px, py, b.scale, (yEnd - groundStart + 1) * b.scale, theme.ground)
      if groundStart == 1 or column:sub(groundStart - 1, groundStart - 1) == "." then
        fill(r, px, py, b.scale, math.max(1, b.scale / 2), theme.grass)
      end
    end
    for y = yStart, yEnd do
      if column:sub(y, y) == "=" then
        local py = b.y + (y - 1 - b.scrollY) * b.scale
        fill(r, px, py, b.scale, b.scale, 8)
      end
    end
  end
  for i, item in ipairs(g.items or {}) do
    if visible(b, item.x, item.y, 1) then
      local x, y = screen(b, item.x, item.y)
      y = y - b.scale * 2 - ((frame + i) % 8 < 4 and 1 or 0)
      local s = math.max(2, b.scale * 2)
      local c = item.kind == "MEDKIT" and 11 or item.kind == "SHIELD" and 13 or 8
      fill(r, x - s / 2, y, s, s, c)
      r:outline(x - s / 2, y, s, s, 7)
    end
  end
  for _, mine in ipairs(g.mines or {}) do
    if visible(b, mine.x, mine.y) then
      local x, y = screen(b, mine.x, mine.y)
      dot(r, x, y, b.scale + 1, mine.arm == 0 and 31 or 17)
    end
  end
  for _, fire in ipairs(g.fires or {}) do
    if visible(b, fire.x, fire.y) then
      local x, y = screen(b, fire.x, fire.y)
      dot(r, x, y - (frame % 4), b.scale + 1, 31)
      dot(r, x, y - b.scale - (frame % 4), b.scale, 18)
    end
  end
end
local function worms(r, g, b, frame)
  for _, worm in ipairs(g.worms) do
    if worm.hp > 0 and visible(b, worm.x, worm.y, 4) then
      local x, y = screen(b, worm.x, worm.y)
      local s = math.max(2, b.scale)
      local selected = worm == Sim.worm(g)
      local bob = selected and frame % 8 < 4 and 1 or 0
      local top = y - s * 3 - bob
      fill(r, x - s, y, s, s, 15)
      fill(r, x + s, y, s, s, 15)
      fill(r, x - 2 * s, top + s, 4 * s, 2 * s, 23)
      fill(r, x - 2 * s + 1, top + s + 1, 4 * s - 2, 2 * s - 1, colorsByTeam[worm.team])
      fill(r, x - s, top, 3 * s, s, 24)
      fill(r, x - s + 1, top + 1, 3 * s - 2, math.max(1, s - 1), colorsByTeam[worm.team])
      fill(r, x + (worm.facing or 1) * s, top + s, s, s, 7)
      fill(r, x + (worm.facing or 1) * s, top + s, 1, 1, 0)
      fill(r, x - 3 * s, top - 4, 6 * s, 2, 10)
      fill(r, x - 3 * s, top - 4, 6 * s * worm.hp / 100, 2, 11)
      if worm.shield then
        r:outline(x - 2 * s - 1, top - 2, 4 * s + 2, 3 * s + 3, 13)
      end
      if selected then
        r:line(x, top - 10, x - 3, top - 7, 18)
        r:line(x, top - 10, x + 3, top - 7, 18)
        if worm.rope then
          local ax, ay = screen(b, worm.rope.x, worm.rope.y)
          r:line(x, y, ax, ay, 6)
        end
      end
    end
  end
end
local function effects(r, g, b, frame)
  for i, p in ipairs(g.trail or {}) do
    if visible(b, p.x, p.y) then
      local x, y = screen(b, p.x, p.y)
      dot(r, x, y, 1, i % 2 == 0 and 8 or 24)
    end
  end
  if g.projectile and visible(b, g.projectile.x, g.projectile.y) then
    local x, y = screen(b, g.projectile.x, g.projectile.y)
    dot(r, x, y, math.max(2, b.scale), 31)
  end
  if g.explosion and g.explosion.radius > 0 and visible(b, g.explosion.x, g.explosion.y, 12) then
    local e = g.explosion
    local x, y = screen(b, e.x, e.y)
    local phase = math.min(1, e.elapsed / 0.85)
    local radius = math.max(1, math.floor(e.radius * b.scale * (0.2 + math.sin(phase * math.pi) * 0.8)))
    dot(r, x, y, radius, phase < 0.5 and 18 or 31)
    dot(r, x, y, math.floor(radius / 2), 7)
  end
  local w = Sim.worm(g)
  if g.state == "aim" and w and visible(b, w.x, w.y) then
    local a = math.rad(w.aim)
    local x, y = screen(b, w.x, w.y)
    r:line(x, y - b.scale, x + math.cos(a) * b.scale * 7, y - b.scale - math.sin(a) * b.scale * 7, 7)
  end
end
function UI:touch(x, y)
  local vx, vy = self.r:touch(x, y)
  if not vx then
    return false
  end
  if self.r:hit(vx, vy) then
    return true
  end
  if self.picker then
    return false
  end
  local b, g = self.board, self.game
  if not b or not self.canControl or vx < b.x or vx >= b.x + b.w or vy < b.y or vy >= b.y + b.h then
    return false
  end
  local wx = (vx - b.x) / b.scale + b.scrollX + 1
  local wy = (vy - b.y) / b.scale + b.scrollY + 1
  local worm = Sim.worm(g)
  if not worm then
    return false
  end
  if self.aimMode == "rope" then
    self.dispatch({ kind = "rope", x = wx, y = wy })
    self.aimMode = nil
  elseif Sim.weapons[worm.weapon].kind == "strike" then
    self.dispatch({ kind = "setTarget", x = wx })
  else
    local dx, dy = wx - worm.x, worm.y - wy
    if dx ~= 0 or dy ~= 0 then
      local a = math.deg(math.atan(dy, dx))
      if a >= 0 and a <= 180 then
        self.dispatch({ kind = "setAim", angle = a })
      end
    end
  end
  return true
end
function UI:draw(g, opts)
  opts = opts or {}
  local r = self.r
  local frame = opts.frame or 0
  self.game, self.board, self.canControl = g, nil, false
  r:begin()
  fill(r, 0, 0, r.w, 19, 1)
  r:text(3, 3, "WORMFRONT", 8)
  if not g then
    r:center(math.floor(r.h * 0.3), "MULTIPLAYER ARTILLERY", 7)
    r:center(math.floor(r.h * 0.3) + 13, "PLAYERS " .. (opts.count or 1) .. "/4", 13)
    r:center(math.floor(r.h * 0.3) + 25, opts.status or "WAITING", 7)
    if opts.role == "host" then
      r:center(math.floor(r.h * 0.3) + 37, "HOST " .. tostring(opts.hostId or "?"), 8)
      r:button(math.floor(r.w / 2) - 32, r.h - 33, 64, 16, "START", function()
        self.dispatch({ kind = "start" })
      end)
    end
    r:button(r.w - 48, r.h - 17, 46, 13, "EXIT", function()
      self.dispatch({ kind = "exit" })
    end)
    r:finish()
    return
  end
  local active = g.phase == "playing" and g.state == "aim"
  local mine = active and (opts.role == "local" or (opts.slot ~= nil and opts.slot == g.turn))
  self.canControl = mine
  local remaining = math.max(0, g.turnLeft or 0)
  r:text(math.max(68, r.w - 104), 3, "TEAM " .. g.turn .. "  TIME " .. math.ceil(remaining), remaining < 10 and 31 or 7, 1, 100)
  fill(r, 3, 11, r.w - 6, 3, 3)
  fill(r, 3, 11, (r.w - 6) * remaining / Sim.TURN_SECONDS, 3, remaining < 10 and 31 or 11)
  r:text(3, 15, "WIND " .. (g.wind > 0 and "+" or "") .. g.wind .. "  " .. g.message, 7, 1, r.w - 6)
  local b = camera(r, g)
  self.board = b
  scene(r, g, b, frame)
  worms(r, g, b, frame)
  effects(r, g, b, frame)
  r:outline(b.x - 1, b.y - 1, b.w + 2, b.h + 2, 3)
  if g.phase == "finished" then
    r:center(r.h - 28, g.message, 18)
    r:button(r.w - 50, r.h - 16, 48, 13, "EXIT", function()
      self.dispatch({ kind = "exit" })
    end)
    r:finish()
    return
  end
  local w = Sim.worm(g)
  local id = w and w.weapon or 1
  local ammo = g.inventory[g.turn] and g.inventory[g.turn][id] or 0
  local name = Sim.weapons[id].name
  local y = r.h - 35
  fill(r, 0, y - 12, r.w, 12, 1)
  local charge = g.charging and math.min(1, g.charge / 1.8) or 0
  local pw = math.max(24, math.floor(r.w / 4))
  local status = "HP " .. (w and w.hp or 0) .. "  " .. name .. " " .. (ammo == -1 and "INF" or ammo)
  r:text(3, y - 10, status, 6, 1, r.w - pw - 8)
  fill(r, r.w - pw - 3, y - 11, pw, 7, 3)
  fill(r, r.w - pw - 3, y - 11, pw * charge, 7, charge > 0.9 and 31 or 18)
  r:outline(r.w - pw - 3, y - 11, pw, 7, 7)
  local function act(kind, dir)
    return function()
      self.dispatch({ kind = kind, dir = dir })
    end
  end
  buttonRow(r, {
    { "LEFT", act("move", -1) }, { "RIGHT", act("move", 1) },
    { "AIM -", act("aim", -1) }, { "AIM +", act("aim", 1) },
    { "JUMP", act("jump") }, { "ARMS", function()
      self.picker = not self.picker
    end },
  }, y, mine)
  buttonRow(r, {
    { "ROPE", function()
      if w and w.rope then
        self.dispatch({ kind = "rope" })
      else
        self.aimMode = "rope"
      end
    end },
    { "REEL -", act("reel", -1) }, { "REEL +", act("reel", 1) },
    { g.charging and "RELEASE" or "CHARGE", act("fire"), true },
    { "PASS", act("pass") }, { "EXIT", act("exit"), false, true },
  }, y + 15, mine)
  if self.picker then
    local x0 = math.max(2, math.floor(r.w * 0.09))
    local bw = math.floor((r.w - 2 * x0 - 8) / 2)
    local height = math.min(b.y + b.h - 8, 12 * 6 + 12)
    local sy = b.y + math.max(2, math.floor((b.h - height) / 2))
    fill(r, x0 - 3, sy - 3, bw * 2 + 14, height + 6, 1)
    r:outline(x0 - 3, sy - 3, bw * 2 + 14, height + 6, 8)
    for i, weapon in ipairs(Sim.weapons) do
      local row, col = math.floor((i - 1) / 2), (i - 1) % 2
      local ix, iy = x0 + col * (bw + 4), sy + row * 14
      local stock = g.inventory[g.turn][i] or 0
      local label = weapon.name .. " " .. (stock == -1 and "INF" or stock)
      r:button(ix, iy, bw, 12, label, mine and stock ~= 0 and function()
        self.dispatch({ kind = "weapon", id = i })
        self.picker = false
      end or nil, { selected = id == i })
    end
    r:button(x0, sy + 70, bw * 2 + 4, 12, "CLOSE", function()
      self.picker = false
    end)
  end
  r:finish()
end
return UI
