-- Installed programs own their globals and module cache.
local bootstrap = loadfile("/games/ironspire/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/games/ironspire" then
  return bootstrap().run("/games/ironspire", "main.lua", _ENV, ...)
end
-- IRONSPIRE v0.1.0 - touchscreen deckbuilding roguelike for CC:Tweaked
-- Run /games/ironspire/main.lua [monitor_name]; --test-api returns the game API.
local args = { ... }
local package = package or { path = "/?.lua", loaded = {} }
package.path = "/games/ironspire/?.lua;" .. (package.path or "")
local require = require or function(name)
  return dofile("/games/ironspire/" .. name .. ".lua")
end
local R = require("render")
local Map = require("map")
local C = {
  strike = { name = "STRIKE", cost = 1, desc = "Deal 6 damage", damage = 6 },
  guard = { name = "GUARD", cost = 1, desc = "Gain 5 block", block = 5 },
  bash = { name = "BASH", cost = 2, desc = "Deal 8, vulnerable 2", damage = 8, vuln = 2 },
  jab = { name = "QUICK JAB", cost = 0, desc = "Deal 3, draw 1", damage = 3, draw = 1 },
  brace = { name = "BRACE", cost = 1, desc = "Gain 9 block", block = 9 },
  twin = { name = "TWIN CUT", cost = 1, desc = "Deal 4 twice", damage = 4, hits = 2 },
  spark = { name = "SPARK", cost = 1, desc = "Deal 7, draw 1", damage = 7, draw = 1 },
  mend = { name = "MEND", cost = 1, desc = "Heal 4 HP", heal = 4 },
  heavy = { name = "HEAVY SLAM", cost = 2, desc = "Deal 15 damage", damage = 15 },
  focus = { name = "FOCUS", cost = 0, desc = "Gain 1 energy, draw 1", energy = 1, draw = 1 },
  bulwark = { name = "BULWARK", cost = 2, desc = "Gain 16 block", block = 16 },
  drain = { name = "LEECH", cost = 1, desc = "Deal 5, heal 3", damage = 5, heal = 3 },
}
local POOL = { "jab", "brace", "twin", "spark", "mend", "heavy", "focus", "bulwark", "drain" }
local FOES = {
  { name = "RUST MITE", hp = 25, attacks = { { "BITE", 7 }, { "HARDEN", 0, 6 }, { "BITE", 9 } } },
  { name = "COPPER SENTINEL", hp = 33, attacks = { { "PUNCH", 9 }, { "GUARD", 4, 9 }, { "SMASH", 13 } } },
  { name = "SMOKE WRAITH", hp = 29, attacks = { { "DRAIN", 6, 0, 2 }, { "SLASH", 10 }, { "DRAIN", 7, 0, 1 } } },
  {
    name = "GEAR COLOSSUS",
    hp = 95,
    attacks = { { "CRUSH", 15 }, { "PLATING", 0, 13 }, { "HAMMER", 19 }, {
      "REV UP",
      0,
      6,
    } },
  },
}
local function copy(a)
  local b = {}
  for i, v in ipairs(a) do
    b[i] = v
  end
  return b
end
local function shuffle(a)
  for i = #a, 2, -1 do
    local j = math.random(i)
    a[i], a[j] = a[j], a[i]
  end
end
local function new()
  return {
    hp = 72,
    maxhp = 72,
    gold = 75,
    floor = 0,
    deck = { "strike", "strike", "strike", "strike", "strike", "guard", "guard", "guard", "guard", "bash" },
    relics = {},
    screen = "map",
    log = "Choose your path.",
    turn = 0,
    map = Map.generate(),
    lane = 2,
  }
end
local function save(s)
  if not fs or not textutils then
    return
  end
  if not fs.exists("/games/ironspire/data") then
    fs.makeDir("/games/ironspire/data")
  end
  local h = fs.open("/games/ironspire/data/save.lua.tmp", "w")
  assert(h, "Cannot write save")
  h.write(textutils.serialize(s))
  h.close()
  if fs.exists("/games/ironspire/data/save.lua") then
    fs.delete("/games/ironspire/data/save.lua")
  end
  fs.move("/games/ironspire/data/save.lua.tmp", "/games/ironspire/data/save.lua")
end
local function loadSave()
  if not fs or not textutils or not fs.exists("/games/ironspire/data/save.lua") then
    return nil
  end
  local h = fs.open("/games/ironspire/data/save.lua", "r")
  if not h then
    return nil
  end
  local data = h.readAll()
  h.close()
  local ok, s = pcall(textutils.unserialize, data)
  if ok and type(s) == "table" and type(s.deck) == "table" and type(s.hp) == "number" and type(s.floor) == "number" then
    return Map.migrate(s)
  end
  return nil
end
local function drawCards(s, n)
  for i = 1, n do
    if #s.draw == 0 then
      s.draw = s.discard
      s.discard = {}
      shuffle(s.draw)
    end
    if #s.draw == 0 then
      return
    end
    s.hand[#s.hand + 1] = table.remove(s.draw)
  end
end
local function beginTurn(s)
  s.energy = 3
  s.block = 0
  s.enemyBlock = s.enemyBlock or 0
  s.draw = s.draw or {}
  s.discard = s.discard or {}
  s.hand = {}
  s.turn = s.turn + 1
  drawCards(s, 5)
end
local function intent(s)
  local foe = s.enemy
  return foe.attacks[((s.turn - 1) % #foe.attacks) + 1]
end
local function startFight(s, boss)
  local template = FOES[boss and 4 or math.random(1, 3)]
  s.enemy = {
    name = template.name,
    hp = template.hp + (boss and 0 or math.max(0, s.floor - 3) * 2),
    maxhp = template.hp + (boss and 0 or math.max(0, s.floor - 3) * 2),
    block = 0,
    attacks = template.attacks,
    vulnerable = 0,
  }
  s.draw = copy(s.deck)
  shuffle(s.draw)
  s.discard = {}
  s.hand = {}
  s.turn = 0
  s.block = 0
  s.energy = 3
  s.screen = "combat"
  s.log = "An enemy approaches!"
  beginTurn(s)
end
local function winFight(s)
  s.gold = s.gold + (s.floor == 9 and 100 or 20 + math.random(8, 21))
  if s.floor == 9 then
    s.screen = "victory"
    s.log = "THE SPIRE IS YOURS!"
  else
    s.screen = "reward"
    s.rewards = {}
    local a = copy(POOL)
    shuffle(a)
    for i = 1, 3 do
      s.rewards[i] = a[i]
    end
    s.log = "Victory! Choose a card or skip."
  end
  s.enemy = nil
  s.hand = nil
  s.draw = nil
  s.discard = nil
  save(s)
end
local function play(s, index)
  if s.screen ~= "combat" then
    return
  end
  local key = s.hand[index]
  local card = C[key]
  if not card or s.energy < card.cost then
    s.log = "Not enough energy."
    return
  end
  s.energy = s.energy - card.cost
  table.remove(s.hand, index)
  local e = s.enemy
  for _ = 1, (card.hits or 1) do
    local damage = card.damage or 0
    if e.vulnerable > 0 then
      damage = math.floor(damage * 1.5)
    end
    local absorbed = math.min(e.block, damage)
    e.block = e.block - absorbed
    e.hp = e.hp - (damage - absorbed)
  end
  s.block = s.block + (card.block or 0)
  s.hp = math.min(s.maxhp, s.hp + (card.heal or 0))
  s.energy = s.energy + (card.energy or 0)
  if card.vuln then
    e.vulnerable = e.vulnerable + card.vuln
  end
  s.discard[#s.discard + 1] = key
  drawCards(s, card.draw or 0)
  s.log = card.name .. " played."
  if e.hp <= 0 then
    winFight(s)
  else
    save(s)
  end
end
local function endTurn(s)
  if s.screen ~= "combat" then
    return
  end
  local e = s.enemy
  local a = intent(s)
  local raw = a[2]
  -- Enemy block protects from player attacks, not enemy's own attack.
  local taken = math.max(0, raw - s.block)
  s.hp = s.hp - taken
  e.block = e.block + (a[3] or 0)
  if a[4] then
    s.maxhp = math.max(25, s.maxhp - a[4])
    s.hp = math.min(s.hp, s.maxhp)
  end
  e.vulnerable = math.max(0, e.vulnerable - 1)
  s.log = a[1] .. ": " .. taken .. " damage taken."
  if s.hp <= 0 then
    s.hp = 0
    s.screen = "defeat"
    save(s)
    return
  end
  for _, key in ipairs(s.hand) do
    s.discard[#s.discard + 1] = key
  end
  beginTurn(s)
  save(s)
end
local function advance(s, kind, lane)
  if s.screen ~= "map" then
    return false
  end
  Map.migrate(s)
  local target = s.floor + 1
  if not Map.reachable(s, target, lane or 2) then
    return false
  end
  local node = s.map[target][lane or 2]
  if node.kind ~= "boss" and node.kind ~= kind then
    return false
  end
  s.lane = lane or 2
  s.floor = target
  s.log = "Floor " .. s.floor .. "."
  if s.floor == 9 or kind == "battle" or kind == "elite" then
    startFight(s, s.floor == 9)
  elseif kind == "rest" then
    s.screen = "rest"
  elseif kind == "shop" then
    s.screen = "shop"
    s.shop = copy(POOL)
    shuffle(s.shop)
  else
    s.screen = "event"
  end
  save(s)
  return true
end
local function next(s)
  s.screen = "map"
  s.log = "Choose your next route."
  save(s)
end
local function fit(value, n)
  value = tostring(value or "")
  return #value > n and value:sub(1, math.max(0, n - 1)) .. "." or value
end
local UI = {}
UI.__index = UI
function UI.new(m, s)
  return setmetatable({ r = R.new(m), s = Map.migrate(s or new()), page = 1, quit = false, selectedCard = nil }, UI)
end
function UI:draw()
  local r = self.r
  local s = self.s
  r:begin()
  local w, h = r.w, r.h
  local margin = 7
  local function text(x, y, v, color, max)
    r:text(x, y, v, color or 7, 1, max or w - x - 5)
  end
  local function button(x, y, bw, bh, label, fn, opt)
    r:button(x, y, bw, bh, label, fn, opt)
  end
  local function tile(x, y, bw, bh, title, detail, fn, opt)
    r:fill(x, y, bw, bh, 2)
    r:outline(x, y, bw, bh, 3)
    text(x + 5, y + 5, title, 8, bw - 10)
    text(x + 5, y + 15, detail, 6, bw - 10)
    if fn then
      button(x + 4, y + bh - 15, bw - 8, 13, "SELECT", fn, opt)
    end
  end
  r:fill(0, 0, w, 19, 14)
  text(7, 6, "IRONSPIRE", 18, 70)
  text(math.max(81, w - 95), 6, "F" .. s.floor .. "  HP " .. s.hp .. "/" .. s.maxhp .. "  G" .. s.gold, 7, 90)
  local top = 25
  local bottom = h - 23
  if s.screen == "map" then
    Map.migrate(s)
    r:center(top, "THE CLOCKWORK ASCENT", 8)
    local cols = 3
    local gap = math.max(5, math.floor((w - 22) / 22))
    local bw = math.floor((w - 14 - gap * 2) / 3)
    local rowHeight = math.max(27, math.min(36, math.floor((bottom - top - 31) / 4)))
    local first = math.max(1, math.min(6, s.floor - 1))
    if s.floor >= 6 then
      first = math.max(1, s.floor - 2)
    end
    for floor = first, math.min(9, first + 3) do
      local y = top + 19 + (floor - first) * rowHeight
      local cy = y + 9
      for lane = 1, 3 do
        local node = s.map[floor][lane]
        local x = 7 + (lane - 1) * (bw + gap)
        local reachable = Map.reachable(s, floor, lane)
        local visited = floor <= s.floor and ((floor == s.floor and lane == s.lane) or false)
        local col = reachable and 11 or visited and 8 or node.kind == "closed" and 14 or 3
        if floor < 9 and floor >= s.floor then
          for nextLane = math.max(1, lane - 1), math.min(3, lane + 1) do
            if s.map[floor + 1][nextLane].kind ~= "closed" then
              local nx = 7 + (nextLane - 1) * (bw + gap) + math.floor(bw / 2)
              r:line(x + math.floor(bw / 2), cy + 11, nx, cy + rowHeight - 1, 4)
            end
          end
        end
        r:fill(x, y, bw, 22, reachable and 12 or visited and 16 or 2)
        r:outline(x, y, bw, 22, col)
        local label = ({
          battle = "FIGHT",
          elite = "ELITE",
          rest = "REST",
          shop = "SHOP",
          event = "EVENT",
          boss = "BOSS",
          closed = "--",
        })[node.kind]
        text(x + 3, y + 3, "F" .. floor .. " " .. label, reachable and 7 or 5, bw - 6)
        if reachable then
          button(x + 2, y + 11, bw - 4, 10, "GO >", function()
            advance(s, node.kind, lane)
          end, { primary = true })
        elseif visited then
          text(x + 4, y + 13, "YOU", 8, bw - 8)
        end
      end
    end
    text(8, bottom - 10, "GOLD: " .. s.gold .. "   SELECT A CONNECTED NODE", 6, w - 14)
  elseif s.screen == "combat" then
    local e = s.enemy
    local a = intent(s)
    r:center(top, e.name, 10)
    r:center(
      top + 12,
      "HP " .. math.max(0, e.hp) .. "/" .. e.maxhp .. "  BLOCK " .. e.block .. "  VULN " .. e.vulnerable,
      6
    )
    r:center(top + 25, "NEXT: " .. a[1] .. "  " .. a[2] .. " DMG" .. (a[3] and (" + " .. a[3] .. " BLOCK") or ""), 8)
    r:fill(7, top + 38, w - 14, 13, 3)
    r:fill(8, top + 39, math.floor((w - 16) * math.max(0, e.hp) / e.maxhp), 11, 10)
    text(8, top + 57, "ENERGY " .. s.energy .. "   BLOCK " .. s.block .. "   DRAW " .. #s.draw, 7)
    local handY = top + 72
    local cols = math.min(4, math.max(2, math.floor((w - 10) / 47)))
    local cardW = math.floor((w - 14 - 4 * (cols - 1)) / cols)
    local cardsPer = cols * 2
    local maxPage = math.max(1, math.ceil(#s.hand / cardsPer))
    self.page = math.min(self.page, maxPage)
    local first = (self.page - 1) * cardsPer + 1
    local available = math.max(31, bottom - handY - 19)
    local cardH = math.max(28, math.min(45, math.floor((available - 4) / 2)))
    for i = first, math.min(#s.hand, first + cardsPer - 1) do
      local offset = i - first
      local x = 7 + (offset % cols) * (cardW + 4)
      local y = handY + math.floor(offset / cols) * (cardH + 4)
      local c = C[s.hand[i]]
      if c then
        r:fill(x, y, cardW, cardH, s.energy >= c.cost and 2 or 14)
        r:outline(x, y, cardW, cardH, c.cost == 0 and 13 or 3)
        text(x + 3, y + 3, c.name, 8, cardW - 6)
        text(x + 3, y + 12, "ENERGY " .. c.cost, 7, cardW - 6)
        text(x + 3, y + 21, fit(c.desc, math.floor((cardW - 6) / 4)), 6, cardW - 6)
        button(x + 2, y + cardH - 12, math.floor((cardW - 6) / 2), 11, "?", function()
          self.selectedCard = i
        end)
        button(x + 4 + math.floor((cardW - 6) / 2), y + cardH - 12, math.floor((cardW - 6) / 2), 11, "PLAY", function()
          play(s, i)
          self.page = 1
          self.selectedCard = nil
        end, { primary = s.energy >= c.cost })
      end
    end
    if self.selectedCard and s.hand[self.selectedCard] then
      local card = C[s.hand[self.selectedCard]]
      local iy = top + 60
      r:fill(6, iy, w - 12, 42, 14)
      r:outline(6, iy, w - 12, 42, 8)
      text(12, iy + 4, card.name .. " - " .. card.cost .. " ENERGY", 18, w - 24)
      text(12, iy + 15, card.desc, 7, w - 24)
      text(
        12,
        iy + 25,
        "DAMAGE " .. (card.damage or 0) .. "  BLOCK " .. (card.block or 0) .. "  DRAW " .. (card.draw or 0),
        6,
        w - 24
      )
      button(w - 38, iy + 1, 29, 11, "CLOSE", function()
        self.selectedCard = nil
      end)
    end
    button(7, bottom - 14, math.floor((w - 22) / 3), 14, "< HAND", function()
      self.page = math.max(1, self.page - 1)
    end)
    button(12 + math.floor((w - 22) / 3), bottom - 14, math.floor((w - 22) / 3), 14, "END TURN", function()
      endTurn(s)
      self.page = 1
    end, { primary = true })
    button(17 + 2 * math.floor((w - 22) / 3), bottom - 14, math.floor((w - 22) / 3), 14, "HAND >", function()
      self.page = math.min(maxPage, self.page + 1)
    end)
  elseif s.screen == "reward" then
    r:center(top, "CHOOSE A NEW CARD", 8)
    local bw = math.floor((w - 24) / 3)
    for i, key in ipairs(s.rewards) do
      local c = C[key]
      local x = 7 + (i - 1) * (bw + 5)
      tile(x, top + 22, bw, math.min(88, bottom - top - 32), c.name, "E" .. c.cost .. " " .. c.desc, function()
        s.deck[#s.deck + 1] = key
        next(s)
      end)
    end
    button(7, bottom - 15, w - 14, 14, "SKIP CARD", function()
      next(s)
    end)
  elseif s.screen == "rest" then
    r:center(top, "A QUIET FORGE", 8)
    tile(7, top + 21, math.floor((w - 19) / 2), 79, "REST", "+22 HP", function()
      s.hp = math.min(s.maxhp, s.hp + 22)
      next(s)
    end)
    local x = 12 + math.floor((w - 19) / 2)
    tile(x, top + 21, math.floor((w - 19) / 2), 79, "TRAIN", "+4 MAX HP", function()
      s.maxhp = s.maxhp + 4
      s.hp = s.hp + 4
      next(s)
    end)
  elseif s.screen == "shop" then
    r:center(top, "TRAVELLING MERCHANT", 8)
    local bw = math.floor((w - 24) / 3)
    for i = 1, 3 do
      local key = s.shop[i]
      local c = key and C[key]
      local x = 7 + (i - 1) * (bw + 5)
      if c then
        tile(x, top + 20, bw, 78, c.name, "50 GOLD", function()
          if s.gold >= 50 then
            s.gold = s.gold - 50
            s.deck[#s.deck + 1] = key
            s.shop[i] = false
            s.log = "Card purchased."
            save(s)
          else
            s.log = "Not enough gold."
          end
        end)
      else
        tile(x, top + 20, bw, 78, "SOLD OUT", "")
      end
    end
    button(7, bottom - 32, math.floor((w - 19) / 2), 14, "HEAL 12 / 30G", function()
      if s.gold >= 30 then
        s.gold = s.gold - 30
        s.hp = math.min(s.maxhp, s.hp + 12)
        save(s)
      else
        s.log = "Not enough gold."
      end
    end)
    button(12 + math.floor((w - 19) / 2), bottom - 32, math.floor((w - 19) / 2), 14, "REMOVE / 40G", function()
      if s.gold >= 40 and #s.deck > 1 then
        s.gold = s.gold - 40
        table.remove(s.deck, 1)
        s.log = "Removed first deck card."
        save(s)
      else
        s.log = "Need 40 gold."
      end
    end)
    button(7, bottom - 14, w - 14, 14, "LEAVE SHOP", function()
      next(s)
    end)
  elseif s.screen == "event" then
    r:center(top, "ABANDONED WORKSHOP", 8)
    r:center(top + 18, "A strange machine hums.", 6)
    button(7, top + 43, w - 14, 20, "SCAVENGE: +35 GOLD / -7 HP", function()
      s.gold = s.gold + 35
      s.hp = math.max(1, s.hp - 7)
      next(s)
    end)
    button(7, top + 68, w - 14, 20, "WALK AWAY", function()
      next(s)
    end)
  elseif s.screen == "victory" or s.screen == "defeat" then
    r:center(top + 20, s.screen == "victory" and "SPIRE CONQUERED" or "THE END", s.screen == "victory" and 11 or 10)
    r:center(top + 43, "FLOOR " .. s.floor .. "  DECK " .. #s.deck, 6)
    button(7, top + 72, w - 14, 20, "NEW EXPEDITION", function()
      self.s = new()
      save(self.s)
    end, { primary = true })
  else
    r:center(top, "IRONSPIRE", 8)
    button(7, top + 28, w - 14, 22, "NEW EXPEDITION", function()
      self.s = new()
      save(self.s)
    end, { primary = true })
    if loadSave() then
      button(7, top + 57, w - 14, 20, "CONTINUE", function()
        self.s = loadSave() or new()
      end)
    end
  end
  r:fill(0, h - 17, w, 17, 14)
  text(5, h - 12, fit(s.log, math.floor((w - 10) / 4)), 6, w - 10)
  r:finish()
end
function UI:touch(x, y)
  local vx, vy = self.r:touch(x, y)
  if vx then
    self.r:hit(vx, vy)
  end
  self:draw()
end
function UI:close()
  self.r:close()
end
local API = {
  new = new,
  play = play,
  endTurn = endTurn,
  advance = advance,
  startFight = startFight,
  UI = UI,
  cards = C,
  Map = Map,
  save = save,
  load = loadSave,
}
if args[1] == "--test-api" then
  return API
end
local monitor, name
if peripheral and peripheral.getNames then
  if args[1] then
    monitor = peripheral.wrap(args[1])
    assert(monitor and monitor.getSize, "Monitor not found")
    name = args[1]
  else
    local area = 0
    for _, id in ipairs(peripheral.getNames()) do
      if peripheral.getType(id) == "monitor" then
        local m = peripheral.wrap(id)
        local w, h = m.getSize()
        if w * h > area then
          area = w * h
          monitor = m
          name = id
        end
      end
    end
  end
end
monitor = monitor or (term and term.current and term.current())
assert(monitor, "No monitor or terminal found")
local oldScale = monitor.getTextScale and monitor.getTextScale()
if monitor.setTextScale then
  pcall(monitor.setTextScale, 0.5)
end
local app = UI.new(
  monitor,
  loadSave()
    or { screen = "title", hp = 72, maxhp = 72, floor = 0, gold = 75, deck = {}, log = "A DECKBUILDING ADVENTURE" }
)
local ok, err = xpcall(function()
  while not app.quit do
    app:draw()
    local event, a, b, c = os.pullEvent()
    if event == "monitor_touch" and (not name or name == a) then
      app:touch(b, c)
    elseif event == "mouse_click" and not name then
      app:touch(b, c)
    elseif event == "monitor_resize" or event == "term_resize" then
      app.r:resize()
    elseif event == "key" and keys and a == keys.q then
      app.quit = true
    end
  end
end, function(e)
  return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
app:close()
if oldScale and monitor.setTextScale then
  pcall(monitor.setTextScale, oldScale)
end
if not ok then
  error(err, 0)
end
