-- Cogworks campaign graph. Each district is an explorable network, not a ladder.
-- Clear any three levels to open the next district. Bonuses never gate the story.
local titles = {
  { "THE APPRENTICE", "Connections and surprising uses of ordinary gears" },
  { "IMPOSSIBLE ROUTES", "Obstacles, spatial assumptions and alternative paths" },
  { "UNEXPECTED MOTION", "Gear ratios, direction and network feedback" },
  { "TRANSMISSION TRICKS", "Chains, belts and shaft/belt crossings" },
  { "TANGLED MACHINERY", "Multi-target branches and mechanical conflicts" },
  { "THE CONTROL ROOM", "Selective redstone, reversals and clutch isolation" },
  { "THE REPAIR SHOP", "Diagnose and repair fixed mechanical assemblies" },
  { "THE GRAND FACTORY", "Synthesis, shortcuts and multiple solutions" },
}
-- Two paths through each district, cross-connected at the middle.
-- Stage 7 is a side route; stage 8 is reachable without completing stage 7.
local paths = {
  { 1, 2 },
  { 1, 3 },
  { 2, 4 },
  { 3, 4 },
  { 3, 5 },
  { 4, 6 },
  { 5, 6 },
  { 4, 7 },
  { 5, 7 },
  { 6, 8 },
  { 7, 8 },
}
local mapNodes = {
  { 12, 57 },
  { 47, 27 },
  { 47, 82 },
  { 86, 27 },
  { 86, 82 },
  { 126, 40 },
  { 126, 79 },
  { 164, 59 },
}
local chapters = {}
for i, info in ipairs(titles) do
  chapters[i] = {
    number = i,
    name = info[1],
    mechanic = info[2],
    first = (i - 1) * 8 + 1,
    last = i * 8,
    requiredMain = 3,
  }
end
local C = { chapters = chapters, paths = paths, mapNodes = mapNodes }
function C.chapterFor(level)
  return math.ceil(level / 8)
end
local function cleared(progress, number)
  return type(progress.best) == "table" and progress.best[number] ~= nil
end
function C.stats(progress, chapter)
  local info = assert(chapters[chapter], "Unknown district")
  local points, main, bonuses = 0, 0, 0
  for number = info.first, info.last do
    if cleared(progress, number) then
      main = main + 1
      points = points + 1
      for _, yes in pairs((progress.awards or {})[number] or {}) do
        if yes then
          points, bonuses = points + 1, bonuses + 1
        end
      end
    end
  end
  return { points = points, main = main, bonuses = bonuses }
end
function C.objectives(progress, last)
  local total = 0
  for number = 1, (last or 64) do
    if cleared(progress, number) then
      total = total + 1
      for _, yes in pairs((progress.awards or {})[number] or {}) do
        if yes then
          total = total + 1
        end
      end
    end
  end
  return total
end
function C.unlocked(progress, chapter)
  if chapter < 1 or chapter > #chapters then
    return false
  end
  for i = 1, chapter - 1 do
    if C.stats(progress, i).main < chapters[i].requiredMain then
      return false
    end
  end
  return true
end
function C.levelUnlocked(progress, level, dev)
  if level < 1 or level > 64 then
    return false
  end
  if dev then
    return true
  end
  local chapter = C.chapterFor(level)
  if not C.unlocked(progress, chapter) then
    return false
  end
  if cleared(progress, level) then
    return true
  end
  local first = chapters[chapter].first
  local step = level - first + 1
  if step == 1 then
    return true
  end
  for _, edge in ipairs(paths) do
    if
      (edge[1] == step and cleared(progress, first + edge[2] - 1))
      or (edge[2] == step and cleared(progress, first + edge[1] - 1))
    then
      return true
    end
  end
  return false
end
-- Legacy save field: last stage number in the highest open district.
function C.openLevels(progress, dev)
  if dev then
    return 64
  end
  local last = 8
  for chapter = 2, #chapters do
    if C.unlocked(progress, chapter) then
      last = chapter * 8
    else
      break
    end
  end
  return last
end
return C
