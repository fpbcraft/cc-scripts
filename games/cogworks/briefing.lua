-- Read-only mission briefs, derived from the same level data used by the
-- kinetic simulator. This prevents the intro screen inventing objectives.
local E = require("games.cogworks.engine")
local B = {}
function B.forLevel(number)
  local stage = assert(E.levels[number], "Invalid campaign level")
  local targets = {}
  for i, machine in ipairs(stage.goals) do
    targets[i] =
      { number = i, x = machine.x, y = machine.y, spin = machine.sign < 0 and "CCW" or "CW", rpm = machine.speed }
  end
  local stock = {}
  local total = 0
  for _, kind in ipairs(E.order) do
    local count = stage.stock[kind] or 0
    if count > 0 then
      stock[#stock + 1] = { kind = kind, name = E.parts[kind].name, count = count }
      total = total + count
    end
  end
  return {
    number = number,
    name = stage.name,
    tip = stage.tip,
    targets = targets,
    stock = stock,
    stockTotal = total,
    bonus = stage.bonuses,
    role = stage.role,
    chapter = stage.chapter,
  }
end
return B
