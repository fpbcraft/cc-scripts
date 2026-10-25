-- COGWORKS kinetic simulation. The board is a 2D teaching abstraction of
-- Create: axial shaft links, side meshing, clear-span belts and bevel gearboxes.
local levels = require("games.cogworks.levels")
local E = { levels = levels, WIDTH = 7, HEIGHT = 6 }
local vectors = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
local ports = {
  S = { 0 }, M = { 0 }, I = { 0, 2 }, G = { 0, 2 },
  O = { 0, 2 }, V = { 0, 2 }, Z = { 0, 2 }, C = { 0, 2 },
  Q = { 0, 1, 2, 3 }, D = { 0, 2 },
}
E.parts = {
  I = { name = "SHAFT", description = "AXIAL ROTATION, 1:1", color = 11 },
  G = { name = "SMALL COG", description = "SHAFTS AXIALLY; MESHES SIDEWAYS", color = 14 },
  O = { name = "LARGE COG", description = "SIDE MESH OR DIAGONAL 2:1", color = 7 },
  Q = { name = "GEARBOX", description = "FOUR SIDES; REVERSES SPIN", color = 13 },
  D = { name = "CHAIN DRIVE", description = "AXIAL SHAFT AND SIDE CHAIN LINKS", color = 11 },
  V = { name = "BELT PULLEY", description = "PARALLEL SHAFTS; CLEAR SPAN", color = 7 },
  Z = { name = "GEARSHIFT", description = "TOGGLE TO REVERSE", color = 6 },
  C = { name = "CLUTCH", description = "TOGGLE TO DISCONNECT", color = 8 },
}
E.order = { "I", "G", "O", "Q", "D", "V", "Z", "C" }
local function index(x, y)
  return (y - 1) * E.WIDTH + x
end
function E.inside(x, y)
  return type(x) == "number" and type(y) == "number"
    and x >= 1 and x <= E.WIDTH and y >= 1 and y <= E.HEIGHT
    and x % 1 == 0 and y % 1 == 0
end
function E.hasPort(tile, dir)
  for _, p in ipairs(ports[tile.kind] or {}) do
    if (p + tile.r) % 4 == dir then
      return true
    end
  end
  return false
end
function E.get(g, x, y)
  return E.inside(x, y) and g.map[index(x, y)] or nil
