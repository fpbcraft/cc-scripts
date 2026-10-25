local actions = {}
local routeLoop = false
local core = {
  snapshot = function()
    return {
      mode = "idle",
      route = { { x = 1, z = 2, name = "One" } },
      routeNext = 1,
      routeLoop = routeLoop,
      presets = { { x = 3, z = 4, name = "Dock" } },
      position = { x = 9, z = 70, y = 90 },
      target = nil,
      outputs = {},
      notice = "ready",
      navName = "nav",
      bridgeName = "bridge",
      displayLinks = 0,
      tick = 10,
      tickAge = 0,
      tickDuration = 0,
      stage = "waiting",
    }
  end,
  fly = function(x, z, name)
    actions[#actions + 1] = "fly:" .. x .. "," .. z
    return true
  end,
  flyMap = function()
    actions[#actions + 1] = "map"
    return true
  end,
  stop = function()
    actions[#actions + 1] = "stop"
    return true
  end,
  addRoute = function()
    actions[#actions + 1] = "routeAdd"
    return true
  end,
  editRoute = function()
    return true
  end,
  removeRoute = function()
    return true
  end,
  moveRoute = function(i, d)
    return i + d
  end,
  addPreset = function()
    return true
  end,
  editPreset = function()
    return true
  end,
  removePreset = function()
    return true
  end,
  capturePreset = function()
    actions[#actions + 1] = "capture"
    return true
  end,
  flyPreset = function()
    actions[#actions + 1] = "presetFly"
    return true
  end,
  presetToRoute = function()
    return true
  end,
  flyRouteFrom = function()
    return true
  end,
  resumeRoute = function()
    return true
  end,
  setRouteLoop = function(enabled)
    routeLoop = enabled
    actions[#actions + 1] = "loop:" .. tostring(enabled)
    return true
  end,
  setting = function()
    return true
  end,
  calibrate = function()
    return true
  end,
}
colors =
  { black = 1, white = 2, lightBlue = 4, cyan = 8, lightGray = 16, gray = 32, blue = 64, yellow = 128, lime = 256, red = 512, orange = 1024 }
term = {
  getSize = function()
    return 51, 22
  end,
}
local createdButtons = {}
local function frame()
  local f = {}
  function f:addFrame(_)
    return frame()
  end
  function f:addLabel(args)
    local o = { text = args.text }
    function o:destroy() end
    return o
  end
  function f:addButton(args)
    local o = { text = args.text }
    function o:onClick(fn)
      createdButtons[#createdButtons + 1] = { text = self.text, call = fn }
    end
    return o
  end
  function f:addInput(args)
    local o = { text = args.text or "" }
    function o:onChange(fn)
      self.changed = fn
    end
    function o:onEnter(fn)
      self.enter = fn
    end
    function o:focus()
      self.focused = true
    end
    return o
  end
  function f:destroy() end
  return f
end
local sched = {}
local basalt = {
  getMainFrame = function()
    return frame()
  end,
  createFrame = function()
    return frame()
  end,
  schedule = function(fn)
    sched[#sched + 1] = fn
  end,
}
sleep = function() end
local function click(name)
  for i = #createdButtons, 1, -1 do
    local b = createdButtons[i]
    if b.text == name then
      return b.call()
    end
  end

  error("missing button: " .. name)
end
function basalt.run()
  assert(#sched == 2, "two Basalt scheduler jobs expected")
  sched[1]() -- render splash animation and UI
  click("FLY TO X/Z")
  click("X COORD")
  click("7")
  click("Z COORD")
  click("8")
  click("SAVE / FLY")
  click("PRESETS")
  click("SAVE HERE")
  click("FLIGHT")
  click("STOP NOW")
  click("ROUTE")
  click("LOOP ROUTE: OFF - STOP AT END")
  assert(routeLoop, "loop route was not enabled")
  click("LOOP ROUTE: ON - REPEAT FROM FIRST")
  assert(not routeLoop, "loop route was not disabled")
end
package.preload.basalt = function()
  return basalt
end
local ui = assert(loadfile("apps/airship/ui.lua"))()
ui.run(core)
assert(actions[1] == "fly:7,8", "numeric keypad failed: " .. tostring(actions[1]))
assert(actions[2] == "capture", "save current position button failed")
assert(actions[3] == "stop", "emergency stop button failed")
assert(actions[4] == "loop:true" and actions[5] == "loop:false", "route looping button failed")
print("Basalt mock UI: PASS (startup, destination, presets, stop)")
