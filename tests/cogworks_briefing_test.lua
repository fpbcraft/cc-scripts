package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local B = require("games.cogworks.briefing")
local goals = 0
for number, stage in ipairs(E.levels) do
  local brief = B.forLevel(number)
  assert(brief.number == number and brief.name == stage.name, "Brief name and number")
  assert(brief.tip == stage.tip, "Brief description")
  assert(#brief.targets == #stage.goals and #brief.targets > 0, "Every press visible in briefing")
  for i, goal in ipairs(brief.targets) do
    local part = stage.goals[i]
    assert(
      goal.x == part.x
        and goal.y == part.y
        and goal.rpm == part.speed
        and goal.spin == (part.sign < 0 and "CCW" or "CW"),
      "Mission brief matches actual press"
    )
    goals = goals + 1
  end
  local total = 0
  for _, count in pairs(stage.stock) do
    total = total + count
  end
  assert(brief.stockTotal == total, "Briefing inventory matches level")
  assert(#brief.bonus == #stage.bonuses, "Brief shows precisely the authored optional objectives")
  for slot, entry in ipairs(brief.bonus) do
    assert(entry.id == "extra" .. slot and entry.name and entry.type, "Stable named objective " .. slot)
  end
  local stockKinds = 0
  for _, kind in ipairs(E.order) do
    if (stage.stock[kind] or 0) > 0 then
      stockKinds = stockKinds + 1
    end
  end
  assert(stockKinds == #brief.stock, "Only real parts included in brief")
end
assert(goals >= #E.levels and #E.levels == 64, "All eight campaign chapters have eight briefs each")
print("COGWORKS: " .. #E.levels .. " revised mission briefs and " .. goals .. " targets passed.")
