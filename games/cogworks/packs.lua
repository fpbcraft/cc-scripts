-- Cogworks authoring/pack format. Data files are inert serialized Lua tables
-- (textutils.unserialize), never executable chunks. A .cogpack bundles several
-- validated .coglevel files into a self-contained reusable level collection.
local P = {}
P.ROOT = "/games/cogworks"
P.LEVELS = P.ROOT .. "/user_levels"
P.PACKS = P.ROOT .. "/packs"
P.VERSION = 1
local validKinds = { S = true, M = true, X = true, I = true, G = true, O = true, Q = true, D = true,
  V = true, Z = true, C = true, R = true, B = true }
local function slug(text)
  if type(text) ~= "string" then
    return nil
  end
  if #text < 1 or #text > 48 or not text:match("^[%w_%-]+$") then
    return nil
  end
  return text
end
local function integer(n, low, high)
  return type(n) == "number" and n == math.floor(n) and n >= low and n <= high
end
local function checkPart(piece, width, height, used)
  if type(piece) ~= "table" or not validKinds[piece.kind] then
    return false, "INVALID PART"
  end
  if not integer(piece.x, 1, width) or not integer(piece.y, 1, height) or not integer(piece.r or 0, 0, 3) then
    return false, "PART OUTSIDE GRID"
  end
  if piece.kind == "M" and (type(piece.speed) ~= "number" or piece.speed <= 0 or piece.speed > 16
      or (piece.sign ~= 1 and piece.sign ~= -1)) then
    return false, "INVALID GOAL SPEED OR DIRECTION"
  end
  local key = piece.y * 16 + piece.x
  if used[key] then
    return false, "OVERLAPPING PARTS"
  end
  used[key] = true
  return true
end
function P.validate(data)
  if type(data) ~= "table" then
    return false, "LEVEL IS NOT A TABLE"
  end
  if type(data.name) ~= "string" or #data.name < 1 or #data.name > 48
    or type(data.tip) ~= "string" or #data.tip > 160 then
    return false, "NAME OR DESCRIPTION INVALID"
  end
  if not integer(data.width, 5, 10) or not integer(data.height, 5, 10) then
    return false, "GRID MUST BE 5-10 CELLS"
  end
  if type(data.goals) ~= "table" or #data.goals < 1 or #data.goals > 12 or type(data.source) ~= "table" then
    return false, "SOURCE AND TARGET REQUIRED"
  end
  local occupied = {}
  local ok, err = checkPart(data.source, data.width, data.height, occupied)
  if not ok or data.source.kind ~= "S" then
    return false, err or "SOURCE REQUIRED"
  end
  for _, entry in ipairs(data.goals) do
    ok, err = checkPart(entry, data.width, data.height, occupied)
    if not ok or entry.kind ~= "M" then
      return false, err or "INVALID GOAL"
    end
  end
  local allowed = { build = true, fixtures = true, redstone = true }
  for field in pairs(allowed) do
    local list = data[field] or {}
    if type(list) ~= "table" or #list > 100 then
      return false, "INVALID " .. field
    end
    for _, entry in ipairs(list) do
      ok, err = checkPart(entry, data.width, data.height, occupied)
      if not ok or entry.kind == "S" or entry.kind == "M" or entry.kind == "X" then
        return false, err or "INVALID BUILD PART"
      end
    end
  end
  if type(data.blocks or {}) ~= "table" or #(data.blocks or {}) > 100 then
    return false, "INVALID OBSTACLES"
  end
  for _, stone in ipairs(data.blocks or {}) do
    if type(stone) ~= "table" or not integer(stone[1], 1, data.width)
      or not integer(stone[2], 1, data.height) or occupied[stone[2] * 16 + stone[1]] then
      return false, "INVALID STONE PLACEMENT"
    end
    occupied[stone[2] * 16 + stone[1]] = true
  end
  if type(data.stock) ~= "table" then
    return false, "INVENTORY REQUIRED"
  end
  local required = {}
  for _, piece in ipairs(data.build or {}) do
    required[piece.kind] = (required[piece.kind] or 0) + 1
  end
  for kind, count in pairs(data.stock) do
    if not validKinds[kind] or kind == "S" or kind == "M" or kind == "X"
      or not integer(count, 0, 100) then
      return false, "INVALID INVENTORY"
    end
  end
  for kind, count in pairs(required) do
    if (data.stock[kind] or 0) < count then
      return false, "INVENTORY BELOW REFERENCE BUILD"
    end
  end
  return true
