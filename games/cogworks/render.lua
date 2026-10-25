-- COGWORKS / CC: Graphics pixel renderer with text fallback.
-- Coordinates in the pixel renderer are 128x88 logical units. Touch events
-- from Graphics mode 2 are zero-based PIXELS; vanilla monitor touch is 1-based.
local E = require("games.cogworks.engine")
local T = require("games.cogworks.tutorials")
local R = {}
R.__index = R
local palette = {
  [0] = 0x0E1A23,
  [1] = 0x172B37,
  [2] = 0x284250,
  [3] = 0x355866,
  [4] = 0x688993,
  [5] = 0xE6EBD7,
  [6] = 0xF3BC59,
  [7] = 0xC97E4E,
  [8] = 0xD35F51,
  [9] = 0x89D79F,
  [10] = 0x39745B,
  [11] = 0x83C2D7,
  [12] = 0x365E8D,
  [13] = 0xD9C391,
  [14] = 0xBE91E3,
  [15] = 0xFFF6E0,
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
  local self = setmetatable({ m = m, mode = "text", frame = 0, original = {}, boardX = 5, boardY = 17, cell = 15 }, R)
  self:enable()
  return self
end
function R:enable()
  local m = self.m
  self.tw, self.th = m.getSize()
  if m.setGraphicsMode and m.drawPixels then
    local ok = pcall(m.setGraphicsMode, 2)
    if ok then
      local good, w, h = pcall(m.getSize, 2)
      if good and type(w) == "number" and w >= 200 and h >= 120 then
        self.mode = "graphics"
        self.pw, self.ph = w, h
        self.scale = math.min(w / 200, h / 120)
        self.ox = math.floor((w - 200 * self.scale) / 2)
        self.oy = math.floor((h - 120 * self.scale) / 2)
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
      self.scale = math.min(w / 200, h / 120)
      self.ox = math.floor((w - 200 * self.scale) / 2)
      self.oy = math.floor((h - 120 * self.scale) / 2)
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
  local s = self.scale
  local x1 = math.max(0, math.floor(self.ox + x * s))
  local y1 = math.max(0, math.floor(self.oy + y * s))
  local x2 = math.min(self.pw, math.floor(self.ox + (x + w) * s))
  local y2 = math.min(self.ph, math.floor(self.oy + (y + h) * s))
  if x2 > x1 and y2 > y1 then
    self.m.drawPixels(x1, y1, color, x2 - x1, y2 - y1)
  end
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
function R:piece(x, y, size, tile, light)
  local running = light and light.powered
  local core = running and 6 or 4
  if tile.kind == "X" then
    self:rect(x, y, size, size, 2)
    for k = 1, size - 1, 3 do
      self:line(x + k, y + 1, x + 1, y + k, 3)
    end
    self:rect(x + 3, y + 3, size - 6, size - 6, 1)
    self:font(x + 4, y + 3, "X", 4)
    return
  end
  local bg = tile.kind == "S" and 10 or (tile.kind == "M" and (tile.sign < 0 and 14 or 12) or 2)
  self:rect(x, y, size, size, 3)
  self:rect(x + 1, y + 1, size - 2, size - 2, bg)
  if running then
    self:rect(x + 1, y + 1, size - 2, 1, 6)
  end
  local cx = x + math.floor(size / 2)
  local cy = y + math.floor(size / 2)
  if tile.kind == "M" then
    local active = light and light.correct
    self:rect(x + 2, y + 2, size - 4, size - 4, active and 9 or 8)
    self:rect(x + 3, y + 3, size - 6, size - 6, 1)
    local requirement = (tile.sign < 0 and "-" or "+") .. tostring(tile.speed)
    self:font(x + 1, y + math.floor(size / 2) - 2, requirement, active and 9 or 15)
  elseif tile.kind == "S" then
    self:rect(x + 3, y + 3, size - 6, size - 6, 6)
    self:font(x + 4, y + math.floor(size / 2) - 2, "S", 0)
  else
    -- Different mechanisms have different centerpieces, not just letter changes.
    if tile.kind == "G" or tile.kind == "O" then
      for i = 0, 7 do
        local a = (i * math.pi / 4) + (running and self.frame * 0.25 or 0)
        self:rect(
          math.floor(cx + 3 * math.cos(a)),
          math.floor(cy + 3 * math.sin(a)),
          2,
          2,
          tile.kind == "O" and 7 or 14
        )
      end
      self:rect(cx - 2, cy - 2, 5, 5, tile.kind == "O" and 7 or 14)
      self:rect(cx - 1, cy - 1, 3, 3, 1)
    elseif tile.kind == "Q" then
      self:rect(cx - 3, cy - 3, 7, 7, 13)
      self:rect(cx - 1, cy - 1, 3, 3, 1)
      self:rect(cx, cy, 1, 1, 15)
    elseif tile.kind == "V" then
      -- The paired rollers turn with the transmission axis.
      if tile.r % 2 == 1 then
        self:rect(cx - 4, cy - 3, 8, 2, 7)
        self:rect(cx - 4, cy + 2, 8, 2, 7)
        self:rect(cx - 4, cy - 2, 2, 5, 13)
        self:rect(cx + 2, cy - 2, 2, 5, 13)
      else
        self:rect(cx - 3, cy - 4, 2, 8, 7)
        self:rect(cx + 2, cy - 4, 2, 8, 7)
        self:rect(cx - 2, cy - 4, 5, 2, 13)
        self:rect(cx - 2, cy + 2, 5, 2, 13)
      end
    elseif tile.kind == "D" then
      if tile.r % 2 == 1 then
        for j = -3, 3, 2 do
          self:rect(cx + j, cy - 3, 1, 7, 11)
        end
        self:rect(cx - 3, cy - 3, 7, 1, 4)
        self:rect(cx - 3, cy + 3, 7, 1, 4)
      else
        for j = -3, 3, 2 do
          self:rect(cx - 3, cy + j, 7, 1, 11)
        end
        self:rect(cx - 3, cy - 3, 1, 7, 4)
        self:rect(cx + 3, cy - 3, 1, 7, 4)
      end
    elseif tile.kind == "Z" or tile.kind == "C" then
      self:rect(cx - 3, cy - 3, 7, 7, tile.engaged and 8 or 9)
      self:rect(cx - 2, cy - 2, 5, 5, 1)
      self:font(cx - 1, cy - 2, tile.kind, tile.engaged and 8 or 9)
    else
      self:rect(cx - 2, cy - 2, 5, 5, core)
      self:rect(cx - 1, cy - 1, 3, 3, 1)
      self:rect(cx, cy, 1, 1, 15)
    end
  end
  -- Port markings are consistent on all devices, including fixed terminals.
  for dir = 0, 3 do
    if E.hasPort(tile, dir) then
      local dx, dy = DX[dir + 1], DY[dir + 1]
      local sx = cx + dx * (math.floor(size / 2) - 1)
      local sy = cy + dy * (math.floor(size / 2) - 1)
      if dx ~= 0 then
        self:rect(math.min(cx, sx), cy - 1, math.abs(sx - cx) + 1, 3, core)
      else
        self:rect(cx - 1, math.min(cy, sy), 3, math.abs(sy - cy) + 1, core)
      end
      -- Moving bright dash denotes powered outlets.
      if running and tile.kind ~= "M" then
        local shift = 2 + (self.frame % 3)
        self:rect(cx + dx * shift, cy + dy * shift, 2, 2, 15)
      end
    end
  end
  -- Machines state rotation in plain CW / CCW text instead of relying
  -- on cryptic plus/minus symbols. The lower line is required RPM.
  if tile.kind == "M" then
    local ready = light and light.correct
    local text = tile.sign < 0 and "CCW" or "CW"
    local accent = ready and 9 or (tile.sign < 0 and 14 or 11)
    self:rect(x + 1, y + 1, size - 2, size - 2, accent)
    self:rect(x + 2, y + 2, size - 4, size - 4, 1)
    self:font(x + (text == "CW" and 3 or 0), y + 1, text, accent)
    local rpm = tostring(tile.speed)
    if #rpm <= 2 then
      self:font(x + math.floor((size - #rpm * 4) / 2), y + 7, rpm, 15)
    else
      self:font(x, y + 7, rpm, 15)
    end
  elseif tile.kind == "S" then
    self:rect(x + 1, y + 1, size - 2, size - 2, 10)
    self:font(x + 3, y + 1, "CW", 15)
    self:font(x + 3, y + 7, "1X", 6)
  end
end
-- Draw belts/chains across every intervening cell, including stone. Draw over
-- the board but stop at endpoint edges so the pulley sprites stay readable.
function R:drawSpan(x1, y1, x2, y2, kind, powered)
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
  if powered then
    for n = self.frame % 4, length, 8 do
      self:rect(x1 + dx * n, y1 + dy * n, 2, 2, 15)
    end
  end
end
function R:drawSpans(g, result)
  for _, tile in ipairs(g.tiles) do
    if tile.kind == "V" or tile.kind == "G" or tile.kind == "O" or tile.kind == "D" then
      for _, link in ipairs(E.meshes(g, tile)) do
        local other = link.tile
        if other.id > tile.id then
          local x1 = self.boardX + (tile.x - 1) * self.cell + 7
          local y1 = self.boardY + (tile.y - 1) * self.cell + 7
          local x2 = self.boardX + (other.x - 1) * self.cell + 7
          local y2 = self.boardY + (other.y - 1) * self.cell + 7
          local powered = result.lights[tile.id].powered and result.lights[other.id].powered
          if link.belt then
            local dx = x2 > x1 and 1 or (x2 < x1 and -1 or 0)
            local dy = y2 > y1 and 1 or (y2 < y1 and -1 or 0)
            self:drawSpan(x1 + dx * 6, y1 + dy * 6, x2 - dx * 6, y2 - dy * 6, "V", powered)
          else
            local mx = math.floor((x1 + x2) / 2)
            local my = math.floor((y1 + y2) / 2)
            self:rect(mx - 1, my - 1, 3, 3, powered and 6 or (link.chain and 11 or 14))
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
  self:rect(0, 14, 200, 1, 7)
  self:fontFit(7, 5, title, 6, 184)
  if subtitle and subtitle ~= "" then
    self:fontFit(10, 19, subtitle, 11, 180)
  end
end
function R:drawGame(m)
  local g, result = m.game, m.result
  self:page(g.sandbox and "COGWORKS  SANDBOX" or ("COGWORKS  " .. string.format("%02d/%02d", g.number, #E.levels)))
  self:font(77, 5, "MV " .. g.moves, 4)
  self:button(120, 2, 28, 11, "SAVE", "save")
  self:button(150, 2, 36, 11, "PAUSE", "pause")
  self:button(188, 2, 11, 11, "?", "help")
  self:rect(3, 16, 109, 94, 1)
  self:rect(4, 17, 107, 92, 3)
  local directions = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
  for y = 1, E.HEIGHT do
    for x = 1, E.WIDTH do
      local px = self.boardX + (x - 1) * self.cell
      local py = self.boardY + (y - 1) * self.cell
      self:rect(px, py, 14, 14, 2)
      self:rect(px + 6, py + 6, 2, 2, 3)
      local tile = E.get(g, x, y)
      if tile then
        self:piece(px + 1, py + 1, 13, tile, result.lights[tile.id])
        if m.settings.showPorts and tile.kind ~= "X" then
          for d = 0, 3 do
            if E.hasPort(tile, d) and not E.connection(g, tile, d) and tile.kind ~= "Q" then
              self:rect(px + 6 + directions[d + 1][1] * 6, py + 6 + directions[d + 1][2] * 6, 2, 2, 8)
            end
          end
        end
      end
      self:add(px, py, 14, 14, "cell", x, y)
    end
  end
  self:rect(114, 16, 83, 97, 1)
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
    self:rect(x, y, 38, 9, active and 6 or 3)
    self:rect(x + 1, y + 1, 36, 7, active and 2 or 1)
    self:rect(x + 2, y + 1, 7, 7, count > 0 and E.parts[kind].color or 4)
    self:font(x + 4, y + 2, kind, 0)
    local alias = ({
      I = "SHAFT",
      G = "COG",
      O = "LARGE",
      Q = "BOX",
      D = "CHAIN",
      V = "BELT",
      Z = "SHIFT",
      C = "CLUTCH",
    })[kind]
    self:fontFit(x + 11, y + 2, alias, count > 0 and 15 or 4, 20)
    self:font(x + 31, y + 2, countText, count > 0 and 9 or 4)
    self:add(x, y, 38, 9, "tool", kind)
  end
  self:button(117, 77, 38, 9, m.selected == "erase" and "ERASE" or "REMOVE", "tool", "erase",
    m.selected == "erase" and 8 or 3)
  self:button(157, 77, 38, 9, m.selected == "switch" and "ON/OFF" or "SWITCH", "tool", "switch",
    m.selected == "switch" and 6 or 3)
  -- Persistent bonus objectives are visible while building, not buried in
  -- a modal screen. Labels are deliberately short enough for this pane.
  self:font(117, 87, g.sandbox and "UNLIMITED PARTS" or "BONUS GOALS", 6)
  local bonuses = E.challenges(g, result)
  local awarded = (m.progress.awards and m.progress.awards[g.number]) or {}
  for i, bonus in ipairs(bonuses) do
    local y = 93 + (i - 1) * 5
    local done = awarded[bonus.id] or false
    local label = bonus.id == "sealed" and "NO OPEN PORTS"
      or (bonus.id == "master" and "ALL STOCK USED" or (bonus.description:match("%d+") or "?") .. " MOVE PAR")
    self:rect(117, y, 4, 4, done and 9 or (bonus.earned and 6 or 3))
    self:fontFit(124, y, label, done and 9 or (bonus.earned and 6 or 5), 70)
  end
  if #bonuses == 0 and not g.sandbox then
    self:font(124, 94, "FROM LEVEL 2", 4)
  end
  self:drawSpans(g, result)
  self:rect(0, 109, 200, 11, 1)
  self:rect(0, 109, 200, 1, 7)
  local selected = E.parts[m.selected]
  local info = selected and (selected.name .. " - " .. T.descriptions[m.selected])
    or (T.descriptions[m.selected] or "SELECT A PART TO PLACE")
  self:fontFit(3, 110, info, 11, 194)
  local status = m.message
  if status == "" then
    if result.win then
      status = "CLEARED! BONUS TASKS ARE OPTIONAL"
    elseif result.jam then
      status = "GEARS JAMMED"
    elseif m.hasLeftInput then
      status = "LEFT: PLACE/TURN   RIGHT: REMOVE"
    else
      status = "CW = CLOCKWISE  /  CCW = COUNTERCLOCKWISE"
    end
  end
  self:fontFit(3, 115, status, result.win and 9 or 5, 160)
  if result.win then
    self:button(166, 114, 32, 6, "NEXT", "next")
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
      local labels =
        { I = "SHFT", G = "COG", O = "LG", Q = "BOX", D = "CHN", V = "BELT", Z = "SHIFT", C = "CLTCH" }
      self:fontFit(x + 9, y, labels[part.kind], 15, 16)
      self:font(x + 26, y, tostring(part.count), 6)
    end
  end
  self:rect(0, 107, 200, 13, 1)
  self:rect(0, 107, 200, 1, 7)
  local extras = {}
  if b.bonus.sealed then
    extras[#extras + 1] = "SEAL"
  end
  if b.bonus.fullFactory then
    extras[#extras + 1] = "STOCK"
  end
  if b.bonus.precision then
    extras[#extras + 1] = "PAR"
  end
  local bonus = #extras > 0 and ("BONUS " .. table.concat(extras, "/")) or "BUILD TO BEGIN"
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
  }
  if m.dev then
    options[#options + 1] = { "DEV: ALL LEVELS", "devLevels" }
  end
  options[#options + 1] = { "SETTINGS", "settings" }
  options[#options + 1] = { "EXIT", "exit" }
  local spacing = m.dev and 11 or 13
  for i, item in ipairs(options) do
    self:button(54, 43 + (i - 1) * spacing, 92, 10, item[1], item[2])
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
  self:page("GAME PAUSED", m.game.sandbox and "SANDBOX / FREE BUILD"
    or (m.devSession and "DEV SESSION / LEVEL " .. m.game.number
    or "SLOT " .. m.slot .. " / LEVEL " .. m.game.number))
  local items = {
    { "RESUME", "resume" },
    { m.game.sandbox and "CLEAR WORKSHOP" or "SAVE GAME", m.game.sandbox and "clearSandbox" or "save" },
    { m.game.sandbox and "FREE WORKSHOP" or "SELECT LEVEL", m.game.sandbox and nil or "levels" },
    { "SETTINGS", "settings" },
    { "HELP", "help" },
    { m.game.sandbox and "CLEAR WORKSHOP" or "RESTART LEVEL", m.game.sandbox and "clearSandbox" or "restart" },
    { m.game.sandbox and "FREE BUILD" or "NEW CAMPAIGN", (m.game.sandbox or m.devSession) and nil or "newGame" },
    { "TITLE MENU", "title" },
  }
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
  self:font(42, 84, "DISPLAY: COMPACT PIXELS", 11)
  self:font(42, 92, "TEXT SCALE: 0.5", 4)
  self:button(68, 108, 64, 10, "BACK", "back")
end
function R:drawLevels(m)
  self:page("CHOOSE LEVEL", "UNLOCKED: " .. m.progress.unlocked .. "/" .. #E.levels)
  for i = 1, #E.levels do
    local x = 10 + ((i - 1) % 6) * 30
    local y = 30 + math.floor((i - 1) / 6) * 15
    local unlocked = m.devSession or i <= m.progress.unlocked
    self:button(x, y, 28, 12, string.format("%02d", i), unlocked and "level" or nil, i,
      m.game and i == m.game.number and 6 or 3)
  end
  self:button(70, 108, 60, 10, "BACK", "back")
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
    "SWITCH: REDSTONE ON",
  }
  local right = {
    "CW = CLOCKWISE",
    "CCW = COUNTERCW",
    "GOAL: MATCH SPIN + RPM",
    "TAP EMPTY TO BUILD",
    "TAP A PART TO ROTATE",
    "REMOVE TO RECLAIM",
    "COGS MESH PERPENDICULAR",
    "LARGE + SMALL = 2X",
    "BELTS NEED CLEAR SPACE",
    "REDSTONE TOGGLE TOOL",
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
    for y = 1, E.HEIGHT do
      for x = 1, E.WIDTH do
        local p = E.get(g, x, y)
        local px = x0 + (x - 1) * 6
        local py = y0 + (y - 1) * 3
        local color = p
            and (p.kind == "M" and colors.blue or (p.kind == "S" and colors.green or (p.kind == "X" and colors.brown or colors.gray)))
          or colors.lightGray
        local fg = p and result.lights[p.id].powered and colors.yellow or colors.white
        local slots = {}
        for d = 0, 3 do
          slots[d + 1] = p and E.hasPort(p, d)
        end
        local labelText = p and (p.kind == "M" and (p.sign < 0 and "-" or "+") .. p.speed or p.kind) or "."
        label(px, py, slots[1] and "  ^  " or "     ", fg, color, 5)
        label(px, py + 1, (slots[4] and "<" or " ") .. " " .. labelText .. (slots[2] and ">" or " "), fg, color, 5)
        label(px, py + 2, slots[3] and "  v  " or "     ", fg, color, 5)
        self:add(px, py, 5, 3, "cell", x, y)
      end
    end
    label(2, 22, g.sandbox and ("SANDBOX / FREE BUILD  MV " .. g.moves) or ("GOALS " .. result.correct .. "/" .. result.goals .. " CW=+ CCW=- MV " .. g.moves), colors.lightBlue)
    local bonuses = E.challenges(g, result)
    local awards = m.progress.awards[g.number] or {}
    for i, bonus in ipairs(bonuses) do
      local name = bonus.id == "sealed" and "SEAL ALL PORTS"
        or (bonus.id == "master" and "USE ALL STOCK" or "PRECISION MOVES")
      label(
        2,
        22 + i,
        (awards[bonus.id] and "[X] " or "[ ] ") .. name,
        awards[bonus.id] and colors.lime or colors.white
      )
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
    btn(15, h - 5, 12, "SWITCH", "tool", "switch")
    btn(1, h - 4, 12, "SAVE", "save")
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
      { "CONTINUE", "continue" }, { "SAVE SLOTS", "slots" },
      { "FREE SANDBOX", "sandbox" }, { "SETTINGS", "settings" }, { "EXIT", "exit" },
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
      local labelText = slot.empty and "EMPTY - NEW" or ("LV " .. slot.level .. "/" .. #E.levels .. " BONUS " .. slot.trophies)
      btn(4, 5 + (i - 1) * 4, math.min(w - 8, 42), "SLOT " .. i .. "  " .. labelText, "slot", i)
    end
    btn(4, h - 2, 16, "BACK", "back")
  elseif m.scene == "levels" then
    for i = 1, #E.levels do
      local col = (i - 1) % 6
      local row = math.floor((i - 1) / 6)
      local x = 2 + col * 7
      local y = 4 + row * 3
      btn(x, y, 6, string.format("%02d", i), (m.devSession or i <= m.progress.unlocked) and "level" or nil, i)
    end
    btn(3, h - 2, 16, "BACK", "back")
  else
    local choices = {}
    if m.scene == "pause" then
      if m.game.sandbox then
        choices = {
          { "RESUME", "resume" }, { "CLEAR WORKSHOP", "clearSandbox" },
          { "SETTINGS", "settings" }, { "HELP", "help" }, { "TITLE MENU", "title" },
        }
      else
        choices = {
          { "RESUME", "resume" }, { "SAVE GAME", "save" },
          { "SELECT LEVEL", "levels" }, { "SETTINGS", "settings" },
          { "HELP", "help" }, { "RESTART LEVEL", "restart" },
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
  local mon = self.m
  if mon.setFrozen then
    pcall(mon.setFrozen, true)
  end
  mon.drawPixels(0, 0, 0, self.pw, self.ph)
  if m.scene == "game" then
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
  elseif m.scene == "confirm" then
    self:drawConfirm(m)
  else
    self:drawHelp(m)
  end
  if mon.setFrozen then
    pcall(mon.setFrozen, false)
  end
  self.frame = self.frame + 1
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
return R
