-- TIDEBOUND v1.0: Two-player strategy for CC:Tweaked. Run: tidebound [monitor-side].

local argv = { ... }
-- Standalone Lua interpreters expose CLI parameters through arg rather than varargs.
if #argv == 0 and type(arg) == "table" and arg[1] then argv[1] = arg[1] end
local GRID, MAX_ROUNDS, TARGET = 9, 20, 12
local MOVES = { sail = 2, dash = 4 }
local COST = { sail = 0, dash = 2, cannon = 1, shell = 3, claim = 0, repair = 3 }
local LABEL = { sail = "SAIL", dash = "DASH", cannon = "CANNON", shell = "SHELL", claim = "CLAIM", repair = "REPAIR" }
local RED, BLUE = 1, 2
local portPositions = { {5, 2}, {5, 5}, {5, 8} }
local obstaclePairs = {
  {3, 1}, {4, 1}, {3, 3}, {4, 3}, {3, 7},
  {4, 7}, {3, 9}, {4, 9}, {5, 4}, {3, 5},
}

local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = deepcopy(x) end
  return out
end

local function dist(ax, ay, bx, by)
  return math.abs(ax - bx) + math.abs(ay - by)
end
local function key(x, y) return x .. ":" .. y end
local function inside(x, y) return x >= 1 and x <= GRID and y >= 1 and y <= GRID end
local function at(g, x, y)
  for _, u in ipairs(g.ships) do
    if u.hp > 0 and u.x == x and u.y == y then return u end
  end
end
local function findShip(g, id)
  for _, u in ipairs(g.ships) do if u.id == id then return u end end
end
local function portAt(g, x, y)
  for _, p in ipairs(g.ports) do if p.x == x and p.y == y then return p end end
end
local function ownedPorts(g, team)
  local n = 0
  for _, p in ipairs(g.ports) do if p.owner == team then n = n + 1 end end
  return n
end
local function remainingHull(g, team)
  local h = 0
  for _, u in ipairs(g.ships) do if u.team == team then h = h + math.max(0, u.hp) end end
  return h
end

