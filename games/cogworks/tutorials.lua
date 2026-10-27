-- Mechanic lessons introduce the Create equivalents used by each puzzle.
local levels = require("games.cogworks.levels")
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
-- Every accessible puzzle can teach all of its available mechanisms. The
-- per-slot seen flags suppress repeats, even when players skip discovery nodes
-- or use an alternative construction requiring a different part family.
T.introductions = {}
local teachingOrder = { "I", "Q", "G", "O", "D", "V", "B", "R", "Z", "C" }
for number, stage in ipairs(levels) do
	local available = {}
	for kind, count in pairs(stage.stock) do
		available[kind] = count > 0
	end
	for _, list in ipairs({ stage.fixtures, stage.redstone }) do
		for _, piece in ipairs(list or {}) do
			available[piece.kind] = true
		end
	end
	local lessons = {}
	for _, kind in ipairs(teachingOrder) do
		if available[kind] then
			lessons[#lessons + 1] = kind
		end
	end
	T.introductions[number] = lessons
end
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
		result[#result + 1] =
			{ key = key, title = T.lessons[key].title, lines = T.lessons[key].lines }
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
