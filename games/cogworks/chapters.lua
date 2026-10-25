-- Eight campaign chapters. Opening later chapters is based on earned
-- objectives, not on a mandatory linear clear of every preceding stage.
local chapters = {
  { name = "SHAFTWORK", mechanic = "Axial shafts and clean power runs", threshold = 0, test = "LONG RUN" },
  { name = "GEARBOXES", mechanic = "Turning corners and reversing direction", threshold = 12, test = "THREE-WAY TEST" },
  { name = "SMALL COGS", mechanic = "Perpendicular tooth meshing", threshold = 27, test = "MESHING TEST" },
  { name = "GEAR RATIOS", mechanic = "Large/small cogs, gearing up and down", threshold = 44, test = "RATIO TEST" },
  {
    name = "CHAIN DRIVES",
    mechanic = "Parallel chain transmissions and branching",
    threshold = 62,
    test = "CHAIN TEST",
  },
  {
    name = "BELT ROUTES",
    mechanic = "Nearby pulleys, long belts, shaft crossings",
    threshold = 82,
    test = "BELT TEST",
  },
  {
    name = "REDSTONE",
    mechanic = "Dust, blocks, powered gearshifts and clutches",
    threshold = 102,
    test = "CONTROL TEST",
  },
  { name = "MASTER WORKSHOP", mechanic = "Integrating all kinetic systems", threshold = 123, test = "MASTER TEST" },
}
for i, chapter in ipairs(chapters) do
  chapter.number = i
  chapter.first = (i - 1) * 8 + 1
  chapter.last = i * 8
end
local C = { chapters = chapters }
function C.chapterFor(level)
  return math.ceil(level / 8)
end
function C.objectives(progress, last)
  local points = 0
  for level = 1, (last or #chapters * 8) do
    if progress.best and progress.best[level] ~= nil then
      points = points + 1
    end
    for _, earned in pairs(progress.awards and progress.awards[level] or {}) do
      if earned then
        points = points + 1
      end
    end
  end
  return points
end
function C.unlocked(progress, index)
  if index < 1 or index > #chapters then
    return false
  end
  return C.objectives(progress, chapters[index].first - 1) >= chapters[index].threshold
end
function C.openLevels(progress, dev)
  local max = 8
  if dev then
    return 64
  end
  for i = 2, #chapters do
    if C.unlocked(progress, i) then
      max = chapters[i].last
    else
      break
    end
  end
  return max
end
return C
