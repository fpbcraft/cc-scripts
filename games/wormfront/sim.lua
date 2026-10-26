-- WORMFRONT: authoritative turn/weapon/rope simulation (CC:Tweaked / Lua 5.2).
local S = {}
S.W, S.H, S.TURN_SECONDS = 144, 60, 45
S.weapons = {
  { name = "BAZOOKA", kind = "rocket", radius = 5, damage = 45, unlimited = true },
  { name = "GRENADE", kind = "grenade", radius = 5, damage = 50, gift = 3 },
  { name = "DYNAMITE", kind = "dynamite", radius = 9, damage = 75, gift = 1 },
  { name = "BASEBALL BAT", kind = "bat", damage = 34, gift = 2 },
  { name = "AIR STRIKE", kind = "strike", radius = 4, damage = 24, gift = 1 },
  { name = "MINIGUN", kind = "minigun", damage = 9, gift = 1 },
  { name = "MINE", kind = "mine", radius = 6, damage = 60, gift = 2 },
  { name = "FIRE PUNCH", kind = "punch", damage = 38, gift = 2 },
  { name = "HANDGUN", kind = "handgun", damage = 20, gift = 3 },
  { name = "PETROL BOMB", kind = "petrol", radius = 4, damage = 22, gift = 2 },
}
local function clamp(n, a, b)
  return math.max(a, math.min(b, n))
end
local function rand(g, a, b)
  g.rng = (g.rng * 48271) % 2147483647
  local n = g.rng / 2147483647
  return a and a + math.floor(n * (b - a + 1)) or n
end
local function tile(g, x, y)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  if x < 1 or x > S.W or y < 1 or y > S.H then
    return "."
  end
  return g.terrain[x]:sub(y, y)
end
local function solid(g, x, y)
  local t = tile(g, x, y)
  return t == "#" or t == "="
end
local function floorAt(g, x, from)
  x = math.floor(x + 0.5)
  if x < 1 or x > S.W then
    return S.H + 1
  end
  for y = clamp(math.floor(from or 1), 1, S.H), S.H do
    if solid(g, x, y) then
      return y
    end
  end
  return S.H + 1
end
local function alive(g, team)
  for _, w in ipairs(g.worms) do
    if w.team == team and w.hp > 0 then
      return true
    end
  end
  return false
end
function S.worm(g)
  local w = g.worms[g.selected[g.turn] or 0]
  return w and w.hp > 0 and w.team == g.turn and w or nil
end
local function nextWorm(g, team)
  local previous = g.selected[team] or 0
  for offset = 1, #g.worms do
    local i = (previous + offset - 1) % #g.worms + 1
    local w = g.worms[i]
    if w.team == team and w.hp > 0 then
      g.selected[team] = i
      return
    end
  end
  g.selected[team] = nil
end
local function hurt(w, amount)
  if amount <= 0 or w.hp <= 0 then
    return
  end
  if w.shield then
    amount = math.floor(amount / 2)
    w.shield = false
  end
  w.hp = math.max(0, w.hp - amount)
end
local function acquire(g, w)
  for i = #g.items, 1, -1 do
    local item = g.items[i]
    if (w.x - item.x) ^ 2 + (w.y - item.y) ^ 2 <= 3.1 then
      if item.kind == "MEDKIT" then
        w.hp = math.min(100, w.hp + 30)
      elseif item.kind == "SHIELD" then
        w.shield = true
      else
        local weapon = item.weapon or 2
        g.inventory[w.team][weapon] = (g.inventory[w.team][weapon] or 0) + S.weapons[weapon].gift
        g.message = S.weapons[weapon].name .. " +" .. S.weapons[weapon].gift
      end
      table.remove(g.items, i)
    end
  end
