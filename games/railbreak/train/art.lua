-- Flat indexed-colour pixel illustrations inspired by the approved CC Graphics HTML mock.
-- No external images, textures, gradients or web access; all sprites are deterministic primitives.
local A = {}
local function box(r, x, y, w, h, c)
  r:fill(x, y, w, h, c)
end
local function wheel(r, x, y, s)
  box(r, x - s * 5, y - s * 5, s * 10, s * 10, 15)
  box(r, x - s * 3, y - s * 3, s * 6, s * 6, 17)
  box(r, x - s, y - s, s * 2, s * 2, 15)
end
function A.sky(r, x, y, w, h, frame)
  box(r, x, y, w, h, 20)
  box(r, x, y + math.floor(h * 0.53), w, h * 0.47, 19)
  for i = 0, 5 do
    local cloudX = x + ((i * 67 + (frame or 0) * 2) % (math.max(30, w + 34))) - 12
    local cloudY = y + 4 + (i % 3) * 11
    box(r, cloudX, cloudY, 14, 3, 6)
    box(r, cloudX + 3, cloudY - 3, 10, 4, 24)
  end
  local peaks =
    { { 0, 0.82 }, { 0.16, 0.40 }, { 0.32, 0.80 }, { 0.47, 0.30 }, { 0.62, 0.70 }, { 0.81, 0.39 }, { 1, 0.77 } }
  for i = 1, #peaks - 1 do
    local a, b = peaks[i], peaks[i + 1]
    local start = math.floor(a[1] * w)
    local finish = math.floor(b[1] * w)
    for xx = start, finish, 3 do
      local progress = (xx - start) / math.max(1, finish - start)
      local top = y + h * (a[2] + (b[2] - a[2]) * progress)
      box(r, x + xx, top, 3, y + h - top, 4)
    end
  end
  local near = { { 0, 0.82 }, { 0.17, 0.65 }, { 0.36, 0.81 }, { 0.57, 0.58 }, { 0.77, 0.76 }, { 1, 0.62 } }
  for i = 1, #near - 1 do
    local a, b = near[i], near[i + 1]
    local start = math.floor(a[1] * w)
    local finish = math.floor(b[1] * w)
    for xx = start, finish, 3 do
      local t = (xx - start) / math.max(1, finish - start)
      local top = y + h * (a[2] + (b[2] - a[2]) * t)
      box(r, x + xx, top, 3, y + h - top, 22)
    end
  end
  box(r, x, y + h - 16, w, 16, 21)
end
function A.track(r, x, y, w)
  box(r, x, y, w, 2, 17)
  box(r, x, y + 6, w, 2, 17)
  for i = 0, w, 10 do
    box(r, x + i, y - 2, 5, 12, 16)
  end
end
function A.loco(r, x, y, s)
  local function b(dx, dy, w, h, c)
    box(r, x + dx * s, y + dy * s, w * s, h * s, c)
  end
  b(5, 19, 56, 18, 15)
  b(8, 10, 36, 16, 10)
  b(11, 12, 31, 11, 9)
  b(13, 14, 21, 3, 8)
  b(40, 5, 13, 24, 2)
  b(40, 5, 13, 1, 8)
  b(43, 8, 7, 7, 13)
  b(44, 9, 5, 5, 6)
  b(2, 29, 58, 8, 15)
  b(0, 35, 62, 5, 10)
  b(0, 38, 62, 3, 8)
  b(9, 1, 9, 11, 15)
  b(7, 0, 13, 3, 4)
  b(10, 4, 6, 7, 3)
  b(20, 6, 7, 4, 15)
  b(30, 8, 5, 3, 15)
  b(2, 26, 7, 7, 8)
  b(6, 28, 3, 3, 6)
  b(52, 26, 12, 6, 10)
  for i = 0, 2 do
    wheel(r, x + (13 + i * 16) * s, y + 39 * s, (i == 0 and 5 or 6) * s / 5)
  end
  b(10, 37, 41, 1, 8)
  b(16, 34, 21, 2, 5)
