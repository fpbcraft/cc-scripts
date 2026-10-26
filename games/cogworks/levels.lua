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
    "A FIXED COG BLOCKS THE STRAIGHT ROUTE. THE PRESS IS STILL REACHABLE.",
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

-- Bespoke discovery boards. These are hand-wired networks, NOT transformations
-- of the old seed missions. They replace motifs where the chapter's central
-- insight requires an entirely different topology, multiple targets, a real
-- shaft/belt crossing, or a meaningful redstone control route.
local function override(number, definition)
  authored[number] = definition
end
override(
  20,
  level(
    "TWO CLOCKS",
    "THE TWO PRESSES DEMAND DIFFERENT SPEEDS FROM ONE MOTOR.",
    7,
    7,
    p("S", 1, 3, 1),
    { p("M", 4, 3, 3, 1, -1), p("M", 4, 6, 0, 2, 1) },
    { p("I", 2, 3, 1), p("Q", 3, 3, 0), p("G", 4, 5, 0) },
    { p("O", 3, 4, 0) },
    { { 6, 3 } },
    { "diagonal", "dual_rotation" }
  )
)
override(
  23,
  level(
    "MIRROR CLOCKS",
    "THE SAME SPLIT, BUT THIS TIME THE LOWER PRESS MUST SLOW DOWN.",
    7,
    7,
    p("S", 1, 3, 1),
    { p("M", 4, 3, 3, 1, -1), p("M", 4, 6, 0, 0.5, 1) },
    { p("I", 2, 3, 1), p("Q", 3, 3, 0), p("O", 4, 5, 0) },
    { p("G", 3, 4, 0) },
    { { 5, 5 } },
    { "diagonal", "fixed_power" }
  )
)
override(
  24,
  level(
    "CLOCKMAKER CERTIFICATION",
    "THREE SPEEDS AND DIRECTIONS FROM ONE FIXED CLOCKWORK.",
    8,
    7,
    p("S", 1, 3, 1),
    { p("M", 3, 2, 2, 1, -1), p("M", 4, 3, 3, 1, -1), p("M", 4, 6, 0, 2, 1) },
    { p("I", 2, 3, 1), p("G", 4, 5, 0) },
    { p("Q", 3, 3, 0), p("O", 3, 4, 0) },
    { { 6, 5 } },
    { "diagonal", "fixed_power" }
  )
)
override(
  28,
  level(
    "CROSSING THE LINE",
    "TWO RUNNING TRANSMISSIONS NEED THE SAME NARROW CORRIDOR.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 5, 4, 3, 1, 1), p("M", 5, 5, 3, 1, -1) },
    { p("Q", 2, 4, 0), p("I", 3, 3, 1), p("I", 3, 4, 1), p("I", 4, 4, 1), p("V", 4, 5, 1) },
    { p("Q", 2, 3, 0), p("V", 4, 3, 1) },
    { { 5, 2 } },
    { "belt_cross", "fixed_power" }
  )
)
override(
  42,
  level(
    "WIRE IT UP",
    "REDSTONE DUST BRIDGES A GAP TO THE FIXED SHIFT.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 5, 3, 3, 1, -1) },
    { p("I", 2, 3, 1), p("I", 4, 3, 1), p("R", 3, 4), p("B", 3, 5) },
    { p("Z", 3, 3, 1) },
    { { 4, 4 } },
    { "redstone_limit", "fixed_power" }
  )
)
override(
  44,
  level(
    "TWO DIFFERENT COMMANDS",
    "THE TWO INSTALLED SHIFTS REQUIRE DIFFERENT COMMANDS.",
    7,
    6,
    p("S", 1, 3, 1),
    { p("M", 3, 1, 2, 1, 1), p("M", 3, 5, 0, 1, -1) },
    { p("I", 2, 3, 1), p("B", 2, 2) },
    { p("Q", 3, 3, 0), p("Z", 3, 2, 0), p("Z", 3, 4, 0) },
    { { 4, 4 } },
    { "single_block", "fixed_power" }
  )
)
override(
  45,
  level(
    "SIGNAL ROUTING",
    "THE DIRECT DUST ROUTE WOULD OVERLAP A MACHINE.",
    7,
    7,
    p("S", 1, 3, 1),
    { p("M", 5, 3, 3, 1, -1) },
    { p("I", 2, 3, 1), p("I", 4, 3, 1), p("R", 3, 4), p("R", 3, 5), p("R", 4, 5), p("B", 5, 5) },
    { p("Z", 3, 3, 1) },
    { { 4, 4 }, { 5, 4 } },
    { "redstone_limit", "fixed_power" }
  )
)
override(
  47,
  level(
    "ONE BLOCK TOO MANY",
    "FAMILIAR SHIFTS, BUT THE OPPOSITE ONE MUST REVERSE.",
    7,
    6,
    p("S", 1, 3, 1),
    { p("M", 3, 1, 2, 1, -1), p("M", 3, 5, 0, 1, 1) },
    { p("I", 2, 3, 1), p("B", 2, 4) },
    { p("Q", 3, 3, 0), p("Z", 3, 2, 0), p("Z", 3, 4, 0) },
    { { 4, 4 } },
    { "single_block", "dual_rotation" }
  )
)
override(
  48,
  level(
    "CONTROL ENGINEER",
    "TWO SELECTIVE SHIFTS AND A THIRD DIRECT PRESS.",
    8,
    7,
    p("S", 1, 3, 1),
    { p("M", 3, 1, 2, 1, 1), p("M", 3, 5, 0, 1, -1), p("M", 4, 3, 3, 1, -1) },
    { p("I", 2, 3, 1), p("Z", 3, 4, 0), p("B", 2, 2) },
    { p("Q", 3, 3, 0), p("Z", 3, 2, 0) },
    { { 5, 4 } },
    { "single_block", "fixed_power" }
  )
)
override(
  52,
  level(
    "FAULTY CONTROLS",
    "MOVE REDSTONE TO THE CORRECT SHIFT; DO NOT REPLACE THE SHAFTS.",
    8,
    8,
    p("S", 1, 3, 1),
    { p("M", 3, 1, 2, 1, 1), p("M", 3, 5, 0, 1, -1) },
    { p("I", 2, 3, 1), p("B", 2, 2) },
    { p("Q", 3, 3, 0), p("Z", 3, 2, 0), p("Z", 3, 4, 0) },
    { { 4, 4 } },
    { "single_block", "fixed_power" }
  )
)
authored[52].redstone = { p("B", 2, 4) }
authored[52].removeRedstone = { { 2, 4 } }
override(
  59,
  level(
    "CRANE BAY",
    "A LIVE SHAFT CUTS BETWEEN TWO FUNCTIONING PULLEYS.",
    9,
    9,
    p("S", 1, 4, 1),
    { p("M", 5, 5, 3, 1, 1), p("M", 5, 6, 3, 1, -1) },
    { p("Q", 2, 5, 0), p("I", 3, 4, 1), p("I", 3, 5, 1), p("I", 4, 5, 1), p("V", 4, 6, 1) },
    { p("Q", 2, 4, 0), p("V", 4, 4, 1) },
    { { 6, 5 }, { 3, 7 } },
    { "belt_cross", "fixed_power" }
  )
)
override(
  60,
  level(
    "THE PISTON CHOIR",
    "A SMALL JUNCTION SERVES FOUR PRESSES WITH DIFFERENT SIGNS.",
    7,
    7,
    p("S", 1, 4, 1),
    { p("M", 3, 2, 2, 1, 1), p("M", 4, 3, 3, 1, 1), p("M", 4, 4, 3, 1, -1), p("M", 3, 5, 0, 1, -1) },
    { p("I", 2, 4, 1) },
    { p("Q", 3, 4, 0), p("Q", 3, 3, 0) },
    { { 5, 4 } },
    { "budget", "dual_rotation" }
  )
)
override(
  62,
  level(
    "THE OVERRIDE CIRCUIT",
    "KEEP ONE GEASHIFT DARK WHILE THE OTHER SHIFTS.",
    8,
    8,
    p("S", 1, 3, 1),
    { p("M", 3, 1, 2, 1, 1), p("M", 3, 5, 0, 1, -1), p("M", 4, 3, 3, 1, -1) },
    { p("I", 2, 3, 1), p("B", 1, 1), p("R", 2, 1), p("R", 2, 2) },
    { p("Q", 3, 3, 0), p("Z", 3, 2, 0), p("Z", 3, 4, 0) },
    { { 4, 4 } },
    { "redstone_limit", "fixed_power" }
  )
)
override(
  64,
  level(
    "THE GRAND COMMISSION",
    "COMMISSION THE FACTORY: FOUR PRESSES, FOUR DIFFERENT DEMANDS.",
    10,
    10,
    p("S", 1, 5, 1),
    { p("M", 6, 5, 3, 1, 1), p("M", 4, 4, 0, 1, -1), p("M", 6, 7, 3, 1, -1), p("M", 8, 8, 3, 2, -1) },
    {
      p("I", 2, 5, 1),
      p("Z", 5, 5, 1),
      p("B", 5, 3),
      p("R", 5, 4),
      p("I", 3, 4, 0),
      p("D", 4, 3, 0),
      p("Q", 3, 6, 0),
      p("I", 4, 6, 1),
      p("Q", 3, 7, 0),
      p("I", 4, 7, 1),
      p("I", 5, 7, 1),
      p("V", 5, 9, 1),
      p("G", 7, 8, 1),
    },
    { p("Q", 3, 5, 0), p("C", 4, 5, 1), p("D", 3, 3, 0), p("V", 5, 6, 1), p("O", 6, 9, 1) },
    { { 2, 9 }, { 7, 6 }, { 4, 8 } },
    { "full", "exact" }
  )
)