end
local function ensure(dir)
  if not fs.exists(dir) then
    fs.makeDir(dir)
  end
end
local function write(path, value)
  ensure(P.ROOT)
  ensure(P.LEVELS)
  ensure(P.PACKS)
  local temporary = path .. ".next"
  local handle = fs.open(temporary, "w")
  if not handle then
    return false, "CANNOT OPEN DATA FILE"
  end
  handle.write(textutils.serialize(value))
  handle.close()
  if fs.exists(path) then
    fs.delete(path)
  end
  fs.move(temporary, path)
  return true
end
local function read(path)
  if not fs.exists(path) then
    return nil, "FILE MISSING"
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil, "CANNOT OPEN DATA FILE"
  end
  local raw = handle.readAll()
  handle.close()
  local ok, data = pcall(textutils.unserialize, raw)
  if not ok or type(data) ~= "table" then
    return nil, "INVALID FILE"
  end
  return data
end
local function list(dir, ext)
  ensure(dir)
  local names = {}
  for _, file in ipairs(fs.list(dir)) do
    if file:sub(-#ext) == ext then
      names[#names + 1] = file:sub(1, -#ext - 1)
    end
  end
  table.sort(names)
  return names
end
function P.listLevels()
  return list(P.LEVELS, ".coglevel")
end
function P.listPacks()
  return list(P.PACKS, ".cogpack")
end
function P.saveLevel(id, data)
  if not slug(id) then
    return false, "INVALID LEVEL ID"
  end
  local valid, reason = P.validate(data)
  if not valid then
    return false, reason
  end
  return write(P.LEVELS .. "/" .. id .. ".coglevel", { format = P.VERSION, level = data })
end
function P.loadLevel(id)
  if not slug(id) then
    return nil, "INVALID LEVEL ID"
  end
  local data, reason = read(P.LEVELS .. "/" .. id .. ".coglevel")
  if not data then
    return nil, reason
  end
  local level = data.format == P.VERSION and data.level
  local valid, problem = P.validate(level)
  return valid and level or nil, valid and nil or problem
end
function P.fromEditor(board, name)
  local data = {
    name = name or board.name or "NEW WORKSHOP",
    tip = board.tip or "CONNECT ALL TARGETS.",
    width = board.width, height = board.height, source = nil,
    goals = {}, build = {}, fixtures = {}, blocks = {}, redstone = {}, stock = {},
  }
  for _, tile in ipairs(board.tiles) do
    local part = { kind = tile.kind, x = tile.x, y = tile.y, r = tile.r }
    if tile.kind == "S" then
      data.source = part
    elseif tile.kind == "M" then
      part.speed, part.sign = tile.speed, tile.sign
      data.goals[#data.goals + 1] = part
    elseif tile.kind == "X" then
      data.blocks[#data.blocks + 1] = { tile.x, tile.y }
    elseif tile.fixed then
      data.fixtures[#data.fixtures + 1] = part
    else
      data.build[#data.build + 1] = part
      data.stock[tile.kind] = (data.stock[tile.kind] or 0) + 1
    end
  end
  return data
end
function P.compile(id, title, ids)
  if not slug(id) then
    return false, "INVALID PACK ID"
  end
  ids = ids or P.listLevels()
  if #ids == 0 or #ids > 64 then
    return false, "A PACK NEEDS 1-64 LEVELS"
  end
  local pack = { format = P.VERSION, id = id, title = title or id, levels = {} }
  for _, levelId in ipairs(ids) do
    local level, problem = P.loadLevel(levelId)
    if not level then
      return false, tostring(problem) .. ": " .. tostring(levelId)
    end
    pack.levels[#pack.levels + 1] = level
  end
  return write(P.PACKS .. "/" .. id .. ".cogpack", pack)
end
function P.loadPack(id)
  if not slug(id) then
    return nil, "INVALID PACK ID"
  end
  local pack, reason = read(P.PACKS .. "/" .. id .. ".cogpack")
  if not pack then
    return nil, reason
  end
  if pack.format ~= P.VERSION or type(pack.title) ~= "string"
    or type(pack.levels) ~= "table" or #pack.levels == 0 or #pack.levels > 64 then
    return nil, "INVALID LEVEL PACK"
  end
  for _, level in ipairs(pack.levels) do
    local ok, err = P.validate(level)
    if not ok then
      return nil, err
    end
  end
  return pack
end
return P
