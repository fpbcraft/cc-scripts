-- Persistent natural landmarks and world-unique constructed wonders.
local Content = dofile("/games/civcraft/content.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local Random = dofile("/games/civcraft/world_random.lua")
local L = {}
local function key(x, y)
  return x .. ":" .. y
end
function L.habitat(tile, id)
  if tile.biome == "ocean" or tile.biome == "coast" then
    return false
  end
  if id == "ice_spikes" then
    return tile.biome == "snowy_plains" or tile.biome == "taiga"
  end
  if id == "mushroom" then
    return tile.elevation ~= "mountain"
      and (tile.biome == "swamp" or tile.biome == "jungle" or tile.biome == "forest" or tile.biome == "mushroom")
  end
  if id == "lushcavern" then
    return tile.elevation ~= "mountain"
      and (tile.biome == "forest" or tile.biome == "jungle" or tile.biome == "swamp" or tile.biome == "taiga")
  end
  return tile.elevation == "hill" or tile.elevation == "mountain" or tile.biome == "badlands"
end
function L.generate(world, checkpoint)
  world.landmarks = {}
  world.rails = {}
  local rng = Random.new(world.seed, 83)
  local kinds = { "ice_spikes", "mushroom", "lushcavern", "amethyst", "dripstone", "ancientcity" }
  local short = math.min(world.width, world.height)
  world.wonderSpawnBuffer = short <= 12 and 5 or short >= 26 and 8 or 6
  world.wonderSeparation = math.min(world.width, world.height) >= 26 and 4 or 3
  local candidates = {}
  for y = 2, world.height - 1 do
    if checkpoint then
      checkpoint()
    end
    for x = 2, world.width - 1 do
      local safe = true
      for _, p in ipairs(world.starts) do
        if Hex.distance(x, y, p.x, p.y) < world.wonderSpawnBuffer then
          safe = false
          break
        end
      end
      if safe then
        candidates[#candidates + 1] = { x = x, y = y, tile = Biomes.tile(world, x, y) }
      end
    end
  end
  rng:shuffle(candidates)
  local placed = {}
  for _, id in ipairs(kinds) do
    local best, bestScore
    for rank, c in ipairs(candidates) do
      if checkpoint and rank % 128 == 0 then
        checkpoint()
      end
      if L.habitat(c.tile, id) then
        local separation = math.huge
        for _, p in ipairs(placed) do
          separation = math.min(separation, Hex.distance(c.x, c.y, p.x, p.y))
        end
        if separation >= world.wonderSeparation then
          -- Prefer dispersed regions; the shuffled tie break avoids common scanline rows.
          local score = (#placed == 0 and 0 or math.min(12, separation)) + #candidates / (rank + #candidates)
          if not bestScore or score > bestScore then
            best, bestScore = c, score
          end
        end
      end
    end
    if best then
      local k = key(best.x, best.y)
      world.landmarks[k] = { kind = id, natural = true }
      placed[#placed + 1] = best
      if world.geography and id == "mushroom" then
        best.tile.biome = "mushroom"
        best.tile.feature = "none"
        world.tiles[k] = Biomes.terrain(best.tile)
      end
    end
  end
end
function L.available(state, id)
  for _, landmark in pairs(state.world and state.world.landmarks or {}) do
    if not landmark.natural and landmark.kind == id then
      return false
    end
  end
  return true
end
function L.canPlace(state, city, id, x, y, systems)
  local record = Content.wonders[id]
  if not record or not state.world or not Hex.inBounds(x, y, state) then
    return false
  end
  local player
  for _, p in ipairs(state.players) do
    if p.id == city.owner then
      player = p
    end
  end
  if not player or not player.techs[record.tech] or not L.available(state, id) then
    return false
  end
  if record.coastal and not systems.coastal(state, city) then
    return false
  end
  local terrain = Hex.terrain(x, y, state)
  local k = key(x, y)
  if
    terrain == "water"
    or terrain == "mountain"
    or (state.world.landmarks or {})[k]
    or (state.world.rails or {})[k]
  then
    return false
  end
  for _, c in ipairs(state.cities) do
    if c.x == x and c.y == y then
      return false
    end
  end
  return city.claimed and city.claimed[k] == true and systems.territoryCity(state, x, y) == city
end
function L.complete(state, city, project, systems)
  if not L.canPlace(state, city, project.id, project.x, project.y, systems) then
    return false
  end
  state.world.landmarks = state.world.landmarks or {}
  state.world.landmarks[key(project.x, project.y)] = { kind = project.id, cityId = city.id, natural = false }
  -- A competing city's reservation is released; its invested industry is retained.
  for _, other in ipairs(state.cities) do
    if other ~= city and other.project and other.project.kind == "wonder" and other.project.id == project.id then
      other.projectProgress["wonder:" .. project.id] = other.project.progress
      other.project = nil
    end
  end
  return true
end
function L.effects(state, city, systems)
  local effects = { food = 0, industry = 0, science = 0, gold = 0 }
  for k, v in pairs(state.world and state.world.landmarks or {}) do
    if not v.natural then
      local x, y = k:match("^(%d+):(%d+)$")
      if systems.territoryCity(state, tonumber(x), tonumber(y)) == city then
        for name, value in pairs((Content.wonders[v.kind] or {}).effects or {}) do
          effects[name] = effects[name] + value
        end
      end
    end
  end
  return effects
end
return L
