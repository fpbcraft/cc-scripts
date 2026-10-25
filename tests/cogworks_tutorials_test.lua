package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("games.cogworks.tutorials")
local E = require("games.cogworks.engine")
local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for k, v in pairs(value) do
    result[k] = copy(v)
  end
  return result
end
-- Lightweight in-memory save system: the UI controller should not depend on
-- CraftOS files or a monitor to decide when a tutorial appears.
local saved = {}
local S = {}
function S.newProgress()
  return { campaignVersion = 3, level = 1, unlocked = 1, best = {}, sessions = {}, awards = {}, tutorials = {} }
end
function S.loadSettings()
  return { animations = true, showPorts = true, lastSlot = 1 }
end
function S.saveSettings()
  return true
end
function S.load(slot)
  return saved[slot] and copy(saved[slot]) or nil
end
function S.has(slot)
  return saved[slot] ~= nil
end
function S.save(slot, data)
  saved[slot] = copy(data)
  return true
end
package.loaded["games.cogworks.storage"] = S
local A = require("games.cogworks.app")
assert(#E.order == 9 and not E.parts.C, "No redundant clutch")
assert(#T.forLevel(9) == 2, "Speed drive and gearbox are introduced together")
local app = A.new()
app:enter(1, false)
assert(app.scene == "briefing" and app.briefing.number == 1, "Every level starts with its mission briefing")
app:act("beginLevel")
assert(app.scene == "tutorial" and app.tutorial.steps[1].key == "I", "First-ever game opens a shaft Ponder")
app:act("tutorialNext")
assert(app.scene == "game" and saved[1].tutorials.I, "Ponder completion persisted")
app:openLevel(1)
assert(app.scene == "briefing", "Briefing reappears on a familiar level")
app:act("beginLevel")
assert(app.scene == "game", "Visiting a familiar level does not repeat Ponder")
app.progress.unlocked = 30
app:openLevel(9)
assert(app.scene == "briefing" and #app.briefing.targets == 2)
app:act("beginLevel")
assert(app.scene == "tutorial" and #app.tutorial.steps == 2, "First-time level-nine lessons include both mechanics")
app:act("tutorialNext")
assert(app.scene == "tutorial" and app.tutorial.index == 2, "NEXT advances to the next illustrated lesson")
app:act("tutorialSkip")
assert(
  app.scene == "game" and saved[1].tutorials.B and saved[1].tutorials.Q,
  "SKIP acknowledges all remaining lessons for this level"
)
app:openLevel(9)
assert(app.scene == "briefing")
app:act("beginLevel")
assert(app.scene == "game", "Finished tutorials do not repeat after re-entry")
app:openLevel(6)
assert(app.scene == "briefing")
app:act("beginLevel")
assert(app.scene == "tutorial" and app.tutorial.steps[1].key == "V", "First belt puzzle teaches the bridge mechanic")
app:act("tutorialSkip")
app:act("help")
assert(app.scene == "help")
app:act("replayTutorial")
assert(app.scene == "tutorial", "Help allows manual replay")
app:act("tutorialNext")
assert(app.scene == "game", "Replayed guide returns to gameplay")
app:act("pause")
app:act("help")
app:act("replayTutorial")
app:act("tutorialNext")
assert(app.scene == "pause", "Replayed guide returns to the prior menu")
app:enter(2, false)
assert(app.scene == "briefing")
app:act("beginLevel")
assert(app.scene == "tutorial" and app.tutorial.steps[1].key == "I", "Separate save slots learn independently")
app:act("tutorialSkip")
assert(saved[2].tutorials.I and saved[1].tutorials.I, "Seen flags are stored with the corresponding slot")
local again = A.new()
again:enter(1, false)
assert(again.scene == "briefing", "Returning players still get the level briefing")
again:act("beginLevel")
assert(again.scene == "game", "Previously acknowledged lesson stays dismissed after relaunch")
print("COGWORKS: briefing to Ponder flow, replay and slot persistence passed.")
