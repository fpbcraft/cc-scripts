-- Content-aware priorities, shared with the same queues and material rules as humans.
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Rails = dofile("/games/civcraft/railways.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local A = {}
local function queue(state, p, city, kind, id, systems, x, y)
  return Actions.apply(state, p.id, {
    action = "queue",
    cityX = city.x,
    cityY = city.y,
    kind = kind,
    id = id,
    tileX = x,
    tileY = y,
  }, systems)
end
function A.research(p, systems)
  local goals = {
    "agriculture",
    "mining",
    "writing",
    "crafting",
    "husbandry",
    "bronze",
    "currency",
    "masonry",
    "deepmining",
    "diamondworking",
    "philosophy",
    "engineering",
    "waterpower",
    "pressing",
    "belts",
    "nether",
    "heatedmixing",
    "brassworking",
    "deployers",
    "precision",
    "education",
    "steampower",
  }
  local finish = p.id % 2 == 0 and { "brewing", "netherite", "astronomy", "enlightenment" }
    or { "mechanicalcrafting", "commerce", "railways", "logistics", "economics" }
  for _, id in ipairs(finish) do
    goals[#goals + 1] = id
  end
  local function nextTech(id)
    if p.techs[id] then
      return nil
    end
    for _, need in ipairs(systems.techs[id].requires) do
      if not p.techs[need] then
        return nextTech(need)
      end
    end
    return id
  end
  for _, id in ipairs(goals) do
    local nextId = nextTech(id)
    if nextId then
      return nextId
    end
  end
  for _, id in ipairs(systems.techOrder) do
    if systems.canResearch(p, id) then
      return id
    end
  end
end
function A.choose(state, p, city, systems)
  local cities, settlers, soldiers, engineers = 0, 0, 0, 0
  for _, c in ipairs(state.cities) do
    if c.owner == p.id then
      cities = cities + 1
    end
  end
  for _, u in ipairs(state.units) do
    if u.owner == p.id then
      local stats = systems.units[u.kind]
      if u.kind == "settler" then
        settlers = settlers + 1
      elseif stats.engineer then
        engineers = engineers + 1
      else
        soldiers = soldiers + 1
      end
    end
  end
  if cities + settlers < 3 and systems.canRecruit(p, "settler", state, Hex, city) then
    return queue(state, p, city, "unit", "settler", systems)
  end
  if p.techs.railways and engineers == 0 then
    return queue(state, p, city, "unit", "engineer", systems)
  end
  if soldiers < math.min(4, cities + 1) then
    for _, id in ipairs({ "diamondguard", "swordsman", "spearman", "archer", "warrior" }) do
      if
        systems.canRecruit(p, id, state, Hex, city)
        and (not systems.units[id].resource or (p.stockpile[systems.units[id].resource] or 0) >= 2)
      then
        return queue(state, p, city, "unit", id, systems)
      end
    end
  end
  local order = {
    "farm",
    "mine",
    "library",
    "pens",
    "craftinghall",
    "market",
    "furnace",
    "walls",
    "academy",
    "deepmine",
    "redstoneworkshop",
    "workshop",
    "waterwheel",
    "press",
    "beltlogistics",
    "portal",
    "burner",
    "mixer",
    "deployer",
    "assembly",
    "university",
    "brewery",
    "station",
    "steamplant",
    "crafter",
    "bazaar",
    "freight",
    "bank",
    "observatory",
    "eyes",
    "equipment",
    "dragon",
    "windmill",
    "crusher",
    "fortress",
    "grandacademy",
  }
  if p.id % 2 == 0 then
    -- Expedition empires prioritize their final projects once they unlock them.
    for _, id in ipairs({ "observatory", "eyes", "equipment", "dragon" }) do
      if systems.canBuild(p, city, id, state) then
        return queue(state, p, city, "building", id, systems)
      end
    end
  end
  for _, id in ipairs(order) do
    if systems.canBuild(p, city, id, state) then
      return queue(state, p, city, "building", id, systems)
    end
  end
  -- Optional wonders are worthwhile after the essential economy is developed.
  local ids = {}
  for id in pairs(systems.wonders) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    for _, tile in ipairs(systems.workable(state, city)) do
      if Landmarks.canPlace(state, city, id, tile.x, tile.y, systems) then
        return queue(state, p, city, "wonder", id, systems, tile.x, tile.y)
      end
    end
  end
end
function A.engineer(state, p, u, systems)
  if not p.techs.railways then
    u.standby = true
    return true
  end
  u.standby = false
  -- BFS between each pair of cities through owned land; no omniscient shortcuts.
  local cities = {}
  for _, c in ipairs(state.cities) do
    if c.owner == p.id then
      cities[#cities + 1] = c
    end
  end
  local owned = World.territory(state, Hex)
  local rails = state.world.rails or {}
  for i = 2, #cities do
    local first, last = cities[1], cities[i]
    local queue = { { x = first.x, y = first.y } }
    local index = 1
    local seen = { [World.key(first.x, first.y)] = true }
    local previous = {}
    local found
    while index <= #queue do
      local c = queue[index]
      index = index + 1
      if c.x == last.x and c.y == last.y then
        found = c
        break
      end
      for _, n in ipairs(Hex.neighbours(c.x, c.y, state)) do
        local k = World.key(n.x, n.y)
        if
          not seen[k]
          and owned[k] == p.id
          and not (state.world.landmarks or {})[k]
          and Hex.passable(n.x, n.y, state, u, systems)
        then
          seen[k] = true
          previous[k] = c
          queue[#queue + 1] = n
        end
      end
    end
    local path = {}
    while found do
      path[#path + 1] = found
      found = previous[World.key(found.x, found.y)]
    end
    local target
    for j = #path, 1, -1 do
      if not rails[World.key(path[j].x, path[j].y)] then
        target = path[j]
        break
      end
    end
    if target then
      if Rails.canBuild(state, p, u, target.x, target.y, systems) then
        Actions.apply(state, p.id, { action = "buildRail", sx = u.x, sy = u.y, x = target.x, y = target.y }, systems)
        return true
      end
      local choices = Hex.reachable(state, u, p.id, systems)
      local best, distance
      for _, c in ipairs(choices) do
        if not c.attack then
          local d = Hex.distance(c.x, c.y, target.x, target.y)
          if not distance or d < distance then
            best = c
            distance = d
          end
        end
      end
      if best then
        Actions.apply(state, p.id, { action = "move", sx = u.x, sy = u.y, x = best.x, y = best.y }, systems)
      end
      u.movesLeft = 0
      u.moved = true
      return true
    end
  end
  u.movesLeft = 0
  u.moved = true
  return true
end
function A.diplomacy(state, p, systems)
  if (p.gold or 0) > 100 then
    for _, city in ipairs(state.cities) do
      if Villages.independent(city) and Villages.discovered(p, city) then
        Actions.apply(state, p.id, { action = "envoy", x = city.x, y = city.y }, systems)
      end
    end
  end
  if p.techs.brassworking then
    for _, id in ipairs({ "copper", "zinc" }) do
      if (p.stockpile[id] or 0) < 2 and p.gold > 40 then
        Actions.apply(state, p.id, { action = "exchange", resource = id }, systems)
      end
    end
  end
end
return A
