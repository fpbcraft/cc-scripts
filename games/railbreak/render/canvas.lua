-- Renderer uses character-cell logical coordinates; CC: Graphics supplies coloured pixels.
-- monitor_touch uses 1-based character coordinates in both modes.
local R = {}
R.__index = R
R.palette = {
  [0] = 0x101C26,
  [1] = 0x182A32,
  [2] = 0x243B43,
  [3] = 0x37545A,
  [4] = 0x708B86,
  [5] = 0xDBEBD7,
  [6] = 0xE8B75B,
  [7] = 0xCF8547,
  [8] = 0xB85B4B,
  [9] = 0x83C19A,
  [10] = 0x38765D,
  [11] = 0x8AB9C7,
  [12] = 0x4B8192,
  [13] = 0xE8D2A5,
  [14] = 0x836A56,
  [15] = 0x8A73B2,
  [16] = 0x34394F,
  [17] = 0xFCF1DB,
  [18] = 0xDB7A65,
  [19] = 0x1B3741,
  [20] = 0x2E464E,
  [21] = 0x32402E,
  [22] = 0x606D49,
  [23] = 0xF3E1B3,
}
local terminalColors = {
  [0] = 32768,
  [1] = 128,
  [2] = 2048,
  [3] = 256,
  [4] = 8,
  [5] = 1,
  [6] = 16,
  [7] = 2,
  [8] = 16384,
  [9] = 32,
  [10] = 8192,
  [11] = 512,
  [12] = 2048,
  [13] = 16,
  [14] = 4096,
  [15] = 1024,
  [16] = 8192,
  [17] = 1,
  [18] = 16384,
  [19] = 128,
  [20] = 256,
  [21] = 8192,
  [22] = 32,
  [23] = 16,
}
-- Compact 3x5 bitmap glyphs, each scaled to one monitor character cell.
local FONT = {
  ["A"] = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
  ["B"] = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
  ["C"] = { "01111", "10000", "10000", "10000", "10000", "10000", "01111" },
  ["D"] = { "11110", "10001", "10001", "10001", "10001", "10001", "11110" },
  ["E"] = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
  ["F"] = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
  ["G"] = { "01111", "10000", "10000", "10111", "10001", "10001", "01111" },
  ["H"] = { "10001", "10001", "10001", "11111", "10001", "10001", "10001" },
  ["I"] = { "11111", "00100", "00100", "00100", "00100", "00100", "11111" },
  ["J"] = { "00111", "00010", "00010", "00010", "10010", "10010", "01100" },
  ["K"] = { "10001", "10010", "10100", "11000", "10100", "10010", "10001" },
  ["L"] = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
  ["M"] = { "10001", "11011", "10101", "10101", "10001", "10001", "10001" },
  ["N"] = { "10001", "11001", "10101", "10011", "10001", "10001", "10001" },
  ["O"] = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" },
  ["P"] = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
  ["Q"] = { "01110", "10001", "10001", "10001", "10101", "10010", "01101" },
  ["R"] = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
  ["S"] = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
  ["T"] = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
  ["U"] = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
  ["V"] = { "10001", "10001", "10001", "10001", "10001", "01010", "00100" },
  ["W"] = { "10001", "10001", "10001", "10101", "10101", "10101", "01010" },
  ["X"] = { "10001", "10001", "01010", "00100", "01010", "10001", "10001" },
  ["Y"] = { "10001", "10001", "01010", "00100", "00100", "00100", "00100" },
  ["Z"] = { "11111", "00001", "00010", "00100", "01000", "10000", "11111" },
  ["0"] = { "01110", "10011", "10101", "10101", "11001", "10001", "01110" },
  ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
  ["2"] = { "01110", "10001", "00001", "00010", "00100", "01000", "11111" },
  ["3"] = { "11110", "00001", "00001", "00110", "00001", "00001", "11110" },
  ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" },
  ["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
  ["6"] = { "00111", "01000", "10000", "11110", "10001", "10001", "01110" },
  ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
  ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" },
  ["9"] = { "01110", "10001", "10001", "01111", "00001", "00010", "11100" },
  ["-"] = { "00000", "00000", "00000", "11111", "00000", "00000", "00000" },
  ["+"] = { "00000", "00100", "00100", "11111", "00100", "00100", "00000" },
  ["/"] = { "00001", "00001", "00010", "00100", "01000", "10000", "10000" },
  [":"] = { "00000", "00110", "00110", "00000", "00110", "00110", "00000" },
  ["."] = { "00000", "00000", "00000", "00000", "00000", "00110", "00110" },
  ["!"] = { "00100", "00100", "00100", "00100", "00100", "00000", "00100" },
  ["?"] = { "01110", "10001", "00001", "00110", "00100", "00000", "00100" },
  ["="] = { "00000", "11111", "00000", "11111", "00000", "00000", "00000" },
  [","] = { "00000", "00000", "00000", "00000", "00010", "00100", "01000" },
  ["("] = { "00010", "00100", "01000", "01000", "01000", "00100", "00010" },
  [")"] = { "01000", "00100", "00010", "00010", "00010", "00100", "01000" },
  ["%"] = { "11001", "11001", "00010", "00100", "01000", "10011", "10011" },
  [">"] = { "10000", "01000", "00100", "00010", "00100", "01000", "10000" },
  ["<"] = { "00001", "00010", "00100", "01000", "00100", "00010", "00001" },
  [" "] = { "00000", "00000", "00000", "00000", "00000", "00000", "00000" },
  ["'"] = { "00100", "00100", "00000", "00000", "00000", "00000", "00000" },
}
function R.new(m)
  local w, h = m.getSize()
  local self = setmetatable({ m = m, w = w, h = h, mode = "text", sx = 1, sy = 1, buttons = {}, draws = 0 }, R)
  if m.setGraphicsMode and m.drawPixels then
    local ok = pcall(m.setGraphicsMode, 2)
    if ok then
      local succeed, pw, ph = pcall(m.getSize, 2)
      if succeed and type(pw) == "number" and pw > w and ph > h then
        self.mode = "graphics"
        self.sx = pw / w
        self.sy = ph / h
        self.originalColors = {}
        if m.setPaletteColor then
          for i, c in pairs(R.palette) do
            if m.getPaletteColor then
              local ok2, r, g, b = pcall(m.getPaletteColor, i)
              if ok2 then
                self.originalColors[i] = { r, g, b }
              end
            end
            pcall(m.setPaletteColor, i, c)
          end
        end
      else
        pcall(m.setGraphicsMode, 0)
      end
    end
  end
  return self
end
function R:resize()
  self.w, self.h = self.m.getSize()
  if self.mode == "graphics" then
    local ok, w, h = pcall(self.m.getSize, 2)
    if ok then
      self.sx = w / self.w
      self.sy = h / self.h
    end
  end
end
function R:rect(x, y, w, h, color)
  x = math.floor(x)
  y = math.floor(y)
  w = math.ceil(w)
  h = math.ceil(h)
  local x2 = math.min(self.w, x + w)
  local y2 = math.min(self.h, y + h)
  x = math.max(0, x)
  y = math.max(0, y)
  if x2 <= x or y2 <= y then
    return
  end
  if self.mode == "graphics" then
    local px = math.floor(x * self.sx)
    local py = math.floor(y * self.sy)
    local width = math.max(1, math.floor(x2 * self.sx) - px)
    local height = math.max(1, math.floor(y2 * self.sy) - py)
    self.m.drawPixels(px, py, color, width, height)
  else
    self.m.setBackgroundColor(terminalColors[color] or 32768)
    for yy = y, y2 - 1 do
      self.m.setCursorPos(x + 1, yy + 1)
      self.m.write((" "):rep(x2 - x))
    end
  end
  self.draws = self.draws + 1
end
function R:line(x1, y1, x2, y2, color)
  local dx, dy = x2 - x1, y2 - y1
  local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy)) * 2))
  for i = 0, steps do
    local t = i / steps
    self:rect(x1 + dx * t, y1 + dy * t, 0.25, 0.25, color)
  end