end
local function crates(g)
  if #g.items >= 6 then
    return
  end
  for _ = 1, 60 do
    local x = rand(g, 6, S.W - 5)
    local y = floorAt(g, x) - 1
    local clear = y > 12 and y < S.H - 2
    for _, w in ipairs(g.worms) do
      if w.hp > 0 and math.abs(w.x - x) <= 2 then
        clear = false
      end
    end
    if clear then
      local typeRoll = rand(g, 1, 5)
      local item = { x = x, y = y }
      if typeRoll == 1 then
        item.kind = "MEDKIT"
      elseif typeRoll == 2 then
        item.kind = "SHIELD"
      else
        item.kind = "WEAPON"
        item.weapon = rand(g, 2, #S.weapons)
      end
      g.items[#g.items + 1] = item
      return
    end
  end
end
local function land(g, w, at)
  local old = w.jumpStartY or w.y
  w.y, w.airborne, w.vx, w.vy, w.jumpStartY = at, false, nil, nil, nil
  if at >= S.H then
    w.hp = 0
  else
    hurt(w, math.max(0, math.floor((at - old - 4) * 6)))
    if w.hp > 0 then
      acquire(g, w)
    end
  end
end
local function settle(g)
  for _, w in ipairs(g.worms) do
    if w.hp > 0 and not w.airborne and not w.rope then
      local at = floorAt(g, w.x, w.y + 0.2) - 1
      if at > w.y then
        land(g, w, at)
      end
    end
  end
  for i = #g.items, 1, -1 do
    local item = g.items[i]
    item.y = floorAt(g, item.x, item.y) - 1
    if item.y >= S.H then
      table.remove(g.items, i)
    end
  end
end
local function crater(g, cx, cy, radius)
  for x = math.max(1, math.floor(cx - radius)), math.min(S.W, math.ceil(cx + radius)) do
    local column, chars = g.terrain[x], {}
    for y = 1, S.H do
      chars[y] = (x - cx) ^ 2 + (y - cy) ^ 2 <= radius * radius and "." or column:sub(y, y)
    end
    g.terrain[x] = table.concat(chars)
  end
end
local function damage(g, x, y, radius, base)
  for _, w in ipairs(g.worms) do
    if w.hp > 0 then
      local distance = math.sqrt((x - w.x) ^ 2 + (y - w.y) ^ 2)
      hurt(w, math.floor(base * math.max(0, 1 - distance / (radius + 3))))
      if w.hp > 0 and distance < radius + 2 then
        w.airborne, w.rope = true, nil
        local strength = (radius + 2 - distance) / (radius + 2)
        w.vx = (w.x < x and -1 or 1) * strength * 10
        w.vy = -strength * 8
        w.jumpStartY = w.y
      end
    end
  end
end
local function blast(g, x, y, weapon)
  local spec = S.weapons[weapon]
  local radius = spec.radius or 3
  crater(g, x, y, radius)
  damage(g, x, y, radius, spec.damage)
  g.explosion = { x = x, y = y, radius = radius, elapsed = 0 }
  g.projectile, g.state = nil, "blast"
  g.message = spec.name .. " HIT"
  if spec.kind == "petrol" then
    g.fires[#g.fires + 1] = { x = x, y = floorAt(g, x, y) - 1, ttl = 4 }
  end
  settle(g)
end
local function finishTurn(g)
  local count, victor = 0, nil
  for team = 1, g.teams do
    if alive(g, team) then
      count, victor = count + 1, team
    end
  end
  if count < 2 then
    g.phase, g.winner, g.state = "finished", victor, "end"
    g.message = victor and "TEAM " .. victor .. " WINS!" or "DRAW!"
    return
  end
  repeat
    g.turn = g.turn % g.teams + 1
    if g.turn == 1 then
      g.round = g.round + 1
    end
  until alive(g, g.turn)
  nextWorm(g, g.turn)
  g.turnLeft, g.state, g.charging, g.charge = S.TURN_SECONDS, "aim", false, 0
  g.projectile, g.explosion, g.trail, g.target = nil, nil, {}, nil
  g.wind = rand(g, -3, 3)
  g.message = "TEAM " .. g.turn .. " TURN"
  if g.round % 2 == 0 then
    crates(g)
  end
end
local function startFlight(g, w)
  local spec = S.weapons[w.weapon]
  local a = math.rad(w.aim)
  local charged = clamp(g.charge / 1.8, 0.08, 1)
  local speed = 5.5 + 20 * charged
  if spec.kind == "grenade" or spec.kind == "petrol" then
    speed = speed * 0.75
  end
  g.projectile = {
    x = w.x + math.cos(a) * 2,
    y = w.y - math.sin(a) * 2,
    vx = math.cos(a) * speed,
    vy = -math.sin(a) * speed,
    weapon = w.weapon,
    ttl = spec.kind == "grenade" and 3 or spec.kind == "petrol" and 2.5 or 10,
    bounce = spec.kind == "grenade",
  }
  g.state, g.charging, g.trail = "flight", false, {}
end
local function strike(g, w)
  local spec = S.weapons[w.weapon]
  local angle = math.rad(w.aim)
  if spec.kind == "strike" then
    local center = clamp(g.target or w.x + w.facing * 22, 4, S.W - 4)
    for i = -2, 2 do
      local x = clamp(center + i * 3, 1, S.W)
      local y = floorAt(g, x) - 1
      crater(g, x, y, spec.radius)
      damage(g, x, y, spec.radius, spec.damage)
    end
    settle(g)
    g.explosion = { x = center, y = floorAt(g, center) - 1, radius = 9, elapsed = 0 }
  elseif spec.kind == "bat" or spec.kind == "punch" then
    local reach = spec.kind == "bat" and 5 or 4
    for _, enemy in ipairs(g.worms) do
      if enemy.hp > 0 and enemy ~= w and (enemy.x - w.x) * w.facing > 0
        and math.abs(enemy.x - w.x) <= reach and math.abs(enemy.y - w.y) <= 3 then
        hurt(enemy, spec.damage)
        if enemy.hp > 0 then
          enemy.rope, enemy.airborne, enemy.jumpStartY = nil, true, enemy.y
          enemy.vx = w.facing * (spec.kind == "bat" and 20 or 12)
          enemy.vy = spec.kind == "punch" and -15 or -7
        end
      end
    end
    g.explosion = { x = w.x + w.facing * 3, y = w.y - 2, radius = 2, elapsed = 0 }
  else
    local shots = spec.kind == "minigun" and 8 or 2
    for i = 1, shots do
      local spread = spec.kind == "minigun" and (i - 4.5) * 0.045 or (i - 1.5) * 0.025
      local vx, vy = math.cos(angle + spread), -math.sin(angle + spread)
      for d = 1, 45 do
        local x = w.x + vx * d
        local y = w.y + vy * d
        if solid(g, x, y) then
          break
        end
        local hit
        for _, enemy in ipairs(g.worms) do
          if enemy ~= w and enemy.hp > 0 and (enemy.x - x) ^ 2 + (enemy.y - y) ^ 2 < 1.7 then
            hurt(enemy, spec.damage)
            hit = true
            break
          end
        end
        if hit then
          break
        end
      end
    end
    g.explosion = { x = w.x + vx * 2, y = w.y - 2, radius = 1.5, elapsed = 0 }
  end
  g.state, g.charging = "blast", false
end
function S.new(teams, seed)
  assert(type(teams) == "number" and teams >= 2 and teams <= 4, "Expected 2-4 teams")
  local g = {
    version = 3, teams = teams, seed = math.floor(tonumber(seed) or 1), terrain = {},
    worms = {}, selected = {}, inventory = {}, items = {}, mines = {}, fires = {},
    phase = "playing", state = "aim", turn = 1, round = 1, turnLeft = S.TURN_SECONDS,
    charge = 0, charging = false, trail = {}, wind = 0, message = "FIND A WEAPON CRATE",
  }
  g.rng = g.seed % 2147483646 + 1
  g.theme = rand(g, 1, 4)
  local height = rand(g, 38, 48)
  local phase = rand(g) * 6.28
  for x = 1, S.W do
    local y = clamp(math.floor(height + math.sin(x * 0.068 + phase) * 7
      + math.cos(x * 0.19 + phase) * 3 + rand(g, -1, 1)), 30, 54)
    g.terrain[x] = ("."):rep(y - 1) .. ("#"):rep(S.H - y + 1)
  end
  -- Suspended destructible platforms, apart from guaranteed ground spawn.
  for _ = 1, 10 do
    local x0, span = rand(g, 8, S.W - 23), rand(g, 8, 17)
    local y = rand(g, 19, 33)
    for x = x0, x0 + span do
      local col = g.terrain[x]
      if col:sub(y, y) == "." then
        g.terrain[x] = col:sub(1, y - 1) .. "=" .. col:sub(y + 1)
      end
    end
  end
  for team = 1, teams do
    g.inventory[team] = { [1] = -1 }
    for n = 1, 3 do
      local pos = (n - 1) * teams + team
      local x = clamp(math.floor(pos * (S.W - 12) / (teams * 3 + 1)) + 6, 3, S.W - 2)
      g.worms[#g.worms + 1] = {
        team = team, x = x, y = floorAt(g, x, 36) - 1, hp = 100,
        aim = team % 2 == 1 and 45 or 135, facing = team % 2 == 1 and 1 or -1,
        weapon = 1, airborne = false,
      }
      if n == 1 then
        g.selected[team] = #g.worms
      end
    end
  end
  g.wind = rand(g, -3, 3)
  for _ = 1, 4 do
    crates(g)
  end
  return g
end
local function reel(w, dir)
  w.rope.length = clamp(w.rope.length + dir * 2, 3, 40)
end
local function attach(g, w, x, y)
  local dx, dy = x - w.x, y - w.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 3 or dist > 44 then
    return false, "Rope out of range"
  end
  local anchor
  for i = 1, math.floor(dist * 4) do
    local t = i / (dist * 4)
    local px, py = w.x + dx * t, w.y + dy * t
    if solid(g, px, py) then
      anchor = { x = px, y = py }
      break
    end
  end
  if not anchor then
    return false, "Aim rope at terrain"
  end
  local length = math.sqrt((w.x - anchor.x) ^ 2 + (w.y - anchor.y) ^ 2)
  w.rope = { x = anchor.x, y = anchor.y, length = length }
  w.airborne, w.vx, w.vy, w.jumpStartY = true, w.vx or 0, w.vy or 0, w.y
  return true
end
function S.apply(g, team, action)
  if type(g) ~= "table" or g.phase ~= "playing" then
    return false, "Match not active"
  end
  if team ~= g.turn or type(action) ~= "table" then
    return false, "Not your turn"
  end
  if g.state ~= "aim" then
    return false, "Shot in progress"
  end
  local w = S.worm(g)
  if not w then
    return false, "No living worm"
  end
  local kind, dir = action.kind, action.dir
  if kind == "select" then
    return false, "Worm selection is automatic"
  elseif kind == "weapon" then
    local id = action.id
    if id == nil then
      id = w.weapon
      for _ = 1, #S.weapons do
        id = id % #S.weapons + 1
        if (g.inventory[team][id] or 0) ~= 0 then
          break
        end
      end
    end
    if type(id) ~= "number" or id % 1 ~= 0 or not S.weapons[id] or (g.inventory[team][id] or 0) == 0 then
      return false, "Weapon unavailable"
    end
    w.weapon = id
    return true
  elseif kind == "setTarget" then
    if type(action.x) ~= "number" or action.x ~= action.x or action.x == math.huge then
      return false, "Invalid strike target"
    end
    g.target = clamp(math.floor(action.x), 1, S.W)
    return true
  elseif kind == "rope" then
    if w.rope then
      w.rope = nil
      return true
    end
    local x, y = action.x, action.y
    if x == nil then
      local a = math.rad(w.aim)
      x, y = w.x + math.cos(a) * 40, w.y - math.sin(a) * 40
    end
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then
      return false, "Invalid rope target"
    end
    return attach(g, w, x, y)
  elseif kind == "reel" then
    if not w.rope or (dir ~= -1 and dir ~= 1) then
      return false, "No rope"
    end
    reel(w, dir)
    return true
  elseif kind == "move" then
    if dir ~= -1 and dir ~= 1 then
      return false, "Invalid direction"
    end
    w.facing = dir
    if w.airborne then
      w.vx = clamp((w.vx or 0) + dir * (w.rope and 2.2 or 3), -15, 15)
    else
      local x = w.x + dir
      local y = floorAt(g, x, w.y - 2) - 1
      if x < 2 or x >= S.W or y >= S.H or math.abs(y - w.y) > 2 then
        return false, "Blocked"
      end
      w.x, w.y = x, y
      acquire(g, w)
    end
    return true
  elseif kind == "jump" then
    if w.rope then
      w.rope = nil
      return true
    end
    if w.airborne then
      return false, "Already airborne"
    end
    w.airborne, w.vx, w.vy, w.jumpStartY = true, w.facing * 7, -13, w.y
    w.y = w.y - 0.5
    return true
  elseif kind == "aim" or kind == "setAim" then
    if g.charging then
      return false, "Release shot"
    end
    if kind == "aim" then
      if dir ~= -1 and dir ~= 1 then
        return false, "Invalid aim"
      end
      w.aim = clamp(w.aim + dir * 3, 5, 175)
    else
      local a = action.angle
      if type(a) ~= "number" or a ~= a or a < 0 or a > 180 then
        return false, "Invalid aim"
      end
      w.aim = clamp(math.floor(a), 5, 175)
    end
    w.facing = w.aim <= 90 and 1 or -1
    return true
  elseif kind == "pass" then
    finishTurn(g)
    return true
  elseif kind == "charge" or kind == "fire" then
    if g.charging then
      kind = "release"
    else
      if w.airborne then
        return false, "Land first"
      end
      if (g.inventory[team][w.weapon] or 0) == 0 then
        return false, "Out of ammunition"
      end
      g.charging, g.charge = true, 0
      return true
    end
  end
  if kind == "release" then
    if not g.charging then
      return false, "Not charging"
    end
    if (g.inventory[team][w.weapon] or 0) == 0 then
      return false, "Out of ammunition"
    end
    if g.inventory[team][w.weapon] > 0 then
      g.inventory[team][w.weapon] = g.inventory[team][w.weapon] - 1
    end
    local spec = S.weapons[w.weapon]
    if spec.kind == "rocket" or spec.kind == "grenade" or spec.kind == "petrol" then
      startFlight(g, w)
    elseif spec.kind == "dynamite" then
      g.projectile = { x = w.x + w.facing * 2, y = w.y - 1, vx = w.facing * 2, vy = 0, ttl = 3, weapon = w.weapon, bounce = true }
      g.state, g.charging = "flight", false
    elseif spec.kind == "mine" then
      g.mines[#g.mines + 1] = { x = w.x + w.facing * 2, y = floorAt(g, w.x + w.facing * 2) - 1, team = team, arm = 0.6 }
      g.state, g.charging = "blast", false
      g.explosion = { x = -100, y = -100, radius = 0, elapsed = 0 }
    else
      strike(g, w)
    end
    w.rope = nil
    return true
  end
  return false, "Unknown action"
end
local function physics(g, dt)
  local step = math.min(dt, 0.07)
  for _, w in ipairs(g.worms) do
    if w.hp > 0 and w.airborne then
      local vx, vy = w.vx or 0, w.vy or 0
      local x = clamp(w.x + vx * step, 2, S.W - 1)
      local y = w.y + vy * step
      vy = vy + 25 * step
      if w.rope then
        local rope = w.rope
        local dx, dy = x - rope.x, y - rope.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > rope.length then
          local nx, ny = dx / dist, dy / dist
          x, y = rope.x + nx * rope.length, rope.y + ny * rope.length
          local radial = vx * nx + vy * ny
          if radial > 0 then
            vx, vy = vx - radial * nx, vy - radial * ny
          end
        end
        if not solid(g, rope.x, rope.y) then
          w.rope = nil
        end
      end
      local floor = floorAt(g, x, w.y + 0.3) - 1
      if not w.rope and vy >= 0 and y >= floor and w.y <= floor + 0.5 then
        w.x = x
        land(g, w, floor)
      elseif y > S.H + 2 then
        w.hp, w.rope, w.airborne = 0, nil, false
      elseif not solid(g, x, y) then
        w.x, w.y, w.vx, w.vy = x, y, vx * 0.99, vy
        acquire(g, w)
      else
        w.vx, w.vy = 0, 0
      end
    end
  end
end
local function projectile(g, dt)
  local p = g.projectile
  if not p then
    return
  end
  local spec = S.weapons[p.weapon]
  local steps = math.max(1, math.ceil(dt / 0.025))
  local delta = dt / steps
  for _ = 1, steps do
    if g.state ~= "flight" then
      break
    end
    p.x, p.y = p.x + p.vx * delta, p.y + p.vy * delta
    p.vx, p.vy = p.vx + g.wind * 0.65 * delta, p.vy + 17 * delta
    p.ttl = p.ttl - delta
    local hit = p.y > 0 and solid(g, p.x, p.y)
    for _, w in ipairs(g.worms) do
      if w.hp > 0 and (w ~= S.worm(g) or p.ttl < 2.7) and (w.x - p.x) ^ 2 + (w.y - p.y) ^ 2 < 1.5 then
        hit = true
      end
    end
    if hit then
      if p.bounce and p.ttl > 0 then
        p.y = p.y - 1
        p.vy = -math.abs(p.vy) * 0.4
        p.vx = p.vx * 0.75
      else
        blast(g, p.x, p.y, p.weapon)
      end
    elseif p.ttl <= 0 then
      blast(g, p.x, math.min(p.y, S.H - 1), p.weapon)
    elseif p.x <= 0 or p.x >= S.W or p.y > S.H + 2 then
      g.state, g.projectile = "blast", nil
      g.explosion = { x = -100, y = -100, radius = 0, elapsed = 0 }
    end
  end
  if g.projectile then
    g.trail[#g.trail + 1] = { x = p.x, y = p.y }
    if #g.trail > 15 then
      table.remove(g.trail, 1)
    end
  end
end
function S.tick(g, dt)
  if not g or g.phase ~= "playing" or type(dt) ~= "number" or dt ~= dt or dt <= 0 then
    return false
  end
  dt = math.min(dt, 0.4)
  local segments = math.max(1, math.ceil(dt / 0.06))
  for _ = 1, segments do
    local step = dt / segments
    physics(g, step)
    for i = #g.fires, 1, -1 do
      local fire = g.fires[i]
      fire.ttl = fire.ttl - step
      for _, w in ipairs(g.worms) do
        if w.hp > 0 and math.abs(w.x - fire.x) < 3 and math.abs(w.y - fire.y) < 3 then
          w.burn = (w.burn or 0) + step
          if w.burn >= 0.5 then
            hurt(w, 4)
            w.burn = 0
          end
        end
      end
      if fire.ttl <= 0 then
        table.remove(g.fires, i)
      end
    end
    for i = #g.mines, 1, -1 do
      local mine = g.mines[i]
      mine.arm = math.max(0, mine.arm - step)
      if mine.arm == 0 then
        for _, w in ipairs(g.worms) do
          if w.hp > 0 and (w.x - mine.x) ^ 2 + (w.y - mine.y) ^ 2 < 9 then
            blast(g, mine.x, mine.y, 7)
            table.remove(g.mines, i)
            break
          end
        end
      end
    end
    if g.state == "aim" then
      if not alive(g, g.turn) then
        finishTurn(g)
      else
        g.turnLeft = math.max(0, g.turnLeft - step)
        if g.charging then
          g.charge = math.min(1.8, g.charge + step)
        end
        if g.turnLeft == 0 then
          finishTurn(g)
        end
      end
    elseif g.state == "flight" then
      projectile(g, step)
    elseif g.state == "blast" then
      g.explosion.elapsed = g.explosion.elapsed + step
      if g.explosion.elapsed >= 0.85 then
        finishTurn(g)
      end
    end
  end
  return true
end
S.solid, S.ground, S.floorAt, S.nextTurn = solid, ground, floorAt, finishTurn
return S