end
function A.wagon(r, x, y, id, s)
  local function b(dx, dy, w, h, c)
    box(r, x + dx * s, y + dy * s, w * s, h * s, c)
  end
  b(1, 33, 51, 6, 15)
  b(1, 35, 51, 3, 10)
  wheel(r, x + 12 * s, y + 40 * s, 4 * s / 5)
  wheel(r, x + 42 * s, y + 40 * s, 4 * s / 5)
  if id == "cargo" then
    b(4, 13, 44, 21, 16)
    b(4, 13, 44, 2, 9)
    for i = 0, 2 do
      b(7 + i * 13, 16, 11, 14, i == 1 and 10 or 9)
      b(11 + i * 13, 18, 3, 9, 8)
    end
    b(5, 12, 43, 2, 8)
  elseif id == "passenger" then
    b(3, 8, 46, 26, 10)
    b(4, 7, 45, 4, 15)
    for i = 0, 3 do
      b(7 + i * 10, 12, 8, 11, 6)
      b(8 + i * 10, 13, 6, 9, 13)
    end
    b(5, 27, 43, 4, 8)
  elseif id == "crane" then
    b(6, 21, 41, 12, 4)
    b(25, 1, 3, 23, 8)
    b(24, 2, 28, 3, 9)
    b(46, 5, 2, 16, 6)
    b(43, 18, 7, 3, 8)
    b(7, 24, 12, 7, 9)
  elseif id == "fuel" then
    b(3, 14, 46, 20, 15)
    b(8, 10, 37, 8, 4)
    b(10, 15, 33, 14, 5)
    b(13, 12, 27, 3, 15)
  else
    b(3, 13, 46, 21, 4)
    b(7, 8, 16, 10, 9)
    b(31, 11, 14, 15, 10)
  end
end
-- Relative geometry returned so UI can attach wagon tap targets to the same visible sprites.
function A.train(r, x, y, w, h, wagons, frame, selectIndex)
  A.sky(r, x, y, w, h, frame)
  local railY = y + h - 19
  A.track(r, x, railY, w)
  local count = math.min(#wagons, 6)
  local base = 63 + math.max(0, count - 1) * 56
  local s = math.min(1.65, math.max(0.40, (w - 12) / base))
  local full = base * s
  local xx = x + math.max(4, math.floor((w - full) / 2))
  local yy = railY - 43 * s - 2
  local taps = {}
  for i = 1, count do
    local sx = xx + (i == 1 and 0 or (66 + (i - 2) * 56) * s)
    local ww = (i == 1 and 62 or 52) * s
    if selectIndex == i then
      box(r, sx - 3, yy - 3, ww + 6, 46 * s, 8)
    end
    if i == 1 then
      A.loco(r, sx, yy, s)
    else
      A.wagon(r, sx, yy, wagons[i].id, s)
    end
    taps[i] = { x = sx, y = yy - 4, w = ww, h = 49 * s }
  end
  for i = 0, 3 do
    local sx = xx + 9 + (i % 2) * 6
    local sy = yy - 8 - ((frame or 0) * 3 + i * 13) % 24
    box(r, sx, sy, 8, 3, 6)
    box(r, sx + 3, sy - 4, 9, 4, 5)
  end
  return taps
end
function A.station(r, x, y, w, h, station, frame)
  A.sky(r, x, y, w, h, frame)
  local platform = y + h - 12
  box(r, x, platform, w, 12, 16)
  box(r, x, platform, w, 2, 8)
  local house = x + math.floor(w * 0.13)
  box(r, house, y + h * 0.35, math.min(w * 0.35, 72), h * 0.49, 16)
  box(r, house - 4, y + h * 0.32, math.min(w * 0.35, 78), 7, 10)
  for i = 0, 2 do
    box(r, house + 8 + i * 16, y + h * 0.5, 10, 14, 13)
  end
  box(r, house + 15, y + h * 0.68, 16, 12, 9)
  if station.kind == "forge" or station.kind == "junction" then
    box(r, x + w * 0.7, y + h * 0.43, 23, h * 0.4, 4)
    box(r, x + w * 0.74, y + h * 0.3, 8, h * 0.17, 5)
    box(r, x + w * 0.69, y + h * 0.6, 27, 5, 8)
  else
    box(r, x + w * 0.72, y + h * 0.44, 6, h * 0.39, 9)
    box(r, x + w * 0.68, y + h * 0.4, 30, 5, 8)
    box(r, x + w * 0.85, y + h * 0.41, 3, h * 0.27, 6)
  end
  box(r, x + w * 0.55, platform - 13, 18, 12, 16)
  box(r, x + w * 0.59, platform - 16, 14, 4, 9)
end
function A.icon(r, id, x, y, s)
  r:icon(id, x, y, s)
end
return A
