local script = (arg and arg[0]) or ""
local root = script:match("^(.*)/games/railbreak/tests/[^/]+$") or "."
package.path = root .. "/games/railbreak/?.lua;" .. root .. "/games/railbreak/?/init.lua;" .. package.path
local S = require("train.state")
local A = require("train.rules")
local C = require("train.catalog")
local UI = require("train.ui")
local Info = require("train.info")
local Storage = require("train.storage")
local passed = 0
local function eq(ok, label)
  passed = passed + 1
  assert(ok, "TEST " .. passed .. ": " .. label)
end
local function doIt(g, command, ...)
  local ok, msg = A[command](g, ...)
  eq(ok, command .. " FAILED: " .. tostring(msg))
  eq(S.valid(g), command .. " corrupts state")
  return msg
end
for n = 1, 4 do
  local g = S.new({ count = n, names = { "ADA", "BOB", "CARL", "DAN" }, seed = 42 })
  eq(S.valid(g), "game creation " .. n)
  eq(#g.players == n, "player count")
  eq(S.load(g) <= S.capacity(g), "starter capacity")
  doIt(g, "accept", 1)
  local ref = g.coins
  doIt(g, "buy", "planks")
  eq(g.coins < ref, "buy charges coins")
  doIt(g, "sell", "planks")
  eq(g.coins < ref, "market spread")
  doIt(g, "shift")
  eq(g.shift == 1, "shift turn counts")
  doIt(g, "depart", 2)
  eq(g.pending ~= nil, "first travel encounter")
  local event = C.eventById[g.pending.event]
  local choice = 2
  doIt(g, "resolve", choice)
  eq(g.location == 2 and not g.pending, "arrival")
  doIt(g, "deliver", 1)
  eq(g.contracts[1] == "done", "delivery complete")
  doIt(g, "salvage")
  eq(g.coins >= 12, "salvage recovery")
  eq(g.delivered == 1 and g.reputation >= 1, "reward")
  eq(g.version == 2, "v2 saves independent")
end
local g = S.new({ seed = 100, difficulty = "explorer" })
local stock = g.cargo.planks
doIt(g, "shift")
eq(g.cargo.planks >= stock, "sawmill outputs")
doIt(g, "module", "foundry")
eq(g.stations[1].modules.foundry == 1, "module installed")
doIt(g, "upgrade", "loader")
eq(g.upgrades.loader, "train upgrade")
local cap = S.capacity(g)
while g.coins < 58 do
  doIt(g, "salvage")
end
doIt(g, "addWagon", "cargo")
eq(S.capacity(g) > cap, "wagon capacity")
local p = g.coins
doIt(g, "salvage")
eq(g.coins == p + 12, "salvage is deterministic")
for id in pairs(g.cargo) do
  eq(g.cargo[id] >= 0, "no negative stock")
end
local gone, reason = A.buy(g, "unknown")
eq(not gone and reason, "invalid product fails")
local pass, why = A.deliver(g, 1)
eq(not pass and why, "cannot deliver unaccepted")
local pass2 = A.depart(g, 5)
eq(not pass2, "no teleport")
-- End to end trip to Eastport with two jobs; allow work through supplies and event options.
local run = S.new({ seed = 64 })
doIt(run, "accept", 1)
doIt(run, "accept", 2)
doIt(run, "depart", 2)
doIt(run, "resolve", 2)
doIt(run, "deliver", 1)
-- Return to Iron Junction then proceed via Stonebridge.
if run.fuel < 2 then
  doIt(run, "refuel")
end
doIt(run, "depart", 1)
if run.fuel < 2 then
  doIt(run, "refuel")
end
-- If track requires parts, purchase them before leaving.
while run.cargo.parts < 2 do
  if S.load(run) >= S.capacity(run) then
    doIt(run, "sell", "planks")
  end
  doIt(run, "buy", "parts")
end
doIt(run, "depart", 3)
if run.pending then
  doIt(run, "resolve", 2)
end
doIt(run, "deliver", 2)
eq(run.reputation >= 2 and run.delivered >= 2, "victory contracts done")
while run.fuel < 3 do
  doIt(run, "refuel")
end
if run.cargo.parts < 1 then
  doIt(run, "buy", "parts")
end
doIt(run, "depart", 4)
if run.pending then
  doIt(run, "resolve", 2)
end
while run.fuel < 3 do
  doIt(run, "refuel")
end
while run.cargo.parts < 2 do
  if S.load(run) >= S.capacity(run) then
    doIt(run, "sell", "planks")
  end
  doIt(run, "buy", "parts")
end
doIt(run, "depart", 5)
if run.pending then
  doIt(run, "resolve", 2)
end
eq(run.won and run.finished, "full campaign win")
-- Fake terminals simulate actual zero-based CC Graphics touch and one-based text touch.
local sizes = { { 160, 162 }, { 212, 162 }, { 212, 219 }, { 212, 276 }, { 270, 219 }, { 270, 276 } }
local scenes = {
  "title",
  "setup",
  "hub",
  "map",
  "station",
  "modules",
  "market",
  "contracts",
  "train",
  "wagons",
  "upgrades",
  "travel",
  "results",
  "help",
}
local function monitor(w, h, mode)
  local m = { cw = w / 2, ch = h / 3, draws = 0, mode = mode }
  function m.getSize(flag)
    if flag then
      return w * 3, h * 3
    end
    return m.cw, m.ch
  end
  function m.setGraphicsMode(n)
    if not mode then
      error("No graphics mode")
    end
    m.gmode = n
  end
  function m.setFrozen(_) end
  function m.drawPixels(...)
    m.draws = m.draws + 1
  end
  function m.setPaletteColor(...) end
  function m.getPaletteColor(...)
    return 0, 0, 0
  end
  function m.setBackgroundColor(...) end
  function m.setTextColor(...) end
  function m.setCursorPos(...) end
  function m.write(...) end
  return m
end
for _, dim in ipairs(sizes) do
  for _, graphics in ipairs({ false, true }) do
    local m = monitor(dim[1], dim[2], graphics)
    local ui = UI.new(m)
    ui:draw()
    eq(
      ui.r.w == (graphics and (dim[1] / 2) * 3 or dim[1]) and ui.r.h == (graphics and (dim[2] / 3) * 4 or dim[2]),
      "expected canvas dimensions"
    )
    eq(ui.r.cw == dim[1] / 2 and ui.r.ch == dim[2] / 3, "terminal text-cell dimensions retained")
    eq(ui:small() == (dim[1] < 200 or dim[2] < 206), "compact layout follows physical monitor, not framebuffer")
    eq(#ui.r.buttons >= 2, "title buttons")
    local b = ui.r.buttons[1]
    local x = b.x + math.floor(b.w / 2)
    local y = b.y + math.floor(b.h / 2)
    local px = graphics and math.floor(ui.r.ox + x * ui.r.sx) or math.floor(x / 2) + 1
    local py = graphics and math.floor(ui.r.oy + y * ui.r.sy) or math.floor(y / 3) + 1
    eq(ui:touch(px, py) ~= false, "touch activates title button")
    eq(ui.scene == "setup", "click new expedition")
    -- Force gameplay and check every screen rendering, bounds and touch hitboxes.
    ui:newGame()
    for _, sc in ipairs(scenes) do
      ui.scene = sc
      ui:draw()
      eq(#ui.r.buttons > 0, "touch targets present in " .. sc)
      for _, hit in ipairs(ui.r.buttons) do
        eq(hit.w > 0 and hit.h > 0, "positive hit area")
        if not (hit.x >= -10 and hit.x <= ui.r.w + 2 and hit.y >= 0 and hit.y <= ui.r.h + 3) then
          print("OFFSCREEN", dim[1], dim[2], graphics, sc, hit.label, hit.x, hit.y, hit.w, hit.h, ui.r.w, ui.r.h)
        end
        eq(
          hit.x >= -10 and hit.x <= ui.r.w + 2 and hit.y >= 0 and hit.y <= ui.r.h + 3,
          "hit box not grossly out of view " .. sc
        )
      end
    end
    ui.scene = "hub"
    ui:draw()
    local counts = #ui.r.buttons
    eq(counts >= 8, "wagon touch controls")
    ui.scene = "map"
    ui:draw()
    eq(#ui.r.buttons >= 8, "map nodes selectable")
    -- Rendering a connected destination used to crash because the UI called
    -- the fuel cost helper on the graphics renderer instead of the rules module.
    ui.selected = 2
    ui:draw()
    eq(ui.scene == "map", "connected station renders without a runtime error")
    eq(
      ui.r:textWidth("STATION MARKET") == (graphics and 14 * 4 or 14 * 2),
      "normal font uses compact width in graphics mode"
    )
    local depart
    for _, hit in ipairs(ui.r.buttons) do
      if hit.label == "DETAILS" then
        depart = hit
      end
    end
    eq(depart ~= nil, "connected route exposes depart action")
    local dx = depart.x + math.floor(depart.w / 2)
    local dy = depart.y + math.floor(depart.h / 2)
    local touchX = graphics and math.floor(ui.r.ox + dx * ui.r.sx) or math.floor(dx / 2) + 1
    local touchY = graphics and math.floor(ui.r.oy + dy * ui.r.sy) or math.floor(dy / 3) + 1
    eq(ui:touch(touchX, touchY) == "DETAILS", "route preview opens")
    eq(ui.info and ui.info.action == "depart", "route preview offers deliberate departure")
    eq(ui.g.pending == nil, "opening preview does not depart")
    local confirm
    for _, hit in ipairs(ui.r.buttons) do
      if hit.label == "DEPART" then
        confirm = hit
      end
    end
    eq(confirm ~= nil, "departure confirmation touch target")
    local cx = confirm.x + math.floor(confirm.w / 2)
    local cy = confirm.y + math.floor(confirm.h / 2)
    eq(
      ui:touch(
        graphics and math.floor(ui.r.ox + cx * ui.r.sx) or math.floor(cx / 2) + 1,
        graphics and math.floor(ui.r.oy + cy * ui.r.sy) or math.floor(cy / 3) + 1
      ) == "DEPART",
      "confirm departure"
    )
    eq(ui.g.pending ~= nil and ui.scene == "travel", "departure triggers event scene")
    local resolve
    for _, hit in ipairs(ui.r.buttons) do
      if hit.label == "TAKE DETOUR" then
        resolve = hit
      end
    end
    -- Event labels may be different; select the second offered choice directly.
    local event = C.eventById[ui.g.pending.event]
    if not resolve then
      for _, hit in ipairs(ui.r.buttons) do
        if hit.label == event.choices[2].label then
          resolve = hit
        end
      end
    end
    eq(resolve ~= nil, "event choice has a button")
    local ex = resolve.x + math.floor(resolve.w / 2)
    local ey = resolve.y + math.floor(resolve.h / 2)
    local rtx = graphics and math.floor(ui.r.ox + ex * ui.r.sx) or math.floor(ex / 2) + 1
    local rty = graphics and math.floor(ui.r.oy + ey * ui.r.sy) or math.floor(ey / 3) + 1
    eq(ui:touch(rtx, rty) ~= false, "travel choice is touchable")
    eq(ui.info and ui.info.action == "resolve", "travel choice explained before resolution")
    eq(ui.g.pending ~= nil, "information does not automatically resolve event")
    local choose
    for _, hit in ipairs(ui.r.buttons) do
      if hit.label == "CHOOSE THIS" then
        choose = hit
      end
    end
    eq(choose ~= nil, "choice confirmation available")
    local zx = choose.x + math.floor(choose.w / 2)
    local zy = choose.y + math.floor(choose.h / 2)
    ui:touch(
      graphics and math.floor(ui.r.ox + zx * ui.r.sx) or math.floor(zx / 2) + 1,
      graphics and math.floor(ui.r.oy + zy * ui.r.sy) or math.floor(zy / 3) + 1
    )
    eq(ui.g.location == 2 and ui.g.pending == nil, "event resolves arrival")

    ui.scene = "market"
    ui:draw()
    eq(#ui.r.buttons >= 7, "market buttons present")
    -- Full render modes share monitor scale 0.5. Graphics gets extra logical
    -- pixel density without altering the native text grid or touch targets.
    if graphics then
      eq(ui.r.sx == ui.r.sy, "denser graphics preserves proportions")
    else
      eq(ui.r.w == dim[1] and ui.r.h == dim[2], "text fallback unchanged")
    end
    ui:resize()
    eq(not graphics or ui.r.sx == ui.r.sy, "resize retains uniform graphics transform")
    ui.scene = "travel"
    ui.g.pending = { from = 1, to = 2, event = "rocks" }
    ui:draw()
    eq(#ui.r.buttons >= 5, "event choices tappable")
    ui:close()
  end
end
-- Tooltip descriptions: every item and screen must have substantive copy, cost and
-- a real action (or an explicitly completed/installed status) when applicable.
local ref = S.new({ seed = 42 })
local function described(kind, id, extra)
  local d = Info.describe(ref, kind, id, extra)
  eq(type(d.title) == "string" and #d.title > 2, "info has a named heading: " .. kind)
  local joined = table.concat(d.lines, " ")
  eq(#joined > 35, "description is substantive: " .. kind .. " " .. tostring(id))
  eq(Info.wrap(d.lines, 17)[1] ~= nil, "description can wrap on compact monitor")
  return d, joined
end
for _, item in ipairs(C.goods) do
  local d, full = described("good", item.id, "buy")
  eq(d.action == "buy" and full:find("BUY:"), "market goods preview has price")
  local sell = described("good", item.id, "sell")
  eq(sell.action == "sell", "market selling explained")
end
for _, item in ipairs(C.upgrades) do
  local d = described("upgrade", item.id)
  eq(d.action == "upgrade", "technology upgrade confirmed")
end
for _, item in ipairs(C.modules) do
  local d = described("module", item.id)
  eq(d.action == "module", "station module preview")
end
for _, item in ipairs(C.wagons) do
  local d = described("wagonNew", item.id)
  eq(d.action == "addWagon", "new wagon confirmed")
end
for i in ipairs(ref.wagons) do
  local d = described("wagon", i)
  eq(d.action == "wagonUpgrade", "existing wagon level explained")
end
for _, id in ipairs({ "coins", "fuel", "hull", "reputation" }) do
  described("resource", id)
end
for _, id in ipairs(scenes) do
  described("topic", id)
end
for _, kind in ipairs({ "repair", "refuel", "shift", "salvage" }) do
  local d = described("service", kind)
  eq(d.action == kind, "service confirms")
end
local route = described("route", 2)
eq(route.action == "depart", "connected route describes requirements")
for _, event in ipairs(C.events) do
  ref.pending = { event = event.id, to = 2, from = 1 }
  for i in ipairs(event.choices) do
    local d = described("event", i)
    eq(d.action == "resolve", "event outcome confirmed")
  end
end
ref.pending = nil
-- Upgrading the previously ineffective engine/crane now produces visible benefit.
local startFuel = ref.maxFuel
local yes = A.wagonUpgrade(ref, 1)
eq(yes and ref.maxFuel == startFuel + 4, "engine level increases fuel capacity")
local startCap = S.capacity(ref)
yes = A.wagonUpgrade(ref, 4)
eq(yes and S.capacity(ref) == startCap + 2, "crane level increases cargo capacity")
-- An existing v2 save with previously ineffective locomotive levels is
-- migrated once, and future saves do not repeatedly grant free fuel capacity.
local old = S.new({ seed = 91 })
old.wagons[1].level = 3
old.balanceRevision = nil
local oldFuel = old.maxFuel
local migrated = Storage.migrate(old)
eq(migrated and migrated.maxFuel == oldFuel + 8, "old engine level migrated")
Storage.migrate(migrated)
eq(migrated.maxFuel == oldFuel + 8, "migration is idempotent")
-- Modals may be dismissed without spending money or advancing a turn.
for _, dim in ipairs(sizes) do
  for _, graphics in ipairs({ false, true }) do
    local u = UI.new(monitor(dim[1], dim[2], graphics), { game = S.new({ seed = 99 }) })
    u.scene = "upgrades"
    u:draw()
    local beforeCoins = u.g.coins
    local beforeTurn = u.g.turn
    local upgradeCard
    for _, hit in ipairs(u.r.buttons) do
      if hit.label == C.upgrades[1].name or hit.label == "BUY " .. C.upgrades[1].cost then
        upgradeCard = hit
        break
      end
    end
    eq(upgradeCard ~= nil, "upgrade card can be inspected at " .. dim[1])
    local function tap(hit)
      local tx = hit.x + math.floor(hit.w / 2)
      local ty = hit.y + math.floor(hit.h / 2)
      return u:touch(
        graphics and math.floor(u.r.ox + tx * u.r.sx) or math.floor(tx / 2) + 1,
        graphics and math.floor(u.r.oy + ty * u.r.sy) or math.floor(ty / 3) + 1
      )
    end
    tap(upgradeCard)
    eq(u.info and u.info.action == "upgrade", "touch opens upgrade explanation")
    eq(u.g.coins == beforeCoins and u.g.turn == beforeTurn, "inspect costs nothing")
    eq(#u.r.buttons <= 5, "modal prevents interacting with hidden screen controls")
    local back
    for _, hit in ipairs(u.r.buttons) do
      if hit.label == "BACK" then
        back = hit
      end
    end
    eq(back ~= nil, "modal has a close button")
    tap(back)
    eq(u.info == nil and u.g.coins == beforeCoins, "dismiss does not purchase")
    tap(upgradeCard)
    local install
    for _, hit in ipairs(u.r.buttons) do
      if hit.label == "INSTALL" then
        install = hit
      end
    end
    eq(install ~= nil, "install confirmation is available")
    tap(install)
    eq(u.g.upgrades.brass and u.g.coins == beforeCoins - 55, "confirmed purchase applies cost once")
    u:close()
  end
end
-- Inline guidance belongs to the screens, not only to modal descriptions.
-- Capture renderer text before rasterisation, across all supported graphics sizes.
for _, dim in ipairs(sizes) do
  local u = UI.new(monitor(dim[1], dim[2], true), { game = S.new({ seed = 177 }) })
  local printed = {}
  local originalText = u.r.text
  u.r.text = function(self, x, y, value, ...)
    printed[#printed + 1] = tostring(value or "")
    return originalText(self, x, y, value, ...)
  end
  local function shows(scene, needle)
    printed = {}
    u.scene = scene
    if scene == "map" then
      u.selected = 2
    end
    if scene == "travel" then
      u.g.pending = { event = "rocks", from = 1, to = 2 }
    end
    u:draw()
    local joined = table.concat(printed, " | ")
    eq(joined:find(needle, 1, true) ~= nil, scene .. " displays " .. needle .. " on " .. dim[1] .. "x" .. dim[2])
  end
  shows("upgrades", "FORECAST NEXT HAZARD")
  shows("upgrades", "COST 55 C")
  shows("modules", "1 LOG -> 2 PLANKS")
  shows("market", "SAWMILL INPUT")
  shows("wagons", "+8 CAP; +4 PER LV")
  shows("contracts", "OWN ")
  shows("map", "PARTS ")
  shows("train", "+8 CARGO CAPACITY")
  shows("station", "+25 HULL")
  shows("travel", "FREE WITH EQUIPMENT")
  -- Selection updates the inline wagon panel without forcing a modal.
  u.g.pending = nil
  u.scene = "train"
  u:draw()
  local selectable
  for _, hit in ipairs(u.r.buttons) do
    if hit.label == "WAGON" then
      selectable = hit
      break
    end
  end
  eq(selectable ~= nil, "train wagon can be selected directly")
  local px = selectable.x + math.floor(selectable.w / 2)
  local py = selectable.y + math.floor(selectable.h / 2)
  u:touch(math.floor(u.r.ox + px * u.r.sx), math.floor(u.r.oy + py * u.r.sy))
  eq(u.info == nil, "selecting wagon does not open a modal")
  u:close()
end

print("TRAIN-FIRST GAME/UI: " .. passed .. " checks passed")
