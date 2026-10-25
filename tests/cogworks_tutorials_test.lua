package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("games.cogworks.tutorials")
local E = require("games.cogworks.engine")
local function copy(v)
  if type(v) ~= "table" then
    return v
  end
  local result = {}
  for k, x in pairs(v) do
    result[k] = copy(x)
  end
  return result
end
local saved = {}
local S = {}
function S.newProgress()
  return { campaignVersion = 4, unlocked = 1, level = 1, best = {}, sessions = {}, awards = {}, tutorials = {} }
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
function S.save(slot, value)
  saved[slot] = copy(value)
  return true
end
package.loaded["games.cogworks.storage"] = S
local A = require("games.cogworks.app")
assert(#T.forLevel(1) == 1 and T.forLevel(1)[1].key == "I")
assert(T.forLevel(2)[1].key == "Q" and T.forLevel(4)[1].key == "G")
assert(T.forLevel(6)[1].key == "D" and T.forLevel(7)[1].key == "Z")
assert(T.forLevel(8)[1].key == "C" and T.forLevel(9)[1].key == "O")
assert(T.forLevel(11)[1].key == "V")
local app = A.new()
app:enter(1, false)
assert(app.scene == "briefing" and app.briefing.number == 1)
app:act("beginLevel")
assert(app.scene == "tutorial" and app.tutorial.steps[1].key == "I")
app:act("tutorialNext")
assert(app.scene == "game" and saved[1].tutorials.I, "Tutorial was saved")
app:openLevel(1)
app:act("beginLevel")
assert(app.scene == "game", "Already seen lesson not repeated")
app.progress.unlocked = #E.levels
app:openLevel(11)
app:act("beginLevel")
assert(app.scene == "tutorial" and app.tutorial.steps[1].key == "V")
app:act("tutorialSkip")
assert(saved[1].tutorials.V, "Belt lesson seen")
app:act("help")
app:act("replayTutorial")
assert(app.scene == "tutorial")
app:act("tutorialNext")
assert(app.scene == "game", "Ponder replay returns to game")
local fresh = A.new({ dev = true })
fresh:act("devLevels")
assert(fresh.scene == "levels" and fresh.devSession and fresh.slot == nil)
fresh:act("level", #E.levels)
assert(fresh.scene == "briefing" and fresh.game.number == #E.levels)
fresh:act("beginLevel")
fresh:act("tutorialSkip")
assert(fresh.scene == "game", "Developer may skip directly to last stage")
assert(not fresh:save(), "Developer session never changes campaign slots")
fresh:act("pause")
fresh:act("levels")
fresh:act("level", 2)
assert(fresh.game.number == 2, "Developer can jump between any stages")
local free = A.new()
free:act("sandbox")
assert(free.scene == "game" and free.game.sandbox and free.slot == nil)
free:act("tool", "G")
assert(free.settings.animations, "Animation enabled by default")
free:act("toggleAnimations")
assert(not free.settings.animations, "Workshop can disable animation immediately")
free:act("toggleAnimations")
assert(free.settings.animations, "Workshop can resume animation without visiting settings")
free:act("cell", 2, 3)
assert(E.get(free.game, 2, 3).kind == "G")
free:act("pause")
assert(free.scene == "pause")
free:act("clearSandbox")
assert(free.scene == "game" and not E.get(free.game, 2, 3), "Sandbox cleared")
free:act("pause")
free:act("title")
assert(free.scene == "title" and not free:save(), "Sandbox never saved into campaign")
print("COGWORKS: updated tutorials, ephemeral dev navigation and sandbox UI passed.")
