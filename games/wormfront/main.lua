-- WORMFRONT v0.2: timed hotseat or authoritative rednet artillery.
local bootstrap = loadfile("/games/wormfront/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/games/wormfront" then
  -- selene: allow(undefined_variable) -- Forward launch arguments through the isolated loader.
  return bootstrap().run("/games/wormfront", "main.lua", _ENV, ...)
end

local args = { ... }
local Sim = require("sim")
local UI = require("ui")
local Display = require("lib.fpb.display")
local protocol = "fpb.wormfront.v3"
local role = args[1] or "local"
if role == "--test-api" then
  return { UI = UI, Sim = Sim }
end
assert(role == "local" or role == "host" or role == "join", "Usage: main.lua [local [2-4] | host | join [ID]]")

local function now()
  if os.epoch then
    return os.epoch("utc") / 1000
  end
  return os.clock()
end

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
local game, status, quit, frame = nil, "", false, 0
if role == "local" then
  game = Sim.new(math.max(2, math.min(4, tonumber(args[2]) or 2)), os.epoch and os.epoch("utc") or 42)
  slot = 0
elseif role == "host" then
  hostId = os.getComputerID()
  slot = 1
  players[1] = hostId
  rednet.host(protocol, "wormfront-" .. hostId)
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
end

local monitor, monitorName
if peripheral and peripheral.getNames then
  local largest = -1
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
      local candidate = peripheral.wrap(name)
      local w, h = candidate.getSize()
      if w * h > largest then
        monitor, monitorName, largest = candidate, name, w * h
      end
    end
  end
end

local originalScale = monitor and monitor.getTextScale and monitor.getTextScale() or nil
if monitor and monitor.setTextScale then
  monitor.setTextScale(0.5)
end
local mode
monitor, mode = Display.select(monitor, term.current(), require("lib.fpb.terminal_view"), 98, 72)
local computerMode = Display.isComputer(mode)

local function packet(kind, extra)
  local data = extra or {}
  data.tag, data.type = protocol, kind
  return data
end

local function send(id, kind, extra)
  rednet.send(id, packet(kind, extra), protocol)
end

local sequence = 0
local terrainAcknowledged = {}
local broadcastDirty = false
local function publish()
  if role ~= "host" or not game then
    return
  end
  sequence = sequence + 1
  local withoutTerrain
  for i = 2, #players do
    local id = players[i]
    local state = game
    if terrainAcknowledged[id] == game.terrainRevision then
      if not withoutTerrain then
        withoutTerrain = {}
        for key, value in pairs(game) do
          if key ~= "terrain" then
            withoutTerrain[key] = value
          end
        end
      end
      state = withoutTerrain
    end
    send(id, "state", { game = state, count = #players, seq = sequence })
  end
end

local ui
local function redraw()
  frame = frame + 1
  ui:draw(game, {
    role = role,
    slot = slot,
    count = count,
    hostId = hostId,
    status = status,
    frame = frame,
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
    if slot and game.turn == slot and game.state == "aim" then
      send(hostId, "action", { action = action })
    end
    return
  end
  local team = role == "local" and game.turn or 1
  local ok, err = Sim.apply(game, team, action)
  if not ok then
    status = err
  elseif role == "host" then
    broadcastDirty = true
  end
end

ui = UI.new(monitor, dispatch)
local newestState = -1
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
        terrainAcknowledged[sender] = nil
        publish()
      else
        send(sender, "denied")
      end
    elseif data.type == "action" and game and type(data.action) == "table" then
      if players[game.turn] == sender then
        local ok = Sim.apply(game, game.turn, data.action)
        if ok then
          broadcastDirty = true
        else
          broadcastDirty = true
        end
      end
    elseif data.type == "terrain_ack" then
      for i = 2, #players do
        if players[i] == sender and data.revision == game.terrainRevision then
          terrainAcknowledged[sender] = data.revision
          break
        end
      end
    elseif data.type == "terrain_request" then
      terrainAcknowledged[sender] = nil
      publish()
    end
  elseif role == "join" and sender == hostId then
    if data.type == "welcome" then
      slot, count = data.slot, data.count
      status = "CONNECTED AS TEAM " .. tostring(slot)
    elseif data.type == "state" and type(data.game) == "table" and type(data.seq) == "number" then
      if data.seq >= newestState then
        local state = data.game
        if not state.terrain then
          if not game or not game.terrain or game.terrainRevision ~= state.terrainRevision then
            send(hostId, "terrain_request")
            return
          end
          state.terrain = game.terrain
        else
          send(hostId, "terrain_ack", { revision = state.terrainRevision })
        end
        newestState = data.seq
        game, count = state, data.count
        status = ""
      end
    elseif data.type == "denied" then
      status = "MATCH FULL OR ALREADY STARTED"
    elseif data.type == "closed" then
      status = "HOST CLOSED MATCH"
      quit = true
    end
  end
end

local held = {}
local function keyAction(key)
  if key == keys.left then
    return { kind = "move", dir = -1 }
  elseif key == keys.right then
    return { kind = "move", dir = 1 }
  elseif key == keys.up then
    return { kind = "aim", dir = 1 }
  elseif key == keys.down then
    return { kind = "aim", dir = -1 }
  end
end

local lastTime = now()
local lastBroadcast = now()
local lastDraw = now()
local lastJoin = 0
local function simulationStep()
  local current = now()
  local dt = math.max(0, current - lastTime)
  lastTime = current
  if role ~= "join" and game then
    local previousTurn = game.turn
    Sim.tick(game, dt)
    if previousTurn ~= game.turn then
      held = {}
    end
  end
  if role == "join" and not slot and current - lastJoin >= 3 then
    send(hostId, "join")
    lastJoin = current
  end
  if keys then
    for key, nextAt in pairs(held) do
      if current >= nextAt then
        local action = keyAction(key)
        if action then
          dispatch(action)
          held[key] = current + 0.11
        end
      end
    end
  end
  if role == "host" and game and current - lastBroadcast >= (broadcastDirty and 0.12 or 0.28) then
    publish()
    lastBroadcast = current
    broadcastDirty = false
  end
  if current - lastDraw >= (ui.r.buffered and 0.10 or 0.2) then
    redraw()
    lastDraw = current
  end
end

local function run()
  redraw()
  if role == "join" then
    send(hostId, "join")
    lastJoin = now()
  end
  local timer = os.startTimer(0.05)
  while not quit do
    local event, a, b, c = os.pullEvent()
    if event == "timer" and a == timer then
      simulationStep()
      timer = os.startTimer(0.05)
    elseif event == "monitor_touch" and (not monitorName or a == monitorName) then
      ui:touch(b, c)
    elseif event == "mouse_click" and computerMode then
      local x, y = Display.click(monitor, mode, b, c)
      if x then
        ui:touch(x, y)
      end
    elseif event == "mouse_scroll" and mode == "virtual-text" then
      monitor.pan(0, a * 4)
    elseif event == "key" and keys then
      local key = a
      local action = keyAction(key)
      if action then
        if not held[key] then
          dispatch(action)
          held[key] = now() + 0.2
        end
      elseif key == keys.space then
        if not held[key] then
          dispatch({ kind = "charge" })
          held[key] = math.huge
        end
      elseif key == keys.j then
        dispatch({ kind = "jump" })
      elseif key == keys.r or key == keys.t then
        dispatch({ kind = "rope" })
      elseif key == keys.pageUp then
        dispatch({ kind = "reel", dir = -1 })
      elseif key == keys.pageDown then
        dispatch({ kind = "reel", dir = 1 })
      elseif key == keys.enter then
        dispatch({ kind = "pass" })
      end
    elseif event == "key_up" and keys then
      if a == keys.space and held[a] then
        dispatch({ kind = "release" })
      end
      held[a] = nil
    elseif event == "char" then
      local kind = (a == "w" and "weapon") or (a == "f" and "fire") or (a == "q" and "exit") or nil
      if kind then
        dispatch({ kind = kind })
      elseif a:match("^[0-9]$") then
        local id = tonumber(a)
        dispatch({ kind = "weapon", id = id == 0 and 10 or id })
      end
    elseif event == "rednet_message" then
      network(a, b, c)
    elseif event == "monitor_resize" or event == "term_resize" then
      ui:resize()
      lastDraw = 0
    end
  end
end

local success, failure = xpcall(run, function(err)
  return tostring(err) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
ui:close()
Display.close(monitor, mode)
if originalScale and monitor.setTextScale then
  pcall(monitor.setTextScale, originalScale)
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
