local S = {}
function S.new(w, h)
  local palette = {}
  for i = 0, 15 do
    palette[2 ^ i] = { 0.2, 0.4, 0.6 }
  end
  local screen = { w = w, h = h, rows = {}, frames = {}, fg = 1, bg = 32768, x = 1, y = 1, mode = 0 }
  function screen.getPaletteColor(color)
    return table.unpack(palette[color])
  end
  function screen.setPaletteColor(color, r, g, b)
    palette[color] = { r, g, b }
  end
  function screen.getSize()
    return screen.w, screen.h
  end
  function screen.setCursorPos(x, y)
    assert(x >= 1 and x <= screen.w and y >= 1 and y <= screen.h, "Cursor outside terminal")
    screen.x, screen.y = x, y
  end
  function screen.setCursorBlink() end
  function screen.setBackgroundColor(c)
    screen.bg = c
  end
  function screen.setTextColor(c)
    screen.fg = c
  end
  function screen.clear()
    screen.rows = {}
  end
  function screen.write(s)
    assert(screen.x + #s - 1 <= screen.w, "Write overflow")
    local row = screen.rows[screen.y] or {}
    screen.rows[screen.y] = row
    for i = 1, #s do
      row[screen.x + i - 1] = { s:sub(i, i), screen.fg, screen.bg }
    end
    screen.x = screen.x + #s
  end
  function screen.setGraphicsMode(mode)
    screen.mode = mode
  end
  function screen.text()
    local lines = {}
    for y = 1, screen.h do
      local row = screen.rows[y] or {}
      local chars = {}
      for x = 1, screen.w do
        chars[x] = row[x] and row[x][1] or " "
      end
      lines[y] = table.concat(chars)
    end
    return table.concat(lines, "\n")
  end
  screen.colors = {
    white = 1,
    orange = 2,
    magenta = 4,
    lightBlue = 8,
    yellow = 16,
    lime = 32,
    pink = 64,
    gray = 128,
    lightGray = 256,
    cyan = 512,
    purple = 1024,
    blue = 2048,
    brown = 4096,
    green = 8192,
    red = 16384,
    black = 32768,
  }
  screen.keys =
    { up = 200, down = 208, enter = 28, escape = 1, backspace = 14, pageUp = 201, pageDown = 209, space = 57, tab = 15 }
  return screen
end
return S
