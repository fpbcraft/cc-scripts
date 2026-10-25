-- Shared windowed terminal for games designed around a large Advanced Monitor.
-- Renders to the computer terminal without changing its resolution. Arrow keys
-- pan the virtual workspace; mouse coordinates map back to virtual UI cells.
local V = {}
function V.new(native, width, height)
  local sw, sh = native.getSize()
  local self = {
    terminal = true,
    native = native,
    width = width,
    height = height,
    ox = 0,
    oy = 0,
    sw = sw,
    sh = sh,
    cx = 1,
    cy = 1,
    fg = colors.white,
    bg = colors.black,
    cells = {},
    dirty = true,
  }
  local function blank()
    return { char = " ", fg = colors.white, bg = colors.black }
  end
  for y = 1, height do
    local row = {}
    for x = 1, width do
      row[x] = blank()
    end
    self.cells[y] = row
  end
  local m = { terminal = true }
  function m.getSize()
    return self.width, self.height
  end
  function m.isColor()
    return native.isColor and native.isColor() or false
  end
  m.isColour = m.isColor
  function m.setTextColor(c)
    self.fg = c
  end
  m.setTextColour = m.setTextColor
  function m.setBackgroundColor(c)
    self.bg = c
  end
  m.setBackgroundColour = m.setBackgroundColor
  function m.getTextColor()
    return self.fg
  end
  function m.getBackgroundColor()
    return self.bg
  end
  function m.setCursorPos(x, y)
    self.cx, self.cy = math.floor(x), math.floor(y)
  end
  function m.getCursorPos()
    return self.cx, self.cy
  end
  function m.setCursorBlink() end
  function m.write(value)
    value = tostring(value)
    local y = self.cy
    if y >= 1 and y <= height then
      for i = 1, #value do
        local x = self.cx + i - 1
        if x >= 1 and x <= width then
          local cell = self.cells[y][x]
          cell.char = value:sub(i, i)
          cell.fg = self.fg
          cell.bg = self.bg
        end
      end
    end
    self.cx = self.cx + #value
    self.dirty = true
  end
  function m.blit(text, fg, bg)
    local colorMap = "0123456789abcdef"
    for i = 1, #text do
      local cf = colorMap:find(fg:sub(i, i), 1, true)
      local cb = colorMap:find(bg:sub(i, i), 1, true)
      local x = self.cx + i - 1
      if self.cy >= 1 and self.cy <= height and x >= 1 and x <= width then
        local cell = self.cells[self.cy][x]
        cell.char = text:sub(i, i)
        cell.fg = cf and 2 ^ (cf - 1) or colors.white
        cell.bg = cb and 2 ^ (cb - 1) or colors.black
      end
    end
    self.cx = self.cx + #text
    self.dirty = true
  end
  function m.clear()
    for y = 1, height do
      for x = 1, width do
        local c = self.cells[y][x]
        c.char = " "
        c.fg = self.fg
        c.bg = self.bg
      end
    end
    self.dirty = true
  end
  function m.clearLine()
    if self.cy >= 1 and self.cy <= height then
      for x = 1, width do
        local c = self.cells[self.cy][x]
        c.char = " "
        c.fg = self.fg
        c.bg = self.bg
      end
    end
    self.dirty = true
  end
  function m.scroll(lines)
    if lines > 0 then
      for _ = 1, math.min(lines, height) do
        table.remove(self.cells, 1)
        local row = {}
        for x = 1, width do
          row[x] = blank()
        end
        self.cells[#self.cells + 1] = row
      end
    elseif lines < 0 then
      for _ = 1, math.min(-lines, height) do
        table.remove(self.cells, #self.cells)
        local row = {}
        for x = 1, width do
          row[x] = blank()
        end
        table.insert(self.cells, 1, row)
      end
    end
    self.dirty = true
  end
  local function refresh()
    local w, h = native.getSize()
    self.sw, self.sh = w, h
    self.ox = math.max(0, math.min(self.ox, math.max(0, width - w)))
    self.oy = math.max(0, math.min(self.oy, math.max(0, height - h + 1)))
    local visible = math.max(1, h - 1)
    local colored = native.isColor and native.isColor()
    for py = 1, visible do
      local yy = self.oy + py
      if yy <= height then
        local row = self.cells[yy]
        local x = 1
        while x <= w do
          local cc = row[self.ox + x]
          local fg = cc and cc.fg or colors.white
          local bg = cc and cc.bg or colors.black
          local start = x
          local chars = {}
          repeat
            cc = row[self.ox + x]
            if not cc or cc.fg ~= fg or cc.bg ~= bg then
              break
            end
            chars[#chars + 1] = cc.char
            x = x + 1
          until x > w
          native.setCursorPos(start, py)
          native.setTextColor(colored and fg or colors.white)
          native.setBackgroundColor(colored and bg or colors.black)
          native.write(table.concat(chars))
          if x == start then
            x = x + 1
          end
        end
      else
        native.setCursorPos(1, py)
        native.setBackgroundColor(colors.black)
        native.write((" "):rep(w))
      end
    end
    native.setBackgroundColor(colors.gray)
    native.setTextColor(colors.white)
    native.setCursorPos(1, h)
    local status = ("VIEW %d,%d | ARROWS PAN | CLICK SELECT | ESC EXIT"):format(self.ox + 1, self.oy + 1)
    native.write((status .. (" "):rep(w)):sub(1, w))
    native.setCursorBlink(false)
    self.dirty = false
  end
  function m.present()
    refresh()
  end
  function m.pan(dx, dy)
    local w, h = native.getSize()
    self.ox = math.max(0, math.min(math.max(0, width - w), self.ox + dx))
    self.oy = math.max(0, math.min(math.max(0, height - h + 1), self.oy + dy))
    refresh()
  end
  function m.mouse(x, y)
    local w, h = native.getSize()
    if x < 1 or x > w or y < 1 or y >= h then
      return nil
    end
    return x + self.ox, y + self.oy
  end
  function m.viewport()
    return self.ox, self.oy
  end
  function m.close()
    native.setBackgroundColor(colors.black)
    native.setTextColor(colors.white)
    native.clear()
    native.setCursorPos(1, 1)
  end
  return m
end
return V
