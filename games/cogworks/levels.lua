-- COGWORKS / Create-style kinetic lessons. Old elbow/splitter/inline-speed
-- puzzles are intentionally replaced, not adapted. 0=N 1=E 2=S 3=W.
-- Each reference contains placements plus optional redstone switch toggles.
local function p(kind, x, y, r, engaged)
  return { kind = kind, x = x, y = y, r = r or 0, engaged = engaged }
end
local function s(x, y, r)
  return p("S", x, y, r)
end
local function m(x, y, r, rate, sign)
  local part = p("M", x, y, r)
  part.speed = rate
  part.sign = sign
  return part
end
local function level(name, tip, source, goals, build, options)
  options = options or {}
  local stock = {}
  for _, part in ipairs(build) do
    stock[part.kind] = (stock[part.kind] or 0) + 1
  end
  for kind, amount in pairs(options.spares or {}) do
    stock[kind] = (stock[kind] or 0) + amount
  end
  return {
    name = name,
    tip = tip,
    source = source,
    goals = goals,
    build = build,
    blocks = options.blocks or {},
    fixtures = options.fixtures or {},
    toggles = options.toggles or {},
    redstone = options.redstone or {},
    removeRedstone = options.removeRedstone or {},
    stock = stock,
  }
end
local levels = {
  level(
    "STRAIGHT SHAFT",
    "CONNECT THE GENERATOR TO THE PRESS WITH AXIAL SHAFTS.",
    s(1, 3, 1),
    { m(5, 3, 3, 1, 1) },
    { p("I", 2, 3, 1), p("I", 3, 3, 1), p("I", 4, 3, 1) }
  ),
  level(
    "THE BEVEL TURN",
    "A GEARBOX TURNS POWER AND REVERSES ITS SPIN.",
    s(1, 3, 1),
    { m(2, 5, 0, 1, -1) },
    { p("Q", 2, 3, 0), p("I", 2, 4, 0) },
    { blocks = { { 3, 4 }, { 3, 5 } } }
  ),
  level(
    "TWO REVERSALS",
    "TWO GEARBOXES CHANGE DIRECTION TWICE.",
    s(1, 2, 1),
    { m(4, 4, 3, 1, 1) },
    { p("Q", 2, 2, 0), p("I", 2, 3, 0), p("Q", 2, 4, 0), p("I", 3, 4, 1) }
  ),
  level(
    "MESHING TEETH",
    "COGS MESH SIDEWAYS, NOT THROUGH THEIR SHAFT ENDS.",
    s(1, 2, 1),
    { m(4, 3, 3, 1, -1) },
    { p("G", 2, 2, 1), p("G", 2, 3, 1), p("I", 3, 3, 1) }
  ),
  level(
    "THREE-WAY POWER",
    "ONE GEARBOX POWERS THREE OPPOSITE-SPIN PRESSES.",
    s(1, 3, 1),
    { m(3, 2, 2, 1, -1), m(4, 3, 3, 1, -1), m(3, 4, 0, 1, -1) },
    { p("I", 2, 3, 1), p("Q", 3, 3, 0) }
  ),
  level(
    "CHAIN LINK",
    "CONNECT SIDE-BY-SIDE CHAIN DRIVES ON PARALLEL SHAFTS.",
    s(1, 3, 1),
    { m(5, 4, 3, 1, 1) },
    { p("I", 2, 3, 1), p("D", 3, 3, 1), p("D", 3, 4, 1), p("I", 4, 4, 1) },
    { blocks = { { 4, 3 } } }
  ),
  level(
    "REDSTONE REVERSE",
    "TOGGLE THE GEARSHIFT TO REVERSE THE OUTPUT.",
    s(1, 3, 1),
    { m(4, 3, 3, 1, -1) },
    { p("Z", 2, 3, 1), p("I", 3, 3, 1) },
    { spares = { B = 1, R = 2 } }
  ),
  level(
    "CUT THE CLUTCH",
    "SWITCH OFF THE POWERED CLUTCH TO CONNECT THE SHAFT.",
    s(1, 3, 1),
    { m(4, 3, 3, 1, 1) },
    { p("I", 3, 3, 1) },
    { fixtures = { p("C", 2, 3, 1) }, redstone = { p("B", 2, 2) }, removeRedstone = { { 2, 2 } } }
  ),
  level(
    "GEAR UP",
    "LARGE TO SMALL DIAGONAL COGS DOUBLE THE RPM.",
    s(1, 2, 1),
    { m(4, 3, 3, 2, -1) },
    { p("O", 2, 2, 1), p("G", 3, 3, 1) }
  ),
  level(
    "GEAR DOWN",
    "SMALL TO LARGE DIAGONAL COGS HALVE THE RPM.",
    s(1, 2, 1),
    { m(4, 3, 3, 0.5, -1) },
    { p("G", 2, 2, 1), p("O", 3, 3, 1) }
  ),
  level(
    "PARALLEL BELTS",
    "PAIR PARALLEL PULLEYS ACROSS AN EMPTY, CLEAR SPAN.",
    s(1, 2, 1),
    { m(3, 5, 3, 1, 1) },
    { p("V", 2, 2, 1), p("V", 2, 5, 1) },
    { blocks = { { 3, 3 }, { 3, 4 } } }
  ),
  level(
    "BRANCHING WORKS",
    "COMBINE A REVERSING GEARBOX WITH A CHAIN DRIVE.",
    s(1, 3, 1),
    { m(3, 2, 2, 1, -1), m(4, 3, 3, 1, -1), m(4, 5, 0, 1, -1) },
    { p("I", 2, 3, 1), p("Q", 3, 3, 0), p("D", 3, 4, 0), p("D", 4, 4, 0) }
  ),
  level(
    "COUNTER ROTATION",
    "A GEARBOX AND SIDE-MESHING COGS CANCEL THE REVERSAL.",
    s(1, 3, 1),
    { m(3, 1, 2, 1, 1) },
    { p("Q", 2, 3, 0), p("G", 2, 2, 0), p("G", 3, 2, 0) }
  ),
  level(
    "BELTED GEAR TRAIN",
    "USE A BELT, THEN A DIAGONAL COG PAIR TO SPEED UP.",
    s(1, 2, 1),
    { m(5, 4, 3, 2, -1) },
    { p("V", 2, 2, 1), p("V", 2, 5, 1), p("O", 3, 5, 1), p("G", 4, 4, 1) }
  ),
  level(
    "CLOCKWORK TREE",
    "SPLIT POWER, THEN REVERSE ONE BRANCH WITH COGS.",
    s(1, 3, 1),
    { m(2, 2, 2, 1, -1), m(5, 4, 3, 1, 1), m(2, 5, 0, 1, -1) },
    { p("Q", 2, 3, 0), p("I", 3, 3, 1), p("G", 4, 3, 1), p("G", 4, 4, 1), p("D", 2, 4, 0) }
  ),
  level(
    "MASTER GEARSHIFT",
    "SWITCH THE GEARSHIFT BEFORE FEEDING THREE GEARBOX OUTPUTS.",
    s(1, 3, 1),
    { m(3, 2, 2, 1, 1), m(4, 3, 3, 1, 1), m(3, 4, 0, 1, 1) },
    { p("Q", 3, 3, 0) },
    { fixtures = { p("Z", 2, 3, 1) }, spares = { B = 1, R = 2 } }
  ),
} 
local sizes = {
  { 5, 5 }, { 5, 5 }, { 5, 5 }, { 6, 5 },
  { 6, 5 }, { 6, 6 }, { 6, 6 }, { 6, 6 },
  { 7, 6 }, { 7, 6 }, { 8, 7 }, { 8, 7 },
  { 8, 8 }, { 9, 8 }, { 9, 9 }, { 10, 10 },
}
for index, stage in ipairs(levels) do
  stage.width, stage.height = sizes[index][1], sizes[index][2]
end
-- Redstone is part of authored solutions, not a global magic switch.
levels[7].build[#levels[7].build + 1] = p("B", 2, 2)
levels[16].build[#levels[16].build + 1] = p("B", 2, 2)
return levels
