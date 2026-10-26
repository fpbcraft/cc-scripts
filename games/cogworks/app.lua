-- COGWORKS interface controller. Game rules stay in the pure Lua engine.
local E = require("games.cogworks.engine")
local S = require("games.cogworks.storage")
local T = require("games.cogworks.tutorials")
local B = require("games.cogworks.briefing")
local Campaign = require("games.cogworks.chapters")
local Packs = require("games.cogworks.packs")
local Pointer = require("games.cogworks.pointer")
local A = {}
A.__index = A
local function countAward(awards)
  local n = 0
  for _, v in pairs(awards or {}) do
    if v then
      n = n + 1
    end
  end
  return n
end
function A.new(options)
  local self = setmetatable({
    scene = "title",
    settings = S.loadSettings(),
    store = S,
    game = nil,
    result = nil,
    slot = nil,
    progress = nil,
    selected = "I",
    message = "",
    returnScene = "title",
    pending = nil,
    inspected = nil,
    sandboxSize = 10,
    tutorial = nil,
    briefing = nil,
    dev = options and options.dev == true or false,
    devSession = false,
    levelReturn = "pause",
    levelChapter = 1,
    editorId = nil,
    editorSerial = 1,
    customSession = false,
    activePack = nil,
    packIndex = 1,
    catalogPage = 1,
  }, A)
  return self
end
function A:slots()
  if self.cachedSlots then
    return self.cachedSlots
  end
  local slots = {}
  for i = 1, 3 do
    local p = self.store.load(i)
    slots[i] = p
        and {
          number = i,
          empty = false,
          level = p.level,
          unlocked = p.unlocked,
          trophies = (function()
            local count = 0
            for _, awards in pairs(p.awards) do
              count = count + countAward(awards)
            end
            return count
          end)(),
        }
      or { number = i, empty = true, level = 1, unlocked = 1, trophies = 0 }
  end
  self.cachedSlots = slots
  return slots
end
function A:startTutorial(steps, returnScene)
  if #steps == 0 then
    return false
  end
  self.tutorial = { steps = steps, index = 1, returnScene = returnScene or "game" }
  self.scene = "tutorial"
  return true
end
function A:finishTutorial()
  if not self.tutorial then
    return
  end
  self.progress.tutorials = self.progress.tutorials or {}
  for _, step in ipairs(self.tutorial.steps) do
    self.progress.tutorials[step.key] = true
  end
  self.scene = self.tutorial.returnScene
  self.tutorial = nil
  self:save()
end
function A:openLevel(index)
  assert(self.progress and Campaign.levelUnlocked(self.progress, index, self.devSession))
  self.game = E.new(index)
  local session = self.progress.sessions[index]
  if type(session) == "table" and E.restore(self.game, session.parts) then
    self.game.moves = math.max(0, math.floor(tonumber(session.moves) or 0))
  end
  self.progress.level = index
  self.result = E.evaluate(self.game)
  self.selected = "I"
  self.inspected = nil
  self.message = ""
  self.briefing = B.forLevel(index)
  self.scene = "briefing"
end
function A:enter(slot, newGame)
  self.devSession = false
  assert(slot >= 1 and slot <= 3)
  self.slot = slot
  self.progress = newGame and self.store.newProgress() or self.store.load(slot)
  if not self.progress then
    self.progress = self.store.newProgress()
  end
  self.progress.unlocked = Campaign.openLevels(self.progress)
  self.settings.lastSlot = slot
  self.cachedSlots = nil
  self.store.saveSettings(self.settings)
  self:openLevel(self.progress.level)
  self:save()
end
function A:enterSandbox()
  self.slot = nil
  self.devSession = false
  self.game = E.sandbox(self.sandboxSize)
  self.progress = self.store.newProgress()
  self.result = E.evaluate(self.game)
  self.selected = "I"
  self.message = ""
  self.inspected = nil
  self.briefing = nil
  self.scene = "game"
