-- Short, illustrated, one-time lessons. Keys are mechanism identifiers rather than
-- level numbers so a resumed save does not repeat a lesson.
local T = {}
T.lessons = {
	I = {
		title = "SHAFTS AND PORTS",
		lines = {
			"SHAFTS CONNECT OPPOSITE PORTS.",
			"SPIN AND RPM PASS THROUGH UNCHANGED.",
		},
	},
	L = {
		title = "TURNING POWER",
		lines = {
			"ELBOWS BEND A ROUTE BY 90 DEGREES.",
			"TAP A PLACED PART TO ROTATE IT.",
		},
	},
	T = {
		title = "SPLITTING POWER",
		lines = {
			"SPLITTERS CONNECT THREE DIRECTIONS.",
			"EACH BRANCH RECEIVES THE SAME DRIVE.",
		},
	},
	V = {
		title = "BELT TRANSMISSION",
		lines = {
			"PAIR TWO FACING BELT ENDPOINTS.",
			"SPAN UP TO TWO CELLS, EVEN STONE.",
		},
	},
	G = {
		title = "REVERSING ROTATION",
		lines = {
			"GEARS CHANGE CW INTO CCW AND BACK.",
			"THE SPEED STAYS THE SAME.",
		},
	},
	B = {
		title = "SPEED CONTROLLERS",
		lines = {
			"GREEN MARK SHOWS THE INPUT SIDE.",
			"FORWARD DOUBLES; REVERSE HALVES RPM.",
		},
	},
	Q = {
		title = "FOUR WAY GEARBOX",
		lines = {
			"POWER CAN LEAVE IN FOUR DIRECTIONS.",
			"UNUSED GEARBOX PORTS ARE SEALED.",
		},
	},
	O = {
		title = "LARGE COG",
		lines = {
			"REVERSES SPIN AND DOUBLES RPM.",
			"REVERSE FLOW HALVES THE SPEED.",
		},
	},
	D = {
		title = "CHAIN TRANSMISSION",
		lines = {
			"PAIR TWO FACING CHAIN ENDPOINTS.",
			"SPAN UP TO THREE CELLS, EVEN STONE.",
		},
	},
}
-- Introduce a part at the first campaign stage where players can use it.
T.introductions = {
	[1] = { "I" },
	[2] = { "L" },
	[4] = { "T" },
	[6] = { "V" },
	[8] = { "G" },
	[9] = { "B", "Q" },
	[16] = { "O" },
	[23] = { "D" },
}
T.descriptions = {
	I = "STRAIGHT CONNECTION; SAME SPIN AND RPM",
	L = "90 DEGREE TURN; SAME SPIN AND RPM",
	T = "THREE WAY POWER JUNCTION",
	G = "REVERSES CW AND CCW AT SAME RPM",
	B = "DOUBLES RPM FROM MARKED INPUT",
	Q = "FOUR WAY JUNCTION WITH CAPPED PORTS",
	O = "REVERSES ROTATION AND DOUBLES RPM",
	V = "PAIRED BELTS SPAN UP TO TWO CELLS",
	D = "PAIRED CHAINS SPAN UP TO THREE CELLS",
	erase = "REMOVE A PLACED PART AND REFUND IT",
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
