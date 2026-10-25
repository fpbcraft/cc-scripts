-- CIVCRAFT 4X data & deterministic mechanics, no dependencies on UI/peripherals.
local M = {}
local Content = dofile("/games/civcraft/content.lua")
M.civs = Content.civs
M.techs = Content.techs
M.techOrder = Content.techOrder
M.units = Content.units
M.buildings = Content.buildings
M.ages = Content.ages
M.resources = Content.resources
M.resourceOrder = Content.resourceOrder
M.wonders = Content.wonders
M.naturalWonders = Content.naturalWonders
M.jobs = { "food", "wood", "science" }
local Hex = dofile("/games/civcraft/hex.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local World = dofile("/games/civcraft/world.lua")
local Economy = dofile("/games/civcraft/economy.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Rails = dofile("/games/civcraft/railways.lua")
local AI = dofile("/games/civcraft/ai.lua")
local Actions = dofile("/games/civcraft/actions.lua")
M.exchange = Economy.exchange
function M.territoryCity(state, x, y)
  return World.territoryCity(state, Hex, x, y)
end
function M.age(p)
  local age = 1
  for i, a in ipairs(Content.ages) do
    if (p.techs or {})[a.milestone] then
      age = math.max(age, i)
    end
  end
  return age
end
function M.label(kind, id)
  local source = kind == "unit" and M.units
    or kind == "wonder" and M.wonders
    or kind == "tech" and M.techs
    or M.buildings
  return (source[id] or {}).name or tostring(id):upper()
end
function M.workable(state, city)
  local tiles = {}
  if not state.world or not city then
    return tiles
  end
  for yy = math.max(1, city.y - 3), math.min(state.world.height, city.y + 3) do
    for xx = math.max(1, city.x - 3), math.min(state.world.width, city.x + 3) do
      if
        not (xx == city.x and yy == city.y)
        and Hex.distance(xx, yy, city.x, city.y) <= 3
        and World.territoryCity(state, Hex, xx, yy) == city
      then
        local yield = World.yields(state.world, xx, yy)
        tiles[#tiles + 1] = { x = xx, y = yy, key = World.key(xx, yy), yield = yield }
      end
    end
  end
  table.sort(tiles, function(a, b)
    local aa = a.yield.food + a.yield.industry + a.yield.science * 2
    local bb = b.yield.food + b.yield.industry + b.yield.science * 2
    if aa ~= bb then
      return aa > bb
    end
    return a.y == b.y and a.x < b.x or a.y < b.y
  end)
  return tiles
end
function M.tileJob(tile)
  local y = tile.yield
  if y.science > 0 and y.science >= y.food and y.science >= y.industry then
    return "science"
  end
  if y.industry > y.food then
    return "wood"
  end
  return "food"
end
function M.ensureWorkers(state, city)
  if not state.world or not city then
    return
  end
  local tiles = M.workable(state, city)
  local had = city.worked ~= nil
  city.worked = city.worked or {}
  local available = {}
  for _, t in ipairs(tiles) do
    available[t.key] = t
  end
  local keys = {}
  for k in pairs(city.worked) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  local count = 0
  for _, k in ipairs(keys) do
    if not available[k] or count >= (city.population or 2) then
      city.worked[k] = nil
    else
      count = count + 1
    end
  end
  if not had then
    for _, tile in ipairs(tiles) do
      if count >= (city.population or 2) then
        break
      end
      city.worked[tile.key] = true
      count = count + 1
    end
  end
  city.jobs = { food = 0, wood = 0, science = 0 }
  for _, tile in ipairs(tiles) do
    if city.worked[tile.key] then
      local job = M.tileJob(tile)
      city.jobs[job] = city.jobs[job] + 1
    end
  end
end
function M.workTile(state, city, x, y)
  if not city or not state.world or type(x) ~= "number" or type(y) ~= "number" then
    return false, "Invalid city or hex"
  end
  M.ensureWorkers(state, city)
  local k = World.key(x, y)
  local allowed = false
  for _, tile in ipairs(M.workable(state, city)) do
    if tile.key == k then
      allowed = true
      break
    end
  end
  if not allowed then
    return false, "Hex is outside this city's workable land"
  end
  if city.worked[k] then
    city.worked[k] = nil
  elseif M.idle(city) > 0 then
    city.worked[k] = true
  else
    return false, "No idle population; unwork a hex first"
  end
  M.ensureWorkers(state, city)
  return true
end
function M.civ(id)
  for _, v in ipairs(M.civs) do
    if v.id == id then
      return v
    end
  end
  return M.civs[1]
end
function M.nameCity(state, city)
  if city.name and city.name ~= "" then
    return city.name
  end
  local civ = "verdant"
  for _, p in ipairs(state.players or {}) do
    if p.id == city.owner then
      civ = p.civ or civ
      break
    end
  end
  local pool = Content.cityNames[civ] or Content.cityNames.verdant
  local used = {}
  for _, c in ipairs(state.cities or {}) do
    if c.name then
      used[c.name:upper()] = true
    end
  end
  -- Campaign-seeded randomness keeps host/client migrations reproducible.
  local seed = (state.world and state.world.seed or state.mapSeed or 1) % 2147483647
  seed = (seed * 48271 + (city.id or 0) * 997 + (city.x or 0) * 131 + (city.y or 0) * 71) % 2147483647
  local start = seed % #pool
  for i = 0, #pool - 1 do
    local name = pool[(start + i) % #pool + 1]
    if not used[name] then
      city.name = name
      return name
    end
  end
  local base = pool[start + 1]
  local suffix = 2
  while true do
    local tail = tostring(suffix)
    local name = base:sub(1, 8 - #tail) .. tail
    if not used[name] then
      city.name = name
      return name
    end
    suffix = suffix + 1
  end
end
function M.migrate(state)
  state.ruleset = state.ruleset or "legacy"
  state.roundLimit = state.roundLimit or (state.ruleset == "create" and 180 or 90)
  state.hostileMode = state.hostileMode or (state.ruleset == "create" and "standard" or "off")
  if state.world then
    state.world.landmarks = state.world.landmarks or {}
    state.world.rails = state.world.rails or {}
  end
  World.ensureTerritories(state, Hex, (state.version or 0) < 5)
  for i, p in ipairs(state.players or {}) do
    p.civ = p.civ or M.civs[(i - 1) % #M.civs + 1].id
    p.techs = p.techs or {}
    if p.settlersTrained == nil then
      local cities, settlers = 0, 0
      for _, c in ipairs(state.cities or {}) do
        if c.owner == p.id then
          cities = cities + 1
        end
      end
      for _, u in ipairs(state.units or {}) do
        if u.owner == p.id and u.kind == "settler" then
          settlers = settlers + 1
        end
      end
      p.settlersTrained = math.max(0, cities - 1) + settlers
    end
    p.ai = p.ai or false
    p.explored = p.explored or {}
    p.food = p.food or 0
    p.wood = p.wood or 0
    p.science = p.science or 0
    p.gold = p.gold or 20
    p.researchProgress = p.researchProgress or {}
    Economy.stocks(p)
  end
  for _, c in ipairs(state.cities or {}) do
    M.nameCity(state, c)
    c.population = c.population or 2
    c.foodStore = c.foodStore or 0
    c.growthAge = c.growthAge or 0
    c.hungryTurns = c.hungryTurns or 0
    c.jobs = c.jobs or { food = 1, wood = 1, science = 0 }
    c.buildings = c.buildings or {}
    c.projectProgress = c.projectProgress or {}
    M.ensureWorkers(state, c)
  end
  for _, u in ipairs(state.units or {}) do
    local stats = M.units[u.kind] or M.units.warrior
    if u.movesLeft == nil then
      u.movesLeft = u.moved and 0 or stats.move
    end
  end
  Combat.migrate(state)
  state.version = 6
  return state
end
function M.canResearch(p, id)
  local t = M.techs[id]
  if not t or p.techs[id] then
    return false
  end
  for _, req in ipairs(t.requires) do
    if not p.techs[req] then
      return false
    end
  end
  return true
end
-- Research selects a project. Science arrives at the global turn boundary.
function M.research(p, id)
  if not M.canResearch(p, id) then
    return false, "Technology prerequisites unmet"
  end
  p.researchTarget = id
  p.researchProgress = p.researchProgress or {}
  p.researchProgress[id] = p.researchProgress[id] or 0
  return true
end
function M.coastal(state, c)
  if not state or not state.world then
    return false
  end
  for _, n in ipairs(Hex.neighbours(c.x, c.y, state)) do
    if Hex.terrain(n.x, n.y, state) == "water" then
      return true
    end
  end
  return false
end
function M.treasury(p, state)
  local income, upkeep = 0, 0
  for _, city in ipairs(state.cities or {}) do
    if city.owner == p.id then
      local effects = Economy.effects(city, state, M)
      income = income + 2 + (city.population or 2) + effects.gold
    end
  end
  for _, unit in ipairs(state.units or {}) do
    if unit.owner == p.id then
      upkeep = upkeep + ((M.units[unit.kind] or {}).upkeep or 1)
    end
  end
  return { income = income, upkeep = upkeep, net = income - upkeep }
end
function M.economy(p, state)
  local result = M.treasury(p, state)
  result.food = 0
  result.industry = 0
  result.science = 0
  result.strategic = { iron = 0, horses = 0, saltpeter = 0 }
  for _, city in ipairs(state.cities or {}) do
    if city.owner == p.id then
      local y = M.yields(p, city, state, Hex)
      result.food = result.food + y.food - 2 * (city.population or 2)
      result.industry = result.industry + y.industry
      result.science = result.science + y.science
    end
  end
  local owned = World.territory(state, Hex)
  result.strategic = Economy.rates(p, state, owned)
  return result
end
function M.canBuild(p, c, id, state)
  local b = M.buildings[id]
  if not b or b.tech and not p.techs[b.tech] or c.buildings[id] or b.coastal and not M.coastal(state, c) then
    return false
  end
  for _, need in ipairs(b.requires or {}) do
    if not c.buildings[need] then
      return false
    end
  end
  return true
end
function M.canRecruit(p, id, state, hex, city)
  local u = M.units[id]
  if not u or u.hostile or (u.tech and not p.techs[u.tech]) then
    return false
  end
  if u.unique and p.civ ~= u.unique then
    return false
  end
  if u.building and (not city or not (city.buildings or {})[u.building] or u.naval and not M.coastal(state, city)) then
    return false
  end
  if state and (p.gold or 20) <= 0 and M.treasury(p, state).net < (u.upkeep or 1) then
    return false
  end
  if
    u.resource
    and ((p.stockpile or {})[u.resource] or 0) < 2
    and (not state or not hex or not World.strategic(state, p, hex, u.resource))
  then
    return false
  end
  return true
end
-- Retain familiar action names as pure queue selection (no purchases).
function M.queue(p, c, kind, id, state, hex, x, y)
  if kind == "none" then
    if c.project then
      c.projectProgress = c.projectProgress or {}
      c.projectProgress[c.project.kind .. ":" .. c.project.id] = c.project.progress
    end
    c.project = nil
    c.productionIdle = true
    return true
  end
  if kind == "wonder" then
    if not Landmarks.canPlace(state, c, id, x, y, M) then
      return false, "Wonder needs its research and an empty owned land hex; one per world"
    end
  elseif kind == "building" then
    if not M.canBuild(p, c, id, state) then
      return false, "Building locked or already completed"
    end
  elseif kind == "unit" then
    if not M.canRecruit(p, id, state, hex, c) then
      return false, "Unit locked or missing strategic resource"
    end
  else
    return false, "Unknown project category"
  end
  if c.project then
    c.projectProgress = c.projectProgress or {}
    c.projectProgress[c.project.kind .. ":" .. c.project.id] = c.project.progress
  end
  c.productionIdle = false
  c.project = { kind = kind, id = id, x = x, y = y, progress = (c.projectProgress or {})[kind .. ":" .. id] or 0 }
  return true
end
function M.build(p, c, id, state, hex)
  return M.queue(p, c, "building", id, state, hex)
end
function M.idle(c)
  local total = 0
  for _, job in ipairs(M.jobs) do
    total = total + (c.jobs[job] or 0)
  end
  return math.max(0, (c.population or 2) - total)
end
function M.assign(c, from, to, state)
  local function valid(job)
    return job == "idle" or job == "food" or job == "wood" or job == "science"
  end
  if not valid(from) or not valid(to) or from == to then
    return false, "Invalid citizen assignment"
  end
  if state and state.world then
    M.ensureWorkers(state, c)
  end
  local count = from == "idle" and M.idle(c) or (c.jobs[from] or 0)
  if count <= 0 then
    return false, from == "idle" and "No idle citizens" or "No citizens assigned to this job"
  end
  if state and state.world then
    local remove, candidates = nil, {}
    for _, tile in ipairs(M.workable(state, c)) do
      if c.worked[tile.key] and M.tileJob(tile) == from then
        remove = tile.key
      end
      if not c.worked[tile.key] and M.tileJob(tile) == to then
        candidates[#candidates + 1] = tile.key
      end
    end
    if to ~= "idle" and #candidates == 0 then
      return false, "No free owned tile of this job type"
    end
    if remove then
      c.worked[remove] = nil
    end
    if to ~= "idle" then
      local index = ((state.round or 1) * 31 + c.x * 17 + c.y * 13 + count) % #candidates + 1
      c.worked[candidates[index]] = true
    end
    M.ensureWorkers(state, c)
    return true
  end
  if from ~= "idle" then
    c.jobs[from] = c.jobs[from] - 1
  end
  if to ~= "idle" then
    c.jobs[to] = (c.jobs[to] or 0) + 1
  end
  return true
end
function M.techCost(id)
  local tech = M.techs[id]
  return tech and tech.cost or nil
end
function M.projectCost(kind, id, player)
  local record = (kind == "unit" and M.units or kind == "wonder" and M.wonders or M.buildings)[id]
  if not record then
    return nil
  end
  local base = record.production or math.ceil((record.wood or 8) * 2.5)
  if kind == "unit" and id == "settler" then
    return base + (record.productionStep or 0) * ((player and player.settlersTrained) or 0)
  end
  return base
end
function M.centerYields(p, c, state)
  local e = Economy.effects(c, state, M)
  local civ = p.civ
  local buildings = c.buildings or {}
  local food, industry, science = 2 + e.food, 1 + e.industry, 1 + e.science
  if civ == "verdant" and buildings.farm then
    food = food + 1
  end
  if civ == "iron" and buildings.mine then
    industry = industry + 1
  end
  if civ == "scholar" then
    science = science + 2
  end
  if civ == "forge" and buildings.workshop then
    industry = industry + 2
  end
  if civ == "merchant" and buildings.market then
    food = food + 2
  end
  return { food = food, industry = industry, science = science }
end
function M.yields(p, c, state, hex, owned)
  local center = M.centerYields(p, c, state)
  local jobs = c.jobs
  local food = center.food - 1 + jobs.food * 2
  local industry = center.industry + jobs.wood * 2
  local science = center.science - 1 + jobs.science * 2
  if state and state.world then
    -- Replace abstract F/W/S worker counters with owned worked hexes.
    M.ensureWorkers(state, c)
    local center = M.centerYields(p, c, state)
    food, industry, science = center.food, center.industry, center.science
    for _, tile in ipairs(M.workable(state, c)) do
      if c.worked and c.worked[tile.key] then
        food = food + tile.yield.food
        industry = industry + tile.yield.industry
        science = science + tile.yield.science
      end
    end
  end
  return { food = food, industry = industry, science = science }
end
-- Stable city yield entry point for UI, AI and regression tests.
function M.cityYield(state, city)
  for _, p in ipairs(state.players or {}) do
    if p.id == city.owner then
      return M.yields(p, city, state, Hex)
    end
  end
  return nil
end
local function spawn(state, p, c, id, hex)
  local stats = M.units[id]
  if not stats then
    return false
  end
  local function available(x, y)
    for _, u in ipairs(state.units) do
      if u.x == x and u.y == y then
        return false
      end
    end
    return hex.passable(x, y, state, { kind = id, owner = p.id }, M)
  end
  local x, y = c.x, c.y
  if stats.naval or not available(x, y) then
    x = nil
    for _, n in ipairs(hex.neighbours(c.x, c.y, state)) do
      if available(n.x, n.y) then
        x, y = n.x, n.y
        break
      end
    end
  end
  if not x then
    return false
  end
  if stats.resource then
    p.stockpile = p.stockpile or {}
    if (p.stockpile[stats.resource] or 0) < 2 then
      return false
    end
    p.stockpile[stats.resource] = p.stockpile[stats.resource] - 2
  end
  state.units[#state.units + 1] =
    { id = state.nextId, owner = p.id, x = x, y = y, kind = id, moved = true, movesLeft = 0 }
  state.nextId = state.nextId + 1
  if id == "settler" then
    p.settlersTrained = (p.settlersTrained or 0) + 1
  end
  return true
end
function M.growth(p, c, state)
  local yield = M.yields(p, c, state, Hex)
  local surplus = yield.food - 2 * (c.population or 2)
  local threshold = 20 + 8 * (c.population or 2)
  local result = { surplus = surplus, threshold = threshold, stored = c.foodStore or 0 }
  if surplus > 0 then
    result.status = "GROWING"
    result.turns = math.max(1, 4 - (c.growthAge or 0), math.ceil((threshold - result.stored) / surplus))
  elseif surplus == 0 then
    result.status = "STAGNANT"
  else
    result.status = "STARVING"
    result.canShrink = (c.population or 2) > 1
    result.turns = math.max(3 - (c.hungryTurns or 0), math.ceil(result.stored / -surplus), 1)
  end
  return result
end
function M.autoExplore(state, unit, hex)
  if unit.kind ~= "scout" and unit.kind ~= "explorer" then
    return false, "Only scouts and explorers can auto explore"
  end
  local player
  for _, p in ipairs(state.players) do
    if p.id == unit.owner then
      player = p
    end
  end
  if not player or not state.world then
    return false, "No world to explore"
  end
  unit.autoExplore = true
  unit.standby = false
  while (unit.movesLeft or 0) > 0 and not unit.moved do
    World.reveal(state, hex, M)
    local scout = {}
    for k, v in pairs(unit) do
      scout[k] = v
    end
    scout.movesLeft = state.world.width * state.world.height * 3
    scout.moved = false
    local best, bestScore
    local vision = (M.units[unit.kind] or M.units.scout).vision
    for _, choice in ipairs(hex.reachable(state, scout, unit.owner, M)) do
      if not choice.attack then
        local discoveries = 0
        for y = math.max(1, choice.y - vision), math.min(state.world.height, choice.y + vision) do
          for x = math.max(1, choice.x - vision), math.min(state.world.width, choice.x + vision) do
            if not (player.explored or {})[World.key(x, y)] and hex.distance(x, y, choice.x, choice.y) <= vision then
              discoveries = discoveries + 1
            end
          end
        end
        local score = discoveries / (choice.cost + 1)
        if discoveries > 0 and (not bestScore or score > bestScore) then
          best = choice
          bestScore = score
        end
        if M.checkpoint then
          M.checkpoint()
        end
      end
    end
    if not best then
      unit.autoExplore = false
      return true, "No safe unexplored frontier remains"
    end
    local spent = 0
    local destination
    for i = 2, #best.path do
      local point = best.path[i]
      local cost = hex.moveCost(point.x, point.y, state, unit, M, best.path[i - 1].x, best.path[i - 1].y)
      if not cost or spent + cost > unit.movesLeft then
        break
      end
      spent = spent + cost
      destination = point
    end
    if not destination then
      unit.movesLeft = 0
      unit.moved = true
      break
    end
    local ok = Actions.apply(
      state,
      unit.owner,
      { action = "move", sx = unit.x, sy = unit.y, x = destination.x, y = destination.y },
      M
    )
    if not ok then
      unit.autoExplore = false
      return false, "Exploration route blocked"
    end
    unit.autoExplore = true
  end
  World.reveal(state, hex, M)
  return true
end
function M.production(state, hex)
  local owned = state.world and hex and World.territory(state, hex) or {}
  for _, p in ipairs(state.players) do
    if M.checkpoint then
      M.checkpoint()
    end
    p.researchProgress = p.researchProgress or {}
    Economy.stocks(p)
    local rates = Economy.rates(p, state, owned)
    for id, rate in pairs(rates) do
      p.stockpile[id] = p.stockpile[id] + rate
    end
    local totalScience = 0
    for _, c in ipairs(state.cities) do
      if c.owner == p.id then
        if M.checkpoint then
          M.checkpoint()
        end
        local yield = M.yields(p, c, state, hex, owned)
        totalScience = totalScience + yield.science
        p.food = math.max(0, (p.food or 0) + yield.food - 2 * (c.population or 2))
        p.wood = (p.wood or 0) + yield.industry
        local growth = M.growth(p, c, state)
        c.growthAge = (c.growthAge or 0) + 1
        c.foodStore = math.max(0, (c.foodStore or 0) + growth.surplus)
        if growth.surplus < 0 then
          c.hungryTurns = (c.hungryTurns or 0) + 1
          if c.foodStore <= 0 and c.hungryTurns >= 3 and c.population > 1 then
            c.population = c.population - 1
            c.hungryTurns = 0
            c.growthAge = 0
            M.ensureWorkers(state, c)
          end
        else
          c.hungryTurns = 0
          if growth.surplus > 0 and c.foodStore >= growth.threshold and c.growthAge >= 4 then
            c.foodStore = c.foodStore - growth.threshold
            c.population = c.population + 1
            c.growthAge = 0
            if state.world then
              for _, tile in ipairs(M.workable(state, c)) do
                if not c.worked[tile.key] then
                  c.worked[tile.key] = true
                  break
                end
              end
              M.ensureWorkers(state, c)
            else
              c.jobs.food = c.jobs.food + 1
            end
          end
        end
        if state.world then
          World.expandCity(state, hex, c)
        end
        if c.project then
          local pr = c.project
          local valid = pr.kind == "wonder" and Landmarks.canPlace(state, c, pr.id, pr.x, pr.y, M)
            or pr.kind == "building" and M.canBuild(p, c, pr.id, state)
            or pr.kind == "unit" and M.canRecruit(p, pr.id, state, hex, c)
          if valid then
            pr.progress = pr.progress + yield.industry
            local cost = M.projectCost(pr.kind, pr.id, p)
            if pr.progress >= cost then
              local completed
              if pr.kind == "wonder" then
                completed = Landmarks.complete(state, c, pr, M)
              elseif pr.kind == "building" then
                c.buildings[pr.id] = true
                Combat.city(c)
                completed = true
              else
                completed = spawn(state, p, c, pr.id, hex)
              end
              if completed then
                c.project = nil
                c.projectProgress = c.projectProgress or {}
                c.projectProgress[pr.kind .. ":" .. pr.id] = nil
              end
            end
          end
          if c.project then
            c.projectProgress = c.projectProgress or {}
            c.projectProgress[pr.kind .. ":" .. pr.id] = pr.progress
          end
        end
      end
    end
    local treasury = M.treasury(p, state)
    p.gold = (p.gold or 20) + treasury.net
    if p.gold < 0 then
      for index = #state.units, 1, -1 do
        local unit = state.units[index]
        if unit.owner == p.id then
          p.gold = p.gold + ((M.units[unit.kind] or {}).upkeep or 1)
          table.remove(state.units, index)
          if p.gold >= 0 then
            break
          end
        end
      end
      p.gold = math.max(0, p.gold)
    end
    p.scienceRate = totalScience
    p.science = (p.science or 0) + totalScience
    local id = p.researchTarget
    if id and M.canResearch(p, id) then
      local progress = (p.researchProgress[id] or 0) + totalScience
      p.researchProgress[id] = progress
      if progress >= M.techs[id].cost then
        p.techs[id] = true
        p.researchTarget = nil
      end
    end
  end
end
-- AI plays by the same research and production queue rules as humans.
function M.aiTurn(state, p, hex)
  if p.ready then
    return
  end
  AI.diplomacy(state, p, M)
  if not p.researchTarget then
    local id = AI.research(p, M)
    if id then
      Actions.apply(state, p.id, { action = "researchTech", id = id }, M)
    end
  end
  for _, city in ipairs(state.cities) do
    if city.owner == p.id then
      for _, enemy in ipairs(state.units) do
        if
          enemy.owner ~= p.id
          and Actions.apply(
            state,
            p.id,
            { action = "cityStrike", x = city.x, y = city.y, tx = enemy.x, ty = enemy.y },
            M
          )
        then
          break
        end
      end
      if not city.project and not city.productionIdle then
        AI.choose(state, p, city, M)
      end
      if city.jobs.food > 1 and city.jobs.science < 2 then
        Actions.apply(state, p.id, { action = "assign", x = city.x, y = city.y, from = "food", to = "science" }, M)
      end
    end
  end
  -- Move one unit a turn; settlers expand, warriors approach other empires.
  local orders = {}
  for _, u in ipairs(state.units) do
    orders[#orders + 1] = u
  end
  for _, u in ipairs(orders) do
    local present = false
    for _, v in ipairs(state.units) do
      if v == u then
        present = true
        break
      end
    end
    if present and u.owner == p.id and not u.moved then
      local engineer = (M.units[u.kind] or {}).engineer
      if engineer then
        AI.engineer(state, p, u, M)
      end
      local choices = not engineer and hex.reachable(state, u, p.id, M) or {}
      for index = #choices, 1, -1 do
        if choices[index].attack then
          local neutral = false
          for _, c in ipairs(state.cities) do
            if c.village and c.owner == c.villageOwner and c.x == choices[index].x and c.y == choices[index].y then
              neutral = true
            end
          end
          for _, v in ipairs(state.units) do
            if v.villageGuard and v.owner < 0 and v.x == choices[index].x and v.y == choices[index].y then
              neutral = true
            end
          end
          if neutral then
            table.remove(choices, index)
          end
        end
      end
      if u.kind == "settler" then
        local canFound = true
        for _, c in ipairs(state.cities) do
          if hex.distance(c.x, c.y, u.x, u.y) < 3 then
            canFound = false
          end
        end
        local nearest = 100
        for _, c in ipairs(state.cities) do
          if c.owner == p.id then
            nearest = math.min(nearest, hex.distance(c.x, c.y, u.x, u.y))
          end
        end
        if (state.world.landmarks or {})[u.x .. ":" .. u.y] then
          canFound = false
        end
        for _, camp in ipairs(state.spawners or {}) do
          if not camp.cleared and camp.x == u.x and camp.y == u.y then
            canFound = false
          end
        end
        if canFound and nearest <= 5 then
          local ok = Actions.apply(state, p.id, { action = "found", x = u.x, y = u.y }, M)
          if ok then
            u.consumed = true
          end
        end
      end
      if not u.consumed and #choices > 0 then
        local target
        for _, c in ipairs(state.cities) do
          if c.owner ~= p.id and ((p.explored or {})[c.x .. ":" .. c.y] or (p.visible or {})[c.x .. ":" .. c.y]) then
            target = c
            break
          end
        end
        table.sort(choices, function(a, b)
          if u.kind == "settler" then
            local function settlementScore(tile)
              local terrain = hex.terrain(tile.x, tile.y, state)
              if
                terrain == "water"
                or terrain == "mountain"
                or (state.world.landmarks or {})[tile.x .. ":" .. tile.y]
              then
                return -1000
              end
              local closest, home = 100, 100
              for _, c in ipairs(state.cities) do
                local d = hex.distance(tile.x, tile.y, c.x, c.y)
                closest = math.min(closest, d)
                if c.owner == p.id then
                  home = math.min(home, d)
                end
              end
              return closest >= 3 and home <= 5 and 100 - home or closest * 2 - home
            end
            local aa, bb = settlementScore(a), settlementScore(b)
            if aa ~= bb then
              return aa > bb
            end
            return a.y == b.y and a.x < b.x or a.y < b.y
          end
          if not target then
            return a.x + a.y > b.x + b.y
          end
          return hex.distance(a.x, a.y, target.x, target.y) < hex.distance(b.x, b.y, target.x, target.y)
        end)
        for _, choice in ipairs(choices) do
          if choice.attack then
            target = { x = choice.x, y = choice.y }
            break
          end
        end
        if u.kind ~= "settler" then
          table.sort(choices, function(a, b)
            if (a.attack == true) ~= (b.attack == true) then
              return a.attack == true
            end
            local da = target and hex.distance(a.x, a.y, target.x, target.y) or a.cost
            local db = target and hex.distance(b.x, b.y, target.x, target.y) or b.cost
            if da ~= db then
              return da < db
            end
            return a.y == b.y and a.x < b.x or a.y < b.y
          end)
        end
        local choice = choices[1]
        Actions.apply(state, p.id, { action = "move", sx = u.x, sy = u.y, x = choice.x, y = choice.y }, M)
      end
    end
  end
  for i = #state.units, 1, -1 do
    if state.units[i].consumed then
      table.remove(state.units, i)
    end
  end
  p.ready = true
end
return M
