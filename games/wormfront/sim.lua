-- WORMFRONT v0.2: time-based artillery, deterministic combat and pickups.
-- Only the authoritative host advances physics and the turn clock.
local S = {}
S.W, S.H = 72, 36
S.TURN_SECONDS = 45
local weapons = {
  { name = "ROCKET", radius = 4.5, damage = 42, speed = 1 },
  { name = "MEGA", radius = 7, damage = 64, speed = 0.86 },
}
S.weapons = weapons
local function clamp(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end

-- Local PRNG: match generation and mid-game crates never affect global math.random.
local function random(g, lo, hi)
  g.rng = (g.rng * 48271) % 2147483647
  local fraction = g.rng / 2147483647
  if lo then
    return lo + math.floor(fraction * (hi - lo + 1))
  end
  return fraction
end

local function solid(g, x, y)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  return x >= 1 and x <= S.W and y >= 1 and y <= S.H and g.terrain[x]:sub(y, y) == "#"
end

local function ground(g, x)
  if x < 1 or x > S.W then
    return S.H + 1
  end
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
  local id = g.selected[g.turn]
  if id and g.worms[id] and g.worms[id].team == g.turn and g.worms[id].hp > 0 then
    return g.worms[id]
  end
  for i, worm in ipairs(g.worms) do
    if worm.team == g.turn and worm.hp > 0 then
      g.selected[g.turn] = i
      return worm
    end
  end
end

local function drop(g)
  if #g.items >= 4 then
    return
  end
  for _ = 1, 40 do
    local x = random(g, 4, S.W - 3)
    local y = ground(g, x) - 1
    local clear = y > 4 and y < S.H - 2
    for _, w in ipairs(g.worms) do
      if w.hp > 0 and math.abs(w.x - x) < 2 then
        clear = false
      end
    end
    if clear then
      g.items[#g.items + 1] = { x = x, y = y, kind = ({ "MEDKIT", "AMMO", "SHIELD" })[random(g, 1, 3)] }
      return
    end
  end
end

local function collect(g, worm)
  for i = #g.items, 1, -1 do
    local item = g.items[i]
    if (worm.x - item.x) ^ 2 + (worm.y - item.y) ^ 2 <= 2.5 then
      if item.kind == "MEDKIT" then
        worm.hp = math.min(100, worm.hp + 30)
      elseif item.kind == "AMMO" then
        worm.mega = worm.mega + 1
      else
        worm.shield = true
      end
      g.message = item.kind .. " COLLECTED!"
      table.remove(g.items, i)
    end
  end
end

local function settle(g)
  for _, w in ipairs(g.worms) do
    if w.hp > 0 and not w.airborne then
      local old = w.y
      local y = ground(g, w.x) - 1
      if y >= S.H then
        w.hp = 0
      else
        w.y = y
        local fall = math.max(0, y - old)
        if fall > 4 then
          local damage = (fall - 4) * 6
          if w.shield then
            damage = math.floor(damage / 2)
            w.shield = false
          end
          w.hp = math.max(0, w.hp - damage)
        end
        if w.hp > 0 then
          collect(g, w)
        end
      end
    end
  end
  for i = #g.items, 1, -1 do
    local item = g.items[i]
    item.y = ground(g, item.x) - 1
    if item.y >= S.H then
      table.remove(g.items, i)
    end
  end
end

local function crater(g, cx, cy, radius)
  for x = math.max(1, math.floor(cx - radius)), math.min(S.W, math.ceil(cx + radius)) do
    local column = g.terrain[x]
    local chars = {}
    for y = 1, S.H do
      chars[y] = (x - cx) ^ 2 + (y - cy) ^ 2 <= radius * radius and "." or column:sub(y, y)
    end
    g.terrain[x] = table.concat(chars)
  end
end

local function nextTurn(g)
  local count, victor = 0, nil
  for team = 1, g.teams do
    if alive(g, team) then
      count, victor = count + 1, team
    end
  end
  if count <= 1 then
    g.phase, g.winner = "finished", victor
    g.message = victor and ("TEAM " .. victor .. " WINS!") or "DRAW!"
    g.state, g.charging, g.projectile, g.explosion = "end", false, nil, nil
    return
  end
  repeat
    g.turn = g.turn % g.teams + 1
    if g.turn == 1 then
      g.round = g.round + 1
    end
  until alive(g, g.turn)
  g.turnLeft, g.state, g.charging, g.charge = S.TURN_SECONDS, "aim", false, 0
  g.wind = random(g, -3, 3)
  g.projectile, g.explosion, g.trail = nil, nil, {}
  g.message = "TEAM " .. g.turn .. " TURN"
  if g.round % 2 == 0 then
    drop(g)
  end
  S.worm(g)
end

local function explode(g, x, y, weapon)
  local item = weapons[weapon]
  crater(g, x, y, item.radius)
  for _, w in ipairs(g.worms) do
    if w.hp > 0 then
      local distance = math.sqrt((w.x - x) ^ 2 + (w.y - y) ^ 2)
      local damage = math.floor(item.damage * math.max(0, 1 - distance / (item.radius + 2)) + 0.5)
      if w.shield and damage > 0 then
        damage = math.floor(damage / 2)
        w.shield = false
      end
      w.hp = math.max(0, w.hp - damage)
    end
  end
  settle(g)
  g.projectile = nil
  g.state = "blast"
  g.explosion = { x = x, y = y, radius = item.radius, elapsed = 0 }
  g.message = item.name .. " IMPACT!"
end

local function release(g, worm)
  if not g.charging then
    return false, "Not charging"
  end
  g.charging = false
  if worm.weapon == 2 then
    if worm.mega == 0 then
      return false, "Out of mega bombs"
    end
    worm.mega = worm.mega - 1
  end
  local fraction = clamp(g.charge / 1.8, 0.08, 1)
  local speed = (5.5 + 19 * fraction) * weapons[worm.weapon].speed
  local angle = math.rad(worm.aim)
  g.projectile = {
    x = worm.x + math.cos(angle) * 1.9,
    y = worm.y - math.sin(angle) * 1.9,
    vx = math.cos(angle) * speed,
    vy = -math.sin(angle) * speed,
    weapon = worm.weapon,
    elapsed = 0,
  }
  g.trail, g.state = {}, "flight"
  g.message = "FIRING " .. weapons[worm.weapon].name
  return true
end

function S.new(teams, seed)
  assert(type(teams) == "number" and teams >= 2 and teams <= 4, "Expected 2-4 teams")
  local g = {
    version = 2,
    seed = math.floor(tonumber(seed) or 1),
    teams = teams,
    terrain = {},
    worms = {},
    selected = {},
    items = {},
    turn = 1,
    round = 1,
    phase = "playing",
    state = "aim",
    turnLeft = S.TURN_SECONDS,
    wind = 0,
    charge = 0,
    charging = false,
    projectile = nil,
    explosion = nil,
    trail = {},
    message = "AIM WITH UP / DOWN",
  }
  g.rng = g.seed % 2147483646 + 1
  g.theme = random(g, 1, 4)
  local elevation = random(g, 20, 27)
  local variation = random(g, 3, 6)
  local phase = random(g) * 6.28
  for x = 1, S.W do
    local h = elevation
      + math.sin(x * (0.10 + g.theme * 0.015) + phase) * variation
      + math.cos(x * 0.27 + phase) * (variation / 2)
      + random(g, -1, 1)
    local surface = clamp(math.floor(h), 17, 31)
    g.terrain[x] = ("."):rep(surface - 1) .. ("#"):rep(S.H - surface + 1)
  end
  -- Varied ridges, valleys and craters without obstructing guaranteed starting sites.
  if g.theme == 3 or g.theme == 4 then
    crater(g, random(g, 20, 52), 21, random(g, 3, 5))
  end
  for team = 1, teams do
    for n = 1, 3 do
      local slot = (n - 1) * teams + team
      local x = clamp(math.floor((slot - 0.5) * (S.W - 10) / (teams * 3)) + 5, 3, S.W - 2)
      local aim = (team % 2 == 1) and 45 or 135
      local w = {
        team = team,
        x = x,
        y = ground(g, x) - 1,
        hp = 100,
        aim = aim,
        facing = aim < 90 and 1 or -1,
        weapon = 1,
        mega = 2,
        shield = false,
        airborne = false,
      }
      g.worms[#g.worms + 1] = w
      if n == 1 then
        g.selected[team] = #g.worms
      end
    end
  end
  g.wind = random(g, -3, 3)
  drop(g)
  drop(g)
  return g
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
  if g.state ~= "aim" then
    return false, "Shot in progress"
  end
  local w = S.worm(g)
  if not w then
    return false, "No living worm"
  end
  local kind, dir = action.kind, action.dir
  if kind == "release" or (kind == "fire" and g.charging) then
    return release(g, w)
  elseif kind == "fire" or kind == "charge" then
    if w.airborne then
      return false, "Land before firing"
    end
    if w.weapon == 2 and w.mega <= 0 then
      return false, "Out of mega bombs"
    end
    if not g.charging then
      g.charging, g.charge = true, 0
    end
  elseif g.charging then
    return false, "Release shot first"
  elseif kind == "move" then
    if dir ~= -1 and dir ~= 1 then
      return false, "Invalid direction"
    end
    if w.airborne then
      -- Horizontal air control is applied by changing jump velocity.
      w.vx = dir * 8
    else
      local x = w.x + dir
      if x < 2 or x >= S.W then
        return false, "Edge of map"
      end
      local y = ground(g, x) - 1
      if y >= S.H or math.abs(y - w.y) > 2 then
        return false, "Too steep"
      end
      for _, other in ipairs(g.worms) do
        if other ~= w and other.hp > 0 and math.abs(other.x - x) < 0.65 and math.abs(other.y - y) < 0.9 then
          return false, "Occupied"
        end
      end
      w.x, w.y = x, y
      collect(g, w)
    end
    w.facing = dir
    w.aim = dir == 1 and math.min(w.aim, 89) or math.max(w.aim, 91)
  elseif kind == "jump" then
    if w.airborne then
      return false, "Already jumping"
    end
    w.airborne, w.vx, w.vy = true, w.facing * 6, -11
    w.jumpStartY = w.y
    w.y = w.y - 0.4
  elseif kind == "setAim" then
    if type(action.angle) ~= "number" or action.angle ~= action.angle or action.angle < 0 or action.angle > 180 then
      return false, "Invalid aim angle"
    end
    w.aim = clamp(math.floor(action.angle + 0.5), 5, 175)
    w.facing = w.aim <= 90 and 1 or -1
  elseif kind == "aim" then
    if dir ~= -1 and dir ~= 1 then
      return false, "Invalid aim"
    end
    w.aim = clamp(w.aim + dir * 3, 5, 175)
    w.facing = w.aim <= 90 and 1 or -1
  elseif kind == "select" then
    local i = g.selected[team] or 0
    for _ = 1, #g.worms do
      i = i % #g.worms + 1
      if g.worms[i].team == team and g.worms[i].hp > 0 then
        g.selected[team] = i
        break
      end
    end
  elseif kind == "weapon" then
    w.weapon = w.weapon == 1 and w.mega > 0 and 2 or 1
  elseif kind == "pass" then
    nextTurn(g)
  else
    return false, "Unknown action"
  end
  return true
end

function S.tick(g, dt)
  if not g or g.phase ~= "playing" or type(dt) ~= "number" or dt < 0 or dt ~= dt then
    return false
  end
  dt = math.min(dt, 2)
  if dt == 0 then
    return false
  end
  -- Movement physics and turn clocks advance exclusively on the host.
  for _, w in ipairs(g.worms) do
    if w.hp > 0 and w.airborne then
      local newX = clamp(w.x + w.vx * dt, 2, S.W - 1)
      local newY = w.y + w.vy * dt
      w.vy = w.vy + 25 * dt
      if newY >= ground(g, newX) - 1 and w.vy >= 0 then
        w.x, w.y = newX, ground(g, newX) - 1
        w.airborne, w.vx, w.vy = false, nil, nil
        local fall = math.max(0, w.y - (w.jumpStartY or w.y))
        w.jumpStartY = nil
        if w.y >= S.H then
          w.hp = 0
        elseif fall > 4 then
          local damage = math.floor((fall - 4) * 6)
          if w.shield then
            damage = math.floor(damage / 2)
            w.shield = false
          end
          w.hp = math.max(0, w.hp - damage)
        end
        if w.hp > 0 then
          collect(g, w)
        end
      elseif newY > S.H + 1 then
        w.hp, w.airborne = 0, false
      else
        w.x, w.y = newX, newY
      end
    end
  end
  if g.state == "aim" and not alive(g, g.turn) then
    nextTurn(g)
    return true
  end
  if g.state == "aim" then
    g.turnLeft = math.max(0, g.turnLeft - dt)
    if g.charging then
      g.charge = math.min(1.8, g.charge + dt)
    end
    if g.turnLeft <= 0 then
      if g.charging then
        release(g, S.worm(g))
      else
        nextTurn(g)
      end
    end
  elseif g.state == "flight" then
    local p = g.projectile
    local substeps = math.max(1, math.ceil(dt / 0.025))
    local step = dt / substeps
    for _ = 1, substeps do
      if g.state ~= "flight" then
        break
      end
      p.x = p.x + p.vx * step
      p.y = p.y + p.vy * step
      p.vx = p.vx + g.wind * 0.55 * step
      p.vy = p.vy + 16 * step
      p.elapsed = p.elapsed + step
      local collide = p.y >= 1 and solid(g, p.x, p.y)
      for _, w in ipairs(g.worms) do
        if w.hp > 0 and (p.elapsed > 0.16 or w ~= S.worm(g)) then
          if (p.x - w.x) ^ 2 + (p.y - w.y) ^ 2 < 1.2 then
            collide = true
          end
        end
      end
      if collide then
        explode(g, p.x, p.y, p.weapon)
      elseif p.x <= 0 or p.x > S.W or p.y > S.H + 1 or p.elapsed > 10 then
        g.projectile, g.state = nil, "blast"
        g.explosion = { x = -100, y = -100, radius = 0, elapsed = 0 }
        g.message = "MISS!"
      end
    end
    if g.state == "flight" then
      g.trail[#g.trail + 1] = { x = p.x, y = p.y }
      if #g.trail > 18 then
        table.remove(g.trail, 1)
      end
    end
  elseif g.state == "blast" then
    g.explosion.elapsed = g.explosion.elapsed + dt
    if g.explosion.elapsed >= 0.85 then
      nextTurn(g)
    end
  end
  return true
end

S.solid, S.ground, S.alive, S.nextTurn = solid, ground, alive, nextTurn
return S
