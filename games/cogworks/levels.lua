-- Individually specified kinetic puzzle plans. The first workshop's puzzles
-- are hand-authored circuits; subsequent authored challenge layouts use proven
-- kinetic motifs as reference assemblies, then lock different subsets and
-- constrain alternative paths. A reference *construction* is not the only
-- allowed solution.
local seed = require("games.cogworks.levels_seed")
local chapterNames = require("games.cogworks.chapters").chapters
local L = {}
local function p(kind, x, y, r, speed, sign)
  return { kind = kind, x = x, y = y, r = r or 0, speed = speed, sign = sign }
end
local function level(name, tip, width, height, source, goals, build, fixtures, blocks, bonusKinds)
  local stock = {}
  for _, piece in ipairs(build) do
    stock[piece.kind] = (stock[piece.kind] or 0) + 1
  end
  return {
    name = name,
    tip = tip,
    width = width,
    height = height,
    source = source,
    goals = goals,
    build = build,
    fixtures = fixtures or {},
    blocks = blocks or {},
    redstone = {},
    removeRedstone = {},
    stock = stock,
    bonusKinds = bonusKinds,
  }
end
-- Chapter 1 is deliberately NOT a line that gets one tile longer each time.
local authored = {
  level(
    "FIRST POWER",
    "A SINGLE SHAFT STARTS THE WORKSHOP.",
    5,
    5,
    p("S", 1, 3, 1),
    { p("M", 3, 3, 3, 1, 1) },
    { p("I", 2, 3, 1) },
    {},
    {},
    { "budget", "clean" }
  ),
  level(
    "AROUND THE CORNER",
    "SHAFTS DO NOT BEND. WHAT PART CHANGES DIRECTION?",
    5,
    5,
    p("S", 1, 2, 1),
    { p("M", 2, 4, 0, 1, -1) },
    { p("Q", 2, 2, 0), p("I", 2, 3, 0) },
    {},
    { { 3, 3 } },
    { "no_gear_extra", "clean" }
  ),
  level(
    "NOT THAT SIDE",
    "A COG'S TEETH CAN CONNECT WHERE ITS SHAFT CANNOT.",
    5,
    5,
    p("S", 1, 2, 1),
    { p("M", 3, 3, 3, 1, -1) },
    { p("G", 2, 2, 1), p("G", 2, 3, 1) },
    {},
    {},
    { "no_gearbox", "dual_rotation" }
  ),
  level(
    "THE MISPLACED COG",
    "THE INSTALLED COG IS THE KEY, NOT AN OBSTACLE.",
    5,
    5,
    p("S", 1, 3, 1),
    { p("M", 4, 4, 3, 1, -1) },
    { p("I", 2, 3, 1), p("G", 3, 4, 1) },
    { p("G", 3, 3, 1) },
    { { 4, 2 } },
    { "fixed_power", "gear_limit" }
  ),
  level(
    "THE OTHER DIRECTION",
    "THE SAME FIXTURE, BUT THE OLD ANSWER HAS THE WRONG SPIN.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 4, 5, 3, 1, 1) },
    { p("I", 2, 3, 1), p("G", 3, 4, 1), p("G", 3, 5, 1) },
    { p("G", 3, 3, 1) },
    { { 2, 5 } },
    { "fixed_power", "dual_rotation" }
  ),
  level(
    "LESS IS MORE",
    "SUPPLY TWO PRESSES WITHOUT UNNECESSARY LINKS.",
    6,
    5,
    p("S", 1, 3, 1),
    { p("M", 4, 3, 3, 1, -1), p("M", 3, 4, 0, 1, -1) },
    { p("I", 2, 3, 1), p("Q", 3, 3, 0) },
    {},
    { { 5, 3 } },
    { "budget", "dual_rotation" }
  ),
  level(
    "THE COG WAS NEVER MISPLACED",
    "OPTIONAL REMIX: DIAGONAL LARGE/SMALL TOOTH CONTACT.",
    5,
    5,
    p("S", 1, 3, 1),
    { p("M", 4, 4, 3, 2, -1) },
    { p("G", 3, 4, 1) },
    { p("O", 2, 3, 1) },
    { { 2, 4 } },
    { "diagonal", "fixed_power" }
  ),
  level(
    "APPRENTICE EXAM",
    "POWER THREE PRESSES USING THE INSTALLED GEARS AND JUNCTION.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 4, 3, 3, 1, -1), p("M", 3, 2, 2, 1, -1), p("M", 3, 5, 0, 1, -1) },
    { p("I", 2, 3, 1) },
    { p("Q", 3, 3, 0), p("G", 3, 4, 0) },
    { { 2, 4 } },
    { "fixed_power", "budget" }
  ),
}
-- Every subsequent entry has explicitly chosen reference topology, fixture
-- subset, board reflection, bonus pair and chapter insight; these are not
-- sequentially stretched shaft layouts. References are checked by tests.
local plans = {
  { "BLOCKED PASSAGE", 2, 1, "1", "budget", "clear_zone", "A WALL MAKES THE OBVIOUS AXIAL ROUTE IMPOSSIBLE." }, -- 09
  { "THE WRONG CORNER", 3, 2, "1", "fixed_power", "clean", "THE FIXED GEARBOX HAS A MORE USEFUL EXIT." }, -- 10
  { "A TIGHT SQUEEZE", 4, 3, "1", "gear_limit", "dual_rotation", "TWO GEAR FACES MUST SHARE A NARROW SPACE." }, -- 11
  { "THE UNMOVABLE GEAR", 13, 0, "2", "fixed_power", "no_gearbox", "WORK WITH THE GEAR ALREADY MOUNTED IN YOUR PATH." }, -- 12
  { "CROSSROADS", 3, 1, "1,3", "clean", "no_chain", "MORE LINKS DO NOT ALWAYS MEAN BETTER POWER." }, -- 13
  { "THE DETOUR", 5, 2, "2", "budget", "no_belt", "THE DIRECT ROUTE COSTS MORE THAN AN INDIRECT BRANCH." }, -- 14
  { "BLOCKED PASSAGE?", 4, 0, "1", "fixed_power", "use_cell", "THE OLD PASSAGE IS SEALED; READ THE INSTALLED COG." }, -- 15
  {
    "WAREHOUSE RENOVATION",
    12,
    3,
    "2,3",
    "fixed_power",
    "budget",
    "RECONNECT TWO INSTALLED SECTIONS WITHOUT MOVING THEM.",
  }, -- 16
  { "TOO FAST", 10, 0, "", "diagonal", "gear_limit", "USE SMALL-TO-LARGE GEARING TO SLOW THE PRESS." }, -- 17
  { "DOUBLE TIME", 9, 1, "", "diagonal", "budget", "REVERSE THE GEARS TO DOUBLE THE SPEED." }, -- 18
  { "THE DIAGONAL TRICK", 9, 2, "1", "diagonal", "fixed_power", "A FIXED LARGE COG DRIVES A DIAGONAL PINION." }, -- 19
  { "TWO CLOCKS", 14, 3, "1", "diagonal", "dual_rotation", "DIVIDE A TRUNK BEFORE THE SPEED CHANGE." }, -- 20
  {
    "SPEED, WRONG DIRECTION",
    13,
    1,
    "1",
    "dual_rotation",
    "no_chain",
    "GET THE RATE RIGHT WITHOUT THE WRONG ROTATION.",
  }, -- 21
  { "THE FEEDBACK TRAP", 15, 3, "1,2", "clean", "gear_limit", "TWO PATHS CANNOT FEED INCOMPATIBLE ROTATION." }, -- 22
  { "MIRROR CLOCKS", 10, 3, "1", "diagonal", "no_gearbox", "REMIX: THE SLOW AND FAST OUTPUTS TRADE PLACES." }, -- 23
  {
    "CLOCKMAKER CERTIFICATION",
    14,
    1,
    "1,3",
    "diagonal",
    "budget",
    "COMBINE RATIO CHANGES WITH CORRECT OUTPUT DIRECTIONS.",
  }, -- 24
  { "LINKED TOGETHER", 6, 1, "", "chain_link", "no_gearbox", "ADJACENT CHAINS SEND POWER SIDEWAYS." }, -- 25
  { "OVER THE GAP", 11, 0, "", "belt_span", "no_chain", "BELTS LEAP ACROSS EMPTY SPACES." }, -- 26
  { "CLOSE COUPLING", 11, 2, "1", "belt_span", "fixed_power", "TWO PARALLEL PULLEYS DO NOT NEED A LONG GAP." }, -- 27
  { "CROSSING THE LINE", 14, 0, "2", "belt_span", "diagonal", "A SHAFT MAY CROSS A BELT LINK, NOT ITS PULLEY." }, -- 28
  { "CHAIN REACTION", 6, 3, "2,3", "chain_link", "fixed_power", "BRANCH FROM A RUN OF ENCASED CHAIN DRIVES." }, -- 29
  { "ABOVE AND BELOW", 14, 2, "1", "belt_span", "budget", "TWO BELT ROUTES COMPETE FOR THE CENTRAL CORRIDOR." }, -- 30
  { "OVER THE GAP?", 11, 3, "1", "belt_span", "clear_zone", "REMIX: THE OLD PULLEY LANDING IS BLOCKED." }, -- 31
  {
    "TRANSMISSION ENGINEER",
    12,
    0,
    "2,4",
    "chain_link",
    "budget",
    "CONNECT SEVERAL TARGETS WITH LONG-RANGE TRANSMISSIONS.",
  }, -- 32
  { "BRANCH OFFICE", 5, 0, "", "budget", "dual_rotation", "ONE SOURCE IS ENOUGH FOR TWO DIFFERENT PRESS LINES." }, -- 33
  { "THREE DIFFERENT DIRECTIONS", 5, 1, "1", "fixed_power", "dual_rotation", "FAN OUT FROM A SINGLE JUNCTION." }, -- 34
  { "SHARED INFRASTRUCTURE", 12, 2, "2", "chain_link", "clean", "A COMMON SHAFT LINE CAN SUPPLY MULTIPLE CONSUMERS." }, -- 35
  { "THE UNWANTED LOOP", 15, 1, "1,2", "no_belt", "budget", "DO NOT CLOSE A CONTRADICTORY LOOP." }, -- 36
  { "MIXED SPEED FACTORY", 14, 3, "2", "diagonal", "dual_rotation", "EACH BRANCH NEEDS A DIFFERENT RATIO." }, -- 37
  { "NO DEAD MACHINERY", 15, 0, "1,3", "fixed_power", "clean", "REUSE PRE-INSTALLED MACHINERY PRODUCTIVELY." }, -- 38
  {
    "ONE MORE CONNECTION?",
    12,
    1,
    "1,4",
    "chain_link",
    "fixed_power",
    "REMIX: A FORMERLY WRONG CONNECTION IS NOW USEFUL.",
  }, -- 39
  {
    "DISTRIBUTION DIRECTOR",
    16,
    2,
    "1,2",
    "fixed_power",
    "single_block",
    "POWER MULTIPLE OUTPUTS WITH A COMMON CONTROLLED SPINE.",
  }, -- 40
  { "THE REVERSE LEVER", 7, 0, "1", "fixed_power", "single_block", "A REDSTONE BLOCK CONTROLS THE GEARSHIFT." }, -- 41
  { "WIRE IT UP", 7, 1, "", "redstone_limit", "single_block", "ROUTE ELECTRICAL POWER PAST MECHANICAL COMPONENTS." }, -- 42
  { "EMERGENCY STOP", 8, 2, "1", "fixed_power", "clean", "A POWERED CLUTCH DISCONNECTS AN UNWANTED BRANCH." }, -- 43
  {
    "TWO DIFFERENT COMMANDS",
    16,
    0,
    "1",
    "fixed_power",
    "redstone_limit",
    "NOT EVERY GEARSHIFT NEEDS THE SAME INPUT.",
  }, -- 44
  { "SIGNAL ROUTING", 7, 3, "1", "redstone_limit", "single_block", "DUST CANNOT OCCUPY A SHAFT CELL." }, -- 45
  { "NORMALLY OFF", 8, 0, "1", "clean", "fixed_power", "REMOVE AN UNWANTED CLUTCH SIGNAL TO ENABLE THE NETWORK." }, -- 46
  {
    "ONE BLOCK TOO MANY",
    16,
    1,
    "1,2",
    "single_block",
    "fixed_power",
    "A SMALL CONTROL CHANGE COMPLETELY CHANGES THE ANSWER.",
  }, -- 47
  {
    "CONTROL ENGINEER",
    16,
    3,
    "1",
    "single_block",
    "redstone_limit",
    "COMBINE REDSTONE REVERSALS WITH KINETIC BRANCHING.",
  }, -- 48
  { "ONE MISSING GEAR", 4, 1, "1,2", "fixed_power", "gear_limit", "THE FIXED MACHINE NEEDS A SINGLE FINAL COUPLING." }, -- 49
  {
    "REVERSED INSTALLATION",
    13,
    2,
    "1",
    "fixed_power",
    "dual_rotation",
    "A PREINSTALLED GEAR TRAIN SENDS POWER THE WRONG WAY.",
  }, -- 50
  { "MECHANICAL JAM", 15, 1, "1,3", "clean", "gear_limit", "REPAIR A MECHANICAL NETWORK WITHOUT MOVING ITS CORE." }, -- 51
  { "FAULTY CONTROLS", 16, 2, "1", "redstone_limit", "fixed_power", "THE SHAFTS WORK, BUT THE SIGNALS ARE WRONG." }, -- 52
  { "A BAD REPAIR", 12, 3, "1,2", "chain_link", "fixed_power", "NOT EVERY EXISTING CONNECTION IS HELPFUL." }, -- 53
  { "SALVAGE OPERATION", 14, 0, "1,3", "belt_span", "fixed_power", "COMBINE TWO SEPARATE INSTALLED TRANSMISSIONS." }, -- 54
  { "FACTORY BLACKOUT?", 15, 3, "2,4", "fixed_power", "clean", "REMIX: A FORMERLY USEFUL BRIDGE NOW CAUSES A JAM." }, -- 55
  {
    "CHIEF MECHANIC",
    16,
    1,
    "1,2",
    "single_block",
    "fixed_power",
    "RESTORE MOTION, SPEED AND DIRECTION IN ONE FACTORY.",
  }, -- 56
  { "FOUNDRY RESTART", 12, 1, "2,4", "chain_link", "fixed_power", "THREE SUBASSEMBLIES NEED A SHARED POWER PLAN." }, -- 57
  { "THE CLOCK TOWER", 14, 2, "1,3", "diagonal", "gear_limit", "A COMPACT SET OF COGS PROVIDES VERY DIFFERENT RATES." }, -- 58
  { "CRANE BAY", 11, 0, "1", "belt_span", "fixed_power", "TWO TRANSMISSIONS MUST SHARE A CROSSING." }, -- 59
  { "THE PISTON CHOIR", 5, 3, "1", "dual_rotation", "budget", "FOUR CLOSELY GROUPED MACHINES NEED OPPOSITE MOTIONS." }, -- 60
  {
    "MINIMUM MATERIALS",
    15,
    2,
    "1,2,3",
    "fixed_power",
    "gear_limit",
    "THE CORRECT PATH USES SURPRISINGLY FEW NEW PARTS.",
  }, -- 61
  {
    "THE OVERRIDE CIRCUIT",
    16,
    0,
    "1",
    "single_block",
    "redstone_limit",
    "POWER THE RIGHT CONTROLS BUT NOT THE WRONG ONES.",
  }, -- 62
  {
    "THE INCOMPLETE BLUEPRINT",
    12,
    2,
    "1,4",
    "fixed_power",
    "clean",
    "REMIX: THE FAMILIAR SHARED BRANCH IS NOW MISLEADING.",
  }, -- 63
  {
    "THE GRAND COMMISSION",
    16,
    3,
    "1,2",
    "fixed_power",
    "single_block",
    "COMPLETE A COMPACT FACTORY USING EVERY KIND OF TRANSMISSION.",
  }, -- 64
}
local function clone(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, child in pairs(value) do
    result[key] = clone(child)
  end
  return result
end
local function parseFixtureIndices(stringValue)
  local included = {}
  for number in string.gmatch(stringValue or "", "%d+") do
    included[tonumber(number)] = true
  end
  return included
end
local function makePlan(i, spec)
  local source = seed[spec[2]]
  local variant = spec[3]
  local mirrorX, mirrorY = variant % 2 == 1, variant >= 2
  local chapter = math.ceil(i / 8)
  local step = (i - 1) % 8 + 1
  local breadth = math.min(10, math.max(source.width, 5 + chapter - 1 + (step >= 6 and 1 or 0)))
  local depth = math.min(10, math.max(source.height, 5 + chapter - 1 + (step >= 4 and 1 or 0)))
  local offX = math.floor((breadth - source.width) / 2)
  local offY = math.floor((depth - source.height) / 2)
  local function coords(x, y)
    return (mirrorX and source.width + 1 - x or x) + offX, (mirrorY and source.height + 1 - y or y) + offY
  end
  local function relocate(piece)
    local item = clone(piece)
    item.x, item.y = coords(piece.x, piece.y)
    if mirrorX then
      item.r = ({ [0] = 0, [1] = 3, [2] = 2, [3] = 1 })[item.r or 0]
    end
    if mirrorY then
      item.r = ({ [0] = 2, [1] = 1, [2] = 0, [3] = 3 })[item.r or 0]
    end
    return item
  end
  local function relocateList(items)
    local mapped = {}
    for _, item in ipairs(items or {}) do
      mapped[#mapped + 1] = relocate(item)
    end
    return mapped
  end
  local result = {
    name = spec[1],
    tip = spec[7],
    width = breadth,
    height = depth,
    source = relocate(source.source),
    goals = relocateList(source.goals),
    build = {},
    fixtures = relocateList(source.fixtures),
    blocks = {},
    redstone = relocateList(source.redstone),
    removeRedstone = {},
    stock = clone(source.stock),
    bonusKinds = { spec[5], spec[6] },
  }
  local chosen = parseFixtureIndices(spec[4])
  local fixedCount = 0
  for index in pairs(chosen) do
    fixedCount = fixedCount + 1
  end
  -- Never hand the player a machine that is already fully constructed.
  if fixedCount >= #source.build then
    chosen[1] = nil
  end
  for index, piece in ipairs(source.build) do
    local item = relocate(piece)
    if chosen[index] then
      result.fixtures[#result.fixtures + 1] = item
      result.stock[item.kind] = (result.stock[item.kind] or 0) - 1
    else
      result.build[#result.build + 1] = item
    end
  end
  for _, position in ipairs(source.blocks or {}) do
    local x, y = coords(position[1], position[2])
    result.blocks[#result.blocks + 1] = { x, y }
  end
  for _, position in ipairs(source.removeRedstone or {}) do
    local x, y = coords(position[1], position[2])
    result.removeRedstone[#result.removeRedstone + 1] = { x, y }
  end
  -- Mark a nearby no-build corner in the tougher stages, but never hide a
  -- required reference piece under a wall. Fixed parts are never moved.
  if step >= 4 then
    local used = {}
    for _, item in ipairs({ result.source }) do
      used[item.y * 16 + item.x] = true
    end
    for _, list in ipairs({ result.goals, result.build, result.fixtures, result.redstone }) do
      for _, item in ipairs(list) do
        used[item.y * 16 + item.x] = true
      end
    end
    for _, wall in ipairs(result.blocks) do
      used[wall[2] * 16 + wall[1]] = true
    end
    local corners = {
      { 1, 1 },
      { breadth, depth },
      { 1, depth },
      { breadth, 1 },
    }
    for wallIndex = 1, (step >= 7 and 2 or 1) do
      local corner = corners[(wallIndex + chapter - 2) % 4 + 1]
      if not used[corner[2] * 16 + corner[1]] then
        result.blocks[#result.blocks + 1] = corner
      end
    end
  end
  return result
end
for i = 9, 64 do
  authored[i] = makePlan(i, plans[i - 8])
end
-- Two named, parameterized bonus challenges belong to each individual
-- stage. Only two can award points, even if the engine knows many predicates.
local names = {
  budget = { "UNDER BUDGET", "USE FEWER PARTS", "budget" },
  moves = { "PAR PERFORMANCE", "MINIMIZE CHANGES", "moves" },
  exact = { "PERFECT FIT", "EXACT PART COUNT", "exact_parts" },
  clean = { "CLEAN MACHINE", "NO IDLE MACHINE PARTS", "clean" },
  full = { "FULL UTILIZATION", "ALL PARTS POWERED", "full_stock" },
  no_gearbox = { "NO GEARBOX", "BUILD WITHOUT NEW GEARBOXES", "no_gearbox" },
  no_gear_extra = { "MINIMAL GEARING", "NO EXTRA COGWHEELS", "gear_limit" },
  gear_limit = { "MINIMAL GEARING", "LIMIT NEW COGWHEELS", "gear_limit" },
  belt_span = { "BELT SPECIALIST", "USE A LIVE BELT TRANSMISSION", "belt_span" },
  chain_link = { "CHAIN REACTION", "USE LIVE CHAIN TRANSMISSION", "chain_link" },
  diagonal = { "DIAGONAL THINKING", "USE POWERED MIXED-SIZE DIAGONAL COGS", "diagonal" },
  dual_rotation = { "DUAL ROTATION", "HAVE BOTH CW AND CCW RUNNING", "dual_rotation" },
  redstone_limit = { "MINIMAL WIRING", "LIMIT NEW REDSTONE DUST", "redstone_limit" },
  single_block = { "SINGLE POWER", "USE AT MOST ONE REDSTONE BLOCK", "single_block" },
  fixed_power = { "RESTORE ORIGINAL", "USE INSTALLED MACHINERY IN POWERED NETWORK", "fixed_power" },
  no_belt = { "NO BELT NEEDED", "FIND A BELT-FREE SOLUTION", "no_belt" },
  no_chain = { "NO CHAIN NEEDED", "FIND A CHAIN-FREE SOLUTION", "no_chain" },
  clear_zone = { "KEEP IT CLEAR", "LEAVE THE MARKED CELL VACANT", "clear_zone" },
  use_cell = { "USE THE MOUNT", "PLACE A POWERED PART ON THE MOUNT", "use_cell" },
}
local function countKind(items, wanted)
  local count = 0
  for _, item in ipairs(items) do
    if item.kind == wanted then
      count = count + 1
    end
  end
  return count
end
local function bonusFor(stage, key, index)
  local definition = assert(names[key], "Unknown bonus " .. tostring(key))
  local spec = { id = "extra" .. index, name = definition[1], description = definition[2], type = definition[3] }
  if key == "budget" or key == "exact" then
    spec.value = #stage.build - countKind(stage.build, "R") - countKind(stage.build, "B")
  elseif key == "moves" then
    spec.value = #stage.build * 4 + 3
  elseif key == "gear_limit" then
    spec.value = countKind(stage.build, "G") + countKind(stage.build, "O")
  elseif key == "no_gear_extra" then
    spec.value = 0
  elseif key == "belt_span" then
    spec.value = 1
  elseif key == "redstone_limit" then
    spec.value = countKind(stage.build, "R")
  elseif key == "fixed_power" then
    spec.value = math.max(1, math.min(1, #stage.fixtures))
  elseif key == "clear_zone" or key == "use_cell" then
    -- Prefer authorable empty corners, never a source/press or obstacle.
    local occupied = {}
    for _, piece in ipairs({ stage.source }) do
      occupied[piece.y * 16 + piece.x] = true
    end
    for _, list in ipairs({ stage.build, stage.fixtures, stage.goals, stage.redstone }) do
      for _, piece in ipairs(list) do
        occupied[piece.y * 16 + piece.x] = true
      end
    end
    for _, obstacle in ipairs(stage.blocks) do
      occupied[obstacle[2] * 16 + obstacle[1]] = true
    end
    if key == "use_cell" then
      for _, piece in ipairs(stage.build) do
        if piece.kind ~= "R" and piece.kind ~= "B" then
          spec.x, spec.y = piece.x, piece.y
          break
        end
      end
    else
      for y = 1, stage.height do
        for x = 1, stage.width do
          if not occupied[y * 16 + x] and not spec.x then
            spec.x1, spec.x2, spec.y1, spec.y2 = x, x, y, y
            spec.x = x
          end
        end
      end
    end
  end
  if key == "fixed_power" and #stage.fixtures == 0 then
    return bonusFor(stage, "budget", index)
  end
  if key == "use_cell" and not spec.x then
    return bonusFor(stage, "budget", index)
  end
  return spec
end
for i, stage in ipairs(authored) do
  stage.chapter = math.ceil(i / 8)
  stage.stage = (i - 1) % 8 + 1
  stage.finale = stage.stage == 8
  stage.role = ({
    "discovery",
    "application",
    "alternative",
    "twist",
    "combination",
    "synthesis",
    "extra",
    "examination",
  })[stage.stage]
  stage.title = stage.chapter .. "-" .. stage.stage .. " " .. stage.name
  local bonuses = stage.bonusKinds or { "budget", "clean" }
  stage.bonuses = { bonusFor(stage, bonuses[1], 1), bonusFor(stage, bonuses[2], 2) }
  stage.bonusKinds = nil
end
return authored
