-- Regression: Basalt UI coroutine cannot consume the dedicated flight timer.
local now, timerId = 0, 0
local timers = {}
local writes = {}
local files = {}
local saved = {}
local activeMonitor = nil
local lastSnapshot
local ship = { x = 0, z = 0 }
fs = {
  getDir = function()
    return "apps/airship"
  end,
  combine = function(a, b)
    return a .. "/" .. b
  end,
  exists = function(path)
    return files[path] ~= nil
  end,
  getSize = function(path)
    return #(files[path] or "")
  end,
  open = function(path, mode)
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
    if mode == "w" then
      files[path] = ""
    end
    return {
      write = function(txt)
        files[path] = (files[path] or "") .. txt
      end,
      writeLine = function(txt)
        files[path] = (files[path] or "") .. txt .. "\n"
      end,
      close = function() end,
    }
  end,
}
textutils = {
  serialize = function(obj)
    if type(obj) == "table" and obj.points and obj.loop ~= nil then
      saved.routeLoop = obj.loop
      saved.routeNext = obj.nextIndex
    end
    return "stub"
  end,
  unserialize = function(raw)
    if raw == "settings" then
      return { bowOffset = 0, autoMap = false }
    end
  end,
}
files["apps/airship/.airship_avionics_burners_settings"] = "settings"
shell = {
  getRunningProgram = function()
    return "apps/airship/autopilot.lua"
  end,
}
local nav = {
  getHeading = function()
    return 0
  end,
  getTablePosition = function()
    return { x = ship.x, y = 100, z = ship.z, projected = true }
  end,
  getTargetPosition = function()
    return nil
  end,
}
local bridge = {
  getLinkSignal = function()
    return 0
  end,
  sendLinkSignal = function(a, b, v)
    writes[#writes + 1] = { a, b, v }
  end,
}
peripheral = {
  getNames = function()
    return { "nav", "bridge" }
  end,
  wrap = function(name)
    if name == "nav" then
      return nav
    elseif name == "bridge" then
      return bridge
    end
  end,
  hasType = function()
    return false
  end,
  getType = function()
    return "other"
  end,
}
term = {
  current = function()
    return term
  end,
  redirect = function() end,
  setCursorBlink = function() end,
  setBackgroundColor = function() end,
  setTextColor = function() end,
  clear = function() end,
  setCursorPos = function() end,
}
colors = { black = 1, white = 2 }
os.clock = function()
  return now
end
os.startTimer = function(delay)
  timerId = timerId + 1
  timers[timerId] = now + delay
  return timerId
end
os.pullEventRaw = function(filter)
  return coroutine.yield(filter)
end
parallel = {}
function parallel.waitForAny(...)
  local jobs = { ... }
  local active, filters = {}, {}
  for i, job in ipairs(jobs) do
    active[i] = coroutine.create(job)
    local ok, f = coroutine.resume(active[i])
    assert(ok, f)
    filters[i] = f
  end
  for _ = 1, 6000 do
    local nextId, min = nil, math.huge
    for id, t in pairs(timers) do
      if t < min then
        nextId, min = id, t
      end
    end
    assert(nextId, "Flight/engine timers stopped")
    now = min
    timers[nextId] = nil
    for i, co in ipairs(active) do
      if coroutine.status(co) ~= "dead" and (filters[i] == nil or filters[i] == "timer") then
        local ok, f = coroutine.resume(co, "timer", nextId)
        assert(ok, f)
        filters[i] = f
        if coroutine.status(co) == "dead" then
          return
        end
      end
    end
  end
  error("No UI exit from scheduler")
end
package.preload.ui = function()
  return {
    run = function(controller)
      controller.setPage("FLIGHT")
      assert(controller.snapshot().mode == "idle")
      assert(controller.addPreset(100, 200, "Dock"))
      assert(controller.addRoute(0, 500, "First", 0))
      assert(controller.addRoute(200, 1000, "Second", 1))
      assert(controller.setRouteLoop(true))
      assert(controller.snapshot().routeLoop == true)
      assert(saved.routeLoop == true, "loop setting not persisted")
      assert(controller.flyRouteFrom(2))
      assert(controller.snapshot().routeIndex == 2)
      -- Arrive within the fly-through zone of the final stop. Looping must
      -- select the FIRST stop, not enter the arrived/idle state.
      ship.x, ship.z = 200, 1000
      for i = 1, 100 do
        os.pullEventRaw("timer")
      end
      local wrapped = controller.snapshot()
      assert(wrapped.mode == "route", "loop stopped unexpectedly at last stop")
      assert(wrapped.routeIndex == 1 and wrapped.routeNext == 1, "last stop did not wrap to first")
      assert(saved.routeNext == 1, "next stop after wrap not persisted")
      -- Now advance through the first stop again.
      ship.x, ship.z = 0, 500
      for i = 1, 80 do
        os.pullEventRaw("timer")
      end
      assert(controller.snapshot().routeIndex == 2, "loop did not advance again")
      assert(controller.snapshot().routeNext == 2)
      -- Turning looping OFF must not immediately cancel an active route.
      assert(controller.setRouteLoop(false))
      assert(controller.snapshot().routeLoop == false)
      assert(saved.routeLoop == false, "disabled loop mode not persisted")
      lastSnapshot = controller.snapshot()
      -- With looping disabled, final stop should settle into ARRIVED.
      ship.x, ship.z = 200, 1000
      for i = 1, 160 do
        os.pullEventRaw("timer")
      end
      assert(controller.snapshot().mode == "arrived", "non-loop route did not arrive at the final waypoint")
      controller.stop()
      assert(controller.snapshot().routeNext == 2)
    end,
  }
end
local originalPrint = print
print = function() end
local chunk = assert(loadfile("apps/airship/autopilot.lua"))
chunk()
assert(lastSnapshot and lastSnapshot.tick >= 30, "flight tick stalled while UI active")
assert(
  type(lastSnapshot.error) == "number" and math.abs(lastSnapshot.error) > 0.1,
  "heading error must remain numeric and nonzero while flying"
)
assert(lastSnapshot.controlError == nil, "controller should not report error")
assert(#writes > 4, "no controls were sent")
assert(files["apps/airship/.airship_avionics_route"], "route not saved")
assert(files["apps/airship/.airship_avionics_presets"], "preset not saved")
originalPrint("Airship core integration: PASS, " .. lastSnapshot.tick .. " ticks, " .. #writes .. " outputs")