end
function A:enterEditor()
  self.game = E.editor(7, 7)
  self.result = E.evaluate(self.game)
  self.progress = self.store.newProgress()
  self.selected, self.inspected = "I", nil
  self.editorId, self.customSession, self.activePack = nil, false, nil
  self.scene, self.message = "editor", "PLACE PARTS; TAP A GOAL TO EDIT ITS TARGET"
end
function A:loadEditor(id)
  local level, reason = Packs.loadLevel(id)
  if not level then
    self.message = "LOAD ERROR: " .. tostring(reason)
    return false
  end
  self.game = E.fromDefinition(level, true)
  self.game.editor, self.game.sandbox, self.game.custom = true, true, false
  for _, kind in ipairs(E.order) do
    self.game.remaining[kind] = math.huge
  end
  self.editorId, self.inspected, self.selected = id, nil, "I"
  self.result, self.scene = E.evaluate(self.game), "editor"
  self.message = "LOADED " .. id:upper()
  return true
end
function A:saveEditor()
  local levels = Packs.listLevels()
  if not self.editorId then
    local max = 0
    for _, id in ipairs(levels) do
      local n = tonumber(id:match("^level%-(%d+)$"))
      max = math.max(max, n or 0)
    end
    self.editorId = string.format("level-%03d", max + 1)
  end
  local data = Packs.fromEditor(self.game, self.game.name)
  local ok, reason = Packs.saveLevel(self.editorId, data)
  self.message = ok and ("SAVED " .. self.editorId .. ".COGLEVEL") or ("EDITOR: " .. tostring(reason))
  return ok
end
function A:playPack(pack, index)
  self.activePack, self.packIndex = pack, index
  self.customSession, self.devSession, self.slot = true, false, nil
  self.game = E.fromDefinition(pack.levels[index], false)
  self.progress = self.store.newProgress()
  self.result, self.scene, self.selected = E.evaluate(self.game), "game", "I"
  self.inspected, self.message = nil, "CUSTOM PACK: " .. pack.title
end
function A:save()
  if not self.slot or not self.game or self.game.sandbox or self.devSession or self.customSession then
    return false
  end
  self.progress.level = self.game.number
  self.progress.sessions[self.game.number] = {
    parts = E.snapshot(self.game),
    moves = self.game.moves,
  }
  local ok, err = self.store.save(self.slot, self.progress)
  if ok then
    self.cachedSlots = nil
  end
  if not ok then
    self.message = "SAVE ERROR: " .. tostring(err):sub(1, 24)
  end
  return ok
end
function A:updateGame()
  self.result = E.evaluate(self.game)
  if self.customSession then
    self.message = self.result.win and "PACK LEVEL COMPLETE" or (self.result.jam and "GEARS JAMMED" or "")
    return
  end
  if self.game.sandbox then
    self.message = self.result.jam and "JAM: CONTRADICTORY ROTATION" or "FREE BUILD - NO OBJECTIVES"
    return
  end
  if self.devSession then
    self.message = self.result.win and "DEV: REFERENCE POWERED" or (self.result.jam and "JAM" or "")
    return
  end
  if self.result.win then
    local earned = self.progress.awards[self.game.number]
    if type(earned) ~= "table" then
      earned = {}
      self.progress.awards[self.game.number] = earned
    end
    local additions = 0
    for _, bonus in ipairs(E.challenges(self.game, self.result)) do
      if bonus.earned and not earned[bonus.id] then
        earned[bonus.id] = true
        additions = additions + 1
      end
    end
    if self.game.moves >= 0 then
      local best = self.progress.best[self.game.number]
      if not best or self.game.moves < best then
        self.progress.best[self.game.number] = self.game.moves
      end
    end
    local previous = self.progress.unlocked
    self.progress.unlocked = Campaign.openLevels(self.progress)
    self.message = self.progress.unlocked > previous and "NEW DISTRICT OPEN!"
      or (additions > 0 and ("LEVEL CLEAR +" .. additions .. " BONUS") or "LEVEL CLEAR - NEW PATHS OPEN")
  elseif self.result.jam then
    self.message = "JAM: INCONSISTENT ROTATION"
  end
  self:save()
