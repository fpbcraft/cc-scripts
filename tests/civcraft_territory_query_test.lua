local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)

local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")

local function reference(state, hex)
	local result = {}
	for y = 1, state.world.height do
		for x = 1, state.world.width do
			local city = World.territoryCity(state, hex, x, y)
			if city then
				result[World.key(x, y)] = city.owner
			end
		end
	end
	return result
end

local function equal(first, second)
	for key, value in pairs(first) do
		assert(second[key] == value, "Territory differs at " .. key)
	end
	for key in pairs(second) do
		assert(first[key] ~= nil, "Optimized territory omitted " .. key)
	end
end

local function compare(state, hex)
	equal(reference(state, hex), World.territory(state, hex))
end

local function stateFor(width, height, wrapX, cities)
	return { world = { width = width, height = height, wrapX = wrapX }, cities = cities }
end

-- Exhaustively cover bounded and wrapped small boards with city pairs/triples,
-- legacy radius claims, explicit claims, and distance/ID/order ties.
for width = 1, 6 do
	for height = 1, 5 do
		for _, wrapX in ipairs({ false, true }) do
			for offset = 0, width * height - 1 do
				local ax, ay = offset % width + 1, math.floor(offset / width) + 1
				local bx = (ax + math.floor(width / 2) - 1) % width + 1
				local by = ay == height and 1 or ay + 1
				local cities = {
					{ id = 7, owner = 1, x = ax, y = ay, population = offset % 3 == 0 and 7 or 2 },
					{ id = 7, owner = 2, x = bx, y = by, population = offset % 2 == 0 and 4 or 1 },
				}
				if offset % 2 == 0 then
					cities[1].claimed = {}
					for y = 1, height do
						for x = 1, width do
							if (x * 7 + y * 11 + offset) % 5 == 0 then
								cities[1].claimed[World.key(x, y)] = true
							end
						end
					end
				end
				if offset % 3 == 0 then
					cities[2].claimed = {}
					for y = 1, height do
						for x = 1, width do
							if (x * 13 + y * 3 + offset) % 7 == 0 then
								cities[2].claimed[World.key(x, y)] = 1
							end
						end
					end
				end
				compare(stateFor(width, height, wrapX, cities), Hex)
			end
		end
	end
end

local seed = 149
local function nextInt(limit)
	seed = seed * 48271 % 2147483647
	return seed % limit + 1
end
for case = 1, 120 do
	local width, height = nextInt(12), nextInt(9)
	local cities = {}
	for _ = 1, nextInt(10) do
		local city = {
			owner = nextInt(4),
			x = nextInt(width),
			y = nextInt(height),
			population = nextInt(9),
		}
		if nextInt(5) ~= 1 then
			city.id = nextInt(4)
		end
		if nextInt(3) ~= 1 then
			city.claimed = {}
			for _ = 1, nextInt(width * height + 8) do
				local x, y = nextInt(width + 4) - 2, nextInt(height + 4) - 2
				local claimKey = World.key(x, y)
				if nextInt(5) == 1 then
					claimKey = string.format("%02d:%d", x, y)
				elseif nextInt(5) == 1 then
					claimKey = tostring(x) .. ":0" .. tostring(y)
				end
				city.claimed[claimKey] = nextInt(4) ~= 1 and true or false
			end
		end
		cities[#cities + 1] = city
	end
	compare(stateFor(width, height, nextInt(2) == 1, cities), Hex)
end

-- Explicit keys use the same canonical string lookup as the original grid
-- scan: malformed, leading-zero, non-string and out-of-world keys are ignored.
local oddClaims = stateFor(4, 3, true, {
	{
		id = 1,
		owner = 10,
		x = 1,
		y = 2,
		claimed = {
			["1:1"] = true,
			["01:1"] = true,
			["1:01"] = true,
			["0:1"] = true,
			["5:1"] = true,
			["1:4"] = true,
			["2:2"] = false,
			[22] = true,
		},
	},
})
compare(oddClaims, Hex)
local oddResult = World.territory(oddClaims, Hex)
assert(oddResult["1:1"] == 10)
for _, invalid in ipairs({ "01:1", "1:01", "0:1", "5:1", "1:4", "2:2" }) do
	assert(oddResult[invalid] == nil, "Malformed claim was introduced: " .. invalid)
end

-- Sequential calls reflect owner capture, claim edits, population changes,
-- and switching between explicit and legacy claim representations.
local mutable = stateFor(9, 7, true, {
	{ id = 3, owner = 1, x = 1, y = 4, population = 7, claimed = { ["8:4"] = true } },
	{ id = 4, owner = 2, x = 5, y = 4, population = 2 },
})
compare(mutable, Hex)
mutable.cities[1].owner = 3
mutable.cities[1].claimed["8:4"] = nil
mutable.cities[1].claimed["9:4"] = true
mutable.cities[2].population = 7
compare(mutable, Hex)
mutable.cities[1].claimed = nil
mutable.cities[1].x = 9
compare(mutable, Hex)

-- Legacy radius enumeration must wrap at the seam and fall back to the old
-- traversal when the supplied geometry API cannot enumerate a radius.
local legacyWrap = stateFor(8, 6, true, { { id = 1, owner = 1, x = 1, y = 3, population = 7 } })
compare(legacyWrap, Hex)
assert(World.territory(legacyWrap, Hex)["8:3"] == 1)
local limitedHex = { distance = Hex.distance }
compare(legacyWrap, limitedHex)

local invalidOrigin = stateFor(5, 4, true, {
	{ id = 1, owner = 1, x = 0, y = 2, claimed = { ["2:2"] = true } },
	{ id = 2, owner = 2, x = 3, y = 2, population = 4 },
})
compare(invalidOrigin, Hex)
local virtualClaims = stateFor(5, 4, false, {
	{
		id = 1,
		owner = 1,
		x = 1,
		y = 2,
		claimed = setmetatable({}, {
			__index = function(_, tileKey)
				return tileKey == "3:2" and true or nil
			end,
		}),
	},
})
compare(virtualClaims, Hex)
local malformedNeighborhood = {
	distance = Hex.distance,
	canonical = Hex.canonical,
	withinRadius = function()
		return { { x = 1, y = 1 }, { x = 99, y = 1 } }
	end,
}
compare(legacyWrap, malformedNeighborhood)

-- Sparse authoritative claims are enumerated directly rather than asking for
-- ownership of every map tile. Keep the operation-count check deterministic.
local large = stateFor(96, 60, true, {})
local expectedDistances = 0
for id = 1, 24 do
	local city = { id = id, owner = id, x = id * 3, y = id * 2, claimed = {} }
	for index = 0, 4 do
		local x = (city.x + index * 7 - 1) % large.world.width + 1
		local y = (city.y + index * 11 - 1) % large.world.height + 1
		city.claimed[World.key(x, y)] = true
		expectedDistances = expectedDistances + 1
	end
	large.cities[#large.cities + 1] = city
end
local distanceCalls = 0
local countingHex = {
	canonical = Hex.canonical,
	withinRadius = Hex.withinRadius,
	distance = function(...)
		distanceCalls = distanceCalls + 1
		return Hex.distance(...)
	end,
}
compare(large, Hex)
local sparse = World.territory(large, countingHex)
equal(reference(large, Hex), sparse)
assert(
	distanceCalls == expectedDistances,
	"Explicit ownership did not visit only its claimed tiles"
)
assert(distanceCalls < large.world.width * large.world.height * #large.cities)

print(
	"CIVCRAFT: sparse territory matches the legacy scan across wrapped, bounded, and mutated maps."
)
