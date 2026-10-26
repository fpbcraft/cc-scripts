-- CraftOS-PC may create a virtual monitor window; normal CC:Tweaked cannot.
-- Never replace/detach a user-attached peripheral.
local M = {}

local function list()
  local result = {}
  if peripheral and peripheral.getNames and peripheral.getType and peripheral.wrap then
    for _, side in ipairs(peripheral.getNames()) do
      if peripheral.getType(side) == "monitor" then
        local screen = peripheral.wrap(side)
        if screen and screen.getSize then
          result[#result + 1] = { name = side, screen = screen }
        end
      end
    end
  end
  table.sort(result, function(a, b)
    return a.name < b.name
  end)
  return result
end

function M.available()
  return type(periphemu) == "table" and type(periphemu.create) == "function"
end

function M.monitors()
  return list()
end

function M.ensure()
  local existing = list()
  if #existing > 0 then
    return existing[1], false
  end
  if not M.available() then
    return nil, false, "No attached monitor (CraftOS-PC virtual monitor API unavailable)"
  end
  for _, side in ipairs({ "fpbstore_monitor", "right", "left", "back", "top", "bottom" }) do
    local occupied = peripheral and peripheral.isPresent and peripheral.isPresent(side)
    if not occupied then
      local ok, created = pcall(periphemu.create, side, "monitor")
      if ok and created then
        for _, entry in ipairs(list()) do
          if entry.name == side then
            if entry.screen.setTextScale then
              pcall(entry.screen.setTextScale, 0.5)
            end
            return entry, true
          end
        end
      end
    end
  end
  return nil, false, "CraftOS-PC could not attach a virtual monitor"
end

return M