end
function R:text(x, y, value, color, max)
  local s = tostring(value or ""):upper()
  if max then
    s = s:sub(1, max)
  end
  x = math.floor(x)
  y = math.floor(y)
  if y < 0 or y >= self.h or x >= self.w then
    return
  end
  if x < 0 then
    s = s:sub(1 - x)
    x = 0
  end
  s = s:sub(1, self.w - x)
  if #s == 0 then
    return
  end
  if self.mode == "text" then
    self.m.setCursorPos(x + 1, y + 1)
    self.m.setBackgroundColor(terminalColors[0])
    self.m.setTextColor(terminalColors[color] or 1)
    self.m.write(s)
    return
  end
  for i = 1, #s do
    local pattern = FONT[s:sub(i, i)] or FONT["?"]
    local left = math.floor((x + i - 1) * self.sx)
    local top = math.floor(y * self.sy)
    for cy = 1, 7 do
      local row = pattern[cy]
      for cx = 1, 5 do
        if row:sub(cx, cx) == "1" then
          local px = left + math.floor((cx - 1) * self.sx / 6)
          local py = top + math.floor((cy - 1) * self.sy / 9)
          local wide = math.max(1, math.floor(self.sx / 6))
          local tall = math.max(1, math.floor(self.sy / 9))
          self.m.drawPixels(px, py, color, wide, tall)
        end
      end
    end
  end
