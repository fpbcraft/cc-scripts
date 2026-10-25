package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
assert(#E.order == 9, "Nine distinct construction mechanisms available")
for _, level in ipairs({ 6, 9, 16, 23, 25, 27, 30 }) do
	local state = E.new(level, true)
	assert(E.evaluate(state).win, "Expanded reference not solved: " .. level)
end
local function find(g, kind)
	for _, part in ipairs(g.tiles) do
		if part.kind == kind then
			return part
		end
	end
end
-- Legacy snapshots with clutch tiles migrate to regular shafts without
-- invalidating the save slot or the level's solution.
local legacy = E.snapshot(E.new(6, true))
local oldClutch = nil
for _, part in ipairs(legacy) do
	if part.x == 2 and part.y == 2 then
		part.kind = "C"
		part.enabled = false
		oldClutch = part
		break
	end
end
assert(oldClutch, "Old level 6 contained a clutch")
local migrated = E.new(6)
assert(E.restore(migrated, legacy), "Legacy clutch snapshot is accepted")
assert(E.get(migrated, 2, 2).kind == "I", "Clutch becomes a shaft")
assert(E.evaluate(migrated).win, "Migrated reference still powers both presses")
assert(not E.parts.C, "Clutch removed from selectable inventory")
local gearbox = E.new(9, true)
local box = assert(find(gearbox, "Q"))
for d = 0, 3 do
	assert(E.hasPort(box, d), "Four-way gearbox has all ports")
end
local belt = E.new(6, true)
local left = assert(E.get(belt, 3, 3))
local right = assert(E.get(belt, 5, 3))
assert(left.kind == "V" and right.kind == "V", "Belt endpoints in level 6")
assert(E.get(belt, 4, 3).kind == "X", "Belt spans obstacle")
assert(E.connection(belt, left, 1) == right, "Belt bridges gap")
local chain = E.new(23, true)
local top = assert(E.get(chain, 6, 2))
local bottom = assert(E.get(chain, 6, 4))
assert(top.kind == "D" and bottom.kind == "D", "Chain endpoint layout")
assert(E.get(chain, 6, 3).kind == "X", "Chain route blocked by stone")
assert(E.connection(chain, top, 2) == bottom, "Chain bridges a stone cell")
local cog = E.new(16, true)
local large = assert(find(cog, "O"))
assert(E.evaluate(cog).win, "Large cog reference works")
large.kind = "G"
assert(not E.evaluate(cog).win, "Large cog speed ratio matters to goal")
print("COGWORKS: migration, gearbox, large cog, belt and chain dynamics passed.")
