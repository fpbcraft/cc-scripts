package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local C = require("games.cogworks.chapters")
local W = require("games.cogworks.witnesses")
assert(#E.levels == 64 and #C.chapters == 8)
local ids, insights, layouts, bonusTypes = {}, {}, {}, {}
local counts, totalBonus = { [0] = 0, [1] = 0, [2] = 0 }, 0
local function signature(g)
  local out = {}
  for _, tile in ipairs(g.tiles) do
    out[#out + 1] = tile.kind .. ":" .. tile.x .. "," .. tile.y .. ":" .. (tile.r % 2)
  end
  table.sort(out)
  return table.concat(out, ";")
end
for number, stage in ipairs(E.levels) do
  assert(stage.id and not ids[stage.id], "Stable, unique level ID")
  ids[stage.id] = true
  assert(
    stage.design and #stage.design.insight > 25 and not insights[stage.design.insight],
    "Distinct authored insight"
  )
  insights[stage.design.insight] = true
  assert(#stage.design.failedApproach > 20 and #stage.design.fixturePurpose > 10)
  assert(stage.chapter == math.ceil(number / 8) and stage.stage == (number - 1) % 8 + 1 and stage.role)
  assert(not E.evaluate(E.new(number)).win, "Playable initial state must not start solved")
  local game, result = W.play(number)
  assert(result.win and result.remaining > 0, "Certified clear with useful inventory alternatives: " .. number)
  local key = signature(game) .. " INITIAL " .. signature(E.new(number))
  assert(not layouts[key], "Distinct authored layout")
  layouts[key] = true
  for _, tile in ipairs(game.tiles) do
    if not tile.fixed and tile.kind ~= "B" and tile.kind ~= "R" then
      assert(result.lights[tile.id].powered, "No idle player machinery in reference: " .. number)
    end
  end
  local n = #stage.bonuses
  assert(n >= 0 and n <= 2)
  counts[n], totalBonus = counts[n] + 1, totalBonus + n
  for _, bonus in ipairs(E.challenges(game, result)) do
    assert(not bonus.earned, "A normal reference must not automatically collect " .. number .. "/" .. bonus.id)
  end
  local _, failed = W.play(number, "misconception")
  assert(not failed.win, "The documented plausible failure must actually fail: " .. number)
  if number > 2 then
    local alternate, outcome = W.play(number, "alternate")
    assert(outcome.win, "Certified alternate clear: " .. number)
    local differences = 0
    for y = 1, stage.height do
      for x = 1, stage.width do
        local a, b = E.get(game, x, y), E.get(alternate, x, y)
        if (a and a.kind .. (a.r % 2) or "-") ~= (b and b.kind .. (b.r % 2) or "-") then
          differences = differences + 1
        end
      end
    end
    assert(differences >= 2, "Alternate requires more than an incidental part swap: " .. number)
  end
  for index, spec in ipairs(stage.bonuses) do
    assert(spec.id == "extra" .. index and spec.witness and spec.description)
    assert(spec.type ~= "moves" and spec.type ~= "clean" and spec.type ~= "full_stock")
    bonusTypes[spec.type] = true
    local solved, evaluation = W.play(number, spec.id)
    assert(evaluation.win)
    assert(E.challenges(solved, evaluation)[index].earned, "Independent bonus witness: " .. number .. "/" .. spec.id)
    local restored = E.new(number)
    assert(E.restore(restored, E.snapshot(solved)), "Bonus solution can be saved and restored")
    local restoredResult = E.evaluate(restored)
    assert(restoredResult.win and E.challenges(restored, restoredResult)[index].earned)
  end
  for _, fixture in ipairs(stage.fixtures) do
    local initial = E.new(number)
    assert(not E.remove(initial, fixture.x, fixture.y) and not E.rotate(initial, fixture.x, fixture.y))
  end
end
assert(counts[0] > 0 and counts[1] > 0 and counts[2] > 0, "Authored variable objective counts")
assert(totalBonus == 66, "Every shipped bonus has its own certified witness")
local ruleCount = 0
for _ in pairs(bonusTypes) do
  ruleCount = ruleCount + 1
end
assert(ruleCount >= 6, "Different construction challenges, without automatic rewards")
local progress = { best = {}, awards = {} }
assert(C.levelUnlocked(progress, 1))
assert(not C.levelUnlocked(progress, 2) and not C.levelUnlocked(progress, 9))
progress.best[1] = 1
assert(C.levelUnlocked(progress, 2) and C.levelUnlocked(progress, 3))
assert(not C.levelUnlocked(progress, 4))
progress.best[3] = 1 -- skip level 2 entirely
assert(C.levelUnlocked(progress, 4) and C.levelUnlocked(progress, 5))
assert(not C.levelUnlocked(progress, 6))
progress.best[5] = 1 -- three clears: the next district is open
assert(C.unlocked(progress, 2) and C.levelUnlocked(progress, 9))
assert(C.levelUnlocked(progress, 6) and C.levelUnlocked(progress, 7))
assert(not C.levelUnlocked(progress, 8))
progress.best[7] = 1 -- expert route opens the finale, without clearing 6
assert(C.levelUnlocked(progress, 8))
assert(not C.unlocked(progress, 3))
assert(C.stats(progress, 1).main == 4 and C.stats(progress, 1).bonuses == 0)
assert(C.objectives(progress, 8) == 4)
assert(C.levelUnlocked(progress, 64, true))
-- No individual node in a district is mandatory to open the next district:
-- a valid 1 -> 3 -> 5 route suffices, repeated in every district.
local alternate = { best = {}, awards = {} }
for chapter = 1, 8 do
  local first = (chapter - 1) * 8 + 1
  assert(C.levelUnlocked(alternate, first))
  alternate.best[first] = 1
  assert(C.levelUnlocked(alternate, first + 2))
  alternate.best[first + 2] = 1
  assert(C.levelUnlocked(alternate, first + 4))
  alternate.best[first + 4] = 1
  assert(C.unlocked(alternate, chapter))
end
assert(C.openLevels(alternate) == 64)
print(
  "COGWORKS: 64 main clears, 62 alternate builds, 64 failed approaches, 66 independently certified bonuses and branching routes passed."
)
