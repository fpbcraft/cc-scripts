local script = (arg and arg[0]) or ""
local root = script:match("^(.*)/games/railbreak/tests/[^/]+$") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local U = require("games.railbreak.core.util")
local C = require("games.railbreak.content.catalog")
local S = require("games.railbreak.game.state")
local A = require("games.railbreak.game.commands")
local P = require("games.railbreak.game.processing")
local K = require("games.railbreak.game.kinetics")
local App = require("games.railbreak.ui.app")
local passed = 0
local function check(value, label)
  passed = passed + 1
  assert(value, "TEST " .. passed .. " " .. (label or "?"))
end
local function empty(g, x, y)
  g.grid[y][x] = { id = "empty", face = 1, filter = "iron", slot = {}, output = {}, work = 0 }
end
local function obj(g, x, y, id, face, filter)
  g.grid[y][x] = { id = id, face = face or 1, filter = filter or "iron", slot = {}, output = {}, work = 0 }
end
local function resources(g)
  local all = U.copy(g.warehouse)
  for y = 1, S.H do
    for x = 1, S.W do
      local t = S.get(g, x, y)
      U.add(all, t.slot)
      U.add(all, t.output)
      if t.item then
        U.add(all, { [t.item.id] = t.item.n })
      end
    end
  end
  return all