end
local SPRITES = {
  wheel = { "01110", "11011", "10101", "11011", "01110", "00100", "11111" },
  steam = { "00110", "01100", "11111", "10101", "10101", "11111", "01010" },
  shaft = { "00100", "00100", "11111", "00100", "11111", "00100", "00100" },
  gear = { "01110", "11011", "10101", "11011", "01110", "00100", "00100" },
  press = { "11111", "00100", "01110", "11111", "00100", "11111", "11111" },
  saw = { "00100", "01110", "11111", "01110", "00100", "11111", "10001" },
  crusher = { "10101", "11111", "10101", "11111", "10101", "11111", "10101" },
  mixer = { "10101", "01110", "00100", "11111", "10101", "11111", "01110" },
  assembler = { "01010", "11111", "01110", "10101", "01110", "11111", "11111" },
  belt = { "00000", "11111", "10001", "11101", "10001", "11111", "00000" },
  depot = { "11111", "10001", "10101", "10101", "10101", "10001", "11111" },
  chest = { "11111", "10001", "11111", "10101", "11111", "10001", "11111" },
  factory = { "00100", "11111", "11111", "10101", "10101", "11111", "11111" },
  build = { "00100", "00100", "11111", "00100", "00100", "00000", "00000" },
  train = { "10101", "11111", "01110", "01110", "11111", "10001", "10001" },
  info = { "01110", "10001", "00001", "00100", "00100", "00000", "00100" },
}
function R:bigText(x, y, value, color, scale)
  scale = math.max(1, math.floor(scale or 2))
  if self.mode == "text" then
    self:text(x, y, value, color)
    return
  end
  local str = tostring(value or ""):upper()
  for i = 1, #str do
    local pattern = FONT[str:sub(i, i)] or FONT["?"]
    local left = math.floor((x + (i - 1) * scale) * self.sx)
    local top = math.floor(y * self.sy)
    for cy = 1, 7 do
      for cx = 1, 5 do
        if pattern[cy]:sub(cx, cx) == "1" then
          local px = left + math.floor((cx - 1) * scale * self.sx / 6)
          local py = top + math.floor((cy - 1) * scale * self.sy / 9)
          local pw = math.max(1, math.floor(scale * self.sx / 6))
          local ph = math.max(1, math.floor(scale * self.sy / 9))
          self.m.drawPixels(px, py, color, pw, ph)
        end
      end
    end
  end
