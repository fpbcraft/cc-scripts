-- COGWORKS / CC: Graphics pixel renderer with text fallback.
-- Scenes retain a 200x120 authored layout, but pixels are no longer
-- magnified just to fill the screen. Like CivCraft, graphics density follows
-- the terminal dimensions (3x4 logical pixels per text cell).
-- Graphics pointer coordinates are zero-based; vanilla touch is one-based.
local E = require("games.cogworks.engine")
local Campaign = require("games.cogworks.chapters")
local T = require("games.cogworks.tutorials")
local R = {}
R.__index = R
-- All visual elements use CraftOS' sixteen palette indices. The accents
-- follow Create-style blueprints: navy, cyan ink, steel and restrained brass.
local palette = {
  [0] = 0x07192D, -- blueprint background
  [1] = 0x0D2844, -- deep panel
  [2] = 0x173B5A, -- tile/background fill
  [3] = 0x23567B, -- blue grid lines / borders
  [4] = 0x4780A4, -- inactive mechanism / secondary ink
  [5] = 0xC1D8E7, -- text
  [6] = 0xD9B06B, -- pale wood / brass selection
  [7] = 0x8D633E, -- oak timber / brass shadow
  [8] = 0xB94A37, -- jam / redstone tracks
  [9] = 0x91D3B7, -- successful machine
  [10] = 0x533922, -- dark wood grain / source block
  [11] = 0x64D3F2, -- CW / cyan highlights
  [12] = 0x307FAF, -- bright-blue frame
  [13] = 0xA3B6C3, -- steel
  [14] = 0xF4A25E, -- CCW / orange highlights
  [15] = 0xF1F5E9, -- white blueprint text
}
local F = {
  A = { "010", "101", "111", "101", "101" },
  B = { "110", "101", "110", "101", "110" },
  C = { "011", "100", "100", "100", "011" },
  D = { "110", "101", "101", "101", "110" },
  E = { "111", "100", "110", "100", "111" },
  F = { "111", "100", "110", "100", "100" },
  G = { "011", "100", "101", "101", "011" },
  H = { "101", "101", "111", "101", "101" },
  I = { "111", "010", "010", "010", "111" },
  J = { "001", "001", "001", "101", "010" },
  K = { "101", "101", "110", "101", "101" },
  L = { "100", "100", "100", "100", "111" },
  M = { "101", "111", "111", "101", "101" },
  N = { "101", "111", "111", "111", "101" },
  O = { "010", "101", "101", "101", "010" },
  P = { "110", "101", "110", "100", "100" },
  Q = { "010", "101", "101", "111", "011" },
  R = { "110", "101", "110", "101", "101" },
  S = { "011", "100", "010", "001", "110" },
  T = { "111", "010", "010", "010", "010" },
  U = { "101", "101", "101", "101", "111" },
  V = { "101", "101", "101", "101", "010" },
  W = { "101", "101", "111", "111", "101" },
  X = { "101", "101", "010", "101", "101" },
  Y = { "101", "101", "010", "010", "010" },
  Z = { "111", "001", "010", "100", "111" },
  ["0"] = { "111", "101", "101", "101", "111" },
  ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "110", "001", "010", "100", "111" },
  ["3"] = { "110", "001", "010", "001", "110" },
  ["4"] = { "101", "101", "111", "001", "001" },
  ["5"] = { "111", "100", "110", "001", "110" },
  ["6"] = { "011", "100", "110", "101", "010" },
  ["7"] = { "111", "001", "010", "010", "010" },
  ["8"] = { "010", "101", "010", "101", "010" },
  ["9"] = { "010", "101", "011", "001", "110" },
  [" "] = { "000", "000", "000", "000", "000" },
  ["-"] = { "000", "000", "111", "000", "000" },
  ["+"] = { "000", "010", "111", "010", "000" },
  ["/"] = { "001", "001", "010", "100", "100" },
  [":"] = { "000", "010", "000", "010", "000" },
  ["!"] = { "010", "010", "010", "000", "010" },
  ["."] = { "000", "000", "000", "000", "010" },
  ["?"] = { "110", "001", "010", "000", "010" },
  ["="] = { "000", "111", "000", "111", "000" },
  ["<"] = { "001", "010", "100", "010", "001" },
  [">"] = { "100", "010", "001", "010", "100" },
  ["#"] = { "101", "111", "101", "111", "101" },
  ["("] = { "001", "010", "010", "010", "001" },
  [")"] = { "100", "010", "010", "010", "100" },
}
local function fillText(m, x, y, w, fg, bg, text)
  m.setCursorPos(x, y)
  m.setTextColor(fg)
  m.setBackgroundColor(bg)
  m.write((tostring(text) .. (" "):rep(w)):sub(1, w))
end
function R.new(m)
  local self =
    setmetatable({ m = m, mode = "text", frame = 0, original = {}, buffer = {}, boardX = 5, boardY = 17, cell = 15 }, R)
  self:enable()
  return self
end
-- Keep one isotropic pixel scale, but derive both canvas dimensions from
-- the actual raster. Window shape never introduces a letterbox or pillarbox.
function R:fitGraphics()
  self.scale = math.min(self.pw / math.max(200, self.tw * 3), self.ph / 120)
  self.canvasW = math.ceil(self.pw / self.scale)
  self.canvasH = math.ceil(self.ph / self.scale)
  self.logicalWidth, self.logicalHeight = self.canvasW, self.canvasH
  self.wide = self.canvasW >= 200 and self.canvasH >= 160
  self.ox, self.oy = 0, 0
end
function R:enable()
  local m = self.m
  self.tw, self.th = m.getSize()
  self.needsClear = true
  if m.setGraphicsMode and m.drawPixels then
    local ok = pcall(m.setGraphicsMode, 2)
    if ok then
      local good, w, h = pcall(m.getSize, 2)
      if good and type(w) == "number" and w >= 200 and h >= 120 then
        self.mode = "graphics"
        self.pw, self.ph = w, h
        self:fitGraphics()
        if m.setPaletteColor then
          for i, c in pairs(palette) do
            if m.getPaletteColor then
              local success, r, g, b = pcall(m.getPaletteColor, i)
              if success then
                self.original[i] = { r, g, b }
              end
            end
            pcall(m.setPaletteColor, i, c)
          end
        end
        return
      end
      pcall(m.setGraphicsMode, 0)
    end
  end
  self.mode = "text"
end
function R:resize()
  if self.mode == "graphics" then
    local ok, w, h = pcall(self.m.getSize, 2)
    if ok and type(w) == "number" then
      self.pw, self.ph = w, h
      self.tw, self.th = self.m.getSize()
      self:fitGraphics()
      self.previousBuffer = nil
      self.baseBuffer = nil
      self.previewBounds = nil
      -- The previous image and letterbox are still in the monitor's pixel
      -- backing surface after a resize. Discard them before the next draw.
      self.needsClear = true
    end
  else
    self.tw, self.th = self.m.getSize()
  end
end
function R:close()
  if self.mode == "graphics" then
    if self.m.setFrozen then
      pcall(self.m.setFrozen, false)
    end
    if self.m.setPaletteColor then
      for i, c in pairs(self.original) do
        pcall(self.m.setPaletteColor, i, c[1], c[2], c[3])
      end
    end
    pcall(self.m.setGraphicsMode, 0)
  end
end
function R:rect(x, y, w, h, color)
  if self.mode ~= "graphics" or w <= 0 or h <= 0 then
    return
  end
  -- Retained logical pixels: individual font and sprite pixels never issue
  -- peripheral calls. At presentation time only changed horizontal runs are
  -- sent to the attached monitor.
  local x1, y1 = math.max(0, math.floor(x)), math.max(0, math.floor(y))
  local x2, y2 = math.min(self.canvasW, math.ceil(x + w)), math.min(self.canvasH, math.ceil(y + h))
  if self.spriteClip then
    local clip = self.spriteClip
    x1, y1 = math.max(x1, clip.x), math.max(y1, clip.y)
    x2, y2 = math.min(x2, clip.x + clip.size), math.min(y2, clip.y + clip.size)
  end
  for py = y1, y2 - 1 do
    -- Preview frames inherit unchanged scanlines from the cached scene.
    -- Copy only rows touched by the ghost; never mutate the cached board.
    local row = rawget(self.buffer, py + 1)
    if not row then
      row = {}
      if self.overlayBase then
        local baseRow = self.overlayBase[py + 1]
        if baseRow then
          setmetatable(row, { __index = baseRow })
        end
      end
      self.buffer[py + 1] = row
    end
    for px = x1, x2 - 1 do
      row[px + 1] = color
    end
  end
