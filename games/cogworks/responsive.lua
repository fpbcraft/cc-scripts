-- Responsive graphics-only scenes. The 200x120 renderer remains the fallback
-- for small CC:Tweaked displays and the vanilla text renderer is unchanged.
-- The wide canvas uses CivCraft's native 3x4 pixels-per-character density.
local E = require("games.cogworks.engine")
local C = require("games.cogworks.chapters")
local T = require("games.cogworks.tutorials")
return function(R)
  local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
  end
  local function countAwards(awards)
    local n = 0
    for _, earned in pairs(awards or {}) do
      if earned then
        n = n + 1
      end
    end
    return n
  end
  local function shortSpeed(value)
    return tostring(value) .. "X"
  end
  local function wrapWords(value, width)
    local result, row = {}, ""
    for word in tostring(value or ""):gmatch("%S+") do
      if row ~= "" and #row + #word + 1 > width then
        result[#result + 1] = row
        row = word
      else
        row = row == "" and word or (row .. " " .. word)
      end
    end
    if row ~= "" then
      result[#result + 1] = row
    end
    return result
  end
  local labels = {
    I = "SHAFT",
    G = "COG",
    O = "LARGE",
    Q = "GEARBOX",
    D = "CHAIN",
    V = "BELT",
    Z = "SHIFT",
    C = "CLUTCH",
    R = "DUST",
    B = "BLOCK",
  }
  function R:wideFrame(title, subtitle)
    local w, h = self.canvasW, self.canvasH
    self:rect(0, 0, w, h, 0)
    self:rect(0, 0, w, 26, 1)
    self:rect(0, 25, w, 1, 6)
    for x = 0, w - 1, 13 do
      self:rect(x, 24, 6, 1, 7)
    end
    self:fontFit(9, 5, title, 6, w - 164)
    self:fontFit(9, 15, subtitle or "", 11, w - 20)
    self:rect(0, h - 23, w, 23, 1)
    self:rect(0, h - 23, w, 1, 12)
  end
  function R:widePanel(x, y, w, h, heading)
    self:rect(x, y, w, h, 3)
    self:rect(x + 1, y + 1, w - 2, h - 2, 1)
    self:rect(x + 1, y + 1, w - 2, 12, 2)
    self:rect(x + 1, y + 12, w - 2, 1, 12)
    self:fontFit(x + 5, y + 4, heading, 6, w - 10)
  end
  local function panelRow(self, x, y, w, caption, shade, fill)
    self:rect(x, y, w, 10, fill or 2)
    self:fontFit(x + 4, y + 2, caption, shade or 15, w - 8)
  end
  function R:wideBriefing(m)
    local b, w, h = m.briefing, self.canvasW, self.canvasH
    if self.lastBriefing ~= b then
      self.lastBriefing = b
      self.briefingFrame = 0
    end
    local tick = m.settings.animations ~= false and self.briefingFrame or 1000
    self.briefingFrame = math.min(self.briefingFrame + 1, 100000)
    self:wideFrame(
      "COGWORKS  /  MISSION BRIEF",
      "DISTRICT " .. b.chapter .. "  /  LEVEL " .. string.format("%02d", b.number)
    )
    self:font(w - 65, 7, string.format("%02d / %02d", b.number, #E.levels), 15)
    local x, y, heroW, heroH = 9, 33, w - 18, 65
    self:rect(x, y, heroW, heroH, 12)
    self:rect(x + 2, y + 2, heroW - 4, heroH - 4, 1)
    self:rect(x + 2, y + 2, 3, heroH - 4, 6)
    if tick >= 2 then
      self:font(x + 11, y + 7, "WORK ORDER  " .. string.format("%02d", b.number), 11)
    end
    if tick >= 5 then
      if #b.name * 8 <= heroW - 24 then
        self:fontLarge(x + 11, y + 19, b.name, 15)
      else
        self:fontFit(x + 11, y + 23, b.name, 15, heroW - 22)
      end
      self:rect(x + 11, y + 35, heroW - 25, 1, 6)
    end
    if tick >= 8 then
      for i, line in ipairs(wrapWords(b.tip, math.floor((heroW - 29) / 4))) do
        if i > 3 then
          break
        end
        self:fontFit(x + 11, y + 39 + (i - 1) * 7, line, 11, heroW - 21)
      end
    end
    local bottom = h - 32
    local lowerY, lowerH = 105, math.max(20, bottom - 105)
    local leftW = math.floor((w - 28) * 0.46)
    local leftX, rightX = 9, 17 + leftW
    local rightW = w - rightX - 9
    self:widePanel(leftX, lowerY, leftW, lowerH, "TARGETS / " .. #b.targets)
    self:widePanel(rightX, lowerY, rightW, lowerH, "AVAILABLE PARTS / " .. b.stockTotal)
    for i, goal in ipairs(b.targets) do
      local gy = lowerY + 16 + (i - 1) * 12
      if gy + 10 <= bottom - 2 then
        local spin = goal.spin
        self:rect(leftX + 6, gy + 2, 6, 6, spin == "CCW" and 14 or 11)
        panelRow(
          self,
          leftX + 16,
          gy,
          leftW - 22,
          string.format("%d  %s %s  C%d R%d", i, spin, shortSpeed(goal.rpm), goal.x, goal.y),
          15,
          i % 2 == 0 and 2 or 1
        )
      end
    end
    local columns = rightW >= 104 and 2 or 1
    local columnW = math.floor((rightW - 15) / columns)
    for i, part in ipairs(b.stock) do
      local col = (i - 1) % columns
      local row = math.floor((i - 1) / columns)
      local px = rightX + 5 + col * columnW
      local py = lowerY + 16 + row * 12
      if py + 10 <= bottom - 2 then
        self:rect(px, py, columnW - 2, 10, 2)
        self:rect(px + 2, py + 2, 6, 6, E.parts[part.kind].color)
        self:font(px + 3, py + 2, part.kind, 0)
        self:fontFit(px + 12, py + 2, labels[part.kind] .. " " .. part.count, 15, columnW - 14)
      end
    end
    local bonusNames = {}
    for _, bonus in ipairs(b.bonus or {}) do
      bonusNames[#bonusNames + 1] = bonus.name
    end
    local notice = #bonusNames > 0 and ("OPTIONAL: " .. table.concat(bonusNames, " / "))
      or "NO BONUS GOALS / SOLVE THE MAIN PUZZLE"
    self:fontFit(9, h - 15, notice, 11, w - 102)
    self:button(w - 86, h - 20, 77, 17, "START LEVEL", "beginLevel", nil, 6)
    -- Tapping the mission card still starts the level, as in compact mode.
    self:add(9, 33, w - 18, 65, "beginLevel")
  end
  -- The playfield is sized to the puzzle, not to a fixed percentage of the
  -- window. Taller displays give it more space; wider ones give the surplus
  -- to the component palette. Board and sidebar are adjacent with a 5px gap.
  function R:gameLayout(g)
    local w, h = self.canvasW, self.canvasH
    local left, top, gap, bottom = 3, 22, 5, h - 14
    local height = bottom - top
    local sideWidth = clamp(math.floor(w * 0.29), 100, 170)
    local sideCell = math.floor(math.min((w - sideWidth - gap - 8) / g.width, (height - 4) / g.height))
    local dockHeight = g.editor and 82 or 70
    local dockCell = math.floor(math.min((w - 8) / g.width, (height - dockHeight - gap - 4) / g.height))
    local docked = dockCell > sideCell
    local cell = math.max(4, docked and dockCell or sideCell)
    local gridWidth, gridHeight = cell * g.width, cell * g.height
    local boardWidth = docked and w - 6 or gridWidth + 4
    local boardHeight = docked and gridHeight + 4 or height
    local gridX = left + math.floor((boardWidth - gridWidth) / 2)
    local gridY = top + math.floor((boardHeight - gridHeight) / 2)
    local sidebar = docked and { x = left, y = top + boardHeight + gap, w = w - 6, h = height - boardHeight - gap }
      or { x = left + boardWidth + gap, y = top, w = w - left - boardWidth - gap - 3, h = height }
    return {
      board = { x = left, y = top, w = boardWidth, h = boardHeight },
      grid = { x = gridX, y = gridY, w = gridWidth, h = gridHeight },
      sidebar = sidebar,
      cell = cell,
      docked = docked,
      columns = (docked or sidebar.h < 165) and 5 or 2,
    }
  end
  function R:wideGame(m)
    local g, result, w, h = m.game, m.result, self.canvasW, self.canvasH
    local title = g.editor and "COGWORKS / EDITOR"
      or g.custom and "COGWORKS / USER PACK"
      or g.sandbox and "COGWORKS / SANDBOX"
      or ("COGWORKS / LEVEL " .. string.format("%02d", g.number))
    -- The 26px page banner and 23px footer are not needed during building.
    -- Keep just the controls and one contextual line; no persistent legend.
    self:rect(0, 0, w, h, 0)
    self:rect(0, 0, w, 20, 1)
    self:rect(0, 19, w, 1, 6)
    self:fontFit(7, 3, title, 6, w - 148)
    self:fontFit(7, 12, (g.name or "MECHANICAL WORKSHOP") .. "  /  MOVES " .. g.moves, 11, w - 148)
    self:rect(0, h - 12, w, 12, 1)
    self:rect(0, h - 12, w, 1, 12)
    local buttonY, buttonH = 2, 16
    self:button(w - 27, buttonY, 19, buttonH, "?", "help")
    self:button(w - 67, buttonY, 37, buttonH, g.editor and "MENU" or "PAUSE", g.editor and "editorMenu" or "pause")
    self:button(
      w - 102,
      buttonY,
      32,
      buttonH,
      g.editor and "SAVE" or (g.sandbox and "CLEAR" or "SAVE"),
      g.editor and "editorSave" or (g.sandbox and "clearSandbox" or "save")
    )
    self:button(w - 135, buttonY, 30, buttonH, m.settings.animations and "RUN" or "OFF", "toggleAnimations")
    self.currentGameLayout = self:gameLayout(g)
    local layout = self.currentGameLayout
    local by, bh = layout.sidebar.y, layout.sidebar.h
    local sx, sw = layout.sidebar.x, layout.sidebar.w
    local cell = layout.cell
    self.cell, self.boardX, self.boardY = cell, layout.grid.x, layout.grid.y
    -- Frame only the occupied cells, rather than a large empty board panel.
    -- No detached board title, oversized outline or horizontal dead space.
    self:rect(self.boardX - 2, self.boardY - 2, layout.grid.w + 3, layout.grid.h + 3, 3)
    self:rect(self.boardX - 1, self.boardY - 1, layout.grid.w + 1, layout.grid.h + 1, 1)
    for y = 1, g.height do
      for x = 1, g.width do
        local px = self.boardX + (x - 1) * cell
        local py = self.boardY + (y - 1) * cell
        self:rect(px, py, cell, cell, 2)
        self:rect(px, py, cell, 1, 3)
        self:rect(px, py, 1, cell, 3)
        self:rect(px + math.floor(cell / 2), py + math.floor(cell / 2), 1, 1, 3)
      end
    end
    self:drawSpans(g, result)
    local directions = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
    for y = 1, g.height do
      for x = 1, g.width do
        local px = self.boardX + (x - 1) * cell
        local py = self.boardY + (y - 1) * cell
        local span = cell
        local tile = E.get(g, x, y)
        if
          tile
          and not (
            m.drag
            and m.drag.moved
            and m.drag.origin == "board"
            and tile.x == m.drag.fromX
            and tile.y == m.drag.fromY
          )
        then
          if tile.kind == "R" or tile.kind == "B" then
            self:redstonePiece(g, tile, result, px, py, span)
            self:fixedFrame(px, py, span, tile, g.editor)
          else
            self:piece(px, py, span, tile, result.lights[tile.id])
            self:fixedFrame(px, py, span, tile, g.editor)
          end
          if m.settings.showPorts and tile.kind ~= "X" then
            for dir = 0, 3 do
              if E.hasPort(tile, dir) and not E.connection(g, tile, dir) and tile.kind ~= "Q" then
                local radius = math.max(2, math.floor(span / 2) - 1)
                self:rect(
                  px + radius + directions[dir + 1][1] * radius,
                  py + radius + directions[dir + 1][2] * radius,
                  1,
                  1,
                  8
                )
              end
            end
          end
        end
        self:add(px, py, span, span, "cell", x, y)
      end
    end
    self:drawBonusMarks(g)
    self:widePanel(sx, by, sw, bh, "PARTS")
    self:fontFit(
      sx + sw - 42,
      by + 4,
      g.sandbox and "FREE" or (result.correct .. "/" .. result.goals .. " OUT"),
      result.win and 9 or 11,
      38
    )
    local columns = layout.columns
    local rows = math.ceil(#E.order / columns)
    local columnW = math.floor((sw - 8) / columns)
    local buttonH = clamp(math.floor((bh - 70) / rows), 9, 16)
    for i, kind in ipairs(E.order) do
      local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
      local px, py = sx + 4 + col * columnW, by + 16 + row * (buttonH + 2)
      local count = g.remaining[kind] or 0
      local active = m.selected == kind
      self:rect(px, py, columnW - 2, buttonH, active and 6 or 12)
      self:rect(px + 1, py + 1, columnW - 4, buttonH - 2, active and 3 or 1)
      self:toolIcon(px + 1, py + 1, kind)
      if columnW >= 32 then
        self:fontFit(px + 10, py + 3, labels[kind], count > 0 and 15 or 4, columnW - 24)
      end
      self:fontFit(px + columnW - 10, py + 3, count == math.huge and "++" or tostring(count), count > 0 and 9 or 4, 9)
      self:add(px, py, columnW - 2, buttonH, "tool", kind)
    end
    local actionsY = by + 17 + rows * (buttonH + 2)
    local actionH = columns == 5 and 10 or 13
    local actionW = math.floor((sw - 9) / 2)
    self:button(sx + 4, actionsY, actionW, actionH, m.selected == "erase" and "ERASING" or "ERASE", "tool", "erase")
    self:button(
      sx + 5 + actionW,
      actionsY,
      actionW,
      actionH,
      g.sandbox and ("SIZE " .. g.width) or "ROTATE",
      g.sandbox and "sandboxSize" or nil,
      g.sandbox and (5 + g.width % 6) or nil
    )
    local detailY = actionsY + actionH + 3
    local available = by + bh - detailY
    if g.editor then
      if available >= 16 then
        self:fontFit(sx + 4, detailY, "EDITOR TOOLS", 6, sw - 8)
        local kinds = { { "SRC", "S" }, { "GOAL", "M" }, { "WALL", "X" } }
        local toolW = math.floor((sw - 11) / 3)
        for i, item in ipairs(kinds) do
          self:button(sx + 4 + (i - 1) * toolW, detailY + 8, toolW - 1, 11, item[1], "editorTool", item[2])
        end
      end
      if available >= 30 then
        local commands =
          { { "FIX", "editorFix" }, { "RATE", "editorRate" }, { "DIR", "editorSpin" }, { "TEST", "editorTest" } }
        local toolW = math.floor((sw - 9) / 4)
        for i, item in ipairs(commands) do
          self:button(sx + 4 + (i - 1) * toolW, detailY + 19, toolW - 1, 9, item[1], item[2])
        end
      end
    else
      local awards = (m.progress and m.progress.awards and m.progress.awards[g.number]) or {}
      local bonuses = E.challenges(g, result)
      local y = detailY
      if columns == 2 then
        self:fontFit(sx + 4, y, #bonuses > 0 and "BONUS GOALS" or "NO BONUS GOALS", 6, sw - 8)
        y = y + 9
      end
      for index, bonus in ipairs(bonuses) do
        if y + 7 <= by + bh - 2 then
          self:rect(sx + 4, y + 1, 6, 6, awards[bonus.id] and 9 or (bonus.earned and 6 or 4))
          local progressWidth = bonus.progress and (#bonus.progress * 4 + 4) or 0
          self:fontFit(sx + 14, y + 2, bonus.name, awards[bonus.id] and 9 or 15, sw - 19 - progressWidth)
          if bonus.progress then
            self:font(sx + sw - progressWidth, y + 2, bonus.progress, 11)
          end
          self:add(sx + 3, y, sw - 6, columns == 5 and 8 or 10, "inspectBonus", bonus.id)
          y = y + (columns == 5 and 9 or 12)
          local lines = wrapWords(bonus.description, math.max(10, math.floor((sw - 20) / 4)))
          if y + #lines * 7 + (#bonuses - index) * (columns == 5 and 9 or 12) <= by + bh - 2 then
            for _, line in ipairs(lines) do
              self:fontFit(sx + 14, y, line, 11, sw - 19)
              y = y + 7
            end
            y = y + 3
          end
        end
      end
    end
    if m.inspected then
      local tile = E.get(g, m.inspected.x, m.inspected.y)
      if tile then
        local px = self.boardX + (tile.x - 1) * cell
        local py = self.boardY + (tile.y - 1) * cell
        local span = cell
        self:rect(px, py, span, 1, 11)
        self:rect(px, py + span - 1, span, 1, 11)
        self:rect(px, py, 1, span, 11)
        self:rect(px + span - 1, py, 1, span, 11)
        local hit = math.min(7, math.floor(span / 2))
        if not tile.fixed and tile.kind ~= "R" and tile.kind ~= "B" then
          self:rect(px + 1, py + 1, hit - 1, hit - 1, 11)
          self:font(px + 1, py + 1, "+", 0)
          self:add(px, py, hit, hit, "rotate", tile.x, tile.y)
        end
        if not tile.fixed then
          self:rect(px + span - hit, py + 1, hit - 1, hit - 1, 8)
          self:font(px + span - hit, py + 1, "X", 0)
          self:add(px + span - hit, py, hit, hit, "remove", tile.x, tile.y)
        end
      end
    end
    local selected = E.parts[m.selected]
    local hint = selected
        and ((selected.name or labels[m.selected]) .. " / " .. (T.descriptions[m.selected] or "TAP A FREE CELL"))
      or "SELECT A PART TO BUILD"
    self:fontFit(
      7,
      h - 9,
      m.message ~= "" and m.message or hint,
      result.win and 9 or 5,
      result.win and w - 78 or w - 14
    )
    if result.win then
      self:button(w - 70, h - 11, 66, 10, "FACTORY MAP", "map", nil, 9)
    end
  end
  local function dots(self, x1, y1, x2, y2, color)
    local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    for step = 0, distance, 7 do
      local fraction = distance == 0 and 0 or step / distance
      self:rect(math.floor(x1 + (x2 - x1) * fraction), math.floor(y1 + (y2 - y1) * fraction), 3, 2, color)
    end
  end
  function R:wideMap(m, district)
    local w, h = self.canvasW, self.canvasH
    local chapter = district and m.chapters[m.levelChapter] or nil
    local status = district and C.stats(m.progress, m.levelChapter) or nil
    self:wideFrame(
      district and ("DISTRICT " .. m.levelChapter .. "  /  " .. chapter.name) or "THE FACTORY OVERWORLD",
      district and (status.main .. "/8 CLEARED  /  " .. status.bonuses .. " BONUSES  /  FOLLOW TRACKS")
        or "CHOOSE A DISTRICT  /  THREE CLEARS OPEN THE NEXT AREA"
    )
    local left, top, width, height = 10, 34, w - 20, h - 69
    self:widePanel(left, top, width, height, district and "WORKSHOP ROUTES" or "FACTORY DISTRICTS")
    if district then
      local places = {}
      local nodeW, nodeH = 37, 21
      for i, pos in ipairs(C.mapNodes) do
        local x = left + 13 + math.floor((pos[1] - 12) / 152 * (width - nodeW - 26))
        local y = top + 17 + math.floor((pos[2] - 27) / 55 * (height - nodeH - 39))
        places[i] = { x = x, y = y }
      end
      for _, edge in ipairs(C.paths) do
        local a, b = places[edge[1]], places[edge[2]]
        local first, second = chapter.first + edge[1] - 1, chapter.first + edge[2] - 1
        local visible = m.devSession or (C.levelUnlocked(m.progress, first) and C.levelUnlocked(m.progress, second))
        dots(self, a.x + nodeW / 2, a.y + nodeH / 2, b.x + nodeW / 2, b.y + nodeH / 2, visible and 11 or 4)
      end
      for i, point in ipairs(places) do
        local number = chapter.first + i - 1
        local stage = E.levels[number]
        local unlocked = C.levelUnlocked(m.progress, number, m.devSession)
        local cleared = (m.progress.best or {})[number] ~= nil
        local color = cleared and 9 or (unlocked and 6 or 3)
        self:rect(point.x, point.y, nodeW, nodeH, color)
        self:rect(point.x + 1, point.y + 1, nodeW - 2, nodeH - 2, 1)
        self:fontFit(point.x + 3, point.y + 3, string.format("%02d", number), unlocked and 15 or 4, nodeW - 6)
        local awards = countAwards(m.progress.awards[number])
        self:fontFit(
          point.x + 3,
          point.y + 12,
          awards .. "/" .. #stage.bonuses .. " BONUS",
          unlocked and 11 or 4,
          nodeW - 5
        )
        self:fontFit(point.x - 2, point.y + nodeH + 2, stage.name, unlocked and 15 or 4, nodeW + 12)
        if unlocked then
          self:add(point.x, point.y, nodeW, nodeH, "level", number)
        end
      end
    else
      local cols, rows = 4, 2
      local cellW, cellH = math.floor((width - 20) / cols), math.floor((height - 20) / rows)
      for i, chapterInfo in ipairs(m.chapters) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, y = left + 10 + col * cellW, top + 16 + row * cellH
        local active = m.devSession or C.unlocked(m.progress, i)
        local stats = C.stats(m.progress, i)
        local nodeW, nodeH = cellW - 7, cellH - 6
        self:rect(x, y, nodeW, nodeH, active and (stats.main >= 3 and 9 or 6) or 3)
        self:rect(x + 1, y + 1, nodeW - 2, nodeH - 2, 1)
        self:fontFit(x + 5, y + 5, string.format("%02d %s", i, chapterInfo.name), active and 15 or 4, nodeW - 10)
        self:fontFit(
          x + 5,
          y + 16,
          active and (stats.main .. "/8 MACHINES") or "SEALED",
          active and 11 or 4,
          nodeW - 10
        )
        if active then
          self:add(x, y, nodeW, nodeH, "chapter", i)
        end
      end
    end
    self:fontFit(
      10,
      h - 16,
      district and "GREEN = CLEARED   GOLD = ACCESSIBLE" or "EXPLORE SIDE PATHS / SKIP AND REVISIT PUZZLES",
      11,
      w - 103
    )
    self:button(w - 94, h - 20, 84, 17, district and "WORLD MAP" or "BACK", "back")
  end
  function R:wideMenu(m)
    local w, h, scene = self.canvasW, self.canvasH, m.scene
    local title, description, items
    if scene == "title" then
      title, description = "COGWORKS  /  KINETIC LAB", "BUILD / EXPERIMENT / DISCOVER"
      local saved = false
      for _, slot in ipairs(m.slots) do
        if not slot.empty then
          saved = true
        end
      end
      items = {
        { "CONTINUE CAMPAIGN", saved and "continue" or nil },
        { "SELECT SAVE SLOT", "slots" },
        { "FREE WORKSHOP", "sandbox" },
        { "LEVEL EDITOR", "editor" },
        { "CUSTOM PUZZLES", "packs" },
        { "SETTINGS", "settings" },
        { "EXIT", "exit" },
      }
      if m.dev then
        table.insert(items, 6, { "DEV LEVELS", "devLevels" })
      end
    elseif scene == "slots" then
      title, description, items = "SELECT A SAVE", "THREE INDEPENDENT CAMPAIGNS", {}
      for _, slot in ipairs(m.slots) do
        local name = slot.empty and "NEW CAMPAIGN" or ("LEVEL " .. slot.level .. " / BONUSES " .. slot.trophies)
        items[#items + 1] = { "SLOT " .. slot.number .. "  /  " .. name, "slot", slot.number }
      end
      items[#items + 1] = { "BACK", "back" }
    elseif scene == "pause" then
      title, description = "WORKSHOP PAUSED", m.game.name
      if m.game.sandbox then
        items = {
          { "RESUME", "resume" },
          { "CLEAR WORKSHOP", "clearSandbox" },
          { "SETTINGS", "settings" },
          { "HELP", "help" },
          { "TITLE MENU", "title" },
        }
      else
        items = {
          { "RESUME", "resume" },
          { "FACTORY MAP", "levels" },
          { "SAVE PROGRESS", "save" },
          { "RESTART PUZZLE", "restart" },
          { "SETTINGS", "settings" },
          { "HELP", "help" },
          { "NEW CAMPAIGN", m.devSession and nil or "newGame" },
          { "TITLE MENU", "title" },
        }
      end
    elseif scene == "settings" then
      title, description = "DISPLAY SETTINGS", "CHANGES ARE SAVED AUTOMATICALLY"
      items = {
        { "ANIMATION " .. (m.settings.animations and "ON" or "OFF"), "toggleAnimations" },
        { "OPEN PORTS " .. (m.settings.showPorts and "ON" or "OFF"), "togglePorts" },
        { "BACK", "back" },
      }
    elseif scene == "editorMenu" then
      title, description = "LEVEL EDITOR", "CREATE / SAVE / EXPORT MECHANICAL PUZZLES"
      items = {
        { "RESUME EDITING", "resume" },
        { "SAVE LEVEL", "editorSave" },
        { "LOAD LEVEL", "editorLoad" },
        { "COMPILE PACK", "editorCompile" },
        { "TEST NETWORK", "editorTest" },
        { "NEW LEVEL", "editorNew" },
        { "TITLE MENU", "title" },
      }
    elseif scene == "confirm" then
      title = "CONFIRM ACTION"
      description = m.pending == "newGame" and "THIS WILL DELETE SAVE SLOT PROGRESS"
        or "THE CURRENT MACHINE WILL BE RESET"
      items = { { "CANCEL", "cancel" }, { "CONFIRM", "confirm" } }
    elseif scene == "help" then
      title, description = "MECHANICAL REFERENCE", "BUILD CONNECTIONS / POWER PRESSES / AVOID JAMS"
      items = { { "BACK", "back" } }
      if m.game and #T.forLevel(m.game.number) > 0 then
        items[#items + 1] = { "REPLAY PONDER", "replayTutorial" }
      end
    end
    if not items then
      return false
    end
    self:wideFrame(title, description)
    local margin, top, bottom = 10, 34, h - 29
    if scene == "help" then
      self:widePanel(margin, top, w - 20, bottom - top, "HOW THE MACHINE WORKS")
      local rows = {
        { "SHAFT / AXIAL POWER", "COGS / MESH AND REVERSE" },
        { "LARGE COG / SPEED CHANGE", "GEARBOX / RIGHT ANGLE" },
        { "CHAIN / LINK PARALLEL DRIVES", "BELT / CROSS OPEN SPANS" },
        { "GEARSHIFT / REVERSE", "CLUTCH / STOP TRANSMISSION" },
        { "DUST / SIGNAL", "BLOCK / POWER REDSTONE" },
        { "TAP FREE SPACE TO BUILD", "TAP A PART FOR ROTATE / REMOVE" },
        { "CYAN = CW, ORANGE = CCW", "BONUSES ARE OPTIONAL" },
      }
      local rowH = clamp(math.floor((bottom - top - 28) / #rows), 9, 15)
      for i, row in ipairs(rows) do
        local y = top + 15 + (i - 1) * rowH
        self:fontFit(margin + 8, y, row[1], 15, math.floor((w - 33) / 2))
        self:fontFit(math.floor(w / 2) + 3, y, row[2], 11, math.floor(w / 2) - 16)
      end
      for i, item in ipairs(items) do
        self:button(w - i * 103 - 8, h - 20, 99, 17, item[1], item[2])
      end
    else
      local cols = w >= 275 and 2 or 1
      local rows = math.ceil(#items / cols)
      local gap = 8
      local cellW = math.floor((w - 22 - gap * (cols - 1)) / cols)
      local cellH = clamp(math.floor((bottom - top - 6) / rows) - 5, 16, 26)
      local y0 = top + math.max(2, math.floor((bottom - top - rows * (cellH + 5)) / 2))
      for i, item in ipairs(items) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        self:button(11 + col * (cellW + gap), y0 + row * (cellH + 5), cellW, cellH, item[1], item[2], item[3])
      end
      self:fontFit(10, h - 15, m.message or "", 9, w - 20)
    end
    return true
  end
  function R:wideTutorial(m)
    self:wideGame(m)
    self.targets = {}
    local w, h = self.canvasW, self.canvasH
    local lesson = m.tutorial.steps[m.tutorial.index]
    local x, y, panelW, panelH = 16, 34, w - 32, h - 69
    self:rect(x, y, panelW, panelH, 7)
    self:rect(x + 2, y + 2, panelW - 4, panelH - 4, 1)
    self:fontFit(x + 10, y + 8, "PONDER   " .. m.tutorial.index .. "/" .. #m.tutorial.steps, 6, panelW - 20)
    self:fontFit(x + 10, y + 21, lesson.title, 15, panelW - 20)
    local demoY = y + 39
    local powered = { powered = true, correct = true }
    local key = lesson.key
    local cx = x + math.floor(panelW / 2)
    if key == "V" or key == "D" then
      self:piece(cx - 46, demoY, 15, { kind = key, r = 1, enabled = true }, powered)
      self:piece(cx + 31, demoY, 15, { kind = key, r = 1, enabled = true }, powered)
      self:drawSpan(cx - 31, demoY + 7, cx + 31, demoY + 7, key, true)
    else
      self:piece(cx - 40, demoY, 15, { kind = "S", r = 1 }, powered)
      self:line(cx - 24, demoY + 7, cx - 10, demoY + 7, 6)
      self:piece(cx - 7, demoY, 15, { kind = key, r = 1, enabled = true }, powered)
      self:line(cx + 9, demoY + 7, cx + 23, demoY + 7, 6)
      self:piece(cx + 26, demoY, 15, { kind = "M", r = 3, sign = 1, speed = 1 }, powered)
    end
    local lineY = y + math.min(66, panelH - 39)
    for i, line in ipairs(lesson.lines) do
      self:fontFit(x + 10, lineY + (i - 1) * 8, line, 15, panelW - 20)
    end
    self:button(19, h - 20, 88, 17, "SKIP TUTORIAL", "tutorialSkip")
    self:button(w - 107, h - 20, 88, 17, m.tutorial.index == #m.tutorial.steps and "GOT IT" or "NEXT", "tutorialNext")
  end
  function R:wideList(m)
    local scene, w, h = m.scene, self.canvasW, self.canvasH
    local entries, action, heading
    if scene == "editorList" then
      entries, action, heading = m.editorFiles or {}, "editorLoadFile", "SAVED PUZZLES"
    elseif scene == "packList" then
      entries, action, heading = m.packFiles or {}, "pack", "CUSTOM PACKS"
    else
      entries = m.activePack and m.activePack.levels or {}
      action = "packLevel"
      heading = m.activePack and m.activePack.title or "CUSTOM LEVELS"
    end
    self:wideFrame(heading, "SELECT A FILE OR USE THE PAGE BUTTONS")
    local rows, page = 7, m.catalogPage or 1
    local left, width, rowH = 12, w - 24, clamp(math.floor((h - 78) / rows), 13, 22)
    for slot = 1, rows do
      local index = (page - 1) * rows + slot
      local item = entries[index]
      if item then
        local caption = type(item) == "table" and (item.name or item.title) or item
        local arg = type(item) == "table" and index or item
        self:button(left, 34 + (slot - 1) * (rowH + 3), width, rowH, index .. "  " .. tostring(caption), action, arg)
      end
    end
    if page > 1 then
      self:button(12, h - 20, 63, 17, "PREVIOUS", "catalogPage", page - 1)
    end
    self:button(math.floor((w - 68) / 2), h - 20, 68, 17, "BACK", "back")
    if page * rows < #entries then
      self:button(w - 75, h - 20, 63, 17, "NEXT", "catalogPage", page + 1)
    end
  end
  function R:drawResponsive(m)
    if m.scene == "game" or m.scene == "editor" then
      self:wideGame(m)
    elseif m.scene == "briefing" then
      self:wideBriefing(m)
    elseif m.scene == "tutorial" then
      self:wideTutorial(m)
    elseif m.scene == "levels" or m.scene == "chapter" then
      self:wideMap(m, m.scene == "chapter")
    elseif m.scene == "editorList" or m.scene == "packList" or m.scene == "packLevels" then
      self:wideList(m)
    else
      return self:wideMenu(m)
    end
    return true
  end
end
