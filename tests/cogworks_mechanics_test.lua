package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local function put(g, x, y, kind, rotation)
  assert(E.place(g, x, y, kind, rotation), "Cannot place " .. kind)
  return E.get(g, x, y)
end
local function state(g, tile)
  return E.evaluate(g).lights[tile.id]
end
local function powered(g, tile)
  return state(g, tile).powered
end
-- Axial shafts and same-axis cogwheels pass power unchanged.
local axial = E.sandbox()
local shaft = put(axial, 2, 3, "I", 1)
local cog1 = put(axial, 3, 3, "G", 1)
local cog2 = put(axial, 4, 3, "G", 1)
assert(E.connection(axial, shaft, 1) == cog1)
assert(state(axial, cog2).rate == 1 and state(axial, cog2).sign == 1)
-- Cog teeth mesh only perpendicular to their shaft axis.
local meshing = E.sandbox()
local first = put(meshing, 2, 3, "G", 1)
local second = put(meshing, 2, 4, "G", 1)
assert(powered(meshing, second) and state(meshing, second).sign == -1)
assert(not E.connection(meshing, first, 2), "Perpendicular cog interaction is meshing, not shaft coupling")
local isolated = put(meshing, 3, 5, "G", 0)
assert(not powered(meshing, isolated), "Wrong axis / diagonal small cog does not mesh")
local large = E.sandbox()
put(large, 2, 3, "O", 1)
local small = put(large, 3, 4, "G", 1)
assert(
  state(large, small).rate == 2 and state(large, small).sign == -1,
  "Large cog drives diagonal small cog at twice the speed and opposite spin"
)
-- Adjacent rims must couple too: axial shaft ends are NOT the only
-- connection. A large/small pair has inverse spin and a 2:1 transfer.
local rim = E.sandbox()
put(rim, 2, 3, "O", 1)
local rimSmall = put(rim, 2, 4, "G", 1)
assert(
  state(rim, rimSmall).rate == 2 and state(rim, rimSmall).sign == -1,
  "Adjacent large/small toothed rims mesh, not just shafts or diagonal neighbors"
)
assert(not E.connection(rim, E.get(rim, 2, 3), 2), "Gear rim is not an axial port")
local wrongAxis = E.sandbox()
put(wrongAxis, 2, 3, "O", 1)
local offAxis = put(wrongAxis, 2, 4, "G", 0)
assert(not powered(wrongAxis, offAxis), "Perpendicular shafts cannot mesh in the 2D workshop")
local reverseRim = E.sandbox()
put(reverseRim, 2, 3, "G", 1)
local rimLarge = put(reverseRim, 2, 4, "O", 1)
assert(
  state(reverseRim, rimLarge).rate == 0.5 and state(reverseRim, rimLarge).sign == -1,
  "Adjacent small-to-large toothed rims halve the RPM"
)
local reduction = E.sandbox()
put(reduction, 2, 3, "G", 1)
local largeOut = put(reduction, 3, 4, "O", 1)
assert(
  state(reduction, largeOut).rate == 0.5 and state(reduction, largeOut).sign == -1,
  "Small cog drives diagonal large cog at half speed"
)
-- Every gearbox output reverses sign relative to the incoming shaft.
local box = E.sandbox()
local gearbox = put(box, 2, 3, "Q", 0)
local b = state(box, gearbox)
assert(not E.evaluate(box).jam, "Unused gearbox outlets should not jam")
for direction = 0, 3 do
  assert(E.hasPort(gearbox, direction), "Gearbox should have four axial ports")
  assert(
    b.ports[direction] and b.ports[direction].sign == (direction == 3 and 1 or -1),
    "Output should reverse input on port " .. direction
  )
end
local belt = E.sandbox()
put(belt, 2, 3, "V", 1)
local remote = put(belt, 2, 6, "V", 1)
assert(powered(belt, remote) and state(belt, remote).sign == 1, "Belt preserves rotation and speed across a clear span")
assert(not E.connection(belt, E.get(belt, 2, 3), 2), "Belt is not an invisible axial shaft")
local obstructed = E.sandbox()
put(obstructed, 2, 3, "V", 1)
local far = put(obstructed, 2, 6, "V", 1)
put(obstructed, 2, 4, "I", 0)
assert(not powered(obstructed, far), "Machinery cannot be bridged by an invisible belt")
local chain = E.sandbox()
local head = put(chain, 2, 3, "D", 1)
local tail = put(chain, 2, 4, "D", 1)
assert(powered(chain, tail) and state(chain, tail).sign == 1, "Parallel chain drives relay sideways without reversing")
assert(not E.connection(chain, head, 2), "Chain link is not a gearbox port")
local shift = E.sandbox()
put(shift, 2, 3, "Z", 1)
local shiftedOut = put(shift, 3, 3, "I", 1)
assert(state(shift, shiftedOut).sign == 1, "Unpowered gearshift is a straight shaft")
assert(E.toggle(shift, 2, 3))
assert(state(shift, shiftedOut).sign == -1, "Powered gearshift reverses spin")
local clutch = E.sandbox()
put(clutch, 2, 3, "C", 1)
local stopped = put(clutch, 3, 3, "I", 1)
assert(powered(clutch, stopped))
assert(E.toggle(clutch, 2, 3))
assert(not powered(clutch, stopped), "Powered clutch disconnects its output")
assert(E.toggle(clutch, 2, 3) and powered(clutch, stopped), "Clutch reconnects when switched off")
-- Saving a fixed puzzle toggle must not silently reset its redstone state.
local fixture = E.new(8, true)
local restored = E.new(8)
assert(
  E.restore(restored, E.snapshot(fixture)) and E.evaluate(restored).win,
  "Fixed clutch redstone state is serialized"
)
-- Contradictory loops are jams, not arbitrary winner-takes-all power.
assert(not E.evaluate(E.new(16, true)).jam, "Three gearbox outputs must coexist")
print("COGWORKS: shafts, gearbox inversion, cog mesh and ratios, belts, chains, switches passed.")
