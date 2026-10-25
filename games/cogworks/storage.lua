-- COGWORKS: versioned save slots and settings with crash-safe file replacement.
-- The original /games/cogworks/save.dat remains untouched, and is imported as slot 1.
local S = {}
S.ROOT = "/games/cogworks"
S.DIR = S.ROOT .. "/saves"
S.SETTINGS = S.ROOT .. "/settings.dat"
S.LEGACY = S.ROOT .. "/save.dat"
S.VERSION = 6
local function ensure(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end
local function decode(path)
  if not fs.exists(path) then
    return nil
  end
  local f = fs.open(path, "r")
  if not f then
    return nil
  end
  local raw = f.readAll()
  f.close()
  local ok, value = pcall(textutils.unserialize, raw)
  if ok and type(value) == "table" then
    return value
  end
  return nil
end
local function write(path, value)
  ensure(S.ROOT)
  ensure(S.DIR)
  local temp = path .. ".next"
  local previous = path .. ".backup"
  local h, err = fs.open(temp, "w")
  if not h then
    return false, tostring(err)
  end
  local ok, body = pcall(textutils.serialize, value)
  if not ok then
    h.close()
    fs.delete(temp)
    return false, body
  end
  h.write(body)
  h.close()
  local success, reason = pcall(function()
    if fs.exists(previous) then
      fs.delete(previous)
    end
    if fs.exists(path) then
      fs.move(path, previous)
    end
    fs.move(temp, path)
  end)
  if not success then
    if fs.exists(previous) and not fs.exists(path) then
      pcall(fs.move, previous, path)
    end
    return false, tostring(reason)
  end
  if fs.exists(previous) then
    fs.delete(previous)
  end
  return true
end
local function clamp(n, low, high, default)
  n = tonumber(n)
  if not n or n ~= n then
    return default
  end
  return math.max(low, math.min(high, math.floor(n)))
end
function S.path(slot)
  assert(type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= 3, "Invalid save slot")
  return S.DIR .. "/slot-" .. slot .. ".dat"
end
function S.newProgress()
  return { campaignVersion = S.VERSION, unlocked = 1, level = 1, best = {}, sessions = {}, awards = {}, tutorials = {} }
end
function S.normalize(data)
  local p = S.newProgress()
  if type(data) ~= "table" then
    return p
  end
  -- The 64-level chapter campaign has different layouts; incompatible saves
  -- start at chapter one rather than applying solutions to the wrong stages.
  if data.campaignVersion ~= S.VERSION then
    return p
  end
  local chapters = require("games.cogworks.chapters")
  p.best = type(data.best) == "table" and data.best or {}
  p.awards = type(data.awards) == "table" and data.awards or {}
  p.unlocked = chapters.openLevels(p)
  p.level = clamp(data.level, 1, p.unlocked, 1)
  if not chapters.levelUnlocked(p, p.level) then
    p.level = 1
  end
  p.sessions = type(data.sessions) == "table" and data.sessions or {}
  if type(data.tutorials) == "table" then
    for key, value in pairs(data.tutorials) do
      if type(key) == "string" and value == true then
        p.tutorials[key] = true
      end
    end
  end
  return p
end
function S.loadSettings()
  local raw = decode(S.SETTINGS) or {}
  return {
    animations = raw.animations ~= false,
    showPorts = raw.showPorts ~= false,
    lastSlot = clamp(raw.lastSlot, 1, 3, 1),
  }
end
function S.saveSettings(settings)
  return write(S.SETTINGS, settings)
end
function S.load(slot)
  local path = S.path(slot)
  local raw = decode(path)
  if not raw and slot == 1 and not fs.exists(path) then
    -- Seamless migration: retain the legacy file as an additional backup.
    raw = decode(S.LEGACY)
  end
  if not raw then
    return nil
  end
  return S.normalize(raw)
end
function S.has(slot)
  return S.load(slot) ~= nil
end
function S.save(slot, data)
  local path = S.path(slot)
  local original = decode(path)
  -- The previous procedurally generated level campaign has incompatible
  -- geometry; preserve its save bytes before resetting chapter progress.
  if original and original.campaignVersion ~= S.VERSION then
    local backup = path .. ".campaign-v" .. tostring(original.campaignVersion or "unknown")
    if not fs.exists(backup) then
      local oldFile = fs.open(path, "r")
      if oldFile then
        local bytes = oldFile.readAll()
        oldFile.close()
        local archive = fs.open(backup, "w")
        if archive then
          archive.write(bytes)
          archive.close()
        end
      end
    end
  end
  return write(path, S.normalize(data))
end
return S
