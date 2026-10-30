local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Geometry = dofile("/games/civcraft/display_geometry.lua")
dofile = native

local wrapped = { width = 18, height = 12, wrapX = true }
local state = { world = wrapped }
assert(Geometry.isWrapped(wrapped) and Geometry.isWrapped(state))
assert(not Geometry.isWrapped({ width = 18, height = 12 }))
assert(Geometry.nearestX(18, 1, wrapped) == 0)
assert(Geometry.nearestX(1, 18, state) == 19)
assert(Geometry.nearestX(1, 10, wrapped) == 19, "Half-period ties choose the positive copy")
assert(Geometry.nearestX(37, 1, wrapped) == 1)

local bounded = { width = 18, height = 12, wrapX = false }
assert(not Geometry.isWrapped(bounded))
assert(Geometry.nearestX(18, 1, bounded) == 18, "Bounded maps preserve display X")
assert(Geometry.nearestX(18, 1) == 18, "Missing topology remains bounded")
assert(Geometry.nearestX(18, math.huge, wrapped) == 18)
assert(Geometry.nearestX(18, 1, { width = 0, wrapX = true }) == 18)

print("CIVCRAFT display geometry: topology selection and nearest periodic copies passed.")
