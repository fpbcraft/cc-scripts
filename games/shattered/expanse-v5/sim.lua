-- SHATTERED v5: deterministic, renderer-free four-civilization strategy engine.
local root = _G.EXPANSE_V5_ROOT or "/games/shattered/expanse-v5"
local C = dofile(root .. "/content.lua")
local E = dofile(root .. "/events.lua")
local M = { VERSION = 5, content = C, events = E }
local function clamp(n, a, b)
  return math.max(a, math.min(b, n))
end
local function rnd(g, n)
  g.rng = (g.rng * 48271) % 2147483647
  return n and (1 + math.floor(g.rng / 2147483647 * n)) or g.rng / 2147483647
end
local function push(g, txt)
  table.insert(g.log, 1, "Y" .. g.round .. " " .. txt)
  while #g.log > 90 do
    table.remove(g.log)
  end
end
M.push = push
local function key(a, b, t)
  return math.min(a, b) .. ":" .. math.max(a, b) .. ":" .. t
end
local function linked(g, a, b)
  for _, edge in ipairs(g.links) do
    if (edge[1] == a and edge[2] == b) or (edge[1] == b and edge[2] == a) then
      return true
    end
  end
  return false
end
local function neighbors(g, id)
  local n = {}
  for _, edge in ipairs(g.links) do
    if edge[1] == id then
      n[#n + 1] = edge[2]
    elseif edge[2] == id then
      n[#n + 1] = edge[1]
    end
  end
  return n
end
M.neighbors = neighbors
M.linked = linked
function M.current(g)
  return g.order[g.turnIndex]
end
function M.atWar(g, a, b)
  return g.wars[key(a, b, "war")] == true
end
function M.hasPact(g, a, b, t)
  return g.pacts[key(a, b, t)] == true
end
function M.owned(g, p)
  local n = 0
  for _, s in ipairs(g.systems) do
    if s.owner == p then
      n = n + 1
    end
  end
  return n
end
function M.colonies(g, p)
  local n = 0
  for _, s in ipairs(g.systems) do
    if s.owner == p and s.colony then
      n = n + 1
    end
  end
  return n
end
function M.nearBorder(g, id, p)
  for _, n in ipairs(neighbors(g, id)) do
    if g.systems[n].owner == p then
      return true
    end
  end
  return false
end
function M.findShip(g, id)
  for _, s in ipairs(g.ships) do
    if s.id == id then
      return s
    end
  end
end
function M.shipsAt(g, id, p)
  local out = {}
  for _, s in ipairs(g.ships) do
    if s.location == id and (p == nil or s.owner == p) then
      out[#out + 1] = s
    end
  end
  return out
end
local function spend(f, cost)
  for k, v in pairs(cost) do
    if (f[k] or 0) < v then
      return false, "NEED " .. (v - (f[k] or 0)) .. " MORE " .. k:upper()
    end
  end
  for k, v in pairs(cost) do
    f[k] = f[k] - v
  end
  return true
end
local function relation(g, a, b)
  return g.factions[a].relations[b] or 0
end
M.relation = relation
local function trust(g, a, b, delta)
  if a == b then
    return
  end
  for _, pair in ipairs({ { a, b }, { b, a } }) do
    local f = g.factions[pair[1]]
    f.relations[pair[2]] = clamp((f.relations[pair[2]] or 0) + delta, -100, 100)
  end
end
local function chart(g, p, id)
  local f = g.factions[p]
  if f.seen[id] then
    return false
  end
  f.seen[id] = true
  f.charted[id] = true
  for _, other in ipairs(neighbors(g, id)) do
    f.charted[other] = true
  end
  return true
end
local function enqueue(g, p, id, system, delay)
  local f = g.factions[p]
  if not E.catalog[id] then
    return
  end
  if delay and delay > 0 then
    f.deferred[#f.deferred + 1] = { id = id, system = system, due = g.round + delay }
  else
    f.events[#f.events + 1] = E.create(id, system)
  end
end
local function explore(g, p, id)
  local f = g.factions[p]
  local s = g.systems[id]
  local first = chart(g, p, id)
  if not first then
    return
  end
  if f.archetype == 3 then
    f.knowledge = f.knowledge + 2
  end
  if s.kind == "RELIC" or s.kind == "RIFT" then
    f.clues = f.clues + 1
  end
  if s.kind == "RELIC" and f.tech.exploration >= 2 then
    f.knowledge = f.knowledge + 6
  end
  local context = (s.kind == "RELIC" and "relic") or (s.kind == "RIFT" and "rift") or "general"
  local pool = {}
  for eventId, data in pairs(E.catalog) do
    if
      not f.storySeen[eventId]
      and data.context ~= "chain"
      and (data.context == context or data.context == "general")
    then
      pool[#pool + 1] = eventId
    end
  end
  table.sort(pool)
  if #pool > 0 and rnd(g, 100) <= (s.kind == "RELIC" and 80 or 34) and #f.events < 3 then
    local which = pool[rnd(g, #pool)]
    f.storySeen[which] = true
    enqueue(g, p, which, id)
    push(g, f.name .. " discovers " .. E.catalog[which].title)
  end
  if f.tech.exploration >= 1 then
    for _, n in ipairs(neighbors(g, id)) do
      f.charted[n] = true
    end
  end
end
local function mkShip(g, p, kind, id)
  g.shipSeq = g.shipSeq + 1
  local s =
    { id = g.shipSeq, owner = p, kind = kind, location = id, orders = 2, name = C.ships[kind].name .. " " .. g.shipSeq }
  g.ships[#g.ships + 1] = s
  return s
end
function M.new(cfg)
  cfg = cfg or {}
  local seed = math.max(1, math.floor(tonumber(cfg.seed) or 10937) % 2147483646)
  local g = {
    version = 5,
    round = 1,
    limit = cfg.rounds or 20,
    rng = seed,
    systems = {},
    links = {},
    factions = {},
    ships = {},
    shipSeq = 0,
    order = { 1, 2, 3, 4 },
    turnIndex = 1,
    pacts = {},
    wars = {},
    log = {},
    ended = false,
    winner = nil,
    winReason = nil,
    results = nil,
  }
  for id = 1, 30 do
    local column = (id - 1) % 6
    local row = math.floor((id - 1) / 6)
    local x = 0.075 + 0.85 * column / 5 + (rnd(g) - 0.5) * 0.025
    local y = 0.09 + 0.82 * row / 4 + (rnd(g) - 0.5) * 0.03
    local typeId = C.systemTypes[rnd(g, #C.systemTypes)].id
    g.systems[id] = {
      id = id,
      name = C.names[id],
      x = x,
      y = y,
      kind = typeId,
      owner = 0,
      colony = false,
      focus = nil,
      level = 0,
      focusedYear = 0,
    }
    if column > 0 then
      g.links[#g.links + 1] = { id - 1, id }
    end
    if row > 0 then
      g.links[#g.links + 1] = { id - 6, id }
    end
  end
  local capitals = { 1, 6, 25, 30 }
  for p = 1, 4 do
    local origin = capitals[p]
    local fSpec
    local archetype = (cfg.archetypes and cfg.archetypes[p]) or p
    archetype = clamp(math.floor(archetype), 1, 4)
    fSpec = C.factions[archetype]
    local f = {
      id = p,
      name = (cfg.names and cfg.names[p]) or fSpec.name,
      archetype = archetype,
      human = (cfg.humans and cfg.humans[p]) == true,
      credits = 24,
      alloy = 22,
      knowledge = 9,
      tech = { exploration = 0, prosperity = 0, warfare = 0 },
      seen = {},
      charted = {},
      events = {},
      deferred = {},
      storySeen = {},
      ethics = {},
      relations = {},
      lastOffer = {},
      prestige = 0,
      project = nil,
      history = {},
      home = origin,
      proposalCount = 0,
      clues = 0,
    }
    for q = 1, 4 do
      if q ~= p then
        f.relations[q] = 10
      end
    end
    g.factions[p] = f
    local s = g.systems[origin]
    s.owner = p
    s.colony = true
    s.focus = ({ "industry", "science", "science", "commerce" })[p]
    s.level = 1
    chart(g, p, origin)
    mkShip(g, p, "scout", origin)
    mkShip(g, p, "ark", origin)
    mkShip(g, p, "fleet", origin)
  end
  push(g, "Four successor civilizations enter the Shattered Expanse.")
  return g
end
function M.income(g, p)
  local out = { credits = 4, alloy = 3, knowledge = 2 }
  local f = g.factions[p]
  for _, s in ipairs(g.systems) do
    if s.owner == p and s.colony then
      out.credits = out.credits + 1
      out.alloy = out.alloy + 1
      out.knowledge = out.knowledge + 1
      local type = s.focus or "commerce"
      local primary = type == "industry" and "alloy" or type == "science" and "knowledge" or "credits"
      local bonus = 4 + math.max(0, s.level - 1) * 2
      if
        (s.kind == "FORGE" and type == "industry")
        or (s.kind == "RELIC" and type == "science")
        or (s.kind == "GARDEN" and type == "commerce")
      then
        bonus = bonus + 2
      end
      if type == "commerce" and f.archetype == 4 then
        bonus = bonus + 2
      end
      if type == "commerce" and f.tech.prosperity >= 1 then
        bonus = bonus + 2
      end
      if f.tech.prosperity >= 3 then
        bonus = bonus + 1
      end
      out[primary] = out[primary] + bonus
    elseif s.owner == p then
      out.alloy = out.alloy + 1
    end
  end
  for q = 1, 4 do
    if q ~= p and M.hasPact(g, p, q, "trade") then
      out.credits = out.credits + 2
    end
  end
  return out
end
function M.score(g, p)
  local f = g.factions[p]
  local tech = f.tech
  local diplomacy = 0
  for q = 1, 4 do
    if q ~= p then
      if M.hasPact(g, p, q, "alliance") then
        diplomacy = diplomacy + 18
      elseif M.hasPact(g, p, q, "trade") then
        diplomacy = diplomacy + 5
      end
    end
  end
  return M.owned(g, p) * 7
    + M.colonies(g, p) * 8
    + (tech.exploration + tech.prosperity + tech.warfare) * 6
    + f.prestige * 2
    + math.floor((f.credits + f.alloy + f.knowledge) / 9)
    + diplomacy
end
function M.winProgress(g, p)
  local f = g.factions[p]
  local allies = 0
  for q = 1, 4 do
    if q ~= p and M.hasPact(g, p, q, "alliance") then
      allies = allies + 1
    end
  end
  return {
    discovery = f.tech.exploration >= 3 and (f.project and f.project.type == "discovery" and f.project.progress or 0)
      or f.tech.exploration,
    unity = allies,
    dominion = M.owned(g, p),
    alliances = allies,
  }
end
local function checkWin(g)
  for p = 1, 4 do
    local f = g.factions[p]
    if M.owned(g, p) >= 15 then
      g.ended = true
      g.winner = p
      g.winReason = "DOMINION"
      return
    end
    if f.completed == "discovery" or f.completed == "unity" then
      g.ended = true
      g.winner = p
      g.winReason = f.completed:upper()
      return
    end
  end
end
M.checkWin = checkWin
local function spendTest(f, cost)
  for k, n in pairs(cost) do
    if (f[k] or 0) < n then
      return false, "NEED " .. n .. " " .. k:upper()
    end
  end
  return true
end
function M.can(g, p, action, a)
  a = a or {}
  if g.ended then
    return false, "CAMPAIGN COMPLETED"
  end
  if p ~= M.current(g) then
    return false, "NOT YOUR COMMAND PHASE"
  end
  local f = g.factions[p]
  if #f.events > 0 and action ~= "choose" then
    return false, "RESOLVE YOUR COUNCIL EVENT FIRST"
  end
  if action == "choose" then
    local e = f.events[1]
    if not e then
      return false, "NO PENDING EVENT"
    end
    local choice = e.choices[a.choice or 0]
    if not choice then
      return false, "SELECT A VALID CHOICE"
    end
    for k, v in pairs(choice.effect) do
      if (k == "credits" or k == "alloy" or k == "knowledge") and v < 0 and f[k] < -v then
        return false, "NEED " .. -v .. " " .. k:upper()
      end
    end
    return true
  elseif action == "move" then
    local sh = M.findShip(g, a.ship)
    if not sh or sh.owner ~= p then
      return false, "SELECT YOUR SHIP"
    end
    if sh.orders < 1 then
      return false, "SHIP HAS NO ORDERS LEFT"
    end
    local s = g.systems[a.system or 0]
    if not s or not linked(g, sh.location, s.id) then
      return false, "DESTINATION MUST BE A LINKED STAR"
    end
    if s.owner ~= 0 and s.owner ~= p then
      if not M.atWar(g, p, s.owner) then
        return false, "DECLARE WAR BEFORE ENTERING RIVAL TERRITORY"
      end
      if sh.kind ~= "fleet" then
        return false, "ONLY FLEETS MAY ENTER ENEMY SYSTEMS"
      end
    end
    return true
  elseif action == "colonize" then
    local sh = M.findShip(g, a.ship)
    if not sh or sh.owner ~= p or sh.kind ~= "ark" then
      return false, "SELECT A COLONY ARK"
    end
    if sh.orders < 1 then
      return false, "ARK HAS NO ORDERS LEFT"
    end
    local s = g.systems[sh.location]
    if s.owner ~= 0 then
      return false, "TARGET SYSTEM IS ALREADY CLAIMED"
    end
    if not f.seen[s.id] then
      return false, "SCOUT THE SYSTEM FIRST"
    end
    if not M.nearBorder(g, s.id, p) then
      return false, "COLONIES MUST TOUCH YOUR TERRITORY"
    end
    return spendTest(f, { alloy = 12, credits = 8 })
  elseif action == "focus" or action == "upgrade" then
    local s = g.systems[a.system or 0]
    if not s or s.owner ~= p or not s.colony then
      return false, "SELECT ONE OF YOUR COLONIES"
    end
    if s.focusedYear == g.round then
      return false, "COLONY ALREADY DEVELOPED THIS YEAR"
    end
    if action == "focus" then
      if not C.focus[a.focus] then
        return false, "CHOOSE A VALID SPECIALIZATION"
      end
      if s.focus == a.focus then
        return false, "ALREADY SPECIALIZED HERE"
      end
      return spendTest(f, { credits = 7 })
    end
    if s.level >= 3 then
      return false, "COLONY AT MAX DEVELOPMENT"
    end
    return spendTest(f, { credits = 9, alloy = 8 })
  elseif action == "build_ship" then
    local s = g.systems[a.system or 0]
    if not s or s.owner ~= p or not s.colony then
      return false, "BUILD AT AN OWNED COLONY"
    end
    local ship = C.ships[a.kind]
    if not ship then
      return false, "UNKNOWN SHIP ROLE"
    end
    local cost = { credits = ship.cost.credits, alloy = ship.cost.alloy }
    if f.archetype == 1 and a.kind == "fleet" then
      cost.alloy = cost.alloy - 1
    end
    return spendTest(f, cost)
  elseif action == "research" then
    local path = C.tech[a.path]
    if not path then
      return false, "UNKNOWN RESEARCH PATH"
    end
    local nextLevel = f.tech[a.path] + 1
    if nextLevel > 3 then
      return false, "PATH ALREADY COMPLETE"
    end
    return spendTest(f, { knowledge = path[nextLevel].cost })
  elseif action == "pact" then
    local target = a.to
    if type(target) ~= "number" or target == p or target < 1 or target > 4 then
      return false, "SELECT A RIVAL EMPIRE"
    end
    if not C.pacts[a.kind] then
      return false, "UNKNOWN TREATY"
    end
    if M.atWar(g, p, target) then
      return false, "MAKE PEACE BEFORE NEGOTIATING"
    end
    if M.hasPact(g, p, target, a.kind) then
      return false, "TREATY ALREADY ACTIVE"
    end
    if f.lastOffer[target] == g.round then
      return false, "YOU ALREADY SENT AN ENVOY THIS YEAR"
    end
    if a.kind == "alliance" and not M.hasPact(g, p, target, "nonaggression") then
      return false, "SIGN NON-AGGRESSION FIRST"
    end
    return spendTest(f, { credits = 3 })
  elseif action == "war" then
    local target = a.to
    if type(target) ~= "number" or target == p or target < 1 or target > 4 then
      return false, "SELECT ANOTHER EMPIRE"
    end
    if M.atWar(g, p, target) then
      return false, "YOU ARE ALREADY AT WAR"
    end
    return spendTest(f, { credits = 5 })
  elseif action == "peace" then
    local target = a.to
    if type(target) ~= "number" or target == p or target < 1 or target > 4 or not M.atWar(g, p, target) then
      return false, "YOU ARE NOT AT WAR"
    end
    if f.lastOffer[target] == g.round then
      return false, "ONE PROPOSAL PER EMPIRE PER YEAR"
    end
    return true
  elseif action == "reply" then
    if not f.offers or #f.offers < 1 then
      return false, "NO PENDING PROPOSAL"
    end
    return true
  elseif action == "project" then
    if f.project then
      return false, "PROJECT ALREADY UNDERWAY"
    end
    if a.kind == "discovery" then
      if f.tech.exploration < 3 then
        return false, "REQUIRES EXPLORATION LEVEL 3"
      end
      local seen = 0
      for _ in pairs(f.seen) do
        seen = seen + 1
      end
      if seen < 14 or f.clues < 3 then
        return false, "NEED 14 SURVEYED SYSTEMS AND THREE ANCIENT CLUES"
      end
      if M.colonies(g, p) < 3 then
        return false, "NEED THREE COLONIES TO HOST THE ARCHIVE"
      end
      return spendTest(f, { credits = 25, alloy = 15, knowledge = 18 })
    elseif a.kind == "unity" then
      local count = 0
      for q = 1, 4 do
        if q ~= p and M.hasPact(g, p, q, "alliance") then
          count = count + 1
        end
      end
      if count < 2 or f.tech.prosperity < 2 then
        return false, "NEED TWO ALLIANCES AND PROSPERITY 2"
      end
      if M.colonies(g, p) < 4 then
        return false, "NEED FOUR COLONIES TO HOST THE COUNCIL"
      end
      return spendTest(f, { credits = 30, alloy = 12, knowledge = 12 })
    end
    return false, "UNKNOWN VICTORY PROJECT"
  end
  return false, "UNKNOWN ORDER"
end
function M.command(g, p, action, a)
  a = a or {}
  local valid, why = M.can(g, p, action, a)
  if not valid then
    return false, why
  end
  local f = g.factions[p]
  if action == "choose" then
    local e = table.remove(f.events, 1)
    local choice = e.choices[a.choice]
    local eff = choice.effect
    for k, v in pairs(eff) do
      if k == "credits" or k == "alloy" or k == "knowledge" then
        f[k] = math.max(0, f[k] + v)
      end
    end
    if eff.trust then
      for q = 1, 4 do
        if q ~= p then
          trust(g, p, q, eff.trust)
        end
      end
    end
    if eff.ethic then
      f.ethics[eff.ethic] = (f.ethics[eff.ethic] or 0) + 1
    end
    if choice.follow then
      enqueue(g, p, choice.follow.id, e.system, choice.follow.delay)
    end
    f.prestige = f.prestige + 1
    push(g, f.name .. ": " .. choice.title)
  elseif action == "move" then
    local sh = M.findShip(g, a.ship)
    local target = g.systems[a.system]
    sh.orders = sh.orders - 1
    if target.owner ~= 0 and target.owner ~= p then
      local strength = C.ships[sh.kind].power
        + (f.tech.warfare >= 1 and 2 or 0)
        + (f.tech.warfare >= 2 and 2 or 0)
        + (f.archetype == 1 and 1 or 0)
      local enemies = M.shipsAt(g, target.id, target.owner)
      local defense = (target.colony and 3 or 1) + (g.factions[target.owner].tech.warfare >= 3 and 3 or 0)
      for _, enemy in ipairs(enemies) do
        if enemy.kind == "fleet" then
          defense = defense + 5 + (g.factions[target.owner].tech.warfare >= 1 and 2 or 0)
        end
      end
      local attack = strength + rnd(g, 4)
      local protect = defense + rnd(g, 4)
      if attack >= protect then
        for i = #g.ships, 1, -1 do
          if g.ships[i].location == target.id and g.ships[i].owner == target.owner then
            table.remove(g.ships, i)
          end
        end
        target.owner = p
        target.colony = false
        target.focus = nil
        target.level = 0
        sh.location = target.id
        push(g, f.name .. " captures " .. target.name)
        for q = 1, 4 do
          if q ~= p and q ~= a.target then
            trust(g, p, q, -2)
          end
        end
      else
        for i = #g.ships, 1, -1 do
          if g.ships[i] == sh then
            table.remove(g.ships, i)
            break
          end
        end
        push(g, f.name .. " loses a fleet at " .. target.name)
      end
    else
      sh.location = target.id
    end
    if sh.kind == "scout" then
      explore(g, p, target.id)
    end
    if target.owner == p then
      chart(g, p, target.id)
    end
  elseif action == "colonize" then
    local sh = M.findShip(g, a.ship)
    local s = g.systems[sh.location]
    spend(f, { credits = 8, alloy = 12 })
    s.owner = p
    s.colony = true
    s.focus = "industry"
    s.level = 1
    s.focusedYear = g.round
    sh.orders = sh.orders - 1
    push(g, f.name .. " settles " .. s.name)
    -- An Ark is a permanent investment; it is consumed when establishing the colony.
    for i = #g.ships, 1, -1 do
      if g.ships[i] == sh then
        table.remove(g.ships, i)
        break
      end
    end
  elseif action == "focus" or action == "upgrade" then
    local s = g.systems[a.system]
    if action == "focus" then
      spend(f, { credits = 7 })
      s.focus = a.focus
      push(g, s.name .. " specializes in " .. a.focus)
    else
      spend(f, { credits = 9, alloy = 8 })
      s.level = s.level + 1
      push(g, s.name .. " reaches development " .. s.level)
    end
    s.focusedYear = g.round
  elseif action == "build_ship" then
    local cost = C.ships[a.kind].cost
    spend(f, { credits = cost.credits, alloy = cost.alloy - (f.archetype == 1 and a.kind == "fleet" and 1 or 0) })
    mkShip(g, p, a.kind, a.system)
    push(g, f.name .. " launches a " .. C.ships[a.kind].name)
  elseif action == "research" then
    local level = f.tech[a.path] + 1
    spend(f, { knowledge = C.tech[a.path][level].cost })
    f.tech[a.path] = level
    push(g, f.name .. " discovers " .. C.tech[a.path][level].name)
  elseif action == "pact" or action == "peace" then
    local target = a.to
    if action == "pact" then
      spend(f, { credits = 3 })
    end
    f.lastOffer[target] = g.round
    if g.factions[target].human then
      local offers = g.factions[target].offers or {}
      g.factions[target].offers = offers
      offers[#offers + 1] = { from = p, kind = action == "peace" and "peace" or a.kind }
      push(g, f.name .. " sends a proposal to " .. g.factions[target].name)
    else
      local yes = M.willAccept(g, target, p, action == "peace" and "peace" or a.kind)
      if yes then
        M.resolvePact(g, p, target, action == "peace" and "peace" or a.kind)
      else
        trust(g, p, target, -2)
        push(g, g.factions[target].name .. " declines an offer")
      end
    end
  elseif action == "reply" then
    local offer = table.remove(f.offers, 1)
    if a.accept then
      M.resolvePact(g, offer.from, p, offer.kind)
    else
      trust(g, p, offer.from, -3)
      push(g, f.name .. " rejects a proposal")
    end
  elseif action == "war" then
    spend(f, { credits = 5 })
    g.wars[key(p, a.to, "war")] = true
    for _, kind in ipairs({ "trade", "nonaggression", "alliance" }) do
      g.pacts[key(p, a.to, kind)] = nil
    end
    trust(g, p, a.to, -35)
    push(g, f.name .. " declares war on " .. g.factions[a.to].name)
  elseif action == "project" then
    spend(
      f,
      a.kind == "discovery" and { credits = 25, alloy = 15, knowledge = 18 }
        or { credits = 30, alloy = 12, knowledge = 12 }
    )
    f.project = { type = a.kind, progress = 0 }
    push(g, f.name .. " starts the " .. a.kind .. " project")
  end
  checkWin(g)
  return true
end
function M.willAccept(g, p, source, kind)
  if kind == "peace" then
    return M.atWar(g, p, source) and relation(g, p, source) > -70
  end
  local f = g.factions[p]
  local threshold = { trade = -10, nonaggression = 7, alliance = 60 }
  local feeling = relation(g, p, source)
    + (f.archetype == 2 and 15 or 0)
    + (g.factions[source].tech.prosperity >= 2 and 12 or 0)
  return feeling >= (threshold[kind] or 99)
end
function M.resolvePact(g, a, b, kind)
  if kind == "peace" then
    g.wars[key(a, b, "war")] = nil
    trust(g, a, b, 12)
  else
    g.pacts[key(a, b, kind)] = true
    trust(g, a, b, kind == "alliance" and 12 or 8)
  end
  push(g, g.factions[a].name .. " and " .. g.factions[b].name .. " sign " .. kind)
end
local function yearEnd(g)
  for p, f in ipairs(g.factions) do
    local inc = M.income(g, p)
    for k, n in pairs(inc) do
      f[k] = f[k] + n
    end
    if f.project then
      f.project.progress = f.project.progress + 1
      if f.project.progress >= 3 then
        f.completed = f.project.type
      end
    end
    for i = #f.deferred, 1, -1 do
      if f.deferred[i].due <= g.round + 1 then
        local d = table.remove(f.deferred, i)
        if #f.events < 4 then
          enqueue(g, p, d.id, d.system)
        end
      end
    end
  end
  for _, sh in ipairs(g.ships) do
    sh.orders = 2
  end
  g.round = g.round + 1
  g.turnIndex = 1
  local first = table.remove(g.order, 1)
  g.order[#g.order + 1] = first
  push(g, "A new galactic year begins.")
  checkWin(g)
  if not g.ended and g.round > g.limit then
    local best = 1
    for p = 2, 4 do
      if M.score(g, p) > M.score(g, best) then
        best = p
      end
    end
    g.ended = true
    g.winner = best
    g.winReason = "LEGACY"
  end
end
function M.endTurn(g, p)
  if g.ended then
    return false, "CAMPAIGN FINISHED"
  end
  if M.current(g) ~= p then
    return false, "NOT YOUR TURN"
  end
  local f = g.factions[p]
  if #f.events > 0 then
    return false, "RESOLVE YOUR COUNCIL EVENT"
  end
  if f.offers and #f.offers > 0 then
    return false, "ANSWER PENDING DIPLOMACY"
  end
  g.turnIndex = g.turnIndex + 1
  if g.turnIndex > 4 then
    yearEnd(g)
  end
  return true
end
function M.aiTurn(g, p)
  if g.ended or M.current(g) ~= p then
    return false
  end
  local f = g.factions[p]
  while #f.events > 0 do
    local choices = f.events[1].choices
    local pick = 1
    for i, c in ipairs(choices) do
      local ok = M.can(g, p, "choose", { choice = i })
      if ok then
        pick = i
        break
      end
    end
    M.command(g, p, "choose", { choice = pick })
  end
  while f.offers and #f.offers > 0 do
    local offer = f.offers[1]
    local yes = M.willAccept(g, p, offer.from, offer.kind)
    M.command(g, p, "reply", { accept = yes })
  end
  -- Prioritize a sustainable economy and one technology purchase per year.
  if f.knowledge >= 12 then
    local path = (f.archetype == 1 and "warfare")
      or ((f.archetype == 2 or f.archetype == 4) and "prosperity")
      or "exploration"
    if f.tech[path] >= 3 then
      path = f.tech.prosperity <= f.tech.warfare and "prosperity" or "warfare"
    end
    M.command(g, p, "research", { path = path })
  end
  local colony
  for _, s in ipairs(g.systems) do
    if s.owner == p and s.colony and s.focusedYear ~= g.round then
      colony = s
      break
    end
  end
  if colony and f.credits >= 12 and f.alloy >= 12 then
    if colony.level < 2 and rnd(g, 100) < 50 then
      M.command(g, p, "upgrade", { system = colony.id })
    elseif f.archetype == 3 and colony.focus ~= "science" then
      M.command(g, p, "focus", { system = colony.id, focus = "science" })
    end
  end
  -- One sensible diplomatic attempt per year, with rivals treated differently.
  for q = 1, 4 do
    if q ~= p and not M.atWar(g, p, q) and f.lastOffer[q] ~= g.round then
      local action = not M.hasPact(g, p, q, "trade") and "trade"
        or not M.hasPact(g, p, q, "nonaggression") and "nonaggression"
        or "alliance"
      if M.willAccept(g, q, p, action) and rnd(g, 100) < 35 then
        M.command(g, p, "pact", { to = q, kind = action })
        break
      end
    end
  end
  -- Pathfinding makes civilian expansion coherent instead of wandering at random.
  local function route(startId, goal)
    if startId == goal then
      return {}
    end
    local queue = { startId }
    local parent = { [startId] = 0 }
    local qi = 1
    while queue[qi] do
      local at = queue[qi]
      qi = qi + 1
      for _, nextId in ipairs(neighbors(g, at)) do
        if parent[nextId] == nil then
          parent[nextId] = at
          queue[#queue + 1] = nextId
          if nextId == goal then
            local steps = {}
            local v = goal
            while v ~= startId do
              table.insert(steps, 1, v)
              v = parent[v]
            end
            return steps
          end
        end
      end
    end
  end
  -- Recheck live ship ownership because founding a colony consumes its Ark.
  local candidates = {}
  for _, s in ipairs(g.systems) do
    if s.owner == 0 and f.seen[s.id] and M.nearBorder(g, s.id, p) then
      candidates[#candidates + 1] = s.id
    end
  end
  for _, ship in ipairs(g.ships) do
    if ship.owner == p and ship.kind == "scout" then
      for actionNo = 1, 2 do
        if ship.orders < 1 then
          break
        end
        local options = {}
        for _, id in ipairs(neighbors(g, ship.location)) do
          if not f.seen[id] then
            options[#options + 1] = id
          end
        end
        if #options == 0 then
          -- Prefer returning toward owned territory if the local frontier is exhausted.
          for _, id in ipairs(neighbors(g, ship.location)) do
            if g.systems[id].owner == p then
              options[#options + 1] = id
            end
          end
        end
        if #options == 0 then
          break
        end
        M.command(g, p, "move", { ship = ship.id, system = options[rnd(g, #options)] })
        -- Events interrupt human turns, but AI resolves them synchronously.
        while #f.events > 0 do
          local pick
          for ix = 1, #f.events[1].choices do
            if M.can(g, p, "choose", { choice = ix }) then
              pick = ix
              break
            end
          end
          if not pick then
            break
          end
          M.command(g, p, "choose", { choice = pick })
        end
      end
    end
  end
  -- Scout discoveries may make new contiguous colony locations available.
  candidates = {}
  for _, s in ipairs(g.systems) do
    if s.owner == 0 and f.seen[s.id] and M.nearBorder(g, s.id, p) then
      candidates[#candidates + 1] = s.id
    end
  end
  -- Iterate a snapshot to avoid corruption when a colony Ark is consumed.
  local arks = {}
  for _, ship in ipairs(g.ships) do
    if ship.owner == p and ship.kind == "ark" then
      arks[#arks + 1] = ship
    end
  end
  for _, ship in ipairs(arks) do
    if #candidates > 0 then
      local bestPath, bestId
      for _, id in ipairs(candidates) do
        local path = route(ship.location, id)
        if path and (not bestPath or #path < #bestPath) then
          bestPath = path
          bestId = id
        end
      end
      if bestPath then
        for step = 1, math.min(ship.orders, #bestPath) do
          M.command(g, p, "move", { ship = ship.id, system = bestPath[step] })
        end
        if ship.location == bestId and ship.orders > 0 and f.alloy >= 12 and f.credits >= 8 then
          M.command(g, p, "colonize", { ship = ship.id })
        end
      end
    end
  end
  -- Military AIs seek strategic targets, but a fleet cannot conquer an entire empire alone.
  local warTarget
  if f.archetype == 1 and g.round >= 6 and f.credits >= 12 then
    for _, sys in ipairs(g.systems) do
      if sys.owner > 0 and sys.owner ~= p then
        if not warTarget then
          warTarget = sys.id
        end
      end
    end
    if warTarget and not M.atWar(g, p, g.systems[warTarget].owner) and rnd(g, 100) < 28 then
      M.command(g, p, "war", { to = g.systems[warTarget].owner })
    end
  end
  if f.archetype == 1 then
    local fleets = {}
    for _, ship in ipairs(g.ships) do
      if ship.owner == p and ship.kind == "fleet" then
        fleets[#fleets + 1] = ship
      end
    end
    for _, ship in ipairs(fleets) do
      for step = 1, 2 do
        if ship.orders < 1 or not M.findShip(g, ship.id) then
          break
        end
        local bestPath
        for _, sys in ipairs(g.systems) do
          if sys.owner > 0 and sys.owner ~= p and M.atWar(g, p, sys.owner) then
            local path = route(ship.location, sys.id)
            if path and (not bestPath or #path < #bestPath) then
              bestPath = path
            end
          end
        end
        if not bestPath or #bestPath == 0 then
          break
        end
        local ok = M.command(g, p, "move", { ship = ship.id, system = bestPath[1] })
        if not ok then
          break
        end
      end
    end
  end
  local scoutCount, arkCount, fleetCount = 0, 0, 0
  for _, sh in ipairs(g.ships) do
    if sh.owner == p then
      if sh.kind == "scout" then
        scoutCount = scoutCount + 1
      elseif sh.kind == "ark" then
        arkCount = arkCount + 1
      else
        fleetCount = fleetCount + 1
      end
    end
  end
  local kind
  if arkCount < 1 then
    kind = "ark"
  elseif scoutCount < 1 then
    kind = "scout"
  elseif fleetCount < 2 then
    kind = "fleet"
  end
  if kind and f.credits >= C.ships[kind].cost.credits and f.alloy >= C.ships[kind].cost.alloy then
    M.command(g, p, "build_ship", { system = f.home, kind = kind })
  end
  if f.tech.exploration >= 3 and not f.project then
    M.command(g, p, "project", { kind = "discovery" })
  end
  if (f.archetype == 2 or f.archetype == 4) and f.tech.prosperity >= 2 and not f.project then
    M.command(g, p, "project", { kind = "unity" })
  end
  -- Scouting can queue a new event midway through the AI's turn. Resolve it
  -- before yielding, otherwise endTurn rejects it and AI can repeat forever.
  while #f.events > 0 do
    local affordable
    for i = 1, #f.events[1].choices do
      if M.can(g, p, "choose", { choice = i }) then
        affordable = i
        break
      end
    end
    if not affordable then
      return false
    end
    M.command(g, p, "choose", { choice = affordable })
  end
  local ok = M.endTurn(g, p)
  return ok
end
function M.advanceAI(g)
  local n = 0
  while not g.ended and not g.factions[M.current(g)].human and n < 8 do
    local p = M.current(g)
    if not M.aiTurn(g, p) then
      break
    end
    n = n + 1
  end
  return n
end
function M.validState(g)
  if
    type(g) ~= "table"
    or g.version ~= 5
    or #g.factions ~= 4
    or #g.systems ~= 30
    or #g.order ~= 4
    or type(g.rng) ~= "number"
  then
    return false
  end
  if g.turnIndex < 1 or g.turnIndex > 4 or g.round < 1 then
    return false
  end
  for p, f in ipairs(g.factions) do
    for _, k in ipairs({ "credits", "alloy", "knowledge" }) do
      if type(f[k]) ~= "number" or f[k] < 0 then
        return false
      end
    end
    if type(f.events) ~= "table" or type(f.seen) ~= "table" or type(f.tech) ~= "table" then
      return false
    end
  end
  for _, s in ipairs(g.ships) do
    if not C.ships[s.kind] or s.location < 1 or s.location > 30 or s.owner < 1 or s.owner > 4 or s.orders < 0 then
      return false
    end
  end
  return true
end
return M