end
function R:icon(x, y, kind, color, scale)
  local fallback = {
    wheel = "W",
    steam = "E",
    shaft = "+",
    gear = "G",
    press = "P",
    saw = "S",
    crusher = "C",
    mixer = "M",
    assembler = "A",
    depot = "I",
    chest = "O",
    belt = ">",
    empty = ".",
    train = "T",
    map = "^",
    shift = ">",
    build = "+",
    tools = "G",
    help = "?",
    back = "<",
    contract = "!",
    gift = "*",
    settings = "=",
    stock = "O",
    check = "+",
    close = "X",
    factory = "F",
    road = "=",
    info = "I",
    play = ">",
    next = ">",
  }
  if self.mode == "text" or not SPRITES[kind] then
    return self:text(x, y, fallback[kind] or "?", color)
  end
  local pattern = SPRITES[kind]
  scale = math.max(1, math.floor(scale or 1))
  local left = math.floor(x * self.sx)
  local top = math.floor(y * self.sy)
  for cy = 1, 7 do
    for cx = 1, 5 do
      if pattern[cy]:sub(cx, cx) == "1" then
        local px = left + math.floor((cx - 1) * scale * self.sx / 6)
        local py = top + math.floor((cy - 1) * scale * self.sy / 9)
        local pw = math.max(1, math.floor(scale * self.sx / 6))
        local ph = math.max(1, math.floor(scale * self.sy / 9))
        self.m.drawPixels(px, py, color, pw, ph)
      end
    end
  end
end
function R:button(x, y, w, h, title, action, opt)
  opt = opt or {}
  if w <= 2 or h <= 1 then
    return
  end
  local tint = opt.color or 6
  self:rect(x, y, w, h, opt.disabled and 1 or 2)
  self:rect(x, y, 1, h, opt.disabled and 3 or tint)
  if opt.icon then
    self:icon(x + 2, y + 1, opt.icon, opt.disabled and 4 or tint)
  end
  self:text(x + (opt.icon and 4 or 2), y + 1, title, opt.disabled and 4 or 17, w - (opt.icon and 5 or 3))
  if opt.note and h >= 4 then
    self:text(x + 2, y + 2, opt.note, opt.disabled and 4 or 4, w - 3)
  end
  if not opt.disabled and action then
    self.buttons[#self.buttons + 1] = { x = x, y = y, w = w, h = h, fn = action, title = title }
  end
end
-- CC: Graphics replaces monitor_touch with ZERO-based PIXEL coordinates.
-- In mode 0, vanilla CC:Tweaked reports ONE-based CHARACTER coordinates.
-- Normalize once here, so button/tile hitboxes remain logical cell rectangles.
function R:touchCoords(x, y)
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil, nil
  end
  local lx, ly
  if self.mode == "graphics" then
    lx = math.floor(x / self.sx)
    ly = math.floor(y / self.sy)
  else
    lx = x - 1
    ly = y - 1
  end
  if lx < 0 or ly < 0 or lx >= self.w or ly >= self.h then
    return nil, nil
  end
  return lx, ly
end
function R:hit(x, y)
  for i = #self.buttons, 1, -1 do
    local b = self.buttons[i]
    if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
      b.fn()
      return true
    end
  end
  return false
end
function R:begin()
  self.buttons = {}
  self.draws = 0
  if self.mode == "graphics" and self.m.setFrozen then
    pcall(self.m.setFrozen, true)
  end
  self:rect(0, 0, self.w, self.h, 0)
end
function R:finish()
  if self.mode == "graphics" and self.m.setFrozen then
    pcall(self.m.setFrozen, false)
  end
end
function R:close()
  if self.mode == "graphics" then
    if self.originalColors and self.m.setPaletteColor then
      for i, rgb in pairs(self.originalColors) do
        pcall(self.m.setPaletteColor, i, rgb[1], rgb[2], rgb[3])
      end
    end
    if self.m.setGraphicsMode then
      pcall(self.m.setGraphicsMode, 0)
    end
  end
end
return R
