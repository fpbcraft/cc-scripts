-- Device onboarding regression tests: run lua5.3 tests/devices_test.lua
package.path = "./apps/factory/?.lua;" .. package.path
local disk = {}
local function serialize(v)
  if type(v) == "table" then
    local out = {}
    for k, x in pairs(v) do
      out[#out + 1] = "[" .. serialize(k) .. "]=" .. serialize(x)
    end
    return "{" .. table.concat(out, ",") .. "}"
  end
  if type(v) == "string" then
    return string.format("%q", v)
  end
  return tostring(v)
end
fs = {
  combine = function(a, b)
    return a .. "/" .. b
  end,
  exists = function(p)
    return disk[p] ~= nil
  end,
  open = function(p, mode)
    if mode == "r" then
      if not disk[p] then
        return nil
      end
      return {
        readAll = function()
          return disk[p]
        end,
        close = function() end,
      }
    end
    return {
      write = function(v)
        disk[p] = v
      end,
      close = function() end,
    }
  end,
  delete = function(p)
    disk[p] = nil
  end,
  move = function(a, b)
    disk[b] = disk[a]
    disk[a] = nil
  end,
}
textutils = {
  serialize = serialize,
  unserialize = function(raw)
    return assert(load("return " .. raw))()
  end,
}
local connected = {
  gauge_0 = { type = "custom_gauge", value = 20 },
  gauge_1 = { type = "custom_gauge", value = 100 },
  relay_0 = { type = "redstone_relay" },
}
local sent = 0
peripheral = {
  getNames = function()
    local out = {}
    for n in pairs(connected) do
      out[#out + 1] = n
    end
    return out
  end,
  getType = function(n)
    return connected[n] and connected[n].type
  end,
  getMethods = function(n)
    if not connected[n] then
      return nil
    end
    if connected[n].type == "redstone_relay" then
      return { "setOutput", "getOutput" }
    end
    return { "getValue", "getOtherStuff", "setValue", "trigger", "getItemDetail" }
  end,
  call = function(name, method)
    local d = assert(connected[name])
    if method == "getValue" then
      return d.value
    end
    if method == "setValue" or method == "setOutput" then
      sent = sent + 1
      return true
    end
    error("Method requires arguments")
  end,
}
local Devices = require("devices")
local manager = Devices.new("apps/factory/data")
local discovered = manager:discover()
assert(#discovered == 3)
assert(manager:rename("gauge_0", "Boiler A"))
local methods = manager:methods("gauge_0")
assert(#methods == 2 and methods[1] == "getOtherStuff" and methods[2] == "getValue")
local notAllowed, err = manager:add("relay_0", "setOutput")
assert(not notAllowed and err:find("read%-only"))
local reading = assert(manager:add("gauge_0", "getValue"))
assert(reading.label == "Boiler A / getValue")
assert(manager:update(reading.id, { label = "Heat", unit = "C", warnAbove = 30 }))
local data = manager:readAll()
assert(data["sensor_" .. reading.id] == 20)
assert(manager.values[reading.id].status == "online")
assert(#manager:charts() == 1 and manager:charts()[1].label == "Heat")
connected.gauge_0.value = 35
data = manager:readAll()
assert(data["sensor_" .. reading.id] == 35 and manager.values[reading.id].warning)
assert(sent == 0, "Reading must never execute setter methods")
connected.gauge_0 = nil
manager:readAll()
assert(manager.values[reading.id].status == "offline")
assert(manager:get("gauge_0").alias == "Boiler A")
assert(manager:rebind(reading.id, "gauge_1"))
assert(manager:readAll()["sensor_" .. reading.id] == 100)
assert(manager:update(reading.id, { warnAbove = false, graph = false }))
manager:readAll()
assert(manager.values[reading.id].warning == nil and #manager:charts() == 0)
local reloaded = Devices.new("apps/factory/data")
reloaded:discover()
local persisted = reloaded:getReading(reading.id)
assert(persisted.label == "Heat" and persisted.device == "gauge_1")
assert(#reloaded:list() == 3, "Known offline peripherals must remain visible")
assert(reloaded:remove(reading.id))
assert(reloaded:getReading(reading.id) == nil)
print("Peripheral discovery and onboarding tests passed")
