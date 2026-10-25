-- Deterministic pixel detail; no random shimmer when the camera moves.
local Hex = dofile("/games/civcraft/hex.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local T = {}
function T.color(land, explored)
  if explored then
    return 14
  end
  if type(land) == "table" then
    if land.elevation == "mountain" then
      return land.biome == "snowy_plains" and 30 or 4
    end
    return ({
      plains = 11,
      forest = 12,
      savanna = 8,
      desert = 29,
      taiga = 22,
      jungle = 21,
      swamp = 25,
      snowy_plains = 30,
      badlands = 26,
      coast = 13,
      ocean = 19,
      mushroom = 10,
    })[land.biome] or 11
  end
  return ({
    water = 19,
    mountain = 4,
    forest = 12,
    hills = 28,
    plains = 11,
    grassland = 11,
    desert = 29,
  })[land] or 11
end
function T.draw(r, land, x, y, size, tx, ty)
  local tile = type(land) == "table" and land or Biomes.legacy(land)
  land = Biomes.terrain(tile)
  if size < 12 then
    return
  end
  local function dot(dx, dy, w, h, c)
    if Hex.contains(x, y, size, x + dx, y + dy) and Hex.contains(x, y, size, x + dx + w - 1, y + dy + h - 1) then
      r:fill(x + dx, y + dy, w, h, c)
    end
  end
  local seed = tx * 37 + ty * 67
  local count = (land == "water" or tile.biome == "desert" or tile.biome == "snowy_plains" or tile.feature == "marsh")
      and 3
    or 0
  for n = 1, count do
    local dx = (seed + n * 17) % math.max(1, size - 4) + 2
    local dy = (seed * 3 + n * 11) % math.max(1, size - 4) + 2
    if land == "water" then
      dot(dx, dy, size >= 20 and 3 or 2, 1, n % 2 == 0 and 13 or 25)
    elseif tile.feature == "marsh" then
      dot(dx, dy, 2, 1, 13)
    elseif tile.biome == "snowy_plains" then
      dot(dx, dy, 2, 1, 7)
    elseif land ~= "mountain" then
      dot(dx, dy, 2, 1, 8)
    end
  end
  if size < 16 then
    return
  end
  local cx = x + size / 2
  local cy = y + size / 2
  if land == "mountain" or land == "hills" then
    local height = land == "mountain" and math.floor(size * 0.55) or math.floor(size * 0.25)
    local top = cy - height / 2
    for row = 0, height do
      local span = math.floor(row * (land == "mountain" and 0.65 or 1.1))
      r:fill(cx - span, top + row, span + 1, 1, land == "mountain" and 17 or 28)
      r:fill(cx + 1, top + row, math.max(1, span), 1, land == "mountain" and 4 or 12)
      if land == "mountain" and row < height * 0.28 then
        r:fill(cx - span, top + row, span * 2 + 1, 1, 30)
      end
    end
  end
  if tile.feature == "woods" or tile.feature == "dense" then
    local trees = 1
    for n = 1, trees do
      local px = cx + (n - 2) * (size / 5)
      local py = cy + (n % 2) * 2
      if trees == 1 then
        px = cx
      end
      r:fill(px, py + 2, 1, 4, 16)
      for row = 0, 4 do
        local half = math.floor(row / 2)
        r:fill(px - half, py - 3 + row, half + 1, 1, 21)
        r:fill(px + 1, py - 3 + row, math.max(1, half), 1, 12)
      end
    end
  end
end
local sprites = {}
local spriteKeys = {}
local spriteSlot = 1
local spriteLimit = 256
function T.sprite(land, size, tx, ty, base, detail, edge)
  local variant = (tx * 37 + ty * 67) % 16
  local style = type(land) == "table" and (land.biome .. "/" .. land.elevation .. "/" .. land.feature) or land
  local key = table.concat({ style, size, variant, base, detail and 1 or 0, edge }, ":")
  if sprites[key] then
    return sprites[key]
  end
  local blank = string.rep(string.char(255), size + 1)
  local rows = {}
  for y = 1, size + 1 do
    rows[y] = blank
  end
  local canvas = {}
  function canvas:fill(x, y, w, h, color)
    local x0, y0 = math.max(0, math.floor(x)), math.max(0, math.floor(y))
    local x1, y1 = math.min(size + 1, math.ceil(x + w)), math.min(size + 1, math.ceil(y + h))
    if x1 <= x0 or y1 <= y0 then
      return
    end
    local strip = string.rep(string.char(color), x1 - x0)
    for row = y0 + 1, y1 do
      rows[row] = rows[row]:sub(1, x0) .. strip .. rows[row]:sub(x1 + 1)
    end
  end
  for y = 0, size - 1 do
    local inset = y < size / 4 and size / 2 - 2 * y or y >= size * 3 / 4 and 2 * (y + 1) - size * 1.5 or 0
    canvas:fill(inset, y, math.max(1, size - inset * 2), 1, base)
  end
  if detail then
    T.draw(canvas, land, 0, 0, size, variant, 0)
  end
  local vertices = Hex.vertices(0, 0, size)
  for i, a in ipairs(vertices) do
    local b = vertices[i % 6 + 1]
    local dx, dy = b.x - a.x, b.y - a.y
    local count = math.max(math.abs(dx), math.abs(dy))
    for step = 0, count do
      canvas:fill(a.x + dx * step / count, a.y + dy * step / count, 1, 1, edge)
    end
  end
  local previous = spriteKeys[spriteSlot]
  if previous then
    sprites[previous] = nil
  end
  spriteKeys[spriteSlot] = key
  spriteSlot = spriteSlot % spriteLimit + 1
  sprites[key] = rows
  return rows
end
return T
