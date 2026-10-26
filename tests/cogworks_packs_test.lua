package.path = "./?.lua;./?/init.lua;" .. package.path
-- File-backed authoring/pack tests run on Lua 5.3 without a Minecraft computer.
local files, dirs, stored, serial = {}, {}, {}, 0
fs = {}
function fs.exists(path)
  return files[path] ~= nil or dirs[path] == true
end
function fs.makeDir(path)
  dirs[path] = true
end
function fs.delete(path)
  files[path], dirs[path] = nil, nil
end
function fs.move(from, to)
  assert(files[from], "Missing temporary level file")
  files[to], files[from] = files[from], nil
end
function fs.list(dir)
  local result = {}
  for path in pairs(files) do
    local prefix = dir .. "/"
    if path:sub(1, #prefix) == prefix then
      local name = path:sub(#prefix + 1)
      if not name:find("/") then
        result[#result + 1] = name
      end
    end
  end
  table.sort(result)
  return result
end
function fs.open(path, mode)
  if mode == "r" then
    if not files[path] then
      return nil
    end
    return {
      readAll = function()
        return files[path]
      end,
      close = function() end,
    }
  end
  local content = ""
  return {
    write = function(body)
      content = content .. body
    end,
    close = function()
      files[path] = content
    end,
  }
end
local function clone(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for k, item in pairs(value) do
    result[k] = clone(item)
  end
  return result
end
textutils = {
  serialize = function(data)
    serial = serial + 1
    stored[serial] = clone(data)
    return tostring(serial)
  end,
  unserialize = function(data)
    return clone(stored[tonumber(data)])
  end,
}
local E = require("games.cogworks.engine")
local P = require("games.cogworks.packs")
local edit = E.editor(7, 7)
assert(edit.editor and E.get(edit, 1, 3).kind == "S" and E.get(edit, 7, 3).kind == "M")
for x = 2, 6 do
  assert(E.place(edit, x, 3, "I", 1))
end
assert(E.evaluate(edit).win, "Authoring mode uses the real kinetic solver")
assert(E.place(edit, 4, 4, "X"), "Editor supports fixed stone")
assert(E.place(edit, 3, 4, "B"), "Editor supports redstone blocks")
E.get(edit, 2, 3).fixed = true
local original = P.fromEditor(edit, "SHAFTWORK TRAINING")
assert(
  #original.fixtures == 1 and #original.blocks == 1 and #original.build == 5,
  "Editor distinguishes immovable fixtures from stock and obstacles"
)
local valid, reason = P.validate(original)
assert(valid, tostring(reason))
assert(P.saveLevel("shaftwork", original), "Save independent editable level file")
assert(files[P.LEVELS .. "/shaftwork.coglevel"], "Editor file is stored outside managed game scripts")
assert(#P.listLevels() == 1 and P.listLevels()[1] == "shaftwork")
local restored = assert(P.loadLevel("shaftwork"))
assert(restored.name == "SHAFTWORK TRAINING")
local compiled, err = P.compile("training-pack", "TRAINING PACK")
assert(compiled, tostring(err))
local packed = assert(P.loadPack("training-pack"))
assert(#packed.levels == 1 and packed.levels[1].name == "SHAFTWORK TRAINING")
local playable = E.fromDefinition(packed.levels[1], false)
local solved = E.fromDefinition(packed.levels[1], true)
assert(
  not E.evaluate(playable).win and E.evaluate(solved).win,
  "Compiled pack plays identically to its editor reference"
)
assert(E.get(playable, 2, 3).fixed, "Compiled pack preserves immovable factory parts")
assert(#P.listPacks() == 1 and P.listPacks()[1] == "training-pack")
assert(not P.saveLevel("../escape", original), "Reject path traversal in level names")
local broken = clone(original)
broken.build[1].x, broken.build[1].y = broken.source.x, broken.source.y
assert(not P.validate(broken), "Reject overlapping board cells")
broken = clone(original)
broken.stock.I = 0
assert(not P.validate(broken), "Reject unbuildable inventories")
broken = clone(original)
broken.width = 11
assert(not P.validate(broken), "Reject oversized boards")
assert(not P.compile("empty-pack", "EMPTY", {}), "Packs must contain at least one level")
print("COGWORKS: editor files, fixtures, validation, compiled packs and kinetic playback passed.")