end
local function add(g, value, fixed)
  assert(E.inside(value.x, value.y), "Invalid level coordinates")
  local id = index(value.x, value.y)
  assert(not g.map[id], "Overlapping level part at " .. id)
  local t = {
    id = id, x = value.x, y = value.y, kind = value.kind,
    r = value.r or 0, fixed = not not fixed,
    speed = value.speed, sign = value.sign,
    engaged = value.engaged == true,
  }
  g.map[id] = t
  g.tiles[#g.tiles + 1] = t
  return t
end
local function copy(t)
  local result = {}
  for k, v in pairs(t) do
    result[k] = v
  end
  return result
end
function E.new(number, solved)
  local data = assert(levels[number], "Invalid level")
  local g = {
    number = number, name = data.name, tip = data.tip,
    tiles = {}, map = {}, stock = copy(data.stock),
    remaining = copy(data.stock), moves = 0,
    fullNetwork = false, sandbox = false,
  }
  add(g, data.source, true)
  for _, goal in ipairs(data.goals) do
    add(g, goal, true)
  end
  for _, fixture in ipairs(data.fixtures or {}) do
    add(g, fixture, true)
  end
  for _, v in ipairs(data.blocks or {}) do
    add(g, { kind = "X", x = v[1], y = v[2] }, true)
  end
  if solved then
    for _, v in ipairs(data.build) do
      assert(g.remaining[v.kind] > 0, "Invalid reference inventory")
      g.remaining[v.kind] = g.remaining[v.kind] - 1
      add(g, v, false)
    end
    for _, v in ipairs(data.toggles or {}) do
      assert(E.toggle(g, v[1], v[2]), "Invalid authored toggle")
    end
  end
  return g
end
function E.sandbox()
  local g = {
    number = 0, name = "FREE WORKSHOP",
    tip = "EXPERIMENT WITH ALL PARTS. NO GOALS OR LIMITS.",
    tiles = {}, map = {}, stock = {}, remaining = {},
    moves = 0, fullNetwork = false, sandbox = true,
  }
  for _, kind in ipairs(E.order) do
    g.remaining[kind] = math.huge
  end
  add(g, { kind = "S", x = 1, y = 3, r = 1 }, true)
  return g
end
function E.place(g, x, y, kind, rotation)
  if not E.inside(x, y) or not E.parts[kind] or E.get(g, x, y) then
    return false
  end
  if not g.sandbox and (g.remaining[kind] or 0) < 1 then
    return false
  end
  if not g.sandbox then
    g.remaining[kind] = g.remaining[kind] - 1
  end
  add(g, { kind = kind, x = x, y = y, r = (rotation or 0) % 4 }, false)
  g.moves = g.moves + 1
  return true
end
function E.remove(g, x, y)
  local tile = E.get(g, x, y)
  if not tile or tile.fixed then
    return false
  end
  g.map[tile.id] = nil
  for i, v in ipairs(g.tiles) do
    if v == tile then
      table.remove(g.tiles, i)
      break
    end
  end
  if not g.sandbox then
    g.remaining[tile.kind] = g.remaining[tile.kind] + 1
  end
  g.moves = g.moves + 1
  return true
end
function E.rotate(g, x, y)
  local tile = E.get(g, x, y)
  if not tile or tile.fixed then
    return false
  end
  tile.r = (tile.r + 1) % 4
  g.moves = g.moves + 1
  return true
end
function E.toggle(g, x, y)
  local tile = E.get(g, x, y)
  if not tile or (tile.kind ~= "C" and tile.kind ~= "Z") then
    return false
  end
  -- Fixed puzzle switches can be operated, but not moved or rotated.
  tile.engaged = not tile.engaged
  g.moves = g.moves + 1
  return true
end
-- Direct shaft / gearbox / chain connections require two facing shaft ports.
function E.connection(g, tile, dir)
  if not E.hasPort(tile, dir) then
    return nil
  end
  local d = vectors[dir + 1]
  local neighbor = E.get(g, tile.x + d[1], tile.y + d[2])
  if neighbor and E.hasPort(neighbor, (dir + 2) % 4) then
    return neighbor
  end
  return nil
end
-- Cogs have an axial shaft, but teeth mesh PERPENDICULAR to that shaft.
-- Equal-sized gears mesh side by side; small/large 2:1 gears mesh diagonally.
-- Pulley belts also run perpendicular to two parallel shafts, without gearing.
function E.meshes(g, tile)
  local links = {}
  if tile.kind ~= "G" and tile.kind ~= "O" and tile.kind ~= "V" and tile.kind ~= "D" then
    return links
  end
  local horizontal = tile.r % 2 == 1
  local function matching(other)
    return other and other.r % 2 == tile.r % 2
  end
  if tile.kind == "D" then
    local sideways = horizontal and { { 0, -1 }, { 0, 1 } } or { { -1, 0 }, { 1, 0 } }
    for _, d in ipairs(sideways) do
      local other = E.get(g, tile.x + d[1], tile.y + d[2])
      if other and other.kind == "D" and matching(other) then
        links[#links + 1] = { tile = other, ratio = 1, sign = 1, chain = true }
      end
    end
    return links
  end
  if tile.kind == "V" then
    for _, side in ipairs({ -1, 1 }) do
      for distance = 1, 5 do
        local x = tile.x + (horizontal and 0 or side * distance)
        local y = tile.y + (horizontal and side * distance or 0)
        if not E.inside(x, y) then
          break
        end
        local other = E.get(g, x, y)
        if other then
          if other.kind == "V" and matching(other) and distance >= 2 then
            links[#links + 1] = { tile = other, ratio = 1, sign = 1, belt = true }
          end
          -- Belts cannot pass through stone, machinery or another pulley.
          break
        end
      end
    end
    return links
  end
  local otherKind = tile.kind == "G" and "O" or "G"
  local perpendicular = horizontal and { { 0, -1 }, { 0, 1 } } or { { -1, 0 }, { 1, 0 } }
  for _, d in ipairs(perpendicular) do
    local other = E.get(g, tile.x + d[1], tile.y + d[2])
    if other and other.kind == tile.kind and matching(other) then
      links[#links + 1] = { tile = other, ratio = 1, sign = -1 }
    end
  end
  for _, dx in ipairs({ -1, 1 }) do
    for _, dy in ipairs({ -1, 1 }) do
      local other = E.get(g, tile.x + dx, tile.y + dy)
      if other and other.kind == otherKind and matching(other) then
        links[#links + 1] = { tile = other, ratio = tile.kind == "O" and 2 or 0.5, sign = -1 }
      end
    end
  end
  return links
end
function E.snapshot(g)
  local list = {}
  for _, tile in ipairs(g.tiles) do
    if not tile.fixed or tile.kind == "C" or tile.kind == "Z" then
      list[#list + 1] = {
        x = tile.x, y = tile.y, kind = tile.kind, r = tile.r,
        engaged = tile.engaged, fixed = tile.fixed or nil,
      }
    end
  end
  table.sort(list, function(a, b)
    if a.y == b.y then
      return a.x < b.x
    end
    return a.y < b.y
  end)
  return list
end
function E.restore(g, list)
  if type(list) ~= "table" or #list > E.WIDTH * E.HEIGHT then
    return false
  end
  local trial = g.sandbox and E.sandbox() or E.new(g.number)
  for _, v in ipairs(list) do
    if type(v) ~= "table" or not E.inside(v.x, v.y)
      or type(v.r) ~= "number" or v.r % 1 ~= 0 or v.r < 0 or v.r > 3
      or (v.engaged ~= nil and type(v.engaged) ~= "boolean")
    then
      return false
    end
    local tile
    if v.fixed == true then
      tile = E.get(trial, v.x, v.y)
      if not tile or not tile.fixed or tile.kind ~= v.kind or tile.r ~= v.r
        or (tile.kind ~= "C" and tile.kind ~= "Z") or type(v.engaged) ~= "boolean"
      then
        return false
      end
    else
      if not E.place(trial, v.x, v.y, v.kind, v.r) then
        return false
      end
      tile = E.get(trial, v.x, v.y)
    end
    if tile.kind == "C" or tile.kind == "Z" then
      tile.engaged = v.engaged == true
    elseif v.engaged then
      return false
    end
  end
  g.map, g.tiles, g.remaining = trial.map, trial.tiles, trial.remaining
  g.moves = 0
  return true
end
function E.evaluate(g)
  local states, queue, first = {}, {}, 1
  local jam = false
  local function assign(tile, port, rate, sign, internal)
    local slots = states[tile.id]
    if not slots then
      slots = {}
      states[tile.id] = slots
    end
    local existing = slots[port]
    if existing then
      if math.abs(existing.rate - rate) > 0.001 or existing.sign ~= sign then
        jam = true
      end
      return
    end
    local state = { rate = rate, sign = sign }
    slots[port] = state
    queue[#queue + 1] = { tile = tile, port = port, info = state, internal = internal }
  end
  for _, tile in ipairs(g.tiles) do
    if tile.kind == "S" then
      assign(tile, tile.r, 1, 1)
    end
  end
  while first <= #queue do
    local event = queue[first]
    first = first + 1
    local tile, port, info = event.tile, event.port, event.info
    if (tile.kind ~= "C" or not tile.engaged) and not event.internal then
      for dir = 0, 3 do
        if dir ~= port and E.hasPort(tile, dir) then
          local sign = info.sign
          if tile.kind == "Q" or (tile.kind == "Z" and tile.engaged) then
            sign = -sign
          end
          assign(tile, dir, info.rate, sign, true)
        end
      end
      for _, link in ipairs(E.meshes(g, tile)) do
        assign(link.tile, link.tile.r, info.rate * link.ratio, info.sign * link.sign)
      end
    end
    local neighbor = E.connection(g, tile, port)
    if neighbor then
      assign(neighbor, (port + 2) % 4, info.rate, info.sign)
    end
  end
  local lights, goals, correct, powered = {}, 0, 0, 0
  local openPorts, unpowered = 0, 0
  for _, tile in ipairs(g.tiles) do
    local slots = states[tile.id] or {}
    local sample = slots[next(slots)]
    local light = {
      powered = sample ~= nil, rate = sample and sample.rate or 0,
      sign = sample and sample.sign or 0, ports = slots,
    }
    if sample then
      powered = powered + 1
    elseif E.parts[tile.kind] then
      unpowered = unpowered + 1
    end
    if tile.kind ~= "X" then
      for dir = 0, 3 do
        if E.hasPort(tile, dir) and not E.connection(g, tile, dir) then
          openPorts = openPorts + 1
        end
      end
    end
    if tile.kind == "M" then
      goals = goals + 1
      local actual = slots[tile.r]
      light.correct = not not (
        actual and actual.sign == tile.sign and math.abs(actual.rate - tile.speed) < 0.001
      )
      if light.correct then
        correct = correct + 1
      end
    end
    lights[tile.id] = light
  end
  local remaining = 0
  if not g.sandbox then
    for _, count in pairs(g.remaining) do
      remaining = remaining + count
    end
  end
  return {
    lights = lights, powered = powered, goals = goals, correct = correct,
    jam = jam, openPorts = openPorts, unpowered = unpowered,
    remaining = remaining, complete = not jam and goals == correct,
    win = not g.sandbox and not jam and goals > 0 and goals == correct,
  }
end
function E.challenges(g, result)
  if g.sandbox then
    return {}
  end
  local list = {}
  local par = 0
  for _, tile in ipairs(levels[g.number].build) do
    par = par + 1 + (tile.r or 0)
  end
  par = par + #(levels[g.number].toggles or {})
  local function add(id, name, description, earned)
    list[#list + 1] = {
      id = id, name = name, description = description,
      earned = result.win and earned or false,
    }
  end
  if g.number >= 2 then
    add("sealed", "NO IDLE PARTS", "EVERY PLACED PART GETS POWER", result.unpowered == 0)
  end
  if g.number >= 3 then
    add("master", "USE EVERY PART", "ALL STOCK USED AND POWERED",
      result.remaining == 0 and result.unpowered == 0)
  end
  if g.number >= 5 then
    add("precision", "PRECISION", "AT MOST " .. par .. " MOVES", g.moves <= par)
  end
  return list
end
return E
