local native = dofile
dofile = function(path)
  return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local S = dofile("games/civcraft/systems.lua")
local W = dofile("games/civcraft/world.lua")
local H = dofile("games/civcraft/hex.lua")
local C = dofile("games/civcraft/combat.lua")
local V = dofile("games/civcraft/victory.lua")
local M = dofile("games/civcraft/hostiles.lua")
local Villages = dofile("games/civcraft/villages.lua")
local function simulate(secondID, expected)
  local world = W.generate(75123, "standard", 2, "pangaea")
  local state = {
    ruleset = "create",
    hostileMode = "standard",
    phase = "game",
    round = 1,
    version = 6,
    nextId = 10,
    world = world,
    players = {
      { id = 1, name = "A", civ = "scholar", techs = {}, ai = true },
      {
        id = secondID,
        name = "B",
        civ = "iron",
        techs = {},
        ai = true,
      },
    },
    cities = {},
    units = {},
  }
  for i, p in ipairs(state.players) do
    local start = world.starts[i]
    state.cities[#state.cities + 1] =
      { id = i, owner = p.id, capitalOf = p.id, x = start.x, y = start.y, population = 2, buildings = {} }
    state.units[#state.units + 1] =
      { id = i + 3, owner = p.id, kind = "warrior", x = start.x + 1, y = start.y, movesLeft = 2 }
  end
  M.generate(state)
  Villages.generate(state)
  S.migrate(state)
  W.reveal(state, H, S)
  for round = 1, 180 do
    state.round = round
    for _, p in ipairs(state.players) do
      p.ready = false
      S.aiTurn(state, p, H)
    end
    C.round(state, S)
    S.production(state, H)
    Villages.round(state, S, C)
    M.round(state, S)
    V.check(state, true)
    for _, u in ipairs(state.units) do
      local stats = S.units[u.kind]
      u.movesLeft = stats.hostile and 0 or stats.move
      u.moved = stats.hostile or false
    end
    W.reveal(state, H, S)
    if state.phase == "over" then
      break
    end
  end
  assert(
    state.phase == "over" and state.round < 180 and state.victoryReason == expected,
    "AI must reach " .. expected .. " before score deadline"
  )
  for _, p in ipairs(state.players) do
    assert(S.age(p) == 6, "Both AI empires reach Steam & Rail")
  end
  print("CIVCRAFT seeded AI campaign: " .. expected .. " in round " .. state.round)
end
simulate(2, "END EXPEDITION")
simulate(3, "INDUSTRIAL")
