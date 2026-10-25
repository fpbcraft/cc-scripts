-- Installed programs own their globals and module cache.
local bootstrap = loadfile("/games/cogworks/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/games/cogworks" then
  -- selene: allow(undefined_variable) -- Selene misidentifies chunk-level varargs.
  return bootstrap().run("/games/cogworks", "main.lua", _ENV, ...)
end
-- COGWORKS / kinetic workshop for CC:Tweaked Advanced Monitors.
-- Uses CC: Graphics when available, with a vanilla text-mode fallback.
package.path = "/?.lua;/?/init.lua;" .. package.path
local App = require("games.cogworks.app")
local Renderer = require("games.cogworks.render")
local E = require("games.cogworks.engine")
local Display = require("games.cogworks.display")
local args = { ... }
if args[1] == "--test-api" then
  return { app = App, engine = E, renderer = Renderer }
end
local dev = false
local debugInput = false
local preferredMonitor = nil
for _, arg in ipairs(args) do
  if arg == "--dev" then
    dev = true
  elseif arg == "--input-debug" then
    debugInput = true
  elseif arg:sub(1, 2) == "--" then
    error("Unknown option: " .. arg)
  elseif not preferredMonitor then
    preferredMonitor = arg
  else
    error("Only one monitor can be selected")
  end
end
local function selectMonitor(preferred)
  if preferred then
    local m = peripheral.wrap(preferred)
    assert(m and peripheral.getType(preferred) == "monitor", "Unknown monitor: " .. tostring(preferred), 0)
    return m, preferred
  end
  local chosen, name, largest = nil, nil, -1
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "monitor" then
      local m = peripheral.wrap(side)
      local ok, w, h = pcall(m.getSize)
      if ok and w and h then
        -- Always use an attached monitor rather than CraftOS-PC's own screen.
        -- Prefer an Advanced (color) monitor, then the largest surface.
        -- Ordinary monitors remain a supported text-mode fallback.
        local colored = not m.isColor or m.isColor()
        local score = w * h + (colored and 1000000 or 0)
        if score > largest then
          chosen, name, largest = m, side, score
        end
      end
    end
  end
  return chosen, name
end
local function start()
  local monitor, name = selectMonitor(preferredMonitor)
  local mode
  local native = nil
  if not monitor then
    native = term.current()
  end
  monitor, mode = Display.select(monitor, native, require("games.cogworks.terminal_view"), 70, 40)
  local computerMode = Display.isComputer(mode)

  local previous = monitor.getTextScale and monitor.getTextScale() or 1
  if monitor.setTextScale then
    -- Half text scale gives Advanced Monitors their maximum usable resolution.
    -- Restore the original setting when Cogworks exits.
    pcall(monitor.setTextScale, 0.5)
  end
  local inputLog = debugInput and fs.open("/games/cogworks/input-debug.log", "w") or nil
  local function trace(message)
    if inputLog then
      inputLog.write(tostring(message) .. "\n")
    end
  end
  trace("COGWORKS MONITOR=" .. tostring(name) .. " MODE=" .. tostring(mode))
  local renderer, app
  local ok, reason = xpcall(function()
    renderer = Renderer.new(monitor)
    app = App.new({ dev = dev })
    local function redraw()
      renderer:draw(app:model())
      Display.present(monitor, mode)
    end
    local function act(action, x, y)
      if not action then
        return true
      end
      local response = app:act(action, x, y)
      if response == "exit" then
        return false
      end
      redraw()
      return true
    end
    redraw()
    local drag = nil
    local timer = os.startTimer(0.2)
    while true do
      local event, a, b, c, d = os.pullEventRaw()
      if
        event == "monitor_touch"
        or event == "monitor_left_click"
        or event == "monitor_mouse_click"
        or event == "monitor_resize"
        or event == "mouse_click"
      then
        trace(
          tostring(event)
            .. " side="
            .. tostring(a)
            .. " x="
            .. tostring(b)
            .. " y="
            .. tostring(c)
            .. " extra="
            .. tostring(d)
            .. " graphics="
            .. tostring(renderer.mode)
        )
      end
      if event == "terminate" then
        if app then
          app:save()
        end
        break
      elseif event == "monitor_touch" and a == name then
        local action, x, y = renderer:hitTouch(b, c)
        -- CC:Tweaked reports character-cell coordinates. Other monitor
        -- implementations may report graphics pixels; try those only if
        -- character-cell hit testing did not find a control.
        if not action and renderer.mode == "graphics" then
          action, x, y = renderer:hit(b, c)
        end
        if action == "cell" then
          action = app.selected == "erase" and "remove" or "inspect"
        end
        trace("MONITOR HIT=" .. tostring(action) .. " part=" .. tostring(x) .. "," .. tostring(y))
        if not act(action, x, y) then
          break
        end
      elseif not computerMode and (event == "mouse_click" or event == "monitor_mouse_click") then
        -- CraftOS monitor windows can expose a mouse_click event instead of
        -- vanilla monitor_touch. Pixel graphics input uses pixel coordinates.
        if event == "mouse_click" or a == name then
          local mx, my = event == "mouse_click" and b or c, event == "mouse_click" and c or d
          local action, x, y = renderer:hit(mx, my)
          if not action then
            action, x, y = renderer:hitTouch(mx, my)
          end
          if action == "cell" then
            action = app.selected == "erase" and "remove" or "inspect"
          end
          if not act(action, x, y) then
            break
          end
        end
      elseif event == "monitor_left_click" and a == name then
        -- FPB Monitor Input companion sends normalized 0..1 screen positions.
        -- After it is detected, vanilla right-clicks remove directly.
        local action, x, y = renderer:hitNormalized(b, c)
        if action then
          app.hasLeftInput = true
          if action == "cell" then
            action = app.selected == "erase" and "remove" or "inspect"
          end
          if not act(action, x, y) then
            break
          end
        end
      elseif computerMode and event == "mouse_click" then
        local x, y = Display.click(monitor, mode, b, c)
        if x then
          local action, cx, cy = renderer:hit(x, y)
          if action == "cell" then
            drag = { button = a, x = cx, y = cy, moved = false }
          elseif not act(action, cx, cy) then
            break
          end
        end
      elseif computerMode and event == "mouse_drag" and drag then
        local x, y = Display.click(monitor, mode, b, c)
        if x then
          local action, cx, cy = renderer:hit(x, y)
          if action == "cell" and (cx ~= drag.x or cy ~= drag.y) then
            drag.moved = true
          end
        end
      elseif computerMode and event == "mouse_up" and drag then
        local start = drag
        drag = nil
        local x, y = Display.click(monitor, mode, b, c)
        local action, cx, cy
        if x then
          action, cx, cy = renderer:hit(x, y)
        end
        if start.moved then
          if action == "cell" then
            app.moveX, app.moveY = cx, cy
            if not act("move", start.x, start.y) then
              break
            end
          end
        elseif not act(start.button == 1 and "remove" or "cell", start.x, start.y) then
          break
        end
      elseif mode == "virtual-text" and event == "mouse_scroll" then
        monitor.pan(0, a * 3)
      elseif computerMode and event == "term_resize" then
        renderer:resize()
        redraw()
      elseif event == "monitor_resize" and a == name then
        renderer:resize()
        redraw()
      elseif event == "timer" and a == timer then
        if
          renderer.mode == "graphics"
          and app.settings.animations
          and (app.scene == "game" or app.scene == "briefing" or app.scene == "tutorial")
        then
          redraw()
        end
        -- Peripheral monitor graphics need fewer pushes than native CraftOS-PC.
        timer = os.startTimer(app.scene == "briefing" and 0.15 or (computerMode and 0.2 or 0.3))
      elseif event == "char" then
        local char = tostring(a):lower()
        local n = tonumber(char)
        if n and n >= 1 and n <= 9 then
          if not act("tool", E.order[n]) then
            break
          end
        elseif char == "0" then
          act("tool", E.order[10])
        elseif char == "x" then
          act("tool", "erase")
        elseif char == "t" then
          act("tool", "R")
        elseif char == "s" then
          act("save")
        elseif char == "n" then
          act(app.scene == "briefing" and "beginLevel" or "next")
        elseif char == " " and app.scene == "briefing" then
          act("beginLevel")
        elseif char == "p" or char == "q" then
          if app.scene == "game" then
            act("pause")
          elseif app.scene == "pause" then
            act("resume")
          elseif app.scene == "title" and char == "q" then
            if not act("exit") then
              break
            end
          end
        elseif char == "b" then
          act("back")
        end
      elseif event == "key" and keys then
        if mode == "virtual-text" and (a == keys.up or a == keys.down or a == keys.left or a == keys.right) then
          local dx = a == keys.left and -8 or (a == keys.right and 8 or 0)
          local dy = a == keys.up and -5 or (a == keys.down and 5 or 0)
          monitor.pan(dx, dy)
        elseif (a == keys.enter or a == keys.numPadEnter or a == keys.space) and app.scene == "briefing" then
          act("beginLevel")
        elseif a == keys.escape or a == keys.backspace then
          local state = app.scene
          if state == "game" then
            act("pause")
          elseif state == "pause" then
            act("resume")
          else
            act("back")
          end
        elseif a == keys.left and app.scene == "game" then
          act("prev")
        elseif a == keys.right and app.scene == "game" then
          act("next")
        end
      end
    end
  end, function(e)
    return tostring(e) .. (debug and debug.traceback and "\n" .. debug.traceback() or "")
  end)
  if renderer then
    renderer:close()
  end
  if inputLog then
    inputLog.close()
  end
  Display.close(monitor, mode)
  if monitor.setTextScale then
    pcall(monitor.setTextScale, previous)
  end
  if not ok then
    error(reason, 0)
  end
end
start()
