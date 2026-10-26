package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local App = require("games.cogworks.app")
local Renderer = require("games.cogworks.render")
local game = E.sandbox(5, 5)
assert(E.place(game, 2, 3, "G", 1))
local app = setmetatable({
  scene = "game",
  game = game,
  result = E.evaluate(game),
  selected = "G",
  message = "",
  devSession = true,
  progress = { best = {}, awards = {} },
  settings = { animations = false, showPorts = true },
  slots = {},
  store = {
    saveSettings = function()
      return true
    end,
  },
}, App)
function app:model()
  return self
end
package.loaded["games.cogworks.app"] = {
  new = function()
    return app
  end,
}
local native = { pw = 600, ph = 495 }
function native.getSize(mode)
  return mode == 2 and native.pw or 100, mode == 2 and native.ph or 55
end
function native.setGraphicsMode() end
function native.setPaletteColor() end
function native.drawPixels() end
term = {
  current = function()
    return native
  end,
}
peripheral = {
  getNames = function()
    return {}
  end,
}
keys = { escape = 1 }
local renderer, oldNew = nil, Renderer.new
Renderer.new = function(device)
  renderer = oldNew(device)
  return renderer
end
local function cell(x, y)
  return (renderer.boardX + (x - 0.5) * renderer.cell) * renderer.scale,
    (renderer.boardY + (y - 0.5) * renderer.cell) * renderer.scale
end
local function event(kind, button, x, y)
  local px, py = cell(x, y)
  return kind, button, px, py
end
local function inventory(button, kind)
  for _, target in ipairs(renderer.targets) do
    if target.action == "tool" and target.arg == kind then
      return "mouse_click",
        button,
        (target.x + target.w / 2) * renderer.scale,
        (target.y + target.h / 2) * renderer.scale
    end
  end
  error("Missing inventory target")
end
local lastTimer, oldTimer, oldPull = 0, os.startTimer, os.pullEventRaw
os.startTimer = function()
  lastTimer = lastTimer + 1
  return lastTimer
end
local moves = game.moves
local steps = {
  function()
    return event("mouse_click", 2, 2, 3)
  end,
  function()
    return "timer", lastTimer
  end, -- long hold must not rotate / move
  function()
    assert(game.moves == moves and E.get(game, 2, 3).r == 1)
    return event("mouse_drag", 2, 3, 3)
  end,
  function()
    assert(app.drag and app.drag.moved and E.get(game, 2, 3))
    return "mouse_drag", 2, 0, 0
  end,
  function()
    assert(not app.drag.valid)
    return event("mouse_up", 2, 3, 4)
  end,
  function()
    assert(E.get(game, 3, 4).r == 1 and not E.get(game, 2, 3))
    return event("mouse_click", 1, 3, 4)
  end,
  function()
    assert(not E.get(game, 3, 4))
    return event("mouse_click", 2, 2, 2)
  end,
  function()
    return "timer", lastTimer
  end, -- click-only right tap still places
  function()
    assert(E.get(game, 2, 2).r == 0)
    return event("mouse_up", 2, 2, 2)
  end,
  function()
    return event("mouse_click", 2, 2, 2)
  end,
  function()
    return event("mouse_up", 2, 2, 2)
  end,
  function()
    assert(E.get(game, 2, 2).r == 1)
    return inventory(1, "O")
  end,
  function()
    return event("mouse_drag", 1, 3, 3)
  end,
  function()
    assert(not E.get(game, 3, 3) and app.drag.origin == "inventory")
    return event("mouse_up", 1, 3, 3)
  end,
  function()
    assert(E.get(game, 3, 3).kind == "O")
    return inventory(2, "I")
  end,
  function()
    return "mouse_drag", 2, 0, 0
  end,
  function()
    return "mouse_up", 2, 0, 0
  end,
  function()
    assert(not app.drag)
    return event("mouse_click", 2, 2, 2)
  end,
  function()
    return event("mouse_drag", 2, 3, 3)
  end,
  function()
    assert(not app.drag.valid)
    return event("mouse_up", 2, 3, 3)
  end,
  function()
    assert(E.get(game, 2, 2).r == 1 and E.get(game, 3, 3).kind == "O")
    return event("mouse_click", 2, 1, 3)
  end,
  function()
    assert(not app.drag, "Fixed source cannot initiate drag")
    return event("mouse_drag", 2, 4, 4)
  end,
  function()
    return event("mouse_up", 2, 4, 4)
  end,
  function()
    assert(not E.get(game, 4, 4))
    return event("mouse_click", 2, 2, 2)
  end,
  function()
    return event("mouse_drag", 2, 4, 4)
  end,
  function()
    return "key", keys.escape
  end,
  function()
    assert(not app.drag and app.scene == "game" and E.get(game, 2, 2))
    return inventory(2, "I")
  end,
  function()
    return event("mouse_drag", 2, 4, 4)
  end,
  function()
    native.pw, native.ph = 800, 450
    return "term_resize"
  end,
  -- Selected-cell remove/rotate hit targets must never hijack a right click.
  function()
    assert(not app.drag and not E.get(game, 4, 4))
    assert(E.get(game, 2, 2).kind == "G")
    app:act("inspect", 2, 2)
    renderer:draw(app:model())
    for _, target in ipairs(renderer.targets) do
      if target.action == "remove" and target.arg == 2 and target.arg2 == 2 then
        local px = (target.x + target.w / 2) * renderer.scale
        local py = (target.y + target.h / 2) * renderer.scale
        assert(renderer:hit(px, py) == "remove", "Remove overlay is reachable")
        app.testRemoveX, app.testRemoveY = px, py
        return "mouse_click", 2, px, py
      end
    end
    error("Missing selected-cell remove overlay")
  end,
  function()
    assert(E.get(game, 2, 2), "Right press on remove overlay must not delete")
    return "mouse_up", 2, app.testRemoveX, app.testRemoveY
  end,
  function()
    assert(E.get(game, 2, 2), "Right release on remove overlay must not delete")
    app.selected = "erase"
    return event("mouse_click", 2, 2, 2)
  end,
  function()
    assert(E.get(game, 2, 2), "Right click with erase selected must not delete")
    return event("mouse_up", 2, 2, 2)
  end,
  function()
    assert(E.get(game, 2, 2), "Right release with erase selected must not delete")
    return event("mouse_click", 1, 2, 2)
  end,
  function()
    assert(not E.get(game, 2, 2), "Left click should still delete with erase selected")
    assert(E.get(game, 3, 3), "Unrelated part was preserved")
    return "terminate"
  end,
}
local nextStep = 0
os.pullEventRaw = function()
  nextStep = nextStep + 1
  return assert(steps[nextStep], "Unexpected extra event")()
end
local ok, reason = pcall(assert(loadfile("games/cogworks/main.lua")))
os.startTimer, os.pullEventRaw, Renderer.new = oldTimer, oldPull, oldNew
assert(ok, tostring(reason))
assert(nextStep == #steps)
print(
  "COGWORKS: real mouse dispatcher handles long holds, left removal, right construction, inventory drags, invalid releases, Escape and resize."
)
