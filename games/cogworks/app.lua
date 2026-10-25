-- COGWORKS interface controller. Game rules stay in the pure Lua engine.
local E = require("games.cogworks.engine")
local S = require("games.cogworks.storage")
local T = require("games.cogworks.tutorials")
local B = require("games.cogworks.briefing")
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
function A.new()
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
    tutorial = nil,
    briefing = nil,
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
  assert(self.progress and index >= 1 and index <= self.progress.unlocked)
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
  assert(slot >= 1 and slot <= 3)
  self.slot = slot
  self.progress = newGame and self.store.newProgress() or self.store.load(slot)
  if not self.progress then
    self.progress = self.store.newProgress()
  end
  self.settings.lastSlot = slot
  self.cachedSlots = nil
  self.store.saveSettings(self.settings)
  self:openLevel(self.progress.level)
  self:save()
end
function A:save()
  if not self.slot or not self.game then
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
  if self.result.win then
    self.progress.unlocked = math.max(self.progress.unlocked, math.min(#E.levels, self.game.number + 1))
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
    self.message = additions > 0 and ("LEVEL CLEAR + " .. additions .. " BONUS") or "LEVEL CLEAR - NEXT UNLOCKED"
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
    tutorial = self.tutorial,
    briefing = self.briefing,
    hasLeftInput = self.hasLeftInput or false,
  }
end
-- Return 'exit' only in direct response to player choosing Exit.
function A:act(action, x, y)
  local scene = self.scene
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
  elseif scene == "game" then
    local changed = false
    self.message = ""
    if action == "cell" or action == "remove" then
      local tile = E.get(self.game, x, y)
      if action == "remove" or self.selected == "erase" then
        changed = E.remove(self.game, x, y)
      elseif tile then
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
    elseif action == "tool" then
      if x == "erase" or E.parts[x] then
        self.selected = x
      end
    elseif action == "next" or action == "prev" then
      local nextIndex = self.game.number + (action == "next" and 1 or -1)
      if nextIndex >= 1 and nextIndex <= self.progress.unlocked then
        self:save()
        self:openLevel(nextIndex)
        self:save()
      else
        self.message = "LEVEL LOCKED"
      end
    elseif action == "save" then
      self.message = self:save() and "SAVED TO SLOT " .. self.slot or self.message
    elseif action == "pause" then
      self:save()
      self.scene = "pause"
    elseif action == "help" then
      self.returnScene = "game"
      self.scene = "help"
    elseif action == "reset" then
      self.game = E.new(self.game.number)
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
    elseif action == "levels" then
      self.scene = "levels"
    elseif action == "title" then
      self:save()
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
      self.scene = "pause"
    elseif action == "level" and x >= 1 and x <= self.progress.unlocked then
      self:save()
      self:openLevel(x)
      self:save()
    end
  elseif scene == "confirm" then
    if action == "cancel" or action == "back" then
      self.scene = "pause"
      self.pending = nil
    elseif action == "confirm" then
      if self.pending == "restart" then
        self.game = E.new(self.game.number)
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