-- Warehouse puzzles replace the most repetitive reflected references with
-- actual constrained routes, shared fixed parts and multi-press arrangements.
override(
  9,
  level(
    "BLOCKED PASSAGE",
    "THE MAIN PASSAGE IS SEALED. FIND ANOTHER WAY TO RUN THE PRESS.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 5, 4, 3, 1, 1) },
    { p("I", 2, 3, 1), p("Q", 3, 3, 0), p("Q", 3, 4, 0), p("I", 4, 4, 1) },
    {},
    { { 4, 3 }, { 4, 2 } },
    { "budget", "clear_zone" }
  )
)
override(
  10,
  level(
    "THE WRONG CORNER",
    "THE INSTALLED FOUR-WAY BOX HAS A USEFUL UPPER EXIT.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 4, 2, 3, 1, 1) },
    { p("I", 2, 3, 1), p("Q", 3, 2, 0) },
    { p("Q", 3, 3, 0) },
    { { 4, 3 } },
    { "fixed_power", "clean" }
  )
)
override(
  11,
  level(
    "A TIGHT SQUEEZE",
    "USE BOTH THE SHAFT AND THE TEETH OF A SINGLE PINION.",
    5,
    6,
    p("S", 1, 3, 1),
    { p("M", 3, 3, 3, 1, 1), p("M", 4, 4, 3, 1, -1) },
    { p("G", 2, 3, 1), p("I", 3, 4, 1) },
    { p("G", 2, 4, 1) },
    { { 4, 3 } },
    { "gear_limit", "dual_rotation" }
  )
)
override(
  12,
  level(
    "THE UNMOVABLE GEAR",
    "THE FIXED GEAR MUST DO TWO DIFFERENT JOBS.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 4, 3, 3, 1, 1), p("M", 5, 4, 3, 1, -1) },
    { p("I", 2, 3, 1), p("G", 3, 4, 1), p("I", 4, 4, 1) },
    { p("G", 3, 3, 1) },
    { { 5, 3 } },
    { "fixed_power", "no_gearbox" }
  )
)
override(
  14,
  level(
    "THE DETOUR",
    "AN INDIRECT GEAR PATH FITS THE LIMITED STOCK.",
    7,
    7,
    p("S", 1, 3, 1),
    { p("M", 4, 6, 0, 1, 1) },
    { p("I", 2, 3, 1), p("I", 3, 4, 0), p("G", 3, 5, 0), p("G", 4, 5, 0) },
    { p("Q", 3, 3, 0) },
    { { 4, 3 }, { 5, 3 } },
    { "budget", "dual_rotation" }
  )
)
override(
  15,
  level(
    "BLOCKED PASSAGE?",
    "THE WALL HAS MOVED, BUT THE FIXED TOOTHED RIM IS THE OPENING.",
    6,
    6,
    p("S", 1, 3, 1),
    { p("M", 4, 4, 3, 1, -1) },
    { p("I", 2, 3, 1), p("G", 3, 4, 1) },
    { p("G", 3, 3, 1) },
    { { 4, 3 }, { 2, 4 } },
    { "fixed_power", "no_gearbox" }
  )
)
override(
  16,
  level(
    "WAREHOUSE RENOVATION",
    "THREE PRESSES AND TWO INSTALLED BOXES, WITHOUT MOVING ANY FIXTURE.",
    7,
    7,
    p("S", 1, 3, 1),
    { p("M", 3, 2, 2, 1, -1), p("M", 4, 3, 3, 1, -1), p("M", 5, 4, 3, 1, 1) },
    { p("I", 2, 3, 1), p("I", 4, 4, 1) },
    { p("Q", 3, 3, 0), p("Q", 3, 4, 0) },
    { { 6, 4 } },
    { "fixed_power", "budget" }
  )
)
-- The distribution plant is about independent output branches rather than
-- simply adding more length to the generator's shaft.
override(
  33,
  level(
    "BRANCH OFFICE",
    "REUSE A COMMON TRUNK TO POWER TWO DISTANT PRESS LINES.",
    7,
    7,
    p("S", 1, 3, 1),
    { p("M", 5, 3, 3, 1, -1), p("M", 3, 5, 0, 1, -1) },
    { p("I", 2, 3, 1), p("I", 4, 3, 1), p("I", 3, 4, 0) },
    { p("Q", 3, 3, 0) },
    { { 4, 4 } },
    { "fixed_power", "budget" }
  )
)
override(
  34,
  level(
    "THREE DIFFERENT DIRECTIONS",
    "ONE INSTALLED JUNCTION GENERATES MULTIPLE SPINS.",
    7,
    7,
    p("S", 1, 4, 1),
    { p("M", 4, 4, 3, 1, -1), p("M", 4, 2, 2, 1, 1), p("M", 3, 5, 0, 1, -1) },
    { p("I", 2, 4, 1), p("G", 3, 3, 0), p("G", 4, 3, 0) },
    { p("Q", 3, 4, 0) },
    { { 5, 4 } },
    { "dual_rotation", "gear_limit" }
  )
)
override(
  37,
  level(
    "MIXED SPEED FACTORY",
    "MAKE HALF, NORMAL AND DOUBLE SPEED WITHOUT REJOINING THEM.",
    8,
    8,
    p("S", 1, 4, 1),
    { p("M", 4, 1, 2, 0.5, 1), p("M", 4, 4, 3, 1, -1), p("M", 4, 7, 0, 2, 1) },
    { p("I", 2, 4, 1), p("G", 3, 3, 0), p("O", 3, 5, 0), p("G", 4, 6, 0) },
    { p("Q", 3, 4, 0), p("O", 4, 2, 0) },
    { { 5, 4 } },
    { "diagonal", "dual_rotation" }
  )
)
override(
  40,
  level(
    "DISTRIBUTION DIRECTOR",
    "AN EXTREMELY COMPACT FOUR-PRESS DISTRIBUTION NETWORK.",
    9,
    9,
    p("S", 1, 4, 1),
    { p("M", 3, 2, 2, 1, 1), p("M", 4, 3, 3, 1, 1), p("M", 4, 4, 3, 1, -1), p("M", 3, 5, 0, 1, -1) },
    { p("I", 2, 4, 1), p("Q", 3, 3, 0) },
    { p("Q", 3, 4, 0) },
    { { 5, 3 }, { 5, 5 } },
    { "fixed_power", "dual_rotation" }
  )
)
override(
  49,
  level(
    "ONE MISSING GEAR",
    "THIS ASSEMBLY ALMOST WORKS. THE REPAIR IS NOT OBVIOUS.",
    7,
    7,
    p("S", 1, 3, 1),
    { p("M", 3, 3, 3, 1, 1), p("M", 4, 4, 3, 1, -1) },
    { p("G", 2, 4, 1) },
    { p("G", 2, 3, 1), p("I", 3, 4, 1) },
    { { 4, 3 } },
    { "fixed_power", "gear_limit" }
  )
)

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
  belt_cross = { "THE CROSSOVER", "POWER A SHAFT THROUGH A LIVE BELT SPAN", "belt_cross" },
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
  -- A category restriction must be satisfied by at least one certified
  -- reference. When the authored transmission motif fundamentally requires
  -- that part, substitute a comparable feasible constraint.
  if key == "no_gearbox" and countKind(stage.build, "Q") > 0 then
    key = "gear_limit"
  end
  if key == "no_belt" and countKind(stage.build, "V") > 0 then
    key = "gear_limit"
  end
  if key == "no_chain" and countKind(stage.build, "D") > 0 then
    key = "budget"
  end
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
-- Do not distribute a recipe's exact bill of materials to the player.
-- These pilot puzzles deliberately include plausible competing transmissions.
-- Stock lists are authored independently from the tested reference assembly.
local exploratoryStock = {
  [4] = { Q = 2, I = 1, G = 1 },
  [9] = { G = 2, I = 1, Q = 1 },
  [20] = { G = 2, O = 1, Q = 1, I = 2 },
  [28] = { V = 1, Q = 1, I = 2, D = 2 },
  [44] = { B = 1, R = 3, G = 1 },
  [49] = { G = 2, Q = 2, I = 1, D = 1 },
  [64] = { I = 2, G = 1, O = 1, Q = 1, V = 1, R = 2 },
}
for number, spare in pairs(exploratoryStock) do
  for kind, amount in pairs(spare) do
    authored[number].stock[kind] = (authored[number].stock[kind] or 0) + amount
  end
end

-- Explicit objective counts: discoveries can be reward-free; ordinary
-- experiments may have one optional challenge, and complex stages up to two.
-- Stage 64 is deliberately a substantial open-ended main objective, not a
-- mandatory full-inventory/exact-count checklist.
local noBonuses = {
  [1] = true,
  [2] = true,
  [9] = true,
  [17] = true,
  [25] = true,
  [33] = true,
  [41] = true,
  [64] = true,
}
local singleBonus = {
  [3] = true,
  [4] = true,
  [5] = true,
  [10] = true,
  [12] = true,
  [18] = true,
  [20] = true,
  [26] = true,
  [28] = true,
  [34] = true,
  [35] = true,
  [42] = true,
  [44] = true,
  [49] = true,
  [50] = true,
  [57] = true,
}
for number, stage in ipairs(authored) do
  if noBonuses[number] then
    stage.bonusKinds = {}
  elseif singleBonus[number] then
    stage.bonusKinds = { stage.bonusKinds[1] }
  end
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
  stage.bonuses = {}
  for index, key in ipairs(bonuses) do
    stage.bonuses[index] = bonusFor(stage, key, index)
  end
  stage.bonusKinds = nil
end
return authored
