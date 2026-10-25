-- Branching eight-stage chapters: a chapter's entrance is never blocked by
-- its optional advanced remix (stage 7) or examination (stage 8).
local names = {
  { "THE APPRENTICE", "Connections and surprising uses of ordinary gears", "APPRENTICE EXAM" },
  { "IMPOSSIBLE ROUTES", "Obstacles, spatial assumptions and alternative paths", "WAREHOUSE RENOVATION" },
  { "UNEXPECTED MOTION", "Gear ratios, direction and network feedback", "CLOCKMAKER'S TEST" },
  { "TRANSMISSION TRICKS", "Chains, belts and shaft/belt crossings", "TRANSMISSION EXAM" },
  { "TANGLED MACHINERY", "Multi-target branches and mechanical conflicts", "DISTRIBUTION EXAM" },
  { "THE CONTROL ROOM", "Selective redstone, reversals and clutch isolation", "CONTROL EXAM" },
  { "THE REPAIR SHOP", "Diagnose and repair fixed mechanical assemblies", "CHIEF MECHANIC" },
  { "THE GRAND FACTORY", "Synthesis, unexpected shortcuts and multiple solutions", "GRAND COMMISSION" },
}
local chapters = {}
for i, spec in ipairs(names) do
  chapters[i] = {
    number = i, name = spec[1], mechanic = spec[2], test = spec[3],
    first = (i - 1) * 8 + 1, last = i * 8,
    requiredPoints = 6, requiredMain = 4,
  }
end
local C = { chapters = chapters }
function C.chapterFor(level)
  return math.ceil(level / 8)
end
local function cleared(progress, level)
  return type(progress.best) == "table" and progress.best[level] ~= nil
end
function C.stats(progress, chapter)
  local info = assert(chapters[chapter], "Unknown chapter")
  local points, main = 0, 0
  for number = info.first, info.last do
    if cleared(progress, number) then
      points = points + 1
      if number < info.last - 1 then
        main = main + 1
      end
      for _, awarded in pairs((progress.awards or {})[number] or {}) do
        if awarded then
          points = points + 1
        end
      end
    end
  end
  return { points = points, main = main }
end
function C.objectives(progress, last)
  local points = 0
  for level = 1, (last or 64) do
    if cleared(progress, level) then
      points = points + 1
      for _, awarded in pairs((progress.awards or {})[level] or {}) do
        if awarded then
          points = points + 1
        end
      end
    end
  end
  return points
end
function C.unlocked(progress, chapter)
  if chapter < 1 or chapter > #chapters then
    return false
  end
  if chapter == 1 then
    return true
  end
  for i = 1, chapter - 1 do
    local stats = C.stats(progress, i)
    if stats.points < chapters[i].requiredPoints or stats.main < chapters[i].requiredMain then
      return false
    end
  end
  return true
end
function C.levelUnlocked(progress, level, dev)
  if dev then return level >= 1 and level <= 64 end
  if level < 1 or level > 64 then return false end
  local chapter = C.chapterFor(level)
  if not C.unlocked(progress, chapter) then return false end
  local first = chapters[chapter].first
  local localIndex = level - first + 1
  if localIndex == 1 then return true end
  local function completed(stage)
    return cleared(progress, first + stage - 1)
  end
  if localIndex == 2 or localIndex == 3 then return completed(1) end
  if localIndex == 4 or localIndex == 5 then return completed(2) or completed(3) end
  if localIndex == 6 then
    local count = 0
    for stage = 2, 5 do if completed(stage) then count = count + 1 end end
    return count >= 2
  end
  if localIndex == 7 then
    local count = 0
    for stage = 1, 6 do if completed(stage) then count = count + 1 end end
    return completed(4) and count >= 2
  end
  local count = 0
  for stage = 1, 6 do if completed(stage) then count = count + 1 end end
  return count >= 4
end
-- Kept as a migration/API convenience for older saved slots; the level menu
-- uses levelUnlocked for each node instead of this range.
function C.openLevels(progress, dev)
  if dev then return 64 end
  local last = 8
  for chapter = 2, 8 do
    if C.unlocked(progress, chapter) then
      last = chapter * 8
    else
      break
    end
  end
  return last
end
return C
