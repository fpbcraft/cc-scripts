-- WORMFRONT: local hotseat or remote rednet artillery.
local bootstrap = loadfile("/games/wormfront/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/games/wormfront" then
  -- selene: allow(undefined_variable) -- Forward launch arguments to the isolated loader.
  return bootstrap().run("/games/wormfront", "main.lua", _ENV, ...)
end

local args = { ... }
local Sim = require("sim")
local UI = require("ui")
local Display = require("lib.fpb.display")
local protocol = "fpb.wormfront.v1"
local role = args[1] or "local"
if role == "--test-api" then
  return { UI = UI, Sim = Sim }
end
assert(role == "local" or role == "host" or role == "join", "Usage: main.lua [local [2-4] | host | join [ID]]")

local modemSide
if role ~= "local" then
  assert(rednet and peripheral, "Remote multiplayer requires rednet and a modem")
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" or (peripheral.hasType and peripheral.hasType(name, "modem")) then
      modemSide = name
      break
    end
  end
  assert(modemSide, "Attach a wired or wireless modem")
  rednet.open(modemSide)
end

local players, slot, hostId, count = {}, nil, nil, 1
local game, status, quit = nil, "", false
if role == "local" then
  game = Sim.new(math.max(2, math.min(4, tonumber(args[2]) or 2)), os.epoch and os.epoch("utc") or 42)
  slot = 0
elseif role == "host" then
  local id = os.getComputerID()
  players[1] = id
  slot, hostId = 1, id
  rednet.host(protocol, "wormfront-" .. id)
  status = "WAITING FOR PLAYERS"
elseif role == "join" then
  hostId = tonumber(args[2])
  if not hostId then
    local hosts = { rednet.lookup(protocol) }
    table.sort(hosts)
    hostId = hosts[1]
  end
  assert(hostId, "No WORMFRONT host found; use join HOST_ID")
  status = "CONNECTING TO " .. hostId
  rednet.send(hostId, { tag = protocol, type = "join" }, protocol)
end

local monitor, monitorName
if peripheral and peripheral.getNames then
  local area = -1
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
      local found = peripheral.wrap(name)
      local w, h = found.getSize()
      if w * h > area then
        monitor, monitorName, area = found, name, w * h
      end
    end
  end
end
local oldScale = monitor and monitor.getTextScale and monitor.getTextScale() or nil
if monitor and monitor.setTextScale then
  monitor.setTextScale(0.5)
end
local mode
monitor, mode = Display.select(monitor, term.current(), require("lib.fpb.terminal_view"), 98, 72)
local computerMode = Display.isComputer(mode)

local function packet(kind, extra)
  local data = extra or {}
  data.tag = protocol
  data.type = kind
  return data
end

local function send(id, kind, extra)
  rednet.send(id, packet(kind, extra), protocol)
end

local function publish()
  if role ~= "host" then
    return
  end
  for i = 2, #players do
    send(players[i], "state", { game = game, count = #players })
  end
end

local function redraw()
  ui:draw(game, {
    role = role,
    slot = slot,
    count = count,
    hostId = hostId,
    status = status,
  })
  Display.present(monitor, mode)
end

local function dispatch(action)
  if action.kind == "exit" then
    quit = true
    if role == "host" then
      for i = 2, #players do
        send(players[i], "closed")
      end
    end
    return
  end
  if action.kind == "start" then
    if role == "host" and not game and #players >= 2 then
      game = Sim.new(#players, os.epoch and os.epoch("utc") or 42)
      count = #players
      publish()
    else
      status = "NEED AT LEAST TWO PLAYERS"
    end
    return
  end
  if not game then
    return
  end
  if role == "join" then
    if slot and game.turn == slot then
      send(hostId, "action", { action = action })
    end
    return
  end
  local team = role == "local" and game.turn or 1
  local ok, err = Sim.apply(game, team, action)
  if not ok then
    status = err
    game.message = err
  elseif role == "host" then
    publish()
  end
end

-- UI callbacks are invoked only after the complete UI has been initialized.
local ui = UI.new(monitor, dispatch)

local function network(sender, data, channel)
  if channel ~= protocol or type(data) ~= "table" or data.tag ~= protocol then
    return
  end
  if role == "host" then
    if data.type == "join" then
      local index
      for i, id in ipairs(players) do
        if id == sender then
          index = i
          break
        end
      end
      if not index and not game and #players < 4 then
        players[#players + 1] = sender
        index = #players
      end
      if index then
        count = #players
        send(sender, "welcome", { slot = index, count = count })
        publish()
      else
        send(sender, "denied")
      end
    elseif data.type == "action" and game and type(data.action) == "table" then
      if players[game.turn] == sender then
        local ok = Sim.apply(game, game.turn, data.action)
        if ok then
          publish()
        else
          send(sender, "state", { game = game, count = #players })
        end
      end
    end
  elseif role == "join" and sender == hostId then
    if data.type == "welcome" then
      slot, count = data.slot, data.count
      status = "CONNECTED AS TEAM " .. tostring(slot)
    elseif data.type == "state" then
      game, count = data.game, data.count
      status = ""
    elseif data.type == "denied" then
      status = "MATCH FULL OR ALREADY STARTED"
    elseif data.type == "closed" then
      status = "HOST CLOSED THE MATCH"
      quit = true
    end
  end
end

local function run()
  redraw()
  while not quit do
    local event, a, b, c = os.pullEvent()
    if event == "monitor_touch" and (not monitorName or a == monitorName) then
      ui:touch(b, c)
      redraw()
    elseif event == "mouse_click" and computerMode then
      local x, y = Display.click(monitor, mode, b, c)
      if x then
        ui:touch(x, y)
        redraw()
      end
    elseif event == "mouse_scroll" and mode == "virtual-text" then
      monitor.pan(0, a * 4)
    elseif event == "key" and keys then
      local action
      if a == keys.left then
        action = { kind = "move", dir = -1 }
      elseif a == keys.right then
        action = { kind = "move", dir = 1 }
      elseif a == keys.up then
        action = { kind = "aim", dir = 1 }
      elseif a == keys.down then
        action = { kind = "aim", dir = -1 }
      elseif a == keys.pageUp then
        action = { kind = "power", dir = 1 }
      elseif a == keys.pageDown then
        action = { kind = "power", dir = -1 }
      elseif a == keys.tab then
        action = { kind = "select" }
      elseif a == keys.space then
        action = { kind = "fire" }
      end
      if action then
        dispatch(action)
        redraw()
      end
    elseif event == "char" then
      local action = a == "m" and "weapon" or a == "q" and "exit" or nil
      if action then
        dispatch({ kind = action })
        redraw()
      end
    elseif event == "rednet_message" then
      network(a, b, c)
      redraw()
    elseif event == "monitor_resize" or event == "term_resize" then
      ui:resize()
      redraw()
    end
  end
end

local success, failure = xpcall(run, function(err)
  return tostring(err) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
ui:close()
Display.close(monitor, mode)
if oldScale and monitor.setTextScale then
  pcall(monitor.setTextScale, oldScale)
end
if role == "host" then
  rednet.unhost(protocol, "wormfront-" .. hostId)
end
if modemSide then
  rednet.close(modemSide)
end
if not success then
  error(failure, 0)
end
