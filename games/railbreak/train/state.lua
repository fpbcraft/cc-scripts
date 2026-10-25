local C = require("train.catalog")
local U = require("core.util")
local S = { VERSION = 2 }
function S.new(opts)
  opts = opts or {}
  local count = U.clamp(tonumber(opts.count) or 1, 1, 4)
  local names = {}
  for i = 1, count do
    local n = U.name(opts.names and opts.names[i] or "")
    names[i] = n ~= "" and n or ("PLAYER " .. i)
  end
  local built = {}
  for _, e in ipairs(C.edges) do
    if e[1] == 1 and e[2] == 2 then
      built["1-2"] = true
    end
  end
  local g = {
    version = S.VERSION,
    balanceRevision = 1,
    seed = tonumber(opts.seed) or 48819,
    difficulty = opts.difficulty or "standard",
    players = names,
    currentPlayer = 1,
    turn = 0,
    shift = 0,
    trips = 0,
    location = 1,
    coins = 150,
    fuel = 9,
    maxFuel = 12,
    hull = 100,
    maxHull = 100,
    reputation = 0,
    delivered = 0,
    penalty = 0,
    cargo = { logs = 1, planks = 3, ore = 2, sheets = 1, parts = 3, coal = 1, food = 1, passengers = 0 },
    wagons = { { id = "engine", level = 1 }, { id = "cargo", level = 1 }, { id = "passenger", level = 1 }, {
      id = "crane",
      level = 1,
    } },
    upgrades = {},
    stations = {},
    contracts = {},
    built = built,
    discovered = { [1] = true, [2] = true, [3] = true, [7] = true },
    pending = nil,
    finished = false,
    won = false,
    history = {},
    playerStats = {},
    score = 0,
  }
  for i = 1, count do
    g.playerStats[i] = { actions = 0, deliveries = 0 }
  end
  for _, s in ipairs(C.stations) do
    g.stations[s.id] = { modules = {}, production = 0 }
  end
  g.stations[1].modules.sawmill = 1
  g.stations[1].modules.press = 1
  g.stations[3].modules.foundry = 1
  g.stations[2].modules.sawmill = 1
  g.stations[4].modules.press = 1
  g.stations[6].modules.sawmill = 1
  g.stations[7].modules.ticket = 1
  for _, c in ipairs(C.contracts) do
    g.contracts[c.id] = "available"
  end
  S.log(g, "LOCOMOTIVE COMMISSIONED")
  return g
end
function S.log(g, message)
  table.insert(g.history, 1, ("TURN %d  %s"):format(g.turn, message))
  while #g.history > 24 do
    table.remove(g.history)
  end
end
function S.edge(a, b)
  for _, e in ipairs(C.edges) do
    if (e[1] == a and e[2] == b) or (e[1] == b and e[2] == a) then
      return e
    end
  end
  return nil
end
function S.edgeKey(a, b)
  return math.min(a, b) .. "-" .. math.max(a, b)
end
function S.neighbors(id)
  local t = {}
  for _, e in ipairs(C.edges) do
    if e[1] == id then
      t[#t + 1] = e[2]
    elseif e[2] == id then
      t[#t + 1] = e[1]
    end
  end
  return t
end
function S.capacity(g)
  local cap = 0
  for _, w in ipairs(g.wagons) do
    if w.id == "cargo" then
      cap = cap + 8 + ((w.level or 1) - 1) * 4
    elseif w.id == "passenger" then
      cap = cap + 4 + ((w.level or 1) - 1) * 2
    elseif w.id == "fuel" then
      cap = cap + 2
    elseif w.id == "crane" then
      cap = cap + 2 + ((w.level or 1) - 1) * 2
    end
  end
  if g.upgrades.loader then
    cap = cap + 5
  end
  if g.upgrades.whistle then
    cap = cap + 2
  end
  return cap
end
function S.load(g)
  local n = 0
  for _, v in pairs(g.cargo) do
    n = n + v
  end
  return n
end
function S.valid(g)
  if type(g) ~= "table" or g.version ~= S.VERSION or type(g.players) ~= "table" or #g.players < 1 or #g.players > 4 then
    return false
  end
  if type(g.location) ~= "number" or not C.stations[g.location] or type(g.turn) ~= "number" or g.turn < 0 then
    return false
  end
  if type(g.coins) ~= "number" or g.coins < 0 or type(g.hull) ~= "number" or g.hull <= 0 or g.hull > g.maxHull then
    return false
  end
  if type(g.fuel) ~= "number" or g.fuel < 0 or g.fuel > g.maxFuel or type(g.cargo) ~= "table" then
    return false
  end
  if type(g.stations) ~= "table" or type(g.contracts) ~= "table" or type(g.wagons) ~= "table" or #g.wagons < 1 then
    return false
  end
  if type(g.playerStats) ~= "table" or type(g.upgrades) ~= "table" or type(g.built) ~= "table" then
    return false
  end
  for _, good in ipairs(C.goods) do
    if type(g.cargo[good.id]) ~= "number" or g.cargo[good.id] < 0 or g.cargo[good.id] % 1 ~= 0 then
      return false
    end
  end
  if S.load(g) > S.capacity(g) then
    return false
  end
  return true
end
return S
