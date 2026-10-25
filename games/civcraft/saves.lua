-- Three independent local campaigns; legacy save is copied on first use.
local S = { count = 3, root = "/games/civcraft/data" }
local function path(slot)
  slot = tonumber(slot)
  assert(slot and slot == math.floor(slot) and slot >= 1 and slot <= S.count, "Invalid save slot")
  return S.root .. "/slot-" .. slot .. ".dat"
end
S.path = path
local migrationMarker = S.root .. "/slots-migrated"
local function read(p)
  if not fs.exists(p) then
    return nil
  end
  local h = fs.open(p, "r")
  if not h then
    return nil
  end
  local ok, raw = pcall(h.readAll)
  h.close()
  if not ok or not raw then
    return nil
  end
  local success, value = pcall(textutils.unserialize, raw)
  if success and type(value) == "table" then
    return value
  end
  return nil
end
function S.load(slot)
  local state = read(path(slot))
  if state then
    return state
  end
  if tonumber(slot) == 1 and not fs.exists(migrationMarker) then
    return read(S.root .. "/local-save.dat")
  end
end
function S.list()
  local out = {}
  for slot = 1, S.count do
    local game = S.load(slot)
    if game then
      out[slot] = {
        occupied = true,
        name = game.name or ("CAMPAIGN " .. slot),
        seed = game.world and game.world.seed or 0,
        size = game.world and game.world.size or "legacy",
        round = game.round or 1,
        phase = game.phase or "lobby",
      }
    else
      out[slot] = { occupied = false, name = "EMPTY SLOT " .. slot }
    end
  end
  return out
end
function S.save(slot, state)
  local dest = path(slot)
  if not fs.exists(S.root) then
    fs.makeDir(S.root)
  end
  local tmp = dest .. ".tmp"
  local out = assert(fs.open(tmp, "w"), "Cannot write campaign")
  local encoded = textutils.serialize(state)
  out.write(encoded)
  out.close()
  -- Copy previous contents before replacing, so partial writes don't destroy a save.
  local backup = dest .. ".bak"
  if fs.exists(dest) then
    if fs.exists(backup) then
      fs.delete(backup)
    end
    fs.move(dest, backup)
  end
  local ok, why = pcall(fs.move, tmp, dest)
  if not ok then
    if fs.exists(backup) then
      fs.move(backup, dest)
    end
    error("Save not committed: " .. tostring(why))
  end
  if not fs.exists(migrationMarker) then
    local marker = fs.open(migrationMarker, "w")
    if marker then
      marker.write("v3")
      marker.close()
    end
  end
  return true
end
function S.delete(slot)
  local dest = path(slot)
  if tonumber(slot) == 1 and not fs.exists(migrationMarker) then
    if not fs.exists(S.root) then
      fs.makeDir(S.root)
    end
    local marker = fs.open(migrationMarker, "w")
    if marker then
      marker.write("v3")
      marker.close()
    end
  end
  if fs.exists(dest) then
    fs.delete(dest)
  end
  if fs.exists(dest .. ".bak") then
    fs.delete(dest .. ".bak")
  end
  return true
end
return S
