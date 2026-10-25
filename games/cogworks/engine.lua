-- COGWORKS kinetic simulation. The board is a 2D teaching abstraction of
-- Create: axial shaft links, side meshing, clear-span belts and bevel gearboxes.
local levels = require("games.cogworks.levels")
local E = { levels = levels, WIDTH = 7, HEIGHT = 6, MAX_SIZE = 10 }
local vectors = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
local ports = {
  S = { 0 },
  M = { 0 },
  I = { 0, 2 },
  G = { 0, 2 },
  O = { 0, 2 },
  V = { 0, 2 },
  Z = { 0, 2 },
  C = { 0, 2 },
  Q = { 0, 1, 2, 3 },
  D = { 0, 2 },
}
E.parts = {
  I = { name = "SHAFT", description = "AXIAL ROTATION, 1:1", color = 11 },
  G = { name = "SMALL COG", description = "SHAFTS AXIALLY; MESHES SIDEWAYS", color = 14 },
  O = { name = "LARGE COG", description = "SIDE MESH OR DIAGONAL 2:1", color = 7 },
  Q = { name = "GEARBOX", description = "FOUR SIDES; REVERSES SPIN", color = 13 },
  D = { name = "CHAIN DRIVE", description = "AXIAL SHAFT AND SIDE CHAIN LINKS", color = 11 },
  V = { name = "BELT PULLEY", description = "PARALLEL SHAFTS; CLEAR SPAN", color = 7 },
  Z = { name = "GEARSHIFT", description = "TOGGLE TO REVERSE", color = 6 },
  C = { name = "CLUTCH", description = "REDSTONE DISCONNECTS SHAFT", color = 8 },
  R = { name = "REDSTONE DUST", description = "CONNECTS TO POWER BLOCKS", color = 8 },
  B = { name = "REDSTONE BLOCK", description = "POWERS DUST AND SWITCHES", color = 8 },
}
E.order = { "I", "G", "O", "Q", "D", "V", "Z", "C", "R", "B" }
local function index(x, y, g)
  return (y - 1) * (g and g.width or E.WIDTH) + x
end
function E.inside(x, y, g)
  return type(x) == "number"
    and type(y) == "number"
    and x >= 1
    and x <= (g and g.width or E.WIDTH)
    and y >= 1
    and y <= (g and g.height or E.HEIGHT)
    and x % 1 == 0
    and y % 1 == 0
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
  return E.inside(x, y, g) and g.map[index(x, y, g)] or nil
