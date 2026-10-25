local path = (arg and arg[0]) or "tests/simulation.lua"
local dir = path:match("^(.*)/tests/[^/]+$") or "."
_G.EXPANSE_ROOT = dir .. "/expanse"
local sim = dofile(_G.EXPANSE_ROOT .. "/sim.lua")
local UI = dofile(_G.EXPANSE_ROOT .. "/ui.lua")
local checks = 0
local function t(c, m)
  checks = checks + 1
  assert(c, m or ("check " .. checks))
end
local function eventResolve(g, p)
  local f = g.factions[p]
  for _ = 1, 25 do
    if #f.events == 0 then
      return
    end
    local yes, msg = sim.command(g, p, "choose", { choice = 1 })
    t(yes, msg)
  end
  error("Event processing loop")
end
local function connected(g)
  local visited = { [1] = true }
  local work = { 1 }
  local cur = 1
  while work[cur] do
    local i = work[cur]
    cur = cur + 1
    for _, id in ipairs(sim.neighbors(g, i)) do
      if not visited[id] then
        visited[id] = true
        work[#work + 1] = id
      end
    end
  end
  for id = 1, 40 do
    t(visited[id], "Disconnected " .. id)
  end
end
-- Test core mechanics and economy for many deterministic galaxies.
for seed = 1, 45 do
  local config = { seed = seed * 181 + 733, humans = { true, false, false, false }, rounds = 20 }
  local g = sim.new(config)
  t(#g.systems == 40)
  t(#g.factions == 4)
  t(#g.ships == 13)
  connected(g)
  local p = 1
  local capital = 1
  local s = g.systems[capital]
  t(s.owner == p and s.colony == 1)
  local scout, builder
  for _, sh in ipairs(sim.shipsAt(g, capital, 1)) do
    if sh.kind == "scout" then
      scout = sh
    elseif sh.kind == "builder" then
      builder = sh
    end
  end
  t(scout and builder)
  t(not sim.validate(g, 1, "build", { system = 2, building = "mine" }), "Cannot build outside territory")
  local neighbors = sim.neighbors(g, capital)
  t(#neighbors > 0)
  local dest = neighbors[1]
  local ok, msg = sim.command(g, 1, "move", { ship = scout.id, system = dest })
  t(ok, msg)
  t(g.factions[1].seen[dest], "Science ship must reveal destination")
  t(scout.ap == 1, "Move spends ship orders")
  eventResolve(g, 1)
  local stock = g.factions[1].credits
  ok, msg = sim.command(g, 1, "build", { system = capital, building = "mine" })
  t(ok, msg)
  t(g.factions[1].credits < stock, "Building costs credits")
  t(g.systems[capital].construction ~= nil)
  t(
    sim.validate(g, 1, "shipbuild", { system = capital, class = "frigate" }),
    "Ship construction independent of colony buildings"
  )
  ok, msg = sim.command(g, 1, "shipbuild", { system = capital, class = "frigate" })
  t(ok, msg)
  t(g.systems[capital].shipQueue ~= nil)
  t(not sim.validate(g, 1, "build", { system = capital, building = "lab" }), "Single construction queue per world")
  local before = g.factions[1].research
  t(sim.researchCost(g.factions[1], "engineering") == 12, "Initial Engineering research price")
  ok, msg = sim.endTurn(g, 1)
  t(ok, msg)
  local ai = sim.advanceAI(g)
  t(ai >= 3, "AI must advance to human")
  t(sim.current(g) == 1, "Expected human after AI turns")
  t(g.round >= 2)
  t(g.factions[1].research >= before)
  t(g.systems[capital].buildings.mine == 1, "Build completes at round end")
  t(#g.ships >= 13, "Ships should launch")
  t(sim.validateState(g))
  for i = 1, math.min(8, seed % 10 + 1) do
    eventResolve(g, 1)
    while #g.factions[1].offers > 0 do
      sim.command(g, 1, "offer_reply", { accept = true })
    end
    local o = sim.endTurn(g, 1)
    t(o)
    sim.advanceAI(g)
    t(sim.validateState(g), "Invalid state after AI iteration")
    t(g.ended or g.factions[sim.current(g)].human, "AI lockup")
    for _, fac in ipairs(g.factions) do
      for _, k in ipairs({ "credits", "materials", "research", "aether" }) do
        t(fac[k] >= 0, "Negative " .. k)
      end
    end
    if g.ended then
      break
    end
  end
end
-- Human count: exactly 1,2,3,4; skipped AIs may occupy rotated first turn slots.
for humans = 1, 4 do
  local who = {}
  for p = 1, 4 do
    who[p] = p <= humans
  end
  local g = sim.new({ seed = 1922 + humans, humans = who })
  for p = 1, 4 do
    t(g.factions[p].human == who[p])
  end
  for i = 1, 11 do
    local p = sim.current(g)
    if g.ended then
      break
    end
    if who[p] then
      eventResolve(g, p)
      while #g.factions[p].offers > 0 do
        sim.command(g, p, "offer_reply", { accept = false })
      end
      t(sim.endTurn(g, p))
    end
    sim.advanceAI(g)
    t(sim.validateState(g))
    t(g.ended or who[sim.current(g)])
  end
end
-- Resource spending is independent of the fleet's order count.
local g = sim.new({ seed = 142, humans = { true, true, true, true } })
local f = g.factions[1]
f.research = 200
for _ = 1, 4 do
  t(sim.command(g, 1, "research", { branch = "engineering" }))
end
t(f.tech.engineering == 4 and f.research < 200)
local scout = sim.shipsAt(g, 1, 1)[1]
t(scout.ap == 2)
t(not sim.validate(g, 1, "research", { branch = "engineering" }), "Branch caps at four discoveries")
-- Diplomacy offers must be delivered across human turns, not auto-accepted.
g.factions[1].credits = 40
t(sim.command(g, 1, "diplomacy", { to = 2, pact = "trade" }))
t(#g.factions[2].offers == 1)
t(sim.endTurn(g, 1))
t(sim.current(g) == 2)
t(sim.command(g, 2, "offer_reply", { accept = true }))
t(sim.hasTreaty(g, 1, 2, "trade"))
-- UI graphics mode / touchscreen coordinates and page flow.
local function mon(w, h, graphics)
  local m = { pixels = 0 }
  function m.setTextScale() end
  function m.getSize(mode)
    if mode == 2 then
      return w * 6, h * 9
    end
    return w, h
  end
  function m.setGraphicsMode() end
  function m.setPaletteColor() end
  function m.drawPixels()
    m.pixels = m.pixels + 1
  end
  function m.setFrozen() end
  function m.setCursorPos() end
  function m.setBackgroundColor() end
  function m.setTextColor() end
  function m.write() end
  if not graphics then
    m.setGraphicsMode = nil
    m.drawPixels = nil
  end
  return m
end
for _, size in ipairs({ { 72, 51 }, { 103, 73 }, { 126, 89 } }) do
  for _, gfx in ipairs({ true, false }) do
    local m = mon(size[1], size[2], gfx)
    local ui = UI.new(m)
    t(ui.r.kind == (gfx and "gfx" or "text"))
    ui:draw()
    t(#ui.r.buttons >= 3)
    local b = ui.r.buttons[#ui.r.buttons - 2] -- NEW CAMPAIGN
    local px = math.floor(b.x + b.w / 2)
    local py = math.floor(b.y + b.h / 2)
    if gfx then
      t(ui:monitorTouch(px * ui.r.px, py * ui.r.py))
    else
      t(ui:monitorTouch(px + 1, py + 1))
    end
    t(ui.screen == "setup")
    ui:draw()
    t(#ui.r.buttons >= 8)
    ui:start()
    t(ui.g ~= nil)
    ui:draw()
    t(#ui.r.buttons >= 1)
    local b = ui.r.buttons[#ui.r.buttons]
    local x = math.floor(b.x + b.w / 2)
    local y = math.floor(b.y + b.h / 2)
    if gfx then
      ui:monitorTouch(x * ui.r.px, y * ui.r.py)
    else
      ui:monitorTouch(x + 1, y + 1)
    end
    t(ui.screen == "galaxy")
    ui:draw()
    t(#ui.r.buttons > 3)
    t(ui.g.round == 1)
    t(ui:monitorTouch(-1, -1) == false)
  end
end
print("SHATTERED EXPANSE: " .. checks .. " checks passed")
