--[[
	Private deterministic streams; arithmetic stays exact on CraftOS's Lua doubles.
	Never share math.random state with gameplay, rendering or other programs.
]]
local WorldRandom = {}
function WorldRandom.new(seed, salt)
	local value = (math.floor(tonumber(seed) or 0) + (salt or 0) * 104729) % 2147483646 + 1
	local stream = {}
	function stream:next()
		value = value * 48271 % 2147483647
		return value / 2147483647
	end
	function stream:integer(maximum)
		return math.floor(self:next() * maximum) + 1
	end
	function stream:shuffle(list)
		for i = #list, 2, -1 do
			local j = self:integer(i)
			list[i], list[j] = list[j], list[i]
		end
		return list
	end
	for _ = 1, 8 do
		stream:next()
	end
	return stream
end
return WorldRandom
