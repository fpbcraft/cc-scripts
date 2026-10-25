-- Mechanic lessons introduce the Create equivalents used by each puzzle.
local T = {}
T.lessons = {
  I = { title = "AXIAL SHAFTS", lines = {
    "SHAFTS TRANSMIT ALONG THEIR AXIS.",
    "TURN A SHAFT TO CHANGE ITS AXIS.",
  } },
  Q = { title = "BEVEL GEARBOX", lines = {
    "A GEARBOX CONNECTS ALL FOUR SIDES.",
    "EACH OUTPUT REVERSES INPUT SPIN.",
  } },
  G = { title = "SMALL COGWHEELS", lines = {
    "SHAFTS CONNECT AT EACH AXIAL END.",
    "COGS MESH SIDEWAYS AND REVERSE SPIN.",
  } },
  D = { title = "ENCASED CHAIN DRIVE", lines = {
    "PARALLEL DRIVES CONNECT SIDEWAYS.",
    "CHAIN LINKS PRESERVE SPIN AND SPEED.",
  } },
  Z = { title = "GEARSHIFT", lines = {
    "USE SWITCH TO APPLY REDSTONE POWER.",
    "POWERED GEARSHIFTS REVERSE SPIN.",
  } },
  C = { title = "CLUTCH", lines = {
    "USE SWITCH TO APPLY REDSTONE POWER.",
    "POWERED CLUTCHES DISCONNECT SHAFTS.",
  } },
  O = { title = "LARGE COGWHEELS", lines = {
    "LARGE AND SMALL COGS MESH DIAGONALLY.",
    "LARGE TO SMALL DOUBLES SPEED.",
  } },
  V = { title = "MECHANICAL BELTS", lines = {
    "TWO PARALLEL PULLEYS NEED CLEAR SPACE.",
    "BELTS KEEP ROTATION AND SPEED.",
  } },
}
T.introductions = {
  [1] = { "I" },
  [2] = { "Q" },
  [4] = { "G" },
  [6] = { "D" },
  [7] = { "Z" },
  [8] = { "C" },
  [9] = { "O" },
  [11] = { "V" },
}
T.descriptions = {
  I = "STRAIGHT AXIAL SHAFT; SAME RPM AND SPIN",
  G = "AXIAL SHAFTS; SIDE MESH REVERSES SPIN",
  O = "LARGE TO SMALL DIAGONAL MESH IS 2X",
  Q = "FOUR-WAY BEVEL GEARBOX; REVERSES",
  D = "SIDE-BY-SIDE CHAIN LINKS, SAME SPIN",
  V = "PARALLEL BELT PULLEYS, CLEAR SPAN",
  Z = "POWERED GEARSHIFT REVERSES ROTATION",
  C = "POWERED CLUTCH DISCONNECTS SHAFT",
  erase = "REMOVE A PLACED PART AND REFUND IT",
  switch = "TOGGLE REDSTONE ON CLUTCH/GEARSHIFT",
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
