-- Research-only ranked-candidate adapter for a generated compact policy.
-- It preserves AI.choose/AI.research and only reorders their ranked candidates.
local cache = rawget(_G, "__civcraftModuleCache")
assert(cache, "CivCraft module cache is required")
local Production = cache["/games/civcraft/ai_production.lua"]
local Research = cache["/games/civcraft/ai_research.lua"]
local Systems = cache["/games/civcraft/systems.lua"]
local Hex = cache["/games/civcraft/hex.lua"]
local Policy = assert(COMPACT_POLICY, "COMPACT_POLICY must be installed")
local targetPlayer = COMPACT_PLAYER_ID == nil and 0 or COMPACT_PLAYER_ID
local mode = COMPACT_MODE or "model"

local function features(view, player, legalCount)
  local cities, population, buildings, idle, industry, science = 0, 0, 0, 0, 0, 0
  for _, item in ipairs(view.cities or {}) do
    if item.owner == player.id then
      cities = cities + 1
      population = population + (item.population or 0)
      for _ in pairs(item.buildings or {}) do buildings = buildings + 1 end
      if item.productionIdle or item.idle then idle = idle + 1 end
      local y = Systems.yields(player, item, view, Hex)
      industry = industry + (y.industry or 0)
      science = science + (y.science or 0)
    end
  end
  local units, combat = 0, 0
  for _, unit in ipairs(view.units or {}) do
    if unit.owner == player.id then
      units = units + 1
      combat = combat + (unit.publicAttack or unit.attack or 0)
    end
  end
  local techCount, progress = 0, 0
  for _ in pairs(player.techs or {}) do techCount = techCount + 1 end
  for _, value in pairs(player.researchProgress or {}) do progress = progress + (value or 0) end
  local treasury = Systems.treasury(player, view)
  local limit = math.max(1, view.roundLimit or 180)
  return {
    math.min(1, (view.round or 1) / limit), math.min(1, math.max(0, (player.age or 1) / 6)),
    math.min(1, cities / 8), math.min(1, population / 32),
    math.min(1, industry / 40), math.min(1, science / 40),
    math.max(0, math.min(1, (player.gold or 0) / 200)),
    math.max(0, math.min(1, (treasury.net or 0) / 20 + 0.5)),
    math.min(1, techCount / 30), math.min(1, buildings / 24),
    math.min(1, units / 24), math.min(1, combat / 160),
    math.min(1, idle / 8), math.max(0, math.min(1, progress / 100)),
    math.min(1, legalCount / 16),
  }
end

local function choices(kind, records)
  local labels, candidates = {}, {}
  for _, item in ipairs(records or {}) do
    local label = kind .. ":" .. tostring(item.id)
    labels[#labels + 1] = label
    candidates[#candidates + 1] = { label = label, score = item.score or 0,
      turns = item.turns or 0, rank = #candidates }
  end
  return labels, candidates
end

function COMPACT_POLICY.install()
  local originalProductionRanked, originalResearchRanked = Production.ranked, Research.ranked

  local function reorder(view, player, kind, ranked)
    -- Oracle invokes this same wrapper but returns exact source order, allowing
    -- final-state/action-hash comparison to the baseline controller.
    if player.id ~= targetPlayer or mode == "oracle" then return ranked end
    local labels, candidates = choices(kind, ranked)
    if #labels == 0 then return ranked end
    local selected = Policy.predict(features(view, player, #labels), labels, candidates)
    local selectedIndex
    for index, label in ipairs(labels) do
      if label == selected then selectedIndex = index break end
    end
    if not selectedIndex or selectedIndex == 1 then return ranked end
    local ordered = { ranked[selectedIndex] }
    for index, item in ipairs(ranked) do
      if index ~= selectedIndex then ordered[#ordered + 1] = item end
    end
    return ordered
  end

  Production.ranked = function(view, player, city, systems, canExpand)
    local ranked, context = originalProductionRanked(view, player, city, systems, canExpand)
    return reorder(view, player, "production", ranked), context
  end
  Research.ranked = function(view, player, systems)
    local ranked = originalResearchRanked(view, player, systems)
    return reorder(view, player, "research", ranked)
  end
end

return COMPACT_POLICY.install()
