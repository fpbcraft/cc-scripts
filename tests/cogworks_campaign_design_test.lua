package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local C = require("games.cogworks.chapters")
assert(#E.levels == 64 and #C.chapters == 8)
local names, distinct, bonusTypes, counts = {}, {}, {}, {[0] = 0, [1] = 0, [2] = 0}
local fixedStages, targetCount, totalBonus = 0, 0, 0
for i, stage in ipairs(E.levels) do
  assert(not names[stage.name], "Duplicate title: " .. stage.name)
  names[stage.name] = true
  assert(stage.role and stage.chapter == math.ceil(i / 8) and stage.stage == (i - 1) % 8 + 1)
  local n = #stage.bonuses
  assert(n >= 0 and n <= 2, "Optional objective count out of range: " .. i)
  counts[n] = counts[n] + 1
  totalBonus = totalBonus + n
  for index, bonus in ipairs(stage.bonuses) do
    assert(bonus.id == "extra" .. index and bonus.name and bonus.type)
    bonusTypes[bonus.type] = true
  end
  local current = E.new(i)
  assert(not E.evaluate(current).win, "Starts solved: " .. i)
  local reference = E.new(i, true)
  local evaluation = E.evaluate(reference)
  assert(evaluation.win, "Reference unsolved: " .. i
    .. " (" .. evaluation.correct .. "/" .. evaluation.goals .. ") jam=" .. tostring(evaluation.jam))
  assert(evaluation.unpowered == 0, "Idle reference machinery: " .. i)
  assert(#E.challenges(reference, evaluation) == n, "Bonus evaluator honors variable counts")
  -- A main reference is *not* required to collect optional bonuses.
  local signature = {}
  for _, tile in ipairs(reference.tiles) do
    signature[#signature + 1] = tile.kind .. ":" .. tile.x .. "," .. tile.y .. ":" .. tile.r
  end
  table.sort(signature)
  distinct[table.concat(signature, ";")] = true
  targetCount = targetCount + #stage.goals
  if #stage.fixtures > 0 then
    fixedStages = fixedStages + 1
    for _, fixture in ipairs(stage.fixtures) do
      local tile = E.get(current, fixture.x, fixture.y)
      assert(tile and tile.fixed)
      assert(not E.rotate(current, fixture.x, fixture.y))
      assert(not E.remove(current, fixture.x, fixture.y))
    end
  end
end
local function size(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end
assert(counts[0] > 0 and counts[1] > 0 and counts[2] > 0,
  "Some levels have no bonus, some one, some two")
assert(size(bonusTypes) >= 12, "Bonus catalogue diversity")
assert(size(distinct) >= 55 and fixedStages >= 32, "Board / fixture diversity")
assert(totalBonus < 128 and totalBonus > 64, "Optional bonuses do not dominate the main campaign")
local progress = {best = {}, awards = {}}
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
local alternate = {best = {}, awards = {}}
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
print("COGWORKS: 64 solver-checked references, spatial map skips, "
  .. counts[0] .. "/" .. counts[1] .. "/" .. counts[2]
  .. " stages with 0/1/2 bonuses, " .. size(bonusTypes) .. " bonus rules verified.")
