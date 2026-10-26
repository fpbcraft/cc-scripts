package.path = "./?.lua;./?/init.lua;" .. package.path
local files, dirs = {}, {}
fs = {}
function fs.exists(path)
  return files[path] ~= nil or dirs[path] ~= nil
end
function fs.makeDir(path)
  dirs[path] = true
end
function fs.delete(path)
  files[path], dirs[path] = nil, nil
end
function fs.move(a, b)
  assert(files[a], "Missing " .. a)
  files[b], files[a] = files[a], nil
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
  assert(mode == "w")
  local body = ""
  return {
    write = function(str)
      body = body .. str
    end,
    close = function()
      files[path] = body
    end,
  }
end
local stored, counter = {}, 0
local function copy(v)
  if type(v) ~= "table" then
    return v
  end
  local result = {}
  for k, value in pairs(v) do
    result[k] = copy(value)
  end
  return result
end
textutils = {
  serialize = function(v)
    counter = counter + 1
    stored[counter] = copy(v)
    return tostring(counter)
  end,
  unserialize = function(v)
    return copy(stored[tonumber(v)])
  end,
}
local S = require("games.cogworks.storage")
assert(S.VERSION == 6 and not S.has(2), "Updated campaign save schema")
local old = {
  campaignVersion = 3,
  unlocked = 30,
  level = 27,
  sessions = { [27] = { parts = { { kind = "L", x = 2, y = 3, r = 1 } } } },
  awards = { [27] = { sealed = true } },
}
files[S.LEGACY] = textutils.serialize(old)
local imported = S.load(1)
assert(
  imported.level == 1 and imported.unlocked == 8 and next(imported.sessions) == nil and next(imported.awards) == nil,
  "Incompatible 30-stage saves reset to the new campaign"
)
assert(files[S.LEGACY], "Preserve legacy file for backup")
local current = S.newProgress()
current.level, current.unlocked, current.best[2] = 2, 8, 12
current.best[1] = 10
current.tutorials.G = true
assert(S.save(1, current), "Can save new campaign")
local reloaded = S.load(1)
assert(reloaded.level == 2 and reloaded.unlocked == 8 and reloaded.best[2] == 12)
assert(reloaded.tutorials.G, "New Ponder progress persists")
assert(S.save(2, S.newProgress()) and S.save(3, S.newProgress()), "Independent slots")
local older = { campaignVersion = 5, level = 47, best = { [47] = 5 }, awards = {} }
local previousBytes = textutils.serialize(older)
files[S.path(3)] = previousBytes
local migrated = S.load(3)
assert(migrated.level == 1 and next(migrated.best) == nil, "Old placeholder campaign is not treated as new puzzles")
assert(S.save(3, migrated), "Write the new campaign save")
assert(files[S.path(3) .. ".campaign-v5"] == previousBytes, "The previous campaign save is permanently archived")
assert(S.load(3).campaignVersion == 6, "Migrate to chapter-based save format")
local settings = S.loadSettings()
assert(settings.animations and settings.showPorts)
settings.animations = false
settings.showPorts = false
settings.lastSlot = 3
assert(S.saveSettings(settings), "Settings persisted")
local loaded = S.loadSettings()
assert(not loaded.animations and not loaded.showPorts and loaded.lastSlot == 3)
files[S.path(2)] = "invalid lua"
assert(not S.load(2) and S.load(1).level == 2, "Corrupted slot stays isolated")
print("COGWORKS: campaign-v6 migration, slots, settings and corruption isolation passed.")
