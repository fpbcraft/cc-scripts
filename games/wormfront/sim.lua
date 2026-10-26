-- WORMFRONT deterministic, host-authoritative match rules.
-- The same state and actions work in hotseat mode and over rednet.
local S = {}
S.W, S.H = 72, 36
local weapons = { { name = "ROCKET", radius = 4, damage = 42, speed = 1 }, { name = "MEGA", radius = 7, damage = 60, speed = 0.8 } }

local function clamp(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end

local function solid(g, x, y)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  return x >= 1 and x <= S.W and y >= 1 and y <= S.H and g.terrain[x]:sub(y, y) == "#"
end

local function ground(g, x)
  for y = 1, S.H do
    if solid(g, x, y) then
      return y
    end
  end
  return S.H + 1
end

local function alive(g, team)
  for _, worm in ipairs(g.worms) do
    if worm.team == team and worm.hp > 0 then
      return true
    end
  end
  return false
end

function S.worm(g)
  local team = g.turn
  local selection = g.selected[team]
  if selection and g.worms[selection] and g.worms[selection].hp > 0 then
    return g.worms[selection]
  end
  for i, worm in ipairs(g.worms) do
    if worm.team == team and worm.hp > 0 then
      g.selected[team] = i
      return worm
    end
  end
  return nil
end

function S.new(teams, seed)
  assert(type(teams) == "number" and teams >= 2 and teams <= 4, "Expected 2-4 teams")
  seed = math.floor(tonumber(seed) or 1)
  math.randomseed(seed)
  local g = {
    version = 1,
    seed = seed,
    phase = "playing",
    teams = teams,
    terrain = {},
    worms = {},
    selected = {},
    turn = 1,
    round = 1,
    wind = math.random(-3, 3),
    moves = 0,
    trace = {},
    blast = nil,
    message = "Take aim and fire!",
    winner = nil,
  }
  for x = 1, S.W do
    local elevation = 24 + math.sin(x * 0.17) * 4 + math.cos(x * 0.39) * 2 + math.random(-1, 1)
    local y0 = clamp(math.floor(elevation), 18, 31)
    g.terrain[x] = ("."):rep(y0 - 1) .. ("#"):rep(S.H - y0 + 1)
  end
  for team = 1, teams do
    for n = 1, 3 do
      local x = math.floor((team - 1 + n / 4) * (S.W - 8) / teams) + 5
      x = clamp(x, 3, S.W - 2)
      local worm = {
        team = team,
        x = x,
        y = ground(g, x) - 1,
        hp = 100,
        aim = team % 2 == 1 and 45 or 135,
        power = 65,
        weapon = 1,
        mega = 2,
      }
      g.worms[#g.worms + 1] = worm
      if n == 1 then
        g.selected[team] = #g.worms
      end
    end
  end
  return g
end

local function crater(g, cx, cy, radius)
  local r2 = radius * radius
  for x = math.max(1, math.floor(cx - radius)), math.min(S.W, math.ceil(cx + radius)) do
    local column = g.terrain[x]
    local parts = {}
    for y = 1, S.H do
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r2 then
        parts[y] = "."
      else
        parts[y] = column:sub(y, y)
      end
    end
    g.terrain[x] = table.concat(parts)
  end
end

local function settle(g)
  for _, worm in ipairs(g.worms) do
    if worm.hp > 0 then
      local oldY = worm.y
      local floor = ground(g, worm.x)
      if floor > S.H then
        worm.hp = 0
      else
        worm.y = floor - 1
        local fall = math.max(0, worm.y - oldY)
        if fall > 4 then
          worm.hp = math.max(0, worm.hp - (fall - 4) * 6)
        end
      end
    end
  end
end

local function nextTurn(g)
  local remaining, last = 0, nil
  for team = 1, g.teams do
    if alive(g, team) then
      remaining = remaining + 1
      last = team
    end
  end
  if remaining <= 1 then
    g.phase = "finished"
    g.winner = last
    g.message = last and ("TEAM " .. last .. " WINS!") or "DRAW!"
    return
  end
  repeat
    g.turn = g.turn % g.teams + 1
    if g.turn == 1 then
      g.round = g.round + 1
    end
  until alive(g, g.turn)
  g.wind = math.random(-3, 3)
  g.moves = 0
  S.worm(g)
end

local function shoot(g, worm)
  local weapon = weapons[worm.weapon]
  local a = math.rad(worm.aim)
  local v = (0.8 + worm.power * 0.025) * weapon.speed
  local vx, vy = math.cos(a) * v, -math.sin(a) * v
  local x, y = worm.x + math.cos(a) * 1.6, worm.y - math.sin(a) * 1.6
  local hitX, hitY = nil, nil
  g.trace = {}
  for step = 1, 600 do
    x = x + vx * 0.3
    y = y + vy * 0.3
    vx = vx + g.wind * 0.0009
    vy = vy + 0.13 * 0.3
    if step % 4 == 0 then
      g.trace[#g.trace + 1] = { x = x, y = y }
    end
    if x < 1 or x > S.W or y > S.H then
      break
    end
    if y >= 1 then
      local collision = solid(g, x, y)
      for _, target in ipairs(g.worms) do
        if target.hp > 0 and (target ~= worm or step > 12) then
          if (x - target.x) ^ 2 + (y - target.y) ^ 2 < 1.1 then
            collision = true
          end
        end
      end
      if collision then
        hitX, hitY = x, y
        break
      end
    end
  end
  if hitX then
    crater(g, hitX, hitY, weapon.radius)
    for _, target in ipairs(g.worms) do
      if target.hp > 0 then
        local distance = math.sqrt((target.x - hitX) ^ 2 + (target.y - hitY) ^ 2)
        local damage = math.floor(weapon.damage * math.max(0, 1 - distance / (weapon.radius + 2)) + 0.5)
        target.hp = math.max(0, target.hp - damage)
      end
    end
    settle(g)
    g.blast = { x = hitX, y = hitY, radius = weapon.radius }
    g.message = weapon.name .. " IMPACT!"
  else
    g.blast = nil
    g.message = "MISS!"
  end
end

function S.apply(g, team, action)
  if type(g) ~= "table" or g.phase ~= "playing" then
    return false, "Match not active"
  end
  if team ~= g.turn then
    return false, "Not your turn"
  end
  if type(action) ~= "table" then
    return false, "Invalid action"
  end
  local worm = S.worm(g)
  if not worm then
    return false, "No living worm"
  end
  local kind = action.kind
  if kind == "move" then
    local direction = action.dir
    if (direction ~= -1 and direction ~= 1) or g.moves >= 4 then
      return false, "No movement remaining"
    end
    local x = worm.x + direction
    if x < 2 or x >= S.W then
      return false, "Edge of map"
    end
    local y = ground(g, x) - 1
    if y >= S.H or math.abs(y - worm.y) > 2 then
      return false, "Too steep"
    end
    for _, other in ipairs(g.worms) do
      if other ~= worm and other.hp > 0 and other.x == x and other.y == y then
        return false, "Occupied"
      end
    end
    worm.x, worm.y = x, y
    g.moves = g.moves + 1
  elseif kind == "aim" then
    if action.dir ~= -1 and action.dir ~= 1 then
      return false, "Invalid aim"
    end
    worm.aim = clamp(worm.aim + action.dir * 5, 5, 175)
  elseif kind == "power" then
    if action.dir ~= -1 and action.dir ~= 1 then
      return false, "Invalid power"
    end
    worm.power = clamp(worm.power + action.dir * 5, 20, 100)
  elseif kind == "select" then
    local idx = g.selected[team]
    for _ = 1, #g.worms do
      idx = idx % #g.worms + 1
      if g.worms[idx].team == team and g.worms[idx].hp > 0 then
        g.selected[team] = idx
        break
      end
    end
  elseif kind == "weapon" then
    worm.weapon = worm.weapon == 1 and worm.mega > 0 and 2 or 1
  elseif kind == "fire" then
    if worm.weapon == 2 then
      if worm.mega <= 0 then
        return false, "No mega bombs left"
      end
      worm.mega = worm.mega - 1
    end
    shoot(g, worm)
    nextTurn(g)
    return true
  else
    return false, "Unknown action"
  end
  g.trace, g.blast = {}, nil
  g.message = "TEAM " .. team .. " AIMING"
  return true
end

S.solid = solid
S.ground = ground
return S
