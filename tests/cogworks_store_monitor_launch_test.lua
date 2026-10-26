-- Reproduce FPBStore running on an attached CraftOS monitor and launching
-- Cogworks on that same redirected terminal. Mouse events must stay button-
-- aware even though Display.select classifies its output as "monitor".
package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local Renderer = require("games.cogworks.render")
local Store = require("apps.fpbstore.launcher")

local original = { term = term, peripheral = peripheral, config = config, colors = colors, keys = keys }
local pull, raw, timer = os.pullEvent, os.pullEventRaw, os.startTimer

local screen = { w = 70, h = 40, pw = 640, ph = 480, mode = 0, scale = 1, uploads = 0 }
function screen.getSize(mode)
  return mode == 2 and screen.pw or screen.w, mode == 2 and screen.ph or screen.h
end
function screen.getTextScale()
  return screen.scale
end
function screen.setTextScale(value)
  screen.scale = value
end
function screen.getGraphicsMode()
  return screen.mode
end
function screen.setGraphicsMode(mode)
  screen.mode = mode
end
function screen.isColor()
  return true
end
function screen.setPaletteColor() end
function screen.getPaletteColor()
  return 0.2, 0.4, 0.6
end
function screen.setCursorPos() end
function screen.setCursorBlink() end
function screen.setTextColor() end
function screen.setBackgroundColor() end
function screen.write() end
function screen.clear() end
function screen.setFrozen() end
function screen.drawPixels()
  assert(screen.mode == 2, "Bitmap drawn without switching into graphics mode")
  screen.uploads = screen.uploads + 1
end

local other = { w = 100, h = 60, pw = 800, ph = 600 }
function other.getSize(mode)
  return mode == 2 and other.pw or other.w, mode == 2 and other.ph or other.h
end
function other.isColor()
  return true
end
peripheral = {
  getNames = function()
    return { "right", "left" }
  end,
  getType = function(name)
    return name == "left" or name == "right" and "monitor" or nil
  end,
  getName = function(device)
    return device == screen and "left" or nil
  end,
  wrap = function(name)
    return name == "left" and screen or other
  end,
}
-- Make the display attached to the Store the redirected terminal, even
-- though the other available monitor is larger.
local current = screen
term = {
  current = function()
    return current
  end,
  redirect = function(nextTerminal)
    current = nextTerminal
  end,
}
colors = {
  black = 32768,
  white = 1,
  gray = 128,
  lightGray = 256,
  orange = 2,
  lightBlue = 8,
  yellow = 16,
  blue = 2048,
  red = 16384,
}
keys = { enter = 28, escape = 1, up = 200, down = 208, pageUp = 201, pageDown = 209, tab = 15, space = 57 }
local mouseSetting = false
config = {
  get = function(name)
    assert(name == "monitorsUseMouseEvents")
    return mouseSetting
  end,
  set = function(name, value)
    assert(name == "monitorsUseMouseEvents")
    mouseSetting = value
  end,
}

local game = E.sandbox(5, 5)
assert(E.place(game, 2, 3, "G", 0))
local actions = {}
local App = {}
App.__index = App
function App.new()
  return setmetatable({
    scene = "game",
    game = game,
    result = E.evaluate(game),
    selected = "G",
    message = "",
    settings = { animations = false, showPorts = false },
    progress = { best = {}, awards = {}, unlocked = 1 },
    slots = {},
  }, App)
end
function App:model()
  return self
end
function App:save()
  return false
end
function App:act(action, x, y)
  actions[#actions + 1] = action
  if action == "cell" then
    assert(E.rotate(game, x, y), "Right-click should rotate the existing cog")
  elseif action == "inspect" or action == "remove" then
    error("Right-click through FPBStore was mistaken for " .. action)
  end
  self.result = E.evaluate(game)
end
local oldApp = package.loaded["games.cogworks.app"]
package.loaded["games.cogworks.app"] = App
local lastRenderer, oldNew = nil, Renderer.new
Renderer.new = function(device)
  assert(device == screen, "Nested launch must prefer FPBStore's active monitor")
  lastRenderer = oldNew(device)
  return lastRenderer
end

local app = { id = "cogworks", name = "COGWORKS", subtitle = "KINETIC LAB", genre = "PUZZLE" }
local manager = { catalog = { apps = { app } } }
function manager.installed()
  return true
end
function manager.status()
  return { installed = true, installedVersion = "2.2.0" }
end
function manager.storeStatus()
  return { installedVersion = "2.0.0" }
end
function manager.refreshVersions()
  return false
end
local launched = 0
function manager.launch()
  launched = launched + 1
  assert(screen.mode == 0, "Store must hand off a clean text-mode monitor")
  assert(loadfile("games/cogworks/main.lua"))()
  assert(not mouseSetting, "Cogworks restores CraftOS monitor mouse configuration")
  assert(screen.mode == 0 and screen.scale == 1, "Cogworks restores graphics and text scale")
end

local events = 0
os.pullEvent = function()
  events = events + 1
  if events == 1 then
    return "key", keys.enter
  end
  return "char", "q"
end
local pointerEvents = 0
os.pullEventRaw = function()
  pointerEvents = pointerEvents + 1
  assert(lastRenderer, "Game renderer initialized before pointer events")
  local x = (lastRenderer.boardX + (2 - 0.5) * lastRenderer.cell) * lastRenderer.scale
  local y = (lastRenderer.boardY + (3 - 0.5) * lastRenderer.cell) * lastRenderer.scale
  if pointerEvents == 1 then
    assert(mouseSetting, "Cogworks enables precise monitor mouse events")
    return "mouse_click", 2, x, y, "left"
  elseif pointerEvents == 2 then
    return "mouse_up", 2, x, y, "left"
  end
  return "terminate"
end
os.startTimer = function()
  return 1
end

local ok, err = pcall(Store.run, manager)
os.pullEvent, os.pullEventRaw, os.startTimer = pull, raw, timer
Renderer.new = oldNew
package.loaded["games.cogworks.app"] = oldApp
term, peripheral, config, colors, keys = original.term, original.peripheral, original.config, original.colors, original.keys
assert(ok, tostring(err))
assert(launched == 1 and pointerEvents == 3, "Store launched the nested game and returned")
assert(game.moves == 2 and E.get(game, 2, 3).r == 1, "Nested monitor right-click rotated and never removed")
assert(actions[1] == "cell", "Actual mouse event uses desktop semantics")
assert(screen.uploads > 0, "Correct monitor received graphics bitmap")
print("COGWORKS: FPBStore same-monitor launch preserves native graphics and right-click rotation.")
