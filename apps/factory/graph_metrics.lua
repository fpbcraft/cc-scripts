-- Pure metric discovery; do not show empty Power Grid charts.
local M = {}
local POWER = { voltage = true, current = true, power = true, battery = true, energy = true }
function M.available(base, snapshot, machines, readings, colors)
  local all = {}
  local live = {}
  for _, p in ipairs((snapshot and snapshot.power) or {}) do
    if
      type(p.key) == "string"
      and type(p.value) == "number"
      and p.value == p.value
      and p.value < math.huge
      and p.value > -math.huge
    then
      live[p.key] = true
    end
  end
  for _, metric in ipairs(base or {}) do
    if not POWER[metric[1]] or live[metric[1]] then
      all[#all + 1] = metric
    end
  end
  for _, m in ipairs(machines or {}) do
    if m.product and m.product ~= "" then
      all[#all + 1] = { "rate_" .. m.id, m.name .. " / NET RATE", "items/min", colors.pink }
    end
  end
  for _, r in ipairs(readings or {}) do
    all[#all + 1] = { r.id, r.label, r.unit, colors.magenta }
  end
  return all
end
return M