end
-- CC:Graphics uses the CraftOS-PC drawPixels API and supports indexed
-- bitmap rows. Upload one changed rectangle per frame instead of invoking
-- thousands of peripheral methods and freezing the server-side monitor.
function R:flush(bounds)
  local old = self.previousBuffer
  local current = self.buffer
  local left, top, right, bottom = self.canvasW, self.canvasH, -1, -1
  local firstX = bounds and math.max(0, math.floor(bounds.x1)) or 0
  local firstY = bounds and math.max(0, math.floor(bounds.y1)) or 0
  local lastX = bounds and math.min(self.canvasW - 1, math.ceil(bounds.x2)) or self.canvasW - 1
  local lastY = bounds and math.min(self.canvasH - 1, math.ceil(bounds.y2)) or self.canvasH - 1
  for y = firstY, lastY do
    local row = current[y + 1] or {}
    local prior = old and old[y + 1] or nil
    for x = firstX, lastX do
      if (row[x + 1] or 0) ~= (prior and prior[x + 1] or 0) or not old then
        left = math.min(left, x)
        top = math.min(top, y)
        right = math.max(right, x)
        bottom = math.max(bottom, y)
      end
    end
  end
  if right < left then
    self.previousBuffer = current
    return 0
  end
  local x1 = math.max(0, math.floor(self.ox + left * self.scale))
  local y1 = math.max(0, math.floor(self.oy + top * self.scale))
  local x2 = math.min(self.pw, math.ceil(self.ox + (right + 1) * self.scale))
  local y2 = math.min(self.ph, math.ceil(self.oy + (bottom + 1) * self.scale))
  local width, height = x2 - x1, y2 - y1
  if width <= 0 or height <= 0 then
    self.previousBuffer = current
    return 0
  end
  local rows = {}
  for py = y1, y2 - 1 do
    local sy = math.max(0, math.min(self.canvasH - 1, math.floor((py - self.oy) / self.scale)))
    local source = current[sy + 1] or {}
    local bytes = {}
    for px = x1, x2 - 1 do
      local sx = math.max(0, math.min(self.canvasW - 1, math.floor((px - self.ox) / self.scale)))
      bytes[#bytes + 1] = string.char(source[sx + 1] or 0)
    end
    rows[#rows + 1] = table.concat(bytes)
  end
  local mon = self.m
  if mon.setFrozen then
    pcall(mon.setFrozen, true)
  end
  if self.needsClear then
    -- Clear the full physical pixel surface, including the intentional
    -- drafting-table margins around the compact 200x120 playfield.
    mon.drawPixels(0, 0, 0, self.pw, self.ph)
    self.needsClear = false
  end
  -- One batched draw request, including on remote Minecraft monitors.
  mon.drawPixels(x1, y1, rows, width, height)
  if mon.setFrozen then
    pcall(mon.setFrozen, false)
  end
  self.previousBuffer = current
  return 1
end
function R:font(x, y, str, color)
  str = tostring(str):upper()
  for n = 1, #str do
    local g = F[str:sub(n, n)] or F["?"]
    for row = 1, 5 do
      for col = 1, 3 do
        if g[row]:sub(col, col) == "1" then
          self:rect(x + (n - 1) * 4 + col - 1, y + row - 1, 1, 1, color)
        end
      end
    end
  end
end
-- Double-sized bitmap lettering for cinematic level cards.
function R:fontLarge(x, y, str, color)
  str = tostring(str):upper()
  for n = 1, #str do
    local glyph = F[str:sub(n, n)] or F["?"]
    for row = 1, 5 do
      for col = 1, 3 do
        if glyph[row]:sub(col, col) == "1" then
          self:rect(x + (n - 1) * 8 + (col - 1) * 2, y + (row - 1) * 2, 2, 2, color)
        end
      end
    end
  end
end
function R:line(x1, y1, x2, y2, color)
  local count = math.ceil(math.max(math.abs(x2 - x1), math.abs(y2 - y1)))
  for i = 0, math.max(1, count) do
    local t = i / math.max(1, count)
    self:rect(math.floor(x1 + (x2 - x1) * t), math.floor(y1 + (y2 - y1) * t), 1, 1, color)
  end
end
local DX = { 0, 1, 0, -1 }
local DY = { -1, 0, 1, 0 }
-- Numeric rate is relative to the fixed 1X generator. Individual gearbox
-- outlets have opposite spin, so prefer the actual axial facing port rather
-- than interpreting the first arbitrary port as the whole block's direction.
local function motionFor(tile, light)
  if not light or not light.powered then
    return nil
  end
  return light.ports and (light.ports[tile.r] or light.ports[next(light.ports)])
    or (light.rate and { sign = light.sign, rate = light.rate })
end
local function speedLabel(rate)
  if not rate or rate <= 0 then
    return nil
  end
  if math.abs(rate - 0.5) < 0.01 then
    return "0.5"
  end
  if math.abs(rate - math.floor(rate + 0.5)) < 0.01 then
    return tostring(math.floor(rate + 0.5)) .. "X"
  end
  return string.format("%.1f", rate)
end
-- The shaft's highlight alternates across its upper/lower (or left/right)
-- faces. This communicates *axial rotation*, not motion along a conveyor.
-- The phase is signed and linked to kinetic speed.
function R:shaft(x, y, cx, cy, tile, spin)
  local active = spin ~= nil
  local phase = active and math.floor(self.frame * math.min(spin.rate, 4)) * spin.sign or 0
  local edge = phase % 4
  for dir = 0, 3 do
    if E.hasPort(tile, dir) then
      local dx, dy = DX[dir + 1], DY[dir + 1]
      local ex, ey = cx + dx * 5, cy + dy * 5
      if dx ~= 0 then
        local sx = math.min(cx, ex)
        local length = math.abs(cx - ex) + 1
        self:rect(sx, cy - 1, length, 3, 4)
        self:rect(sx, cy, length, 1, 13)
        if active then
          self:rect(sx, cy - 1, length, 1, edge < 2 and 11 or 7)
          self:rect(sx, cy + 1, length, 1, edge >= 2 and 11 or 7)
        end
      else
        local sy = math.min(cy, ey)
        local length = math.abs(cy - ey) + 1
        self:rect(cx - 1, sy, 3, length, 4)
        self:rect(cx, sy, 1, length, 13)
        if active then
          self:rect(cx - 1, sy, 1, length, edge < 2 and 11 or 7)
          self:rect(cx + 1, sy, 1, length, edge >= 2 and 11 or 7)
        end
      end
      self:rect(ex, ey, 2, 2, 7)
    end
  end
end
-- Port of the approved Blueprint Lab HTML prototype's gear sprite.
-- Large cogs use a 4px radius, small cogs a 3px radius, with visible 2x2
-- teeth outside the circular-ish brass rim and a steel-centered hub.
-- The first tooth is a moving white index marker, while the two spokes
-- rotate continuously at the gear's actual signed speed.
local function rounded(x)
  return math.floor(x + 0.5)
end
-- Two distinct gear silhouettes: small = compact solid four-spoke pinion;
-- large = open twelve-tooth ring with a steel spider. Both have an obvious
-- off-center index tooth so animation direction remains visible.
function R:cog(cx, cy, large, spin, maxRadius)
  local radius = math.min(large and 4 or 2, maxRadius or 4)
  local angle = spin and self.frame * 0.44 * math.min(spin.rate, 4) * spin.sign or 0
  if large then
    -- The large wheel has a hollow dark center, an outer brass ring, and
    -- twelve square teeth: its silhouette is not a scaled-up small pinion.
    self:rect(cx - radius, cy - radius + 1, radius * 2 + 1, radius * 2 - 1, 7)
    self:rect(cx - radius + 1, cy - radius, radius * 2 - 1, radius * 2 + 1, 7)
    if radius >= 3 then
      self:rect(cx - radius + 2, cy - radius + 2, radius * 2 - 3, radius * 2 - 3, 2)
    end
    for tooth = 0, 11 do
      local theta = tooth * math.pi / 6 + angle
      local tx = rounded(cx + math.cos(theta) * (radius + 1))
      local ty = rounded(cy + math.sin(theta) * (radius + 1))
      self:rect(tx, ty, 2, 2, tooth == 0 and spin and 15 or 6)
    end
    for arm = 0, 3 do
      local theta = angle + arm * math.pi / 2
      local reach = math.max(1, radius - 1)
      self:line(
        cx,
        cy,
        rounded(cx + math.cos(theta) * reach),
        rounded(cy + math.sin(theta) * reach),
        arm == 0 and (spin and 11 or 13) or 13
      )
    end
    self:rect(cx - 1, cy - 1, 3, 3, 13)
    self:rect(cx, cy, 1, 1, 1)
  else
    -- A pinion is a small, solid brass gear with eight individual fine teeth,
    -- a simple white spoke, and a tiny one-pixel bearing.
    self:rect(cx - radius + 1, cy - radius + 1, radius * 2 - 1, radius * 2 - 1, 6)
    for tooth = 0, 7 do
      local theta = tooth * math.pi / 4 + angle
      self:rect(
        rounded(cx + math.cos(theta) * (radius + 1)),
        rounded(cy + math.sin(theta) * (radius + 1)),
        1,
        1,
        tooth == 0 and spin and 15 or 6
      )
    end
    self:line(
      cx,
      cy,
      rounded(cx + math.cos(angle) * radius),
      rounded(cy + math.sin(angle) * radius),
      spin and (spin.sign > 0 and 11 or 14) or 13
    )
    self:rect(cx, cy, 1, 1, 1)
  end
end
-- Inventory glyphs use just 7x7 pixels: real sprites instead of a
-- colored square containing the part's name.
function R:toolIcon(x, y, kind)
  if kind == "G" then
    -- Tiny eight-tooth pinion, deliberately much smaller than the open wheel.
    self:rect(x + 2, y + 2, 3, 3, 6)
    for _, tooth in ipairs({ { 3, 1 }, { 5, 3 }, { 3, 5 }, { 1, 3 } }) do
      self:rect(x + tooth[1], y + tooth[2], 1, 1, 6)
    end
    self:rect(x + 3, y + 3, 1, 1, 1)
  elseif kind == "O" then
    -- Large open rim + four strong teeth + open dark interior.
    self:rect(x + 1, y + 1, 5, 5, 7)
    self:rect(x + 2, y + 2, 3, 3, 2)
    for _, tooth in ipairs({ { 3, 0 }, { 6, 3 }, { 3, 6 }, { 0, 3 } }) do
      self:rect(x + tooth[1], y + tooth[2], 1, 1, 6)
    end
    self:rect(x + 3, y + 3, 1, 1, 13)
  elseif kind == "R" then
    self:rect(x + 3, y, 1, 7, 8)
    self:rect(x, y + 3, 7, 1, 8)
  elseif kind == "B" then
    self:rect(x, y, 7, 7, 7)
    self:rect(x + 1, y + 1, 5, 5, 8)
    self:rect(x + 2, y + 2, 3, 3, 14)
  elseif kind == "I" then
    self:rect(x + 2, y, 3, 7, 4)
    self:rect(x + 3, y, 1, 7, 13)
    self:rect(x + 1, y + 1, 5, 1, 6)
    self:rect(x + 1, y + 5, 5, 1, 6)
  elseif kind == "Q" then
    self:rect(x, y, 7, 7, 13)
    self:rect(x + 1, y + 1, 5, 5, 2)
    self:rect(x + 2, y + 2, 3, 3, 7)
  elseif kind == "V" then
    self:rect(x, y + 1, 7, 5, 7)
    self:rect(x + 1, y + 2, 5, 3, 2)
    self:rect(x + 1, y + 3, 1, 1, 13)
    self:rect(x + 5, y + 3, 1, 1, 13)
  elseif kind == "D" then
    self:rect(x, y + 2, 7, 3, 4)
    for n = 1, 5, 2 do
      self:rect(x + n, y + 3, 1, 1, 13)
    end
  else
    self:rect(x + 1, y, 5, 7, 13)
    self:rect(x + 2, y + 1, 3, 5, 2)
    self:rect(x + 3, y, 1, 7, kind == "C" and 8 or 6)
  end
end
-- A directional hook uses only six pixels. The color and shape both indicate
-- direction so users are not dependent on color perception alone.
function R:spinMark(x, y, sign)
  local color = sign > 0 and 11 or 14
  self:rect(x + 1, y, 3, 1, color)
  self:rect(x, y + 1, 1, 2, color)
  self:rect(x + 4, y + 1, 1, 3, color)
  if sign > 0 then
    self:rect(x + 3, y + 3, 3, 1, color)
    self:rect(x + 4, y + 4, 1, 1, color)
  else
    self:rect(x - 1, y + 3, 3, 1, color)
    self:rect(x, y + 4, 1, 1, color)
  end
end
-- Compact 7..12px glyphs for later 10x10 stages. The same indexed
-- palette and kinetic states apply, without drawing outside a grid cell.
function R:compactPiece(x, y, size, tile, light)
  local cx, cy = x + math.floor(size / 2), y + math.floor(size / 2)
  local spin = motionFor(tile, light)
  if tile.kind == "R" or tile.kind == "B" then
    return
  end
  if tile.kind == "X" then
    self:rect(x, y, size, size, 4)
    self:rect(x + 1, y + 1, size - 2, size - 2, 2)
    return
  end
  if tile.kind == "S" or tile.kind == "M" then
    self:rect(x + 1, y + 1, size - 2, size - 2, tile.kind == "S" and 10 or (light and light.correct and 9 or 8))
    self:rect(cx - 1, cy - 1, 3, 3, 15)
    return
  end
  local color = spin and 6 or 7
  if tile.kind == "G" or tile.kind == "O" then
    local radius = math.max(2, math.floor(size / 2) - 1)
    self:cog(cx, cy, tile.kind == "O", spin, radius)
  else
    self:rect(cx - 2, cy - 2, 5, 5, tile.kind == "I" and 13 or color)
    self:rect(cx - 1, cy - 1, 3, 3, tile.kind == "C" and light and light.redstone and 8 or 2)
    if tile.kind == "I" then
      if tile.r % 2 == 1 then
        self:rect(x, cy, size, 1, 13)
      else
        self:rect(cx, y, 1, size, 13)
      end
    end
  end
  if tile.kind ~= "G" and tile.kind ~= "O" then
    self:rect(cx, cy, 1, 1, 1)
  end
  if spin and tile.kind ~= "G" and tile.kind ~= "O" then
    self:rect(x, y + math.floor(size / 2), 1, 2, spin.sign > 0 and 11 or 14)
  end
end
function R:redstonePiece(g, tile, result, x, y, size)
  local cx, cy = x + math.floor(size / 2), y + math.floor(size / 2)
  local powered = result.redstone[tile.id]
  local ink = powered and 8 or 7
  if tile.kind == "B" then
    local radius = math.max(2, math.floor((size - 3) / 2))
    self:rect(cx - radius, cy - radius, 2 * radius + 1, 2 * radius + 1, 7)
    self:rect(cx - radius + 1, cy - radius + 1, 2 * radius - 1, 2 * radius - 1, 8)
    self:rect(cx - 1, cy - 1, 3, 3, 14)
    return
  end
  local connection = E.wireConnections(g, tile)
  if connection[1] then
    self:rect(cx, y, 1, cy - y + 1, ink)
  end
  if connection[2] then
    self:rect(cx, cy, x + size - cx, 1, ink)
  end
  if connection[3] then
    self:rect(cx, cy, 1, y + size - cy, ink)
  end
  if connection[4] then
    self:rect(x, cy, cx - x + 1, 1, ink)
  end
  self:rect(cx - 1, cy - 1, 3, 3, ink)
  if size >= 12 then
    self:rect(cx - 2, cy, 1, 1, ink)
    self:rect(cx + 2, cy, 1, 1, ink)
  end
  self:rect(cx, cy, 1, 1, powered and 14 or 4)
end
function R:piece(x, y, size, tile, light)
  if tile.kind == "X" then
    self:rect(x, y, size, size, 2)
    for k = 1, size - 1, 3 do
      self:line(x + k, y + 1, x + 1, y + k, 3)
    end
    self:font(x + 4, y + 3, "X", 4)
    return
  end
  if size < 13 then
    self:compactPiece(x, y, size, tile, light)
    return
  end
  local spin = motionFor(tile, light)
  local cx, cy = x + math.floor(size / 2), y + math.floor(size / 2)
  if tile.kind == "M" then
    self:shaft(x, y, cx, cy, tile, spin)
    self:rect(x + 1, y + 1, size - 2, size - 2, light and light.correct and 9 or 8)
    self:rect(x + 2, y + 2, size - 4, size - 4, 1)
    self:font(x + 3, y + 2, tile.sign > 0 and ">" or "<", tile.sign > 0 and 11 or 14)
    self:font(x + 3, y + 7, tostring(tile.speed):sub(1, 2), 15)
    return
  end
  if tile.kind == "S" then
    self:rect(x + 1, y + 1, size - 2, size - 2, 10)
    self:rect(x + 2, y + 2, size - 4, size - 4, 3)
    self:font(x + 2, y + 3, "IN", 15)
  end
  self:shaft(x, y, cx, cy, tile, spin)
  if tile.kind == "G" or tile.kind == "O" then
    self:cog(cx, cy, tile.kind == "O", spin)
  elseif tile.kind == "Q" then
    self:rect(cx - 4, cy - 4, 9, 9, 7)
    self:rect(cx - 3, cy - 3, 7, 7, 13)
    self:rect(cx - 2, cy - 2, 5, 5, 2)
    self:rect(cx - 1, cy - 1, 3, 3, 6)
    self:rect(cx, cy, 1, 1, 1)
  elseif tile.kind == "V" then
    self:rect(cx - 4, cy - 3, 9, 7, 7)
    self:rect(cx - 3, cy - 2, 7, 5, 2)
    self:rect(cx - 3, cy - 1, 2, 3, 13)
    self:rect(cx + 2, cy - 1, 2, 3, 13)
  elseif tile.kind == "D" then
    self:rect(cx - 4, cy - 4, 9, 9, 4)
    self:rect(cx - 3, cy - 3, 7, 7, 2)
    if tile.r % 2 == 1 then
      self:rect(cx - 3, cy, 7, 1, 13)
    else
      self:rect(cx, cy - 3, 1, 7, 13)
    end
    self:rect(cx - 1, cy - 1, 3, 3, 6)
  elseif tile.kind == "C" or tile.kind == "Z" then
    self:rect(cx - 4, cy - 3, 9, 7, 13)
    self:rect(cx - 3, cy - 2, 7, 5, 2)
    self:rect(cx - 1, cy - 3, 3, 7, tile.engaged and 8 or 6)
    self:rect(cx, cy - 2, 1, 5, 1)
  elseif tile.kind == "I" then
    self:rect(cx - 1, cy - 1, 3, 3, 13)
  end
  if spin and tile.kind ~= "G" and tile.kind ~= "O" then
    -- Distinct CW/CCW ink remains outside the mechanism face.
    self:rect(x, y + math.floor(size / 2), 1, 2, spin.sign > 0 and 11 or 14)
  end
end
-- Draw belts/chains across every intervening cell, including stone. Draw over
-- the board but stop at endpoint edges so the pulley sprites stay readable.
function R:drawSpan(x1, y1, x2, y2, kind, powered, motion)
  local dx = x2 > x1 and 1 or (x2 < x1 and -1 or 0)
  local dy = y2 > y1 and 1 or (y2 < y1 and -1 or 0)
  local length = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
  if length == 0 then
    return
  end
  local rail = kind == "V" and 7 or 11
  self:line(x1 - dy * 2, y1 + dx * 2, x2 - dy * 2, y2 + dx * 2, rail)
  self:line(x1 + dy * 2, y1 - dx * 2, x2 + dy * 2, y2 - dx * 2, rail)
  for n = 0, length, 4 do
    local x = x1 + dx * n
    local y = y1 + dy * n
    self:line(x - dy * 2, y + dx * 2, x + dy * 2, y - dx * 2, kind == "D" and (n % 8 == 0 and 15 or 4) or 13)
  end
  if powered and motion then
    local speed = math.min(motion.rate, 8)
    local phase = math.floor(self.frame * speed * motion.sign)
    for n = 0, length do
      -- Opposing strands move in opposite directions and reverse with spin.
      if (n + phase) % 5 == 0 then
        self:rect(x1 + dx * n - dy * 2, y1 + dy * n + dx * 2, 1, 1, 11)
      end
      if (n - phase) % 5 == 0 then
        self:rect(x1 + dx * n + dy * 2, y1 + dy * n - dx * 2, 1, 1, 14)
      end
    end
  end
end
function R:drawSpans(g, result)
  for _, tile in ipairs(g.tiles) do
    if tile.kind == "V" or tile.kind == "G" or tile.kind == "O" or tile.kind == "D" then
      for _, link in ipairs(E.meshes(g, tile)) do
        local other = link.tile
        if other.id > tile.id then
          local center = math.floor(self.cell / 2)
          local x1 = self.boardX + (tile.x - 1) * self.cell + center
          local y1 = self.boardY + (tile.y - 1) * self.cell + center
          local x2 = self.boardX + (other.x - 1) * self.cell + center
          local y2 = self.boardY + (other.y - 1) * self.cell + center
          local powered = result.lights[tile.id].powered and result.lights[other.id].powered
          local light = result.lights[tile.id]
          local motion = light.ports[tile.r] or light.ports[next(light.ports)]
          if link.belt then
            local dx = x2 > x1 and 1 or (x2 < x1 and -1 or 0)
            local dy = y2 > y1 and 1 or (y2 < y1 and -1 or 0)
            local inset = math.min(5, math.floor(self.cell / 3))
            self:drawSpan(x1 + dx * inset, y1 + dy * inset, x2 - dx * inset, y2 - dy * inset, "V", powered, motion)
          else
            local mx = math.floor((x1 + x2) / 2)
            local my = math.floor((y1 + y2) / 2)
            if link.chain then
              self:rect(mx - 2, my - 1, 5, 3, 4)
              self:rect(mx, my, 1, 1, powered and 11 or 13)
            else
              -- Visible contact teeth bridge the adjacent rims; this is NOT a shaft.
              self:rect(mx - 2, my, 2, 2, 7)
              self:rect(mx, my - 1, 2, 2, powered and 6 or 7)
              self:rect(mx + 2, my, 1, 2, 7)
            end
          end
        end
      end
    end
  end
end
-- Dynamic hit targets use the same coordinates as the graphics renderer.
-- On vanilla text monitors the targets are one-based character rectangles.
function R:add(x, y, w, h, action, arg, arg2)
  self.targets[#self.targets + 1] = { x = x, y = y, w = w, h = h, action = action, arg = arg, arg2 = arg2 }
end
function R:fontFit(x, y, label, color, width)
  local max = math.max(0, math.floor(width / 4))
  if max < 1 then
    return
  end
  self:font(x, y, tostring(label):sub(1, max), color)
end
-- Wrap mission descriptions by whole words. Glyphs in the compact font use
-- four horizontal pixels, so 42 characters occupy at most 168 pixels.
function R:wrapBriefingTip(value)
  local lines = {}
  local line = ""
  for word in tostring(value):gmatch("%S+") do
    if line ~= "" and #line + #word + 1 > 42 then
      lines[#lines + 1] = line
      line = word
    else
      line = line == "" and word or (line .. " " .. word)
    end
  end
  if line ~= "" then
    lines[#lines + 1] = line
  end
  return lines
end
function R:button(x, y, w, h, caption, action, arg, color)
  local active = action ~= nil
  self:rect(x, y, w, h, active and (color or 3) or 1)
  self:rect(x + 1, y + 1, w - 2, h - 2, active and 2 or 1)
  local text = tostring(caption)
  local max = math.max(1, math.floor((w - 4) / 4))
  text = text:sub(1, max)
  local tx = x + math.max(2, math.floor((w - #text * 4) / 2))
  self:font(tx, y + math.max(1, math.floor((h - 5) / 2)), text, active and 15 or 4)
  if action then
    self:add(x, y, w, h, action, arg)
  end
end
function R:page(title, subtitle)
  self:rect(0, 0, 200, 120, 0)
  self:rect(0, 0, 200, 15, 1)
  self:rect(0, 14, 200, 1, 6)
  self:fontFit(7, 5, title, 6, 184)
  if subtitle and subtitle ~= "" then
    self:fontFit(10, 19, subtitle, 11, 180)
  end
end
function R:bonusMark(g, x, y)
  if g.sandbox or g.custom or g.editor then
    return nil
  end
  for index, bonus in ipairs(E.levels[g.number].bonuses) do
    if
      (bonus.type == "clear_zone" and x >= bonus.x1 and x <= bonus.x2 and y >= bonus.y1 and y <= bonus.y2)
      or (bonus.type == "required_cell" and x == bonus.x and y == bonus.y)
    then
      return index, bonus.type == "clear_zone" and 6 or 11
    end
  end
end
function R:toCanvas(x, y)
  if self.mode == "graphics" then
    return (x - self.ox) / self.scale, (y - self.oy) / self.scale
  end
  return x, y
end
function R:boardCell(x, y)
  local px, py = self:toCanvas(x, y)
  local board = self.textBoard
  if self.mode == "graphics" then
    board = self.currentGameLayout and self.currentGameLayout.grid
    if not board then
      return nil
    end
    local cx, cy = math.floor((px - board.x) / self.cell) + 1, math.floor((py - board.y) / self.cell) + 1
    if px >= board.x and py >= board.y and px < board.x + board.w and py < board.y + board.h then
      return cx, cy
    end
  elseif board and px >= board.x and py >= board.y and px < board.x + board.w and py < board.y + board.h then
    return math.floor((px - board.x) / board.cellW) + 1, math.floor((py - board.y) / board.cellH) + 1
  end
end
function R:fixedFrame(x, y, size, tile, editor)
  if not tile.fixed or editor then
    return
  end
  self:rect(x, y, size, 1, 6)
  self:rect(x, y + size - 1, size, 1, 6)
  self:rect(x, y, 1, size, 6)
  self:rect(x + size - 1, y, 1, size, 6)
  self:rect(x, y, 2, 2, 15)
  if size >= 12 then
    self:rect(x + size - 5, y + 1, 3, 4, 1)
    self:rect(x + size - 4, y + 1, 1, 2, 15)
    self:rect(x + size - 5, y + 3, 3, 2, 6)
  end
end
function R:drawDrag(m)
  local drag = m.drag
  if self.mode ~= "graphics" or not drag or not drag.moved or (m.scene ~= "game" and m.scene ~= "editor") then
    return
  end
  local size = self.cell
  if drag.targetX and drag.targetY then
    local tx, ty = self.boardX + (drag.targetX - 1) * size, self.boardY + (drag.targetY - 1) * size
    local ink = drag.valid and 9 or 8
    self:rect(tx, ty, size, 2, ink)
    self:rect(tx, ty + size - 2, size, 2, ink)
    self:rect(tx, ty, 2, size, ink)
    self:rect(tx + size - 2, ty, 2, size, ink)
  end
  local px, py = drag.cursorX - drag.offsetX, drag.cursorY - drag.offsetY
  self:rect(px + 2, py + 2, size, size, 1)
  local tile = { kind = drag.kind, r = drag.r, id = -1, x = drag.targetX or 0, y = drag.targetY or 0 }
  local light = { powered = false }
  if drag.origin == "board" then
    local source = E.get(m.game, drag.fromX, drag.fromY)
    light = source and m.result.lights[source.id] or light
  end
  if tile.kind == "R" or tile.kind == "B" then
    self:redstonePiece(m.game, tile, { redstone = {} }, px, py, size)
  else
    self:piece(px, py, size, tile, light)
  end
  self:rect(px, py, size, 1, drag.valid and 11 or 8)
end
-- An unmodified full frame is the source for every drag preview.
-- Keeping the underlying scene intact avoids rebuilding the entire board,
-- UI and simulation for each mouse_drag event on CraftOS/iPad.
function R:dragBounds(drag)
  if not drag or not drag.moved then
    return nil
  end
  local size = self.cell
  local px, py = drag.cursorX - drag.offsetX, drag.cursorY - drag.offsetY
  local b = { x1 = px - 2, y1 = py - 2, x2 = px + size + 4, y2 = py + size + 4 }
  if drag.targetX and drag.targetY then
    local tx = self.boardX + (drag.targetX - 1) * size
    local ty = self.boardY + (drag.targetY - 1) * size
    b.x1, b.y1 = math.min(b.x1, tx - 2), math.min(b.y1, ty - 2)
    b.x2, b.y2 = math.max(b.x2, tx + size + 2), math.max(b.y2, ty + size + 2)
  end
  return b
end
function R:drawDragPreview(m)
  if self.mode ~= "graphics" or not self.baseBuffer or not m.drag or not m.drag.moved then
    return self:draw(m)
  end
  -- The first frame of a board drag must remove its source tile from the
  -- cached scene. All subsequent pointer moves can use the cheap overlay.
  if m.drag.origin == "board" and not self.dragSourceHidden then
    return self:draw(m)
  end
  local bounds = self:dragBounds(m.drag)
  local old = self.previewBounds
  if old then
    bounds.x1, bounds.y1 = math.min(bounds.x1, old.x1), math.min(bounds.y1, old.y1)
    bounds.x2, bounds.y2 = math.max(bounds.x2, old.x2), math.max(bounds.y2, old.y2)
  end
  self.buffer = setmetatable({}, { __index = self.baseBuffer })
  self.overlayBase = self.baseBuffer
  self:drawDrag(m)
  self.overlayBase = nil
  self:flush(bounds)
  self.previewBounds = self:dragBounds(m.drag)
end
function R:drawBonusMarks(g)
  for y = 1, g.height do
    for x = 1, g.width do
      local mark, ink = self:bonusMark(g, x, y)
      if mark then
        local px, py = self.boardX + (x - 1) * self.cell, self.boardY + (y - 1) * self.cell
        local span = self.cell - 1
        self:rect(px, py, span, 1, ink)
        self:rect(px, py + span - 1, span, 1, ink)
        self:rect(px, py, 1, span, ink)
        self:rect(px + span - 1, py, 1, span, ink)
        if not E.get(g, x, y) and span >= 10 then
          self:font(px + 2, py + 2, mark == 1 and "A" or "B", ink)
        end
      end
    end
  end
end
function R:drawGame(m)
  local g, result = m.game, m.result
  self:page(
    g.editor and "COGWORKS  EDITOR"
      or (g.custom and "COGWORKS  USER PACK")
      or (g.sandbox and "COGWORKS  SANDBOX" or ("COGWORKS  " .. string.format("%02d/%02d", g.number, #E.levels)))
  )
  self:font(77, 5, "MV " .. g.moves, 4)
  -- Quick visible animation control: saves may have animations disabled.
  self:button(
    98,
    2,
    20,
    11,
    m.settings.animations and "RUN" or "OFF",
    "toggleAnimations",
    nil,
    m.settings.animations and 9 or 8
  )
  self:button(
    120,
    2,
    28,
    11,
    g.editor and "SAVE" or (g.sandbox and "CLEAR" or "SAVE"),
    g.editor and "editorSave" or (g.sandbox and "clearSandbox" or "save")
  )
  self:button(150, 2, 36, 11, g.editor and "MENU" or "PAUSE", g.editor and "editorMenu" or "pause")
  self:button(188, 2, 11, 11, "?", "help")
  self:rect(3, 16, 109, 94, 1)
  self:rect(4, 17, 107, 92, 3)
  self.cell = math.min(math.floor(105 / g.width), math.floor(90 / g.height))
  self.boardX = 5 + math.floor((105 - g.width * self.cell) / 2)
  self.boardY = 17 + math.floor((90 - g.height * self.cell) / 2)
  for y = 1, g.height do
    for x = 1, g.width do
      local px = self.boardX + (x - 1) * self.cell
      local py = self.boardY + (y - 1) * self.cell
      local size = self.cell - 1
      self:rect(px, py, size, size, 2)
      self:rect(px + math.floor(size / 2), py + math.floor(size / 2), 1, 1, 3)
    end
  end
  -- Spans sit behind components, not behind the board cells.
  self:drawSpans(g, result)
  local directions = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
  for y = 1, g.height do
    for x = 1, g.width do
      local px = self.boardX + (x - 1) * self.cell
      local py = self.boardY + (y - 1) * self.cell
      local size = self.cell - 1
      local tile = E.get(g, x, y)
      if tile then
        if tile.kind == "R" or tile.kind == "B" then
          self:redstonePiece(g, tile, result, px, py, size)
        else
          self:piece(px + 1, py + 1, size - 2, tile, result.lights[tile.id])
        end
        if m.settings.showPorts and tile.kind ~= "X" then
          for d = 0, 3 do
            if E.hasPort(tile, d) and not E.connection(g, tile, d) and tile.kind ~= "Q" then
              local radius = math.max(2, math.floor(size / 2) - 1)
              self:rect(
                px + radius + directions[d + 1][1] * radius,
                py + radius + directions[d + 1][2] * radius,
                1,
                1,
                8
              )
            end
          end
        end
      end
      self:add(px, py, size, size, "cell", x, y)
    end
  end
  self:drawBonusMarks(g)
  self:rect(114, 16, 83, 93, 1)
  self:rect(114, 16, 83, 1, 12)
  self:font(117, 19, "PARTS", 11)
  self:font(163, 19, g.sandbox and "FREE" or (result.correct .. "/" .. result.goals), result.win and 9 or 15)
  -- Two columns keep the eight Create-style mechanisms visible.
  for n, kind in ipairs(E.order) do
    local col = (n - 1) % 2
    local row = math.floor((n - 1) / 2)
    local x = 116 + col * 40
    local y = 26 + row * 10
    local count = g.remaining[kind] or 0
    local countText = count == math.huge and "++" or tostring(count)
    local active = m.selected == kind
    self:rect(x, y, 38, 9, active and 6 or 12)
    self:rect(x + 1, y + 1, 36, 7, active and 3 or 1)
    if active then
      -- A complete highlighted outline survives the 16-color terminal
      -- palette, and the small left tab stays visible beside the glyph.
      self:rect(x, y, 38, 1, 15)
      self:rect(x, y + 8, 38, 1, 6)
      self:rect(x, y, 1, 9, 6)
      self:rect(x + 37, y, 1, 9, 6)
      self:rect(x + 1, y + 3, 1, 3, 11)
    end
    self:toolIcon(x + 2, y + 1, kind)
    self:font(x + 11, y + 2, kind, active and 6 or 11)
    local alias = ({
      I = "SHFT",
      G = "COG",
      O = "LRGE",
      Q = "BOX",
      D = "CHN",
      V = "BELT",
      Z = "REV",
      C = "CLCH",
      R = "DUST",
      B = "BLOK",
    })[kind]
    self:fontFit(x + 17, y + 2, alias, count > 0 and 15 or 4, 14)
    self:font(x + 31, y + 2, countText, count > 0 and 9 or 4)
    self:add(x, y, 38, 9, "tool", kind)
  end
  self:button(
    117,
    77,
    38,
    9,
    m.selected == "erase" and "ERASE" or "REMOVE",
    "tool",
    "erase",
    m.selected == "erase" and 8 or 3
  )
  self:button(
    157,
    77,
    38,
    9,
    g.sandbox and ("SIZE " .. g.width) or "ROTATE",
    g.sandbox and "sandboxSize" or nil,
    g.sandbox and (5 + g.width % 6) or nil
  )
  if g.editor then
    self:font(117, 87, "EDITOR / SELECT A TOOL", 6)
    self:button(116, 93, 25, 8, "SRC", "editorTool", "S")
    self:button(143, 93, 25, 8, "GOAL", "editorTool", "M")
    self:button(170, 93, 25, 8, "WALL", "editorTool", "X")
    self:button(116, 102, 19, 7, "FIX", "editorFix")
    self:button(136, 102, 19, 7, "RATE", "editorRate")
    self:button(156, 102, 19, 7, "DIR", "editorSpin")
    self:button(176, 102, 19, 7, "TEST", "editorTest")
  else
    -- Persistent bonus objectives are visible while building.
    self:font(
      117,
      87,
      (g.sandbox or g.custom) and "UNLIMITED PARTS"
        or (#E.levels[g.number].bonuses == 0 and "NO BONUS GOALS" or "BONUS GOALS"),
      6
    )
    local bonuses = E.challenges(g, result)
    local awarded = (m.progress.awards and m.progress.awards[g.number]) or {}
    for i, bonus in ipairs(bonuses) do
      local y = 93 + (i - 1) * 8
      local done = awarded[bonus.id] or false
      self:rect(117, y, 4, 4, done and 9 or (bonus.earned and 6 or 5))
      local progressWidth = bonus.progress and (#bonus.progress * 4 + 4) or 0
      self:fontFit(124, y, bonus.name, done and 9 or (bonus.earned and 6 or 5), 70 - progressWidth)
      if bonus.progress then
        self:font(198 - progressWidth, y, bonus.progress, 11)
      end
      self:add(116, y - 1, 80, 8, "inspectBonus", bonus.id)
    end
  end
  if m.inspected then
    local chosen = E.get(g, m.inspected.x, m.inspected.y)
    if chosen then
      local px = self.boardX + (chosen.x - 1) * self.cell
      local py = self.boardY + (chosen.y - 1) * self.cell
      local span = self.cell - 1
      -- A four-sided frame marks which part is selected without dimming it.
      self:rect(px, py, span, 1, 11)
      self:rect(px, py + span - 1, span, 1, 11)
      self:rect(px, py, 1, span, 11)
      self:rect(px + span - 1, py, 1, span, 11)
      -- Place small unboxed glyphs on the grid corners. The targets are
      -- deliberately larger than the 3-pixel artwork for touch usability.
      local hitSize = math.min(5, math.floor((span + 1) / 2))
      if not chosen.fixed and chosen.kind ~= "R" and chosen.kind ~= "B" then
        self:rect(px + 1, py + 1, 3, 3, 2)
        self:rect(px + 2, py + 1, 2, 1, 11)
        self:rect(px + 1, py + 2, 1, 2, 11)
        self:rect(px + 3, py + 2, 1, 1, 11)
        self:add(px, py, hitSize, hitSize, "rotate", chosen.x, chosen.y)
      end
      if not chosen.fixed then
        local right = px + span - hitSize
        self:rect(right + 1, py + 1, 3, 3, 2)
        self:rect(right + 1, py + 1, 1, 1, 8)
        self:rect(right + 3, py + 1, 1, 1, 8)
        self:rect(right + 2, py + 2, 1, 1, 8)
        self:rect(right + 1, py + 3, 1, 1, 8)
        self:rect(right + 3, py + 3, 1, 1, 8)
        self:add(right, py, hitSize, hitSize, "remove", chosen.x, chosen.y)
      end
    end
  end
  self:rect(0, 109, 200, 11, 1)
  self:rect(0, 109, 200, 1, 6)
  local selected = E.parts[m.selected]
  local info = selected and (selected.name .. " - " .. T.descriptions[m.selected])
    or (T.descriptions[m.selected] or "SELECT A PART TO PLACE")
  local inspected = m.inspected and E.get(g, m.inspected.x, m.inspected.y)
  local light = inspected and result.lights[inspected.id]
  local motion = light and (light.ports[inspected.r] or light.ports[next(light.ports)])
  local statusText = motion
      and (inspected.kind .. " " .. (motion.sign > 0 and "CW " or "CCW ") .. (speedLabel(motion.rate) or "?"))
    or info
  local status = m.message
  if g.editor and m.inspected then
    local tile = E.get(g, m.inspected.x, m.inspected.y)
    if tile and tile.kind == "M" then
      status = "GOAL " .. tile.speed .. "X " .. (tile.sign == 1 and "CW" or "CCW") .. " / RATE + DIR TO EDIT"
    elseif tile then
      status = tile.kind .. (tile.fixed and " FIXED" or " MOVABLE") .. " / FIX TO TOGGLE"
    end
  end
  if status == "" then
    if result.win then
      status = "CLEARED! BONUS TASKS ARE OPTIONAL"
    elseif result.jam then
      status = "GEARS JAMMED"
    elseif g.sandbox then
      status = "FREE BUILD - NO TARGETS OR PART LIMITS"
    elseif m.hasLeftInput then
      status = "LEFT: PLACE/TURN   RIGHT: REMOVE"
    else
      status = statusText
    end
  end
  self:fontFit(3, 112, status, result.win and 9 or 5, result.win and 160 or 195)
  if result.win then
    self:button(166, 114, 32, 6, "MAP", "map")
  end
end
-- All briefings use the authored mission targets and inventory, never
-- independently maintained objective text.  Animation is non-blocking.
function R:drawBriefing(m)
  local b = m.briefing
  if self.lastBriefing ~= b then
    self.lastBriefing = b
    self.briefingFrame = 0
  end
  local motion = m.settings.animations ~= false
  local tick = motion and self.briefingFrame or 1000
  self.briefingFrame = math.min(self.briefingFrame + 1, 100000)
  self:rect(0, 0, 200, 120, 0)
  self:rect(0, 0, 200, 15, 1)
  self:font(8, 5, "COGWORKS / MISSION BRIEF", 6)
  self:font(164, 5, string.format("%02d/%02d", b.number, #E.levels), 15)
  self:rect(0, 14, 200, 1, 7)
  for x = 0, 199, 9 do
    local offset = motion and (tick * 2) % 9 or 0
    self:rect((x + offset) % 200, 13, 4, 1, 6)
  end
  -- A taller hero card reserves a real two-line description area.
  self:rect(7, 18, 186, 42, 3)
  self:rect(9, 20, 182, 38, 1)
  self:rect(10, 20, 2, 38, 6)
  self:rect(12, 57, 178, 1, 4)
  self:rect(11 + (motion and tick * 5 % 177 or 177), 19, 7, 2, 9)
  local titleX = 14 - math.max(0, 12 - tick) * 2
  if tick >= 2 then
    self:fontFit(15, 22, "LEVEL " .. string.format("%02d", b.number), 11, 95)
  end
  if tick >= 5 then
    self:fontLarge(titleX, 29, b.name, 15)
    self:rect(15, 41, math.min(172, (tick - 5) * 10), 1, 6)
  end
  if tick >= 9 then
    local lines = self:wrapBriefingTip(b.tip)
    local y = #lines == 1 and 48 or 45
    for _, line in ipairs(lines) do
      self:fontFit(15, y, line, 11, 172)
      y = y + 6
    end
  end
  -- Coupled cogwheel decoration lives clear of the mission title.
  for _, gear in ipairs({ { 177, 32, 4, 1 }, { 187, 39, 3, -1 } }) do
    local gx, gy, r, reverse = gear[1], gear[2], gear[3], gear[4]
    for tooth = 0, 7 do
      local a = (tooth / 4) * math.pi + (motion and tick * 0.16 * reverse or 0)
      self:rect(math.floor(gx + math.cos(a) * r), math.floor(gy + math.sin(a) * r), 2, 2, 7)
    end
    self:rect(gx - 1, gy - 1, 3, 3, 6)
    self:rect(gx, gy, 1, 1, 1)
  end
  -- Reclaim vertical space with compact objective/inventory rows, supporting
  -- the maximum of five targets and all nine part types without collisions.
  self:rect(7, 63, 108, 42, 3)
  self:rect(9, 65, 104, 38, 1)
  self:rect(119, 63, 74, 42, 3)
  self:rect(121, 65, 70, 38, 1)
  self:rect(12, 71, 98, 1, 11)
  self:rect(124, 71, 64, 1, 11)
  self:font(13, 65, "TARGETS " .. #b.targets, 6)
  self:font(124, 65, "PARTS " .. b.stockTotal, 6)
  for i, goal in ipairs(b.targets) do
    local y = 74 + (i - 1) * 6
    if tick >= 10 + i * 2 then
      self:rect(13, y - 1, 96, 6, i % 2 == 0 and 2 or 1)
      self:rect(15, y, 4, 4, goal.spin == "CCW" and 14 or 9)
      local caption = string.format("%d  %s %sX  C%d R%d", goal.number, goal.spin, tostring(goal.rpm), goal.x, goal.y)
      self:fontFit(22, y, caption, 15, 86)
    else
      self:rect(15, y, math.min(85, math.max(0, tick - 5 - i) * 7), 2, 3)
    end
  end
  for i, part in ipairs(b.stock) do
    if tick >= 8 + i then
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local x = 124 + col * 33
      local y = 74 + row * 6
      self:rect(x, y - 1, 31, 6, 2)
      self:rect(x + 1, y, 6, 5, E.parts[part.kind].color)
      self:font(x + 2, y, part.kind, 0)
      local labels = {
        I = "SHFT",
        G = "COG",
        O = "LG",
        Q = "BOX",
        D = "CHN",
        V = "BELT",
        Z = "SHIFT",
        C = "CLTCH",
        R = "DUST",
        B = "BLOCK",
      }
      self:fontFit(x + 9, y, labels[part.kind], 15, 16)
      self:font(x + 26, y, tostring(part.count), 6)
    end
  end
  self:rect(0, 107, 200, 13, 1)
  self:rect(0, 107, 200, 1, 7)
  local extras = {}
  for _, objective in ipairs(b.bonus or {}) do
    extras[#extras + 1] = objective.name
  end
  local bonus = #extras > 0 and ("BONUS " .. table.concat(extras, " / ")) or "BUILD TO BEGIN"
  self:fontFit(9, 111, bonus, 11, 121)
  self:rect(131, 112, 4, 4, motion and tick % 8 < 4 and 9 or 6)
  -- Entire screen is a usable tap target, with a prominent START button.
  self:add(0, 0, 200, 120, "beginLevel")
  self:button(141, 109, 54, 10, "START", "beginLevel", nil, 6)
end
function R:drawTutorial(m)
  self:drawGame(m)
  -- Ponder is modal: touches must not rotate the underlying machinery.
  self.targets = {}
  local lesson = m.tutorial.steps[m.tutorial.index]
  self:rect(11, 18, 178, 90, 0)
  self:rect(14, 21, 172, 84, 7)
  self:rect(16, 23, 168, 80, 1)
  self:fontFit(22, 28, "PONDER   " .. m.tutorial.index .. "/" .. #m.tutorial.steps, 6, 158)
  self:fontFit(22, 38, lesson.title, 15, 158)
  self:rect(22, 48, 156, 29, 2)
  local key = lesson.key
  local powered = { powered = true, correct = true }
  if key == "V" or key == "D" then
    self:piece(46, 55, 13, { kind = key, r = 1, enabled = true }, powered)
    self:piece(130, 55, 13, { kind = key, r = 1, enabled = true }, powered)
    self:drawSpan(59, 61, 129, 61, key, true)
    self:font(93, 51, key == "V" and "BELT" or "CHAIN", 6)
  else
    local rpm = key == "O" and 2 or 1
    local sign = (key == "G" or key == "O" or key == "Q") and -1 or 1
    self:piece(47, 55, 13, { kind = "S", r = 1 }, powered)
    self:line(60, 61, 76, 61, 6)
    self:piece(79, 55, 13, { kind = key, r = 1, enabled = true }, powered)
    self:line(92, 61, 116, 61, 6)
    self:piece(120, 55, 13, { kind = "M", r = 3, sign = sign, speed = rpm }, powered)
  end
  self:fontFit(23, 80, lesson.lines[1], 15, 155)
  self:fontFit(23, 87, lesson.lines[2], 11, 155)
  self:button(24, 94, 65, 9, "SKIP", "tutorialSkip")
  self:button(110, 94, 65, 9, m.tutorial.index == #m.tutorial.steps and "GOT IT" or "NEXT", "tutorialNext")
end
function R:drawTitle(m)
  self:page("COGWORKS", "KINETIC WORKSHOP / " .. #E.levels .. " PUZZLES")
  self:rect(27, 29, 146, 86, 1)
  self:rect(33, 32, 134, 80, 2)
  self:font(59, 36, "BUILD THE NETWORK", 6)
  local hasSave = false
  for _, slot in ipairs(m.slots) do
    if not slot.empty then
      hasSave = true
    end
  end
  local options = {
    { "CONTINUE", hasSave and "continue" or nil },
    { "SAVE SLOTS", "slots" },
    { "FREE SANDBOX", "sandbox" },
    { "LEVEL EDITOR", "editor" },
    { "CUSTOM PACKS", "packs" },
  }
  if m.dev then
    options[#options + 1] = { "DEV: ALL LEVELS", "devLevels" }
  end
  options[#options + 1] = { "SETTINGS", "settings" }
  options[#options + 1] = { "EXIT", "exit" }
  local spacing = 10
  for i, item in ipairs(options) do
    self:button(54, 39 + (i - 1) * spacing, 92, 9, item[1], item[2])
  end
end
function R:drawSlots(m)
  self:page("SELECT SAVE SLOT", "SELECT A SLOT TO LOAD OR START")
  for _, slot in ipairs(m.slots) do
    local y = 30 + (slot.number - 1) * 26
    self:rect(12, y, 176, 23, 2)
    self:font(20, y + 4, "SLOT " .. slot.number, 6)
    if slot.empty then
      self:font(20, y + 12, "EMPTY - NEW GAME", 5)
    else
      self:font(20, y + 12, "LEVEL " .. slot.level .. "/" .. #E.levels .. "   BONUSES " .. slot.trophies, 9)
    end
    self:add(12, y, 176, 23, "slot", slot.number)
  end
  self:button(69, 110, 62, 9, "BACK", "back")
end
function R:drawPause(m)
  self:page(
    "GAME PAUSED",
    m.game.sandbox and "SANDBOX / FREE BUILD"
      or (m.devSession and "DEV SESSION / LEVEL " .. m.game.number or "SLOT " .. m.slot .. " / LEVEL " .. m.game.number)
  )
  local items
  if m.game.sandbox then
    items = {
      { "RESUME", "resume" },
      { "CLEAR WORKSHOP", "clearSandbox" },
      { "SETTINGS", "settings" },
      { "HELP", "help" },
      { "TITLE MENU", "title" },
    }
  else
    items = {
      { "RESUME", "resume" },
      { "SAVE GAME", "save" },
      { "SELECT LEVEL", "levels" },
      { "SETTINGS", "settings" },
      { "HELP", "help" },
      { "RESTART LEVEL", "restart" },
      { "NEW CAMPAIGN", m.devSession and nil or "newGame" },
      { "TITLE MENU", "title" },
    }
  end
  for i, item in ipairs(items) do
    self:button(41, 24 + (i - 1) * 11, 118, 10, item[1], item[2])
  end
  if m.message and m.message ~= "" then
    self:fontFit(5, 114, m.message, 9, 185)
  end
end
function R:drawSettings(m)
  self:page("SETTINGS", "SAVED AUTOMATICALLY")
  self:rect(26, 34, 148, 67, 1)
  self:button(37, 43, 126, 13, "ANIMATION " .. (m.settings.animations and "ON" or "OFF"), "toggleAnimations")
  self:button(37, 61, 126, 13, "OPEN PORTS " .. (m.settings.showPorts and "ON" or "OFF"), "togglePorts")
  self:font(42, 84, "DISPLAY: CIVCRAFT DENSITY", 11)
  self:font(42, 92, "MONITOR SCALE: 0.5 IF SUPPORTED", 4)
  self:button(68, 108, 64, 10, "BACK", "back")
end
-- Compact navigable world / district maps inspired by spatial overworlds.
-- Dashed tracks are the actual adjacency graph, not decorative ordering.
local districtCoords = {
  { 8, 34 },
  { 56, 38 },
  { 104, 32 },
  { 152, 38 },
  { 152, 79 },
  { 104, 81 },
  { 56, 77 },
  { 8, 81 },
}
local districtNames = { "APPRENTICE", "ROUTES", "MOTION", "BELTS", "BRANCHES", "CONTROL", "REPAIRS", "MASTER" }
local function dottedTrack(renderer, x1, y1, x2, y2, shade)
  local dx, dy = x2 - x1, y2 - y1
  local distance = math.sqrt(dx * dx + dy * dy)
  for t = 0, distance, 6 do
    local f = distance == 0 and 0 or t / distance
    renderer:rect(math.floor(x1 + dx * f), math.floor(y1 + dy * f), 2, 2, shade)
  end
end
function R:drawLevels(m)
  local cleared = 0
  for _, chapter in ipairs(m.chapters) do
    cleared = cleared + Campaign.stats(m.progress, chapter.number).main
  end
  self:page("FACTORY OVERWORLD", "EXPLORE THE TRACKS / " .. cleared .. " OF 64 MACHINES RESTORED")
  -- Draw rails first so touch targets stay above them.
  for i = 1, 7 do
    local a, b = districtCoords[i], districtCoords[i + 1]
    local open = m.devSession or Campaign.unlocked(m.progress, i + 1)
    dottedTrack(self, a[1] + 20, a[2] + 8, b[1] + 20, b[2] + 8, open and 11 or 3)
  end
  for i, chapter in ipairs(m.chapters) do
    local x, y = districtCoords[i][1], districtCoords[i][2]
    local active = m.devSession or Campaign.unlocked(m.progress, i)
    local stats = Campaign.stats(m.progress, i)
    local color = active and (stats.main >= 3 and 9 or 6) or 3
    self:rect(x, y, 42, 19, color)
    self:rect(x + 1, y + 1, 40, 17, active and 1 or 0)
    self:fontFit(x + 3, y + 2, string.format("%d %s", i, districtNames[i]), active and 15 or 4, 36)
    local status = active and (stats.main .. "/8 CLEARED") or "SEALED"
    self:fontFit(x + 3, y + 10, status, active and 11 or 8, 36)
    if active then
      self:add(x, y, 42, 19, "chapter", i)
    end
  end
  self:fontFit(6, 105, "THREE CLEARS OPEN THE NEXT DISTRICT / REVISIT ANY TIME", 11, 188)
  self:button(78, 111, 44, 9, "BACK", "back")
end
function R:drawChapter(m)
  local chapter = m.chapters[m.levelChapter]
  local status = Campaign.stats(m.progress, m.levelChapter)
  self:page(
    "DISTRICT " .. m.levelChapter .. ": " .. chapter.name,
    status.main .. "/8 CLEARED / " .. status.bonuses .. " BONUS / PATHS OPEN FROM CLEARED NODES"
  )
  for _, edge in ipairs(Campaign.paths) do
    local a, b = Campaign.mapNodes[edge[1]], Campaign.mapNodes[edge[2]]
    local aLevel, bLevel = chapter.first + edge[1] - 1, chapter.first + edge[2] - 1
    local available = m.devSession
      or Campaign.levelUnlocked(m.progress, aLevel) and Campaign.levelUnlocked(m.progress, bLevel)
    dottedTrack(self, a[1] + 11, a[2] + 7, b[1] + 11, b[2] + 7, available and 11 or 3)
  end
  for i, pos in ipairs(Campaign.mapNodes) do
    local number = chapter.first + i - 1
    local stage = E.levels[number]
    local active = Campaign.levelUnlocked(m.progress, number, m.devSession)
    local finished = (m.progress.best or {})[number] ~= nil
    local awardCount = 0
    for _, yes in pairs(m.progress.awards[number] or {}) do
      if yes then
        awardCount = awardCount + 1
      end
    end
    local totalBonuses = #stage.bonuses
    local color = finished and 9 or (active and 6 or 3)
    local x, y = pos[1], pos[2]
    self:rect(x, y, 23, 15, color)
    self:rect(x + 1, y + 1, 21, 13, active and 1 or 0)
    local label = i == 7 and "EX" or (i == 8 and "FIN" or string.format("%02d", i))
    self:fontFit(x + 3, y + 2, label, active and 15 or 4, 17)
    if finished then
      self:rect(x + 18, y + 2, 3, 3, 9)
    end
    if totalBonuses > 0 and active then
      self:fontFit(x + 3, y + 9, awardCount .. "/" .. totalBonuses, 11, 17)
    end
    self:fontFit(math.max(1, x - 4), y + 16, stage.name, active and 11 or 8, 33)
    if active then
      self:add(x, y, 23, 16, "level", number)
    end
  end
  self:fontFit(5, 108, "EX = OPTIONAL EXPERT / FIN = OPTIONAL FINALE", 11, 185)
  self:button(77, 112, 46, 8, "WORLD MAP", "back")
end
local function listMenu(self, title, entries, action, page)
  self:page(title, "TOUCH A ROW TO SELECT / USE PAGE BUTTONS")
  page = page or 1
  for slot = 1, 7 do
    local index = (page - 1) * 7 + slot
    local item = entries[index]
    if item then
      local label = type(item) == "table" and (item.name or item.title) or item
      self:button(
        23,
        21 + slot * 11,
        154,
        10,
        tostring(index) .. " " .. tostring(label),
        action,
        type(item) == "table" and index or item
      )
    end
  end
  if page > 1 then
    self:button(15, 109, 48, 10, "PREV", "catalogPage", page - 1)
  end
  if page * 7 < #entries then
    self:button(136, 109, 48, 10, "NEXT", "catalogPage", page + 1)
  end
  self:button(72, 109, 56, 10, "BACK", "back")
end
function R:drawEditorMenu(m)
  self:page("LEVEL EDITOR", "SOURCE / TARGET / FIXTURES / STOCK")
  local options = {
    { "RESUME EDITING", "resume" },
    { "SAVE .COGLEVEL", "editorSave" },
    { "LOAD SAVED LEVEL", "editorLoad" },
    { "COMPILE .COGPACK", "editorCompile" },
    { "TEST GOAL NETWORK", "editorTest" },
    { "START NEW LEVEL", "editorNew" },
    { "TITLE MENU", "title" },
  }
  for i, item in ipairs(options) do
    self:button(34, 23 + i * 11, 132, 10, item[1], item[2])
  end
  self:fontFit(12, 108, m.message, 9, 170)
end
function R:drawEditorList(m)
  listMenu(self, "SAVED LEVEL FILES", m.editorFiles or {}, "editorLoadFile", m.catalogPage)
end
function R:drawPackList(m)
  listMenu(self, "COMPILED PACKS", m.packFiles or {}, "pack", m.catalogPage)
end
function R:drawPackLevels(m)
  listMenu(
    self,
    m.activePack and m.activePack.title or "USER PACK",
    m.activePack and m.activePack.levels or {},
    "packLevel",
    m.catalogPage
  )
end
function R:drawConfirm(m)
  self:page("CONFIRM ACTION")
  local new = m.pending == "newGame"
  self:fontFit(16, 42, new and "ERASE THIS SAVE SLOT?" or "RESTART CURRENT LEVEL?", 6, 168)
  self:font(18, 56, new and "PROGRESS WILL BE LOST" or "CURRENT BOARD WILL RESET", 8)
  self:button(28, 77, 68, 16, "CANCEL", "cancel")
  self:button(104, 77, 68, 16, "CONFIRM", "confirm")
end
function R:drawHelp(m)
  self:page("MACHINE LEGEND", "INPUT PORTS ARE NOT SPIN DIRECTION")
  local left = {
    "S: ENGINE CW 1X",
    "M: PRESS NEEDS CW/CCW",
    "I: STRAIGHT SHAFT",
    "G: AXIAL / SIDE COG",
    "O: LARGE 2X COG",
    "Q: REVERSE GEARBOX",
    "D: ENCASED CHAIN",
    "V: CLEAR-SPAN BELT",
    "Z: GEARSHIFT REVERSE",
    "C: CLUTCH CUT-OFF",
    "R: CENTERED REDSTONE DUST",
    "B: POWER BLOCK",
  }
  local right = {
    "CW = CLOCKWISE",
    "CCW = COUNTERCW",
    "GOAL: MATCH SPIN + RPM",
    "TAP EMPTY TO BUILD",
    "TAP PART: CORNER CONTROLS",
    "REMOVE TO RECLAIM",
    "COGS MESH PERPENDICULAR",
    "LARGE + SMALL = 2X",
    "BELTS NEED CLEAR SPACE",
    "REDSTONE POWERS SHIFT/CLUTCH",
    "BONUSES ARE OPTIONAL",
    "AUTO SAVES PER SLOT",
  }
  for i = 1, #left do
    local y = 23 + (i - 1) * 7
    self:fontFit(8, y, left[i], i < 3 and 6 or 15, 91)
    self:fontFit(105, y, right[i], 11, 90)
  end
  self:button(52, 109, 58, 10, "BACK", "back")
  if m.game and #T.forLevel(m.game.number) > 0 then
    self:button(113, 109, 83, 10, "REPLAY PONDER", "replayTutorial")
  end
end
function R:drawText(m)
  local t = self.m
  local w, h = t.getSize()
  t.setBackgroundColor(colors.black)
  t.setTextColor(colors.white)
  t.clear()
  local function label(x, y, s, fg, bg, width)
    if y < 1 or y > h or x < 1 or x > w then
      return
    end
    t.setCursorPos(x, y)
    t.setTextColor(fg or colors.white)
    t.setBackgroundColor(bg or colors.black)
    t.write((tostring(s) .. (" "):rep(width or 0)):sub(1, math.min(width or #tostring(s), w - x + 1)))
  end
  local function btn(x, y, width, caption, action, arg)
    label(x, y, caption, colors.black, colors.orange, width)
    if action then
      self:add(x, y, width, 1, action, arg)
    end
  end
  label(2, 1, "COGWORKS / " .. m.scene:upper(), colors.orange)
  if m.scene == "game" then
    local g = m.game
    local result = m.result
    local x0, y0 = 2, 3
    local columnWidth = math.min(6, math.max(4, math.floor((w - 2) / g.width)))
    local rowHeight = math.max(2, math.min(3, math.floor((h - 15) / g.height)))
    self.textBoard =
      { x = x0, y = y0, w = columnWidth * g.width, h = rowHeight * g.height, cellW = columnWidth, cellH = rowHeight }
    for y = 1, g.height do
      for x = 1, g.width do
        local p = E.get(g, x, y)
        local px = x0 + (x - 1) * columnWidth
        local py = y0 + (y - 1) * rowHeight
        local color = p
            and (p.kind == "M" and colors.blue or (p.kind == "S" and colors.green or (p.kind == "X" and colors.brown or colors.gray)))
          or colors.lightGray
        local fg = p and result.lights[p.id].powered and colors.yellow or colors.white
        local slots = {}
        for d = 0, 3 do
          slots[d + 1] = p and E.hasPort(p, d)
        end
        local mark = self:bonusMark(g, x, y)
        local labelText = p and (p.kind == "M" and (p.sign < 0 and "-" or "+") .. p.speed or p.kind)
          or (mark and (mark == 1 and "A" or "B") or ".")
        local motion = p and motionFor(p, result.lights[p.id])
        local readout = motion and ((motion.sign > 0 and ">" or "<") .. (speedLabel(motion.rate) or "?")) or ""
        local readoutColor = motion and (motion.sign > 0 and colors.lightBlue or colors.orange) or fg
        if rowHeight == 3 then
          label(px, py, slots[1] and "  ^  " or "     ", fg, color, columnWidth - 1)
        end
        label(
          px,
          py + rowHeight - 2,
          (slots[4] and "<" or " ") .. " " .. labelText .. (slots[2] and ">" or " "),
          fg,
          color,
          columnWidth - 1
        )
        label(
          px,
          py + rowHeight - 1,
          (readout .. "    "):sub(1, 4) .. (slots[3] and "v" or " "),
          readoutColor,
          color,
          columnWidth - 1
        )
        self:add(px, py, columnWidth - 1, rowHeight, "cell", x, y)
      end
    end
    label(
      2,
      g.height > 6 and 2 or 22,
      g.sandbox and ("SANDBOX " .. g.width .. "X" .. g.height .. " MV " .. g.moves)
        or ("GOALS " .. result.correct .. "/" .. result.goals .. " CW=+ CCW=- MV " .. g.moves),
      colors.lightBlue
    )
    local bonuses = E.challenges(g, result)
    local awards = m.progress.awards[g.number] or {}
    for i, bonus in ipairs(bonuses) do
      local row = math.max(23, y0 + g.height * rowHeight) + i - 1
      local name = bonus.name .. (bonus.progress and " " .. bonus.progress or "")
      label(2, row, (awards[bonus.id] and "[X] " or "[ ] ") .. name, awards[bonus.id] and colors.lime or colors.white)
      self:add(2, row, math.min(w - 2, #name + 4), 1, "inspectBonus", bonus.id)
    end
    local size = math.floor(w / 5)
    for i, kind in ipairs(E.order) do
      local row = h - 8 + math.floor((i - 1) / 5)
      local col = (i - 1) % 5
      btn(
        1 + col * size,
        row,
        size,
        (m.selected == kind and ">" or " ") .. kind .. " " .. (g.sandbox and "++" or (g.remaining[kind] or 0)),
        "tool",
        kind
      )
    end
    btn(1, h - 5, 12, "REMOVE", "tool", "erase")
    btn(
      15,
      h - 5,
      12,
      g.sandbox and ("SIZE " .. g.width) or "ROTATE",
      g.sandbox and "sandboxSize" or nil,
      g.sandbox and (5 + g.width % 6) or nil
    )
    btn(1, h - 4, 12, g.sandbox and "CLEAR" or "SAVE", g.sandbox and "clearSandbox" or "save")
    btn(15, h - 4, 12, "PAUSE", "pause")
    if result.win then
      btn(29, h - 4, 12, "NEXT", "next")
    end
    local part = E.parts[m.selected]
    label(1, h - 3, (part and part.name .. " - " or "") .. (T.descriptions[m.selected] or ""), colors.lightBlue)
    label(1, h - 2, m.message ~= "" and m.message or g.name, colors.orange)
  elseif m.scene == "briefing" then
    local b = m.briefing
    label(3, 3, string.format("LEVEL %02d / %02d", b.number, #E.levels), colors.orange)
    label(3, 5, b.name, colors.yellow)
    label(3, 7, b.tip, colors.lightBlue, nil, w - 4)
    label(3, 9, "OBJECTIVES: MATCH SPIN AND RPM", colors.lightBlue)
    for i, goal in ipairs(b.targets) do
      label(
        3,
        9 + i,
        string.format("%d. %s %sX AT %d,%d", i, goal.spin, tostring(goal.rpm), goal.x, goal.y),
        colors.white
      )
    end
    local stocks = {}
    for _, part in ipairs(b.stock) do
      stocks[#stocks + 1] = part.kind .. "=" .. part.count
    end
    label(3, 16, "PARTS: " .. table.concat(stocks, "  "), colors.yellow, nil, w - 4)
    label(3, 17, "BONUS GOALS ARE OPTIONAL", colors.lightBlue)
    btn(3, 18, 18, "START LEVEL", "beginLevel")
  elseif m.scene == "tutorial" then
    local current = m.tutorial.steps[m.tutorial.index]
    label(3, 4, "PONDER  " .. m.tutorial.index .. "/" .. #m.tutorial.steps, colors.orange)
    label(3, 7, current.title, colors.lightBlue)
    label(3, 11, current.lines[1], colors.white)
    label(3, 13, current.lines[2], colors.white)
    btn(3, 18, 18, "SKIP", "tutorialSkip")
    btn(23, 18, 18, m.tutorial.index == #m.tutorial.steps and "GOT IT" or "NEXT", "tutorialNext")
  elseif m.scene == "title" then
    label(3, 4, "KINETIC WORKSHOP  /  " .. #E.levels .. " PUZZLES", colors.lightBlue)
    local choices = {
      { "CONTINUE", "continue" },
      { "SAVE SLOTS", "slots" },
      { "FREE SANDBOX", "sandbox" },
      { "SETTINGS", "settings" },
      { "EXIT", "exit" },
    }
    if m.dev then
      table.insert(choices, 4, { "DEV: ALL LEVELS", "devLevels" })
    end
    local hasSave = false
    for _, slot in ipairs(m.slots) do
      if not slot.empty then
        hasSave = true
      end
    end
    for i, item in ipairs(choices) do
      btn(5, 7 + i * 3, math.min(w - 8, 34), item[1], i == 1 and not hasSave and nil or item[2])
    end
  elseif m.scene == "slots" then
    for i, slot in ipairs(m.slots) do
      local labelText = slot.empty and "EMPTY - NEW"
        or ("LV " .. slot.level .. "/" .. #E.levels .. " BONUS " .. slot.trophies)
      btn(4, 5 + (i - 1) * 4, math.min(w - 8, 42), "SLOT " .. i .. "  " .. labelText, "slot", i)
    end
    btn(4, h - 2, 16, "BACK", "back")
  elseif m.scene == "levels" then
    label(2, 3, "FACTORY OVERWORLD - CLEAR 3 IN EACH AREA TO ADVANCE", colors.lightBlue)
    for i, chapter in ipairs(m.chapters) do
      local open = m.devSession or Campaign.unlocked(m.progress, i)
      local stats = Campaign.stats(m.progress, i)
      btn(
        3,
        4 + i * 3,
        math.min(w - 6, 45),
        i .. " " .. chapter.name .. (open and (" " .. stats.main .. "/8") or " LOCKED"),
        open and "chapter" or nil,
        i
      )
    end
    btn(3, h - 2, 16, "BACK", "back")
  elseif m.scene == "chapter" then
    local chapter = m.chapters[m.levelChapter]
    label(2, 3, "CHAPTER " .. m.levelChapter .. " " .. chapter.name, colors.lightBlue)
    for step = 1, 8 do
      local i = chapter.first + step - 1
      local clear = (m.progress.best or {})[i] ~= nil
      local count = 0
      for _, yes in pairs(m.progress.awards[i] or {}) do
        if yes then
          count = count + 1
        end
      end
      local active = Campaign.levelUnlocked(m.progress, i, m.devSession)
      btn(
        3,
        4 + step * 3,
        math.min(w - 6, 50),
        string.format(
          "%02d %s %s B:%d/%d",
          i,
          E.levels[i].name,
          clear and "CLEAR" or (active and "OPEN" or "LOCK"),
          count,
          #E.levels[i].bonuses
        ),
        active and "level" or nil,
        i
      )
    end
    btn(3, h - 2, 16, "CHAPTERS", "back")
  else
    local choices = {}
    if m.scene == "pause" then
      if m.game.sandbox then
        choices = {
          { "RESUME", "resume" },
          { "CLEAR WORKSHOP", "clearSandbox" },
          { "SETTINGS", "settings" },
          { "HELP", "help" },
          { "TITLE MENU", "title" },
        }
      else
        choices = {
          { "RESUME", "resume" },
          { "SAVE GAME", "save" },
          { "SELECT LEVEL", "levels" },
          { "SETTINGS", "settings" },
          { "HELP", "help" },
          { "RESTART LEVEL", "restart" },
          { "NEW CAMPAIGN", m.devSession and nil or "newGame" },
          { "TITLE MENU", "title" },
        }
      end
    elseif m.scene == "settings" then
      choices = {
        { "ANIMATION " .. (m.settings.animations and "ON" or "OFF"), "toggleAnimations" },
        { "OPEN PORTS " .. (m.settings.showPorts and "ON" or "OFF"), "togglePorts" },
        { "BACK", "back" },
      }
    elseif m.scene == "confirm" then
      label(3, 5, m.pending == "newGame" and "DELETE SLOT PROGRESS?" or "RESTART LEVEL?")
      choices = { { "CANCEL", "cancel" }, { "CONFIRM", "confirm" } }
    else
      label(2, 4, "S: SOURCE  M: TARGET  I: SHAFT")
      label(2, 6, "G: COG  O: LARGE COG  Q: GEARBOX")
      label(2, 8, "D: CHAIN  V: BELT  Z: GEARSHIFT")
      label(2, 9, "C: CLUTCH; SWITCH TO TOGGLE")
      choices = { { "BACK", "back" } }
      if m.scene == "help" and m.game and #T.forLevel(m.game.number) > 0 then
        table.insert(choices, 1, { "REPLAY PONDER", "replayTutorial" })
      end
    end
    for i, item in ipairs(choices) do
      btn(5, 10 + (i - 1) * 2, math.min(w - 8, 38), item[1], item[2])
    end
  end
end
function R:draw(m)
  self.targets = {}
  if self.mode == "text" then
    self:drawText(m)
    return
  end
  self.buffer = {}
  -- Time-derived angles do not depend on how frequently UI events redraw.
  -- A deterministic override is exposed for sprite regression tests.
  self.motionNow = self.motionOverride or (m.settings and m.settings.animations ~= false and os.clock() or 0)
  if (self.wide or m.scene == "game" or m.scene == "editor") and self:drawResponsive(m) then
    self.baseBuffer = self.buffer
    self.dragSourceHidden = m.drag and m.drag.moved and m.drag.origin == "board" or false
    if m.drag and m.drag.moved then
      self.buffer = setmetatable({}, { __index = self.baseBuffer })
      self.overlayBase = self.baseBuffer
      self:drawDrag(m)
      self.overlayBase = nil
    end
    self.previewBounds = self:dragBounds(m.drag)
    self:flush()
    self.frame = self.frame + 1
    return
  end
  if m.scene == "game" or m.scene == "editor" then
    self:drawGame(m)
  elseif m.scene == "briefing" then
    self:drawBriefing(m)
  elseif m.scene == "tutorial" then
    self:drawTutorial(m)
  elseif m.scene == "title" then
    self:drawTitle(m)
  elseif m.scene == "slots" then
    self:drawSlots(m)
  elseif m.scene == "pause" then
    self:drawPause(m)
  elseif m.scene == "settings" then
    self:drawSettings(m)
  elseif m.scene == "levels" then
    self:drawLevels(m)
  elseif m.scene == "chapter" then
    self:drawChapter(m)
  elseif m.scene == "editorMenu" then
    self:drawEditorMenu(m)
  elseif m.scene == "editorList" then
    self:drawEditorList(m)
  elseif m.scene == "packList" then
    self:drawPackList(m)
  elseif m.scene == "packLevels" then
    self:drawPackLevels(m)
  elseif m.scene == "confirm" then
    self:drawConfirm(m)
  else
    self:drawHelp(m)
  end
  self.baseBuffer = self.buffer
  self.dragSourceHidden = m.drag and m.drag.moved and m.drag.origin == "board" or false
  if m.drag and m.drag.moved then
    self.buffer = setmetatable({}, { __index = self.baseBuffer })
    self.overlayBase = self.baseBuffer
    self:drawDrag(m)
    self.overlayBase = nil
  end
  self.previewBounds = self:dragBounds(m.drag)
  self:flush()
  self.frame = self.frame + 1
end
-- Vanilla CC:Tweaked monitor_touch reports 1-based CHARACTER coordinates
-- even when CC:Graphics mode 2 is enabled. Pixel hitboxes are zero-based.
-- Sample the center of the touched character cell, allowing the graphics
-- viewport to letterbox/scalably fill the actual monitor.
function R:hitTouch(charX, charY)
  local w, h = self.m.getSize()
  if type(charX) ~= "number" or type(charY) ~= "number" or charX < 1 or charY < 1 or charX > w or charY > h then
    return nil
  end
  if self.mode == "graphics" then
    return self:hit((charX - 0.5) * self.pw / w, (charY - 0.5) * self.ph / h)
  end
  return self:hit(charX, charY)
end
-- Optional FPB Monitor Input addon exposes normalized left-click positions.
-- Translate those into the renderer's own pixel or character coordinates.
function R:hitNormalized(nx, ny)
  if type(nx) ~= "number" or type(ny) ~= "number" or nx < 0 or nx >= 1 or ny < 0 or ny >= 1 then
    return nil
  end
  local x, y
  if self.mode == "graphics" then
    x = math.floor(nx * self.pw)
    y = math.floor(ny * self.ph)
  else
    local w, h = self.m.getSize()
    x = math.floor(nx * w) + 1
    y = math.floor(ny * h) + 1
  end
  return self:hit(x, y)
end
function R:hit(x, y)
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  if self.mode == "graphics" then
    x = (x - self.ox) / self.scale
    y = (y - self.oy) / self.scale
  end
  for i = #self.targets, 1, -1 do
    local b = self.targets[i]
    if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
      return b.action, b.arg, b.arg2
    end
  end
  return nil
end
require("games.cogworks.responsive")(R)
require("games.cogworks.create_art")(R)
require("games.cogworks.create_textures")(R)
return R
