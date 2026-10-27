-- IRONSPIRE route generator. Stored in saves so a run never rerolls.
local M = {}
local kinds = { "battle", "battle", "battle", "event", "elite", "rest", "shop" }
function M.generate(random)
	random = random or math.random
	local rows = {}
	for floor = 1, 9 do
		rows[floor] = {}
		for lane = 1, 3 do
			local kind
			if floor == 1 then
				kind = "battle"
			elseif floor == 9 then
				kind = lane == 2 and "boss" or "closed"
			elseif floor == 8 then
				kind = lane == 2 and "rest" or "battle"
			else
				kind = kinds[random(#kinds)]
			end
			rows[floor][lane] = { kind = kind, floor = floor, lane = lane }
		end
	end
	return rows
end
function M.reachable(s, floor, lane)
	if not s.map or floor ~= s.floor + 1 or floor > 9 or lane < 1 or lane > 3 then
		return false
	end
	local node = s.map[floor] and s.map[floor][lane]
	if not node or node.kind == "closed" then
		return false
	end
	if s.floor == 0 then
		return true
	end
	if floor == 9 then
		return lane == 2
	end
	return math.abs(lane - (s.lane or 2)) <= 1
end
function M.migrate(s)
	if type(s.map) ~= "table" or #s.map ~= 9 then
		s.map = M.generate()
		-- Older saves had no route location; use centre as their last visited node.
		s.lane = 2
	end
	return s
end
return M
