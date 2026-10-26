package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local W = require("games.cogworks.witnesses")

-- A normal solve must not quietly bank a bonus during an intermediate
-- rotation or before its final part is placed.
for number, stage in ipairs(E.levels) do
  local game = E.new(number)
  local function check()
    local result = E.evaluate(game)
    if result.win then
      for _, bonus in ipairs(E.challenges(game, result)) do
        assert(not bonus.earned, "Automatic reward during normal construction: " .. number .. "/" .. bonus.id)
      end
    end
  end
  for _, cell in ipairs(stage.removeRedstone) do
    assert(E.remove(game, cell[1], cell[2]))
    check()
  end
  for _, piece in ipairs(stage.build) do
    assert(E.place(game, piece.x, piece.y, piece.kind, 0))
    check()
    for _ = 1, piece.r do
      assert(E.rotate(game, piece.x, piece.y))
      check()
    end
  end
end

local original = E.levels[1]
local function part(kind, x, y, r, speed, sign)
  return { kind = kind, x = x, y = y, r = r or 0, speed = speed, sign = sign }
end
local function trial(kind, useful)
  local driver = kind == "diagonal" and "O" or kind == "chain_link" and "D" or "V"
  local follower = kind == "diagonal" and "G" or driver
  local x, y = kind == "diagonal" and 3 or 2, kind == "belt_span" and 5 or 4
  local goal = useful and part("M", x + 2, y, 3, kind == "diagonal" and 2 or 1, kind == "diagonal" and -1 or 1)
    or part("M", 4, 3, 3, 1, 1)
  E.levels[1] = {
    name = "BONUS SEMANTICS",
    tip = "",
    width = 7,
    height = 7,
    source = part("S", 1, 3, 1),
    goals = { goal },
    fixtures = {},
    blocks = {},
    redstone = {},
    stock = { I = 6, G = 3, O = 3, D = 3, V = 3 },
    build = { part(driver, 2, 3, 1), part(follower, x, y, 1), part("I", useful and x + 1 or 3, useful and y or 3, 1) },
    bonuses = {
      { id = "link", name = "USEFUL LINK", type = kind },
      { id = "mount", name = "USEFUL MOUNT", type = "required_cell", x = x, y = y, value = 1 },
    },
  }
  local game = E.new(1, true)
  local evaluation = E.evaluate(game)
  assert(evaluation.win and evaluation.lights[E.get(game, x, y).id].powered)
  local moves, tileCount, stock = game.moves, #game.tiles, game.remaining.I
  local outcomes = E.challenges(game, evaluation)
  assert(outcomes[1].earned == useful, "A powered decorative link cannot earn " .. kind)
  assert(outcomes[2].earned == useful, "A powered dead-end mount cannot earn a useful-path reward")
  assert(game.moves == moves and #game.tiles == tileCount and game.remaining.I == stock)
  assert(
    E.get(game, x, y).kind == follower and E.evaluate(game).win,
    "Counterfactual analysis leaves the live board intact"
  )
  assert(E.challenges(game, evaluation) == outcomes, "Animation frames reuse objective analysis")
end
for _, kind in ipairs({ "belt_span", "chain_link", "diagonal" }) do
  trial(kind, false)
  trial(kind, true)
end
E.levels[1] = original

-- Different bonuses can be earned on separate constructions. Neither blocks
-- the clear; replays never count as additional district clears.
local storage = { data = nil }
function storage.newProgress()
  return { level = 1, best = {}, sessions = {}, awards = {}, tutorials = {} }
end
function storage.loadSettings()
  return { animations = false, showPorts = true }
end
function storage.save(_, progress)
  storage.data = progress
  return true
end
package.loaded["games.cogworks.storage"] = storage
local App = require("games.cogworks.app")
local C = require("games.cogworks.chapters")
local app = App.new()
app.slot, app.progress = 1, storage.newProgress()
app.progress.unlocked = 8
app.game = W.play(4)
app:updateGame()
assert(app.progress.best[4] and next(app.progress.awards[4]) == nil, "Ordinary clear progresses without a bonus")
app.game = W.play(4, "extra1")
app:updateGame()
assert(app.progress.awards[4].extra1)
app.game = W.play(4, "extra2")
app:updateGame()
assert(app.progress.awards[4].extra1 and app.progress.awards[4].extra2)
assert(C.stats(app.progress, 1).main == 1, "Replays do not grind district access")
app.scene = "game"
local moves = app.game.moves
app:act("inspectBonus", "extra1")
assert(app.message == E.levels[4].bonuses[1].description and app.game.moves == moves)
print(
  "COGWORKS: nonautomatic normal clears, functional transmission checks, independent awards and objective inspection passed."
)
