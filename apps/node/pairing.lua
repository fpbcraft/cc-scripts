-- Pairing-disk utilities shared by node GUI and legacy command line.
-- Only the node ID, friendly name and secret are written to the disk.
local Pairing = {}
local FILENAME = "fpb_pairing.db"
local function hasType(name, kind)
  return peripheral.hasType and peripheral.hasType(name, kind) or peripheral.getType(name) == kind
end
function Pairing.drives()
  local out = {}
  for _, name in ipairs(peripheral.getNames()) do
    if hasType(name, "drive") then
      local mount = disk.getMountPath(name)
      if mount and fs.exists(mount) and not fs.isReadOnly(mount) then
        out[#out + 1] = { name = name, mount = mount }
      end
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end
function Pairing.path(drive)
  return fs.combine(drive.mount, FILENAME)
end
local function existing(path)
  if not fs.exists(path) then
    return nil
  end
  local f = fs.open(path, "r")
  if not f then
    return false
  end
  local raw = f.readAll()
  f.close()
  local ok, doc = pcall(textutils.unserialize, raw)
  if ok and type(doc) == "table" then
    return doc
  end
  return false
end
function Pairing.export(cfg, id, opts)
  if type(cfg) ~= "table" or type(cfg.key) ~= "string" or #cfg.key < 32 then
    return false, "Pairing key unavailable"
  end
  id = tonumber(id)
  if not id then
    return false, "Computer ID unavailable"
  end
  local drives = Pairing.drives()
  if #drives == 0 then
    return false, "Insert a writable floppy in a Disk Drive"
  end
  local drive = drives[1]
  if opts and opts.drive then
    drive = nil
    for _, d in ipairs(drives) do
      if d.name == opts.drive then
        drive = d
        break
      end
    end
    if not drive then
      return false, "Selected drive is unavailable"
    end
  end
  local path = Pairing.path(drive)
  local old = existing(path)
  if old == false then
    return false, "Existing pairing file is unreadable; remove it manually"
  end
  if old and old.node == id and old.key == cfg.key then
    return true, "Already on disk", drive
  end
  if old and not (opts and opts.replace == true) then
    return false, "Disk has another pairing key; confirm overwrite", drive
  end
  local data = textutils.serialize({
    format = 1,
    node = id,
    name = tostring(cfg.name or ("Node " .. id)),
    key = cfg.key,
  })
  local tmp = path .. ".new"
  if fs.exists(tmp) then
    fs.delete(tmp)
  end
  local f, err = fs.open(tmp, "w")
  if not f then
    return false, "Cannot write floppy: " .. tostring(err), drive
  end
  f.write(data)
  f.close()
  -- Preserve the previous complete file if writing fails.
  if fs.exists(path) then
    fs.delete(path)
  end
  fs.move(tmp, path)
  return true, "Pairing key copied to floppy", drive
end
return Pairing
