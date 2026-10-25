-- Seeded hex geography, strategic deposits, private discovery and territory.
-- World state is authoritative and saved; map presets never reroll on reload.
local Content = dofile("/games/civcraft/content.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local W = {}
W.sizes = { compact = { 18, 12 }, standard = { 28, 18 }, large = { 40, 26 } }
W.types = { "continents", "archipelago", "pangaea", "highlands" }
local function key(x, y)
  return x .. ":" .. y
end
W.key = key
local function noise(seed, x, y, salt)
  local n = (seed * 1103515245 + x * 110351 + y * 143417 + salt * 7193) % 2147483647
  return ((n * 48271 + 17) % 2147483647) / 2147483647
end
local function clamp(v, a, b)
  return math.max(a, math.min(b, v))
end
local function deposit(seed, x, y, t)
  local v = noise(seed, x, y, 19)
  if t == "water" then
    return v > 0.88 and "fish" or nil
  end
  if t == "forest" and v > 0.54 then
    return "timber"
  end
  if t == "hills" or t == "mountain" then
    if v > 0.78 then
      return "iron"
    end
    if v > 0.40 then
      return "stone"
    end
  end
  if t == "plains" then
    if v > 0.91 then
      return "saltpeter"
    end
    if v > 0.85 then
      return "horses"
    end
    if v > 0.57 then
      return "grain"
    end
  end
end
function W.generate(seed, size, count, mapType)
  size = W.sizes[size] and size or "standard"
  local dims = W.sizes[size]
  seed = math.floor(tonumber(seed) or 12345) % 1000000
  mapType = mapType or "continents"
  if not ({ continents = true, archipelago = true, pangaea = true, highlands = true })[mapType] then
    mapType = "continents"
  end
  local world = {
    width = dims[1],
    height = dims[2],
    seed = seed,
    size = size,
    mapType = mapType,
    tiles = {},
    resources = {},
    starts = {},
  }
  local w, h = world.width, world.height
  for y = 1, h do
    for x = 1, w do
      local nx = (x - (w + 1) / 2) / (w / 2)
      local ny = (y - (h + 1) / 2) / (h / 2)
      local d = math.sqrt(nx * nx + ny * ny)
      local macro = noise(seed, math.floor(x / 5), math.floor(y / 5), 7)
      local detail = noise(seed, x, y, 1)
      local v = 0.58 * macro + 0.42 * detail
      local waterLimit
      if mapType == "pangaea" then
        waterLimit = 0.11 + d * 0.40
      elseif mapType == "archipelago" then
        waterLimit = 0.43 + d * 0.11
      elseif mapType == "highlands" then
        waterLimit = 0.09 + d * 0.12
      else
        waterLimit = 0.22 + d * 0.17
      end
      local t
      if v < waterLimit then
        t = "water"
      elseif (mapType == "highlands" and v > 0.68) or v > 0.84 then
        t = "mountain"
      elseif v > 0.57 then
        t = "forest"
      elseif v > 0.40 then
        t = "hills"
      else
        t = "plains"
      end
      world.tiles[key(x, y)] = t
      world.resources[key(x, y)] = deposit(seed, x, y, t)
    end
  end
  local starts = { { 3, 3 }, { w - 2, h - 2 }, { w - 2, 3 }, { 3, h - 2 } }
  for i = 1, math.min(4, count or 4) do
    local x, y = starts[i][1], starts[i][2]
    world.starts[i] = { x = x, y = y }
    for yy = y - 1, y + 1 do
      for xx = x - 1, x + 1 do
        if xx >= 1 and xx <= w and yy >= 1 and yy <= h then
          world.tiles[key(xx, yy)] = "plains"
          world.resources[key(xx, yy)] = deposit(seed, xx, yy, "plains")
        end
      end
    end
  end
  for _, pos in ipairs(world.starts) do
    local nx = pos.x + (pos.x < world.width / 2 and 1 or -1)
    world.resources[key(nx, pos.y)] = "grain"
  end
  -- New-world deposits, deterministic and independent of discovery.
  for y = 1, h do
    for x = 1, w do
      local k = key(x, y)
      local t = world.tiles[k]
      local value = noise(seed, x, y, 37)
      if t ~= "water" and t ~= "mountain" then
        if value > 0.96 then
          world.resources[k] = "diamond"
        elseif value > 0.91 then
          world.resources[k] = "redstone"
        elseif value > 0.85 then
          world.resources[k] = "copper"
        elseif value > 0.80 then
          world.resources[k] = "zinc"
        end
        if world.resources[k] == "saltpeter" then
          world.resources[k] = "redstone"
        end
      end
    end
  end
  -- Every start has accessible iron; trading handles rarer material shortages.
  for _, pos in ipairs(world.starts) do
    local nx = pos.x + (pos.x < w / 2 and 1 or -1)
    world.resources[key(nx, pos.y + 1)] = "iron"
    world.resources[key(nx, pos.y)] = "grain"
  end
  world.contentVersion = 1
  Landmarks.generate(world)
  return world
end
function W.terrain(world, x, y)
  if not world or x < 1 or y < 1 or x > world.width or y > world.height then
    return nil
  end
  return world.tiles[key(x, y)] or "plains"
end
function W.deposit(world, x, y)
  if not world or not world.resources then
    return nil
  end
  return world.resources[key(x, y)]
end
-- Migrate pre-v0.5 legacy maps without changing existing city terrain.
function W.migrate(state)
  if not state.world and state.phase == "game" then
    local world =
      { width = 12, height = 8, seed = 0, size = "legacy", mapType = "legacy", tiles = {}, resources = {}, starts = {} }
    for y = 1, 8 do
      for x = 1, 12 do
        local v = (x * 37 + y * 61 + x * y * 13) % 19
        local t = v <= 1 and "water" or v <= 3 and "mountain" or v < 9 and "forest" or "plains"
        world.tiles[key(x, y)] = t
      end
    end
    state.world = world
    state.mapSize = "compact"
    state.mapSeed = 0
  end
  if state.world then
    local world = state.world
    world.mapType = world.mapType or "continents"
    world.resources = world.resources or {}
    for y = 1, world.height do
      for x = 1, world.width do
        local k = key(x, y)
        if not world.contentVersion and world.resources[k] == nil then
          world.resources[k] = deposit(world.seed or 0, x, y, world.tiles[k])
        end
      end
    end
  end
  state.mapType = state.mapType or state.world and state.world.mapType or "continents"
  return state
end
local function radius(city)
  return city.population and city.population >= 6 and 3 or city.population and city.population >= 4 and 2 or 1
end
function W.territoryCity(state, hex, x, y)
  local best, bestDist
  local tileKey = key(x, y)
  for _, city in ipairs(state.cities or {}) do
    local dist
    if city.claimed then
      if city.claimed[tileKey] then
        dist = hex.distance(x, y, city.x, city.y)
      end
    else
      local candidate = hex.distance(x, y, city.x, city.y)
      if candidate <= radius(city) then
        dist = candidate
      end
    end
    if dist and (not bestDist or dist < bestDist or (dist == bestDist and (city.id or 0) < (best.id or 0))) then
      best, bestDist = city, dist
    end
  end
  return best
end
function W.ensureTerritories(state, hex, legacy)
  if not state.world then
    return
  end
  for _, city in ipairs(state.cities or {}) do
    if not city.claimed then
      local range = legacy and radius(city) or 1
      city.claimed = {}
      city.borderProgress = city.borderProgress or 0
      for y = math.max(1, city.y - range), math.min(state.world.height, city.y + range) do
        for x = math.max(1, city.x - range), math.min(state.world.width, city.x + range) do
          if hex.distance(city.x, city.y, x, y) <= range then
            city.claimed[key(x, y)] = true
          end
        end
      end
    end
  end
end
function W.expandCity(state, hex, city)
  W.ensureTerritories(state, hex, false)
  city.borderProgress = (city.borderProgress or 0) + 1
  local count = 0
  for _ in pairs(city.claimed or {}) do
    count = count + 1
  end
  local delay = 6 + math.floor(count / 4)
  if city.borderProgress < delay then
    return false
  end
  local candidates = {}
  for y = math.max(1, city.y - 3), math.min(state.world.height, city.y + 3) do
    for x = math.max(1, city.x - 3), math.min(state.world.width, city.x + 3) do
      if hex.distance(city.x, city.y, x, y) <= 3 and not W.territoryCity(state, hex, x, y) then
        local adjacent = false
        for _, n in ipairs(hex.neighbours(x, y, state)) do
          if city.claimed[key(n.x, n.y)] then
            adjacent = true
            break
          end
        end
        if adjacent then
          local yield = W.yields(state.world, x, y)
          candidates[#candidates + 1] = {
            x = x,
            y = y,
            distance = hex.distance(city.x, city.y, x, y),
            score = yield.food + yield.industry + yield.science,
          }
        end
      end
    end
  end
  table.sort(candidates, function(a, b)
    if a.distance ~= b.distance then
      return a.distance < b.distance
    end
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.y == b.y and a.x < b.x or a.y < b.y
  end)
  local tile = candidates[1]
  if not tile then
    city.borderProgress = math.min(city.borderProgress, delay)
    return false
  end
  city.claimed[key(tile.x, tile.y)] = true
  city.borderProgress = 0
  state.territoryRevision = (state.territoryRevision or 0) + 1
  return true, tile
end
function W.yields(world, x, y)
  local t = W.terrain(world, x, y)
  local food, industry, science = 0, 0, 0
  if t == "plains" then
    food, industry = 2, 1
  elseif t == "hills" then
    food, industry = 1, 2
  elseif t == "forest" then
    food, industry = 1, 2
  elseif t == "mountain" then
    industry = 2
  elseif t == "water" then
    food = 2
  end
  local deposit = W.deposit(world, x, y)
  if deposit == "grain" or deposit == "fish" then
    food = food + 2
  elseif deposit == "stone" or deposit == "timber" then
    industry = industry + 2
  elseif deposit == "iron" then
    industry = industry + 1
  elseif deposit == "saltpeter" then
    science = science + 2
  elseif deposit == "horses" then
    food = food + 1
  end
  local landmark = world and (world.landmarks or {})[key(x, y)]
  local extra = landmark and landmark.natural and Content.naturalWonders[landmark.kind] or {}
  food = food + (extra.food or 0)
  industry = industry + (extra.industry or 0)
  science = science + (extra.science or 0)
  if deposit == "copper" or deposit == "zinc" then
    industry = industry + 1
  end
  if deposit == "redstone" or deposit == "diamond" then
    science = science + 1
  end
  return { food = food, industry = industry, science = science }
end
-- Hex territory nearest owner; deterministic tie break by city ID.
function W.territory(state, hex)
  local w = state.world
  local result = {}
  if not w then
    return result
  end
  for y = 1, w.height do
    for x = 1, w.width do
      local city = W.territoryCity(state, hex, x, y)
      if city then
        result[key(x, y)] = city.owner
      end
    end
  end
  return result
end
function W.strategic(state, player, hex, res)
  local owned = W.territory(state, hex)
  for k, id in pairs(owned) do
    if id == player.id and state.world.resources and state.world.resources[k] == res then
      return true
    end
  end
  return false
end
function W.reveal(state, hex, systems)
  local world = state.world
  if not world then
    return
  end
  for _, p in ipairs(state.players or {}) do
    p.explored = p.explored or {}
    local visible = {}
    local function reveal(x, y, r)
      for yy = math.max(1, y - r), math.min(world.height, y + r) do
        for xx = math.max(1, x - r), math.min(world.width, x + r) do
          if hex.distance(x, y, xx, yy) <= r then
            local k = key(xx, yy)
            visible[k] = true
            p.explored[k] = true
          end
        end
      end
    end
    for _, c in ipairs(state.cities or {}) do
      if c.owner == p.id then
        reveal(c.x, c.y, 2)
      end
    end
    for _, unit in ipairs(state.units or {}) do
      if unit.owner == p.id then
        local stat = systems.units[unit.kind] or systems.units.warrior
        reveal(unit.x, unit.y, stat.vision or 2)
      end
    end
    p.visible = visible
  end
end
-- Build an observer-safe network snapshot. Local saves keep the authoritative state.
function W.forPlayer(state, id)
  local observer
  for _, p in ipairs(state.players or {}) do
    if p.id == id then
      observer = p
      break
    end
  end
  if not observer then
    return nil
  end
  if state.phase ~= "game" and state.phase ~= "over" then
    return state
  end
  local view = {
    version = state.version,
    phase = state.phase,
    round = state.round,
    turn = state.turn,
    name = state.name,
    winner = state.winner,
    ruleset = state.ruleset,
    roundLimit = state.roundLimit,
    hostileMode = state.hostileMode,
    victoryReason = state.victoryReason,
    spawners = {},
    players = {},
    cities = {},
    units = {},
    logs = {},
  }
  local world = state.world
  if world then
    view.world = {
      width = world.width,
      height = world.height,
      size = world.size,
      mapType = world.mapType,
      tiles = {},
      resources = {},
      landmarks = {},
      rails = {},
      contentVersion = world.contentVersion,
    }
    for y = 1, world.height do
      for x = 1, world.width do
        local k = key(x, y)
        if (observer.explored or {})[k] or (observer.visible or {})[k] then
          view.world.tiles[k] = world.tiles[k]
          view.world.resources[k] = (world.resources or {})[k]
          view.world.landmarks[k] = (world.landmarks or {})[k]
          view.world.rails[k] = (world.rails or {})[k]
        end
      end
    end
  end
  for _, p in ipairs(state.players or {}) do
    if p.id == id then
      view.players[#view.players + 1] = p
    else
      view.players[#view.players + 1] = {
        id = p.id,
        name = p.name,
        civ = p.civ,
        ai = p.ai,
        ready = p.ready,
        age = p.age,
        industryTurns = p.industryTurns,
        endStage = p.endStage,
      }
    end
  end
  for _, c in ipairs(state.cities or {}) do
    if
      c.owner == id
      or (observer.visible or {})[key(c.x, c.y)]
      or c.village and (observer.explored or {})[key(c.x, c.y)]
    then
      local copy = {}
      for field, value in pairs(c) do
        copy[field] = value
      end
      if c.village then
        if not (observer.visible or {})[key(c.x, c.y)] then
          copy = {
            id = c.id,
            name = c.name,
            owner = c.owner,
            x = c.x,
            y = c.y,
            village = true,
            villageOwner = c.villageOwner,
            villageKind = c.villageKind,
            remoteVillage = true,
          }
        end
        copy.influence = { [id] = (c.influence or {})[id] }
        copy.envoyRounds = { [id] = (c.envoyRounds or {})[id] }
        copy.publicAlly = Villages.ally(c) or false
      end
      view.cities[#view.cities + 1] = copy
    end
  end
  for _, u in ipairs(state.units or {}) do
    if u.owner == id or (observer.visible or {})[key(u.x, u.y)] then
      view.units[#view.units + 1] = u
    end
  end
  for _, spawner in ipairs(state.spawners or {}) do
    if (observer.explored or {})[key(spawner.x, spawner.y)] or (observer.visible or {})[key(spawner.x, spawner.y)] then
      view.spawners[#view.spawners + 1] = spawner
    end
  end
  return view
end
function W.known(player, x, y)
  if not player then
    return "hidden"
  end
  local k = key(x, y)
  if player.visible and player.visible[k] then
    return "visible"
  end
  if player.explored and player.explored[k] then
    return "explored"
  end
  return "hidden"
end
return W
