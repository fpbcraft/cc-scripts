local U = require("games.railbreak.core.util")
local C = require("games.railbreak.content.catalog")
local S = require("games.railbreak.game.state")
local K = require("games.railbreak.game.kinetics")
local A = require("games.railbreak.game.commands")
local R = require("games.railbreak.render.canvas")
local Disk = require("games.railbreak.platform.storage")
local App = {}
App.__index = App
local function textwrap(str, width)
  local out, line = {}, ""
  for word in tostring(str or ""):gmatch("%S+") do
    if #line + #word + 1 > width and line ~= "" then
      out[#out + 1] = line
      line = word
    else
      line = (line == "" and word or line .. " " .. word)
    end
  end
  if line ~= "" then
    out[#out + 1] = line
  end
  return out
end
function App.new(m, opt)
  local self = setmetatable(
    {
      r = R.new(m),
      scene = "title",
      game = nil,
      selected = nil,
      tool = "shaft",
      mode = "select",
      buildPage = 1,
      playerCount = 1,
      editing = 1,
      names = { "", "", "", "" },
      modal = nil,
      helpPage = 1,
      blueprintPage = 1,
      toast = "",
      animation = 0,
      autoTarget = "iron_sheet",
      settings = { audio = true },
      buttons = {},
      presaved = nil,
      seed = 12825,
    },
    App
  )
  if opt and opt.game then
    self.game = opt.game
    self.scene = "factory"
  end
  return self
end
function App:notify(msg)
  self.toast = tostring(msg or "")
end
function App:save()
  if self.game then
    local ok, err = Disk.save(self.game)
    if not ok and fs then
      self:notify("SAVE ERROR: " .. tostring(err))
    end
  end
end
function App:action(fn)
  local ok, msg = fn()
  self:notify(msg)
  if ok then
    local count = self.game.contributions and self.game.contributions[self.game.currentPlayer]
    if count then
      count.actions = count.actions + 1
    end
    self:save()
    self.animation = 5
  end
  return ok
end
function App:newGame()
  local names = {}
  for i = 1, self.playerCount do
    names[i] = U.name(self.names[i])
  end
  self.game = S.new({ seed = self.seed, names = names, count = self.playerCount })
  K.analyze(self.game)
  self.scene = "factory"
  self.selected = nil
  self.mode = "select"
  self.modal = nil
  self:save()
  self:notify("STARTER FACTORY READY. RUN A SHIFT TO MAKE SHEETS.")
end
function App:layout()
  local r = self.r
  local compact = r.h < 76 or r.w < 106
  local sidebar = math.max(29, math.min(40, math.floor(r.w * 0.30)))
  local x = 2
  local top = compact and 8 or 12
  local bottom = r.h - (compact and 7 or 9)
  local available = r.w - sidebar - 5
  local step = math.floor(math.min(available / S.W, (bottom - top - 4) / S.H))
  step = math.max(3, step)
  return { x = x, y = top, step = step, gw = S.W * step, gh = S.H * step, side = r.w - sidebar - 1, sw = sidebar, bottom = bottom, compact = compact }
end
function App:header()
  local r = self.r
  local g = self.game
  local compact = r.h < 76 or r.w < 106
  local hh = compact and 7 or 8
  r:rect(0, 0, r.w, hh, 1)
  r:rect(0, hh - 1, r.w, 1, 7)
  r:rect(1, 1, 2, 4, 6)
  r:text(4, 1, "RAILBREAK", 17)
  if not compact then
    r:text(4, 4, "KINETIC FRONTIER", 11)
  end
  if g then
    local statsX = compact and 23 or 31
    r:text(
      statsX,
      1,
      "LEG " .. math.min(g.chapter, g.totalChapters) .. "/" .. g.totalChapters .. " SHIFT " .. g.shift,
      6
    )
    local k = g.machineStatus
    r:text(statsX, compact and 3 or 4, "STRESS " .. k.load .. "/" .. k.capacity .. " SU", k.overstressed and 18 or 9)
    local crewW = compact and 19 or 37
    r:button(
      r.w - crewW - 1,
      1,
      crewW,
      3,
      compact and ("CREW " .. g.currentPlayer) or ("CREW " .. g.currentPlayer .. ": " .. g.players[g.currentPlayer]),
      function()
        g.currentPlayer = g.currentPlayer % #g.players + 1
        self:save()
      end,
      { color = 11, icon = "info" }
    )
    if not compact then
      r:text(r.w - 36, 4, "SCORE " .. A.score(g), 6)
    end
  end
end
function App:bottom()
  local r = self.r
  local l = self:layout()
  local b = l.bottom
  local g = self.game
  r:rect(0, b, r.w, r.h - b, 1)
  r:rect(0, b, r.w, 1, 7)
  local compact = l.compact
  local pad = compact and 1 or 2
  local bw = math.floor((r.w - 2 * pad - 5) / 6)
  local menu = {
    { "WORKSHOP", "factory" },
    { "RAILWAY", "railway" },
    { "WAREHOUSE", "warehouse" },
    { "BLUEPRINTS", "blueprints" },
    { "HELP", "help" },
    { "MENU", "title" },
  }
  local short = { "FACTORY", "RAILS", "STOCK", "PLANS", "HELP", "MENU" }
  for i, item in ipairs(menu) do
    local xx = pad + (i - 1) * (bw + 1)
    r:button(
      xx,
      b + 1,
      bw,
      compact and 3 or 5,
      compact and short[i] or item[1],
      function()
        self.scene = item[2]
        self.modal = nil
      end,
      {
        color = self.scene == item[2] and 9 or 6,
        icon = not compact
            and (i == 1 and "factory" or i == 2 and "train" or i == 3 and "stock" or i == 4 and "tools" or "info")
          or nil,
      }
    )
  end
  if g and self.scene ~= "title" then
    r:text(2, r.h - 2, self.toast, 5, r.w - 4)
  end
end
function App:factory()
  local r = self.r
  local g = self.game
  local l = self:layout()
  self:header()
  if not l.compact then
    r:text(l.x, l.y - 2, "WORKSHOP / TOP VIEW     TOUCH TILE TO INSPECT", 4)
  end
  r:rect(l.x - 1, l.y - 1, l.gw + 2, l.gh + 2, 1)
  K.analyze(g)
  local components = {
    wheel = 6,
    steam = 18,
    shaft = 4,
    gear = 6,
    press = 9,
    saw = 11,
    crusher = 7,
    mixer = 15,
    assembler = 18,
    belt = 14,
    depot = 12,
    chest = 10,
    empty = 19,
  }
  for y = 1, S.H do
    for x = 1, S.W do
      local t = S.get(g, x, y)
      local xx = l.x + (x - 1) * l.step
      local yy = l.y + (y - 1) * l.step
      local selected = self.selected and self.selected.x == x and self.selected.y == y
      local base = (x + y) % 2 == 0 and 20 or 19
      r:rect(xx, yy, l.step - 1, l.step - 1, selected and 7 or base)
      if t.id ~= "empty" then
        r:rect(xx + 1, yy + 1, l.step - 3, l.step - 3, components[t.id] or 4)
        r:icon(xx + math.floor(l.step / 2) - 1, yy + math.floor(l.step / 2) - 1, t.id, 17, l.step <= 5 and 2 or 3)
        if self.animation > 0 and (t.id == "wheel" or t.id == "gear" or t.id == "steam") then
          r:text(xx + l.step - 3, yy + 1, (self.animation % 2 == 0) and "+" or "-", 6)
        end
        if t.id == "belt" then
          r:icon(xx + 1, yy + l.step - 3, ({ "next", "next", "back", "info" })[t.face], 17)
        end
        if t.item then
          r:text(xx + 1 + (self.animation > 0 and self.animation % 2 or 0), yy + 1, "*", 6)
        end
        if t.id == "depot" then
          r:text(xx + 1, yy + 1, t.filter:sub(1, 1), 23)
        end
        if C.recipes[t.id] then
          local power = g.machineStatus.connections[U.key(x, y)]
          r:rect(xx + l.step - 3, yy + 1, 1, 1, power and power.powered and 9 or 8)
          if next(t.output) then
            r:text(xx + 1, yy + l.step - 2, "!", 6)
          end
        end
      end
      r.buttons[#r.buttons + 1] = {
        x = xx,
        y = yy,
        w = l.step - 1,
        h = l.step - 1,
        fn = function()
          self.selected = { x = x, y = y }
          if self.mode == "build" and t.id == "empty" then
            self:action(function()
              return A.build(g, x, y, self.tool)
            end)
          end
        end,
      }
    end
  end
  -- Utility status below the factory, not over the grid.
  local row = l.y + l.gh + 2
  local kinetic = g.machineStatus
  local msg = kinetic.overstressed and "OVERSTRESSED - DISENGAGE OR ADD GENERATION"
    or "CONNECTED FACTORY - READY FOR PRODUCTION"
  if row + 3 < l.bottom then
    r:text(l.x, row, msg, kinetic.overstressed and 18 or 9, l.gw)
    r:text(
      l.x,
      row + 2,
      "IRON "
        .. g.warehouse.iron
        .. "  WOOD "
        .. g.warehouse.logs
        .. "  SHEETS "
        .. g.warehouse.iron_sheet
        .. "  TRACK "
        .. g.warehouse.track,
      5,
      l.gw
    )
  end
  self:factoryPanel(l)
  self:bottom()
end
function App:factoryPanel(l)
  local r = self.r
  local g = self.game
  local x = l.side
  local w = l.sw
  if l.compact then
    r:rect(x, 7, w, l.bottom - 8, 1)
    r:rect(x, 7, w, 1, 7)
    r:text(x + 2, 8, self.mode == "build" and "BUILD / SELECT TILE" or "WORKSHOP CONTROLS", 6, w - 3)
    local bw = math.floor((w - 6) / 3)
    local function step(count)
      local before = g.shift
      if self:action(function()
        return A.advance(g, count)
      end) then
        g.contributions[g.currentPlayer].shifts = g.contributions[g.currentPlayer].shifts + g.shift - before
        self:save()
      end
    end
    r:button(x + 2, 11, bw, 3, "1X", function()
      step(1)
    end, { color = 9 })
    r:button(x + 3 + bw, 11, bw, 3, "5X", function()
      step(5)
    end, { color = 9 })
    r:button(x + 4 + bw * 2, 11, bw, 3, "AUTO", function()
      self.modal = "auto"
    end, { color = 11 })
    local contentY = 16
    if self.mode == "build" then
      r:text(x + 2, contentY, "TAP EMPTY TILE", 9)
      local listTop = contentY + 3
      local listBottom = l.bottom - 12
      local pageSize = math.max(1, math.floor((listBottom - listTop) / 4))
      local pages = math.ceil(#C.buildOrder / pageSize)
      self.buildPage = U.clamp(self.buildPage, 1, pages)
      for i = 1, pageSize do
        local id = C.buildOrder[(self.buildPage - 1) * pageSize + i]
        if id then
          local spec = C.spec[id]
          local disabled = (C.unlocks[id] or 0) > g.unlocked
          r:button(x + 2, listTop + (i - 1) * 4, w - 4, 3, spec.name, function()
            self.tool = id
            self:notify(spec.help .. " COST: " .. U.format(spec.cost))
          end, { color = self.tool == id and 9 or 6, disabled = disabled })
        end
      end
      local by = l.bottom - 11
      local half = math.floor((w - 5) / 2)
      r:button(x + 2, by, half, 3, "PREV", function()
        self.buildPage = math.max(1, self.buildPage - 1)
      end, { disabled = self.buildPage == 1 })
      r:button(x + 3 + half, by, half, 3, "NEXT", function()
        self.buildPage = math.min(pages, self.buildPage + 1)
      end, { disabled = self.buildPage == pages })
      r:button(x + 2, by + 4, w - 4, 3, "INSPECT", function()
        self.mode = "select"
      end, { color = 11 })
    else
      local t = self.selected and S.get(g, self.selected.x, self.selected.y)
      if t then
        local spec = C.spec[t.id]
        r:text(x + 2, contentY, "TILE " .. self.selected.x .. "," .. self.selected.y, w < 32 and 6 or 17, w - 4)
        r:text(x + 2, contentY + 2, spec.name, 17, w - 4)
        local lines = textwrap(spec.help or "Empty. Build here.", w - 5)
        for i = 1, math.min(#lines, 3) do
          r:text(x + 2, contentY + 3 + i, lines[i], 5, w - 4)
        end
        if t.id ~= "empty" then
          local st = g.machineStatus.connections[U.key(self.selected.x, self.selected.y)]
          if st then
            r:text(
              x + 2,
              contentY + 8,
              "RPM " .. st.rpm .. " SU " .. st.networkLoad .. "/" .. st.capacity,
              st.powered and 9 or 18,
              w - 4
            )
          end
          local by = l.bottom - (t.id == "depot" and 15 or 11)
          r:button(x + 2, by, w - 4, 3, "ROTATE", function()
            self:action(function()
              return A.rotate(g, self.selected.x, self.selected.y)
            end)
          end, { color = 11 })
          r:button(x + 2, by + 4, w - 4, 3, "DISMANTLE", function()
            self.modal = "demolish"
          end, { color = 18 })
          if t.id == "depot" then
            r:button(x + 2, by + 8, w - 4, 3, "CHANGE FEED", function()
              self.modal = "filter"
            end, { color = 11 })
          end
        end
      else
        r:text(x + 2, contentY + 2, "TAP A MACHINE", 5)
      end
      r:button(x + 2, l.bottom - 5, w - 4, 3, "BUILD", function()
        self.mode = "build"
      end, { color = 9 })
    end
    return
  end
  r:rect(x, 9, w, l.bottom - 10, 1)
  r:rect(x, 9, w, 1, 7)
  r:text(x + 2, 10, self.mode == "build" and "MACHINE BLUEPRINTS" or "FACTORY CONTROLS", 6)
  local shiftW = math.floor((w - 6) / 3)
  r:button(x + 2, 14, shiftW, 4, "1 SHIFT", function()
    local before = g.shift
    if self:action(function()
      return A.advance(g, 1)
    end) then
      g.contributions[g.currentPlayer].shifts = g.contributions[g.currentPlayer].shifts + g.shift - before
      self:save()
    end
  end, { color = 9 })
  r:button(x + 3 + shiftW, 14, shiftW, 4, "5 SHIFTS", function()
    local before = g.shift
    if self:action(function()
      return A.advance(g, 5)
    end) then
      g.contributions[g.currentPlayer].shifts = g.contributions[g.currentPlayer].shifts + (g.shift - before)
      self:save()
    end
  end, { color = 9 })
  r:button(x + 4 + shiftW * 2, 14, shiftW, 4, "AUTO", function()
    self.modal = "auto"
  end, { color = 11 })
  if self.mode == "build" then
    r:text(x + 2, 20, "TAP EMPTY TILE TO PLACE", 4)
    local max = l.bottom < 68 and 4 or 6
    local pages = math.ceil(#C.buildOrder / max)
    self.buildPage = U.clamp(self.buildPage, 1, pages)
    for n = 1, max do
      local idx = (self.buildPage - 1) * max + n
      local id = C.buildOrder[idx]
      if id then
        local spec = C.spec[id]
        local disabled = (C.unlocks[id] or 0) > g.unlocked
        r:button(x + 2, 22 + (n - 1) * 5, w - 4, 4, spec.name, function()
          self.tool = id
          self:notify(spec.help .. " COST: " .. U.format(spec.cost))
        end, { icon = id, color = id == self.tool and 9 or 6, disabled = disabled })
      end
    end
    local by = l.bottom - 12
    r:button(x + 2, by, math.floor((w - 5) / 2), 4, "PREV", function()
      self.buildPage = math.max(1, self.buildPage - 1)
    end, { icon = "back", disabled = self.buildPage == 1 })
    r:button(x + 3 + math.floor((w - 5) / 2), by, math.floor((w - 5) / 2), 4, "NEXT", function()
      self.buildPage = math.min(pages, self.buildPage + 1)
    end, { icon = "next", disabled = self.buildPage == pages })
    r:button(x + 2, by + 5, w - 4, 4, "INSPECT MODE", function()
      self.mode = "select"
    end, { color = 11, icon = "info" })
  else
    local selected = self.selected and S.get(g, self.selected.x, self.selected.y)
    if selected then
      local spec = C.spec[selected.id]
      r:text(x + 2, 20, "TILE " .. self.selected.x .. "," .. self.selected.y .. "  " .. spec.name, 17, w - 4)
      local lines = textwrap(spec.help or "Empty tile. Select Build to place machinery.", w - 5)
      for i = 1, math.min(#lines, 4) do
        r:text(x + 2, 22 + i, lines[i], 4, w - 4)
      end
      if selected.id ~= "empty" then
        local st = g.machineStatus.connections[U.key(self.selected.x, self.selected.y)]
        r:text(x + 2, 29, "FACE " .. ({ "EAST", "SOUTH", "WEST", "NORTH" })[selected.face], 6)
        if st then
          r:text(
            x + 2,
            31,
            "RPM " .. st.rpm .. " | " .. st.networkLoad .. "/" .. st.capacity .. " SU",
            st.powered and 9 or 18,
            w - 4
          )
        end
        if C.recipes[selected.id] then
          local recipe = C.recipes[selected.id]
          r:text(x + 2, 33, "IN: " .. U.format(recipe.input), 11, w - 4)
          r:text(x + 2, 35, "OUT: " .. U.format(recipe.output), 9, w - 4)
          r:text(x + 2, 37, "BUFFER: " .. U.format(selected.slot), 4, w - 4)
        elseif selected.id == "depot" then
          r:text(x + 2, 33, "FEED: " .. selected.filter, 11)
        end
        local by = l.bottom - (selected.id == "depot" and 20 or 15)
        r:button(x + 2, by, w - 4, 4, "ROTATE", function()
          self:action(function()
            return A.rotate(g, self.selected.x, self.selected.y)
          end)
        end, { icon = "next" })
        r:button(x + 2, by + 5, w - 4, 4, "DISMANTLE", function()
          self.modal = "demolish"
        end, { icon = "tools", color = 18 })
        if selected.id == "depot" then
          r:button(x + 2, by + 10, w - 4, 4, "CHANGE FEED", function()
            self.modal = "filter"
          end, { icon = "stock", color = 11 })
        end
      end
    else
      r:text(x + 2, 23, "SELECT A MACHINE", 4)
      r:text(x + 2, 25, "TO VIEW ITS DETAILS", 4)
    end
    r:button(x + 2, l.bottom - 6, w - 4, 4, "BUILD MACHINES", function()
      self.mode = "build"
    end, { icon = "build", color = 9 })
  end
end
function App:route()
  local r = self.r
  local g = self.game
  self:header()
  local compact = self:layout().compact
  if compact then
    r:text(3, 8, "RAILWAY / STAGE " .. g.chapter .. " OF " .. g.totalChapters, 17)
    local contract = C.contracts[g.currentContract]
    r:text(3, 11, "CONTRACT " .. contract.title, 6, r.w - 5)
    r:text(3, 13, U.format(contract.needs), 11, r.w - 5)
    r:button(r.w - 25, 10, 23, 4, "DELIVER", function()
      self:action(function()
        return A.deliver(g)
      end)
    end, { color = 9, disabled = g.contractStatus ~= "OPEN" })
    local routesTop = 17
    for i, route in ipairs(g.routeChoices) do
      local y = routesTop + (i - 1) * 12
      r:rect(3, y, r.w - 6, 11, 1)
      r:rect(3, y, 1, 11, i == 1 and 6 or 11)
      r:text(6, y + 1, route.title, 17, r.w - 12)
      r:text(6, y + 3, "NEEDS " .. U.format(route.cost), 6, r.w - 12)
      r:text(6, y + 5, "REWARD " .. U.format(route.reward), 9, r.w - 12)
      r:button(r.w - 28, y + 7, 24, 3, "BUILD + TRAVEL", function()
        self.routeChoice = i
        self.modal = "travel"
      end, { color = 9 })
    end
    self:bottom()
    return
  end
  r:text(6, 10, "EXPEDITION MAP  /  RAILWAY ROUTE PLANNING", 6)
  local baseX = math.floor(r.w * 0.17)
  local baseY = math.floor(19 + math.max(0, r.h - 80) * 0.08)
  for i = 1, g.totalChapters do
    local x = baseX + (i - 1) * math.floor(r.w * 0.18)
    local y = baseY + math.floor(math.sin(i * 0.9) * 6)
    if i > 1 then
      local xx = baseX + (i - 2) * math.floor(r.w * 0.18)
      local yy = baseY + math.floor(math.sin((i - 1) * 0.9) * 6)
      r:line(xx + 3, yy + 3, x - 3, y + 3, i < g.chapter and 9 or 3)
    end
    r:rect(x - 3, y - 3, 8, 8, i < g.chapter and 10 or i == g.chapter and 6 or 3)
    r:icon(x, y, "train", 17)
    r:text(x - 2, y + 7, "LEG " .. i, 5)
  end
  r:text(6, r.h - 39, "NEXT DESTINATIONS", 17)
  for i, route in ipairs(g.routeChoices) do
    local width = math.floor((r.w - 20) / 2)
    local x = 6 + (i - 1) * (width + 7)
    local y = r.h - 36
    r:rect(x, y, width, 24, 1)
    r:rect(x, y, width, 2, i == 1 and 6 or 11)
    r:text(x + 2, y + 4, route.title, 17, width - 4)
    r:text(x + 2, y + 7, route.detail, 5, width - 4)
    r:text(x + 2, y + 10, "REQUIRES: " .. U.format(route.cost), 6, width - 4)
    r:text(x + 2, y + 13, "SUPPLIES: " .. U.format(route.reward), 9, width - 4)
    r:button(x + 3, y + 18, width - 6, 4, "BUILD AND TRAVEL", function()
      self.routeChoice = i
      self.modal = "travel"
    end, { icon = "train", color = 9 })
  end
  local contractY = r.h - 49
  r:text(6, contractY, "CURRENT CONTRACT", 6)
  local contract = C.contracts[g.currentContract]
  r:text(6, contractY + 2, contract.title .. " - " .. U.format(contract.needs), 17, r.w - 11)
  r:text(
    6,
    contractY + 4,
    "STATUS " .. g.contractStatus .. " | DEADLINE " .. math.max(0, g.contractLimit - g.contractAge) .. " SHIFTS",
    5
  )
  r:button(6, contractY + 5, 27, 4, "FULFILL CONTRACT", function()
    self:action(function()
      return A.deliver(g)
    end)
  end, { icon = "contract", color = 11, disabled = g.contractStatus ~= "OPEN" })
  self:bottom()
end
function App:warehouse()
  local r = self.r
  local g = self.game
  self:header()
  local compact = self:layout().compact
  r:text(4, compact and 8 or 11, "MATERIAL WAREHOUSE", 17)
  local width = math.floor((r.w - 16) / 3)
  for i, item in ipairs(C.resources) do
    local col = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    local x = 4 + col * (width + 3)
    local y = (compact and 11 or 17) + row * (compact and 7 or 10)
    r:rect(x, y, width, compact and 6 or 8, 1)
    r:text(x + 2, y + 1, item:upper(), 6, width - 4)
    r:text(x + 2, y + (compact and 3 or 5), tostring(g.warehouse[item] or 0), 17)
  end
  local sy = compact and self:layout().bottom - 6 or r.h - 24
  r:button(4, sy, math.min(36, r.w - 8), compact and 3 or 5, "EMERGENCY SCAVENGE", function()
    self.modal = "scavenge"
  end, { icon = not compact and "stock" or nil, color = 18 })
  if not compact then
    r:text(5, r.h - 17, "Scavenging costs one shift and a score penalty.", 4, r.w - 10)
  end
  self:bottom()
end
function App:blueprints()
  local r = self.r
  local g = self.game
  self:header()
  local compact = self:layout().compact
  r:text(4, compact and 8 or 10, "MACHINE BLUEPRINTS / CREATE", 17, r.w - 8)
  local columns = compact and 2 or 3
  local width = math.floor((r.w - 12 - (columns - 1) * 3) / columns)
  local rows = compact and 2 or math.max(2, math.floor((self:layout().bottom - 20) / 14))
  local pageSize = columns * rows
  local pages = math.ceil(#C.buildOrder / pageSize)
  self.blueprintPage = U.clamp(self.blueprintPage, 1, pages)
  for index = 1, pageSize do
    local id = C.buildOrder[(self.blueprintPage - 1) * pageSize + index]
    if id then
      local spec = C.spec[id]
      local col = (index - 1) % columns
      local row = math.floor((index - 1) / columns)
      local x = 4 + col * (width + 3)
      local y = (compact and 12 or 16) + row * (compact and 12 or 14)
      local locked = (C.unlocks[id] or 0) > g.unlocked
      r:rect(x, y, width, compact and 10 or 12, locked and 1 or 2)
      r:icon(x + 2, y + 1, id, locked and 4 or 9)
      r:text(x + 5, y + 1, spec.name, locked and 4 or 17, width - 7)
      r:text(x + 2, y + 3, U.format(spec.cost), 6, width - 4)
      local lines = textwrap(spec.help, width - 4)
      for j = 1, math.min(compact and 2 or 3, #lines) do
        r:text(x + 2, y + 3 + j, lines[j], 4, width - 4)
      end
      if locked then
        r:text(x + 2, y + (compact and 8 or 10), "LOCKED STAGE " .. (C.unlocks[id] + 1), 18, width - 4)
      end
    end
  end
  local by = self:layout().bottom - 5
  r:button(4, by, 18, 3, "PREV", function()
    self.blueprintPage = math.max(1, self.blueprintPage - 1)
  end, { disabled = self.blueprintPage == 1 })
  r:text(25, by + 1, "PAGE " .. self.blueprintPage .. "/" .. pages, 6)
  r:button(r.w - 22, by, 18, 3, "NEXT", function()
    self.blueprintPage = math.min(pages, self.blueprintPage + 1)
  end, { disabled = self.blueprintPage == pages })
  self:bottom()
end
function App:help()
  local r = self.r
  self:header()
  local compact = self:layout().compact
  r:text(4, compact and 8 or 10, "FIELD MANUAL / CREATE KINETICS", 17)
  local lines = {
    "GOAL: BUILD RAILWAY ACROSS FOUR FRONTIER SECTIONS.",
    "SOLO OR 2-4 FRIENDS SHARE ONE TOUCH MONITOR.",
    "PLANNING HAS NO TIMER. SHIFTS RUN ONLY ON REQUEST.",
    "THE STARTER PRESS LINE WORKS. TRY FIVE SHIFTS.",
    "WATER WHEEL + SHAFT + PRESS = KINETIC POWER.",
    "DEPOT + BELT + PRESS + BELT + CHEST = ITEM FLOW.",
    "PRESS NEEDS IRON TO MAKE IRON SHEETS.",
    "SELECT BUILD, CHOOSE MACHINE, TAP AN EMPTY TILE.",
    "CONNECT MACHINES TO SHAFTS OR GEARS FOR ROTATION.",
    "OVERSTRESSED NETWORKS STOP PROCESSING.",
    "GEARS DOUBLE RPM AND INCREASE MACHINE STRESS.",
    "DEPOTS SEND FILTERED MATERIAL FROM WAREHOUSE.",
    "BELTS MOVE ONE PACKET PER TILE EACH SHIFT.",
    "MACHINES OUTPUT IN THE FACING DIRECTION.",
    "CHESTS RETURN PRODUCTS TO THE WAREHOUSE.",
    "BUILD MORE DEPOTS TO PROVIDE MULTIPLE INPUTS.",
    "ONE SHIFT FOR PRECISION; FIVE FOR PRODUCTION.",
    "AUTO STOPS ON WARNINGS OR MATERIAL GOALS.",
    "RAILWAY SHOWS CONTRACTS AND BRANCHING ROUTES.",
    "COMPLETE CONTRACTS FOR REWARDS AND REPUTATION.",
    "BUILD TRACK AND BRIDGES TO EXTEND THE LINE.",
    "NO MULTITOUCH REQUIRED. CREW CAN TAKE TURNS.",
    "EMERGENCY SCAVENGE RESTOCKS BASIC MATERIALS.",
    "NEW BLUEPRINTS UNLOCK AFTER LATER STATIONS.",
  }
  local top = compact and 12 or 16
  local step = compact and 2 or 2
  local visible = math.max(1, math.floor((self:layout().bottom - top - 6) / step))
  local pages = math.ceil(#lines / visible)
  self.helpPage = U.clamp(self.helpPage, 1, pages)
  for i = 1, visible do
    local line = lines[(self.helpPage - 1) * visible + i]
    if line then
      r:text(4, top + (i - 1) * step, line, i % 4 == 1 and 9 or 5, r.w - 8)
    end
  end
  local by = self:layout().bottom - 5
  r:button(4, by, 18, 3, "PREV", function()
    self.helpPage = math.max(1, self.helpPage - 1)
  end, { disabled = self.helpPage == 1 })
  r:text(25, by + 1, "PAGE " .. self.helpPage .. "/" .. pages, 6)
  r:button(r.w - 22, by, 18, 3, "NEXT", function()
    self.helpPage = math.min(pages, self.helpPage + 1)
  end, { disabled = self.helpPage == pages })
  self:bottom()
end
function App:dialog()
  if not self.modal then
    return
  end
  local r = self.r
  local g = self.game
  local w, h = math.min(61, r.w - 8), math.min(24, r.h - 12)
  local x = math.floor((r.w - w) / 2)
  local y = math.floor((r.h - h) / 2)
  r:rect(x, y, w, h, 1)
  r:rect(x, y, w, 2, 6)
  r:text(x + 3, y + 3, self.modal:upper() .. " / CONFIRM", 17)
  local desc, cancel, confirm
  if self.modal == "travel" then
    local route = g.routeChoices[self.routeChoice]
    desc = "Build rails to "
      .. route.title
      .. ". Spend "
      .. U.format(route.cost)
      .. ". Gain "
      .. U.format(route.reward)
      .. ". The expedition advances to the next region."
    confirm = function()
      self:action(function()
        return A.travel(g, self.routeChoice)
      end)
      self.scene = g.finished and "results" or "railway"
    end
  elseif self.modal == "demolish" then
    desc =
      "Dismantle selected machinery. Recover materials at 75 percent, plus buffered items. Connected networks may stop."
    confirm = function()
      self:action(function()
        return A.remove(g, self.selected.x, self.selected.y)
      end)
      self.selected = nil
    end
  elseif self.modal == "scavenge" then
    desc = "Scavenge 2 iron, 2 logs, 2 cobblestone and 1 coal. Consumes a shift and reduces your score by 35 points."
    confirm = function()
      self:action(function()
        return A.scavenge(g)
      end)
    end
  elseif self.modal == "auto" then
    local target = self.autoTarget
    desc = "Run up to 20 production shifts, stopping on new warnings or when "
      .. target
      .. " increases by 4. Does not advance in real time."
    confirm = function()
      local start = g.warehouse[target]
      local simulated = 0
      for i = 1, 20 do
        local ok, why = A.advance(g, 1)
        if not ok then
          self:notify(why)
          break
        end
        simulated = i
        if g.warehouse[target] >= start + 4 or #g.production.events > 0 then
          break
        end
      end
      g.contributions[g.currentPlayer].shifts = g.contributions[g.currentPlayer].shifts + simulated
      self:notify("AUTO: " .. simulated .. " SHIFTS EXECUTED.")
      self:save()
      self.animation = 5
    end
  elseif self.modal == "filter" then
    desc = "Select an item for the input depot to send into its facing conveyor."
    local names = C.resources
    local cols = 3
    local bw = math.floor((w - 8) / cols)
    for i, name in ipairs(names) do
      local xx = x + 3 + ((i - 1) % cols) * bw
      local yy = y + 8 + math.floor((i - 1) / cols) * 4
      r:button(xx, yy, bw - 1, 3, name, function()
        self:action(function()
          return A.filter(g, self.selected.x, self.selected.y, name)
        end)
        self.modal = nil
      end, { color = 11 })
    end
    r:button(x + 3, y + h - 5, 19, 4, "CANCEL", function()
      self.modal = nil
    end, { color = 18 })
    return
  end
  for i, line in ipairs(textwrap(desc or "", w - 8)) do
    r:text(x + 4, y + 6 + (i - 1) * 2, line, 5, w - 8)
  end
  r:button(x + 3, y + h - 6, math.floor((w - 8) / 2), 4, "CANCEL", function()
    self.modal = nil
  end, { color = 18 })
  r:button(x + 5 + math.floor((w - 8) / 2), y + h - 6, math.floor((w - 8) / 2), 4, "CONFIRM", function()
    self.modal = nil
    confirm()
  end, { color = 9 })
end
function App:title()
  local r = self.r
  if r.h < 76 then
    local cx = math.floor(r.w / 2)
    r:bigText(cx - 18, 3, "RAILBREAK", 17, 3)
    r:text(cx - 11, 9, "KINETIC FRONTIER", 6)
    r:rect(cx - 28, 17, 56, 2, 14)
    r:rect(cx - 25, 12, 19, 6, 7)
    r:rect(cx - 23, 9, 10, 4, 14)
    r:rect(cx - 5, 13, 6, 5, 8)
    for i = 1, 3 do
      local x = cx + 5 + (i - 1) * 8
      r:rect(x, 13, 7, 5, 10)
      r:rect(x + 1, 17, 2, 3, 3)
    end
    local bw = math.min(37, r.w - 12)
    local xx = cx - math.floor(bw / 2)
    r:button(xx, 23, bw, 5, "NEW EXPEDITION", function()
      self.scene = "setup"
    end, { color = 9 })
    r:button(xx, 29, bw, 5, "CONTINUE", function()
      local loaded = Disk.load()
      if loaded then
        self.game = loaded
        self.scene = "factory"
        self:notify("EXPEDITION RESTORED")
      else
        self:notify("NO SAVED EXPEDITION FOUND")
      end
    end, { color = 11 })
    r:button(xx, 35, bw, 4, "ABOUT AND GUIDE", function()
      self.scene = "intro"
    end, { color = 6 })
    r:text(cx - 21, r.h - 3, self.toast ~= "" and self.toast or "NO TIMERS / SOLO OR COOP", 5, r.w - 4)
    return
  end
  -- Static poster-like train, copper boiler, smoke, pistons and cargo wagons.
  local cx = math.floor(r.w / 2)
  local cy = math.min(math.floor(r.h * 0.36), r.h - 49)
  for i = 0, 18 do
    local px = math.floor((i * 67 + 13) % r.w)
    local py = math.floor((i * 17 + 9) % (r.h * 0.65))
    r:rect(px, py, 1, 1, 3)
  end
  r:rect(cx - 43, cy + 13, 95, 2, 4)
  r:rect(cx - 41, cy + 17, 95, 1, 14)
  for i = -5, 5 do
    local x = cx + i * 8
    r:rect(x, cy + 18, 3, 1, 14)
  end
  r:rect(cx - 36, cy - 2, 25, 16, 7)
  r:rect(cx - 33, cy - 13, 15, 12, 14)
  r:rect(cx - 31, cy - 10, 10, 6, 11)
  r:rect(cx - 13, cy - 4, 8, 18, 14)
  r:rect(cx - 12, cy - 11, 6, 8, 7)
  for i = 0, 3 do
    local x = cx - 36 + i * 12
    r:rect(x, cy + 12, 6, 6, 3)
    r:rect(x + 1, cy + 13, 4, 4, 6)
  end
  for i = 0, 2 do
    local x = cx + 3 + i * 17
    r:rect(x, cy + 2, 14, 13, 10 + i % 2)
    r:rect(x + 2, cy + 5, 10, 5, 12)
    r:rect(x + 2, cy + 13, 3, 5, 3)
    r:rect(x + 10, cy + 13, 3, 5, 3)
  end
  r:bigText(cx - 18, 5, "RAILBREAK", 17, 4)
  r:bigText(cx - 16, 11, "KINETIC FRONTIER", 6, 2)
  r:text(cx - 25, cy + 23, "A CREATE-INSPIRED FACTORY RAILWAY GAME", 5)
  local b = math.min(41, r.w - 15)
  local xx = cx - math.floor(b / 2)
  r:button(xx, cy + 28, b, 5, "NEW EXPEDITION", function()
    self.scene = "setup"
  end, { color = 9, icon = "train", note = "1-4 LOCAL PLAYERS" })
  r:button(xx, cy + 34, b, 5, "CONTINUE", function()
    local loaded = Disk.load()
    if loaded then
      self.game = loaded
      self.scene = "factory"
      self:notify("EXPEDITION RESTORED")
    else
      self:notify("NO SAVED EXPEDITION FOUND")
    end
  end, { color = 11, icon = "play" })
  r:button(xx, cy + 40, b, 4, "ABOUT AND GUIDE", function()
    self.scene = "intro"
  end, { color = 6, icon = "info" })
  r:text(cx - 22, r.h - 3, self.toast ~= "" and self.toast or "TURN-BASED AUTOMATION  |  NO TIME PRESSURE", 4)
end
function App:setup()
  local r = self.r
  local compact = r.h < 76
  if compact then
    r:text(3, 1, "EXPEDITION SETUP / 1-4 PLAYERS", 17, r.w - 6)
    local countW = math.floor((r.w - 9) / 4)
    for i = 1, 4 do
      r:button(3 + (i - 1) * (countW + 1), 5, countW, 3, (i == 1 and "SOLO" or i .. " PLAYERS"), function()
        self.playerCount = i
        self.editing = math.min(i, self.editing)
      end, { color = self.playerCount == i and 9 or 6 })
    end
    local nameWidth = math.floor((r.w - 8) / self.playerCount)
    for i = 1, self.playerCount do
      r:button(
        3 + (i - 1) * nameWidth,
        10,
        nameWidth - 1,
        3,
        self.names[i] ~= "" and self.names[i] or ("NAME " .. i),
        function()
          self.editing = i
        end,
        { color = self.editing == i and 9 or 4 }
      )
    end
    r:text(3, 14, "EDITING PLAYER " .. self.editing, 6)
    local rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
    local keyStep = math.max(5, math.floor((r.w - 6) / 10))
    for line, row in ipairs(rows) do
      local x = math.floor((r.w - #row * keyStep) / 2)
      for i = 1, #row do
        local ch = row:sub(i, i)
        r:button(x + (i - 1) * keyStep, 17 + (line - 1) * 4, keyStep - 1, 3, ch, function()
          self.names[self.editing] = U.name(self.names[self.editing] .. ch)
        end, { color = 6 })
      end
    end
    local w = math.floor((r.w - 12) / 3)
    r:button(3, 30, w, 3, "DELETE", function()
      self.names[self.editing] = self.names[self.editing]:sub(1, -2)
    end, { color = 18 })
    r:button(4 + w, 30, w, 3, "SPACE", function()
      self.names[self.editing] = U.name(self.names[self.editing] .. " ")
    end, { color = 6 })
    r:button(5 + 2 * w, 30, w, 3, "CLEAR", function()
      self.names[self.editing] = ""
    end, { color = 18 })
    r:text(3, 35, "NO TIME LIMIT / SHIFTS ON REQUEST", 5, r.w - 6)
    r:button(3, r.h - 7, 18, 4, "BACK", function()
      self.scene = "title"
    end, { color = 11 })
    r:button(r.w - 31, r.h - 7, 28, 4, "START EXPEDITION", function()
      self.seed = math.floor(((os.epoch and os.epoch("utc")) or (os.clock() * 1000)) % 1900000) + 5123
      self:newGame()
    end, { color = 9 })
    return
  end
  r:bigText(6, 2, "EXPEDITION SETUP", 17, 2)
  for i = 1, 4 do
    local x = 6 + (i - 1) * math.floor((r.w - 14) / 4)
    local width = math.floor((r.w - 18) / 4)
    r:button(x, 11, width, 4, (i == 1 and "SOLO" or (i .. " PLAYERS")), function()
      self.playerCount = i
      self.editing = math.min(i, self.editing)
    end, { color = self.playerCount == i and 9 or 6 })
  end
  r:text(6, 20, "SELECT AN ENGINEER TO RENAME", 6)
  local count = self.playerCount
  for i = 1, count do
    local width = math.floor((r.w - 16) / count)
    r:button(
      6 + (i - 1) * (width + 1),
      24,
      width,
      4,
      self.names[i] ~= "" and self.names[i] or ("NAME " .. i),
      function()
        self.editing = i
      end,
      { color = self.editing == i and 9 or 4 }
    )
  end
  r:text(6, 33, "ON-SCREEN KEYBOARD  /  EDITING " .. self.editing, 5)
  local rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
  local keyStep = 6
  for line, row in ipairs(rows) do
    local x = math.floor((r.w - #row * keyStep) / 2)
    for i = 1, #row do
      local ch = row:sub(i, i)
      r:button(x + (i - 1) * keyStep, 37 + (line - 1) * 6, keyStep - 1, 4, ch, function()
        self.names[self.editing] = U.name(self.names[self.editing] .. ch)
      end, { color = 6 })
    end
  end
  local buttonWidth = math.min(23, math.floor((r.w - 24) / 3))
  local x = math.floor((r.w - (buttonWidth + 2) * 3) / 2)
  r:button(x, 57, buttonWidth, 4, "BACKSPACE", function()
    self.names[self.editing] = self.names[self.editing]:sub(1, -2)
  end, { color = 18 })
  r:button(x + buttonWidth + 2, 57, buttonWidth, 4, "SPACE", function()
    self.names[self.editing] = U.name(self.names[self.editing] .. " ")
  end, { color = 6 })
  r:button(x + (buttonWidth + 2) * 2, 57, buttonWidth, 4, "CLEAR", function()
    self.names[self.editing] = ""
  end, { color = 18 })
  r:text(6, 66, "SHIFTS ADVANCE ONLY WHEN PLAYERS CHOOSE.", 5)
  r:button(6, r.h - 10, 24, 5, "BACK", function()
    self.scene = "title"
  end, { color = 11 })
  r:button(r.w - 44, r.h - 10, 39, 5, "BEGIN EXPEDITION", function()
    self.seed = math.floor(((os.epoch and os.epoch("utc")) or (os.clock() * 1000)) % 1900000) + 5123
    self:newGame()
  end, { color = 9 })
end
function App:intro()
  local r = self.r
  r:text(3, 3, "RAILBREAK / KINETIC FRONTIER", 17)
  local lines = {
    "BUILD A RAILWAY ACROSS A FRONTIER.",
    "CREATE-INSPIRED COGS, SHAFTS, BELTS.",
    "NO TIME LIMIT; SHIFTS ARE MANUAL.",
    "ONE TO FOUR PLAYERS / SHARED WORKSHOP.",
    "PRESS IRON INTO SHEETS WITH STARTER LINE.",
    "ASSEMBLE TRACK, BUILD BRIDGES, EXPLORE.",
    "REACH THE INDUSTRIAL CITY IN FOUR LEGS.",
  }
  local sep = r.h < 76 and 4 or 5
  for i, v in ipairs(lines) do
    r:text(4, 7 + i * sep, v, i == 1 and 9 or 5, r.w - 8)
  end
  r:button(4, r.h - 7, 24, 4, "BACK TO TITLE", function()
    self.scene = "title"
  end, { color = 11 })
end
function App:results()
  local r = self.r
  local g = self.game
  self:header()
  if self:layout().compact then
    local cx = math.floor(r.w / 2)
    r:text(cx - 10, 9, "RAILWAY COMPLETED", 9)
    r:text(cx - 21, 13, "THE CLOCKWORK RAILWAY REACHES THE CAPITAL", 17, r.w - 6)
    r:text(cx - 13, 17, "FINAL SCORE " .. A.score(g), 6)
    r:text(cx - 13, 20, "SHIFTS " .. g.shift .. "  CONTRACTS " .. g.delivered, 5)
    for i, name in ipairs(g.players) do
      local c = g.contributions[i]
      r:text(cx - 18, 22 + i * 3, name .. " - " .. c.actions .. " ACTIONS, " .. c.shifts .. " SHIFTS", 11, r.w - 6)
    end
    r:button(cx - 18, r.h - 14, 36, 4, "NEW EXPEDITION", function()
      self.scene = "setup"
    end, { color = 9 })
  else
    r:text(math.floor(r.w / 2) - 22, math.floor(r.h / 4), "RAILWAY COMPLETED", 9)
    r:text(math.floor(r.w / 2) - 25, math.floor(r.h / 4) + 7, "THE CLOCKWORK RAILWAY REACHES THE CAPITAL", 17)
    r:text(math.floor(r.w / 2) - 13, math.floor(r.h / 4) + 13, "TOTAL SCORE " .. A.score(g), 6)
    r:text(math.floor(r.w / 2) - 13, math.floor(r.h / 4) + 16, "SHIFTS " .. g.shift .. "  CONTRACTS " .. g.delivered, 5)
    for i, name in ipairs(g.players) do
      local c = g.contributions[i]
      r:text(
        math.floor(r.w / 2) - 16,
        math.floor(r.h / 4) + 18 + i * 2,
        name .. " - " .. c.actions .. " ACTIONS, " .. c.shifts .. " SHIFTS",
        11
      )
    end
    r:button(math.floor(r.w / 2) - 20, math.floor(r.h / 4) + 29, 40, 5, "NEW EXPEDITION", function()
      self.scene = "setup"
    end, { icon = "train", color = 9 })
  end
  self:bottom()
end
function App:draw()
  local r = self.r
  r:begin()
  if r.w < 70 or r.h < 49 then
    r:text(3, 4, "MONITOR TOO SMALL: MINIMUM 3X3 AT SCALE 0.5", 18)
    r:text(3, 8, "USE A MULTIBLOCK ADVANCED MONITOR.", 5)
  else
    if self.scene == "title" then
      self:title()
    elseif self.scene == "setup" then
      self:setup()
    elseif self.scene == "intro" then
      self:intro()
    elseif self.scene == "factory" and self.game then
      self:factory()
    elseif self.scene == "railway" and self.game then
      self:route()
    elseif self.scene == "warehouse" and self.game then
      self:warehouse()
    elseif self.scene == "blueprints" and self.game then
      self:blueprints()
    elseif self.scene == "help" and self.game then
      self:help()
    elseif self.scene == "results" and self.game then
      self:results()
    else
      self.scene = "title"
      self:title()
    end
    if self.modal then
      -- Modal controls must be exclusive; underlying buttons are not interactive.
      r.buttons = {}
      self:dialog()
    end
  end
  r:finish()
end
function App:touch(x, y)
  local lx, ly = self.r:touchCoords(x, y)
  if lx == nil then
    return false
  end
  return self.r:hit(lx, ly)
end
return App