end
local function add(g, value, fixed)
  assert(E.inside(value.x, value.y, g), "Invalid level coordinates")
  local id = index(value.x, value.y, g)
  assert(not g.map[id], "Overlapping level part at " .. id)
  local t = {
    id = id,
    x = value.x,
    y = value.y,
    kind = value.kind,
    r = value.r or 0,
    fixed = not not fixed,
    speed = value.speed,
    sign = value.sign,
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
    number = number,
    width = data.width or E.WIDTH,
    height = data.height or E.HEIGHT,
    name = data.name,
    tip = data.tip,
    tiles = {},
    map = {},
    stock = copy(data.stock),
    remaining = copy(data.stock),
    moves = 0,
    fullNetwork = false,
    sandbox = false,
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
  for _, wire in ipairs(data.redstone or {}) do
    add(g, wire, false)
  end
  if solved then
    for _, v in ipairs(data.build) do
      assert(g.remaining[v.kind] > 0, "Invalid reference inventory")
      g.remaining[v.kind] = g.remaining[v.kind] - 1
      add(g, v, false)
    end
    for _, v in ipairs(data.removeRedstone or {}) do
      assert(E.remove(g, v[1], v[2]), "Invalid reference redstone removal")
    end
  end
  return g
end
function E.sandbox(width, height)
  width = width or E.MAX_SIZE
  height = height or width
  assert(width >= 5 and width <= E.MAX_SIZE and height >= 5 and height <= E.MAX_SIZE, "Invalid sandbox size")
  local g = {
    number = 0,
    width = width,
    height = height,
    name = "FREE WORKSHOP",
    tip = "EXPERIMENT WITH ALL PARTS. NO GOALS OR LIMITS.",
    tiles = {},
    map = {},
    stock = {},
    remaining = {},
    moves = 0,
    fullNetwork = false,
    sandbox = true,
  }
  for _, kind in ipairs(E.order) do
    g.remaining[kind] = math.huge
  end
  add(g, { kind = "S", x = 1, y = 3, r = 1 }, true)
  return g
end
-- Editor games use the same simulation as campaign play, but permit placing
-- fixed sources, goals and obstacles. All authored geometry is serialized
-- as data and validated before being loaded in playable packs.
function E.editor(width, height)
  local g = E.sandbox(width or 7, height or width or 7)
  g.editor = true
  g.name = "UNNAMED WORKSHOP"
  add(g, { kind = "M", x = g.width, y = 3, r = 3, speed = 1, sign = 1 }, true)
  return g
end
function E.fromDefinition(data, solved)
  local g = {
    number = 0,
    width = data.width,
    height = data.height,
    name = data.name,
    tip = data.tip,
    tiles = {},
    map = {},
    stock = copy(data.stock or {}),
    remaining = copy(data.stock or {}),
    moves = 0,
    sandbox = false,
    custom = true,
  }
  add(g, data.source, true)
  for _, goal in ipairs(data.goals or {}) do
    add(g, goal, true)
  end
  for _, fixture in ipairs(data.fixtures or {}) do
    add(g, fixture, true)
  end
  for _, v in ipairs(data.blocks or {}) do
    add(g, { kind = "X", x = v[1], y = v[2] }, true)
  end
  for _, wire in ipairs(data.redstone or {}) do
    add(g, wire, false)
  end
  if solved then
    for _, piece in ipairs(data.build or {}) do
      assert(g.remaining[piece.kind] and g.remaining[piece.kind] > 0, "Invalid custom inventory")
      g.remaining[piece.kind] = g.remaining[piece.kind] - 1
      add(g, piece, false)
    end
  end
  return g
end
function E.place(g, x, y, kind, rotation)
  if
    not E.inside(x, y, g)
    or not (E.parts[kind] or g.editor and (kind == "S" or kind == "M" or kind == "X"))
    or E.get(g, x, y)
  then
    return false
  end
  if not g.sandbox and (g.remaining[kind] or 0) < 1 then
    return false
  end
  if not g.sandbox then
    g.remaining[kind] = g.remaining[kind] - 1
  end
  if g.editor and kind == "S" then
    for _, tile in ipairs(g.tiles) do
      if tile.kind == "S" then
        E.remove(g, tile.x, tile.y)
        break
      end
    end
  end
  local special = g.editor and (kind == "S" or kind == "M" or kind == "X")
  add(g, {
    kind = kind,
    x = x,
    y = y,
    r = (rotation or 0) % 4,
    speed = kind == "M" and (g.goalRate or 1) or nil,
    sign = kind == "M" and (g.goalSign or 1) or nil,
  }, special)
  g.moves = g.moves + 1
  return true
end
function E.remove(g, x, y)
  local tile = E.get(g, x, y)
  if not tile or tile.fixed and not g.editor then
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
    g.remaining[tile.kind] = (g.remaining[tile.kind] or 0) + 1
  end
  g.moves = g.moves + 1
  return true
end
function E.rotate(g, x, y)
  local tile = E.get(g, x, y)
  if not tile or (tile.fixed and not g.editor) or tile.kind == "R" or tile.kind == "B" then
    return false
  end
  tile.r = (tile.r + 1) % 4
  g.moves = g.moves + 1
  return true
end
function E.move(g, x, y, tx, ty)
  local tile = E.get(g, x, y)
  if not tile or tile.fixed and not g.editor or not E.inside(tx, ty, g) or E.get(g, tx, ty) then
    return false
  end
  g.map[tile.id] = nil
  tile.id = index(tx, ty, g)
  tile.x, tile.y = tx, ty
  g.map[tile.id] = tile
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
-- Cog rims mesh side by side at any size, with a 2:1 ratio for mixed sizes.
-- Diagonal mixed-size meshing remains supported for existing puzzle layouts.
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
        if not E.inside(x, y, g) then
          break
        end
        local other = E.get(g, x, y)
        if other then
          if other.kind == "V" and matching(other) and distance >= 1 then
            links[#links + 1] = { tile = other, ratio = 1, sign = 1, belt = true }
          end
          -- An axial shaft may cross an existing belt run without severing it.
          if other.kind ~= "I" then
            break
          end
        end
      end
    end
    return links
  end
  local otherKind = tile.kind == "G" and "O" or "G"
  local perpendicular = horizontal and { { 0, -1 }, { 0, 1 } } or { { -1, 0 }, { 1, 0 } }
  for _, d in ipairs(perpendicular) do
    local other = E.get(g, tile.x + d[1], tile.y + d[2])
    if other and (other.kind == "G" or other.kind == "O") and matching(other) then
      -- In the flat workshop adjacent toothed rims mesh regardless of size.
      -- Different sizes keep their Create-inspired 2:1 speed relationship.
      local ratio = 1
      if other.kind ~= tile.kind then
        ratio = tile.kind == "O" and 2 or 0.5
      end
      links[#links + 1] = { tile = other, ratio = ratio, sign = -1 }
    end
  end
  for _, dx in ipairs({ -1, 1 }) do
    for _, dy in ipairs({ -1, 1 }) do
      local other = E.get(g, tile.x + dx, tile.y + dy)
      if other and other.kind == otherKind then
        links[#links + 1] = { tile = other, ratio = tile.kind == "O" and 2 or 0.5, sign = -1 }
      end
    end
  end
  return links
end
-- Centered dust connects orthogonally, including to redstone-powered devices.
function E.wireConnections(g, tile)
  local connected = {}
  for dir, vector in ipairs(vectors) do
    local other = E.get(g, tile.x + vector[1], tile.y + vector[2])
    connected[dir] = other and (other.kind == "R" or other.kind == "B" or other.kind == "C" or other.kind == "Z")
      or false
  end
  return connected
end
function E.redstone(g)
  local powered, queue, first = {}, {}, 1
  for _, tile in ipairs(g.tiles) do
    if tile.kind == "B" then
      powered[tile.id] = true
      queue[#queue + 1] = tile
    end
  end
  while first <= #queue do
    local tile = queue[first]
    first = first + 1
    for _, delta in ipairs(vectors) do
      local other = E.get(g, tile.x + delta[1], tile.y + delta[2])
      if other and other.kind == "R" and not powered[other.id] then
        powered[other.id] = true
        queue[#queue + 1] = other
      end
    end
  end
  local switches = {}
  for _, tile in ipairs(g.tiles) do
    if tile.kind == "C" or tile.kind == "Z" then
      for _, delta in ipairs(vectors) do
        local other = E.get(g, tile.x + delta[1], tile.y + delta[2])
        if other and powered[other.id] then
          switches[tile.id] = true
          break
        end
      end
    end
  end
  return powered, switches
end
function E.snapshot(g)
  local list = {}
  for _, tile in ipairs(g.tiles) do
    if not tile.fixed or tile.kind == "C" or tile.kind == "Z" then
      list[#list + 1] = {
        x = tile.x,
        y = tile.y,
        kind = tile.kind,
        r = tile.r,
        engaged = tile.engaged,
        fixed = tile.fixed or nil,
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
  if type(list) ~= "table" or #list > g.width * g.height then
    return false
  end
  local trial = g.sandbox and E.sandbox(g.width, g.height) or E.new(g.number)
  -- Nonfixed level-start redstone (e.g. the clutch lesson's powered block)
  -- is part of the save snapshot. Clear it before restoring the snapshot,
  -- or the snapshot would conflict with that starting fixture.
  for i = #trial.tiles, 1, -1 do
    local tile = trial.tiles[i]
    if not tile.fixed then
      E.remove(trial, tile.x, tile.y)
    end
  end
  for _, v in ipairs(list) do
    if
      type(v) ~= "table"
      or not E.inside(v.x, v.y, g)
      or type(v.r) ~= "number"
      or v.r % 1 ~= 0
      or v.r < 0
      or v.r > 3
      or (v.engaged ~= nil and type(v.engaged) ~= "boolean")
    then
      return false
    end
    local tile
    if v.fixed == true then
      tile = E.get(trial, v.x, v.y)
      if
        not tile
        or not tile.fixed
        or tile.kind ~= v.kind
        or tile.r ~= v.r
        or (tile.kind ~= "C" and tile.kind ~= "Z")
        or type(v.engaged) ~= "boolean"
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
  local redstone, switches = E.redstone(g)
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
    if (tile.kind ~= "C" or not switches[tile.id]) and not event.internal then
      for dir = 0, 3 do
        if dir ~= port and E.hasPort(tile, dir) then
          local sign = info.sign
          if tile.kind == "Q" or (tile.kind == "Z" and switches[tile.id]) then
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
      powered = sample ~= nil,
      rate = sample and sample.rate or 0,
      sign = sample and sample.sign or 0,
      ports = slots,
      redstone = redstone[tile.id] or switches[tile.id] or false,
    }
    if sample then
      powered = powered + 1
    elseif E.parts[tile.kind] and tile.kind ~= "R" and tile.kind ~= "B" then
      unpowered = unpowered + 1
    end
    if tile.kind ~= "X" and tile.kind ~= "R" and tile.kind ~= "B" then
      for dir = 0, 3 do
        if E.hasPort(tile, dir) and not E.connection(g, tile, dir) then
          openPorts = openPorts + 1
        end
      end
    end
    if tile.kind == "M" then
      goals = goals + 1
      local actual = slots[tile.r]
      light.correct = not not (actual and actual.sign == tile.sign and math.abs(actual.rate - tile.speed) < 0.001)
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
    lights = lights,
    redstone = redstone,
    switches = switches,
    powered = powered,
    goals = goals,
    correct = correct,
    jam = jam,
    openPorts = openPorts,
    unpowered = unpowered,
    remaining = remaining,
    complete = not jam and goals == correct,
    win = (not g.sandbox or g.editor) and not jam and goals > 0 and goals == correct,
  }
end
-- Authored two-slot bonus predicates; each predicate is evaluated against the
-- *actual* powered graph, not the author's saved reference.
function E.challenges(g, result)
  if g.sandbox or g.custom or g.editor then
    return {}
  end
  local stage = levels[g.number]
  local bonuses = stage.bonuses or {}
  local placed, gears, gearboxes, dust, blocks = 0, 0, 0, 0, 0
  local cw, ccw, energizedFixed = false, false, 0
  for _, tile in ipairs(g.tiles) do
    if not tile.fixed and tile.kind ~= "R" and tile.kind ~= "B" then
      placed = placed + 1
    end
    if not tile.fixed and (tile.kind == "G" or tile.kind == "O") then
      gears = gears + 1
    end
    if not tile.fixed and tile.kind == "Q" then
      gearboxes = gearboxes + 1
    end
    if not tile.fixed and tile.kind == "R" then
      dust = dust + 1
    end
    if not tile.fixed and tile.kind == "B" then
      blocks = blocks + 1
    end
    local light = result.lights[tile.id]
    if light and light.powered then
      cw = cw or light.sign == 1
      ccw = ccw or light.sign == -1
      if tile.fixed and E.parts[tile.kind] then
        energizedFixed = energizedFixed + 1
      end
    end
  end
  local function poweredLink(typeName, minimum)
    for _, tile in ipairs(g.tiles) do
      local light = result.lights[tile.id]
      if light and light.powered then
        for _, link in ipairs(E.meshes(g, tile)) do
          local other = result.lights[link.tile.id]
          if link[typeName] and other and other.powered then
            local span = math.abs(tile.x - link.tile.x) + math.abs(tile.y - link.tile.y)
            if span >= (minimum or 1) then
              return true
            end
          end
        end
      end
    end
    return false
  end
  local function diagonal()
    for _, tile in ipairs(g.tiles) do
      if (tile.kind == "G" or tile.kind == "O") and result.lights[tile.id].powered then
        for _, link in ipairs(E.meshes(g, tile)) do
          if
            link.tile.kind ~= tile.kind
            and math.abs(tile.x - link.tile.x) == 1
            and math.abs(tile.y - link.tile.y) == 1
            and result.lights[link.tile.id].powered
          then
            return true
          end
        end
      end
    end
    return false
  end
  local function occupiesZone(predicate)
    for _, tile in ipairs(g.tiles) do
      if not tile.fixed and predicate(tile) then
        return true
      end
    end
    return false
  end
  local list = {}
  for _, spec in ipairs(bonuses) do
    local goal = spec.value or 0
    local typeName = spec.type
    local achieved = false
    local progress = nil
    if typeName == "budget" then
      achieved, progress = placed <= goal, tostring(placed) .. "/" .. goal
    elseif typeName == "moves" then
      achieved, progress = g.moves <= goal, tostring(g.moves) .. "/" .. goal
    elseif typeName == "exact_parts" then
      achieved, progress = placed == goal, tostring(placed) .. "/" .. goal
    elseif typeName == "clean" then
      achieved = result.unpowered == 0
    elseif typeName == "full_stock" then
      achieved = result.remaining == 0 and result.unpowered == 0
    elseif typeName == "no_gearbox" then
      achieved = gearboxes == 0
    elseif typeName == "gear_limit" then
      achieved, progress = gears <= goal, tostring(gears) .. "/" .. goal
    elseif typeName == "belt_span" then
      achieved = poweredLink("belt", goal)
    elseif typeName == "chain_link" then
      achieved = poweredLink("chain", 1)
    elseif typeName == "diagonal" then
      achieved = diagonal()
    elseif typeName == "dual_rotation" then
      achieved = cw and ccw
    elseif typeName == "redstone_limit" then
      achieved, progress = dust <= goal, tostring(dust) .. "/" .. goal
    elseif typeName == "single_block" then
      achieved, progress = blocks <= 1, tostring(blocks) .. "/1"
    elseif typeName == "fixed_power" then
      achieved = energizedFixed >= goal
    elseif typeName == "no_belt" then
      achieved = not occupiesZone(function(tile)
        return tile.kind == "V"
      end)
    elseif typeName == "no_chain" then
      achieved = not occupiesZone(function(tile)
        return tile.kind == "D"
      end)
    elseif typeName == "clear_zone" then
      achieved = not occupiesZone(function(tile)
        return tile.x >= spec.x1 and tile.x <= spec.x2 and tile.y >= spec.y1 and tile.y <= spec.y2
      end)
    elseif typeName == "use_cell" then
      local tile = E.get(g, spec.x, spec.y)
      achieved = tile ~= nil and not tile.fixed and result.lights[tile.id].powered
    elseif typeName == "no_kind" then
      achieved = not occupiesZone(function(tile)
        return tile.kind == spec.kind
      end)
    elseif typeName == "mechanical_override" then
      local tile = E.get(g, spec.x, spec.y)
      achieved = tile and (tile.kind == "Z" or tile.kind == "C") and not result.switches[tile.id] or false
    elseif typeName == "signal_sharing" then
      local count = 0
      for _, tile in ipairs(g.tiles) do
        if (tile.kind == "Z" or tile.kind == "C") and result.switches[tile.id] then
          count = count + 1
        end
      end
      achieved = count >= 2
    end
    list[#list + 1] = {
      id = spec.id,
      name = spec.name,
      description = spec.description or spec.name,
      earned = result.win and not not achieved,
      progress = progress,
    }
  end
  return list
end
return E