local function makeGame(seed)
  math.randomseed(seed or 1)
  local g = {
    version = 1, seed = seed or 1, board = {}, ports = {}, ships = {},
    round = 1, turn = 1, ap = 2, steam = {3, 3}, vp = {0, 0},
    winner = nil, history = {}, log = "Select a ship, then choose an action.",
  }
  for y = 1, GRID do
    g.board[y] = {}
    for x = 1, GRID do g.board[y][x] = "water" end
  end
  for _, pos in ipairs(portPositions) do
    local x, y = pos[1], pos[2]
    g.board[y][x] = "port"
    g.ports[#g.ports + 1] = { x = x, y = y, owner = 0 }
  end
  -- Fair, symmetric terrain.
  local possible = deepcopy(obstaclePairs)
  for i = #possible, 2, -1 do
    local j = math.random(i)
    possible[i], possible[j] = possible[j], possible[i]
  end
  local function passableCrossings()
    local seen = {[key(2, 5)] = true}
    local queue = {{2, 5}}
    local head = 1
    while head <= #queue do
      local node = queue[head]
      head = head + 1
      for _, step in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local x, y = node[1] + step[1], node[2] + step[2]
        local k = key(x, y)
        if inside(x, y) and not seen[k] and g.board[y][x] == "water" then
          seen[k] = true
          queue[#queue + 1] = {x, y}
        end
      end
    end
    for _, port in ipairs(g.ports) do
      if not seen[key(4, port.y)] or not seen[key(6, port.y)] then return false end
    end
    return true
  end
  for i = 1, 3 do
    local pos = possible[i]
    local x, y = pos[1], pos[2]
    g.board[y][x] = "island"
    g.board[GRID + 1 - y][GRID + 1 - x] = "island"
  end
  -- Reject obstacles which isolate parts of the ocean; both players must reach every port.
  for i = 3, 1, -1 do
    if passableCrossings() then break end
    local pos = possible[i]
    local x, y = pos[1], pos[2]
    g.board[y][x] = "water"
    g.board[GRID + 1 - y][GRID + 1 - x] = "water"
  end
  local definitions = {
    {RED, "Cutter", 2, 3, 3}, {RED, "Flagship", 2, 5, 4}, {RED, "Cutter", 2, 7, 3},
    {BLUE, "Cutter", 8, 3, 3}, {BLUE, "Flagship", 8, 5, 4}, {BLUE, "Cutter", 8, 7, 3},
  }
  for i, info in ipairs(definitions) do
    g.ships[i] = { id = i, team = info[1], kind = info[2], x = info[3], y = info[4],
      hp = info[5], maxhp = info[5], fired = false }
  end
  return g
end

-- Movement is flood-fill, not a Manhattan-distance teleport; islands and ships obstruct paths.
local function reachable(g, ship, maxSteps)
  local found = {}
  local queue = { {ship.x, ship.y, 0} }
  local visited = { [key(ship.x, ship.y)] = true }
  local head = 1
  while head <= #queue do
    local node = queue[head]
    head = head + 1
    if node[3] < maxSteps then
      local neighbors = {
        {node[1] + 1, node[2]}, {node[1] - 1, node[2]},
        {node[1], node[2] + 1}, {node[1], node[2] - 1},
      }
      for _, p in ipairs(neighbors) do
        local x, y = p[1], p[2]
        local k = key(x, y)
        if inside(x, y) and not visited[k] and g.board[y][x] == "water" and not at(g, x, y) then
          visited[k] = true
          found[k] = true
          queue[#queue + 1] = {x, y, node[3] + 1}
        end
      end
    end
  end
  return found
end

-- Bresenham line-of-sight: shells, cannons and enemy units cannot shoot through terrain/ships.
local function clearShot(g, ship, target)
  local x0, y0, x1, y1 = ship.x, ship.y, target.x, target.y
  local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
  local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
  local err = dx - dy
  while x0 ~= x1 or y0 ~= y1 do
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
    if x0 ~= x1 or y0 ~= y1 then
      if g.board[y0][x0] ~= "water" or at(g, x0, y0) then return false end
    end
  end
  return true
end

local function legalTargets(g, ship, action)
  local legal = {}
  if not ship or g.winner or g.ap < 1 or ship.team ~= g.turn or ship.hp <= 0 then return legal end
  if g.steam[g.turn] < (COST[action] or math.huge) then return legal end
  if MOVES[action] then return reachable(g, ship, MOVES[action]) end
  if action == "cannon" or action == "shell" then
    if ship.fired then return legal end
    for _, enemy in ipairs(g.ships) do
      if enemy.team ~= g.turn and enemy.hp > 0 then
        local d = dist(ship.x, ship.y, enemy.x, enemy.y)
        local within = action == "cannon" and d <= 3
          or action == "shell" and d <= 4 and (ship.x == enemy.x or ship.y == enemy.y)
        if within and clearShot(g, ship, enemy) then legal[key(enemy.x, enemy.y)] = true end
      end
    end
  elseif action == "claim" then
    for _, p in ipairs(g.ports) do
      if p.owner ~= g.turn and dist(ship.x, ship.y, p.x, p.y) == 1 then
        legal[key(p.x, p.y)] = true
      end
    end
  elseif action == "repair" and ship.hp < ship.maxhp then
    legal[key(ship.x, ship.y)] = true
  end
  return legal
end

local function snapshot(g)
  local copy = deepcopy(g)
  copy.history = {}
  return copy
end

local function checkFleetVictory(g, team)
  local other = 3 - team
  local shipsLeft, flagship = 0, false
  for _, u in ipairs(g.ships) do
    if u.team == other and u.hp > 0 then
      shipsLeft = shipsLeft + 1
      if u.kind == "Flagship" then flagship = true end
    end
  end
  if not flagship or shipsLeft == 0 then g.winner = team end
end

local function perform(g, id, action, x, y)
  local ship = findShip(g, id)
  if not ship then return false, "No ship selected." end
  if not legalTargets(g, ship, action)[key(x, y)] then return false, "That action is not available there." end
  g.history[#g.history + 1] = snapshot(g)
  local team = g.turn
  g.steam[team] = g.steam[team] - COST[action]
  g.ap = g.ap - 1
  if action == "sail" or action == "dash" then
    ship.x, ship.y = x, y
    g.log = ship.kind .. " sailed to " .. string.char(64 + x) .. y .. "."
  elseif action == "cannon" or action == "shell" then
    local enemy = at(g, x, y)
    local damage = action == "shell" and 2 or 1
    enemy.hp = math.max(0, enemy.hp - damage)
    ship.fired = true
    if enemy.hp == 0 then
      g.log = "Direct hit! Enemy " .. enemy.kind .. " sunk."
      checkFleetVictory(g, team)
    else
      g.log = "Hit! Enemy " .. enemy.kind .. " has " .. enemy.hp .. " hull."
    end
  elseif action == "claim" then
    local p = portAt(g, x, y)
    p.owner = team
    g.log = (team == RED and "Crimson" or "Azure") .. " captured an outpost!"
  elseif action == "repair" then
    ship.hp = ship.hp + 1
    g.log = ship.kind .. " repaired 1 hull."
  end
  return true
end

local function undo(g)
  local n = #g.history
  if n == 0 or g.winner then return g, false end
  local old = g.history[n]
  local stack = g.history
  stack[n] = nil
  old.history = stack
  old.log = "Last action undone."
  return old, true
end

local function endTurn(g)
  if g.winner then return end
  g.history = {}
  if g.turn == RED then
    g.turn = BLUE
    g.log = "Azure fleet's turn."
  else
    for team = RED, BLUE do g.vp[team] = g.vp[team] + ownedPorts(g, team) end
    if g.vp[RED] >= TARGET or g.vp[BLUE] >= TARGET or g.round >= MAX_ROUNDS then
      if g.vp[RED] > g.vp[BLUE] then g.winner = RED
      elseif g.vp[BLUE] > g.vp[RED] then g.winner = BLUE
      elseif remainingHull(g, RED) > remainingHull(g, BLUE) then g.winner = RED
      elseif remainingHull(g, BLUE) > remainingHull(g, RED) then g.winner = BLUE
      else g.winner = 3 end
      g.log = "The campaign is over."
      return
    end
    g.round = g.round + 1
    g.turn = RED
    g.log = "New round! Crimson fleet's turn."
  end
  g.ap = 2
  for _, u in ipairs(g.ships) do
    if u.team == g.turn then u.fired = false end
  end
  if g.round > 1 then
    g.steam[g.turn] = math.min(8, g.steam[g.turn] + 2 + ownedPorts(g, g.turn))
  end
end

-- Buffered monitor renderer.
local G = {
  white = "0", orange = "1", cyan = "9", red = "e", yellow = "4",
  water = "b", land = "d", sand = "c", black = "f", gray = "7",
  muted = "8", green = "5", lightBlue = "3", purple = "a",
}
local theme = {
  {"black", 0x101B26}, {"blue", 0x15374B}, {"gray", 0x283B48},
  {"lightGray", 0x91A7AE}, {"white", 0xF2E9D5}, {"red", 0xF6796D},
  {"cyan", 0x6FD3DB}, {"green", 0x3C644E}, {"lime", 0x79BF84},
  {"brown", 0x81694B}, {"yellow", 0xEEC777}, {"orange", 0xE9A75F},
  {"lightBlue", 0x7D9DCA}, {"purple", 0x937FBF},
}
local Buffer = {}
Buffer.__index = Buffer
function Buffer.new(w, h)
  local self = setmetatable({w = w, h = h, rows = {}}, Buffer)
  for y = 1, h do
    local c, f, b = {}, {}, {}
    for x = 1, w do c[x] = " "; f[x] = G.white; b[x] = G.black end
    self.rows[y] = {c, f, b}
  end
  return self
end
function Buffer:put(x, y, str, fg, bg)
  if y < 1 or y > self.h then return end
  str = tostring(str or "")
  local row = self.rows[y]
  for i = 1, #str do
    local xx = x + i - 1
    if xx >= 1 and xx <= self.w then
      row[1][xx] = str:sub(i, i)
      if fg then row[2][xx] = fg end
      if bg then row[3][xx] = bg end
    end
  end
end
function Buffer:fill(x, y, w, h, bg, ch, fg)
  for yy = math.max(1, y), math.min(self.h, y + h - 1) do
    local row = self.rows[yy]
    for xx = math.max(1, x), math.min(self.w, x + w - 1) do
      row[1][xx] = ch or " "
      row[2][xx] = fg or G.white
      row[3][xx] = bg
    end
  end
end
function Buffer:center(y, msg, fg, bg)
  self:put(math.floor((self.w - #msg) / 2) + 1, y, msg, fg, bg)
end
function Buffer:flush(m)
  for y = 1, self.h do
    local row = self.rows[y]
    m.setCursorPos(1, y)
    m.blit(table.concat(row[1]), table.concat(row[2]), table.concat(row[3]))
  end
end

local function tone(team) return team == RED and G.red or G.cyan end
local function teamName(team) return team == RED and "CRIMSON" or "AZURE" end
local function padText(t, width)
  t = tostring(t)
  if #t > width then return t:sub(1, math.max(0, width - 1)) .. "." end
  return t .. string.rep(" ", math.max(0, width - #t))
end

local function uiNew()
  return { page = "menu", selected = nil, action = nil, buttons = {},
    bx = nil, by = nil, layout = nil, game = nil, saveOk = true }
end
local function hit(ui, x, y, w, h, f, tag)
  ui.buttons[#ui.buttons + 1] = {x = x, y = y, w = w, h = h, fn = f, tag = tag}
end
local function btn(b, ui, x, y, w, h, label, enabled, selected, callback)
  if w < 3 or h < 1 then return end
  local bg = selected and G.yellow or enabled and G.gray or G.black
  local fg = selected and G.black or enabled and G.white or G.muted
  b:fill(x, y, w, h, bg)
  if enabled then
    b:put(x, y, string.rep("=", w), G.muted, bg)
    if h >= 3 then b:put(x, y + h - 1, string.rep("=", w), G.muted, bg) end
    hit(ui, x, y, w, h, callback, label)
  end
  local yy = y + math.floor((h - 1) / 2)
  b:put(x + math.floor((w - math.min(#label, w - 2)) / 2), yy,
    label:sub(1, math.max(0, w - 2)), fg, bg)
end
local function canUse(g, ship, action)
  if not ship or ship.team ~= g.turn or g.ap <= 0 then return false end
  return next(legalTargets(g, ship, action)) ~= nil
end
local function drawMap(b, ui, g, bx, by)
  ui.bx, ui.by = bx, by
  local selected = findShip(g, ui.selected)
  local available = selected and ui.action and legalTargets(g, selected, ui.action) or {}
  for y = 1, GRID do
    for x = 1, GRID do
      local xx, yy = bx + (x - 1) * 3, by + (y - 1) * 2
      local tile = g.board[y][x]
      local p = portAt(g, x, y)
      local ship = at(g, x, y)
      local bg = tile == "island" and G.land or tile == "port" and G.sand or G.water
      local k = key(x, y)
      local active = available[k]
      if active then
        if ui.action == "claim" then bg = G.yellow
        elseif ui.action == "cannon" or ui.action == "shell" then bg = G.red
        elseif ui.action == "repair" then bg = G.green
        else bg = G.land end
      end
      if ship and ship.id == ui.selected and not active then bg = G.gray end
      b:fill(xx, yy, 3, 2, bg)
      if p then
        local sign = p.owner == 0 and "o" or p.owner == RED and "R" or "B"
        b:put(xx, yy, "[" .. sign .. "]", p.owner == 0 and G.white or tone(p.owner), bg)
        b:put(xx, yy + 1, "###", G.yellow, bg)
      elseif ship then
        local letter = ship.kind == "Flagship" and "F" or "C"
        b:put(xx, yy, "<" .. letter .. ">", tone(ship.team), bg)
        b:put(xx, yy + 1, " " .. ship.hp .. (ship.fired and "*" or " "),
          ship.id == ui.selected and G.yellow or G.white, bg)
      elseif tile == "island" then
        b:put(xx, yy, "^^^", G.green, bg)
        b:put(xx, yy + 1, ":::", G.sand, bg)
      elseif active then
        b:put(xx, yy, " + ", G.white, bg)
        b:put(xx, yy + 1, "...", G.white, bg)
      else
        local ripple = (x * 5 + y * 13 + g.seed) % 7 == 0 and "~" or " "
        b:put(xx, yy, " " .. ripple .. " ", G.lightBlue, bg)
        if y % 2 == 0 and x % 3 == 0 then b:put(xx, yy + 1, "  .", G.muted, bg) end
      end
    end
  end
  -- Grid label strips don't occupy any touch cells.
  for x = 1, GRID do
    b:put(bx + (x - 1) * 3 + 1, by - 1, string.char(64 + x), G.muted)
  end
end
local function drawHeader(b, g)
  b:fill(1, 1, b.w, 1, G.gray)
  b:put(2, 1, "TIDEBOUND", G.yellow, G.gray)
  b:put(math.max(12, b.w - 11), 1, "ROUND " .. g.round .. "/" .. MAX_ROUNDS, G.white, G.gray)
  local right = "AZURE " .. g.vp[BLUE] .. "/" .. TARGET
  b:put(2, 2, "CRIMSON " .. g.vp[RED] .. "/" .. TARGET, G.red)
  b:put(math.max(18, b.w - #right - 1), 2, right, G.cyan)
  local msg = teamName(g.turn) .. " TURN | " .. g.ap .. " AP | " .. g.steam[g.turn] .. " STEAM"
  b:put(2, 3, msg, tone(g.turn))
  b:put(2, 4, string.rep("-", b.w - 3), G.gray)
end
local function drawSelection(b, ui, g, x, y, w)
  local ship = findShip(g, ui.selected)
  b:put(x, y, teamName(g.turn) .. " COMMAND", tone(g.turn))
  if ship and ship.team == g.turn and ship.hp > 0 then
    b:put(x, y + 1, padText(ship.kind .. " | " .. ship.hp .. "/" .. ship.maxhp .. " HULL", w), G.white)
    local detail = ship.fired and "Cannon spent this turn" or "Ready to fire"
    b:put(x, y + 2, padText(detail, w), G.muted)
  else
    b:put(x, y + 1, "Tap one of your ships", G.white)
    b:put(x, y + 2, "to select its commands.", G.muted)
  end
end
local order = { "sail", "dash", "cannon", "shell", "claim", "repair" }
local function drawActions(b, ui, g, x, y, columns, width, bh, spacing)
  local ship = findShip(g, ui.selected)
  for i, action in ipairs(order) do
    local col = (i - 1) % columns
    local row = math.floor((i - 1) / columns)
    local xx = x + col * (width + 1)
    local yy = y + row * (bh + spacing)
    local enabled = canUse(g, ship, action)
    local label = LABEL[action]
    if COST[action] > 0 then label = label .. " " .. COST[action] end
    btn(b, ui, xx, yy, width, bh, label, enabled, ui.action == action,
      function()
        if ui.action == action then ui.action = nil else ui.action = action end
        ui.game.log = ui.action and (LABEL[action] .. ": tap a highlighted tile.")
          or "Choose an action."
      end)
  end
end
local function gameDraw(b, ui)
  local g = ui.game
  if b.w < 34 or b.h < 31 or (b.w < 55 and b.h < 36) then
    b:center(math.max(2, math.floor(b.h / 2) - 2), "DISPLAY TOO SMALL", G.red)
    b:center(math.max(3, math.floor(b.h / 2)), "Use 3x3 advanced monitors", G.white)
    b:center(math.max(4, math.floor(b.h / 2) + 1), "and text scale 0.5", G.muted)
    return
  end
  drawHeader(b, g)
  local side = b.w >= 55 and b.h >= 31
  ui.layout = side and "side" or "stack"
  local bx = side and (math.floor((b.w - 57) / 2) + 2) or math.floor((b.w - 27) / 2) + 1
  local by = side and 6 or 5
  drawMap(b, ui, g, bx, by)
  if side then
    local x = bx + 29
    local cw = math.min(13, math.floor((b.w - x) / 2))
    cw = math.max(9, cw)
    b:fill(x - 1, 5, b.w - x + 2, math.min(b.h - 5, 26), G.black)
    drawSelection(b, ui, g, x, 6, b.w - x)
    drawActions(b, ui, g, x, 12, 2, cw, 3, 1)
    local bw = math.floor((b.w - x - 1) / 2)
    btn(b, ui, x, 25, bw, 3, "END TURN", true, false, function()
      endTurn(g); ui.selected = nil; ui.action = nil
    end)
    btn(b, ui, x + bw + 1, 25, bw, 3, "UNDO", #g.history > 0, false, function()
      local restored = undo(ui.game)
      ui.game = restored; ui.action = nil
    end)
    btn(b, ui, x, 29, bw, 2, "RULES", true, false, function() ui.page = "rules" end)
    btn(b, ui, x + bw + 1, 29, bw, 2, "MENU", true, false, function() ui.page = "confirm" end)
    b:put(bx, 25, padText(g.log, 27), G.yellow)
    b:put(bx, 27, "F=Flagship  C=Cutter", G.muted)
    b:put(bx, 28, "[o]=Outpost  *=Fired", G.muted)
    b:put(bx, 30, "Select -> Action -> Tile", G.white)
  else
    local ax = 2
    local bw = math.floor((b.w - 6) / 3)
    drawActions(b, ui, g, ax, 25, 3, bw, 2, 1)
    b:put(2, 23, padText(g.log, b.w - 3), G.yellow)
    local ship = findShip(g, ui.selected)
    b:put(2, 24, ship and (ship.kind .. " " .. ship.hp .. "/" .. ship.maxhp .. " HP") or "Tap a ship to select it.", G.white)
    btn(b, ui, 2, 31, math.floor((b.w - 3) / 2), 2, "END TURN", true, false, function()
      endTurn(g); ui.selected = nil; ui.action = nil
    end)
    btn(b, ui, 3 + math.floor((b.w - 3) / 2), 31,
      math.floor((b.w - 3) / 2), 2, "UNDO", #g.history > 0, false, function()
        ui.game = (undo(ui.game)); ui.action = nil
      end)
    local w = math.floor((b.w - 3) / 2)
    btn(b, ui, 2, 34, w, 2, "RULES", true, false, function() ui.page = "rules" end)
    btn(b, ui, 3 + w, 34, w, 2, "MENU", true, false, function() ui.page = "confirm" end)
  end
  if not ui.saveOk then b:put(2, b.h, "SAVE ERROR: storage unavailable", G.red) end
end

local function simplePage(b, ui, title, lines, buttons)
  local w = math.min(b.w - 4, 45)
  local x = math.floor((b.w - w) / 2) + 1
  local y = math.max(2, math.floor(b.h / 2) - 12)
  b:fill(x, y, w, math.min(b.h - y + 1, 27), G.gray)
  b:fill(x, y, w, 2, G.water)
  b:put(x + 2, y, title, G.yellow, G.water)
  for i, line in ipairs(lines) do
    local yy = y + 3 + i
    if yy < b.h - 5 then b:put(x + 2, yy, line:sub(1, w - 4), G.white, G.gray) end
  end
  local by = math.min(b.h - 3, y + 5 + #lines + 2)
  for i, button in ipairs(buttons) do
    local bw = math.floor((w - 2 - (#buttons - 1)) / #buttons)
    local xx = x + 1 + (i - 1) * (bw + 1)
    btn(b, ui, xx, by, bw, 3, button[1], true, false, button[2])
  end
end
local function drawMenu(b, ui, resume)
  local lines = {
    "   TWO FLEETS. THREE OUTPOSTS.",
    "   ONE ARCHIPELAGO TO RULE.",
    "",
    "A 2-player tactical tabletop duel.",
    "Sail, bombard, capture, repair.",
    "All controls are on the monitor.",
    "",
    "A 3x3 monitor is recommended.",
  }
  simplePage(b, ui, " TIDEBOUND  /  1.0", lines, {
    {resume and "RESUME" or "NEW GAME", function()
      if resume then ui.page = "game" else ui.page = "new" end
    end},
    {"RULES", function() ui.page = "rules" end},
  })
  if resume then
    btn(b, ui, math.floor((b.w - 23) / 2) + 1, math.min(b.h - 3, 31), 23, 2,
      "START A NEW MATCH", true, false, function() ui.page = "new" end)
  end
end
local function drawRules(b, ui)
  simplePage(b, ui, " HOW TO PLAY", {
    "Tap a friendly ship, choose an action,",
    "then tap a highlighted target.",
    "Each turn: 2 actions (AP).",
    "",
    "SAIL     Move up to 2 water tiles",
    "DASH 2   Move up to 4 water tiles",
    "CANNON 1 Range 3; deals 1 damage",
    "SHELL 3  Straight range 4; 2 damage",
    "CLAIM    Capture adjacent outposts",
    "REPAIR 3 Restore 1 hull anywhere",
    "",
    "Numbers above show STEAM costs.",
    "Each ship can fire once per turn.",
    "Terrain and ships block shots.",
    "Earn 2 steam + 1 per owned outpost",
    "each turn after round 1 (max 8).",
    "",
    "After both turns, each owned",
    "outpost awards 1 victory point.",
    "First to 12 points wins, or sink",
    "the enemy Flagship. 20-round cap.",
    "UNDO reverses your last action.",
  }, {
    {"BACK", function() ui.page = ui.game and (ui.game.winner and "over" or "game") or "menu" end},
  })
end
local function drawConfirm(b, ui)
  simplePage(b, ui, " LEAVE THIS MATCH?", {
    "Your current match is autosaved.",
    "You can resume it from the menu.",
  }, {
    {"KEEP PLAYING", function() ui.page = "game" end},
    {"MAIN MENU", function() ui.page = "menu" end},
  })
end
local function drawNew(b, ui)
  simplePage(b, ui, " BEGIN A NEW MATCH?", {
    "A new game will replace any",
    "previously autosaved match.",
    "The islands change every time.",
  }, {
    {"CANCEL", function() ui.page = ui.game and "menu" or "menu" end},
    {"START", function()
      local seed = (os.epoch and os.epoch("utc") or (os.time() * 7319 + math.random(10000))) % 2147483646 + 1
      ui.game = makeGame(seed); ui.selected = nil; ui.action = nil; ui.page = "game"
    end},
  })
end
local function drawOver(b, ui)
  local g = ui.game
  local victory = g.winner == 3 and "DRAW GAME" or teamName(g.winner) .. " VICTORY!"
  simplePage(b, ui, " CAMPAIGN COMPLETE", {
    "", "            " .. victory,
    "", "CRIMSON: " .. g.vp[RED] .. " POINTS",
    "AZURE:   " .. g.vp[BLUE] .. " POINTS",
    "", "Rounds played: " .. g.round,
    "Sinking the flagship ends the match.",
  }, {
    {"NEW MATCH", function() ui.page = "new" end},
    {"MAIN MENU", function() ui.page = "menu" end},
  })
end
local function render(m, ui)
  local w, h = m.getSize()
  local b = Buffer.new(w, h)
  ui.buttons = {}
  ui.bx, ui.by = nil, nil
  if ui.page == "game" and ui.game and not ui.game.winner then gameDraw(b, ui)
  elseif ui.page == "game" and ui.game and ui.game.winner then ui.page = "over"; drawOver(b, ui)
  elseif ui.page == "over" then drawOver(b, ui)
  elseif ui.page == "rules" then drawRules(b, ui)
  elseif ui.page == "confirm" then drawConfirm(b, ui)
  elseif ui.page == "new" then drawNew(b, ui)
  else drawMenu(b, ui, ui.game ~= nil) end
  b:flush(m)
  return b
end
local function onMapTouch(ui, tx, ty)
  local g = ui.game
  local ship = at(g, tx, ty)
  if ship and ship.team == g.turn then
    if ui.action == "repair" and ship.id == ui.selected and canUse(g, ship, "repair") then
      perform(g, ship.id, "repair", tx, ty); ui.action = nil
      return "action"
    end
    ui.selected = ship.id
    ui.action = nil
    g.log = ship.kind .. " selected. Choose a command."
    return "select"
  end
  if ui.selected and ui.action then
    local success, why = perform(g, ui.selected, ui.action, tx, ty)
    if success then ui.action = nil; return "action" end
    g.log = why
    return "invalid"
  end
  if ship then
    g.log = "Enemy " .. ship.kind .. ": " .. ship.hp .. " hull."
  else
    local p = portAt(g, tx, ty)
    if p then g.log = "Outpost: " .. (p.owner == 0 and "neutral" or teamName(p.owner)) .. "." end
  end
  return "inspect"
end
local function touch(ui, x, y)
  for i = #ui.buttons, 1, -1 do
    local t = ui.buttons[i]
    if x >= t.x and x < t.x + t.w and y >= t.y and y < t.y + t.h then
      t.fn()
      return t.tag
    end
  end
  if ui.page == "game" and ui.game and ui.bx and ui.by then
    local gx = math.floor((x - ui.bx) / 3) + 1
    local gy = math.floor((y - ui.by) / 2) + 1
    if inside(gx, gy) then return onMapTouch(ui, gx, gy) end
  end
  return nil
end

local function validSave(g)
  if type(g) ~= "table" or g.version ~= 1 or type(g.board) ~= "table"
    or type(g.ships) ~= "table" or #g.ships ~= 6 or type(g.ports) ~= "table"
    or #g.ports ~= 3 or type(g.steam) ~= "table" or type(g.vp) ~= "table"
    or (g.turn ~= RED and g.turn ~= BLUE) then return false end
  for y = 1, GRID do
    if type(g.board[y]) ~= "table" then return false end
    for x = 1, GRID do
      if g.board[y][x] ~= "water" and g.board[y][x] ~= "port" and g.board[y][x] ~= "island" then return false end
    end
  end
  return true
end
local function savePath()
  local script = shell and shell.getRunningProgram and shell.getRunningProgram() or "tidebound.lua"
  local dir = fs.getDir(script)
  return fs.combine(dir, "tidebound.save")
end
local function saveGame(g)
  if not fs or not textutils then return false end
  local ok = pcall(function()
    local path = savePath()
    local temp, backup = path .. ".tmp", path .. ".bak"
    local file = assert(fs.open(temp, "w"))
    file.write(textutils.serialize(g))
    file.close()
    -- Keep a recoverable previous save if the computer stops between file moves.
    if fs.exists(backup) then fs.delete(backup) end
    if fs.exists(path) then fs.move(path, backup) end
    local moved, message = pcall(fs.move, temp, path)
    if not moved then
      if fs.exists(backup) and not fs.exists(path) then fs.move(backup, path) end
      error(message)
    end
    if fs.exists(backup) then fs.delete(backup) end
  end)
  return ok
end
local function loadGame()
  if not fs or not textutils then return nil end
  local path = savePath()
  for _, candidate in ipairs({path, path .. ".bak"}) do
    local ok, g = pcall(function()
      if not fs.exists(candidate) then return nil end
      local file = assert(fs.open(candidate, "r"))
      local data = file.readAll()
      file.close()
      return textutils.unserialize(data)
    end)
    if ok and validSave(g) then return g end
  end
  return nil
end

local function chooseMonitor(requested)
  if not peripheral then return nil, nil end
  if requested then
    local p = peripheral.wrap(requested)
    if not p or peripheral.getType(requested) ~= "monitor" then
      error("'" .. requested .. "' is not a monitor")
    end
    if p.isColor and not p.isColor() then error("Use an Advanced (colour) Monitor") end
    return p, requested
  end
  local best, bestName, bestArea = nil, nil, -1
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
      local m = peripheral.wrap(name)
      if not m.isColor or m.isColor() then
        local ok, area = pcall(function()
          local original = m.getTextScale()
          m.setTextScale(0.5)
          local w, h = m.getSize()
          m.setTextScale(original)
          return w * h
        end)
        if ok and area > bestArea then best = m; bestName = name; bestArea = area end
      end
    end
  end
  return best, bestName
end

local function run()
  local monitor, name = chooseMonitor(argv[1])
  if not monitor then
    print("TIDEBOUND requires an Advanced Monitor.")
    print("Connect one, then run: tidebound [monitor-side]")
    return
  end
  local oldScale = monitor.getTextScale and monitor.getTextScale() or 1
  local oldPalette = {}
  if colors and monitor.getPaletteColor then
    for _, entry in ipairs(theme) do
      local c = colors[entry[1]]
      if c then oldPalette[c] = {monitor.getPaletteColor(c)} end
    end
  end
  local function restore()
    if colors and monitor.setPaletteColor then
      for c, rgb in pairs(oldPalette) do pcall(monitor.setPaletteColor, c, rgb[1], rgb[2], rgb[3]) end
    end
    pcall(monitor.setTextScale, oldScale)
  end
  local ok, err = pcall(function()
    monitor.setTextScale(0.5)
    if colors and monitor.setPaletteColor then
      for _, entry in ipairs(theme) do
        if colors[entry[1]] then pcall(monitor.setPaletteColor, colors[entry[1]], entry[2]) end
      end
    end
    local speaker = peripheral.find("speaker")
    local function sound(kind)
      if not speaker then return end
      local instrument = kind == "action" and "bit" or "harp"
      local note = kind == "action" and 15 or 19
      pcall(speaker.playNote, instrument, 0.5, note)
    end
    local ui = uiNew()
    ui.game = loadGame()
    if ui.game and ui.game.winner then ui.page = "menu" end
    render(monitor, ui)
    while true do
      local event, side, x, y = os.pullEvent()
      if event == "monitor_touch" and side == name then
        local former = ui.page
        local eventKind = touch(ui, x, y)
        if eventKind and (eventKind == "action" or eventKind == "CLAIM"
          or eventKind == "CANNON 1" or eventKind == "SHELL 3") then sound("action") end
        if ui.game and (ui.page == "game" or ui.page == "over"
          or former == "game" or former == "new") then
          ui.saveOk = saveGame(ui.game)
        end
        render(monitor, ui)
      elseif event == "monitor_resize" and side == name then
        render(monitor, ui)
      elseif event == "peripheral_detach" and side == name then
        error("The game monitor was disconnected")
      end
    end
  end)
  restore()
  if not ok then error(err, 0) end
end
-- Expose pure game/rendering functions to the separate offline test harness.
if argv[1] == "--test-api" then
  return {GRID=GRID, RED=RED, BLUE=BLUE, inside=inside, makeGame=makeGame, key=key, at=at, findShip=findShip,
    reachable=reachable, legalTargets=legalTargets, clearShot=clearShot,
    perform=perform, undo=undo, endTurn=endTurn, render=render,
    uiNew=uiNew, touch=touch, portAt=portAt}
end
run()