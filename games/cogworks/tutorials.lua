-- Mechanic lessons introduce the Create equivalents used by each puzzle.
local T = {}
T.lessons = {
  I = {
    title = "AXIAL SHAFTS",
    lines = {
      "SHAFTS TRANSMIT ALONG THEIR AXIS.",
      "TURN A SHAFT TO CHANGE ITS AXIS.",
    },
  },
  Q = {
    title = "BEVEL GEARBOX",
    lines = {
      "A GEARBOX CONNECTS ALL FOUR SIDES.",
      "EACH OUTPUT REVERSES INPUT SPIN.",
    },
  },
  G = {
    title = "SMALL COGWHEELS",
    lines = {
      "SHAFTS CONNECT AT EACH AXIAL END.",
      "COGS MESH SIDEWAYS AND REVERSE SPIN.",
    },
  },
  D = {
    title = "ENCASED CHAIN DRIVE",
    lines = {
      "PARALLEL DRIVES CONNECT SIDEWAYS.",
      "CHAIN LINKS PRESERVE SPIN AND SPEED.",
    },
  },
  Z = {
    title = "GEARSHIFT",
    lines = {
      "REDSTONE BLOCKS OR DUST APPLY POWER.",
      "POWERED GEARSHIFTS REVERSE SPIN.",
    },
  },
  C = {
    title = "CLUTCH",
    lines = {
      "REDSTONE BLOCKS OR DUST APPLY POWER.",
      "POWERED CLUTCHES DISCONNECT SHAFTS.",
    },
  },
  O = {
    title = "LARGE COGWHEELS",
    lines = {
      "LARGE AND SMALL COGS MESH DIAGONALLY.",
      "LARGE TO SMALL DOUBLES SPEED.",
    },
  },
  V = {
    title = "MECHANICAL BELTS",
    lines = {
      "ADJACENT PULLEYS OR CLEAR-SPAN BELTS.",
      "SHAFTS CAN CROSS BELT RUNS.",
    },
  },
  R = {
    title = "REDSTONE DUST",
    lines = {
      "DUST LINKS BLOCKS TO CLUTCHES.",
      "DUST CONNECTS AND TURNS AT CORNERS.",
    },
  },
  B = {
    title = "REDSTONE BLOCK",
    lines = {
      "BLOCKS POWER ADJACENT REDSTONE.",
      "PLACE BESIDE SHIFT OR WIRE.",
    },
  },
}
-- Lessons are attached to the first *accessible* stage where a component
-- matters, not an arbitrary chapter boundary. Skipped optional previews
-- are retaught at the next mandatory encounter.
T.introductions = {
  [1] = { "I" },
  [2] = { "Q" },
  [3] = { "G" },
  [7] = { "O" },
  [17] = { "O" },
  [25] = { "D" },
  [26] = { "V" },
  [41] = { "Z", "B" },
  [42] = { "R" },
  [43] = { "C" },
}
T.descriptions = {
  I = "STRAIGHT AXIAL SHAFT; SAME RPM AND SPIN",
  G = "AXIAL SHAFTS; SIDE MESH REVERSES SPIN",
  O = "LARGE/SMALL COGS MESH DIAGONALLY AT 2X",
  Q = "FOUR-WAY BEVEL GEARBOX; REVERSES",
  D = "SIDE-BY-SIDE CHAIN LINKS, SAME SPIN",
  V = "PULLEYS CONNECT ADJACENT OR ACROSS SHAFTS",
  Z = "POWERED GEARSHIFT REVERSES ROTATION",
  C = "POWERED CLUTCH DISCONNECTS SHAFT",
  erase = "REMOVE A PLACED PART AND REFUND IT",
  R = "CENTERED CONNECTING REDSTONE POWDER",
  B = "REDSTONE POWER BLOCK FOR SHIFT AND CLUTCH",
}
function T.forLevel(level)
  local result = {}
  for _, key in ipairs(T.introductions[level] or {}) do
    result[#result + 1] = { key = key, title = T.lessons[key].title, lines = T.lessons[key].lines }
  end
  return result
end
function T.unseen(level, seen)
  local result = {}
  for _, lesson in ipairs(T.forLevel(level)) do
    if not (seen and seen[lesson.key]) then
      result[#result + 1] = lesson
    end
  end
  return result
end
return T