end
function A:model()
  return {
    scene = self.scene,
    game = self.game,
    result = self.result,
    progress = self.progress,
    settings = self.settings,
    slot = self.slot,
    selected = self.selected,
    message = self.message,
    slots = self:slots(),
    returnScene = self.returnScene,
    pending = self.pending,
    inspected = self.inspected,
    moving = self.moving,
    drag = self.drag,
    tutorial = self.tutorial,
    briefing = self.briefing,
    hasLeftInput = self.hasLeftInput or false,
    dev = self.dev,
    devSession = self.devSession,
    sandboxSize = self.sandboxSize,
    chapters = Campaign.chapters,
    levelChapter = self.levelChapter,
    objectives = Campaign.objectives(self.progress or self.store.newProgress()),
    editorId = self.editorId,
    customSession = self.customSession,
    packIndex = self.packIndex,
    activePack = self.activePack,
    editorFiles = self.scene == "editorList" and Packs.listLevels() or nil,
    packFiles = self.scene == "packList" and Packs.listPacks() or nil,
    catalogPage = self.catalogPage,
  }
end
function A:dropDrag(x, y)
  local drag = self.drag
  self.drag, self.inspected = nil, nil
  if not drag or not drag.moved or not Pointer.valid(self.game, drag, x, y) then
    self.message = "DROP CANCELLED"
    return false
  end
  local changed
  if drag.origin == "board" then
    if x == drag.fromX and y == drag.fromY then
      return false
    end
    changed = E.move(self.game, drag.fromX, drag.fromY, x, y)
  else
    changed = E.place(self.game, x, y, drag.kind, drag.r)
  end
  if changed then
    self.message = ""
    if self.game.editor then
      self.result = E.evaluate(self.game)
    else
      self:updateGame()
    end
  end
  return changed