end
local start = S.new({ count = 1, names = { "FELIX" }, seed = 11 })
check(S.valid(start), "initial schema")
check(#start.players == 1 and start.players[1] == "FELIX", "solo setup")
check(start.currentContract == 4, "starter contract must be achievable")
local k = K.analyze(start)
check(k.capacity == 32 and k.load == 12 and k.active, "initial connected kinetic press")
local before = resources(start)
for i = 1, 12 do
  local production = P.shift(start)
  check(production and not k.overstressed, "working shift")
end
local after = resources(start)
check(after.iron_sheet > 0, "starter press produces sheets")
check(after.iron + after.iron_sheet == before.iron + before.iron_sheet, "iron conservation through press")
check(start.warehouse.iron_sheet >= 3, "chest actually returns sheets to warehouse")
local clean = S.new({ count = 4, names = { "Ada", "Ben", "Cia", "Dan" }, seed = 12 })
check(#clean.players == 4 and clean.players[4] == "DAN", "four players")
check(clean.contributions[4].actions == 0, "multiplayer contribution tracking")
local noPlace = A.build(clean, 4, 4, "press")
check(not noPlace, "cannot overwrite press")
check(A.build(clean, 8, 4, "shaft"), "build machinery with resources")
check(A.rotate(clean, 8, 4), "rotation")
check(S.get(clean, 8, 4).face == 2, "rotation changes orientation")
local stockBefore = clean.warehouse.logs
check(A.remove(clean, 8, 4), "dismantle")
check(clean.warehouse.logs >= stockBefore, "refund reclaimed")
check(not A.build(clean, 8, 4, "mixer"), "locked machine not available")
check(A.deliver(start), "sheet-metal contract achievable")
check(start.contractStatus == "DONE" and start.delivered == 1, "deliver goods")
local route = start.routeChoices[1]
check(route.cost.iron_sheet > 0, "opening route achievable without locked blueprints")
-- Hammer out the first route by constructing a second saw processing line.
local build = S.new({ count = 2, seed = 13 })
-- Additional machine adjacent to press power conductor; saw feeds logs -> plank.
obj(build, 2, 5, "depot", 1, "logs")
obj(build, 3, 5, "belt", 1)
obj(build, 4, 5, "saw", 1)
obj(build, 5, 5, "belt", 1)
obj(build, 6, 5, "chest", 1)
check(K.analyze(build).active, "press and saw fit starter capacity")
for i = 1, 14 do
  P.shift(build)
end
check(build.warehouse.iron_sheet >= 3 and build.warehouse.plank >= 2, "starter route supplies can be manufactured")
check(A.travel(build, 1), "travel across first route")
check(build.chapter == 2 and build.unlocked == 1, "travel unlocks machine tier")
check(A.deliver(build) == false, "new contract should need track kits")
-- Network stress safety: press+crusher+saw over 32 SU.
obj(build, 4, 6, "crusher")
local stress = K.analyze(build)
check(stress.overstressed, "network overloaded")
local crafted = build.totalManufactured
P.shift(build)
check(build.totalManufactured == crafted, "overstress halts machinery")
obj(build, 4, 6, "empty")
obj(build, 4, 7, "empty")
check(not K.analyze(build).overstressed, "removing load restores network")
-- Expanded connected 80 SU steam generator must use coal while running.
local steam = S.new()
obj(steam, 4, 2, "steam")
check(K.analyze(steam).capacity == 80, "steam engine capacity")
local coal = steam.warehouse.coal
P.shift(steam)
check(steam.warehouse.coal == coal - 1, "steam coal consumption")
steam.warehouse.coal = 0
check(not K.analyze(steam).active, "coal shortage stops steam")
-- Two simultaneous machine ingredient feeds, deterministic material accounting.
local mixed = S.new()
mixed.unlocked = 2
obj(mixed, 9, 4, "wheel")
obj(mixed, 9, 5, "shaft")
obj(mixed, 9, 6, "mixer", 1)
obj(mixed, 7, 6, "depot", 1, "gravel")
obj(mixed, 8, 6, "belt", 1)
obj(mixed, 9, 8, "depot", 4, "iron_sheet")
obj(mixed, 9, 7, "belt", 4)
obj(mixed, 10, 6, "belt", 1)
obj(mixed, 11, 6, "chest", 1)
mixed.warehouse.gravel = 5
mixed.warehouse.iron_sheet = 5
local initial = resources(mixed)
check(K.analyze(mixed).active, "mixer is kinetically powered")
for i = 1, 24 do
  P.shift(mixed)
end
check(mixed.warehouse.track >= 2, "mixer constructs track kits with two different material inputs")
local final = resources(mixed)
check(final.gravel + final.track / 2 == initial.gravel, "gravel conservation")
check(
  final.iron + final.iron_sheet + final.track / 2 == initial.iron + initial.iron_sheet,
  "sheet and iron conservation"
)
-- Sprite/UI rendering and hitboxes at multiple screen dimensions and modes.
local function mock(w, h, graphics)
  local m = { w = w, h = h, draws = 0, mode = 0 }
  function m.getSize(type)
    if type == 2 then
      return m.w * 6, m.h * 9
    end
    return m.w, m.h
  end
  function m.setGraphicsMode(value)
    if graphics then
      m.mode = value
    else
      error("unsupported")
    end
  end
  function m.drawPixels(x, y, color, ww, hh)
    check(type(x) == "number" and type(color) == "number" and ww > 0 and hh > 0, "valid graphic primitive")
    m.draws = m.draws + 1
  end
  function m.setPaletteColor() end
  function m.setFrozen() end
  function m.setCursorPos(x, y)
    check(x >= 1 and y >= 1 and x <= m.w and y <= m.h, "terminal coordinate")
  end
  function m.setBackgroundColor() end
  function m.setTextColor() end
  function m.write(s)
    m.draws = m.draws + 1
  end
  return m
end
-- CC:Graphics actual monitor_touch: zero-based PIXELS in modes 1/2.
-- Native CC:Tweaked monitor_touch: one-based CHARACTER cells in mode 0.
local function tap(app, rect)
  local xx = rect.x + math.floor((rect.w - 1) / 2)
  local yy = rect.y + math.floor((rect.h - 1) / 2)
  if app.r.mode == "graphics" then
    return app:touch(math.floor((xx + 0.5) * app.r.sx), math.floor((yy + 0.5) * app.r.sy))
  end
  return app:touch(xx + 1, yy + 1)
end
local sizes = {
  { name = "3x3", w = 80, h = 54 },
  { name = "4x3", w = 106, h = 54 },
  { name = "4x4", w = 106, h = 73 },
  { name = "5x4", w = 135, h = 73 },
  { name = "4x5", w = 106, h = 92 },
  { name = "5x5", w = 135, h = 92 },
}
for _, size in ipairs(sizes) do
  for _, gfx in ipairs({ true, false }) do
    local m = mock(size.w, size.h, gfx)
    local app = App.new(m)
    app:draw()
    check(#app.r.buttons >= 3, size.name .. " title menu")
    local opening = app.r.buttons[1]
    check(tap(app, opening), size.name .. " clickable title")
    check(app.scene == "setup", size.name .. " opens setup")
    app:draw()
    local letter = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "Q" then
        letter = button
        break
      end
    end
    check(letter ~= nil, size.name .. " keyboard visible")
    check(tap(app, letter), size.name .. " keyboard touch")
    check(app.names[1] == "Q", size.name .. " keyboard enters correct character")
    local person = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "4 PLAYERS" then
        person = button
        break
      end
    end
    check(person ~= nil and tap(app, person), size.name .. " crew count touch")
    check(app.playerCount == 4, size.name .. " selects four players")
    app:draw()
    local startButton = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "START EXPEDITION" or button.title == "BEGIN EXPEDITION" then
        startButton = button
      end
    end
    check(startButton ~= nil and tap(app, startButton), size.name .. " start touch")
    check(app.scene == "factory" and #app.game.players == 4, size.name .. " enters factory")
    for _, scene in ipairs({ "factory", "railway", "warehouse", "blueprints", "help", "results" }) do
      app.scene = scene
      app:draw()
      check(m.draws > 0, size.name .. " renders " .. scene)
      for _, button in ipairs(app.r.buttons) do
        check(
          button.x >= 0 and button.y >= 0 and button.x + button.w <= m.w and button.y + button.h <= m.h,
          size.name .. " bounds " .. scene .. " " .. tostring(button.title)
        )
      end
    end
    app.scene = "factory"
    app:draw()
    local l = app:layout()
    check(l.step >= 3, size.name .. " tile tap target")
    check(l.x + l.gw < l.side, size.name .. " factory fits next to inspector")
    check(l.y + l.gh < l.bottom, size.name .. " factory fits above navbar")
    check(#app.r.buttons >= S.W * S.H + 5, size.name .. " every tile touch exposed")
    local prev = app.game.shift
    local one = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "1X" or button.title == "1 SHIFT" then
        one = button
      end
    end
    check(one and tap(app, one), size.name .. " shift button touch")
    check(app.game.shift == prev + 1, size.name .. " shift was executed")
    -- Factory grid: pressing an occupied press selects exactly (4,4).
    app:draw()
    local cx = l.x + 3 * l.step + 1
    local cy = l.y + 3 * l.step + 1
    local rx, ry = cx + 1, cy + 1
    if gfx then
      rx = math.floor((cx + 0.5) * app.r.sx)
      ry = math.floor((cy + 0.5) * app.r.sy)
    end
    check(app:touch(rx, ry), size.name .. " touch factory tile")
    check(app.selected and app.selected.x == 4 and app.selected.y == 4, size.name .. " selects intended tile")
    app:draw()
    local build = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "BUILD" or button.title == "BUILD MACHINES" then
        build = button
      end
    end
    check(build and tap(app, build), size.name .. " enter build mode")
    check(app.mode == "build", size.name .. " build panel appears")
    app:draw()
    local nextButton = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "NEXT" then
        nextButton = button
      end
    end
    check(nextButton ~= nil, size.name .. " build pagination available")
    if nextButton then
      tap(app, nextButton)
      check(app.buildPage >= 2, size.name .. " build pagination touch")
    end
    app.modal = "scavenge"
    app:draw()
    local cancel = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "CANCEL" then
        cancel = button
      end
    end
    check(cancel and tap(app, cancel), size.name .. " modal tap")
    check(app.modal == nil, size.name .. " modal dismisses")
    app.scene = "railway"
    app:draw()
    local railway = nil
    for _, button in ipairs(app.r.buttons) do
      if button.title == "BUILD + TRAVEL" or button.title == "BUILD AND TRAVEL" then
        railway = button
        break
      end
    end
    check(railway and tap(app, railway), size.name .. " route tap")
    check(app.modal == "travel", size.name .. " travel confirm opens")
    app.r:resize()
    app:draw()
    check(app.r.mode == (gfx and "graphics" or "text"), size.name .. " gfx/text after resize")
    check(app.r:touchCoords(-1, 0) == nil, size.name .. " out-of-bounds negative touch")
    if gfx then
      local a, b = app.r:touchCoords(0, 0)
      check(a == 0 and b == 0, size.name .. " zero based origin")
      local xx, yy = app.r:touchCoords(m.w * 6 - 1, m.h * 9 - 1)
      check(xx == m.w - 1 and yy == m.h - 1, size.name .. " last pixel")
      check(app.r:touchCoords(m.w * 6, 1) == nil, size.name .. " outside pixel bounds")
    else
      local a, b = app.r:touchCoords(1, 1)
      check(a == 0 and b == 0, size.name .. " 1 based origin")
      local xx, yy = app.r:touchCoords(m.w, m.h)
      check(xx == m.w - 1 and yy == m.h - 1, size.name .. " last char")
      check(app.r:touchCoords(m.w + 1, 1) == nil, size.name .. " outside char bounds")
    end
  end
end
-- Bulk randomized independent runs; commands never admit negative warehouse values.
for seed = 1, 150 do
  local g = S.new({ count = seed % 4 + 1, seed = seed * 13 })
  for j = 1, 10 do
    P.shift(g)
  end
  for _, item in ipairs(C.resources) do
    check(g.warehouse[item] >= 0, "no negative stock")
  end
  check(S.valid(g), "stays valid after shifts")
end
-- Test a complete four-stage expedition, route choice validity and saved-state schema.
local campaign = S.new({ seed = 719, count = 3 })
for chapter = 1, 4 do
  check(campaign.chapter == chapter, "chapter progression")
  local choice = campaign.routeChoices[1]
  U.add(campaign.warehouse, choice.cost)
  local success, message = A.travel(campaign, 1)
  check(success, "route should be traversable after acquiring supplies: " .. tostring(message))
  check(S.valid(campaign), "state remains valid after route travel")
end
check(campaign.finished and campaign.won, "four stages end in victory")
check(#campaign.routeHistory == 4, "records four route choices")
check(A.score(campaign) > 0, "positive outcome score")
check(not A.travel(campaign, 1), "finished game blocks more travel")
-- Scavenging consumes a real shift, including contract deadlines.
local salvage = S.new({ seed = 714 })
salvage.contractAge = salvage.contractLimit
local ok, msg = A.scavenge(salvage)
check(ok and salvage.contractStatus == "MISSED", "salvage cannot bypass contract deadlines")
check(salvage.shift == 1 and salvage.penalty == 1, "salvage penalty and shift accounting")
-- Saved network state isn't trusted if corrupt or incompatible.
local invalid = U.copy(campaign)
invalid.grid[1][1].id = "nonexistent"
check(not S.valid(invalid), "invalid module IDs rejected")
invalid = U.copy(campaign)
invalid.version = 2
check(not S.valid(invalid), "save version mismatch rejected")
print("RAILBREAK: " .. passed .. " assertions passed")
