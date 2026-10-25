package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local C = require("games.cogworks.chapters")
assert(#E.levels == 64 and #C.chapters == 8, "64 authored stages / eight chapters")
local names, distinct, bonusTypes = {}, {}, {}
local fixedStages, targetCount = 0, 0
for i, stage in ipairs(E.levels) do
  assert(not names[stage.name], "Duplicate stage title " .. stage.name)
  names[stage.name] = true
  assert(stage.role and stage.chapter == math.ceil(i / 8) and stage.stage == (i - 1) % 8 + 1)
  assert(#stage.bonuses == 2, "Exactly two authored bonuses at stage " .. i)
  assert(stage.bonuses[1].id ~= stage.bonuses[2].id, "Stable objective slots")
  for _, bonus in ipairs(stage.bonuses) do
    bonusTypes[bonus.type] = true
  end
  local current = E.new(i)
  assert(not E.evaluate(current).win, "Stage must start unsolved: " .. i)
  local reference = E.new(i, true)
  local evaluated = E.evaluate(reference)
  assert(
    evaluated.win,
    "Reference failed at stage "
      .. i
      .. " ("
      .. evaluated.correct
      .. "/"
      .. evaluated.goals
      .. ") jam="
      .. tostring(evaluated.jam)
  )
  assert(evaluated.unpowered == 0, "Idle reference machinery at stage " .. i)
  for _, objective in ipairs(E.challenges(reference, evaluated)) do
    assert(objective.earned, "Authored bonus cannot be reached by published reference: " .. i .. " " .. objective.name)
  end
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
      assert(tile and tile.fixed, "Locked fixture missing")
      assert(not E.rotate(current, fixture.x, fixture.y), "Fixed machinery cannot rotate")
      assert(not E.remove(current, fixture.x, fixture.y), "Fixed machinery cannot be deleted")
    end
  end
end
local totalTypes = 0
for _ in pairs(bonusTypes) do
  totalTypes = totalTypes + 1
end
local totalLayouts = 0
for _ in pairs(distinct) do
  totalLayouts = totalLayouts + 1
end
assert(totalTypes >= 12, "Campaign should feature a broad catalogue of bonuses")
assert(totalLayouts >= 55, "Most campaign puzzles must have different actual board geometry")
assert(fixedStages >= 32, "Fixed machinery appears throughout the campaign")
local progress = { best = {}, awards = {} }
assert(C.levelUnlocked(progress, 1))
assert(not C.levelUnlocked(progress, 2) and not C.levelUnlocked(progress, 9))
progress.best[1] = 1
assert(C.levelUnlocked(progress, 2) and C.levelUnlocked(progress, 3))
assert(not C.levelUnlocked(progress, 4))
progress.best[2] = 2
assert(C.levelUnlocked(progress, 4) and C.levelUnlocked(progress, 5))
assert(not C.levelUnlocked(progress, 6))
progress.best[3] = 2
assert(C.levelUnlocked(progress, 6))
progress.best[4] = 3
assert(C.levelUnlocked(progress, 7) and C.levelUnlocked(progress, 8))
assert(not C.unlocked(progress, 2))
progress.awards[1] = { extra1 = true, extra2 = true }
assert(C.stats(progress, 1).points == 6 and C.stats(progress, 1).main == 4)
assert(C.unlocked(progress, 2) and C.levelUnlocked(progress, 9), "Four main clears + two extras unlock chapter two")
assert(not C.unlocked(progress, 3))
assert(C.objectives(progress, 8) == 6)
assert(C.levelUnlocked(progress, 64, true), "Dev mode can access every stage")
print(
  "COGWORKS: 64 stage solutions, both authored bonuses, chapter paths and fixture locks verified; "
    .. totalLayouts
    .. " distinct board layouts, "
    .. totalTypes
    .. " bonus rules, "
    .. targetCount
    .. " targets."
)