end
-- Return 'exit' only in direct response to player choosing Exit.
function A:act(action, x, y)
  local scene = self.scene
  if scene == "game" or scene == "editor" then
    if action == "moveStart" then
      local part = E.get(self.game, x, y)
      if part and (not part.fixed or self.game.editor) then
        if self.moving and self.moving.x == x and self.moving.y == y then
          self.moving = nil
          self.message = "MOVE CANCELLED"
        else
          self.moving = { x = x, y = y }
          self.inspected = { x = x, y = y }
          self.message = "MOVE: SELECT AN EMPTY CELL"
        end
      end
      return nil
    end
    if self.moving and (action == "cell" or action == "inspect" or action == "moveTo" or action == "remove") then
      local from = self.moving
      if from.x == x and from.y == y then
        self.moving = nil
        self.message = "MOVE CANCELLED"
      elseif E.move(self.game, from.x, from.y, x, y) then
        self.moving = nil
        self.inspected = { x = x, y = y }
        if self.game.editor then
          self.result = E.evaluate(self.game)
        else
          self:updateGame()
        end
        self.message = "PART MOVED"
      else
        self.message = "MOVE: CHOOSE AN EMPTY CELL"
      end
      return nil
    end
    if action == "tool" or action == "editorTool" or action == "pause" or action == "editorMenu" then
      self.moving = nil
    end
  end
  if action == "exit" then
    if self.game then
      self:save()
    end
    return "exit"
  end
  if scene == "title" then
    if action == "continue" then
      local slot = self.settings.lastSlot
      if not self.store.has(slot) then
        for i = 1, 3 do
          if self.store.has(i) then
            slot = i
            break
          end
        end
      end
      if self.store.has(slot) then
        self:enter(slot, false)
      else
        self.scene = "slots"
      end
    elseif action == "slots" then
      self.scene = "slots"
    elseif action == "sandbox" then
      self:enterSandbox()
    elseif action == "devLevels" and self.dev then
      self.devSession = true
      self.slot = nil
      self.game = nil
      self.result = nil
      self.progress = self.store.newProgress()
      self.progress.unlocked = #E.levels
      self.levelChapter = 1
      self.levelReturn = "title"
      self.scene = "levels"
    elseif action == "editor" then
      self:enterEditor()
    elseif action == "packs" then
      self.scene = "packList"
    elseif action == "settings" then
      self.returnScene = "title"
      self.scene = "settings"
    elseif action == "help" then
      self.returnScene = "title"
      self.scene = "help"
    end
  elseif scene == "slots" then
    if action == "back" then
      self.scene = "title"
    elseif action == "slot" then
      self:enter(x, false)
    end
  elseif scene == "help" then
    if action == "back" then
      self.scene = self.returnScene
    elseif action == "replayTutorial" then
      self:startTutorial(T.forLevel(self.game.number), self.returnScene)
    end
  elseif scene == "settings" then
    if action == "back" then
      self.scene = self.returnScene
    elseif action == "toggleAnimations" then
      self.settings.animations = not self.settings.animations
      self.store.saveSettings(self.settings)
    elseif action == "togglePorts" then
      self.settings.showPorts = not self.settings.showPorts
      self.store.saveSettings(self.settings)
    end
  elseif scene == "briefing" then
    if action == "beginLevel" or action == "back" then
      self.scene = "game"
      self:startTutorial(T.unseen(self.game.number, self.progress.tutorials), "game")
    end
  elseif scene == "tutorial" then
    if action == "tutorialNext" then
      if self.tutorial.index < #self.tutorial.steps then
        self.tutorial.index = self.tutorial.index + 1
      else
        self:finishTutorial()
      end
    elseif action == "tutorialSkip" or action == "back" then
      self:finishTutorial()
    end
  elseif scene == "editor" then
    self.message = ""
    local changed = false
    if action == "editorTool" or action == "tool" then
      if x == "erase" or E.parts[x] or x == "S" or x == "M" or x == "X" then
        self.selected, self.inspected = x, nil
      end
    elseif action == "inspect" then
      local tile = E.get(self.game, x, y)
      if tile then
        self.inspected = { x = x, y = y }
        self.message = tile.kind .. " " .. x .. "," .. y
      else
        changed = E.place(self.game, x, y, self.selected)
        self.inspected = nil
      end
    elseif action == "cell" or action == "rotate" or action == "remove" then
      local tile = E.get(self.game, x, y)
      if action == "remove" or self.selected == "erase" and action == "cell" then
        changed = E.remove(self.game, x, y)
      elseif tile then
        changed = E.rotate(self.game, x, y)
        self.inspected = { x = x, y = y }
      else
        changed = E.place(self.game, x, y, self.selected)
      end
    elseif action == "editorFix" and self.inspected then
      local t = E.get(self.game, self.inspected.x, self.inspected.y)
      if t and t.kind ~= "S" and t.kind ~= "M" and t.kind ~= "X" then
        t.fixed = not t.fixed
        changed = true
      end
    elseif (action == "editorRate" or action == "editorSpin") and self.inspected then
      local t = E.get(self.game, self.inspected.x, self.inspected.y)
      if t and t.kind == "M" then
        if action == "editorSpin" then
          t.sign = -t.sign
        else
          local cycle = { [0.5] = 1, [1] = 2, [2] = 4, [4] = 0.5 }
          t.speed = cycle[t.speed] or 1
        end
        changed = true
      end
    elseif action == "sandboxSize" then
      self.sandboxSize = math.max(5, math.min(10, tonumber(x) or 7))
      self.game = E.editor(self.sandboxSize, self.sandboxSize)
      self.editorId, self.inspected, changed = nil, nil, true
    elseif action == "editorSave" then
      self:saveEditor()
    elseif action == "editorTest" then
      local good, reason = Packs.validate(Packs.fromEditor(self.game))
      if not good then
        self.message = "ERROR: " .. tostring(reason)
      else
        self.result = E.evaluate(self.game)
        self.message = self.result.win and "TEST PASSED / ALL TARGETS" or "TEST: COMPLETE ALL TARGETS"
      end
    elseif action == "editorMenu" or action == "pause" then
      self.scene = "editorMenu"
    elseif action == "toggleAnimations" then
      self.settings.animations = not self.settings.animations
      self.store.saveSettings(self.settings)
    end
    if changed then
      self.result = E.evaluate(self.game)
    end
  elseif scene == "editorMenu" then
    if action == "resume" or action == "back" then
      self.scene = "editor"
    elseif action == "editorSave" then
      self:saveEditor()
    elseif action == "editorLoad" then
      self.catalogPage = 1
      self.scene = "editorList"
    elseif action == "editorCompile" then
      if self:saveEditor() then
        local ok, reason = Packs.compile("workshop-pack", "WORKSHOP LEVEL PACK")
        self.message = ok and "COMPILED /PACKS/WORKSHOP-PACK.COGPACK" or ("PACK: " .. tostring(reason))
      end
    elseif action == "editorTest" then
      self.scene = "editor"
      self:act("editorTest")
    elseif action == "editorNew" then
      self:enterEditor()
    elseif action == "title" then
      self.scene = "title"
    end
  elseif scene == "editorList" then
    if action == "back" then
      self.scene = "editorMenu"
    elseif action == "editorLoadFile" then
      self:loadEditor(x)
    elseif action == "catalogPage" then
      self.catalogPage = math.max(1, tonumber(x) or 1)
    end
  elseif scene == "packList" then
    if action == "back" then
      self.scene = "title"
    elseif action == "catalogPage" then
      self.catalogPage = math.max(1, tonumber(x) or 1)
    elseif action == "pack" then
      local pack, reason = Packs.loadPack(x)
      if pack then
        self.activePack = pack
        self.catalogPage = 1
        self.scene = "packLevels"
      else
        self.message = "PACK ERROR: " .. tostring(reason)
      end
    end
  elseif scene == "packLevels" then
    if action == "back" then
      self.scene = "packList"
    elseif action == "packLevel" then
      self:playPack(self.activePack, x)
    elseif action == "catalogPage" then
      self.catalogPage = math.max(1, tonumber(x) or 1)
    end
  elseif scene == "game" then
    local changed = false
    self.message = ""
    if action == "inspectBonus" then
      for _, bonus in ipairs(E.challenges(self.game, self.result)) do
        if bonus.id == x then
          self.message = bonus.description
          break
        end
      end
    elseif action == "inspect" then
      local tile = E.get(self.game, x, y)
      if tile then
        self.inspected = { x = x, y = y }
        local light = self.result.lights[tile.id]
        local spin = light and light.ports and (light.ports[tile.r] or light.ports[next(light.ports)])
        self.message = spin and ((spin.sign > 0 and "CW " or "CCW ") .. spin.rate .. "X") or "IDLE"
      else
        self.inspected = nil
        changed = E.place(self.game, x, y, self.selected)
      end
    elseif action == "cell" or action == "remove" or action == "rotate" then
      local tile = E.get(self.game, x, y)
      self.inspected = nil
      if action == "remove" or self.selected == "erase" and action == "cell" then
        changed = E.remove(self.game, x, y)
      elseif tile and (action == "rotate" or action == "cell") then
        changed = E.rotate(self.game, x, y)
        if tile.kind == "M" then
          local current = self.result.lights[tile.id].ports[tile.r]
          local wanted = (tile.sign < 0 and "CCW" or "CW") .. " " .. tile.speed .. "X"
          local got = current and ((current.sign < 0 and "CCW" or "CW") .. " " .. current.rate .. "X") or "OFF"
          self.message = "NEED " .. wanted .. " / CURRENT " .. got
        elseif tile.kind == "S" then
          self.message = "GENERATOR: CW 1X (FIXED)"
        elseif not changed then
          self.message = "STONE BLOCKS THE WAY"
        end
      else
        changed = E.place(self.game, x, y, self.selected)
        if not changed then
          self.message = "NO STOCK AVAILABLE"
        end
      end
    elseif action == "toggleAnimations" then
      self.settings.animations = not self.settings.animations
      self.store.saveSettings(self.settings)
      self.message = self.settings.animations and "KINETIC ANIMATION ON" or "KINETIC ANIMATION OFF"
    elseif action == "tool" then
      if x == "erase" or E.parts[x] then
        self.inspected = nil
        self.selected = x
      end
    elseif (action == "next" or action == "prev") and self.customSession then
      if self.activePack then
        local nextIndex = self.packIndex + (action == "next" and 1 or -1)
        if nextIndex >= 1 and nextIndex <= #self.activePack.levels then
          self:playPack(self.activePack, nextIndex)
        end
      end
    elseif action == "map" and not self.game.sandbox then
      self:save()
      self.levelChapter = Campaign.chapterFor(self.game.number)
      self.levelReturn = "pause"
      self.scene = "chapter"
    elseif action == "next" or action == "prev" then
      -- A solved level opens neighboring nodes, not necessarily the next ID.
      self:save()
      self.levelChapter = Campaign.chapterFor(self.game.number)
      self.levelReturn = "pause"
      self.scene = "chapter"
    elseif action == "clearSandbox" and self.game.sandbox then
      self.game = E.sandbox(self.sandboxSize)
      changed = true
    elseif action == "save" then
      self.message = self:save() and "SAVED TO SLOT " .. self.slot or "THIS SESSION IS NOT SAVED"
    elseif action == "pause" then
      self:save()
      self.scene = "pause"
    elseif action == "help" then
      self.returnScene = "game"
      self.scene = "help"
    elseif action == "sandboxSize" and self.game.sandbox then
      self.sandboxSize = math.max(5, math.min(10, tonumber(x) or self.sandboxSize))
      self.game = E.sandbox(self.sandboxSize)
      self.inspected = nil
      changed = true
    elseif action == "reset" then
      self.game = self.game.sandbox and E.sandbox(self.sandboxSize) or E.new(self.game.number)
      changed = true
    end
    if changed then
      self:updateGame()
    end
  elseif scene == "pause" then
    if action == "resume" or action == "back" then
      self.scene = "game"
    elseif action == "save" then
      self.message = self:save() and "SAVED TO SLOT " .. self.slot or self.message
    elseif action == "settings" then
      self.returnScene = "pause"
      self.scene = "settings"
    elseif action == "help" then
      self.returnScene = "pause"
      self.scene = "help"
    elseif action == "levels" and not self.game.sandbox then
      self.levelReturn = "pause"
      self.levelChapter = Campaign.chapterFor(self.game.number)
      self.scene = "levels"
    elseif action == "clearSandbox" and self.game.sandbox then
      self.game = E.sandbox(self.sandboxSize)
      self.result = E.evaluate(self.game)
      self.message = "SANDBOX CLEARED"
      self.scene = "game"
    elseif action == "title" then
      self:save()
      self.customSession = false
      self.scene = "title"
      self.message = ""
    elseif action == "restart" then
      self.scene = "confirm"
      self.pending = "restart"
    elseif action == "newGame" then
      self.scene = "confirm"
      self.pending = "newGame"
    end
  elseif scene == "levels" then
    if action == "back" then
      self.scene = self.levelReturn
    elseif action == "chapter" and x >= 1 and x <= #Campaign.chapters then
      if Campaign.unlocked(self.progress, x) or self.devSession then
        self.levelChapter = x
        self.scene = "chapter"
      else
        local stats = Campaign.stats(self.progress, x - 1)
        self.message = "CLEAR "
          .. math.max(0, Campaign.chapters[x - 1].requiredMain - stats.main)
          .. " MORE LEVELS IN THE PREVIOUS AREA"
      end
    end
  elseif scene == "chapter" then
    if action == "back" then
      self.scene = "levels"
    elseif action == "level" and Campaign.levelUnlocked(self.progress, x, self.devSession) then
      self:save()
      self:openLevel(x)
      self.levelReturn = "pause"
      self:save()
    end
  elseif scene == "confirm" then
    if action == "cancel" or action == "back" then
      self.scene = "pause"
      self.pending = nil
    elseif action == "confirm" then
      if self.pending == "restart" then
        self.game = self.customSession and E.fromDefinition(self.activePack.levels[self.packIndex], false)
          or E.new(self.game.number)
        self.result = E.evaluate(self.game)
        self.message = "LEVEL RESET"
        self:save()
        self.scene = "game"
      elseif self.pending == "newGame" then
        self:enter(self.slot, true)
        self.message = "NEW CAMPAIGN IN SLOT " .. self.slot
      end
      self.pending = nil
    end
  end
  return nil
end
return A
